-- One real seed/height constructor, bounded column samples, no VM population.
local repo = assert(arg[1])
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local deps = {source = dofile(directory .. "/source/simple_map.lua"),
	schemas = dofile(directory .. "/schemas.lua"),
	canonical = dofile(directory .. "/canonical.lua"),
	deterministic = dofile(directory .. "/deterministic.lua"),
	raw_sha256 = common.new_sha256(),
	coupled_grade = dofile(directory .. "/coupled_grade.lua")()}
local seed = "7354267267733045968"
local start = os.clock()
deps.horizontal_session = dofile(directory .. "/simple_map.lua")(deps).new(seed)
local horizontal = deps.horizontal_session
io.write("horizontal_seconds\t", os.clock()-start, "\n")
local height = dofile(directory .. "/height.lua")(deps).new_runtime(seed)
io.write("height_seconds\t", os.clock()-start, "\n")
for _, reach in ipairs(deps.source.hydrology) do
	local changed, wet, shallow, deep = 0, 0, 100, -100
	if reach.id == "hydro_frostbarrow_tarns" or reach.id == "hydro_moonfall_lake" or
			reach.id == "hydro_lethariel_lake" or reach.id == "hydro_raincall_headwater" then
		for _, point in ipairs(reach.centreline) do
			for dx = -point.half_width-8, point.half_width+8, 4 do
				local x,z = point.x+dx,point.z
				local offset = horizontal.hydrology_edge_at(reach.id,x,z)
				if offset ~= 0 then changed=changed+1 end
				local class,_,_,_,id = horizontal.classification_values_at(x,z)
				local level=height.water_surface_at(x,z)
				local ground=height.terrain_height_at(x,z)
				if id == reach.id and level and level>ground then
					local depth=level-ground
					wet=wet+1; shallow=math.min(shallow,depth);deep=math.max(deep,depth)
				end
			end
		end
		if reach.civic_core_zone_numeric_id or reach.id == "hydro_raincall_headwater" then
			assert(changed==0,"functional lake outline changed")
		else assert(changed>0 and shallow==1,"natural lake variation missing") end
		io.write("lake\t",reach.id,"\t",changed,"\t",wet,"\t",shallow,"\t",deep,"\n")
	end
end
for _, point in ipairs({{-1680,-2932},{-1680,-2944},{-1680,-2920},
	{-1800,-2350},{-1650,-2200},{-1500,-1850},{-3150,0}}) do
	local x,z=point[1],point[2]
	local profile,distance,width,fresh,key,target,relief,water=height.coast_profile_at(x,z)
	io.write("point\t",x,"\t",z,"\t",height.terrain_height_at(x,z),"\t",
		tostring(profile),"\t",tostring(distance),"\t",tostring(target),"\t",tostring(water),"\n")
end
local _,_,material=dofile(directory.."/r6_content.lua")
local sand,rock=0,0
for z=-2952,-2872,8 do
	for x=-1720,-1640,8 do
		local ground=height.terrain_height_at(x,z)
		local profile,distance,width,fresh,key,target,relief,water=height.coast_profile_at(x,z)
		if profile then
			local sandy=material.low_sand_surface(ground,water,distance,fresh)
			if sandy then sand=sand+1 else rock=rock+1 end
			io.write("coast\t",x,"\t",z,"\t",ground,"\t",profile,"\t",distance,
				"\t",target,"\t",water,"\t",sandy and "low" or "high","\n")
		end
	end
end
assert(sand>0 and rock>0,"reported coast sample must exercise low and high sand eligibility")
io.write("coast_eligibility\t",sand,"\t",rock,"\n")
io.write("total_cpu_seconds\t",os.clock()-start,"\n")
