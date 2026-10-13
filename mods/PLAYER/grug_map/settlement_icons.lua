-- The icon kind of each settlement (Round 44, world_map.md "Baked layer")
-- and the map window's marker layer it belongs to (Round 47 lane ML, "Map
-- window"), pure: no engine calls, so the portable fixtures run it as it
-- ships. A settlement's class comes from its anchor slot
-- (grug_core.settlement_socket_settlements). The minimap's image bakes every
-- settlement for everyone; the map window shows them in its layers, the
-- other faction's starts, capitals, villages, outposts and fortress included
-- (Round 47 ruling 5: the settlement and place layers show both factions;
-- it keeps Round 44's end of Round 31's per-viewer hiding). The hostile
-- camps (bandits, Mirefolk) have icons of their own that read as dangerous
-- (Round 32 §2.2).
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

-- The map window's layer of each kind (Round 47, the work package's §3):
-- towns under Towns, camps, mines and clash sites under POIs, the dragon
-- arenas and rare dens under Bosses (with the kings, the dragons and the
-- rift boss), fortresses and war camps under PvP.
M.LAYER = {start = "towns", capital = "towns", village = "towns", outpost = "towns",
	bandit = "pois", mirefolk = "pois", mine = "pois", clash = "pois",
	rare_den = "bosses", dragon = "bosses", king = "bosses", rift_boss = "bosses",
	fortress = "pvp", war_camp = "pvp"}

-- The layer of a settlement of `slot`, or nil (a slot of no known kind).
function M.layer(slot)
	local kind = M.kind(slot)
	return kind and M.LAYER[kind] or nil
end

-- A point of interest's tooltip word by slot (the work package: "kind +
-- name"); gem camps are the apex mines.
M.POI_WORD = {bandit = "Bandit camp", mirefolk = "Mirefolk camp", mine = "Mine",
	clash = "Clash site"}
function M.poi_word(slot)
	if slot == "apex_mine" then return "Gem camp" end
	return M.POI_WORD[M.kind(slot) or ""]
end

return M
