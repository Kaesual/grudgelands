-- Round 69 lane UI portable test (round69-plan.md rulings 1, 2, 7). Through
-- tools/r44_ch/harness.lua (the REAL grug_inventory: bags, storage, trash, ui,
-- pages) with the REAL grug_housing/soulbound.lua and
-- grug_skills/bound_items.lua guards and the metadata-carrying ItemStack of
-- tools/r67_containers, it checks:
--   L  the layout: the box's place and height, the Money box above it, the
--      slot on the column of the others, the ghost, no listring on the page,
--      nothing on the other tabs;
--   T  the texts: the empty state, Destroyed with the name and Undo, a long
--      name inside the room, the count, the scale helpers;
--   D  discards: the whole stack, part of a stack, gone at once, the action
--      log line, a new discard replacing the last;
--   U  Undo: meta, wear and count restored, once; through the give helper;
--      no room keeps it undoable with the hint, part of a stack comes back;
--      the conservation of a stack through all of it;
--   R  refusals by the real guards: soulbound from main and a bag, a skill
--      on the hotbar, a mount item; the hint in the danger colour, its timer,
--      Undo stays; a filled bag with room gives up its contents, without
--      room it stays with the feed line; the hidden hotbar list;
--   X  exploits: only the owner, nothing to take or move, relog and leave
--      drop the state, a second player's Undo, a double click. Death needs
--      no case: no code here runs on it and the inventory stays (the
--      session's stack is one stack, dead or alive).
--
-- Usage (repo root): luajit tools/r69_ui/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)
dofile(repo .. "/tools/r67_containers/sort_cases.lua")(H) -- the meta ItemStack

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
local function has(text, needle, label)
	return check(text:find(needle, 1, true) ~= nil, label .. " (missing " .. needle .. ")")
end
local function lacks(text, needle, label)
	return check(text:find(needle, 1, true) == nil, label .. " (found " .. needle .. ")")
end

-- Colours readable in the form text.
core.colorize = function(color, text) return "<" .. color .. ">" .. text end
local COLORS = grug_core.ui.colors

-- The items.
local function item(name, description, groups, stack_max)
	core.registered_items[name] = {description = description, groups = groups or {},
		stack_max = stack_max or 99}
end
item("t:sword", "Steel Sword\nDamage 12", {}, 1)
item("t:ore", "Iron Ore")
item("t:long", "An Exceptionally Long Item Name Of Considerable Length And Then Some", {}, 1)
item("t:spaced", "Aaaa Bbbb Cccc Dddd Eeee Ffff", {grug_soulbound = 1}, 1)
item("t:umlaut", "Äääääääääääääääääääääääääääääääääääääääääääääääää", {}, 1)
item("t:packet", "Runner's Packet", {grug_soulbound = 1}, 1)
item("t:stone", "Claim Stone", {grug_soulbound = 1}, 1)
item("t:mount", "Old Mount", {grug_bound_skill = 1}, 1)
item("grug_abilities:strike", "Strike", {grug_ability = 1, grug_bound_skill = 1}, 1)
core.get_translated_string = nil
grug_core.plain_text = nil
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")

-- The real guards (grug_housing and grug_skills load after this mod).
grug_housing = {}
core.registered_nodes = {}
core.override_item = function() end
dofile(repo .. "/mods/PLAYER/grug_housing/soulbound.lua")
grug_skills = {}
grug_abilities = {is_unlocked = function() return true end}
grug_mounts = {owns_tier = function() return true end}
dofile(repo .. "/mods/PLAYER/grug_skills/bound_items.lua")

local players = {}
core.get_player_by_name = function(name) return players[name] end
local function player(name, bags)
	local p = H.player(name, "warrior", bags)
	players[name] = p
	local context = sfinv.get_or_create_context(p)
	context.page = "grug_inventory:inventory"
	return p, context
end
local function page(p) return sfinv.get_formspec(p, sfinv.contexts[p:get_player_name()]) end
local function box_of(p)
	local location, list = grug_inventory.trash_location(p)
	local name = location:match("^detached:(.+)$")
	return H.detached[name], core.detached_inventories[name], list
end

-- IMoveAction::apply from a player list into the detached list: allow_put,
-- the player's take half (both always run), the move, on_put, on_take.
local function drag(p, from_list, from_index, count, actor)
	local box, callbacks, list = box_of(p)
	actor = actor or p
	local source = p.inv:get_stack(from_list, from_index)
	if source:is_empty() then return 0 end
	if count and count < source:get_count() then source:set_count(count) end
	local put = callbacks.allow_put(box, list, 1, source, actor)
	local take = H.allow(p, "take", {listname = from_list, index = from_index, stack = source})
	local moved = math.min(put, take == nil and source:get_count() or take, source:get_count())
	if moved <= 0 then return 0 end
	local left = p.inv:get_stack(from_list, from_index)
	local moving = left:take_item(moved)
	p.inv:set_stack(from_list, from_index, left)
	box:set_stack(list, 1, moving)
	callbacks.on_put(box, list, 1, moving, actor)
	H.after_action(p, "take", {listname = from_list, index = from_index, stack = moving})
	return moved
end
local function undo(p) return H.click(p, {grug_trash_undo = "Undo"}) end
local function fill_inventory(p)
	for _, list in ipairs(grug_inventory.carried_lists(p.inv)) do
		for index = 1, p.inv:get_size(list) do
			if p.inv:get_stack(list, index):is_empty() then
				p.inv:set_stack(list, index, ItemStack("t:ore 99"))
			end
		end
	end
end
local function clear_inventory(p)
	for _, list in ipairs(grug_inventory.carried_lists(p.inv)) do
		for index = 1, p.inv:get_size(list) do p.inv:set_stack(list, index, ItemStack("")) end
	end
end
local function run_timers()
	local timers = H.timers
	H.timers = {}
	for _, timer in ipairs(timers) do timer.fn(unpack(timer.args)) end
end
local function count_of(p, name)
	local total = 0
	for _, list in ipairs(grug_inventory.carried_lists(p.inv)) do
		for _, stack in ipairs(p.inv:get_list(list)) do
			if stack:get_name() == name then total = total + stack:get_count() end
		end
	end
	return total
end

------------------------------------------------------------------------------
-- L. The layout.
------------------------------------------------------------------------------
local hero, hero_context = player("hero")
local layout = grug_inventory.LAYOUT
local fs = page(hero)
local function near(a, b) return math.abs(a - b) < 0.0005 end
check(near(layout.trash_y + layout.slot_box_h, layout.inventory_y + layout.inventory_h),
	"L the box ends at the Inventory box's bottom")
check(near(layout.money_y + layout.money_h + layout.gap, layout.trash_y),
	"L the Money box ends a gap above it")
has(fs, grug_core.ui.panel(layout.side_x, layout.trash_y, layout.side_w, layout.slot_box_h),
	"L the box, as high as the Potion belt box")
has(fs, ">TRASH]", "L the label")
local slot_x, slot_y = layout.side_x + layout.pad, layout.trash_y + layout.label_h
local location, list = grug_inventory.trash_location(hero)
eq(location, "detached:grug_trash_hero", "L the viewer's own list")
has(fs, ("list[%s;%s;%.3f,%.3f;1,1;]"):format(location, list, slot_x, slot_y),
	"L one native slot at the other slots' left")
has(fs, ("image[%.3f,%.3f;0.75,0.75;"):format(slot_x + 0.125, slot_y + 0.125) ..
	core.formspec_escape("creative_trash_icon.png^[multiply:#cb9290^[opacity:184") .. "]",
	"L the ghost on the slot")
check(fs:find("list[" .. location, 1, true) < fs:find("creative_trash_icon", 1, true),
	"L the ghost after the list, never under it")
lacks(fs, "listring[", "L no listring on the page: shift-click never reaches the slot")
local deposit_bottom = layout.money_y + 2.3 + 1
check(deposit_bottom < layout.money_y + layout.money_h, "L the deposit slot stays in the Money box")
print(("room under the deposit slot: %.2f units"):format(
	layout.money_y + layout.money_h - deposit_bottom))
for _, mode in ipairs({"stats", "effects"}) do
	lacks(H.page(hero, mode), "grug_trash", "L nothing on the Character page: " .. mode)
end
hero_context.page = "grug_inventory:inventory"
lacks(grug_inventory.station_formspec(hero, "", 1, {}), "grug_trash", "L nothing in a station form")

------------------------------------------------------------------------------
-- T. The texts.
------------------------------------------------------------------------------
has(fs, "<" .. COLORS.muted .. ">Drag an item here to destroy it.]", "T the empty state's first line")
has(fs, "<" .. COLORS.muted .. ">You can undo the last one.]", "T the empty state's second line")
lacks(fs, "grug_trash_undo", "T no Undo while nothing waits")

H.put(hero, "main", 9, "t:sword 1 4000 grug_quality=3;grug_ilvl=40")
eq(drag(hero, "main", 9), 1, "D a stack dragged in moves")
fs = page(hero)
has(fs, "<" .. COLORS.muted .. ">Destroyed:]", "T Destroyed")
has(fs, "<" .. COLORS.text .. ">Steel Sword]", "T the item's name, its first line")
has(fs, "button[17.080,", "T Undo at the right end of the box")
has(fs, ";grug_trash_undo;Undo]", "T the button")
local right = 17.08 + 1.7
check(near(right, layout.side_x + layout.side_w - layout.pad), "T Undo inside the box")

-- A label's room: from the text's left to the button.
local function shown_name(p)
	return page(p):match("Destroyed:%]label%[[^;]*;<" .. COLORS.text:gsub("%p", "%%%0") .. ">([^%]]*)%]")
end
local function chars(text) return select(2, text:gsub("[^\128-\191]", "")) end
local LIMIT = math.floor((17.08 - 0.1 - (slot_x + 1.15)) / 0.15)
H.put(hero, "main", 9, "t:long")
drag(hero, "main", 9)
local long = shown_name(hero)
check(chars(long) <= LIMIT and long:sub(-2) == "..", "T a long name is cut to the room: " .. long)
has(page(hero), "tooltip[", "T ...and stands whole in the tooltip")
has(page(hero), "Of Considerable Length And Then Some]", "T ...to the end")
H.put(hero, "main", 9, "t:umlaut")
drag(hero, "main", 9)
local umlaut = shown_name(hero)
check(chars(umlaut) <= LIMIT, "T the cut counts characters")
check(umlaut:gsub("%.%.$", ""):match("^[\195\132\195\164]+$") ~= nil, "T ...and splits none")
H.put(hero, "main", 9, "t:ore 42")
drag(hero, "main", 9)
eq(shown_name(hero), "Iron Ore ×42", "T the count beside the name")
-- The scale helpers: a shrunk form scales the text, the page's label size
-- comes back after it.
H.window_info.hero = {real_gui_scaling = 2, max_formspec_size = {x = 20, y = 8}}
fs = page(hero)
local scaled = fs:match("style_type%[label;font_size=%*([%d.]+)%]label%[%d+%.%d+,%d+%.%d+;<" ..
	COLORS.muted:gsub("%p", "%%%0") .. ">Destroyed")
check(scaled and tonumber(scaled) < 0.85, "T text_scale reaches the text: " .. tostring(scaled))
H.window_info.hero = nil
-- Empty the state again.
clear_inventory(hero)
undo(hero)
clear_inventory(hero)

------------------------------------------------------------------------------
-- D. Discards, U. Undo.
------------------------------------------------------------------------------
H.logs = {}
H.put(hero, "main", 9, "t:sword 1 4000 grug_quality=3;grug_ilvl=40")
local before = hero.inv:get_stack("main", 9):to_string()
local sent = hero.sent
eq(drag(hero, "main", 9), 1, "D a whole stack")
eq(hero.inv:get_stack("main", 9):to_string(), "", "D gone from the inventory at once")
eq(box_of(hero):get_stack("trash", 1):to_string(), "", "D the list stays empty")
eq(hero.sent, sent + 1, "D one page resend")
check(H.logs[#H.logs]:find("^action: %[grug_inventory%] hero destroyed t:sword x1") ~= nil,
	"D the action line: " .. tostring(H.logs[#H.logs]))
eq(#H.logs, 1, "D one line")
eq(undo(hero), true, "U the button is the page's")
eq(count_of(hero, "t:sword"), 1, "U it is back")
eq(hero.inv:get_stack("main", 9):to_string(), before, "U count, wear and meta intact")
undo(hero)
eq(count_of(hero, "t:sword"), 1, "U a second Undo gives nothing")
lacks(page(hero), "grug_trash_undo", "U no button after it")
has(page(hero), "Drag an item here", "U the empty state again")

-- Part of a stack, a right-drag.
clear_inventory(hero)
H.put(hero, "main", 10, "t:ore 30")
eq(drag(hero, "main", 10, 12), 12, "D part of a stack")
eq(count_of(hero, "t:ore"), 18, "D the rest stays")
has(page(hero), "Iron Ore ×12", "D the box names the part")
undo(hero)
eq(count_of(hero, "t:ore"), 30, "U the part comes back")

-- A new discard replaces the last; the old one is gone for good.
clear_inventory(hero)
H.put(hero, "main", 9, "t:sword")
H.put(hero, "main", 10, "t:ore 5")
drag(hero, "main", 9)
drag(hero, "main", 10)
has(page(hero), "Iron Ore ×5", "D the new discard shows")
undo(hero)
eq(count_of(hero, "t:ore"), 5, "U the last one returns")
eq(count_of(hero, "t:sword"), 0, "U the replaced one does not")

-- The potion belt's items may go too.
H.put(hero, grug_inventory.POTION_BELT, 1, "t:ore 2")
eq(drag(hero, grug_inventory.POTION_BELT, 1), 2, "D from the potion belt")
undo(hero)

-- No room: it stays undoable, with the hint; part of a stack comes back.
clear_inventory(hero)
H.put(hero, "main", 9, "t:sword 1 700 grug_ilvl=9")
drag(hero, "main", 9)
fill_inventory(hero)
local ore_before = count_of(hero, "t:ore")
undo(hero)
eq(count_of(hero, "t:sword"), 0, "U no room: nothing appears")
eq(count_of(hero, "t:ore"), ore_before, "U ...and nothing moves")
fs = page(hero)
has(fs, "<" .. COLORS.danger .. ">", "U the hint in the danger colour")
has(fs, "press Undo.", "U the hint says what to do")
has(fs, "grug_trash_undo", "U ...and Undo stays")
hero.inv:set_stack("main", 9, ItemStack(""))
undo(hero)
eq(hero.inv:get_stack("main", 9):to_string(), "t:sword 1 700 grug_ilvl=9", "U after making room, intact")
lacks(page(hero), "press Undo.", "U the hint goes with it")

clear_inventory(hero)
H.put(hero, "main", 9, "t:ore 60")
drag(hero, "main", 9)
fill_inventory(hero)
hero.inv:set_stack("main", 9, ItemStack("t:ore 90"))
hero.inv:set_stack("main", 10, ItemStack("t:ore 90"))
ore_before = count_of(hero, "t:ore")
undo(hero)
eq(count_of(hero, "t:ore"), ore_before + 18, "U part of the stack comes back")
has(page(hero), "Iron Ore ×42", "U the rest stays undoable (the hint's tooltip names it)")
run_timers()
eq(shown_name(hero), "Iron Ore ×42", "U ...and shows when the hint ran out")
hero.inv:set_stack("main", 9, ItemStack(""))
undo(hero)
eq(count_of(hero, "t:ore"), ore_before + 18 - 99 + 42, "U ...and follows, nothing lost or doubled")
lacks(page(hero), "grug_trash_undo", "U all back")

------------------------------------------------------------------------------
-- R. Refusals by the real guards.
------------------------------------------------------------------------------
clear_inventory(hero)
H.timers = {}
H.put(hero, "main", 9, "t:packet")
eq(drag(hero, "main", 9), 0, "R a soulbound item from main is refused")
eq(count_of(hero, "t:packet"), 1, "R ...and stays")
fs = page(hero)
has(fs, "<" .. COLORS.danger .. ">Runner's Packet can't be destroyed", "R the hint, first line")
has(fs, "<" .. COLORS.danger .. ">here: it is bound to you.]", "R the hint, second line")
lacks(fs, "grug_trash_undo", "R no Undo with nothing to undo")
eq(#H.timers, 1, "R one timer")
eq(H.timers[1].delay, 6, "R six seconds")
run_timers()
has(page(hero), "Drag an item here", "R the hint runs out")

-- A hint over a waiting Undo: the button stays, the text beside it fits.
H.put(hero, "main", 10, "t:sword")
drag(hero, "main", 10)
eq(drag(hero, "main", 9), 0, "R refused beside a waiting stack")
fs = page(hero)
has(fs, "grug_trash_undo", "R Undo stays through a hint")
-- Every hint stays two lines in its room, the long spaced name included.
local function hint_fits(room, label)
	local shown = page(hero)
	local lines = 0
	for line in shown:gmatch("<" .. COLORS.danger:gsub("%p", "%%%0") .. ">([^%]]*)%]") do
		lines = lines + 1
		check(chars(line) <= room, label .. ": the line fits: " .. line)
	end
	eq(lines, 2, label .. ": two lines")
end
hint_fits(LIMIT, "R the bound hint beside Undo")
has(fs, "Bound items can't be", "R ...its short form")
H.put(hero, "main", 11, "t:spaced")
eq(drag(hero, "main", 11), 0, "R a long spaced name")
hint_fits(LIMIT, "R the same for a long name")
clear_inventory(hero)
undo(hero)
clear_inventory(hero)
H.put(hero, "main", 11, "t:spaced")
drag(hero, "main", 11)
local WIDE = math.floor((layout.side_x + layout.side_w - layout.pad - (slot_x + 1.15)) / 0.15)
hint_fits(WIDE, "R a long name in the wide box")
clear_inventory(hero)
H.put(hero, "main", 9, "t:packet")
H.put(hero, "main", 10, "t:sword")
drag(hero, "main", 10)
fill_inventory(hero)
undo(hero)
hint_fits(LIMIT, "R the no-room hint beside Undo")
hero.inv:set_stack("main", 10, ItemStack(""))
-- A stale timer leaves a newer hint alone.
H.timers = {}
drag(hero, "main", 9)
local stale = H.timers[1]
drag(hero, "main", 9)
stale.fn(unpack(stale.args))
has(page(hero), "<" .. COLORS.danger .. ">", "R the first timer leaves the second hint")
run_timers()
lacks(page(hero), "<" .. COLORS.danger .. ">", "R its own timer clears it")
has(page(hero), "Steel Sword", "R the waiting stack shows again")
H.put(hero, "main", 11, "")
hero.inv:set_stack("main", 9, ItemStack(""))

-- In a bag; the stone; a skill on the hotbar; a mount item.
local bagged = player("bagged", {8, 0, 0, 0})
H.put(bagged, "grug_bag1_content", 3, "t:stone")
eq(drag(bagged, "grug_bag1_content", 3), 0, "R soulbound in a bag")
has(page(bagged), "Claim Stone can't be destroyed", "R ...with the hint")
H.put(bagged, "main", 1, "grug_abilities:strike")
eq(drag(bagged, "main", 1), 0, "R a skill on the hotbar")
eq(bagged.inv:get_stack("main", 1):get_name(), "grug_abilities:strike", "R ...stays")
has(page(bagged), "Strike can't be destroyed", "R ...with the hint")
H.put(bagged, "main", 2, "t:mount")
eq(drag(bagged, "main", 2), 0, "R a bound mount item")

-- The hidden hotbar list refuses every action.
H.put(bagged, grug_inventory.HOTBAR_STORE, 1, "t:ore 3")
eq(drag(bagged, grug_inventory.HOTBAR_STORE, 1), 0, "R the inactive hotbar layout")
eq(bagged.inv:get_stack(grug_inventory.HOTBAR_STORE, 1):get_count(), 3, "R ...keeps its stack")

-- A filled bag: its contents move (the bag rules), then it goes; Undo returns
-- it empty. Without room it stays, with the bag rules' feed line.
local packer = player("packer", {8, 0, 0, 0})
H.put(packer, "grug_bag1_content", 1, "t:sword")
H.put(packer, "grug_bag1_content", 2, "t:ore 7")
eq(drag(packer, "grug_bag1", 1), 1, "R a filled bag with room goes")
eq(packer.inv:get_size("grug_bag1_content"), 0, "R ...its list is gone")
eq(count_of(packer, "t:sword"), 1, "R ...its contents stay")
eq(count_of(packer, "t:ore"), 7, "R ...all of them")
undo(packer)
eq(count_of(packer, "grug_inventory:bag_small"), 1, "R Undo returns the bag")

local tight = player("tight", {8, 0, 0, 0})
H.put(tight, "grug_bag1_content", 1, "t:sword")
fill_inventory(tight)
local feed_before = #H.feed
eq(drag(tight, "grug_bag1", 1), 0, "R a filled bag without room stays")
eq(tight.inv:get_stack("grug_bag1", 1):get_name(), "grug_inventory:bag_small", "R ...in its slot")
eq(tight.inv:get_size("grug_bag1_content"), 8, "R ...with its list")
check(#H.feed > feed_before, "R ...and the bag rules' feed line")
lacks(page(tight), "grug_trash_undo", "R ...nothing to undo")

------------------------------------------------------------------------------
-- X. Exploits.
------------------------------------------------------------------------------
local owner = player("owner")
local thief = player("thief")
H.put(owner, "main", 9, "t:sword")
local box, callbacks = box_of(owner)
eq(callbacks.allow_put(box, "trash", 1, ItemStack("t:ore"), thief), 0, "X another player cannot put")
eq(callbacks.allow_put(box, "trash", 1, ItemStack("t:ore"), nil), 0, "X nor nobody")
lacks(page(thief), "can't be destroyed", "X a foreign put gives the thief no hint")
lacks(page(owner), "can't be destroyed", "X ...nor the owner")
eq(callbacks.allow_take(box, "trash", 1, ItemStack("t:sword"), owner), 0, "X nothing to take")
eq(callbacks.allow_move(box, "trash", 1, "trash", 1, 1, owner), 0, "X nothing to move")
has(page(thief), "detached:grug_trash_thief", "X each viewer draws the own list")
lacks(page(thief), "grug_trash_owner", "X ...never another's")
drag(owner, "main", 9)
undo(thief)
eq(count_of(thief, "t:sword"), 0, "X the other player's Undo gives nothing")
eq(count_of(owner, "t:sword"), 0, "X ...and restores nothing")
-- Twice in one event: one stack.
H.click(owner, {grug_trash_undo = "Undo"})
H.click(owner, {grug_trash_undo = "Undo"})
eq(count_of(owner, "t:sword"), 1, "X a double click restores once")

-- Leaving drops the state and the list; a rejoin starts empty.
drag(owner, "main", 9)
H.timers = {}
H.leave(owner)
check(core.detached_inventories.grug_trash_owner == nil, "X the list goes at leave")
undo(owner)
eq(count_of(owner, "t:sword"), 0, "X nothing to undo after leaving")
H.join(owner)
check(core.detached_inventories.grug_trash_owner ~= nil, "X a rejoin builds it again")
lacks(page(owner), "grug_trash_undo", "X a relog keeps no Undo")
undo(owner)
eq(count_of(owner, "t:sword"), 0, "X ...and none works")
-- A timer that outlives the session finds nothing.
H.put(owner, "main", 9, "t:packet")
drag(owner, "main", 9)
local timer = H.timers[#H.timers]
H.leave(owner)
timer.fn(unpack(timer.args))
H.join(owner)
lacks(page(owner), "can't be destroyed", "X a timer after a leave finds nothing")

print(("R69 UI PORTABLE %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
	checks, failures))
if failures > 0 then os.exit(1) end
