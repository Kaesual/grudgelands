-- Character screen & bags (WP15, spec: docs/design/inventory_equipment.md).
-- Equipment and bags are player-inventory lists (auto-persisted); the UI
-- consists of sfinv pages, with the character page as the new homepage.

wob_inventory = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/equipment.lua")
dofile(modpath .. "/bags.lua")
dofile(modpath .. "/pages.lua")
