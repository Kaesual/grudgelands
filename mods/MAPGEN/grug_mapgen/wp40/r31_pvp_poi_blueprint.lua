-- Round 31 PvP POIs (pvp-plan rulings 17-22): the faction fortress and the
-- two Battlegrounds camp layouts. A pure cell builder in the form of
-- `r20_poi_blueprint.lua`; the R7 successor owns projection, clipping,
-- protection and the anchor root.
--
-- `profile.art` names the composition:
--   kind     "pvp_fortress" | "pvp_camp_low" | "pvp_camp_high"
--   faction  "accord" | "throng"
--   race     camps only: one race of that faction (its materials); the
--            fortress always builds in its faction's stone
--   turns    quarter turns about +Y (local +z to world +x per turn, as
--            `wp13/parts.lua`); at 0 the one gate faces local -z
--
-- Every composition is square and centred on the anchor (-r..r), so a turn
-- keeps its bounds. The anchor column stays open: solid support at (0,0,0)
-- and a clear 5x5x3 yard round the root, where the R7 writer puts the anchor
-- node. Sockets are landmarks, never cells (role list in the lane S report
-- and at the bottom of this file).
-- Plain Lua 5.1, no globals.
local module_info = debug and debug.getinfo and debug.getinfo(1, "S")
local module_dir = type(module_info)=="table" and type(module_info.source)=="string" and
	module_info.source:sub(1,1)=="@" and module_info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not module_dir or module_dir=="" then module_dir=core.get_modpath("grug_mapgen").."/wp40" end
local parts = dofile(module_dir.."/../wp13/parts.lua")
local rot = dofile(module_dir.."/../wp13/plot_approach.lua").rot

local SIZE = {pvp_fortress={r=24,h=16}, pvp_camp_low={r=11,h=9}, pvp_camp_high={r=13,h=9}}
local FACTION_OF = {dwarf="accord",human="accord",elf="accord",undead="throng",orc="throng",troll="throng"}
-- Faction cloth: tents, banners and pennants carry the side's colour
-- (grug_core.factions: Accord blue, Throng red).
local CLOTH = {accord={main="wool:blue",trim="wool:white"},throng={main="wool:red",trim="wool:black"}}

-- The fortress: one stone for wall, towers and keep per faction, the seat
-- race's timber or adobe for the halls inside.
local FORT = {
	accord={ground="default:dirt_with_grass",yard="default:gravel",wall="default:stonebrick",
		trim="default:stone_block",keep="default:stone_block",pave="grug_decor:castle_pavement_brick",low="default:stonebrick",
		up="default:wood",post="default:tree",floor="default:wood",roof="grug_decor:darkage_slate_tile",
		form="gable",fence="default:fence_wood"},
	throng={ground="default:dry_dirt_with_dry_grass",yard="default:dry_dirt",wall="grug_decor:darkage_basalt_brick",
		trim="grug_decor:darkage_ors_block",keep="grug_decor:darkage_ors_brick",pave="default:desert_cobble",low="default:desert_stonebrick",
		up="grug_decor:darkage_adobe",post="default:acacia_tree",floor="default:acacia_wood",
		roof="default:desert_stonebrick",form="flat",fence="default:fence_acacia_wood"},
}
-- The camps: race ground, timber and signature stone (wp13/palette.lua
-- `signature`), the race rug inside the command tent.
local CAMP = {
	dwarf={ground="default:dirt_with_coniferous_litter",yard="default:gravel",stone="default:stone_block",
		wood="default:pine_wood",post="default:pine_tree",roof="stairs:slab_pine_wood",rug="wool:brown",
		fence="default:fence_pine_wood"},
	human={ground="default:dirt_with_grass",yard="default:gravel",stone="default:brick",
		wood="default:wood",post="default:tree",roof="stairs:slab_wood",rug="wool:white",
		fence="default:fence_wood"},
	elf={ground="grug_nodes:dirt_with_silver_litter",yard="default:silver_sand",stone="grug_decor:darkage_marble",
		wood="grug_trees:silverwood_wood",post="grug_trees:silverwood_tree",roof="grug_decor:darkage_slate_tile_slab",
		rug="wool:white",fence="default:fence_aspen_wood"},
	undead={ground="grug_nodes:dirt_with_bone_litter",yard="grug_nodes:blight_dirt",stone="default:obsidianbrick",
		wood="grug_trees:gravewood_wood",post="grug_trees:gravewood_tree",roof="stairs:slab_obsidianbrick",
		rug="wool:black",fence="default:fence_wood"},
	orc={ground="default:dry_dirt_with_dry_grass",yard="default:dry_dirt",stone="grug_decor:darkage_adobe",
		wood="default:acacia_wood",post="default:acacia_tree",roof="stairs:slab_desert_stonebrick",
		rug="wool:orange",fence="default:fence_acacia_wood"},
	troll={ground="default:dirt_with_rainforest_litter",yard="default:dirt",stone="grug_decor:darkage_basalt",
		wood="default:junglewood",post="default:jungletree",roof="stairs:slab_junglewood",rug="wool:green",
		fence="default:fence_junglewood"},
}

return function(options, profile)
	local art = assert(profile and profile.art, "Round 31 PvP art missing")
	local size = assert(SIZE[art.kind], "Round 31 PvP kind differs")
	local cloth = assert(CLOTH[art.faction], "Round 31 PvP faction differs")
	local turns = art.turns or 0
	assert(turns%1==0 and turns>=0 and turns<=3, "Round 31 PvP turns differ")
	local r, height = size.r, size.h
	local by_pos, structures, sockets = {}, {}, {}
	local function key(x,y,z) return ((z+r)*(height+1)+y)*(2*r+1)+x+r end
	local function put(x,y,z,name,param2)
		assert(x>=-r and x<=r and z>=-r and z<=r and y>=0 and y<=height,
			"Round 31 "..art.kind..": cell outside authored core")
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
	local function lamp(x,z,post)
		fill(x,1,z,x,2,z,post); put(x,3,z,"default:torch",1)
	end
	-- Merlons: every other cell of a ring's outer edge, one course up.
	local function merlons(x1,z1,x2,z2,y,name)
		for x=x1,x2 do for z=z1,z2 do
			if (x==x1 or x==x2 or z==z1 or z==z2) and (x+z)%2==0 then put(x,y,z,name) end
		end end
	end
	-- A pennant: a pole with two cloth courses on its +x side, a torch on top.
	local function pennant(x,y,z,post,top)
		fill(x,y,z,x,top,z,post)
		fill(x+1,top-1,z,x+1,top,z,cloth.main); put(x+1,top-2,z,cloth.trim)
		put(x,top+1,z,"default:torch",1)
	end

	if art.kind=="pvp_fortress" then
		local f=FORT[art.faction]
		fill(-r,0,-r,r,0,r,f.ground)
		fill(-r,1,-r,r,height,r,"air")
		-- Curtain wall: two nodes thick and six high, a plinth course and a
		-- battlement on the outer ring; the inner ring is the wall walk.
		for z=-r,r do for x=-r,r do
			local ring=math.max(math.abs(x),math.abs(z))
			if ring>=r-1 then
				fill(x,1,z,x,6,z,f.wall)
				if ring==r then
					put(x,1,z,f.trim)
					if (x+z)%2==0 then put(x,7,z,f.wall) end
				end
			end
		end end
		record("curtain wall",0,0,r,r,7,"wall")
		-- Solid towers: plinth, string course under the merlons.
		local function tower(x1,z1,x2,z2,top,base)
			base=base or 1
			fill(x1,base,z1,x2,top,z2,f.wall)
			fill(x1,base,z1,x2,base,z2,f.trim); fill(x1,top,z1,x2,top,z2,f.trim)
			merlons(x1,z1,x2,z2,top+1,f.wall)
		end
		for _,c in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}}) do
			local x1,z1=c[1]<0 and -r or r-4, c[2]<0 and -r or r-4
			tower(x1,z1,x1+4,z1+4,9)
			record("corner tower",x1+2,z1+2,2,2,10,"tower")
		end
		-- The one gate: a vaulted passage five wide and four high between two
		-- gate towers, a lintel course and the faction banner over it.
		tower(-6,-r,-3,-r+4,9); tower(3,-r,6,-r+4,9)
		fill(-2,5,-r,2,9,-r+4,f.wall); fill(-2,5,-r,2,5,-r,f.trim)
		merlons(-6,-r,6,-r+4,10,f.wall)
		fill(-2,1,-r,2,4,-r+4,"air"); fill(-2,0,-r,2,0,-r+4,f.pave)
		fill(0,6,-r,0,8,-r,cloth.main); put(0,8,-r,cloth.trim)
		record("gatehouse",0,-r+2,6,2,10,"gate")
		for _,x in ipairs({-5,4}) do pennant(x,10,-r+2,f.post,12) end
		-- A stepped stair up to the wall walk inside the south wall.
		for step=1,6 do fill(-7-step,1,-r+2,-7-step,step,-r+3,f.wall) end

		-- Paved ways: gate to keep, the cross way, the spur to the waypoint
		-- pad and to the drill yard, and the parade square at the anchor.
		fill(-2,0,-r+5,2,0,11,f.pave)
		fill(-13,0,-1,16,0,1,f.pave)
		fill(-6,0,-6,6,0,6,f.pave)
		for x=-6,6 do put(x,0,-6,f.trim); put(x,0,6,f.trim) end
		for z=-6,6 do put(-6,0,z,f.trim); put(6,0,z,f.trim) end
		fill(3,0,-13,8,0,-11,f.pave)
		fill(-9,0,-15,-3,0,-13,f.pave)

		-- Halls inside the wall: a stone course, then the faction's timber or
		-- adobe; gabled slate (Accord) or a flat roof with a parapet (Throng).
		local function hall(label,cx,cz,w,d,h,opts)
			record(label,cx,cz,w,d,h+1,opts.kind)
			fill(cx-w,0,cz-d,cx+w,0,cz+d,f.floor)
			for y=1,h do
				local m=y<=2 and f.low or f.up
				for x=cx-w,cx+w do put(x,y,cz-d,m); put(x,y,cz+d,m) end
				for z=cz-d,cz+d do put(cx-w,y,z,m); put(cx+w,y,z,m) end
				for _,x in ipairs({cx-w,cx+w}) do for _,z in ipairs({cz-d,cz+d}) do put(x,y,z,f.post) end end
			end
			-- window slits on the long sides, every fourth node
			for y=2,3 do
				for x=cx-w+2,cx+w-2,4 do put(x,y,cz-d,"air"); put(x,y,cz+d,"air") end
				for z=cz-d+2,cz+d-2,4 do put(cx-w,y,z,"air"); put(cx+w,y,z,"air") end
			end
			if opts.open then
				local x=opts.open=="x1" and cx-w or cx+w
				fill(x,1,cz-d+1,x,h,cz+d-1,"air")
			end
			for _,door in ipairs(opts.doors or {}) do
				local x,z=door[1],door[2]
				if x==cx-w or x==cx+w then fill(x,1,z-1,x,3,z+1,"air")
				else fill(x-1,1,z,x+1,3,z,"air") end
			end
			if f.form=="gable" then
				local along_z=w<=d
				for z=cz-d,cz+d do for x=cx-w,cx+w do
					local distance=along_z and math.abs(x-cx) or math.abs(z-cz)
					local y=h+1+math.floor(((along_z and w or d)-distance)/2)
					put(x,y,z,f.roof)
					local gable=along_z and math.abs(z-cz)==d or (not along_z and math.abs(x-cx)==w)
					if gable then fill(x,h+1,z,x,y-1,z,f.up) end
				end end
			else
				fill(cx-w,h+1,cz-d,cx+w,h+1,cz+d,f.roof)
				merlons(cx-w,cz-d,cx+w,cz+d,h+2,f.low)
			end
		end

		-- The keep: the General's hall, solid stone with a crenellated roof
		-- and a keep tower carrying the great banner.
		record("keep",0,16,9,4,13,"keep")
		fill(-9,0,12,9,0,20,f.pave)
		for y=1,6 do
			local m=y==1 and f.wall or f.keep
			for x=-9,9 do put(x,y,12,m); put(x,y,20,m) end
			for z=12,20 do put(-9,y,z,m); put(9,y,z,m) end
		end
		fill(-9,7,12,9,7,20,f.keep); merlons(-9,12,9,20,8,f.keep)
		fill(-1,1,12,1,3,12,"air"); fill(-2,4,12,2,4,12,f.trim)
		for _,x in ipairs({-6,6}) do fill(x,3,12,x,4,12,"air") end
		for _,z in ipairs({15,18}) do fill(-9,3,z,-9,4,z,"air"); fill(9,3,z,9,4,z,"air") end
		tower(-3,15,3,20,12,8)
		pennant(0,13,18,f.post,15)
		-- inside: the war table, the seat behind the General, hall banners
		put(4,1,15,f.fence); put(6,1,15,f.fence)
		for x=4,6 do put(x,2,15,"stairs:slab_wood") end
		put(0,1,19,"grug_decor:xdecor_chair")
		for _,x in ipairs({-4,4}) do fill(x,3,20,x,5,20,cloth.main); put(x,5,20,cloth.trim) end
		for _,q in ipairs({{-8,13},{8,13},{-8,19},{8,19}}) do put(q[1],1,q[2],"default:torch",1) end
		put(-8,1,16,"grug_decor:xdecor_barrel"); put(-8,1,17,"grug_decor:xdecor_barrel")

		-- West: the barracks against the curtain wall, cots along its back.
		hall("barracks",-18,2,4,8,4,{kind="barracks",doors={{-14,0}}})
		for z=-5,9,2 do put(-21,1,z,"grug_decor:cottages_straw_mat") end
		for z=-5,9,4 do put(-17,1,z,"grug_decor:cottages_straw_mat") end
		put(-15,1,9,"grug_decor:xdecor_barrel"); put(-16,1,9,"grug_decor:xdecor_barrel")
		put(-15,1,-5,"grug_decor:cottages_bench"); put(-16,1,-5,"grug_decor:cottages_bench")
		-- North-west: stores beside the keep.
		for _,q in ipairs({{-21,13},{-20,13},{-21,14},{-21,15},{-19,13}}) do put(q[1],1,q[2],"grug_decor:xdecor_barrel") end
		put(-21,2,13,"grug_decor:xdecor_barrel")
		put(-15,1,15,"grug_decor:cottages_wagon_wheel")
		-- East: the Quartermaster's store, open to the cross way behind a
		-- counter, and the armoury north of it.
		hall("quartermaster store",19,0,3,5,4,{kind="store",open="x1"})
		for z=-2,2 do put(17,1,z,"grug_decor:xdecor_barrel") end
		put(17,1,-1,"stairs:slab_wood"); put(17,1,1,"stairs:slab_wood")
		for z=-4,4,2 do put(21,1,z,"grug_decor:cottages_shelf") end
		hall("armoury",18,12,4,4,4,{kind="armoury",doors={{14,12}}})
		put(20,1,10,"grug_decor:cottages_anvil"); put(21,1,14,"grug_decor:xdecor_barrel")
		for z=10,14,2 do put(21,1,z-1,f.fence) end
		-- South-west: the drill yard with straw targets and a weapon rail.
		fill(-20,0,-19,-11,0,-11,f.yard)
		for _,x in ipairs({-18,-15,-12}) do fill(x,1,-17,x,2,-17,f.post); put(x,3,-17,"grug_decor:cottages_straw_bale") end
		fill(-20,1,-12,-17,1,-12,f.fence)
		record("drill yard",-15,-15,5,4,3,"yard")
		-- South-east: the waypoint pad, the capitals' stone cross and diamond
		-- at reach 3 (settlements.md "Waypoint pads").
		for dz=-3,3 do for dx=-3,3 do
			local d=math.abs(dx)+math.abs(dz)
			if d<=3 then put(12+dx,0,-12+dz,(dx==0 or dz==0 or d==3) and f.trim or f.pave) end
		end end
		put(12,1,-12,"grug_mapgen:waystone")
		record("waypoint pad",12,-12,3,3,1,"waypoint")
		for _,q in ipairs({{-4,-9},{4,-9},{-4,9},{4,9},{-12,3},{15,3},{9,-16}}) do lamp(q[1],q[2],f.post) end

		-- Sockets. Gate guards stand in the passage facing out; ten inner
		-- posts; the General with two bodyguards in the keep; three quest
		-- givers; the Quartermaster behind the counter; the waystone.
		socket("gate_west","guard_post",-2,-r+3,0,-1,{group="gate"})
		socket("gate_east","guard_post",2,-r+3,0,-1,{group="gate"})
		local posts={{"keep_door_west",-3,10,0,-1},{"keep_door_east",3,10,0,-1},
			{"yard_west",-8,-4,0,-1},{"yard_east",8,-4,0,-1},
			{"gate_inner_west",-5,-18,0,-1},{"gate_inner_east",5,-18,0,-1},
			{"corner_southwest",-19,-19,1,0},{"corner_southeast",19,-19,-1,0},
			{"corner_northwest",-19,19,1,0},{"corner_northeast",19,19,-1,0}}
		for _,q in ipairs(posts) do socket(q[1],"guard_post",q[2],q[3],q[4],q[5],{group="inner"}) end
		socket("general","general",0,17,0,-1)
		socket("bodyguard_west","bodyguard",-2,16,0,-1)
		socket("bodyguard_east","bodyguard",2,16,0,-1)
		socket("quest_warmaster","quest",-6,10,0,-1)
		socket("quest_drillmaster","quest",-10,-9,0,-1)
		socket("quest_scout","quest",7,-9,0,-1)
		socket("vendor_quartermaster","vendor",19,0,-1,0,{kind="general"})
		socket("travel_waypoint","waypoint",12,-12,0,1)
	else
		local c=assert(CAMP[art.race], "Round 31 PvP camp race differs")
		assert(FACTION_OF[art.race]==art.faction, "Round 31 PvP camp race is not of its faction")
		local high=art.kind=="pvp_camp_high"
		fill(-r,0,-r,r,0,r,c.ground)
		fill(-r,1,-r,r,height,r,"air")
		-- Palisade: one ring of upright logs, every other one a node taller,
		-- the gate three wide on local -z between two flag posts.
		for z=-r,r do for x=-r,r do
			if math.max(math.abs(x),math.abs(z))==r then
				fill(x,1,z,x,3+(x+z)%2,z,c.post)
			end
		end end
		fill(-1,1,-r,1,4,-r,"air")
		for _,x in ipairs({-2,2}) do
			put(x,1,-r,c.stone); fill(x,2,-r,x,5,-r,c.post); put(x,6,-r,"default:torch",1)
		end
		fill(-1,3,-r,-1,4,-r,cloth.main); fill(1,3,-r,1,4,-r,cloth.main)
		record("palisade",0,0,r,r,5,"palisade")
		-- The yard: trampled ground from the gate to the command tent.
		fill(-1,0,-r,1,0,-r+3,c.yard)
		fill(-6,0,-r+3,6,0,high and 4 or 3,c.yard)
		-- A ridge tent of faction cloth along z: the courses step in one node
		-- per course to a ridge `half`+1 high, the back closed, the front open.
		local function tent(label,cx,z1,z2,half,kind)
			record(label,cx,math.floor((z1+z2)/2),half,math.floor((z2-z1)/2),half+1,kind)
			for z=z1,z2 do for dx=-half,half do put(cx+dx,half+1-math.abs(dx),z,cloth.main) end end
			put(cx,half+1,z1,cloth.trim)
			for dx=-half+1,half-1 do fill(cx+dx,1,z2,cx+dx,half-math.abs(dx),z2,cloth.main) end
		end
		-- The command tent and its standard, the captain before its door.
		local ch=high and 4 or 3
		local cz1,cz2=high and 5 or 4, high and 10 or 8
		tent("command tent",0,cz1,cz2,ch,"command")
		fill(-ch+1,0,cz1+1,ch-1,0,cz2-1,c.rug)
		put(-ch+1,1,cz2-1,"grug_decor:xdecor_barrel"); put(ch-1,1,cz2-1,"grug_decor:xdecor_table")
		pennant(ch+2,1,cz2,c.post,5)
		-- Soldiers' tents in one row on the west side, all facing the gate.
		local tx=high and -9 or -8
		local rows=high and {{-6,-3},{0,3}} or {{-8,-5},{-2,1}}
		for i,z in ipairs(rows) do
			tent("soldiers' tent "..i,tx,z[1],z[2],2,"tent")
			put(tx-1,1,z[2]-1,"grug_decor:cottages_straw_mat"); put(tx+1,1,z[2]-1,"grug_decor:cottages_straw_mat")
		end
		-- The shelter for own-faction players on the east side: a roofed,
		-- open-fronted lean-to with bedrolls, a bench and a light.
		local sx1,sx2,sz1,sz2=5,high and 11 or 10,high and -5 or -8,high and 3 or 1
		record("shelter",math.floor((sx1+sx2)/2),math.floor((sz1+sz2)/2),
			math.floor((sx2-sx1)/2),math.floor((sz2-sz1)/2),4,"shelter")
		fill(sx2,1,sz1,sx2,3,sz2,c.wood)
		fill(sx1+1,1,sz1,sx2,2,sz1,c.wood); fill(sx1+1,1,sz2,sx2,2,sz2,c.wood)
		for _,z in ipairs({sz1,sz2}) do fill(sx1,1,z,sx1,3,z,c.post); fill(sx2,1,z,sx2,3,z,c.post) end
		fill(sx1,4,sz1,sx2,4,sz2,c.roof)
		fill(sx1+1,0,sz1+1,sx2-1,0,sz2-1,c.wood)
		for z=sz1+1,sz2-1,2 do put(sx2-1,1,z,"grug_decor:cottages_straw_mat") end
		put(sx1+1,1,sz2-1,"grug_decor:cottages_bench"); put(sx1+2,1,sz2-1,"grug_decor:cottages_bench")
		put(sx2-1,1,sz2-1,"grug_decor:xdecor_lantern")
		-- Supplies and a weapon rail by the command tent, a cooking place
		-- opposite: no open fire, the camp's light is torches and lanterns.
		local nz=high and 9 or 7
		for _,q in ipairs({{-r+2,nz},{-r+3,nz},{-r+2,nz-1}}) do put(q[1],1,q[2],"grug_decor:xdecor_barrel") end
		put(-r+2,2,nz,"grug_decor:xdecor_barrel")
		fill(-r+2,1,nz-3,-r+4,1,nz-3,c.fence)
		put(r-4,1,nz,"grug_decor:xdecor_cauldron")
		for _,q in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do put(r-4+q[1],0,nz+q[2],c.stone) end
		lamp(-4,-r+3,c.post); lamp(4,-r+3,c.post)
		local captain_z=cz1-1
		if high then
			-- Two watchtowers by the gate: a deck on four posts, a railing
			-- open over the ladder, a roof; the ladder on the inner side.
			for _,cx in ipairs({-10,10}) do
				local cz=-10
				record("watchtower",cx,cz,1,1,8,"tower")
				for _,dx in ipairs({-1,1}) do for _,dz in ipairs({-1,1}) do
					fill(cx+dx,1,cz+dz,cx+dx,7,cz+dz,c.post)
				end end
				fill(cx,1,cz+1,cx,5,cz+1,c.post)
				fill(cx-1,5,cz-1,cx+1,5,cz+1,c.wood)
				for x=cx-1,cx+1 do put(x,6,cz-1,c.fence) end
				put(cx-1,6,cz,c.fence); put(cx+1,6,cz,c.fence)
				fill(cx-1,8,cz-1,cx+1,8,cz+1,c.roof)
				for y=1,5 do put(cx,y,cz+2,"default:ladder_wood",5) end
			end
			-- Straw targets: a drill line inside the palisade.
			for _,x in ipairs({-4,-2}) do put(x,1,nz+2,c.post); put(x,2,nz+2,"grug_decor:cottages_straw_bale") end
			socket("gate_west","guard_post",-2,-r+2,0,-1,{group="gate"})
			socket("gate_east","guard_post",2,-r+2,0,-1,{group="gate"})
			socket("tower_west","guard_post",-10,-7,0,-1,{group="camp"})
			socket("tower_east","guard_post",10,-7,0,-1,{group="camp"})
			socket("yard_west","guard_post",-5,captain_z,0,-1,{group="camp"})
		else
			socket("gate_west","guard_post",-2,-r+2,0,-1,{group="gate"})
			socket("gate_east","guard_post",2,-r+2,0,-1,{group="gate"})
			socket("yard_west","guard_post",-4,captain_z,0,-1,{group="camp"})
			socket("yard_east","guard_post",4,captain_z,0,-1,{group="camp"})
		end
		socket("captain","captain",0,captain_z,0,-1)
	end

	-- The anchor root and its yard stay open; nothing is authored onto them.
	for z=-2,2 do for x=-2,2 do for y=1,3 do
		assert(name_at(x,y,z)=="air","Round 31 "..art.kind..": central actor clearance blocked")
	end end end
	assert(name_at(0,0,0)~="air","Round 31 "..art.kind..": anchor support missing")

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
		landmarks={structures=structures,sockets=sockets,arrival={x=0,y=1,z=0}}}
end

-- Socket roles (lanes M and G):
--   guard_post  one guard at an authored post; `group` "gate" (the fortress's
--               two gate guards, a camp's two gate guards), "inner" (fortress
--               elites inside the wall) or "camp" (the rest of a camp garrison)
--   general     the fortress General (level-65 elite, king chassis)
--   bodyguard   the General's two level-60 elite bodyguards
--   captain     the camp's named captain
--   quest       a protected quest giver (fortress)
--   vendor      `kind = "general"`: the fortress Quartermaster
--   waypoint    `travel_waypoint`: the waystone cell (grug_home reads it)
