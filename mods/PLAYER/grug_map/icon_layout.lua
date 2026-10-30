-- Alpha-aware tooltip geometry of the 32px marker art (icon_masks.lua) at
-- any drawn size. Pure Lua. Round 64's displacement solve that lived here
-- left with Round 67 (rulings 20 and 21: markers stay at their anchors).
local L = {}
local floor, ceil = math.floor, math.ceil

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
