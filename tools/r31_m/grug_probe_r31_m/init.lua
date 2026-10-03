-- Round 31 Lane M engine probe (disposable, never shipped): one PvP fortress
-- and two camps of one Battlegrounds zone on a real world.
--
-- Seed 42 takes the Accord fortress and the Accord camps of The Broken
-- Causeway, every other seed the Throng fortress and the Throng camps of The
-- Shattered Line. Per POI the area round its anchor is emerged and read:
-- 1. PLACEMENT: the settlement is registered under its key at the source's
--    anchor x/z (a camp under a race of its faction);
-- 2. TERRAIN FIT: every column of the building core has walkable ground at
--    the anchor height, the 5x5 yard round the anchor root is open, and
--    every socket stands (feet and head free, ground below); the collar's
--    largest step within 8 nodes of the core is logged;
-- 3. PROTECTION: the core and its blueprint box plus 10 nodes are the world
--    feature "fortress" / "camp" and refused to both factions; 12 nodes out
--    on at least two sides is not;
-- 4. WAYSTONE (fortress): the travel_waypoint socket holds
--    grug_mapgen:waystone, grug_home lists it among the faction's seven
--    known stones and never for the other faction;
-- 5. GATE: a fortress's gate trail starts in front of its gate (the node
--    there is world feature "road") and the own faction alone sees its map
--    icon; walking from the trail start (a camp: 6 nodes outside its gate)
--    on walkable ground (steps of at most one node, two nodes of headroom)
--    reaches the anchor yard (logged, a warning when not); a camp's map icon
--    shows to both factions.
-- Every POI's surroundings are written to the world folder as
-- r31m_<key>.cells.tsv (x y z name param2, anchor-relative: the exposed
-- ground and everything above it) and r31m_<key>.sockets.tsv for the
-- preview pictures. Ends the server itself; "RESULT PASS" is the verdict.

local PREFIX = "[r31_m_probe] "
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

local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local catalog = dofile(wp40 .. "/r31_pvp_catalog.lua")
local BOX = {pvp_fortress = 24, pvp_camp_low = 11, pvp_camp_high = 13}
local prof = {}
for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end
local zone_numeric = {}
for _, z in ipairs(source.zones) do zone_numeric[z.id] = z.numeric_id end

local seed = core.get_mapgen_setting("seed")
local WANT = seed == "42" and {"pvp_fortress_accord", "pvp_camp_broken_causeway_accord_low",
	"pvp_camp_broken_causeway_accord_high"} or {"pvp_fortress_throng",
	"pvp_camp_shattered_line_throng_low", "pvp_camp_shattered_line_throng_high"}

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r31 m probe done", false, 0)
end

local function node_at(x, y, z) return core.get_node({x = x, y = y, z = z}) end
local function walkable(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false
end
local function solid_top(x, z, y0, y1)
	for y = y1, y0, -1 do
		local name = node_at(x, y, z).name
		if name ~= "air" and name ~= "ignore" then return y, name end
	end
end

local function fake_player(faction, set)
	local data = {["grug_factions:faction"] = faction, ["grug_home:waypoints"] = set}
	local meta = {get_string = function(_, k) return data[k] or "" end}
	return {get_player_name = function() return "r31m_probe_" .. faction end,
		get_meta = function() return meta end}
end

local function poi(row, done)
	local anchor_source = source.anchors[100 + (function()
		for i, r in ipairs(catalog.rows) do if r.key == row.key then return i end end
	end)()]
	local a = grug_core.settlement_socket_anchor(row.key)
	if not check(a ~= nil, row.key .. " registered") then return done() end
	check(a.x == anchor_source.position.x and a.z == anchor_source.position.z,
		row.key .. " at the source anchor")
	local race
	for _, s in ipairs(grug_core.settlement_socket_settlements()) do
		if s.key == row.key then race = s.race_id end
	end
	local ok_race = false
	for _, r in ipairs(catalog.FACTION_RACES[row.faction]) do ok_race = ok_race or r == race end
	check(ok_race, row.key .. " registered as a race of its faction (" .. tostring(race) .. ")")
	local core_half = prof[row.kind].building_core_width / 2
	local box = BOX[row.kind]
	local reach = core_half + 30
	local y0, y1 = a.y - 40, a.y + 40
	local t0 = core.get_us_time()
	core.emerge_area({x = a.x - reach, y = y0, z = a.z - reach},
		{x = a.x + reach, y = y1, z = a.z + reach}, function(_, _, remaining)
		if remaining > 0 then return end
		local ok, err = pcall(function()
			log(("%s: %s at %d,%d,%d emerged in %.1f s"):format(row.key, race, a.x, a.y, a.z,
				(core.get_us_time() - t0) / 1000000))
			-- 2. terrain fit
			local flat_bad = 0
			for z = a.z - core_half, a.z + core_half - 1 do
				for x = a.x - core_half, a.x + core_half - 1 do
					if not walkable(node_at(x, a.y, z).name) then flat_bad = flat_bad + 1 end
				end
			end
			check(flat_bad == 0, ("%s: core ground at y %d (%d columns not)"):format(row.key, a.y,
				flat_bad))
			for dz = -2, 2 do
				for dx = -2, 2 do
					check(node_at(a.x + dx, a.y + 1, a.z + dz).name == "air",
						row.key .. " anchor yard open")
				end
			end
			local step = 0
			for d = core_half + 1, core_half + 8 do
				for t = -core_half, core_half - 1, 2 do
					for _, c in ipairs({{t, -d}, {t, d - 1}, {-d, t}, {d - 1, t}}) do
						local y = solid_top(a.x + c[1], a.z + c[2], y0, y1)
						if y then step = math.max(step, math.abs(y - a.y)) end
					end
				end
			end
			local sockets = grug_core.settlement_sockets_at(row.key)
			local standing, waystone = 0, nil
			for _, s in ipairs(sockets) do
				local p = s.pos
				if s.id == "travel_waypoint" then
					waystone = p
				else
					local feet, head = node_at(p.x, p.y, p.z).name, node_at(p.x, p.y + 1, p.z).name
					local below = node_at(p.x, p.y - 1, p.z).name
					if check(not walkable(feet) and not walkable(head) and walkable(below),
							("%s socket %s stands (%s/%s on %s)"):format(row.key, s.id, feet, head, below)) then
						standing = standing + 1
					end
				end
			end
			log(("%s: %d sockets standing, collar step up to %d nodes within 8 of the core")
				:format(row.key, standing, step))
			-- 3. protection
			local kind = row.kind == "pvp_fortress" and "fortress" or "war_camp"
			local open_sides = 0
			for _, c in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local p = {x = a.x + c[1] * (box + 10), y = a.y + 1, z = a.z + c[2] * (box + 10)}
				check(grug_core.world_feature_at(p) == kind, ("%s protected 10 beyond its box (%s)")
					:format(row.key, tostring(grug_core.world_feature_at(p))))
				check(grug_core.world_protected_for_faction(p, "accord") and
					grug_core.world_protected_for_faction(p, "throng"), row.key .. " refused to both")
				local q = {x = a.x + c[1] * (box + 12), y = a.y + 1, z = a.z + c[2] * (box + 12)}
				if grug_core.world_feature_at(q) == nil then open_sides = open_sides + 1 end
			end
			check(grug_core.world_feature_at({x = a.x, y = a.y + 1, z = a.z}) == kind,
				row.key .. " core protected")
			check(open_sides >= 2, row.key .. " margin ends")
			-- 4. waystone
			if row.kind == "pvp_fortress" then
				check(waystone and node_at(waystone.x, waystone.y, waystone.z).name ==
					"grug_mapgen:waystone", row.key .. " waystone node at its socket")
				local all = {}
				for _, r in ipairs(catalog.rows) do all[#all + 1] = r.key end
				for _, id in ipairs({"hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar",
						"kapok", "dur_brannoc", "highcourt", "lethariel", "nhal_veyr", "gor_drazhak",
						"kezamba"}) do all[#all + 1] = id end
				local own = grug_home.known_waypoints(fake_player(row.faction, table.concat(all, " ")))
				local found
				for _, w in ipairs(own) do
					if w.id == row.key then found = w end
				end
				check(#own == 7, row.key .. " seven known stones for its faction (" .. #own .. ")")
				check(found and vector.equals(found.pos, waystone), row.key .. " own faction knows it")
				local enemy = row.faction == "accord" and "throng" or "accord"
				for _, w in ipairs(grug_home.known_waypoints(fake_player(enemy, row.key))) do
					check(w.id ~= row.key, row.key .. " never the enemy's stone")
				end
				log(("%s: waystone at %s, %d own stones"):format(row.key,
					core.pos_to_string(waystone), #own))
			end
			-- 5. the gate approach: a fortress's gate faces the middle road's
			-- axis, and its trail starts in front of it; a camp's gate faces its
			-- own continent
			local gx, gz = 0, (row.faction == "accord") and -1 or 1
			if row.kind == "pvp_fortress" then gx, gz = a.x > 0 and -1 or 1, 0 end
			local sx, sz = a.x + gx * (box + 6), a.z + gz * (box + 6)
			if row.kind == "pvp_fortress" then
				-- beyond the 10-node protection margin the trail is a road
				-- corridor of its own
				local tx, tz = a.x + gx * (box + 12), a.z
				local ty = solid_top(tx, tz, y0, y1)
				check(ty and grug_core.world_feature_at({x = tx, y = ty, z = tz}) == "road",
					("%s: the gate trail runs at %d,%d (%s)"):format(row.key, tx, tz,
						ty and node_at(tx, ty, tz).name or "-"))
				sx, sz = a.x + gx * (core_half + 4), a.z
				-- the map: the own faction sees the fortress icon, the enemy not
				local function sees(faction)
					for _, m in ipairs(grug_map.atlas.collect_markers(fake_player(faction, ""),
							{settlement = true})) do
						if m.id == "settlement:" .. row.key then return true end
					end
					return false
				end
				local enemy = row.faction == "accord" and "throng" or "accord"
				check(sees(row.faction) and not sees(enemy), row.key .. ": icon for its own faction only")
			end
			-- standing heights near `y`: walkable ground, two nodes of air
			local function stand(x, z, y)
				for _, h in ipairs({y, y + 1, y - 1}) do
					if walkable(node_at(x, h, z).name) and not walkable(node_at(x, h + 1, z).name) and
							not walkable(node_at(x, h + 2, z).name) then
						return h
					end
				end
			end
			local seen, queue, head = {}, {}, 1
			local first = solid_top(sx, sz, y0, y1)
			first = first and stand(sx, sz, first)
			local reached = false
			if first then
				seen[sx .. "," .. sz] = true
				queue[1] = {sx, sz, first}
			end
			while head <= #queue and not reached do
				local x, z, y = queue[head][1], queue[head][2], queue[head][3]
				head = head + 1
				if math.abs(x - a.x) <= 2 and math.abs(z - a.z) <= 2 then reached = true end
				for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local nx, nz = x + d[1], z + d[2]
					local k = nx .. "," .. nz
					local bound = math.max(box + 8, core_half + 6)
					if not seen[k] and math.abs(nx - a.x) <= bound and math.abs(nz - a.z) <= bound then
						local ny = stand(nx, nz, y)
						if ny then
							seen[k] = true
							queue[#queue + 1] = {nx, nz, ny}
						end
					end
				end
			end
			if row.kind ~= "pvp_fortress" then
				local seen = 0
				for _, faction in ipairs({"accord", "throng"}) do
					for _, m in ipairs(grug_map.atlas.collect_markers(fake_player(faction, ""),
							{settlement = true})) do
						if m.id == "settlement:" .. row.key then seen = seen + 1 end
					end
				end
				check(seen == 2, row.key .. ": icon for both factions")
			end
			if reached then
				log(("%s: the gate approach from %d,%d reaches the yard"):format(row.key, sx, sz))
			else
				core.log("warning", PREFIX .. ("WARN %s: no walk from %d,%d (top %s) to the yard")
					:format(row.key, sx, sz, tostring(first)))
			end
			-- the dump for the pictures
			local path = core.get_worldpath() .. "/r31m_" .. row.key
			local out = assert(io.open(path .. ".cells.tsv", "w"))
			local tops = {}
			for z = a.z - reach, a.z + reach do
				for x = a.x - reach, a.x + reach do
					tops[x .. "," .. z] = solid_top(x, z, y0, y1) or y0
				end
			end
			local cells = 0
			for z = a.z - reach, a.z + reach do
				for x = a.x - reach, a.x + reach do
					local t = tops[x .. "," .. z]
					local low = t
					for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
						local n = tops[(x + d[1]) .. "," .. (z + d[2])]
						if n and n < low then low = n end
					end
					for y = math.max(y0, low - 1), t do
						local node = node_at(x, y, z)
						if node.name ~= "air" and node.name ~= "ignore" then
							out:write(("%d\t%d\t%d\t%s\t%d\n"):format(x - a.x, y - a.y, z - a.z,
								node.name, node.param2))
							cells = cells + 1
						end
					end
				end
			end
			out:close()
			out = assert(io.open(path .. ".sockets.tsv", "w"))
			for _, s in ipairs(sockets) do
				local group = s.tags and s.tags[1] or ""
				out:write(("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\n"):format(s.id, s.role, group,
					s.pos.x - a.x, s.pos.y - a.y, s.pos.z - a.z, s.dir.x, s.dir.z))
			end
			out:close()
			log(("%s: dumped %d cells"):format(row.key, cells))
		end)
		check(ok, row.key .. " scenario ran (" .. tostring(err) .. ")")
		done()
	end)
end

core.after(2, function()
	local rows = {}
	for _, key in ipairs(WANT) do
		for _, r in ipairs(catalog.rows) do if r.key == key then rows[#rows + 1] = r end end
	end
	local index = 0
	local function step()
		index = index + 1
		if index > #rows then return finish() end
		poi(rows[index], step)
	end
	step()
end)
