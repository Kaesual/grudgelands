-- Round64: alpha placement, state stability, projections and actual markers.
local repo = arg[1] or "."
local path = repo .. "/mods/PLAYER/grug_map"
local L = dofile(path .. "/icon_layout.lua")
local masks = dofile(path .. "/icon_masks.lua")
local checks = 0
local function check(ok, message) checks=checks+1; assert(ok,message) end
local function row(id,x,y,mask) return {id=id,x=x,y=y,mask=mask} end
local function signature(rows)
 local list = {}
 for _, r in ipairs(rows) do list[#list+1]=r.id .. ":" .. r.dx .. ":" .. r.dy end
 table.sort(list)
 return table.concat(list,"|")
end
local function occupied(mask,x,y)
 for i=1,#mask[y+1],2 do if x>=mask[y+1][i] and x<mask[y+1][i+1] then return true end end
 return false
end
local square, left, right = {}, {}, {}
for y=1,32 do square[y]={0,32}; left[y]={0,8}; right[y]={24,32} end
local a,b = row("a",0,0,left),row("b",0,0,right)
a.dx,a.dy,b.dx,b.dy=0,0,0,0
check(L.overlap(a,b,32)==0,"transparent areas may overlap")
b.mask=left
check(L.overlap(a,b,32)==256,"occupied pixel overlap is counted")
local result=L.solve({a,row("b",0,0,right)},32,16)
check(result[1].dx==0 and result[2].dx==0,"no bounding-box-only displacement")
result=L.solve({row("a",0,0,square),row("b",0,0,square)},32,16)
check(L.overlap(result[1],result[2],32)<1024,"coincident opaque icons improve")
local source={}
for i=1,36 do source[i]=row(("m%02d"):format(i),(i%6)*9,math.floor(i/6)*9,masks["grug_map_innkeeper.png"]) end
local dense=L.solve(source,32,16)
local overlap=0
for i,r in ipairs(dense) do
 check(r.dx*r.dx+r.dy*r.dy<=256,"hard16pxradius")
 check(source[i].dx==nil,"input remains untouched")
 for j=i+1,#dense do overlap=overlap+L.overlap(r,dense[j],32) end
end
check(overlap>0,"dense groups retain residual overlap rather than hiding")
local reverse={};for i=#source,1,-1 do reverse[#reverse+1]=source[i] end
check(signature(dense)==signature(L.solve(reverse,32,16)),"shuffled input deterministic")
-- A chain crosses arbitrary viewport/cell boundaries; adding a distant
-- component cannot affect offsets. Cropping happens only after this solve.
local chain={}
for i=1,24 do chain[i]=row(("c%02d"):format(i),i*40,0,square) end
local chained=L.solve(chain,32,16)
chain[#chain+1]=row("distant",5000,5000,square)
local plus=L.solve(chain,32,16);table.remove(plus)
check(signature(chained)==signature(plus),"canonical chain independent of unrelated groups")
for _, size in ipairs({16,32,48,64}) do
 local mask=L.scale_mask(masks["grug_map_riding.png"],size)
 local scaled=L.solve({row("a",0,0,mask),row("b",0,0,mask)},size,math.floor(size/2))
 for _,r in ipairs(scaled) do check(r.dx*r.dx+r.dy*r.dy <= (size/2)*(size/2),"scaled displacement bound") end
end
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
rawset(_G,"grug_map",{quest_slots=function() return {{id="quest:q",kind="quest",position={x=0,z=0}}} end})
local M=dofile(path .. "/markers.lua")
for _,hud in ipairs({0.75,1,1.5,2}) do
 for _,gui in ipairs({0.7,1,1.8}) do
  local size,px=M.metrics({real_hud_scaling=hud,real_gui_scaling=gui,
   size={x=1920,y=1080},max_formspec_size={x=1920/(72*gui),y=1080/(72*gui)}})
  check(size==math.floor(32*hud+0.5),"shared HUD size independent of GUI scale")
  check(px==math.floor(72*gui+0.0001),"formspec conversion uses integer client imgsize")
 end
end
local markers={
 {id="quest:q",kind="quest",status="available",position={x=0,z=0}},
 {id="home:inn",kind="innkeeper",position={x=1,z=1}},
 {id="service:smith",kind="trainer",texture="grug_map_trainer_armorsmith.png",position={x=2,z=2}},
}
local function common(offsets)
 local result={};for _,id in ipairs({"quest:q","home:inn","service:smith"}) do result[#result+1]=offsets[id] end
 return signature(result)
end
local before=M.offsets({}, {quest=true},markers,1,1,32)
markers[1].status="story_ready";markers[2].kind="home"
local after=M.offsets({}, {quest=true},markers,1,1,32)
check(common(before)==common(after),"quest/home variant changes preserve shared offsets")
markers[#markers+1]={id="waypoint:claim",kind="waypoint",texture="grug_map_claim.png",position={x=0,z=0}}
after=M.offsets({}, {quest=true},markers,1,1,32)
check(common(before)==common(after),"personal insertion leaves fixed offsets unchanged")
markers[4].position.x=100
after=M.offsets({}, {quest=true},markers,1,1,32)
check(after["waypoint:claim"].x==100,"relocated personal marker invalidates layout")
check(common(before)==common(after),"personal relocation preserves fixed offsets")
table.remove(markers,1)
after=M.offsets({}, {quest=true},markers,1,1,32)
check(common(before)==common(after),"invisible giver still reserves union mask")
for i=1,30 do M.offsets({}, {quest=true},markers,i,i,32) end
after=M.offsets({}, {quest=true},markers,1,1,32)
check(common(before)==common(after),"layout cache eviction reproduces placement")
print(("R64 MAP PASS checks=%d dense_residual_pixels=%d"):format(checks,overlap))
