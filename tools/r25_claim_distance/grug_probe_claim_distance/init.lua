-- Round 25 Lane A2 engine probe (disposable, never shipped): claim distance
-- to settlements (ruling 27) and a road through a claim (ruling 17) in a real
-- world, merged main with every housing mod (run with SEED=4242424242, see
-- ../run.sh).
--   1. the housing mods loaded, grug_zones.hard_footprint_in published and
--      grug_zones.claim_exclusion_in gone;
--   2. a village core of seed 4242424242 (candidates from
--      tools/r25_claim_core/fixture.lua; the probe finds the core's edge
--      itself with grug_core.world_feature_boxes_in): a stone 20 nodes from
--      the core is refused ("site"), one 70 nodes away is accepted -- inside
--      the village's old 160-node blend envelope, which refused it before;
--   3. a road through that claim: every corridor column across it stays
--      protected for the owner, and on its middle column
--      (placing onto it and digging it refused, hint "Road – protected"),
--      the owner builds next to it, a stranger is refused there with the
--      claim hint.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r25_distance_probe] "
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
	core.request_shutdown("r25 distance probe done", false, 0)
end

local STONE = grug_housing.STONE_ITEM
local OWNER, OTHER = "r25a2owner", "r25a2other"
local FACTIONS = {[OWNER] = "accord", [OTHER] = "accord"}
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
		get_look_dir = function() return {x = 0, y = -1, z = 0} end,
		get_look_horizontal = function() return 0 end,
	}
end

-- The highest walkable, not buildable_to node of a column.
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

-- The real stone's on_place with a fake placer; true when the stone stands.
local function place_stone(name, pos)
	local left = core.registered_items[STONE].on_place(ItemStack(STONE),
		fake_player(name), {type = "node", under = {x = pos.x, y = pos.y - 1, z = pos.z},
		above = pos})
	return left:is_empty()
end

-- Pure placement check (no map), the shipped world queries with the cube
-- taken as clear.
local function zone_check(name, pos)
	local world = {}
	for key, fn in pairs(grug_housing.placement_world) do world[key] = fn end
	world.cube_clear = function() return true end
	local ok, code, message = grug_housing.model.validate(name,
		grug_core.get_player_faction(name), pos, world)
	return ok, code, message
end

-- A player placing a dirt node through the engine's own placement
-- (core.item_place_node: core.is_protected decides). True when placed.
local function place_dirt(name, ground)
	local above = {x = ground.x, y = ground.y + 1, z = ground.z}
	local ok, _, placed = pcall(core.item_place_node, ItemStack("default:dirt"),
		fake_player(name, "default:dirt"), {type = "node", under = ground, above = above})
	return ok and placed ~= nil and core.get_node(above).name == "default:dirt", above
end

local function road_kind_near(x, z, y)
	for dy = -1, 1 do
		local kind = grug_core.world_feature_at({x = x, y = y + dy, z = z})
		if kind == "road" or kind == "bridge" then return kind end
	end
	return nil
end

-- Village cores of seed 4242424242 on Accord land (a point inside the core,
-- its y inside the core's box) and the side to try.
local CANDIDATES = {
	{x = -925, y = 65, z = -1557, dx = -1, dz = 0, key = "r20_anchor_016"},
	{x = 875, y = 105, z = -1557, dx = 0, dz = 1, key = "r20_anchor_018"},
	{x = -1869, y = 110, z = -2037, dx = 0, dz = 1, key = "copperfell_village"},
}

local function scenario(c, edge)
	local near = {x = edge.x + c.dx * 20, z = edge.z + c.dz * 20}
	local far = {x = edge.x + c.dx * 70, z = edge.z + c.dz * 70}
	local minp = {x = math.min(near.x, far.x) - 56, y = c.y - 50,
		z = math.min(near.z, far.z) - 56}
	local maxp = {x = math.max(near.x, far.x) + 56, y = c.y + 50,
		z = math.max(near.z, far.z) + 56}
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED %s..%s in %.1f s"):format(core.pos_to_string(minp),
			core.pos_to_string(maxp), (core.get_us_time() - started) / 1e6))
		-- 2. 20 nodes from the core: refused as a settlement.
		local ny = surface(near.x, near.z)
		if not check(ny ~= nil, "surface at the near spot") then return finish() end
		local near_pos = {x = near.x, y = ny + 1, z = near.z}
		clear_cube(near_pos)
		core.set_node(near_pos, {name = "air"})
		local ok20, code20, message20 = grug_housing.validate_placement(fake_player(OWNER),
			near_pos)
		check(not ok20 and code20 == "site", "20 nodes from the village core: site")
		check(not place_stone(OWNER, near_pos), "on_place refused 20 nodes from the core")
		log(("NEAR %s (20 from the core): %s, %q"):format(core.pos_to_string(near_pos),
			tostring(code20), tostring(message20)))
		-- 70 nodes away: accepted.
		local fy = surface(far.x, far.z)
		if not check(fy ~= nil, "surface at the far spot") then return finish() end
		local pos = {x = far.x, y = fy + 1, z = far.z}
		clear_cube(pos)
		core.set_node(pos, {name = "air"})
		local t0 = core.get_us_time()
		local placed = place_stone(OWNER, pos)
		local place_ms = (core.get_us_time() - t0) / 1000
		check(placed, "stone accepted 70 nodes from the village core")
		local claim = grug_housing.player_claim(OWNER)
		if not check(claim ~= nil, "owner has the claim") then return finish() end
		-- Round 26: a placed stone is a draft; activate it (5 lumps) first.
		check(grug_housing.model.activate(claim, 5) == 5 and
			grug_housing.add_fuel(claim, 3) == 3 and grug_housing.is_active(claim),
			"activated and fuelled")
		log(("FAR claim %d at %s (70 from the core, %d/%d from the village centre," ..
			" inside the old 160-node blend envelope: %s); placement %.1f ms"):format(
			claim.id, core.pos_to_string(pos), math.abs(pos.x - c.x), math.abs(pos.z - c.z),
			tostring(math.abs(pos.x - c.x) <= 131 and math.abs(pos.z - c.z) <= 131),
			place_ms))
		-- 3. A road column inside the claim (its surface node in the corridor),
		-- away from the arrival cube.
		local road, road_kind
		for r = 3, 50 do
			for dx = -r, r do
				for dz = -r, r do
					if not road and (math.abs(dx) == r or math.abs(dz) == r) then
						local x, z = pos.x + dx, pos.z + dz
						local y = surface(x, z)
						local kind = y and grug_core.world_feature_at({x = x, y = y, z = z})
						if kind == "road" then road, road_kind = {x = x, y = y, z = z}, kind end
					end
				end
			end
			if road then break end
		end
		if not check(road ~= nil, "a road runs through the claim") then return finish() end
		-- Next to the road: the first column beside the corridor's near edge
		-- (either side, x or z) with no road or bridge at its surface.
		local beside
		for step = 1, 16 do
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				if not beside then
					local x, z = road.x + d[1] * step, road.z + d[2] * step
					local y = surface(x, z)
					local b = y and {x = x, y = y, z = z}
					if b and not road_kind_near(x, z, y + 1) and
							not grug_core.world_feature_at({x = x, y = y + 1, z = z}) and
							grug_housing.claim_at(b) == claim and
							not grug_housing.model.in_arrival_cube(claim, {x = x, y = y + 1, z = z}) then
						beside = b
					end
				end
			end
			if beside then break end
		end
		if not check(beside ~= nil, "a column next to the road in the claim") then
			return finish()
		end
		-- Across the corridor from there: its columns, and the middle one (the
		-- road itself) for the owner's place and dig attempts.
		local sx = road.x - beside.x
		local sz = road.z - beside.z
		local step_x = sx == 0 and 0 or (sx > 0 and 1 or -1)
		local step_z = sz == 0 and 0 or (sz > 0 and 1 or -1)
		local crossing, names = {}, {}
		for k = 0, 40 do
			local x, z = road.x + step_x * k, road.z + step_z * k
			local y = surface(x, z)
			local kind = y and grug_core.world_feature_at({x = x, y = y, z = z})
			if kind ~= "road" and kind ~= "bridge" then break end
			crossing[#crossing + 1] = {x = x, y = y, z = z}
			names[#names + 1] = core.get_node({x = x, y = y, z = z}).name:gsub("^.*:", "")
		end
		local owner_open = 0
		for _, p in ipairs(crossing) do
			if not core.is_protected(p, OWNER) or
					not core.is_protected({x = p.x, y = p.y + 1, z = p.z}, OWNER) then
				owner_open = owner_open + 1
			end
		end
		check(owner_open == 0, "every corridor column protected for the owner")
		log(("CROSSING %d corridor columns from %s: %s; open to the owner: %d"):format(
			#crossing, core.pos_to_string(road), table.concat(names, " "), owner_open))
		road = crossing[math.floor((#crossing + 1) / 2)]
		check(grug_housing.claim_at(road) == claim, "the road column lies in the claim")
		check(core.is_protected(road, OWNER), "road surface protected for the owner")
		local hint = grug_core.protection_hint(road, OWNER)
		check(hint == "Road – protected", "owner's hint on the road")
		local on_road, above_road = place_dirt(OWNER, road)
		check(not on_road, "owner cannot place onto the road")
		local node = core.get_node(road)
		core.node_dig(road, node, fake_player(OWNER, "grug_materials:pick_bronze"))
		check(core.get_node(road).name == node.name, "owner cannot dig the road")
		log(("ROAD %s (%s, node %s) in claim %d: owner is_protected=%s, hint %q," ..
			" place above=%s, dig kept %s"):format(core.pos_to_string(road), road_kind,
			node.name, claim.id, tostring(core.is_protected(road, OWNER)), tostring(hint),
			tostring(on_road), core.get_node(road).name))
		local target = {x = beside.x, y = beside.y + 1, z = beside.z}
		check(core.is_protected(target, OTHER), "stranger refused next to the road")
		local other_hint = grug_core.protection_hint(target, OTHER)
		check(other_hint == "Home of " .. OWNER .. " – protected", "stranger's claim hint")
		local other_placed = place_dirt(OTHER, beside)
		check(not other_placed, "stranger cannot build next to the road")
		check(not core.is_protected(target, OWNER), "owner may build next to the road")
		local built = place_dirt(OWNER, beside)
		check(built, "owner builds next to the road")
		log(("BESIDE %s (beside the corridor, %d from its middle column): stranger hint %q, stranger placed=%s;" ..
			" owner placed=%s -> %s"):format(core.pos_to_string(target),
			math.max(math.abs(beside.x - road.x), math.abs(beside.z - road.z)),
			tostring(other_hint), tostring(other_placed), tostring(built),
			core.get_node(target).name))
		finish()
	end)
end

core.after(3, function()
	-- 1. Load.
	local mods = {}
	for _, name in ipairs(core.get_modnames()) do
		if name:find("housing") or name:find("home") then mods[#mods + 1] = name end
	end
	table.sort(mods)
	log("MODS " .. table.concat(mods, " "))
	check(rawget(_G, "grug_housing") and grug_housing.open_stone_interface and
		rawget(_G, "grug_home") ~= nil, "housing mods loaded")
	check(type(grug_zones.hard_footprint_in) == "function" and
		grug_zones.claim_exclusion_in == nil, "hard_footprint_in in, claim_exclusion_in gone")
	check(grug_housing.model.SETTLEMENT_MARGIN == 16, "margin 16")
	-- 2. The first candidate whose 70-node spot passes the map-free check and
	-- holds a road.
	local chosen, chosen_edge
	for _, c in ipairs(CANDIDATES) do
		local kind = grug_core.world_feature_at({x = c.x, y = c.y, z = c.z})
		log(("CANDIDATE %s at %d,%d,%d: %s"):format(c.key, c.x, c.y, c.z, tostring(kind)))
		if kind == "village" then
			local ex, ez = c.x, c.z
			while grug_core.world_feature_boxes_in(ex + c.dx, ez + c.dz, ex + c.dx,
					ez + c.dz, 0) do
				ex, ez = ex + c.dx, ez + c.dz
			end
			local edge = {x = ex, z = ez}
			local far = {x = ex + c.dx * 70, y = 0, z = ez + c.dz * 70}
			local ok, code = zone_check(OWNER, far)
			log(("  core edge %d,%d; 70 away %d,%d: %s"):format(ex, ez, far.x, far.z,
				ok and "ok" or tostring(code)))
			if ok and not chosen then chosen, chosen_edge = c, edge end
		end
	end
	if not check(chosen ~= nil, "a village with an eligible spot 70 from its core") then
		return finish()
	end
	scenario(chosen, chosen_edge)
end)
