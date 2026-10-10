-- Round 44 lane FR portable test: the inventory window. Loads the REAL
-- vendored sfinv (mods/BASE/sfinv/api.lua) and grug_inventory's bags.lua
-- (with lane IH's storage.lua), ui.lua and pages.lua under a minimal `core`
-- stub and checks:
--   1. the tab order: one table (grug_inventory.TAB_ORDER) whatever the
--      registration order, pages missing from it after it, the Inventory
--      page as the homepage, no ordering hook left in the page mods;
--   2. the frame: formspec_version 6 with a real-coordinate size equal to the
--      old legacy size[10.4,11.1] (every tab keeps it; the boxed layout with
--      seven rows and the money row fits it, Round 45 playtest), legacy
--      content after real_coordinates[false], a page's own header (the Map
--      tab) left alone;
--   3. the views, full and short, with 0-4 bags of mixed sizes: main[9..]
--      first, then each equipped bag's list in slot order as one 8-wide grid
--      without gaps, the hotbar outside the scroll area and at one place in
--      both views, both views boxed (an Inventory and a Hotbar box, labelled
--      inside), slot counts, the scrollbar only when the grid is taller than
--      the view with a thumb shorter than its track, no listring on the
--      Inventory page; the Inventory page's boxed layout (Round 45 playtest:
--      a box and label per area, edges; the money row between the grid and
--      the hotbar: the balance, Withdraw, the deposit, Sort, as tall as a
--      slot, on the slot columns);
--      the view's scrollbaroptions reset to the engine defaults after its
--      scrollbar, so page scrollbars do not inherit them;
--   4. the scrollbar echo: CHG and VAL values kept per view, echoed and
--      clamped on the next build; a pure scrollbar event reaches no page
--      handler and sends nothing, a button event still does;
--   5. Sort: calls lane IH's real grug_inventory.sort (counted through a
--      wrapper; it sorts main[9..]), ignores clicks for 2.5 s after one it
--      ran, never resends; the potion belt drawn from IH's constants;
--   6. refresh: a bag change re-renders a page with a view, a stat change
--      only the Character page, a balance change only the Inventory page;
--      the deposit slot and Withdraw on the Inventory page, not on the
--      Character page;
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
	withdraws = 0,
	show_withdraw = function() grug_money.withdraws = grug_money.withdraws + 1 end,
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
stub_page("grug_classes:talents", "Talents & Skills", true, {
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
stub_page("grug_parties:group", "Party & PvP", false)
stub_page("creative:all", "All", true, {is_in_nav = function() return false end})
for _, fn in ipairs(mods_loaded) do fn() end
local receive = receive_handlers[1]

--
-- 1. Tab order
--

local order = {}
for _, def in ipairs(sfinv.pages_unordered) do order[#order + 1] = def.name end
eq(table.concat(order, ","), "grug_inventory:inventory,grug_inventory:character," ..
	"grug_classes:talents,sfinv:crafting,grug_parties:group," ..
	"grug_map:atlas,grug_inventory:help,creative:all", -- the map before Help since 0.45.1
	"tab order follows TAB_ORDER, other pages after it")
eq(sfinv.get_homepage_name(), "grug_inventory:inventory", "Inventory is the homepage")
check(sfinv.pages["grug_inventory:bags"] == nil, "the Bags page is gone")

local plain = make_player("plain", lists_with_bags({}))
local context = sfinv.get_or_create_context(plain)
eq(context.page, "grug_inventory:inventory", "a new context opens Inventory")
local form = sfinv.get_formspec(plain, context)
has(form, "tabheader[0,0;sfinv_nav_tabs;Inventory,Character,Talents & Skills,Crafting," ..
	"Party & PvP,Map,Help;1;true;false]", "the tab captions in order, Inventory selected")

-- No page mod keeps an ordering hook.
for _, file in ipairs({"mods/PLAYER/grug_classes/talents_ui.lua",
		"mods/PLAYER/grug_skills/page.lua", "mods/PLAYER/grug_map/quest_box.lua",
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
local L = grug_inventory.LAYOUT
local frame_h = grug_inventory.UI.frame_h
local header = ("formspec_version[6]size[%.3f,%.3f]"):format(legacy_w, frame_h)
eq(form:sub(1, #header), header, "fv6 frame, real-coordinate size first")
check(math.abs(grug_inventory.UI.frame_w - legacy_w) < 1e-9 and
	math.abs(frame_h - legacy_h) < 1e-9,
	"the frame is the old legacy 10.4 x 11.1 window")
-- Round 45 playtest (the user, 2026-10-09): seven rows, so the boxed layout
-- with the money row fits that window, top and bottom margins equal.
eq(grug_inventory.VIEW_ROWS.full, 7, "the full view shows seven rows")
check(math.abs(L.top_y - (frame_h - L.hotbar_box_y - L.slot_box_h)) < 1e-9 and
	L.top_y >= L.gap, "the boxed layout fits the window with equal margins")
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
			-- Round 45 playtest: the engine draws the thumb as
			-- thumbsize / (max + 1) of the track; it shows the visible share
			-- of the rows and is shorter than the track, so it can be dragged.
			local thumb = tonumber(view:match("scrollbaroptions%[min=0;max=%d+;" ..
				"smallstep=%d+;largestep=%d+;thumbsize=(%d+);arrows=hide%]"))
			eq(thumb, math.max(1, math.floor(visible * (max + 1) / row + 0.5)),
				label .. ": the thumb shows the visible share")
			check(thumb and thumb < max + 1, label .. ": the thumb is shorter than the track")
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
	-- The hotbar at one place in every tab, in its box (Round 45 playtest).
	check(math.abs(hotbars.full - (L.hotbar_box_y + L.label_h)) < 0.001,
		case.label .. ": the full view's hotbar in its box")
	eq(hotbars.short, hotbars.full, case.label .. ": the short view's hotbar at the same place")
	check(math.abs(hotbars.short - grug_inventory.VIEW_GEOMETRY.hotbar_y) < 0.001,
		case.label .. ": VIEW_GEOMETRY names it")
end
-- Both views boxed: their Inventory box (labelled inside, top left above the
-- grid) and the same Hotbar box; the short one's right above the Hotbar box,
-- its top the page content's limit (VIEW_GEOMETRY.top).
local function view_boxes(fs)
	local out = {}
	for x, y, w, h, color, lx, ly, text in fs:gmatch(
			"box%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^%]]+)%]" ..
			"label%[([%d.]+),([%d.]+);([^%]]+)%]") do
		out[text] = {x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h),
			color = color, lx = tonumber(lx), ly = tonumber(ly)}
	end
	return out
end
do
	local four_bags = make_player("vb", lists_with_bags({32, 32, 32, 32}))
	local full_view = grug_inventory.inventory_view(four_bags, "full", {})
	local short_view = grug_inventory.inventory_view(four_bags, "short", {})
	local full, short = view_boxes(full_view), view_boxes(short_view)
	for _, pair in ipairs({{"full", full, full_view}, {"short", short, short_view}}) do
		local mode, boxes, view = pair[1], pair[2], pair[3]
		local inv, hot = boxes.Inventory, boxes.Hotbar
		if check(inv and hot, mode .. " view: an Inventory and a Hotbar box") then
			eq(inv.color, grug_inventory.BOX_COLOR, mode .. " view: the Inventory box colour")
			eq(hot.color, "#8a682f44", mode .. " view: the Hotbar box's gold")
			local gx, gy = view:match("scroll_container%[([%d.]+),([%d.]+);")
			check(math.abs(inv.lx - tonumber(gx)) < 0.002 and inv.ly > inv.y and
				inv.ly < tonumber(gy), mode .. " view: the label inside, top left above the grid")
			local sb_x, sb_w = view:match("scrollbar%[([%d.]+),[%d.]+;([%d.]+),")
			check(tonumber(sb_x) + tonumber(sb_w) < inv.x + inv.w,
				mode .. " view: the scrollbar inside the Inventory box")
			check(math.abs(inv.x - hot.x) < 0.002 and math.abs(inv.w - hot.w) < 0.002,
				mode .. " view: the boxes on one left edge, equally wide")
			check(inv.y + inv.h < hot.y, mode .. " view: the Inventory box above the Hotbar box")
		end
	end
	if full.Hotbar and short.Hotbar and short.Inventory then
		check(full.Hotbar.x == short.Hotbar.x and full.Hotbar.y == short.Hotbar.y,
			"the Hotbar box at the same place in both views")
		check(math.abs(short.Inventory.y + short.Inventory.h + L.gap - short.Hotbar.y) < 0.002,
			"the short Inventory box right above the Hotbar box")
		check(math.abs(short.Inventory.y - grug_inventory.VIEW_GEOMETRY.top) < 0.002,
			"VIEW_GEOMETRY.top is the short Inventory box's top")
	end
	lacks(short_view, "label[0.3", "no Hotbar label left of the short view any more")
end
-- The short view is the hotbar + two rows; the full view starts below the
-- Inventory tab's top row and its rows fit the window.
local short_view = grug_inventory.inventory_view(plain, "short", {})
local _, short_y, _, short_h = short_view:match(
	"scroll_container%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);")
eq(tonumber(short_h), 2.25, "short view: two rows high")
check(tonumber(short_y) > 0.375 + 7 * 15 / 13, "short view below legacy content (y 7.0)")
check(hotbars.full + 1 <= grug_inventory.UI.frame_h, "the hotbar fits the window")
check(grug_inventory.VIEW_GEOMETRY.top > 0.375 + 7 * 15 / 13,
	"the short view's box below legacy content (y 7.0)")

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

-- The boxed layout (Round 45 playtest): one box per area with its label
-- inside, top left above the slots; Bags, Inventory and Hotbar on one left
-- edge; Bags and Potion belt share the width, ending where Inventory and
-- Hotbar end; the group centred. Between the Inventory and the Hotbar box
-- the money row: "Money" over the balance, Withdraw, the deposit slot and
-- Sort, as tall as a slot, on the slot columns, Sort ending with the
-- hotbar's last slot. No Coins box.
local function num(value) return tonumber(value) end
local boxes = view_boxes(inventory)
local function close(a, b) return a and b and math.abs(a - b) < 0.002 end
local function slot_at(pattern)
	local x, y = inventory:match(pattern)
	return num(x), num(y)
end
local slot_x = {}
local slot_y = {}
slot_x.Bags, slot_y.Bags = slot_at("list%[current_player;grug_bag1;([%d.]+),([%d.]+);1,1;%]")
slot_x["Potion belt"], slot_y["Potion belt"] = slot_at(
	"list%[current_player;" .. grug_inventory.POTION_BELT .. ";([%d.]+),([%d.]+);")
slot_x.Inventory, slot_y.Inventory = slot_at("scroll_container%[([%d.]+),([%d.]+);")
slot_x.Hotbar, slot_y.Hotbar = slot_at("list%[current_player;main;([%d.]+),([%d.]+);8,1;%]")
local frame = grug_inventory.UI
check(boxes.Coins == nil, "no Coins box")
for _, name in ipairs({"Bags", "Potion belt", "Inventory", "Hotbar"}) do
	local box = boxes[name]
	check(box ~= nil, name .. ": its own box with its label")
	if box then
		eq(box.color, name == "Hotbar" and "#8a682f44" or grug_inventory.BOX_COLOR,
			name .. ": the box colour")
		check(close(box.lx, slot_x[name]), name .. ": the label at the slots' left edge")
		check(box.ly > box.y and box.ly < slot_y[name], name .. ": the label above the slots")
		check(slot_x[name] > box.x and slot_y[name] > box.y, name .. ": the slots inside the box")
		check(box.x >= 0 and box.y >= 0 and box.x + box.w <= frame.frame_w and
			box.y + box.h <= frame.frame_h, name .. ": inside the window")
	end
end
if boxes.Bags and boxes.Inventory and boxes.Hotbar and boxes["Potion belt"] then
	check(close(slot_x.Bags, slot_x.Inventory) and close(slot_x.Bags, slot_x.Hotbar),
		"Bags, Inventory and Hotbar on one left edge")
	check(close(boxes.Bags.x, boxes.Inventory.x) and close(boxes.Bags.x, boxes.Hotbar.x),
		"their boxes on one left edge")
	local belt_right = boxes["Potion belt"].x + boxes["Potion belt"].w
	check(close(boxes.Inventory.x + boxes.Inventory.w, belt_right) and
		close(boxes.Hotbar.x + boxes.Hotbar.w, belt_right),
		"Bags and Potion belt end where Inventory and Hotbar end")
	check(close(boxes.Bags.w, boxes["Potion belt"].w) and
		close(boxes.Bags.y, boxes["Potion belt"].y), "Bags and Potion belt share the width")
	check(close(boxes.Bags.x, frame.frame_w - belt_right), "the group centred")
	check(close(boxes.Bags.y, frame.frame_h - boxes.Hotbar.y - boxes.Hotbar.h),
		"top and bottom margins equal")
	check(boxes.Inventory.y > boxes.Bags.y + boxes.Bags.h and
		boxes.Hotbar.y > boxes.Inventory.y + boxes.Inventory.h, "the boxes do not overlap")
	-- The money row.
	local inv_bottom, hot_top = boxes.Inventory.y + boxes.Inventory.h, boxes.Hotbar.y
	local ly, money = inventory:match("label%[[%d.]+,([%d.]+);Money\n([^%]]*)%]")
	local lx = num(inventory:match("label%[([%d.]+),[%d.]+;Money\n"))
	eq(money, "12345c", "the balance under Money")
	local wx, wy, ww, wh = inventory:match(
		"button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_money_withdraw;Withdraw%]")
	local dx, dy = slot_at("list%[detached:[^;]+;deposit;([%d.]+),([%d.]+);1,1;%]")
	local sx, sy, sw, sh = inventory:match(
		"button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_inv_sort;Sort%]")
	wx, wy, ww, wh, sx, sy, sw, sh = num(wx), num(wy), num(ww), num(wh), num(sx),
		num(sy), num(sw), num(sh)
	if check(lx and wx and dx and sx, "the money row: balance, Withdraw, deposit, Sort") then
		check(close(wh, 1) and close(sh, 1), "Withdraw and Sort as tall as the slot")
		check(close(wy, dy) and close(sy, dy), "one row: Withdraw, deposit and Sort level")
		check(dy > inv_bottom and dy + 1 < hot_top, "the row between Inventory and Hotbar")
		check(close(dy - inv_bottom, hot_top - dy - 1), "the row centred in its gap")
		check(close(num(ly), dy + 0.25), "Money and the balance centred on the slot's halves")
		check(close(lx, slot_x.Hotbar) and lx < wx and wx + ww < dx and dx + 1 < sx,
			"left to right: balance, Withdraw, deposit, Sort")
		check(close(sx + sw, slot_x.Hotbar + 7 * 1.25 + 1),
			"Sort ends with the hotbar's last slot")
		for _, x in ipairs({wx, dx, sx}) do
			check(close((x - slot_x.Hotbar) / 1.25, math.floor((x - slot_x.Hotbar) / 1.25 + 0.5)),
				"the row on the slot columns")
		end
		has(inventory, ("image[%.3f,%.3f;1,1;grug_money_bag_of_coins.png^[multiply:#666666]")
			:format(dx, dy), "the deposit slot's ghost as before")
	end
end
-- Withdraw on the Inventory page opens grug_money's dialog.
local withdraws = grug_money.withdraws
eq(receive(four, "", {grug_money_withdraw = "Withdraw"}), true, "Withdraw is handled")
eq(grug_money.withdraws, withdraws + 1, "Withdraw opens the dialog")

four_context.page = "grug_inventory:character"
four_context.grug_character_tab = "stats" -- the balance's mode (Round 44 lane CH)
local character = sfinv.get_formspec(four, four_context)
formspec_ok(character, "Character page")
lacks(character, "deposit;", "no deposit on the Character page")
lacks(character, "grug_money_withdraw", "no Withdraw on the Character page")
lacks(character, "Money", "no balance on the Character page")
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
-- Above the range: clamped (19 rows, 7 visible: 120).
receive(scroller, "", {grug_inv_scroll_full = "CHG:500"})
has(sfinv.get_formspec(scroller, ctx), ";vertical;grug_inv_scroll_full;120]",
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
has(sfinv.get_formspec(scroller, ctx), ";vertical;grug_inv_scroll_full;40]",
	"after a bag change the echo clamps to the new range (11 rows: 40)")

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
rctx.page = "grug_classes:talents"
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
-- A balance change re-sends the Inventory page (the money row), nothing else.
before = refresher.sent
stat_hooks.money(refresher)
eq(refresher.sent, before, "a balance change leaves the Character page alone")
rctx.page = "grug_inventory:inventory"
sfinv.set_player_inventory_formspec(refresher, rctx)
before = refresher.sent
stat_hooks.money(refresher)
eq(refresher.sent, before + 1, "a balance change re-sends the Inventory page")
rctx.page = "grug_map:atlas"
sfinv.set_player_inventory_formspec(refresher, rctx)
before = refresher.sent
grug_inventory.refresh(refresher)
eq(refresher.sent, before, "a bag change leaves the Map tab alone")

print(("r44_fr: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(("r44_fr: %d failures"):format(failures)) end
