-- Round 31 Lane M portable test (LuaJIT): the PvP POI placement as data and
-- its consumers, without building a world (tools/r31_m/spacing_check.lua
-- checks the anchors on real worlds).
--
--   luajit tools/r31_m/portable_test.lua [REPO]
--
--   1. anchors 101..118 are the catalogue's rows in order (zone, slot,
--      template = kind, `layout_fixed`), each kind's fitting profile holds
--      its blueprint box, and the two fortresses stand on the middle road's
--      axis (x = 0), so their gate faces their own continent;
--   2. `r7_settlement.pvp_profiles` binds all 18 to their anchors and the
--      roster carries them once; on the source without anchors 101..118 the
--      binding is refused (no "none bound" branch is left);
--   3. the R7 consumers that count anchors accept the 118: the consumer
--      payload is byte-identical to the one of the first 100 anchors (its
--      frozen digest in `r7_manifest.lua` does not move), and the activation
--      roster stays the 42 capitals, outposts and bandit camps (the PvP POIs
--      carry no activation node) on a stub session;
--   4. world protection: the PvP slots answer "fortress" or "camp", a PvP
--      box grows by PVP_MARGIN (10) on every side in x and z (y unchanged),
--      every other slot's box is the blueprint's own; `kind_at` answers on
--      the margin's last node and not one node beyond; the settlement cores
--      outside starts and capitals are 106 (the count the claim scan names);
--   5. the waystone rules: each faction's network is seven stones, the
--      fortress travels like a capital (known only when discovered).
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
		check(a.position.x == 0, row.key .. ": on the middle road's axis")
		check(settlement.pvp_gate_turns(row, a.position.x) == (row.faction == "accord" and 0 or 2),
			row.key .. ": gate toward the own continent")
		check((row.faction == "accord") == (a.position.z < 0), row.key .. ": own side")
	else
		check((row.faction == "accord") == (a.position.z < 0), row.key .. ": own side of z = 0")
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
	check(wp.settlement_kind(slot) == "camp" and wp.settlement_margin(slot) == 10, slot .. ": camp")
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
check(boxes[2].kind == "camp" and boxes[2].max_x - boxes[2].min_x == 26 + 20, "camp box + 10")
check(boxes[3].kind == "poi" and boxes[3].min_x == -2010 and boxes[3].max_z == 509, "mine box unchanged")
local index = wp.new(dofile(dir .. "/index128.lua"), {boxes = boxes})
check(index.kind_at(1000 + 34, 51, -900) == "fortress" and index.kind_at(1000 + 35, 51, -900) == nil,
	"fortress margin ends after 10")
check(index.kind_at(1000, 50 + 26, -900 - 34) == "fortress" and index.kind_at(1000, 50 + 27, -900) == nil,
	"fortress box top")
check(index.kind_at(2000 - 23, 71, 40) == "camp" and index.kind_at(2000 - 24, 71, 40) == nil, "camp margin")
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

print(("R31 M PORTABLE PASS checks=%d"):format(checks))
