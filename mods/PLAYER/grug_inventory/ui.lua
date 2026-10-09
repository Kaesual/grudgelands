-- The inventory window (Round 44 lane FR, docs/design/inventory_equipment.md
-- §1): the frame every sfinv page is drawn in, the fixed tab order and the
-- two inventory views. Plus the shared selection style, plain-text wrapping
-- and the creative Food category.
--
-- The frame is formspec_version 6 with real coordinates, the same window as
-- the old legacy size[10.4,11.1] frame: a legacy size of W x H is
-- 3/8 + 5/4 (W - 1) + 1 + 3/8 slot units wide and 3/8 + 15/13 (H - 1) + 1 +
-- 3/8 plus two thirds of a button half-height (15/13 * 0.35) high
-- (guiFormSpecMenu.cpp regenerateGui), 13.5 x 13.673 real units. Page content
-- follows a real_coordinates[false], so pages still written in legacy
-- coordinates keep their place; a page in real coordinates starts its content
-- with real_coordinates[true]. Legacy content ends before y = 7.0
-- (content_bottom), which is real y 8.45; the inventory views sit below it.
-- The map has its own window since Round 44 (grug_map window.lua); the
-- legacy width and height below remain the old Map tab's reference size.
grug_inventory.UI = {width = 10.4, height = 11.1, inventory_y = 7.2,
	content_bottom = 7.0}
local UI = grug_inventory.UI
UI.frame_w = 3 / 4 + 5 / 4 * (UI.width - 1) + 1
UI.frame_h = 3 / 4 + 15 / 13 * (UI.height - 1) + 1 + 15 / 13 * 0.35 * 2 / 3

-- Shared selection treatment for page-local buttons. The selected state has
-- both a gold tint and a border; the unselected state has neither, so the
-- distinction remains visible without relying on colour alone.
function grug_inventory.selected_button_style(fieldname, selected)
	local field = core.formspec_escape(tostring(fieldname or ""))
	if selected then
		return ("style[%s;bgcolor=#8a682f;bgcolor_hovered=#a77f3b;" ..
			"bgcolor_pressed=#6f5427;border=true]"):format(field)
	end
	return ("style[%s;bgcolor=#3d3d3d;bgcolor_hovered=#505050;" ..
		"bgcolor_pressed=#303030;border=false]"):format(field)
end

function grug_inventory.wrap_text(value, width)
	width = width or 58
	local lines = {}
	for paragraph in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			if #line > 0 and #line + #word + 1 > width then
				lines[#lines + 1] = line
				line = word
			else
				line = line == "" and word or line .. " " .. word
			end
		end
		lines[#lines + 1] = line
	end
	return table.concat(lines, "\n")
end

--
-- Tab order (spec ruling 1): one table, not the mods' load order. Pages
-- missing from it (creative's tabs for creative players) follow in their
-- registration order. grug_classes:talents is "Talents & Skills";
-- "Party & PvP" is grug_parties's page; the quest log lives in the map
-- window (Round 44 MQ).
--
grug_inventory.TAB_ORDER = {
	"grug_inventory:inventory",
	"grug_inventory:character",
	"grug_classes:talents",
	"sfinv:crafting",
	"grug_parties:group",
	"grug_inventory:help",
	"grug_map:atlas",
}

-- Puts sfinv's page list into TAB_ORDER; run once every page is registered.
function grug_inventory.order_tabs()
	local ordered, placed = {}, {}
	for _, name in ipairs(grug_inventory.TAB_ORDER) do
		local def = sfinv.pages[name]
		if def then
			ordered[#ordered + 1] = def
			placed[name] = true
		end
	end
	for _, def in ipairs(sfinv.pages_unordered) do
		if not placed[def.name] then
			ordered[#ordered + 1] = def
		end
	end
	sfinv.pages_unordered = ordered
end

--
-- Inventory views (spec §3.1-§3.2). "full" (the Inventory tab) and "short"
-- (every other page with an inventory) both draw main[9..] and then each
-- equipped bag's content list as one 8-wide grid in a scroll_container, and
-- the hotbar (main[1..8]) below it, outside the scroll area. Bag sizes are
-- multiples of 8, so the grid has no gaps. The full view shows
-- VIEW_ROWS.full rows in the Inventory tab's boxed layout (FULL_LAYOUT); the
-- short one shows two, with the hotbar at the same place in every other tab.
-- No listring: shift-click has no job inside one inventory.
--
-- The scroll position: the client does not keep a scroll_container's
-- scrollbar across a resend, but sends its value with every event of the form
-- (CHG for the scrollbar's own event, VAL for any other;
-- guiFormSpecMenu.cpp acceptInput). sfinv.handle_scroll below keeps it in the
-- sfinv context and the view echoes it on every build, so equipping a bag or
-- sorting does not jump back to the top. A pure scrollbar event ends there,
-- before any page handler, and never causes a resend.
--
local SLOT, PITCH = 1, 1.25 -- real-coordinate slot and slot + list spacing
local VIEW_X = 1.875 -- the legacy frame's inventory column (legacy x 1.2)
local VIEW_W = 8 * SLOT + 7 * (PITCH - SLOT)
local HOTBAR_Y = 12.2
local AREA_BOTTOM = HOTBAR_Y - 0.45
local SCROLLBAR_X, SCROLLBAR_W = VIEW_X + VIEW_W + 0.15, 0.3
-- Scrollbar units per real unit: one row's pitch is ten units, one wheel
-- step (smallstep) scrolls a row.
local SCROLL_FACTOR = 0.125
local ROW_STEPS = PITCH / SCROLL_FACTOR
local SCROLLBAR_DEFAULTS = "scrollbaroptions[min=0;max=1000;smallstep=10;" ..
	"largestep=100;thumbsize=1;arrows=default]"
grug_inventory.VIEW_ROWS = {full = 8, short = 2}
-- The background of the window's boxed areas (the Character tab's boxes, the
-- Inventory tab's areas).
grug_inventory.BOX_COLOR = "#00000040"
local HOTBAR_COLOR = "#8a682f44"

grug_inventory.SCROLL_FIELDS = {full = "grug_inv_scroll_full",
	short = "grug_inv_scroll_short"}
-- Where the views sit, for pages that lay out content around them. The short
-- view's place; the full view has its own (FULL_LAYOUT below).
grug_inventory.VIEW_GEOMETRY = {x = VIEW_X, width = VIEW_W,
	hotbar_y = HOTBAR_Y, area_bottom = AREA_BOTTOM}

-- The Inventory tab's layout (Round 45 playtest): one box per area with its
-- label inside, top left above the slots -- Bags and Potion belt side by side
-- on top, Inventory (the grid and its scrollbar) and Hotbar below them, all
-- on one left edge and as wide as the top row; Coins and under it Sort in a
-- column to the right. The group is centred in the window, top and bottom
-- margins equal. Every number is a box edge or a slot corner; pages.lua draws
-- the top row from it.
do
	local pad, label_h, gap = 0.12, 0.38, 0.1
	local box_w = VIEW_W + (SCROLLBAR_X - VIEW_X - VIEW_W) + SCROLLBAR_W + 2 * pad
	local side_w = SLOT + 2 * pad
	local slot_box_h = label_h + SLOT + pad
	local grid_h = grug_inventory.VIEW_ROWS.full * PITCH - (PITCH - SLOT)
	local inventory_h = label_h + grid_h + pad
	local top_y = (UI.frame_h - (2 * slot_box_h + inventory_h + 2 * gap)) / 2
	local box_x = (UI.frame_w - (box_w + gap + side_w)) / 2
	grug_inventory.FULL_LAYOUT = {
		pad = pad, label_h = label_h, gap = gap,
		box_x = box_x, box_w = box_w, x = box_x + pad,
		side_x = box_x + box_w + gap, side_w = side_w,
		top_y = top_y, slot_box_h = slot_box_h,
		inventory_y = top_y + slot_box_h + gap, inventory_h = inventory_h,
		hotbar_box_y = top_y + slot_box_h + gap + inventory_h + gap,
	}
end
local FULL = grug_inventory.FULL_LAYOUT

-- A boxed area's background and its label, top left above the slots.
function grug_inventory.area_box(x, y, w, h, label, color)
	return ("box[%.3f,%.3f;%.3f,%.3f;%s]label[%.3f,%.3f;%s]"):format(x, y, w, h,
		color or grug_inventory.BOX_COLOR, x + FULL.pad, y + FULL.label_h / 2,
		core.formspec_escape(label))
end

-- The lists of the scroll area, top to bottom: {list, start, rows}.
local function view_sections(inv)
	local sections = {}
	local main_rows = math.ceil(math.max(0, inv:get_size("main") - 8) / 8)
	if main_rows > 0 then
		sections[1] = {list = "main", start = 8, rows = main_rows}
	end
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		local rows = math.ceil(inv:get_size(list) / 8)
		if rows > 0 then
			sections[#sections + 1] = {list = list, start = 0, rows = rows}
		end
	end
	return sections
end

-- The scrollbar's maximum for `rows` content rows shown `visible` at a time.
function grug_inventory.view_scroll_max(rows, visible)
	return math.max(0, rows - visible) * ROW_STEPS
end

-- The formspec part of one inventory view, in real coordinates (it switches
-- them on itself, so it may follow legacy content). mode: "full" or "short".
function grug_inventory.inventory_view(player, mode, context)
	local visible = grug_inventory.VIEW_ROWS[mode]
	assert(visible, "inventory_view: unknown mode " .. tostring(mode))
	local inv = player:get_inventory()
	local sections = view_sections(inv)
	local rows = 0
	for _, section in ipairs(sections) do rows = rows + section.rows end
	local area_h = visible * PITCH - (PITCH - SLOT)
	local area_y = AREA_BOTTOM - area_h
	local view_x, scrollbar_x, hotbar_y = VIEW_X, SCROLLBAR_X, HOTBAR_Y
	local field = grug_inventory.SCROLL_FIELDS[mode]
	local fs = {"real_coordinates[true]"}
	if mode == "full" then
		-- The boxed layout: the Inventory and the Hotbar box, drawn first so
		-- the lists lie on them.
		view_x, scrollbar_x = FULL.x, FULL.x + (SCROLLBAR_X - VIEW_X)
		area_y = FULL.inventory_y + FULL.label_h
		hotbar_y = FULL.hotbar_box_y + FULL.label_h
		fs[#fs + 1] = grug_inventory.area_box(FULL.box_x, FULL.inventory_y,
			FULL.box_w, FULL.inventory_h, "Inventory")
		fs[#fs + 1] = grug_inventory.area_box(FULL.box_x, FULL.hotbar_box_y,
			FULL.box_w, FULL.slot_box_h, "Hotbar", HOTBAR_COLOR)
	end

	local max = grug_inventory.view_scroll_max(rows, visible)
	if max > 0 then
		local stored = context and context.grug_inv_scroll and
			context.grug_inv_scroll[mode] or 0
		local value = math.max(0, math.min(max, math.floor(stored)))
		-- The engine draws the thumb as thumbsize / (max - min + 1) of the
		-- track (CGUIScrollBar::setPosRaw with the page size
		-- guiFormSpecMenu.cpp parseScrollBar sets), so the visible share of
		-- the rows is visible / rows of max + 1. A thumbsize of a page's steps
		-- filled the whole track whenever max was below it: no handle to grab.
		local thumb = math.max(1, math.floor(visible * (max + 1) / rows + 0.5))
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;" ..
			"thumbsize=%d;arrows=hide]"):format(max, ROW_STEPS,
			visible * ROW_STEPS, thumb)
		fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.2f,%.3f;vertical;%s;%d]"):format(
			scrollbar_x, area_y, SCROLLBAR_W, area_h, field, value)
		-- scrollbaroptions[] applies to every later scrollbar[], page content
		-- included: back to the engine's defaults (guiFormSpecMenu.h
		-- parserData::scrollbar_options).
		fs[#fs + 1] = SCROLLBAR_DEFAULTS
	end
	fs[#fs + 1] = ("scroll_container[%.3f,%.3f;%.3f,%.3f;%s;vertical;%.3f]"):format(
		view_x, area_y, VIEW_W, area_h, field, SCROLL_FACTOR)
	local row = 0
	for _, section in ipairs(sections) do
		fs[#fs + 1] = ("list[current_player;%s;0,%.3f;8,%d;%d]"):format(
			section.list, row * PITCH, section.rows, section.start)
		row = row + section.rows
	end
	fs[#fs + 1] = "scroll_container_end[]"

	-- The hotbar: its gold band (the full view's is its box), the engine's
	-- hotbar cell art under each slot and the first eight cells of main.
	if mode ~= "full" then
		fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(VIEW_X - 0.08,
			HOTBAR_Y - 0.08, VIEW_W + 0.16, SLOT + 0.16, HOTBAR_COLOR)
		fs[#fs + 1] = ("label[0.3,%.3f;Hotbar]"):format(HOTBAR_Y + SLOT / 2)
	end
	for index = 0, 7 do
		fs[#fs + 1] = ("image[%.3f,%.3f;1,1;gui_hb_bg.png]"):format(
			view_x + index * PITCH, hotbar_y)
	end
	fs[#fs + 1] = ("list[current_player;main;%.3f,%.3f;8,1;]"):format(view_x,
		hotbar_y)
	return table.concat(fs)
end

-- Chains sfinv's hook (api.lua GRUG PATCH): keeps the views' scroll values
-- from every event and reports a pure scrollbar event as handled.
local previous_handle_scroll = sfinv.handle_scroll
function sfinv.handle_scroll(player, context, fields)
	local pure = previous_handle_scroll(player, context, fields)
	for mode, field in pairs(grug_inventory.SCROLL_FIELDS) do
		local raw = fields[field]
		local kind, value
		if type(raw) == "string" then
			kind, value = raw:match("^(%u+):(%-?%d+)$")
		end
		if kind == "CHG" or kind == "VAL" then
			context.grug_inv_scroll = context.grug_inv_scroll or {}
			context.grug_inv_scroll[mode] = math.max(0, tonumber(value))
			pure = pure or kind == "CHG"
		end
	end
	return pure
end

--
-- Shift-click from a bag (Round 45 playtest PT5): on a page whose rings send
-- `main` to another list, each bag the view shows goes there too. The engine
-- takes the ring entry after the FIRST one naming the source list
-- (getNextInventoryRing), so pairs appended at the end change no other
-- list's target; a bag the page rings itself (the Character tab) is left
-- alone.
--
local function bag_rings(player, content)
	local rings, ringed = {}, {}
	for entry in content:gmatch("listring%[([^%]]*;[^%]]*)%]") do
		rings[#rings + 1] = entry
		ringed[entry] = true
	end
	local target
	for index, entry in ipairs(rings) do
		if entry == "current_player;main" then
			target = rings[index % #rings + 1]
			break
		end
	end
	if not target or target == "current_player;main" then return "" end
	local inv = player:get_inventory()
	local fs = {}
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		if inv:get_size(list) > 0 and not ringed["current_player;" .. list] then
			fs[#fs + 1] = ("listring[current_player;%s]listring[%s]"):format(list, target)
		end
	end
	return table.concat(fs)
end

--
-- The frame. A page passes show_inv = "full" or "short" for that view, true
-- for the short view (pages not yet reworked) and false or nil for none. A
-- page with its own header (`size`; none since the map got its own window)
-- gets the tabs and its content only. context.grug_inv_view records the
-- view the page shows, so a bag change re-renders it (pages.lua
-- grug_inventory.refresh).
--
function sfinv.make_formspec(player, context, content, show_inv, size)
	local nav = sfinv.get_nav_fs(player, context, context.nav_titles,
		context.nav_idx)
	if size then
		context.grug_inv_view = nil
		return size .. nav .. content
	end
	local mode = show_inv == true and "short" or show_inv or nil
	context.grug_inv_view = mode
	return table.concat({
		("formspec_version[6]size[%.3f,%.3f]"):format(UI.frame_w, UI.frame_h),
		nav,
		mode and grug_inventory.inventory_view(player, mode, context) or "",
		"real_coordinates[false]",
		content,
		mode and bag_rings(player, content) or "",
	})
end

core.register_on_mods_loaded(function()
	if not rawget(_G, "creative") then return end
	local foods = {}
	for name, definition in pairs(core.registered_items) do
		if ((definition.groups or {}).grug_food or 0) > 0 then
			foods[name] = definition
		end
	end
	creative.register_tab("food", "Food", foods)
end)

-- After the Food tab above: every page exists by now.
core.register_on_mods_loaded(grug_inventory.order_tabs)
