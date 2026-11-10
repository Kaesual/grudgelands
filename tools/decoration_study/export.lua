-- Read-only blueprint inventory for the decoration discussion. LuaJIT only.
-- Uses the actual builders, including plot-side service dressing and trees.
local root, city = arg[1], arg[2]
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp40"
local function keys(t)
 local out = {}; for k in pairs(t) do out[#out + 1] = k end
 table.sort(out); return out
end
local function quote(s)
 return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
  if c == '"' then return '\\"' end
  if c == '\\' then return '\\\\' end
  return string.format('\\u%04x', c:byte())
 end) .. '"'
end
local function json(v)
 if type(v) == 'string' then return quote(v) end
 if type(v) == 'number' or type(v) == 'boolean' then return tostring(v) end
 if type(v) ~= 'table' then return 'null' end
 local out = {}
 if #v > 0 then
  for i = 1, #v do out[i] = json(v[i]) end
  return '[' .. table.concat(out, ',') .. ']'
 end
 for _, k in ipairs(keys(v)) do out[#out + 1] = quote(k) .. ':' .. json(v[k]) end
 return '{' .. table.concat(out, ',') .. '}'
end
local function inventory(cells)
 local counts, tables, at, free = {}, {}, {}, 0
 for _, c in ipairs(cells) do
  counts[c.name] = (counts[c.name] or 0) + 1
  at[c.x .. ',' .. c.y .. ',' .. c.z] = c.name
  if c.name == 'grug_decor:xdecor_table' or c.name == 'grug_decor:cottages_table' then
   tables[#tables + 1] = c
  end
 end
 for _, c in ipairs(tables) do
  local n = at[c.x .. ',' .. (c.y + 1) .. ',' .. c.z]
  if not n or n == 'air' then free = free + 1 end
 end
 return {nodes=counts, table_cells=#tables, clear_above_tables=free}
end
-- Observe the public template seam; never change its arguments or output.
local original_dofile, captured = dofile, {}
_G.dofile = function(path)
 local value = original_dofile(path)
 if path:match('/wp13/templates%.lua$') then
  return function(directory)
   local mod = value(directory)
   local original_part = mod.part
   mod.part = function(t, id, race, palette_of)
    local part = original_part(t, id, race, palette_of)
    captured[#captured + 1] = {id=id, template=t.name,
     inventory=inventory(part.buffer:cells())}
    return part
   end
   return mod
  end
 end
 return value
end
local rows = {}
local function emit(id, kind, district, role, blueprint)
 local row = {id=id, kind=kind, district=district, role=role,
  inventory=inventory(blueprint.cells), templates=captured,
  structures=blueprint.landmarks and blueprint.landmarks.structures,
  sockets=blueprint.landmarks and blueprint.landmarks.sockets}
 rows[#rows + 1] = row
 if kind:match('^village') then
  row.buildings = {}
  for index, s in ipairs(blueprint.landmarks.structures or {}) do
   local cells = {}
   for _, c in ipairs(blueprint.cells) do
    if c.x >= s.x-s.w and c.x <= s.x+s.w and c.z >= s.z-s.d and c.z <= s.z+s.d then
     cells[#cells+1] = c
    end
   end
   row.buildings[#row.buildings+1] = {id='building_' .. index, spec=s, inventory=inventory(cells)}
  end
 end
 captured = {}
end
local caps = dofile(wp .. '/r7_capital_blueprint.lua')
local race, label
if caps.CAPITALS[city] then
 race, label = caps.CAPITALS[city].race, city
 local kit = caps.kit(city)
 emit('core','core','core','core',kit.core.build())
 for _, p in ipairs(kit.plots) do emit(p.id,p.kind,p.district,p.role,p.build()) end
else
 local settlement = dofile(wp .. '/r7_settlement.lua')
 local profile
 for _, p in ipairs(settlement.roster) do if p.key == city then profile = p end end
 assert(profile, 'unknown settlement: ' .. city)
 race, label = profile.race, profile.label
 local builder = dofile(wp .. '/' .. profile.blueprint_file)
 local blueprint = profile.art and builder({}, profile) or builder()
 emit(city,profile.slot,'town','town',blueprint)
end
io.write(json({city=city,race=race,label=label,rows=rows}) .. '\n')
