local denial_times = {}

local function deny_message(player, key, message)
	if not player or not player.get_player_name then return end
	local name = player:get_player_name()
	local now = core.get_gametime and core.get_gametime() or 0
	local denial_key = name .. "\0" .. key
	if denial_times[denial_key] == nil or now - denial_times[denial_key] >= 1 then
		denial_times[denial_key] = now
		core.chat_send_player(name, message)
	end
end

local function deny(player, recipe, reason)
	deny_message(player, recipe.output_name,
		"Cannot craft " .. recipe.output_name .. ": " .. reason)
end

local function deny_resolution(player, reason)
	deny_message(player, "ambiguous_grid", "Cannot craft: " .. reason)
end

local function quality_permission(player, recipe)
	local quality_api = rawget(_G, "grug_items")
	if quality_api and type(quality_api.can_craft_quality) == "function" then
		return quality_api.can_craft_quality(player, recipe)
	end
	return true
end

local function grid_permission(itemstack, player, old_craft_grid)
	local recipe, resolution_error = grug_jobs.recipe_for_craft(
		"grid", itemstack, old_craft_grid)
	if resolution_error then
		deny_resolution(player, resolution_error)
		return ItemStack("")
	end
	if not recipe then return nil end
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if allowed then allowed, reason = quality_permission(player, recipe) end
	if allowed then return nil end
	deny(player, recipe, reason)
	return ItemStack("")
end

grug_jobs.register_station("grid", {
	register_recipe = function(recipe)
		core.register_craft({output = recipe.output, recipe = recipe.inputs})
	end,
})

grug_jobs.register_station("furnace", {
	register_recipe = function(recipe)
		if #recipe.flat_inputs ~= 1 then
			error("grug_jobs furnace recipe " .. recipe.output_name ..
				" needs exactly one input", 0)
		end
		core.register_craft({
			type = "cooking",
			output = recipe.output,
			recipe = recipe.flat_inputs[1],
			cooktime = tonumber(recipe.time) or 5,
		})
	end,
})

grug_jobs.register_station("dual_furnace", {
	register_recipe = function(recipe)
		if #recipe.flat_inputs ~= 2 then
			error("grug_jobs dual-furnace recipe " .. recipe.output_name ..
				" needs exactly two inputs", 0)
		end
		if not rawget(_G, "grug_smelting") or
				type(grug_smelting.register_alloy) ~= "function" then
			error("grug_jobs: dual furnace handler is unavailable", 0)
		end
		grug_smelting.register_alloy(recipe.output_name, recipe.flat_inputs[1],
			recipe.flat_inputs[2], tonumber(recipe.time) or 6)
	end,
})

-- `brewing_stand` intentionally has no registration handler here. R8-ALCH
-- registers it through `register_station` after creating the node.

local audit_terminal = function() end

local function final_grid_predict(itemstack, player, old_craft_grid)
	if not audit_terminal(core.registered_craft_predicts, final_grid_predict) then
		return nil
	end
	return grid_permission(itemstack, player, old_craft_grid)
end

local function final_grid_craft(itemstack, player, old_craft_grid)
	if not audit_terminal(core.registered_on_crafts, final_grid_craft) then
		return nil
	end
	local recipe, resolution_error = grug_jobs.recipe_for_craft(
		"grid", itemstack, old_craft_grid)
	if resolution_error then
		deny_resolution(player, resolution_error)
		return ItemStack("")
	end
	if not recipe then return nil end
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if allowed then allowed, reason = quality_permission(player, recipe) end
	if not allowed then
		-- Predict is the normal veto, before the engine decrements anything. This
		-- callback is the fail-closed emergency path after decrement: never put the
		-- saved grid back, because another callback may already have replaced the
		-- output and restoring both would duplicate the ingredients.
		deny(player, recipe, reason)
		return ItemStack("")
	end
	local quality_api = rawget(_G, "grug_items")
	if quality_api and type(quality_api.crafted_output) == "function" then
		quality_api.crafted_output(itemstack, player, recipe)
	end
	grug_jobs.record_craft(player, recipe.profession, recipe.tier)
	return itemstack
end

core.register_craft_predict(final_grid_predict)
core.register_on_craft(final_grid_craft)

local function reappend(callbacks, wanted)
	if type(callbacks) ~= "table" then
		error("grug_jobs: engine craft callback registry is unavailable", 0)
	end
	for index = #callbacks, 1, -1 do
		if callbacks[index] == wanted then table.remove(callbacks, index) end
	end
	callbacks[#callbacks + 1] = wanted
end

local authority_finalized = false
local registration_wrappers_installed = false
local late_registration_logged = false
local finalize_authority

local function log_late_registration()
	if late_registration_logged then return end
	late_registration_logged = true
	core.log("warning", "[grug_jobs] craft callback registered after the first " ..
		"server step; inserted before the terminal profession gate")
end

local function install_registration_wrappers()
	if registration_wrappers_installed then return end
	registration_wrappers_installed = true
	local register_predict = core.register_craft_predict
	local register_craft = core.register_on_craft
	core.register_craft_predict = function(callback)
		register_predict(callback)
		reappend(core.registered_craft_predicts, final_grid_predict)
		log_late_registration()
	end
	core.register_on_craft = function(callback)
		register_craft(callback)
		reappend(core.registered_on_crafts, final_grid_craft)
		log_late_registration()
	end
end

finalize_authority = function()
	grug_jobs.validate_recipe_collisions()
	reappend(core.registered_craft_predicts, final_grid_predict)
	reappend(core.registered_on_crafts, final_grid_craft)
	authority_finalized = true
	install_registration_wrappers()
end

audit_terminal = function(callbacks, wanted)
	if not authority_finalized or callbacks[#callbacks] == wanted then return true end
	-- A caller may have retained the pre-finalisation registration function and
	-- bypassed the wrappers above. Moving this callback while it is running is
	-- safe with Luanti's ipairs chain: this invocation does no work, later
	-- callbacks run, then the newly terminal invocation decides exactly once.
	reappend(callbacks, wanted)
	log_late_registration()
	return false
end

-- Content mods depend on grug_jobs and therefore register after it. Luanti's
-- mods-loaded runner freezes its callback count before iteration, so queueing
-- from here executes only on the first server step, after every later mod's
-- mods-loaded callback. Put both vetoes at the end then: callback replacements
-- are threaded forward, so only the terminal position is authoritative.
core.register_on_mods_loaded(function()
	core.after(0, finalize_authority)
end)

core.register_on_leaveplayer(function(player)
	local prefix = player:get_player_name() .. "\0"
	for key in pairs(denial_times) do
		if key:sub(1, #prefix) == prefix then denial_times[key] = nil end
	end
end)
