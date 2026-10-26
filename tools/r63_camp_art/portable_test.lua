local repo = assert(arg[1], "repo path required")
local registered = {}
local core_stub = {
	registered_nodes = {},
	get_modpath = function(name)
		assert(name == "grug_mapgen")
		return repo .. "/mods/MAPGEN/grug_mapgen"
	end,
	register_node = function(name, def) registered[name] = def end,
}
for _, name in ipairs({"default:pine_wood", "default:wood", "grug_trees:silverwood_wood",
	"grug_trees:gravewood_wood", "default:acacia_wood", "default:junglewood"}) do
	core_stub.registered_nodes[name] = {tiles = {name:gsub(":", "_") .. ".png"}}
end
local default_stub = {
	node_sound_leaves_defaults = function() return {kind = "leaves"} end,
	node_sound_wood_defaults = function() return {kind = "wood"} end,
}
dofile(repo .. "/mods/MAPGEN/grug_mapgen/camp_nodes.lua")(core_stub, default_stub)
local wanted = {"camp_canvas", "camp_ridge", "camp_trim_accord", "camp_trim_throng",
	"faction_banner_accord", "faction_banner_throng"}
for _, race in ipairs({"dwarf", "human", "elf", "undead", "orc", "troll"}) do
	wanted[#wanted + 1] = "camp_stockade_" .. race
	wanted[#wanted + 1] = "camp_wall_cap_" .. race
end
assert(#wanted == 18)
for _, suffix in ipairs(wanted) do
	local def = assert(registered["grug_mapgen:" .. suffix], suffix)
	assert(def.diggable == false and def.is_ground_content == false and def.drop == "")
	assert(def.groups.not_in_creative_inventory == 1 and def.paramtype2 == "facedir")
end
assert(registered["grug_mapgen:faction_banner_accord"].walkable == false)
print("r63_camp_art portable fixture: OK (18 nodes)")
