-- Round 58 lane GUILDQUESTS: the Miner's Guild's settlements for the
-- portable quest harnesses that load the shipped quest files without a
-- world (tools/r28_q0, tools/r27_quest_item_names, tools/r56_questmap, this
-- lane's fixture). The shipped files name the camps' foremen and the guild
-- leaders, whom grug_quests/npcs.lua registers only where the world has the
-- camp and the capital (grug_mapgen.mining_camps, the settlement sockets).
--
--   local W = dofile(REPO .. "/tools/r58_guildquests/guild_world.lua")(REPO)
--   W.mining_camps          grug_mapgen.mining_camps' shape: {camps, under_construction}
--   W.camp_catalog          r58_camp_catalog.lua (pvp_garrison.new's third argument)
--   W.race_of[key]          the race a camp, a camp site or a capital registers as
--   W.anchor(key)           an anchor for those settlements, else nil
--   W.records()             {key, race_id} rows of those settlements
--
-- The camps are the real camp module's (wp40/r58_camps.lua) over a layout
-- that puts every anchor at the origin: ids, factions, tiers and zones do
-- not depend on positions. A war camp's race is rolled per world; here it
-- is its faction's first race (the faction is what the quests read).
-- Plain Lua 5.1 / LuaJIT, no globals.
return function(repo)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local module = dofile(wp40 .. "/r58_camps.lua")
	local anywhere = setmetatable({}, {__index = function() return {x = 0, z = 0} end})
	local W = {camp_catalog = dofile(wp40 .. "/r58_camp_catalog.lua")}
	local FIRST_RACE = {accord = "human", throng = "orc"}
	W.CAPITAL_RACE = {highcourt = "human", dur_brannoc = "dwarf", lethariel = "elf",
		nhal_veyr = "undead", gor_drazhak = "orc", kezamba = "troll"}
	local camps = module.camps(anywhere)
	for _, camp in ipairs(camps) do camp.race = camp.race or FIRST_RACE[camp.faction] end
	W.mining_camps = {camps = camps, under_construction = module.under_construction(anywhere)}
	W.race_of = {}
	for _, camp in ipairs(camps) do W.race_of[camp.id] = camp.race end
	for _, site in ipairs(W.mining_camps.under_construction) do W.race_of[site.id] = site.race end
	for key, race in pairs(W.CAPITAL_RACE) do W.race_of[key] = race end
	function W.anchor(key)
		return W.race_of[key] and {x = 0, y = 0, z = 0} or nil
	end
	function W.records()
		local out = {}
		for key, race in pairs(W.race_of) do out[#out + 1] = {key = key, race_id = race} end
		table.sort(out, function(a, b) return a.key < b.key end)
		return out
	end
	return W
end
