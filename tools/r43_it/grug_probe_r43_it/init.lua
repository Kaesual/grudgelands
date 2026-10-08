-- Disposable engine probe (Round 43 lane IT: world migrations end to end).
-- Never shipped: tools/r43_it/it.py stages it through tools/luanti_headless.sh
-- for each boot of a test world. It asserts nothing: it writes what the game
-- saw to <world>/r43_it_obs.json and it.py checks it.
--   at load       grug_core.world_version's decision (new world, the version
--                 the start began from, the steps the guard knows), the map
--                 reset's state and this mod's storage (a step's offline
--                 write and delete);
--   mods loaded   the test steps' log (grug_it_log, tools/r43_it/
--                 grug_test_migrations.lua): world handlers run in
--                 grug_core's on_mods_loaded, which comes before this one;
--   each join     right after grug_core's migration runner (this callback is
--                 moved to the second place): the character's meta, its first
--                 main slot, the fly privilege, its pending markers and the
--                 log;
--   then          once every character the plan names has left again
--                 (tools/r43_it/client.py joins them), or a few seconds after
--                 the first server step when it names none, it writes the
--                 file and shuts the server down.
-- The plan: <world>/r43_it_plan.json {"phase": "...", "joins": [names],
-- "seed_storage": true|false}; seed_storage writes the keys a later step
-- deletes or keeps.

local P = "[r43_it_probe] "
local world = core.get_worldpath()
local storage = core.get_mod_storage()
local wv = grug_core.world_version
local reset = grug_core.map_reset

local function log(msg) core.log("action", P .. msg) end

local function read(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local plan = core.parse_json(read(world .. "/r43_it_plan.json") or "") or {}
local expected = plan.joins or {}

local function copy_log()
	local out = {}
	for i, entry in ipairs(rawget(_G, "grug_it_log") or {}) do
		out[i] = table.copy(entry)
	end
	return out
end

local function pending_markers(meta)
	local out = {}
	for _, key in ipairs(meta:get_keys()) do
		if key:sub(1, #wv.CHARACTER_MARKER) == wv.CHARACTER_MARKER then
			out[#out + 1] = key:sub(#wv.CHARACTER_MARKER + 1)
		end
	end
	table.sort(out)
	return out
end

local obs = {
	phase = plan.phase or "?",
	load = {
		new_world = wv.new_world, from = wv.from, game = wv.game, steps = {},
		reset_pending = reset.pending(), reset_applied = reset.applied,
		offline = storage:get_string("offline"),
		offline_reset = storage:get_string("offline_reset"),
		delete_me = storage:get_string("delete_me"),
		keep = storage:get_string("keep"),
	},
	joins = {},
	leaves = 0,
}
for i, step in ipairs(wv.steps) do
	obs.load.steps[i] = step.version
end
if plan.seed_storage then
	storage:set_string("delete_me", "probe")
	storage:set_string("keep", "probe")
end
log(("phase %s: new_world=%s from=%s"):format(obs.phase, tostring(wv.new_world), tostring(wv.from)))

local function on_join(player)
	local name = player:get_player_name()
	local meta = player:get_meta()
	obs.joins[#obs.joins + 1] = {
		name = name,
		offline = meta:get_string("it:offline"),
		order = meta:get_string("it:order"),
		markers = pending_markers(meta),
		main1 = player:get_inventory():get_stack("main", 1):to_string(),
		fly = core.check_player_privs(name, {fly = true}),
		log = copy_log(),
	}
	log("joined " .. name)
end
core.register_on_joinplayer(on_join)

core.register_on_mods_loaded(function()
	obs.mods_loaded = {log = copy_log()}
	local joins = core.registered_on_joinplayers
	for i, fn in ipairs(joins) do
		if fn == on_join then
			table.insert(joins, 2, table.remove(joins, i))
			break
		end
	end
	local info = debug.getinfo(joins[1], "S")
	obs.first_join_callback = info and info.source or "?"
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r43 it probe done") end)
end

core.register_on_leaveplayer(function(player)
	obs.leaves = obs.leaves + 1
	log("left " .. player:get_player_name())
	if obs.leaves >= #expected then
		core.after(1, finish, "every planned character left")
	end
end)

core.after(0, function()
	if #expected == 0 then
		core.after(3, finish, "no joins planned")
	end
	core.after(150, finish, "timeout: not every planned character joined and left")
end)
