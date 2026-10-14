-- The look of the P9G sources and their items (Round 48; plant-growth-plan.md
-- §2.20, §3.10, §3.14; plant-art-plan.md §6-§7), as runtime overrides: the
-- WP33 catalog's `image` fields are hashed into the mapgen manifest, so they
-- stay as they are and nothing here changes what the world generator writes.
--   * The crops among the sources (Potato, Corn, Melon, Mushroom) show their
--     stage-4 crop look in the wild, like every other wild crop
--     (grug_mapgen/world_nodes.lua).
--   * Melon and Mushroom items, and Sunleaf, Gravemoss and Wild Cocoa, take
--     files of their own; for the last three the source's world sprite
--     (`_plant`) is a file apart from the item icon. Placeholders until the
--     art lane's pick replaces the PNGs (tools/r48_farm/gen_placeholders.py).
local CROP_LOOK = {"corn", "melon", "mushroom", "potato"}
local ITEM_ICON = {"gravemoss", "melon", "mushroom", "sunleaf", "wild_cocoa"}
local WORLD_SPRITE = {"gravemoss", "sunleaf", "wild_cocoa"}

for _, key in ipairs(CROP_LOOK) do
	local look = grug_nodes.crop_visual(key, 4, nil, "wild")
	core.override_item("grug_gathering:" .. key .. "_source", {
		tiles = look.tiles,
		inventory_image = look.inventory_image,
		wield_image = look.wield_image,
		visual_scale = look.visual_scale,
		selection_box = look.selection_box,
	})
end

for _, key in ipairs(ITEM_ICON) do
	core.override_item("grug_gathering:" .. key,
		{inventory_image = "grug_gathering_" .. key .. ".png"})
end

for _, key in ipairs(WORLD_SPRITE) do
	local image = "grug_gathering_" .. key .. "_plant.png"
	core.override_item("grug_gathering:" .. key .. "_source",
		{tiles = {image}, inventory_image = image, wield_image = image})
end
