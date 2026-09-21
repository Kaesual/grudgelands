-- Thin identity-bearing source for the shared Round 14 POI builder.
return function()
	local info = debug and debug.getinfo and debug.getinfo(1, "S")
	local here = type(info)=="table" and type(info.source)=="string" and
		info.source:sub(1,1)=="@" and info.source:sub(2):match("^(.*)[/\\\\][^/\\\\]*$")
	if not here or here=="" then here=core.get_modpath("grug_mapgen").."/wp40" end
	return dofile(here .. "/r14_poi_blueprint.lua")({
		schema="grug_r14_goldmead_outpost_v1",race="human",kind="outpost"})
end
