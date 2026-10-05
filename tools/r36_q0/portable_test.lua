-- Round 36 lane Q0 portable test: the shared data of the main questline
-- (round36-plan.md §4.7, the story bible docs/planning/round36/story-bible.md).
-- Checks:
--   S  the ten corrupted sub-types: role, name, family, body and level band as
--      the bible gives them, the one ember tint #B4472A in every zone whose
--      recipe spawns them and nowhere else, always a minor role (at most a
--      quarter of a roster's weight), the replaced roles still in their zone;
--   T  the REAL grug_mobs/subtypes.lua on a stub engine: a corrupted bandit
--      is tinted on activation in its zone, not outside it; after a level
--      change recomposes its skin (refresh_visual) the tint goes back on top
--      once, never twice;
--   O  the twelve quest-object kinds, exactly, with their texture files;
--   P  the four rule-placed quest places under their new names;
--   A  the three achievements, their counters and their cloaks;
--   I  the captains' orders as quest items;
--   W  lane A's art wired: every rift texture and both commander tabards
--      name a shipped file.
--
-- Usage (repo root): luajit tools/r36_q0/portable_test.lua [REPO]
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
local function exists(path)
	local handle = io.open(path, "r")
	if handle then handle:close() end
	return handle ~= nil
end
local function load_json(path)
	return json.decode(assert(read(repo .. "/" .. path), "missing " .. path))
end

local MOBS = repo .. "/mods/ENTITIES/grug_mobs"
local LOW = {"front_broken_causeway", "front_shattered_line"}
local GRAVESALT, SKYGLASS = {"front_gravesalt_escarpment"}, {"front_skyglass_canopy"}
local HIGH = {GRAVESALT[1], SKYGLASS[1]}
-- The bible's table (§3): role -> name, family, base, zones; the level band
-- is the zones' band.
local CORRUPTED = {
	coal_purse_factor = {"Coal-Purse Factor", "outlaw", "grug_mobs:bandit", LOW},
	ash_writ_bowman = {"Ash-Writ Bowman", "outlaw", "grug_mobs:bandit_archer", HIGH},
	brandbound_collector = {"Brandbound Collector", "skeleton", "grug_mobs:skeleton_raider", LOW},
	tallow_sealed_husk = {"Tallow-Sealed Husk", "zombie", "grug_mobs:sun_dried_husk", LOW},
	kiln_whisper_hexer = {"Kiln-Whisper Hexer", "skeleton", "grug_mobs:bog_witch", GRAVESALT},
	debtjaw_hound = {"Debtjaw Hound", "wolf", "grug_mobs:blightfang_wolf", GRAVESALT},
	embergrit_gnawer = {"Embergrit Gnawer", "weevil", "grug_mobs:stone_mite", GRAVESALT},
	dunshade_prowler = {"Dunshade Prowler", "cat", "grug_mobs:panther", SKYGLASS},
	furnace_coil_serpent = {"Furnace-Coil Serpent", "serpent", "grug_mobs:serpent", SKYGLASS},
	sootlace_spinner = {"Sootlace Spinner", "spider", "grug_mobs:jungle_spider", SKYGLASS},
}
local BAND = {front_broken_causeway = {41, 50}, front_shattered_line = {41, 50},
	front_gravesalt_escarpment = {51, 60}, front_skyglass_canopy = {51, 60}}

------------------------------------------------------------------------------
-- S: the data.
------------------------------------------------------------------------------
local subtypes = load_json("mods/ENTITIES/grug_mobs/data/subtypes.json")
local tints = {}
for _, row in ipairs(load_json("mods/ENTITIES/grug_mobs/data/tints.json")) do tints[row.id] = row end
local by_role = {}
for _, row in ipairs(subtypes) do by_role[row.role] = row end

-- Where each role spawns: zone -> role -> true, and the rosters it is in.
local spawns, rosters = {}, {}
for zone in pairs(BAND) do
	local recipe = load_json("mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json").recipe
	spawns[zone] = {}
	local function roster(list, where)
		if type(list) ~= "table" then return end
		rosters[#rosters + 1] = {list = list, where = where}
		for _, entry in ipairs(list) do spawns[zone][entry.role] = true end
	end
	for _, belt in ipairs(recipe.belts) do
		for _, kind in pairs(belt.kinds) do
			roster(kind.day, zone .. "/" .. kind.id .. " day")
			roster(kind.night, zone .. "/" .. kind.id .. " night")
		end
	end
	for _, camp in ipairs(recipe.camps or {}) do roster(camp.roster, zone .. "/" .. camp.id) end
end

local count = 0
for role, want in pairs(CORRUPTED) do
	count = count + 1
	local row = by_role[role]
	if check(row ~= nil, "S " .. role .. " is a sub-type") then
		eq(row.display, want[1], "S " .. role .. " name")
		eq(row.family, want[2], "S " .. role .. " family")
		eq(row.base, want[3], "S " .. role .. " body")
		eq(row.tier, "normal", "S " .. role .. " normal tier")
		eq(row.disposition, "aggressive", "S " .. role .. " aggressive")
		local band = BAND[want[4][1]]
		check(row.levels[1] == band[1] and row.levels[2] == band[2],
			"S " .. role .. " levels are its zones' band " .. band[1] .. "-" .. band[2])
		local tinted = 0
		for zone, tint in pairs(row.tint_by_zone or {}) do
			tinted = tinted + 1
			local t = tints[tint]
			check(t and t.modifier and t.modifier:find("^%^%[colorize:#B4472A:%d+$") ~= nil,
				"S " .. role .. " in " .. zone .. ": the ember tint (" .. tostring(tint) .. ")")
			check(spawns[zone] and spawns[zone][role], "S " .. role .. " tinted in " .. zone .. " spawns there")
		end
		eq(tinted, #want[4], "S " .. role .. " tinted in exactly its zones")
		for _, zone in ipairs(want[4]) do
			check(spawns[zone][role], "S " .. role .. " spawns in " .. zone)
		end
		for zone in pairs(BAND) do
			if spawns[zone][role] then
				check(row.tint_by_zone[zone] ~= nil, "S " .. role .. " spawns in " .. zone .. " only tinted")
			end
		end
	end
end
eq(count, 10, "S ten corrupted sub-types")
-- A corrupted role joins a roster as its minor role; the role it replaced is
-- still elsewhere in the zone (every role of a roster's main still spawns,
-- trivially; the minor roles replaced in Round 36 are listed here).
for _, r in ipairs(rosters) do
	local total = 0
	for _, entry in ipairs(r.list) do total = total + entry.weight end
	for _, entry in ipairs(r.list) do
		if CORRUPTED[entry.role] then
			check(entry.weight * 4 <= total, "S " .. entry.role .. " is a minor role in " .. r.where)
		end
	end
end
local KEPT = {
	front_broken_causeway = {"watchful_carrion_crow", "causeway_ford_zombie", "causeway_brigand"},
	front_shattered_line = {"siege_deserter", "siege_deserter_archer", "dustwing_vulture", "unburied_husk"},
	front_gravesalt_escarpment = {"salt_antler_stag", "salt_boring_weevil", "salt_hide_bear",
		"last_watch_husk", "last_watch_zombie", "saltroad_deserter", "last_watch_skeleton_raider"},
	front_skyglass_canopy = {"last_watch_skeleton_raider", "last_watch_zombie", "saltbound_zombie",
		"last_watch_husk", "saltbound_husk"},
}
-- The Skyglass rootways keep the Saltbound Husk by day: the 54-57 belt's
-- only daylight zombie (its catalogue note: mandatory where daylight lacks
-- blight-ground zombies).
local husk_by_day = false
for _, r in ipairs(rosters) do
	if r.where == "front_skyglass_canopy/rootways day" then
		for _, entry in ipairs(r.list) do husk_by_day = husk_by_day or entry.role == "saltbound_husk" end
	end
end
check(husk_by_day, "S the Skyglass rootways keep the Saltbound Husk by day")
for zone, list in pairs(KEPT) do
	for _, role in ipairs(list) do
		check(spawns[zone][role], "S " .. role .. " still spawns in " .. zone)
	end
end

------------------------------------------------------------------------------
-- T: the real subtypes.lua on a stub engine.
------------------------------------------------------------------------------
do
	local registered, zone_at = {}, "front_broken_causeway"
	core = {
		registered_items = {}, registered_entities = {},
		get_modpath = function() return MOBS end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function() return {} end,
		parse_json = function(text) return (json.decode(text)) end,
		register_craftitem = function(name, def) core.registered_items[name] = def end,
		register_on_mods_loaded = function() end,
		colorize = function(_, text) return text end,
	}
	grug_zones = {id_at = function() return zone_at end}
	grug_mobs = {
		LEADER = {size = 1.15, hp = 1.5},
		copy_base_def = function()
			return {attack_type = "dogfight", textures = {{"grug_mobs_blank.png", "base.png"}}}
		end,
		disposition = function() return "aggressive" end,
		register_disposition = function() end,
		register_mob = function(name, def) registered[name] = def end,
		set_base_texture = function(self, textures)
			self._grug_base_texture = textures
			self.base_texture = textures
		end,
	}
	function table.copy(t)
		local out = {}
		for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
		return out
	end
	dofile(MOBS .. "/subtypes.lua")

	local tint = tints[by_role.coal_purse_factor.tint_by_zone.front_broken_causeway].modifier
	local function bandit()
		return {name = "grug_mobs:coal_purse_factor", object = {get_pos = function() return {x = 0, z = 0} end},
			base_texture = {"grug_mobs_blank.png", "composed_skin.png"}}
	end
	local def = registered["grug_mobs:coal_purse_factor"]
	if check(def ~= nil, "T the Coal-Purse Factor registers") then
		local mob = bandit()
		def.after_activate(mob)
		eq(mob.base_texture[2], "composed_skin.png" .. tint, "T tinted on activation in its zone")
		eq(mob.base_texture[1], "grug_mobs_blank.png", "T ...the blank slot untouched")
		eq(mob.description, "Coal-Purse Factor", "T its name")
		-- A level change recomposes the skin without the tint (refresh_visual).
		grug_mobs.set_base_texture(mob, {"grug_mobs_blank.png", "composed_skin_b5.png"})
		grug_mobs.reapply_zone_variant(mob)
		eq(mob.base_texture[2], "composed_skin_b5.png" .. tint, "T the tint back on the recomposed skin")
		grug_mobs.reapply_zone_variant(mob)
		eq(mob.base_texture[2], "composed_skin_b5.png" .. tint, "T ...once, never twice")
		zone_at = "kragmar_blackwind_rise"
		local stray = bandit()
		def.after_activate(stray)
		eq(stray.base_texture[2], "composed_skin.png", "T no tint outside its zones")
		local plain = {name = "grug_mobs:causeway_brigand", base_texture = {"x.png"}}
		grug_mobs.reapply_zone_variant(plain)
		eq(plain.base_texture[1], "x.png", "T a sub-type without a tint keeps its skin")
	end
end

------------------------------------------------------------------------------
-- O, P: the quest objects and places.
------------------------------------------------------------------------------
local KINDS = {"impounded_pay", "false_requisition", "brand_rubbing", "ash_slab", "toll_box",
	"courier_ledger", "branded_pay_pit", "pledged_standard", "tally_stone", "rootmark",
	"survey_cairn", "wreck_pay_chest"}
local objects = load_json("mods/PLAYER/grug_quests/data/use_objects.json")
local seen = 0
for kind, row in pairs(objects) do
	if kind ~= "notes" then
		seen = seen + 1
		eq(row.texture, "grug_quests_obj_" .. kind .. ".png", "O " .. kind .. " texture name")
		check(exists(repo .. "/mods/PLAYER/grug_quests/textures/" .. tostring(row.texture)),
			"O " .. kind .. " texture file")
		check(type(row.size) == "number" and row.size >= 1 and row.size <= 1.5, "O " .. kind .. " size")
	end
end
for _, kind in ipairs(KINDS) do check(objects[kind] ~= nil, "O kind " .. kind) end
eq(seen, 12, "O exactly the twelve kinds")

local PLACES = {elandor_stormvault_heights = {"brandscar_cairn", "Brandscar Cairn"},
	elandor_glassroot_wilds = {"couriers_stump", "Courier's Stump"},
	kragmar_blackwind_rise = {"ashen_grave", "Ashen Grave"},
	kragmar_thunderroot_wilds = {"coinpit_hollow", "Coinpit Hollow"}}
for zone, want in pairs(PLACES) do
	local places = load_json("mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json").recipe.places
	eq(places and #places, 1, "P one place in " .. zone)
	eq(places and places[1].id, want[1], "P " .. zone .. " place id")
	eq(places and places[1].name, want[2], "P " .. zone .. " place name")
end

------------------------------------------------------------------------------
-- A, I, W.
------------------------------------------------------------------------------
local catalog = dofile(repo .. "/mods/PLAYER/grug_achievements/catalog.lua")
local cloaks, achievements = {}, {}
for _, c in ipairs(catalog.cloaks) do cloaks[c.id] = c end
for _, a in ipairs(catalog.achievements) do achievements[a.id] = a end
for id, want in pairs({
	every_name_accounted_for = {"Every Name Accounted For", "quest:accord_main_final", "unburnt_roll"},
	our_oaths_are_ours = {"Our Oaths Are Ours", "quest:throng_main_final", "unbought_banner"},
	last_claim_denied = {"The Last Claim Denied", "boss:rift", "broken_due"}}) do
	local a = achievements[id]
	if check(a ~= nil, "A achievement " .. id) then
		eq(a.name, want[1], "A " .. id .. " name")
		eq(a.counter, want[2], "A " .. id .. " counter")
		check(#a.tiers == 1 and a.tiers[1].at == 1 and a.tiers[1].cloak == want[3],
			"A " .. id .. " one tier at 1 unlocking " .. want[3])
		eq(cloaks[want[3]] and cloaks[want[3]].texture, "grug_achievements_cloak_" .. want[3] .. ".png",
			"A cloak " .. want[3] .. " texture")
	end
end

local items = {}
for _, row in ipairs(load_json("mods/ENTITIES/grug_mobs/data/items.json")) do items[row.id] = row end
for _, id in ipairs({"grug_mobs:throng_captains_orders", "grug_mobs:accord_captains_orders"}) do
	eq(items[id] and items[id].kind, "quest", "I " .. id .. " is a quest item")
end

local rift = read(MOBS .. "/rift.lua") or ""
local block = rift:match("local TEXTURES = (%b{})") or ""
local named = 0
for key, file in block:gmatch('(%w+) = "([^"]+)"') do
	named = named + 1
	check(file:find("^[%w_]+%.png$") and exists(MOBS .. "/textures/" .. file),
		"W rift texture " .. key .. " is a shipped file (" .. file .. ")")
end
eq(named, 4, "W four rift textures")
for _, faction in ipairs({"accord", "throng"}) do
	check(exists(MOBS .. "/textures/grug_mobs_commander_" .. faction .. "_overlay.png"),
		"W the " .. faction .. " commander's tabard file")
end
check((read(MOBS .. "/guard.lua") or ""):find('"grug_mobs_commander_" .. faction .. "_overlay.png"', 1, true) ~= nil,
	"W guard.lua dresses the commanders in it")

if failures > 0 then
	print(("R36 Q0 PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R36 Q0 PORTABLE PASS checks=%d"):format(checks))
