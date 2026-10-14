-- Mail storage (mail plan §3.10): grug_mail's mod storage, `core.serialize`.
-- Offline player meta cannot be written (ObjectRef:get_meta needs a live
-- object), so every mailbox lives here, read and written whole:
--   box:<name>    one player's mailbox (model.lua)
--   tickets       the admin inbox, every player's messages to the admin
--   broadcasts    the "All players" letters, stored once
--   factions      the recipient index: lower-case name -> {name, faction}
--   next_id       the id counter of letters, tickets and broadcasts
-- The per-player read set of the broadcasts is player meta
-- (`grug_mail:broadcasts_read`); the player is online whenever it changes.
-- Expired entries are pruned when a list is read, never by a pass over every
-- player. Mail is not map-bound: a map reset clears none of it.

local M = grug_mail.model
local storage = core.get_mod_storage()
local S = {}

local READ_KEY = "grug_mail:broadcasts_read"

local function now() return os.time() end
S.now = now

local function load(key)
	local raw = storage:get_string(key)
	if raw == "" then return nil end
	local value = core.deserialize(raw)
	if type(value) ~= "table" then
		core.log("error", "[grug_mail] unreadable mod storage key " .. key ..
			"; it starts empty")
		return nil
	end
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

function S.tickets()
	local tickets = load("tickets") or {}
	if M.prune(tickets, now()) > 0 then S.save_tickets(tickets) end
	return tickets
end

function S.save_tickets(tickets)
	save("tickets", tickets)
end

function S.broadcasts()
	local broadcasts = load("broadcasts") or {}
	if M.prune(broadcasts, now()) > 0 then S.save_broadcasts(broadcasts) end
	return broadcasts
end

function S.save_broadcasts(broadcasts)
	save("broadcasts", broadcasts)
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

return S
