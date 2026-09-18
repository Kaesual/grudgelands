-- R8-MOB1 package 1 KAT: load the final production roster, derive the 38
-- closed zone palettes from world_zones.md Section 8, and compare the exact
-- day/night casts after each mob's production spawn check at band midpoints.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"clock KAT requires an absolute repository root")

	local current = {zone = nil, race = nil, level = 1, time = 0.5}
	local mob_defs, spawn_rows = {}, {}
	local storage = {
		get_string = function() return "" end,
		set_string = function() end,
		get_int = function() return 0 end,
		set_int = function() end,
	}
	local engine = {
		registered_entities = {},
		registered_nodes = {
			["grug_nodes:camp_fire"] = {},
			["grug_nodes:guard_banner"] = {},
		},
		registered_items = {}, registered_aliases = {},
		settings = {get_bool = function() return false end},
	}
	function engine.get_current_modname() return "grug_mobs" end
	function engine.get_modpath(name)
		return root .. "/mods/ENTITIES/" .. tostring(name)
	end
	function engine.get_mod_storage() return storage end
	function engine.get_translator() return function(value) return value end end
	function engine.get_timeofday() return current.time end
	function engine.get_gametime() return 0 end
	function engine.get_us_time() return 0 end
	function engine.item_eat() return function() end end
	function engine.register_craftitem(name, def) engine.registered_items[name] = def end
	function engine.register_node(name, def) engine.registered_nodes[name] = def end
	function engine.override_item(name, def)
		local target = assert(engine.registered_nodes[name], "missing override target " .. name)
		for key, value in pairs(def) do target[key] = value end
	end
	function engine.register_alias(name, target) engine.registered_aliases[name] = target end
	function engine.register_entity(name, def) engine.registered_entities[name] = def end
	function engine.register_lbm() end
	function engine.register_globalstep() end
	function engine.register_on_leaveplayer() end
	function engine.register_on_shutdown() end
	function engine.register_on_mods_loaded() end
	function engine.register_on_joinplayer() end
	function engine.register_on_dignode() end
	function engine.register_on_player_hpchange() end
	function engine.register_on_dieplayer() end
	function engine.after() end
	function engine.chat_send_player() end
	function engine.colorize(_, value) return value end
	function engine.is_player() return false end
	function engine.get_connected_players() return {} end
	function engine.get_node()
		if current.check_name == "grug_mobs:skeleton_archer" then
			return {name = "grug_nodes:dirt_with_bone_litter"}
		end
		return {name = "grug_nodes:dirt_with_grass"}
	end
	function engine.get_node_or_nil() return {name = "air"} end
	function engine.get_objects_inside_radius() return {} end
	function engine.find_nodes_in_area() return {} end
	function engine.find_node_near() return nil end
	function engine.get_meta()
		return {get_int = function() return 0 end, get_string = function() return "" end,
			set_int = function() end, set_string = function() end}
	end
	function engine.get_node_timer()
		return {is_started = function() return false end, start = function() end}
	end
	function engine.add_particlespawner() end
	function engine.sound_play() end
	function engine.pos_to_string() return "(0,0,0)" end
	function engine.log() end
	function engine.global_exists() return false end

	local mobs_api = {mob_class = {}}
	function mobs_api.register_mob(_, name, def)
		mob_defs[name] = def
		engine.registered_entities[name] = def
	end
	function mobs_api.spawn(_, def) spawn_rows[#spawn_rows + 1] = def end
	function mobs_api.register_arrow(_, name, def) engine.registered_entities[name] = def end
	function mobs_api.add_mob() return nil end
	function mobs_api.add_eatable() end

	local starts = {}
	for index = 1, 6 do
		starts[index] = {race_id = ({"dwarf", "human", "elf", "undead", "orc", "troll"})[index],
			faction_id = index <= 3 and "accord" or "throng",
			anchor = {x = index * 10000, y = 0, z = index * 10000}}
	end
	local zone_api = {
		zone_authority_installed = function() return true end,
		get_player_faction = function() return "accord" end,
		get_race_perk = function() return nil end,
		register_on_effective_heal = function() end,
		register_on_effective_absorb = function() end,
		register_on_player_hit_mob = function() end,
		start_identities = function() return starts end,
		outpost_at = function() return nil end,
		rare_route = function()
			return {{x = 0, z = 0}, {x = 1, z = 1}, {x = 2, z = 2}}
		end,
		opposing_faction = function(value)
			return value == "accord" and "throng" or "accord"
		end,
		mob_level_at = function() return current.level end,
		guard_level_at = function() return current.level end,
	}
	local zones = {
		id_at = function() return current.zone end,
		biome_at = function() return current.race == "undead" and "grug_blight" or "grug_meadows" end,
		pvp_rule_at = function() return "peaceful" end,
		faction_at = function()
			if current.race == "dwarf" or current.race == "human" or current.race == "elf" then
				return "accord"
			end
			return "throng"
		end,
		race_region_at = function() return current.race end,
		mob_level_at = function() return current.level end,
		guard_level_at = function() return current.level end,
		water_class_at = function() return "land" end,
	}
	local environment = setmetatable({
		core = engine, minetest = engine, mobs = mobs_api,
		grug_core = zone_api, grug_zones = zones,
		grug_factions = {
			get_object_faction = function() return nil end,
			player_enemy_of = function() return true end,
		},
		grug_xp = {get_level = function() return current.level end,
			add_xp = function() end},
		vector = {
			new = function(x, y, z)
				if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
				return {x = x, y = y, z = z}
			end,
			distance = function() return 0 end,
			offset = function(pos, x, y, z)
				return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
			end,
		},
		ItemStack = function() return {} end,
		PcgRandom = function() return {next = function() return 1 end} end,
		default = {node_sound_gravel_defaults = function() return {} end},
	}, {__index = _G})
	function environment.dofile(path)
		local chunk = assert(loadfile(path))
		setfenv(chunk, environment)
		return chunk()
	end
	local initializer = assert(loadfile(root .. "/mods/ENTITIES/grug_mobs/init.lua"))
	setfenv(initializer, environment)
	initializer()
	local production = assert(environment.grug_mobs)
	assert(next(mob_defs) ~= nil and #spawn_rows > 25,
		"final production mob registrations were not loaded")

	-- Row stamping is part of the clock contract, including the underground
	-- exception and exact ceil(1.25 * AOC) night density.
	local day = production.prepare_spawn_row({name = "grug_mobs:boar",
		min_light = 1, max_light = 15, day_toggle = false,
		active_object_count = 5, max_height = 200})
	assert(day.min_light == 10 and day.max_light == nil and day.day_toggle == nil and
		day.active_object_count == 5)
	local night = production.prepare_spawn_row({name = "grug_mobs:giant_spider",
		min_light = 10, active_object_count = 4, max_height = 200})
	assert(night.min_light == nil and night.max_light == 5 and
		night.day_toggle == false and night.active_object_count == 5)
	local rounded = production.prepare_spawn_row({name = "grug_mobs:skeleton_archer",
		active_object_count = 3, max_height = 200})
	assert(rounded.active_object_count == 4)
	local cave = production.prepare_spawn_row({name = "grug_mobs:giant_spider",
		max_light = 5, day_toggle = false, active_object_count = 4, max_height = -40})
	assert(cave.max_light == 5 and cave.day_toggle == nil and cave.active_object_count == 4)

	local function trim(value)
		return (value:gsub("^%s+", ""):gsub("%s+$", ""))
	end
	local function fields(line)
		local result = {}
		for value in (line .. "|"):gmatch("|([^|]*)") do
			result[#result + 1] = trim(value)
		end
		return result
	end
	local doc = assert(io.open(root .. "/docs/design/world_zones.md", "rb"))
	local source = assert(doc:read("*a"))
	doc:close()
	local catalog = {}
	local inside = false
	for line in (source .. "\n"):gmatch("([^\n]*)\n") do
		if line == "### 8.1 Elandor — Accord" then inside = true end
		if line == "### 8.4 Binding relief and landmark assignment" then inside = false end
		if inside and line:match("^| `%l") then
			local row = fields(line)
			local zone_id = row[1] and row[1]:match("^`([^`]+)`$")
			if zone_id then
				local low, high = row[4]:match("(%d+)%D+(%d+)")
				if not low then low = row[4]:match("(%d+)"); high = low end
				catalog[#catalog + 1] = {id = zone_id,
					race = row[3]:lower(), low = assert(tonumber(low)),
					high = assert(tonumber(high)), text = row[6]}
			end
		end
	end
	assert(#catalog == 38, "Section 8 zone parser did not find all 38 zones")

	-- This table is the family meaning of Section 8's generic palette words;
	-- it is deliberately independent of spawn_policy.lua's transcription.
	local family_palettes = {
		["grug_mobs:boar"] = {settled = true},
		["grug_mobs:plague_boar"] = {settled = true},
		["grug_mobs:jungle_boar"] = {settled = true},
		["grug_mobs:rabbit"] = {settled = true},
		["grug_mobs:hare"] = {settled = true},
		["grug_mobs:zombie"] = {settled = true, war = true},
		["grug_mobs:wolf"] = {forest = true},
		["grug_mobs:blightfang_wolf"] = {forest = true},
		["grug_mobs:bear"] = {forest = true},
		["grug_mobs:plaguehide_bear"] = {forest = true},
		["grug_mobs:stag"] = {forest = true},
		["grug_mobs:gaunt_stag"] = {forest = true},
		["grug_mobs:giant_spider"] = {forest = true},
		["grug_mobs:pale_spider"] = {forest = true},
		["grug_mobs:skeleton_archer"] = {forest = true, war = true},
		["grug_mobs:bone_weevil"] = {forest = true},
		["grug_mobs:crag_eagle"] = {mountain = true},
		["grug_mobs:vulture"] = {mountain = true},
		["grug_mobs:stone_golem"] = {mountain = true},
		["grug_mobs:mesa_golem"] = {mountain = true},
		["grug_mobs:mountain_ram"] = {mountain = true},
		["grug_mobs:hyena"] = {mountain = true, savanna = true},
		["grug_mobs:zebra"] = {savanna = true},
		["grug_mobs:jungle_lynx"] = {jungle_edge = true, jungle = true},
		["grug_mobs:panther"] = {jungle = true},
		["grug_mobs:serpent"] = {jungle = true},
		["grug_mobs:jungle_ape"] = {jungle = true},
		["grug_mobs:jungle_spider"] = {jungle = true},
		["grug_mobs:parrot"] = {jungle_edge = true},
		["grug_mobs:crocodile"] = {swamp = true},
		["grug_mobs:bog_ooze"] = {swamp = true},
		["grug_mobs:bog_fowl"] = {swamp = true},
		["grug_mobs:skeleton_raider"] = {war = true},
		["grug_mobs:carrion_crow"] = {war = true},
	}
	local clocks = {
		boar = "day", plague_boar = "day", jungle_boar = "day", rabbit = "day", hare = "day",
		zombie = {settled = "night", war = "night", blight = "any"},
		wolf = "any", blightfang_wolf = "any", bear = "day", plaguehide_bear = "day",
		stag = "day", gaunt_stag = "day", giant_spider = "night", pale_spider = "night",
		skeleton_archer = "night", bone_weevil = "day", crag_eagle = "day", vulture = "day",
		stone_golem = "any", mesa_golem = "any", mountain_ram = "day", hyena = "any",
		zebra = "day", jungle_lynx = "day", panther = "night", serpent = "day",
		jungle_ape = "day", jungle_spider = "night", parrot = "day", crocodile = "any",
		bog_ooze = "any", bog_fowl = "day", skeleton_raider = "night", carrion_crow = "any",
		poacher = "night", frost_stray = "night", sun_dried_husk = "night", song_bird = "day",
		fox = "day", ibex = "day", wild_turkey = "day", plains_runner = "day", tapir = "day",
		giant_rat = "night", scorpion = "night", viper = "night", goblin_raider = "night",
		goblin_slinger = "night", goblin_hound = "night", snow_leopard = "night", wisp = "night",
		ashen_treant = "night", gravewood_treant = "night",
	}
	local explicit = {
		Fox = "fox", Ibex = "ibex", ["Wild Turkey"] = "wild_turkey",
		["Plains Runner"] = "plains_runner", Tapir = "tapir", ["Giant Rat"] = "giant_rat",
		Scorpion = "scorpion", Viper = "viper", Poacher = "poacher",
		["Frost Stray"] = "frost_stray", ["Sun-Dried Husk"] = "sun_dried_husk",
		["Song Bird"] = "song_bird", ["Snow Leopard"] = "snow_leopard", Wisp = "wisp",
		["Ashen Treant"] = "ashen_treant", ["Gravewood Treant"] = "gravewood_treant",
	}
	local fallbacks = {settled = "zombie", war = "zombie", forest = "skeleton_archer",
		mountain = "skeleton_archer", jungle = "jungle_spider", swamp = "bog_ooze"}
	local cultural_races = {
		rabbit = {dwarf = true, human = true, elf = true},
		hare = {undead = true, orc = true, troll = true},
		stone_golem = {dwarf = true, human = true, elf = true},
		mesa_golem = {undead = true, orc = true, troll = true},
	}
	local function culture_allows(short, race)
		local races = cultural_races[short]
		return not races or races[race] == true
	end
	local function add(result, short)
		result["grug_mobs:" .. short] = true
	end
	local function palette_words(text)
		local result = {}
		if text:find("settled", 1, true) then result.settled = true end
		if text:find("forest mobs", 1, true) or text:find("forest/war mobs", 1, true) or
				text:find("forest and lower%-jungle mobs") then result.forest = true end
		if text:find("mountain mobs", 1, true) or text:find("mountain/war mobs", 1, true) then result.mountain = true end
		if text:find("savanna mobs", 1, true) or text:find("savanna/mountain mobs", 1, true) then result.savanna = true end
		if text:find("jungle-edge", 1, true) then result.jungle_edge = true end
		if text:find("jungle mobs", 1, true) or text:find("jungle/war", 1, true) then result.jungle = true end
		if text:find("swamp mobs", 1, true) or text:find("swamp mobs", 1, true) then result.swamp = true end
		if text:find("war mobs", 1, true) or text:find("forest/war", 1, true) or
				text:find("mountain/war", 1, true) or text:find("jungle/war", 1, true) then result.war = true end
		return result
	end
	local function clock_for(short, palette)
		local value = assert(clocks[short], "missing expected clock for " .. short)
		if type(value) == "table" then
			return value[palette]
		end
		return value
	end
	local function band_min(text, label)
		if text:find("band-2 " .. label, 1, true) or
				text:find(label .. " from band 2", 1, true) or
				text:find("Fox/Ibex from band 2", 1, true) and (label == "Fox" or label == "Ibex") then
			return 2
		end
		if text:find("band-3 " .. label, 1, true) then return 3 end
		return 1
	end
	local function expected_cast(zone, band, wanted_clock)
		if zone.text:find("no ambient hostiles", 1, true) then return {} end
		local palettes, result = palette_words(zone.text), {}
		for name, mob_palettes in pairs(family_palettes) do
			for palette in pairs(mob_palettes) do
				if palettes[palette] then
					local short = name:match(":(.+)$")
					local role = clock_for(short, palette)
					if culture_allows(short, zone.race) and
							(role == wanted_clock or role == "any") then
						result[name] = true
					end
					break
				end
			end
		end
		if zone.text:find("remembered for pale stags", 1, true) and wanted_clock == "day" then
			add(result, "stag")
		end
		for label, short in pairs(explicit) do
			if zone.text:find(label, 1, true) and band >= band_min(zone.text, label) then
				local role = clock_for(short, nil)
				if role == wanted_clock or role == "any" then add(result, short) end
			end
		end
		if zone.text:find("Goblin Raid", 1, true) and wanted_clock == "night" then
			add(result, "goblin_raider"); add(result, "goblin_slinger"); add(result, "goblin_hound")
		end
		if wanted_clock == "night" then
			local night_count = 0
			for name, mob_palettes in pairs(family_palettes) do
				for palette in pairs(mob_palettes) do
					if palettes[palette] and clock_for(name:match(":(.+)$"), palette) == "night" then
						night_count = night_count + 1; break
					end
				end
			end
			for _, short in pairs(explicit) do
				if result["grug_mobs:" .. short] and clock_for(short, nil) == "night" then
					night_count = night_count + 1
				end
			end
			if zone.text:find("Goblin Raid", 1, true) then night_count = night_count + 3 end
			for palette, short in pairs(fallbacks) do
				if palettes[palette] and night_count < 2 then add(result, short) end
			end
			if zone.text:find("remembered for pale stags", 1, true) and night_count < 2 then
				add(result, "skeleton_archer")
			end
		end
		return result
	end
	local function checked_cast(zone, clock)
		local list = assert(production.zone_clock_cast(zone.id, clock), "missing production zone " .. zone.id)
		local result, pos = {}, {x = 500, y = 1, z = 500}
		for index = 1, #list do
			local name = list[index]
			local check = mob_defs[name] and mob_defs[name]._grug_spawn_check
			current.check_name = name
			if not check or check(pos) then result[name] = true end
		end
		current.check_name = nil
		return result
	end
	local function digest(set)
		local values = {}
		for name in pairs(set) do values[#values + 1] = name end
		table.sort(values)
		return table.concat(values, ",")
	end

	local comparisons = 0
	for index = 1, #catalog do
		local zone = catalog[index]
		current.zone, current.race = zone.id, zone.race
		for band = 1, 3 do
			current.level = math.floor(zone.low + (zone.high - zone.low) * (band * 2 - 1) / 6)
			for _, clock in ipairs({"day", "night"}) do
				local expected = expected_cast(zone, band, clock)
				local actual = checked_cast(zone, clock)
				assert(digest(actual) == digest(expected), zone.id .. " band " .. band .. " " .. clock ..
					" cast differs\nexpected=" .. digest(expected) .. "\nactual=" .. digest(actual))
				comparisons = comparisons + 1
			end
		end
	end
	assert(comparisons == 228)

	current.zone, current.race, current.level = "elandor_hearthpine_vale", "dwarf", 5
	current.time = 0.5
	assert(production.spawn_clock_allows("grug_mobs:boar", {x = 500, y = 1, z = 500}))
	assert(not production.spawn_clock_allows("grug_mobs:giant_rat", {x = 500, y = 1, z = 500}))
	current.time = 0.9
	assert(not production.spawn_clock_allows("grug_mobs:boar", {x = 500, y = 1, z = 500}))
	assert(production.spawn_clock_allows("grug_mobs:giant_rat", {x = 500, y = 1, z = 500}))
	assert(production.spawn_clock_allows("grug_mobs:giant_spider", {x = 500, y = -100, z = 500}))
	current.zone, current.race, current.time = "kragmar_stillgrave_hollow", "undead", 0.5
	assert(production.spawn_clock_allows("grug_mobs:zombie", {x = 500, y = 1, z = 500}),
		"blight Zombie lost its any-clock exception")

	return "r8_mob1_clock_v3|zones=38|band_casts=228|production_roles=1|" ..
		"doc_band_oracle=1|doc_palettes=1|night_factor=5/4\n"
end
