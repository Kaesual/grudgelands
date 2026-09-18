-- Function-style KAT for the carrier-neutral mobs_redo AOC compensation.

local function run(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	local mutation = tonumber(os.getenv("MUTATION") or "") or 0
	local budget = dofile(repo .. "/mods/ENTITIES/mobs/grug_tag_budget.lua")
	if mutation == 1 then
		budget.effective_count = function(_, _, raw_count) return raw_count end
	end
	local scans = 0
	local objects = {
		{get_luaentity = function() return {name = "grug_core:tag_carrier"} end},
		{get_luaentity = function() return {name = "grug_core:tag_carrier"} end},
		{get_luaentity = function() return {name = "grug_mobs:stag"} end},
		{get_luaentity = function() return nil end},
	}
	local core_api = {get_objects_in_area = function(minp, maxp)
		scans = scans + 1
		assert(minp.x == 16 and maxp.x == 63,
			"scan is not aligned to the candidate's three-block X span")
		assert(minp.y == -32 and maxp.y == 15,
			"scan is not aligned to the candidate's three-block Y span")
		return objects
	end}
	assert(budget.effective_count(core_api, {x = 33, y = -1, z = 8},
		255, 256) == 255, "sub-limit count changed")
	assert(scans == 0, "sub-limit count paid for an object scan")
	assert(budget.effective_count(core_api, {x = 33, y = -1, z = 8},
		257, 256) == 255, "carriers were not removed from wider AOC")
	assert(scans == 1, "rejection path did not scan exactly once")
	return "r8_tag_spawn_budget=257_raw 2_carriers 255_effective lazy_scan\n"
end

return run
