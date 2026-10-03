-- Round 31 Lane M portable test (LuaJIT): the PvP POI placement as data and
-- its consumers, without building a world (tools/r31_m/spacing_check.lua
-- checks the anchors on real worlds).
--
--   luajit tools/r31_m/portable_test.lua [REPO]
--
--   1. anchors 101..118 are the catalogue's rows in order (zone, slot,
--      template = kind, `layout_fixed`), each kind's fitting profile holds
--      its blueprint box (the fortress with an apron of at least 5 nodes),
--      and each fortress stands on the Battlegrounds half of its zone, off
--      the middle road's axis, its gate (`r7_settlement.pvp_gate_turns`)
--      facing the axis;
--   1b. the road layout's inputs (`road_layout.inputs`): a fortress is a
--      trail node whose gate side is the same as the blueprint's turn, a
--      PvP camp is none (the Battlegrounds have no trails), and every PvP
--      POI reserves its round core area;
--   2. `r7_settlement.pvp_profiles` binds all 18 to their anchors and the
--      roster carries them once; on the source without anchors 101..118 the
--      binding is refused (no "none bound" branch is left);
--   3. the R7 consumers that count anchors accept the 118: the consumer
--      payload is byte-identical to the one of the first 100 anchors (its
--      frozen digest in `r7_manifest.lua` does not move), and the activation
--      roster stays the 42 capitals, outposts and bandit camps (the PvP POIs
--      carry no activation node) on a stub session;
--   4. world protection: the PvP slots answer "fortress" or "war_camp", a PvP
--      box grows by PVP_MARGIN (10) on every side in x and z (y unchanged),
--      every other slot's box is the blueprint's own; `kind_at` answers on
--      the margin's last node and not one node beyond; the settlement cores
--      outside starts and capitals are 106 (the count the claim scan names);
--   5. the waystone rules: each faction's network is seven stones, the
--      fortress travels like a capital (known only when discovered);
--   6. the map's settlement icons (`grug_map/settlement_icons.lua`): the
--      enemy's starts, capitals, villages, outposts and fortress are hidden,
--      the war camps and every neutral place are seen by both factions and
--      by a player without one only the neutral places and the camps; the
--      mobs' rules (`spawn_policy.lua`, `roam_avoid.lua`) treat "fortress"
--      and "war_camp" like a village, and a bandit "camp" not.
-- Prints "R31 M PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local source = dofile(dir .. "/source/simple_map.lua")
local catalog = dofile(dir .. "/r31_pvp_catalog.lua")
local settlement = dofile(dir .. "/r7_settlement.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local zone_by_id, prof = {}, {}
for _, z in ipairs(source.zones) do zone_by_id[z.id] = z end
for _, p in ipairs(source.anchor_profiles) do prof[p.id] = p end

-- 1. the anchor rows
check(#source.anchors == 118, "118 anchors")
for i, row in ipairs(catalog.rows) do
	local a = source.anchors[100 + i]
	check(a.numeric_id == 100 + i and a.id == ("anchor_%03d"):format(100 + i), row.key .. ": id")
	check(a.zone_numeric_id == zone_by_id[row.zone_id].numeric_id and a.slot_id == row.slot and
		a.template_id == row.kind and a.placement_mode == "layout_fixed" and
		a.approved_candidate_index == 1, row.key .. ": zone, slot, template")
	local box = settlement.BOUNDS[row.kind]
	local half = prof[row.kind].building_core_width / 2
	check(-half <= box.min.x and box.max.x <= half - 1 and -half <= box.min.z and
		box.max.z <= half - 1, row.key .. ": the core holds the blueprint box")
	if row.kind == "pvp_fortress" then
		local hub = zone_by_id[row.zone_id].hub
		check(a.position.x ~= 0 and math.abs(a.position.z) < math.abs(hub.z) and
			(a.position.z < 0) == (row.faction == "accord"), row.key .. ": Battlegrounds half")
		check(settlement.pvp_gate_turns(row, a.position.x) == (a.position.x > 0 and 1 or 3),
			row.key .. ": gate toward the middle road's axis")
		check(half - box.max.x >= 5, row.key .. ": a flat apron round the walls")
	else
		check((row.faction == "accord") == (a.position.z < 0), row.key .. ": own side of z = 0")
	end
end

-- 1b. the road layout's inputs
local road_layout = dofile(dir .. "/road_layout.lua")
local inputs = road_layout.inputs(source)
local trail_of, reserve_of = {}, {}
for _, n in ipairs(inputs.trail_nodes) do trail_of[n.id] = n end
for _, r in ipairs(inputs.reserved) do reserve_of[r.id] = r end
for i, row in ipairs(catalog.rows) do
	local a = source.anchors[100 + i]
	local n = trail_of[a.id]
	local r = reserve_of[a.id]
	check(r and r.round and r.half == prof[row.kind].building_core_width / 2 + 10,
		row.key .. ": the router reserves the core")
	if row.kind == "pvp_fortress" then
		-- quarter turns about +y take the gate (local -z) to the world
		local turns = settlement.pvp_gate_turns(row, a.position.x)
		local gx, gz = ({{0, -1}, {-1, 0}, {0, 1}, {1, 0}})[turns + 1][1],
			({{0, -1}, {-1, 0}, {0, 1}, {1, 0}})[turns + 1][2]
		check(n and n.kind == "pvp_fortress" and n.gate_x == gx and n.gate_z == gz and
			n.core == prof[row.kind].building_core_width, row.key .. ": a trail node out of the gate")
	else
		check(n == nil, row.key .. ": no trail")
	end
end

-- 2. the binding
local profiles = settlement.pvp_profiles(source)
check(#profiles == 18, "all 18 bound")
local in_roster = 0
for _, p in ipairs(settlement.roster) do
	if p.blueprint_file == "r31_pvp_poi_blueprint.lua" then in_roster = in_roster + 1 end
end
check(in_roster == 18, "the roster carries them once")
local first100 = {}
for k, v in pairs(source) do first100[k] = v end
first100.anchors = {}
for i = 1, 100 do first100.anchors[i] = source.anchors[i] end
check(not pcall(settlement.pvp_profiles, first100), "a source without them is refused")

-- 3. the R7 consumers
local payload_factory = dofile(dir .. "/r7_consumer_payload.lua")
local function sha_hex(bytes) return common.hex(sha(bytes)) end
local payload = payload_factory(source, sha_hex)
check(not pcall(payload_factory, first100, sha_hex), "the payload refuses 100 anchors now")
-- The payload of the first 100 anchors, read through a source that only
-- reports 118 (the count is the one thing that changed).
local padded = {}
for k, v in pairs(first100) do padded[k] = v end
padded.anchors = {}
for i = 1, 100 do padded.anchors[i] = source.anchors[i] end
for i = 101, 118 do padded.anchors[i] = {id = "pad", zone_numeric_id = 1, slot_id = "pad"} end
check(payload_factory(padded, sha_hex).sha256 == payload.sha256,
	"the consumer payload does not see the PvP anchors")
local roster_factory = dofile(dir .. "/r7_anchor_roster.lua")
local session = {anchor = function(zone_id, slot_id)
	for _, a in ipairs(source.anchors) do
		local z = source.zones[a.zone_numeric_id]
		if z.id == zone_id and a.slot_id == slot_id then
			return {numeric_id = a.numeric_id, id = a.id, zone_numeric_id = a.zone_numeric_id,
				slot_id = a.slot_id, x = a.position.x, y = 20, z = a.position.z,
				functional_feature_id = "feature_" .. a.id}
		end
	end
end}
local planner = {column_values_at = function(x, z)
	for _, a in ipairs(source.anchors) do
		if a.position.x == x and a.position.z == z then
			return "land", a.zone_numeric_id, source.zones[a.zone_numeric_id].id, "biome", "race",
				20, nil, nil, nil, "platform", 20, "feature_" .. a.id, nil, nil, nil, nil, nil,
				nil, nil, false
		end
	end
end}
local roster = roster_factory(source, session, planner, sha)
check(#roster.rows == 42, "the activation roster stays 42 rows")
for _, row in ipairs(roster.rows) do
	check(row.numeric_id <= 60, "no PvP anchor in the activation roster")
end

-- 4. world protection
local wp = dofile(dir .. "/world_protection.lua")
check(wp.PVP_MARGIN == 10, "ruling 22 margin")
check(wp.settlement_kind("pvp_fortress") == "fortress", "fortress kind")
for _, slot in ipairs({"pvp_accord_low", "pvp_accord_high", "pvp_throng_low", "pvp_throng_high"}) do
	check(wp.settlement_kind(slot) == "war_camp" and wp.settlement_margin(slot) == 10,
		slot .. ": war camp")
end
check(wp.settlement_kind("village_1") == "village" and wp.settlement_kind("bandit_1") == "camp" and
	wp.settlement_kind("outpost_1") == "poi" and wp.settlement_kind("mine") == "poi",
	"older kinds unchanged")
for _, slot in ipairs({"village_1", "bandit_1", "outpost_1", "mine", "mirefolk", "clash_1"}) do
	check(wp.settlement_margin(slot) == 0, slot .. ": no margin")
end
local box = settlement.BOUNDS.pvp_fortress
local rows = {
	{key = "fort", slot = "pvp_fortress", anchor = {x = 1000, y = 50, z = -900}, bounds = box},
	{key = "camp", slot = "pvp_throng_high", anchor = {x = 2000, y = 70, z = 40},
		bounds = settlement.BOUNDS.pvp_camp_high},
	{key = "mine", slot = "mine", anchor = {x = -2000, y = 30, z = 500},
		bounds = {min = {x = -10, y = 0, z = -10}, max = {x = 9, y = 8, z = 9}}},
}
local boxes = wp.settlement_boxes(rows)
check(boxes[1].kind == "fortress" and boxes[1].min_x == 1000 - 24 - 10 and
	boxes[1].max_x == 1000 + 24 + 10 and boxes[1].min_z == -900 - 24 - 10 and
	boxes[1].max_z == -900 + 24 + 10 and boxes[1].min_y == 50 - 10 and
	boxes[1].max_y == 50 + 16 + 10, "fortress box: blueprint + 10 in x/z, y as ruling 16")
check(boxes[2].kind == "war_camp" and boxes[2].max_x - boxes[2].min_x == 26 + 20, "camp box + 10")
check(boxes[3].kind == "poi" and boxes[3].min_x == -2010 and boxes[3].max_z == 509, "mine box unchanged")
local index = wp.new(dofile(dir .. "/index128.lua"), {boxes = boxes})
check(index.kind_at(1000 + 34, 51, -900) == "fortress" and index.kind_at(1000 + 35, 51, -900) == nil,
	"fortress margin ends after 10")
check(index.kind_at(1000, 50 + 26, -900 - 34) == "fortress" and index.kind_at(1000, 50 + 27, -900) == nil,
	"fortress box top")
check(index.kind_at(2000 - 23, 71, 40) == "war_camp" and index.kind_at(2000 - 24, 71, 40) == nil,
	"camp margin")
local cores = 0
for _, p in ipairs(settlement.roster) do
	if p.slot ~= "start" and p.slot ~= "capital" then cores = cores + 1 end
end
check(cores == 106, ("106 settlement cores (%d)"):format(cores))

-- 5. the waystone rules with the fortresses
local R = dofile(repo .. "/mods/PLAYER/grug_home/waypoints_core.lua")
local stones = {}
local function stone(id, faction, race, start) stones[#stones + 1] = {id = id, label = id,
	faction = faction, race = race, start = start, pos = {x = #stones * 100, y = 10, z = 0}} end
for _, r in ipairs({"dwarf", "human", "elf"}) do stone(r .. "_start", "accord", r, true) end
for _, r in ipairs({"undead", "orc", "troll"}) do stone(r .. "_start", "throng", r, true) end
for _, r in ipairs({"dwarf", "human", "elf"}) do stone(r .. "_capital", "accord", r, false) end
for _, r in ipairs({"undead", "orc", "troll"}) do stone(r .. "_capital", "throng", r, false) end
stone("pvp_fortress_accord", "accord", "human", false)
stone("pvp_fortress_throng", "throng", "orc", false)
check(#R.network(stones, "accord") == 7 and #R.network(stones, "throng") == 7, "seven stones each")
local fortress = stones[13]
check(not R.known({}, fortress, "human") and R.known({pvp_fortress_accord = true}, fortress, "human"),
	"the fortress is known once discovered")
check(R.refusal({alive = true, faction = "accord", race = "human", set = {pvp_fortress_accord = true},
	origin = stones[2], target = fortress, at_origin = true}) == nil, "travel to the own fortress")
check(R.refusal({alive = true, faction = "accord", race = "human", set = {pvp_fortress_throng = true},
	origin = stones[2], target = stones[14], at_origin = true}) == "That waystone is not on your path.",
	"the enemy fortress is not on the path")
local entries = R.entries(stones, "throng", {}, "orc", "pvp_fortress_throng")
check(#entries == 7 and entries[7].state == "here", "the fortress in its own travel list")

-- 6. the map icons and the mobs' rules
local icons = dofile(repo .. "/mods/PLAYER/grug_map/settlement_icons.lua")
local owned = {"start", "capital", "village_1", "outpost_1", "outpost_2", "pvp_fortress"}
for _, slot in ipairs(owned) do
	check(icons.visible(slot, "accord", "accord") and not icons.visible(slot, "accord", "throng") and
		not icons.visible(slot, "throng", "") and not icons.visible(slot, "throng", nil),
		slot .. ": own faction only")
end
for _, slot in ipairs({"pvp_accord_low", "pvp_throng_high", "bandit_1", "mine", "mirefolk",
		"clash_2", "dragon", "apex_mine"}) do
	check(icons.visible(slot, "accord", "throng") and icons.visible(slot, "throng", "accord") and
		icons.visible(slot, nil, ""), slot .. ": seen by everyone")
end
-- the source's slots fall in the expected classes
local classes = {}
for _, a in ipairs(source.anchors) do
	local c = icons.class(a.slot_id)
	classes[c] = (classes[c] or 0) + 1
end
check(classes.start == 6 and classes.capital == 6 and classes.fortress == 2 and
	classes.war_camp == 16 and classes.village == 12 and classes.outpost == 24,
	"icon classes of the 118 anchors")
-- Round 32: the hostile camps (their own map symbol): 6 start-zone and 6
-- frontier bandit camps, 4 Mirefolk camps.
check(classes.bandit == 12 and classes.mirefolk == 4,
	("hostile camp classes: %s bandit, %s Mirefolk"):format(tostring(classes.bandit),
		tostring(classes.mirefolk)))
local function read(path)
	local f = assert(io.open(repo .. path, "rb")); local t = f:read("*a"); f:close(); return t
end
local policy = read("/mods/ENTITIES/grug_mobs/spawn_policy.lua")
check(policy:find('kind == "fortress" or kind == "war_camp"', 1, true) ~= nil,
	"no hostile spawn on a fortress or war camp")
local push = read("/mods/ENTITIES/grug_mobs/roam_avoid.lua")
check(push:find("fortress = true", 1, true) and push:find("war_camp = true", 1, true) and
	not push:find("[%s{,]camp = true"), "the idle push keeps off fortresses and war camps only")

print(("R31 M PORTABLE PASS checks=%d"):format(checks))
