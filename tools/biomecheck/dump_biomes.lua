-- Engine stub: load the REAL grug_core/init.lua and grug_mapgen/biomes.lua,
-- dump every registration as CSV in registration order (= engine biome index).
local REPO = "/home/jan/projects/grudgelands"

local biomes = {}

local noop = function() end
core = setmetatable({}, {__index = function(t, k)
  -- Permissive stub: any unstubbed core.* is a no-op function.
  local v = noop
  t[k] = v
  return v
end})
minetest = core
core.registered_biomes = {}
function core.register_biome(def)
  biomes[#biomes + 1] = def
  core.registered_biomes[def.name] = def
end
function core.get_mod_storage()
  return {get_int = function() return 0 end, set_int = function() end,
          get_string = function() return "" end, set_string = function() end}
end
function core.log() end
function core.get_modpath() return REPO .. "/mods/CORE/grug_core" end
function core.get_current_modname() return "grug_core" end
function core.get_spawn_level() return nil end
function core.register_on_mods_loaded() end
function core.register_on_joinplayer() end
function core.register_on_newplayer() end
function core.register_on_respawnplayer() end
function core.after() end
function core.get_node_or_nil() return nil end
function core.get_item_group() return 0 end
function core.settings() end
core.settings = {get = function() return nil end, get_bool = function() return false end}
function core.set_mapgen_setting_noiseparams() end
function core.get_mapgen_setting() return "1" end
function core.registered_nodes() end
core.registered_nodes = setmetatable({}, {__index = function() return {} end})
function core.get_content_id() return 0 end
function core.get_biome_name() return nil end
function core.register_on_generated() end
function core.get_value_noise() return {get_2d = function() return 0 end} end

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.offset(p, dx, dy, dz) return {x = p.x + dx, y = p.y + dy, z = p.z + dz} end

grug_core = {}
-- grug_core/init.lua defines grug_core itself; it expects the global to be free.
grug_core = nil
dofile(REPO .. "/mods/CORE/grug_core/init.lua")

-- biomes.lua only needs grug_core constants; give it the real ones.
local f = loadfile(REPO .. "/mods/MAPGEN/grug_mapgen/biomes.lua")
f()

print("idx,name,node_top,x_min,x_max,y_min,y_max,z_min,z_max,heat,humidity,vertical_blend")
for i, b in ipairs(biomes) do
  local mn = b.min_pos or {}
  local mx = b.max_pos or {}
  print(string.format("%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
    i, b.name, tostring(b.node_top),
    tostring(mn.x or -31000), tostring(mx.x or 31000),
    tostring(mn.y or (b.y_min or -31000)), tostring(mx.y or (b.y_max or 31000)),
    tostring(mn.z or -31000), tostring(mx.z or 31000),
    tostring(b.heat_point), tostring(b.humidity_point),
    tostring(b.vertical_blend or 0)))
end
