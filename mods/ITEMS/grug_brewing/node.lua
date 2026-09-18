local INACTIVE = "grug_brewing:brewing_stand"
local ACTIVE = "grug_brewing:brewing_stand_active"
local VIAL = "vessels:glass_bottle"
local STAND_FORM = "grug_brewing:stand"
local recipes = {}
local recipe_list = {}
local public_positions = {}

grug_brewing.NODE = INACTIVE
grug_brewing.NODE_ACTIVE = ACTIVE

local function pos_key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

function grug_brewing.register_public_position(pos)
	if type(pos) ~= "table" or type(pos.x) ~= "number" or
			type(pos.y) ~= "number" or type(pos.z) ~= "number" then
		error("grug_brewing: public position differs", 0)
	end
	public_positions[pos_key(pos)] = true
end

local function may_access(pos, player)
	if public_positions[pos_key(pos)] then return true end
	return player and player.is_player and player:is_player() and
		not core.is_protected(pos, player:get_player_name())
end

local function formspec(fuel_percent, brew_percent)
	local fire = "image[3.1,2.2;1,1;default_furnace_fire_bg.png"
	local arrow = "image[4.25,1.2;1,1;gui_furnace_arrow_bg.png"
	if fuel_percent then
		fire = fire .. "^[lowpart:" .. fuel_percent ..
			":default_furnace_fire_fg.png]"
		arrow = arrow .. "^[lowpart:" .. brew_percent ..
			":gui_furnace_arrow_fg.png^[transformR270]"
	else
		fire = fire .. "]"
		arrow = arrow .. "^[transformR270]"
	end
	local result = "formspec_version[3]size[12.5,11]" ..
		"label[0.5,0.45;Brewing Stand]" ..
		"label[1.1,1.15;Reagents]" ..
		"list[context;reagent;1,1.55;2,1;]" ..
		"label[1.35,2.75;Vial]list[context;vial;1.5,3.1;1,1;]" ..
		"label[3.05,3.45;Fuel]list[context;fuel;3.1,3.75;1,1;]" ..
		fire .. arrow ..
		"label[5.65,1.15;Output]list[context;output;5.6,1.55;2,1;]" ..
		"list[current_player;main;1.2,5.3;8,1;]" ..
		"list[current_player;main;1.2,6.55;8,3;8]" ..
		"listring[context;output]listring[current_player;main]" ..
		"listring[context;reagent]listring[current_player;main]" ..
		"listring[context;vial]listring[current_player;main]" ..
		"listring[context;fuel]listring[current_player;main]" ..
		default.get_hotbar_bg(1.2, 5.3)
	local jobs = rawget(_G, "grug_jobs")
	if jobs and type(jobs.station_book_button) == "function" then
		result = result .. jobs.station_book_button("brewing_stand")
	end
	return result
end

grug_brewing.formspec = formspec

local function input_key(first, second, vial)
	local pair = {first, second}
	table.sort(pair)
	return pair[1] .. "\0" .. pair[2] .. "\0" .. vial
end

function grug_brewing.register_recipe(recipe)
	if type(recipe) ~= "table" or recipe.station ~= "brewing_stand" or
			type(recipe.flat_inputs) ~= "table" or #recipe.flat_inputs ~= 3 then
		error("grug_brewing: recipe differs", 0)
	end
	local reagents = {}
	local vial_count = 0
	for index = 1, #recipe.flat_inputs do
		local item = recipe.flat_inputs[index]
		if item == VIAL then vial_count = vial_count + 1
		else reagents[#reagents + 1] = item end
	end
	if vial_count ~= 1 or #reagents ~= 2 then
		error("grug_brewing: recipe needs two reagents and one vial", 0)
	end
	local key = input_key(reagents[1], reagents[2], VIAL)
	if recipes[key] then error("grug_brewing: duplicate inputs", 0) end
	recipes[key] = {
		job = recipe, output = recipe.output, output_name = recipe.output_name,
		time = tonumber(recipe.time) or 5, reagents = reagents,
	}
	recipe_list[#recipe_list + 1] = recipes[key]
end

local function ingredient_matches(token, item)
	if token == item then return true end
	local group_names = token:match("^group:(.+)$")
	if not group_names then return false end
	for group in group_names:gmatch("[^,]+") do
		if core.get_item_group(item, group) <= 0 then return false end
	end
	return true
end

local function match_names(first, second, vial)
	if vial ~= VIAL then return nil end
	for index = 1, #recipe_list do
		local recipe = recipe_list[index]
		local reagents = recipe.reagents
		if (ingredient_matches(reagents[1], first) and
				ingredient_matches(reagents[2], second)) or
				(ingredient_matches(reagents[1], second) and
				ingredient_matches(reagents[2], first)) then
			return recipe
		end
	end
	return nil
end

local function matched(inv)
	local first = inv:get_stack("reagent", 1):get_name()
	local second = inv:get_stack("reagent", 2):get_name()
	local vial = inv:get_stack("vial", 1):get_name()
	if first == "" or second == "" or vial == "" then return nil end
	return match_names(first, second, vial)
end

function grug_brewing.match(first, second, vial)
	return match_names(first or "", second or "", vial or "")
end

local function is_fuel(stack)
	return core.get_craft_result({method = "fuel", width = 1,
		items = {stack}}).time ~= 0
end

local function swap_node(pos, name)
	local node = core.get_node(pos)
	if node.name == name then return end
	node.name = name
	core.swap_node(pos, node)
end

local function ensure_inventory(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local sizes = {reagent = 2, vial = 1, fuel = 1, output = 2}
	for listname, size in pairs(sizes) do
		if inv:get_size(listname) ~= size then inv:set_size(listname, size) end
	end
	if meta:get_string("formspec") == "" then
		meta:set_string("formspec", formspec(nil, 0))
		meta:set_string("infotext", "Brewing Stand")
	end
	return meta, inv
end

grug_brewing.ensure_inventory = ensure_inventory

local function timer(pos, elapsed)
	local meta, inv = ensure_inventory(pos)
	local fuel_time = meta:get_float("fuel_time") or 0
	local fuel_total = meta:get_float("fuel_total") or 0
	local brew_time = meta:get_float("brew_time") or 0
	local brew_recipe = meta:get_string("brew_recipe")
	local recipe
	local output_full = false
	local update = true
	while elapsed > 0 and update do
		update = false
		recipe = matched(inv)
		local recipe_name = recipe and recipe.output_name or ""
		if recipe_name ~= brew_recipe then
			brew_time = 0
			brew_recipe = recipe_name
		end
		local step = math.min(elapsed, fuel_total - fuel_time)
		if recipe then step = math.min(step, recipe.time - brew_time) end
		if step < 0 then step = 0 end
		if fuel_time < fuel_total then
			fuel_time = fuel_time + step
			if recipe then
				brew_time = brew_time + step
				if brew_time >= recipe.time then
					if inv:room_for_item("output", recipe.output) then
						for slot = 1, 2 do
							local stack = inv:get_stack("reagent", slot)
							stack:take_item(1)
							inv:set_stack("reagent", slot, stack)
						end
						local vial = inv:get_stack("vial", 1)
						vial:take_item(1)
						inv:set_stack("vial", 1, vial)
						inv:add_item("output", recipe.output)
						brew_time = brew_time - recipe.time
						update = true
					else
						output_full = true
					end
				else update = true end
			end
		else
			if recipe then
				local fuel, after = core.get_craft_result({method = "fuel", width = 1,
					items = inv:get_list("fuel")})
				if fuel.time > 0 then
					inv:set_stack("fuel", 1, after.items[1])
					fuel_total = fuel.time + (fuel_total - fuel_time)
					update = true
				else fuel_total = 0 brew_time = 0 end
			else fuel_total = 0 brew_time = 0 end
			fuel_time = 0
		end
		elapsed = elapsed - step
	end
	if not recipe then brew_time = 0 brew_recipe = "" end
	local active = fuel_total ~= 0
	local fuel_percent, brew_percent
	if active then
		fuel_percent = 100 - math.floor(fuel_time / fuel_total * 100)
		brew_percent = recipe and math.floor(brew_time / recipe.time * 100) or 0
		swap_node(pos, ACTIVE)
	else
		swap_node(pos, INACTIVE)
		core.get_node_timer(pos):stop()
	end
	meta:set_float("fuel_time", fuel_time)
	meta:set_float("fuel_total", fuel_total)
	meta:set_float("brew_time", brew_time)
	meta:set_string("brew_recipe", brew_recipe)
	meta:set_string("formspec", formspec(fuel_percent, brew_percent or 0))
	meta:set_string("infotext", active and "Brewing Stand active" or
		(output_full and "Brewing Stand (output full)" or "Brewing Stand"))
	return active
end

grug_brewing.timer = timer

local function initialize(pos)
	ensure_inventory(pos)
	timer(pos, 0)
end

local function on_rightclick(pos, node, player, itemstack)
	initialize(pos)
	if player and player:is_player() then
		local spos = pos.x .. "," .. pos.y .. "," .. pos.z
		local displayed = core.get_meta(pos):get_string("formspec")
		core.show_formspec(player:get_player_name(), STAND_FORM,
			displayed:gsub("context", "nodemeta:" .. spos))
	end
	return itemstack
end

local function allow_put(pos, listname, index, stack, player)
	if not may_access(pos, player) then return 0 end
	if listname == "output" then return 0 end
	if listname == "fuel" then return is_fuel(stack) and stack:get_count() or 0 end
	if listname == "vial" then return stack:get_name() == VIAL and stack:get_count() or 0 end
	return listname == "reagent" and stack:get_count() or 0
end

local function allow_move(pos, from_list, from_index, to_list, to_index,
		count, player)
	if from_list == "output" then return 0 end
	local stack = core.get_meta(pos):get_inventory():get_stack(from_list, from_index)
	return math.min(count, allow_put(pos, to_list, to_index, stack, player))
end

local function allow_take(pos, listname, index, stack, player)
	if not may_access(pos, player) then return 0 end
	if listname ~= "output" then return stack:get_count() end
	local jobs = rawget(_G, "grug_jobs")
	local recipe
	if jobs and type(jobs.recipe_for_output) == "function" then
		recipe = jobs.recipe_for_output(stack:get_name(), "brewing_stand")
	end
	if not recipe or recipe.station ~= "brewing_stand" or
			type(jobs.can_craft_recipe) ~= "function" then return 0 end
	local allowed = jobs.can_craft_recipe(player, recipe)
	return allowed and stack:get_count() or 0
end

local function on_take(pos, listname, index, stack, player)
	if listname == "output" then
		local jobs = rawget(_G, "grug_jobs")
		local recipe = jobs and jobs.recipe_for_output(stack:get_name(),
			"brewing_stand")
		if recipe and recipe.station == "brewing_stand" then
			for count = 1, stack:get_count() do
				jobs.record_craft(player, recipe.profession, recipe.tier)
			end
		end
	end
	core.get_node_timer(pos):start(1)
end

local function can_dig(pos)
	local inv = core.get_meta(pos):get_inventory()
	return inv:is_empty("reagent") and inv:is_empty("vial") and
		inv:is_empty("fuel") and inv:is_empty("output")
end

local function register(name, active)
	local groups = {cracky = 2}
	if active then groups.not_in_creative_inventory = 1 end
	local def = {
		description = "Brewing Stand",
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = {
			{-0.38, -0.5, -0.38, 0.38, -0.4, 0.38},
			{-0.08, -0.4, -0.08, 0.08, 0.3, 0.08},
			{-0.35, 0.2, -0.35, 0.35, 0.32, 0.35},
		}},
		tiles = {"default_steel_block.png^[colorize:#805020:55"},
		paramtype = "light", paramtype2 = "facedir", is_ground_content = false,
		groups = groups, sounds = default.node_sound_metal_defaults(), drop = INACTIVE,
		light_source = active and 6 or 0,
		on_timer = timer, can_dig = can_dig,
		on_rightclick = on_rightclick,
		allow_metadata_inventory_put = allow_put,
		allow_metadata_inventory_move = allow_move,
		allow_metadata_inventory_take = allow_take,
		on_metadata_inventory_put = function(pos) core.get_node_timer(pos):start(1) end,
		on_metadata_inventory_move = function(pos) core.get_node_timer(pos):start(1) end,
		on_metadata_inventory_take = on_take,
		on_blast = function(pos)
			local drops = {}
			for _, listname in ipairs({"reagent", "vial", "fuel", "output"}) do
				default.get_inventory_drops(pos, listname, drops)
			end
			drops[#drops + 1] = INACTIVE
			core.remove_node(pos)
			return drops
		end,
	}
	if not active then def.on_construct = initialize end
	default.set_inventory_action_loggers(def, "brewing stand")
	core.register_node(name, def)
end

register(INACTIVE, false)
register(ACTIVE, true)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= STAND_FORM then return false end
	if fields.grug_jobs_book and player and player:is_player() then
		local jobs = rawget(_G, "grug_jobs")
		if jobs and type(jobs.open_book) == "function" then
			jobs.open_book(player, "station", "brewing_stand")
		end
	end
	return true
end)

-- Blueprint writes bypass on_construct. This activates inventories for the
-- current capital projection whenever its mapblock is loaded.
core.register_lbm({
	label = "Activate brewing stands",
	name = "grug_brewing:activate",
	nodenames = {INACTIVE, ACTIVE},
	run_at_every_load = true,
	action = function(pos)
		if core.get_meta(pos):get_inventory():get_size("reagent") ~= 2 then
			initialize(pos)
		end
	end,
})
