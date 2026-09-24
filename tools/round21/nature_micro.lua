-- Portable final-byte checks of the exact production arithmetic; no world build.
return function(repo)
	local root = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local _, lake_factory = dofile(root .. "/simple_map.lua")
	local _, _, nature = dofile(root .. "/height.lua")
	local _, _, material = dofile(root .. "/r6_content.lua")
	local function round(n,d)
		if n < 0 then return -math.floor(-n/d+0.5) end
		return math.floor(n/d+0.5)
	end
	local rows = {"round21-nature-v1"}
	local lattice = {}
	for z=-2,2 do
		lattice[z]={}
		for x=-2,2 do lattice[z][x]=x<0 and 0 or 160 end
	end
	local smooth = nature.smooth_lattice(lattice,-2,2,-2,2,round)
	assert(smooth[0][-2]==0 and smooth[0][-1]==40 and smooth[0][0]==120 and smooth[0][1]==160)
	assert(lattice[0][-1]==0 and lattice[0][0]==160,"smoothing mutated its inputs")
	rows[#rows+1]="broad\t0\t40\t120\t160"
	local lake=lake_factory("7354267267733045968")
	local minimum,maximum=8,-8
	for z=-96,96,8 do
		for x=-96,96,8 do
			local value=lake.offset(x,z,209458)
			assert(value>=-8 and value<=8 and value%1==0)
			assert(math.abs(value-lake.offset(x+1,z,209458))<=1)
			assert(math.abs(value-lake.offset(x,z+1,209458))<=1)
			minimum,maximum=math.min(minimum,value),math.max(maximum,value)
			rows[#rows+1]=table.concat({"edge",x,z,value},"\t")
		end
	end
	assert(minimum<0 and maximum>0,"lake edge lost inward/outward variation")
	for _,depth in ipairs({1,2,3,5,8,11,15}) do
		local previous=0
		for inside=0,20 do
			local value=nature.bowl_depth(depth,inside,16,round)
			assert(value>=previous and value>=1 and value<=depth)
			assert(nature.bowl_depth(depth,inside,0,round)==depth,"reserved depth changed")
			previous=value
		end
		assert(nature.bowl_depth(depth,0,16,round)==1)
		assert(nature.bowl_depth(depth,16,16,round)==depth)
	end
	for _,pair in ipairs({{2,90},{90,2},{-20,40}}) do
		local left=nature.lateral_blend(pair[1],pair[2],47,round)
		local right=nature.lateral_blend(pair[2],pair[1],0,round)
		assert(math.abs(left-right)<=3,"coast run boundary swaps full targets")
		rows[#rows+1]=table.concat({"coast",left,right},"\t")
	end
	assert(material.low_sand_surface(7,1,20,false))
	assert(not material.low_sand_surface(24,1,20,false))
	assert(not material.low_sand_surface(6,1,2,false))
	assert(material.low_sand_surface(66,65,2,true),"raised freshwater uses its own level")
	assert(not material.low_sand_surface(70,65,10,true))
	rows[#rows+1]="material\tlow-beach\thigh-rock\tfreshwater-level"
	return table.concat(rows,"\n").."\n"
end
