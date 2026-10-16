-- Character screen & bags (WP15, spec: docs/design/inventory_equipment.md).
-- Equipment and bags are player-inventory lists (auto-persisted); the UI
-- consists of sfinv pages, with the character page as the new homepage.

grug_inventory = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/equipment.lua")
dofile(modpath .. "/bags.lua")
dofile(modpath .. "/inbox.lua")
dofile(modpath .. "/ui.lua")
-- The furnace forms' fire and arrow (0.49.1 ANIM), for default and grug_jobs.
grug_inventory.furnace_progress = dofile(modpath .. "/furnace_progress.lua")
dofile(modpath .. "/help.lua")
dofile(modpath .. "/welcome.lua")
dofile(modpath .. "/pages.lua")
