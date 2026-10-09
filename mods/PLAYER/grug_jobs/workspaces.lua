-- Detached inventories are views; node metadata owns every durable workspace.
-- Since Round 45 only furnaces and dual furnaces keep a dialog with lists.
-- The forge, the four benches and the brewing stand are proximity stations
-- (spec ruling 27, lane ST): no dialog, no lists; a profession job only
-- checks that one stands nearby (jobs.lua). Their old node-meta contents stay
-- where they are and still come out when a player-placed station is dug
-- (round45-plan.md ruling 3).
local workspaces = {}
local automatic = dofile(core.get_modpath("grug_jobs") .. "/automatic.lua")
local viewers = {}
local sequence = 0
local FORM = "grug_jobs:workspace"
local PREFIX = "grug_jobs:workspace:"
local PERSONAL_BURN_UNTIL = "grug_jobs:personal_burn_until"
local refresh

-- The stations whose dialog still holds lists.
local DIALOG_STATIONS = {furnace = true, dual_furnace = true}

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
	-- Using a station is an interaction, not an edit: a claim's "interact"
	-- permission is enough (Round 25 ruling 18).
	return ctx.personal or not grug_core.interaction_protected(ctx.pos, ctx.name)
end

local function inputs(ctx)
	return ctx.personal and ctx.inv or core.get_meta(ctx.pos):get_inventory()
end

-- Private jobs keep their inventories private, but a burning furnace is a
-- shared world visual. Record only the latest cosmetic expiry at the node;
-- the node timer never scans or advances a player's saved workspace.
local function extend_personal_light(ctx)
	if not ctx.personal or (ctx.station ~= "furnace" and
			ctx.station ~= "dual_furnace") or (ctx.process.fuel or 0) <= 0 then return end
	local meta = core.get_meta(ctx.pos)
	local deadline = automatic.personal_light_deadline(core.get_gametime(),
		meta:get_int(PERSONAL_BURN_UNTIL), ctx.process.fuel)
	if deadline > meta:get_int(PERSONAL_BURN_UNTIL) then
		meta:set_int(PERSONAL_BURN_UNTIL, deadline)
	end
	local node = core.get_node(ctx.pos)
	local active = grug_jobs.station_info(ctx.station).node .. "_active"
	if node.name ~= active then node.name = active core.swap_node(ctx.pos, node) end
	local timer = core.get_node_timer(ctx.pos)
	if not timer:is_started() then timer:start(1) end
end

local function save(ctx)
	local station = node_station(ctx.pos)
	if station ~= ctx.station or core.get_meta(ctx.pos):get_string("grug_jobs:station_id") ~= ctx.id then
		return
	end
	local record = {lists = {}, process = ctx.process}
	if ctx.personal then
		for list, stacks in pairs(ctx.inv:get_lists()) do
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
	for _, list in ipairs({"src", "input", "fuel", "dst", "output"}) do
		for _, stack in ipairs(ctx.inv:get_list(list) or {}) do
			result[#result + 1] = stack:to_string()
		end
	end
	return core.serialize(result)
end

-- Returns whether settlement changed an inventory slot. An allow callback
-- refuses that stale transfer; the next request sees the settled inventory.
local function advance(ctx)
	if not ctx.personal then return false end
	local now = core.get_gametime()
	local elapsed = math.max(0, now - (ctx.process.last or now))
	ctx.process.last = now
	if elapsed == 0 then return false end
	local before = inventory_signature(ctx)
	local fuel, progress, recipe = ctx.process.fuel, ctx.process.progress, ctx.process.recipe
	automatic.advance(ctx.station, ctx.inv, ctx.process, elapsed)
	extend_personal_light(ctx)
	local changed_inventory = before ~= inventory_signature(ctx)
	-- Updating only the idle clock must not dirty the physical node every tick.
	if changed_inventory or fuel ~= ctx.process.fuel or progress ~= ctx.process.progress or
			recipe ~= ctx.process.recipe then save(ctx) end
	return changed_inventory
end

-- The repair button a station inside an active Claim Stone claim adds
-- (grug_repair), or "".
local function repair_button(name, pos, x, y)
	local repair = rawget(_G, "grug_repair")
	if repair and repair.can_open_station(core.get_player_by_name(name), pos) then
		return ("button[%g,%g;2.4,0.8;grug_jobs_repair;Repair equipment]"):format(x, y)
	end
	return ""
end

-- Shift-click: each station list rings to the shift-click inbox
-- (grug_inventory/inbox.lua: into main[9..] and the bags), `main` to the
-- first station list. The list name is spelled out: fixtures stub
-- grug_inventory.
local function ring(location, list)
	return "listring[" .. location .. ";" .. list ..
		"]listring[current_player;grug_inbox]listring[current_player;main]"
end

local function formspec(ctx)
	local location = ctx.personal and "detached:" .. ctx.detached or
		"nodemeta:" .. ctx.pos.x .. "," .. ctx.pos.y .. "," .. ctx.pos.z
	local title = grug_jobs.station_info(ctx.station).display_name
	local mode = ctx.personal and "Personal workspace" or "Shared station"
	local explanation = ctx.personal and "Your work is saved here, separately for each station." or
		"Inputs and finished work are shared with players who can access this area."
	local source = ctx.station == "furnace" and "src" or "input"
	local output = ctx.station == "furnace" and "dst" or "output"
	local width = ctx.station == "dual_furnace" and 2 or 1
	local process = ctx.process
	if not ctx.personal then
		process = core.deserialize(core.get_meta(ctx.pos):get_string(
			"grug_jobs:process")) or {}
	end
	local fuel_fraction, progress_fraction = automatic.fractions(ctx.station,
		inputs(ctx), process)
	local fuel_percent = math.floor(fuel_fraction * 100 + 0.5)
	local progress_percent = math.floor(progress_fraction * 100 + 0.5)
	return "formspec_version[4]size[12,11]label[0.5,0.4;" .. core.formspec_escape(title) ..
		"]label[0.5,0.85;" .. mode .. "]label[0.5,1.25;" .. core.formspec_escape(explanation) .. "]" ..
		"label[1,1.9;Input]list[" .. location .. ";" .. source .. ";1,2.3;" .. width .. ",1;]" ..
		"label[3.5,1.9;Fuel]list[" .. location .. ";fuel;3.5,2.3;1,1;]" ..
		"label[6,1.9;Finished output]list[" .. location .. ";" .. output .. ";6,2.3;2," ..
		(ctx.station == "furnace" and 2 or 1) .. ";]" .. ring(location, output) ..
		ring(location, source) .. ring(location, "fuel") ..
		"image[4.55,2.4;0.6,0.6;default_furnace_fire_bg.png]" ..
		(fuel_percent > 0 and "image[4.55,2.4;0.6,0.6;default_furnace_fire_bg.png^[lowpart:" ..
			fuel_percent .. ":default_furnace_fire_fg.png]" or "") ..
		"image[5.25,2.4;0.6,0.6;gui_furnace_arrow_bg.png^[transformR270]" ..
		(progress_percent > 0 and "image[5.25,2.4;0.6,0.6;gui_furnace_arrow_bg.png^[lowpart:" ..
			progress_percent .. ":gui_furnace_arrow_fg.png^[transformR270]" or "") ..
		repair_button(ctx.name, ctx.pos, 9.3, 4.95) ..
		"list[current_player;main;1,6;8,1;]list[current_player;main;1,7.25;8,3;8]" ..
		default.get_hotbar_bg(1, 6)
end

-- Whether the station's own form is the one open (default/node_formspec.lua
-- records the last form shown): a re-show never pops it back over another
-- form (Round 37, PLY-03).
local function form_open(ctx)
	return default.node_formspec.shown_form(ctx.name) == FORM
end

refresh = function(ctx, show)
	if not accessible(ctx, core.get_player_by_name(ctx.name)) then return end
	if show and form_open(ctx) then core.show_formspec(ctx.name, FORM, formspec(ctx)) end
end

local function refresh_position(pos)
	for _, ctx in pairs(viewers) do
		if vector.equals(ctx.pos, pos) then refresh(ctx, false) end
	end
end

local function changed(ctx)
	if ctx.personal then
		automatic.advance(ctx.station, ctx.inv, ctx.process, 0)
		extend_personal_light(ctx)
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
			if not accessible(ctx, player) then return 0 end
			if advance(ctx) then return 0 end
			return stack:get_count()
		end,
		on_put = function() changed(ctx) end,
		on_move = function() changed(ctx) end,
		on_take = function(inv, list, index, stack, player)
			if list == "dst" or list == "output" then
				grug_sounds.play(grug_jobs.furnace_take_sound(stack), player)
			end
			changed(ctx)
		end,
	}
end

-- Opens the furnace or dual-furnace form at `pos`; true when it is shown. `id` (optional)
-- is the station id a return from the repair form expects (Round 41 ruling
-- 3): a station dug and replaced at the same place is another station, and
-- the caller falls back to the inventory.
function workspaces.open(pos, player, id)
	local station = node_station(pos)
	if not DIALOG_STATIONS[station] or not player or not player:is_player() then return false end
	if id and core.get_meta(pos):get_string("grug_jobs:station_id") ~= id then return false end
	local name = player:get_player_name()
	local ctx = {name = name, pos = vector.new(pos), station = station,
		id = stamp(pos), personal = grug_jobs.is_public_station(station, pos)}
	if not accessible(ctx, player) then return false end
	detach(viewers[name])
	sequence = sequence + 1
	ctx.detached = "grug_workspace_" .. name .. "_" .. sequence
	ctx.inv = core.create_detached_inventory(ctx.detached, callbacks(ctx), name)
	local data = core.deserialize(core.get_meta(pos):get_string(PREFIX .. name)) or {}
	ctx.process = data.process or {}
	local sizes = ctx.personal and automatic.sizes[station] or {}
	for list, size in pairs(sizes) do
		ctx.inv:set_size(list, size)
		if data.lists and data.lists[list] then ctx.inv:set_list(list, data.lists[list]) end
	end
	viewers[name] = ctx
	advance(ctx)
	core.show_formspec(name, FORM, formspec(ctx))
	return true
end

-- Close of a station's repair form (Round 41 ruling 3): back to the station
-- form at `origin` ({pos, id}) when it can be reopened there, else the
-- inventory.
local function close_to_origin(player, origin)
	if origin and workspaces.open(origin.pos, player, origin.id) then return true end
	core.show_formspec(player:get_player_name(), "", player:get_inventory_formspec())
	return false
end

-- The repair form replaces the station form and the session ends; its Close
-- returns here, Esc closes everything.
local function open_repair(player, ctx)
	local repair = rawget(_G, "grug_repair")
	if not repair then return end
	local origin = {pos = vector.new(ctx.pos), id = ctx.id}
	repair.open_station(player, origin.pos, function(closer)
		close_to_origin(closer, origin)
	end)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return false end
	local ctx = viewers[player:get_player_name()]
	if not ctx then return true end
	if fields.quit then detach(ctx) return true end
	if not accessible(ctx, player) then return true end
	if fields.grug_jobs_repair then
		detach(ctx)
		open_repair(player, ctx)
		return true
	end
	refresh(ctx, true)
	return true
end)

core.register_on_leaveplayer(function(player)
	detach(viewers[player:get_player_name()])
end)
local accumulator = 0
core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < 1 then return end
	accumulator = 0
	for _, ctx in pairs(viewers) do
		-- Another form replaced the station's (no "quit" reaches us then):
		-- the session is over.
		if not form_open(ctx) then
			detach(ctx)
		elseif accessible(ctx, core.get_player_by_name(ctx.name)) then
			advance(ctx)
			refresh(ctx, true)
		end
	end
end)

-- The node lists a station keeps: a furnace's and a dual furnace's automatic
-- lists; a proximity station keeps none.
local function station_lists(station)
	return automatic.sizes[station] or {}
end

-- Everything a station holds: every list its node meta has and every
-- player's saved workspace record. Digging and blasts both release all of
-- it, so other players' invisible leftovers never block a dig (Round 28
-- ruling 18). A proximity station built before Round 45 still holds its old
-- lists (the crafting grid; a brewing stand's mixture, fuel and output),
-- which come out here too (round45-plan.md ruling 3).
local function station_contents(pos, drops)
	for list in pairs(core.get_meta(pos):get_inventory():get_lists()) do
		default.get_inventory_drops(pos, list, drops)
	end
	for key, value in pairs(core.get_meta(pos):to_table().fields or {}) do
		if key:sub(1, #PREFIX) == PREFIX then
			local data = core.deserialize(value)
			for _, list in pairs(data and data.lists or {}) do
				for _, item in ipairs(list) do
					if not ItemStack(item):is_empty() then drops[#drops + 1] = item end
				end
			end
		end
	end
	return drops
end

local function initialize(pos, station)
	stamp(pos)
	local inv = core.get_meta(pos):get_inventory()
	for list, size in pairs(station_lists(station)) do
		if inv:get_size(list) ~= size then inv:set_size(list, size) end
	end
end

local function install_node(name, station)
	local def = core.registered_nodes[name]
	if not def then return end
	-- Inventory use is an interaction (a claim's "interact" permission is
	-- enough, Round 25 ruling 18); digging (`edit`) keeps core.is_protected.
	local dialog = DIALOG_STATIONS[station]
	local function allowed(pos, player, edit)
		if grug_jobs.is_public_station(station, pos) then return false end
		if not (player and player:is_player() and player:get_hp() > 0 and
				player:get_pos() and vector.distance(player:get_pos(), pos) <= 8 and
				node_station(pos) == station) then
			return false
		end
		local name = player:get_player_name()
		if edit then return not core.is_protected(pos, name) end
		return not grug_core.interaction_protected(pos, name)
	end
	local function update(pos)
		local meta = core.get_meta(pos)
		local state = core.deserialize(meta:get_string("grug_jobs:process")) or {}
		automatic.advance(station, meta:get_inventory(), state, 0)
		meta:set_string("grug_jobs:process", core.serialize(state))
		local node = core.get_node(pos)
		local inactive = grug_jobs.station_info(station).node
		local wanted = (state.fuel or 0) > 0 and inactive .. "_active" or inactive
		if node.name ~= wanted then node.name = wanted core.swap_node(pos, node) end
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then timer:start(1) end
		refresh_position(pos)
	end
	-- Only a dialog station shows its node lists; the others take nothing
	-- (nor give: their old lists come out only when they are dug).
	local function allow_put(pos, list, index, stack, player)
		if not dialog or not allowed(pos, player) or
				list == "output" or list == "dst" then return 0 end
		if not station_lists(station)[list] then return 0 end
		if list == "fuel" and automatic.fuel_time(station, stack) <= 0 then return 0 end
		return stack:get_count()
	end
	local override = {
		_grug_station = station,
		-- Anyone the normal protection allows may dig a player-placed station
		-- at any time, full or not; authored public stations stay undiggable.
		can_dig = function(pos, player) return allowed(pos, player, true) end,
		-- node_dig calls this after can_dig and the protection check, with the
		-- node still in place and before handle_node_drops: the contents join
		-- the dug station's own drops (digger's inventory, overflow on the
		-- ground).
		preserve_metadata = function(pos, _, _, drops)
			station_contents(pos, drops)
		end,
		on_blast = function(pos)
			if grug_jobs.is_public_station(station, pos) then return {} end
			local drops = station_contents(pos, {def.drop or name})
			core.remove_node(pos)
			return drops
		end,
		allow_metadata_inventory_put = allow_put,
		allow_metadata_inventory_take = function(pos, list, index, stack, player)
			if not dialog or not allowed(pos, player) or
					not station_lists(station)[list] then return 0 end
			return stack:get_count()
		end,
		allow_metadata_inventory_move = function(pos, from, fi, to, ti, count, player)
			local stack = core.get_meta(pos):get_inventory():get_stack(from, fi)
			return math.min(count, allow_put(pos, to, ti, stack, player))
		end,
		on_receive_fields = function() end,
	}
	if not dialog then
		-- A proximity station has no dialog (no on_rightclick) and no lists. A
		-- brewing stand the automatic brewing lit before Round 45 still runs its
		-- node timer once after loading: it goes out, and the timer stops.
		override.on_timer = function(pos)
			local node = core.get_node(pos)
			local inactive = grug_jobs.station_info(station).node
			if node.name ~= inactive then node.name = inactive core.swap_node(pos, node) end
			return false
		end
		core.override_item(name, override)
		return
	end
	override.on_construct = function(pos) initialize(pos, station) end
	override.on_rightclick = function(pos, node, player, stack)
		initialize(pos, station) workspaces.open(pos, player) return stack
	end
	override.on_metadata_inventory_put = update
	override.on_metadata_inventory_take = update
	override.on_metadata_inventory_move = update
	override.on_timer = function(pos, elapsed)
		initialize(pos, station)
		local meta = core.get_meta(pos)
		local state = core.deserialize(meta:get_string("grug_jobs:process")) or {}
		local public = grug_jobs.is_public_station(station, pos)
		if not public then
			automatic.advance(station, meta:get_inventory(), state, elapsed)
			meta:set_string("grug_jobs:process", core.serialize(state))
		end
		local running = not public and
			automatic.running(station, meta:get_inventory(), state) or false
		local personal_lit = automatic.personal_light_active(core.get_gametime(),
			meta:get_int(PERSONAL_BURN_UNTIL))
		if not personal_lit and meta:get_int(PERSONAL_BURN_UNTIL) ~= 0 then
			meta:set_int(PERSONAL_BURN_UNTIL, 0)
		end
		local node = core.get_node(pos)
		local inactive = grug_jobs.station_info(station).node
		local wanted = ((state.fuel or 0) > 0 or personal_lit) and
			inactive .. "_active" or inactive
		if node.name ~= wanted then node.name = wanted core.swap_node(pos, node) end
		return running or personal_lit
	end
	core.override_item(name, override)
end

core.register_on_mods_loaded(function()
	local names = {}
	for name, def in pairs(core.registered_nodes) do
		local station = def._grug_station
		if name == "default:furnace" or name == "default:furnace_active" then station = "furnace" end
		if name == "grug_smelting:dual_furnace" or name == "grug_smelting:dual_furnace_active" then station = "dual_furnace" end
		if name == "grug_brewing:brewing_stand" or name == "grug_brewing:brewing_stand_active" then station = "brewing_stand" end
		if station then
			install_node(name, station)
			if DIALOG_STATIONS[station] then names[#names + 1] = name end
		end
	end
	core.register_lbm({name = ":grug_jobs:workspace_activation", label = "Activate station workspaces",
		nodenames = names, run_at_every_load = true,
		action = function(pos)
			local station = node_station(pos)
			initialize(pos, station)
			local meta = core.get_meta(pos)
			local personal_lit = automatic.personal_light_active(core.get_gametime(),
				meta:get_int(PERSONAL_BURN_UNTIL))
			if not personal_lit then meta:set_int(PERSONAL_BURN_UNTIL, 0) end
			local state = core.deserialize(meta:get_string("grug_jobs:process")) or {}
			local shared_lit = (state.fuel or 0) > 0
			local node = core.get_node(pos)
			local inactive = grug_jobs.station_info(station).node
			local wanted = (shared_lit or personal_lit) and inactive .. "_active" or inactive
			if node.name ~= wanted then node.name = wanted core.swap_node(pos, node) end
			if shared_lit or personal_lit then core.get_node_timer(pos):start(1) end
		end})
end)

return workspaces
