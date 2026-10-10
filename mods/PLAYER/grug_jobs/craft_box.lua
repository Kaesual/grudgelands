-- The Crafting tab's recipe box (Round 45 lane UI; ui-crafting-rework-plan.md
-- §2.18, §4.2, §4.3; Round 45 playtest fix 3), drawn into grug_jobs.CRAFT_BOX
-- by ui.lua in three stacked areas:
--   top     the chosen recipe's output: icon, name, area, tier, "makes N";
--   middle  the item's description (what its tooltip says, scrolling when
--           long), the ingredients with have/need, the maximum, the
--           warnings (the profession gate, "Requires: <station> nearby"),
--           the note of the last refused action and the XP hint;
--   bottom  the quantity row "Quantity [−][field][+] [Max]" (stackable
--           outputs only, default 1) and below it Craft now, which turns
--           into Stop while a job runs.
-- Without a chosen recipe the box shows the professions overview
-- (overview.lua): every known profession's tier, progress and the level cap
-- note.
--
-- The description is a read-only textarea: it scrolls on the client and a
-- scroll sends nothing to the server. It takes the room the other parts
-- leave and is left out when the tooltip says nothing beyond the name.
--
-- The quantity field (spec §4.3): the server learns the typed number only
-- with an event. Enter in the field recalculates and never starts; Craft now
-- above the maximum lowers the field to it and shows jobs.lua's note
-- without starting; the last known value is echoed on every build. "−" and
-- "+" (0.45.1 fix plan row 3) step the field by one: "−" only above 1, "+"
-- only below the maximum (max_craftable); a value that is not a whole
-- number of 1 or more counts as 1, as the build counts it for have/need, so
-- "−" turns it into 1 and "+" into 2 (when the maximum allows).
--
-- A button that cannot start ("Requires: Forge nearby", a missing tier) is
-- drawn disabled. A formspec button has no disabled state: it is greyed and
-- named grug_craft_recheck, and a click only rebuilds the page, which checks
-- the station again (the client shows the cached page when the inventory
-- opens, so a player who walked to the forge refreshes it this way).

local F = grug_jobs.CRAFT_FIELDS
local BOX = grug_jobs.CRAFT_BOX
local n, clip = grug_jobs._fs_number, grug_jobs._clip
local wrapped_labels = grug_jobs._wrapped_labels
local label_of = grug_jobs.recipe_label

local X = BOX.x + 0.2
local W = BOX.w - 0.4
local BUTTON_Y = BOX.y + BOX.h - 0.75
-- The quantity row sits right above the button.
local QUANTITY_Y = BUTTON_Y - 0.75
-- The middle area's first label (its centre) below the top area.
local MIDDLE_Y = BOX.y + 1.4
local INGREDIENT_ROWS, INGREDIENT_STEP = 5, 0.45
local NOTE_STEP = 0.38
-- The description: the height of a line, the least height worth drawing,
-- the room a scrollbar takes from the text's width.
local DESCRIPTION_LINE, DESCRIPTION_MIN, SCROLLBAR_W = 0.35, 0.8, 0.3
local COOKED_NOTE = "Must be cooked in a furnace to become edible."
local BOX_COLOR = "#00000040"
local WARN = "#ff9f5a"
local NOTE = "#f0c75e"
local XP_GREEN = "#7ae08a"
local XP_GREY = "#8a8a8a"
local DISABLED_STYLE = "style[" .. F.recheck ..
	";bgcolor=#2a2a2a;bgcolor_hovered=#2a2a2a;textcolor=#808080;border=false]"
-- Characters per real unit (ui.lua's rate).
local CHARS = 6.6

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- Whether a craft makes a stackable item: only those get a quantity field.
local function stackable(recipe)
	return ItemStack(recipe.output):get_stack_max() > 1
end

local function quantity_of(text)
	local value = tonumber(text)
	if value and value >= 1 and value % 1 == 0 then return value end
	return nil
end

-- A group entry (0.45.1 fix plan row 1): up to three members (by name) are
-- written out ("Carrot", "Carrot or Cassava", "Apple, Pear or Plum"); four
-- or more read as the group's hand-kept name below. A group of four or more
-- without one falls back to the generated "Any <Group Name>" label (add its
-- name here when such a group appears). The tooltip lists every member.
local GROUP_NAMES = {
	wool = "Any wool",
	stone = "Any stone",
	wood = "Any planks",
	grug_cooking_fruit = "Any fruit",
	grug_cooking_berry = "Any berry",
}
local WRITTEN_OUT = 3

local function group_label(group, names)
	if #names == 1 then return names[1] end
	if #names >= 2 and #names <= WRITTEN_OUT then
		return table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]
	end
	return GROUP_NAMES[group] or "Any " .. (group:gsub("_", " "):gsub("(%a)([%w']*)",
		function(a, b) return a:upper() .. b end))
end

-- A group's members (every item name, ordered by display name, then name),
-- label and tooltip, built once per group; the icon is per player
-- (group_icon).
local groups = {}
local function group_info(group)
	local info = groups[group]
	if info then return info end
	local names, by_label, members = {}, {}, {}
	for name in pairs(core.registered_items) do
		if core.get_item_group(name, group) > 0 then
			local label = grug_core.item_name(name)
			if not by_label[label] then
				names[#names + 1] = label
				by_label[label] = true
			end
			members[#members + 1] = {name = name, label = label}
		end
	end
	table.sort(names)
	table.sort(members, function(a, b)
		if a.label ~= b.label then return a.label < b.label end
		return a.name < b.name
	end)
	for index, member in ipairs(members) do members[index] = member.name end
	info = {
		members = members,
		label = group_label(group, names),
		tooltip = table.concat(names, " or "),
	}
	groups[group] = info
	return info
end

-- The member the player carries most of (the stacks have/need count,
-- `counts` from ingredient_counts), else the first member.
local function group_icon(info, counts)
	local icon, most = info.members[1] or "", 0
	for _, name in ipairs(info.members) do
		local have = counts and counts.items[name] or 0
		if have > most then icon, most = name, have end
	end
	return icon
end

-- "Crafting this will (not) give you a <profession> experience point", green
-- when the craft counts (a progress recipe of the profession's current tier
-- with XP left in the tier, as record_craft counts), grey with "not" for a
-- lower tier, the highest tier or a full tier count; nil for recipes that
-- never count and for a tier the player cannot craft yet.
local function xp_hint(player, recipe)
	if not recipe.progress or not grug_jobs.has(player, recipe.profession) then return nil end
	local level = grug_jobs.profession_level(player, recipe.profession)
	if recipe.tier > level then return nil end
	local needed = grug_jobs.CRAFTS_TO_ADVANCE[level]
	local counts = recipe.tier == level and needed ~= nil and
		grug_jobs.crafts_in_tier(player, recipe.profession) < needed
	local name = grug_jobs.PROFESSIONS[recipe.profession].name
	local article = name:match("^[AEIOUaeiou]") and "an " or "a "
	return ("Crafting this will %sgive you %s%s experience point"):format(
		counts and "" or "not ", article, name), counts and XP_GREEN or XP_GREY
end

local function area_name(recipe)
	return recipe.area == "basic" and "Basic" or grug_jobs.PROFESSIONS[recipe.area].name
end

-- What the made item's tooltip says, as plain text without the name line
-- the top area already shows ("" when nothing is left):
--   gear (whatever grug_items.crafted_output takes: weapons, armour,
--        offhands, trinkets, tools) is built on a copy exactly as the job
--        builds it; crafted gear is deterministic (Common, no enchants), so
--        item level, stats, requirement and durability are the real ones;
--   a raw dish (a Cooking recipe the furnace finishes) shows the cooked
--        dish, found through its furnace cooking recipe, and the note;
--   anything else its definition's description.
local function description_of(player, recipe)
	local name, text, note = recipe.output, nil, nil
	local items = rawget(_G, "grug_items")
	local stack = ItemStack(name)
	if items and type(items.crafted_output) == "function" and
			items.crafted_output(stack, player) then
		text = stack:get_meta():get_string("description")
	end
	if (not text or text == "") and recipe.area == "cooking" then
		local cooked = core.get_craft_result({method = "cooking", width = 1,
			items = {ItemStack(name)}})
		if cooked and cooked.item and not cooked.item:is_empty() then
			name, note = cooked.item:get_name(), COOKED_NOTE
		end
	end
	if not text or text == "" then
		local def = core.registered_items[name]
		text = def and def.description or ""
	end
	text = grug_core.plain_text(text)
	local first, rest = text:match("^([^\n]*)\n?(.*)$")
	if first:match("^%s*(.-)%s*$") == label_of(recipe.output) then text = rest end
	if note then text = text == "" and note or (text .. "\n" .. note) end
	return text:match("^%s*(.-)%s*$")
end

-- The number of lines `text` wraps to in `width` units.
local function line_count(text, width)
	local wrapped = grug_inventory.wrap_text(text, math.floor(width * CHARS))
	return select(2, wrapped:gsub("\n", "")) + 1
end

local function ingredient_rows(fs, recipe, counts, quantity, y)
	local list = recipe.ingredients
	local shown = #list > INGREDIENT_ROWS and INGREDIENT_ROWS - 1 or #list
	for index = 1, shown do
		local entry = list[index]
		local icon, label, tooltip = entry.item, nil, nil
		if entry.item then
			label = grug_core.item_name(entry.item)
		else
			local info = group_info(entry.group)
			icon, label, tooltip = group_icon(info, counts), info.label, info.tooltip
		end
		local have = grug_jobs.ingredient_have(counts, entry)
		local need = entry.n * quantity
		local amount = have .. "/" .. need
		-- The name takes the room up to have/need (a written-out group
		-- reads longer; the tooltip names every member).
		fs[#fs + 1] = ("item_image[%s,%s;0.4,0.4;%s]label[%s,%s;%s]label[%s,%s;%s]"):format(
			n(X), n(y), esc(icon), n(X + 0.5), n(y + 0.2),
			esc(clip(label, math.floor((W - 0.65 - 0.15 * #amount) * CHARS))),
			n(X + W - 0.15 * #amount), n(y + 0.2),
			esc(have >= need and amount or core.colorize(NOTE, amount)))
		if tooltip and tooltip ~= "" then
			fs[#fs + 1] = ("tooltip[%s,%s;%s,0.4;%s]"):format(n(X), n(y), n(W),
				esc(grug_inventory.wrap_text(tooltip, 40)))
		end
		y = y + INGREDIENT_STEP
	end
	if shown < #list then
		fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + 0.5), n(y + 0.2),
			esc(("... and %d more"):format(#list - shown)))
		y = y + INGREDIENT_STEP
	end
	return y
end

local function button(fs, job, enabled)
	local geometry = ("%s,%s;%s,0.65"):format(n(X), n(BUTTON_Y), n(W))
	if job then
		fs[#fs + 1] = ("button[%s;%s;Stop]"):format(geometry, F.stop)
	elseif enabled then
		fs[#fs + 1] = ("button[%s;%s;Craft now]"):format(geometry, F.go)
	else
		fs[#fs + 1] = DISABLED_STYLE ..
			("button[%s;%s;Craft now]"):format(geometry, F.recheck)
	end
end

local function build(player, view)
	local st, recipe, job = view.st, view.recipe, view.job
	local fs = {("box[%s,%s;%s,%s;%s]"):format(n(BOX.x), n(BOX.y), n(BOX.w), n(BOX.h),
		BOX_COLOR)}
	if not recipe then
		-- The overview fills the box (above Stop while a job runs).
		local bottom = job and BUTTON_Y - 0.1 or BOX.y + BOX.h
		fs[#fs + 1] = grug_jobs.professions_formspec(grug_jobs.profession_overview(player),
			{x = X, y = BOX.y + 0.05, w = W, h = bottom - BOX.y - 0.1})
		if job then button(fs, job) end
		return table.concat(fs)
	end
	local stacks = stackable(recipe)
	local most, by_ingredients, by_space = grug_jobs.max_craftable(player, recipe,
		view.counts)
	-- Max and "−"/"+" (clicks) are applied here, from this build's one
	-- inventory pass.
	if st.fill_max then st.qty, st.fill_max = tostring(math.max(1, most)), nil end
	if st.step then
		local value = quantity_of(st.qty) or 1
		if st.step < 0 and value > 1 then value = value - 1 end
		if st.step > 0 and value < most then value = value + 1 end
		st.qty, st.step = tostring(value), nil
	end
	local quantity = stacks and quantity_of(st.qty) or 1
	local sub = area_name(recipe) .. " · Tier " .. recipe.tier
	if recipe.count > 1 then sub = sub .. " · makes " .. recipe.count end
	-- The name in up to two lines beside the icon, then the area line.
	local width = math.floor((W - 1.05) * CHARS)
	local name = {}
	for piece in (grug_inventory.wrap_text(label_of(recipe.output), width) ..
			"\n"):gmatch("(.-)\n") do
		name[#name + 1] = piece
	end
	if #name > 2 then name = {name[1], clip(table.concat(name, " ", 2), width)} end
	local y = BOX.y + (#name > 1 and 0.3 or 0.45)
	fs[#fs + 1] = ("item_image[%s,%s;0.9,0.9;%s]"):format(n(X), n(BOX.y + 0.2),
		esc(recipe.output))
	for _, piece in ipairs(name) do
		fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + 1.05), n(y), esc(piece))
		y = y + 0.35
	end
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + 1.05), n(y + 0.05), esc(sub))
	-- The middle's warnings, the note and the XP hint, gathered first: the
	-- description takes the room they and the ingredients leave.
	local enabled, notes = true, {}
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if not allowed then
		enabled = false
		notes[#notes + 1] = {reason, WARN}
	elseif recipe.station and not grug_jobs.station_nearby(player, recipe.station) then
		enabled = false
		local info = grug_jobs.station_info(recipe.station)
		notes[#notes + 1] = {"Requires: " .. (info and info.display_name or recipe.station) ..
			" nearby", WARN}
	end
	if st.note then notes[#notes + 1] = {st.note, NOTE} end
	local hint, color = xp_hint(player, recipe)
	if hint then notes[#notes + 1] = {hint, color} end
	local note_lines = 0
	for _, entry in ipairs(notes) do note_lines = note_lines + line_count(entry[1], W) end
	-- Below the description: the heading, the ingredient rows, Max, the notes;
	-- all of it ends above the quantity row (or the button).
	local rows = math.min(#recipe.ingredients, INGREDIENT_ROWS)
	local below = 0.1 + 0.25 + rows * INGREDIENT_STEP + 0.65 + note_lines * NOTE_STEP
	local limit = (stacks and QUANTITY_Y or BUTTON_Y) - 0.05
	y = MIDDLE_Y
	local text = description_of(player, recipe)
	if text ~= "" then
		local top = MIDDLE_Y - 0.15
		local needed = line_count(text, W - SCROLLBAR_W) * DESCRIPTION_LINE + 0.15
		local height = math.min(needed, limit - below - MIDDLE_Y)
		if height >= DESCRIPTION_MIN then
			fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]textarea[%s,%s;%s,%s;;;%s]"):format(
				n(X), n(top), n(W), n(height), BOX_COLOR, n(X), n(top), n(W), n(height),
				esc(text))
			y = top + height + 0.25
		end
	end
	fs[#fs + 1] = ("label[%s,%s;Ingredients (have/need)]"):format(n(X), n(y))
	y = ingredient_rows(fs, recipe, view.counts, quantity, y + 0.25)
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X), n(y + 0.2), esc("Max: " .. most ..
		(by_space < by_ingredients and " (output area)" or "")))
	y = y + 0.65
	for _, entry in ipairs(notes) do
		y = wrapped_labels(fs, X, y, W, entry[1], entry[2], NOTE_STEP)
	end
	if stacks then
		-- Quantity [−][field][+] [Max] across the box's inner width.
		fs[#fs + 1] = ("label[%s,%s;Quantity]button[%s,%s;0.55,0.6;%s;−]" ..
			"field[%s,%s;0.95,0.6;%s;;%s]field_close_on_enter[%s;false]" ..
			"button[%s,%s;0.55,0.6;%s;+]button[%s,%s;0.9,0.6;%s;Max]"):format(
			n(X), n(QUANTITY_Y + 0.3), n(X + 1.25), n(QUANTITY_Y), F.minus,
			n(X + 1.85), n(QUANTITY_Y), F.qty, esc(st.qty), F.qty,
			n(X + 2.85), n(QUANTITY_Y), F.plus, n(X + 3.5), n(QUANTITY_Y), F.max)
	end
	button(fs, job, enabled)
	return table.concat(fs)
end

local function fields(player, st, fields)
	if fields[F.stop] then
		local ok, reason = grug_jobs.cancel_job(player)
		if not ok then st.note = reason end
		return true
	end
	if fields[F.recheck] then return true end
	local recipe = st.selected and grug_jobs.recipe(st.selected)
	if not recipe then return false end
	local stacks = stackable(recipe)
	if fields[F.max] then
		st.fill_max = true
		return true
	end
	if stacks and (fields[F.minus] or fields[F.plus]) then
		st.step = fields[F.plus] and 1 or -1
		return true
	end
	if fields.key_enter_field == F.qty then
		-- Recalculates (the build reads the field); never starts.
		if stacks and not quantity_of(st.qty) then
			st.note = "Enter a quantity of 1 or more."
		end
		return true
	end
	if fields[F.go] then
		local ok, reason, info = grug_jobs.start_job(player, recipe.id,
			stacks and (quantity_of(st.qty) or st.qty) or 1)
		if not ok then
			st.note = reason
			if info and (info.code == "space" or info.code == "ingredients") and
					(info.max or 0) > 0 then
				st.qty = tostring(info.max)
			end
		end
		return true
	end
	return false
end

grug_jobs.register_craft_box("recipe", {build = build, fields = fields})

-- Shared with lane EU's enchant and upgrade boxes (operation_box.lua).
grug_jobs._xp_hint = xp_hint
grug_jobs._ingredient_rows = ingredient_rows
