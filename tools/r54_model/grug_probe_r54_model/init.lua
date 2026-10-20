-- Disposable engine probe (Round 54 lane MODEL): character models in a
-- studio, for screenshots. Never shipped: tools/r54_model/capture.sh stages
-- a copy through tools/luanti_headless.sh (with the stand-in textures it
-- generates and the scene it is given) and connects one real client. The
-- driver (character creation, the SHOT / ack handshake) is
-- tools/r531_race's.
--
-- After the character is made the probe builds, 40 nodes above the player, a
-- grass floor, and plays the scene (scene.lua next to this file, or the one
-- capture.sh copies over it): for each shot it places the shot's FIGURES --
-- mesh entities frozen on one animation frame, facing one yaw -- moves the
-- player (the camera) to the shot's spot and logs "SHOT <name>" plus one
-- "figure" line per figure (mesh and textures as the engine got them).
--
-- A scene file returns {setup = function(player) end (optional), shots =
-- {...}}; a shot is {name, cam = {x, y, z}, yaw, pitch, figures = {...}},
-- positions relative to the studio origin S (the floor's top is y 0.5); a
-- figure is {at = {x, y, z}, yaw, frame (engine frame, frozen), mesh,
-- textures, size (visual size, default 1), wield (an item the game's wield
-- entity holds in the tool pose at the figure's size), mirror (true: take
-- mesh, textures and visual size from the capture player itself, i.e. what
-- the game's own composition put on it)}. Lane GAME reuses it with its own
-- scene: equip items on the player in `setup` and show `mirror` figures.
local P = "[r54model] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r54model_settle") or "") or 6
local function log(msg) core.log("action", P .. msg) end

local scene = dofile(core.get_modpath(core.get_current_modname()) .. "/scene.lua")
local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r54model_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

core.register_entity("grug_probe_r54_model:figure", {
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"character.png"},
		physical = false,
		pointable = false,
		collide_with_objects = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
	},
})

-- The studio: a grass floor x -8..8, z -4..12 at y 0 relative to S.
local S
local function build_studio()
	local minp, maxp = vector.offset(S, -10, -2, -6), vector.offset(S, 10, 8, 14)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local cid = core.get_content_id
	local air, grass, dirt = cid("air"), cid("default:dirt_with_grass"), cid("default:dirt")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local rx, ry, rz = x - S.x, y - S.y, z - S.z
				local id = air
				if rx >= -8 and rx <= 8 and rz >= -4 and rz <= 12 and ry <= 0 and ry >= -1 then
					id = ry == 0 and grass or dirt
				end
				data[area:index(x, y, z)] = id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

local live = {}
local function clear()
	for _, obj in ipairs(live) do
		if obj:get_pos() then obj:remove() end
	end
	live = {}
end

local function vec(t) return vector.offset(S, t[1], t[2], t[3]) end

local function place(player, shot)
	clear()
	for i, fig in ipairs(shot.figures) do
		local obj = core.add_entity(vec(fig.at), "grug_probe_r54_model:figure")
		if obj then
			local props = {visual_size = {x = fig.size or 1, y = fig.size or 1, z = fig.size or 1}}
			if fig.mirror then
				local own = player:get_properties()
				props.mesh, props.textures, props.visual_size = own.mesh, own.textures, own.visual_size
			else
				props.mesh, props.textures = fig.mesh, fig.textures
			end
			obj:set_properties(props)
			obj:set_yaw(fig.yaw or 0)
			obj:set_animation({x = fig.frame or 0, y = fig.frame or 0}, 0, 0, false)
			live[#live + 1] = obj
			if fig.wield then
				local wield = core.add_entity(vec(fig.at), "grug_visuals:wield")
				if wield then
					local t = grug_visuals.wield_transform(props.visual_size.x, "tool")
					wield:set_properties({textures = {fig.wield}, wield_item = fig.wield, visual_size = t.size})
					wield:set_attach(obj, t.bone, t.pos, t.rot)
					live[#live + 1] = wield
				end
			end
			local got = obj:get_properties()
			log(("figure %d of %s: mesh %s, %d textures {%s}, frame %d, yaw %.2f%s"):format(i, shot.name,
				got.mesh, #got.textures, table.concat(got.textures, ", "), fig.frame or 0, fig.yaw or 0,
				fig.wield and (", wield " .. fig.wield) or ""))
		end
	end
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.2 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
			wielditem = false, breathbar = false, minimap = false, minimap_radar = false})
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		local own = player:get_properties()
		log(("player: mesh %s, %d textures {%s}"):format(own.mesh, #own.textures,
			table.concat(own.textures, ", ")))
		S = vector.offset(at, 0, 40, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(S, -16, -16, -16), vector.offset(S, 16, 16, 24),
			function(_, _, remaining)
				if remaining > 0 then return end
				core.after(0, function()
					build_studio()
					if scene.setup then scene.setup(player) end
					log("studio at " .. core.pos_to_string(S))
					state.phase, state.shot, state.waited, state.logged = "shoot", 1, 0, false
					log("READY")
				end)
			end)
	elseif state.phase == "shoot" then
		core.set_timeofday(0.5)
		local shot = scene.shots[state.shot]
		if not shot then
			state.phase = "done"
			clear()
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then
			place(player, shot)
		end
		player:set_pos(vec(shot.cam))
		player:set_look_horizontal(shot.yaw or 0)
		player:set_look_vertical(shot.pitch or 0)
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log(("SHOT %s"):format(shot.name))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
