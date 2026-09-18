local BOOK_FORM = "grug_jobs:book"
local BOOK_TEXTURE = "grug_jobs_book.png"
local EMPTY_BOOK_TEXTURE = BOOK_TEXTURE .. "^[colorize:#777777:180"
local RECIPES_PER_PAGE = 6
local sessions = {}
local general_cache

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function output_name(output)
	return grug_jobs._item_name(output)
end

local function output_count(output)
	local count = type(output) == "string" and output:match("%s+(%d+)%s*$") or nil
	return tonumber(count) or 1
end

local function item_label(name)
	local definition = core.registered_items and core.registered_items[name]
	return definition and definition.description ~= "" and definition.description or name
end

local function inferred_tier(name)
	local definition = core.registered_items and core.registered_items[name] or {}
	local tier = tonumber(definition._grug_tier)
	if tier and tier >= 1 and tier <= 6 then return math.floor(tier) end
	local level = tonumber(definition._grug_ilvl)
	if level and level > 0 then
		return math.min(6, math.floor((level - 1) / 10) + 1)
	end
	return 1
end

local function engine_general_recipes()
	if general_cache then return general_cache end
	local result, seen = {}, {}
	local names = {}
	for name in pairs(core.registered_items or {}) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		local name = names[index]
		if not grug_jobs.recipe_for_output(name) and core.get_all_craft_recipes then
			local recipes = core.get_all_craft_recipes(name) or {}
			for recipe_index = 1, #recipes do
				local engine = recipes[recipe_index]
				local station = engine.method == "cooking" and "furnace" or
					(engine.method == "normal" and "grid" or nil)
				if station then
					local inputs = grug_jobs._flatten_inputs(engine.items or {})
					local key = station .. "\0" .. name .. "\0" ..
						table.concat(inputs, "\0")
					if not seen[key] then
						seen[key] = true
						result[#result + 1] = {
							profession = "general", tier = inferred_tier(name),
							station = station, flat_inputs = inputs,
							output = engine.output or name,
							output_name = name,
							hint = station == "grid" and "Crafting grid" or "Furnace",
						}
					end
				end
			end
		end
	end
	local smelting = rawget(_G, "grug_smelting")
	if smelting and type(smelting.RECIPES) == "table" then
		for index = 1, #smelting.RECIPES do
			local recipe = smelting.RECIPES[index]
			if not grug_jobs.recipe_for_output(recipe.output) then
				result[#result + 1] = {
					profession = "general", tier = inferred_tier(recipe.output),
					station = "dual_furnace", flat_inputs = recipe.inputs,
					output = recipe.output, output_name = recipe.output,
					hint = "Dual furnace",
				}
			end
		end
	end
	table.sort(result, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		if a.station ~= b.station then return a.station < b.station end
		return a.output_name < b.output_name
	end)
	general_cache = result
	return result
end

local function copied_filtered(source, station)
	local result = {}
	for index = 1, #source do
		if station == nil or source[index].station == station then
			result[#result + 1] = source[index]
		end
	end
	return result
end

function grug_jobs.book_records(player, book, station)
	if book == "general" then
		return copied_filtered(engine_general_recipes(), station)
	end
	if book == "station" then
		local result = copied_filtered(engine_general_recipes(), station)
		for profession in pairs(grug_jobs.PROFESSIONS) do
			if grug_jobs.has(player, profession) then
				local recipes = grug_jobs.recipes_for(profession, station)
				for index = 1, #recipes do result[#result + 1] = recipes[index] end
			end
		end
		table.sort(result, function(a, b)
			if a.tier ~= b.tier then return a.tier < b.tier end
			if a.profession ~= b.profession then return a.profession < b.profession end
			return a.output_name < b.output_name
		end)
		return result
	end
	return grug_jobs.recipes_for(book, station)
end

local function compressed_inputs(recipe)
	local order, counts = {}, {}
	for index = 1, #(recipe.flat_inputs or {}) do
		local name = recipe.flat_inputs[index]
		if name ~= "" then
			if not counts[name] then order[#order + 1] = name counts[name] = 0 end
			counts[name] = counts[name] + 1
		end
	end
	return order, counts
end

local function title_for(book, station)
	if book == "station" then
		local names = {furnace = "Furnace", dual_furnace = "Dual Furnace",
			brewing_stand = "Brewing Stand", grid = "Crafting Grid"}
		return (names[station] or "Station") .. " Recipes"
	end
	if book == "general" then return "General Recipe Book" end
	local definition = grug_jobs.PROFESSIONS[book]
	return (definition and definition.name or book) .. " Recipe Book"
end

function grug_jobs.book_formspec(player, book, station, page)
	local recipes = grug_jobs.book_records(player, book, station)
	local pages = math.max(1, math.ceil(#recipes / RECIPES_PER_PAGE))
	page = math.max(1, math.min(tonumber(page) or 1, pages))
	local fs = {
		"size[8,9.1]",
		("label[0.25,0.25;%s]"):format(esc(title_for(book, station))),
		("label[6.15,0.25;%s]"):format(esc(("Page %d/%d"):format(page, pages))),
	}
	local first = (page - 1) * RECIPES_PER_PAGE + 1
	for row = 1, RECIPES_PER_PAGE do
		local recipe = recipes[first + row - 1]
		if recipe then
			local y = 0.70 + (row - 1) * 1.12
			local unlocked = recipe.profession == "general" or
				grug_jobs.profession_level(player, recipe.profession) >= recipe.tier
			table.insert(fs, ("box[0.15,%.2f;7.7,1.02;%s]"):format(y,
				unlocked and "#20202055" or "#77777799"))
			table.insert(fs, ("item_image[0.25,%.2f;0.8,0.8;%s]"):format(
				y + 0.10, esc(recipe.output_name)))
			local count = output_count(recipe.output)
			local label = item_label(recipe.output_name) ..
				(count > 1 and (" x" .. count) or "")
			table.insert(fs, ("label[1.12,%.2f;%s]"):format(y + 0.12, esc(label)))
			local names, counts = compressed_inputs(recipe)
			for input_index = 1, math.min(4, #names) do
				local x = 1.12 + (input_index - 1) * 0.72
				local name = names[input_index]
				table.insert(fs, ("item_image[%.2f,%.2f;0.55,0.55;%s]"):format(
					x, y + 0.40, esc(name)))
				table.insert(fs, ("tooltip[%.2f,%.2f;0.55,0.55;%s]"):format(
					x, y + 0.40, esc(item_label(name))))
				if counts[name] > 1 then
					table.insert(fs, ("label[%.2f,%.2f;%s]"):format(
						x + 0.40, y + 0.69, counts[name]))
				end
			end
			local profession = recipe.profession ~= "general" and
				grug_jobs.PROFESSIONS[recipe.profession].name or "Universal"
			table.insert(fs, ("label[4.15,%.2f;%s]"):format(y + 0.12,
				esc(("T%d · %s"):format(recipe.tier, profession))))
			table.insert(fs, ("label[4.15,%.2f;%s]"):format(y + 0.45,
				esc(recipe.hint)))
			local requirement = recipe.profession == "general" and "No profession" or
				((unlocked and "Unlocked" or
				("Requires profession T%d (character L%d+)"):format(
					recipe.tier, (recipe.tier - 1) * 10 + 1)))
			table.insert(fs, ("label[4.15,%.2f;%s]"):format(y + 0.76,
				esc(requirement)))
		end
	end
	table.insert(fs, "button[0.25,7.75;1.25,0.65;grug_jobs_prev;Previous]")
	table.insert(fs, "button[1.65,7.75;1.25,0.65;grug_jobs_next;Next]")
	table.insert(fs, "button_exit[6.45,7.75;1.25,0.65;grug_jobs_close;Close]")
	return table.concat(fs), page, pages
end

function grug_jobs.open_book(player, book, station, page)
	local name = player:get_player_name()
	local formspec, actual = grug_jobs.book_formspec(player, book, station, page)
	sessions[name] = {book = book, station = station, page = actual}
	core.show_formspec(name, BOOK_FORM, formspec)
end

local function slot_button(fs, x, y, field, profession, empty_label)
	local definition = profession and grug_jobs.PROFESSIONS[profession]
	local texture = definition and BOOK_TEXTURE or EMPTY_BOOK_TEXTURE
	local tooltip = definition and (definition.name .. " recipe book") or empty_label
	fs[#fs + 1] = ("image_button[%.2f,%.2f;0.82,0.82;%s;%s;]"):format(
		x, y, texture, field)
	fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(tooltip))
end

function grug_jobs.crafting_page_content(player)
	local fs = {
		"label[0.05,0.15;Recipe books]",
		"list[current_player;craft;1.75,0.5;3,3;]",
		"list[current_player;craftpreview;5.75,1.5;1,1;]",
		"image[4.75,1.5;1,1;sfinv_crafting_arrow.png]",
		"listring[current_player;main]",
		"listring[current_player;craft]",
	}
	slot_button(fs, 0.10, 0.55, "grug_jobs_book_primary_1",
		grug_jobs.primary_at(player, 1), "Primary slot 1 — learn at a trainer")
	slot_button(fs, 0.10, 1.48, "grug_jobs_book_primary_2",
		grug_jobs.primary_at(player, 2), "Primary slot 2 — learn at a trainer")
	local cooking = grug_jobs.has(player, "cooking") and "cooking" or nil
	slot_button(fs, 0.10, 2.41, "grug_jobs_book_cooking", cooking,
		"Cooking — learn at a trainer")
	fs[#fs + 1] = ("image_button[0.10,3.34;0.82,0.82;%s;" ..
		"grug_jobs_book_general;]"):format(BOOK_TEXTURE)
	fs[#fs + 1] = "tooltip[grug_jobs_book_general;General recipe book]"
	return table.concat(fs)
end

local function crafting_fields(player, fields)
	for slot = 1, grug_jobs.PRIMARY_SLOTS do
		if fields["grug_jobs_book_primary_" .. slot] then
			local profession = grug_jobs.primary_at(player, slot)
			if profession then grug_jobs.open_book(player, profession) end
			return true
		end
	end
	if fields.grug_jobs_book_cooking then
		if grug_jobs.has(player, "cooking") then grug_jobs.open_book(player, "cooking") end
		return true
	end
	if fields.grug_jobs_book_general then
		grug_jobs.open_book(player, "general")
		return true
	end
end

sfinv.override_page("sfinv:crafting", {
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			grug_jobs.crafting_page_content(player), true)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		return crafting_fields(player, fields)
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= BOOK_FORM then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then return true end
	if fields.grug_jobs_prev then session.page = math.max(1, session.page - 1) end
	if fields.grug_jobs_next then session.page = session.page + 1 end
	if fields.grug_jobs_prev or fields.grug_jobs_next then
		grug_jobs.open_book(player, session.book, session.station, session.page)
	end
	if fields.quit then sessions[name] = nil end
	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)

function grug_jobs.station_book_button(station)
	return ("image_button[0.35,1.45;0.85,0.85;%s;grug_jobs_book;]" ..
		"tooltip[grug_jobs_book;Open station recipe books]"):format(BOOK_TEXTURE)
end

grug_jobs.BOOK_TEXTURE = BOOK_TEXTURE
grug_jobs.RECIPES_PER_PAGE = RECIPES_PER_PAGE
