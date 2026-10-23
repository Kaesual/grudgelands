-- Round 57 lane FIX56: the flight rule over the four bays of one seed
-- (ruling 23, "bays are not ocean"). Pure x/z queries, no engine.
--
--   luajit tools/r57_fix56/bay_scan.lua REPO SEED [STEP] [GRID_OUT]
--
-- Builds the zones session as the runtime does (wp40/world_assembly.lua,
-- without the capitals) and a horizontal session of the same world, and
-- every STEP nodes (default 4) over each bay's box (its centreline's bounds
-- plus 400 nodes) compares two water classes through the real flight rule
-- (grug_mounts.flight_rule, flight.lua):
--   before  the generation class (simple_map.lua classification_values_at;
--           wet river and lake columns planned water), what the rule read
--           up to 0.56
--   after   the gameplay class grug_zones publishes (zones.lua
--           water_class_at), which reads a bay's shore strip of the belt as
--           the bay's (simple_map.lua bay_shore_at)
-- and counts per bay:
--   flipped      columns whose class changed (belt -> planned water)
--   fly_after    of those, columns a faction may now fly over
--   rim_before / rim_after
--                no-fly sea columns next to the bay's water landward of its
--                mouth: a sea column (neither land nor planned water) with a
--                bay column (water query "bay"; before: of the bay's body,
--                after: of the gameplay class) within 24 nodes in one of 8
--                directions, and the bay's organic mouth cut (approximated in
--                the plain warp) not yet passed. What the ruling is about.
--   pockets      no-fly sea columns (after) that no path through no-fly sea
--                (4 neighbours on the STEP grid) joins to the open sea or the
--                box's edge: no-fly specks inside flyable bay water
--   caps         bay-body columns past the mouth cut and their classes
--                (they stay belt or open sea: the outer bay-mouth caps)
-- and prints up to 4 example columns per bay of each kind. With GRID_OUT it
-- writes one text grid per bay for tools/r57_fix56/bay_png.py.
local repo, seed = arg[1], arg[2]
local STEP = tonumber(arg[3] or "4")
local grid_out = arg[4]
assert(repo and seed, "usage: bay_scan.lua REPO SEED [STEP] [GRID_OUT]")
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local A = dofile(dir .. "/world_assembly.lua")(dir, common.new_sha256())
local W = A.world(seed)
local session = W.zones().new_with_planner_source_runtime(seed, 1)
local source = W.place()
local horizontal = W.horizontal_factory({source = source, schemas = A.schemas,
	canonical = A.canonical, deterministic = A.deterministic,
	raw_sha256 = common.new_sha256()}).new(seed)
local field = dofile(dir .. "/zone_field.lua").new_checked(seed, source, source.zone_field)
local mouth_noise = A.terrain_field.simplex(seed, "bay_mouth")
local MOUTH = source.water.bay_mouth

rawset(_G, "grug_zones", {get = function(id) return session.get(id) end})
rawset(_G, "grug_mounts", {})
dofile(repo .. "/mods/PLAYER/grug_mounts/flight.lua")
local flight_rule = grug_mounts.flight_rule

local function flies(class, x, z)
	local land = class == "land" or class == "planned_water"
	local id = land and session.id_at(x, z) or nil
	return flight_rule("accord", class, id) or flight_rule("throng", class, id)
end
local function before_class(x, z)
	local class = horizontal.water_class_at(x, z)
	if class == "land" and session.water_class_at(x, z) == "planned_water" then
		return "planned_water"
	end
	return class
end
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}
-- A bay column (water query "bay") within 24 nodes in one of 8 directions:
-- of the bay's body (the generation class) for "before", of the gameplay
-- class for "after".
local function near_bay(x, z, gameplay)
	for d = 4, 24, 4 do
		for _, o in ipairs(DIRS) do
			local bx, bz = x + o[1] * d, z + o[2] * d
			local class = gameplay and session.water_class_at(bx, bz) or
				horizontal.water_class_at(bx, bz)
			if class == "planned_water" and session.water_query_at(bx, bz) == "bay" then
				return true
			end
		end
	end
	return false
end

local floor = math.floor
local CHAR = {land = ".", planned_water = "b", coastal_shelf = "s",
	deep_ocean = "o", immutable_dragon_channel = "c"}
print(("seed %s step %d"):format(seed, STEP))
local totals = {flipped = 0, fly_after = 0, rim_before = 0, rim_after = 0, pockets = 0}
for index, bay in ipairs(source.bays) do
	local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(bay.centreline) do
		local h = p.half_width or 0
		min_x, max_x = math.min(min_x, p.x - h), math.max(max_x, p.x + h)
		min_z, max_z = math.min(min_z, p.z), math.max(max_z, p.z)
	end
	min_x, max_x = floor(min_x - 400), floor(max_x + 400)
	min_z, max_z = floor(min_z - 400), floor(max_z + 400)
	local n = {flipped = 0, fly_after = 0, rim_before = 0, rim_after = 0}
	local caps, examples, lines = {}, {}, {}
	local nofly, open = {}, {}
	local function example(kind, x, z, text)
		local list = examples[kind] or {}
		examples[kind] = list
		if #list < 4 then list[#list + 1] = ("(%d,%d) %s"):format(x, z, text) end
	end
	for z = max_z, min_z, -STEP do
		local line = {}
		for x = min_x, max_x, STEP do
			local before, after = before_class(x, z), session.water_class_at(x, z)
			local body, _, bz = field.bay_at(x, z)
			local wz
			if body == index then wz = bz else _, wz = field.warp_at(x, z) end
			local cut = bay.deep_ocean_cut_z + MOUTH.amplitude *
				mouth_noise(x / MOUTH.period, bay.deep_ocean_cut_z / MOUTH.period)
			local inner
			if bay.deep_ocean_side == "min_z" then inner = wz > cut else inner = wz < cut end
			local ch = CHAR[after] or "?"
			if before ~= after then
				n.flipped = n.flipped + 1
				ch = "B"
				if flies(after, x, z) then n.fly_after = n.fly_after + 1 end
				example("flipped", x, z, ("%s -> %s, zone %s, query %s"):format(before, after,
					tostring(session.id_at(x, z)), tostring((session.water_query_at(x, z)))))
			end
			if body == index and not inner then
				caps[after] = (caps[after] or 0) + 1
			end
			local sea_before = before ~= "land" and before ~= "planned_water"
			local sea_after = after ~= "land" and after ~= "planned_water"
			if inner and sea_before and near_bay(x, z, false) then
				n.rim_before = n.rim_before + 1
			end
			if inner and sea_after and near_bay(x, z, true) then
				do
					n.rim_after = n.rim_after + 1
					ch = "S"
					example("rim_after", x, z, ("%s, zone %s"):format(after,
						tostring(session.id_at(x, z))))
				end
			end
			line[#line + 1] = ch
			local key = #lines * 100000 + #line
			if sea_after and not flies(after, x, z) then nofly[key] = true end
			if after == "deep_ocean" then open[#open + 1] = key end
		end
		lines[#lines + 1] = table.concat(line)
	end
	-- pockets: flood the no-fly sea from the open sea and the box's edge
	local rows, cols = #lines, #lines[1]
	local reached, queue = {}, {}
	for key in pairs(nofly) do
		local r, c = floor(key / 100000), key % 100000
		if r == 0 or c == 1 or r == rows - 1 or c == cols then queue[#queue + 1] = key end
	end
	for _, key in ipairs(open) do queue[#queue + 1] = key end
	local head = 1
	while head <= #queue do
		local key = queue[head]
		head = head + 1
		if nofly[key] and not reached[key] then
			reached[key] = true
			for _, d in ipairs({1, -1, 100000, -100000}) do
				if nofly[key + d] and not reached[key + d] then queue[#queue + 1] = key + d end
			end
		end
	end
	n.pockets = 0
	for key in pairs(nofly) do
		if not reached[key] then
			n.pockets = n.pockets + 1
			local r, c = floor(key / 100000), key % 100000
			example("pocket", min_x + (c - 1) * STEP, max_z - r * STEP, "")
		end
	end
	print(("bay %s box x %d..%d z %d..%d: flipped %d (fly after %d), rim no-fly " ..
		"before %d after %d, pockets after %d"):format(bay.id, min_x, max_x, min_z, max_z,
		n.flipped, n.fly_after, n.rim_before, n.rim_after, n.pockets))
	local cap_keys = {}
	for key in pairs(caps) do cap_keys[#cap_keys + 1] = key end
	table.sort(cap_keys)
	local cap_text = {}
	for _, key in ipairs(cap_keys) do cap_text[#cap_text + 1] = key .. " " .. caps[key] end
	print("  mouth caps (bay body past the cut): " .. table.concat(cap_text, ", "))
	for _, kind in ipairs({"flipped", "rim_after", "pocket"}) do
		for _, e in ipairs(examples[kind] or {}) do print("  " .. kind .. " e.g. " .. e) end
	end
	for key in pairs(totals) do totals[key] = totals[key] + n[key] end
	if grid_out then
		local file = assert(io.open(("%s/%s_%s.txt"):format(grid_out, seed, bay.id), "w"))
		file:write(("%d %d %d %d %d\n"):format(min_x, max_z, STEP, #lines[1], #lines))
		file:write(table.concat(lines, "\n"), "\n")
		file:close()
	end
end
print(("total seed %s: flipped %d (fly after %d), rim no-fly before %d after %d, " ..
	"pockets after %d (step %d)"):format(seed, totals.flipped, totals.fly_after,
	totals.rim_before, totals.rim_after, totals.pockets, STEP))
