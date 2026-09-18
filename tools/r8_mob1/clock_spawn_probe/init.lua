-- Disposable headless probe. It drives the registered mobs_redo ABM actions
-- at real generated nodes, bypassing only the engine's random ABM lottery.

local player_pos
local spawned = {}
local probe_player
local whitebridge_ready = false
local fake_meta = {
	get_string = function() return "" end,
	set_string = function() end,
	get_int = function() return 0 end,
	set_int = function() end,
	contains = function() return false end,
}
local fake_inventory = {
	get_stack = function() return ItemStack("") end,
	get_list = function() return {} end,
	get_size = function() return 0 end,
	contains_item = function() return false end,
	room_for_item = function() return true end,
}
local fake_player = {}
function fake_player:get_pos()
	return {x = player_pos.x, y = player_pos.y, z = player_pos.z}
end
function fake_player:get_player_name() return "r8_mob1_clock_probe" end
function fake_player:is_player() return true end
function fake_player:get_meta() return fake_meta end
function fake_player:get_inventory() return fake_inventory end
function fake_player:get_player_control() return {} end
function fake_player:get_hp() return 20 end
function fake_player:get_properties() return {hp_max = 20, eye_height = 1.625} end
function fake_player:get_armor_groups() return {fleshy = 100} end
function fake_player:get_wielded_item() return ItemStack("") end
function fake_player:get_look_horizontal() return 0 end
function fake_player:get_look_vertical() return 0 end
function fake_player:get_look_dir() return {x = 0, y = 0, z = 1} end
function fake_player:hud_add() return 1 end
function fake_player:hud_get() return nil end
function fake_player:hud_get_flags() return {} end
function fake_player:get_player_velocity() return {x = 0, y = 0, z = 0} end
setmetatable(fake_player, {__index = function() return function() return nil end end})

local real_add_entity = core.add_entity
local real_is_player = core.is_player
local real_get_connected_players = core.get_connected_players
local real_get_objects_inside_radius = core.get_objects_inside_radius
core.get_objects_inside_radius = function(pos, radius)
	local objects = real_get_objects_inside_radius(pos, radius)
	if player_pos then
		local dx = pos.x - player_pos.x
		local dy = pos.y - player_pos.y
		local dz = pos.z - player_pos.z
		if dx * dx + dy * dy + dz * dz <= radius * radius then
			objects[#objects + 1] = fake_player
		end
	end
	return objects
end
core.add_entity = function(pos, name, staticdata)
	local object = real_add_entity(pos, name, staticdata)
	if object and (name == "grug_mobs:boar" or name == "grug_mobs:zombie" or
			name == "grug_mobs:song_bird" or
			name == "grug_mobs:wild_turkey" or
			name == "grug_mobs:giant_rat" or name == "grug_mobs:wisp") then
		spawned[name] = (spawned[name] or 0) + 1
		core.log("action", "R8_MOB1_CLOCK_SPAWN name=" .. name ..
			" tod=" .. tostring(core.get_timeofday()) ..
			" zone=" .. tostring(grug_zones.id_at(pos.x, pos.z)) ..
			" x=" .. math.floor(pos.x) .. " y=" .. math.floor(pos.y) ..
			" z=" .. math.floor(pos.z))
	end
	return object
end

core.register_entity(":r8_mob1_clock_spawn_probe:player_marker", {
	initial_properties = {
		physical = false, pointable = false, visual = "sprite",
		textures = {"grug_mobs_blank.png"}, static_save = false,
	},
})

local function force_area(pos)
	for dx = -128, 128, 16 do
		for dz = -128, 128, 16 do
			for dy = -16, 16, 16 do
				core.forceload_block({x = pos.x + dx, y = pos.y + dy,
					z = pos.z + dz}, true, -1)
			end
		end
	end
end

local function abm_for(name)
	local label = name .. " spawning"
	for _, def in pairs(core.registered_abms) do
		if def.label == label then return def end
	end
	return nil
end

local tops = {
	"default:dirt_with_grass",
	"default:dirt_with_coniferous_litter",
	"grug_nodes:dirt_with_silver_litter",
	"default:dry_dirt_with_dry_grass",
	"default:dirt_with_rainforest_litter",
	"grug_nodes:dirt_with_forest_litter",
	"grug_nodes:dirt_with_canopy_litter",
	"grug_nodes:mesa_clay", "default:gravel", "default:snowblock",
	"grug_nodes:mud", "default:sand",
}

local function drive(name)
	local abm = assert(abm_for(name), "missing ABM for " .. name)
	local minp = {x = player_pos.x - 125, y = player_pos.y - 15,
		z = player_pos.z - 125}
	local maxp = {x = player_pos.x + 125, y = player_pos.y + 15,
		z = player_pos.z + 125}
	local positions = core.find_nodes_in_area_under_air(minp, maxp, tops)
	local tried = 0
	for i = 1, #positions do
		local pos = positions[i]
		local dx, dz = pos.x - player_pos.x, pos.z - player_pos.z
		local distance2 = dx * dx + dz * dz
		if distance2 > 80 * 80 and distance2 < 125 * 125 then
			tried = tried + 1
			if tried == 1 then
				core.log("action", "R8_MOB1_CLOCK_CANDIDATE name=" .. name ..
					" total=" .. #positions .. " zone=" ..
					tostring(grug_zones.id_at(pos.x, pos.z)) .. " policy=" ..
					tostring(grug_mobs.spawn_policy_allows(name, pos)) ..
					" light=" .. tostring(core.get_node_light({x = pos.x,
						y = pos.y + 1, z = pos.z})) .. " protected=" ..
					tostring(core.is_protected({x = pos.x, y = pos.y + 1,
						z = pos.z}, "")))
			end
			abm.action({x = pos.x, y = pos.y, z = pos.z}, core.get_node(pos), 0, 0)
			if (spawned[name] or 0) > 0 then return true end
		end
	end
	core.log("action", "R8_MOB1_CLOCK_DRIVE name=" .. name ..
		" candidates=" .. #positions .. " tried=" .. tried)
	return false
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		player_pos = assert(grug_core.start_position("accord", "human"))
		force_area(player_pos)
		local wx, wz = -900, -1500
		local wy = grug_zones.terrain_height_at(wx, wz) + 2
		local whitebridge = {x = wx, y = wy, z = wz}
		force_area(whitebridge)
		core.emerge_area({x = wx - 128, y = wy - 16, z = wz - 128},
			{x = wx + 128, y = wy + 16, z = wz + 128},
			function(_, _, remaining)
				if remaining == 0 then whitebridge_ready = true end
			end)
	end)
end)

local ready_for = 0
local ran = false
core.register_globalstep(function(dtime)
	if ran or not player_pos or not whitebridge_ready or
			not grug_core.start_ready("human") then return end
	ready_for = ready_for + dtime
	if ready_for < 5 then return end
	ran = true
	core.after(0, function()
			probe_player = assert(real_add_entity(player_pos,
				"r8_mob1_clock_spawn_probe:player_marker"))
			core.is_player = function(object)
				return object == probe_player or real_is_player(object)
			end
			core.get_connected_players = function() return {probe_player} end
			core.set_timeofday(0.5)
			local zombie_before = spawned["grug_mobs:zombie"] or 0
			drive("grug_mobs:zombie")
			assert((spawned["grug_mobs:zombie"] or 0) == zombie_before,
				"night family spawned by day")
			assert(drive("grug_mobs:boar"), "day family did not spawn by day")
			core.set_timeofday(0.9)
			local boar_before = spawned["grug_mobs:boar"] or 0
			drive("grug_mobs:boar")
			assert((spawned["grug_mobs:boar"] or 0) == boar_before,
				"day family spawned at night")
			assert(drive("grug_mobs:zombie"),
				"night family did not spawn at night")
			core.set_timeofday(0.5)
			assert(drive("grug_mobs:wild_turkey"),
				"package-3 day family did not spawn in Dawnmere")
			core.set_timeofday(0.9)
			assert(drive("grug_mobs:giant_rat"),
				"package-3 night family did not spawn in Dawnmere")
			player_pos = assert(grug_core.start_position("accord", "elf"))
			probe_player:set_pos(player_pos)
			force_area(player_pos)
			core.set_timeofday(0.5)
			assert(drive("grug_mobs:song_bird"),
				"package-2 day family did not spawn in Silverleaf")
			local wx, wz = -900, -1500
			player_pos = {x = wx, y = grug_zones.terrain_height_at(wx, wz) + 2,
				z = wz}
			probe_player:set_pos(player_pos)
			force_area(player_pos)
			core.set_timeofday(0.9)
			assert(drive("grug_mobs:wisp"),
				"package-4 night family did not spawn in Whitebridge")
			core.log("action", "R8_MOB1_CLOCK_RESULT day_boar=" ..
				tostring(spawned["grug_mobs:boar"] or 0) ..
				" night_zombie=" .. tostring(spawned["grug_mobs:zombie"] or 0) ..
				" day_song_bird=" .. tostring(spawned["grug_mobs:song_bird"] or 0) ..
				" day_wild_turkey=" ..
				tostring(spawned["grug_mobs:wild_turkey"] or 0) ..
				" night_giant_rat=" ..
				tostring(spawned["grug_mobs:giant_rat"] or 0) ..
				" night_wisp=" .. tostring(spawned["grug_mobs:wisp"] or 0))
			core.is_player = real_is_player
			core.get_connected_players = real_get_connected_players
			probe_player:remove()
			core.request_shutdown("R8-MOB1 clock spawn probe complete", false, 0)
	end)
end)
