-- The world version, the start guard and the online migration work (Round 43;
-- the hosting platform's migration contract R6 and R7,
-- docs/technical/upgrade-contract.md). Loaded first in grug_core, before any
-- of this game's code reads or writes saved state (the map-reset clears
-- included); the mods that can load before grug_core write none at load.
--
-- The record: this mod's storage, key "world_version", a major.minor.patch
-- string. A missing record on an existing world is 0.41.0, the baseline; a
-- new world counts as this game's version.
-- The guard, at load: a world newer than this game, or one with a migration
-- step between its record and this game's version, refuses to start.
-- Otherwise the game writes its own version into the record once the load
-- has succeeded (the first server step).
-- Online work: the steps' world markers run once every mod has loaded, the
-- character markers at a join (grug_core/migrations.lua).
--
-- It is independent of the map reset's record "reset_world"
-- (grug_core/map_reset.lua): that one counts map resets and drives the
-- clears; this one names the game version that last started the world and
-- drives the guard. A move that combines both passes the guard, then resets.
local storage = core.get_mod_storage()
local RECORD_KEY = "world_version"
local WORLD_MARKER = "migrate_world:"
local CHARACTER_MARKER = "grug_core:migrate:"
local BASELINE = "0.41.0"
-- The test hook: undeclared test steps for the integration tests, read before
-- the guard. Only when this setting is true (no shipped configuration sets
-- it, settingtypes.txt does not list it), the file of that name in the world
-- directory returns a list of {version = "x.y.z", world = fn, character = fn}.
local TEST_SETTING = "grug_test_migrations"
local TEST_FILE = "grug_test_migrations.lua"

local M = {}
grug_core.world_version = M
M.RECORD_KEY = RECORD_KEY
M.WORLD_MARKER = WORLD_MARKER
M.CHARACTER_MARKER = CHARACTER_MARKER
M.BASELINE = BASELINE

-- {major, minor, patch} of a major.minor.patch string, else nil.
function M.parse(text)
	if type(text) ~= "string" then
		return nil
	end
	local a, b, c = text:match("^(%d+)%.(%d+)%.(%d+)$")
	if not a then
		return nil
	end
	return {tonumber(a), tonumber(b), tonumber(c)}
end

-- Whether parsed version `a` comes before `b`.
function M.before(a, b)
	for i = 1, 3 do
		if a[i] ~= b[i] then
			return a[i] < b[i]
		end
	end
	return false
end

-- The steps in step order: the registry's declared versions with their
-- handlers, plus the test steps of the hook. Raises on a malformed entry.
function M.collect(registry, tests)
	local steps, seen = {}, {}
	local function add(version, handlers, origin)
		local parsed = M.parse(version)
		if not parsed then
			error(("[grug_core] %s: %q is no major.minor.patch version"):format(origin, tostring(version)), 0)
		end
		if seen[version] then
			error(("[grug_core] %s: the step %s is listed twice"):format(origin, version), 0)
		end
		seen[version] = true
		steps[#steps + 1] = {version = version, parsed = parsed,
			world = handlers.world, character = handlers.character}
	end
	for _, version in ipairs(registry.versions) do
		add(version, registry.handlers[version] or {}, "grug_core.migrations")
	end
	for version in pairs(registry.handlers) do
		if not seen[version] then
			error(("[grug_core] grug_core.migrations: handlers for %s, which is no listed step"):
				format(tostring(version)), 0)
		end
	end
	for _, test in ipairs(tests or {}) do
		add(test.version, test, "the test steps")
	end
	table.sort(steps, function(a, b) return M.before(a.parsed, b.parsed) end)
	return steps
end

-- New-world recognition, conservative (in doubt, existing). A world is new
-- only when nothing of an earlier start is there:
--   this mod's storage holds no key at all (every start that loaded grug_core
--   wrote the world preparation's mode, starts_preload.lua);
--   the world directory holds no env_meta.txt (the engine writes it whenever
--   an environment ran: each map save interval and at shutdown);
--   the world directory holds no players.sqlite and no players directory (the
--   SQLite and files player backends; characters exist only once an
--   environment ran, so a PostgreSQL player backend is covered by the two
--   above). Auth entries are never looked at: a platform may create them
--   before the first start.
function M.is_new_world(storage_keys, world_files, world_dirs)
	if #storage_keys > 0 then
		return false
	end
	for _, name in ipairs(world_files) do
		if name == "env_meta.txt" or name == "players.sqlite" then
			return false
		end
	end
	for _, name in ipairs(world_dirs) do
		if name == "players" then
			return false
		end
	end
	return true
end

-- The guard's decision. Returns the world's version (the record, else what a
-- missing record counts as), or nil and the error the server stops with.
function M.decide(record, new_world, game, steps, world_path)
	local from = record
	if from == "" then
		from = new_world and game or BASELINE
	end
	local current, start = M.parse(game), M.parse(from)
	if not current then
		return nil, ("[grug_core] game.conf names no major.minor.patch version (%q); " ..
			"the server does not start"):format(tostring(game))
	end
	if not start then
		return nil, ("[grug_core] the world's version record %q is no major.minor.patch " ..
			"version; the server does not start: restore the world from its backup"):format(from)
	end
	if M.before(current, start) then
		return nil, ("[grug_core] This world is at version %s, newer than this game's " ..
			"version %s; the server does not start: downgrade to %s to continue."):
			format(from, game, from)
	end
	local due = {}
	for _, step in ipairs(steps) do
		if M.before(start, step.parsed) and not M.before(current, step.parsed) then
			due[#due + 1] = step.version
		end
	end
	if #due > 0 then
		return nil, ("[grug_core] This world is at version %s and needs the migration " ..
			"%s %s before this game's version %s can start it; the server does not " ..
			"start: back up the world and run the tool from the game's repository root: " ..
			"python3 tools/migrate.py --world %s"):format(from,
			#due == 1 and "step" or "steps", table.concat(due, ", "), game, world_path)
	end
	return from
end

-- Runs the pending world markers in step order: each handler gets the
-- marker's value, the marker goes after it succeeded. Raises on a failure:
-- the server does not start and the next start runs the marker again.
function M.run_world(store, steps)
	for _, step in ipairs(steps) do
		local key = WORLD_MARKER .. step.version
		local marker = store:get_string(key)
		if marker ~= "" then
			local ok, err = false, "the step has no world handler"
			if step.world then
				ok, err = pcall(step.world, marker)
			end
			if not ok then
				error(("[grug_core] migration %s: the world's online work failed, the server " ..
					"does not start: %s"):format(step.version, tostring(err)), 0)
			end
			store:set_string(key, "")
			core.log("action", ("[grug_core] migration %s: the world's online work is done"):
				format(step.version))
		end
	end
end

-- Runs a joining character's pending markers in step order. On a failure the
-- character is held: an administrator sees a severe error, the player is
-- disconnected with a short message and the marker stays, so the next join
-- runs it again. Returns false then.
function M.run_character(player, steps)
	local meta = player:get_meta()
	local name = player:get_player_name()
	for _, step in ipairs(steps) do
		local key = CHARACTER_MARKER .. step.version
		local marker = meta:get_string(key)
		if marker ~= "" then
			local ok, err = false, "the step has no character handler"
			if step.character then
				ok, err = pcall(step.character, player, marker)
			end
			if not ok then
				grug_core.severe.report("grug_core",
					("Migration %s: updating the character %s failed; the character is held")
						:format(step.version, name),
					tostring(err), "migrate:" .. step.version .. ":" .. name)
				core.disconnect_player(name, "Your character could not be updated to " ..
					"this game version. Please tell an administrator; joining again retries.")
				return false
			end
			meta:set_string(key, "")
			core.log("action", ("[grug_core] migration %s: %s's online work is done"):
				format(step.version, name))
		end
	end
	return true
end

-- At load: the game's version, the test hook, the guard.
local info = core.get_game_info()
local game = info and info.path and Settings(info.path .. "/game.conf"):get("version")
local world_path = core.get_worldpath()
local tests
if core.settings:get_bool(TEST_SETTING, false) then
	tests = dofile(world_path .. "/" .. TEST_FILE)
	core.log("warning", ("[grug_core] %s is set: %d test migration step(s) from %s"):
		format(TEST_SETTING, #tests, TEST_FILE))
end
M.steps = M.collect(grug_core.migrations, tests)
local record = storage:get_string(RECORD_KEY)
M.new_world = record == "" and M.is_new_world(storage:get_keys(),
	core.get_dir_list(world_path, false), core.get_dir_list(world_path, true))
local from, refusal = M.decide(record, M.new_world, game, M.steps, world_path)
if not from then
	error(refusal, 0)
end
M.game = game
-- The world's version this start began from.
M.from = from
core.log("action", ("[grug_core] world version %s%s, game %s: no migration step due"):format(
	from, record ~= "" and "" or (M.new_world and " (a new world)" or " (no record)"), game))

core.register_on_mods_loaded(function()
	M.run_world(storage, M.steps)
	-- The record once the load has succeeded: every mod and every
	-- register_on_mods_loaded callback ran without an error.
	core.after(0, function()
		if storage:get_string(RECORD_KEY) ~= game then
			storage:set_string(RECORD_KEY, game)
			core.log("action", ("[grug_core] world version %s recorded (was %s)"):format(game,
				record ~= "" and record or (M.new_world and "none, a new world" or
					"none, an existing world: " .. BASELINE)))
		end
	end)
end)

-- The first join callback of all, so a step's character work is done before
-- any other join callback reads that character (the map reset's relocation
-- included, which runs later still).
local function on_join(player)
	M.run_character(player, M.steps)
end
core.register_on_joinplayer(on_join)
local joins = core.registered_on_joinplayers
assert(joins[#joins] == on_join)
table.remove(joins, #joins)
table.insert(joins, 1, on_join)
