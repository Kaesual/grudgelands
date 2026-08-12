-- Canonical material/depth owner (WP43; items_crafting.md §3.0).

grug_materials = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/registry.lua")
dofile(modpath .. "/mining.lua")

local STRATUM_COLORS = {
	slate = "#4a5a6e:70",
	basalt = "#2a2a2e:90",
	granite = "#8a5a52:60",
	emberrock = "#7a2a10:90",
	abyssal_rock = "#241830:150",
}

local STRATUM_NAMES = {
	slate = "Slate",
	basalt = "Basalt",
	granite = "Granite",
	emberrock = "Emberrock",
	abyssal_rock = "Abyssal Rock",
}

for i = 2, #grug_materials.TIERS do
	local tier = grug_materials.TIERS[i]
	local name = tier.node:match("^grug_materials:(.+)$")
	core.register_node(tier.node, {
		description = STRATUM_NAMES[name],
		tiles = {"default_stone.png^[colorize:" .. STRATUM_COLORS[name]},
		groups = {cracky = 3, grug_natural = 1, grug_stratum = i},
		drop = "default:cobble",
		is_ground_content = true,
		sounds = default.node_sound_stone_defaults(),
	})
end

dofile(modpath .. "/ores.lua")
dofile(modpath .. "/derivatives.lua")
dofile(modpath .. "/overrides.lua")
dofile(modpath .. "/migration.lua")
dofile(modpath .. "/audit.lua")
