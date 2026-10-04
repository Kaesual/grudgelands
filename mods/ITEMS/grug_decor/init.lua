-- grug_decor: curated decorative building kit for race settlements and capitals.
--
-- Node DEFINITIONS and MEDIA are harvested from four upstream mods
-- (castle_masonry, cottages, darkage, xdecor-libre); see VENDOR.md for the
-- exact upstream commits and LICENSE-media.md for per-file media provenance.
-- Mechanics are NOT harvested: this mod registers no crafts, no ABMs, no LBMs,
-- no node timers, no formspecs and no inventories, and it never writes nodes at
-- runtime. The ordinary kit is diggable; capital service props are intrinsically
-- immutable and have no item/drop route (capital.lua).
--
-- The capital Decor Merchant sells part of this kit (grug_traders/stock.lua,
-- round33-plan.md §2.6); traders buy back only what a vendor sells.
-- Decorative crafting is owned by a later work package.

grug_decor = {}

local modpath = core.get_modpath(core.get_current_modname())

dofile(modpath .. "/shapes.lua")
dofile(modpath .. "/castle.lua")
dofile(modpath .. "/cottages.lua")
dofile(modpath .. "/darkage.lua")
dofile(modpath .. "/xdecor.lua")

dofile(modpath .. "/capital.lua")
