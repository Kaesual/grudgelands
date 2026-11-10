-- Static, no-loot copies for authored towns. Regional village shells remain
-- diggable; capital/start protection is owned by the existing town system.
-- Copy before grug_displays adds inventories to the player item frame.
local function clone(source, suffix, painting)
	local original = assert(core.registered_nodes[source], source)
	local def = table.copy(original)
	def.description = "City " .. original.description
	def.groups = {not_in_creative_inventory = 1, choppy = 3, oddly_breakable_by_hand = 2}
	def.drop = ""
	def.diggable = true
	def.on_place = nil
	def.on_rotate = function() return false end
	def._grug_city_decoration = true
	if painting then
		def.mesh = "grug_decor_painting_1.obj"
		def.selection_box = {type = "fixed", fixed = {-.46, -.46, .43, .46, .46, .495}}
	end
	core.register_node("grug_decor:city_" .. suffix, def)
end

local path = core.get_modpath("grug_decor")
for _, row in ipairs(dofile(path .. "/furnishings_catalog.lua")) do
	clone(row.item, row.item:match(":(.+)$"))
end
for _, suffix in ipairs({"display_armor", "display_weapon", "xdecor_itemframe",
	"xdecor_empty_shelf", "cottages_shelf", "xdecor_table", "cottages_table",
	"xdecor_chair", "cottages_bench", "xdecor_barrel", "cottages_barrel",
	"cottages_barrel_open", "cottages_barrel_lying", "cottages_barrel_lying_open",
	"cottages_tub", "cottages_washing", "xdecor_cushion", "xdecor_cushion_block",
	"xdecor_curtain", "xdecor_curtain_open", "xdecor_ivy", "xdecor_stonepath",
	"cottages_straw_mat", "cottages_straw_bale", "cottages_window_shutter_open",
	"cottages_window_shutter_closed", "xdecor_workbench", "xdecor_cauldron",
	"xdecor_candle", "xdecor_lantern", "xdecor_lantern_hanging", "cottages_wagon_wheel"}) do
	clone("grug_decor:" .. suffix, suffix)
end
for _, flower in ipairs({"dandelion_white", "dandelion_yellow", "geranium", "rose",
	"tulip", "viola", "tulip_black", "chrysanthemum_green"}) do
	local suffix = "xdecor_potted_" .. flower
	clone("grug_decor:" .. suffix, suffix)
end
for _, row in ipairs(dofile(path .. "/paintings_catalog.lua")) do
	clone("grug_decor:painting_" .. row.id, "painting_" .. row.id, true)
end
