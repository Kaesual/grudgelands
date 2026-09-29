-- Round 25 Lane E engine probe (disposable, never shipped): road and POI
-- protection (rulings 15-17) on a real generated world.
--
-- 1. ROAD: picks a straight, nearly level stretch of a real network road in
--    home territory, away from every other road and settlement core, emerges
--    it and checks the generated surface node against the corridor's surface
--    node. Across the road (perpendicular, at the surface height) the
--    protection must be exactly "distance to the centreline <= half width +
--    3" (distances printed); the home-faction probe digger is refused on the
--    last protected column and digs the first open one; placing likewise; at
--    the centre column +5/-5 are refused, +6/-6 allowed. The hint line.
-- 2. BRIDGE: the same surface check and hint on a real bridge run.
-- 3. VILLAGE, CAMP and POI: a real village's core box edges (x/z faces,
--    placement - 10 and highest node + 10) refused, one beyond allowed, and
--    the hint lines of a village, a bandit camp and an outpost.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r25_road_poi_probe] "
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

local PROBE_NAME = "r25eprobe"
local PICK = "default:pick_bronze"
local faction = "accord"
-- Installed once the server runs: grug_factions defines the real lookup
-- after this mod has loaded.
local previous_faction
local function override_faction()
	previous_faction = grug_core.get_player_faction
	grug_core.get_player_faction = function(name)
		if name == PROBE_NAME then return faction end
		return previous_faction(name)
	end
end

local function probe_player(item)
	local stack = ItemStack(item or "")
	return {
		is_player = function() return true end,
		get_player_name = function() return PROBE_NAME end,
		get_wielded_item = function() return ItemStack(stack) end,
		set_wielded_item = function(_, new) stack = ItemStack(new) return true end,
		get_inventory = function() return nil end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_look_dir = function() return {x = 0, y = -1, z = 0} end,
		get_meta = function() return nil end,
	}
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	grug_core.get_player_faction = previous_faction
	core.request_shutdown("r25 road poi probe done", false, 0)
end

local modpath = core.get_modpath("grug_mapgen") .. "/wp40"
local roads = dofile(modpath .. "/road_layout.lua")
local wp = dofile(modpath .. "/world_protection.lua")
local SURFACES = {}
for _, name in ipairs({"default:cobble", "default:stone_block",
		"default:silver_sandstone_block", "default:stonebrick", "default:desert_cobble",
		"default:mossycobble", "default:wood", "default:pine_wood", "default:aspen_wood",
		"default:acacia_wood", "default:junglewood"}) do
	SURFACES[name] = true
end

-- Dig (a stone set there first) and place (dirt onto a stone below, the
-- target set to air first); returns whether each went through.
local function dig_at(pos)
	core.set_node(pos, {name = "default:stone"})
	local player = probe_player(PICK)
	local ok, result = pcall(core.node_dig, pos, core.get_node(pos), player)
	if not ok then log("node_dig error " .. tostring(result)) end
	return core.get_node(pos).name == "air"
end
local function place_at(pos)
	local under = {x = pos.x, y = pos.y - 1, z = pos.z}
	core.set_node(under, {name = "default:stone"})
	core.set_node(pos, {name = "air"})
	local ok, result = pcall(core.item_place_node, ItemStack("default:dirt"),
		probe_player("default:dirt"), {type = "node", under = under, above = pos})
	if not ok then log("item_place_node error " .. tostring(result)) end
	return core.get_node(pos).name == "default:dirt"
end
local function edit_both(pos, label, protected)
	local dug, placed = dig_at(pos), place_at(pos)
	local hint = grug_core.protection_hint(pos, PROBE_NAME)
	log(("%s %s: protected=%s kind=%s dig=%s place=%s hint=%s"):format(label,
		core.pos_to_string(pos), tostring(core.is_protected(pos, PROBE_NAME)),
		tostring(grug_core.world_feature_at(pos)), tostring(dug), tostring(placed),
		tostring(hint)))
	check(core.is_protected(pos, PROBE_NAME) == protected, label .. " is_protected")
	check(dug == not protected, label .. " dig " .. (protected and "refused" or "allowed"))
	check(placed == not protected, label .. " place " ..
		(protected and "refused" or "allowed"))
	return hint
end

-- The road layout the world was generated with.
local layout = roads.deserialize(grug_mapgen.wp40.road_layout_text)
local road_list = {}
for id, r in pairs(layout.roads) do road_list[#road_list + 1] = r end
table.sort(road_list, function(a, b) return a.id < b.id end)

local function nearest_on(r, x, z)
	local best, bi, bu = math.huge, nil, nil
	for i = 1, #r.X - 1 do
		local ax, az = r.X[i], r.Z[i]
		local vx, vz = r.X[i + 1] - ax, r.Z[i + 1] - az
		local l2 = vx * vx + vz * vz
		local u = l2 > 0 and ((x - ax) * vx + (z - az) * vz) / l2 or 0
		if u < 0 then u = 0 elseif u > 1 then u = 1 end
		local dx, dz = x - ax - u * vx, z - az - u * vz
		local d2 = dx * dx + dz * dz
		if d2 < best then best, bi, bu = d2, i, u end
	end
	return math.sqrt(best), bi, bu
end
local function other_road_within(r, x, z, distance)
	for _, o in ipairs(road_list) do
		if o ~= r then
			local d = nearest_on(o, x, z)
			if d <= distance then return true end
		end
	end
	return false
end

-- A straight, level, lone stretch in home territory: kind "G" around it,
-- the heading within ~8 degrees of an axis over +-8 points, the profile
-- within half a node over +-8 points.
local function pick_stretch(want_class)
	for _, r in ipairs(road_list) do
		if r.kind == "primary" or r.kind == "secondary" then
			local n = #r.X
			for i = 20, n - 20, 7 do
				local ok = true
				for j = i - 8, i + 8 do
					if r.cls[j] ~= want_class then ok = false break end
				end
				local dx, dz = r.X[i + 8] - r.X[i - 8], r.Z[i + 8] - r.Z[i - 8]
				local len = math.sqrt(dx * dx + dz * dz)
				local along_x = math.abs(dx) >= 0.99 * len
				local along_z = math.abs(dz) >= 0.99 * len
				if ok and (along_x or along_z) and
						math.abs(r.R[i + 8] - r.R[i - 8]) < 0.5 then
					local x, z = math.floor(r.X[i] + 0.5), math.floor(r.Z[i] + 0.5)
					local s = wp.surface_node(r.R[i], r.R[i], 0)
					local pos = {x = x, y = s, z = z}
					local rule = grug_zones.territory_rule_at(pos)
					if (rule == "accord_home" or rule == "throng_home") and
							grug_zones.hard_protection_kind_at(pos) == nil and
							not other_road_within(r, x, z, 40) then
						local clear = true
						for o = -16, 16 do
							local p = along_x and {x = x, y = s, z = z + o} or {x = x + o, y = s, z = z}
							local k = grug_core.world_feature_at(p)
							if k ~= nil and k ~= "road" and k ~= "bridge" then clear = false end
						end
						if clear then return r, i, along_x, rule end
					end
				end
			end
		end
	end
end

local function emerge(minp, maxp, fn)
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED %s..%s in %.1f s"):format(core.pos_to_string(minp),
			core.pos_to_string(maxp), (core.get_us_time() - started) / 1000000))
		local ok, err = pcall(fn)
		check(ok, "scenario ran (" .. tostring(err) .. ")")
	end)
end

local function road_scenario(done)
	local r, i, along_x, rule = pick_stretch("G")
	if not check(r ~= nil, "a straight lone road stretch in home territory") then
		return done()
	end
	faction = rule == "accord_home" and "accord" or "throng"
	local x, z = math.floor(r.X[i] + 0.5), math.floor(r.Z[i] + 0.5)
	local s = wp.surface_node(r.R[i], r.R[i], 0)
	log(("ROAD %d (%s, half width %.1f) point %d at %d,%d surface %d, %s, probe faction %s"):format(
		r.id, r.kind, r.hw, i, x, z, s, rule, faction))
	emerge({x = x - 16, y = s - 16, z = z - 16}, {x = x + 16, y = s + 16, z = z + 16}, function()
		local centre = {x = x, y = s, z = z}
		local _, ci, cu = nearest_on(r, x, z)
		local cs = wp.surface_node(r.R[ci], r.R[ci + 1], cu)
		local names = {}
		for dy = -1, 2 do names[#names + 1] = core.get_node({x = x, y = cs + dy, z = z}).name end
		log(("SURFACE column %d,%d: corridor surface %d; nodes y%+d..%+d: %s"):format(x, z, cs,
			-1, 2, table.concat(names, " ")))
		check(SURFACES[core.get_node({x = x, y = cs, z = z}).name] == true,
			"the generated road surface node lies at the corridor's surface")
		-- Across the road at the surface height.
		local reach = r.hw + wp.ROAD_SIDE
		local last_in, first_out = {}, {}
		for side = -1, 1, 2 do
			for o = 0, 12 do
				local p = along_x and {x = x, y = cs, z = z + side * o} or
					{x = x + side * o, y = cs, z = z}
				local d, ni, nu = nearest_on(r, p.x, p.z)
				local ps = wp.surface_node(r.R[ni], r.R[ni + 1], nu)
				local kind = grug_core.world_feature_at(p)
				local want = d <= reach and math.abs(p.y - ps) <= wp.ROAD_VERTICAL
				check((kind ~= nil) == want, ("offset %+d distance %.2f kind %s"):format(
					side * o, d, tostring(kind)))
				if kind then last_in[side] = {o = o, d = d, p = p} elseif
						not first_out[side] then first_out[side] = {o = o, d = d, p = p} end
			end
			log(("ACROSS side %+d: last protected offset %d (distance %.2f), first open " ..
				"offset %d (distance %.2f), limit %.1f"):format(side, last_in[side].o,
				last_in[side].d, first_out[side].o, first_out[side].d, reach))
			check(last_in[side].d <= reach and first_out[side].d > reach,
				"the corridor edge is half width + 3")
			check(first_out[side].o == last_in[side].o + 1, "one edge per side")
			local hint = edit_both(last_in[side].p, "EDGE IN side " .. side, true)
			check(hint == "Road – protected", "road hint")
			local out = first_out[side].p
			if grug_zones.territory_rule_at(out) == rule then
				check(edit_both(out, "EDGE OUT side " .. side, false) == nil, "no hint outside")
			end
		end
		-- Vertically at the centre column.
		for _, row in ipairs({{5, true}, {6, false}, {-5, true}, {-6, false}}) do
			edit_both({x = x, y = cs + row[1], z = z}, ("CENTRE y%+d"):format(row[1]), row[2])
		end
		-- The flash line a punch shows on the road (grug_materials).
		local punch = grug_materials.punch_hint(centre, core.get_node(centre),
			probe_player(PICK))
		log("PUNCH HINT on the road: " .. tostring(punch))
		check(punch == "Road – protected", "punch hint on the road")
		done()
	end)
end

local function bridge_scenario(done)
	-- the middle of the longest bridge run ("B" points)
	local best, br, bi
	for _, r in ipairs(road_list) do
		if r.kind == "primary" or r.kind == "secondary" or r.kind == "trail" then
			local run = 0
			for i = 1, #r.cls do
				if r.cls[i] == "B" then
					run = run + 1
					if not best or run > best then best, br, bi = run, r, i - math.floor(run / 2) end
				else
					run = 0
				end
			end
		end
	end
	if not br then
		log("BRIDGE none in this world")
		return done()
	end
	local x, z = math.floor(br.X[bi] + 0.5), math.floor(br.Z[bi] + 0.5)
	local _, ci, cu = nearest_on(br, x, z)
	local cs = wp.surface_node(br.R[ci], br.R[ci + 1], cu)
	emerge({x = x - 8, y = cs - 12, z = z - 8}, {x = x + 8, y = cs + 12, z = z + 8}, function()
		local pos = {x = x, y = cs, z = z}
		local node = core.get_node(pos).name
		local kind = grug_core.world_feature_at(pos)
		faction = "accord"
		local hint_a = grug_core.protection_hint(pos, PROBE_NAME)
		faction = "throng"
		local hint_t = grug_core.protection_hint(pos, PROBE_NAME)
		log(("BRIDGE road %d (%s) run of %d at %s: node %s, kind %s, hints %s / %s, " ..
			"+6 %s, -6 %s"):format(br.id, br.kind, best, core.pos_to_string(pos), node,
			tostring(kind), tostring(hint_a), tostring(hint_t),
			tostring(grug_core.world_feature_at({x = x, y = cs + 6, z = z})),
			tostring(grug_core.world_feature_at({x = x, y = cs - 6, z = z}))))
		check(SURFACES[node] == true, "the bridge deck lies at the corridor's surface")
		if grug_zones.hard_protection_kind_at(pos) == nil then
			check(kind == "bridge" and hint_a == "Bridge – protected" and
				hint_t == "Bridge – protected", "bridge kind and hint")
		end
		done()
	end)
end

local SETTLEMENTS = {
	{key = "goldmead_village", zone = "elandor_goldmead_vale", slot = "village_1",
		half = 12, top = 8, kind = "village", text = "Village – protected"},
	{key = "goldmead_bandit_camp", zone = "elandor_goldmead_vale", slot = "bandit_1",
		half = 12, top = 8, kind = "camp", text = "Camp – protected"},
	{key = "goldmead_outpost", zone = "elandor_goldmead_vale", slot = "outpost_1",
		half = 8, top = 8, kind = "poi", text = "Point of interest – protected"},
}

local function settlement_scenario(done)
	local row = SETTLEMENTS[1]
	local anchor = grug_zones.anchor(row.zone, row.slot)
	faction = "accord"
	local x0, x1 = anchor.x - row.half, anchor.x + row.half - 1
	local z0, z1 = anchor.z - row.half, anchor.z + row.half - 1
	local y0, y1 = anchor.y - 10, anchor.y + row.top + 10
	log(("VILLAGE %s anchor %s: box x %d..%d, y %d..%d, z %d..%d"):format(row.key,
		core.pos_to_string(anchor), x0, x1, y0, y1, z0, z1))
	emerge({x = x0 - 4, y = y0 - 4, z = z0 - 4}, {x = x1 + 4, y = y1 + 4, z = z1 + 4}, function()
		local my = anchor.y + 2
		-- the face whose outside neighbour is open ground of the home faction
		local faces = {
			{{x = x0, y = my, z = anchor.z}, {x = x0 - 1, y = my, z = anchor.z}},
			{{x = x1, y = my, z = anchor.z}, {x = x1 + 1, y = my, z = anchor.z}},
			{{x = anchor.x, y = my, z = z0}, {x = anchor.x, y = my, z = z0 - 1}},
			{{x = anchor.x, y = my, z = z1}, {x = anchor.x, y = my, z = z1 + 1}},
		}
		local tested = 0
		for index, face in ipairs(faces) do
			local inside = edit_both(face[1], "VILLAGE face " .. index .. " in", true)
			check(inside == row.text, "village hint")
			if grug_core.world_feature_at(face[2]) == nil and
					grug_zones.territory_rule_at(face[2]) == "accord_home" and
					grug_zones.hard_protection_kind_at(face[2]) == nil then
				edit_both(face[2], "VILLAGE face " .. index .. " out", false)
				tested = tested + 1
			else
				log(("VILLAGE face %d out %s: kind %s (a road reaches the core), skipped"):format(
					index, core.pos_to_string(face[2]),
					tostring(grug_core.world_feature_at(face[2]))))
			end
		end
		check(tested >= 1, "at least one open face beside the village")
		-- vertical limits at a corner column away from the anchor column
		local cx, cz = x0 + 1, z0 + 1
		for _, v in ipairs({{y1, true}, {y1 + 1, false}, {y0, true}, {y0 - 1, false}}) do
			local p = {x = cx, y = v[1], z = cz}
			if v[2] or (grug_core.world_feature_at(p) == nil and
					grug_zones.territory_rule_at(p) == "accord_home") then
				edit_both(p, ("VILLAGE y %d"):format(v[1]), v[2])
			end
		end
		for index = 2, #SETTLEMENTS do
			local s = SETTLEMENTS[index]
			local a = grug_zones.anchor(s.zone, s.slot)
			local p = {x = a.x - s.half, y = a.y + s.top + 10, z = a.z + s.half - 1}
			local hint = grug_core.protection_hint(p, PROBE_NAME)
			log(("%s %s anchor %s: corner %s kind %s hint %s"):format(s.kind:upper(), s.key,
				core.pos_to_string(a), core.pos_to_string(p),
				tostring(grug_core.world_feature_at(p)), tostring(hint)))
			check(hint == s.text, s.key .. " hint")
		end
		done()
	end)
end

core.after(2, function()
	override_faction()
	road_scenario(function()
		bridge_scenario(function()
			settlement_scenario(finish)
		end)
	end)
end)
