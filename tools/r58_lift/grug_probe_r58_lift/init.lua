-- Disposable engine probe (Round 58 lane LIFT): the Miner's Guild lift in
-- the real game. Never shipped: tools/r58_lift/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r58_rooms's shot
-- probe.
--
-- The capture character (The Accord) rides the real lift of its faction's
-- first T4 mining camp (setting r58lift_camp names another): the
-- right-click through the node's own on_rightclick, the Travel buttons
-- through the registered field handlers, so the trip is the game's
-- (grug_home.travel, emerge, safe arrival). It rides from the surface down
-- to every level and back, logging a RIDE line per trip (the arrival, the
-- node under the feet, the time), then shoots:
--   L1_lift_surface    the surface lift (the picked art) from its front
--   L2_level_list      the lift's list at the surface
--   L3_lift_room       the lift in the T4 room
--   L4_enemy_refusal   the same character as The Throng right-clicking it
--   M1_map_mining_camp the map window's POIs at the camp, zoomed in
--   M2_map_camp_construction  the PvP layer at a camp under construction
--   R1_character_reputation   the Character page with the reputation icon
-- Only the camp's surface, its rooms and the camp site are emerged.

local P = "[r58lift] "
local NAME = "grugcap"
local LIFT = "grug_mapgen:guild_lift"
local SETTLE = tonumber(core.settings:get("r58lift_settle") or "") or 3
local CAMP_ID = core.settings:get("r58lift_camp")
-- Only the shots whose names start with this (no rides then).
local ONLY = core.settings:get("r58lift_only")

local function log(msg) core.log("action", P .. msg) end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r58lift_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The lift's forms as the client gets them (the probe needs the form name
-- to press a button the way the client would).
local last_form, forms_shown = nil, 0
local real_show = core.show_formspec
core.show_formspec = function(name, formname, fs)
	if name == NAME and formname:sub(1, 16) == "grug_guild:lift:" then
		last_form, forms_shown = formname, forms_shown + 1
	end
	return real_show(name, formname, fs)
end

local function look_at(player, eye, target)
	player:set_pos(eye)
	local dx, dy, dz = target.x - eye.x, target.y - (eye.y + 1.5), target.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

local camp, rooms, surface
local function front_of(pos)
	local node = core.get_node(pos)
	local back = core.fourdir_to_dir(node.param2 % 4)
	return {x = -back.x, z = -back.z}, node
end
local function lift_pos(level)
	if level == 0 then return surface end
	return rooms[level].lift_cell
end
local function expected_arrival(level)
	if level > 0 then return rooms[level].arrival end
	local f = front_of(surface)
	return {x = surface.x + f.x, y = surface.y - 0.49, z = surface.z + f.z}
end
local function click(player, pos)
	local def = core.registered_nodes[LIFT]
	def.on_rightclick(pos, core.get_node(pos), player, player:get_wielded_item(), nil)
end

-- The steps: {kind, ...}; the driver below runs one at a time.
local steps = {}
local function add(step)
	if ONLY and ONLY ~= "" and (step.kind == "ride" or
			(step.kind == "shot" and step.name:sub(1, #ONLY) ~= ONLY)) then
		return
	end
	steps[#steps + 1] = step
end
-- The map shots stand the character this far south of the icon, so its
-- arrow does not cover it.
local MAP_OFFSET = 60

local function plan()
	add({kind = "emerge", pos = surface})
	add({kind = "shot", name = "L1_lift_surface", frame = function(player)
		local f = front_of(surface)
		look_at(player, {x = surface.x + 3 * f.x + f.z, y = surface.y - 0.5, z = surface.z + 3 * f.z + f.x},
			{x = surface.x, y = surface.y, z = surface.z})
	end})
	add({kind = "shot", name = "L2_level_list", frame = function(player)
		local f = front_of(surface)
		look_at(player, {x = surface.x + 2 * f.x, y = surface.y - 0.5, z = surface.z + 2 * f.z},
			{x = surface.x, y = surface.y, z = surface.z})
		click(player, surface)
	end})
	add({kind = "close"})
	local at = 0
	for level = 1, #rooms do
		add({kind = "ride", from = at, to = level})
		add({kind = "ride", from = level, to = 0})
	end
	add({kind = "ride", from = 0, to = #rooms})
	add({kind = "shot", name = "L3_lift_room", frame = function(player)
		local room = rooms[#rooms]
		local c = room.lift_cell
		look_at(player, {x = c.x + 2, y = room.floor_y - 0.5, z = c.z + 3}, {x = c.x, y = room.floor_y, z = c.z})
	end})
	add({kind = "shot", name = "L4_enemy_refusal", frame = function(player)
		local room = rooms[#rooms]
		local c = room.lift_cell
		look_at(player, {x = c.x, y = room.floor_y - 0.5, z = c.z + 2}, {x = c.x, y = room.floor_y, z = c.z})
		local meta = player:get_meta()
		local own = meta:get_string("grug_factions:faction")
		meta:set_string("grug_factions:faction", own == "accord" and "throng" or "accord")
		local before = forms_shown
		click(player, c)
		log(("enemy right-click: %s, list shown %s"):format(grug_factions.get_faction(player),
			tostring(forms_shown ~= before)))
		meta:set_string("grug_factions:faction", own)
	end})
	add({kind = "ride", from = #rooms, to = 0})
	add({kind = "shot", name = "M1_map_mining_camp", frame = function(player)
		player:set_pos({x = camp.anchor.x, y = surface.y + 20, z = camp.anchor.z - MAP_OFFSET})
		grug_map.window.open(player)
		submit(player, grug_map.window.FORMNAME, {grug_map_layer_pois = "POIs"})
		for _ = 1, 3 do submit(player, grug_map.window.FORMNAME, {grug_map_zoom_in = "+"}) end
	end})
	add({kind = "close"})
	local site = grug_mapgen.mining_camps.under_construction[1]
	for _, c in ipairs(grug_mapgen.mining_camps.under_construction) do
		local dx, dz = c.anchor.x - camp.anchor.x, c.anchor.z - camp.anchor.z
		local sx, sz = site.anchor.x - camp.anchor.x, site.anchor.z - camp.anchor.z
		if dx * dx + dz * dz < sx * sx + sz * sz then site = c end
	end
	add({kind = "emerge", pos = {x = site.anchor.x, y = 30, z = site.anchor.z}, label = site.id})
	add({kind = "shot", name = "M2_map_camp_construction", frame = function(player)
		player:set_pos({x = site.anchor.x, y = 80, z = site.anchor.z - MAP_OFFSET})
		grug_map.window.open(player)
		submit(player, grug_map.window.FORMNAME, {grug_map_layer_pvp = "PvP"})
		for _ = 1, 3 do submit(player, grug_map.window.FORMNAME, {grug_map_zoom_in = "+"}) end
		log("camp under construction " .. site.id)
	end})
	add({kind = "close"})
	add({kind = "shot", name = "R1_character_reputation", frame = function(player)
		grug_guild.add(player, 2734, "admin")
		sfinv.set_page(player, "grug_inventory:character")
		real_show(NAME, "grug_probe_r58_lift:character",
			sfinv.get_formspec(player, sfinv.get_or_create_context(player)))
		local view = grug_guild.summary(player)
		log(("reputation: rank %d balance %d"):format(view.rank, view.balance))
	end})
end

local state = {phase = "wait", clock = 0, index = 1}
local function next_step() state.index, state.ran = state.index + 1, false end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step_time = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:hud_set_flags({minimap = false, crosshair = false, wielditem = false})
		local faction = grug_factions.get_faction(player)
		for _, c in ipairs(grug_mapgen.mining_camps.camps) do
			if (CAMP_ID and c.id == CAMP_ID) or
					(not CAMP_ID and not camp and c.kind == "mining_camp" and c.tier == 4 and
						c.faction == faction) then
				camp = c
			end
		end
		rooms = grug_mapgen.guild_rooms.rooms_for_camp(camp.id)
		for _, s in ipairs(grug_core.settlement_sockets_at(camp.id)) do
			if s.id == "lift" then surface = s.pos end
		end
		log(("camp %s (%s, T%d, %d rooms), surface lift %d,%d,%d"):format(camp.id, camp.faction,
			camp.tier, #rooms, surface.x, surface.y, surface.z))
		plan()
		state.phase, state.index, state.ran, state.started = "run", 1, false, os.clock()
		return
	end
	if state.phase ~= "run" then return end
	local step = steps[state.index]
	if not step then
		state.phase = "done"
		log("shutdown")
		core.request_shutdown("probe done", false, 0)
		return
	end
	if step.kind == "emerge" then
		if not state.ran then
			state.ran, state.ready = true, false
			core.emerge_area(vector.subtract(step.pos, 24), vector.add(step.pos, 24),
				function(_, _, remaining) if remaining == 0 then state.ready = true end end)
		elseif state.ready then
			log("emerged " .. (step.label or core.pos_to_string(step.pos)))
			next_step()
		end
	elseif step.kind == "close" then
		core.close_formspec(NAME, "")
		if last_form then core.close_formspec(NAME, last_form) end
		core.close_formspec(NAME, grug_map.window.FORMNAME)
		core.close_formspec(NAME, "grug_probe_r58_lift:character")
		next_step()
	elseif step.kind == "ride" then
		if not state.ran then
			state.ran, state.waited, state.t0 = true, 0, core.get_us_time()
			local from = lift_pos(step.from)
			if step.from > 0 then
				player:set_pos(rooms[step.from].arrival)
			else
				player:set_pos(expected_arrival(0))
			end
			local before = forms_shown
			click(player, from)
			if forms_shown == before then
				log(("RIDE %d -> %d FAIL: no list"):format(step.from, step.to))
				return next_step()
			end
			submit(player, last_form, {["go_" .. step.to] = "Travel"})
			return
		end
		state.waited = state.waited + step_time
		local want = expected_arrival(step.to)
		local pos = player:get_pos()
		local done = not grug_home.is_pending(player) and vector.distance(pos, want) < 0.1
		if done or state.waited > 30 then
			local under = core.get_node({x = pos.x, y = math.floor(pos.y), z = pos.z}).name
			log(("RIDE %d -> %d %s at %s on %s, %.1f s"):format(step.from, step.to,
				done and "OK" or "FAIL", core.pos_to_string(vector.round(pos)), under,
				(core.get_us_time() - state.t0) / 1e6))
			next_step()
		end
	elseif step.kind == "shot" then
		if not state.ran then
			state.ran, state.waited, state.logged = true, 0, false
			step.frame(player)
			return
		end
		state.waited = state.waited + step_time
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. step.name)
		elseif state.logged and read_ack() == step.name then
			next_step()
		end
	end
end)
