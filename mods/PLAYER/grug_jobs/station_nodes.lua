local brewing = rawget(_G, "grug_brewing")
if brewing and brewing._grug_station_factory then
	return brewing._grug_station_factory
end

local factory = {}
local station_visuals = dofile(core.get_modpath("grug_jobs") ..
	"/station_visuals.lua")
local PUBLIC_STATIONS = {
	furnace = true,
	dual_furnace = true,
	brewing_stand = true,
	forge = true,
	tanning_rack = true,
	tailor_bench = true,
	carving_bench = true,
	jewellers_bench = true,
}
local public_positions = {}
local nodes_registered = false
local jobs_installed = false

local function pos_key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

function factory.register_public_position(station, pos)
	if not PUBLIC_STATIONS[station] or type(pos) ~= "table" or
			type(pos.x) ~= "number" or type(pos.y) ~= "number" or
			type(pos.z) ~= "number" then
		error("grug_jobs: public station position differs", 0)
	end
	public_positions[station .. "\0" .. pos_key(pos)] = true
end

function factory.is_public_station(station, pos)
	return public_positions[station .. "\0" .. pos_key(pos)] == true
end

-- The vendored furnace keeps its complete timer/extraction chain; this is
-- only the explicit authored public-position exception to node protection.
function factory.can_access_public_furnace(pos, player)
	if not factory.is_public_station("furnace", pos) or not player or
			not player.is_player or not player:is_player() or player:get_hp() <= 0 then
		return false
	end
	local at = player:get_pos()
	if not at or vector.distance(at, pos) > 8 then return false end
	local node = core.get_node_or_nil(pos)
	return node ~= nil and (node.name == "default:furnace" or
		node.name == "default:furnace_active")
end

local function register_station_node(station, info, visual)
	core.register_node(":" .. info.node, {
		description = info.display_name,
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = visual.boxes},
		tiles = visual.tiles or {visual.texture},
		paramtype = "light", paramtype2 = "facedir",
		is_ground_content = false,
		groups = visual.groups,
		sounds = type(visual.sounds) == "function" and visual.sounds() or visual.sounds,
		-- A proximity station (Round 45, spec ruling 27): no dialog and no
		-- lists; a profession job only checks that one stands nearby.
		_grug_station = station,
	})
end

local wood_boxes = {
	{-0.5, -0.5, -0.45, 0.5, -0.36, 0.45},
	{-0.43, -0.36, -0.38, -0.31, 0.25, -0.26},
	{0.31, -0.36, -0.38, 0.43, 0.25, -0.26},
	{-0.43, -0.36, 0.26, -0.31, 0.25, 0.38},
	{0.31, -0.36, 0.26, 0.43, 0.25, 0.38},
}

local STATION_INFO = {
	forge = {display_name = "Forge", professions = {weaponsmith = true,
		armorsmith = true},
		node = "grug_jobs:forge"},
	tanning_rack = {display_name = "Tanning Rack", profession = "leatherworker",
		node = "grug_jobs:tanning_rack"},
	tailor_bench = {display_name = "Tailor Bench", profession = "tailor",
		node = "grug_jobs:tailor_bench"},
	carving_bench = {display_name = "Carving Bench", profession = "woodcarver",
		node = "grug_jobs:carving_bench"},
	jewellers_bench = {display_name = "Jeweller's Bench", profession = "goldsmith",
		node = "grug_jobs:jewellers_bench"},
}

local function station_visual(station, fallback)
	local authored = station_visuals[station]
	if not authored then return fallback end
	return {texture = authored.texture or fallback.texture,
		tiles = authored.tiles, boxes = authored.boxes or fallback.boxes,
		groups = authored.groups or fallback.groups,
		sounds = authored.sounds or fallback.sounds}
end

function factory.register_nodes()
	if nodes_registered then return end
	nodes_registered = true
	register_station_node("forge", STATION_INFO.forge, station_visual("forge", {
		texture = "default_steel_block.png^[colorize:#34251f:70",
		boxes = {
			{-0.5, -0.5, -0.5, 0.5, -0.12, 0.5},
			{-0.32, -0.12, -0.2, 0.32, 0.08, 0.2},
			{-0.18, 0.08, -0.12, 0.18, 0.35, 0.12},
		},
		groups = {cracky = 2}, sounds = default.node_sound_metal_defaults,
	}))
	register_station_node("tanning_rack", STATION_INFO.tanning_rack, station_visual("tanning_rack", {
		texture = "default_wood.png^[colorize:#704020:55",
		boxes = {
			{-0.46, -0.5, -0.1, -0.34, 0.45, 0.1},
			{0.34, -0.5, -0.1, 0.46, 0.45, 0.1},
			{-0.34, -0.38, -0.04, 0.34, 0.34, 0.04},
			{-0.5, 0.34, -0.1, 0.5, 0.46, 0.1},
		},
		groups = {choppy = 2}, sounds = default.node_sound_wood_defaults,
	}))
	register_station_node("tailor_bench", STATION_INFO.tailor_bench, station_visual("tailor_bench", {
		texture = "default_wood.png^[colorize:#735493:75",
		boxes = wood_boxes,
		groups = {choppy = 2}, sounds = default.node_sound_wood_defaults,
	}))
	register_station_node("carving_bench", STATION_INFO.carving_bench, station_visual("carving_bench", {
		texture = "default_wood.png^[colorize:#315f35:45",
		boxes = wood_boxes,
		groups = {choppy = 2}, sounds = default.node_sound_wood_defaults,
	}))
	register_station_node("jewellers_bench", STATION_INFO.jewellers_bench, station_visual("jewellers_bench", {
		texture = "default_steel_block.png^[colorize:#c69a35:105",
		boxes = wood_boxes,
		groups = {cracky = 2}, sounds = default.node_sound_metal_defaults,
	}))
end

local STEEL = "grug_materials:steel_bar"

-- Each profession builds its own station (tier 3, no XP, no station nearby:
-- the station is what it builds).
local station_recipes = {
	{profession = "weaponsmith", output = "grug_jobs:forge", ingredients = {
		{item = STEEL, n = 3}, {item = "default:furnace", n = 1},
		{item = "default:stonebrick", n = 3}}},
	{profession = "leatherworker", output = "grug_jobs:tanning_rack", ingredients = {
		{group = "wood", n = 6}, {item = STEEL, n = 1}, {item = "default:paper", n = 1}}},
	{profession = "tailor", output = "grug_jobs:tailor_bench", ingredients = {
		{item = "default:paper", n = 3}, {item = STEEL, n = 1}, {group = "wood", n = 2},
		{item = "default:chest", n = 1}}},
	{profession = "woodcarver", output = "grug_jobs:carving_bench", ingredients = {
		{group = "wood", n = 5}, {item = STEEL, n = 1}, {item = "default:stick", n = 1}}},
	{profession = "goldsmith", output = "grug_jobs:jewellers_bench", ingredients = {
		{item = "default:glass", n = 2}, {item = STEEL, n = 1}, {item = "default:torch", n = 1},
		{item = "default:stonebrick", n = 3}}},
}

function factory.install_jobs(jobs)
	if jobs_installed then return end
	jobs_installed = true
	factory.register_nodes()
	jobs.register_public_position = factory.register_public_position
	jobs.is_public_station = factory.is_public_station
	jobs.can_access_public_furnace = factory.can_access_public_furnace
	jobs.workspaces = dofile(core.get_modpath("grug_jobs") .. "/workspaces.lua")
	core.register_lbm({
		label = "Activate authored public cooking hearths",
		name = "grug_jobs:activate_public_hearths",
		nodenames = {"default:furnace", "default:furnace_active"},
		run_at_every_load = true,
		action = function(pos)
			if not factory.is_public_station("furnace", pos) then return end
			local node = core.get_node_or_nil(pos)
			if not node or (node.name ~= "default:furnace" and
					node.name ~= "default:furnace_active") then return end
			local inv = core.get_meta(pos):get_inventory()
			if inv:get_size("src") == 0 and inv:get_size("fuel") == 0 and
					inv:get_size("dst") == 0 then
				core.registered_nodes["default:furnace"].on_construct(pos)
			end
		end,
	})
	jobs.register_ingredient_tier(STEEL, 3)
	for index = 1, #station_recipes do
		local recipe = station_recipes[index]
		jobs.register_recipe({area = recipe.profession, tier = 3,
			output = recipe.output, ingredients = recipe.ingredients,
			time = jobs.DURATIONS.station, progress = false})
	end
	core.register_on_mods_loaded(function()
		local settlements = grug_core.settlement_socket_settlements()
		for index = 1, #settlements do
			local sockets = grug_core.settlement_sockets_at(settlements[index].key)
			for socket_index = 1, #sockets do
				local socket = sockets[socket_index]
				local station = socket.tags and socket.tags[1]
				if socket.role == "public_station" and PUBLIC_STATIONS[station] then
					jobs.register_public_position(station, socket.pos)
				end
			end
		end
	end)
end

if brewing then brewing._grug_station_factory = factory end
return factory
