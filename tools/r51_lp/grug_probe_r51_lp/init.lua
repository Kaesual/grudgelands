-- Disposable engine probe (Round 51 lane LP): the land plants in the engine,
-- once. Never shipped: tools/r51_lp/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is lane LG's probe's.
--
-- 1. Sky strips above the spawn (full daylight, nothing in the way), each a
--    ground 26 x 7 nodes and 2 deep (goal 1: the plants next to their zone's
--    gathering sources, ruling 11):
--      P1 jungle   canopy litter: the three strong flowers | the jungle's
--                  gathering sources | the three ferns; a large-leaved bush;
--                  a liana run (three strands and the end) under a leaf pad
--      P2 elves    silver litter: the three pastel flowers | the elves'
--                  gathering sources
--      P3 crags    gravel and stone: lichen a and b, the alpine plants | the
--                  crags' and pine hills' gathering sources
--      P4 beach    sand by water: papyrus stacks of 2, 3 and 4 at the edge,
--                  the marram grasses on the dry sand, a withered bush on
--                  mesa clay
-- 2. The generated world: the nearest jungle, elf forest, crags and warm
--    beach (zones by grug_zones), each emerged, its land plants counted
--    ("COUNT <scene> name=n ...") and shot (W1..W4).

local P = "[r51lp] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51lp_settle") or "") or 6
local FILTER = core.settings:get("r51lp_shots") or "P,W"
local TIME_OF_DAY = 0.5

local function log(msg) core.log("action", P .. msg) end

local B -- the strips' origin (south-west corner, top layer)
local function at(dx, dy, dz) return {x = B.x + dx, y = B.y + dy, z = B.z + dz} end

local STRIPS = {
	{z = 0, ground = "grug_nodes:dirt_with_canopy_litter", items = {
		"grug_nodes:flower_ruby_fan", "grug_nodes:flower_ember_star", "grug_nodes:flower_violet_fan", false,
		"grug_gathering:crimson_lotus_source", "grug_gathering:wild_cocoa_source",
		"grug_gathering:melon_source", "grug_mapgen:bamboo_shoot_source",
		"grug_mapgen:jungle_berry_source", false,
		"default:fern_1", "default:fern_2", "default:fern_3"}},
	{z = 12, ground = "grug_nodes:dirt_with_silver_litter", items = {
		"grug_nodes:flower_blush_star", "grug_nodes:flower_lilac_bells", "grug_nodes:flower_cream_cups", false,
		"grug_gathering:sunleaf_source", "grug_mapgen:carrot_source", "grug_mapgen:wild_onion_source",
		"grug_mapgen:wild_grain_source"}},
	{z = 24, ground = "default:gravel", items = {
		"grug_nodes:alpine_cushion", "grug_nodes:alpine_windshrub", "grug_nodes:alpine_cushion", false,
		"grug_gathering:dragonweed_source", "grug_gathering:gravemoss_source",
		"grug_mapgen:frost_melon_source"}},
}
local BEACH_Z = 36
local LIANA = {"grug_trees:liana_strand", "grug_trees:liana_strand", "grug_trees:liana_strand",
	"grug_trees:liana"}
local liana_at = {}

local function build()
	local put = {}
	local function set(p, name)
		put[name] = put[name] or {}
		put[name][#put[name] + 1] = p
	end
	for _, strip in ipairs(STRIPS) do
		for x = 0, 25 do
			for z = 0, 6 do
				for y = -1, 0 do
					local ground = strip.ground
					-- the crags strip: stone on its east half
					if ground == "default:gravel" and x >= 13 and y == 0 then ground = "default:stone" end
					set(at(x, y, strip.z + z), ground)
				end
			end
		end
		for i, name in ipairs(strip.items) do
			if name then set(at(i * 2 - 1, 1, strip.z + 3), name) end
		end
	end
	-- the crags' lichen: two sparse patches, on gravel and on stone
	for _, c in ipairs({{4, 30}, {18, 29}}) do
		for k, d in ipairs({{0, 0}, {1, 1}, {-1, 1}, {2, -1}, {0, 2}}) do
			set(at(c[1] + d[1], 1, c[2] + d[2]), k % 2 == 0 and "grug_nodes:lichen_carpet_b" or
				"grug_nodes:lichen_carpet")
		end
	end
	-- the beach: sand, water 3 wide on the south side (2 deep), the rest dry
	for x = 0, 25 do
		for z = 0, 9 do
			local water = z <= 2
			set(at(x, -2, BEACH_Z + z), "default:sand")
			set(at(x, -1, BEACH_Z + z), water and "default:water_source" or "default:sand")
			set(at(x, 0, BEACH_Z + z), water and "default:water_source" or
				((x >= 19 and z >= 5) and "grug_nodes:mesa_clay" or "default:sand"))
		end
	end
	for i, h in ipairs({2, 3, 4, 2, 3}) do
		for y = 1, h do set(at(i * 3 - 2, y, BEACH_Z + 3), "default:papyrus") end
	end
	for i = 1, 6 do set(at(i * 2, 1, BEACH_Z + 7 + i % 2), "default:marram_grass_" .. (i % 3 + 1)) end
	-- the liana: a jungle leaf pad at 8 over the jungle strip's east end
	for dx = -1, 1 do
		for dz = -1, 1 do set(at(23 + dx, 8, 3 + dz), "default:jungleleaves") end
	end
	for i, name in ipairs(LIANA) do
		liana_at[i] = at(23, 8 - i, 3)
		set(liana_at[i], name)
	end
	local count = 0
	local names = {}
	for name in pairs(put) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		if core.registered_nodes[name] then
			core.bulk_set_node(put[name], {name = name, param2 = 1})
			count = count + #put[name]
		else
			log("missing node " .. name)
		end
	end
	-- the bushes: default's schematics with their own foliage, as the rows
	local schem = core.get_modpath("default") .. "/schematics/"
	core.place_schematic(at(19, 1, 1), schem .. "bush.mts", "0",
		{["default:bush_leaves"] = "grug_nodes:jungle_bush_leaves"}, true)
	core.place_schematic(at(21, 1, BEACH_Z + 6), schem .. "acacia_bush.mts", "0",
		{["default:acacia_bush_leaves"] = "grug_nodes:withered_bush_leaves"}, true)
	log(("strips built at %s: %d nodes"):format(core.pos_to_string(B), count))
end

local SHOTS = {
	{name = "P1_jungle", cam = {12, 5, -9}, yaw = 0, pitch = 22, first = true},
	{name = "P1_jungle_liana_bush", cam = {21, 3, -4}, yaw = 0, pitch = 2},
	{name = "P2_elves", cam = {9, 4, 6}, yaw = 0, pitch = 24},
	{name = "P3_crags", cam = {12, 5, 17}, yaw = 0, pitch = 30},
	{name = "P4_beach", cam = {12, 6, BEACH_Z - 6}, yaw = 0, pitch = 28},
}
-- World scenes: biomes, whether a shore, camera height above the ground and pitch.
local WARM = {grug_deep_jungle = true, grug_jungle_fringe = true, grug_jungle_edge = true,
	grug_savanna = true, grug_badlands = true, grug_badlands_east = true}
local WORLD = {
	{name = "W1_jungle", biomes = {grug_deep_jungle = true, grug_jungle_fringe = true}, up = 3, pitch = 4},
	{name = "W2_elf_forest", biomes = {grug_elf_forest = true}, up = 5, pitch = 18},
	{name = "W3_crags", biomes = {grug_crags = true}, up = 12, pitch = 32},
	{name = "W4_warm_beach", biomes = WARM, shore = true, up = 8, pitch = 30},
}
local COUNTED = {"grug_trees:liana", "grug_trees:liana_strand", "grug_nodes:flower_ruby_fan",
	"grug_nodes:flower_ember_star", "grug_nodes:flower_violet_fan", "grug_nodes:flower_blush_star",
	"grug_nodes:flower_lilac_bells", "grug_nodes:flower_cream_cups", "default:fern_1", "default:fern_2",
	"default:fern_3", "grug_nodes:jungle_bush_leaves", "grug_nodes:withered_bush_leaves",
	"grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b", "grug_nodes:alpine_cushion",
	"grug_nodes:alpine_windshrub", "default:papyrus", "default:marram_grass_1",
	"default:marram_grass_2", "default:marram_grass_3"}

local function zone_ok(scene, x, z)
	local zones = grug_zones
	if not scene.biomes[zones.biome_at(x, z) or ""] or zones.water_class_at(x, z) ~= "land" then
		return false
	end
	if scene.shore then
		local wet = false
		for _, d in ipairs({{6, 0}, {-6, 0}, {0, 6}, {0, -6}, {10, 0}, {-10, 0}, {0, 10}, {0, -10}}) do
			local class = zones.water_class_at(x + d[1], z + d[2])
			if class == "immutable_dragon_channel" then return false end
			if class == "coastal_shelf" or class == "deep_ocean" or class == "planned_water" then wet = true end
		end
		return wet
	end
	for _, d in ipairs({{20, 20}, {-20, 20}, {20, -20}, {-20, -20}}) do
		if not scene.biomes[zones.biome_at(x + d[1], z + d[2]) or ""] or
				zones.water_class_at(x + d[1], z + d[2]) ~= "land" then
			return false
		end
	end
	return true
end

-- The nearest column of a scene on a 32-node grid around `origin`.
local function find_scene(scene, origin)
	for r = 1, 120 do
		local best
		for i = -r, r do
			for _, d in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = origin.x + d[1] * 32, origin.z + d[2] * 32
				if not best and zone_ok(scene, x, z) then best = {x = x, z = z} end
			end
		end
		if best then return best end
	end
end

local function filter_shots()
	local kept = {}
	for _, shot in ipairs(SHOTS) do
		for prefix in FILTER:gmatch("[^,]+") do
			if shot.name:sub(1, #prefix) == prefix then
				kept[#kept + 1] = shot
				break
			end
		end
	end
	SHOTS = kept
end

local function camera_of(shot)
	if shot.pos then return shot.pos, shot.yaw, shot.pitch end
	return at(shot.cam[1], shot.cam[2], shot.cam[3]), shot.yaw, shot.pitch
end

---------------------------------------------------------------------------
-- The driver (lane LG's)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51lp_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function hide_hud(player)
	player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
		wielditem = false, breathbar = false, minimap = false, minimap_radar = false,
		basic_debug = false, chat = false})
	for id in pairs(player:hud_get_all() or {}) do
		player:hud_remove(id)
	end
	player:set_clouds({density = 0})
	player:set_properties({is_visible = false, show_on_minimap = false,
		visual_size = {x = 0, y = 0, z = 0}})
end

local function hold(player, shot)
	-- no fall, drowning or mob may end the run
	player:set_armor_groups({immortal = 1})
	if player:get_hp() < 20 then player:set_hp(20) end
	local pos, yaw, pitch = camera_of(shot)
	player:set_pos({x = pos.x, y = pos.y - 1.625, z = pos.z})
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(pitch))
end

-- Emerge one world scene, count its plants and add its shot.
local function visit(scene, origin)
	local spot = find_scene(scene, origin)
	if not spot then
		log("scene " .. scene.name .. ": none found")
		return false
	end
	local ground = math.floor(grug_zones.terrain_height_at(spot.x, spot.z))
	local minp = {x = spot.x - 40, y = ground - 16, z = spot.z - 40}
	local maxp = {x = spot.x + 40, y = ground + 48, z = spot.z + 40}
	state.pending = true
	state.emerge_started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining == 0 then state.pending = false end
	end)
	state.scene = {scene = scene, spot = spot, ground = ground, minp = minp, maxp = maxp}
	log(("scene %s at %d,%d,%d (%s)"):format(scene.name, spot.x, ground, spot.z,
		grug_zones.biome_at(spot.x, spot.z)))
	return true
end

local function count_scene()
	local s = state.scene
	local _, found = core.find_nodes_in_area(s.minp, s.maxp, COUNTED)
	local parts = {}
	for _, name in ipairs(COUNTED) do
		if (found[name] or 0) > 0 then parts[#parts + 1] = name:gsub("^.*:", "") .. "=" .. found[name] end
	end
	log(("COUNT %s %s (emerge %.1f s)"):format(s.scene.name, table.concat(parts, " "),
		(core.get_us_time() - state.emerge_started) / 1e6))
	-- the camera in open air: up from the scene's height until the eye and
	-- the cells round it are free (a trunk or leaves there would hide all)
	local cam = {x = s.spot.x, y = s.ground + s.scene.up, z = s.spot.z - 18}
	local function free(p)
		for _, d in ipairs({{0, 0, 0}, {0, -1, 0}, {0, -2, 0}, {0, 0, 1}, {1, 0, 0}, {-1, 0, 0}}) do
			local name = core.get_node({x = p.x + d[1], y = p.y + d[2], z = p.z + d[3]}).name
			if name ~= "air" then return false end
		end
		return true
	end
	for _ = 1, 40 do
		if free(cam) then break end
		cam.y = cam.y + 1
	end
	SHOTS[#SHOTS + 1] = {name = s.scene.name, first = true, pos = cam, yaw = 0, pitch = s.scene.pitch}
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
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
		local pos = vector.round(player:get_pos())
		state.home = pos
		log("character complete at " .. core.pos_to_string(pos))
		B = {x = pos.x - 13, y = pos.y + 60, z = pos.z + 10}
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		state.phase = "emerge"
		state.pending = true
		state.emerge_started = core.get_us_time()
		core.emerge_area(at(-16, -24, -24), at(48, 24, 72), function(_, _, remaining)
			if remaining == 0 then state.pending = false end
		end)
	elseif state.phase == "emerge" then
		if state.pending then return end
		log(string.format("emerge done in %.1f s", (core.get_us_time() - state.emerge_started) / 1e6))
		build()
		filter_shots()
		hide_hud(player)
		state.phase = "shoot"
		state.shot = 1
		state.waited = 0
		state.logged = false
		state.next_scene = FILTER:find("W", 1, true) and 1 or #WORLD + 1
		log("READY")
	elseif state.phase == "world" then
		if state.pending then return end
		count_scene()
		state.phase = "shoot"
		state.waited = 0
		state.logged = false
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			-- the next world scene, if any
			while state.next_scene <= #WORLD do
				local scene = WORLD[state.next_scene]
				state.next_scene = state.next_scene + 1
				if visit(scene, state.home) then
					state.phase = "world"
					return
				end
			end
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		core.set_timeofday(TIME_OF_DAY)
		hold(player, shot)
		hide_hud(player)
		state.waited = state.waited + step
		local wait = shot.first and SETTLE * 2 or SETTLE
		if shot.pos then wait = SETTLE * 3 end
		if not state.logged and state.waited >= wait then
			state.logged = true
			log("SHOT " .. shot.name .. " at " .. core.pos_to_string(vector.round(camera_of(shot))))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited = 0
			state.logged = false
		end
	end
end)
