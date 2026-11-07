-- Round 70 DESIGN: read-only composition and capital-planner export.
-- Run from the repository root; no engine, nodes, world or server is created.
-- luajit tools/r70_design/export.lua blueprints OUTPUT
-- luajit tools/r70_design/export.lua planner OUTPUT SEED today|proposed|lake0|lake_shift
-- luajit tools/r70_design/export.lua lakes OUTPUT
local mode, output = assert(arg[1]), assert(arg[2])
local base = "mods/MAPGEN/grug_mapgen/"
local dir = base .. "wp13"
local raw_dofile = dofile
local function json(v)
 local t = type(v)
 if t == "nil" then return "null" end
 if t == "boolean" then return tostring(v) end
 if t == "number" then
  if v ~= v or v == math.huge or v == -math.huge then return "null" end
  return string.format("%.12g", v)
 end
 if t == "string" then
  return '"' .. v:gsub('[%z\1-\31\\"]', function(c)
   if c == '"' then return '\\"' end
   if c == '\\' then return '\\\\' end
   return string.format('\\u%04x', c:byte())
  end) .. '"'
 end
 assert(t == "table", t)
 local result = {}
 if #v > 0 or next(v) == nil then
  for i = 1, #v do result[#result + 1] = json(v[i]) end
  return '[' .. table.concat(result, ',') .. ']'
 end
 local keys = {}
 for k in pairs(v) do keys[#keys + 1] = k end
 table.sort(keys)
 for _, k in ipairs(keys) do result[#result + 1] = json(tostring(k)) .. ':' .. json(v[k]) end
 return '{' .. table.concat(result, ',') .. '}'
end
local function write(v)
 local f = assert(io.open(output, "w")); f:write(json(v), "\n"); f:close()
end
if mode == "blueprints" or mode == "geometry" then
 local capture
 local names, name_ids = {}, {}
 local function runs(cells)
  local sorted, out = {}, {}
  for _, c in ipairs(cells) do
   if c.name ~= 'air' then sorted[#sorted + 1] = c end
  end
  table.sort(sorted, function(a, b)
   if a.y ~= b.y then return a.y < b.y end
   if a.z ~= b.z then return a.z < b.z end
   return a.x < b.x
  end)
  for _, c in ipairs(sorted) do
   if not name_ids[c.name] then
    names[#names + 1] = c.name; name_ids[c.name] = #names
   end
   local id, last = name_ids[c.name], out[#out]
   if last and last[2] + 1 == c.x and last[3] == c.y and last[4] == c.z and last[5] == id then
    last[2] = c.x
   else out[#out + 1] = {c.x, c.x, c.y, c.z, id} end
  end
  return out
 end
 -- Observe the actual template loader and stamping path; never parse a
 -- placement out of comments and never substitute an authored composition.
 _G.dofile = function(path)
  local m = raw_dofile(path)
  if path:match('/templates.lua$') then
   return function(directory)
    local T = m(directory)
    local part = T.part
    T.part = function(t, id, ...)
     local p = part(t, id, ...)
     p.design_id, p.design_template = id, t.name
     return p
    end
    return T
   end
  elseif path:match('/parts.lua$') then
   local stamp = m.stamp
   m.stamp = function(target, part, x, y, z, turns)
    local points = stamp(target, part, x, y, z, turns)
    if capture and part.design_id then
     local fp = assert(points.footprint[1])
     local box = {x1 = math.huge, z1 = math.huge, x2 = -math.huge, z2 = -math.huge}
     for _, c in ipairs(part.buffer:cells()) do
      local rx, rz = m.rotate_footprint(c.x, c.z, part.w, part.d, turns)
      if c.name ~= 'air' then
       box.x1, box.x2 = math.min(box.x1, x + rx), math.max(box.x2, x + rx)
       box.z1, box.z2 = math.min(box.z1, z + rz), math.max(box.z2, z + rz)
      end
     end
     capture[#capture + 1] = {id = part.design_id, template = part.design_template,
      x = x, y = y, z = z, w = fp.w, d = fp.d, turns = turns, cells_box = box,
      doors = points.doors or {}, sockets = points.sockets or {}}
     if mode == 'geometry' then
      local cells = {}
      for _, c in ipairs(part.buffer:cells()) do
       local rx, rz = m.rotate_footprint(c.x, c.z, part.w, part.d, turns)
       cells[#cells + 1] = {x = x + rx, y = y + c.y, z = z + rz, name = c.name}
      end
      capture[#capture].runs = runs(cells)
     end
    end
    return points
   end
  end
  return m
 end
 local result = {}
 local keys = {"dur_brannoc", "highcourt", "lethariel", "gor_drazhak", "nhal_veyr", "kezamba",
  "hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar", "kapok"}
 for i, key in ipairs(keys) do
  capture = {}
  local mod = dofile(dir .. '/' .. key .. '.lua')(dir)
  local bp = type(mod) == 'function' and mod() or mod.core()
  local tops, ground = {}, {}
  for _, c in ipairs(bp.cells) do
   if c.name ~= 'air' then
    local k = c.z .. ':' .. c.x
    if not tops[k] or c.y > tops[k].y then tops[k] = c end
    if c.y <= 0 and (not ground[k] or c.y > ground[k].y) then ground[k] = c end
   end
  end
  local raster = {}
  for z = bp.bounds.min.z, bp.bounds.max.z do
   local row = {}
   for x = bp.bounds.min.x, bp.bounds.max.x do
    local c = tops[z .. ':' .. x]
    local g = ground[z .. ':' .. x]
    local kind = 'empty'
    if c then
     local n = c.name
     if n:find('water') then kind = 'water'
     elseif n:find('leaves') or n:find('needles') then kind = 'tree'
     elseif n:find('grass') or n:find('litter') or n:find('dirt') or n:find('mud') then kind = 'ground'
     elseif n:find('flower') or n:find('fern') or n:find('shrub') then kind = 'ground'
     elseif c.y > 2 then kind = 'built' else kind = 'paving' end
    end
    row[#row + 1] = {kind, c and c.y or -999, g and g.y or -999}
   end
   raster[#raster + 1] = row
  end
  result[key] = {kind = i <= 6 and 'capital' or 'town', bounds = bp.bounds,
   buildings = capture, landmarks = bp.landmarks, raster = raster}
  if mode == 'geometry' then
   result[key] = {buildings = capture, top = bp.bounds.max.y, composition_runs = runs(bp.cells)}
  end
  io.stderr:write(key, ': ', #capture, ' templates, ', #bp.landmarks.sockets, ' sockets\n')
  capture = nil
 end
 _G.dofile = raw_dofile
 if mode == 'geometry' then write({names = names, places = result}) else write(result) end
elseif mode == "bindings" then
 local services = dofile(dir .. '/capital_services.lua')
 local result = {plots = services.PLOTS, inns = services.INNS, guild = services.GUILD_HALL, sockets = {}}
 for _, key in ipairs({'dur_brannoc','highcourt','lethariel','gor_drazhak','nhal_veyr','kezamba'}) do
  local districts = dofile(dir .. '/' .. key .. '_districts.lua')(dir)
  local list = {}
  for _, plot in ipairs(districts.plots()) do
   local bp = plot.build()
   for _, s in ipairs((bp.landmarks or {}).sockets or {}) do
    local c = {}
    for k,v in pairs(s) do c[k] = v end
    c.id, c.plot = plot.id .. '/' .. s.id, plot.id
    list[#list+1] = c
   end
  end
  result.sockets[key] = list
 end
 write(result)
elseif mode == "lakes" then
 local variant = dofile('tools/r70_design/lake_variant.lua')
 local result = {}
 local lagoon = dofile(dir .. '/kezamba_lagoon.lua')()
 local f = assert(io.open(dir .. '/lethariel.lua'))
 local source = f:read('*a'); f:close()
 local mere = assert(loadstring('return ' .. assert(source:match('local MERE = (%b{})'))))()
 for _, shifted in ipairs({false, true}) do
  for _, row in ipairs(variant.factory(base .. 'wp40/water_authored.lua', shifted)({LAKE_PROXY = 40})) do
   if variant.shifts[row.id] then
    local key = row.id == 'kezamba_cenote' and 'kezamba' or 'lethariel'
    local az = key == 'kezamba' and 1500 or -1500
    result[key] = result[key] or {}
    local wet = {}
    for z = -80, 80 do
     for x = -80, 80 do
      if row.indicator(1800 + x, az + z) >= 0.5 then wet[#wet + 1] = {x,z} end
     end
    end
    result[key][shifted and 'shifted' or 'unshifted'] = wet
    if not shifted then
     local count, mismatch = 0, 0
     for z = -47,47 do
      for x = -47,47 do
       local span = mere[z]
       local authored = key == 'kezamba' and lagoon.lagoon(x,z) or
        (key == 'lethariel' and span ~= nil and x >= span[1] and x <= span[2])
       local actual = row.indicator(1800+x,az+z) >= 0.5
       if actual then count = count+1 end
       if actual ~= authored then mismatch = mismatch+1 end
      end
     end
     result[key].baseline_mask_half = 47
     result[key].baseline_mask_columns = count
     result[key].baseline_mask_mismatches = mismatch
     assert(mismatch == 0, key .. ': old composition mask differs from water')
    end
   end
  end
 end
 write(result)
elseif mode == "planner" then
 local seed, variant = assert(arg[3]), assert(arg[4])
 assert(variant == 'today' or variant == 'proposed' or variant == 'lake0' or variant == 'lake_shift')
 local lake_study = variant == 'lake0' or variant == 'lake_shift'
 if lake_study then
  local lake_variant = dofile('tools/r70_design/lake_variant.lua')
  _G.dofile = function(path)
   if path:match('/water_authored.lua$') then
    return lake_variant.factory(path, variant == 'lake_shift')
   end
   local value = raw_dofile(path)
   if path:match('/source/simple_map.lua$') then
    local function widen(t)
     if type(t) ~= 'table' then return end
     if t.civic_width == 96 then t.civic_width = 112 end
     for _, v in pairs(t) do widen(v) end
    end
    widen(value)
   end
   return value
  end
 end
 _G.core = {}
 local common = dofile('tools/wp40/r6/common.lua')
 local A = dofile(base .. 'wp40/world_assembly.lua')(base .. 'wp40', common.new_sha256())
 A.capital_plots()
 local planner = A.capitals.planner
 local original = planner.plan
 local by_anchor = {}
 for _, p in ipairs(A.capital_profiles) do by_anchor[p.anchor_id] = p.key end
 local result = {seed = seed, variant = variant, capitals = {}}
 planner.plan = function(s, I, opt)
  if variant == 'proposed' or lake_study then
   -- Sensitivity experiment ONLY: today's core cells and landing detector.
   -- Proposed keeps old terrain; lake studies widen the fitting and change
   -- authored water in memory above. Neither builds the future core.
   opt.CORE, opt.CORE_GATE, opt.CORE_KEEP = 56, 57, 60
  end
  local p = original(s, I, opt)
  local out = {anchor = p.anchor, area = p.area, core = p.P.CORE, keep = p.P.CORE_KEEP,
   gates = {}, outline = {}, streets = {}, plots = {}, left_out = p.left_out,
   relaxed = p.relaxed, overflowed = p.stats.overflowed, squares = p.squares,
   failures = {no_route = p.stats.no_route, connector_failed = p.stats.connector_failed,
    infeasible = (p.stats.kit_stats or {}).infeasible}, buildable = 0,
   lost_band_buildable = 0, required = 0, missing_required = {}}
  for _, g in ipairs(p.gates) do
   out.gates[#out.gates+1] = {name=g.name,x=g.x,z=g.z,y=g.y,dx=g.dx,dz=g.dz}
  end
  for a, r in ipairs(p.R) do out.outline[#out.outline + 1] = {r*p.rays[a].c,r*p.rays[a].s} end
  for _, r in ipairs(p.streets) do
   local pts = {}
   for n = 1, #r.X do pts[#pts + 1] = {r.X[n]-p.anchor.x,r.Z[n]-p.anchor.z} end
   out.streets[#out.streets + 1] = {role = r.role or r.kind, hw = r.hw, pts = pts}
  end
  local grid = p.grid
  for iz = 0, grid.NG-1 do
   for ix = 0, grid.NG-1 do
    local k = iz*grid.NG+ix
    if grid.BUILD[k] then
     out.buildable = out.buildable+1
     local radius = math.max(math.abs(-grid.EXT+ix*grid.G),math.abs(-grid.EXT+iz*grid.G))
     if radius > 52 and radius <= 60 then out.lost_band_buildable = out.lost_band_buildable+1 end
    end
   end
  end
  local present = {}
  for _, q in ipairs(p.plots) do
   present[q.id] = true
   out.plots[#out.plots + 1] = {id = q.id, district = q.district, kind = q.kind,
    required = q.required, x = q.x, z = q.z, y = q.y, turns = q.turns,
    x1 = q.x+q.x0, x2 = q.x+q.x1, z1 = q.z+q.z0, z2 = q.z+q.z1}
  end
  for _, q in ipairs(I.plots) do
   if q.required then
    out.required = out.required + 1
    if not present[q.id] then out.missing_required[#out.missing_required+1] = q.id end
   end
  end
  -- Local terrain samples, deliberately not a world voxel raster.
  out.terrain = {}
  for z = -76,76,2 do
   local row = {}
   for x = -76,76,2 do
    local h,w = I.sample(p.anchor.x+x,p.anchor.z+z)
    row[#row+1] = {h,w or false}
   end
   out.terrain[#out.terrain+1] = row
  end
  if lake_study and (by_anchor[I.anchor.id] == 'lethariel' or by_anchor[I.anchor.id] == 'kezamba') then
   out.core_wet, out.castle_wet, out.core_columns = 0, 0, 115 * 115
   local key = by_anchor[I.anchor.id]
   local castle = key == 'lethariel' and {-52,-51,-18,-7} or {5,-52,49,-18}
   for z = -57,57 do
    for x = -57,57 do
     local h,w = I.sample(p.anchor.x+x,p.anchor.z+z)
     if w and w > h then
      out.core_wet = out.core_wet + 1
      if x >= castle[1] and x <= castle[3] and z >= castle[2] and z <= castle[4] then
       out.castle_wet = out.castle_wet + 1
      end
     end
    end
   end
  end
  result.capitals[by_anchor[I.anchor.id]] = out
  io.stderr:write(seed, ' ', variant, ' ', by_anchor[I.anchor.id], ': ', #out.plots,
   ' plots; ', #out.missing_required, ' missing required\n')
  return p
 end
 local W = A.world(seed)
 local ok, err = pcall(W.plan_capitals)
 result.ok, result.error = ok, not ok and tostring(err) or nil
 write(result)
 assert(ok, err)
else error('unknown mode') end
