-- Mail storage (mail plan §3.10): grug_mail's mod storage, `core.serialize`.
-- Offline player meta cannot be written (ObjectRef:get_meta needs a live
-- object), so every mailbox lives here, read and written whole:
--   box:<name>    one player's mailbox (model.lua)
--   sent:<name>   one player's sent letters, text copies only (Round 66;
--                 kept apart from the box, which every inbox access reads
--                 whole; a missing key is an empty list)
--   tickets       the admin inbox, every player's messages to the admin
--   broadcasts    the "All players" letters, stored once
--   factions      the recipient index: lower-case name -> {name, faction}
--   next_id       the id counter of letters, tickets and broadcasts
-- The per-player read set of the broadcasts is player meta
-- (`grug_mail:broadcasts_read`); the player is online whenever it changes.
-- Expired entries are pruned when a list is read, and once at every start
-- (Round 83 ruling 10, S.prune_all), never by a pass while the server runs.
-- Mail is not map-bound: a map reset clears none of it.

local M = grug_mail.model
local storage = core.get_mod_storage()
local S = {}

local READ_KEY = "grug_mail:broadcasts_read"

local function now() return os.time() end
S.now = now

-- One mailbox click reads the same box up to five times (Round 81 P5-02).
-- The last few keys read keep their stored string and an untouched copy of
-- what it decoded to: a read whose stored string is unchanged copies that
-- instead of decoding the string again. Every read still hands out a fresh
-- table (callers write to it and save it, or throw it away), and a save
-- changes the string, so the next read decodes. At most DECODED_KEYS keys
-- are kept (a click reads two or three: the box, the broadcasts).
local DECODED_KEYS = 4
local decoded, decoded_keys = {}, 0

local function copy(value, seen)
	if type(value) ~= "table" then return value end
	if seen[value] then return seen[value] end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do out[copy(k, seen)] = copy(v, seen) end
	return out
end

local function load(key)
	local raw = storage:get_string(key)
	if raw == "" then return nil end
	local entry = decoded[key]
	if entry and entry.raw == raw then return copy(entry.value, {}) end
	local value = core.deserialize(raw)
	if type(value) ~= "table" then
		core.log("error", "[grug_mail] unreadable mod storage key " .. key ..
			"; it starts empty")
		return nil
	end
	if not entry then
		if decoded_keys >= DECODED_KEYS then decoded, decoded_keys = {}, 0 end
		decoded_keys = decoded_keys + 1
	end
	decoded[key] = {raw = raw, value = copy(value, {})}
	return value
end

local function save(key, value)
	storage:set_string(key, core.serialize(value))
end

function S.next_id()
	local id = storage:get_int("next_id") + 1
	storage:set_int("next_id", id)
	return id
end

-- A player's mailbox, expired letters removed (and the removal saved).
function S.box(name)
	local box = load("box:" .. name) or M.new_box()
	box.letters = box.letters or {}
	if M.prune(box.letters, now()) > 0 then S.save_box(name, box) end
	return box
end

function S.save_box(name, box)
	save("box:" .. name, box)
end

-- A player's sent copies, newest first, expired ones removed (and the
-- removal saved).
function S.sent(name)
	local sent = load("sent:" .. name) or {}
	if M.prune(sent, now()) > 0 then S.save_sent(name, sent) end
	return sent
end

-- An empty list removes the key.
function S.save_sent(name, sent)
	storage:set_string("sent:" .. name, #sent > 0 and core.serialize(sent) or "")
end

-- Who hears that a whole list was written (grug_bridge, 0.69.1): func(list)
-- after the write, for the kinds "tickets" and "broadcasts". Every change of
-- those lists ends in their save below, the pruning at a read included. The
-- list is the caller's: never written to, never kept.
local saved_callbacks = {tickets = {}, broadcasts = {}}

function S.register_on_saved(kind, func)
	table.insert(saved_callbacks[kind], func)
end

local function run_saved(kind, list)
	for _, func in ipairs(saved_callbacks[kind]) do func(list) end
end

function S.tickets()
	local tickets = load("tickets") or {}
	if M.prune(tickets, now()) > 0 then S.save_tickets(tickets) end
	return tickets
end

function S.save_tickets(tickets)
	save("tickets", tickets)
	run_saved("tickets", tickets)
end

function S.broadcasts()
	local broadcasts = load("broadcasts") or {}
	if M.prune(broadcasts, now()) > 0 then S.save_broadcasts(broadcasts) end
	return broadcasts
end

function S.save_broadcasts(broadcasts)
	save("broadcasts", broadcasts)
	run_saved("broadcasts", broadcasts)
end

--
-- The read set of the broadcasts (player meta, online players only)
--

function S.read_set(player)
	local raw = player:get_meta():get_string(READ_KEY)
	local set = raw ~= "" and core.deserialize(raw) or nil
	return type(set) == "table" and set or {}
end

function S.save_read_set(player, set, broadcasts)
	set = M.trim_read_set(set, broadcasts)
	player:get_meta():set_string(READ_KEY, next(set) and core.serialize(set) or "")
end

--
-- The recipient index (§3.8): every created character's faction, filled at
-- the faction choice and at every join. A character that has not joined
-- since the update is not in it yet and cannot receive player mail.
--

local index

local function load_index()
	if not index then index = load("factions") or {} end
	return index
end

function S.index_player(name, faction)
	if type(name) ~= "string" or name == "" or type(faction) ~= "string" then return end
	local rows = load_index()
	local row = rows[name:lower()]
	if row and row.name == name and row.faction == faction then return end
	rows[name:lower()] = {name = name, faction = faction}
	save("factions", rows)
end

-- The stored name and faction for a typed name (any letter case), or nil.
function S.lookup(name)
	local row = load_index()[tostring(name or ""):lower()]
	if row then return row.name, row.faction end
	return nil
end

--
-- Round 83: the start's pruning and the deletion of a character
--

-- Every mailbox, sent list, the tickets and the broadcasts lose their expired
-- entries (the reads above prune and save). One pass at the start, before any
-- join, so "removed after 30 days" holds within one restart. Returns the
-- number of lists read.
function S.prune_all()
	local count = 0
	for _, key in ipairs(storage:get_keys()) do
		local kind, name = key:match("^(%a+):(.+)$")
		if kind == "box" then
			S.box(name)
			count = count + 1
		elseif kind == "sent" then
			S.sent(name)
			count = count + 1
		end
	end
	S.tickets()
	S.broadcasts()
	return count + 2
end

-- The character's own mailbox (its attachments with it), its sent copies,
-- its tickets and its row in the recipient index go. What others hold about
-- it stays (Round 83 ruling 1): their letters from it, their sent copies to
-- it, their reports of its letters.
function S.forget(name)
	storage:set_string("box:" .. name, "")
	storage:set_string("sent:" .. name, "")
	local tickets, kept = S.tickets(), {}
	for _, ticket in ipairs(tickets) do
		if ticket.from ~= name then kept[#kept + 1] = ticket end
	end
	if #kept < #tickets then S.save_tickets(kept) end
	local rows = load_index()
	local row = rows[name:lower()]
	if row and row.name == name then
		rows[name:lower()] = nil
		save("factions", rows)
	end
end

return S
