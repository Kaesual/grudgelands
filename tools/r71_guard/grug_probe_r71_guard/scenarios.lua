-- The scenarios, one per run.sh SCENARIO.
--   rules    every rule inside a box: mounts, digging, building, liquids, flight,
--            Blink, Charge, Return Home, the respawn in and after a run
--   spawns   natural spawns round a player in slot 1: run it with and without the
--            gate (r71guard_gate = off); counts refusals, mobs and air
--   wander   a player just outside the field: what spawns there, how far it walks
local S = {}
local E = grug_expeditions
local TIER = {land = 1, flight = 3, boat = 5}
local ORE = "default:stone_with_iron"

local function to_level(player, level)
	grug_xp.set_xp(player, grug_xp.xp_for_level(level))
end

local function prepared_run(lib, player)
	local run = assert(E.create(player, "test_vault", 0))
	lib.wait_for(function() return run.state == "ready" end, 60)
	assert(run.state == "ready", "not ready")
	return run
end

local function enter(lib, player, run)
	assert(E.enter(player, "highcourt"))
	lib.wait_for(function() return E.run_inside(player) == run end, 30)
	assert(E.run_inside(player) == run, "not inside")
end

local function rel(run, x, y, z)
	return {x = run.minp.x + x, y = run.minp.y + y, z = run.minp.z + z}
end

local function node(pos) return core.get_node(pos).name end

local function look_at(player, target)
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height or 1.47, 0)
	local dir = vector.direction(eye, target)
	player:set_look_horizontal(core.dir_to_yaw(dir))
	player:set_look_vertical(-math.asin(dir.y))
end

local function feet(cell) return {x = cell.x, y = cell.y - 0.49, z = cell.z} end

-- The ways a line reaches the player: a keyed feed line, a mining hint.
local function spies()
	local seen = {}
	local feed, emit = grug_core.feed, grug_materials.emit_hint
	grug_core.feed = function(player, kind, text, key)
		seen[#seen + 1] = "feed:" .. tostring(text)
		return feed(player, kind, text, key)
	end
	grug_materials.emit_hint = function(name, text)
		seen[#seen + 1] = "hint:" .. tostring(text)
		return emit(name, text)
	end
	return seen, function(what)
		for _, line in ipairs(seen) do
			if line == what then return true end
		end
		return false
	end
end

local function pointed_at(under)
	return {type = "node", under = under, above = {x = under.x, y = under.y + 1, z = under.z}}
end

-- The mounts: a working ride on the map first, then every tier and path refused.
local function prove_mounts(lib, player, heard)
	local MESSAGE = "Mounts cannot be used in an Expedition."
	for _, id in ipairs({TIER.land, TIER.flight, TIER.boat}) do
		local ok = grug_mounts.toggle(player, id)
		lib.check(not ok and not grug_mounts.is_mounted(player), "mount tier " .. id .. " refused")
	end
	lib.check(heard("feed:" .. MESSAGE), "the refusal is in the feed")
	local ok, why = grug_mounts.mount(player, TIER.land)
	lib.check(not ok and why == MESSAGE, "grug_mounts.mount refused: " .. tostring(why))
	grug_quickbar.open(player)
	grug_quickbar.handle_fields(player, {["grug_quickbar_mount_" .. TIER.land] = "x"})
	lib.check(not grug_mounts.is_mounted(player), "the quickbar's button refused")
	core.close_formspec(lib.NAME, "")
	lib.check(not grug_mounts.flight_state(player, player:get_pos()),
		"flight: the open sea's rule refuses the column without the guard")
end

local function prove_digging(lib, player, run, heard)
	-- Disposable marks: the tiny template has no ore, and its file stays FRAME's.
	local tpl = E.templates[E.definition(run.expedition).template]
	tpl.dig[ORE] = true
	local wall = {rel(run, 4, 6, 10), rel(run, 4, 6, 11), rel(run, 4, 6, 12), rel(run, 4, 6, 13)}
	for _, pos in ipairs(wall) do core.set_node(pos, {name = ORE}) end
	local stand = vector.offset(wall[1], 2, -1, 0)
	player:set_pos(feet(stand))
	lib.wait(0.5)
	player:set_wielded_item(ItemStack("grug_materials:pick_steel"))
	local inv = player:get_inventory()
	local function dig(pos)
		local here = core.get_node(pos)
		core.registered_nodes[here.name].on_dig(pos, here, player)
	end
	local before = inv:get_list("main")
	local count = 0
	for _, stack in ipairs(before) do
		if stack:get_name() ~= "" and stack:get_name() ~= "grug_materials:pick_steel" then
			count = count + stack:get_count()
		end
	end
	local tool_wear = player:get_wielded_item():get_wear()
	dig(wall[1])
	local gained = 0
	for _, stack in ipairs(inv:get_list("main")) do
		if stack:get_name() ~= "" and stack:get_name() ~= "grug_materials:pick_steel" then
			gained = gained + stack:get_count()
		end
	end
	lib.check(node(wall[1]) == "air", "a member digs the marked ore")
	lib.check(gained > count, ("the drop reached the inventory, %d more"):format(gained - count))
	lib.check(player:get_wielded_item():get_wear() > tool_wear, "the pick wore")
	-- the hull round it, the template's own node
	local hull = vector.offset(wall[1], -1, 0, 0)
	local hull_name = node(hull)
	dig(hull)
	lib.check(node(hull) == hull_name, "the hull stays: " .. hull_name)
	lib.check(heard("feed:Expedition – protected") or heard("hint:Expedition – protected"),
		"the hint names the Expedition")
	lib.logf("protection_hint hull %s, ore %s",
		tostring(grug_core.protection_hint(hull, lib.NAME)),
		tostring(grug_core.protection_hint(wall[2], lib.NAME)))
	lib.check(grug_core.protection_hint(wall[2], lib.NAME) == nil, "no hint on what may be dug")
	-- a pick too weak: the ordinary mining rule
	player:set_wielded_item(ItemStack(""))
	dig(wall[2])
	lib.check(node(wall[2]) == ORE, "bare hands: the ordinary harvest rule refuses")
	player:set_wielded_item(ItemStack("grug_materials:pick_steel"))
	-- the dug cell takes nothing back
	local left = core.item_place(ItemStack("default:cobble 5"), player,
		{type = "node", under = wall[2], above = wall[1]})
	lib.check(node(wall[1]) == "air" and left:get_count() == 5, "the dug cell takes no block")
	-- a stranger, then a run that is over
	local owner = run.owner
	run.owner = {kind = "player", name = "somebody_else"}
	dig(wall[2])
	lib.check(node(wall[2]) == ORE, "a stranger cannot dig the ore")
	run.owner = owner
	run.state = "ready"
	dig(wall[2])
	lib.check(node(wall[2]) == ORE, "not in a run that is not running")
	run.state = "running"
	dig(wall[2])
	lib.check(node(wall[2]) == "air", "digs again once it runs")
	tpl.dig[ORE] = nil
	dig(wall[3])
	lib.check(node(wall[3]) == ORE, "an unmarked ore stays")
	tpl.dig[ORE] = true
end

-- Build in a free corner of the hall: every way of placing.
local function prove_building(lib, player, run)
	player:set_pos(feet(rel(run, 30, 5, 20)))
	lib.wait(0.5)
	local floor = rel(run, 32, 4, 20)
	local above = rel(run, 32, 5, 20)
	look_at(player, floor)
	for _, item in ipairs({"default:cobble", "default:torch", "default:chest", "default:ladder_wood",
			"doors:door_wood", "default:sapling", "grug_signs:standing_sign"}) do
		local def = core.registered_items[item]
		if def then
			local stack = ItemStack(item .. " 3")
			local left = (def.on_place or core.item_place)(stack, player, pointed_at(floor))
			left = left or stack
			lib.check(node(above) == "air" and left:get_count() == 3, "build refused: " .. item)
		else
			lib.logf("no item %s", item)
		end
	end
	local bucket = core.registered_items["grug_farming:water_bucket"]
	local left = bucket.on_place(ItemStack("grug_farming:water_bucket"), player, pointed_at(floor))
	lib.check(node(above) == "air" and left:get_name() == "grug_farming:water_bucket",
		"liquid refused: the water bucket stays full")
	if core.registered_items["bucket:bucket_lava"] then
		lib.log("there is a lava bucket")
	end
	lib.check(not grug_core.world_alterable(above), "liquid: no flow may change the box")
	-- a source written by the server (a later template) stays put
	local water = rel(run, 40, 6, 24)
	core.set_node(water, {name = "default:water_source"})
	lib.wait(6)
	local wet = 0
	for _, offset in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}, {0, -1, 0}}) do
		local cell = vector.offset(water, offset[1], offset[2], offset[3])
		local name = node(cell)
		if name:find("water", 1, true) and name ~= "grug_core:water_barrier" then wet = wet + 1 end
	end
	lib.logf("beside a written source: %d wet cells", wet)
	lib.check(wet == 0, "liquid: a source does not spread in the box")
	core.set_node(water, {name = "air"})
end

-- Every direction at every wall of the rooms: the destination stays in a room.
local function prove_blink(lib, player, run)
	local props = player:get_properties()
	local eye_height = props.eye_height or 1.47
	local box = props.collisionbox
	local tries, found, out = 0, 0, 0
	local spots = {rel(run, 5, 5, 5), rel(run, 14, 9, 14), rel(run, 25, 5, 5), rel(run, 42, 11, 26),
		rel(run, 29, 5, 33), rel(run, 38, 9, 42), rel(run, 34, 7, 30)}
	for _, cell in ipairs(spots) do
		local from = feet(cell)
		for yaw = 0, 15 do
			for pitch = -3, 3 do
				local h, v = yaw * math.pi / 8, pitch * math.pi / 8
				local dir = {x = -math.sin(h) * math.cos(v), y = math.sin(v), z = math.cos(h) * math.cos(v)}
				local dest = grug_abilities.blink_destination(
					vector.offset(from, 0, eye_height, 0), dir, 10, eye_height, box)
				tries = tries + 1
				if dest then
					found = found + 1
					-- feet on a floor's top round down into it: ask the cell above
					local here = core.get_node_or_nil(vector.round(vector.offset(dest, 0, 0.5, 0)))
					if E.slot_at(dest) ~= run.slot or not here or
							core.registered_nodes[here.name].walkable then
						out = out + 1
						lib.logf("OUT %s", core.pos_to_string(dest))
					end
				end
			end
		end
	end
	lib.check(found > 0 and out == 0, ("Blink: %d aims, %d destinations, %d out of the rooms"):format(
		tries, found, out))
end

local function prove_charge(lib, player, run)
	-- The dash's own code path; the definition is private, it reads only these.
	local charge = {id = "charge", name = "Charge", kind = "cast", target_kind = "hostile",
		range = 16, values = function() return {damage = 1, rage = 0} end}
	player:set_pos(feet(rel(run, 26, 5, 16)))
	lib.wait(0.5)
	-- a target inside, then one behind the hull in a cell carved beyond the box
	local mob = assert(core.add_entity(vector.offset(feet(rel(run, 36, 5, 16)), 0, 0.5, 0),
		"grug_mobs:giant_spider"))
	lib.wait(0.3)
	local props = player:get_properties()
	local dest = grug_abilities.charge_destination(player:get_pos(), props.eye_height or 1.47,
		props.collisionbox, mob:get_pos())
	lib.check(dest ~= nil, "Charge has a destination in the hall")
	local ok, why = grug_abilities.charge_dash(player, mob, dest, charge)
	lib.logf("dash %s %s", tostring(ok), tostring(why))
	lib.wait_for(function() return not grug_abilities.charge_dashing(player) end, 8)
	lib.check(E.slot_at(player:get_pos()) == run.slot, "Charge ends in the box at " ..
		core.pos_to_string(player:get_pos(), 1))
	mob:remove()
	-- behind the wall: not aimable, so no Charge
	local beyond = {x = run.maxp.x + 2, y = run.minp.y + 6, z = run.minp.z + 16}
	lib.wait_for(function() return core.get_node_or_nil(beyond) ~= nil end, 5)
	core.set_node(beyond, {name = "air"})
	core.set_node(vector.offset(beyond, 0, 1, 0), {name = "air"})
	player:set_pos(feet(rel(run, 42, 5, 16)))
	lib.wait(0.5)
	local outside = assert(core.add_entity(vector.offset(beyond, 0, 0, 0), "grug_mobs:giant_spider"))
	lib.wait(0.3)
	look_at(player, beyond)
	lib.wait(0.3)
	local target = grug_abilities.aimed_target(player, charge)
	lib.check(target == nil, "a mob behind the hull cannot be aimed at")
	outside:remove()
end

function S.rules(lib, player)
	lib.wait(3)
	to_level(player, 30)
	local meta = player:get_meta()
	meta:set_int("grug_mounts:land_tier", TIER.land)
	meta:set_int("grug_mounts:flight_tier", TIER.flight)
	meta:set_int("grug_mounts:water_tier", TIER.boat)
	-- the seam changes nothing on the map
	lib.check(grug_mounts.toggle(player, TIER.land), "a ride on the map")
	grug_mounts.dismount(player, nil, true)
	local _, heard = spies()
	local run = prepared_run(lib, player)
	enter(lib, player, run)
	lib.logf("inside at %s", core.pos_to_string(player:get_pos(), 2))
	prove_mounts(lib, player, heard)
	prove_digging(lib, player, run, heard)
	prove_building(lib, player, run)
	prove_blink(lib, player, run)
	prove_charge(lib, player, run)
	lib.wait_for(function() return not grug_core.in_combat(player) end, 40)

	-- A death in the run: the start waystone, the penalty unchanged, still inside.
	local wears, wear = 0, grug_repair.wear_death
	grug_repair.wear_death = function(p)
		wears = wears + 1
		return wear(p)
	end
	player:set_pos(feet(rel(run, 30, 5, 20)))
	lib.wait(0.5)
	player:set_hp(0, {type = "set"})
	lib.wait_for(function() return player:get_hp() == 0 end, 3)
	lib.wait(1)
	player:respawn()
	local arrival = E.start_arrival(run)
	lib.wait_for(function()
		return player:get_hp() > 0 and vector.distance(player:get_pos(), arrival) < 0.1
	end, 15)
	lib.wait(1.5)
	lib.check(vector.distance(player:get_pos(), arrival) < 0.2,
		"respawn at the start waystone, at " .. core.pos_to_string(player:get_pos(), 2))
	lib.check(E.run_inside(player) == run and run.state == "running", "still in the run")
	lib.check(wears == 1, "the death penalty ran once, wear_death calls " .. wears)
	lib.check(not grug_home.is_pending(player), "the respawn is finished")
	local hold_gone = player:get_physics_override().speed > 0
	lib.check(hold_gone, "the hold is released")

	-- Return Home from inside, under its normal rules.
	lib.check(grug_home.return_home(player), "Return Home starts")
	lib.wait_for(function() return E.run_inside(player) == nil end, 30)
	lib.check(E.run_inside(player) == nil and not E.slot_at(player:get_pos()),
		"Return Home leaves the box, at " .. core.pos_to_string(player:get_pos(), 1))
	lib.check(grug_home.remaining(player) > 0, "with its cooldown")

	-- A run that ends while its player is dead: the ordinary respawn.
	local back_home = player:get_pos()
	lib.check(E.enter(player, "highcourt"), "enter again")
	lib.wait_for(function() return E.run_inside(player) == run end, 30)
	player:set_hp(0, {type = "set"})
	lib.wait(1.5)
	E.end_run(run, "probe")
	player:respawn()
	lib.wait_for(function()
		return player:get_hp() > 0 and not E.slot_at(player:get_pos()) and not grug_home.is_pending(player)
	end, 20)
	lib.wait(1)
	lib.check(not E.slot_at(player:get_pos()) and vector.distance(player:get_pos(), back_home) < 2,
		"the run ended while dead: home, at " .. core.pos_to_string(player:get_pos(), 1))
	lib.logf("run slots free: %s", tostring(E.run_at(rel(run, 8, 5, 8)) == nil))
end

-- ---- Spawns ----------------------------------------------------------------------

local function counting_gate()
	local counts = {calls = 0, refused = 0, allowed = 0, rows = {}}
	local allows = grug_mobs.spawn_policy_allows
	grug_mobs.spawn_policy_allows = function(name, pos)
		local answer = allows(name, pos)
		if pos.x > 4190 then
			counts.calls = counts.calls + 1
			local row = counts.rows[name] or {0, 0}
			counts.rows[name] = row
			if answer then
				counts.allowed = counts.allowed + 1
				row[1] = row[1] + 1
			else
				counts.refused = counts.refused + 1
				row[2] = row[2] + 1
			end
		end
		return answer
	end
	return counts
end

local function report_rows(lib, counts)
	lib.logf("POLICY off-map calls %d refused %d allowed %d", counts.calls, counts.refused, counts.allowed)
	for name, row in pairs(counts.rows) do
		lib.logf("ROW %s allowed %d refused %d", name, row[1], row[2])
	end
end

-- Air in a cube round a position, from what is generated now.
local function air_round(center, radius)
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(vector.subtract(center, radius), vector.add(center, radius))
	local data = vm:get_data()
	local air, ignore = core.get_content_id("air"), core.get_content_id("ignore")
	local a, unknown = 0, 0
	for _, id in ipairs(data) do
		if id == air then a = a + 1 elseif id == ignore then unknown = unknown + 1 end
	end
	return a, unknown, (e2.x - e1.x + 1) * (e2.y - e1.y + 1) * (e2.z - e1.z + 1)
end

local function is_mob(ent)
	return ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:"
end

local function sample(player, seen, radius)
	local here = player:get_pos()
	local objects = core.objects_inside_radius and core.objects_inside_radius(here, radius) or
		core.get_objects_inside_radius(here, radius)
	local alive = 0
	local function take(object)
		local ent = object:get_luaentity()
		if is_mob(ent) then
			alive = alive + 1
			local pos = object:get_pos()
			local row = seen[object]
			if not row then
				row = {name = ent.name, first = vector.copy(pos), last = vector.copy(pos),
					max_x = pos.x, far = 0}
				seen[object] = row
			end
			row.last = vector.copy(pos)
			row.max_x = math.max(row.max_x, pos.x)
			row.far = math.max(row.far, vector.distance(pos, row.first))
		end
	end
	if type(objects) == "table" then
		for _, object in ipairs(objects) do take(object) end
	else
		for object in objects do take(object) end
	end
	return alive
end

function S.spawns(lib, player)
	local counts = counting_gate()
	lib.wait(3)
	to_level(player, 20)
	local run = prepared_run(lib, player)
	enter(lib, player, run)
	lib.logf("slot %d box %s..%s at %s", run.slot, core.pos_to_string(run.minp),
		core.pos_to_string(run.maxp), core.pos_to_string(player:get_pos(), 1))
	local seconds = tonumber(core.settings:get("r71guard_seconds")) or 120
	local center = vector.round(player:get_pos())
	local air0, unknown0 = air_round(center, 80)
	lib.logf("AIR start %d ignore %d", air0, unknown0)
	local seen, peak = {}, 0
	local t0 = core.get_us_time()
	while (core.get_us_time() - t0) / 1e6 < seconds do
		peak = math.max(peak, sample(player, seen, 200))
		lib.wait(1)
	end
	local air1, unknown1, cube = air_round(center, 80)
	lib.logf("AIR end %d ignore %d of %d", air1, unknown1, cube)
	report_rows(lib, counts)
	local total, inside = 0, 0
	local names = {}
	for _, row in pairs(seen) do
		total = total + 1
		names[row.name] = (names[row.name] or 0) + 1
		if E.slot_at(row.first) then inside = inside + 1 end
	end
	for name, n in pairs(names) do lib.logf("MOB %s %d", name, n) end
	lib.logf("MOBS seen %d peak %d in the box %d over %d s", total, peak, inside, seconds)
	lib.logf("player hp %d", player:get_hp())
end

-- Just west of the field: a player for whom mobs do spawn. How far do they get?
function S.wander(lib, player)
	local counts = counting_gate()
	lib.wait(3)
	to_level(player, 60)
	local first = E.slot_box(1)
	local field_x = first.x - 320
	local depth = tonumber(core.settings:get("r71guard_y")) or -80
	local spot = {x = field_x - 48, y = depth, z = first.z + 64}
	local done
	core.emerge_area(vector.offset(spot, -96, -48, -96), vector.offset(spot, 96, 48, 96),
		function(_, _, remaining) if remaining == 0 then done = true end end)
	lib.wait_for(function() return done end, 60)
	if depth < -30 then
		for dx = -2, 2 do
			for dz = -2, 2 do
				core.set_node(vector.offset(spot, dx, -1, dz), {name = "default:stone"})
				for dy = 0, 2 do
					core.set_node(vector.offset(spot, dx, dy, dz), {name = "air"})
				end
			end
		end
	end
	player:set_physics_override({gravity = depth < -30 and 1 or 0})
	player:set_pos({x = spot.x, y = spot.y, z = spot.z})
	lib.logf("standing at %s, field from x %d", core.pos_to_string(player:get_pos(), 1), field_x)
	local seconds = tonumber(core.settings:get("r71guard_seconds")) or 170
	local seen = {}
	local t0 = core.get_us_time()
	while (core.get_us_time() - t0) / 1e6 < seconds do
		sample(player, seen, 220)
		lib.wait(1)
	end
	report_rows(lib, counts)
	local total, in_field, spawned_in, inward, far, last_max = 0, 0, 0, 0, 0, -math.huge
	for _, row in pairs(seen) do
		total = total + 1
		if row.first.x >= field_x then spawned_in = spawned_in + 1 end
		if row.max_x >= field_x then in_field = in_field + 1 end
		inward = math.max(inward, row.max_x - row.first.x)
		far = math.max(far, row.far)
		last_max = math.max(last_max, row.max_x)
		lib.logf("MOB %s first %s last %s max_x %.1f far %.1f", row.name,
			core.pos_to_string(row.first, 1), core.pos_to_string(row.last, 1), row.max_x, row.far)
	end
	lib.logf("WANDER mobs %d spawned in the field %d reached the field %d most inward %.1f most far %.1f furthest x %.1f (field x %d)",
		total, spawned_in, in_field, inward, far, last_max, field_x)
	lib.logf("player hp %d", player:get_hp())
end

return S
