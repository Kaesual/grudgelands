-- The Crafting tab's enchant and upgrade boxes (Round 45 lane EU;
-- round45-plan.md §4.6; ui-crafting-rework-plan.md §2.24, §2.26, §4.3, §4.6;
-- wireframe v1's Crafting artboard, variants "enchant" and "upgrade"), drawn
-- into grug_jobs.CRAFT_BOX through register_craft_box. A learned primary
-- area shows the buttons "Enchant an item" and "Upgrade an item" below its
-- list; the jobs are operation_jobs.lua's.
--
-- Enchant: the target slot (grug_craft_target), the arrow, the preview (the
-- result's image with its computed description as the tooltip), the area
-- profession's enchants valid for the placed item up to the profession's
-- tier (a scrolling list with the value each gives on this item), the
-- chosen enchant's materials with have/need, the overwrite warning, the XP
-- hint and Enchant now, which turns into Cancel while a job runs.
--
-- Upgrade: the target slot, its item level and cap, "+N levels" with Max,
-- the resulting item level, the materials for N levels with have/need, the
-- permanent warning when the result needs a higher level than the
-- player's, and Upgrade now, the yellow "Upgrade anyway" with the warning
-- (Stop while a job runs). An item at or above its cap reads "Already at
-- the cap" and takes no level.
--
-- The levels field follows spec §4.3 like the quantity field: Enter
-- recalculates and never starts; a click above the maximum (the cap or the
-- materials) lowers the field with the note and starts nothing. The
-- warning is the same two-step: the server knows the levels only with the
-- click, so a click for an item and level count the page has not yet shown
-- with the warning shows it, and the next click starts.

local UIF = grug_jobs.CRAFT_FIELDS
local BOX = grug_jobs.CRAFT_BOX
local n = grug_jobs._fs_number
local wrapped_labels = grug_jobs._wrapped_labels
local clean = grug_jobs._clean_field
local TARGET = grug_jobs.TARGET_LIST

local F = {
	list = "grug_craft_ench_list", enchant = "grug_craft_ench_go",
	levels = "grug_craft_levels", max = "grug_craft_levels_max",
	upgrade = "grug_craft_upg_go",
}
grug_jobs.OPERATION_FIELDS = F

local X = BOX.x + 0.2
local W = BOX.w - 0.4
local BUTTON_Y = BOX.y + BOX.h - 0.75
local TITLE_Y, SLOT_Y = BOX.y + 0.3, BOX.y + 0.65
local NOTE_STEP = 0.38
local LEVEL_CHARS = 8
local BOX_COLOR = "#00000040"
local SLOT_COLOR = "#00000080"
local WARN = "#ff9f5a"
local NOTE = "#f0c75e"
local DIM = "#9a9a9a"
local ARROW = "gui_furnace_arrow_bg.png^[transformR270"
local DISABLED_STYLE = "style[" .. UIF.recheck ..
	";bgcolor=#2a2a2a;bgcolor_hovered=#2a2a2a;textcolor=#808080;border=false]"
local ANYWAY_STYLE = "style[" .. F.upgrade ..
	";bgcolor=#f0c419;bgcolor_hovered=#f5d24a;bgcolor_pressed=#c9a10f;textcolor=#222222]"

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- The operations of one profession and kind, in registration order (all
-- register at load; the list is built at the first use).
local by_kind = {}
local function operations_of(profession, kind)
	local key = profession .. ":" .. kind
	local list = by_kind[key]
	if not list then
		list = {}
		for index, op in ipairs(grug_jobs.station_operations()) do
			if op.profession == profession and op.operation == kind then
				list[#list + 1] = op
				op._grug_order = index
			end
		end
		by_kind[key] = list
	end
	return list
end

-- The profession of the tab when it is a learned area with `kind`
-- operations.
local function area_profession(player, tab, kind)
	local area = tab and tab.area
	if not area or not tab.learned or not grug_jobs.PROFESSIONS[area] then return nil end
	if not grug_jobs.station_operations or #operations_of(area, kind) == 0 then return nil end
	return area
end

local function target_of(player)
	return player:get_inventory():get_stack(TARGET, 1)
end

-- The slot, its label and the box behind it.
local function slot(fs, x, label)
	fs[#fs + 1] = ("box[%s,%s;1,1;%s]list[current_player;%s;%s,%s;1,1;]"):format(
		n(x), n(SLOT_Y), SLOT_COLOR, TARGET, n(x), n(SLOT_Y))
	if label then
		fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(x), n(SLOT_Y + 1.2), esc(label))
	end
end

-- Shift-click moves an item of `main` into the slot and back: the ring
-- keeps UI's output → main first (the first occurrence of a list decides
-- where a shift-click goes).
local RING = ("listring[current_player;%s]listring[current_player;main]" ..
	"listring[current_player;%s]listring[current_player;main]"):format(
	grug_jobs.OUTPUT_LIST, TARGET)

local function station_warning(op)
	local info = grug_jobs.station_info(op.station)
	return "Requires: " .. (info and info.display_name or op.station) .. " nearby"
end

-- The button: Cancel/Stop while a job runs, else the action or its greyed
-- form (a click on that only rebuilds the page).
local function button(fs, job, stop_label, field, label, enabled, style)
	local geometry = ("%s,%s;%s,0.65"):format(n(X), n(BUTTON_Y), n(W))
	if job then
		fs[#fs + 1] = ("button[%s;%s;%s]"):format(geometry, UIF.stop, stop_label)
	elseif enabled then
		if style then fs[#fs + 1] = style end
		fs[#fs + 1] = ("button[%s;%s;%s]"):format(geometry, field, esc(label))
	else
		fs[#fs + 1] = DISABLED_STYLE .. ("button[%s;%s;%s]"):format(geometry, UIF.recheck,
			esc(label))
	end
end

local function no_area(fs, job, stop_label)
	wrapped_labels(fs, X, TITLE_Y + 0.5, W, "Choose a profession area above.", DIM, NOTE_STEP)
	if job then button(fs, job, stop_label) end
	return table.concat(fs)
end

local function cancel(player, st)
	local ok, reason = grug_jobs.cancel_job(player)
	if not ok then st.note = reason end
	return true
end

--
-- Enchant.
--

-- The text of one enchant in the list: its tier, channel and the value it
-- gives on an item of `ilvl` ("T5 prefix: +11 Strength").
local function enchant_text(op, ilvl)
	local affix = grug_items.AFFIXES[op.enchant_stat]
	local value = grug_items.enchant_value(op.enchant_stat, ilvl, op.tier)
	return ("T%d %s: +%s%s %s"):format(op.tier, op.enchant_channel,
		grug_items.format_enchant_value(op.enchant_stat, value),
		affix.percent and "%" or "", affix.label)
end

-- The profession's enchants valid for `target` (family, item tier, the
-- channels, a change: grug_items.enchant_refusal) up to the profession's
-- tier: the best tier first, prefix before suffix, then the stat pools'
-- order.
local function enchant_rows(player, profession, target)
	local rows = {}
	if target:is_empty() then return rows end
	local family = grug_items.family_for(target)
	local level = grug_jobs.profession_level(player, profession)
	for _, op in ipairs(operations_of(profession, "enchant")) do
		if op.family == family and op.tier <= level and
				not grug_items.enchant_refusal(op, target) then
			rows[#rows + 1] = op
		end
	end
	table.sort(rows, function(a, b)
		if a.tier ~= b.tier then return a.tier > b.tier end
		if a.enchant_channel ~= b.enchant_channel then return a.enchant_channel == "prefix" end
		return a._grug_order < b._grug_order
	end)
	return rows
end

-- The preview: the result's own image (its enchant colours) or the item's,
-- and the computed description as the tooltip.
local function preview(fs, x, result)
	fs[#fs + 1] = ("box[%s,%s;1,1;%s]"):format(n(x), n(SLOT_Y), SLOT_COLOR)
	if not result then return end
	local image = result:get_meta():get_string("inventory_image")
	if image ~= "" then
		fs[#fs + 1] = ("image[%s,%s;0.9,0.9;%s]"):format(n(x + 0.05), n(SLOT_Y + 0.05),
			esc(image))
	else
		fs[#fs + 1] = ("item_image[%s,%s;0.9,0.9;%s]"):format(n(x + 0.05),
			n(SLOT_Y + 0.05), esc(result:get_name()))
	end
	fs[#fs + 1] = ("tooltip[%s,%s;1,1;%s]"):format(n(x), n(SLOT_Y),
		esc(result:get_meta():get_string("description")))
end

local function enchant_build(player, view)
	local st, job = view.st, view.job
	local fs = {("box[%s,%s;%s,%s;%s]"):format(n(BOX.x), n(BOX.y), n(BOX.w), n(BOX.h),
		BOX_COLOR)}
	local profession = area_profession(player, view.tab, "enchant")
	if not profession then return no_area(fs, job, "Cancel") end
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X), n(TITLE_Y),
		esc("Enchant · " .. grug_jobs.OPERATION_SECONDS.enchant .. " s"))
	fs[#fs + 1] = RING
	slot(fs, X, "Target")
	fs[#fs + 1] = ("image[%s,%s;0.9,0.45;%s]"):format(n(X + 1.2), n(SLOT_Y + 0.28),
		esc(ARROW))
	local target = target_of(player)
	local rows = enchant_rows(player, profession, target)
	st.ench_rows = {}
	local chosen, selected = nil, 0
	for index, op in ipairs(rows) do
		st.ench_rows[index] = op.id
		if op.id == st.ench then chosen, selected = op, index end
	end
	if not chosen then st.ench = nil end
	local plan, refusal
	if chosen then plan, refusal = grug_items.operation_plan(chosen, target, player) end
	preview(fs, X + 2.3, plan and plan.output)
	fs[#fs + 1] = ("label[%s,%s;Result]"):format(n(X + 2.3), n(SLOT_Y + 1.2))
	local y = SLOT_Y + 1.55
	local name = grug_jobs.PROFESSIONS[profession].name
	if target:is_empty() then
		y = wrapped_labels(fs, X, y, W, "Place an item in the Target slot to see the " ..
			name .. " enchants for it.", DIM, NOTE_STEP)
	elseif #rows == 0 then
		local level = grug_jobs.profession_level(player, profession)
		y = wrapped_labels(fs, X, y, W, name .. " (tier " .. level ..
			") has no enchant for this item.", DIM, NOTE_STEP)
	else
		fs[#fs + 1] = ("label[%s,%s;Enchants valid for this item]"):format(n(X), n(y))
		local ilvl = grug_items.effective_ilvl(target) or 1
		local items = {}
		for index, op in ipairs(rows) do items[index] = esc(enchant_text(op, ilvl)) end
		fs[#fs + 1] = ("textlist[%s,%s;%s,1.6;%s;%s;%d;false]"):format(n(X), n(y + 0.2),
			n(W), F.list, table.concat(items, ","), selected)
		y = y + 1.95
	end
	local enabled = chosen ~= nil and plan ~= nil and job == nil
	if chosen then
		y = grug_jobs._ingredient_rows(fs, {ingredients = chosen.ingredients}, view.counts, 1,
			y) + 0.1
		if refusal then
			y = wrapped_labels(fs, X, y, W, refusal, WARN, NOTE_STEP)
		elseif plan.warning then
			y = wrapped_labels(fs, X, y, W, plan.warning, WARN, NOTE_STEP)
		end
		if chosen.station and not grug_jobs.station_nearby(player, chosen.station) then
			enabled = false
			y = wrapped_labels(fs, X, y, W, station_warning(chosen), WARN, NOTE_STEP)
		end
	end
	if st.note then y = wrapped_labels(fs, X, y, W, st.note, NOTE, NOTE_STEP) end
	if chosen then
		local hint, color = grug_jobs._xp_hint(player, chosen)
		if hint then wrapped_labels(fs, X, y, W, hint, color, NOTE_STEP) end
	end
	button(fs, job, "Cancel", F.enchant, "Enchant now", enabled)
	return table.concat(fs)
end

local function enchant_fields(player, st, fields)
	if fields[UIF.stop] then return cancel(player, st) end
	if fields[UIF.recheck] then return true end
	local event = fields[F.list]
	if event then
		local index = tonumber(tostring(event):match("^%u%u%u:(%d+)"))
		if index and st.ench_rows and st.ench_rows[index] then st.ench = st.ench_rows[index] end
		return true
	end
	if fields[F.enchant] then
		if not st.ench then
			st.note = "Choose an enchant from the list."
			return true
		end
		local ok, reason = grug_jobs.start_operation(player, st.ench)
		if not ok then st.note = reason end
		return true
	end
	return false
end

--
-- Upgrade.
--

local function levels_of(text)
	local value = tonumber(text)
	if value and value >= 1 and value % 1 == 0 then return value end
	return nil
end

-- What the slot's item allows: {reason} for none, else its item level, cap,
-- operation, the levels left to the cap (`gap`), the materials of one level
-- and the levels they pay for; `max` the most levels a job may take now.
local function upgrade_view(player, profession, target, counts)
	if target:is_empty() then return {empty = true} end
	local ilvl, cap, tier = grug_items.upgrade_span(target)
	if not ilvl then return {reason = cap} end
	local v = {ilvl = ilvl, cap = cap, tier = tier}
	local first = operations_of(profession, "upgrade")[1]
	if not first.family_set[grug_items.family_for(target)] then
		v.reason = grug_jobs.PROFESSIONS[profession].name .. " does not upgrade this item."
		return v
	end
	v.op = grug_jobs.upgrade_operation(profession, tier)
	if ilvl >= cap then
		v.reason = "Already at the cap (item level " .. cap .. ")."
		return v
	end
	v.gap = cap - ilvl
	v.ingredients = grug_jobs.operation_ingredients(v.op, target)
	v.affordable = grug_jobs.crafts_from_counts(counts, {ingredients = v.ingredients})
	v.max = math.min(v.gap, v.affordable)
	return v
end

-- The level a result of item level `ilvl` requires, when it is above the
-- player's; else nil.
local function above_level(player, ilvl)
	local required = grug_gear.required_level(ilvl)
	if required > grug_xp.get_level(player) then return required end
	return nil
end

local function warned_key(target, levels)
	return target:to_string() .. "#" .. levels
end

local function upgrade_build(player, view)
	local st, job = view.st, view.job
	local fs = {("box[%s,%s;%s,%s;%s]"):format(n(BOX.x), n(BOX.y), n(BOX.w), n(BOX.h),
		BOX_COLOR)}
	local profession = area_profession(player, view.tab, "upgrade")
	if not profession then return no_area(fs, job, "Stop") end
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X), n(TITLE_Y),
		esc("Upgrade · " .. grug_jobs.OPERATION_SECONDS.upgrade .. " s per level"))
	fs[#fs + 1] = RING
	slot(fs, X)
	local target = target_of(player)
	local v = upgrade_view(player, profession, target, view.counts)
	if st.fill_levels then
		st.levels, st.fill_levels = tostring(math.max(1, v.max or 1)), nil
	end
	local info_x, info_w = X + 1.25, W - 1.25
	local info = {}
	if v.empty then
		info[1] = "Place an item in the slot."
	elseif v.ilvl then
		info[1] = "Item level " .. v.ilvl
		info[2] = "Cap " .. v.cap .. " (" .. grug_jobs.PROFESSIONS[profession].name ..
			" tier " .. v.tier .. ")"
	end
	local iy = SLOT_Y + 0.2
	for _, line in ipairs(info) do iy = wrapped_labels(fs, info_x, iy, info_w, line, nil, NOTE_STEP) end
	local y = SLOT_Y + 1.35
	local enabled, warning = false, nil
	if v.reason then
		y = wrapped_labels(fs, X, y, W, v.reason, v.op and NOTE or WARN, NOTE_STEP)
	elseif v.gap then
		local levels = levels_of(st.levels)
		local shown = levels and math.min(levels, v.gap) or 1
		fs[#fs + 1] = ("label[%s,%s;+N levels]field[%s,%s;1,0.6;%s;;%s]" ..
			"field_close_on_enter[%s;false]button[%s,%s;1,0.6;%s;Max]"):format(
			n(X), n(y + 0.3), n(X + 1.35), n(y), F.levels, esc(st.levels or "1"), F.levels,
			n(X + 2.5), n(y), F.max)
		y = y + 0.95
		fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X), n(y), esc("Result: item level " ..
			(v.ilvl + shown) .. (v.ilvl + shown == v.cap and " (cap)" or "")))
		y = y + 0.25
		y = grug_jobs._ingredient_rows(fs, {ingredients = v.ingredients}, view.counts, shown,
			y) + 0.1
		enabled = job == nil
		local allowed, why = grug_jobs.can_craft_recipe(player, v.op)
		if not allowed then
			enabled = false
			y = wrapped_labels(fs, X, y, W, why, WARN, NOTE_STEP)
		elseif v.op.station and not grug_jobs.station_nearby(player, v.op.station) then
			enabled = false
			y = wrapped_labels(fs, X, y, W, station_warning(v.op), WARN, NOTE_STEP)
		end
		local required = above_level(player, v.ilvl + shown)
		if required then
			warning = true
			y = wrapped_labels(fs, X, y, W, "The target item level exceeds your level, " ..
				"you won't be able to use this item before you have reached level " ..
				required .. ".", WARN, NOTE_STEP)
		end
		-- The two-step (spec §4.3): this item and level count were shown with
		-- the warning.
		st.warned = warning and warned_key(target, shown) or nil
	end
	if st.note then wrapped_labels(fs, X, y, W, st.note, NOTE, NOTE_STEP) end
	-- The yellow "Upgrade anyway" only where it starts something.
	local anyway = warning and enabled
	button(fs, job, "Stop", F.upgrade, anyway and "Upgrade anyway" or "Upgrade now", enabled,
		anyway and ANYWAY_STYLE or nil)
	return table.concat(fs)
end

local function upgrade_fields(player, st, fields)
	if fields[F.levels] then st.levels = clean(fields[F.levels], LEVEL_CHARS) end
	if fields[UIF.stop] then return cancel(player, st) end
	if fields[UIF.recheck] then return true end
	if fields[F.max] then
		st.fill_levels = true
		return true
	end
	if fields.key_enter_field == F.levels then
		if not levels_of(st.levels) then st.note = "Enter a number of levels of 1 or more." end
		return true
	end
	if not fields[F.upgrade] then return false end
	local levels = levels_of(st.levels)
	if not levels then
		st.note = "Enter a number of levels of 1 or more."
		return true
	end
	local profession = area_profession(player, st.tab_seen, "upgrade")
	local target = target_of(player)
	local v = profession and upgrade_view(player, profession, target,
		grug_jobs.ingredient_counts(player)) or {reason = "Choose a profession area above."}
	if v.reason or v.empty then
		st.note = v.reason or "Place an item in the slot."
		return true
	end
	-- Above the maximum: lower the field and say why, start nothing.
	if levels > v.gap then
		st.levels = tostring(v.gap)
		st.note = "The cap is item level " .. v.cap .. " — levels reduced to " .. v.gap
		return true
	end
	if levels > v.max and v.max > 0 then
		st.levels = tostring(v.max)
		st.note = "Not enough ingredients — levels reduced to " .. v.max
		return true
	end
	-- The warning first shows; the next click for the same item and levels
	-- starts.
	if above_level(player, v.ilvl + levels) and st.warned ~= warned_key(target, levels) then
		return true
	end
	local ok, reason, info = grug_jobs.start_operation(player, v.op.id, levels)
	if not ok then
		st.note = reason
		if info and (info.code == "cap" or info.code == "ingredients") and
				(info.max or 0) > 0 then
			st.levels = tostring(info.max)
		end
	end
	return true
end

-- The boxes and their buttons in the learned primary areas.
local function shown_for(kind)
	return function(player, tab)
		return area_profession(player, tab, kind) ~= nil
	end
end

-- The tab the build saw (the click handler needs the area; ui.lua passes
-- only st to fields).
local function remember_tab(build)
	return function(player, view)
		view.st.tab_seen = view.tab
		return build(player, view)
	end
end

grug_jobs.register_craft_box("enchant", {build = remember_tab(enchant_build),
	fields = enchant_fields,
	button = {label = "Enchant an item", shown = shown_for("enchant")}})
grug_jobs.register_craft_box("upgrade", {build = remember_tab(upgrade_build),
	fields = upgrade_fields,
	button = {label = "Upgrade an item", shown = shown_for("upgrade")}})
