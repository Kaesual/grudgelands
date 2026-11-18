-- Round 82 lane BOOT portable test (the building library's construction
-- cost, docs/planning/round82-plan.md §4 BOOT):
--   A. the packed cell key (`parts.cell_key`): one exact integer per
--      position, -0 as 0, nil off the grid; `put` refuses such a position,
--      `at` misses it; a buffer keeps its write order;
--   B. a template part with its per-placement memo is the part resolved
--      cell by cell (`templates.resolve`), for every template of Highcourt,
--      Kezamba and Dawnmere Fields' placements;
--   C. the shared tree pool (`dressing.tree_pool`): every entry's `leaves`
--      is its leaf count, the narrowest first; a city green keeps its pool
--      over a second `new` (an idle release);
--   D. the cost, printed (`count` lines): template parses per capital kit,
--      palette role lookups, buffer writes and reads (each built one string
--      key before Round 82) and tree generations of the Highcourt kit, and
--      the tree generations of two city greens.
-- Usage (repo root): luajit tools/r82_boot/portable_test.lua [REPO] [count]
--   `count` prints D only (it runs on a tree before Round 82 too).
-- What the library builds stays byte-identical: tools/r82_boot/dump.lua.
local repo = arg[1] or "."
local COUNT_ONLY = arg[2] == "count"
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local parts = dofile(wp13 .. "/parts.lua")

-- A. the packed cell key ---------------------------------------------------------
if not COUNT_ONLY then
	local key = parts.cell_key
	check(key(0, 0, 0) == key(-0, 0, -0), "-0 packs like 0")
	local seen, distinct = {}, true
	for z = -2, 2 do
		for y = -2, 2 do
			for x = -2, 2 do
				local k = key(x, y, z)
				if seen[k] or k % 1 ~= 0 then distinct = false end
				seen[k] = true
			end
		end
	end
	check(distinct, "distinct positions, distinct integer keys")
	check(key(32767, -32767, 32767) ~= nil and key(32768, 0, 0) == nil and
		key(0, -32768, 0) == nil and key(0.5, 0, 0) == nil and key(0, 0, 0 / 0) == nil,
		"a position off the grid has no key")
	local buf = parts.buffer()
	buf:put(2, 1, -3, "default:stone")
	buf:put(-1, 0, 4, "default:dirt")
	buf:put(2, 1, -3, "default:cobble")
	check(buf:at(2, 1, -3).name == "default:cobble" and buf:at(2, 1, 3) == nil and
		buf:at(0.5, 1, -3) == nil and buf:at(40000, 1, -3) == nil, "at reads its cell")
	local order, count = buf:cells()
	check(count == 2 and order[1].x == 2 and order[2].z == 4, "the write order holds")
	check(not pcall(buf.put, buf, 1.5, 0, 0, "default:stone") and
		not pcall(buf.put, buf, 0, 0, 40000, "default:stone"), "put refuses a position off the grid")
	local zero = parts.buffer()
	zero:put(-0, 0, 0, "default:stone")
	check(zero:at(0, 0, 0) ~= nil, "a cell put at -0 is the cell at 0")
end

-- B. the memo against cell-by-cell resolution ---------------------------------------
if not COUNT_ONLY then
	local templates = dofile(wp13 .. "/templates.lua")(wp13)
	local compared = 0
	local function reference(t, race, palette_of)
		-- every non-late cell as `templates.part` wrote it before the memo
		local out = {}
		for layer_index, layer in ipairs(t.grid) do
			for row_index, row in ipairs(layer) do
				for column, key in ipairs(row) do
					local entry = key and t.legend[key]
					if key and not (entry and entry.late) then
						local name, param2 = templates.resolve(t, key, palette_of, race)
						if name then
							out[#out + 1] = {t.x0 + column - 1, t.y0 + layer_index - 1,
								t.z0 + row_index - 1, name, param2}
						end
					end
				end
			end
		end
		return out
	end
	local function same(part, t, race, palette_of)
		-- a planted part or one with late cells writes in another order
		if #t.stems > 0 or t.meta.undergrowth then return true end
		local want = reference(t, race, palette_of)
		local got, count = part.buffer:cells()
		local late = 0
		for _, layer in ipairs(t.grid) do
			for _, row in ipairs(layer) do
				for _, key in ipairs(row) do
					if key and t.legend[key] and t.legend[key].late then late = late + 1 end
				end
			end
		end
		if late > 0 then return true end
		compared = compared + 1
		if count ~= #want then return false end
		for index = 1, count do
			local a, b = got[index], want[index]
			if a.x ~= b[1] or a.y ~= b[2] or a.z ~= b[3] or a.name ~= b[4] or a.param2 ~= b[5] then
				return false
			end
		end
		return true
	end
	for _, key in ipairs({"highcourt", "kezamba"}) do
		local capital = templates.capital(key)
		for _, use in ipairs(capital.roster.uses) do
			local t = capital.templates[use.template]
			local roof = use.channels.roof
			local part = capital.part(use.template, "x", use.main, roof)
			local main = use.main or "town"
			local race = capital.roster.palettes[main] and capital.roster.palettes[main].race or
				capital.roster.race
			local channels = {}
			for channel in pairs(t.channels) do
				channels[channel] = channel == "roof" and roof or channel
			end
			check(same(part, t, race, function(channel)
				if channel == nil then return capital.palettes[main] end
				return capital.palettes[channels[channel]]
			end), key .. ": " .. use.key .. " resolves as cell by cell")
		end
	end
	local town = templates.town("dawnmere")
	for _, place in ipairs(town.places) do
		check(same(town.part(place), town.templates[place.template], place.race,
			town.palette_of(place)), "dawnmere: " .. place.id .. " resolves as cell by cell")
	end
	check(compared > 60, "parts compared cell by cell (" .. compared .. ")")
end

-- C. the shared tree pool ------------------------------------------------------------
local synthetic_city
do
	local pts = {}
	for i = -120, 119, 8 do pts[#pts + 1] = {i, -120} end
	for i = -120, 119, 8 do pts[#pts + 1] = {120, i} end
	for i = 120, -119, -8 do pts[#pts + 1] = {i, 120} end
	for i = 120, -119, -8 do pts[#pts + 1] = {-120, i} end
	local anchor = {x = 1000, z = 2000}
	synthetic_city = {race = "human", anchor = anchor,
		layout = {wall = {pts = pts}, squares = {{x = 70, z = -70, r = 6}}},
		plots = {{min_x = 1060, max_x = 1080, min_z = 2060, max_z = 2080, turns = 0}},
		column = function(x, z)
			return 10 + (z - anchor.z > 90 and 1 or 0), nil,
				(x - anchor.x) == 30 or (x - anchor.x) == 31
		end}
end
if not COUNT_ONLY then
	local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
	local trees = dressing.tree_templates()
	local pool = dressing.tree_pool("apple", function(k) return k * 101 end)
	local counted, narrow = true, true
	for k, entry in ipairs(pool.entries) do
		local leaves = 0
		for _, cell in ipairs(entry.cells) do
			if cell.flag == trees.LEAF then leaves = leaves + 1 end
		end
		if leaves ~= entry.leaves or entry.seed ~= k then counted = false end
	end
	for rank = 2, #pool.smallest do
		local a, b = pool.entries[pool.smallest[rank - 1]], pool.entries[pool.smallest[rank]]
		if a.area > b.area then narrow = false end
	end
	check(#pool.entries == 24 and counted and narrow,
		"a pool's entries carry their leaf counts, the narrowest first")
end

-- D. the cost ---------------------------------------------------------------------------
do
	local counts
	local function reset()
		counts = {parse = 0, role = 0, put = 0, at = 0, tree = 0}
	end
	reset()
	local real_dofile = dofile
	rawset(_G, "dofile", function(path)
		local result = real_dofile(path)
		if path:match("/parts%.lua$") then
			local Buffer = getmetatable(result.buffer()).__index
			local put, at = Buffer.put, Buffer.at
			Buffer.put = function(...) counts.put = counts.put + 1 return put(...) end
			Buffer.at = function(...) counts.at = counts.at + 1 return at(...) end
		elseif path:match("/palette%.lua$") then
			local new = result.new
			result.new = function(...)
				local handle = new(...)
				for _, field in ipairs({"node", "maybe", "variant"}) do
					local fn = handle[field]
					handle[field] = function(...)
						counts.role = counts.role + 1
						return fn(...)
					end
				end
				return handle
			end
		elseif path:match("/templates%.lua$") then
			return function(...)
				local M = result(...)
				local parse = M.parse_template
				M.parse_template = function(...)
					counts.parse = counts.parse + 1
					return parse(...)
				end
				return M
			end
		elseif path:match("/tree_templates%.lua$") then
			return function(...)
				local T = result(...)
				local tree = T.tree
				T.tree = function(...)
					counts.tree = counts.tree + 1
					return tree(...)
				end
				return T
			end
		end
		return result
	end)
	local capital_source = dofile(wp40 .. "/r7_capital_blueprint.lua")
	local parses = {}
	for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
			"gor_drazhak", "kezamba"}) do
		reset()
		local kit = capital_source.kit(key)
		parses[#parses + 1] = key .. "=" .. counts.parse
		if key == "highcourt" then
			reset()
			local started = os.clock()
			kit.core.build()
			for _, plot in ipairs(kit.plots) do plot.build() end
			print(("count\thighcourt build\trole lookups %d, buffer writes %d, reads %d " ..
				"(%d string keys built before Round 82), tree generations %d, %.2f s CPU"):format(
				counts.role, counts.put, counts.at, counts.put + counts.at, counts.tree,
				os.clock() - started))
		end
	end
	print("count\ttemplate parses per capital kit\t" .. table.concat(parses, " "))
	reset()
	local green_module = dofile(wp13 .. "/city_green.lua")(wp13)
	local box = {min_x = 870, max_x = 1130, min_z = 1870, max_z = 2130}
	local first = green_module.new(synthetic_city).cells(box)
	local second = green_module.new(synthetic_city).cells(box)
	print(("count\ttwo city greens\ttree generations %d"):format(counts.tree))
	rawset(_G, "dofile", real_dofile)
	if not COUNT_ONLY then
		check(counts.tree == 24, "a second city green reuses the pool (" .. counts.tree ..
			" tree generations)")
		local same = #first == #second and #first > 1000
		for index = 1, math.min(#first, #second) do
			local a, b = first[index], second[index]
			if a.x ~= b.x or a.y ~= b.y or a.z ~= b.z or a.name ~= b.name or
					a.param2 ~= b.param2 then
				same = false
			end
		end
		check(same, "a city green with a kept pool grows the same trees")
	end
end

print("r82_boot portable test: " .. (COUNT_ONLY and "COUNTED" or ("PASS (" .. checks .. " checks)")))
