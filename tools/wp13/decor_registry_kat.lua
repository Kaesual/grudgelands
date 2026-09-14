-- decor_registry_kat.lua -- engine-free registration smoke test for grug_decor.
--
-- Loads mods/ITEMS/grug_decor against a minimal `core` stub and asserts the
-- package contract of the curated decorative building kit:
--
--   1. every registered name starts with "grug_decor:";
--   2. every texture string resolves to a file in grug_decor/textures or in
--      mods/BASE/default/textures (texture modifiers and the `^` overlay
--      syntax are decomposed first);
--   3. every `mesh` file exists in grug_decor/models;
--   4. no craft recipe was registered;
--   5. no ABM, LBM, node timer, formspec or inventory hook was installed;
--   6. the node count per source is printed.
--
-- Run under both interpreters (from the repo root):
--     luajit         tools/wp13/decor_registry_kat.lua
--     tools/bin/lua51 tools/wp13/decor_registry_kat.lua
--
-- Exit status is 0 on success; any violation raises and aborts.

local MOD = "mods/ITEMS/grug_decor"
local DEFAULT_TEX = "mods/BASE/default/textures"

---------------------------------------------------------------------------
-- tiny helpers
---------------------------------------------------------------------------

local function file_exists(path)
	local fh = io.open(path, "rb")
	if fh then
		fh:close()
		return true
	end
	return false
end

local function sorted_keys(t)
	local out = {}
	for k in pairs(t) do
		out[#out + 1] = k
	end
	table.sort(out)
	return out
end

local violations = {}

local function check(ok, msg)
	if not ok then
		violations[#violations + 1] = msg
	end
end

---------------------------------------------------------------------------
-- recorders
---------------------------------------------------------------------------

local registered_nodes = {}
local registered_order = {}
local registered_aliases = {}
local crafts = 0
local abms = 0
local lbms = 0
local entities = 0
local craftitems = 0
local tools = 0

-- Node definition fields that would mean "this node does something".
local FORBIDDEN_FIELDS = {
	"on_timer", "on_receive_fields", "allow_metadata_inventory_put",
	"allow_metadata_inventory_take", "allow_metadata_inventory_move",
	"on_metadata_inventory_put", "on_metadata_inventory_take",
	"on_metadata_inventory_move", "on_rightclick", "on_punch", "on_blast",
	"on_construct", "after_place_node", "after_dig_node", "on_destruct",
	"after_destruct", "can_dig", "preserve_metadata", "on_rotate",
	"on_dig", "on_use", "on_flood", "node_dig_prediction",
}

---------------------------------------------------------------------------
-- the `core` stub
---------------------------------------------------------------------------

local core_stub = {}

function core_stub.register_node(name, def)
	assert(type(name) == "string", "register_node with a non-string name")
	assert(type(def) == "table", "register_node without a definition table: " .. name)
	check(registered_nodes[name] == nil, "duplicate registration: " .. name)
	registered_nodes[name] = def
	registered_order[#registered_order + 1] = name
end

function core_stub.register_alias(old, new)
	registered_aliases[#registered_aliases + 1] = tostring(old) .. " -> " .. tostring(new)
end

core_stub.register_alias_force = core_stub.register_alias

function core_stub.register_craft()
	crafts = crafts + 1
end

function core_stub.register_abm()
	abms = abms + 1
end

function core_stub.register_lbm()
	lbms = lbms + 1
end

function core_stub.register_entity()
	entities = entities + 1
end

function core_stub.register_craftitem()
	craftitems = craftitems + 1
end

function core_stub.register_tool()
	tools = tools + 1
end

function core_stub.get_modpath()
	return MOD
end

function core_stub.get_current_modname()
	return "grug_decor"
end

function core_stub.get_translator()
	return function(s)
		return s
	end
end

core_stub.settings = {
	get_bool = function(_, _, fallback)
		return fallback
	end,
	get = function()
		return nil
	end,
}

core_stub.registered_nodes = registered_nodes
core_stub.registered_items = registered_nodes

function core_stub.log() end
function core_stub.rotate_node() end
function core_stub.item_place() end
function core_stub.item_place_node() end
function core_stub.get_node() end
function core_stub.dir_to_facedir() return 0 end
function core_stub.pointed_thing_to_face_pos() return {x = 0, y = 0, z = 0} end
function core_stub.is_creative_enabled() return false end
function core_stub.get_us_time() return 0 end

core = core_stub
minetest = core_stub

-- Globals the mod legitimately reads from its declared dependencies.
default = {}
local SOUND_KINDS = {
	"defaults", "stone_defaults", "dirt_defaults", "sand_defaults",
	"gravel_defaults", "wood_defaults", "leaves_defaults", "glass_defaults",
	"ice_defaults", "metal_defaults", "water_defaults", "snow_defaults",
}
for _, kind in ipairs(SOUND_KINDS) do
	default["node_sound_" .. kind] = function()
		return {_kind = kind}
	end
end
default.LIGHT_MAX = 14

vector = {
	subtract = function(a, b)
		return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
	end,
}

function ItemStack(s)
	return {get_name = function() return s end}
end

if not table.copy then
	local function copy(t, seen)
		seen = seen or {}
		if type(t) ~= "table" then
			return t
		end
		if seen[t] then
			return seen[t]
		end
		local out = {}
		seen[t] = out
		for k, v in pairs(t) do
			out[copy(k, seen)] = copy(v, seen)
		end
		return out
	end
	table.copy = copy
end

---------------------------------------------------------------------------
-- load the mod
---------------------------------------------------------------------------

local chunk, err = loadfile(MOD .. "/init.lua")
assert(chunk, "cannot load grug_decor: " .. tostring(err))
chunk()

---------------------------------------------------------------------------
-- 1. namespace
---------------------------------------------------------------------------

for _, name in ipairs(registered_order) do
	check(name:sub(1, 11) == "grug_decor:",
		"node name outside the grug_decor namespace: " .. name)
end
check(#registered_aliases == 0,
	"grug_decor registered " .. #registered_aliases .. " aliases")

---------------------------------------------------------------------------
-- 2. textures
---------------------------------------------------------------------------

-- Decompose a Luanti texture string into the plain file names it names.
-- Handles `^` overlays, `(` `)` grouping and `[modifier:arg` parameters.
local function texture_files(str, out)
	out = out or {}
	for token in str:gmatch("[^%^%(%)]+") do
		-- a token may still be "file.png" or "[modifier:a:b"
		if token:sub(1, 1) ~= "[" then
			-- strip a trailing modifier chain that gmatch already split off
			local first = token:match("^([^:]+)")
			if first and first:match("%.png$") then
				out[first] = true
			end
		else
			-- modifier arguments may themselves name a texture
			for part in token:gmatch("[^:]+") do
				if part:match("%.png$") then
					out[part] = true
				end
			end
		end
	end
	return out
end

local function collect_textures(value, out)
	local t = type(value)
	if t == "string" then
		texture_files(value, out)
	elseif t == "table" then
		if type(value.name) == "string" then
			texture_files(value.name, out)
		end
		for k, v in pairs(value) do
			if k ~= "name" then
				collect_textures(v, out)
			end
		end
	end
	return out
end

local TEXTURE_FIELDS = {"tiles", "inventory_image", "wield_image", "special_tiles"}

local wanted = {}
local meshes = {}

for _, name in ipairs(registered_order) do
	local def = registered_nodes[name]
	for _, field in ipairs(TEXTURE_FIELDS) do
		if def[field] ~= nil then
			collect_textures(def[field], wanted)
		end
	end
	if def.mesh then
		meshes[def.mesh] = true
	end
end

local resolved_mod, resolved_default = 0, 0
for _, tex in ipairs(sorted_keys(wanted)) do
	if file_exists(MOD .. "/textures/" .. tex) then
		resolved_mod = resolved_mod + 1
	elseif file_exists(DEFAULT_TEX .. "/" .. tex) then
		resolved_default = resolved_default + 1
	else
		check(false, "unresolved texture: " .. tex)
	end
end

---------------------------------------------------------------------------
-- 3. meshes
---------------------------------------------------------------------------

local mesh_count = 0
for _, mesh in ipairs(sorted_keys(meshes)) do
	mesh_count = mesh_count + 1
	check(file_exists(MOD .. "/models/" .. mesh), "missing mesh: " .. mesh)
end

---------------------------------------------------------------------------
-- 4. + 5. no recipes, no mechanics
---------------------------------------------------------------------------

check(crafts == 0, crafts .. " craft recipes were registered")
check(abms == 0, abms .. " ABMs were registered")
check(lbms == 0, lbms .. " LBMs were registered")
check(entities == 0, entities .. " entities were registered")
check(craftitems == 0, craftitems .. " craftitems were registered")
check(tools == 0, tools .. " tools were registered")

for _, name in ipairs(registered_order) do
	local def = registered_nodes[name]
	for _, field in ipairs(FORBIDDEN_FIELDS) do
		check(def[field] == nil, name .. " carries a behaviour hook: " .. field)
	end
	check(def.formspec == nil, name .. " carries a formspec")
	check(def.inventory == nil, name .. " carries an inventory")
	-- grug_materials/audit.lua hard-fails startup on any node with level > 0.
	check(type(def.groups) ~= "table" or def.groups.level == nil,
		name .. " carries a level group")
	-- `_grug_sell_price` is deliberately unset (0 = not sellable)
	check(def._grug_sell_price == nil, name .. " sets _grug_sell_price")
end

-- `on_place` is allowed: it is the vendored placement rotation of stairs /
-- core.rotate_node, which only chooses param2. Assert it is nothing else.
local ALLOWED_ON_PLACE = {
	["grug_decor:cottages_wood_flat"] = true,
	["grug_decor:cottages_wool_tent"] = true,
	["grug_decor:xdecor_barrel"] = true,
	["grug_decor:xdecor_cushion"] = true,
}
for _, name in ipairs(registered_order) do
	local def = registered_nodes[name]
	if def.on_place ~= nil then
		local shape = name:find("_stair$") or name:find("_stair_inner$")
			or name:find("_stair_outer$") or name:find("_slab$")
		check(shape ~= nil or ALLOWED_ON_PLACE[name],
			name .. " carries an unexpected on_place")
	end
end

---------------------------------------------------------------------------
-- report
---------------------------------------------------------------------------

local SOURCES = {"castle", "cottages", "darkage", "xdecor"}
local per_source = {}
for _, s in ipairs(SOURCES) do
	per_source[s] = 0
end
local unknown = 0

for _, name in ipairs(registered_order) do
	local rest = name:sub(12)
	local hit = nil
	for _, s in ipairs(SOURCES) do
		if rest:sub(1, #s + 1) == s .. "_" then
			hit = s
		end
	end
	if hit then
		per_source[hit] = per_source[hit] + 1
	else
		unknown = unknown + 1
		check(false, "node outside the four source prefixes: " .. name)
	end
end

print("grug_decor registry KAT")
print(string.format("  interpreter        : %s", _VERSION ..
	(type(jit) == "table" and " / " .. jit.version or "")))
for _, s in ipairs(SOURCES) do
	print(string.format("  nodes from %-9s: %d", s, per_source[s]))
end
print(string.format("  nodes total        : %d", #registered_order))
print(string.format("  textures resolved  : %d (grug_decor) + %d (default) = %d",
	resolved_mod, resolved_default, resolved_mod + resolved_default))
print(string.format("  meshes resolved    : %d", mesh_count))
print(string.format("  crafts / abms / lbms: %d / %d / %d", crafts, abms, lbms))

if #violations > 0 then
	print("FAILURES:")
	for _, v in ipairs(violations) do
		print("  " .. v)
	end
	error(#violations .. " contract violation(s)", 0)
end

print("OK")
