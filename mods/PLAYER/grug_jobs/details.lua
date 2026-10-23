-- The recipe details page (Round 57 lane DETAILS, round57-plan.md ruling 5;
-- wireframe "Recipe details"): a crafting box ("details", ui.lua's
-- register_craft_box) over the chosen recipe, so the job strip ui.lua draws
-- under every box (the bar, the stop button, View Queue) stays (ruling 2).
--   header   "◀ Back" (one page back; from the first page to the box it was
--            opened from) and "Recipe details: <name>";
--   item     the made item's icon with its tooltip, its name, the area, tier,
--            station and count, and "Select this recipe" for a recipe the
--            player knows (one other than the chosen one);
--   boxes    one per ingredient: icon and tooltip, "<name> ×N", "you have
--            H", "Open ▶" to that ingredient's own recipe (a group: "Kinds ▶"
--            to a page of its kinds), the ingredient's sources from the
--            source index (sources.lua) and, while there is room, the
--            ingredients of its own recipe as small chips with tooltips.
-- A group page lists the group's kinds, each with its first source line and
-- "Open ▶" where it has a recipe, paged when it does not fit. An enchant or
-- upgrade page (opened from its box, operation_box.lua) shows the operation
-- and the boxes of its materials (an upgrade's for one level, a weapon's
-- extra included). ◀ and ▶ are in the engine's fonts, ◂ and ▸ are not.
--
-- Navigation exists only on this page: a stack of pages in the page state
-- (context.grug_craft.details, never saved). A page is
--   {kind = "recipe", id = <record id>}, {kind = "group", group, n, page} or
--   {kind = "operation", id = <station operation id>, target = <item name>}.
-- grug_jobs.open_recipe_details(st, page) starts a new stack; without one,
-- the page shows the chosen recipe.
--
-- Item tooltips: grug_items.tooltip_text (grug_quality's one helper) and the
-- item's source lines. "Open ▶" never goes to a loop-back recipe (bars from
-- their block, planks from stairs). Every text is clipped or wrapped to its column (the
-- window is the same on desktop and web).

local F = grug_jobs.CRAFT_FIELDS
local BOX = grug_jobs.CRAFT_BOX
local n = grug_jobs._fs_number
local X = BOX.x + 0.2
local W = BOX.w - 0.4
local CHARS = 6.6
local BOX_COLOR = "#00000040"
local DIM = "#b4b8bd"
local WARN = "#f0a35e"
local LINE = 0.36
-- The page's own fields.
local D = {back = "grug_craft_dback", open = "grug_craft_dopen_",
	kinds = "grug_craft_dkinds_", select = "grug_craft_dselect",
	prev = "grug_craft_dprev", next = "grug_craft_dnext"}
grug_jobs.DETAILS_FIELDS = D

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end
local function chars(width)
	return math.max(4, math.floor(width * CHARS))
end
local function clip(text, width)
	return grug_jobs._clip_chars and grug_jobs._clip_chars(text, chars(width)) or
		grug_jobs._clip(text, chars(width))
end
local function name_of(item)
	return grug_core.item_name(item)
end
local function index()
	return grug_jobs.item_sources()
end

-- The tooltip text of an item stack: grug_quality's one helper (not
-- formspec-escaped; tooltip_area escapes it).
local function tooltip_text(item, player)
	return grug_items.tooltip_text(item, player)
end

--
-- Source lines: what the index says about an item, one short line per kind
-- of source, in the index's order.
--

local function range(levels)
	if levels[1] == levels[2] then return "L" .. levels[1] end
	return "L" .. levels[1] .. "–" .. levels[2]
end

local function list_text(names, most)
	if #names <= most then return table.concat(names, ", ") end
	return table.concat(names, ", ", 1, most) .. " and " .. (#names - most) .. " more"
end

local function token_name(token)
	local group = token:match("^group:(.+)$")
	return group and ("any " .. group:gsub("_", " ")) or name_of(token)
end

-- The rock tiers T<a>–T<b> and their depth (grug_materials.TIERS).
local function rock_text(source)
	local tiers = grug_materials.TIERS
	local first, last = source.tiers[1], source.tiers[#source.tiers]
	local top = tiers[first].y_max
	if source.lower_half == first and tiers[first].lower_half_y_max then
		top = tiers[first].lower_half_y_max
	end
	local where = top >= 0 and "surface" or ("y " .. top)
	where = where .. (last == #tiers and " and deeper" or (" to y " .. tiers[last].y_min))
	local pick = source.pick_level > 0 and (tiers[source.pick_level].name .. " pick") or "any pick"
	return ("T%d%s rock (%s), %s"):format(first, last ~= first and ("–T" .. last) or "",
		where, pick)
end

local KIND_LINES = {}
function KIND_LINES.recipe(list)
	local labels, count, order = {}, {}, {}
	for _, source in ipairs(list) do
		local label
		if source.area == "basic" then
			label = "Basic recipe"
		else
			label = ("%s T%d recipe"):format(grug_jobs.PROFESSIONS[source.profession].name,
				source.tier)
			local station = source.station and grug_jobs.STATIONS[source.station]
			if station then label = label .. " at a " .. station.display_name end
		end
		if not count[label] then
			order[#order + 1] = label
			labels[label] = true
		end
		count[label] = (count[label] or 0) + 1
	end
	for i, label in ipairs(order) do
		if count[label] > 1 then order[i] = label .. " (" .. count[label] .. " ways)" end
	end
	return table.concat(order, "; ")
end
function KIND_LINES.furnace(list)
	local inputs = {}
	for i, source in ipairs(list) do inputs[i] = token_name(source.input) end
	return "Furnace: from " .. table.concat(inputs, " or ")
end
function KIND_LINES.alloy(list)
	local pairs_ = {}
	for i, source in ipairs(list) do
		pairs_[i] = name_of(source.inputs[1]) .. " + " .. name_of(source.inputs[2])
	end
	return "Dual Furnace: " .. table.concat(pairs_, " or ")
end
function KIND_LINES.vendor(list)
	local core_stock, shops, price = false, {}, nil
	for _, source in ipairs(list) do
		if source.vendor == "quartermaster" then
			core_stock = true
		else
			shops[#shops + 1] = source.label
		end
		if not price or source.price < price then price = source.price end
	end
	table.sort(shops)
	local shop_text = #shops > 3 and (#shops .. " shops in the capitals") or
		(#shops > 0 and (table.concat(shops, ", ") .. " (capitals)") or nil)
	local text = core_stock and "Sold by every Quartermaster" or "Sold by"
	if shop_text then text = text .. (core_stock and " and " or " ") .. shop_text end
	local money = rawget(_G, "grug_money")
	return text .. ", from " .. (money and money.format(price) or (price .. "c"))
end
-- The band drops by level, then the leaders, then the mobs outside every
-- drop table.
function KIND_LINES.drop(list)
	local bands, leaders, mobs = {}, {}, {}
	for _, source in ipairs(list) do
		if source.mob then
			mobs[#mobs + 1] = source.label ..
				(source.levels and (" (" .. range(source.levels) .. ")") or "")
		elseif source.leader then
			if #source.mobs > 0 then leaders[#leaders + 1] = "leaders " .. list_text(source.mobs, 2) end
		elseif #source.mobs > 0 then
			bands[#bands + 1] = {band = source.band, text = list_text(source.mobs, 2) ..
				" (" .. range(source.levels) .. ")"}
		end
	end
	table.sort(bands, function(a, b)
		if a.band ~= b.band then return a.band < b.band end
		return a.text < b.text
	end)
	local parts = {}
	for _, entry in ipairs(bands) do parts[#parts + 1] = entry.text end
	for _, text in ipairs(leaders) do parts[#parts + 1] = text end
	for _, text in ipairs(mobs) do parts[#parts + 1] = text end
	if #parts == 0 then return nil end
	return "Drops from: " .. table.concat(parts, ", ")
end
function KIND_LINES.gather(list)
	local parts, herb = {}, nil
	for _, source in ipairs(list) do
		if #source.zones > 0 then
			for _, id in ipairs(source.zones) do
				local zone = index().zone(id)
				local levels = source.levels or (zone and {zone.level_min, zone.level_max})
				parts[#parts + 1] = (zone and zone.display_name or id) ..
					(levels and (" (" .. range(levels) .. ")") or "")
			end
		elseif source.depth then
			parts[#parts + 1] = "caves below y " .. source.depth[2]
		else
			parts[#parts + 1] = "the wild"
		end
		herb = herb or source.alchemy_tier
	end
	return "Grows in " .. table.concat(parts, ", ") ..
		(herb and ("; needs Alchemy T" .. herb) or "")
end
function KIND_LINES.mining(list)
	local parts = {}
	for i, source in ipairs(list) do parts[i] = source.label .. " ore in " .. rock_text(source) end
	return "Mined: " .. table.concat(parts, "; ")
end
function KIND_LINES.tree(list)
	local labels = {}
	for i, source in ipairs(list) do labels[i] = source.label end
	return "From trees: " .. list_text(labels, 3)
end
function KIND_LINES.fishing(list)
	if #list == 6 then return ("Fished anywhere (%d %%)"):format(list[1].weight) end
	local parts = {}
	for i, source in ipairs(list) do
		parts[i] = ("%s waters (%d %%)"):format(range(source.levels), source.weight)
	end
	return "Fished in " .. table.concat(parts, ", ")
end
function KIND_LINES.farming(list)
	local seeds = {}
	for i, source in ipairs(list) do seeds[i] = name_of(source.seed) end
	return "Farmed from " .. table.concat(seeds, ", ")
end
function KIND_LINES.dig(list)
	local labels = {}
	for i, source in ipairs(list) do labels[i] = source.label end
	return "Dug from: " .. list_text(labels, 3)
end

function KIND_LINES.use(list)
	return list[1].text
end

-- The source lines of an item or an ingredient token: one per kind, or
-- "No known source". A group token reads as its kinds.
local NO_SOURCE = "No known source."
function grug_jobs.source_lines(token)
	local group = token:match("^group:(.+)$")
	if group then
		local names = {}
		for i, member in ipairs(index().members(group)) do names[i] = name_of(member) end
		return {"Any of: " .. list_text(names, 4)}
	end
	local lines, by_kind, kinds = {}, {}, {}
	for _, source in ipairs(index().sources(token)) do
		if not by_kind[source.kind] then
			by_kind[source.kind] = {}
			kinds[#kinds + 1] = source.kind
		end
		table.insert(by_kind[source.kind], source)
	end
	for _, kind in ipairs(kinds) do
		local line = KIND_LINES[kind](by_kind[kind])
		if line then lines[#lines + 1] = line end
	end
	if #lines == 0 then lines[1] = NO_SOURCE end
	return lines
end

-- An item's tooltip on the page: its own tooltip, then its sources.
local function item_tooltip(item, player)
	local text = tooltip_text(item, player)
	return text .. "\n" .. table.concat(grug_jobs.source_lines(item), "\n")
end

local function tooltip_area(fs, x, y, w, h, text)
	fs[#fs + 1] = ("tooltip[%s,%s;%s,%s;%s]"):format(n(x), n(y), n(w), n(h),
		esc(grug_inventory.wrap_text(text, 48)))
end

--
-- Recipes and knowledge.
--

-- Whether the player knows `recipe`: Basic by the held set
-- (recipe_known), a profession recipe up to the player's tier of it.
local function knows(player, recipe)
	if recipe.area == "basic" then return grug_jobs.recipe_known(player, recipe) end
	return grug_jobs.has(player, recipe.area) and
		recipe.tier <= grug_jobs.profession_level(player, recipe.area)
end
grug_jobs.details_knows = knows

-- Whether `recipe` (which makes `item`) loops back: one of its item
-- ingredients is made from `item` (a block unpacked into bars, planks from
-- stairs). It is no real source, so Open ▶ skips it.
local function loops_back(recipe, item)
	for _, entry in ipairs(recipe.ingredients) do
		for _, back in ipairs(entry.item and grug_jobs.recipes_for_output(entry.item) or {}) do
			for _, input in ipairs(back.ingredients) do
				if input.item == item then return true end
			end
		end
	end
	return false
end

-- The recipe "Open ▶" shows for an item: the first the player knows, else
-- the first (the index's order), never a loop-back; nil without one (the
-- box then shows the source lines only).
local function recipe_for(player, item)
	local first
	for _, source in ipairs(index().sources(item)) do
		if source.kind == "recipe" then
			local recipe = grug_jobs.recipe(source.id)
			if recipe and not loops_back(recipe, item) then
				if knows(player, recipe) then return recipe end
				first = first or recipe
			end
		end
	end
	return first
end

grug_jobs.details_recipe_for = function(player, item) return recipe_for(player, item) end

-- The area tab a recipe is listed in (ui.lua's slots: Basic, Cooking, the
-- two primary slots, Alchemy), or nil.
local function slot_of(player, recipe)
	if recipe.area == "basic" then return 1 end
	if recipe.area == "cooking" then return 2 end
	if recipe.area == "alchemist" then return 5 end
	for slot = 1, grug_jobs.PRIMARY_SLOTS do
		if grug_jobs.primary_at(player, slot) == recipe.area then return 2 + slot end
	end
	return nil
end

--
-- The state.
--

function grug_jobs.open_recipe_details(st, page)
	st.details = {pages = {page}}
	grug_jobs.open_craft_box(st, "details")
end

-- The page shown: the top of the stack, else the chosen recipe.
local function current(st)
	local pages = st.details and st.details.pages
	if pages and #pages > 0 then return pages[#pages] end
	return st.selected and {kind = "recipe", id = st.selected} or nil
end

-- The ingredient entries a page lists.
local function page_entries(page)
	if page.kind == "operation" then
		local op = grug_jobs.station_operation(page.id)
		if not op then return {} end
		return grug_jobs.operation_ingredients(op, page.target and ItemStack(page.target) or nil)
	end
	local recipe = page.kind == "recipe" and grug_jobs.recipe(page.id)
	return recipe and recipe.ingredients or {}
end

--
-- The build.
--

local function header(fs, y, title, name)
	fs[#fs + 1] = ("button[%s,%s;1.4,0.5;%s;%s]"):format(n(X), n(y), D.back, esc("◀ Back"))
	local text = core.colorize(DIM, title) .. " " .. clip(name, W - 1.6 - 0.15 * #title)
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + 1.6), n(y + 0.25), esc(text))
	return y + 0.65
end

local function recipe_subtitle(recipe)
	local parts = {recipe.area == "basic" and "Basic" or grug_jobs.PROFESSIONS[recipe.area].name}
	if recipe.area ~= "basic" then parts[#parts + 1] = "T" .. recipe.tier end
	local station = recipe.station and grug_jobs.STATIONS[recipe.station]
	if station then parts[#parts + 1] = station.display_name end
	parts[#parts + 1] = "makes " .. recipe.count
	return table.concat(parts, " · ")
end

-- The chips of an ingredient's own recipe: icon, "name ×n", tooltip.
local function chips(fs, player, x, y, width, recipe)
	local list = recipe.ingredients
	local w = (width - 0.1 * (#list - 1)) / #list
	for _, entry in ipairs(list) do
		local token = grug_jobs.ingredient_token(entry)
		local icon = entry.item or index().members(entry.group)[1] or ""
		fs[#fs + 1] = ("box[%s,%s;%s,0.45;%s]item_image[%s,%s;0.35,0.35;%s]label[%s,%s;%s]"):format(
			n(x), n(y), n(w), BOX_COLOR, n(x + 0.05), n(y + 0.05), esc(icon), n(x + 0.45),
			n(y + 0.22), esc(clip(token_name(token) .. " ×" .. entry.n, w - 0.5)))
		local tip = entry.item and item_tooltip(entry.item, player) or
			table.concat(grug_jobs.source_lines(token), "\n")
		tooltip_area(fs, x, y, w, 0.45, tip)
		x = x + w + 0.1
	end
end

-- One ingredient's box from `y`, `h` high.
local function ingredient_box(fs, player, view, index_, entry, y, h)
	local token = grug_jobs.ingredient_token(entry)
	local members = entry.group and index().members(entry.group) or nil
	local icon = entry.item or (members and members[1]) or ""
	local label = entry.item and name_of(entry.item) or token_name(token):gsub("^a", "A")
	fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]"):format(n(X), n(y), n(W), n(h - 0.1), BOX_COLOR)
	fs[#fs + 1] = ("item_image[%s,%s;0.45,0.45;%s]"):format(n(X + 0.1), n(y + 0.08), esc(icon))
	tooltip_area(fs, X + 0.1, y + 0.08, 0.45, 0.45, entry.item and item_tooltip(entry.item, player) or
		table.concat(grug_jobs.source_lines(token), "\n"))
	local have = view.counts and grug_jobs.ingredient_have(view.counts, entry) or 0
	local have_text = "you have " .. have
	local button_w = 1.3
	local own = entry.item and recipe_for(player, entry.item)
	if own then
		fs[#fs + 1] = ("button[%s,%s;%s,0.45;%s%d;%s]"):format(n(X + W - button_w - 0.05),
			n(y + 0.08), n(button_w), D.open, index_, esc("Open ▶"))
	elseif members then
		fs[#fs + 1] = ("button[%s,%s;%s,0.45;%s%d;%s]"):format(n(X + W - button_w - 0.05),
			n(y + 0.08), n(button_w), D.kinds, index_, esc("Kinds ▶"))
	end
	-- "you have" left of the button with room for a wider font (web).
	local have_x = X + W - button_w - 0.3 - 0.17 * #have_text
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(have_x), n(y + 0.3),
		esc(have < entry.n and core.colorize(WARN, have_text) or have_text))
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + 0.65), n(y + 0.3),
		esc(clip(label .. " ×" .. entry.n, have_x - X - 0.75)))
	-- The source lines, then the chips where the room allows.
	local inner = y + 0.6
	local bottom = y + h - 0.15
	local lines = grug_jobs.source_lines(token)
	local wrapped = {}
	for _, line in ipairs(lines) do
		for piece in (grug_inventory.wrap_text(line, chars(W - 0.7)) .. "\n"):gmatch("(.-)\n") do
			wrapped[#wrapped + 1] = piece
		end
	end
	-- The sources come first: the chips only where two lines (or all of
	-- them) still fit above them.
	local chip_room = own and #own.ingredients > 0 and
		bottom - inner - 0.5 >= math.min(#wrapped, 2) * LINE
	local line_bottom = chip_room and bottom - 0.5 or bottom
	local room = math.max(1, math.floor((line_bottom - inner) / LINE + 0.01))
	for i = 1, math.min(room, #wrapped) do
		local piece = wrapped[i]
		if i == room and #wrapped > room then piece = clip(piece .. " ..", W - 0.3) end
		fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + 0.15), n(inner + (i - 0.5) * LINE),
			esc(core.colorize(DIM, piece)))
	end
	if chip_room then chips(fs, player, X + 0.15, bottom - 0.47, W - 0.3, own) end
end

-- The ingredient boxes from `y` down to the box's bottom.
local function ingredient_boxes(fs, player, view, list, y)
	local h = math.min(2.6, (view.bottom - y) / math.max(1, #list))
	for i, entry in ipairs(list) do
		ingredient_box(fs, player, view, i, entry, y, h)
		y = y + h
	end
end

local function recipe_page(fs, player, view, page)
	local recipe = grug_jobs.recipe(page.id)
	if not recipe then return end
	local y = header(fs, BOX.y + 0.15, "Recipe details:", name_of(recipe.output))
	fs[#fs + 1] = ("item_image[%s,%s;0.8,0.8;%s]"):format(n(X), n(y), esc(recipe.output))
	tooltip_area(fs, X, y, 0.8, 0.8, item_tooltip(recipe.output, player))
	local select_w = 0
	if recipe.id ~= view.st.selected and knows(player, recipe) and slot_of(player, recipe) then
		select_w = 2.6
		fs[#fs + 1] = ("button[%s,%s;%s,0.6;%s;%s]"):format(n(X + W - select_w), n(y + 0.1),
			n(select_w), D.select, esc("Select this recipe"))
	end
	local text_w = W - 0.95 - select_w - 0.1
	fs[#fs + 1] = ("label[%s,%s;%s]label[%s,%s;%s]"):format(n(X + 0.95), n(y + 0.2),
		esc(clip(name_of(recipe.output), text_w)), n(X + 0.95), n(y + 0.6),
		esc(core.colorize(DIM, clip(recipe_subtitle(recipe), text_w))))
	ingredient_boxes(fs, player, view, recipe.ingredients, y + 1.0)
end

-- An enchant or upgrade: its title, the profession, tier and station, the
-- target item's icon (the operation's preview item without one), then the
-- materials.
local function operation_page(fs, player, view, page)
	local op = grug_jobs.station_operation(page.id)
	if not op then return end
	local title
	if op.operation == "enchant" then
		local affix = grug_items.AFFIXES[op.enchant_stat]
		title = ("Enchant: T%d %s %s"):format(op.tier, op.enchant_channel,
			affix and affix.label or op.enchant_stat)
	else
		title = ("Upgrade: T%d, one item level"):format(op.tier)
	end
	local y = header(fs, BOX.y + 0.15, "Details:", title)
	local icon = page.target or op.output_name or ""
	fs[#fs + 1] = ("item_image[%s,%s;0.8,0.8;%s]"):format(n(X), n(y), esc(icon))
	if icon ~= "" then tooltip_area(fs, X, y, 0.8, 0.8, tooltip_text(icon, player)) end
	local parts = {grug_jobs.PROFESSIONS[op.profession].name, "T" .. op.tier}
	local station = op.station and grug_jobs.STATIONS[op.station]
	if station then parts[#parts + 1] = station.display_name end
	parts[#parts + 1] = op.operation == "enchant" and
		(grug_jobs.OPERATION_SECONDS.enchant .. " s") or
		(grug_jobs.OPERATION_SECONDS.upgrade .. " s per level")
	local text_w = W - 1.05
	fs[#fs + 1] = ("label[%s,%s;%s]label[%s,%s;%s]"):format(n(X + 0.95), n(y + 0.2),
		esc(clip(page.target and ("On " .. name_of(page.target)) or title, text_w)),
		n(X + 0.95), n(y + 0.6), esc(core.colorize(DIM, clip(table.concat(parts, " · "), text_w))))
	ingredient_boxes(fs, player, view, page_entries(page), y + 1.0)
end

local ROW = 0.8
local function group_page(fs, player, view, page)
	local members = index().members(page.group)
	local y = header(fs, BOX.y + 0.15, "Kinds of:", token_name("group:" .. page.group))
	local per_page = math.max(1, math.floor((view.bottom - y - 0.6) / ROW))
	local pages = math.max(1, math.ceil(#members / per_page))
	page.page = math.max(1, math.min(page.page or 1, pages))
	local first = (page.page - 1) * per_page
	for i = first + 1, math.min(#members, first + per_page) do
		local item = members[i]
		fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]item_image[%s,%s;0.45,0.45;%s]"):format(n(X), n(y),
			n(W), n(ROW - 0.08), BOX_COLOR, n(X + 0.1), n(y + 0.12), esc(item))
		tooltip_area(fs, X + 0.1, y + 0.12, 0.45, 0.45, item_tooltip(item, player))
		local text_w = W - 0.75 - 1.45
		fs[#fs + 1] = ("label[%s,%s;%s]label[%s,%s;%s]"):format(n(X + 0.65), n(y + 0.2),
			esc(clip(name_of(item), text_w)), n(X + 0.65), n(y + 0.52),
			esc(core.colorize(DIM, clip(grug_jobs.source_lines(item)[1], text_w))))
		if recipe_for(player, item) then
			fs[#fs + 1] = ("button[%s,%s;1.3,0.45;%s%d;%s]"):format(n(X + W - 1.35), n(y + 0.12),
				D.open, i, esc("Open ▶"))
		end
		y = y + ROW
	end
	if pages > 1 then
		local pager_y = view.bottom - 0.5
		fs[#fs + 1] = ("button[%s,%s;0.6,0.5;%s;<]label[%s,%s;%s]button[%s,%s;0.6,0.5;%s;>]"):format(
			n(X + W / 2 - 1.6), n(pager_y), D.prev, n(X + W / 2 - 0.85), n(pager_y + 0.25),
			esc(("Page %d of %d"):format(page.page, pages)), n(X + W / 2 + 1.0), n(pager_y), D.next)
	end
end

local function build(player, view)
	local fs = {}
	local page = current(view.st)
	if page and page.kind == "group" then
		group_page(fs, player, view, page)
	elseif page and page.kind == "operation" then
		operation_page(fs, player, view, page)
	elseif page then
		recipe_page(fs, player, view, page)
	end
	return table.concat(fs)
end

--
-- The events.
--

local function push(st, page)
	st.details = st.details or {pages = {}}
	if #st.details.pages == 0 and st.selected then
		st.details.pages[1] = {kind = "recipe", id = st.selected}
	end
	table.insert(st.details.pages, page)
end

local function fields(player, st, fields_)
	local page = current(st)
	if not page then return false end
	if fields_[D.back] then
		local pages = st.details and st.details.pages
		if pages and #pages > 1 then
			table.remove(pages)
		else
			st.details = nil
			grug_jobs.close_craft_box(st)
		end
		return true
	end
	if fields_[D.select] and page.kind == "recipe" then
		local recipe = grug_jobs.recipe(page.id)
		local slot = recipe and knows(player, recipe) and slot_of(player, recipe)
		if slot then
			st.slot, st.page, st.selected, st.qty = slot, 1, recipe.id, "1"
			st.details, st.box, st.box_return = nil, nil, nil
		end
		return true
	end
	if page.kind == "group" then
		if fields_[D.prev] or fields_[D.next] then
			page.page = (page.page or 1) + (fields_[D.next] and 1 or -1)
			return true
		end
		local members = index().members(page.group)
		for i, item in ipairs(members) do
			if fields_[D.open .. i] then
				local recipe = recipe_for(player, item)
				if recipe then push(st, {kind = "recipe", id = recipe.id}) end
				return true
			end
		end
		return false
	end
	for i, entry in ipairs(page_entries(page)) do
		if fields_[D.open .. i] and entry.item then
			local recipe = recipe_for(player, entry.item)
			if recipe then push(st, {kind = "recipe", id = recipe.id}) end
			return true
		end
		if fields_[D.kinds .. i] and entry.group then
			push(st, {kind = "group", group = entry.group, n = entry.n, page = 1})
			return true
		end
	end
	return false
end

grug_jobs.register_craft_box("details", {build = build, fields = fields})
