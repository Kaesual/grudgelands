local BOOK_FORM = "grug_jobs:book"
local BOOK_TEXTURE = "grug_jobs_book.png"
local EMPTY_BOOK_TEXTURE = BOOK_TEXTURE .. "^[colorize:#777777:180"
local GENERIC_STATION_TEXTURE = "default_furnace_front.png^[colorize:#9b743d:110"
local ITEMS_PER_PAGE = 14
local PROFESSION_STATIONS = {
	forge = true,
	tanning_rack = true,
	tailor_bench = true,
	carving_bench = true,
	jewellers_bench = true,
}
local sessions = {}
local general_cache
local record_cache = setmetatable({}, {__mode = "k"})

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function maximum_index(value)
	local maximum = 0
	if type(value) ~= "table" then return maximum end
	for key in pairs(value) do
		if type(key) == "number" and key % 1 == 0 and key > maximum then
			maximum = key
		end
	end
	return maximum
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

local function method_for_station(station)
	if station == "grid" then return "normal" end
	if station == "furnace" then return "cooking" end
	return station
end

local function registry_slots(recipe)
	local inputs = recipe.inputs
	if type(inputs) ~= "table" then return {grug_jobs._item_name(inputs)}, 1 end
	local rows = maximum_index(inputs)
	local nested = rows > 0 and type(inputs[1]) == "table" and
		type(inputs[1].get_name) ~= "function"
	if not nested then
		local slots = {}
		for index = 1, rows do slots[index] = grug_jobs._item_name(inputs[index]) end
		return slots, tonumber(recipe.width) or math.min(3, math.max(1, rows))
	end
	local width = 0
	for row = 1, rows do width = math.max(width, maximum_index(inputs[row])) end
	width = math.max(1, width)
	local slots = {}
	for row = 1, rows do
		for column = 1, width do
			slots[#slots + 1] = grug_jobs._item_name(inputs[row][column])
		end
	end
	return slots, width
end

local function cached_record(recipe)
	local cached = record_cache[recipe]
	if cached then return cached end
	local slots, width = registry_slots(recipe)
	local method = recipe.method or method_for_station(recipe.station)
	local shapeless = recipe.shapeless == true or
		(method == "normal" and tonumber(recipe.width) == 0)
	cached = {}
	for key, value in pairs(recipe) do cached[key] = value end
	cached.method = method
	cached.width = tonumber(recipe.width) or width
	cached.shapeless = shapeless
	cached.display_width = shapeless and math.min(3, math.max(1,
		#slots <= 4 and 2 or 3)) or math.max(1, width)
	cached.display_items = slots
	record_cache[recipe] = cached
	return cached
end

local function engine_record(name, engine, station)
	local maximum = maximum_index(engine.items or {})
	local slots = {}
	for index = 1, maximum do
		slots[index] = grug_jobs._item_name(engine.items[index])
	end
	local width = tonumber(engine.width) or 0
	local shapeless = engine.method == "normal" and width == 0
	local display_width = width
	if shapeless then
		display_width = #slots <= 4 and 2 or 3
	elseif engine.method == "cooking" then
		display_width = 1
	end
	return {
		profession = "general",
		tier = inferred_tier(name),
		station = station,
		inputs = engine.items or {},
		flat_inputs = grug_jobs._flatten_inputs(engine.items or {}),
		display_items = slots,
		display_width = math.max(1, display_width),
		width = width,
		method = engine.method,
		shapeless = shapeless,
		output = engine.output or name,
		output_name = name,
		hint = station == "grid" and "Crafting grid" or "Furnace",
	}
end

local function engine_general_recipes()
	if general_cache then return general_cache end
	local result, seen = {}, {}
	local names = {}
	for name in pairs(core.registered_items or {}) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		local name = names[index]
		if core.get_all_craft_recipes then
			local recipes = core.get_all_craft_recipes(name) or {}
			for recipe_index = 1, #recipes do
				local engine = recipes[recipe_index]
				local station = engine.method == "cooking" and "furnace" or
					(engine.method == "normal" and "grid" or nil)
				if station and not grug_jobs.recipe_for_craft(station, name,
						engine.items or {}) then
					local record = engine_record(name, engine, station)
					local key = table.concat({station, name, record.method,
						tostring(record.width), tostring(record.shapeless),
						table.concat(record.display_items, "\1")}, "\0")
					if not seen[key] then
						seen[key] = true
						result[#result + 1] = record
					end
				end
			end
		end
	end
	local smelting = rawget(_G, "grug_smelting")
	if smelting and type(smelting.RECIPES) == "table" then
		for index = 1, #smelting.RECIPES do
			local recipe = smelting.RECIPES[index]
			if not grug_jobs.recipe_for_craft("dual_furnace", recipe.output,
					recipe.inputs) then
				local inputs = {}
				for input = 1, #(recipe.inputs or {}) do
					inputs[input] = grug_jobs._item_name(recipe.inputs[input])
				end
				result[#result + 1] = {
					profession = "general", tier = inferred_tier(recipe.output),
					station = "dual_furnace", inputs = recipe.inputs,
					flat_inputs = grug_jobs._flatten_inputs(recipe.inputs),
					display_items = inputs, display_width = 2, width = 2,
					method = "dual_furnace", shapeless = true,
					output = recipe.output, output_name = output_name(recipe.output),
					hint = "Dual furnace",
				}
			end
		end
	end
	table.sort(result, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		if a.output_name ~= b.output_name then return a.output_name < b.output_name end
		if a.station ~= b.station then return a.station < b.station end
		return table.concat(a.display_items, "\0") < table.concat(b.display_items, "\0")
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

local function normalized_profession_records(profession, station)
	local source = grug_jobs.recipes_for(profession, station)
	local result = {}
	for index = 1, #source do result[index] = cached_record(source[index]) end
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
				local recipes = normalized_profession_records(profession, station)
				for index = 1, #recipes do result[#result + 1] = recipes[index] end
			end
		end
		table.sort(result, function(a, b)
			if a.tier ~= b.tier then return a.tier < b.tier end
			if a.output_name ~= b.output_name then return a.output_name < b.output_name end
			return a.station < b.station
		end)
		return result
	end
	return normalized_profession_records(book, station)
end

local function recipe_unlocked(player, recipe)
	return recipe.profession == "general" or
		grug_jobs.recipe_progress_unlocked(player, recipe)
end

local function recipe_discovered(player, recipe)
	return type(grug_jobs.recipe_discovered) ~= "function" or
		grug_jobs.recipe_discovered(player, recipe)
end

function grug_jobs.book_undiscovered_counts(player, records)
	local counts = {0, 0, 0, 0, 0, 0}
	for index = 1, #records do
		local recipe = records[index]
		if not recipe_discovered(player, recipe) then
			counts[recipe.tier] = counts[recipe.tier] + 1
		end
	end
	return counts
end

local function listed_records(player, records, search)
	search = tostring(search or ""):lower()
	local result = {}
	for index = 1, #records do
		local recipe = records[index]
		local text = (recipe.output_name .. " " .. item_label(recipe.output_name)):lower()
		if recipe_unlocked(player, recipe) and recipe_discovered(player, recipe) and
				(search == "" or text:find(search, 1, true)) then
			result[#result + 1] = recipe
		end
	end
	return result
end

local function output_groups(records)
	local order, groups = {}, {}
	for index = 1, #records do
		local name = records[index].output_name
		if not groups[name] then groups[name] = {} order[#order + 1] = name end
		groups[name][#groups[name] + 1] = records[index]
	end
	return order, groups
end

local function title_for(book, station)
	if book == "station" then
		local names = {furnace = "Furnace", dual_furnace = "Dual Furnace",
			brewing_stand = "Brewing Stand", grid = "Crafting Grid",
			forge = "Forge", tanning_rack = "Tanning Rack",
			tailor_bench = "Tailor Bench", carving_bench = "Carving Bench",
			jewellers_bench = "Jeweller's Bench"}
		return (names[station] or "Station") .. " Recipes"
	end
	if book == "general" then return "Basics" end
	local definition = grug_jobs.PROFESSIONS[book]
	return (definition and definition.name or book) .. " Recipe Book"
end

local function station_node(station)
	local metadata = grug_jobs.STATIONS and grug_jobs.STATIONS[station]
	local node_name
	if type(metadata) == "table" then
		node_name = metadata.node or metadata.node_name or metadata.item
	end
	local known = {furnace = "default:furnace",
		dual_furnace = "grug_smelting:dual_furnace",
		brewing_stand = "grug_brewing:brewing_stand"}
	node_name = node_name or known[station]
	if node_name and core.registered_nodes and core.registered_nodes[node_name] then
		return node_name
	end
	local names = {}
	for name in pairs(core.registered_nodes or {}) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		local definition = core.registered_nodes[names[index]]
		if definition._grug_station == station or
				definition._grug_station_id == station then return names[index] end
	end
	return nil
end

function grug_jobs.book_station_icon(station)
	local node = station_node(station)
	if node then return node, true end
	return GENERIC_STATION_TEXTURE, false
end

local function display_item(token)
	if token == "" or not token:match("^group:") then return token end
	local names = {}
	for name in pairs(core.registered_items or {}) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		local matches
		if grug_jobs._discovery_token_matches then
			matches = grug_jobs._discovery_token_matches(token, names[index])
		else
			local groups = token:match("^group:(.+)$")
			matches = true
			for group in groups:gmatch("[^,]+") do
				if not core.get_item_group or core.get_item_group(names[index], group) <= 0 then
					matches = false break
				end
			end
		end
		if matches then return names[index] end
	end
	return "unknown"
end

function grug_jobs._book_recipe_cells(recipe)
	local cells = {}
	local station = recipe.station
	if station == "furnace" then
		cells[1] = {column = 2, row = 2, token = recipe.flat_inputs[1] or ""}
	elseif station == "dual_furnace" then
		cells[1] = {column = 1, row = 2, token = recipe.flat_inputs[1] or ""}
		cells[2] = {column = 3, row = 2, token = recipe.flat_inputs[2] or ""}
	elseif station == "brewing_stand" then
		cells[1] = {column = 1, row = 1, token = recipe.flat_inputs[1] or ""}
		cells[2] = {column = 3, row = 1, token = recipe.flat_inputs[2] or ""}
		cells[3] = {column = 2, row = 3, token = recipe.flat_inputs[3] or ""}
	else
		local width = math.max(1, math.min(3, recipe.display_width or recipe.width or 1))
		for index = 1, #(recipe.display_items or {}) do
			local token = recipe.display_items[index]
			if token and token ~= "" then
				cells[#cells + 1] = {column = (index - 1) % width + 1,
					row = math.floor((index - 1) / width) + 1, token = token,
					slot = index}
			end
		end
	end
	return cells
end

function grug_jobs._book_recipe_background_cells(recipe)
	if recipe.station == "grid" or PROFESSION_STATIONS[recipe.station] then
		local cells = {}
		for row = 1, 3 do
			for column = 1, 3 do
				cells[#cells + 1] = {column = column, row = row}
			end
		end
		return cells
	end
	return grug_jobs._book_recipe_cells(recipe)
end

local function append_recipe(fs, recipe, alternative, alternative_count)
	local station_icon, station_item = grug_jobs.book_station_icon(recipe.station)
	if station_item then
		fs[#fs + 1] = ("item_image[0.25,6.55;0.85,0.85;%s]"):format(
			esc(station_icon))
	else
		fs[#fs + 1] = ("image[0.25,6.55;0.85,0.85;%s]"):format(
			esc(station_icon))
	end
	fs[#fs + 1] = ("tooltip[0.25,6.55;0.85,0.85;%s]"):format(
		esc(title_for("station", recipe.station):gsub(" Recipes$", "")))
	local backgrounds = grug_jobs._book_recipe_background_cells(recipe)
	for index = 1, #backgrounds do
		local cell = backgrounds[index]
		fs[#fs + 1] = ("box[%.2f,%.2f;0.82,0.82;#20202066]"):format(
			1.25 + (cell.column - 1) * 0.9, 5.65 + (cell.row - 1) * 0.9)
	end
	local cells = grug_jobs._book_recipe_cells(recipe)
	for index = 1, #cells do
		local cell = cells[index]
		local x = 1.25 + (cell.column - 1) * 0.9
		local y = 5.65 + (cell.row - 1) * 0.9
		local item = display_item(cell.token)
		fs[#fs + 1] = ("item_image[%.2f,%.2f;0.82,0.82;%s]"):format(x, y,
			esc(item))
			local label = item_label(cell.token)
			if cell.token:match("^group:") then
				local names, seen = {}, {}
				for name in pairs(core.registered_items or {}) do
					if grug_jobs._group_matches(cell.token, name) then
						local candidate = item_label(name):match("^[^\n]+")
						if not seen[candidate] then
							seen[candidate] = true
							names[#names + 1] = candidate
						end
					end
				end
				table.sort(names)
				label = #names > 0 and table.concat(names, " or ") or cell.token
			end
			fs[#fs + 1] = ("tooltip[%.2f,%.2f;0.82,0.82;%s]"):format(x, y,
				esc(label))
	end
	fs[#fs + 1] = "image[4.15,6.55;0.9,0.7;gui_furnace_arrow_bg.png^[transformR270]"
	fs[#fs + 1] = ("item_image[5.25,6.35;1.1,1.1;%s]"):format(
		esc(recipe.output_name))
	local count = output_count(recipe.output)
	fs[#fs + 1] = ("label[5.18,7.55;%s]"):format(esc(item_label(recipe.output_name) ..
		(count > 1 and (" x" .. count) or "")))
	fs[#fs + 1] = ("label[1.25,8.52;%s]"):format(esc(recipe.hint))
	if recipe.shapeless then fs[#fs + 1] = "label[4.18,5.75;Shapeless]" end
	fs[#fs + 1] = "button[6.75,6.35;0.65,0.65;grug_jobs_alt_prev;<]"
	fs[#fs + 1] = "button[8.55,6.35;0.65,0.65;grug_jobs_alt_next;>]"
	fs[#fs + 1] = ("label[7.48,6.55;%s]"):format(esc(("%d / %d"):format(
		alternative, alternative_count)))
	fs[#fs + 1] = ("label[6.75,7.25;T%d · %s]"):format(recipe.tier,
		esc(recipe.profession == "general" and "Universal" or
			grug_jobs.PROFESSIONS[recipe.profession].name))
end

local function make_formspec(player, book, station, state)
	local records = grug_jobs.book_records(player, book, station)
	local listed = listed_records(player, records, state.search)
	local outputs, alternatives = output_groups(listed)
	local pages = math.max(1, math.ceil(#outputs / ITEMS_PER_PAGE))
	state.page = math.max(1, math.min(tonumber(state.page) or 1, pages))
	local selected = state.output
	if not selected or not alternatives[selected] then selected = outputs[1] end
	state.output = selected
	local choices = selected and alternatives[selected] or nil
	local alternative_count = choices and #choices or 1
	state.alternative = ((tonumber(state.alternative) or 1) - 1) %
		alternative_count + 1
	local counts = grug_jobs.book_undiscovered_counts(player, records)
	local fs = {
		"formspec_version[4]size[10,9.8]",
		("label[0.25,0.25;%s]"):format(esc(title_for(book, station))),
		("field[0.3,0.72;3.7,0.7;grug_jobs_search;;%s]"):format(esc(state.search)),
		"field_close_on_enter[grug_jobs_search;false]",
		"button[4.05,0.66;1.0,0.7;grug_jobs_do_search;Search]",
		"button[5.10,0.66;0.9,0.7;grug_jobs_clear_search;Clear]",
		("label[8.0,0.82;%s]"):format(esc(("Page %d/%d"):format(state.page, pages))),
		"button[7.05,0.65;0.65,0.7;grug_jobs_prev;<]",
		"button[9.05,0.65;0.65,0.7;grug_jobs_next;>]",
	}
	local first = (state.page - 1) * ITEMS_PER_PAGE + 1
	for slot = 1, ITEMS_PER_PAGE do
		local name = outputs[first + slot - 1]
		if name then
			local column = (slot - 1) % 7
			local row = math.floor((slot - 1) / 7)
			fs[#fs + 1] = ("item_image_button[%.2f,%.2f;1,1;%s;grug_jobs_item_%d;]"):format(
				0.30 + column * 1.35, 1.45 + row * 1.25, esc(name), slot)
			fs[#fs + 1] = ("tooltip[grug_jobs_item_%d;%s]"):format(slot,
				esc(item_label(name)))
		end
	end
	local count_text = {}
	for tier = 1, 6 do count_text[#count_text + 1] = "T" .. tier .. ": " .. counts[tier] end
	fs[#fs + 1] = ("label[0.30,4.18;Undiscovered — %s]"):format(
		esc(table.concat(count_text, "   ")))
	fs[#fs + 1] = "box[0.25,4.65;9.5,0.04;#8c6b3ccc]"
	if choices then
		append_recipe(fs, choices[state.alternative], state.alternative, #choices)
	else
		fs[#fs + 1] = "label[3.05,6.65;No discovered recipes match.]"
	end
	fs[#fs + 1] = "button[8.25,8.92;1.45,0.65;grug_jobs_close;Close]"
	return table.concat(fs), state.page, pages, outputs
end

function grug_jobs.book_formspec(player, book, station, page, search, output, alternative)
	local state = {page = page or 1, search = search or "", output = output,
		alternative = alternative or 1}
	return make_formspec(player, book, station, state)
end

function grug_jobs.open_book(player, book, station, page)
	local name = player:get_player_name()
	local state = sessions[name]
	if not state or state.book ~= book or state.station ~= station then
		state = {book = book, station = station, page = page or 1, search = "",
			alternative = 1}
		sessions[name] = state
	elseif page then
		state.page = page
	end
	local formspec = make_formspec(player, book, station, state)
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
	fs[#fs + 1] = "tooltip[grug_jobs_book_general;Basics — profession-free recipes]"
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
	local state = sessions[name]
	if not state then return true end
	if fields.grug_jobs_close then
		sessions[name] = nil
		if core.close_formspec then core.close_formspec(name, BOOK_FORM) end
		sfinv.set_page(player, "sfinv:crafting")
		core.show_formspec(name, "", player:get_inventory_formspec())
		return true
	end
	local redraw = false
	if fields.grug_jobs_prev then state.page = state.page - 1 redraw = true end
	if fields.grug_jobs_next then state.page = state.page + 1 redraw = true end
	if fields.grug_jobs_do_search or fields.key_enter_field == "grug_jobs_search" then
		state.search = fields.grug_jobs_search or ""
		state.page, state.output, state.alternative = 1, nil, 1
		redraw = true
	elseif fields.grug_jobs_clear_search then
		state.search, state.page, state.output, state.alternative = "", 1, nil, 1
		redraw = true
	end
	for slot = 1, ITEMS_PER_PAGE do
		if fields["grug_jobs_item_" .. slot] then
			local _, _, _, outputs = make_formspec(player, state.book, state.station,
				state)
			local index = (state.page - 1) * ITEMS_PER_PAGE + slot
			state.output, state.alternative = outputs[index], 1
			redraw = true
			break
		end
	end
	if fields.grug_jobs_alt_prev then
		state.alternative = state.alternative - 1
		redraw = true
	elseif fields.grug_jobs_alt_next then
		state.alternative = state.alternative + 1
		redraw = true
	end
	if redraw then grug_jobs.open_book(player, state.book, state.station) end
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
grug_jobs.RECIPES_PER_PAGE = ITEMS_PER_PAGE
grug_jobs.BOOK_PROFESSION_STATIONS = PROFESSION_STATIONS
grug_jobs._reset_book_cache = function()
	general_cache = nil
	record_cache = setmetatable({}, {__mode = "k"})
end
