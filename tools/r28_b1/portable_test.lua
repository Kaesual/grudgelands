-- Round 28 Lane B1 portable test (LuaJIT): the zone spawn data and ruling 3.
-- (Lane S1 replaced B1's hand-placed areas by spawn regions; their builder,
-- spawner, camps and leaders are tested in tools/r28_s1/portable_test.lua.)
--
--   luajit tools/r28_b1/portable_test.lua [REPO] [BASE_COMMIT]
--
-- 1. Fallback identity (ruling 34 trigger): the real spawn_policy.lua of
--    BASE_COMMIT (default 7af1aaf2, the palettes as Lua tables, read with
--    `git show`) and the current spawn_policy.lua + spawn_regions.lua (the
--    palettes as data/zones/*.spawns.json, every zone without a recipe) give the
--    same answer for every zone, every policy mob, several heights, biomes,
--    levels and both clocks: spawn_policy_allows, spawn_clock_for,
--    zone_density_cast, zone_clock_cast, zone_spawn_palette_allows and
--    density_zone_ids. Protected surfaces are kept out of this comparison
--    (ruling 3 is a deliberate change, part 2).
-- 2. Ruling 3 on ABM rows: road, bridge, village, start footprint and capital
--    city refuse ordinary natural rows; camps and POIs do not; critters and
--    NPC rows are never refused.
-- 3. The loader on the 38 shipped files: all zones, a palette in every
--    zone without a recipe, the recipe zone (Dawnmere) refuses its ABM rows
--    but its critters, format errors fail loudly.
-- 4. levels.lua: a region or leader level replaces the field; the field
--    level comes from the gameplay level (grug_core.mob_level_at).
-- 5. Cost: spawn_policy_allows before/after (stubbed world).
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

-- Each zone's level band as grug_zones serves it (the mapgen source with the
-- gameplay bands of zone_bands.lua), so the shipped recipes parse.
local ZONE_BANDS = {}
do
	local zone_bands = dofile(repo .. "/mods/CORE/grug_core/zone_bands.lua")
	for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").zones) do
		ZONE_BANDS[row.id] = zone_bands.apply({level_min = row.level_min,
			level_max = row.level_max}, row.id)
	end
end

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
		get = function(zone)
			local band = ZONE_BANDS[zone] or {level_min = 1, level_max = 10}
			return {macro_region = "elandor_mainland", hub = {x = 0, z = 0},
				level_min = band.level_min, level_max = band.level_max}
		end,
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
		register_level_overlay = function() end,
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
load_into(new_env_, MOBS .. "/spawn_regions.lua")
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
-- A zone with a spawn recipe (Lanes S1, S2) has no palette: it is compared on
-- its own in part 3. Every other zone answers exactly as before.
local SR = NEW.spawn_regions
local palette_zones, shipped_palettes = {}, 0
for _, zone in ipairs(zone_files) do
	if not SR.zone_has_recipe(zone) then palette_zones[#palette_zones + 1] = zone end
	local data = json.parse(io.open(DATA .. "/" .. zone .. ".spawns.json"):read("*a"))
	if data.recipe == nil then shipped_palettes = shipped_palettes + 1 end
end
check(#palette_zones == shipped_palettes, "the " .. shipped_palettes ..
	" zones without a recipe keep their palette (" .. #palette_zones .. ")")
-- Round 28 S2 adds recipes zone by zone: every zone has one or the other.
check(#palette_zones < #zone_files, "some zone has a spawn recipe (" ..
	(#zone_files - #palette_zones) .. " of " .. #zone_files .. ")")
do
	local old_ids = {}
	for _, zone in ipairs(OLD.density_zone_ids()) do
		if not SR.zone_has_recipe(zone) then old_ids[#old_ids + 1] = zone end
	end
	check(same_list(old_ids, NEW.density_zone_ids()), "density_zone_ids")
end

local compared = 0
for _, zone in ipairs(palette_zones) do
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
	:format(compared, #palette_zones, #mob_names))

-- ---------------------------------------------------------------------------
-- 2. Ruling 3 on ABM rows
-- ---------------------------------------------------------------------------
do
	local x0 = ZONE_X.elandor_goldmead_vale
	new_world.time, old_world.time = 0.5, 0.5
	local boar, rabbit, guard = "grug_mobs:boar", "grug_mobs:rabbit", "grug_mobs:guard_accord"
	-- A day boar on open ground is allowed in Goldmead (palette settled).
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
	check(#SR.zone_ids() == 38, "loader installed 38 zones")
	for _, zone in ipairs(SR.zone_ids()) do
		local text = io.open(DATA .. "/" .. zone .. ".spawns.json"):read("*a")
		local data = json.parse(text)
		if SR.zone_has_recipe(zone) then
			check(data.palette == nil and type(data.recipe) == "table", zone .. " recipe, no palette")
		else
			check(type(data.palette) == "table" and type(data.palette.families) == "table",
				zone .. " carries its palette")
			local keys = sorted_keys(data)
			check(#keys == 2 and keys[1] == "palette" and keys[2] == "zone", zone .. " zone and palette only")
		end
	end
	check(SR.zone_critter("elandor_dawnmere_fields", "grug_mobs:wild_turkey"), "dawnmere turkey critter")
	check(SR.zone_critter("elandor_dawnmere_fields", "grug_mobs:boar") == false, "boar is no critter")
	-- The recipe zone's ABM rows: critters it lists, nothing else on the
	-- surface; underground keeps its closed list.
	local x0 = ZONE_X.elandor_dawnmere_fields
	new_world.time = 0.5
	check(NEW.spawn_policy_allows("grug_mobs:boar", {x = x0 + 5, y = 10, z = 102}) == false,
		"ABM boar refused in a recipe zone")
	check(NEW.spawn_policy_allows("grug_mobs:shore_crab", {x = x0 + 5, y = 10, z = 102}) == false,
		"ABM crab refused in a recipe zone")
	check(NEW.spawn_policy_allows("grug_mobs:rabbit", {x = x0 + 5, y = 10, z = 102}) == true,
		"listed critter keeps its row")
	check(NEW.spawn_policy_allows("grug_mobs:gull", {x = x0 + 5, y = 10, z = 102}) == false,
		"unlisted critter refused")
	-- Rift Spawn keeps its row (Round 28 S2c) in the recipe zones whose
	-- palette carried it, at its clock; never in the others (Dawnmere).
	local gx = ZONE_X.front_gravesalt_escarpment
	new_world.time = 0.0
	check(NEW.spawn_policy_allows("grug_mobs:rift_spawn", {x = gx + 5, y = 10, z = 102}) == true,
		"Rift Spawn keeps its row in Gravesalt at night")
	check(NEW.spawn_policy_allows("grug_mobs:rift_spawn", {x = x0 + 5, y = 10, z = 102}) == false,
		"no Rift Spawn in Dawnmere, whose palette never had it")
	-- Ruling 3 still refuses it on a protected surface (memoised per
	-- position: each case at its own height).
	for step, kind in ipairs({"road", "bridge", "village"}) do
		new_world.protected.feature = function() return kind end
		check(NEW.spawn_policy_allows("grug_mobs:rift_spawn", {x = gx + 5, y = 10 + step, z = 102}) == false,
			"no Rift Spawn on a " .. kind .. " in Gravesalt")
	end
	new_world.protected.feature = nil
	check(NEW.spawn_policy_allows("grug_mobs:rift_spawn", {x = gx + 5, y = 20, z = 102}) == true,
		"Rift Spawn beside the protected surface in Gravesalt")
	new_world.time = 0.5
	check(NEW.spawn_policy_allows("grug_mobs:rift_spawn", {x = gx + 5, y = 10, z = 102}) == false,
		"Rift Spawn keeps its night clock in Gravesalt")
	check(NEW.spawn_policy_allows("grug_mobs:zombie", {x = x0 + 5, y = -60, z = 102}) ==
		OLD.spawn_policy_allows("grug_mobs:zombie", {x = x0 + 5, y = -60, z = 102}),
		"underground unchanged in a recipe zone")
	-- Format errors fail loudly and leave the zone's data in place.
	local function refused(zone, data)
		return not pcall(SR.install_zone, zone, data)
	end
	check(refused("elandor_goldmead_vale", {zone = "elandor_goldmead_vale"}),
		"a zone without a recipe needs its palette")
	check(refused("elandor_goldmead_vale", {zone = "elandor_goldmead_vale", palette = {families = {}},
		areas = {}}), "the hand-area format is gone")
	check(refused("elandor_goldmead_vale", {zone = "elandor_highcourt", palette = {families = {}}}),
		"zone mismatch")
	check(refused("elandor_goldmead_vale", {zone = "elandor_goldmead_vale", recipe = {belts = {}}}),
		"a broken recipe")
	check(NEW.spawn_regions.fallback_palettes().elandor_goldmead_vale ~= nil,
		"a refused install keeps the zone's palette")
	local palettes = upvalue(OLD.zone_density_cast, "ZONE_MOB_PALETTES")
	check(#sorted_keys(palettes) == 38, "baseline had 38 palettes")
end

-- ---------------------------------------------------------------------------
-- 4. levels.lua honours the region level
-- ---------------------------------------------------------------------------
do
	local LW = {time = 0.5, zones = {mob_level_at = function() return 1 end},
		core = setmetatable({mob_level_at = function() return 42 end},
			{__index = function() return function() return "" end end})}
	local LE = new_env(LW)
	LE.grug_xp = {mob_xp = function(level) return 25 + 5 * level end, LEVEL_OFFSET = 5}
	LE.mobs = {scale_mob = noop}
	LE.math = setmetatable({round = function(x) return math.floor(x + 0.5) end}, {__index = math})
	load_into(LE, MOBS .. "/levels.lua")
	local function new_object(ent, pos)
		local obj = {props = {}, _pos = pos}
		function obj:get_pos() return self._pos end
		function obj:get_luaentity() return ent end
		function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
		function obj:get_properties() return self.props end
		return obj
	end
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
	check(plain._grug_level == 42, "no region level: the gameplay level (grug_core) decides")
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
-- 5. Cost comparison (stubbed world)
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
end

print("R28 B1 PORTABLE PASS checks=" .. checks)
