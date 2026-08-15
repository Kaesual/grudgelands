local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
arg._wp40_phase = dofile(repo .. "/tools/wp40/t2_phase_selector.lua")(
	os.getenv("WP40_T2_ONLY"))

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/catalog.lua")
local stage1 = dofile(wp40 .. "/validation/t2_source.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")

-- Consume the real WP43 owner and its existing pure handoff projection. This
-- harness is the only place T2 loads runtime-owner data; the source does not.
local old_arg = arg
arg = {repo}
dofile(repo .. "/tools/wp43/materials_test.lua")
arg = old_arg
local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
local projection = handoff.project(grug_materials)

local function projection_keys(rows)
	local result = {}
	for i = 1, #rows do result[i] = rows[i].key or rows[i]._projection_key end
	return result
end

local vocabulary = {
	resource_keys = projection_keys(projection.resources),
	resource_rows = projection.resources,
	cultural_keys = projection_keys(projection.cultural_materials),
	wood_keys = projection_keys(projection.signature_woods),
}

local sha_counter,sha_cache = 0,{}
local function from_hex(value)
	return (value:gsub("..", function(pair) return string.char(assert(tonumber(pair,16))) end))
end
local function raw_sha256(data)
	local cached=sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/source-" .. sha_counter .. ".bin"
	local output = scratch .. "/source-" .. sha_counter .. ".sha"
	local file = assert(io.open(input,"wb")) assert(file:write(data)) assert(file:close())
	local execute_ok,execute_why,execute_code=
		os.execute("sha256sum " .. input .. " > " .. output)
	assert(execute_ok==0 or execute_ok==true and execute_why=="exit" and
		execute_code==0)
	file = assert(io.open(output,"rb")) local line=assert(file:read("*l")) assert(file:close())
	assert(os.remove(input))
	assert(os.remove(output))
	local digest=from_hex(assert(line:match("^([0-9a-f]+)")))
	sha_cache[data]=digest
	return digest
end

-- Load a second copy through the production-owned binding path. This faithful
-- offline core stand-in exposes only the real fixed mod path and an independent
-- binary SHA implementation; it is not passed to validate.
local previous_core=rawget(_G,"core")
_G.core={
	get_modpath=function(name)
		assert(name=="grug_mapgen")
		return repo.."/mods/MAPGEN/grug_mapgen"
	end,
	sha256=function(data,binary)
		assert(binary==true)
		return raw_sha256(data)
	end,
}
local production_stage1=dofile(wp40.."/validation/t2_source.lua")
_G.core=previous_core
assert(production_stage1.new_offline_test_adapter==nil,
	"production Stage1 exposed the offline adapter")

local EXPECTED_SOURCE_CHECKSUM="5e8866d1490b508e54a4d503c087fa5265722ecd443dcfe098bc0e672b2d0000"
local EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM=
	"3e6209c76325fa7fa7395c7f75f15181f21ca2e81e8e8c26848019221d96e8fe"
local EXPECTED_WORLD_PARTITION_CHECKSUM=
	"8f3459c2a9eae21dd182129d8447063e7ae102e74373bb55fa779d18ab91cd45"
assert(stage1.EXPECTED_SOURCE_CHECKSUM==EXPECTED_SOURCE_CHECKSUM,
	"production and independent source KAT differ")
assert(production_stage1.EXPECTED_SOURCE_CHECKSUM==EXPECTED_SOURCE_CHECKSUM,
	"bound production source KAT differs")
assert(stage1.EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM==
	EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM and
	production_stage1.EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM==
	EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM,
	"boundary-displacement export KAT differs")
assert(stage1.EXPECTED_WORLD_PARTITION_CHECKSUM==
	EXPECTED_WORLD_PARTITION_CHECKSUM and
	production_stage1.EXPECTED_WORLD_PARTITION_CHECKSUM==
	EXPECTED_WORLD_PARTITION_CHECKSUM,
	"world-partition export KAT differs")
local offline=assert(stage1.new_offline_test_adapter,
	"offline Stage1 adapter missing")(canonical,raw_sha256)

local function assert_valid(value, vocab)
	local ok, failure = offline.validate(value, vocab)
	assert(ok, failure and (failure.invariant .. ":" .. tostring(failure.record_id)..":"..tostring(failure.observed)))
end

assert_valid(source, vocabulary)
if arg._wp40_phase.enabled("production_trust_path") then
	local ok,failure=production_stage1.validate(source,vocabulary)
	assert(ok,failure and failure.invariant)
end

if arg._wp40_phase.enabled("source_roster_contract") then
local counts = {start=0,capital=0,village=0,outpost=0,bandit=0,mine=0,
	mirefolk=0,clash=0,dragon=0,apex_mine=0,rare=0}
for i = 1, #source.anchors do
	local slot = source.anchors[i].slot_id
	local family = slot
	if slot:match("^village_") then family="village"
	elseif slot:match("^outpost_") then family="outpost"
	elseif slot:match("^bandit_") then family="bandit"
	elseif slot:match("^clash_") then family="clash"
	elseif slot:match("^rare_") then family="rare" end
	counts[family] = counts[family] + 1
end
assert(#source.zones == 38 and #source.land_edges == 61 and
	#source.relief_junctions==38 and #source.junction_departures==4 and
	#source.perimeter_attachments==8 and #source.perimeter_spans==18 and #source.routes==57 and
	#source.bay_mouth_apertures==4 and
	#source.boat_edges == 4 and #source.landmarks == 70 and
	#source.anchors == 100)
assert(#source.bay_bank_components==20 and #source.bay_edge_transitions==8 and
	#source.face_arcs==34 and #source.zone_faces==38 and
	#source.bay_closure_wings==8 and
	#source.surface_level_controls==162 and
	#source.poi_spurs==74 and #source.hydrology_profiles==11 and
	#source.hydrology_transition_profiles==6 and #source.hydrology==25 and
	#source.hard_protection==36 and
	#source.pending_static_reservations==86 and
	#source.claim_exclusions==540)
assert(counts.start==6 and counts.capital==6 and counts.village==12 and
	counts.outpost==24 and counts.bandit==12 and counts.mine==6 and
	counts.mirefolk==4 and counts.clash==16 and counts.dragon==2 and
	counts.apex_mine==2 and counts.rare==10)

local routes = {primary=0,secondary=0,trail=0}
local incident = {}
for i = 1, #source.zones do incident[source.zones[i].id] = {} end
for i = 1, #source.land_edges do
	local edge = source.land_edges[i]
	incident[edge.zone_a][#incident[edge.zone_a]+1] = edge.zone_b
	incident[edge.zone_b][#incident[edge.zone_b]+1] = edge.zone_a
end
for i=1,#source.routes do local route=source.routes[i]
	routes[route.class]=routes[route.class]+1
end
assert(routes.primary==30 and routes.secondary==24 and routes.trail==3)
assert(#incident.elandor_hearthpine_vale == 1 and
	incident.elandor_hearthpine_vale[1] == "elandor_copperfell_foothills")
assert(#incident.kragmar_stillgrave_hollow == 1 and
	incident.kragmar_stillgrave_hollow[1] == "kragmar_mournfen")
assert(#incident.front_wyrmglass_crown == 0 and
	#incident.front_stormscale_summit == 0)
for i=1,#source.land_edges do local edge=source.land_edges[i]
	assert(edge.left_zone~=edge.right_zone and edge.left_probe and edge.right_probe)
end
for i=1,#source.route_crossing_interfaces do
	assert(source.route_crossing_interfaces[i].hard_protected==false)
end
for i=1,#source.pending_static_reservations do
	assert(source.pending_static_reservations[i].active==false and
		source.pending_static_reservations[i].status=="pending")
end
for _,anchor_index in ipairs({87,88,89,90}) do
	assert(source.anchors[anchor_index].placement_mode=="fixed")
end
for _,anchor_index in ipairs({89,90}) do
	assert(#source.anchors[anchor_index].socket_reservations==12)
	for _,socket in ipairs(source.anchors[anchor_index].socket_reservations) do
		assert(socket.active==true and socket.status=="active")
	end
end
end

-- Slow semantic oracles deliberately iterate ID maps in reverse source order.
-- Production remains an ordered/KAT source; these checks prove that face and
-- spur authority do not secretly depend on array iteration.
if arg._wp40_phase.enabled("face_edge_order") then
	local zone_a_right={}
	for i=1,9 do zone_a_right[i]=true end
	for i=31,34 do zone_a_right[i]=true end
	for i=41,48 do zone_a_right[i]=true end
	for i=#source.land_edges,1,-1 do local edge=source.land_edges[i]
		local numeric=tonumber(edge.id:match("(%d+)$"))
		if numeric<=57 then
			local expected_left=zone_a_right[numeric] and edge.zone_b or edge.zone_a
			assert(edge.left_zone==expected_left and edge.right_zone~=edge.left_zone,
				"reverse-order face authority drift")
		end
	end
	local new_left={land_058="elandor_frostbarrow_shelf",
		land_059="elandor_moonfall_wood",land_060="kragmar_mournfen",
		land_061="kragmar_raincall_basin"}
	for i=58,61 do assert(source.land_edges[i].left_zone==new_left[source.land_edges[i].id]) end
	local reversed={}
	for key,value in pairs(source) do reversed[key]=value end
	reversed.land_edges={}
	for i=#source.land_edges,1,-1 do
		reversed.land_edges[#reversed.land_edges+1]=source.land_edges[i]
	end
	local ok,failure=offline.validate(reversed,vocabulary)
	assert(not ok and failure.invariant=="canonical_numeric_order",
		"ordered production source accepted an edge permutation")
end
if arg._wp40_phase.enabled("poi_spur_bindings") then
	local route_by_id,first_by_zone={},{ }
	for i=#source.routes,1,-1 do route_by_id[source.routes[i].id]=source.routes[i] end
	for i=#source.island_routes,1,-1 do
		route_by_id[source.island_routes[i].id]=source.island_routes[i]
	end
	for i=1,#source.routes do local route=source.routes[i]
		first_by_zone[route.zone_a]=first_by_zone[route.zone_a] or route.id
		first_by_zone[route.zone_b]=first_by_zone[route.zone_b] or route.id
	end
	local differs_from_old_heuristic=0
	for i=#source.poi_spurs,1,-1 do local spur=source.poi_spurs[i]
		local route=assert(route_by_id[spur.target_route_id])
		local anchor=source.anchors[tonumber(spur.anchor_id:match("(%d+)$"))]
		assert((route.zone_a==anchor.zone_id or route.zone_b==anchor.zone_id) or
			route.island_id~=nil)
		if spur.class=="secondary" and
				first_by_zone[anchor.zone_id]~=spur.target_route_id then
			differs_from_old_heuristic=differs_from_old_heuristic+1
		end
	end
	assert(differs_from_old_heuristic>=4,
		"literal spur bindings collapsed to old first-route heuristic")
end

-- Exhaustive Stage-1 integer-column audit of exact Base-Bay membership and
-- owner arithmetic. Coordinate-free R11 bank materialization, dry-face
-- coverage and the combined Base/Wing partition remain Stage-2 obligations.
if arg._wp40_phase.enabled("base_bay_owner_oracle") then
	local edge_by_id,perimeter_by_id={},{}
	for i=1,#source.land_edges do edge_by_id[source.land_edges[i].id]=source.land_edges[i] end
	for i=1,#source.perimeters do perimeter_by_id[source.perimeters[i].id]=source.perimeters[i] end
	local function point_in_polygon(x,z,polygon)
		local winding=0
		for i=1,#polygon-1 do local a,b=polygon[i],polygon[i+1]
			local side=(b.x-a.x)*(z-a.z)-(b.z-a.z)*(x-a.x)
			if side==0 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
					z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then return true end
			if a.z<=z then if b.z>z and side>0 then winding=winding+1 end
			elseif b.z<=z and side<0 then winding=winding-1 end
		end
		return winding~=0
	end
	local function point_strictly_in_polygon(x,z,polygon)
		local winding=0
		for i=1,#polygon-1 do local a,b=polygon[i],polygon[i+1]
			local side=(b.x-a.x)*(z-a.z)-(b.z-a.z)*(x-a.x)
			if side==0 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
					z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then return false end
			if a.z<=z then if b.z>z and side>0 then winding=winding+1 end
			elseif b.z<=z and side<0 then winding=winding-1 end
		end
		return winding~=0
	end
	local function raster_segment(authored_a,authored_b)
		local reverse=authored_a.x>authored_b.x or
			(authored_a.x==authored_b.x and authored_a.z>authored_b.z)
		local a,b=authored_a,authored_b
		if reverse then a,b=b,a end
		local points={}
		local x,z=a.x,a.z
		local dx,dz=math.abs(b.x-a.x),math.abs(b.z-a.z)
		local sx=a.x<b.x and 1 or -1
		local sz=a.z<b.z and 1 or -1
		if dx>=dz then
			local error_value=2*dz-dx
			for step=0,dx do
				points[#points+1]={x=x,z=z}
				if step<dx then
					x=x+sx
					if error_value>=0 then z=z+sz error_value=error_value-2*dx end
					error_value=error_value+2*dz
				end
			end
		else
			local error_value=2*dx-dz
			for step=0,dz do
				points[#points+1]={x=x,z=z}
				if step<dz then
					z=z+sz
					if error_value>=0 then x=x+sx error_value=error_value-2*dz end
					error_value=error_value+2*dx
				end
			end
		end
		if reverse then
			local reversed={} for i=#points,1,-1 do reversed[#reversed+1]=points[i] end
			return reversed
		end
		return points
	end
	local function raster_polyline(control)
		local points={}
		for i=1,#control-1 do local segment=raster_segment(control[i],control[i+1])
			for j=1,#segment do if #points==0 or j>1 then points[#points+1]=segment[j] end end
		end
		return points
	end
	local perimeter_stations_by_id,perimeter_station_lookup={},{ }
	for perimeter_id,perimeter in pairs(perimeter_by_id) do
		local stations=raster_polyline(perimeter.polygon)
		if stations[1].x==stations[#stations].x and stations[1].z==stations[#stations].z then
			table.remove(stations)
		end
		perimeter_stations_by_id[perimeter_id]=stations
		local lookup={} perimeter_station_lookup[perimeter_id]=lookup
		for station_index=1,#stations do
			lookup[stations[station_index].x..":"..stations[station_index].z]=station_index
		end
	end
	local attachment_by_id,attachment_by_edge={},{}
	for i=1,#source.perimeter_attachments do local attachment=source.perimeter_attachments[i]
		attachment_by_id[attachment.id]=attachment attachment_by_edge[attachment.edge_id]=attachment
	end
	local attachment_point={}
	for edge_id,attachment in pairs(attachment_by_edge) do
		local edge=edge_by_id[edge_id]
		local points=raster_polyline(edge.control)
		local perimeter=perimeter_by_id[attachment.perimeter_id].polygon
		local first,last
		for i=1,#points do if point_in_polygon(points[i].x,points[i].z,perimeter) then
			first=first or i last=i
		end end
		assert(first and last)
		local kept={}
		for i=first,last do
			assert(point_in_polygon(points[i].x,points[i].z,perimeter),
				"attachment candidate retained run is not consecutive")
			kept[#kept+1]=points[i]
		end
		attachment_point[attachment.id]=attachment.edge_endpoint=="from" and kept[1] or kept[#kept]
	end
	-- This is deliberately the undisplaced literal Stage-1 baseline. Final
	-- seed-zero and corpus attachment geometry belongs to Stage 2.
	local baseline_exact_attachment_count,baseline_adjacent_attachment_count=0,0
	local baseline_reviewed_short_attachment_minimum=9007199254740991
	local expected_attachment_station_steps={
		["perimeter_attachment:elandor:land_031"]=298,
		["perimeter_attachment:elandor:land_034"]=297,
	}
	local expected_undisplaced_attachment_delta={
		["perimeter_attachment:elandor:land_031"]={-2497,-1100,-2498,-1099,1},
		["perimeter_attachment:elandor:land_007"]={2511,-2662,2512,-2663,1},
		["perimeter_attachment:elandor:land_034"]={2496,-1100,2497,-1101,1},
		["perimeter_attachment:kragmar:land_010"]={-2520,2664,-2521,2664,1},
		["perimeter_attachment:kragmar:land_016"]={2517,2678,2517,2679,1},
	}
	local expected_undisplaced_exact_attachment={
		["perimeter_attachment:elandor:land_001"]=true,
		["perimeter_attachment:kragmar:land_037"]=true,
		["perimeter_attachment:kragmar:land_040"]=true,
	}
	for attachment_id,point in pairs(attachment_point) do local attachment=attachment_by_id[attachment_id]
		local perimeter=perimeter_by_id[attachment.perimeter_id]
		local segment=raster_segment(perimeter.polygon[attachment.perimeter_segment_index],
			perimeter.polygon[attachment.perimeter_segment_index+1])
		local best,best_distance,best_canonical_index
		for station_index=1,#segment do local station=segment[station_index]
			local distance=math.max(math.abs(station.x-point.x),math.abs(station.z-point.z))
			local canonical_index=perimeter_station_lookup[attachment.perimeter_id]
				[station.x..":"..station.z]
			assert(canonical_index,"attachment station absent from canonical perimeter")
			if not best_distance or distance<best_distance or
					(distance==best_distance and canonical_index<best_canonical_index) then
				best,best_distance,best_canonical_index=station,distance,canonical_index
			end
		end
		assert(best_distance<=1,
			"attachment requires an adjacent perimeter station: "..attachment_id..
			" point="..point.x..":"..point.z.." distance="..best_distance)
		local witness=expected_undisplaced_attachment_delta[attachment_id]
		if witness then
			assert(point.x==witness[1] and point.z==witness[2] and
				best.x==witness[3] and best.z==witness[4] and
				best_distance==witness[5],"undisplaced attachment E/A baseline drift: "..attachment_id)
		else
			assert(expected_undisplaced_exact_attachment[attachment_id] and best_distance==0 and
				point.x==best.x and point.z==best.z,
				"undisplaced attachment exact E=A baseline drift: "..attachment_id)
		end
		if best_distance==0 then
			baseline_exact_attachment_count=baseline_exact_attachment_count+1
		else baseline_adjacent_attachment_count=baseline_adjacent_attachment_count+1 end

		-- E chooses A but is not emitted. A replaces the authored outside terminal
		-- control before the one authoritative final edge raster.
		local edge=edge_by_id[attachment.edge_id]
		local final_control={}
		if attachment.edge_endpoint=="from" then
			final_control[1]=best
			for i=2,#edge.control do final_control[#final_control+1]=edge.control[i] end
		else
			for i=1,#edge.control-1 do final_control[#final_control+1]=edge.control[i] end
			final_control[#final_control+1]=best
		end
		local final_points=raster_polyline(final_control)
		local first_point,last_point=final_points[1],final_points[#final_points]
		local endpoint_chebyshev=math.max(
			math.abs(last_point.x-first_point.x),
			math.abs(last_point.z-first_point.z))
		local expected_station_steps=expected_attachment_station_steps[attachment_id]
		if expected_station_steps then
			baseline_reviewed_short_attachment_minimum=math.min(
				baseline_reviewed_short_attachment_minimum,endpoint_chebyshev)
			assert(endpoint_chebyshev==expected_station_steps,
				"undisplaced attachment station-step KAT drift: "..attachment_id)
		end
		local terminal=attachment.edge_endpoint=="from" and final_points[1] or
			final_points[#final_points]
		assert(terminal.x==best.x and terminal.z==best.z,
			"attachment final raster misses joint station A")
		local perimeter_polygon=perimeter_by_id[attachment.perimeter_id].polygon
		for i=1,#final_points do
			local is_terminal=attachment.edge_endpoint=="from" and i==1 or
				attachment.edge_endpoint=="to" and i==#final_points
			if not is_terminal then assert(point_strictly_in_polygon(
				final_points[i].x,final_points[i].z,perimeter_polygon),
				"attachment final edge station is not strict interior: "..attachment_id)
			end
			if i>1 then assert(math.max(math.abs(final_points[i].x-final_points[i-1].x),
				math.abs(final_points[i].z-final_points[i-1].z))==1,
				"attachment final edge is not 8-connected") end
		end
	end
	assert(baseline_exact_attachment_count==3 and
		baseline_adjacent_attachment_count==5,
		"undisplaced attachment exact/adjacent baseline drift")
	assert(baseline_reviewed_short_attachment_minimum==297,
		"undisplaced attachment minimum station-step baseline drift: "..
			baseline_reviewed_short_attachment_minimum)
	do
		local attachment=attachment_by_id["perimeter_attachment:kragmar:land_016"]
		local raw_points=raster_polyline(edge_by_id[attachment.edge_id].control)
		local raw_set={}
		for i=1,#raw_points do raw_set[raw_points[i].x..":"..raw_points[i].z]=true end
		local perimeter=perimeter_by_id[attachment.perimeter_id]
		local perimeter_points=raster_segment(
			perimeter.polygon[attachment.perimeter_segment_index],
			perimeter.polygon[attachment.perimeter_segment_index+1])
		local common=0
		for i=1,#perimeter_points do
			if raw_set[perimeter_points[i].x..":"..perimeter_points[i].z] then
				common=common+1
			end
		end
		assert(common==0,"land_016 unexpectedly regained a common raw raster station")
	end
	local ceil_isqrt
	local function point_in_base_bay(x,z,bay)
		for i=1,#bay.centreline-1 do local a,b=bay.centreline[i],bay.centreline[i+1]
			local dx,dz=b.x-a.x,b.z-a.z
			local length_squared=dx*dx+dz*dz
			local projection=(x-a.x)*dx+(z-a.z)*dz
			if projection<=0 then
				local px,pz=x-a.x,z-a.z
				if px*px+pz*pz<a.half_width*a.half_width then return true end
			elseif projection>=length_squared then
				local px,pz=x-b.x,z-b.z
				if px*px+pz*pz<b.half_width*b.half_width then return true end
			else
				local cross=dx*(z-a.z)-dz*(x-a.x)
				if math.abs(cross)>=math.max(a.half_width,b.half_width)*
						ceil_isqrt(length_squared) then
					-- Exact early rejection precedes every square product.
				else
				local width_numerator=a.half_width*(length_squared-projection)+
					b.half_width*projection
				if cross*cross*length_squared<width_numerator*width_numerator then
					return true
				end
				end
			end
		end
		return false
	end
	ceil_isqrt=function(value)
		local low,high=0,1
		while high<=value/high do high=high*2 end
		while low+1<high do local middle=math.floor((low+high)/2)
			if middle<=value/middle then low=middle else high=middle end end
		return low*low==value and low or low+1
	end
	local function point_in_wing(x,z,wing)
		local dx,dz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
		local px,pz=x-wing.head.x,z-wing.head.z
		local length_squared=dx*dx+dz*dz
		local projection=px*dx+pz*dz
		if projection<0 or projection>=length_squared then return false end
		local cross=dx*pz-dz*px
		if math.abs(cross)>=wing.head_half_width*ceil_isqrt(length_squared) then
			return false
		end
		local remaining=length_squared-projection
		return cross*cross*length_squared<
			wing.head_half_width*wing.head_half_width*remaining*remaining
	end
	local wings_by_bay={}
	for i=1,#source.bay_closure_wings do local wing=source.bay_closure_wings[i]
		wings_by_bay[wing.bay_id]=wings_by_bay[wing.bay_id] or {}
		wings_by_bay[wing.bay_id][#wings_by_bay[wing.bay_id]+1]=wing
	end
	local aperture_station_by_bay={}
	local function point_in_final_bay(x,z,bay)
		local perimeter_lookup=perimeter_station_lookup[bay.perimeter_projection.perimeter_id]
		local on_perimeter=perimeter_lookup[x..":"..z]~=nil
		if point_in_base_bay(x,z,bay) and (not on_perimeter or
				aperture_station_by_bay[bay.id] and aperture_station_by_bay[bay.id][x..":"..z]) then
			return true,"base"
		end
		if on_perimeter then return false end
		local wings=wings_by_bay[bay.id]
		for i=1,#wings do if point_in_wing(x,z,wings[i]) then return true,wings[i].id end end
		return false
	end
	local zone_numeric={}
	for i=1,#source.zones do zone_numeric[source.zones[i].id]=source.zones[i].numeric_id end
	local OWNER_SAFE_INTEGER=9007199254740991
	local owner_max_checked_product=0
	local owner_oracle_columns,owner_segment_ties,owner_changed_ties=0,0,0
	local first_owner_change
	local owner_ties_by_bay,owner_changes_by_bay={},{}
	for bay_index=1,#source.bays do
		owner_ties_by_bay[source.bays[bay_index].id]=0
		owner_changes_by_bay[source.bays[bay_index].id]=0
	end
	local function owner_safe_product(a,b)
		assert(type(a)=="number" and type(b)=="number" and a>=0 and b>=0 and
			math.floor(a)==a and math.floor(b)==b and
			(a==0 or b<=OWNER_SAFE_INTEGER/a),"Bay owner product exceeds 2^53-1")
		local product=a*b
		owner_max_checked_product=math.max(owner_max_checked_product,product)
		return product
	end
	local function owner_safe_signed_product(a,b)
		local product=owner_safe_product(math.abs(a),math.abs(b))
		return (a<0)~=(b<0) and -product or product
	end
	local function owner_safe_sum(a,b)
		local result=a+b
		assert(math.floor(a)==a and math.floor(b)==b and math.floor(result)==result and
			math.abs(result)<=OWNER_SAFE_INTEGER,"Bay owner sum exceeds 2^53-1")
		return result
	end
	local function owner_gcd(a,b)
		assert(a>=0 and b>=0 and math.floor(a)==a and math.floor(b)==b)
		while b~=0 do
			local quotient=math.floor(a/b)
			a,b=b,a-quotient*b
		end
		return a
	end
	local function compare_owner_rationals(a,b,c,d)
		assert(a>=0 and c>=0 and b>0 and d>0)
		if a==0 or c==0 then
			if a==c then return 0 end
			return a==0 and -1 or 1
		end
		local numerator_gcd=owner_gcd(a,c)
		local denominator_gcd=owner_gcd(b,d)
		local left=owner_safe_product(a/numerator_gcd,d/denominator_gcd)
		local right=owner_safe_product(c/numerator_gcd,b/denominator_gcd)
		if left<right then return -1 end
		if left>right then return 1 end
		return 0
	end
	-- Independent quotient/remainder comparator: no cross product and no use of
	-- the production-style GCD-reduced comparison above.
	local function oracle_compare_rationals(a,b,c,d)
		local reverse=false
		while true do
			local qa,qc=math.floor(a/b),math.floor(c/d)
			if qa~=qc then
				local result=qa<qc and -1 or 1
				return reverse and -result or result
			end
			local ra,rc=a-qa*b,c-qc*d
			if ra==0 or rc==0 then
				local result
				if ra==rc then result=0 elseif ra==0 then result=-1 else result=1 end
				return reverse and -result or result
			end
			a,b,c,d=b,ra,d,rc
			reverse=not reverse
		end
	end
	local function span_for_segment(bay,segment_index)
		for i=1,#bay.owner_spans do local span=bay.owner_spans[i]
			if segment_index>=span.first_segment and segment_index<=span.last_segment then
				return span
			end
		end
	end
	local function side_owner(left_zone_id,right_zone_id,cross)
		if cross>0 then return left_zone_id end
		if cross<0 then return right_zone_id end
		return zone_numeric[left_zone_id]<zone_numeric[right_zone_id] and
			left_zone_id or right_zone_id
	end
	local function owner_distance_candidate(x,z,a,b)
		local dx,dz=b.x-a.x,b.z-a.z
		local px,pz=x-a.x,z-a.z
		local length_squared=owner_safe_sum(owner_safe_signed_product(dx,dx),
			owner_safe_signed_product(dz,dz))
		local projection=owner_safe_sum(owner_safe_signed_product(px,dx),
			owner_safe_signed_product(pz,dz))
		local numerator,denominator,cross
		if projection<=0 then
			numerator=owner_safe_sum(owner_safe_product(math.abs(px),math.abs(px)),
				owner_safe_product(math.abs(pz),math.abs(pz)))
			denominator=1
			cross=owner_safe_sum(owner_safe_signed_product(dx,pz),
				-owner_safe_signed_product(dz,px))
		elseif projection>=length_squared then
			local ex,ez=x-b.x,z-b.z
			numerator=owner_safe_sum(owner_safe_product(math.abs(ex),math.abs(ex)),
				owner_safe_product(math.abs(ez),math.abs(ez)))
			denominator=1
			cross=owner_safe_sum(owner_safe_signed_product(dx,ez),
				-owner_safe_signed_product(dz,ex))
		else
			cross=owner_safe_sum(owner_safe_signed_product(dx,pz),
				-owner_safe_signed_product(dz,px))
			numerator=owner_safe_product(math.abs(cross),math.abs(cross))
			denominator=length_squared
		end
		return numerator,denominator,cross
	end
	local function oracle_owner_distance_candidate(x,z,a,b)
		local vx,vz=b.x-a.x,b.z-a.z
		local qx,qz=x-a.x,z-a.z
		local length=owner_safe_sum(owner_safe_product(math.abs(vx),math.abs(vx)),
			owner_safe_product(math.abs(vz),math.abs(vz)))
		local along=owner_safe_sum(owner_safe_signed_product(qx,vx),
			owner_safe_signed_product(qz,vz))
		local side=owner_safe_sum(owner_safe_signed_product(vx,qz),
			-owner_safe_signed_product(vz,qx))
		if along<=0 then
			return owner_safe_sum(owner_safe_product(math.abs(qx),math.abs(qx)),
				owner_safe_product(math.abs(qz),math.abs(qz))),1,side
		end
		if along>=length then
			local bx,bz=x-b.x,z-b.z
			return owner_safe_sum(owner_safe_product(math.abs(bx),math.abs(bx)),
				owner_safe_product(math.abs(bz),math.abs(bz))),1,side
		end
		return owner_safe_product(math.abs(side),math.abs(side)),length,side
	end
	local function base_bay_owner(x,z,bay)
		local best_numerator,best_denominator,best_owner,best_segment,legacy_owner
		local had_segment_tie=false
		for i=1,#bay.centreline-1 do local a,b=bay.centreline[i],bay.centreline[i+1]
			local numerator,denominator,cross=owner_distance_candidate(x,z,a,b)
			local span=assert(span_for_segment(bay,i))
			local owner=side_owner(span.left_zone_id,span.right_zone_id,cross)
			local comparison=best_numerator and compare_owner_rationals(numerator,
				denominator,best_numerator,best_denominator) or -1
			if comparison<0 then
				best_numerator,best_denominator,best_owner,best_segment,legacy_owner=
					numerator,denominator,owner,i,owner
			elseif comparison==0 then
				had_segment_tie=true
				if zone_numeric[owner]<zone_numeric[best_owner] then
					best_owner,best_segment=owner,i
				end
			end
		end
		return best_owner,best_segment,had_segment_tie,legacy_owner
	end
	local function oracle_base_bay_owner(x,z,bay)
		local best_numerator,best_denominator,best_owner,best_segment
		local had_segment_tie=false
		for segment_index=1,#bay.centreline-1 do
			local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
			local numerator,denominator,cross=
				oracle_owner_distance_candidate(x,z,a,b)
			local span=assert(span_for_segment(bay,segment_index))
			local owner
			if cross==0 then
				owner=zone_numeric[span.left_zone_id]<zone_numeric[span.right_zone_id] and
					span.left_zone_id or span.right_zone_id
			elseif cross>0 then owner=span.left_zone_id else owner=span.right_zone_id end
			local comparison=best_numerator and oracle_compare_rationals(numerator,
				denominator,best_numerator,best_denominator) or -1
			if comparison<0 then
				best_numerator,best_denominator,best_owner,best_segment=
					numerator,denominator,owner,segment_index
			elseif comparison==0 then
				had_segment_tie=true
				if zone_numeric[owner]<zone_numeric[best_owner] then
					best_owner,best_segment=owner,segment_index
				end
			end
		end
		return best_owner,best_segment,had_segment_tie
	end
	do
		local owner,segment,tied=base_bay_owner(-628,-2664,source.bays[1])
		assert(owner=="elandor_dawnmere_fields" and segment==1 and tied,
			"Elandor-west exact-distance lower-candidate KAT drift")
		owner,segment,tied=base_bay_owner(1080,-2580,source.bays[2])
		assert(owner=="elandor_dawnmere_fields" and segment==1 and tied,
			"Elandor-east vertex segment-tie KAT drift")
		owner,segment,tied=base_bay_owner(-940,-2770,source.bays[1])
		assert(owner=="elandor_hearthpine_vale" and segment==1,
			"Base-Bay C=0 lower-zone KAT drift")

		local synthetic_centreline={{x=0,z=0},{x=10,z=0},{x=10,z=10}}
		local later_lower={centreline=synthetic_centreline,owner_spans={
			{first_segment=1,last_segment=1,
				left_zone_id="elandor_goldmead_vale",
				right_zone_id="elandor_silverleaf_glades"},
			{first_segment=2,last_segment=2,
				left_zone_id="elandor_dawnmere_fields",
				right_zone_id="elandor_hearthpine_vale"},
		}}
		local first_n,first_d,first_c=owner_distance_candidate(12,0,
			synthetic_centreline[1],synthetic_centreline[2])
		local second_n,second_d,second_c=owner_distance_candidate(12,0,
			synthetic_centreline[2],synthetic_centreline[3])
		assert(first_n==4 and first_d==1 and first_c==0 and
			second_n==4 and second_d==1 and second_c==-20,
			"synthetic exact-distance C=0/side fixture drift")
		local legacy_owner
		owner,segment,tied,legacy_owner=base_bay_owner(12,0,later_lower)
		local oracle_owner,oracle_segment,oracle_tied=
			oracle_base_bay_owner(12,0,later_lower)
		assert(owner=="elandor_hearthpine_vale" and segment==2 and tied and
			oracle_owner==owner and oracle_segment==segment and oracle_tied and
			legacy_owner=="elandor_goldmead_vale" and legacy_owner~=owner,
			"later lower-numeric tied-segment owner KAT drift")

		local first_lower={centreline=synthetic_centreline,owner_spans={
			{first_segment=1,last_segment=1,
				left_zone_id="elandor_hearthpine_vale",
				right_zone_id="elandor_dawnmere_fields"},
			{first_segment=2,last_segment=2,
				left_zone_id="elandor_silverleaf_glades",
				right_zone_id="elandor_goldmead_vale"},
		}}
		owner,segment,tied,legacy_owner=base_bay_owner(12,0,first_lower)
		oracle_owner,oracle_segment,oracle_tied=
			oracle_base_bay_owner(12,0,first_lower)
		assert(owner=="elandor_hearthpine_vale" and segment==1 and tied and
			oracle_owner==owner and oracle_segment==segment and oracle_tied and
			legacy_owner==owner,
			"first lower-numeric tied-segment owner KAT drift")
	end
	local function final_bay_owner(x,z,bay)
		local perimeter_lookup=perimeter_station_lookup[bay.perimeter_projection.perimeter_id]
		local on_perimeter=perimeter_lookup[x..":"..z]~=nil
		if point_in_base_bay(x,z,bay) and (not on_perimeter or
				aperture_station_by_bay[bay.id] and aperture_station_by_bay[bay.id][x..":"..z]) then
			return assert(base_bay_owner(x,z,bay))
		end
		local wing_owner,wing_count
		wing_count=0
		for i=1,#wings_by_bay[bay.id] do local wing=wings_by_bay[bay.id][i]
			if point_in_wing(x,z,wing) then
				local dx,dz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
				local cross=dx*(z-wing.head.z)-dz*(x-wing.head.x)
				wing_owner=side_owner(wing.left_zone_id,wing.right_zone_id,cross)
				wing_count=wing_count+1
			end
		end
		return wing_owner,wing_count
	end
	local aperture_runs={}
	local aperture_expected_counts={711,664,638,719}
	local aperture_expected_widths={720,660,640,740}
	for aperture_index=1,#source.bay_mouth_apertures do local aperture=source.bay_mouth_apertures[aperture_index]
		local bay=source.bays[aperture_index]
		assert(aperture.bay_id==bay.id)
		local stations=perimeter_stations_by_id[aperture.perimeter_id]
		local mouth=bay.centreline[1]
		local mouth_index=assert(perimeter_station_lookup[aperture.perimeter_id][mouth.x..":"..mouth.z])
		local first,last=mouth_index,mouth_index
		while first>1 and point_in_base_bay(stations[first-1].x,stations[first-1].z,bay) do first=first-1 end
		while last<#stations and point_in_base_bay(stations[last+1].x,stations[last+1].z,bay) do last=last+1 end
		assert(first>1 and last<#stations and first<=mouth_index and mouth_index<=last,
			"Bay aperture must be one nonwrapping run")
		local included={}
		for station_index=first,last do local station=stations[station_index]
			assert(point_in_base_bay(station.x,station.z,bay))
			included[station.x..":"..station.z]=true
		end
		local before,excluded_end=stations[first-1],stations[last+1]
		assert(not point_in_base_bay(before.x,before.z,bay) and
			not point_in_base_bay(excluded_end.x,excluded_end.z,bay))
		aperture_station_by_bay[bay.id]=included
		aperture_runs[bay.id]={first=first,last=last,count=last-first+1,
			first_point=stations[first],last_point=stations[last],before=before,
			excluded_end=excluded_end}
		assert(last-first+1==aperture_expected_counts[aperture_index] and
			2*mouth.half_width==aperture_expected_widths[aperture_index],
			"derived Bay aperture run/width KAT drift: "..bay.id)
	end

	-- Independent R15 joint-tail wedge oracle. The closing K+ -> K- chord is
	-- used only by the exact point classifier below; it is never rasterized or
	-- returned as materialized geometry.
	do
		local wing_by_id,bay_by_id={},{ }
		for i=1,#source.bays do bay_by_id[source.bays[i].id]=source.bays[i] end
		for i=1,#source.bay_closure_wings do
			wing_by_id[source.bay_closure_wings[i].id]=source.bay_closure_wings[i]
		end
		local function point_key(point) return point.x..":"..point.z end
		local function point_signature(points)
			local result={}
			for i=1,#points do result[i]=point_key(points[i]) end
			return table.concat(result,",")
		end
		local function final_planned_water(x,z)
			for bay_index=1,#source.bays do
				if point_in_final_bay(x,z,source.bays[bay_index]) then return true end
			end
			return false
		end
		local function final_dry(bay,x,z)
			return point_in_polygon(x,z,
				perimeter_by_id[bay.perimeter_projection.perimeter_id].polygon) and
				not final_planned_water(x,z)
		end
		local cardinals={{x=1,z=0},{x=0,z=1},{x=-1,z=0},{x=0,z=-1}}
		local function select_wing_k(wing,sign)
			local bay=assert(bay_by_id[wing.bay_id])
			local vx,vz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
			local length=vx*vx+vz*vz
			local best
			for z=math.min(wing.head.z,wing.junction.z)-wing.head_half_width,
					math.max(wing.head.z,wing.junction.z)+wing.head_half_width do
				for x=math.min(wing.head.x,wing.junction.x)-wing.head_half_width,
						math.max(wing.head.x,wing.junction.x)+wing.head_half_width do
					local px,pz=x-wing.head.x,z-wing.head.z
					local projection=px*vx+pz*vz
					local cross=vx*pz-vz*px
					local adjacent_own_water=false
					for direction_index=1,#cardinals do local direction=cardinals[direction_index]
						if point_in_wing(x+direction.x,z+direction.z,wing) then
							adjacent_own_water=true break
						end
					end
					if final_dry(bay,x,z) and adjacent_own_water and projection>=0 and
							projection<length and
							(sign<0 and cross<0 or sign>0 and cross>0) and
							(not best or projection>best.projection or
							projection==best.projection and
								(x<best.x or x==best.x and z<best.z)) then
						best={x=x,z=z,projection=projection}
					end
				end
			end
			assert(best,"R15 K set is empty: "..wing.id)
			return {x=best.x,z=best.z}
		end
		local function enumerate_side_paths(wing,k,sign)
			local bay=assert(bay_by_id[wing.bay_id])
			local junction=wing.junction
			local vx,vz=junction.x-wing.head.x,junction.z-wing.head.z
			local result,path={},{ {x=k.x,z=k.z} }
			local function visit(current)
				local distance=math.max(math.abs(current.x-junction.x),
					math.abs(current.z-junction.z))
				if distance==0 then
					local copy={}
					for i=1,#path do copy[i]={x=path[i].x,z=path[i].z} end
					result[#result+1]=copy
					return
				end
				local next_points={}
				for dz=-1,1 do for dx=-1,1 do
					if dx~=0 or dz~=0 then
						local x,z=current.x+dx,current.z+dz
						local next_distance=math.max(math.abs(x-junction.x),
							math.abs(z-junction.z))
						if next_distance==distance-1 then
							local cross=vx*(z-wing.head.z)-vz*(x-wing.head.x)
							if x==junction.x and z==junction.z or
									(final_dry(bay,x,z) and
									(sign<0 and cross<0 or sign>0 and cross>0)) then
								next_points[#next_points+1]={x=x,z=z}
							end
						end
					end
				end end
				table.sort(next_points,function(a,b)
					return a.x<b.x or a.x==b.x and a.z<b.z
				end)
				for next_index=1,#next_points do
					path[#path+1]=next_points[next_index]
					visit(next_points[next_index])
					path[#path]=nil
				end
			end
			visit(k)
			return result
		end
		local function add_diagonals(path,diagonals)
			for i=1,#path-1 do local a,b=path[i],path[i+1]
				local dx,dz=b.x-a.x,b.z-a.z
				if math.abs(dx)==1 and math.abs(dz)==1 then
					local cell=math.min(a.x,b.x)..":"..math.min(a.z,b.z)
					local slope=dx==dz and 1 or -1
					if diagonals[cell] and diagonals[cell]~=slope then return false end
					diagonals[cell]=slope
				end
			end
			return true
		end
		local function structural_pair(negative,positive)
			local occupied={}
			for i=1,#negative-1 do occupied[point_key(negative[i])]=true end
			for i=1,#positive-1 do
				if occupied[point_key(positive[i])] then return false end
			end
			if point_key(negative[#negative-1])==point_key(positive[#positive-1]) then
				return false
			end
			local diagonals={}
			return add_diagonals(negative,diagonals) and
				add_diagonals(positive,diagonals)
		end
		local function path_less(a,b)
			for i=1,math.min(#a,#b) do
				if a[i].x~=b[i].x then return a[i].x<b[i].x end
				if a[i].z~=b[i].z then return a[i].z<b[i].z end
			end
			return #a<#b
		end
		local function pair_less(a,b)
			if path_less(a.negative,b.negative) then return true end
			if path_less(b.negative,a.negative) then return false end
			return path_less(a.positive,b.positive)
		end
		local function orientation(a,b,c)
			return (b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
		end
		local function on_segment(a,b,p)
			return orientation(a,b,p)==0 and p.x>=math.min(a.x,b.x) and
				p.x<=math.max(a.x,b.x) and p.z>=math.min(a.z,b.z) and
				p.z<=math.max(a.z,b.z)
		end
		local function segments_intersect(a,b,c,d)
			local ab_c,ab_d=orientation(a,b,c),orientation(a,b,d)
			local cd_a,cd_b=orientation(c,d,a),orientation(c,d,b)
			return ab_c==0 and on_segment(a,b,c) or
				ab_d==0 and on_segment(a,b,d) or
				cd_a==0 and on_segment(c,d,a) or
				cd_b==0 and on_segment(c,d,b) or
				((ab_c<0)~=(ab_d<0) and (cd_a<0)~=(cd_b<0))
		end
		local function wedge_polygon(pair)
			local polygon={}
			for i=1,#pair.negative do
				polygon[#polygon+1]={x=pair.negative[i].x,z=pair.negative[i].z}
			end
			for i=#pair.positive-1,1,-1 do
				polygon[#polygon+1]={x=pair.positive[i].x,z=pair.positive[i].z}
			end
			local seen={}
			for i=1,#polygon do
				if seen[point_key(polygon[i])] then return nil,"tail_wedge_not_simple" end
				seen[point_key(polygon[i])]=true
			end
			local area2=0
			for i=1,#polygon do local a,b=polygon[i],polygon[i%#polygon+1]
				area2=area2+a.x*b.z-b.x*a.z
			end
			if area2==0 then return nil,"tail_wedge_zero_area" end
			for first=1,#polygon do local a,b=polygon[first],polygon[first%#polygon+1]
				for second=first+1,#polygon do
					if second~=first+1 and not (first==1 and second==#polygon) then
						local c,d=polygon[second],polygon[second%#polygon+1]
						if segments_intersect(a,b,c,d) then
							return nil,"tail_wedge_not_simple"
						end
					end
				end
			end
			return polygon
		end
		local function classify_polygon(x,z,polygon)
			local winding=0
			for i=1,#polygon do local a,b=polygon[i],polygon[i%#polygon+1]
				local side=(b.x-a.x)*(z-a.z)-(b.z-a.z)*(x-a.x)
				if side==0 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
						z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then
					return 0
				end
				if a.z<=z then
					if b.z>z and side>0 then winding=winding+1 end
				elseif b.z<=z and side<0 then winding=winding-1 end
			end
			return winding==0 and -1 or 1
		end
		local function analyze_wedge(wing,pair)
			local polygon,polygon_failure=wedge_polygon(pair)
			if not polygon then return nil,polygon_failure end
			local junction=wing.junction
			local negative_distance=math.max(
				math.abs(pair.negative[1].x-junction.x),
				math.abs(pair.negative[1].z-junction.z))
			local positive_distance=math.max(
				math.abs(pair.positive[1].x-junction.x),
				math.abs(pair.positive[1].z-junction.z))
			local radius=math.max(negative_distance,positive_distance)+1
			if radius>5 then return nil,"tail_wedge_radius" end
			local exempt={}
			for i=1,#pair.negative do exempt[point_key(pair.negative[i])]=true end
			for i=1,#pair.positive do exempt[point_key(pair.positive[i])]=true end
			local dry_columns={}
			for z=junction.z-radius,junction.z+radius do
				for x=junction.x-radius,junction.x+radius do
					if classify_polygon(x,z,polygon)>=0 and not exempt[x..":"..z] and
							not point_in_wing(x,z,wing) then
						dry_columns[#dry_columns+1]={x=x,z=z}
					end
				end
			end
			return {radius=radius,dry_columns=dry_columns,polygon=polygon}
		end
		local function select_wedge_valid_pair(wing,pairs)
			table.sort(pairs,pair_less)
			local wedge_valid={}
			for pair_index=1,#pairs do
				local analysis=analyze_wedge(wing,pairs[pair_index])
				if analysis and #analysis.dry_columns==0 then
					wedge_valid[#wedge_valid+1]={rank=pair_index,pair=pairs[pair_index],
						analysis=analysis}
				end
			end
			return wedge_valid[1],wedge_valid
		end
		local expected={
			["bay_wing:elandor_west:left"]={4,1,1,4,4,3,0,
				"-1397:-1900,-1398:-1900,-1399:-1900,-1400:-1900",
				"-1398:-1901,-1399:-1901,-1400:-1900",""},
			["bay_wing:elandor_west:right"]={18,1,10,5,4,5,1,
				"-403:-1901,-402:-1901,-401:-1901,-400:-1900",
				"-404:-1900,-403:-1900,-402:-1900,-401:-1900,-400:-1900",
				"-402:-1901"},
			["bay_wing:elandor_east:left"]={18,1,2,5,5,4,1,
				"404:-1900,403:-1900,402:-1900,401:-1900,400:-1900",
				"403:-1901,402:-1901,401:-1901,400:-1900","402:-1901"},
			["bay_wing:elandor_east:right"]={4,1,1,4,3,4,0,
				"1398:-1901,1399:-1901,1400:-1900",
				"1397:-1900,1398:-1900,1399:-1900,1400:-1900",""},
			["bay_wing:kragmar_west:left"]={2,1,2,3,2,3,1,
				"-1399:1901,-1400:1900","-1398:1900,-1399:1900,-1400:1900",
				"-1399:1900"},
			["bay_wing:kragmar_west:right"]={18,1,17,5,5,4,4,
				"-404:1900,-403:1900,-402:1900,-401:1900,-400:1900",
				"-403:1901,-402:1901,-401:1901,-400:1900",
				"-402:1899,-403:1900,-402:1900,-401:1900"},
			["bay_wing:kragmar_east:left"]={18,1,9,5,4,5,4,
				"403:1901,402:1901,401:1901,400:1900",
				"404:1900,403:1900,402:1900,401:1900,400:1900",
				"402:1899,401:1900,402:1900,403:1900"},
			["bay_wing:kragmar_east:right"]={18,1,17,5,5,4,4,
				"1396:1900,1397:1900,1398:1900,1399:1900,1400:1900",
				"1397:1901,1398:1901,1399:1901,1400:1900",
				"1398:1899,1397:1900,1398:1900,1399:1900"},
		}
		local raw_total,wedge_total,old_dry_total,new_dry_total=0,0,0,0
		local selected_by_wing={}
		for wing_index=1,#source.bay_closure_wings do
			local wing=source.bay_closure_wings[wing_index]
			local golden=assert(expected[wing.id],"unknown R15 Wing: "..wing.id)
			local negative_k=select_wing_k(wing,-1)
			local positive_k=select_wing_k(wing,1)
			local negative_paths=enumerate_side_paths(wing,negative_k,-1)
			local positive_paths=enumerate_side_paths(wing,positive_k,1)
			local pairs={}
			for negative_index=1,#negative_paths do
				for positive_index=1,#positive_paths do
					if structural_pair(negative_paths[negative_index],
							positive_paths[positive_index]) then
						pairs[#pairs+1]={negative=negative_paths[negative_index],
							positive=positive_paths[positive_index]}
					end
				end
			end
			local selected,wedge_valid=select_wedge_valid_pair(wing,pairs)
			assert(selected,"R15 has no wedge-valid pair: "..wing.id)
			local old_analysis=assert(analyze_wedge(wing,pairs[1]))
			assert(#pairs==golden[1] and #wedge_valid==golden[2] and
				selected.rank==golden[3] and selected.analysis.radius==golden[4] and
				#selected.pair.negative==golden[5] and
				#selected.pair.positive==golden[6] and
				#old_analysis.dry_columns==golden[7] and
				point_signature(selected.pair.negative)==golden[8] and
				point_signature(selected.pair.positive)==golden[9] and
				point_signature(old_analysis.dry_columns)==golden[10],
				"R15 Wing golden drift: "..wing.id)
			assert(#selected.analysis.dry_columns==0,
				"R15 selected wedge retained a dry column: "..wing.id)
			local reversed={}
			for i=#selected.pair.negative,1,-1 do
				reversed[#reversed+1]=selected.pair.negative[i]
			end
			for i=1,#reversed do
				assert(point_key(reversed[i])==
					point_key(selected.pair.negative[#selected.pair.negative-i+1]),
					"R15 reverse is not byte-exact: "..wing.id)
			end
			selected_by_wing[wing.id]={pair=selected.pair,pairs=pairs}
			raw_total=raw_total+#pairs
			wedge_total=wedge_total+#wedge_valid
			old_dry_total=old_dry_total+#old_analysis.dry_columns
			new_dry_total=new_dry_total+#selected.analysis.dry_columns
			expected[wing.id]=nil
		end
		assert(next(expected)==nil and raw_total==100 and wedge_total==8 and
			old_dry_total==15 and new_dry_total==0,
			"R15 all-Wing 100/8 and 15-to-0 corpus drift")
		do
			local wing=assert(wing_by_id["bay_wing:elandor_west:right"])
			local selected=selected_by_wing[wing.id]
			local old_only=assert(analyze_wedge(wing,selected.pairs[1]))
			assert(#old_only.dry_columns==1,
				"R15 old lex-first dry-gap mutation was not rejected")
			local no_pair=select_wedge_valid_pair(wing,{selected.pairs[1]})
			assert(not no_pair,"R15 no-wedge-valid-pair mutation was accepted")
			local zero_area={negative={{x=0,z=0},{x=1,z=0}},
				positive={{x=2,z=0},{x=1,z=0}}}
			local _,failure=analyze_wedge(wing,zero_area)
			assert(failure=="tail_wedge_zero_area",
				"R15 zero-area wedge mutation was accepted")
			local self_crossing={negative={{x=0,z=0},{x=3,z=3},{x=0,z=3}},
				positive={{x=2,z=0},{x=0,z=3}}}
			_,failure=analyze_wedge(wing,self_crossing)
			assert(failure=="tail_wedge_not_simple",
				"R15 self-intersecting wedge mutation was accepted")
			local over_radius={negative={{x=wing.junction.x-6,z=wing.junction.z},
				{x=wing.junction.x,z=wing.junction.z}},
				positive={{x=wing.junction.x,z=wing.junction.z-1},
				{x=wing.junction.x,z=wing.junction.z}}}
			_,failure=analyze_wedge(wing,over_radius)
			assert(failure=="tail_wedge_radius",
				"R15 radius-above-five mutation was accepted")
			local synthetic_wing={id="synthetic_wedge",bay_id=wing.bay_id,
				head={x=0,z=-4},junction={x=0,z=0},head_half_width=4}
			local chord_pair={
				negative={{x=2,z=-2},{x=1,z=-1},{x=0,z=0}},
				positive={{x=-2,z=-2},{x=-1,z=-1},{x=0,z=0}},
			}
			local chord_analysis=assert(analyze_wedge(synthetic_wing,chord_pair))
			assert(#chord_analysis.dry_columns==0,
				"R15 strict-Wing chord-interior fixture did not pass")
			synthetic_wing.head_half_width=2
			chord_analysis=assert(analyze_wedge(synthetic_wing,chord_pair))
			assert(#chord_analysis.dry_columns>0,
				"R15 dry nonterminal chord-column mutation was accepted")
			synthetic_wing.head_half_width=8
			local lex_later={negative={{x=2,z=-1},{x=1,z=0},{x=0,z=0}},
				positive={{x=-2,z=-2},{x=-1,z=-1},{x=0,z=0}}}
			local lex_first={negative={{x=2,z=-1},{x=1,z=-1},{x=0,z=0}},
				positive={{x=-2,z=-2},{x=-1,z=-1},{x=0,z=0}}}
			local selected_synthetic,valid_synthetic=select_wedge_valid_pair(
				synthetic_wing,{lex_later,lex_first})
			assert(selected_synthetic and #valid_synthetic==2 and
				point_signature(selected_synthetic.pair.negative)==
					point_signature(lex_first.negative),
				"R15 multiple wedge-valid pairs did not select lexicographically first")
		end
		print("WP40 T2 R15 Wing-wedge oracle passed: 100 raw pairs, 8 wedge pairs, "..
			"15->0 dry columns, R<=5")
	end
	-- With coordinate-free R11 banks, Stage 1 independently exhausts water
	-- membership/owner arithmetic only. Closed dry-face coverage belongs to
	-- the complete Stage-2 materialization corpus.
	for bay_index=1,#source.bays do local bay=source.bays[bay_index]
		local min_x,max_x,min_z,max_z
		for i=1,#bay.centreline do local p=bay.centreline[i]
			min_x=math.min(min_x or p.x-p.half_width,p.x-p.half_width)
			max_x=math.max(max_x or p.x+p.half_width,p.x+p.half_width)
			min_z=math.min(min_z or p.z-p.half_width,p.z-p.half_width)
			max_z=math.max(max_z or p.z+p.half_width,p.z+p.half_width)
		end
		for z=min_z,max_z do for x=min_x,max_x do
			if point_in_base_bay(x,z,bay) then
				local actual,actual_segment,tied,legacy_owner=base_bay_owner(x,z,bay)
				local expected,expected_segment,oracle_tied=oracle_base_bay_owner(x,z,bay)
				assert(actual==expected and actual_segment==expected_segment and
					tied==oracle_tied,"R11 Base-Bay owner oracle drift: "..bay.id)
				owner_oracle_columns=owner_oracle_columns+1
				if tied then owner_segment_ties=owner_segment_ties+1
					owner_ties_by_bay[bay.id]=owner_ties_by_bay[bay.id]+1
					if actual~=legacy_owner then owner_changed_ties=owner_changed_ties+1
						owner_changes_by_bay[bay.id]=owner_changes_by_bay[bay.id]+1
						first_owner_change=first_owner_change or
							(bay.id..":"..x..","..z..":"..legacy_owner.."->"..actual)
					end
				end
			end
		end end
	end
	assert(owner_oracle_columns>0 and owner_segment_ties>0 and
		owner_max_checked_product<=OWNER_SAFE_INTEGER,
		("Base-Bay owner exhaustive proof did not exercise its exact contracts: "..
			"columns=%d ties=%d changes=%d max_product=%d"):format(
			owner_oracle_columns,owner_segment_ties,owner_changed_ties,
			owner_max_checked_product))
	local owner_bay_counts={}
	for bay_index=1,#source.bays do local bay_id=source.bays[bay_index].id
		owner_bay_counts[#owner_bay_counts+1]=bay_id..":"..owner_ties_by_bay[bay_id]..
			"/"..owner_changes_by_bay[bay_id]
	end
	print(("WP40 T2 Base-Bay owner oracle passed: %d columns, %d segment ties, "..
		"%d lower-candidate changes (first %s), by Bay ties/changes %s, "..
		"max checked product %d"):format(
		owner_oracle_columns,owner_segment_ties,owner_changed_ties,
		tostring(first_owner_change),table.concat(owner_bay_counts,","),
		owner_max_checked_product))
end

if arg._wp40_phase.enabled("source_literal_contract") then
-- Every relationship above is reconstructed from the one edge authority;
-- zone rows intentionally contain no copied neighbor arrays.
for i = 1, #source.zones do assert(source.zones[i].neighbors == nil) end

-- The two continents are independent authored records, not reflected aliases.
local ep, kp = source.perimeters[1], source.perimeters[2]
assert(ep ~= kp and ep.polygon ~= kp.polygon and
	ep.noise_domain ~= kp.noise_domain and
	ep.polygon[2].x ~= kp.polygon[2].x and
	ep.polygon[14].z ~= -kp.polygon[14].z)
assert(source.bays[1].centreline ~= source.bays[3].centreline and
	source.bays[1].centreline[2].x ~= source.bays[3].centreline[2].x)

assert(source.constants.holy_grounds.min_x == -2500 and
	source.constants.holy_grounds.max_x == 2500 and
	source.constants.holy_grounds.min_z == -250 and
	source.constants.holy_grounds.max_z == 250)
assert(source.constants.holy_junction_x[1] == -1500 and
	source.constants.holy_junction_x[2] == 0 and
	source.constants.holy_junction_x[3] == 1500)
assert(source.islands[1].center.x == -3150 and
	source.islands[2].center.x == 3150)
assert(source.constants.coastal_shelf_width == 80 and
	source.constants.flight_warning_width == 48 and
	source.constants.minimum_hard_flight_width == 104)

local critical=source.critical_source_manifest
assert(critical.id=="critical_source_manifest" and
	critical.schema=="grug_wp40_critical_source_manifest_v1" and
	critical.mg_name=="v7" and critical.water_level==1 and
	critical.chunksize==5 and critical.num_emerge_threads==1 and
	critical.mgv7_dungeon_ymin==-31000 and
	critical.mgv7_dungeon_ymax==-193 and
	critical.broad_content_y_min==-37 and
	critical.force_native_dungeon==false)
assert(table.concat(critical.mg_flags,",")==
	"dungeons,biomes,caves,ores,decorations,light")
assert(#critical.mgv7_special_flags==4 and
	critical.mgv7_special_flags[1].id=="mountains" and
	critical.mgv7_special_flags[1].enabled==true and
	critical.mgv7_special_flags[2].id=="ridges" and
	critical.mgv7_special_flags[2].enabled==true and
	critical.mgv7_special_flags[3].id=="floatlands" and
	critical.mgv7_special_flags[3].enabled==false and
	critical.mgv7_special_flags[4].id=="caverns" and
	critical.mgv7_special_flags[4].enabled==true)
local dungeon_noise=critical.mgv7_np_dungeons
assert(dungeon_noise.offset.numerator==9 and
	dungeon_noise.offset.denominator==10 and
	dungeon_noise.scale.numerator==1 and
	dungeon_noise.scale.denominator==2 and dungeon_noise.spread.x==500 and
	dungeon_noise.spread.y==500 and dungeon_noise.spread.z==500 and
	dungeon_noise.seed==0 and dungeon_noise.octaves==2 and
	dungeon_noise.persistence.numerator==4 and
	dungeon_noise.persistence.denominator==5 and
	dungeon_noise.lacunarity==2 and #dungeon_noise.flags==1 and
	dungeon_noise.flags[1]=="defaults")
end

if arg._wp40_phase.enabled("logical_biome_selector") then
-- Independent logical-biome selector KAT. The deliberately over-53-bit seed
-- stays a decimal byte string all the way into SHA-256; it is never converted
-- to a Lua number. This oracle exercises the exact cell, jitter, distance,
-- tie and palette-roll rules frozen by the source policy.
local biome_selector=source.geometry_policies.logical_biome_selector
assert(biome_selector.id=="zone_palette_jittered_voronoi_t1_hash_v1" and
	biome_selector.cell_size==192 and biome_selector.site_offset_min==32 and
	biome_selector.site_offset_span==128)
local function logical_site(seed,x,z)
	local hash=deterministic.new_hash(canonical,raw_sha256,
		biome_selector.hash_schema,seed)
	local size=biome_selector.cell_size
	local base_x,base_z=math.floor(x/size),math.floor(z/size)
	local best
	for cell_x=base_x-1,base_x+1 do
		for cell_z=base_z-1,base_z+1 do
			local site_x=cell_x*size+biome_selector.site_offset_min+
				hash.range(biome_selector.hash_domain,
					biome_selector.hash_feature_id,{cell_x,cell_z},
					biome_selector.hash_candidate_index,
					biome_selector.hash_lanes.site_x,
					biome_selector.site_offset_span)
			local site_z=cell_z*size+biome_selector.site_offset_min+
				hash.range(biome_selector.hash_domain,
					biome_selector.hash_feature_id,{cell_x,cell_z},
					biome_selector.hash_candidate_index,
					biome_selector.hash_lanes.site_z,
					biome_selector.site_offset_span)
			local dx,dz=site_x-x,site_z-z
			local distance=dx*dx+dz*dz
			if not best or distance<best.distance or
					(distance==best.distance and (cell_x<best.cell_x or
					(cell_x==best.cell_x and cell_z<best.cell_z))) then
				best={distance=distance,cell_x=cell_x,cell_z=cell_z,
					site_x=site_x,site_z=site_z,
					roll=hash.range(biome_selector.hash_domain,
						biome_selector.hash_feature_id,{cell_x,cell_z},
						biome_selector.hash_candidate_index,
						biome_selector.hash_lanes.palette,100)}
			end
		end
	end
	return best
end
local full_seed="18446744073709551615"
for _,fixture in ipairs({
	{0,0,3145,0,-1,36,-43,9},
	{-193,191,12218,-2,1,-290,244,30},
	{2599,-2999,905,13,-16,2570,-3007,50},
}) do
	local got=logical_site(full_seed,fixture[1],fixture[2])
	assert(got.distance==fixture[3] and got.cell_x==fixture[4] and
		got.cell_z==fixture[5] and got.site_x==fixture[6] and
		got.site_z==fixture[7] and got.roll==fixture[8],
		"logical-biome full-seed KAT drift")
end
local function palette_at_roll(zone,roll)
	local cumulative=0
	for i=1,#zone.biomes do
		cumulative=cumulative+zone.biomes[i].share
		if cumulative>roll then return zone.biomes[i].id end
	end
end
local palette_zone=source.zones[4]
assert(palette_at_roll(palette_zone,0)=="grug_pine_hills" and
	palette_at_roll(palette_zone,54)=="grug_pine_hills" and
	palette_at_roll(palette_zone,55)=="grug_crags" and
	palette_at_roll(palette_zone,94)=="grug_crags" and
	palette_at_roll(palette_zone,95)=="grug_swamp" and
	palette_at_roll(palette_zone,99)=="grug_swamp")
end

-- Generic policy KATs cover the exact tie/rounding equations independently of
-- the catalog checksums. These values exercise negative floor division,
-- raster major-axis ties, smootherstep endpoints/midpoint and lower-median
-- selection used by housing smoothing.
assert(deterministic.floor_div(-1,192)==-1 and
	deterministic.floor_div(-192,192)==-1 and
	deterministic.floor_div(-193,192)==-2)
assert(deterministic.smootherstep(0)==0 and
	deterministic.smootherstep(32768)==32768 and
	deterministic.smootherstep(65536)==65536)
local function raster_canonical_points(x0,z0,x1,z1)
	local reverse=x0>x1 or (x0==x1 and z0>z1)
	if reverse then x0,z0,x1,z1=x1,z1,x0,z0 end
	local dx,dz=math.abs(x1-x0),math.abs(z1-z0)
	local sx,sz=x0<=x1 and 1 or -1,z0<=z1 and 1 or -1
	local x_major=dx>=dz
	local major,minor=x_major and dx or dz,x_major and dz or dx
	local error=2*minor-major
	local points={}
	for step=0,major do
		points[#points+1]={x=x0,z=z0}
		if step<major then
			if x_major then x0=x0+sx else z0=z0+sz end
			if error>=0 then
				if x_major then z0=z0+sz else x0=x0+sx end
				error=error-2*major
			end
			error=error+2*minor
		end
	end
	if reverse then
		for i=1,math.floor(#points/2) do
			points[i],points[#points-i+1]=points[#points-i+1],points[i]
		end
	end
	return points
end

-- Exhaustive reviewed Bay-projection Reality corpus. Enumerate every integer
-- column of every authored segment bbox enlarged by its maximum varied radius,
-- retain only strict segment-body columns inside the exact +48 envelope, and
-- compare the specified Euclidean raster-station owner with parameter round.
if arg._wp40_phase.enabled("bay_projection_oracle") then
	local relevant_columns=0
	local maximum_executed_lhs=0
	local first_divergence
	local function ceil_isqrt_exact(value)
		local low,high=0,1
		while high<=value/high do high=high*2 end
		while low+1<high do local middle=math.floor((low+high)/2)
			if middle<=value/middle then low=middle else high=middle end
		end
		return low*low==value and low or low+1
	end
	for bay_index=1,#source.bays do local bay=source.bays[bay_index]
		for segment_index=1,#bay.centreline-1 do
			local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
			local vx,vz=b.x-a.x,b.z-a.z
			local length_squared=vx*vx+vz*vz
			local maximum_varied_radius=math.max(a.half_width,b.half_width)+48
			local early_cross_bound=maximum_varied_radius*
				ceil_isqrt_exact(length_squared)
			local points=raster_canonical_points(a.x,a.z,b.x,b.z)
			for x=math.min(a.x,b.x)-maximum_varied_radius,
					math.max(a.x,b.x)+maximum_varied_radius do
				for z=math.min(a.z,b.z)-maximum_varied_radius,
						math.max(a.z,b.z)+maximum_varied_radius do
					local px,pz=x-a.x,z-a.z
					local projection=px*vx+pz*vz
					if projection>0 and projection<length_squared then
						local cross=vx*pz-vz*px
						if math.abs(cross)<early_cross_bound then
							local lhs=cross*cross*length_squared
							maximum_executed_lhs=math.max(maximum_executed_lhs,lhs)
							local effective_width=(a.half_width+48)*
								(length_squared-projection)+
								(b.half_width+48)*projection
						if lhs<effective_width*effective_width then
							relevant_columns=relevant_columns+1
							local euclidean_index,euclidean_distance
							for station_index=1,#points do
								local sx,sz=points[station_index].x-x,
									points[station_index].z-z
								local squared=sx*sx+sz*sz
								if not euclidean_distance or squared<euclidean_distance then
									euclidean_index,euclidean_distance=
										station_index,squared
								end
							end
							local parametric_index=math.floor(
								(2*projection*(#points-1)+length_squared)/
								(2*length_squared))+1
							if not first_divergence and
									euclidean_index~=parametric_index then
								first_divergence={bay.id,segment_index,x,z,
									euclidean_index-1,points[euclidean_index].x,
									points[euclidean_index].z,parametric_index-1,
									points[parametric_index].x,points[parametric_index].z}
							end
						end end
					end
				end
			end
		end
	end
	assert(relevant_columns==2290129,
		"Bay projection exhaustive relevant-column count drift: "..relevant_columns)
	local reviewed_algebraic_early_cross_bound=4251754341463400
	assert(maximum_executed_lhs==4251571423760000 and
		maximum_executed_lhs<=reviewed_algebraic_early_cross_bound,
		"Bay projection exhaustive guarded LHS maximum drift: "..
			maximum_executed_lhs)
	assert(first_divergence and first_divergence[1]=="bay_elandor_west" and
		first_divergence[2]==1 and first_divergence[3]==-1376 and
		first_divergence[4]==-2846 and first_divergence[5]==2 and
		first_divergence[6]==-980 and first_divergence[7]==-2938 and
		first_divergence[8]==1 and first_divergence[9]==-980 and
		first_divergence[10]==-2939,
		"Bay projection exhaustive first-divergence KAT drift")
end
local function raster_signature(points)
	local parts={}
	for i=1,#points do parts[i]=points[i].x..":"..points[i].z end
	return table.concat(parts,",")
end
local function reversed_signature(points)
	local parts={}
	for i=#points,1,-1 do parts[#parts+1]=points[i].x..":"..points[i].z end
	return table.concat(parts,",")
end
local forward_half=raster_canonical_points(0,0,4,2)
local reverse_half=raster_canonical_points(4,2,0,0)
assert(raster_signature(forward_half)=="0:0,1:1,2:1,3:2,4:2" and
	raster_signature(reverse_half)==reversed_signature(forward_half),
	"canonical half-cell route raster reversal drift")
for _,fixture in ipairs({{0,0,-4,2},{-2,-3,3,-1},{0,4,0,-4},
		{5,-1,-2,-6}}) do
	local a=raster_canonical_points(fixture[1],fixture[2],fixture[3],fixture[4])
	local b=raster_canonical_points(fixture[3],fixture[4],fixture[1],fixture[2])
	assert(raster_signature(b)==reversed_signature(a),
		"route raster octant reversal drift")
end
local joined={}
for _,segment in ipairs({{{0,0},{4,2}},{{4,2},{6,-2}}}) do
	local points=raster_canonical_points(segment[1][1],segment[1][2],
		segment[2][1],segment[2][2])
	for i=1,#points do
		if #joined==0 or joined[#joined].x~=points[i].x or
				joined[#joined].z~=points[i].z then joined[#joined+1]=points[i] end
	end
end
local joint_count=0
for i=1,#joined do if joined[i].x==4 and joined[i].z==2 then
	joint_count=joint_count+1 end end
assert(joint_count==1 and joined[1].x==0 and joined[#joined].x==6,
	"route joint suppression/station retention drift")

local Q=65536

-- The junction tuple is part of authored full-seed geometry. Seed zero must
-- select 38 from the first junction's inclusive 24..56 intersection.
if arg._wp40_phase.enabled("relief_junction_hash") then
	local junction=source.relief_junctions[1]
	local hash=deterministic.new_hash(canonical,raw_sha256,
		"grug_wp40_geometry_source_v1","0")
	local selected=junction.gate_min_above_water+hash.range(
		junction.hash_domain,junction.hash_feature_id,
		{junction.position.x,junction.position.z},junction.hash_candidate_index,
		junction.hash_lane,junction.gate_max_above_water-
			junction.gate_min_above_water+1)
	assert(junction.id=="relief_junction:-1050:-2250" and selected==38,
		"relief junction seed-zero hash tuple KAT drift")
end

-- R13 has four coordinate-free departure declarations.  The executable
-- station is derived from the untouched authored edge control and enters the
-- copied effective boundary control before the one displacement pipeline.
if arg._wp40_phase.enabled("junction_departure_projection") then
	local expected={
		{"land_035","relief_junction:-1400:-1100",-1399,-1099},
		{"land_036","relief_junction:400:-1100",401,-1099},
		{"land_041","relief_junction:-1400:1100",-1399,1099},
		{"land_042","relief_junction:400:1100",401,1099},
	}
	for i=1,#expected do local row=source.junction_departures[i]
		local edge=source.land_edges[tonumber(row.edge_id:sub(6))]
		local junction=edge.control[1]
		local adjacent=edge.control[2]
		local derived_x=junction.x+(adjacent.x<junction.x and -1 or 1)
		local derived_z=junction.z+(adjacent.z<junction.z and -1 or 1)
		assert(row.edge_id==expected[i][1] and row.junction_id==expected[i][2] and
			row.edge_endpoint=="from" and derived_x==expected[i][3] and
			derived_z==expected[i][4] and row.position==nil and row.control==nil and
			row.route_id==nil,
			"junction departure coordinate-free derivation KAT drift")
	end
end

-- Independent R13 lattice oracle.  It uses this harness's raster rather than
-- the production validator, proves the old four conflicts, then proves the
-- effective copied controls remove every conflict across all 102 pairs.
if arg._wp40_phase.enabled("junction_lattice_oracle") then
	local departure_by_edge={}
	for i=1,#source.junction_departures do
		departure_by_edge[source.junction_departures[i].edge_id]=
			source.junction_departures[i]
	end
	local function raster_controls(edge,use_departures)
		local controls={}
		for i=1,#edge.control do controls[i]=edge.control[i] end
		if use_departures and departure_by_edge[edge.id] then
			local endpoint,adjacent=controls[1],controls[2]
			local derived={
				x=endpoint.x+(adjacent.x<endpoint.x and -1 or 1),
				z=endpoint.z+(adjacent.z<endpoint.z and -1 or 1),
			}
			table.insert(controls,2,derived)
		end
		local result={}
		for control_index=1,#controls-1 do
			local part=raster_canonical_points(controls[control_index].x,
				controls[control_index].z,controls[control_index+1].x,
				controls[control_index+1].z)
			for station_index=1,#part do local point=part[station_index]
				if #result==0 or result[#result].x~=point.x or
						result[#result].z~=point.z then
					result[#result+1]={x=point.x,z=point.z}
				end
			end
		end
		return result
	end
	local function reverse_copy(points)
		local result={}
		for i=#points,1,-1 do result[#result+1]=points[i] end
		return result
	end
	local function pair_audit(use_departures)
		local rasters={}
		for i=1,#source.land_edges do
			rasters[source.land_edges[i].id]=
				raster_controls(source.land_edges[i],use_departures)
		end
		local pair_count,conflicts=0,{}
		for junction_index=1,#source.relief_junctions do
			local junction=source.relief_junctions[junction_index]
			local oriented={}
			for incidence_index=1,#junction.incident_edge_ids do
				local raster=rasters[junction.incident_edge_ids[incidence_index]]
				if raster[1].x==junction.position.x and
						raster[1].z==junction.position.z then
					oriented[incidence_index]=raster
				else
					assert(raster[#raster].x==junction.position.x and
						raster[#raster].z==junction.position.z)
					oriented[incidence_index]=reverse_copy(raster)
				end
			end
			for first_index=1,#oriented-1 do
				for second_index=first_index+1,#oriented do
					pair_count=pair_count+1
					local pair=junction.incident_edge_ids[first_index].."/"..
						junction.incident_edge_ids[second_index]
					local seen={}
					for i=2,#oriented[first_index] do local point=oriented[first_index][i]
						seen[point.x..":"..point.z]=true
					end
					for i=2,#oriented[second_index] do local point=oriented[second_index][i]
						local key=point.x..":"..point.z
						if seen[key] then conflicts[#conflicts+1]=pair.."@"..key end
					end
					local diagonals={}
					for i=1,#oriented[first_index]-1 do
						local a,b=oriented[first_index][i],oriented[first_index][i+1]
						local dx,dz=b.x-a.x,b.z-a.z
						if math.abs(dx)==1 and math.abs(dz)==1 then
							diagonals[math.min(a.x,b.x)..":"..math.min(a.z,b.z)]=
								dx==dz and 1 or -1
						end
					end
					for i=1,#oriented[second_index]-1 do
						local a,b=oriented[second_index][i],oriented[second_index][i+1]
						local dx,dz=b.x-a.x,b.z-a.z
						if math.abs(dx)==1 and math.abs(dz)==1 then
							local key=math.min(a.x,b.x)..":"..math.min(a.z,b.z)
							local slope=dx==dz and 1 or -1
							if diagonals[key] and diagonals[key]~=slope then
								conflicts[#conflicts+1]=pair.."@X:"..key
							end
						end
					end
				end
			end
		end
		table.sort(conflicts)
		return pair_count,conflicts
	end
	local old_count,old_conflicts=pair_audit(false)
	local effective_count,effective_conflicts=pair_audit(true)
	assert(old_count==102 and effective_count==102 and
		table.concat(old_conflicts,";")==
			"land_032/land_035@-1399:-1100;"..
			"land_033/land_036@401:-1100;"..
			"land_038/land_041@-1399:1100;"..
			"land_039/land_042@401:1100" and
		#effective_conflicts==0,
		"independent R13 38-junction/102-pair raster oracle drift")
end

assert(source.bay_mouth_apertures[1].station_order==
		"canonical_deduplicated_final_perimeter_integer_raster_order" and
	source.geometry_policies.world_partition.bay_bank_aperture_terminal_order==
		"deduplicated_final_authored_declared_perimeter_integer_raster_order_separate_from_the_canonical_mouth_aperture_membership_indices_payload_and_attachment_tie",
	"R12 canonical aperture payload / authored Bank terminal split drift")

-- Reality-correction KATs: raw relief uses the numeric inclusive span
-- (max-min), not the number of representable integer results.
local function raw_relief_offset(profile,noise_q)
	noise_q=math.max(-Q,math.min(Q,noise_q))
	local delta=profile.max_above_water-profile.min_above_water
	return profile.min_above_water+
		math.floor((noise_q+Q)*delta/(2*Q))
end
for i=1,#source.relief_profiles do local profile=source.relief_profiles[i]
	local delta=profile.max_above_water-profile.min_above_water
	assert(raw_relief_offset(profile,-Q)==profile.min_above_water and
		raw_relief_offset(profile,-Q-1)==profile.min_above_water and
		raw_relief_offset(profile,-2*Q)==profile.min_above_water and
		raw_relief_offset(profile,-1000000000)==profile.min_above_water and
		raw_relief_offset(profile,0)==profile.min_above_water+math.floor(delta/2) and
		raw_relief_offset(profile,Q)==profile.max_above_water and
		raw_relief_offset(profile,Q+1)==profile.max_above_water and
		raw_relief_offset(profile,2*Q)==profile.max_above_water and
		raw_relief_offset(profile,1000000000)==profile.max_above_water,
		"raw relief inclusive-span KAT drift: "..profile.id)
end
assert(40+math.floor((Q)*(40-40)/(2*Q))==40,
	"raw relief singleton KAT drift")

local function junction_weight(distance)
	return Q-deterministic.smootherstep(
		deterministic.qfrom_ratio(distance,96))
end
assert(junction_weight(94)>0 and junction_weight(95)==0 and
	junction_weight(96)==0 and junction_weight(97)==0 and
	Q-deterministic.smootherstep(Q-1)==0,
	"junction quantized support boundary KAT drift")
local function aggregate_junction(post_landmark_h,candidates)
	local weighted_sum,denominator,strength=0,0,0
	for i=1,#candidates do local candidate=candidates[i]
		local weight=junction_weight(candidate.distance)
		if weight>0 then
			weighted_sum=weighted_sum+
				deterministic.qmul(candidate.height_q,weight)
			denominator=denominator+weight
			strength=math.max(strength,weight)
		end
	end
	if denominator==0 then return post_landmark_h,0,0 end
	return deterministic.qdiv(weighted_sum,denominator),strength,denominator
end
local unchanged,strength,denominator=aggregate_junction(77*Q,
	{{distance=96,height_q=200*Q}})
assert(unchanged==77*Q and strength==0 and denominator==0,
	"junction zero-weight fallback divided or changed post-landmark H")
local averaged=aggregate_junction(1*Q,{{distance=0,height_q=20*Q},
	{distance=0,height_q=40*Q}})
assert(averaged==30*Q,"junction ordered Q16 weighted average KAT drift")

-- One ordinary edge projection can select at most one locally supported
-- endpoint. Stage 1 freezes only the raw-control baseline; Stage 2 must reject
-- each final raster below 192 steps before the two strict supports are used.
local minimum_raw_endpoint_chebyshev=9007199254740991
for i=1,#source.land_edges do local edge=source.land_edges[i]
	local first,last=edge.control[1],edge.control[#edge.control]
	minimum_raw_endpoint_chebyshev=math.min(minimum_raw_endpoint_chebyshev,
		math.max(math.abs(last.x-first.x),math.abs(last.z-first.z)))
end
assert(minimum_raw_endpoint_chebyshev==400,
	"junction raw-control endpoint-separation baseline drift")
local function supported_endpoint(station,last_station)
	if last_station<192 then return false,"short_final_edge" end
	local start_distance=station
	local end_distance=last_station-station
	assert(not (start_distance<96 and end_distance<96),
		"junction endpoint supports overlap")
	if start_distance<96 then return "start",start_distance end
	if end_distance<96 then return "end",end_distance end
	return false,false
end
local final_stage2_minimum=192
local side,distance=supported_endpoint(95,final_stage2_minimum)
assert(side=="start" and distance==95)
side,distance=supported_endpoint(96,final_stage2_minimum)
assert(side==false and distance==false)
side,distance=supported_endpoint(final_stage2_minimum-95,
	final_stage2_minimum)
assert(side=="end" and distance==95)
side,distance=supported_endpoint(final_stage2_minimum-96,
	final_stage2_minimum)
assert(side==false and distance==false)
side,distance=supported_endpoint(95,191)
assert(side==false and distance=="short_final_edge",
	"junction short final edge was not rejected before endpoint support")
local function nearest_projection_station(points,numerator_x,numerator_z,denominator)
	local best_index,best_distance
	for i=1,#points do
		local dx=points[i].x*denominator-numerator_x
		local dz=points[i].z*denominator-numerator_z
		local squared=dx*dx+dz*dz
		if not best_distance or squared<best_distance then
			best_index,best_distance=i,squared
		end
	end
	return best_index
end
assert(nearest_projection_station({{x=0,z=0},{x=1,z=0}},1,0,2)==1,
	"junction projection-station lower-index tie drift")

local function control_taper(station,total)
	return deterministic.smootherstep(deterministic.qfrom_ratio(
		math.min(station,total-station),96))
end
local function no_jitter_damping(distance)
	if distance<=96 then return 0 end
	if distance>=192 then return Q end
	return deterministic.smootherstep(
		deterministic.qfrom_ratio(distance-96,96))
end
assert(control_taper(0,240)==0 and control_taper(96,240)==Q and
	control_taper(37,240)==control_taper(203,240) and
	no_jitter_damping(95)==0 and no_jitter_damping(96)==0 and
	no_jitter_damping(144)==32768 and no_jitter_damping(192)==Q and
	math.min(no_jitter_damping(120),no_jitter_damping(180))==
		no_jitter_damping(120) and
	deterministic.qmul(control_taper(37,240),
		math.min(no_jitter_damping(120),no_jitter_damping(180)))==
		deterministic.qmul(control_taper(203,240),no_jitter_damping(120)),
	"boundary damping metric/reversal/overlap KAT drift")

-- R7 independent displacement oracle. It deliberately consumes only T1
-- arithmetic and the public raster KAT above; no compiler implementation is
-- available to hide a second normal, clip, component, or reraster path.
local function displacement_step_normal(dx,dz)
	assert(math.abs(dx)<=1 and math.abs(dz)<=1 and (dx~=0 or dz~=0))
	local length_q=deterministic.isqrt((dx*dx+dz*dz)*Q*Q)
	return deterministic.qdiv(-dz*Q,length_q),
		deterministic.qdiv(dx*Q,length_q)
end
local function displacement_joint_normal(in_dx,in_dz,out_dx,out_dz)
	local in_x,in_z=displacement_step_normal(in_dx,in_dz)
	local out_x,out_z=displacement_step_normal(out_dx,out_dz)
	local sum_x,sum_z=in_x+out_x,in_z+out_z
	assert(sum_x~=0 or sum_z~=0,"opposite displacement joint accepted")
	local length_q=deterministic.isqrt(sum_x*sum_x+sum_z*sum_z)
	return deterministic.qdiv(sum_x,length_q),deterministic.qdiv(sum_z,length_q)
end
local function displacement_components(normal_x_q,normal_z_q,scalar_q)
	return deterministic.qround(deterministic.qmul(normal_x_q,scalar_q)),
		deterministic.qround(deterministic.qmul(normal_z_q,scalar_q))
end
local function displacement_clip(base,normal_x_q,normal_z_q,desired_q,
		maximum,predicate)
	local function accepted(scalar_q)
		local dx,dz=displacement_components(normal_x_q,normal_z_q,scalar_q)
		return predicate(base.x+dx,base.z+dz),dx,dz
	end
	if desired_q==0 then
		local ok=accepted(0) assert(ok,"zero displacement outside local envelope")
		return 0
	end
	local ok=accepted(desired_q)
	if ok then return desired_q end
	local sign=desired_q<0 and -1 or 1
	local magnitude=math.min(maximum,math.floor(math.abs(desired_q)/Q))
	for nodes=magnitude,0,-1 do
		local candidate=sign*nodes*Q
		if accepted(candidate) then return candidate end
	end
	error("no displacement magnitude inside local envelope")
end
local horizontal_x,horizontal_z=displacement_step_normal(1,0)
local vertical_x,vertical_z=displacement_step_normal(0,1)
local diagonal_x,diagonal_z=displacement_step_normal(1,1)
local negative_horizontal_x,negative_horizontal_z=displacement_step_normal(-1,0)
local negative_vertical_x,negative_vertical_z=displacement_step_normal(0,-1)
assert(horizontal_x==0 and horizontal_z==Q and vertical_x==-Q and
	vertical_z==0 and diagonal_x==-46341 and diagonal_z==46341 and
	negative_horizontal_x==0 and negative_horizontal_z==-Q and
	negative_vertical_x==Q and negative_vertical_z==0,
	"boundary exact step-normal KAT drift")
local corner_x,corner_z=displacement_joint_normal(1,0,0,1)
assert(corner_x==-46341 and corner_z==46341,
	"boundary exact corner-normal KAT drift")
local dx,dz=displacement_components(Q,0,Q/2)
local negative_dx,negative_dz=displacement_components(Q,0,-Q/2)
assert(dx==1 and dz==0 and negative_dx==-1 and negative_dz==0,
	"boundary signed half-tie component rounding drift")
if arg._wp40_phase.enabled("displacement_clip_kats") then
	local base={x=2599,z=-2200}
	local frame=function(x,z) return x>=-2600 and x<=2600 and
		z>=-3000 and z<=3000 end
	local clipped=displacement_clip(base,Q,0,5*Q+Q/2,96,frame)
	assert(clipped==Q,"boundary exact-desired then descending clip drift")
	local accepted=displacement_clip({x=0,z=0},Q,0,5*Q+Q/4,64,
		function(x) return x<=6 end)
	assert(accepted==5*Q+Q/4,
		"boundary valid fractional displacement was unnecessarily clipped")
	local island=function(x,z)
		return math.abs(x+3150)<=300 and math.abs(z)<=350
	end
	assert(island(-2850,350) and not island(-2849,350) and
		not island(-2850,351),
		"boundary closed island authoring-rectangle equality drift")
	for island_index=1,#source.islands do local record=source.islands[island_index]
		for point_index=1,#record.polygon do local point=record.polygon[point_index]
			assert(math.abs(point.x-record.center.x)<=record.envelope.radius_x and
				math.abs(point.z-record.center.z)<=record.envelope.radius_z,
				"authored island control outside binding rectangle")
		end
	end
	local land=function(x,z) return math.abs(x)<=64 and math.abs(z)<=64 end
	assert(displacement_clip({x=0,z=0},diagonal_x,diagonal_z,64*Q,64,land)==64*Q)
	local fixed=function(x,z) return x==12 and z==-7 end
	assert(displacement_clip({x=12,z=-7},Q,0,8*Q,8,fixed)==0,
		"boundary fixed envelope failed to clip to exact base station")
end
local function raster_displaced_controls(controls,closed)
	local result={}
	local limit=closed and #controls or #controls-1
	for control_index=1,limit do
		local next_index=control_index+1
		if next_index>#controls then next_index=1 end
		local segment=raster_canonical_points(controls[control_index].x,
			controls[control_index].z,controls[next_index].x,controls[next_index].z)
		for station_index=1,#segment do local point=segment[station_index]
			if #result==0 or result[#result].x~=point.x or
					result[#result].z~=point.z then result[#result+1]=point end
		end
	end
	if closed and #result>1 and result[1].x==result[#result].x and
			result[1].z==result[#result].z then table.remove(result) end
	return result
end
local rerastered=raster_displaced_controls({{x=0,z=0},{x=3,z=2},{x=5,z=0}},false)
assert(rerastered[1].x==0 and rerastered[#rerastered].x==5 and
	raster_signature(rerastered)=="0:0,1:1,2:1,3:2,4:1,5:0",
	"boundary shifted-control sole reraster/join drift")
local closed_reraster=raster_displaced_controls(
	{{x=0,z=0},{x=2,z=0},{x=2,z=2},{x=0,z=2}},true)
local closed_seen={}
for i=1,#closed_reraster do
	local key=closed_reraster[i].x..":"..closed_reraster[i].z
	assert(not closed_seen[key] or key~="0:0","boundary closed seam duplicated")
	closed_seen[key]=true
end
assert(closed_reraster[1].x==0 and closed_reraster[1].z==0 and
	closed_reraster[#closed_reraster].x==0 and closed_reraster[#closed_reraster].z==1,
	"boundary closed seam reraster drift")
local function topology_ceiling(local_scalars,maximum,valid)
	local probes={}
	for ceiling=maximum,0,-1 do
		local candidate={}
		for index=1,#local_scalars do
			candidate[index]=math.max(-ceiling*Q,
				math.min(ceiling*Q,local_scalars[index]))
		end
		probes[#probes+1]=ceiling
		if valid(candidate,ceiling) then return ceiling,candidate,probes end
	end
	error("zero topology ceiling rejected")
end
if arg._wp40_phase.enabled("topology_ceiling_kats") then
	local ceiling,scalars,probes=topology_ceiling(
		{39*Q,40*Q,42*Q,40*Q,39*Q},48,
		function(_,candidate) return candidate==41 end)
	assert(ceiling==41 and table.concat(probes,",")=="48,47,46,45,44,43,42,41" and
		scalars[1]==39*Q and scalars[2]==40*Q and scalars[3]==41*Q and
		scalars[4]==40*Q and scalars[5]==39*Q,
		"R10 local synthetic V-peak ceiling fixture drift")
	local unchanged,unchanged_scalars=topology_ceiling(
		{12*Q,-9*Q,Q/2},48,function() return true end)
	assert(unchanged==48 and unchanged_scalars[1]==12*Q and
		unchanged_scalars[2]==-9*Q and unchanged_scalars[3]==Q/2,
		"R10 clean record was not bit-identical")
	local nonmonotone=topology_ceiling({48*Q},48,
		function(_,candidate) return candidate==46 or candidate==44 end)
	assert(nonmonotone==46,"R10 descending ceiling scan assumed monotonicity")
	local zero,_,zero_probes=topology_ceiling({48*Q},48,
		function(_,candidate) return candidate==0 end)
	assert(zero==0 and #zero_probes==49,
		"R10 finite C=0 termination drift")
end
if arg._wp40_phase.enabled("displacement_reversal_kats") then
	local function sequence_less(a,b)
		for i=1,#a do
			if a[i].x~=b[i].x then return a[i].x<b[i].x end
			if a[i].z~=b[i].z then return a[i].z<b[i].z end
		end
		return false
	end
	local function reversed_copy(points)
		local result={}
		for i=#points,1,-1 do result[#result+1]={x=points[i].x,z=points[i].z} end
		return result
	end
	local function canonical_open(points)
		local reversed=reversed_copy(points)
		return sequence_less(reversed,points) and reversed or points
	end
	local function canonical_closed(points)
		local count=#points
		if count>1 and points[1].x==points[count].x and points[1].z==points[count].z then
			count=count-1
		end
		local base={}
		for i=1,count do base[i]={x=points[i].x,z=points[i].z} end
		local best
		for direction=-1,1,2 do
			for start=1,count do
				local candidate={}
				for offset=0,count-1 do
					local index=(start-1+direction*offset)%count+1
					candidate[#candidate+1]={x=base[index].x,z=base[index].z}
				end
				if not best or sequence_less(candidate,best) then best=candidate end
			end
		end
		return best
	end
	local function displace_canonical_open(input,scalar_q)
		local points=canonical_open(input)
		local result={}
		for i=1,#points do
		local nx,nz
		if i==1 then nx,nz=displacement_step_normal(
			points[2].x-points[1].x,points[2].z-points[1].z)
		elseif i==#points then nx,nz=displacement_step_normal(
			points[i].x-points[i-1].x,points[i].z-points[i-1].z)
		else nx,nz=displacement_joint_normal(
			points[i].x-points[i-1].x,points[i].z-points[i-1].z,
			points[i+1].x-points[i].x,points[i+1].z-points[i].z) end
		local sx,sz=displacement_components(nx,nz,scalar_q)
		result[i]={x=points[i].x+sx,z=points[i].z+sz}
		end
		return result
	end
	local function displace_canonical_closed(input,scalar_q)
		local points=canonical_closed(input)
		local result={}
		for i=1,#points do
			local previous=i==1 and #points or i-1
			local following=i==#points and 1 or i+1
			local nx,nz=displacement_joint_normal(
				points[i].x-points[previous].x,points[i].z-points[previous].z,
				points[following].x-points[i].x,points[following].z-points[i].z)
			local sx,sz=displacement_components(nx,nz,scalar_q)
			result[i]={x=points[i].x+sx,z=points[i].z+sz}
		end
		return result
	end
	local authored_forward=raster_canonical_points(-2,-1,3,1)
	local authored_reverse=reversed_copy(authored_forward)
	local displaced_forward=displace_canonical_open(authored_forward,3*Q)
	local displaced_from_reverse=displace_canonical_open(authored_reverse,3*Q)
	assert(raster_signature(displaced_from_reverse)==raster_signature(displaced_forward),
		"boundary canonical normal/scalar reversal identity drift")
	local cycle={{x=2,z=0},{x=2,z=2},{x=0,z=2},{x=0,z=0},{x=2,z=0}}
	local rotated={{x=0,z=2},{x=0,z=0},{x=2,z=0},{x=2,z=2},{x=0,z=2}}
	local reversed_cycle=reversed_copy(cycle)
	assert(raster_signature(canonical_closed(cycle))==
		raster_signature(canonical_closed(rotated)) and
		raster_signature(canonical_closed(cycle))==
		raster_signature(canonical_closed(reversed_cycle)),
		"boundary closed-cycle rotation/reversal canonicalization drift")
	local base_cycle=raster_displaced_controls(
		{{x=0,z=0},{x=5,z=1},{x=3,z=6},{x=-2,z=4}},true)
	local base_rotated={}
	for offset=0,#base_cycle-1 do
		local index=(3+offset-1)%#base_cycle+1
		base_rotated[#base_rotated+1]=base_cycle[index]
	end
	local base_reversed=reversed_copy(base_cycle)
	local displaced_cycle=displace_canonical_closed(base_cycle,2*Q)
	local displaced_rotated=displace_canonical_closed(base_rotated,2*Q)
	local displaced_reversed=displace_canonical_closed(base_reversed,2*Q)
	local final_cycle=raster_displaced_controls(displaced_cycle,true)
	local final_rotated=raster_displaced_controls(displaced_rotated,true)
	local final_reversed=raster_displaced_controls(displaced_reversed,true)
	assert(raster_signature(final_cycle)==raster_signature(final_rotated) and
		raster_signature(final_cycle)==raster_signature(final_reversed),
		"boundary closed-cycle full displacement/reraster identity drift")
	local zero_ok=pcall(displacement_step_normal,0,0)
	local opposite_ok=pcall(displacement_joint_normal,1,0,-1,0)
	assert(not zero_ok and not opposite_ok,
		"boundary degenerate step or opposite joint was accepted")
end

if arg._wp40_phase.enabled("fixed_closure_oracle") then
	-- H55 independently resolves each fixed mainland closure from its six
	-- directed, max-zero Holy-contact edges.  No source-segment index is an
	-- input: equivalent closed rotations/reversals must rediscover the one full
	-- matching segment and carry that segment tag into canonical calculation.
	local edge_by_id={}
	for index=1,#source.land_edges do edge_by_id[source.land_edges[index].id]=
		source.land_edges[index] end
	local function reverse_path(points)
		local result={}
		for index=#points,1,-1 do
			result[#result+1]={x=points[index].x,z=points[index].z}
		end
		return result
	end
	local function same_path(a,b)
		if #a~=#b then return false end
		for index=1,#a do
			if a[index].x~=b[index].x or a[index].z~=b[index].z then return false end
		end
		return true
	end
	local function canonical_rows(points)
		local minimum=1
		for index=2,#points do
			if points[index].x<points[minimum].x or
					points[index].x==points[minimum].x and
					points[index].z<points[minimum].z then minimum=index end
		end
		local forward,backward={},{}
		for offset=0,#points-1 do
			forward[offset+1]=points[(minimum-1+offset)%#points+1]
			backward[offset+1]=points[(minimum-1-offset)%#points+1]
		end
		local function less(a,b)
			for index=1,#a do
				if a[index].x~=b[index].x then return a[index].x<b[index].x end
				if a[index].z~=b[index].z then return a[index].z<b[index].z end
			end
			return false
		end
		return less(backward,forward) and backward or forward
	end
	local function fixed_union(perimeter,edges)
		local union,seen={},{ }
		local closure=assert(perimeter.r7_fixed_closure)
		assert(closure.kind=="fixed_holy_land_edge_union" and #closure.edge_refs==6)
		for ref_index=1,#closure.edge_refs do local ref=closure.edge_refs[ref_index]
			local edge=assert(edges[ref.edge_id])
			assert(edge.max_displacement==0 and ref.direction=="reverse")
			local part=raster_displaced_controls(edge.control,false)
			part=reverse_path(part)
			if #union>0 then assert(union[#union].x==part[1].x and
				union[#union].z==part[1].z,"H55 fixed union join drift") end
			for point_index=1,#part do local point=part[point_index]
				if #union==0 or union[#union].x~=point.x or union[#union].z~=point.z then
					local key=point.x..":"..point.z
					assert(not seen[key],"H55 fixed union repeated station")
					seen[key]=true
					union[#union+1]={x=point.x,z=point.z}
				end
			end
		end
		return union
	end
	local function resolve(perimeter,controls,edges)
		local union=fixed_union(perimeter,edges or edge_by_id)
		local count=#controls
		if count>1 and controls[1].x==controls[count].x and
				controls[1].z==controls[count].z then count=count-1 end
		local parts,matches={},{}
		local reversed_union=reverse_path(union)
		for segment_index=1,count do
			local following=segment_index==count and 1 or segment_index+1
			local a,b=controls[segment_index],controls[following]
			local part=raster_canonical_points(a.x,a.z,b.x,b.z)
			parts[segment_index]=part
			if same_path(part,union) or same_path(part,reversed_union) then
				matches[#matches+1]=segment_index
			end
		end
		assert(#matches==1 and count==27,
			"H55 closure did not resolve to one full segment plus 26 ordinary segments")
		local matched=matches[1]
		local ring={}
		for segment_index=1,count do local part=parts[segment_index]
			for point_index=1,#part do local point=part[point_index]
				if #ring==0 or ring[#ring].x~=point.x or ring[#ring].z~=point.z then
					ring[#ring+1]={x=point.x,z=point.z,
						closure=segment_index==matched}
				elseif segment_index==matched then ring[#ring].closure=true end
			end
		end
		if ring[1].x==ring[#ring].x and ring[1].z==ring[#ring].z then
			if ring[#ring].closure then ring[1].closure=true end
			table.remove(ring)
		end
		local canonical_ring=canonical_rows(ring)
		local scalar_parts,closure_count={},0
		for index=1,#canonical_ring do local point=canonical_ring[index]
			local scalar
			if point.closure then scalar,closure_count=0,closure_count+1
			else scalar=(math.abs(point.x*17+point.z*31)%95+1)*Q end
			scalar_parts[index]=point.x..":"..point.z..":"..scalar
		end
		return {union=union,match=matched,
			canonical_bytes=raster_signature(canonical_ring),
			scalar_bytes=table.concat(scalar_parts,","),closure_count=closure_count}
	end
	local function equivalent_controls(polygon,start,reverse)
		local count=#polygon-1
		local result={}
		for offset=0,count-1 do
			local signed=reverse and -offset or offset
			local index=(start-1+signed)%count+1
			result[#result+1]={x=polygon[index].x,z=polygon[index].z}
		end
		result[#result+1]={x=result[1].x,z=result[1].z}
		return result
	end
	for perimeter_index=1,2 do local perimeter=source.perimeters[perimeter_index]
		local ordinary=resolve(perimeter,perimeter.polygon)
		local rotated=resolve(perimeter,equivalent_controls(perimeter.polygon,7,false))
		local reversed=resolve(perimeter,equivalent_controls(perimeter.polygon,4,true))
		assert(#ordinary.union==5001 and ordinary.closure_count==5001 and
			ordinary.canonical_bytes==rotated.canonical_bytes and
			ordinary.canonical_bytes==reversed.canonical_bytes and
			ordinary.scalar_bytes==rotated.scalar_bytes and
			ordinary.scalar_bytes==reversed.scalar_bytes and
			(ordinary.match~=rotated.match or ordinary.match~=reversed.match),
			"H55 closure rotation/reversal remap or scalar-zero KAT drift")
	end
	local function clone_closure(perimeter)
		local copy={r7_fixed_closure={kind=perimeter.r7_fixed_closure.kind,edge_refs={}}}
		for index=1,#perimeter.r7_fixed_closure.edge_refs do local ref=
			perimeter.r7_fixed_closure.edge_refs[index]
			copy.r7_fixed_closure.edge_refs[index]={edge_id=ref.edge_id,direction=ref.direction}
		end
		return copy
	end
	local first=source.perimeters[1]
	local function rejects(mutator,controls,edges)
		local copy=clone_closure(first)
		mutator(copy)
		return not pcall(resolve,copy,controls or first.polygon,edges or edge_by_id)
	end
	assert(rejects(function(p) p.r7_fixed_closure.edge_refs[1],
		p.r7_fixed_closure.edge_refs[2]=p.r7_fixed_closure.edge_refs[2],
		p.r7_fixed_closure.edge_refs[1] end) and
		rejects(function(p) p.r7_fixed_closure.edge_refs[3].direction="forward" end) and
		rejects(function(p) table.remove(p.r7_fixed_closure.edge_refs,4) end) and
		rejects(function(p) p.r7_fixed_closure.edge_refs[3].edge_id="land_047" end) and
		rejects(function(p) p.r7_fixed_closure.edge_refs[2].edge_id="land_055" end),
		"H55 fixed closure ref reorder/reverse/delete/duplicate/wrong-edge mutation accepted")
	local moved_edges={}
	for id,edge in pairs(edge_by_id) do moved_edges[id]=edge end
	local moved={}
	for key,value in pairs(edge_by_id.land_046) do moved[key]=value end
	moved.max_displacement=1 moved_edges.land_046=moved
	assert(rejects(function() end,nil,moved_edges),
		"H55 nonfixed referenced closure edge mutation accepted")
	local split_controls={}
	for index=1,#first.polygon-1 do split_controls[#split_controls+1]=
		{x=first.polygon[index].x,z=first.polygon[index].z} end
	split_controls[#split_controls+1]={x=0,z=-250}
	split_controls[#split_controls+1]={x=split_controls[1].x,z=split_controls[1].z}
	assert(rejects(function() end,split_controls),
		"H55 split/no-full closure segment mutation accepted")
	local changed_edges={}
	for id,edge in pairs(edge_by_id) do changed_edges[id]=edge end
	local changed={}
	for key,value in pairs(edge_by_id.land_046) do changed[key]=value end
	changed.control={{x=0,z=-250},{x=750,z=-249}}
	changed_edges.land_046=changed
	assert(rejects(function() end,nil,changed_edges),
		"H55 changed fixed-union station mutation accepted")
	print("WP40 T2 H55 fixed-closure oracle passed: 2 x 6 refs, 5001 stations each")

	local function boundary_bytes(value)
		if value.kind=="perimeter_vertex" then
			return "v:"..value.perimeter_id..":"..value.index
		end
		return "a:"..value.attachment_id
	end
	local span_bytes={}
	for index=1,#source.perimeter_spans do local span=source.perimeter_spans[index]
		span_bytes[index]=table.concat({span.id,span.zone_id,span.perimeter_id,
			span.first_segment,span.last_segment,span.face_direction,
			boundary_bytes(span.start_boundary),boundary_bytes(span.end_boundary),
			span.geometry_authority,span.displacement_source_ref,span.tie_rule},"\31")
	end
	local coast_source_span_hash=canonical.hex(raw_sha256(table.concat(span_bytes,"\30")))
	assert(coast_source_span_hash==
		"bf7880fea20624378a8c177e513af637b61b8f169be6cf1e03a45a86fe538534",
		"H55 18 Coast source-span definitions changed: "..coast_source_span_hash)
end

-- R8 independently freezes land/planned-water precedence. A channel uses a
-- closed polygon only after mainland, island, and fixed Holy land authority.
local function closed_polygon_member(x,z,polygon)
	local winding=0
	for i=1,#polygon-1 do local a,b=polygon[i],polygon[i+1]
		local side=(b.x-a.x)*(z-a.z)-(b.z-a.z)*(x-a.x)
		if side==0 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
				z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then return true end
		if a.z<=z then if b.z>z and side>0 then winding=winding+1 end
		elseif b.z<=z and side<0 then winding=winding-1 end
	end
	return winding~=0
end
local function r8_base_bay_member(x,z,bay)
	for i=1,#bay.centreline-1 do local a,b=bay.centreline[i],bay.centreline[i+1]
		local vx,vz=b.x-a.x,b.z-a.z
		local px,pz=x-a.x,z-a.z
		local length=vx*vx+vz*vz
		local projection=px*vx+pz*vz
		if projection<=0 then
			if px*px+pz*pz<a.half_width*a.half_width then return true end
		elseif projection>=length then
			local ex,ez=x-b.x,z-b.z
			if ex*ex+ez*ez<b.half_width*b.half_width then return true end
		else
			local area=vx*pz-vz*px
			local width=a.half_width*(length-projection)+b.half_width*projection
			if area*area*length<width*width then return true end
		end
	end
	return false
end
local function r8_wing_member(x,z,wing)
	local vx,vz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
	local px,pz=x-wing.head.x,z-wing.head.z
	local length=vx*vx+vz*vz
	local projection=px*vx+pz*vz
	if projection<0 or projection>=length then return false end
	local area=vx*pz-vz*px
	local remaining=length-projection
	return area*area*length<wing.head_half_width*wing.head_half_width*
		remaining*remaining
end
local function r8_class(x,z)
	local bay_index_by_id={bay_elandor_west=1,bay_elandor_east=2,
		bay_kragmar_west=3,bay_kragmar_east=4}
	for perimeter_index=1,2 do
		if closed_polygon_member(x,z,source.perimeters[perimeter_index].polygon) then
			local continent=perimeter_index==1 and "elandor" or "kragmar"
			for i=1,#source.bays do local bay=source.bays[i]
				if bay.continent==continent and r8_base_bay_member(x,z,bay) then
					return "planned_water"
				end
			end
			for i=1,#source.bay_closure_wings do local wing=source.bay_closure_wings[i]
				local bay=source.bays[bay_index_by_id[wing.bay_id]]
				if bay and bay.continent==continent and r8_wing_member(x,z,wing) then
					return "planned_water"
				end
			end
			return "land"
		end
	end
	for i=1,#source.islands do
		if closed_polygon_member(x,z,source.islands[i].polygon) then return "land" end
	end
	local holy=source.constants.holy_grounds
	if x>=holy.min_x and x<=holy.max_x and z>=holy.min_z and z<=holy.max_z then
		return "land"
	end
	for i=1,#source.channels do
		if closed_polygon_member(x,z,source.channels[i].polygon) then
			return "immutable_dragon_channel"
		end
	end
	return "ordinary_exterior"
end
assert(r8_class(0,0)=="land" and r8_class(-2500,0)=="land" and
	r8_class(2500,0)=="land" and
	r8_class(source.islands[1].polygon[1].x,source.islands[1].polygon[1].z)=="land" and
	r8_class(-2850,0)=="immutable_dragon_channel" and
	r8_class(2860,0)=="immutable_dragon_channel" and
	r8_class(-980,-2940)=="planned_water" and
	r8_class(-900,-2600)=="planned_water" and
	r8_class(source.bay_closure_wings[1].left_probe.x,
		source.bay_closure_wings[1].left_probe.z)=="planned_water",
	"channel strict-exterior/equality precedence KAT drift")
for i=1,#source.channels do local channel=source.channels[i]
	assert(closed_polygon_member(channel.polygon[1].x,channel.polygon[1].z,
		channel.polygon),"channel own polygon boundary became open")
end

-- R16 independent Slot-19 Reality oracle. It reconstructs land_010's R7
-- lattice from Source + T1 arithmetic, derives the seed-dependent Bay mask,
-- resolves the coordinate-free transition row, and runs an independent
-- water-right Moore/DFS trace from the declared Kragmar-west negative Wing K.
-- It deliberately never loads or calls geometry/partition.lua or raster.lua.
local function run_r16_r17_source_oracle()
	local seed="18446744073709551615"
	local function point_key(point) return point.x..":"..point.z end
	local function point_less(a,b)
		return a.x<b.x or a.x==b.x and a.z<b.z
	end
	local function sequence_less(a,b)
		local count=math.min(#a,#b)
		for i=1,count do
			if point_less(a[i],b[i]) then return true end
			if point_less(b[i],a[i]) then return false end
		end
		return #a<#b
	end
	local function reverse_rows(values)
		local result={}
		for i=#values,1,-1 do result[#result+1]=values[i] end
		return result
	end
	local no_jitter,no_jitter_seen={},{}
	local function add_no_jitter(point)
		if type(point)=="table" and type(point.x)=="number" and
				type(point.z)=="number" then
			local key=point_key(point)
			if not no_jitter_seen[key] then
				no_jitter_seen[key]=true
				no_jitter[#no_jitter+1]={x=point.x,z=point.z}
			end
		end
	end
	local function add_polylines(collection,field)
		for i=1,#collection do local points=collection[i][field]
			if points then for j=1,#points do add_no_jitter(points[j]) end end
		end
	end
	add_polylines(source.land_edges,"control")
	add_polylines(source.perimeters,"polygon")
	add_polylines(source.bays,"centreline")
	add_polylines(source.islands,"polygon")
	add_polylines(source.channels,"polygon")
	add_polylines(source.routes,"centreline")
	add_polylines(source.island_routes,"centreline")
	add_polylines(source.hydrology,"centreline")
	add_polylines(source.housing_masks,"polygon")
	for i=1,#source.poi_spurs do
		for j=1,#source.poi_spurs[i].candidate_paths do
			for k=1,#source.poi_spurs[i].candidate_paths[j] do
				add_no_jitter(source.poi_spurs[i].candidate_paths[j][k])
			end
		end
	end
	for i=1,#source.face_arcs do
		for j=1,#source.face_arcs[i].authority_components do
			local component=source.face_arcs[i].authority_components[j]
			if component.kind=="literal_arc" then
				for k=1,#component.control do add_no_jitter(component.control[k]) end
			end
		end
	end
	for _,collection in ipairs({source.route_interfaces,
			source.island_route_interfaces}) do
		for i=1,#collection do add_no_jitter(collection[i].position) end
	end
	for i=1,#source.anchors do
		if source.anchors[i].placement_mode=="fixed" then
			add_no_jitter(source.anchors[i].position)
		end
	end
	local holy=source.constants.holy_grounds
	for _,x in ipairs({holy.min_x,holy.max_x}) do
		for _,z in ipairs({holy.min_z,holy.max_z}) do add_no_jitter({x=x,z=z}) end
	end
	for i=1,#source.constants.holy_junction_x do
		local x=source.constants.holy_junction_x[i]
		add_no_jitter({x=x,z=holy.min_z}) add_no_jitter({x=x,z=holy.max_z})
	end
	for i=1,#source.junction_departures do
		local row=source.junction_departures[i]
		local edge=source.land_edges[tonumber(row.edge_id:sub(6))]
		local from=row.edge_endpoint=="from"
		local endpoint=edge.control[from and 1 or #edge.control]
		local adjacent=edge.control[from and 2 or #edge.control-1]
		add_no_jitter({x=endpoint.x+(adjacent.x<endpoint.x and -1 or 1),
			z=endpoint.z+(adjacent.z<endpoint.z and -1 or 1)})
	end
	table.sort(no_jitter,point_less)

	local edge=source.land_edges[10]
	assert(edge.id=="land_010" and edge.max_displacement==64)
	local authored={}
	for segment_index=1,#edge.control-1 do
		local part=raster_canonical_points(edge.control[segment_index].x,
			edge.control[segment_index].z,edge.control[segment_index+1].x,
			edge.control[segment_index+1].z)
		for local_index=1,#part do local point=part[local_index]
			if #authored==0 or point_key(authored[#authored])~=point_key(point) then
				authored[#authored+1]={x=point.x,z=point.z,
					source_segment=segment_index-1,local_station=local_index-1,
					local_last=#part-1,authored_order=#authored+1}
			end
		end
	end
	local calculation=authored
	local reversed=reverse_rows(authored)
	if sequence_less(reversed,authored) then calculation=reversed end
	local boundary_noise={schema="grug_wp40_geometry_source_v1",seed=seed,
		domain=edge.noise_domain,feature="",octaves={
			{period=384,amplitude_numerator=2,amplitude_denominator=3},
			{period=768,amplitude_numerator=1,amplitude_denominator=3}}}
	local local_rows={}
	for i=1,#calculation do local point=calculation[i]
		local previous=i>1 and calculation[i-1] or nil
		local following=i<#calculation and calculation[i+1] or nil
		local nx,nz
		if previous and following then
			nx,nz=displacement_joint_normal(point.x-previous.x,point.z-previous.z,
				following.x-point.x,following.z-point.z)
		elseif following then
			nx,nz=displacement_step_normal(following.x-point.x,following.z-point.z)
		else
			nx,nz=displacement_step_normal(point.x-previous.x,point.z-previous.z)
		end
		local noise_q=deterministic.clamp(deterministic.value_noise_2d(
			canonical,raw_sha256,boundary_noise,point.x,point.z),-Q,Q)
		local taper_q=deterministic.smootherstep(deterministic.qfrom_ratio(
			math.min(math.min(point.local_station,
				point.local_last-point.local_station),96),96))
		local minimum_damping=Q
		for source_index=1,#no_jitter do
			local fixed=no_jitter[source_index]
			local distance=math.max(math.abs(point.x-fixed.x),math.abs(point.z-fixed.z))
			local damping=no_jitter_damping(distance)
			if damping<minimum_damping then minimum_damping=damping end
			if minimum_damping==0 then break end
		end
		local desired_q=deterministic.qmul(
			deterministic.qmul(noise_q,edge.max_displacement*Q),
			deterministic.qmul(taper_q,minimum_damping))
		local_rows[i]={x=point.x,z=point.z,authored_order=point.authored_order,
			scalar_q=desired_q,nx=nx,nz=nz}
	end
	local bucket_size=64
	local base_buckets={}
	for i=1,#authored do local point=authored[i]
		local bucket=deterministic.floor_div(point.x,bucket_size)..":"..
			deterministic.floor_div(point.z,bucket_size)
		base_buckets[bucket]=base_buckets[bucket] or {}
		base_buckets[bucket][#base_buckets[bucket]+1]=point
	end
	local function final_valid(points)
		local seen,diagonals={},{}
		for i=1,#points do local point=points[i]
			local key=point_key(point)
			if seen[key] then return false end
			seen[key]=true
			local bx,bz=deterministic.floor_div(point.x,bucket_size),
				deterministic.floor_div(point.z,bucket_size)
			local inside=false
			for ox=-1,1 do for oz=-1,1 do
				local bucket=base_buckets[(bx+ox)..":"..(bz+oz)] or {}
				for j=1,#bucket do
					if math.abs(point.x-bucket[j].x)<=edge.max_displacement and
							math.abs(point.z-bucket[j].z)<=edge.max_displacement then
						inside=true break
					end
				end
				if inside then break end
			end if inside then break end end
			if not inside then return false end
			if i>1 then
				local previous=points[i-1]
				local dx,dz=point.x-previous.x,point.z-previous.z
				if math.max(math.abs(dx),math.abs(dz))~=1 then return false end
				if math.abs(dx)==1 and math.abs(dz)==1 then
					local cell=math.min(point.x,previous.x)..":"..math.min(point.z,previous.z)
					local slope=dx==dz and 1 or -1
					if diagonals[cell] and diagonals[cell]~=slope then return false end
					diagonals[cell]=slope
				end
			end
		end
		return #points>=2
	end
	local provisional,selected_ceiling
	for ceiling=edge.max_displacement,0,-1 do
		local controls={}
		for i=1,#local_rows do local row=local_rows[i]
			local scalar=deterministic.clamp(row.scalar_q,-ceiling*Q,ceiling*Q)
			local sx,sz=displacement_components(row.nx,row.nz,scalar)
			controls[row.authored_order]={x=row.x+sx,z=row.z+sz}
		end
		local points=raster_displaced_controls(controls,false)
		if final_valid(points) then provisional,selected_ceiling=points,ceiling break end
	end
	assert(provisional and selected_ceiling==3,
		"R16 independent land_010 R7 ceiling drift: "..tostring(selected_ceiling))

	-- C2 independently binds the complete upstream selected-R7 station/scalar
	-- identity for Slot 30's land_007 before any final-dry interval selection.
	-- This is deliberately a second local oracle rather than a compiler digest.
	local function selected_land_edge_identity(edge_index,world_seed)
		local selected_edge=source.land_edges[edge_index]
		local selected_authored={}
		for segment_index=1,#selected_edge.control-1 do
			local part=raster_canonical_points(selected_edge.control[segment_index].x,
				selected_edge.control[segment_index].z,
				selected_edge.control[segment_index+1].x,
				selected_edge.control[segment_index+1].z)
			for local_index=1,#part do local point=part[local_index]
				if #selected_authored==0 or
						point_key(selected_authored[#selected_authored])~=point_key(point) then
					selected_authored[#selected_authored+1]={x=point.x,z=point.z,
						source_segment=segment_index-1,local_station=local_index-1,
						local_last=#part-1,authored_order=#selected_authored+1}
				end
			end
		end
		local selected_calculation=selected_authored
		local selected_reversed=reverse_rows(selected_authored)
		if sequence_less(selected_reversed,selected_authored) then
			selected_calculation=selected_reversed
		end
		local selected_noise={schema="grug_wp40_geometry_source_v1",seed=world_seed,
			domain=selected_edge.noise_domain,feature="",octaves={
				{period=384,amplitude_numerator=2,amplitude_denominator=3},
				{period=768,amplitude_numerator=1,amplitude_denominator=3}}}
		local selected_rows={}
		for i=1,#selected_calculation do local point=selected_calculation[i]
			local previous=i>1 and selected_calculation[i-1] or nil
			local following=i<#selected_calculation and selected_calculation[i+1] or nil
			local nx,nz
			if previous and following then
				nx,nz=displacement_joint_normal(point.x-previous.x,point.z-previous.z,
					following.x-point.x,following.z-point.z)
			elseif following then
				nx,nz=displacement_step_normal(following.x-point.x,following.z-point.z)
			else
				nx,nz=displacement_step_normal(point.x-previous.x,point.z-previous.z)
			end
			local noise_q=deterministic.clamp(deterministic.value_noise_2d(
				canonical,raw_sha256,selected_noise,point.x,point.z),-Q,Q)
			local taper_q=deterministic.smootherstep(deterministic.qfrom_ratio(
				math.min(math.min(point.local_station,
					point.local_last-point.local_station),96),96))
			local minimum_damping=Q
			for source_index=1,#no_jitter do local fixed=no_jitter[source_index]
				local distance=math.max(math.abs(point.x-fixed.x),
					math.abs(point.z-fixed.z))
				local damping=no_jitter_damping(distance)
				if damping<minimum_damping then minimum_damping=damping end
				if minimum_damping==0 then break end
			end
			selected_rows[i]={x=point.x,z=point.z,
				source_segment=point.source_segment,local_station=point.local_station,
				authored_order=point.authored_order,
				desired_q=deterministic.qmul(
					deterministic.qmul(noise_q,selected_edge.max_displacement*Q),
					deterministic.qmul(taper_q,minimum_damping)),nx=nx,nz=nz}
		end
		local selected_base_buckets={}
		for i=1,#selected_authored do local point=selected_authored[i]
			local bucket=deterministic.floor_div(point.x,64)..":"..
				deterministic.floor_div(point.z,64)
			selected_base_buckets[bucket]=selected_base_buckets[bucket] or {}
			selected_base_buckets[bucket][#selected_base_buckets[bucket]+1]=point
		end
		local function candidate_valid(points)
			local seen,diagonals={},{}
			for i=1,#points do local point=points[i]
				local key=point_key(point)
				if seen[key] then return false end
				seen[key]=true
				local bx=deterministic.floor_div(point.x,64)
				local bz=deterministic.floor_div(point.z,64)
				local inside=false
				for ox=-1,1 do for oz=-1,1 do
					local bucket=selected_base_buckets[(bx+ox)..":"..(bz+oz)] or {}
					for j=1,#bucket do
						if math.abs(point.x-bucket[j].x)<=selected_edge.max_displacement and
								math.abs(point.z-bucket[j].z)<=selected_edge.max_displacement then
							inside=true break
						end
					end
					if inside then break end
				end if inside then break end end
				if not inside then return false end
				if i>1 then
					local old=points[i-1]
					local sx,sz=point.x-old.x,point.z-old.z
					if math.max(math.abs(sx),math.abs(sz))~=1 then return false end
					if math.abs(sx)==1 and math.abs(sz)==1 then
						local cell=math.min(point.x,old.x)..":"..math.min(point.z,old.z)
						local slope=sx==sz and 1 or -1
						if diagonals[cell] and diagonals[cell]~=slope then return false end
						diagonals[cell]=slope
					end
				end
			end
			return #points>=2
		end
		for ceiling=selected_edge.max_displacement,0,-1 do
			local selected_controls,selected_scalars={},{}
			for i=1,#selected_rows do local row=selected_rows[i]
				local scalar=deterministic.clamp(row.desired_q,-ceiling*Q,ceiling*Q)
				local sx,sz=displacement_components(row.nx,row.nz,scalar)
				selected_controls[row.authored_order]={x=row.x+sx,z=row.z+sz}
				selected_scalars[row.authored_order]=scalar
			end
			local selected_points=raster_displaced_controls(selected_controls,false)
			if candidate_valid(selected_points) then
				local bytes={}
				for i=1,#selected_rows do local row=selected_rows[i]
					local station=selected_controls[row.authored_order]
					bytes[#bytes+1]=table.concat({row.x,row.z,row.source_segment,
						row.local_station,row.authored_order,row.desired_q,
						selected_scalars[row.authored_order],row.nx,row.nz,
						station.x,station.z},":")
				end
				return ceiling,#selected_rows,table.concat(bytes,";"),selected_points,
					selected_controls,selected_scalars,selected_rows
			end
		end
		error("C2 no selected R7 land-edge candidate")
	end
	local slot30_ceiling,slot30_count,slot30_identity=
		selected_land_edge_identity(7,"15219119262482319357")
	local slot30_identity_sha=canonical.hex(raw_sha256(slot30_identity))
	assert(slot30_ceiling==3 and slot30_count==1941 and
		slot30_identity_sha=="7145f381da0bcaca60b1fb473397a513fe4974fd48cee185ba71aac68bb50dff",
		"C2 Slot30 upstream R7 station/scalar identity drift: "..
			slot30_ceiling..":"..slot30_count..":"..slot30_identity_sha)

	-- Independently materialize both selected mainland R7 perimeters.  Candidate
	-- scope below therefore uses the final footprint and perimeter-equality
	-- rules rather than treating every dry coordinate as mainland.
	local land_edge_by_id={}
	for edge_index=1,#source.land_edges do
		land_edge_by_id[source.land_edges[edge_index].id]=source.land_edges[edge_index]
	end
	local function same_sequence(a,b)
		if #a~=#b then return false end
		for index=1,#a do
			if a[index].x~=b[index].x or a[index].z~=b[index].z then return false end
		end
		return true
	end
	local function fixed_closure_union(perimeter)
		local result={}
		for ref_index=1,#perimeter.r7_fixed_closure.edge_refs do
			local ref=perimeter.r7_fixed_closure.edge_refs[ref_index]
			local fixed_edge=assert(land_edge_by_id[ref.edge_id])
			assert(fixed_edge.max_displacement==0)
			local part=raster_displaced_controls(fixed_edge.control,false)
			if ref.direction=="reverse" then part=reverse_rows(part)
			elseif ref.direction~="forward" then error("R16 invalid fixed-closure direction") end
			if #result>0 then assert(point_key(result[#result])==point_key(part[1])) end
			for point_index=1,#part do
				if #result==0 or point_key(result[#result])~=point_key(part[point_index]) then
					result[#result+1]={x=part[point_index].x,z=part[point_index].z}
				end
			end
		end
		return result
	end
	local function authored_perimeter_rows(perimeter)
		local union=fixed_closure_union(perimeter)
		local union_reverse=reverse_rows(union)
		local matched
		for segment_index=1,#perimeter.polygon-1 do
			local a,b=perimeter.polygon[segment_index],perimeter.polygon[segment_index+1]
			local part=raster_canonical_points(a.x,a.z,b.x,b.z)
			if same_sequence(part,union) or same_sequence(part,union_reverse) then
				assert(not matched,"R16 fixed closure matched twice")
				matched=segment_index
			end
		end
		assert(matched,"R16 fixed closure did not match a full source segment")
		local rows={}
		for segment_index=1,#perimeter.polygon-1 do
			local a,b=perimeter.polygon[segment_index],perimeter.polygon[segment_index+1]
			local part=raster_canonical_points(a.x,a.z,b.x,b.z)
			for local_index=1,#part do local point=part[local_index]
				if #rows==0 or point_key(rows[#rows])~=point_key(point) then
					rows[#rows+1]={x=point.x,z=point.z,source_segment=segment_index-1,
						local_station=local_index-1,local_last=#part-1,
						fixed_closure=segment_index==matched}
				elseif segment_index==matched then rows[#rows].fixed_closure=true end
			end
		end
		if point_key(rows[1])==point_key(rows[#rows]) then
			if rows[#rows].fixed_closure then rows[1].fixed_closure=true end
			table.remove(rows)
		end
		for index=1,#rows do rows[index].authored_order=index end
		return rows
	end
	local function canonical_closed_rows(rows)
		local minimum=1
		for index=2,#rows do
			assert(point_key(rows[index])~=point_key(rows[minimum]) or
				index==minimum,"R16 closed perimeter repeated its minimum")
			if point_less(rows[index],rows[minimum]) then minimum=index end
		end
		local forward,backward={},{}
		for offset=0,#rows-1 do
			forward[offset+1]=rows[(minimum-1+offset)%#rows+1]
			backward[offset+1]=rows[(minimum-1-offset)%#rows+1]
		end
		return sequence_less(backward,forward) and backward or forward
	end
	local mainland_frame=source.constants.mainland_frame
	local function valid_closed_perimeter(perimeter,points)
		if #points<3 then return false end
		local seen,diagonals={},{}
		for index=1,#points do local point=points[index]
			local key=point_key(point)
			if seen[key] or point.x<mainland_frame.min_x or
					point.x>mainland_frame.max_x or
					point.z<mainland_frame.min_z or
					point.z>mainland_frame.max_z then return false end
			seen[key]=true
		end
		local area2=0
		for index=1,#points do
			local following=index==#points and 1 or index+1
			local a,b=points[index],points[following]
			local dx,dz=b.x-a.x,b.z-a.z
			if math.max(math.abs(dx),math.abs(dz))~=1 then return false end
			if math.abs(dx)==1 and math.abs(dz)==1 then
				local cell=math.min(a.x,b.x)..":"..math.min(a.z,b.z)
				local slope=dx==dz and 1 or -1
				if diagonals[cell] and diagonals[cell]~=slope then return false end
				diagonals[cell]=slope
			end
			area2=area2+a.x*b.z-b.x*a.z
		end
		if perimeter.orientation=="counterclockwise" then return area2>0 end
		if perimeter.orientation=="clockwise" then return area2<0 end
		return false
	end
	local function polygon_class(points,x,z)
		local winding=0
		for index=1,#points do
			local following=index==#points and 1 or index+1
			local a,b=points[index],points[following]
			local side=(b.x-a.x)*(z-a.z)-(b.z-a.z)*(x-a.x)
			if side==0 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
					z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then return 0 end
			if a.z<=z then
				if b.z>z and side>0 then winding=winding+1 end
			elseif b.z<=z and side<0 then winding=winding-1 end
		end
		return winding==0 and -1 or 1
	end
	local function build_polygon_classifier(points)
		local boundary,events_by_z={},{}
		for index=1,#points do
			local following=index==#points and 1 or index+1
			local a,b=points[index],points[following]
			boundary[point_key(a)]=true
			if b.z>a.z then
				events_by_z[a.z]=events_by_z[a.z] or {}
				events_by_z[a.z][#events_by_z[a.z]+1]={x=a.x,delta=1}
			elseif b.z<a.z then
				events_by_z[b.z]=events_by_z[b.z] or {}
				events_by_z[b.z][#events_by_z[b.z]+1]={x=b.x,delta=-1}
			end
		end
		return function(x,z)
			if boundary[x..":"..z] then return 0 end
			local winding=0
			for _,event in ipairs(events_by_z[z] or {}) do
				if x<event.x then winding=winding+event.delta end
			end
			return winding==0 and -1 or 1
		end
	end
	local wing_by_bay={}
	for i=1,#source.bay_closure_wings do local wing=source.bay_closure_wings[i]
		wing_by_bay[wing.bay_id]=wing_by_bay[wing.bay_id] or {}
		wing_by_bay[wing.bay_id][#wing_by_bay[wing.bay_id]+1]=wing
	end
	local MAX_SAFE_INTEGER=9007199254740991
	local function checked_integer_sum(value,delta)
		assert(value==math.floor(value) and delta==math.floor(delta) and
			value>=-MAX_SAFE_INTEGER and value<=MAX_SAFE_INTEGER and
			delta>=-MAX_SAFE_INTEGER and delta<=MAX_SAFE_INTEGER and
			(value>=0 and delta>=0 and value<=MAX_SAFE_INTEGER-delta or
			 value<=0 and delta<=0 and value>=-MAX_SAFE_INTEGER-delta or
			 value<0 and delta>0 or value>0 and delta<0 or value==0 or delta==0),
			"R17 unsafe integer sum")
		local result=value+delta
		assert(result>=-MAX_SAFE_INTEGER and result<=MAX_SAFE_INTEGER and
			result-delta==value)
		return result
	end
	local function build_raw_world(world_seed)
		local final_perimeter_by_id,perimeter_ceiling={},{}
		local perimeter_segment_points={}
		for perimeter_index=1,2 do local perimeter=source.perimeters[perimeter_index]
			local authored=authored_perimeter_rows(perimeter)
			local calculation=canonical_closed_rows(authored)
			local noise={schema="grug_wp40_geometry_source_v1",seed=world_seed,
				domain=perimeter.noise_domain,feature="",octaves={
					{period=512,amplitude_numerator=2,amplitude_denominator=3},
					{period=1024,amplitude_numerator=1,amplitude_denominator=3}}}
			local rows={}
			for index=1,#calculation do local point=calculation[index]
				local previous=calculation[index==1 and #calculation or index-1]
				local following=calculation[index==#calculation and 1 or index+1]
				local nx,nz=displacement_joint_normal(point.x-previous.x,
					point.z-previous.z,following.x-point.x,following.z-point.z)
				local noise_q=deterministic.clamp(deterministic.value_noise_2d(
					canonical,raw_sha256,noise,point.x,point.z),-Q,Q)
				local distance=math.min(point.local_station,
					point.local_last-point.local_station)
				local taper=deterministic.smootherstep(deterministic.qfrom_ratio(
					math.min(distance,96),96))
				local desired=deterministic.qmul(
					deterministic.qmul(noise_q,perimeter.max_displacement*Q),
					deterministic.qmul(taper,no_jitter_damping((function()
						local minimum=2147483647
						for source_index=1,#no_jitter do local fixed=no_jitter[source_index]
							minimum=math.min(minimum,math.max(math.abs(point.x-fixed.x),
								math.abs(point.z-fixed.z)))
						end
						return minimum
					end)())))
				local scalar=point.fixed_closure and 0 or displacement_clip(point,nx,nz,
					desired,perimeter.max_displacement,function(x,z)
						return x>=mainland_frame.min_x and x<=mainland_frame.max_x and
							z>=mainland_frame.min_z and z<=mainland_frame.max_z
					end)
				rows[index]={x=point.x,z=point.z,authored_order=point.authored_order,
					scalar_q=scalar,nx=nx,nz=nz}
			end
			for ceiling=perimeter.max_displacement,0,-1 do
				local controls={}
				for index=1,#rows do local row=rows[index]
					local scalar=deterministic.clamp(row.scalar_q,-ceiling*Q,ceiling*Q)
					local sx,sz=displacement_components(row.nx,row.nz,scalar)
					controls[row.authored_order]={x=row.x+sx,z=row.z+sz}
				end
				local points=raster_displaced_controls(controls,true)
				if valid_closed_perimeter(perimeter,points) then
					final_perimeter_by_id[perimeter.id]=points
					perimeter_ceiling[perimeter.id]=ceiling
					local order_by_key={}
					for authored_index=1,#authored do
						order_by_key[point_key(authored[authored_index])]=
							authored[authored_index].authored_order
					end
					local segments={}
					for segment_index=1,#perimeter.polygon-1 do
						local start_order=assert(order_by_key[point_key(
							perimeter.polygon[segment_index])])
						local finish_order=assert(order_by_key[point_key(
							perimeter.polygon[segment_index+1])])
						local segment_controls={}
						local order=start_order
						while true do
							segment_controls[#segment_controls+1]=controls[order]
							if order==finish_order then break end
							order=order==#controls and 1 or order+1
							assert(#segment_controls<=#controls,
								"R19 perimeter segment control walk exhausted")
						end
						segments[segment_index-1]=
							raster_displaced_controls(segment_controls,false)
					end
					perimeter_segment_points[perimeter.id]=segments
					break
				end
			end
			assert(final_perimeter_by_id[perimeter.id],"R17 final perimeter absent")
		end
		local footprint_classifier={}
		for id,points in pairs(final_perimeter_by_id) do
			footprint_classifier[id]=build_polygon_classifier(points)
			for probe_index=1,math.min(#points,16) do local point=points[probe_index]
				assert(footprint_classifier[id](point.x,point.z)==0 and
					polygon_class(points,point.x,point.z)==0)
			end
		end
		local bay_by_id={}
		for bay_index=1,#source.bays do local bay=source.bays[bay_index]
			local compiled={source=bay,segments={}}
			for segment_index=1,#bay.centreline-1 do
				local stations=raster_canonical_points(bay.centreline[segment_index].x,
					bay.centreline[segment_index].z,bay.centreline[segment_index+1].x,
					bay.centreline[segment_index+1].z)
				local noise={schema="grug_wp40_geometry_source_v1",seed=world_seed,
					domain=bay.noise_domain,feature="",octaves={
						{period=256,amplitude_numerator=2,amplitude_denominator=3},
						{period=512,amplitude_numerator=1,amplitude_denominator=3}}}
				local deltas,buckets={},{ }
				for station_index=1,#stations do local point=stations[station_index]
					local noise_q=deterministic.clamp(deterministic.value_noise_2d(
						canonical,raw_sha256,noise,point.x,point.z),-Q,Q)
					local distance=math.min(station_index-1,#stations-station_index)
					local taper=deterministic.smootherstep(deterministic.qfrom_ratio(
						math.min(distance,96),96))
					deltas[station_index]=deterministic.qround(deterministic.qmul(
						deterministic.qmul(noise_q,bay.max_displacement*Q),taper))
				end
				for first=1,#stations,32 do
					local bucket={first=first,last=math.min(first+31,#stations)}
					for station_index=bucket.first,bucket.last do local point=stations[station_index]
						bucket.min_x=bucket.min_x and math.min(bucket.min_x,point.x) or point.x
						bucket.max_x=bucket.max_x and math.max(bucket.max_x,point.x) or point.x
						bucket.min_z=bucket.min_z and math.min(bucket.min_z,point.z) or point.z
						bucket.max_z=bucket.max_z and math.max(bucket.max_z,point.z) or point.z
					end
					buckets[#buckets+1]=bucket
				end
				compiled.segments[segment_index]={stations=stations,deltas=deltas,
					buckets=buckets}
			end
			bay_by_id[bay.id]=compiled
		end
		local function bucket_lower(bucket,x,z)
			local dx=x<bucket.min_x and bucket.min_x-x or
				x>bucket.max_x and x-bucket.max_x or 0
			local dz=z<bucket.min_z and bucket.min_z-z or
				z>bucket.max_z and z-bucket.max_z or 0
			return dx*dx+dz*dz
		end
		local function nearest_delta(segment,x,z)
			local first_bucket,first_lower
			for bucket_index=1,#segment.buckets do
				local lower=bucket_lower(segment.buckets[bucket_index],x,z)
				if not first_lower or lower<first_lower then
					first_bucket,first_lower=bucket_index,lower
				end
			end
			local best_index,best_distance
			local function inspect(bucket)
				for station_index=bucket.first,bucket.last do
					local station=segment.stations[station_index]
					local dx,dz=station.x-x,station.z-z
					local distance=dx*dx+dz*dz
					if not best_distance or distance<best_distance or
							distance==best_distance and station_index<best_index then
						best_index,best_distance=station_index,distance
					end
				end
			end
			inspect(segment.buckets[first_bucket])
			for bucket_index=1,#segment.buckets do
				if bucket_index~=first_bucket and
						bucket_lower(segment.buckets[bucket_index],x,z)<=best_distance then
					inspect(segment.buckets[bucket_index])
				end
			end
			return segment.deltas[best_index]
		end
		local function base_member(compiled,x,z)
			local bay=compiled.source
			for segment_index=1,#bay.centreline-1 do
				local segment=compiled.segments[segment_index]
				local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
				local vx,vz=b.x-a.x,b.z-a.z
				local px,pz=x-a.x,z-a.z
				local length=vx*vx+vz*vz
				local projection=px*vx+pz*vz
				local max_width=math.max(a.half_width,b.half_width)+bay.max_displacement
				local possible
				if projection<=0 then possible=px*px+pz*pz<max_width*max_width
				elseif projection>=length then local ex,ez=x-b.x,z-b.z
					possible=ex*ex+ez*ez<max_width*max_width
				else local cross=vx*pz-vz*px
					possible=cross*cross*length<(max_width*length)*(max_width*length) end
				if possible then
					local delta=nearest_delta(segment,x,z)
					if projection<=0 then local width=a.half_width+delta
						if px*px+pz*pz<width*width then return true end
					elseif projection>=length then local ex,ez=x-b.x,z-b.z
						local width=b.half_width+delta
						if ex*ex+ez*ez<width*width then return true end
					else local cross=vx*pz-vz*px
						local width=(a.half_width+delta)*(length-projection)+
							(b.half_width+delta)*projection
						if cross*cross*length<width*width then return true end
					end
				end
			end
			return false
		end
		local aperture_station_by_bay,aperture_run_by_id={},{}
		for aperture_index=1,#source.bay_mouth_apertures do
			local aperture=source.bay_mouth_apertures[aperture_index]
			local compiled=assert(bay_by_id[aperture.bay_id])
			local stations=assert(final_perimeter_by_id[aperture.perimeter_id])
			local mouth=compiled.source.centreline[1]
			local mouth_index
			for station_index=1,#stations do
				if stations[station_index].x==mouth.x and stations[station_index].z==mouth.z then
					assert(not mouth_index,"R17 mouth appears twice on final perimeter")
					mouth_index=station_index
				end
			end
			assert(mouth_index,"R17 mouth absent from final perimeter")
			local first,last=mouth_index,mouth_index
			while first>1 and base_member(compiled,stations[first-1].x,
					stations[first-1].z) do first=first-1 end
			while last<#stations and base_member(compiled,stations[last+1].x,
					stations[last+1].z) do last=last+1 end
			assert(first>1 and last<#stations,"R17 aperture wrapped final perimeter")
			local included={}
			for station_index=first,last do included[point_key(stations[station_index])]=true end
			aperture_station_by_bay[aperture.bay_id]=included
			aperture_run_by_id[aperture.id]={first=first,last=last,
				before=stations[first-1],after=stations[last+1],
				first_point=stations[first],last_point=stations[last]}
		end
		local bay_context_by_id={}
		for bay_index=1,#source.bays do local bay=source.bays[bay_index]
			local perimeter_id=bay.perimeter_projection.perimeter_id
			local context={bay_id=bay.id,compiled=bay_by_id[bay.id],
				perimeter=final_perimeter_by_id[perimeter_id],
				footprint_class=footprint_classifier[perimeter_id],boxes={}}
			for segment_index=1,#bay.centreline-1 do
				local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
				local radius=checked_integer_sum(checked_integer_sum(
					math.max(a.half_width,b.half_width),bay.max_displacement),1)
				context.boxes[#context.boxes+1]={
					min_x=checked_integer_sum(math.min(a.x,b.x),-radius),
					max_x=checked_integer_sum(math.max(a.x,b.x),radius),
					min_z=checked_integer_sum(math.min(a.z,b.z),-radius),
					max_z=checked_integer_sum(math.max(a.z,b.z),radius)}
			end
			for wing_index=1,#wing_by_bay[bay.id] do local closure=wing_by_bay[bay.id][wing_index]
				local radius=checked_integer_sum(closure.head_half_width,1)
				context.boxes[#context.boxes+1]={
					min_x=checked_integer_sum(math.min(closure.head.x,closure.junction.x),-radius),
					max_x=checked_integer_sum(math.max(closure.head.x,closure.junction.x),radius),
					min_z=checked_integer_sum(math.min(closure.head.z,closure.junction.z),-radius),
					max_z=checked_integer_sum(math.max(closure.head.z,closure.junction.z),radius)}
			end
			for box_index=1,#context.boxes do local box=context.boxes[box_index]
				context.min_x=context.min_x and math.min(context.min_x,box.min_x) or box.min_x
				context.max_x=context.max_x and math.max(context.max_x,box.max_x) or box.max_x
				context.min_z=context.min_z and math.min(context.min_z,box.min_z) or box.min_z
				context.max_z=context.max_z and math.max(context.max_z,box.max_z) or box.max_z
			end
			bay_context_by_id[bay.id]=context
		end
		local function in_bay_envelope(context,x,z)
			for box_index=1,#context.boxes do local box=context.boxes[box_index]
				if x>=box.min_x and x<=box.max_x and z>=box.min_z and z<=box.max_z then
					return true
				end
			end
			return false
		end
		local function bay_water(bay_id,x,z)
			local context=bay_context_by_id[bay_id]
			local class=context.footprint_class(x,z)
			if class<0 then return false end
			if base_member(context.compiled,x,z) and
					(class>0 or aperture_station_by_bay[bay_id][x..":"..z]) then return true end
			if class>0 then
				for wing_index=1,#wing_by_bay[bay_id] do
					if r8_wing_member(x,z,wing_by_bay[bay_id][wing_index]) then return true end
				end
			end
			return false
		end
		local owner_cache={}
		local function raw_owner(x,z)
			local key=x..":"..z
			local cached=owner_cache[key]
			if cached then return cached.count,cached.owner end
			local count,owner=0
			for bay_index=1,#source.bays do local bay_id=source.bays[bay_index].id
				if bay_water(bay_id,x,z) then count=count+1 owner=owner or bay_id end
			end
			owner_cache[key]={count=count,owner=owner}
			return count,owner
		end
		return {seed=world_seed,final_perimeter_by_id=final_perimeter_by_id,
			perimeter_ceiling=perimeter_ceiling,bay_context_by_id=bay_context_by_id,
			perimeter_segment_points=perimeter_segment_points,
			aperture_run_by_id=aperture_run_by_id,
			in_bay_envelope=in_bay_envelope,bay_water=bay_water,raw_owner=raw_owner,
			clear_owner_cache=function() owner_cache={} end}
	end
	local max_raw_world=build_raw_world(seed)
	local final_perimeter_by_id=max_raw_world.final_perimeter_by_id
	local perimeter_ceiling=max_raw_world.perimeter_ceiling
	local bay_context_by_id=max_raw_world.bay_context_by_id
	local in_bay_envelope=max_raw_world.in_bay_envelope
	local raw_bay_water=max_raw_world.bay_water
	local raw_water_owner_count=max_raw_world.raw_owner
	local cardinal={{x=1,z=0},{x=0,z=-1},{x=-1,z=0},{x=0,z=1}}
	local diagonal={{x=1,z=-1},{x=-1,z=-1},{x=-1,z=1},{x=1,z=1}}
	local function checked_neighbour(value,delta)
		assert(value==math.floor(value) and (delta==0 or delta==1 or delta==-1) and
			value>-MAX_SAFE_INTEGER and value<MAX_SAFE_INTEGER,
			"R17 unsafe neighbour coordinate")
		return checked_integer_sum(value,delta)
	end
	assert(not pcall(checked_neighbour,MAX_SAFE_INTEGER,1) and
		not pcall(checked_integer_sum,-MAX_SAFE_INTEGER,-1),
		"R17 unsafe envelope/neighbour arithmetic was accepted")
	local function raw_notch_predicate(bay_id,x,z,strict_inside,raw_owner)
		if not strict_inside(x,z) then return false end
		local center_count=raw_owner(x,z)
		if center_count~=0 then return false end
		local water_count,dry_neighbor=0
		for direction_index=1,4 do local direction=cardinal[direction_index]
			local nx,nz=checked_neighbour(x,direction.x),
				checked_neighbour(z,direction.z)
			local count,owner=raw_owner(nx,nz)
			if count==1 and owner==bay_id and strict_inside(nx,nz) then
				water_count=water_count+1
			elseif count==0 and strict_inside(nx,nz) and not dry_neighbor then
				dry_neighbor={x=nx,z=nz}
			else return false end
		end
		if water_count~=3 or not dry_neighbor then return false end
		for direction_index=1,4 do local direction=diagonal[direction_index]
			local nx,nz=checked_neighbour(x,direction.x),
				checked_neighbour(z,direction.z)
			local count,owner=raw_owner(nx,nz)
			if not strict_inside(nx,nz) or count~=1 or owner~=bay_id then
				return false
			end
		end
		return true,dry_neighbor
	end
	local function raw_notch_candidate(world,bay_id,x,z,synthetic_owner)
		local context=world.bay_context_by_id[bay_id]
		if not world.in_bay_envelope(context,x,z) then return false end
		return raw_notch_predicate(bay_id,x,z,function(px,pz)
			return context.footprint_class(px,pz)==1
		end,synthetic_owner or world.raw_owner)
	end
	local zone_numeric={}
	for zone_index=1,#source.zones do zone_numeric[source.zones[zone_index].id]=zone_index end
	local function rational_compare(an,ad,bn,bd)
		local reverse=false
		while true do
			local aq,bq=math.floor(an/ad),math.floor(bn/bd)
			if aq~=bq then local result=aq<bq and -1 or 1
				return reverse and -result or result end
			local ar,br=an-aq*ad,bn-bq*bd
			if ar==0 or br==0 then local result
				if ar==br then result=0 elseif ar==0 then result=-1 else result=1 end
				return reverse and -result or result
			end
			an,ad,bn,bd=ad,ar,bd,br reverse=not reverse
		end
	end
	local function exact_base_owner(bay,x,z)
		local best_n,best_d,best_owner
		for segment_index=1,#bay.centreline-1 do
			local a,b=bay.centreline[segment_index],bay.centreline[segment_index+1]
			local vx,vz=b.x-a.x,b.z-a.z
			local px,pz=x-a.x,z-a.z
			local length=vx*vx+vz*vz
			local projection=px*vx+pz*vz
			local cross=vx*pz-vz*px
			local numerator,denominator
			if projection<=0 then numerator,denominator=px*px+pz*pz,1
			elseif projection>=length then local ex,ez=x-b.x,z-b.z
				numerator,denominator=ex*ex+ez*ez,1
			else numerator,denominator=cross*cross,length end
			local span
			for span_index=1,#bay.owner_spans do local candidate=bay.owner_spans[span_index]
				if segment_index>=candidate.first_segment and
						segment_index<=candidate.last_segment then span=candidate break end
			end
			assert(span)
			local owner=cross>0 and span.left_zone_id or cross<0 and
				span.right_zone_id or (zone_numeric[span.left_zone_id]<
				zone_numeric[span.right_zone_id] and span.left_zone_id or span.right_zone_id)
			local comparison=best_n and rational_compare(numerator,denominator,
				best_n,best_d) or -1
			if comparison<0 then best_n,best_d,best_owner=numerator,denominator,owner
			elseif comparison==0 and zone_numeric[owner]<zone_numeric[best_owner] then
				best_owner=owner
			end
		end
		return best_owner
	end
	local function enumerate_raw_notches(world,label)
		local result,counts,by_point={},{},{}
		for bay_index=1,#source.bays do local bay=source.bays[bay_index]
			local context=world.bay_context_by_id[bay.id]
			counts[bay.id]=0
			for x=context.min_x,context.max_x do for z=context.min_z,context.max_z do
				if world.in_bay_envelope(context,x,z) then
					local accepted,dry=raw_notch_predicate(bay.id,x,z,function(px,pz)
						return context.footprint_class(px,pz)==1
					end,world.raw_owner)
					if accepted then
						local key=x..":"..z
						assert(not by_point[key],"R17 P qualified for multiple Bays: "..key)
						by_point[key]=bay.id counts[bay.id]=counts[bay.id]+1
						result[#result+1]={bay_id=bay.id,x=x,z=z,dry_x=dry.x,dry_z=dry.z,
							owner=exact_base_owner(bay,x,z)}
					end
				end
			end end
		end
		print(("WP40 T2 R17 exhaustive raw-notch %s EW/EE/KW/KE=%d/%d/%d/%d total=%d"):
			format(label,counts.bay_elandor_west,counts.bay_elandor_east,
			counts.bay_kragmar_west,counts.bay_kragmar_east,#result))
		return result,counts,by_point
	end
	local function verify_row_endpoint_superset(world,label,exhaustive)
		local selected={}
		for bay_index=1,#source.bays do local bay=source.bays[bay_index]
			local context=world.bay_context_by_id[bay.id]
			local candidates={}
			for z=context.min_z,context.max_z do
				local first
				for x=context.min_x,context.max_x do
					local water=world.bay_water(bay.id,x,z)
					if water and not first then first=x end
					if not water and first then
						local finish=checked_integer_sum(x,-1)
						for _,candidate_x in ipairs({checked_integer_sum(first,-1),
							checked_integer_sum(finish,1)}) do
							if candidate_x>=context.min_x and candidate_x<=context.max_x and
								world.in_bay_envelope(context,candidate_x,z) then
								candidates[candidate_x..":"..z]={x=candidate_x,z=z}
							end
						end
						first=nil
					end
				end
				if first then local candidate_x=checked_integer_sum(first,-1)
					if candidate_x>=context.min_x and
							world.in_bay_envelope(context,candidate_x,z) then
						candidates[candidate_x..":"..z]={x=candidate_x,z=z}
					end
				end
			end
			for _,point in pairs(candidates) do
				if raw_notch_candidate(world,bay.id,point.x,point.z) then
					local key=point.x..":"..point.z
					assert(not selected[key] or selected[key]==bay.id)
					selected[key]=bay.id
				end
			end
		end
		for key,bay_id in pairs(exhaustive) do
			assert(selected[key]==bay_id,
				"R17 row-end theorem missed exhaustive P: "..label..":"..key)
		end
		for key,bay_id in pairs(selected) do
			assert(exhaustive[key]==bay_id,
				"R17 row-end theorem added nonsemantic P: "..label..":"..key)
		end
	end
	do
		for dry_direction=1,4 do
			local raw={}
			for direction_index=1,4 do if direction_index~=dry_direction then
				local direction=cardinal[direction_index]
				raw[direction.x..":"..direction.z]=true
			end end
			local row_runs={}
			local first
			for x=-1,1 do
				if raw[x..":0"] and not first then first=x end
				if not raw[x..":0"] and first then
					row_runs[#row_runs+1]={first=first,finish=x-1}
					first=nil
				end
			end
			if first then row_runs[#row_runs+1]={first=first,finish=1} end
			local represented=false
			for run_index=1,#row_runs do local run=row_runs[run_index]
				if run.first-1==0 or run.finish+1==0 then represented=true end
			end
			assert(represented,
				"R17 row-end theorem lost a dry-cardinal orientation")
		end
	end
	local seed0_raw_world=build_raw_world("0")
	local seed0_notches,seed0_counts,seed0_by_point=
		enumerate_raw_notches(seed0_raw_world,"Seed0")
	assert(#seed0_notches==0 and seed0_counts.bay_elandor_west==0 and
		seed0_counts.bay_elandor_east==0 and seed0_counts.bay_kragmar_west==0 and
		seed0_counts.bay_kragmar_east==0,"R17 Seed0 raw-notch count drift")
	verify_row_endpoint_superset(seed0_raw_world,"Seed0",seed0_by_point)
	seed0_raw_world.clear_owner_cache() seed0_raw_world=nil collectgarbage("collect")
	local max_notches,max_counts,max_fill_by_point=
		enumerate_raw_notches(max_raw_world,"max-u64")
	verify_row_endpoint_superset(max_raw_world,"max-u64",max_fill_by_point)
	local function materialize_fill_payloads(rows)
		local payloads={}
		for bay_index=1,#source.bays do local bay=source.bays[bay_index]
			payloads[bay.id]={policy_id=source.geometry_policies.world_partition.
				bay_notch_fill_policy_id,count=0,columns={}}
		end
		for row_index=1,#rows do local row=rows[row_index]
			local payload=assert(payloads[row.bay_id])
			payload.columns[#payload.columns+1]={x=row.x,z=row.z}
		end
		for _,payload in pairs(payloads) do
			table.sort(payload.columns,function(a,b)
				return a.x<b.x or a.x==b.x and a.z<b.z
			end)
			payload.count=#payload.columns
		end
		return payloads
	end
	local fill_payloads=materialize_fill_payloads(max_notches)
	local synthetic_payload=materialize_fill_payloads({
		{bay_id="bay_elandor_west",x=2,z=-1},
		{bay_id="bay_elandor_west",x=-3,z=4},
		{bay_id="bay_elandor_west",x=2,z=-2},
	}).bay_elandor_west
	assert(synthetic_payload.count==3 and synthetic_payload.columns[1].x==-3 and
		synthetic_payload.columns[2].x==2 and synthetic_payload.columns[2].z==-2 and
		synthetic_payload.columns[3].z==-1,
		"R17 compiled fill payload lexicographic order drift")
	local notch_witnesses={
		{"bay_elandor_west",-775,-2349,-774,-2349,"elandor_goldmead_vale"},
		{"bay_elandor_east",887,-2036,886,-2036,"elandor_goldmead_vale"},
		{"bay_kragmar_west",-1121,2220,-1122,2220,"kragmar_mournfen"},
	}
	assert(#max_notches==#notch_witnesses and max_counts.bay_elandor_west==1 and
		max_counts.bay_elandor_east==1 and max_counts.bay_kragmar_west==1 and
		max_counts.bay_kragmar_east==0 and
		fill_payloads.bay_elandor_west.count==1 and
		fill_payloads.bay_elandor_east.count==1 and
		fill_payloads.bay_kragmar_west.count==1 and
		fill_payloads.bay_kragmar_east.count==0,
		"R17 max-u64 raw-notch/payload count drift")
	for witness_index=1,#notch_witnesses do local expected=notch_witnesses[witness_index]
		local actual=max_notches[witness_index]
		local payload=fill_payloads[expected[1]]
		assert(actual and actual.bay_id==expected[1] and actual.x==expected[2] and
			actual.z==expected[3] and actual.dry_x==expected[4] and
			actual.dry_z==expected[5] and actual.owner==expected[6] and
			payload.policy_id=="single_pass_same_bay_raw_mask_degree_one_notch_v1" and
			payload.columns[1].x==actual.x and payload.columns[1].z==actual.z,
			"R17 max-u64 notch/bay/connector/owner bijection drift: "..
				tostring(actual and (actual.bay_id.." "..actual.x..":"..actual.z..
				" dry="..actual.dry_x..":"..actual.dry_z.." owner="..actual.owner)))
		local context=max_raw_world.bay_context_by_id[actual.bay_id]
		for _,direction in ipairs({{x=0,z=0},cardinal[1],cardinal[2],cardinal[3],
				cardinal[4],diagonal[1],diagonal[2],diagonal[3],diagonal[4]}) do
			local px,pz=actual.x+direction.x,actual.z+direction.z
			assert(context.footprint_class(px,pz)==
				polygon_class(context.perimeter,px,pz),"R17 fast footprint classifier drift")
		end
	end
	local foreign_row=notch_witnesses[1]
	local foreign_key
	for direction_index=1,4 do local direction=cardinal[direction_index]
		local nx,nz=foreign_row[2]+direction.x,foreign_row[3]+direction.z
		local count,owner=raw_water_owner_count(nx,nz)
		if count==1 and owner==foreign_row[1] then foreign_key=nx..":"..nz break end
	end
	assert(foreign_key,"R17 witness has no same-Bay cardinal water")
	local function corrupt_owner(mode)
		return function(px,pz)
			local count,owner=raw_water_owner_count(px,pz)
			if px..":"..pz==foreign_key and count==1 and owner==foreign_row[1] then
				if mode=="foreign" then return 1,"bay_kragmar_east" end
				return 2,owner
			end
			return count,owner
		end
	end
	assert(not raw_notch_candidate(max_raw_world,foreign_row[1],foreign_row[2],
		foreign_row[3],corrupt_owner("foreign")),
		"R17 count-one foreign raw-water owner was accepted")
	assert(not raw_notch_candidate(max_raw_world,foreign_row[1],foreign_row[2],
		foreign_row[3],corrupt_owner("multiple")),
		"R17 multiple raw-water owners were accepted")
	do
		local raw={}
		local function set_water(x,z) raw[x..":"..z]="bay_fixture" end
		for _,point in ipairs({{-1,0},{0,-1},{0,1},{-1,-1},{1,-1},
				{-1,1},{1,1},{2,-1},{2,1}}) do set_water(point[1],point[2]) end
		local function inside() return true end
		local function owner(x,z)
			return raw[x..":"..z] and 1 or 0,raw[x..":"..z]
		end
		assert(raw_notch_predicate("bay_fixture",0,0,inside,owner) and
			not raw_notch_predicate("bay_fixture",1,0,inside,owner),
			"R17 synthetic raw-mask notch fixture drift")
		raw["0:0"]="bay_fixture"
		assert(raw_notch_predicate("bay_fixture",1,0,inside,owner),
			"R17 synthetic fixture no longer distinguishes recursive fill")
		raw["0:0"]=nil
		assert(not raw_notch_predicate("bay_fixture",0,0,
			function(x,z) return not (x==0 and z==0) end,owner),
			"R17 perimeter-equality center was accepted as strict interior")
		assert(not raw_notch_predicate("bay_fixture",0,0,
			function(x,z) return not (x==-1 and z==0) end,owner),
			"R17 non-interior cardinal water neighbour was accepted")
	end
	local function bay_water(bay_id,x,z)
		return raw_bay_water(bay_id,x,z) or max_fill_by_point[x..":"..z]==bay_id
	end
	local function final_water_owner_count(x,z)
		local count,owner=raw_water_owner_count(x,z)
		local fill=max_fill_by_point[x..":"..z]
		if fill then assert(count==0 and not owner) return 1,fill end
		return count,owner
	end
	print("WP40 T2 R17 exhaustive raw-notch oracle passed: Seed0=0 max-u64=1/1/1/0 "..
		"single-pass/nonrecursive/foreign/strict-interior guards")
	local function bay_dry(bay_id,x,z)
		local context=bay_context_by_id[bay_id]
		return context.footprint_class(x,z)>=0 and
			final_water_owner_count(x,z)==0
	end
	local function candidate(bay_id,x,z,synthetic_foreign_water)
		local context=bay_context_by_id[bay_id]
		if not in_bay_envelope(context,x,z) or not bay_dry(bay_id,x,z) then return false end
		local own=false
		for i=1,4 do local direction=cardinal[i]
			local nx,nz=x+direction.x,z+direction.z
			local own_neighbor=bay_water(bay_id,nx,nz)
			if own_neighbor then own=true end
			if (synthetic_foreign_water and synthetic_foreign_water(nx,nz)) or
					(final_water_owner_count(nx,nz)>0 and not own_neighbor) then return false end
		end
		return own
	end
	local function raw_candidate(bay_id,x,z)
		local context=bay_context_by_id[bay_id]
		if not in_bay_envelope(context,x,z) or context.footprint_class(x,z)<0 or
				raw_water_owner_count(x,z)>0 then return false end
		local own=false
		for i=1,4 do local direction=cardinal[i]
			local nx,nz=x+direction.x,z+direction.z
			local own_neighbor=raw_bay_water(bay_id,nx,nz)
			if own_neighbor then own=true end
			if raw_water_owner_count(nx,nz)>0 and not own_neighbor then return false end
		end
		return own
	end
	local retained={}
	for i=1,#provisional do
		if final_water_owner_count(provisional[i].x,provisional[i].z)==0 then
			retained[#retained+1]=i
		end
	end
	assert(#retained>0)
	for i=2,#retained do
		assert(retained[i]==retained[i-1]+1,"R16 land_010 gained a second dry run")
	end
	local e=provisional[retained[#retained]]
	local w=provisional[retained[#retained]+1]
	assert(e and w and e.x==-1140 and e.z==2241 and w.x==-1139 and w.z==2242,
		"R16 Slot-19 E/W drift: "..tostring(e and point_key(e)).."/"..
			tostring(w and point_key(w)))
	local transition_resolution_calls=0
	local function resolve_transition(bay_id,endpoint,discarded)
		transition_resolution_calls=transition_resolution_calls+1
		if candidate(bay_id,endpoint.x,endpoint.z) then
			return {x=endpoint.x,z=endpoint.z},"direct"
		end
		local context=bay_context_by_id[bay_id]
		assert(context.footprint_class(endpoint.x,endpoint.z)==1 and
			bay_dry(bay_id,endpoint.x,endpoint.z))
		for i=1,4 do local direction=cardinal[i]
			assert(final_water_owner_count(endpoint.x+direction.x,
				endpoint.z+direction.z)==0)
		end
		assert(math.abs(discarded.x-endpoint.x)==1 and
			math.abs(discarded.z-endpoint.z)==1)
		local count,owner=final_water_owner_count(discarded.x,discarded.z)
		assert(count==1 and owner==bay_id)
		local elbows={{x=discarded.x,z=endpoint.z},{x=endpoint.x,z=discarded.z}}
		assert(point_key(elbows[1])~=point_key(elbows[2]))
		for i=1,2 do assert(candidate(bay_id,elbows[i].x,elbows[i].z)) end
		table.sort(elbows,point_less)
		return elbows[1],"diagonal_elbow"
	end
	local terminal,mode=resolve_transition("bay_kragmar_west",e,w)
	assert(mode=="diagonal_elbow" and terminal.x==-1140 and terminal.z==2242 and
		candidate("bay_kragmar_west",terminal.x,terminal.z) and
		transition_resolution_calls==1 and not max_fill_by_point[point_key(terminal)],
		"R16 Slot-19 lex elbow drift")
	local trace_context=bay_context_by_id.bay_kragmar_west
	local min_x,max_x,min_z,max_z
	for box_index=1,#trace_context.boxes do local box=trace_context.boxes[box_index]
		min_x=min_x and math.min(min_x,box.min_x) or box.min_x
		max_x=max_x and math.max(max_x,box.max_x) or box.max_x
		min_z=min_z and math.min(min_z,box.min_z) or box.min_z
		max_z=max_z and math.max(max_z,box.max_z) or box.max_z
	end
	local envelope_columns,outside_footprint=0
	for x=min_x,max_x do for z=min_z,max_z do
		if in_bay_envelope(trace_context,x,z) then
			if trace_context.footprint_class(x,z)>=0 then
				envelope_columns=envelope_columns+1
			elseif not outside_footprint then outside_footprint={x=x,z=z} end
		end
	end end
	assert(perimeter_ceiling.perimeter_elandor_mainland==3 and
		perimeter_ceiling.perimeter_kragmar_mainland==2 and
		envelope_columns==1132870 and outside_footprint and
		not candidate("bay_kragmar_west",outside_footprint.x,outside_footprint.z) and
		not candidate("bay_kragmar_west",min_x-1,min_z),
		"R16 envelope/footprint candidate scope drift")
	local foreign_key
	for direction_index=1,4 do local direction=cardinal[direction_index]
		local nx,nz=terminal.x+direction.x,terminal.z+direction.z
		if not bay_water("bay_kragmar_west",nx,nz) then foreign_key=nx..":"..nz break end
	end
	assert(foreign_key and not candidate("bay_kragmar_west",terminal.x,terminal.z,
		function(x,z) return x..":"..z==foreign_key end),
		"R16 synthetic foreign-water candidate corruption was accepted")

	local wing
	for i=1,#source.bay_closure_wings do
		if source.bay_closure_wings[i].id=="bay_wing:kragmar_west:left" then
			wing=source.bay_closure_wings[i] break
		end
	end
	assert(wing)
	local vx,vz=wing.junction.x-wing.head.x,wing.junction.z-wing.head.z
	local length=vx*vx+vz*vz
	local k,k_projection
	local radius=wing.head_half_width
	for x=math.min(wing.head.x,wing.junction.x)-radius,
			math.max(wing.head.x,wing.junction.x)+radius do
		for z=math.min(wing.head.z,wing.junction.z)-radius,
				math.max(wing.head.z,wing.junction.z)+radius do
			local own_neighbor=false
			for direction_index=1,4 do local direction=cardinal[direction_index]
				if r8_wing_member(x+direction.x,z+direction.z,wing) then
					own_neighbor=true break
				end
			end
			if own_neighbor and bay_dry("bay_kragmar_west",x,z) then
				local px,pz=x-wing.head.x,z-wing.head.z
				local projection=px*vx+pz*vz
				local cross=vx*pz-vz*px
				local point={x=x,z=z}
				if projection>=0 and projection<length and cross<0 and
						(not k or projection>k_projection or
						projection==k_projection and point_less(point,k)) then
					k,k_projection=point,projection
				end
			end
		end
	end
	assert(k and k.x==-1399 and k.z==1901,"R16 independent negative K drift")
	local clockwise={{x=1,z=0},{x=1,z=-1},{x=0,z=-1},{x=-1,z=-1},
		{x=-1,z=0},{x=-1,z=1},{x=0,z=1},{x=1,z=1}}
	local function diagonal_signature(a,b)
		local dx,dz=b.x-a.x,b.z-a.z
		if math.abs(dx)~=1 or math.abs(dz)~=1 then return nil end
		return math.min(a.x,b.x)..":"..math.min(a.z,b.z),dx==dz and 1 or -1
	end
	local function add_diagonal(diagonals,a,b)
		local cell,slope=diagonal_signature(a,b)
		if not cell then return true,nil end
		if diagonals[cell] and diagonals[cell]~=slope then return false,nil end
		if diagonals[cell] then return true,nil end
		diagonals[cell]=slope
		return true,cell
	end
	local function state_key(previous,current)
		return point_key(previous)..">"..point_key(current)
	end
	local function water_right_for(water,current,following)
		local dx,dz=following.x-current.x,following.z-current.z
		for i=1,4 do local direction=cardinal[i]
			if water("bay_kragmar_west",current.x+direction.x,
					current.z+direction.z) and
					dx*direction.z-dz*direction.x<0 then return true end
		end
		return false
	end
	local function successors_for(candidate_fn,water,previous,current,states,columns,
			diagonals)
		local bx,bz=previous.x-current.x,previous.z-current.z
		local back
		for i=1,8 do if clockwise[i].x==bx and clockwise[i].z==bz then back=i break end end
		assert(back,"R16 non-eight-connected Moore state")
		local result={}
		for offset=1,8 do
			local index=((back-offset-1)%8)+1
			local direction=clockwise[index]
			local following={x=current.x+direction.x,z=current.z+direction.z}
			local key=point_key(following)
			local state=state_key(current,following)
			local cell,slope=diagonal_signature(current,following)
			if key~=point_key(previous) and not states[state] and not columns[key] and
					(not cell or not diagonals[cell] or diagonals[cell]==slope) and
					candidate_fn("bay_kragmar_west",following.x,following.z) and
					water_right_for(water,current,following) then result[#result+1]=following end
		end
		return result
	end
	local function trace_bank(candidate_fn,water,start_previous,start_current,
			trace_target,trace_envelope_columns)
	local active_envelope_columns=trace_envelope_columns or envelope_columns
	local pushed_total,max_pushed_per_call,max_stack=0,0,0
	local function reachable(previous,current,target,base_states,base_columns,base_diagonals)
		local states,columns,diagonals={},{},{}
		for key in pairs(base_states) do states[key]=true end
		for key in pairs(base_columns) do columns[key]=true end
		for key,value in pairs(base_diagonals) do diagonals[key]=value end
		local first_state,first_column=state_key(previous,current),point_key(current)
		if states[first_state] or columns[first_column] then return false end
		states[first_state],columns[first_column]=true,true
		local diagonal_ok,first_cell=add_diagonal(diagonals,previous,current)
		if not diagonal_ok then return false end
		local stack={{previous=previous,current=current,state=first_state,
			column=first_column,diagonal=first_cell}}
		local pushed_frames=1
		pushed_total=pushed_total+1
		max_pushed_per_call=math.max(max_pushed_per_call,pushed_frames)
		max_stack=math.max(max_stack,#stack)
		assert(pushed_frames<=8*active_envelope_columns and
			#stack<=active_envelope_columns,
			"R16 independent DFS initial bound")
		while #stack>0 do
			local frame=stack[#stack]
			if point_key(frame.current)==point_key(target) then return true end
			if not frame.nexts then
				frame.nexts=successors_for(candidate_fn,water,frame.previous,
					frame.current,states,columns,diagonals)
				frame.next_index=1
			end
			local following=frame.nexts[frame.next_index]
			if following then
				frame.next_index=frame.next_index+1
				local state=state_key(frame.current,following)
				local column=point_key(following)
				states[state],columns[column]=true,true
				local diagonal_valid,cell=add_diagonal(diagonals,frame.current,following)
				assert(diagonal_valid,"R16 successor diagonal validity drift")
				stack[#stack+1]={previous=frame.current,current=following,
					state=state,column=column,diagonal=cell}
				pushed_frames=pushed_frames+1
				pushed_total=pushed_total+1
				max_pushed_per_call=math.max(max_pushed_per_call,pushed_frames)
				max_stack=math.max(max_stack,#stack)
				assert(pushed_frames<=8*active_envelope_columns and
					#stack<=active_envelope_columns,
					"R16 independent DFS exact envelope bound")
			else
				states[frame.state],columns[frame.column]=nil,nil
				if frame.diagonal then diagonals[frame.diagonal]=nil end
				stack[#stack]=nil
			end
		end
		return false
	end
	local points={start_previous or {x=wing.junction.x,z=wing.junction.z},
		start_current or {x=k.x,z=k.z}}
	local previous,current=points[1],points[2]
	local active_target=trace_target or terminal
	local states={[state_key(previous,current)]=true}
	local columns={[point_key(previous)]=true,[point_key(current)]=true}
	local diagonals={}
	local first_valid=add_diagonal(diagonals,previous,current)
	assert(first_valid,"R16 negative Wing tail gained an X-cross")
	local branch_count,main_steps=0,0
	while point_key(current)~=point_key(active_target) do
		local nexts=successors_for(candidate_fn,water,previous,current,states,
			columns,diagonals)
		local following
		if #nexts==1 then following=nexts[1]
		elseif #nexts>1 then
			branch_count=branch_count+1
			for i=1,#nexts do
				if reachable(current,nexts[i],active_target,states,columns,diagonals) then
					following=nexts[i] break
				end
			end
		end
		assert(following,"R16 independent Mournfen DFS cannot reach elbow")
		local state=state_key(current,following)
		local diagonal_valid=add_diagonal(diagonals,current,following)
		assert(diagonal_valid,"R16 main trace gained an X-cross")
		states[state],columns[point_key(following)]=true,true
		points[#points+1]={x=following.x,z=following.z}
		previous,current=current,following
		main_steps=main_steps+1
		assert(main_steps<=active_envelope_columns-1,
			"R16 independent main trace bound")
	end
	return {points=points,branch_count=branch_count,pushed_total=pushed_total,
		max_pushed_per_call=max_pushed_per_call,max_stack=max_stack,
		main_steps=main_steps}
	end
	local raw_trace=trace_bank(raw_candidate,raw_bay_water)
	local final_trace=trace_bank(candidate,bay_water)
	local points=final_trace.points
	local tail={}
	for i=math.max(1,#points-5),#points do tail[#tail+1]=point_key(points[i]) end
	local path_sha=canonical.hex(raw_sha256(raster_signature(points)))
	assert(#points==453 and table.concat(tail,",")==
		"-1135:2237,-1136:2238,-1137:2239,-1138:2240,-1139:2241,-1140:2242",
		"R16 independent Mournfen path drift: "..#points.."/"..table.concat(tail,","))
	assert(raw_trace.branch_count==1 and raw_trace.pushed_total==24 and
		raw_trace.max_pushed_per_call==23 and raw_trace.max_stack==23 and
		raw_trace.main_steps==451 and final_trace.branch_count==0 and
		final_trace.pushed_total==0 and final_trace.max_pushed_per_call==0 and
		final_trace.max_stack==0 and final_trace.main_steps==451 and
		raster_signature(raw_trace.points)==raster_signature(final_trace.points) and
		final_trace.main_steps<=envelope_columns-1 and
		path_sha=="1f528c5671fe69254049b03c3ef5047093bb743f9ddcfdb3967b73a000740cca",
		"R16/R17 raw-before/final-mask DFS branch/frame/hash drift: "..
			raw_trace.branch_count.."/"..raw_trace.pushed_total.."->"..
			final_trace.branch_count.."/"..final_trace.pushed_total.."/"..path_sha)
	local stillgrave_nexts=successors_for(candidate,bay_water,e,terminal,{},
		{[point_key(terminal)]=true},{})
	assert(#stillgrave_nexts==1 and stillgrave_nexts[1].x==-1141 and
		stillgrave_nexts[1].z==2242,"R16 Stillgrave first successor drift")

	-- R19 independently reconstructs the hidden pre-R18 Slot29 seed from the
	-- same Source+T1-only machinery.  It keeps R18's maximal dry interval,
	-- probes every R16-resolvable incidence through a candidate-specific final
	-- edge reraster, and accepts only the tuple whose two incident Banks both
	-- reach their fixed other terminals.
	local r19_seed="16178445837170081103"
	local r19_ceiling,r19_row_count,r19_identity,r19_provisional,
		r19_controls,r19_scalars=selected_land_edge_identity(10,r19_seed)
	assert(r19_ceiling==3 and r19_row_count==#r19_controls and
		#r19_controls==#r19_scalars and #r19_provisional>0 and #r19_identity>0,
		"R19 selected-R7 land_010 materialization drift")
	local r19_world=build_raw_world(r19_seed)
	local r19_fills,_,r19_fill_by_point=enumerate_raw_notches(r19_world,"R19-slot29")
	local function r19_water(bay_id,x,z)
		return r19_world.bay_water(bay_id,x,z) or
			r19_fill_by_point[x..":"..z]==bay_id
	end
	local function r19_owner(x,z)
		local count,owner=r19_world.raw_owner(x,z)
		local fill=r19_fill_by_point[x..":"..z]
		if fill then assert(count==0 and not owner) return 1,fill end
		return count,owner
	end
	local function r19_candidate(bay_id,x,z)
		local context=r19_world.bay_context_by_id[bay_id]
		if not r19_world.in_bay_envelope(context,x,z) or
				context.footprint_class(x,z)<0 or r19_owner(x,z)>0 then return false end
		local own=false
		for direction_index=1,4 do local direction=cardinal[direction_index]
			local nx,nz=checked_neighbour(x,direction.x),
				checked_neighbour(z,direction.z)
			local own_water=r19_water(bay_id,nx,nz)
			if own_water then own=true end
			if r19_owner(nx,nz)>0 and not own_water then return false end
		end
		return own
	end
	local kw_context=r19_world.bay_context_by_id.bay_kragmar_west
	local r19_dry_runs={}
	for point_index=1,#r19_provisional do local point=r19_provisional[point_index]
		if kw_context and kw_context.footprint_class(point.x,point.z)>=0 and
				r19_owner(point.x,point.z)==0 then
			local run=r19_dry_runs[#r19_dry_runs]
			if not run or run.last~=point_index-1 then
				run={first=point_index,last=point_index}
				r19_dry_runs[#r19_dry_runs+1]=run
			else run.last=point_index end
		end
	end
	assert(#r19_dry_runs==1,"R19 land_010 R18 interval count drift: "..#r19_dry_runs)
	local r19_run=r19_dry_runs[1]
	local r19_interval_key={}
	for point_index=r19_run.first,r19_run.last do
		r19_interval_key[point_key(r19_provisional[point_index])]=point_index
	end
	local r19_control_point_index={}
	for control_index=1,#r19_controls do
		r19_control_point_index[control_index]=r19_interval_key[point_key(r19_controls[control_index])]
	end

	local attachment_segment=assert(r19_world.perimeter_segment_points.
		perimeter_kragmar_mainland[6])
	local attachment_e=r19_provisional[r19_run.first]
	local canonical_perimeter=canonical_closed_rows(
		r19_world.final_perimeter_by_id.perimeter_kragmar_mainland)
	local canonical_index={}
	for index=1,#canonical_perimeter do canonical_index[point_key(canonical_perimeter[index])]=index end
	local attachment_a,attachment_distance,attachment_index
	for index=1,#attachment_segment do local point=attachment_segment[index]
		local distance=math.max(math.abs(point.x-attachment_e.x),
			math.abs(point.z-attachment_e.z))
		local order=assert(canonical_index[point_key(point)])
		if not attachment_distance or distance<attachment_distance or
				distance==attachment_distance and order<attachment_index then
			attachment_a,attachment_distance,attachment_index=point,distance,order
		end
	end
	assert(attachment_a and attachment_distance<=1,
		"R19 land_010 attachment probe failed: E="..point_key(attachment_e)..
		" A="..tostring(attachment_a and point_key(attachment_a))..
		" d="..tostring(attachment_distance))

	local r19_min_x,r19_max_x,r19_min_z,r19_max_z
	for box_index=1,#kw_context.boxes do local box=kw_context.boxes[box_index]
		r19_min_x=r19_min_x and math.min(r19_min_x,box.min_x) or box.min_x
		r19_max_x=r19_max_x and math.max(r19_max_x,box.max_x) or box.max_x
		r19_min_z=r19_min_z and math.min(r19_min_z,box.min_z) or box.min_z
		r19_max_z=r19_max_z and math.max(r19_max_z,box.max_z) or box.max_z
	end
	local r19_envelope_columns=0
	for x=r19_min_x,r19_max_x do for z=r19_min_z,r19_max_z do
		if r19_world.in_bay_envelope(kw_context,x,z) and
				kw_context.footprint_class(x,z)>=0 then
			r19_envelope_columns=r19_envelope_columns+1
		end
	end end
	assert(r19_envelope_columns>0,"R19 empty exact Kragmar-west trace envelope")
	local kw_aperture
	for aperture_index=1,#source.bay_mouth_apertures do local aperture=
			source.bay_mouth_apertures[aperture_index]
		if aperture.bay_id=="bay_kragmar_west" then kw_aperture=aperture break end
	end
	assert(kw_aperture and kw_aperture.id=="bay_mouth_aperture:kragmar_west" and
		kw_aperture.perimeter_id=="perimeter_kragmar_mainland",
		"R19 Kragmar-west aperture Source projection drift")
	local kw_aperture_run=assert(r19_world.aperture_run_by_id[kw_aperture.id])
	local aperture_points=r19_world.final_perimeter_by_id.perimeter_kragmar_mainland
	local final_aperture_first,final_aperture_last,final_aperture_runs
	for index=1,#aperture_points do local point=aperture_points[index]
		local included=kw_context.footprint_class(point.x,point.z)==0 and
			r19_water("bay_kragmar_west",point.x,point.z)
		if included then
			if not final_aperture_last or final_aperture_last~=index-1 then
				final_aperture_runs=(final_aperture_runs or 0)+1
				final_aperture_first=index
			end
			final_aperture_last=index
		end
	end
	assert(final_aperture_runs==1 and final_aperture_first==kw_aperture_run.first and
		final_aperture_last==kw_aperture_run.last,
		"R19 final-mask authored-order aperture run differs from Source projection")
	local aperture_signature={}
	for index=kw_aperture_run.first,kw_aperture_run.last do
		aperture_signature[#aperture_signature+1]=point_key(aperture_points[index])
	end
	local aperture_sha=canonical.hex(raw_sha256(table.concat(aperture_signature,",")))
	assert(#aperture_signature==625 and
		aperture_sha=="864ce08d38aacfa028bac35d82435018c721ee3dd6563ac14021741f28f25837",
		"R19 final-mask aperture bytes drift: "..#aperture_signature.."/"..
		aperture_sha)
	local stillgrave_target=kw_aperture_run.before
	assert(point_key(stillgrave_target)=="-1386:2938" and
		kw_context.footprint_class(stillgrave_target.x,stillgrave_target.z)==0 and
		r19_owner(stillgrave_target.x,stillgrave_target.z)==0 and
		not r19_fill_by_point[point_key(stillgrave_target)],
		"R19 final-mask Stillgrave aperture target drift: "..
		point_key(stillgrave_target))

	local r19_wing
	for wing_index=1,#source.bay_closure_wings do
		if source.bay_closure_wings[wing_index].id=="bay_wing:kragmar_west:left" then
			r19_wing=source.bay_closure_wings[wing_index] break
		end
	end
	assert(r19_wing)
	local r19_wing_vx,r19_wing_vz=
		r19_wing.junction.x-r19_wing.head.x,
		r19_wing.junction.z-r19_wing.head.z
	local r19_wing_length=r19_wing_vx*r19_wing_vx+
		r19_wing_vz*r19_wing_vz
	local function r19_select_wing_k(sign)
		local best,best_projection
		for x=math.min(r19_wing.head.x,r19_wing.junction.x)-
				r19_wing.head_half_width,
				math.max(r19_wing.head.x,r19_wing.junction.x)+
				r19_wing.head_half_width do
			for z=math.min(r19_wing.head.z,r19_wing.junction.z)-
					r19_wing.head_half_width,
					math.max(r19_wing.head.z,r19_wing.junction.z)+
					r19_wing.head_half_width do
				local own_neighbor=false
				for direction_index=1,4 do local direction=cardinal[direction_index]
					if r8_wing_member(checked_neighbour(x,direction.x),
							checked_neighbour(z,direction.z),r19_wing) then
						own_neighbor=true break
					end
				end
				local px,pz=x-r19_wing.head.x,z-r19_wing.head.z
				local projection=px*r19_wing_vx+pz*r19_wing_vz
				local side=r19_wing_vx*pz-r19_wing_vz*px
				local point={x=x,z=z}
				if own_neighbor and kw_context.footprint_class(x,z)>=0 and
						r19_owner(x,z)==0 and projection>=0 and
						projection<r19_wing_length and
						(sign<0 and side<0 or sign>0 and side>0) and
						(not best or projection>best_projection or
						projection==best_projection and point_less(point,best)) then
					best,best_projection=point,projection
				end
			end
		end
		return assert(best,"R19 R15 Wing K set is empty")
	end
	local function r19_tail_paths(k,sign)
		local result,path={},{ {x=k.x,z=k.z} }
		local function visit(current)
			local distance=math.max(math.abs(current.x-r19_wing.junction.x),
				math.abs(current.z-r19_wing.junction.z))
			if distance==0 then
				local copy={}
				for index=1,#path do copy[index]={x=path[index].x,z=path[index].z} end
				result[#result+1]=copy return
			end
			local next_points={}
			for dz=-1,1 do for dx=-1,1 do
				if dx~=0 or dz~=0 then
					local x,z=checked_neighbour(current.x,dx),
						checked_neighbour(current.z,dz)
					if math.max(math.abs(x-r19_wing.junction.x),
							math.abs(z-r19_wing.junction.z))==distance-1 then
						local px,pz=x-r19_wing.head.x,z-r19_wing.head.z
						local side=r19_wing_vx*pz-r19_wing_vz*px
						if x==r19_wing.junction.x and z==r19_wing.junction.z or
								(kw_context.footprint_class(x,z)>=0 and
								r19_owner(x,z)==0 and
								(sign<0 and side<0 or sign>0 and side>0)) then
							next_points[#next_points+1]={x=x,z=z}
						end
					end
				end
			end end
			table.sort(next_points,point_less)
			for index=1,#next_points do
				path[#path+1]=next_points[index] visit(next_points[index]) path[#path]=nil
			end
		end
		visit(k) return result
	end
	local function r19_path_less(a,b)
		for index=1,math.min(#a,#b) do
			if point_less(a[index],b[index]) then return true end
			if point_less(b[index],a[index]) then return false end
		end
		return #a<#b
	end
	local function r19_pair_less(a,b)
		if r19_path_less(a.negative,b.negative) then return true end
		if r19_path_less(b.negative,a.negative) then return false end
		return r19_path_less(a.positive,b.positive)
	end
	local function r19_structural_pair(pair)
		local occupied={}
		for index=1,#pair.negative-1 do occupied[point_key(pair.negative[index])]=true end
		for index=1,#pair.positive-1 do
			if occupied[point_key(pair.positive[index])] then return false end
		end
		if point_key(pair.negative[#pair.negative-1])==
				point_key(pair.positive[#pair.positive-1]) then return false end
		local diagonals={}
		for _,path in ipairs({pair.negative,pair.positive}) do
			for index=1,#path-1 do
				local ok=add_diagonal(diagonals,path[index],path[index+1])
				if not ok then return false end
			end
		end
		return true
	end
	local function r19_orientation(a,b,c)
		return (b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
	end
	local function r19_on_segment(a,b,p)
		return r19_orientation(a,b,p)==0 and p.x>=math.min(a.x,b.x) and
			p.x<=math.max(a.x,b.x) and p.z>=math.min(a.z,b.z) and
			p.z<=math.max(a.z,b.z)
	end
	local function r19_intersects(a,b,c,d)
		local ac,ad=r19_orientation(a,b,c),r19_orientation(a,b,d)
		local ca,cb=r19_orientation(c,d,a),r19_orientation(c,d,b)
		return ac==0 and r19_on_segment(a,b,c) or
			ad==0 and r19_on_segment(a,b,d) or
			ca==0 and r19_on_segment(c,d,a) or
			cb==0 and r19_on_segment(c,d,b) or
			((ac<0)~=(ad<0) and (ca<0)~=(cb<0))
	end
	local function r19_wedge_valid(pair)
		local polygon={}
		for index=1,#pair.negative do polygon[#polygon+1]=pair.negative[index] end
		for index=#pair.positive-1,1,-1 do polygon[#polygon+1]=pair.positive[index] end
		local seen={}
		for index=1,#polygon do
			if seen[point_key(polygon[index])] then return false end
			seen[point_key(polygon[index])]=true
		end
		local area2=0
		for index=1,#polygon do local a,b=polygon[index],polygon[index%#polygon+1]
			area2=area2+a.x*b.z-b.x*a.z
		end
		if area2==0 then return false end
		for first=1,#polygon do local a,b=polygon[first],polygon[first%#polygon+1]
			for second=first+1,#polygon do
				if second~=first+1 and not (first==1 and second==#polygon) then
					if r19_intersects(a,b,polygon[second],polygon[second%#polygon+1]) then
						return false
					end
				end
			end
		end
		local radius=math.max(
			math.max(math.abs(pair.negative[1].x-r19_wing.junction.x),
				math.abs(pair.negative[1].z-r19_wing.junction.z)),
			math.max(math.abs(pair.positive[1].x-r19_wing.junction.x),
				math.abs(pair.positive[1].z-r19_wing.junction.z)))+1
		if radius>5 then return false end
		local exempt={}
		for _,path in ipairs({pair.negative,pair.positive}) do
			for index=1,#path do exempt[point_key(path[index])]=true end
		end
		for x=r19_wing.junction.x-radius,r19_wing.junction.x+radius do
			for z=r19_wing.junction.z-radius,r19_wing.junction.z+radius do
				local winding=0
				for index=1,#polygon do local a,b=polygon[index],polygon[index%#polygon+1]
					local side=r19_orientation(a,b,{x=x,z=z})
					if side==0 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
							z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then
						winding=1 break
					end
					if a.z<=z then if b.z>z and side>0 then winding=winding+1 end
					elseif b.z<=z and side<0 then winding=winding-1 end
				end
				if winding~=0 and not exempt[x..":"..z] and
						not r8_wing_member(x,z,r19_wing) then return false end
			end
		end
		return true,radius
	end
	local negative_paths=r19_tail_paths(r19_select_wing_k(-1),-1)
	local positive_paths=r19_tail_paths(r19_select_wing_k(1),1)
	local r19_pairs={}
	for negative_index=1,#negative_paths do for positive_index=1,#positive_paths do
		local pair={negative=negative_paths[negative_index],
			positive=positive_paths[positive_index]}
		if r19_structural_pair(pair) then r19_pairs[#r19_pairs+1]=pair end
	end end
	table.sort(r19_pairs,r19_pair_less)
	local r19_wedge_valid_pairs={}
	for pair_index=1,#r19_pairs do
		local valid,radius=r19_wedge_valid(r19_pairs[pair_index])
		if valid then r19_wedge_valid_pairs[#r19_wedge_valid_pairs+1]=
			{rank=pair_index,pair=r19_pairs[pair_index],radius=radius} end
	end
	assert(#r19_pairs==2 and #r19_wedge_valid_pairs==1 and
		r19_wedge_valid_pairs[1].rank==2 and r19_wedge_valid_pairs[1].radius==3,
		"R19 current-seed R15 pair/rank/radius drift")
	local r19_tail_pair=r19_wedge_valid_pairs[1].pair
	local r19_negative_tail=r19_tail_pair.negative
	assert(raster_signature(r19_tail_pair.negative)==
		"-1399:1901,-1400:1900" and
		raster_signature(r19_tail_pair.positive)==
		"-1398:1900,-1399:1900,-1400:1900",
		"R19 current-seed R15 selected full tail bytes drift")
	local r19_wing_k=r19_negative_tail[1]
	assert(point_key(r19_negative_tail[#r19_negative_tail])==
		point_key(r19_wing.junction) and #r19_negative_tail==2 and
		point_key(r19_wing_k)=="-1399:1901",
		"R19 frozen R15 negative tail bytes drift")
	for tail_index=1,#r19_negative_tail-1 do local tail=r19_negative_tail[tail_index]
		assert(kw_context.footprint_class(tail.x,tail.z)>=0 and
			r19_owner(tail.x,tail.z)==0,
			"R19 selected R15 tail is not final dry")
	end

	local function r19_resolve_incidence(point_index)
		local e_point=r19_provisional[point_index]
		if r19_candidate("bay_kragmar_west",e_point.x,e_point.z) then
			return {x=e_point.x,z=e_point.z},"direct",e_point
		end
		local toward=r19_provisional[point_index+1]
		if not toward or kw_context.footprint_class(e_point.x,e_point.z)~=1 or
				r19_owner(e_point.x,e_point.z)>0 or
				math.abs(toward.x-e_point.x)~=1 or math.abs(toward.z-e_point.z)~=1 then
			return nil
		end
		for direction_index=1,4 do local direction=cardinal[direction_index]
			if r19_owner(checked_neighbour(e_point.x,direction.x),
					checked_neighbour(e_point.z,direction.z))>0 then return nil end
		end
		local count,owner=r19_owner(toward.x,toward.z)
		if count~=1 or owner~="bay_kragmar_west" then return nil end
		local elbows={{x=toward.x,z=e_point.z},{x=e_point.x,z=toward.z}}
		if not r19_candidate("bay_kragmar_west",elbows[1].x,elbows[1].z) or
				not r19_candidate("bay_kragmar_west",elbows[2].x,elbows[2].z) then return nil end
		table.sort(elbows,point_less)
		return elbows[1],"diagonal_elbow",e_point
	end
	local function valid_r19_probe(points)
		if #points<2 then return false end
		local seen,diagonals={},{ }
		for point_index=1,#points do local point=points[point_index]
			local key=point_key(point)
			if seen[key] or kw_context.footprint_class(point.x,point.z)<0 or
					r19_owner(point.x,point.z)>0 then return false end
			seen[key]=true
			local bx,bz=deterministic.floor_div(point.x,bucket_size),
				deterministic.floor_div(point.z,bucket_size)
			local in_record_envelope=false
			for ox=-1,1 do for oz=-1,1 do
				local bucket=base_buckets[(bx+ox)..":"..(bz+oz)] or {}
				for source_index=1,#bucket do local base= bucket[source_index]
					if math.abs(point.x-base.x)<=edge.max_displacement and
							math.abs(point.z-base.z)<=edge.max_displacement then
						in_record_envelope=true break
					end
				end
				if in_record_envelope then break end
			end if in_record_envelope then break end end
			if not in_record_envelope then return false end
			if point_index>1 then
				local previous=points[point_index-1]
				local dx,dz=point.x-previous.x,point.z-previous.z
				if math.max(math.abs(dx),math.abs(dz))~=1 then return false end
				if math.abs(dx)==1 and math.abs(dz)==1 then
					local cell=math.min(point.x,previous.x)..":"..
						math.min(point.z,previous.z)
					local slope=dx==dz and 1 or -1
					if diagonals[cell] and diagonals[cell]~=slope then return false end
					diagonals[cell]=slope
				end
			end
		end
		return true
	end
	local r19_resolved,r19_complete={},{ }
	for point_index=r19_run.last,r19_run.first+1,-1 do
		local resolved,mode,e_point=r19_resolve_incidence(point_index)
		if resolved then
			local probe_controls={{x=attachment_a.x,z=attachment_a.z}}
			local previous_control_index,retained_control_count
			for control_index=1,#r19_controls do
				local interval_index=r19_control_point_index[control_index]
				if interval_index and interval_index>=r19_run.first and
						interval_index<=point_index then
					if previous_control_index then
						assert(control_index==previous_control_index+1,
							"R19 retained controls are not one contiguous subsequence")
					end
					previous_control_index=control_index
					retained_control_count=(retained_control_count or 0)+1
					local control=r19_controls[control_index]
					if point_key(probe_controls[#probe_controls])~=point_key(control) then
						probe_controls[#probe_controls+1]={x=control.x,z=control.z}
					end
				end
			end
			assert(retained_control_count and retained_control_count>0,
				"R19 empty retained R7 control subsequence")
			if mode=="diagonal_elbow" and
					point_key(probe_controls[#probe_controls])~=point_key(e_point) then
				probe_controls[#probe_controls+1]={x=e_point.x,z=e_point.z}
			end
			if point_key(probe_controls[#probe_controls])~=point_key(resolved) then
				probe_controls[#probe_controls+1]={x=resolved.x,z=resolved.z}
			end
			local probe_edge=raster_displaced_controls(probe_controls,false)
			if point_key(probe_edge[#probe_edge])==point_key(resolved) and
					valid_r19_probe(probe_edge) and
					r19_candidate("bay_kragmar_west",resolved.x,resolved.z) and
					r19_candidate("bay_kragmar_west",stillgrave_target.x,
						stillgrave_target.z) and
					r19_candidate("bay_kragmar_west",r19_wing_k.x,r19_wing_k.z) then
				local previous=probe_edge[#probe_edge-1]
				local still_ok,still=pcall(trace_bank,r19_candidate,r19_water,
					previous,resolved,stillgrave_target,r19_envelope_columns)
				local mourn_ok,mourn=pcall(trace_bank,r19_candidate,r19_water,
					r19_wing.junction,r19_wing_k,resolved,r19_envelope_columns)
				local row={point_index=point_index,mode=mode,terminal=resolved,
					previous=previous,edge=probe_edge,stillgrave=still_ok and still or nil,
					mournfen=mourn_ok and mourn or nil}
				r19_resolved[#r19_resolved+1]=row
				if still_ok and mourn_ok then r19_complete[#r19_complete+1]=row end
			end
		end
	end
	assert(#r19_resolved==2 and #r19_complete==1,
		"R19 Slot29 resolved/complete candidate count drift: "..
		#r19_resolved.."/"..#r19_complete)
	local r19_selected=r19_complete[1]
	assert(point_key(r19_selected.terminal)=="-1135:2242" and
		point_key(r19_selected.previous)=="-1136:2242" and
		#r19_selected.edge==1601,
		"R19 selected K/B/final-edge drift")
	local repeated_probe={}
	for index=1,#r19_selected.edge do local point=r19_selected.edge[index]
		repeated_probe[index]={x=point.x,z=point.z}
	end
	repeated_probe[3]={x=repeated_probe[2].x,z=repeated_probe[2].z}
	assert(not valid_r19_probe(repeated_probe),
		"R19 accepted repeated candidate-specific final edge station")
	local disconnected_probe={}
	for index=1,#r19_selected.edge do local point=r19_selected.edge[index]
		disconnected_probe[index]={x=point.x,z=point.z}
	end
	disconnected_probe[3]={x=disconnected_probe[2].x+2,
		z=disconnected_probe[2].z}
	assert(not valid_r19_probe(disconnected_probe),
		"R19 accepted non-8-connected candidate-specific final edge")
	local stillgrave_points={}
	for index=2,#r19_selected.stillgrave.points do
		stillgrave_points[#stillgrave_points+1]=r19_selected.stillgrave.points[index]
	end
	local mournfen_points=r19_selected.mournfen.points
	local edge_sha=canonical.hex(raw_sha256(raster_signature(r19_selected.edge)))
	local stillgrave_sha=canonical.hex(raw_sha256(raster_signature(stillgrave_points)))
	local mournfen_sha=canonical.hex(raw_sha256(raster_signature(mournfen_points)))
	assert(edge_sha=="f823d2abac877c13aa03484cb2941c784b16cbc2c15798bc087596caba7a8e70" and
		canonical.hex(raw_sha256(reversed_signature(r19_selected.edge)))==
			"d914e97cde5ee07c8a45c6fa7bafa5422aa7877429b4c04656433da60e030dc1" and
		#stillgrave_points==794 and
		stillgrave_sha=="f50970d89d04bf992bfb15f898621157e602abf624b09c6dff49fb09bf8d2317" and
		canonical.hex(raw_sha256(reversed_signature(stillgrave_points)))==
			"b98009b596c8ed73450523c8a52df9aecfc97a11f32b4babf8377fbd7555617a" and
		#mournfen_points==456 and
		mournfen_sha=="457ec6b155f092589972e01d21e6d2c13181a39e26a3eb700fa1e0f4c2071384" and
		canonical.hex(raw_sha256(reversed_signature(mournfen_points)))==
			"7229bcfa7ae0a3aa6f1c6027678abd71168eaba596a0e2971ffc411b85dffff4",
		"R19 computed edge/Bank byte witness drift: "..edge_sha.."/"..
		stillgrave_sha.."/"..mournfen_sha)
	local excluded=r19_provisional[r19_run.last]
	local edge_owner=0
	for index=1,#r19_selected.edge do
		if point_key(r19_selected.edge[index])==point_key(excluded) then edge_owner=edge_owner+1 end
	end
	local bank_owner=0
	for _,points_row in ipairs({stillgrave_points,mournfen_points}) do
		for index=1,#points_row do
			if point_key(points_row[index])==point_key(excluded) then
				bank_owner=bank_owner+1 break
			end
		end
	end
	assert(point_key(excluded)=="-1134:2242" and edge_owner==0 and bank_owner==1 and
		exact_base_owner(source.bays[3],excluded.x,excluded.z)=="kragmar_mournfen",
		"R19 excluded E owner witness drift")
	local r19_control_sha=canonical.hex(raw_sha256(raster_signature(r19_controls)))
	local r19_identity_sha=canonical.hex(raw_sha256(r19_identity))
	local scalar_parts={}
	for index=1,#r19_scalars do scalar_parts[index]=tostring(r19_scalars[index]) end
	local r19_scalar_sha=canonical.hex(raw_sha256(table.concat(scalar_parts,",")))
	assert(#r19_fills==0 and r19_control_sha==
		"c61d4cd4d0152e04b4f3afe4b061ff454ef04f2a5574524da4295b2e49a9c9c9" and
		r19_scalar_sha=="a251f81728b4aa000a1ed279ab055a7ed38fef81f338ab6d99963bf2b5117295" and
		r19_identity_sha=="25d19e716fc9ccee106f8bdd33938ac94a939d4f50609db3d0cead808261f255" and
		r19_envelope_columns==1130890 and 8*r19_envelope_columns==9047120 and
		r19_envelope_columns-1==1130889,
		"R19 unchanged upstream R7 control/scalar witness drift: "..
		r19_control_sha.."/"..r19_scalar_sha.."/"..r19_identity_sha..
		"/N="..r19_envelope_columns.."/AP="..kw_aperture_run.first..":"..
		kw_aperture_run.last)
	print(("WP40 T2 R19 Slot29 Source oracle passed: R16=%d complete=%d "..
		"K=%s B=%s edge=%d/%s Stillgrave=%d/%s Mournfen=%d/%s"):format(
		#r19_resolved,#r19_complete,point_key(r19_selected.terminal),
		point_key(r19_selected.previous),#r19_selected.edge,edge_sha,
		#stillgrave_points,stillgrave_sha,#mournfen_points,mournfen_sha))
	print(("WP40 T2 R16 Slot-19 oracle passed: C=%d perimeter-C=%d/%d N=%d "..
		"E=%s W=%s T=%s Mournfen=%d steps=%d branches=%d frames=%d/%d stack=%d "..
		"Stillgrave-nexts=%d sha=%s"):format(selected_ceiling,
		perimeter_ceiling.perimeter_elandor_mainland,
		perimeter_ceiling.perimeter_kragmar_mainland,envelope_columns,
		point_key(e),point_key(w),point_key(terminal),#points,final_trace.main_steps,
		final_trace.branch_count,final_trace.pushed_total,
		final_trace.max_pushed_per_call,final_trace.max_stack,
		#stillgrave_nexts,path_sha))
end
if arg._wp40_phase.enabled("r16_r17_source_oracle") then
	run_r16_r17_source_oracle()
end

-- R9 exact coast-source inheritance oracle. Segment distance is represented
-- by numerator/positive denominator and all minima are collected before the
-- zone/component/segment tie tuple is applied.
local function gcd_positive(a,b)
	while b~=0 do a,b=b,a%b end
	return a
end
local function rational_compare(an,ad,bn,bd)
	local g=gcd_positive(ad,bd)
	ad,bd=ad/g,bd/g
	local g1=gcd_positive(an,ad) an,ad=an/g1,ad/g1
	local g2=gcd_positive(bn,bd) bn,bd=bn/g2,bd/g2
	return an*bd-bn*ad
end
local function exact_segment_distance(px,pz,a,b)
	local dx,dz=b.x-a.x,b.z-a.z
	local qx,qz=px-a.x,pz-a.z
	local length=dx*dx+dz*dz
	local projection=qx*dx+qz*dz
	if projection<=0 then return qx*qx+qz*qz,1 end
	if projection>=length then
		local ex,ez=px-b.x,pz-b.z return ex*ex+ez*ez,1
	end
	local area=dx*qz-dz*qx
	return area*area,length
end
local function coast_source(candidates,px,pz)
	local minima,best_n,best_d={}
	for i=1,#candidates do local row=candidates[i]
		local n,d=exact_segment_distance(px,pz,row.a,row.b)
		local compare=best_n and rational_compare(n,d,best_n,best_d) or -1
		if compare<0 then minima,best_n,best_d={row},n,d
		elseif compare==0 then minima[#minima+1]=row end
	end
	table.sort(minima,function(a,b)
		if a.zone_numeric~=b.zone_numeric then return a.zone_numeric<b.zone_numeric end
		if a.component_id~=b.component_id then return a.component_id<b.component_id end
		return a.segment_index<b.segment_index
	end)
	return minima[1],best_n,best_d,#minima
end
local high_first={
	{zone_numeric=35,component_id="z_component",segment_index=7,
		a={x=-1,z=0},b={x=0,z=1}},
	{zone_numeric=34,component_id="a_component",segment_index=9,
		a={x=0,z=-1},b={x=1,z=0}},
}
local coast,numerator,denominator,ties=coast_source(high_first,0,0)
assert(coast.zone_numeric==34 and numerator==1 and denominator==2 and ties==2,
	"coast-source exact geometry tie failed to override iteration order")
local component_tie={
	{zone_numeric=5,component_id="b",segment_index=1,
		a={x=-1,z=0},b={x=0,z=1}},
	{zone_numeric=5,component_id="a",segment_index=2,
		a={x=0,z=-1},b={x=1,z=0}},
}
local component_winner=coast_source(component_tie,0,0)
assert(component_winner.component_id=="a",
	"coast-source stable component tie drift")
if arg._wp40_phase.enabled("coast_distance_kats") then
	local endpoint_a_n,endpoint_a_d=exact_segment_distance(-1,0,
		{x=0,z=0},{x=1,z=0})
	local endpoint_b_n,endpoint_b_d=exact_segment_distance(2,0,
		{x=0,z=0},{x=1,z=0})
	assert(endpoint_a_n==1 and endpoint_a_d==1 and endpoint_b_n==1 and
		endpoint_b_d==1,"coast-source endpoint distance branches drift")
	local unequal={
		{zone_numeric=9,component_id="endpoint",segment_index=0,
			a={x=2,z=0},b={x=3,z=0}},
		{zone_numeric=10,component_id="body",segment_index=0,
			a={x=0,z=0},b={x=1,z=1}},
	}
	local unequal_winner,unequal_n,unequal_d=coast_source(unequal,1,0)
	local reordered={unequal[2],unequal[1]}
	local reordered_winner=coast_source(reordered,1,0)
	assert(unequal_winner.component_id=="body" and unequal_n==1 and
		unequal_d==2 and reordered_winner.component_id=="body",
		"coast-source unequal rational/iteration-order comparison drift")
	local segment_tie={
		{zone_numeric=5,component_id="same",segment_index=1,
			a={x=0,z=0},b={x=1,z=1}},
		{zone_numeric=5,component_id="same",segment_index=0,
			a={x=0,z=0},b={x=1,z=1}},
	}
	local segment_winner=coast_source(segment_tie,1,0)
	assert(segment_winner.segment_index==0,
		"coast-source lower zero-based segment-index tie drift")
end
local coast_roster=source.geometry_policies.world_partition.
	coast_source_allowed_component_ids
assert(#coast_roster==22 and coast_roster[1]=="perimeter_span:elandor:stormvault" and
	coast_roster[18]=="perimeter_span:kragmar:thunderroot" and
	coast_roster[19]=="face_arc:gravesalt:holy_west" and
	coast_roster[20]=="face_arc:skyglass:holy_east" and
	coast_roster[21]=="face_arc:wyrmglass:island" and
	coast_roster[22]=="face_arc:stormscale:island" and
	8192*8192*2==134217728 and (2*8192)*(2*8192)==268435456 and
	268435456*2==536870912,
	"coast-source roster or safe-integer bound drift")
if arg._wp40_phase.enabled("lua_false_kat") then
	local false_is_not_a_lua_ternary=true and false or "fallback"
	assert(false_is_not_a_lua_ternary=="fallback",
		"Lua false/nil ternary trap KAT drift")
end

-- The Bay projection is an exact station-distance decision, not a rounded
-- parametric projection. This witness is the reviewed divergent case.
if arg._wp40_phase.enabled("bay_projection_divergence") then
	local points=raster_canonical_points(-980,-2940,-900,-2600)
	local px,pz=-1376,-2846
	local dx,dz=80,340
	local length_squared=dx*dx+dz*dz
	local projection_n=(px+980)*dx+(pz+2940)*dz
	local best_index,best_distance
	for i=1,#points do
		local dx,dz=points[i].x-px,points[i].z-pz
		local distance=dx*dx+dz*dz
		if not best_distance or distance<best_distance then
			best_index,best_distance=i,distance
		end
	end
	local rounded_parametric_index=math.floor(
		(2*projection_n*(#points-1)+length_squared)/(2*length_squared))+1
	assert(best_index==3 and points[best_index].x==-980 and
		points[best_index].z==-2938 and rounded_parametric_index==2 and
		points[rounded_parametric_index].x==-980 and
		points[rounded_parametric_index].z==-2939,
		"Bay exact station projection KAT drift")
end
local function bay_delta(noise_q,taper_q)
	return deterministic.qround(deterministic.qmul(
		deterministic.qmul(noise_q,48*Q),taper_q))
end
for _,fixture in ipairs({{Q,Q,48},{-Q,Q,-48},{0,Q,0},{Q,0,0},
		{Q,32768,24}}) do
	assert(bay_delta(fixture[1],fixture[2])==fixture[3],
		"Bay symmetric radius-delta KAT drift")
end
local synthetic_e,synthetic_l=10,1
assert((-9)*(-9)*synthetic_l<synthetic_e*synthetic_e and
	9*9*synthetic_l<synthetic_e*synthetic_e and
	not ((-10)*(-10)*synthetic_l<synthetic_e*synthetic_e) and
	not (10*10*synthetic_l<synthetic_e*synthetic_e),
	"Bay symmetric strict dry-equality KAT drift")
assert(4243584391840000<9007199254740991 and
	4251754341463400<9007199254740991,
	"Bay displacement safe-product KAT drift")

local function route_cross_section_weight(offset,visible_width,corridor_width)
	local distance=math.abs(offset)*Q
	local visible_half=deterministic.qfrom_ratio(visible_width,2)
	local corridor_half=deterministic.qfrom_ratio(corridor_width,2)
	if distance<=visible_half then return Q end
	if distance>=corridor_half then return 0 end
	local progress=deterministic.qdiv(distance-visible_half,
		corridor_half-visible_half)
	return Q-deterministic.smootherstep(progress)
end
local lateral={}
for offset=-math.floor(16/2),math.ceil(16/2)-1 do lateral[#lateral+1]=offset end
assert(#lateral==16 and lateral[1]==-8 and lateral[#lateral]==7,
	"centered half-open even route corridor drift")
local edge_weight=route_cross_section_weight(-8,7,16)
local center_weight=route_cross_section_weight(0,7,16)
assert(edge_weight==0 and center_weight==Q and
	deterministic.qround(deterministic.qlerp(10*Q,20*Q,edge_weight))==10 and
	deterministic.qround(deterministic.qlerp(10*Q,20*Q,center_weight))==20,
	"route cross-section final-target earthwork drift")

local function rim_offset(radius,inner,peak,outer,height)
	if radius<=inner or radius>=outer then return 0 end
	if radius<=peak then return deterministic.qmul(height*Q,
		deterministic.smootherstep(deterministic.qfrom_ratio(radius-inner,peak-inner))) end
	return deterministic.qmul(height*Q,Q-deterministic.smootherstep(
		deterministic.qfrom_ratio(radius-peak,outer-peak)))
end
assert(rim_offset(208,208,232,256,8)==0 and
	rim_offset(232,208,232,256,8)==8*Q and
	rim_offset(256,208,232,256,8)==0,
	"continuous rim boundary KAT drift")
local function terrace_offset(radius,step_run,step_height,rings)
	return math.min(rings-1,math.floor(radius/step_run))*step_height
end
assert(terrace_offset(0,56,3,5)==0 and
	terrace_offset(100,56,3,5)==3 and
	terrace_offset(300,56,3,5)==12 and
	source.template_compositions[4].operations[1].primitive_id=="terrace",
	"non-flat continuous-envelope elf terrace KAT drift")
local housing_samples={9,1,7,3,5,11}
table.sort(housing_samples)
assert(housing_samples[math.floor((#housing_samples+1)/2)]==5)

local fixture_policy=source.geometry_policies.geometry_fixture_selector
assert(#fixture_policy.classes==9 and fixture_policy.candidate_min==-40 and
	fixture_policy.candidate_max==39 and
	( fixture_policy.candidate_max-fixture_policy.candidate_min+1)^3==80^3 and
	fixture_policy.classes[7].feature_family_ids[5]=="route_crossing_interfaces" and
	fixture_policy.append_only_later_classes[1]==10 and
	fixture_policy.append_only_later_classes[2]==11,
	"geometry fixture selector KAT drift")
local trace_policy=source.geometry_policies.requester_trace
assert(trace_policy.active_tick_count==trace_policy.active_tick_last-
	trace_policy.active_tick_first+1 and 9*trace_policy.active_tick_last<300*100 and
	9*(trace_policy.active_tick_last+1)>=300*100 and
	trace_policy.recovery_tick_count*trace_policy.recovery_dtime.numerator==
	trace_policy.recovery_duration_seconds*trace_policy.recovery_dtime.denominator,
	"requester trace exact tick KAT drift")
local extreme_policy=source.geometry_policies.geometry_extreme_selector
-- A final +48Q sample on a record whose authored maximum is 96 nodes is
-- exactly +1/2 even if local damping clipped its available amplitude to 24.
local extreme_sample_q=48*Q
local extreme_record_max_q=96*Q
assert(extreme_sample_q*2==extreme_record_max_q and
	extreme_policy.normalization_denominator==
		"record_max_displacement_times_Q_not_local_damped_amplitude" and
	extreme_policy.sample_sequence==
		"pre_displacement_canonical_source_segment_raster_only_never_final_reraster_stations" and
	extreme_policy.scalar_sample_rule==
		"each_unique_source_station_scores_its_post_noise_damping_local_clip_selected_topology_ceiling_pre_component_scalar_q_exactly_once" and
	extreme_policy.scalar_stage==
		"final_signed_q16_after_noise_damping_local_magnitude_clip_and_selected_record_topology_ceiling_before_x_z_component_rounding" and
	extreme_policy.attachment_rule==
		"every_positive_displacement_canonical_source_station_scores_exactly_once_even_if_its_shifted_control_or_final_interval_is_not_selected_selector_excludes_only_derived_provisional_E_perimeter_A_elbows_and_other_inserted_final_reraster_stations_that_have_no_source_station_identity" and
	extreme_policy.score_all_candidates_before_stage2==true and
	extreme_policy.candidate_count==4096,
	"geometry extreme exact normalization KAT drift")
if arg._wp40_phase.enabled("extreme_span_union") then
	local segment_owners={}
	for span_index=1,#source.perimeter_spans do local span=source.perimeter_spans[span_index]
		if span.perimeter_id=="perimeter_elandor_mainland" then
			for segment_index=span.first_segment,span.last_segment do
				segment_owners[segment_index]=(segment_owners[segment_index] or 0)+1
			end
		end
	end
	assert(segment_owners[3]==2 and
		extreme_policy.coast_mainland_overlap_rule==
			"perimeter_span_overlap_never_duplicates_a_source_segment_or_station_in_the_union" and
		extreme_policy.coast_mainland_identity==
			"perimeter_id_zero_based_source_segment_index_zero_based_local_station_index" and
		extreme_policy.source_join_dedup==
			"duplicate_segment_join_and_closed_seam_station_keeps_the_stable_earlier_identity_in_the_declared_sequence" and
		extreme_policy.no_interpolation_rule==
			"never_interpolate_resample_or_rehash_a_selector_scalar",
		"geometry extreme overlapping perimeter span was not union-deduplicated")
end

-- Focused independent C2 algebraic witnesses.  Stage 1 owns no selected-seed
-- Bank/Face geometry; exhaustive compiler geometry remains a later gate.
if arg._wp40_phase.enabled("c2_source_algebra") then
	local function cross(ax,az,bx,bz) return ax*bz-az*bx end
	local function select_aperture_mode(row)
		if row.d_candidate then return "direct",row.a,row.d end
		assert(row.d_class==0 and row.d_own==0 and row.d_foreign==0)
		assert(row.w_raw_owner==row.bay and row.w_final_owner==row.bay and
			math.abs(row.w.x-row.d.x)==1 and math.abs(row.w.z-row.d.z)==1)
		local elbows={{x=row.w.x,z=row.d.z},{x=row.d.x,z=row.w.z}}
		local valid={}
		for i=1,2 do if row.candidate(elbows[i]) then valid[#valid+1]=elbows[i] end end
		assert(#valid==1)
		local t=valid[1]
		local from,to
		if row.terminal_side=="start" then from,to=row.d,t else from,to=t,row.d end
		assert(cross(to.x-from.x,to.z-from.z,row.w.x-from.x,row.w.z-from.z)<0)
		return "tail",from,to,t
	end
	local slot29={bay="bay_elandor_east",terminal_side="start",
		a={x=569,z=-2928},d={x=570,z=-2927},w={x=571,z=-2926},
		d_candidate=false,d_class=0,d_own=0,d_foreign=0,
		w_raw_owner="bay_elandor_east",w_final_owner="bay_elandor_east",
		candidate=function(p) return p.x==570 and p.z==-2926 end}
	local mode,from,to,t=select_aperture_mode(slot29)
	assert(mode=="tail" and from==slot29.d and to==t and
		t.x==570 and t.z==-2926,"C2 Slot29 shoulder-tail witness drift")
	local direct={a={x=1,z=1},d={x=2,z=2},d_candidate=true}
	assert(select_aperture_mode(direct)=="direct","C2 direct aperture mode drift")
	local finish={bay="synthetic",terminal_side="end",a={x=2,z=2},
		d={x=1,z=1},w={x=0,z=2},d_candidate=false,d_class=0,d_own=0,d_foreign=0,
		w_raw_owner="synthetic",w_final_owner="synthetic",
		candidate=function(p) return p.x==1 and p.z==2 end}
	assert(select_aperture_mode(finish)=="tail","C2 end-tail direction witness drift")
	local function copied_slot29(candidate,w)
		return {bay=slot29.bay,terminal_side="start",a=slot29.a,d=slot29.d,
			w=w or slot29.w,d_candidate=false,d_class=0,d_own=0,d_foreign=0,
			w_raw_owner=slot29.bay,w_final_owner=slot29.bay,candidate=candidate}
	end
	local ok=pcall(select_aperture_mode,copied_slot29(function() return false end))
	assert(not ok,"C2 zero-shoulder aperture tail was accepted")
	ok=pcall(select_aperture_mode,copied_slot29(function() return true end))
	assert(not ok,"C2 two-shoulder aperture tail was accepted")
	ok=pcall(select_aperture_mode,copied_slot29(function(p)
		return p.x==570 and p.z==-2926
	end,{x=569,z=-2926}))
	assert(not ok,"C2 wrong-side aperture tail was accepted")
	local finished={{x=570,z=-2927},{x=570,z=-2926},{x=571,z=-2925}}
	local finished_reverse={}
	for i=#finished,1,-1 do
		finished_reverse[#finished_reverse+1]={x=finished[i].x,z=finished[i].z}
	end
	for i=1,#finished do
		assert(finished_reverse[i].x==finished[#finished-i+1].x and
			finished_reverse[i].z==finished[#finished-i+1].z,
			"C2 aperture finished-byte reversal drift")
	end
	local function unique_controls(controls)
		local seen={}
		for i=1,#controls do
			if seen[controls[i]] then return false end
			seen[controls[i]]=true
		end
		return true
	end
	local function one_control_direction(controls)
		local step
		for i=2,#controls do
			local delta=controls[i]-controls[i-1]
			if delta~=1 and delta~=-1 then return false end
			step=step or delta
			if delta~=step then return false end
		end
		return true
	end

	local function select_incidence_complete(intervals)
		local selected
		for i=1,#intervals do
			local row=intervals[i]
			if row.from_ok and row.to_ok then
				assert(not selected,"multiple incidence-complete intervals")
				selected=row
			end
		end
		assert(selected,"no incidence-complete interval")
		assert(#selected.controls>0,"empty selected controls")
		assert(unique_controls(selected.controls),"repeated selected control")
		assert(one_control_direction(selected.controls),
			"noncontiguous or direction-flipped selected controls")
		for i=1,#intervals do
			if intervals[i]~=selected then
				assert(intervals[i].excluded_owner_count==1 and
					not intervals[i].final_land_identity,
					"excluded dry fragment ownership")
			end
		end
		return selected
	end
	local longer={id="longer",from_ok=true,to_ok=false,controls={1,2,3,4},
		excluded_owner_count=1,final_land_identity=false}
	local complete={id="complete",from_ok=true,to_ok=true,controls={7,8},
		stations={{x=1128,z=-2239},{x=1129,z=-2240}},
		excluded_owner_count=1,final_land_identity=false}
	assert(select_incidence_complete({longer,complete})==complete,
		"C2 selector used length instead of complete incidence")
	local reversed={id="complete",from_ok=complete.to_ok,to_ok=complete.from_ok,
		controls={8,7},stations={{x=1129,z=-2240},{x=1128,z=-2239}},
		excluded_owner_count=1,final_land_identity=false}
	assert(select_incidence_complete({reversed,longer})==reversed,
		"C2 reversal did not preserve complete obligation selection")
	for i=1,#complete.stations do
		local a=complete.stations[#complete.stations-i+1]
		local b=reversed.stations[i]
		assert(a.x==b.x and a.z==b.z,
			"C2 incidence-run final bytes were not exact reverse")
	end
	ok=pcall(select_incidence_complete,{{id="none",from_ok=true,to_ok=false,
		controls={1},excluded_owner_count=1,final_land_identity=false}})
	assert(not ok,"C2 accepted zero complete intervals")
	ok=pcall(select_incidence_complete,{{id="a",from_ok=true,to_ok=true,
		controls={1},excluded_owner_count=1},{id="b",from_ok=true,to_ok=true,
		controls={2},excluded_owner_count=1}})
	assert(not ok,"C2 accepted multiple complete intervals")
	ok=pcall(select_incidence_complete,{{id="bad",from_ok=true,to_ok=true,
		controls={1,3},excluded_owner_count=1}})
	assert(not ok,"C2 accepted noncontiguous selected controls")
	ok=pcall(select_incidence_complete,{{id="bad",from_ok=true,to_ok=true,
		controls={1,1},excluded_owner_count=1}})
	assert(not ok and not unique_controls({1,1}),
		"C2 accepted a repeated selected control")
	ok=pcall(select_incidence_complete,{{id="bad",from_ok=true,to_ok=true,
		controls={1,2,1},excluded_owner_count=1}})
	assert(not ok and not one_control_direction({1,2,1}),
		"C2 accepted a selected-control direction flip")
	for _,bad in ipairs({
		{id="bad",from_ok=false,to_ok=false,controls={3},excluded_owner_count=0,
			final_land_identity=false},
		{id="bad",from_ok=false,to_ok=false,controls={3},excluded_owner_count=2,
			final_land_identity=false},
		{id="bad",from_ok=false,to_ok=false,controls={3},excluded_owner_count=1,
			final_land_identity=true},
	}) do
		ok=pcall(select_incidence_complete,{complete,bad})
		assert(not ok,"C2 accepted invalid excluded dry-fragment ownership")
	end
end

-- Focused independent R19 terminal-tuple authority.  Stage 1 does not
-- materialize selected-seed geometry; these fixtures bind exhaustive tuple
-- selection, candidate-specific final-raster anchors, and the retained
-- compiler handoff witnesses without importing a Stage-2 implementation.
if arg._wp40_phase.enabled("r19_source_oracle") then
	local function point_key(point) return point.x..":"..point.z end
	local function byte_key(points)
		local parts={}
		for i=1,#points do parts[i]=point_key(points[i]) end
		return table.concat(parts,",")
	end
	local function reverse_points(points)
		local reversed={}
		for i=#points,1,-1 do
			reversed[#reversed+1]={x=points[i].x,z=points[i].z}
		end
		return reversed
	end
	local function select_joint_terminal(candidate_sets,probe)
		assert(#candidate_sets==1 or #candidate_sets==2,
			"R19 transition edge must have one or two endpoint candidate sets")
		local MAX_EXACT=9007199254740991
		local function safe_count_product(a,b)
			assert(a>=0 and b>=0 and math.floor(a)==a and math.floor(b)==b and
				(a==0 or b<=MAX_EXACT/a),"R19 candidate-count product overflow")
			return a*b
		end
		local expected_visits=1
		for endpoint_index=1,#candidate_sets do
			local candidates=candidate_sets[endpoint_index]
			assert(#candidates>0 and type(candidates.interval_station_count)=="number" and
				#candidates<=candidates.interval_station_count-1,
				"R19 endpoint candidate count exceeds interval bound")
			expected_visits=safe_count_product(expected_visits,#candidates)
		end
		local complete,identities,visited={},{ },0
		local tuple={}
		local function visit(endpoint_index)
			if endpoint_index<=#candidate_sets then
				local candidates=candidate_sets[endpoint_index]
				assert(#candidates>0,"R19 empty resolved endpoint candidate set")
				for candidate_index=1,#candidates do
					local candidate=candidates[candidate_index]
					assert(candidate.in_interval and candidate.has_adjacent_away,
						"R19 ineligible station incidence")
					tuple[endpoint_index]=candidate
					visit(endpoint_index+1)
				end
				return
			end
			visited=visited+1
			local result=probe(tuple)
			assert(type(result)=="table" and #result.edge_bytes>=2 and
				#result.terminals==#candidate_sets and
				#result.previous==#candidate_sets and
				#result.bank_pairs_complete==#candidate_sets,
				"R19 malformed joint probe")
			local identity_parts={byte_key(result.edge_bytes)}
			for i=1,#candidate_sets do
				local side=tuple[i].endpoint
				assert(side=="from" or side=="to","R19 candidate endpoint side")
				local endpoint=side=="from" and result.edge_bytes[1] or
					result.edge_bytes[#result.edge_bytes]
				local adjacent=side=="from" and result.edge_bytes[2] or
					result.edge_bytes[#result.edge_bytes-1]
				assert(point_key(endpoint)==point_key(result.terminals[i]) and
					point_key(adjacent)==point_key(result.previous[i]),
					"R19 anchor did not come from candidate-specific final edge bytes")
				identity_parts[#identity_parts+1]=point_key(result.terminals[i])
				identity_parts[#identity_parts+1]=point_key(result.previous[i])
			end
			local identity=table.concat(identity_parts,";")
			assert(not identities[identity],"R19 duplicate resolved tuple identity")
			identities[identity]=true
			local all_complete=true
			for i=1,#result.bank_pairs_complete do
				if not result.bank_pairs_complete[i] then all_complete=false end
			end
			if all_complete then complete[#complete+1]=result end
		end
		visit(1)
		assert(visited==expected_visits,"R19 did not enumerate full Cartesian set")
		assert(#complete==1,"R19 requires exactly one complete joint edge tuple")
		return complete[1],safe_count_product
	end

	-- Bresenham subline clipping is not byte stable.  The probe previous
	-- station must come from the rerasterized bytes, never from provisional
	-- selected-R7 adjacency.
	local provisional=raster_canonical_points(0,0,1,3)
	local probe_subline=raster_canonical_points(0,0,1,2)
	assert(point_key(provisional[2])=="0:1" and
		point_key(probe_subline[#probe_subline-1])=="1:1" and
		point_key(provisional[2])~=point_key(probe_subline[#probe_subline-1]),
		"R19 synthetic subline-divergence anchor KAT drift")
	local function synthetic_probe_controls(retained,e,t,mode)
		assert(#retained>0,"R19 synthetic empty retained controls")
		local controls={}
		for index=1,#retained do controls[index]=retained[index] end
		if mode=="diagonal_elbow" and
				point_key(controls[#controls])~=point_key(e) then
			controls[#controls+1]=e
		end
		if point_key(controls[#controls])~=point_key(t) then controls[#controls+1]=t end
		return controls
	end
	local diagonal_controls=synthetic_probe_controls({{x=0,z=0}},
		{x=1,z=1},{x=1,z=2},"diagonal_elbow")
	assert(byte_key(diagonal_controls)=="0:0,1:1,1:2",
		"R19 diagonal E-then-T probe control order drift")
	local empty_ok=pcall(synthetic_probe_controls,{},
		{x=1,z=1},{x=1,z=2},"diagonal_elbow")
	assert(not empty_ok,"R19 accepted empty retained probe controls")

	-- This authored-control fixture is deliberately selected twice.  Forward
	-- selection receives B,K,E and the `to` obligation; reversed selection
	-- receives E,K,B and the swapped `from` obligation.  Each candidate clips
	-- and rerasterizes its own control subsequence before Bank completeness is
	-- evaluated, so this is not a reversal of already-selected output bytes.
	local forward_controls={{x=-1136,z=2242,id="B"},
		{x=-1135,z=2242,id="K"},{x=-1134,z=2242,id="E"}}
	local reverse_controls={{x=-1134,z=2242,id="E"},
		{x=-1135,z=2242,id="K"},{x=-1136,z=2242,id="B"}}
	local slot29_E={id="E",x=-1134,z=2242,endpoint="to",authored_index=3,
		in_interval=true,has_adjacent_away=true}
	local slot29_K={id="K",x=-1135,z=2242,endpoint="to",authored_index=2,
		in_interval=true,has_adjacent_away=true}
	local slot29_candidates={slot29_E,slot29_K,interval_station_count=3}
	local function authored_candidate_probe(controls,candidate)
		local retained={}
		if candidate.endpoint=="to" then
			for index=1,candidate.authored_index do
				retained[#retained+1]=controls[index]
			end
		else
			for index=candidate.authored_index,#controls do
				retained[#retained+1]=controls[index]
			end
		end
		assert(#retained>=2,"R19 authored candidate probe lost its away anchor")
		local edge_bytes=raster_displaced_controls(retained,false)
		local terminal=candidate.endpoint=="from" and edge_bytes[1] or
			edge_bytes[#edge_bytes]
		local previous=candidate.endpoint=="from" and edge_bytes[2] or
			edge_bytes[#edge_bytes-1]
		assert(point_key(terminal)==candidate.x..":"..candidate.z,
			"R19 authored candidate probe terminal drift")
		return {edge_bytes=edge_bytes,terminals={terminal},previous={previous},
			bank_pairs_complete={candidate.id=="K"}}
	end
	local function slot29_probe(tuple)
		return authored_candidate_probe(forward_controls,tuple[1])
	end
	local selected,safe_count_product=select_joint_terminal({slot29_candidates},slot29_probe)
	assert(point_key(selected.terminals[1])=="-1135:2242" and
		point_key(selected.previous[1])=="-1136:2242",
		"R19 Slot29 unique complete terminal K drift")
	local reordered=select_joint_terminal({{slot29_K,slot29_E,
		interval_station_count=3}},slot29_probe)
	assert(byte_key(reordered.edge_bytes)==byte_key(selected.edge_bytes),
		"R19 candidate enumeration order changed selected bytes")

	-- Two-transition edges are selected as one Cartesian tuple because either
	-- endpoint changes the combined reraster and therefore both anchors.
	local left_a={id="left_a",endpoint="from",in_interval=true,has_adjacent_away=true}
	local left_b={id="left_b",endpoint="from",in_interval=true,has_adjacent_away=true}
	local right_a={id="right_a",endpoint="to",in_interval=true,has_adjacent_away=true}
	local right_b={id="right_b",endpoint="to",in_interval=true,has_adjacent_away=true}
	local function paired_probe(tuple)
		local chosen=tuple[1].id=="left_b" and tuple[2].id=="right_a"
		local left_previous=tuple[2].id=="right_a" and {x=1,z=0} or {x=1,z=1}
		local right_previous=tuple[1].id=="left_b" and {x=2,z=0} or {x=2,z=-1}
		return {edge_bytes={{x=0,z=0},left_previous,right_previous,{x=3,z=0}},
			terminals={{x=0,z=0},{x=3,z=0}},
			previous={left_previous,right_previous},
			bank_pairs_complete={chosen,chosen}}
	end
	local pair=select_joint_terminal({{left_a,left_b,interval_station_count=3},
		{right_a,right_b,interval_station_count=3}},paired_probe)
	assert(pair.bank_pairs_complete[1] and pair.bank_pairs_complete[2] and
		point_key(pair.previous[1])=="1:0",
		"R19 joint two-endpoint tuple selection drift")

	local ok=pcall(select_joint_terminal,{{slot29_E,interval_station_count=2}},slot29_probe)
	assert(not ok,"R19 accepted zero complete terminal tuples")
	ok=pcall(select_joint_terminal,{{slot29_K,slot29_K,interval_station_count=3}},slot29_probe)
	assert(not ok,"R19 accepted duplicate resolved tuple identity")
	ok=pcall(select_joint_terminal,{{slot29_K,{id="K2",x=-1135,z=2242,
		endpoint="to",in_interval=true,has_adjacent_away=true},
		interval_station_count=3}},function(tuple)
		if tuple[1].id=="K2" then
			return {edge_bytes={{x=-1138,z=2242},{x=-1137,z=2242}},
				terminals={{x=-1137,z=2242}},previous={{x=-1138,z=2242}},
				bank_pairs_complete={true}}
		end
		return slot29_probe(tuple)
	end)
	assert(not ok,"R19 accepted multiple complete terminal tuples")
	ok=pcall(select_joint_terminal,{{{id="opposite",endpoint="to",in_interval=true,
		has_adjacent_away=false},interval_station_count=2}},slot29_probe)
	assert(not ok,"R19 accepted an incidence without adjacent-away station")
	ok=pcall(safe_count_product,9007199254740991,2)
	assert(not ok,"R19 accepted candidate-count product overflow")

	local reversed=reverse_points(selected.edge_bytes)
	assert(byte_key(reversed)=="-1135:2242,-1136:2242" and
		byte_key(reverse_points(reversed))==byte_key(selected.edge_bytes),
		"R19 final-edge finished-byte reversal drift")
	local reversed_E={id="E",x=-1134,z=2242,endpoint="from",authored_index=1,
		in_interval=true,has_adjacent_away=true}
	local reversed_K={id="K",x=-1135,z=2242,endpoint="from",authored_index=2,
		in_interval=true,has_adjacent_away=true}
	local reversed_selected=select_joint_terminal({{reversed_E,reversed_K,
		interval_station_count=3}},function(tuple)
		return authored_candidate_probe(reverse_controls,tuple[1])
	end)
	assert(byte_key(reversed_selected.edge_bytes)==byte_key(reversed) and
		point_key(reversed_selected.terminals[1])=="-1135:2242" and
		point_key(reversed_selected.previous[1])=="-1136:2242",
		"R19 reversed authored controls/obligation re-enumeration drift")

	assert(#source.geometry_policies.boundary_displacement.
		bay_edge_transition_terminal_policy_id>0,
		"R19 terminal policy ID disappeared")
end

local function clone(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do copy[clone(key, seen)] = clone(child, seen) end
	return copy
end

local function expect_failure(id, mutate, vocab)
	local copy = clone(source)
	mutate(copy)
	local selected=vocab
	if vocab==nil then selected=vocabulary elseif vocab==false then selected=nil end
	local ok, failure = offline.validate(copy, selected)
	assert(not ok and failure.invariant == id,
		"expected diagnostic " .. id .. ", got " ..
		tostring(failure and failure.invariant))
end

local function expect_failure_at(id,record_id,mutate)
	local copy=clone(source)
	mutate(copy)
	local ok,failure=offline.validate(copy,vocabulary)
	assert(not ok and failure.invariant==id and failure.record_id==record_id,
		"expected diagnostic "..id..":"..record_id..", got "..
		tostring(failure and failure.invariant)..":"..
		tostring(failure and failure.record_id))
end

if arg._wp40_phase.enabled("source_corruption_kats") then
expect_failure("perimeter_fixed_closure_fields",function(s)
	s.perimeters[1].r7_fixed_closure.kind=nil
end)
expect_failure("perimeter_fixed_closure_fields",function(s)
	s.perimeters[1].r7_fixed_closure.extra=true
end)
expect_failure("perimeter_fixed_closure_ref_fields",function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs[1].direction=nil
end)
expect_failure("perimeter_fixed_closure_ref_fields",function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs[1].extra=true
end)
expect_failure("perimeter_fixed_closure_contract",function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs={}
end)
expect_failure("perimeter_fixed_closure_contract",function(s)
	s.perimeters[1].r7_fixed_closure.kind="copied_polyline"
end)
expect_failure("perimeter_fixed_closure_ref",function(s)
	local refs=s.perimeters[1].r7_fixed_closure.edge_refs
	refs[1],refs[2]=refs[2],refs[1]
end)
expect_failure("perimeter_fixed_closure_ref",function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs[3].direction="forward"
end)
expect_failure("perimeter_fixed_closure_contract",function(s)
	table.remove(s.perimeters[1].r7_fixed_closure.edge_refs,4)
end)
expect_failure("perimeter_fixed_closure_ref",function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs[3]=
		clone(s.perimeters[1].r7_fixed_closure.edge_refs[2])
end)
expect_failure("perimeter_fixed_closure_ref",function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs[2].edge_id="land_055"
end)
expect_failure("perimeter_fixed_closure_fixed_edge",function(s)
	s.land_edges[46].max_displacement=1
end)
expect_failure("perimeter_fixed_closure_join",function(s)
	s.land_edges[47].control[2].x=1501
	s.land_edges[47].to_junction_id="junction:1501:-250"
end)
expect_failure("perimeter_fixed_closure_repeat",function(s)
	s.land_edges[46].control={
		{x=0,z=-250},{x=1500,z=-500},{x=1500,z=-250},{x=750,z=-250},
	}
end)
expect_failure("perimeter_fixed_closure_scope",function(s)
	s.perimeters[3].r7_fixed_closure=clone(s.perimeters[1].r7_fixed_closure)
end)
expect_failure("perimeter_fixed_closure_projection",function(s)
	local components=s.perimeters[1].ordered_outer_components
	components[#components]="land_043:forward"
end)
expect_failure("perimeter_fixed_closure_geometry",function(s)
	local polygon=s.perimeters[1].polygon
	table.insert(polygon,#polygon,{x=0,z=-250})
end)
expect_failure("perimeter_fixed_closure_geometry",function(s)
	local polygon=s.perimeters[1].polygon
	local first,last=polygon[1],polygon[#polygon-1]
	polygon[#polygon+1]={x=last.x,z=last.z}
	polygon[#polygon+1]={x=first.x,z=first.z}
end)

expect_failure("section_order",function(s)
	s.section_order[1],s.section_order[2]=s.section_order[2],s.section_order[1]
end)
expect_failure_at("critical_manifest_fields","critical_source_manifest",
	function(s) s.critical_source_manifest=nil end)
expect_failure_at("critical_manifest_fields","critical_source_manifest.extra",
	function(s) s.critical_source_manifest.extra=0 end)
for _,row in ipairs({
	{"id","changed"},{"schema","changed"},{"mg_name","singlenode"},
	{"water_level",0},{"chunksize",4},{"num_emerge_threads",2},
	{"mgv7_dungeon_ymin",-30999},{"mgv7_dungeon_ymax",-192},
	{"broad_content_y_min",-36},
}) do
	local field,value=row[1],row[2]
	expect_failure_at("critical_manifest_value",
		"critical_source_manifest."..field,function(s)
			s.critical_source_manifest[field]=value
		end)
end
expect_failure_at("critical_manifest_fields",
	"critical_source_manifest.water_level",
	function(s) s.critical_source_manifest.water_level=nil end)
expect_failure("native_dungeon_force_forbidden",function(s)
	s.critical_source_manifest.force_native_dungeon=true
end)
expect_failure_at("critical_manifest_fields",
	"critical_source_manifest.force_native_dungeon",
	function(s) s.critical_source_manifest.force_native_dungeon=nil end)

expect_failure("critical_manifest_mg_flags",function(s)
	table.remove(s.critical_source_manifest.mg_flags,6)
end)
expect_failure("critical_manifest_mg_flags",function(s)
	s.critical_source_manifest.mg_flags[7]="liquids"
end)
expect_failure_at("critical_manifest_mg_flags",
	"critical_source_manifest.mg_flags[1]",function(s)
		local flags=s.critical_source_manifest.mg_flags
		flags[1],flags[2]=flags[2],flags[1]
	end)
expect_failure_at("critical_manifest_mg_flags",
	"critical_source_manifest.mg_flags[2]",function(s)
		s.critical_source_manifest.mg_flags[2]="dungeons"
	end)

expect_failure("critical_manifest_mgv7_special_flags",function(s)
	table.remove(s.critical_source_manifest.mgv7_special_flags,4)
end)
expect_failure("critical_manifest_mgv7_special_flags",function(s)
	s.critical_source_manifest.mgv7_special_flags[5]=
		{id="terrain",enabled=true}
end)
expect_failure_at("critical_manifest_mgv7_special_flags",
	"critical_source_manifest.mgv7_special_flags[1]",function(s)
		local flags=s.critical_source_manifest.mgv7_special_flags
		flags[1],flags[2]=flags[2],flags[1]
	end)
expect_failure_at("critical_manifest_mgv7_special_flags",
	"critical_source_manifest.mgv7_special_flags[2]",function(s)
		local flags=s.critical_source_manifest.mgv7_special_flags
		flags[2]={id="mountains",enabled=true}
	end)
for i=1,4 do
	expect_failure_at("critical_manifest_mgv7_special_flags",
		"critical_source_manifest.mgv7_special_flags["..i.."]",function(s)
			local row=s.critical_source_manifest.mgv7_special_flags[i]
			row.enabled=not row.enabled
		end)
end
expect_failure_at("critical_manifest_mgv7_special_flags",
	"critical_source_manifest.mgv7_special_flags[1].enabled",function(s)
		s.critical_source_manifest.mgv7_special_flags[1].enabled=nil
	end)

expect_failure_at("critical_manifest_noise_fields",
	"critical_source_manifest.mgv7_np_dungeons.offset",function(s)
		s.critical_source_manifest.mgv7_np_dungeons.offset=nil
	end)
expect_failure_at("critical_manifest_noise_fields",
	"critical_source_manifest.mgv7_np_dungeons.extra",function(s)
		s.critical_source_manifest.mgv7_np_dungeons.extra=0
	end)
for _,row in ipairs({
	{"offset","numerator",8},{"scale","numerator",2},
	{"persistence","numerator",3},
	{"offset","denominator",20},{"scale","denominator",4},
	{"persistence","denominator",10},
}) do
	local field,part,value=row[1],row[2],row[3]
	expect_failure_at("critical_manifest_noise_value",
		"critical_source_manifest.mgv7_np_dungeons."..field,function(s)
			s.critical_source_manifest.mgv7_np_dungeons[field][part]=value
		end)
end
for _,axis in ipairs({"x","y","z"}) do
	expect_failure_at("critical_manifest_noise_value",
		"critical_source_manifest.mgv7_np_dungeons.spread."..axis,
		function(s)
			s.critical_source_manifest.mgv7_np_dungeons.spread[axis]=499
		end)
end
for _,row in ipairs({{"seed",1},{"octaves",3},{"lacunarity",3}}) do
	local field,value=row[1],row[2]
	expect_failure_at("critical_manifest_noise_value",
		"critical_source_manifest.mgv7_np_dungeons."..field,function(s)
			s.critical_source_manifest.mgv7_np_dungeons[field]=value
		end)
end
expect_failure_at("critical_manifest_noise_fields",
	"critical_source_manifest.mgv7_np_dungeons.spread.w",function(s)
		s.critical_source_manifest.mgv7_np_dungeons.spread.w=500
	end)
expect_failure("critical_manifest_noise_flags",function(s)
	s.critical_source_manifest.mgv7_np_dungeons.flags={}
end)
expect_failure("critical_manifest_noise_flags",function(s)
	s.critical_source_manifest.mgv7_np_dungeons.flags={"defaults","eased"}
end)
expect_failure("critical_manifest_noise_flags",function(s)
	s.critical_source_manifest.mgv7_np_dungeons.flags={"defaults","defaults"}
end)
expect_failure_at("critical_manifest_noise_flags",
	"critical_source_manifest.mgv7_np_dungeons.flags[1]",function(s)
		s.critical_source_manifest.mgv7_np_dungeons.flags={"eased"}
	end)

expect_failure("exact_count_zones", function(s) s.zones[38] = nil end)
expect_failure("unique_string_id", function(s) s.zones[2].id=s.zones[1].id end)
expect_failure("zone_palette_total", function(s) s.zones[1].biomes[1].share=89 end)
expect_failure("land_edge_duplicate", function(s) s.land_edges[2].zone_a=s.land_edges[1].zone_a s.land_edges[2].zone_b=s.land_edges[1].zone_b end)
expect_failure("anchor_slot_identity", function(s) s.anchors[1].slot_id="invented" end)
expect_failure("polygon_closed", function(s) s.perimeters[1].polygon[#s.perimeters[1].polygon].x=-2499 end)
expect_failure("semantic_reference", function(s) s.semantics.race_region_assignments[1].g1="not_wp43" end)
expect_failure("integer_graph", function(s) s.constants.coast_displacement=96.5 end)
expect_failure("source_graph_value_type", function(s) s.constants.bad=function() end end)
expect_failure("source_graph_value_type", function(s) s.constants.bad=coroutine.create(function() end) end)
expect_failure("source_graph_value_type", function(s) s.constants.bad=io.stdout end)
expect_failure("source_graph_metatable", function(s) setmetatable(s.constants,{}) end)
expect_failure("native_dungeon_force_forbidden", function(s) s.templates[1].force_native_dungeon=true end)
expect_failure("native_dungeon_force_forbidden", function(s) s.constants.nested={force_native_dungeon=true} end)
expect_failure("source_graph_mixed_keys", function(s) s.constants[1]=1 end)
expect_failure("source_graph_dense_array", function(s) s.zones[100]=s.zones[1] end)
expect_failure("integer_graph", function(s) s.constants.q=0/0 end)
expect_failure("integer_graph", function(s) s.constants.q=math.huge end)
expect_failure("integer_graph", function(s) s.constants.q=9007199254740992 end)
expect_failure("acyclic_graph", function(s) s.constants.loop=s end)
expect_failure("rational_record", function(s) s.constants.island_route_parity.denominator=0 end)
expect_failure("edge_control_point", function(s) s.land_edges[1].control[1].x=nil end)
expect_failure("exact_count_land_edges",function(s) table.remove(s.land_edges,58) end)
expect_failure("boundary_only_land_edge",function(s) s.land_edges[58].boundary_only=false end)
expect_failure("boundary_only_route_forbidden",function(s)
	s.routes[1].boundary_id="land_058"
	s.routes[1].zone_a=s.land_edges[58].zone_a s.routes[1].zone_b=s.land_edges[58].zone_b
end)
expect_failure("old_land_edge_fixture",function(s) s.land_edges[57].boundary_only=true end)
expect_failure("exact_source_checksum", function(s) s.zones[1].display_name="Wrong" end)
expect_failure("face_edge_junctions", function(s) s.land_edges[1].control[1].x=-2699 end)
expect_failure("exact_count_relief_junctions",function(s)
	table.remove(s.relief_junctions,38)
end)
expect_failure("relief_junction_incidence",function(s)
	s.relief_junctions[1].incident_edge_ids[1],
		s.relief_junctions[1].incident_edge_ids[2]=
		s.relief_junctions[1].incident_edge_ids[2],
		s.relief_junctions[1].incident_edge_ids[1]
end)
expect_failure("relief_junction_band",function(s)
	s.relief_junctions[10].transition_midpoint_above_water=75
end)
expect_failure("relief_junction_contract",function(s)
	s.relief_junctions[1].hash_lane=0
end)
expect_failure("exact_count_junction_departures",function(s)
	table.remove(s.junction_departures,4)
end)
expect_failure("junction_departure_fields",function(s)
	s.junction_departures[1].position={x=-1399,z=-1099}
end)
expect_failure("junction_departure_contract",function(s)
	s.junction_departures[1].departure_rule="literal_departure_coordinate"
end)
expect_failure("junction_departure_duplicate",function(s)
	local duplicate=s.junction_departures[2]
	duplicate.id="junction_departure:land_035:from:duplicate"
	duplicate.edge_id="land_035"
	duplicate.junction_id="relief_junction:-1400:-1100"
end)
expect_failure("junction_departure_reference",function(s)
	s.junction_departures[1].edge_id="land_999"
end)
expect_failure("junction_departure_incidence",function(s)
	s.junction_departures[1].junction_id="relief_junction:400:-1100"
end)
expect_failure("junction_departure_incidence",function(s)
	s.junction_departures[1].edge_endpoint="to"
end)
expect_failure("junction_departure_diagonal",function(s)
	s.land_edges[35].control[2].x=s.land_edges[35].control[1].x
end)
expect_failure("junction_departure_safe_arithmetic",function(s)
	s.land_edges[35].control[2].x=9007199254740991
end)
expect_failure("junction_departure_derived_station",function(s)
	s.land_edges[35].control[2].x=-1500
end)
expect_failure("junction_pair_base_overlap",function(s)
	table.insert(s.land_edges[32].control,2,{x=-1399,z=-1099})
end)
expect_failure("junction_pair_base_x_cross",function(s)
	table.insert(s.land_edges[32].control,2,{x=-1400,z=-1099})
	table.insert(s.land_edges[32].control,3,{x=-1399,z=-1100})
end)
expect_failure("route_crosses_boundary", function(s) s.routes[1].centreline[s.routes[1].crossing_station].x=999 end)
expect_failure("route_station_ref", function(s) s.routes[1].station_a_id="station:elandor_copperfell_foothills:hub" end)
expect_failure("route_crossing_sides", function(s) local r=s.routes[1] r.centreline[2].x=r.centreline[4].x r.centreline[2].z=r.centreline[4].z end)
expect_failure("exact_boat_contract", function(s) s.boat_edges[1].approach_z=-124 end)
expect_failure("landmark_role", function(s) s.landmarks[1].roles[1]="unknown" end)
expect_failure("template_composition_ref", function(s) s.templates[1].composition_id="missing" end)
expect_failure("template_operation", function(s) s.template_compositions[1].operations[1].op="invent" end)
expect_failure("rare_patrol_offsets", function(s)
	s.anchors[91].patrol_offsets={s.anchors[91].patrol_offsets[1]}
end)
expect_failure("apex_socket_species_count", function(s)
	s.anchors[89].socket_reservations[1].resource_key="garnet"
end)
expect_failure("housing_zone", function(s) s.housing_masks[1].zone_id="elandor_hearthpine_vale" end)
expect_failure("coastal_core_contract", function(s) s.coastal_housing_cores[1].frontage_min=599 end)
expect_failure("coastal_core_contract", function(s)
	s.coastal_housing_cores[1].perimeter_span_id="perimeter_span:elandor:hearthpine"
end)
expect_failure("hydrology_contract", function(s) s.hydrology[1].profile_id="unknown" end)
expect_failure("hydrology_point", function(s) s.hydrology[1].centreline[1].half_width=0 end)
expect_failure("highcourt_arms_distinct", function(s) s.hydrology[6].centreline[1].x=s.hydrology[5].centreline[1].x end)
expect_failure("route_crossing_hydrology_incidence", function(s) for i=1,#s.hydrology[8].centreline do s.hydrology[8].centreline[i].z=-1513 end end)
expect_failure("hydrology_route_interface_incidence", function(s)
	s.route_crossing_interfaces[1].position.z=-1501
end)
expect_failure("tunnel_landmark_incidence", function(s) s.landmarks[65].center.x=1700 end)
expect_failure("island_landing_contract", function(s) s.island_landings[1].boat_edge_id="boat_wyrmglass_north" end)
expect_failure("island_route_target_independence", function(s)
	local route=s.island_routes[4]
	route.from_station_id="island_station_wyrmglass_dragon"
	route.centreline[1].x=-3260 route.centreline[1].z=-40
	local interface=s.island_route_interfaces[7]
	interface.station_id="island_station_wyrmglass_dragon"
	interface.position.x=-3260 interface.position.z=-40
end)
expect_failure("housing_smoothing_composition", function(s) s.template_compositions[18].operations[1].parameters.radius=49 end)
expect_failure("hydrology_contract", function(s)
	local row=s.hydrology[1]
	row.to_id=row.to_id..";water_node_semantic=s:"..row.water_node_semantic
	row.water_node_semantic=nil
end)
expect_failure("apex_socket_count", function(s)
	local sockets=s.anchors[89].socket_reservations
	table.remove(sockets,2)
end)
expect_failure("semantic_vocabulary", function(s) end, false)

-- Readiness mutations: every source authority above must fail before the KAT
-- rather than surviving until T2b compilation.
expect_failure("face_edge_probe_zone",function(s)
	local edge=s.land_edges[1]
	edge.left_zone,edge.right_zone=edge.right_zone,edge.left_zone
	edge.left_probe,edge.right_probe=edge.right_probe,edge.left_probe
end)
expect_failure("zone_face_closure",function(s)
	local cycle=s.zone_faces[4].cycle
	for i=#cycle,1,-1 do if cycle[i].ref_id=="land_058" then table.remove(cycle,i) break end end
end)
expect_failure("face_edge_tie",function(s)
	s.land_edges[1].tie_zone_id=s.land_edges[1].zone_b
end)
expect_failure("face_edge_junctions",function(s)
	s.land_edges[1].from_junction_id="changed"
end)
expect_failure("face_edge_probe_zone",function(s)
	local ref=s.zone_faces[1].cycle[1]
	ref.direction=ref.direction=="forward" and "reverse" or "forward"
end)
expect_failure("exact_count_perimeter_attachments",function(s)
	table.remove(s.perimeter_attachments,8)
end)
expect_failure("perimeter_attachment_contract",function(s)
	s.perimeter_attachments[1].retained_run="prefix"
end)
expect_failure("perimeter_attachment_contract",function(s)
	s.perimeter_attachments[1].position={x=-2490,z=-1050}
end)
expect_failure("perimeter_attachment_contract",function(s)
	s.perimeter_attachments[1].perimeter_segment_index=4
end)
expect_failure("perimeter_attachment_contract",function(s)
	s.perimeter_attachments[1].joint_station_rule="nearest_with_snap"
end)
expect_failure("zone_face_edge_ref",function(s)
	for i=1,#s.zone_faces do for j=1,#s.zone_faces[i].cycle do
		local ref=s.zone_faces[i].cycle[j]
		if ref.ref_id=="land_031" then ref.clip_attachment_id=false return end
	end end
end)
expect_failure("face_arc_component_endpoints",function(s)
	s.face_arcs[1].from_boundary_id="changed"
end)
expect_failure("face_arc_perimeter_span",function(s)
	s.face_arcs[1].authority_components[1].ref_id="perimeter_span:elandor:frostbarrow"
end)
expect_failure("bay_bank_component_incidence",function(s)
	s.face_arcs[1].authority_components[2].ref_id="bay_bank:elandor_west:copperfell"
end)
expect_failure("face_arc_bay_bank",function(s)
	s.face_arcs[1].authority_components[2].from_boundary_id="changed"
end)
expect_failure("exact_count_bay_bank_components",function(s)
	table.remove(s.bay_bank_components,20)
end)
expect_failure("exact_count_bay_edge_transitions",function(s)
	table.remove(s.bay_edge_transitions,8)
end)
expect_failure("bay_edge_transition_fields",function(s)
	s.bay_edge_transitions[1].control={{x=-1050,z=-2250}}
end)
expect_failure("bay_edge_transition_fields",function(s)
	s.bay_edge_transitions[1].candidate_tie_rule=nil
end)
expect_failure("bay_edge_transition_incidence_fields",function(s)
	s.bay_edge_transitions[1].incident_bank_component_ids=false
end)
expect_failure("bay_edge_transition_incidence_fields",function(s)
	s.bay_edge_transitions[1].incident_bank_component_ids={}
end)
expect_failure("bay_edge_transition_incidence",function(s)
	local ids=s.bay_edge_transitions[1].incident_bank_component_ids
	ids[1],ids[2]=ids[2],ids[1]
end)
expect_failure("bay_edge_transition_incidence",function(s)
	s.bay_edge_transitions[1].incident_bank_component_ids[2]=
		s.bay_edge_transitions[1].incident_bank_component_ids[1]
end)
expect_failure("bay_edge_transition_reference",function(s)
	s.bay_edge_transitions[1].bay_id="bay_missing"
end)
expect_failure("bay_edge_transition_reference",function(s)
	s.bay_edge_transitions[1].edge_id="land_999"
end)
expect_failure("bay_edge_transition_projection",function(s)
	s.bay_edge_transitions[1].edge_endpoint="from"
end)
expect_failure("bay_edge_transition_projection",function(s)
	s.bay_edge_transitions[2].edge_id="land_001"
	s.bay_edge_transitions[2].edge_endpoint="to"
end)
expect_failure("bay_edge_transition_projection",function(s)
	s.bay_bank_components[11].start_terminal.edge_id="land_009"
end)
expect_failure("bay_edge_transition_incidence",function(s)
	s.bay_bank_components[12].bay_id="bay_kragmar_east"
end)
expect_failure("bay_edge_transition_terminal_sides",function(s)
	local bank=s.bay_bank_components[12]
	bank.start_terminal,bank.end_terminal=bank.end_terminal,bank.start_terminal
end)
expect_failure("bay_edge_transition_contract",function(s)
	s.bay_edge_transitions[1].resolution_policy_id="direct_only"
end)
expect_failure("bay_edge_transition_contract",function(s)
	s.bay_edge_transitions[1].candidate_tie_rule="lexicographically_greatest_x_then_z"
end)
expect_failure("bay_edge_transition_fields",function(s)
	s.bay_edge_transitions[1].terminal_selection_policy_id=nil
end)
expect_failure("bay_edge_transition_contract",function(s)
	s.bay_edge_transitions[1].terminal_selection_policy_id="first_reachable_terminal"
end)
expect_failure("bay_edge_transition_terminal_dependency",function(s)
	s.bay_bank_components[1].start_terminal={kind="land_edge_transition",
		edge_id="land_004",edge_endpoint="from"}
end)
expect_failure("bay_aperture_transition_projection",function(s)
	s.bay_bank_components[5].end_terminal.side="before"
end)
expect_failure("bay_aperture_transition_reference",function(s)
	s.bay_bank_components[1].start_terminal.aperture_id="bay_mouth_aperture:missing"
end)
expect_failure("bay_aperture_transition_incidence",function(s)
	local first=s.bay_bank_components[1].start_terminal
	s.bay_bank_components[1].start_terminal=s.bay_bank_components[6].start_terminal
	s.bay_bank_components[6].start_terminal=first
end)
expect_failure("shared_boundary_incidence_run_scope",function(s)
	s.bay_edge_transitions[1],s.bay_edge_transitions[2]=
		s.bay_edge_transitions[2],s.bay_edge_transitions[1]
	s.bay_edge_transitions[1].numeric_id=1
	s.bay_edge_transitions[2].numeric_id=2
end)
expect_failure("shared_boundary_incidence_run_projection",function(s)
	s.bay_edge_transitions[2].edge_id="land_001"
	s.bay_bank_components[4].end_terminal.edge_id="land_001"
	s.bay_bank_components[5].start_terminal.edge_id="land_001"
	s.bay_edge_transitions[3].edge_id="land_007"
	s.bay_bank_components[6].end_terminal.edge_id="land_007"
	s.bay_bank_components[7].start_terminal.edge_id="land_007"
end)
expect_failure("shared_boundary_incidence_run_obligation",function(s)
	s.bay_edge_transitions[1].id="bay_edge_transition:land_001:to:changed"
end)
expect_failure("bay_bank_component_contract",function(s)
	s.bay_bank_components[1].direction="reverse"
end)
expect_failure("bay_bank_component_fields",function(s)
	s.bay_bank_components[1].control={{x=-980,z=-2940},{x=-1050,z=-2250}}
end)
expect_failure("bay_bank_component_contract",function(s)
	s.bay_bank_components[1].endpoint_face_incidence[2].face_arc_id=
		"face_arc:copperfell:bay"
end)
expect_failure("bay_bank_component_fields",function(s)
	s.bay_bank_components[1].extra=false
end)
expect_failure("bay_bank_terminal_fields",function(s)
	s.bay_bank_components[1].start_terminal.extra=false
end)
expect_failure("bay_bank_terminal_fields",function(s)
	s.bay_bank_components[1].end_terminal.extra=false
end)
expect_failure("bay_bank_terminal_fields",function(s)
	s.bay_bank_components[2].end_terminal.extra=false
end)
expect_failure("bay_bank_terminal_fields",function(s)
	s.bay_bank_components[1].start_terminal=false
end)
expect_failure("bay_bank_incidence_fields",function(s)
	s.bay_bank_components[1].endpoint_face_incidence=false
end)
expect_failure("bay_bank_incidence_fields",function(s)
	s.bay_bank_components[1].endpoint_face_incidence[1].extra=false
end)
expect_failure("face_arc_fields",function(s)
	s.face_arcs[1].extra=false
end)
expect_failure("face_arc_contract",function(s)
	s.face_arcs[1].authority_components=false
end)
expect_failure("face_arc_component_fields",function(s)
	s.face_arcs[3].authority_components[1].extra=false
end)
expect_failure("face_arc_component_fields",function(s)
	s.face_arcs[2].authority_components[1].extra=false
end)
expect_failure("face_arc_component_fields",function(s)
	s.face_arcs[31].authority_components[1].extra=false
end)
expect_failure("perimeter_bank_terminal_fields",function(s)
	s.face_arcs[1].authority_components[1].to_terminal.extra=false
end)
expect_failure("perimeter_bank_terminal_fields",function(s)
	s.face_arcs[3].authority_components[1].from_terminal=true
end)
expect_failure("face_arc_source_projection",function(s)
	table.remove(s.face_arcs[6].source_refs,2)
end)
expect_failure("face_arc_source_projection",function(s)
	table.insert(s.face_arcs[6].source_refs,"bay_elandor_east")
end)
expect_failure("face_arc_source_projection",function(s)
	local refs=s.face_arcs[6].source_refs
	refs[1],refs[2]=refs[2],refs[1]
end)
expect_failure("face_arc_kind_composition",function(s)
	s.face_arcs[2].kind="coast_shore"
end)
expect_failure("bay_bank_component_incidence",function(s)
	s.face_arcs[2].authority_components[1].ref_id=
		s.face_arcs[7].authority_components[1].ref_id
end)
expect_failure("bay_bank_component_incidence",function(s)
	s.face_arcs[2].authority_components[1].ref_id="bay_bank:missing"
end)
expect_failure("bay_bank_component_contract",function(s)
	s.bay_bank_components[2].end_terminal.tail_side="negative"
end)
expect_failure("bay_edge_transition_projection",function(s)
	s.bay_bank_components[1].end_terminal.edge_endpoint="from"
end)
expect_failure("bay_bank_component_contract",function(s)
	s.bay_bank_components[1].endpoint_face_incidence[1].terminal_side="end"
end)
expect_failure("bay_bank_component_contract",function(s)
	s.bay_bank_components[1].endpoint_face_incidence[2].face_arc_end="component_start"
end)
expect_failure("bay_closure_wing_junction_ref",function(s)
	s.bay_closure_wings[1].junction_edge_ids[1]="land_003"
end)
expect_failure("face_arc_perimeter_span",function(s)
	s.face_arcs[1].authority_components[1].to_terminal.side="after"
end)
expect_failure("face_arc_component_fields",function(s)
	s.face_arcs[1].authority_components[2]=false
end)
expect_failure("perimeter_span_contract",function(s)
	s.perimeter_spans[1].first_segment=2
end)
expect_failure("perimeter_span_contract",function(s)
	s.perimeter_spans[1].control={{x=-2500,z=-250},{x=-2490,z=-1050}}
end)
expect_failure("exact_source_checksum",function(s)
	s.zone_faces[1]["simple_".."after_exact_outer_clip"]=true
end)
expect_failure("exact_source_checksum",function(s)
	s.zone_faces[1].preview_overlap_waiver=true
end)
expect_failure("face_arc_sole_geometry_authority",function(s)
	s.bays[1].geometry_authority="zone_face_cycle_segments"
end)
expect_failure("perimeter_component_ref",function(s)
	s.perimeters[1].ordered_outer_components[1]=
		"face_arc:stormvault:coast#1-2:forward"
end)
expect_failure("perimeter_component_coverage",function(s)
	table.remove(s.perimeters[1].ordered_outer_components,1)
end)
expect_failure("bay_owner_spans",function(s)
	s.bays[1].owner_spans[2].first_segment=3
end)
expect_failure("bay_owner_spans",function(s)
	s.bays[1].owner_spans[1].left_zone_id="front_broken_causeway"
end)
expect_failure("bay_mouth_perimeter_incidence",function(s)
	s.bays[1].perimeter_projection.mouth_vertex_index=11
end)
expect_failure("exact_count_bay_mouth_apertures",function(s)
	table.remove(s.bay_mouth_apertures,4)
end)
expect_failure("bay_mouth_aperture_contract",function(s)
	s.bay_mouth_apertures[1].before_span_id="perimeter_span:elandor:copperfell"
end)
expect_failure("bay_mouth_aperture_fields",function(s)
	s.bay_mouth_apertures[1].analytic_cross_section_width=719
end)
expect_failure("bay_mouth_aperture_fields",function(s)
	s.bay_mouth_apertures[1].control={{x=-980,z=-2940}}
end)
expect_failure("bay_mouth_aperture_contract",function(s)
	s.bays[1].mouth_aperture_id="bay_mouth_aperture:elandor_east"
end)
expect_failure("exact_count_bay_closure_wings",function(s)
	table.remove(s.bay_closure_wings,8)
end)
expect_failure("bay_closure_wing_literal",function(s)
	s.bay_closure_wings[1].junction.x=-1399
end)
expect_failure("bay_closure_wing_literal",function(s)
	s.bay_closure_wings[1].head_sample_index=3
end)
expect_failure("bay_closure_wing_literal",function(s)
	s.bay_closure_wings[1].tie_zone_id="elandor_whitebridge_shire"
end)
expect_failure("bay_closure_wing_literal",function(s)
	local wing=s.bay_closure_wings[1]
	wing.left_probe,wing.right_probe=wing.right_probe,wing.left_probe
end)
expect_failure("bay_closure_wing_coverage",function(s)
	s.bays[1].closure_wing_ids[1],s.bays[1].closure_wing_ids[2]=
		s.bays[1].closure_wing_ids[2],s.bays[1].closure_wing_ids[1]
end)
expect_failure("face_arc_sole_geometry_authority",function(s)
	s.islands[1].closed_arc_id="face_arc:stormscale:island"
end)
expect_failure("island_target_anchor_mode",function(s)
	local anchor=s.anchors[87]
	anchor.placement_mode="candidate_set"
	anchor.candidates={{x=anchor.position.x,z=anchor.position.z}}
	anchor.position=nil
end)
expect_failure("rare_patrol_absolute_forbidden",function(s)
	s.anchors[91].patrol_route={{x=0,z=0},{x=1,z=1}}
end)
expect_failure("rare_patrol_coordinate_space",function(s)
	s.anchors[91].patrol_coordinate_space="candidate_one_relative"
end)
expect_failure("poi_spur_contract",function(s)
	s.poi_spurs[1].class="trail"
end)
expect_failure("poi_spur_target_zone",function(s)
	s.poi_spurs[1].target_route_id="route_004"
	s.poi_spurs[1].target_station_id=s.routes[4].station_a_id
	s.poi_spurs[1].target_interface_id=s.routes[4].endpoint_a_id
end)
expect_failure("poi_spur_candidate_origin",function(s)
	s.poi_spurs[1].candidate_paths[1][1].x=1
end)
expect_failure("poi_spur_world_terminus",function(s)
	s.poi_spurs[1].candidate_paths[2][3].x=
		s.poi_spurs[1].candidate_paths[2][3].x+1
end)
expect_failure("route_class_profile",function(s)
	s.route_classes[1].max_grade.denominator=11
end)
expect_failure("route_interface_grade",function(s)
	s.route_interfaces[1].grade_phase="unbound"
end)
expect_failure("route_crossing_grade_policy",function(s)
	s.route_crossing_interfaces[1].hard_protected=true
end)
expect_failure("route_crossing_grade_policy",function(s)
	s.route_crossing_interfaces[1].vertical_rule_id="ford_bed_v1"
end)
expect_failure("geometry_policy_contract",function(s)
	s.geometry_policies.relief_composition.landmark_priority_tie="first"
end)
expect_failure("geometry_policy_contract",function(s)
	s.geometry_policies.relief_composition.landmark_priority_order=
		"smaller_integer_priority_wins"
end)
expect_failure("logical_biome_selector_contract",function(s)
	s.geometry_policies.logical_biome_selector.cell_size=1
end)
expect_failure("logical_biome_selector_fields",function(s)
	s.geometry_policies.logical_biome_selector.seed_input=nil
end)
expect_failure("generic_geometry_policy_contract",function(s)
	s.geometry_policies.primitive_evaluator.apply_rule="first_wins"
end)
expect_failure("primitive_axis_frame_policy",function(s)
	s.geometry_policies.primitive_evaluator.axis_frame.zero_segment_rule="use_zero"
end)
expect_failure("primitive_axis_frame_policy",function(s)
	s.geometry_policies.primitive_evaluator.initial_accumulator_q16=1
end)
expect_failure("primitive_rim_continuity",function(s)
	s.geometry_policies.primitive_formulas.formulas[6].formula_id=
		"primitive_rim_q16_v1"
end)
expect_failure("primitive_terrace_continuity",function(s)
	s.geometry_policies.primitive_formulas.formulas[3].support=
		"euclidean_radius_rings_times_step_run"
end)
expect_failure("generic_geometry_policy_contract",function(s)
	s.geometry_policies.primitive_formulas.formulas[9].base_rule="center_sample"
end)
expect_failure("generic_geometry_policy_contract",function(s)
	s.geometry_policies.boundary_displacement.hash_lanes.fine=2
end)
expect_failure("generic_geometry_policy_contract",function(s)
	s.geometry_policies.route_raster.major_axis_rule="z_tie"
end)
expect_failure("route_raster_reversal_policy",function(s)
	s.geometry_policies.route_raster.canonical_endpoint_order="authored"
end)
expect_failure("generic_geometry_policy_contract",function(s)
	s.geometry_policies.route_profile_solver.cost_tuple[1]="total_earthwork"
end)
expect_failure("route_profile_solver_policy",function(s)
	s.geometry_policies.route_profile_solver.earthwork_rule=
		"absolute_candidate_y_minus_H"
end)
expect_failure("route_profile_solver_policy",function(s)
	s.geometry_policies.route_profile_solver.world_column_membership=
		"absolute_lateral_less_equal_half_width"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.boundary_blend_width=95
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.nearest_edge_distance=
		"nearest_raster_station"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.raw_height_delta=
		"inclusive_value_count"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.raw_noise_input=
		"assume_noise_already_clamped"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.junction_zero_weight_rule=
		"divide_all_candidates"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.junction_candidate_eligibility=
		"nonnegative_weight"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.junction_candidate_edge_dedup=
		"one_candidate_per_junction_edge_pair"
end)
expect_failure("relief_shared_gate_policy",function(s)
	s.geometry_policies.relief_field.junction_endpoint_support_proof=
		"assume_supports_do_not_overlap"
end)
expect_failure("relief_edge_gate_authority",function(s)
	s.land_edges[11].gate_min_above_water=39
end)
expect_failure("landmark_mask_policy",function(s)
	s.geometry_policies.landmark_masks.blend_width=63
end)
expect_failure("landmark_mask_policy",function(s)
	s.geometry_policies.landmark_masks.ellipse_signed_distance=
		"rho_q16_minus_Q"
end)
expect_failure("coastal_core_policy",function(s)
	s.geometry_policies.coastal_housing_core.inland_depth=299
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.classification_precedence[1]=
		"dry_zone_face_partition"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_policy_id=
		"iterative_dry_leaf_fill"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_input=
		"read_the_already_filled_final_mask"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_scope=
		"permit_mouth_aperture_equality"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_enumeration=
		"scan_only_the_left_endpoint_of_each_raw_row"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_predicate=
		"three_cardinal_same_bay_water_neighbours_only"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_application=
		"repeat_until_no_dry_leaf_remains"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_owner=
		"copy_the_first_neighbour_owner"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_precedence=
		"fill_before_footprint_and_aperture_clipping"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_safe_arithmetic=
		"raw_coordinate_plus_direction"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_stage=
		"repair_faces_after_bank_materialization"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_notch_fill_payload=
		"each_consumer_recomputes_the_fill_from_its_face"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_candidate=
		"same_bay_Base_or_Wing_neighbour_only"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.strict_exterior_rule=
		"outside_every_final_mainland_and_island"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.coast_source_allowed_component_ids[19]=
		"face_arc:wyrmglass:island"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.coast_source_tie_rule=
		"first_component_iteration_order"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_mask_membership=
		"squared_distance_less_than_or_equal_width_squared"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_owner_segment_tie=
		"exact_equal_rational_distance_then_lower_segment_index"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_displacement_lanes={left=0,right=1}
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_displacement_projection_station=
		"rounded_parametric_projection"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_wing_k_set=
		"directed_trace_occurrence"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_edge_transition_identity=
		"nearest_dry_then_snap"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_nonwing_terminal_resolution=
		"raw_clipped_endpoint_only"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_nonwing_start_half_edge=
		"first_neighbor"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_aperture_terminal_order=
		"canonical_deduplicated_final_perimeter_integer_raster_order"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_aperture_transition_policy_id=
		"direct_aperture_only"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_aperture_transition_side=
		"always_test_D_to_T"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_aperture_transition_elbows=
		"select_first_valid_elbow"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_water_side=
		"test_the_resolved_start_anchor_previous_to_current"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_branch_rule=
		"require_exactly_one_terminal_reachable_successor"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_reachability_bound=
		"unbounded_recursive_search"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_tail_pair_selection=
		"lexicographically_least_structural_pair_before_wedge_validation"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_tail_wedge_polygon=
		"raster_the_closing_chord"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_tail_wedge_radius=
		"unbounded_polygon_bbox"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_tail_wedge_scan=
		"exempt_every_chord_station"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_tail_wedge_chord=
		"serialize_the_analysis_chord"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.bay_bank_reject=
		"fall_back_to_the_old_lex_first_pair"
end)
expect_failure("world_partition_policy",function(s)
	s.geometry_policies.world_partition.raw_dry_multiplicity_rule=
		"exactly_one_outside_strict_final_bay_masks_at_least_one_inside"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.shared_boundary_attachment_rule=
		"nearest_perimeter_station_then_snap"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_policy_id=
		"direct_candidate_only"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_elbows=
		"choose_first_iteration_order"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_diagonal_precondition=
		"W_is_water_only_before_notch_fill"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_scalar_scope=
		"score_the_elbow_as_a_new_scalar_row"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_mask_source=
		"select_against_raw_water_then_revalidate_after_fill"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_policy_id=
		"first_reachable_transition_terminal"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_candidates=
		"scan_from_endpoint_until_first_candidate"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_dependency=
		"permit_chained_edge_transition_banks"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_complete=
		"trace_only_one_incident_bank"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_selection=
		"select_endpoints_independently"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_application=
		"reraster_after_terminal_selection"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_bounds=
		"unbounded_cartesian_search"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_reversal=
		"reselect_after_reverse"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.bay_edge_transition_terminal_reject=
		"backstep_to_previous_candidate"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.shared_boundary_incidence_run_selection=
		"select_longest_then_first"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.shared_boundary_incidence_run_obligations=
		"resolve_endpoints_after_run_selection"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.shared_boundary_incidence_control_clip=
		"recompute_scalars_for_retained_controls"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.shared_boundary_incidence_excluded_dry=
		"discard_without_owner_validation"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.no_jitter_metric=
		"euclidean_world_distance"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.control_taper_metadata=
		"rederive_from_whole_polyline"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.clip_loop_rule=
		"scan_full_integer_record_range"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.component_rounding=
		"round_normal_and_scalar_before_multiply"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.final_raster_rule=
		"emit_shifted_base_stations_directly"
end)
expect_failure("base_raster_repeat",function(s)
	s.land_edges[1].control={{x=0,z=0},{x=4,z=2},{x=0,z=3}}
end)
expect_failure("base_raster_x_cross",function(s)
	s.land_edges[1].control={{x=0,z=0},{x=1,z=1},{x=0,z=1},{x=1,z=0}}
end)
expect_failure("base_raster_envelope",function(s)
	local changed={x=-3451,z=-260}
	s.islands[1].polygon[2]=changed
	for i=1,#s.face_arcs do
		if s.face_arcs[i].id=="face_arc:wyrmglass:island" then
			s.face_arcs[i].authority_components[1].control[2]=changed
		end
	end
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.topology_ceiling_candidate_order=
		"binary_search_assuming_monotone_validity"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.junction_departure_application=
		"append_after_final_raster"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.junction_departure_safe_arithmetic=
		"subtract_unchecked_then_take_sign"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.island_coast_envelope_predicate=
		"authored_island_ellipse"
end)
expect_failure("channel_strict_exterior_contract",function(s)
	s.channels[1].membership_rule="caller_supplied_planned_water_precedence"
end)
expect_failure("geometry_fixture_selector_policy",function(s)
	s.geometry_policies.geometry_fixture_selector.classes[7].predicate_id=""
end)
expect_failure("geometry_fixture_selector_policy",function(s)
	s.geometry_policies.geometry_fixture_selector.candidate_max=40
end)
expect_failure("requester_trace_policy",function(s)
	s.geometry_policies.requester_trace.road_profile_family_ids[3]="rare_patrols"
end)
expect_failure("requester_trace_policy",function(s)
	s.geometry_policies.requester_trace.active_tick_last=3334
end)
expect_failure("geometry_extreme_selector_policy",function(s)
	s.geometry_policies.geometry_extreme_selector.normalization_denominator=
		"local_damped_amplitude_times_Q"
end)
expect_failure("geometry_extreme_selector_policy",function(s)
	s.geometry_policies.geometry_extreme_selector.selected_stage2_rule=
		"fallback_to_next_candidate"
end)
expect_failure("geometry_extreme_selector_policy",function(s)
	s.geometry_policies.geometry_extreme_selector.sample_sequence=
		"final_displaced_reraster_stations"
end)
expect_failure("geometry_extreme_selector_policy",function(s)
	s.geometry_policies.geometry_extreme_selector.coast_mainland_overlap_rule=
		"score_each_perimeter_span_independently"
end)
expect_failure("geometry_extreme_selector_policy",function(s)
	s.geometry_policies.geometry_extreme_selector.scalar_stage=
		"post_local_clip_pre_topology_ceiling"
end)
expect_failure("geometry_extreme_selector_policy",function(s)
	s.geometry_policies.geometry_extreme_selector.attachment_rule=
		"discard_every_source_control_outside_the_final_interval"
end)
expect_failure("generic_geometry_policy_contract",function(s)
	s.geometry_policies.hydrology_mask.bank_skirt_horizontal_nodes=3
end)
expect_failure("hydrology_mask_policy",function(s)
	s.geometry_policies.hydrology_mask.rapid_run_interval="downstream_only"
end)
expect_failure("route_vertical_interface_policy",function(s)
	s.geometry_policies.route_vertical_interfaces.bridge.minimum_clearance_nodes=2
end)
expect_failure("template_primitive_parameters",function(s)
	s.template_primitives[1].parameters[1]="generic_degree"
end)
expect_failure("primitive_rim_parameters",function(s)
	s.template_compositions[6].operations[2].parameters.peak_radius=256
end)
expect_failure("primitive_axis_source",function(s)
	s.template_compositions[13].operations[1].axis_source="world_x"
end)
expect_failure("landmark_base_h_contract",function(s)
	s.landmarks[2].base_h_priority=1
end)
expect_failure("hydrology_profile_contract",function(s)
	s.hydrology_profiles[1].bed_seal_layers=2
end)
expect_failure("hydrology_transition_profile",function(s)
	s.hydrology_transition_profiles[1].open_face=nil
end)
expect_failure("hydrology_transition_vertical",function(s)
	s.hydrology_transition_profiles[2].minimum_clearance_nodes=2
end)
expect_failure("rapid_interface",function(s)
	s.hydrology_interfaces[4].lower_level_offset=67
end)
expect_failure("waterfall_dimensions",function(s)
	s.hydrology_interfaces[5].plunge_width=0
end)
expect_failure("confluence_incidence",function(s)
	s.hydrology_interfaces[1].position.x=200
end)
expect_failure("hard_protection_recipe",function(s)
	s.hard_protection_recipes[1].total_width=531
end)
expect_failure("hard_protection_active",function(s)
	s.hard_protection[1].active=false
end)
expect_failure("hard_protection_recipe",function(s)
	s.hard_protection_recipes[3].y_policy_id="socket_node_y_from_t2"
end)
expect_failure("hard_protection_recipe",function(s)
	s.hard_protection_recipes[3].y_min=-699
end)
expect_failure("pending_recipe_contract",function(s)
	s.pending_static_recipes[1].total_width=64
end)
expect_failure("pending_reservation_contract",function(s)
	s.pending_static_reservations[1].active=true
end)
expect_failure("pending_reservation_contract",function(s)
	s.pending_static_reservations[9].position={x=0,z=0}
end)
expect_failure("pending_reservation_contract",function(s)
	s.pending_static_reservations[#s.pending_static_reservations].yield=1
end)
expect_failure("pending_containment",function(s)
	s.pending_static_reservations[1].containment_exclusion_ids=nil
end)
expect_failure("pending_containment",function(s)
	s.pending_static_reservations[9].containment_exclusion_ids[1]=
		"exclude:anchor:anchor_002:01"
end)
expect_failure("pending_recipe_contract",function(s)
	s.pending_static_recipes[2].radius=32
end)
expect_failure("claim_exclusion_contract",function(s)
	s.claim_exclusions[1].total_width=s.claim_exclusions[1].total_width-1
end)
expect_failure_at("claim_exclusion_missing","exclude:anchor:anchor_001:01",function(s)
	s.claim_exclusions[1].id="unexpected:first"
	s.claim_exclusions[#s.claim_exclusions].id="unexpected:last"
end)
expect_failure("apex_socket_offset_unique",function(s)
	local sockets=s.anchors[89].socket_reservations
	sockets[2].offset.x=sockets[1].offset.x
	sockets[2].offset.z=sockets[1].offset.z
	sockets[2].position.x=sockets[1].position.x
	sockets[2].position.z=sockets[1].position.z
end)
expect_failure("apex_socket_reservation",function(s)
	s.anchors[89].socket_reservations[1].active=false
end)
expect_failure("hard_apex_socket",function(s)
	s.hard_protection[13].resource_key="ruby"
end)
expect_failure("surface_level_bracket",function(s)
	s.surface_level_controls[1].level=11
end)
expect_failure("surface_level_gate_agreement",function(s)
	s.surface_level_controls[38+2*34+1].level=40
end)
expect_failure("surface_level_endgame_exception",function(s)
	s.surface_level_controls[38+2*42+1].endgame_exception=false
end)
expect_failure("closed_semantic_vocabulary",function(s)
	s.semantics.hydrology_profile_ids[1]="unknown"
end)
end

if arg._wp40_phase.enabled("exact_source_seam") then
	local ok,failure=stage1.validate(source,vocabulary)
	assert(not ok and failure.invariant=="exact_source_seam")
end
if arg._wp40_phase.enabled("forged_canonical_rejection") then
	local corrupt=clone(source)
	corrupt.zones[1].display_name="forged canonical repro"
	local forged_canonical={}
	for _,name in ipairs({"text","signed","boolean","array","map","hex"}) do
		forged_canonical[name]=canonical[name]
	end
	function forged_canonical.checksum()
		return from_hex(EXPECTED_SOURCE_CHECKSUM)
	end
	local ok,failure=production_stage1.validate(corrupt,vocabulary,forged_canonical,
		raw_sha256)
	assert(not ok and failure.invariant=="exact_source_checksum",
		"well-formed forged canonical bypassed production validate")
end
if arg._wp40_phase.enabled("forged_digest_rejection") then
	local corrupt=clone(source)
	corrupt.zones[1].display_name="forged digest repro"
	local function forged_raw_sha256()
		return from_hex(EXPECTED_SOURCE_CHECKSUM)
	end
	local ok,failure=production_stage1.validate(corrupt,vocabulary,canonical,
		forged_raw_sha256)
	assert(not ok and failure.invariant=="exact_source_checksum",
		"well-formed forged digest bypassed production validate")
end
if arg._wp40_phase.enabled("forged_projector_rejection") then
	local corrupt=clone(source)
	corrupt.zones[1].display_name="forged exported projector repro"
	local original_export=production_stage1.canonicalize_source
	production_stage1.canonicalize_source=function()
		return stage1.canonicalize_source(source,canonical)
	end
	local ok,failure=production_stage1.validate(corrupt,vocabulary)
	production_stage1.canonicalize_source=original_export
	assert(not ok and failure.invariant=="exact_source_checksum",
		"mutable exported projector replaced private production authority")
end
if arg._wp40_phase.enabled("canonical_source_identity") then
for iteration=1,200 do
	local copy=clone(source)
	local invalid={}
	if iteration%2==0 then invalid[false]=1 invalid[function() end]=2
	else invalid[function() end]=2 invalid[false]=1 end
	copy.constants.invalid_keys=invalid
	local ok,failure=offline.validate(copy,vocabulary)
	assert(not ok and failure.invariant=="source_graph_key_type" and
		failure.observed=="boolean:false","invalid-key diagnostic order drift")
end

assert(canonical.encode(stage1.canonicalize_source({roles={}},canonical))==
	canonical.encode(canonical.map({{canonical.text("roles"),canonical.array({})}})),
	"schema-declared empty array encoded as map")
assert(canonical.encode(stage1.canonicalize_source(
	{incident_bank_component_ids={}},canonical))==
	canonical.encode(canonical.map({{canonical.text("incident_bank_component_ids"),
		canonical.array({})}})),
	"transition incident-bank empty array encoded as map")
assert(canonical.encode(stage1.canonicalize_source({parameters={}},canonical))==
	canonical.encode(canonical.map({{canonical.text("parameters"),canonical.map({})}})),
	"schema-declared empty map encoded as array")

local bytes_a = canonical.encode(stage1.canonicalize_source(source,canonical))
local bytes_b = canonical.encode(stage1.canonicalize_source(dofile(wp40 .. "/source/catalog.lua"),canonical))
assert(bytes_a == bytes_b, "canonical source bytes changed between loads")
local checksum_a = canonical.hex(canonical.checksum(stage1.canonicalize_source(source,canonical),raw_sha256))
local checksum_b = canonical.hex(canonical.checksum(stage1.canonicalize_source(
	dofile(wp40 .. "/source/catalog.lua"),canonical),raw_sha256))
assert(checksum_a == checksum_b, "canonical source checksum is not deterministic")
local forbidden_force = clone(source)
forbidden_force.templates[1].force_native_dungeon = true
local forbidden_bytes=canonical.encode(stage1.canonicalize_source(forbidden_force,canonical))
assert(forbidden_bytes ~= bytes_a,
	"native-dungeon force policy is absent from canonical source bytes")
local forbidden_checksum = canonical.hex(canonical.checksum(
	stage1.canonicalize_source(forbidden_force,canonical),raw_sha256))
assert(forbidden_checksum ~= checksum_a,
	"native-dungeon force policy is not checksum-covered")
local changed_manifest=clone(source)
changed_manifest.critical_source_manifest.water_level=0
local changed_manifest_bytes=canonical.encode(
	stage1.canonicalize_source(changed_manifest,canonical))
assert(changed_manifest_bytes~=bytes_a,
	"critical source manifest is absent from canonical source bytes")
local changed_manifest_checksum=canonical.hex(canonical.checksum(
	stage1.canonicalize_source(changed_manifest,canonical),raw_sha256))
assert(changed_manifest_checksum~=checksum_a,
	"critical source manifest is not checksum-covered")
assert(checksum_a == EXPECTED_SOURCE_CHECKSUM,
	"authored source checksum changed without an explicit fixture update: "..checksum_a)

print(("WP40 T2 source passed: 38 zones, 61 land edges / 57 routes (30/24/3), " ..
	"4 boat edges, 70 landmarks, 100 anchors, checksum %s"):format(checksum_a))
end
arg._wp40_phase.finish()
