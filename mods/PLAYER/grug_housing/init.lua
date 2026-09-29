-- Claim Stone housing (Round 25, docs/planning/round25-housing-plan.md).
-- Each file has one owner lane so the lanes can work in parallel:
--   registry.lua     the pure claim model (Lane A)
--   api.lua          claim core and the interface contract (Lane A)
--   stone.lua        the stone item and nodes, expiry check (Lane A)
--   soulbound.lua    main-inventory-only items (Lane A)
--   protection.lua   is_protected, arrival cube, renewal guard (Lane A)
--   interaction.lua  right-click and node-inventory guard (Lane B)
--   interface.lua    stone formspec, Housing Manager, character status (Lane C)
-- The home-stone travel target lives in grug_home (Lane D).

grug_housing = {}

local path = core.get_modpath("grug_housing")
dofile(path .. "/api.lua")
dofile(path .. "/stone.lua")
dofile(path .. "/soulbound.lua")
dofile(path .. "/protection.lua")
dofile(path .. "/interaction.lua")
dofile(path .. "/interface.lua")
