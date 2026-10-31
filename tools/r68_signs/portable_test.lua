-- Round 68 lane SIGNS portable test (round68-plan.md rulings 6-8, §4 SIGNS).
-- The real grug_text (layout.lua, init.lua, the shipped characters.tsv) and
-- the real grug_signs on a small fake engine (nodes, metadata, objects,
-- placement, protection; the builtin vector rotation transcribed from
-- tools/r68_text/portable_test.lua). It checks:
--   M  the models against lane ART's spec (tools/r68_art/candidates): the
--      engine's OBJ loader mirrors x, so every text centre, normal and box
--      in the game is ART's with x negated; each turned model stays inside
--      its unrotated selection boxes (degrotate never turns them);
--   O  each text entity stands where ART's text area is after the engine
--      turns the mesh (client/mesh.cpp rotateMesh, degrotate 1.5 degrees
--      per step, 4dir as rotateMeshBy6dFacedir), 1/64 in front of the
--      board, facing out of it;
--   P  placement: the standing sign faces the placer, the waypost's arrow
--      points where the placer looks, wayposts stack from the right-click;
--   B  the notice board: both halves placed facing the placer, refused when
--      a node, the headroom or the ground is missing or protected; digging
--      either half removes both, one drop, the text entity gone; the part
--      opens the board's form;
--   F  writing: the forms (a text box per grid), quit-gated, protection,
--      512 bytes, control characters, newlines, clearing, no hover text
--      (the user, 2026-10-31); the LBM restores the entities; the one-time
--      LBM drops an old stored hover text;
--   R  the recipes in the Basic catalog, the claim reading exemption and
--      Help's line.
--
-- Usage (repo root): luajit tools/r68_signs/portable_test.lua [repo]

local repo = arg and arg[1] or "."

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local sin, cos = math.sin, math.cos
local function V(x, y, z) return {x = x, y = y, z = z} end
vector = {}
vector.new = function(x, y, z)
	if type(x) == "table" then return V(x.x, x.y, x.z) end
	return V(x or 0, y or 0, z or 0)
end
vector.copy = function(v) return V(v.x, v.y, v.z) end
vector.add = function(a, b) return V(a.x + b.x, a.y + b.y, a.z + b.z) end
vector.subtract = function(a, b) return V(a.x - b.x, a.y - b.y, a.z - b.z) end
vector.multiply = function(a, s) return V(a.x * s, a.y * s, a.z * s) end
vector.equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
vector.length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
vector.distance = function(a, b) return vector.length(vector.subtract(a, b)) end
vector.normalize = function(v)
	local l = vector.length(v)
	return l == 0 and V(0, 0, 0) or vector.multiply(v, 1 / l)
end
local function round(n) return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5) end
vector.round = function(v) return V(round(v.x), round(v.y), round(v.z)) end
vector.dot = function(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
vector.cross = function(a, b)
	return V(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end
vector.angle = function(a, b)
	return math.atan2(vector.length(vector.cross(a, b)), vector.dot(a, b))
end
-- Transcribed from Luanti's builtin/common/vector.lua (rotate_around_axis,
-- rotate, dir_to_rotation; reference_projects/luanti at 5.17.0-dev).
vector.rotate_around_axis = function(v, axis, angle)
	local c, s = cos(angle), sin(angle)
	axis = vector.normalize(axis)
	local dot_axis = vector.multiply(axis, vector.dot(axis, v))
	local cross = vector.cross(v, axis)
	return V(cross.x * s + (v.x - dot_axis.x) * c + dot_axis.x,
		cross.y * s + (v.y - dot_axis.y) * c + dot_axis.y,
		cross.z * s + (v.z - dot_axis.z) * c + dot_axis.z)
end
vector.rotate = function(v, rot)
	local sp, sy, sr = sin(-rot.x), sin(-rot.y), sin(-rot.z)
	local cp, cy, cr = cos(rot.x), cos(rot.y), cos(rot.z)
	local m = {
		{sy * sp * sr + cy * cr, sy * sp * cr - cy * sr, sy * cp},
		{cp * sr, cp * cr, -sp},
		{cy * sp * sr - sy * cr, cy * sp * cr + sy * sr, cy * cp},
	}
	return V(m[1][1] * v.x + m[1][2] * v.y + m[1][3] * v.z,
		m[2][1] * v.x + m[2][2] * v.y + m[2][3] * v.z,
		m[3][1] * v.x + m[3][2] * v.y + m[3][3] * v.z)
end
vector.dir_to_rotation = function(forward, up)
	forward = vector.normalize(forward)
	local rot = V(math.asin(forward.y), -math.atan2(forward.x, forward.z), 0)
	if not up then return rot end
	up = vector.normalize(up)
	local forwup = vector.rotate(V(0, 1, 0), rot)
	rot.z = vector.angle(forwup, up)
	local back = vector.rotate_around_axis(up, forward, -rot.z)
	local d = vector.subtract(back, forwup)
	if vector.dot(d, d) > 0.0000001 then rot.z = -rot.z end
	return rot
end

function table.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local nodes, metas, objects = {}, {}, {}
local entity_defs, lbms = {}, {}
local protected, violations, feeds, shown, placed_param2 = {}, {}, {}, {}, {}

local function meta_at(pos)
	local k = key(pos)
	if not metas[k] then
		local store = {}
		metas[k] = {
			get_string = function(_, f) return store[f] or "" end,
			set_string = function(_, f, v) store[f] = v ~= "" and v or nil end,
			get_int = function(_, f) return math.floor(tonumber(store[f]) or 0) end,
			clear = function() for f in pairs(store) do store[f] = nil end end,
		}
	end
	return metas[k]
end

local facedir_dirs = {[0] = V(0, 0, 1), V(1, 0, 0), V(0, 0, -1), V(-1, 0, 0)}

core = {
	registered_nodes = {},
	get_current_modname = function() return "grug_text" end,
	get_modpath = function() return repo .. "/mods/CORE/grug_text" end,
	register_node = function(name, def)
		def = table.copy(def)
		def.name = name
		core.registered_nodes[name] = def
	end,
	override_item = function(name, redef)
		local def = assert(core.registered_nodes[name], "override of unknown " .. name)
		for k, v in pairs(redef) do def[k] = v end
	end,
	register_entity = function(name, def) def.name = name; entity_defs[name] = def end,
	register_lbm = function(def) lbms[#lbms + 1] = def end,
	get_node_or_nil = function(pos)
		local n = nodes[key(pos)]
		return {name = n and n.name or "air", param2 = n and n.param2 or 0}
	end,
	get_meta = meta_at,
	facedir_to_dir = function(p) return vector.copy(facedir_dirs[p % 4]) end,
	yaw_to_dir = function(yaw) return V(-sin(yaw), 0, cos(yaw)) end,
	-- builtin/common/item_s.lua
	dir_to_fourdir = function(dir)
		if math.abs(dir.x) > math.abs(dir.z) then return dir.x < 0 and 3 or 1 end
		return dir.z < 0 and 2 or 0
	end,
	get_objects_inside_radius = function(pos, r)
		local out = {}
		for _, obj in ipairs(objects) do
			if not obj.removed and vector.distance(obj.pos, pos) <= r then out[#out + 1] = obj end
		end
		return out
	end,
	add_entity = function(pos, name)
		local def = entity_defs[name]
		local obj = {pos = vector.copy(pos), rot = V(0, 0, 0),
			props = table.copy(def.initial_properties)}
		local ent = setmetatable({name = name, object = obj}, {__index = def})
		function obj:get_luaentity() return not self.removed and ent or nil end
		function obj:set_pos(p) self.pos = vector.copy(p) end
		function obj:set_rotation(r) self.rot = vector.copy(r) end
		function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
		function obj:set_armor_groups(g) self.armor = g end
		function obj:remove() self.removed = true end
		objects[#objects + 1] = obj
		if def.on_activate then def.on_activate(ent, "") end
		return obj
	end,
	-- A protected spot refuses everyone but "owner".
	is_protected = function(pos, name) return protected[key(pos)] == true and name ~= "owner" end,
	record_protection_violation = function(pos, name) violations[#violations + 1] = key(pos) end,
	is_creative_enabled = function() return false end,
	check_for_falling = function() end,
	log = function() end,
	pos_to_string = function(p) return "(" .. key(p) .. ")" end,
	formspec_escape = function(s) return (s:gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(_, s) return s end,
}
core.get_node = core.get_node_or_nil
-- The engine's order: on_destruct with the node still there, the swap, the
-- metadata gone, after_destruct.
core.set_node = function(pos, node)
	local old = core.get_node(pos)
	local olddef = core.registered_nodes[old.name]
	if olddef and olddef.on_destruct then olddef.on_destruct(pos) end
	nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
	meta_at(pos):clear()
	if olddef and olddef.after_destruct then olddef.after_destruct(pos, old) end
end
core.add_node = core.set_node
core.swap_node = function(pos, node) nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0} end
core.remove_node = function(pos) core.set_node(pos, {name = "air"}) end
-- builtin item_place_node, reduced: above, protection, the attached_node
-- floor check (rating 3), the given param2.
core.item_place_node = function(itemstack, placer, pointed_thing, param2)
	local pos = pointed_thing.above
	local name = placer:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return itemstack
	end
	local below = core.registered_nodes[core.get_node(vector.subtract(pos, V(0, 1, 0))).name]
	if not below or not below.walkable then return itemstack end
	placed_param2[#placed_param2 + 1] = param2
	core.set_node(pos, {name = itemstack:get_name(), param2 = param2})
	itemstack:take_item()
	return itemstack, pos
end
core.item_place = function(itemstack, placer, pointed_thing, param2)
	return core.item_place_node(itemstack, placer, pointed_thing, param2)
end
core.register_node("air", {walkable = false, buildable_to = true})
core.register_node("default:stone", {walkable = true})

local function stack(name, count)
	local s = {name = name, count = count or 1}
	function s:get_name() return self.count > 0 and self.name or "" end
	function s:take_item() self.count = self.count - 1 end
	return s
end
local function player(name, yaw, look)
	return {
		get_player_name = function() return name end,
		is_player = function() return true end,
		get_look_horizontal = function() return yaw or 0 end,
		get_look_dir = function() return look or V(-sin(yaw or 0), 0, cos(yaw or 0)) end,
		get_player_control = function() return {sneak = false} end,
	}
end

default = {
	node_sound_wood_defaults = function() return {} end,
	log_player_action = function() end,
	containers = {TIERS = {}, LABEL_KEY = "grug_label"},
	node_formspec = {
		show = function(p, pos, build)
			shown[#shown + 1] = {pos = vector.copy(pos), form = build(pos, p, {})}
			return true
		end,
		refresh = function() end,
	},
}
grug_core = {
	feed = function(_, kind, text) feeds[#feeds + 1] = text end,
	ui = {
		colors = {muted = "#a9aea4"},
		frame = function(w, h, title) return ("size[%s,%s]title[%s]"):format(w, h, title) end,
		input_background = function() return "" end,
		button_style = function() return "" end,
	},
}

dofile(repo .. "/mods/CORE/grug_text/init.lua")
dofile(repo .. "/mods/ITEMS/grug_signs/init.lua")
local ENT = "grug_text:text"
local STANDING, WAYPOST = "grug_signs:standing_sign", "grug_signs:waypost"
local BOARD, PART = "grug_signs:notice_board", "grug_signs:notice_board_part"
local GAP = 1 / 64

local function live(pos)
	local out = {}
	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()
		if ent and ent._grug_pos and vector.equals(ent._grug_pos, pos) then out[#out + 1] = obj end
	end
	table.sort(out, function(a, b) return a:get_luaentity()._grug_index < b:get_luaentity()._grug_index end)
	return out
end
local function all_live()
	local n = 0
	for _, obj in ipairs(objects) do if not obj.removed then n = n + 1 end end
	return n
end
local function near(a, b, tol) return vector.distance(a, b) < (tol or 1e-9) end
local function submit(pos, text, who, quit)
	local def = core.registered_nodes[core.get_node(pos).name]
	def.on_receive_fields(pos, "default:node_formspec",
		{quit = quit ~= false and "true" or nil, text = text}, player(who or "owner"))
end

------------------------------------------------------------------------------
-- A small JSON reader (ART's specs) and the OBJ vertices.
------------------------------------------------------------------------------
local function json_decode(text)
	local i = 1
	local function ws() i = text:find("[^%s]", i) or #text + 1 end
	local value
	local function str()
		local j = text:find('"', i + 1, true)
		local s = text:sub(i + 1, j - 1)
		i = j + 1
		return s
	end
	function value()
		ws()
		local c = text:sub(i, i)
		if c == "{" then
			local t = {}
			i = i + 1; ws()
			if text:sub(i, i) == "}" then i = i + 1; return t end
			while true do
				ws(); local k = str(); ws(); i = i + 1
				t[k] = value(); ws()
				local d = text:sub(i, i); i = i + 1
				if d == "}" then return t end
			end
		elseif c == "[" then
			local t = {}
			i = i + 1; ws()
			if text:sub(i, i) == "]" then i = i + 1; return t end
			while true do
				t[#t + 1] = value(); ws()
				local d = text:sub(i, i); i = i + 1
				if d == "]" then return t end
			end
		elseif c == '"' then return str()
		elseif text:sub(i, i + 3) == "true" then i = i + 4; return true
		elseif text:sub(i, i + 4) == "false" then i = i + 5; return false
		elseif text:sub(i, i + 3) == "null" then i = i + 4; return nil end
		local num = text:match("^-?[%d%.eE+-]+", i)
		i = i + #num
		return tonumber(num)
	end
	return value()
end
local function spec(name) return json_decode(read("tools/r68_art/candidates/" .. name .. ".json")) end
local function obj_vertices(file)
	local out = {}
	for x, y, z in read("mods/ITEMS/grug_signs/models/" .. file):gmatch("\nv (%S+) (%S+) (%S+)") do
		-- The engine's handedness change (irr/src/COBJMeshFileLoader.cpp:314).
		out[#out + 1] = V(-tonumber(x), tonumber(y), tonumber(z))
	end
	return out
end
local function mirror(v) return V(-v[1], v[2], v[3]) end

-- client/mesh.cpp rotateMesh<X, Z>: u' = c u - s v, v' = s u + c v.
local function turn(v, degrees)
	local r = math.rad(degrees)
	local c, s = cos(r), sin(r)
	return V(c * v.x - s * v.z, v.y, s * v.x + c * v.z)
end
-- client/mesh.cpp rotateMeshBy6dFacedir, the horizontal part.
local FACEDIR_DEGREES = {[0] = 0, -90, 180, 90}
local function inside(p, boxes, tol)
	for _, b in ipairs(boxes) do
		if p.x >= b[1] - tol and p.y >= b[2] - tol and p.z >= b[3] - tol and
				p.x <= b[4] + tol and p.y <= b[5] + tol and p.z <= b[6] + tol then
			return true
		end
	end
	return false
end

local SPECS = {
	[STANDING] = spec("sign_standing_a"),
	[WAYPOST] = spec("waypost_b"),
	[BOARD] = spec("notice_board_b"),
}
local MODELS = {
	[STANDING] = "grug_signs_standing.obj",
	[WAYPOST] = "grug_signs_waypost.obj",
	[BOARD] = "grug_signs_notice_board.obj",
}

------------------------------------------------------------------------------
-- M. The models against ART's spec.
------------------------------------------------------------------------------
for name, file in pairs(MODELS) do
	local s = SPECS[name]
	local lo, hi = V(1e9, 1e9, 1e9), V(-1e9, -1e9, -1e9)
	for _, v in ipairs(obj_vertices(file)) do
		lo = V(math.min(lo.x, v.x), math.min(lo.y, v.y), math.min(lo.z, v.z))
		hi = V(math.max(hi.x, v.x), math.max(hi.y, v.y), math.max(hi.z, v.z))
	end
	local b = s.bounds
	check(near(lo, V(-b[4], b[2], b[3]), 1e-6) and near(hi, V(-b[1], b[5], b[6]), 1e-6),
		"M " .. name .. ": the loaded model is ART's mirrored in x")
end
eq(-SPECS[BOARD].bounds[4] .. "," .. -SPECS[BOARD].bounds[1], "-1.5,0.5",
	"M the board's model reaches one node towards -x (the part, the reader's left)")
for _, name in ipairs({STANDING, WAYPOST}) do
	local boxes = core.registered_nodes[name].selection_box.fixed
	local ok = true
	for p2 = 0, 239, 7 do
		for _, v in ipairs(obj_vertices(MODELS[name])) do
			if not inside(turn(v, 1.5 * p2), boxes, 1e-6) then ok = false end
		end
	end
	check(ok, "M " .. name .. ": the turned model stays inside its unrotated selection box")
end
eq(core.registered_nodes[WAYPOST].walkable, true, "M the waypost carries the next one")
eq(#core.registered_nodes[WAYPOST].collision_box.fixed, 1, "M only the waypost's post collides")
-- The board's boxes: ART's suggestion mirrored and split at the halves.
do
	local main, part = {}, {}
	for _, b in ipairs(SPECS[BOARD].selection_box.fixed) do
		local x1, x2 = -b[4], -b[1]
		if x2 > -0.5 then main[#main + 1] = {math.max(x1, -0.5), b[2], b[3], x2, b[5], b[6]} end
		if x1 < -0.5 then part[#part + 1] = {x1 + 1, b[2], b[3], math.min(x2, -0.5) + 1, b[5], b[6]} end
	end
	local function same(list, boxes, label)
		local found = 0
		for _, want in ipairs(list) do
			for _, have in ipairs(boxes) do
				local ok = true
				for k = 1, 6 do if math.abs(want[k] - have[k]) > 1e-9 then ok = false end end
				if ok then found = found + 1; break end
			end
		end
		eq(found .. "/" .. #boxes, #list .. "/" .. #list, label)
	end
	same(main, core.registered_nodes[BOARD].selection_box.fixed, "M the board's boxes are ART's (its half)")
	same(part, core.registered_nodes[PART].selection_box.fixed, "M the part's boxes are ART's (its half)")
	same(main, core.registered_nodes[BOARD].collision_box.fixed, "M the board collides as selected")
end

------------------------------------------------------------------------------
-- O. Each text entity where ART's text area is after the engine's turn.
------------------------------------------------------------------------------
local function areas(name)
	local out = {}
	for index, a in ipairs(SPECS[name].text_areas) do
		local n = mirror(a.normal)
		-- ART's centres sit `surface_offset` (0.003) off the board; ours 1/64.
		local c = vector.add(mirror(a.center), vector.multiply(n, GAP - a.surface_offset))
		out[index] = {centre = c, normal = n, lines = a.lines, chars = a.characters_per_line}
	end
	return out
end
local function orientation_case(name, pos, param2, degrees)
	core.set_node(pos, {name = name, param2 = param2})
	submit(pos, "Hello")
	local list = live(pos)
	local want = areas(name)
	eq(#list, #want, ("O %s param2 %d: one entity per text area"):format(name, param2))
	for index, a in ipairs(want) do
		local obj = list[index]
		local surface = grug_text.surfaces(name)[index]
		eq(surface.lines .. "x" .. surface.chars, a.lines .. "x" .. a.chars,
			("O %s area %d: ART's grid"):format(name, index))
		if obj then
			local label = ("O %s param2 %d area %d"):format(name, param2, index)
			check(near(obj.pos, vector.add(pos, turn(a.centre, degrees)), 1e-9),
				label .. ": in front of the turned board")
			check(near(vector.rotate(V(0, 0, 1), obj.rot), turn(a.normal, degrees), 1e-9),
				label .. ": faces out of the board")
			check(near(vector.rotate(V(0, 1, 0), obj.rot), V(0, 1, 0), 1e-9), label .. ": upright")
		end
	end
	core.remove_node(pos)
	eq(#live(pos), 0, ("O %s param2 %d: dug, no entity"):format(name, param2))
end
for _, p2 in ipairs({0, 1, 37, 60, 120, 180, 199, 239}) do
	orientation_case(STANDING, V(0, 50, 0), p2, 1.5 * p2)
	orientation_case(WAYPOST, V(0, 50, 0), p2, 1.5 * p2)
end
for p2 = 0, 3 do orientation_case(BOARD, V(0, 50, 0), p2, FACEDIR_DEGREES[p2]) end
-- The waypost's two texts face opposite ways and read the same text.
do
	local pos = V(0, 60, 0)
	core.set_node(pos, {name = WAYPOST, param2 = 17})
	submit(pos, "Eastmarch")
	local list = live(pos)
	check(near(vector.add(vector.rotate(V(0, 0, 1), list[1].rot), vector.rotate(V(0, 0, 1),
		list[2].rot)), V(0, 0, 0), 1e-9), "O the waypost's sides face opposite ways")
	eq(list[1].props.textures[1], list[2].props.textures[1], "O both sides show the same text")
	eq(list[1].props.textures[2], "blank.png", "O each side is one-faced")
	core.remove_node(pos)
end

------------------------------------------------------------------------------
-- P. Placement.
------------------------------------------------------------------------------
local function on_ground(x, z) return {type = "node", under = V(200 + x, 0, z), above = V(200 + x, 1, z)} end
for x = -20, 20 do for z = -20, 20 do nodes[key(V(200 + x, 0, z))] = {name = "default:stone", param2 = 0} end end
for _, yaw_deg in ipairs({0, 30, 91, 200, 333}) do
	local yaw = math.rad(yaw_deg)
	local look = V(-sin(yaw), 0, cos(yaw))
	local s = stack(STANDING)
	core.registered_nodes[STANDING].on_place(s, player("owner", yaw), on_ground(0, 0))
	local node = core.get_node(V(200, 1, 0))
	eq(node.name, STANDING, "P standing sign placed at yaw " .. yaw_deg)
	-- The reader looks along +z unturned: turned, along the placer's look.
	check(near(turn(V(0, 0, 1), 1.5 * node.param2), look, math.rad(0.76)),
		"P the standing sign faces the placer at yaw " .. yaw_deg)
	eq(s.count, 0, "P the item is used")
	core.remove_node(V(200, 1, 0))
	local w = stack(WAYPOST)
	core.registered_nodes[WAYPOST].on_place(w, player("owner", yaw), on_ground(0, 0))
	node = core.get_node(V(200, 1, 0))
	check(near(turn(V(0, 0, -1), 1.5 * node.param2), look, math.rad(0.76)),
		"P the waypost's arrow points where the placer looks at yaw " .. yaw_deg)
	core.remove_node(V(200, 1, 0))
end
-- Stacking: a waypost in hand on a waypost's top places the next; without
-- one, or on its side, the form opens.
do
	local wdef = core.registered_nodes[WAYPOST]
	wdef.on_place(stack(WAYPOST), player("owner", 0), on_ground(2, 2))
	local bottom = V(202, 1, 2)
	local s = stack(WAYPOST, 2)
	local top_face = {type = "node", under = bottom, above = V(202, 2, 2)}
	local back = wdef.on_rightclick(bottom, core.get_node(bottom), player("owner", math.rad(90)), s, top_face)
	eq(core.get_node(V(202, 2, 2)).name, WAYPOST, "P a waypost stacks on a waypost's top")
	eq(back, s, "P the stack comes back")
	eq(s.count, 1, "P one item used")
	local n_shown = #shown
	wdef.on_rightclick(bottom, core.get_node(bottom), player("owner", 0), s,
		{type = "node", under = bottom, above = V(203, 1, 2)})
	eq(#shown, n_shown + 1, "P on the side the form opens")
	wdef.on_rightclick(bottom, core.get_node(bottom), player("owner", 0), stack("default:stick"), top_face)
	eq(#shown, n_shown + 2, "P with something else in hand the form opens")
	eq(core.get_node(V(202, 3, 2)).name, "air", "P nothing else stacked")
	core.remove_node(V(202, 2, 2)); core.remove_node(bottom)
end
eq(core.registered_nodes[STANDING].groups.attached_node, 3, "P the standing sign stands on the ground")
eq(core.registered_nodes[WAYPOST].groups.attached_node, 3, "P the waypost stands on the ground")

------------------------------------------------------------------------------
-- B. The notice board.
------------------------------------------------------------------------------
local bdef = core.registered_nodes[BOARD]
local function place_board(x, z, look, who)
	local s = stack(BOARD)
	feeds = {}
	bdef.on_place(s, player(who or "builder", 0, look), on_ground(x, z))
	return s
end
do
	local s = place_board(0, 0, V(0, 0, 1))
	eq(s.count, 0, "B placed facing +z")
	eq(core.get_node(V(200, 1, 0)).name, PART, "B the part where the player points")
	eq(core.get_node(V(201, 1, 0)).name, BOARD, "B the board to the placer's right")
	eq(core.get_node(V(201, 1, 0)).param2, 0, "B facing the placer")
	check(vector.equals(grug_signs.partner(V(200, 1, 0), core.get_node(V(200, 1, 0))), V(201, 1, 0)),
		"B the part finds the board")
	check(vector.equals(grug_signs.partner(V(201, 1, 0), core.get_node(V(201, 1, 0))), V(200, 1, 0)),
		"B the board finds the part")
	submit(V(201, 1, 0), "Market opens at sunrise\nFresh bread at the square")
	eq(#live(V(201, 1, 0)), 1, "B one text entity on the board")
	eq(meta_at(V(200, 1, 0)):get_string("infotext") .. "|" .. meta_at(V(201, 1, 0)):get_string("infotext"),
		"|", "B neither half has hover text")
	local n_shown = #shown
	core.registered_nodes[PART].on_rightclick(V(200, 1, 0), core.get_node(V(200, 1, 0)),
		player("owner", 0), stack("default:stick"))
	check(#shown == n_shown + 1 and vector.equals(shown[#shown].pos, V(201, 1, 0)),
		"B the part opens the board's form")
	-- Digging the part: both go, the entity too, the part drops the board.
	eq(core.registered_nodes[PART].drop, BOARD, "B the part drops the board")
	core.remove_node(V(200, 1, 0))
	eq(core.get_node(V(201, 1, 0)).name, "air", "B digging the part removes the board")
	eq(#live(V(201, 1, 0)), 0, "B and its text entity")
	eq(meta_at(V(201, 1, 0)):get_string("text"), "", "B and its text")
	-- Digging the board: both go.
	place_board(0, 0, V(0, 0, 1))
	submit(V(201, 1, 0), "Again")
	eq(bdef.drop, nil, "B the board drops itself")
	core.remove_node(V(201, 1, 0))
	eq(core.get_node(V(200, 1, 0)).name, "air", "B digging the board removes the part")
	eq(#live(V(201, 1, 0)), 0, "B no text entity left")
end
for p2, look in pairs({[0] = V(0, 0, 1), V(1, 0, 0), V(0, 0, -1), V(-1, 0, 0)}) do
	place_board(5, 5, look)
	local part = V(205, 1, 5)
	local main = vector.add(part, V(look.z, 0, -look.x))
	eq(core.get_node(main).name .. "/" .. core.get_node(main).param2, BOARD .. "/" .. p2,
		"B facing " .. p2 .. ": the board to the placer's right")
	core.remove_node(main)
	eq(core.get_node(part).name, "air", "B facing " .. p2 .. ": dug as one")
end
do
	local function refused(label, setup, undo)
		setup()
		local s = place_board(0, 0, V(0, 0, 1))
		eq(s.count, 1, "B refused: " .. label)
		eq(core.get_node(V(200, 1, 0)).name ~= PART and core.get_node(V(201, 1, 0)).name ~= BOARD,
			true, "B nothing placed: " .. label)
		undo()
	end
	local function stone(p) nodes[key(p)] = {name = "default:stone", param2 = 0} end
	local function air(p) nodes[key(p)] = nil end
	refused("the second node is taken", function() stone(V(201, 1, 0)) end, function() air(V(201, 1, 0)) end)
	eq(#feeds, 1, "B a refusal says why")
	refused("no headroom over the part", function() stone(V(200, 2, 0)) end, function() air(V(200, 2, 0)) end)
	refused("no headroom over the board", function() stone(V(201, 2, 0)) end, function() air(V(201, 2, 0)) end)
	refused("no ground under the board", function() air(V(201, 0, 0)) end, function() stone(V(201, 0, 0)) end)
	violations = {}
	refused("the board's node is protected", function() protected[key(V(201, 1, 0))] = true end,
		function() protected[key(V(201, 1, 0))] = nil end)
	eq(#violations, 1, "B the protection violation is recorded")
	refused("the space above is protected", function() protected[key(V(201, 2, 0))] = true end,
		function() protected[key(V(201, 2, 0))] = nil end)
	local s = place_board(0, 0, V(0, 0, 1))
	eq(s.count, 0, "B placed once the space is free")
	core.remove_node(V(201, 1, 0))
end
do
	-- Another node's on_rightclick wins without sneak (the bed pattern).
	core.register_node("test:clicky", {walkable = true, on_rightclick = function(_, _, _, itemstack)
		_G.clicked = true
		return itemstack
	end})
	nodes[key(V(210, 0, 0))] = {name = "test:clicky", param2 = 0}
	local s = stack(BOARD)
	bdef.on_place(s, player("owner", 0, V(0, 0, 1)), {type = "node", under = V(210, 0, 0), above = V(210, 1, 0)})
	check(_G.clicked == true and s.count == 1, "B a pointed node's right-click comes first")
	nodes[key(V(210, 0, 0))] = {name = "default:stone", param2 = 0}
end

------------------------------------------------------------------------------
-- F. Writing.
------------------------------------------------------------------------------
do
	local pos = V(220, 1, 0)
	core.set_node(pos, {name = STANDING, param2 = 0})
	core.registered_nodes[STANDING].on_rightclick(pos, core.get_node(pos), player("owner"), stack("x"))
	check(shown[#shown].form:find("textarea%[") ~= nil, "F the standing sign's form has a text box")
	check(shown[#shown].form:find("4 lines of 15") ~= nil, "F it names the grid")
	submit(pos, "Welcome to\nAshford")
	eq(meta_at(pos):get_string("text"), "Welcome to\nAshford", "F the text is saved, newline kept")
	eq(meta_at(pos):get_string("infotext"), "", "F no hover text")
	local tex = live(pos)[1].props.textures[1]
	eq(#grug_text.layout.wrap(meta_at(pos):get_string("text"), 4, 15), 2, "F the newline makes two rows")
	check(tex:find("%^%[multiply:#2b1e14$") ~= nil, "F dark ink")
	submit(pos, "ignored", "owner", false)
	eq(meta_at(pos):get_string("text"), "Welcome to\nAshford", "F only a quit writes")
	feeds = {}
	submit(pos, ("x"):rep(513))
	eq(meta_at(pos):get_string("text"), "Welcome to\nAshford", "F 513 bytes are refused")
	eq(feeds[1], "Text too long", "F and said so")
	submit(pos, ("y"):rep(512))
	eq(#meta_at(pos):get_string("text"), 512, "F 512 bytes are written")
	submit(pos, "a\1b\27c\td\ne")
	eq(meta_at(pos):get_string("text"), "abc\td\ne", "F control characters are stripped, tab and newline kept")
	protected[key(pos)] = true
	violations = {}
	submit(pos, "vandal", "stranger")
	eq(meta_at(pos):get_string("text"), "abc\td\ne", "F in someone else's claim nothing is written")
	eq(#violations, 1, "F the violation is recorded")
	submit(pos, "owner's", "owner")
	eq(meta_at(pos):get_string("text"), "owner's", "F the owner writes")
	protected[key(pos)] = nil
	submit(pos, "")
	eq(#live(pos), 0, "F clearing removes the entity")
	eq(meta_at(pos):get_string("infotext"), "", "F still no hover text")
	-- A sign written before stored its text as hover text: the one-time
	-- LBM drops it, the text and its entity stay.
	local drop
	for _, lbm in ipairs(lbms) do
		if lbm.name == "grug_signs:drop_hover_text" then drop = lbm end
	end
	if check(drop ~= nil, "F the LBM that drops old hover text") then
		eq(drop.run_at_every_load, false, "F it runs once per block")
		eq(table.concat(drop.nodenames, " "), table.concat(grug_signs.NODES, " "),
			"F it covers the four nodes, the board's part too")
		submit(pos, "Old words")
		meta_at(pos):set_string("infotext", '"Old words"')
		drop.action(pos, core.get_node(pos), 0)
		eq(meta_at(pos):get_string("infotext"), "", "F an old hover text is dropped")
		eq(meta_at(pos):get_string("text") .. " " .. #live(pos), "Old words 1", "F ...the text and its entity stay")
	end
	core.remove_node(pos)
end
do
	local pos = V(222, 1, 0)
	core.set_node(pos, {name = WAYPOST, param2 = 0})
	core.registered_nodes[WAYPOST].on_rightclick(pos, core.get_node(pos), player("owner"), stack("x"))
	check(shown[#shown].form:find("field%[") ~= nil and shown[#shown].form:find("textarea%[") == nil,
		"F the waypost's form is one line")
	place_board(15, 10, V(0, 0, 1))
	local board = V(216, 1, 10)
	bdef.on_rightclick(board, core.get_node(board), player("owner"), stack("x"))
	check(shown[#shown].form:find("textarea%[") ~= nil and shown[#shown].form:find("7 lines of 30") ~= nil,
		"F the notice board's form has a text box for 7 lines")
	local seven = "ASHFORD NOTICE BOARD\nMarket opens at sunrise\nFresh bread at the square\n" ..
		"Miners meet by the old well\nBring a lantern after dusk\nLeave parcels with the clerk\n" ..
		"All travellers are welcome"
	submit(board, seven)
	-- An old board's part stored the hover text too; the one-time LBM
	-- clears it.
	local part = V(215, 1, 10)
	eq(core.get_node(part).name, PART, "F the board's part")
	meta_at(part):set_string("infotext", '"old"')
	for _, lbm in ipairs(lbms) do
		if lbm.name == "grug_signs:drop_hover_text" then lbm.action(part, core.get_node(part), 0) end
	end
	eq(meta_at(part):get_string("infotext"), "", "F an old part's hover text is dropped")
	local tex = live(board)[1].props.textures[1]
	print(("notice board texture string with 7 full lines of real text: %d bytes"):format(#tex))
	eq(#grug_text.layout.wrap(seven, 7, 30), 7, "F seven lines on the notice board")
	check(#tex < 65535, "F the board's texture fits the engine's string")
	-- The LBM after an unload: the entity comes back once.
	for _, obj in ipairs(live(board)) do obj.removed = true end
	for _, lbm in ipairs(lbms) do lbm.action(board, core.get_node(board), 0) end
	for _, lbm in ipairs(lbms) do lbm.action(board, core.get_node(board), 0) end
	eq(#live(board), 1, "F the LBM restores the board's text once")
	core.remove_node(board)
	core.remove_node(pos)
end
eq(all_live(), 0, "F no text entity left behind")

------------------------------------------------------------------------------
-- R. Recipes, the reading exemption, Help.
------------------------------------------------------------------------------
do
	local catalog = read("mods/PLAYER/grug_jobs/basic_recipes.lua")
	local function row(output, n)
		return ('{output = "%s", count = 1, ingredients = {{item = "default:sign_wall_wood", n = %d}, ' ..
			'{group = "stick", n = %d}}}'):format(output, n, n)
	end
	check(catalog:find(row(STANDING, 1), 1, true) ~= nil, "R standing sign = 1 wall sign + 1 stick")
	check(catalog:find(row(WAYPOST, 1), 1, true) ~= nil, "R waypost = 1 wall sign + 1 stick")
	check(catalog:find(row(BOARD, 2), 1, true) ~= nil, "R notice board = 2 wall signs + 2 sticks")
	local interaction = read("mods/PLAYER/grug_housing/interaction.lua")
	for _, name in ipairs(grug_signs.NODES) do
		check(interaction:find('["' .. name .. '"] = "reading a sign"', 1, true) ~= nil,
			"R reading " .. name .. " is free in a claim")
	end
	local help = read("mods/PLAYER/grug_inventory/help.lua")
	for _, word in ipairs({"Standing Sign", "Waypost", "Notice Board"}) do
		check(help:find(word, 1, true) ~= nil, "R Help names the " .. word)
	end
end

if failures > 0 then
	print(("R68 SIGNS PORTABLE FAIL %d of %d checks"):format(failures, checks))
	error("R68 SIGNS portable fixture failed")
end
print(("R68 SIGNS PORTABLE PASS checks=%d"):format(checks))
