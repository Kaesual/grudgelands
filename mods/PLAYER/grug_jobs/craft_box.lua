-- The Crafting tab's recipe box (Round 45 lane UI; ui-crafting-rework-plan.md
-- §2.18, §4.2, §4.3), drawn into grug_jobs.CRAFT_BOX by ui.lua: the chosen
-- recipe's output, its ingredients with have/need, the maximum, the
-- quantity field with Max (stackable outputs only, default 1), the
-- warnings (the profession gate, "Requires: <station> nearby"), the note of
-- the last refused action, the XP hint, and Craft now, which turns into Stop
-- while a job runs. Without a chosen recipe the box shows the professions
-- overview (overview.lua): every known profession's tier, progress and the
-- level cap note.
--
-- The quantity field (spec §4.3): the server learns the typed number only
-- with an event. Enter in the field recalculates and never starts; Craft now
-- above the maximum lowers the field to it and shows jobs.lua's note
-- without starting; the last known value is echoed on every build.
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
local BUTTON_Y = BOX.y + BOX.h - 0.8
local INGREDIENT_ROWS, INGREDIENT_STEP = 5, 0.45
local NOTE_STEP = 0.38
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

-- A group entry's icon (its alphabetically first member by name), label
-- ("Any Wood") and tooltip (every member), built once per group.
local groups = {}
local function group_info(group)
	local info = groups[group]
	if info then return info end
	local names, by_label = {}, {}
	for name in pairs(core.registered_items) do
		if core.get_item_group(name, group) > 0 then
			local label = grug_core.item_name(name)
			if not by_label[label] then
				names[#names + 1] = label
				by_label[label] = name
			elseif name < by_label[label] then
				by_label[label] = name
			end
		end
	end
	table.sort(names)
	info = {
		icon = names[1] and by_label[names[1]] or "",
		label = "Any " .. (group:gsub("_", " "):gsub("(%a)([%w']*)",
			function(a, b) return a:upper() .. b end)),
		tooltip = table.concat(names, " or "),
	}
	groups[group] = info
	return info
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
			icon, label, tooltip = info.icon, info.label, info.tooltip
		end
		local have = grug_jobs.ingredient_have(counts, entry)
		local need = entry.n * quantity
		local amount = have .. "/" .. need
		fs[#fs + 1] = ("item_image[%s,%s;0.4,0.4;%s]label[%s,%s;%s]label[%s,%s;%s]"):format(
			n(X), n(y), esc(icon), n(X + 0.5), n(y + 0.2),
			esc(clip(label, math.floor(3.0 * CHARS))),
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
	-- Max (a click) is filled here, from this build's one inventory pass.
	if st.fill_max then st.qty, st.fill_max = tostring(math.max(1, most)), nil end
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
	fs[#fs + 1] = ("label[%s,%s;Ingredients (have/need)]"):format(n(X), n(BOX.y + 1.4))
	y = ingredient_rows(fs, recipe, view.counts, quantity, BOX.y + 1.65)
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X), n(y + 0.2), esc("Max: " .. most ..
		(by_space < by_ingredients and " (output area)" or "")))
	y = y + 0.5
	if stacks then
		fs[#fs + 1] = ("label[%s,%s;Quantity]field[%s,%s;1.2,0.6;%s;;%s]" ..
			"field_close_on_enter[%s;false]button[%s,%s;1,0.6;%s;Max]"):format(
			n(X), n(y + 0.3), n(X + 1.15), n(y), F.qty, esc(st.qty), F.qty,
			n(X + 2.45), n(y), F.max)
		y = y + 0.8
	end
	y = y + 0.15
	local enabled = true
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if not allowed then
		enabled = false
		y = wrapped_labels(fs, X, y, W, reason, WARN, NOTE_STEP)
	elseif recipe.station and not grug_jobs.station_nearby(player, recipe.station) then
		enabled = false
		local info = grug_jobs.station_info(recipe.station)
		y = wrapped_labels(fs, X, y, W, "Requires: " ..
			(info and info.display_name or recipe.station) .. " nearby", WARN, NOTE_STEP)
	end
	if st.note then y = wrapped_labels(fs, X, y, W, st.note, NOTE, NOTE_STEP) end
	local hint, color = xp_hint(player, recipe)
	if hint then wrapped_labels(fs, X, y, W, hint, color, NOTE_STEP) end
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
