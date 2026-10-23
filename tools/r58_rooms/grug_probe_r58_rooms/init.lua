-- Disposable engine probe (Round 58 lane ROOMS): the Miner's Guild lift rooms
-- in a real world. Never shipped: staged through tools/luanti_headless.sh
-- (PROBE=), see the Round 58 ROOMS line in tools/README.md.
--
-- Emerges only each room's box (setting r58rooms_max: at most that many
-- rooms, default all; r58rooms_camps: a comma list of camp ids to keep), then
-- per room one CHECK line: every node of the box and the exits' plugs is the shape's
-- (guild_rooms.lua R.cell), no liquid and no ground-content node in it, light
-- at the arrival, the zone authority's "guild_room" and "hard_protected" in
-- the box and not right outside, and the ambient spawn policy refusing a
-- zombie at the lift cell; plus a count of the liquids in the ring of 3
-- nodes round the box and the nearest water and lava within r58rooms_far
-- (default 12) nodes of it (so a run shows rooms with water or lava near).
-- Ends the server with "[r58rooms] DONE pass=<n> fail=<n>".

local P = "[r58rooms] "
local function log(msg) core.log("action", P .. msg) end
local R = dofile(core.get_modpath("grug_mapgen") .. "/wp40/guild_rooms.lua")
local MAX = tonumber(core.settings:get("r58rooms_max") or "") or 1000
local FAR = tonumber(core.settings:get("r58rooms_far") or "") or 12
local KEEP = {}
for id in (core.settings:get("r58rooms_camps") or ""):gmatch("[^,%s]+") do KEEP[id] = true end

local function expected(room, kind)
	if kind == "mantle" then return R.NODES.mantle[room.tier] end
	return R.NODES[kind]
end

local function check_room(room)
	local minp, maxp = room.minp, room.maxp
	core.load_area(vector.subtract(minp, 4), vector.add(maxp, 4))
	local wrong, liquid, ground, first = 0, 0, 0, nil
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local pos = {x = x, y = y, z = z}
				local name = core.get_node(pos).name
				local want = expected(room, R.cell(room, x, y, z))
				local def = core.registered_nodes[name]
				if name ~= want then
					wrong = wrong + 1
					first = first or (core.pos_to_string(pos) .. " " .. name .. "~=" .. want)
				end
				if def and def.liquidtype ~= "none" then liquid = liquid + 1 end
				if not def or def.is_ground_content ~= false then ground = ground + 1 end
			end
		end
	end
	-- the exits' plugs, one node past the box face
	local c = room.lift_cell
	for _, exit in ipairs(R.EXITS) do
		for dy = 0, R.EXIT_HEIGHT - 1 do
			local pos = {x = c.x + exit[1] * (R.BOX.max_x + 1), y = room.floor_y + dy,
				z = c.z + exit[2] * (R.BOX.max_z + 1)}
			local name = core.get_node(pos).name
			if name ~= R.NODES.plug[room.tier] then
				wrong = wrong + 1
				first = first or (core.pos_to_string(pos) .. " " .. name .. " (plug)")
			end
		end
	end
	local ring_liquid = {}
	for z = minp.z - 3, maxp.z + 3 do
		for y = minp.y - 3, maxp.y + 3 do
			for x = minp.x - 3, maxp.x + 3 do
				if x < minp.x or x > maxp.x or y < minp.y or y > maxp.y or
						z < minp.z or z > maxp.z then
					local name = core.get_node({x = x, y = y, z = z}).name
					local def = core.registered_nodes[name]
					if def and def.liquidtype ~= "none" then
						ring_liquid[name] = (ring_liquid[name] or 0) + 1
					end
				end
			end
		end
	end
	local ring = {}
	for name, n in pairs(ring_liquid) do ring[#ring + 1] = name .. "=" .. n end
	table.sort(ring)
	-- the nearest water and lava within FAR nodes of the box (Chebyshev)
	local nearest = {}
	for _, kind in ipairs({"water", "lava"}) do
		local found = core.find_nodes_in_area(vector.subtract(minp, FAR), vector.add(maxp, FAR),
			{"group:" .. kind})
		local best
		for _, p in ipairs(found) do
			local d = math.max(minp.x - p.x, p.x - maxp.x, minp.y - p.y, p.y - maxp.y,
				minp.z - p.z, p.z - maxp.z)
			if not best or d < best then best = d end
		end
		nearest[#nearest + 1] = kind .. " " .. (best and tostring(best) or "-")
	end
	local lift = core.get_node(room.lift_cell)
	if lift.param2 ~= R.NODES.lift_param2 then
		wrong = wrong + 1
		first = first or ("lift param2 " .. lift.param2)
	end
	local arrival = vector.round(room.arrival)
	local light = core.get_node_light(arrival) or -1
	local above = {x = room.lift_cell.x, y = maxp.y + 1, z = room.lift_cell.z}
	local beside = {x = maxp.x + 1, y = room.floor_y, z = room.lift_cell.z}
	local protected = grug_zones.hard_protection_kind_at(room.lift_cell) == "guild_room" and
		grug_zones.territory_rule_at(minp) == "hard_protected" and
		grug_zones.hard_protection_kind_at(above) == nil and
		grug_zones.hard_protection_kind_at(beside) == nil
	local spawn = grug_mobs.spawn_policy_allows("grug_mobs:zombie", room.lift_cell)
	local ok = wrong == 0 and liquid == 0 and ground == 0 and light >= 8 and protected and
		spawn == false
	log(("CHECK %s %s T%d floor %d at %d,%d: wrong %d%s, liquid %d, ground content %d, " ..
		"light %d, protected %s, zombie spawn %s, ring liquids %s, nearest %s"):format(
		ok and "PASS" or "FAIL", room.camp_id, room.tier, room.floor_y, room.lift_cell.x,
		room.lift_cell.z, wrong, first and (" (first " .. first .. ")") or "", liquid, ground,
		light, tostring(protected), tostring(spawn), #ring > 0 and table.concat(ring, " ") or "none",
		table.concat(nearest, ", ")))
	return ok
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local list = {}
		for _, room in ipairs(grug_mapgen.guild_rooms.list) do
			if (next(KEEP) == nil or KEEP[room.camp_id]) and #list < MAX then
				list[#list + 1] = room
			end
		end
		log(("rooms %d of %d"):format(#list, #grug_mapgen.guild_rooms.list))
		local index, pass, fail = 0, 0, 0
		local started = core.get_us_time()
		local function next_room()
			index = index + 1
			local room = list[index]
			if not room then
				log(("DONE pass=%d fail=%d in %.1f s"):format(pass, fail,
					(core.get_us_time() - started) / 1e6))
				core.request_shutdown("r58 rooms probe done", false, 0)
				return
			end
			local t0 = core.get_us_time()
			core.emerge_area(room.minp, room.maxp, function(_, _, remaining)
				if remaining > 0 then return end
				core.after(0, function()
					log(("emerged %s T%d in %.2f s"):format(room.camp_id, room.tier,
						(core.get_us_time() - t0) / 1e6))
					if check_room(room) then pass = pass + 1 else fail = fail + 1 end
					next_room()
				end)
			end)
		end
		next_room()
	end)
end)
