-- Disposable engine probe (Round 47 lane TA): a test patch of the tree shape
-- nodes for screenshots. Never shipped: tools/r47_ta/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is the Round 46 TREE
-- probe's (grug_probe_r46_tree, in git at de5c8400).
--
-- Three flat areas high in the sky (y = 500, every background is sky), 300
-- nodes apart. Every camera looks west (-x) with the morning sun behind it;
-- in a scene, u runs +z (left to right in the picture), v runs -x (away from
-- the camera), h is the height above the grass.
--   G  bark grain (handoff §4 check 1): limb rows of jungle (bark M) and
--      apple wood, a log, a base, branches and a twig, all at facedir 4 (grain
--      along the row, u); the same row above at facedir 0 (grain upright, the
--      wrong way, for contrast); a jungle row running away from the camera
--      at facedir 12 (grain along v).
--   Q  the quarter mesh (check 2): a 2 x 2 jungle trunk with a limb (base,
--      branch, twig, a leaf above the twig and one beside it) and two roots
--      at its foot (a base and a twig on the grass), a 3 x 3 apple trunk
--      (quarter corners, log edges and centre), a 2 x 2 apple trunk, a lone
--      standing quarter and five lying ones (facedir 4, 8, 12, 16, 20); a
--      2 x 2 jungle and a 2 x 2 apple trunk with one quarter dug out (Q6).
--   R  template rotation (check 4): one small cell set (a 2 x 2 apple quarter
--      trunk three high, a limb east, a twig north under a leaf, a root base
--      south) turned 0, 90, 180 and 270 degrees by the real
--      wp40/r6_templates.lua, left to right.

local P = "[r47ta] "
local NAME = "grugcap"
local GROUND_Y = 500
local SETTLE = tonumber(core.settings:get("r47ta_settle") or "") or 8
local FILTER = core.settings:get("r47ta_shots") or "G,Q,R"

local function log(msg) core.log("action", P .. msg) end

local HUBS = {G = 0, Q = 1, R = 2}
local origin -- set from the arrived player's position
local function hub(id)
	return {x = origin.x + HUBS[id] * 300, y = GROUND_Y, z = origin.z}
end
local U_MIN, U_MAX, V_MIN, V_MAX = -76, 40, -24, 24
local TIME_OF_DAY = 0.34

local function at(center, u, h, v)
	return {x = center.x - v, y = GROUND_Y + h, z = center.z + u}
end
local function scene_box(center, y1, y2)
	return {x = center.x - V_MAX, y = y1, z = center.z + U_MIN},
		{x = center.x - V_MIN, y = y2, z = center.z + U_MAX}
end
local function put(pos, name, param2)
	core.set_node(pos, {name = name, param2 = param2 or 0})
end

local GY, GZ, GX = 0, 4, 12 -- facedir: grain along y, z (u), x (v)
local SHAPES = grug_trees.shape_nodes

-- Probe-only quarters with the centre-row variant of the mesh
-- (tools/r47_ta/variant_obj.js), for the Q6v comparison.
local VARIANT = {}
for _, wood in ipairs({"jungle", "apple"}) do
	local def = table.copy(core.registered_nodes[SHAPES[wood].quarter])
	def.mesh = "r47ta_quarter_centre_row.obj"
	def.name, def.type, def.mod_origin = nil, nil, nil
	VARIANT[wood] = "grug_probe_r47_ta:" .. wood .. "_quarter_centre_row"
	core.register_node(VARIANT[wood], def)
end

-- A quarter's facedir for a trunk cell: facedir 0 has the trunk axis at
-- +x +z, each step turns (x, z) -> (z, -x).
local function quarter_facedir(dx, dz)
	if dx > 0 and dz > 0 then return 0 end
	if dx > 0 then return 1 end
	if dz < 0 then return 2 end
	return 3
end

-- A trunk of quarters (n = 2) or quarter corners around logs (n = 3) on the
-- world cells x0.., z0.., layers y1..y2.
local function trunk(wood, x0, z0, y1, y2, n, quarter)
	local log_name = grug_trees.shape_woods[wood].trunk
	local c = (n - 1) / 2
	for y = y1, y2 do
		for i = 0, n - 1 do
			for k = 0, n - 1 do
				local pos = {x = x0 + i, y = y, z = z0 + k}
				local corner = (i == 0 or i == n - 1) and (k == 0 or k == n - 1)
				if corner then
					put(pos, quarter or SHAPES[wood].quarter, quarter_facedir(c - i, c - k))
				else
					put(pos, log_name, GY)
				end
			end
		end
	end
end

-- One limb row along u from u0: log, base, three branches, twig, a leaf
-- above the twig.
local function limb_row(center, wood, u0, h, v, facedir)
	local s = SHAPES[wood]
	local names = {grug_trees.shape_woods[wood].trunk, s.base, s.branch, s.branch,
		s.branch, s.twig}
	for i, name in ipairs(names) do put(at(center, u0 + i - 1, h, v), name, facedir) end
	put(at(center, u0 + #names - 1, h + 1, v), grug_trees.shape_woods[wood].leaves)
end

local function build_ground(center)
	local p1, p2 = scene_box(center, GROUND_Y - 3, GROUND_Y)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(p1, p2)
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data = vm:get_data()
	local top = core.get_content_id("default:dirt_with_grass")
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

local function build_grain(c)
	limb_row(c, "jungle", -8, 3, 0, GZ)
	limb_row(c, "apple", 0, 3, 0, GZ)
	limb_row(c, "jungle", -8, 7, 0, GY)
	limb_row(c, "apple", 0, 7, 0, GY)
	-- away from the camera: log far, twig near
	local s = SHAPES.jungle
	local names = {"default:jungletree", s.base, s.branch, s.branch, s.branch, s.twig}
	for i, name in ipairs(names) do put(at(c, 10, 3, 5 - i), name, GX) end
	put(at(c, 10, 4, 0), "default:jungleleaves")
end

local function build_quarters(c)
	-- 2 x 2 jungle trunk on u -6..-5, v 0..1, six high
	local base = at(c, -6, 1, 1)
	trunk("jungle", base.x, base.z, base.y, base.y + 5, 2)
	local s = SHAPES.jungle
	-- a limb north (+z) from the trunk's x0 + 1 column at h 4
	put({x = base.x + 1, y = base.y + 3, z = base.z + 2}, s.base, GZ)
	put({x = base.x + 1, y = base.y + 3, z = base.z + 3}, s.branch, GZ)
	put({x = base.x + 1, y = base.y + 3, z = base.z + 4}, s.twig, GZ)
	put({x = base.x + 1, y = base.y + 4, z = base.z + 4}, "default:jungleleaves")
	put({x = base.x + 1, y = base.y + 3, z = base.z + 5}, "default:jungleleaves")
	-- roots towards the camera (+x): a base on the grass beside the quarter,
	-- then a twig diving into the grass
	put({x = base.x + 2, y = base.y, z = base.z}, s.base, GX)
	put({x = base.x + 3, y = base.y, z = base.z}, s.twig, GX)
	-- 3 x 3 apple trunk on u 2..4, v 0..2; a 2 x 2 apple trunk on u 8..9
	local b3 = at(c, 2, 1, 2)
	trunk("apple", b3.x, b3.z, b3.y, b3.y + 4, 3)
	local b2 = at(c, 8, 1, 1)
	trunk("apple", b2.x, b2.z, b2.y, b2.y + 3, 2)
	-- a lone standing quarter, its bark and slant towards the camera
	put(at(c, -11, 1, -2), s.quarter, 2)
	-- lying quarters
	for i, facedir in ipairs({4, 8, 12, 16, 20}) do
		put(at(c, 11 + 2 * i, 1, -2), s.quarter, facedir)
	end
	-- partly felled: a 2 x 2 jungle and a 2 x 2 apple trunk with the
	-- camera-side (+x, -z) quarter dug out two above the grass
	local cut2 = at(c, -22, 1, 1)
	trunk("jungle", cut2.x, cut2.z, cut2.y, cut2.y + 4, 2)
	core.remove_node({x = cut2.x + 1, y = cut2.y + 1, z = cut2.z})
	local cut3 = at(c, -33, 1, 1)
	trunk("apple", cut3.x, cut3.z, cut3.y, cut3.y + 4, 2)
	core.remove_node({x = cut3.x + 1, y = cut3.y + 1, z = cut3.z})
	-- the same two with the probe's centre-row variant of the mesh
	for i, wood in ipairs({"jungle", "apple"}) do
		local cut = at(c, -44 - 11 * i, 1, 1)
		trunk(wood, cut.x, cut.z, cut.y, cut.y + 4, 2, VARIANT[wood])
		core.remove_node({x = cut.x + 1, y = cut.y + 1, z = cut.z})
	end
end

-- The real template expander over one probe definition.
local templates
do
	local SX, SY, SZ = 5, 3, 4
	local s = SHAPES.apple
	local data = {}
	for i = 1, SX * SY * SZ do data[i] = {name = "air", prob = 254, param2 = 0} end
	local function cell(x, y, z, name, param2)
		data[z * SX * SY + y * SX + x + 1] = {name = name, prob = 254, param2 = param2 or 0}
	end
	for y = 0, 2 do
		for _, q in ipairs({{1, 1}, {2, 1}, {1, 2}, {2, 2}}) do
			cell(q[1], y, q[2], s.quarter,
				quarter_facedir(q[1] < 2 and 1 or -1, q[2] < 2 and 1 or -1))
		end
	end
	cell(2, 0, 0, s.base, GZ)
	cell(3, 1, 1, s.base, GX)
	cell(4, 1, 1, s.branch, GX)
	cell(1, 1, 3, s.twig, GZ)
	cell(1, 2, 3, "default:leaves", 0)
	local hash = {digest = function() return "" end, digest_count = function() return "" end,
		sha256_bytes = function(text) return text end, frame = tostring,
		hex = function() return "probe" end}
	local content = {
		content_contract = function()
			return {content_kind_masks = setmetatable({}, {__index = function() return 8 end}),
				resolve_r6 = function() return 1, 1 end, ignore_cid = 0}
		end,
		decorations = function()
			return {{id = "r47ta_probe", kind = "template", asset_or_node = "probe.mts",
				rule = "", settlement_class = 2}}
		end,
		param2_kind = function(ref) return ref == 2 and "none" or "facedir" end,
		content_ref = function(name) return name == "default:leaves" and 2 or 1 end,
	}
	local source = {read = function()
		return {size = {x = SX, y = SY, z = SZ},
			yslice_prob = {{ypos = 0, prob = 254}, {ypos = 1, prob = 254}, {ypos = 2, prob = 254}},
			data = data}
	end}
	templates = dofile(core.get_modpath("grug_mapgen") .. "/wp40/r6_templates.lua")(
		hash, content, source)
end

local function build_rotations(c)
	for rotation = 0, 3 do
		local record = templates.rotation("r47ta_probe", rotation)
		local o = at(c, -13 + rotation * 8, 1, 0)
		local rx, sy = record.size_x, record.size_y
		local list = {}
		for index, entry in ipairs(record.cells) do
			if entry.name ~= "air" then
				local i = index - 1
				local x = i % rx
				local y = math.floor(i / rx) % sy
				local z = math.floor(i / (rx * sy))
				put({x = o.x + x, y = o.y + y, z = o.z + z}, entry.name, entry.param2)
				if y == 1 then list[#list + 1] = entry.name:match(":(.*)") .. "@" .. x .. "," ..
					z .. "/" .. entry.param2 end
			end
		end
		log("CHECK rotation " .. rotation .. " layer 1: " .. table.concat(list, " "))
	end
end

local BUILD = {G = build_grain, Q = build_quarters, R = build_rotations}
local function build_scene(id)
	local center = hub(id)
	build_ground(center)
	BUILD[id](center)
	core.fix_light(scene_box(center, GROUND_Y - 3, GROUND_Y + 30))
	log("scene " .. id .. " built at " .. core.pos_to_string(center))
end

-- Camera at (u, h, v), looking west; pitch in degrees, positive looks down.
local SHOTS = {
	{name = "G1_grain_rows", hub = "G", u = 0, h = 5.5, v = -15, pitch = 6},
	{name = "G2_grain_close", hub = "G", u = -4, h = 5.5, v = -7, pitch = 8},
	{name = "Q1_quarters_eye", hub = "Q", u = 1, h = 3.5, v = -13, pitch = 6},
	{name = "Q2_jungle_trunk_close", hub = "Q", u = -3.5, h = 3.5, v = -6.5, pitch = 12},
	{name = "Q3_quarters_top", hub = "Q", u = 1, h = 17, v = -9, pitch = 58},
	{name = "Q4_lying_quarters", hub = "Q", u = 17, h = 3, v = -7, pitch = 18},
	{name = "Q6_cut_jungle_2x2", hub = "Q", u = -25, h = 2.6, v = -4, pitch = 6, yaw = 48},
	{name = "Q6_cut_apple_2x2", hub = "Q", u = -36, h = 2.6, v = -4, pitch = 6, yaw = 48},
	{name = "Q6v_cut_jungle_2x2_centre_row", hub = "Q", u = -58, h = 2.6, v = -4, pitch = 6, yaw = 48},
	{name = "Q6v_cut_apple_2x2_centre_row", hub = "Q", u = -69, h = 2.6, v = -4, pitch = 6, yaw = 48},
	{name = "R1_rotations_raised", hub = "R", u = 0, h = 10, v = -9, pitch = 45},
	{name = "R2_rotations_eye", hub = "R", u = 0, h = 3.5, v = -12, pitch = 8},
}
do
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
	local pos = at(hub(shot.hub), shot.u, shot.h, shot.v)
	return pos, shot.yaw or 90, shot.pitch
end

---------------------------------------------------------------------------
-- The driver (Round 46 TREE probe)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r47ta_ack", "r")
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

local function clear_objects(center)
	for _, object in ipairs(core.get_objects_inside_radius(center, 80)) do
		if not object:is_player() then object:remove() end
	end
end

local function hold(player, shot)
	local pos, yaw, pitch = camera_of(shot)
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
		local pos = vector.round(player:get_pos())
		origin = {x = pos.x, y = GROUND_Y, z = pos.z}
		log("character complete at " .. core.pos_to_string(pos))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 3
		for id in pairs(HUBS) do
			local p1, p2 = scene_box(hub(id), GROUND_Y - 8, GROUND_Y + 30)
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
		for _, id in ipairs({"G", "Q", "R"}) do build_scene(id) end
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
			log("SHOT " .. shot.name .. " at " ..
				core.pos_to_string(vector.round(camera_of(shot))))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited = 0
			state.logged = false
		end
	end
end)
