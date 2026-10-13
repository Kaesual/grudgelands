-- Disposable engine probe (Round 46 lane TREE): stages the tree prototype
-- for screenshots. Never shipped: tools/r46_tree/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client.
--
-- For the joining client it completes character creation through the real
-- receive-fields chain (Accord, Human, Warrior) once world preparation is
-- ready and the character has arrived. Then it builds five flat test areas
-- high in the sky (y = 500, far above any terrain, so nothing else grows
-- there and every background is sky), 300 nodes apart, one per scene:
--   A  the jungle row: today's jungle tree twice, four drafts, an acacia
--   B  the kapok row: today's emergent jungle tree, four drafts
--   C  the apple row: today's apple tree twice, four drafts
--   D  a troll grove: ten jungle drafts and two kapoks
--   E  a meadow grove: eight apple drafts
-- Today's trees are the vendored schematics placed as the engine places
-- them; the drafts are grug_treeproto's generator output as schematic
-- tables. It then moves the camera through the SHOTS list. Each shot logs
-- "SHOT <name>" when the view has had time to load, and waits until
-- capture.sh has written the name into <world>/r46tree_ack after its
-- screenshot. It also logs node and face counts (METRIC lines) of today's
-- schematics and of the drafts, and shuts the server down at the end.

local P = "[r46tree] "
local NAME = "grugcap"
local GROUND_Y = 500
local SETTLE = tonumber(core.settings:get("r46tree_settle") or "") or 8

local function log(msg) core.log("action", P .. msg) end

local T = grug_treeproto
local gen = T.generator
local default_path = core.get_modpath("default") .. "/schematics/"

---------------------------------------------------------------------------
-- The scenes
---------------------------------------------------------------------------

local HUBS = {A = 0, B = 1, C = 2, D = 3, E = 4}
local origin -- set from the arrived player's position

local function hub(id)
	return {x = origin.x + HUBS[id] * 300, y = GROUND_Y, z = origin.z}
end

-- Scenes are laid out in local coordinates: u runs along a row (left to
-- right in the picture), v away from the camera. Every camera looks west
-- (-x) with the morning sun behind it (the sun rises at +x,
-- src/client/sky.cpp getSunDirection), so the trees are lit from the front
-- and cast their shadows away from the camera: u is +z and v is -x.
local U_MIN, U_MAX, V_MIN, V_MAX = -64, 64, -48, 72
local TIME_OF_DAY = 0.34

local function world(center, u, v)
	return center.x - v, center.z + u
end

local function scene_box(center, y1, y2)
	return {x = center.x - V_MAX, y = y1, z = center.z + U_MIN},
		{x = center.x - V_MIN, y = y2, z = center.z + U_MAX}
end

local TODAY = {
	jungle = {file = "jungle_tree.mts", offset = 0},
	emergent = {file = "emergent_jungle_tree.mts", offset = -4},
	apple = {file = "apple_tree.mts", offset = 0},
	acacia = {file = "acacia_tree.mts", offset = 0},
}

-- Row layouts: x offsets along the row (the row stands at hub z + 10).
local ROWS = {
	A = {ground = "default:dirt_with_rainforest_litter", trees = {
		{today = "jungle", x = -40}, {today = "jungle", x = -28},
		{draft = "jungle", seed = 2, x = -12}, {draft = "jungle", seed = 12, x = 0},
		{draft = "jungle", seed = 18, x = 12}, {draft = "jungle", seed = 4, x = 24},
		{today = "acacia", x = 40}}},
	B = {ground = "default:dirt_with_rainforest_litter", trees = {
		{today = "emergent", x = -38},
		{draft = "kapok", seed = 6, x = -18}, {draft = "kapok", seed = 2, x = 0},
		{draft = "kapok", seed = 13, x = 18}, {draft = "kapok", seed = 12, x = 36}}},
	C = {ground = "default:dirt_with_grass", trees = {
		{today = "apple", x = -32}, {today = "apple", x = -22},
		{draft = "apple", seed = 3, x = -8}, {draft = "apple", seed = 7, x = 4},
		{draft = "apple", seed = 12, x = 16}, {draft = "apple", seed = 20, x = 28}}},
	D = {ground = "default:dirt_with_rainforest_litter", trees = {}},
	E = {ground = "default:dirt_with_grass", trees = {}},
}

-- The groves: seeded positions on a jittered grid, so they look planted by
-- nature rather than by a gardener.
do
	local spots = {
		{-30, -6}, {-18, 4}, {-8, -10}, {4, 2}, {14, -8}, {26, 6}, {-24, 18},
		{-6, 16}, {10, 20}, {28, 22},
	}
	for index, spot in ipairs(spots) do
		local row = ROWS.D.trees
		row[#row + 1] = {draft = "jungle", seed = 30 + index, x = spot[1], z = spot[2]}
	end
	ROWS.D.trees[#ROWS.D.trees + 1] = {draft = "kapok", seed = 21, x = -42, z = 14}
	ROWS.D.trees[#ROWS.D.trees + 1] = {draft = "kapok", seed = 22, x = 40, z = 24}
	local meadow = {{-24, -4}, {-12, 8}, {-2, -6}, {8, 10}, {18, -2}, {28, 12},
		{-18, 22}, {6, 26}}
	for index, spot in ipairs(meadow) do
		local row = ROWS.E.trees
		row[#row + 1] = {draft = "apple", seed = 40 + index, x = spot[1], z = spot[2]}
	end
end

local WOOD_OF = {jungle = "jungle", kapok = "jungle", apple = "oak"}
local built_trees = {} -- "<hub>:<index>" -> generated tree and its root

-- One flat area: grass (or litter) at GROUND_Y over five layers of dirt.
local function build_ground(center, ground)
	local p1, p2 = scene_box(center, GROUND_Y - 5, GROUND_Y)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(p1, p2)
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data = vm:get_data()
	local top = core.get_content_id(ground)
	local dirt = core.get_content_id("default:dirt")
	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			local vi = area:index(p1.x, y, z)
			for _ = p1.x, p2.x do
				data[vi] = y == GROUND_Y and top or dirt
				vi = vi + 1
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

local function place_tree(hub_id, index, spec, center)
	local gx, gz = world(center, spec.x, 10 + (spec.z or 0))
	if spec.today then
		local today = TODAY[spec.today]
		core.place_schematic({x = gx, y = GROUND_Y + 1 + today.offset, z = gz},
			default_path .. today.file, "0", nil, true,
			"place_center_x, place_center_z")
		return
	end
	local tree = gen.build(spec.draft, spec.seed)
	local schematic, offset = gen.to_schematic(tree, T.names(WOOD_OF[spec.draft]))
	core.place_schematic({x = gx + offset.x, y = GROUND_Y + offset.y,
		z = gz + offset.z}, schematic, "0", nil, true)
	built_trees[hub_id .. ":" .. index] = {tree = tree, x = gx, z = gz}
end

local function build_scene(id)
	local center = hub(id)
	local row = ROWS[id]
	build_ground(center, row.ground)
	for index, spec in ipairs(row.trees) do
		place_tree(id, index, spec, center)
	end
	core.fix_light(scene_box(center, GROUND_Y - 5, GROUND_Y + 40))
	log("scene " .. id .. " built at " .. core.pos_to_string(center) ..
		" trees=" .. #row.trees)
end

---------------------------------------------------------------------------
-- Numbers
---------------------------------------------------------------------------

local function describe(name)
	local def = core.registered_nodes[name] or {}
	local info = {wood = core.get_item_group(name, "tree") > 0}
	if def.drawtype == "allfaces_optional" or def.drawtype == "allfaces" then
		info.draw = "allfaces"
	elseif def.drawtype == "plantlike" then
		info.draw = "plantlike"
	elseif def.drawtype == "nodebox" then
		info.draw = "nodebox"
		info.shape = name:match("_([a-z]+)$")
		if def.connects_to then
			info.connects = {}
			for _, other in ipairs(def.connects_to) do info.connects[other] = true end
		end
	else
		info.draw = "normal"
	end
	return info
end

local function metric_line(label, counted, extra)
	local wood_names = {}
	for name, entry in pairs(counted.by_name) do
		wood_names[#wood_names + 1] = name .. "=" .. entry.nodes .. "/" .. entry.faces
	end
	table.sort(wood_names)
	log("METRIC " .. label .. " nodes=" .. counted.nodes .. " wood=" .. counted.wood ..
		" faces=" .. counted.faces .. " wood_faces=" .. counted.wood_faces ..
		" leaf_faces=" .. counted.leaf_faces .. (extra or "") .. " | " ..
		table.concat(wood_names, " "))
end

-- Today's schematics, anchored as the world generator anchors them: the
-- lowest occupied slice on the first node above the ground, the emergent
-- tree four nodes deeper (wp40/r6_templates.lua). Cells below the ground
-- are counted as buried wood, not drawn.
local function today_metrics()
	for _, key in ipairs({"jungle", "emergent", "apple", "acacia"}) do
		local today = TODAY[key]
		local s = core.read_schematic(default_path .. today.file, {})
		local sx, sy, sz = s.size.x, s.size.y, s.size.z
		local lowest
		local cells, buried, partial = {}, 0, 0
		for z = 0, sz - 1 do
			for y = 0, sy - 1 do
				for x = 0, sx - 1 do
					local node = s.data[(z * sy + y) * sx + x + 1]
					if node.name ~= "air" and node.prob > 0 then
						if not lowest or y < lowest then lowest = y end
					end
				end
			end
		end
		for z = 0, sz - 1 do
			for y = 0, sy - 1 do
				for x = 0, sx - 1 do
					local node = s.data[(z * sy + y) * sx + x + 1]
					if node.name ~= "air" and node.prob > 0 then
						local ry = today.offset == 0 and (y - lowest + 1) or (y + 1 + today.offset)
						if node.prob < 254 then partial = partial + 1 end
						if ry <= 0 then
							buried = buried + 1
						else
							cells[#cells + 1] = {x = x, y = ry, z = z, name = node.name,
								param2 = node.param2 or 0}
						end
					end
				end
			end
		end
		local counted = T.metrics.count(cells, describe)
		metric_line("today_" .. key .. " size=" .. sx .. "x" .. sy .. "x" .. sz,
			counted, " buried=" .. buried .. " probabilistic=" .. partial)
	end
end

local function draft_cells(tree)
	local names = T.names(WOOD_OF[tree.species])
	local cells = {}
	for index, cell in ipairs(tree.list) do
		cells[index] = {x = cell.x, y = cell.y, z = cell.z, name = names[cell.kind],
			param2 = cell.param2}
	end
	return cells
end

local function draft_metrics()
	for _, species in ipairs(gen.SPECIES_ORDER) do
		local total = {nodes = 0, wood = 0, faces = 0, wood_faces = 0, leaf_faces = 0}
		local kinds = {}
		local height, width = 0, 0
		local N = 100
		for seed = 1, N do
			local tree = gen.build(species, seed)
			local counted = T.metrics.count(draft_cells(tree), describe)
			for field in pairs(total) do total[field] = total[field] + counted[field] end
			for kind, n in pairs(tree.counts) do kinds[kind] = (kinds[kind] or 0) + n end
			local x1, x2, y2, z1, z2 = 99, -99, 0, 99, -99
			for _, c in ipairs(tree.list) do
				x1, x2 = math.min(x1, c.x), math.max(x2, c.x)
				z1, z2 = math.min(z1, c.z), math.max(z2, c.z)
				y2 = math.max(y2, c.y)
			end
			height = height + y2
			width = width + math.max(x2 - x1 + 1, z2 - z1 + 1)
		end
		local kind_list = {}
		for kind, n in pairs(kinds) do
			kind_list[#kind_list + 1] = kind .. "=" .. string.format("%.1f", n / N)
		end
		table.sort(kind_list)
		log(string.format("METRIC draft_%s mean_of=%d nodes=%.1f wood=%.1f faces=%.1f " ..
			"wood_faces=%.1f leaf_faces=%.1f height=%.1f width=%.1f | %s", species, N,
			total.nodes / N, total.wood / N, total.faces / N, total.wood_faces / N,
			total.leaf_faces / N, height / N, width / N, table.concat(kind_list, " ")))
	end
	-- the drafts in the pictures, one line each
	local ids = {}
	for id in pairs(built_trees) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local tree = built_trees[id].tree
		local counted = T.metrics.count(draft_cells(tree), describe)
		local params = {}
		for k, v in pairs(tree.params) do
			params[#params + 1] = k .. "=" .. (type(v) == "table" and table.concat(v, ",") or
				tostring(v))
		end
		table.sort(params)
		metric_line("draft_" .. tree.species .. "_seed" .. tree.seed .. " at=" .. id, counted,
			" params=" .. table.concat(params, ","))
	end
end

---------------------------------------------------------------------------
-- The shots
---------------------------------------------------------------------------

-- Camera at local (x = u, y above ground, z = v), looking along +v (west);
-- pitch in degrees, positive looks down.
local function tree_at(hub_id, index)
	local entry = built_trees[hub_id .. ":" .. index]
	return entry
end

local SHOTS = {
	{name = "A1_jungle_row_eye", hub = "A", x = 0, y = 1.6, z = -34, pitch = -8},
	{name = "A2_jungle_row_raised", hub = "A", x = 0, y = 16, z = -36, pitch = 16},
	{name = "A3_jungle_drafts_eye", hub = "A", x = 6, y = 1.6, z = -16, pitch = -10},
	{name = "A4_jungle_fork_close", hub = "A", tree = 4, close = "fork"},
	{name = "B1_kapok_row_eye", hub = "B", x = 0, y = 1.6, z = -44, pitch = -14},
	{name = "B2_kapok_row_raised", hub = "B", x = 0, y = 22, z = -42, pitch = 12},
	{name = "B3_kapok_drafts_eye", hub = "B", x = 9, y = 1.6, z = -30, pitch = -16},
	{name = "B4_kapok_3x3_base_close", hub = "B", tree = 2, close = "base"},
	{name = "B5_kapok_2x2_trunk_close", hub = "B", tree = 3, close = "trunk"},
	{name = "B6_kapok_crown_close", hub = "B", tree = 5, close = "crown"},
	{name = "C1_apple_row_eye", hub = "C", x = -2, y = 1.6, z = -28, pitch = -6},
	{name = "C2_apple_row_raised", hub = "C", x = -2, y = 14, z = -30, pitch = 18},
	{name = "C3_apple_drafts_eye", hub = "C", x = 10, y = 1.6, z = -12, pitch = -8},
	{name = "C4_apple_fork_close", hub = "C", tree = 4, close = "fork"},
	{name = "D1_troll_grove_raised", hub = "D", x = 0, y = 24, z = -44, pitch = 20},
	{name = "D2_troll_grove_eye", hub = "D", x = 2, y = 1.6, z = -22, pitch = -10},
	{name = "E1_meadow_grove_raised", hub = "E", x = 0, y = 18, z = -34, pitch = 22},
}

-- The camera of a close-up, from the tree's own parameters: in front of the
-- tree is +x (towards the row cameras), the view west (yaw 90).
local function close_camera(shot)
	local entry = tree_at(shot.hub, shot.tree)
	local p = entry.tree.params
	local tx, tz = entry.x + (p.top_x or 0), entry.z + (p.top_z or 0)
	if shot.close == "fork" then
		local fork_y = p.fork or p.trunk_h
		return {x = tx + 6, y = GROUND_Y + fork_y - 3, z = tz + 0.5}, 90, -28
	elseif shot.close == "base" then
		return {x = entry.x + 9, y = GROUND_Y + 2.5, z = entry.z + 0.5}, 90, -4
	elseif shot.close == "trunk" then
		return {x = entry.x + 8, y = GROUND_Y + 4, z = entry.z + 1}, 90, -12
	end
	-- the crown
	return {x = tx + 9, y = GROUND_Y + p.trunk_h - 6, z = tz + 0.5}, 90, -40
end

local function camera_of(shot)
	if shot.close then return close_camera(shot) end
	local center = hub(shot.hub)
	local x, z = world(center, shot.x, shot.z)
	return {x = x, y = GROUND_Y + shot.y, z = z}, 90, shot.pitch
end

---------------------------------------------------------------------------
-- The driver
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r46tree_ack", "r")
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
	-- no own model, so no own shadow in the raised views
	player:set_properties({is_visible = false, show_on_minimap = false,
		visual_size = {x = 0, y = 0, z = 0}})
end

local function clear_objects(center)
	for _, object in ipairs(core.get_objects_inside_radius(center, 120)) do
		if not object:is_player() then object:remove() end
	end
end

local function hold(player, shot)
	local pos, yaw, pitch = camera_of(shot)
	-- the eye is 1.625 above the feet (player_api's default model)
	player:set_pos({x = pos.x, y = pos.y - 1.625, z = pos.z})
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(pitch))
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
		local at = vector.round(player:get_pos())
		origin = {x = at.x, y = GROUND_Y, z = at.z}
		log("character complete at " .. core.pos_to_string(at))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		-- Five separate boxes, not one 1300-long one: only the scenes emerge.
		state.pending = 5
		for id in pairs(HUBS) do
			local p1, p2 = scene_box(hub(id), GROUND_Y - 8, GROUND_Y + 40)
			core.emerge_area(p1, p2, function(_, _, remaining)
					if remaining == 0 then
						state.pending = state.pending - 1
						log("emerged " .. id)
					end
				end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		for _, id in ipairs({"A", "B", "C", "D", "E"}) do build_scene(id) end
		today_metrics()
		draft_metrics()
		hide_hud(player)
		state.phase = "shoot"
		state.shot = 1
		state.waited = 0
		state.logged = false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		core.set_timeofday(TIME_OF_DAY)
		clear_objects(hub(shot.hub))
		hold(player, shot)
		hide_hud(player)
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local pos = camera_of(shot)
			log("SHOT " .. shot.name .. " at " .. core.pos_to_string(vector.round(pos)))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited = 0
			state.logged = false
		end
	end
end)
