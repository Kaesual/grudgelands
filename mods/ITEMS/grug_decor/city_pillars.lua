-- City-only material variants of the existing fixed pillar geometry.
-- Reuse the curated castle kit; no new meshes, interaction or player stock.
local materials = {
	{name = "marble", source = "grug_decor:darkage_marble"},
	{name = "ors", source = "grug_decor:darkage_ors_block"},
	{name = "basalt", source = "grug_decor:darkage_basalt_block"},
	{name = "junglewood", source = "default:junglewood"},
}
for _, material in ipairs(materials) do
	local surface = assert(core.registered_nodes[material.source])
	for _, shape in ipairs({"bottom", "middle", "top"}) do
		local original = assert(core.registered_nodes["grug_decor:castle_pillar_stone_block_" .. shape])
		local def = table.copy(original)
		def.description = "City " .. material.name .. " pillar " .. shape
		def.tiles = table.copy(surface.tiles)
		def.sounds = surface.sounds
		def.groups = table.copy(original.groups)
		def.groups.not_in_creative_inventory = 1
		def.drop = ""
		def._grug_city_architecture = true
		core.register_node("grug_decor:city_pillar_" .. material.name .. "_" .. shape, def)
	end
end
