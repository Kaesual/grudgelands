-- Round 88 lane STATS portable test: the Character page's Stats mode (plan
-- ruling 8, mods/PLAYER/grug_inventory/stats.lua and pages.lua). Through the
-- Round 44 harness (the real sfinv, grug_inventory and grug_achievements)
-- with the REAL attribute, pool, crit and dodge formulas of
-- grug_classes/stats.lua and grug_core's pool, base-hit and armor functions
-- (cut from combat.lua), and grug_quality's equipment layer as a stand-in of
-- its own shape (the totals combat reads and the per-slot sources), it checks:
--   1. the list order per class (HP and mana or rage first, the attributes,
--      Armor and Dodge, Crit; no Damage reduction), the values the accessors
--      give, the separators, the attribute tooltips;
--   2. Maximum HP selected on open; a row click selects (runtime context,
--      re-sent, never stored); a mode button and the window's close reset it
--      (the close re-sends only when another stat was shown);
--   3. the detail: the name, the value, the sentence, Effect, Where it comes
--      from, the rule; the source lines add up to the shown value (pools by
--      their calculation, armor with the race factor), for every class bare
--      and geared, with talents and effects; an unknown source becomes an
--      "Other sources" line; a chance over the cap shows the cap line; the
--      Armor effects at the attacker levels −5, ±0, +5, +10;
--   4. the cloak picker in the gear box under the model, between the slot
--      columns and above the Scout's quiver rule, in every mode; its field
--      still handled; the Scout's Home line beside the quiver's one-line
--      total (fix round).
--
-- Usage (repo root): luajit tools/r88_stats/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)

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
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function near(actual, expected, label, tolerance)
	return check(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
		label .. (" (got %s, expected %s)"):format(tostring(actual), tostring(expected)))
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. ("%q"):format(part) .. ")")
end

-- Formspec sanity as the engine parses it (tools/r44_ch).
local function formspec_ok(fs, label)
	local piece, i = {}, 1
	while i <= #fs do
		local c = fs:sub(i, i)
		if c == "\\" then
			piece[#piece + 1] = fs:sub(i, i + 1)
			i = i + 1
		elseif c == "]" then
			if not table.concat(piece):match("^[%w_]+%[") then
				return check(false, label .. ": not an element before ] at " .. i)
			end
			piece = {}
		else
			piece[#piece + 1] = c
		end
		i = i + 1
	end
	return check(#piece == 0, label .. ": text after the last element")
end

--
-- The real formulas
--

-- grug_core's functions, cut from combat.lua by name.
local function cut_functions(path, names)
	local file = assert(io.open(repo .. path))
	local text = file:read("*a")
	file:close()
	for _, name in ipairs(names) do
		local body = text:match("\n(function grug_core%." .. name .. "%(.-\nend)\n")
		assert(body, "no grug_core." .. name .. " in " .. path)
		assert((loadstring or load)(body))()
	end
end
cut_functions("/mods/CORE/grug_core/combat.lua", {"base_pool", "baseline_weapon_damage",
	"baseline_melee_total", "armor_k", "armor_reduction"})

-- The classes' growth as registered (grug_classes init.lua, scout.lua).
for _, file in ipairs({"init.lua", "scout.lua"}) do
	local handle = assert(io.open(repo .. "/mods/PLAYER/grug_classes/" .. file))
	local text = handle:read("*a")
	handle:close()
	for id, growth in text:gmatch('id = "(%w+)",.-growth = (%b{})') do
		local class = grug_classes.registered_classes[id]
		if class then class.growth = assert((loadstring or load)("return " .. growth))() end
	end
end
for _, id in ipairs({"warrior", "mage", "priest", "scout"}) do
	check(grug_classes.registered_classes[id].growth ~= nil, id .. ": growth read")
end

-- Talents, effects, race and Sidestep per player (fixture state).
local T = {}
local function state(player)
	local name = player:get_player_name()
	T[name] = T[name] or {talents = {}, status = {}, absorb = {}, slots = {}, sidestep = 0}
	return T[name]
end
grug_classes.get_talent_bonus = function(player, key) return state(player).talents[key] or 0 end
grug_core.status_modifier_sum = function(player, key) return state(player).status[key] or 0 end
grug_core.absorb_modifier = function(player, key) return state(player).absorb[key] or 0 end
grug_core.get_race_perk = function(player, key)
	return key == "armor_rating_mult" and state(player).dwarf and 1.05 or nil
end
grug_classes.get_race_def = function(player)
	return state(player).dwarf and {name = "Dwarf"} or {name = "Human"}
end
grug_classes.get_scout_dodge_add = function(player) return state(player).sidestep end
grug_classes.get_scout_dodge_cap = function() return 30 end
grug_xp.get_level = function(player) return player.level end
grug_classes.on_level_change_talents = function() end
grug_core.register_on_equipment_change = function() end
dofile(repo .. "/mods/PLAYER/grug_classes/stats.lua")

-- grug_quality's layer in its shape (init.lua equipment_totals and the
-- overrides): the per-slot affixes come from the fixture's table.
local function totals(player)
	local out = {}
	for _, slot in ipairs(state(player).slots) do
		for key, value in pairs(slot.stats) do out[key] = (out[key] or 0) + value end
	end
	return out
end
grug_items = {
	get_equipment_slot_sources = function(player)
		local out = {}
		for index, slot in ipairs(state(player).slots) do
			local stats = {}
			for key, value in pairs(slot.stats) do stats[key] = value end
			out[index] = {list = slot.list, name = slot.name, stats = stats}
		end
		return out
	end,
	get_equipment_armor_rating_bonus = function(player) return state(player).shield or 0 end,
}
grug_classes.get_equipment_pool_percent = function(player, pool)
	local t = totals(player)
	return (pool == "hp" and t.max_hp_percent or pool == "mana" and t.max_mana_percent) or 0
end
local base_attributes = grug_classes.get_attributes
grug_classes.get_attributes = function(player)
	local a, t = base_attributes(player), totals(player)
	a.str, a.dex, a.int = a.str + (t.str or 0), a.dex + (t.dex or 0), a.int + (t.int or 0)
	a.str = a.str + (state(player).hidden_str or 0)
	return a
end
local crit_raw, dodge_raw = grug_classes.get_crit_chance_raw, grug_classes.get_dodge_chance_raw
grug_classes.get_crit_chance_raw = function(player)
	return crit_raw(player) + (totals(player).crit_percent or 0) / 100
end
grug_classes.get_dodge_chance_raw = function(player)
	return dodge_raw(player) + (totals(player).dodge_percent or 0) / 100
end
grug_core.get_armor_rating = function(player)
	local s = state(player)
	local total = grug_inventory.get_equipped_armor(player) + (totals(player).armor_rating or 0) +
		(s.shield or 0) + grug_classes.get_talent_bonus(player, "armor_percent_add") +
		grug_core.status_modifier_sum(player, "armor")
	local mult = grug_core.get_race_perk(player, "armor_rating_mult")
	if mult and total > 0 then total = total * mult end
	return total
end

-- Armor pieces with a base rating (grug_gear's _grug_armor).
local function armor_item(name, group, rank, armor, description)
	core.registered_items[name] = {description = description, stack_max = 1,
		groups = {grug_gear = 1, [group] = 1, grug_armor_class = rank}, _grug_armor = armor}
end
armor_item("r88:helm", "grug_equip_head", 3, 3.1, "Steel Helm")
armor_item("r88:plate", "grug_equip_chest", 3, 4.9, "Steel Chestplate")
armor_item("r88:hood", "grug_equip_head", 2, 1.8, "Heavy Hood")
core.registered_items["r88:battlebeat"] = {description = "Battlebeat\nA trinket", stack_max = 1,
	groups = {grug_gear = 1, grug_equip_trinket = 1}}
core.registered_items["r88:shield"] = {description = "Steel Shield", stack_max = 1,
	groups = {grug_gear = 1, grug_equip_offhand = 1, grug_shield = 1}}

local function equip(player, list, itemname, stats)
	H.put(player, list, 1, itemname)
	local slots = state(player).slots
	slots[#slots + 1] = {list = list, name = itemname, stats = stats or {}}
	grug_inventory.equipment_changed(player, list)
end

--
-- Helpers on the page
--

local sheet = grug_inventory.stat_sheet
local function entries(player)
	local out, ids = {}, {}
	for _, entry in ipairs(sheet.sheet(player)) do
		ids[#ids + 1] = entry == "gap" and "|" or entry.id
		if entry ~= "gap" then out[entry.id] = entry end
	end
	return out, table.concat(ids, " ")
end

-- The source lines' result: additions, a class or race factor, pool percents.
local function source_result(entry)
	if entry.id == "hp" or entry.id == "mana" then
		local base, factor, percent = 0, 1, 0
		for _, line in ipairs(entry.sources) do
			if line.kind == "base" then base = line.n
			elseif line.kind == "factor" then factor = line.n
			elseif line.kind == "percent" then percent = percent + line.n end
		end
		return math.floor(base * factor * (1 + percent / 100) + 0.5)
	end
	local sum, factor = 0, 1
	for _, line in ipairs(entry.sources) do
		if line.kind == "factor" then factor = line.n else sum = sum + line.n end
	end
	return sum * factor
end

local function sums_ok(player, label)
	local list = entries(player)
	for id, entry in pairs(list) do
		if id ~= "rage" then
			near(source_result(entry), entry.amount, label .. ": " .. id .. " sources add up", 1e-6)
		end
	end
end

local function other_lines(player)
	local n = 0
	for _, entry in pairs((entries(player))) do
		for _, line in ipairs(entry.sources) do
			if line[2] == "Other sources" or line[2] == "Other equipment" then n = n + 1 end
		end
	end
	return n
end

local function source_label(entry, label)
	for _, line in ipairs(entry.sources) do
		if line[2] == label then return line end
	end
	return nil
end

local function page(player, mode)
	local context = sfinv.get_or_create_context(player)
	context.page = "grug_inventory:character"
	context.grug_character_tab = mode
	H.context = context
	return sfinv.get_formspec(player, context)
end
local function nav(field, selected)
	return grug_core.ui.navigation_style(field, selected, 0, 0, 1, 1, true):match("^style%[[^%]]+%]")
end

local BOX_BOTTOM = grug_inventory.VIEW_GEOMETRY.top - 0.1

--
-- 1. The list per class
--

local LISTS = {
	warrior = "hp rage | str int dex | armor dodge | crit",
	mage = "hp mana | str int dex | armor dodge | crit",
	priest = "hp mana | str int dex | armor dodge | crit",
	scout = "hp mana | str int dex | armor dodge | crit",
}
for class_id, order in pairs(LISTS) do
	local player = H.player("l_" .. class_id, class_id, nil, 30)
	local list, ids = entries(player)
	eq(ids, order, class_id .. ": the list order")
	local hp = grug_classes.get_pool_breakdown(player, "hp").final
	eq(list.hp.value, tostring(hp), class_id .. ": Maximum HP from the pool accessor")
	local factor = ({warrior = 1.2, mage = 0.8, priest = 0.8, scout = 1})[class_id]
	eq(hp, math.floor(grug_core.base_pool(30) * factor + 0.5), class_id .. ": the class factor")
	local a = grug_classes.get_attributes(player)
	eq(list.str.value .. "/" .. list.int.value .. "/" .. list.dex.value,
		a.str .. "/" .. a.int .. "/" .. a.dex, class_id .. ": the attributes")
	eq(list.crit.value, sheet.pct(grug_classes.get_crit_chance(player) * 100, 1),
		class_id .. ": Crit from the accessor")
	eq(list.dodge.value, sheet.pct(grug_classes.get_dodge_chance(player) * 100, 1),
		class_id .. ": Dodge from the accessor")
	eq(list.armor.value, "0", class_id .. ": no armor bare")
	sums_ok(player, class_id .. " bare")
	eq(other_lines(player), 0, class_id .. " bare: every source known")
	local fs = page(player, nil)
	formspec_ok(fs, class_id .. " page")
	lacks(fs, "Damage reduction", class_id .. ": no Damage reduction row")
	for _, id in ipairs({"str", "int", "dex"}) do
		has(fs, "tooltip[grug_stat_" .. id .. ";", class_id .. ": the " .. id .. " row's tooltip")
	end
	lacks(fs, "tooltip[grug_stat_hp;", class_id .. ": no tooltip on a pool")
	-- Rows: a clear button over the name and the right-aligned value.
	has(fs, "button[10.00,1.30;4.35,0.50;grug_stat_hp;]", class_id .. ": the HP row's button")
	has(fs, "button[10.00,5.25;4.35,0.50;grug_stat_crit;]", class_id .. ": Crit last, after three gaps")
	has(fs, "halign=right", class_id .. ": the value right-aligned")
	eq(select(2, fs:gsub("box%[10%.15,[%d.]+;4%.05,0%.015;", "")), 3, class_id .. ": three separators")
end
-- Warrior numbers at 30: 97 Str, 10 Int, 39 Dex; rage 100.
local wl = entries(H.player("w30", "warrior", nil, 30))
eq(wl.str.value .. "/" .. wl.int.value .. "/" .. wl.dex.value, "97/10/39", "warrior 30: attributes")
eq(wl.rage.value, "100", "warrior: Maximum rage 100")
eq(wl.str.tip, "Strength: +9.7 melee damage per hit.", "warrior: the Strength tooltip")
local sl = entries(H.player("s30", "scout", nil, 30))
has(sl.str.tip, "no effect for Scouts", "scout: Strength does nothing")
has(sl.dex.tip, "melee and bow damage per hit", "scout: Dexterity hits")
eq(sl.str.effects[1][1], "–", "scout: Strength's effect is none")
local ml = entries(H.player("m30", "mage", nil, 30))
eq(ml.int.effects[1][1], "+9.7", "mage: spell power Int/10")
eq(wl.int.effects[1][1], "–", "warrior: no spell power")

--
-- 2. Selection
--

local w = H.player("sel", "warrior", nil, 30)
local fs = page(w, nil)
has(fs, nav("grug_stat_hp", true), "Maximum HP selected on open")
has(fs, nav("grug_stat_str", false), "Strength not selected")
has(fs, "label[14.70,1.65;Maximum HP]", "the detail names Maximum HP")
local sent = w.sent
check(H.click(w, {grug_stat_str = "", grug_cloak = "No cloak"}), "a row click is handled")
eq(H.context.grug_stat, "str", "the click selects Strength")
check(w.sent > sent, "... and re-sends the page")
has(w.formspec, nav("grug_stat_str", true), "Strength styled selected")
has(w.formspec, "label[14.70,1.65;Strength]", "the detail shows Strength")
eq(w:get_meta():get_string("grug_stat"), "", "the selection is runtime context only")
sent = w.sent
H.click(w, {quit = "true"})
eq(H.context.grug_stat, nil, "closing the window resets to Maximum HP")
check(w.sent > sent, "... re-sending the cached page")
has(w.formspec, nav("grug_stat_hp", true), "... which shows Maximum HP")
sent = w.sent
H.click(w, {quit = "true"})
eq(w.sent, sent, "a close with HP shown re-sends nothing")
H.click(w, {grug_stat_armor = ""})
H.click(w, {grug_character_effects = "Effects"})
H.click(w, {grug_character_stats = "Stats"})
eq(H.context.grug_stat, nil, "a mode switch re-enters the page: HP again")
sfinv.set_page(w, "grug_inventory:inventory")
H.context.grug_stat = "dex"
sfinv.set_page(w, "grug_inventory:character")
eq(H.context.grug_stat, nil, "entering the page from another tab: HP again")
H.click(w, {grug_stat_bogus = ""})
has(w.formspec, "label[14.70,1.65;Maximum HP]", "an unknown row falls back to HP")

--
-- 3. The detail and its sources
--

local entry = wl.armor
eq(#entry.effects, 4, "Armor: four attacker levels")
eq(entry.effects_note, "Less damage from an enemy of", "Armor: the effects' lead")
eq(entry.effects[1][2], "level 25", "Armor: level −5")
eq(entry.effects[2][2], "level 30, your level", "Armor: your level")
eq(entry.effects[4][2], "level 40", "Armor: level +10")
H.click(w, {grug_stat_armor = ""})
local armor_fs = w.formspec
has(armor_fs, "EFFECT", "the Effect section")
has(armor_fs, "WHERE IT COMES FROM", "the sources section")
has(armor_fs, "Reduction = rating ÷ (rating + 200 + 5 per attacker level)", "the Armor rule")
has(armor_fs, "350 against level 30", "... with its divisor at your level")
has(armor_fs, "drowning ignore armor", "... and what armor ignores")

-- A geared Dwarf Warrior with talents and effects.
local g = H.player("geared", "warrior", nil, 30)
local gs = state(g)
gs.dwarf = true
gs.talents = {armor_percent_add = 1.5, crit_chance_add = 2, max_hp_percent_add = 3}
gs.status = {armor = 0.8, crit_percent = 4.2, hp_pool_percent = 4}
gs.shield = 9.4
equip(g, "grug_head", "r88:helm", {str = 8, max_hp_percent = 2.8, armor_rating = 0.5})
equip(g, "grug_chest", "r88:plate", {str = 8})
equip(g, "grug_offhand", "r88:shield", {max_hp_percent = 2.8})
equip(g, "grug_trinket1", "r88:battlebeat", {crit_percent = 3})
local gl = entries(g)
eq(gl.str.value, "113", "geared: Strength 97 + 8 + 8")
has(source_label(gl.str, "Head · Steel Helm")[1], "+8", "geared: the helm's Strength line")
check(source_label(gl.str, "Chest · Steel Chestplate") ~= nil, "geared: the chest's line")
check(source_label(gl.armor, "Shield · Steel Shield") ~= nil, "geared: the shield's armor line")
eq(source_label(gl.armor, "Head · Steel Helm")[1], "+36", "geared: helm 3.1 + 0.5 shown ×10")
eq(source_label(gl.armor, "Dwarf race")[1], "× 1.05", "geared: the race factor")
check(source_label(gl.armor, "Talents") and source_label(gl.armor, "Effects (elixirs)"),
	"geared: talent and elixir armor")
check(source_label(gl.crit, "Trinket · Battlebeat") ~= nil, "geared: a trinket's Crit, first line of its name")
check(source_label(gl.hp, "Warrior class factor") and source_label(gl.hp, "Talents") and
	source_label(gl.hp, "Effects (food, elixirs)"), "geared: the HP calculation's lines")
near(gl.armor.amount, (3.1 + 4.9 + 0.5 + 9.4 + 1.5 + 0.8) * 1.05, "geared: the rating combat reads")
sums_ok(g, "geared")
eq(other_lines(g), 0, "geared: every source known")
local geared_fs = page(g, nil)
formspec_ok(geared_fs, "geared page")
has(geared_fs, "Head · Steel Helm", "geared: the slot · item line on the page")

-- An unknown source: the line that keeps the sum.
gs.hidden_str = 5
gl = entries(g)
eq(source_label(gl.str, "Other sources")[1], "+5", "an unknown +5 Strength shows as Other")
sums_ok(g, "with an unknown source")
gs.hidden_str = nil

-- Over the cap: the cap line.
gs.status.crit_percent = 40
gl = entries(g)
eq(gl.crit.value, "30 %", "Crit capped at 30 %")
check(source_label(gl.crit, "Above the 30 % cap") ~= nil, "the cap line")
sums_ok(g, "over the cap")
gs.status.crit_percent = 4.2

-- Every class with gear, talents and Sidestep.
for _, class_id in ipairs({"mage", "priest", "scout"}) do
	local p = H.player("g_" .. class_id, class_id, nil, 47)
	local ps = state(p)
	ps.talents = {dodge_chance_add = 3, max_mana_percent_add = 4}
	ps.absorb = {dodge_percent = 5}
	ps.sidestep = class_id == "scout" and 15 or 0
	equip(p, "grug_head", "r88:hood", {int = 7, max_mana_percent = 3.1, dodge_percent = 2.5})
	equip(p, "grug_trinket2", "r88:battlebeat", {dex = 6, max_hp_percent = 2})
	sums_ok(p, class_id .. " geared")
	eq(other_lines(p), 0, class_id .. " geared: every source known")
	formspec_ok(page(p, nil), class_id .. " geared page")
end
local priest = entries(H.player("g_priest", "priest", nil, 47))
has(priest.int.effects[2][2], "from the 7 Intelligence on your gear", "priest: support from gear Int")
local scout = entries(H.player("g_scout", "scout", nil, 47))
check(source_label(scout.dodge, "Sidestep") ~= nil, "scout: Sidestep's Dodge")

--
-- 4. The cloak picker in the gear box
--

for _, class_id in ipairs({"warrior", "scout"}) do
	local p = H.player("c_" .. class_id, class_id, nil, 30)
	for _, mode in ipairs({"stats", "effects", "achievements"}) do
		local cfs = page(p, mode)
		local label = class_id .. " " .. mode
		local x, y, cw, ch = cfs:match("dropdown%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_cloak;")
		x, y, cw, ch = tonumber(x), tonumber(y), tonumber(cw), tonumber(ch)
		check(x ~= nil, label .. ": the cloak picker")
		if x then
			check(x >= 1.5 and x + cw <= 8.05, label .. ": between the slot columns")
			local _, my, _, mh = cfs:match("model%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_preview;")
			check(tonumber(my) + tonumber(mh) <= y + 1e-6, label .. ": under the model")
			check(y + ch <= 6.7 - 0.25 + 1e-6, label .. ": above the quiver's rule")
		end
		has(cfs, "label[1.70,6.13;Cloak]", label .. ": its label")
		has(cfs, "tooltip[grug_cloak;Cloaks unlock through achievements.]", label .. ": its hint")
		eq(select(2, cfs:gsub("grug_cloak;", "")), 2, label .. ": one picker")
		has(cfs, "button[0.50,8.00;8.85,0.65;grug_character_home;", label .. ": Return home kept")
	end
end
-- The user (fix round): beside the Scout's quiver the Home line sits on the
-- quiver's row, right of its one-line total; the Warrior keeps it above the
-- button.
local qs = page(H.player("q_scout", "scout", nil, 30), "stats")
has(qs, "label[1.65,7.20;Quiver 0/500]", "scout: the quiver total on one line, the slot's middle")
-- Fix round 2: right-aligned to the inner right edge (where Return home
-- ends), in a box that starts right of the widest total and wraps a long name.
has(qs, "hypertext[4.10,6.75;5.25,0.90;;<global margin=0 valign=middle halign=right color=#eeeae1 size=16>Home: Ironhold Inn]",
	"scout: Home right-aligned on the quiver's row")
has(qs, "button[0.50,8.00;8.85,0.65;grug_character_home;", "scout: Return home ends at the same edge")
lacks(qs, "label[0.50,7.70;Home:", "scout: no Home label above the button")
has(qs, "list[current_player;grug_quiver_content;0.50,6.70;1,1;]", "scout: the quiver slot kept")
has(page(H.player("q_war", "warrior", nil, 30), "stats"), "label[0.50,7.70;Home: Ironhold Inn]",
	"warrior: Home above the button")

local chosen
local choose = grug_achievements.choose_cloak_by_name
grug_achievements.choose_cloak_by_name = function(_, name) chosen = name return true end
local cp = H.player("cpick", "warrior", nil, 30)
page(cp, "effects")
check(H.click(cp, {grug_cloak = "Plain Grey Cloak"}), "a cloak choice is handled in any mode")
eq(chosen, "Plain Grey Cloak", "... by grug_achievements")
grug_achievements.choose_cloak_by_name = choose

-- Every element of the Stats mode stays in its column.
local whole = page(H.player("geo", "scout", nil, 30), "stats")
local part = whole:sub(whole:find("real_coordinates[false]", 1, true) or 1)
for name, x, y, ew, eh in part:gmatch("([%w_]+)%[([%d.]+),([%d.]+);([%d.]+),([%d.]+)[;%]]") do
	x, y, ew, eh = tonumber(x), tonumber(y), tonumber(ew), tonumber(eh)
	if x >= 9.8 and y >= 1.2 and y < BOX_BOTTOM and name ~= "background9" then
		check(y + eh <= BOX_BOTTOM + 0.005, ("stats geometry: %s at %.2f,%.2f ends inside the box")
			:format(name, x, y))
		check(x + ew <= 14.35 + 1e-6 or x >= 14.5 - 1e-6,
			("stats geometry: %s at %.2f,%.2f in the list or the detail"):format(name, x, y))
	end
end

print(("bytes: Character page Stats (geared warrior) %d"):format(#geared_fs))
print(("r88_stats: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("r88_stats: %d failures"):format(failures)) end
