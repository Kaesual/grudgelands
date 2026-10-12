-- Disposable engine probe (Round 24 Lane F). Never shipped:
-- tools/r24_density_xp/run.sh stages it through tools/luanti_headless.sh
-- together with probe_player_shim.patch (mobs_redo count_mobs accepts the
-- stationary probe points below as players in range) and, for the baseline,
-- the reverse of the Lane F grug_mobs change.
--
-- Eight probe points, seed 4242424242: each start zone 170 nodes from its
-- start toward the front (band 1, level 3), plus Moonfall Wood and Redtusk
-- Savanna. Each point's 7x7-block column (y h-32..h+47) is force-loaded, so
-- the real natural spawn ABMs, policy, clocks, light and caps run there. A
-- day window then a night window; at the census times every live grug_mobs
-- entity within 56 nodes (horizontal) of a point is counted: budgeted
-- natural species (the Round 24 ruling 27 set), other natural rows
-- (critters etc.) and everything else (NPCs, camps).
--
-- Depth mode (Round 46 lane UW; a `mode.txt` reading "depth" next to this
-- file, written by run.sh POINTS=depth): three points under the Hearthpine
-- point at y -30, -300 and -900, each a 7x7x5-block volume (y h-40..h+39)
-- force-loaded; one window at a fixed clock; at the census times every live
-- object within 56 nodes (3D) of a point is counted: hostile grug_mobs
-- (spawn_role_hostile), their elites, other grug_mobs and all objects. A
-- disposable test room 400 nodes east at y -200 holds one torch on its
-- floor; the light along the floor shows which nodes an underground row
-- (light <= 7 since Round 46, <= 5 before) may spawn on.

local P = "[r24_density_probe] "
local WINDOW = tonumber(core.settings:get("r24_density_window")) or 120
local CENSUS = {60, 90, 120}
local RADIUS = 56
local MODE = "surface"
do
	local handle = io.open(core.get_modpath(core.get_current_modname()) .. "/mode.txt", "r")
	if handle then
		MODE = (handle:read("*l") or "surface"):match("^%s*(%a+)") or "surface"
		handle:close()
	end
end

local POINTS = {
	{id = "hearthpine", x = -1800, z = -2380, h = 50},
	{id = "dawnmere", x = 0, z = -2380, h = 57},
	{id = "silverleaf", x = 1800, z = -2380, h = 28},
	{id = "stillgrave", x = -1800, z = 2380, h = 11},
	{id = "sunscar", x = 0, z = 2380, h = 41},
	{id = "kapok", x = 1800, z = 2380, h = 22},
	{id = "moonfall", x = 2400, z = -1600, h = 44},
	{id = "redtusk", x = 160, z = 2112, h = 96},
}

-- The Round 24 budgeted set, listed so the baseline (which lacks
-- grug_mobs.density_budgeted) is classified identically.
local BUDGETED = {}
for name in ([[ashen_treant bear blightfang_wolf boar bog_ooze bog_witch
carrion_crow crag_eagle crocodile fox frost_stray gaunt_stag giant_rat
giant_spider goblin_hound goblin_raider goblin_slinger gravewood_treant hyena
ibex jungle_ape jungle_boar jungle_lynx jungle_spider mesa_golem mountain_ram
pale_spider panther plague_boar plaguehide_bear poacher rift_spawn scorpion
serpent skeleton_archer skeleton_raider snow_leopard speargrass_tiger stag
stone_golem sun_dried_husk tapir viper vulture war_construct wisp wolf zebra
zombie]]):gmatch("%S+") do
	BUDGETED["grug_mobs:" .. name] = true
end

local DEPTH_POINTS = {
	{id = "depth30", x = -1800, z = -2380, h = -30},
	{id = "depth300", x = -1800, z = -2380, h = -300},
	{id = "depth900", x = -1800, z = -2380, h = -900},
}
local TORCH_ROOM = {x = -1400, y = -200, z = -2380, half = 12}
if MODE == "depth" then
	POINTS = DEPTH_POINTS
	CENSUS = {50, 100, 150}
	WINDOW = 150
end
-- Pulse mode (Round 46 lane DP; mode.txt "pulse", run.sh POINTS=pulse): three
-- points under the same column at y -400, -1000 and -1500, each with a
-- disposable 21x5x21 room carved around it (the same room before and after)
-- and a stationary stand-in player standing on its floor, handed to the depth
-- pulse as its player list. A stand-in is no target, so an arrival fades
-- after its 10 s; the census counts pulse arrivals apart from the ambient
-- hostiles, and the pulse counters are logged at the end.
local PULSE_POINTS = {
	{id = "pulse400", x = -1800, z = -2380, h = -400},
	{id = "pulse1000", x = -1800, z = -2380, h = -1000},
	{id = "pulse1500", x = -1800, z = -2380, h = -1500},
}
local PULSE_ROOM = {half = 10, height = 5}
if MODE == "pulse" then
	POINTS = PULSE_POINTS
	CENSUS = {60, 120, 180, 240}
	WINDOW = 240
end
local DEEP = MODE == "depth" or MODE == "pulse"

local function log(msg) core.log("action", P .. msg) end

local variant = grug_mobs.density_allows and "round24" or "baseline"
if MODE == "depth" then
	-- Round 46 lane UW: its tree has the underground boundary constant.
	variant = grug_mobs.UNDERGROUND_TOP and "round46" or "baseline"
end
if MODE == "pulse" then
	variant = grug_mobs.depth_pulse and "pulse" or "baseline"
end

local function census_depth(label)
	for _, point in ipairs(POINTS) do
		local center = {x = point.x, y = point.h, z = point.z}
		-- shallow: hostiles standing above y -40.5, the band without
		-- underground spawns before Round 46.
		local hostile, elite, other_mobs, objects, shallow, pulse = 0, 0, 0, 0, 0, 0
		local by_name = {}
		for _, object in ipairs(core.get_objects_inside_radius(center, RADIUS)) do
			objects = objects + 1
			local ent = object:get_luaentity()
			if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" then
				if ent._grug_pulse then
					pulse = pulse + 1
					local short = "pulse:" .. ent.name:sub(11)
					by_name[short] = (by_name[short] or 0) + 1
				elseif grug_mobs.spawn_role_hostile(ent.name) then
					hostile = hostile + 1
					if object:get_pos().y > -40.5 then shallow = shallow + 1 end
					local short = ent.name:sub(11)
					if ent._grug_tier == "elite" then
						elite = elite + 1
						short = short .. "*L" .. tostring(ent._grug_level)
					end
					by_name[short] = (by_name[short] or 0) + 1
				else
					other_mobs = other_mobs + 1
				end
			end
		end
		local names = {}
		for name, count in pairs(by_name) do names[#names + 1] = name .. "=" .. count end
		table.sort(names)
		log(("depth %s %s %s hostile=%d elite=%d shallow=%d other_mobs=%d objects=%d " ..
			"level=%s [%s]%s"):format(variant, label, point.id, hostile, elite, shallow,
			other_mobs, objects,
			tostring(grug_zones.mob_level_at(center)), table.concat(names, " "),
			MODE == "pulse" and (" pulse=" .. pulse) or ""))
	end
end

-- The torch room: a 25x4x25 air room on a stone floor, one torch in the
-- middle of the floor; the light at the floor's standing height by distance.
local function torch_room()
	local r = TORCH_ROOM
	local minp = {x = r.x - r.half - 1, y = r.y - 1, z = r.z - r.half - 1}
	local maxp = {x = r.x + r.half + 1, y = r.y + 4, z = r.z + r.half + 1}
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()
	local air, stone = core.get_content_id("air"), core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local inside = math.abs(x - r.x) <= r.half and math.abs(z - r.z) <= r.half and
					y >= r.y and y <= r.y + 3
				data[area:index(x, y, z)] = inside and air or stone
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	core.set_node({x = r.x, y = r.y, z = r.z}, {name = "default:torch", param2 = 1})
	local parts, before_r, after_r = {}, nil, nil
	for d = 0, 10 do
		local light = core.get_node_light({x = r.x + d, y = r.y, z = r.z})
		parts[#parts + 1] = d .. ":" .. tostring(light)
		if light and light <= 7 and not after_r then after_r = d end
		if light and light <= 5 and not before_r then before_r = d end
	end
	log(("torch light along the floor (distance:light) %s; first spawnable distance " ..
		"at light<=7: %s, at light<=5: %s"):format(table.concat(parts, " "),
		tostring(after_r), tostring(before_r)))
end

-- Pulse mode: the rooms, carved once before the window.
local function pulse_rooms()
	local air, stone = core.get_content_id("air"), core.get_content_id("default:stone")
	for _, point in ipairs(POINTS) do
		local half, height = PULSE_ROOM.half, PULSE_ROOM.height
		local minp = {x = point.x - half - 1, y = point.h - 1, z = point.z - half - 1}
		local maxp = {x = point.x + half + 1, y = point.h + height, z = point.z + half + 1}
		local vm = core.get_voxel_manip()
		local emin, emax = vm:read_from_map(minp, maxp)
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local data = vm:get_data()
		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				for x = minp.x, maxp.x do
					local inside = math.abs(x - point.x) <= half and math.abs(z - point.z) <= half
						and y >= point.h and y < point.h + height
					data[area:index(x, y, z)] = inside and air or stone
				end
			end
		end
		vm:set_data(data)
		vm:write_to_map(true)
	end
end

local function pulse_stand_ins()
	local list = {}
	for _, point in ipairs(POINTS) do
		local pos = {x = point.x, y = point.h - 0.5, z = point.z}
		list[#list + 1] = {
			get_pos = function() return {x = pos.x, y = pos.y, z = pos.z} end,
			get_player_name = function() return "probe_" .. point.id end,
			get_hp = function() return 20 end,
		}
	end
	return list
end

local function pulse_counters()
	local DP = grug_mobs.depth_pulse
	if not DP then
		log("pulse counters: none (no depth pulse in this tree)")
		return
	end
	local keys = {}
	for k in pairs(DP.stats) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. DP.stats[k] end
	log(("pulse counters %s: %s; live arrivals %d"):format(variant,
		table.concat(parts, " "), #DP.arrivals))
end

local function census(label)
	if DEEP then return census_depth(label) end
	for _, point in ipairs(POINTS) do
		local center = {x = point.x, y = point.h, z = point.z}
		local budgeted, natural, other = 0, 0, 0
		local by_name = {}
		for _, object in ipairs(core.get_objects_inside_radius(center, 120)) do
			local ent = object:get_luaentity()
			local pos = object:get_pos()
			if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" and pos then
				local dx, dz = pos.x - point.x, pos.z - point.z
				if dx * dx + dz * dz <= RADIUS * RADIUS then
					if BUDGETED[ent.name] and not ent._grug_camp_pos and
							not ent._grug_rare_id then
						budgeted = budgeted + 1
						local short = ent.name:sub(11)
						by_name[short] = (by_name[short] or 0) + 1
					elseif mobs.spawning_mobs[ent.name] then
						natural = natural + 1
					else
						other = other + 1
					end
				end
			end
		end
		local names = {}
		for name, count in pairs(by_name) do names[#names + 1] = name .. "=" .. count end
		table.sort(names)
		log(("census %s %s %s budgeted=%d natural_other=%d other=%d level=%s [%s]"):format(
			variant, label, point.id, budgeted, natural, other,
			tostring(grug_zones.mob_level_at(center)), table.concat(names, " ")))
	end
end

local function run_window(clock, done)
	core.set_timeofday(clock == "day" and 0.5 or 0.0)
	log(("window %s %s start (%d s)"):format(variant, clock, WINDOW))
	for _, second in ipairs(CENSUS) do
		core.after(second, function()
			-- Hold the clock inside its phase for the whole window.
			core.set_timeofday(clock == "day" and 0.5 or 0.0)
			census(clock .. "@" .. second)
			if second == CENSUS[#CENSUS] then done() end
		end)
	end
	for s = 20, WINDOW - 1, 20 do
		core.after(s, function() core.set_timeofday(clock == "day" and 0.5 or 0.0) end)
	end
end

local function start_measuring()
	local players = {}
	for _, point in ipairs(POINTS) do
		players[#players + 1] = {x = point.x, y = point.h + 2, z = point.z}
		log(("point %s zone=%s level=%s"):format(point.id,
			tostring(grug_zones.id_at(point.x, point.z)),
			tostring(grug_zones.mob_level_at({x = point.x, y = point.h, z = point.z}))))
	end
	mobs._grug_probe_players = players
	if MODE == "pulse" then
		pulse_rooms()
		if grug_mobs.depth_pulse then
			local stand_ins = pulse_stand_ins()
			grug_mobs.depth_pulse.players = function() return stand_ins end
		end
		run_window("night", function()
			pulse_counters()
			log("RESULT DONE " .. variant)
			core.request_shutdown("r24 density probe done", false, 0)
		end)
		return
	end
	if MODE == "depth" then
		torch_room()
		run_window("night", function()
			log("RESULT DONE " .. variant)
			core.request_shutdown("r24 density probe done", false, 0)
		end)
		return
	end
	run_window("day", function()
		run_window("night", function()
			log("RESULT DONE " .. variant)
			core.request_shutdown("r24 density probe done", false, 0)
		end)
	end)
end

core.after(2, function()
	local areas = {}
	for _, point in ipairs(POINTS) do
		local minp = {x = point.x - 56, y = point.h - 32, z = point.z - 56}
		local maxp = {x = point.x + 55, y = point.h + 47, z = point.z + 55}
		if DEEP then
			minp.y, maxp.y = point.h - 40, point.h + 39
		end
		for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
		areas[#areas + 1] = {minp, maxp}
	end
	if MODE == "depth" then
		local r = TORCH_ROOM
		areas[#areas + 1] = {{x = r.x - r.half - 1, y = r.y - 1, z = r.z - r.half - 1},
			{x = r.x + r.half + 1, y = r.y + 4, z = r.z + r.half + 1}}
	end
	local pending = #areas
	local t0 = core.get_us_time()
	for _, area in ipairs(areas) do
		core.emerge_area(area[1], area[2], function(_, _, remaining)
			if remaining == 0 then
				pending = pending - 1
				if pending == 0 then
					log(("emerged %d areas in %.1f s"):format(#areas,
						(core.get_us_time() - t0) / 1e6))
					core.after(1, start_measuring)
				end
			end
		end)
	end
end)
