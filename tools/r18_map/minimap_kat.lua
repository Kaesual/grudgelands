local repo = assert(arg[1], "repository root required")
local mods_loaded_callback
local join_callback
local definitions = {
	["fixture:visible"] = {initial_properties = {show_on_minimap = true,
		visual = "sprite", nametag = "Visible"}},
	["fixture:implicit"] = {initial_properties = {visual = "mesh"}},
	["fixture:empty"] = {},
}
local core_api = {
	registered_entities = definitions,
	register_on_mods_loaded = function(callback) mods_loaded_callback = callback end,
	register_on_joinplayer = function(callback) join_callback = callback end,
}
local environment = {core = core_api}
environment._G = environment
setmetatable(environment, {__index = _G})
local chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_map/minimap.lua"))
setfenv(chunk, environment)
chunk()
assert(mods_loaded_callback and join_callback)
mods_loaded_callback()
for _, definition in pairs(definitions) do
	assert(definition.initial_properties.show_on_minimap == false)
end
assert(definitions["fixture:visible"].initial_properties.visual == "sprite")
assert(definitions["fixture:visible"].initial_properties.nametag == "Visible")

local properties
local modes
local selected
local player = {
	set_properties = function(self, value) properties = value end,
	set_minimap_modes = function(self, value, index)
		modes, selected = value, index
	end,
}
join_callback(player)
assert(properties.show_on_minimap == false)
assert(#modes == 2 and modes[1].type == "surface" and modes[1].size == 256)
assert(modes[2].type == "off" and selected == 0)
print("r18_map_minimap_kat_v1\tentities=hidden\tplayers=hidden\tsurface_default=ok\tV=surface/off")
