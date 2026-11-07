grug_repair = {}

local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/service.lua")
dofile(path .. "/presentation.lua")
dofile(path .. "/runtime.lua")
dofile(path .. "/providers.lua")
dofile(path .. "/hints.lua")

-- A PvP death costs nothing (grug_pvp decides, it holds the enemy's last hit).
grug_pvp.register_on_death(function(player, pvp)
	if not pvp then grug_repair.wear_death(player) end
end)
