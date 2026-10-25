-- Round 56 lane QUESTMAP portable test (LuaJIT):
--   F  flags.lua on a small hand-made quest set: the signature (types and
--      targets; counts, areas and levels ignored; a travel quest has none),
--      same-in-start-towns only between start zones, repeated across zones,
--      a reward that is a requested item, the kill-only run through a quest
--      (a non-kill quest breaks it), ancestors, depth and unlocks;
--   M  model.lua over the shipped quests (the real loader): every quest once,
--      copper from the loader's formula unless a quest sets its own, XP from
--      grug_quests.reward_xp's formula, names on every kill, every giver in a
--      hub; the start towns' wooden tools quest is flagged;
--   V  (Round 57) the model of tools/r57_qsys's samples: a shared quest's
--      variants, a story quest, a choice of rewards with its enchants;
--   P  questmap.lua writes one page with the data in place of its marker.
-- Usage (repo root): luajit tools/r56_questmap/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function has(list, value)
	for _, v in ipairs(list) do if v == value then return true end end
	return false
end

-- F ---------------------------------------------------------------------------
local F = dofile(repo .. "/tools/r56_questmap/flags.lua")
local function kill(role, count, area) return {type = "kill", roles = {role}, count = count or 8, area = area} end
local function item(name, count) return {type = "item", item = name, count = count or 1} end
local function q(id, zone, requires, objectives, rewards)
	return {id = id, zone = zone, requires = requires or {}, objectives = objectives,
		rewards = {items = rewards or {}}}
end
local zones = {{id = "start_a", level_min = 1}, {id = "start_b", level_min = 1}, {id = "mid", level_min = 11}}
local quests = {
	q("a1", "start_a", {}, {kill("boar", 8, "start_a/fields")}),
	q("a2", "start_a", {"a1"}, {kill("rat")}),
	q("a3", "start_a", {"a2"}, {kill("fox")}),
	q("a4", "start_a", {"a3"}, {kill("crab")}),
	q("a5", "start_a", {"a4"}, {{type = "talk", npc = "steward", count = 1}}),
	q("a6", "start_a", {"a5"}, {kill("wolf")}),
	q("tools_a", "start_a", {}, {item("axe_wood"), item("pick_wood")},
		{{item = "axe_wood", count = 1}, {item = "pick_wood", count = 1}}),
	q("b1", "start_b", {}, {kill("boar", 6, "start_b/woods")}),
	q("tools_b", "start_b", {}, {item("pick_wood"), item("axe_wood")}, {{item = "furnace", count = 1}}),
	q("m1", "mid", {"a5"}, {kill("boar")}),
	q("m2", "mid", {"m1", "tools_a"}, {{type = "talk", npc = "elder", count = 1}}),
}
local result = F.analyse(quests, zones)
local f = result.by_id
eq(F.signature(quests[1]), F.signature(quests[8]), "F counts and areas do not split a signature")
eq(F.signature(quests[7]), F.signature(quests[9]), "F objective order does not split a signature")
eq(F.signature(quests[5]), false, "F a travel quest has no signature")
check(has(f.a1.flags, "start_twin") and has(f.b1.flags, "start_twin"), "F boars in two start towns")
check(not has(f.m1.flags, "start_twin"), "F a mid zone is no start town")
check(has(f.m1.flags, "repeated") and f.m1.family_zones == 3, "F boars repeated in three zones")
check(not has(f.a2.flags, "repeated"), "F a rat in one zone repeats nothing")
check(not has(f.a5.flags, "repeated") and not has(f.m2.flags, "repeated"), "F travel quests never repeat")
check(has(f.tools_a.flags, "reward_is_request") and #f.tools_a.reward_items == 2, "F tools back as reward")
check(not has(f.tools_b.flags, "reward_is_request"), "F another reward is fine")
eq(f.a1.kill_chain, 4, "F kill run a1..a4")
eq(f.a3.kill_chain, 4, "F the run counts through a quest")
eq(f.a5.kill_chain, 0, "F a travel quest is no kill run")
eq(f.a6.kill_chain, 1, "F a travel quest breaks the run")
check(has(f.a4.flags, "kill_chain") and not has(f.a6.flags, "kill_chain"),
	"F a run of LIMITS.kill_chain is flagged")
eq(f.m2.ancestors, 7, "F ancestors through every path, each once")
eq(f.m2.depth, 7, "F depth is the longest path")
check(#f.a5.unlocks == 2 and has(f.a5.unlocks, "a6") and has(f.a5.unlocks, "m1"), "F unlocks")
local saved = F.LIMITS.ancestors
F.LIMITS.ancestors = 7
check(has(F.analyse(quests, zones).by_id.m2.flags, "deep"), "F deep at LIMITS.ancestors")
F.LIMITS.ancestors = saved
check(not has(f.m2.flags, "deep"), "F not deep below it")

-- M ---------------------------------------------------------------------------
local model = dofile(repo .. "/tools/r56_questmap/model.lua")(repo)
-- (Round 61: 392 ship after the band 31-40's rework.)
check(#model.quests > 380, "M the shipped quests load (" .. #model.quests .. ")")
eq(#model.warnings, 0, "M the loader logs nothing")
check(rawget(_G, "grug_quests") == nil and rawget(_G, "core") == nil, "M the model puts its globals back")
-- The two formulas on their own, under a do-nothing engine (model.lua put
-- its globals back).
local permissive = {__index = function() return function() end end}
rawset(_G, "core", setmetatable({}, permissive))
rawset(_G, "grug_core", setmetatable({}, permissive))
rawset(_G, "grug_quests", {})
dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
local copper = grug_quests.quest_copper
dofile(repo .. "/mods/PLAYER/grug_xp/init.lua")
local seen, bad_copper, bad_xp, no_name, no_hub = {}, 0, 0, 0, 0
for _, quest in ipairs(model.quests) do
	check(not seen[quest.id], "M quest once: " .. quest.id)
	seen[quest.id] = true
	if not quest.rewards.copper_fixed and quest.rewards.copper ~= copper(quest.level, quest.rewards.weight) then
		bad_copper = bad_copper + 1
	end
	if quest.rewards.xp ~= grug_xp.quest_reward(quest.level, quest.rewards.weight) then bad_xp = bad_xp + 1 end
	for _, objective in ipairs(quest.objectives) do
		if objective.type == "kill" and #objective.names == 0 then no_name = no_name + 1 end
	end
	-- Round 58: a quest given by a role (the gather quests' foremen) has no hub.
	if not quest.hub and #quest.variants[1].givers > 0 then no_hub = no_hub + 1 end
end
eq(bad_copper, 0, "M copper is the loader's formula")
eq(bad_xp, 0, "M XP is the reward formula")
eq(no_name, 0, "M every kill names its targets")
eq(no_hub, 0, "M every quest's giver stands in a hub")
local facts = F.analyse(model.quests, model.zones).by_id
-- Round 57: the start zones' tool swaps are gone and their common tasks are
-- shared quests, one row each (tools/r57_startquests).
do
	local swaps, boars = 0, nil
	for _, quest in ipairs(model.quests) do
		if has(facts[quest.id].flags, "reward_is_request") then swaps = swaps + 1 end
		if quest.id == "start_boars" then boars = quest end
	end
	eq(swaps, 0, "M no shipped quest rewards what it requests")
	check(boars and boars.shared and #boars.variants == 6, "M the start boars are one row with six variants")
end

-- V (Round 57): a shared quest, a story quest and a choice of rewards, on
-- tools/r57_qsys's sample files (Dawnmere Fields and Sunscar Flats).
do
	local sample = dofile(repo .. "/tools/r56_questmap/model.lua")(repo, repo .. "/tools/r57_qsys/samples/grug_quests")
	local by_id = {}
	for _, quest in ipairs(sample.quests) do by_id[quest.id] = quest end
	local crop = by_id.qs_crop_thieves
	check(crop and crop.shared and #crop.variants == 2, "V the shared quest is one row with two variants")
	eq(crop and crop.variants[2].zone, "kragmar_sunscar_flats", "V ...its second variant's zone")
	eq(crop and crop.variants[2].giver_names[1], "Gara Stonevoice", "V ...and giver")
	eq(crop and crop.variants[1].hub, "dawnmere", "V the first variant's hub")
	eq(crop and crop.variants[2].hub, "sunscar", "V the second variant's hub")
	check(crop and crop.variants[2].text:find("[place]", 1, true) == nil and
		crop.variants[2].text:find("Piglets dig up", 1, true) ~= nil, "V the variant's own text")
	eq(crop and #crop.rewards.choices, 2, "V the choice of rewards")
	check(crop and crop.completion and crop.completion:find("quiet again", 1, true), "V the completion text")
	check(by_id.qs_story_landing and by_id.qs_story_landing.story, "V the story quest is marked")
	eq(by_id.qs_final and by_id.qs_final.rewards.choices[1].affixes[2], "suffix crit_percent", "V a choice's enchants")
	eq(by_id.qs_guild_stone and by_id.qs_guild_stone.variants[1].giver_names[1], "every foreman of the throng",
		"V a role giver")
end

-- P ---------------------------------------------------------------------------
local out = os.tmpname()
local _, said = dofile(repo .. "/tools/r56_questmap/questmap.lua")(repo, out)
local handle = io.open(out, "r")
local page = handle and handle:read("*a") or ""
if handle then handle:close() end
os.remove(out)
check(said:find("questmap: ", 1, true) ~= nil, "P the tool reports")
check(page:find("__QUESTMAP_DATA__", 1, true) == nil, "P the marker is replaced")
check(page:find('"id":"start_boars"', 1, true) ~= nil, "P the data is in the page")
check(page:find("<title>", 1, true) ~= nil and page:find("http", 1, true) == nil, "P one page, no network")

if failures > 0 then
	error(("R56 QUESTMAP PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R56 QUESTMAP PORTABLE PASS checks=%d"):format(checks))
