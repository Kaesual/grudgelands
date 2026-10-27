-- Shared 32px marker sizes, silhouette tooltips and cached displacement.
-- Only layout is cached; visibility/textures always come from current state.
local path = core.get_modpath("grug_map")
local L = dofile(path .. "/icon_layout.lua")
local masks = dofile(path .. "/icon_masks.lua")
local M = {SIZE=32, layout=L}
grug_map.markers = M
local cache, order = {}, {}
local CACHE_LIMIT = 24
local scaled, scale_order = {}, {}

function M.metrics(info, form_w, form_h)
 local hud, px = 1, 72
 if type(info) == "table" then
  if type(info.real_hud_scaling) == "number" and info.real_hud_scaling > 0 then hud=info.real_hud_scaling end
  if info.size and info.max_formspec_size and info.max_formspec_size.x > 0 then
   px = info.size.x / info.max_formspec_size.x
  end
 end
 if form_w and info and info.size then
  px = math.min(px, info.size.x/form_w, info.size.y/form_h)
 end
 -- max_formspec_size is reported as float32; compensate only its small
 -- round-trip error before matching the client's integer imgsize.
 return math.max(1, math.floor(M.SIZE * hud + 0.5)), math.max(1,math.floor(px+0.0001))
end
function M.texture(marker)
 if marker.kind == "quest" then return "grug_map_quest_" .. marker.status .. ".png" end
 if marker.texture then return marker.texture end
 if marker.kind == "home" or marker.kind == "innkeeper" or marker.kind == "waypoint" then
  return "grug_map_" .. marker.kind .. ".png"
 end
end
local function mask_name(marker)
 if marker.kind == "quest" then return "quest" end
 if marker.kind == "home" or marker.kind == "innkeeper" then return "home" end
 return M.texture(marker)
end
local function mask_of(name, size)
 if not scaled[size] then
  if #scale_order >= 8 then scaled[table.remove(scale_order,1)] = nil end
  scale_order[#scale_order+1], scaled[size] = size, {}
 end
 local bucket = scaled[size]
 if not bucket[name] then bucket[name] = L.scale_mask(assert(masks[name], name), size) end
 return bucket[name]
end
function M.tip_rectangles(texture,size)
 if not masks[texture] then return nil end
 local mask=mask_of(texture,size)
 local key="tips:" .. texture
 local bucket=scaled[size]
 if not bucket[key] then bucket[key]=L.hit_rectangles(mask) end
 return bucket[key]
end
local function memo(key, build)
 if cache[key] then return cache[key] end
 local value = build()
 if #order >= CACHE_LIMIT then cache[table.remove(order,1)] = nil end
 order[#order+1], cache[key] = key, value
 return value
end

-- Markers outside the world bounds are harmless to the stable solve; the
-- renderer clips them. Each view uses its own projection, no camera offset.
function M.offsets(player, providers, markers, sx, sy, size)
 local shared, personal = {}, {}
 local function project(marker)
  local name = mask_name(marker)
  if not name or not masks[name] then return end
  return {id=marker.id, x=marker.position.x*sx, y=-marker.position.z*sy,
   mask=mask_of(name,size), name=name}
 end
 for _, marker in ipairs(markers) do
  if marker.kind ~= "quest" then
   local row = project(marker)
   if row then
    local list = (marker.personal or marker.kind == "waypoint") and personal or shared
    list[#list+1] = row
   end
  end
 end
 if providers and providers.quest then
  for _, marker in ipairs(grug_map.quest_slots(player)) do shared[#shared+1] = project(marker) end
 end
 local function signature(rows)
  table.sort(rows, function(a,b) return a.id < b.id end)
  local parts = {tostring(size)}
  for _, row in ipairs(rows) do
   parts[#parts+1] = ("%s/%d/%d/%s"):format(row.id, math.floor(row.x+0.5), math.floor(row.y+0.5), row.name)
  end
  return table.concat(parts, "|")
 end
 -- The complete projected roster and mask names identify world, faction,
 -- projection and simultaneous set. Art is immutable for this process.
 local key = signature(shared)
 local fixed = memo(key, function() return L.solve(shared,size,math.floor(size/2)) end)
 local result = {}
 for _, row in ipairs(fixed) do result[row.id] = row end
 if #personal > 0 then
  local own = memo(key .. "#personal#" .. signature(personal), function()
   return L.solve(personal,size,math.floor(size/2),fixed)
  end)
  for _, row in ipairs(own) do result[row.id] = row end
 end
 return result
end
return M
