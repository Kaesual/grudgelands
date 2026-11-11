-- Architectural regressions reported during the browser review, through the
-- real template loader. Exact full-scene/rotation proof: integrate.py --runtime.
local root = arg[1] or "."
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp13"
local templates = dofile(wp .. "/templates.lua")(wp)
local palettes = dofile(wp .. "/palette.lua")
local parts = dofile(wp .. "/parts.lua")
local count = 0
local function check(value, message) assert(value,message); count=count+1 end
local function building(name,race)
 local file = assert(io.open(root .. "/mods/MAPGEN/grug_mapgen/building_templates/templates/" .. name .. ".tpl"))
 local t = templates.parse_template(file:read("*a"),name,name); file:close()
 local palette = palettes.new(race)
 local part = templates.part(t,"proof",race,function() return palette end)
 local out = {}; local cells,n = part.buffer:cells()
 for i=1,n do local c=cells[i]; out[c.x..":"..c.y..":"..c.z]=c end
 return function(x,y,z,node)
  local c=out[x..":"..y..":"..z]
  check(c and c.name == node, name .. " material at " .. x .. ":" .. y .. ":" .. z)
 end
end
local inn = building("dawnmere_harvest_inn","human")
for y=2,7 do inn(0,y,4,"grug_trees:gravewood_wood") end
for z=0,14 do
 inn(0,5,z,"grug_trees:gravewood_wood")
 inn(0,7,z,"grug_trees:gravewood_wood")
end
inn(0,4,5,"grug_decor:cottages_loam")
inn(0,4,6,"grug_decor:cottages_loam")
inn(0,6,5,"grug_decor:cottages_loam")
local dwarf = building("dur_brannoc_lane_house","dwarf")
for y=5,6 do dwarf(1,y,0,"grug_decor:darkage_stone_brick") end
dwarf(1,7,0,"default:stone_block")
dwarf(0,9,3,"default:wood")
local troll = building("kapok_elder_stilt","troll")
for y=6,9 do troll(0,y,0,"default:junglewood") end
troll(0,8,1,"grug_nodes:clay_band_umber")
local elf = building("dur_brannoc_plaza_house","elf")
for x=0,8 do elf(x,5,0,"grug_decor:darkage_serpentine") end
for _, family in ipairs({"cottages_reet","darkage_slate"}) do
 for _, shape in ipairs({"stair","stair_inner","stair_outer","slab"}) do
  local name="grug_decor:" .. family .. "_" .. shape
  check(parts.shaped(name) and parts.param2_kind(name)==parts.FACEDIR,name .. " rotation contract")
 end
end
print("r75_5_architecture: " .. count .. " checks passed")
