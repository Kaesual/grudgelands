local function fail(message)
	error("grug_jobs recipe registry: " .. message, 0)
end

grug_jobs.PROFESSIONS = {
	blacksmith = {name = "Blacksmith", class = "primary"},
	alchemist = {name = "Alchemist", class = "primary"},
	tailor = {name = "Tailor", class = "primary"},
	leatherworker = {name = "Leatherworker", class = "primary"},
	woodcarver = {name = "Woodcarver", class = "primary"},
	goldsmith = {name = "Goldsmith", class = "primary"},
	cooking = {name = "Cooking", class = "secondary"},
}

grug_jobs.PRIMARY_PROFESSIONS = {
	"blacksmith", "alchemist", "tailor", "leatherworker", "woodcarver",
	"goldsmith",
}
grug_jobs.SECONDARY_PROFESSIONS = {"cooking"}
grug_jobs.STATIONS = {
	grid = true,
	furnace = true,
	dual_furnace = true,
	brewing_stand = true,
}

grug_jobs.recipes = {}

local ingredient_tiers = {}
local recipes_by_output = {}
local recipes_by_profession = {}
local station_handlers = {}
local ambiguous_crafts_logged = {}

local function item_name(value)
	if type(value) == "string" then
		return value:match("^%s*([^%s]+)") or ""
	end
	if type(value) == "userdata" or type(value) == "table" then
		if type(value.get_name) == "function" then
			return value:get_name()
		end
	end
	return ""
end

local function flatten_inputs(value, result)
	result = result or {}
	if type(value) == "string" or
			((type(value) == "userdata" or type(value) == "table") and
			type(value.get_name) == "function") then
		local name = item_name(value)
		if name ~= "" then result[#result + 1] = name end
	elseif type(value) == "table" then
		-- Engine recipe arrays may contain nil holes for empty shaped slots, so
		-- `#value` is not an authority for their last numeric index.
		local maximum = 0
		for key in pairs(value) do
			if type(key) == "number" and key % 1 == 0 and key > maximum then
				maximum = key
			end
		end
		for index = 1, maximum do
			flatten_inputs(value[index], result)
		end
	end
	return result
end

local function normalized_inputs(value)
	local names = flatten_inputs(value)
	table.sort(names)
	return table.concat(names, "\0")
end

local function group_matches(token, actual)
	local groups = token:match("^group:(.+)$")
	if not groups then return token == actual end
	if type(core.get_item_group) ~= "function" then return token == actual end
	for group in groups:gmatch("[^,]+") do
		if core.get_item_group(actual, group) <= 0 then return false end
	end
	return true
end

local function perfect_match(left, right, compatible, index, used)
	index = index or 1
	used = used or {}
	if index > #left then return true end
	for right_index = 1, #right do
		if not used[right_index] and compatible(left[index], right[right_index]) then
			used[right_index] = true
			if perfect_match(left, right, compatible, index + 1, used) then
				return true
			end
			used[right_index] = nil
		end
	end
	return false
end

-- Match the ingredients the engine actually selected, independent of their
-- craft-grid offset. Backtracking matters when one concrete item satisfies
-- both a broad and a narrow group token.
local function inputs_match(declared, actual)
	local wanted = flatten_inputs(declared)
	local got = flatten_inputs(actual)
	if #wanted ~= #got then return false end
	return perfect_match(wanted, got, group_matches)
end

local function tokens_overlap(first, second)
	local first_group = first:match("^group:(.+)$")
	local second_group = second:match("^group:(.+)$")
	if not first_group then return group_matches(second, first) end
	if not second_group then return group_matches(first, second) end
	local registered = core.registered_items or {}
	for name in pairs(registered) do
		if group_matches(first, name) and group_matches(second, name) then
			return true
		end
	end
	return false
end

-- Two recipe languages overlap when at least one concrete, unordered input
-- multiset can satisfy both. Group/group overlap is decidable once an item
-- belonging to both groups is registered; otherwise the final runtime guard
-- below remains authoritative.
local function input_languages_overlap(first, second)
	local left = flatten_inputs(first)
	local right = flatten_inputs(second)
	if #left ~= #right then return false end
	return perfect_match(left, right, tokens_overlap)
end

local function engine_method(station)
	if station == "grid" then return "normal" end
	if station == "furnace" then return "cooking" end
	return nil
end

local function all_engine_recipes()
	local result = {}
	if type(core.get_all_craft_recipes) ~= "function" then return result end
	local outputs = {}
	for name in pairs(core.registered_items or {}) do outputs[#outputs + 1] = name end
	table.sort(outputs)
	for output_index = 1, #outputs do
		local output = outputs[output_index]
		local recipes = core.get_all_craft_recipes(output) or {}
		for recipe_index = 1, #recipes do
			local recipe = recipes[recipe_index]
			result[#result + 1] = {
				method = recipe.method,
				items = recipe.items or {},
				output = item_name(recipe.output or output),
			}
		end
	end
	return result
end

local function dual_recipe_list()
	local smelting = rawget(_G, "grug_smelting")
	if not smelting or type(smelting.RECIPES) ~= "table" then return {} end
	return smelting.RECIPES
end

local function refuse_input_collision(station, inputs, output, engine, dual)
	local method = engine_method(station)
	if method then
		for index = 1, #engine do
			local existing = engine[index]
			if existing.method == method and
					input_languages_overlap(inputs, existing.items) then
				fail("profession " .. station .. " inputs for " .. output ..
					" collide with universal engine output " .. existing.output)
			end
		end
	elseif station == "dual_furnace" then
		for index = 1, #dual do
			local existing = dual[index]
			if input_languages_overlap(inputs, existing.inputs or {}) then
				fail("profession dual-furnace inputs for " .. output ..
					" collide with existing output " .. item_name(existing.output))
			end
		end
	end
end

local function dual_recipe_count(output)
	local count = 0
	local recipes = dual_recipe_list()
	for index = 1, #recipes do
		if item_name(recipes[index].output) == output then
			count = count + 1
		end
	end
	return count
end

local function engine_recipes(output)
	if type(core.get_all_craft_recipes) ~= "function" then return {} end
	return core.get_all_craft_recipes(output) or {}
end

local function refuse_existing_output(output)
	if #engine_recipes(output) > 0 then
		fail("profession output " .. output ..
			" already has a universal engine recipe")
	end
	if dual_recipe_count(output) > 0 then
		fail("profession output " .. output ..
			" already has a dual-furnace recipe")
	end
end

function grug_jobs.register_ingredient_tier(item, tier)
	local name = item_name(item)
	if name == "" then fail("an ingredient needs an itemstring") end
	if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > 6 then
		fail("ingredient " .. name .. " needs tier 1..6")
	end
	local old = ingredient_tiers[name]
	if old and old ~= tier then
		fail("ingredient " .. name .. " already has tier " .. old)
	end
	ingredient_tiers[name] = tier
	return tier
end

function grug_jobs.ingredient_tier(item)
	return ingredient_tiers[item_name(item)]
end

local function install_recipe(recipe)
	local handler = station_handlers[recipe.station]
	if handler and handler.register_recipe then
		handler.register_recipe(recipe)
	end
end

-- A future station (notably R8-ALCH's brewing stand) installs its recipe
-- adapter and optional per-player permission hook here. Recipes registered
-- before the station exists are retained and replayed exactly once. A custom
-- station owns its take path: before output leaves it MUST call
-- `grug_jobs.can_craft_recipe(player, recipe)`, and after a successful take it
-- MUST call `grug_jobs.record_craft(player, recipe.profession, recipe.tier)`.
-- Merely supplying `can_use` does not gate or settle a station inventory.
-- Craft callbacks and recipes must be registered during mod load or an
-- on-mods-loaded callback. grug_jobs finalizes authority on the first server
-- step; registrations after that step are unsupported and a terminality audit
-- logs an error before scheduling a repair.
function grug_jobs.register_station(station, definition)
	if not grug_jobs.STATIONS[station] then
		fail("unknown station " .. tostring(station))
	end
	if type(definition) ~= "table" then fail(station .. " station differs") end
	if definition.register_recipe ~= nil and
			type(definition.register_recipe) ~= "function" then
		fail(station .. " register_recipe differs")
	end
	if definition.can_use ~= nil and type(definition.can_use) ~= "function" then
		fail(station .. " can_use differs")
	end
	if station_handlers[station] then fail(station .. " station is already owned") end
	station_handlers[station] = definition
	for index = 1, #grug_jobs.recipes do
		local recipe = grug_jobs.recipes[index]
		if recipe.station == station then install_recipe(recipe) end
	end
end

function grug_jobs.station_handler(station)
	return station_handlers[station]
end

function grug_jobs.register_recipe(definition)
	if type(definition) ~= "table" then fail("recipe definition differs") end
	local profession = definition.profession
	local profession_def = grug_jobs.PROFESSIONS[profession]
	if not profession_def then
		fail("unknown profession " .. tostring(profession))
	end
	local tier = definition.tier
	if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > 6 then
		fail(profession .. " recipe needs tier 1..6")
	end
	local station = definition.station
	if not grug_jobs.STATIONS[station] then
		fail("unknown station " .. tostring(station))
	end
	if type(definition.inputs) ~= "table" and
			type(definition.inputs) ~= "string" then
		fail(profession .. " T" .. tier .. " recipe needs inputs")
	end
	local inputs = flatten_inputs(definition.inputs)
	if #inputs == 0 then fail(profession .. " T" .. tier .. " recipe has no input") end
	local has_own_tier = false
	for index = 1, #inputs do
		local input_tier = ingredient_tiers[inputs[index]]
		if input_tier == tier then has_own_tier = true end
		if input_tier and input_tier > tier then
			fail(profession .. " T" .. tier .. " recipe uses higher-tier ingredient " ..
				inputs[index])
		end
	end
	if not has_own_tier then
		fail(profession .. " T" .. tier ..
			" recipe needs at least one declared T" .. tier .. " ingredient")
	end
	local output = item_name(definition.output)
	if output == "" then fail(profession .. " recipe needs an output") end
	if recipes_by_output[output] then
		fail("duplicate profession output " .. output)
	end
	refuse_existing_output(output)
	refuse_input_collision(station, definition.inputs, output,
		all_engine_recipes(), dual_recipe_list())
	local input_key = normalized_inputs(definition.inputs)
	for index = 1, #grug_jobs.recipes do
		local previous = grug_jobs.recipes[index]
		if previous.station == station and
				input_languages_overlap(previous.inputs, definition.inputs) then
			fail("overlapping profession " .. station .. " inputs for " .. output ..
				" and " .. previous.output_name)
		end
	end
	if type(definition.hint) ~= "string" or definition.hint == "" then
		fail(output .. " needs a station hint")
	end

	local recipe = {
		profession = profession,
		tier = tier,
		station = station,
		inputs = definition.inputs,
		flat_inputs = inputs,
		output = definition.output,
		output_name = output,
		hint = definition.hint,
		time = definition.time,
		id = station .. "\0" .. input_key .. "\0" .. output,
		input_key = input_key,
	}
	grug_jobs.recipes[#grug_jobs.recipes + 1] = recipe
	recipes_by_output[output] = recipe
	local list = recipes_by_profession[profession]
	if not list then
		list = {}
		recipes_by_profession[profession] = list
	end
	list[#list + 1] = recipe
	install_recipe(recipe)
	return recipe
end

function grug_jobs.recipe_for_output(output)
	return recipes_by_output[item_name(output)]
end

local function ambiguous_craft(station, inputs)
	local key = station .. "\0" .. normalized_inputs(inputs)
	if not ambiguous_crafts_logged[key] then
		ambiguous_crafts_logged[key] = true
		if type(core.log) == "function" then
			core.log("error", "[grug_jobs] ambiguous profession " .. station ..
				" recipe inputs; craft refused")
		end
	end
	return nil, "ambiguous profession recipe inputs; contact an administrator"
end

-- Resolve one profession recipe by station and concrete ingredients. Inputs,
-- not a mutable callback output, are authoritative. Registration rejects every
-- overlap it can decide; if a later group definition creates an ambiguity, the
-- runtime safety net reports it and fails closed.
function grug_jobs.recipe_for_craft(station, output, inputs)
	local recipe = recipes_by_output[item_name(output)]
	if inputs == nil and recipe and recipe.station == station then
		return recipe
	end
	if inputs == nil then return nil end
	local found
	for index = 1, #grug_jobs.recipes do
		local candidate = grug_jobs.recipes[index]
		if candidate.station == station and inputs_match(candidate.inputs, inputs) then
			if found then return ambiguous_craft(station, inputs) end
			found = candidate
		end
	end
	return found
end

-- At registration time a profession output and input language must be unused.
-- Recheck after all mods have initialized so later engine/dual registrations
-- cannot silently override a profession recipe or become gated as one.
function grug_jobs.validate_recipe_collisions()
	local all_engine = all_engine_recipes()
	local all_dual = dual_recipe_list()
	for index = 1, #grug_jobs.recipes do
		local recipe = grug_jobs.recipes[index]
		local engine = engine_recipes(recipe.output_name)
		local expected_engine =
			(recipe.station == "grid" or recipe.station == "furnace") and 1 or 0
		if #engine ~= expected_engine then
			fail("profession output " .. recipe.output_name ..
				" collides with a universal engine recipe")
		end
		if expected_engine == 1 then
			local wanted_method = recipe.station == "grid" and "normal" or "cooking"
			if engine[1].method ~= wanted_method or
					not input_languages_overlap(recipe.inputs, engine[1].items or {}) then
				fail("profession output " .. recipe.output_name ..
					" engine recipe provenance differs")
			end
		end
		local wanted_method = engine_method(recipe.station)
		if wanted_method then
			local own = 0
			for engine_index = 1, #all_engine do
				local existing = all_engine[engine_index]
				if existing.method == wanted_method and
						input_languages_overlap(recipe.inputs, existing.items) then
					if existing.output ~= recipe.output_name then
						fail("profession " .. recipe.station .. " inputs for " ..
							recipe.output_name .. " collide with universal engine output " ..
							existing.output)
					end
					own = own + 1
				end
			end
			if own ~= 1 then
				fail("profession " .. recipe.station .. " inputs for " ..
					recipe.output_name .. " have " .. own .. " engine owners")
			end
		elseif recipe.station == "dual_furnace" then
			local own = 0
			for dual_index = 1, #all_dual do
				local existing = all_dual[dual_index]
				if input_languages_overlap(recipe.inputs, existing.inputs or {}) then
					if item_name(existing.output) ~= recipe.output_name then
						fail("profession dual-furnace inputs for " .. recipe.output_name ..
							" collide with existing output " .. item_name(existing.output))
					end
					own = own + 1
				end
			end
			if own ~= 1 then
				fail("profession dual-furnace inputs for " .. recipe.output_name ..
					" have " .. own .. " station owners")
			end
		end
		local expected_dual = recipe.station == "dual_furnace" and 1 or 0
		if dual_recipe_count(recipe.output_name) ~= expected_dual then
			fail("profession output " .. recipe.output_name ..
				" collides with a dual-furnace recipe")
		end
	end
	return true
end

function grug_jobs.recipes_for(profession, station)
	local source = recipes_by_profession[profession] or {}
	local result = {}
	for index = 1, #source do
		local recipe = source[index]
		if station == nil or recipe.station == station then
			result[#result + 1] = recipe
		end
	end
	table.sort(result, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		return a.output_name < b.output_name
	end)
	return result
end

grug_jobs._item_name = item_name
grug_jobs._flatten_inputs = flatten_inputs
grug_jobs._normalized_inputs = normalized_inputs
grug_jobs._inputs_match = inputs_match
grug_jobs._input_languages_overlap = input_languages_overlap
