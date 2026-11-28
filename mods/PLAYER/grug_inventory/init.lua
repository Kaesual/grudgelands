-- Character screen & bags (WP15, spec: docs/design/inventory_equipment.md).
-- Equipment and bags are player-inventory lists (auto-persisted); the UI
-- consists of sfinv pages, with the Inventory page as the homepage.

grug_inventory = {}

local modpath = core.get_modpath(core.get_current_modname())
-- Hotbars A and B first: their guard must answer before equipment.lua's and
-- bags.lua's allow callbacks (hotbars.lua).
dofile(modpath .. "/hotbars.lua")
dofile(modpath .. "/equipment.lua")
dofile(modpath .. "/bags.lua")
dofile(modpath .. "/inbox.lua")
-- The bound-item seam (Round 81): soulbound items and skills register their
-- rules; every detached inventory created from here on (the trash box's
-- included) is wrapped at creation.
dofile(modpath .. "/bound.lua")
dofile(modpath .. "/trash.lua")
dofile(modpath .. "/ui.lua")
dofile(modpath .. "/navigation.lua")
-- The furnace forms' fire and arrow (0.49.1 ANIM), for default and grug_jobs.
grug_inventory.furnace_progress = dofile(modpath .. "/furnace_progress.lua")
dofile(modpath .. "/help.lua")
dofile(modpath .. "/welcome.lua")
-- The Character page's stat sheet (Round 88), read by pages.lua.
dofile(modpath .. "/stats.lua")
dofile(modpath .. "/pages.lua")
