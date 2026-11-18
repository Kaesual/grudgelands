-- character.delete (Round 83, docs/technical/web-bridge.md "character.delete";
-- round83-plan.md §3.3): the website erases a character, online or offline.
-- commands.lua checks the arguments and calls D.start; init.lua adds the
-- login guards (D.blocked, D.on_join). The sequence:
--   0. at arrival, synchronous: existence, the character id, the refusals,
--      the deadline; then the name is blocked at pre-join and the answer
--      waits (the ledger's defer, link.lua);
--   1. online: disconnect; for everyone: wait until the engine is done with
--      the player (it saves a leaving player after its leave hooks, and only
--      then drops it from core.objects_by_guid, whose key for a player is its
--      name; a removal before that would be undone by that save);
--   2. one call: every mod's clear (grug_core.character_delete), the
--      tombstone first;
--   3. wait one mod-storage commit (server_map_save_interval), so the clears
--      are on disk before the login goes;
--   4. one call: the clears again (a letter or a queued grant that arrived
--      meanwhile), then the engine's player record and auth entry; the
--      answer, whose one log line is the link's.
-- Step 2 starts only while D.margin() seconds remain before the command's
-- expires_at, and step 4 only before it, so nothing destructive runs after
-- it: a player not gone by then answers `expired`, disconnected and not
-- deleted (after step 2: not completely; the login stays refused until a
-- retry finishes it). Every deferred step runs
-- under pcall (an error in a core.after job ends the server) and answers
-- `error`. A shutdown loses a running deletion unanswered; it is idempotent,
-- the website's retry finishes it.

local D = {}

D.TEXT = "This character was deleted on the website."
D.POLL = 0.1        -- seconds between two looks at a leaving player
D.SLACK = 4         -- seconds besides one commit wait that step 2 needs left
D.MARGIN_MIN = 10
D.ZOMBIE_SECONDS = 120

local running = {}  -- lower-case name -> the deletion under way

local function log(level, text)
	core.log(level, "[grug_bridge] " .. text)
end

-- One mod-storage commit and a step.
local function commit_wait()
	local interval = tonumber(core.settings:get("server_map_save_interval")) or 5.3
	return interval + 0.5
end

-- The seconds that must remain before expires_at when step 2 starts.
function D.margin()
	return math.max(D.MARGIN_MIN, commit_wait() + D.SLACK)
end

-- Whether the engine is done with the player (step 1).
function D.gone(name)
	return core.get_player_by_name(name) == nil and core.objects_by_guid[name] == nil
end

-- Whether a deletion of `name` (any letter case) is under way: pre-join
-- refuses it.
function D.blocked(name)
	return running[name:lower()] ~= nil
end

local function finish(job, code, message)
	running[job.key] = nil
	job.done(code, message)
end

local function fail(job, err)
	log("error", "a deletion failed: " .. tostring(err))
	local ok, failure = pcall(finish, job, "error", "The deletion failed; see the server log.")
	if not ok then log("error", "its answer failed: " .. tostring(failure)) end
end

-- A deferred step, guarded.
local function step(job, func)
	return function()
		local ok, err = pcall(func, job)
		if not ok then fail(job, err) end
	end
end

local wait_gone, clear, remove

local function past_deadline(job)
	return os.time() >= job.expires_at - D.margin()
end

local function expired(job)
	finish(job, "expired", job.name .. (job.cleared and
		" was not deleted completely: the command expired first. Send it again." or
		" was not deleted: the command expired first."))
end

-- Step 1.
wait_gone = function(job)
	if past_deadline(job) then return expired(job) end
	if not D.gone(job.name) then
		core.after(D.POLL, step(job, wait_gone))
		return
	end
	clear(job)
end

-- Step 2, then step 3.
clear = function(job)
	grug_core.character_delete.clear(job.name)
	job.cleared = true
	core.after(commit_wait(), step(job, remove))
end

-- Step 4. A server that lagged past expires_at removes nothing any more.
remove = function(job)
	if os.time() >= job.expires_at then return expired(job) end
	if not D.gone(job.name) then
		-- Back in the game: a connection that passed pre-join before the
		-- deletion began. Once more from the disconnect, within the deadline.
		core.disconnect_player(job.name, D.TEXT)
		return wait_gone(job)
	end
	grug_core.character_delete.clear(job.name)
	if core.remove_player(job.name) == 2 then error("the player is still connected") end
	core.remove_player_auth(job.name)
	finish(job, "ok", ("%s (%s) deleted by admin %s."):format(job.name,
		job.id and ("character " .. job.id) or "no character id", job.admin))
end

local function begin(job)
	running[job.key] = job
	local ok, err = pcall(function()
		if core.get_player_by_name(job.name) then core.disconnect_player(job.name, D.TEXT) end
		core.after(0, step(job, wait_gone))
	end)
	if not ok then fail(job, err) end
end

-- True when a login of `name` in another letter case exists.
local function other_case(name)
	local lower = name:lower()
	for other in core.get_auth_handler().iterate() do
		if other ~= name and other:lower() == lower then return true end
	end
	return false
end

-- Step 0. The arguments are checked (commands.lua); `defer` is the ledger's.
-- Answers a code and a message, or nothing after calling defer().
function D.start(name, character_id, admin, expires_at, defer)
	local auth = core.get_auth_handler().get_auth(name)
	local entry = grug_accounts.index_entry(name)
	local indexed = entry ~= nil and entry ~= grug_accounts.TOMBSTONE
	-- Without a login, an index id still names a character a deletion left
	-- half done (its retry finishes it), unless the name is another
	-- character's in another letter case (the index is lower case).
	if not auth and not (indexed and not other_case(name)) then
		return "unknown_target", "There is no character called " .. name .. "."
	end
	local player = core.get_player_by_name(name)
	local id = player and grug_accounts.character_id(player) or (indexed and entry or nil)
	-- A tombstone beside a login: a deletion of this character stopped after
	-- its clears (an error, an expiry, a crash after the commit). The website's
	-- retry carries the id it knows and finishes it; the game has none left to
	-- compare (the index holds the tombstone, the record is offline).
	local resumed = auth and not player and entry == grug_accounts.TOMBSTONE
	if resumed then
		id = character_id
	elseif character_id and character_id ~= id then
		return "unknown_target", name .. " has another character id."
	end
	local server_admin = core.settings:get("name") or ""
	if server_admin ~= "" and server_admin:lower() == name:lower() then
		return "refused", name .. " is the server administrator's character."
	end
	if D.blocked(name) then
		return "refused", name .. " is already being deleted."
	end
	if os.time() >= expires_at - D.margin() then
		return "expired", "The command expires too soon for a deletion."
	end
	begin({key = name:lower(), name = name, id = id, admin = admin,
		expires_at = expires_at, done = defer()})
end

-- The record_login guard's second half (init.lua): a character that joins
-- without a login passed pre-join before a deletion removed it. It is a new,
-- empty character (the record was gone); it leaves again and its record
-- goes, by the same sequence without an answer.
function D.on_join(player)
	local name = player:get_player_name()
	if core.get_auth_handler().get_auth(name) then return end
	log("warning", "a character joined without a login (deleted during its connection): disconnected")
	core.disconnect_player(name, D.TEXT)
	if D.blocked(name) then return end
	begin({key = name:lower(), name = name, admin = "", expires_at = os.time() + D.ZOMBIE_SECONDS,
		done = function() end})
end

return D
