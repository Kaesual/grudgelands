-- Round 25 Lane A engine probe (disposable, never shipped): the Claim Stone
-- core in a real world (run with SEED=4242424242, see ../run.sh).
--
-- Boot 1 (empty probe storage):
--   1. the mod loaded: node variants, pick groupcaps, housing masks gone,
--      grug_zones.hard_footprint_in published;
--   2. the first accepted Accord spot of a lattice over the home zones
--      (pure zone check), emerged; the real stone on_place with a fake
--      placer: refused while the arrival cube holds a node, accepted once it
--      is air; refused next to the faction's start town and in an L1-10
--      zone; placement cost;
--   3. protection for a second (same-faction) player: open while empty,
--      closed once fuelled, open with "everything", closed with "interact",
--      open again after the fuel "expires" (paid_until moved into the past =
--      a faked clock); the arrival cube refuses placing for the owner; the
--      periodic check swaps the node variant and reports "expired";
--   4. liquid: a water source next to the arrival cube floods around it,
--      never into it;
--   5. a second claim is dug with a bronze pick while empty (claim gone,
--      owner destroyed, no drop) and refused while fuelled;
--   6. core.is_protected cost with 0 and 50 registered (fuelled) claims;
--   7. the first claim is refuelled and left standing; its record is written
--      to the probe's mod storage.
-- Boot 2 (same world): the claim, its fuel and the owner's record read back
-- identically from the housing mod storage.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r25_claim_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end
local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r25 claim probe done", false, 0)
end

local storage = core.get_mod_storage()
local model = grug_housing.model
local STONE, EMPTY = grug_housing.STONE_ITEM, grug_housing.EMPTY_STONE
local OWNER, OTHER, DIGGER = "r25owner", "r25other", "r25digger"
local FACTIONS = {[OWNER] = "accord", [OTHER] = "accord", [DIGGER] = "accord",
	r25second = "accord"}

local previous_faction = grug_core.get_player_faction
grug_core.get_player_faction = function(name)
	if FACTIONS[name] then return FACTIONS[name] end
	return previous_faction(name)
end

local function fake_player(name, item)
	local stack = ItemStack(item or "")
	return {
		is_player = function() return true end,
		get_player_name = function() return name end,
		get_player_control = function() return {} end,
		get_wielded_item = function() return ItemStack(stack) end,
		set_wielded_item = function(_, new) stack = ItemStack(new) return true end,
		get_inventory = function() return nil end,
		get_meta = function() return {get_int = function() return 10 ^ 9 end,
			get_string = function() return "" end} end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
	}
end

local events = {}
grug_housing.register_on_claim_changed(function(claim, event)
	events[#events + 1] = event .. ":" .. claim.id
end)

local function surface(x, z)
	local top = grug_zones.terrain_height_at(x, z) + 24
	for y = top, top - 64, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		local def = core.registered_nodes[node.name]
		if def and def.walkable and not def.buildable_to then return y end
	end
	return nil
end

local function clear_cube(pos)
	for dy = 1, 3 do
		for dz = -1, 1 do
			for dx = -1, 1 do
				core.set_node({x = pos.x + dx, y = pos.y + dy, z = pos.z + dz},
					{name = "air"})
			end
		end
	end
end

local function place(name, pos)
	local ground = {x = pos.x, y = pos.y - 1, z = pos.z}
	local stack = ItemStack(STONE)
	local left = core.registered_items[STONE].on_place(stack, fake_player(name),
		{type = "node", under = ground, above = pos})
	return left:is_empty()
end

-- Pure zone check (no map needed): the world queries of api.lua with the
-- cube taken as clear.
local function zone_ok(x, z)
	local zone = grug_zones.get(grug_zones.id_at(x, z) or "")
	if not zone or zone.faction ~= "accord" then return false end
	local world = {}
	for key, fn in pairs(grug_housing.placement_world) do world[key] = fn end
	world.cube_clear = function() return true end
	local ok, code = model.validate("r25scan", "accord", {x = x, y = 0, z = z}, world)
	return ok, code, zone
end

local function boot_two()
	local saved = storage:get_string("claim")
	local id = tonumber(storage:get_string("claim_id"))
	local claim = id and model.claim_by_id(id)
	local line = claim and table.concat({claim.id, claim.owner, claim.center.x,
		claim.center.y, claim.center.z, claim.placed_at, claim.paid_until,
		grug_housing.permission(claim, OTHER) or "-"}, "|") or "missing"
	log("BOOT 2 claim " .. line .. " (saved " .. saved .. ")")
	check(claim ~= nil and line == saved, "claim reads back after restart")
	local c2, state = grug_housing.player_claim(OWNER)
	check(c2 == claim and state == "placed", "owner record reads back after restart")
	check(grug_housing.is_active(claim), "claim still fuelled after restart")
	check(grug_housing.claim_at({x = claim.center.x + 50, y = 0,
		z = claim.center.z - 50}) == claim, "claim grid rebuilt after restart")
	local node = core.get_node_or_nil(claim.center)
	log("BOOT 2 stone node " .. tostring(node and node.name))
	finish()
end

local bench_points
local function bench()
	local t = core.get_us_time()
	for _ = 1, 5 do
		for i = 1, #bench_points do core.is_protected(bench_points[i], OTHER) end
	end
	return (core.get_us_time() - t) * 1000 / (5 * #bench_points)
end

local function scenario(spot)
	local t_scan = spot.scan_ms
	local sx, sz = spot.x, spot.z
	bench_points = {}
	for i = 1, 4000 do
		bench_points[i] = {x = sx - 400 + (i * 37) % 800, y = 20 + (i % 20),
			z = sz - 400 + (i * 91) % 800}
	end
	bench()
	local zero_claims = bench()
	local zero_count = model.claim_count()
	local minp = {x = sx - 60, y = -20, z = sz - 60}
	local maxp = {x = sx + 60 + 101, y = 120, z = sz + 60}
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED around %d,%d in %.1f s"):format(sx, sz,
			(core.get_us_time() - started) / 1e6))
		local y = surface(sx, sz)
		if not check(y ~= nil, "surface found") then return finish() end
		local pos = {x = sx, y = y + 1, z = sz}
		-- 2. Arrival cube refusal, then acceptance.
		clear_cube(pos)
		core.set_node({x = sx + 1, y = pos.y + 2, z = sz - 1}, {name = "default:dirt"})
		check(not place(OWNER, pos), "refused while the arrival cube holds a node")
		clear_cube(pos)
		core.set_node(pos, {name = "air"})
		local t0 = core.get_us_time()
		local placed = place(OWNER, pos)
		local place_ms = (core.get_us_time() - t0) / 1000
		check(placed, "stone accepted at an eligible L11-30 Accord spot")
		local claim, state = grug_housing.player_claim(OWNER)
		if not check(claim ~= nil and state == "placed", "owner state placed") then
			return finish()
		end
		log(("PLACED claim %d at %s in %s (L%d-%d); placement %.1f ms, zone scan %.1f ms"):format(
			claim.id, core.pos_to_string(pos), spot.zone.id, spot.zone.level_min,
			spot.zone.level_max, place_ms, t_scan))
		check(core.get_node(pos).name == EMPTY, "a new stone stands empty")
		-- 3. Protection.
		local inside = {x = sx + 20, y = pos.y + 2, z = sz + 20}
		check(not core.is_protected(inside, OTHER), "empty claim: open to others")
		check(grug_housing.add_fuel(claim, 3) == 3, "fuel accepted")
		check(grug_housing.remaining_seconds(claim) >= 3 * 26160 - 2, "remaining after fuel")
		check(core.get_node(pos).name == STONE, "fuelled stone variant")
		check(core.is_protected(inside, OTHER), "fuelled claim: other player refused")
		check(not core.is_protected(inside, OWNER), "fuelled claim: owner builds")
		check(core.is_protected({x = sx + 20, y = 400, z = sz + 20}, OTHER),
			"claim unbounded upward")
		check(not core.is_protected({x = sx + 20, y = -101, z = sz + 20}, OTHER),
			"below y -100 not claimed")
		check(not core.is_protected({x = sx + 51, y = pos.y, z = sz}, OTHER),
			"outside the 101 square")
		grug_housing.set_permission(claim, OTHER, "everything")
		check(not core.is_protected(inside, OTHER), "everything: builds")
		grug_housing.set_permission(claim, OTHER, "interact")
		check(core.is_protected(inside, OTHER), "interact: refused")
		check(core.is_protected({x = sx, y = pos.y + 1, z = sz}, OWNER),
			"arrival cube refuses the owner's placement")
		-- The dig refusal of a fuelled stone (nobody digs it).
		local dug = core.node_dig(pos, core.get_node(pos),
			fake_player(OWNER, "default:pick_bronze"))
		check(core.get_node(pos).name == STONE, "fuelled stone survives a dig attempt")
		log("DIG fuelled stone by owner: node_dig=" .. tostring(dug))
		-- Faked clock: the paid-until time moves into the past.
		claim.paid_until = os.time() - 1
		check(not grug_housing.is_active(claim), "expired by the wall clock")
		check(not core.is_protected(inside, OTHER), "expired claim: open to others")
		check(core.is_protected({x = sx, y = pos.y + 1, z = sz}, OTHER),
			"expired claim keeps the arrival cube")
		-- 4. Liquid next to the cube.
		local source = {x = sx + 2, y = pos.y + 3, z = sz}
		core.set_node(source, {name = "default:water_source"})
		core.after(7, function()
			local wet_cube, wet_near = 0, 0
			for dy = 1, 3 do
				for dz = -1, 1 do
					for dx = -1, 1 do
						local n = core.get_node({x = sx + dx, y = pos.y + dy, z = sz + dz}).name
						if n:find("water") then wet_cube = wet_cube + 1 end
					end
				end
			end
			for dy = 0, 3 do
				for dz = -2, 2 do
					for dx = 2, 4 do
						local n = core.get_node({x = sx + dx, y = pos.y + dy, z = sz + dz}).name
						if n:find("water") then wet_near = wet_near + 1 end
					end
				end
			end
			log(("LIQUID water nodes: arrival cube %d, beside it %d"):format(wet_cube,
				wet_near))
			check(wet_cube == 0, "no water in the arrival cube")
			check(wet_near > 0, "water flows beside the cube")
			core.set_node(source, {name = "air"})
			-- The periodic check has run: variant and expiry event.
			check(core.get_node(pos).name == EMPTY, "periodic check: empty variant")
			local seen = false
			for _, e in ipairs(events) do
				if e == "expired:" .. claim.id then seen = true end
			end
			check(seen, "expired event reported")
			log("EVENTS " .. table.concat(events, " "))
			-- 5. A second claim, dug with a pick.
			local x2 = sx + 101
			local y2 = surface(x2, sz)
			local ok2 = zone_ok(x2, sz)
			log(("SECOND spot %d,%d zone check %s"):format(x2, sz, tostring(ok2)))
			if ok2 and y2 then
				local pos2 = {x = x2, y = y2 + 1, z = sz}
				clear_cube(pos2)
				core.set_node(pos2, {name = "air"})
				check(place("r25second", pos2), "edge-to-edge second claim accepted")
				local c2 = grug_housing.player_claim("r25second")
				grug_housing.add_fuel(c2, 1)
				core.node_dig(pos2, core.get_node(pos2), fake_player(DIGGER, "default:pick_bronze"))
				check(model.claim_by_id(c2.id) ~= nil, "fuelled second stone not dug")
				c2.paid_until = os.time() - 1
				grug_housing.sync_stone_node(c2)
				local hand = core.node_dig(pos2, core.get_node(pos2), fake_player(DIGGER, ""))
				check(model.claim_by_id(c2.id) ~= nil, "hand cannot dig the empty stone")
				local pick_ok, pick_res = pcall(core.node_dig, pos2, core.get_node(pos2),
					fake_player(DIGGER, "default:pick_bronze"))
				log(("DIG empty second stone: hand=%s pick=%s %s -> %s"):format(tostring(hand),
					tostring(pick_ok), tostring(pick_res), core.get_node(pos2).name))
				check(model.claim_by_id(c2.id) == nil and core.get_node(pos2).name == "air",
					"bronze pick digs the empty stone, claim gone")
				local _, state2 = grug_housing.player_claim("r25second")
				check(state2 == "destroyed", "second owner destroyed")
				local drops = core.get_objects_inside_radius(pos2, 3)
				local items = 0
				for _, obj in ipairs(drops) do
					local ent = obj:get_luaentity()
					if ent and ent.name == "__builtin:item" then items = items + 1 end
				end
				check(items == 0, "no drop from the destroyed stone")
			else
				check(false, "second edge-to-edge spot usable")
			end
			-- 6. is_protected cost.
			local extra = {}
			for i = 1, 49 do
				local cx = sx - 2000 + ((i - 1) % 7) * 101
				local cz = sz + 3000 + math.floor((i - 1) / 7) * 101
				local c = model.create("r25bench" .. i, {x = cx, y = 10, z = cz})
				model.add_fuel(c, 5)
				extra[#extra + 1] = c
			end
			-- Some of the fifty inside the benchmark area.
			for i = 1, 10 do
				local c = extra[i]
				model.remove(c, "picked_up")
				local moved = model.create("r25benchin" .. i, {x = sx - 400 + i * 101,
					y = 10, z = sz - 300})
				model.add_fuel(moved, 5)
				extra[i] = moved
			end
			bench()
			local fifty = bench()
			log(("BENCH core.is_protected (4000 columns round the spot): %.0f ns per call" ..
				" with %d claims, %.0f ns with %d claims (10 of them in the sampled area)"):format(
				zero_claims, zero_count, fifty, model.claim_count()))
			for _, c in ipairs(extra) do model.remove(c, "picked_up") end
			-- 7. Leave the first claim fuelled for boot 2.
			check(grug_housing.add_fuel(claim, 5) == 5, "refuel after expiry (ruling 20)")
			check(grug_housing.is_active(claim), "refuelled claim active again")
			grug_housing.set_permission(claim, OTHER, "interact")
			local line = table.concat({claim.id, claim.owner, claim.center.x,
				claim.center.y, claim.center.z, claim.placed_at, claim.paid_until,
				grug_housing.permission(claim, OTHER) or "-"}, "|")
			storage:set_string("claim", line)
			storage:set_string("claim_id", tostring(claim.id))
			log("BOOT 1 claim " .. line)
			finish()
		end)
	end)
end

core.after(3, function()
	if storage:get_string("claim_id") ~= "" then return boot_two() end
	-- 1. Load.
	check(core.registered_nodes[STONE] and core.registered_nodes[EMPTY],
		"stone nodes registered")
	local caps = core.registered_items["default:pick_bronze"].tool_capabilities
	check(caps.groupcaps.grug_claim_stone and
		caps.groupcaps.grug_claim_stone.times[1] == 60, "bronze pick: 60 s cap")
	local steel = core.registered_items["grug_materials:pick_abyssal_steel"]
	check(steel and steel.tool_capabilities.groupcaps.grug_claim_stone.times[1] == 10,
		"T6 pick: 10 s cap")
	check(ItemStack(""):get_tool_capabilities().groupcaps.grug_claim_stone == nil,
		"hand has no claim-stone cap")
	check(grug_zones.housing_eligible_at == nil and
		type(grug_zones.hard_footprint_in) == "function" and
		grug_zones.claim_exclusion_in == nil, "authority: masks gone, footprint query in")
	-- 2. Refusals by zone: next to the Accord (human) start and in its L1-10 zone.
	local start = grug_core.start_anchor("accord", "human")
	local near_ok, near_code = zone_ok(start.x, start.z + 150)
	local low_ok, low_code = zone_ok(start.x + 300, start.z)
	log(("REFUSED near start %d,%d: %s; L1-10 at %d,%d: %s"):format(start.x,
		start.z + 150, tostring(near_code), start.x + 300, start.z, tostring(low_code)))
	check(not near_ok and not low_ok, "start town and L1-10 zone refused")
	local low_zone = grug_zones.get(grug_zones.id_at(start.x + 300, start.z))
	check(low_zone and low_zone.level_max <= 10, "the L1-10 sample lies in an L1-10 zone")
	-- Through the stone itself (on_place) at the start: refused.
	core.emerge_area({x = start.x - 2, y = start.y - 4, z = start.z + 148},
		{x = start.x + 2, y = start.y + 8, z = start.z + 152}, function(_, _, left)
		if left > 0 then return end
		local y = surface(start.x, start.z + 150)
		check(y and not place(OWNER, {x = start.x, y = y + 1, z = start.z + 150}),
			"on_place refused next to the start town")
		-- The first accepted Accord spot of a lattice (edge to edge).
		local t = core.get_us_time()
		local spot
		for x = -2400, 2400, 101 do
			for z = -2500, -1000, 101 do
				local ok, _, zone = zone_ok(x, z)
				if ok and grug_zones.water_class_at(x, z) == "land" and
						grug_zones.water_class_at(x + 101, z) == "land" and
						zone_ok(x + 101, z) then
					spot = {x = x, z = z, zone = zone}
					break
				end
			end
			if spot then break end
		end
		if not check(spot ~= nil, "an eligible Accord spot exists") then return finish() end
		local t1 = core.get_us_time()
		zone_ok(spot.x, spot.z)
		spot.scan_ms = (core.get_us_time() - t1) / 1000
		log(("SPOT %d,%d in %s (search %.1f s)"):format(spot.x, spot.z, spot.zone.id,
			(core.get_us_time() - t) / 1e6))
		scenario(spot)
	end)
end)
