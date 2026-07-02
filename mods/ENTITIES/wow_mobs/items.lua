-- Trash-Loot: existiert nur, um beim Haendler (WP7) fuer Gold verkauft zu
-- werden. _wow_sell_price = Ankaufspreis in Gold (vom Haendler gelesen).

core.register_craftitem("wow_mobs:zombie_flesh", {
	description = "Verrottetes Fleisch",
	inventory_image = "mobs_meat_raw.png^[multiply:#7fae6a",
	groups = {wow_trash_loot = 1},
	_wow_sell_price = 2,
})

core.register_craftitem("wow_mobs:boar_tusk", {
	description = "Wildschwein-Hauer",
	inventory_image = "mobs_leather.png^[multiply:#e8e0c8",
	groups = {wow_trash_loot = 1},
	_wow_sell_price = 1,
})
