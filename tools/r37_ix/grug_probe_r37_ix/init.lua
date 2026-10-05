-- Disposable engine probe (Round 37 lane IX, CORE-02): how often the water
-- guard (grug_core/water_guard.lua) undoes the engine's liquid flow at one
-- capital edge and one coast, and whether it loops. Never shipped:
-- tools/r37_ix/engine.sh stages it through tools/luanti_headless.sh.
--
-- Two regions of the seed's real world are emerged (no player is needed: the
-- liquid queue runs on loaded blocks, and the unload timeout is raised so
-- they stay loaded):
--   capital  the first edge of the human capital's protected city (territory
--            "hard_protected" beside open ground) with planned water within
--            four nodes, nearest the capital anchor; else the edge on the +x
--            ray;
--   coast    the nearest "immutable" (open sea) column on eight rays from the
--            human start.
-- Each region is HALF nodes either side in x and z. Two liquid callbacks
-- frame the guard's own: one inserted before it records what the engine
-- wrote, one appended after it sees what the guard left. A transform is a
-- flood (non-water -> water), a drain (water -> non-water) or a shift (water
-- -> other water); a revert is a transform the guard changed again. A barrier
-- node's refused floods (grug_core:water_barrier, when it exists) are counted
-- too. Logged per region: transforms and reverts per kind, reverted
-- positions, positions reverted 3 or more times, reverts in the last 30 s and
-- the five busiest positions; then the server shuts down.

local P = "[r37ix_probe] "
local OBSERVE = tonumber(core.settings:get("r37ix_observe") or "") or 120
local HALF = 80
local TAIL = 30
local BARRIER = "grug_core:water_barrier"

local function log(msg) core.log("action", P .. msg) end

-- Keep the emerged blocks loaded without a player (read every server step).
core.settings:set("server_unload_unused_data_timeout", "3600")

local WATER = {
	["default:water_source"] = true,
	["default:water_flowing"] = true,
	["default:river_water_source"] = true,
	["default:river_water_flowing"] = true,
}

local regions = {}
local clock, observe_from, observing = 0, nil, false

local function region_of(pos)
	for index = 1, #regions do
		local r = regions[index]
		if pos.x >= r.minp.x and pos.x <= r.maxp.x and pos.y >= r.minp.y and
				pos.y <= r.maxp.y and pos.z >= r.minp.z and pos.z <= r.maxp.z then
			return r
		end
	end
	return nil
end

local function new_stats()
	return {transforms = {flood = 0, drain = 0, shift = 0},
		reverts = {flood = 0, drain = 0, shift = 0},
		refused = 0, tail = 0, positions = {}, examples = {}}
end

local function stats_for(r)
	if not observing then return r.during end
	return r.observe
end

-- Before the guard: what the engine wrote at each transformed position.
local engine_new = {}
table.insert(core.registered_on_liquid_transformed, 1, function(positions)
	engine_new = {}
	for index = 1, #positions do
		local node = core.get_node_or_nil(positions[index])
		engine_new[index] = node and {name = node.name, param2 = node.param2}
	end
end)

-- After the guard: whether it changed the engine's result.
core.register_on_liquid_transformed(function(positions, old_nodes)
	for index = 1, #positions do
		local pos, old, new = positions[index], old_nodes[index], engine_new[index]
		local r = pos and old and new and region_of(pos)
		if r then
			local kind
			if WATER[old.name] then
				kind = WATER[new.name] and "shift" or "drain"
			else
				kind = WATER[new.name] and "flood" or nil
			end
			if kind then
				local s = stats_for(r)
				s.transforms[kind] = s.transforms[kind] + 1
				local after = core.get_node(pos)
				if after.name ~= new.name or after.param2 ~= new.param2 then
					s.reverts[kind] = s.reverts[kind] + 1
					local key = core.hash_node_position(pos)
					s.positions[key] = (s.positions[key] or 0) + 1
					s.examples[key] = s.examples[key] or
						(kind .. " " .. old.name .. "->" .. new.name .. "->" .. after.name)
					if observing and clock >= observe_from + OBSERVE - TAIL then
						s.tail = s.tail + 1
					end
				end
			end
		end
	end
	engine_new = {}
end)

core.register_on_mods_loaded(function()
	local def = core.registered_nodes[BARRIER]
	if not def then return end
	local original = def.on_flood
	core.override_item(BARRIER, {on_flood = function(pos, oldnode, newnode)
		local refused = original and original(pos, oldnode, newnode)
		local r = refused and region_of(pos)
		if r then
			local s = stats_for(r)
			s.refused = s.refused + 1
		end
		return refused
	end})
end)

-- ---------------------------------------------------------------- spots
local function planned_water(x, z)
	local values = {grug_mapgen.wp40.planner_source.column_values_at(x, z)}
	local terrain_y, water_y, water_id = values[6], values[7], values[8]
	return water_id ~= nil and water_y ~= nil and water_y > terrain_y
end

local function territory(x, y, z)
	return grug_zones.territory_rule_at({x = x, y = y, z = z})
end

local function capital_spot()
	local anchor = grug_core.capital_anchor("accord", "human")
	if not anchor then return nil end
	local y = anchor.y
	local best, best_d
	for dz = -400, 400, 4 do
		for dx = -400, 400, 4 do
			local x, z = anchor.x + dx, anchor.z + dz
			local d = dx * dx + dz * dz
			if (not best_d or d < best_d) and territory(x, y, z) == "hard_protected" and
					(territory(x + 4, y, z) ~= "hard_protected" or
					territory(x - 4, y, z) ~= "hard_protected" or
					territory(x, y, z + 4) ~= "hard_protected" or
					territory(x, y, z - 4) ~= "hard_protected") then
				local wet = false
				for ox = -4, 4, 4 do
					for oz = -4, 4, 4 do
						wet = wet or planned_water(x + ox, z + oz)
					end
				end
				if wet then best, best_d = {x = x, y = y, z = z}, d end
			end
		end
	end
	if best then return best, "water edge" end
	for dx = 0, 1000, 4 do
		if territory(anchor.x + dx, y, anchor.z) ~= "hard_protected" then
			return {x = anchor.x + dx, y = y, z = anchor.z}, "+x edge (no water edge found)"
		end
	end
	return anchor, "anchor (no edge found)"
end

local function coast_spot()
	local start = grug_core.start_position("accord", "human")
	if not start then return nil end
	local best, best_d
	for angle = 0, 7 do
		local ax, az = math.cos(angle * math.pi / 4), math.sin(angle * math.pi / 4)
		for d = 0, 4000, 8 do
			local x, z = math.floor(start.x + ax * d + 0.5), math.floor(start.z + az * d + 0.5)
			if territory(x, 1, z) == "immutable" then
				if not best_d or d < best_d then best, best_d = {x = x, y = 1, z = z}, d end
				break
			end
		end
	end
	return best, best and ("immutable at distance " .. best_d .. " from the human start") or nil
end

local function add_region(name, center, note, y0, y1)
	local r = {name = name, center = center,
		minp = {x = center.x - HALF, y = y0, z = center.z - HALF},
		maxp = {x = center.x + HALF - 1, y = y1, z = center.z + HALF - 1},
		during = new_stats(), observe = new_stats(), done = false}
	regions[#regions + 1] = r
	log(("region %s at %s (%s), %s .. %s"):format(name, core.pos_to_string(center), note,
		core.pos_to_string(r.minp), core.pos_to_string(r.maxp)))
	core.emerge_area(r.minp, r.maxp, function(_, _, remaining)
		if remaining == 0 then r.done = true end
	end)
end

local function report_stats(r, label, s)
	local reverted, looping = 0, 0
	local list = {}
	for key, count in pairs(s.positions) do
		reverted = reverted + 1
		if count >= 3 then looping = looping + 1 end
		list[#list + 1] = {key = key, count = count}
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return a.key < b.key
	end)
	log(("RESULT %s %s transforms flood %d drain %d shift %d; reverts flood %d drain %d " ..
		"shift %d; refused floods %d; reverted positions %d, positions reverted >= 3 times %d; " ..
		"reverts in the last %d s %d"):format(r.name, label, s.transforms.flood,
		s.transforms.drain, s.transforms.shift, s.reverts.flood, s.reverts.drain,
		s.reverts.shift, s.refused, reverted, looping, TAIL, s.tail))
	for index = 1, math.min(5, #list) do
		local pos = core.get_position_from_hash(list[index].key)
		log(("  %s %s x%d %s territory %s node now %s"):format(r.name, label, list[index].count,
			core.pos_to_string(pos), s.examples[list[index].key], tostring(territory(pos.x, pos.y, pos.z)),
			core.get_node(pos).name))
	end
end

-- ---------------------------------------------------------------- driver
local phase, phase_t = "wait", 0
core.register_globalstep(function(dtime)
	clock = clock + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if clock > 3 and grug_core.zone_authority_installed() then
			local t0 = core.get_us_time()
			local capital, capital_note = capital_spot()
			local coast, coast_note = coast_spot()
			log(("spot search %.0f ms"):format((core.get_us_time() - t0) / 1000))
			if capital then add_region("capital", capital, capital_note, capital.y - 32, capital.y + 32) end
			if coast then add_region("coast", coast, coast_note, -40, 24) end
			phase, phase_t = "emerge", 0
		end
	elseif phase == "emerge" then
		local all = true
		for index = 1, #regions do all = all and regions[index].done end
		if all or phase_t > 100 then
			log(("emerge done=%s after %.1f s"):format(tostring(all), phase_t))
			observing, observe_from = true, clock
			phase, phase_t = "observe", 0
		end
	elseif phase == "observe" then
		if phase_t >= OBSERVE then
			for index = 1, #regions do
				local r = regions[index]
				report_stats(r, "emerge", r.during)
				report_stats(r, "observe" .. OBSERVE .. "s", r.observe)
			end
			log("RESULT DONE")
			phase = "done"
			core.request_shutdown("r37 ix probe done", false, 0)
		end
	end
end)
