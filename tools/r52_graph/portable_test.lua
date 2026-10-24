-- Round 52 lane GRAPH portable test, rewritten for the live graph in Round 53
-- (round53-plan.md §4 "LIVE": the four class data files, <tree>_<name> ids,
-- the live page). Loads, on the stub world of tools/r44_ts/harness.lua (the
-- REAL sfinv, grug_inventory/ui.lua, talents.lua with the graph files it
-- loads, talents_ui.lua, talent_graph_ui.lua and grug_skills), and checks:
--   A. the registry against the node list: 8 trees, 109 nodes, 263 ranks
--      (Warding Faith at 5 ranks), the per-tree counts of node-list.md §1,
--      every code, the ids "<tree>_<name>", the vocabulary, the icons by
--      the name part (K5);
--   B. the audit refuses broken trees (a cycle, an unreachable node, a rank
--      sum, a key, a param, two ultimates, a granting node without an
--      ability, a prerequisite of a higher gate, a shared cell, an id
--      without its tree prefix, a sample build that is not legal) and
--      accepts a tree whose filler needs further ranks of a needed node
--      (the reach_cost note of Round 52);
--   C. the candidates' worked 30-point builds, adapted to the node list
--      (each adaptation below), bought rank by rank; the trees' sample
--      builds are the pure ones;
--   D. the gates on both paths with the same texts: illegal spends refused,
--      the read path drops the same ranks with the same reasons, a forged
--      pair of gates that only pay for each other, the refund down to the
--      budget, the full reset, the round trip;
--   E. the live Talents page: one tab per tree with the choice in the sfinv
--      context, the background or the plain fallback at D5's rectangle, the
--      connectors (a multi-parent node, a prerequisite in the same row),
--      icon and text nodes, the sample build's node states, a selected
--      node's text and refusal; the layout of all eight trees (no line
--      through a node, no line into a node from under another, everything
--      inside the rectangle);
--   F. the skill row (C13): more than eight skills scroll, the value is kept
--      in the sfinv context across a pure scrollbar event, a page event and
--      a rebuild, clamped when the row shrinks; a drag from a slot past the
--      eighth works.
-- Prints the page content's bytes per tree with its sample build (a
-- comparison, not a target).
--
-- Usage (repo root): luajit tools/r52_graph/portable_test.lua [repo]
--
-- Adaptations of the candidates' builds to the node list (C):
--   * pure Mercy (priest.md §5) spent 3 points on M12 Shelter, which is cut
--     (node-list.md §5 item 1): two go to Warding Faith's ranks 4-5, where
--     Shelter's value went (the user, 2026-10-20), one to Lasting Haven;
--   * priest.md writes Reckoning as R1-R14: read RK1-RK14 (node list);
--   * the renames (Aimed Shot -> True Draw, Ice Armor -> Rime Mantle) change
--     no code.

local repo = arg and arg[1] or "."
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
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (found " .. ("%q"):format(part) .. ")")
end

-- One talent icon, one background and one skill icon are hidden, so both
-- paths of each fallback are drawn (the skill icon also before and after
-- the new skills' icons ship).
local HIDDEN = {"grug_classes_talent_measured_fuel.png", "grug_classes_tree_rime.png",
	"grug_abilities_skill_flame_lance.png"}
local H = dofile(repo .. "/tools/r44_ts/harness.lua")(repo, HIDDEN)
local graph = grug_classes.graph
local function node(code) return graph.codes[code] end

--
-- A. The registry against the node list.
--

local SUMMARY = { -- node-list.md §1 (Mercy: M5 at 5 ranks): nodes, ranks, unlocks,
	-- transforms, windows, modifiers
	ember = {13, 32, 3, 0, 0, 9}, rime = {14, 33, 2, 2, 1, 8},
	bulwark = {14, 33, 2, 2, 0, 9}, ruin = {14, 33, 2, 1, 0, 10},
	mercy = {13, 33, 3, 0, 1, 8}, reckoning = {14, 34, 3, 0, 0, 10},
	quarry = {13, 32, 3, 0, 1, 8}, veil = {14, 33, 3, 1, 0, 9},
}
local CLASS = {ember = "mage", rime = "mage", bulwark = "warrior", ruin = "warrior",
	mercy = "priest", reckoning = "priest", quarry = "scout", veil = "scout"}
eq(table.concat(graph.tree_ids, ","), "ember,rime,bulwark,ruin,mercy,reckoning,quarry,veil",
	"A the eight trees in class order")
eq(#graph.node_ids, 109, "A 109 nodes")
local all_ranks = 0
for _, tree_id in ipairs(graph.tree_ids) do
	local tree, want = graph.trees[tree_id], SUMMARY[tree_id]
	local count = {unlock = 0, transform = 0, window = 0, modifier = 0, ultimate = 0}
	local ranks = 0
	for _, def in ipairs(tree.nodes) do
		count[def.type] = count[def.type] + 1
		ranks = ranks + def.ranks
		check(def.id:sub(1, #tree_id + 1) == tree_id .. "_", "A " .. def.id .. " is <tree>_<name>")
		eq(tree_id .. "_" .. def.icon_name, def.id, "A " .. def.id .. ": its name part")
	end
	all_ranks = all_ranks + ranks
	eq(tree.class, CLASS[tree_id], "A " .. tree_id .. ": its class")
	eq(#tree.nodes, want[1], "A " .. tree_id .. ": nodes")
	eq(ranks, want[2], "A " .. tree_id .. ": ranks")
	eq(count.unlock, want[3], "A " .. tree_id .. ": unlocks")
	eq(count.transform, want[4], "A " .. tree_id .. ": transforms")
	eq(count.window, want[5], "A " .. tree_id .. ": windows")
	eq(count.modifier, want[6], "A " .. tree_id .. ": modifiers")
	eq(count.ultimate, 1, "A " .. tree_id .. ": one ultimate")
end
eq(all_ranks, 263, "A 263 ranks")
local codes = {}
for prefix, last in pairs({F = 13, R = 14, B = 14, U = 14, M = 14, RK = 14, Q = 13, V = 14}) do
	for n = 1, last do
		local code = prefix .. n
		if code == "M12" then
			eq(graph.codes[code], nil, "A M12 Shelter is cut")
		else
			codes[#codes + 1] = code
			check(graph.codes[code] ~= nil, "A node " .. code .. " is registered")
		end
	end
end
eq(#codes, 109, "A every node list code")
-- The node list's prerequisites, rank counts, gates and types, spot-checked
-- where the graph differs from the old chains.
eq(table.concat(node("R10").requires, "+"), "rime_ice_nova+rime_cold_spark",
	"A Cold Shock has two prerequisites")
eq(table.concat(node("V12").requires, "+"), "veil_opening+veil_parry",
	"A Close Dance has two prerequisites")
eq(node("F12").type .. node("F12").gate .. node("F12").ranks, "ultimate201",
	"A Fire Rain: ultimate, gate 20, one rank")
eq(node("U14").ranks, 1, "A Reach the Fight has one rank")
eq(node("M5").ranks, 5, "A Warding Faith has 5 ranks (the user, 2026-10-20)")
eq(node("M5").id, "mercy_warding_faith", "A the node list's own example id")
eq(node("R1").ability, "cold_spark", "A a transform names its ability only")
eq(node("R1").replaces, nil, "A and no `replaces`")
eq(node("M3").ability, "shield_spell", "A Shield is today's ability id")
eq(node("B12").id, "bulwark_unbroken", "A Unbroken's id carries its tree prefix")
-- The vocabulary (D4): shared keys, class keys, families with a class param.
check(graph.valid_key("warrior", "rage_per_swing_add"), "A a warrior key")
check(not graph.valid_key("mage", "rage_per_swing_add"), "A not a mage key")
check(graph.valid_key("mage", "damage_pct:fire"), "A a family with a mage param")
check(not graph.valid_key("warrior", "damage_pct:fire"), "A not with a warrior")
check(not graph.valid_key("mage", "fire_damage_pct"), "A an unknown key")
check(graph.valid_key("scout", "dodge_chance_add"), "A a shared key")
eq(node("RK8").effects["damage_pct:paid"][3], 9, "A Hard Faith's damage_pct:paid (node list)")
eq(grug_classes.TALENT_EFFECT_KEYS, nil, "A the old EFFECT_KEYS are gone (INTEG part 2)")
-- No player text carries a unit letter of the node list's notation
-- (round53-plan.md §3): D, S, R, M, B, P, K, Q, F or W+I after a number.
for _, id in ipairs(graph.node_ids) do
	local text = graph.nodes[id].description
	check(not text:find("%d[DSRMBPKQF]%f[%W]") and not text:find("W%+I", 1, false) and
		not text:find("%d ?x [QF]%f[%W]"), "A " .. id .. "'s text has no unit letter: " .. text)
end
-- The icons (K5): a talent node shows grug_classes_talent_<name part>.png,
-- every picked one ships (one hidden here); a granting node its skill's.
for _, tree_id in ipairs(graph.tree_ids) do
	eq(H.textures["grug_classes_tree_" .. tree_id .. ".png"] or false, tree_id ~= "rime",
		"A art: the " .. tree_id .. " background ships (Rime hidden here)")
end
local talent_icons = 0
for _, id in ipairs(graph.node_ids) do
	local def = graph.nodes[id]
	if not def.ability then
		local want = id ~= "ember_measured_fuel" and
			"grug_classes_talent_" .. def.icon_name .. ".png" or nil
		eq(graph.icon_texture(def), want, "A art: " .. def.code .. "'s talent icon")
		if want then talent_icons = talent_icons + 1 end
	end
end
eq(talent_icons, 73, "A art: 73 talent icons by the name part (one hidden)")
eq(graph.icon_texture(node("F4")), "grug_abilities_skill_fireball.png",
	"A art: Fireball shows its skill's icon")
eq(graph.icon_texture(node("F5")), nil, "A art: Flame Lance without its (hidden) icon")

--
-- B. The audit refuses broken trees: a fresh registry per case.
--

local function audit_error(mutate)
	local saved = grug_classes
	grug_classes = {registered_classes = saved.registered_classes}
	dofile(repo .. "/mods/PLAYER/grug_classes/talent_graph.lua")
	local g = grug_classes.graph
	g.register_class_vocabulary("mage", {params = {"fire", "bolt", "storm"}})
	local tree = {id = "t", class = "mage", name = "T", ranks = 31, nodes = {
		{id = "t_a", code = "A1", name = "A", type = "modifier", ranks = 5, gate = 0, col = 1,
			effects = {["damage_pct:fire"] = {1, 2, 3, 4, 5}}},
		{id = "t_b", code = "A2", name = "B", type = "modifier", ranks = 5, gate = 0, col = 2},
		{id = "t_c", code = "A3", name = "C", type = "unlock", ability = "bolt", ranks = 1,
			gate = 2, col = 1, requires = {"t_a"}},
		{id = "t_d", code = "A4", name = "D", type = "modifier", ranks = 5, gate = 6, col = 1,
			requires = {"t_c"}},
		{id = "t_e", code = "A5", name = "E", type = "modifier", ranks = 5, gate = 10, col = 1},
		{id = "t_f", code = "A6", name = "F", type = "modifier", ranks = 5, gate = 16, col = 1},
		{id = "t_u", code = "A7", name = "U", type = "ultimate", ability = "storm", ranks = 1,
			gate = 20, col = 1, requires = {"t_c"}},
		{id = "t_v", code = "A8", name = "V", type = "modifier", ranks = 4, gate = 0, col = 3},
	}, example = "A1x5 A2x5 A3 A4x5 A5x4 A6x5 A7"}
	mutate(tree, g)
	local ok, err = pcall(function()
		g.register_tree(tree)
		g.audit()
	end)
	grug_classes = saved
	return ok and "ok" or tostring(err)
end
local function by_code(tree, code)
	for _, def in ipairs(tree.nodes) do if def.code == code then return def end end
end
eq(audit_error(function() end), "ok", "B the small tree passes")
local CASES = {
	{"a prerequisite cycle", "cycle", function(t)
		by_code(t, "A2").requires = {"t_v"}
		by_code(t, "A8").requires = {"t_b"}
		t.example = nil
	end},
	{"an unreachable node", "not reachable", function(t)
		-- 17 ranks below gate 20: the ultimate can never open.
		by_code(t, "A4").ranks = 1
		by_code(t, "A5").ranks = 1
		by_code(t, "A6").gate, by_code(t, "A6").col, by_code(t, "A6").ranks = 20, 2, 13
		t.example = nil
	end},
	{"a wrong rank sum", "ranks, its data says", function(t) t.ranks = 30 end},
	{"a tree one could buy out", "could be bought out", function(t)
		by_code(t, "A8").ranks = 3
		t.ranks = 30
		t.example = nil
	end},
	{"an unknown key", "outside its vocabulary", function(t)
		by_code(t, "A2").effects = {fire_power = {1, 2, 3, 4, 5}}
	end},
	{"a family param of no class", "outside its vocabulary", function(t)
		by_code(t, "A2").effects = {["damage_pct:frost"] = {1, 2, 3, 4, 5}}
	end},
	{"values per rank", "one value per rank", function(t)
		by_code(t, "A1").effects = {["damage_pct:fire"] = {1, 2}}
	end},
	{"two ultimates", "2 ultimates", function(t)
		by_code(t, "A6").type = "ultimate"
		by_code(t, "A6").ability = "bolt"
		by_code(t, "A6").ranks = 1
		by_code(t, "A6").gate = 20
		by_code(t, "A6").col = 2
		t.ranks = 27
		t.example = nil
	end},
	{"an ultimate below its gate", "an ultimate sits at its gate", function(t)
		by_code(t, "A7").gate = 16
		by_code(t, "A7").col = 2
	end},
	{"an unlock without its ability", "needs `ability`", function(t)
		by_code(t, "A3").ability = nil
	end},
	{"an ability its class did not register", "not among its class's params", function(t)
		by_code(t, "A3").ability = "comet"
	end},
	{"a prerequisite of a higher gate", "higher gate", function(t)
		by_code(t, "A3").requires = {"t_d"}
	end},
	{"a shared cell", "shares its cell", function(t) by_code(t, "A2").col = 1 end},
	{"a gate outside the rows", "outside GATE_ROWS", function(t) by_code(t, "A5").gate = 8 end},
	{"an id without its tree prefix", "is not named t_<name>", function(t)
		by_code(t, "A8").id = "v"
	end},
	{"an id that is only the prefix", "is not named t_<name>", function(t)
		by_code(t, "A8").id = "t_"
	end},
	{"an illegal sample build", "sample build", function(t)
		t.example = "A3 A1x5"
	end},
}
for _, case in ipairs(CASES) do
	has(audit_error(case[3]), case[2], "B the audit refuses " .. case[1])
end
-- The reach_cost filler (the Round 52 note): before the gate-2 unlock the
-- only open ranks are further ranks of its own prerequisite, so the filler
-- must buy them; the old filler skipped a needed node's extra ranks and
-- called the unlock unreachable.
eq(audit_error(function(t)
	by_code(t, "A2").gate, by_code(t, "A2").requires = 2, {"t_c"}
	by_code(t, "A8").gate, by_code(t, "A8").requires = 2, {"t_c"}
	by_code(t, "A2").col, by_code(t, "A8").col = 2, 3
	t.example = nil
end), "ok", "B the filler buys further ranks of a needed node")

--
-- C. The candidates' worked builds, adapted (header), rank by rank.
--

local BUILDS = {
	-- mage: the class-redesign handoff §5.6 (mage.md keeps them)
	{"mage", "Fire with utility 21/9", "F1x4 F4 F2x2 F5 F6x3 F7x3 F8 F9x3 F10x2 F12 " ..
		"R2x2 R4 R2x2 R5 R7 R6x2", {ember = 21, rime = 9}},
	{"mage", "Frost with a fire hit 9/21", "R1 R2x4 R3x2 R4 R5x2 R7 R8 R9 R10x3 R12x3 R8 R13 " ..
		"F2x3 F3x3 F5 F6x2", {ember = 9, rime = 21}},
	{"mage", "Mixed 15/15", "F1x4 F4 F2 F5 F6x3 F7x3 F8 F9 R2x4 R4 R5x3 R6x2 R7 R8 R9 R11x2",
		{ember = 15, rime = 15}},
	{"mage", "Pure Fire", graph.trees.ember.example, {ember = 30}},
	{"mage", "Pure Frost", graph.trees.rime.example, {rime = 30}},
	-- warrior.md §5
	{"warrior", "Pure Bulwark", graph.trees.bulwark.example, {bulwark = 30}},
	{"warrior", "Pure Ruin", graph.trees.ruin.example, {ruin = 30}},
	{"warrior", "Protected attacker 21/9", "B1 B2x2 B4 B2x2 B5x3 B3x3 B8x3 B6x3 B10x2 B12 " ..
		"U1 U2x4 U3 U7 U4 U3", {bulwark = 21, ruin = 9}},
	{"warrior", "Offensive survivor 9/21", "U1 U2x4 U3 U7 U5x3 U8x3 U10x3 U11x3 U4 U12 " ..
		"B1 B2x2 B4 B2x2 B5x3", {bulwark = 9, ruin = 21}},
	{"warrior", "Mobile mixed 15/15", "B1 B2x2 B4 B2x2 B5x3 B3 B8x3 B6x2 " ..
		"U1 U2x4 U3 U7 U4 U5x3 U6x3 U14", {bulwark = 15, ruin = 15}},
	-- priest.md §5 (R codes read RK; pure Mercy's M12x3 goes to M5x2 and M14)
	{"priest", "Pure Mercy", graph.trees.mercy.example, {mercy = 30}},
	{"priest", "Pure Reckoning", graph.trees.reckoning.example, {reckoning = 30}},
	{"priest", "Mercy with paid attack 21/9", "M1x3 M3 M2x2 M6 M4x3 M5x3 M10 M8x3 M9x3 M13 " ..
		"RK1x3 RK3 RK2x2 RK6 RK4x2", {mercy = 21, reckoning = 9}},
	{"priest", "Reckoning with protection 9/21", "RK1x3 RK3 RK2x2 RK6 RK4x3 RK8x3 RK9 RK7x3 " ..
		"RK11x3 RK13 M1x3 M3 M2x2 M6 M4x2", {mercy = 9, reckoning = 21}},
	{"priest", "Broad mixed 15/15", "M1x3 M3 M2x2 M6 M4x3 M5x3 M10 M8 " ..
		"RK1x3 RK3 RK2x2 RK6 RK4x3 RK8x3 RK9 RK7", {mercy = 15, reckoning = 15}},
	-- scout.md §7
	{"scout", "Pure Quarry", graph.trees.quarry.example, {quarry = 30}},
	{"scout", "Pure Quarry follow-up", "Q1x4 Q4 Q2x3 Q5x3 Q6 Q8 Q9x3 Q7x3 Q11 Q12 Q11x2 " ..
		"Q3x3 Q10 Q13x3", {quarry = 30}},
	{"scout", "Quarry 21/Veil 9", "Q1x4 Q4 Q2x3 Q5x3 Q6 Q8 Q9x3 Q7x3 Q11 Q12 " ..
		"V1 V2x4 V4 V6 V3x2", {quarry = 21, veil = 9}},
	{"scout", "Pure Veil", graph.trees.veil.example, {veil = 30}},
	{"scout", "Veil 21/Quarry 9", "V1 V2x4 V4 V6 V7x3 V3x2 V8 V9x3 V10x3 V3 V12 " ..
		"Q1x4 Q4 Q2x3 Q3", {quarry = 9, veil = 21}},
	{"scout", "Mixed 15/15", "Q1x4 Q4 Q2x3 Q5x3 Q6 Q8 Q9x2 V1 V2x4 V4 V6 V7x3 V3x2 V8 V9x2",
		{quarry = 15, veil = 15}},
}
local PURE = {
	ember = "F1x4 F4 F2x3 F3x2 F5 F6x3 F7x3 F8 F9x3 F10x3 F11x3 F12 F13x2",
	rime = "R1 R2x4 R3x3 R4 R5x3 R6x3 R7 R8x3 R9 R10x3 R13 R11x3 R14x3",
	bulwark = "B1 B2x2 B4 B2x2 B5x3 B3x3 B8x3 B6x3 B10x2 B12 B10 B14x3 B7 B9 B13x3",
	ruin = "U1 U2x4 U3 U7 U5x3 U8x3 U10x3 U11x3 U4 U12 U3x2 U6x3 U9x3 U14",
	mercy = "M1x3 M3 M2x2 M6 M4x3 M5x3 M10 M8x3 M9x3 M13 M7x3 M5x2 M2 M14x3",
	reckoning = "RK1x3 RK3 RK2x2 RK6 RK4x3 RK8x3 RK9 RK7x3 RK11x3 RK13 RK12x3 RK14x3 RK2 RK5x2",
	quarry = "Q1x4 Q4 Q2x3 Q5x3 Q6 Q8 Q9x3 Q7x3 Q11 Q12 Q3x3 Q10x3 Q13x3",
	veil = "V1 V2x4 V4 V6 V7x3 V3x2 V8 V9x3 V10x3 V3 V12 V5x3 V11x3 V13x3",
}
for tree_id, order in pairs(PURE) do
	eq(graph.trees[tree_id].example, order, "C " .. tree_id .. ": the sample build is the pure order")
end
for _, build in ipairs(BUILDS) do
	local class_id, label, order, trees = build[1], build[2], build[3], build[4]
	local ranks, reason = graph.apply_order(class_id, order, graph.POINTS_MAX)
	if check(ranks ~= nil, "C " .. class_id .. " " .. label .. " is legal (" ..
			tostring(reason) .. ")") then
		eq(graph.spent(ranks), 30, "C " .. class_id .. " " .. label .. ": 30 points")
		for tree_id, points in pairs(trees) do
			eq(graph.tree_points(ranks, tree_id), points, "C " .. label .. ": " .. tree_id)
		end
		local again = graph.parse(class_id, graph.serialize(ranks), graph.POINTS_MAX)
		eq(graph.serialize(again), graph.serialize(ranks), "C " .. label .. ": the read path keeps it")
	end
end
-- The re-derived pure Mercy: Warding Faith at 5/5, Quiet Care unbought.
local mercy = graph.trees.mercy.example_ranks
eq(mercy.mercy_warding_faith, 5, "C pure Mercy: Warding Faith 5/5")
eq(mercy.mercy_lasting_haven, 3, "C pure Mercy: Lasting Haven 3/3")
eq(mercy.mercy_quiet_care, nil, "C pure Mercy: Quiet Care unbought (its 3 of 33 ranks)")
-- The candidate's own pure Mercy order fails on the cut node.
local _, cut = graph.apply_order("priest", "M1x3 M3 M2x2 M6 M4x3 M5x3 M10 M8x3 M9x3 M13 M7x3 " ..
	"M12x3 M2 M14x2", graph.POINTS_MAX)
eq(cut, "M12x3: no such node.", "C priest.md's pure Mercy needs the adaptation")

--
-- D. The gates on both paths, with the same texts.
--

local function spend_order(class_id, order, budget, ranks)
	return assert(graph.apply_order(class_id, order, budget or graph.POINTS_MAX, ranks))
end
local function refusal(class_id, ranks, code, budget)
	return graph.spend_refusal(class_id, ranks, node(code).id, budget or graph.POINTS_MAX)
end
local five = spend_order("mage", "F1x4 F4")
local REFUSALS = {
	{"gate", "mage", five, "F8", "Meteor needs 12 points in Ember (you have 5)."},
	{"prerequisite", "mage", spend_order("mage", "F1x4 F2x2"), "F6",
		"Heat Focus needs a rank in Flame Lance."},
	{"second prerequisite", "mage", spend_order("mage", "R1 R2x4 R3x3 R4 R5x3 R7 R8x3 R11x2"),
		"R10", "Cold Shock needs a rank in Ice Nova."},
	{"ultimate before its gate", "mage", spend_order("mage", "F1x4 F4 F2x3 F3x3 F5 F6x3 F8"),
		"F12", "Fire Rain needs 20 points in Ember (you have 16)."},
	{"ultimate's second rank", "mage", graph.trees.ember.example_ranks, "F12",
		"Fire Rain is already at 1/1."},
	{"no points", "mage", five, "F2", "No talent points left.", 5},
	{"other class", "warrior", five, "F2", "Measured Fuel belongs to another class."},
	{"Warding Faith's sixth rank", "priest", spend_order("priest", "M1x3 M3 M2x2 M5x5"), "M5",
		"Warding Faith is already at 5/5."},
}
for _, case in ipairs(REFUSALS) do
	eq(refusal(case[2], case[3], case[4], case[6]), case[5], "D spend refused: " .. case[1])
end
eq(graph.spend_refusal("mage", {}, "no_such_node", 30), "No such talent.", "D spend: unknown")
-- A pure build leaves no room for the other tree's ultimate: two
-- ultimates cannot coexist (arithmetic).
eq(refusal("mage", graph.trees.ember.example_ranks, "R1"), "No talent points left.",
	"D a full tree leaves no point")
local fire21 = spend_order("mage", "F1x4 F4 F2x2 F5 F6x3 F7x3 F8 F9x3 F10x2 F12")
eq(refusal("mage", spend_order("mage", "R2x4 R4 R5x3 R7", 30, fire21), "R13", 39),
	"Winter Field needs 20 points in Rime (you have 9).", "D no second ultimate")

-- The read path: each forged rank above is dropped with the same reason.
local function parsed(class_id, raw, budget)
	return graph.parse(class_id, raw, budget or graph.POINTS_MAX)
end
local ranks, dropped = parsed("mage", "ember_fire_mastery=4,ember_fireball=1,ember_meteor=1")
eq(ranks.ember_meteor, nil, "D read: Meteor below its gate is dropped")
eq(dropped.ember_meteor, "Meteor needs 12 points in Ember (you have 5).", "D read: the spend's text")
ranks, dropped = parsed("mage", "ember_fire_mastery=4,ember_measured_fuel=2,ember_heat_focus=3")
eq(dropped.ember_heat_focus, "Heat Focus needs a rank in Flame Lance.",
	"D read: a missing prerequisite")
ranks, dropped = parsed("mage", "rime_cold_spark=1,rime_mana_reserve=4,rime_keen_cold=3," ..
	"rime_blink=1,rime_clear_thought=3,rime_rime_mantle=1,rime_thick_ice=3," ..
	"rime_returning_cold=3,rime_cold_shock=2")
eq(dropped.rime_cold_shock, "Cold Shock needs a rank in Ice Nova.", "D read: the second prerequisite")
eq(ranks.rime_returning_cold, 3, "D read: the rest stays")
ranks, dropped = parsed("mage", "ember_fire_mastery=9,ember_fireball=4")
eq(ranks.ember_fire_mastery .. "/" .. ranks.ember_fireball, "4/1",
	"D read: ranks clamped to the node's count")
ranks, dropped = parsed("mage", "bulwark_retort=1,ember_fire_mastery=1,bogus=2")
eq(dropped.bulwark_retort, "Retort belongs to another class.", "D read: another class's node")
eq(dropped.bogus, "No such talent.", "D read: an unknown id")
-- A 0.52 string (the old trees' bare ids) reads as zero ranks.
ranks, dropped = parsed("mage", "fire_mastery=4,fireball=1,ignite=5,whitehot=1")
eq(next(ranks), nil, "D read: a 0.52 string keeps no rank")
eq(dropped.fire_mastery, "No such talent.", "D read: an old id is unknown")
-- Removing a prerequisite takes its dependants along.
ranks, dropped = parsed("mage", "ember_fire_mastery=4,ember_measured_fuel=1,ember_fireball=1," ..
	"ember_afterglow=3")
eq(ranks.ember_afterglow, 3, "D read: Afterglow on Fireball with 6 points")
ranks, dropped = parsed("mage", "ember_measured_fuel=3,ember_fireball=1,ember_afterglow=3," ..
	"ember_far_cast=3")
eq(dropped.ember_fireball, "Fireball needs a rank in Fire Mastery.", "D read: no Fire Mastery")
eq(dropped.ember_afterglow, "Afterglow needs a rank in Fireball.", "D read: Afterglow goes with it")
-- Three gate-6 nodes that would only pay for each other: each has 6 points
-- "elsewhere in the tree", but no order can buy the first of them.
ranks, dropped = parsed("mage", "ember_fire_mastery=2,ember_fireball=1,ember_flame_lance=1," ..
	"ember_heat_focus=3,ember_afterglow=3")
eq(graph.serialize(ranks), "ember_fire_mastery=2,ember_fireball=1",
	"D read: gates that pay for each other")
eq(dropped.ember_heat_focus, "Heat Focus needs 6 points in Ember (you have 3).", "D read: its reason")
eq(refusal("mage", ranks, "F5"), "Flame Lance needs 6 points in Ember (you have 3).",
	"D the spend says the same")

-- Refunds: a 30-point build read at 20 points (level 40) gives back the
-- deepest ranks first (gate 20, then 16, ...), keeping a legal build.
ranks, dropped = parsed("mage", graph.serialize(graph.trees.ember.example_ranks), 20)
eq(graph.spent(ranks), 20, "D refund down to the budget")
eq(ranks.ember_fire_rain or ranks.ember_spreading_rain or ranks.ember_controlled_burn, nil,
	"D the gate-20 and gate-16 ranks went first")
eq(dropped.ember_fire_rain, "Refunded: more ranks than points.", "D a refund's reason")
for id in pairs(ranks) do
	eq(graph.structure_refusal(ranks, graph.nodes[id]), nil, "D after the refund " .. id .. " is legal")
end
-- The full reset: every point back, spending starts over.
local reset, returned = graph.reset(graph.trees.ember.example_ranks)
eq(returned, 30, "D the reset returns every point")
eq(next(reset), nil, "D and keeps no rank")
eq(refusal("mage", reset, "F4"), "Fireball needs 2 points in Ember (you have 0).",
	"D after the reset the gates start over")
eq(refusal("mage", reset, "F1"), nil, "D and gate 0 is open")
eq(graph.serialize(graph.trees.ruin.example_ranks), "ruin_mighty_blow=1,ruin_heavy_hand=4," ..
	"ruin_stoke=3,ruin_hamstring=1,ruin_keen_edge=3,ruin_onset=3,ruin_broadstroke=1," ..
	"ruin_follow_through=3,ruin_clean_cut=3,ruin_finisher=3,ruin_relentless=3," ..
	"ruin_ruination=1,ruin_reach_the_fight=1", "D the stored form: id=rank in node order")

--
-- E. The live Talents page.
--

local function field_of(code) return graph.node_field(node(code).id) end
local mage = H.make_player("mage60", "mage", 60, graph.serialize(graph.trees.ember.example_ranks))
H.join(mage)
local ctx = sfinv.get_or_create_context(mage)
local page = sfinv.pages["grug_classes:talents"]
local fs = H.render(mage, "grug_classes:talents")
has(fs, "button[0.25,0.15;2.60,0.60;grug_graph_tab_1;Ember (30)]", "E the Ember tab")
has(fs, "button[2.95,0.15;2.60,0.60;grug_graph_tab_2;Rime (0)]", "E the Rime tab")
has(fs, grug_core.ui.button_style("grug_graph_tab_1", "selected"), "E the first tab selected")
has(fs, grug_core.ui.button_style("grug_graph_tab_2", "normal"), "E the second not")
has(fs, "label[5.75,0.45;Talent points available: 0 of 30]", "E the points in the header row")
has(fs, "button[9.90,0.15;3.35,0.60;grug_talent_respec;Respec: Free]", "E the respec control")
has(fs, "image[0.25,0.95;13.00,5.50;grug_classes_tree_ember.png]",
	"E the picked background fills D5's rectangle")
has(fs, "set_focus[grug_graph_focus;true]button[0,0;0,0;grug_graph_focus;]", "E the focus sink")
has(fs, "textarea[0.25,6.50;13.00,0.65;;;Click an available talent to buy one rank.]",
	"E the strip under it with the hint")
-- Icons where shipped, text otherwise.
has(fs, ";grug_abilities_skill_fireball.png;" .. field_of("F4") .. ";]",
	"E Fireball shows its shipped skill icon")
has(fs, ";grug_classes_talent_fire_mastery.png;" .. field_of("F1") .. ";]",
	"E a talent node shows its icon by the name part")
has(fs, ";blank.png;" .. field_of("F2") .. ";Measured Fuel\n3/3]", "E a text node without one")
has(fs, ";blank.png;" .. field_of("F5") .. ";Flame Lance\n1/1]", "E an unlock without an icon")
-- The sample build's node states: maxed and ranked (Ember spends 30 of 32).
local maxed = fs:match("style%[([^%]]-);bgcolor=#5c4a2a")
local ranked = fs:match("style%[([^%]]-);bgcolor=#4a4a4a")
check(maxed and maxed:find(field_of("F1"), 1, true), "E Fire Mastery 4/4 is maxed")
eq(ranked, field_of("F3") .. "," .. field_of("F13"), "E Far Cast 2/3 and Spreading Rain 2/3 ranked")
has(fs, "tooltip[" .. field_of("F3") .. ";Far Cast (2/3)", "E a tooltip names the rank")
has(fs, "Locked: No talent points left.", "E and why it cannot rise")
-- Ember has no gate-10 node: no label in that row.
local gate_labels = {}
for gate in fs:gmatch("label%[0%.37,[%d.]+;(%d+)%]") do gate_labels[#gate_labels + 1] = gate end
eq(table.concat(gate_labels, ","), "0,2,6,12,16,20", "E the gate of each used row")

-- The other tab: the choice lives in the sfinv context.
page:on_player_receive_fields(mage, ctx, {grug_graph_tab_2 = "Rime (0)"})
eq(ctx.grug_talent_tab, 2, "E a tab click is kept in the context")
fs = mage.formspec
has(fs, grug_core.ui.button_style("grug_graph_tab_2", "selected"), "E and selects Rime")
has(fs, "box[0.25,0.95;13.00,5.50;#101318c8]", "E without its background (hidden): the plain one")
local locked = fs:match("style%[([^%]]-);bgcolor=#2e2e2e")
check(locked and locked:find(field_of("R12"), 1, true), "E Far Frost is locked (no points left)")
has(fs, "tooltip[" .. field_of("R12") .. ";Far Frost (0/3)", "E its tooltip")
-- A refused click selects the node: gold, and its text and reason in the strip.
page:on_player_receive_fields(mage, ctx, {[field_of("R10")] = "x"})
eq(grug_classes.talent_rank(mage, "rime_cold_shock"), 0, "E a refused click buys nothing")
fs = mage.formspec
has(fs, grug_core.ui.button_style(field_of("R10"), "selected"), "E the selected node is gold")
has(fs, "textarea[0.25,6.50;13.00,0.65;;;Cold Shock — rank 0/3: When Ice Nova hits an enemy",
	"E the strip shows its text")
has(fs, "No talent points left.]", "E and its refusal")
-- The armor amounts at the viewer's level (Ironbound, a warrior at 60:
-- K(60) = 50, so 4/8/12/16 % are 2/4/6/8 rating).
local warrior = H.make_player("war60", "warrior", 60, "")
H.join(warrior)
fs = H.render(warrior, "grug_classes:talents")
eq(graph.node_text(warrior, node("B2")), "Armor +4/8/12/16 % of the level's armor constant. " ..
	"At your level: +2 / +4 / +6 / +8 armor rating.", "E Ironbound's text names its rating")
has(fs, "armor constant. At your level: +2 / +4 / +6 / +8 armor\nrating.", "E in its tooltip")
eq(graph.node_text(warrior, node("B3")), "Max health +3/6/9 %. At your level: +81 HP / " ..
	"+162 HP / +243 HP.", "E Weathered's amounts at the level (the harness's pool)")
eq(graph.node_text(warrior, node("B1")), node("B1").description, "E other nodes: the text")
-- Without a class: no trees, a line and the focus sink.
local nobody = H.make_player("nobody", nil, 5, "")
H.join(nobody)
fs = H.render(nobody, "grug_classes:talents")
has(fs, "Choose a class before spending talent points.", "E no class: the line")
lacks(fs, "grug_graph_tab_", "E and no tabs")
has(fs, "button[0,0;0,0;grug_graph_focus;]", "E and the focus sink")

-- The connectors of a multi-parent node and of a same-row prerequisite.
local PAGE = graph.PAGE
local rime_layout = graph.layout(graph.trees.rime)
local function connector(layout, from, to)
	for _, c in ipairs(layout.connectors) do
		if c.from == from and c.to == to then return c end
	end
end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local down = connector(rime_layout, "rime_cold_spark", "rime_cold_shock")
local side = connector(rime_layout, "rime_ice_nova", "rime_cold_shock")
local shock = rime_layout.nodes.rime_cold_shock
check(down and #down.segments == 1, "E Cold Shock's first parent: one segment down its column")
check(down and near(down.segments[1].y, rime_layout.nodes.rime_cold_spark.y + PAGE.node_h) and
	near(down.segments[1].y + down.segments[1].h, shock.y),
	"E from Cold Spark's bottom to Cold Shock's top, through three empty rows")
check(side and #side.segments == 1 and near(side.segments[1].y + side.segments[1].h / 2,
	shock.y + PAGE.node_h / 2), "E its second parent, in its row: one segment at mid-height")
check(side and near(side.segments[1].x, shock.x + shock.w) and
	near(side.segments[1].x + side.segments[1].w, rime_layout.nodes.rime_ice_nova.x),
	"E between the facing edges")
local veil_layout = graph.layout(graph.trees.veil)
for _, parent in ipairs({"veil_opening", "veil_parry"}) do
	local c = connector(veil_layout, parent, "veil_turn_the_blade")
	check(c and #c.segments == 3, "E Turn the Blade from " .. parent .. ": down, across, down")
	local child = veil_layout.nodes.veil_turn_the_blade
	check(c and near(c.segments[2].y + c.segments[2].h / 2, child.y - PAGE.row_gap / 2),
		"E " .. parent .. "'s across in the gap above the child's row")
end
-- The connectors are drawn under the nodes, coloured by the parent's rank.
page:on_player_receive_fields(mage, ctx, {grug_graph_tab_1 = "x"})
fs = mage.formspec
local first_node = fs:find("image_button[", 1, true)
local last_line = 0
for start in fs:gmatch("()box%[[^%]]-;#c9a65a%]") do last_line = start end
check(last_line > 0 and last_line < first_node, "E the lines before (under) the nodes")

-- The layout of every tree: nodes in D5's rectangle, no line through a
-- node that is not its end, no line into a node from right under another.
local function overlaps(a, b)
	return a.x < b.x + b.w - 1e-9 and a.x + a.w > b.x + 1e-9 and
		a.y < b.y + b.h - 1e-9 and a.y + a.h > b.y + 1e-9
end
for _, tree_id in ipairs(graph.tree_ids) do
	local tree = graph.trees[tree_id]
	local layout = graph.layout(tree)
	local cells, cell_rect = {}, {}
	for _, def in ipairs(tree.nodes) do
		local r = layout.nodes[def.id]
		cells[r.row .. ":" .. r.col] = def
		cell_rect[def.id] = {x = r.cx - layout.cell_w / 2, y = r.y, w = layout.cell_w, h = r.h}
		check(r.cx - layout.cell_w / 2 >= PAGE.x and r.cx + layout.cell_w / 2 <= PAGE.x + PAGE.w and
			r.y >= PAGE.y and r.y + r.h <= PAGE.y + PAGE.h,
			"E " .. tree_id .. " " .. def.code .. " inside the rectangle")
	end
	for _, c in ipairs(layout.connectors) do
		local label = "E " .. tree_id .. " " .. graph.nodes[c.from].code .. ">" ..
			graph.nodes[c.to].code
		for _, s in ipairs(c.segments) do
			check(s.w > 0 and s.h > 0, label .. ": a segment has a size")
			for _, def in ipairs(tree.nodes) do
				if def.id ~= c.from and def.id ~= c.to then
					check(not overlaps(s, cell_rect[def.id]), label .. " runs through " .. def.code)
				end
			end
		end
		if #c.segments == 3 then
			local child = layout.nodes[c.to]
			local above = cells[(child.row - 1) .. ":" .. child.col]
			local parent_above = false
			for _, parent_id in ipairs(graph.nodes[c.to].requires) do
				if above and above.id == parent_id then parent_above = true end
			end
			check(not above or parent_above, label .. ": enters under " ..
				(above and above.code or "nothing"))
		end
		if #c.segments == 1 and layout.nodes[c.from].row == layout.nodes[c.to].row then
			eq(math.abs(layout.nodes[c.from].col - layout.nodes[c.to].col), 1,
				label .. ": a same-row prerequisite is the neighbour")
		end
	end
end
-- Seven gate rows in 5.5 units (D5): the reported node size and gap.
local rows = #graph.GATE_ROWS
check(rows * PAGE.node_h + (rows - 1) * PAGE.row_gap <= PAGE.h,
	"E seven rows of " .. PAGE.node_h .. " with gaps of " .. PAGE.row_gap .. " fit 5.5")
eq(PAGE.strip_y + PAGE.strip_h, 7.15, "E the strip ends at 7.15")
check(PAGE.strip_y + PAGE.strip_h <= grug_inventory.VIEW_GEOMETRY.top - 0.1 - 1.8,
	"E above the skill row with its scrollbar")

-- The page content's bytes per tree with its sample build (comparison only).
local bytes = {}
for _, tree_id in ipairs(graph.tree_ids) do
	local trees = graph.trees_of_class(graph.trees[tree_id].class)
	local tab = trees[1].id == tree_id and 1 or 2
	local content = graph.page_content(mage, {trees = trees, tab = tab,
		ranks = graph.trees[tree_id].example_ranks, budget = graph.POINTS_MAX,
		hint = "x", points_text = "x", header = ""})
	bytes[#bytes + 1] = tree_id .. " " .. #content
end

--
-- F. The skill row scrolls (C13, live).
--

for i = 1, 6 do
	table.insert(H.abilities, {id = "extra_" .. i, name = "Extra " .. i, talent_gated = false})
	H.abilities[#H.abilities].talent_gated = false
	grug_abilities.registered["extra_" .. i] = H.abilities[#H.abilities]
	core.registered_items["grug_abilities:extra_" .. i] = {description = "Extra " .. i,
		stack_max = 1, groups = {grug_ability = 1, grug_bound_skill = 1}}
end
local scout = H.make_player("rower", "scout", 30,
	"quarry_bowcraft=4,quarry_true_draw=1,quarry_quiver=3,veil_bladecraft=1,veil_fine_edge=1," ..
	"veil_opening=1")
H.join(scout)
local sctx = sfinv.get_or_create_context(scout)
local form = H.render(scout, "grug_classes:talents")
local cat = H.catalog("rower")
eq(cat.inv:get_size("catalog"), 12, "F twelve skills in the row (no assert at eight)")
has(form, "scrollbaroptions[min=0;max=40;smallstep=10;largestep=80;thumbsize=27;arrows=hide]",
	"F four slots past eight: a range of 40, a slot per step")
local bar_x, bar_y = form:match("scrollbar%[([%d.]+),([%d.]+);9%.750,0%.240;horizontal;" ..
	"grug_skills_scroll;0%]")
check(bar_x ~= nil, "F a horizontal scrollbar as wide as eight slots")
local box_y = tonumber(form:match("background9%[[%d.]+,([%d.]+);[%d.]+,1%.800;[^%]]+%]label%[[%d.]+,[%d.]+;Skills%]"))
check(box_y and bar_y and tonumber(bar_y) > box_y + 1.38 and tonumber(bar_y) + 0.24 < box_y + 1.8,
	"F the bar under the slots, inside the box")
has(form, "scroll_container[1.650,", "F the slots in a scroll container on the hotbar's columns")
has(form, ";9.750,1;grug_skills_scroll;horizontal;0.125]list[detached:grug_skills_rower;" ..
	"catalog;0,0;12,1;0]scroll_container_end[]", "F all twelve slots in it")
has(form, "arrows=default]", "F the scrollbar options are reset after the bar")
-- A pure scrollbar event: kept, handled, not re-sent.
local receive = H.registered.receive[1]
local sent = scout.sent
eq(receive(scout, "", {grug_skills_scroll = "CHG:20"}), true, "F a scrollbar event is handled")
eq(scout.sent, sent, "F and not re-sent")
eq(sctx.grug_skills_scroll, 20, "F its value kept in the sfinv context")
-- A page event carries the value (VAL) and the resend echoes it.
receive(scout, "", {grug_skills_scroll = "VAL:20", [graph.node_field("veil_fine_edge")] = "x"})
eq(grug_classes.talent_rank(scout, "veil_fine_edge"), 2, "F the page event bought its rank")
has(scout.formspec, ";horizontal;grug_skills_scroll;20]", "F the refresh keeps the position")
-- A rebuild (an entitlement change) keeps it too.
grug_skills.rebuild(scout, true)
form = H.render(scout, "grug_classes:talents")
has(form, ";horizontal;grug_skills_scroll;20]", "F a rebuild keeps the position")
-- Past the end of a shorter row: clamped.
sctx.grug_skills_scroll = 500
has(H.render(scout, "grug_classes:talents"), ";horizontal;grug_skills_scroll;40]",
	"F a value past the end is clamped")
-- A drag from a slot past the eighth, at any position.
local tenth = cat.inv:get_stack("catalog", 10)
eq(cat.callbacks.allow_take(cat.inv, "catalog", 10, tenth, scout), -1,
	"F the tenth slot can be taken (an infinite source)")
eq(cat.callbacks.allow_put(cat.inv, "catalog", 10, tenth, scout), -1,
	"F and its own skill dragged back onto it")
-- Eight skills or fewer: no scrollbar, the row as before.
local few = H.make_player("few", "scout", 2, "")
for i = 1, 6 do grug_abilities.registered["extra_" .. i].talent = "no_such_talent" end
H.join(few)
local few_form = H.render(few, "grug_classes:talents")
lacks(few_form, "horizontal;grug_skills_scroll;", "F four skills: no scrollbar")
has(few_form, "catalog;0,0;8,1;0]", "F the list keeps its eight columns")

print("bytes: talent page content per tree with its sample build: " .. table.concat(bytes, ", "))
if failures > 0 then
	error(("r52_graph: %d checks, %d failures"):format(checks, failures), 0)
end
print(("r52_graph: %d checks, 0 failures"):format(checks))
