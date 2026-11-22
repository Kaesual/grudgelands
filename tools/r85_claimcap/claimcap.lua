-- Round 85 CLAIMCAP (read-only study): how many housing claims fit, as today's
-- 101 x 101 squares and as whole 80 x 80 map chunks. One seed per run, on the
-- seed fleet's runtime (tools/seed_fleet/runtime.lua: the real mapgen planner
-- under LuaJIT, no engine, no generated map blocks). Nothing shipped changes.
--
--   luajit tools/r85_claimcap/claimcap.lua <repo> <seed> <outdir> [probes]
--
-- The claim rule is the game's own as of 0.84.1: grug_housing/registry.lua
-- (frozen in registry_084.lua since Round 85 CORE moved the game to the map
-- chunk and the claim mask) is loaded with a
-- stub storage and its column_problem (the per-column zone, water and
-- territory rule validate's scan applies) judges every column at step 1; its
-- validate runs on `probes` random centres per faction (default 300) with the
-- same world adapter api.lua gives it, here built from the runtime's zone
-- session and a world protection index built exactly as r7_loader.lua builds
-- it. The spawn regions are spawn_regions_core.lua's build on the same
-- session (as tools/seed_fleet/seed.lua does).
--
-- Writes into <outdir>:
--   meta.tsv            seed, timings, raster frames per faction
--   zones.tsv           every zone record and its role for each faction
--   anchors.tsv         every source anchor with its fitted position
--   settlements.tsv     every settlement (key, label, slot, zone, anchor)
--   boxes.tsv           the settlement cores of the world protection
--   roads.tsv           every road corridor point (id, half width, x, z)
--   raster_<f>.bin      step-1 layers over the faction's frame, each W*H
--                       bytes, row-major in z then x: zone numeric id (255:
--                       not computed), water class code, the faction's
--                       column_problem code, territory code (4: a town
--                       column, 7: a landmark column, both hard_protected)
--   height_<f>.bin      step-4 terrain height (int16 LE, -32768 not computed),
--                       sample (x0 + 4i + 2, z0 + 4j + 2)
--   chunks_<f>.tsv      every computed chunk: cx, cz, core (1) or ring (0),
--                       and the exact feature_in answer for margins 16, 8, 0
--   validate_<f>.tsv    probe centres: x, z, validate's answer and code
--   cells.tsv, leaders.tsv, places.tsv, camps.tsv   the spawn regions of the
--                       claim, capital and contested 31-40 zones
--   rares.tsv           the named rares' route points
local repo, seed, out, probes = arg[1], arg[2], arg[3], tonumber(arg[4] or 300)
assert(repo and seed and out, "usage: claimcap.lua <repo> <seed> <outdir> [probes]")
arg = {repo}
local floor = math.floor

local t0 = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local t_build = os.clock() - t0
local Z = R.built.zones_session
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local SOURCE = dofile(wp40 .. "/source/simple_map.lua")
local B = SOURCE.world_bounds

local function open(name)
	return assert(io.open(out .. "/" .. name, "wb"))
end

-- The world protection, as r7_loader.lua builds it (settlement cores from the
-- prepared blueprints' cell bounds, every road of the layout text).
local wp = dofile(wp40 .. "/world_protection.lua")
local socket_rows = R.main.settlement_sockets(R.built)
local prepared = R.main.prepared_handover()
local box_rows = {}
for _, row in ipairs(socket_rows) do
	if row.slot ~= "start" and row.slot ~= "capital" then
		local p = prepared[row.key]
		assert(type(p) == "table" and type(p.bounds) == "table", "bounds " .. row.key)
		box_rows[#box_rows + 1] = {key = row.key, slot = row.slot, anchor = row.anchor,
			bounds = p.bounds}
	end
end
local corridors = wp.road_corridors(R.main.road_module(), R.main.road_layout_text())
local boxes = wp.settlement_boxes(box_rows)
local WP = wp.new(dofile(wp40 .. "/index128.lua"), {corridors = corridors, boxes = boxes})

-- grug_housing's placement world (api.lua), on this session.
local zone_records = {}
local world = {fixed = false}
function world.water_class_at(x, z) return Z.water_class_at(x, z) end
function world.zone_at(x, z)
	local id = Z.id_at(x, z)
	if not id then return nil end
	local r = zone_records[id]
	if not r then r = Z.get(id); zone_records[id] = r end
	return r
end
function world.territory_at(x, z) return Z.territory_rule_at({x = x, y = 30000, z = z}) end
function world.feature_in(min_x, min_z, max_x, max_z, margin)
	if WP.boxes_in(min_x, min_z, max_x, max_z, margin) then return "site" end
	local _, kind = Z.hard_footprint_in(min_x - margin, min_z - margin, max_x + margin,
		max_z + margin)
	return kind
end
function world.cube_clear() return true end

local store = {}
local HM = dofile(repo .. "/tools/r85_claimcap/registry_084.lua")({
	storage = {get_string = function(k) return store[k] or "" end,
		set_string = function(k, v) store[k] = v ~= "" and v or nil end,
		keys = function() local t = {} for k in pairs(store) do t[#t + 1] = k end return t end},
	now = function() return 1000000 end})

-- Codes.
local PCODE = {shelf = 1, sea = 2, enemy = 3, low_level = 4, high_level = 5,
	capital_zone = 6, not_home = 7, town = 8, deep_water = 9}
local WCODE = {land = 1, planned_water = 2, coastal_shelf = 3, deep_ocean = 4,
	immutable_dragon_channel = 5}
local TCODE = {accord_home = 1, throng_home = 2, contested_land = 3, hard_protected = 4,
	immutable = 5}

-- Zones and their role per faction: "claim" (eligible today), "contested"
-- (a level 31-40 zone of the faction's own continent, the relaxed variants),
-- "capital" (the faction's capital zones, the follow-up variants).
local CONTINENT = {accord = "elandor_mainland", throng = "kragmar_mainland"}
local FACTIONS = {"accord", "throng"}
local role = {accord = {}, throng = {}}
local f = open("zones.tsv")
for _, zr in ipairs(SOURCE.zones) do
	local rec = Z.get(zr.id)
	local roles = {}
	for _, fac in ipairs(FACTIONS) do
		local r = "-"
		local problem = HM.column_problem(fac, "land", rec, false)
		if problem == nil then
			r = "claim"
		elseif problem == "capital_zone" then
			r = "capital"
		elseif rec.level_min == 31 and rec.level_max == 40 and zr.macro_region == CONTINENT[fac] then
			r = "contested"
		end
		role[fac][zr.numeric_id] = r ~= "-" and r or nil
		roles[#roles + 1] = r
	end
	f:write(table.concat({zr.numeric_id, zr.id, zr.display_name, tostring(rec.faction),
		rec.territory_rule, rec.level_min, rec.level_max, tostring(rec.civic_no_hostiles),
		zr.macro_region, roles[1], roles[2]}, "\t"), "\n")
end
f:close()
local zindex = {}
for _, zr in ipairs(SOURCE.zones) do zindex[zr.id] = zr.numeric_id end

-- Anchors, settlements, boxes, roads.
local profile = {}
for _, p in ipairs(SOURCE.anchor_profiles) do profile[p.id] = p end
f = open("anchors.tsv")
for _, a in ipairs(SOURCE.anchors) do
	local zr = SOURCE.zones[a.zone_numeric_id]
	local w = Z.anchor(zr.id, a.slot_id)
	f:write(table.concat({a.id, a.zone_numeric_id, zr.id, a.slot_id, a.template_id,
		a.placement_mode, w and w.x or "nil", w and w.z or "nil", w and w.y or "nil"}, "\t"), "\n")
end
f:close()
f = open("settlements.tsv")
for _, row in ipairs(socket_rows) do
	f:write(table.concat({row.key, tostring(row.label), row.slot, row.zone_id,
		zindex[row.zone_id] or 0, row.anchor.x, row.anchor.z}, "\t"), "\n")
end
f:close()
f = open("boxes.tsv")
for _, b in ipairs(boxes) do
	f:write(table.concat({b.id, b.kind, b.min_x, b.max_x, b.min_z, b.max_z}, "\t"), "\n")
end
f:close()
f = open("roads.tsv")
for _, c in ipairs(corridors) do
	for i = 1, #c.X do
		f:write(c.id, "\t", c.half_width + c.side, "\t", ("%.3f"):format(c.X[i]), "\t",
			("%.3f"):format(c.Z[i]), "\n")
	end
end
f:close()

-- The chunk grid (chunksize 5): column cx covers x 80 cx - 32 .. 80 cx + 47.
local function chunk_of(v) return floor((floor(v / 16) + 2) / 5) end
local function chunk_min(c) return 80 * c - 32 end
local CX0, CX1 = chunk_of(B.min_x), chunk_of(B.max_x)
local CZ0, CZ1 = chunk_of(B.min_z), chunk_of(B.max_z)

-- Coarse pass: the zone of a 10 x 10 sample grid per chunk (8-node pitch).
local t1 = os.clock()
local relevant = {accord = {}, throng = {}}
for cz = CZ0, CZ1 do
	for cx = CX0, CX1 do
		local seen = {}
		for a = 0, 9 do
			for b = 0, 9 do
				local x, z = chunk_min(cx) + 4 + 8 * a, chunk_min(cz) + 4 + 8 * b
				if x >= B.min_x and x <= B.max_x and z >= B.min_z and z <= B.max_z then
					local id = Z.id_at(x, z)
					if id then seen[zindex[id]] = true end
				end
			end
		end
		for _, fac in ipairs(FACTIONS) do
			for n in pairs(seen) do
				if role[fac][n] then relevant[fac][cx .. "," .. cz] = true break end
			end
		end
	end
end
local t_coarse = os.clock() - t1

local meta = open("meta.tsv")
meta:write("seed\t", seed, "\nbuild_s\t", ("%.1f"):format(t_build), "\ncoarse_s\t",
	("%.1f"):format(t_coarse), "\n")

local RING = 2
for _, fac in ipairs(FACTIONS) do
	t1 = os.clock()
	-- core chunks and a ring of RING chunks round them
	local set, core = {}, relevant[fac]
	local minx, maxx, minz, maxz = math.huge, -math.huge, math.huge, -math.huge
	for key in pairs(core) do
		local cx, cz = key:match("^(-?%d+),(-?%d+)$")
		cx, cz = tonumber(cx), tonumber(cz)
		for dz = -RING, RING do
			for dx = -RING, RING do
				local k = (cx + dx) .. "," .. (cz + dz)
				set[k] = true
				minx, maxx = math.min(minx, cx + dx), math.max(maxx, cx + dx)
				minz, maxz = math.min(minz, cz + dz), math.max(maxz, cz + dz)
			end
		end
	end
	local x0, z0 = chunk_min(minx), chunk_min(minz)
	local W, H = 80 * (maxx - minx + 1), 80 * (maxz - minz + 1)
	local layers = {zid = {}, wc = {}, pa = {}, terr = {}}
	local hrows = {}
	local list = {}
	for key in pairs(set) do list[#list + 1] = key end
	table.sort(list)
	local computed = {}
	for _, key in ipairs(list) do computed[key] = true end
	local cf = open("chunks_" .. fac .. ".tsv")
	for _, key in ipairs(list) do
		local cx, cz = key:match("^(-?%d+),(-?%d+)$")
		cx, cz = tonumber(cx), tonumber(cz)
		local ax, az = chunk_min(cx), chunk_min(cz)
		local function fi(m)
			return world.feature_in(ax, az, ax + 79, az + 79, m) or "-"
		end
		cf:write(table.concat({cx, cz, core[key] and 1 or 0, fi(16), fi(8), fi(0)}, "\t"), "\n")
	end
	cf:close()
	-- rows of bytes, one string per z row
	local zid_rows, wc_rows, pa_rows, terr_rows = {}, {}, {}, {}
	local char = string.char
	for row = 0, H - 1 do
		local z = z0 + row
		local cz = chunk_of(z)
		local bz, bw, bp, bt = {}, {}, {}, {}
		for col = 0, W - 1 do
			local x = x0 + col
			local n = col + 1
			if computed[chunk_of(x) .. "," .. cz] and x >= B.min_x and x <= B.max_x and
					z >= B.min_z and z <= B.max_z then
				local water = Z.water_class_at(x, z)
				local zone = world.zone_at(x, z)
				local territory = zone and Z.territory_rule_at({x = x, y = 30000, z = z}) or nil
				local problem = HM.column_problem(fac, water, zone, territory)
				bz[n] = zone and zone.numeric_id or 0
				bw[n] = WCODE[water] or 6
				bp[n] = problem and (PCODE[problem] or 10) or 0
				bt[n] = territory and (TCODE[territory] or 6) or 0
				if bt[n] == 4 and Z.hard_protection_kind_at({x = x, y = 30000, z = z}) == "landmark" then
					bt[n] = 7
				end
			else
				bz[n], bw[n], bp[n], bt[n] = 255, 0, 255, 0
			end
		end
		local function pack(t)
			local parts = {}
			for s = 1, W, 4000 do
				parts[#parts + 1] = char(unpack(t, s, math.min(W, s + 3999)))
			end
			return table.concat(parts)
		end
		zid_rows[row + 1], wc_rows[row + 1] = pack(bz), pack(bw)
		pa_rows[row + 1], terr_rows[row + 1] = pack(bp), pack(bt)
	end
	local rf = open("raster_" .. fac .. ".bin")
	rf:write(table.concat(zid_rows)) zid_rows = nil
	rf:write(table.concat(wc_rows)) wc_rows = nil
	rf:write(table.concat(pa_rows)) pa_rows = nil
	rf:write(table.concat(terr_rows)) terr_rows = nil
	rf:close()
	collectgarbage()
	-- heights, step 4
	local hf = open("height_" .. fac .. ".bin")
	for j = 0, H / 4 - 1 do
		local z = z0 + 4 * j + 2
		local buf = {}
		for i = 0, W / 4 - 1 do
			local x = x0 + 4 * i + 2
			local v = -32768
			if computed[chunk_of(x) .. "," .. chunk_of(z)] and x >= B.min_x and x <= B.max_x and
					z >= B.min_z and z <= B.max_z then
				local h = Z.terrain_height_at(x, z)
				if h then v = floor(h + 0.5) end
			end
			if v < 0 then v = v + 65536 end
			buf[#buf + 1] = char(v % 256, floor(v / 256))
		end
		hf:write(table.concat(buf))
	end
	hf:close()
	local t_raster = os.clock() - t1
	-- validate on random probe centres in the faction's claim zones
	t1 = os.clock()
	local vf = open("validate_" .. fac .. ".tsv")
	local rng = 12345
	local function rand(n)
		rng = (rng * 1103515245 + 12345) % 2147483648
		return rng % n
	end
	local done, tries = 0, 0
	while done < probes and tries < probes * 200 do
		tries = tries + 1
		local x, z = x0 + rand(W), z0 + rand(H)
		local zone = world.zone_at(x, z)
		if zone and role[fac][zone.numeric_id] == "claim" then
			local ok, code = HM.validate("probe", fac, {x = x, y = 10, z = z}, world)
			vf:write(x, "\t", z, "\t", ok and 1 or 0, "\t", tostring(code or "-"), "\n")
			done = done + 1
		end
	end
	vf:close()
	local t_validate = os.clock() - t1
	meta:write("frame_", fac, "\t", x0, "\t", z0, "\t", W, "\t", H, "\n")
	meta:write("raster_s_", fac, "\t", ("%.1f"):format(t_raster), "\nvalidate_s_", fac, "\t",
		("%.1f"):format(t_validate), "\n")
	print(fac, "chunks", #list, "frame", x0, z0, W, H, ("raster %.1f s, validate %.1f s"):format(
		t_raster, t_validate))
end

-- Spawn regions of every claim, capital and contested zone (spawn_regions_core.lua,
-- the query adapter of tools/seed_fleet/seed.lua).
t1 = os.clock()
do
	local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local function read(path)
		local h = assert(io.open(path, "rb"))
		local text = h:read("*a")
		h:close()
		return text
	end
	local catalogue = {}
	do
		local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
		for _, row in ipairs(data[1] and data or data.subtypes) do catalogue[row.role] = row end
	end
	local labels = {}
	for _, row in ipairs(dofile(wp40 .. "/r7_settlement.lua").roster) do
		if row.anchor_id then labels[row.anchor_id] = row.label end
	end
	local q = core.queries({zones = Z, column_values_at = R.planner_source.column_values_at,
		road_polylines = R.main.road_polylines(), source = SOURCE})
	local fc, fl, fp, fk = open("cells.tsv"), open("leaders.tsv"), open("places.tsv"),
		open("camps.tsv")
	for _, zr in ipairs(SOURCE.zones) do
		if role.accord[zr.numeric_id] or role.throng[zr.numeric_id] then
			local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zr.id ..
				".spawns.json"))
			local record = Z.get(zr.id)
			local recipe = core.parse_recipe(zr.id, data.recipe, {
				band = {record.level_min, record.level_max},
				role_levels = function(r) return catalogue[r] and catalogue[r].levels end,
				leader = function(r) return catalogue[r] ~= nil and catalogue[r].leader == true end,
				pois = function(id) return core.zone_pois(SOURCE, id, labels) end,
			})
			local map = core.build(zr.id, q, recipe)
			local largest = {}
			for kid, regions in pairs(map.by_kind) do
				local best
				for _, r in ipairs(regions) do
					if not best or r.size > best.size or (r.size == best.size and r.id < best.id) then
						best = r
					end
				end
				largest[kid] = best
			end
			for _, c in ipairs(map.order) do
				local r = c.region
				if r then
					local kind = r.kind
					local is_camp = r.camp and 1 or 0
					fc:write(table.concat({zr.numeric_id, c.i, c.j, r.id, kind.id, is_camp,
						kind.quest_target and 1 or 0, kind.density or (is_camp == 1 and "camp" or "-"),
						largest[kind.id] == r and 1 or 0, r.size}, "\t"), "\n")
				end
			end
			for _, l in ipairs(map.leaders or {}) do
				fl:write(table.concat({zr.numeric_id, l.role, l.x, l.z,
					l.region and l.region.kind.id or "-"}, "\t"), "\n")
			end
			for _, p in ipairs(map.places or {}) do
				fp:write(table.concat({zr.numeric_id, p.id, p.x, p.z}, "\t"), "\n")
			end
			for _, u in ipairs(map.camps or {}) do
				fk:write(table.concat({zr.numeric_id, u.id, floor(u.x), floor(u.z),
					u.site and "poi" or "generated"}, "\t"), "\n")
			end
		end
	end
	fc:close() fl:close() fp:close() fk:close()
end
local t_regions = os.clock() - t1

-- The named rares' route points (the consumer payload grug_core validates).
f = open("rares.tsv")
for _, row in ipairs(R.built.consumer_payload.rare_routes) do
	local a = Z.anchor(row.anchor.zone_id, row.anchor.slot_id)
	local parts = {row.id, zindex[row.anchor.zone_id] or 0, a.x, a.z}
	for _, o in ipairs(row.patrol_offsets) do
		parts[#parts + 1] = a.x + o.x
		parts[#parts + 1] = a.z + o.z
	end
	f:write(table.concat(parts, "\t"), "\n")
end
f:close()

meta:write("regions_s\t", ("%.1f"):format(t_regions), "\n")
meta:close()
print("done", seed, ("build %.1f coarse %.1f regions %.1f"):format(t_build, t_coarse, t_regions))
