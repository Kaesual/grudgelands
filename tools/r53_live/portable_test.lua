-- Round 53 lane LIVE portable test (round53-plan.md §4 "LIVE", K3-K5): the
-- graph talents as the live talent engine. Loads, through the stub world of
-- tools/r44_ts/harness.lua, the REAL talents.lua (which loads talent_graph.lua
-- and the four class data files), talents_ui.lua, talent_graph_ui.lua and
-- grug_skills, and checks on characters with stored strings:
--   A. every tree's sample build bought rank by rank through
--      grug_classes.spend_talent at level 60, and through page clicks; the
--      stored string is the graph's; the points per tree;
--   B. illegal spends refuse with the graph's gate texts on both paths: the
--      spend (spend_talent and a page click's strip) and the read path (a
--      forged stored string loses exactly those ranks); no class; a full
--      budget;
--   C. a 0.52 string (the old trees' ids) reads as zero ranks: no point
--      spent, every old key 0, every old talent id rank 0; the old registry,
--      its window API and the Unbroken passive are gone (INTEG part 2);
--   D. the accessors: get_talent_bonus sums shared keys, class keys and
--      "<family>:<param>" keys over the ranks; armor_percent_add at levels
--      10 and 60 equals the rank's % x armor_k; talent_rank on node ids;
--      register_on_talents_changed fires on a spend and a respec;
--   E. respec (free first, then the bracket price) and the level-drop reset
--      with its feed line; the "point earned" line; /talents;
--   F. the Mercy sample build re-derived for 33 ranks (Warding Faith 5/5).
-- Prints the Talents & Skills page's bytes per class with its first tree's
-- sample build at level 60 (a comparison, not a target).
--
-- Usage (repo root): luajit tools/r53_live/portable_test.lua [repo]

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
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end

local H = dofile(repo .. "/tools/r44_ts/harness.lua")(repo)
local graph = grug_classes.graph
local page = sfinv.pages["grug_classes:talents"]
local META = "grug_classes:talents"

local changes = {}
grug_classes.register_on_talents_changed(function(player)
	changes[player:get_player_name()] = (changes[player:get_player_name()] or 0) + 1
end)

local function player(name, class, level, talents)
	local p = H.make_player(name, class, level, talents or "")
	H.join(p)
	return p
end
local function stored(p) return p:get_meta():get_string(META) end
local function strip(p) return p.formspec and p.formspec:match("textarea%[[^;]*;[^;]*;;;(.-)%]") end
-- The node ids of an order in the node list's notation, one per rank.
local function order_ids(order)
	local ids = {}
	for token in order:gmatch("[^%s]+") do
		local code, count = token:match("^([%a]+%d+)x?(%d*)$")
		for _ = 1, tonumber(count) or 1 do ids[#ids + 1] = graph.codes[code].id end
	end
	return ids
end

--
-- A. Every tree's sample build, rank by rank, on both purchase paths.
--

local page_bytes = {}
for _, tree_id in ipairs(graph.tree_ids) do
	local tree = graph.trees[tree_id]
	local ids = order_ids(tree.example)
	eq(#ids, 30, "A " .. tree_id .. ": the sample spends 30 points")
	-- The accessor path.
	local p = player("a_" .. tree_id, tree.class, 60)
	local refused
	for index, id in ipairs(ids) do
		local ok, reason = grug_classes.spend_talent(p, id)
		if not ok and not refused then refused = index .. " " .. id .. ": " .. tostring(reason) end
	end
	eq(refused, nil, "A " .. tree_id .. ": every rank of the sample is bought")
	eq(stored(p), graph.serialize(tree.example_ranks), "A " .. tree_id .. ": the stored string")
	eq(grug_classes.talent_points_spent(p), 30, "A " .. tree_id .. ": 30 spent")
	eq(grug_classes.talent_points_available(p), 0, "A " .. tree_id .. ": none left")
	eq(grug_classes.tree_points(p, tree_id), 30, "A " .. tree_id .. ": all in its tree")
	for id, rank in pairs(tree.example_ranks) do
		eq(grug_classes.talent_rank(p, id), rank, "A " .. tree_id .. ": " .. id .. "'s rank")
	end
	-- The page path: the tree's tab, then one click per rank.
	local q = player("p_" .. tree_id, tree.class, 60)
	local ctx = sfinv.get_or_create_context(q)
	H.render(q, "grug_classes:talents")
	local tab = graph.trees_of_class(tree.class)[1].id == tree_id and 1 or 2
	page:on_player_receive_fields(q, ctx, {["grug_graph_tab_" .. tab] = "x"})
	for _, id in ipairs(ids) do
		page:on_player_receive_fields(q, ctx, {[graph.node_field(id)] = "x"})
	end
	eq(stored(q), stored(p), "A " .. tree_id .. ": the page's clicks store the same")
	has(q.formspec, ("grug_graph_tab_%d;%s (30)]"):format(tab, tree.name),
		"A " .. tree_id .. ": its tab shows 30 points")
	has(q.formspec, "label[5.75,0.45;Talent points available: 0 of 30]",
		"A " .. tree_id .. ": the header's points")
	if tab == 1 then page_bytes[#page_bytes + 1] = tree.class .. " " .. #q.formspec end
end

--
-- B. Illegal spends: the same texts on the spend path and the read path.
--

local CASES = { -- class, stored ranks, node, the graph's refusal
	{"mage", "ember_fire_mastery=4,ember_fireball=1", "ember_meteor",
		"Meteor needs 12 points in Ember (you have 5)."},
	{"mage", "ember_fire_mastery=2", "ember_heat_focus", "Heat Focus needs 6 points in Ember (you have 2)."},
	{"mage", "ember_fire_mastery=4,ember_measured_fuel=2,ember_far_cast=1", "ember_heat_focus",
		"Heat Focus needs a rank in Flame Lance."},
	{"warrior", "", "bulwark_hold_ground", "Hold Ground needs 2 points in Bulwark (you have 0)."},
	{"priest", "mercy_steady_word=3,mercy_shield=1,mercy_measured_care=1", "mercy_mend",
		"Mend needs 6 points in Mercy (you have 5)."},
	{"scout", "quarry_bowcraft=2", "veil_opening", "Opening needs 2 points in Veil (you have 0)."},
	{"scout", "veil_fine_edge=2", "veil_opening", "Opening needs a rank in Bladecraft."},
	{"mage", "ember_fire_mastery=1", "bulwark_retort", "Retort belongs to another class."},
	{"mage", "", "no_such_node", "No such talent."},
}
for index, case in ipairs(CASES) do
	local class_id, ranks, id, text = case[1], case[2], case[3], case[4]
	local p = player("b" .. index, class_id, 60, ranks)
	local before = stored(p)
	local ok, reason = grug_classes.spend_talent(p, id)
	check(not ok, "B " .. id .. ": refused")
	eq(reason, text, "B " .. id .. ": the spend path's text")
	eq(stored(p), before, "B " .. id .. ": nothing stored")
	-- The page's click shows the same reason in the strip (own nodes only).
	if graph.nodes[id] and graph.nodes[id].class == class_id then
		local ctx = sfinv.get_or_create_context(p)
		H.render(p, "grug_classes:talents")
		page:on_player_receive_fields(p, ctx, {[graph.node_field(id)] = "x"})
		has(strip(p), text, "B " .. id .. ": the page's strip")
		eq(grug_classes.talent_rank(p, id), 0, "B " .. id .. ": the click buys nothing")
	end
	-- The read path: the forged rank is dropped with the same reason.
	if graph.nodes[id] then
		local forged = player("r" .. index, class_id, 60, (ranks ~= "" and ranks .. "," or "") ..
			id .. "=1")
		eq(grug_classes.talent_rank(forged, id), 0, "B " .. id .. ": the read path drops it")
		local _, dropped = graph.parse(class_id, stored(forged), 30)
		eq(dropped[id], text, "B " .. id .. ": with the same reason")
		eq(grug_classes.talent_points_spent(forged), graph.spent(graph.parse(class_id, ranks, 30)),
			"B " .. id .. ": and keeps the legal ranks")
	end
end
-- No class, and a full budget.
local classless = player("b_none", nil, 30)
local ok, reason = grug_classes.spend_talent(classless, "ember_fire_mastery")
check(not ok and reason == "You have no class yet.", "B no class: refused")
local low = player("b_low", "mage", 4, "ember_fire_mastery=2")
ok, reason = grug_classes.spend_talent(low, "ember_far_cast")
eq(reason, "No talent points left.", "B two points at level 4 are spent")
-- More stored ranks than the level allows: refunded deepest first on read.
local over = player("b_over", "mage", 20, graph.serialize(graph.trees.ember.example_ranks))
eq(grug_classes.talent_points_spent(over), 10, "B a 30-point string at level 20 reads as 10")
eq(grug_classes.talent_rank(over, "ember_fire_rain"), 0, "B the ultimate went first")

--
-- C. A 0.52 string and the old registry (K3).
--

-- A real 0.52 Warrior string (the old Bulwark and Ruin trees).
local OLD = "ironbound=5,weathered=4,unbroken=1,grudge=4,affront=3,stoke=5,ruination=1," ..
	"hold_ground=1,mighty_blow=1"
local veteran = player("c_old", "warrior", 60, OLD)
eq(grug_classes.talent_points_spent(veteran), 0, "C a 0.52 string spends nothing")
eq(grug_classes.talent_points_available(veteran), 30, "C every point is free")
for _, key in ipairs({"armor_percent_add", "max_hp_percent_add", "rage_per_swing_add",
		"threat_mult_add", "taunt_radius", "armor_rating_add_low_hp", "hold_ground_absorb"}) do
	eq(grug_classes.get_talent_bonus(veteran, key), 0, "C old key " .. key .. " reads 0")
end
for id in OLD:gmatch("([%a_]+)=") do
	eq(grug_classes.talent_rank(veteran, id), 0, "C old id " .. id .. " has no rank")
end
eq(stored(veteran), OLD, "C reading never rewrites the string (the migration step clears it)")
-- INTEG part 2 deleted the old registry and its window API (K3 ended).
for _, old in ipairs({"registered_talents", "registered_trees", "register_talent",
		"register_tree", "audit_talents", "TALENT_EFFECT_KEYS", "talent_level_amount",
		"start_talent_window", "try_trigger_talent_window", "talent_trigger_ready",
		"talent_window_active"}) do
	eq(grug_classes[old], nil, "C the old " .. old .. " is gone")
end
local guard = player("c_unbroken", "warrior", 60, graph.serialize(graph.trees.bulwark.example_ranks))
eq(grug_classes.talent_rank(guard, "bulwark_unbroken"), 1, "C Bulwark's Unbroken is ranked")
eq(grug_classes.talent_rank(guard, "unbroken"), 0, "C an old id has no rank")

--
-- D. The accessors.
--

-- Shared keys, a class key and families, summed over the ranks.
local mage = player("d_mage", "mage", 60, "ember_fire_mastery=3,ember_measured_fuel=2," ..
	"ember_far_cast=3,ember_fireball=1,rime_cold_spark=1,rime_mana_reserve=2")
eq(grug_classes.get_talent_bonus(mage, "damage_pct:fire"), 15, "D damage_pct:fire at rank 3")
eq(grug_classes.get_talent_bonus(mage, "cost_pct:fire"), -8, "D cost_pct:fire at rank 2")
eq(grug_classes.get_talent_bonus(mage, "range_add:fiery_spark"), 3, "D both forms named: Spark")
eq(grug_classes.get_talent_bonus(mage, "range_add:cold_spark"), 3, "D and Cold Spark")
eq(grug_classes.get_talent_bonus(mage, "max_mana_percent_add"), 10, "D a shared key")
eq(grug_classes.get_talent_bonus(mage, "damage_pct:frost"), 0, "D an unranked family")
eq(grug_classes.get_talent_bonus(mage, "no_such_key"), 0, "D an unknown key")
eq(grug_classes.talent_rank(mage, "ember_fireball"), 1, "D a granting node's rank")
eq(grug_classes.get_talent_bonus(nil, "damage_pct:fire"), 0, "D no player")
local priest = player("d_priest", "priest", 60, graph.serialize(graph.trees.reckoning.example_ranks) ..
	",mercy_quiet_care=3")
eq(grug_classes.talent_points_spent(priest), 30, "D the Quiet Care ranks beyond 30 are refunded")
local healer = player("d_healer", "priest", 60, "mercy_steady_word=3,mercy_measured_care=3," ..
	"mercy_shield=1,mercy_gentle_hand=3,mercy_mend=1,mercy_warding_faith=1,mercy_quiet_care=2")
near(grug_classes.get_talent_bonus(healer, "heal_threat_factor_sub"), 0.1, "D a class key")
eq(grug_classes.get_talent_bonus(priest, "damage_pct:paid"), 9, "D Hard Faith 3/3")
eq(grug_classes.get_talent_bonus(priest, "max_mana_percent_add"), 12, "D Deep Resolve 3/3")
-- armor_percent_add at levels 10 and 60: the rank's % x armor_k(level).
for _, level in ipairs({10, 60}) do
	for rank = 1, 4 do
		local w = player("d_armor" .. level .. "_" .. rank, "warrior", level,
			"bulwark_ironbound=" .. rank)
		local percent = graph.nodes.bulwark_ironbound.effects.armor_percent_add[rank]
		near(grug_classes.get_talent_bonus(w, "armor_percent_add"),
			percent * grug_core.armor_k(level) / 100,
			("D Ironbound %d/4 at level %d: %d %% of armor_k %g"):format(rank, level, percent,
				grug_core.armor_k(level)))
	end
end
near(grug_classes.get_talent_bonus(player("d_armor_k", "warrior", 60, "bulwark_ironbound=4"),
	"armor_percent_add"), 8, "D 16 % of K(60) = 50 is 8 rating points")
-- The talents-changed callbacks.
local fan = player("d_fan", "scout", 30)
changes.d_fan = 0
grug_classes.spend_talent(fan, "quarry_bowcraft")
eq(changes.d_fan, 1, "D a spend fires register_on_talents_changed")
grug_classes.spend_talent(fan, "veil_opening")
eq(changes.d_fan, 1, "D a refused spend does not")
grug_classes.respec(fan)
eq(changes.d_fan, 2, "D a respec fires it")

--
-- E. Respec, the level-drop reset, the point line, /talents.
--

local buyer = player("e_buyer", "scout", 45, "quarry_bowcraft=4,quarry_true_draw=1")
eq(grug_classes.respec_price(buyer), 0, "E the first respec is free")
local ok2, returned, price = grug_classes.buy_respec(buyer)
check(ok2 and returned == 5 and price == 0, "E a free respec returns the 5 points")
eq(stored(buyer), "", "E and stores an empty build")
eq(grug_classes.talent_points_available(buyer), 22, "E every point is back")
grug_classes.spend_talent(buyer, "veil_bladecraft")
eq(grug_classes.respec_price(buyer), grug_classes.RESPEC_PRICES[5], "E then the bracket price")
-- The level drop: a free full reset, with the stored total in the feed.
local dropper = player("e_drop", "mage", 60, graph.serialize(graph.trees.rime.example_ranks))
dropper.level = 20
grug_classes.on_level_change_talents(dropper, 60, 20)
eq(stored(dropper), "", "E a level drop resets the build")
eq(grug_classes.talent_points_spent(dropper), 0, "E nothing spent after it")
has(dropper.feed and dropper.feed[#dropper.feed], "Your level dropped: all 30 talent points " ..
	"were returned.", "E the feed names the stored total, not the clamped one")
local riser = player("e_rise", "mage", 3, "ember_fire_mastery=1")
riser.level = 4
grug_classes.on_level_change_talents(riser, 3, 4)
has(riser.feed and riser.feed[#riser.feed], "Talent point earned - 1 to spend.",
	"E a new point: the feed line with what is left")
-- /talents: read only, the graph's trees and reasons.
local chatty = player("e_chat", "warrior", 20, "bulwark_retort=1,bulwark_ironbound=4")
local cmd_ok, text = H.commands.talents.func("e_chat")
check(cmd_ok, "E /talents answers")
has(text, "Warrior - 10 talent points, 5 spent, 5 left", "E its header")
has(text, "Bulwark [5]", "E a tree with its points")
has(text, "bulwark_ironbound", "E node ids")
has(text, "4/4  Ironbound", "E ranks")
has(text, "! bulwark_unbroken", "E the ultimate marked")
has(text, "(Unbroken needs 20 points in Bulwark (you have 5).)", "E a locked node's reason")
eq(stored(chatty), "bulwark_retort=1,bulwark_ironbound=4", "E /talents changes nothing")

--
-- F. The Mercy sample build for 33 ranks.
--

local mercy = graph.trees.mercy
eq(mercy.ranks, 33, "F Mercy holds 33 ranks")
eq(graph.nodes.mercy_warding_faith.ranks, 5, "F Warding Faith has 5 ranks")
local sample = mercy.example_ranks
eq(sample.mercy_warding_faith, 5, "F the sample takes Warding Faith 5/5")
eq(sample.mercy_quiet_care, nil, "F and leaves Quiet Care's 3 ranks unbought")
eq(graph.spent(sample), 30, "F 30 points")
local text_m5 = graph.nodes.mercy_warding_faith.description
has(text_m5, "+2/4/6/8/10 %", "F Warding Faith's increments (the user's answer to Q1)")

print("bytes: Talents & Skills page, level 60, first tree's sample build: " ..
	table.concat(page_bytes, ", "))
if failures > 0 then
	error(("r53_live: %d checks, %d failures"):format(checks, failures), 0)
end
print(("r53_live: %d checks, 0 failures"):format(checks))
