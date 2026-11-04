-- Round 58 camps (round58-plan.md §2, §4 CAMPS): the Miner's Guild's mining
-- camp and the enemy camp under construction. A pure cell builder in the
-- form of `r31_pvp_poi_blueprint.lua`; the R7 successor owns projection,
-- clipping, protection and the anchor root.
--
-- `profile.art` names the composition (`r7_settlement.camp_profiles`):
--   kind       "mining_camp" | "camp_construction"
--   faction    "accord" | "throng" (a camp under construction: its builder)
--   race       one race of that faction: the WP13 palette the camp builds
--              from (`wp13/palette.lua`) and the race it registers as
--   contested  a mining camp in contested land keeps two more guards
--   turns      quarter turns about +Y (local +z to world +x per turn, as
--              `wp13/parts.lua`); at 0 the gate faces local -z
--
-- Mining camps use the shared Round 63 templates; a camp under construction
-- uses its own, `camp_site_<race>.tpl` (Round 69), and its five sockets are
-- fixed here and in those files: garrisons of every existing world stand on
-- them.
--
-- A camp under construction fills its whole box: 23 x 10 x 23, every cell
-- written, air included. The migration 0.69.0 rewrites each existing camp's
-- box from these cells, so the design is free inside the box and a cell the
-- template left unwritten would keep what the old camp had there.
--
-- Every composition is square and centred on the anchor (-r..r), so a turn
-- keeps its bounds. The anchor column stays open: solid support at (0,0,0)
-- and a clear 5x5x3 yard round the root. Sockets are landmarks, never
-- cells (the role list at the bottom of this file); `landmarks.race` and
-- `landmarks.faction` name what the settlement registers as.
-- Plain Lua 5.1, no globals.
local module_info = debug and debug.getinfo and debug.getinfo(1, "S")
local module_dir = type(module_info)=="table" and type(module_info.source)=="string" and
	module_info.source:sub(1,1)=="@" and module_info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not module_dir or module_dir=="" then module_dir=core.get_modpath("grug_mapgen").."/wp40" end
local wp13 = module_dir.."/../wp13"
local parts = dofile(wp13.."/parts.lua")
local templates = dofile(wp13.."/templates.lua")(wp13)
local rot = dofile(wp13.."/plot_approach.lua").rot
local palettes = dofile(wp13.."/palette.lua")
local camp_blueprint = dofile(module_dir.."/r63_camp_blueprint.lua")

local R, HEIGHT = 11, 9
local FACTION_OF = {dwarf="accord",human="accord",elf="accord",undead="throng",orc="throng",troll="throng"}
-- {id, role, local cell (x, z), facing, tags}: at y = 1 on every template.
local SOCKETS = {
	{"gate_west","guard_post",-2,-9,1,0,{"gate"}},
	{"gate_east","guard_post",2,-9,-1,0,{"gate"}},
	{"yard_west","guard_post",-4,1,0,-1,{"camp"}},
	{"yard_east","guard_post",4,1,0,-1,{"camp"}},
	{"captain","captain",0,3,0,-1},
}
-- The composition's landmarks in the local frame.
local STRUCTURES = {
	{"gate wall",0,-10,10,1,6,"palisade"},
	{"west wall",-10,0,1,10,4,"palisade"},
	{"rear wall",0,10,10,1,4,"palisade"},
	{"east wall",10,-6,1,4,4,"palisade"},
	{"east scaffold",9,5,2,4,6,"scaffold"},
	{"command tent",0,7,3,2,4,"command"},
	{"north worker tent",-7,5,2,2,3,"tent"},
	{"south worker tent",-7,-5,2,2,3,"tent"},
	{"panel stack",7,-6,2,1,2,"scaffold"},
}

local function template(race)
	local name = "camp_site_"..race
	local path = templates.ROOT.."/templates/"..name..".tpl"
	local parsed = templates.parse_template(templates.read(path),path,name)
	local palette = palettes.new(race)
	return templates.part(parsed,name,race,function() return palette end)
end

return function(options, profile)
	local art = assert(profile and profile.art, "Round 58 camp art missing")
	if art.kind=="mining_camp" then return camp_blueprint(options, profile, art.race) end
	assert(art.kind=="camp_construction", "Round 58 camp kind differs")
	local race = art.race
	assert(FACTION_OF[race]==art.faction, "Round 58 camp race is not of its faction")
	local turns = art.turns or 0
	assert(turns%1==0 and turns>=0 and turns<=3, "Round 58 camp turns differ")
	local part = template(race)
	local function key(x,y,z) return ((z+R)*(HEIGHT+1)+y)*(2*R+1)+x+R end
	local source, count = {}, 0
	for _,cell in ipairs(part.buffer:cells()) do
		assert(cell.x>=-R and cell.x<=R and cell.z>=-R and cell.z<=R and cell.y>=0 and cell.y<=HEIGHT,
			"Round 58 "..art.kind..": cell outside authored core")
		source[key(cell.x,cell.y,cell.z)] = cell.name
		count = count + 1
	end
	assert(count==(2*R+1)*(2*R+1)*(HEIGHT+1), "Round 58 "..art.kind..": a cell of the box is unwritten")
	local function name_at(x,y,z) return source[key(x,y,z)] end

	-- The anchor root and its yard stay open; nothing is authored onto them.
	for z=-2,2 do for x=-2,2 do for y=1,3 do
		assert(name_at(x,y,z)=="air","Round 58 "..art.kind..": central actor clearance blocked")
	end end end
	assert(name_at(0,0,0)~="air","Round 58 "..art.kind..": anchor support missing")
	-- Every socket stands in open air on solid ground, on its marker.
	local markers = {}
	for _,point in ipairs(part.points.camp_points) do markers[point.id]=point end
	for _,row in ipairs(SOCKETS) do
		local mark = assert(markers[row[1]], "Round 58 "..art.kind..": missing marker "..row[1])
		assert(mark.x==row[3] and mark.y==1 and mark.z==row[4],
			"Round 58 "..art.kind..": socket "..row[1].." moved")
		assert(name_at(row[3],1,row[4])=="air" and name_at(row[3],0,row[4])~="air",
			"Round 58 "..art.kind..": socket "..row[1].." blocked")
	end

	-- Turn the finished composition: cells, their orientation, the sockets
	-- (position and facing) and the structure boxes.
	local cells,names={},{}
	for _,cell in ipairs(part.buffer:cells()) do
		local x,z=rot(cell.x,cell.z,turns)
		cells[#cells+1]={x=x,y=cell.y,z=z,name=cell.name,
			param2=parts.rotate_param2(cell.param2,parts.param2_kind(cell.name),turns)}
		names[cell.name]=true
	end
	parts.sort_cells_zyx(cells)
	local palette={}
	for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette,parts.less_bytes)
	local sockets={}
	for _,row in ipairs(SOCKETS) do
		local x,z=rot(row[3],row[4],turns)
		local dx,dz=rot(row[5],row[6],turns)
		sockets[#sockets+1]={id=row[1],role=row[2],x=x,y=1,z=z,dir={x=dx,z=dz},tags=row[7]}
	end
	local structures={}
	for _,b in ipairs(STRUCTURES) do
		local x,z=rot(b[2],b[3],turns)
		local w,d=b[4],b[5]
		if turns%2==1 then w,d=d,w end
		structures[#structures+1]={label=b[1],x=x,z=z,w=w,d=d,h=b[6],kind=b[7]}
	end
	return {schema=profile.blueprint_schema,palette=palette,cells=cells,
		bounds={min={x=-R,y=0,z=-R},max={x=R,y=HEIGHT,z=R}},clear_to=HEIGHT,
		landmarks={structures=structures,sockets=sockets,arrival={x=0,y=1,z=0},
			race=race,faction=art.faction}}
end

-- Socket roles (the camp socket contract; settlements.md "Mining camps"):
--   lift        `lift`: the lift node's cell (grug_mapgen:guild_lift); its
--               x/z is the camp's lift column (`r58_camps.lua` camps().lift)
--   quest       `quest_foreman`: the foreman, the camp's quest giver
--   vendor      `vendor_camp`, `kind = "camp"`: the camp vendor
--   guard_post  `gate_west`, `gate_east` (tag "gate") and, in a contested
--               mining camp and every camp under construction, `yard_west`
--               and `yard_east` (tag "camp"): faction guards; in a camp
--               under construction the PvP garrison's (pvp_garrison.lua)
--   captain     `captain`: the named captain of a camp under construction
--   quest_place `held_load` (a mining camp): a town place of a "use at a
--               place" quest (Round 60), nobody stands on it
