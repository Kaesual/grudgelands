-- Disposable engine probe (Round 31 lane Q). Never shipped:
-- tools/r31_q/run.sh stages it through tools/luanti_headless.sh.
--
-- The boot itself proves the fortress quests pass the load-time checks
-- against the real registries. After every mod loaded it checks, on this
-- world's region maps and settlement registry:
--   1. both fortresses' three quest givers stand at their sockets and serve
--      their fortress's faction (lane N's filter, the map's quest markers);
--   2. every fortress quest's area is the tag lane G's garrison carries
--      (pvp_garrison.area) for an enemy camp; its objectives show the
--      camp's level band;
--   3. every text fills without a placeholder left, and each
--      {dir_from_giver:<camp or fortress>} reads the compass word from the
--      giver's socket to that POI's anchor (the quest points at the right
--      camp).
local P = "[r31_q_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then core.log("error", P .. "FAIL " .. msg) end
	end
	return ok
end

local function run()
	local Q, garrison, regions = grug_quests, grug_mobs.pvp_garrison, grug_mobs.spawn_regions
	local core_regions = regions.core
	local fortress_givers = {}
	for _, faction in ipairs({"accord", "throng"}) do
		local key = "pvp_fortress_" .. faction
		for _, role in ipairs({"warmaster", "drillmaster", "outrider"}) do
			local id = "r31_" .. faction .. "_" .. role
			local npc = Q.registered_npcs[id]
			if check(npc ~= nil, id .. " is registered") then
				check(npc.settlement == key and npc.socket == "quest_" .. role, id .. " at its socket")
				check(npc.faction == faction, id .. " serves the " .. faction .. " (got " .. tostring(npc.faction) .. ")")
				fortress_givers[id] = faction
			end
		end
	end
	local function socket_pos(id)
		local npc = Q.registered_npcs[id]
		for _, socket in ipairs(grug_core.settlement_sockets_at(npc.settlement)) do
			if socket.id == npc.socket then return socket.pos end
		end
	end
	local quests, camps, directions = 0, 0, 0
	local ids = {}
	for id, def in pairs(Q.registered_quests) do
		if fortress_givers[def.npc] or fortress_givers[def.turnin_npc] then ids[#ids + 1] = id end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		quests = quests + 1
		local faction = Q.registered_npcs[def.npc].faction
		for _, objective in ipairs(def.objectives) do
			local key = objective.area and objective.area:match("/(pvp_camp_.+)$")
			if key then
				local row = garrison.poi(key)
				check(row and row.faction ~= faction, id .. ": an enemy camp")
				check(garrison.area(key) == objective.area, id .. ": the garrison's own area tag")
				check(objective.levels ~= nil, id .. ": the objective shows the camp's levels")
				if objective.mobs[1]:find("captain") then camps = camps + 1 end
			end
		end
		local text = Q.quest_text(def, true)
		check(not text:find("{", 1, true), id .. ": filled text: " .. text)
		check(not def.title:find("{", 1, true), id .. ": filled title: " .. def.title)
		for target in def.description:gmatch("{dir_from_giver:([%w_/]+)}") do
			local place = regions.place(target:match("[^/]+$"))
			local from = socket_pos(def.npc)
			if check(place and from, id .. ": " .. target .. " has an anchor and the giver a socket") then
				local dir = core_regions.compass(from.x, from.z, place.x, place.z)
				local d = math.sqrt((place.x - from.x) * (place.x - from.x) + (place.z - from.z) * (place.z - from.z))
				local want = d < core_regions.NEAR and "nearby" or (dir .. " from here")
				check(text:lower():find(want, 1, true) ~= nil, id .. ": points " .. want .. ": " .. text)
				directions = directions + 1
			end
		end
		log(("%s [%s] %s | %s"):format(id, def.npc, def.title, text:match("^[^\n]*")))
	end
	check(quests == 24, "24 quests at or to the fortresses (got " .. quests .. ")")
	check(camps == 16, "16 camp raids (got " .. camps .. ")")
	log(("fortress quests %d, camp raids %d, directions checked %d"):format(quests, camps, directions))
	log(("RESULT %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
