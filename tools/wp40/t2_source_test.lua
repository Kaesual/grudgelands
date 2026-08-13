local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

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

local sha_counter = 0
local function from_hex(value)
	return (value:gsub("..", function(pair) return string.char(assert(tonumber(pair,16))) end))
end
local function raw_sha256(data)
	sha_counter = sha_counter + 1
	local input = scratch .. "/source-" .. sha_counter .. ".bin"
	local output = scratch .. "/source-" .. sha_counter .. ".sha"
	local file = assert(io.open(input,"wb")) assert(file:write(data)) assert(file:close())
	assert(os.execute("sha256sum " .. input .. " > " .. output) == 0)
	file = assert(io.open(output,"rb")) local line=assert(file:read("*l")) assert(file:close())
	return from_hex(assert(line:match("^([0-9a-f]+)")))
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

local EXPECTED_SOURCE_CHECKSUM="5f0cd9afbb56c03a4f69a5d20648e4bc27ed256311ae37bee70e08d5d2d7d0d0"
assert(stage1.EXPECTED_SOURCE_CHECKSUM==EXPECTED_SOURCE_CHECKSUM,
	"production and independent source KAT differ")
assert(production_stage1.EXPECTED_SOURCE_CHECKSUM==EXPECTED_SOURCE_CHECKSUM,
	"bound production source KAT differs")
local offline=assert(stage1.new_offline_test_adapter,
	"offline Stage1 adapter missing")(canonical,raw_sha256)

local function assert_valid(value, vocab)
	local ok, failure = offline.validate(value, vocab)
	assert(ok, failure and (failure.invariant .. ":" .. tostring(failure.record_id)..":"..tostring(failure.observed)))
end

assert_valid(source, vocabulary)
do
	local ok,failure=production_stage1.validate(source,vocabulary)
	assert(ok,failure and failure.invariant)
end

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
	#source.perimeter_attachments==8 and #source.perimeter_spans==18 and #source.routes==57 and
	#source.bay_mouth_apertures==4 and
	#source.boat_edges == 4 and #source.landmarks == 70 and
	#source.anchors == 100)
assert(#source.face_arcs==34 and #source.zone_faces==38 and
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

-- Slow semantic oracles deliberately iterate ID maps in reverse source order.
-- Production remains an ordered/KAT source; these checks prove that face and
-- spur authority do not secretly depend on array iteration.
do
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
do
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

-- Exhaustive integer-column audit around all four final bay footprints. The
-- outer perimeter is independent authority: every interior column in a bay
-- neighbourhood must be covered by either a dry face, the unchanged analytic
-- base capsule, or one of its two exact tapered closure wings. This catches
-- literal face/water cavities before displaced-corpus testing in Stage 2.
do
	local edge_by_id,arc_by_id,face_by_zone,perimeter_by_id={},{},{},{}
	for i=1,#source.land_edges do edge_by_id[source.land_edges[i].id]=source.land_edges[i] end
	for i=1,#source.face_arcs do arc_by_id[source.face_arcs[i].id]=source.face_arcs[i] end
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
	local clipped_edge_point_set,clipped_edge={},{}
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
	local attachment_perimeter_station={}
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
		attachment_perimeter_station[attachment_id]=best
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
		clipped_edge[attachment.edge_id]=final_points
		local point_set={} clipped_edge_point_set[attachment.edge_id]=point_set
		for i=1,#final_points do
			point_set[final_points[i].x..":"..final_points[i].z]=true
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
	local span_by_id={}
	for i=1,#source.perimeter_spans do span_by_id[source.perimeter_spans[i].id]=source.perimeter_spans[i] end
	local function boundary_point(boundary)
		if boundary.kind=="perimeter_attachment" then
			return attachment_perimeter_station[boundary.attachment_id]
		end
		return perimeter_by_id[boundary.perimeter_id].polygon[boundary.index]
	end
	local function materialize_span(span)
		local stations=perimeter_stations_by_id[span.perimeter_id]
		local lookup=perimeter_station_lookup[span.perimeter_id]
		local first_point,last_point=boundary_point(span.start_boundary),
			boundary_point(span.end_boundary)
		local first_index=assert(lookup[first_point.x..":"..first_point.z],
			span.id.." missing first "..first_point.x..":"..first_point.z)
		local last_index=assert(lookup[last_point.x..":"..last_point.z],
			span.id.." missing last "..last_point.x..":"..last_point.z)
		assert(first_index<=last_index,"symbolic perimeter span must not wrap")
		local points={}
		for index=first_index,last_index do points[#points+1]=stations[index] end
		if span.face_direction=="reverse" then local reversed={}
			for i=#points,1,-1 do reversed[#reversed+1]=points[i] end
			return reversed
		end
		return points
	end
	local function materialize_arc(arc)
		local points={}
		for i=1,#arc.authority_components do local component=arc.authority_components[i]
			local part=component.kind=="perimeter_span" and
				materialize_span(span_by_id[component.ref_id]) or component.control
			if #points>0 then assert(points[#points].x==part[1].x and
				points[#points].z==part[1].z,"face arc authority components do not join") end
			for j=1,#part do if #points==0 or j>1 then points[#points+1]=part[j] end end
		end
		return points
	end
	for i=1,#source.zone_faces do local face=source.zone_faces[i]
		local polygon={}
		for ref_index=1,#face.cycle do local ref=face.cycle[ref_index]
			local points
			if ref.kind=="shared_edge" then
				local edge=edge_by_id[ref.ref_id]
				local base=clipped_edge[ref.ref_id] or edge.control points={}
				if ref.direction=="forward" then for j=1,#base do
					points[#points+1]=base[j] end
				else for j=#base,1,-1 do points[#points+1]=base[j] end end
			else points=materialize_arc(arc_by_id[ref.ref_id]) end
			if #polygon>0 then assert(polygon[#polygon].x==points[1].x and
				polygon[#polygon].z==points[1].z,"zone face authority components do not join") end
			for j=1,#points do if #polygon==0 or j>1 then
				polygon[#polygon+1]=points[j] end end
		end
		assert(polygon[#polygon].x==polygon[1].x and polygon[#polygon].z==polygon[1].z,
			"zone face authority cycle does not close exactly")
		face_by_zone[face.zone_id]=polygon
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
	local perimeter_dry_owner={}
	for perimeter_id in pairs(perimeter_by_id) do perimeter_dry_owner[perimeter_id]={} end
	for span_index=1,#source.perimeter_spans do local span=source.perimeter_spans[span_index]
		local points=raster_polyline(materialize_span(span))
		local lookup=perimeter_station_lookup[span.perimeter_id]
		for station_index=1,#points do local point=points[station_index] local key=point.x..":"..point.z
			if lookup[key] then local row=perimeter_dry_owner[span.perimeter_id][key] or {}
				perimeter_dry_owner[span.perimeter_id][key]=row row[#row+1]=span.zone_id
			end
		end
	end
	-- The two mainland footprints close on the authored Holy shared-edge
	-- chain.  Those equality stations use that existing shared authority,
	-- not a synthetic coast span.
	for edge_index=1,#source.land_edges do local edge=source.land_edges[edge_index]
		local points=clipped_edge[edge.id] or raster_polyline(edge.control)
		for perimeter_id,lookup in pairs(perimeter_station_lookup) do
			if perimeter_dry_owner[perimeter_id] then
				for station_index=1,#points do local point=points[station_index]
					local key=point.x..":"..point.z
					if lookup[key] then perimeter_dry_owner[perimeter_id][key]={edge.tie_zone_id} end
				end
			end
		end
	end
	for attachment_id,point in pairs(attachment_perimeter_station) do local attachment=attachment_by_id[attachment_id]
		perimeter_dry_owner[attachment.perimeter_id][point.x..":"..point.z]=
			{edge_by_id[attachment.edge_id].tie_zone_id}
	end
	local function perimeter_equality_owner(perimeter_id,x,z)
		local candidates=perimeter_dry_owner[perimeter_id][x..":"..z]
		if not candidates then return nil end
		local owner=candidates[1]
		for i=2,#candidates do if zone_numeric[candidates[i]]<zone_numeric[owner] then
			owner=candidates[i]
		end end
		return owner
	end
	local function point_on_edge(x,z,edge)
		for i=1,#edge.control-1 do local a,b=edge.control[i],edge.control[i+1]
			if (b.x-a.x)*(z-a.z)-(b.z-a.z)*(x-a.x)==0 and
				x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x) and
				z>=math.min(a.z,b.z) and z<=math.max(a.z,b.z) then return true end
		end
		return false
	end
	local function declared_dry_equality(x,z,zone_ids)
		local declared={}
		for i=1,#source.land_edges do local edge=source.land_edges[i]
			if point_on_edge(x,z,edge) or
					(clipped_edge_point_set[edge.id] and clipped_edge_point_set[edge.id][x..":"..z]) then
				declared[edge.left_zone]=true declared[edge.right_zone]=true
			end
		end
		if next(declared)==nil then return false end
		for i=1,#zone_ids do if not declared[zone_ids[i]] then return false end end
		return true
	end
	local function ceil_div(n,d) return -math.floor(-n/d) end
	local function polygon_scanlines(polygon,zone_id)
		local rows={}
		for i=1,#polygon-1 do local a,b=polygon[i],polygon[i+1]
			if a.z==b.z then
				local row=rows[a.z] or {crossings={},horizontal={}}
				rows[a.z]=row row.horizontal[#row.horizontal+1]={math.min(a.x,b.x),math.max(a.x,b.x)}
			else
				local first_z,last_z=math.min(a.z,b.z),math.max(a.z,b.z)-1
				for z=first_z,last_z do
					local denominator=b.z-a.z
					local numerator=a.x*denominator+(z-a.z)*(b.x-a.x)
					if denominator<0 then numerator,denominator=-numerator,-denominator end
					local row=rows[z] or {crossings={},horizontal={}}
					rows[z]=row row.crossings[#row.crossings+1]={numerator,denominator}
				end
			end
		end
		local result={}
		for z,row in pairs(rows) do
			table.sort(row.crossings,function(a,b) return a[1]*b[2]<b[1]*a[2] end)
			assert(#row.crossings%2==0,"odd exact polygon scanline crossing count: "..
				tostring(zone_id).." z="..z.." crossings="..#row.crossings)
			local intervals=row.horizontal
			for i=1,#row.crossings,2 do local left,right=row.crossings[i],row.crossings[i+1]
				local first,last=ceil_div(left[1],left[2]),math.floor(right[1]/right[2])
				if first<=last then intervals[#intervals+1]={first,last} end
			end
			table.sort(intervals,function(a,b) return a[1]<b[1] or a[1]==b[1] and a[2]<b[2] end)
			local merged={}
			for i=1,#intervals do local interval=intervals[i] local previous=merged[#merged]
				if previous and interval[1]<=previous[2]+1 then previous[2]=math.max(previous[2],interval[2])
				else merged[#merged+1]={interval[1],interval[2]} end
			end
			result[z]=merged
		end
		return result
	end
	local face_scanlines={}
	for zone_id,polygon in pairs(face_by_zone) do face_scanlines[zone_id]=polygon_scanlines(polygon,zone_id) end
	local function intervals_contain(intervals,x)
		if not intervals then return false end
		for i=1,#intervals do if x>=intervals[i][1] and x<=intervals[i][2] then return true end end
		return false
	end
	local function point_in_face(zone_id,x,z)
		return intervals_contain(face_scanlines[zone_id][z],x)
	end
	for bay_index,fixture in ipairs({
		{-980,-1920,-980,-1921},{1020,-1910,1020,-1911},
		{-1060,1930,-1060,1931},{900,1900,900,1901},
	}) do local bay=source.bays[bay_index]
		assert(not point_in_base_bay(fixture[1],fixture[2],bay) and
			point_in_base_bay(fixture[3],fixture[4],bay),
			"bay strict dry-boundary/head-interior KAT drift: "..bay.id)
	end
	for _,fixture in ipairs({
		{1,-896,-2053},{2,1252,-2866},{2,771,-2398},{2,1101,-2222},{4,787,2286},
	}) do
		assert(not point_in_base_bay(fixture[2],fixture[3],source.bays[fixture[1]]),
			"exact rational Bay divergence golden became water")
	end
	local gap_summaries={}
	for bay_index=1,#source.bays do local bay=source.bays[bay_index]
		local gap_count,overlap_count,wing_overlap_count,owner_failure_count,
			first_gap,first_overlap,gap_min_x,gap_max_x,gap_min_z,gap_max_z=0,0,0,0
		local gap_bands={}
		local min_x,max_x,min_z,max_z
		for i=1,#bay.centreline do local p=bay.centreline[i]
			min_x=math.min(min_x or p.x-p.half_width,p.x-p.half_width)
			max_x=math.max(max_x or p.x+p.half_width,p.x+p.half_width)
			min_z=math.min(min_z or p.z-p.half_width,p.z-p.half_width)
			max_z=math.max(max_z or p.z+p.half_width,p.z+p.half_width)
		end
		for i=1,#wings_by_bay[bay.id] do local wing=wings_by_bay[bay.id][i]
			min_x=math.min(min_x,wing.junction.x,wing.head.x-wing.head_half_width)
			max_x=math.max(max_x,wing.junction.x,wing.head.x+wing.head_half_width)
			min_z=math.min(min_z,wing.junction.z,wing.head.z-wing.head_half_width)
			max_z=math.max(max_z,wing.junction.z,wing.head.z+wing.head_half_width)
		end
		local perimeter=perimeter_by_id[bay.perimeter_projection.perimeter_id].polygon
		for z=min_z,max_z do for x=min_x,max_x do
			if point_in_polygon(x,z,perimeter) then
				local under_any_bay=false
				local water_owner
				for other_index=1,#source.bays do local other=source.bays[other_index]
					if other.continent==bay.continent and point_in_final_bay(x,z,other) then
						under_any_bay=true
						local owner,wing_count=final_bay_owner(x,z,other)
						water_owner=owner
						if point_in_base_bay(x,z,other) then
			local actual,actual_segment,tied,legacy_owner=base_bay_owner(x,z,other)
							local expected,expected_segment,oracle_tied=
								oracle_base_bay_owner(x,z,other)
							assert(actual==expected and actual_segment==expected_segment and
								tied==oracle_tied,"independent exact Base-Bay owner oracle drift: "..
								other.id..":"..x..","..z)
				owner_oracle_columns=owner_oracle_columns+1
				if tied then
					owner_segment_ties=owner_segment_ties+1
					owner_ties_by_bay[other.id]=owner_ties_by_bay[other.id]+1
					if actual~=legacy_owner then
						owner_changed_ties=owner_changed_ties+1
						owner_changes_by_bay[other.id]=owner_changes_by_bay[other.id]+1
						first_owner_change=first_owner_change or
							(other.id..":"..x..","..z..":"..legacy_owner.."->"..actual)
					end
				end
						end
						if not point_in_base_bay(x,z,other) and wing_count~=1 then
							wing_overlap_count=wing_overlap_count+1
						end
						break
					end
				end
				if under_any_bay then
					if not water_owner or not zone_numeric[water_owner] then
						owner_failure_count=owner_failure_count+1
					end
				else
					local dry_count,dry_zones=0,{}
					for zone_id,polygon in pairs(face_by_zone) do
						if zone_id:match("^"..bay.continent.."_") and point_in_face(zone_id,x,z) then
							dry_count=dry_count+1 dry_zones[#dry_zones+1]=zone_id
						end
					end
				if dry_count==0 then gap_count=gap_count+1
					local band=math.floor(z/100)*100
					local band_row=gap_bands[band]
					if not band_row then band_row={count=0,min_x=x,max_x=x}
						gap_bands[band]=band_row end
					band_row.count=band_row.count+1
					band_row.min_x=math.min(band_row.min_x,x)
					band_row.max_x=math.max(band_row.max_x,x)
					first_gap=first_gap or (x..","..z)
					gap_min_x=math.min(gap_min_x or x,x)
					gap_max_x=math.max(gap_max_x or x,x)
					gap_min_z=math.min(gap_min_z or z,z)
					gap_max_z=math.max(gap_max_z or z,z)
					elseif dry_count>1 and not declared_dry_equality(x,z,dry_zones) then
						overlap_count=overlap_count+1
						first_overlap=first_overlap or (x..","..z..":"..table.concat(dry_zones,"+"))
				else
					local canonical_owner=dry_zones[1]
					for i=2,#dry_zones do if zone_numeric[dry_zones[i]]<
						zone_numeric[canonical_owner] then canonical_owner=dry_zones[i] end end
					if not canonical_owner then owner_failure_count=owner_failure_count+1 end
				end
				end
			end
		end end
		if gap_count>0 or overlap_count>0 or wing_overlap_count>0 or
				owner_failure_count>0 then local band_rows={}
			for band,row in pairs(gap_bands) do band_rows[#band_rows+1]={band,row} end
			table.sort(band_rows,function(a,b) return a[1]<b[1] end)
			local band_text={}
			for i=1,#band_rows do local row=band_rows[i][2]
				band_text[#band_text+1]=band_rows[i][1]..":"..row.count..
					"["..row.min_x..".."..row.max_x.."]" end
			gap_summaries[#gap_summaries+1]=
			bay.id.."=g"..gap_count.."/o"..overlap_count.."/w"..wing_overlap_count..
				"/u"..owner_failure_count.."@"..tostring(first_gap).." overlap="..tostring(first_overlap)..
			"["..tostring(gap_min_x)..".."..tostring(gap_max_x)..","..
			tostring(gap_min_z)..".."..tostring(gap_max_z).."]{"..
			table.concat(band_text,",").."}" end
	end
	for _,fixture in ipairs({
		{"land_005",0,-1900},{"land_014",0,1900},
		{"land_043",-2000,-250},{"land_049",-2000,250},
	}) do
		local edge=edge_by_id[fixture[1]]
		local containing={}
		for zone_id,polygon in pairs(face_by_zone) do
			if point_in_face(zone_id,fixture[2],fixture[3]) then containing[#containing+1]=zone_id end
		end
		assert(#containing>=2 and declared_dry_equality(fixture[2],fixture[3],containing),
			"declared shared-edge equality KAT drift: "..fixture[1])
		local owner=containing[1]
		for i=2,#containing do if zone_numeric[containing[i]]<zone_numeric[owner] then
			owner=containing[i] end end
		assert(owner==edge.tie_zone_id,"canonical shared-edge tie KAT drift: "..fixture[1])
	end
	assert(#gap_summaries==0,"final bay partition gaps-or-dry-overlaps "..
		table.concat(gap_summaries,";"))

	-- Exhaustive whole-mainland oracle.  Exact rational scanline endpoints
	-- avoid a floating polygon test at every column while preserving all
	-- integer boundary columns.  Bay precedence is then evaluated by the same
	-- exact integer capsule/wing predicates used above.
	local faces_by_continent={elandor={},kragmar={}}
	for zone_id,polygon in pairs(face_by_zone) do
		local continent=zone_id:match("^(elandor)_") or zone_id:match("^(kragmar)_")
		if continent then faces_by_continent[continent][#faces_by_continent[continent]+1]=
			{zone_id=zone_id,polygon=polygon} end
	end
	for _,rows in pairs(faces_by_continent) do
		table.sort(rows,function(a,b) return zone_numeric[a.zone_id]<zone_numeric[b.zone_id] end)
	end
	local bays_by_continent={elandor={},kragmar={}}
	for i=1,#source.bays do local bay=source.bays[i]
		bays_by_continent[bay.continent][#bays_by_continent[bay.continent]+1]=bay
	end
	local whole_gap,whole_final_overlap,whole_raw_violation=0,0,0
	local first_whole_failure
	for _,continent in ipairs({"elandor","kragmar"}) do
		local perimeter=perimeter_by_id["perimeter_"..continent.."_mainland"].polygon
		local perimeter_scanlines=polygon_scanlines(perimeter)
		local minimum_z,maximum_z=perimeter[1].z,perimeter[1].z
		for i=2,#perimeter do minimum_z=math.min(minimum_z,perimeter[i].z)
			maximum_z=math.max(maximum_z,perimeter[i].z) end
		for z=minimum_z,maximum_z do
			local events={}
			for face_index=1,#faces_by_continent[continent] do
				local intervals=face_scanlines[faces_by_continent[continent][face_index].zone_id][z] or {}
				for interval_index=1,#intervals do local interval=intervals[interval_index]
					events[interval[1]]=(events[interval[1]] or 0)+1
					events[interval[2]+1]=(events[interval[2]+1] or 0)-1
				end
			end
			local event_x={}
			for x in pairs(events) do event_x[#event_x+1]=x end
			table.sort(event_x)
			local perimeter_intervals=perimeter_scanlines[z] or {}
			for interval_index=1,#perimeter_intervals do local interval=perimeter_intervals[interval_index]
				local event_index,dry_count=1,0
				while event_index<=#event_x and event_x[event_index]<interval[1] do
					dry_count=dry_count+events[event_x[event_index]] event_index=event_index+1
				end
				for x=interval[1],interval[2] do
					while event_index<=#event_x and event_x[event_index]==x do
						dry_count=dry_count+events[event_x[event_index]] event_index=event_index+1
					end
					local water_count,water_owner=0
					local perimeter_key=x..":"..z
					local on_perimeter=perimeter_station_lookup[
						"perimeter_"..continent.."_mainland"][perimeter_key]~=nil
					for bay_index=1,#bays_by_continent[continent] do local bay=bays_by_continent[continent][bay_index]
						if point_in_final_bay(x,z,bay) then
							local owner,wing_count=final_bay_owner(x,z,bay)
							water_count=water_count+1 water_owner=owner
							if not point_in_base_bay(x,z,bay) and wing_count~=1 then
								whole_final_overlap=whole_final_overlap+1
							end
						end
					end
					if water_count>1 or water_count==1 and not zone_numeric[water_owner] then
						whole_final_overlap=whole_final_overlap+1
						first_whole_failure=first_whole_failure or (continent..":"..x..","..z)
					elseif water_count==0 and on_perimeter then
						local equality_owner=perimeter_equality_owner(
							"perimeter_"..continent.."_mainland",x,z)
						if not equality_owner then
							whole_gap=whole_gap+1
							first_whole_failure=first_whole_failure or (continent..":"..x..","..z)
						end
					elseif water_count==0 and dry_count==0 then
						whole_gap=whole_gap+1
						if not first_whole_failure then local direct={}
							for face_index=1,#faces_by_continent[continent] do local face=faces_by_continent[continent][face_index]
								if point_in_polygon(x,z,face.polygon) then direct[#direct+1]=face.zone_id end
							end
							first_whole_failure=continent..":"..x..","..z..":direct="..table.concat(direct,"+")
						end
					elseif water_count==0 and dry_count>1 then
						local zones={}
						for face_index=1,#faces_by_continent[continent] do local face=faces_by_continent[continent][face_index]
							if point_in_face(face.zone_id,x,z) then zones[#zones+1]=face.zone_id end
						end
						if not declared_dry_equality(x,z,zones) then
							whole_raw_violation=whole_raw_violation+1
							first_whole_failure=first_whole_failure or (continent..":"..x..","..z)
						end
					end
				end
			end
		end
	end
	local aperture_run_text={}
	for i=1,#source.bays do local run=aperture_runs[source.bays[i].id]
		aperture_run_text[#aperture_run_text+1]=source.bays[i].id..":"..run.count
	end
	assert(whole_gap==0 and whole_final_overlap==0 and whole_raw_violation==0,
		("whole mainland partition g%d/o%d/r%d first=%s"):format(whole_gap,
			whole_final_overlap,whole_raw_violation,tostring(first_whole_failure))..
			" apertures="..table.concat(aperture_run_text,","))
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
do
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
do
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

-- The Bay projection is an exact station-distance decision, not a rounded
-- parametric projection. This witness is the reviewed divergent case.
do
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
	extreme_policy.score_all_candidates_before_stage2==true and
	extreme_policy.candidate_count==4096,
	"geometry extreme exact normalization KAT drift")

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
expect_failure("face_arc_literal_component",function(s)
	s.face_arcs[1].authority_components[2].boundary_role="outer_coast"
end)
expect_failure("face_arc_literal_component",function(s)
	s.face_arcs[1].authority_components[2].from_boundary_id="changed"
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
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.shared_boundary_attachment_rule=
		"nearest_perimeter_station_then_snap"
end)
expect_failure("boundary_clip_policy",function(s)
	s.geometry_policies.boundary_displacement.no_jitter_metric=
		"euclidean_world_distance"
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

do
	local ok,failure=stage1.validate(source,vocabulary)
	assert(not ok and failure.invariant=="exact_source_seam")
end
do
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
do
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
do
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
