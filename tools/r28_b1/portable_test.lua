-- Round 28 Lane B1 portable test (LuaJIT): spawn areas, rulings 3, 34, 37, 38.
--
--   luajit tools/r28_b1/portable_test.lua [REPO] [BASE_COMMIT]
--
-- 1. Fallback identity (ruling 34 trigger): the real spawn_policy.lua of
--    BASE_COMMIT (default 7af1aaf2, the palettes as Lua tables, read with
--    `git show`) and the current spawn_policy.lua + spawn_areas.lua (the
--    palettes as data/zones/*.spawns.json, every zone without areas) give the
--    same answer for every zone, every policy mob, several heights, biomes,
--    levels and both clocks: spawn_policy_allows, spawn_clock_for,
--    zone_density_cast, zone_clock_cast, zone_spawn_palette_allows and
--    density_zone_ids. Protected surfaces are kept out of this comparison
--    (ruling 3 is a deliberate change, part 2).
-- 2. Ruling 3 on ABM rows: road, bridge, village, start footprint and capital
--    city refuse ordinary natural rows; camps and POIs do not; critters and
--    NPC rows are never refused.
-- 3. The loader on the 38 shipped files: all zones, palettes present, no
--    areas, critter lists, format errors fail loudly.
-- 4. Areas on a synthetic world: anchors (anchor id, settlement key, slot,
--    start, capital, zone, offsets), shapes (circle, ring, band on both
--    continents, zone), clipping, clocks, hosts (biome, shore), overlap
--    union and pick weights, fallback, ABM refusal and critters in a zone
--    with areas, the ambient spawner end to end (area tag, fixed level,
--    protected refusal, density share and cap), the seams.
-- 5. Camps: ruling 37 timers, fires dormant in area zones, area camp slots
--    (first fill, respawn window, player distance, free roaming).
-- 6. Leaders: fixed spot and level, no area tag, not saved, ~300 s respawn
--    only after a kill.
-- 7. levels.lua: an area or leader level replaces the field.
-- 8. Cost: spawn_policy_allows before/after (stubbed world), one area attempt.
-- Prints "R28 B1 PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local base = arg[2] or "7af1aaf2"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local MOBS = repo .. "/mods/ENTITIES/grug_mobs"
local DATA = MOBS .. "/data/zones"

-- The world's 38 zone ids, from the mapgen's own source; a data file per id.
local WORLD_ZONES = {}
for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").zones) do
	WORLD_ZONES[#WORLD_ZONES + 1] = row.id
end
table.sort(WORLD_ZONES)
local function list_dir()
	local names = {}
	for _, id in ipairs(WORLD_ZONES) do
		local f = io.open(DATA .. "/" .. id .. ".spawns.json")
		if f then
			f:close()
			names[#names + 1] = id .. ".spawns.json"
		end
	end
	return names
end

local function load_into(env, path_or_text, label)
	local chunk, err
	if label then
		chunk, err = loadstring(path_or_text, label)
	else
		chunk, err = loadfile(path_or_text)
	end
	assert(chunk, err)
	setfenv(chunk, env)
	return chunk()
end

local function noop() end

-- ---------------------------------------------------------------------------
-- The shared stub environment
-- ---------------------------------------------------------------------------
-- `world` supplies the zone queries; every env gets its own grug_mobs.
local function new_env(world)
	local env = setmetatable({}, {__index = _G})
	env._G = env
	local globalsteps, mods_loaded, overrides = {}, {}, {}
	local storage_data = {}
	env.core = {
		get_modpath = function(name)
			if name == "grug_mapgen" then return repo .. "/mods/MAPGEN/grug_mapgen" end
			return MOBS
		end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function() return list_dir() end,
		parse_json = json.parse,
		register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
		register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
		register_lbm = noop,
		override_item = function(name, def) overrides[name] = def end,
		settings = {get = function() return nil end, get_bool = function() return nil end},
		get_timeofday = function() return world.time or 0.5 end,
		get_gametime = function() return world.now or 0 end,
		registered_entities = world.entities or {},
		registered_nodes = world.nodes or {},
		get_item_group = function(name, group)
			local def = (world.nodes or {})[name]
			return def and def.groups and def.groups[group] or 0
		end,
		find_nodes_in_area_under_air = function(minp, maxp)
			return world.ground_column and world.ground_column(minp, maxp) or {}
		end,
		find_nodes_in_area = function(minp, maxp, names)
			return world.water_in and world.water_in(minp, maxp) or {}
		end,
		get_node = function(pos) return {name = world.node_at and world.node_at(pos) or "air"} end,
		get_node_or_nil = function(pos) return {name = world.node_at and world.node_at(pos) or "air"} end,
		get_objects_inside_radius = function(pos, r)
			local out = {}
			for _, obj in ipairs(world.objects or {}) do
				local p = obj:get_pos()
				if p then
					local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
					if dx * dx + dy * dy + dz * dz <= r * r then out[#out + 1] = obj end
				end
			end
			return out
		end,
		get_connected_players = function() return world.players or {} end,
		get_natural_light = function(pos, tod)
			if world.natural then return world.natural(pos, tod) end
			return 15
		end,
		get_node_light = function(pos, tod)
			if world.light then return world.light(pos, tod) end
			if tod then return 15 end
			local t = tod or world.time or 0.5
			return (t >= 0.1875 and t <= 0.8125) and 15 or 0
		end,
		log = noop,
		pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
		get_meta = function(pos) return world.meta_at(pos) end,
		get_node_timer = function() return {start = noop, is_started = function() return true end} end,
		set_node = noop,
		get_mod_storage = function() return nil end,
	}
	env.grug_zones = world.zones
	env.grug_core = world.core
	env.mobs = {can_spawn = function(_, pos) return pos end}
	env.vector = {distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end, round = function(p) return p end}
	env.grug_mobs = {
		storage = {
			get_int = function(_, key) return storage_data[key] or 0 end,
			set_int = function(_, key, value) storage_data[key] = value end,
		},
		settle_mob_death = function(self) world.settled = (world.settled or 0) + 1 end,
	}
	env._steps, env._loaded, env._overrides = globalsteps, mods_loaded, overrides
	return env
end

-- Spawn roles registered identically into old and new policies.
local function role_defs(mob_names)
	local defs = {}
	local clocks = {"day", "night", "any"}
	for i, name in ipairs(mob_names) do
		local def = {clock = clocks[i % 3 + 1], type = (i % 7 == 0) and "animal" or "monster",
			passive = (i % 5 == 0), attack_players = (i % 4 == 0) and false or nil,
			_grug_min_level = (i % 6 == 0) and 10 or nil,
			_grug_tier = (i % 11 == 0) and "critter" or nil}
		if name == "grug_mobs:zombie" then
			def.clock = {settled = "night", war = "night", blight = "any"}
		elseif name == "grug_mobs:scorpion" then
			def.clock = {scorpion = "night", ["zone:kragmar_sunscar_flats"] = "any"}
		elseif name == "grug_mobs:viper" then
			def.clock = {viper = "night", ["zone:kragmar_kapok_cradle"] = "any"}
		elseif name == "grug_mobs:gull" or name == "grug_mobs:rabbit" then
			def._grug_tier, def.passive, def.clock = "critter", true, "day"
		elseif name == "grug_mobs:guard_accord" then
			def.type = "npc"
		end
		defs[name] = def
	end
	return defs
end

local function upvalue(fn, wanted)
	local i = 1
	while true do
		local name, value = debug.getupvalue(fn, i)
		if not name then return nil end
		if name == wanted then return value end
		i = i + 1
	end
end

local function sorted_keys(t)
	local out = {}
	for k in pairs(t) do out[#out + 1] = k end
	table.sort(out)
	return out
end

local function same_list(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

-- ---------------------------------------------------------------------------
-- 1. Fallback identity
-- ---------------------------------------------------------------------------
local zone_files = {}
for _, name in ipairs(list_dir()) do
	local id = name:match("^([%w_]+)%.spawns%.json$")
	if id then zone_files[#zone_files + 1] = id end
end
table.sort(zone_files)
check(#zone_files == 38, "38 zone files (" .. #zone_files .. ")")

local ZONE_X = {} -- zone id -> x stripe origin
for i, id in ipairs(zone_files) do ZONE_X[id] = i * 1000 end
local BIOMES = {"grug_blight", "grug_beach", "grug_meadows", "grug_pine_hills"}

local function stripe_world()
	local world = {time = 0.5, protected = {},
		anchors = {["elandor_highcourt/capital"] = {x = 0, y = 0, z = 0}}}
	world.zones = {
		id_at = function(x, z)
			local i = math.floor(x / 1000)
			return zone_files[i]
		end,
		biome_at = function(x, z) return BIOMES[math.abs(z) % 4 + 1] end,
		mob_level_at = function(pos)
			if math.abs(pos.z) % 9 == 8 then return nil end
			return 1 + math.abs(pos.z) % 60
		end,
		hard_protection_kind_at = function(pos) return world.protected.town and world.protected.town(pos) or nil end,
		anchor = function(zone, slot) return world.anchors and world.anchors[zone .. "/" .. slot] or nil end,
		get = function(zone) return {macro_region = "elandor_mainland", hub = {x = 0, z = 0}} end,
		pvp_rule_at = function() return "peaceful" end,
		race_region_at = function() return "human" end,
	}
	world.core = {
		start_identities = function()
			local out = {}
			for i = 1, 6 do out[i] = {anchor = {x = -100000 - i * 1000, y = 10, z = 0}} end
			if world.start then out[1] = {anchor = world.start} end
			return out
		end,
		world_feature_at = function(pos) return world.protected.feature and world.protected.feature(pos) or nil end,
		DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
		settlement_socket_anchor = function() return nil end,
	}
	return world
end

local old_world = stripe_world()
local new_world = stripe_world()
local old_env = new_env(old_world)
local new_env_ = new_env(new_world)
local base_text = io.popen("git -C '" .. repo .. "' show " .. base ..
	":mods/ENTITIES/grug_mobs/spawn_policy.lua"):read("*a")
check(#base_text > 10000, "baseline spawn_policy.lua read from " .. base)
load_into(old_env, base_text, "=base spawn_policy.lua")
load_into(new_env_, MOBS .. "/spawn_areas.lua")
load_into(new_env_, MOBS .. "/spawn_policy.lua")
local OLD, NEW = old_env.grug_mobs, new_env_.grug_mobs

local mob_set = {}
for name in pairs(upvalue(OLD.zone_density_cast, "MOB_PALETTES")) do mob_set[name] = true end
for name in pairs(upvalue(OLD.spawn_policy_allows, "UNDERGROUND_MOBS")) do mob_set[name] = true end
for _, name in ipairs({"grug_mobs:gull", "grug_mobs:shore_crab", "grug_mobs:reef_lurker",
		"grug_mobs:kraken", "grug_mobs:reed_angelfish", "grug_mobs:guard_accord",
		"grug_mobs:unknown_family"}) do mob_set[name] = true end
local mob_names = sorted_keys(mob_set)
local defs = role_defs(mob_names)
for _, name in ipairs(mob_names) do
	check(OLD.register_spawn_role(name, defs[name]) == NEW.register_spawn_role(name, defs[name]),
		"hostile role " .. name)
end
check(same_list(OLD.density_zone_ids(), NEW.density_zone_ids()), "density_zone_ids")

local compared = 0
for _, zone in ipairs(zone_files) do
	for _, clock in ipairs({"day", "night"}) do
		check(same_list(OLD.zone_density_cast(zone, clock), NEW.zone_density_cast(zone, clock)),
			"zone_density_cast " .. zone .. " " .. clock)
		local a, b = OLD.zone_clock_cast(zone, clock), NEW.zone_clock_cast(zone, clock)
		check((a == nil and b == nil) or (a and b and same_list(a, b)),
			"zone_clock_cast " .. zone .. " " .. clock)
	end
	local x0 = ZONE_X[zone]
	for _, time in ipairs({0.5, 0.0}) do
		old_world.time, new_world.time = time, time
		for _, y in ipairs({-60, -20, 3, 120}) do
			for dz = 0, 17 do
				local pos = {x = x0 + 5, y = y, z = 100 + dz}
				for _, name in ipairs(mob_names) do
					local a = OLD.spawn_policy_allows(name, pos)
					local b = NEW.spawn_policy_allows(name, pos)
					if a ~= b then
						error(("FAIL fallback identity %s %s y=%d z=%d t=%s: %s vs %s")
							:format(zone, name, y, pos.z, time, tostring(a), tostring(b)))
					end
					compared = compared + 1
					local ca, cb = OLD.spawn_clock_for(name, pos), NEW.spawn_clock_for(name, pos)
					if ca ~= cb then error("FAIL spawn_clock_for " .. zone .. " " .. name) end
				end
				for _, palette in ipairs({"settled", "war", "forest", "fox", "swamp"}) do
					check(OLD.zone_spawn_palette_allows(palette, pos) ==
						NEW.zone_spawn_palette_allows(palette, pos), "palette allows " .. zone)
				end
			end
		end
	end
end
checks = checks + compared
print(("fallback identity: %d spawn_policy_allows decisions identical over %d zones and %d mobs")
	:format(compared, #zone_files, #mob_names))

-- ---------------------------------------------------------------------------
-- 2. Ruling 3 on ABM rows
-- ---------------------------------------------------------------------------
do
	local dawn = "elandor_dawnmere_fields"
	local x0 = ZONE_X[dawn]
	new_world.time, old_world.time = 0.5, 0.5
	local boar, rabbit, guard = "grug_mobs:boar", "grug_mobs:rabbit", "grug_mobs:guard_accord"
	-- A day boar on a meadow at level 3 is allowed in Dawnmere (palette settled).
	local probe = {x = x0 + 5, y = 10, z = 102}
	defs[boar].clock = "day"
	check(NEW.spawn_policy_allows(boar, probe) == OLD.spawn_policy_allows(boar, probe), "probe agrees")
	local base_ok = NEW.spawn_policy_allows(boar, probe)
	check(base_ok == true, "boar allowed on open ground")
	-- The protection answer is memoised per position (the world features are
	-- static); every case below therefore asks at its own height.
	local y = probe.y
	for _, kind in ipairs({"road", "bridge", "village"}) do
		new_world.protected.feature = function(pos) return kind end
		y = y + 1
		check(NEW.spawn_policy_allows(boar, {x = probe.x, y = y, z = probe.z}) == false,
			"ruling 3 refuses on " .. kind)
		check(NEW.spawn_policy_allows(rabbit, {x = probe.x, y = y, z = probe.z}) ==
			OLD.spawn_policy_allows(rabbit, {x = probe.x, y = y, z = probe.z}),
			"critter unchanged on " .. kind)
		check(NEW.spawn_policy_allows(guard, {x = probe.x, y = y, z = probe.z}) ==
			OLD.spawn_policy_allows(guard, {x = probe.x, y = y, z = probe.z}),
			"npc row unchanged on " .. kind)
	end
	for _, kind in ipairs({"camp", "poi"}) do
		new_world.protected.feature = function(pos) return kind end
		y = y + 1
		check(NEW.spawn_policy_allows(boar, {x = probe.x, y = y, z = probe.z}) == true,
			"no refusal on " .. kind)
	end
	new_world.protected.feature = nil
	-- start footprint: a neutral row is refused there now (hostile rows were before)
	new_world.start = {x = probe.x, y = 10, z = probe.z}
	new_world.protected.town = function(pos) return pos.y >= -90 and "town" or nil end
	-- forget the compiled pads so the new start is read
	debug.setupvalue(NEW.in_start_footprint, (function()
		local i = 1
		while true do
			local n = debug.getupvalue(NEW.in_start_footprint, i)
			if n == "start_pads" then return i end
			i = i + 1
		end
	end)(), nil)
	check(NEW.spawn_policy_allows(boar, {x = probe.x + 1, y = 30, z = probe.z}) == false,
		"ruling 3: start footprint refuses the boar row")
	check(NEW.protected_spawn_surface({x = probe.x + 200, y = 10, z = probe.z}) == false,
		"outside the footprint is open")
	-- capital city, only asked in a capital zone
	new_world.start = nil
	local hx = ZONE_X.elandor_highcourt
	check(NEW.protected_spawn_surface({x = hx + 3, y = 10, z = 5}) == true, "capital city protected")
	check(NEW.protected_spawn_surface({x = x0 + 3, y = 10, z = 5}) == false,
		"no capital query outside capital zones")
	new_world.protected.town = nil
	check(NEW.protected_spawn_surface({x = hx + 3, y = 11, z = 5}) == false, "capital outskirts open")
end

-- ---------------------------------------------------------------------------
-- 3. The shipped files
-- ---------------------------------------------------------------------------
do
	local SA = NEW.spawn_areas
	check(#SA.zone_ids() == 38, "loader installed 38 zones")
	for _, zone in ipairs(SA.zone_ids()) do
		check(SA.zone_has_areas(zone) == false, "shipped " .. zone .. " has no areas")
		local text = io.open(DATA .. "/" .. zone .. ".spawns.json"):read("*a")
		local data = json.parse(text)
		check(type(data.palette) == "table" and type(data.palette.families) == "table",
			zone .. " carries its palette")
		check(type(data.critters) == "table" and #data.areas == 0 and #data.leaders == 0,
			zone .. " critters list, empty areas and leaders")
	end
	check(SA.zone_critter("elandor_dawnmere_fields", "grug_mobs:wild_turkey"), "dawnmere turkey critter")
	check(SA.zone_critter("elandor_dawnmere_fields", "grug_mobs:boar") == false, "boar is no critter")
	local palettes = upvalue(OLD.zone_density_cast, "ZONE_MOB_PALETTES")
	check(#sorted_keys(palettes) == 38, "baseline had 38 palettes")
end

-- ---------------------------------------------------------------------------
-- 4. Areas on a synthetic world
-- ---------------------------------------------------------------------------
-- Dawnmere z < -2000 (|x| < 1000), Goldmead -2000 <= z < -1000, Highcourt
-- -1000 <= z < -500, Broken Causeway |z| < 500, Sunscar z > 2000.
local W = {time = 0.5, now = 1000, objects = {}, players = {}, protected = {}}
local START = {x = 0, y = 36, z = -2550}
local SUNSCAR = {x = 0, y = 40, z = 2550}
local ZONE_REC = {
	elandor_dawnmere_fields = {macro_region = "elandor_mainland", hub = {x = 0, z = -2550}},
	elandor_goldmead_vale = {macro_region = "elandor_mainland", hub = {x = 0, z = -2050}},
	elandor_highcourt = {macro_region = "elandor_mainland", hub = {x = 0, z = -800}},
	front_broken_causeway = {macro_region = "holy_grounds", hub = {x = -750, z = 0}},
	kragmar_sunscar_flats = {macro_region = "kragmar_mainland", hub = {x = 0, z = 2550}},
}
local ANCHORS = {
	["elandor_dawnmere_fields/start"] = {x = 0, y = 36, z = -2550, id = "anchor_002"},
	["elandor_goldmead_vale/village_1"] = {x = -120, y = 37, z = -2020, id = "anchor_015"},
	["elandor_goldmead_vale/bandit_1"] = {x = 320, y = 30, z = -1980, id = "anchor_051"},
	["elandor_highcourt/capital"] = {x = 0, y = 50, z = -800, id = "anchor_008"},
	["kragmar_sunscar_flats/start"] = {x = 0, y = 40, z = 2550, id = "anchor_005"},
	["front_broken_causeway/clash_1"] = {x = -700, y = 20, z = 10, id = "anchor_078"},
}
local SETTLEMENTS = {
	dawnmere = {x = 0, y = 36, z = -2550},
	goldmead_bandit_camp = {x = 320, y = 30, z = -1980},
}
local GROUND_Y = 2
local function zone_at(x, z)
	if z > 2000 then return "kragmar_sunscar_flats" end
	if math.abs(x) >= 1000 then return nil end
	if z < -2000 then return "elandor_dawnmere_fields" end
	if z < -1000 then return "elandor_goldmead_vale" end
	if z < -500 then return "elandor_highcourt" end
	if z < 500 then return "front_broken_causeway" end
	return nil
end
local function biome_at(x, z)
	if z < -2800 then return "grug_beach" end
	if x < -400 then return "grug_swamp" end
	return "grug_meadows"
end
W.zones = {
	id_at = function(x, z) return zone_at(x, z) end,
	biome_at = function(x, z) return biome_at(x, z) end,
	get = function(zone) return ZONE_REC[zone] end,
	anchor = function(zone, slot) return ANCHORS[zone .. "/" .. slot] end,
	mob_level_at = function() return 5 end,
	terrain_height_at = function() return GROUND_Y end,
	hard_protection_kind_at = function(pos)
		-- start town pads (128 + band, approximated as a box) and the capital city
		if math.abs(pos.x - START.x) <= 76 and math.abs(pos.z - START.z) <= 76 and pos.y >= -64 then
			return "town"
		end
		if math.abs(pos.x) <= 60 and math.abs(pos.z + 800) <= 60 then return "town" end
		return nil
	end,
	pvp_rule_at = function() return "peaceful" end,
	race_region_at = function() return "human" end,
}
W.core = {
	start_identities = function()
		local out = {{anchor = START}, {anchor = SUNSCAR}}
		for i = 3, 6 do out[i] = {anchor = {x = 50000 + i * 1000, y = 10, z = 0}} end
		return out
	end,
	world_feature_at = function(pos)
		-- a north-south road along x = 300, 3 wide, and a village box
		if math.abs(pos.x - 300) <= 1 and pos.z < -2000 then return "road" end
		if math.abs(pos.x - 500) <= 8 and math.abs(pos.z + 2300) <= 8 then return "village" end
		return nil
	end,
	DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	settlement_socket_anchor = function(key) return SETTLEMENTS[key] end,
}
local SAND_FROM = -2800
W.node_at = function(pos)
	if pos.y <= GROUND_Y then return pos.z < SAND_FROM and "default:sand" or "default:dirt_with_grass" end
	return "air"
end
W.ground_column = function(minp, maxp)
	if GROUND_Y < minp.y or GROUND_Y > maxp.y then return {} end
	return {{x = minp.x, y = GROUND_Y, z = minp.z}}
end
-- sea water south of z = -2850
W.water_in = function(minp, maxp)
	if minp.z <= -2850 then return {{x = minp.x, y = 0, z = minp.z}} end
	return {}
end
W.nodes = {["default:dirt_with_grass"] = {walkable = true}, ["default:sand"] = {walkable = true},
	["air"] = {walkable = false}}
W.entities = {}
for _, role in ipairs({"boar", "giant_rat", "shore_crab", "fox", "wolf", "zombie", "bandit",
		"bandit_archer", "bog_ooze", "bear", "rabbit", "wild_turkey", "gull"}) do
	W.entities["grug_mobs:" .. role] = {_grug_disposition =
		(role == "rabbit" or role == "wild_turkey" or role == "gull") and "critter" or "neutral"}
end

local AE = new_env(W)
-- No data files: this world installs its zones itself.
AE.core.get_dir_list = function() return {} end
-- Fake mobs: add_mob creates an entity at pos with an object.
local function new_object(ent, pos)
	local obj = {props = {}}
	obj._pos = {x = pos.x, y = pos.y, z = pos.z}
	function obj:get_pos() return self._removed and nil or self._pos end
	function obj:get_luaentity() return not self._removed and ent or nil end
	function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function obj:get_properties() return self.props end
	return obj
end
local spawned = {}
AE.grug_mobs.add_mob = function(pos, def)
	if W.refuse_add then return nil end
	local ent = {name = def.name, health = 10}
	-- a family with a composed look levels from the field during activation
	if W.prelevel then ent._grug_level = 33 end
	ent.object = new_object(ent, pos)
	W.objects[#W.objects + 1] = ent.object
	spawned[#spawned + 1] = ent
	return ent
end
load_into(AE, MOBS .. "/spawn_areas.lua")
load_into(AE, MOBS .. "/spawn_policy.lua")
load_into(AE, MOBS .. "/density.lua")
load_into(AE, MOBS .. "/camps.lua")
local G = AE.grug_mobs
local SA = G.spawn_areas
local relevels = 0
G.relevel = function(ent, level)
	ent._grug_spawn_level = level
	if ent._grug_level and ent._grug_level ~= level then
		ent._grug_level = level
		relevels = relevels + 1
	end
end
for _, name in ipairs({"grug_mobs:boar", "grug_mobs:fox", "grug_mobs:zombie", "grug_mobs:rabbit",
		"grug_mobs:shore_crab", "grug_mobs:gull", "grug_mobs:bandit", "grug_mobs:giant_rat",
		"grug_mobs:wolf", "grug_mobs:bog_ooze", "grug_mobs:bear"}) do
	G.register_spawn_role(name, {clock = "day", type = "monster",
		_grug_tier = (name == "grug_mobs:rabbit" or name == "grug_mobs:gull") and "critter" or nil})
end

local function area(t)
	t.hosts = t.hosts or {biomes = {"any"}}
	t.clock = t.clock or "both"
	t.levels = t.levels or {1, 3}
	return t
end
local DAWN = "elandor_dawnmere_fields"
local dawn_data = {
	zone = DAWN,
	palette = {families = {"settled"}, boar = "grug_mobs:boar"},
	critters = {"rabbit"},
	areas = {
		area{id = "home_day", anchor = "start", shape = {kind = "band", forward = {-400, 0}, side = {-250, 250}},
			clock = "day", levels = {1, 3}, species = {{role = "boar", weight = 3}}},
		area{id = "home_night", anchor = "anchor_002", shape = {kind = "band", forward = {-400, 0}, side = {-250, 250}},
			clock = "night", levels = {1, 3}, species = {{role = "giant_rat", weight = 1}}},
		area{id = "beach", anchor = "dawnmere", offset = {0, -300}, shape = {kind = "circle", r = 100},
			hosts = {biomes = {"any"}, shore = true}, clock = "day", levels = {3, 5},
			species = {{role = "shore_crab", weight = 1}}, cap = 2},
		area{id = "fox_a", anchor = "start", offset = {200, 100}, shape = {kind = "circle", r = 80},
			clock = "day", levels = {5, 7}, species = {{role = "fox", weight = 1}}},
		area{id = "fox_b", anchor = "start", offset = {260, 100}, shape = {kind = "circle", r = 80},
			clock = "day", levels = {6, 7}, species = {{role = "fox", weight = 1}, {role = "wolf", weight = 2}}},
		area{id = "ring_night", anchor = "start", shape = {kind = "ring", r = {150, 200}},
			clock = "night", levels = {3, 5}, species = {{role = "zombie", weight = 1}}},
		area{id = "swamp_oozes", anchor = "zone", offset = {-500, 0}, shape = {kind = "circle", r = 150},
			hosts = {biomes = {"swamp"}}, levels = {4, 6}, species = {{role = "bog_ooze", weight = 1}}},
		area{id = "border_bandits", anchor = "start", offset = {-160, 400}, shape = {kind = "circle", r = 38},
			levels = {9, 10}, species = {{role = "bandit", weight = 1}},
			camp = {slots = 4, respawn = {30, 60}, min_player_distance = 16}},
		area{id = "fallback", anchor = "zone", shape = {kind = "zone"}, levels = {3, 6},
			species = {{role = "boar", weight = 1}}, fallback = true},
	},
	leaders = {
		{role = "bear", anchor = "start", offset = {-160, 400}, level = 10, respawn = 300},
	},
}
SA.install_zone(DAWN, dawn_data)
for _, fn in ipairs(AE._loaded) do fn() end -- role checks pass for the sample
check(SA.zone_has_areas(DAWN), "sample zone has areas")
check(not SA.zone_has_areas("elandor_goldmead_vale"), "uninstalled zone has none")

local function pt(x, z, node)
	return SA.point(x, GROUND_Y, z, node or W.node_at({x = x, y = GROUND_Y, z = z}))
end
local out = {}
local function match_ids(x, z, clock)
	local n = SA.areas_at(DAWN, pt(x, z), clock, out)
	local ids = {}
	for i = 1, n do ids[#ids + 1] = out[i].id end
	table.sort(ids)
	return table.concat(ids, ",")
end

-- anchors and offsets
local a = SA.get_area(DAWN, "home_day")
check(a.cx == 0 and a.cz == -2550 and a.tag == DAWN .. "/home_day", "start anchor")
check(SA.get_area(DAWN, "home_night").cx == 0 and SA.get_area(DAWN, "home_night").cz == -2550,
	"anchor id anchor_002 resolves through its slot")
check(SA.get_area(DAWN, "beach").cz == -2850, "settlement key + offset")
check(SA.get_area(DAWN, "swamp_oozes").cx == -500 and SA.get_area(DAWN, "swamp_oozes").cz == -2550,
	"zone hub + offset")
check(SA.get_area(DAWN, "fox_b").levels[1] == 6 and SA.get_area(DAWN, "fox_b").species[2].role == "wolf",
	"seam fields levels/species")
local roles = SA.area_roles(DAWN, "fox_b")
check(roles.fox and roles.wolf and not roles.boar, "area_roles")
check(SA.get_area(DAWN, "nope") == nil and SA.area_roles(DAWN, "nope") == nil, "unknown area")
-- other anchor forms in other zones
local function try_install(zone, areas, leaders)
	return pcall(SA.install_zone, zone, {zone = zone, palette = {families = {}}, critters = {},
		areas = areas, leaders = leaders or {}})
end
local ok, err = try_install("elandor_goldmead_vale", {
	area{id = "v", anchor = "village_1", shape = {kind = "circle", r = 30}, species = {{role = "boar", weight = 1}}},
	area{id = "b", anchor = "anchor_051", shape = {kind = "circle", r = 30}, species = {{role = "boar", weight = 1}}},
	area{id = "k", anchor = "goldmead_bandit_camp", offset = {10, -5}, shape = {kind = "circle", r = 30},
		species = {{role = "boar", weight = 1}}},
	area{id = "f", anchor = "zone", shape = {kind = "zone"}, species = {{role = "boar", weight = 1}}, fallback = true},
})
check(ok, "goldmead anchors: " .. tostring(err))
check(SA.get_area("elandor_goldmead_vale", "v").cx == -120, "slot village_1")
check(SA.get_area("elandor_goldmead_vale", "b").cx == 320 and SA.get_area("elandor_goldmead_vale", "b").cz == -1980,
	"anchor id anchor_051 (bandit_1)")
check(SA.get_area("elandor_goldmead_vale", "k").cx == 330 and SA.get_area("elandor_goldmead_vale", "k").cz == -1985,
	"settlement key goldmead_bandit_camp + offset")
ok = try_install("elandor_highcourt", {
	area{id = "c", anchor = "capital", shape = {kind = "ring", r = {80, 300}}, species = {{role = "boar", weight = 1}}},
	area{id = "f", anchor = "zone", shape = {kind = "zone"}, species = {{role = "boar", weight = 1}}, fallback = true},
})
check(ok, "capital anchor")
check(SA.get_area("elandor_highcourt", "c").cz == -800, "capital resolves")
-- format errors fail loudly
local bad = {
	{"anchor of another zone", {area{id = "x", anchor = "anchor_015", shape = {kind = "zone"},
		species = {{role = "boar", weight = 1}}, fallback = true}}},
	{"unknown anchor", {area{id = "x", anchor = "nowhere", shape = {kind = "zone"},
		species = {{role = "boar", weight = 1}}, fallback = true}}},
	{"no fallback", {area{id = "x", anchor = "start", shape = {kind = "circle", r = 5},
		species = {{role = "boar", weight = 1}}}}},
	{"two fallbacks", {area{id = "x", anchor = "start", shape = {kind = "zone"}, species = {{role = "boar", weight = 1}}, fallback = true},
		area{id = "y", anchor = "start", shape = {kind = "zone"}, species = {{role = "boar", weight = 1}}, fallback = true}}},
	{"bad clock", {area{id = "x", anchor = "start", shape = {kind = "zone"}, clock = "dusk",
		species = {{role = "boar", weight = 1}}, fallback = true}}},
	{"bad levels", {area{id = "x", anchor = "start", shape = {kind = "zone"}, levels = {5, 2},
		species = {{role = "boar", weight = 1}}, fallback = true}}},
	{"bad weight", {area{id = "x", anchor = "start", shape = {kind = "zone"},
		species = {{role = "boar", weight = 0}}, fallback = true}}},
	{"unknown key", {area{id = "x", anchor = "start", shape = {kind = "zone"}, radius = 3,
		species = {{role = "boar", weight = 1}}, fallback = true}}},
	{"bad camp", {area{id = "x", anchor = "start", shape = {kind = "circle", r = 30},
		species = {{role = "boar", weight = 1}}, camp = {slots = 0}},
		area{id = "f", anchor = "start", shape = {kind = "zone"}, species = {{role = "boar", weight = 1}}, fallback = true}}},
}
-- Installed into Sunscar (its own start anchor; anchor_015 is Goldmead's).
for _, case in ipairs(bad) do
	local okb = pcall(SA.install_zone, "kragmar_sunscar_flats", {zone = "kragmar_sunscar_flats",
		areas = case[2]})
	check(not okb, "loader refuses: " .. case[1])
end
check(not pcall(SA.install_zone, "front_broken_causeway", {zone = "front_broken_causeway", areas = {
	area{id = "b", anchor = "clash_1", shape = {kind = "band", forward = {0, 10}, side = {-5, 5}},
		species = {{role = "boar", weight = 1}}},
	area{id = "f", anchor = "zone", shape = {kind = "zone"}, species = {{role = "boar", weight = 1}}, fallback = true}}}),
	"no band in a front zone")
check(not pcall(SA.install_zone, DAWN, {zone = "elandor_goldmead_vale", areas = {}}), "zone mismatch")
check(not pcall(SA.install_zone, "kragmar_sunscar_flats", {zone = "kragmar_sunscar_flats", areas = {}}),
	"a zone without areas needs its palette")
-- The failed installs above must not have touched Dawnmere
check(SA.get_area(DAWN, "home_day") ~= nil, "failed installs leave other zones intact")
-- ... nor a zone's own previous data: a broken re-install of Dawnmere
check(not pcall(SA.install_zone, DAWN, {zone = DAWN, areas = {
	area{id = "x", anchor = "start", shape = {kind = "circle", r = 5}, species = {{role = "boar", weight = 1}}}}}),
	"broken re-install refused")
check(SA.get_area(DAWN, "border_bandits") and SA.area_by_tag(DAWN .. "/border_bandits") and
	SA.leader("bear") and #SA.camp_areas() == 1, "a refused re-install keeps the zone's data")
-- a leader role can have one spot only
check(not pcall(SA.install_zone, "kragmar_sunscar_flats", {zone = "kragmar_sunscar_flats", areas = {},
	leaders = {{role = "bear", anchor = "start", level = 5, respawn = 300}}}), "leader role unique")

-- band on Kragmar: forward = -z
ok, err = pcall(SA.install_zone, "kragmar_sunscar_flats", {zone = "kragmar_sunscar_flats", areas = {
	area{id = "toward_front", anchor = "start", shape = {kind = "band", forward = {0, 300}, side = {-50, 50}},
		species = {{role = "boar", weight = 1}}},
	area{id = "f", anchor = "zone", shape = {kind = "zone"}, species = {{role = "zombie", weight = 1}}, fallback = true},
}})
check(ok, "sunscar band, areas without a palette: " .. tostring(err))
local tf = SA.get_area("kragmar_sunscar_flats", "toward_front")
check(SA.in_shape(tf, 10, 2550 - 200) and not SA.in_shape(tf, 10, 2550 + 200), "kragmar band runs toward -z")
check(not SA.in_shape(tf, 60, 2400), "band side limit")

-- shapes on Dawnmere
local home = SA.get_area(DAWN, "home_day")
check(SA.in_shape(home, 0, -2700) and SA.in_shape(home, 250, -2950) and not SA.in_shape(home, 0, -2500),
	"elandor band behind the town (toward -z)")
check(not SA.in_shape(home, 251, -2700) and not SA.in_shape(home, 0, -2951), "band limits")
local ring = SA.get_area(DAWN, "ring_night")
check(SA.in_shape(ring, 0, -2550 + 175) and not SA.in_shape(ring, 0, -2550 + 100) and
	not SA.in_shape(ring, 0, -2550 + 210), "ring")
check(SA.in_shape(SA.get_area(DAWN, "fox_a"), 200 + 80, -2450) and
	not SA.in_shape(SA.get_area(DAWN, "fox_a"), 200 + 81, -2450), "circle edge")

-- clocks, overlap union, fallback, hosts
check(match_ids(0, -2800, "day") == "home_day", "day home field")
check(match_ids(0, -2800, "night") == "home_night", "night home field")
check(match_ids(0, -2700, "night") == "home_night,ring_night", "night overlap of band and ring")
check(match_ids(230, -2450, "day") == "fox_a,fox_b", "overlap returns both")
check(match_ids(230, -2450, "night") == "fallback", "no night area there: fallback")
check(match_ids(0, -2550 + 175, "night") == "ring_night", "ring at night")
check(match_ids(0, -2550 + 175, "day") == "fallback", "ring is night only")
check(match_ids(-500, -2550, "day") == "swamp_oozes", "swamp biome host")
check(match_ids(-200, -2550 + 600, "day") == "fallback", "meadow inside no area -> fallback")
check(match_ids(-280, -2550 + 140, "day") == "fallback", "outside the swamp circle")
-- the swamp circle on non-swamp ground does not match, so the fallback answers there
check(match_ids(-450, -2550, "day") == "swamp_oozes" and match_ids(-380, -2550, "day") == "fallback",
	"biome host decides inside the circle")
-- shore: sand near water inside the beach circle
check(match_ids(0, -2852, "day") == "beach,home_day", "shore sand near water + home band")
check(match_ids(0, -2805, "day") == "home_day", "sand too far from water is no shore")
check(match_ids(0, -2795, "day") == "home_day", "grass is no shore")
-- camp ground keeps the fallback away but is not an ambient pick
check(match_ids(-160, -2150, "day") == "", "camp area covers its ground, no ambient pick")
-- pick: union weights fox 2, wolf 2 at the overlap
local n = SA.areas_at(DAWN, pt(230, -2450), "day", out)
local tally = {}
for i = 0, 3999 do
	local ar, role, rw, total = SA.pick(out, n, (i + 0.5) / 4000)
	tally[role] = (tally[role] or 0) + 1
	check(total == 4, "pick total weight")
	check((role == "fox" and rw == 2) or (role == "wolf" and rw == 2), "role weight is the union")
	check(ar.roles[role] ~= nil, "picked area lists the role")
end
check(tally.fox == 2000 and tally.wolf == 2000, "pick follows the union weights")
for i = 1, 200 do
	local lvl = SA.roll_level(SA.get_area(DAWN, "fox_b"))
	check(lvl >= 6 and lvl <= 7, "level in the area range")
end

-- the ABM rows in a zone with areas
W.time = 0.5
local open_ground = {x = -200, y = GROUND_Y, z = -1950 - 650}
check(G.spawn_policy_allows("grug_mobs:boar", open_ground) == false, "ABM boar refused in an area zone")
check(G.spawn_policy_allows("grug_mobs:shore_crab", {x = 0, y = GROUND_Y, z = -2852}) == false,
	"ABM crab refused in an area zone")
check(G.spawn_policy_allows("grug_mobs:rabbit", open_ground) == true, "listed critter keeps its row")
check(G.spawn_policy_allows("grug_mobs:gull", open_ground) == false, "unlisted critter refused")
check(G.spawn_policy_allows("grug_mobs:zombie", {x = -200, y = -60, z = -2600}) == true and
	G.spawn_policy_allows("grug_mobs:bandit", {x = -200, y = -60, z = -2600}) == false,
	"underground keeps its closed list")

-- ---------------------------------------------------------------------------
-- The ambient spawner end to end
-- ---------------------------------------------------------------------------
local function player_at(x, y, z)
	local p = {pos = {x = x, y = y, z = z}}
	function p:get_pos() return self.pos end
	return p
end
local function clear_world()
	for _, obj in ipairs(W.objects) do obj._removed = true end
	W.objects = {}
	spawned = {}
end
local P = player_at(0, GROUND_Y + 1, -2750)
W.players = {P}
-- force a column: angle 0 = +x, dist roll 0 = 24 nodes
local outcome = SA.attempt(P.pos, W.players, "day", 0, 0)
check(outcome == "spawned", "home field spawn: " .. outcome)
local ent = spawned[1]
check(ent.name == "grug_mobs:boar" and ent._grug_area == DAWN .. "/home_day", "boar with its area tag")
check(ent._grug_spawn_level >= 1 and ent._grug_spawn_level <= 3, "level from the area")
check(ent.object:get_pos().x == 24 and ent.object:get_pos().y == GROUND_Y + 1, "stands on the ground")
-- a mob that levelled during activation is re-levelled to the area
W.prelevel = true
check(SA.attempt(P.pos, W.players, "day", 0, 0) == "spawned", "prelevelled spawn")
local pre = spawned[#spawned]
check(pre._grug_level == pre._grug_spawn_level and pre._grug_level <= 3 and relevels == 1,
	"activation-time level replaced by the area level")
W.prelevel = nil
pre.object._removed = true
-- night picks the rat
W.time = 0.0
check(SA.attempt(P.pos, W.players, "night", 0, 0) == "spawned" and
	spawned[#spawned].name == "grug_mobs:giant_rat", "night rat")
W.time = 0.5
-- light (today's ABM behaviour): natural noon light >= 10, day >= 10,
-- hostile at night <= 5
G.spawn_role_hostile = function(name) return name ~= "grug_mobs:boar" end
W.natural, W.light = function() return 0 end, function() return 0 end
check(SA.attempt(P.pos, W.players, "day", 0, 0) == "light", "cave floor refused")
W.natural, W.light = function() return 2 end, function() return 14 end
check(SA.attempt(P.pos, W.players, "day", 0, 0) == "light", "roofed room under a lamp refused")
W.natural, W.light = function() return 12 end, function() return 12 end
check(SA.attempt(P.pos, W.players, "day", 0, 0) == "spawned", "ground under a leaf canopy spawns")
spawned[#spawned].object._removed = true
W.natural = nil
W.light = function(pos, tod) if tod then return 15 end return 8 end
check(SA.attempt(P.pos, W.players, "day", 0, 0) == "light", "day area below light 10")
W.light = function(pos, tod) if tod then return 15 end return 9 end
check(SA.attempt(P.pos, W.players, "night", 0, 0) == "light", "torch-lit ground refuses a hostile at night")
W.light = function(pos, tod) if tod then return 15 end return 4 end
check(SA.attempt(P.pos, W.players, "night", 0, 0) == "spawned", "dark open ground at night")
W.light = nil
spawned[#spawned].object._removed = true
-- the road at x = 300 refuses (ruling 3), critters would not be refused
local PR = player_at(276, GROUND_Y + 1, -2750)
check(SA.attempt(PR.pos, {PR}, "day", 0, 0) == "protected", "road refuses an area spawn")
-- the start town footprint
local PT = player_at(-30, GROUND_Y + 1, -2600)
check(SA.attempt(PT.pos, {PT}, "day", 0, 0) == "protected", "start town refuses an area spawn")
-- another player close by
local P2 = player_at(30, GROUND_Y + 1, -2750)
check(SA.attempt(P.pos, {P, P2}, "day", 0, 0) == "player_near", "keeps 24 from every player")
-- clipping: a column in Goldmead (no areas installed there now) is not served
SA.install_zone("elandor_goldmead_vale", {zone = "elandor_goldmead_vale", palette = {families = {}}, areas = {}})
local PB = player_at(0, GROUND_Y + 1, -2010)
check(SA.attempt(PB.pos, {PB}, "day", 0.25, 0) == "no_area_zone", "clipped at the zone border")
check(SA.attempt(PB.pos, {PB}, "day", 0.75, 0) == "spawned", "same player, a Dawnmere column")
-- no ground (water, unloaded)
local saved = W.ground_column
W.ground_column = function() return {} end
check(SA.attempt(P.pos, W.players, "day", 0, 0) == "no_ground", "no ground, no spawn")
W.ground_column = saved

-- density: share and refill over the eligible species at the point
clear_world()
W.time = 0.5
local budget = G.density_budget(DAWN, "day")
check(budget == 15, "day budget 15")
check(G.area_density_decision(0, 0, 0, 15, 15, nil) == true, "empty point spawns")
check(G.area_density_decision(14, 14, 0, 15, 15, nil) == true, "below budget and share")
check(G.area_density_decision(15, 14, 0, 15, 15, nil) == false, "budget full")
check(G.area_density_decision(20, 3, 0, 15, 8, nil) == true, "below share/1.5 always refills")
check(G.area_density_decision(20, 6, 0, 15, 8, nil) == false, "above floor needs room in the budget")
check(G.area_density_decision(0, 8, 0, 15, 8, nil) == false, "never above the share")
check(G.area_density_decision(0, 0, 2, 15, 8, 2) == false, "area cap")
-- fill the overlap point: fox and wolf share 15 by weight 2:2 -> 8 each
local PF = player_at(230 - 24, GROUND_Y + 1, -2450)
local counts = {}
for i = 1, 400 do
	SA.attempt(PF.pos, {PF}, "day", 0, 0)
end
for _, e in ipairs(spawned) do counts[e.name] = (counts[e.name] or 0) + 1 end
-- shares round(15 x 2/4) = 8 each, the point holds the budget of 15
local fox_n, wolf_n = counts["grug_mobs:fox"] or 0, counts["grug_mobs:wolf"] or 0
check(fox_n + wolf_n == 15 and fox_n <= 8 and wolf_n <= 8 and fox_n >= 6 and wolf_n >= 6,
	("union shares fill the budget (fox %d wolf %d)"):format(fox_n, wolf_n))
-- kill every fox: foxes refill, wolves do not grow
for _, e in ipairs(spawned) do
	if e.name == "grug_mobs:fox" then e.object._removed = true; e.health = 0 end
end
local before_wolves = counts["grug_mobs:wolf"]
for i = 1, 400 do SA.attempt(PF.pos, {PF}, "day", 0, 0) end
counts = {}
for _, e in ipairs(spawned) do
	if not e.object._removed then counts[e.name] = (counts[e.name] or 0) + 1 end
end
check((counts["grug_mobs:fox"] or 0) >= 7 and counts["grug_mobs:wolf"] <= 8 and
	counts["grug_mobs:wolf"] >= before_wolves and
	counts["grug_mobs:fox"] + counts["grug_mobs:wolf"] == 15,
	"species-aware refill: foxes come back, wolves never pass their share")
-- crabs: cap 2 on the beach
clear_world()
local PC = player_at(-24, GROUND_Y + 1, -2852)
for i = 1, 200 do SA.attempt(PC.pos, {PC}, "day", 0, 0) end
local crabs = 0
for _, e in ipairs(spawned) do
	if e.name == "grug_mobs:shore_crab" then
		crabs = crabs + 1
		check(e._grug_area == DAWN .. "/beach" and e._grug_spawn_level >= 3 and e._grug_spawn_level <= 5,
			"crab tag and level")
	end
end
check(crabs == 2, "area cap 2 holds (" .. crabs .. ")")
check(SA.stats.density and SA.stats.density > 0, "density refusals counted")

-- ---------------------------------------------------------------------------
-- 5. Camps
-- ---------------------------------------------------------------------------
check(G.registered_camp_types.bandit.respawn_min == 30 and G.registered_camp_types.bandit.respawn_max == 60,
	"ruling 37: bandit camps 30-60 s")
check(G.registered_camp_types.mirefolk.respawn_min == 30 and G.registered_camp_types.mirefolk.respawn_max == 60,
	"ruling 37: mirefolk camps 30-60 s")
check(G.registered_camp_types.guard_accord.respawn_min == 180, "guard posts unchanged")
-- a fire in a zone with areas stays scenery
local metas = {}
W.meta_at = function(pos)
	local key = pos.x .. "," .. pos.z
	metas[key] = metas[key] or {s = {}, i = {}}
	local m = metas[key]
	return {
		get_string = function(_, k) return m.s[k] or "" end,
		set_string = function(_, k, v) m.s[k] = v end,
		get_int = function(_, k) return m.i[k] or 0 end,
		set_int = function(_, k, v) m.i[k] = v end,
	}
end
local fire = AE._overrides["grug_nodes:camp_fire"]
clear_world()
W.players = {player_at(5, GROUND_Y + 1, -2600)}
fire.on_timer({x = 0, y = GROUND_Y + 1, z = -2600}, 30)
check(metas["0,-2600"].i._grug_camp_target == nil, "fire in an area zone rolls nothing")
check(#spawned == 0, "fire in an area zone spawns nothing")
W.players = {player_at(5, GROUND_Y + 1, -1600)}
SA.install_zone("elandor_goldmead_vale", {zone = "elandor_goldmead_vale", palette = {families = {}}, areas = {}})
fire.on_timer({x = 0, y = GROUND_Y + 1, z = -1600}, 30)
check((metas["0,-1600"].i._grug_camp_target or 0) >= 3, "fire in a fallback zone keeps working")
-- area camp slots
clear_world()
local camp = SA.get_area(DAWN, "border_bandits")
local PCAMP = player_at(-160 + 60, GROUND_Y + 1, -2150)
W.now = 5000
G.area_camp_tick(W.now, {player_at(-160 + 75, GROUND_Y + 1, -2150)}, "day")
check(#spawned == 0, "first fill waits for a player within 64 nodes")
G.area_camp_tick(W.now, {PCAMP}, "day")
local members = 0
for _, e in ipairs(spawned) do
	if e._grug_area == camp.tag then
		members = members + 1
		check(e.name == "grug_mobs:bandit" and e._grug_spawn_level >= 9 and e._grug_spawn_level <= 10,
			"camp member role and level")
		check(e._grug_camp_pos == nil and e._grug_home == nil, "free roaming: no camp anchor")
		local p = e.object:get_pos()
		local dx, dz = p.x + 160, p.z + 2150
		check(dx * dx + dz * dz <= 38 * 38 + 1, "inside the camp circle")
		local qx, qz = p.x - PCAMP.pos.x, p.z - PCAMP.pos.z
		check(qx * qx + qz * qz >= 16 * 16, "min_player_distance 16")
	end
end
check(members == 4, "first look fills all four slots (" .. members .. ")")
-- kill two: refill after 30-60 s, one per roll
spawned[1].object._removed = true
spawned[2].object._removed = true
local before = #spawned
G.area_camp_tick(W.now + 5, {PCAMP}, "day")
check(#spawned == before, "no instant refill after a death")
G.area_camp_tick(W.now + 29, {PCAMP}, "day")
check(#spawned == before, "not before 30 s")
G.area_camp_tick(W.now + 5 + 60, {PCAMP}, "day")
check(#spawned == before + 1, "first slot back within 60 s")
G.area_camp_tick(W.now + 5 + 125, {PCAMP}, "day")
check(#spawned == before + 2, "second slot after another 30-60 s")
-- nobody near: no work
local far = player_at(500, GROUND_Y + 1, -2900)
spawned[3].object._removed = true
local n_before = #spawned
G.area_camp_tick(W.now + 1000, {far}, "day")
check(#spawned == n_before, "no player near: nothing happens")
-- camp members do not count against the ambient budget
check(SA.area_by_tag(camp.tag).camp ~= nil, "camp tag lookup")

-- ---------------------------------------------------------------------------
-- 6. Leaders
-- ---------------------------------------------------------------------------
clear_world()
local L = SA.leader("bear")
check(L and L.zone == DAWN and L.pos.x == -160 and L.pos.z == -2150 and L.level == 10 and L.respawn == 300,
	"leader seam")
check(SA.leader("boar") == nil, "no leader for a plain role")
local PL = player_at(-100, GROUND_Y + 1, -2150)
W.now = 10000
SA.leader_tick(W.now, {player_at(-150, GROUND_Y + 1, -2150)})
check(#spawned == 0, "no leader appears within 24 nodes of a player")
SA.leader_tick(W.now, {PL})
check(#spawned == 1, "leader spawned")
local leader = spawned[1]
check(leader.name == "grug_mobs:bear" and leader._grug_leader == true and leader._grug_area == nil,
	"leader flag, no area")
check(leader._grug_spawn_level == 10, "leader fixed level")
check(leader.object.props.static_save == false, "leader is never saved with the map")
local lp = leader.object:get_pos()
check(lp.x == -160 and lp.z == -2150 and lp.y == GROUND_Y + 1, "snapped onto the surface")
SA.leader_tick(W.now + 5, {PL})
check(#spawned == 1, "alive: no second leader")
-- unloaded (removed without a kill): back on the next visit
leader.object._removed = true
SA.leader_tick(W.now + 10, {PL})
check(#spawned == 2, "a leader lost with its block returns at once")
leader = spawned[2]
-- killed: ~300 s
W.now = 20000
leader.health = 0
G.settle_mob_death(leader)
leader.object._removed = true
check(W.settled == 1, "the death boundary still runs")
SA.leader_tick(W.now + 100, {PL})
check(#spawned == 2, "no respawn before the timer")
SA.leader_tick(W.now + 301, {PL})
check(#spawned == 3, "respawn after 300 s")
SA.leader_tick(W.now + 400, {player_at(500, GROUND_Y + 1, -2900)})
check(#spawned == 3, "a leader needs a player near its spot")

-- ---------------------------------------------------------------------------
-- 7. levels.lua honours the area level
-- ---------------------------------------------------------------------------
do
	local LW = {time = 0.5, zones = {mob_level_at = function() return 42 end},
		core = setmetatable({}, {__index = function() return function() return "" end end})}
	local LE = new_env(LW)
	LE.grug_xp = {mob_xp = function(level) return 25 + 5 * level end, LEVEL_OFFSET = 5}
	LE.mobs = {scale_mob = noop}
	LE.math = setmetatable({round = function(x) return math.floor(x + 0.5) end}, {__index = math})
	load_into(LE, MOBS .. "/levels.lua")
	local LG = LE.grug_mobs
	LG.ensure_tag_carrier = noop
	LG.register_level_cfg("grug_mobs:boar", {})
	local function fake(level)
		local self = {name = "grug_mobs:boar", _grug_spawn_level = level}
		self.object = new_object(self, {x = 0, y = 0, z = 0})
		function self.object:set_armor_groups() end
		return self
	end
	local plain = fake(nil)
	LG.ensure_init(plain)
	check(plain._grug_level == 42, "no area level: the field decides")
	local tagged = fake(7)
	LG.ensure_init(tagged)
	check(tagged._grug_level == 7, "area level replaces the field")
	-- An authored sub-type of a family with a composed look (a bandit role):
	-- it levels during activation from the field (42), set_tier refuses
	-- authored tiers, relevel still hands it the area level with its stats.
	LG.register_level_cfg("grug_mobs:confused_bandit", {_grug_authored_tier = true})
	local bandit = {name = "grug_mobs:confused_bandit"}
	bandit.object = new_object(bandit, {x = 0, y = 0, z = 0})
	function bandit.object:set_armor_groups() end
	LG.ensure_init(bandit)
	check(bandit._grug_level == 42, "activation-time level from the field")
	LG.set_tier(bandit, "normal")
	local hp42 = bandit.hp_max
	LG.relevel(bandit, 9)
	check(bandit._grug_level == 9 and bandit._grug_spawn_level == 9, "relevel sets the area level")
	local hp9 = LG.stats_for(9, bandit._grug_tier)
	check(bandit.hp_max == hp9 and hp9 < hp42 and bandit.health <= hp9, "relevel re-derives the stats")
	LG.ensure_init(bandit)
	check(bandit._grug_level == 9, "the next tick keeps it")
	local fresh = {name = "grug_mobs:confused_bandit"}
	fresh.object = new_object(fresh, {x = 0, y = 0, z = 0})
	function fresh.object:set_armor_groups() end
	LG.relevel(fresh, 9)
	check(fresh._grug_level == nil and fresh._grug_spawn_level == 9, "before the first tick only the field is set")
	LG.ensure_init(fresh)
	check(fresh._grug_level == 9, "and the first tick applies it")
end

-- ---------------------------------------------------------------------------
-- 8. Cost comparison (stubbed world; real-world numbers come from the probe)
-- ---------------------------------------------------------------------------
do
	local function bench(G_, label)
		local x0 = ZONE_X.elandor_dawnmere_fields
		local t0 = os.clock()
		local calls = 0
		for rep = 1, 20 do
			for dz = 0, 17 do
				local pos = {x = x0 + 5, y = 12, z = 100 + dz}
				for _, name in ipairs(mob_names) do
					G_.spawn_policy_allows(name, pos)
					calls = calls + 1
				end
			end
		end
		return (os.clock() - t0) / calls * 1e6
	end
	old_world.time, new_world.time = 0.5, 0.5
	local b1, a1 = bench(OLD, "before"), bench(NEW, "after")
	local b2, a2 = bench(OLD, "before"), bench(NEW, "after")
	print(("cost spawn_policy_allows (stubbed world): before %.3f us, after %.3f us per call")
		:format(math.min(b1, b2), math.min(a1, a2)))
	clear_world()
	local t0 = os.clock()
	local attempts = 0
	for i = 1, 2000 do
		SA.attempt(P.pos, {P}, "day")
		attempts = attempts + 1
		if #W.objects > 30 then clear_world() end
	end
	print(("cost area attempt (stubbed world): %.2f us"):format((os.clock() - t0) / attempts * 1e6))
end

print("R28 B1 PORTABLE PASS checks=" .. checks)
