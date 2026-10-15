-- Round 49 lane VIS portable test (LuaJIT): node items at 70 % in the
-- third-person hand (round49-gameplay-draft.md ruling 8).
--
--   luajit tools/r49_vis/portable_test.lua [REPO]
--
-- Loads the REAL grug_visuals files and player_api against stubs:
--   S. `wield_item_scale` follows the engine's wielditem rule
--      (wieldmesh.cpp WieldMeshSceneNode::setItem): a node without a wield
--      image drawn as a cube, nodebox, mesh, glass or liquid is a block (0.7);
--      plantlike, torchlike, signlike, raillike, plantlike_rooted and flowing
--      nodes, any node with a wield image (definition, `_grug_world_wield_image`
--      or stack meta), tools and craftitems stay at 1;
--   G. `wield_transform` with the factor: the size is 0.7 of today's for every
--      pose and stature, the rotation is unchanged, a centred pose keeps its
--      centre in the fist and a diagonal pose keeps its grip pixel there; no
--      factor (or 1) is today's transform exactly (SIZE 0.32 / stature);
--   P. the player path through `grug_visuals.apply` and the hand entity: a
--      held dirt block, slab and mesh at 70 %, a pickaxe, a torch and a
--      sapling at today's size; a block-to-block swap only re-textures, a
--      block-to-flat swap of the same pose re-attaches at the new size;
--   N. an NPC (`apply_entity`, no stature) holding a block gets the same 70 %.
-- Prints "R49 VIS PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

------------------------------------------------------------------------------
-- Stubs: just enough engine for the real files (the tools/r31_a set, plus an
-- item registry, item groups, ItemStack metadata and recorded entities).
------------------------------------------------------------------------------
local registered = {}
local function reg(name, def)
	def.name = name
	registered[name] = def
end
reg("default:dirt", {type = "node"})
reg("default:stone", {type = "node", drawtype = "normal"})
reg("stairs:slab_stone", {type = "node", drawtype = "nodebox"})
reg("test:mesh_block", {type = "node", drawtype = "mesh"})
reg("default:glass", {type = "node", drawtype = "glasslike_framed_optional"})
reg("default:leaves", {type = "node", drawtype = "allfaces_optional"})
reg("default:water_source", {type = "node", drawtype = "liquid"})
reg("default:water_flowing", {type = "node", drawtype = "flowingliquid"})
reg("default:sapling", {type = "node", drawtype = "plantlike",
	inventory_image = "default_sapling.png"})
reg("default:apple", {type = "node", drawtype = "plantlike"})
reg("default:torch", {type = "node", drawtype = "mesh",
	inventory_image = "default_torch_on_floor.png", wield_image = "default_torch_on_floor.png"})
reg("test:torchlike", {type = "node", drawtype = "torchlike"})
reg("default:sign_wall_wood", {type = "node", drawtype = "nodebox",
	wield_image = "default_sign_wood.png"})
reg("test:signlike", {type = "node", drawtype = "signlike"})
reg("carts:rail", {type = "node", drawtype = "raillike"})
reg("test:rooted", {type = "node", drawtype = "plantlike_rooted"})
reg("test:air", {type = "node", drawtype = "airlike"})
reg("test:world_image_block", {type = "node", drawtype = "normal",
	_grug_world_wield_image = "test_flat.png"})
reg("default:pick_steel", {type = "tool", groups = {pickaxe = 1}})
reg("default:axe_steel", {type = "tool", groups = {axe = 1}})
reg("default:stick", {type = "craftitem"})

local spawned = {}
local function new_object()
	local obj = {props = {}, alive = true}
	function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function obj:get_properties() return self.props end
	function obj:set_attach(parent, bone, pos, rot)
		self.attach = {parent = parent, bone = bone, pos = pos, rot = rot}
	end
	function obj:get_attach() return self.attach and self.attach.parent end
	function obj:get_pos() return self.alive and {x = 0, y = 0, z = 0} or nil end
	function obj:remove() self.alive = false end
	return obj
end

local callbacks = {join = {}}
core = {
	log = function() end,
	get_modpath = function(name)
		return ROOT .. (name == "player_api" and "/mods/BASE/" or "/mods/PLAYER/") .. name
	end,
	formspec_escape = function(text) return text end,
	calculate_knockback = function() return 0 end,
	get_us_time = function() return 0 end,
	get_connected_players = function() return {} end,
	get_current_modname = function() return "grug_visuals" end,
	register_entity = function() end,
	register_globalstep = function() end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_respawnplayer = function() end,
	register_on_mods_loaded = function() end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	registered_items = registered,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	add_entity = function()
		local obj = new_object()
		spawned[#spawned + 1] = obj
		return obj
	end,
}
minetest = core
local race_of = {}
grug_classes = {
	race_ids = {accord = {"human", "dwarf", "elf"}, throng = {"orc", "troll", "undead"}},
	registered_races = {},
	get_race = function(player) return race_of[player] end,
	register_on_race_chosen = function() end,
	register_on_class_chosen = function() end,
	register_look_panel = function() end,
}
grug_core = {
	register_on_equipment_change = function() end,
	equipment_is_broken = function() return false end,
	register_on_settled_incoming_hit = function() end,
	settlement_socket_settlements = function() return {} end,
}
grug_inventory = {
	get_cosmetic_weapon = function() return nil end,
	get_cosmetic_offhand = function() return nil end,
	get_cosmetic_hand = function() return nil end,
}
grug_gear = {
	BRACKETS = {{}, {}, {}, {}, {}, {}},
	MATERIALS = {
		{metal = {key = "bronze"}, cloth = {key = "patch"}, leather = {key = "light"}},
		{metal = {key = "iron"}, cloth = {key = "woven"}, leather = {key = "cured"}},
		{metal = {key = "steel"}, cloth = {key = "heavy"}, leather = {key = "heavy"}},
		{metal = {key = "silversteel"}, cloth = {key = "silkweave"}, leather = {key = "scaled"}},
		{metal = {key = "embersteel"}, cloth = {key = "silk"}, leather = {key = "sleek"}},
		{metal = {key = "abyssal_steel"}, cloth = {key = "stormweave"}, leather = {key = "nightscale"}},
	},
	bracket_for_level = function() return 1 end,
	weapon_item = function(family) return "grug_gear:" .. family .. "_bronze" end,
	has_enchant_masks = function() return false end,
}
dofile(ROOT .. "/mods/ITEMS/grug_gear/permissions.lua")
local function new_meta(fields)
	local store = {}
	for k, v in pairs(fields or {}) do store[k] = v end
	return {
		fields = store,
		get_string = function(_, key) return store[key] or "" end,
		set_string = function(_, key, value)
			store[key] = value ~= "" and value or nil
		end,
	}
end
ItemStack = function(source)
	local name, fields = "", nil
	if type(source) == "table" then
		name, fields = source:get_name(), source:get_meta().fields
	elseif type(source) == "string" then
		name = source
	end
	local meta = new_meta(fields)
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_meta() return meta end
	function stack:to_string()
		local keys = {}
		for key in pairs(meta.fields) do keys[#keys + 1] = key end
		table.sort(keys)
		local out = name
		for _, key in ipairs(keys) do out = out .. " " .. key .. "=" .. meta.fields[key] end
		return out
	end
	return stack
end
function table.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = table.copy(v) end
	return out
end

player_api = nil
dofile(ROOT .. "/mods/BASE/player_api/init.lua")
grug_visuals = nil
dofile(ROOT .. "/mods/PLAYER/grug_visuals/init.lua")
local V = grug_visuals

------------------------------------------------------------------------------
-- S. Which items are blocks.
------------------------------------------------------------------------------
local BLOCK = {"default:dirt", "default:stone", "stairs:slab_stone", "test:mesh_block",
	"default:glass", "default:leaves", "default:water_source"}
local FLAT = {"default:water_flowing", "default:sapling", "default:apple", "default:torch",
	"test:torchlike", "default:sign_wall_wood", "test:signlike", "carts:rail",
	"test:rooted", "test:air", "test:world_image_block", "default:pick_steel",
	"default:axe_steel", "default:stick"}
for _, name in ipairs(BLOCK) do
	eq(V.wield_item_scale(registered[name], ""), 0.7, "S " .. name .. " is a block")
end
for _, name in ipairs(FLAT) do
	eq(V.wield_item_scale(registered[name], ""), 1, "S " .. name .. " is flat")
end
eq(V.wield_item_scale(registered["default:dirt"], nil), 0.7, "S no stack meta")
eq(V.wield_item_scale(registered["default:dirt"], "x.png"), 1,
	"S a stack's own wield image is extruded flat")
eq(V.wield_item_scale(nil, ""), 1, "S an unknown definition stays at full size")

------------------------------------------------------------------------------
-- G. The transform.
------------------------------------------------------------------------------
local W = V.WIELD
near(W.size.x, 0.32, "G today's uncompensated size")
local poses = {}
for _, pose in pairs(V.POSE) do poses[#poses + 1] = pose end
table.sort(poses)
local function sub(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end
for _, stature in ipairs({1, 0.9, 1.12}) do
	for _, pose in ipairs(poses) do
		local label = "G " .. pose .. " @" .. stature
		local today = V.wield_transform(stature, pose)
		local one = V.wield_transform(stature, pose, 1)
		local block = V.wield_transform(stature, pose, 0.7)
		near(today.size.x, 0.32 / stature, label .. " no factor is today's size")
		for _, axis in ipairs({"x", "y", "z"}) do
			eq(one.pos[axis], today.pos[axis], label .. " factor 1 pos " .. axis)
			eq(one.rot[axis], today.rot[axis], label .. " factor 1 rot " .. axis)
			eq(block.rot[axis], today.rot[axis], label .. " block rot " .. axis)
		end
		eq(one.size.x, today.size.x, label .. " factor 1 size")
		near(block.size.x, 0.7 * today.size.x, label .. " block size x")
		near(block.size.y, 0.7 * today.size.y, label .. " block size y")
		-- The anchor stays in the fist: the offset from the hand is the grip
		-- vector, which is linear in the sprite edge (zero for a centred pose).
		local d_today, d_block = sub(today.pos, today.hand), sub(block.pos, block.hand)
		for _, axis in ipairs({"x", "y", "z"}) do
			near(d_block[axis], 0.7 * d_today[axis], label .. " grip offset " .. axis)
		end
		if pose == V.POSE.forward or pose == V.POSE.upright or pose == V.POSE.bow then
			for _, axis in ipairs({"x", "y", "z"}) do
				eq(block.pos[axis], block.hand[axis], label .. " centre in the fist " .. axis)
			end
		end
	end
end

------------------------------------------------------------------------------
-- P. The player path.
------------------------------------------------------------------------------
local function fake_player(name_text, race)
	local props = {}
	local meta = new_meta()
	local player = {_wielded = ItemStack("")}
	function player:get_player_name() return name_text end
	function player:is_player() return true end
	function player:set_properties(p) for k, v in pairs(p) do props[k] = v end end
	function player:get_properties() return props end
	function player:set_animation() end
	function player:set_local_animation() end
	function player:get_meta() return meta end
	function player:get_inventory() return nil end
	function player:get_wielded_item() return ItemStack(self._wielded) end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:get_hp() return 20 end
	function player:get_look_vertical() return 0 end
	function player:set_bone_override() end
	race_of[player] = race
	for _, fn in ipairs(callbacks.join) do fn(player) end
	return player
end
local function shown(parent)
	local live
	for _, obj in ipairs(spawned) do
		if obj.alive and obj.attach and obj.attach.parent == parent then
			check(live == nil, "one hand entity per wielder")
			live = obj
		end
	end
	return live
end
local function hold(player, item)
	player._wielded = type(item) == "string" and ItemStack(item) or item
	V.apply(player)
	return shown(player)
end

local dwarf = fake_player("dee", "dwarf")
local k = V.RACES.dwarf.stature
local HAND = W.hand
local function expect(obj, scale, pose, label)
	if not check(obj ~= nil, label .. " shown") then return end
	local t = V.wield_transform(k, pose, scale)
	near(obj.props.visual_size.x, 0.32 * scale / k, label .. " size")
	for _, axis in ipairs({"x", "y", "z"}) do
		near(obj.attach.pos[axis], t.pos[axis], label .. " pos " .. axis)
		eq(obj.attach.rot[axis], t.rot[axis], label .. " rot " .. axis)
	end
end
local dirt = hold(dwarf, "default:dirt")
expect(dirt, 0.7, V.POSE.forward, "P dirt")
for _, axis in ipairs({"x", "y", "z"}) do
	eq(dirt and dirt.attach.pos[axis], HAND[axis], "P dirt centre in the fist " .. axis)
end
local count = #spawned
local stone = hold(dwarf, "default:stone")
eq(#spawned, count, "P dirt -> stone re-textures, no new entity")
check(stone == dirt, "P the same entity holds the stone")
eq(stone and stone.props.textures[1], "default:stone", "P stone texture")
expect(hold(dwarf, "stairs:slab_stone"), 0.7, V.POSE.forward, "P slab")
expect(hold(dwarf, "test:mesh_block"), 0.7, V.POSE.forward, "P mesh block")
local block = shown(dwarf)
local sapling = hold(dwarf, "default:sapling")
check(sapling ~= block and block and not block.alive,
	"P block -> sapling (same pose, other size) re-attaches")
expect(sapling, 1, V.POSE.forward, "P sapling")
expect(hold(dwarf, "default:pick_steel"), 1, V.POSE.tool, "P pickaxe")
expect(hold(dwarf, "default:axe_steel"), 1, V.POSE.edge_down, "P axe")
expect(hold(dwarf, "default:torch"), 1, V.POSE.forward, "P torch")
expect(hold(dwarf, "default:stick"), 1, V.POSE.forward, "P stick")
local imaged = ItemStack("default:dirt")
imaged:get_meta():set_string("wield_image", "x.png")
expect(hold(dwarf, imaged), 1, V.POSE.forward, "P dirt with a stack wield image")
expect(hold(dwarf, "default:dirt"), 0.7, V.POSE.forward, "P back to plain dirt")
eq(hold(dwarf, ""), nil, "P empty hands show nothing")

------------------------------------------------------------------------------
-- N. NPCs share the path (no stature: the mob's own size).
------------------------------------------------------------------------------
local npc_obj = new_object()
local npc = {object = npc_obj}
V.apply_entity(npc, {race = "human", weapon = "default:dirt"})
local held = shown(npc_obj)
if check(held ~= nil, "N the NPC holds the block") then
	near(held.props.visual_size.x, 0.32 * 0.7, "N block at 70 %")
end
npc._grug_visual_skin = nil
V.apply_entity(npc, {race = "human", weapon = "default:pick_steel"})
held = shown(npc_obj)
if check(held ~= nil, "N the NPC holds the pickaxe") then
	near(held.props.visual_size.x, 0.32, "N pickaxe at today's size")
end

if failures > 0 then
	error("R49 VIS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R49 VIS PORTABLE PASS checks=" .. checks)
