-- Known-answer test for the WP13 character-visuals composition
-- (mods/PLAYER/grug_visuals/compose.lua, contract
-- docs/research/wp13-character-visuals-contract.md §2).
--
-- Plain Lua 5.1, no engine: the real `grug_gear` catalog is loaded against a
-- stub `core` the way tools/wp13/stub_registry.lua loads the vendored node
-- mods, and the real `compose.lua` is loaded on top of it. Nothing is
-- hand-listed -- the brackets, their tints and every armor item come out of
-- the shipped sources, so a retuned palette or a new armor line moves this
-- fixture with it.
--
-- What it proves, in order of the emitted rows:
--   1  compose is PURE: two structurally equal specs built independently
--      produce byte-identical texture strings, and composing the whole matrix
--      twice in a different order changes nothing.
--   2  compose is CACHED: a repeat call with an equal spec returns the SAME
--      table (identity, not equality) and the cache grows by exactly the number
--      of distinct keys.
--   3  COVERAGE: every race x art line x slot x bracket combination composes,
--      including the full 6 x 2 x 6 = 72 four-piece sets and every one of the
--      6 x 2 x 4 x 6 = 288 single-piece looks.
--   4  the composed strings are WELL FORMED for the engine's texture-modifier
--      splitter (balanced parentheses, no trailing backslash, `[multiply`
--      always inside its own group).
--   5  every texture name a composition refers to EXISTS ON DISK.
--   6  stature stays inside the visual-only window and does not depend on gear.
--   7  an unknown race falls back to human; a spec with only a skin keeps it
--      and gets no stature.
--   8  the real grug_gear armor catalog indexes to the expected line/bracket.
--
-- Usage (from the repository root):
--   luajit         -e 'io.write(dofile("tools/wp13/character_visuals_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp13/character_visuals_kat.lua")("."))'
-- Both must print byte-identical output.

local M = {}

local GEAR = "mods/ITEMS/grug_gear/init.lua"
local COMPOSE = "mods/PLAYER/grug_visuals/compose.lua"
local TEXTURES = "mods/PLAYER/grug_visuals/textures/"

-- ---------------------------------------------------------------------------
-- a stub engine, no larger than these two sources actually touch
-- ---------------------------------------------------------------------------
local function load_sources(repo)
	local items = {}
	local logs = {}
	local noop = function() end

	local core_stub = {}
	core_stub.registered_items = items
	core_stub.registered_nodes = {}
	core_stub.registered_tools = {}
	core_stub.registered_craftitems = {}
	local function register(name, def)
		if type(name) ~= "string" or type(def) ~= "table" then
			return
		end
		if name:sub(1, 1) == ":" then
			name = name:sub(2)
		end
		items[name] = def
	end
	core_stub.register_tool = register
	core_stub.register_craftitem = register
	core_stub.register_node = register
	function core_stub.override_item(name, fields)
		local def = items[name]
		if not def then
			return
		end
		for key, value in pairs(fields) do
			def[key] = value
		end
	end
	function core_stub.log(level, message)
		logs[#logs + 1] = tostring(level) .. "\t" .. tostring(message)
	end
	function core_stub.colorize(_, text)
		return text
	end
	function core_stub.get_modpath()
		return repo
	end
	function core_stub.get_current_modname()
		return "grug_visuals"
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	-- Globals the two sources publish or read; handed back untouched after.
	local names = {"core", "minetest", "grug_gear", "grug_visuals"}
	local saved, had = {}, {}
	for _, name in ipairs(names) do
		had[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
	end
	rawset(_G, "core", core_stub)
	rawset(_G, "minetest", core_stub)
	rawset(_G, "grug_gear", nil)
	rawset(_G, "grug_visuals", {})

	local function restore()
		for _, name in ipairs(names) do
			rawset(_G, name, had[name] and saved[name] or nil)
		end
	end

	local ok, err = pcall(function()
		for _, path in ipairs({repo .. "/" .. GEAR, repo .. "/" .. COMPOSE}) do
			local chunk, load_err = loadfile(path)
			if not chunk then
				error("cannot load " .. path .. ": " .. tostring(load_err), 0)
			end
			chunk()
		end
	end)
	if not ok then
		restore()
		error(err, 0)
	end

	-- The stub globals STAY INSTALLED while the fixture runs: compose.lua reads
	-- `grug_gear` and `core` the way every mod in this tree does, and the point
	-- of the fixture is to exercise the shipped file unmodified. `restore` puts
	-- the interpreter back the way it was found.
	local visuals = rawget(_G, "grug_visuals")
	visuals._kat_logs = logs
	visuals._kat_items = items
	visuals._kat_gear = rawget(_G, "grug_gear")
	visuals._kat_restore = restore
	return visuals
end

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------
local function sorted_keys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function file_exists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

-- The engine splits a texture string on TOP-LEVEL `^` while tracking
-- parentheses (src/client/imagesource.cpp). A malformed string is a
-- client-side error with nothing at all in the server log, so the shape is
-- checked here instead: balanced parentheses, no trailing backslash, and every
-- `[multiply` inside a group so it cannot reach back over the base skin.
local function well_formed(texture)
	local depth = 0
	for index = 1, #texture do
		local char = texture:sub(index, index)
		if char == "(" then
			depth = depth + 1
		elseif char == ")" then
			depth = depth - 1
			if depth < 0 then
				return false, "unbalanced ')'"
			end
		end
	end
	if depth ~= 0 then
		return false, "unbalanced '('"
	end
	if texture:sub(-1) == "\\" then
		return false, "trailing backslash"
	end
	local scan = 1
	while true do
		-- PLAIN search, so the needle is the literal text "^[multiply" -- no
		-- `%` escape. It used to carry one, which made the needle a string that
		-- can never occur and this entire loop dead code.
		local at = texture:find("^[multiply", scan, true)
		if not at then
			break
		end
		-- The modifier must sit inside a group: the character before its `^`
		-- run is either "(" or part of the overlay name inside one.
		local before = texture:sub(1, at - 1)
		local opens = select(2, before:gsub("%(", ""))
		local closes = select(2, before:gsub("%)", ""))
		if opens <= closes then
			return false, "[multiply outside a group"
		end
		scan = at + 1
	end
	return true, nil
end

-- The malformed strings `well_formed` MUST reject, with the reason it must
-- give. A checker that accepts everything looks exactly like a checker that has
-- nothing to complain about, so this corpus is what keeps it honest: the
-- `[multiply` case is the one that went dead when its needle carried a pattern
-- escape into a plain search.
local MALFORMED = {
	{"skin.png^overlay.png^[multiply:#ffffff", "[multiply outside a group"},
	{"skin.png^(overlay.png^[multiply:#ffffff", "unbalanced '('"},
	{"skin.png^overlay.png)", "unbalanced ')'"},
	{"skin.png^(overlay.png^[multiply:#ffffff)\\", "trailing backslash"},
}

-- Every `<name>.png` a composition mentions.
local function texture_names(texture)
	local names = {}
	for name in texture:gmatch("[%w_%.%-]+%.png") do
		names[#names + 1] = name
	end
	return names
end

-- ---------------------------------------------------------------------------
-- the fixture
-- ---------------------------------------------------------------------------
function M.run(repo)
	repo = repo or "."
	local V = load_sources(repo)
	local ok, result = pcall(M.body, repo, V)
	V._kat_restore()
	if not ok then
		error(result, 0)
	end
	return result
end

function M.body(repo, V)
	local gear = V._kat_gear
	local out = {}
	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local failures = {}
	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end

	local races = sorted_keys(V.RACES)
	local lines = V.LINES
	local slots = V.SLOTS
	local brackets = #gear.BRACKETS

	row("wp13_cv_inputs", #races, #lines, #slots, brackets,
		table.concat(races, ","), table.concat(lines, ","),
		table.concat(slots, ","), table.concat(gear.BRACKET_TINT, ","))

	-- 8. the real catalog indexes the way the equip groups say it does
	local indexed = V.index_armor(V._kat_items)
	local by_line = {}
	local by_slot = {}
	for name, entry in pairs(V.armor_appearance) do
		by_line[entry.line] = (by_line[entry.line] or 0) + 1
		by_slot[entry.slot] = (by_slot[entry.slot] or 0) + 1
		check(name:find(entry.slot, 1, true) ~= nil,
			"indexed slot " .. entry.slot .. " not in item name " .. name)
		check(entry.bracket >= 1 and entry.bracket <= brackets,
			"indexed bracket out of range for " .. name)
	end
	local line_row = {}
	for _, key in ipairs(sorted_keys(by_line)) do
		line_row[#line_row + 1] = key .. "=" .. by_line[key]
	end
	local slot_row = {}
	for _, key in ipairs(sorted_keys(by_slot)) do
		slot_row[#slot_row + 1] = key .. "=" .. by_slot[key]
	end
	row("wp13_cv_index", indexed, table.concat(line_row, ","),
		table.concat(slot_row, ","))

	-- One concrete round trip through the real catalog: a full metal set of
	-- bracket 3 named by ITEM, not by shorthand.
	local by_item = V.compose({race = "dwarf", armor = {
		head = "grug_gear:head_metal_b3", chest = "grug_gear:chest_metal_b3",
		legs = "grug_gear:legs_metal_b3", feet = "grug_gear:feet_metal_b3"}})
	local by_line_spec = V.compose({race = "dwarf", armor_line = "metal",
		bracket = 3})
	check(by_item.textures[1] == by_line_spec.textures[1],
		"item-named set and armor_line shorthand disagree")
	row("wp13_cv_roundtrip", by_item.textures[1])

	-- `torso` is the contract's spelling of `chest`.
	local torso = V.compose({race = "dwarf",
		armor = {torso = "grug_gear:chest_metal_b3"}})
	local chest = V.compose({race = "dwarf",
		armor = {chest = "grug_gear:chest_metal_b3"}})
	check(torso == chest, "armor.torso is not armor.chest")

	-- 3+4+5. the whole matrix, in a fixed order, hashed into one digest
	local cache_before = 0
	for _ in pairs(V.cache) do
		cache_before = cache_before + 1
	end
	local seen_textures = {}
	local combos = 0
	local corpus = {}
	local function compose_case(spec)
		local result = V.compose(spec)
		combos = combos + 1
		local texture = result.textures[1]
		local ok, why = well_formed(texture)
		check(ok, "malformed texture: " .. tostring(why) .. " in " .. texture)
		for _, name in ipairs(texture_names(texture)) do
			seen_textures[name] = true
		end
		corpus[#corpus + 1] = result.key .. "\t" .. texture
		return result
	end

	for _, race in ipairs(races) do
		-- bare
		compose_case({race = race})
		for _, line in ipairs(lines) do
			for bracket = 1, brackets do
				-- full set
				local full = compose_case({race = race, armor_line = line,
					bracket = bracket})
				-- the same set named per item, where the catalog has one
				for _, slot in ipairs(slots) do
					compose_case({race = race, armor = {[slot] =
						"grug_gear:" .. slot .. "_" .. line .. "_b" .. bracket}})
				end
				-- 6. stature never depends on gear
				local bare = V.compose({race = race})
				check(full.visual_size == bare.visual_size,
					"stature changed with armor for " .. race)
			end
		end
	end

	-- 1. purity: the same matrix again, in reverse, must produce the same rows
	local replay = {}
	for index = #races, 1, -1 do
		local race = races[index]
		replay[#replay + 1] = V.compose({race = race}).textures[1]
		for line_index = #lines, 1, -1 do
			for bracket = brackets, 1, -1 do
				replay[#replay + 1] = V.compose({race = race,
					armor_line = lines[line_index],
					bracket = bracket}).textures[1]
			end
		end
	end
	local replay_ok = true
	for index = 1, #replay do
		if type(replay[index]) ~= "string" then
			replay_ok = false
		end
	end
	check(replay_ok, "replay produced a non-string")

	-- Two INDEPENDENTLY BUILT equal specs must hit the same cache entry.
	local first = V.compose({race = "elf", armor_line = "cloth", bracket = 2,
		weapon = "grug_gear:staff_b2"})
	local second = V.compose({race = "elf", armor_line = "cloth", bracket = 2,
		weapon = "grug_gear:staff_b2"})
	check(first == second, "compose is not cached by key (different tables)")
	check(first.key == second.key, "compose keys differ for equal specs")

	-- ... and the level shorthand must land on the same bracket as the number.
	local by_level = V.compose({race = "elf", armor_line = "cloth", level = 17,
		weapon_family = "staff"})
	check(by_level == first,
		"level 17 did not resolve to bracket 2 / staff_b2")

	local cache_after = 0
	for _ in pairs(V.cache) do
		cache_after = cache_after + 1
	end
	check(cache_after > cache_before, "nothing was cached at all")

	table.sort(corpus)
	local digest = 5381
	local joined = table.concat(corpus, "\n")
	for index = 1, #joined do
		-- djb2 in double arithmetic, kept well inside 2^53 by the modulo.
		digest = (digest * 33 + joined:byte(index)) % 4294967296
	end
	row("wp13_cv_matrix", combos, #corpus, cache_after - cache_before,
		string.format("%010d", digest))

	-- 4b. the shape checker itself: it must REJECT each malformed string, with
	-- the reason it is malformed for.
	local rejected = {}
	for index = 1, #MALFORMED do
		local texture, reason = MALFORMED[index][1], MALFORMED[index][2]
		local ok, why = well_formed(texture)
		check(ok == false, "well_formed accepted a malformed texture: " .. texture)
		check(why == reason, "well_formed gave \"" .. tostring(why) ..
			"\" for " .. texture .. ", expected \"" .. reason .. "\"")
		rejected[#rejected + 1] = tostring(why)
	end
	-- ... and it must still accept a real composition.
	check(well_formed(by_item.textures[1]) == true,
		"well_formed rejected a real composition")
	row("wp13_cv_shapecheck", #MALFORMED, table.concat(rejected, ";"))

	-- 5. every texture the matrix named is on disk
	local missing = {}
	for _, name in ipairs(sorted_keys(seen_textures)) do
		if not file_exists(repo .. "/" .. TEXTURES .. name) then
			missing[#missing + 1] = name
		end
	end
	check(#missing == 0,
		"texture(s) missing on disk: " .. table.concat(missing, ", "))
	row("wp13_cv_textures", #sorted_keys(seen_textures), #missing,
		table.concat(sorted_keys(seen_textures), ","))

	-- 6. the stature window, and the exact per-race values
	local stature = {}
	for _, race in ipairs(races) do
		local size = V.RACES[race].size
		for _, axis in ipairs({"x", "y", "z"}) do
			check(size[axis] >= V.STATURE_MIN and size[axis] <= V.STATURE_MAX,
				"stature of " .. race .. " outside the window")
		end
		stature[#stature + 1] = string.format("%s=%.2f/%.2f/%.2f", race,
			size.x, size.y, size.z)
	end
	row("wp13_cv_stature", string.format("%.2f", V.STATURE_MIN),
		string.format("%.2f", V.STATURE_MAX), table.concat(stature, ","))

	-- 7. fallbacks
	local unknown = V.compose({race = "gnome"})
	local human = V.compose({race = "human"})
	check(unknown == human, "unknown race did not fall back to human")
	local none = V.compose({})
	check(none == human, "a raceless spec did not fall back to human")
	local skin_only = V.compose({skin = "grug_mobs_mirefolk.png"})
	check(skin_only.textures[1] == "grug_mobs_mirefolk.png",
		"a skin-only spec did not keep its skin")
	check(skin_only.visual_size == nil,
		"a skin-only spec invented a stature")
	-- exactly one warning, however often the unknown race is asked for
	V.compose({race = "gnome"})
	V.compose({race = "gnome", armor_line = "metal"})
	local warnings = 0
	for _, entry in ipairs(V._kat_logs) do
		if entry:find("unknown race", 1, true) then
			warnings = warnings + 1
		end
	end
	check(warnings == 1, "the unknown-race warning fired " .. warnings ..
		" times, expected once")
	row("wp13_cv_fallback", unknown.key, warnings,
		skin_only.textures[1], tostring(skin_only.visual_size))

	-- weapons
	local unarmed = V.compose({race = "orc"})
	check(unarmed.weapon == nil, "a bare spec produced a weapon")
	local armed = V.compose({race = "orc", weapon = "grug_gear:sword_b1"})
	check(armed.weapon == "grug_gear:sword_b1", "weapon not passed through")
	check(armed.textures[1] == unarmed.textures[1],
		"the weapon changed the skin")
	local family = V.compose({race = "orc", weapon_family = "sword",
		level = 55})
	check(family.weapon == "grug_gear:sword_b6",
		"weapon_family at level 55 is not the sixth bracket")
	check(gear.get_price(family.weapon) ~= nil,
		"weapon_family built a name grug_gear never registered")
	row("wp13_cv_weapon", tostring(unarmed.weapon), armed.weapon, family.weapon)

	table.sort(failures)
	row("wp13_cv_result", #failures == 0 and "PASS" or "FAIL", #failures)
	for _, message in ipairs(failures) do
		row("wp13_cv_failure", message)
	end
	return table.concat(out, "\n") .. "\n"
end

return function(repo)
	return M.run(repo)
end
