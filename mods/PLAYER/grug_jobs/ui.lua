-- The Crafting tab (Round 45 lane UI; round45-plan.md §3, §4.4;
-- ui-crafting-rework-plan.md §2.16-2.22, §2.33, §4.2-4.5; wireframe v1's
-- Crafting artboard). Real coordinates inside the inventory window's frame,
-- above the short inventory view:
--   top     the area tabs (Basic, Cooking, the two primary slots, Alchemy)
--           and the selected area's tier progress;
--   left    the recipe list: search, "Craftable only", 10 rows per page
--           (icon, name, ×N), "Page x of y";
--   middle  the crafting box (craft_box.lua; replaceable, lane EU adds the
--           enchant and upgrade boxes); the professions overview while no
--           recipe is chosen;
--   right   the output area (grug_craft_out, take-only), Take all and the
--           running job: the green indicator, its label, the progress bar.
--
-- Runtime state lives in the sfinv context (context.grug_craft), never in
-- player meta: the area, the page, the applied search and the typed text,
-- "Craftable only", the chosen recipe, the last known quantity and the note
-- of the last refused action. A formspec is resent whole and the client
-- does not keep typed field text across a resend, so every build echoes the
-- last known field values (spec §4.3).
--
-- Traffic (spec §1, §4.4, plan §5): one ingredient pass per build
-- (grug_jobs.ingredient_counts), which feeds ×N, "Craftable only" and the
-- crafting box. A click is answered with one resend; a pure scrollbar event
-- of the inventory view never reaches this page (sfinv.handle_scroll). Per
-- job the page is sent at its start (the Craft now click), at its end (the
-- timer, only while the player's current page is Crafting) and at a cancel
-- (the Stop click). The search runs at most once per second: a search
-- request within a second of the last one is ignored without a resend, like
-- Sort's cooldown (spec ruling 5).

local PAGE = "sfinv:crafting"
local PER_PAGE = 10
local SEARCH_INTERVAL_US = 1000000
local SEARCH_CHARS = 40
local QUANTITY_CHARS = 8

-- The progress bar (gen_progress_bar.py writes the texture): BAR_FILL_FRAMES
-- fill frames, then half as many full frames as a lag buffer, stacked
-- vertically. The animation lasts 1.5 x the job time, so the bar is full at
-- 2/3 of it and a late end resend still finds it full (spec §4.5).
local BAR_TEXTURE = "grug_jobs_progress_bar.png"
local BAR_FILL_FRAMES = 64
local BAR_FRAMES = BAR_FILL_FRAMES + BAR_FILL_FRAMES / 2
grug_jobs.BAR_FILL_FRAMES = BAR_FILL_FRAMES
grug_jobs.BAR_FRAMES = BAR_FRAMES

-- Field names (shared with craft_box.lua).
local F = {
	area = "grug_craft_area", row = "grug_craft_row",
	prev = "grug_craft_prev", next = "grug_craft_next",
	search = "grug_craft_search", find = "grug_craft_find",
	only = "grug_craft_only", take = "grug_craft_take",
	qty = "grug_craft_qty", max = "grug_craft_max",
	go = "grug_craft_go", stop = "grug_craft_stop", recheck = "grug_craft_recheck",
	box = "grug_craft_box_",
}
grug_jobs.CRAFT_FIELDS = F

-- Colours: the gold selection of grug_inventory, the overview's note colour,
-- the running job's green.
local SELECTED_ROW = "#8a682f80"
local BOX_COLOR = "#00000040"
local DIM = "#9a9a9a"
local RUN_COLOR = "#5fd068"

-- Layout (real coordinates; the frame is 13.5 wide and the short view's
-- grid starts at y 9.5, see grug_inventory/ui.lua).
local TAB_Y, TAB_H = 0.25, 0.65
local LIST_X, LIST_W = 0.2, 5.0
local SEARCH_Y, CHECK_Y = 1.1, 2.0
local ROW_Y, ROW_H, ICON = 2.35, 0.56, 0.45
local PAGER_Y = ROW_Y + PER_PAGE * ROW_H + 0.1
local PAGER_H = 0.55
local BOX = {x = 5.4, y = 0.95, w = 4.8, h = 8.25}
local OUT = {x = 10.4, y = 0.95, w = 2.9, h = 8.25}
grug_jobs.CRAFT_BOX = BOX
-- Characters per real unit for clipping and wrapping (the overview's rate),
-- and a row's room for its name between the icon and ×N.
local CHARS_PER_UNIT = 6.6
local ROW_CHARS = math.floor(3.55 * CHARS_PER_UNIT)

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end
-- Coordinates without trailing zeros.
local function n(value)
	return ("%g"):format(math.floor(value * 100 + 0.5) / 100)
end
grug_jobs._fs_number = n
local function clip(text, limit)
	if #text <= limit then return text end
	return text:sub(1, limit - 2) .. ".."
end
grug_jobs._clip = clip

--
-- Areas (spec §2.16): Basic and Cooking, the two primary slots, Alchemy. An
-- empty primary slot and an unlearned profession show an empty list with how
-- to learn it, as the recipe books did.
--

local AREA_SLOTS = {{area = "basic"}, {area = "cooking"}, {primary = 1},
	{primary = 2}, {area = "alchemist"}}

-- {area (nil for an empty primary slot), label, learned} per tab.
local function area_tabs(player)
	local tabs = {}
	for index, slot in ipairs(AREA_SLOTS) do
		local area = slot.area or grug_jobs.primary_at(player, slot.primary)
		local label
		if area == "basic" then
			label = "Basic"
		elseif area then
			label = grug_jobs.PROFESSIONS[area].name
		else
			label = "Primary " .. slot.primary
		end
		tabs[index] = {area = area, label = label,
			learned = area == "basic" or (area ~= nil and grug_jobs.has(player, area))}
	end
	return tabs
end

-- The tier progress of a profession area: its text and the fill (0..1) of
-- the small bar, nil without one.
local function tier_progress(player, tab)
	if tab.area == "basic" then return "Basic: no tier" end
	if not tab.learned then return "Not learned" end
	local tier = grug_jobs.profession_level(player, tab.area)
	local needed = grug_jobs.CRAFTS_TO_ADVANCE[tier]
	if not needed then return ("Tier %d · highest"):format(tier) end
	local crafts = math.min(needed, grug_jobs.crafts_in_tier(player, tab.area))
	return ("Tier %d · %d/%d"):format(tier, crafts, needed), crafts / needed
end

--
-- The list (spec §2.17, §4.2): the area's recipes in the registry's stable
-- order (tier, name, id). A profession area (Cooking, Alchemy and the
-- primaries alike) shows only the tiers up to the player's profession tier
-- (profession_level, which the character's level band caps; Round 45
-- playtest fix 3, correcting spec §2.33's "all recipes"); Basic has no
-- profession tier and shows every recipe. The search over the output's name
-- and "Craftable only" (×N ≥ 1) filter that visible set; ×N is
-- crafts_from_counts on the build's one pass.
--

local labels, lowered = {}, {}
local function label_of(output)
	local label = labels[output]
	if not label then
		label = grug_core.item_name(output)
		labels[output] = label
		lowered[output] = label:lower()
	end
	return label
end
grug_jobs.recipe_label = label_of

-- {recipe, n} rows of the tab (n filled for every row when "Craftable only"
-- needs it, else later for the shown page only).
local function list_rows(player, st, tab, counts)
	local rows = {}
	if not tab.learned then return rows end
	local query = st.search:lower()
	local level = tab.area ~= "basic" and grug_jobs.profession_level(player, tab.area) or nil
	for _, recipe in ipairs(grug_jobs.recipes_in_area(tab.area)) do
		label_of(recipe.output)
		if (not level or recipe.tier <= level) and
				(query == "" or lowered[recipe.output]:find(query, 1, true)) then
			if st.only then
				local crafts = grug_jobs.crafts_from_counts(counts, recipe)
				if crafts > 0 then
					rows[#rows + 1] = {recipe = recipe, n = crafts}
				end
			else
				rows[#rows + 1] = {recipe = recipe}
			end
		end
	end
	return rows
end

local function empty_text(tab, searching)
	if not tab.area then
		return "No primary profession yet. Learn one from its trainer in the capital."
	end
	if not tab.learned then
		return "Not learned yet. Learn " .. tab.label .. " from its trainer in the capital."
	end
	return searching and "No recipe matches." or "No recipe can be crafted now."
end

local function wrapped_labels(fs, x, y, width, text, color, step)
	for piece in (grug_inventory.wrap_text(text, math.floor(width * CHARS_PER_UNIT)) ..
			"\n"):gmatch("(.-)\n") do
		fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(x), n(y),
			esc(color and core.colorize(color, piece) or piece))
		y = y + (step or 0.4)
	end
	return y
end
grug_jobs._wrapped_labels = wrapped_labels

local function list_content(fs, player, st, tab, counts)
	local rows = list_rows(player, st, tab, counts)
	local pages = math.max(1, math.ceil(#rows / PER_PAGE))
	st.page = math.max(1, math.min(pages, st.page))
	fs[#fs + 1] = ("field[%s,%s;3.6,0.6;%s;;%s]field_close_on_enter[%s;false]"):format(
		n(LIST_X), n(SEARCH_Y), F.search, esc(st.typed), F.search)
	fs[#fs + 1] = ("button[%s,%s;1.3,0.6;%s;Search]"):format(n(LIST_X + 3.7),
		n(SEARCH_Y), F.find)
	fs[#fs + 1] = ("checkbox[%s,%s;%s;Craftable only;%s]"):format(n(LIST_X), n(CHECK_Y),
		F.only, tostring(st.only))
	fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]"):format(n(LIST_X), n(ROW_Y), n(LIST_W),
		n(PER_PAGE * ROW_H), BOX_COLOR)
	st.rows = {}
	local first = (st.page - 1) * PER_PAGE
	for index = 1, math.min(PER_PAGE, #rows - first) do
		local row = rows[first + index]
		local recipe = row.recipe
		local crafts = row.n or grug_jobs.crafts_from_counts(counts, recipe)
		local y = ROW_Y + (index - 1) * ROW_H
		st.rows[index] = recipe.id
		if recipe.id == st.selected then
			fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]"):format(n(LIST_X), n(y), n(LIST_W),
				n(ROW_H), SELECTED_ROW)
		end
		local count = "×" .. crafts
		local name = label_of(recipe.output)
		local shown = clip(name, ROW_CHARS)
		fs[#fs + 1] = ("item_image[%s,%s;%s,%s;%s]label[%s,%s;%s]label[%s,%s;%s]"):format(
			n(LIST_X + 0.1), n(y + (ROW_H - ICON) / 2), n(ICON), n(ICON), esc(recipe.output),
			n(LIST_X + 0.7), n(y + ROW_H / 2), esc(shown),
			n(LIST_X + LIST_W - 0.75), n(y + ROW_H / 2),
			esc(crafts > 0 and count or core.colorize(DIM, count)))
		-- The click target over the row (the old book's overlay pattern); a
		-- clipped name in full as its tooltip.
		fs[#fs + 1] = ("image_button[%s,%s;%s,%s;blank.png;%s%d;;false;false]"):format(
			n(LIST_X), n(y), n(LIST_W), n(ROW_H), F.row, index)
		if shown ~= name then
			fs[#fs + 1] = ("tooltip[%s%d;%s]"):format(F.row, index, esc(name))
		end
	end
	if #rows == 0 then
		wrapped_labels(fs, LIST_X + 0.15, ROW_Y + 0.35, LIST_W - 0.3,
			empty_text(tab, st.search ~= ""))
	end
	fs[#fs + 1] = ("button[%s,%s;0.8,%s;%s;<]label[%s,%s;%s]button[%s,%s;0.8,%s;%s;>]"):format(
		n(LIST_X), n(PAGER_Y), n(PAGER_H), F.prev,
		n(LIST_X + 1.6), n(PAGER_Y + PAGER_H / 2), ("Page %d of %d"):format(st.page, pages),
		n(LIST_X + LIST_W - 0.8), n(PAGER_Y), n(PAGER_H), F.next)
end

--
-- The output area and the running job (spec §2.20, §4.5).
--

-- What the indicator says per job kind; lane EU adds "Enchanting…".
grug_jobs.JOB_RUN_LABELS = {recipe = "Crafting…"}

-- The running job's label per kind, fn(job) -> text; lane EU adds the
-- enchant ("Steel Sword") and upgrade ("Steel Sword +3 levels") texts.
grug_jobs.JOB_TEXTS = {recipe = function(job)
	local recipe = job.recipe_def
	if not recipe then return "" end
	local total = recipe.count * (job.quantity or 1)
	local name = label_of(recipe.output)
	return total > 1 and (name .. " ×" .. total) or name
end}

local function job_label(job)
	local text = grug_jobs.JOB_TEXTS[job.kind or "recipe"]
	return text and text(job) or ""
end

-- The bar's element: frame_start is the fill frame for the elapsed time,
-- computed on every build; one frame lasts 1.5 x the job time / BAR_FRAMES
-- (integer ms).
function grug_jobs.progress_bar(x, y, w, h, job, now)
	local total = math.max(0.001, job.finish - job.start)
	local elapsed = math.max(0, math.min(total, now - job.start))
	local start = math.min(BAR_FILL_FRAMES,
		math.floor(elapsed / total * BAR_FILL_FRAMES)) + 1
	local duration = math.max(1, math.floor(total * 1500 / BAR_FRAMES + 0.5))
	return ("animated_image[%s,%s;%s,%s;grug_craft_bar;%s;%d;%d;%d]"):format(
		n(x), n(y), n(w), n(h), BAR_TEXTURE, BAR_FRAMES, duration, start)
end

local function output_content(fs, job)
	local x = OUT.x + 0.2
	fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]label[%s,%s;Output]"):format(n(OUT.x), n(OUT.y),
		n(OUT.w), n(OUT.h), BOX_COLOR, n(x), n(OUT.y + 0.35))
	-- Shift-click goes to the inbox (grug_inventory/inbox.lua): main[9..]
	-- and the bags.
	fs[#fs + 1] = ("list[current_player;%s;%s,%s;2,2;]listring[current_player;%s]" ..
		"listring[current_player;grug_inbox]listring[current_player;main]"):format(
		grug_jobs.OUTPUT_LIST, n(x), n(OUT.y + 0.7), grug_jobs.OUTPUT_LIST)
	fs[#fs + 1] = ("button[%s,%s;2.5,0.6;%s;Take all]"):format(n(x), n(OUT.y + 3.1), F.take)
	local y = OUT.y + 4.15
	if not job then
		fs[#fs + 1] = ("label[%s,%s;No job running]"):format(n(x), n(y))
		return
	end
	fs[#fs + 1] = ("box[%s,%s;0.2,0.2;%s]label[%s,%s;%s]"):format(n(x), n(y - 0.1),
		RUN_COLOR, n(x + 0.3), n(y), esc(core.colorize(RUN_COLOR,
		grug_jobs.JOB_RUN_LABELS[job.kind or "recipe"] or "Working…")))
	y = wrapped_labels(fs, x, y + 0.5, 2.5, job_label(job))
	fs[#fs + 1] = grug_jobs.progress_bar(x, y, 2.5, 0.27, job, grug_jobs.now())
end

--
-- The crafting boxes (spec §2.18; lane EU adds its enchant and upgrade
-- boxes): def.build(player, view) -> formspec text inside grug_jobs.CRAFT_BOX,
-- def.fields(player, st, fields) -> true when it handled the event (the page
-- then resends). `view` = {st, tab, recipe, job, counts}. The box drawn is
-- context.grug_craft.box (default "recipe"). A box with `button = {label,
-- shown = fn(player, tab)}` gets a button below the list where `shown` says
-- so (lane EU: "Enchant an item", "Upgrade an item" in the primary areas); a
-- click opens it, a recipe row or an area tab returns to the recipe box.
--

local boxes, box_order = {}, {}
function grug_jobs.register_craft_box(name, def)
	if not boxes[name] then box_order[#box_order + 1] = name end
	boxes[name] = def
end

-- The row of box buttons below the pager, down to the boxes' bottom edge.
-- They are drawn as ordinary buttons (the pane with its border; the shared
-- unselected tab style has no border and read as plain text in the
-- playtest), the open box's button in the gold selection style.
local BOX_BUTTON_Y = PAGER_Y + PAGER_H + 0.05
local BOX_BUTTON_H = BOX.y + BOX.h - BOX_BUTTON_Y
local function box_buttons(fs, player, st, tab)
	local shown = {}
	for _, name in ipairs(box_order) do
		local button = boxes[name].button
		if button and button.shown(player, tab) then shown[#shown + 1] = name end
	end
	if #shown == 0 then return end
	local w = (LIST_W - 0.1 * (#shown - 1)) / #shown
	for index, name in ipairs(shown) do
		local field = F.box .. name
		if st.box == name then
			fs[#fs + 1] = grug_inventory.selected_button_style(field, true)
		end
		fs[#fs + 1] = ("button[%s,%s;%s,%s;%s;%s]"):format(n(LIST_X + (index - 1) * (w + 0.1)),
			n(BOX_BUTTON_Y), n(w), n(BOX_BUTTON_H), field, esc(boxes[name].button.label))
	end
end

local function state_of(context)
	local st = context.grug_craft
	if not st then
		st = {slot = 1, page = 1, search = "", typed = "", only = false, qty = "1",
			rows = {}}
		context.grug_craft = st
	end
	return st
end

function grug_jobs.crafting_page_content(player, context)
	local st = state_of(context)
	local job = grug_jobs.job_state(player)
	-- The one inventory pass of this build.
	local counts = grug_jobs.ingredient_counts(player)
	local tabs = area_tabs(player)
	local tab = tabs[st.slot] or tabs[1]
	local fs = {"real_coordinates[true]"}
	-- Area tabs in the shared selection style: one style[] for the selected
	-- tab, one naming all the others (style[] takes several names).
	local others = {}
	for index in ipairs(tabs) do
		if index ~= st.slot then others[#others + 1] = F.area .. index end
	end
	fs[#fs + 1] = grug_inventory.selected_button_style(F.area .. st.slot, true)
	fs[#fs + 1] = (grug_inventory.selected_button_style("@", false):gsub("^style%[@;",
		"style[" .. table.concat(others, ",") .. ";", 1))
	local x = LIST_X
	for index, entry in ipairs(tabs) do
		local w = 0.5 + 0.135 * #entry.label
		fs[#fs + 1] = ("button[%s,%s;%s,%s;%s%d;%s]"):format(n(x), n(TAB_Y), n(w), n(TAB_H),
			F.area, index, esc(entry.label))
		x = x + w + 0.1
	end
	local text, fill = tier_progress(player, tab)
	local bar_x = OUT.x + OUT.w - 1.3
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(math.min(x + 0.2, bar_x - 2.3)),
		n(TAB_Y + TAB_H / 2), esc(text))
	if fill then
		fs[#fs + 1] = ("box[%s,%s;1.3,0.25;#00000080]box[%s,%s;%s,0.25;#c9a24a]"):format(
			n(bar_x), n(TAB_Y + TAB_H / 2 - 0.125), n(bar_x), n(TAB_Y + TAB_H / 2 - 0.125),
			n(1.3 * fill))
	end
	list_content(fs, player, st, tab, counts)
	box_buttons(fs, player, st, tab)
	local box = boxes[st.box or "recipe"] or boxes.recipe
	fs[#fs + 1] = box.build(player, {st = st, tab = tab, job = job, counts = counts,
		recipe = st.selected and grug_jobs.recipe(st.selected) or nil})
	output_content(fs, job)
	return table.concat(fs)
end

--
-- Events.
--

-- A field value trimmed and cut to `limit` characters. The cut to a few
-- times the limit comes first: a client may send a field of hundreds of
-- kilobytes, and the trim's pattern takes time that grows with the square
-- of the spaces in it.
local function clean(value, limit)
	local text = tostring(value):sub(1, 4 * limit):gsub("[%c]", "")
	return (text:match("^%s*(.-)%s*$") or ""):sub(1, limit)
end
grug_jobs._clean_field = clean

local function receive_fields(player, context, fields)
	if fields.quit then return end
	local st = state_of(context)
	-- Every event carries the fields: keep their last known values.
	if fields[F.search] then st.typed = clean(fields[F.search], SEARCH_CHARS) end
	if fields[F.qty] then st.qty = clean(fields[F.qty], QUANTITY_CHARS) end
	if fields[F.find] or fields.key_enter_field == F.search then
		local now = core.get_us_time()
		if st.searched_at and now - st.searched_at < SEARCH_INTERVAL_US then
			return true -- at most one search per second; no resend
		end
		st.searched_at = now
		st.note = nil
		st.search, st.page = st.typed, 1
		sfinv.set_player_inventory_formspec(player, context)
		return true
	end
	st.note = nil
	local handled = false
	for index = 1, #AREA_SLOTS do
		if fields[F.area .. index] then
			st.slot, st.page, st.selected, st.qty, st.box = index, 1, nil, "1", nil
			handled = true
		end
	end
	for index = 1, PER_PAGE do
		if fields[F.row .. index] and st.rows[index] then
			st.selected, st.qty, st.box = st.rows[index], "1", nil
			handled = true
		end
	end
	for _, name in ipairs(box_order) do
		if fields[F.box .. name] and boxes[name].button then
			st.box, st.selected = name, nil
			handled = true
		end
	end
	if fields[F.prev] then st.page, handled = st.page - 1, true end
	if fields[F.next] then st.page, handled = st.page + 1, true end
	if fields[F.only] then
		st.only, st.page, handled = fields[F.only] == "true", 1, true
	end
	if fields[F.take] then
		local _, left = grug_jobs.take_all(player)
		if left then st.note = "Not everything fit into your inventory." end
		handled = true
	end
	local box = boxes[st.box or "recipe"] or boxes.recipe
	if box.fields(player, st, fields) then handled = true end
	if not handled then return end
	sfinv.set_player_inventory_formspec(player, context)
	return true
end

sfinv.override_page(PAGE, {
	get = function(self, player, context)
		-- Opening the tab catches the crafting job up (jobs.lua).
		grug_jobs.update_job(player, "open")
		return sfinv.make_formspec(player, context,
			grug_jobs.crafting_page_content(player, context), "short")
	end,
	on_player_receive_fields = function(self, player, context, fields)
		return receive_fields(player, context, fields)
	end,
})

-- The end resend (spec §4.4): a job the timer or the join completed resends
-- the page when the player's current page is Crafting (the server cannot
-- tell whether the window is open; a resend while it is closed is cheap).
-- Ends inside a build ("open") or a click ("start", "stop") are answered by
-- that build or that click's own resend.
grug_jobs.register_on_job_end(function(player, job, outcome, source)
	if source == "open" or source == "start" or source == "stop" then return end
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == PAGE then
		sfinv.set_player_inventory_formspec(player, context)
	end
end)
