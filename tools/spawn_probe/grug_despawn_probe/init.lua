-- Disposable Lane S headless probe for the block-unload removal path.

local PLAYER_DISTANCE = 32
local LOG_INTERVAL = 1
local UNLOAD_AT = 10
local RELOAD_AT = 25
local FINISH_AT = 40
local UNLOAD_TIMEOUT = 2

local player_pos
local stag_pos
local stag_ref
local stag_block_forced = false
local elapsed = 0
local next_log = 0
local phase = "waiting"

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

local function probe_entity()
	local objects = core.get_objects_inside_radius(stag_pos, 4)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity and entity._grug_lane_s_probe then
			return objects[index], entity
		end
	end
	return nil, nil
end

local function start_probe()
	local start = grug_core.start_position("accord", "human")
	if not start then
		core.log("error", "GRUG_R5_DESPAWN event=fail missing_human_start")
		return
	end
	player_pos = {x = start.x, y = start.y, z = start.z}
	stag_pos = {x = start.x + PLAYER_DISTANCE, y = start.y + 2, z = start.z}
	core.settings:set("server_unload_unused_data_timeout",
		tostring(UNLOAD_TIMEOUT))
	stag_block_forced = core.forceload_block(stag_pos, true, -1)
	stag_ref = core.add_entity(stag_pos, "grug_mobs:stag")
	local entity = stag_ref and stag_ref:get_luaentity()
	if not entity then
		core.log("error", "GRUG_R5_DESPAWN event=fail stag_add")
		return
	end
	entity._grug_lane_s_probe = true
	-- A mob that has completed one ordinary save/reactivation carries this
	-- upstream unload-culling flag. The reported stag was an existing mob,
	-- not a brand-new entity receiving its one-save grace period.
	entity.remove_ok = true
	entity.order = "stand"
	entity.state = "stand"
	entity.walk_chance = 0
	core.get_connected_players = function() return {fake_player} end
	phase = "loaded"
	elapsed = 0
	log({"event=start", "distance=" .. PLAYER_DISTANCE,
		"active_block_range=" .. tostring(core.settings:get("active_block_range") or 4),
		"unload_timeout=" .. UNLOAD_TIMEOUT,
		"remove_ok=" .. tostring(entity.remove_ok),
		"forced=" .. tostring(stag_block_forced)})
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
	if phase == "loaded" and elapsed >= UNLOAD_AT then
		core.forceload_free_block(stag_pos, true)
		stag_block_forced = false
		phase = "unloaded"
		log({"event=block_unload", "second=" .. math.floor(elapsed)})
	elseif phase == "unloaded" and elapsed >= RELOAD_AT then
		stag_block_forced = core.forceload_block(stag_pos, true, -1)
		core.load_area(stag_pos, stag_pos)
		phase = "reloaded"
		log({"event=block_reload", "second=" .. math.floor(elapsed),
			"forced=" .. tostring(stag_block_forced)})
	end

	if elapsed >= next_log then
		next_log = next_log + LOG_INTERVAL
		local object = probe_entity()
		log({"event=lifetime", "second=" .. math.floor(elapsed),
			"phase=" .. phase, "active=" .. tostring(object ~= nil)})
	end
	if elapsed >= FINISH_AT then
		local object = probe_entity()
		phase = "done"
		log({"event=finish", "seconds=" .. FINISH_AT,
			"alive=" .. tostring(object ~= nil)})
		core.request_shutdown("Lane S despawn window complete", false, 0)
	end
end)
