-- Round 46 lane PL engine probe (disposable, never shipped): placed POIs on
-- a real world (tools/r46_pl/engine.sh boots it).
--
-- Per seed a few placed POIs (seed 8507030740356938342, which stopped at
-- load before Round 46: the Accord fortress and Copperfell Village; any
-- other seed: Causeway Accord Picket and Tarncut Mine, plus the quest place
-- of the clash site Ashen Wheelbreak):
-- 1. PLACEMENT: the settlement registry, `grug_zones.anchor` and the
--    placement text of this world (`grug_mapgen.wp40.placement_layout_text`)
--    give the same x/z;
-- 2. GROUND: the area round the core is emerged; every core column has
--    walkable ground at the anchor height, no water in the core, the yard
--    round the anchor root is open, and sockets stand;
-- 3. PROTECTION: the core is a protected world feature;
-- 4. ROADS: a fortress's gate trail starts in front of its gate; a village
--    or mainland camp or mine is reached by a road or trail (a road feature
--    within 40 nodes of its core);
-- 5. QUESTS AND MAP: a clash site's "use at a place" target resolves to its
--    placed anchor (`grug_quests.use_place_xz`), and the map's settlement
--    rows carry the placed anchors.
-- 6. CACHE: the world folder's layout cache holds this placement text; on a
--    second boot of the same world (ROOT re-use) the text equals the one
--    the first boot wrote to `r46pl_placement.txt`.
-- Ends the server itself; "RESULT PASS" is the verdict.
local PREFIX = "[r46_pl_probe] "
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
	core.request_shutdown("r46 pl probe done", false, 0)
end

local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local roster = dofile(wp40 .. "/r7_settlement.lua").roster
local source = dofile(wp40 .. "/source/simple_map.lua")
local prof = {}
for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end
local profile_of = {}
for _, p in ipairs(roster) do profile_of[p.key] = p end

local seed = core.get_mapgen_setting("seed")
local WANT = seed == "8507030740356938342" and {"pvp_fortress_accord", "copperfell_village"} or
	{"pvp_camp_broken_causeway_accord_low", "r20_anchor_061"}

local function node_at(x, y, z) return core.get_node({x = x, y = y, z = z}) end
local function walkable(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false
end
local function liquid(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.liquidtype ~= nil and def.liquidtype ~= "none"
end
local function solid_top(x, z, y0, y1)
	for y = y1, y0, -1 do
		local name = node_at(x, y, z).name
		if name ~= "air" and name ~= "ignore" then return y, name end
	end
end

local placed = {}
local function read_placement()
	local text = grug_mapgen.wp40.placement_layout_text
	check(type(text) == "string" and text:match("^P1 %d+\n") ~= nil, "placement text published")
	for id, x, z in (text or ""):gmatch("(anchor_%d+) (%-?%d+) (%-?%d+) %d+\n") do
		placed[id] = {x = tonumber(x), z = tonumber(z)}
	end
	return text
end

local function cache_check(text)
	local world = core.get_worldpath()
	local file = io.open(world .. "/grug_world_layouts.txt", "rb")
	local bytes = file and file:read("*a") or ""
	if file then file:close() end
	local len, at = bytes:match("\nsection placement (%d+) %x+\n()")
	local body = len and bytes:sub(at, at + tonumber(len) - 1)
	check(body == text, "the layout cache holds this placement")
	local saved_path = world .. "/r46pl_placement.txt"
	local saved = io.open(saved_path, "rb")
	if saved then
		local before = saved:read("*a")
		saved:close()
		check(before == text, "second boot: the same placement as the first")
		log("second boot: placement equal to the first boot's")
	else
		local out = assert(io.open(saved_path, "wb"))
		out:write(text)
		out:close()
		log("first boot: placement saved")
	end
end

local function poi(key, done)
	local p = profile_of[key]
	if not check(p ~= nil, key .. " in the roster") then return done() end
	local a = grug_core.settlement_socket_anchor(key)
	if not check(a ~= nil, key .. " registered") then return done() end
	local z_anchor = grug_zones.anchor(p.zone_id, p.slot)
	local want = placed[p.anchor_id]
	check(want and a.x == want.x and a.z == want.z, key .. " registered at its placed anchor")
	check(z_anchor and z_anchor.x == a.x and z_anchor.z == a.z, key .. " grug_zones.anchor agrees")
	local kind = source.anchors[p.numeric_id].template_id
	local core_half = prof[kind].building_core_width / 2
	local reach = core_half + 40
	local y0, y1 = a.y - 40, a.y + 40
	local t0 = core.get_us_time()
	core.emerge_area({x = a.x - reach, y = y0, z = a.z - reach},
		{x = a.x + reach, y = y1, z = a.z + reach}, function(_, _, remaining)
		if remaining > 0 then return end
		local ok, err = pcall(function()
			log(("%s (%s) at %d,%d,%d emerged in %.1f s"):format(key, kind, a.x, a.y, a.z,
				(core.get_us_time() - t0) / 1000000))
			local bad, wet = 0, 0
			for z = a.z - core_half, a.z + core_half - 1 do
				for x = a.x - core_half, a.x + core_half - 1 do
					if not walkable(node_at(x, a.y, z).name) then bad = bad + 1 end
					if liquid(node_at(x, a.y + 1, z).name) then wet = wet + 1 end
				end
			end
			check(bad == 0, ("%s: core ground at y %d (%d columns not)"):format(key, a.y, bad))
			check(wet == 0, ("%s: no water on the core (%d columns)"):format(key, wet))
			local standing, waystone = 0, nil
			for _, s in ipairs(grug_core.settlement_sockets_at(key)) do
				local q = s.pos
				if s.id == "travel_waypoint" then waystone = q end
				if not walkable(node_at(q.x, q.y, q.z).name) and
						not walkable(node_at(q.x, q.y + 1, q.z).name) and
						walkable(node_at(q.x, q.y - 1, q.z).name) then
					standing = standing + 1
				end
			end
			check(standing >= 1, key .. ": sockets stand (" .. standing .. ")")
			check(grug_core.world_feature_at({x = a.x, y = a.y + 1, z = a.z}) ~= nil,
				key .. ": core protected (" ..
				tostring(grug_core.world_feature_at({x = a.x, y = a.y + 1, z = a.z})) .. ")")
			if kind == "pvp_fortress" then
				check(waystone and node_at(waystone.x, waystone.y, waystone.z).name ==
					"grug_mapgen:waystone", key .. ": waystone at its socket")
				local gx = a.x > 0 and -1 or 1
				local tx = a.x + gx * (24 + 12)
				local ty = solid_top(tx, a.z, y0, y1)
				check(ty and grug_core.world_feature_at({x = tx, y = ty, z = a.z}) == "road",
					key .. ": the gate trail runs in front of the gate")
			end
			if kind ~= "pvp_camp_low" and kind ~= "pvp_camp_high" then
				local road = false
				for d = core_half + 12, core_half + 40, 4 do
					for t = -d, d, 4 do
						for _, c in ipairs({{t, -d}, {t, d}, {-d, t}, {d, t}}) do
							local x, z = a.x + c[1], a.z + c[2]
							local y = solid_top(x, z, y0, y1)
							if not road and y and grug_core.world_feature_at({x = x, y = y, z = z}) ==
									"road" then
								road = true
							end
						end
					end
				end
				check(road, key .. ": a road or trail reaches it")
			end
			local row
			for _, s in ipairs(grug_core.settlement_socket_settlements()) do
				if s.key == key then row = s end
			end
			check(row and row.anchor.x == a.x and row.anchor.z == a.z,
				key .. ": the map's settlement row at the placed anchor")
		end)
		check(ok, key .. " probe ran: " .. tostring(err))
		done()
	end)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local text = read_placement()
		cache_check(text)
		if seed ~= "8507030740356938342" then
			local xz = grug_quests.use_place_xz("r20_anchor_071")
			local want = placed.anchor_071
			check(xz and want and xz.x == want.x and xz.z == want.z,
				"the clash site's quest place is its placed anchor")
		end
		local index = 0
		local function step()
			index = index + 1
			if index > #WANT then return finish() end
			poi(WANT[index], step)
		end
		step()
	end)
end)
