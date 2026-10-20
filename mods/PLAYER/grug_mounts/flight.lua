-- The flight rule (docs/design/mounts.md §4): where a flying mount may be,
-- per faction and column. One rule for everything that asks: the per-step
-- dismount, the summon check and the warning sweep (entity.lua) and the
-- minimap's no-fly overlay (grug_map base.lua flight_overlay, fix 0.53.1),
-- so the overlay and the dismount cannot disagree. This file's source enters
-- the overlay's cache key: a change to the rule re-renders it.

local DRAGON_ISLANDS = {
	front_wyrmglass_crown = true,
	front_stormscale_summit = true,
}

-- Zone id -> {island, territory}: the two fields of a zone record the flight
-- rule reads. Zone records never change, and grug_zones.at returns a deep
-- copy of the record on every call, so the rule reads the column's zone id
-- and keeps the rest here.
local zone_rules = {}
local function zone_rule(id)
	local rule = zone_rules[id]
	if not rule then
		local zone = grug_zones.get(id)
		rule = {island = DRAGON_ISLANDS[id] == true,
			territory = zone and zone.territory_rule}
		zone_rules[id] = rule
	end
	return rule
end

-- The rule for one faction on a column of water class `water` (grug_zones
-- water_class_at) in zone `id` (grug_zones id_at; nil or false: none):
-- true, or false and why ("ocean", "island" or "enemy"). The zone id is
-- read only on land and planned water.
function grug_mounts.flight_rule(faction, water, id)
	if water ~= "land" and water ~= "planned_water" then
		return false, "ocean"
	end
	if faction ~= "accord" and faction ~= "throng" then
		return false, "enemy"
	end
	-- Zone ownership is horizontal.  Altitude is handled independently by the
	-- underground takeoff and y=600 ceiling rules (entity.lua).
	local rule = id and zone_rule(id)
	if rule and rule.island then
		return false, "island"
	end
	local territory = rule and rule.territory
	if territory == "contested_land" or territory == faction .. "_home" then
		return true, nil
	end
	return false, "enemy"
end

-- The flight rule of one column for one faction, from the public zone
-- queries.
function grug_mounts.column_flight_state(faction, x, z)
	local water = grug_zones.water_class_at(x, z)
	local land = water == "land" or water == "planned_water"
	return grug_mounts.flight_rule(faction, water, land and grug_zones.id_at(x, z) or nil)
end
