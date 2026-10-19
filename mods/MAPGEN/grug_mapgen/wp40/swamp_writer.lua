-- Round 47 lane SW: the swamp pass of the R7 successor settle (after the
-- road dressing, before P9G, world content, anchors and settlements; plan
-- ruling 23, tools/r47_sw/DESIGN.md). It writes what the surface rows and
-- the decoration rows cannot express, from the world's pools
-- (swamp_pools.lua, the same object the surface selector, the planner and
-- the writer's surface skin read):
--   * the pools: a kept pool column whose ground lies one above its level
--     loses its top node (only when nothing but air or a plant stands on
--     it), then water sources fill the level (and the node below in a
--     2-deep column) in place of the mud; where the top stays, the column
--     keeps its mud and gets no water. The pool rule keeps every side of
--     every water node solid or water of the same level, and the surface
--     skin stays closed round a pool, so no water can flow;
--   * on the water: waterlilies on inner pool columns, reeds rooted in the
--     mud bed of bank pool columns (grug_nodes:mud_with_reeds, a leveled
--     plantlike_rooted node: up through the water and 1-2 above it);
--   * on the bank (the dry swamp columns beside a pool): reeds 1-2 high,
--     cattails and moss carpets.
-- Every write goes through `write_road` (plain nodes, as the road and arena
-- dressing write), only inside the owner, only over the node the pass
-- expects there (a swamp ground, or air for a plant); anything else keeps
-- what it has, which never opens a pool (DESIGN.md: a column that keeps its
-- ground is always safe).
--
--   local swamp = dofile(wp40 .. "/swamp_writer.lua")
--   swamp.NATURAL_NAMES          the nodes the pass places (runtime renewal)
--   swamp.config(core_api)       the successor's configuration: .new(deps)
local M = {}
-- The nodes the pass places, for runtime renewal's natural set
-- (vegetation_density.lua `extra_natural_names`).
M.NATURAL_NAMES = {"grug_mapgen:freshwater_waterlily", "grug_nodes:cattails",
	"grug_nodes:moss_carpet", "grug_nodes:mud_with_reeds", "grug_nodes:reeds"}
function M.config(core_api)
	local function fail(message) error("WP40 swamp writer: " .. message, 0) end
	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" then
		fail("construction seam differs")
	end
	local function cid(name)
		if not core_api.registered_nodes[name] then fail("node missing: " .. name) end
		return core_api.get_content_id(name)
	end
	local air = core_api.CONTENT_AIR or cid("air")
	local WATER = cid("default:water_source")
	local LILY = cid("grug_mapgen:freshwater_waterlily")
	local REEDS = cid("grug_nodes:reeds")
	local ROOTED = cid("grug_nodes:mud_with_reeds")
	local CATTAILS = cid("grug_nodes:cattails")
	local CARPET = cid("grug_nodes:moss_carpet")
	-- The swamp's grounds (surface tops and the mud filler).
	local GROUND = {}
	for _, name in ipairs({"grug_nodes:mud", "grug_nodes:mud_dry", "grug_nodes:mud_mottled",
			"grug_nodes:mud_with_wet_grass", "grug_nodes:swamp_moss"}) do
		GROUND[cid(name)] = true
	end
	-- A plant that may go where a pool takes its ground: not walkable, no
	-- liquid (grass, ferns, carpets and the like, also an engine decoration).
	local plant_by_cid = {}
	local function plant(c)
		local value = plant_by_cid[c]
		if value == nil then
			local def = core_api.registered_nodes[core_api.get_name_from_content_id(c)]
			value = def ~= nil and def.walkable == false and
				(def.liquidtype == nil or def.liquidtype == "none")
			plant_by_cid[c] = value
		end
		return value
	end

	-- Plant chances in percent (DESIGN.md "Plants").
	local LILY_PCT, ROOTED_PCT, REEDS_PCT, CATTAILS_PCT, CARPET_PCT = 22, 30, 32, 18, 12
	local SIDES = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

	local config = {}
	-- `dependencies`: the successor's (full_seed_string, planner_source,
	-- content); nil pools (no factory) make the pass a no-op.
	function config.new(dependencies)
		local pools = dependencies.content.swamp_pools(dependencies.full_seed_string,
			dependencies.planner_source)
		local writer = {}
		function writer.dress(context)
			if not pools or type(context.write_road) ~= "function" then return 0 end
			local inside, settled, write = context.inside_owner, context.settled_at,
				context.write_road
			local function at(x, y, z)
				if not inside(x, y, z) then return nil end
				return (settled(x, y, z))
			end
			local count = 0
			for z = context.min_z, context.max_z do
				for x = context.min_x, context.max_x do
					local _, _, _, biome = context.column_values_at(x, z)
					if biome == "grug_swamp" then
						local level, depth, ground = pools.at(x, z)
						if level then
							count = count + 1
							-- levelling: the top node one above the level goes
							local open = ground == level
							if ground == level + 1 and GROUND[at(x, ground, z)] then
								local above = at(x, ground + 1, z)
								if above == air or (above and plant(above)) then
									if above ~= air then write(x, ground + 1, z, air, 0) end
									write(x, ground, z, air, 0)
									open = true
								end
							elseif open then
								-- a plant on the ground that becomes water
								local above = at(x, level + 1, z)
								if above and above ~= air and plant(above) then
									write(x, level + 1, z, air, 0)
								end
							end
							-- Water (and the plants on it) only where the top is open:
							-- a kept top (something walkable stands on it, or it
							-- lies in the owner above) keeps its mud below too, so
							-- no water is hidden under ground; a kept column is
							-- always safe for its neighbours (swamp_pools.lua).
							if open then
								for y = level, level - depth + 1, -1 do
									if GROUND[at(x, y, z)] then write(x, y, z, WATER, 0) end
								end
							end
							local inner = true
							for _, d in ipairs(SIDES) do
								if not pools.at(x + d[1], z + d[2]) then inner = false end
							end
							local roll = pools.hash(x, z, 811) % 100
							if not open then
								-- nothing on a kept column
							elseif inner then
								if roll < LILY_PCT and at(x, level + 1, z) == air then
									write(x, level + 1, z, LILY, pools.hash(x, z, 823) % 4)
								end
							elseif roll < ROOTED_PCT then
								local bed = level - depth
								if GROUND[at(x, bed, z)] then
									local height = depth + 1 + pools.hash(x, z, 829) % 2
									write(x, bed, z, ROOTED, height * 16)
								end
							end
						else
							-- a bank: a dry swamp column beside a pool
							local bank = false
							for _, d in ipairs(SIDES) do
								if pools.at(x + d[1], z + d[2]) then bank = true break end
							end
							if bank then
								local _, _, _, _, _, terrain_y = context.column_values_at(x, z)
								local y = terrain_y + 1
								if GROUND[at(x, terrain_y, z)] and at(x, y, z) == air then
									local roll = pools.hash(x, z, 839) % 100
									if roll < REEDS_PCT then
										write(x, y, z, REEDS, 0)
										if pools.hash(x, z, 853) % 100 < 45 and at(x, y + 1, z) == air then
											write(x, y + 1, z, REEDS, 0)
										end
									elseif roll < REEDS_PCT + CATTAILS_PCT then
										write(x, y, z, CATTAILS, 0)
									elseif roll < REEDS_PCT + CATTAILS_PCT + CARPET_PCT then
										write(x, y, z, CARPET, 0)
									end
								end
							end
						end
					end
				end
			end
			return count
		end
		return writer
	end
	return config
end
return M
