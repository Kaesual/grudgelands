-- Round 43 lane IT: the test-only migration steps on the game's side. Never
-- shipped, never declared. tools/r43_it/it.py copies this file into a test
-- world; grug_core's test hook (grug_core/world_version.lua: the setting
-- grug_test_migrations = true) runs it from the world directory before the
-- guard. The world's r43_it_plan.json names the steps this boot's game knows
-- ("steps"), the same the tool ran (their offline part:
-- tools/r43_it/steps.py).
--   0.41.1  offline writes only, no online work
--   0.41.2  world work at the next load
--   0.41.3  character work at the next join
--   0.41.4  character work at the next join (the same character as 0.41.3,
--           so the two markers must run in step order)
--   0.41.5  world work at the next load (with a map reset: after the clears)
-- Each handler notes its call in the global grug_it_log, which the probe
-- grug_probe_r43_it reads; a character handler also appends its version to
-- the player meta key it:order, which the engine saves.
grug_it_log = rawget(_G, "grug_it_log") or {}
local log = grug_it_log
local MARKER = "grug_core:migrate:"

local function character(version)
	return function(player, marker)
		local meta = player:get_meta()
		local pending = {}
		for _, key in ipairs(meta:get_keys()) do
			if key:sub(1, #MARKER) == MARKER then
				pending[#pending + 1] = key:sub(#MARKER + 1)
			end
		end
		table.sort(pending)
		log[#log + 1] = {kind = "character", step = version, marker = marker,
			name = player:get_player_name(), pending = pending}
		meta:set_string("it:order", meta:get_string("it:order") .. version .. ";")
	end
end

local function world(version)
	return function(marker)
		log[#log + 1] = {kind = "world", step = version, marker = marker,
			reset_pending = grug_core.map_reset.pending(),
			reset_applied = grug_core.map_reset.applied}
	end
end

local all = {
	{version = "0.41.1"},
	{version = "0.41.2", world = world("0.41.2")},
	{version = "0.41.3", character = character("0.41.3")},
	{version = "0.41.4", character = character("0.41.4")},
	{version = "0.41.5", world = world("0.41.5")},
}

local f = io.open(core.get_worldpath() .. "/r43_it_plan.json", "r")
local plan = f and core.parse_json(f:read("*a")) or {}
if f then f:close() end
local known = {}
for _, version in ipairs(plan.steps or {}) do
	known[version] = true
end
local steps = {}
for _, step in ipairs(all) do
	if known[step.version] then
		steps[#steps + 1] = step
	end
end
return steps
