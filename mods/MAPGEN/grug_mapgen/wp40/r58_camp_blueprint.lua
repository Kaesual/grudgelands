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
-- The mining camp: a fence ring with a gate on every side, the lift's
-- headframe on its timber deck (the lift node, `grug_mapgen:guild_lift`, at
-- `r58_camp_catalog.LIFT.mining_camp`), the foreman's tent in faction
-- cloth, the vendor's stall, ore heaps, an ore cart and the timber stack;
-- torches on the gate posts. The camp under construction: a palisade begun
-- on its gate side, a scaffolded watchtower, a hut frame, timber and
-- supplies and the command tent; no lift, no vendor, no shelter and no bed,
-- nothing an enemy could use.
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
local rot = dofile(wp13.."/plot_approach.lua").rot
local palettes = dofile(wp13.."/palette.lua")
local decor = dofile(wp13.."/decor_kit.lua")(wp13)
local catalog = dofile(module_dir.."/r58_camp_catalog.lua")

local SIZE = {mining_camp={r=11,h=9}, camp_construction={r=11,h=9}}
local FACTION_OF = {dwarf="accord",human="accord",elf="accord",undead="throng",orc="throng",troll="throng"}
-- Faction cloth, as the war camps' (grug_core.factions: Accord blue, Throng red).
local CLOTH = {accord={main="wool:blue",trim="wool:white"},throng={main="wool:red",trim="wool:black"}}
local LIFT_NODE = "grug_mapgen:guild_lift"
local TABLE = "grug_decor:cottages_table"

return function(options, profile)
	local art = assert(profile and profile.art, "Round 58 camp art missing")
	local size = assert(SIZE[art.kind], "Round 58 camp kind differs")
	local cloth = assert(CLOTH[art.faction], "Round 58 camp faction differs")
	local race = art.race
	assert(FACTION_OF[race]==art.faction, "Round 58 camp race is not of its faction")
	local turns = art.turns or 0
	assert(turns%1==0 and turns>=0 and turns<=3, "Round 58 camp turns differ")
	local p = palettes.new(race)
	local r, height = size.r, size.h
	local by_pos, structures, sockets = {}, {}, {}
	local function key(x,y,z) return ((z+r)*(height+1)+y)*(2*r+1)+x+r end
	local function put(x,y,z,name,param2)
		assert(x>=-r and x<=r and z>=-r and z<=r and y>=0 and y<=height,
			"Round 58 "..art.kind..": cell outside authored core")
		by_pos[key(x,y,z)]={x=x,y=y,z=z,name=name,param2=param2 or 0}
	end
	local function fill(x1,y1,z1,x2,y2,z2,name,param2)
		for z=z1,z2 do for y=y1,y2 do for x=x1,x2 do put(x,y,z,name,param2) end end end
	end
	local function name_at(x,y,z)
		local cell=by_pos[key(x,y,z)]
		return cell and cell.name
	end
	local function record(label,x,z,w,d,h,kind)
		structures[#structures+1]={label=label,x=x,z=z,w=w,d=d,h=h,kind=kind}
	end
	local function socket(id,role,x,z,dx,dz,extra)
		local row={id=id,role=role,x=x,y=1,z=z,dir={x=dx,z=dz}}
		for k,v in pairs(extra or {}) do row[k]=v end
		sockets[#sockets+1]=row
	end
	-- The decor kit's pieces paint into this composition (wp13/decor_kit.lua).
	local brush = decor.brush(decor.view(put, function(x,y,z) return by_pos[key(x,y,z)] end),
		race, p)
	local light = p.node("light_post")
	-- A post of `top` courses with a light on it.
	local function lamp(x,z,top)
		fill(x,1,z,x,top,z,p.node("post")); put(x,top+1,z,light,1)
	end
	-- A ridge tent of faction cloth along z (the war camps' tent): the
	-- courses step in one node per course to a ridge `half`+1 high, the back
	-- closed, the front open.
	local function tent(label,cx,z1,z2,half,kind)
		record(label,cx,math.floor((z1+z2)/2),half,math.floor((z2-z1)/2),half+1,kind)
		for z=z1,z2 do for dx=-half,half do put(cx+dx,half+1-math.abs(dx),z,cloth.main) end end
		put(cx,half+1,z1,cloth.trim)
		for dx=-half+1,half-1 do fill(cx+dx,1,z2,cx+dx,half-math.abs(dx),z2,cloth.main) end
		fill(cx-half+1,0,z1+1,cx+half-1,0,z2-1,p.node("rug"))
	end
	-- An ore cart along +x: two planks loaded with the race's rubble, the
	-- wheels on its -z side where the race has wheels (no lying log, so the
	-- cart turns with the composition).
	local function cart(x,z)
		for u=0,1 do
			put(x+u,1,z,p.node("floor")); put(x+u,2,z,p.node("rubble"))
			parts.wall_prop(brush.buf,p,"wheel",x+u,1,z-1,0,0,1)
		end
	end

	fill(-r,0,-r,r,0,r,p.node("ground"))
	fill(-r,1,-r,r,height,r,"air")
	if art.kind=="mining_camp" then
		-- The ways: gate to gate in both directions, crossing at the anchor.
		fill(-1,0,-r,1,0,r,p.node("path"))
		fill(-r,0,-1,r,0,1,p.node("path"))
		-- A fence ring with a three-wide gate on every side, its posts lit.
		for z=-r,r do for x=-r,r do
			if math.max(math.abs(x),math.abs(z))==r and math.abs(x)>1 and math.abs(z)>1 then
				put(x,1,z,p.node("fence"))
			end
		end end
		for _,q in ipairs({{-2,-r},{2,-r},{-2,r},{2,r},{-r,-2},{-r,2},{r,-2},{r,2}}) do
			lamp(q[1],q[2],2)
		end
		record("fence",0,0,r,r,3,"fence")
		-- The lift: a timber deck, the headframe's two posts and beam, the rope
		-- over the lift node; the lift socket is the node's cell.
		local lift=assert(catalog.LIFT.mining_camp)
		local lx,lz=lift.x,lift.z
		fill(lx-2,0,lz-1,lx+2,0,lz+1,p.node("floor"))
		fill(lx-1,1,lz,lx-1,4,lz,p.node("post")); fill(lx+1,1,lz,lx+1,4,lz,p.node("post"))
		fill(lx-1,5,lz,lx+1,5,lz,p.node("beam"))
		fill(lx,2,lz,lx,4,lz,p.maybe("rope") or p.node("fence"))
		put(lx,1,lz,LIFT_NODE)
		record("lift headframe",lx,lz,2,1,5,"lift")
		-- The foreman's tent (west) with the foreman at its door.
		tent("foreman's tent",-7,3,7,2,"foreman")
		put(-8,1,6,p.node("storage")); put(-6,1,6,TABLE)
		-- The vendor's stall (east): four posts, a slab roof, a counter.
		for _,q in ipairs({{5,-6},{9,-6},{5,-2},{9,-2}}) do fill(q[1],1,q[2],q[1],3,q[2],p.node("post")) end
		fill(5,4,-6,9,4,-2,p.node("roof_slab"))
		put(5,1,-5,p.node("storage")); put(5,1,-4,TABLE); put(5,1,-3,p.node("storage"))
		record("vendor's stall",7,-4,2,2,4,"stall")
		decor.piece(brush,"stores",8,-8,0)
		-- The work: ore heaps by the lift and the gate, the cart, timber.
		cart(3,7)
		decor.piece(brush,"ore_heap",-4,9,0)
		decor.piece(brush,"ore_heap",7,8,0)
		decor.piece(brush,"ore_heap",-6,-6,0)
		decor.piece(brush,"woodpile",-9,-9,0,3)
		lamp(-4,-4,2); lamp(4,4,2)
		-- Sockets (the camp socket contract, settlements.md "Mining camps").
		socket("lift","lift",lx,lz,0,-1)
		socket("quest_foreman","quest",-7,2,0,-1)
		socket("vendor_camp","vendor",6,-4,-1,0,{kind="camp"})
		socket("gate_west","guard_post",-2,-r+1,1,0,{tags={"gate"}})
		socket("gate_east","guard_post",2,-r+1,-1,0,{tags={"gate"}})
		if art.contested then
			socket("yard_west","guard_post",-4,-2,0,-1,{tags={"camp"}})
			socket("yard_east","guard_post",4,2,0,-1,{tags={"camp"}})
		end
	else
		-- Trampled ground from the gate to the command tent.
		fill(-1,0,-r,1,0,3,p.node("rubble"))
		-- The palisade begun on the gate side and stopped halfway along the
		-- flanks, its logs of uneven height; the gate between two lit posts.
		for z=-r,r do for x=-r,r do
			local ring=math.max(math.abs(x),math.abs(z))==r
			if ring and math.abs(x)>1 and (z==-r or (z<=0 and math.abs(x)==r)) then
				fill(x,1,z,x,1+(x*3+z)%3,z,p.node("post"))
			end
		end end
		lamp(-2,-r,3); lamp(2,-r,3)
		record("palisade",0,-r,r,1,4,"palisade")
		-- A scaffolded watchtower: four corner posts, a plank deck, no roof.
		for _,dx in ipairs({-8,-6}) do for _,dz in ipairs({-8,-6}) do
			fill(dx,1,dz,dx,6,dz,p.node("post"))
		end end
		fill(-8,4,-8,-6,4,-6,p.node("floor"))
		record("watchtower frame",-7,-7,1,1,6,"scaffold")
		-- A hut frame: corner posts and the first beams.
		for _,q in ipairs({{5,-8},{9,-8},{5,-4},{9,-4}}) do fill(q[1],1,q[2],q[1],3,q[2],p.node("post")) end
		fill(6,3,-8,8,3,-8,p.node("floor")); fill(5,3,-7,5,3,-5,p.node("floor"))
		record("hut frame",7,-6,2,2,3,"scaffold")
		-- Timber and supplies.
		decor.piece(brush,"woodpile",6,5,0,3)
		decor.piece(brush,"woodpile",6,8,0,3)
		decor.piece(brush,"stores",-8,7,1)
		decor.piece(brush,"ore_heap",-8,1,0)
		-- The command tent and the captain before its door.
		tent("command tent",0,4,8,3,"command")
		lamp(-4,3,2); lamp(4,-3,2)
		socket("gate_west","guard_post",-2,-r+2,1,0,{tags={"gate"}})
		socket("gate_east","guard_post",2,-r+2,-1,0,{tags={"gate"}})
		socket("yard_west","guard_post",-4,1,0,-1,{tags={"camp"}})
		socket("yard_east","guard_post",4,1,0,-1,{tags={"camp"}})
		socket("captain","captain",0,3,0,-1)
	end

	-- The anchor root and its yard stay open; nothing is authored onto them.
	for z=-2,2 do for x=-2,2 do for y=1,3 do
		assert(name_at(x,y,z)=="air","Round 58 "..art.kind..": central actor clearance blocked")
	end end end
	assert(name_at(0,0,0)~="air","Round 58 "..art.kind..": anchor support missing")
	-- Every socket stands in open air on solid ground (the lift's is its node).
	for _,s in ipairs(sockets) do
		local here=name_at(s.x,1,s.z)
		assert((s.role=="lift" and here==LIFT_NODE) or (s.role~="lift" and here=="air"),
			"Round 58 "..art.kind..": socket "..s.id.." blocked")
	end

	-- Turn the finished composition: cells, their orientation, the sockets
	-- (position and facing) and the structure boxes.
	local cells,names={},{}
	for _,cell in pairs(by_pos) do
		if turns~=0 then
			cell.x,cell.z=rot(cell.x,cell.z,turns)
			cell.param2=parts.rotate_param2(cell.param2,parts.param2_kind(cell.name),turns)
		end
		cells[#cells+1]=cell; names[cell.name]=true
	end
	if turns~=0 then
		for _,s in ipairs(sockets) do
			s.x,s.z=rot(s.x,s.z,turns)
			s.dir.x,s.dir.z=rot(s.dir.x,s.dir.z,turns)
		end
		for _,b in ipairs(structures) do
			b.x,b.z=rot(b.x,b.z,turns)
			if turns%2==1 then b.w,b.d=b.d,b.w end
		end
	end
	table.sort(cells,function(a,b)
		return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x)))
	end)
	local palette={}
	for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette,function(a,b)
		for i=1,math.min(#a,#b) do local x,y=a:byte(i),b:byte(i);if x~=y then return x<y end end
		return #a<#b
	end)
	return {schema=profile.blueprint_schema,palette=palette,cells=cells,
		bounds={min={x=-r,y=0,z=-r},max={x=r,y=height,z=r}},clear_to=height,
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
