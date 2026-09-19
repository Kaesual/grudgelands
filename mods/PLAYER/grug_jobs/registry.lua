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
	grid = {display_name = "Crafting Grid"},
	furnace = {display_name = "Furnace", node = "default:furnace"},
	dual_furnace = {display_name = "Dual Furnace",
		node = "grug_smelting:dual_furnace"},
	brewing_stand = {display_name = "Brewing Stand", profession = "alchemist",
		node = "grug_brewing:brewing_stand"},
	forge = {display_name = "Forge", profession = "blacksmith",
		node = "grug_jobs:forge"},
	tanning_rack = {display_name = "Tanning Rack", profession = "leatherworker",
		node = "grug_jobs:tanning_rack"},
	tailor_bench = {display_name = "Tailor Bench", profession = "tailor",
		node = "grug_jobs:tailor_bench"},
	carving_bench = {display_name = "Carving Bench", profession = "woodcarver",
		node = "grug_jobs:carving_bench"},
	jewellers_bench = {display_name = "Jeweller's Bench", profession = "goldsmith",
		node = "grug_jobs:jewellers_bench"},
}

function grug_jobs.station_info(station)
	local definition = grug_jobs.STATIONS[station]
	if type(definition) ~= "table" then return nil end
	return {id = station, display_name = definition.display_name,
		profession = definition.profession, node = definition.node}
end

grug_jobs.recipes = {}

local ingredient_tiers = {}
local recipes_by_output = {}
local recipes_by_profession = {}
local station_handlers = {}
local ambiguous_crafts_logged = {}
local in_place_universal_routes = {}
local registration_phase
local registry_metrics = {
	matrix_checks = 0,
	engine_output_scans = 0,
	group_item_checks = 0,
	token_overlap_computations = 0,
}

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

-- Build token compatibility once, then find a maximum bipartite matching with
-- one augmenting path per left slot. This is O(VE), unlike enumerating slot
-- permutations, and mirrors the graph/matching split in Luanti craftdef.cpp.
local function can_match_all(left, right, compatible)
	if #left ~= #right then return false end
	local graph = {}
	for left_index = 1, #left do
		local neighbors = {}
		for right_index = 1, #right do
			registry_metrics.matrix_checks = registry_metrics.matrix_checks + 1
			if compatible(left[left_index], right[right_index]) then
				neighbors[#neighbors + 1] = right_index
			end
		end
		graph[left_index] = neighbors
	end

	local matched_left = {}
	local function augment(left_index, seen)
		local neighbors = graph[left_index]
		for index = 1, #neighbors do
			local right_index = neighbors[index]
			if not seen[right_index] then
				seen[right_index] = true
				if not matched_left[right_index] or
						augment(matched_left[right_index], seen) then
					matched_left[right_index] = left_index
					return true
				end
			end
		end
		return false
	end

	for left_index = 1, #left do
		if not augment(left_index, {}) then return false end
	end
	return true
end

-- Match the ingredients the engine actually selected, independent of their
-- craft-grid offset. Maximum matching handles broad and narrow group tokens
-- without making a greedy choice or enumerating permutations.
local function inputs_match(declared, actual)
	local wanted = flatten_inputs(declared)
	local got = flatten_inputs(actual)
	return can_match_all(wanted, got, group_matches)
end

local function maximum_numeric_key(value)
	local maximum = 0
	for key in pairs(value or {}) do
		if type(key) == "number" and key % 1 == 0 and key > maximum then
			maximum = key
		end
	end
	return maximum
end

local function matrix_from_nested(value)
	local matrix = {}
	local height = maximum_numeric_key(value)
	local width = 0
	for row = 1, height do
		local row_value = type(value[row]) == "table" and value[row] or {}
		width = math.max(width, maximum_numeric_key(row_value))
		matrix[row] = row_value
	end
	return matrix, width, height
end

local function matrix_from_grid(value, width)
	local matrix = {}
	local maximum = maximum_numeric_key(value)
	local height = math.max(1, math.ceil(maximum / width))
	for row = 1, height do
		matrix[row] = {}
		for column = 1, width do
			matrix[row][column] = value[(row - 1) * width + column]
		end
	end
	return matrix, width, height
end

local function trim_matrix(matrix, width, height)
	local min_row, max_row, min_column, max_column
	for row = 1, height do
		for column = 1, width do
			if item_name(matrix[row] and matrix[row][column]) ~= "" then
				min_row = min_row and math.min(min_row, row) or row
				max_row = max_row and math.max(max_row, row) or row
				min_column = min_column and math.min(min_column, column) or column
				max_column = max_column and math.max(max_column, column) or column
			end
		end
	end
	if not min_row then return {}, 0, 0 end
	local result = {}
	for row = min_row, max_row do
		local target = {}
		for column = min_column, max_column do
			target[#target + 1] = item_name(matrix[row] and matrix[row][column])
		end
		result[#result + 1] = target
	end
	return result, max_column - min_column + 1, max_row - min_row + 1
end

-- Shaped recipes use the same placement rule as the engine grid: surrounding
-- empty rows and columns only move the pattern, while every slot inside the
-- trimmed rectangle is authoritative. Shapeless recipes retain the registry's
-- maximum-matching group semantics.
local function shaped_inputs_match(declared, actual)
	local declared_matrix, declared_width, declared_height =
		matrix_from_nested(declared)
	local actual_matrix, actual_width, actual_height
	if type(actual[1]) == "table" and
		(type(actual[1].get_name) ~= "function") then
		actual_matrix, actual_width, actual_height = matrix_from_nested(actual)
	else
		actual_matrix, actual_width, actual_height = matrix_from_grid(actual, 3)
	end
	local wanted, wanted_width, wanted_height = trim_matrix(declared_matrix,
		declared_width, declared_height)
	local got, got_width, got_height = trim_matrix(actual_matrix,
		actual_width, actual_height)
	if wanted_width ~= got_width or wanted_height ~= got_height then return false end
	for row = 1, wanted_height do
		for column = 1, wanted_width do
			local token = wanted[row][column]
			local name = got[row][column]
			if token == "" then
				if name ~= "" then return false end
			elseif name == "" or not group_matches(token, name) then
				return false
			end
		end
	end
	return true
end

local function new_comparison_phase()
	return {group_members = {}, token_members = {}, token_overlap = {}}
end

local function registration_comparison_phase()
	if not registration_phase then registration_phase = new_comparison_phase() end
	return registration_phase
end

local function group_member_set(group, phase)
	local cached = phase.group_members[group]
	if cached then return cached end
	local items = {}
	local count = 0
	for name in pairs(core.registered_items or {}) do
		registry_metrics.group_item_checks = registry_metrics.group_item_checks + 1
		if type(core.get_item_group) == "function" and
				core.get_item_group(name, group) > 0 then
			items[name] = true
			count = count + 1
		end
	end
	cached = {items = items, count = count}
	phase.group_members[group] = cached
	return cached
end

local function group_token_members(token, phase)
	local cached = phase.token_members[token]
	if cached then return cached end
	local groups = token:match("^group:(.+)$")
	if not groups then return nil end
	local sets = {}
	local smallest
	for group in groups:gmatch("[^,]+") do
		local members = group_member_set(group, phase)
		sets[#sets + 1] = members
		if not smallest or members.count < smallest.count then smallest = members end
	end
	local items = {}
	local count = 0
	for name in pairs(smallest and smallest.items or {}) do
		local present = true
		for index = 1, #sets do
			if not sets[index].items[name] then present = false break end
		end
		if present then items[name] = true count = count + 1 end
	end
	cached = {items = items, count = count}
	phase.token_members[token] = cached
	return cached
end

local function tokens_overlap(first, second, phase)
	local first_group = first:match("^group:(.+)$")
	local second_group = second:match("^group:(.+)$")
	if not first_group and not second_group then return first == second end
	local pair_key = first <= second and first .. "\0" .. second or
		second .. "\0" .. first
	local cached = phase.token_overlap[pair_key]
	if cached ~= nil then return cached end
	registry_metrics.token_overlap_computations =
		registry_metrics.token_overlap_computations + 1
	local overlap = false
	if not first_group then
		overlap = group_token_members(second, phase).items[first] == true
	elseif not second_group then
		overlap = group_token_members(first, phase).items[second] == true
	else
		local first_members = group_token_members(first, phase)
		local second_members = group_token_members(second, phase)
		local smaller, larger = first_members, second_members
		if second_members.count < first_members.count then
			smaller, larger = second_members, first_members
		end
		for name in pairs(smaller.items) do
			if larger.items[name] then overlap = true break end
		end
	end
	phase.token_overlap[pair_key] = overlap
	return overlap
end

-- Two recipe languages overlap when at least one concrete, unordered input
-- multiset can satisfy both. Group/group overlap is decidable once an item
-- belonging to both groups is registered; otherwise the final runtime guard
-- below remains authoritative.
local function input_languages_overlap(first, second, phase)
	local left = flatten_inputs(first)
	local right = flatten_inputs(second)
	phase = phase or registration_comparison_phase()
	return can_match_all(left, right, function(left_token, right_token)
		return tokens_overlap(left_token, right_token, phase)
	end)
end

local function engine_method(station)
	if station == "grid" then return "normal" end
	if station == "furnace" then return "cooking" end
	return nil
end

local function engine_corpus(phase)
	if phase.engine_corpus then return phase.engine_corpus end
	local corpus = {by_output = {}, by_method_count = {}}
	phase.engine_corpus = corpus
	if type(core.get_all_craft_recipes) ~= "function" then return corpus end
	local outputs = {}
	for name in pairs(core.registered_items or {}) do outputs[#outputs + 1] = name end
	table.sort(outputs)
	for output_index = 1, #outputs do
		local output = outputs[output_index]
		registry_metrics.engine_output_scans = registry_metrics.engine_output_scans + 1
		local recipes = core.get_all_craft_recipes(output) or {}
		for recipe_index = 1, #recipes do
			local recipe = recipes[recipe_index]
			local record = {
				method = recipe.method,
				items = recipe.items or {},
				output = item_name(recipe.output or output),
			}
			local output_recipes = corpus.by_output[record.output]
			if not output_recipes then
				output_recipes = {}
				corpus.by_output[record.output] = output_recipes
			end
			output_recipes[#output_recipes + 1] = record
			local by_count = corpus.by_method_count[record.method]
			if not by_count then
				by_count = {}
				corpus.by_method_count[record.method] = by_count
			end
			local count = #flatten_inputs(record.items)
			local bucket = by_count[count]
			if not bucket then bucket = {} by_count[count] = bucket end
			bucket[#bucket + 1] = record
		end
	end
	return corpus
end

local function engine_bucket(corpus, method, inputs)
	local by_count = corpus.by_method_count[method] or {}
	return by_count[#flatten_inputs(inputs)] or {}
end

local function dual_recipe_list()
	local smelting = rawget(_G, "grug_smelting")
	if not smelting or type(smelting.RECIPES) ~= "table" then return {} end
	return smelting.RECIPES
end

local function refuse_input_collision(station, inputs, output, phase, dual)
	local method = engine_method(station)
	if method then
		local corpus = engine_corpus(phase)
		local bucket = engine_bucket(corpus, method, inputs)
		for index = 1, #bucket do
			local existing = bucket[index]
			if existing.method == method and
					input_languages_overlap(inputs, existing.items, phase) then
				fail("profession " .. station .. " inputs for " .. output ..
					" collide with universal engine output " .. existing.output)
			end
		end
	elseif station == "dual_furnace" then
		for index = 1, #dual do
			local existing = dual[index]
			if input_languages_overlap(inputs, existing.inputs or {}, phase) then
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

local function output_route_count(output, station)
	local routes = recipes_by_output[output] or {}
	local count = 0
	for index = 1, #routes do
		if station == nil or routes[index].station == station then
			count = count + 1
		end
	end
	return count
end

local function refuse_existing_output(output, phase, in_place)
	local recipes = engine_corpus(phase).by_output[output] or {}
	local owned_engine = output_route_count(output, "grid") +
		output_route_count(output, "furnace")
	local universal_routes = math.max(0, #recipes - owned_engine)
	if not in_place and (universal_routes > 0 or
			(in_place_universal_routes[output] or 0) > 0) then
		fail("profession output " .. output ..
			" already has a universal engine recipe")
	end
	if dual_recipe_count(output) > output_route_count(output, "dual_furnace") then
		fail("profession output " .. output ..
			" already has a dual-furnace recipe")
	end
	return universal_routes
end

local function contains_exact_input(inputs, output)
	for index = 1, #inputs do
		if inputs[index] == output then return true end
	end
	return false
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
	if not old then registration_phase = nil end
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
-- grug_jobs finalizes craft authority on the first server step. Later calls to
-- the engine's craft-callback registration APIs remain supported: grug_jobs
-- inserts them synchronously before its terminal permission gate and logs the
-- first such late registration.
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
	if definition.shapeless ~= nil and type(definition.shapeless) ~= "boolean" then
		fail(profession .. " T" .. tier .. " shapeless flag differs")
	end
	if definition.in_place ~= nil and type(definition.in_place) ~= "boolean" then
		fail(profession .. " T" .. tier .. " in_place flag differs")
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
	if definition.in_place and
			(station ~= "grid" or not contains_exact_input(inputs, output)) then
		fail(output .. " in-place recipe must use the grid and consume its output")
	end
	local output_routes = recipes_by_output[output]
	if output_routes then
		for index = 1, #output_routes do
			local route = output_routes[index]
			if route.station == station then
				fail("duplicate profession output " .. output .. " at " .. station)
			end
			if route.profession ~= profession or route.tier ~= tier then
				fail("profession output " .. output ..
					" routes disagree on profession or tier")
			end
		end
	end
	local phase = registration_comparison_phase()
	local universal_routes = refuse_existing_output(output, phase,
		definition.in_place == true)
	refuse_input_collision(station, definition.inputs, output, phase,
		dual_recipe_list())
	local input_key = normalized_inputs(definition.inputs)
	for index = 1, #grug_jobs.recipes do
		local previous = grug_jobs.recipes[index]
		if previous.station == station and
				input_languages_overlap(previous.inputs, definition.inputs, phase) then
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
		in_place = definition.in_place == true,
		universal_output_routes = universal_routes,
		shapeless = definition.shapeless == true,
		shaped = definition.shapeless ~= true and
			type(definition.inputs) == "table" and
			type(definition.inputs[1]) == "table" and
			type(definition.inputs[1].get_name) ~= "function",
		id = station .. "\0" .. input_key .. "\0" .. output,
		input_key = input_key,
	}
	if recipe.in_place then
		in_place_universal_routes[output] = universal_routes
	end
	grug_jobs.recipes[#grug_jobs.recipes + 1] = recipe
	if not output_routes then
		output_routes = {}
		recipes_by_output[output] = output_routes
	end
	output_routes[#output_routes + 1] = recipe
	local list = recipes_by_profession[profession]
	if not list then
		list = {}
		recipes_by_profession[profession] = list
	end
	list[#list + 1] = recipe
	install_recipe(recipe)
	return recipe
end

function grug_jobs.recipe_for_output(output, station)
	local routes = recipes_by_output[item_name(output)] or {}
	if station == nil then return routes[1] end
	local found
	for index = 1, #routes do
		if routes[index].station == station then
			if found then return nil end
			found = routes[index]
		end
	end
	return found
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
	if inputs == nil then
		return grug_jobs.recipe_for_output(output, station)
	end
	local found
	for index = 1, #grug_jobs.recipes do
		local candidate = grug_jobs.recipes[index]
		if candidate.station == station then
			local matches = candidate.shaped and
				shaped_inputs_match(candidate.inputs, inputs) or
				(not candidate.shaped and inputs_match(candidate.inputs, inputs))
			if matches then
				if found then return ambiguous_craft(station, inputs) end
				found = candidate
			end
		end
	end
	return found
end

-- At registration time a profession output and input language must be unused.
-- Recheck after all mods have initialized so later engine/dual registrations
-- cannot silently override a profession recipe or become gated as one.
function grug_jobs.validate_recipe_collisions()
	local phase = new_comparison_phase()
	local corpus = engine_corpus(phase)
	local all_dual = dual_recipe_list()
	for index = 1, #grug_jobs.recipes do
		local recipe = grug_jobs.recipes[index]
		local engine = corpus.by_output[recipe.output_name] or {}
		local expected_engine = output_route_count(recipe.output_name, "grid") +
			output_route_count(recipe.output_name, "furnace") +
			(in_place_universal_routes[recipe.output_name] or 0)
		if #engine ~= expected_engine then
			fail("profession output " .. recipe.output_name ..
				" collides with a universal engine recipe")
		end
		if recipe.station == "grid" or recipe.station == "furnace" then
			local wanted_method = recipe.station == "grid" and "normal" or "cooking"
			local provenance = 0
			for engine_index = 1, #engine do
				if engine[engine_index].method == wanted_method and
						input_languages_overlap(recipe.inputs,
							engine[engine_index].items or {}, phase) then
					provenance = provenance + 1
				end
			end
			if provenance ~= 1 then
				fail("profession output " .. recipe.output_name ..
					" engine recipe provenance differs")
			end
		end
		local wanted_method = engine_method(recipe.station)
		if wanted_method then
			local own = 0
			local bucket = engine_bucket(corpus, wanted_method, recipe.inputs)
			for engine_index = 1, #bucket do
				local existing = bucket[engine_index]
				if existing.method == wanted_method and
						input_languages_overlap(recipe.inputs, existing.items, phase) then
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
				if input_languages_overlap(recipe.inputs, existing.inputs or {}, phase) then
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
		local expected_dual = output_route_count(recipe.output_name, "dual_furnace")
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
grug_jobs._input_languages_overlap = function(first, second)
	return input_languages_overlap(first, second, registration_comparison_phase())
end
grug_jobs._recipe_registry_metrics = function()
	return {
		matrix_checks = registry_metrics.matrix_checks,
		engine_output_scans = registry_metrics.engine_output_scans,
		group_item_checks = registry_metrics.group_item_checks,
		token_overlap_computations = registry_metrics.token_overlap_computations,
	}
end
