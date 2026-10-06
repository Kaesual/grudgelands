-- Round 39 lane WG: a GUI probe for the player model as glTF
-- (round39-web-data-plan.md §4.3, §6). Not part of the game: copy this folder
-- and the .glb into a test world's worldmods (tools/web_data/model/README.md).
--
--   /glb_probe        spawns two models three nodes in front of the caller,
--                     facing them: the glTF model on the left, the game's
--                     .b3d on the right, both with the caller's skin, cloak
--                     and visual size; they switch stand <-> walk together
--                     every SWITCH seconds (the nametag names the clip)
--   /glb_probe clear  removes them (they are never saved either)
--
-- The .glb carries one named clip per animation, timed in seconds, so it plays
-- with play_animation(<clip>) at speed 1 (Luanti 5.17); the .b3d plays
-- player_api's frame range at its animation_speed, as players do.

local MODEL_GLB = "grug_visuals_character.glb"
local MODEL_B3D = "grug_visuals_character.b3d"
-- player_api's registration (mods/BASE/player_api/init.lua); the fixture
-- tools/r39_wg/portable_test.lua compares these with it.
local SPEED = 30
local FRAMES = {stand = {x = 0, y = 79}, walk = {x = 168, y = 187}}
local CYCLE = {"stand", "walk"}
local SWITCH = 4

local spawned = {}

local function play(self)
	local clip = CYCLE[self._clip]
	local obj = self.object
	if self._kind == "glb" then
		if obj.play_animation then
			obj:stop_animation()
			obj:play_animation(clip, {speed = 1, loop = true})
		else
			-- An engine without named tracks plays the first clip (stand).
			clip = "stand only, no play_animation"
			obj:set_animation({x = 0, y = (FRAMES.stand.y - FRAMES.stand.x) / SPEED}, 1, 0, true)
		end
	else
		obj:set_animation(FRAMES[clip], SPEED, 0, true)
	end
	obj:set_properties({nametag = self._kind .. ": " .. clip})
end

core.register_entity("grug_glb_probe:model", {
	initial_properties = {
		visual = "mesh",
		mesh = MODEL_GLB,
		textures = {"blank.png", "blank.png"},
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		physical = false,
		static_save = false,
	},
	on_step = function(self, dtime)
		if not self._kind then
			return
		end
		self._timer = self._timer + dtime
		if self._timer >= SWITCH then
			self._timer = self._timer - SWITCH
			self._clip = self._clip % #CYCLE + 1
			play(self)
		end
	end,
})

local function spawn(kind, pos, yaw, props)
	local obj = core.add_entity(pos, "grug_glb_probe:model")
	local self = obj and obj:get_luaentity()
	if not self then
		return false
	end
	obj:set_properties({
		mesh = kind == "glb" and MODEL_GLB or MODEL_B3D,
		textures = props.textures,
		visual_size = props.visual_size,
	})
	obj:set_yaw(yaw)
	self._kind, self._clip, self._timer = kind, 1, 0
	play(self)
	spawned[#spawned + 1] = obj
	return true
end

core.register_chatcommand("glb_probe", {
	params = "[clear]",
	description = "Show the glTF player model next to the .b3d (Round 39 probe)",
	privs = {server = true},
	func = function(name, param)
		for _, obj in ipairs(spawned) do
			if obj:get_pos() then
				obj:remove()
			end
		end
		spawned = {}
		if param == "clear" then
			return true, "glb_probe: removed"
		end
		local player = core.get_player_by_name(name)
		if not player then
			return false, "glb_probe: in game only"
		end
		local props = player:get_properties()
		local yaw = player:get_look_horizontal()
		local ahead = {x = -math.sin(yaw) * 3, y = 0, z = math.cos(yaw) * 3}
		local right = {x = math.cos(yaw), y = 0, z = math.sin(yaw)}
		local base = vector.add(player:get_pos(), ahead)
		local ok = spawn("glb", vector.subtract(base, right), yaw + math.pi, props)
		ok = spawn("b3d", vector.add(base, right), yaw + math.pi, props) and ok
		if not ok then
			return false, "glb_probe: could not spawn the models"
		end
		return true, "glb_probe: glb left, b3d right; stand and walk switch every "
			.. SWITCH .. " s"
	end,
})
