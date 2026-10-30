-- Round64: alpha-aware tooltip rectangles and the shared marker metrics
-- (the placement checks left with the solve in Round 67).
local repo = arg[1] or "."
local path = repo .. "/mods/PLAYER/grug_map"
local L = dofile(path .. "/icon_layout.lua")
local masks = dofile(path .. "/icon_masks.lua")
local checks = 0
local function check(ok, message) checks=checks+1; assert(ok,message) end
local function occupied(mask,x,y)
 for i=1,#mask[y+1],2 do if x>=mask[y+1][i] and x<mask[y+1][i+1] then return true end end
 return false
end
-- Round 67 (rulings 20 and 21) removed the displacement solve (L.overlap,
-- L.solve, markers.offsets) and its checks; the tooltip geometry stays.
-- Every tooltip rectangle covers exactly the visible alpha mask once.
for name,mask in pairs(masks) do
 local cells={}
 for _,rect in ipairs(L.rectangles(mask)) do
  for y=rect.y,rect.y+rect.h-1 do for x=rect.x,rect.x+rect.w-1 do
   check(occupied(mask,x,y),name .. ": tooltip excludes transparent pixels")
   local key=y*32+x;check(not cells[key],"nonoverlapping hit rectangles");cells[key]=true
  end end
 end
 for y=0,31 do for x=0,31 do check((cells[y*32+x] or false)==occupied(mask,x,y),"complete tooltip coverage") end end
end
for name,mask in pairs(masks) do
 local hits=L.hit_rectangles(mask)
 check(#hits>0,name .. ": hoverable filled interior")
 for _,rect in ipairs(hits) do
  check(rect.w>=2 and rect.h>=2,"tooltip geometry has positive area with inclusive endpoints")
  for y=rect.y,rect.y+rect.h-1 do for x=rect.x,rect.x+rect.w-1 do
   check(occupied(mask,x,y),"inclusive hit region contains no transparent pixel")
  end end
 end
end
rawset(_G,"core",{get_modpath=function() return path end})
rawset(_G,"grug_map",{})
local M=dofile(path .. "/markers.lua")
for _,hud in ipairs({0.75,1,1.5,2}) do
 for _,gui in ipairs({0.7,1,1.8}) do
  local size,px=M.metrics({real_hud_scaling=hud,real_gui_scaling=gui,
   size={x=1920,y=1080},max_formspec_size={x=1920/(72*gui),y=1080/(72*gui)}})
  check(size==math.floor(M.SIZE*hud+0.5),"shared HUD size independent of GUI scale")
  check(px==math.floor(72*gui+0.0001),"formspec conversion uses integer client imgsize")
 end
end
print(("R64 MAP PASS checks=%d"):format(checks))
