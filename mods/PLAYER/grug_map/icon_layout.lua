-- Deterministic alpha-aware placement in projected screen pixels. Pure Lua.
-- Canonical neighbor groups use anchors, never a viewport or minimap cell.
-- A fixed candidate set and two improvement passes bound work independently
-- of wall time. Fixed offsets are solved before any personal markers.
local L = {}
local floor, ceil, abs = math.floor, math.ceil, math.abs

function L.scale_mask(source, size)
 local rows = {}
 for y = 0, size - 1 do
  local row = {}
  for _, x in ipairs(source[floor(y * 32 / size) + 1]) do
   row[#row + 1] = ceil(x * size / 32)
  end
  rows[y + 1] = row
 end
 return rows
end

-- Pixels in both silhouettes, with half-open horizontal spans.
function L.overlap(a, b, size, stop)
 local ax, ay, bx, by = a.x + a.dx, a.y + a.dy, b.x + b.dx, b.y + b.dy
 if abs(ax - bx) >= size or abs(ay - by) >= size then return 0 end
 local count = 0
 for y = math.max(ay, by), math.min(ay, by) + size - 1 do
  local ar, br = a.mask[y - ay + 1], b.mask[y - by + 1]
  local i, j = 1, 1
  while i <= #ar and j <= #br do
   local left, right = math.max(ax + ar[i], bx + br[j]), math.min(ax + ar[i+1], bx + br[j+1])
   if right > left then count = count + right - left end
   if ax + ar[i+1] < bx + br[j+1] then i = i + 2 else j = j + 2 end
  end
  if stop and count > stop then return count end
 end
 return count
end

local function candidates(radius)
 local list = {}
 local step = math.max(1, floor(radius / 4))
 for y = -radius, radius, step do
  for x = -radius, radius, step do
   local distance = x*x + y*y
   if distance <= radius*radius then list[#list+1] = {x=x, y=y, distance=distance} end
  end
 end
 list[#list+1] = {x=0, y=0, distance=0}
 table.sort(list, function(a,b)
  if a.distance ~= b.distance then return a.distance < b.distance end
  if a.y ~= b.y then return a.y < b.y end
  return a.x < b.x
 end)
 return list
end

local function place(row, neighbors, size, choices)
 local best, best_count
 local function cost(limit)
  local count = 0
  for _, other in ipairs(neighbors) do
   if other ~= row then
    count = count + L.overlap(row, other, size, limit and limit - count)
    if limit and count > limit then break end
   end
  end
  return count
 end
 -- Keeping the current offset is also a candidate; improvement never raises
 -- total overlap merely to satisfy tie ordering.
 best = {x=row.dx, y=row.dy, distance=row.dx*row.dx + row.dy*row.dy}
 best_count = cost()
 for _, candidate in ipairs(choices) do
  if best_count == 0 and candidate.distance > best.distance then break end
  row.dx, row.dy = candidate.x, candidate.y
  local count = cost(best_count)
  if count < best_count or (count == best_count and candidate.distance < best.distance) then
   best, best_count = candidate, count
  end
 end
 row.dx, row.dy = best.x, best.y
end

-- rows {id,x,y,mask}; fixed rows may carry dx/dy, are obstacles only.
-- Input and masks are never mutated. Anchors are rounded on a world-fixed
-- pixel grid; output contains offsets only, so rendering keeps real anchors.
function L.solve(rows, size, radius, fixed)
 local ordered, grid, pitch = {}, {}, size + 2 * radius
 local function add(row)
  local gx, gy = floor(row.x / pitch), floor(row.y / pitch)
  local key = gx .. ":" .. gy
  grid[key] = grid[key] or {}
  grid[key][#grid[key]+1] = row
 end
 for _, row in ipairs(fixed or {}) do add(row) end
 for _, input in ipairs(rows) do
  local row = {id=input.id, x=floor(input.x+0.5), y=floor(input.y+0.5),
   mask=input.mask, dx=0, dy=0}
  ordered[#ordered+1] = row
  add(row)
 end
 table.sort(ordered, function(a,b) return a.id < b.id end)
 -- Neighbor lists include a whole canonical component implicitly: every
 -- solve runs over the complete roster; no viewport-dependent truncation.
 for _, row in ipairs(ordered) do
  local neighbors, gx, gy = {}, floor(row.x / pitch), floor(row.y / pitch)
  for y = gy-1, gy+1 do
   for x = gx-1, gx+1 do
    for _, other in ipairs(grid[x .. ":" .. y] or {}) do
     if abs(row.x-other.x) < pitch and abs(row.y-other.y) < pitch then
      neighbors[#neighbors+1] = other
     end
    end
   end
  end
  table.sort(neighbors, function(a,b) return a.id < b.id end)
  row.neighbors = neighbors
 end
 local choices = candidates(radius)
 for _ = 1, 2 do
  for _, row in ipairs(ordered) do place(row, row.neighbors, size, choices) end
 end
 for _, row in ipairs(ordered) do row.neighbors = nil end
 return ordered
end

-- Exact rectangles for positional tooltips. Identical spans in successive
-- rows merge; no rectangle includes a transparent source pixel.
function L.rectangles(mask)
 local result, active = {}, {}
 for y, row in ipairs(mask) do
  local next_active = {}
  for i = 1, #row, 2 do
   local x, right = row[i], row[i+1]
   if right > x then
    local key = x .. ":" .. right
    local rect = active[key]
    if rect then rect.h = rect.h + 1 else
     rect = {x=x, y=y-1, w=right-x, h=1}
     result[#result+1] = rect
    end
    next_active[key] = rect
   end
  end
  active = next_active
 end
 return result
end
-- Luanti tooltip rectangles have inclusive endpoints, but zero area is
-- ignored. Use only filled 2x2 interiors; isolated one-pixel edge slivers
-- cannot own a tooltip without including a transparent neighboring pixel.
function L.hit_rectangles(mask)
 local bands = {}
 for y=1,#mask-1 do
  local a,b,row,i,j=mask[y],mask[y+1],{},1,1
  while i<=#a and j<=#b do
   local left,right=math.max(a[i],b[j]),math.min(a[i+1],b[j+1])
   if right-left>=2 then row[#row+1]=left;row[#row+1]=right end
   if a[i+1]<b[j+1] then i=i+2 else j=j+2 end
  end
  bands[y]=row
 end
 local result=L.rectangles(bands)
 for _,rect in ipairs(result) do rect.h=rect.h+1 end
 return result
end
return L
