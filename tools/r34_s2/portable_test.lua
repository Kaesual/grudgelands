-- Round 34 Lane S2 portable test (LuaJIT): ambience beds, calls, forge and
-- fire loops, the music scheduler and its on-demand delivery.
--
--   luajit tools/r34_s2/portable_test.lua [repo]
--
-- Loads the REAL grug_ambience rules.lua and data.lua, and init.lua on a
-- fake engine (every data name shipped, so the runtime paths run). Round 35
-- made music a capital feature: its scheduler, the either-music-or-bed rule
-- and the music settings are checked in tools/r35_m. Checks here:
--   B  the sound key (biome group, zone overrides, the ocean) and the
--      surface bed by it (underwater, sea and stream water, night beds and
--      the crags' silent night, no key yet keeps the bed), the fallback to
--      a shipped bed, the two-pass hysteresis, town gain; the shipped beds
--      per group (Round 52 code step: the groups whose files are not
--      shipped yet are silent) and no dropped file named;
--   C  calls by sound key and time of day;
--   T  the town flag of grug_map's location resolver;
--   E  fire and water emitters: the nearest per kind; none at forges and anvils;
--   P  settings: /music and /ambience words, volumes;
--   R  runtime on a fake engine: one pass per player per 2 s in eight
--      slots; a bed loop to the player only, crossfaded at night, under
--      water and between groups, none between biomes of one group; the
--      three layers by the depth (Round 52): the surface bed fading down a
--      shaft to the floor and stopped after three passes, the dead band,
--      no restart when hovering at a threshold, the cave bed only in open
--      air and its deep variant, the wind at height; emitters started and
--      faded, underground too; the debug line; no music outside a
--      capital; the ambience settings through the Help page fields and the
--      chat command;
--   F  files: data integrity (every rotation track, bed key and call);
--      every shipped .ogg of the mod is on tools/r34_s2/approved.txt; once
--      that list exists, every name in data.lua is shipped.
-- Prints "R34 S2 PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

local MOD = repo .. "/mods/CORE/grug_ambience"
local R = dofile(MOD .. "/rules.lua")
local D = dofile(MOD .. "/data.lua")

-- A seeded stand-in for math.random(a, b).
local function seeded(seed)
	local state = seed
	return function(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		if not a then return state / 2147483648 end
		return a + state % (b - a + 1)
	end
end

local function all_available()
	local set = {}
	for _, names in pairs(D.beds) do
		for _, n in ipairs(names) do set[n] = true end
	end
	for _, call in pairs(D.calls) do set[call.sound] = true end
	for _, e in pairs(D.emitters) do set[e.sound] = true end
	return set
end
local AVAILABLE = all_available()

-- ---------------------------------------------------------------------------
-- B  beds: the rules on a test table, then the shipped data (Round 52: the
-- surface bed by sound key, round52-ambience-plan.md §2)
-- ---------------------------------------------------------------------------
local TD = {gains = D.gains,
	beds = {temperate = {"t1", "t2", "t3"}, temperate_night = {"n1"}, crags = {"c1"},
		crags_snowy = {"s1"}, ocean = {"o1"}, sea = {"o1"}, stream = {"st1"}, underwater = {"w1"},
		battlegrounds = {"b1"}},
	region = {temperate = {day = "temperate", night = "temperate_night"},
		crags = {day = "crags", night = false}, crags_snowy = {day = "crags_snowy"},
		ocean = {day = "ocean"}, battlegrounds = {day = "battlegrounds"}},
	groups = {grug_meadows = "temperate", grug_elf_forest = "temperate", grug_crags = "crags",
		grug_crags_snowy = "crags_snowy"},
	overrides = {battlegrounds = true, dragon_island = true, ocean = true},
	calls = {owl = {sound = "o", time = "night", keys = {temperate = true}},
		crow = {sound = "c", time = "day", keys = {battlegrounds = true}},
		thunder = {sound = "t", time = "any", keys = {dragon_island = true}}},
}
local TA = {}
for _, names in pairs(TD.beds) do for _, n in ipairs(names) do TA[n] = true end end
for _, call in pairs(TD.calls) do TA[call.sound] = true end
do
	local function key(mood, biome) return R.sound_key(TD, mood, true, biome) end
	check(key(nil, "grug_meadows") == "temperate" and key("human", "grug_elf_forest") == "temperate",
		"B the biome's group, whatever race mood the zone has")
	check(key("battlegrounds", "grug_meadows") == "battlegrounds" and
		key("dragon_island", "grug_crags") == "dragon_island", "B zone overrides beat the biome")
	check(key(nil, nil) == "ocean" and key("ocean", nil) == "ocean", "B no biome (deep ocean): the ocean")
	check(key(nil, "grug_unknown") == false, "B a biome without a group: no bed")
	check(key("underground", "grug_meadows") == nil and R.sound_key(TD, "human", false, nil) == nil,
		"B underground mood or nothing known: keep the key")
	local function keys(s) return R.bed_keys(TD, s) end
	local function first(s) return R.pick_bed(TD, keys(s), TA) end
	check(first({key = "temperate", underwater = true, water = "sea"}) == "underwater",
		"B underwater beats everything")
	check(first({key = "temperate", water = "sea"}) == "sea", "B sea near the player")
	check(first({key = "temperate", water = "stream", night = true}) == "stream", "B stream beats night")
	check(first({key = "temperate", night = true}) == "temperate_night", "B night bed")
	check(first({key = "temperate"}) == "temperate", "B day bed")
	check(first({key = "crags_snowy", night = true}) == "crags_snowy",
		"B a key without a night row keeps its bed")
	check(first({key = "crags", night = true}) == false and first({key = "crags"}) == "crags",
		"B crags: the day bed, silence at night")
	check(first({key = "crags", night = true, water = "sea"}) == "sea", "B crags at night still hear the sea")
	check(first({key = "savanna"}) == false and first({key = false}) == false,
		"B a key without a row, or none: silence")
	check(R.bed_keys(TD, {key = nil}) == nil, "B no key yet: keep the bed")
	check(first({key = nil, water = "sea"}) == "sea", "B no key yet still hears the sea")
	local some = {}
	for k, v in pairs(TA) do some[k] = v end
	some.n1 = nil
	check(R.pick_bed(TD, keys({key = "temperate", night = true}), some) == "temperate",
		"B no night file: the day bed")
	check(R.pick_bed(TD, keys({key = "temperate", underwater = true}), {}) == false,
		"B nothing shipped: silence")
	local ok = true
	for seed = 1, 20 do
		if R.bed_sound(TD, "temperate", {t2 = true}, seeded(seed)) ~= "t2" then ok = false end
	end
	check(ok, "B variant picked among shipped names only")
	local b = {seen = 0}
	check(R.bed_should_change(b, "temperate") == true, "B first bed starts at once")
	b.key = "temperate"
	check(R.bed_should_change(b, "stream") == false, "B one pass of stream: wait")
	check(R.bed_should_change(b, "temperate") == false, "B back to temperate: stays")
	check(R.bed_should_change(b, "stream") == false and R.bed_should_change(b, "stream") == true,
		"B two passes of stream: change")
	b.key = "stream"
	check(R.bed_should_change(b, "underwater", true) == true, "B diving changes at once")
	b.key = "underwater"
	check(R.bed_should_change(b, "stream", false) == true, "B surfacing changes at once")
	b.key = "temperate"
	check(R.bed_should_change(b, false, true) == true and b.underwater == true,
		"B diving into silence changes at once")
	check(math.abs(R.bed_gain(D, 100, true) - D.gains.bed * D.gains.town_bed) < 1e-9 and
		math.abs(R.bed_gain(D, 50, false) - D.gains.bed * 0.5) < 1e-9, "B gain: volume and town")

	-- the shipped data (code step: only shipped files are named; the groups
	-- whose files come with the user's approval are silent until then)
	local function real(key, night) return R.pick_bed(D, R.bed_keys(D, {key = key, night = night}), AVAILABLE) end
	local day = {temperate = "temperate", savanna = "savanna", jungle = "jungle", badlands = false,
		swamp = false, crags = false, crags_snowy = false, blight = "blight", beach = "beach",
		battlegrounds = false, dragon_island = "dragon_island", ocean = "ocean"}
	local night = {temperate = "temperate_night", savanna = "savanna_night", jungle = "jungle",
		badlands = false, swamp = false, crags = false, crags_snowy = false, blight = "blight",
		beach = "beach", battlegrounds = false, dragon_island = "dragon_island", ocean = "ocean"}
	for k, want in pairs(day) do
		check(real(k) == want, "B day bed for " .. k .. ": " .. tostring(real(k)))
		check(real(k, true) == night[k], "B night bed for " .. k .. ": " .. tostring(real(k, true)))
	end
	check(D.region.crags.night == false, "B the crags are silent at night (§6.2)")
	local function names_of(key)
		local t = {}
		for _, n in ipairs(D.beds[key] or {}) do t[#t + 1] = n end
		table.sort(t)
		return table.concat(t, ",")
	end
	check(names_of("temperate") == "grug_ambience_elf_forest,grug_ambience_human_meadow",
		"B temperate: the human and elf forest beds (ruling 1)")
	check(names_of("savanna") == "grug_ambience_orc_steppe" and
		names_of("jungle") == "grug_ambience_elf_birdsong,grug_ambience_troll_jungle",
		"B the orc bed in the savanna, the troll bed in the jungle (ruling 1)")
	check(names_of("wind") == "grug_ambience_battlegrounds_gusts", "B the gusts are the wind (ruling 2)")
	check(names_of("cave") == "grug_ambience_underground_dungeon" and
		names_of("cave_deep") == "grug_ambience_underground_crystal", "B the cave beds (ruling 6, §6.6)")
	local dropped = {grug_ambience_elf_blackbirds = true, grug_ambience_undead_graveyard = true,
		grug_ambience_underground_dark = true, grug_ambience_orc_wind = true,
		grug_ambience_dwarf_storm = true, grug_ambience_underground_creepy = true}
	local named_dropped = {}
	for _, names in pairs(D.beds) do
		for _, n in ipairs(names) do if dropped[n] then named_dropped[#named_dropped + 1] = n end end
	end
	check(#named_dropped == 0, "B no dropped file is named (ruling 9): " .. table.concat(named_dropped, ","))
	check(D.beds.underground == nil and D.beds.underwater == nil, "B no underground or underwater bed key")
	check(D.gains.bed == 0.2, "B every bed at gain 0.2")
end

-- ---------------------------------------------------------------------------
-- C  calls
-- ---------------------------------------------------------------------------
do
	local function ids(s) return table.concat(R.eligible_calls(TD, s, TA), ",") end
	check(ids({key = "temperate", night = true}) == "owl", "C night call by sound key")
	check(ids({key = "temperate", night = false}) == "", "C day: none")
	check(ids({key = "battlegrounds", night = false}) == "crow", "C day call by sound key")
	check(ids({key = "temperate", night = true, underwater = true}) == "", "C none under water")
	check(ids({key = "temperate", night = true, underground = true}) == "", "C none underground")
	check(table.concat(R.eligible_calls(TD, {key = "temperate", night = true}, {}), ",") == "",
		"C no shipped file: no call")
	local function real(s) return table.concat(R.eligible_calls(D, s, AVAILABLE), ",") end
	check(real({key = "dragon_island"}) == "thunder" and real({key = "dragon_island", night = true}) == "thunder",
		"C thunder on the dragon islands, day and night")
	check(real({key = "dragon_island", surface = 0}) == "thunder", "C thunder ignores the surface level")
	local others = ""
	for k in pairs(D.region) do
		if k ~= "dragon_island" then others = others .. real({key = k, surface = 1}) .. real({key = k, night = true, surface = 1}) end
	end
	check(others == "", "C no other call ships yet: " .. others)
	local lo, hi = math.huge, -math.huge
	for seed = 1, 200 do
		local d = R.next_call_delay(D, seeded(seed))
		lo, hi = math.min(lo, d), math.max(hi, d)
	end
	check(lo >= 90 and hi <= 240, "C calls are rare: 90-240 s apart")
end

-- ---------------------------------------------------------------------------
-- T  the town seam of the location resolver (grug_map/location_view.lua)
-- ---------------------------------------------------------------------------
do
	local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
	local resolve = L.resolver({zone_at = function() return "zone_a" end,
		names = {zone_a = "Zone A"}, reach = 50,
		towns = {{name = "Dawnmere", x = 0, z = 0, footprint = "fp1"}},
		footprint_at = function(x, z) return (math.abs(x) < 20 and math.abs(z) < 20) and "fp1" or nil end})
	local text, town = resolve(5, 5)
	check(text == "Dawnmere" and town == true, "T inside a town: its name and true")
	text, town = resolve(30, 30)
	check(text == "Zone A" and not town, "T outside: the zone, not a town")
end

-- ---------------------------------------------------------------------------
-- E  emitters
-- ---------------------------------------------------------------------------
do
	local limits = {forge = 2, fire = 2, furnace = 2, water = 2}
	local hears = {forge = 16, fire = 10, furnace = 10, water = 14}
	local key = function(p) return p.x .. "," .. p.y .. "," .. p.z end
	local found = {
		["grug_jobs:forge"] = {{x = 10, y = 0, z = 0}},
		["grug_decor:cottages_anvil"] = {{x = 3, y = 0, z = 0}, {x = 6, y = 0, z = 0}},
		["default:furnace_active"] = {{x = 0, y = 0, z = 2}, {x = 0, y = 0, z = 9},
			{x = 0, y = 0, z = 5}},
		["grug_decor:xdecor_cauldron"] = {{x = 0, y = 0, z = 1}},
		["default:stone"] = {{x = 1, y = 0, z = 0}},
		["default:water_source"] = {{x = 0, y = 0, z = -1}},
	}
	local function text(rows)
		local t = {}
		for _, row in ipairs(rows) do t[#t + 1] = row.kind .. "@" .. row.pos.x .. "," .. row.pos.z end
		return table.concat(t, " ")
	end
	local rows = R.choose_emitters(found, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {}, key)
	-- Round 45 PT8: forges and anvils have no loop any more (their sound plays
	-- at a job's start, tools/r45_pt8).
	-- Round 47: a burning furnace is the furnace kind (same loop, lower gain).
	check(text(rows) == "furnace@0,2 furnace@0,5",
		"E the nearest two per kind; forges, anvils, sources, cold cauldrons and other nodes ignored: " ..
		text(rows))
	check(D.emitter_nodes["grug_jobs:forge"] == nil and D.emitter_nodes["grug_decor:cottages_anvil"] == nil
		and D.emitters.forge == nil, "E no loop at forges and anvils (Round 45 PT8)")
	rows = R.choose_emitters({["default:furnace_active"] = {{x = 11, y = 0, z = 0}},
		["default:water_flowing"] = {{x = 11, y = 0, z = 0}}}, D.emitter_nodes, {x = 0, y = 0, z = 0},
		limits, hears, {}, key)
	check(text(rows) == "water@11,0", "E a node beyond its kind's hearing distance is no candidate")
	-- flowing water along a river: a playing loop stays while among the nearest 2 * limit
	local river = {["default:water_flowing"] = {}}
	for x = 1, 8 do table.insert(river["default:water_flowing"], {x = x, y = 0, z = 0}) end
	rows = R.choose_emitters(river, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {["3,0,0"] = true}, key)
	check(text(rows) == "water@1,0 water@3,0", "E a playing loop near enough stays: " .. text(rows))
	rows = R.choose_emitters(river, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {["6,0,0"] = true}, key)
	check(text(rows) == "water@1,0 water@2,0", "E a playing loop too far behind is replaced: " .. text(rows))
	-- a river bank with hundreds of flowing nodes: the same choice as a full sort
	local many, brute = {["default:water_flowing"] = {}}, {}
	local r = seeded(11)
	for i = 1, 300 do
		local p = {x = r(-12, 12), y = r(-5, 5), z = r(-12, 12)}
		table.insert(many["default:water_flowing"], p)
		brute[#brute + 1] = p
	end
	table.sort(brute, function(a, b)
		local da, db = a.x * a.x + a.y * a.y + a.z * a.z, b.x * b.x + b.y * b.y + b.z * b.z
		if da ~= db then return da < db end
		if a.x ~= b.x then return a.x < b.x end
		if a.y ~= b.y then return a.y < b.y end
		return a.z < b.z
	end)
	rows = R.choose_emitters(many, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears, {}, key)
	check(#rows == 2 and rows[1].pos == brute[1] and rows[2].pos == brute[2],
		"E 300 flowing nodes: the two nearest, as a full sort")
	rows = R.choose_emitters(many, D.emitter_nodes, {x = 0, y = 0, z = 0}, limits, hears,
		{[key(brute[4])] = true}, key)
	check(#rows == 2 and rows[1].pos == brute[1] and rows[2].pos == brute[4],
		"E 300 flowing nodes: the fourth nearest still playing stays")
	check(D.emitter_nodes["default:water_source"] == nil and D.emitter_nodes["default:river_water_source"] == nil,
		"E never a water source")
end

-- ---------------------------------------------------------------------------
-- P  settings
-- ---------------------------------------------------------------------------
do
	local function same(a, b)
		return a ~= nil and a.on == b.on and a.volume == b.volume
	end
	check(same(R.parse_command(""), {}), "P status")
	check(same(R.parse_command(" ON "), {on = true}), "P on")
	check(same(R.parse_command("off"), {on = false}), "P off")
	check(same(R.parse_command("50"), {on = true, volume = 50}), "P 50")
	check(same(R.parse_command("50%"), {on = true, volume = 50}), "P 50%")
	check(same(R.parse_command("0"), {on = false, volume = 0}), "P 0 is off")
	check(same(R.parse_command("250"), {on = true, volume = 100}), "P clamps to 100")
	check(R.parse_command("loud") == nil and R.parse_command("-5") == nil, "P bad words")
	check(R.clamp_volume("x") == nil and R.clamp_volume(49.6) == 50, "P clamp")
	check(R.audible(true, 1) and not R.audible(true, 0) and not R.audible(false, 80), "P audible")
end

-- ---------------------------------------------------------------------------
-- R  runtime on a fake engine (Round 52: the three layers by the depth below
-- a per-player surface reference and the biome under the player, both from
-- a stand-in grug_core.depth_below_surface)
-- ---------------------------------------------------------------------------
do
	local us = 0
	local steps, joins, leaves, loaded, commands = {}, {}, {}, {}, {}
	local players = {}
	local sounds, fades, pushes = {}, {}, {}
	local huds = {}
	local next_handle = 0
	local node_at = {} -- "x,y,z" -> content id
	local open_default = 0 -- the content id where node_at names none (0: rock)
	local found_nodes = {}
	local finds = 0
	local searched
	local timeofday = 0.5
	local shipped = {}
	for name in pairs(AVAILABLE) do shipped[#shipped + 1] = name .. ".ogg" end
	shipped[#shipped + 1] = "grug_ambience_call_thunder.1.ogg"
	local music = {}
	for _, track in pairs(D.tracks) do music[#music + 1] = track.file end
	local CID = {["default:water_source"] = 10, ["default:water_flowing"] = 11,
		["default:river_water_source"] = 12, ["default:river_water_flowing"] = 13,
		air = 99, ignore = 127, ["default:torch"] = 98}
	local AIR = 99
	local fake_core = {
		get_current_modname = function() return "grug_ambience" end,
		get_modpath = function() return MOD end,
		get_dir_list = function(path)
			if path:find("/sounds$") then return shipped end
			if path:find("/music$") then return music end
			return {}
		end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_chatcommand = function(name, def) commands[name] = def end,
		get_player_by_name = function(name) return players[name] end,
		get_us_time = function() return us end,
		get_timeofday = function() return timeofday end,
		registered_nodes = {
			air = {walkable = false}, ignore = {walkable = false},
			["default:torch"] = {walkable = false},
			["default:water_source"] = {liquidtype = "source", walkable = false},
			["default:water_flowing"] = {liquidtype = "flowing", walkable = false,
				liquid_alternative_source = "default:water_source"},
			["default:river_water_source"] = {liquidtype = "source", walkable = false},
			["default:river_water_flowing"] = {liquidtype = "flowing", walkable = false,
				liquid_alternative_source = "default:river_water_source"},
			["grug_test:bog_flowing"] = {liquidtype = "flowing",
				liquid_alternative_source = "default:river_water_source"},
			["default:lava_flowing"] = {liquidtype = "flowing",
				liquid_alternative_source = "default:lava_source"},
			["grug_jobs:forge"] = {}, ["grug_decor:cottages_anvil"] = {},
			["default:furnace_active"] = {}, ["grug_nodes:camp_fire"] = {}},
		get_content_id = function(name) return CID[name] or 0 end,
		get_node_raw = function(x, y, z) return node_at[x .. "," .. y .. "," .. z] or open_default end,
		find_nodes_in_area = function(minp, maxp, names, grouped)
			finds = finds + 1
			assert(grouped == true)
			searched = names
			local wanted = {}
			for _, n in ipairs(names) do wanted[n] = true end
			local out = {}
			for name, list in pairs(found_nodes) do
				if wanted[name] then
				for _, p in ipairs(list) do
					if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
							p.z >= minp.z and p.z <= maxp.z then
						out[name] = out[name] or {}
						table.insert(out[name], p)
					end
				end
				end
			end
			return out
		end,
		hash_node_position = function(p) return p.x * 1000000 + p.y * 1000 + p.z end,
		sound_play = function(spec, params, ephemeral)
			next_handle = next_handle + 1
			sounds[#sounds + 1] = {spec = spec, params = params, ephemeral = ephemeral,
				handle = next_handle}
			return next_handle
		end,
		sound_fade = function(handle, step, gain)
			fades[#fades + 1] = {handle = handle, step = step, gain = gain}
		end,
		dynamic_add_media = function(options, callback)
			pushes[#pushes + 1] = {options = options, callback = callback}
			return true
		end,
		formspec_escape = function(text) return text end,
		log = function() end,
		-- Round 47: init.lua hooks the furnaces' on_destruct (tools/r47_fs).
		override_item = function(name, fields)
			for k, v in pairs(fields) do core.registered_nodes[name][k] = v end
		end,
	}
	rawset(_G, "core", fake_core)
	local mood = {}
	local in_town = {}
	-- Per player: the surface reference y (terrain or water surface) and the
	-- biome under the player; the stand-in counts its calls.
	local ref, biome = {}, {}
	local depth_calls = 0
	rawset(_G, "grug_core", {
		atmosphere_moods = {human = true, elf = true, dwarf = true, undead = true, orc = true,
			troll = true, battlegrounds = true, dragon_island = true, ocean = true,
			underground = true},
		get_atmosphere = function(name) return mood[name] end,
		is_day_phase = function(t) return t >= 0.1875 and t <= 0.8125 end,
		depth_below_surface = function(pos, name)
			depth_calls = depth_calls + 1
			return (ref[name] or 9) + 0.5 - pos.y, {biome = biome[name] or "grug_meadows"}
		end,
	})
	rawset(_G, "grug_map", {location = {in_town = function(name) return in_town[name] == true end,
		capital_of = function() return nil end}})
	dofile(MOD .. "/init.lua")
	for _, fn in ipairs(loaded) do fn() end
	local A = rawget(_G, "grug_ambience")

	local function new_player(name, pos)
		local store = {}
		local meta = {}
		function meta:get(k) return store[k] end
		function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
		function meta:set_int(k, v) store[k] = tostring(v) end
		local p = {_pos = pos, _store = store}
		function p:get_player_name() return name end
		function p:get_pos() return {x = self._pos.x, y = self._pos.y, z = self._pos.z} end
		function p:get_meta() return meta end
		function p:hud_add(def)
			huds[#huds + 1] = {def = def, text = def.text}
			return #huds
		end
		function p:hud_change(id, stat, value) huds[id][stat] = value end
		function p:hud_remove(id) huds[id].removed = true end
		players[name] = p
		for _, fn in ipairs(joins) do fn(p) end
		return p
	end
	local function run(seconds)
		for _ = 1, math.floor(seconds / 0.25 + 0.5) do
			us = us + 250000
			for _, fn in ipairs(steps) do fn(0.25) end
		end
	end
	local function plays_to(name, filter)
		local list = {}
		for _, s in ipairs(sounds) do
			if s.params.to_player == name and (not filter or filter(s)) then list[#list + 1] = s end
		end
		return list
	end
	local function is_bed(s) return s.params.loop and not s.params.pos end
	local function named(prefix) return function(s) return is_bed(s) and s.spec.name:find(prefix, 1, true) == 1 end end
	local is_wind = named("grug_ambience_battlegrounds_gusts")
	local is_cave = function(s) return named("grug_ambience_underground_")(s) end
	local function fades_of(handle)
		local list = {}
		for _, f in ipairs(fades) do if f.handle == handle then list[#list + 1] = f end end
		return list
	end
	local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end
	local FULL = D.gains.bed

	-- slots: eight players, each evaluated once per 2 s
	local before = A.stats.passes
	for i = 1, 8 do
		local name = "slot" .. i
		mood[name] = "human"
		new_player(name, {x = 1000 * i, y = 10, z = 0})
	end
	local per_step = {}
	for _ = 1, 8 do
		local p0 = A.stats.passes
		us = us + 250000
		for _, fn in ipairs(steps) do fn(0.25) end
		per_step[#per_step + 1] = A.stats.passes - p0
	end
	check(A.stats.passes - before == 8 and table.concat(per_step, ",") == "1,1,1,1,1,1,1,1",
		"R one player per slot, each once per 2 s: " .. table.concat(per_step, ","))
	check(#steps == 1, "R one globalstep, no new per-tick work")
	for i = 1, 8 do
		players["slot" .. i] = nil
		for _, fn in ipairs(leaves) do fn({get_player_name = function() return "slot" .. i end}) end
	end

	-- one player on the ground in a meadow: day bed, night crossfade, water
	sounds, fades, pushes = {}, {}, {}
	mood.ana, ref.ana = "human", 9
	local ana = new_player("ana", {x = 0, y = 9.5, z = 0})
	run(2)
	local beds = plays_to("ana", is_bed)
	check(#beds == 1 and (beds[1].spec.name == "grug_ambience_human_meadow" or
		beds[1].spec.name == "grug_ambience_elf_forest") and beds[1].params.to_player == "ana" and
		beds[1].ephemeral == false and near(beds[1].spec.gain, FULL),
		"R the meadow's temperate bed loops to the player only, at full level")
	check(#plays_to("ana", is_wind) == 0 and #plays_to("ana", is_cave) == 0,
		"R on the ground: no wind, no cave bed")
	local day_handle = beds[1] and beds[1].handle
	timeofday = 0.95
	run(2)
	check(#plays_to("ana", is_bed) == 1, "R night: one pass is not enough (hysteresis)")
	run(2)
	beds = plays_to("ana", is_bed)
	check(#beds == 2 and beds[2].spec.name:find("^grug_ambience_night_"), "R night bed after two passes")
	local faded = false
	for _, f in ipairs(fades) do
		if f.handle == day_handle and f.gain == 0 then faded = true end
	end
	check(faded, "R the day bed fades out (crossfade)")
	-- under water: the eye node is water; no underwater bed ships, so silence
	node_at["0,11,0"] = 10
	fades = {}
	local count = #plays_to("ana", is_bed)
	run(2)
	local night_off = false
	for _, f in ipairs(fades) do if f.handle == beds[2].handle and f.gain == 0 then night_off = true end end
	check(night_off and #plays_to("ana", is_bed) == count, "R under water: the bed stops at once, silence")
	node_at["0,11,0"] = nil
	run(2)
	beds = plays_to("ana", is_bed)
	check(#beds == count + 1 and beds[#beds].spec.name:find("^grug_ambience_night_") ~= nil,
		"R surfacing: the night bed again")
	-- at night the elf forest is in the same group: nothing restarts; the
	-- jungle is another group: a crossfade after two passes
	biome.ana = "grug_elf_forest"
	mood.ana = "elf"
	fades = {}
	run(4)
	check(#fades == 0 and #plays_to("ana", is_bed) == count + 1,
		"R into the elf forest at night: the same temperate night bed goes on")
	timeofday = 0.5
	biome.ana = "grug_deep_jungle"
	mood.ana = "troll"
	run(2)
	run(2)
	beds = plays_to("ana", is_bed)
	check(#beds >= count + 2 and (beds[#beds].spec.name == "grug_ambience_troll_jungle" or
		beds[#beds].spec.name == "grug_ambience_elf_birdsong"),
		"R into the jungle by day: a crossfade to the jungle bed")
	-- a zone override: the Battlegrounds' own bed is not shipped yet: silence
	mood.ana = "battlegrounds"
	fades = {}
	run(4)
	check(#fades >= 1 and fades[#fades].gain == 0 and #plays_to("ana", is_bed) == #beds,
		"R the Battlegrounds override the biome (their bed comes with its file: silence now)")
	mood.ana, biome.ana = "human", "grug_meadows"
	run(4)

	-- town: the bed fades to the town gain
	in_town.ana = true
	fades = {}
	run(4)
	local town_fade = false
	for _, f in ipairs(fades) do
		if near(f.gain, FULL * D.gains.town_bed) then town_fade = true end
	end
	check(town_fade, "R in town the bed is quieter")
	in_town.ana = nil
	run(4)

	-- digging down: the surface bed fades with the depth, to the floor at
	-- -15, and is stopped only after three passes there; nothing restarts in
	-- the shaft
	beds = plays_to("ana", is_bed)
	local surface = beds[#beds]
	fades, sounds = {}, {}
	ana._pos.y = 9.5 - 7.5 -- depth 7.5: half the surface level
	run(2)
	local f = fades_of(surface.handle)
	check(#f == 1 and near(f[1].gain, 0.5 * FULL) and near(f[1].step, 0.5 * FULL / D.layer_fade),
		"R 7.5 nodes down: the surface bed fades to 50 % over one pass")
	ana._pos.y = 9.5 - 7.8 -- 0.3 deeper: inside the dead band
	run(2)
	check(#fades_of(surface.handle) == 1, "R a change under 3 % of the bed level sends nothing")
	ana._pos.y = 9.5 - 15
	run(2)
	f = fades_of(surface.handle)
	check(#f == 2 and near(f[2].gain, R.LEVEL_FLOOR * FULL), "R at -15 the bed fades to the 0.01 floor")
	run(2)
	check(#fades_of(surface.handle) == 2, "R a second pass at the floor: nothing")
	run(2)
	f = fades_of(surface.handle)
	check(#f == 3 and f[3].gain == 0, "R the third pass at the floor stops the bed (fade to 0)")
	ana._pos.y = 9.5 - 30
	run(10)
	check(#fades_of(surface.handle) == 3 and #plays_to("ana") == 0,
		"R in the dug shaft: silence, the stopped sound is never touched again")
	-- hovering around the threshold does not restart the loop every pass
	ana._pos.y = 9.5 - 14
	run(2)
	beds = plays_to("ana", is_bed)
	check(#beds == 1 and near(beds[1].spec.gain, (1 - 14 / 15) * FULL),
		"R back up to -14: a new surface sound at 7 %")
	ana._pos.y = 9.5 - 15.5
	run(4)
	ana._pos.y = 9.5 - 14
	run(2)
	check(#plays_to("ana", is_bed) == 1, "R dipping below -15 for two passes keeps the sound")
	ana._pos.y = 9.5
	run(2)
	check(#plays_to("ana", is_bed) == 1 and near(fades_of(beds[1].handle)[#fades_of(beds[1].handle)].gain, FULL),
		"R back on the ground: the same sound fades up to full")

	-- a real cave: open air all round; the cave bed fades in after two
	-- passes (the probe's hysteresis), quietly
	open_default = AIR
	fades, sounds = {}, {}
	ana._pos.y = 9.5 - 10 -- depth 10
	run(2)
	check(#plays_to("ana", is_cave) == 0, "R in a cave: one pass is not enough (hysteresis)")
	run(2)
	local caves = plays_to("ana", is_cave)
	check(#caves == 1 and caves[1].spec.name == "grug_ambience_underground_dungeon" and
		near(caves[1].spec.gain, (10 - 4) / 12 * 0.4 * FULL),
		"R in a cave 10 down: the dungeon bed at (10-4)/12 of 40 %")
	ana._pos.y = 9.5 - 40
	run(2)
	f = fades_of(caves[1].handle)
	check(#f == 1 and near(f[1].gain, 0.4 * FULL), "R deep in the cave: the cave bed at its 40 % cap")
	-- a dug tunnel: rock all round; the cave bed fades to the floor, stops
	-- (standing still, the probe's share is reused for up to two passes)
	open_default = 0
	run(14)
	f = fades_of(caves[1].handle)
	check(#f >= 3 and f[#f].gain == 0 and #plays_to("ana", is_cave) == 1,
		"R into a dug tunnel: the cave bed goes, nothing else plays")
	-- the deep cave bed below -500
	open_default = AIR
	ana._pos.y = -520
	ref.ana = -480
	run(6)
	caves = plays_to("ana", is_cave)
	check(caves[#caves].spec.name == "grug_ambience_underground_crystal",
		"R a real cave below -500: the crystal bed")
	-- the underground loops: a burning furnace in a mine is heard
	found_nodes = {["default:furnace_active"] = {{x = 2, y = -520, z = 0}}}
	run(2)
	check(#plays_to("ana", function(s) return s.params.loop and s.params.pos end) == 1,
		"R a burning furnace in the mine plays its loop (Round 52)")
	found_nodes = {}
	open_default = 0
	ref.ana = 9
	ana._pos.y = 9.5
	run(8)

	-- a tower and the flying mount: the bed fades from +10, the wind from +30
	fades, sounds = {}, {}
	ana._pos.y = 9.5 + 35
	run(2)
	local winds = plays_to("ana", is_wind)
	check(#winds == 1 and near(winds[1].spec.gain, (35 - 30) / 70 * 0.5 * FULL),
		"R 35 up: the wind starts at (35-30)/70 of 50 %")
	ana._pos.y = 9.5 + 31
	run(2)
	check(#plays_to("ana", is_wind) == 1, "R hovering near +30 does not restart the wind")
	ana._pos.y = 9.5 + 100
	run(2)
	f = fades_of(winds[1].handle)
	check(near(f[#f].gain, 0.5 * FULL), "R 100 up: the wind at its 50 % cap")
	ana._pos.y = 9.5 + 300
	run(2)
	check(near(fades_of(winds[1].handle)[#fades_of(winds[1].handle)].gain, 0.5 * FULL),
		"R far above: the wind stays at 50 %")
	-- music: every layer silent
	ana._pos.y = 9.5
	run(8)

	-- emitters: an anvil, a furnace and flowing water near the player, a
	-- forge far away, a water source next to the player (never a loop; since
	-- Round 45 PT8 neither the anvil nor the forge)
	found_nodes = {["grug_decor:cottages_anvil"] = {{x = 4, y = 10, z = 0}},
		["default:furnace_active"] = {{x = 0, y = 10, z = 5}},
		["grug_jobs:forge"] = {{x = 60, y = 10, z = 0}},
		["default:water_source"] = {{x = 1, y = 9, z = 0}},
		["default:river_water_flowing"] = {{x = -3, y = 9, z = 0}},
		["grug_test:bog_flowing"] = {{x = -6, y = 9, z = 0}, {x = -9, y = 9, z = 0}},
		["default:lava_flowing"] = {{x = 2, y = 9, z = 2}}}
	sounds = {}
	local f0 = finds
	run(2)
	check(finds - f0 == 1, "R one node search per pass")
	local want = {}
	for _, n in ipairs(searched) do want[n] = true end
	check(want["default:water_flowing"] and want["grug_test:bog_flowing"] and
		not want["default:water_source"] and not want["default:river_water_source"] and
		not want["default:lava_flowing"], "R searched: flowing water of any registered kind, never a source")
	local loops = plays_to("ana", function(s) return s.params.loop and s.params.pos end)
	local names = {}
	for _, s in ipairs(loops) do names[#names + 1] = s.spec.name .. "@" .. s.params.pos.x end
	table.sort(names)
	check(table.concat(names, " ") == "grug_ambience_fire@0 " ..
		"grug_ambience_stream_pond@-3 grug_ambience_stream_pond@-6" and
		loops[1].params.to_player == "ana", "R fire and flowing-water loops, none at the anvil: " ..
		table.concat(names, " "))
	run(2)
	check(#plays_to("ana", function(s) return s.params.loop and s.params.pos end) == 3,
		"R running loops are not restarted")
	found_nodes = {}
	fades = {}
	run(2)
	local loop_fades = 0
	for _, fd in ipairs(fades) do if fd.gain == 0 then loop_fades = loop_fades + 1 end end
	check(loop_fades == 3, "R loops fade out when out of reach")

	-- the debug line: on, one HUD text with the biome, group, depth, cave
	-- share and the levels; sent only when it changes; off removes it
	local ok, msg = commands.ambience.func("ana", "debug")
	check(ok and msg:find("on") and #huds == 1 and huds[1].def.type == "text" and
		huds[1].def.position.x == 0, "R /ambience debug: one text line, left")
	run(2)
	local shown = huds[1].text
	check(shown:find("meadows", 1, true) and shown:find("temperate", 1, true) and
		shown:find("depth 0.0", 1, true) and shown:find("surface 100%", 1, true) and
		shown:find("wind 0%", 1, true), "R the line names biome, group, depth and levels: " .. shown)
	local changes = 0
	local real_change = players.ana.hud_change
	players.ana.hud_change = function(self, ...) changes = changes + 1 return real_change(self, ...) end
	run(6)
	check(changes == 0, "R nothing changed: nothing sent")
	ana._pos.y = 9.5 - 7.5
	run(2)
	check(changes == 1 and huds[1].text:find("surface 50%", 1, true), "R a change is sent once")
	players.ana.hud_change = real_change
	ok = commands.ambience.func("ana", "debug")
	check(ok and huds[1].removed, "R /ambience debug again removes it")
	check(commands.music.func("ana", "debug") == false, "R /music debug is no word")
	ana._pos.y = 9.5
	run(4)

	-- no music outside a capital (Round 35; the music runtime: tools/r35_m)
	run(600)
	check(#pushes == 0, "R no music push outside a capital in 10 min")
	-- "on" after a volume of 0 is never silent
	commands.ambience.func("ana", "0")
	A.handle_settings_fields(ana, {grug_ambience_ambience = "true"})
	check(A.get(ana, "ambience").on and A.get(ana, "ambience").volume == R.DEFAULT_VOLUME.ambience,
		"R the ambience checkbox after 0 restores the default volume")
	run(2)
	-- a volume change fades every playing layer
	fades = {}
	commands.ambience.func("ana", "50")
	check(#fades == 1 and near(fades[1].gain, 0.5 * FULL), "R /ambience 50 fades the bed to half")
	commands.ambience.func("ana", "100")
	-- ambience off: the bed fades, nothing new plays
	fades, sounds = {}, {}
	commands.ambience.func("ana", "off")
	local bed_off = false
	for _, fd in ipairs(fades) do if fd.gain == 0 then bed_off = true end end
	run(600)
	check(bed_off and #plays_to("ana", function(s) return s.spec.name:find("^grug_ambience_") end) == 0,
		"R ambience off: bed stops, no bed, call or loop for 10 min")
	commands.ambience.func("ana", "on")
	run(2)
	check(#plays_to("ana", is_bed) == 1, "R ambience on: the bed returns at once")
	-- calls: none in the meadows, rare thunder on a dragon island
	timeofday = 0.95
	sounds = {}
	run(1800)
	check(#plays_to("ana", function(s) return s.ephemeral end) == 0, "R no calls in the meadows")
	mood.ana = "dragon_island"
	run(1800)
	local calls = plays_to("ana", function(s) return s.ephemeral end)
	local spread_ok = #calls >= 6 and #calls <= 22
	for _, s in ipairs(calls) do
		if not s.params.pos or s.spec.name ~= "grug_ambience_call_thunder" then spread_ok = false end
	end
	check(spread_ok, "R thunder on a dragon island: positional, minutes apart (" .. #calls .. " in 30 min)")
	mood.ana = "underground"
	sounds = {}
	run(1800)
	check(#plays_to("ana", function(s) return s.ephemeral end) == 0, "R no thunder in the underground mood")
	players.ana = nil
	for _, fn in ipairs(leaves) do fn(ana) end
end

-- ---------------------------------------------------------------------------
-- F  files and data integrity
-- ---------------------------------------------------------------------------
do
	for capital, rotation in pairs(D.rotations) do
		for _, id in ipairs(rotation) do
			check(D.tracks[id] ~= nil, "F rotation " .. capital .. " track " .. id)
		end
	end
	for key, row in pairs(D.region) do
		check(D.beds[row.day] ~= nil and (not row.night or D.beds[row.night] ~= nil),
			"F region " .. key .. " beds exist")
	end
	for biome, group in pairs(D.groups) do
		check(D.region[group] ~= nil, "F group " .. group .. " of " .. biome .. " has a row")
	end
	for mood in pairs(D.overrides) do check(D.region[mood] ~= nil, "F override " .. mood .. " has a row") end
	for id, call in pairs(D.calls) do
		check(call.distance[1] >= 8 and call.distance[2] >= call.distance[1], "F call " .. id .. " distance")
	end
	check(D.call_gap[1] >= 5, "F calls never more often than every few seconds")
	for _, name in pairs(D.emitter_nodes) do check(D.emitters[name] ~= nil, "F emitter kind " .. name) end

	-- shipped files
	local function ls(path)
		local handle, out = io.popen('ls "' .. path .. '" 2>/dev/null'), {}
		for line in handle:lines() do out[#out + 1] = line end
		handle:close()
		return out
	end
	local oggs = {}
	for _, dir in ipairs({"sounds", "music"}) do
		for _, file in ipairs(ls(MOD .. "/" .. dir)) do
			if file:match("%.ogg$") then oggs[#oggs + 1] = file end
		end
	end
	for _, file in ipairs(ls(repo .. "/menu")) do
		if file:match("%.ogg$") then oggs[#oggs + 1] = file end
	end
	local approved = {}
	local list = io.open(repo .. "/tools/r34_s2/approved.txt")
	if list then
		for line in list:lines() do
			local file = line:match("^%s*([^,%s#][^,%s]*)")
			if file then approved[file] = true end
		end
		list:close()
	end
	for _, file in ipairs(oggs) do
		check(approved[file] == true, "F shipped file not approved: " .. file)
	end
	if list then
		local shipped = {}
		for _, file in ipairs(oggs) do
			shipped[(file:match("^(.-)%.%d%.ogg$") or file:match("^(.-)%.ogg$"))] = true
		end
		for name in pairs(AVAILABLE) do
			check(shipped[name] == true, "F data name not shipped: " .. name)
		end
		for id, track in pairs(D.tracks) do
			check(shipped[track.file:match("^(.-)%.ogg$")] == true, "F track not shipped: " .. id)
		end
	end
	local menu = io.open(repo .. "/menu/theme.ogg", "rb")
	local twin = io.open(MOD .. "/music/grug_music_fantasy_orchestral_theme.ogg", "rb")
	if menu and twin then
		check(menu:read("*a") == twin:read("*a"), "F menu/theme.ogg is the same cut as the M6 track")
	end
	if menu then menu:close() end
	if twin then twin:close() end
	print(("R34 S2 files: %d shipped .ogg, approved list %s"):format(#oggs,
		list and "present" or "absent (phase 1: no file may ship)"))
end

if #failures > 0 then
	for _, f in ipairs(failures) do print("FAIL " .. f) end
	print(("R34 S2 PORTABLE FAIL %d/%d"):format(#failures, checks))
	os.exit(1)
end
print("R34 S2 PORTABLE PASS checks=" .. checks)
