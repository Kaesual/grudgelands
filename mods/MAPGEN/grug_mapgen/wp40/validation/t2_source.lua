-- Stage-1 validation for the ordered WP40 authored source catalog.

local validator = {}
local EXPECTED_SOURCE_CHECKSUM =
	"50258d6d9cec7f67de77c61b7e672ed23de623580518297703003ba2ba8bee15"

local SOURCE_ARRAY_FIELDS={section_order=true,relief_profiles=true,
	mg_flags=true,mgv7_special_flags=true,flags=true,
	route_classes=true,water_classes=true,landmark_role_vocabulary=true,
	template_primitives=true,zones=true,land_edges=true,route_stations=true,
	routes=true,route_interfaces=true,route_crossing_interfaces=true,
	boat_edges=true,island_landings=true,island_route_stations=true,
	island_routes=true,island_route_interfaces=true,perimeters=true,bays=true,
	islands=true,channels=true,landmarks=true,anchors=true,templates=true,
	template_compositions=true,hydrology=true,hydrology_interfaces=true,
	housing_masks=true,coastal_housing_cores=true,octaves=true,biomes=true,
	control=true,polygon=true,centreline=true,roles=true,candidates=true,
	patrol_route=true,socket_resource_keys=true,operations=true,
	parameters=false,from_ids=true,approach_edge_ids=true,race_regions=true,
	regional_resource_keys=true,cultural_material_keys=true,
	signature_wood_keys=true,race_region_assignments=true,
	holy_junction_x=true,dragon_approach_z=true}

local function source_table_shape(value)
	local count=#value
	if count==0 then return false,0 end
	for key in pairs(value) do
		if type(key)~="number" or key%1~=0 or key<1 or key>count then
			return false,count
		end
	end
	return true,count
end

local function canonicalize_source_node(value,field_name,canonical)
	local kind=type(value)
	if kind=="string" then return canonical.text(value) end
	if kind=="number" then return canonical.signed(value) end
	if kind=="boolean" then return canonical.boolean(value) end
	if kind~="table" then error("unsupported source kind "..kind,0) end
	local array,count=source_table_shape(value)
	if count==0 then array=SOURCE_ARRAY_FIELDS[field_name]==true end
	if array then
		local children={}
		for i=1,count do children[i]=canonicalize_source_node(value[i],nil,canonical) end
		return canonical.array(children)
	end
	local keys={}
	for key in pairs(value) do
		if type(key)~="string" then error("source map key is not text",0) end
		keys[#keys+1]=key
	end
	table.sort(keys)
	local rows={}
	for i=1,#keys do local key=keys[i]
		rows[i]={canonical.text(key),canonicalize_source_node(value[key],key,canonical)}
	end
	return canonical.map(rows)
end

local function canonicalize_source(source,canonical)
	if type(canonical)~="table" then error("T1 canonical module missing",0) end
	return canonicalize_source_node(source,nil,canonical)
end

function validator.canonicalize_source(source,canonical)
	return canonicalize_source(source,canonical)
end

-- Production trust closes at module load. The engine-owned core and the
-- reviewed T1 module at this mod's fixed path are captured once; validate has
-- no dependency, projector, or expected-digest arguments a caller can forge.
local production_canonical
local production_raw_sha256
local engine_core=rawget(_G,"core")
if engine_core~=nil then
	if type(engine_core.get_modpath)~="function" or
			type(engine_core.sha256)~="function" then
		error("WP40 production Stage1 trust APIs unavailable",0)
	end
	local production_modpath=engine_core.get_modpath("grug_mapgen")
	if type(production_modpath)~="string" or production_modpath=="" then
		error("WP40 production Stage1 mod path unavailable",0)
	end
	production_canonical=dofile(production_modpath.."/wp40/canonical.lua")
	local engine_sha256=engine_core.sha256
	production_raw_sha256=function(data)
		return engine_sha256(data,true)
	end
end

local function diag(invariant, record_id, expected, observed)
	return nil, {
		stage = "stage1",
		schema = "grug_wp40_authored_source_v1",
		record_id = record_id,
		invariant = invariant,
		expected = expected,
		observed = observed,
	}
end

local function dense(values)
	if type(values) ~= "table" then return false end
	local count = #values
	for key in pairs(values) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			return false
		end
	end
	for i = 1, count do
		if values[i] == nil then return false end
	end
	return true
end

local function source_graph(value, path, seen)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge or
				value % 1 ~= 0 or value < -9007199254740991 or
				value > 9007199254740991 then
			return diag("integer_graph", path, "safe integer", value)
		end
		return true
	elseif kind == "function" or kind == "thread" or kind == "userdata" then
		return diag("source_graph_value_type",path,"data only",kind)
	elseif kind ~= "table" then
		return true
	end
	if getmetatable(value) ~= nil then
		return diag("source_graph_metatable",path,"no metatable","present")
	end
	seen = seen or {}
	if seen[value] then return diag("acyclic_graph", path, "acyclic", "cycle") end
	seen[value] = true
	local key_kind=nil
	local numeric_count=0
	local string_keys={}
	local key_issues={}
	local key_type_rank={boolean="1",["function"]="2",table="3",thread="4",userdata="5"}
	for key in pairs(value) do
		local current=type(key)
		if current~="number" and current~="string" then
			local detail=current
			if current=="boolean" then detail=current..":"..(key and "true" or "false") end
			key_issues[#key_issues+1]={rank=key_type_rank[current] or "9",detail=detail}
		elseif current=="number" then
			if key~=key or key==math.huge or key==-math.huge or key%1~=0 or key<1 then
				local detail=key~=key and "nan" or (key==math.huge and "positive_infinity" or (key==-math.huge and "negative_infinity" or tostring(key)))
				key_issues[#key_issues+1]={rank="0",detail=detail,array=true}
			else
				numeric_count=numeric_count+1
			end
		else
			string_keys[#string_keys+1]=key
		end
		if current=="number" or current=="string" then
			if key_kind and key_kind~=current then key_kind="mixed" else key_kind=key_kind or current end
		end
	end
	if #key_issues>0 then
		table.sort(key_issues,function(a,b) if a.rank~=b.rank then return a.rank<b.rank end return a.detail<b.detail end)
		seen[value]=nil
		local issue=key_issues[1]
		if issue.array then return diag("source_graph_array_key",path,"positive integer",issue.detail) end
		return diag("source_graph_key_type",path,"dense numeric array or string map",issue.detail)
	end
	if key_kind=="mixed" then seen[value]=nil return diag("source_graph_mixed_keys",path,"one key kind","mixed") end
	if key_kind=="number" and #value~=numeric_count then
		seen[value]=nil
		return diag("source_graph_dense_array",path,"dense 1..n","sparse")
	end
	if value.numerator ~= nil or value.denominator ~= nil then
		if type(value.numerator) ~= "number" or value.numerator % 1 ~= 0 or
				type(value.denominator) ~= "number" or
				value.denominator % 1 ~= 0 or value.denominator <= 0 then
			seen[value] = nil
			return diag("rational_record", path, "integer numerator/positive denominator", "invalid")
		end
		if #string_keys~=2 or value.numerator==nil or value.denominator==nil then
			seen[value]=nil
			return diag("rational_record",path,"exact numerator/denominator map","extra or missing field")
		end
	end
	if key_kind=="number" then
		for i=1,numeric_count do
			if value[i]==nil then seen[value]=nil return diag("source_graph_dense_array",path,"dense 1..n","hole at "..i) end
			local ok,failure=source_graph(value[i],path.."["..i.."]",seen)
			if not ok then seen[value]=nil return nil,failure end
		end
	else
		table.sort(string_keys)
		for i=1,#string_keys do local key=string_keys[i]
			if key=="force_native_dungeon" and value[key]==true then
				seen[value]=nil
				return diag("native_dungeon_force_forbidden",path.."."..key,
					"false or absent",true)
			end
			local ok,failure=source_graph(value[key],path.."."..key,seen)
			if not ok then seen[value]=nil return nil,failure end
		end
	end
	seen[value] = nil
	return true
end

local function unique_ordered(records, kind)
	if not dense(records) then return diag("dense_array", kind, true, false) end
	local ids = {}
	local numeric = {}
	for i = 1, #records do
		local row = records[i]
		if type(row) ~= "table" or type(row.id) ~= "string" or row.id == "" then
			return diag("required_id", kind .. "[" .. i .. "]", "non-empty string", row and row.id)
		end
		if ids[row.id] then return diag("unique_string_id", row.id, true, false) end
		ids[row.id] = true
		if row.numeric_id ~= i then
			return diag("canonical_numeric_order", row.id, i, row.numeric_id)
		end
		if numeric[row.numeric_id] then
			return diag("unique_numeric_id", row.id, true, false)
		end
		numeric[row.numeric_id] = true
	end
	return true, ids
end

local function orientation(points)
	local twice = 0
	for i = 1, #points - 1 do
		twice = twice + points[i].x * points[i + 1].z -
			points[i + 1].x * points[i].z
	end
	if twice > 0 then return "counterclockwise" end
	if twice < 0 then return "clockwise" end
	return "degenerate"
end

local function cross(a, b, c)
	return (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
end

local function between(a, b, c)
	return c.x >= math.min(a.x,b.x) and c.x <= math.max(a.x,b.x) and
		c.z >= math.min(a.z,b.z) and c.z <= math.max(a.z,b.z)
end

-- Exact integer incidence. Interior segment distance compares cross^2 with
-- width^2 * length^2; endpoint cases compare squared Euclidean distance.
-- The narrower endpoint width owns the segment, so validation never widens a
-- reach implicitly between authored samples.
local function point_in_reach(point, centreline)
	for i=1,#centreline-1 do
		local a,b=centreline[i],centreline[i+1]
		local dx,dz=b.x-a.x,b.z-a.z
		local px,pz=point.x-a.x,point.z-a.z
		if math.abs(dx)>4096 or math.abs(dz)>4096 or math.abs(px)>4096 or
				math.abs(pz)>4096 or a.half_width>4096 or b.half_width>4096 then
			return false
		end
		local length_squared=dx*dx+dz*dz
		local projection=px*dx+pz*dz
		if projection<=0 then
			if px*px+pz*pz<=a.half_width*a.half_width then return true end
		elseif projection>=length_squared then
			local ex,ez=point.x-b.x,point.z-b.z
			if ex*ex+ez*ez<=b.half_width*b.half_width then return true end
		else
			local area=dx*pz-dz*px
			local width=math.min(a.half_width,b.half_width)
			if area*area<=width*width*length_squared then return true end
		end
	end
	return false
end

local function point_in_landmark(point,row)
	local dx,dz=point.x-row.center.x,point.z-row.center.z
	if math.abs(dx)>8192 or math.abs(dz)>8192 or row.radius_x>4096 or
			row.radius_z>4096 then return false end
	local ax,az=math.abs(dx),math.abs(dz)
	if row.primitive=="rectangle" then
		return ax<=row.radius_x and az<=row.radius_z
	elseif row.primitive=="ellipse" then
		return dx*dx*row.radius_z*row.radius_z+
			dz*dz*row.radius_x*row.radius_x<=
			row.radius_x*row.radius_x*row.radius_z*row.radius_z
	elseif row.primitive=="capsule" then
		if row.radius_x>=row.radius_z then
			local straight=row.radius_x-row.radius_z
			if ax<=straight then return az<=row.radius_z end
			local cap=ax-straight
			return cap*cap+dz*dz<=row.radius_z*row.radius_z
		end
		local straight=row.radius_z-row.radius_x
		if az<=straight then return ax<=row.radius_x end
		local cap=az-straight
		return dx*dx+cap*cap<=row.radius_x*row.radius_x
	end
	return false
end

local function point_in_polygon(point,points)
	local winding=0
	for i=1,#points-1 do
		local a,b=points[i],points[i+1]
		local side=cross(a,b,point)
		if side==0 and between(a,b,point) then return true end
		if a.z<=point.z then
			if b.z>point.z and side>0 then
				winding=winding+1
			end
		elseif b.z<=point.z and side<0 then winding=winding-1 end
	end
	return winding~=0
end

local function intersects(a, b, c, d)
	local ab_c, ab_d = cross(a,b,c), cross(a,b,d)
	local cd_a, cd_b = cross(c,d,a), cross(c,d,b)
	if ab_c == 0 and between(a,b,c) then return true end
	if ab_d == 0 and between(a,b,d) then return true end
	if cd_a == 0 and between(c,d,a) then return true end
	if cd_b == 0 and between(c,d,b) then return true end
	return (ab_c < 0 and ab_d > 0 or ab_c > 0 and ab_d < 0) and
		(cd_a < 0 and cd_b > 0 or cd_a > 0 and cd_b < 0)
end

local function polygon_valid(row, label)
	local points = row.polygon
	if not dense(points) or #points < 4 then
		return diag("polygon_dense_closed", label, "dense closed polygon", "invalid")
	end
	if points[1].x ~= points[#points].x or points[1].z ~= points[#points].z then
		return diag("polygon_closed", label, true, false)
	end
	if row.orientation and orientation(points) ~= row.orientation then
		return diag("polygon_orientation", label, row.orientation, orientation(points))
	end
	local segment_count = #points - 1
	for i = 1, segment_count do
		local a, b = points[i], points[i + 1]
		if a.x == b.x and a.z == b.z then
			return diag("polygon_zero_edge", label, false, true)
		end
		for j = i + 1, segment_count do
			if j ~= i + 1 and not (i == 1 and j == segment_count) then
				if intersects(a,b,points[j],points[j+1]) then
					return diag("polygon_self_intersection", label, false,
						i .. ":" .. j)
				end
			end
		end
	end
	return true
end

local EXPECTED_COUNTS = {
	{"zones",38},{"land_edges",57},{"route_stations",68},{"routes",57},{"route_interfaces",171},
	{"route_crossing_interfaces",7},{"boat_edges",4},{"island_landings",4},
	{"island_route_stations",10},{"island_routes",8},{"island_route_interfaces",16},{"landmarks",70},
	{"anchors",100},{"perimeters",3},{"bays",4},{"islands",2},
	{"channels",2},{"relief_profiles",6},{"route_classes",3},
	{"water_classes",5},{"template_primitives",9},{"templates",17},
	{"template_compositions",18},{"hydrology",22},
	{"hydrology_interfaces",10},{"housing_masks",10},
	{"coastal_housing_cores",4},
}

local SLOT_COUNTS = {
	{"start",6},{"capital",6},{"village",12},{"outpost",24},
	{"bandit",12},{"mine",6},{"mirefolk",4},{"clash",16},
	{"dragon",2},{"apex_mine",2},{"rare",10},
}

local function slot_family(slot)
	if slot == "start" or slot == "capital" or slot == "mine" or
			slot == "mirefolk" or slot == "dragon" or slot == "apex_mine" then
		return slot
	end
	if slot:match("^village_%d+$") then return "village" end
	if slot:match("^outpost_%d+$") then return "outpost" end
	if slot:match("^bandit_%d+$") then return "bandit" end
	if slot:match("^clash_%d+$") then return "clash" end
	if slot:match("^rare_[a-z0-9_]+$") then return "rare" end
	return nil
end

local function semantic_set(vocabulary, name)
	local result = {}
	local values = vocabulary and vocabulary[name]
	if not dense(values) then return nil end
	for i = 1, #values do result[values[i]] = true end
	return result
end

local function point_valid(value,with_width)
	if type(value)~="table" or type(value.x)~="number" or
			type(value.z)~="number" then return false end
	if with_width and (type(value.half_width)~="number" or
			value.half_width<=0) then return false end
	return true
end

local function closed_fields(value,path,fields,invariant)
	if type(value)~="table" then
		return diag(invariant,path,"closed string-key record",type(value))
	end
	local allowed={}
	for i=1,#fields do
		local field=fields[i]
		allowed[field]=true
		if value[field]==nil then
			return diag(invariant,path.."."..field,"present","missing")
		end
	end
	local extras={}
	for field in pairs(value) do
		if type(field)~="string" or not allowed[field] then
			extras[#extras+1]=field
		end
	end
	table.sort(extras)
	if #extras>0 then
		return diag(invariant,path.."."..extras[1],"absent","extra")
	end
	return true
end

local function exact_ordered_strings(value,path,expected,invariant)
	if not dense(value) or #value~=#expected then
		return diag(invariant,path,"exact ordered closed list","changed")
	end
	for i=1,#expected do
		if value[i]~=expected[i] then
			return diag(invariant,path.."["..i.."]",expected[i],value[i])
		end
	end
	return true
end

local function exact_rational(value,numerator,denominator,path)
	if type(value)~="table" or value.numerator~=numerator or
			value.denominator~=denominator then
		return diag("critical_manifest_noise_value",path,
			numerator.."/"..denominator,"changed")
	end
	return true
end

local function diagnostic_atom(value)
	local kind=type(value)
	if kind=="string" or kind=="number" or kind=="boolean" or
			kind=="nil" then return tostring(value) end
	return "type:"..kind
end

local function validate_critical_manifest(manifest)
	local path="critical_source_manifest"
	local ok,failure=closed_fields(manifest,path,{"id","schema","mg_name",
		"water_level","chunksize","num_emerge_threads","mg_flags",
		"mgv7_special_flags","mgv7_dungeon_ymin","mgv7_dungeon_ymax",
		"mgv7_np_dungeons","broad_content_y_min","force_native_dungeon"},
		"critical_manifest_fields")
	if not ok then return nil,failure end
	local scalar_values={
		{"id","critical_source_manifest"},
		{"schema","grug_wp40_critical_source_manifest_v1"},
		{"mg_name","v7"},{"water_level",1},{"chunksize",5},
		{"num_emerge_threads",1},{"mgv7_dungeon_ymin",-31000},
		{"mgv7_dungeon_ymax",-193},{"broad_content_y_min",-37},
		{"force_native_dungeon",false},
	}
	for i=1,#scalar_values do
		local field,expected=scalar_values[i][1],scalar_values[i][2]
		if manifest[field]~=expected then
			return diag("critical_manifest_value",path.."."..field,
				expected,manifest[field])
		end
	end
	ok,failure=exact_ordered_strings(manifest.mg_flags,path..".mg_flags",
		{"dungeons","biomes","caves","ores","decorations","light"},
		"critical_manifest_mg_flags")
	if not ok then return nil,failure end
	local expected_special={{"mountains",true},{"ridges",true},
		{"floatlands",false},{"caverns",true}}
	if not dense(manifest.mgv7_special_flags) or
			#manifest.mgv7_special_flags~=#expected_special then
		return diag("critical_manifest_mgv7_special_flags",
			path..".mgv7_special_flags","exact ordered closed bitset","changed")
	end
	for i=1,#expected_special do
		local row=manifest.mgv7_special_flags[i]
		ok,failure=closed_fields(row,path..".mgv7_special_flags["..i.."]",
			{"id","enabled"},"critical_manifest_mgv7_special_flags")
		if not ok then return nil,failure end
		if row.id~=expected_special[i][1] or row.enabled~=expected_special[i][2] then
			return diag("critical_manifest_mgv7_special_flags",
				path..".mgv7_special_flags["..i.."]",
				expected_special[i][1]..":"..tostring(expected_special[i][2]),
				diagnostic_atom(row.id)..":"..diagnostic_atom(row.enabled))
		end
	end
	local noise=manifest.mgv7_np_dungeons
	ok,failure=closed_fields(noise,path..".mgv7_np_dungeons",
		{"offset","scale","spread","seed","octaves","persistence",
		"lacunarity","flags"},"critical_manifest_noise_fields")
	if not ok then return nil,failure end
	ok,failure=exact_rational(noise.offset,9,10,
		path..".mgv7_np_dungeons.offset")
	if not ok then return nil,failure end
	ok,failure=exact_rational(noise.scale,1,2,
		path..".mgv7_np_dungeons.scale")
	if not ok then return nil,failure end
	ok,failure=closed_fields(noise.spread,path..".mgv7_np_dungeons.spread",
		{"x","y","z"},"critical_manifest_noise_fields")
	if not ok then return nil,failure end
	for _,axis in ipairs({"x","y","z"}) do
		if noise.spread[axis]~=500 then
			return diag("critical_manifest_noise_value",
				path..".mgv7_np_dungeons.spread."..axis,500,noise.spread[axis])
		end
	end
	for _,expected_row in ipairs({{"seed",0},{"octaves",2},{"lacunarity",2}}) do
		local field,expected=expected_row[1],expected_row[2]
		if noise[field]~=expected then
			return diag("critical_manifest_noise_value",
				path..".mgv7_np_dungeons."..field,expected,noise[field])
		end
	end
	ok,failure=exact_rational(noise.persistence,4,5,
		path..".mgv7_np_dungeons.persistence")
	if not ok then return nil,failure end
	ok,failure=exact_ordered_strings(noise.flags,
		path..".mgv7_np_dungeons.flags",{"defaults"},
		"critical_manifest_noise_flags")
	if not ok then return nil,failure end
	return true
end

local function validate_impl(source, vocabulary, canonical, raw_sha256)
	if type(source) ~= "table" then return diag("source_type", "source", "table", type(source)) end
	local ok, failure = source_graph(source, "source", {})
	if not ok then return nil, failure end
	if source.schema ~= "grug_wp40_authored_source_v1" then
		return diag("source_schema", "source", "grug_wp40_authored_source_v1", source.schema)
	end
	local expected_sections={"critical_source_manifest","constants",
		"relief_profiles","route_classes",
		"water_classes","landmark_role_vocabulary","template_primitives",
		"zones","land_edges","route_stations","routes","route_interfaces",
		"route_crossing_interfaces","boat_edges","island_landings",
		"island_route_stations","island_routes","island_route_interfaces",
		"perimeters","bays","islands","channels","landmarks","anchors","templates",
		"template_compositions","hydrology","hydrology_interfaces",
		"housing_masks","coastal_housing_cores","semantics"}
	if not dense(source.section_order) or #source.section_order~=#expected_sections then return diag("section_order","source","exact ordered sections","changed") end
	for i=1,#expected_sections do if source.section_order[i]~=expected_sections[i] then return diag("section_order","source["..i.."]",expected_sections[i],source.section_order[i]) end end
	ok,failure=validate_critical_manifest(source.critical_source_manifest)
	if not ok then return nil,failure end
	for count_index=1,#EXPECTED_COUNTS do
		local field=EXPECTED_COUNTS[count_index][1]
		local count=EXPECTED_COUNTS[count_index][2]
		if not dense(source[field]) or #source[field] ~= count then
			return diag("exact_count_" .. field, field, count,
				type(source[field]) == "table" and #source[field] or type(source[field]))
		end
	end
	local zone_ids
	ok, zone_ids = unique_ordered(source.zones, "zones")
	if not ok then return nil, zone_ids end
	for _, family in ipairs({"relief_profiles","route_classes","water_classes",
			"template_primitives","perimeters","bays","islands","channels",
			"landmarks","anchors","templates","template_compositions",
			"hydrology","hydrology_interfaces","route_stations","routes","route_interfaces",
			"route_crossing_interfaces","island_landings","island_route_stations",
			"island_routes","island_route_interfaces","housing_masks",
			"coastal_housing_cores"}) do
		ok, failure = unique_ordered(source[family], family)
		if not ok then return nil, failure end
	end
	local relief_ids = {}
	for i = 1, #source.relief_profiles do relief_ids[source.relief_profiles[i].id] = true end
	local race_allowed = {dwarf=true,human=true,elf=true,undead=true,orc=true,troll=true}
	local territory_allowed = {accord_home=true,throng_home=true,contested_land=true,holy_grounds=true}
	local biome_allowed={grug_meadows=true,grug_deep_forest=true,
		grug_pine_hills=true,grug_crags=true,grug_crags_snowy=true,
		grug_elf_forest=true,grug_jungle_fringe=true,grug_savanna=true,
		grug_badlands=true,grug_badlands_east=true,grug_blight=true,
		grug_bone_forest=true,grug_jungle_edge=true,grug_deep_jungle=true,
		grug_swamp=true,grug_beach=true}
	for i = 1, #source.zones do
		local row = source.zones[i]
		if not race_allowed[row.race_region] then return diag("zone_race_region",row.id,"valid race region",row.race_region) end
		if not territory_allowed[row.territory_rule] then return diag("zone_territory_rule",row.id,"valid source policy",row.territory_rule) end
		if row.pvp_rule ~= "peaceful" and row.pvp_rule ~= "contested" then return diag("zone_pvp_rule",row.id,"peaceful/contested",row.pvp_rule) end
		if not relief_ids[row.primary_relief_id] then return diag("zone_relief",row.id,"registered relief",row.primary_relief_id) end
		if not dense(row.biomes) or #row.biomes == 0 then return diag("zone_palette",row.id,"non-empty dense palette","invalid") end
		local total, seen = 0, {}
		for j = 1, #row.biomes do
			local entry = row.biomes[j]
			if type(entry.id) ~= "string" or not biome_allowed[entry.id] or seen[entry.id] then return diag("zone_palette_id",row.id,"unique allowed biome id",entry.id) end
			if type(entry.share)~="number" or entry.share<0 or entry.share%1~=0 then return diag("zone_palette_share",row.id,"nonnegative integer",entry.share) end
			seen[entry.id] = true
			total = total + (entry.share or 0)
		end
		if total ~= 100 then return diag("zone_palette_total",row.id,100,total) end
	end
	local edge_ids
	ok, edge_ids = unique_ordered(source.land_edges, "land_edges")
	if not ok then return nil, edge_ids end
	local pairs_seen = {}
	for i = 1, #source.land_edges do
		local row = source.land_edges[i]
		if not zone_ids[row.zone_a] or not zone_ids[row.zone_b] then return diag("land_edge_zone",row.id,"known zones",row.zone_a..":"..row.zone_b) end
		if row.zone_a == row.zone_b then return diag("land_edge_self",row.id,false,true) end
		local a, b = row.zone_a, row.zone_b
		if b < a then a, b = b, a end
		local key = a .. "\0" .. b
		if pairs_seen[key] then return diag("land_edge_duplicate",row.id,false,true) end
		pairs_seen[key] = true
		if row.route_class~=nil then return diag("boundary_route_separation",row.id,"no route-owned fields","route_class") end
		if not dense(row.control) or #row.control < 2 then return diag("edge_control",row.id,"two or more points","invalid") end
		for j=1,#row.control do
			if not point_valid(row.control[j],false) then return diag("edge_control_point",row.id,"integer x/z point","invalid") end
		end
	end
	local station_ids,station_by_id={},{}
	local station_kind_allowed={hub=true,start_gate=true,capital_gate=true}
	for i=1,#source.route_stations do local row=source.route_stations[i]
		if not zone_ids[row.zone_id] or not station_kind_allowed[row.kind] or not point_valid(row.position,false) or (row.gate_ref~=false and type(row.gate_ref)~="string") then return diag("route_station_contract",row.id,"known zone/kind/point/gate","invalid") end
		station_ids[row.id]=true station_by_id[row.id]=row
	end
	local route_classes={primary=true,secondary=true,trail=true}
	local route_ids,route_by_id,route_counts={},{},{primary=0,secondary=0,trail=0}
	for i=1,#source.routes do
		local row=source.routes[i]
		local edge=source.land_edges[i]
		if row.boundary_id~=edge.id or row.zone_a~=edge.zone_a or
				row.zone_b~=edge.zone_b then
			return diag("route_boundary_reference",row.id,edge.id,"mismatch")
		end
		if not route_classes[row.class] or not dense(row.centreline) or
				#row.centreline<5 or type(row.crossing_station)~="number" or row.crossing_station<2 or row.crossing_station>#row.centreline-1 then return diag("route_geometry",row.id,"valid class and complete centreline","invalid") end
		route_counts[row.class]=route_counts[row.class]+1
		for j=1,#row.centreline do if not point_valid(row.centreline[j],false) then return diag("route_point",row.id,"integer x/z point","invalid") end end
		local crossing=row.centreline[row.crossing_station]
		local on_boundary,side_a,side_b=false,nil,nil
		for j=1,#edge.control-1 do if cross(edge.control[j],edge.control[j+1],crossing)==0 and between(edge.control[j],edge.control[j+1],crossing) then on_boundary=true side_a=cross(edge.control[j],edge.control[j+1],row.centreline[row.crossing_station-1]) side_b=cross(edge.control[j],edge.control[j+1],row.centreline[row.crossing_station+1]) break end end
		if not on_boundary then return diag("route_crosses_boundary",row.id,true,false) end
		if side_a==0 or side_b==0 or side_a*side_b>=0 then return diag("route_crossing_sides",row.id,"opposite nonzero boundary sides",tostring(side_a)..":"..tostring(side_b)) end
		local station_a,station_b=station_by_id[row.station_a_id],station_by_id[row.station_b_id]
		if not station_a or not station_b or station_a.zone_id~=row.zone_a or station_b.zone_id~=row.zone_b or row.centreline[1].x~=station_a.position.x or row.centreline[1].z~=station_a.position.z or row.centreline[#row.centreline].x~=station_b.position.x or row.centreline[#row.centreline].z~=station_b.position.z then return diag("route_station_ref",row.id,"matching endpoint stations","mismatch") end
		if station_a.gate_ref~=row.gate_ref_a or station_b.gate_ref~=row.gate_ref_b then return diag("route_gate_ref",row.id,"station-owned gate refs","mismatch") end
		if row.endpoint_a_id==row.endpoint_b_id or type(row.boundary_interface_id)~="string" or type(row.grade_phase)~="number" then return diag("route_interfaces",row.id,"distinct endpoints/crossing/phase","invalid") end
		route_ids[row.id]=true route_by_id[row.id]=row
	end
	for _,expected_row in ipairs({{"primary",30},{"secondary",24},{"trail",3}}) do local class,expected=expected_row[1],expected_row[2] if route_counts[class]~=expected then return diag("route_class_count",class,expected,route_counts[class]) end end
	local route_interface_ids={}
	for i=1,#source.route_interfaces do local row=source.route_interfaces[i]
		if not route_ids[row.route_id] or not point_valid(row.position,false) or
				type(row.direction)~="string" or row.direction=="" then return diag("route_interface_contract",row.id,"route/point/direction","invalid") end
		if row.kind=="endpoint" and not station_ids[row.station_id] then return diag("route_interface_station_ref",row.id,"known station",row.station_id) end
		if row.kind~="endpoint" and row.kind~="boundary_crossing" then return diag("route_interface_kind",row.id,"endpoint/boundary_crossing",row.kind) end
		route_interface_ids[row.id]=true
	end
	for i=1,#source.routes do local row=source.routes[i]
		if not route_interface_ids[row.endpoint_a_id] or not route_interface_ids[row.endpoint_b_id] or not route_interface_ids[row.boundary_interface_id] then return diag("route_interface_ref",row.id,"three known interfaces","missing") end
	end
	local boat_ids
	ok, boat_ids = unique_ordered(source.boat_edges,"boat_edges")
	if not ok then return nil, boat_ids end
	local expected_boats={{"front_gravesalt_escarpment","front_wyrmglass_crown",-125,96},{"front_gravesalt_escarpment","front_wyrmglass_crown",125,96},{"front_skyglass_canopy","front_stormscale_summit",-125,96},{"front_skyglass_canopy","front_stormscale_summit",125,96}}
	local landings={}
	for i = 1, #source.boat_edges do
		local row = source.boat_edges[i]
		if not zone_ids[row.from_zone] or not zone_ids[row.to_zone] then return diag("boat_edge_zone",row.id,"known zones","invalid") end
		local a,b=row.from_zone,row.to_zone if b<a then a,b=b,a end
		if pairs_seen[a.."\0"..b] then return diag("boat_land_disjoint",row.id,true,false) end
		local expected=expected_boats[i]
		if row.from_zone~=expected[1] or row.to_zone~=expected[2] or row.approach_z~=expected[3] or row.width~=expected[4] then return diag("exact_boat_contract",row.id,"fixed endpoint/z/width","changed") end
		if landings[row.landing_id] then return diag("boat_distinct_landing",row.id,true,false) end
		landings[row.landing_id]=true
	end
	local family_counts, slot_seen, local_suffixes = {}, {}, {}
	local anchor_ids,anchor_by_id={},{}
	for i = 1, #source.anchors do
		local row = source.anchors[i]
		anchor_ids[row.id]=true anchor_by_id[row.id]=row
		local slot = row.slot_id
		local family = type(slot)=="string" and slot_family(slot) or nil
		if not family then return diag("anchor_slot_identity",row.id,"legal stable slot",row.slot_id) end
		family_counts[family] = (family_counts[family] or 0) + 1
		-- Lua patterns have no alternation; keep the four accepted numbered
		-- families explicit.
		local suffix = slot:match("^village_(%d+)$")
		if not suffix then suffix = slot:match("^outpost_(%d+)$") end
		if not suffix then suffix = slot:match("^bandit_(%d+)$") end
		if not suffix then suffix = slot:match("^clash_(%d+)$") end
		if suffix then
			local key = row.zone_id .. "\0" .. family
			local_suffixes[key] = local_suffixes[key] or {}
			local_suffixes[key][tonumber(suffix)] = true
		end
		if not zone_ids[row.zone_id] then return diag("anchor_zone",row.id,"known zone",row.zone_id) end
		local slot_key = row.zone_id .. "\0" .. row.slot_id
		if slot_seen[slot_key] then return diag("anchor_slot_unique",row.id,true,false) end
		slot_seen[slot_key] = true
		if row.placement_mode == "fixed" then
			if not point_valid(row.position,false) then return diag("fixed_anchor_position",row.id,"integer x/z point","invalid") end
		elseif row.placement_mode == "candidate_set" then
			if not dense(row.candidates) or #row.candidates == 0 then return diag("candidate_anchor_set",row.id,"non-empty dense array","invalid") end
			for j=1,#row.candidates do if not point_valid(row.candidates[j],false) then return diag("candidate_anchor_point",row.id,"integer x/z point","invalid") end end
		else return diag("anchor_placement_mode",row.id,"fixed/candidate_set",row.placement_mode) end
		if family=="rare" then
			if not dense(row.patrol_route) or #row.patrol_route<2 or #row.patrol_route>3 then return diag("rare_patrol_route",row.id,"2..3 fixed points","invalid") end
			for j=1,#row.patrol_route do if not point_valid(row.patrol_route[j],false) then return diag("rare_patrol_point",row.id,"integer x/z point","invalid") end end
		end
	end
	for count_index=1,#SLOT_COUNTS do
		local family,expected=SLOT_COUNTS[count_index][1],SLOT_COUNTS[count_index][2]
		if family_counts[family] ~= expected then return diag("anchor_family_count",family,expected,family_counts[family]) end
	end
	local suffix_keys={}
	for key in pairs(local_suffixes) do suffix_keys[#suffix_keys+1]=key end
	table.sort(suffix_keys)
	for key_index=1,#suffix_keys do
		local key=suffix_keys[key_index]
		local suffixes=local_suffixes[key]
		local count=0 for _ in pairs(suffixes) do count=count+1 end
		for i=1,count do if not suffixes[i] then return diag("anchor_local_suffixes",key,"contiguous 1.."..count,"gap") end end
	end
	local island_ids,island_by_id={},{}
	for i=1,#source.islands do local row=source.islands[i] island_ids[row.id]=true island_by_id[row.id]=row end
	local landing_ids,landing_by_id={},{}
	for i=1,#source.island_landings do local row=source.island_landings[i]
		if not island_ids[row.island_id] or not zone_ids[row.zone_id] or
				not boat_ids[row.boat_edge_id] or not point_valid(row.position,false) or
				not point_in_polygon(row.position,island_by_id[row.island_id].polygon) or
				source.boat_edges[i].landing_id~=row.id or
				source.boat_edges[i].id~=row.boat_edge_id then
			return diag("island_landing_contract",row.id,"island/zone/boat/point in canonical order","invalid")
		end
		landing_ids[row.id]=true landing_by_id[row.id]=row
	end
	local island_station_ids,island_station_by_id={},{}
	local island_station_kind={landing=true,junction=true,dragon=true,apex_mine=true}
	for i=1,#source.island_route_stations do local row=source.island_route_stations[i]
		if not island_ids[row.island_id] or not island_station_kind[row.kind] or not point_valid(row.position,false) then return diag("island_route_station_contract",row.id,"island/kind/point","invalid") end
		if (row.kind=="dragon" or row.kind=="apex_mine") and not anchor_ids[row.anchor_id] then return diag("island_target_anchor_ref",row.id,"known target anchor",row.anchor_id) end
		if row.anchor_id then local anchor=anchor_by_id[row.anchor_id] local candidate=anchor and anchor.candidates and anchor.candidates[1] if not candidate or candidate.x~=row.position.x or candidate.z~=row.position.z then return diag("island_target_anchor_position",row.id,"anchor first candidate",row.anchor_id) end end
		island_station_ids[row.id]=true island_station_by_id[row.id]=row
	end
	for i=1,#source.island_landings do local row=source.island_landings[i] local station=island_station_by_id[row.station_id]
		if not station or station.kind~="landing" or station.island_id~=row.island_id or station.position.x~=row.position.x or station.position.z~=row.position.z then return diag("island_landing_station_ref",row.id,"matching landing station","mismatch") end
	end
	local island_route_ids,island_route_by_id={},{}
	local adjacency={}
	for i=1,#source.island_route_stations do adjacency[source.island_route_stations[i].id]={} end
	for i=1,#source.island_routes do local row=source.island_routes[i]
		local from,to=island_station_by_id[row.from_station_id],island_station_by_id[row.to_station_id]
		if not from or not to or from.island_id~=row.island_id or to.island_id~=row.island_id or row.class~="secondary" or not dense(row.centreline) or #row.centreline<2 then return diag("island_route_contract",row.id,"same-island stations/class/centreline","invalid") end
		for j=1,#row.centreline do if not point_valid(row.centreline[j],false) or not point_in_polygon(row.centreline[j],island_by_id[row.island_id].polygon) then return diag("island_route_point",row.id,"integer point inside island polygon","invalid") end end
		if row.centreline[1].x~=from.position.x or row.centreline[1].z~=from.position.z or row.centreline[#row.centreline].x~=to.position.x or row.centreline[#row.centreline].z~=to.position.z then return diag("island_route_endpoint",row.id,"station positions","mismatch") end
		adjacency[from.id][#adjacency[from.id]+1]=to.id adjacency[to.id][#adjacency[to.id]+1]=from.id
		island_route_ids[row.id]=true island_route_by_id[row.id]=row
	end
	local interface_counts={}
	for i=1,#source.island_route_interfaces do local row=source.island_route_interfaces[i] local route=island_route_by_id[row.route_id] local station=island_station_by_id[row.station_id]
		if not route or not station or row.kind~="endpoint" or not point_valid(row.position,false) or row.position.x~=station.position.x or row.position.z~=station.position.z or (station.id~=route.from_station_id and station.id~=route.to_station_id) then return diag("island_route_interface_contract",row.id,"route endpoint station/point","invalid") end
		interface_counts[row.route_id]=(interface_counts[row.route_id] or 0)+1
	end
	for i=1,#source.island_routes do if interface_counts[source.island_routes[i].id]~=2 then return diag("island_route_interface_count",source.island_routes[i].id,2,interface_counts[source.island_routes[i].id]) end end
	local function reachable(start_id,target_id,blocked_id)
		local queue={start_id} local head=1 local seen={[start_id]=true}
		while head<=#queue do local current=queue[head] head=head+1 if current==target_id then return true end
			local next_ids=adjacency[current] for j=1,#next_ids do local next_id=next_ids[j] if next_id~=blocked_id and not seen[next_id] then seen[next_id]=true queue[#queue+1]=next_id end end
		end return false
	end
	for i=1,#source.island_landings do local landing=source.island_landings[i] local dragon,apex,junction
		for j=1,#source.island_route_stations do local station=source.island_route_stations[j] if station.island_id==landing.island_id then if station.kind=="dragon" then dragon=station.id elseif station.kind=="apex_mine" then apex=station.id elseif station.kind=="junction" then junction=station.id end end end
		if not dragon or not apex or not junction or not reachable(landing.station_id,dragon,nil) or not reachable(landing.station_id,apex,nil) then return diag("island_route_connectivity",landing.id,"both targets through authored branch","disconnected") end
		if not reachable(landing.station_id,dragon,apex) or not reachable(landing.station_id,apex,dragon) then return diag("island_route_target_independence",landing.id,"neither target gates the other",false) end
	end
	for _, collection in ipairs({source.perimeters,source.islands,source.channels,source.housing_masks}) do
		if not dense(collection) then return diag("dense_array","polygon_collection",true,false) end
		for i = 1, #collection do
			ok, failure = polygon_valid(collection[i],collection[i].id)
			if not ok then return nil, failure end
		end
	end
	local role_allowed={base_H=true,target_T=true,hydrology=true,route=true,
		interface=true,dressing=true}
	local landmark_primitive_allowed={rectangle=true,ellipse=true,capsule=true}
	local landmark_ids,landmark_by_id={},{}
	for i=1,#source.landmarks do local row=source.landmarks[i]
		if not zone_ids[row.zone_id] or not landmark_primitive_allowed[row.primitive] or
				not point_valid(row.center,false) or type(row.radius_x)~="number" or
				type(row.radius_z)~="number" or row.radius_x<=0 or row.radius_z<=0 or
				not dense(row.roles) or #row.roles==0 then return diag("landmark_contract",row.id,"known zone/primitive/mask/roles","invalid") end
		for j=1,#row.roles do if not role_allowed[row.roles[j]] then return diag("landmark_role",row.id,"allowed role",row.roles[j]) end end
		landmark_ids[row.id]=true landmark_by_id[row.id]=row
	end
	local primitive_ids={}
	for i=1,#source.template_primitives do primitive_ids[source.template_primitives[i].id]=true end
	local operation_allowed={apply=true,overlay=true,blend=true,subtract=true}
	local composition_ids,composition_by_id={},{}
	for i=1,#source.template_compositions do local row=source.template_compositions[i]
		composition_ids[row.id]=true composition_by_id[row.id]=row
		if row.version~=1 or not dense(row.operations) or #row.operations==0 then return diag("template_composition",row.id,"versioned operations","invalid") end
		for j=1,#row.operations do local operation=row.operations[j]
			if not operation_allowed[operation.op] or not primitive_ids[operation.primitive_id] or type(operation.parameters)~="table" then return diag("template_operation",row.id,"known op/primitive/parameters","invalid") end
		end
	end
	local housing_composition=composition_by_id.compose_coastal_housing_core
	local housing_operation=housing_composition and housing_composition.operations[1]
	local parameter_count=0
	if housing_operation and type(housing_operation.parameters)=="table" then for _ in pairs(housing_operation.parameters) do parameter_count=parameter_count+1 end end
	if not housing_composition or #housing_composition.operations~=1 or
			housing_operation.op~="apply" or
			housing_operation.primitive_id~="housing_smoothing" or
			parameter_count~=2 or
			housing_operation.parameters.radius~=source.constants.housing_reservation_radius or
			housing_operation.parameters.relief_limit~=source.constants.housing_relief_limit then
		return diag("housing_smoothing_composition","compose_coastal_housing_core","one exact constant-bound smoothing operation","invalid")
	end
	local template_ids={}
	for i=1,#source.templates do local row=source.templates[i]
		if not composition_ids[row.composition_id] then return diag("template_composition_ref",row.id,"known composition",row.composition_id) end
		template_ids[row.id]=true
	end
	for i=1,#source.anchors do if not template_ids[source.anchors[i].template_id] then return diag("anchor_template_ref",source.anchors[i].id,"known template",source.anchors[i].template_id) end end
	local hydrology_ids,hydrology_by_id={},{}
	local depth_allowed={[0]=true,[1]=true,[2]=true,[4]=true,[8]=true,[12]=true}
	for i=1,#source.hydrology do local row=source.hydrology[i]
		hydrology_ids[row.id]=true hydrology_by_id[row.id]=row
		if not zone_ids[row.zone_id] or not landmark_ids[row.landmark_id] or
				not depth_allowed[row.depth] or not dense(row.centreline) or
				#row.centreline<2 or row.bed_seal_layers~=3 or
				row.bank_seal_nodes~=2 or type(row.from_id)~="string" or
				type(row.to_id)~="string" or type(row.water_surface)~="table" or
				row.water_surface.reference~="mapgen_water_level" or
				type(row.water_surface.offset)~="number" then return diag("hydrology_contract",row.id,"typed connected sealed reach with W/D","invalid") end
		if row.depth==0 and row.profile~="dry_channel" then return diag("hydrology_dry_profile",row.id,"dry_channel",row.profile) end
		for j=1,#row.centreline do if not point_valid(row.centreline[j],true) then return diag("hydrology_point",row.id,"x/z/positive half_width","invalid") end end
	end
	local crossing_ids={}
	for i=1,#source.route_crossing_interfaces do crossing_ids[source.route_crossing_interfaces[i].id]=true end
	local hydrology_interface_kinds={confluence=true,bridge=true,ford=true,
		waterfall=true,causeway=true,rapid=true}
	for i=1,#source.hydrology_interfaces do local row=source.hydrology_interfaces[i]
		if not hydrology_interface_kinds[row.kind] then return diag("hydrology_interface_kind",row.id,"closed kind",row.kind) end
		if row.hydrology_id and not hydrology_ids[row.hydrology_id] then return diag("hydrology_interface_ref",row.id,"known reach",row.hydrology_id) end
		if row.route_interface_id and not crossing_ids[row.route_interface_id] then return diag("hydrology_route_interface_ref",row.id,"known route crossing",row.route_interface_id) end
		if row.upper_id and (not hydrology_ids[row.upper_id] or not hydrology_ids[row.lower_id] or not point_valid(row.position,false) or type(row.lip_id)~="string" or type(row.drop_id)~="string" or type(row.plunge_id)~="string" or row.drop_height<=0 or row.bed_seal_layers~=3 or row.bank_seal_nodes~=2) then return diag("waterfall_interface",row.id,"connected lip/drop/plunge/seals","invalid") end
		if row.kind=="rapid" and (not point_valid(row.position,false) or row.run<=0 or row.drop<=0 or row.sealed~=true) then return diag("rapid_interface",row.id,"position/run/drop/seal","invalid") end
	end
	local crossing_kind_allowed={bridge=true,ford=true,causeway=true,tunnel=true}
	for i=1,#source.route_crossing_interfaces do local row=source.route_crossing_interfaces[i]
		if not route_ids[row.route_id] or not crossing_kind_allowed[row.kind] or not point_valid(row.position,false) or row.span<=0 or row.width<=0 or type(row.grade_limit)~="table" then return diag("route_crossing_contract",row.id,"route/kind/point/span/width/grade","invalid") end
		if row.hydrology_id and not hydrology_ids[row.hydrology_id] then return diag("route_crossing_hydrology_ref",row.id,"known hydrology",row.hydrology_id) end
		if row.landmark_id and not landmark_ids[row.landmark_id] then return diag("route_crossing_landmark_ref",row.id,"known landmark",row.landmark_id) end
		local route=route_by_id[row.route_id]
		local on_route=false
		for j=1,#route.centreline-1 do if cross(route.centreline[j],route.centreline[j+1],row.position)==0 and between(route.centreline[j],route.centreline[j+1],row.position) then on_route=true break end end
		if not on_route then return diag("route_crossing_route_incidence",row.id,"position on referenced route centreline",false) end
		if row.hydrology_id and not point_in_reach(row.position,hydrology_by_id[row.hydrology_id].centreline) then return diag("route_crossing_hydrology_incidence",row.id,"position inside authored reach width",false) end
		if row.kind=="tunnel" and not point_in_landmark(row.position,landmark_by_id[row.landmark_id]) then return diag("tunnel_landmark_incidence",row.id,"position inside exact landmark mask",false) end
		if not crossing_ids[row.alternate_id] and not route_ids[row.alternate_id] then return diag("route_crossing_alternate_ref",row.id,"known crossing or route",row.alternate_id) end
		if row.kind=="tunnel" and row.portal_length~=16 then return diag("tunnel_portal_length",row.id,16,row.portal_length) end
	end
	if source.hydrology[5].centreline[1].x==source.hydrology[6].centreline[1].x then return diag("highcourt_arms_distinct","highcourt",true,false) end
	for _,index in ipairs({89,90}) do local counts={citrine=0,garnet=0,jade=0,diamond=0,sapphire=0,ruby=0}
		local sockets=source.anchors[index].socket_resource_keys
		if not dense(sockets) or #sockets~=12 then return diag("apex_socket_count",source.anchors[index].id,12,type(sockets)=="table" and #sockets or "invalid") end
		for j=1,#sockets do if counts[sockets[j]]==nil then return diag("apex_socket_species",source.anchors[index].id,"six gem keys",sockets[j]) end counts[sockets[j]]=counts[sockets[j]]+1 end
		for _,key in ipairs({"citrine","garnet","jade","diamond","sapphire","ruby"}) do if counts[key]~=2 then return diag("apex_socket_species_count",source.anchors[index].id..":"..key,2,counts[key]) end end
	end
	local housing_zones={elandor_copperfell_foothills=true,elandor_goldmead_vale=true,elandor_starbough_vale=true,elandor_whitebridge_shire=true,elandor_lorindor=true,kragmar_mournfen=true,kragmar_redtusk_savanna=true,kragmar_raincall_basin=true,kragmar_speargrass_reach=true,kragmar_whispering_reedlands=true}
	local housing_ids={}
	for i=1,#source.housing_masks do local row=source.housing_masks[i] if not housing_zones[row.zone_id] then return diag("housing_zone",row.id,"exact housing-zone catalog",row.zone_id) end housing_ids[row.id]=true end
	for i=1,#source.coastal_housing_cores do local row=source.coastal_housing_cores[i]
		if not housing_ids[row.housing_mask_id] or row.composition_id~="compose_coastal_housing_core" or row.frontage_min~=600 or row.inland_depth_min~=300 or row.relief_max~=12 or not dense(row.centerline) or #row.centerline<2 then return diag("coastal_core_contract",row.id,"mask/composition/minima/centreline","invalid") end
		for j=1,#row.centerline do if not point_valid(row.centerline[j],false) then return diag("coastal_core_point",row.id,"integer x/z point","invalid") end end
	end
	if source.constants.holy_grounds.min_x ~= -2500 or source.constants.holy_grounds.max_x ~= 2500 or source.constants.holy_grounds.min_z ~= -250 or source.constants.holy_grounds.max_z ~= 250 then
		return diag("fixed_holy_rectangle","holy_grounds","-2500..2500/-250..250","changed")
	end
	local fixed_constants = {
		{"q",source.constants.q,65536},
		{"mainland_frame.min_x",source.constants.mainland_frame.min_x,-2600},
		{"mainland_frame.max_x",source.constants.mainland_frame.max_x,2600},
		{"mainland_frame.min_z",source.constants.mainland_frame.min_z,-3000},
		{"mainland_frame.max_z",source.constants.mainland_frame.max_z,3000},
		{"ordinary_boundary_displacement",source.constants.ordinary_boundary_displacement,64},
		{"peace_contested_displacement",source.constants.peace_contested_displacement,32},
		{"coast_displacement",source.constants.coast_displacement,96},
		{"bay_displacement",source.constants.bay_displacement,48},
		{"boundary_min_wavelength",source.constants.boundary_min_wavelength,256},
		{"anchor_no_jitter_radius",source.constants.anchor_no_jitter_radius,96},
		{"minimum_zone_core",source.constants.minimum_zone_core,256},
		{"minimum_travel_corridor",source.constants.minimum_travel_corridor,96},
		{"coastal_shelf_width",source.constants.coastal_shelf_width,80},
		{"flight_warning_width",source.constants.flight_warning_width,48},
		{"minimum_dragon_channel",source.constants.minimum_dragon_channel,200},
		{"minimum_hard_flight_width",source.constants.minimum_hard_flight_width,104},
		{"dragon_approach_width",source.constants.dragon_approach_width,96},
		{"shallow_protection_floor",source.constants.shallow_protection_floor,-700},
		{"contested_deep_ceiling",source.constants.contested_deep_ceiling,-701},
		{"housing_reservation_width",source.constants.housing_reservation_width,101},
		{"housing_reservation_radius",source.constants.housing_reservation_radius,50},
		{"housing_relief_limit",source.constants.housing_relief_limit,12},
		{"housing_frontage_min",source.constants.housing_frontage_min,600},
		{"housing_depth_min",source.constants.housing_depth_min,300},
		{"capital_build_width",source.constants.capital_build_width,512},
		{"capital_blend_width",source.constants.capital_blend_width,704},
		{"start_build_width",source.constants.start_build_width,128},
		{"start_blend_width",source.constants.start_blend_width,256},
		{"start_dry_core_width",source.constants.start_dry_core_width,600},
		{"start_dry_core_depth",source.constants.start_dry_core_depth,500},
		{"island_envelope_width",source.constants.island_envelope_width,600},
		{"island_envelope_depth",source.constants.island_envelope_depth,700},
	}
	for i=1,#fixed_constants do local row=fixed_constants[i] if row[2]~=row[3] then return diag("fixed_constant",row[1],row[3],row[2]) end end
	if source.constants.holy_junction_x[1] ~= -1500 or
			source.constants.holy_junction_x[2] ~= 0 or
			source.constants.holy_junction_x[3] ~= 1500 then
		return diag("fixed_holy_junctions","holy_junction_x","-1500,0,1500","changed")
	end
	if source.constants.dragon_approach_z[1] ~= -125 or
			source.constants.dragon_approach_z[2] ~= 125 then
		return diag("fixed_dragon_approaches","dragon_approach_z","-125,125","changed")
	end
	local function point_signature(points, widths)
		local parts={}
		for i=1,#points do
			local row=points[i]
			parts[i]=row.x..","..row.z..(widths and ","..row.half_width or "")
		end
		return table.concat(parts,";")
	end
	local bay_signatures={
		"-980,-2940,360;-900,-2600,280;-1040,-2300,190;-980,-2000,80",
		"900,-2920,330;1080,-2580,250;920,-2280,180;1020,-1990,80",
		"-1080,2930,320;-1200,2620,260;-940,2300,190;-1060,2010,80",
		"820,2960,370;700,2630,250;1050,2320,170;900,1980,80",
	}
	for i=1,4 do
		local actual=point_signature(source.bays[i].centreline,true)
		if actual~=bay_signatures[i] then return diag("fixed_bay_samples",source.bays[i].id,bay_signatures[i],actual) end
	end
	local island_fixed={{-3150,0,300,350},{3150,0,300,350}}
	for i=1,2 do local row=source.islands[i] local expected=island_fixed[i]
		if row.center.x~=expected[1] or row.center.z~=expected[2] or
				row.envelope.radius_x~=expected[3] or row.envelope.radius_z~=expected[4] then
			return diag("fixed_island_envelope",row.id,"fixed center and 300x350 radii","changed")
		end
	end
	local start_expected={{-1800,-2550},{0,-2550},{1800,-2550},{-1800,2550},{0,2550},{1800,2550}}
	local capital_expected={{-1800,-1500},{0,-1500},{1800,-1500},{-1800,1500},{0,1500},{1800,1500}}
	for i=1,6 do
		local p=source.anchors[i].position if p.x~=start_expected[i][1] or p.z~=start_expected[i][2] then return diag("fixed_start_coordinate",source.anchors[i].id,start_expected[i][1]..","..start_expected[i][2],p.x..","..p.z) end
		p=source.anchors[i+6].position if p.x~=capital_expected[i][1] or p.z~=capital_expected[i][2] then return diag("fixed_capital_coordinate",source.anchors[i+6].id,capital_expected[i][1]..","..capital_expected[i][2],p.x..","..p.z) end
	end
	if not vocabulary then
		return diag("semantic_vocabulary","vocabulary","required WP43 projection","missing")
	else
		local resources=semantic_set(vocabulary,"resource_keys")
		local cultures=semantic_set(vocabulary,"cultural_keys")
		local woods=semantic_set(vocabulary,"wood_keys")
		if not resources or not cultures or not woods or not dense(vocabulary.resource_rows) then return diag("semantic_vocabulary","vocabulary","projection keys and rows","invalid") end
		local resource_rows={}
		for i=1,#vocabulary.resource_rows do resource_rows[vocabulary.resource_rows[i].key]=vocabulary.resource_rows[i] end
		local expected_assignments={{"dwarf","garnet","sapphire","runeslate","mountain_pine"},{"human","citrine","diamond","sunwax","oak"},{"elf","jade","sapphire","moonresin","silverwood"},{"undead","citrine","ruby","gravesalt","gravewood"},{"orc","garnet","diamond","red_ochre","spikethorn_acacia"},{"troll","jade","ruby","spirit_resin","kapok"}}
		for i=1,#source.semantics.race_region_assignments do
			local row=source.semantics.race_region_assignments[i]
			if not resources[row.g1] or not resources[row.g2] or not cultures[row.cultural] or not woods[row.signature_wood] then return diag("semantic_reference",row.race_region,"published WP43 stable key","unresolved") end
			local expected=expected_assignments[i]
			if row.race_region~=expected[1] or row.g1~=expected[2] or row.g2~=expected[3] or row.cultural~=expected[4] or row.signature_wood~=expected[5] then return diag("exact_race_assignment",row.race_region,"WP43 published assignment","changed") end
			if not resource_rows[row.g1] or resource_rows[row.g1].scope~="regional" or resource_rows[row.g1].grade~="G1" or not resource_rows[row.g2] or resource_rows[row.g2].scope~="regional" or resource_rows[row.g2].grade~="G2" then return diag("semantic_resource_grade",row.race_region,"regional G1/G2","mismatch") end
		end
		for _, index in ipairs({89,90}) do for j=1,#source.anchors[index].socket_resource_keys do local key=source.anchors[index].socket_resource_keys[j] if not resources[key] then return diag("semantic_reference",source.anchors[index].id,"published WP43 resource key",key) end end end
	end
	if type(canonical)~="table" or type(raw_sha256)~="function" then
		return diag("exact_source_seam","source","T1 canonical module and raw SHA injection","missing")
	end
	local projected_ok,projected=pcall(canonicalize_source,source,canonical)
	if not projected_ok then return diag("exact_source_projection","source","valid canonical graph",projected) end
	local checksum_ok,checksum=pcall(function()
		return canonical.hex(canonical.checksum(projected,raw_sha256))
	end)
	if not checksum_ok then return diag("exact_source_checksum","source",EXPECTED_SOURCE_CHECKSUM,checksum) end
	if checksum~=EXPECTED_SOURCE_CHECKSUM then return diag("exact_source_checksum","source",EXPECTED_SOURCE_CHECKSUM,checksum) end
	return true
end

function validator.validate(source,vocabulary)
	local call_ok,accepted,failure=pcall(validate_impl,source,vocabulary,
		production_canonical,production_raw_sha256)
	if not call_ok then
		return diag("validator_exception","source","structured validation",accepted)
	end
	return accepted,failure
end

-- Plain Lua 5.1 has no engine hash. The offline harness gets a separate
-- adapter only when this module was loaded outside Luanti. It exercises the
-- same private validator and production-owned source projector, while the
-- production validate entrypoint above remains dependency-free.
if engine_core==nil then
	function validator.new_offline_test_adapter(canonical,raw_sha256)
		if type(canonical)~="table" or type(raw_sha256)~="function" then
			error("WP40 offline Stage1 test adapter dependencies missing",0)
		end
		local adapter={}
		function adapter.validate(source,vocabulary)
			local call_ok,accepted,failure=pcall(validate_impl,source,vocabulary,
				canonical,raw_sha256)
			if not call_ok then
				return diag("validator_exception","source","structured validation",accepted)
			end
			return accepted,failure
		end
		return adapter
	end
end

validator.EXPECTED_COUNTS = EXPECTED_COUNTS
validator.EXPECTED_SOURCE_CHECKSUM = EXPECTED_SOURCE_CHECKSUM

return validator
