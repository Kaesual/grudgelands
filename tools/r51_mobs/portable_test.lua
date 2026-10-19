-- Round 51 lane MOBS, step M1 portable test (LuaJIT): the water mobs
-- (sea plan rulings S10-S17, §5; round51-plan.md MOBS).
--
--   luajit tools/r51_mobs/portable_test.lua [REPO]
--
-- A. The data against the accepted NAMES draft (tools/r51_names/draft.json):
--    the 17 sub-type rows (role, family, base, name, disposition, levels,
--    tier, drop family; the sizes fitted to the catalogue's 0.75-1.3 over an
--    enlarged base so the shown size stays the draft's), the design
--    catalogue copies byte-equal, the fish drop tables (each band a family
--    reaches drops that band's fishing fish 1/1), the names (the world slots
--    Bay Shark L30, Abyssal Shark L70, Tide Goby L1 and, until step M2 places
--    them, one world slot per sub-type bearing its draft name), the water
--    authority list, no quest naming a critter.
-- B. Sub-type selection at every ladder edge: the role a belt takes is the
--    family's role of the belt's tier (the tier holding most of the belt's
--    levels, the higher on a tie: tools/r38_names/check_rules.py
--    effective_tier); every draft slot follows it; level 20 resolves by its
--    belt (L18-20 the T2 role, L20-23 the T3 role, a lone L20 the T2 role)
--    and drops band-2 loot either way.
-- C. Registrations: the REAL disposition.lua, swimmer.lua, the five mob files
--    and subtypes.lua over the REAL data files, under a small stub of
--    init.lua's register_mob: dispositions, tiers, fixed levels, level
--    clamps, swimmers vs amphibians, silence, sizes, drops by band at the
--    ladder edges, the sharks' and the goby's static drops.
-- D. The swimmer reset (S11) in the REAL aggro.lua leash tick: a pure
--    swimmer whose target is in water, wades or rides a boat keeps fighting;
--    a target ashore (or on a ground mount) resets it: forgotten, healed,
--    the player given up, and the evade swims it home all the way (arrival
--    4 nodes, not the 32-node wander radius); the reach veto refuses players
--    ashore at acquisition; the Kraken, critters, amphibians and land mobs
--    are untouched.
-- Prints "R51 MOBS PORTABLE PASS checks=<n>" or exits 1 listing failures.

local ROOT = arg and arg[1] or "."
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
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local json = dofile(ROOT .. "/tools/r28_b1/json.lua")
local function read_json(path) return json.parse(read(path)) end

local MOBS = "mods/ENTITIES/grug_mobs"
local DRAFT = read_json("tools/r51_names/draft.json")
local SUBTYPES = read_json(MOBS .. "/data/subtypes.json")
local DROPS = read_json(MOBS .. "/data/drops.json")
local NAMES = read_json(MOBS .. "/data/names.json").names

-- The base enlargement per family (tortoise.lua, frog.lua, stingray.lua):
-- the draft's size is the shown size, the catalogue's is size / K.
local K = {tortoise = 1.1, frog = 1.35, stingray = 1.15}
local FISH = {"grug_mobs:raw_fish", "grug_fishing:silver_trout", "grug_fishing:mire_carp",
	"grug_fishing:frostfin", "grug_fishing:ember_eel", "grug_fishing:storm_tuna"}
local function band_of(level)
	return math.max(1, math.min(6, math.floor((level - 1) / 10) + 1))
end

------------------------------------------------------------------------------
-- A. The data
------------------------------------------------------------------------------
local shipped = {}
for _, row in ipairs(SUBTYPES) do shipped[row.role] = row end
eq(#DRAFT.subtypes, 17, "A the draft has 17 sub-types")
local roles_of = {}
for _, d in ipairs(DRAFT.subtypes) do
	local row = shipped[d.role]
	if check(row ~= nil, "A " .. d.role .. " is in subtypes.json") then
		for _, key in ipairs({"family", "base", "display", "disposition", "tier", "drops"}) do
			eq(row[key], d[key], "A " .. d.role .. " " .. key)
		end
		eq(row.levels[1], d.levels[1], "A " .. d.role .. " lowest level")
		eq(row.levels[2], d.levels[2], "A " .. d.role .. " highest level")
		check(row.size >= 0.75 and row.size <= 1.3, "A " .. d.role .. " size in 0.75-1.3")
		check(math.abs(row.size * K[d.family] - d.size) <= 0.07,
			"A " .. d.role .. " shown size " .. row.size * K[d.family] .. " ~ draft " .. d.size)
		eq(row.habitats, nil, "A " .. d.role .. " carries no draft-only key")
		roles_of[d.family] = roles_of[d.family] or {}
		table.insert(roles_of[d.family], row)
	end
end
for family, rows in pairs(roles_of) do
	table.sort(rows, function(a, b) return a.levels[1] < b.levels[1] end)
	for i = 2, #rows do
		check(rows[i].size > rows[i - 1].size, "A " .. family .. " sizes grow up the ladder")
	end
end
for _, file in ipairs({"subtypes", "drops", "items", "tints"}) do
	check(read(MOBS .. "/data/" .. file .. ".json") ==
		read("docs/planning/round28/design/catalog/" .. file .. ".json"),
		"A the design catalogue's " .. file .. ".json is the shipped file")
end

local drop_family = {}
for _, row in ipairs(DROPS) do drop_family[row.family] = row end
for family, rows in pairs(roles_of) do
	local fam = drop_family[family]
	if check(fam ~= nil, "A drops.json has the " .. family .. " family") then
		local need = {}
		for _, row in ipairs(rows) do
			for level = row.levels[1], row.levels[2] do need[band_of(level)] = true end
		end
		for band = 1, 6 do
			local list = fam.bands[tostring(band)]
			if need[band] then
				local fish
				for _, drop in ipairs(list or {}) do
					if drop.item == FISH[band] then fish = drop end
				end
				check(fish ~= nil and fish.chance == 1 and fish.min >= 1,
					"A " .. family .. " band " .. band .. " drops " .. FISH[band] .. " 1/1")
			else
				eq(list, nil, "A " .. family .. " has no band " .. band .. " it never reaches")
			end
		end
	end
end

eq(NAMES["world/bay_shark/L30-30"], "Bay Shark", "A world slot Bay Shark L30")
eq(NAMES["world/abyssal_shark/L70-70"], "Abyssal Shark", "A world slot Abyssal Shark L70")
eq(NAMES["world/goby/L1-1"], "Tide Goby", "A world slot Tide Goby L1")
eq(NAMES["world/kraken/L70-70"], "Kraken", "A the Kraken keeps its slot")
for _, w in ipairs(DRAFT.world) do
	eq(NAMES[w.key], w.name, "A the draft's world slot " .. w.key)
end
-- Step M2: the recipes' water kinds place every water role, so the names
-- are zone slots: every draft slot bears its draft name, a slot the draft
-- lacks (a belt its survey saw no water beside) its role's one name, and no
-- sub-type is an unplaced world slot any more. No frog in an L1-2 belt (the
-- NAMES lane's question 5).
local display = {}
for _, d in ipairs(DRAFT.subtypes) do display[d.role] = d.display end
for key, slot in pairs(DRAFT.slots) do
	eq(NAMES[key], slot.name, "A draft zone slot " .. key)
end
local water_zone_slots, frog_home = 0, 0
for key, name in pairs(NAMES) do
	local scope, role, lo, hi = key:match("^([%w_]+)/([%w_]+)/L(%d+)%-(%d+)$")
	if role and display[role] then
		check(scope ~= "world", "A " .. key .. " is no unplaced world slot")
		eq(name, display[role], "A " .. key .. " bears its role's name")
		water_zone_slots = water_zone_slots + 1
		if role:match("^frog_") and tonumber(hi) <= 2 then frog_home = frog_home + 1 end
	end
end
check(water_zone_slots >= 291, "A the water zone slots (" .. water_zone_slots .. ") hold the draft's 291")
eq(frog_home, 0, "A no frog slot in an L1-2 belt")
eq(DRAFT.slots["elandor_dawnmere_fields/frog_t1/L1-2"], nil, "A the draft dropped Dawnmere's L1-2 frog")
eq(DRAFT.slots["kragmar_sunscar_flats/frog_t1/L1-2"], nil, "A the draft dropped Sunscar's L1-2 frog")
local policy = read(MOBS .. "/spawn_policy.lua")
local authority = policy:match("local INDEPENDENT_AUTHORITY = (%b{})")
for _, name in ipairs({"kraken", "reed_angelfish", "bay_shark", "abyssal_shark", "goby"}) do
	check(authority and authority:find('"grug_mobs:' .. name .. '"', 1, true) ~= nil,
		"A " .. name .. " is a water authority (a world slot)")
end
for _, name in ipairs({"tortoise", "frog", "stingray"}) do
	check(authority and not authority:find('"grug_mobs:' .. name .. '"', 1, true),
		"A " .. name .. " is not: its family spawns from zone recipes (M2)")
end
do
	-- Every zone's quest files (the zone ids are the names file's scopes).
	local zones, named, files = {}, {}, 0
	for key in pairs(NAMES) do
		local zone = key:match("^([%w_]+)/")
		if zone and zone ~= "world" then zones[zone] = true end
	end
	for zone in pairs(zones) do
		for _, suffix in ipairs({".quests.json", ".front.quests.json"}) do
			local path = "mods/PLAYER/grug_quests/data/zones/" .. zone .. suffix
			local handle = io.open(ROOT .. "/" .. path, "rb")
			if handle then
				files = files + 1
				local text = handle:read("*a")
				handle:close()
				for _, word in ipairs({"goby", "Tide Goby", "reed_angelfish", "Reed Angelfish"}) do
					if text:find(word, 1, true) then named[#named + 1] = path .. ": " .. word end
				end
			end
		end
	end
	check(files >= 38, "A the quest files of every zone read (" .. files .. ")")
	eq(#named, 0, "A no quest names a critter fish " .. table.concat(named, ", "))
end

------------------------------------------------------------------------------
-- B. Sub-type selection at the ladder edges
------------------------------------------------------------------------------
-- The family's role for a belt [lo, hi]: the role named for the belt's tier
-- (most of its levels, the higher tier on a tie), whose levels hold the belt.
local TIER_LEVELS = {{1, 10}, {11, 20}, {20, 30}, {31, 40}, {41, 50}, {51, 60}}
local function belt_tier(lo, hi)
	local count = {}
	for level = lo, hi do
		local band = band_of(level)
		count[band] = (count[band] or 0) + 1
	end
	local best
	for band = 1, 6 do
		if count[band] and (not best or count[band] >= count[best]) then best = band end
	end
	return best
end
local function role_for(family, lo, hi)
	local tier = TIER_LEVELS[belt_tier(lo, hi)]
	for _, row in ipairs(roles_of[family] or {}) do
		if row.levels[1] == tier[1] and row.levels[2] == tier[2] then
			if row.levels[1] <= lo and hi <= row.levels[2] then return row.role end
			return nil
		end
	end
	return nil
end
local edges = {
	{"frog", 1, 2, "frog_t1"}, {"frog", 8, 10, "frog_t1"}, {"frog", 11, 13, "frog_t2"},
	{"frog", 18, 20, "frog_t2"}, {"frog", 20, 23, "frog_t3"}, {"frog", 20, 20, "frog_t2"},
	{"frog", 21, 23, "frog_t3"}, {"frog", 28, 30, "frog_t3"}, {"frog", 31, 33, "frog_t4"},
	{"frog", 38, 40, "frog_t4"}, {"frog", 41, 43, "frog_t5"}, {"frog", 48, 50, "frog_t5"},
	{"frog", 51, 53, "frog_t6"}, {"frog", 58, 60, "frog_t6"}, {"frog", 60, 60, "frog_t6"},
	{"tortoise", 1, 2, "tortoise_t1"}, {"tortoise", 18, 20, "tortoise_t2"},
	{"tortoise", 20, 23, "tortoise_t3"}, {"tortoise", 60, 60, "tortoise_t6"},
	{"stingray", 20, 23, "stingray_t3"}, {"stingray", 18, 20, "stingray_t2"},
	{"stingray", 41, 43, nil}, {"stingray", 58, 60, "stingray_t6"},
}
for _, e in ipairs(edges) do
	eq(role_for(e[1], e[2], e[3]), e[4], ("B %s L%d-%d"):format(e[1], e[2], e[3]))
end
local slots = 0
for key, slot in pairs(DRAFT.slots) do
	slots = slots + 1
	eq(role_for(slot.family, slot.levels[1], slot.levels[2]), slot.role, "B draft slot " .. key)
end
eq(slots, 291, "B the draft's 291 zone slots (293 less the two L1-2 frogs)")
eq(band_of(20), 2, "B a level-20 mob drops band 2 (either role)")
eq(band_of(21), 3, "B level 21 drops band 3")

------------------------------------------------------------------------------
-- C. Registrations (the real files under a small stub)
------------------------------------------------------------------------------
local function deep_copy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do out[deep_copy(k, seen)] = deep_copy(v, seen) end
	return out
end
table.copy = function(t) return deep_copy(t) end

-- A tiny node world for the reach checks (D): water at y <= 1 for x <= 0,
-- dry land above y = 0 for x > 0; `cells` overrides.
local cells = {}
local function node_at(x, y, z)
	local key = x .. "," .. y .. "," .. z
	if cells[key] then return cells[key] end
	if x <= 0 then return y <= 1 and "default:water_source" or "air" end
	return y <= 0 and "default:sand" or "air"
end
local mounts_active = {}
local mods_loaded = {}
local entities = {}
_G.core = {
	get_modpath = function() return ROOT .. "/" .. MOBS end,
	get_current_modname = function() return "grug_mobs" end,
	parse_json = function(text) return json.parse(text) end,
	colorize = function(_, text) return text end,
	get_dir_list = function() return {} end,
	registered_items = {},
	registered_entities = entities,
	registered_nodes = {},
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	get_content_id = function(name) return name end,
	get_name_from_content_id = function(id) return id end,
	get_node_raw = function(x, y, z) return node_at(x, y, z) end,
	get_node_or_nil = function(pos) return {name = node_at(pos.x, pos.y, pos.z)} end,
	get_item_group = function(name, group)
		return group == "water" and name == "default:water_source" and 3 or 0
	end,
	global_exists = function(name) return name == "grug_mounts" end,
	is_player = function(o) return type(o) == "table" and o.is_player_ref == true end,
	CONTENT_IGNORE = "ignore",
}
_G.grug_mounts = {active = mounts_active}
_G.vector = {
	new = function(x, y, z) return {x = x, y = y, z = z} end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}
local now = 1000
_G.grug_core = {
	mono_time = function() return now end,
	recheck_switch = function() end,
	prune_engagement = function() end,
	clear_threat = function(self) self._threat_cleared = true end,
}
-- The water query of part G's spawn checks: a scripted answer.
local query = {}
_G.grug_zones = {
	id_at = function() return "test_zone" end,
	water_query_at = function() return query.class, query.zone, query.level,
		query.distance, query.depth, query.protected end,
}
-- The spawn rows the mob files add (mobs:spawn), by mob name.
local rows = {}
_G.mobs = {spawn = function(_, def) rows[def.name] = def end}
core.get_node = function(pos)
	return {name = node_at(math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))}
end

local base_defs, registered = {}, {}
_G.grug_mobs = {
	CALM_WALK_MAX = 2.5,
	LEADER = {size = 1.15, hp = 1.5},
	atlas_textures = function(texture, slots)
		local list = {}
		for i = 1, slots do list[i] = texture end
		return list
	end,
	-- init.lua register_mob, the parts these files and subtypes.lua rely on.
	register_mob = function(name, def)
		base_defs[name] = deep_copy(def)
		grug_mobs.apply_disposition(name, def)
		if def._grug_swimmer then grug_mobs.prepare_swimmer_def(name, def) end
		registered[name] = def
		entities[name] = {initial_properties = {collisionbox = def.collisionbox},
			fly_in = def.fly_in, on_step = function() end}
		entities[name].__index = entities[name]
		if def._grug_swimmer then grug_mobs.install_swimmer_guard(name, def) end
	end,
	copy_base_def = function(name)
		if base_defs[name] then return deep_copy(base_defs[name]) end
		-- A land base of the catalogue (not under test here): a minimal
		-- ambient definition, so its land sub-types load next to the water
		-- ones and every role collision is still seen.
		if grug_mobs.disposition(name) then
			return {attack_type = "dogfight", visual_size = {x = 1, y = 1},
				collisionbox = {-0.4, 0, -0.4, 0.4, 1, 0.4}}
		end
		return nil
	end,
	-- Walks (patrol.lua) and the rest leash_tick calls (D).
	walk_toward = function() end,
	walk_fixed = function(self) self._walked = (self._walked or 0) + 1 end,
	walk_clear = function() end,
	walk_follow = function() end,
	idle_health_tick = function() end,
	place_on_ground = function() end,
	roam_avoid_tick = function() end,
}
dofile(ROOT .. "/" .. MOBS .. "/disposition.lua")
dofile(ROOT .. "/" .. MOBS .. "/swimmer.lua")
for _, file in ipairs({"tortoise", "frog", "stingray", "shark", "goby"}) do
	dofile(ROOT .. "/" .. MOBS .. "/" .. file .. ".lua")
end
dofile(ROOT .. "/" .. MOBS .. "/subtypes.lua")
dofile(ROOT .. "/" .. MOBS .. "/aggro.lua")

local BASES = {
	tortoise = {disposition = "neutral", swimmer = false, type = "animal"},
	frog = {disposition = "aggressive", swimmer = false, type = "monster"},
	stingray = {disposition = "aggressive", swimmer = true, type = "monster"},
	bay_shark = {disposition = "aggressive", swimmer = true, type = "monster",
		level = 30, tier = "normal"},
	abyssal_shark = {disposition = "aggressive", swimmer = true, type = "monster",
		level = 70, tier = "elite"},
	goby = {disposition = "critter", swimmer = true, type = "animal", tier = "critter"},
}
for short, want in pairs(BASES) do
	local name = "grug_mobs:" .. short
	local def = registered[name]
	if check(def ~= nil, "C " .. name .. " registered") then
		eq(grug_mobs.disposition(name), want.disposition, "C " .. short .. " disposition")
		eq(def.type, want.type, "C " .. short .. " type")
		eq(def._grug_voice, false, "C " .. short .. " is silent")
		eq(def._grug_swimmer == true, want.swimmer, "C " .. short .. " pure swimmer")
		eq(def.fly == true, want.swimmer, "C " .. short .. " flies in water only as a swimmer")
		eq(def.floats, true, "C " .. short .. " floats")
		eq(def._grug_fixed_level, want.level, "C " .. short .. " fixed level")
		eq(def._grug_tier, want.tier, "C " .. short .. " tier")
		if want.swimmer then
			eq(def.fly_in, "default:water_source", "C " .. short .. " swims in sea water")
			eq(def.stepheight, 0, "C " .. short .. " never climbs a bank")
		else
			check(def.stepheight > 1, "C " .. short .. " steps up a bank")
		end
	end
end
eq(registered["grug_mobs:goby"].passive, true, "C the goby is passive")
eq(registered["grug_mobs:tortoise"].attack_players, false, "C the tortoise acquires nobody")
eq(registered["grug_mobs:tortoise"].passive, false, "C the tortoise bites back")
eq(registered["grug_mobs:frog"].attack_players, true, "C the frog hunts players")
local abyssal = registered["grug_mobs:abyssal_shark"].visual_size.x
local bay = registered["grug_mobs:bay_shark"].visual_size.x
check(abyssal / bay * 1.4 >= 2 and abyssal / bay * 1.4 <= 3,
	"C the Abyssal Shark shows 2-3 times the Bay Shark (" .. abyssal / bay * 1.4 .. ")")

for _, d in ipairs(DRAFT.subtypes) do
	local name = "grug_mobs:" .. d.role
	local def = registered[name]
	local sub = grug_mobs.subtype(name)
	if check(def ~= nil and sub ~= nil, "C " .. d.role .. " registered as a sub-type") then
		eq(grug_mobs.family_of(name), d.family, "C " .. d.role .. " family")
		eq(grug_mobs.disposition(name), d.disposition, "C " .. d.role .. " disposition")
		eq(def._grug_min_level, d.levels[1], "C " .. d.role .. " level floor")
		eq(def._grug_max_level, d.levels[2], "C " .. d.role .. " level cap")
		eq(def._grug_tier, "normal", "C " .. d.role .. " normal tier")
		eq(def._grug_swimmer == true, d.family == "stingray", "C " .. d.role .. " swimmer as its base")
		eq(def.group_attack, false, "C " .. d.role .. " fights alone")
		local base = base_defs["grug_mobs:" .. d.family]
		local shown = def.visual_size.x
		check(math.abs(shown - base.visual_size.x * sub.size) < 1e-9,
			"C " .. d.role .. " visual size = base x size")
		-- Drops at the role's two edges: that level's band fish.
		for _, level in ipairs({d.levels[1], d.levels[2]}) do
			local rows = grug_mobs.band_drop_rows({name = name, _grug_level = level})
			local found = false
			for _, row in ipairs(rows or {}) do
				if row.name == FISH[band_of(level)] and row.chance == 1 then found = true end
			end
			check(found, ("C %s at L%d drops %s"):format(d.role, level, FISH[band_of(level)]))
		end
	end
end
do
	local rows = grug_mobs.band_drop_rows({name = "grug_mobs:frog_t3", _grug_level = 20})
	eq(rows and rows[1].name, "grug_fishing:silver_trout", "C a level-20 Fen Croaker drops band 2")
	rows = grug_mobs.band_drop_rows({name = "grug_mobs:frog_t2", _grug_level = 20})
	eq(rows and rows[1].name, "grug_fishing:silver_trout", "C a level-20 Bog Toad drops band 2")
end
local function static_drop(short, item)
	for _, row in ipairs(registered["grug_mobs:" .. short].drops or {}) do
		if row.name == item then return row end
	end
end
eq(grug_mobs.band_drop_rows({name = "grug_mobs:bay_shark", _grug_level = 30}), nil,
	"C the Bay Shark keeps its static drops")
check(static_drop("bay_shark", FISH[3]) ~= nil, "C the Bay Shark (L30) drops band-3 fish")
check(static_drop("abyssal_shark", FISH[6]) ~= nil, "C the Abyssal Shark (L70) drops band-6 fish")
check(static_drop("goby", "grug_mobs:raw_fish") ~= nil, "C the Tide Goby drops a Raw Fish")
eq(registered["grug_mobs:goby"]._grug_no_quality_loot, true, "C the goby drops no quality loot")

------------------------------------------------------------------------------
-- D. The swimmer reset (S11) and the reach veto
------------------------------------------------------------------------------
local function player(name, pos, attach)
	local p = {is_player_ref = true, pos = pos}
	function p.get_pos() return p.pos end
	function p.get_hp() return 20 end
	function p.get_player_name() return name end
	function p.get_attach() return attach end
	return p
end
-- Water (x <= 0, y <= 1), land (x > 0, ground y = 0, feet at 0.5).
local SWIM = {x = -5, y = 0.6, z = 0}     -- at the surface
local DIVE = {x = -5, y = -3, z = 0}      -- under water
local WADE = {x = 1, y = 0.5, z = 3}      -- wading: water over the sand
local BANK = {x = 4, y = 0.5, z = 0}      -- dry land
cells["1,1,3"] = "default:water_source"
eq(grug_mobs.in_swimmer_reach(player("a", SWIM)), true, "D a swimmer at the surface is in reach")
eq(grug_mobs.in_swimmer_reach(player("a", DIVE)), true, "D a diver is in reach")
eq(grug_mobs.in_swimmer_reach(player("a", WADE)), true, "D a wader is in reach")
eq(grug_mobs.in_swimmer_reach(player("a", BANK)), false, "D a player on the bank is out of reach")
mounts_active.boater = {mode = "water"}
mounts_active.rider = {mode = "land"}
eq(grug_mobs.in_swimmer_reach(player("boater", {x = -5, y = 2, z = 0}, {})), true,
	"D a player on a boat is in reach")
eq(grug_mobs.in_swimmer_reach(player("rider", BANK, {})), false,
	"D a player on a ground mount on the bank is out of reach")
eq(grug_mobs.in_swimmer_reach(player("nobody", BANK, {})), false,
	"D attached without a water mount is out of reach")
eq(grug_mobs.in_swimmer_reach({get_pos = function() return nil end}), false,
	"D a vanished target is out of reach")

-- The acquisition veto (swimmer.lua), on the fighting swimmers only.
local veto = entities["grug_mobs:stingray"]._grug_target_veto
if check(type(veto) == "function", "D the stingray carries the reach veto") then
	eq(veto({}, player("a", BANK)), true, "D the veto refuses a player ashore")
	eq(veto({}, player("a", SWIM)), false, "D the veto keeps a player in water")
end
check(entities["grug_mobs:stingray_t3"]._grug_target_veto == veto, "D a stingray sub-type too")
check(entities["grug_mobs:bay_shark"]._grug_target_veto == veto, "D the Bay Shark too")
check(entities["grug_mobs:abyssal_shark"]._grug_target_veto == veto, "D the Abyssal Shark too")
eq(entities["grug_mobs:goby"]._grug_target_veto, nil, "D a critter needs none")
eq(entities["grug_mobs:frog"]._grug_target_veto, nil, "D an amphibian has none")
do
	local kraken = {fly = true, fly_in = "default:water_source", _grug_swimmer = true,
		stepheight = 0, attack_type = "dogfight", _grug_no_leash = true,
		collisionbox = {-0.8, 0, -0.8, 0.8, 1.8, 0.8}}
	entities["grug_mobs:kraken_stub"] = {initial_properties = {collisionbox = kraken.collisionbox},
		fly_in = kraken.fly_in, on_step = function() end}
	grug_mobs.install_swimmer_guard("grug_mobs:kraken_stub", kraken)
	eq(entities["grug_mobs:kraken_stub"]._grug_target_veto, nil,
		"D the no-leash Kraken keeps its own rules (no veto)")
end

-- The leash tick on a fighting swimmer.
local function fighter(fields, target)
	local pos = fields.pos or {x = -10, y = -2, z = 0}
	local self = {type = "monster", state = "attack", attack = target, health = 7,
		hp_max = 40, _grug_home = {x = -40, y = -6, z = 0}, temp = {},
		_grug_damage_pursuit_candidate = true, _grug_player_tag = {name = "a"}}
	for key, value in pairs(fields) do self[key] = value end
	self.object = {get_pos = function() return pos end}
	self.stop_attack = function(s) s.attack = nil; s.state = "stand" end
	self.move = function(p) pos = p end
	return self
end
local function tick(self)
	now = now + 1
	grug_mobs.leash_tick(self, 1)
end
local DY = entities["grug_mobs:stingray"]._grug_swim_dy
check(type(DY) == "number", "D the swimmer guard marks the stingray")
local cases = {
	{"in water", SWIM, false}, {"diving", DIVE, false}, {"wading", WADE, false},
	{"on a boat", "boat", false}, {"ashore", BANK, true}, {"on a ground mount", "mount", true},
}
for _, case in ipairs(cases) do
	local target
	if case[2] == "boat" then
		target = player("boater", {x = -5, y = 2, z = 0}, {})
	elseif case[2] == "mount" then
		target = player("rider", BANK, {})
	else
		target = player("a", case[2])
	end
	local ray = fighter({_grug_swim_dy = DY}, target)
	tick(ray)
	if case[3] then
		check(ray.attack == nil and ray.health == ray.hp_max and ray._threat_cleared
			and ray._grug_player_tag == nil,
			"D target " .. case[1] .. ": the swimmer forgets the fight and heals")
		check(ray.temp.grug_gave_up ~= nil and ray.temp.grug_gave_up.name == target.get_player_name(),
			"D target " .. case[1] .. ": the player is given up (no instant re-acquisition)")
		check(ray.temp.grug_evading ~= nil, "D target " .. case[1] .. ": it swims back home")
	else
		check(ray.attack == target and ray.health == 7 and ray.temp.grug_evading == nil,
			"D target " .. case[1] .. ": the swimmer keeps fighting")
	end
end
do
	-- The swim home: all the way (arrival 4 nodes), not just into the
	-- 32-node wander radius a land mob's evade stops at.
	local ray = fighter({_grug_swim_dy = DY}, player("a", BANK))
	tick(ray)
	ray.move({x = -30, y = -6, z = 0})
	tick(ray)
	check(ray.temp.grug_evading ~= nil and (ray._walked or 0) >= 1,
		"D 10 nodes from home the swimmer still swims home")
	ray.move({x = -37, y = -6, z = 0})
	tick(ray)
	eq(ray.temp.grug_evading, nil, "D within 4 nodes of home it is a normal swimmer again")
	-- Reset near home: nothing to swim back to.
	local near = fighter({_grug_swim_dy = DY, pos = {x = -38, y = -6, z = 0}}, player("a", BANK))
	tick(near)
	check(near.attack == nil and near.health == near.hp_max and near.temp.grug_evading == nil,
		"D a reset next to its spawn point only heals and forgets")
	-- A land mob keeps its 32-node wander radius on the way home.
	local boar = fighter({}, nil)
	boar.temp.grug_evading = {started = now}
	boar.move({x = -30, y = -6, z = 0})
	tick(boar)
	eq(boar.temp.grug_evading, nil, "D a land mob's evade still ends inside the wander radius")
end
do
	-- Untouched: an amphibian or land mob with a target ashore (it follows),
	-- the no-leash Kraken, a mob without a target.
	local frog = fighter({}, player("a", BANK))
	tick(frog)
	check(frog.attack ~= nil and frog.health == 7, "D an amphibian follows a target ashore")
	local kraken = fighter({_grug_swim_dy = DY, _grug_no_leash = true,
		_grug_damage_pursuit_candidate = false}, player("a", BANK))
	tick(kraken)
	check(kraken.attack ~= nil and kraken.health == 7, "D the Kraken keeps its own leash")
	local idle = fighter({_grug_swim_dy = DY, state = "walk"}, nil)
	tick(idle)
	eq(idle.temp.grug_evading, nil, "D an idle swimmer is left alone")
end


------------------------------------------------------------------------------
-- E. The recipes' water kinds (step M2), parsed by the REAL
--    spawn_regions_core.lua: each band holds only its families (S10, S15),
--    no frog or stingray in an L1-2 belt, every role's levels inside its
--    belt; the band rule and the belt of a level.
------------------------------------------------------------------------------
local CORE = dofile(ROOT .. "/" .. MOBS .. "/spawn_regions_core.lua")
local role_levels = {}
for _, row in ipairs(SUBTYPES) do role_levels[row.role] = row.levels end
local function family(role)
	return role:match("^(tortoise)_t%d$") or role:match("^(frog)_t%d$") or role:match("^(stingray)_t%d$")
end
local ALLOWED = {sea_shallows = {tortoise = true}, sea_deep = {stingray = true},
	lake = {frog = true, tortoise = true}, river = {frog = true}}
local recipes, bands_seen, water_kinds = {}, {}, 0
local zone_ids = {}
for key in pairs(NAMES) do
	local zone = key:match("^([%w_]+)/")
	if zone and zone ~= "world" then zone_ids[zone] = true end
end
for zone in pairs(zone_ids) do
	local handle = io.open(ROOT .. "/" .. MOBS .. "/data/zones/" .. zone .. ".spawns.json", "rb")
	if handle then
		local data = json.parse(handle:read("*a"))
		handle:close()
		local belts = data.recipe.belts
		-- Camps, leaders and quest places need the world's POIs; the water
		-- kinds do not, so they are parsed without them.
		data.recipe.camps, data.recipe.leaders, data.recipe.places = nil, nil, nil
		local ok, parsed = pcall(CORE.parse_recipe, zone, data.recipe, {
			band = {belts[1].levels[1], belts[#belts].levels[2]},
			role_levels = function(role) return role_levels[role] end,
			leader = function() return false end,
		})
		if check(ok, "E " .. zone .. " recipe parses (" .. tostring(not ok and parsed or "") .. ")") then
			recipes[zone] = parsed
			for _, belt in ipairs(parsed.belts) do
				for _, band in ipairs(CORE.WATER_TYPES) do
					local kind = belt.kinds[band]
					if kind then
						water_kinds = water_kinds + 1
						bands_seen[band] = true
						eq(kind.density, "sparse", "E " .. kind.tag .. " is sparse")
						for _, clock in ipairs({"day", "night"}) do
							for _, row in ipairs(kind.rosters[clock].list) do
								local fam = family(row.role)
								check(fam ~= nil and ALLOWED[band][fam],
									("E %s %s: %s belongs in %s"):format(kind.tag, clock, row.role, band))
								if fam == "frog" or fam == "stingray" then
									check(belt.levels[2] >= 3, "E " .. kind.tag .. ": no hostile water mob in an L1-2 belt")
								end
								local range = kind.levels_by_role[row.role]
								check(range[1] >= belt.levels[1] and range[2] <= belt.levels[2],
									"E " .. kind.tag .. " " .. row.role .. " within its belt")
							end
						end
					end
				end
			end
		end
	end
end
eq(water_kinds, 392, "E the 392 water kinds")
for _, band in ipairs(CORE.WATER_TYPES) do check(bands_seen[band], "E some zone has " .. band) end
local BAND = {
	{"lake", nil, 2, "lake"}, {"river", nil, 1, "river"},
	{"bay", 5, 20, "sea_shallows"}, {"bay", 40, 6, "sea_shallows"}, {"bay", 40, 7, "sea_deep"},
	{"belt", 16, 30, "sea_shallows"}, {"belt", 17, 30, "sea_deep"}, {"channel", 30, 10, "sea_deep"},
	{"open_sea", 300, 25, nil}, {nil, nil, nil, nil},
}
for _, b in ipairs(BAND) do
	eq(CORE.water_band(b[1], b[2], b[3]), b[4], ("E band of %s, %s from land, %s deep"):format(
		tostring(b[1]), tostring(b[2]), tostring(b[3])))
end
local DAWN = recipes.elandor_dawnmere_fields
for _, lb in ipairs({{nil, "l1_2"}, {1, "l1_2"}, {2, "l1_2"}, {3, "l3_4"}, {7, "l5_7"},
		{10, "l8_10"}, {14, "l8_10"}}) do
	eq(CORE.belt_for_level(DAWN, lb[1]).id, lb[2], "E Dawnmere's belt of level " .. tostring(lb[1]))
end
eq(CORE.water_kind(DAWN, "sea_deep", 2), nil, "E no stingray in Dawnmere's home belt")
eq(CORE.water_kind(DAWN, "sea_deep", 5).id, "sea_deep_l5_7", "E Dawnmere's L5-7 coastal waters")
eq(CORE.water_kind(DAWN, "lake", 1).rosters.day.list[1].role, "tortoise_t1",
	"E Dawnmere's home lakes: the tortoise only")
eq(#CORE.water_kind(DAWN, "lake", 1).rosters.day.list, 1, "E ... and no frog")

------------------------------------------------------------------------------
-- F. The water attempt (cut out of the REAL spawn_regions.lua): the band,
--    the zone's belt of the column's level, the kind's role, the spot (an
--    amphibian at the surface, a swimmer under it), the pocket rule, and the
--    land path's gates in order.
------------------------------------------------------------------------------
do
	local src = read(MOBS .. "/spawn_regions.lua")
	local cut = src:match("\n(SR%.POCKET_STEP = %d+.-)\n%-%- The camps of the built maps")
	if check(cut ~= nil, "F the water attempt is found in spawn_regions.lua") then
		local spawned, world = {}, {}
		local F = {SR = {}, CORE = CORE, MOD_PREFIX = "grug_mobs:", math = math,
			ipairs = ipairs, tonumber = tonumber, zones = {}}
		for zone, r in pairs(recipes) do F.zones[zone] = {recipe = r} end
		function F.count(reason) return reason end
		F.core = {
			settings = {get = function() return nil end},
			registered_entities = entities,
			get_node = function(pos) return {name = world.node_at(pos)} end,
		}
		F.grug_zones = {water_query_at = function(x, z) return world.query(x, z) end}
		F.grug_core = {surface_mob_level_at = function() return world.level end}
		F.grug_mobs = {
			disposition = grug_mobs.disposition,
			region_density_allows = function() return true end,
		}
		local pick = 1
		local SR = F.SR
		function SR.pick_role(roster)
			local row = roster.list[math.min(pick, #roster.list)]
			return row.role, row.weight
		end
		function SR.players_clear() return true end
		function SR.spawn_refused() return nil end
		function SR.in_drift() return false end
		function SR.light_allows() return true end
		function SR.spawn_mob(kind, role, g, clock)
			spawned[#spawned + 1] = {kind = kind, role = role, y = g.y + 1}
			return {}
		end
		local chunk = assert(loadstring(cut))
		setfenv(chunk, F)
		chunk()
		-- A scripted world: the surface at y 1 of sea water (any column), and
		-- one answer of the water query for the column and its neighbours.
		local function attempt(answer, level, neighbours, surface_node)
			world.level = level
			world.node_at = function() return surface_node or "default:water_source" end
			world.query = function(x, z)
				if (x ~= 0 or z ~= 0) and neighbours then return unpack(neighbours) end
				return unpack(answer)
			end
			spawned = {}
			local result = SR.water_attempt({x = 0, y = 1, z = 0, node = surface_node or
				"default:water_source"}, {}, "day")
			return result, spawned[1]
		end
		local D = "elandor_dawnmere_fields"
		local r, s = attempt({"lake", D, 5, nil, 3}, 5, nil)
		check(r == "spawned_lake" and s.role == "frog_t1" and s.y == 1 and s.kind.id == "lake_l5_7",
			"F a lake at L5: a frog of the L5-7 lakes at the surface (" .. tostring(r) .. ")")
		pick = 2
		r, s = attempt({"lake", D, 5, nil, 3}, 5, nil)
		check(r == "spawned_lake" and s.role == "tortoise_t1", "F ... or its minor role, the tortoise")
		pick = 1
		r, s = attempt({"river", D, 8, nil, 2}, 8, nil, "default:river_water_source")
		check(r == "spawned_river" and s.role == "frog_t1" and s.kind.id == "river_l8_10",
			"F a river at L8: a frog of the L8-10 rivers (" .. tostring(r) .. ")")
		r, s = attempt({"belt", D, 4, 10, 5}, 4, {"belt", D, 4, 30, 9})
		check(r == "spawned_sea_shallows" and s.role == "tortoise_t1" and s.y == 1,
			"F sea water 10 nodes from land: a tortoise at the surface (" .. tostring(r) .. ")")
		r, s = attempt({"belt", D, 6, 40, 20}, 6, {"belt", D, 6, 40, 20})
		check(r == "spawned_sea_deep" and s.role == "stingray_t1" and s.y == -1,
			"F deep sea water 40 nodes out: a stingray two nodes under the surface (" .. tostring(r) .. ")")
		r = attempt({"belt", D, 2, 40, 20}, 2, {"belt", D, 2, 40, 20})
		eq(r, "water_no_kind", "F deep water in the home belt: nothing")
		r = attempt({"open_sea", nil, nil, 400, 25}, nil, nil)
		eq(r, "water_no_band", "F the open sea: no recipe band (world rows only)")
		r = attempt({nil}, nil, nil)
		eq(r, "water_no_band", "F dry land: nothing")
		local S = "front_stormscale_summit"
		r, s = attempt({"channel", S, 60, 60, 10}, 60, {"channel", S, 60, 60, 10})
		check(r == "spawned_sea_deep" and s.role == "stingray_t6",
			"F a dragon channel at its island's L60: a Wyrmwake Ray (" .. tostring(r) .. ")")
		r = attempt({"channel", S, 60, 60, 10}, 60, {"belt", "front_shattered_line", 45, 60, 10})
		eq(r, "water_pocket", "F a channel pocket inside a belt spawns nothing")
		r = attempt({"belt", D, 6, 40, 20}, 6, {"belt", "elandor_goldmead_vale", 12, 40, 20})
		eq(r, "water_pocket", "F a column beside another zone's water: the border strip")
		r = attempt({"belt", D, 4, 10, 5}, 4, {nil})
		eq(r, "spawned_sea_shallows", "F land around a shallow column does not make it a pocket")
		r = attempt({"belt", D, 6, 40, 20}, 6, {"bay", D, 6, 40, 20})
		eq(r, "spawned_sea_deep", "F the zone's own bay water beside its belt is no pocket")
		r = attempt({"belt", "no_such_zone", 6, 40, 20}, 6, nil)
		eq(r, "no_recipe_zone", "F a zone without a recipe")
		-- A swimmer in water too shallow to dive stays at the surface.
		eq(SR.water_spot({x = 0, y = 1, z = 0}, "grug_mobs:stingray_t1", 2).y, 1,
			"F a swimmer in 2-deep water at the surface")
		eq(SR.water_spot({x = 0, y = 1, z = 0}, "grug_mobs:stingray_t1", 3).y, 0,
			"F ... one node down in 3-deep water")
		eq(SR.water_spot({x = 0, y = 1, z = 0}, "grug_mobs:frog_t1", 20).y, 1,
			"F an amphibian always at the surface")
	end
end

------------------------------------------------------------------------------
-- G. The world rows (shark.lua, goby.lua): in the merged water ABM (water
--    nodes, tops at or above y 0), and their bands as spawn checks.
------------------------------------------------------------------------------
for _, name in ipairs({"grug_mobs:bay_shark", "grug_mobs:abyssal_shark", "grug_mobs:goby"}) do
	local row = rows[name]
	if check(row ~= nil, "G " .. name .. " has a spawn row") then
		eq(row.nodes[1], "default:water_source", "G " .. name .. " spawns from water")
		check(row.max_height >= 0, "G " .. name .. " joins the water ABM (top at or above y 0)")
		if name ~= "grug_mobs:goby" then
			eq(row.neighbors[1], "air", "G " .. name .. " appears at the surface, as the Kraken")
		end
	end
end
eq(rows["grug_mobs:abyssal_shark"].chance, 10 * 12000,
	"G the Abyssal Shark is a rare spawn: a tenth of the Kraken's rate")
local bands = grug_mobs.shark_bands
local deep = {x = -5, y = -3, z = 0} -- water below and above (x <= 0, y <= 1)
local function answer(class, distance, depth) query.class, query.distance, query.depth = class, distance, depth end
answer("bay", 50, 30)
eq(bands.bay_middle(deep), true, "G Bay Shark: the deep middle of a bay")
answer("bay", 20, 30)
eq(bands.bay_middle(deep), false, "G ... not near the bay's shore")
answer("bay", 50, 10)
eq(bands.bay_middle(deep), false, "G ... not in shallow bay water")
answer("belt", 50, 30)
eq(bands.bay_middle(deep), false, "G ... not in the belt")
answer("open_sea", 400, 25)
eq(bands.open_sea(deep), true, "G Abyssal Shark: the open sea")
answer("belt", 100, 25)
eq(bands.open_sea(deep), false, "G ... never in the belt")
local goby_check = base_defs["grug_mobs:goby"]._grug_spawn_check
for _, c in ipairs({{"bay", true}, {"belt", true}, {"channel", true}, {"open_sea", true},
		{"lake", false}, {"river", false}}) do
	answer(c[1], 30, 10)
	eq(goby_check(deep), c[2], "G the Tide Goby in " .. c[1] .. " water")
end
answer("belt", 30, 10)
eq(goby_check({x = -5, y = 1, z = 0}), false, "G ... below the surface, never at it")

if failures > 0 then
	error(("R51 MOBS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R51 MOBS PORTABLE PASS checks=%d"):format(checks))
