-- Round 36 lane Q-T portable test: The Throng's main line, "Our Oaths Are
-- Ours" (round36-plan.md §2.2-§2.8, the story bible
-- docs/planning/round36/story-bible.md), on the shipped quest files.
-- Checks:
--   C  the chapters: each opens at its gate (41, 46, 53, 60) with its first
--      quest, every step of it opens no earlier and depends on that first
--      quest, the first requires the previous chapter's last turn-in, and
--      each chapter ends with a turn-in at the Warmaster;
--   G  no quest's gate lies below a prerequisite's (validate.py
--      W-chain-gate) on the whole line;
--   T  the tag throng_main on exactly the spine: every quest the final
--      turn-in requires, directly or not, that the chapters name, and on no
--      optional branch;
--   F  the final turn-in: id throng_main_final at the Warmaster, after the
--      finale on the rift boss, ending with the bible's last line;
--   S  the solo rule: no "Group:" title or group flag on a required step
--      but the finale; the optional branches keep their prefixes;
--   P  the bible's interaction places (§4: the Throng's rows and the "Both"
--      rows): each object at the place of its zone, in a quest of its
--      chapter (the islands' in optional quests only), the Tombroad Ambush
--      tally-stone with the Throng's verb;
--   B  behind the lines: the captain of the Accord's high war camp on The
--      Shattered Line drops the orders (a quest drop) in a solo step; the
--      commander hunt is an optional group quest at the Skyglass camp, and
--      the raid on that camp warns of him.
--
-- Usage (repo root): luajit tools/r36_qt/portable_test.lua [REPO]
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

-- Every shipped quest by id, with its file's zone.
local ZONES = repo .. "/mods/PLAYER/grug_quests/data/zones/"
local quests, zone_of = {}, {}
local listing = io.popen('ls "' .. ZONES .. '"')
for name in listing:lines() do
	if name:match("%.quests%.json$") then
		local data = json.decode(assert(read(ZONES .. name), name))
		for _, quest in ipairs(data.quests) do
			quests[quest.id] = quest
			zone_of[quest.id] = data.zone
		end
	end
end
listing:close()

local WARMASTER = "r31_throng_warmaster"
local TAG = "throng_main"
local FINAL = "throng_main_final"
local FINALE = "throng_main_finale"
-- The chapters (bible §2, The Throng): gate, first quest, last turn-in and
-- every spine step.
local CHAPTERS = {
	{gate = 41, first = "throng_main_01", last = "throng_main_02",
		steps = {"throng_main_01", "bb_front_ramp_04", "bb_front_ramp_05", "throng_main_02"}},
	{gate = 46, first = "throng_main_03", last = "throng_main_05",
		steps = {"throng_main_03", "bb_front_torn_05", "throng_main_04", "throng_main_05"}},
	{gate = 53, first = "throng_main_06", last = "throng_main_07",
		steps = {"throng_main_06", "bw_front_ashveil_04", "kz_front_04", "throng_main_07"}},
	{gate = 60, first = FINALE, last = FINAL, steps = {FINALE, FINAL}},
}
local OPTIONAL = {"throng_main_greyvow", "throng_main_island_wreck", "throng_main_island_cairn"}

-- Every quest `id` requires, directly or not.
local function closure(id)
	local out, stack = {}, {id}
	while #stack > 0 do
		local q = quests[table.remove(stack)]
		for _, req in ipairs(q and q.requires or {}) do
			if not out[req] then
				out[req] = true
				stack[#stack + 1] = req
			end
		end
	end
	return out
end
local function has_tag(q)
	for _, tag in ipairs(q.tags or {}) do if tag == TAG then return true end end
	return false
end
local function is_group(q)
	return q.group == true or (q.title or ""):find("^Group:") ~= nil
end

------------------------------------------------------------------------------
-- C: the chapters.
------------------------------------------------------------------------------
local chapter_of = {}
for index, chapter in ipairs(CHAPTERS) do
	local first = quests[chapter.first]
	if check(first ~= nil, "C chapter " .. index .. ": " .. chapter.first .. " exists") then
		eq(first.min_level, chapter.gate, "C chapter " .. index .. " opens at its gate")
	end
	for _, id in ipairs(chapter.steps) do
		chapter_of[id] = index
		local q = quests[id]
		if check(q ~= nil, "C chapter " .. index .. ": " .. id .. " exists") then
			check(q.min_level >= chapter.gate, "C " .. id .. " opens no earlier than " .. chapter.gate)
			check(id == chapter.first or closure(id)[chapter.first],
				"C " .. id .. " depends on " .. chapter.first)
		end
	end
	local previous = CHAPTERS[index - 1]
	if previous and first then
		local direct = false
		for _, req in ipairs(first.requires or {}) do direct = direct or req == previous.last end
		check(direct, "C " .. chapter.first .. " requires the previous chapter's last turn-in " .. previous.last)
	end
	local last = quests[chapter.last]
	check(last and last.turnin == WARMASTER, "C chapter " .. index .. " ends at the Warmaster")
end
-- The Warmaster's free second line carries his part of the spine.
local mesa = json.decode(assert(read(ZONES .. "kragmar_bannerbreak_mesa.quests.json")))
local warmaster_lines
for _, hub in ipairs(mesa.hubs) do
	for _, giver in ipairs(hub.givers) do
		if giver.npc == WARMASTER then warmaster_lines = giver.lines end
	end
end
check(warmaster_lines and #warmaster_lines == 2 and warmaster_lines[1] == "front",
	"C the Warmaster has the front line and a second line")
for _, id in ipairs({"throng_main_01", "throng_main_03", "throng_main_04", "throng_main_05",
		"throng_main_06", FINALE}) do
	local q = quests[id]
	check(q and q.giver == WARMASTER and q.line == warmaster_lines[2],
		"C " .. id .. " is the Warmaster's, on his second line")
end

------------------------------------------------------------------------------
-- G: no gate below a prerequisite's on the line.
------------------------------------------------------------------------------
local line = closure(FINAL)
line[FINAL] = true
for _, id in ipairs(OPTIONAL) do line[id] = true end
local gated = 0
for id in pairs(line) do
	local q = quests[id]
	for _, req in ipairs(q and q.requires or {}) do
		gated = gated + 1
		check(quests[req] and q.min_level >= quests[req].min_level,
			"G " .. id .. " opens no earlier than its prerequisite " .. req)
	end
end
check(gated > 20, "G the line's prerequisites are checked (" .. gated .. ")")

------------------------------------------------------------------------------
-- T: the tag on exactly the spine.
------------------------------------------------------------------------------
local required = closure(FINAL)
required[FINAL] = true
local spine = 0
for id in pairs(chapter_of) do
	spine = spine + 1
	check(required[id], "T " .. id .. " is required by the final turn-in")
	check(quests[id] and has_tag(quests[id]), "T " .. id .. " carries " .. TAG)
end
eq(spine, 14, "T fourteen spine steps")
for id, q in pairs(quests) do
	if has_tag(q) then check(chapter_of[id] ~= nil, "T " .. id .. " is tagged but no spine step") end
end
for _, id in ipairs(OPTIONAL) do
	local q = quests[id]
	check(q and q.optional == true and not has_tag(q) and not required[id],
		"T " .. id .. " is an optional branch outside the spine")
end

------------------------------------------------------------------------------
-- F: the final turn-in.
------------------------------------------------------------------------------
local final, finale = quests[FINAL], quests[FINALE]
if check(final ~= nil and finale ~= nil, "F the finale and the final turn-in exist") then
	eq(final.turnin, WARMASTER, "F the final turn-in is at the Warmaster")
	check(#final.requires == 1 and final.requires[1] == FINALE, "F it follows the finale")
	local last_line = "His last blow struck the ground. The answering blow came from underneath."
	check(final.text:sub(-#last_line) == last_line, "F its text ends with the bible's last line")
	eq(finale.title, "Group: The Collector Comes Due", "F the finale's title")
	check(finale.level >= 58 and finale.level <= 60 and finale.min_level == 60, "F the finale at 60")
	local boss = finale.objectives[1]
	check(#finale.objectives == 1 and boss.type == "kill" and boss.roles[1] == "rift_boss" and
		#boss.roles == 1 and boss.area == nil, "F the finale kills the rift boss")
	check(finale.text:find("{name:r20_anchor_077}", 1, true) ~= nil, "F the finale names Tombroad Ambush")
end

------------------------------------------------------------------------------
-- S: solo through chapter 3.
------------------------------------------------------------------------------
for id in pairs(required) do
	local q = quests[id]
	if q and id ~= FINALE then
		check(not is_group(q) and not q.optional, "S required step " .. id .. " is solo and not optional")
	end
end
check(is_group(quests.throng_main_greyvow), "S the commander hunt is a Group: quest")
for _, id in ipairs({"throng_main_island_wreck", "throng_main_island_cairn"}) do
	check(quests[id] and quests[id].title:find("^Optional: ") ~= nil, "S " .. id .. " keeps the Optional: prefix")
end

------------------------------------------------------------------------------
-- P: the interaction places (bible §4).
------------------------------------------------------------------------------
local clash_zone = {}
for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua").roster) do
	if row.art and row.art.kind == "clash" then clash_zone[row.key] = row.zone_id end
end
local function place_zone(place)
	return clash_zone[place] or place:match("^([%w_]+)/")
end
-- object -> zone of its place, chapter (nil: optional), label.
local PLACES = {
	false_requisition = {"kragmar_bannerbreak_mesa", 1, "Break the false requisition seal"},
	ash_slab = {"kragmar_blackwind_rise", 1, "Wash fresh ash from old stone"},
	toll_box = {"front_broken_causeway", 1, "Turn out the branded toll-box"},
	branded_pay_pit = {"kragmar_thunderroot_wilds", 2, "Bury the branded pay unspent"},
	pledged_standard = {"front_shattered_line", 2, "Unpick the pledged standard"},
	tally_stone = {"front_gravesalt_escarpment", 3, "Burn our dead off the tally"},
	rootmark = {"front_skyglass_canopy", 3, "Smother the burning rootmark"},
	survey_cairn = {"front_wyrmglass_crown", nil, "Pry the brand-coin from the survey cairn"},
	wreck_pay_chest = {"front_stormscale_summit", nil, "Give the wreck's pay to the sea"},
}
local found = {}
for id, q in pairs(quests) do
	if line[id] then
		for _, objective in ipairs(q.objectives) do
			if objective.type == "use" then
				local want = PLACES[objective.object]
				if check(want ~= nil, "P " .. id .. ": " .. tostring(objective.object) .. " is a Throng object") then
					found[objective.object] = (found[objective.object] or 0) + 1
					eq(place_zone(objective.place), want[1], "P " .. objective.object .. "'s place zone")
					eq(objective.label, want[3], "P " .. objective.object .. "'s verb")
					if want[2] then
						eq(chapter_of[id], want[2], "P " .. objective.object .. " in a quest of its chapter")
					else
						check(q.optional == true and not required[id],
							"P " .. objective.object .. " only in an optional quest")
					end
				end
			end
		end
	end
end
for object in pairs(PLACES) do eq(found[object], 1, "P " .. object .. " is used once") end
local tally
for _, objective in ipairs(quests.throng_main_07 and quests.throng_main_07.objectives or {}) do
	if objective.object == "tally_stone" then tally = objective end
end
eq(tally and tally.place, "r20_anchor_077", "P the tally-stone stands at Tombroad Ambush")

------------------------------------------------------------------------------
-- B: behind the lines.
------------------------------------------------------------------------------
local CAMP = "front_shattered_line/pvp_camp_shattered_line_accord_high"
local ORDERS = "grug_mobs:accord_captains_orders"
local orders = quests.throng_main_04
if check(orders ~= nil and chapter_of.throng_main_04 == 2, "B the orders are a chapter-2 step") then
	local kills, wants = false, false
	for _, objective in ipairs(orders.objectives) do
		if objective.type == "kill" then
			kills = objective.roles[1] == "captain_accord" and #objective.roles == 1 and objective.area == CAMP
		elseif objective.type == "item" then
			wants = objective.item == ORDERS and objective.count == 1
		end
	end
	check(kills, "B kill the captain of the Accord's high war camp on The Shattered Line")
	check(wants, "B bring his orders")
	local drop = orders.quest_drops and orders.quest_drops[1]
	check(drop and drop.item == ORDERS and drop.roles[1] == "captain_accord" and drop.area == CAMP and
		drop.chance == 1, "B the captain drops the orders as a quest drop")
end
local hunt = quests.throng_main_greyvow
if check(hunt ~= nil, "B the commander hunt exists") then
	local target = hunt.objectives[1]
	check(target.roles[1] == "commander_accord" and
		target.area == "front_skyglass_canopy/pvp_camp_skyglass_canopy_accord_high",
		"B the hunt names the Accord's commander in the Skyglass war camp")
	check(hunt.optional == true and hunt.group == true and hunt.min_level >= 57,
		"B the hunt is optional, Group: and at the camp's level")
	check(hunt.requires[1] == "throng_main_05", "B the hunt opens with the orders' reading")
end
local raid = quests.bannerbreak_warhold_warcamp_skyglass
check(raid and raid.text:find("Greyvow", 1, true) ~= nil and #raid.requires == 1 and not has_tag(raid),
	"B the raid on that camp warns of the commander and stays ungated")

if failures > 0 then
	print(("R36 QT PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R36 QT PORTABLE PASS checks=%d"):format(checks))
