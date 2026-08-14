-- Stage-1 validation for the ordered WP40 authored source catalog.

local validator = {}
local EXPECTED_SOURCE_CHECKSUM =
	"9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68"
local EXPECTED_POLICY_CHECKSUMS={
	logical_biome_selector="8e8146cd514ff6a8e7f086670844bb54ce4a378b3a6aced3b2f024cafc7090bd",
	primitive_evaluator="c9af10634c293342e3729b2a9c618ba9d3cc2dd85d152937045b8ed1c54cfa24",
	primitive_formulas="03365f8654bdb4ffac4af9a1123f6df2f5231bcec7bf999b859cc115cf839f8b",
	boundary_displacement="3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140",
	route_raster="2f8690642442c96345994bee6960408e4fe2f02cfd35eafdfc1b4ec7d4a6695c",
	route_profile_solver="3a0ef9ac6c0f3416e57089317cc80db4695265c54df046d6ffec605b06ce18ac",
	relief_field="21eef51446dd63a734f9ee9c0fbbd409ff7a64d827080ea896f379b42f00b200",
	landmark_masks="99535a1033607d7f0b327bbce859d2e578d8b42ddc76cc2cb8a80dbdaa385f1e",
	coastal_housing_core="58b92908c65ec089213298e2d5cf280879cfa69c6292efe9b8b8cb7b88db9fe4",
	world_partition="e5c17a5a084b0f13a5779b7c84aa823c8dae64e711020be5f46087db80a24693",
	geometry_fixture_selector="cf71fc428ff68160c364e9ce02fdf54d3abd8c88e6f08319b7cfe270928346c6",
	requester_trace="1c8bb210b53bb50bb6a661dfaaf8e3f771cc1ae2674a0a405783a6ca19dd69ff",
	geometry_extreme_selector="b983c61c6740dfea9ff7821a3bfbda0da08c3475d4965995814cb71fff53f255",
	hydrology_mask="8d52ca635a2fccd3ccc337dd11c7f37c268657b66b5eee30d550bd4183e20d27",
	route_vertical_interfaces="14f849ac48bad0bf888a46d975a73acbb34be1c34d5d51ea2648ad3ee7b1ce09",
}

local SOURCE_ARRAY_FIELDS={section_order=true,relief_profiles=true,
	mg_flags=true,mgv7_special_flags=true,flags=true,
	route_classes=true,water_classes=true,landmark_role_vocabulary=true,
	template_primitives=true,zones=true,land_edges=true,relief_junctions=true,
	junction_departures=true,
	incident_edge_ids=true,
	perimeter_attachments=true,perimeter_spans=true,bay_bank_components=true,
	endpoint_face_incidence=true,face_arcs=true,
	zone_faces=true,cycle=true,source_refs=true,authority_components=true,
		ordered_outer_components=true,edge_refs=true,route_stations=true,
	routes=true,route_interfaces=true,surface_level_controls=true,
	route_crossing_interfaces=true,
	boat_edges=true,island_landings=true,island_route_stations=true,
	island_routes=true,island_route_interfaces=true,perimeters=true,bays=true,
	bay_mouth_apertures=true,bay_closure_wings=true,junction_edge_ids=true,closure_wing_ids=true,
	islands=true,channels=true,landmarks=true,anchors=true,templates=true,
	poi_spurs=true,template_compositions=true,hydrology_profiles=true,
	hydrology_transition_profiles=true,hydrology=true,hydrology_interfaces=true,
	hard_protection_recipes=true,hard_protection=true,
	pending_static_recipes=true,pending_static_reservations=true,
	claim_exclusion_recipes=true,claim_exclusions=true,
	housing_masks=true,coastal_housing_cores=true,octaves=true,biomes=true,
	control=true,polygon=true,centreline=true,roles=true,candidates=true,
	patrol_offsets=true,socket_reservations=true,candidate_paths=true,
	containment_exclusion_ids=true,
	shore_zone_ids=true,owner_spans=true,operations=true,anchor_connection_policy=true,
	parameters=false,from_ids=true,approach_edge_ids=true,race_regions=true,
	regional_resource_keys=true,cultural_material_keys=true,
	signature_wood_keys=true,race_region_assignments=true,
	footprint_policy_ids=true,relief_ids=true,template_shape_ids=true,
	route_semantic_ids=true,water_class_ids=true,hydrology_profile_ids=true,
	protection_recipe_ids=true,exclusion_recipe_ids=true,
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

local function declared_bank_incidence_counts(face_arcs,bank_by_id)
	local counts={}
	for arc_index=1,#face_arcs do
		local components=face_arcs[arc_index].authority_components
		if not dense(components) then return {_defer=true} end
		for component_index=1,#components do
			local component=components[component_index]
			if type(component)~="table" or type(component.kind)~="string" then
				return {_defer=true}
			end
			if component.kind=="bay_bank" then
				if type(component.ref_id)~="string" then return {_defer=true} end
				counts[component.ref_id]=(counts[component.ref_id] or 0)+1
			elseif component.kind~="perimeter_span" and component.kind~="literal_arc" then
				return {_defer=true}
			end
		end
	end
	for bank_id in pairs(bank_by_id) do
		if counts[bank_id]~=1 then
			local _,failure=diag("bay_bank_component_incidence",bank_id,1,
				counts[bank_id] or 0)
			return {_failure=failure}
		end
	end
	return counts
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

local SAFE_INTEGER=9007199254740991
local function safe_nonnegative_product(a,b)
	if type(a)~="number" or type(b)~="number" or a<0 or b<0 or
		math.floor(a)~=a or math.floor(b)~=b or
		(a~=0 and b>SAFE_INTEGER/a) then return nil end
	return a*b
end

local function ceil_isqrt(value)
	if type(value)~="number" or value<0 or math.floor(value)~=value then return nil end
	local low,high=0,1
	while high<=value/high do high=high*2 end
	while low+1<high do
		local middle=math.floor((low+high)/2)
		if middle<=value/middle then low=middle else high=middle end
	end
	if low*low==value then return low end
	return low+1
end

-- Exact integer-column closure-wing predicate.  The early cross bound keeps
-- both squared products inside the source-proven Lua double integer domain.
local function point_in_closure_wing(point,wing)
	local dx,dz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
	local px,pz=point.x-wing.head.x,point.z-wing.head.z
	local length_squared=dx*dx+dz*dz
	local projection=px*dx+pz*dz
	if projection<0 or projection>=length_squared then return false end
	local area=dx*pz-dz*px
	local root=ceil_isqrt(length_squared)
	local bound=wing.head_half_width*root
	if math.abs(area)>=bound then return false,area end
	local remaining=length_squared-projection
	local area_squared=safe_nonnegative_product(math.abs(area),math.abs(area))
	local left=area_squared and safe_nonnegative_product(area_squared,length_squared)
	local radius_squared=safe_nonnegative_product(wing.head_half_width,
		wing.head_half_width)
	local remaining_squared=safe_nonnegative_product(remaining,remaining)
	local right=radius_squared and remaining_squared and
		safe_nonnegative_product(radius_squared,remaining_squared)
	if not left or not right then return nil,area end
	return left<right,area
end

-- Sole exact base-bay predicate. Segment interpolation stays rational: no
-- projected Q16 point, rounded width, division, or floating comparison enters
-- the authority decision. Strict equality belongs to dry land.
local function point_in_base_bay(point,bay)
	for segment_index=1,#bay.centreline-1 do
		local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
		local vx,vz=b.x-a.x,b.z-a.z
		local px,pz=point.x-a.x,point.z-a.z
		local length_squared=vx*vx+vz*vz
		local projection=px*vx+pz*vz
		if projection<=0 then
			if px*px+pz*pz<a.half_width*a.half_width then return true end
		elseif projection>=length_squared then
			local ex,ez=point.x-b.x,point.z-b.z
			if ex*ex+ez*ez<b.half_width*b.half_width then return true end
		else
			local area=vx*pz-vz*px
			local root=ceil_isqrt(length_squared)
			local max_radius=math.max(a.half_width,b.half_width)
			if math.abs(area)<max_radius*root then
				local width_numerator=a.half_width*(length_squared-projection)+
					b.half_width*projection
				local area_squared=safe_nonnegative_product(math.abs(area),math.abs(area))
				local left=area_squared and
					safe_nonnegative_product(area_squared,length_squared)
				local right=safe_nonnegative_product(width_numerator,width_numerator)
				if not left or not right then return nil end
				if left<right then return true end
			end
		end
	end
	return false
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

-- Independent zero-displacement proof for the finite topology-ceiling scan.
-- This deliberately owns a small Stage-1 copy of the frozen route-raster
-- arithmetic: a continuous control polygon can be simple while its integer
-- raster repeats a station or crosses both diagonals of one cell.
local function raster_point_less(a,b)
	return a.x<b.x or a.x==b.x and a.z<b.z
end

local function reverse_points(points)
	local result={}
	for i=#points,1,-1 do result[#result+1]=points[i] end
	return result
end

local function base_raster_segment(a,b)
	if a.x==b.x and a.z==b.z then return nil,"zero control segment" end
	local low,high,authored_reverse=a,b,false
	if raster_point_less(high,low) then
		low,high,authored_reverse=high,low,true
	end
	local dx,dz=high.x-low.x,high.z-low.z
	local absolute_x,absolute_z=math.abs(dx),math.abs(dz)
	local x_major=absolute_x>=absolute_z
	local major=x_major and absolute_x or absolute_z
	local minor=x_major and absolute_z or absolute_x
	local major_step=x_major and (dx<0 and -1 or 1) or
		(dz<0 and -1 or 1)
	local minor_step=x_major and (dz<0 and -1 or 1) or
		(dx<0 and -1 or 1)
	local x,z=low.x,low.z
	local error_value=2*minor-major
	local points={}
	for step=0,major do
		points[#points+1]={x=x,z=z}
		if step==major then break end
		if x_major then x=x+major_step else z=z+major_step end
		if error_value>=0 then
			if x_major then z=z+minor_step else x=x+minor_step end
			error_value=error_value-2*major
		end
		error_value=error_value+2*minor
	end
	return authored_reverse and reverse_points(points) or points
end

local function base_raster_valid(row,label,points,closed,envelope)
	local result={}
	local count=#points
	if closed and count>1 and points[1].x==points[count].x and
			points[1].z==points[count].z then count=count-1 end
	local segment_count=closed and count or count-1
	for segment_index=1,segment_count do
		local next_index=segment_index==count and 1 or segment_index+1
		local part,reason=base_raster_segment(points[segment_index],points[next_index])
		if not part then return diag("base_raster_zero_segment",label,
			"nonzero control segment",reason) end
		for station_index=1,#part do local point=part[station_index]
			if #result==0 or result[#result].x~=point.x or result[#result].z~=point.z then
				result[#result+1]=point
			end
		end
	end
	if closed and #result>1 and result[1].x==result[#result].x and
			result[1].z==result[#result].z then table.remove(result) end
	local station_seen,diagonal_cells={},{}
	for index=1,#result do local point=result[index]
		local station_key=point.x..":"..point.z
		if station_seen[station_key] then return diag("base_raster_repeat",label,
			"unique zero-displacement stations",
			station_seen[station_key]..":"..index..":"..station_key) end
		station_seen[station_key]=index
		if envelope and not envelope(point) then return diag("base_raster_envelope",label,
			"zero-displacement station inside record envelope",station_key) end
	end
	local edge_count=closed and #result or #result-1
	for index=1,edge_count do
		local following=index==#result and 1 or index+1
		local a,b=result[index],result[following]
		local dx,dz=b.x-a.x,b.z-a.z
		if math.max(math.abs(dx),math.abs(dz))~=1 then
			return diag("base_raster_connectivity",label,"eight-connected",index)
		end
		if math.abs(dx)==1 and math.abs(dz)==1 then
			local cell_key=math.min(a.x,b.x)..":"..math.min(a.z,b.z)
			local slope=dx==dz and 1 or -1
			if diagonal_cells[cell_key] and diagonal_cells[cell_key]~=slope then
				return diag("base_raster_x_cross",label,
					"at most one diagonal slope per integer cell",cell_key)
			end
			diagonal_cells[cell_key]=slope
		end
	end
	if closed then
		local polygon={}
		for index=1,#result do polygon[index]=result[index] end
		polygon[#polygon+1]=result[1]
		local actual=orientation(polygon)
		if actual~=row.orientation then return diag("base_raster_orientation",label,
			row.orientation,actual) end
	end
	return true,nil,result
end

local EXPECTED_COUNTS = {
	{"zones",38},{"land_edges",61},{"relief_junctions",38},{"junction_departures",4},
	{"perimeter_attachments",8},
	{"perimeter_spans",18},{"bay_bank_components",20},{"face_arcs",34},{"zone_faces",38},
	{"route_stations",68},{"routes",57},{"route_interfaces",171},
	{"surface_level_controls",162},
	{"route_crossing_interfaces",7},{"boat_edges",4},{"island_landings",4},
	{"island_route_stations",10},{"island_routes",8},{"island_route_interfaces",16},{"landmarks",70},
	{"anchors",100},{"perimeters",3},{"bays",4},{"bay_mouth_apertures",4},{"islands",2},
	{"bay_closure_wings",8},
	{"channels",2},{"relief_profiles",6},{"route_classes",3},
	{"water_classes",5},{"template_primitives",9},{"templates",17},
	{"poi_spurs",74},{"template_compositions",18},
	{"hydrology_profiles",11},{"hydrology_transition_profiles",6},
	{"hydrology",25},
	{"hydrology_interfaces",10},{"housing_masks",10},
	{"hard_protection_recipes",3},{"hard_protection",36},
	{"pending_static_recipes",3},{"pending_static_reservations",86},
	{"claim_exclusion_recipes",6},{"claim_exclusions",540},
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

local FIXED_CLOSURE_EXPECTED={
	perimeter_elandor_mainland={"land_048","land_047","land_046",
		"land_045","land_044","land_043"},
	perimeter_kragmar_mainland={"land_054","land_053","land_052",
		"land_051","land_050","land_049"},
}

local function same_point_sequence(a,b)
	if #a~=#b then return false end
	for point_index=1,#a do
		if a[point_index].x~=b[point_index].x or
				a[point_index].z~=b[point_index].z then return false end
	end
	return true
end

local function validate_fixed_closure(row,row_index,edge_by_id)
	local expected=FIXED_CLOSURE_EXPECTED[row.id]
	local closure=row.r7_fixed_closure
	if not expected then
		if closure~=nil then return diag("perimeter_fixed_closure_scope",row.id,
			"closure absent outside two planned mainlands","present") end
		return true
	end
	local closure_path="perimeters["..row_index.."].r7_fixed_closure"
	local fields_ok,fields_failure=closed_fields(closure,closure_path,
		{"kind","edge_refs"},"perimeter_fixed_closure_fields")
	if not fields_ok then return nil,fields_failure end
	if closure.kind~="fixed_holy_land_edge_union" or
			not dense(closure.edge_refs) or #closure.edge_refs~=6 then
		return diag("perimeter_fixed_closure_contract",row.id,
			"one dense six-edge fixed Holy union","invalid")
	end
	local union,station_seen,edge_seen={},{},{}
	for ref_index=1,#closure.edge_refs do local ref=closure.edge_refs[ref_index]
		fields_ok,fields_failure=closed_fields(ref,
			closure_path..".edge_refs["..ref_index.."]",
			{"edge_id","direction"},"perimeter_fixed_closure_ref_fields")
		if not fields_ok then return nil,fields_failure end
		if ref.edge_id~=expected[ref_index] or ref.direction~="reverse" or
				edge_seen[ref.edge_id] then
			return diag("perimeter_fixed_closure_ref",row.id,
				expected[ref_index]..":reverse",tostring(ref.edge_id)..":"..
					tostring(ref.direction))
		end
		edge_seen[ref.edge_id]=true
		local edge=edge_by_id[ref.edge_id]
		if not edge or edge.max_displacement~=0 then
			return diag("perimeter_fixed_closure_fixed_edge",row.id,
				"known max-displacement-zero land edge",ref.edge_id)
		end
		local edge_ok,edge_failure,part=base_raster_valid(edge,ref.edge_id,
			edge.control,false,nil)
		if not edge_ok then return nil,edge_failure end
		part=reverse_points(part)
		if #union>0 and (union[#union].x~=part[1].x or
				union[#union].z~=part[1].z) then
			return diag("perimeter_fixed_closure_join",row.id,
				"consecutive byte-identical shared endpoint",ref_index)
		end
		for point_index=1,#part do local point=part[point_index]
			if #union==0 or union[#union].x~=point.x or union[#union].z~=point.z then
				local station_key=point.x..":"..point.z
				if station_seen[station_key] then
					return diag("perimeter_fixed_closure_repeat",row.id,
						"unique union station outside consecutive joins",station_key)
				end
				station_seen[station_key]=true
				union[#union+1]=point
			end
		end
	end
	local matches={}
	for source_segment=1,#row.polygon-1 do
		local part,reason=base_raster_segment(row.polygon[source_segment],
			row.polygon[source_segment+1])
		if not part then return diag("perimeter_fixed_closure_geometry",row.id,
			"nonzero authored source segment",reason) end
		if same_point_sequence(part,union) then matches[#matches+1]=source_segment end
	end
	if #matches~=1 or #row.polygon-1~=27 then
		return diag("perimeter_fixed_closure_geometry",row.id,
			"unique full union-byte-equal derived closure and exactly 26 other source segments",
			#matches..":"..tostring(matches[1])..":"..(#row.polygon-1))
	end
	if #row.ordered_outer_components<6 then
		return diag("perimeter_fixed_closure_projection",row.id,
			"six projected ordered outer components","missing")
	end
	local suffix_first=#row.ordered_outer_components-5
	for ref_index=1,#closure.edge_refs do
		local ref=closure.edge_refs[ref_index]
		local projected=ref.edge_id..":"..ref.direction
		if row.ordered_outer_components[suffix_first+ref_index-1]~=projected then
			return diag("perimeter_fixed_closure_projection",row.id,projected,
				tostring(row.ordered_outer_components[suffix_first+ref_index-1]))
		end
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
		"geometry_policies","relief_profiles","route_classes",
		"water_classes","landmark_role_vocabulary","template_primitives",
		"zones","land_edges","relief_junctions","junction_departures",
		"perimeter_attachments","perimeter_spans",
		"bay_bank_components","face_arcs","zone_faces",
		"route_stations","routes","route_interfaces","surface_level_controls",
		"route_crossing_interfaces","boat_edges","island_landings",
		"island_route_stations","island_routes","island_route_interfaces",
		"perimeters","bays","bay_mouth_apertures","bay_closure_wings",
		"islands","channels","landmarks","anchors","templates",
		"poi_spurs","template_compositions","hydrology_profiles",
		"hydrology_transition_profiles","hydrology","hydrology_interfaces",
		"hard_protection_recipes","hard_protection",
		"pending_static_recipes","pending_static_reservations",
		"claim_exclusion_recipes","claim_exclusions",
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
	local zone_by_id={}
	for i=1,#source.zones do zone_by_id[source.zones[i].id]=source.zones[i] end
	for _, family in ipairs({"relief_profiles","route_classes","water_classes",
			"template_primitives","perimeter_attachments","perimeter_spans",
			"bay_bank_components",
			"relief_junctions","junction_departures",
			"face_arcs","zone_faces","perimeters","bays","bay_mouth_apertures",
			"bay_closure_wings","islands","channels",
			"landmarks","anchors","templates","template_compositions",
			"poi_spurs","hydrology_profiles","hydrology_transition_profiles",
			"hydrology","hydrology_interfaces","route_stations","routes","route_interfaces",
			"surface_level_controls",
			"route_crossing_interfaces","island_landings","island_route_stations",
			"island_routes","island_route_interfaces","hard_protection_recipes",
			"hard_protection","pending_static_recipes","pending_static_reservations",
			"claim_exclusion_recipes","claim_exclusions","housing_masks",
			"coastal_housing_cores"}) do
		ok, failure = unique_ordered(source[family], family)
		if not ok then return nil, failure end
	end
	local relief_ids,relief_by_id = {},{}
	local relief_expected={
		wetland_delta={2,24},lowland={8,56},rolling_hills={24,96},
		plateau={56,144},highland={96,224},mountain={160,360},
	}
	for i = 1, #source.relief_profiles do
		local profile=source.relief_profiles[i]
		local expected=relief_expected[profile.id]
		if not expected or profile.min_above_water~=expected[1] or
				profile.max_above_water~=expected[2] then
			return diag("relief_profile_band",profile.id,
				expected and expected[1]..".."..expected[2] or "known profile",
				tostring(profile.min_above_water)..".."..tostring(profile.max_above_water))
		end
		local delta=profile.max_above_water-profile.min_above_water
		if delta<0 or (2*65536)*delta>9007199254740991 then
			return diag("relief_raw_height_product",profile.id,
				"nonnegative exact delta product","unsafe")
		end
		for _,noise_q in ipairs({-1000000000,-131072,-65537,-65536,-65535,0,
			65535,65536,65537,131072,1000000000}) do
			local clamped_noise=math.max(-65536,math.min(65536,noise_q))
			local mapped=profile.min_above_water+
				math.floor((clamped_noise+65536)*delta/(2*65536))
			if mapped<profile.min_above_water or mapped>profile.max_above_water or
					(noise_q<=-65536 and mapped~=profile.min_above_water) or
					(noise_q==0 and mapped~=
						profile.min_above_water+math.floor(delta/2)) or
					(noise_q>=65536 and mapped~=profile.max_above_water) then
				return diag("relief_raw_height_kat",profile.id,
					"inclusive min/max exact mapping",mapped)
			end
		end
		relief_ids[profile.id] = true
		relief_by_id[profile.id]=profile
	end
	if 40+math.floor((0+65536)*(40-40)/(2*65536))~=40 then
		return diag("relief_raw_height_kat","singleton",40,"changed")
	end
	local policies=source.geometry_policies
	if type(policies)~="table" or policies.id~="geometry_policies" or
			policies.schema~="grug_wp40_geometry_source_v1" or
			type(policies.template_footprint)~="table" or
			policies.template_footprint.id~="centered_half_open_square_v1" or
			policies.template_footprint.interval_rule~="centered_half_open_total_width" or
			type(policies.relief_composition)~="table" or
			policies.relief_composition.landmark_overlap_rule~=
				"highest_priority_replace_profile" or
			policies.relief_composition.landmark_priority_order~=
				"greater_integer_priority_wins" or
			policies.relief_composition.landmark_priority_tie~="reject" or
			not dense(policies.relief_composition.evaluation_order) or
			#policies.relief_composition.evaluation_order~=3 or
			policies.relief_composition.evaluation_order[1]~=
				"raw_owning_zone_profile" or
			policies.relief_composition.evaluation_order[2]~=
				"highest_priority_landmark_replacement_and_64_node_blend" or
			policies.relief_composition.evaluation_order[3]~=
				"shared_edge_G_and_96_node_blend" or
			type(policies.surface_level_interpolation)~="table" or
			policies.surface_level_interpolation.id~="inverse_distance_squared_q16_v1" or
			policies.surface_level_interpolation.schema_version~=1 or
			policies.surface_level_interpolation.control_selection~="all_controls_owned_by_zone" or
			policies.surface_level_interpolation.distance_metric~="squared_euclidean_xz" or
			policies.surface_level_interpolation.exact_control_rule~=
				"exact_position_level_or_reject_conflict" or
			policies.surface_level_interpolation.weight_rule~=
				"floor_q_squared_div_distance_squared" or
			policies.surface_level_interpolation.gcd_reduction~=
				"reduce_weighted_sum_before_multiply" or
			policies.surface_level_interpolation.max_coordinate_delta~=8192 or
			policies.surface_level_interpolation.max_control_count~=16 or
			policies.surface_level_interpolation.overflow_rule~=
				"reject_outside_safe_double_integer_range" or
			policies.surface_level_interpolation.weighted_rounding~=
				"nearest_integer_ties_lower" or
			policies.surface_level_interpolation.edge_vertex_rule~=
				"owning_face_then_lower_zone_numeric_tie" or
			policies.surface_level_interpolation.outside_rule~="reject_outside_owning_face" or
			policies.surface_level_interpolation.clamp_rule~="published_zone_level_bracket" then
		return diag("geometry_policy_contract","geometry_policies",
			"closed footprint/H-overlap/surface interpolation authority","invalid")
	end
	local biome_selector=policies.logical_biome_selector
	ok,failure=closed_fields(biome_selector,
		"geometry_policies.logical_biome_selector",{
			"id","schema_version","coordinate_space","seed_input","hash_api",
			"hash_schema","hash_domain","hash_feature_id","hash_coordinates",
			"hash_candidate_index","hash_lanes","cell_size","cell_index_rule",
			"candidate_neighborhood","site_offset_min","site_offset_span",
			"site_offset_rule","distance_rule","nearest_tie_rule",
			"palette_roll_rule","palette_mapping_rule","ownership_rule",
			"arithmetic_rule","share_audit_domain",
			"share_audit_tolerance_percentage_points"},
		"logical_biome_selector_fields")
	if not ok then return nil,failure end
	ok,failure=closed_fields(biome_selector.hash_lanes,
		"geometry_policies.logical_biome_selector.hash_lanes",
		{"site_x","site_z","palette"},"logical_biome_selector_fields")
	if not ok then return nil,failure end
	if biome_selector.id~="zone_palette_jittered_voronoi_t1_hash_v1" or
			biome_selector.schema_version~=1 or
			biome_selector.coordinate_space~="world_xz_integer_columns" or
			biome_selector.seed_input~="t1_canonical_unsigned_u64_decimal_text" or
			biome_selector.hash_api~="deterministic.new_hash" or
			biome_selector.hash_schema~="grug_wp40_geometry_source_v1" or
			biome_selector.hash_domain~="logical_biome_patch_v1" or
			biome_selector.hash_feature_id~="" or
			biome_selector.hash_coordinates~="signed_cell_x_z" or
			biome_selector.hash_candidate_index~=0 or
			biome_selector.hash_lanes.site_x~=0 or
			biome_selector.hash_lanes.site_z~=1 or
			biome_selector.hash_lanes.palette~=2 or
			biome_selector.cell_size~=192 or
			biome_selector.cell_index_rule~=
				"mathematical_floor_coordinate_div_cell_size" or
			biome_selector.candidate_neighborhood~=
				"own_and_eight_adjacent_cells" or
			biome_selector.site_offset_min~=32 or
			biome_selector.site_offset_span~=128 or
			biome_selector.site_offset_rule~=
				"min_plus_t1_unbiased_range_lane" or
			biome_selector.distance_rule~=
				"squared_euclidean_integer_world_xz" or
			biome_selector.nearest_tie_rule~=
				"lowest_cell_x_then_lowest_cell_z" or
			biome_selector.palette_roll_rule~=
				"t1_unbiased_range_lane_size_100" or
			biome_selector.palette_mapping_rule~=
				"first_authored_cumulative_share_strictly_greater_than_roll" or
			biome_selector.ownership_rule~=
				"resolve_zone_first_and_use_only_owning_zone_palette" or
			biome_selector.arithmetic_rule~=
				"t1_safe_integer_and_floor_division" or
			biome_selector.share_audit_domain~=
				"ordinary_land_columns_after_fixed_roads_and_structures" or
			biome_selector.share_audit_tolerance_percentage_points~=5 then
		return diag("logical_biome_selector_contract",
			"geometry_policies.logical_biome_selector",
			"closed coherent full-seed zone-palette selector","invalid")
	end
	local generic_policy_ids={
		primitive_evaluator="template_primitive_q16_composition_v1",
		primitive_formulas="template_primitive_formulas_v1",
		boundary_displacement="shared_polyline_normal_displacement_t1_hash_v3",
		route_raster="symmetric_bresenham_8_connected_stations_v1",
		route_profile_solver="route_profile_dynamic_program_v1",
		relief_field="shared_edge_gate_relief_q16_v1",
		landmark_masks="landmark_masks_and_replacement_blend_v1",
		coastal_housing_core="displaced_coast_interval_inward_core_v1",
		world_partition="face_partition_with_bay_capsule_water_v2",
		geometry_fixture_selector="geometry_microcorpus_selector_v1",
		requester_trace="requester_trace_manifest_v1",
		geometry_extreme_selector="geometry_extreme_seed_selector_v1",
		hydrology_mask="analytic_reach_round_union_sealed_v1",
		route_vertical_interfaces="route_water_vertical_interfaces_v1",
	}
	local generic_policy_versions={boundary_displacement=3,world_partition=2}
	for _,key in ipairs({"primitive_evaluator","primitive_formulas",
			"boundary_displacement","route_raster","route_profile_solver",
			"relief_field","landmark_masks","coastal_housing_core",
			"world_partition","geometry_fixture_selector","requester_trace",
			"geometry_extreme_selector",
			"hydrology_mask","route_vertical_interfaces"}) do
		if type(policies[key])~="table" or policies[key].id~=generic_policy_ids[key] or
				policies[key].schema_version~=(generic_policy_versions[key] or 1) then
			return diag("generic_geometry_policy_contract","geometry_policies."..key,
				generic_policy_ids[key],"invalid")
		end
	end
	local vertical=policies.route_vertical_interfaces
	if type(vertical.bridge)~="table" or
			vertical.bridge.id~="bridge_clearance_v1" or
			vertical.bridge.minimum_clearance_nodes~=3 or
			type(vertical.ford)~="table" or vertical.ford.id~="ford_bed_v1" or
			type(vertical.causeway)~="table" or
			vertical.causeway.id~="causeway_culvert_v1" or
			type(vertical.tunnel)~="table" or
			vertical.tunnel.id~="tunnel_lumen_v1" or
			vertical.tunnel.clear_nodes_above_road~=5 or
			vertical.tunnel.lining_thickness~=2 or
			vertical.tunnel.portal_length~=16 then
		return diag("route_vertical_interface_policy","geometry_policies.route_vertical_interfaces",
			"closed bridge/ford/causeway/tunnel vertical rules","invalid")
	end
	if policies.relief_field.boundary_blend_width~=
			policies.relief_composition.boundary_blend_width or
			policies.relief_field.raw_height_equation_id~=
				"relief_noise_to_inclusive_height_delta_floor_v2" or
			policies.relief_field.raw_noise_input~=
				"clamp_noise_q_to_minus_Q_through_plus_Q_before_height_product" or
			policies.relief_field.raw_height_delta~=
				"max_above_water_minus_min_above_water_not_inclusive_value_count" or
			policies.relief_field.raw_height_rule~=
				"water_level_plus_min_plus_floor_div_clamped_noise_plus_Q_times_delta_by_two_Q" or
			policies.relief_field.raw_height_product_guard~=
				"clamped_noise_plus_Q_times_delta_at_most_2_pow_53_minus_1" or
			policies.relief_field.gate_lane~=2 or
			policies.relief_field.gate_identity_rule~=
				"one_G_per_shared_edge_station_consumed_by_both_incident_faces" or
			policies.relief_field.junction_policy_id~=
				"shared_relief_junction_gate_v1" or
			policies.relief_field.junction_source~=
				"one_checksum_covered_record_per_multi_edge_endpoint" or
			policies.relief_field.junction_seed_rule~=
				"intersection_band_uses_domain_relief_junction_v1_feature_junction_x_z_coordinates_x_z_candidate_zero_lane_two_full_seed_unbiased_singleton_midpoint_uses_no_hash" or
			policies.relief_field.junction_empty_rule~=
				"lower_midpoint_floor_max_incident_min_plus_min_incident_max_div_two" or
			policies.relief_field.junction_transition_distance~=96 or
			policies.relief_field.junction_transition_metric~=
				"canonical_incident_edge_raster_station_steps_from_endpoint" or
			policies.relief_field.junction_edge_gate_rule~=
				"qlerp_junction_G_to_ordinary_edge_G_by_smootherstep_clamped_station_steps_div_96" or
			policies.relief_field.junction_candidate_weight~=
				"one_minus_smootherstep_clamped_exact_edge_distance_div_96" or
			policies.relief_field.junction_candidate_edge_dedup~=
				"one_candidate_per_unique_land_edge_from_ordinary_nearest_segment_and_projection_tie_never_one_pair_per_junction_endpoint" or
			policies.relief_field.junction_projection_station~=
				"on_selected_nearest_segment_exact_rational_nearest_canonical_raster_station_to_projection_lower_global_station_index_tie" or
			policies.relief_field.junction_endpoint_support~=
				"select_start_if_zero_based_global_station_s_less_than_96_else_end_if_total_steps_minus_s_less_than_96_else_no_local_junction" or
			policies.relief_field.junction_raw_endpoint_minimum_chebyshev~=400 or
			policies.relief_field.junction_undisplaced_attachment_minimum_station_steps~=297 or
			policies.relief_field.junction_final_edge_minimum_station_steps~=192 or
			policies.relief_field.junction_endpoint_support_proof~=
				"stage1_raw_control_endpoint_chebyshev_minimum_400_and_undisplaced_attachment_joint_raster_minimum_297_steps_are_baseline_KATs_only_stage2_measures_each_final_raster_and_hard_rejects_station_steps_below_192_before_endpoint_support" or
			policies.relief_field.junction_final_edge_short_rule~=
				"stage2_hard_reject_final_edge_raster_station_steps_less_than_192" or
			policies.relief_field.junction_unsupported_edge_gate~=
				"ordinary_native_edge_G_without_separate_far_endpoint_junction_candidate" or
			policies.relief_field.junction_candidate_eligibility~=
				"strictly_positive_weight_only_all_quantized_zero_weights_excluded_including_distance_96" or
			policies.relief_field.junction_candidate_aggregation~=
				"ordered_checked_Q16_weighted_sum_all_positive_weight_incident_candidates" or
			policies.relief_field.junction_candidate_average~=
				"t1_qdiv_ordered_sum_qmul_effective_gate_q_and_weight_q_by_ordered_sum_weight_q" or
			policies.relief_field.junction_zero_weight_rule~=
				"return_post_landmark_H_exactly_without_division" or
			policies.relief_field.junction_boundary_strength~=
				"maximum_candidate_weight_q16" or
			policies.relief_field.junction_final_rule~=
				"qlerp_ordinary_relief_to_weighted_junction_candidates_by_boundary_strength" or
			policies.relief_field.junction_candidate_order~=
				"unique_land_edge_numeric_id" or
			policies.relief_field.junction_band_exception~=
				"empty_intersection_midpoint_is_bounded_shared_transition_and_may_be_outside_incident_raw_profile_band" or
			policies.relief_field.nearest_edge_distance~=
				"minimum_exact_squared_q16_distance_to_closed_displaced_edge_segment" or
			policies.relief_field.nearest_edge_projection~=
				"clamped_dot_over_segment_length_squared_q16_half_away_from_zero" then
		return diag("relief_shared_gate_policy","geometry_policies.relief_field",
			"one common 96-node G field for both incident faces","invalid")
	end
	if policies.landmark_masks.blend_width~=
			policies.relief_composition.secondary_blend_width or
			policies.landmark_masks.priority_tie_rule~="reject" or
			policies.landmark_masks.replacement_rule~=
				"highest_priority_replace_profile_height" or
			policies.landmark_masks.replacement_noise_domain~=
				"landmark_record_noise_domain" or
			policies.landmark_masks.replacement_profile~=
				"landmark_secondary_relief_id_ordered_octaves_and_inclusive_band" or
			policies.landmark_masks.replacement_hash_binding~=
				"feature_empty_candidate_zero_with_landmark_noise_domain" or
			policies.landmark_masks.distance_unit~=
				"all_shape_signed_distances_are_world_node_Q16" or
			policies.landmark_masks.ellipse_signed_distance~=
				"u_q16=qdiv(dx_Q,radius_x_Q);v_q16=qdiv(dz_Q,radius_z_Q);rho_q16=isqrt_Q(qmul(u,u)+qmul(v,v));sd_node_q16=qmul(rho_q16-Q,min_radius_Q)" or
			policies.landmark_masks.blend_rule~=
				"qlerp_previous_H_to_replacement_H_by_Q_minus_smootherstep(max_zero_sd_node_q16_div_64Q)" or
			policies.landmark_masks.blend_endpoints~=
				"replacement_at_inside_and_boundary_previous_at_64_nodes_outside" then
		return diag("landmark_mask_policy","geometry_policies.landmark_masks",
			"closed shapes and 64-node priority replacement blend","invalid")
	end
	local coastal_policy=policies.coastal_housing_core
	if coastal_policy.frontage_minimum~=600 or coastal_policy.inland_depth~=300 or
			coastal_policy.relief_limit~=12 or
			coastal_policy.frontage_distance~=
				"sum_integer_station_euclidean_q16_in_interval" or
			coastal_policy.inward_side_rule~="authored_face_arc_zone_inside_side" or
			coastal_policy.endpoint_cap_rule~=
				"closed_half_discs_radius_inland_depth_at_both_interval_endpoints" then
		return diag("coastal_core_policy","geometry_policies.coastal_housing_core",
			"exact displaced coast interval/inward 600x300 core policy","invalid")
	end
	local partition=policies.world_partition
	if not dense(partition.classification_precedence) or
			#partition.classification_precedence~=4 or
			partition.classification_precedence[1]~=
				"planned_base_bay_water_in_strict_mainland_interior_or_own_mouth_aperture_equality_then_closure_wing_water_in_strict_mainland_interior_only" or
			partition.classification_precedence[2]~=
				"mainland_island_or_fixed_holy_land_strict_interior_or_remaining_perimeter_equality_owner" or
			partition.classification_precedence[3]~=
				"strict_exterior_closed_dragon_channel_including_own_polygon_boundary" or
			partition.classification_precedence[4]~=
				"strict_exterior_coastal_shelf_or_deep_ocean" or
			partition.strict_exterior_rule~=
				"outside_every_final_mainland_island_and_fixed_holy_grounds_closed_footprint_after_all_planned_water_and_dry_land_equality_resolution" or
			partition.holy_land_authority~=
				"constants_holy_grounds_closed_rectangle_and_its_four_zone_face_partition_including_rectangle_equality" or
			partition.channel_policy_id~=
				"strict_exterior_closed_integer_polygon_channel_v1" or
			partition.channel_membership~=
				"nonzero_integer_winding_or_exact_channel_segment_equality" or
			partition.channel_boundary_rule~=
				"channel_polygon_boundary_is_included_only_when_point_is_already_strict_exterior" or
			partition.channel_precedence_rule~=
				"never_preempts_mainland_island_or_fixed_holy_interior_perimeter_aperture_base_bay_or_closure_wing_equality" or
			partition.coast_source_policy_id~=
				"exact_rational_nearest_allowed_outer_coast_component_v1" or
			partition.coast_source_role~=
				"dressing_and_policy_inheritance_only_never_zone_membership_race_region_territory_or_adjacency" or
			not dense(partition.coast_source_allowed_component_ids) or
			#partition.coast_source_allowed_component_ids~=22 or
			partition.coast_source_allowed_component_ids[19]~=
				"face_arc:gravesalt:holy_west" or
			partition.coast_source_allowed_component_ids[20]~=
				"face_arc:skyglass:holy_east" or
			partition.coast_source_allowed_component_ids[21]~=
				"face_arc:wyrmglass:island" or
			partition.coast_source_allowed_component_ids[22]~=
				"face_arc:stormscale:island" or
			partition.coast_source_component_owner~=
				"compiled_perimeter_span_zone_id_or_compiled_outer_coast_face_arc_zone_id_including_fixed_holy_and_island_arcs" or
			partition.coast_source_segment_distance~=
				"for_projection_N_less_equal_zero_endpoint_A_squared_distance_over_one_N_greater_equal_L_endpoint_B_else_cross_C_squared_over_L" or
			partition.coast_source_minimum_rule~=
				"collect_every_exact_minimum_using_gcd_reduced_positive_rational_cross_multiplication_before_ownership_ties" or
			partition.coast_source_tie_rule~=
				"lower_zone_numeric_id_then_stable_component_id_then_zero_based_compiled_component_segment_index" or
			partition.coast_source_query_domain~=
				"compiled_interesting_extent_only_nil_outside" or
			partition.coast_source_max_coordinate_delta~=8192 or
			partition.coast_source_max_compiled_segment_delta~=1 or
			partition.coast_source_safe_bounds~=
				"endpoint_distance_squared_at_most_134217728_cross_squared_at_most_268435456_reduced_compare_product_at_most_536870912" or
			partition.bay_mask_authority~=
				"unchanged_four_sample_round_capsule_union_then_two_literal_head_closure_wings" or
			partition.bay_base_predicate_id~=
				"strict_rational_variable_width_capsule_union_v1" or
			partition.bay_base_terms~=
				"v_equals_B_minus_A_L_equals_dot_v_v_N_equals_dot_P_minus_A_v_C_equals_cross_v_P_minus_A_width_num_equals_rA_times_L_minus_N_plus_rB_times_N" or
			partition.bay_base_segment_membership~=
				"zero_strictly_less_N_and_N_strictly_less_L_and_C_squared_times_L_strictly_less_than_width_num_squared" or
			partition.bay_base_cap_membership~=
				"N_less_equal_zero_uses_strict_squared_distance_to_A_less_than_rA_squared_N_greater_equal_L_uses_B_and_rB" or
			partition.bay_base_early_reject~=
				"for_segment_body_absolute_C_greater_equal_max_r_times_ceil_isqrt_L_is_outside_before_products" or
			partition.bay_base_product_guard~=
				"each_segment_max_r_squared_times_L_squared_and_guarded_cross_bound_squared_times_L_at_most_2_pow_53_minus_1" or
			partition.bay_base_arithmetic~=
				"exact_safe_integer_products_only_no_q16_projection_width_rounding_or_float_division" or
			partition.bay_displacement_lane~=0 or
			partition.bay_displacement_symmetry~=
				"one_radius_delta_applied_equally_to_both_banks_unchanged_centreline" or
			partition.bay_displacement_projection_station~=
				"minimum_exact_squared_euclidean_distance_to_canonical_stations_of_evaluated_authored_segment_lower_canonical_station_index_tie" or
			partition.bay_displacement_projection_kat~=
				"bay_elandor_west_segment_1_point_minus1376_minus2846_selects_zero_based_station_2_minus980_minus2938_not_parametric_round_station_1" or
			partition.bay_displacement_source~=
				"bay_record_noise_domain_and_max_displacement" or
			partition.bay_displacement_hash~=
				"deterministic.new_hash_grug_wp40_geometry_source_v1_empty_feature_candidate_zero" or
			partition.bay_displacement_noise~=
				"ordered_two_octave_t1_value_noise_q16_sum_clamped_minus_Q_to_plus_Q_at_selected_station" or
			not dense(partition.bay_displacement_octave_periods) or
			#partition.bay_displacement_octave_periods~=2 or
			partition.bay_displacement_octave_periods[1]~=256 or
			partition.bay_displacement_octave_periods[2]~=512 or
			not dense(partition.bay_displacement_octave_hash_lanes) or
			#partition.bay_displacement_octave_hash_lanes~=2 or
			partition.bay_displacement_octave_hash_lanes[1]~=0 or
			partition.bay_displacement_octave_hash_lanes[2]~=1 or
			not dense(partition.bay_displacement_octave_amplitudes) or
			#partition.bay_displacement_octave_amplitudes~=2 or
			partition.bay_displacement_octave_amplitudes[1].numerator~=2 or
			partition.bay_displacement_octave_amplitudes[1].denominator~=3 or
			partition.bay_displacement_octave_amplitudes[2].numerator~=1 or
			partition.bay_displacement_octave_amplitudes[2].denominator~=3 or
			partition.bay_displacement_taper_metric~=
				"canonical_segment_station_steps_to_nearest_authored_sample" or
			partition.bay_displacement_taper~=
				"smootherstep_clamped_min_station_steps_from_segment_ends_div_96_zero_at_every_sample" or
			partition.bay_displacement_delta_rule~=
				"delta_nodes_equals_qround_qmul_qmul_noise_q_max_displacement_times_Q_taper_q" or
			partition.bay_displacement_exact_body~=
				"effective_width_num_equals_base_width_num_plus_delta_nodes_times_L_then_C_squared_times_L_strictly_less_effective_width_num_squared" or
			partition.bay_displacement_product_guard~=
				"effective_width_square_max_4243584391840000_actual_guarded_cross_square_times_L_max_4251571423760000_and_conservative_early_cross_bound_4251754341463400_all_below_2_pow_53_minus_1" or
			partition.bay_displacement_lanes~=nil or
			partition.bay_displacement_width_rule~=nil or
			partition.bay_mask_membership~=
				"strict_rational_variable_width_capsule_union_v1" or
			partition.bay_boundary_tie~=
				"analytic_bank_and_cap_equality_belongs_to_adjacent_dry_face" or
			partition.bay_owner_projection_segment~=
				"minimum_exact_rational_segment_distance_compare_cross_squared_over_L_with_caps" or
			partition.bay_owner_distance_compare~=
				"reduce_cross_squared_times_other_L_by_gcd_before_safe_product_compare_caps_use_squared_integer_distance" or
			partition.bay_owner_side_rule~=
				"signed_integer_cross_C_of_selected_authored_segment_and_point" or
			partition.bay_owner_policy_id~=
				"exact_rational_minimum_segment_set_owner_v1" or
			partition.bay_owner_rule~=
				"literal_owner_span_for_each_exact_nearest_segment_then_lower_numeric_candidate_zone" or
			partition.bay_owner_segment_tie~=
				"exact_equal_rational_distance_collect_each_segment_candidate_owner_then_lower_numeric_zone_id" or
			partition.outer_footprint_authority~=
				"literal_perimeter_polygon_after_sole_boundary_displacement" or
			partition.perimeter_equality_rule~=
				"inside_footprint_and_dry_except_matching_base_bay_mouth_aperture" or
			partition.perimeter_equality_span_owner~="incident_perimeter_span_zone_id" or
			partition.perimeter_equality_attachment_precedence~=
				"shared_edge_half_open_lower_numeric_incident_zone_before_span_owner" or
			partition.perimeter_equality_vertex_tie~=
				"lower_numeric_zone_id_among_two_incident_unattached_spans" or
			partition.bay_mouth_aperture_policy_id~=
				"maximal_contiguous_nonwrapping_half_open_exact_base_bay_perimeter_stations_v1" or
			partition.bay_mouth_aperture_station_order~=
				"canonical_deduplicated_final_perimeter_integer_raster_order" or
			partition.bay_mouth_aperture_predicate~=
				"strict_rational_variable_width_capsule_union_v1_for_referenced_bay" or
			partition.wing_footprint_clip~=
				"strict_footprint_interior_only_never_mouth_aperture_equality" or
			partition.outer_footprint_rule~=
				"independent_final_literal_perimeter_not_face_union" or
			partition.closure_wing_policy_id~=
				"strict_tapered_bay_closure_wing_v1" or
			partition.closure_wing_membership~=
				"zero_less_equal_N_and_N_strictly_less_than_L_and_cross_squared_times_L_strictly_less_than_r_squared_times_M_squared" or
			partition.closure_wing_early_reject~=
				"absolute_cross_greater_equal_r_times_ceil_isqrt_L_is_outside_before_any_square_product" or
			partition.closure_wing_boundary_tie~=
				"side_equality_and_zero_width_terminal_junction_are_dry" or
			partition.bay_bank_policy_id~=
				"same_bay_final_water_union_dry_column_boundary_v1" or
			partition.bay_bank_candidate~=
				"final_classifier_dry_mainland_column_including_permitted_dry_perimeter_equality_with_four_neighbor_owned_by_same_final_base_bay_or_either_closure_wing" or
			partition.bay_bank_trace_envelope~=
				"referenced_bay_all_base_segment_and_two_wing_bounding_boxes_expanded_one_then_clipped_to_referenced_final_mainland_footprint" or
			partition.bay_bank_trace_state~=
				"bounded_depth_first_search_state_previous_current_plus_seen_directed_state_set_the_resolved_start_anchor_supplies_rotation_only_and_the_independently_resolved_end_terminal_is_the_target" or
			partition.bay_bank_neighbor_order~=
				"base_clockwise_east_southeast_south_southwest_west_northwest_north_northeast_rotate_so_first_is_immediately_clockwise_after_direction_current_to_previous_for_water_left_and_immediately_counterclockwise_for_water_right_then_continue_that_rotation" or
			partition.bay_bank_water_side~=
				"for_each_proposed_materialized_bank_step_current_to_successor_at_least_one_cardinal_same_bay_water_neighbor_of_current_must_have_strictly_positive_cross_for_water_left_or_strictly_negative_cross_for_water_right_zero_cross_does_not_satisfy_side_the_start_anchor_previous_to_current_has_no_water_side_requirement" or
			partition.bay_bank_admissible_successor~=
				"ordered_eight_neighbor_final_dry_same_bay_boundary_candidate_whose_outgoing_current_to_successor_step_satisfies_the_exact_water_side_rule_and_is_not_previous_or_in_the_seen_directed_state_set" or
			partition.bay_bank_branch_rule~=
				"evaluate_admissible_successors_in_the_fixed_Moore_order_and_select_the_first_with_a_complete_valid_path_to_the_declared_terminal_later_reachable_successors_are_permitted_zero_reachable_rejects" or
			partition.bay_bank_reachability_bound~=
				"per_successor_bounded_DFS_counts_every_pushed_frame_including_the_start_and_rejects_above_eight_times_the_finite_envelope_column_count_stack_depth_at_most_envelope_columns_main_trace_steps_at_most_envelope_columns_minus_one" or
			partition.bay_bank_terminal_authority~=
				"structured_aperture_dry_land_edge_transition_or_wing_junction_tail_side_reference_only_resolved_once_for_every_incident_arc" or
			partition.bay_bank_aperture_terminal_order~=
				"deduplicated_final_authored_declared_perimeter_integer_raster_order_separate_from_the_canonical_mouth_aperture_membership_indices_payload_and_attachment_tie" or
			partition.bay_bank_nonwing_terminal_resolution~=
				"aperture_dry_is_the_adjacent_dry_station_on_the_declared_side_in_the_separate_authored_bank_terminal_order_land_edge_transition_is_the_declared_endpoint_of_the_final_clipped_dry_edge_raster_and_that_endpoint_itself_must_be_a_final_dry_same_bay_boundary_candidate_no_inward_shift_is_permitted" or
			partition.bay_bank_edge_transition_identity~=
				"for_each_of_eight_transitions_the_inward_candidate_scan_offset_from_the_declared_final_endpoint_must_equal_zero_in_every_corpus_seed_edge_and_bank_consume_the_same_resolved_station_id_and_exact_canonical_x_z_bytes_without_a_second_resolution_defensive_copies_are_permitted_nonzero_rejects_and_requires_a_new_Reality_partition" or
			partition.bay_bank_nonwing_start_half_edge~=
				"aperture_previous_is_the_next_dry_authored_perimeter_station_away_from_the_aperture_land_edge_previous_is_the_immediately_adjacent_retained_dry_edge_station_away_from_the_resolved_endpoint_current_is_the_resolved_candidate_the_anchor_half_edge_must_be_eight_connected_and_current_candidate_valid_but_water_right_begins_only_on_the_first_materialized_bank_step_current_to_successor" or
			partition.bay_bank_wing_k_set~=
				"all_final_dry_candidates_in_the_declared_wing_bbox_with_a_cardinal_neighbor_in_strict_water_owned_by_that_referenced_closure_wing_zero_less_equal_N_and_N_strictly_less_than_L_and_strict_declared_cross_X_sign_independent_of_any_Moore_trace" or
			partition.bay_bank_wing_k_rank~=
				"greatest_exact_wing_axis_projection_N_then_lexicographically_least_x_then_z_unique_selected_coordinate_or_reject_empty_K_set" or
			partition.bay_bank_wing_k_guard~=
				"absolute_N_and_absolute_X_are_checked_against_the_existing_closure_wing_dot_cross_bounds_before_ranking_and_every_product_must_be_at_most_2_pow_53_minus_1" or
			partition.bay_bank_wing_terminal_direction~=
				"negative_tail_is_component_start_and_byte_exact_J_to_K_positive_tail_is_component_end_and_K_to_J_with_the_K_join_deduplicated" or
			partition.bay_bank_wing_start_half_edge~=
				"joint_tail_is_selected_before_any_component_trace_and_the_last_two_stations_of_negative_J_to_K_are_the_rotation_only_previous_current_start_anchor_while_positive_K_is_the_fixed_independent_target_for_a_wing_end_the_first_current_to_successor_bank_step_must_be_water_right_or_reject" or
			partition.bay_bank_tail_graph~=
				"two_complete_strict_side_dry_eight_neighbor_chebyshev_distance_layer_DAGs_from_K_to_J" or
			partition.bay_bank_tail_pair_selection~=
				"enumerate_all_complete_path_pairs_filter_interior_disjoint_distinct_J_predecessor_and_no_intra_or_inter_path_diagonal_X_cross_then_apply_wedge_validity_then_lexicographically_least_full_negative_path_coordinate_sequence_then_full_positive_sequence_coordinate_compare_x_then_z_and_shorter_sequence_first_on_exact_prefix_multiple_wedge_valid_pairs_permitted_none_rejects" or
			partition.bay_bank_tail_side~=
				"nonterminal_X_strictly_negative_or_positive_as_declared_X_zero_only_at_common_J" or
			partition.bay_bank_tail_bound~=
				"each_path_length_at_most_ceil_isqrt_wing_L_plus_one_finite_layer_DAG_has_no_cycles_and_current_source_requires_chebyshev_K_to_J_at_most_four" or
			partition.bay_bank_tail_wedge_polygon~=
				"analysis_only_exact_polygon_follows_negative_Kminus_to_J_then_reverse_positive_J_to_Kplus_then_direct_exact_chord_Kplus_to_Kminus_and_must_be_simple_with_nonzero_signed_area" or
			partition.bay_bank_tail_wedge_radius~=
				"R_equals_one_plus_maximum_Chebyshev_Kminus_to_J_or_Kplus_to_J_scan_inclusive_J_centered_R_bbox_current_source_R_at_most_five" or
			partition.bay_bank_tail_wedge_scan~=
				"for_each_integer_column_in_the_inclusive_J_centered_R_bbox_with_exact_polygon_class_greater_equal_zero_exempt_only_exact_negative_or_positive_tail_stations_including_Kminus_Kplus_and_J_every_other_column_must_be_strict_water_of_the_referenced_closure_wing" or
			partition.bay_bank_tail_wedge_chord~=
				"direct_exact_chord_Kplus_to_Kminus_is_analysis_only_and_never_rastered_materialized_serialized_or_used_for_ownership" or
			partition.bay_bank_tail_reversal~=
				"select_once_in_canonical_direction_reverse_output_is_byte_exact_sequence_reverse" or
			partition.bay_bank_reject~=
				"missing_K_malformed_nonadjacent_or_noncandidate_start_anchor_zero_terminal_reachable_successor_outgoing_bank_step_water_side_failure_reachability_frame_cap_stack_or_main_trace_bound_exhaustion_repeated_column_or_state_intra_or_inter_X_cross_foreign_bay_or_nonreferenced_water_contact_undeclared_endpoint_non_simple_or_zero_area_wedge_wedge_radius_above_five_nonwing_column_inside_wedge_or_no_wedge_valid_joint_tail_pair" or
			partition.bay_bank_materialization~=
				"resolve_each_terminal_and_each_joint_wing_tail_pair_once_then_materialize_one_shared_integer_column_chain_per_component_consumed_by_its_face_arc_no_literal_polyline_connector_snap_or_alternate_trace" or
			partition.raw_dry_multiplicity_rule~=
				"outside_final_planned_water_raw_dry_face_multiplicity_at_least_one_multiples_only_on_declared_shared_edge_or_junction_with_canonical_half_open_owner_inside_final_planned_water_has_no_raw_dry_face_requirement" or
			partition.cross_face_intersection_rule~=
				"forbidden_outside_strict_final_bay_masks_allowed_under_bay_precedence" or
			partition.ordered_component_oracle~=
				"stage2_composed_union_outer_boundary_equals_perimeter_ordered_outer_components" then
		return diag("world_partition_policy","geometry_policies.world_partition",
			"base water, literal wings, dry face, exterior with exact strict ties","invalid")
	end
	local fixture=policies.geometry_fixture_selector
	if fixture.coordinate_space~="signed_mapchunk_coordinates" or
			fixture.mapchunk_width~=80 or fixture.candidate_min~=-40 or
			fixture.candidate_max~=39 or not dense(fixture.classes) or
			#fixture.classes~=9 or not dense(fixture.final_tie_order) or
			table.concat(fixture.final_tie_order,"\0")~=
				"cy_least\0cz_least\0cx_least\0feature_numeric_id_least" then
		return diag("geometry_fixture_selector_policy",
			"geometry_policies.geometry_fixture_selector",
			"closed class-1..9 finite deterministic selector","invalid")
	end
	for class_index=1,9 do local class=fixture.classes[class_index]
		if class.id~=class_index or type(class.predicate_id)~="string" or
				class.predicate_id=="" or not dense(class.feature_family_ids) or
				not dense(class.score) then
			return diag("geometry_fixture_selector_policy",
				"geometry_policies.geometry_fixture_selector.classes["..class_index.."]",
				"ordered predicate/families/score","invalid")
		end
	end
	local trace=policies.requester_trace
	if trace.requester_count~=100 or trace.requester_index_min~=0 or
			trace.requester_index_max~=99 or not dense(trace.road_profile_family_ids) or
			table.concat(trace.road_profile_family_ids,"\0")~=
				"routes\0island_routes\0poi_spurs" or
			trace.active_tick_first~=0 or trace.active_tick_last~=3333 or
			trace.active_tick_count~=3334 or trace.recovery_tick_count~=2000 or
			type(trace.recovery_dtime)~="table" or
			trace.recovery_dtime.numerator~=9 or trace.recovery_dtime.denominator~=100 or
			trace.recovery_duration_seconds~=180 or
			trace.flight_legal_predicate_id~=
				"not_holy_not_warning_not_hard_no_flight_and_inside_compiled_land" then
		return diag("requester_trace_policy","geometry_policies.requester_trace",
			"exact final manifest/tick/recovery contract","invalid")
	end
	local extreme=policies.geometry_extreme_selector
	if extreme.candidate_count~=4096 or extreme.score_all_candidates_before_stage2~=true or
			extreme.sample_sequence~=
				"pre_displacement_canonical_source_segment_raster_only_never_final_reraster_stations" or
			extreme.coast_mainland_sequence~=
				"union_of_eligible_outer_source_perimeter_segments_in_perimeter_id_then_zero_based_source_segment_then_local_station_order" or
			extreme.coast_mainland_identity~=
				"perimeter_id_zero_based_source_segment_index_zero_based_local_station_index" or
			extreme.coast_mainland_overlap_rule~=
				"perimeter_span_overlap_never_duplicates_a_source_segment_or_station_in_the_union" or
			extreme.island_sequence~=
				"eligible_island_outer_arc_id_then_zero_based_source_segment_then_local_station_order" or
			extreme.island_identity~=
				"arc_id_zero_based_source_segment_index_zero_based_local_station_index" or
			extreme.noncoast_sequence~=
				"eligible_positive_shared_land_edge_numeric_id_then_zero_based_source_segment_then_local_station_order" or
			extreme.noncoast_identity~=
				"edge_id_zero_based_source_segment_index_zero_based_local_station_index" or
			extreme.source_join_dedup~=
				"duplicate_segment_join_and_closed_seam_station_keeps_the_stable_earlier_identity_in_the_declared_sequence" or
			extreme.scalar_sample_rule~=
				"each_unique_source_station_scores_its_post_noise_damping_local_clip_selected_topology_ceiling_pre_component_scalar_q_exactly_once" or
			extreme.attachment_rule~=
				"provisional_E_perimeter_A_discarded_prefix_suffix_and_inserted_final_reraster_stations_never_enter_selector_sequence" or
			extreme.no_interpolation_rule~=
				"never_interpolate_resample_or_rehash_a_selector_scalar" or
			extreme.scalar_stage~=
				"final_signed_q16_after_noise_damping_local_magnitude_clip_and_selected_record_topology_ceiling_before_x_z_component_rounding" or
			extreme.normalization_denominator~=
				"record_max_displacement_times_Q_not_local_damped_amplitude" or
				not dense(extreme.slots) or #extreme.slots~=4 or
			extreme.score_tie~="numerically_smaller_unsigned_decimal_seed" or
			extreme.selected_stage2_rule~=
				"compile_and_validate_four_selected_seeds_invalid_selected_seed_fails_without_fallback" then
		return diag("geometry_extreme_selector_policy",
			"geometry_policies.geometry_extreme_selector",
			"closed 4096-candidate exact rational extreme selector","invalid")
	end
	local axis_frame=policies.primitive_evaluator.axis_frame
	if policies.primitive_evaluator.initial_accumulator_q16~=0 or
			policies.primitive_evaluator.initial_accumulator_rule~=
				"zero_height_offset_at_every_fitting_envelope_column" or
			policies.primitive_evaluator.default_weight_rule~=
				"Q_inside_support_zero_outside_unless_formula_weight_rule_present" or
			policies.primitive_evaluator.feature_blend_source~=
				"composition_fitting_footprint_signed_chebyshev_q16" or
			policies.primitive_evaluator.feature_blend_width~=
				"template_blend_width_minus_fitting_width_div_two_per_side" or
			policies.primitive_evaluator.feature_blend_endpoints~=
				"composition_offset_at_fitting_boundary_zero_offset_at_blend_envelope_boundary" or
			type(axis_frame)~="table" or
			axis_frame.id~="canonical_oriented_tangent_frame_q16_v1" or
			axis_frame.zero_segment_rule~="skip_to_nearest_distinct_station" or
			axis_frame.opposite_turn_tie~="use_outgoing_tangent" then
		return diag("primitive_axis_frame_policy","geometry_policies.primitive_evaluator.axis_frame",
			"closed route/trail/patrol tangent frame","invalid")
	end
	local rim_formula=policies.primitive_formulas.formulas[6]
	if type(rim_formula)~="table" or rim_formula.id~="rim" or
			rim_formula.formula_id~="primitive_continuous_rim_q16_v1" or
			rim_formula.continuity_rule~=
				"zero_at_inner_and_outer_support_boundaries_height_at_peak" then
		return diag("primitive_rim_continuity","geometry_policies.primitive_formulas.rim",
			"continuous inner rise/peak/outer fall to zero","invalid")
	end
	local terrace_formula=policies.primitive_formulas.formulas[3]
	if type(terrace_formula)~="table" or terrace_formula.id~="terrace" or
			terrace_formula.formula_id~="primitive_terrace_q16_v2" or
			terrace_formula.support~="composition_fitting_footprint" or
			terrace_formula.continuity_rule~=
				"capped_outer_terrace_reaches_fitting_boundary_then_generic_feature_blend_returns_offset_to_zero" then
		return diag("primitive_terrace_continuity",
			"geometry_policies.primitive_formulas.terrace",
			"non-flat capped terrace plus generic continuous envelope blend","invalid")
	end
	local raster=policies.route_raster
	if raster.canonical_endpoint_order~="lower_x_then_lower_z" or
			raster.canonical_execution_rule~=
				"raster_once_from_lexicographically_lower_endpoint_to_higher_endpoint" or
			raster.authored_reversal_rule~=
				"reverse_finished_canonical_point_sequence_when_authored_direction_is_opposite" then
		return diag("route_raster_reversal_policy","geometry_policies.route_raster",
			"lex-canonical execution and whole-sequence authored reversal","invalid")
	end
	local route_solver=policies.route_profile_solver
	if route_solver.world_column_membership~=
			"signed_lateral_q16_greater_equal_minus_floor_width_div_two_Q_and_strictly_less_than_ceil_width_div_two_Q" or
			route_solver.final_target_rule~=
				"qround_qlerp_H_to_route_y_Q_by_cross_section_weight_half_away_from_zero" or
			route_solver.earthwork_rule~=
				"absolute_final_rounded_cross_section_target_minus_H_at_owned_lateral_column" or
			route_solver.interface_phase_rule~=
				"for_interface_station_i_flat_run_12_requires_delta_j_zero_for_j=max_2_i-11_through_min_last_i_plus_11" then
		return diag("route_profile_solver_policy",
			"geometry_policies.route_profile_solver",
			"half-open columns, final-target earthwork and exact phase","invalid")
	end
	local hydro_mask=policies.hydrology_mask
	local boundary_policy=policies.boundary_displacement
	local expected_no_jitter_sources={"all_literal_polyline_control_vertices",
		"all_route_interface_positions","all_fixed_anchor_positions",
		"holy_rectangle_corners_and_junctions"}
	if boundary_policy.input_rule~=
			"literal_control_polyline_authored_order_retained_only_for_final_output_mapping" or
			boundary_policy.sampling_rule~=
			"one_route_raster_policy_integer_sequence_with_consecutive_join_duplicates_suppressed" or
			boundary_policy.open_orientation_rule~=
				"lexicographically_smaller_complete_station_sequence_of_forward_and_reverse_is_calculation_order" or
			boundary_policy.closed_orientation_rule~=
				"remove_repeated_terminal_station_rotate_each_direction_to_lexicographically_lowest_x_then_z_station_then_choose_lexicographically_smaller_cycle" or
			boundary_policy.orientation_restore_rule~=
				"map_displaced_controls_back_to_authored_rotation_and_direction_only_after_all_scalar_and_component_results_exist" or
			boundary_policy.reversal_identity_rule~=
				"canonical_calculation_order_makes_reversal_change_only_output_order_never_displaced_world_columns" or
			boundary_policy.normal_and_scalar_orientation~=
				"canonical_calculation_direction_exclusively_authored_direction_never_changes_normal_or_scalar_sign" or
			boundary_policy.step_rule~=
				"incoming_equals_current_minus_previous_distinct_outgoing_equals_next_distinct_minus_current_each_component_minus_one_zero_or_one" or
			boundary_policy.step_length_q_rule~=
				"t1_isqrt_of_dx_squared_plus_dz_squared_times_Q_squared" or
			boundary_policy.step_left_normal_rule~=
				"normal_x_q_equals_t1_qdiv_minus_dz_times_Q_by_step_length_q_normal_z_q_equals_t1_qdiv_dx_times_Q_by_step_length_q" or
			boundary_policy.endpoint_normal_rule~=
				"single_available_directed_step_left_unit_normal" or
			boundary_policy.joint_rule~=
				"sum_incoming_and_outgoing_left_unit_q16_normals_then_t1_isqrt_sum_squares_and_t1_qdiv_each_sum_component_by_sum_length_q" or
			boundary_policy.joint_degenerate_rule~=
				"reject_zero_length_step_or_zero_opposite_joint_sum" or
			boundary_policy.normal_safe_bounds~=
				"step_length_radicand_at_most_8589934592_joint_sum_square_at_most_34359738368" or
			boundary_policy.raw_scalar_rule~=
				"raw_scalar_q_equals_t1_qmul_clamped_noise_q_and_record_max_displacement_times_Q" or
			boundary_policy.displacement_rule~=nil or
			boundary_policy.control_taper_distance~=96 or
			boundary_policy.control_taper_metric~=
			"canonical_eight_connected_segment_station_steps_equal_chebyshev_arclength" or
			boundary_policy.control_taper_rule~=
				"smootherstep_clamped_min_station_steps_from_segment_ends_div_96" or
			boundary_policy.control_taper_metadata~=
				"each_base_station_retains_authored_source_segment_numeric_index_zero_based_local_station_index_and_local_last_index" or
			boundary_policy.control_join_taper~=
				"deduplicated_shared_control_join_has_zero_taper_for_both_incident_segments" or
			boundary_policy.control_orientation_remap~=
				"open_reverse_and_closed_rotate_or_reverse_remap_segment_and_local_station_metadata_with_points_never_rederive_segment_boundaries_from_canonical_whole_sequence" or
			boundary_policy.no_jitter_metric~=
				"exact_world_chebyshev_distance_to_source_point" or
			boundary_policy.no_jitter_distance~=96 or
			boundary_policy.no_jitter_transition_distance~=96 or
			boundary_policy.no_jitter_rule~=
				"zero_through_distance_96_then_smootherstep_distance_minus_96_div_96_full_at_192" or
			boundary_policy.no_jitter_aggregation~=
				"minimum_damping_q16_over_all_sources" or
			not dense(boundary_policy.no_jitter_sources) or
			#boundary_policy.no_jitter_sources~=#expected_no_jitter_sources or
			table.concat(boundary_policy.no_jitter_sources,"\0")~=
				table.concat(expected_no_jitter_sources,"\0") or
			boundary_policy.damping_rule~=
				"t1_qmul_control_taper_q16_and_no_jitter_minimum_q16" or
			boundary_policy.damped_scalar_rule~=
				"damped_scalar_q_equals_t1_qmul_raw_scalar_q_and_damping_q" or
			type(boundary_policy.clip_envelope_by_kind)~="table" or
			boundary_policy.clip_envelope_by_kind.land_edge~=
				"closed_chebyshev_square_about_base_station_with_radius_record_max_displacement" or
			boundary_policy.clip_envelope_by_kind.mainland_coast~=
				"closed_constants_mainland_frame_rectangle" or
			boundary_policy.clip_envelope_by_kind.island_coast~=
				"closed_centered_axis_aligned_record_authoring_rectangle" or
			boundary_policy.clip_envelope_by_kind.fixed~="exact_base_station_only" or
			boundary_policy.clip_envelope_by_kind.bay~=nil or
			boundary_policy.land_edge_envelope_predicate~=
				"absolute_candidate_x_minus_base_x_less_equal_record_max_displacement_and_absolute_candidate_z_minus_base_z_less_equal_record_max_displacement" or
			boundary_policy.mainland_coast_envelope_predicate~=
				"mainland_frame_min_x_less_equal_candidate_x_less_equal_max_x_and_min_z_less_equal_candidate_z_less_equal_max_z" or
			boundary_policy.island_coast_envelope_predicate~=
				"absolute_candidate_x_minus_center_x_less_equal_radius_x_and_absolute_candidate_z_minus_center_z_less_equal_radius_z" or
			boundary_policy.fixed_envelope_predicate~=
				"candidate_x_equals_base_x_and_candidate_z_equals_base_z" or
			boundary_policy.envelope_boundary_tie~="equality_inside_for_every_kind" or
			boundary_policy.envelope_arithmetic~=
				"checked_exact_integer_comparisons_no_face_polygon_final_geometry_or_float_dependency" or
			boundary_policy.envelope_safe_bounds~=
				"every_kind_uses_only_safe_integer_subtraction_absolute_value_and_ordered_comparison" or
			not dense(boundary_policy.excluded_parameterized_geometry) or
			#boundary_policy.excluded_parameterized_geometry~=1 or
			boundary_policy.excluded_parameterized_geometry[1]~=
				"base_bay_symmetric_effective_half_width_uses_world_partition_policy_not_polyline_normal_displacement" or
			boundary_policy.clip_loop_rule~=
				"test_exact_damped_scalar_first_if_outside_scan_integer_magnitude_nodes_from_minimum_record_max_displacement_and_floor_absolute_damped_scalar_q_div_Q_down_to_zero_with_fixed_damped_sign" or
			boundary_policy.clip_probe_rule~=
				"for_each_magnitude_m_probe_station_plus_qround_qmul_normal_x_q_sign_m_Q_and_qround_qmul_normal_z_q_sign_m_Q" or
			boundary_policy.clip_selection_rule~=
				"exact_damped_scalar_if_its_probe_is_inside_else_first_integer_probe_is_greatest_tested_admissible_not_exceeding_desired_magnitude_no_monotonicity_assumption" or
			boundary_policy.clip_scalar_rule~=
				"local_scalar_q_equals_exact_damped_scalar_or_sign_damped_times_selected_integer_magnitude_times_Q_zero_damped_skips_loop_and_returns_zero_no_untested_fractional_result" or
			boundary_policy.local_scalar_stage~=
				"post_noise_damping_exact_local_envelope_clip_pre_topology_ceiling" or
			boundary_policy.mainland_fixed_closure_policy_id~=
				"referenced_fixed_holy_edge_union_r7_v1" or
			boundary_policy.mainland_fixed_closure_source~=
				"each_planned_mainland_footprint_has_one_structured_ordered_directed_union_of_exactly_six_max_displacement_zero_land_edge_references_no_copied_coordinates_or_authored_perimeter_segment_index" or
			boundary_policy.mainland_fixed_closure_resolution~=
				"route_raster_each_referenced_land_edge_in_declared_direction_suppress_only_consecutive_shared_endpoints_and_require_the_complete_union_byte_equal_exactly_one_complete_authored_perimeter_base_segment_with_exactly_twenty_six_other_source_segments" or
			boundary_policy.mainland_fixed_closure_remap~=
				"for_each_equivalent_authored_control_rotation_or_reversal_refind_the_unique_complete_source_segment_by_full_union_byte_sequence_then_tag_its_authored_segment_membership_before_canonicalization_and_carry_that_tag_with_station_metadata_never_rederive_from_canonical_array_position_or_point_membership" or
			boundary_policy.mainland_fixed_closure_scalar~=
				"inside_the_ordinary_local_scalar_loop_every_tagged_closure_row_has_local_scalar_q_exactly_zero_and_both_closure_to_ordinary_coast_ring_joins_must_also_be_zero_by_existing_no_jitter_before_the_record_wide_topology_ceiling" or
			boundary_policy.mainland_fixed_closure_topology~=
				"one_unchanged_record_wide_C_and_one_candidate_validity_and_final_reraster_cover_the_displaced_twenty_six_segment_coast_plus_fixed_closure_union" or
			boundary_policy.mainland_fixed_closure_output~=
				"selected_final_mainland_perimeter_closure_must_be_byte_exact_to_the_same_resolved_six_edge_union_in_declared_perimeter_order" or
			boundary_policy.mainland_fixed_closure_forbidden~=
				"no_post_R7_replace_snap_owner_fallback_private_coordinate_match_second_ceiling_or_change_to_the_eighteen_coast_components" or
			boundary_policy.topology_ceiling_policy_id~=
				"record_uniform_integer_magnitude_ceiling_v1" or
			boundary_policy.topology_ceiling_domain~=
				"integer_C_descending_from_record_max_displacement_through_zero_inclusive" or
			boundary_policy.topology_ceiling_scalar_rule~=
				"candidate_scalar_q_equals_clamp_local_scalar_q_to_minus_C_times_Q_through_plus_C_times_Q_preserving_values_with_absolute_value_not_greater_than_C_times_Q" or
			boundary_policy.topology_ceiling_candidate_order~=
				"strictly_descending_C_no_binary_search_or_monotonicity_assumption" or
			boundary_policy.topology_ceiling_validity~=
				"all_shifted_controls_and_final_raster_stations_inside_record_envelope_unique_stations_no_diagonal_X_cross_eight_connected_and_closed_records_simple_with_declared_orientation" or
			boundary_policy.topology_ceiling_selection~=
				"first_valid_candidate_is_greatest_admissible_C_and_its_scalar_rows_and_already_computed_raster_are_authoritative" or
			boundary_policy.topology_ceiling_provisional_rule~=
				"higher_invalid_candidate_rasters_are_selection_probes_never_exported_or_scored" or
			boundary_policy.topology_ceiling_termination~=
				"stage1_validates_zero_displacement_base_raster_C_zero_must_pass_max_displacement_plus_one_candidates_at_most_97_else_source_invalid" or
			boundary_policy.topology_ceiling_output_field~=
				"compiled_record_unsigned_topology_ceiling_nodes" or
			boundary_policy.junction_departure_policy_id~=
				"derived_diagonal_endpoint_precontrol_v1" or
			boundary_policy.junction_departure_derivation~=
				"for_the_declared_edge_endpoint_J_and_its_adjacent_original_authored_control_C_D_equals_J_plus_sign_C_minus_J_per_axis_both_axis_deltas_must_be_nonzero" or
			boundary_policy.junction_departure_safe_arithmetic~=
				"compare_adjacent_and_endpoint_coordinates_without_subtraction_to_select_each_sign_then_checked_safe_integer_plus_or_minus_one_source_adjacent_control_must_remain_inside_mainland_frame" or
			boundary_policy.junction_departure_application~=
				"copy_the_original_land_edge_control_array_insert_fixed_D_at_position_two_for_a_from_endpoint_or_before_the_last_control_for_a_to_endpoint_then_use_that_effective_copy_in_the_sole_boundary_displacement_pipeline" or
			boundary_policy.junction_departure_displacement~=
				"D_is_a_checksum_declared_derived_no_jitter_source_and_never_mutates_the_original_land_edge_control_array" or
			boundary_policy.junction_departure_topology~=
				"stage1_C_zero_and_stage2_selected_final_rasters_check_every_unordered_incident_edge_pair_at_all_38_junctions_only_J_may_be_shared_with_no_nonterminal_station_segment_or_opposing_diagonal_X_cross" or
			boundary_policy.junction_departure_failure~=
				"missing_duplicate_malformed_nonincident_nonendpoint_nondiagonal_wrong_derived_station_or_pairwise_overlap_rejects_without_shared_trunk_snap_connector_or_joint_ceiling_retry" or
			boundary_policy.component_rule~=
				"dx_equals_t1_qround_t1_qmul_normal_x_q_displacement_scalar_q_then_dz_analogously" or
			boundary_policy.component_rounding~=
				"qmul_half_away_to_Q16_then_qround_half_away_to_integer_in_that_order_including_positive_and_negative_half_ties" or
			boundary_policy.scalar_component_product_bound_decimal~=
				"412316860416" or
			boundary_policy.shifted_station_rule~=
				"every_shifted_base_raster_station_is_a_final_reraster_control_not_a_final_emitted_station" or
			boundary_policy.final_raster_rule~=
				"route_raster_once_between_consecutive_shifted_controls_closed_cycle_also_last_to_first_suppress_only_consecutive_duplicates_remove_repeated_cycle_terminal" or
			boundary_policy.final_validation_rule~=
				"selected_ceiling_final_raster_rechecks_envelope_and_record_local_topology_width_or_cross_record_connectivity_failure_rejects_seed_without_second_clip_snap_or_seed_fallback" or
			boundary_policy.displacement_scalar_authority~=
				"sole_final_signed_Q16_value_after_noise_damping_local_magnitude_clip_and_selected_record_topology_ceiling_before_component_rounding" or
			boundary_policy.shared_boundary_clip_policy_id~=
			"canonical_integer_land_run_prefix_suffix_v1" or
			boundary_policy.shared_boundary_clip_raster~=
				"route_raster_policy_integer_sequence" or
			boundary_policy.shared_boundary_clip_classifier~=
				"final_literal_perimeter_land_mask_after_displacement" or
			boundary_policy.shared_boundary_clip_retained_rule~=
				"exactly_one_consecutive_retained_station_interval" or
			boundary_policy.shared_boundary_clip_endpoint_rule~=
				"nonattached_first_and_last_retained_integer_stations_attached_endpoint_uses_joint_station" or
			boundary_policy.shared_boundary_attachment_policy_id~=
				"joint_perimeter_station_endpoint_before_final_raster_v1" or
			boundary_policy.shared_boundary_attachment_candidate~=
				"final_displaced_perimeter_then_provisional_edge_selection_only_run_yields_E_then_final_displaced_declared_perimeter_segment_yields_A" or
			boundary_policy.shared_boundary_attachment_selection~=
				"minimum_chebyshev_E_to_A_then_lower_canonical_perimeter_index_tie_distance_at_most_one" or
			boundary_policy.shared_boundary_attachment_final~=
				"discarded_prefix_or_suffix_controls_are_removed_A_is_zero_displacement_terminal_control_and_both_span_boundaries_before_sole_final_edge_raster_provisional_run_not_exported" or
			boundary_policy.shared_boundary_attachment_interior~=
				"all_final_stations_after_A_strict_footprint_interior_eight_connected_one_run" or
			boundary_policy.shared_boundary_attachment_rule~=nil or
			boundary_policy.shared_boundary_clip_forbidden~=
				"emitted_E_to_A_connector_post_raster_snap_inserted_float_or_rational_intersection_and_private_connector_geometry" then
		return diag("boundary_clip_policy","geometry_policies.boundary_displacement",
			"sole canonical integer prefix/suffix clip without inserted intersection","invalid")
	end
	if hydro_mask.rapid_run_interval~=
			"floor_run_div_two_stations_upstream_plus_interface_plus_remaining_stations_downstream" or
			hydro_mask.interface_axis_rule~=
				"last_distinct_upper_reach_station_to_first_distinct_lower_reach_station" or
			hydro_mask.transition_volume_rule~=
				"union_profile_seals_then_remove_only_declared_open_faces" then
		return diag("hydrology_mask_policy","geometry_policies.hydrology_mask",
			"closed rapid placement/axis/seal policy","invalid")
	end
	if type(canonical)~="table" or type(raw_sha256)~="function" then
		return diag("exact_source_seam","source",
			"T1 canonical module and raw SHA injection","missing")
	end
	for _,key in ipairs({"logical_biome_selector","primitive_evaluator",
			"primitive_formulas","boundary_displacement","route_raster",
			"route_profile_solver","relief_field","landmark_masks",
			"coastal_housing_core","world_partition","geometry_fixture_selector",
			"requester_trace","geometry_extreme_selector",
			"hydrology_mask","route_vertical_interfaces"}) do
		local projected_ok,projected=pcall(canonicalize_source_node,
			policies[key],key,canonical)
		if not projected_ok then return diag("generic_geometry_policy_contract",
			"geometry_policies."..key,"canonical policy",projected) end
		local checksum_ok,checksum=pcall(function()
			return canonical.hex(canonical.checksum(projected,raw_sha256))
		end)
		local invariant=key=="logical_biome_selector" and
			"logical_biome_selector_contract" or "generic_geometry_policy_contract"
		if not checksum_ok or checksum~=EXPECTED_POLICY_CHECKSUMS[key] then
			return diag(invariant,"geometry_policies."..key,
				EXPECTED_POLICY_CHECKSUMS[key],checksum)
		end
	end
	local connection_policy={}
	if not dense(policies.anchor_connection_policy) or
			#policies.anchor_connection_policy~=11 then
		return diag("anchor_connection_policy","geometry_policies",11,"changed")
	end
	for i=1,#policies.anchor_connection_policy do local row=policies.anchor_connection_policy[i]
		if connection_policy[row.id] or (row.class~="primary" and
				row.class~="secondary" and row.class~="trail") then
			return diag("anchor_connection_policy",row.id,"unique closed route class","invalid")
		end
		connection_policy[row.id]=row
	end
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
	local edge_by_id = {}
	local boundary_only_expected={
		land_058={"elandor_copperfell_foothills","elandor_frostbarrow_shelf",-2600,-1900,-2200,-1900},
		land_059={"elandor_starbough_vale","elandor_moonfall_wood",2200,-1900,2600,-1900},
		land_060={"kragmar_mournfen","kragmar_ossuary_reach",-2600,1900,-2200,1900},
		land_061={"kragmar_raincall_basin","kragmar_totemwater_reach",2200,1900,2600,1900},
	}
	local function junction_id(point)
		return "junction:"..point.x..":"..point.z
	end
	local minimum_edge_endpoint_chebyshev=9007199254740991
	for i = 1, #source.land_edges do
		local row = source.land_edges[i]
		if not zone_ids[row.zone_a] or not zone_ids[row.zone_b] then return diag("land_edge_zone",row.id,"known zones",row.zone_a..":"..row.zone_b) end
		if row.zone_a == row.zone_b then return diag("land_edge_self",row.id,false,true) end
		local a, b = row.zone_a, row.zone_b
		if b < a then a, b = b, a end
		local key = a .. "\0" .. b
		if pairs_seen[key] then return diag("land_edge_duplicate",row.id,false,true) end
		pairs_seen[key] = true
		local profile_a=relief_by_id[zone_by_id[row.zone_a].primary_relief_id]
		local profile_b=relief_by_id[zone_by_id[row.zone_b].primary_relief_id]
		local gate_min=math.max(profile_a.min_above_water,profile_b.min_above_water)
		local gate_max=math.min(profile_a.max_above_water,profile_b.max_above_water)
		if gate_min>gate_max then
			local lower_max=math.min(profile_a.max_above_water,profile_b.max_above_water)
			local upper_min=math.max(profile_a.min_above_water,profile_b.min_above_water)
			gate_min=math.floor((lower_max+upper_min)/2)
			gate_max=gate_min
		end
		if row.gate_selector_id~="shared_edge_gate_relief_q16_v1" or
				row.gate_min_above_water~=gate_min or
				row.gate_max_above_water~=gate_max then
			return diag("relief_edge_gate_authority",row.id,
				gate_min..".."..gate_max,
				tostring(row.gate_min_above_water)..".."..
					tostring(row.gate_max_above_water))
		end
		if not dense(row.control) or #row.control < 2 then return diag("edge_control",row.id,"two or more points","invalid") end
		for j=1,#row.control do
			if not point_valid(row.control[j],false) then return diag("edge_control_point",row.id,"integer x/z point","invalid") end
		end
		if (row.id=="land_035" or row.id=="land_036" or
				row.id=="land_041" or row.id=="land_042") and
				(row.control[2].x<source.constants.mainland_frame.min_x or
				row.control[2].x>source.constants.mainland_frame.max_x or
				row.control[2].z<source.constants.mainland_frame.min_z or
				row.control[2].z>source.constants.mainland_frame.max_z) then
			return diag("junction_departure_safe_arithmetic",row.id,
				"adjacent authored control inside exact mainland frame",
				row.control[2].x..":"..row.control[2].z)
		end
		local base_ok,base_failure=base_raster_valid(row,row.id,row.control,false,
			function() return true end)
		if not base_ok then return nil,base_failure end
		local first,last=row.control[1],row.control[#row.control]
		local endpoint_chebyshev=math.max(math.abs(last.x-first.x),
			math.abs(last.z-first.z))
		minimum_edge_endpoint_chebyshev=math.min(
			minimum_edge_endpoint_chebyshev,endpoint_chebyshev)
		if not point_valid(row.left_probe,false) or
				not point_valid(row.right_probe,false) or
				type(row.probe_segment_index)~="number" or
				row.probe_segment_index<1 or
				row.probe_segment_index>#row.control-1 then
			return diag("face_edge_probe_contract",row.id,
				"two explicit probes on one authored segment","invalid")
		end
		if row.left_zone==row.right_zone or
				(row.left_zone~=row.zone_a and row.left_zone~=row.zone_b) or
				(row.right_zone~=row.zone_a and row.right_zone~=row.zone_b) then
			return diag("face_edge_probe_contract",row.id,
				"two distinct incident declared sides","invalid")
		end
		local numeric_a,numeric_b
		for zone_index=1,#source.zones do local zone_row=source.zones[zone_index]
			if zone_row.id==row.zone_a then numeric_a=zone_row.numeric_id end
			if zone_row.id==row.zone_b then numeric_b=zone_row.numeric_id end
		end
		local tie_zone=numeric_a<numeric_b and row.zone_a or row.zone_b
		if row.tie_rule~="lower_zone_numeric_id" or row.tie_zone_id~=tie_zone then
			return diag("face_edge_tie",row.id,tie_zone,row.tie_zone_id)
		end
		if row.from_junction_id~=junction_id(row.control[1]) or
				row.to_junction_id~=junction_id(row.control[#row.control]) then
			return diag("face_edge_junctions",row.id,
				"coordinate-bound stable endpoint junctions","changed")
		end
		if row.route_class~=nil then return diag("boundary_route_separation",row.id,"no route-owned fields","route_class") end
		local boundary_expected=boundary_only_expected[row.id]
		if i<=57 then
			if row.boundary_only~=nil then return diag("old_land_edge_fixture",row.id,
				"original 57 record has no boundary-only field","changed") end
		elseif not boundary_expected or row.boundary_only~=true or
				row.zone_a~=boundary_expected[1] or row.zone_b~=boundary_expected[2] or
				row.max_displacement~=0 or row.noise_domain~="boundary_"..row.id or
				#row.control~=2 or row.control[1].x~=boundary_expected[3] or
				row.control[1].z~=boundary_expected[4] or
				row.control[2].x~=boundary_expected[5] or row.control[2].z~=boundary_expected[6] then
			return diag("boundary_only_land_edge",row.id,
				"exact reviewed pair/endpoints/zero jitter/no route","changed")
		end
		if not dense(row.control) or #row.control < 2 then return diag("edge_control",row.id,"two or more points","invalid") end
		for j=1,#row.control do
			if not point_valid(row.control[j],false) then return diag("edge_control_point",row.id,"integer x/z point","invalid") end
		end
		for a=1,#row.control-1 do for b=a+2,#row.control-1 do
			if intersects(row.control[a],row.control[a+1],row.control[b],row.control[b+1]) then
				return diag("face_edge_planarity",row.id,"simple control polyline",a..":"..b)
			end
		end end
		edge_by_id[row.id]=row
	end
	if minimum_edge_endpoint_chebyshev~=400 then
		return diag("relief_junction_raw_endpoint_baseline","land_edges",
			"minimum raw-control endpoint Chebyshev separation 400",
			minimum_edge_endpoint_chebyshev)
	end
	-- Resolve the structured fixed closure as soon as its six referenced edge
	-- rasters exist. This keeps join/repeat failures owned by the closure
	-- contract rather than letting later junction or global-planarity checks
	-- obscure them.
	for i=1,#source.perimeters do
		local polygon=source.perimeters[i].polygon
		if dense(polygon) and #polygon>=4 and
				polygon[1].x==polygon[#polygon].x and
				polygon[1].z==polygon[#polygon].z then
			ok,failure=validate_fixed_closure(source.perimeters[i],i,edge_by_id)
			if not ok then return nil,failure end
		end
	end
	local junction_incidence={}
	for edge_index=1,#source.land_edges do local edge=source.land_edges[edge_index]
		for _,point in ipairs({edge.control[1],edge.control[#edge.control]}) do
			local key=point.x..":"..point.z
			local row=junction_incidence[key] or {x=point.x,z=point.z,edges={}}
			junction_incidence[key]=row row.edges[#row.edges+1]=edge
		end
	end
	local expected_junctions={}
	for _,row in pairs(junction_incidence) do
		if #row.edges>=2 then expected_junctions[#expected_junctions+1]=row end
	end
	table.sort(expected_junctions,function(a,b)
		return a.z==b.z and a.x<b.x or a.z<b.z
	end)
	if #expected_junctions~=38 then
		return diag("relief_junction_count","derived endpoints",38,#expected_junctions)
	end
	local empty_junctions=0
	for junction_index=1,#expected_junctions do
		local derived=expected_junctions[junction_index]
		table.sort(derived.edges,function(a,b) return a.numeric_id<b.numeric_id end)
		local row=source.relief_junctions[junction_index]
		local expected_id="relief_junction:"..derived.x..":"..derived.z
		local ok_fields,field_failure=closed_fields(row,
			"relief_junctions["..junction_index.."]",
			{"id","position","incident_edge_ids","gate_min_above_water",
				"gate_max_above_water","empty_intersection",
				"transition_midpoint_above_water","hash_domain",
				"hash_feature_id","hash_coordinates","hash_candidate_index",
				"hash_lane","transition_station_steps",
				"policy_id","numeric_id"},"relief_junction_fields")
		if not ok_fields then return nil,field_failure end
		if row.id~=expected_id or not point_valid(row.position,false) or
				row.position.x~=derived.x or row.position.z~=derived.z or
				row.hash_domain~="relief_junction_v1" or
				row.hash_feature_id~="junction:"..derived.x..":"..derived.z or
				row.hash_coordinates~="position_x_z" or
				row.hash_candidate_index~=0 or row.hash_lane~=2 or
				row.transition_station_steps~=96 or
				row.policy_id~="shared_relief_junction_gate_v1" or
				not dense(row.incident_edge_ids) or
				#row.incident_edge_ids~=#derived.edges then
			return diag("relief_junction_contract",row.id,
				"exact coordinate/incidence/hash/transition record","changed")
		end
		local band_min,band_max=-9007199254740991,9007199254740991
		for incidence_index=1,#derived.edges do local edge=derived.edges[incidence_index]
			if row.incident_edge_ids[incidence_index]~=edge.id then
				return diag("relief_junction_incidence",row.id,edge.id,
					row.incident_edge_ids[incidence_index])
			end
			band_min=math.max(band_min,edge.gate_min_above_water)
			band_max=math.min(band_max,edge.gate_max_above_water)
		end
		local empty=band_min>band_max
		local midpoint=empty and math.floor((band_min+band_max)/2) or false
		if row.gate_min_above_water~=band_min or
				row.gate_max_above_water~=band_max or
				row.empty_intersection~=empty or
				row.transition_midpoint_above_water~=midpoint then
			return diag("relief_junction_band",row.id,
				band_min..".."..band_max..":"..tostring(midpoint),
				tostring(row.gate_min_above_water)..".."..
					tostring(row.gate_max_above_water)..":"..
					tostring(row.transition_midpoint_above_water))
		end
		if empty then empty_junctions=empty_junctions+1 end
	end
	if empty_junctions~=16 then
		return diag("relief_junction_empty_count","relief_junctions",16,
			empty_junctions)
	end
	local relief_junction_by_id={}
	for i=1,#source.relief_junctions do
		relief_junction_by_id[source.relief_junctions[i].id]=source.relief_junctions[i]
	end
	local witness_a=relief_junction_by_id["relief_junction:-1400:-1100"]
	local witness_b=relief_junction_by_id["relief_junction:-2200:1900"]
	if not witness_a or witness_a.gate_min_above_water~=96 or
			witness_a.gate_max_above_water~=56 or
			witness_a.transition_midpoint_above_water~=76 or
			table.concat(witness_a.incident_edge_ids,"/")~=
				"land_003/land_020/land_032/land_035" or
			not witness_b or witness_b.gate_min_above_water~=56 or
			witness_b.gate_max_above_water~=24 or
			witness_b.transition_midpoint_above_water~=40 or
			table.concat(witness_b.incident_edge_ids,"/")~=
				"land_011/land_025/land_060" then
		return diag("relief_junction_witnesses","relief_junctions",
			"exact two reviewed empty-intersection fixtures","changed")
	end
	ok,failure=(function()
	local expected_departures={
		{"land_035","relief_junction:-1400:-1100",-1399,-1099},
		{"land_036","relief_junction:400:-1100",401,-1099},
		{"land_041","relief_junction:-1400:1100",-1399,1099},
		{"land_042","relief_junction:400:1100",401,1099},
	}
	local departure_by_edge={}
	local effective_control_by_edge={}
	for departure_index=1,#source.junction_departures do
		local row=source.junction_departures[departure_index]
		local label="junction_departures["..departure_index.."]"
		local ok_fields,field_failure=closed_fields(row,label,
			{"id","edge_id","junction_id","edge_endpoint",
				"departure_rule","application_rule","displacement_rule",
				"route_rule","numeric_id"},"junction_departure_fields")
		if not ok_fields then return nil,field_failure end
		local expected=expected_departures[departure_index]
		if type(row.id)~="string" or type(row.edge_id)~="string" or
				type(row.junction_id)~="string" or
				(row.edge_endpoint~="from" and row.edge_endpoint~="to") or
				row.departure_rule~=
					"diagonal_sign_step_toward_adjacent_authored_control_v1" or
				row.application_rule~=
					"copied_effective_control_position_two_before_sole_boundary_displacement" or
				row.displacement_rule~="fixed_zero_no_jitter_derived_station" or
				row.route_rule~=
					"boundary_geometry_only_route_source_and_payload_unchanged" then
			return diag("junction_departure_contract",row.id,
				"closed typed coordinate-free departure record","changed")
		end
		local departure_key=row.edge_id..":"..row.edge_endpoint
		if departure_by_edge[departure_key] then
			return diag("junction_departure_duplicate",row.id,
				"one departure per land edge endpoint",departure_key)
		end
		local edge=edge_by_id[row.edge_id]
		local junction=relief_junction_by_id[row.junction_id]
		if not edge or not junction or not point_valid(junction.position,false) then
			return diag("junction_departure_reference",row.id,
				"known edge and relief junction","missing")
		end
		local incident=false
		for incidence_index=1,#junction.incident_edge_ids do
			if junction.incident_edge_ids[incidence_index]==edge.id then
				incident=true break
			end
		end
		local endpoint=row.edge_endpoint=="from" and edge.control[1] or
			edge.control[#edge.control]
		local adjacent=row.edge_endpoint=="from" and edge.control[2] or
			edge.control[#edge.control-1]
		if not incident or endpoint.x~=junction.position.x or
				endpoint.z~=junction.position.z then
			return diag("junction_departure_incidence",row.id,
				"declared endpoint is the incident relief junction","changed")
		end
		if row.id~="junction_departure:"..row.edge_id..":"..row.edge_endpoint or
				row.edge_endpoint~="from" or row.edge_id~=expected[1] or
				row.junction_id~=expected[2] then
			return diag("junction_departure_contract",row.id,
				"exact ordered departure roster","changed")
		end
		if adjacent.x==endpoint.x or adjacent.z==endpoint.z then
			return diag("junction_departure_diagonal",row.id,
				"both adjacent authored control deltas nonzero",
				adjacent.x..":"..adjacent.z)
		end
		local step_x=adjacent.x<endpoint.x and -1 or 1
		local step_z=adjacent.z<endpoint.z and -1 or 1
		if (step_x<0 and endpoint.x<=-SAFE_INTEGER) or
				(step_x>0 and endpoint.x>=SAFE_INTEGER) or
				(step_z<0 and endpoint.z<=-SAFE_INTEGER) or
				(step_z>0 and endpoint.z>=SAFE_INTEGER) then
			return diag("junction_departure_safe_arithmetic",row.id,
				"checked exact sign step remains inside safe integer range",
				endpoint.x..":"..endpoint.z)
		end
		local derived={x=endpoint.x+step_x,z=endpoint.z+step_z}
		if derived.x~=expected[3] or derived.z~=expected[4] then
			return diag("junction_departure_derived_station",row.id,
				expected[3]..":"..expected[4],derived.x..":"..derived.z)
		end
		local effective={}
		for control_index=1,#edge.control do
			effective[control_index]=edge.control[control_index]
		end
		table.insert(effective,row.edge_endpoint=="from" and 2 or #effective,derived)
		departure_by_edge[departure_key]=row
		departure_by_edge[row.edge_id]=row
		effective_control_by_edge[row.edge_id]=effective
	end
	for expected_index=1,#expected_departures do
		if not departure_by_edge[expected_departures[expected_index][1]] then
			return diag("junction_departure_roster","junction_departures",
				expected_departures[expected_index][1],"missing")
		end
	end
	local base_raster_by_edge={}
	for edge_index=1,#source.land_edges do local edge=source.land_edges[edge_index]
		local controls=effective_control_by_edge[edge.id] or edge.control
		local raster_ok,raster_failure,raster=base_raster_valid(edge,
			"junction_pair_base:"..edge.id,controls,false,function() return true end)
		if not raster_ok then return nil,raster_failure end
		base_raster_by_edge[edge.id]=raster
	end
	local junction_pair_count=0
	for junction_index=1,#source.relief_junctions do local junction=source.relief_junctions[junction_index]
		local point=junction.position
		local oriented={}
		for incidence_index=1,#junction.incident_edge_ids do
			local edge_id=junction.incident_edge_ids[incidence_index]
			local raster=base_raster_by_edge[edge_id]
			if raster[1].x==point.x and raster[1].z==point.z then
				oriented[incidence_index]=raster
			elseif raster[#raster].x==point.x and raster[#raster].z==point.z then
				oriented[incidence_index]=reverse_points(raster)
			else
				return diag("junction_pair_base_incidence",junction.id,
					"every incident raster begins at J after orientation",edge_id)
			end
		end
		for first_index=1,#oriented-1 do for second_index=first_index+1,#oriented do
			junction_pair_count=junction_pair_count+1
			local first,second=oriented[first_index],oriented[second_index]
			local first_stations={}
			for station_index=2,#first do
				first_stations[first[station_index].x..":"..first[station_index].z]=station_index
			end
			for station_index=2,#second do
				local key=second[station_index].x..":"..second[station_index].z
				if first_stations[key] then
					return diag("junction_pair_base_overlap",
						junction.incident_edge_ids[first_index]..":"..
							junction.incident_edge_ids[second_index],
						"only the common junction station may coincide",
						junction.id..":"..key)
				end
			end
			local first_diagonals={}
			for station_index=1,#first-1 do local a,b=first[station_index],first[station_index+1]
				local dx,dz=b.x-a.x,b.z-a.z
				if math.abs(dx)==1 and math.abs(dz)==1 then
					first_diagonals[math.min(a.x,b.x)..":"..math.min(a.z,b.z)]=
						dx==dz and 1 or -1
				end
			end
			for station_index=1,#second-1 do local a,b=second[station_index],second[station_index+1]
				local dx,dz=b.x-a.x,b.z-a.z
				if math.abs(dx)==1 and math.abs(dz)==1 then
					local key=math.min(a.x,b.x)..":"..math.min(a.z,b.z)
					local slope=dx==dz and 1 or -1
					if first_diagonals[key] and first_diagonals[key]~=slope then
						return diag("junction_pair_base_x_cross",
							junction.incident_edge_ids[first_index]..":"..
								junction.incident_edge_ids[second_index],
							"no opposing diagonal in one integer cell",key)
					end
				end
			end
		end end
	end
	if junction_pair_count~=102 then
		return diag("junction_pair_base_count","relief_junctions",102,
			junction_pair_count)
	end
	return true
	end)()
	if not ok then return nil,failure end
	for first_index=1,#source.land_edges do
		local first=source.land_edges[first_index]
		for second_index=first_index+1,#source.land_edges do
			local second=source.land_edges[second_index]
			for a=1,#first.control-1 do for b=1,#second.control-1 do
				if intersects(first.control[a],first.control[a+1],
						second.control[b],second.control[b+1]) then
					local p,q=first.control[a],first.control[a+1]
					local r,s=second.control[b],second.control[b+1]
					local shared_endpoint=(p.x==r.x and p.z==r.z) or
						(p.x==s.x and p.z==s.z) or (q.x==r.x and q.z==r.z) or
						(q.x==s.x and q.z==s.z)
					if not shared_endpoint then return diag("land_edge_planarity",
						first.id..":"..second.id,"no crossing away from shared junction",
						a..":"..b) end
				end
			end end
		end
	end
	-- Close literal wing endpoints before those records can relax the global
	-- face-intersection oracle.  This ordering makes malformed water authority
	-- fail deterministically rather than hiding a dry crossing.
	local early_wing_endpoints={
		{"bay_wing:elandor_west:left",-980,-2000,-1400,-1900},
		{"bay_wing:elandor_west:right",-980,-2000,-400,-1900},
		{"bay_wing:elandor_east:left",1020,-1990,400,-1900},
		{"bay_wing:elandor_east:right",1020,-1990,1400,-1900},
		{"bay_wing:kragmar_west:left",-1060,2010,-1400,1900},
		{"bay_wing:kragmar_west:right",-1060,2010,-400,1900},
		{"bay_wing:kragmar_east:left",900,1980,400,1900},
		{"bay_wing:kragmar_east:right",900,1980,1400,1900},
	}
	for wing_index=1,#early_wing_endpoints do local wing=source.bay_closure_wings[wing_index]
		local expected=early_wing_endpoints[wing_index]
		if wing.id~=expected[1] or not point_valid(wing.head,false) or
				not point_valid(wing.junction,false) or wing.head.x~=expected[2] or
				wing.head.z~=expected[3] or wing.junction.x~=expected[4] or
				wing.junction.z~=expected[5] then
			return diag("bay_closure_wing_literal",wing.id,
				"reviewed fixed head and triple-junction endpoints","invalid")
		end
	end
	local geometry_ref_ids,geometry_ref_by_id={},{ }
	for _,collection in ipairs({source.perimeters,source.bays,source.islands}) do
		for i=1,#collection do
			geometry_ref_ids[collection[i].id]=true
			geometry_ref_by_id[collection[i].id]=collection[i]
		end
	end
	local attachment_expected={
		{"perimeter_attachment:elandor:land_031","land_031","from","perimeter_elandor_mainland",3,"suffix","perimeter_span:elandor:stormvault","perimeter_span:elandor:frostbarrow"},
		{"perimeter_attachment:elandor:land_001","land_001","from","perimeter_elandor_mainland",7,"suffix","perimeter_span:elandor:copperfell","perimeter_span:elandor:hearthpine"},
		{"perimeter_attachment:elandor:land_007","land_007","to","perimeter_elandor_mainland",20,"prefix","perimeter_span:elandor:silverleaf","perimeter_span:elandor:starbough"},
		{"perimeter_attachment:elandor:land_034","land_034","to","perimeter_elandor_mainland",24,"prefix","perimeter_span:elandor:moonfall","perimeter_span:elandor:glassroot"},
		{"perimeter_attachment:kragmar:land_037","land_037","from","perimeter_kragmar_mainland",3,"suffix","perimeter_span:kragmar:blackwind","perimeter_span:kragmar:ossuary"},
		{"perimeter_attachment:kragmar:land_010","land_010","from","perimeter_kragmar_mainland",7,"suffix","perimeter_span:kragmar:mournfen","perimeter_span:kragmar:stillgrave"},
		{"perimeter_attachment:kragmar:land_016","land_016","to","perimeter_kragmar_mainland",20,"prefix","perimeter_span:kragmar:kapok","perimeter_span:kragmar:raincall"},
		{"perimeter_attachment:kragmar:land_040","land_040","to","perimeter_kragmar_mainland",24,"prefix","perimeter_span:kragmar:totemwater","perimeter_span:kragmar:thunderroot"},
	}
	local attachment_by_id,attachment_by_edge={},{}
	for attachment_index=1,#source.perimeter_attachments do
		local row=source.perimeter_attachments[attachment_index]
		local expected=attachment_expected[attachment_index]
		if row.id~=expected[1] or row.edge_id~=expected[2] or
				row.edge_endpoint~=expected[3] or row.perimeter_id~=expected[4] or
				row.perimeter_segment_index~=expected[5] or row.retained_run~=expected[6] or
				row.canonical_before_span_id~=expected[7] or
				row.canonical_after_span_id~=expected[8] or
				row.clip_policy_id~="joint_perimeter_station_endpoint_before_final_raster_v1" or
				row.geometry_rule~="symbolic_edge_to_perimeter_joint_station_no_connector_or_snap" or
				row.selection_station_rule~=
					"first_or_last_retained_candidate_station_E_stage2_only" or
				row.joint_station_rule~=
					"final_displaced_declared_perimeter_segment_station_A_min_chebyshev_to_E_lower_canonical_index_tie_max_one" or
				row.compiled_endpoint_rule~=
					"discard_outside_terminal_controls_A_is_shared_zero_displacement_terminal_control_before_sole_final_edge_raster_provisional_run_not_exported" or
				row.control~=nil or row.position~=nil then
			return diag("perimeter_attachment_contract",row.id,
				"exact symbolic reviewed edge/perimeter attachment","changed")
		end
		local edge,perimeter=edge_by_id[row.edge_id],geometry_ref_by_id[row.perimeter_id]
		if not edge or not perimeter or perimeter.kind~="planned_mainland_footprint" then
			return diag("perimeter_attachment_ref",row.id,"known edge and mainland perimeter","invalid")
		end
		local crossing_count=0
		for edge_segment=1,#edge.control-1 do
			for perimeter_segment=1,#perimeter.polygon-1 do
				if intersects(edge.control[edge_segment],edge.control[edge_segment+1],
						perimeter.polygon[perimeter_segment],perimeter.polygon[perimeter_segment+1]) then
					crossing_count=crossing_count+1
					if perimeter_segment~=row.perimeter_segment_index then
						return diag("perimeter_attachment_incidence",row.id,
							row.perimeter_segment_index,perimeter_segment)
					end
				end
			end
		end
		if crossing_count~=1 then return diag("perimeter_attachment_incidence",row.id,1,crossing_count) end
		attachment_by_id[row.id]=row attachment_by_edge[row.edge_id]=row
	end
	local function boundary_key(boundary)
		if type(boundary)~="table" then return nil end
		if boundary.kind=="perimeter_attachment" and attachment_by_id[boundary.attachment_id] then
			return boundary.attachment_id
		end
		if boundary.kind=="perimeter_vertex" then
			local perimeter=geometry_ref_by_id[boundary.perimeter_id]
			local point=perimeter and perimeter.polygon[boundary.index]
			if point then return junction_id(point) end
		end
		return nil
	end
	local expected_spans={
		{"perimeter_span:elandor:stormvault","elandor_stormvault_heights","perimeter_elandor_mainland",1,3,"forward","junction:-2500:-250","perimeter_attachment:elandor:land_031"},
		{"perimeter_span:elandor:frostbarrow","elandor_frostbarrow_shelf","perimeter_elandor_mainland",3,4,"forward","perimeter_attachment:elandor:land_031","junction:-2600:-1900"},
		{"perimeter_span:elandor:copperfell","elandor_copperfell_foothills","perimeter_elandor_mainland",5,7,"forward","junction:-2600:-1900","perimeter_attachment:elandor:land_001"},
		{"perimeter_span:elandor:hearthpine","elandor_hearthpine_vale","perimeter_elandor_mainland",7,11,"forward","perimeter_attachment:elandor:land_001","junction:-980:-2940"},
		{"perimeter_span:elandor:dawnmere","elandor_dawnmere_fields","perimeter_elandor_mainland",12,15,"forward","junction:-980:-2940","junction:900:-2920"},
		{"perimeter_span:elandor:silverleaf","elandor_silverleaf_glades","perimeter_elandor_mainland",16,20,"forward","junction:900:-2920","perimeter_attachment:elandor:land_007"},
		{"perimeter_span:elandor:starbough","elandor_starbough_vale","perimeter_elandor_mainland",20,22,"forward","perimeter_attachment:elandor:land_007","junction:2600:-1900"},
		{"perimeter_span:elandor:moonfall","elandor_moonfall_wood","perimeter_elandor_mainland",23,24,"forward","junction:2600:-1900","perimeter_attachment:elandor:land_034"},
		{"perimeter_span:elandor:glassroot","elandor_glassroot_wilds","perimeter_elandor_mainland",24,26,"forward","perimeter_attachment:elandor:land_034","junction:2500:-250"},
		{"perimeter_span:kragmar:blackwind","kragmar_blackwind_rise","perimeter_kragmar_mainland",1,3,"reverse","junction:-2500:250","perimeter_attachment:kragmar:land_037"},
		{"perimeter_span:kragmar:ossuary","kragmar_ossuary_reach","perimeter_kragmar_mainland",3,4,"reverse","perimeter_attachment:kragmar:land_037","junction:-2600:1900"},
		{"perimeter_span:kragmar:mournfen","kragmar_mournfen","perimeter_kragmar_mainland",5,7,"reverse","junction:-2600:1900","perimeter_attachment:kragmar:land_010"},
		{"perimeter_span:kragmar:stillgrave","kragmar_stillgrave_hollow","perimeter_kragmar_mainland",7,11,"reverse","perimeter_attachment:kragmar:land_010","junction:-1080:2930"},
		{"perimeter_span:kragmar:sunscar","kragmar_sunscar_flats","perimeter_kragmar_mainland",12,15,"reverse","junction:-1080:2930","junction:820:2960"},
		{"perimeter_span:kragmar:kapok","kragmar_kapok_cradle","perimeter_kragmar_mainland",16,20,"reverse","junction:820:2960","perimeter_attachment:kragmar:land_016"},
		{"perimeter_span:kragmar:raincall","kragmar_raincall_basin","perimeter_kragmar_mainland",20,22,"reverse","perimeter_attachment:kragmar:land_016","junction:2600:1900"},
		{"perimeter_span:kragmar:totemwater","kragmar_totemwater_reach","perimeter_kragmar_mainland",23,24,"reverse","junction:2600:1900","perimeter_attachment:kragmar:land_040"},
		{"perimeter_span:kragmar:thunderroot","kragmar_thunderroot_wilds","perimeter_kragmar_mainland",24,26,"reverse","perimeter_attachment:kragmar:land_040","junction:2500:250"},
	}
	local span_by_id={}
	for span_index=1,#source.perimeter_spans do local span=source.perimeter_spans[span_index]
		local expected=expected_spans[span_index]
		if span.id~=expected[1] or span.zone_id~=expected[2] or span.perimeter_id~=expected[3] or
				span.first_segment~=expected[4] or span.last_segment~=expected[5] or
				span.face_direction~=expected[6] or boundary_key(span.start_boundary)~=expected[7] or
				boundary_key(span.end_boundary)~=expected[8] or
				span.geometry_authority~="directed_canonical_perimeter_segment_span_v2" or
				span.displacement_source_ref~=span.perimeter_id or
				span.tie_rule~="perimeter_station_then_lower_zone_numeric_id" or
				span.control~=nil then
			return diag("perimeter_span_contract",span.id,
				"exact symbolic canonical segment span without copied geometry","changed")
		end
		span_by_id[span.id]=span
	end
	local aperture_ids,wing_ids={},{ }
	for i=1,#source.bay_mouth_apertures do aperture_ids[source.bay_mouth_apertures[i].id]=true end
	for i=1,#source.bay_closure_wings do wing_ids[source.bay_closure_wings[i].id]=true end
	local function terminal_key(terminal)
		if type(terminal)~="table" then return nil end
		if terminal.kind=="aperture_dry" and aperture_ids[terminal.aperture_id] and
				(terminal.side=="before" or terminal.side=="after") then
			return "a:"..terminal.aperture_id..":"..terminal.side
		elseif terminal.kind=="land_edge_transition" and edge_by_id[terminal.edge_id] and
				(terminal.edge_endpoint=="from" or terminal.edge_endpoint=="to") then
			return "e:"..terminal.edge_id..":"..terminal.edge_endpoint
		elseif terminal.kind=="wing_junction_tail_side" and wing_ids[terminal.wing_id] and
				(terminal.tail_side=="negative" or terminal.tail_side=="positive") then
			return "w:"..terminal.wing_id..":"..terminal.tail_side
		end
		return nil
	end
	local function terminal_boundary_id(terminal)
		local key=terminal_key(terminal)
		if not key then return nil end
		if terminal.kind=="aperture_dry" then
			return "bay_bank_terminal:"..terminal.aperture_id..":"..terminal.side
		elseif terminal.kind=="land_edge_transition" then
			return "bay_bank_terminal:"..terminal.edge_id..":"..terminal.edge_endpoint
		end
		return "bay_bank_terminal:"..terminal.wing_id..":junction"
	end
	local expected_banks={
		{"bay_bank:elandor_west:hearthpine","bay_elandor_west","face_arc:hearthpine:outer","a:bay_mouth_aperture:elandor_west:before","e:land_001:to"},
		{"bay_bank:elandor_west:copperfell","bay_elandor_west","face_arc:copperfell:bay","e:land_001:to","w:bay_wing:elandor_west:left:positive"},
		{"bay_bank:elandor_west:whitebridge","bay_elandor_west","face_arc:whitebridge:bay_head","w:bay_wing:elandor_west:left:negative","w:bay_wing:elandor_west:right:positive"},
		{"bay_bank:elandor_west:goldmead","bay_elandor_west","face_arc:goldmead:west_bay","w:bay_wing:elandor_west:right:negative","e:land_004:from"},
		{"bay_bank:elandor_west:dawnmere","bay_elandor_west","face_arc:dawnmere:outer","e:land_004:from","a:bay_mouth_aperture:elandor_west:after"},
		{"bay_bank:elandor_east:dawnmere","bay_elandor_east","face_arc:dawnmere:outer","a:bay_mouth_aperture:elandor_east:before","e:land_004:to"},
		{"bay_bank:elandor_east:goldmead","bay_elandor_east","face_arc:goldmead:east_bay","e:land_004:to","w:bay_wing:elandor_east:left:positive"},
		{"bay_bank:elandor_east:lorindor","bay_elandor_east","face_arc:lorindor:bay_head","w:bay_wing:elandor_east:left:negative","w:bay_wing:elandor_east:right:positive"},
		{"bay_bank:elandor_east:starbough","bay_elandor_east","face_arc:starbough:bay","w:bay_wing:elandor_east:right:negative","e:land_007:from"},
		{"bay_bank:elandor_east:silverleaf","bay_elandor_east","face_arc:silverleaf:outer","e:land_007:from","a:bay_mouth_aperture:elandor_east:after"},
		{"bay_bank:kragmar_west:stillgrave","bay_kragmar_west","face_arc:stillgrave:outer","e:land_010:to","a:bay_mouth_aperture:kragmar_west:before"},
		{"bay_bank:kragmar_west:mournfen","bay_kragmar_west","face_arc:mournfen:bay","w:bay_wing:kragmar_west:left:negative","e:land_010:to"},
		{"bay_bank:kragmar_west:speargrass","bay_kragmar_west","face_arc:speargrass:bay_head","w:bay_wing:kragmar_west:right:negative","w:bay_wing:kragmar_west:left:positive"},
		{"bay_bank:kragmar_west:redtusk","bay_kragmar_west","face_arc:redtusk:west_bay","e:land_013:from","w:bay_wing:kragmar_west:right:positive"},
		{"bay_bank:kragmar_west:sunscar","bay_kragmar_west","face_arc:sunscar:outer","a:bay_mouth_aperture:kragmar_west:after","e:land_013:from"},
		{"bay_bank:kragmar_east:sunscar","bay_kragmar_east","face_arc:sunscar:outer","e:land_013:to","a:bay_mouth_aperture:kragmar_east:before"},
		{"bay_bank:kragmar_east:redtusk","bay_kragmar_east","face_arc:redtusk:east_bay","w:bay_wing:kragmar_east:left:negative","e:land_013:to"},
		{"bay_bank:kragmar_east:whispering","bay_kragmar_east","face_arc:whispering:bay_head","w:bay_wing:kragmar_east:right:negative","w:bay_wing:kragmar_east:left:positive"},
		{"bay_bank:kragmar_east:raincall","bay_kragmar_east","face_arc:raincall:bay","e:land_016:from","w:bay_wing:kragmar_east:right:positive"},
		{"bay_bank:kragmar_east:kapok","bay_kragmar_east","face_arc:kapok:outer","a:bay_mouth_aperture:kragmar_east:after","e:land_016:from"},
	}
	local bank_by_id={}
	for i=1,#source.bay_bank_components do local row=source.bay_bank_components[i]
		local expected=expected_banks[i]
		local incidence=row.endpoint_face_incidence
		local fields_ok,fields_failure=closed_fields(row,
			"bay_bank_components["..i.."]",{"id","bay_id","direction",
				"water_side","start_terminal","end_terminal",
				"endpoint_face_incidence","geometry_authority","numeric_id"},
			"bay_bank_component_fields")
		if not fields_ok then return nil,fields_failure end
		if not dense(incidence) or #incidence~=2 then
			return diag("bay_bank_incidence_fields",row.id,
				"two closed incidence records",type(incidence))
		end
		for terminal_index=1,2 do
			local terminal
			if terminal_index==1 then terminal=row.start_terminal
			else terminal=row.end_terminal end
			local terminal_fields={
				aperture_dry={"kind","aperture_id","side"},
				land_edge_transition={"kind","edge_id","edge_endpoint"},
				wing_junction_tail_side={"kind","wing_id","tail_side"},
			}
			fields_ok,fields_failure=closed_fields(terminal,
				row.id..".terminal["..terminal_index.."]",
				type(terminal)=="table" and terminal_fields[terminal.kind] or {},
				"bay_bank_terminal_fields")
			if not fields_ok then return nil,fields_failure end
		end
		for incidence_index=1,#incidence do
			fields_ok,fields_failure=closed_fields(incidence[incidence_index],
				row.id..".endpoint_face_incidence["..incidence_index.."]",
				{"terminal_side","face_arc_id","face_arc_end"},
				"bay_bank_incidence_fields")
			if not fields_ok then return nil,fields_failure end
		end
		if row.id~=expected[1] or row.bay_id~=expected[2] or
				terminal_key(row.start_terminal)~=expected[4] or
				terminal_key(row.end_terminal)~=expected[5] or
				row.direction~="canonical_start_to_end" or row.water_side~="right" or
				row.geometry_authority~="materialized_same_bay_dry_column_bank_v1" or
				row.control~=nil or row.polygon~=nil or row.points~=nil or
				not dense(incidence) or #incidence~=2 or
				incidence[1].terminal_side~="start" or incidence[2].terminal_side~="end" or
				incidence[1].face_arc_id~=expected[3] or incidence[2].face_arc_id~=expected[3] or
				incidence[1].face_arc_end~="component_start" or
				incidence[2].face_arc_end~="component_end" then
			return diag("bay_bank_component_contract",row.id,
				"exact coordinate-free ordered 20-component roster","changed")
		end
		bank_by_id[row.id]=row
	end
	local perimeter_bank_terminals={
		["perimeter_span:elandor:hearthpine"]={false,"a:bay_mouth_aperture:elandor_west:before"},
		["perimeter_span:elandor:dawnmere"]={"a:bay_mouth_aperture:elandor_west:after","a:bay_mouth_aperture:elandor_east:before"},
		["perimeter_span:elandor:silverleaf"]={"a:bay_mouth_aperture:elandor_east:after",false},
		["perimeter_span:kragmar:stillgrave"]={"a:bay_mouth_aperture:kragmar_west:before",false},
		["perimeter_span:kragmar:sunscar"]={"a:bay_mouth_aperture:kragmar_east:before","a:bay_mouth_aperture:kragmar_west:after"},
		["perimeter_span:kragmar:kapok"]={false,"a:bay_mouth_aperture:kragmar_east:after"},
	}
	local island_by_id={}
	for i=1,#source.islands do island_by_id[source.islands[i].id]=source.islands[i] end
	local arc_by_id={}
	local bank_component_incidence=declared_bank_incidence_counts(source.face_arcs,
		bank_by_id)
	if bank_component_incidence._failure then
		return nil,bank_component_incidence._failure
	end
	for i=1,#source.face_arcs do local row=source.face_arcs[i]
		local fields_ok,fields_failure=closed_fields(row,"face_arcs["..i.."]",
			{"id","zone_id","kind","geometry_ref","source_refs",
				"authority_components","geometry_authority","from_boundary_id",
				"to_boundary_id","shore_owner_zone_id","shore_tie_rule",
				"projection_rule","numeric_id"},"face_arc_fields")
		if not fields_ok then return nil,fields_failure end
		if not zone_ids[row.zone_id] or type(row.from_boundary_id)~="string" or
				type(row.to_boundary_id)~="string" or type(row.kind)~="string" or
				row.geometry_ref~=row.id or
				row.geometry_authority~="ordered_face_arc_authority_components_v2" or
				not dense(row.source_refs) or not dense(row.authority_components) or
				row.control~=nil or row.segment_spans~=nil or
				row.perimeter_span_ids~=nil or
				row.shore_owner_zone_id~=row.zone_id or
				row.shore_tie_rule~="lower_zone_numeric_id" or
				row.projection_rule~="zone_inside_coast_outside" then
			return diag("face_arc_contract",row.id,
				"ordered symbolic perimeter/literal authority graph","invalid")
		end
		for ref_index=1,#row.source_refs do
			if type(row.source_refs[ref_index])~="string" or
					not geometry_ref_ids[row.source_refs[ref_index]] then
				return diag("face_arc_source_ref",row.id,
					"declared perimeter/bay/island source",
					tostring(row.source_refs[ref_index]))
			end
		end
		local previous_end
		local projected_refs={}
		local component_kinds={perimeter_span=0,bay_bank=0,literal_arc=0}
		for component_index=1,#row.authority_components do
			local component=row.authority_components[component_index]
			if type(component)~="table" then return diag("face_arc_component_fields",
				row.id..":"..component_index,"closed component record",type(component)) end
			component_kinds[component.kind]=(component_kinds[component.kind] or 0)+1
			if component.kind=="perimeter_span" then
				fields_ok,fields_failure=closed_fields(component,
					row.id..".authority_components["..component_index.."]",
					{"kind","ref_id","direction","from_boundary_id","to_boundary_id",
						"from_terminal","to_terminal"},"face_arc_component_fields")
				if not fields_ok then return nil,fields_failure end
				local span=span_by_id[component.ref_id]
				projected_refs[#projected_refs+1]=span and span.perimeter_id or component.ref_id
				local first_key,last_key=span and boundary_key(span.start_boundary),
					span and boundary_key(span.end_boundary)
				if span and span.face_direction=="reverse" then first_key,last_key=last_key,first_key end
				local expected_terminals=perimeter_bank_terminals[component.ref_id] or {false,false}
				for terminal_index=1,2 do
					local terminal
					if terminal_index==1 then terminal=component.from_terminal
					else terminal=component.to_terminal end
					if terminal~=false then
						fields_ok,fields_failure=closed_fields(terminal,
							row.id..".perimeter_terminal["..terminal_index.."]",
							{"kind","aperture_id","side"},"perimeter_bank_terminal_fields")
						if not fields_ok then return nil,fields_failure end
					end
				end
				local from_terminal_key=component.from_terminal and
					terminal_key(component.from_terminal) or false
				local to_terminal_key=component.to_terminal and
					terminal_key(component.to_terminal) or false
				if from_terminal_key then first_key=terminal_boundary_id(component.from_terminal) end
				if to_terminal_key then last_key=terminal_boundary_id(component.to_terminal) end
				if not span or span.zone_id~=row.zone_id or
						component.direction~=span.face_direction or
						from_terminal_key~=expected_terminals[1] or
						to_terminal_key~=expected_terminals[2] or
						component.from_boundary_id~=first_key or
						component.to_boundary_id~=last_key or component.control~=nil then
					return diag("face_arc_perimeter_span",row.id..":"..component_index,
						"exact owning symbolic directed perimeter span","invalid")
				end
			elseif component.kind=="bay_bank" then
				fields_ok,fields_failure=closed_fields(component,
					row.id..".authority_components["..component_index.."]",
					{"kind","ref_id","direction","from_boundary_id","to_boundary_id"},
					"face_arc_component_fields")
				if not fields_ok then return nil,fields_failure end
				local bank=bank_by_id[component.ref_id]
				projected_refs[#projected_refs+1]=bank and bank.bay_id or component.ref_id
				if not bank or component.direction~="forward" or
						bank.endpoint_face_incidence[1].face_arc_id~=row.id or
						bank.endpoint_face_incidence[2].face_arc_id~=row.id or
						component.from_boundary_id~=terminal_boundary_id(bank.start_terminal) or
						component.to_boundary_id~=terminal_boundary_id(bank.end_terminal) or
						component.control~=nil then
					return diag("face_arc_bay_bank",row.id..":"..component_index,
						"one owning structured Bay-bank component","invalid")
				end
			elseif component.kind=="literal_arc" then
				fields_ok,fields_failure=closed_fields(component,
					row.id..".authority_components["..component_index.."]",
					{"kind","boundary_role","source_ref","control",
						"from_boundary_id","to_boundary_id"},"face_arc_component_fields")
				if not fields_ok then return nil,fields_failure end
				projected_refs[#projected_refs+1]=component.source_ref
				local role_allowed={fixed_holy=true,island_coast=true}
				if not role_allowed[component.boundary_role] or
						not geometry_ref_ids[component.source_ref] or
						not dense(component.control) or #component.control<2 or
						component.from_boundary_id~=junction_id(component.control[1]) or
						component.to_boundary_id~=junction_id(component.control[#component.control]) then
					return diag("face_arc_literal_component",row.id..":"..component_index,
						"simple literal bay/Holy/island sub-polyline","invalid")
				end
				for point_index=1,#component.control do
					if not point_valid(component.control[point_index],false) then
						return diag("face_arc_control",row.id,"integer literal component",point_index)
					end
				end
				for first=1,#component.control-1 do
					for second=first+2,#component.control-1 do
						local closed=component.control[1].x==component.control[#component.control].x and
							component.control[1].z==component.control[#component.control].z
						if not (closed and first==1 and second==#component.control-1) and
								intersects(component.control[first],component.control[first+1],
								component.control[second],component.control[second+1]) then
							return diag("face_arc_literal_planarity",row.id..":"..component_index,
								"simple literal sub-polyline",first..":"..second)
						end
					end
				end
			else return diag("face_arc_component_kind",row.id,
				"perimeter_span, bay_bank, or fixed literal_arc",tostring(component.kind)) end
			if previous_end and previous_end~=component.from_boundary_id then
				return diag("face_arc_component_closure",row.id,previous_end,
					component.from_boundary_id)
			end
			previous_end=component.to_boundary_id
		end
		if row.from_boundary_id~=row.authority_components[1].from_boundary_id or
				row.to_boundary_id~=previous_end then
			return diag("face_arc_component_endpoints",row.id,
				"arc endpoints equal first/last component boundary","changed")
		end
		if #projected_refs~=#row.source_refs then
			return diag("face_arc_source_projection",row.id,#projected_refs,#row.source_refs)
		end
		for ref_index=1,#projected_refs do
			if projected_refs[ref_index]~=row.source_refs[ref_index] then
				return diag("face_arc_source_projection",row.id,
					projected_refs[ref_index],row.source_refs[ref_index])
			end
		end
		local kind_allowed={coast_shore=true,bay_shore=true,
			coast_bay_shore=true,fixed_holy_arc=true,island_perimeter_arc=true}
		if not kind_allowed[row.kind] then
			return diag("face_arc_kind",row.id,"closed arc kind",row.kind)
		end
		local composition_ok=
			(row.kind=="coast_shore" and component_kinds.perimeter_span>0 and component_kinds.bay_bank==0 and component_kinds.literal_arc==0) or
			(row.kind=="bay_shore" and component_kinds.bay_bank>0 and component_kinds.perimeter_span==0 and component_kinds.literal_arc==0) or
			(row.kind=="coast_bay_shore" and component_kinds.bay_bank>0 and component_kinds.perimeter_span>0 and component_kinds.literal_arc==0) or
			(row.kind=="fixed_holy_arc" and component_kinds.literal_arc==1 and #row.authority_components==1) or
			(row.kind=="island_perimeter_arc" and component_kinds.literal_arc==1 and #row.authority_components==1)
		if not composition_ok then return diag("face_arc_kind_composition",row.id,
			"kind matches exact component families","invalid") end
		if row.kind=="island_perimeter_arc" then
			local island=#row.source_refs==1 and island_by_id[row.source_refs[1]]
			local control=row.authority_components[1] and row.authority_components[1].control
			if not island or island.zone_id~=row.zone_id or row.from_boundary_id~=row.to_boundary_id or
					#row.authority_components~=1 or not control or #control~=#island.polygon then
				return diag("face_island_arc",row.id,
					"exact owning closed island polygon","invalid")
			end
			for point_index=1,#control do local a,b=control[point_index],island.polygon[point_index]
				if a.x~=b.x or a.z~=b.z then return diag("face_island_arc_geometry",row.id,
					"exact island polygon",point_index) end
			end
		elseif row.kind=="fixed_holy_arc" then
			if #row.source_refs~=1 or row.source_refs[1]~="perimeter_holy_grounds" then
				return diag("face_fixed_holy_arc",row.id,
					"Holy Grounds perimeter source","invalid")
			end
		else
			local continent=row.zone_id:match("^(elandor)_") or row.zone_id:match("^(kragmar)_")
			for ref_index=1,#row.source_refs do
				if not continent or not row.source_refs[ref_index]:match("_"..continent) then
					return diag("face_arc_continent_ref",row.id,continent,row.source_refs[ref_index])
				end
			end
		end
		arc_by_id[row.id]=row
	end
	for i=1,#source.bay_bank_components do local bank=source.bay_bank_components[i]
		if bank_component_incidence[bank.id]~=1 then
			return diag("bay_bank_component_incidence",bank.id,1,
				bank_component_incidence[bank.id] or 0)
		end
	end
	local edge_bank_boundary={}
	for i=1,#source.bay_closure_wings do local wing=source.bay_closure_wings[i]
		local boundary="bay_bank_terminal:"..wing.id..":junction"
		for j=1,#wing.junction_edge_ids do local edge=edge_by_id[wing.junction_edge_ids[j]]
			if not edge then
				return diag("bay_closure_wing_junction_ref",wing.id,
					"existing incident edge",wing.junction_edge_ids[j])
			elseif edge.from_junction_id==wing.junction_ref then
				edge_bank_boundary[edge.id..":from"]=boundary
			elseif edge.to_junction_id==wing.junction_ref then
				edge_bank_boundary[edge.id..":to"]=boundary
			else
				return diag("bay_closure_wing_junction_ref",wing.id,
					"incident edge endpoint at wing J",edge.id)
			end
		end
	end
	for i=1,#source.bay_bank_components do local bank=source.bay_bank_components[i]
		for _,terminal in ipairs({bank.start_terminal,bank.end_terminal}) do
			if terminal.kind=="land_edge_transition" then
				local key=terminal.edge_id..":"..terminal.edge_endpoint
				local boundary=terminal_boundary_id(terminal)
				if edge_bank_boundary[key] and edge_bank_boundary[key]~=boundary then
					return diag("bay_bank_edge_terminal_identity",key,boundary,
						edge_bank_boundary[key])
				end
				edge_bank_boundary[key]=boundary
			end
		end
	end
	local edge_incidence,arc_incidence={},{}
	local edge_forward_face,edge_reverse_face={},{}
	local face_zone_seen={}
	for i=1,#source.zone_faces do local face=source.zone_faces[i]
		if not zone_ids[face.zone_id] or face_zone_seen[face.zone_id] or
				face.orientation~="counterclockwise" or
				face.tie_rule~="lower_zone_numeric_id" or not dense(face.cycle) or
				#face.cycle==0 then
			return diag("zone_face_contract",face.id,"one canonical oriented cycle per zone","invalid")
		end
		face_zone_seen[face.zone_id]=true
		local first_junction,previous_end
		local boundary_junction_seen={}
		for j=1,#face.cycle do local ref=face.cycle[j]
			local start_id,end_id
			if ref.kind=="shared_edge" then
				local edge=edge_by_id[ref.ref_id]
				local attachment=attachment_by_edge[ref.ref_id]
				if not edge or (edge.left_zone~=face.zone_id and edge.right_zone~=face.zone_id) or
						(ref.direction~="forward" and ref.direction~="reverse") or
						ref.clip_attachment_id~=(attachment and attachment.id or false) or
						ref.first_control~=nil or ref.last_control~=nil or ref.clip_rule~=nil then
					return diag("zone_face_edge_ref",face.id,"incident oriented shared edge",ref.ref_id)
				end
				local expected_direction=edge.left_zone==face.zone_id and "forward" or "reverse"
				if ref.direction~=expected_direction then
					return diag("face_edge_probe_zone",face.id..":"..ref.ref_id,
						expected_direction,ref.direction)
				end
				local from_id=edge.from_junction_id
				local to_id=edge.to_junction_id
				if attachment then
					if attachment.edge_endpoint=="from" then from_id=attachment.id else to_id=attachment.id end
				end
				from_id=edge_bank_boundary[edge.id..":from"] or from_id
				to_id=edge_bank_boundary[edge.id..":to"] or to_id
				start_id=ref.direction=="forward" and from_id or to_id
				end_id=ref.direction=="forward" and to_id or from_id
				edge_incidence[ref.ref_id]=edge_incidence[ref.ref_id] or {}
				edge_incidence[ref.ref_id][#edge_incidence[ref.ref_id]+1]=ref.direction
				if ref.direction=="forward" then edge_forward_face[ref.ref_id]=face.zone_id
				else edge_reverse_face[ref.ref_id]=face.zone_id end
			elseif ref.kind=="arc" then
				local arc=arc_by_id[ref.ref_id]
				if not arc or arc.zone_id~=face.zone_id or ref.direction~="forward" then
					return diag("zone_face_arc_ref",face.id,"own forward arc",ref.ref_id)
				end
				start_id,end_id=arc.from_boundary_id,arc.to_boundary_id
				arc_incidence[ref.ref_id]=(arc_incidence[ref.ref_id] or 0)+1
			else return diag("zone_face_ref_kind",face.id,"shared_edge/arc",ref.kind) end
			if previous_end and previous_end~=start_id then
				return diag("zone_face_closure",face.id,previous_end,start_id)
			end
			first_junction=first_junction or start_id
			if boundary_junction_seen[end_id] and j<#face.cycle then
				return diag("zone_face_planarity",face.id,"no repeated interior junction",end_id)
			end
			boundary_junction_seen[end_id]=true previous_end=end_id
		end
		if previous_end~=first_junction then return diag("zone_face_closure",face.id,first_junction,previous_end) end
	end
	for i=1,#source.land_edges do local edge=source.land_edges[i]
		if edge_forward_face[edge.id]~=edge.left_zone or
				edge_reverse_face[edge.id]~=edge.right_zone then
			return diag("face_edge_probe_zone",edge.id,
				"declared left/right owner equals abstract face incidence","invalid")
		end
		local probe_index=edge.probe_segment_index
		local first,second=edge.control[probe_index],edge.control[probe_index+1]
		local left_cross=cross(first,second,edge.left_probe)
		local right_cross=cross(first,second,edge.right_probe)
		if left_cross<=0 or right_cross>=0 then return diag("face_edge_probe_side",
			edge.id,"left probe > 0 and right probe < 0 for directed control",
			left_cross..":"..right_cross) end
	end
	local global_segments={}
	local function add_segments(owner,points,water_ref)
		for i=1,#points-1 do global_segments[#global_segments+1]={
			owner=owner,index=i,a=points[i],b=points[i+1],water_ref=water_ref} end
	end
	for i=1,#source.land_edges do add_segments(source.land_edges[i].id,
		source.land_edges[i].control) end
	for i=1,#source.face_arcs do local arc=source.face_arcs[i]
		for component_index=1,#arc.authority_components do local component=arc.authority_components[component_index]
			if component.kind=="literal_arc" then
				local water_ref=component.boundary_role=="bay_shore" and component.source_ref or false
				add_segments(arc.id..":"..component_index,component.control,water_ref)
			end
		end
	end
	local function same_point(a,b) return a.x==b.x and a.z==b.z end
	for i=1,#global_segments do local a=global_segments[i]
		for j=i+1,#global_segments do local b=global_segments[j]
			if a.owner~=b.owner and intersects(a.a,a.b,b.a,b.b) then
				if (a.water_ref and not b.water_ref) or (b.water_ref and not a.water_ref) or
						(a.water_ref and a.water_ref==b.water_ref) then
					-- A literal bay-shore component declares this as a possible raw-water
					-- intersection class. Exact location/precedence is a Stage-2 integer
					-- proof; two different bays are never interchangeable.
				else
				local common=0
				if same_point(a.a,b.a) or same_point(a.a,b.b) then common=common+1 end
				if same_point(a.b,b.a) or same_point(a.b,b.b) then common=common+1 end
				local collinear=cross(a.a,a.b,b.a)==0 and cross(a.a,a.b,b.b)==0
				if common~=1 or collinear and
						((between(a.a,a.b,b.a) and not same_point(b.a,a.a) and not same_point(b.a,a.b)) or
						 (between(a.a,a.b,b.b) and not same_point(b.b,a.a) and not same_point(b.b,a.b)) or
						 (between(b.a,b.b,a.a) and not same_point(a.a,b.a) and not same_point(a.a,b.b)) or
						 (between(b.a,b.b,a.b) and not same_point(a.b,b.a) and not same_point(a.b,b.b))) then
					return diag("face_global_planarity",a.owner..":"..b.owner,
						"one exact declared endpoint or same authored bay component class",
						a.index..":"..b.index)
				end
				end
			end
		end
	end
	for edge_index=1,#source.land_edges do local edge=source.land_edges[edge_index]
		local edge_id=edge.id local incidence=edge_incidence[edge_id]
		if not incidence or #incidence~=2 or incidence[1]==incidence[2] then
			return diag("zone_face_edge_incidence",edge_id,"twice in opposite directions","invalid")
		end
	end
	for arc_index=1,#source.face_arcs do local arc_id=source.face_arcs[arc_index].id
		if arc_incidence[arc_id]~=1 then
		return diag("zone_face_arc_incidence",arc_id,1,arc_incidence[arc_id])
	end end
	local dual={}
	for zone_id in pairs(zone_ids) do dual[zone_id]={} end
	for edge_index=1,#source.land_edges do local edge=source.land_edges[edge_index]
		dual[edge.zone_a][#dual[edge.zone_a]+1]=edge.zone_b
		dual[edge.zone_b][#dual[edge.zone_b]+1]=edge.zone_a
	end
	local queue={"elandor_hearthpine_vale"} local head=1
	local reached={[queue[1]]=true}
	while head<=#queue do local current=queue[head] head=head+1
		for i=1,#dual[current] do local next_id=dual[current][i]
			if not reached[next_id] then reached[next_id]=true queue[#queue+1]=next_id end
		end
	end
	local reached_count=0 for _ in pairs(reached) do reached_count=reached_count+1 end
	if #source.land_edges~=61 or reached_count~=36 then
		return diag("zone_face_dual_graph","land_edges","61 edges/36 connected mainland zones",
			#source.land_edges.."/"..reached_count)
	end
	for _,island_zone in ipairs({"front_wyrmglass_crown","front_stormscale_summit"}) do
		for edge_index=1,#source.land_edges do local edge=source.land_edges[edge_index]
			if edge.zone_a==island_zone or edge.zone_b==island_zone then
			return diag("island_land_edge_forbidden",edge.id,"no island land edge",island_zone)
		end end
	end
	local station_ids,station_by_id={},{}
	local station_kind_allowed={hub=true,start_gate=true,capital_gate=true}
	for i=1,#source.route_stations do local row=source.route_stations[i]
		if not zone_ids[row.zone_id] or not station_kind_allowed[row.kind] or not point_valid(row.position,false) or (row.gate_ref~=false and type(row.gate_ref)~="string") then return diag("route_station_contract",row.id,"known zone/kind/point/gate","invalid") end
		station_ids[row.id]=true station_by_id[row.id]=row
	end
	local route_class_by_id={}
	local route_class_expected={primary={1,12,12,7,16,"road_primary_v1",8},
		secondary={1,8,8,5,12,"road_secondary_v1",6},
		trail={1,4,4,3,8,"road_trail_v1",4}}
	for i=1,#source.route_classes do local row=source.route_classes[i]
		local expected=route_class_expected[row.id]
		if not expected or type(row.max_grade)~="table" or
				row.max_grade.numerator~=expected[1] or
				row.max_grade.denominator~=expected[2] or
				row.minimum_transition_run~=expected[3] or row.grade_step~=1 or
				row.visible_width~=expected[4] or row.exclusion_width~=expected[5] or
				row.cross_section_id~=expected[6] or row.lateral_blend_width~=expected[7] or
				row.grade_phase_rule~="flat_run_at_fixed_interface" or
				row.transition_semantic_id~="road_climb_stair_v1" then
			return diag("route_class_profile",row.id,
				"closed grade/spacing/cross-section/blend/transition","invalid")
		end
		route_class_by_id[row.id]=row
	end
	local route_classes={primary=true,secondary=true,trail=true}
	local route_ids,route_by_id,route_counts={},{},{primary=0,secondary=0,trail=0}
	for i=1,#source.routes do
		local row=source.routes[i]
		local edge=edge_by_id[row.boundary_id]
		if not edge or row.zone_a~=edge.zone_a or
				row.zone_b~=edge.zone_b then
			return diag("route_boundary_reference",row.id,row.boundary_id,"mismatch")
		end
		if edge.boundary_only then return diag("boundary_only_route_forbidden",row.id,
			"boundary-only edges absent from routes",row.boundary_id) end
		if not route_classes[row.class] or not dense(row.centreline) or
				#row.centreline<5 or type(row.crossing_station)~="number" or row.crossing_station<2 or row.crossing_station>#row.centreline-1 then return diag("route_geometry",row.id,"valid class and complete centreline","invalid") end
		route_counts[row.class]=route_counts[row.class]+1
		for j=1,#row.centreline do if not point_valid(row.centreline[j],false) then return diag("route_point",row.id,"integer x/z point","invalid") end end
		local crossing=row.centreline[row.crossing_station]
		local on_boundary,side_a,side_b=false,nil,nil
		for j=1,#edge.control-1 do if cross(edge.control[j],edge.control[j+1],crossing)==0 and between(edge.control[j],edge.control[j+1],crossing) then on_boundary=true side_a=cross(edge.control[j],edge.control[j+1],row.centreline[row.crossing_station-1]) side_b=cross(edge.control[j],edge.control[j+1],row.centreline[row.crossing_station+1]) break end end
		if not on_boundary then return diag("route_crosses_boundary",row.id,true,false) end
		if side_a==0 or side_b==0 or side_a*side_b>=0 then return diag("route_crossing_sides",row.id,"opposite nonzero boundary sides",tostring(side_a)..":"..tostring(side_b)) end
		local expected_a_sign=edge.left_zone==row.zone_a and 1 or -1
		if side_a*expected_a_sign<=0 then
			return diag("route_face_incidence",edge.id,
				"route zone_a approach on its independently declared face",side_a)
		end
		local station_a,station_b=station_by_id[row.station_a_id],station_by_id[row.station_b_id]
		if not station_a or not station_b or station_a.zone_id~=row.zone_a or station_b.zone_id~=row.zone_b or row.centreline[1].x~=station_a.position.x or row.centreline[1].z~=station_a.position.z or row.centreline[#row.centreline].x~=station_b.position.x or row.centreline[#row.centreline].z~=station_b.position.z then return diag("route_station_ref",row.id,"matching endpoint stations","mismatch") end
		if station_a.gate_ref~=row.gate_ref_a or station_b.gate_ref~=row.gate_ref_b then return diag("route_gate_ref",row.id,"station-owned gate refs","mismatch") end
		if row.endpoint_a_id==row.endpoint_b_id or type(row.boundary_interface_id)~="string" or row.grade_phase~="class_default" then return diag("route_interfaces",row.id,"distinct endpoints/crossing/class-default phase","invalid") end
		route_ids[row.id]=true route_by_id[row.id]=row
	end
	for _,expected_row in ipairs({{"primary",30},{"secondary",24},{"trail",3}}) do local class,expected=expected_row[1],expected_row[2] if route_counts[class]~=expected then return diag("route_class_count",class,expected,route_counts[class]) end end
	local route_interface_ids,route_interface_by_id={},{}
	for i=1,#source.route_interfaces do local row=source.route_interfaces[i]
		if not route_ids[row.route_id] or not point_valid(row.position,false) or
				type(row.direction)~="string" or row.direction=="" then return diag("route_interface_contract",row.id,"route/point/direction","invalid") end
		if type(row.grade_limit)~="table" or row.grade_limit.numerator~=1 or
				row.grade_limit.denominator~=12 or row.grade_phase~="flat_run_12" or
				row.transition_semantic_id~="road_climb_stair_v1" then
			return diag("route_interface_grade",row.id,"fixed 1:12 flat phase and climb semantic","invalid")
		end
		if row.kind=="endpoint" and not station_ids[row.station_id] then return diag("route_interface_station_ref",row.id,"known station",row.station_id) end
		if row.kind~="endpoint" and row.kind~="boundary_crossing" then return diag("route_interface_kind",row.id,"endpoint/boundary_crossing",row.kind) end
		route_interface_ids[row.id]=true route_interface_by_id[row.id]=row
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
			if row.candidates~=nil then return diag("anchor_placement_fields",row.id,"fixed position only","candidates present") end
		elseif row.placement_mode == "candidate_set" then
			if not dense(row.candidates) or #row.candidates == 0 then return diag("candidate_anchor_set",row.id,"non-empty dense array","invalid") end
			for j=1,#row.candidates do if not point_valid(row.candidates[j],false) then return diag("candidate_anchor_point",row.id,"integer x/z point","invalid") end end
			if row.position~=nil then return diag("anchor_placement_fields",row.id,"candidate set only","position present") end
		else return diag("anchor_placement_mode",row.id,"fixed/candidate_set",row.placement_mode) end
		if family=="rare" then
			if row.placement_mode~="candidate_set" then return diag("rare_anchor_placement_mode",row.id,"candidate_set",row.placement_mode) end
			if row.patrol_route~=nil then return diag("rare_patrol_absolute_forbidden",row.id,"candidate-relative offsets only","patrol_route present") end
			if row.patrol_coordinate_space~="selected_candidate_relative" then return diag("rare_patrol_coordinate_space",row.id,"selected_candidate_relative",row.patrol_coordinate_space) end
			if not dense(row.patrol_offsets) or #row.patrol_offsets<2 or #row.patrol_offsets>3 then return diag("rare_patrol_offsets",row.id,"2..3 ordered offsets","invalid") end
			for j=1,#row.patrol_offsets do if not point_valid(row.patrol_offsets[j],false) then return diag("rare_patrol_offset",row.id..":"..j,"integer x/z offset","invalid") end end
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
	for i=1,#source.islands do local row=source.islands[i]
		if row.geometry_authority~="closed_island_face_arc" or
				row.source_geometry_role~="constraint_projection_and_envelope_only" or
				row.ordered_component_rule~="closed_face_arc_forward" or
				not arc_by_id[row.closed_arc_id] or
				arc_by_id[row.closed_arc_id].source_refs[1]~=row.id then
			return diag("face_arc_sole_geometry_authority",row.id,
				"one exact closed forward island face arc; polygon only constrains envelope",
				"invalid")
		end
		island_ids[row.id]=true island_by_id[row.id]=row
	end
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
		if row.anchor_id then
			local anchor=anchor_by_id[row.anchor_id]
			if not anchor or anchor.placement_mode~="fixed" or anchor.slot_id~=row.kind then return diag("island_target_anchor_mode",row.id,"fixed matching target anchor",row.anchor_id) end
			if not anchor.position or anchor.position.x~=row.position.x or anchor.position.z~=row.position.z then return diag("island_target_anchor_position",row.id,"fixed anchor position",row.anchor_id) end
		end
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
	local island_route_interface_by_id={}
	for i=1,#source.island_route_interfaces do local row=source.island_route_interfaces[i] local route=island_route_by_id[row.route_id] local station=island_station_by_id[row.station_id]
		if not route or not station or row.kind~="endpoint" or not point_valid(row.position,false) or row.position.x~=station.position.x or row.position.z~=station.position.z or (station.id~=route.from_station_id and station.id~=route.to_station_id) then return diag("island_route_interface_contract",row.id,"route endpoint station/point","invalid") end
		interface_counts[row.route_id]=(interface_counts[row.route_id] or 0)+1
		island_route_interface_by_id[row.id]=row
	end
	for i=1,#source.island_routes do if interface_counts[source.island_routes[i].id]~=2 then return diag("island_route_interface_count",source.island_routes[i].id,2,interface_counts[source.island_routes[i].id]) end end
	local surface_core_seen,surface_gate_by_route,surface_position_levels={},{},{}
	local surface_control_count_by_zone={}
	local surface_role={home_low=true,front_high=true,lateral_neighbor=true}
	for i=1,#source.surface_level_controls do local row=source.surface_level_controls[i]
		local zone=zone_by_id[row.zone_id]
		local control_position=row.position
		if not zone or type(row.level)~="number" or row.level%1~=0 or
				row.level<zone.level_min or row.level>zone.level_max then
			return diag("surface_level_bracket",row.id,
				zone and zone.level_min..".."..zone.level_max or "known zone",row.level)
		end
		surface_control_count_by_zone[row.zone_id]=
			(surface_control_count_by_zone[row.zone_id] or 0)+1
		if row.kind=="zone_core" then
			local station=station_by_id[row.station_id]
			if surface_core_seen[row.zone_id] or not station or
					station.zone_id~=row.zone_id or
					row.interpolation_id~="inverse_distance_squared_q16_v1" then
				return diag("surface_level_core",row.id,
					"one core control at own hub with closed interpolation","invalid")
			end
			surface_core_seen[row.zone_id]=true
			control_position=station.position
		elseif row.kind=="road_gate" then
			local route=route_by_id[row.route_id]
			local interface=route_interface_by_id[row.interface_id]
			if not route or not interface or interface.kind~="endpoint" or
					interface.route_id~=route.id or not surface_role[row.progression_role] or
					not point_valid(row.position,false) or
					type(row.endgame_exception)~="boolean" or
					row.interpolation_id~="inverse_distance_squared_q16_v1" then
				return diag("surface_level_gate",row.id,
					"route endpoint/role/exception/closed interpolation","invalid")
			end
			local side=interface.id==route.endpoint_a_id and "a" or
				(interface.id==route.endpoint_b_id and "b" or nil)
			if not side or (side=="a" and route.zone_a or route.zone_b)~=row.zone_id then
				return diag("surface_level_gate_zone",row.id,row.zone_id,"mismatch")
			end
			local expected_position=side=="a" and route.centreline[2] or
				route.centreline[#route.centreline-1]
			if row.position.x~=expected_position.x or row.position.z~=expected_position.z then
				return diag("surface_level_gate_position",row.id,
					expected_position.x..":"..expected_position.z,
					row.position.x..":"..row.position.z)
			end
			surface_gate_by_route[route.id]=surface_gate_by_route[route.id] or {}
			if surface_gate_by_route[route.id][side] then return diag("surface_level_gate_duplicate",
				row.id,"one control per side",side) end
			surface_gate_by_route[route.id][side]=row
		elseif row.kind=="level_60_endpoint" then
			local station=island_station_by_id[row.island_station_id]
			if not station or row.level~=60 or zone.level_min~=60 or zone.level_max~=60 or
					row.interpolation_id~="flat_level_60_v1" then
				return diag("surface_level_60_endpoint",row.id,
					"own island station, exact flat level 60","invalid")
			end
			control_position=station.position
		else return diag("surface_level_kind",row.id,
			"zone_core/road_gate/level_60_endpoint",row.kind) end
		local position_key=row.zone_id..":"..control_position.x..":"..control_position.z
		if surface_position_levels[position_key] and
				surface_position_levels[position_key]~=row.level then
			return diag("surface_level_control_conflict",row.id,
				surface_position_levels[position_key],row.level)
		end
		surface_position_levels[position_key]=row.level
	end
	for i=1,#source.zones do local zone_id=source.zones[i].id
		if not surface_core_seen[zone_id] then
			return diag("surface_level_core_missing",zone_id,"one core","missing")
		end
		if surface_control_count_by_zone[zone_id]>
				policies.surface_level_interpolation.max_control_count then
			return diag("surface_level_control_count",zone_id,
				policies.surface_level_interpolation.max_control_count,
				surface_control_count_by_zone[zone_id])
		end
	end
	local endgame_routes={route_043=true,route_048=true,route_049=true,
		route_054=true,route_055=true,route_057=true}
	for i=1,#source.routes do local route=source.routes[i]
		local pair=surface_gate_by_route[route.id]
		if not pair or not pair.a or not pair.b then return diag("surface_level_gate_missing",
			route.id,"two endpoint controls","missing") end
		local declared=endgame_routes[route.id]==true
		if pair.a.endgame_exception~=declared or pair.b.endgame_exception~=declared then
			return diag("surface_level_endgame_exception",route.id,declared,
				tostring(pair.a.endgame_exception)..":"..tostring(pair.b.endgame_exception))
		end
		if not declared and math.abs(pair.a.level-pair.b.level)>2 then
			return diag("surface_level_gate_agreement",route.id,"difference <= 2",
				math.abs(pair.a.level-pair.b.level))
		end
	end
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
	local frame=source.constants.mainland_frame
	for i=1,#source.perimeters do local row=source.perimeters[i]
		local base_ok,base_failure=base_raster_valid(row,row.id,row.polygon,true,
			function(point) return point.x>=frame.min_x and point.x<=frame.max_x and
				point.z>=frame.min_z and point.z<=frame.max_z end)
		if not base_ok then return nil,base_failure end
	end
	for i=1,#source.islands do local row=source.islands[i]
		local base_ok,base_failure=base_raster_valid(row,row.id,row.polygon,true,
			function(point) return
				math.abs(point.x-row.center.x)<=row.envelope.radius_x and
				math.abs(point.z-row.center.z)<=row.envelope.radius_z end)
		if not base_ok then return nil,base_failure end
	end
	local expected_coast_components={}
	for span_index=1,#source.perimeter_spans do
		expected_coast_components[#expected_coast_components+1]=
			source.perimeter_spans[span_index].id
	end
	expected_coast_components[#expected_coast_components+1]=
		"face_arc:gravesalt:holy_west"
	expected_coast_components[#expected_coast_components+1]=
		"face_arc:skyglass:holy_east"
	expected_coast_components[#expected_coast_components+1]=
		"face_arc:wyrmglass:island"
	expected_coast_components[#expected_coast_components+1]=
		"face_arc:stormscale:island"
	if #expected_coast_components~=#partition.coast_source_allowed_component_ids then
		return diag("coast_source_component_roster","geometry_policies.world_partition",
			#expected_coast_components,#partition.coast_source_allowed_component_ids)
	end
	for component_index=1,#expected_coast_components do
		local expected=expected_coast_components[component_index]
		local observed=partition.coast_source_allowed_component_ids[component_index]
		local arc=arc_by_id[observed]
		local literal=arc and #arc.authority_components==1 and
			arc.authority_components[1]
		local expected_role
		if component_index>#source.perimeter_spans and
				component_index<=#source.perimeter_spans+2 then
			expected_role="fixed_holy"
		elseif component_index>#source.perimeter_spans+2 then
			expected_role="island_coast"
		end
		if observed~=expected or expected_role and
				(not literal or literal.boundary_role~=expected_role) then
			return diag("coast_source_component_roster",
				"geometry_policies.world_partition.coast_source_allowed_component_ids["..
					component_index.."]",expected,observed)
		end
	end
	local channel_expected={
		{"channel_wyrmglass","island_wyrmglass","front_gravesalt_escarpment",
			-2850,-350,-2500,350},
		{"channel_stormscale","island_stormscale","front_skyglass_canopy",
			2500,-350,2860,350},
	}
	for channel_index=1,#source.channels do
		local channel=source.channels[channel_index]
		local expected=channel_expected[channel_index]
		local polygon=channel.polygon
		if channel.id~=expected[1] or channel.island_id~=expected[2] or
				channel.mainland_zone_id~=expected[3] or
				channel.classification_policy_id~=
					"strict_exterior_closed_integer_polygon_channel_v1" or
				channel.membership_rule~=
					"nonzero_integer_winding_or_exact_segment_equality_after_strict_exterior" or
				channel.boundary_rule~=
					"included_channel_only_after_land_and_planned_water_precedence" or
				#polygon~=5 or polygon[1].x~=expected[4] or
				polygon[1].z~=expected[5] or polygon[2].x~=expected[6] or
				polygon[2].z~=expected[5] or polygon[3].x~=expected[6] or
				polygon[3].z~=expected[7] or polygon[4].x~=expected[4] or
				polygon[4].z~=expected[7] or polygon[5].x~=expected[4] or
				polygon[5].z~=expected[5] then
			return diag("channel_strict_exterior_contract",channel.id,
				"exact closed rectangle and post-land/water strict-exterior policy",
				"changed")
		end
	end
	local perimeter_by_id={}
	local outer_component_seen={}
	for i=1,#source.perimeters do local row=source.perimeters[i]
		if row.geometry_authority~=
				"literal_perimeter_polygon_after_sole_boundary_displacement" or
				row.source_geometry_role~="independent_outer_footprint_and_shelf_authority" or
				not dense(row.ordered_outer_components) or
				type(row.component_rule)~="string" then
			return diag("face_arc_sole_geometry_authority",row.id,
				"ordered zone-face outer components; polygon only constrains projection/envelope",
				"invalid")
		end
		for component_index=1,#row.ordered_outer_components do
			local component=row.ordered_outer_components[component_index]
			local span_id=component:match("^(perimeter_span:.*):canonical_forward$")
			local arc_id,first,last,direction=component:match(
				"^(face_arc:.-)#(%d+)%-(%d+):(forward)$")
			if not arc_id then arc_id,first,last,direction=component:match(
				"^(face_arc:.-)#(%d+)%-(%d+):(reverse)$") end
			if span_id then
				local span=span_by_id[span_id]
				if not span or span.perimeter_id~=row.id or outer_component_seen[span_id] then
					return diag("perimeter_component_ref",row.id,
						"unique canonical span of owning perimeter",component)
				end
				outer_component_seen[span_id]=true
			elseif arc_id then
				local arc=arc_by_id[arc_id]
				first,last=tonumber(first),tonumber(last)
				local literal=arc and arc.authority_components[1]
				local matched=literal and #arc.authority_components==1 and
					literal.kind=="literal_arc" and literal.boundary_role=="fixed_holy" and
					first==1 and last==#literal.control-1 and direction=="forward"
				if not matched then return diag("perimeter_component_ref",row.id,
					"outer-coast/fixed-Holy segment span",component) end
				outer_component_seen[component]=true
			else
				local bay_id,bay_direction=component:match(
					"^(bay_.-):mouth_outer_union:(forward)$")
				local land_id,land_direction=component:match("^(land_%d+):(.*)$")
				if bay_id then
					if not geometry_ref_by_id[bay_id] or bay_direction~="forward" then
						return diag("perimeter_component_ref",row.id,"known bay mouth",component)
					end
				elseif land_id then
					if not edge_by_id[land_id] or
							(land_direction~="forward" and land_direction~="reverse") then
						return diag("perimeter_component_ref",row.id,"known directed edge",component)
					end
				else return diag("perimeter_component_ref",row.id,
					"closed directed component vocabulary",component) end
			end
		end
		perimeter_by_id[row.id]=row
	end
	for span_index=1,#source.perimeter_spans do local span=source.perimeter_spans[span_index]
		if not outer_component_seen[span.id] then
			return diag("perimeter_component_coverage",span.id,
				"canonical span used exactly once","missing")
		end
	end
	local bay_by_id={}
	local bay_displacement_max_width_square=0
	local bay_displacement_max_early_cross=0
	for i=1,#source.bays do local bay=source.bays[i]
		bay_by_id[bay.id]=bay
		if bay.geometry_authority~=
				"unchanged_base_bay_centreline_half_width_round_capsule_union" or
				bay.source_geometry_role~="sole_base_planned_water_mask_and_owner_seam" or
				bay.mouth_closure_rule~=
					"open_round_capsule_intersection_with_projected_outer_perimeter" or
				bay.head_closure_rule~=
					"closed_round_cap_at_final_centreline_sample" or
				bay.ordered_component_rule~="authored_centreline_segments_in_array_order" then
			return diag("face_arc_sole_geometry_authority",bay.id,
				"sole ordered centreline capsule mask with open mouth and closed head",
				"invalid")
		end
		local projection=bay.perimeter_projection
		local perimeter=type(projection)=="table" and perimeter_by_id[projection.perimeter_id]
		if not dense(bay.shore_zone_ids) or #bay.shore_zone_ids~=4 or
				not perimeter or type(projection.mouth_vertex_index)~="number" or
				not zone_ids[projection.coast_left_zone_id] or
				not zone_ids[projection.coast_right_zone_id] or
				bay.owner_seam_tie~="lower_zone_numeric_id" then
			return diag("bay_face_projection",bay.id,
				"four shore zones and exact perimeter-to-zone/coast projection","invalid")
		end
		local mouth=perimeter.polygon[projection.mouth_vertex_index]
		local sample=bay.centreline[1]
		if not mouth or mouth.x~=sample.x or mouth.z~=sample.z then
			return diag("bay_mouth_perimeter_incidence",bay.id,
				sample.x..","..sample.z,mouth and mouth.x..","..mouth.z or "missing")
		end
		for segment_index=1,#bay.centreline-1 do
			local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
			local dx,dz=b.x-a.x,b.z-a.z
			local length_squared=dx*dx+dz*dz
			local max_radius=math.max(a.half_width,b.half_width)
			local radius_squared=safe_nonnegative_product(max_radius,max_radius)
			local length_fourth=safe_nonnegative_product(length_squared,length_squared)
			local full_guard=radius_squared and length_fourth and
				safe_nonnegative_product(radius_squared,length_fourth)
			local root=ceil_isqrt(length_squared)
			local open_bound=max_radius*root-1
			local open_bound_squared=safe_nonnegative_product(open_bound,open_bound)
			local open_guard=open_bound_squared and
				safe_nonnegative_product(open_bound_squared,length_squared)
			if not full_guard or not open_guard then
				return diag("bay_base_safe_product",bay.id..":"..segment_index,
					"max_r^2*L^2 and (max_r*ceil_isqrt(L)-1)^2*L <= 2^53-1","overflow")
			end
			if bay.max_displacement~=48 then
				return diag("bay_displacement_limit",bay.id,48,bay.max_displacement)
			end
			local varied_radius=max_radius+bay.max_displacement
			local varied_radius_squared=safe_nonnegative_product(
				varied_radius,varied_radius)
			local varied_full_guard=varied_radius_squared and length_fourth and
				safe_nonnegative_product(varied_radius_squared,length_fourth)
			local varied_open_bound=varied_radius*root-1
			local varied_open_squared=safe_nonnegative_product(
				varied_open_bound,varied_open_bound)
			local varied_open_guard=varied_open_squared and
				safe_nonnegative_product(varied_open_squared,length_squared)
			if not varied_full_guard or not varied_open_guard then
				return diag("bay_displacement_safe_product",bay.id..":"..segment_index,
					"varied E^2 and early C guard below 2^53","overflow")
			end
			bay_displacement_max_width_square=math.max(
				bay_displacement_max_width_square,varied_full_guard)
			bay_displacement_max_early_cross=math.max(
				bay_displacement_max_early_cross,varied_open_guard)
		end
		local shore_seen={}
		for j=1,#bay.shore_zone_ids do local zone_id=bay.shore_zone_ids[j]
			if not zone_ids[zone_id] or shore_seen[zone_id] then
				return diag("bay_shore_zone",bay.id,"four unique known shore zones",zone_id)
			end
			shore_seen[zone_id]=true
		end
		if not shore_seen[projection.coast_left_zone_id] or
				not shore_seen[projection.coast_right_zone_id] then
			return diag("bay_coast_projection_zone",bay.id,"projected zones among shores","invalid")
		end
		if not dense(bay.owner_spans) or
				bay.owner_span_transition_rule~=
					"adjacent_spans_meet_at_authored_centreline_station" or
				bay.owner_span_transition_tie~="lower_zone_numeric_id_on_selected_side" then
			return diag("bay_owner_spans",bay.id,
				"complete literal left/right centreline owner spans","invalid")
		end
		local next_segment=1
		local owner_seen={}
		for span_index=1,#bay.owner_spans do local span=bay.owner_spans[span_index]
			if span.first_segment~=next_segment or type(span.last_segment)~="number" or
					span.last_segment<span.first_segment or
					span.last_segment>#bay.centreline-1 or
					not shore_seen[span.left_zone_id] or
					not shore_seen[span.right_zone_id] or
					span.left_zone_id==span.right_zone_id then
				return diag("bay_owner_spans",bay.id..":"..span_index,
					"ordered complete listed left/right owners","invalid")
			end
			owner_seen[span.left_zone_id]=true owner_seen[span.right_zone_id]=true
			next_segment=span.last_segment+1
		end
		if next_segment~=#bay.centreline then
			return diag("bay_owner_spans",bay.id,#bay.centreline-1,next_segment-1)
		end
		for shore_index=1,#bay.shore_zone_ids do
			if not owner_seen[bay.shore_zone_ids[shore_index]] then
				return diag("bay_owner_span_coverage",bay.id,
					bay.shore_zone_ids[shore_index],"missing")
			end
		end
	end
	if bay_displacement_max_width_square~=4243584391840000 or
			bay_displacement_max_early_cross~=4251754341463400 then
		return diag("bay_displacement_product_kat","bays",
			"4243584391840000/4251754341463400",
			bay_displacement_max_width_square.."/"..
				bay_displacement_max_early_cross)
	end
	local bay_divergence_goldens={
		{"bay_elandor_west",-896,-2053},
		{"bay_elandor_east",1252,-2866},
		{"bay_elandor_east",771,-2398},
		{"bay_elandor_east",1101,-2222},
		{"bay_kragmar_east",787,2286},
	}
	for golden_index=1,#bay_divergence_goldens do local golden=bay_divergence_goldens[golden_index]
		local inside=point_in_base_bay({x=golden[2],z=golden[3]},bay_by_id[golden[1]])
		if inside~=false then return diag("bay_base_rational_divergence_golden",
			golden[1]..":"..golden[2]..":"..golden[3],false,inside) end
	end
	local expected_apertures={
		{"bay_mouth_aperture:elandor_west","bay_elandor_west","perimeter_elandor_mainland",12,"perimeter_span:elandor:hearthpine","perimeter_span:elandor:dawnmere",720},
		{"bay_mouth_aperture:elandor_east","bay_elandor_east","perimeter_elandor_mainland",16,"perimeter_span:elandor:dawnmere","perimeter_span:elandor:silverleaf",660},
		{"bay_mouth_aperture:kragmar_west","bay_kragmar_west","perimeter_kragmar_mainland",12,"perimeter_span:kragmar:stillgrave","perimeter_span:kragmar:sunscar",640},
		{"bay_mouth_aperture:kragmar_east","bay_kragmar_east","perimeter_kragmar_mainland",16,"perimeter_span:kragmar:sunscar","perimeter_span:kragmar:kapok",740},
	}
	local aperture_by_bay={}
	for aperture_index=1,#source.bay_mouth_apertures do
		local row=source.bay_mouth_apertures[aperture_index]
		local fields_ok,fields_failure=closed_fields(row,row.id,
			{"id","numeric_id","bay_id","mouth_sample_index","perimeter_id",
				"mouth_vertex_index","before_span_id","after_span_id","policy_id",
				"station_order","geometry_rule","owner_rule","boundary_tie"},
			"bay_mouth_aperture_fields")
		if not fields_ok then return nil,fields_failure end
		local expected=expected_apertures[aperture_index]
		local bay=bay_by_id[row.bay_id]
		local before_span,after_span=span_by_id[row.before_span_id],span_by_id[row.after_span_id]
		local perimeter=geometry_ref_by_id[row.perimeter_id]
		local mouth=perimeter and perimeter.polygon[row.mouth_vertex_index]
		local sample=bay and bay.centreline[row.mouth_sample_index]
		local derived_width=sample and 2*sample.half_width
		if row.id~=expected[1] or row.bay_id~=expected[2] or row.perimeter_id~=expected[3] or
				row.mouth_vertex_index~=expected[4] or row.before_span_id~=expected[5] or
				row.after_span_id~=expected[6] or derived_width~=expected[7] or
				row.mouth_sample_index~=1 or
				row.policy_id~="maximal_contiguous_nonwrapping_half_open_exact_base_bay_perimeter_stations_v1" or
				row.station_order~="canonical_deduplicated_final_perimeter_integer_raster_order" or
				row.geometry_rule~="derive_from_referenced_bay_and_perimeter_no_copied_shape" or
				row.owner_rule~="same_exact_base_bay_projection_and_owner" or
				row.boundary_tie~="first_and_last_included_end_and_preceding_start_excluded_dry" or
				row.control~=nil or row.position~=nil or not bay or
				bay.mouth_aperture_id~=row.id or aperture_by_bay[row.bay_id] or
				not before_span or not after_span or before_span.zone_id~=
					bay.perimeter_projection.coast_left_zone_id or after_span.zone_id~=
					bay.perimeter_projection.coast_right_zone_id or
					not mouth or mouth.x~=sample.x or mouth.z~=sample.z then
			return diag("bay_mouth_aperture_contract",row.id,
				"exact Bay/mouth/perimeter/two-span derived aperture record","changed")
		end
		aperture_by_bay[row.bay_id]=row
	end
	for bay_index=1,#source.bays do if not aperture_by_bay[source.bays[bay_index].id] then
		return diag("bay_mouth_aperture_coverage",source.bays[bay_index].id,1,0)
	end end
	local expected_wings={
		{"bay_wing:elandor_west:left","bay_elandor_west",-980,-2000,-1400,-1900,
			"junction:-1400:-1900","land_002","land_020",
			"elandor_copperfell_foothills","elandor_whitebridge_shire",-1195,-1971,-1185,-1929,
			"elandor_copperfell_foothills"},
		{"bay_wing:elandor_west:right","bay_elandor_west",-980,-2000,-400,-1900,
			"junction:-400:-1900","land_005","land_021",
			"elandor_whitebridge_shire","elandor_goldmead_vale",-695,-1921,-685,-1979,
			"elandor_goldmead_vale"},
		{"bay_wing:elandor_east:left","bay_elandor_east",1020,-1990,400,-1900,
			"junction:400:-1900","land_005","land_022",
			"elandor_goldmead_vale","elandor_lorindor",706,-1975,714,-1915,
			"elandor_goldmead_vale"},
		{"bay_wing:elandor_east:right","bay_elandor_east",1020,-1990,1400,-1900,
			"junction:1400:-1900","land_008","land_023",
			"elandor_lorindor","elandor_starbough_vale",1206,-1926,1214,-1964,
			"elandor_starbough_vale"},
		{"bay_wing:kragmar_west:left","bay_kragmar_west",-1060,2010,-1400,1900,
			"junction:-1400:1900","land_011","land_026",
			"kragmar_speargrass_reach","kragmar_mournfen",-1219,1921,-1241,1989,
			"kragmar_mournfen"},
		{"bay_wing:kragmar_west:right","bay_kragmar_west",-1060,2010,-400,1900,
			"junction:-400:1900","land_014","land_027",
			"kragmar_redtusk_savanna","kragmar_speargrass_reach",-725,1985,-735,1925,
			"kragmar_redtusk_savanna"},
		{"bay_wing:kragmar_east:left","bay_kragmar_east",900,1980,400,1900,
			"junction:400:1900","land_014","land_028",
			"kragmar_whispering_reedlands","kragmar_redtusk_savanna",655,1910,645,1970,
			"kragmar_redtusk_savanna"},
		{"bay_wing:kragmar_east:right","bay_kragmar_east",900,1980,1400,1900,
			"junction:1400:1900","land_017","land_029",
			"kragmar_raincall_basin","kragmar_whispering_reedlands",1155,1970,1145,1910,
			"kragmar_raincall_basin"},
	}
	local wings_by_bay={}
	for wing_index=1,#source.bay_closure_wings do local wing=source.bay_closure_wings[wing_index]
		local expected=expected_wings[wing_index]
		local bay=bay_by_id[wing.bay_id]
		local head=bay and bay.centreline[wing.head_sample_index]
		if wing.id~=expected[1] or wing.bay_id~=expected[2] or
				wing.head.x~=expected[3] or wing.head.z~=expected[4] or
				wing.junction.x~=expected[5] or wing.junction.z~=expected[6] or
				wing.junction_ref~=expected[7] or not dense(wing.junction_edge_ids) or
				#wing.junction_edge_ids~=2 or wing.junction_edge_ids[1]~=expected[8] or
				wing.junction_edge_ids[2]~=expected[9] or wing.left_zone_id~=expected[10] or
				wing.right_zone_id~=expected[11] or wing.left_probe.x~=expected[12] or
				wing.left_probe.z~=expected[13] or wing.right_probe.x~=expected[14] or
				wing.right_probe.z~=expected[15] or wing.tie_zone_id~=expected[16] or
				wing.head_sample_index~=4 or wing.head_half_width~=80 or
				wing.geometry_policy_id~="strict_tapered_bay_closure_wing_v1" or
				wing.noise_domain~="fixed" or wing.max_displacement~=0 or not head or
				head.x~=wing.head.x or head.z~=wing.head.z or
				head.half_width~=wing.head_half_width then
			return diag("bay_closure_wing_literal",wing.id,
				"reviewed fixed head/junction/owner/probe record","invalid")
		end
		if not zone_ids[wing.left_zone_id] or not zone_ids[wing.right_zone_id] or
				wing.left_zone_id==wing.right_zone_id or
				wing.tie_zone_id~=(zone_by_id[wing.left_zone_id].numeric_id<
				zone_by_id[wing.right_zone_id].numeric_id and wing.left_zone_id or wing.right_zone_id) then
			return diag("bay_closure_wing_owner",wing.id,
				"two known owners and lower numeric seam tie","invalid")
		end
		for edge_ref_index=1,2 do local edge=edge_by_id[wing.junction_edge_ids[edge_ref_index]]
			if not edge or (edge.from_junction_id~=wing.junction_ref and
					edge.to_junction_id~=wing.junction_ref) then
				return diag("bay_closure_wing_junction_ref",wing.id,
					"two existing land-edge endpoints at fixed triple junction","invalid")
			end
		end
		local dx,dz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
		local length_squared=dx*dx+dz*dz
		local radius_squared=safe_nonnegative_product(wing.head_half_width,wing.head_half_width)
		local length_fourth=safe_nonnegative_product(length_squared,length_squared)
		local full_guard=radius_squared and length_fourth and
			safe_nonnegative_product(radius_squared,length_fourth)
		local root=ceil_isqrt(length_squared)
		local open_bound=wing.head_half_width*root-1
		local open_bound_squared=safe_nonnegative_product(open_bound,open_bound)
		local open_guard=open_bound_squared and
			safe_nonnegative_product(open_bound_squared,length_squared)
		if not full_guard or not open_guard then
			return diag("bay_closure_wing_safe_product",wing.id,
				"r^2*L^2 and (r*ceil_isqrt(L)-1)^2*L <= 2^53-1","overflow")
		end
		local left_inside,left_cross=point_in_closure_wing(wing.left_probe,wing)
		local right_inside,right_cross=point_in_closure_wing(wing.right_probe,wing)
		local terminal_inside=point_in_closure_wing(wing.junction,wing)
		if left_inside~=true or right_inside~=true or left_cross<=0 or right_cross>=0 or
				terminal_inside~=false then
			return diag("bay_closure_wing_probe_side",wing.id,
				"left/right probes strict inside by authored A-to-B cross and J dry",
				tostring(left_cross)..":"..tostring(right_cross))
		end
		wings_by_bay[wing.bay_id]=wings_by_bay[wing.bay_id] or {}
		wings_by_bay[wing.bay_id][#wings_by_bay[wing.bay_id]+1]=wing.id
	end
	for bay_index=1,#source.bays do local bay=source.bays[bay_index]
		local wing_ids=wings_by_bay[bay.id]
		if not dense(bay.closure_wing_ids) or #bay.closure_wing_ids~=2 or
				not wing_ids or bay.closure_wing_ids[1]~=wing_ids[1] or
				bay.closure_wing_ids[2]~=wing_ids[2] then
			return diag("bay_closure_wing_coverage",bay.id,
				"exactly two source-ordered literal wings","invalid")
		end
	end
	local role_allowed={base_H=true,target_T=true,hydrology=true,route=true,
		interface=true,dressing=true}
	local landmark_primitive_allowed={rectangle=true,ellipse=true,capsule=true}
	local landmark_ids,landmark_by_id={},{}
	local base_h_priorities={}
	for i=1,#source.landmarks do local row=source.landmarks[i]
		if not zone_ids[row.zone_id] or not landmark_primitive_allowed[row.primitive] or
				not point_valid(row.center,false) or type(row.radius_x)~="number" or
				type(row.radius_z)~="number" or row.radius_x<=0 or row.radius_z<=0 or
				not relief_ids[row.secondary_relief_id] or
				row.noise_domain~="landmark_"..row.id or
				not dense(row.roles) or #row.roles==0 then return diag("landmark_contract",row.id,"known zone/primitive/mask/secondary relief/noise domain/roles","invalid") end
		for j=1,#row.roles do if not role_allowed[row.roles[j]] then return diag("landmark_role",row.id,"allowed role",row.roles[j]) end end
		if row.roles[1]~="base_H" or row.base_h_priority~=i or
				base_h_priorities[row.base_h_priority] or
				row.base_h_composition~="replace_profile_height" or
				row.base_h_blend_width~=64 then
			return diag("landmark_base_h_contract",row.id,
				"unique priority and explicit replacement composition","invalid")
		end
		base_h_priorities[row.base_h_priority]=true
		landmark_ids[row.id]=true landmark_by_id[row.id]=row
	end
	local primitive_ids={}
	local formula_rows=policies.primitive_formulas.formulas
	if not dense(formula_rows) or #formula_rows~=#source.template_primitives then
		return diag("primitive_formula_coverage","geometry_policies.primitive_formulas",
			#source.template_primitives,"changed")
	end
	local primitive_parameters={flat={"height_offset"},
		tilt={"axis_x","axis_z","rise","run"},
		terrace={"step_height","step_run","rings"},
		plateau={"inner_radius","shoulder_width"},
		basin={"inner_radius","depth","rim_width"},
		rim={"inner_radius","peak_radius","outer_radius","height"},
		causeway={"surface_width","backing_depth"},
		cross_section={"surface_width","corridor_width"},
		housing_smoothing={"radius","relief_limit"}}
	for i=1,#source.template_primitives do local primitive=source.template_primitives[i]
		local expected=primitive_parameters[primitive.id]
		if formula_rows[i].id~=primitive.id then
			return diag("primitive_formula_coverage",primitive.id,primitive.id,
				formula_rows[i].id)
		end
		if primitive.version~=1 or not expected or not dense(primitive.parameters) or
				#primitive.parameters~=#expected or primitive.degree~=nil then
			return diag("template_primitive_contract",primitive.id,
				"feature-specific closed parameter vocabulary","invalid")
		end
		for j=1,#expected do if primitive.parameters[j]~=expected[j] then
			return diag("template_primitive_parameters",primitive.id..":"..j,
				expected[j],primitive.parameters[j])
		end end
		primitive_ids[primitive.id]=true
	end
	local operation_allowed={apply=true,overlay=true,blend=true,subtract=true}
	local composition_ids,composition_by_id={},{}
	for i=1,#source.template_compositions do local row=source.template_compositions[i]
		composition_ids[row.id]=true composition_by_id[row.id]=row
		if row.version~=1 or not dense(row.operations) or #row.operations==0 then return diag("template_composition",row.id,"versioned operations","invalid") end
		for j=1,#row.operations do local operation=row.operations[j]
			if not operation_allowed[operation.op] or not primitive_ids[operation.primitive_id] or type(operation.parameters)~="table" then return diag("template_operation",row.id,"known op/primitive/parameters","invalid") end
			local expected_parameters=primitive_parameters[operation.primitive_id]
			local operation_parameter_count=0
			for _ in pairs(operation.parameters) do
				operation_parameter_count=operation_parameter_count+1
			end
			if operation_parameter_count~=#expected_parameters then
				return diag("template_operation_parameters",row.id..":"..j,
					#expected_parameters,operation_parameter_count)
			end
			for parameter_index=1,#expected_parameters do
				local name=expected_parameters[parameter_index]
				if type(operation.parameters[name])~="number" then
					return diag("template_operation_parameters",
						row.id..":"..j..":"..name,"numeric authored parameter",
						type(operation.parameters[name]))
				end
			end
			if operation.primitive_id=="rim" then local p=operation.parameters
				if p.inner_radius<0 or p.inner_radius>=p.peak_radius or
						p.peak_radius>=p.outer_radius or p.height<0 then
					return diag("primitive_rim_parameters",row.id..":"..j,
						"0 <= inner < peak < outer and height >= 0","invalid")
				end
			end
			local axis_expected
			if row.id=="compose_mirefolk" or row.id=="compose_clash" then
				axis_expected="selected_candidate_trail_spur_endpoint_tangent"
			elseif row.id=="compose_rare_route" then
				axis_expected="selected_candidate_patrol_first_segment_tangent"
			end
			local axis_dependent=operation.primitive_id=="causeway" or
				operation.primitive_id=="cross_section"
			if axis_dependent and operation.axis_source~=axis_expected then
				return diag("primitive_axis_source",row.id..":"..j,
					axis_expected,operation.axis_source)
			elseif not axis_dependent and operation.axis_source~=nil then
				return diag("primitive_axis_source",row.id..":"..j,"absent",
					operation.axis_source)
			end
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
		if row.fitting_width<=0 or row.blend_width<row.fitting_width or
				row.force_native_dungeon~=false then
			return diag("template_footprint_contract",row.id,
				"positive centered fitting inside blend; no dungeon force","invalid")
		end
		template_ids[row.id]=true
	end
	for i=1,#source.anchors do if not template_ids[source.anchors[i].template_id] then return diag("anchor_template_ref",source.anchors[i].id,"known template",source.anchors[i].template_id) end end
	local spur_anchor_seen={}
	for i=1,#source.poi_spurs do local row=source.poi_spurs[i]
		local anchor=anchor_by_id[row.anchor_id]
		local family=anchor and slot_family(anchor.slot_id)
		local major=family=="village" or family=="outpost" or family=="mine"
		local minor=family=="bandit" or family=="mirefolk" or family=="clash"
		local route=route_by_id[row.target_route_id] or
			island_route_by_id[row.target_route_id]
		local island_route=island_route_by_id[row.target_route_id]~=nil
		local station=station_by_id[row.target_station_id] or
			island_station_by_id[row.target_station_id]
		local interface=route_interface_by_id[row.target_interface_id] or
			island_route_interface_by_id[row.target_interface_id]
		if not anchor or anchor.placement_mode~="candidate_set" or
				(not major and not minor) or spur_anchor_seen[row.anchor_id] or
				row.class~=(major and "secondary" or "trail") or
				row.coordinate_space~="candidate_specific_relative_to_fixed_world_station" or
				row.terminal_rule~="fixed_station_exact" or
				not dense(row.candidate_paths) or
				#row.candidate_paths~=#anchor.candidates or not point_valid(row.target_position,false) or
				not route or not station or not interface then
			return diag("poi_spur_contract",row.id,
				"unique required candidate trail/secondary paths to fixed route station interface","invalid")
		end
		local route_zone_matches=(not island_route and
			(route.zone_a==anchor.zone_id or route.zone_b==anchor.zone_id)) or
			(island_route and island_by_id[route.island_id] and
				island_by_id[route.island_id].zone_id==anchor.zone_id)
		if not route_zone_matches then
			return diag("poi_spur_target_zone",row.id,anchor.zone_id,"route outside zone")
		end
		local route_station_a=island_route and route.from_station_id or route.station_a_id
		local route_station_b=island_route and route.to_station_id or route.station_b_id
		if row.target_station_id~=route_station_a and
				row.target_station_id~=route_station_b then
			return diag("poi_spur_station_ref",row.id,"route endpoint station",row.target_station_id)
		end
		local route_interface_a=island_route and route.id..":from" or route.endpoint_a_id
		local route_interface_b=island_route and route.id..":to" or route.endpoint_b_id
		if row.target_interface_id~=route_interface_a and
				row.target_interface_id~=route_interface_b then
			return diag("poi_spur_interface_ref",row.id,"route endpoint interface",row.target_interface_id)
		end
		local expected_interface=route_station_a==row.target_station_id and
			route_interface_a or route_interface_b
		if row.target_interface_id~=expected_interface or
				row.target_position.x~=station.position.x or
				row.target_position.z~=station.position.z then
			return diag("poi_spur_target_incidence",row.id,
				"same route endpoint/station/interface world position","mismatch")
		end
		for candidate_index=1,#row.candidate_paths do
			local path=row.candidate_paths[candidate_index]
			if not dense(path) or #path<3 then return diag("poi_spur_path",row.id..":"..candidate_index,
				"complete three-or-more-point authored path","invalid") end
			for j=1,#path do if not point_valid(path[j],false) then
				return diag("poi_spur_path_offset",row.id..":"..candidate_index,
					"integer candidate-relative offset","invalid")
			end
			end
			if path[1].x~=0 or path[1].z~=0 then return diag("poi_spur_candidate_origin",
				row.id..":"..candidate_index,"0,0",path[1].x..","..path[1].z) end
			local candidate=anchor.candidates[candidate_index]
			local terminal=path[#path]
			if candidate.x+terminal.x~=row.target_position.x or
					candidate.z+terminal.z~=row.target_position.z then
				return diag("poi_spur_world_terminus",row.id..":"..candidate_index,
					row.target_position.x..":"..row.target_position.z,
					(candidate.x+terminal.x)..":"..(candidate.z+terminal.z))
			end
		end
		spur_anchor_seen[row.anchor_id]=true
	end
	for i=1,#source.anchors do local family=slot_family(source.anchors[i].slot_id)
		if (family=="village" or family=="outpost" or family=="mine" or
				family=="bandit" or family=="mirefolk" or family=="clash") and
				not spur_anchor_seen[source.anchors[i].id] then
			return diag("poi_spur_required",source.anchors[i].id,"one secondary spur","missing")
		end
	end
	local hydrology_profile_ids,hydrology_profile_by_id={},{}
	local profile_expected={dry_channel=0,ford=1,shallow_marsh=1,stream=2,
		spring=2,shallow_pond=2,river=4,delta_arm=4,ordinary_lake=8,
		plunge_pool=12,deep_cenote=12}
	for i=1,#source.hydrology_profiles do local row=source.hydrology_profiles[i]
		if profile_expected[row.id]~=row.depth or row.bed_seal_layers~=3 or
				row.bank_seal_nodes~=2 or type(row.bank_blend_width)~="number" or
				row.bank_blend_width<=0 or type(row.mask_semantic_id)~="string" then
			return diag("hydrology_profile_contract",row.id,
				"closed depth/blend/two-bank/three-bed profile","invalid")
		end
		hydrology_profile_ids[row.id]=true hydrology_profile_by_id[row.id]=row
	end
	local transition_ids,transition_by_id={},{}
	local transition_vertical={bridge_clearance="bridge_clearance_v1",
		ford_bed="ford_bed_v1",causeway_deck="causeway_culvert_v1"}
	for i=1,#source.hydrology_transition_profiles do local row=source.hydrology_transition_profiles[i]
		if transition_ids[row.id] or type(row.kind)~="string" or
				type(row.run)~="number" or row.run<0 or type(row.drop)~="number" or
				row.drop<0 or type(row.open_face)~="string" or
				type(row.seal_semantic_id)~="string" then
			return diag("hydrology_transition_profile",row.id,"closed transition parameters","invalid")
		end
		if transition_vertical[row.id] and row.vertical_rule_id~=
				transition_vertical[row.id] then
			return diag("hydrology_transition_vertical",row.id,
				transition_vertical[row.id],row.vertical_rule_id)
		end
		if row.id=="bridge_clearance" and row.minimum_clearance_nodes~=3 then
			return diag("hydrology_transition_vertical",row.id,3,
				row.minimum_clearance_nodes)
		elseif row.id=="ford_bed" and row.road_y_offset_from_bed~=0 then
			return diag("hydrology_transition_vertical",row.id,0,
				row.road_y_offset_from_bed)
		elseif row.id=="causeway_deck" and row.deck_y_offset_from_W~=1 then
			return diag("hydrology_transition_vertical",row.id,1,
				row.deck_y_offset_from_W)
		end
		transition_ids[row.id]=true transition_by_id[row.id]=row
	end
	local hydrology_ids,hydrology_by_id={},{}
	for i=1,#source.hydrology do local row=source.hydrology[i]
		hydrology_ids[row.id]=true hydrology_by_id[row.id]=row
		if not zone_ids[row.zone_id] or not landmark_ids[row.landmark_id] or
				not hydrology_profile_ids[row.profile_id] or not dense(row.centreline) or
				#row.centreline<2 or type(row.from_id)~="string" or
				type(row.to_id)~="string" or
				row.water_surface_reference~="mapgen_water_level" or
				type(row.water_surface_offset)~="number" or
				row.water_node_semantic~="surface_water" or row.depth~=nil or
				row.water_surface~=nil then
			return diag("hydrology_contract",row.id,
				"one W, one closed profile, connected reach, surface_water semantic","invalid")
		end
		for j=1,#row.centreline do if not point_valid(row.centreline[j],true) then return diag("hydrology_point",row.id,"x/z/positive half_width","invalid") end end
	end
	local crossing_ids,crossing_by_id={},{}
	for i=1,#source.route_crossing_interfaces do local row=source.route_crossing_interfaces[i]
		crossing_ids[row.id]=true crossing_by_id[row.id]=row
	end
	local hydrology_interface_kinds={confluence=true,bridge=true,ford=true,
		waterfall=true,causeway=true,rapid=true}
	for i=1,#source.hydrology_interfaces do local row=source.hydrology_interfaces[i]
		if not hydrology_interface_kinds[row.kind] then return diag("hydrology_interface_kind",row.id,"closed kind",row.kind) end
		if row.hydrology_id and not hydrology_ids[row.hydrology_id] then return diag("hydrology_interface_ref",row.id,"known reach",row.hydrology_id) end
		if row.route_interface_id and not crossing_ids[row.route_interface_id] then return diag("hydrology_route_interface_ref",row.id,"known route crossing",row.route_interface_id) end
		local transition=transition_by_id[row.transition_profile_id]
		if not transition then return diag("hydrology_transition_ref",row.id,"closed transition profile",row.transition_profile_id) end
		if transition.kind~=row.kind then return diag("hydrology_transition_kind",row.id,row.kind,transition.kind) end
		if row.route_interface_id then local crossing=crossing_by_id[row.route_interface_id]
			if not point_valid(row.position,false) or row.position.x~=crossing.position.x or
					row.position.z~=crossing.position.z or row.hydrology_id~=crossing.hydrology_id then
				return diag("hydrology_route_interface_incidence",row.id,
					"same route/hydrology interface point","mismatch")
			end
		end
		if row.kind=="confluence" then
			if not dense(row.from_ids) or #row.from_ids<2 or
					not hydrology_ids[row.outgoing_reach_id] or
					not point_valid(row.position,false) or row.sealed~=true then
				return diag("confluence_interface",row.id,"incoming reaches/position/outgoing reach/seal","invalid")
			end
			for j=1,#row.from_ids do if not hydrology_ids[row.from_ids[j]] or
					not point_in_reach(row.position,hydrology_by_id[row.from_ids[j]].centreline) then
				return diag("confluence_incidence",row.id,"position in every incoming reach",row.from_ids[j])
			end end
			if not point_in_reach(row.position,
					hydrology_by_id[row.outgoing_reach_id].centreline) then
				return diag("confluence_incidence",row.id,"position in outgoing reach",false)
			end
		elseif row.kind=="rapid" or row.kind=="waterfall" then
			local upper,lower=hydrology_by_id[row.upper_id],hydrology_by_id[row.lower_id]
			if not upper or not lower or not point_valid(row.position,false) or
					row.upper_level_offset~=upper.water_surface_offset or
					row.lower_level_offset~=lower.water_surface_offset or
					row.upper_level_offset-row.lower_level_offset~=row.drop or
					row.drop<=0 or row.bed_seal_layers~=3 or
					row.bank_seal_nodes~=2 or row.sealed~=true or
					not point_in_reach(row.position,upper.centreline) or
					not point_in_reach(row.position,lower.centreline) then
				return diag(row.kind=="rapid" and "rapid_interface" or
					"waterfall_interface",row.id,
					"upper/lower W, incidence, drop and closed seals","invalid")
			end
			if row.kind=="rapid" then
				if row.run<=0 or row.width<=0 then return diag("rapid_interface",row.id,"positive run/width","invalid") end
			else
				if type(row.lip_id)~="string" or type(row.drop_id)~="string" or
						type(row.plunge_id)~="string" or row.drop_height~=row.drop or
						row.drop_mask_width<=0 or row.drop_mask_length<=0 or
						not hydrology_profile_ids[row.plunge_profile_id] or
						row.plunge_width<=0 or row.plunge_length<=0 then
					return diag("waterfall_dimensions",row.id,
						"exact lip/drop/plunge dimensions/profile","invalid")
				end
			end
		elseif row.sealed~=true or not point_valid(row.position,false) then
			if row.kind=="bridge" or row.kind=="ford" then
				return diag("hydrology_crossing_interface",row.id,"position and seal","invalid")
			end
		end
	end
	local crossing_kind_allowed={bridge=true,ford=true,causeway=true,tunnel=true}
	local crossing_vertical_rule={bridge="bridge_clearance_v1",ford="ford_bed_v1",
		causeway="causeway_culvert_v1",tunnel="tunnel_lumen_v1"}
	for i=1,#source.route_crossing_interfaces do local row=source.route_crossing_interfaces[i]
		if not route_ids[row.route_id] or not crossing_kind_allowed[row.kind] or not point_valid(row.position,false) or row.span<=0 or row.width<=0 or type(row.grade_limit)~="table" then return diag("route_crossing_contract",row.id,"route/kind/point/span/width/grade","invalid") end
		if row.grade_limit.numerator~=1 or row.grade_limit.denominator~=12 or
				row.grade_phase~="flat_run_12" or
				row.transition_semantic_id~="road_climb_stair_v1" or
				row.vertical_rule_id~=crossing_vertical_rule[row.kind] or
				row.hard_protected~=false then
			return diag("route_crossing_grade_policy",row.id,
				"1:12 flat phase/climb semantic/mutable crossing","invalid")
		end
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
		local anchor=source.anchors[index]
		local sockets=anchor.socket_reservations
		if anchor.placement_mode~="fixed" or
				anchor.socket_coordinate_space~="anchor_relative" or
				not dense(sockets) or #sockets~=12 then return diag("apex_socket_count",anchor.id,12,type(sockets)=="table" and #sockets or "invalid") end
		local ids,offsets={},{ }
		for j=1,#sockets do local socket=sockets[j]
			local expected_route=index==89 and
				"island_route_wyrmglass_junction_apex" or
				"island_route_stormscale_junction_apex"
			if type(socket.id)~="string" or ids[socket.id] or
					not point_valid(socket.offset,false) or not point_valid(socket.position,false) or
					socket.position.x~=anchor.position.x+socket.offset.x or
					socket.position.z~=anchor.position.z+socket.offset.z or
					socket.implementation_owner~="WP40" or socket.refill_owner~="WP34" or
					socket.approach_route_id~=expected_route or
					not island_route_ids[socket.approach_route_id] or
					math.abs(socket.offset.x)>=48 or math.abs(socket.offset.z)>=48 or
					not point_in_polygon(socket.position,
						island_by_id[index==89 and "island_wyrmglass" or
							"island_stormscale"].polygon) or
					socket.status~="active" or socket.active~=true then
				return diag("apex_socket_reservation",anchor.id..":"..j,
					"unique active reachable WP40 position with WP34 refill owner","invalid")
			end
			local offset_key=socket.offset.x..":"..socket.offset.z
			if offsets[offset_key] then return diag("apex_socket_offset_unique",anchor.id,12,offset_key) end
			ids[socket.id]=true offsets[offset_key]=true
			if counts[socket.resource_key]==nil then return diag("apex_socket_species",anchor.id,"six gem keys",socket.resource_key) end
			counts[socket.resource_key]=counts[socket.resource_key]+1
		end
		for _,key in ipairs({"citrine","garnet","jade","diamond","sapphire","ruby"}) do if counts[key]~=2 then return diag("apex_socket_species_count",source.anchors[index].id..":"..key,2,counts[key]) end end
	end
	local hard_recipe_by_id={}
	for i=1,#source.hard_protection_recipes do local row=source.hard_protection_recipes[i]
		local ordinary=row.id=="hard_capital_build_plus_apron_v1" or
			row.id=="hard_start_core_v1"
		local ordinary_width=row.id=="hard_capital_build_plus_apron_v1" and 532 or 128
		local socket=row.id=="hard_apex_socket_column_v1"
		if not ((ordinary and row.shape=="centered_half_open_square" and
			row.footprint_policy_id=="centered_half_open_square_v1" and
			row.total_width==ordinary_width and
			row.y_policy_id=="shallow_land_upward_to_world_top" and
			row.y_min==-700 and row.upward_unbounded==true) or
			(socket and row.shape=="exact_column" and
			row.footprint_policy_id=="exact_column_v1" and row.column_count==1 and
			row.y_policy_id=="shallow_land_upward_to_world_top" and
			row.y_min==-700 and row.upward_unbounded==true)) then
			return diag("hard_protection_recipe",row.id,"exact active footprint recipe","invalid")
		end
		hard_recipe_by_id[row.id]=row
	end
	local hard_source_ids,hard_socket_ids={},{ }
	for i=1,#source.hard_protection do local row=source.hard_protection[i]
		local anchor=anchor_by_id[row.source_anchor_id]
		local expected_recipe
		if i<=12 then expected_recipe=anchor and anchor.slot_id=="capital" and
			"hard_capital_build_plus_apron_v1" or "hard_start_core_v1"
		else expected_recipe="hard_apex_socket_column_v1" end
		if not anchor or not hard_recipe_by_id[row.recipe_id] or
				row.recipe_id~=expected_recipe or not point_valid(row.center,false) or
				row.active~=true or row.status~="active" or
				row.activation_owner~="WP40" then
			return diag("hard_protection_active",row.id,
				"12 exact cores plus 24 exact apex socket columns","invalid")
		end
		if i<=12 then
			if anchor~=source.anchors[i] or row.center.x~=anchor.position.x or
					row.center.z~=anchor.position.z or row.socket_reservation_id~=nil then
				return diag("hard_protection_core",row.id,"ordered exact start/capital core","invalid")
			end
		else
			local socket_record
			for j=1,#anchor.socket_reservations do
				if anchor.socket_reservations[j].id==row.socket_reservation_id then
					socket_record=anchor.socket_reservations[j] break end
			end
			if not socket_record or hard_socket_ids[row.socket_reservation_id] or
					row.resource_key~=socket_record.resource_key or
					row.center.x~=socket_record.position.x or
					row.center.z~=socket_record.position.z then
				return diag("hard_apex_socket",row.id,
					"unique exact semantic socket column","invalid")
			end
			hard_socket_ids[row.socket_reservation_id]=true
		end
		hard_source_ids[row.source_anchor_id]=true
	end
	for i=1,12 do
		if source.hard_protection[i].source_anchor_id~=source.anchors[i].id then
			return diag("hard_protection_order",source.hard_protection[i].id,
				source.anchors[i].id,source.hard_protection[i].source_anchor_id)
		end
	end
	local pending_recipe_by_id={}
	for i=1,#source.pending_static_recipes do local row=source.pending_static_recipes[i]
		if row.status~="pending" or row.geometry_authority~=
				"activation_owner" or type(row.activation_owner)~="string" or
				row.total_width~=nil or row.radius~=nil then
			return diag("pending_recipe_contract",row.id,
				"owner/status only; no future dimensions","invalid")
		end
		pending_recipe_by_id[row.id]=row
	end
	local pending_ids={}
	local pending_counts={wp13=0,wp17=0,wp34=0}
	for i=1,#source.pending_static_reservations do local row=source.pending_static_reservations[i]
		local recipe=pending_recipe_by_id[row.recipe_id]
		local pending_anchor=anchor_by_id[row.anchor_id]
		if not recipe or not pending_anchor or
				row.activation_owner~=recipe.activation_owner or row.status~="pending" or
				row.active~=false or hard_socket_ids[row.id] or
				row.center~=nil or row.position~=nil or row.total_width~=nil or
				row.radius~=nil or row.polygon~=nil or row.corridor_width~=nil or
				row.half_width~=nil or row.node_id~=nil or row.yield~=nil or
				row.refill_seconds~=nil or row.deep_multiplier~=nil or
				row.hard_protected~=nil or row.protection_recipe_id~=nil then
			return diag("pending_reservation_contract",row.id,
				"known owner/anchor, inactive ownership handoff without geometry or behavior",
				"invalid")
		end
		local expected_containment={}
		if row.socket_reservation_id then
			expected_containment[1]="exclude:active:hard:"..row.socket_reservation_id
		else
			local count=pending_anchor.placement_mode=="candidate_set" and
				#pending_anchor.candidates or 1
			for candidate_index=1,count do
				expected_containment[candidate_index]=
					("exclude:anchor:%s:%02d"):format(row.anchor_id,candidate_index)
			end
		end
		if not dense(row.containment_exclusion_ids) or
				#row.containment_exclusion_ids~=#expected_containment then
			return diag("pending_containment",row.id,
				"all exact current anchor/socket exclusion containers","invalid")
		end
		for containment_index=1,#expected_containment do
			if row.containment_exclusion_ids[containment_index]~=
					expected_containment[containment_index] then
				return diag("pending_containment",row.id,
					expected_containment[containment_index],
					row.containment_exclusion_ids[containment_index])
			end
		end
		if row.activation_owner=="WP13" then
			local family=slot_family(anchor_by_id[row.anchor_id].slot_id)
			if (family~="mine" and family~="apex_mine") or
					row.reservation_kind~="mining_camp_functional_anchor" then
				return diag("pending_wp13_scope",row.id,"six mines plus two apex mines",family)
			end
			pending_counts.wp13=pending_counts.wp13+1
		elseif row.activation_owner=="WP17" then pending_counts.wp17=pending_counts.wp17+1
		elseif row.activation_owner=="WP34" then pending_counts.wp34=pending_counts.wp34+1 end
		pending_ids[row.id]=true
	end
	if pending_counts.wp13~=8 or pending_counts.wp17~=48 or pending_counts.wp34~=30 then
		return diag("pending_exact_scope","pending_static_reservations","8/48/30",
			pending_counts.wp13.."/"..pending_counts.wp17.."/"..pending_counts.wp34)
	end
	local exclusion_recipe_by_id={}
	for i=1,#source.claim_exclusion_recipes do local row=source.claim_exclusion_recipes[i]
		if type(row.kind)~="string" or type(row.footprint_policy_id)~="string" then
			return diag("claim_exclusion_recipe",row.id,"closed kind/footprint policy","invalid")
		end
		exclusion_recipe_by_id[row.id]=row
	end
	local expected_exclusions,expected_exclusion_order={},{}
	local function expect_exclusion(id,recipe_id,source_id,value_name,value)
		expected_exclusions[id]={recipe_id=recipe_id,source_id=source_id,
			value_name=value_name,value=value}
		expected_exclusion_order[#expected_exclusion_order+1]=id
	end
	local template_record_by_id={}
	for i=1,#source.templates do template_record_by_id[source.templates[i].id]=source.templates[i] end
	for i=1,#source.anchors do local anchor=source.anchors[i]
		local candidates=anchor.placement_mode=="fixed" and {anchor.position} or anchor.candidates
		for j=1,#candidates do expect_exclusion(("exclude:anchor:%s:%02d"):format(anchor.id,j),
			"exclude_anchor_blend_v1",anchor.id,"total_width",
			template_record_by_id[anchor.template_id].blend_width) end
	end
	local route_width={primary=16,secondary=12,trail=8}
	for i=1,#source.routes do local row=source.routes[i]
		expect_exclusion("exclude:route:"..row.id,"exclude_route_corridor_v1",
			row.id,"corridor_width",route_width[row.class]) end
	for i=1,#source.island_routes do local row=source.island_routes[i]
		expect_exclusion("exclude:route:"..row.id,"exclude_route_corridor_v1",
			row.id,"corridor_width",12) end
	for i=1,#source.poi_spurs do local row=source.poi_spurs[i]
		expect_exclusion("exclude:route:"..row.id,"exclude_route_corridor_v1",
			row.id,"corridor_width",route_width[row.class]) end
	for i=1,#source.hydrology do local row=source.hydrology[i]
		expect_exclusion("exclude:water:"..row.id,"exclude_planned_water_v1",row.id) end
	for i=1,#source.bays do local row=source.bays[i]
		expect_exclusion("exclude:water:"..row.id,"exclude_planned_water_v1",row.id) end
	for _,collection in ipairs({source.perimeters,source.islands,source.channels}) do
		for i=1,#collection do local row=collection[i]
			expect_exclusion("exclude:coast:"..row.id,"exclude_coast_v1",row.id) end
	end
	for i=1,#source.land_edges do local row=source.land_edges[i]
		expect_exclusion("exclude:boundary:"..row.id,"exclude_boundary_v1",row.id) end
	for i=1,#source.hard_protection do local row=source.hard_protection[i]
		expect_exclusion("exclude:active:"..row.id,"exclude_active_core_v1",row.id) end
	local exclusion_seen,first_invalid_exclusion={}
	for i=1,#source.claim_exclusions do local row=source.claim_exclusions[i]
		local expected=expected_exclusions[row.id]
		local duplicate=expected and exclusion_seen[row.id]
		if not expected or duplicate or
				row.recipe_id~=expected.recipe_id or row.source_id~=expected.source_id or
				not exclusion_recipe_by_id[row.recipe_id] or
				(expected.value_name and row[expected.value_name]~=expected.value) then
			first_invalid_exclusion=first_invalid_exclusion or row
		end
		if expected and not duplicate then
			exclusion_seen[row.id]=true
		end
		if expected and row.recipe_id=="exclude_anchor_blend_v1" and
				(row.coverage~="complete_fitting_plus_blend_envelope" or
				not point_valid(row.center,false)) then
			return diag("claim_anchor_envelope",row.id,"full candidate fitting+blend envelope","invalid")
		end
	end
	for i=1,#expected_exclusion_order do local id=expected_exclusion_order[i]
		if not exclusion_seen[id] then
		return diag("claim_exclusion_missing",id,"present","missing")
	end end
	if first_invalid_exclusion then return diag("claim_exclusion_contract",
		first_invalid_exclusion.id,
		"complete current anchor/route/water/coast/boundary/active-core exclusion","invalid") end
	local housing_zones={elandor_copperfell_foothills=true,elandor_goldmead_vale=true,elandor_starbough_vale=true,elandor_whitebridge_shire=true,elandor_lorindor=true,kragmar_mournfen=true,kragmar_redtusk_savanna=true,kragmar_raincall_basin=true,kragmar_speargrass_reach=true,kragmar_whispering_reedlands=true}
	local housing_ids,housing_by_id={},{}
	for i=1,#source.housing_masks do local row=source.housing_masks[i] if not housing_zones[row.zone_id] then return diag("housing_zone",row.id,"exact housing-zone catalog",row.zone_id) end housing_ids[row.id]=true housing_by_id[row.id]=row end
	local coastal_zone_seen={}
	for i=1,#source.coastal_housing_cores do local row=source.coastal_housing_cores[i]
		local housing=housing_by_id[row.housing_mask_id]
		local span=span_by_id[row.perimeter_span_id]
		if not housing or housing.zone_id~=row.zone_id or coastal_zone_seen[row.zone_id] or
				row.composition_id~="compose_coastal_housing_core" or
				row.policy_id~="displaced_coast_interval_inward_core_v1" or
				row.frontage_min~=600 or row.inland_depth_min~=300 or
				row.relief_max~=12 or not span or span.zone_id~=row.zone_id or
				row.direction~="forward" or row.inward_side~="left" or
				type(row.start_segment)~="number" or type(row.end_segment)~="number" or
				row.start_segment<1 or row.end_segment<row.start_segment or
				row.end_segment>span.last_segment-span.first_segment+2 then
			return diag("coastal_core_contract",row.id,
				"exact mask/zone/displaced-coast interval/inward 600x300 policy","invalid")
		end
		if row.start_segment>row.end_segment then return diag("coastal_core_coast_ref",row.id,
			"interval wholly in one canonical perimeter span","invalid") end
		-- Stage 1 owns source identity, span direction, dimensions and policy
		-- references only. Stage 2 sums the final displaced one-node station
		-- sequence in Q16 and proves the binding 600-node frontage; an authored
		-- control chord is deliberately not a frontage authority.
		coastal_zone_seen[row.zone_id]=true
	end
	if #source.coastal_housing_cores~=4 then return diag("coastal_core_count",
		"coastal_housing_cores",4,#source.coastal_housing_cores) end
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
	if source.semantics.semantic_water_node~="surface_water" then
		return diag("surface_water_semantic","semantics","surface_water",
			source.semantics.semantic_water_node)
	end
	local semantic_lists={
		{source.semantics.relief_ids,source.relief_profiles,"relief"},
		{source.semantics.water_class_ids,source.water_classes,"water_class"},
		{source.semantics.hydrology_profile_ids,source.hydrology_profiles,"hydrology_profile"},
		{source.semantics.protection_recipe_ids,source.hard_protection_recipes,"protection_recipe"},
		{source.semantics.exclusion_recipe_ids,source.claim_exclusion_recipes,"exclusion_recipe"},
	}
	for list_index=1,#semantic_lists do local item=semantic_lists[list_index]
		if not dense(item[1]) or #item[1]~=#item[2] then
			return diag("closed_semantic_vocabulary",item[3],#item[2],"changed")
		end
		for i=1,#item[2] do if item[1][i]~=item[2][i].id then
			return diag("closed_semantic_vocabulary",item[3]..":"..i,
				item[2][i].id,item[1][i])
		end end
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
		for point_index=1,#row.polygon do local point=row.polygon[point_index]
			if math.abs(point.x-row.center.x)>row.envelope.radius_x or
					math.abs(point.z-row.center.z)>row.envelope.radius_z then
				return diag("fixed_island_authoring_envelope",row.id,
					"every authored control inside the centered closed 600x700 rectangle",
					point_index..":"..point.x..":"..point.z)
			end
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
		for _, index in ipairs({89,90}) do
			for j=1,#source.anchors[index].socket_reservations do
				local key=source.anchors[index].socket_reservations[j].resource_key
				if not resources[key] then return diag("semantic_reference",
					source.anchors[index].id,"published WP43 resource key",key) end
			end
		end
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
