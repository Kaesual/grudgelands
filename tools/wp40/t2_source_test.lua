local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/catalog.lua")
local stage1 = dofile(wp40 .. "/validation/t2_source.lua")
local canonical = dofile(wp40 .. "/canonical.lua")

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

local EXPECTED_SOURCE_CHECKSUM="50258d6d9cec7f67de77c61b7e672ed23de623580518297703003ba2ba8bee15"
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
assert(#source.zones == 38 and #source.land_edges == 57 and
	#source.boat_edges == 4 and #source.landmarks == 70 and
	#source.anchors == 100)
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
expect_failure("exact_source_checksum", function(s) s.zones[1].display_name="Wrong" end)
expect_failure("exact_source_checksum", function(s) s.land_edges[1].control[1].x=-2699 end)
expect_failure("route_crosses_boundary", function(s) s.routes[1].centreline[s.routes[1].crossing_station].x=999 end)
expect_failure("route_station_ref", function(s) s.routes[1].station_a_id="station:elandor_copperfell_foothills:hub" end)
expect_failure("route_crossing_sides", function(s) local r=s.routes[1] r.centreline[2].x=r.centreline[4].x r.centreline[2].z=r.centreline[4].z end)
expect_failure("exact_boat_contract", function(s) s.boat_edges[1].approach_z=-124 end)
expect_failure("landmark_role", function(s) s.landmarks[1].roles[1]="unknown" end)
expect_failure("template_composition_ref", function(s) s.templates[1].composition_id="missing" end)
expect_failure("template_operation", function(s) s.template_compositions[1].operations[1].op="invent" end)
expect_failure("rare_patrol_route", function(s) s.anchors[91].patrol_route={s.anchors[91].patrol_route[1]} end)
expect_failure("apex_socket_species_count", function(s) s.anchors[89].socket_resource_keys[1]="garnet" end)
expect_failure("housing_zone", function(s) s.housing_masks[1].zone_id="elandor_hearthpine_vale" end)
expect_failure("coastal_core_contract", function(s) s.coastal_housing_cores[1].frontage_min=599 end)
expect_failure("hydrology_contract", function(s) s.hydrology[1].depth=3 end)
expect_failure("hydrology_point", function(s) s.hydrology[1].centreline[1].half_width=0 end)
expect_failure("highcourt_arms_distinct", function(s) s.hydrology[6].centreline[1].x=s.hydrology[5].centreline[1].x end)
expect_failure("route_crossing_hydrology_incidence", function(s) for i=1,#s.hydrology[7].centreline do s.hydrology[7].centreline[i].z=-1513 end end)
expect_failure("route_crossing_route_incidence", function(s) s.route_crossing_interfaces[1].position.z=-1501 end)
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
expect_failure("exact_source_checksum", function(s)
	local row=s.hydrology[1]
	row.to_id=row.to_id..";water_node_semantic=s:"..row.water_node_semantic
	row.water_node_semantic=nil
end)
expect_failure("apex_socket_count", function(s)
	local sockets=s.anchors[89].socket_resource_keys
	sockets[1]="citrine;s:garnet"
	table.remove(sockets,2)
end)
expect_failure("semantic_vocabulary", function(s) end, false)

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

print(("WP40 T2 source passed: 38 zones, 57 land edges (30/24/3), " ..
	"4 boat edges, 70 landmarks, 100 anchors, checksum %s"):format(checksum_a))
