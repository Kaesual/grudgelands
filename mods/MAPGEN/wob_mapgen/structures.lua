-- Post-generation pass for the few things biomes cannot express:
--  * spawn camp platforms (walkable, guaranteed flat ground at both faction
--    spawns; placeholder until WP13 ships real capital structures)
--  * the soft east-west world border: a mountain wall at |x| ~ 2000 that
--    keeps content density high (docs/design/world.md §1)

local WALL_X = wob_core.WORLD_HALF_WIDTH_X
local WALL_THICKNESS = 16
local CAMP_HALF = wob_core.CAMP_HALF
local PLATFORM_Y = wob_core.CAMP_PLATFORM_Y
local CLEAR_TOP = wob_core.CAMP_CLEAR_TOP
local SKIRT_DEPTH = 16 -- platform base reaches this far below the surface

local c_air = core.get_content_id("air")
local c_stone = core.get_content_id("default:stone")
local c_cobble = core.get_content_id("default:cobble")

-- Jagged wall crest between ~68 and ~108 so it reads as a mountain range.
local wall_noise
local function wall_top(x, z)
	wall_noise = wall_noise or core.get_perlin({
		offset = 88, scale = 20,
		spread = {x = 160, y = 160, z = 160},
		seed = 52731, octaves = 2, persist = 0.6,
	})
	return math.floor(wall_noise:get_2d({x = x, y = z}))
end

local wall_bands = {
	{x_min = WALL_X, x_max = WALL_X + WALL_THICKNESS - 1},
	{x_min = -WALL_X - WALL_THICKNESS + 1, x_max = -WALL_X},
}

local function build_wall(data, area, minp, maxp)
	for _, band in ipairs(wall_bands) do
		local x1 = math.max(minp.x, band.x_min)
		local x2 = math.min(maxp.x, band.x_max)
		for x = x1, x2 do
			for z = minp.z, maxp.z do
				local y2 = math.min(maxp.y, wall_top(x, z))
				if y2 >= minp.y then
					local idx = area:index(x, minp.y, z)
					for _ = minp.y, y2 do
						data[idx] = c_stone
						idx = idx + area.ystride
					end
				end
			end
		end
	end
end

local function build_camp(data, area, minp, maxp, spawn)
	local x1 = math.max(minp.x, spawn.x - CAMP_HALF)
	local x2 = math.min(maxp.x, spawn.x + CAMP_HALF)
	local z1 = math.max(minp.z, spawn.z - CAMP_HALF)
	local z2 = math.min(maxp.z, spawn.z + CAMP_HALF)
	local base_y = math.max(minp.y, PLATFORM_Y - SKIRT_DEPTH)
	local top_y = math.min(maxp.y, PLATFORM_Y)
	local clear_y1 = math.max(minp.y, PLATFORM_Y + 1)
	local clear_y2 = math.min(maxp.y, CLEAR_TOP)
	for x = x1, x2 do
		for z = z1, z2 do
			for y = base_y, top_y do
				data[area:index(x, y, z)] = c_cobble
			end
			for y = clear_y1, clear_y2 do
				data[area:index(x, y, z)] = c_air
			end
		end
	end
end

core.register_on_generated(function(minp, maxp, blockseed)
	local need_wall =
		(maxp.x >= wall_bands[1].x_min and minp.x <= wall_bands[1].x_max) or
		(maxp.x >= wall_bands[2].x_min and minp.x <= wall_bands[2].x_max)

	local camps = {}
	for _, def in pairs(wob_core.factions) do
		local s = def.spawn
		if maxp.x >= s.x - CAMP_HALF and minp.x <= s.x + CAMP_HALF and
				maxp.z >= s.z - CAMP_HALF and minp.z <= s.z + CAMP_HALF and
				maxp.y >= PLATFORM_Y - SKIRT_DEPTH and minp.y <= CLEAR_TOP then
			camps[#camps + 1] = s
		end
	end

	if not need_wall and #camps == 0 then
		return
	end

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()

	if need_wall then
		build_wall(data, area, minp, maxp)
	end
	for _, spawn in ipairs(camps) do
		build_camp(data, area, minp, maxp, spawn)
	end

	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map()
end)
