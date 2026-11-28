-- Round 89 lane HALLS portable test (LuaJIT): the arena Breach Road's halls
-- with the inside stair, the roofed balcony and its barrier (round89-plan.md
-- ruling 3 and "The barrier"; the approved draft tools/r89_balcony_draft/),
-- on the real model (`wp40/breach_model.lua` over the shipped templates),
-- the real layout (`wp40/breach_layout.lua`) and the territory rules
-- (`grug_pvp/rules.lua`).
--
--   luajit tools/r89_halls/portable_test.lua [REPO]
--
-- B  the boxes: each hall's friendly list is the draft's (interior, upper
--    stair, balcony), the interior as before; world() hands them out.
-- K  the barrier: 45 cells per hall exactly at the draft's places
--    (grug_mapgen:arena_barrier, nowhere else), every face toward the
--    balcony closed by the barrier, a wall, the deck or the roof.
-- W  the walk: a 0.6-wide body along every lane of both flights (lower flight,
--    turn, upper flight) and over the whole deck and the parapet's rail, on
--    the real cells' collision boxes, never rises more than half a node at
--    once, keeps two nodes clear above it, and stands in its hall's
--    friendly territory at every sample, also at the top of a jump.
-- T  territory: every node of every friendly box answers its faction
--    (friendly; enemy for the other); every open cell beside a box but in
--    none is a doorway of the interior (the friendly air leaks nowhere
--    else); both roofs' landings, every roof top, the barrier's outer side,
--    the barrier itself and the gate court under the balcony answer the
--    zone (contested).
-- N  the node (world_nodes.lua, on a recording engine): the barrier's
--    definition (airlike, solid, "blocking", light through, no dig, no drop,
--    no grug_air), and the raycast wrapper: a server ray naming no
--    pointabilities points the barrier, one naming its own keeps them.
-- Prints "R89 HALLS PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local L = dofile(wp40 .. "/breach_layout.lua")
local B = dofile(wp40 .. "/breach_model.lua")
local R = dofile(repo .. "/mods/PLAYER/grug_pvp/rules.lua")
local model = B.new(wp40)
local floor = math.floor
local BARRIER = "grug_mapgen:arena_barrier"
local FACTIONS = {"accord", "throng"}
local SIGN = {accord = 1, throng = -1}

-- The hall frame of the draft (tools/r89_balcony_draft/halls.py place): u
-- toward the road, y from the floor layer, v; to the layout's local frame.
local function local_of(faction, u, y, v)
	local s = SIGN[faction]
	return s * (42 - u) + 0, y + 6, -s * v + 0
end
local function name_at(lx, ly, lz)
	-- (+ 0: a column key of -0 would read "-0")
	local c = model.column(lx + 0, lz + 0)
	local v = c and c.cells[ly + 1]
	if v == nil or v == B.AIR or v == B.KEEP then return v == B.KEEP and "@keep" or "air" end
	local e = model.entries[v]
	return e.name or ("@" .. e.role)
end
local function hall_name(faction, u, y, v)
	return name_at(local_of(faction, u, y, v))
end

-- B -------------------------------------------------------------------------
-- The draft's handoff table (REPORT.md "Layout handoff"), layout-local.
local DRAFT = {
	accord = {barrier = {{22, 14, -14}, {22, 18, -6}},
		{{31, 7, -14}, {41, 13, 14}}, {{30, 14, -14}, {37, 18, -12}}, {{23, 15, -14}, {29, 18, -6}}},
	throng = {barrier = {{-22, 14, 6}, {-22, 18, 14}},
		{{-41, 7, -14}, {-31, 13, 14}}, {{-37, 14, 12}, {-30, 18, 14}}, {{-29, 15, 6}, {-23, 18, 14}}},
}
local function same_box(b, lo, hi)
	return b.min.x == lo[1] and b.min.y == lo[2] and b.min.z == lo[3] and
		b.max.x == hi[1] and b.max.y == hi[2] and b.max.z == hi[3]
end
for _, faction in ipairs(FACTIONS) do
	local hall, want = L.HALLS[faction], DRAFT[faction]
	check(#hall.friendly == 3, "B " .. faction .. ": three friendly boxes")
	for index = 1, 3 do
		check(same_box(hall.friendly[index], want[index][1], want[index][2]),
			"B " .. faction .. " friendly box " .. index .. " is the draft's")
	end
	check(hall.friendly[1] == hall.interior and same_box(hall.interior, want[1][1], want[1][2]),
		"B " .. faction .. ": the interior is unchanged and the first friendly box")
end
local site = {x = -72, z = 8, y = 23, reach = 29}
local W = L.world(site)
local halls = {}
for _, faction in ipairs(FACTIONS) do
	local wh = W.halls[faction]
	check(#wh.friendly == 3 and wh.interior.min.x == site.x + L.HALLS[faction].interior.min.x,
		"B world() hands out the " .. faction .. " boxes")
	for index, b in ipairs(wh.friendly) do
		local lb = L.HALLS[faction].friendly[index]
		check(b.min.x == site.x + lb.min.x and b.max.y == site.y + lb.max.y and
			b.max.z == site.z + lb.max.z, "B world box " .. index .. " in world nodes")
		halls[#halls + 1] = {faction = faction, min = b.min, max = b.max}
	end
end
-- the territory as the game asks it (grug_pvp: the Battlegrounds contested)
local zones = {pvp_rule_at = function() return "contested" end, faction_at = function() return nil end}
local function answer(lx, ly, lz, own)
	local rule, here = R.zone_answers(zones, halls, {x = site.x + lx, y = site.y + ly, z = site.z + lz})
	return R.territory(rule, here, own)
end
local function friendly_at(faction, lx, ly, lz)
	local other = faction == "accord" and "throng" or "accord"
	return answer(lx, ly, lz, faction) == "friendly" and answer(lx, ly, lz, other) == "enemy"
end
local function contested_at(lx, ly, lz)
	return answer(lx, ly, lz, "accord") == "contested" and answer(lx, ly, lz, "throng") == "contested"
end
local function in_boxes(faction, lx, ly, lz)
	for _, b in ipairs(L.HALLS[faction].friendly) do
		if lx >= b.min.x and lx <= b.max.x and ly >= b.min.y and ly <= b.max.y and
				lz >= b.min.z and lz <= b.max.z then
			return true
		end
	end
	return false
end

-- K -------------------------------------------------------------------------
for _, faction in ipairs(FACTIONS) do
	local lo, hi = DRAFT[faction].barrier[1], DRAFT[faction].barrier[2]
	local count, stray = 0, 0
	-- the hall box (template u 0..20, y 0..18, v -15..15)
	for u = 0, 20 do
		for y = 0, 18 do
			for v = -15, 15 do
				local lx, ly, lz = local_of(faction, u, y, v)
				local inside = lx >= lo[1] and lx <= hi[1] and ly >= lo[2] and ly <= hi[2] and
					lz >= lo[3] and lz <= hi[3]
				local name = name_at(lx, ly, lz)
				if inside then
					check(name == BARRIER, ("K %s barrier at %d,%d,%d"):format(faction, lx, ly, lz))
					count = count + 1
				elseif name == BARRIER then
					stray = stray + 1
				end
			end
		end
	end
	check(count == 45 and stray == 0, "K " .. faction .. ": 45 barrier cells, none elsewhere")
	-- the barrier meets both solid flanks, the roof above and nothing below
	-- the deck's floor layer is open (the deck's floor meets its heel)
	for y = 8, 12 do
		for _, v in ipairs({5, 15}) do
			local n = hall_name(faction, 20, y, v)
			check(n ~= "air" and n ~= BARRIER, "K " .. faction .. " flank wall at y " .. y)
		end
	end
	for v = 6, 14 do
		check(hall_name(faction, 20, 13, v) ~= "air", "K " .. faction .. " roof over the barrier")
		check(hall_name(faction, 19, 8, v) ~= "air", "K " .. faction .. " the deck meets its heel")
		check(hall_name(faction, 19, 9, v) == "grug_decor:capital_rail",
			"K " .. faction .. " the parapet's rail at v " .. v)
	end
end

-- W -------------------------------------------------------------------------
-- Collision boxes (node-relative, param2 0) of the nodes in the hall boxes;
-- every other node there is a full cube (the model forces param2 0).
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local SLAB = {{-0.5, -0.5, -0.5, 0.5, 0, 0.5}}
local SHAPES = {
	["grug_decor:capital_rail"] = {{-0.08, -0.5, -0.5, 0.08, -0.2, 0.5},
		{-0.08, 0.15, -0.5, 0.08, 0.35, 0.5}, {-0.13, -0.5, -0.13, 0.13, 0.5, 0.13}},
	[B.WAYSTONE] = {{-0.4, -0.5, -0.4, 0.4, -0.3, 0.4}, {-0.25, -0.3, -0.25, 0.25, 1, 0.25}},
}
local function shape(name)
	if name == "air" then return nil end
	if name:find("^stairs:slab_") then return SLAB end
	check(SHAPES[name] or not (name:find("^stairs:") or name:find("^grug_decor:capital_")),
		"W a known shape for " .. name)
	return SHAPES[name] or FULL
end
local HALF, CLEAR = 0.3, 2
-- The support height (layout-local y) under a body at (x, z), and the check
-- that nothing intersects the body from there up CLEAR nodes. `expect` is
-- the designed walking level, a number or a function of a cell's column (a
-- body over a step edge rests on the higher tread only where it is
-- designed to): as tools/r89_balcony_draft/verify.py walks.
local function support(x, z, expect)
	local x0, x1, z0, z1 = x - HALF, x + HALF, z - HALF, z + HALF
	local surfaces = {}
	for nx = floor(x0 + 0.5), floor(x1 + 0.5) do
		for nz = floor(z0 + 0.5), floor(z1 + 0.5) do
			local e = type(expect) == "function" and expect(nx, nz) or expect
			for ny = floor(e) - 2, floor(e) + 4 do
				for _, b in ipairs(shape(name_at(nx, ny, nz)) or {}) do
					if nx + b[1] < x1 and nx + b[4] > x0 and nz + b[3] < z1 and nz + b[6] > z0 then
						surfaces[#surfaces + 1] = {ny + b[2], ny + b[5], e}
					end
				end
			end
		end
	end
	local top
	for _, s in ipairs(surfaces) do
		if s[2] <= s[3] + 0.001 and (not top or s[2] > top) then top = s[2] end
	end
	if not top then return nil end
	for _, s in ipairs(surfaces) do
		if s[2] > top + 0.001 and s[1] < top + CLEAR - 0.001 then return nil, "head" end
	end
	return top
end
-- The draft's walking surface (halls.py flights): half-nodes above the
-- room's floor surface (hall frame y 0.5), the deck beyond u 13.
local function rise(u, v)
	local ru, rv = floor(u + 0.5), floor(v + 0.5)
	if ru >= 2 and ru <= 4 and rv >= 4 and rv <= 11 then return rv - 3 end
	if ru >= 2 and ru <= 4 and rv >= 12 and rv <= 14 then return 8 end
	if ru >= 5 and ru <= 12 and rv >= 12 and rv <= 14 then return ru + 4 end
	return ru >= 13 and 16 or 0
end
local walked = 0
for _, faction in ipairs(FACTIONS) do
	local s = SIGN[faction]
	local function walk(u, v)
		local x, z = s * (42 - u), -s * v
		local top, why = support(x, z, function(nx, nz)
			return 6.5 + rise(42 - s * nx, -s * nz) / 2
		end)
		check(top, ("W %s a body at u %.3f v %.3f stands (%s)"):format(faction, u, v, why or "no floor"))
		check(friendly_at(faction, x, top, z) and friendly_at(faction, x, top + 1.25, z),
			("W %s friendly at u %.3f v %.3f y %.2f and jumping"):format(faction, u, v, top))
		walked = walked + 1
		return top
	end
	-- the lower flight (three lanes), from the room floor to the turn
	for lane = 2, 4 do
		local last
		for i = 0, 80 do
			local h = walk(lane, 3 + i / 8)
			check(not last or h - last == 0 or h - last == 0.5,
				("W %s lower lane %d rises by half nodes"):format(faction, lane))
			last = h
		end
		check(last == 6.5 + 4, "W " .. faction .. " lower lane " .. lane .. " reaches the turn")
	end
	-- the turn and the upper flight (three lanes), to the deck
	for lane = 12, 14 do
		local last
		for i = 0, 112 do
			local h = walk(3 + i / 8, lane)
			check(not last or h - last == 0 or h - last == 0.5,
				("W %s upper lane %d rises by half nodes"):format(faction, lane))
			last = h
		end
		check(last == 6.5 + 8, "W " .. faction .. " upper lane " .. lane .. " reaches the deck")
	end
	-- the whole deck up to the rail (a body reaches over the rail's top
	-- bar from u 18.62 on), then the rail itself up to the barrier's inner face
	-- (u 19.5): a body stands on its top rail (deck + 0.85, a jump) or a
	-- post (deck + 1) along the whole length
	local function across(u)
		for iv = 0, 34 do
			walk(u, math.min(5.8 + iv * 0.25, 14.2))
		end
	end
	for iu = 0, 22 do across(13 + iu * 0.25) end
	for iu = 0, 5 do
		local u = 18.7 + iu * 0.1
		for iv = 0, 34 do
			local v = math.min(5.8 + iv * 0.25, 14.2)
			local x, z = s * (42 - u), -s * v
			local top = support(x, z, 6.5 + 9)
			check(top and top >= 15.35 - 1e-6 and top <= 15.5 + 1e-6, ("W %s a body stands on the " ..
				"rail at u %.1f v %.2f (%s)"):format(faction, u, v, tostring(top)))
			check(friendly_at(faction, x, top, z) and friendly_at(faction, x, top + 1.25, z),
				("W %s friendly on the rail at u %.1f v %.2f and jumping"):format(faction, u, v))
			walked = walked + 1
		end
	end
end
check(walked > 2000, "W the walk sampled (" .. walked .. ")")

-- T -------------------------------------------------------------------------
for _, faction in ipairs(FACTIONS) do
	local nodes, doorways = 0, 0
	local leaks = {}
	for _, b in ipairs(L.HALLS[faction].friendly) do
		for lx = b.min.x, b.max.x do
			for ly = b.min.y, b.max.y do
				for lz = b.min.z, b.max.z do
					check(friendly_at(faction, lx, ly, lz),
						("T %s node %d,%d,%d is friendly"):format(faction, lx, ly, lz))
					nodes = nodes + 1
					for _, o in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
						local nx, ny, nz = lx + o[1], ly + o[2], lz + o[3]
						if not in_boxes(faction, nx, ny, nz) then
							check(contested_at(nx, ny, nz),
								("T %s beyond the box at %d,%d,%d is contested"):format(faction, nx, ny, nz))
							if name_at(nx, ny, nz) == "air" then
								-- an open cell: only the interior's two doorway sills (u 0
								-- and u 12, the floor's two layers above)
								local u = 42 - SIGN[faction] * nx
								if (u == 0 or u == 12) and ny >= 7 and ny <= 13 and b == L.HALLS[faction].interior then
									doorways = doorways + 1
								else
									leaks[#leaks + 1] = nx .. "," .. ny .. "," .. nz
								end
							end
						end
					end
				end
			end
		end
	end
	check(#leaks == 0, "T " .. faction .. ": the friendly air is closed but for the doorways: " ..
		table.concat(leaks, " ", 1, math.min(#leaks, 8)))
	check(doorways > 0, "T " .. faction .. " has its doorways (" .. doorways .. ")")
	check(nodes == 11 * 7 * 29 + 8 * 5 * 3 + 7 * 4 * 9, "T " .. faction .. " node count " .. nodes)
	-- both roofs' landing patches (the draft: u 3..7 v -2..2 on the hall's
	-- roof at y 8, u 14..18 v 7..11 on the balcony's roof at y 13): solid,
	-- open sky above, contested where a body stands
	for _, p in ipairs({{3, -2, 8}, {14, 7, 13}}) do
		for u = p[1], p[1] + 4 do
			for v = p[2], p[2] + 4 do
				local lx, ly, lz = local_of(faction, u, p[3], v)
				check(name_at(lx, ly, lz) ~= "air", "T " .. faction .. " a roof landing is solid")
				for y = p[3] + 1, 18 do
					check(hall_name(faction, u, y, v) == "air", "T " .. faction .. " open sky over a landing")
				end
				check(contested_at(lx, ly + 0.5, lz) and contested_at(lx, ly + 1.75, lz),
					"T " .. faction .. " a roof landing is contested")
			end
		end
	end
	-- every roof top of the hall and the stair hood (u 0..12), the balcony's
	-- roof (u 13..20), contested where a body stands on it
	for u = 0, 20 do
		for v = -15, 15 do
			local top
			for y = 18, 0, -1 do
				if hall_name(faction, u, y, v) ~= "air" then top = y break end
			end
			local lx, ly, lz = local_of(faction, u, top, v)
			check(contested_at(lx, ly + 0.5, lz), ("T %s the roof top at u %d v %d is contested"):format(
				faction, u, v))
		end
	end
	-- the barrier, its outer side (u 21, beyond the box) and the air in
	-- front, the gate court under the balcony (u 12..20, y 1..5)
	for v = 6, 14 do
		for y = 8, 12 do
			check(contested_at(local_of(faction, 20, y, v)) and contested_at(local_of(faction, 21, y, v)) and
				contested_at(local_of(faction, 23, y, v)), "T " .. faction .. " the barrier and beyond")
		end
	end
	for u = 12, 20 do
		for v = -15, 15 do
			for y = 1, 5 do
				check(contested_at(local_of(faction, u, y, v)), "T " .. faction .. " the gate court")
			end
		end
	end
end

-- N -------------------------------------------------------------------------
do
	local registered, rays = {}, {}
	-- a recording engine: every other function returns a table, every
	-- registered node (the camp art reads some) is an empty definition
	local stub = setmetatable({}, {__index = function() return function() return {} end end})
	local engine = setmetatable({
		register_node = function(name, def) registered[name] = def end,
		raycast = function(a, b, objects, liquids, pointabilities)
			rays[#rays + 1] = {a, b, objects, liquids, pointabilities}
			return "ray"
		end,
		registered_nodes = setmetatable({}, {__index = function() return {} end}),
	}, {__index = getmetatable(stub).__index})
	local saved = _G.default
	_G.default = stub
	dofile(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")(engine,
		repo .. "/mods/MAPGEN/grug_mapgen", stub, stub)
	_G.default = saved
	local d = registered[BARRIER]
	check(d and d.drawtype == "airlike" and d.walkable == true and d.pointable == "blocking" and
		d.paramtype == "light" and d.sunlight_propagates == true and d.diggable == false and
		d.buildable_to == false and d.floodable == false and d.drop == "" and
		d.is_ground_content == false and not (d.groups or {}).grug_air and d.node_box == nil and
		d.collision_box == nil and d.selection_box == nil, "N the barrier's definition")
	check(engine.raycast({x = 0}, {x = 1}, true, false) == "ray" and rays[1][3] == true and
		rays[1][4] == false and rays[1][5].nodes[BARRIER] == true,
		"N a server ray without pointabilities points the barrier")
	local own = {nodes = {}}
	engine.raycast({x = 0}, {x = 1}, false, true, own)
	check(rays[2][5] == own and rays[2][3] == false and rays[2][4] == true,
		"N a ray with its own pointabilities keeps them")
	engine.raycast({x = 0}, {x = 1})
	check(rays[3][3] == nil and rays[3][4] == nil and rays[3][5].nodes[BARRIER] == true,
		"N the defaults pass on unchanged")
end

print("R89 HALLS PORTABLE PASS checks=" .. checks)
