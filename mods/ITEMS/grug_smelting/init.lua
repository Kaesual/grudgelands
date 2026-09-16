-- WP26 -- the two smelting nodes' recipe families.
--
-- WHAT LIVES WHERE
--   alloys.lua   the `dualfurn` recipe registry: `grug_smelting.RECIPES`, the
--                either-order matcher and the anti-loop read surface the
--                §3.8 audit in `grug_traders` walks
--   node.lua     the ported dual furnace node pair (two material slots, two
--                output slots, one fuel slot, node-timer driven)
--   recipes.lua  every registration: the five §3.2 cooking recipes, the five
--                §3.3 alloys, the twelve §3.4 storage pack/unpack pairs and
--                the furnace's own §3.5 craft recipe
--
-- WHY A SEPARATE MOD. `grug_materials` is the recipe-free canonical registry
-- WP43 froze ("Recipes are deliberately not part of this registry",
-- `registry.lua`), and the task card makes WP26 the sole owner of the bar
-- recipe families. Owning them from here keeps that split intact: every item
-- and node this mod names is already registered by `grug_materials`, and the
-- dual furnace pair is the only NEW content WP26 adds
-- (`docs/research/wp26-task-card.md` §2).

grug_smelting = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/alloys.lua")
dofile(modpath .. "/node.lua")
dofile(modpath .. "/recipes.lua")
