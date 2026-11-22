-- Round 85 lane BUILD portable test (LuaJIT): the arena "Breach Road"'s
-- blocks (`wp40/breach_model.lua`, `breach_field.lua`, `breach_writer.lua`,
-- the hall templates, the envelope box, the hearth smoke).
--
--   luajit tools/r85_build/portable_test.lua [REPO]
--
-- (That the field data equals its generator's output, and the generator the
-- approved draft's own construction, is `python3 tools/r85_build/gen_field.py
-- --check`; it needs Python and PIL, so it is not run from here.)
-- M  the model: every footprint column and only those, both halls placed on
--    the layout's waystone, arrival and muster cells, the game's waystone on
--    the waystone cell (free above, the arrival beside it free two high),
--    the twelve flights (180 stair nodes), the hearths open to the sky, the
--    height; nothing floating (every block reaches the datum through blocks,
--    with either dressing variant).
-- W  the writer on a fake world: only the model's cells inside the
--    footprint, from the datum up to the envelope's top; the rim's natural
--    surface kept, plants and leaves above the field cleared; the roles and
--    the dressing by each column's own biome (the draft's woodland west and
--    badlands east reproduce its west/east ground); the same nodes whether
--    the arena is written in one piece, in 80^3 chunks or in those chunks in
--    reverse order (a hall across a chunk border, datum near a chunk top).
-- E  the envelope: preparation_source's fitted box covers the arena, so
--    air_chunks never skips a chunk the halls reach.
-- P  the hearth smoke: the effect keeps the draft's budget of 22 live puffs
--    for the pair, one 1 s spawner per hearth every second, at the layout's
--    hearths.
-- Prints "R85 BUILD PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local L = dofile(wp40 .. "/breach_layout.lua")
local B = dofile(wp40 .. "/breach_model.lua")
local model = B.new(wp40)

-- M -------------------------------------------------------------------------
local name_of, TOUCH = {}, nil
for index, e in ipairs(model.entries) do name_of[index] = e.name or ("@" .. e.role) end
local function cell(lx, ly, lz)
	local c = model.column(lx, lz)
	return c and c.cells[ly + 1]
end
do
	local footprint = 0
	for lz = -L.HALF_Z, L.HALF_Z do
		for lx = -L.HALF_X, L.HALF_X do
			if L.inside(lx, lz) then
				footprint = footprint + 1
				check(model.column(lx, lz) ~= nil, "M every footprint column has cells")
			end
		end
	end
	check(footprint == 6907 and #model.columns == footprint, "M the footprint's 6,907 columns")
	local stairs, keep = 0, 0
	for _, c in ipairs(model.columns) do
		check(c.cells[1] ~= nil and c.cells[1] ~= B.AIR, "M every column holds its datum cell")
		for _, v in pairs(c.cells) do
			if v > 0 and name_of[v] == "stairs:stair_sandstonebrick" then stairs = stairs + 1 end
		end
		if c.cells[1] == B.KEEP then keep = keep + 1 end
	end
	check(stairs == 180, "M twelve flights of 15 stair nodes (" .. stairs .. ")")
	check(keep > 800 and keep < 1300, "M the rim keeps the natural surface (" .. keep .. ")")
	for faction, hall in pairs(L.HALLS) do
		local w = hall.waystone
		check(name_of[cell(w.x, w.y, w.z)] == "grug_mapgen:waystone" and
			cell(w.x, w.y + 1, w.z) == B.AIR and cell(w.x, w.y + 2, w.z) == B.AIR and
			cell(w.x, w.y - 1, w.z) > 0, "M the " .. faction .. " waystone on the layout's cell, " ..
			"on the floor, free above")
		for _, p in ipairs({hall.arrival, hall.muster}) do
			check(cell(p.x, p.y, p.z) == B.AIR and cell(p.x, p.y + 1, p.z) == B.AIR and
				cell(p.x, p.y - 1, p.z) > 0, "M the " .. faction .. " arrival and muster stand free")
		end
		local box = hall.interior
		local open = 0
		for lx = box.min.x, box.max.x do
			for lz = box.min.z, box.max.z do
				if cell(lx, box.min.y, lz) == B.AIR then open = open + 1 end
				check(cell(lx, hall.floor_y, lz) > 0, "M the " .. faction .. " hall has a floor")
			end
		end
		check(open > 200, "M the " .. faction .. " hall's interior is open (" .. open .. ")")
	end
	for _, h in ipairs(L.HEARTHS) do
		check(name_of[cell(h.x, h.y, h.z)] == "grug_decor:darkage_basalt_brick", "M hearth stone")
		for ly = h.y + 1, h.y + 12 do
			local v = cell(h.x, ly, h.z)
			check(v == nil or v == B.AIR, "M the smoke rises free above the " .. h.id .. " hearth")
		end
	end
	check(model.TOP == 24 and model.REACH == 28, "M the arena's height (datum + 24, clear 4)")
	check(model.REACH <= L.BOX_ABOVE, "M the protected box covers every cell the arena writes")
	check(model.halls.accord.solids > 2000 and model.halls.throng.solids > 2000, "M two halls")
	-- nothing floating: every block reaches the datum's ground (y 0, or the
	-- natural ground under it) through blocks that share a face or an edge
	-- (the Throng crowns' cross-braces are diagonal runs of logs)
	TOUCH = {}
	for dx = -1, 1 do
		for dy = -1, 1 do
			for dz = -1, 1 do
				local n = math.abs(dx) + math.abs(dy) + math.abs(dz)
				if n == 1 or n == 2 then TOUCH[#TOUCH + 1] = {dx, dy, dz} end
			end
		end
	end
	for _, variant in ipairs({"trunk", "rock"}) do
		local solid = {}
		local function key(x, y, z) return x .. "," .. y .. "," .. z end
		for _, c in ipairs(model.columns) do
			for i, v in pairs(c.cells) do
				if v > 0 or v == B.KEEP then solid[key(c.lx, i - 1, c.lz)] = true end
			end
		end
		for _, g in ipairs(model.dressing) do
			for _, d in ipairs(g.cells[variant]) do solid[key(d.x, d.y, d.z)] = true end
		end
		local queue, seen, head = {}, {}, 1
		for k in pairs(solid) do
			local x, y, z = k:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
			if tonumber(y) == 0 then queue[#queue + 1] = {tonumber(x), 0, tonumber(z)}; seen[k] = true end
		end
		while queue[head] do
			local p = queue[head]
			head = head + 1
			for _, o in ipairs(TOUCH) do
				local k = key(p[1] + o[1], p[2] + o[2], p[3] + o[3])
				if solid[k] and not seen[k] then
					seen[k] = true
					queue[#queue + 1] = {p[1] + o[1], p[2] + o[2], p[3] + o[3]}
				end
			end
		end
		local floating = {}
		for k in pairs(solid) do if not seen[k] then floating[#floating + 1] = k end end
		table.sort(floating)
		check(#floating == 0, "M nothing floats (" .. variant .. "): " ..
			table.concat(floating, " ", 1, math.min(8, #floating)))
	end
end

-- W -------------------------------------------------------------------------
-- A fake engine: content ids for every name, a world of stone below the
-- datum, grass at it, air above, a leaf over the rim and one in a hall.
local cids, names = {air = 0}, {[0] = "air"}
local core_api = {registered_nodes = setmetatable({}, {__index = function(_, name)
	if type(name) == "string" and name:find(":", 1, true) then return {} end
end}), CONTENT_AIR = 0}
function core_api.get_content_id(name)
	if not cids[name] then
		names[#names + 1] = name
		cids[name] = #names
	end
	return cids[name]
end
local STONE, GRASS, LEAF = core_api.get_content_id("default:stone"),
	core_api.get_content_id("default:dirt_with_grass"), core_api.get_content_id("default:leaves")
local site = {x = -72, z = 8, y = 30, reach = 29}
local function natural(x, y, z)
	if y < site.y then return STONE elseif y == site.y then return GRASS end
	if (x == site.x - 46 and z == site.z - 16 and y == site.y + 2) or
			(x == site.x + 30 and z == site.z and y == site.y + 10) then
		return LEAF
	end
	return 0
end
-- the draft's ground: woodland west of the road, badlands east
local function biome_at(x) return x < site.x and "grug_deep_forest" or "grug_badlands" end
local writer = dofile(wp40 .. "/breach_writer.lua")(core_api, {breach = site}, B, model)
check(dofile(wp40 .. "/breach_writer.lua")(core_api, {}, B, model).dress({}) == 0,
	"W a world without a site writes nothing")
local function run(boxes)
	local world = {}
	local function key(x, y, z) return x .. "," .. y .. "," .. z end
	for _, b in ipairs(boxes) do
		local context = {min_x = b[1], min_y = b[2], min_z = b[3],
			max_x = b[1] + b[4] - 1, max_y = b[2] + b[4] - 1, max_z = b[3] + b[4] - 1}
		function context.settled_at(x, y, z)
			local v = world[key(x, y, z)]
			if v then return v[1], v[2] end
			return natural(x, y, z), 0
		end
		function context.column_values_at(x, z)
			return "land", nil, nil, biome_at(x), nil, site.y, nil
		end
		function context.write_road(x, y, z, cid, param2)
			assert(x >= context.min_x and x <= context.max_x and y >= context.min_y and
				y <= context.max_y and z >= context.min_z and z <= context.max_z, "write escaped")
			world[key(x, y, z)] = {cid, param2}
		end
		writer.dress(context)
	end
	return world
end
local function origin(v) return (math.floor((math.floor(v / 16) + 2) / 5) * 5 - 2) * 16 end
local whole = run({{site.x - 60, site.y - 5, site.z - 60, 120}})
local chunks = {}
for oz = origin(site.z - 50), origin(site.z + 50), 80 do
	for oy = origin(site.y - 2), origin(site.y + 40), 80 do
		for ox = origin(site.x - 50), origin(site.x + 50), 80 do chunks[#chunks + 1] = {ox, oy, oz, 80} end
	end
end
check(#chunks >= 8, "W the arena spans chunks in x, y and z (" .. #chunks .. ")")
local reversed = {}
for index = #chunks, 1, -1 do reversed[#reversed + 1] = chunks[index] end
local function same(a, b)
	for k, v in pairs(a) do
		local w = b[k]
		if not w or w[1] ~= v[1] or w[2] ~= v[2] then return false, k end
	end
	for k in pairs(b) do if not a[k] then return false, k end end
	return true
end
local ok, where = same(whole, run(chunks))
check(ok, "W the same nodes in one piece and in chunks " .. tostring(where))
ok, where = same(whole, run(reversed))
check(ok, "W the same nodes in reverse chunk order " .. tostring(where))
do
	local written, roles = 0, {}
	local west, east = B.FAMILIES.woodland, B.FAMILIES.badland
	check(west.accent == "grug_nodes:dirt_with_forest_litter" and west.base == "default:dirt" and
		east.accent == "grug_nodes:mesa_clay" and east.base == "default:dry_dirt" and
		east.path == "default:dry_dirt" and west.dress == "trunk" and east.dress == "rock",
		"W the woodland and badland families are the draft's west and east")
	for k, v in pairs(whole) do
		local x, y, z = k:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		local lx, ly, lz = x - site.x, y - site.y, z - site.z
		written = written + 1
		check(L.inside(lx, lz) and ly >= 0 and ly <= model.REACH, "W writes stay in the footprint")
		local value = cell(lx, ly, lz)
		if value == nil or value == B.AIR then
			local dressed = false
			for _, g in ipairs(model.dressing) do
				for _, d in ipairs(g.cells[lx < 0 and "trunk" or "rock"]) do
					if d.x == lx and d.y == ly and d.z == lz then dressed = true end
				end
			end
			check(v[1] == 0 or dressed, "W only air above and between the cells")
		elseif value ~= B.KEEP then
			local e = model.entries[value]
			if e.role then
				local want = cids[(lx < 0 and west or east)[e.role]]
				check(v[1] == want, "W a role takes its column's biome family")
				roles[e.role .. (lx < 0 and "W" or "E")] = true
			else
				check(v[1] == cids[e.name] and v[2] == e.param2, "W a fixed cell as the model says")
			end
		end
	end
	check(roles.accentW and roles.accentE and roles.baseW and roles.baseE and roles.pathW and
		roles.pathE, "W both families' accents, bases and paths appear")
	check(written > 29000, "W the arena is written (" .. written .. " cells)")
	-- the rim keeps the natural surface; the leaf above it is cleared
	local rim
	for _, c in ipairs(model.columns) do
		if c.cells[1] == B.KEEP and c.lx == -46 and c.lz == -16 then rim = c end
	end
	check(rim and whole[(site.x - 46) .. "," .. site.y .. "," .. (site.z - 16)] == nil,
		"W a rim column keeps its natural surface")
	check(whole[(site.x - 46) .. "," .. (site.y + 2) .. "," .. (site.z - 16)][1] == 0,
		"W the leaf over the rim is cleared")
	check(whole[(site.x + 30) .. "," .. (site.y + 10) .. "," .. site.z] ~= nil and
		whole[(site.x + 30) .. "," .. (site.y + 10) .. "," .. site.z][1] ~= LEAF,
		"W the hall's cells replace what stood there")
	-- the dressing: trunks on the woodland, basalt on the badlands
	local trunk, basalt = cids["default:tree"], cids["grug_materials:basalt"]
	for _, g in ipairs(model.dressing) do
		local v = whole[(site.x + g.x) .. "," .. (site.y + 2) .. "," .. (site.z + g.z)]
		check(v and v[1] == (g.x < 0 and trunk or basalt), "W the dressing follows the biome")
		local top = whole[(site.x + g.x) .. "," .. (site.y + 4) .. "," .. (site.z + g.z)]
		check(g.x < 0 and top and top[1] == trunk or g.x > 0 and (top == nil or top[1] == 0),
			"W a trunk stands 4, the basalt 2")
	end
end

-- E -------------------------------------------------------------------------
do
	local box = model.box(site)
	check(box.y_min == site.y and box.y_max == site.y + 28 and box.x_min == site.x - 49 and
		box.z_max == site.z + 45, "E the arena's box")
	local columns = {column_values_at = function() return "land", nil, nil, "grug_meadows", nil, 5 end}
	local templates = {{rotations = {{min_x = -1, min_y = 0, min_z = -1, max_x = 1, max_y = 3, max_z = 1}}}}
	local anchors = {copy_rows = function() return {} end}
	local function sha(text) return ("%08x"):format(#text) end
	local plain = dofile(wp40 .. "/preparation_source.lua")(columns, templates, {}, {}, anchors,
		"t", sha)
	local bounds = dofile(wp40 .. "/preparation_source.lua")(columns, templates, {}, {}, anchors,
		"t", sha, {box})
	check(plain.identity ~= bounds.identity, "E the box enters the envelope's identity")
	local lo = {x = origin(site.x), y = origin(site.y + 28), z = origin(site.z)}
	local hi = {x = lo.x + 79, y = lo.y + 79, z = lo.z + 79}
	local _, _, top = bounds.tile_bounds(lo, hi)
	check(top == site.y + 28, "E the chunk over the arena sees its top")
	local air = dofile(wp40 .. "/air_chunks.lua")(bounds, 1)
	local air_plain = dofile(wp40 .. "/air_chunks.lua")(plain, 1)
	local function heightmap() local h = {} for i = 1, 6400 do h[i] = -31007 end return h end
	-- the datum 30 sits in the chunk -32..47; its halls reach 58 in 48..127
	check(lo.y == 48 and air_plain.untouched(lo, hi, heightmap) and
		not air.untouched(lo, hi, heightmap), "E air_chunks runs the chunk the halls reach")
end

-- P -------------------------------------------------------------------------
do
	local registered = {}
	_G.grug_core = {particles = {register = function(id, emitters) registered[id] = emitters end}}
	dofile(repo .. "/mods/CORE/grug_core/particle_effects.lua")
	_G.grug_core = nil
	local smoke = registered.breach_hearth_smoke
	check(type(smoke) == "table" and #smoke == 1 and smoke[1].kind == "spawner" and
		smoke[1].time == 1, "P one 1 s spawner per hearth")
	local live = 0
	for _, e in ipairs(smoke) do live = live + e.n / e.time * e.exp[2] end
	check(live * #L.HEARTHS <= 22, "P at most 22 live puffs for the pair (" .. live * 2 .. ")")
	local timers, played = {}, {}
	local fake = {after = function(seconds, fn) timers[#timers + 1] = {seconds, fn} end}
	local particles = {play = function(id, frame) played[#played + 1] = {id, frame} end}
	local world = L.world(site)
	check(dofile(repo .. "/mods/MAPGEN/grug_mapgen/breach_smoke.lua")(fake, particles, world) == 2,
		"P two hearths")
	check(#timers == 1 and timers[1][1] == 1, "P a one-second timer")
	timers[1][2]()
	check(#played == 2 and played[1][1] == "breach_hearth_smoke" and #timers == 2,
		"P each second one effect per hearth, then the next second")
	for index, h in ipairs(world.hearths) do
		local c = played[index][2].caster
		check(c.x == h.x and c.z == h.z and c.y == site.y + 0.75, "P the puffs rise at the hearth")
	end
end

print("R85 BUILD PORTABLE PASS checks=" .. checks)
