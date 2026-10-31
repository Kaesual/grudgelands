-- Round 68 lane TEXT portable test (round68-plan.md rulings 1-5, §4 TEXT).
-- The real grug_text (layout.lua, init.lua, surfaces.lua, the shipped
-- characters.tsv and glyphs) and the real default/containers.lua on a small
-- fake engine (nodes, metadata, objects; the builtin vector rotation
-- transcribed below). It checks:
--   W  the wrapping (ruling 4): spaces, a long word, cut-off, newlines,
--      blank lines, UTF-8, control characters;
--   T  the texture string: glyph positions, centring, the ink, the
--      placeholder, the canvas sizes; it prints the string length of a full
--      wall sign, a full chest label and a full 7 x 30 notice board;
--   F  the font: every table row's glyph file exists, the placeholder too;
--   O  the entity's position and turn per wallmounted orientation and per
--      chest facing (the reader's look direction and the text's up);
--   L  the lifecycle: write, rewrite, clear, dig, the LBM after a reload
--      (no duplicate, no entity for an empty text), a chest's label save,
--      clear, open/close swap, the tier upgrade's swap (the ink), digging;
--      both faces of a two-sided surface; several surfaces on one node;
--   H  no hover text (the user, 2026-10-31): the wall sign's handler in
--      default/nodes.lua writes none, a chest's is its name without the
--      label, and the one-time LBM drops an old stored one (a sign's quoted
--      text, a chest's label line) and leaves everything else alone.
--
-- Usage (repo root): luajit tools/r68_text/portable_test.lua [repo]

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
local nodes, metas = {}, {}
local objects = {}
local entity_defs, lbms = {}, {}
local sends = 0

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
local wall_dirs = {[0] = V(0, 1, 0), V(0, -1, 0), V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1),
	V(0, 1, 0), V(0, -1, 0)}

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
		return n and {name = n.name, param2 = n.param2} or nil
	end,
	get_meta = meta_at,
	facedir_to_dir = function(p) return vector.copy(facedir_dirs[p % 4]) end,
	wallmounted_to_dir = function(p) return vector.copy(wall_dirs[p % 8]) end,
	yaw_to_dir = function(yaw) return V(-sin(yaw), 0, cos(yaw)) end,
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
		function obj:set_pos(p) sends = sends + 1; self.pos = vector.copy(p) end
		function obj:set_rotation(r) sends = sends + 1; self.rot = vector.copy(r) end
		function obj:set_properties(p)
			sends = sends + 1
			for k, v in pairs(p) do self.props[k] = v end
		end
		function obj:set_armor_groups(g) self.armor = g end
		function obj:remove() self.removed = true end
		objects[#objects + 1] = obj
		if def.on_activate then def.on_activate(ent, "") end
		return obj
	end,
}
core.get_node = function(pos) return core.get_node_or_nil(pos) or {name = "air", param2 = 0} end
core.swap_node = function(pos, node) nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0} end
core.set_node = function(pos, node)
	local old = nodes[key(pos)]
	local olddef = old and core.registered_nodes[old.name]
	nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
	meta_at(pos):clear()
	if olddef and olddef.after_destruct then olddef.after_destruct(pos, old) end
end
core.remove_node = function(pos) core.set_node(pos, {name = "air"}) end

local function live(pos)
	local out = {}
	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()
		if ent and ent._grug_pos and vector.equals(ent._grug_pos, pos) then out[#out + 1] = obj end
	end
	return out
end
local function run_lbm(pos)
	local node = core.get_node_or_nil(pos)
	for _, lbm in ipairs(lbms) do
		local group = lbm.nodenames[1]:match("^group:(.+)$")
		local def = core.registered_nodes[node.name]
		if def and def.groups and def.groups[group] then lbm.action(pos, node, 0) end
	end
end
-- A mapblock unloaded and loaded again: the unsaved entities are gone.
local function unload(pos)
	for _, obj in ipairs(live(pos)) do obj.removed = true end
end

------------------------------------------------------------------------------
-- The vendored nodes the module wires: the wall sign (its form handler as
-- default/nodes.lua's writes meta `text` and no hover text, checked in H),
-- the iron clone, and the chests' container entries through the real
-- default/containers.lua.
------------------------------------------------------------------------------
default = {get_translator = function(text, ...)
	local args = {...}
	return (text:gsub("@(%d)", function(n) return args[tonumber(n)] end))
end}
local function sign_def(desc)
	return {
		description = desc, paramtype2 = "wallmounted", tiles = {"x.png"},
		groups = {choppy = 2, attached_node = 1},
		after_destruct = function(pos) _G.sign_destructs = (_G.sign_destructs or 0) + 1 end,
		on_receive_fields = function(pos, _, fields)
			if not fields.quit or not fields.text then return end
			meta_at(pos):set_string("text", fields.text)
		end,
	}
end
core.register_node("default:sign_wall_wood", sign_def("Wooden Sign"))
core.register_node("grug_materials:iron_sign_wall", sign_def("Iron Sign"))
dofile(repo .. "/mods/BASE/default/containers.lua")
for tier = 1, #default.containers.TIERS do
	for _, base in ipairs({"default:chest", "default:chest_locked"}) do
		local name = default.containers.tier_name(base, tier)
		local def = {description = default.containers.description("Chest", tier,
			base:find("locked") and "Locked" or nil), paramtype2 = "facedir", groups = {choppy = 2}}
		core.register_node(name, def)
		core.register_node(name .. "_open", def)
		default.containers.register(name, {base = base, tier = tier, list = "main",
			kind = base:find("locked") and "locked" or "chest", open = name .. "_open",
			refresh = default.containers.update_infotext})
	end
end

dofile(repo .. "/mods/CORE/grug_text/init.lua")
local T = grug_text
local layout = T.layout

local function rows_of(text, lines, chars)
	local out = {}
	for i, row in ipairs(layout.wrap(text, lines, chars)) do out[i] = layout.utf8(row) end
	return table.concat(out, "|")
end

------------------------------------------------------------------------------
-- W. Wrapping (ruling 4).
------------------------------------------------------------------------------
eq(rows_of("Welcome to Hearthpine Mill and Inn", 4, 15), "Welcome to|Hearthpine Mill|and Inn",
	"W breaks at spaces")
eq(rows_of("Pneumonoultramicroscopic", 4, 15), "Pneumonoultrami|croscopic",
	"W a word longer than a row is broken inside")
eq(rows_of("To: Pneumonoultramicroscopic", 4, 15), "To:|Pneumonoultrami|croscopic",
	"W a long word starts on its own row")
eq(rows_of("one two three four five six seven eight nine ten eleven twelve", 2, 10),
	"one two|three four", "W what does not fit is cut off")
eq(rows_of("Line one\nLine two\n\nLine four\nLine five", 4, 15),
	"Line one|Line two||Line four", "W newlines start rows, a blank line stays, the fifth is cut")
eq(rows_of("  spaced   out  \t words ", 2, 15), "spaced out|words",
	"W runs of spaces and tabs are one break, no row starts or ends with one")
eq(rows_of("Fünf Größen à côté", 2, 15), "Fünf Größen à|côté", "W UTF-8 characters count once")
eq(rows_of("bell\7 and \27[colour", 1, 20), "bell and [colour", "W control characters are dropped")
eq(rows_of("", 4, 15), "", "W an empty text has no rows")
eq(rows_of("   \n  \n", 4, 15), "", "W blank text has no rows")
eq(rows_of(("x"):rep(15), 4, 15), ("x"):rep(15), "W exactly one row")
eq(rows_of(("x"):rep(61), 4, 15), table.concat({("x"):rep(15), ("x"):rep(15), ("x"):rep(15),
	("x"):rep(15)}, "|"), "W a 61-character word fills four rows, the rest is cut")
eq(#layout.codepoints("a\255b"), 3, "W a bad byte is one placeholder code point")
eq(layout.codepoints("a\255b")[2], 0xFFFD, "W the bad byte becomes U+FFFD")

------------------------------------------------------------------------------
-- F. The font.
------------------------------------------------------------------------------
local count, missing = 0, {}
local longest = ""
for code, name in pairs(T.charmap) do
	count = count + 1
	local f = io.open(repo .. "/mods/CORE/grug_text/textures/" .. name .. ".png", "rb")
	if f then f:close() else missing[#missing + 1] = name end
	if #name > #longest then longest = name end
end
eq(count, 506, "F the table's characters")
eq(#missing, 0, "F every glyph file exists " .. table.concat(missing, " "))
local f = io.open(repo .. "/mods/CORE/grug_text/textures/" .. layout.PLACEHOLDER .. ".png", "rb")
check(f ~= nil, "F the placeholder glyph exists")
if f then f:close() end
eq(T.charmap[65], "grug_text_a_", "F A")
eq(T.charmap[97], "grug_text_a", "F a")
eq(T.charmap[0xE4], "grug_text_ae", "F ä")
eq(T.charmap[0x416] ~= nil, true, "F Cyrillic Ж")
eq(T.charmap[0x3A9] ~= nil, true, "F Greek Ω")
eq(T.charmap[0xEF], nil, "F ï has no glyph file upstream: placeholder")

------------------------------------------------------------------------------
-- T. The texture.
------------------------------------------------------------------------------
do
	local s = {lines = 2, chars = 4, ink = "#123456"}
	local w, h, bw, bh = layout.canvas(2, 4)
	eq(w .. "x" .. h .. " " .. bw .. "x" .. bh, "32x32 24x24", "T a 2x4 canvas and block")
	eq(layout.texture(layout.wrap("Ab", 2, 4), s, T.charmap),
		"[combine:32x32:10,10=grug_text_a_.png:16,10=grug_text_b.png^[multiply:#123456",
		"T one row centred both ways, the ink")
	eq(layout.texture(layout.wrap("Ab cd", 2, 4), s, T.charmap),
		"[combine:32x32:10,4=grug_text_a_.png:16,4=grug_text_b.png:10,16=grug_text_c.png:" ..
		"16,16=grug_text_d.png^[multiply:#123456", "T two rows")
	s.align, s.valign = "left", "top"
	eq(layout.texture(layout.wrap("Ab", 2, 4), s, T.charmap),
		"[combine:32x32:4,4=grug_text_a_.png:10,4=grug_text_b.png^[multiply:#123456",
		"T left and top")
	eq(layout.texture(layout.wrap("☃", 2, 4), s, T.charmap),
		"[combine:32x32:4,4=grug_text_rc.png^[multiply:#123456", "T a character without a glyph")
	eq(layout.texture(layout.wrap("   ", 2, 4), s, T.charmap), nil, "T no glyph, no texture")
	eq(select(1, layout.canvas(4, 15)) .. "x" .. select(2, layout.canvas(4, 15)), "128x64",
		"T the wall sign's canvas")
	eq(select(1, layout.canvas(3, 13)) .. "x" .. select(2, layout.canvas(3, 13)), "128x64",
		"T the chest label's canvas")
	eq(select(1, layout.canvas(7, 30)) .. "x" .. select(2, layout.canvas(7, 30)), "256x128",
		"T the notice board's canvas")
end

-- The measured lengths: every cell holding a glyph (no space), and a
-- realistic text; the bound with the longest glyph name.
local function full(lines, chars, letter)
	local rows = {}
	for i = 1, lines do rows[i] = (letter or "W"):rep(chars) end
	return table.concat(rows, "\n")
end
local prose = "The old mill road runs north past the inn; travellers should keep to the " ..
	"lit path after dark. Water at the well, bread from Marta, ask for the key at the " ..
	"smithy. Wolves were seen near the ford last week, so the gate closes at nightfall. " ..
	"Notices older than a month are taken down."
local lengths = {}
for _, case in ipairs({{"wall sign 4x15", 4, 15}, {"chest label 3x13", 3, 13},
		{"notice board 7x30", 7, 30}}) do
	local s = {lines = case[2], chars = case[3], ink = T.INK.dark}
	local full_len = #layout.texture(layout.wrap(full(case[2], case[3]), case[2], case[3]), s, T.charmap)
	local prose_len = #layout.texture(layout.wrap(prose, case[2], case[3]), s, T.charmap)
	local bound = #layout.texture(layout.wrap(full(case[2], case[3], "W"), case[2], case[3]), s,
		T.charmap) + case[2] * case[3] * (#longest - #T.charmap[87])
	lengths[#lengths + 1] = ("%s: %d bytes full (every cell), %d bytes prose, at most %d"):format(
		case[1], full_len, prose_len, bound)
	check(bound < 65535, "T " .. case[1] .. " stays below the engine's 16-bit string")
end
for _, line in ipairs(lengths) do print("texture string " .. line) end
eq(#layout.texture(layout.wrap(full(4, 15), 4, 15), {lines = 4, chars = 15, ink = T.INK.dark},
	T.charmap) > 0, true, "T a full sign has a texture")

------------------------------------------------------------------------------
-- O. Orientation: the entity stands just in front of the surface, turned so
-- that it faces the reader (its forward is the reader's look direction
-- reversed: the sprite's front is seen from its +z side), its up the text's
-- up, its x the reader's left.
------------------------------------------------------------------------------
local function near(a, b) return vector.distance(a, b) < 1e-9 end
local function frame(obj)
	return vector.rotate(V(0, 0, 1), obj.rot), vector.rotate(V(0, 1, 0), obj.rot),
		vector.rotate(V(1, 0, 0), obj.rot)
end
local SIGN_DEPTH = 7 / 16 - 1 / 64
local expected_up = {[0] = V(0, 0, -1), V(0, 0, 1), V(0, 1, 0), V(0, 1, 0), V(0, 1, 0), V(0, 1, 0)}
for p2 = 0, 5 do
	local pos = V(10 * p2, 5, 0)
	core.set_node(pos, {name = "default:sign_wall_wood", param2 = p2})
	core.registered_nodes["default:sign_wall_wood"].on_receive_fields(pos, "", {quit = "true",
		text = "Hello"}, nil)
	local obj = live(pos)[1]
	if check(obj ~= nil, "O sign param2 " .. p2 .. " has its entity") then
		local d = wall_dirs[p2]
		local forward, up, right = frame(obj)
		check(near(obj.pos, vector.add(pos, vector.multiply(d, SIGN_DEPTH))),
			"O sign param2 " .. p2 .. " stands just in front of the board")
		check(near(forward, vector.multiply(d, -1)), "O sign param2 " .. p2 .. " faces the reader")
		check(near(up, expected_up[p2]), "O sign param2 " .. p2 .. " text up")
		check(near(vector.cross(up, forward), right) or near(vector.cross(forward, up), right),
			"O sign param2 " .. p2 .. " is a rotation")
	end
end
local LABEL_Y = -5 / 16 + 0.5 / 128
for p2 = 0, 3 do
	local pos = V(10 * p2, 20, 0)
	core.set_node(pos, {name = "default:chest", param2 = p2})
	meta_at(pos):set_string("grug_label", "Ore")
	default.containers.update_infotext(pos)
	local obj = live(pos)[1]
	if check(obj ~= nil, "O chest facedir " .. p2 .. " has its label") then
		local back = facedir_dirs[p2]
		local forward, up = frame(obj)
		check(near(obj.pos, vector.add(pos, vector.add(vector.multiply(back, -(0.5 + 1 / 64)),
			V(0, LABEL_Y, 0)))), "O chest facedir " .. p2 .. " label in front of the lower front")
		check(near(forward, vector.multiply(back, -1)), "O chest facedir " .. p2 .. " faces the reader")
		check(near(up, V(0, 1, 0)), "O chest facedir " .. p2 .. " upright")
	end
end

------------------------------------------------------------------------------
-- L. The lifecycle.
------------------------------------------------------------------------------
local sign = core.registered_nodes["default:sign_wall_wood"]
local function write(pos, text)
	core.registered_nodes[core.get_node(pos).name].on_receive_fields(pos, "", {quit = "true",
		text = text}, nil)
end
do
	local pos = V(100, 0, 0)
	core.set_node(pos, {name = "default:sign_wall_wood", param2 = 2})
	eq(#live(pos), 0, "L a new sign has no entity")
	check(sign.groups.grug_text == 1, "L the sign joins the LBM's group")
	eq(sign.tiles[1], "x.png", "L the board's tile is left to the art")
	write(pos, "First words")
	local first = live(pos)
	eq(#first, 1, "L writing makes one entity")
	local obj = first[1]
	check(obj.props.textures[1]:find("^%[combine:128x64:") ~= nil and
		obj.props.textures[1]:find("#2b1e14", 1, true) ~= nil, "L the dark ink on wood")
	eq(obj.props.textures[2], "blank.png", "L one face only")
	eq(obj.props.visual_size.x .. "x" .. obj.props.visual_size.y, "1x0.5", "L the sign's size")
	eq(obj.props.static_save, false, "L not saved")
	eq(obj.props.pointable, false, "L not pointable")
	check(obj.armor and obj.armor.immortal == 1, "L immortal")
	local before = sends
	write(pos, "First words")
	eq(sends, before, "L the same text sends nothing")
	write(pos, "Second words")
	eq(#live(pos), 1, "L a rewrite keeps one entity")
	eq(live(pos)[1], obj, "L the rewrite updates the same entity")
	check(obj.props.textures[1]:find("grug_text_s_.png", 1, true) ~= nil, "L the new text")
	write(pos, "")
	eq(#live(pos), 0, "L clearing removes the entity")
	write(pos, "Again")
	eq(#live(pos), 1, "L written again")
	unload(pos)
	eq(#live(pos), 0, "L unloaded with its block")
	run_lbm(pos)
	eq(#live(pos), 1, "L the LBM recreates it")
	run_lbm(pos)
	eq(#live(pos), 1, "L a second activation makes no duplicate")
	-- A stray duplicate (any cause) is removed by the next refresh.
	core.add_entity(live(pos)[1].pos, "grug_text:text"):get_luaentity()._grug_pos = vector.copy(pos)
	objects[#objects].get_luaentity(objects[#objects])._grug_index = 1
	eq(#live(pos), 2, "L a stray duplicate")
	T.refresh(pos)
	eq(#live(pos), 1, "L refresh removes the duplicate")
	_G.sign_destructs = 0
	core.remove_node(pos)
	eq(#live(pos), 0, "L digging removes it")
	eq(_G.sign_destructs, 1, "L the sign's own after_destruct still runs")
	-- An empty sign at load: no entity, no search.
	core.set_node(pos, {name = "default:sign_wall_wood", param2 = 2})
	run_lbm(pos)
	eq(#live(pos), 0, "L no entity for an empty sign at load")
	-- The neighbour's entity is not taken for this node's.
	local next_pos = V(101, 0, 0)
	core.set_node(next_pos, {name = "default:sign_wall_wood", param2 = 3})
	write(next_pos, "Next door")
	write(pos, "Here")
	eq(#live(pos) .. "/" .. #live(next_pos), "1/1", "L neighbours keep one each")
end
do
	local pos = V(200, 0, 0)
	core.set_node(pos, {name = "grug_materials:iron_sign_wall", param2 = 4})
	write(pos, "Iron")
	check(live(pos)[1].props.textures[1]:find("#2b1e14", 1, true) ~= nil, "L the iron sign's dark ink")
end
do
	local api = default.containers
	local pos = V(300, 0, 0)
	core.set_node(pos, {name = "default:chest_locked", param2 = 0})
	api.update_infotext(pos)
	eq(#live(pos), 0, "L an unlabelled chest has no entity")
	meta_at(pos):set_string(api.LABEL_KEY, api.clean_label(("Copper ore and tin for the bronze " ..
		"works by the river")))
	api.update_infotext(pos)
	local obj = live(pos)[1]
	if check(obj ~= nil, "L a label save makes the entity") then
		local glyphs = select(2, obj.props.textures[1]:gsub("=", ""))
		-- "Copper ore|and tin for|the bronze": "works" no longer fits.
		eq(glyphs, 27, "L the label wraps into 3 x 13, the rest is cut")
		check(obj.props.textures[1]:find(T.INK.dark, 1, true) ~= nil, "L dark ink on the wooden tier")
		eq(obj.props.visual_size.x .. "x" .. obj.props.visual_size.y, "1x0.5", "L the label's size")
	end
	-- Open and close: swap_node to the open variant and back, no call.
	local at = vector.copy(obj.pos)
	core.swap_node(pos, {name = "default:chest_locked_open", param2 = 0})
	run_lbm(pos)
	eq(#live(pos), 1, "L open: still one label")
	check(near(live(pos)[1].pos, at), "L open: the label stays on the front")
	core.swap_node(pos, {name = "default:chest_locked", param2 = 0})
	run_lbm(pos)
	eq(#live(pos), 1, "L closed again: one label")
	-- The upgrade: swap_node to the next tier and its refresh (containers.lua).
	core.swap_node(pos, {name = "default:chest_locked_steel", param2 = 0})
	api.info("default:chest_locked_steel").refresh(pos)
	eq(#live(pos), 1, "L upgraded: one label")
	check(live(pos)[1].props.textures[1]:find(T.INK.light, 1, true) ~= nil,
		"L light ink on the Steel-Reinforced tier")
	core.swap_node(pos, {name = "default:chest_locked_abyssal_open", param2 = 0})
	api.info("default:chest_locked_abyssal_open").refresh(pos)
	eq(#live(pos), 1, "L upgraded while open: one label")
	check(live(pos)[1].props.textures[1]:find(T.INK.light, 1, true) ~= nil,
		"L light ink on the Abyssal tier")
	meta_at(pos):set_string(api.LABEL_KEY, "")
	api.update_infotext(pos)
	eq(#live(pos), 0, "L clearing the label removes it")
	meta_at(pos):set_string(api.LABEL_KEY, "Gems")
	api.update_infotext(pos)
	core.remove_node(pos)
	eq(#live(pos), 0, "L digging the chest removes it")
	-- A node that is no surface any more (swapped to something else).
	core.set_node(pos, {name = "default:chest", param2 = 0})
	meta_at(pos):set_string(api.LABEL_KEY, "Seeds")
	api.update_infotext(pos)
	core.swap_node(pos, {name = "air"})
	T.refresh(pos)
	eq(#live(pos), 0, "L a swap to a plain node removes it on refresh")
end
do
	-- Two-sided and multi-surface descriptions (lane SIGNS' waypost and notice board).
	core.register_node("probe:post", {paramtype2 = "degrotate", groups = {}})
	T.register("probe:post", {
		{lines = 1, chars = 14, faces = 2, offset = {x = 0, y = 0.1, z = -0.1}},
		{lines = 1, chars = 14, offset = {x = 0, y = -0.2, z = 0.1}, ink = "#ffffff",
			text = function(_, _, meta) return meta:get_string("back") end},
	})
	local pos = V(400, 0, 0)
	core.set_node(pos, {name = "probe:post", param2 = 60})
	meta_at(pos):set_string("text", "North Gate")
	T.refresh(pos)
	local list = live(pos)
	eq(#list, 1, "L only the written surface has an entity")
	eq(list[1].props.textures[2], list[1].props.textures[1], "L faces = 2: the back shows the text")
	local forward = frame(list[1])
	check(near(forward, V(1, 0, 0)), "L degrotate 60 (90 degrees) turns the surface")
	-- The offset's x is the reader's right: the reader looks along -x here,
	-- so the right is +z... and the depth -0.1 is towards the reader (+x).
	check(near(list[1].pos, vector.add(pos, V(0.1, 0.1, 0))), "L the offset in the turned frame")
	meta_at(pos):set_string("back", "Mill")
	T.refresh(pos)
	eq(#live(pos), 2, "L a second surface, a second entity")
	run_lbm(pos)
	eq(#live(pos), 2, "L the LBM keeps both, no duplicate")
	meta_at(pos):set_string("text", "")
	T.refresh(pos)
	eq(#live(pos), 1, "L the cleared surface's entity goes, the other stays")
	check(T.surfaces("probe:post")[2].visual_size.x == 128 / 128, "L the second surface's size")
	-- The offset's x is the reader's right: facing west (look -x), right is +z.
	core.register_node("probe:right", {paramtype2 = "degrotate", groups = {}})
	T.register("probe:right", {lines = 1, chars = 4, offset = {x = 0.3, y = 0, z = 0}})
	local rpos = V(410, 0, 0)
	core.set_node(rpos, {name = "probe:right", param2 = 60})
	meta_at(rpos):set_string("text", "R")
	T.refresh(rpos)
	check(near(live(rpos)[1].pos, vector.add(rpos, V(0, 0, 0.3))), "L offset x is the reader's right")
end

------------------------------------------------------------------------------
-- H. No hover text (the user, 2026-10-31).
------------------------------------------------------------------------------
do
	-- The vendored wall sign's handler writes the text and no infotext.
	local f = assert(io.open(repo .. "/mods/BASE/default/nodes.lua", "rb"))
	local source = f:read("*a")
	f:close()
	local body = source:match("local function register_sign%(.-\nend\n")
	if check(body ~= nil, "H default/nodes.lua's register_sign found") then
		check(body:find('set_string("text", text)', 1, true) ~= nil, "H the wall sign writes its text")
		eq(body:find("infotext", 1, true), nil, "H the wall sign writes no hover text")
	end

	local api = default.containers
	local function desc(name) return core.registered_nodes[name].description end
	-- A chest's hover text is its name, a locked chest's with the owner,
	-- never the label.
	local pos = V(500, 0, 0)
	core.set_node(pos, {name = "default:chest_steel", param2 = 0})
	meta_at(pos):set_string(api.LABEL_KEY, "Ores")
	api.update_infotext(pos)
	eq(meta_at(pos):get_string("infotext"), desc("default:chest_steel"), "H a labelled chest's hover text is its name")
	eq(#live(pos), 1, "H ...and the label is on the front")
	local lpos = V(502, 0, 0)
	core.set_node(lpos, {name = "default:chest_locked", param2 = 0})
	meta_at(lpos):set_string("owner", "bob")
	meta_at(lpos):set_string(api.LABEL_KEY, "Gold")
	api.update_infotext(lpos)
	eq(meta_at(lpos):get_string("infotext"), desc("default:chest_locked") .. " (owned by bob)",
		"H a locked chest's hover text names its owner, not its label")

	-- The one-time LBM.
	local drop
	for _, lbm in ipairs(lbms) do
		if lbm.name == "grug_text:drop_hover_text" then drop = lbm end
	end
	if check(drop ~= nil, "H the LBM that drops old hover text") then
		eq(drop.run_at_every_load, false, "H it runs once per block")
		local names = {}
		for _, name in ipairs(drop.nodenames) do names[name] = true end
		check(names["default:sign_wall_wood"] and names["grug_materials:iron_sign_wall"],
			"H it covers both wall signs")
		local all = true
		for tier = 1, #api.TIERS do
			for _, base in ipairs({"default:chest", "default:chest_locked"}) do
				local name = api.tier_name(base, tier)
				all = all and names[name] and names[name .. "_open"]
			end
		end
		check(all, "H it covers every chest tier, normal and locked, closed and open")
		eq(#drop.nodenames, 2 + 4 * #api.TIERS, "H and nothing else")

		-- A sign written before: its text stays, the hover text goes.
		local spos = V(510, 0, 0)
		core.set_node(spos, {name = "default:sign_wall_wood", param2 = 2})
		meta_at(spos):set_string("text", "Old words")
		meta_at(spos):set_string("infotext", '"Old words"')
		drop.action(spos, core.get_node(spos), 0)
		eq(meta_at(spos):get_string("infotext"), "", "H an old sign's hover text is dropped")
		eq(meta_at(spos):get_string("text"), "Old words", "H ...its text kept")
		run_lbm(spos)
		eq(#live(spos), 1, "H ...and shown on the board")
		-- A labelled chest from before: the name stays, the label line goes.
		meta_at(pos):set_string("infotext", "Ores\n" .. desc("default:chest_steel"))
		drop.action(pos, core.get_node(pos), 0)
		eq(meta_at(pos):get_string("infotext"), desc("default:chest_steel"),
			"H an old chest label leaves the hover text")
		eq(meta_at(pos):get_string(api.LABEL_KEY), "Ores", "H ...the label kept")
		eq(#live(pos), 1, "H ...one label on the front")
		core.swap_node(lpos, {name = "default:chest_locked_open", param2 = 0})
		meta_at(lpos):set_string("infotext", "Gold\n" .. desc("default:chest_locked") .. " (owned by bob)")
		drop.action(lpos, core.get_node(lpos), 0)
		eq(meta_at(lpos):get_string("infotext"), desc("default:chest_locked") .. " (owned by bob)",
			"H an open locked chest keeps its name and owner")
		-- An unlabelled chest keeps its hover text.
		local upos = V(504, 0, 0)
		core.set_node(upos, {name = "default:chest", param2 = 0})
		meta_at(upos):set_string("infotext", desc("default:chest"))
		drop.action(upos, core.get_node(upos), 0)
		eq(meta_at(upos):get_string("infotext"), desc("default:chest"), "H an unlabelled chest is left alone")
		eq(#live(upos), 0, "H ...without a label")
	end
end

if failures > 0 then
	print(("R68 TEXT PORTABLE FAIL %d of %d checks"):format(failures, checks))
	error("R68 TEXT portable fixture failed")
end
print(("R68 TEXT PORTABLE PASS checks=%d"):format(checks))
