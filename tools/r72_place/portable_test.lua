-- Round 72 lane PLACE portable test (LuaJIT; round72-plan.md §2.2, §4 PLACE).
-- The whole game's real registrations and placement code
-- (tools/r57_details/game_harness.lua: the doors, beds, torches, the water
-- bucket, the notice board, the Claim Stone) on a small world, with the REAL
-- grug_core/placement.lua loaded over a transcription of builtin
-- core.item_place / core.item_place_node (builtin/game/item.lua: right-click,
-- the buildable test, protection, add_node) and of the falling node's
-- try_place (builtin/game/falling.lua: the landing cell, add_node). Checks:
--   O  out of combat a block, a ladder, a torch, water from the bucket, a
--      door, a bed and the notice board place as before;
--   C  in combat the block, the ladder, the water, the door, the bed, the
--      board and the Claim Stone are refused with the grey feed line, the
--      stack and the bucket stay; a torch (floor and wall) and a plant still
--      place; a right-click on a chest still opens it;
--   B  in or out of combat a walkable node never goes into a cell a live
--      mob's or player's box overlaps: the feet and head cells, a cell the
--      box only partly covers, the placer's own partial cell, a door's upper
--      cell, a bed's second cell; a box that only touches the face, a dead
--      mob, an item entity and a non-walkable torch or water do not refuse;
--      a non-player placer is refused silently;
--   F  a walkable falling node that lands in a body's cell drops as an item
--      (dropped from above, its support dug, onto a buildable plant); with
--      nobody there it lands as before;
--   P  protected placement unchanged: builtin's violation and no combat or
--      body line, for the seam and for a door;
--   Q  cost: one area query per walkable placement out of combat (also for a
--      two-cell door), none for a torch, none for an in-combat refusal, one
--      per walkable landing.
-- Usage (repo root): luajit tools/r72_place/portable_test.lua [REPO]
-- Prints "R72 PLACE PORTABLE PASS checks=<n>" or raises.
local repo = arg and arg[1] or "."
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local nodes = game.nodes
nodes["air"] = nodes["air"] or {name = "air", type = "node", walkable = false,
	buildable_to = true, groups = {}}
core.nodedef_default = {walkable = true, buildable_to = false}
-- builtin's registration defaults (register.lua nodedef_default), which the
-- harness does not fill in.
for _, def in pairs(nodes) do
	if def.walkable == nil then def.walkable = true end
	if def.buildable_to == nil then def.buildable_to = false end
	if def.liquidtype == nil then def.liquidtype = "none" end
end

-- The small world -------------------------------------------------------------
local world, protected, violations, metas = {}, {}, {}, {}
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local function P(x, y, z) return {x = x, y = y, z = z} end
local function put(pos, name, param2) world[key(pos)] = {name = name, param2 = param2 or 0} end
local function at(pos) return (world[key(pos)] or {name = "air"}).name end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return P(x.x, x.y, x.z) end
		return P(x, y, z)
	end,
	copy = function(a) return P(a.x, a.y, a.z) end,
	add = function(a, b)
		if type(b) == "number" then return P(a.x + b, a.y + b, a.z + b) end
		return P(a.x + b.x, a.y + b.y, a.z + b.z)
	end,
	subtract = function(a, b)
		if type(b) == "number" then return P(a.x - b, a.y - b, a.z - b) end
		return P(a.x - b.x, a.y - b.y, a.z - b.z)
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
}
-- grug_signs keeps a vector from its load (UP); load it again over this one.
do
	local register = grug_text.register
	grug_text.register = function() end -- registered once already
	assert(loadfile(repo .. "/mods/ITEMS/grug_signs/init.lua"))()
	grug_text.register = register
end
nodes = game.nodes
core.get_node = function(pos) return world[key(pos)] or {name = "air", param2 = 0} end
core.get_node_or_nil = core.get_node
core.set_node = function(pos, node)
	world[key(pos)] = {name = node.name, param2 = node.param2 or 0}
	return true
end
core.add_node, core.swap_node = core.set_node, core.set_node
core.remove_node = function(pos) world[key(pos)] = nil end
core.get_meta = function(pos)
	local k = key(pos)
	metas[k] = metas[k] or {set_int = function() end, set_string = function() end,
		get_string = function() return "" end, get_int = function() return 0 end}
	return metas[k]
end
core.is_protected = function(pos) return protected[key(pos)] == true end
core.record_protection_violation = function(pos, name)
	violations[#violations + 1] = key(pos) .. ":" .. tostring(name)
end
core.is_creative_enabled = function() return false end
core.check_player_privs = function() return false end
core.sound_play = function() end
core.registered_on_placenodes = {}
core.dir_to_facedir = function(dir)
	if math.abs(dir.x) > math.abs(dir.z) then return dir.x < 0 and 3 or 1 end
	return dir.z < 0 and 2 or 0
end
core.dir_to_fourdir = core.dir_to_facedir
core.facedir_to_dir = function(facedir)
	return ({P(0, 0, 1), P(1, 0, 0), P(0, 0, -1), P(-1, 0, 0)})[facedir % 4 + 1]
end
core.dir_to_wallmounted = function(dir)
	if math.abs(dir.y) > math.max(math.abs(dir.x), math.abs(dir.z)) then
		return dir.y < 0 and 1 or 0
	end
	if math.abs(dir.x) > math.abs(dir.z) then return dir.x < 0 and 3 or 2 end
	return dir.z < 0 and 5 or 4
end

-- Objects: players and mobs with collision boxes, an item entity.
local objects, queries = {}, 0
core.get_objects_inside_radius = function(pos, radius)
	queries = queries + 1
	local out = {}
	for _, object in ipairs(objects) do
		if vector.distance(object.pos, pos) <= radius then out[#out + 1] = object end
	end
	return out
end
local PLAYER_BOX = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}
local function new_player(name, pos)
	local p = {name = name, pos = pos, hp = 20, sneak = false}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return P(self.pos.x, self.pos.y, self.pos.z) end
	function p:get_hp() return self.hp end
	function p:get_properties() return {collisionbox = PLAYER_BOX} end
	function p:get_luaentity() return nil end
	function p:get_player_control() return {sneak = self.sneak} end
	function p:get_look_dir() return P(0, 0, 1) end
	function p:get_wielded_item() return ItemStack("") end
	return p
end
local function new_entity(pos, entity)
	local o = {pos = pos, entity = entity}
	function o:is_player() return false end
	function o:get_pos() return P(self.pos.x, self.pos.y, self.pos.z) end
	function o:get_luaentity() return self.entity end
	return o
end
local MOB_BOX = {-0.4, -0.01, -0.4, 0.4, 1.4, 0.4}
local function new_mob(pos, fields)
	local entity = {_cmi_is_mob = true, health = 30, state = "stand", _grug_cbox = MOB_BOX}
	for k, v in pairs(fields or {}) do entity[k] = v end
	return new_entity(pos, entity)
end

-- builtin core.item_place and core.item_place_node, transcribed to what the
-- placement needs (builtin/game/item.lua).
local function builtin_item_place_node(itemstack, placer, pointed, param2)
	local def = itemstack:get_definition()
	if def.type ~= "node" or pointed.type ~= "node" then return itemstack, nil end
	local under_def = nodes[core.get_node(pointed.under).name] or core.nodedef_default
	local above_def = nodes[core.get_node(pointed.above).name] or core.nodedef_default
	if not above_def.buildable_to and not under_def.buildable_to then return itemstack, nil end
	local place_to = vector.copy(pointed.above)
	if under_def.buildable_to then place_to = vector.copy(pointed.under) end
	local name = placer and placer:get_player_name() or ""
	if core.is_protected(place_to, name) then
		core.record_protection_violation(place_to, name)
		return itemstack, nil
	end
	core.add_node(place_to, {name = def.name, param2 = param2 or 0})
	itemstack:take_item()
	return itemstack, place_to
end
core.item_place_node = builtin_item_place_node
core.item_place = function(itemstack, placer, pointed, param2)
	if pointed.type == "node" and placer and not placer:get_player_control().sneak then
		local n = core.get_node(pointed.under)
		local def = nodes[n.name]
		if def and def.on_rightclick then
			return def.on_rightclick(pointed.under, n, placer, itemstack, pointed) or itemstack, nil
		end
	end
	if itemstack:get_definition().type == "node" then
		return core.item_place_node(itemstack, placer, pointed, param2)
	end
	return itemstack, nil
end

-- builtin's falling node, its try_place transcribed (builtin/game/falling.lua:
-- the cell it lands in, then add_node) and the on_step failure path (drop the
-- node as an item).
local dropped = {}
local falling_proto = {}
falling_proto.__index = falling_proto
function falling_proto.try_place(self, bcp, bcn)
	local bcd = nodes[bcn.name]
	local np = vector.copy(bcp)
	if bcd and bcd.buildable_to then
		core.remove_node(bcp)
	else
		np.y = np.y + 1
	end
	core.add_node(np, self.node)
	return true
end
core.registered_entities["__builtin:falling_node"] = falling_proto
local function land(name, bcp)
	local entity = setmetatable({node = {name = name}}, falling_proto)
	if not entity:try_place(bcp, core.get_node(bcp)) then
		dropped[#dropped + 1] = name
		return false
	end
	return true
end

-- The REAL placement module over these stubs (the harness loaded it over its
-- own permissive engine: load it again so it wraps the transcription).
local feed = {}
grug_core.feed = function(player, kind, text, feed_key)
	feed[#feed + 1] = {name = player:get_player_name(), kind = kind, text = text, key = feed_key}
	return true
end
local combat = {}
grug_core.in_combat = function(player) return combat[player:get_player_name()] == true end
grug_core.combat_eye_pos = function(player)
	local pos = player:get_pos()
	return P(pos.x, pos.y + 1.6, pos.z)
end
grug_core.world_alterable = function() return true end
assert(loadfile(repo .. "/mods/CORE/grug_core/placement.lua"))()
local LINES = grug_core.placement
check(core.item_place_node ~= builtin_item_place_node, "S the seam wraps core.item_place_node")
check(falling_proto.try_place ~= nil and rawget(falling_proto, "try_place") ~= nil,
	"S the falling node's try_place is wrapped on its prototype")

-- The ground: cobble at y = 0 for x -2..60, z -2..2.
for x = -2, 60 do
	for z = -2, 2 do put(P(x, 0, z), "default:cobble") end
end
local placer = new_player("builder", P(0, 0.5, -1.5))
objects[#objects + 1] = placer
local function pointed(x, z, y)
	y = y or 0
	return {type = "node", under = P(x, y, z), above = P(x, y + 1, z)}
end
local function place(item, x, z, who)
	local stack = ItemStack(item)
	local def = stack:get_definition()
	local on_place = def.on_place or core.item_place
	local before = #feed
	-- The placer stands beside the target, within the bucket's reach.
	placer.pos = P(x, 0.5, -1.5)
	queries = 0
	local result = on_place(stack, who or placer, pointed(x, z))
	return result, feed[before + 1], queries
end
local function reset_cells(x)
	for y = 1, 3 do
		for dx = -1, 1 do
			for z = -1, 1 do world[key(P(x + dx, y, z))] = nil end
		end
	end
end

local BLOCK, LADDER, TORCH = "default:cobble", "default:ladder_wood", "grug_materials:torch"
if not nodes[TORCH] then TORCH = "default:torch" end
local PLANT = "default:grass_1"
local BUCKET, EMPTY = "grug_farming:water_bucket", "grug_farming:empty_iron_bucket"
local DOOR, BED, BOARD = "doors:door_wood", "beds:bed_bottom", "grug_signs:notice_board"
check(nodes[LADDER].walkable == false and nodes[LADDER].climbable == true,
	"S the ladder blocks nobody but climbs (walkable false, climbable)")
check(nodes[TORCH].walkable == false, "S the torch is not walkable")
check(nodes["default:water_source"].liquidtype == "source", "S water is a liquid")

-- O. out of combat --------------------------------------------------------------
local r, line, q = place(BLOCK, 2, 0)
eq(at(P(2, 1, 0)), BLOCK, "O a block places")
eq(line, nil, "O no line for a placed block")
eq(q, 1, "Q one area query for a walkable placement")
place(LADDER, 3, 0)
eq(at(P(3, 1, 0)), LADDER, "O a ladder places")
r, line, q = place(TORCH, 4, 0)
check(at(P(4, 1, 0)):find("torch") ~= nil, "O a torch places")
eq(q, 0, "Q no area query for a torch")
r, line, q = place(BUCKET, 6, 0)
eq(at(P(6, 1, 0)), "default:water_source", "O the bucket pours water")
eq(r:get_name(), EMPTY, "O the bucket is empty after pouring")
eq(q, 0, "Q no area query for water")
r, line, q = place(DOOR, 8, 0)
eq(at(P(8, 1, 0)), DOOR .. "_a", "O a door places its bottom")
eq(at(P(8, 2, 0)), "doors:hidden", "O and its hidden top")
eq(q, 1, "Q one area query for the door's two cells")
place(BED, 10, 0)
eq(at(P(10, 1, 0)), "beds:bed_bottom", "O a bed places its bottom")
eq(at(P(10, 1, 1)), "beds:bed_top", "O and its top in front")
place(BOARD, 13, 0)
eq(at(P(13, 1, 0)) ~= "air" and at(P(14, 1, 0)) ~= "air" or
	at(P(12, 1, 0)) ~= "air", true, "O the notice board places both halves")

-- C. in combat ------------------------------------------------------------------
for x = 2, 15 do reset_cells(x) end
combat.builder = true
local function refused_in_combat(item, x, label, cells)
	local stack, refusal, count = place(item, x, 0)
	for _, cell in ipairs(cells or {P(x, 1, 0)}) do
		eq(at(cell), "air", "C " .. label .. " is refused in combat " .. key(cell))
	end
	check(refusal ~= nil and refusal.text == LINES.COMBAT_LINE and refusal.kind == "combat"
		and refusal.key == "placement", "C " .. label .. ": the grey combat line")
	eq(count, 0, "Q no area query for an in-combat refusal (" .. label .. ")")
	return stack
end
local stack = refused_in_combat(BLOCK, 2, "a block")
eq(stack:get_count(), 1, "C the refused block stays in the stack")
refused_in_combat(LADDER, 3, "a ladder")
stack = refused_in_combat(BUCKET, 6, "water from the bucket")
eq(stack:get_name(), BUCKET, "C the bucket stays full")
refused_in_combat(DOOR, 8, "a door", {P(8, 1, 0), P(8, 2, 0)})
refused_in_combat(BED, 10, "a bed", {P(10, 1, 0), P(10, 1, 1)})
refused_in_combat(BOARD, 13, "the notice board", {P(12, 1, 0), P(13, 1, 0), P(14, 1, 0)})
do
	local validated = false
	local saved = grug_housing.validate_placement
	grug_housing.validate_placement = function() validated = true; return true end
	refused_in_combat("grug_housing:claim_stone", 16, "the Claim Stone")
	check(validated, "C the Claim Stone refusal comes after its own placement rules")
	grug_housing.validate_placement = saved
end
r, line = place(TORCH, 4, 0)
check(at(P(4, 1, 0)):find("torch") ~= nil and line == nil, "C a floor torch still places")
do
	local stack2 = ItemStack(TORCH)
	local pt = {type = "node", under = P(5, 1, 1), above = P(5, 1, 0)}
	put(P(5, 1, 1), BLOCK)
	nodes[TORCH].on_place(stack2, placer, pt)
	check(at(P(5, 1, 0)):find("torch") ~= nil, "C a wall torch still places")
end
r, line = place(PLANT, 7, 0)
check(at(P(7, 1, 0)):find("^default:grass_") ~= nil and line == nil, "C a plant still places")
do
	local opened = false
	nodes["default:chest"].on_rightclick = function() opened = true end
	put(P(9, 1, 0), "default:chest")
	core.item_place(ItemStack(BLOCK), placer,
		{type = "node", under = P(9, 1, 0), above = P(9, 2, 0)})
	check(opened and at(P(9, 2, 0)) == "air", "C a right-click on a chest still opens it")
end
combat.builder = nil

-- B. bodies ---------------------------------------------------------------------
for x = 2, 16 do reset_cells(x) end
local mob = new_mob(P(20, 0.5, 0))                -- cells (20,1) and (20,2)
local partial = new_mob(P(24.4, 0.5, 0))          -- x 24.0..24.8: cells 24 and 25
local other = new_player("bystander", P(28, 0.5, 0)) -- cells (28,1) and (28,2)
local touching = new_mob(P(32.9, 0.5, 0))         -- x 32.5..33.3: touches cell 32
local dead = new_mob(P(36, 0.5, 0), {health = 0, state = "die"})
local item = new_entity(P(38, 1.25, 0), {name = "__builtin:item"})
for _, object in ipairs({mob, partial, other, touching, dead, item}) do
	objects[#objects + 1] = object
end
local function refused_body(item_name, x, label, y)
	local stack2 = ItemStack(item_name)
	local def = stack2:get_definition()
	local before = #feed
	local pt = {type = "node", under = P(x, (y or 1) - 1, 0), above = P(x, y or 1, 0)}
	if y and y > 1 then put(P(x, y - 1, 0), BLOCK) end
	local _, placed_at = (def.on_place or core.item_place)(stack2, placer, pt)
	local refusal = feed[before + 1]
	if y and y > 1 then world[key(P(x, y - 1, 0))] = nil end
	eq(at(P(x, y or 1, 0)), "air", "B " .. label .. " is refused")
	check(refusal ~= nil and refusal.text == LINES.BODY_LINE and refusal.kind == "combat",
		"B " .. label .. ": the body line")
	return placed_at
end
refused_body(BLOCK, 20, "a block into a mob's feet cell")
-- The head cell: pointed from a pillar beside it (the cell above the feet).
do
	local before = #feed
	put(P(21, 2, 0), BLOCK)
	core.item_place(ItemStack(BLOCK), placer, {type = "node", under = P(21, 2, 0), above = P(20, 2, 0)})
	world[key(P(21, 2, 0))] = nil
	eq(at(P(20, 2, 0)), "air", "B a block into a mob's head cell is refused")
	eq(feed[before + 1] and feed[before + 1].text, LINES.BODY_LINE, "B the head cell's body line")
end
refused_body(BLOCK, 24, "a block into the partial mob's own cell")
refused_body(BLOCK, 25, "a block into a cell the mob's box only partly covers")
place(BLOCK, 26, 0)
eq(at(P(26, 1, 0)), BLOCK, "B the cell beyond the partial mob's box is free")
reset_cells(26)
refused_body(BLOCK, 28, "a block into another player's cell")
do
	local before = #feed
	placer.pos = P(0, 0.5, -1.5) -- its box reaches z -1.8..-1.2
	core.item_place(ItemStack(BLOCK), placer, pointed(0, -1))
	-- Round 78 ruling 8 reverses this case: the placer's own body is exempt.
	eq(at(P(0, 1, -1)), BLOCK, "B a block into the placer's own partial cell places (Round 78)")
	eq(#feed, before, "B ...without a body line")
	world[key(P(0, 1, -1))] = nil
end
place(BLOCK, 32, 0)
eq(at(P(32, 1, 0)), BLOCK, "B a box that only touches the face does not refuse")
place(BLOCK, 36, 0)
eq(at(P(36, 1, 0)), BLOCK, "B a dead mob does not refuse")
place(BLOCK, 38, 0)
eq(at(P(38, 1, 0)), BLOCK, "B an item entity does not refuse")
for _, x in ipairs({32, 36, 38}) do reset_cells(x) end
place(TORCH, 20, 0)
check(at(P(20, 1, 0)):find("torch") ~= nil, "B a torch goes into a mob's cell")
reset_cells(20)
place(BUCKET, 28, 0)
eq(at(P(28, 1, 0)), "default:water_source", "B water goes into a player's cell")
reset_cells(28)
-- A door whose upper cell only the body covers: a mob one node higher.
do
	local high = new_mob(P(42, 1.5, 0)) -- cells (42,2) and (42,3)
	objects[#objects + 1] = high
	local before = #feed
	game.items[DOOR].on_place(ItemStack(DOOR), placer, pointed(42, 0))
	eq(at(P(42, 1, 0)), "air", "B a door whose upper cell holds a body is refused")
	eq(feed[before + 1] and feed[before + 1].text, LINES.BODY_LINE, "B the door's body line")
	objects[#objects] = nil
end
-- A bed whose second cell (in front, +z) holds a body.
do
	local front = new_mob(P(46, 0.5, 1))
	objects[#objects + 1] = front
	local before = #feed
	nodes[BED].on_place(ItemStack(BED), placer, pointed(46, 0))
	eq(at(P(46, 1, 0)), "air", "B a bed whose second cell holds a body is refused")
	eq(feed[before + 1] and feed[before + 1].text, LINES.BODY_LINE, "B the bed's body line")
	objects[#objects] = nil
end
do
	local before = #feed
	local _, placed_at = core.item_place_node(ItemStack(BLOCK), nil, pointed(20, 0))
	check(placed_at == nil and at(P(20, 1, 0)) == "air" and #feed == before,
		"B a non-player placer is refused silently")
end
combat.builder = true
r, line = place(BLOCK, 20, 0)
eq(line and line.text, LINES.COMBAT_LINE, "B in combat the combat line comes first")
combat.builder = nil

-- F. falling nodes --------------------------------------------------------------
queries = 0
check(not land("default:sand", P(20, 0, 0)), "F sand dropped onto a mob drops as an item")
eq(at(P(20, 1, 0)), "air", "F nothing lands in the mob's cell")
eq(queries, 1, "Q one area query per walkable landing")
-- Its support dug: sand that rested above the partial mob falls to the ground.
check(not land("default:sand", P(24, 0, 0)), "F sand whose support was dug drops beside the mob")
check(not land("default:gravel", P(25, 0, 0)), "F gravel into the partly covered cell drops")
put(P(28, 1, 0), PLANT)
check(not land("default:sand", P(28, 1, 0)), "F sand onto a plant in a player's cell drops")
eq(at(P(28, 1, 0)), PLANT, "F the plant stays")
eq(#dropped, 4, "F four drops")
check(land("default:sand", P(50, 0, 0)) and at(P(50, 1, 0)) == "default:sand",
	"F with nobody there the sand lands as before")
put(P(52, 1, 0), PLANT)
check(land("default:sand", P(52, 1, 0)) and at(P(52, 1, 0)) == "default:sand",
	"F onto a plant with nobody there it replaces the plant as before")

-- P. protection -----------------------------------------------------------------
protected[key(P(20, 1, 0))] = true
protected[key(P(54, 1, 0))] = true
local before_feed, before_violations = #feed, #violations
place(BLOCK, 20, 0)
eq(#violations, before_violations + 1, "P a protected body cell records builtin's violation")
eq(#feed, before_feed, "P and shows no body line")
combat.builder = true
place(BLOCK, 54, 0)
eq(#violations, before_violations + 2, "P a protected cell in combat records the violation")
eq(#feed, before_feed, "P and shows no combat line")
protected[key(P(56, 1, 0))] = true
place(DOOR, 56, 0)
eq(#violations, before_violations + 3, "P a protected door records the violation")
eq(#feed, before_feed, "P and shows no combat line for the door")
combat.builder = nil
place(BLOCK, 58, 0)
eq(at(P(58, 1, 0)), BLOCK, "P an unprotected free cell still places")

if failures > 0 then
	error(("R72 PLACE PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R72 PLACE PORTABLE PASS checks=" .. checks)
