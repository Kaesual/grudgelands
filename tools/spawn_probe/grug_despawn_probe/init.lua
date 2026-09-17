-- Disposable Lane S headless probe for the block-unload removal path.

local NEAR_DISTANCE = 32
local FAR_DISTANCE = 160
local LOG_INTERVAL = 1
local PREPARE_AT = 8
local UNLOAD_AT = 18
local RELOAD_AT = 33
local FINISH_AT = 63
local UNLOAD_TIMEOUT = 2

local player_pos
local near_pos
local far_pos
local blocks_forced = false
local elapsed = 0
local next_log = 0
local phase = "waiting"
local active_baseline

-- Keep the entity census isolated from ambient stag ABMs. spawn_action asks
-- this hook dynamically, so the disposable probe can refuse natural rows
-- without changing the production spawner or the two explicit probe entities.
mobs.spawn_abm_check = function() return true end

local function log(fields)
	local parts = {"GRUG_R5_DESPAWN"}
	for index = 1, #fields do parts[#parts + 1] = fields[index] end
	core.log("action", table.concat(parts, " "))
end

local fake_meta = {
	get_string = function() return "" end,
	set_string = function() end,
	get_int = function() return 0 end,
	set_int = function() end,
}
local fake_inventory = {
	get_stack = function() return ItemStack("") end,
	get_list = function() return {} end,
	get_size = function() return 0 end,
	contains_item = function() return false end,
	room_for_item = function() return true end,
}
local fake_player = {
	get_pos = function()
		return {x = player_pos.x, y = player_pos.y, z = player_pos.z}
	end,
	get_player_name = function() return "lane_s_probe" end,
	is_player = function() return true end,
	get_meta = function() return fake_meta end,
	get_inventory = function() return fake_inventory end,
	get_player_control = function() return {} end,
	get_hp = function() return 20 end,
	get_properties = function() return {hp_max = 20, eye_height = 1.625} end,
	get_armor_groups = function() return {fleshy = 100} end,
	get_wielded_item = function() return ItemStack("") end,
	get_look_horizontal = function() return 0 end,
	get_look_vertical = function() return 0 end,
	get_look_dir = function() return {x = 0, y = 0, z = 1} end,
	hud_add = function() return 1 end,
	hud_get = function() return nil end,
	hud_get_flags = function() return {} end,
}
setmetatable(fake_player, {
	__index = function() return function() return nil end end,
})

local function count_stags(pos)
	local count = 0
	local objects = core.get_objects_inside_radius(pos, 4)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity and entity.name == "grug_mobs:stag" then count = count + 1 end
	end
	return count
end

local function count_mob_objects()
	local count = 0
	local objects = core.get_objects_inside_radius(player_pos, 512)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity and entity._cmi_is_mob then count = count + 1 end
	end
	return count
end

local function active_count()
	return mobs:get_active_mob_count()
end

local function add_stationary_stag(pos, identity)
	local object = core.add_entity(pos, "grug_mobs:stag")
	local entity = object and object:get_luaentity()
	if not entity then return false end
	entity._grug_lane_s_probe = identity
	-- Existing mobs carry remove_ok after their first ordinary static save.
	entity.remove_ok = true
	entity.order = "stand"
	entity.state = "stand"
	entity.walk_chance = 0
	return true
end

local function start_probe()
	local start = grug_core.start_position("accord", "human")
	if not start then
		core.log("error", "GRUG_R5_DESPAWN event=fail missing_human_start")
		return
	end
	player_pos = {x = start.x, y = start.y, z = start.z}
	near_pos = {x = start.x + NEAR_DISTANCE, y = start.y + 2, z = start.z}
	far_pos = {x = start.x + FAR_DISTANCE, y = start.y + 2, z = start.z}
	core.settings:set("server_unload_unused_data_timeout",
		tostring(UNLOAD_TIMEOUT))
	local near_forced = core.forceload_block(near_pos, true, -1)
	local far_forced = core.forceload_block(far_pos, true, -1)
	blocks_forced = near_forced and far_forced
	core.get_connected_players = function() return {fake_player} end
	phase = "preparing"
	elapsed = 0
	next_log = PREPARE_AT
	log({"event=prepare", "near_distance=" .. NEAR_DISTANCE,
		"far_distance=" .. FAR_DISTANCE,
		"active_block_range=" .. tostring(core.settings:get("active_block_range") or 4),
		"unload_timeout=" .. UNLOAD_TIMEOUT,
		"forced=" .. tostring(blocks_forced),
		"active=" .. active_count()})
end

core.register_on_mods_loaded(function()
	local started = false
	local function maybe_start()
		if not started and grug_core.start_ready("human") then
			started = true
			start_probe()
		end
	end
	grug_core.register_on_starts_progress(function() maybe_start() end)
	core.after(0, maybe_start)
end)

core.register_globalstep(function(dtime)
	if phase == "waiting" or phase == "done" then return end
	elapsed = elapsed + dtime
	if phase == "preparing" and elapsed >= PREPARE_AT then
		active_baseline = active_count()
		if not add_stationary_stag(near_pos, "near") or
				not add_stationary_stag(far_pos, "far") then
			core.log("error", "GRUG_R5_DESPAWN event=fail stag_add")
			phase = "done"
			return
		end
		phase = "loaded"
		log({"event=start", "second=" .. math.floor(elapsed),
			"remove_ok=true", "active_baseline=" .. active_baseline,
			"active=" .. active_count(),
			"active_delta=" .. (active_count() - active_baseline)})
	elseif phase == "loaded" and elapsed >= UNLOAD_AT then
		core.forceload_free_block(near_pos, true)
		core.forceload_free_block(far_pos, true)
		blocks_forced = false
		phase = "unloaded"
		log({"event=block_unload", "second=" .. math.floor(elapsed)})
	elseif phase == "unloaded" and elapsed >= RELOAD_AT then
		local near_forced = core.forceload_block(near_pos, true, -1)
		local far_forced = core.forceload_block(far_pos, true, -1)
		blocks_forced = near_forced and far_forced
		phase = "reloaded"
		log({"event=block_reload", "second=" .. math.floor(elapsed),
			"forced=" .. tostring(blocks_forced)})
	end

	if elapsed >= next_log then
		next_log = next_log + LOG_INTERVAL
		log({"event=lifetime", "second=" .. math.floor(elapsed),
			"phase=" .. phase, "near=" .. count_stags(near_pos),
			"far=" .. count_stags(far_pos),
			"active=" .. active_count(),
			"mob_objects=" .. count_mob_objects(),
			"active_delta=" .. (active_count() - active_baseline)})
	end
	if elapsed >= FINISH_AT then
		local near = count_stags(near_pos)
		local far = count_stags(far_pos)
		phase = "done"
		log({"event=finish", "seconds=" .. FINISH_AT,
			"near=" .. near, "far=" .. far,
			"total=" .. (near + far),
			"active=" .. active_count(),
			"mob_objects=" .. count_mob_objects(),
			"active_delta=" .. (active_count() - active_baseline)})
		core.request_shutdown("Lane S despawn window complete", false, 0)
	end
end)
