-- Round 54 lane WEB portable test (LuaJIT): version 1 appearances in the web
-- export (tools/web_data/README.md, "Version 1 appearances").
--
--   luajit tools/r54_web/portable_test.lua [REPO]
--
-- Builds the export from the real game files (tools/web_data/build.lua) and
-- reads the version 1 bodies the old game composed (v1_samples.lua, written
-- by gen_v1_samples.lua from 0.53.1). Checks:
--   A  `appearance_v1`: version 1, its byte caps and depth, `armor_files`
--      sorted, unique, PNG names, none of them a current armour file or
--      any file of `texture_files` (Round 54 INTEG removed them all);
--   S  the samples: every body within version 1's cap and depth, no
--      top-level modifier; every file a body names is in `armor_files` or a
--      current texture file; the files the samples name for armour are
--      exactly `armor_files` (the list is complete and has nothing extra);
--   R  the README's rule (split the body at its top-level `^`, drop every
--      part naming a file of `armor_files`, join the rest) gives exactly the
--      race look the game composes today for that race and look, hairless
--      under a dropped helmet; it parses under the current texture grammar,
--      names only current texture files and stays within the current cap;
--   B  every race's `bare_body` parses under the grammar with current files;
--   F  the fallback: a body the rule rejects (too long, nested deeper than
--      version 1, unbalanced) or whose result does not validate (an unknown
--      file) draws the race's `bare_body`;
--   V  the two whole version 1 values: `"v":1`, within version 1's JSON cap;
--   N  a version 2 composition (every line and grade, enchanted, broken)
--      never names a file of `armor_files`.
--   T  the handoff's test character (test_character.json, scene.lua) is
--      current (gen_test_character.lua --check).
-- Prints "R54 WEB PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(got, want, label)
	return check(got == want, label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end

local web_data = dofile(ROOT .. "/tools/web_data/build.lua")
local data = web_data.build(ROOT)
local gv = grug_visuals
local samples = dofile(ROOT .. "/tools/r54_web/v1_samples.lua")
local v1 = data.appearance_v1
local grammar = data.texture_grammar

local function files_of(text)
	local out = {}
	for name in text:gmatch("[a-z0-9_]+%.png") do out[#out + 1] = name end
	return out
end

local current = {}
for _, entry in ipairs(data.texture_files) do current[entry.name] = true end

-- A. The block.
check(type(v1) == "table", "A appearance_v1 present")
eq(v1.version, 1, "A version")
eq(v1.texture_max_bytes, 2048, "A version 1 texture cap")
eq(v1.json_max_bytes, 10240, "A version 1 JSON cap")
eq(v1.max_depth, 4, "A version 1 depth")
local legacy = {}
for index, name in ipairs(v1.armor_files) do
	check(name:match("^[a-z0-9_]+%.png$") ~= nil, "A file rule: " .. name)
	check(not legacy[name], "A unique: " .. name)
	check(index == 1 or v1.armor_files[index - 1] < name, "A sorted at " .. name)
	check(name:match("^grug_armor_") == nil, "A not a current armour file: " .. name)
	legacy[name] = true
end
for _, name in ipairs(v1.armor_files) do
	check(not current[name], "A removed from the game: " .. name)
end
eq(#v1.armor_files, 1 + #gv.LINES * #gv.SLOTS * #grug_gear.MATERIALS * 2, "A file count")

-- The rule of the README, as a website implements it.
local function split_top(text, max_depth)
	local parts, depth, start = {}, 0, 1
	for index = 1, #text do
		local char = text:sub(index, index)
		if char == "(" then
			depth = depth + 1
			if depth > max_depth then return nil end
		elseif char == ")" then
			depth = depth - 1
			if depth < 0 then return nil end
		elseif char == "^" and depth == 0 then
			parts[#parts + 1] = text:sub(start, index - 1)
			start = index + 1
		end
	end
	if depth ~= 0 then return nil end
	parts[#parts + 1] = text:sub(start)
	return parts
end

local function without_armor(body)
	if #body > v1.texture_max_bytes then return nil end
	local parts = split_top(body, v1.max_depth)
	if not parts then return nil end
	local kept = {}
	for _, part in ipairs(parts) do
		local armour = false
		for _, name in ipairs(files_of(part)) do
			armour = armour or legacy[name] == true
		end
		if not armour then kept[#kept + 1] = part end
	end
	return table.concat(kept, "^")
end

-- A bounded parser of the current grammar (texture_grammar, README).
local function parse(text)
	local pos, depth, max_seen = 1, 0, 0
	local function fail(why) error(why .. " at " .. pos, 0) end
	local function arg_ok(kind, value)
		local def = grammar.args[kind]
		if not def or not value:match(def.pattern) then return false end
		if kind == "int" then
			local n = tonumber(value)
			return n >= def.min and n <= def.max
		elseif kind == "file" then
			return #value <= def.max_length and current[value] == true
		end
		return true
	end
	local chain
	local function token()
		local s, e = text:find("^[^%^%(%)%[]+", pos)
		if not s then return "" end
		pos = e + 1
		return text:sub(s, e)
	end
	local function part(first)
		local char = text:sub(pos, pos)
		if char == "(" then
			pos = pos + 1
			depth = depth + 1
			if depth > grammar.max_depth then fail("too deep") end
			max_seen = math.max(max_seen, depth)
			chain()
			if text:sub(pos, pos) ~= ")" then fail("no )") end
			pos = pos + 1
			depth = depth - 1
		elseif char == "[" then
			if first then fail("modifier first") end
			pos = pos + 1
			local words = {}
			for word in (token() .. ":"):gmatch("([^:]*):") do words[#words + 1] = word end
			local kinds = grammar.modifiers[words[1]]
			if not kinds or #words - 1 ~= #kinds then fail("modifier " .. tostring(words[1])) end
			for index, kind in ipairs(kinds) do
				if not arg_ok(kind, words[index + 1]) then fail("argument " .. words[index + 1]) end
			end
		else
			local name = token()
			if not name:match("^[a-z0-9_]+%.png$") or not current[name] then fail("file " .. name) end
		end
	end
	function chain()
		part(true)
		while text:sub(pos, pos) == "^" do
			pos = pos + 1
			part(false)
		end
	end
	local ok, err = pcall(function()
		chain()
		if pos <= #text then fail("trailing") end
	end)
	return ok, err
end

-- S, R. The samples.
local named = {}
for _, sample in ipairs(samples.samples) do
	local label = sample.label
	check(#sample.body <= v1.texture_max_bytes, "S within the version 1 cap: " .. label)
	local parts = split_top(sample.body, v1.max_depth)
	if check(parts ~= nil, "S splits within depth 4: " .. label) then
		for _, part in ipairs(parts) do
			check(part:sub(1, 1) ~= "[", "S no top-level modifier: " .. label)
		end
	end
	for _, name in ipairs(files_of(sample.body)) do
		if legacy[name] then
			named[name] = true
		else
			check(current[name] == true, "S a current texture file: " .. name .. " (" .. label .. ")")
		end
	end
	local got = without_armor(sample.body)
	local want = gv.look_texture(sample.race, gv.normalize_look(sample.race, sample.look),
		{helmet = sample.helmet})
	eq(got, want, "R the race look: " .. label)
	if got then
		local ok, err = parse(got)
		check(ok, "R parses under the current grammar: " .. label .. " (" .. tostring(err) .. ")")
		check(#got <= data.appearance_limits.texture_max_bytes, "R within the cap: " .. label)
	end
end
for _, name in ipairs(v1.armor_files) do
	check(named[name], "S a sample names " .. name)
end

-- B. The fallback bodies.
for _, race in ipairs(data.races) do
	local ok, err = parse(race.bare_body)
	check(ok, "B bare_body parses: " .. race.id .. " (" .. tostring(err) .. ")")
	eq(race.bare_body, gv.look_texture(race.id, gv.normalize_look(race.id, nil), {}),
		"B bare_body is look 1 unworn: " .. race.id)
end

-- F. The fallback, as the README's rule ends.
local bare = {}
for _, race in ipairs(data.races) do bare[race.id] = race.bare_body end
local function shown_body(body, race)
	local got = without_armor(body)
	if got and parse(got) then
		return got
	end
	return bare[race] or bare.human
end
local look = "(grug_visuals_skin_mask.png^[multiply:#efcfb0)^grug_visuals_human_body.png"
check(parse(look), "F the synthetic look itself parses")
eq(shown_body(look, "human"), look, "F a valid body is kept")
local negatives = {
	{"too long", look .. ("^grug_visuals_human_body.png"):rep(80)},
	{"nested 5 deep", "(((((grug_visuals_human_body.png)))))^" .. look},
	{"an unbalanced (", "(grug_visuals_skin_mask.png^[multiply:#efcfb0^grug_visuals_human_body.png"},
	{"an unbalanced )", look .. ")"},
	{"an unknown file", look .. "^grug_visuals_no_such_layer.png"},
	{"a version 1 modifier outside an armour part", look .. "^(grug_visuals_human_body.png^[mask:" ..
		"grug_visuals_skin_mask.png)"},
}
for _, case in ipairs(negatives) do
	eq(shown_body(case[2], "dwarf"), bare.dwarf, "F " .. case[1] .. " draws bare_body")
end
eq(shown_body(negatives[2][2], "nobody"), bare.human, "F an unknown race draws human's bare_body")
check(#negatives[1][2] > v1.texture_max_bytes, "F the long body is over the cap")

-- V. The whole values.
for _, value in ipairs(samples.values) do
	check(value.json:sub(1, 7) == '{"v":1,', "V version 1: " .. value.label)
	check(#value.json <= v1.json_max_bytes, "V within the version 1 JSON cap: " .. value.label)
end

-- N. Version 2 never names a version 1 armour file.
gv.index_armor(core.registered_items)
for _, line in ipairs(gv.LINES) do
	for bracket, materials in ipairs(grug_gear.MATERIALS) do
		local armor, broken, enchant = {}, {}, {}
		for _, slot in ipairs(gv.SLOTS) do
			armor[slot] = "grug_gear:" .. slot .. "_" .. line .. "_" .. materials[line].key
			broken[slot] = slot == "chest"
			enchant[slot] = {prefix = "str", suffix = "dex"}
		end
		local result = gv.compose({race = "human", armor = armor, armor_broken = broken,
			armor_enchant = enchant})
		for _, text in ipairs({result.skin, result.armor}) do
			for _, name in ipairs(files_of(text)) do
				check(not legacy[name], "N version 2 names no version 1 file: " .. name)
			end
		end
		check(result.armor ~= gv.ARMOR_NONE, "N the set draws armour: " .. line .. bracket)
	end
end

-- T. The test character.
local status = os.execute("luajit " .. ROOT .. "/tools/r54_web/gen_test_character.lua " ..
	ROOT .. " --check >/dev/null")
check(status == 0 or status == true, "T test_character.json and scene.lua are current " ..
	"(run luajit tools/r54_web/gen_test_character.lua)")

if failures > 0 then
	error(("R54 WEB PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print("R54 WEB PORTABLE PASS checks=" .. checks)
