-- Trash loot: exists only to be sold to traders (WP7).
-- _wob_sell_price = buy price in COPPER units (economy.md §1).

core.register_craftitem("wob_mobs:zombie_flesh", {
	description = "Rotting Flesh",
	inventory_image = "mobs_meat_raw.png^[multiply:#7fae6a",
	groups = {wob_trash_loot = 1},
	_wob_sell_price = 2,
})

core.register_craftitem("wob_mobs:boar_tusk", {
	description = "Boar Tusk",
	inventory_image = "mobs_leather.png^[multiply:#e8e0c8",
	groups = {wob_trash_loot = 1},
	_wob_sell_price = 1,
})
