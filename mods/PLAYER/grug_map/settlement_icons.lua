-- The baked icon kind of each settlement (Round 44, world_map.md "Baked
-- layer"), pure: no engine calls, so the portable fixtures run it as it
-- ships. A settlement's class comes from its anchor slot
-- (grug_core.settlement_socket_settlements). Every settlement is baked into
-- the one map image everyone sees, the other faction's starts, capitals,
-- villages, outposts and fortress included (Round 44 ruling 5; it ends
-- Round 31's per-viewer hiding). The hostile camps (bandits, Mirefolk) have
-- icons of their own that read as dangerous (Round 32 §2.2).
local M = {}

function M.class(slot)
	if type(slot) ~= "string" then return "other" end
	if slot == "start" or slot == "capital" then return slot end
	if slot == "pvp_fortress" then return "fortress" end
	if slot:match("^village_%d+$") then return "village" end
	if slot:match("^outpost_%d+$") then return "outpost" end
	if slot:match("^pvp_%a+_%a+$") then return "war_camp" end
	if slot:match("^bandit_%d+$") then return "bandit" end
	if slot == "mirefolk" then return "mirefolk" end
	return "other"
end

-- The baked icon kind of a settlement of `slot`: its class, or for "other"
-- the point of interest (mines and gem camps, clash sites, rare dens, the
-- dragon arenas); nil for a slot of no known kind (drawn without an icon).
function M.kind(slot)
	local class = M.class(slot)
	if class ~= "other" then return class end
	if type(slot) ~= "string" then return nil end
	if slot == "mine" or slot == "apex_mine" then return "mine" end
	if slot == "dragon" then return "dragon" end
	if slot:match("^clash_") then return "clash" end
	if slot:match("^rare_") then return "rare_den" end
	return nil
end

return M
