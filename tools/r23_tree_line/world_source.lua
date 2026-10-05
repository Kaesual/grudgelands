-- Portable planner_source (zones.lua runtime) for coarse analytic sampling,
-- through the shared `wp40/world_assembly.lua`. No roads, no capital
-- streets: terrain/biome only. LuaJIT.
return function(repo, seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	_G.core = _G.core or {}
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local A = dofile(dir .. "/world_assembly.lua")(dir, sha)
	-- No capital layouts are planned here: no column is inside a protected
	-- city (terrain and biome are unaffected; only claims would differ).
	local W = A.world(seed, nil, {roads = false,
		protection = setmetatable({}, {__index = function()
			return {member = function() return false end}
		end})})
	-- The horizontal session zones.lua builds is kept for fixtures that read
	-- the raw zone field (tools/r24_mobs).
	local captured = {}
	local horizontal_factory = W.horizontal_factory
	W.horizontal_factory = function(deps)
		local module = horizontal_factory(deps)
		local new = module.new
		module.new = function(...)
			captured.horizontal = new(...)
			return captured.horizontal
		end
		return module
	end
	local session, planner_source = W.zones().new_with_planner_source_runtime(seed, 1)
	return {session = session, planner_source = planner_source, source = A.source,
		horizontal = captured.horizontal}
end
