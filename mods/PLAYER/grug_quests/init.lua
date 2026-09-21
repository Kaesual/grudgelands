grug_quests = {}
local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/registry.lua")
dofile(path .. "/state.lua")
dofile(path .. "/npc.lua")
dofile(path .. "/content.lua")
core.register_on_mods_loaded(grug_quests.validate_registry)
