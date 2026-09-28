-- Portable planner_source (zones.lua runtime) for coarse analytic sampling.
-- No roads, no capital streets: terrain/biome only. LuaJIT.
return function(repo, seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local tdata = dofile(dir .. "/terrain_data.lua")
	local source = dofile(dir .. "/source/simple_map.lua")
	local simple_map_factory = dofile(dir .. "/simple_map.lua")(dofile(dir .. "/zone_field.lua"))
	-- No capital layouts are planned here: no column is inside a protected
	-- city (terrain and biome are unaffected; only claims would differ).
	local protection_holder = {shapes = setmetatable({}, {__index = function()
		return {member = function() return false end}
	end})}
	local function horizontal_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.capital_protection = protection_holder
		return simple_map_factory(bound)
	end
	local water = {module = dofile(dir .. "/water_layout.lua")(tdata.water),
		authored = dofile(dir .. "/water_authored.lua")(tdata.water), plot_rects = {}}
	local hf = dofile(dir .. "/height.lua")
	-- The start towns' ground (as r7_runtime.lua fills it).
	_G.core = _G.core or {}
	local settlement = dofile(dir .. "/r7_settlement.lua")
	local palette = dofile(dir .. "/../wp13/palette.lua")
	local TWIN = {["default:dirt_with_dry_grass"] = "default:dry_dirt_with_dry_grass"}
	local start_grounds = {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "start" then
			local ground = palette.races[profile.race].ground
			start_grounds[profile.anchor_id] = {ground = TWIN[ground] or ground}
		end
	end
	local function height_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.water = water
		bound.start_grounds = start_grounds
		return hf(bound)
	end
	local zones = dofile(dir .. "/zones.lua")({source = source,
		schemas = dofile(dir .. "/schemas.lua"), canonical = dofile(dir .. "/canonical.lua"),
		deterministic = dofile(dir .. "/deterministic.lua"),
		index128 = dofile(dir .. "/index128.lua"), horizontal_factory = horizontal_factory,
		height_factory = height_factory,
		terrain_field = dofile(dir .. "/terrain_field.lua")(tdata), raw_sha256 = sha})
	local session, planner_source = zones.new_with_planner_source_runtime(seed, 1)
	return {session = session, planner_source = planner_source, source = source}
end
