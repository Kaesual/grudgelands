-- Round 24 ruling 27: ambient mob density is a per-zone budget.
--
-- mobs_redo caps every species separately (api.lua spawn_action: count of
-- that one name within 2 x active_block_range x 16 of the spawn node), so the
-- population around a player used to be the sum of the eligible species'
-- caps, and a zone with few eligible species was empty. The ordinary
-- natural surface species of the named-zone palettes (spawn_policy.lua
-- `density_budgeted`) now share ONE budget per zone and clock instead:
--
--   * budget B = REFERENCE[clock] x DENSITY_SCALE x (ZONE_DENSITY[zone] or 1),
--     rounded; REFERENCE is the pre-Round-24 median per-zone sum of the
--     budgeted species' caps, so DENSITY_SCALE is "about 1.5x" (ruling 27);
--   * each species eligible AT THE SPAWN POINT (its hosts include the node
--     the spawning row matched, and policy, level gate, row domain and
--     check and clock allow it) gets the share B x w / W, rounded, where w is
--     its registered row cap and W the sum over the eligible species; a
--     single eligible species may fill the whole budget;
--   * the budgeted mobs within the same radius never exceed B in total.
--
-- Critters, underground rows, NPCs, guards, camps, patrols, named rares,
-- bosses, royals and independent-authority mobs are neither counted nor
-- limited here; they keep their own rows and timers. The row's own
-- mobs_redo cap is lifted to the largest budget (prepare_spawn_row), so this
-- check, which runs in mobs:spawn_abm_check before mobs_redo counts, is the
-- binding one.

grug_mobs.DENSITY_SCALE = 1.5

-- The pre-Round-24 area population, rounded: the median over the 32 named
-- zones with a budgeted cast of each zone's mean, over its land columns, of
-- the summed Round 16 caps (1.3x, night rows 5/4) of the species that could
-- spawn on that column's biome top (tools/r24_density_xp/fixture.lua prints
-- the table: day 9.46, night 14.95 on seed 4242424242). Budgets are
-- therefore 14 by day and 23 by night.
grug_mobs.DENSITY_REFERENCE = {day = 9, night = 15}

-- Per-zone multipliers for later tuning by feel; absent means 1.
grug_mobs.ZONE_DENSITY = {}

-- Attempt frequency of budgeted rows (spawn_policy.lua prepare_spawn_row).
grug_mobs.DENSITY_ATTEMPT_SCALE = grug_mobs.DENSITY_SCALE

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

-- The lifted mobs_redo row cap: the largest budget any zone can have.
function grug_mobs.density_row_cap()
	local factor = 1
	for _, value in pairs(grug_mobs.ZONE_DENSITY) do
		if value > factor then factor = value end
	end
	local cap = 1
	for _, reference in pairs(grug_mobs.DENSITY_REFERENCE) do
		cap = math.max(cap, math.ceil(reference * grug_mobs.DENSITY_SCALE * factor))
	end
	return cap
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

-- zone_id -> clock -> {budget, weight = {name -> w}, names, total}, built on
-- first use, after every mob file has registered its rows.
local entries

function grug_mobs.density_entry(zone_id, clock)
	if not entries then
		entries = {}
		for _, id in ipairs(grug_mobs.density_zone_ids()) do
			local by_clock = {}
			for _, c in ipairs({"day", "night"}) do
				local cast = grug_mobs.zone_density_cast(id, c)
				local entry = {budget = grug_mobs.density_budget(id, c),
					weight = {}, names = {}, total = 0}
				for _, name in ipairs(cast) do
					local w = weights[name]
					if w then
						entry.weight[name] = w
						entry.names[#entry.names + 1] = name
						entry.total = entry.total + w
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
	local entry = grug_mobs.density_entry(grug_zones.id_at(pos.x, pos.z),
		clock_now())
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
		-- Zombie row by day): its own row cap at the same scale.
		local own = weights[name] or 1
		return same < math.max(1, round(own * grug_mobs.DENSITY_SCALE))
	end
	if total >= entry.budget then
		return false
	end
	-- Cheap path: below the share it would get with the whole static cast
	-- eligible, no per-point evaluation is needed.
	if same < grug_mobs.density_share(entry.budget, weight, entry.total) then
		return true
	end
	local eligible_weight = 0
	for i = 1, #entry.names do
		local other = entry.names[i]
		if other == name or (grug_mobs.density_hosts(other, node_name) and
				eligible(other, pos)) then
			eligible_weight = eligible_weight + entry.weight[other]
		end
	end
	return same < grug_mobs.density_share(entry.budget, weight, eligible_weight)
end
