-- Disposable engine probe. The reserved port selects package 6, 7 or 8.
-- It drives the real registered mobs_redo ABM actions in a fresh scratch
-- world, bypassing only the engine's random ABM lottery.

local package_by_port = { [32176] = 6, [32177] = 7, [32178] = 8 }
local package = assert(package_by_port[tonumber(core.settings:get("port"))],
	"R9-MOB2 probe needs port 32176, 32177 or 32178")
local spawned = {}
local player_pos
local probe_player

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
function fake_player:get_player_name() return "r9_mob2_package_probe" end
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
setmetatable(fake_player, {__index = function() return function() return nil end end})

local real_add_entity = core.add_entity
local real_is_player = core.is_player
local real_get_connected_players = core.get_connected_players
local real_get_objects_inside_radius = core.get_objects_inside_radius

local expected = package == 6 and {
	["grug_mobs:goblin_miner"] = true,
	["grug_mobs:goblin_miner_slinger"] = true,
	["grug_mobs:oerkki"] = true,
	["grug_mobs:glowwing"] = true,
	["grug_mobs:crystal_shard"] = true,
	["grug_mobs:dungeon_master"] = true,
} or package == 7 and {
	["grug_mobs:lava_flan"] = true,
	["grug_mobs:ember_wisp"] = true,
	["grug_mobs:land_guard"] = true,
	["grug_mobs:rift_spawn"] = true,
} or {
	["grug_mobs:war_construct"] = true,
	["grug_mobs:speargrass_tiger"] = true,
	["grug_mobs:shore_crab"] = true,
	["grug_mobs:reef_lurker"] = true,
}

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
	if object and expected[name] then
		spawned[name] = (spawned[name] or 0) + 1
		core.log("action", "R9_MOB2_PACKAGE_SPAWN package=" .. package ..
			" name=" .. name .. " zone=" ..
			tostring(grug_zones.id_at(pos.x, pos.z)) .. " level=" ..
			tostring(grug_zones.mob_level_at(pos)) .. " x=" ..
			math.floor(pos.x) .. " y=" .. math.floor(pos.y) .. " z=" ..
			math.floor(pos.z))
	end
	return object
end

core.register_entity(":r9_mob2_package_spawn_probe:player_marker", {
	initial_properties = {
		physical = false, pointable = false, visual = "sprite",
		textures = {"grug_mobs_blank.png"}, static_save = false,
	},
})

local function abm_for(name, underground)
	local label = name .. " spawning"
	local found
	for _, def in pairs(core.registered_abms) do
		if def.label == label and (not underground or (def.max_y or 0) < 0) and
				(underground or (def.min_y or -1) >= 0) then
			assert(not found, "ambiguous ABM for " .. name)
			found = def
		end
	end
	return assert(found, "missing ABM for " .. name)
end

local function low_beach()
	for _, identity in ipairs(grug_core.start_identities()) do
		local anchor = identity.anchor
		for dz = -300, 300, 8 do
			for dx = -300, 300, 8 do
				local x, z = anchor.x + dx, anchor.z + dz
				local pos = {x = x, y = 2, z = z}
				local level = grug_zones.mob_level_at(pos)
				if level and level >= 1 and level <= 5 and
						not grug_mobs.in_start_footprint(x, z) then
					return x, z
				end
			end
		end
	end
	error("no level 1-5 beach coordinate")
end

local function high_beach()
	for z = -700, 700, 8 do
		for x = -3600, 3600, 8 do
			local pos = {x = x, y = 2, z = z}
			local level = grug_zones.mob_level_at(pos)
			if grug_zones.biome_at(x, z) == "grug_beach" and level and
					level >= 45 and level <= 60 then
				return x, z
			end
		end
	end
	error("no level 45-60 beach coordinate")
end

local function speargrass_point()
	for z = 1100, 1900, 8 do
		for x = -1300, -500, 8 do
			local pos = {x = x, y = 2, z = z}
			local level = grug_zones.mob_level_at(pos)
			if grug_zones.id_at(x, z) == "kragmar_speargrass_reach" and
					level and level >= 21 and level <= 30 then
				return x, z
			end
		end
	end
	error("no level 21-30 Speargrass Reach coordinate")
end

local cells
if package == 6 then
	cells = {
		{name = "grug_mobs:goblin_miner", x = 74, y = -200, z = -2500},
		{name = "grug_mobs:goblin_miner_slinger", x = 76, y = -200,
			z = -2500},
		{name = "grug_mobs:oerkki", x = 74, y = -400, z = -2500},
		{name = "grug_mobs:glowwing", x = 76, y = -400, z = -2500},
		{name = "grug_mobs:crystal_shard", x = 78, y = -400, z = -2500},
		{name = "grug_mobs:dungeon_master", x = 74, y = -600, z = -2500},
	}
elseif package == 7 then
	cells = {
		{name = "grug_mobs:lava_flan", x = 74, y = -800, z = -2500},
		{name = "grug_mobs:ember_wisp", x = 76, y = -800, z = -2500},
		{name = "grug_mobs:land_guard", x = 74, y = -1100, z = -2500},
		{name = "grug_mobs:rift_spawn", x = 76, y = -1100, z = -2500},
	}
else
	local low_x, low_z = low_beach()
	local high_x, high_z = high_beach()
	local tiger_x, tiger_z = speargrass_point()
	cells = {
		{name = "grug_mobs:war_construct", x = -750,
			y = grug_zones.terrain_height_at(-750, 0), z = 0,
			node = "grug_nodes:mud"},
		{name = "grug_mobs:speargrass_tiger", x = tiger_x,
			y = grug_zones.terrain_height_at(tiger_x, tiger_z), z = tiger_z,
			node = "default:dry_dirt_with_dry_grass"},
		{name = "grug_mobs:shore_crab", x = low_x, y = 1, z = low_z,
			node = "default:sand"},
		{name = "grug_mobs:reef_lurker", x = high_x, y = 1, z = high_z,
			node = "default:sand"},
	}
end
for _, cell in ipairs(cells) do cell.z = cell.z or 5000 end

local pending = #cells
local prepared = false
local function prepare_cell(cell)
	local floor = {x = cell.x, y = cell.y, z = cell.z}
	for dx = -2, 2 do
		for dz = -2, 2 do
			core.set_node({x = cell.x + dx, y = cell.y, z = cell.z + dz},
				{name = cell.node or "default:stone"})
			for dy = 1, 5 do
				core.set_node({x = cell.x + dx, y = cell.y + dy,
					z = cell.z + dz}, {name = "air"})
			end
		end
	end
	core.fix_light({x = floor.x - 3, y = floor.y - 1, z = floor.z - 3},
		{x = floor.x + 3, y = floor.y + 6, z = floor.z + 3})
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		for _, cell in ipairs(cells) do
			core.forceload_block({x = cell.x, y = cell.y, z = cell.z}, true, -1)
			core.emerge_area({x = cell.x - 8, y = cell.y - 8, z = cell.z - 8},
				{x = cell.x + 8, y = cell.y + 8, z = cell.z + 8},
				function(_, _, remaining)
					if remaining ~= 0 then return end
					prepare_cell(cell)
					pending = pending - 1
					if pending == 0 then prepared = true end
				end)
		end
	end)
end)

local function drive(cell)
	local underground = cell.y < 0
	local abm = abm_for(cell.name, underground)
	player_pos = {x = cell.x + 30, y = cell.y + 1, z = cell.z}
	probe_player:set_pos(player_pos)
	local pos = {x = cell.x, y = cell.y, z = cell.z}
	core.log("action", "R9_MOB2_PACKAGE_CANDIDATE package=" .. package ..
		" name=" .. cell.name .. " policy=" ..
		tostring(grug_mobs.spawn_policy_allows(cell.name, pos)) .. " biome=" ..
		tostring(grug_zones.biome_at(pos.x, pos.z)) .. " level=" ..
		tostring(grug_zones.mob_level_at(pos)) .. " y=" .. pos.y)
	abm.action(pos, core.get_node(pos), 0, 0)
	assert((spawned[cell.name] or 0) == 1,
		"registered ABM did not spawn " .. cell.name)
end

local ready_for = 0
local ran = false
core.register_globalstep(function(dtime)
	if ran or not prepared then return end
	ready_for = ready_for + dtime
	if ready_for < 2 then return end
	ran = true
	core.after(0, function()
		probe_player = assert(real_add_entity({x = cells[1].x + 30,
			y = cells[1].y + 1, z = cells[1].z},
			"r9_mob2_package_spawn_probe:player_marker"))
		core.is_player = function(object)
			return object == probe_player or real_is_player(object)
		end
		core.get_connected_players = function() return {probe_player} end
		core.set_timeofday(package == 8 and 0.5 or 0.9)
		for _, cell in ipairs(cells) do drive(cell) end
		local count = 0
		for name in pairs(expected) do
			assert(spawned[name] == 1, "missing spawn receipt for " .. name)
			count = count + 1
		end
		core.log("action", "R9_MOB2_PACKAGE_RESULT package=" .. package ..
			" families=" .. count .. " result=PASS")
		core.is_player = real_is_player
		core.get_connected_players = real_get_connected_players
		probe_player:remove()
		core.request_shutdown("R9-MOB2 package probe complete", false, 0)
	end)
end)
