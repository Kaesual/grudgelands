-- Bounded, authored Round 20 places. This is a pure cell builder; the existing
-- R7 successor owns projection, clipping, protection and actor-root precedence.
return function(options, profile)
	local spec = assert(profile and profile.art, "Round 20 art profile missing")
	local palettes = {
		dwarf={ground="default:dirt_with_coniferous_litter",stone="default:stonebrick",wood="default:pine_wood",post="default:pine_tree",roof="default:stonebrick",slab="stairs:slab_stonebrick"},
		human={ground="default:dirt_with_grass",stone="default:cobble",wood="grug_decor:cottages_loam",post="default:tree",roof="grug_decor:darkage_slate_tile",slab="grug_decor:darkage_slate_tile_slab"},
		elf={ground="grug_nodes:dirt_with_silver_litter",stone="default:silver_sandstone_brick",wood="grug_trees:silverwood_wood",post="grug_trees:silverwood_tree",roof="grug_decor:darkage_slate_tile",slab="grug_decor:darkage_slate_tile_slab"},
		undead={ground="grug_nodes:dirt_with_bone_litter",stone="default:mossycobble",wood="grug_trees:gravewood_wood",post="grug_trees:gravewood_tree",roof="default:stonebrick",slab="stairs:slab_stonebrick"},
		orc={ground="default:dry_dirt_with_dry_grass",stone="default:desert_stonebrick",wood="default:acacia_wood",post="default:acacia_tree",roof="default:desert_stonebrick",slab="stairs:slab_desert_stonebrick"},
		troll={ground="default:dirt_with_rainforest_litter",stone="default:mossycobble",wood="default:junglewood",post="default:jungletree",roof="default:junglewood",slab="stairs:slab_junglewood"},
	}
	local p = assert(palettes[spec.race])
	local lo, hi = -spec.width/2, spec.width/2-1
	local by_pos, structures, sockets = {}, {}, {}
	local function key(x,y,z) return (z-lo)*(spec.height+1)*spec.width+y*spec.width+x-lo end
	local function put(x,y,z,name,param2)
		assert(x>=lo and x<=hi and z>=lo and z<=hi and y>=0 and y<=spec.height,
			"Round 20 "..spec.key..": cell outside authored core")
		by_pos[key(x,y,z)]={x=x,y=y,z=z,name=name,param2=param2 or 0}
	end
	local function fill(x1,y1,z1,x2,y2,z2,name,param2)
		for z=z1,z2 do for y=y1,y2 do for x=x1,x2 do put(x,y,z,name,param2) end end end
	end
	fill(lo,0,lo,hi,0,hi,p.ground)
	fill(lo,1,lo,hi,spec.height,hi,"air")
	-- Open cross-court links the fixed root and all perimeter approaches.
	-- Buildings replace their own floor, so this is not a four-house street grid.
	fill(-1,0,lo,1,0,hi,p.stone)
	fill(lo,0,-1,hi,0,1,p.stone)
	local footprints={}
	local function house(b,index)
		local cx,cz,w,d,h,turn,form=unpack(b)
		local raised=spec.race=="troll" and 1 or 0
		local open=form=="canopy" or form=="boat" or form=="forge" or form=="adit"
		footprints[#footprints+1]={x1=cx-w,x2=cx+w,z1=cz-d,z2=cz+d}
		structures[#structures+1]={label=spec.label.." building "..index,
			x=cx,z=cz,w=w,d=d,h=h+raised,kind=form,
			interior={x=cx,y=raised+1,z=cz},entry_turn=turn}
		fill(cx-w,0,cz-d,cx+w,0,cz+d,p.stone)
		if raised>0 then fill(cx-w,raised,cz-d,cx+w,raised,cz+d,p.wood) end
		for y=raised+1,raised+h do
			if not open or form=="adit" then
				for x=cx-w,cx+w do put(x,y,cz-d,y==raised+1 and p.stone or p.wood); put(x,y,cz+d,y==raised+1 and p.stone or p.wood) end
				for z=cz-d,cz+d do put(cx-w,y,z,y==raised+1 and p.stone or p.wood); put(cx+w,y,z,y==raised+1 and p.stone or p.wood) end
			end
			for _,x in ipairs({cx-w,cx+w}) do for _,z in ipairs({cz-d,cz+d}) do put(x,y,z,p.post) end end
		end
		-- Roofs have continuous perimeter bearings; flatter service sheds and
		-- higher gables vary both silhouette and usable floor area.
		for x=cx-w,cx+w do put(x,raised+h,cz-d,p.post);put(x,raised+h,cz+d,p.post) end
		for z=cz-d,cz+d do put(cx-w,raised+h,z,p.post);put(cx+w,raised+h,z,p.post) end
		local along_x=w<=d
		for z=-d,d do for x=-w,w do
			local distance=along_x and math.abs(x) or math.abs(z)
			local radius=along_x and w or d
			local rise=math.floor((radius-distance)/2)
			if form=="flat" then rise=0
			elseif form=="shed" then rise=math.floor((along_x and (x+w) or (z+d))/4) end
			local roof_y=raised+h+1+rise
			put(cx+x,roof_y,cz+z,form=="flat" and p.slab or p.roof)
			if math.abs(x)==w or math.abs(z)==d then
				for y=raised+h+1,roof_y-1 do put(cx+x,y,cz+z,p.wood) end
			end
		end end
		local ex,ez=cx,cz-d
		if turn==1 then ex,ez=cx+w,cz
		elseif turn==2 then ex,ez=cx,cz+d
		elseif turn==3 then ex,ez=cx-w,cz end
		local dx,dz=(turn==0 or turn==2) and 1 or 0,(turn==1 or turn==3) and 1 or 0
		for step=0,1 do
			for y=raised+1,raised+3 do put(ex+dx*step,y,ez+dz*step,"air") end
			if raised>0 then put(ex+dx*step,1,ez+dz*step,"stairs:stair_junglewood",(4-turn)%4) end
		end
		structures[#structures].entry={x=ex,y=raised+1,z=ez}
		-- Small rooms keep their centre and entry empty. Windows are opposite
		-- the entry; corner furniture never narrows the two-node doorway.
		if not open then
			local wx,wz=cx,cz+d
			if turn==1 then wx,wz=cx-w,cz elseif turn==2 then wx,wz=cx,cz-d elseif turn==3 then wx,wz=cx+w,cz end
			put(wx,raised+2,wz,"default:glass")
		end
		local ax,az,bx,bz=cx-w+1,cz+d-1,cx+w-1,cz+d-1
		if turn==1 then ax,az,bx,bz=cx-w+1,cz-d+1,cx-w+1,cz+d-1
		elseif turn==2 then ax,az,bx,bz=cx-w+1,cz-d+1,cx+w-1,cz-d+1
		elseif turn==3 then ax,az,bx,bz=cx+w-1,cz-d+1,cx+w-1,cz+d-1 end
		put(ax,raised+1,az,"grug_decor:xdecor_barrel")
		put(bx,raised+1,bz,"grug_decor:cottages_bench",2)
		put(bx,raised+2,bz,"grug_decor:xdecor_candle",1)
		if form=="forge" then put(ax,raised+1,az,"grug_decor:cottages_anvil")
		elseif form=="oven" then
			-- A fixed masonry baking alcove, not an uninitialized furnace.
			put(ax,raised+1,az,p.stone);put(ax,raised+2,az,p.slab)
		elseif form=="adit" then
			-- Braced workplace with a rear rock face opposite its entry.
			for y=raised+1,raised+h-1 do
				if turn==0 or turn==2 then
					for x=cx-w+1,cx+w-1 do put(x,y,az,p.stone) end
				else for z=cz-d+1,cz+d-1 do put(ax,y,z,p.stone) end end
			end
			put(ax,raised+h-1,az,"grug_decor:xdecor_lantern")
		elseif form=="boat" then
			-- Fixed display hull, no vehicle/entity. Its west work aisle stays open.
			for z=cz-d+1,cz+d-1 do put(cx,raised+1,z,p.slab);put(cx+1,raised+1,z,p.post) end
			structures[#structures].interior.x=cx-2
		end
	end
	for index,b in ipairs(spec.buildings) do house(b,index) end
	local function prop(q)
		local kind,x,z=q[1],q[2],q[3]
		local function at(dx,y,dz,name,param2) put(x+dx,y,z+dz,name,param2) end
		local function column(dx,dz,h,name) for y=1,h do at(dx,y,dz,name) end end
		if kind=="wall" or kind=="ruin" or kind=="hedge" or kind=="fence" then
			local material=kind=="hedge" and "default:leaves" or kind=="fence" and "default:fence_wood" or p.stone
			for dx=-1,1 do column(dx,0,kind=="fence" and 1 or (dx==-1 and 3 or 1),material) end
			if kind=="ruin" then column(-1,1,2,p.stone) end
		elseif kind=="arch" then
			column(-1,0,4,p.stone);column(1,0,3,p.stone)
			at(0,4,0,p.slab);at(1,4,0,p.slab)
		elseif kind=="pier" or kind=="rock_tooth" or kind=="menhir" then
			column(0,0,kind=="rock_tooth" and 5 or 3,p.stone)
			column(1,0,kind=="rock_tooth" and 3 or 1,p.stone)
			at(0,1,1,p.stone)
		elseif kind=="cairn" or kind=="scree" or kind=="bones" then
			for _,v in ipairs({{-1,0},{0,0},{1,0},{0,1}}) do at(v[1],1,v[2],kind=="bones" and "grug_nodes:bone_pile" or p.slab) end
			if kind=="cairn" then at(0,2,0,p.stone) end
		elseif kind=="stump" or kind=="fallen_tree" or kind=="timber" then
			for dx=-1,1 do at(dx,1,0,p.post,12) end
			if kind=="stump" then column(0,0,3,p.post);at(1,2,0,p.post)
			elseif kind=="fallen_tree" then at(-1,2,0,p.post,12);at(1,1,1,p.post,12) end
		elseif kind=="cart" or kind=="wheel" then
			for dx=-1,1 do at(dx,1,0,p.post,12) end
			at(-1,1,-1,p.slab);at(1,1,1,p.slab)
			if kind=="cart" then
				for dx=-1,1 do at(dx,2,0,p.slab);at(dx,2,1,p.slab) end
				at(0,1,-1,p.post,12)
			end
		elseif kind=="ramp" or kind=="platform" then
			for dx=-1,1 do at(dx,1,0,p.post);at(dx,2,0,p.slab);at(dx,1,1,p.slab) end
			if kind=="platform" then column(-1,0,4,p.post);at(-1,4,1,p.slab) end
		elseif kind=="rack" or kind=="trellis" or kind=="pipes" or kind=="chime" or kind=="hook" then
			column(-1,0,3,p.post);column(1,0,3,p.post)
			at(0,3,0,p.post,12)
			if kind=="trellis" then at(0,1,0,"default:leaves");at(0,2,0,"default:leaves")
			elseif kind=="chime" or kind=="pipes" then at(0,2,0,"default:fence_wood")
			elseif kind=="rack" then at(0,1,0,"grug_decor:cottages_straw_mat") end
		elseif kind=="banner" or kind=="fallen_banner" or kind=="brand" then
			local cloth="grug_mapgen:poi_display_"..spec.race
			if kind=="banner" then column(0,0,3,p.post);at(1,3,0,cloth)
			elseif kind=="fallen_banner" then at(0,1,0,p.post,12);at(1,1,0,cloth)
			else at(0,1,0,cloth) end
		elseif kind=="table" or kind=="press" or kind=="altar" then
			column(-1,0,1,p.post);column(1,0,1,p.post)
			for dx=-1,1 do at(dx,2,0,p.slab) end
			if kind=="press" then column(-1,0,4,p.post);column(1,0,4,p.post);at(0,4,0,p.post)
			elseif kind=="altar" then at(0,3,0,"grug_decor:xdecor_candle",1) end
		elseif kind=="shelf" or kind=="board" or kind=="samples" then
			column(-1,0,3,p.post);column(1,0,3,p.post)
			at(0,1,0,p.slab);at(0,3,0,p.slab)
			at(0,2,0,kind=="board" and "grug_mapgen:poi_display_"..spec.race or p.stone)
			if kind=="samples" then
				-- Six fixed sample squares. They are ordinary masonry, never
				-- collectible gems or replacements for the twelve resource roots.
				for dx=-1,1 do for y=1,2 do at(dx,y,1,"grug_mapgen:poi_display_"..spec.race) end end
			end
		elseif kind=="trough" or kind=="hoard" then
			for dx=-1,1 do at(dx,1,0,p.slab) end
			at(-1,1,1,p.stone);at(1,1,1,p.stone)
		elseif kind=="coil" or kind=="crescent" or kind=="marks" then
			for _,v in ipairs({{-1,0},{0,1},{1,0}}) do at(v[1],0,v[2],p.stone) end
		elseif kind=="web" then
			column(0,0,2,"default:fence_wood");at(1,2,0,"default:fence_wood")
		elseif kind=="cocoon" then column(0,0,2,"default:silver_sandstone")
		elseif kind=="feathers" or kind=="grass" then
			at(0,1,0,"default:dry_shrub",4);at(1,1,0,"default:dry_shrub",4)
		elseif kind=="flower" then
			at(0,1,0,"grug_decor:xdecor_potted_viola");at(1,1,0,"grug_decor:xdecor_potted_dandelion_yellow")
		elseif kind=="slab" then
			for dz=-1,1 do at(0,1,dz,p.slab) end
		elseif kind=="grave" then column(0,0,2,p.stone);at(0,1,1,p.slab)
		elseif kind=="totem" then column(0,0,3,p.post);at(0,3,0,"grug_mapgen:poi_display_"..spec.race)
		elseif kind=="rail" or kind=="oar" or kind=="tools" then
			for dz=-1,1 do at(0,1,dz,p.post,4) end
			if kind=="rail" then for dz=-1,1 do at(1,1,dz,p.post,4) end end
		elseif kind=="crates" or kind=="crate" or kind=="jars" or kind=="baskets" then
			at(0,1,0,"grug_decor:xdecor_barrel")
			if kind~="crate" then at(1,1,0,"grug_decor:xdecor_barrel") end
		elseif kind=="bench" then at(0,1,0,"grug_decor:cottages_bench",2);at(1,1,0,"grug_decor:cottages_bench",2)
		elseif kind=="candle" then at(0,1,0,p.stone);at(0,2,0,"grug_decor:xdecor_candle",1)
		elseif kind=="lantern" then column(0,0,2,p.post);at(0,3,0,"grug_decor:xdecor_lantern")
		elseif kind=="bowl" then at(0,1,0,"grug_decor:xdecor_cauldron")
		elseif kind=="shield" or kind=="coins" or kind=="shutter" then at(0,1,0,"grug_mapgen:poi_display_"..spec.race)
		elseif kind=="drum" then at(0,1,0,"grug_decor:xdecor_barrel");at(0,2,0,p.slab)
		elseif kind=="bollard" then column(0,0,2,p.post)
		else error("Round 20 unknown scenery: "..tostring(kind)) end
	end
	for _,q in ipairs(spec.props) do prop(q) end
	-- Actor roots and the host approach are invariant across all authored art.
	-- No duplicate camp fire, banner, dragon, rare or resource is authored here.
	for z=-2,2 do for x=-2,2 do for y=1,3 do
		assert(by_pos[key(x,y,z)].name=="air",spec.key..": central actor clearance blocked")
	end end end
	if spec.host then
		sockets[1]={id="quest_host",role="quest",x=2,y=1,z=0,dir={x=-1,z=0}}
	end
	local cells,names={},{}
	for _,cell in pairs(by_pos) do cells[#cells+1]=cell;names[cell.name]=true end
	table.sort(cells,function(a,b) return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x))) end)
	local palette={};for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette,function(a,b)
		for i=1,math.min(#a,#b) do local x,y=a:byte(i),b:byte(i);if x~=y then return x<y end end
		return #a<#b
	end)
	return {schema=profile.blueprint_schema,palette=palette,cells=cells,
		bounds={min={x=lo,y=0,z=lo},max={x=hi,y=spec.height,z=hi}},clear_to=spec.height,
		landmarks={structures=structures,sockets=sockets,arrival={x=0,y=1,z=0}}}
end
