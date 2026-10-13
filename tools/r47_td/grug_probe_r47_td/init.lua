-- Disposable engine probe (Round 47 lane TD): forest render cost. Never
-- shipped: tools/r47_td/measure.sh stages it through tools/luanti_headless.sh
-- and connects one real client, which it measures. The character driver
-- (creation, camera, HUD off) is lane TC's probe's (tools/r47_tc), from the
-- Round 46 TREE probe.
--
-- Mode "forest" (setting r47td_mode): one species (r47td_species) on a sky
-- platform (160 x 160 grass, 5 deep, at y 600 over 0,0, so nothing of the
-- world is in view). The forest stands on its middle 128 x 128 columns.
-- Scenes, in this order (r47td_scenes picks some):
--   empty     the platform alone (the baseline)
--   today     today's schematic (the vendored default trees; gravewood's
--             old tall MTS; silverwood = aspen with silverwood nodes; pine
--             half pine_tree, half small_pine_tree; kapok = the emergent
--             jungle tree 4 deep), N_TODAY trees, each tree's x/z box free
--             of every other box (the world writer's rule before TC's
--             follow-up: an accepted tree reserves its whole box)
--   new_main  the generated trees (wp40/tree_templates.lua, 32 variants,
--             kapok 16), N_MAIN trees (the density main's writer gives,
--             tools/r47_td/density.lua), boxes as above
--   new50, new75   the generated trees at N_TODAY with the crowns trimmed to
--             50 % and 75 % of their leaves: per variant the leaves farthest
--             from any wood cell go first (ties by a position hash); fruit
--             stays
--   new       the generated trees at N_TODAY, only wood reserved: a tree is
--             refused when one of its wood cells (trunk, quarter, limb,
--             root) comes within one node of another tree's wood; leaves
--             go only into air, so crowns interleave
--   grove     "new" plus a dense grove: the middle 48 x 48 columns packed
--             with more generated trees by the same wood rule until 400
--             candidates in a row fail
-- Every scene uses the same candidate positions (a PcgRandom stream per
-- species), so the scenes differ only by tree, count and rule. Trunks keep
-- off the middle 3 x 3 columns and the leaves of the inside camera's cells
-- are cleared.
-- Per scene: BUILT, then (after the driver's "<scene>:go") the wide view W
-- (camera 24 nodes outside the forest's west edge, 22 up, looking east,
-- 18 degrees down) for r47td_w seconds, a screenshot ("<scene>:shot"), then
-- the inside view I (the middle, eye height, one full turn in r47td_i
-- seconds), and the top view T (150 over the middle, straight down, 3 s:
-- the whole forest in view, for the vertices per tree).
--
-- Mode "capital": the capital r47td_capital (a settlement key, default
-- highcourt): W from 35 over its anchor's ground, 45 south, looking north 35
-- degrees down; I one full turn 14 over the anchor's ground, 12 down.

local P = "[r47td] "
local NAME = "grugcap"
local function setting(name, default)
	local value = core.settings:get("r47td_" .. name)
	if value == nil or value == "" then return default end
	return value
end
local MODE = setting("mode", "forest")
local SPECIES = setting("species", "apple")
local SCENES = setting("scenes", MODE == "capital" and "capital" or
	"empty,today,new_main,new50,new75,new,grove")
local CAPITAL = setting("capital", "highcourt")
local W_SECONDS = tonumber(setting("w", "6"))
local I_SECONDS = tonumber(setting("i", "10"))
local ACK_TIMEOUT = 90
local TIME_OF_DAY = 0.42
local SKY_Y = 600
local C = {x = 0, z = 0}
local PLATFORM = 80   -- half size
local FOREST = 64     -- half size
local GROVE = 24      -- half size

local function log(msg) core.log("action", P .. msg) end

-- Trees per 1000 land columns in the species' home biome, from
-- tools/r47_td/density.lua over seeds 12345 (3 chunks per biome) and
-- 17713522922938657774 (4), pooled: today = the commit before lane TC's
-- merge (e65bf60a), main = 046d1699. Home biomes: apple, aspen deep forest;
-- silverwood elf forest; jungle jungle edge + fringe; kapok fringe;
-- acacia savanna; pine pine hills; gravewood bone forest. Times 16.384
-- (the forest's 128 x 128 columns) gives the counts.
local DENSITY = {
	apple = {4.05, 1.50}, aspen = {1.43, 2.21}, silverwood = {2.40, 1.45},
	jungle = {6.05, 2.60}, kapok = {0.55, 0.12}, acacia = {0.78, 0.49},
	pine = {3.07, 2.87}, gravewood = {2.13, 0.67},
}
local function count(per_1000, override)
	local n = tonumber(setting(override, ""))
	if n then return n end
	return math.max(1, math.floor(per_1000 * 16.384 + 0.5))
end
local N_TODAY = count(DENSITY[SPECIES] and DENSITY[SPECIES][1] or 1, "n_today")
local N_MAIN = count(DENSITY[SPECIES] and DENSITY[SPECIES][2] or 1, "n_main")

-- Today's schematics (copies in this probe's schematics/, from
-- mods/BASE/default/schematics and tools/r46_tree/concept/today).
local MODPATH = core.get_modpath(core.get_current_modname())
local TODAY = {
	apple = {{"apple_tree.mts"}},
	jungle = {{"jungle_tree.mts"}},
	kapok = {{"emergent_jungle_tree.mts", dy = -4}},
	acacia = {{"acacia_tree.mts"}},
	pine = {{"pine_tree.mts"}, {"small_pine_tree.mts"}},
	aspen = {{"aspen_tree.mts"}},
	silverwood = {{"aspen_tree.mts", replacements = {
		["default:aspen_tree"] = "grug_trees:silverwood_tree",
		["default:aspen_leaves"] = "grug_trees:silverwood_leaves"}}},
	gravewood = {{"grug_gravewood_tall.mts"}},
}

---------------------------------------------------------------------------
-- The generated trees
---------------------------------------------------------------------------

local trees
local function tree_templates()
	if not trees then
		local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
		trees = dofile(wp40 .. "/tree_templates.lua")(dofile(wp40 .. "/treegen.lua"))
	end
	return trees
end

local function hash01(x, y, z)
	local d = core.sha256(x .. "," .. y .. "," .. z, true)
	return (d:byte(1) * 256 + d:byte(2)) / 65536
end

-- The variants of a species: cells, wood cells, bounds, and per kept share
-- the leaf cells to drop.
local function variants(key)
	local T = tree_templates()
	local row = T.BY_KEY[key]
	local list = {}
	for k = 1, row.count do
		local seed = T.seed_from_digest(core.sha256("r47td:" .. key .. ":" .. k, true))
		local cells = T.tree(key, seed)
		local v = {cells = cells, wood = {}, min_x = 0, max_x = 0, min_z = 0, max_z = 0,
			leaves = 0, drop = {}}
		local leaves = {}
		for _, cell in ipairs(cells) do
			if cell.x < v.min_x then v.min_x = cell.x end
			if cell.x > v.max_x then v.max_x = cell.x end
			if cell.z < v.min_z then v.min_z = cell.z end
			if cell.z > v.max_z then v.max_z = cell.z end
			if cell.flag ~= T.LEAF then v.wood[#v.wood + 1] = cell
			elseif cell.name == row.leaves then leaves[#leaves + 1] = cell end
		end
		v.leaves = #leaves
		for _, leaf in ipairs(leaves) do
			local best = math.huge
			for _, w in ipairs(v.wood) do
				local dx, dy, dz = leaf.x - w.x, leaf.y - w.y, leaf.z - w.z
				local d = dx * dx + dy * dy + dz * dz
				if d < best then best = d end
			end
			leaf.rank = best + hash01(leaf.x, leaf.y, leaf.z) * 0.5
		end
		table.sort(leaves, function(a, b) return a.rank > b.rank end)
		for _, share in ipairs({0.75, 0.5}) do
			local drop = {}
			local n = #leaves - math.floor(#leaves * share + 0.5)
			for i = 1, n do drop[leaves[i]] = true end
			v.drop[share] = drop
		end
		list[k] = v
	end
	return list
end

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------

local function candidates(n)
	local rng = PcgRandom(tonumber(core.sha256("r47td:" .. SPECIES):sub(1, 7), 16))
	local list = {}
	for i = 1, n do
		list[i] = {x = rng:next(C.x - FOREST, C.x + FOREST - 1),
			z = rng:next(C.z - FOREST, C.z + FOREST - 1), k = rng:next(0, 1023),
			r = rng:next(0, 3)}
	end
	return list
end
local CANDIDATES = candidates(20000)

local function inside(x0, x1, z0, z1, half)
	return x0 >= C.x - half and x1 <= C.x + half - 1 and z0 >= C.z - half and
		z1 <= C.z + half - 1
end
local function overlaps(boxes, b)
	for _, o in ipairs(boxes) do
		if b[1] <= o[2] and o[1] <= b[2] and b[3] <= o[4] and o[3] <= b[4] then return true end
	end
	return false
end
local function near_middle(x, z) return math.abs(x - C.x) <= 1 and math.abs(z - C.z) <= 1 end

-- today: {pos, file, rotation, replacements}
local schematic_size = {}
local function plan_today(n)
	local placed, boxes = {}, {}
	for _, c in ipairs(CANDIDATES) do
		if #placed >= n then break end
		local kinds = TODAY[SPECIES]
		local kind = kinds[c.k % #kinds + 1]
		local path = MODPATH .. "/schematics/" .. kind[1]
		if not schematic_size[path] then
			schematic_size[path] = core.read_schematic(path, {}).size
		end
		local size = schematic_size[path]
		local sx, sz = size.x, size.z
		if c.r % 2 == 1 then sx, sz = sz, sx end
		local x0, z0 = c.x - math.floor((sx - 1) / 2), c.z - math.floor((sz - 1) / 2)
		local box = {x0, x0 + sx - 1, z0, z0 + sz - 1}
		if inside(box[1], box[2], box[3], box[4], FOREST) and not overlaps(boxes, box) and
				math.abs(c.x - C.x) + math.abs(c.z - C.z) > 3 then
			boxes[#boxes + 1] = box
			placed[#placed + 1] = {pos = {x = c.x, y = SKY_Y + 1 + (kind.dy or 0), z = c.z},
				path = path, rotation = tostring(c.r * 90), replacements = kind.replacements or {}}
		end
	end
	return placed
end

-- new: {x, z, v}; rule "box" or "wood"; `wood` (shared between calls) holds
-- the reserved wood columns as "x,z" -> true.
local function plan_new(list, n, rule, half, wood, boxes, start, give_up)
	local placed, misses = {}, 0
	for i = start or 1, #CANDIDATES do
		if #placed >= n or (give_up and misses >= give_up) then break end
		local c = CANDIDATES[i]
		local v = list[c.k % #list + 1]
		local x, z = c.x, c.z
		if half < FOREST then
			x = C.x + (x - C.x) % (2 * half) - half
			z = C.z + (z - C.z) % (2 * half) - half
		end
		local box = {x + v.min_x, x + v.max_x, z + v.min_z, z + v.max_z}
		local ok = inside(box[1], box[2], box[3], box[4], FOREST)
		if ok then
			for _, w in ipairs(v.wood) do
				if near_middle(x + w.x, z + w.z) then ok = false break end
			end
		end
		if ok and rule == "box" then
			ok = not overlaps(boxes, box)
		elseif ok then
			for _, w in ipairs(v.wood) do
				if wood[(x + w.x) .. "," .. (z + w.z)] then ok = false break end
			end
		end
		if ok then
			misses = 0
			boxes[#boxes + 1] = box
			for _, w in ipairs(v.wood) do
				for dx = -1, 1 do
					for dz = -1, 1 do wood[(x + w.x + dx) .. "," .. (z + w.z + dz)] = true end
				end
			end
			placed[#placed + 1] = {x = x, z = z, v = v}
		else
			misses = misses + 1
		end
	end
	return placed
end

---------------------------------------------------------------------------
-- Building a scene
---------------------------------------------------------------------------

local P1 = {x = C.x - PLATFORM, y = SKY_Y - 4, z = C.z - PLATFORM}
local P2 = {x = C.x + PLATFORM - 1, y = SKY_Y + 48, z = C.z + PLATFORM - 1}
local VARIANTS

local function build(scene)
	local started = core.get_us_time()
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(P1, P2)
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data, param2 = vm:get_data(), vm:get_param2_data()
	local AIR = core.get_content_id("air")
	local GRASS, DIRT = core.get_content_id("default:dirt_with_grass"),
		core.get_content_id("default:dirt")
	for z = P1.z, P2.z do
		for y = P1.y, P2.y do
			local index = area:index(P1.x, y, z)
			local id = y == SKY_Y and GRASS or (y < SKY_Y and DIRT or AIR)
			for _ = P1.x, P2.x do
				data[index], param2[index] = id, 0
				index = index + 1
			end
		end
	end
	local info = {trees = 0, cells = 0, leaves = 0}
	local new_trees = {}
	if scene ~= "empty" and scene ~= "today" then
		VARIANTS = VARIANTS or variants(SPECIES)
		local wood, boxes = {}, {}
		if scene == "new_main" then
			new_trees = plan_new(VARIANTS, N_MAIN, "box", FOREST, wood, boxes)
		else
			new_trees = plan_new(VARIANTS, N_TODAY, "wood", FOREST, wood, boxes)
			if scene == "grove" then
				local extra = plan_new(VARIANTS, 100000, "wood", GROVE, wood, boxes, 1, 400)
				info.grove = #extra
				for _, t in ipairs(extra) do new_trees[#new_trees + 1] = t end
			end
		end
		local share = scene == "new50" and 0.5 or (scene == "new75" and 0.75 or nil)
		local ids = {}
		local T = tree_templates()
		for _, t in ipairs(new_trees) do
			local drop = share and t.v.drop[share] or {}
			for _, cell in ipairs(t.v.cells) do
				if not drop[cell] then
					local index = area:index(t.x + cell.x, SKY_Y + 1 + cell.y, t.z + cell.z)
					local id = ids[cell.name]
					if not id then id = core.get_content_id(cell.name); ids[cell.name] = id end
					if cell.flag ~= T.LEAF or data[index] == AIR then
						data[index], param2[index] = id, cell.param2
						info.cells = info.cells + 1
						if cell.flag == T.LEAF then info.leaves = info.leaves + 1 end
					end
				end
			end
		end
		info.trees = #new_trees
	end
	vm:set_data(data)
	vm:set_param2_data(param2)
	if scene == "today" then
		local list = plan_today(N_TODAY)
		for _, t in ipairs(list) do
			core.place_schematic_on_vmanip(vm, t.pos, t.path, t.rotation, t.replacements, false,
				"place_center_x, place_center_z")
		end
		info.trees = #list
	end
	vm:write_to_map(true)
	-- the inside camera's cells
	for dx = -1, 1 do
		for dz = -1, 1 do
			for dy = 1, 3 do
				local pos = {x = C.x + dx, y = SKY_Y + dy, z = C.z + dz}
				if core.get_node(pos).name ~= "air" then core.remove_node(pos) end
			end
		end
	end
	if scene == "today" then
		-- count what the schematics placed (they have random leaves)
		local names = {}
		for _, kind in ipairs(TODAY[SPECIES]) do
			for _, node in ipairs(core.read_schematic(MODPATH .. "/schematics/" .. kind[1], {}).data) do
				local name = (kind.replacements or {})[node.name] or node.name
				if name ~= "air" and name ~= "ignore" then names[name] = true end
			end
		end
		local list = {}
		for name in pairs(names) do list[#list + 1] = name end
		local _, counts = core.find_nodes_in_area({x = P1.x, y = SKY_Y + 1 - 4, z = P1.z},
			{x = P2.x, y = P2.y, z = P2.z}, list)
		for name, n in pairs(counts) do
			info.cells = info.cells + n
			if core.get_item_group(name, "leaves") > 0 then info.leaves = info.leaves + n end
		end
	end
	log(("BUILT %s trees=%d grove=%s cells=%d leaves=%d build_ms=%d"):format(scene, info.trees,
		tostring(info.grove or 0), info.cells, info.leaves,
		math.floor((core.get_us_time() - started) / 1000)))
end

---------------------------------------------------------------------------
-- The driver
---------------------------------------------------------------------------

local scenes = {}
for name in SCENES:gmatch("[^,]+") do scenes[#scenes + 1] = name end

-- camera: pos (eye), yaw (degrees, 0 looks +z, 90 looks -x), pitch (down)
local CAM = {}
local function forest_cameras()
	CAM.W = {pos = {x = C.x - FOREST - 24, y = SKY_Y + 1 + 22, z = C.z}, yaw = 270, pitch = 18}
	CAM.I = {pos = {x = C.x, y = SKY_Y + 1 + 1.625, z = C.z}, yaw = 0, pitch = 0, turn = true}
	CAM.T = {pos = {x = C.x, y = SKY_Y + 1 + 150, z = C.z}, yaw = 0, pitch = 90}
end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r47td_ack", "r")
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
	for _, object in ipairs(core.get_objects_inside_radius(center, 120)) do
		if not object:is_player() then object:remove() end
	end
end

local function hold(player, cam, t)
	player:set_pos({x = cam.pos.x, y = cam.pos.y - 1.625, z = cam.pos.z})
	local yaw = cam.yaw
	if cam.turn then yaw = yaw + 360 * math.min(1, t / I_SECONDS) end
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(cam.pitch))
end

local function find_capital()
	local records = grug_core.settlement_socket_settlements()
	local found
	for _, record in ipairs(records) do
		log("settlement " .. record.key .. " at " .. core.pos_to_string(record.anchor))
		if record.key == CAPITAL then found = record.anchor end
	end
	return found
end

local function ground_at(x, z, top, bottom)
	for y = top, bottom, -1 do
		local def = core.registered_nodes[core.get_node({x = x, y = y, z = z}).name]
		if def and def.walkable then return y end
	end
	return bottom
end

local function next_scene()
	state.scene_index = state.scene_index + 1
	local scene = scenes[state.scene_index]
	if not scene then
		state.phase = "done"
		log("shutdown")
		core.request_shutdown("probe done", false, 0)
		return
	end
	state.scene = scene
	if MODE == "forest" then build(scene)
	else log(("BUILT %s capital=%s"):format(scene, CAPITAL)) end
	state.phase, state.t = "settle", 0
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" or state.phase == "emerge" then
		if state.clock < 0.5 then return end
		state.clock = 0
	end
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
		log("character complete at " .. core.pos_to_string(vector.round(player:get_pos())))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		local p1, p2
		if MODE == "capital" then
			local anchor = find_capital()
			if not anchor then
				log("ERROR no capital " .. CAPITAL)
				core.request_shutdown("probe failed", false, 0)
				state.phase = "done"
				return
			end
			state.anchor = anchor
			p1 = {x = anchor.x - 112, y = anchor.y - 32, z = anchor.z - 112}
			p2 = {x = anchor.x + 112, y = anchor.y + 80, z = anchor.z + 112}
			-- park the player over the capital while it emerges
			player:set_pos({x = anchor.x, y = anchor.y + 60, z = anchor.z})
		else
			forest_cameras()
			p1 = {x = C.x - PLATFORM - 32, y = SKY_Y - 16, z = C.z - PLATFORM - 32}
			p2 = {x = C.x + PLATFORM + 32, y = SKY_Y + 64, z = C.z + PLATFORM + 32}
			hold(player, CAM.W, 0)
		end
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = true
		core.emerge_area(p1, p2, function(_, _, remaining)
			if remaining == 0 then state.pending = false end
		end)
		log(("mode %s species %s n_today %d n_main %d scenes %s"):format(MODE, SPECIES,
			N_TODAY, N_MAIN, SCENES))
	elseif state.phase == "emerge" then
		if state.pending then return end
		log(("emerge done in %.1f s"):format((core.get_us_time() - state.emerge_started) / 1e6))
		if MODE == "capital" then
			local a = state.anchor
			local g = ground_at(a.x, a.z, a.y + 70, a.y - 30)
			log("capital ground " .. g)
			CAM.W = {pos = {x = a.x, y = g + 35, z = a.z - 45}, yaw = 0, pitch = 35}
			CAM.I = {pos = {x = a.x, y = g + 14, z = a.z}, yaw = 0, pitch = 12, turn = true}
			CAM.T = {pos = {x = a.x, y = g + 150, z = a.z}, yaw = 0, pitch = 90}
		end
		hide_hud(player)
		state.scene_index = 0
		log("READY")
		next_scene()
	elseif state.phase ~= "done" then
		state.t = state.t + dtime
		core.set_timeofday(TIME_OF_DAY)
		local cam = (state.phase == "I" or state.phase == "I_wait") and CAM.I or
			((state.phase == "T" or state.phase == "T_wait") and CAM.T or CAM.W)
		clear_objects(cam.pos)
		hold(player, cam, state.phase == "I" and state.t or 0)
		local scene = state.scene
		if state.phase == "settle" then
			if read_ack() == scene .. ":go" or state.t > ACK_TIMEOUT then
				if state.t > ACK_TIMEOUT then log("ack timeout " .. scene .. ":go") end
				state.phase, state.t = "W", 0
				log("BEGIN " .. scene .. " W")
			end
		elseif state.phase == "W" then
			if state.t >= W_SECONDS then
				log("END " .. scene .. " W")
				state.phase, state.t = "shot", 0
			end
		elseif state.phase == "shot" then
			if read_ack() == scene .. ":shot" or state.t > ACK_TIMEOUT then
				state.phase, state.t = "I_wait", 0
			end
		elseif state.phase == "I_wait" then
			if state.t >= 2 then
				state.phase, state.t = "I", 0
				log("BEGIN " .. scene .. " I")
			end
		elseif state.phase == "I" then
			if state.t >= I_SECONDS then
				log("END " .. scene .. " I")
				state.phase, state.t = "T_wait", 0
			end
		elseif state.phase == "T_wait" then
			if state.t >= 2 then
				state.phase, state.t = "T", 0
				log("BEGIN " .. scene .. " T")
			end
		elseif state.phase == "T" then
			if state.t >= 3 then
				log("END " .. scene .. " T")
				next_scene()
			end
		end
	end
end)
