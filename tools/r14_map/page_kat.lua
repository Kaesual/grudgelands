local repo = assert(arg[1], "repository root required")
local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local registered
local selected_page

-- Engine-facing page code runs in an explicit local environment. The fixture
-- supplies only the APIs it consumes and leaves the process globals untouched.
local core_api = {
	formspec_escape = function(value)
		return tostring(value):gsub("\\", "\\\\"):gsub("]", "\\]"):
			gsub(";", "\\;"):gsub(",", "\\,")
	end,
}
local settlement = {key = "copperfell_village", race_id = "dwarf",
	anchor = {x = -1800, y = 12, z = -2200}}
local core_owner = {
	settlement_socket_settlements = function() return {settlement} end,
	zone_authority_installed = function() return true end,
}
local sfinv_api = {
	register_page = function(name, definition)
		assert(name == "grug_map:atlas")
		registered = definition
	end,
	make_formspec = function(player, context, content, show_inventory)
		assert(not show_inventory)
		return content
	end,
	set_page = function(player, name)
		assert(name == "grug_map:atlas")
		selected_page = name
	end,
}
local player = {
	is_player = function() return true end,
	get_player_name = function() return "Cartographer" end,
	get_pos = function() return {x = 0, y = 20, z = 0} end,
}
local map_owner = {atlas = atlas}
local environment = {
	core = core_api,
	grug_core = core_owner,
	grug_zones = {at = function() return {id = "elandor_copperfell_foothills",
		display_name = "Copperfell Foothills"} end},
	grug_map = map_owner,
	sfinv = sfinv_api,
}
environment._G = environment
setmetatable(environment, {__index = _G})
local chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_map/page.lua"))
setfenv(chunk, environment)
chunk()
assert(registered and registered.title == "Map")

local context = {}
local form = registered:get(player, context)
assert(form:sub(1, #"real_coordinates[true]") == "real_coordinates[true]")
assert(form:find("image%[0%.15,0%.85;10%.1,8%.9778;grug_map_atlas_world%.png%]"))
assert(form:find("button%[0%.15,10%.05;1%.4,0%.65;grug_map_view_world;"))
assert(not form:find("list%[current_player"))

-- World marker placement uses 10.1 / 720 horizontally and 8.9778 / 640
-- vertically: the same normalized transform as the 900:800 raster.
local sx, sy = atlas.world_to_screen(atlas.view("world"), settlement.anchor,
	0.15, 0.85, 10.1, 8.9778)
local settlement_field
for field, marker in pairs(context.grug_map_marker_fields) do
	if marker.label == "Copperfell Village" then settlement_field = field end
end
assert(settlement_field)
local expected = ("button[%.3f,%.3f;0.32,0.32;%s;+"):
	format(sx - 0.16, sy - 0.16, settlement_field)
assert(form:find(expected, 1, true), "settlement overlay transform differs")

assert(registered:on_player_receive_fields(player, context,
	{[settlement_field] = true}))
assert(context.grug_map_detail == "Copperfell Village\nDwarf settlement")
assert(selected_page == "grug_map:atlas")
form = registered:get(player, context)
assert(form:find("Selected: Copperfell Village — Dwarf settlement", 1, true))

selected_page = nil
assert(registered:on_player_receive_fields(player, context,
	{grug_map_view_dwarf = true}))
assert(context.grug_map_view == "dwarf" and context.grug_map_detail == nil and
	selected_page == "grug_map:atlas")
form = registered:get(player, context)
assert(form:find("grug_map_atlas_dwarf.png", 1, true))
print("r14_map_page_kat_v1\tbounds=ok\tratio=9:8\tmarker=ok\tclick=ok\tview=ok")
