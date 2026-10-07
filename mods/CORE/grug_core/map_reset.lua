-- The hosting platform's map reset (the upgrade contract, Round 41 ruling 9;
-- docs/technical/upgrade-contract.md). The platform empties the map table
-- while the server is stopped and raises the platform-owned setting
-- `grug_reset_world`; the game does the rest:
--   the world:     a setting above the world's record clears the map-bound
--                  mod-storage state of every mod during that mod's own load
--                  (grug_core.map_reset.clear), and the record takes the
--                  setting once every mod has loaded;
--   a character:   one whose record is below the world's is moved to its race
--                  start on its next join (grug_classes/selection.lua holds it
--                  until the preparation is ready and the start has loaded),
--                  loses its map-bound player state (register_on_relocate) and
--                  only then takes the world's record.
-- A missing record is 0. A new character, or one without a stored race, takes
-- the world's record without a move. Nothing else about a character changes.
--
-- World record: this mod's storage, key "reset_world". Character record:
-- player meta "grug_core:reset_world".
local storage = core.get_mod_storage()
local WORLD_KEY = "reset_world"
local PLAYER_KEY = "grug_core:reset_world"
-- The character-creation rule reads the stored race itself, never the
-- creation stasis (grug_core.player_in_creation_stasis).
local RACE_KEY = "grug_classes:race"

local M = {}
grug_core.map_reset = M

local setting = math.floor(tonumber(core.settings:get("grug_reset_world")) or 0)
local record = storage:get_int(WORLD_KEY)
local pending = setting > record
-- The world's applied value: the setting once this start applies it.
M.applied = pending and setting or record

-- Whether this start clears the map-bound state.
function M.pending()
	return pending
end

-- Runs `fn`, which clears `owner`'s map-bound state, when this start applies
-- a reset; call it during the owner's own load, before the state is read.
-- Clears are idempotent (a start that stops before the record is written runs
-- them again) and keep monotonic counters and the preparation mode. A failing
-- clear stops the load: the world never starts half cleared.
function M.clear(owner, fn)
	if not pending then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		error(("[grug_core] map reset %d: clearing %s failed, the server does not start: %s"):
			format(setting, owner, tostring(err)), 0)
	end
	core.log("action", ("[grug_core] map reset %d: cleared %s"):format(setting, owner))
end

-- After every mod's load, so after every clear.
core.register_on_mods_loaded(function()
	if pending then
		storage:set_int(WORLD_KEY, setting)
		core.log("action", ("[grug_core] map reset %d applied to the world (was %d)"):
			format(setting, record))
	end
end)

-- A created character whose record is below the world's.
function M.needs_relocation(player)
	local meta = player:get_meta()
	return meta:get_string(RACE_KEY) ~= "" and meta:get_int(PLAYER_KEY) < M.applied
end

function M.record(player)
	local meta = player:get_meta()
	if meta:get_int(PLAYER_KEY) ~= M.applied then
		meta:set_int(PLAYER_KEY, M.applied)
	end
end

-- fn(player) clears one piece of map-bound player state (the home claim,
-- grug_home/claim_home.lua) after the relocation teleport.
local relocate_callbacks = {}
function M.register_on_relocate(fn)
	relocate_callbacks[#relocate_callbacks + 1] = fn
end

-- Called once the relocation teleport is done: the map-bound player state
-- goes, then the record is written.
function M.relocated(player)
	for _, fn in ipairs(relocate_callbacks) do
		fn(player)
	end
	M.record(player)
	core.log("action", ("[grug_core] map reset %d: %s moved to the race start"):
		format(M.applied, player:get_player_name()))
end

core.register_on_newplayer(M.record)
core.register_on_joinplayer(function(player)
	if player:get_meta():get_string(RACE_KEY) == "" then
		M.record(player)
	end
end)
