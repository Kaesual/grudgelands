-- Disposable Lane S headless probe. tools/luanti_headless.sh stages this mod
-- only into an isolated scratch game; it is never loaded by Grudgelands.

local storage = core.get_mod_storage()
local boot = (tonumber(storage:get_string("boot")) or 0) + 1
storage:set_string("boot", tostring(boot))

local SETTLE_SECONDS = 5
local WINDOW_SECONDS = 60
local FORCE_REACH = 96
local CENSUS_RADIUS = 128

local player_pos
local fake_meta_values = {}
local fake_meta = {}

function fake_meta:get_string(key)
	return tostring(fake_meta_values[key] or "")
end

function fake_meta:set_string(key, value)
	fake_meta_values[key] = tostring(value)
end

function fake_meta:get_int(key)
	return tonumber(fake_meta_values[key]) or 0
end

function fake_meta:set_int(key, value)
	fake_meta_values[key] = math.floor(tonumber(value) or 0)
end

function fake_meta:contains(key)
	return fake_meta_values[key] ~= nil
end

local fake_inventory = {}

function fake_inventory:get_stack()
	return ItemStack("")
end

function fake_inventory:get_list()
	return {}
end

function fake_inventory:get_size()
	return 0
end

function fake_inventory:contains_item()
	return false
end

function fake_inventory:room_for_item()
	return true
end

local hud_id = 0
local fake_player = {}
fake_player._grug_spawn_probe_player = true

function fake_player:get_pos()
	return {x = player_pos.x, y = player_pos.y, z = player_pos.z}
end

function fake_player:get_player_name()
	return "lane_s_probe"
end

function fake_player:is_player()
	return true
end

function fake_player:get_meta()
	return fake_meta
end

function fake_player:get_inventory()
	return fake_inventory
end

function fake_player:get_player_control()
	return {}
end

function fake_player:get_hp()
	return 20
end

function fake_player:get_properties()
	return {hp_max = 20, eye_height = 1.625}
end

function fake_player:get_armor_groups()
	return {fleshy = 100}
end

function fake_player:get_wielded_item()
	return ItemStack("")
end

function fake_player:get_look_horizontal()
	return 0
end

function fake_player:get_look_vertical()
	return 0
end

function fake_player:get_look_dir()
	return {x = 0, y = 0, z = 1}
end

function fake_player:hud_add()
	hud_id = hud_id + 1
	return hud_id
end

function fake_player:hud_get()
	return nil
end

function fake_player:hud_get_flags()
	return {}
end

function fake_player:get_player_velocity()
	return {x = 0, y = 0, z = 0}
end

setmetatable(fake_player, {
	__index = function()
		return function() return nil end
	end,
})

local function distance(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function log(fields)
	local parts = {"GRUG_R5_SPAWN", "boot=" .. boot}
	for index = 1, #fields do
		parts[#parts + 1] = fields[index]
	end
	core.log("action", table.concat(parts, " "))
end

local function forceload_area(pos)
	local blocks = 0
	for dx = -FORCE_REACH, FORCE_REACH, 16 do
		for dz = -FORCE_REACH, FORCE_REACH, 16 do
			for dy = -16, 16, 16 do
				if core.forceload_block({
					x = pos.x + dx,
					y = pos.y + dy,
					z = pos.z + dz,
				}, true, -1) then
					blocks = blocks + 1
				end
			end
		end
	end
	return blocks
end

local real_add_entity = core.add_entity
local real_get_objects_inside_radius = core.get_objects_inside_radius
local measuring = false
local finished = false
local elapsed = 0
local spawn_count = 0

core.get_objects_inside_radius = function(pos, radius)
	local objects = real_get_objects_inside_radius(pos, radius)
	if player_pos and distance(pos, player_pos) <= radius then
		objects[#objects + 1] = fake_player
	end
	return objects
end

core.add_entity = function(pos, name, staticdata)
	local object = real_add_entity(pos, name, staticdata)
	if measuring and type(name) == "string" and
			mobs.spawning_mobs[name] and
			name:sub(1, 10) == "grug_mobs:" and
			distance(pos, player_pos) <= CENSUS_RADIUS then
		spawn_count = spawn_count + 1
		log({"event=spawn", "second=" .. math.floor(elapsed),
			"name=" .. name, "distance=" .. string.format("%.1f",
				distance(pos, player_pos))})
	end
	return object
end

local function setup_probe()
	player_pos = grug_core.start_position("accord", "human")
	if not player_pos then
		core.log("error", "GRUG_R5_SPAWN event=fail missing_human_start")
		return
	end
	core.get_connected_players = function()
		return {fake_player}
	end
	core.set_timeofday(0.5)
	log({"event=setup", "blocks=" .. forceload_area(player_pos),
		"x=" .. player_pos.x, "y=" .. player_pos.y,
		"z=" .. player_pos.z})
end

core.register_on_mods_loaded(function()
	core.after(0, setup_probe)
end)

local since_ready = 0
core.register_globalstep(function(dtime)
	if not player_pos then return end
	if not grug_core.start_ready("human") then return end
	since_ready = since_ready + dtime
	if not measuring and not finished and since_ready >= SETTLE_SECONDS then
		measuring = true
		elapsed = 0
		spawn_count = 0
		log({"event=window_start", "seconds=" .. WINDOW_SECONDS})
	end
	if not measuring then return end
	elapsed = elapsed + dtime
	if elapsed >= WINDOW_SECONDS then
		measuring = false
		finished = true
		log({"event=window_end", "seconds=" .. WINDOW_SECONDS,
			"spawns=" .. spawn_count})
		core.request_shutdown("Lane S spawn window complete", false, 0)
	end
end)
