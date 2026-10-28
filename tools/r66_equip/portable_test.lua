-- Round 66 lane EQUIP portable test (LuaJIT): the two-handed shift-click
-- swap, the blocked offhand and the refusal on the Character page
-- (round66-plan.md §2 rulings 1 and 2, §4 EQUIP, §6). Through
-- tools/r44_ch/harness.lua (the real sfinv, grug_inventory's equipment.lua,
-- bags.lua with storage.lua, ui.lua and pages.lua, grug_gear's permissions,
-- and a model of the engine's inventory move and shift-click) it checks:
--   S  shift-click a Staff with Wand + Spellbook equipped and one free slot:
--      Staff in Weapon, Wand in the Staff's cell, Spellbook in the free slot;
--      one equipment-change notification (list nil) and one equip sound; the
--      same hands, caches and items as the two separate moves (Spellbook
--      out, then Staff in); the Warrior the same with Battle Axe and Shield;
--   N  no free slot: nothing moves, one "No room" line, a repeat inside the
--      throttle adds none;
--   E  an empty Weapon slot: the Staff's freed cell counts as room, so a
--      full inventory still swaps (the Spellbook takes that cell); a Staff
--      above the level stays with the level line, the offhand untouched;
--   D  the drag refusal in both directions, unchanged in rule, the incoming
--      one with the Round 66 wording; nothing moves;
--   B  the blocked offhand per class: Warrior's Battle Axe, Mage's and
--      Priest's Staff (the dimmed two-hander and the "Blocked" tooltip); a
--      one-hander, an occupied offhand and the Scout keep today's ghost;
--   R  the refusal on the page: the notice replaces the gear box heading
--      while the Character page is selected, the page is re-sent and no item
--      changes by it; nothing for another page; it runs out after 6 s.
-- The rod in the Basic starter set is tools/r47_cr's T section.
--
-- Usage (repo root): luajit tools/r66_equip/portable_test.lua [repo]

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

-- Every notification with its list name (nil = "more than one").
local notified = {}
local notify = grug_core.notify_equipment_change
grug_core.notify_equipment_change = function(player, listname, reason)
	notified[#notified + 1] = {name = player:get_player_name(), list = listname or "nil"}
	return notify(player, listname, reason)
end

local IMAGES = {
	["grug_gear:staff_bronze"] = "grug_gear_item_staff_bronze.png",
	["grug_gear:greataxe_bronze"] = "grug_gear_item_greataxe_bronze.png",
	["grug_gear:wand_bronze"] = "grug_gear_item_wand_bronze.png",
}
for name, image in pairs(IMAGES) do core.registered_items[name].inventory_image = image end

local now_us = 0
core.get_us_time = function() return now_us end

local W, O = "grug_weapon", "grug_offhand"
local function shift(player, list, index)
	return H.shift(player, H.page(player, "stats"), list, index)
end
local function fill(player, item, except)
	local skip = {}
	for _, cell in ipairs(except or {}) do skip[cell[1] .. ":" .. cell[2]] = true end
	for _, list in ipairs({"main", "grug_bag1_content"}) do
		for i = 1, player.inv:get_size(list) do
			if not skip[list .. ":" .. i] then H.put(player, list, i, item) end
		end
	end
end
-- Every non-empty stack the player owns, as a sorted multiset string.
local function owned(player)
	local all = {}
	for _, list in ipairs({"main", "grug_bag1_content", W, O}) do
		for i = 1, player.inv:get_size(list) do
			local s = H.get(player, list, i)
			if s ~= "" then all[#all + 1] = s end
		end
	end
	table.sort(all)
	return table.concat(all, "|")
end
local function lines_for(name, text)
	local n = 0
	for _, line in ipairs(H.feed) do
		if line.name == name and line.text:find(text, 1, true) then n = n + 1 end
	end
	return n
end

--
-- S. The swap with one free slot.
--
local function caster(name, class_id)
	local p = H.player(name, class_id, {8})
	H.put(p, W, 1, "grug_gear:wand_bronze")
	H.put(p, O, 1, "grug_gear:spellbook_bronze")
	fill(p, "t:apple 99", {{"main", 3}, {"grug_bag1_content", 5}})
	H.put(p, "main", 3, "grug_gear:staff_bronze")
	return p
end

local a = caster("swap_a", "mage")
local before = owned(a)
local n0, s0 = #notified, #H.sounds
eq(shift(a, "main", 3), "grug_shift", "S the hotbar rings to the routing list")
eq(H.get(a, W, 1), "grug_gear:staff_bronze", "S the Staff in Weapon")
eq(H.get(a, "main", 3), "grug_gear:wand_bronze", "S the Wand takes the Staff's cell")
eq(H.get(a, O, 1), "", "S the offhand is empty")
eq(H.get(a, "grug_bag1_content", 5), "grug_gear:spellbook_bronze",
	"S the Spellbook in the one free slot (the give order)")
eq(#notified - n0, 1, "S one equipment-change notification")
eq(notified[#notified].list, "nil", "S ... for more than one list (nil)")
eq(#H.sounds - s0, 1, "S one equip sound")
eq(owned(a), before, "S no item lost or doubled")
eq(H.get(a, "grug_shift", 1), "", "S the routing list stays empty")
eq(grug_inventory.get_equipped_weapon(a):get_name(), "grug_gear:staff_bronze",
	"S the weapon cache answers the Staff")
eq(grug_inventory.get_equipped_offhand(a), nil, "S the offhand cache answers empty")

-- The same through two separate moves: the Spellbook out, then the Staff in.
local b = caster("swap_b", "mage")
shift(b, O, 1)
eq(H.get(b, O, 1), "", "S two moves: the Spellbook out first")
shift(b, "main", 3)
for _, list in ipairs({W, O}) do
	eq(H.get(a, list, 1), H.get(b, list, 1), "S " .. list .. " equals the two moves")
end
eq(H.get(a, "main", 3), H.get(b, "main", 3), "S the Staff's cell equals the two moves")
eq(owned(a), owned(b), "S the items equal the two moves")
eq(tostring(grug_inventory.get_equipped_offhand(b)), tostring(grug_inventory.get_equipped_offhand(a)),
	"S the offhand caches agree")

-- The Warrior: Battle Axe over Sword and Shield.
local w = H.player("swap_w", "warrior", {8})
H.put(w, W, 1, "grug_gear:sword_bronze")
H.put(w, O, 1, "grug_gear:shield_bronze")
H.put(w, "main", 12, "grug_gear:greataxe_bronze")
shift(w, "main", 12)
eq(H.get(w, W, 1), "grug_gear:greataxe_bronze", "S warrior: the Battle Axe in Weapon")
eq(H.get(w, "main", 12), "grug_gear:sword_bronze", "S warrior: the Sword takes its cell")
eq(H.get(w, "main", 9), "grug_gear:shield_bronze", "S warrior: the Shield into main[9]")
eq(H.get(w, O, 1), "", "S warrior: the offhand is empty")

-- The Priest's Staff swaps the same way.
local pr = caster("swap_p", "priest")
shift(pr, "main", 3)
eq(H.get(pr, W, 1) .. "|" .. H.get(pr, O, 1), "grug_gear:staff_bronze|",
	"S priest: the Staff swaps both hands")

--
-- N. No free slot: nothing moves, one line.
--
local full = caster("full", "mage")
H.put(full, "grug_bag1_content", 5, "t:apple 99")
local snapshot = owned(full)
local n1, f1 = #notified, #H.feed
shift(full, "main", 3)
eq(H.get(full, W, 1), "grug_gear:wand_bronze", "N the Wand stays")
eq(H.get(full, O, 1), "grug_gear:spellbook_bronze", "N the Spellbook stays")
eq(H.get(full, "main", 3), "grug_gear:staff_bronze", "N the Staff stays")
eq(owned(full), snapshot, "N nothing moved")
eq(#notified - n1, 0, "N no notification")
eq(#H.feed - f1, 1, "N one feed line")
local BOOK = core.registered_items["grug_gear:spellbook_bronze"].description
local STAFF = core.registered_items["grug_gear:staff_bronze"].description
eq(H.feed[#H.feed].text, "No room in your inventory for " .. BOOK .. ".", "N its text")
shift(full, "main", 3)
eq(#H.feed - f1, 1, "N a repeat inside the throttle adds no line")
H.tick()

--
-- E. An empty Weapon slot; the level gate.
--
local e = H.player("empty", "mage", {8})
H.put(e, O, 1, "grug_gear:spellbook_bronze")
fill(e, "t:apple 99", {{"main", 20}})
H.put(e, "main", 20, "grug_gear:staff_bronze")
shift(e, "main", 20)
eq(H.get(e, W, 1), "grug_gear:staff_bronze", "E the Staff in the empty Weapon slot")
eq(H.get(e, O, 1), "", "E the offhand is empty")
eq(H.get(e, "main", 20), "grug_gear:spellbook_bronze",
	"E a full inventory: the Spellbook takes the Staff's freed cell")

local low = H.player("low", "mage", {8}, 10)
H.put(low, W, 1, "grug_gear:wand_bronze")
H.put(low, O, 1, "grug_gear:spellbook_bronze")
H.put(low, "main", 9, "grug_gear:staff_steel")
shift(low, "main", 9)
eq(H.get(low, W, 1) .. "|" .. H.get(low, O, 1), "grug_gear:wand_bronze|grug_gear:spellbook_bronze",
	"E a Staff above the level: both hands stay")
eq(lines_for("low", "requires level 20"), 1, "E ... with the level line")
H.tick()

--
-- D. The drag refusal, both directions.
--
local d = H.player("drag", "mage", {8})
H.put(d, W, 1, "grug_gear:wand_bronze")
H.put(d, O, 1, "grug_gear:spellbook_bronze")
H.put(d, "main", 9, "grug_gear:staff_bronze")
eq(H.move(d, "main", 9, W, 1), 0, "D a Staff dragged onto Weapon beside a Spellbook: refused")
eq(H.get(d, W, 1) .. "|" .. H.get(d, "main", 9), "grug_gear:wand_bronze|grug_gear:staff_bronze",
	"D ... nothing moved")
eq(H.feed[#H.feed].text, STAFF .. " is two-handed: take " .. BOOK .. " out first, " ..
	"or shift-click the " .. STAFF .. " to swap both.", "D the incoming refusal names the shift-click way")
H.tick()
local d2 = H.player("drag2", "mage", {8})
H.put(d2, W, 1, "grug_gear:staff_bronze")
H.put(d2, "main", 9, "grug_gear:spellbook_bronze")
eq(H.move(d2, "main", 9, O, 1), 0, "D a Spellbook dragged beside a Staff: refused")
eq(H.feed[#H.feed].text, STAFF .. " is two-handed: equip a one-handed weapon to carry " ..
	BOOK .. " too.", "D the held refusal is unchanged")
H.tick()

--
-- B. The blocked offhand per class.
--
-- As the formspec carries it: escaped once (the engine unescapes image[]).
local function dimmed(item)
	return H.fs_escape(IMAGES[item] .. "^[multiply:#666666^[opacity:140")
end
local function offhand_cell(fs)
	return fs:match("image%[8%.05,2%.40;1,1;([^%]]*)%]"),
		fs:match("tooltip%[8%.05,2%.40;1,1;([^%]]*)%]")
end
for _, case in ipairs({{"warrior", "grug_gear:greataxe_bronze"},
		{"mage", "grug_gear:staff_bronze"}, {"priest", "grug_gear:staff_bronze"}}) do
	local p = H.player("blocked_" .. case[1], case[1])
	H.put(p, W, 1, case[2])
	local image, tip = offhand_cell(H.page(p, "stats"))
	eq(image, dimmed(case[2]), "B " .. case[1] .. ": the dimmed two-hander")
	eq(tip, "Blocked: " .. core.registered_items[case[2]].description .. " is two-handed",
		"B " .. case[1] .. ": the Blocked tooltip")
end
local one = H.player("one_hand", "mage")
H.put(one, W, 1, "grug_gear:wand_bronze")
local image, tip = offhand_cell(H.page(one, "stats"))
eq(image, grug_inventory.slot_ghost("mage", O), "B a one-hander: the class's ghost")
eq(tip, "Caster offhand", "B ... and the slot's name")
local sc = H.player("blocked_scout", "scout")
H.put(sc, W, 1, "grug_gear:bow_bronze")
image = offhand_cell(H.page(sc, "stats"))
eq(image, grug_inventory.slot_ghost("scout", O), "B the Scout's bow blocks nothing")
-- After the swap the page drawn for the player shows the blocked state.
image = offhand_cell(H.page(a, "stats"))
eq(image, dimmed("grug_gear:staff_bronze"), "B the swapped Mage's offhand is blocked")

--
-- R. The refusal on the page.
--
local r = H.player("notice", "mage", {8})
H.put(r, W, 1, "grug_gear:wand_bronze")
H.put(r, O, 1, "grug_gear:spellbook_bronze")
H.put(r, "main", 9, "grug_gear:staff_bronze")
local fs = H.page(r, "stats")
has(fs, "Equipment", "R the heading before a refusal")
local sent, items = r.sent, owned(r)
H.move(r, "main", 9, W, 1)
check(r.sent > sent, "R the refusal re-sends the page")
has(r.formspec, "to swap both.", "R the refusal shows on the page")
lacks(r.formspec, "Equipment]", "R ... in place of the heading")
eq(owned(r), items, "R the re-send moves no item")
eq(H.get(r, "main", 9), "grug_gear:staff_bronze", "R the Staff is still in its cell")
now_us = now_us + 5000000
has(H.page(r, "stats"), "to swap both.", "R still shown after 5 s")
now_us = now_us + 1500000
fs = H.page(r, "stats")
lacks(fs, "to swap both.", "R gone after 6 s")
has(fs, "Equipment", "R the heading is back")
H.tick()
-- Another page selected: the feed line only.
local other = H.player("other_page", "mage", {8})
H.put(other, W, 1, "grug_gear:staff_bronze")
H.put(other, "main", 9, "grug_gear:spellbook_bronze")
H.page(other, "stats")
sfinv.get_or_create_context(other).page = "grug_inventory:inventory"
local other_sent = other.sent
H.move(other, "main", 9, O, 1)
eq(other.sent, other_sent, "R another page is not re-sent")
eq(lines_for("other_page", "is two-handed"), 1, "R ... the feed line still goes out")

print(("r66_equip: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("r66_equip: %d failures"):format(failures)) end
print("R66 EQUIP PORTABLE PASS")
