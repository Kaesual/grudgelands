-- Real-code R7.6 KAT for three axial surface bands and the existing depth term.

return function(repo)
	assert(type(repo) == "string" and repo:sub(1,1) == "/",
		"absolute repository root required")

	local common=dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40=repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source=dofile(wp40 .. "/source/simple_map.lua")
	local schemas=dofile(wp40 .. "/schemas.lua")
	local canonical=dofile(wp40 .. "/canonical.lua")
	local deterministic=dofile(wp40 .. "/deterministic.lua")
	local raw_sha256=common.new_sha256()
	local horizontal_factory=dofile(wp40 .. "/simple_map.lua")
	local horizontal=horizontal_factory({
		source=source,
		schemas=schemas,
		canonical=canonical,
		deterministic=deterministic,
		raw_sha256=raw_sha256,
	}).new("0")
	local zones_module=dofile(wp40 .. "/zones.lua")({
		source=source,
		schemas=schemas,
		canonical=canonical,
		deterministic=deterministic,
		index128=dofile(wp40 .. "/index128.lua"),
		horizontal_factory=horizontal_factory,
		height_factory=dofile(wp40 .. "/height.lua"),
		coupled_grade=dofile(wp40 .. "/coupled_grade.lua")(),
		raw_sha256=raw_sha256,
	})
	local session=zones_module.new_runtime("0",1)

	local function check(ok,message)
		if not ok then error("R7 level-band KAT: " .. message,0) end
	end

	local function ranges_for(row)
		local count=row.level_max-row.level_min+1
		if count == 1 then
			return {{row.level_min,row.level_max},{row.level_min,row.level_max},
				{row.level_min,row.level_max}}
		end
		local cut1=math.floor(count/3)
		local cut2=math.floor(count*2/3)
		return {
			{row.level_min,row.level_min+cut1-1},
			{row.level_min+cut1,row.level_min+cut2-1},
			{row.level_min+cut2,row.level_max},
		}
	end

	local faction_by_race={}
	for index=1,#source.zones do
		local row=source.zones[index]
		if row.faction then faction_by_race[row.race_region]=row.faction end
	end
	local profiles={}
	for index=1,#source.zones do
		local row=source.zones[index]
		local direction,outer_z,inner_z
		if row.macro_region == "wyrmglass_island" or
				row.macro_region == "stormscale_island" then
			direction,outer_z,inner_z=0,row.hub.z,row.hub.z
		elseif row.macro_region == "holy_grounds" then
			local faction=faction_by_race[row.race_region]
			check(faction == "accord" or faction == "throng",
				"front faction missing for " .. row.id)
			direction=faction == "accord" and 1 or -1
			outer_z=faction == "accord" and source.holy_grounds.min_z or
				source.holy_grounds.max_z
			inner_z=0
		else
			direction=row.macro_region == "elandor_mainland" and 1 or -1
			outer_z=row.hub.z
			local nearest
			for candidate_index=1,#source.zones do
				local candidate=source.zones[candidate_index]
				if candidate.macro_region == row.macro_region then
					local distance=direction*(candidate.hub.z-row.hub.z)
					if distance > 0 and (not nearest or distance < nearest) then
						nearest=distance
					end
				end
			end
			if nearest then inner_z=outer_z+direction*nearest
			elseif direction == 1 then inner_z=source.holy_grounds.min_z
			else inner_z=source.holy_grounds.max_z end
		end
		profiles[index]={direction=direction,outer_z=outer_z,inner_z=inner_z,
			extent=direction == 0 and 0 or direction*(inner_z-outer_z),
			ranges=ranges_for(row)}
	end

	local rows={"schema\tgrug_r7_level_bands_kat_v1\n"}
	local zone_samples=0
	for index=1,#source.zones do
		local row=source.zones[index]
		local profile=profiles[index]
		local samples={}
		if profile.extent == 0 then
			for band=1,3 do
				local level=horizontal.difficulty_for_macro_at(row.hub.x,row.hub.z,
					row.macro_region)
				check(level == 60,row.id .. " summit is not flat 60")
				samples[band]=level
			end
		else
			local progress_samples={math.floor(profile.extent/6),
				math.floor(profile.extent/2),math.floor(profile.extent*5/6)}
			for band=1,3 do
				local z=profile.outer_z+profile.direction*progress_samples[band]
				local level=horizontal.difficulty_for_macro_at(row.hub.x,z,
					row.macro_region)
				local range=profile.ranges[band]
				check(level and level >= range[1] and level <= range[2],
					row.id .. " band " .. band .. " sample escaped its sub-range")
				samples[band]=level
			end
			local previous
			for progress=1,profile.extent do
				local z=profile.outer_z+profile.direction*progress
				local level=horizontal.difficulty_for_macro_at(row.hub.x,z,
					row.macro_region)
				local scaled=progress*3
				local band=scaled < profile.extent and 1 or
					(scaled < profile.extent*2 and 2 or 3)
				local range=profile.ranges[band]
				check(level >= range[1] and level <= range[2],
					row.id .. " staircase escaped band " .. band ..
					" at progress " .. progress)
				check(not previous or level >= previous,
					row.id .. " staircase decreased at progress " .. progress)
				previous=level
			end
		end
		zone_samples=zone_samples+3
		rows[#rows+1]=table.concat({"zone",row.numeric_id,row.id,
			profile.outer_z,row.hub.z,profile.inner_z,samples[1],samples[2],
			samples[3]},"\t") .. "\n"
	end
	check(#source.zones == 38 and zone_samples == 114,
		"zone sample population differs")

	local starts={}
	for index=1,#source.zones do
		local row=source.zones[index]
		if row.level_min == 1 then starts[#starts+1]=row end
	end
	check(#starts == 6,"start-zone population differs")
	local cardinal={{1,0},{-1,0},{0,1},{0,-1}}
	for index=1,#starts do
		local row=starts[index]
		local profile=profiles[row.numeric_id]
		local anchor=session.anchor(row.id,"start")
		check(anchor and anchor.x == row.hub.x and anchor.z == row.hub.z,
			row.id .. " start anchor moved from its hub")
		local front_sign=profile.direction
		local authored=horizontal.difficulty_for_macro_at(anchor.x,anchor.z,
			row.macro_region)
		check(authored >= profile.ranges[1][1] and
			authored <= profile.ranges[1][2],row.id .. " start is outside band 1")
		for direction_index=1,#cardinal do
			local direction=cardinal[direction_index]
			for _,radius in ipairs({0,100,101,150}) do
				local expected=radius <= 100 and 1 or 2
				local actual=session.surface_mob_level_at(
					anchor.x+direction[1]*radius,anchor.z+direction[2]*radius)
				check(actual == expected,row.id .. " safety radius " .. radius ..
					" differs")
			end
		end
		local levels={}
		for sample_index,distance in ipairs({0,101,151,300,500,800}) do
			levels[sample_index]=session.surface_mob_level_at(anchor.x,
				anchor.z+front_sign*distance)
		end
		check(levels[1] == 1 and levels[2] == 2,
			row.id .. " safety samples differ")
		check(levels[3] >= 1 and levels[3] <= 3,
			row.id .. " 151 m sample escaped 1-3")
		check(levels[4] >= 4 and levels[4] <= 6,
			row.id .. " 300 m sample escaped 4-6")
		check(levels[5] <= 10,row.id .. " 500 m sample exceeds 10")
		rows[#rows+1]=table.concat({"start",row.race_region,anchor.x,anchor.z,
			levels[1],levels[2],levels[3],levels[4],levels[5],levels[6]},"\t") ..
			"\n"
	end

	local function expected_depth(y)
		local numerator=-3*y
		local base=math.floor(numerator/50)
		local value=numerator-base*50 >= 25 and base+1 or base
		if value < 1 then return 1 end
		if value > 60 then return 60 end
		return value
	end
	local depth_anchor=session.anchor(starts[1].id,"start")
	for depth=1,1000 do
		local y=-depth
		check(session.mob_level_at({x=depth_anchor.x,y=y,z=depth_anchor.z}) ==
			expected_depth(y),"depth term differs at y=" .. y)
	end
	for outer_depth=50,950,50 do
		local transitions=0
		local previous=expected_depth(-outer_depth)
		for depth=outer_depth+1,outer_depth+50 do
			local level=expected_depth(-depth)
			if level ~= previous then transitions=transitions+1 end
			previous=level
		end
		check(transitions == 3,"depth window at " .. outer_depth ..
			" does not contain three integer steps")
	end
	rows[#rows+1]="depth\tformula=min(60,max(1,round_half_away(-3y/50)))\t" ..
		"uncapped_50_node_steps=3\n"
	rows[#rows+1]="difficulty_field_sha256\t" ..
		horizontal.difficulty_lattice_digest() .. "\n"
	local body=table.concat(rows)
	return body .. "output_sha256\t" .. common.hex(raw_sha256(body)) .. "\n"
end
