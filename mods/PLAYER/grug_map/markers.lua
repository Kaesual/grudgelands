-- Shared marker sizes (21px at 1080p since Round 67, 32 before; since
-- Round 66 fitted to the map), the draw order by importance and the
-- silhouette tooltips. Since Round 67 (rulings 20 and 21) every marker sits
-- at its anchor: overlaps are allowed, nothing is displaced.
local path = core.get_modpath("grug_map")
local L = dofile(path .. "/icon_layout.lua")
local masks = dofile(path .. "/icon_masks.lua")
-- ARROW: the player's and the party's arrows at the reference, today's
-- size; they scale with the markers (ARROW / SIZE of a marker's size).
local M = {SIZE=21, ARROW=32, layout=L}
grug_map.markers = M
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
-- Round 66 ruling 5: a marker keeps the share of its map that it has on a
-- 1920x1080 desktop at HUD and GUI scale 1 (there M.SIZE). `cap` is
-- metrics' HUD-scaled size, `drawn` the map's drawn pixel extent, `reference`
-- the same map's extent on that desktop; the result never exceeds the cap
-- and never goes below M.MIN (unless the cap does). Round 67: 11 (16 before,
-- scaled with M.SIZE).
M.MIN = 11
function M.fit(cap, drawn, reference)
 if not (drawn and reference and drawn > 0 and reference > 0) then return cap end
 local size = math.floor(M.SIZE * drawn / reference + 0.5 + 1e-6)
 return math.min(cap, math.max(M.MIN, size))
end
-- An arrow's size for a marker size: ARROW at the reference, scaled alike.
function M.arrow(size)
 return math.max(1, math.floor(size * M.ARROW / M.SIZE + 0.5))
end
function M.texture(marker)
 if marker.kind == "quest" then return "grug_map_quest_" .. marker.status .. ".png" end
 if marker.texture then return marker.texture end
 if marker.kind == "home" or marker.kind == "innkeeper" or marker.kind == "waypoint" then
  return "grug_map_" .. marker.kind .. ".png"
 end
end

-- Importance (Round 67 coordinator default "draw order by importance"),
-- bottom to top, the minimap's layers before Round 67: places, bosses,
-- trainers, innkeepers and every other kind (0), the Steward and the
-- services (1, above the trainer books beside them), the home and waystones
-- (2), quest givers (3 and up: a locked "!" lowest, then in progress,
-- available, ready, a story marker above the plain one of its status). The
-- minimap's z-index and the map window's draw order both read it; the
-- arrows stay above every marker.
local KIND_RANK = {steward = 1, service = 1, home = 2, waypoint = 2}
local QUEST_RANK = {locked = 0, active = 2, available = 4, ready = 6}
function M.rank(marker)
 if marker.kind == "quest" then
  local status = tostring(marker.status or "")
  local plain = status:match("^story_(.+)$")
  return 3 + (QUEST_RANK[plain or status] or 0) + (plain and 1 or 0)
 end
 return KIND_RANK[marker.kind] or 0
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
return M
