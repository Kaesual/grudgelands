-- Round 44 lane CH portable test: the Character tab (round44-plan.md §4.5,
-- spec ruling 6 and §3.3). Through tools/r44_ch/harness.lua (the real
-- sfinv, grug_inventory equipment/bags/storage/ui/pages, grug_gear
-- permissions, grug_achievements and grug_jobs' body) it checks:
--   1. the three modes (the professions overview moved to the Crafting tab in
--      Round 45 and is checked there, tools/r45_ui; 3D and Stats are one
--      Stats mode since the Round 45 playtest: the model, the stats right of
--      it, the cloak picker bottom-aligned with the model; no balance and no
--      Withdraw, they are on the Inventory tab): each renders, the selected
--      button is styled, Stats is the default, a mode button switches the
--      box only (runtime context), every mode keeps the gear box and the
--      frame's short view, the page draws no `main` of its own, and the
--      boxes stay above the view's Inventory box and apart;
--   2. the gear box per class: eight slots with the class's hand labels
--      (HAND_RULES), tooltips and ghosts, the arrow slot only for Scouts with
--      its total and the overlay above 100 arrows; Return home (label and
--      button, every mode, the countdown, the click);
--   3. shift-click routing through the page's own listring: inventory ->
--      equipment (empty slot first, then a swap; hotbar and bags as sources;
--      the class hands, two-handed, level, armor-class and unique-trinket
--      rules with their feed lines), equipment -> inventory in the give order
--      (main[9..], bags, hotbar last; refused when full), arrows into and out
--      of a Scout's quiver, anything else unmoved; the routing list stays
--      empty (a stray item is given back at join); a drag still equips;
--   4. the page's bytes per mode (printed; comparisons, not targets).
--
-- Usage (repo root): luajit tools/r44_ch/portable_test.lua [repo]

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
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. ("%q"):format(part) .. ")")
end
local function count_of(text, part)
	local n, from = 0, 1
	while true do
		local at = text:find(part, from, true)
		if not at then return n end
		n, from = n + 1, at + 1
	end
end

-- Formspec sanity as the engine parses it: the string splits at every
-- unescaped "]", each piece is a name and "[" and its fields.
local function formspec_ok(fs, label)
	local piece, i = {}, 1
	while i <= #fs do
		local c = fs:sub(i, i)
		if c == "\\" then
			piece[#piece + 1] = fs:sub(i, i + 1)
			i = i + 1
		elseif c == "]" then
			if not table.concat(piece):match("^[%a_]+%[") then
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

-- The page's own content: everything after the frame's view and its
-- real_coordinates[false].
local function page_part(fs)
	local at = fs:find("real_coordinates[false]", 1, true)
	return at and fs:sub(at) or ""
end

-- Elements with a rect in the page part: {name, x, y, w, h}.
local function rects(part)
	local out = {}
	for name, x, y, w, h in part:gmatch("([%a_]+)%[([%d.]+),([%d.]+);([%d.]+),([%d.]+)[;%]]") do
		out[#out + 1] = {name = name, x = tonumber(x), y = tonumber(y),
			w = tonumber(w), h = tonumber(h)}
	end
	for x, y in part:gmatch("label%[([%d.]+),([%d.]+);") do
		out[#out + 1] = {name = "label", x = tonumber(x), y = tonumber(y) - 0.25,
			w = 0, h = 0.5}
	end
	return out
end

-- The boxes end a gap above the short view's Inventory box (ui.lua).
local MODE_RIGHT, GEAR_LEFT = 8.1, 8.3
local BOXES_BOTTOM = grug_inventory.VIEW_GEOMETRY.top - 0.1
local FRAME = ("formspec_version[6]size[%.3f,%.3f]"):format(grug_inventory.UI.frame_w,
	grug_inventory.UI.frame_h)

--
-- 1. The modes
--

local MODES = {"stats", "effects", "achievements"}
local warrior = H.player("wara", "warrior", {16})
local default_fs = H.page(warrior, nil)
eq(H.context.grug_character_tab, nil, "no mode stored before a click")
has(default_fs, "style[grug_character_stats;bgcolor=#8a682f", "Stats is the default mode")
lacks(default_fs, "grug_character_3d", "no 3D mode (one Stats mode, Round 45 playtest)")
-- The Stats mode: the model on the left, the stats right of it, the cloak
-- picker at the foot of the stats column, its hint ending with the model.
local mx, my, mw, mh = default_fs:match("model%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_preview;")
mx, my, mw, mh = tonumber(mx), tonumber(my), tonumber(mw), tonumber(mh)
check(mx ~= nil, "the model in the Stats mode")
has(default_fs, "label[3.95,1.60;Maximum HP: 120]", "the stats right of the model")
check(mx and mx + mw <= 3.95, "the model ends left of the stats column")
has(default_fs, "dropdown[3.95,7.85;4.00;grug_cloak;", "the cloak picker in the stats column")
has(default_fs, "label[3.95,7.50;Cloak]", "the cloak label above it")
local hint_y = tonumber(default_fs:match("label%[3%.95,([%d.]+);Cloaks unlock through\nachievements%.%]"))
check(hint_y and math.abs(hint_y + 0.75 - (my + mh)) < 0.006,
	"the cloak block ends where the model ends (bottom-aligned)")
check(my and my + mh <= BOXES_BOTTOM, "the model inside the mode box")
lacks(default_fs, "Money", "no balance on the Character page")
lacks(default_fs, "grug_money_withdraw", "no Withdraw on the Character page")
local labels = {stats = "Stats", effects = "Effects", achievements = "Achievements"}
H.status_effects = {
	{id = "food", name = "Hearty Stew", texture = "stew.png", detail = "+2% HP/5s",
		remaining_us = 600000000},
	{id = "shield", name = "Bulwark", texture = "shield.png", detail = "Absorb",
		value = 30, caption = "30", remaining_us = 4000000},
}
for _, mode in ipairs(MODES) do
	local fs = H.page(warrior, mode)
	local label = "mode " .. mode
	formspec_ok(fs, label)
	has(fs, FRAME, label .. ": the frame")
	has(fs, "scroll_container[", label .. ": the frame's view")
	has(fs, "grug_inv_scroll_short", label .. ": the short view")
	eq(count_of(fs, "list[current_player;main;"), 2,
		label .. ": main only in the view (grid and hotbar)")
	for _, other in ipairs(MODES) do
		has(fs, ("grug_character_%s;%s]"):format(other, labels[other]),
			label .. ": the " .. other .. " button")
		has(fs, ("style[grug_character_%s;bgcolor=%s"):format(other,
			other == mode and "#8a682f" or "#3d3d3d"), label .. ": " .. other .. " styled")
	end
	-- The gear box in every mode.
	has(fs, "list[current_player;grug_head;8.50,0.95;1,1;]", label .. ": the gear box")
	has(fs, "button[8.50,9.00;4.65,0.8;grug_character_home;Return home (Ready)]",
		label .. ": Return home at the foot of the gear box")
	-- Geometry: the page's content above the view's Inventory box, the mode
	-- body left of the gear box.
	local part = page_part(fs)
	has(part, "real_coordinates[true]", label .. ": real coordinates")
	local inside = true
	for _, r in ipairs(rects(part)) do
		if r.y + r.h > BOXES_BOTTOM + 1e-6 or r.y < 0 then
			inside = check(false, ("%s: %s at %.2f,%.2f+%.2f,%.2f below the boxes"):format(
				label, r.name, r.x, r.y, r.w, r.h))
		end
		if r.x < GEAR_LEFT and r.name ~= "label" and r.x + r.w > MODE_RIGHT + 1e-6 then
			inside = check(false, ("%s: %s at %.2f,%.2f crosses into the gear box"):format(
				label, r.name, r.x, r.y))
		end
	end
	check(inside, label .. ": every element inside its box")
	print(("bytes: Character page (warrior, one bag) %-12s %6d"):format(mode, #fs))
end

-- A mode button switches the box (context) and resends; nothing is stored.
local sent = warrior.sent
check(H.click(warrior, {grug_character_effects = "Effects"}), "the Effects button is handled")
eq(H.context.grug_character_tab, "effects", "the button selects the mode")
check(warrior.sent > sent, "the page is resent")
has(warrior.formspec, "Hearty Stew", "the Effects mode is shown")
eq(warrior:get_meta():get_string("grug_character_tab"), "", "the mode is runtime context only")

-- Stats.
local stats = H.page(warrior, "stats")
for _, line in ipairs({"Maximum HP: 120", "Maximum rage: 100", "Damage reduction: 12.3%",
		"Crit: 5.0%", "Dodge: 5.0%"}) do
	has(stats, line, "stats: " .. line)
end
has(stats, "tooltip[3.95,2.85;4.00,0.50;Armor reduction against", "stats: the reduction tooltip")
lacks(stats, "deposit", "no deposit slot on the Character page")
H.click(warrior, {grug_money_withdraw = "Withdraw"})
eq(H.withdrawn, 0, "the Character page no longer handles Withdraw")

-- Effects: one column, the overflow line.
local effects = H.page(warrior, "effects")
has(effects, "label[1.35,1.50;Hearty Stew  10m]", "effects: name and time")
has(effects, "label[1.35,1.90;+2% HP/5s]", "effects: detail")
has(effects, "label[1.35,2.85;Absorb: 30 left]", "effects: a shield's value")
H.status_effects = {}
for i = 1, 10 do
	H.status_effects[i] = {id = "e" .. i, name = "Effect " .. i, texture = "e.png",
		remaining_us = 0}
end
effects = H.page(warrior, "effects")
has(effects, "Effect 7  0m", "effects: seven rows when more than eight")
lacks(effects, "Effect 8  ", "effects: the eighth row holds the overflow")
has(effects, "... and 3 more", "effects: the overflow line")
H.status_effects = {}
has(H.page(warrior, "effects"), "No active effects.", "effects: the empty text")

-- Achievements: one column of seven, the pager at the foot of the box.
local ach = H.page(warrior, "achievements")
local rows = count_of(ach, "tooltip[0.40,")
eq(rows, 7, "achievements: seven rows per page")
has(ach, "grug_ach_next;>]", "achievements: the pager")
has(ach, "label[5.40,9.70;1/3]", "achievements: page 1 of 3")
check(H.click(warrior, {grug_ach_next = ">"}), "achievements: next page handled")
has(H.page(warrior, "achievements"), "label[5.40,9.70;2/3]", "achievements: page 2")

-- No Professions mode since Round 45 (the overview is on the Crafting tab).
lacks(H.page(warrior, nil), "grug_character_professions", "no Professions mode button")

--
-- 2. The gear box per class
--

local HANDS = {
	warrior = {"Weapon", "Shield"},
	scout = {"Ranged", "Melee"},
	mage = {"Weapon", "Caster\noffhand"},
	priest = {"Weapon", "Caster\noffhand"},
}
for class_id, hands in pairs(HANDS) do
	local player = H.player("g_" .. class_id, class_id)
	local fs = H.page(player, "stats")
	local label = "gear " .. class_id
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		has(fs, ("list[current_player;%s;"):format(slot.list), label .. ": " .. slot.list)
		has(fs, ("listring[current_player;%s]listring[current_player;grug_shift]")
			:format(slot.list), label .. ": " .. slot.list .. " rings to the routing list")
	end
	for _, name in ipairs({"Head", "Chest", "Legs", "Feet", "Trinket"}) do
		has(fs, (";%s]"):format(name), label .. ": label " .. name)
	end
	has(fs, "label[12.00," .. (#hands[1] > 8 and "1.20" or "1.45") .. ";" .. hands[1] .. "]",
		label .. ": weapon hand label")
	has(fs, "label[12.00," .. (hands[2]:find("\n") and "2.45" or "2.70") .. ";" ..
		hands[2] .. "]", label .. ": offhand label")
	has(fs, "tooltip[10.90,0.95;1,1;" .. hands[1] .. " — equip here", label .. ": weapon tooltip")
	has(fs, "image[10.90,2.20;1,1;" .. grug_inventory.slot_ghost(class_id, "grug_offhand"):gsub(",", "\\,"),
		label .. ": the class's offhand ghost")
	has(fs, "listring[current_player;main]listring[current_player;grug_shift]",
		label .. ": main rings to the routing list")
	if class_id == "scout" then
		has(fs, "list[current_player;grug_quiver_content;8.50,6.10;1,1;]",
			label .. ": the arrow slot")
		has(fs, "listring[current_player;grug_quiver_content]listring[current_player;grug_shift]",
			label .. ": the quiver rings to the routing list")
		has(fs, "label[9.60,6.35;Quiver\n0/500]", label .. ": the quiver's total")
		has(fs, "grug_inventory_quiver.png", label .. ": the empty quiver's ghost")
	else
		lacks(fs, "grug_quiver_content", label .. ": no arrow slot")
	end
end
-- An equipped slot has no ghost; the bag's content list rings too.
local w2 = H.player("w2", "warrior", {0, 8})
H.put(w2, "grug_head", 1, "grug_gear:head_metal")
local fs_w2 = H.page(w2, "stats")
lacks(fs_w2, "grug_gear_item_head_metal.png", "an equipped slot shows no ghost")
has(fs_w2, "listring[current_player;grug_bag2_content]listring[current_player;grug_shift]",
	"an equipped bag's list rings to the routing list")
lacks(fs_w2, "listring[current_player;grug_bag1_content]", "no ring for an empty bag slot")

-- The quiver total above one stack: cover and count overlay after the list.
local archer = H.player("archer", "scout")
H.put(archer, "grug_quiver_content", 1, "grug_gear:arrow 100")
lacks(H.page(archer, "stats"), "item_image[", "100 arrows: the engine's count alone")
H.put(archer, "grug_quiver_content", 2, "grug_gear:arrow 81")
local fs_q = H.page(archer, "stats")
local cell = fs_q:find("list[current_player;grug_quiver_content;8.50,6.10;1,1;]", 1, true)
local cover = fs_q:find("image[8.500,6.399;1.02,0.72;[fill:8x8:#1f1f1f]", 1, true)
local total = fs_q:find("item_image[8.50,6.10;1,1;grug_gear:arrow 181]", 1, true)
check(cell and cover and total and cell < cover and cover < total,
	"181 arrows: the list, then the cover over its count corner, then the total")
has(fs_q, "label[9.60,6.35;Quiver\n181/500]", "181 arrows: the total beside the slot")

-- Return home: every mode, the countdown in minutes, the click.
H.home.remaining = 150
has(H.page(archer, "achievements"), "button[8.50,9.00;4.65,0.8;grug_character_home;" ..
	"Return home (3 min)]", "Return home: the cooldown in minutes")
has(H.page(archer, "achievements"), "label[8.50,8.60;Home: Ironhold Inn]", "the home's name")
H.home.remaining = 0
local sent_home = archer.sent
H.page(archer, "effects")
check(H.click(archer, {grug_character_home = "Return home"}), "Return home handled")
check(H.home.pending and archer.sent > sent_home, "Return home starts the return and resends")
has(archer.formspec, "Return home (Preparing arrival)", "the button shows the arrival")
H.home.pending = false
H.home.label = nil
lacks(H.page(archer, "stats"), "grug_character_home", "no home: no button")
H.home.label = "Ironhold Inn"

--
-- 3. Shift-click routing
--

local function shift(player, list, index)
	return H.shift(player, H.page(player, "stats"), list, index)
end
local function feeds_with(text)
	local n = 0
	for _, line in ipairs(H.feed) do
		if line.text:find(text, 1, true) then n = n + 1 end
	end
	return n
end
local function routing_empty(player, label)
	eq(H.get(player, "grug_shift", 1), "", label .. ": the routing list stays empty")
end

-- Warrior: armor from main[9..], the hotbar and a bag; the swap.
local war = H.player("war", "warrior", {16})
eq(war.inv:get_size("grug_shift"), 1, "join sizes the routing list")
H.put(war, "main", 10, "grug_gear:head_metal")
local changes, sounds = H.equipment_changes, #H.sounds
eq(shift(war, "main", 10), "grug_shift", "main rings to the routing list")
eq(H.get(war, "grug_head", 1), "grug_gear:head_metal", "a helmet from main goes to Head")
eq(H.get(war, "main", 10), "", "... and leaves its cell")
check(H.equipment_changes > changes, "an equip notifies the equipment change")
eq(H.sounds[sounds + 1], "equip", "an equip plays the equip sound")
routing_empty(war, "equip")
H.put(war, "main", 2, "grug_gear:head_leather")
shift(war, "main", 2)
eq(H.get(war, "grug_head", 1), "grug_gear:head_leather", "from the hotbar: a swap")
eq(H.get(war, "main", 2), "grug_gear:head_metal", "the old helmet takes the source cell")
H.put(war, "grug_bag1_content", 3, "grug_gear:chest_leather")
eq(shift(war, "grug_bag1_content", 3), "grug_shift", "a bag's list rings to the routing list")
eq(H.get(war, "grug_chest", 1), "grug_gear:chest_leather", "from a bag into Chest")
-- Hands: sword, shield, then a two-handed axe against the shield.
H.put(war, "main", 11, "grug_gear:sword_bronze")
H.put(war, "main", 12, "grug_gear:shield_bronze")
H.put(war, "main", 13, "grug_gear:greataxe_bronze")
shift(war, "main", 11)
shift(war, "main", 12)
eq(H.get(war, "grug_weapon", 1), "grug_gear:sword_bronze", "warrior: sword into Weapon")
eq(H.get(war, "grug_offhand", 1), "grug_gear:shield_bronze", "warrior: shield into Shield")
H.tick()
shift(war, "main", 13)
eq(H.get(war, "main", 13), "grug_gear:greataxe_bronze", "a two-handed axe beside a shield stays")
eq(H.get(war, "grug_weapon", 1), "grug_gear:sword_bronze", "... and the sword stays")
check(feeds_with("is two-handed") > 0, "the two-handed refusal explains itself")
-- Anything that is no equipment stays, silently.
local feed_count = #H.feed
H.put(war, "main", 14, "t:apple 5")
shift(war, "main", 14)
eq(H.get(war, "main", 14), "t:apple 5", "an apple stays where it is")
eq(#H.feed, feed_count, "... without a feed line")
H.put(war, "main", 15, "grug_gear:arrow 20")
shift(war, "main", 15)
eq(H.get(war, "main", 15), "grug_gear:arrow 20", "a warrior's arrows stay (no quiver)")
routing_empty(war, "refusals")

-- Equipment -> inventory: main[9..] first, never the hotbar first.
local un = H.player("un", "warrior", {8})
H.put(un, "grug_head", 1, "grug_gear:head_metal")
eq(shift(un, "grug_head", 1), "grug_shift", "an equipment slot rings to the routing list")
eq(H.get(un, "grug_head", 1), "", "unequipped")
eq(H.get(un, "main", 9), "grug_gear:head_metal", "into main[9], not the empty hotbar")
for i = 9, 32 do H.put(un, "main", i, "t:apple 99") end
H.put(un, "grug_head", 1, "grug_gear:head_metal")
shift(un, "grug_head", 1)
eq(H.get(un, "grug_bag1_content", 1), "grug_gear:head_metal", "main full: into the bag")
for i = 1, 8 do H.put(un, "grug_bag1_content", i, "t:apple 99") end
H.put(un, "grug_head", 1, "grug_gear:head_metal")
shift(un, "grug_head", 1)
eq(H.get(un, "main", 1), "grug_gear:head_metal", "main and bag full: the hotbar last")
for i = 1, 8 do H.put(un, "main", i, "t:apple 99") end
H.put(un, "grug_head", 1, "grug_gear:head_metal")
H.tick()
shift(un, "grug_head", 1)
eq(H.get(un, "grug_head", 1), "grug_gear:head_metal", "all full: the helmet stays equipped")
check(feeds_with("No room in your inventory for") > 0, "the full refusal explains itself")
routing_empty(un, "unequip")

-- Scout: the hands by family, arrows in and out of the quiver.
local sc = H.player("sc", "scout", {8})
H.put(sc, "main", 9, "grug_gear:bow_bronze")
H.put(sc, "main", 10, "grug_gear:dagger_bronze")
H.put(sc, "main", 11, "grug_gear:sword_bronze")
shift(sc, "main", 9)
shift(sc, "main", 10)
eq(H.get(sc, "grug_weapon", 1), "grug_gear:bow_bronze", "scout: the bow into Ranged")
eq(H.get(sc, "grug_offhand", 1), "grug_gear:dagger_bronze", "scout: the dagger into Melee")
shift(sc, "main", 11)
eq(H.get(sc, "grug_offhand", 1), "grug_gear:sword_bronze", "scout: a sword swaps into Melee")
eq(H.get(sc, "main", 11), "grug_gear:dagger_bronze", "... the dagger takes its cell")
H.put(sc, "main", 12, "grug_gear:arrow 60")
H.put(sc, "grug_bag1_content", 2, "grug_gear:arrow 70")
shift(sc, "main", 12)
shift(sc, "grug_bag1_content", 2)
eq(grug_inventory.quiver_count(sc), 130, "scout: arrows from main and a bag into the quiver")
eq(H.get(sc, "grug_quiver_content", 1), "grug_gear:arrow 100", "the visible cell holds 100")
eq(H.get(sc, "main", 12) .. H.get(sc, "grug_bag1_content", 2), "", "... the sources are empty")
local refreshes = H.refreshes
shift(sc, "grug_quiver_content", 1)
eq(grug_inventory.quiver_count(sc), 30, "out of the quiver: one cell of 100")
eq(H.get(sc, "grug_quiver_content", 1), "grug_gear:arrow 30", "the cell is refilled")
eq(H.get(sc, "main", 9), "grug_gear:arrow 100",
	"the arrows land in main[9..] (its first free cell), not the quiver")
check(H.refreshes > refreshes, "a quiver change resends the Character page")
routing_empty(sc, "scout")

-- Mage: the spellbook; a bow and metal armor refused with a reason.
local mage = H.player("mage", "mage")
H.put(mage, "main", 9, "grug_gear:spellbook_bronze")
H.put(mage, "main", 10, "grug_gear:bow_bronze")
H.put(mage, "main", 11, "grug_gear:head_metal")
H.put(mage, "main", 12, "grug_gear:feet_cloth")
shift(mage, "main", 9)
eq(H.get(mage, "grug_offhand", 1), "grug_gear:spellbook_bronze", "mage: the spellbook")
H.tick()
shift(mage, "main", 10)
eq(H.get(mage, "main", 10), "grug_gear:bow_bronze", "mage: a bow stays")
check(feeds_with("Your class cannot equip") > 0, "mage: the bow refusal explains itself")
H.tick()
shift(mage, "main", 11)
eq(H.get(mage, "main", 11), "grug_gear:head_metal", "mage: metal armor stays")
check(feeds_with("cannot wear metal armor") > 0, "mage: the armor refusal explains itself")
H.tick()
shift(mage, "main", 12)
eq(H.get(mage, "main", 12), "grug_gear:feet_cloth", "mage: boots above the level stay")
check(feeds_with("requires level 40") > 0, "mage: the level refusal explains itself")

-- Trinkets: the free slot first, then a swap; never two of one identity.
local tr = H.player("tr", "priest")
H.put(tr, "main", 9, "grug_gear:ring_a")
H.put(tr, "main", 10, "grug_gear:ring_b")
H.put(tr, "main", 11, "grug_gear:ring_c")
shift(tr, "main", 9)
shift(tr, "main", 10)
eq(H.get(tr, "grug_trinket1", 1) .. "|" .. H.get(tr, "grug_trinket2", 1),
	"grug_gear:ring_a|grug_gear:ring_b", "two trinkets fill both slots")
shift(tr, "main", 11)
eq(H.get(tr, "grug_trinket1", 1), "grug_gear:ring_c", "a third swaps with the first slot")
eq(H.get(tr, "main", 11), "grug_gear:ring_a", "... which takes its cell")
H.put(tr, "grug_trinket1", 1, "")
H.put(tr, "main", 12, "grug_gear:ring_b")
shift(tr, "main", 12)
eq(H.get(tr, "grug_trinket1", 1), "", "a second copy of an identity skips the free slot")
eq(H.get(tr, "grug_trinket2", 1), "grug_gear:ring_b", "... and swaps with its twin")

-- The routing list takes nothing by itself; a drag still equips.
local dr = H.player("dr", "warrior")
H.put(dr, "main", 9, "grug_gear:head_metal")
eq(H.move(dr, "main", 9, "grug_shift", 1, 1, false), 0, "a drag onto the routing list moves nothing")
eq(H.get(dr, "grug_head", 1), "grug_gear:head_metal", "... it is applied as the shift-click")
routing_empty(dr, "drag")
H.put(dr, "main", 10, "grug_gear:head_leather")
eq(H.move(dr, "main", 10, "grug_head", 1, 1, false), 1, "a drag onto Head swaps by the engine")
eq(H.get(dr, "main", 10), "grug_gear:head_metal", "... the old helmet takes the cell")

-- The join's safety net: whatever another writer left in the routing list
-- goes back through the give helper; the leftover lands at the feet.
local sn = H.player("sn", "warrior")
H.put(sn, "grug_shift", 1, "grug_gear:head_metal")
H.join(sn)
routing_empty(sn, "join")
eq(H.get(sn, "main", 9), "grug_gear:head_metal", "join: a stray item is given back (main[9])")
for i = 1, 32 do H.put(sn, "main", i, "t:apple 99") end
H.put(sn, "grug_shift", 1, "grug_gear:head_leather")
H.join(sn)
routing_empty(sn, "join, full")
eq(H.dropped[#H.dropped], "grug_gear:head_leather", "join, full: the leftover drops at the feet")

--
-- 4. Bytes (a comparison: tools/r44_ch/bytes.lua measures any tree)
--

print(("r44_ch: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("r44_ch: %d failures"):format(failures)) end
