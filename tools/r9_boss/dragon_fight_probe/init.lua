-- Headless proof that the production Wyrmglass spawn ticks its runtime flight
-- state and casts against a probe-only hostile ObjectRef for 60 active seconds.

local real_add_entity = core.add_entity
local real_is_player = core.is_player
local real_get_faction = grug_core.get_player_faction
local dragon_object
local target_object
local target_anchor
local emerged = false
local elapsed = 0
local last_state
local saw_air = false
local saw_cast = false
local spawn_count = 0
local forced = {}

core.log("action", "R9_BOSS_DRAGON_PROBE loaded")

core.register_entity("r9_boss_dragon_fight_probe:target", {
	initial_properties = {
		hp_max = 32767,
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		visual = "sprite",
		visual_size = {x = 0, y = 0},
		textures = {"grug_mobs_blank.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
	},
})

core.add_entity = function(pos, name, staticdata)
	local object = real_add_entity(pos, name, staticdata)
	if object and name == "grug_mobs:ice_dragon" then
		spawn_count = spawn_count + 1
		dragon_object = object
		core.log("action", "R9_BOSS_DRAGON_SPAWN name=" .. name ..
			" count=" .. spawn_count .. " x=" .. math.floor(pos.x) ..
			" y=" .. math.floor(pos.y) .. " z=" .. math.floor(pos.z))
	end
	return object
end

local x, z = -3260, -40
local y = grug_zones.terrain_height_at(x, z) + 1

core.register_on_mods_loaded(function()
	core.after(0, function()
		core.emerge_area({x = x, y = y, z = z}, {x = x, y = y, z = z},
			function(_, _, remaining)
				if remaining ~= 0 then return end
				for dx = -32, 32, 16 do
					for dy = -16, 16, 16 do
						for dz = -32, 32, 16 do
							local pos = {x = x + dx, y = y + dy, z = z + dz}
							assert(core.forceload_block(pos, true, -1),
								"could not keep dragon probe mapblock active")
							forced[#forced + 1] = pos
						end
					end
				end
				emerged = true
				core.log("action", "R9_BOSS_DRAGON_READY anchor=-3260,-40")
			end)
	end)
end)

local function install_target()
	local pos = dragon_object and dragon_object:get_pos()
	if not pos then return false end
	target_anchor = {x = pos.x + 20, y = pos.y, z = pos.z}
	target_object = real_add_entity(target_anchor,
		"r9_boss_dragon_fight_probe:target")
	if not target_object then return false end
	core.is_player = function(object)
		return object == target_object or real_is_player(object)
	end
	grug_core.get_player_faction = function(name)
		if not name or name == "" then return "accord" end
		return real_get_faction(name)
	end
	local dragon = dragon_object:get_luaentity()
	dragon.attack = target_object
	core.log("action", "R9_BOSS_DRAGON_TARGET kind=probe_hostile distance=20")
	return true
end

local function state_name(dragon)
	local state = dragon.temp and dragon.temp.grug_dragon
	if not state then return "initializing" end
	local action = state.action and state.action.kind
	return state.mode .. (action and (":" .. action) or "")
end

local function restore_overrides()
	core.is_player = real_is_player
	grug_core.get_player_faction = real_get_faction
	for index = 1, #forced do
		core.forceload_free_block(forced[index], true)
	end
end

core.register_globalstep(function(dtime)
	if not emerged or spawn_count == 0 then return end
	assert(spawn_count == 1, "production heartbeat spawned duplicate Ice Dragons")
	if not target_object and not install_target() then return end
	target_object:set_pos(target_anchor)
	local dragon = dragon_object and dragon_object:get_luaentity()
	assert(dragon, "Ice Dragon disappeared during fight probe")
	elapsed = elapsed + dtime
	local current = state_name(dragon)
	if current ~= last_state then
		local pos = dragon_object:get_pos()
		core.log("action", "R9_BOSS_DRAGON_STATE t=" ..
			string.format("%.1f", elapsed) .. " state=" .. current ..
			" fly=" .. tostring(dragon.fly) .. " x=" ..
			string.format("%.1f", pos.x) .. " y=" ..
			string.format("%.1f", pos.y) .. " z=" ..
			string.format("%.1f", pos.z))
		last_state = current
	end
	if dragon.fly then saw_air = true end
	if current:find(":", 1, true) then saw_cast = true end
	if elapsed < 60 then return end
	local state = assert(dragon.temp and dragon.temp.grug_dragon,
		"dragon state machine did not initialize")
	assert(saw_air, "dragon never entered runtime flight")
	assert(saw_cast, "dragon never entered a cast state")
	assert(dragon._grug_boss_id == "dragon:wyrmglass", "wrong boss identity")
	assert(dragon.hp_max == 18000, "dragon did not receive flat boss HP")
	core.log("action", "R9_BOSS_DRAGON_RESULT ticks=60 flight=1 cast=1" ..
		" final=" .. state.mode .. " hp_max=" .. dragon.hp_max ..
		" spawns=" .. spawn_count)
	restore_overrides()
	core.request_shutdown("R9-BOSS dragon fight probe complete", false, 0)
end)
