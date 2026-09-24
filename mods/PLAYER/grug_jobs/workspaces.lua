-- Detached inventories are views; node metadata owns every durable workspace.
local workspaces = {}
local automatic = dofile(core.get_modpath("grug_jobs") .. "/automatic.lua")
local viewers = {}
local sequence = 0
local FORM = "grug_jobs:workspace"
local PREFIX = "grug_jobs:workspace:"
local refresh

local function node_station(pos)
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	return def and def._grug_station, node
end

local function stamp(pos)
	local meta = core.get_meta(pos)
	local id = meta:get_string("grug_jobs:station_id")
	if id == "" then
		sequence = sequence + 1
		id = tostring(core.get_us_time()) .. ":" .. sequence
		meta:set_string("grug_jobs:station_id", id)
	end
	return id
end

local function accessible(ctx, player)
	if not player or not player:is_player() or player:get_player_name() ~= ctx.name or
			player:get_hp() <= 0 then return false end
	local at = player:get_pos()
	if not at or vector.distance(at, ctx.pos) > 8 then return false end
	if node_station(ctx.pos) ~= ctx.station or
			core.get_meta(ctx.pos):get_string("grug_jobs:station_id") ~= ctx.id then return false end
	return ctx.personal or not core.is_protected(ctx.pos, ctx.name)
end

local function inputs(ctx)
	return ctx.personal and ctx.inv or core.get_meta(ctx.pos):get_inventory()
end

local function save(ctx)
	local station = node_station(ctx.pos)
	if station ~= ctx.station or core.get_meta(ctx.pos):get_string("grug_jobs:station_id") ~= ctx.id then
		return
	end
	local record = {lists = {}, process = ctx.process, produced = ctx.produced}
	for list, stacks in pairs(ctx.inv:get_lists()) do
		if (ctx.personal and (ctx.automatic or list ~= "output")) or
				(list == "output" and ctx.produced) then
			local values = {}
			for index = 1, #stacks do values[index] = stacks[index]:to_string() end
			record.lists[list] = values
		end
	end
	local meta = core.get_meta(ctx.pos)
	local key, encoded = PREFIX .. ctx.name, core.serialize(record)
	-- The durable owner record must never be serialized to other clients.
	-- mark_as_private also accepts a not-yet-written key in the pinned engine.
	meta:mark_as_private(key)
	if meta:get_string(key) ~= encoded then meta:set_string(key, encoded) end
end

local function inventory_signature(ctx)
	local result = {}
	for _, list in ipairs({"src", "input", "mixture", "fuel", "dst", "output"}) do
		for _, stack in ipairs(ctx.inv:get_list(list) or {}) do
			result[#result + 1] = stack:to_string()
		end
	end
	return core.serialize(result)
end

-- Returns whether settlement changed an inventory slot. An allow callback
-- refuses that stale transfer; the next request sees the settled inventory.
local function advance(ctx)
	if not ctx.personal or not ctx.automatic then return false end
	local now = core.get_gametime()
	local elapsed = math.max(0, now - (ctx.process.last or now))
	ctx.process.last = now
	if elapsed == 0 then return false end
	local before = inventory_signature(ctx)
	local fuel, progress, recipe = ctx.process.fuel, ctx.process.progress, ctx.process.recipe
	automatic.advance(ctx.station, ctx.inv, ctx.process, elapsed)
	local changed_inventory = before ~= inventory_signature(ctx)
	-- Updating only the idle clock must not dirty the physical node every tick.
	if changed_inventory or fuel ~= ctx.process.fuel or progress ~= ctx.process.progress or
			recipe ~= ctx.process.recipe then save(ctx) end
	return changed_inventory
end

local function qualified(player, recipe)
	return recipe and grug_jobs.can_craft_recipe(player, recipe)
end

local function selected(ctx)
	if not ctx.operation or not grug_jobs.station_operations then return nil end
	for _, recipe in ipairs(grug_jobs.station_operations(ctx.station)) do
		if recipe.id == ctx.operation then return recipe end
	end
end

local function preview(ctx, player)
	local list = inputs(ctx):get_list("craft") or {}
	local recipe = selected(ctx)
	if recipe then
		local plan = grug_items.operation_plan(recipe, list, player)
		return plan and plan.output or ItemStack(""), plan and recipe or nil
	end
	recipe = grug_jobs.recipe_for_craft(ctx.station, ItemStack(""), list)
	if not qualified(player, recipe) then return ItemStack("") end
	local output = ItemStack(recipe.output)
	local quality = rawget(_G, "grug_items")
	if quality and quality.crafted_output then quality.crafted_output(output, player, recipe) end
	return output, recipe
end

local function set_output(ctx, stack)
	if ctx.inv:get_stack("output", 1):to_string() ~= stack:to_string() then
		ctx.inv:set_stack("output", 1, stack)
	end
end

local function formspec(ctx)
	local location = ctx.personal and "detached:" .. ctx.detached or
		"nodemeta:" .. ctx.pos.x .. "," .. ctx.pos.y .. "," .. ctx.pos.z
	local title = grug_jobs.station_info(ctx.station).display_name
	local mode = ctx.personal and "Personal workspace" or "Shared station"
	local explanation = ctx.personal and "Your work is saved here, separately for each station." or
		"Inputs and finished work are shared with players who can access this area."
	local result = "formspec_version[4]size[12,11]label[0.5,0.4;" .. core.formspec_escape(title) ..
		"]label[0.5,0.85;" .. mode .. "]label[0.5,1.25;" .. core.formspec_escape(explanation) .. "]"
	if ctx.automatic then
		local source = ctx.station == "furnace" and "src" or
			(ctx.station == "dual_furnace" and "input" or "mixture")
		local output = ctx.station == "furnace" and "dst" or "output"
		local width = ctx.station == "dual_furnace" and 2 or 1
		local furnace_kind = ctx.station == "furnace" or ctx.station == "dual_furnace"
		local fuel_percent, progress_percent = 0, 0
		if furnace_kind then
			local process = ctx.process
			if not ctx.personal then
				process = core.deserialize(core.get_meta(ctx.pos):get_string(
					"grug_jobs:process")) or {}
			end
			local fuel_fraction, progress_fraction = automatic.fractions(ctx.station,
				inputs(ctx), process)
			fuel_percent = math.floor(fuel_fraction * 100 + 0.5)
			progress_percent = math.floor(progress_fraction * 100 + 0.5)
		end
		result = result .. "label[1,1.9;" .. (source == "mixture" and "Prepared mixture" or "Input") ..
			"]list[" .. location .. ";" .. source .. ";1,2.3;" .. width .. ",1;]" ..
			"label[3.5,1.9;Fuel]list[" .. location .. ";fuel;3.5,2.3;1,1;]" ..
			"label[6,1.9;Finished output]list[" .. location .. ";" .. output .. ";6,2.3;2," ..
			(ctx.station == "furnace" and 2 or 1) .. ";]listring[" .. location .. ";" .. output ..
			"]listring[current_player;main]listring[" .. location .. ";" .. source ..
			"]listring[current_player;main]listring[" .. location .. ";fuel]listring[current_player;main]" ..
			(furnace_kind and "image[4.55,2.4;0.6,0.6;default_furnace_fire_bg.png]" or "") ..
			(furnace_kind and fuel_percent > 0 and "image[4.55,2.4;0.6,0.6;default_furnace_fire_bg.png^[lowpart:" ..
				fuel_percent .. ":default_furnace_fire_fg.png]" or "") ..
			(furnace_kind and "image[5.25,2.4;0.6,0.6;gui_furnace_arrow_bg.png^[transformR270]" or "") ..
			(furnace_kind and progress_percent > 0 and "image[5.25,2.4;0.6,0.6;gui_furnace_arrow_bg.png^[lowpart:" ..
				progress_percent .. ":gui_furnace_arrow_fg.png^[transformR270]" or "")
	else
		result = result .. "list[" .. location .. ";craft;1,2;3,3;]" ..
			"label[6,1.8;" .. (ctx.produced and "Crafted remainder" or "Qualified result") ..
			"]list[detached:" .. ctx.detached .. ";output;6,2.3;1,1;]" ..
			"listring[detached:" .. ctx.detached .. ";output]listring[current_player;main]" ..
			"listring[" .. location .. ";craft]listring[current_player;main]"
		local choices = {"Craft from inputs"}
		ctx.choices = {false}
		local chosen = 1
		for _, recipe in ipairs(grug_jobs.station_operations and grug_jobs.station_operations(ctx.station) or {}) do
			if grug_jobs.can_craft_recipe(core.get_player_by_name(ctx.name), recipe) then
				choices[#choices + 1] = core.formspec_escape(recipe.label or recipe.id)
				ctx.choices[#ctx.choices + 1] = recipe.id
				if ctx.operation == recipe.id then chosen = #choices end
			end
		end
		if #choices > 1 then
			result = result .. "dropdown[5,3.7;6.5,0.8;operation;" .. table.concat(choices, ",") ..
				";" .. chosen .. ";true]"
		end
		if ctx.operation then result = result .. "button[7.3,2.3;2,0.8;apply;Apply]" end
	end
	return result .. "list[current_player;main;1,6;8,1;]list[current_player;main;1,7.25;8,3;8]" ..
		default.get_hotbar_bg(1, 6) .. grug_jobs.station_book_button(ctx.station, 10.3, 2.3)
end

refresh = function(ctx, show)
	local player = core.get_player_by_name(ctx.name)
	if not accessible(ctx, player) then
		if not ctx.automatic and not ctx.produced then set_output(ctx, ItemStack("")) end
		return
	end
	if not ctx.automatic and not ctx.produced then
		local output, recipe = preview(ctx, player)
		ctx.recipe = recipe
		set_output(ctx, output)
	end
	if show then core.show_formspec(ctx.name, FORM, formspec(ctx)) end
end

local function refresh_position(pos)
	for _, ctx in pairs(viewers) do
		if vector.equals(ctx.pos, pos) then refresh(ctx, false) end
	end
end

local function changed(ctx)
	if ctx.personal and (ctx.station == "furnace" or ctx.station == "dual_furnace") then
		automatic.advance(ctx.station, ctx.inv, ctx.process, 0)
	end
	save(ctx)
	refresh_position(ctx.pos)
end

local function detach(ctx)
	if not ctx then return end
	save(ctx)
	core.remove_detached_inventory(ctx.detached)
	viewers[ctx.name] = nil
end

local function callbacks(ctx)
	return {
		allow_put = function(inv, list, index, stack, player)
			if not accessible(ctx, player) or not ctx.personal then return 0 end
			if advance(ctx) then return 0 end
			if list == "output" or list == "dst" then return 0 end
			if list == "fuel" and automatic.fuel_time(ctx.station, stack) <= 0 then return 0 end
			return stack:get_count()
		end,
		allow_move = function(inv, from, fi, to, ti, count, player)
			if not accessible(ctx, player) or not ctx.personal or from == "output" or
					from == "dst" or to == "output" or to == "dst" then return 0 end
			if advance(ctx) then return 0 end
			if to == "fuel" and automatic.fuel_time(ctx.station,
					inv:get_stack(from, fi)) <= 0 then return 0 end
			return count
		end,
		allow_take = function(inv, list, index, stack, player)
			ctx.receipt = nil
			if not accessible(ctx, player) then return 0 end
			if advance(ctx) then return 0 end
			if ctx.automatic or list ~= "output" or ctx.produced then return stack:get_count() end
			if ctx.operation then return 0 end
			local output, recipe = preview(ctx, player)
			local current = inv:get_stack(list, index)
			if not recipe or current:to_string() ~= output:to_string() then refresh(ctx, false) return 0 end
			local consume = {}
			for slot, ingredient in ipairs(inputs(ctx):get_list("craft") or {}) do
				if not ingredient:is_empty() then consume[slot] = 1 end
			end
			ctx.receipt = {recipe = recipe, consume = consume}
			return stack:get_count()
		end,
		on_put = function() changed(ctx) end,
		on_move = function() changed(ctx) end,
		on_take = function(inv, list, index, stack, player)
			if not ctx.automatic and list == "output" and not ctx.produced then
				local receipt = assert(ctx.receipt, "station result without authorized receipt")
				local recipe = receipt.recipe
				ctx.receipt = nil
				local source = inputs(ctx)
				for slot, count in pairs(receipt.consume) do
					local ingredient = source:get_stack("craft", slot)
					ingredient:take_item(count)
					source:set_stack("craft", slot, ingredient)
				end
				grug_jobs.record_craft(player, recipe.profession, recipe.tier)
				ctx.produced = not inv:is_empty("output")
			elseif ctx.produced then ctx.produced = not inv:is_empty("output") end
			changed(ctx)
		end,
	}
end

function workspaces.open(pos, player)
	local station = node_station(pos)
	if not station or not player or not player:is_player() then return end
	local name = player:get_player_name()
	local ctx = {name = name, pos = vector.new(pos), station = station,
		id = stamp(pos), personal = grug_jobs.is_public_station(station, pos),
		automatic = automatic.sizes[station] ~= nil}
	if not accessible(ctx, player) then return end
	detach(viewers[name])
	sequence = sequence + 1
	ctx.detached = "grug_workspace_" .. name .. "_" .. sequence
	ctx.inv = core.create_detached_inventory(ctx.detached, callbacks(ctx), name)
	local data = core.deserialize(core.get_meta(pos):get_string(PREFIX .. name)) or {}
	ctx.process = data.process or {}
	ctx.produced = data.produced == true
	local sizes = ctx.personal and (automatic.sizes[station] or {craft = 9, output = 1}) or {output = 1}
	for list, size in pairs(sizes) do
		ctx.inv:set_size(list, size)
		if data.lists and data.lists[list] then ctx.inv:set_list(list, data.lists[list]) end
	end
	viewers[name] = ctx
	advance(ctx)
	refresh(ctx, true)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return false end
	local ctx = viewers[player:get_player_name()]
	if not ctx then return true end
	if fields.quit then detach(ctx) return true end
	if not accessible(ctx, player) then return true end
	if fields.grug_jobs_book then grug_jobs.open_book(player, "station", ctx.station) return true end
	if fields.operation and not ctx.produced then
		local index = tonumber(fields.operation)
		if index and ctx.choices and ctx.choices[index] ~= nil then ctx.operation = ctx.choices[index] or nil end
	end
	if fields.apply and not ctx.produced then
		local recipe = selected(ctx)
		local plan, reason
		if recipe then plan, reason = grug_items.operation_plan(recipe, inputs(ctx):get_list("craft"), player) end
		if plan and player:get_inventory():room_for_item("main", plan.output) then
			local source = inputs(ctx)
			for slot, count in pairs(plan.consume) do
				local stack = source:get_stack("craft", slot)
				stack:take_item(count)
				source:set_stack("craft", slot, stack)
			end
			local rest = player:get_inventory():add_item("main", plan.output)
			assert(rest:is_empty(), "station operation destination changed during commit")
			grug_jobs.record_craft(player, recipe.profession, recipe.tier)
			changed(ctx)
		else core.chat_send_player(ctx.name, reason or "Make room in your inventory.") end
	end
	refresh(ctx, true)
	return true
end)

core.register_on_leaveplayer(function(player) detach(viewers[player:get_player_name()]) end)
local accumulator = 0
core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < 1 then return end
	accumulator = 0
	for _, ctx in pairs(viewers) do
		if accessible(ctx, core.get_player_by_name(ctx.name)) then
			advance(ctx)
			refresh(ctx, ctx.station == "furnace" or ctx.station == "dual_furnace")
		end
	end
end)

local function has_saved_items(pos)
	for key, value in pairs(core.get_meta(pos):to_table().fields or {}) do
		if key:sub(1, #PREFIX) == PREFIX then
			local data = core.deserialize(value)
			for _, list in pairs(data and data.lists or {}) do
				for _, item in ipairs(list) do if not ItemStack(item):is_empty() then return true end end
			end
		end
	end
	return false
end

local function initialize(pos, station)
	stamp(pos)
	local inv = core.get_meta(pos):get_inventory()
	for list, size in pairs(automatic.sizes[station] or {craft = 9}) do
		if inv:get_size(list) ~= size then inv:set_size(list, size) end
	end
end

local function install_node(name, station)
	local def = core.registered_nodes[name]
	if not def then return end
	local function allowed(pos, player)
		if grug_jobs.is_public_station(station, pos) then return false end
		return player and player:is_player() and player:get_hp() > 0 and
			player:get_pos() and vector.distance(player:get_pos(), pos) <= 8 and
			not core.is_protected(pos, player:get_player_name()) and node_station(pos) == station
	end
	local function update(pos)
		if automatic.sizes[station] then
			local meta = core.get_meta(pos)
			if station == "furnace" or station == "dual_furnace" then
				local state = core.deserialize(meta:get_string("grug_jobs:process")) or {}
				automatic.advance(station, meta:get_inventory(), state, 0)
				meta:set_string("grug_jobs:process", core.serialize(state))
				local node = core.get_node(pos)
				local inactive = grug_jobs.station_info(station).node
				local wanted = (state.fuel or 0) > 0 and inactive .. "_active" or inactive
				if node.name ~= wanted then node.name = wanted core.swap_node(pos, node) end
			end
			local timer = core.get_node_timer(pos)
			if not timer:is_started() then timer:start(1) end
		end
		refresh_position(pos)
	end
	local function allow_put(pos, list, index, stack, player)
		if not allowed(pos, player) or list == "output" or list == "dst" then return 0 end
		if not (automatic.sizes[station] or {craft = 9})[list] then return 0 end
		if list == "fuel" and automatic.fuel_time(station, stack) <= 0 then return 0 end
		return stack:get_count()
	end
	core.override_item(name, {
		_grug_station = station,
		on_construct = function(pos) initialize(pos, station) end,
		on_rightclick = function(pos, node, player, stack)
			initialize(pos, station) workspaces.open(pos, player) return stack
		end,
		can_dig = function(pos, player)
			if not allowed(pos, player) or has_saved_items(pos) then return false end
			local inv = core.get_meta(pos):get_inventory()
			for list in pairs(automatic.sizes[station] or {craft = 9}) do
				if not inv:is_empty(list) then return false end
			end
			return true
		end,
		on_blast = function(pos)
			if grug_jobs.is_public_station(station, pos) then return {} end
			local drops = {def.drop or name}
			for list in pairs(automatic.sizes[station] or {craft = 9}) do default.get_inventory_drops(pos, list, drops) end
			for key, value in pairs(core.get_meta(pos):to_table().fields or {}) do
				if key:sub(1, #PREFIX) == PREFIX then
					local data = core.deserialize(value)
					for _, list in pairs(data and data.lists or {}) do
						for _, item in ipairs(list) do if not ItemStack(item):is_empty() then drops[#drops + 1] = item end end
					end
				end
			end
			core.remove_node(pos)
			return drops
		end,
		allow_metadata_inventory_put = allow_put,
		allow_metadata_inventory_take = function(pos, list, index, stack, player)
			if not allowed(pos, player) or not (automatic.sizes[station] or {craft = 9})[list] then return 0 end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, from, fi, to, ti, count, player)
			local stack = core.get_meta(pos):get_inventory():get_stack(from, fi)
			return math.min(count, allow_put(pos, to, ti, stack, player))
		end,
		on_metadata_inventory_put = update, on_metadata_inventory_take = update,
		on_metadata_inventory_move = update,
		on_timer = function(pos, elapsed)
			if not automatic.sizes[station] or grug_jobs.is_public_station(station, pos) then return false end
			initialize(pos, station)
			local meta = core.get_meta(pos)
			local state = core.deserialize(meta:get_string("grug_jobs:process")) or {}
			automatic.advance(station, meta:get_inventory(), state, elapsed)
			meta:set_string("grug_jobs:process", core.serialize(state))
			local running = automatic.running(station, meta:get_inventory(), state)
			local node = core.get_node(pos)
			local inactive = grug_jobs.station_info(station).node
			local wanted = (state.fuel or 0) > 0 and inactive .. "_active" or inactive
			if node.name ~= wanted then node.name = wanted core.swap_node(pos, node) end
			return running
		end,
		on_receive_fields = function() end,
	})
end

core.register_on_mods_loaded(function()
	local names = {}
	for name, def in pairs(core.registered_nodes) do
		local station = def._grug_station
		if name == "default:furnace" or name == "default:furnace_active" then station = "furnace" end
		if name == "grug_smelting:dual_furnace" or name == "grug_smelting:dual_furnace_active" then station = "dual_furnace" end
		if name == "grug_brewing:brewing_stand" or name == "grug_brewing:brewing_stand_active" then station = "brewing_stand" end
		if station then names[#names + 1] = name install_node(name, station) end
	end
	core.register_lbm({name = ":grug_jobs:workspace_activation", label = "Activate station workspaces",
		nodenames = names, run_at_every_load = true,
		action = function(pos) initialize(pos, node_station(pos)) end})
end)

return workspaces
