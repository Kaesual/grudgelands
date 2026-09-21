-- Round 15 regional village, outpost and bandit-camp compositions.
-- The macro map owns anchors, roads, fitting and protection; this module owns
-- only the guaranteed flat core above one existing anchor.
-- Plain Lua 5.1, no globals.

return function(spec)
	local palettes = {
		dwarf={ground="default:dirt_with_coniferous_litter",foundation="default:stonebrick",wall="default:pine_wood",post="default:pine_tree",roof="stairs:slab_pine_wood",accent="default:copperblock"},
		human={ground="default:dirt_with_grass",foundation="default:cobble",wall="grug_decor:cottages_loam",post="default:tree",roof="grug_decor:darkage_slate_tile_slab",accent="default:brick"},
		elf={ground="grug_nodes:dirt_with_silver_litter",foundation="default:silver_sandstone_brick",wall="grug_trees:silverwood_wood",post="grug_trees:silverwood_tree",roof="grug_decor:darkage_slate_tile_slab",accent="grug_materials:emberglass_lamp"},
		undead={ground="grug_nodes:dirt_with_bone_litter",foundation="default:mossycobble",wall="grug_trees:gravewood_wood",post="grug_trees:gravewood_tree",roof="stairs:slab_stonebrick",accent="grug_nodes:bone_pile"},
		orc={ground="default:dry_dirt_with_dry_grass",foundation="default:desert_stonebrick",wall="default:acacia_wood",post="default:acacia_tree",roof="stairs:slab_desert_stonebrick",accent="default:desert_cobble"},
		troll={ground="default:dirt_with_rainforest_litter",foundation="default:mossycobble",wall="default:junglewood",post="default:jungletree",roof="stairs:slab_junglewood",accent="default:clay"},
	}
	local p = assert(palettes[spec.race], "Round 14 POI race differs")
	p.accent = "grug_mapgen:poi_display_" .. spec.race
	local roof_blocks = {dwarf="default:pine_wood",human="grug_decor:darkage_slate_tile",
		elf="grug_decor:darkage_slate_tile",undead="default:stonebrick",
		orc="default:desert_stonebrick",troll="default:junglewood"}
	p.roof_block = roof_blocks[spec.race]
	local low, high = -12, 11
	if spec.kind == "outpost" then low, high = -8, 7 end
	local cells, by_pos, names = {}, {}, {air=true}
	local function key(x,y,z) return x .. ":" .. y .. ":" .. z end
	local function put(x,y,z,name,param2)
		by_pos[key(x,y,z)]={x=x,y=y,z=z,name=name,param2=param2 or 0}
		names[name]=true
	end
	local function fill(x1,y1,z1,x2,y2,z2,name)
		for z=z1,z2 do for y=y1,y2 do for x=x1,x2 do put(x,y,z,name) end end end
	end
	local structures={}
	local function record(label,x,z,w,d,h)
		local entry={label=label,x=x,z=z,w=w,d=d,h=h or 4}
		structures[#structures+1]=entry
		return entry
	end
	local function course(distance,radius,base,steep)
		local step=radius-distance
		if steep then return base+step,p.roof_block end
		return base+math.floor(step/2),step%2==0 and p.roof or p.roof_block
	end
	-- Every house is authored in local coordinates; a turn changes its entry,
	-- ridge and furnishing together. Full foundations carry every wall.
	local function house(label,cx,cz,w,d,h,turn,style)
		local building=record(label,cx,cz,w,d,h)
		local raised=spec.race=="troll" and 1 or 0
		building.interior={x=cx,y=raised+1,z=cz}
		local function at(x,y,z,n,param2)
			for _=1,turn or 0 do x,z=-z,x end
			put(cx+x,y+raised,cz+z,n,param2)
		end
		for x=-w,w do for z=-d,d do at(x,0,z,p.foundation) end end
		if raised>0 then
			for _,x in ipairs({-w,w}) do for _,z in ipairs({-d,d}) do at(x,-1,z,p.post) end end
			for x=-1,1 do at(x,0,-d-1,"stairs:stair_junglewood",(4-(turn or 0))%4) end
		end
		for y=1,h do
			local wall=y==1 and p.foundation or p.wall
			for x=-w,w do at(x,y,-d,wall); at(x,y,d,wall) end
			for z=-d,d do at(-w,y,z,wall); at(w,y,z,wall) end
		end
		for _,x in ipairs({-w,w}) do for _,z in ipairs({-d,d}) do
			for y=1,h do at(x,y,z,p.post) end
		end end
		for x=-w,w do at(x,h,-d,p.post); at(x,h,d,p.post) end
		for _,x in ipairs({-w,w}) do for z=-1,1 do at(x,2,z,"default:glass") end end
		for x=-1,1 do for y=1,math.min(3,h) do at(x,y,-d,"air") end end
		for x=-w-1,w+1 do
			local y,material=course(math.abs(x),w+1,h+1,style=="spire")
			if style=="flat" then y,material=h+1,p.roof_block end
			for z=-d-1,d+1 do at(x,y,z,material) end
			if math.abs(x)<=w then for gy=h+1,y-1 do
				at(x,gy,-d,p.wall); at(x,gy,d,p.wall)
			end end
		end
		-- Separate rear work surface and sleeping/bench side leave the entry clear.
		for x=-w+1,w-1 do at(x,1,d-1,p.post); at(x,2,d-1,p.roof,20) end
		for z=0,d-2 do at(-w+1,1,z,p.roof) end
		at(w-1,1,0,"grug_decor:xdecor_barrel")
		at(0,3,d-1,"grug_decor:xdecor_candle",1)
		at(w-1,1,-d+2,"grug_decor:cottages_straw_mat")
		at(w-1,1,-d+1,"grug_decor:cottages_straw_mat")
		local work={dwarf="grug_decor:cottages_anvil",human="grug_decor:cottages_straw_bale",
			elf="grug_decor:xdecor_potted_viola",undead="grug_decor:xdecor_candle",
			orc="grug_decor:xdecor_cauldron",troll="grug_decor:xdecor_potted_chrysanthemum_green"}
		if spec.race=="undead" then at(0,3,d-1,work[spec.race],1)
		else at(w-1,1,d-2,work[spec.race]) end
	end
	local function canopy(label,cx,cz,w,d,h)
		record(label,cx,cz,w,d,h).kind="canopy"
		for _,x in ipairs({-w,w}) do for _,z in ipairs({-d,d}) do
			fill(cx+x,1,cz+z,cx+x,h,cz+z,p.post)
		end end
		for z=-d,d do
			local y,n=course(math.abs(z),d,h+1)
			fill(cx-w,y,cz+z,cx+w,y,cz+z,n)
		end
		local beam_y=math.max(h,3)
		fill(cx-w,beam_y,cz-d,cx+w,beam_y,cz-d,p.post)
		fill(cx-w,beam_y,cz+d,cx+w,beam_y,cz+d,p.post)
	end
	local function stores(x,z,n)
		for i=0,n-1 do put(x+i,1,z,"grug_decor:xdecor_barrel") end
		if n>2 then put(x+1,2,z,"grug_decor:xdecor_barrel") end
	end
	local function timber(x,z,n)
		for i=0,n-1 do fill(x+i,1,z,x+i,2,z,p.post) end
	end
	local function tree(x,z)
		fill(x,1,z,x,4,z,p.post)
		fill(x-1,4,z-1,x+1,5,z+1,spec.race=="human" and "default:leaves" or "default:jungleleaves")
	end
	local function mats(x,z)
		put(x,1,z,"grug_decor:cottages_straw_mat")
		put(x,1,z+1,"grug_decor:cottages_straw_mat")
	end
	local function lamp(x,z)
		put(x,1,z,p.foundation); put(x,2,z,"grug_decor:xdecor_lantern")
	end
	local function bench(x,z,dir)
		put(x,1,z,"grug_decor:cottages_bench",dir or 0)
		put(x+1,1,z,"grug_decor:cottages_bench",dir or 0)
	end
	local function ruin(x,z,w,d)
		record("broken enclosure",x,z,w,d)
		for dz=-d,d do fill(x-w,1,z+dz,x-w,1+(dz+d)%3,z+dz,p.foundation) end
		for dx=-w,w do fill(x+dx,1,z+d,x+dx,1+(dx+w)%2,z+d,p.foundation) end
		-- Two unequal broken gate piers still carry the remnant of an arch.
		fill(x-w,1,z-d,x-w,4,z-d,p.foundation)
		fill(x-w+4,1,z-d,x-w+4,3,z-d,p.foundation)
		fill(x-w+1,4,z-d,x-w+2,4,z-d,p.foundation)
		put(x-w+3,3,z-d,"stairs:slab_mossycobble",20)
	end
	local function lookout(cx,cz,w,h,roofed)
		record("lookout",cx,cz,w,w,h)
		for _,dx in ipairs({-w,w}) do for _,dz in ipairs({-w,w}) do
			fill(cx+dx,1,cz+dz,cx+dx,h,cz+dz,p.post)
		end end
		fill(cx-w,h,cz-w,cx+w,h,cz+w,p.wall)
		for x=cx-w,cx+w do put(x,h+1,cz+w,"default:fence_wood") end
		for z=cz-w,cz+w do put(cx-w,h+1,z,"default:fence_wood"); put(cx+w,h+1,z,"default:fence_wood") end
		-- Ladder faces its full-height support; a two-node opening admits the climber.
		fill(cx,1,cz-w,cx,h,cz-w,p.post)
		for y=1,h do put(cx,y,cz-w-1,"default:ladder_wood",4) end
		if roofed then canopy("lookout roof",cx,cz,w,w,h+2) end
	end
	fill(low,0,low,high,0,high,p.ground)
	fill(low,1,low,high,8,high,"air")
	-- Off-centre yards connect all approaches without a mechanical four-way grid.
	fill(-1,0,low,1,0,1,p.foundation)
	local function path(x1,z1,x2,z2)
		fill(x1,0,z1,x2,0,z2,p.foundation)
	end
	local sockets={}
	local race=spec.race
	if spec.kind=="village" then
		if race=="human" then
			house("granary hall",-5,5,4,4,4,0)
			house("turned dwelling",7,4,2,3,3,3)
			canopy("work shed",-7,-6,3,2,3); stores(-9,-5,4)
			tree(7,-7); tree(9,-3); timber(-9,9,3)
			for z=-9,-5,2 do for x=3,5 do put(x,1,z,"grug_decor:xdecor_potted_dandelion_yellow") end end
			put(-8,3,8,"grug_decor:xdecor_candle",1)
			fill(2,1,-10,9,1,-10,"default:fence_wood")
			fill(10,1,-10,10,1,-5,"default:fence_wood")
			fill(-9,0,-7,-5,0,-5,"grug_decor:cottages_straw_ground")
			put(-9,1,-7,"grug_decor:cottages_straw_bale"); put(-8,1,-7,"grug_decor:cottages_straw_bale")
			put(-7,1,-7,"grug_decor:xdecor_workbench"); lamp(-4,-5); bench(3,1,2)
			put(-4,1,-2,"grug_decor:xdecor_table")
			fill(-8,1,8,-7,6,9,"default:brick")
			path(-6,-2,5,0); path(-6,-4,-5,1); path(4,0,5,4)
		elseif race=="dwarf" then
			house("long workshop",-6,3,3,6,3,0)
			house("cross dwelling",5,-7,2,4,3,3)
			canopy("stone workyard",6,6,3,3,3); stores(4,8,4)
			fill(-8,4,7,-7,7,8,p.foundation); timber(-9,-8,4)
			put(5,1,6,"grug_decor:cottages_anvil"); path(-6,-3,1,-2); path(0,1,6,2); path(5,2,6,6); path(0,-6,1,-3)
		elseif race=="elf" then
			house("tall grove house",-7,-3,2,5,4,2,"spire")
			house("short grove house",5,6,2,3,3,0,"spire")
			canopy("communal walk",-3,4,2,1,3)
			tree(8,-6); tree(-8,8); stores(4,8,3); path(-7,3,5,4); path(0,1,1,3)
			bench(3,-5,2); lamp(-3,5)
			put(-8,1,7,"grug_decor:xdecor_potted_viola")
		elseif race=="undead" then
			house("wax workshop",-6,-6,4,3,3,2,"flat")
			house("narrow dwelling",6,5,2,4,4,3)
			ruin(-7,6,3,2)
			for x=-8,-4,2 do put(x,1,7,p.foundation); put(x,2,7,p.accent) end
			stores(-8,-7,4); canopy("wax drying",6,-6,2,2,2); path(-6,-2,1,-1); path(-7,2,5,3); path(0,1,1,3)
			for x=-8,-4,2 do put(x,3,7,"grug_decor:xdecor_candle",1) end
			lamp(3,1); put(4,1,-5,"grug_decor:cottages_shelf")
		elseif race=="orc" then
			house("earth longhouse",6,3,5,3,3,3,"flat")
			house("low annex",-6,7,3,2,2,0,"flat")
			canopy("cooking court",-7,-6,3,2,3); stores(-9,-5,3)
			fill(4,1,-8,7,1,-8,p.foundation); timber(8,-4,2)
			put(-7,1,-6,"grug_decor:xdecor_cauldron"); path(-6,2,1,3); path(-7,-3,0,-2); path(0,1,2,4)
		else
			house("communal rainhouse",-2,7,5,2,3,0)
			canopy("raised veranda",-2,3,5,1,4)
			house("small dwelling",-7,-5,2,3,3,1)
			canopy("preparation shelter",7,-5,2,3,2); stores(6,-3,3)
			tree(8,7); timber(-10,8,2); path(-2,1,1,4); path(-3,-6,5,-5)
			put(7,1,-6,"grug_decor:xdecor_workbench"); lamp(4,-4)
			bench(3,0,2)
		end
		sockets={{id="quest_steward",role="quest",x=2,y=1,z=0,dir={x=-1,z=0}},
			{id="quest_local",role="quest",x=-2,y=1,z=-2,dir={x=0,z=-1}},
			{id="resident_work",role="idle",x=-2,y=1,z=0,dir={x=-1,z=0},tags={"work"}},
			{id="resident_spare",role="idle",x=0,y=1,z=-3,dir={x=0,z=-1},spawn=false}}
	elseif spec.kind=="outpost" then
		if race=="human" then
			lookout(-4,3,2,4,true); house("side office",4,4,2,2,3,0)
			stores(3,5,2)
		elseif race=="dwarf" then
			lookout(-4,3,2,3,false); ruin(-4,3,2,2)
			canopy("guard shelter",4,3,2,3,3); stores(4,5,2)
		elseif race=="elf" then
			lookout(-4,3,1,4,true); canopy("open stores",4,4,2,2,2)
			stores(3,5,3); tree(-5,-5)
		elseif race=="undead" then
			house("low watchhouse",-3,4,3,2,3,0,"flat")
			lookout(5,4,1,2,false); canopy("observation niche",5,-5,1,2,2)
		elseif race=="orc" then
			lookout(-4,3,2,4,true); canopy("guard stores",4,4,2,2,2)
			for _,q in ipairs({{-7,-5},{-6,-5},{-5,-4},{-4,-4},{-3,-3}}) do fill(q[1],1,q[2],q[1],3,q[2],p.post) end
			stores(3,5,3)
		else
			lookout(4,3,2,4,true); canopy("dry equipment",-5,3,2,3,2)
			stores(-6,5,3); timber(-6,-5,3)
		end
		put(5,1,3,"grug_decor:xdecor_table"); lamp(6,-2)
		sockets={{id="quest_scout",role="quest",x=3,y=1,z=-3,dir={x=0,z=-1}}}
	elseif spec.kind=="camp" then
		if race=="human" then
			house("plundered barn",4,5,5,3,3,0)
			ruin(-6,6,4,3)
			canopy("patched lean-to",-7,-6,2,3,2); stores(-8,-5,3); timber(-9,-10,3)
			fill(-8,0,-8,-6,0,-4,"grug_decor:cottages_straw_ground")
			put(-8,1,-8,"grug_decor:cottages_straw_bale"); put(-7,1,-8,"grug_decor:cottages_straw_bale")
			put(-8,3,-9,"stairs:slab_wood"); put(-7,3,-9,"stairs:slab_wood")
			fill(5,1,-5,9,1,-5,"default:fence_wood"); lamp(-3,-4); path(-5,-3,0,-2); path(0,0,4,1)
		elseif race=="dwarf" then
			ruin(-6,4,4,5); canopy("occupied workshop",-6,5,3,3,3)
			stores(5,-5,3); timber(-9,-7,5)
			put(-7,1,6,"grug_decor:cottages_anvil"); put(-5,1,7,"grug_decor:xdecor_workbench")
			mats(-8,4); lamp(-3,7); stores(5,-8,2); path(-5,0,1,1); path(0,-4,5,-3)
		elseif race=="elf" then
			canopy("poacher hall",-6,3,2,6,3); canopy("hide shelter",5,-7,4,1,2)
			timber(-9,-7,5); stores(5,-3,3)
			fill(-8,1,8,-8,3,8,p.post); fill(-4,1,8,-4,3,8,p.post)
			fill(-7,2,8,-5,3,8,"wool:brown")
			mats(5,-6); lamp(-3,4); path(-5,-4,1,-3); path(0,-6,5,-5)
			for _,q in ipairs({{6,4},{3,7},{-4,-5}}) do put(q[1],1,q[2],p.post) end
		elseif race=="undead" then
			ruin(-6,4,4,5); canopy("ruin command shelter",-6,6,3,2,3)
			record("open raised supply rack",5,-6,3,2,2)
			fill(3,1,-5,7,1,-5,p.post); fill(3,2,-5,7,2,-5,p.accent)
			fill(3,1,-7,7,1,-7,p.foundation)
			for x=3,7 do put(x,2,-5,"grug_decor:xdecor_barrel") end
			put(-8,1,6,"grug_decor:cottages_straw_mat"); put(-8,1,7,"grug_decor:cottages_straw_mat")
			put(-5,1,7,"grug_decor:xdecor_table"); lamp(-3,7)
			fill(-10,1,8,-10,4,9,p.foundation); path(-5,0,1,1); path(0,-4,5,-3)
			for _,q in ipairs({{-10,-8},{-8,-9},{-5,-8},{6,5},{5,7},{-10,10}}) do
				put(q[1],0,q[2],p.foundation); put(q[1],1,q[2],"default:fern_2")
			end
		elseif race=="orc" then
			canopy("caravan shade",-2,5,6,4,3); record("freight yard",6,-5,3,2,1)
			stores(-9,7,5); stores(3,-5,3); timber(-9,-7,3)
			put(-9,1,5,"grug_decor:cottages_wagon_wheel")
			put(-4,1,7,"grug_decor:cottages_straw_bale"); mats(6,-7)
			put(-5,1,4,"grug_decor:xdecor_table"); lamp(-2,7); path(0,-4,6,-3)
		else
			canopy("patched main canopy",-5,2,3,6,3)
			canopy("sleeping mat shelter",6,-7,2,1,2)
			canopy("small sleeping place",6,3,2,2,2); stores(5,-5,3)
			mats(6,-7); mats(6,3); mats(-6,5)
			put(-5,1,7,"grug_decor:xdecor_table"); lamp(-2,7)
			fill(-7,4,-4,-5,4,-4,"stairs:slab_pine_wood"); path(-4,-5,1,-4); path(0,-4,5,-3); path(0,2,4,3)
		end
		lamp(8,7); put(9,1,10,"grug_decor:cottages_straw_mat")
		-- A visible but open captive enclosure outside the hostile spawn disk.
		fill(8,1,11,11,2,11,p.post); fill(11,1,8,11,2,11,p.post)
		record("open captive enclosure",9,9,2,2,2)
		sockets={{id="quest_captive",role="quest",x=10,y=1,z=10,dir={x=0,z=-1}}}
	else error("POI kind differs",0) end

	local grass=spec.race=="orc" and "default:dry_shrub" or "default:fern_1"
	for _,q in ipairs({{low+1,low+1},{high-1,low+1},{low+1,high-1}}) do
		if by_pos[key(q[1],1,q[2])].name=="air" then put(q[1],1,q[2],grass,grass=="default:dry_shrub" and 4 or 0) end
	end

	for _,cell in pairs(by_pos) do cells[#cells+1]=cell end
	table.sort(cells,function(a,b)
		return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x)))
	end)
	local palette={}
	for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette)
	return {schema=spec.schema,palette=palette,cells=cells,
		bounds={min={x=low,y=0,z=low},max={x=high,y=8,z=high}},
		clear_to=8,landmarks={structures=structures,sockets=sockets,arrival={x=0,y=1,z=0}}}
end
