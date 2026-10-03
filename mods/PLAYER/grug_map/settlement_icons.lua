-- Settlement icons per viewer faction (Round 31, the user's ruling after the
-- lane-M preview), pure: no engine calls, so tools/r31_m/portable_test.lua
-- runs it as it ships. The terrain map is the same for everyone; a faction's
-- own places are no icon for the other faction. A settlement's class comes
-- from its anchor slot (grug_core.settlement_socket_settlements). HIDDEN lists
-- the classes the enemy does not see, so hiding another class is one entry
-- there. Seen by everyone: the Battlegrounds war camps (quest targets) and
-- every neutral place (bandit and Mirefolk camps, mines, clash sites, the
-- dragon arenas). The kings and dragons are NPC markers (providers.lua).
-- HOSTILE lists the classes of hostile camps (Round 32 §2.2): their own
-- symbol and colour on the Map tab (page.lua), never the quest giver's "!".
local M = {}

M.HIDDEN = {start = true, capital = true, village = true, outpost = true, fortress = true}
M.HOSTILE = {bandit = true, mirefolk = true}

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

-- Whether a settlement of `slot` is a hostile camp (bandits, Mirefolk).
function M.hostile(slot)
	return M.HOSTILE[M.class(slot)] == true
end

-- Whether a settlement of `slot` owned by `owner` (a faction id, nil for
-- none) shows its icon to `viewer` (a faction id, "" or nil for none).
function M.visible(slot, owner, viewer)
	return not (M.HIDDEN[M.class(slot)] and owner ~= viewer)
end

return M
