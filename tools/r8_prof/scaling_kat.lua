-- Count-based KAT for profession recipe-language and engine-corpus scaling.
-- Usage: <lua> -e 'io.write(dofile(".../scaling_kat.lua")("/abs/repo"))'

return function(repo)
	local saved = {
		core = rawget(_G, "core"),
		grug_jobs = rawget(_G, "grug_jobs"),
		grug_smelting = rawget(_G, "grug_smelting"),
	}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_jobs", saved.grug_jobs)
		rawset(_G, "grug_smelting", saved.grug_smelting)
	end
	local function fail(message)
		restore()
		error("r8 profession scaling: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end
	local mutation = tonumber(os.getenv("R8_PROF_SCALING_MUTATION") or "") or 0

	local function load_registry(registered_items, universal, groups)
		local engine = {}
		local get_all_calls = 0
		local get_group_calls = 0
		core = {registered_items = registered_items}
		function core.get_all_craft_recipes(output)
			get_all_calls = get_all_calls + 1
			local result = {}
			local base = universal[output] or {}
			for index = 1, #base do result[#result + 1] = base[index] end
			local profession = engine[output] or {}
			for index = 1, #profession do result[#result + 1] = profession[index] end
			return #result > 0 and result or nil
		end
		function core.get_item_group(name, group)
			get_group_calls = get_group_calls + 1
			local item_groups = groups[name]
			return item_groups and item_groups[group] or 0
		end
		function core.register_craft(definition)
			local output = definition.output:match("^([^%s]+)")
			local list = engine[output]
			if not list then list = {} engine[output] = list end
			list[#list + 1] = {
				method = definition.type == "cooking" and "cooking" or "normal",
				items = definition.recipe,
				output = definition.output,
			}
		end
		grug_smelting = {RECIPES = {}}
		grug_jobs = {}
		dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
		return function() return get_all_calls, get_group_calls end
	end

	local function run_corpus_scale()
		local registered_items = {}
		local universal = {}
		local groups = {}
		registered_items["bench:universal_input"] = {}
		for index = 1, 2000 do
			local output = ("bench:universal_%04d"):format(index)
			registered_items[output] = {}
			universal[output] = {{method = "normal",
				items = {"bench:universal_input"}, output = output}}
		end
		for index = 1, 200 do
			registered_items[("bench:profession_input_%03d"):format(index)] = {}
			registered_items[("bench:profession_output_%03d"):format(index)] = {}
		end
		local counts = load_registry(registered_items, universal, groups)
		grug_jobs.register_station("grid", {
			register_recipe = function(recipe)
				core.register_craft({output = recipe.output, recipe = recipe.inputs})
			end,
		})
		for index = 1, 200 do
			grug_jobs.register_ingredient_tier(
				("bench:profession_input_%03d"):format(index), 1)
		end
		if mutation == 2 then
			local real_register = grug_jobs.register_recipe
			grug_jobs.register_recipe = function(definition)
				for name in pairs(core.registered_items) do
					core.get_all_craft_recipes(name)
				end
				return real_register(definition)
			end
		end
		for index = 1, 200 do
			grug_jobs.register_recipe({
				profession = "cooking",
				tier = 1,
				station = "grid",
				inputs = {("bench:profession_input_%03d"):format(index)},
				output = ("bench:profession_output_%03d"):format(index),
				hint = "Scaling fixture",
			})
		end
		grug_jobs.validate_recipe_collisions()
		local metrics = grug_jobs._recipe_registry_metrics()
		local get_all_calls, get_group_calls = counts()
		check(metrics.matrix_checks <= 861000,
			"compatibility matrix bound exceeded: " ..
			tostring(metrics.matrix_checks))
		check(metrics.engine_output_scans <= 4802,
			"engine corpus scan bound exceeded: " ..
			tostring(metrics.engine_output_scans))
		check(get_all_calls == metrics.engine_output_scans and get_all_calls <= 4802,
			"engine corpus was rescanned per profession recipe: " ..
			tostring(get_all_calls))
		check(get_group_calls == 0, "exact-token corpus performed group lookups")
		return metrics, get_all_calls
	end

	local function run_adversarial_groups()
		local registered_items = {}
		local groups = {}
		for index = 1, 498 do
			local name = ("group:item_%03d"):format(index)
			registered_items[name] = {}
			groups[name] = {broad = 1}
		end
		registered_items["group:left_only"] = {}
		groups["group:left_only"] = {left_only = 1}
		registered_items["group:right_only"] = {}
		groups["group:right_only"] = {right_only = 1}
		local counts = load_registry(registered_items, {}, groups)
		local left, right = {}, {}
		for index = 1, 8 do
			left[index] = "group:broad"
			right[index] = "group:broad"
		end
		left[9] = "group:left_only"
		right[9] = "group:right_only"
		if mutation == 1 then
			grug_jobs._input_languages_overlap = function() return true end
		end
		local before = grug_jobs._recipe_registry_metrics()
		check(not grug_jobs._input_languages_overlap(left, right),
			"adversarial nine-slot languages were reported as overlapping")
		local after = grug_jobs._recipe_registry_metrics()
		local get_all_calls, get_group_calls = counts()
		local matrix_checks = after.matrix_checks - before.matrix_checks
		local item_checks = after.group_item_checks - before.group_item_checks
		local pair_checks = after.token_overlap_computations -
			before.token_overlap_computations
		check(matrix_checks == 81,
			"nine-slot comparison did not build exactly one 9x9 matrix")
		check(item_checks == 1500 and get_group_calls == 1500,
			"group membership sets were not cached once per group")
		check(pair_checks == 4,
			"group token pairs were recomputed: " .. tostring(pair_checks))
		check(get_all_calls == 0, "language comparison scanned the engine corpus")
		return matrix_checks, item_checks, pair_checks
	end

	local scale, corpus_scans = run_corpus_scale()
	local matrix_checks, item_checks, pair_checks = run_adversarial_groups()
	local report = table.concat({
		"scale", "professions=200", "universal=2000",
		"matrix_checks=" .. scale.matrix_checks,
		"corpus_scans=" .. corpus_scans,
	}, "\t") .. "\n" .. table.concat({
		"adversarial", "slots=9", "broad_groups=8",
		"matrix_checks=" .. matrix_checks,
		"group_item_checks=" .. item_checks,
		"token_pairs=" .. pair_checks,
	}, "\t") .. "\n"
	restore()
	return report
end
