local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "SVG output path required")
local seed = arg[4] or "0"
local canonical_output = repo .. "/docs/research/wp40-simple-map-preview.svg"
assert(output == canonical_output or output:sub(1,#scratch+1) == scratch.."/",
	"SVG output must be the canonical preview or live below scratch")

local loaded = dofile(repo .. "/tools/wp40/simple_map_offline.lua")(
	repo,scratch,seed)
local source, session = loaded.source, loaded.session
local landmark_by_id={}
for index=1,#source.landmarks do
	landmark_by_id[source.landmarks[index].id]=source.landmarks[index]
end
local hydrology_profile_by_id={}
for index=1,#source.hydrology_profiles do
	local row=source.hydrology_profiles[index]
	hydrology_profile_by_id[row.id]=row
end
local width, height = 1440, 1280
local world_width = source.extent.max_x-source.extent.min_x
local world_height = source.extent.max_z-source.extent.min_z
local scale_x, scale_z = width/world_width, height/world_height

local function sx(x) return (x-source.extent.min_x)*scale_x end
local function sy(z) return (source.extent.max_z-z)*scale_z end
local function number(value) return ("%.2f"):format(value) end
local function escape(value)
	local amp=string.char(38)
	return tostring(value):gsub(amp,amp.."amp;"):gsub("<",amp.."lt;"):
		gsub(">",amp.."gt;"):gsub('"',amp.."quot;")
end
local function points(values)
	local result={}
	for index=1,#values do
		result[index]=number(sx(values[index].x))..","..number(sy(values[index].z))
	end
	return table.concat(result," ")
end
local function write_mask(write, row, attributes)
	local shape=row.primitive or row.kind
	if shape=="ellipse" then
		write('<ellipse cx="',number(sx(row.center.x)),'" cy="',number(sy(row.center.z)),
			'" rx="',number(row.radius_x*scale_x),'" ry="',
			number(row.radius_z*scale_z),'" ',attributes,'><title>',
			escape(row.id),'</title></ellipse>\n')
	elseif shape=="rectangle" then
		write('<rect x="',number(sx(row.center.x-row.radius_x)),'" y="',
			number(sy(row.center.z+row.radius_z)),'" width="',
			number(2*row.radius_x*scale_x),'" height="',
			number(2*row.radius_z*scale_z),'" ',attributes,'><title>',
			escape(row.id),'</title></rect>\n')
	elseif shape=="capsule" and row.a and row.b then
		write('<line x1="',number(sx(row.a.x)),'" y1="',number(sy(row.a.z)),
			'" x2="',number(sx(row.b.x)),'" y2="',number(sy(row.b.z)),
			'" stroke-width="',number(2*row.radius*scale_x),'" ',attributes,
			'><title>',escape(row.id),'</title></line>\n')
	elseif shape=="capsule" then
		local radius=math.min(row.radius_x,row.radius_z)
		write('<rect x="',number(sx(row.center.x-row.radius_x)),'" y="',
			number(sy(row.center.z+row.radius_z)),'" width="',
			number(2*row.radius_x*scale_x),'" height="',
			number(2*row.radius_z*scale_z),'" rx="',number(radius*scale_x),
			'" ry="',number(radius*scale_z),
			'" ',attributes,'><title>',escape(row.id),'</title></rect>\n')
	end
end
local function zone_color(zone)
	local target=zone.difficulty_target
	if zone.macro_region=="holy_grounds" then
		return ("hsl(%d,52%%,%d%%)"):format(275+(zone.numeric_id-34)*13,73-math.floor(target/5))
	elseif zone.macro_region=="wyrmglass_island" then return "hsl(340,55%,42%)"
	elseif zone.macro_region=="stormscale_island" then return "hsl(12,58%,42%)"
	elseif zone.faction=="accord" then
		return ("hsl(%d,46%%,%d%%)"):format(145+(zone.numeric_id%6)*8,78-math.floor(target/4))
	elseif zone.faction=="throng" then
		return ("hsl(%d,52%%,%d%%)"):format(18+(zone.numeric_id%6)*8,78-math.floor(target/4))
	elseif zone.macro_region=="elandor_mainland" then
		return "hsl(205,18%,57%)"
	elseif zone.macro_region=="kragmar_mainland" then
		return "hsl(32,38%,60%)"
	end
	return "hsl(300,35%,55%)"
end

local water_fill={
	planned_water="#397ea2",
	coastal_shelf="#5797ad",
	immutable_dragon_channel="#182b48",
}
local land_rects,water_rects={},{}
local raster_step=12
for z=source.extent.max_z,source.extent.min_z,-raster_step do
	local run_key,run_start,run_class
	local function finish_run(end_x)
		if not run_key or run_class=="deep_ocean" then return end
		local target=run_class=="land" and land_rects or water_rects
		local fill
		if run_class=="land" then fill=zone_color(source.zones[tonumber(run_key)])
		else fill=water_fill[run_class] end
		target[#target+1]=(('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'):format(
			number(sx(run_start)),number(sy(z)),
			number((end_x-run_start)*scale_x),number(raster_step*scale_z),fill))
	end
	for x=source.extent.min_x,source.extent.max_x+raster_step,raster_step do
		local classification
		if x<=source.extent.max_x then classification=session.classification_at(x,z)
		else classification={water_class="sentinel"} end
		local key=classification.water_class=="land" and
			tostring(classification.zone_numeric_id) or classification.water_class
		if key~=run_key then
			finish_run(x)
			run_key,run_start,run_class=key,x,classification.water_class
		end
	end
end

local file=assert(io.open(output,"wb"))
local function write(...)
	assert(file:write(...))
end
write('<?xml version="1.0" encoding="UTF-8"?>\n')
write('<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1280" viewBox="0 0 1440 1280">\n')
write('<title>WP40 simple map preview — seed ',escape(seed),'</title>\n')
write('<desc>Generated from the production simple-map evaluator. Preview seed ',
	escape(seed),'; layout ',escape(source.layout_id),'.</desc>\n')
write('<defs><filter id="label-halo"><feMorphology in="SourceAlpha" operator="dilate" radius="1.4" result="d"/><feFlood flood-color="#081421" result="c"/><feComposite in="c" in2="d" operator="in" result="o"/><feMerge><feMergeNode in="o"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>\n')
write('<g id="ocean-and-shelf"><rect width="1440" height="1280" fill="#091728"/>\n',
	table.concat(water_rects,"\n"),'\n</g>\n')
write('<g id="macro-land" data-layer-role="authored-control-geometry" fill="none" stroke="#d7edf4" stroke-opacity="0.12" stroke-linecap="round">\n')
for index=1,#source.land_primitives do
	local row=source.land_primitives[index]
	if row.kind=="rounded_rect" then
		write('<rect x="',number(sx(row.min_x)),'" y="',number(sy(row.max_z)),
			'" width="',number((row.max_x-row.min_x)*scale_x),'" height="',
			number((row.max_z-row.min_z)*scale_z),'" rx="',
			number(row.radius*scale_x),'"/>\n')
	else
		write_mask(write,row,'fill="none" stroke="#d7edf4" stroke-opacity="0.12"')
	end
end
for index=1,#source.islands do
	write('<polygon points="',points(source.islands[index].polygon),'"/>\n')
end
write('</g>\n')
write('<g id="zone-ownership">\n',table.concat(land_rects,"\n"),'\n</g>\n')
local holy=source.holy_grounds
write('<g id="progression-pvp" fill="none" stroke="#e8c870" stroke-width="2" stroke-dasharray="7 5" opacity="0.8"><rect x="',
	number(sx(holy.min_x)),'" y="',number(sy(holy.max_z)),'" width="',
	number((holy.max_x-holy.min_x)*scale_x),'" height="',
	number((holy.max_z-holy.min_z)*scale_z),'"/></g>\n')

write('<g id="planned-water" fill="none" stroke="#b7e5f2" stroke-width="2" opacity="0.8">\n')
for index=1,#source.bays do
	local centreline={}
	for sample=1,#source.bays[index].centreline do
		local row=source.bays[index].centreline[sample]
		centreline[sample]={x=row.x,z=row.z}
	end
	write('<polyline points="',points(centreline),'"/>\n')
end
write('</g>\n')

write('<g id="channels-and-boat-routes">\n')
for index=1,#source.channels do
	write('<polygon points="',points(source.channels[index].polygon),
		'" fill="none" stroke="#8bb6db" stroke-width="2"/>\n')
end
for index=1,#source.boat_paths do
	write('<polyline points="',points(source.boat_paths[index].centreline),
		'" fill="none" stroke="#f4dd8e" stroke-width="4" stroke-dasharray="8 6"/>\n')
end
write('</g>\n')
write('<g id="hydrology" fill="none" stroke-linecap="round" stroke-linejoin="round">\n')
for index=1,#(source.hydrology or {}) do
	local row=source.hydrology[index]
	local profile=assert(hydrology_profile_by_id[row.profile_id])
	local color=profile.depth > 0 and "#8eddf0" or "#8b9da3"
	local dash=profile.depth > 0 and "" or ' stroke-dasharray="7 5"'
	for segment=1,#row.centreline-1 do
		local a,b=row.centreline[segment],row.centreline[segment+1]
		write('<line data-hydrology="',escape(row.id),'" x1="',number(sx(a.x)),
			'" y1="',number(sy(a.z)),'" x2="',number(sx(b.x)),'" y2="',
			number(sy(b.z)),'" stroke="',color,'" stroke-width="',
			number(math.max(2,(a.half_width+b.half_width)*scale_x)),
			'" stroke-opacity="0.38"',dash,'><title>',
			escape(row.id.." ("..row.profile_id..")"),'</title></line>\n')
	end
end
write('</g>\n')
write('<g id="hydrology-transitions" fill="#d9f7ff" stroke="#173a4b" stroke-width="1.5">\n')
for index=1,#source.hydrology_interfaces do
	local row=source.hydrology_interfaces[index]
	if row.kind=="waterfall" or row.kind=="rapid" then
		local radius=row.kind=="waterfall" and 7 or 4
		write('<circle cx="',number(sx(row.position.x)),'" cy="',
			number(sy(row.position.z)),'" r="',number(radius),'"><title>',
			escape(row.id.." ("..row.kind..")"),'</title></circle>\n')
	end
end
write('</g>\n')

write('<g id="protected-capital-ingresses" fill="none" stroke="#fff0a8" stroke-opacity="0.16" stroke-linecap="round" stroke-linejoin="round">\n')
local route_by_id={}
for index=1,#source.routes do route_by_id[source.routes[index].id]=source.routes[index] end
for index=1,#source.capital_ingresses do
	local ingress=source.capital_ingresses[index]
	for route_index=1,#ingress.route_ids do
		local route=assert(route_by_id[ingress.route_ids[route_index]])
		write('<polyline data-ingress="',ingress.id,'" points="',
			points(route.centreline),'" stroke-width="',
			number(ingress.total_width*scale_x),'"><title>',
			escape(ingress.id.." protected capital ingress"),'</title></polyline>\n')
	end
end
write('</g>\n')

write('<g id="land-routes" fill="none" stroke-linecap="round" stroke-linejoin="round">\n')
local route_style={primary={color="#f7e0a0",width=4},secondary={color="#e8c47b",width=3},trail={color="#d9a869",width=2}}
for index=1,#source.routes do
	local route=source.routes[index]
	local style=route_style[route.class]
	write('<polyline data-route="',route.id,'" points="',points(route.centreline),
		'" stroke="',style.color,'" stroke-width="',style.width,'"/>\n')
end
for index=1,#source.island_routes do
	write('<polyline points="',points(source.island_routes[index].centreline),
		'" stroke="#e8c47b" stroke-width="3"/>\n')
end
write('</g>\n')

write('<g id="crossing-interfaces" fill="#fff0ac" stroke="#402d17" stroke-width="1">\n')
for index=1,#source.crossing_interfaces do
	local row=source.crossing_interfaces[index]
	write('<rect x="',number(sx(row.position.x)-3),'" y="',number(sy(row.position.z)-3),
		'" width="6" height="6"><title>',escape(row.id.." ("..row.kind..")"),'</title></rect>\n')
end
write('</g>\n')

write('<g id="landmarks" fill="none" stroke="#f7f1cb" stroke-width="1" stroke-dasharray="3 3" stroke-opacity="0.24">\n')
for index=1,#(source.landmarks or {}) do
	write_mask(write,source.landmarks[index],
		'fill="none" stroke="#f7f1cb" stroke-opacity="0.24" stroke-dasharray="3 3"')
end
write('</g>\n')
write('<g id="ownership-cores" fill="none" stroke="#ffffff" stroke-width="1.2" opacity="0.75">\n')
for index=1,12 do
	local row=source.anchors[index]
	local width_x=index<=6 and source.start_core.width_x or source.capital_core.width_x
	local width_z=index<=6 and source.start_core.width_z or source.capital_core.width_z
	write('<rect x="',number(sx(row.position.x-width_x/2)),'" y="',
		number(sy(row.position.z+width_z/2)),'" width="',number(width_x*scale_x),
		'" height="',number(width_z*scale_z),'"/>\n')
end
write('</g>\n')

write('<g id="housing-masks" fill="#f2d7a5" fill-opacity="0.12" stroke="#f5d58d" stroke-width="1.5">\n')
for index=1,#source.housing_masks do
	write('<polygon points="',points(source.housing_masks[index].polygon),'"/>\n')
end
write('</g>\n')
write('<g id="coastal-housing-cores" fill="#f8e3a2" fill-opacity="0.18" stroke="#fff0a8" stroke-width="2">\n')
for index=1,#source.coastal_housing_cores do
	local row=source.coastal_housing_cores[index]
	local landmark=assert(landmark_by_id[row.landmark_id])
	assert(row.shape=="vertical_capsule_v1",
		"unsupported coastal housing core shape: "..tostring(row.shape))
	write_mask(write,{id=row.id,primitive="capsule",center=landmark.center,
		radius_x=landmark.radius_x,radius_z=landmark.radius_z},"")
end
write('</g>\n')

write('<g id="anchor-alternatives" fill="#ffffff" fill-opacity="0.22">\n')
for index=1,#source.anchors do
	local row=source.anchors[index]
	if row.candidates then
		for candidate=1,#row.candidates do
			write('<circle cx="',number(sx(row.candidates[candidate].x)),'" cy="',
				number(sy(row.candidates[candidate].z)),'" r="2"/>\n')
		end
	end
end
write('</g>\n')
write('<g id="selected-anchors" fill="#ffffff" stroke="#192536" stroke-width="1">\n')
for index=1,#source.anchors do
	local row=source.anchors[index]
	local selected=session.selected_anchor_by_id(row.id)
	local radius=(row.slot_id=="start" or row.slot_id=="capital") and 4 or 2.5
	write('<circle cx="',number(sx(selected.x)),'" cy="',number(sy(selected.z)),
		'" r="',number(radius),'"><title>',escape(row.id.." "..row.slot_id),'</title></circle>\n')
end
write('</g>\n')

write('<g id="zone-hubs-and-labels" font-family="sans-serif" font-size="10" text-anchor="middle" fill="#ffffff" filter="url(#label-halo)">\n')
for index=1,#source.zones do
	local row=source.zones[index]
	write('<circle cx="',number(sx(row.hub.x)),'" cy="',number(sy(row.hub.z)),
		'" r="3.5" fill="#fff4c4"/><text x="',number(sx(row.hub.x)),'" y="',
		number(sy(row.hub.z)-7),'">',escape(row.display_name),
		'<tspan x="',number(sx(row.hub.x)),'" dy="10" font-size="8">L',
		row.difficulty_target,'</tspan></text>\n')
end
write('</g>\n')

local digest=session.canonical_kat_digest()
write('<g id="diagnostics" font-family="sans-serif"><rect x="12" y="12" width="390" height="76" rx="8" fill="#07111d" fill-opacity="0.9" stroke="#7089a0"/><text x="26" y="36" fill="#f4e8c8" font-size="16" font-weight="bold">WP40 simple map V1d</text><text x="26" y="56" fill="#d2dfeb" font-size="11">layout ',escape(source.layout_id),' · preview seed ',escape(seed),'</text><text x="26" y="74" fill="#91a9bd" font-size="9">KAT ',digest,'</text></g>\n')
write('</svg>\n')
assert(file:close())
print("svg\t"..output.."\t"..digest)
