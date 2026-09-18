local denial_times = {}

local function deny(player, recipe, reason)
	if not player or not player.get_player_name then return end
	local name = player:get_player_name()
	local now = core.get_gametime and core.get_gametime() or 0
	local key = name .. "\0" .. recipe.output_name
	if denial_times[key] == nil or now - denial_times[key] >= 1 then
		denial_times[key] = now
		core.chat_send_player(name, "Cannot craft " .. recipe.output_name .. ": " .. reason)
	end
end

local function grid_permission(itemstack, player, old_craft_grid)
	local recipe = grug_jobs.recipe_for_craft("grid", itemstack, old_craft_grid)
	if not recipe then return nil end
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
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

local function final_grid_predict(itemstack, player, old_craft_grid)
	return grid_permission(itemstack, player, old_craft_grid)
end

local function final_grid_craft(itemstack, player, old_craft_grid)
	local recipe = grug_jobs.recipe_for_craft("grid", itemstack, old_craft_grid)
	if not recipe then return nil end
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if not allowed then
		-- Predict is the normal veto, before the engine decrements anything. This
		-- callback is the fail-closed emergency path after decrement: never put the
		-- saved grid back, because another callback may already have replaced the
		-- output and restoring both would duplicate the ingredients.
		deny(player, recipe, reason)
		return ItemStack("")
	end
	grug_jobs.record_craft(player, recipe.profession, recipe.tier)
	return nil
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

-- Content mods depend on grug_jobs and therefore register after it. Once every
-- mod has initialized, put both vetoes back at the end of the real engine
-- chains. Luanti threads each callback's returned ItemStack into the next one,
-- so only the final position is authoritative.
core.register_on_mods_loaded(function()
	grug_jobs.validate_recipe_collisions()
	reappend(core.registered_craft_predicts, final_grid_predict)
	reappend(core.registered_on_crafts, final_grid_craft)
end)

local function wrap_furnace_formspecs()
	if not rawget(_G, "default") then return end
	local old_active = default.get_furnace_active_formspec
	local old_inactive = default.get_furnace_inactive_formspec
	if type(old_active) == "function" then
		default.get_furnace_active_formspec = function(...)
			return old_active(...) .. grug_jobs.station_book_button("furnace")
		end
	end
	if type(old_inactive) == "function" then
		default.get_furnace_inactive_formspec = function(...)
			return old_inactive(...) .. grug_jobs.station_book_button("furnace")
		end
	end
end

local function output_craft_count(pos, recipe, stack)
	local output = type(recipe.output) == "string" and
		tonumber(recipe.output:match("%s+(%d+)%s*$")) or nil
	output = output or 1
	local meta = core.get_meta(pos)
	local name_key = "grug_jobs:credit_output"
	local units_key = "grug_jobs:credit_units"
	local carried = meta:get_string(name_key) == recipe.output_name and
		meta:get_int(units_key) or 0
	local units = carried + stack:get_count()
	local crafts = math.floor(units / output)
	meta:set_string(name_key, recipe.output_name)
	meta:set_int(units_key, units - crafts * output)
	return crafts
end

local function wrap_station_node(node_name, listname, station)
	local definition = core.registered_nodes[node_name]
	if not definition then return end
	local old_allow = definition.allow_metadata_inventory_take
	local old_move = definition.allow_metadata_inventory_move
	local old_take = definition.on_metadata_inventory_take
	local old_receive = definition.on_receive_fields
	core.override_item(node_name, {
		allow_metadata_inventory_take = function(pos, list, index, stack, player)
			if list ~= listname then
				return old_allow and old_allow(pos, list, index, stack, player) or
					stack:get_count()
			end
			local recipe = grug_jobs.recipe_for_craft(station, stack)
			if not recipe then
				return old_allow and old_allow(pos, list, index, stack, player) or
					stack:get_count()
			end
			if not player or not player.get_meta then return 0 end
			local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
			if not allowed then deny(player, recipe, reason) return 0 end
			return old_allow and old_allow(pos, list, index, stack, player) or
				stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, from_list, from_index,
				to_list, to_index, count, player)
			if from_list == listname then
				local stack = core.get_meta(pos):get_inventory():get_stack(
					from_list, from_index)
				local recipe = grug_jobs.recipe_for_craft(station, stack)
				-- A metadata move has no corresponding take callback, so letting a
				-- profession output leave this list would bypass both permission
				-- and progression settlement. Players take it directly instead.
				if recipe then return 0 end
			end
			return old_move and old_move(pos, from_list, from_index, to_list,
				to_index, count, player) or count
		end,
		on_metadata_inventory_take = function(pos, list, index, stack, player)
			if old_take then old_take(pos, list, index, stack, player) end
			if list ~= listname then return end
			local recipe = grug_jobs.recipe_for_craft(station, stack)
			if recipe then
				local crafts = output_craft_count(pos, recipe, stack)
				for _ = 1, crafts do
					grug_jobs.record_craft(player, recipe.profession, recipe.tier)
				end
			end
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			if old_receive then old_receive(pos, formname, fields, sender) end
			if fields.grug_jobs_book and sender and sender:is_player() then
				grug_jobs.open_book(sender, "station", station)
			end
		end,
	})
end

wrap_furnace_formspecs()
wrap_station_node("default:furnace", "dst", "furnace")
wrap_station_node("default:furnace_active", "dst", "furnace")
wrap_station_node("grug_smelting:dual_furnace", "output", "dual_furnace")
wrap_station_node("grug_smelting:dual_furnace_active", "output",
	"dual_furnace")

core.register_on_leaveplayer(function(player)
	local prefix = player:get_player_name() .. "\0"
	for key in pairs(denial_times) do
		if key:sub(1, #prefix) == prefix then denial_times[key] = nil end
	end
end)
