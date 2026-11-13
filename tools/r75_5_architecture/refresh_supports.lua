-- Refresh only the authored wall-support names, never decoration placement.
local root = assert(arg[1])
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp40"
local catalog = dofile(wp .. "/city_decor_catalog.lua")
local capitals = dofile(wp .. "/r7_capital_blueprint.lua")
local settlement = dofile(wp .. "/r7_settlement.lua")
local parts = dofile(wp .. "/../wp13/parts.lua")
local function keys(t)
 local out = {}; for k in pairs(t) do out[#out+1] = k end
 table.sort(out); return out
end
local function key(x,y,z) return x .. ":" .. y .. ":" .. z end
for _, city in ipairs(keys(catalog)) do
 local builds = {}
 if capitals.CAPITALS[city] then
  local kit = capitals.kit(city)
  builds.core = kit.core.build
  for _, plot in ipairs(kit.plots) do builds[plot.id] = plot.build end
 else
  local profile
  for _, p in ipairs(settlement.roster) do if p.key == city then profile = p end end
  assert(profile, city)
  local builder = dofile(wp .. "/" .. profile.blueprint_file)
  builds.blueprint = function() return profile.art and builder({},profile) or builder() end
 end
 for _, scope in ipairs(keys(catalog[city])) do
  local bp = assert(builds[scope],scope)()
  local cells = {}
  for _, c in ipairs(bp.cells) do cells[key(c.x,c.y,c.z)] = c end
  for _, row in ipairs(catalog[city][scope]) do for _, p in ipairs(row.placements) do
   local at = key(p.x,p.y,p.z)
   assert(cells[at] and cells[at].name == p.expect, row.id .. " target changed")
   local support = assert(cells[key(p.x+p.support_dx,p.y+p.support_dy,p.z+p.support_dz)])
   if support.name ~= p.support then
    assert(parts.full_solid(support.name), row.id .. " changed support: " .. p.support .. " -> " .. support.name .. " dy=" .. p.support_dy)
    print(table.concat({row.id,at,p.support,support.name}, "\t"))
   end
  end end
 end
end
