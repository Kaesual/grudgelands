-- Round 51 follow-up lane FT portable test (the towns; round51-followup-plan
-- §1 items 4-8, §2 "FT"):
--   A. the six start towns' trees are halved (each within 45-56 % of its
--      count before, the Kapok giants kept) and no quarter of a start goes
--      bare (each quarter keeps at least a third of its trees before);
--   B. the capitals' trees are unchanged: every core's and district plot's
--      planted trees per capital equal the counts before;
--   C. Stillgrave: the burial grounds inside their walls hold exactly the
--      cells they held before (the trees aside), and outside the walls the
--      bones are a sparse scatter of at most 28 % of the count before, and
--      some remain;
--   D. the capital cores' ground cover: at most 45 % of the cover before,
--      Nhal Veyr's bones at most 10 %, and uneven -- in 8 x 8 blocks of open
--      ground at least three gaps (under a quarter of the core's mean) and
--      three patches (over 7/4 of it), where the plain scatter had none or
--      one; no new cover on a socket's feet or head cell;
--   E. the city's ground cover and lake plants (wp13/city_green.lua `cover`)
--      on a synthetic city with a lake and a street: present, sparse, on dry
--      open ground one above the ground, never on or beside a street, in the
--      core, on a plot with its collar and approach or on a taken cell; the
--      undead city's few bones; lily pads on a lake's water and weeds in its
--      bed (none without `lake`, none on a bed that is not sand); every
--      name in `cover_names`; the same on
--      every load and the same cells when split into mapchunk boxes;
--   F. one seed's real capitals (the seed fleet's runtime): every capital
--      gets city ground cover, Kezamba and Lethariel lily pads, and every
--      cover cell's name is in the overlay palette the writer resolves.
--
-- Prints the counts it checks. Usage (repo root):
--   luajit tools/r51_ft/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks, failed = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failed = failed + 1
		print("FAIL " .. label)
	end
	return ok
end
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"

-- Every town tree a composition plants, by its stem (the wp13 dressing's
-- `grown`, which every tree routine goes through).
local stems = {}
local real_dofile = dofile
rawset(_G, "dofile", function(path, ...)
	local result = real_dofile(path, ...)
	if type(path) == "string" and path:match("wp13/dressing%.lua$") and
			type(result) == "function" then
		local loader = result
		return function(...)
			local M = loader(...)
			local grown = M.grown
			M.grown = function(buf, palette, species, x, z, top)
				local planted = grown(buf, palette, species, x, z, top)
				if planted then stems[#stems + 1] = {x, z} end
				return planted
			end
			return M
		end
	end
	return result
end)
local function blueprint(name)
	local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
	if type(bp) == "function" then bp = bp() end
	return bp
end
local BONES = {}
for _, name in ipairs({"grug_nodes:bone_pile", "grug_nodes:skull_human",
		"grug_nodes:ribcage_human", "grug_nodes:skull_horned", "grug_nodes:spine_animal",
		"grug_nodes:bones_fragments"}) do
	BONES[name] = true
end

-- A. the starts -------------------------------------------------------------
-- Before (main 713fcf88): the trees and their quarters (x < 0 / x >= 0 by
-- z < 0 / z >= 0).
local START_BEFORE = {
	dawnmere = {82, {13, 18, 25, 26}}, hearthpine = {180, {50, 44, 36, 50}},
	kapok = {107, {26, 36, 25, 20}}, silverleaf = {128, {33, 33, 31, 31}},
	stillgrave = {164, {43, 53, 41, 27}}, sunscar = {84, {20, 20, 25, 19}},
}
local stillgrave
for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf", "stillgrave", "sunscar"}) do
	stems = {}
	local bp = blueprint(name)
	if name == "stillgrave" then stillgrave = bp end
	local quarter = {0, 0, 0, 0}
	for _, s in ipairs(stems) do
		local q = (s[1] < 0 and 1 or 2) + (s[2] < 0 and 0 or 2)
		quarter[q] = quarter[q] + 1
	end
	local before = START_BEFORE[name]
	print(("A %-10s trees %3d -> %3d, quarters %s -> %d/%d/%d/%d"):format(name, before[1],
		#stems, table.concat(before[2], "/"), quarter[1], quarter[2], quarter[3], quarter[4]))
	check(#stems >= 0.45 * before[1] and #stems <= 0.56 * before[1],
		name .. "'s trees are halved (" .. before[1] .. " -> " .. #stems .. ")")
	for q = 1, 4 do
		check(quarter[q] * 3 >= before[2][q], name .. "'s quarter " .. q .. " keeps its trees (" ..
			before[2][q] .. " -> " .. quarter[q] .. ")")
	end
end

-- B. the capitals' trees ----------------------------------------------------
local CAPITAL_TREES = {highcourt = 83, dur_brannoc = 62, lethariel = 141, nhal_veyr = 70,
	gor_drazhak = 35, kezamba = 37}
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
local cores = {}
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
		"kezamba"}) do
	local kit = capital.kit(key)
	stems = {}
	cores[key] = kit.core.build()
	for _, plot in ipairs(kit.plots) do plot.build() end
	check(#stems == CAPITAL_TREES[key], key .. "'s trees are unchanged (" ..
		CAPITAL_TREES[key] .. " -> " .. #stems .. ")")
end

-- C. Stillgrave's bones -----------------------------------------------------
do
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local green = dofile(wp13 .. "/city_green.lua")(wp13)
	local tree = {}
	for _, n in ipairs(green.names("undead")) do tree[n] = true end
	local function in_yard(x, z)
		return (x >= -50 and x <= -26 and z >= -26 and z <= -6) or
			(x >= 26 and x <= 50 and z >= 8 and z <= 28)
	end
	local rows, inside, outside = {}, 0, 0
	for _, c in ipairs(stillgrave.cells) do
		if in_yard(c.x, c.z) then
			if not tree[c.name] then
				rows[#rows + 1] = c.x .. "," .. c.y .. "," .. c.z .. "," .. c.name .. "," .. c.param2
			end
			if BONES[c.name] then inside = inside + 1 end
		elseif BONES[c.name] then
			outside = outside + 1
		end
	end
	table.sort(rows)
	local digest = common.hex(sha(table.concat(rows, "\n")))
	print(("C stillgrave: bones inside the walls 103 -> %d, outside 254 -> %d"):format(inside,
		outside))
	-- the burial grounds' cells before (main 713fcf88)
	check(#rows == 2695 and digest ==
		"d922f0fdc58bbe0fb9347cf3154409296e26634aaba30d25893b362b8c8aee5e",
		"Stillgrave's burial grounds are unchanged (" .. #rows .. " cells, " .. digest .. ")")
	check(inside == 103, "the bones inside the walls stay (" .. inside .. ")")
	check(outside > 20 and outside <= 0.28 * 254,
		"outside the walls a sparse scatter of bones (" .. outside .. ")")
end

-- D. the capital cores' cover -----------------------------------------------
do
	local parts = dofile(wp13 .. "/parts.lua")
	local palettes = dofile(wp13 .. "/palette.lua")
	-- before (main 713fcf88): the cover cells and Nhal Veyr's bones
	local BEFORE = {highcourt = 582, dur_brannoc = 594, lethariel = 641, nhal_veyr = 1760,
		gor_drazhak = 498, kezamba = 676}
	-- the plain scatter's tufts on a socket's feet before (a plant is not
	-- walkable; the patches keep a subset of the scatter's cells)
	local SOCKET_BEFORE = {lethariel = 5, gor_drazhak = 2}
	for key, core in pairs(cores) do
		local p = palettes.new(capital.CAPITALS[key].race)
		local cover = {}
		for _, role in ipairs({"undergrowth", "grass_tuft", "fern"}) do
			local n = p.maybe(role)
			if n then cover[n] = true end
		end
		for n in pairs(BONES) do cover[n] = true end
		local at = {}
		for _, c in ipairs(core.cells) do at[c.x .. ":" .. c.y .. ":" .. c.z] = c.name end
		local n_cover, n_open, bones, blocks = 0, 0, 0, {}
		local function block(x, z)
			local b = math.floor((x + 64) / 8) * 100 + math.floor((z + 64) / 8)
			blocks[b] = blocks[b] or {0, 0}
			return blocks[b]
		end
		for _, c in ipairs(core.cells) do
			if c.y == 1 and cover[c.name] then
				n_cover = n_cover + 1
				if BONES[c.name] then bones = bones + 1 end
				local b = block(c.x, c.z)
				b[1] = b[1] + 1
			end
			if c.y == 0 and parts.wild_soil(c.name) then
				local above = at[c.x .. ":1:" .. c.z]
				if above == nil or above == "air" or cover[above] then
					n_open = n_open + 1
					local b = block(c.x, c.z)
					b[2] = b[2] + 1
				end
			end
		end
		local mean = n_cover / math.max(1, n_open)
		local gaps, patches = 0, 0
		for _, b in pairs(blocks) do
			if b[2] >= 32 then
				local d = b[1] / b[2]
				if d < mean / 4 then gaps = gaps + 1 elseif d > mean * 7 / 4 then patches = patches + 1 end
			end
		end
		print(("D %-11s cover %4d -> %4d (bones %d), %d gaps and %d patches"):format(key,
			BEFORE[key], n_cover, bones, gaps, patches))
		check(n_cover > 0 and n_cover <= 0.45 * BEFORE[key], key .. "'s core cover is cut (" ..
			BEFORE[key] .. " -> " .. n_cover .. ")")
		check(gaps >= 3 and patches >= 3, key .. "'s core cover is uneven (" .. gaps ..
			" gaps, " .. patches .. " patches)")
		if key == "nhal_veyr" then
			check(bones > 0 and bones <= 90, "Nhal Veyr's core bones are cut (899 -> " .. bones .. ")")
		end
		local blocked = 0
		for _, s in ipairs(core.landmarks.sockets or {}) do
			for _, y in ipairs({s.y, s.y + 1}) do
				if cover[at[s.x .. ":" .. y .. ":" .. s.z] or ""] then blocked = blocked + 1 end
			end
		end
		check(blocked <= (SOCKET_BEFORE[key] or 0), key .. ": no new cover on a socket (" ..
			blocked .. ")")
	end
end

-- E. the city's cover on a synthetic city -----------------------------------
local green_module = dofile(wp13 .. "/city_green.lua")(wp13)
do
	local pts = {}
	for i = -120, 119, 8 do pts[#pts + 1] = {i, -120} end
	for i = -120, 119, 8 do pts[#pts + 1] = {120, i} end
	for i = 120, -119, -8 do pts[#pts + 1] = {i, 120} end
	for i = 120, -119, -8 do pts[#pts + 1] = {-120, i} end
	local layout = {wall = {pts = pts}, squares = {{x = 70, z = -70, r = 6}}}
	local anchor = {x = 1000, z = 2000}
	local plot = {min_x = 1060, max_x = 1080, min_z = 2060, max_z = 2080, turns = 0}
	-- a street at local x 30..31 and a lake (local x -100..-60, z 60..100,
	-- 1 to 10 deep from its rim to its middle)
	local function column(x, z)
		local lx, lz = x - anchor.x, z - anchor.z
		local road = lx == 30 or lx == 31
		if lx >= -100 and lx <= -60 and lz >= 60 and lz <= 100 then
			local rim = math.min(lx + 100, -60 - lx, lz - 60, 100 - lz)
			return 9 - math.min(9, rim), 10, road
		end
		return 10, nil, road
	end
	local function make(race, lake)
		return green_module.new({race = race, anchor = anchor, layout = layout,
			plots = {plot}, column = column, lake = lake})
	end
	local box = {min_x = anchor.x - 130, max_x = anchor.x + 130,
		min_z = anchor.z - 130, max_z = anchor.z + 130}
	for _, race in ipairs({"human", "dwarf", "elf", "undead", "orc", "troll"}) do
		local green = make(race, true)
		local taken = {}
		for _, c in ipairs(green.cells(box)) do taken[c.x .. ":" .. c.y .. ":" .. c.z] = true end
		local cover = green.cover(box, taken)
		local allowed = {}
		for _, n in ipairs(green_module.cover_names(race, true)) do allowed[n] = true end
		local plants, bones, lilies, weeds, bad, names_ok, on_taken = 0, 0, 0, 0, 0, true, 0
		for _, c in ipairs(cover) do
			if not allowed[c.name] then names_ok = false end
			if taken[c.x .. ":" .. c.y .. ":" .. c.z] then on_taken = on_taken + 1 end
			local lx, lz = c.x - anchor.x, c.z - anchor.z
			local ground, water = column(c.x, c.z)
			-- the core (49 + 4), the wall (12), the plot with collar (8 + 1)
			-- and approach (12 in front, -z), the square (6 + 4), the street
			-- and its neighbours
			if (math.abs(lx) <= 53 and math.abs(lz) <= 53) or math.abs(lx) > 108 or
					math.abs(lz) > 108 or (c.x >= plot.min_x - 9 and c.x <= plot.max_x + 9 and
						c.z >= plot.min_z - 21 and c.z <= plot.max_z + 9) or
					((lx - 70) * (lx - 70) + (lz + 70) * (lz + 70) <= 100) or
					(lx >= 29 and lx <= 32) then
				bad = bad + 1
			end
			if c.name == green_module.LILY then
				lilies = lilies + 1
				if not water or c.y ~= water + 1 or c.param2 > 3 then bad = bad + 1 end
			elseif c.name == green_module.WEED then
				weeds = weeds + 1
				if not water or c.y ~= ground or c.param2 < 16 or c.param2 > 64 or
						c.param2 % 16 ~= 0 or c.param2 / 16 > water - ground - 1 then
					bad = bad + 1
				end
			else
				plants = plants + 1
				if BONES[c.name] then bones = bones + 1 end
				if water or c.y ~= ground + 1 then bad = bad + 1 end
			end
		end
		print(("E %-6s plants %4d (bones %d), lilies %d, weeds %d"):format(race, plants, bones,
			lilies, weeds))
		check(names_ok, race .. ": every cover name is in cover_names")
		check(bad == 0, race .. ": the cover keeps to the open ground and the lake (" .. bad .. ")")
		check(on_taken == 0, race .. ": no cover on a tree's cell (" .. on_taken .. ")")
		-- the open dry ground is about 33,000 columns: sparse, but there
		check(plants > 300 and plants < 3000, race .. ": sparse city ground cover (" .. plants .. ")")
		check(lilies > 5 and weeds > 5, race .. ": lily pads and weeds in the lake (" .. lilies ..
			", " .. weeds .. ")")
		if race == "undead" then
			check(bones > 10 and bones * 4 < plants, "the undead city's few bones (" .. bones .. ")")
		else
			check(bones == 0, race .. ": no bones")
		end
		if race == "troll" then
			local again = make(race, true).cover(box, taken)
			local same = #again == #cover
			for i = 1, math.min(#again, #cover) do
				local a, b = again[i], cover[i]
				if a.x ~= b.x or a.y ~= b.y or a.z ~= b.z or a.name ~= b.name or
						a.param2 ~= b.param2 then
					same = false
				end
			end
			check(same, "the city cover is deterministic")
			local split, n = {}, 0
			local fresh = make(race, true)
			for _, sub in ipairs({
					{min_x = box.min_x, max_x = anchor.x - 1, min_z = box.min_z, max_z = anchor.z - 1},
					{min_x = anchor.x, max_x = box.max_x, min_z = box.min_z, max_z = anchor.z - 1},
					{min_x = box.min_x, max_x = anchor.x - 1, min_z = anchor.z, max_z = box.max_z},
					{min_x = anchor.x, max_x = box.max_x, min_z = anchor.z, max_z = box.max_z}}) do
				for _, c in ipairs(fresh.cover(sub, taken)) do
					split[c.x .. ":" .. c.y .. ":" .. c.z] = c.name .. ":" .. c.param2
					n = n + 1
				end
			end
			local seam = n == #cover
			for _, c in ipairs(cover) do
				if split[c.x .. ":" .. c.y .. ":" .. c.z] ~= c.name .. ":" .. c.param2 then seam = false end
			end
			check(seam, "four mapchunk parts write exactly the whole city's cover")
			local dry = 0
			for _, c in ipairs(make(race, false).cover(box, taken)) do
				if c.name == green_module.LILY or c.name == green_module.WEED then dry = dry + 1 end
			end
			check(dry == 0, "no lake plants in a capital without a lake (" .. dry .. ")")
			-- a waterweed only on a natural sand bed (the writer's `bed_ok`):
			-- sand here only on even local x
			local function sand(x) return (x - anchor.x) % 2 == 0 end
			local on_sand, off_sand, lilies_kept = 0, 0, 0
			for _, c in ipairs(make(race, true).cover(box, taken, function(x) return sand(x) end)) do
				if c.name == green_module.WEED then
					if sand(c.x) then on_sand = on_sand + 1 else off_sand = off_sand + 1 end
				elseif c.name == green_module.LILY then
					lilies_kept = lilies_kept + 1
				end
			end
			check(on_sand > 0 and off_sand == 0, "waterweed only on a sand bed (" .. on_sand ..
				" on sand, " .. off_sand .. " off it)")
			local none = 0
			for _, c in ipairs(make(race, true).cover(box, taken, function() return false end)) do
				if c.name == green_module.WEED then none = none + 1 end
			end
			check(none == 0 and lilies_kept == lilies, "no sand bed, no waterweed; the lily pads stay (" ..
				none .. ", " .. lilies_kept .. ")")
		end
	end
end

-- F. one seed's real capitals -----------------------------------------------
do
	local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, "12345")
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	local native = dofile(wp40 .. "/r7_native.lua")
	local authority = R.main.build_authority(native.identities())
	local ps = authority.planner_source
	local function upvalue(fn, wanted)
		for index = 1, 255 do
			local name, value = debug.getupvalue(fn, index)
			if name == nil then break end
			if name == wanted then return value end
		end
		error("upvalue " .. wanted .. " not found")
	end
	local settlements = upvalue(R.main.settlement_sockets, "settlements")
	local function column(x, z)
		local _, _, _, _, _, terrain_y, water_y = ps.column_values_at(x, z)
		local road = ps.road_column_at and ps.road_column_at(x, z) == "surface" or false
		if type(water_y) ~= "number" or water_y <= terrain_y then water_y = nil end
		return terrain_y, water_y, road
	end
	local seen = 0
	for _, row in ipairs(settlements) do
		local profile, prepared = row.profile, row.prepared
		if profile.slot == "capital" then
			seen = seen + 1
			local anchor = authority.zones_session.anchor(profile.zone_id, profile.slot)
			local rects, overlay = {}, nil
			for _, b in ipairs(prepared.blueprints) do
				if b.descriptor.kind == "reference" then
					local rect = settlement.plot_rect(b, anchor.x, anchor.z)
					rect.turns = b.descriptor.turns or 0
					rects[#rects + 1] = rect
				elseif b.descriptor.kind == "overlay" then
					overlay = b
				end
			end
			local palette = {}
			for _, name in ipairs(overlay.city.names or overlay.descriptor.names or {}) do
				palette[name] = true
			end
			local green = overlay.city.green({x = anchor.x, z = anchor.z}, rects, column)
			local plants, lilies, unknown = 0, 0, 0
			local x0 = math.floor((anchor.x - 260 + 32) / 80) * 80 - 32
			local z0 = math.floor((anchor.z - 260 + 32) / 80) * 80 - 32
			for bz = z0, anchor.z + 260, 80 do
				for bx = x0, anchor.x + 260, 80 do
					local box = {min_x = bx, max_x = bx + 79, min_z = bz, max_z = bz + 79}
					local taken = {}
					for _, c in ipairs(green.cells(box)) do taken[c.x .. ":" .. c.y .. ":" .. c.z] = true end
					for _, c in ipairs(green.cover(box, taken)) do
						if next(palette) and not palette[c.name] then unknown = unknown + 1 end
						if c.name == green_module.LILY then lilies = lilies + 1
						elseif c.name ~= green_module.WEED then plants = plants + 1 end
					end
				end
			end
			print(("F %-12s city cover %d, lily pads %d"):format(profile.key, plants, lilies))
			check(next(palette) ~= nil, profile.key .. ": the overlay publishes its palette")
			check(unknown == 0, profile.key .. ": every cover name is in the overlay palette (" ..
				unknown .. ")")
			check(plants > 100, profile.key .. " has city ground cover (" .. plants .. ")")
			local lake = capital.CAPITALS[profile.key].lake
			check((lake and lilies > 10) or (not lake and lilies == 0), profile.key ..
				"'s lake plants (" .. lilies .. " lily pads)")
		end
	end
	check(seen == 6, "the six capitals (" .. seen .. ")")
end

print(("r51_ft: %d checks, %d failed"):format(checks, failed))
if failed > 0 then error("r51_ft: " .. failed .. " failures", 0) end
