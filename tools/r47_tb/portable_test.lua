-- Round 47 lane TB portable test (round47-plan.md §4.2): the Lua tree
-- generator mods/MAPGEN/grug_mapgen/wp40/treegen.lua against the JS concept
-- tools/r46_tree/concept/treegen.js, through the reference that
-- tools/r47_tb/write_reference.js wrote (no node needed here):
--   A. the module is pure: it loads in an environment that refuses every
--      global but math, table, error and tostring (no core, no writes);
--   B. treegen.js is the one the reference was written from;
--   C. per species and each of the reference's 300 seeds the node list and
--      the root cells equal the JS output on flat ground (no callback), and
--      for apple, jungle and kapok on a bumpy ground too; the other species
--      never ask the ground and give the flat tree on any ground;
--   D. the canonical serialisation of nine full trees equals the JS text
--      (the first differing line is shown);
--   E. the Shapes view's root study equals the JS for three cases;
--   F. the seed range: 2147483646 gives the tree of 0, 2147483645 and -7
--      that of -1, 2147483647 that of 1.
--
-- Usage (repo root): luajit tools/r47_tb/portable_test.lua [REPO] [time]
-- With `time` it then reports the time per tree per species (mean and
-- worst over the reference seeds, flat ground, os.clock) and one template
-- set (seeds 1..32 per species, 1..16 for kapok); it also runs under
-- tools/bin/lua51.
local ROOT = arg[1] or "."
local TIME = arg[2] == "time"
local checks = 0
local failures = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 30 then print("FAIL " .. label) end
	end
end

-- A. purity
local allowed = {math = math, table = table, error = error, tostring = tostring}
local env = setmetatable({}, {
	__index = function(_, name)
		if allowed[name] == nil then error("treegen reads the global " .. tostring(name), 2) end
		return allowed[name]
	end,
	__newindex = function(_, name) error("treegen writes the global " .. tostring(name), 2) end,
})
local chunk = assert(loadfile(ROOT .. "/mods/MAPGEN/grug_mapgen/wp40/treegen.lua"))
setfenv(chunk, env)
local T = chunk()
check(type(T) == "table" and type(T.generate) == "function", "module returns the API")
local REF = dofile(ROOT .. "/tools/r47_tb/reference.lua")

-- The digest of write_reference.js.
local M = 2147483647
local KIND = {trunk = 1, quarter = 2, base = 3, branch = 4, twig = 5, leaves = 6, fruit = 7}
local function new_digest() return {h1 = 0, h2 = 0} end
local function feed(d, v)
	d.h1 = (d.h1 * 1000003 + v + 1000) % M
	d.h2 = (d.h2 * 69069 + v + 1000) % M
end
local function tree_digest(tree)
	local d = new_digest()
	for i = 1, #tree.nodes do
		local n = tree.nodes[i]
		local code = KIND[n.kind]
		if code == nil then error("unknown kind " .. tostring(n.kind)) end
		feed(d, n.x); feed(d, n.y); feed(d, n.z); feed(d, code); feed(d, n.rot)
	end
	for i = 1, #tree.roots do
		local r = tree.roots[i]
		feed(d, r[1]); feed(d, r[2]); feed(d, r[3])
	end
	return #tree.nodes .. "/" .. #tree.roots .. "/" .. d.h1 .. "/" .. d.h2
end
local function serialise(tree)
	local lines = {}
	for i = 1, #tree.nodes do
		local n = tree.nodes[i]
		lines[#lines + 1] = n.x .. " " .. n.y .. " " .. n.z .. " " .. n.kind .. " " .. n.rot
	end
	for i = 1, #tree.roots do
		local r = tree.roots[i]
		lines[#lines + 1] = "root " .. r[1] .. " " .. r[2] .. " " .. r[3]
	end
	return table.concat(lines, "\n") .. "\n"
end
local function bumpy(seed)
	local s = ((seed % 1000) + 1000) % 1000
	return function(x, y, z)
		local r = ((x + 50) * 7919 + (z + 50) * 104729 + s * 31) % 7
		return y < (r == 0 and -1 or (r == 1 and 1 or 0))
	end
end
local function flat(_, y, _) return y < 0 end

-- B. the source
do
	local handle = assert(io.open(ROOT .. "/tools/r46_tree/concept/treegen.js", "rb"))
	local bytes = handle:read("*a")
	handle:close()
	local d = new_digest()
	for i = 1, #bytes do feed(d, bytes:byte(i)) end
	check(#bytes .. "/" .. d.h1 .. "/" .. d.h2 == REF.source,
		"treegen.js changed since the reference: port the change, then node tools/r47_tb/write_reference.js")
end

-- C. per seed
local rooted = {}
for _, sp in ipairs(REF.rooted) do rooted[sp] = true end
check(#T.ORDER == 8, "eight species")
local trees = 0
for _, sp in ipairs(T.ORDER) do
	local flat_list, bumpy_list = REF.flat[sp], REF.bumpy[sp]
	check(flat_list ~= nil and #flat_list == #REF.seeds, sp .. " has a flat reference")
	check((rooted[sp] == true) == (bumpy_list ~= nil), sp .. " bumpy reference only for rooted species")
	for i, seed in ipairs(REF.seeds) do
		local got = tree_digest(T.generate(sp, seed))
		check(got == flat_list[i], sp .. " seed " .. seed .. " flat: " .. got .. " vs JS " .. flat_list[i])
		local asked = 0
		local ground = bumpy(seed)
		local counted = function(x, y, z) asked = asked + 1; return ground(x, y, z) end
		local rough = tree_digest(T.generate(sp, seed, counted))
		if rooted[sp] then
			check(rough == bumpy_list[i], sp .. " seed " .. seed .. " bumpy: " .. rough .. " vs JS " .. bumpy_list[i])
		else
			check(asked == 0 and rough == got, sp .. " seed " .. seed .. " asks the ground")
		end
		trees = trees + 2
	end
end

-- D. full lists
for _, f in ipairs(REF.full) do
	local text = serialise(T.generate(f.species, f.seed, f.ground == "bumpy" and bumpy(f.seed) or nil))
	if text ~= f.text then
		local line, a, b = 1, 1, 1
		while true do
			local ea, eb = text:find("\n", a, true), f.text:find("\n", b, true)
			local la, lb = ea and text:sub(a, ea - 1), eb and f.text:sub(b, eb - 1)
			if la ~= lb then
				print("  first difference at line " .. line .. ": Lua " .. tostring(la) .. " | JS " .. tostring(lb))
				break
			end
			if not ea then break end
			a, b, line = ea + 1, eb + 1, line + 1
		end
	end
	check(text == f.text, "full list " .. f.species .. " " .. f.seed .. " " .. f.ground)
end

-- E. root study
for _, st in ipairs(REF.study) do
	local got = tree_digest(T.root_study(st.ground == "bumpy" and bumpy(st.bumpy_seed) or flat, st.w, st.specs))
	check(got == st.digest, "root study " .. st.ground .. " " .. st.w .. ": " .. got .. " vs JS " .. st.digest)
end

-- F. seed range
for _, sp in ipairs(T.ORDER) do
	for _, pair in ipairs(REF.same) do
		check(tree_digest(T.generate(sp, pair[1])) == tree_digest(T.generate(sp, pair[2])),
			sp .. " seeds " .. pair[1] .. " and " .. pair[2] .. " give the same tree")
	end
end
check(tree_digest(T.generate("apple", 1)) ~= tree_digest(T.generate("apple", 2)), "neighbouring seeds differ")
check(not pcall(T.generate, "oak", 1), "an unknown species is refused")

if failures > 0 then
	error(failures .. " FAILURES of " .. checks .. " checks", 0)
end
print("PASS r47_tb: " .. checks .. " checks, " .. trees .. " trees (" .. #REF.seeds .. " seeds x " ..
	#T.ORDER .. " species, flat and bumpy ground) equal the JS reference")

if TIME then
	local clock = os.clock
	print(string.format("%-11s %8s %8s %6s", "species", "mean ms", "worst ms", "trees"))
	local set_species = {}
	for _, sp in ipairs(T.ORDER) do
		local sum, worst = 0, 0
		for _, seed in ipairs(REF.seeds) do
			local started = clock()
			T.generate(sp, seed)
			local took = clock() - started
			sum = sum + took
			if took > worst then worst = took end
		end
		print(string.format("%-11s %8.3f %8.3f %6d", sp, sum / #REF.seeds * 1000, worst * 1000, #REF.seeds))
		set_species[#set_species + 1] = sp
	end
	local started = clock()
	local count = 0
	for _, sp in ipairs(set_species) do
		for seed = 1, sp == "kapok" and 16 or 32 do
			T.generate(sp, seed)
			count = count + 1
		end
	end
	print(string.format("template set: %d trees in %.1f ms (%s)", count, (clock() - started) * 1000,
		jit and jit.version or _VERSION))
end
