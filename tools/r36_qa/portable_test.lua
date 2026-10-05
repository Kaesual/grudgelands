-- Round 36 lane Q-A portable test: The Accord's main questline in the shipped
-- quest files (round36-plan.md §2.2-§2.8, the story bible
-- docs/planning/round36/story-bible.md).
-- Checks:
--   C  the chain: the spine in order, every step requiring the one before;
--      the chapter gates 41, 46, 53 and 60, each chapter's opener and its
--      folded climax requiring the previous chapter's last turn-in; no step
--      opens below a prerequisite (the shown gate is the real one);
--   T  the tag accord_main on every spine quest and on nothing else;
--   F  the final id accord_main_final: the Warmaster's turn-in, after the
--      finale, ending with the bible's last line; the finale on the rift
--      boss, "Group:", level 58-60;
--   S  the solo rule: no quest the final turn-in requires carries "Group:",
--      `group` or `optional`, except the finale;
--   B  behind the lines: the Throng captain's orders from the captain of
--      the Throng war camp on The Shattered Line, a sure quest drop; the
--      optional "Group:" hunt on the war commander in his camp; the raid on
--      that camp warns of him;
--   P  the bible's interaction uses for The Accord and both factions, each
--      in a quest at its place; the island uses only in optional quests.
--
-- Usage (repo root): luajit tools/r36_qa/portable_test.lua [REPO]
local repo = arg[1] or "."
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = io.open(path, "r")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Every quest of The Accord's files (the main line touches no other file).
local ZONES = repo .. "/mods/PLAYER/grug_quests/data/zones/"
local FILES = {"elandor_ashenward_march.quests.json", "elandor_ashenward_march.front.quests.json",
	"elandor_stormvault_heights.front.quests.json", "elandor_lethariel.front.quests.json",
	"elandor_highcourt.front.quests.json", "elandor_dur_brannoc.front.quests.json"}
local quests, file_of = {}, {}
for _, name in ipairs(FILES) do
	local text = read(ZONES .. name)
	if check(text ~= nil, "C quest file " .. name) then
		for _, q in ipairs(json.decode(text).quests) do
			quests[q.id], file_of[q.id] = q, name
		end
	end
end

local WM = "r31_accord_warmaster"
local TAG = "accord_main"
local FINAL = "accord_main_final"
local LAST_LINE = "We closed his account. Beneath us, someone turned a fresh page."

-- The spine in play order: {id, chapter}. Chapter openers and last
-- turn-ins below.
local SPINE = {
	{"accord_main_impounded", 1}, {"cinderline_front_05", 1}, {"cinderline_front_04", 1},
	{"archshadow_front_02", 1}, {"archshadow_front_03", 1}, {"accord_main_accounts", 1},
	{"accord_main_standard", 2}, {"lasthedge_front_04", 2}, {"accord_main_orders", 2}, {"accord_main_audit", 2},
	{"accord_main_roll", 3}, {"splitbolt_front_08", 3}, {"splitbolt_front_06", 3},
	{"lethariel_front_04", 3}, {"accord_main_tally", 3},
	{"accord_main_collector", 4}, {FINAL, 4},
}
local GATE = {41, 46, 53, 60}
local OPENER = {"accord_main_impounded", "accord_main_standard", "accord_main_roll", "accord_main_collector"}
local LAST = {"accord_main_accounts", "accord_main_audit", "accord_main_tally", FINAL}
-- The bible's folded climaxes and the chapter they carry.
local CLIMAX = {archshadow_front_03 = 1, lasthedge_front_04 = 2, splitbolt_front_08 = 3, lethariel_front_04 = 3}

local function has(list, value)
	for _, v in ipairs(list or {}) do if v == value then return true end end
	return false
end
-- Every quest `id` requires, transitively (itself not included).
local function closure(id, out)
	out = out or {}
	for _, req in ipairs(quests[id] and quests[id].requires or {}) do
		if not out[req] then
			out[req] = true
			closure(req, out)
		end
	end
	return out
end

------------------------------------------------------------------------------
-- C: the chain.
------------------------------------------------------------------------------
local in_spine = {}
for index, row in ipairs(SPINE) do
	local id, chapter = row[1], row[2]
	local q = quests[id]
	in_spine[id] = chapter
	if check(q ~= nil, "C spine quest " .. id .. " exists") then
		if index > 1 then
			local prev = SPINE[index - 1][1]
			check(has(q.requires, prev), "C " .. id .. " requires " .. prev)
			-- The thread: each step is given where the one before was turned
			-- in, or the one before sends the player on by name.
			local before = quests[prev]
			if before and before.turnin ~= q.giver then
				check(q.giver == WM and before.text:find("Warmaster", 1, true) ~= nil,
					"C " .. prev .. " sends the player on to " .. id .. "'s giver " .. q.giver)
			end
		end
		check(q.min_level >= GATE[chapter] and (chapter == 4 or q.min_level <= GATE[chapter + 1]),
			("C %s opens inside chapter %d (min_level %d)"):format(id, chapter, q.min_level))
		for _, req in ipairs(q.requires or {}) do
			if check(quests[req] ~= nil, "C " .. id .. ": prerequisite " .. req .. " is an Accord quest") then
				check(quests[req].min_level <= q.min_level,
					("C %s (min_level %d) opens no lower than %s (%d)"):format(id, q.min_level, req,
						quests[req].min_level))
			end
		end
	end
end
for chapter, id in ipairs(OPENER) do
	local q = quests[id]
	if q then
		eq(q.min_level, GATE[chapter], "C chapter " .. chapter .. " opens at its gate: " .. id)
		if chapter > 1 then
			check(has(q.requires, LAST[chapter - 1]), "C chapter " .. chapter .. "'s opener requires " ..
				LAST[chapter - 1])
		end
	end
end
eq(quests.accord_main_impounded and #quests.accord_main_impounded.requires, 0, "C chapter 1 needs nothing before 41")
for id, chapter in pairs(CLIMAX) do
	check(in_spine[id] == chapter, "C the folded climax " .. id .. " is a step of chapter " .. chapter)
	if chapter > 1 then
		check(closure(id)[LAST[chapter - 1]], "C " .. id .. " requires chapter " .. (chapter - 1) .. "'s last turn-in")
	end
end
for chapter = 2, 4 do
	for _, row in ipairs(SPINE) do
		if row[2] == chapter then
			check(closure(row[1])[LAST[chapter - 1]],
				"C " .. row[1] .. " follows chapter " .. (chapter - 1) .. "'s last turn-in")
		end
	end
end
eq(quests.accord_main_accounts and quests.accord_main_accounts.turnin, WM, "C chapter 1 ends at the Warmaster")
eq(quests.accord_main_audit and quests.accord_main_audit.turnin, WM, "C chapter 2 ends at the Warmaster")
eq(quests.accord_main_tally and quests.accord_main_tally.turnin, WM, "C chapter 3 ends at the Warmaster")

------------------------------------------------------------------------------
-- T: the tag.
------------------------------------------------------------------------------
for id, q in pairs(quests) do
	if in_spine[id] then
		check(has(q.tags, TAG), "T spine quest " .. id .. " carries " .. TAG)
	else
		check(not has(q.tags, TAG), "T " .. id .. " is no spine quest and carries no " .. TAG)
	end
end

------------------------------------------------------------------------------
-- F: the final turn-in and the finale.
------------------------------------------------------------------------------
local final, finale = quests[FINAL], quests.accord_main_collector
if check(final ~= nil, "F " .. FINAL .. " exists") then
	eq(final.giver, WM, "F the final quest is the Warmaster's")
	eq(final.turnin, WM, "F the last Warmaster turn-in")
	eq(file_of[FINAL], "elandor_ashenward_march.quests.json", "F on the Warmaster's own line")
	eq(final.line, "main", "F the Warmaster's second line")
	check(final.text:sub(-#LAST_LINE) == LAST_LINE, "F the final text ends with the bible's last line")
	check(has(final.requires, "accord_main_collector"), "F the report follows the finale")
end
if check(finale ~= nil, "F the finale exists") then
	eq(finale.title, "Group: The Collector Comes Due", "F the finale's title")
	check(finale.group == true and finale.optional == nil, "F the finale is a required group quest")
	eq(finale.objectives[1].type, "kill", "F the finale is a kill")
	eq(finale.objectives[1].roles[1], "rift_boss", "F on the rift boss")
	check(finale.level >= 58 and finale.level <= 60, "F the finale's reward level is 58-60")
	check((finale.text or ""):find("{name:r20_anchor_077}", 1, true) ~= nil, "F it points at Tombroad Ambush")
end
-- The finale's last text points below, never at the Nether.
for id in pairs(in_spine) do
	local q = quests[id]
	if q then
		check(not (q.title .. " " .. q.text):lower():find("nether"), "F " .. id .. " names no Nether")
	end
end

------------------------------------------------------------------------------
-- S: the solo rule.
------------------------------------------------------------------------------
local required = closure(FINAL)
required[FINAL] = true
for id in pairs(required) do
	local q = quests[id]
	if check(q ~= nil, "S required quest " .. tostring(id) .. " is an Accord quest") then
		local grouped = q.title:match("^Group: ") ~= nil or q.group == true
		if id == "accord_main_collector" then
			check(grouped, "S the finale is the group step")
		else
			check(not grouped, "S required step " .. id .. " is solo")
			check(not q.optional and not q.title:match("^Optional: "), "S required step " .. id .. " is not optional")
		end
	end
end
for id in pairs(in_spine) do check(required[id], "S spine quest " .. id .. " is required for the final turn-in") end

------------------------------------------------------------------------------
-- B: behind the lines.
------------------------------------------------------------------------------
local CAMP = "front_shattered_line/pvp_camp_shattered_line_throng_high"
local orders = quests.accord_main_orders
if orders then
	local obj = orders.objectives[1]
	eq(#orders.objectives, 1, "B the orders quest has one objective")
	eq(obj.type .. ":" .. tostring(obj.item), "item:grug_mobs:throng_captains_orders", "B bring the captain's orders")
	eq(obj.area, CAMP, "B from the Throng war camp on The Shattered Line")
	local drop = (orders.quest_drops or {})[1]
	check(drop and drop.item == obj.item and drop.chance == 1 and has(drop.roles, "captain_throng") and
		drop.area == CAMP, "B a sure quest drop of the camp's captain")
	check(not orders.title:match("^Group: ") and not orders.group, "B the captain step is solo")
end
local hunt = quests.accord_main_stonegrudge
if check(hunt ~= nil, "B the commander hunt exists") then
	check(hunt.title:match("^Group: ") and hunt.group == true and hunt.optional == true,
		"B the commander hunt is an optional Group: quest")
	eq(hunt.objectives[1].roles[1], "commander_throng", "B on the Throng war commander")
	eq(hunt.objectives[1].area, "front_gravesalt_escarpment/pvp_camp_gravesalt_escarpment_throng_high",
		"B in his camp")
	check(hunt.min_level >= 57, "B at his camp's level (the raids there open at 57)")
	check(has(hunt.requires, "accord_main_orders"), "B after the orders that name him")
end
local raid = quests.ashenward_bastion_warcamp_gravesalt
check(raid and raid.text:find("War Commander Stonegrudge", 1, true) ~= nil, "B the raid on his camp warns of him")

------------------------------------------------------------------------------
-- P: the interaction uses (bible §4: The Accord's rows and the shared ones).
------------------------------------------------------------------------------
local CLASH = {
	ashenward = {r20_anchor_071 = true, r20_anchor_072 = true},
	causeway = {r20_anchor_078 = true, r20_anchor_079 = true, r20_anchor_080 = true},
	shattered = {r20_anchor_081 = true, r20_anchor_082 = true, r20_anchor_083 = true},
	skyglass = {r20_anchor_084 = true, r20_anchor_085 = true},
}
local USES = {
	{"impounded_pay", "Unseal the impounded pay", CLASH.ashenward, 1},
	{"brand_rubbing", "Take a rubbing of the brand", {brandscar_cairn = true,
		["elandor_stormvault_heights/brandscar_cairn"] = true}, 1},
	{"toll_box", "Turn out the branded toll-box", CLASH.causeway, 1},
	{"courier_ledger", "Copy the courier's pay ledger", {["elandor_glassroot_wilds/couriers_stump"] = true}, 2},
	{"pledged_standard", "Unpick the pledged standard", CLASH.shattered, 2},
	{"tally_stone", "Strike the names from the tally", {r20_anchor_077 = true}, 3},
	{"rootmark", "Smother the burning rootmark", CLASH.skyglass, 3},
	{"survey_cairn", "Pry the brand-coin from the survey cairn", {r20_anchor_075 = true}, "island"},
	{"wreck_pay_chest", "Give the wreck's pay to the sea", {r20_anchor_086 = true}, "island"},
}
for _, row in ipairs(USES) do
	local kind, label, places, chapter = row[1], row[2], row[3], row[4]
	local found = {}
	for id, q in pairs(quests) do
		for _, obj in ipairs(q.objectives) do
			if obj.type == "use" and obj.object == kind then found[#found + 1] = {id = id, q = q, obj = obj} end
		end
	end
	if check(#found >= 1, "P " .. kind .. " is used") then
		for _, use in ipairs(found) do
			eq(use.obj.label, label, "P " .. use.id .. ": the bible's verb for " .. kind)
			check(places[use.obj.place], "P " .. use.id .. ": " .. kind .. " at its zone's place (" ..
				tostring(use.obj.place) .. ")")
			if chapter == "island" then
				check(use.q.optional == true and not required[use.id] and use.q.title:match("^Optional: ") ~= nil,
					"P " .. use.id .. ": an island use is an optional extension")
				check(closure(use.id).accord_main_roll, "P " .. use.id .. ": open once chapter 3 has begun")
			else
				eq(in_spine[use.id], chapter, "P " .. use.id .. ": " .. kind .. " in chapter " .. chapter)
			end
		end
	end
end

if failures > 0 then
	print(("R36 QA PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R36 QA PORTABLE PASS checks=%d"):format(checks))
