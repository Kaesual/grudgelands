-- Round 14's bounded village, outpost and bandit-camp compositions.
-- The macro map owns anchors, roads, fitting and protection; this module owns
-- only the guaranteed flat core above one existing anchor.
-- Plain Lua 5.1, no globals.

return function(spec)
	local palettes = {
		dwarf={ground="default:dirt_with_coniferous_litter",foundation="default:stonebrick",wall="default:pine_wood",post="default:pine_tree",roof="stairs:slab_pine_wood",accent="default:copperblock"},
		human={ground="default:dirt_with_grass",foundation="default:cobble",wall="default:wood",post="default:tree",roof="stairs:slab_wood",accent="default:brick"},
		elf={ground="grug_nodes:dirt_with_silver_litter",foundation="default:silver_sandstone_brick",wall="grug_trees:silverwood_wood",post="grug_trees:silverwood_tree",roof="grug_decor:darkage_slate_tile_slab",accent="grug_materials:emberglass_lamp"},
		undead={ground="grug_nodes:dirt_with_bone_litter",foundation="default:mossycobble",wall="grug_trees:gravewood_wood",post="grug_trees:gravewood_tree",roof="stairs:slab_stonebrick",accent="grug_nodes:bone_pile"},
		orc={ground="default:dry_dirt_with_dry_grass",foundation="default:desert_stonebrick",wall="default:acacia_wood",post="default:acacia_tree",roof="stairs:slab_desert_stonebrick",accent="default:desert_cobble"},
		troll={ground="default:dirt_with_rainforest_litter",foundation="default:mossycobble",wall="default:junglewood",post="default:jungletree",roof="stairs:slab_junglewood",accent="default:clay"},
	}
	local p = assert(palettes[spec.race], "Round 14 POI race differs")
	p.accent = "grug_mapgen:poi_display_" .. spec.race
	local roof_blocks = {dwarf="default:pine_wood",human="default:wood",
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
	-- Half-node steps alternate full blocks and slabs. Neighbouring roof
	-- courses meet without the floating half-node gaps of stacked slabs.
	local function roof_course(distance,radius,base)
		local step=radius-distance
		return base+math.floor(step/2), step%2==0 and p.roof or p.roof_block
	end
	local function hut(cx,cz,w,d,h)
		fill(cx-w,0,cz-d,cx+w,0,cz+d,p.foundation)
		for y=1,h do
			for x=cx-w,cx+w do put(x,y,cz-d,p.wall); put(x,y,cz+d,p.wall) end
			for z=cz-d,cz+d do put(cx-w,y,z,p.wall); put(cx+w,y,z,p.wall) end
		end
		for _,dx in ipairs({-w,w}) do for _,dz in ipairs({-d,d}) do
			fill(cx+dx,1,cz+dz,cx+dx,h,cz+dz,p.post)
		end end
		-- Timber headers and glazed windows break up the cultural wall panels.
		fill(cx-w,h,cz-d,cx+w,h,cz-d,p.post)
		fill(cx-w,h,cz+d,cx+w,h,cz+d,p.post)
		for _,dz in ipairs({-1,0,1}) do
			put(cx-w,2,cz+dz,"default:glass"); put(cx+w,2,cz+dz,"default:glass")
		end
		for dx=-1,1 do put(cx+dx,2,cz+d,"default:glass") end
		for dx=-w-1,w+1 do
			local y,material=roof_course(math.abs(dx),w+1,h+1)
			fill(cx+dx,y,cz-d-1,cx+dx,y,cz+d+1,material)
			if math.abs(dx)<=w then
				for gy=h+1,y-1 do
					put(cx+dx,gy,cz-d,p.wall); put(cx+dx,gy,cz+d,p.wall)
				end
			end
		end
		-- A three-wide entry stays usable beside the reserved outpost banner.
		for dx=-1,1 do for y=1,3 do put(cx+dx,y,cz-d,"air") end end
		fill(cx-1,4,cz-d,cx+1,4,cz-d,p.post)
		-- Side benches, a rear work table and one display leave the centre free.
		fill(cx-w+1,1,cz-1,cx-w+1,1,cz+1,p.roof)
		put(cx+w-1,1,cz+1,p.post)
		fill(cx+w-1,2,cz,cx+w-1,2,cz+2,p.roof)
		put(cx-w+1,1,cz+d-1,p.accent)
	end
	-- Clear and level only this authored footprint. The pad edge and central
	-- cross make the existing spur's arrival obvious without replacing it.
	fill(low,0,low,high,0,high,p.ground)
	fill(low,1,low,high,8,high,"air")
	fill(-1,0,low,1,0,high,p.foundation)
	fill(low,0,-1,high,0,1,p.foundation)

	-- Open canopies have two full nodes of headroom at their eaves and
	-- a raised ridge, with corner supports and clear entrances on every side.
	local function shelter(cx,cz,w,d)
		for _,dx in ipairs({-w,w}) do for _,dz in ipairs({-d,d}) do
			fill(cx+dx,1,cz+dz,cx+dx,2,cz+dz,p.post)
		end end
		for dz=-d,d do
			local y,material=roof_course(math.abs(dz),d,3)
			fill(cx-w,y,cz+dz,cx+w,y,cz+dz,material)
		end
		-- End crossbeams carry the ridge while the sides remain open.
		put(cx-w,3,cz,p.post); put(cx+w,3,cz,p.post)
	end
	local sockets={}
	if spec.kind=="village" then
		hut(-6,-6,3,3,3); hut(6,-6,3,3,3)
		hut(-6,6,3,3,3); hut(6,6,3,3,3)
		for _,q in ipairs({{-11,-11},{10,-11},{-11,10},{10,10}}) do
			put(q[1],1,q[2],p.post); put(q[1],2,q[2],"default:torch")
		end
		sockets={{id="quest_steward",role="quest",x=2,y=1,z=0,dir={x=1,z=0}},
			{id="resident_work",role="idle",x=-2,y=1,z=1,dir={x=0,z=1},tags={"work"}},
			{id="resident_spare",role="idle",x=0,y=1,z=-3,dir={x=0,z=-1},spawn=false}}
	elseif spec.kind=="outpost" then
		hut(0,3,3,3,4)
		-- Slender watch posts leave the road and central guard-banner root open.
		for _,q in ipairs({{-6,-6},{6,-6},{-6,6},{6,6}}) do
			fill(q[1],1,q[2],q[1],3,q[2],p.post)
			fill(q[1]-1,4,q[2]-1,q[1]+1,4,q[2]+1,p.wall)
			for _,dx in ipairs({-1,1}) do for _,dz in ipairs({-1,1}) do
				fill(q[1]+dx,5,q[2]+dz,q[1]+dx,6,q[2]+dz,p.post)
			end end
			for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
				put(q[1]+d[1],5,q[2]+d[2],"default:fence_wood")
			end
			for dx=-1,1 do
				local y,material=roof_course(math.abs(dx),1,7)
				fill(q[1]+dx,y,q[2]-1,q[1]+dx,y,q[2]+1,material)
			end
		end
		sockets={{id="quest_scout",role="quest",x=3,y=1,z=-3,dir={x=0,z=-1}}}
	elseif spec.kind=="camp" then
		-- The existing writer owns the camp fire at (0,1,0). Four shelters
		-- surround it; the captive canopy stays beyond its 12-node spawn disk.
		for _,q in ipairs({{-6,-6},{6,-6},{-6,6},{5,5}}) do
			shelter(q[1],q[2],2,2)
		end
		fill(-3,1,10,3,1,10,p.post)
		for x=-3,3,3 do put(x,2,10,p.accent) end
		fill(-2,1,-10,2,1,-10,p.accent)
		shelter(9,9,2,2)
		sockets={{id="quest_captive",role="quest",x=10,y=1,z=10,dir={x=0,z=-1}}}
	else error("Round 14 POI kind differs",0) end

	for _,cell in pairs(by_pos) do cells[#cells+1]=cell end
	table.sort(cells,function(a,b)
		return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x)))
	end)
	local palette={}
	for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette)
	return {schema=spec.schema,palette=palette,cells=cells,
		bounds={min={x=low,y=0,z=low},max={x=high,y=8,z=high}},
		clear_to=8,landmarks={sockets=sockets,arrival={x=0,y=1,z=0}}}
end
