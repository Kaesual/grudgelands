-- Disposable engine probe (Round 85 lane BUILD): the arena "Breach Road" as
-- the engine generates it. Emerges the footprint with a margin, measures the
-- emerge time, checks every cell of the arena's model against the generated
-- nodes (as the seed fleet's arena_blocks does: present, ground under it,
-- nothing burying it) and logs the zones and biome families under it, then
-- announces six views for tools/r85_build/capture.sh. Never shipped. The
-- driver follows tools/r70_towns's probe.

local P = "[r85build] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r85build_settle") or "") or 5
local MARGIN = 40

local function log(msg) core.log("action", P .. msg) end

local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local L = dofile(wp40 .. "/breach_layout.lua")
local B = dofile(wp40 .. "/breach_model.lua")
local model = B.new(wp40)
local site = L.from_placement(grug_mapgen.wp40.placement_layout_text)
local world = L.world(site)

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r85build_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- A local point of the layout in world coordinates.
local function at(lx, ly, lz) return vector.new(site.x + lx, site.y + ly, site.z + lz) end

-- Stand (feet) at `from` and look at `to`.
local function view(player, from, to)
	player:set_pos(from)
	local eye = vector.offset(from, 0, 1.5, 0)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

-- The views (the draft's poses, tools/r84_arena_draft/sites.py poses(), feet
-- 1.5 below the draft's eye). The aerial comes last and lifts the zone's
-- clouds and fog for this one client (its camera would stand in the
-- Battlegrounds' cloud layer, and the far hall in the fog); every other view
-- shows the zone's own sky.
local SHOTS = {
	{name = "2_road_north", from = {0, 2.5, 58}, to = {0, 6, 0}},
	{name = "3_road_south", from = {0, 2.5, -58}, to = {0, 6, 0}},
	{name = "4_hall_accord", from = {32, 6.5, 10}, to = {39, 8.6, -2}},
	{name = "5_hall_throng", from = {-32, 6.5, -10}, to = {-39, 8.6, 2}},
	{name = "6_lookout", from = {23, 8, 27}, to = {-17, 4, 1}},
	{name = "1_aerial", from = {48, 58, 88}, to = {0, 2, 6}, clear = true},
}

-- The model against the generated nodes; the zones and families under it.
local function check_blocks()
	local q = grug_mapgen.wp40.planner_source
	local function family(x, z) return B.family((select(4, q.column_values_at(x, z)))) end
	local dressed = {}
	for _, g in ipairs(model.dressing) do
		local f = B.FAMILIES[family(site.x + g.x, site.z + g.z)]
		for _, cell in ipairs(g.cells[f.dress]) do
			dressed[(site.x + cell.x) .. "," .. (site.y + cell.y) .. "," .. (site.z + cell.z)] =
				cell.entry
		end
	end
	local missing, buried, floating, cells, shown = 0, 0, 0, 0, 0
	local zones, families = {}, {}
	local function note(text)
		if shown < 12 then log("mismatch " .. text) end
		shown = shown + 1
	end
	for _, c in ipairs(model.columns) do
		local x, z = site.x + c.lx, site.z + c.lz
		local _, _, zone, biome = q.column_values_at(x, z)
		zones[tostring(zone)] = (zones[tostring(zone)] or 0) + 1
		local fam = B.family(biome)
		families[fam] = (families[fam] or 0) + 1
		local under = core.get_node(vector.new(x, site.y - 1, z)).name
		local def = core.registered_nodes[under]
		if not def or not def.walkable then
			floating = floating + 1
			note(("ground under %d,%d,%d is %s"):format(x, site.y - 1, z, under))
		end
		for ly = 0, model.REACH do
			local y = site.y + ly
			local want = dressed[x .. "," .. y .. "," .. z] or c.cells[ly + 1]
			local node = core.get_node(vector.new(x, y, z))
			cells = cells + 1
			if want == nil or want == B.AIR then
				if node.name ~= "air" then
					buried = buried + 1
					note(("%s at %d,%d,%d where the arena has air"):format(node.name, x, y, z))
				end
			elseif want == B.KEEP then
				if node.name == "air" then
					missing = missing + 1
					note(("no rim surface at %d,%d,%d"):format(x, y, z))
				end
			else
				local e = model.entries[want]
				local name = e.role and B.FAMILIES[fam][e.role] or e.name
				if node.name ~= name or node.param2 ~= e.param2 then
					missing = missing + 1
					note(("%s %d at %d,%d,%d holds %s %d"):format(name, e.param2, x, y, z,
						node.name, node.param2))
				end
			end
		end
	end
	local zone_list, family_list = {}, {}
	for k, v in pairs(zones) do zone_list[#zone_list + 1] = k .. "=" .. v end
	for k, v in pairs(families) do family_list[#family_list + 1] = k .. "=" .. v end
	table.sort(zone_list)
	table.sort(family_list)
	log("zones under the footprint " .. table.concat(zone_list, " "))
	log("family columns " .. table.concat(family_list, " "))
	log(("arena cells %d: missing %d, buried %d, columns without ground %d"):format(cells,
		missing, buried, floating))
	log("RESULT " .. ((missing + buried + floating == 0) and "PASS" or "FAIL"))
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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		log(("site %d,%d datum %d reach %d"):format(site.x, site.z, site.y, site.reach))
		state.phase = "emerging"
		player:set_pos(at(0, 30, 0))
		local fp = world.footprint
		local t0 = core.get_us_time()
		core.emerge_area(vector.new(fp.min.x - MARGIN, site.y - 12, fp.min.z - MARGIN),
			vector.new(fp.max.x + MARGIN, site.y + model.REACH + 4, fp.max.z + MARGIN),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				log(("arena emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
				local ok, err = pcall(check_blocks)
				if not ok then log("RESULT FAIL check error " .. tostring(err)) end
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				state.phase = "shoot"
			end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			if shot.clear then
				player:set_clouds({density = 0})
				player:set_sky({fog = {fog_distance = 400, fog_start = 0.9}})
			end
			local ok, err = pcall(view, player, at(shot.from[1], shot.from[2], shot.from[3]),
				at(shot.to[1], shot.to[2], shot.to[3]))
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
