-- Round 44 lane FR portable test: the inventory window. Loads the REAL
-- vendored sfinv (mods/BASE/sfinv/api.lua) and grug_inventory's bags.lua
-- (with lane IH's storage.lua), ui.lua and pages.lua under a minimal `core`
-- stub and checks:
--   1. the tab order: one table (grug_inventory.TAB_ORDER) whatever the
--      registration order, pages missing from it after it, the Inventory
--      page as the homepage, no ordering hook left in the page mods;
--   2. the frame: formspec_version 6 with a real-coordinate size equal to the
--      old legacy size[10.4,11.1], legacy content after real_coordinates[false],
--      a page's own header (the Map tab) left alone;
--   3. the views, full and short, with 0-4 bags of mixed sizes: main[9..]
--      first, then each equipped bag's list in slot order as one 8-wide grid
--      without gaps, the hotbar outside the scroll area at one place in both
--      views, slot counts, the scrollbar only when the grid is taller than the
--      view, no listring on the Inventory page;
--      the view's scrollbaroptions reset to the engine defaults after its
--      scrollbar, so page scrollbars do not inherit them;
--   4. the scrollbar echo: CHG and VAL values kept per view, echoed and
--      clamped on the next build; a pure scrollbar event reaches no page
--      handler and sends nothing, a button event still does;
--   5. Sort: calls lane IH's real grug_inventory.sort (counted through a
--      wrapper; it sorts main[9..]), ignores clicks for 2.5 s after one it
--      ran, never resends; the potion belt drawn from IH's constants;
--   6. refresh: a bag change re-renders a page with a view, a stat change
--      only the Character page; the deposit slot on the Inventory page, not
--      on the Character page;
--   7. every built formspec passes a bracket sanity check; the Inventory
--      page's bytes with four 32-slot bags are printed (a comparison, not a
--      target).
--
-- Usage (repo root): luajit tools/r44_fr/portable_test.lua [repo]

local repo = arg and arg[1] or "."
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

local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
end

-- Formspec sanity as the engine parses it (guiFormSpecMenu.cpp
-- regenerateGui, parseElement): the string splits at every unescaped "]",
-- and each piece is a name, a "[" and the element's fields (a raw "[" inside,
-- as in a texture's "^[multiply", is fine). Nothing may trail the last "]".
local function formspec_ok(fs, label)
	local piece, i = {}, 1
	while i <= #fs do
		local c = fs:sub(i, i)
		if c == "\\" then
			piece[#piece + 1] = fs:sub(i, i + 1)
			i = i + 1
		elseif c == "]" then
			local text = table.concat(piece)
			if not text:match("^[%a_]+%[") then
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
-- Stubs
--

-- Stacks without metadata: enough for the views and for the real sort.
local stack_methods = {}
local stack_meta = {__index = stack_methods}
function ItemStack(value)
	local name, count = "", 0
	if type(value) == "table" then
		name, count = value.name, value.count
	elseif type(value) == "string" and value ~= "" then
		local n, c = value:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	end
	return setmetatable({name = name, count = count}, stack_meta)
end
function stack_methods:is_empty() return self.name == "" or self.count <= 0 end
function stack_methods:get_name() return self.name end
function stack_methods:get_count() return self.count end
function stack_methods:set_count(count) self.count = count end
function stack_methods:get_description() return self.name end
function stack_methods:get_stack_max() return 99 end
function stack_methods:get_definition() return core.registered_items[self.name] end
function stack_methods:get_meta() return {get_int = function() return 0 end} end
function stack_methods:to_string()
	if self:is_empty() then return "" end
	return self.count == 1 and self.name or self.name .. " " .. self.count
end
function stack_methods:add_item(other)
	other = ItemStack(other)
	if self:is_empty() then
		self.name, self.count = other.name, other.count
		return ItemStack("")
	end
	if other.name ~= self.name then return other end
	local moved = math.min(other.count, 99 - self.count)
	self.count = self.count + moved
	other.count = other.count - moved
	return other:is_empty() and ItemStack("") or other
end

local mods_loaded, receive_handlers = {}, {}
local now_us = 0
core = {
	formspec_escape = fs_escape,
	colorize = function(_, text) return text end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_inventory" end,
	get_current_modname = function() return "grug_inventory" end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	register_globalstep = function() end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_player_receive_fields = function(fn)
		receive_handlers[#receive_handlers + 1] = fn
	end,
	log = function() end,
	get_player_window_information = function() return nil end,
	get_us_time = function() return now_us end,
	registered_items = {
		["default:dirt"] = {description = "Dirt", groups = {}},
		["test:sword"] = {description = "Sword", groups = {grug_equip_weapon = 1}},
	},
	is_creative_enabled = function() return false end,
	register_craftitem = function() end,
	register_allow_player_inventory_action = function() end,
	register_on_player_inventory_action = function() end,
	register_on_item_pickup = function() end,
	strip_colors = function(text) return text end,
}
function core.get_item_group(name, group)
	local def = core.registered_items[name]
	return def and def.groups and def.groups[group] or 0
end
minetest = core
dump = function(value) return tostring(value) end

local stat_hooks = {}
grug_core = {
	register_on_equipment_change = function(fn) stat_hooks.equipment = fn end,
	register_on_status_modifiers_changed = function(fn) stat_hooks.status = fn end,
	status_effects = function() return {} end,
	status_icons = {remaining_text = function() return "" end},
	get_armor_rating = function() return 10 end,
	armor_reduction = function() return 0.1 end,
	get_player_level = function() return 10 end,
}
grug_xp = {register_on_level_change = function(fn) stat_hooks.level = fn end}
grug_money = {
	register_on_change = function(fn) stat_hooks.money = fn end,
	deposit_location = function(player)
		return "detached:grug_money_deposit_" .. player:get_player_name(), "deposit"
	end,
	format = function(value) return tostring(value) .. "c" end,
	get = function() return 12345 end,
}
grug_classes = {
	get_class_def = function() return {resource = "mana", name = "Mage"} end,
	get_pool_breakdown = function() return {final = 100} end,
	get_crit_chance = function() return 0.05 end,
	get_dodge_chance = function() return 0.05 end,
	get_class = function() return "mage" end,
}
player_api = {registered_models = {["character.b3d"] = {textures = {"character.png"}}}}

-- grug_inventory as equipment.lua leaves it; bags.lua and storage.lua are
-- the real files (loaded below).
grug_inventory = {
	equipment_slots = {
		{list = "grug_head", label = "Head"}, {list = "grug_chest", label = "Chest"},
		{list = "grug_legs", label = "Legs"}, {list = "grug_feet", label = "Feet"},
		{list = "grug_weapon", label = "Weapon"}, {list = "grug_offhand", label = "Offhand"},
		{list = "grug_trinket1", label = "Trinket"}, {list = "grug_trinket2", label = "Trinket"},
	},
	slot_label = function(_, list) return list end,
	slot_ghost = function() return nil end,
	SHIFT_LIST = "grug_shift", -- equipment.lua's shift-click routing list
}

-- Players: lists by name; set_inventory_formspec counts sends.
local function make_player(name, lists)
	local player = {sent = 0, formspec = nil}
	local inv = {}
	function inv:get_size(list) return lists[list] and #lists[list] or 0 end
	function inv:get_stack(list, index) return ItemStack(lists[list] and lists[list][index] or "") end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for index, value in ipairs(lists[list]) do out[index] = ItemStack(value) end
		return out
	end
	function inv:set_stack(list, index, stack)
		lists[list][index] = ItemStack(stack):to_string()
	end
	function inv:is_empty(list)
		for _, v in ipairs(lists[list] or {}) do if v ~= "" then return false end end
		return true
	end
	function player.get_player_name() return name end
	function player.get_inventory() return inv end
	function player.get_properties()
		return {visual = "mesh", mesh = "character.b3d", textures = {"character.png"}}
	end
	function player.get_meta() return {get_string = function() return "" end} end
	function player.set_inventory_formspec(_, fs)
		player.sent = player.sent + 1
		player.formspec = fs
	end
	player.lists = lists
	return player
end

local function slots(n)
	local out = {}
	for i = 1, n do out[i] = "" end
	return out
end
-- `bags`: content size per bag slot (0 = no bag).
local function lists_with_bags(bags)
	local lists = {main = slots(32), grug_potion_belt = slots(4)}
	for i = 1, 4 do
		local size = bags[i] or 0
		lists["grug_bag" .. i] = {size > 0 and "grug_inventory:bag" or ""}
		lists["grug_bag" .. i .. "_content"] = slots(size)
	end
	return lists
end

--
-- Load the real files. Page mods register in a scrambled order (the old
-- hooks depended on load order); creative's tab is not in the table.
--

dofile(repo .. "/mods/BASE/sfinv/api.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/bags.lua")
-- The real sort, counted.
local sorts, real_sort = 0, grug_inventory.sort
grug_inventory.sort = function(player)
	sorts = sorts + 1
	return real_sort(player)
end
local function stub_page(name, title, show_inv, extra)
	local def = {title = title, get = function(_, player, context)
		return sfinv.make_formspec(player, context, "label[0,0;" .. title .. "]", show_inv)
	end}
	for k, v in pairs(extra or {}) do def[k] = v end
	sfinv.register_page(name, def)
end
local page_calls = 0
stub_page("grug_pvp:pvp", "PvP", true)
stub_page("grug_classes:talents", "Talents", true, {
	on_player_receive_fields = function(_, player, context, fields)
		page_calls = page_calls + 1
		sfinv.set_player_inventory_formspec(player, context)
		return true
	end})
stub_page("grug_map:atlas", "Map", false)
stub_page("sfinv:crafting", "Crafting", true)
dofile(repo .. "/mods/PLAYER/grug_inventory/ui.lua")
stub_page("grug_inventory:help", "Help", true)
dofile(repo .. "/mods/PLAYER/grug_inventory/pages.lua")
stub_page("grug_quests:quests", "Quests", true)
stub_page("grug_skills:skills", "Skills", true)
stub_page("grug_parties:group", "Party", true)
stub_page("creative:all", "All", true, {is_in_nav = function() return false end})
for _, fn in ipairs(mods_loaded) do fn() end
local receive = receive_handlers[1]

--
-- 1. Tab order
--

local order = {}
for _, def in ipairs(sfinv.pages_unordered) do order[#order + 1] = def.name end
eq(table.concat(order, ","), "grug_inventory:inventory,grug_inventory:character," ..
	"grug_classes:talents,grug_skills:skills,sfinv:crafting,grug_parties:group," ..
	"grug_pvp:pvp,grug_inventory:help,grug_quests:quests,grug_map:atlas,creative:all",
	"tab order follows TAB_ORDER, other pages after it")
eq(sfinv.get_homepage_name(), "grug_inventory:inventory", "Inventory is the homepage")
check(sfinv.pages["grug_inventory:bags"] == nil, "the Bags page is gone")

local plain = make_player("plain", lists_with_bags({}))
local context = sfinv.get_or_create_context(plain)
eq(context.page, "grug_inventory:inventory", "a new context opens Inventory")
local form = sfinv.get_formspec(plain, context)
has(form, "tabheader[0,0;sfinv_nav_tabs;Inventory,Character,Talents,Skills,Crafting," ..
	"Party,PvP,Help,Quests,Map;1;true;false]", "the tab captions in order, Inventory selected")

-- No page mod keeps an ordering hook.
for _, file in ipairs({"mods/PLAYER/grug_classes/talents_ui.lua",
		"mods/PLAYER/grug_skills/page.lua", "mods/PLAYER/grug_quests/ui.lua",
		"mods/PLAYER/grug_parties/ui.lua", "mods/PLAYER/grug_pvp/page.lua",
		"mods/PLAYER/grug_inventory/pages.lua"}) do
	local handle = assert(io.open(repo .. "/" .. file))
	local text = handle:read("*a")
	handle:close()
	lacks(text, "pages_unordered", file .. " leaves the tab order alone")
end

--
-- 2. The frame
--

local legacy_w = 3 / 4 + 5 / 4 * (10.4 - 1) + 1
local legacy_h = 3 / 4 + 15 / 13 * (11.1 - 1) + 1 + 15 / 13 * 0.35 * 2 / 3
eq(form:sub(1, #"formspec_version[6]size[13.500,13.673]"),
	"formspec_version[6]size[13.500,13.673]", "fv6 frame, real-coordinate size first")
check(math.abs(grug_inventory.UI.frame_w - legacy_w) < 1e-9 and
	math.abs(grug_inventory.UI.frame_h - legacy_h) < 1e-9,
	"the frame is the old legacy 10.4 x 11.1 window")
context.page = "grug_inventory:help"
local help = sfinv.get_formspec(plain, context)
local rc_false = help:find("real_coordinates[false]", 1, true)
check(rc_false and rc_false < help:find("label[0,0;Help]", 1, true),
	"legacy content follows real_coordinates[false]")
check(help:find("scroll_container[", 1, true) < rc_false,
	"the view is drawn before the legacy content")
context.page = "grug_map:atlas"
sfinv.pages["grug_map:atlas"].get = function(_, player, ctx)
	return sfinv.make_formspec(player, ctx, "label[0,0;Map]", false,
		"formspec_version[4]size[10.4,11.1]real_coordinates[false]")
end
local map = sfinv.get_formspec(plain, context)
eq(map:sub(1, 52), "formspec_version[4]size[10.4,11.1]real_coordinates[f",
	"a page's own header stays first")
lacks(map, "formspec_version[6]", "no second header on the Map tab")
lacks(map, "list[current_player;main", "the Map tab has no inventory")
eq(context.grug_inv_view, nil, "no view recorded for the Map tab")
formspec_ok(form, "Inventory form")
formspec_ok(help, "Help form")

--
-- 3. The views with 0-4 bags of mixed sizes
--

local function list_elements(fs)
	local out = {}
	for list, x, y, w, h, start in fs:gmatch(
			"list%[current_player;([%w_]+);([%d.]+),([%d.]+);(%d+),(%d+);(%d*)%]") do
		out[#out + 1] = {list = list, x = tonumber(x), y = tonumber(y),
			w = tonumber(w), h = tonumber(h), start = tonumber(start) or 0}
	end
	return out
end
local function scroll_part(fs)
	return fs:match("scroll_container%[(.-)scroll_container_end%[%]")
end
local function hotbar_y(fs)
	local y = fs:match("list%[current_player;main;[%d.]+,([%d.]+);8,1;%]")
	return tonumber(y)
end

local cases = {
	{label = "no bags", bags = {}},
	{label = "one 8-slot bag", bags = {8}},
	{label = "16 and 24, slot 2 empty", bags = {16, 0, 24}},
	{label = "four mixed", bags = {32, 8, 24, 16}},
	{label = "four 32", bags = {32, 32, 32, 32}},
}
local hotbars = {}
for _, case in ipairs(cases) do
	local player = make_player("p", lists_with_bags(case.bags))
	local expected_lists, total = {{"main", 3, 8}}, 24
	for i = 1, 4 do
		local size = case.bags[i] or 0
		if size > 0 then
			expected_lists[#expected_lists + 1] = {"grug_bag" .. i .. "_content", size / 8, 0}
			total = total + size
		end
	end
	for _, mode in ipairs({"full", "short"}) do
		local view = grug_inventory.inventory_view(player, mode, {})
		local label = case.label .. ", " .. mode
		formspec_ok(view, label)
		local inner = list_elements(scroll_part(view) or "")
		eq(#inner, #expected_lists, label .. ": lists in the scroll area")
		local count, row = 0, 0
		for index, element in ipairs(inner) do
			local want = expected_lists[index] or {}
			eq(element.list, want[1], label .. ": list " .. index)
			eq(element.h, want[2], label .. ": rows of list " .. index)
			eq(element.start, want[3], label .. ": start of list " .. index)
			eq(element.w, 8, label .. ": 8 wide")
			check(math.abs(element.y - row * 1.25) < 1e-6, label .. ": no gap before list " .. index)
			row = row + element.h
			count = count + element.w * element.h
		end
		eq(count, total, label .. ": slots in the scroll area")
		hotbars[mode] = hotbar_y(view)
		check(hotbars[mode] ~= nil, label .. ": the hotbar row")
		local visible = grug_inventory.VIEW_ROWS[mode]
		local max = view:match("scrollbaroptions%[min=0;max=(%d+);")
		if row > visible then
			eq(tonumber(max), (row - visible) * 10, label .. ": scroll range")
			has(view, "scrollbar[", label .. ": a scrollbar")
			-- The options are reset to the engine's defaults right after the
			-- view's scrollbar, so a page's own scrollbar[] later in the form
			-- does not inherit them.
			local after = view:match("scrollbar%[[^%]]*%](.*)$")
			eq(after and after:match("^scrollbaroptions%[[^%]]*%]"),
				"scrollbaroptions[min=0;max=1000;smallstep=10;largestep=100;" ..
				"thumbsize=1;arrows=default]", label .. ": options reset after the scrollbar")
			local last = nil
			for options in view:gmatch("scrollbaroptions%[([^%]]*)%]") do last = options end
			eq(last, "min=0;max=1000;smallstep=10;largestep=100;thumbsize=1;arrows=default",
				label .. ": the last options in the view are the defaults")
		else
			eq(max, nil, label .. ": no scroll range when it fits")
			lacks(view, "scrollbar[", label .. ": no scrollbar when it fits")
		end
		lacks(view, "listring", label .. ": no listring in the view")
		-- The hotbar sits below the scroll area, outside it.
		local area_y, area_h = view:match("scroll_container%[[%d.]+,([%d.]+);[%d.]+,([%d.]+);")
		check(tonumber(area_y) + tonumber(area_h) <= hotbars[mode],
			label .. ": the hotbar is below the scroll area")
	end
	eq(hotbars.full, hotbars.short, case.label .. ": the hotbar at one place in both views")
end
-- The short view is the hotbar + two rows; the full view starts below the
-- Inventory tab's top row and its rows fit the window.
local short_view = grug_inventory.inventory_view(plain, "short", {})
local _, short_y, _, short_h = short_view:match(
	"scroll_container%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);")
eq(tonumber(short_h), 2.25, "short view: two rows high")
check(tonumber(short_y) > 0.375 + 7 * 15 / 13, "short view below legacy content (y 7.0)")
check(hotbars.full + 1 <= grug_inventory.UI.frame_h, "the hotbar fits the window")

--
-- The Inventory page
--

local four = make_player("four", lists_with_bags({32, 32, 32, 32}))
local four_context = sfinv.get_or_create_context(four)
local inventory = sfinv.get_formspec(four, four_context)
formspec_ok(inventory, "Inventory page")
eq(four_context.grug_inv_view, "full", "the Inventory page shows the full view")
for i = 1, 4 do
	has(inventory, "list[current_player;grug_bag" .. i .. ";", "bag slot " .. i)
end
has(inventory, ("list[current_player;%s;"):format(grug_inventory.POTION_BELT),
	"the potion belt, IH's list")
has(inventory, ";" .. grug_inventory.POTION_BELT_SIZE .. ",1;]", "the belt's slots")
has(inventory, "list[detached:grug_money_deposit_four;deposit;", "the coin deposit")
has(inventory, "button[", "a button")
has(inventory, ";grug_inv_sort;Sort]", "the Sort button")
lacks(inventory, "listring", "no listring on the Inventory page")
local count = 0
for _, element in ipairs(list_elements(scroll_part(inventory))) do
	count = count + element.w * element.h
end
eq(count, 24 + 4 * 32, "the Inventory page shows 152 slots in its grid")
print(("bytes: Inventory page with four 32-slot bags %d"):format(#inventory))

four_context.page = "grug_inventory:character"
four_context.grug_character_tab = "stats" -- the balance's mode (Round 44 lane CH)
local character = sfinv.get_formspec(four, four_context)
formspec_ok(character, "Character page")
lacks(character, "deposit;", "no deposit on the Character page")
has(character, "grug_money_withdraw;Withdraw]", "Withdraw stays beside the balance")
eq(four_context.grug_inv_view, "short", "the Character page shows the short view")
print(("bytes: Character page (Stats) with four 32-slot bags %d"):format(#character))
four_context.page = "grug_inventory:inventory"

--
-- 4. Scrollbar echo, no resend on a pure scrollbar event
--

local scroller = make_player("scroller", lists_with_bags({32, 32, 32, 32}))
scroller.lists.main[1] = "default:dirt 3"
scroller.lists.main[12] = "default:dirt 5"
scroller.lists.grug_bag2_content[3] = "test:sword"
local ctx = sfinv.get_or_create_context(scroller)
sfinv.set_player_inventory_formspec(scroller, ctx)
local sends = scroller.sent
eq(receive(scroller, "", {grug_inv_scroll_full = "CHG:70"}), true,
	"a pure scrollbar event is handled")
eq(scroller.sent, sends, "a pure scrollbar event sends nothing")
eq(ctx.grug_inv_scroll.full, 70, "its value is kept")
has(sfinv.get_formspec(scroller, ctx), ";vertical;grug_inv_scroll_full;70]",
	"the next build echoes it")
-- Above the range: clamped (19 rows, 8 visible: 110).
receive(scroller, "", {grug_inv_scroll_full = "CHG:500"})
has(sfinv.get_formspec(scroller, ctx), ";vertical;grug_inv_scroll_full;110]",
	"an out-of-range value is clamped on the echo")
-- Sort: a button event carries VAL; the value is kept and the page acts.
now_us = 10000000
local sorted = sorts
eq(receive(scroller, "", {grug_inv_scroll_full = "VAL:40", grug_inv_sort = "Sort"}), true,
	"Sort is handled")
eq(sorts, sorted + 1, "Sort sorts")
eq(scroller.lists.main[9], "test:sword", "the real sort put the sword first")
eq(scroller.lists.main[10], "default:dirt 5", "then the dirt")
eq(scroller.lists.main[1], "default:dirt 3", "the hotbar untouched")
eq(ctx.grug_inv_scroll.full, 40, "a button event keeps the scroll value too")
eq(scroller.sent, sends, "Sort sends no formspec")
now_us = now_us + 1000000
receive(scroller, "", {grug_inv_scroll_full = "VAL:40", grug_inv_sort = "Sort"})
eq(sorts, sorted + 1, "a click within the cooldown is ignored")
now_us = now_us + 1000000
receive(scroller, "", {grug_inv_sort = "Sort"})
eq(sorts, sorted + 1, "still ignored at 2 s")
now_us = now_us + 600000
receive(scroller, "", {grug_inv_sort = "Sort"})
eq(sorts, sorted + 2, "accepted again after 2.5 s")
eq(scroller.sent, sends, "the cooldown never sends either")
-- A bag removed: the stored value is clamped to the smaller range.
scroller.lists.grug_bag4_content, scroller.lists.grug_bag3_content = {}, {}
ctx.grug_inv_scroll.full = 110
has(sfinv.get_formspec(scroller, ctx), ";vertical;grug_inv_scroll_full;30]",
	"after a bag change the echo clamps to the new range (11 rows: 30)")

-- On another page: the short view's own value; a scrollbar event never
-- reaches the page handler, a button event does.
ctx.page = "grug_classes:talents"
sfinv.set_player_inventory_formspec(scroller, ctx)
sends, page_calls = scroller.sent, 0
eq(receive(scroller, "", {grug_inv_scroll_short = "CHG:20", grug_cloak = "Plain"}), true,
	"a pure scrollbar event on a page is handled")
eq(page_calls, 0, "the page handler does not see it")
eq(scroller.sent, sends, "and nothing is sent")
eq(ctx.grug_inv_scroll.short, 20, "the short view keeps its own value")
eq(ctx.grug_inv_scroll.full, 110, "the full view's value is untouched")
receive(scroller, "", {grug_inv_scroll_short = "VAL:20", grug_talent_pick_1 = "x"})
eq(page_calls, 1, "a button event reaches the page")
has(scroller.formspec, ";vertical;grug_inv_scroll_short;20]", "and its resend echoes the value")
-- A tab switch keeps the value for the next page.
receive(scroller, "", {sfinv_nav_tabs = "1", grug_inv_scroll_short = "VAL:10"})
eq(ctx.page, "grug_inventory:inventory", "the tab switch went to Inventory")
eq(ctx.grug_inv_scroll.short, 10, "a tab event keeps the value too")

--
-- 6. Refresh
--

local refresher = make_player("refresher", lists_with_bags({8}))
local rctx = sfinv.get_or_create_context(refresher)
rctx.page = "grug_skills:skills"
sfinv.set_player_inventory_formspec(refresher, rctx)
local before = refresher.sent
refresher.lists.grug_bag2_content = slots(16)
grug_inventory.refresh(refresher)
eq(refresher.sent, before + 1, "a bag change re-renders a page with a view")
has(refresher.formspec, "list[current_player;grug_bag2_content;", "with the new bag's list")
stat_hooks.status(refresher)
stat_hooks.level(refresher, 1, 2)
stat_hooks.equipment(refresher, "grug_head", "equip")
eq(refresher.sent, before + 1, "stat changes do not re-render other pages")
rctx.page = "grug_inventory:inventory"
sfinv.set_player_inventory_formspec(refresher, rctx)
before = refresher.sent
stat_hooks.status(refresher)
eq(refresher.sent, before, "nor the Inventory page")
rctx.page = "grug_inventory:character"
sfinv.set_player_inventory_formspec(refresher, rctx)
before = refresher.sent
stat_hooks.status(refresher)
eq(refresher.sent, before + 1, "a stat change re-renders the Character page")
rctx.page = "grug_map:atlas"
sfinv.set_player_inventory_formspec(refresher, rctx)
before = refresher.sent
grug_inventory.refresh(refresher)
eq(refresher.sent, before, "a bag change leaves the Map tab alone")

print(("r44_fr: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("r44_fr: %d failures"):format(failures)) end
