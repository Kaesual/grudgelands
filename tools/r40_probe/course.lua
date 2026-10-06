-- Round 40 lane V4: the test courses in the live world, the target dummy and
-- the striker. A course is built next to the caster from temporary probe
-- nodes and removed again with `/psetup clear` (the replaced nodes are kept
-- in mod storage, so a restart does not lose them). Every node it would
-- touch must be alterable world (grug_core.world_alterable: never a town,
-- capital, start or POI), outside any world feature (roads, villages,
-- camps), loaded, not liquid, without metadata, and no falling node may
-- rest on top; otherwise the course is refused and nothing changes.

return function(P)
local MOD, shapes = P.MOD, P.shapes
local course = {}
P.course = course

local storage = core.get_mod_storage()
local floor = math.floor

local function tile(color)
	return "default_stone.png^[colorize:" .. color .. ":140"
end
local node_def = {
	groups = {cracky = 3, not_in_creative_inventory = 1},
	is_ground_content = false, drop = "",
}
local function node(name, extra)
	local def = {}
	for k, v in pairs(node_def) do def[k] = v end
	for k, v in pairs(extra) do def[k] = v end
	core.register_node(MOD .. ":" .. name, def)
end
node("floor", {description = "R40 probe floor", tiles = {tile("#3a6ea5")}})
node("wall", {description = "R40 probe wall", tiles = {tile("#a5503a")}})
node("low_wall", {description = "R40 probe low wall (1.25 m)", tiles = {tile("#c08a3a")},
	drawtype = "nodebox", paramtype = "light",
	node_box = {type = "fixed", fixed = shapes.LOW_WALL_BOX}})
local NODE = {floor = MOD .. ":floor", wall = MOD .. ":wall",
	low_wall = MOD .. ":low_wall", air = "air"}

-- The dummy is a 0.6 x 1.7 block with its feet at pos.y - 0.85; Charge
-- reads its collision box exactly like a mob's (kits.lua: target pos plus
-- collisionbox[2] are the feet).
local function block_entity(name, color, tag)
	local texture = "default_wood.png^[colorize:" .. color .. ":150"
	core.register_entity(MOD .. ":" .. name, {
		initial_properties = {
			physical = false, static_save = false,
			visual = "cube", visual_size = {x = 0.6, y = 1.7, z = 0.6},
			textures = {texture, texture, texture, texture, texture, texture},
			collisionbox = {-0.3, -0.85, -0.3, 0.3, 0.85, 0.3},
			selectionbox = {-0.3, -0.85, -0.3, 0.3, 0.85, 0.3},
			nametag = tag, hp_max = 1000,
		},
		on_activate = function(self)
			self.object:set_armor_groups({immortal = 1})
		end,
		on_punch = function() return true end,
	})
end
block_entity("dummy", "#2a8a3a", "probe target")
block_entity("striker", "#b02020", "striker")

local state = {} -- player name -> {target, striker, start, yaw}

local function valid(obj)
	return obj and obj:get_pos() ~= nil
end

function course.target(name)
	local st = state[name]
	return st and valid(st.target) and st.target or nil
end
function course.striker(name)
	local st = state[name]
	return st and valid(st.striker) and st.striker or nil
end

-- Spawn `mob` (a registered entity name) or the probe entity with its feet
-- at `feet`; returns the object or nil and a reason.
local function spawn(feet, probe_name, mob)
	local name = mob or (MOD .. ":" .. probe_name)
	local def = core.registered_entities[name]
	if not def then return nil, "no entity named " .. name end
	local props = def.initial_properties or def
	local box = props.collisionbox or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
	local obj = core.add_entity(vector.offset(feet, 0, -box[2], 0), name)
	if not obj then return nil, "add_entity failed for " .. name end
	return obj
end

local function remove_entities(st)
	if not st then return end
	for _, key in ipairs({"target", "striker"}) do
		if valid(st[key]) then st[key]:remove() end
		st[key] = nil
	end
end

-- The caster's facing, snapped to the nearest axis: unit (dx, dz).
local function axis(player)
	local dir = core.yaw_to_dir(player:get_look_horizontal())
	if math.abs(dir.x) > math.abs(dir.z) then
		return dir.x > 0 and 1 or -1, 0
	end
	return 0, dir.z > 0 and 1 or -1
end

-- Highest standing spot in the column at (x, z) between y + 4 and y - 8:
-- a walkable node with two passable nodes above. nil if none is loaded.
local function ground(x, y, z)
	for ny = floor(y + 0.5) + 4, floor(y + 0.5) - 8, -1 do
		local below = core.get_node_or_nil({x = x, y = ny - 1, z = z})
		local def = below and core.registered_nodes[below.name]
		if def and def.walkable then
			local free = true
			for k = 0, 1 do
				local n = core.get_node_or_nil({x = x, y = ny + k, z = z})
				local d = n and core.registered_nodes[n.name]
				if not d or d.walkable then free = false end
			end
			if free then return ny - 0.5 end
		end
	end
	return nil
end

-- Why `pos` may not be changed by the probe, or nil.
local function refusal(pos)
	local n = core.get_node_or_nil(pos)
	if not n or n.name == "ignore" then return "not loaded" end
	if not grug_core.world_alterable(pos) then
		return "not alterable (town, start, capital, POI or other guarded ground)"
	end
	if grug_core.world_feature_at and grug_core.world_feature_at(pos) ~= nil then
		return "inside a world feature (road, village, camp ...)"
	end
	local def = core.registered_nodes[n.name]
	if def and def.liquidtype and def.liquidtype ~= "none" then return "liquid" end
	if n.name ~= "air" then
		local meta = core.get_meta(pos):to_table()
		if next(meta.fields or {}) or next(meta.inventory or {}) then
			return "a node with metadata"
		end
	end
	return nil
end

function course.clear(name)
	remove_entities(state[name])
	state[name] = nil
	local saved = storage:get_string("course:" .. name)
	if saved == "" then return 0 end
	local rec = core.deserialize(saved) or {}
	for _, r in ipairs(rec.nodes or {}) do
		core.set_node({x = r[1], y = r[2], z = r[3]}, {name = r[4], param2 = r[5]})
	end
	storage:set_string("course:" .. name, "")
	return #(rec.nodes or {})
end

local function place_player(player, st)
	player:set_pos(st.start)
	player:set_look_horizontal(st.yaw)
	player:set_look_vertical(0)
end

-- Build course `key` next to the player (mob: an entity name used as the
-- striker on "hit", as the target elsewhere).
function course.build(player, key, mob)
	local shape = shapes.LIST[key]
	if not shape then return false, "unknown course " .. tostring(key) end
	local name = player:get_player_name()
	course.clear(name)
	local dx, dz = axis(player)
	local lx, lz = -dz, dx
	local p = player:get_pos()
	local sx, sz = floor(p.x + 0.5), floor(p.z + 0.5)
	local y0 = floor(p.y + 0.5) - 1
	local a0, a1, h1 = shapes.extent(shape)
	local function at(a, l, h)
		return {x = sx + dx * a + lx * l, y = y0 + h, z = sz + dz * a + lz * l}
	end
	local cells, why = {}, {}
	for a = a0, a1 do
		for l = -shapes.LANE, shapes.LANE do
			for h = 0, h1 + 1 do
				local pos = at(a, l, h)
				if h > h1 then
					local n = core.get_node_or_nil(pos)
					if n and core.get_item_group(n.name, "falling_node") > 0 then
						why["a falling node rests on top"] = true
					end
				else
					local r = refusal(pos)
					if r then
						why[r] = true
					else
						cells[#cells + 1] = {pos, NODE[shapes.cell(shape, a, h)]}
					end
				end
			end
		end
	end
	if next(why) then
		local list = {}
		for r in pairs(why) do list[#list + 1] = r end
		table.sort(list)
		return false, "course refused here: " .. table.concat(list, "; ") ..
			". Walk to open countryside and try again."
	end
	local nodes = {}
	for _, c in ipairs(cells) do
		local n = core.get_node(c[1])
		if n.name ~= c[2] then
			nodes[#nodes + 1] = {c[1].x, c[1].y, c[1].z, n.name, n.param2}
			core.set_node(c[1], {name = c[2]})
		end
	end
	storage:set_string("course:" .. name, core.serialize({nodes = nodes}))
	local st = {
		start = {x = sx, y = y0 + shape.floor(0) + 0.5, z = sz},
		yaw = core.dir_to_yaw({x = dx, y = 0, z = dz}),
	}
	state[name] = st
	local function feet(a, side)
		local fa = floor(a + 0.5)
		return {x = sx + dx * a + lx * side, y = y0 + shape.floor(fa) + 0.5,
			z = sz + dz * a + lz * side}
	end
	local err
	st.target, err = spawn(feet(shape.dist, 0), "dummy", key ~= "hit" and mob or nil)
	if not st.target then return false, err end
	if shape.striker then
		st.striker, err = spawn(feet(shape.striker.a, shape.striker.side), "striker", mob)
		if not st.striker then return false, err end
	end
	place_player(player, st)
	return true, ("course %s: %s; %d nodes replaced (/psetup clear restores them)"):format(
		key, shape.text, #nodes)
end

function course.start_of(name)
	local st = state[name]
	return st and st.start
end

function course.back(player)
	local st = state[player:get_player_name()]
	if not st or not st.start then return false, "no course: /psetup <course> first" end
	place_player(player, st)
	return true, "back at the start"
end

-- A target on the real terrain `dist` metres ahead (no course, no nodes).
function course.dummy(player, dist, mob)
	local name = player:get_player_name()
	local st = state[name] or {}
	state[name] = st
	if valid(st.target) then st.target:remove() end
	local p = player:get_pos()
	local dir = core.yaw_to_dir(player:get_look_horizontal())
	local x, z = floor(p.x + dir.x * dist + 0.5), floor(p.z + dir.z * dist + 0.5)
	local y = ground(x, p.y, z)
	if not y then return false, "no ground found " .. dist .. " m ahead" end
	local err
	st.target, err = spawn({x = x, y = y, z = z}, "dummy", mob)
	if not st.target then return false, err end
	return true, ("target %s at %.1f m"):format(mob or "dummy", dist)
end

core.register_on_leaveplayer(function(player)
	-- The entities are never saved; the nodes stay until /psetup clear.
	remove_entities(state[player:get_player_name()])
	state[player:get_player_name()] = nil
end)
end
