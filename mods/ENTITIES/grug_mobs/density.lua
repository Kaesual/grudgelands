-- Round 24 ruling 27: ambient mob density is a per-zone budget.
--
-- mobs_redo caps every species separately (api.lua spawn_action: count of
-- that one name within 2 x active_block_range x 16 of the spawn node), so the
-- population around a player used to be the sum of the eligible species'
-- caps, and a zone with few eligible species was empty. The ordinary
-- natural surface species of the named-zone palettes (spawn_policy.lua
-- `density_budgeted`) now share ONE budget per spawn point instead:
--
--   * the species that could spawn AT THE POINT are those whose hosts include
--     the node the spawning row matched and which policy, level gate, row
--     domain and check and clock allow;
--   * point budget P = max(zone budget, their old population), where
--     zone budget = round(REFERENCE[clock] x DENSITY_SCALE x ZONE_DENSITY)
--     and old population = the sum of their Round 16 caps (row cap x 1.3
--     rounded, x 5/4 rounded up at night). REFERENCE is the pre-Round-24
--     median area population, so the common budget is "about 1.5x" (ruling
--     27), and the second term keeps every point at least as populated as
--     before (coordinator correction: no zone gets sparser);
--   * each of those species gets the share P x w / W, rounded (at least 1),
--     where w is its registered row cap and W their summed row caps, but
--     never more than ceil(1.5 x its own Round 16 cap) (review decision);
--   * the budgeted mobs within the same radius never exceed P in total;
--   * below its own Round 16 cap a species always spawns, so no species is
--     ever held below its pre-Round-24 population by its neighbours.
--
-- Critters, underground rows, NPCs, guards, camps, patrols, named rares,
-- bosses, royals and independent-authority mobs are neither counted nor
-- limited here; they keep their own rows and timers. The row's own
-- mobs_redo cap is lifted to DENSITY_ROW_CAP (prepare_spawn_row), so this
-- check, which runs in mobs:spawn_abm_check before mobs_redo counts, is the
-- binding one.

grug_mobs.DENSITY_SCALE = 1.5

-- The pre-Round-24 area population, rounded: the median over the 32 named
-- zones with a budgeted cast of each zone's mean, over its land columns, of
-- the summed Round 16 caps (1.3x, night rows 5/4) of the species that could
-- spawn on that column's biome top (tools/r24_density_xp/fixture.lua prints
-- the table: day 9.79, night 14.59 on seed 4242424242, main with Lanes D2 and
-- D3). The common budgets are therefore 15 by day and 23 by night.
grug_mobs.DENSITY_REFERENCE = {day = 10, night = 15}

-- Per-zone multipliers for later tuning by feel; absent means 1.
grug_mobs.ZONE_DENSITY = {}

-- Attempt frequency of budgeted rows (spawn_policy.lua prepare_spawn_row).
grug_mobs.DENSITY_ATTEMPT_SCALE = grug_mobs.DENSITY_SCALE

-- The lifted mobs_redo cap of a budgeted row: above any point budget
-- (the fixture checks every zone's whole-cast old population against it).
grug_mobs.DENSITY_ROW_CAP = 64

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

function grug_mobs.density_row_cap()
	return grug_mobs.DENSITY_ROW_CAP
end

-- The Round 16 cap of a row with cap `weight` at a clock (spawn_policy.lua
-- before Round 24). At night every row counts with its night 5/4, which errs
-- towards more mobs for the few around-the-clock rows.
function grug_mobs.density_old_cap(weight, clock)
	local cap = math.max(1, round(weight * 1.3))
	if clock == "night" then
		cap = math.ceil(cap * 5 / 4)
	end
	return cap
end

-- The most of one species a point may hold (review decision on ruling 27,
-- "about 1.5x"): ceil(DENSITY_SCALE x its Round 16 cap). Where few species
-- share a point the point therefore ends below the zone budget, but never
-- below its old population.
function grug_mobs.density_species_cap(weight, clock)
	return math.ceil(grug_mobs.DENSITY_SCALE *
		grug_mobs.density_old_cap(weight, clock))
end

-- Registered per-species weight (the largest surface row cap of that name)
-- and host nodes (the union of its surface rows' node lists), recorded from
-- the raw row before prepare_spawn_row lifts its cap.
local weights = {}
local hosts = {}

function grug_mobs.note_density_row(row)
	local name = row.name
	local value = math.max(1, math.floor(tonumber(row.active_object_count) or 1))
	if not weights[name] or value > weights[name] then
		weights[name] = value
	end
	local host = hosts[name]
	if not host then
		host = {names = {}, groups = {}}
		hosts[name] = host
	end
	for _, node_name in ipairs(row.nodes or {"group:soil", "group:stone"}) do
		local group = node_name:match("^group:(.+)$")
		if group then
			host.groups[#host.groups + 1] = group
		else
			host.names[node_name] = true
		end
	end
end

function grug_mobs.density_weight(name)
	return weights[name]
end

-- Does `node_name` host this budgeted species? The spawning row's ABM node
-- stands for the local habitat: species that could never spawn on it (the
-- other continent's forest tint, a desert family on grass) do not compete
-- for this area's budget.
function grug_mobs.density_hosts(name, node_name)
	local host = hosts[name]
	if not host or not node_name then
		return false
	end
	if host.names[node_name] then
		return true
	end
	for i = 1, #host.groups do
		if core.get_item_group(node_name, host.groups[i]) > 0 then
			return true
		end
	end
	return false
end

-- One species' share of a budget, given the summed weight of the species
-- eligible at the point. Pure; the fixture drives it directly.
function grug_mobs.density_share(budget, weight, eligible_weight)
	if eligible_weight <= 0 then
		return budget
	end
	return math.max(1, round(budget * weight / eligible_weight))
end

-- The budget at a point: the zone budget, or the old population of the
-- species that could spawn there when that is larger.
function grug_mobs.density_point_budget(zone_budget, old_population)
	return math.max(zone_budget, old_population)
end

-- zone_id -> clock -> {budget, weight = {name -> w}, names, total,
-- old_total}, built on first use, after every mob file has registered its
-- rows. old_total (the whole cast's old population) bounds every point
-- budget of the zone.
local entries

function grug_mobs.density_entry(zone_id, clock)
	if not entries then
		entries = {}
		for _, id in ipairs(grug_mobs.density_zone_ids()) do
			local by_clock = {}
			for _, c in ipairs({"day", "night"}) do
				local cast = grug_mobs.zone_density_cast(id, c)
				local entry = {budget = grug_mobs.density_budget(id, c),
					weight = {}, names = {}, total = 0, old_total = 0}
				for _, name in ipairs(cast) do
					local w = weights[name]
					if w then
						entry.weight[name] = w
						entry.names[#entry.names + 1] = name
						entry.total = entry.total + w
						entry.old_total = entry.old_total +
							grug_mobs.density_old_cap(w, c)
					end
				end
				if #entry.names > 0 then
					by_clock[c] = entry
				end
			end
			entries[id] = by_clock
		end
	end
	local by_clock = entries[zone_id]
	return by_clock and by_clock[clock] or nil
end

-- For the fixture and a reload of the tuning tables.
function grug_mobs.reset_density_entries()
	entries = nil
end

local function clock_now()
	local value = core.get_timeofday and core.get_timeofday() or 0.5
	local day_start = grug_core.DAY_PHASE_START or 0.1875
	local day_end = grug_core.DAY_PHASE_END or 0.8125
	return (value >= day_start and value <= day_end) and "day" or "night"
end

-- Entities that never count against the budget even when they share a
-- budgeted name: named rares, camp members and rare/boss tiers.
local function counted(ent)
	return not ent._grug_rare_id and not ent._grug_camp_pos and
		ent._grug_tier ~= "rare" and ent._grug_tier ~= "boss"
end

local count_radius

-- mobs:spawn_abm_check tail. `node_name` is the node the spawning row's ABM
-- matched, `eligible(name, pos)` the full per-point spawn decision without
-- this budget (init.lua). Returns true to allow.
function grug_mobs.density_allows(name, pos, node_name, eligible)
	if pos.y < 0 or not grug_mobs.density_budgeted(name) then
		return true
	end
	if not count_radius then
		local range = tonumber(core.settings:get("active_block_range")) or 4
		count_radius = range * 16 * 2
	end
	local clock = clock_now()
	local entry = grug_mobs.density_entry(grug_zones.id_at(pos.x, pos.z), clock)
	local weight = entry and entry.weight[name]
	local same, total = 0, 0
	local objects = core.get_objects_inside_radius(pos, count_radius)
	for i = 1, #objects do
		local ent = objects[i]:get_luaentity()
		local ent_name = ent and ent.name
		if ent_name and (ent_name == name or (weight and entry.weight[ent_name]))
				and counted(ent) then
			total = total + 1
			if ent_name == name then
				same = same + 1
			end
		end
	end
	if not weight then
		-- A budgeted species outside the zone's static cast (the 24 h blight
		-- Zombie row by day): its own species cap alone.
		return same < grug_mobs.density_species_cap(weights[name] or 1, clock)
	end
	-- Below its own Round 16 cap a species always spawns, exactly as before
	-- Round 24: neighbours of a mixed area (a higher-level edge, another
	-- biome patch) can then fill the budget without crowding it out.
	if same < grug_mobs.density_old_cap(weight, clock) then
		return true
	end
	-- No species above 1.5x its own old cap, however few share the point: a
	-- lone Stone Golem on bare stone stays a golem or two, not a budget.
	if same >= grug_mobs.density_species_cap(weight, clock) then
		return false
	end
	-- Cheap paths. No point budget exceeds max(zone budget, whole cast's old
	-- population); none falls below the zone budget, and no share below the
	-- one with the whole cast eligible.
	if total >= math.max(entry.budget, entry.old_total) then
		return false
	end
	if total < entry.budget and
			same < grug_mobs.density_share(entry.budget, weight, entry.total) then
		return true
	end
	local eligible_weight, old_population = 0, 0
	for i = 1, #entry.names do
		local other = entry.names[i]
		if other == name or (grug_mobs.density_hosts(other, node_name) and
				eligible(other, pos)) then
			local w = entry.weight[other]
			eligible_weight = eligible_weight + w
			old_population = old_population + grug_mobs.density_old_cap(w, clock)
		end
	end
	local budget = grug_mobs.density_point_budget(entry.budget, old_population)
	return total < budget and
		same < grug_mobs.density_share(budget, weight, eligible_weight)
end

--
-- Round 28 ruling 34: the same budget for spawn areas.
--
-- In a zone whose data defines spawn areas the species eligible at a point
-- are the species of the areas that match it (spawn_areas.lua areas_at:
-- point, clock and host, overlaps adding their weights). The species-aware
-- refill keeps its shape, with the area weights in place of the row caps:
--
--   * point budget P = the zone budget (density_budget, 15 by day and 23 by
--     night unless ZONE_DENSITY tunes the zone);
--   * the chosen species' share = P x w / W (rounded, at least 1), w its
--     summed weight at the point, W the summed weight of every species there;
--   * below share / DENSITY_SCALE (rounded up) a species always refills, so
--     killing every fox of a boar/fox area brings foxes back, not boars;
--   * up to its share it spawns while fewer than P area mobs stand within
--     the counting radius; never above its share;
--   * an area's optional `cap`: at most that many of ITS mobs within the
--     radius, whatever the budget says.
-- Counted are the free area mobs of the areas active at the clock (an
-- `_grug_area` tag of a non-camp area whose clock is `both` or the current
-- one) within the same radius as above: like the clock casts above, day
-- animals still about at dusk do not block the night. Camp members, leaders,
-- rares and bosses have their own timers and are neither counted nor limited
-- here.

-- Pure; the fixture drives it directly.
function grug_mobs.area_density_decision(total, same, in_area, budget, share, cap)
	if cap and in_area >= cap then
		return false
	end
	if same < math.ceil(share / grug_mobs.DENSITY_SCALE) then
		return true
	end
	if same >= share then
		return false
	end
	return total < budget
end

-- `pos` is where the mob would stand, `area` the area it would carry, `name`
-- its entity, `weight` its summed weight at the point and `eligible_weight`
-- the point's total. Returns true to allow.
function grug_mobs.area_density_allows(pos, zone_id, clock, area, name, weight,
		eligible_weight)
	if not count_radius then
		local range = tonumber(core.settings:get("active_block_range")) or 4
		count_radius = range * 16 * 2
	end
	local budget = grug_mobs.density_budget(zone_id, clock)
	local share = grug_mobs.density_share(budget, weight, eligible_weight)
	local area_by_tag = grug_mobs.spawn_areas.area_by_tag
	local total, same, in_area = 0, 0, 0
	local objects = core.get_objects_inside_radius(pos, count_radius)
	for i = 1, #objects do
		local ent = objects[i]:get_luaentity()
		local tag = ent and ent._grug_area
		if tag and counted(ent) then
			local tagged = area_by_tag(tag)
			if not tagged or (not tagged.camp and
					(tagged.clock == "both" or tagged.clock == clock)) then
				total = total + 1
				if ent.name == name then
					same = same + 1
				end
				if tag == area.tag then
					in_area = in_area + 1
				end
			end
		end
	end
	return grug_mobs.area_density_decision(total, same, in_area, budget, share,
		area.cap)
end
