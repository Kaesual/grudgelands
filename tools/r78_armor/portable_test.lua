-- Round 78 lane ARMOR portable test (LuaJIT): armor ratings with one decimal
-- inside, shown x10 as whole numbers (round78-plan.md ruling 12, §4 ARMOR).
--
-- Loads the REAL grug_gear (init.lua with its sub-files) and grug_quality's
-- init.lua under a permissive engine stub with ItemStack metadata, and
-- grug_core's armor_k and armor_reduction cut out of combat.lua; checks:
--   A. grug_gear.format_armor: x10, rounded to a whole number;
--   B. every registered piece: its rating is the set total's share rounded
--      to 0.1, at least 1.0, and its baked line shows it x10; the per-stack
--      path (describe_stack_base) agrees at every item level 1-70; the
--      shield is the rounded sum of the same-ilvl metal pieces;
--   C. the expected results of the plan (cloth, leather and metal at 60,
--      cloth at 1) and, for every line at every tier's base and cap and at
--      65 and 70, the reduction against a same-level attacker (level capped
--      at 60) moves only by rounding against 0.76.2's whole-point pieces;
--   D. the floor: no piece below 1.0, the low cloth pieces sit on it;
--   E. enchants: stored values keep one decimal, the tooltip, the
--      format_enchant_value labels (station, enchant list) show them x10;
--   F. the other display sites name the helper and no rating format is
--      left (the Character page, the abilities, the talent text, the
--      elixirs, the food row); the Help formula in shown units equals the
--      combat formula.
--
--   luajit tools/r78_armor/portable_test.lua [REPO] [--table]
-- `--table` also prints the before/after table of C. Prints
-- "R78 ARMOR PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local ROOT = arg and arg[1] or "."
local SHOW_TABLE = arg and arg[2] == "--table"
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read_file(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local function has(text, needle) return text:find(needle, 1, true) ~= nil end

------------------------------------------------------------------------------
-- Engine stub (the r45_il pattern).
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function()
		return function() end
	end})
end
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
}
local current_mod = "grug_gear"
local serial = {}
local mods_loaded = {}
core = permissive({
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do registered[name][key] = value end
	end,
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
})
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({})
grug_inventory = permissive({})
grug_jobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})

local function new_meta()
	local fields = {}
	local meta = {fields = fields}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = value end
	end
	function meta:get_int(key) return math.floor(tonumber(fields[key]) or 0) end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
ItemStack = function(name)
	local meta = new_meta()
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_count() return 1 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return 0 end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	return stack
end
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	return {next = function(_, low, high)
		state = (state * 48271) % 2147483647
		return low + state % (high - low + 1)
	end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
do
	local source = read_file(ROOT .. "/mods/CORE/grug_core/combat.lua")
	for _, name in ipairs({"armor_k%(attacker_level%)", "armor_reduction%(raw_rating, attacker_level, cap%)"}) do
		local body = source:match("(function grug_core%." .. name .. ".-\nend)\n")
		check(body ~= nil, "combat.lua has grug_core." .. name)
		assert(loadstring(body))()
	end
end
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
for _, fn in ipairs(mods_loaded) do fn() end

local fmt = grug_gear.format_armor
local function tenth(value) return math.floor(value * 10 + 0.5) / 10 end
local function is_tenth(value) return math.abs(value * 10 - math.floor(value * 10 + 0.5)) < 1e-6 end

-- The design line (grug_gear ARMOR_LINES) and split, written out again: the
-- fixture's own copy of the formula, not the game's.
local LINES = {
	metal = {base = 5.6, per = 0.86667},
	leather = {base = 3.2667, per = 0.64444},
	cloth = {base = 2.3333, per = 0.22222},
}
local LINE_ORDER = {"cloth", "leather", "metal"}
local SHARES = {head = 0.22, chest = 0.35, legs = 0.27, feet = 0.16}
local SLOT_ORDER = {"head", "chest", "legs", "feet"}
local function total_at(line, ilvl) return LINES[line].base + LINES[line].per * ilvl end
local function new_piece(line, slot, ilvl)
	return math.max(1, tenth(total_at(line, ilvl) * SHARES[slot]))
end
local function old_piece(line, slot, ilvl) -- 0.76.2: whole points, at least 1
	return math.max(1, math.floor(total_at(line, ilvl) * SHARES[slot] + 0.5))
end
local function set_of(piece, line, ilvl)
	local sum = 0
	for _, slot in ipairs(SLOT_ORDER) do sum = sum + piece(line, slot, ilvl) end
	return sum
end

------------------------------------------------------------------------------
-- A. The display helper.
------------------------------------------------------------------------------
eq(fmt(5.5), "55", "A 5.5 shows 55")
eq(fmt(15.6), "156", "A 15.6 shows 156")
eq(fmt(9.2 + 14.7 + 11.3 + 6.7), "419", "A a float-noisy 41.9 shows 419")
eq(fmt(0), "0", "A 0 shows 0")
eq(fmt(nil), "0", "A nothing shows 0")
eq(fmt(25), "250", "A a whole 25 shows 250")
eq(fmt(10.25), "103", "A a finer value rounds to the whole shown number")
eq(fmt(57.7), "577", "A 57.7 shows 577")

------------------------------------------------------------------------------
-- B. Every registered piece, the per-stack path and the shield.
------------------------------------------------------------------------------
do
	local count, bad = 0, {}
	for bracket, br in ipairs(grug_gear.BRACKETS) do
		for _, line in ipairs(LINE_ORDER) do
			for _, slot in ipairs(SLOT_ORDER) do
				local name = grug_gear.armor_item(slot, line, bracket)
				local def = registered[name]
				local want = new_piece(line, slot, br.ilvl)
				count = count + 1
				if not (def and math.abs(def._grug_armor - want) < 1e-9 and
						is_tenth(def._grug_armor) and
						has(def.description, "\n" .. fmt(want) .. " armor rating\n")) then
					bad[#bad + 1] = name .. "=" .. tostring(def and def._grug_armor)
				end
			end
		end
		local shield = registered["grug_gear:shield_" .. grug_gear.MATERIALS[bracket].metal.key]
		local want = tenth(set_of(new_piece, "metal", br.ilvl))
		check(shield and shield._grug_armor == want and
			has(shield.description, "\n" .. fmt(want) .. " armor rating\n"),
			("B T%d shield is the metal set %s, shown %s"):format(bracket, want, fmt(want)))
	end
	eq(count, 72, "B 72 armor pieces")
	check(#bad == 0, "B every piece is its share to 0.1, shown x10: " .. table.concat(bad, ", "))
end
do
	local bad = {}
	for _, line in ipairs(LINE_ORDER) do
		for _, slot in ipairs(SLOT_ORDER) do
			local stack = ItemStack(grug_gear.armor_item(slot, line, 1))
			for ilvl = 1, 70 do
				local lines, stats = grug_gear.describe_stack_base(stack, ilvl)
				local want = new_piece(line, slot, ilvl)
				if math.abs(stats.armor - want) > 1e-9 or
						lines[#lines] ~= fmt(want) .. " armor rating" then
					bad[#bad + 1] = ("%s %s %d: %s"):format(line, slot, ilvl, tostring(stats.armor))
				end
			end
		end
	end
	check(#bad == 0, "B the per-stack rating at every item level 1-70: " ..
		table.concat(bad, ", "))
	local shield = ItemStack("grug_gear:shield_bronze")
	local lines, stats = grug_gear.describe_stack_base(shield, 60)
	eq(stats.armor, 57.7, "B an item-level-60 shield is the metal set 57.7")
	eq(lines[#lines], "577 armor rating", "B ...shown 577")
	-- A dropped piece's tooltip through grug_quality's one rebuild path.
	local robe = ItemStack(grug_gear.armor_item("chest", "cloth", 6))
	robe:get_meta():set_int("grug_ilvl", 60)
	grug_items.regenerate_description(robe)
	check(has(robe:get_meta():get_string("description"), "\n55 armor rating\n"),
		"B a T6 cloth robe at item level 60 shows 55 (ruling 12's example)")
end

------------------------------------------------------------------------------
-- C. The expected results and every reduction against 0.76.2.
------------------------------------------------------------------------------
local function reduction(rating, level) return grug_core.armor_reduction(rating, level, 0.70) end
local function game_set(line, ilvl)
	local sum = 0
	for _, slot in ipairs(SLOT_ORDER) do
		local _, stats = grug_gear.describe_stack_base(
			ItemStack(grug_gear.armor_item(slot, line, 1)), ilvl)
		sum = sum + stats.armor
	end
	return sum
end
do
	local expected = {
		{"cloth", 60, 15, 23.1, "156", 23.8},
		{"leather", 60, 42, 45.7, "419", 45.6},
		{"metal", 60, 58, 53.7, "577", 53.6},
		{"cloth", 1, 4, 16.3, "40", 16.3},
	}
	for _, row in ipairs(expected) do
		local line, ilvl = row[1], row[2]
		local old, new = set_of(old_piece, line, ilvl), game_set(line, ilvl)
		local old_red = math.floor(reduction(old, ilvl) * 1000 + 0.5) / 10
		local new_red = math.floor(reduction(new, ilvl) * 1000 + 0.5) / 10
		local label = ("C %s at %d"):format(line, ilvl)
		eq(old, row[3], label .. ": 0.76.2's set")
		eq(old_red, row[4], label .. ": 0.76.2's reduction")
		eq(fmt(new), row[5], label .. ": the shown set")
		eq(new_red, row[6], label .. ": the reduction")
	end
end
do
	local points = {}
	for _, br in ipairs(grug_gear.BRACKETS) do
		points[#points + 1] = br.ilvl
		points[#points + 1] = br.cap
	end
	points[#points + 1] = 65
	points[#points + 1] = 70
	if SHOW_TABLE then
		print("| Line | ilvl | Attacker | 0.76.2 set | Reduction | 0.78.0 set (shown) | Reduction | Change |")
		print("|---|---:|---:|---:|---:|---:|---:|---:|")
	end
	local worst = 0
	for _, line in ipairs(LINE_ORDER) do
		for _, ilvl in ipairs(points) do
			local level = math.min(ilvl, 60)
			local old, new = set_of(old_piece, line, ilvl), game_set(line, ilvl)
			local exact = total_at(line, ilvl)
			local k = grug_core.armor_k(level)
			local slope = k / ((exact + k) * (exact + k))
			local delta = reduction(new, level) - reduction(old, level)
			-- Within rounding: no more than four pieces' worth of the old
			-- half-point rounding (and the new 0.05) moves the reduction,
			-- and the new set stays within four pieces' 0.05 of the line,
			-- plus what the 1.0 floor lifts.
			local lift = 0
			for _, slot in ipairs(SLOT_ORDER) do
				lift = lift + math.max(0, 1 - exact * SHARES[slot])
			end
			check(math.abs(delta) <= slope * 4 * 0.55 + 1e-9,
				("C %s %d: the reduction moves only by rounding (%.2f pp)"):format(
					line, ilvl, delta * 100))
			check(new - exact <= 4 * 0.05 + lift + 1e-9 and exact - new <= 4 * 0.05 + 1e-9,
				("C %s %d: the set %.1f stays at the line %.2f"):format(line, ilvl, new, exact))
			if math.abs(delta) > math.abs(worst) then worst = delta end
			if SHOW_TABLE then
				print(("| %s | %d | %d | %d | %.1f %% | %.1f (%s) | %.1f %% | %+.1f pp |"):format(
					line, ilvl, level, old, reduction(old, level) * 100, new, fmt(new),
					reduction(new, level) * 100, delta * 100))
			end
		end
	end
	if SHOW_TABLE then print(("largest change: %+.2f pp"):format(worst * 100)) end
end

------------------------------------------------------------------------------
-- D. The floor.
------------------------------------------------------------------------------
do
	local low = true
	for _, line in ipairs(LINE_ORDER) do
		for _, slot in ipairs(SLOT_ORDER) do
			for ilvl = 1, 70 do
				local _, stats = grug_gear.describe_stack_base(
					ItemStack(grug_gear.armor_item(slot, line, 1)), ilvl)
				if stats.armor < 1 then low = false end
			end
		end
	end
	check(low, "D no piece below 1.0 at any item level")
	for _, slot in ipairs(SLOT_ORDER) do
		eq(registered[grug_gear.armor_item(slot, "cloth", 1)]._grug_armor, 1,
			"D the item-level-1 cloth " .. slot .. " sits on the floor")
	end
	eq(fmt(game_set("cloth", 1)), "40", "D the item-level-1 cloth set shows 40, as 0.76.2's 4")
end

------------------------------------------------------------------------------
-- E. Enchants: stored with one decimal, shown x10.
------------------------------------------------------------------------------
do
	eq(grug_items.enchant_value("armor_rating", 60, 6), 4.8, "E the stored T6 value keeps 4.8")
	eq(grug_items.enchant_value("armor_rating", 1, 1), 0.5, "E the minimum keeps 0.5")
	eq(grug_items.format_enchant_value("armor_rating", 4.8), "48", "E 4.8 shows 48")
	eq(grug_items.format_enchant_value("armor_rating", 0.5), "5", "E 0.5 shows 5")
	eq(grug_items.format_enchant_value("armor_rating", grug_items.enchant_top_value("armor_rating", 7)),
		"56", "E the T7 top 5.6 shows 56 (the station's \"up to\" label)")
	eq(grug_items.format_enchant_value("max_hp_percent", 4), "4.0", "E percentages keep one decimal")
	eq(grug_items.format_enchant_value("str", 19), "19", "E attributes stay whole")
	local stack = grug_items.make_stack(grug_gear.armor_item("chest", "metal", 6), 60,
		{{channel = "prefix", stat = "armor_rating"}})
	check(stack ~= nil, "E an enchanted metal chest is made")
	local affixes = grug_items.get_affixes(stack)
	eq(affixes[1] and affixes[1].value, 4.8, "E ...its enchant is stored as 4.8")
	eq(stack:get_meta():get_string("_grug_armor_rating"), "4.8",
		"E ...and its derived key keeps the stored unit")
	local text = stack:get_meta():get_string("description")
	check(has(text, "\nPrefix: +48 armor rating (T6)"), "E the tooltip shows +48 (T6)")
	check(has(text, "\n202 armor rating\n"), "E ...below the piece's own 20.2 shown 202")
	local _, stats = grug_gear.describe_stack_base(stack, 60)
	eq(stats.armor, 20.2, "E the piece's base rating is untouched by the enchant")
end

------------------------------------------------------------------------------
-- F. The other display sites and the Help formula.
------------------------------------------------------------------------------
do
	local sites = {
		{"mods/PLAYER/grug_inventory/pages.lua", "\"Armor: \" .. grug_gear.format_armor(armor.result)"},
		{"mods/PLAYER/grug_abilities/kits_warrior.lua", "grug_gear.format_armor(v.armor)"},
		{"mods/PLAYER/grug_abilities/kits_mage.lua", "grug_gear.format_armor(values.armor)"},
		{"mods/PLAYER/grug_classes/talent_graph_ui.lua", "grug_gear.format_armor(graph.level_amount("},
		{"mods/ITEMS/grug_alchemy/recipes.lua", "grug_gear.format_armor(value)"},
		{"mods/ITEMS/grug_alchemy/effects.lua", "grug_gear.format_armor(value)"},
		{"mods/ITEMS/grug_food/init.lua", "grug_gear.format_armor(value)"},
	}
	for _, site in ipairs(sites) do
		local source = read_file(ROOT .. "/" .. site[1])
		check(has(source, site[2]), "F " .. site[1] .. " shows its rating through the helper")
		check(not source:find("%%[%.%d]*[df] armor"), "F " .. site[1] ..
			" formats no rating itself")
	end
	local help = read_file(ROOT .. "/mods/PLAYER/grug_inventory/help.lua")
	local base, per_level, above = help:match(
		"rating / %(rating %+ (%d+) %+ (%d+) x attacker level%) for attackers up to level 60 " ..
		"%(each level above 60 adds (%d+) more%)")
	check(base ~= nil, "F Help states the formula in shown units")
	base, per_level, above = tonumber(base), tonumber(per_level), tonumber(above)
	local same = base ~= nil
	for _, level in ipairs({1, 10, 30, 60, 61, 65, 70}) do
		for _, shown in ipairs({5, 40, 156, 419, 577, 1154}) do
			local k_shown = (base or 0) + (per_level or 0) * math.min(level, 60) +
				(above or 0) * math.max(level - 60, 0)
			local help_value = math.min(0.70, shown / (shown + k_shown))
			if math.abs(help_value - reduction(shown / 10, level)) > 1e-12 then same = false end
		end
	end
	check(same, "F Help's formula in shown units equals the combat formula")
end

if failures > 0 then
	print(("R78 ARMOR PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R78 ARMOR PORTABLE PASS checks=%d"):format(checks))
