-- Mob density per area: the zone budget of Round 24 ruling 27, which the
-- spawn regions share out (Round 28 ruling 34, below).
--
-- The budget of a zone and clock is round(REFERENCE[clock] x DENSITY_SCALE x
-- ZONE_DENSITY), "about 1.5x" the pre-Round-24 area population (ruling 27).
-- Round 24 also shared it per spawn point among the ABM rows of the
-- named-zone palettes; no zone has a palette since the Round 28 spawn
-- recipes, and Round 30 retired those surface rows (spawn_policy.lua
-- spawn_row_kept), so that per-point half is gone.

grug_mobs.DENSITY_SCALE = 1.5

-- The pre-Round-24 area population, rounded: the median over the 32 named
-- zones with a budgeted cast of each zone's mean, over its land columns, of
-- the summed Round 16 caps (1.3x, night rows 5/4) of the species that could
-- spawn on that column's biome top (measured in Round 24 on seed 4242424242:
-- day 9.79, night 14.59). The common budgets are therefore 15 by day and 23
-- by night.
grug_mobs.DENSITY_REFERENCE = {day = 10, night = 15}

-- Per-zone multipliers for later tuning by feel; absent means 1.
grug_mobs.ZONE_DENSITY = {}

local function round(value)
	return math.floor(value + 0.5)
end

function grug_mobs.density_budget(zone_id, clock)
	local reference = grug_mobs.DENSITY_REFERENCE[clock]
	if not reference then
		error("[grug_mobs] density clock must be day or night")
	end
	return math.max(1, round(reference * grug_mobs.DENSITY_SCALE *
		(grug_mobs.ZONE_DENSITY[zone_id] or 1)))
end

-- One species' share of a budget, given the summed weight of the species
-- that share it. Pure; the fixture drives it directly.
function grug_mobs.density_share(budget, weight, eligible_weight)
	if eligible_weight <= 0 then
		return budget
	end
	return math.max(1, round(budget * weight / eligible_weight))
end

-- Entities that never count against the budget even when they share a
-- budgeted name: named rares, camp members and rare/boss tiers.
local function counted(ent)
	return not ent._grug_rare_id and not ent._grug_camp_pos and
		ent._grug_tier ~= "rare" and ent._grug_tier ~= "boss"
end

local count_radius

--
-- Round 28 ruling 34, Lane S1: the same budget for spawn regions.
--
-- In a zone with a spawn recipe the species at a point are the roster of
-- its region for the clock (spawn_regions.lua; regions never overlap). The
-- Round 24 species-aware refill keeps its shape, with the roster weights as
-- the weights and the region's density class as its share of the budget:
--
--   * point budget P = the zone budget (density_budget, 15 by day and 23 by
--     night unless ZONE_DENSITY tunes the zone) x the density class factor
--     (spawn_regions_core.lua DENSITY: sparse 0.5, normal 0.75, dense 1),
--     rounded, at least 1: never above the zone budget;
--   * the chosen species' share = P x w / W (rounded, at least 1), w its
--     roster weight, W the roster's total;
--   * below share / DENSITY_SCALE (rounded up) a species always refills, so
--     killing every fox of a fox/boar roster brings foxes back, not boars;
--   * up to its share it spawns while fewer than P region mobs stand within
--     the counting radius; never above its share.
-- Counted are the free region mobs spawned in the current clock (an
-- `_grug_area` tag of a kind and `_grug_spawn_clock` = the clock) within
-- 2 x active_block_range x 16 nodes, mobs_redo's own counting radius: day
-- animals still about at dusk do not block the night. Camp members,
-- leaders, rares and bosses have their own timers and are neither counted
-- nor limited here.

-- Pure; the fixture drives it directly.
function grug_mobs.area_density_decision(total, same, budget, share)
	if same < math.ceil(share / grug_mobs.DENSITY_SCALE) then
		return true
	end
	if same >= share then
		return false
	end
	return total < budget
end

-- The point budget of a region of density class `density` at a clock.
function grug_mobs.region_budget(zone_id, clock, density)
	local factor = grug_mobs.spawn_regions.core.DENSITY[density] or 1
	return math.max(1, math.floor(grug_mobs.density_budget(zone_id, clock) *
		factor + 0.5))
end

-- `pos` is where the mob would stand, `kind` the region's kind, `name` its
-- entity, `weight` its roster weight and `total_weight` the roster's total.
-- Returns true to allow.
function grug_mobs.region_density_allows(pos, zone_id, clock, kind, name, weight,
		total_weight)
	if not count_radius then
		local range = tonumber(core.settings:get("active_block_range")) or 4
		count_radius = range * 16 * 2
	end
	local budget = grug_mobs.region_budget(zone_id, clock, kind.density)
	local share = grug_mobs.density_share(budget, weight, total_weight)
	local by_tag = grug_mobs.spawn_regions.area_by_tag
	local total, same = 0, 0
	local objects = core.get_objects_inside_radius(pos, count_radius)
	for i = 1, #objects do
		local ent = objects[i]:get_luaentity()
		local tag = ent and ent._grug_area
		if tag and ent._grug_spawn_clock == clock and counted(ent) then
			local unit = by_tag(tag)
			if not unit or not unit.is_camp then
				total = total + 1
				if ent.name == name then
					same = same + 1
				end
			end
		end
	end
	return grug_mobs.area_density_decision(total, same, budget, share)
end
