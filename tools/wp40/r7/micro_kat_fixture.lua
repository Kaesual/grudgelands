-- Compact production-seam fixture for the final R7 LuaJIT/PUC parity gate.
-- It deliberately parses no MTS file and uses no LuaJIT-only facility.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local rows = {}
	local changed_order, changed_set, executed = {}, {}, {}
	local saved_dofile = dofile

	local function fail(message)
		error("WP40 R7 micro KAT: " .. message, 0)
	end

	local function check(value, message)
		if not value then fail(message) end
		return value
	end

	local function row(id, value)
		rows[#rows + 1] = id .. "\t" .. tostring(value) .. "\n"
	end

	local function hex_sha256(bytes)
		return common.hex(raw_sha256(bytes))
	end

	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[copy(key)] = copy(child) end
		return result
	end

	local function less_bytes(left, right)
		return common.less_bytes(left, right)
	end

	local function scalar(value)
		local kind = type(value)
		if kind == "string" then return "s" .. tostring(#value) .. ":" .. value end
		if kind == "boolean" then return value and "b1;" or "b0;" end
		if kind == "number" and value == value and value ~= math.huge and
				value ~= -math.huge and value % 1 == 0 and
				math.abs(value) <= 9007199254740991 then
			return "n" .. string.format("%.0f", value) .. ";"
		end
		fail("unsupported canonical scalar")
	end

	local function graph(value, active)
		if type(value) ~= "table" then return scalar(value) end
		if getmetatable(value) ~= nil then fail("canonical graph has a metatable") end
		active = active or {}
		if active[value] then fail("canonical graph is cyclic") end
		active[value] = true
		local count, key_count, array = #value, 0, true
		for key in pairs(value) do
			key_count = key_count + 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				array = false
			end
		end
		if key_count ~= count then array = false end
		local result = {}
		if array then
			result[1] = "a" .. tostring(count) .. "["
			for index = 1, count do
				result[#result + 1] = graph(value[index], active)
			end
			result[#result + 1] = "]"
		else
			local entries = {}
			for key, child in pairs(value) do
				entries[#entries + 1] = graph(key, active) .. graph(child, active)
			end
			table.sort(entries, less_bytes)
			result[1] = "m" .. tostring(#entries) .. "{"
			for index = 1, #entries do result[#result + 1] = entries[index] end
			result[#result + 1] = "}"
		end
		active[value] = nil
		return table.concat(result)
	end

	local function expect_failure(callback, fragment)
		local ok, message = pcall(callback)
		check(not ok and type(message) == "string" and
			message:find(fragment, 1, true),
			"expected failure did not contain " .. fragment)
	end

	local function repo_relative(path)
		local prefix = repo .. "/"
		if type(path) == "string" and path:sub(1, #prefix) == prefix then
			return path:sub(#prefix + 1)
		end
		return nil
	end

	local function mark_executed(path)
		local relative = repo_relative(path)
		if relative and changed_set[relative] then
			executed[relative] = (executed[relative] or 0) + 1
		end
	end

	local function tracking_dofile(path)
		local function mark_return(...)
			mark_executed(path)
			return ...
		end
		return mark_return(saved_dofile(path))
	end

	-- Track successful top-level execution, including authentic transitive
	-- dofile loads.  Compilation alone is deliberately not execution evidence.
	rawset(_G, "dofile", tracking_dofile)

	local changed_file = assert(io.open(repo ..
		"/tools/wp40/r7/changed_production_lua.txt", "rb"))
	local changed_count, changed_rows, previous = 0, {}, nil
	for relative in changed_file:lines() do
		check(relative ~= "" and (not previous or less_bytes(previous, relative)),
			"changed production Lua roster order differs")
		local chunk = assert(loadfile(repo .. "/" .. relative))
		check(type(chunk) == "function", "changed production Lua did not compile")
		changed_count = changed_count + 1
		changed_order[changed_count] = relative
		changed_set[relative] = true
		changed_rows[#changed_rows + 1] = relative .. "\t" ..
			hex_sha256(common.read_file(repo .. "/" .. relative)) .. "\n"
		previous = relative
	end
	assert(changed_file:close())
	check(changed_count == 71, "changed production Lua population differs")
	row("source/changed_production_lua_count", changed_count)
	row("source/changed_production_lua_sha256",
		hex_sha256(table.concat(changed_rows)))

	row("schema", "grug_wp40_r7_micro_kat_v1")

	-- Drive the real r7_runtime factory and build control flow through exact
	-- live-setting validation and the complete assembly/manifest/evidence-mode
	-- sequence.  Its heavyweight collaborators are closed stubs here; the real
	-- writer/successor transaction below exercises the material data path.
	do
	local runtime_calls = {constructor = 0, manifest_new = 0,
		manifest_validate = 0, content = 0, payload = 0}
	local runtime_session, runtime_writer, runtime_zones = {}, {}, {}
	local runtime_roster = {schema = "grug_wp40_r7_anchor_roster_v1",
		sha256 = string.rep("8", 64), copy_rows = function() return {} end, rows = {}}
	local runtime_successor_tail = {probe_reason = function() return "accepted" end,
		anchor_roster = function() return runtime_roster end}
	local runtime_identity = {schema = "grug_wp40_r6_private_identity_v1",
		template_records = {}, planner_fixture = {}, planner_source = {
			column_values_at = function() end}, successor_tail = runtime_successor_tail}
	local runtime_fixture_stub = {scan_horizontal_owner = function()
		return {schema = "micro_scan"}
	end}
	local function runtime_constructor()
		runtime_calls.constructor = runtime_calls.constructor + 1
		return runtime_session, runtime_writer, runtime_zones,
			runtime_fixture_stub, runtime_identity
	end
	local runtime_r6_module = {new = runtime_constructor,
		new_capture = runtime_constructor, new_evidence = runtime_constructor}
	local runtime_content_set = {
		production = {schema = "grug_wp40_r7_production_r6_content_v1"},
		p9g = {schema = "grug_wp40_r7_p9g_content_v1"},
		production_digest = string.rep("1", 64),
		production_semantic_digest = string.rep("2", 64),
		p9g_digest = string.rep("3", 64), p9g_semantic_digest = string.rep("4", 64),
		anchors = {schema = "grug_wp40_r7_anchor_content_v1"},
		anchor_digest = string.rep("9", 64),
		anchor_semantic_digest = string.rep("a", 64),
		accepted_r6_rows = function() return {} end,
	}
	local runtime_manifest_module = {}
	function runtime_manifest_module.new()
		runtime_calls.manifest_new = runtime_calls.manifest_new + 1
		return {schema = "micro_manifest", sha256 = string.rep("5", 64)}
	end
	function runtime_manifest_module.validate(value)
		runtime_calls.manifest_validate = runtime_calls.manifest_validate + 1
		check(value.schema == "micro_manifest", "runtime manifest seam differs")
		return true
	end
	local runtime_r6_manifest = {schema = "micro_r6_manifest",
		r5_manifest_values = {}}
	local function runtime_stub_dofile(path)
		if path:match("/source/catalog%.lua$") then return {} end
		if path:match("/source/simple_map%.lua$") then return {} end
		if path:match("/r6%.lua$") then
			return function() return runtime_r6_module end
		end
		if path:match("/r7_content%.lua$") then
			return function()
				runtime_calls.content = runtime_calls.content + 1
				return runtime_content_set
			end
		end
		if path:match("/r7_consumer_payload%.lua$") then
			return function()
				runtime_calls.payload = runtime_calls.payload + 1
				return {schema = "micro_payload", sha256 = string.rep("6", 64)}
			end
		end
		if path:match("/r7_manifest%.lua$") then
			return function() return runtime_manifest_module end
		end
		if path:match("/r7_p9g%.lua$") then
			return function() return {schema = "grug_wp40_r7_successor_config_v1"} end
		end
		if path:match("/r7_anchor_roster%.lua$") then
			return function() return runtime_roster end
		end
		if path:match("/r7_anchor_activation%.lua$") then
			return function() return {schema = "micro_anchor_config"} end
		end
		if path:match("/r7_successor%.lua$") then
			return function() return {schema = "grug_wp40_r7_successor_config_v1"} end
		end
		if path:match("/r7_zone_overlay%.lua$") then
			return function(session) return session end
		end
		if path:match("/r7_r6_manifest%.lua$") then
			return function() return runtime_r6_manifest end
		end
		if path:match("/r7_template_source%.lua$") then
			return function() return {} end
		end
		return {}
	end
	local runtime_environment = setmetatable({dofile = runtime_stub_dofile},
		{__index = _G})
	local runtime_chunk = assert(loadfile(wp40 .. "/r7_runtime.lua"))
	setfenv(runtime_chunk, runtime_environment)
	local runtime_factory = runtime_chunk()
	mark_executed(wp40 .. "/r7_runtime.lua")
	local runtime_settings = {
		mg_name = "v7", water_level = "1", mapgen_limit = "31007",
		chunksize = "5", mgv7_dungeon_ymin = "-31000",
		mgv7_dungeon_ymax = "-193",
		mg_flags = "biomes,caves,decorations,dungeons,light,ores",
		mgv7_spflags = "mountains,ridges,caverns,nofloatlands", seed = "0",
	}
	local runtime_settings_proxy = newproxy(true)
	local runtime_core = {settings = runtime_settings_proxy}
	function runtime_core.sha256(bytes, raw)
		local digest = raw_sha256(bytes)
		return raw and digest or hex_sha256(bytes)
	end
	function runtime_core.get_mapgen_setting(name) return runtime_settings[name] end
	getmetatable(runtime_settings_proxy).__index = {
		get = function(_, name)
			return name == "num_emerge_threads" and "1" or nil
		end,
	}
	local runtime_catalog = {}
	function runtime_catalog.cultural_registrations() return {} end
	function runtime_catalog.manifest()
		return {schema = "micro_gathering_manifest", sha256 = string.rep("7", 64)}
	end
	local runtime_module = runtime_factory(runtime_core, wp40,
		repo .. "/mods/BASE/default/schematics", {}, runtime_catalog)
	expect_failure(function()
		runtime_module.build({}, nil, "invalid")
	end, "evidence mode differs")
	local runtime_built = runtime_module.build({schema = "micro_native"}, nil, true)
	check(runtime_built.session == runtime_session and
		runtime_built.writer == runtime_writer and
		runtime_built.zones_session == runtime_zones and
		type(runtime_built.evidence) == "table" and
		runtime_calls.constructor == 2 and runtime_calls.content == 1 and
		runtime_calls.payload == 1 and runtime_calls.manifest_new == 1 and
		runtime_calls.manifest_validate == 1,
		"bounded r7_runtime assembly control flow differs")
	row("runtime/bounded_build", table.concat({runtime_calls.constructor,
		runtime_calls.content, runtime_calls.payload, runtime_calls.manifest_new,
		runtime_calls.manifest_validate}, "/"))
	end

	local function execute_in_environment(relative, environment)
		local path = repo .. "/" .. relative
		local chunk = assert(loadfile(path))
		setfenv(chunk, environment)
		local function mark_return(...)
			mark_executed(path)
			return ...
		end
		return mark_return(chunk())
	end

	-- Pure changed factories still execute as chunks even where their returned
	-- closures are exercised elsewhere in this fixture.
	for _, relative in ipairs({
		"mods/MAPGEN/grug_mapgen/wp40/r6.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6_content.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_anchor_activation.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_anchor_roster.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_consumer_payload.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua", -- replaced below by full env run
		"mods/MAPGEN/grug_mapgen/wp40/r7_successor.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_template_source.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r7_zone_overlay.lua",
	}) do
		if not relative:match("r7_mapgen%.lua$") then tracking_dofile(repo .. "/" .. relative) end
	end

	-- Core initializer: changed authority/protection are materially exercised
	-- below; the remaining children are closed here so the changed top-level
	-- initialization order itself is executable without a game runtime.
	do
	local core_init_environment = setmetatable({core = {
		get_current_modname = function() return "grug_core" end,
		get_modpath = function() return repo .. "/mods/CORE/grug_core" end,
	}}, {__index = _G})
	core_init_environment.dofile = function() return nil end
	execute_in_environment("mods/CORE/grug_core/init.lua", core_init_environment)
	check(type(core_init_environment.grug_core) == "table" and
		core_init_environment.grug_core.opposing_faction("accord") == "throng",
		"grug_core initializer projection differs")
	end

	-- The vendored default mapgen top-level must register aliases but, under the
	-- exact v7 setting, must execute no legacy ore/deco registration branch.
	do
	local alias_count = 0
	local default_environment = setmetatable({default = {}, minetest = {
		register_alias = function() alias_count = alias_count + 1 end,
		get_mapgen_setting = function(name)
			return name == "mg_name" and "v7" or nil
		end,
	}}, {__index = _G})
	execute_in_environment("mods/BASE/default/mapgen.lua", default_environment)
	check(alias_count > 20, "default mapgen alias registration differs")
	row("registration/default_alias_count", alias_count)
	end

	-- Load the complete changed mob roster through the authentic grug_mobs
	-- initializer. Engine writes are replaced with closed registration sinks;
	-- definitions and spawn rows are projected at their real registration seam.
	do
	local mob_defs, spawn_rows, arrow_rows, callback_count = {}, {}, {}, 0
	local storage = {get_string = function() return "" end,
		set_string = function() end, get_int = function() return 0 end,
		set_int = function() end}
	local mob_core = {registered_entities = {},
		registered_nodes = {["grug_nodes:camp_fire"] = {base = true},
			["grug_nodes:guard_banner"] = {base = true}},
		registered_items = {}, registered_aliases = {},
		settings = {get_bool = function() return false end}}
	function mob_core.get_current_modname() return "grug_mobs" end
	function mob_core.get_modpath(name)
		if name == "grug_mobs" then return repo .. "/mods/ENTITIES/grug_mobs" end
		return repo .. "/mods/ENTITIES/" .. tostring(name)
	end
	function mob_core.get_mod_storage() return storage end
	function mob_core.get_translator() return function(value) return value end end
	function mob_core.get_timeofday() return 0.5 end
	function mob_core.get_gametime() return 0 end
	function mob_core.get_us_time() return 0 end
	function mob_core.item_eat() return function() end end
	function mob_core.register_craftitem(name, definition)
		mob_core.registered_items[name] = definition
	end
	function mob_core.register_node(name, definition)
		mob_core.registered_nodes[name] = definition
	end
	function mob_core.override_item(name, definition)
		local target = check(mob_core.registered_nodes[name], "mob override target differs")
		for key, value in pairs(definition) do target[key] = value end
	end
	function mob_core.register_alias(name, target)
		mob_core.registered_aliases[name] = target
	end
	function mob_core.register_lbm() callback_count = callback_count + 1 end
	function mob_core.register_globalstep() callback_count = callback_count + 1 end
	function mob_core.register_on_leaveplayer() callback_count = callback_count + 1 end
	function mob_core.register_on_shutdown() callback_count = callback_count + 1 end
	function mob_core.register_on_mods_loaded() callback_count = callback_count + 1 end
	function mob_core.register_on_joinplayer() callback_count = callback_count + 1 end
	function mob_core.register_on_dignode() callback_count = callback_count + 1 end
	function mob_core.register_entity(name, definition)
		mob_core.registered_entities[name] = definition
	end
	function mob_core.after() end
	function mob_core.chat_send_player() end
	function mob_core.colorize(_, value) return value end
	function mob_core.is_player() return false end
	function mob_core.get_connected_players() return {} end
	function mob_core.get_node() return {name = "air"} end
	function mob_core.get_node_or_nil() return {name = "air"} end
	function mob_core.get_objects_inside_radius() return {} end
	function mob_core.find_nodes_in_area() return {} end
	function mob_core.find_node_near() return nil end
	local banner_meta_values = {}
	local banner_meta = {}
	function banner_meta:get_int(key) return banner_meta_values[key] or 0 end
	function banner_meta:get_string(key) return banner_meta_values[key] or "" end
	function banner_meta:set_int(key, value) banner_meta_values[key] = value end
	function banner_meta:set_string(key, value) banner_meta_values[key] = value end
	local banner_timer = {is_started = function() return false end,
		start = function() end}
	function mob_core.get_meta() return banner_meta end
	function mob_core.get_node_timer() return banner_timer end
	function mob_core.add_particlespawner() end
	function mob_core.sound_play() end
	function mob_core.pos_to_string() return "(0,0,0)" end
	function mob_core.log() end
	local mobs_api = {}
	function mobs_api.register_mob(_, name, definition)
		mob_defs[#mob_defs + 1] = {name = name, definition = definition}
		mob_core.registered_entities[name] = definition
	end
	function mobs_api.spawn(_, definition) spawn_rows[#spawn_rows + 1] = definition end
	function mobs_api.register_arrow(_, name, definition)
		arrow_rows[#arrow_rows + 1] = {name = name, definition = definition}
	end
	function mobs_api.add_mob() return nil end
	function mobs_api.add_eatable() end
	local mob_environment = setmetatable({core = mob_core, minetest = mob_core,
		mobs = mobs_api, grug_core = {
			zone_authority_installed = function() return true end,
			get_player_faction = function() return "accord" end,
			get_race_perk = function() return nil end,
			outpost_at = function(pos)
				return pos.outpost_faction and {faction = pos.outpost_faction} or nil
			end,
			rare_route = function()
				return {{x = 0, z = 0}, {x = 1, z = 1}, {x = 2, z = 2}}
			end,
		}, grug_zones = {faction_at = function(pos) return pos.territory end},
		grug_factions = {get_object_faction = function() return nil end},
		grug_xp = {get_level = function() return 1 end, add_xp = function() end},
		vector = {new = function(x, y, z) return {x = x, y = y, z = z} end,
			distance = function() return 0 end},
		ItemStack = function() return {} end,
		PcgRandom = function() return {next = function() return 1 end} end,
		default = {node_sound_gravel_defaults = function() return {} end},
	}, {__index = _G})
	function mob_environment.dofile(path)
		local chunk = assert(loadfile(path))
		setfenv(chunk, mob_environment)
		local function mark_return(...)
			mark_executed(path)
			return ...
		end
		return mark_return(chunk())
	end
	execute_in_environment("mods/ENTITIES/grug_mobs/init.lua", mob_environment)
	check(#mob_defs >= 35 and #spawn_rows >= 25 and #arrow_rows >= 2,
		"mob definition/spawn registration projection differs")
	check(mob_core.registered_aliases["grug_mobs:camp_fire"] ==
		"grug_nodes:camp_fire" and
		type(mob_core.registered_nodes["grug_nodes:camp_fire"].on_construct) ==
			"function" and
		type(mob_core.registered_nodes["grug_nodes:camp_fire"].on_timer) == "function",
		"camp-fire ownership/behaviour seam differs")
	local banner = mob_core.registered_nodes["grug_nodes:guard_banner"]
	banner.on_construct({outpost_faction = "throng"})
	check(banner_meta_values._grug_camp_type == "guard_throng",
		"contested outpost banner faction differs")
	for key in pairs(banner_meta_values) do banner_meta_values[key] = nil end
	banner.on_construct({territory = "accord"})
	check(banner_meta_values._grug_camp_type == "guard_accord",
		"non-outpost banner territory fallback differs")
	local mob_projection = {}
	for index = 1, #mob_defs do
		local value = mob_defs[index]
		mob_projection[#mob_projection + 1] = "mob\t" .. value.name .. "\t" ..
			tostring(value.definition.type) .. "\t" .. tostring(value.definition.mesh) .. "\n"
	end
	for index = 1, #spawn_rows do
		local value = spawn_rows[index]
		mob_projection[#mob_projection + 1] = "spawn\t" .. tostring(value.name) ..
			"\t" .. tostring(value.interval) .. "\t" .. tostring(value.chance) .. "\n"
	end
	table.sort(mob_projection, less_bytes)
	row("registration/mob_projection_sha256", hex_sha256(table.concat(mob_projection)))
	row("registration/mob_spawn_population",
		table.concat({#mob_defs, #spawn_rows, #arrow_rows, callback_count}, "/"))
	end

	-- Gathering top-level ownership is separate from its real catalog/harvest/
	-- node semantics above; closed children keep the initializer side-effect free.
	do
	local gathering_callbacks = 0
	local gathering_environment = setmetatable({grug_materials = {}, core = {
		get_current_modname = function() return "grug_gathering" end,
		get_modpath = function() return repo .. "/mods/ITEMS/grug_gathering" end,
		sha256 = function(bytes) return hex_sha256(bytes) end,
		register_on_mods_loaded = function() gathering_callbacks = gathering_callbacks + 1 end,
		register_on_leaveplayer = function() gathering_callbacks = gathering_callbacks + 1 end,
		registered_items = {}, registered_nodes = {},
	}}, {__index = _G})
	gathering_environment.dofile = function(path)
		if path:match("/catalog%.lua$") then return tracking_dofile(path) end
		if path:match("/harvest%.lua$") then
			return function() return {register_herb_authorizer = function() end,
				clear_player = function() end} end
		end
		if path:match("/nodes%.lua$") then
			return function()
				local result = {}
				for index = 1, 18 do result[index] = "micro:source_" .. index end
				return result
			end
		end
		error("unexpected gathering initializer dependency", 0)
	end
	execute_in_environment("mods/ITEMS/grug_gathering/init.lua", gathering_environment)
	check(type(gathering_environment.grug_gathering) == "table" and
		gathering_callbacks == 2, "gathering initializer projection differs")
	end

	-- Faction top-level APIs/callback registrations under a published authority.
	do
	local faction_callbacks = 0
	local faction_core = {}
	for _, name in ipairs({"register_on_joinplayer", "register_on_respawnplayer",
			"register_on_punchplayer", "register_on_player_hpchange",
			"register_on_leaveplayer", "register_on_player_receive_fields",
			"register_chatcommand"}) do
		faction_core[name] = function() faction_callbacks = faction_callbacks + 1 end
	end
	function faction_core.register_privilege() faction_callbacks = faction_callbacks + 1 end
	function faction_core.get_player_by_name() return nil end
	function faction_core.check_player_privs() return false end
	function faction_core.show_formspec() end
	function faction_core.close_formspec() end
	function faction_core.after() end
	function faction_core.chat_send_player() end
	local faction_environment = setmetatable({core = faction_core,
		grug_core = {zone_authority_installed = function() return true end,
			factions = {accord = {name = "Accord"}, throng = {name = "Throng"}},
			faction_ids = {"accord", "throng"},
			start_position = function() return {x = 0, y = 1, z = 0} end},
		grug_classes = {}, vector = {new = function(value) return value end}},
		{__index = _G})
	execute_in_environment("mods/PLAYER/grug_factions/init.lua", faction_environment)
	check(type(faction_environment.grug_factions) == "table" and
		type(faction_environment.grug_factions.get_faction) == "function" and
		faction_callbacks >= 5, "faction registration projection differs")
	end

	-- Trader registrations and dispatcher callback are captured without objects.
	do
	local trader_defs, trader_steps = {}, 0
	local trader_core = {registered_nodes = {}, registered_entities = {}}
	function trader_core.register_globalstep() trader_steps = trader_steps + 1 end
	function trader_core.get_connected_players() return {} end
	function trader_core.get_objects_inside_radius() return {} end
	function trader_core.get_node_or_nil() return nil end
	function trader_core.log() end
	function trader_core.pos_to_string() return "(0,0,0)" end
	local trader_mobs = {}
	function trader_mobs.register_mob(_, name, definition)
		trader_defs[#trader_defs + 1] = name
		trader_core.registered_entities[name] = definition
	end
	local trader_environment = setmetatable({core = trader_core, mobs = trader_mobs,
		grug_traders = {RACE_DISCOUNT = 0.1, open = function() end},
		grug_classes = {registered_races = {
			human = {name = "Human", faction = "accord"},
			dwarf = {name = "Dwarf", faction = "accord"},
			elf = {name = "Elf", faction = "accord"},
			orc = {name = "Orc", faction = "throng"},
			troll = {name = "Troll", faction = "throng"},
			undead = {name = "Undead", faction = "throng"}},
			get_race = function() return "human" end},
		grug_factions = {get_faction = function() return "accord" end,
			display_name = function(value) return value end},
		grug_mobs = {add_mob = function() return nil end},
		grug_core = {faction_ids = {"accord", "throng"},
			factions = {accord = {name = "Accord"}, throng = {name = "Throng"}},
			capital_anchor = function(_, race)
				return {x = race == "human" and 1 or 2, y = 1, z = 0}
			end}}, {__index = _G})
	execute_in_environment("mods/ENTITIES/grug_traders/vendors.lua", trader_environment)
	check(#trader_defs == 8 and trader_steps == 1,
		"trader registration projection differs")
	table.sort(trader_defs, less_bytes)
	row("registration/trader_projection_sha256",
		hex_sha256(table.concat(trader_defs, "\n") .. "\n"))
	end

	-- Main initializer and emerge script load/register exactly one R7 lane under
	-- closed runtime stubs; loader semantics are separately covered by unit KATs.
	do
	local mapgen_environment = setmetatable({core = {
		get_current_modname = function() return "grug_mapgen" end,
		get_modpath = function() return repo .. "/mods/MAPGEN/grug_mapgen" end,
	}, grug_materials = {}, grug_gathering = {}, grug_core = {}}, {__index = _G})
	mapgen_environment.dofile = function()
		return function() return {schema = "micro_loader", writer_count = 1} end
	end
	execute_in_environment("mods/MAPGEN/grug_mapgen/init.lua", mapgen_environment)
	check(mapgen_environment.grug_mapgen.wp40.writer_count == 1,
		"mapgen initializer projection differs")
	local generated_callback
	local emerge_core = {}
	function emerge_core.get_modpath(name)
		if name == "default" then return repo .. "/mods/BASE/default" end
		if name == "grug_gathering" then return repo .. "/mods/ITEMS/grug_gathering" end
		return repo .. "/mods/MAPGEN/grug_mapgen"
	end
	function emerge_core.ipc_get()
		return {schema = "grug_wp40_r7_ipc_v1", manifest_sha256 = string.rep("a", 64),
			full_seed = "0", projection = {}}
	end
	function emerge_core.register_on_generated(callback) generated_callback = callback end
	local generated_observation = {}
	local engine_callback_vector_metatable = {}
	local emerge_environment = setmetatable({core = emerge_core,
		vector = {metatable = engine_callback_vector_metatable}}, {__index = _G})
	emerge_environment.dofile = function(path)
		if path:match("/r7_native%.lua$") then
			return {validate_emerge = function() end, identities = function() return {} end}
		end
		if path:match("/catalog%.lua$") then return {} end
		if path:match("/r7_runtime%.lua$") then
			return function()
				return {build = function()
					return {full_seed = "0", session = {
						plan_slice = function(minp, maxp)
							generated_observation.plan_min = minp
							generated_observation.plan_max = maxp
							return {}, 1
						end}, writer = {apply = function(_, minp, maxp)
							generated_observation.writer_min = minp
							generated_observation.writer_max = maxp
							return "applied_micro"
						end}}
				end}
			end
		end
		error("unexpected emerge dependency", 0)
	end
	execute_in_environment("mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua",
		emerge_environment)
	check(type(generated_callback) == "function",
		"emerge callback registration projection differs")
	generated_callback({},
		setmetatable({x = -32, y = 0, z = -32}, engine_callback_vector_metatable),
		setmetatable({x = 47, y = 79, z = 47}, engine_callback_vector_metatable), 0)
	check(getmetatable(generated_observation.plan_min) == nil and
		getmetatable(generated_observation.plan_max) == nil and
		rawequal(generated_observation.plan_min,
			generated_observation.writer_min) and
		rawequal(generated_observation.plan_max,
			generated_observation.writer_max),
		"generated callback vector normalization differs")
	row("mapgen/generated_vector_normalized", "true")
	end

	-- Exercise the production native module, including all six setters/readbacks
	-- and the closed six-row ore allowlist, with the engine's vector-shaped
	-- NoiseParams spread readback.
	local saved_core = rawget(_G, "core")
	local saved_vector = rawget(_G, "vector")
	local engine_vector_metatable = {}
	local native_state = {setters = {}, readbacks = {}, ores = {}}
	local native_core = {registered_nodes = {}, registered_ores = {}}
	for _, name in ipairs({"default:stone", "default:gravel",
			"grug_materials:slate", "grug_materials:basalt",
			"grug_materials:granite", "grug_materials:emberrock",
			"grug_materials:abyssal_rock"}) do
		native_core.registered_nodes[name] = {name = name}
	end
	function native_core.sha256(bytes, raw)
		check(raw == false, "native module requested a non-hexadecimal digest")
		return hex_sha256(bytes)
	end
	function native_core.set_mapgen_setting_noiseparams(name, definition, override)
		check(override == true, "native noise setter did not force override")
		native_state.setters[#native_state.setters + 1] = name
		local persist = definition.persist
		if persist == 0.6 then persist = 0.60000002384185791015625 end
		native_state.readbacks[name] = {
			offset = definition.offset, scale = definition.scale,
			persist = persist, persistence = persist,
			lacunarity = definition.lacunarity, seed = definition.seed,
			octaves = definition.octaves, flags = definition.flags or "defaults",
			spread = copy(definition.spread),
		}
	end
	function native_core.get_mapgen_setting_noiseparams(name)
		local value = copy(native_state.readbacks[name])
		setmetatable(value.spread, engine_vector_metatable)
		return value
	end
	function native_core.register_ore(definition)
		native_state.ores[#native_state.ores + 1] = definition
		native_core.registered_ores[definition.name] = definition
		return #native_state.ores
	end
	rawset(_G, "core", native_core)
	rawset(_G, "vector", {metatable = engine_vector_metatable})
	local native = dofile(wp40 .. "/r7_native.lua")
	local native_token = native.apply_and_validate_main()
	local native_identities = native.identities()
	local native_handles = native.register_ores(native_token)
	rawset(_G, "core", saved_core)
	rawset(_G, "vector", saved_vector)
	check(#native_state.setters == 6 and #native_handles == 6 and
		#native_state.ores == 6, "native six/six population differs")
	check(hex_sha256(native_token.noise_bytes) == native_identities.noise_digest,
		"native noise canonicalization differs")
	check(hex_sha256(native_token.native_bytes) == native_identities.native_digest,
		"native allowlist canonicalization differs")
	row("native/noise_sha256", native_identities.noise_digest)
	row("native/allowlist_sha256", native_identities.native_digest)
	row("native/noise_order", table.concat(native_state.setters, ","))
	local ore_names = {}
	for index = 1, #native_state.ores do ore_names[index] = native_state.ores[index].name end
	row("native/ore_order_sha256", hex_sha256(table.concat(ore_names, "\n") .. "\n"))

	-- Exercise the real read_schematic size shape: Luanti pushes a builtin
	-- vector, while the pure R6 template parser deliberately consumes plain
	-- tables only.
	do
	local saved_vector = rawget(_G, "vector")
	local engine_vector_metatable = {}
	rawset(_G, "vector", {metatable = engine_vector_metatable})
	local template_factory = dofile(wp40 .. "/r7_template_source.lua")
	local function schematic(size_metatable)
		return {
			size = setmetatable({x = 1, y = 1, z = 1}, size_metatable),
			yslice_prob = {{ypos = 0, prob = 254}},
			data = {{name = "ignore", prob = 254, param2 = 0}},
		}
	end
	local engine_source = template_factory({read_schematic = function()
		return schematic(engine_vector_metatable)
	end}, "/micro/schematics")
	local normalized = engine_source.read("micro.mts")
	check(getmetatable(normalized.size) == nil and normalized.size.x == 1 and
		normalized.size.y == 1 and normalized.size.z == 1 and
		normalized.data[1].name == "air" and
		normalized.data[1].force_place == false,
		"engine schematic vector normalization differs")
	local foreign_source = template_factory({read_schematic = function()
		return schematic({})
	end}, "/micro/schematics")
	expect_failure(function() foreign_source.read("micro.mts") end,
		"engine size metatable differs")
	rawset(_G, "vector", saved_vector)
	row("template/engine_vector_normalized", "true")
	end

	-- Build the actual R7 content identities without loading or parsing an MTS.
	-- The source parser only discovers the production module's closed target list;
	-- node semantics still come from the real registration files through the
	-- dedicated engine-registration fixture.
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local content_source = common.read_file(wp40 .. "/r7_content.lua")
	local accepted_block = content_source:match(
		"local ACCEPTED_R6_ROWS = {(.-)\n\t}\n\tlocal CULTURAL_NAMES")
	check(accepted_block, "production accepted-content block is absent")
	local accepted_rows = {}
	for name, mask in accepted_block:gmatch('{"([^"]+)", (%d+)}') do
		accepted_rows[#accepted_rows + 1] = {name, assert(tonumber(mask))}
	end
	check(#accepted_rows == 77, "accepted-content population differs")
	local cultural_rows, p9g_rows = catalog.cultural_sources(), catalog.p9g_sources()
	local semantic_names = {"air", "ignore", "default:water_source",
		"default:water_flowing", "default:river_water_source",
		"default:river_water_flowing"}
	for index = 1, #accepted_rows do
		semantic_names[#semantic_names + 1] = accepted_rows[index][1]
	end
	for index = 1, #cultural_rows do
		semantic_names[#semantic_names + 1] = cultural_rows[index].source_node
	end
	for index = 1, #p9g_rows do
		semantic_names[#semantic_names + 1] = p9g_rows[index].source_node
	end
	semantic_names[#semantic_names + 1] = "grug_nodes:camp_fire"
	semantic_names[#semantic_names + 1] = "grug_nodes:guard_banner"
	local semantic_fixture = dofile(repo ..
		"/tools/wp40/r7/node_semantics_fixture.lua")(
		repo, catalog, semantic_names)
	check(semantic_fixture.target_count == 103,
		"semantic target population differs")

	local material_core = {registered_nodes = {}}
	function material_core.get_modpath() return nil end
	function material_core.register_on_leaveplayer() end
	function material_core.node_dig() return false end
	function material_core.handle_node_drops() end
	local material_environment = setmetatable({grug_materials = {},
		core = material_core}, {__index = _G})
	for _, filename in ipairs({"registry.lua", "mining.lua"}) do
		local material_chunk = assert(loadfile(repo ..
			"/mods/ITEMS/grug_materials/" .. filename))
		setfenv(material_chunk, material_environment)
		material_chunk()
	end
	local projection = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp43_handoff.lua").project(
		material_environment.grug_materials)
	check(#projection.tiers == 6 and #projection.natural_ground_nodes == 23 and
		#projection.resources == 15 and #projection.processed_materials == 12 and
		#projection.gem_grades == 2 and #projection.cultural_materials == 6 and
		#projection.signature_woods == 6 and #projection.race_regions == 6 and
		#projection.density.deep_bands == 2,
		"complete production WP43 projection population differs")

	local cid_by_name, name_by_cid, definitions = {}, {}, {}
	local next_cid = 100
	local function register(name, cid)
		cid = cid or next_cid
		if not cid_by_name[name] and cid == next_cid then next_cid = next_cid + 1 end
		check(not cid_by_name[name] and not name_by_cid[cid],
			"duplicate compact content registration")
		cid_by_name[name], name_by_cid[cid] = cid, name
		definitions[name] = semantic_fixture.definitions[name]
	end
	register("air", 0)
	register("default:water_source", 1)
	register("default:water_flowing", 2)
	register("default:river_water_source", 3)
	register("default:river_water_flowing", 4)
	register("ignore", 65535)
	for index = 1, #accepted_rows do register(accepted_rows[index][1]) end
	for index = 1, #cultural_rows do register(cultural_rows[index].source_node) end
	for index = 1, #p9g_rows do register(p9g_rows[index].source_node) end
	register("grug_nodes:camp_fire")
	register("grug_nodes:guard_banner")
	local content_core = {registered_nodes = definitions, CONTENT_AIR = 0,
		CONTENT_IGNORE = 65535}
	function content_core.get_content_id(name)
		return check(cid_by_name[name], "unknown compact content " .. tostring(name))
	end
	function content_core.get_name_from_content_id(cid) return name_by_cid[cid] end
	local content_set = dofile(wp40 .. "/r7_content.lua")(
		content_core, projection, raw_sha256)
	check(content_set.production_semantic_digest ==
		"3e7d2eddded546e39e74656ab03d27dab606ff30867c948808277b724cff4ee2",
		"production semantic identity differs")
	check(content_set.p9g_semantic_digest ==
		"450c35e94af32721768d3771454db89dbdb43099660b2118c178a3ca6b438d49",
		"P9G semantic identity differs")
	row("content/production_sha256", content_set.production_digest)
	row("content/p9g_sha256", content_set.p9g_digest)

	-- Reconstruct the full production receipt at its public validator boundary.
	-- Every non-predecessor value below comes from a production module built in
	-- this process; predecessor digests are the explicit immutable R5/R6 pins.
	local canonical = dofile(wp40 .. "/canonical.lua")
	local manifest_module = dofile(wp40 .. "/r7_manifest.lua")(
		canonical, raw_sha256)
	check(manifest_module.graph_digest_for_evidence(projection) ==
		"c8088a4b6802c0fc1a74d8826e3df0bb49b64f9ab4c6e93bcbd66aa2a16b9895",
		"complete production WP43 projection digest differs")
	local r6_manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
	local r5_manifest_module = dofile(wp40 .. "/mapgen_manifest.lua")
	local r5_values = r5_manifest_module.validate(r6_manifest.r5_manifest_values)
	local r5_digest = hex_sha256(r5_manifest_module.canonical_bytes(r5_values))
	local gathering_manifest = catalog.manifest()
	local cultural_registrations = catalog.cultural_registrations()
	local cultural_digests = {}
	for index = 1, #cultural_registrations do
		cultural_digests[index] = cultural_registrations[index].digest
	end
	local p9g_delta = {schema = "grug_wp40_r7_p9g_delta_v1", opcode = 35,
		class = 10, policy = 11, successor_ref_min = 84,
		successor_ref_max = 95, order = "after_r6_p9_before_run_derivation",
		overwrite = false, catalog_sha256 = gathering_manifest.sha256}
	local p9g_delta_digest = manifest_module.graph_digest_for_evidence(p9g_delta)
	local anchor_roster_sha256 = string.rep("8", 64)
	local anchor_delta = {schema = "grug_wp40_r7_anchor_delta_v1", opcode = 36,
		class = 12, policy = 12, successor_ref_min = 96,
		successor_ref_max = 97, order = "after_p9g_before_run_derivation",
		overwrite = false, roster_sha256 = anchor_roster_sha256,
		root = "anchor_y_plus_one", support = "settled_predecessor_support_v1",
		capital_count = 6, outpost_count = 24, bandit_count = 12,
		functional_protection_schema =
			"grug_wp40_r7_functional_anchor_protection_v1",
		functional_columns = 36, functional_y_min = -700}
	local anchor_delta_digest = manifest_module.graph_digest_for_evidence(anchor_delta)
	local manifest_values = {
		schema = "grug_wp40_r7_mapgen_manifest_v1", full_seed = "0",
		r5_schema = "grug_wp40_r5_mapgen_manifest_v1",
		r5_manifest_sha256 = r5_digest,
		r5_artifact_sha256 =
			"0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0",
		r6_schema = r6_manifest.schema,
		r6_contract_sha256 = r6_manifest.contract_sha256,
		r6_artifact_sha256 =
			"bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4",
		r6_catalog_sha256 =
			"250fefd017d85fe652be66dbe0d6548e0bf3ada64668f4f9cc2f0fd5577edb2d",
		r6_accepted_content_sha256 =
			"b91a815183d93c2ba0de70409f52911d1e019314e7870fa44eff86f363119155",
		r6_template_inputs_sha256 =
			"807ddf131db405974f365c4e08aa124eeba6cac61fa1655e455794507f858a55",
		wp43_projection_sha256 =
			"c8088a4b6802c0fc1a74d8826e3df0bb49b64f9ab4c6e93bcbd66aa2a16b9895",
		noise_schema = native_identities.noise_schema,
		noise_sha256 = native_identities.noise_digest,
		native_schema = native_identities.native_schema,
		native_sha256 = native_identities.native_digest,
		gathering_schema = gathering_manifest.schema,
		gathering_sha256 = gathering_manifest.sha256,
		production_r6_content_schema = content_set.production.schema,
		production_r6_content_sha256 = content_set.production_digest,
		production_r6_semantic_sha256 = content_set.production_semantic_digest,
		cultural_registration_sha256 = table.concat(cultural_digests, ","),
		p9g_content_schema = content_set.p9g.schema,
		p9g_content_sha256 = content_set.p9g_digest,
		p9g_semantic_sha256 = content_set.p9g_semantic_digest,
		p9g_delta_schema = p9g_delta.schema,
		p9g_delta_sha256 = p9g_delta_digest,
		anchor_content_schema = content_set.anchors.schema,
		anchor_content_sha256 = content_set.anchor_digest,
		anchor_semantic_sha256 = content_set.anchor_semantic_digest,
		anchor_roster_schema = "grug_wp40_r7_anchor_roster_v1",
		anchor_roster_sha256 = anchor_roster_sha256,
		anchor_delta_schema = anchor_delta.schema,
		anchor_delta_sha256 = anchor_delta_digest,
		anchor_opcode = 36, anchor_class = 12, anchor_policy = 12,
		anchor_order = anchor_delta.order, anchor_overwrite = false,
		functional_anchor_protection_schema =
			anchor_delta.functional_protection_schema,
		functional_anchor_columns = 36, functional_anchor_y_min = -700,
		writer_schema = "grug_wp40_r7_single_vm_writer_v1",
		p9g_opcode = 35, p9g_class = 10, p9g_policy = 11,
		p9g_order = p9g_delta.order, p9g_overwrite = false,
		source_projection_sha256 =
			"8f1eef2702c631451ee987b3eb4a267d117fcc3ce1d97947d4b6936e0ea3502b",
		production_enabled = true,
	}
	local manifest_field_order = {
		"schema", "full_seed", "r5_schema", "r5_manifest_sha256",
		"r5_artifact_sha256", "r6_schema", "r6_contract_sha256",
		"r6_artifact_sha256", "r6_catalog_sha256",
		"r6_accepted_content_sha256", "r6_template_inputs_sha256",
		"wp43_projection_sha256", "noise_schema", "noise_sha256",
		"native_schema", "native_sha256", "gathering_schema",
		"gathering_sha256", "production_r6_content_schema",
		"production_r6_content_sha256", "production_r6_semantic_sha256",
		"cultural_registration_sha256", "p9g_content_schema",
		"p9g_content_sha256", "p9g_semantic_sha256", "p9g_delta_schema",
		"p9g_delta_sha256", "anchor_content_schema", "anchor_content_sha256",
		"anchor_semantic_sha256", "anchor_roster_schema", "anchor_roster_sha256",
		"anchor_delta_schema", "anchor_delta_sha256", "anchor_opcode",
		"anchor_class", "anchor_policy", "anchor_order", "anchor_overwrite",
		"functional_anchor_protection_schema", "functional_anchor_columns",
		"functional_anchor_y_min", "writer_schema", "p9g_opcode", "p9g_class",
		"p9g_policy", "p9g_order", "p9g_overwrite", "source_projection_sha256",
		"production_enabled",
	}
	local manifest_rows = {}
	for index = 1, #manifest_field_order do
		local key, value = manifest_field_order[index], manifest_values[manifest_field_order[index]]
		if type(value) == "boolean" then value = value and "true" or "false"
		elseif type(value) == "number" then value = string.format("%.0f", value) end
		manifest_rows[index] = key .. "\t" .. value .. "\n"
	end
	local manifest_bytes = table.concat(manifest_rows)
	local manifest = {schema = manifest_values.schema, values = manifest_values,
		canonical_bytes = manifest_bytes, sha256 = hex_sha256(manifest_bytes)}
	check(manifest_module.validate(manifest, manifest.sha256) == true,
		"full R7 manifest validation failed")
	local damaged_manifest = copy(manifest)
	damaged_manifest.canonical_bytes = damaged_manifest.canonical_bytes .. "x"
	expect_failure(function() manifest_module.validate(damaged_manifest) end,
		"receipt validation differs")
	row("manifest/full_sha256", manifest.sha256)
	row("manifest/p9g_delta_sha256", p9g_delta_digest)
	row("manifest/anchor_delta_sha256", anchor_delta_digest)

	-- Bind the real successor with the real catalog/content resolvers. Its SHA
	-- seam is real for catalog authentication and deliberately compact for the
	-- synthetic rank domain; the native and output digests above remain SHA-256.
	local function compact_digest(bytes)
		if bytes == gathering_manifest.canonical_bytes then return raw_sha256(bytes) end
		local accumulators = {2166136261, 2246822519, 3266489917, 668265263,
			374761393, 1274126177, 1431374977, 42595009}
		for index = 1, #bytes do
			local slot = (index - 1) % 8 + 1
			accumulators[slot] = (accumulators[slot] * 257 +
				string.byte(bytes, index) + index) % 4294967296
		end
		local output = {}
		for index = 1, 8 do
			local value = accumulators[index]
			output[#output + 1] = string.char(math.floor(value / 16777216) % 256,
				math.floor(value / 65536) % 256, math.floor(value / 256) % 256,
				value % 256)
		end
		return table.concat(output)
	end
	local successor_config = dofile(wp40 .. "/r7_p9g.lua")(
		catalog, content_set.p9g, compact_digest)
	local hash_seam = {}
	function hash_seam.budget(eligible)
		return eligible > 0 and 1 or 0
	end
	local zones_session = {}
	function zones_session.surface_mob_level_at() return 7 end
	local content_wrapper = {}
	function content_wrapper.content_contract() return content_set.production end
	local successor_dependencies = {full_seed_string = "0",
		hash = hash_seam, planner_source = {}, horizontal = {},
		content = content_wrapper, source = {}, zones_session = zones_session,
		construction_identity = {}}
	local probe_successor = successor_config.new(successor_dependencies)

	local minp, maxp = {x = -32, y = 0, z = -32},
		{x = 47, y = 79, z = 47}
	local column_values = {}
	for index = 1, 6400 * 12 do column_values[index] = 0 end
	local active_column = ((0 - minp.z) * 80 + (0 - minp.x)) * 12
	column_values[active_column + 5] = 5
	local plan = {schema = "grug_wp40_r6_refinement_plan_v1", generation = 1,
		min_x = minp.x, min_y = minp.y, min_z = minp.z,
		max_x = maxp.x, max_y = maxp.y, max_z = maxp.z,
		column_values = column_values, column_count = 6400}
	local production_ref = {}
	for index = 1, #content_set.production.content_names do
		production_ref[content_set.production.content_names[index]] = index
	end
	local corn = p9g_rows[1]
	local corn_zone, corn_biome, support_name = corn.zones[#corn.zones],
		corn.hosts[#corn.hosts].biome, corn.hosts[#corn.hosts].support
	local support_ref = check(production_ref[support_name], "corn support ref is absent")
	local support_cid = content_set.production.content_cids[support_ref]
	local air_cid = content_set.production.r5.resolve(1, 0, 0)
	local function new_context(call_mode, exclusion)
		local written = {}
		local context = {schema = "grug_wp40_r7_successor_context_v1",
			plan = plan, generation = 1, call_mode = call_mode,
			min_x = minp.x, min_y = minp.y, min_z = minp.z,
			max_x = maxp.x, max_y = maxp.y, max_z = maxp.z}
		local function key(x, y, z) return x .. "/" .. y .. "/" .. z end
		function context.inside_owner(x, y, z)
			return x >= minp.x and x <= maxp.x and y >= minp.y and y <= maxp.y and
				z >= minp.z and z <= maxp.z
		end
		function context.original_at() return air_cid, 0 end
		function context.settled_at(x, y, z)
			local value = written[key(x, y, z)]
			if value then return unpack(value) end
			if x == 0 and y == 5 and z == 0 then
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end
			return air_cid, 0, 0, 0, 0, 0, 0
		end
		function context.production_content(name)
			local ref = production_ref[name]
			return ref, ref and content_set.production.content_cids[ref] or nil
		end
		function context.analytic_p7_ref(x, y, z)
			return x == 0 and y == 5 and z == 0 and support_ref or nil
		end
		function context.analytic_p7_tuple(x, y, z)
			if x == 0 and y == 5 and z == 0 then
				return support_cid, 0, 0, 4, 0, 0, (support_ref - 1) * 256
			end
			return -1, -1, -3, -1, -1, -1, -1
		end
		function context.exclusion_at(x, z)
			return x == 0 and z == 0 and exclusion or nil
		end
		function context.housing_excluded_at() return false end
		function context.column_values_at(x, z)
			if x == 0 and z == 0 then
				return "land", 1, corn_zone, corn_biome, "human", 5
			end
			return "land", 1, "micro_no_zone", corn_biome, "human", 0
		end
		function context.write_p9g(x, y, z, cid, param2, local_ref, feature)
			written[key(x, y, z)] = {cid, param2, -2, 35, feature, 0,
				(#content_set.production.content_names + local_ref - 1) * 256 + param2}
		end
		return context
	end

	local function probe_context(exclusion)
		local context = new_context("fixture", exclusion)
		return {inside_owner = context.inside_owner,
			original_at = context.original_at, settled_at = context.settled_at,
			production_content = context.production_content,
			analytic_p7_ref = context.analytic_p7_ref,
			analytic_p7_tuple = context.analytic_p7_tuple,
			exclusion_at = context.exclusion_at,
			housing_excluded_at = context.housing_excluded_at,
			column_values_at = context.column_values_at}
	end
	local accepted_reason, accepted_evidence = probe_successor:probe_reason(
		probe_context(nil), 1, 0, 6, 0)
	local rejected_reason = probe_successor:probe_reason(
		probe_context("fixed_or_protected"), 1, 0, 6, 0)
	check(accepted_reason == "accepted" and rejected_reason == "fixed_or_protected",
		"accepted/rejected P9G probes differ")
	row("p9g/root_pair", accepted_reason .. "/" .. rejected_reason)

	-- Bind both R6 projection receipts through the production evidence contract.
	local evidence_contract = dofile(repo .. "/tools/wp40/r7/contract.lua")
	local operation = accepted_evidence
	check(operation.prior_cid == air_cid and
		operation.prior_param2 == 0 and operation.prior_occupancy == 0 and
		operation.prior_opcode == 0,
		"Stage-A removable P9G delta differs")
	local direct_bytes = table.concat({"root", 0, 6, 0,
		operation.prior_cid, operation.prior_param2,
		operation.prior_occupancy, operation.prior_opcode}, "/")
	local direct_digest = hex_sha256(direct_bytes)
	local stage_a = {
		schema = "grug_wp40_r7_stage_a_receipt_v1", seed_slot = 1,
		seed_identity = "micro-seed-0",
		production_r6_content_sha256 = content_set.production_digest,
		p9g_content_sha256 = content_set.p9g_digest,
		p9g_delta_sha256 = p9g_delta_digest,
		anchor_content_sha256 = content_set.anchor_digest,
		anchor_roster_sha256 = anchor_roster_sha256,
		anchor_delta_sha256 = anchor_delta_digest, anchor_write_count = 0,
		operation_count = 2, accepted_count = 1, rejected_count = 1,
		restored_buffers_sha256 = direct_digest,
		direct_buffers_sha256 = direct_digest,
		restored_runs_sha256 = direct_digest, direct_runs_sha256 = direct_digest,
		equal = true,
	}
	evidence_contract.validate_stage_a(stage_a)
	local accepted_content_rows = content_set.accepted_r6_rows()
	local accepted_by_name, normalized_names = {}, {}
	for index = 1, #accepted_content_rows do
		accepted_by_name[accepted_content_rows[index][1]] =
			accepted_content_rows[index][2]
	end
	local cultural_by_name = {}
	for index = 1, #cultural_rows do
		cultural_by_name[cultural_rows[index].source_node] = true
	end
	local substitution_count = 0
	for index = 1, #content_set.production.content_names do
		local name = content_set.production.content_names[index]
		local mask = content_set.production.content_kind_masks[index]
		if cultural_by_name[name] then
			name, substitution_count = "grug_nodes:bone_pile", substitution_count + 1
			check(accepted_by_name[name] == 24,
				"Stage-B synthetic cultural target differs")
		else
			check(accepted_by_name[name] == mask,
				"Stage-B non-cultural name map differs")
		end
		normalized_names[name] = true
	end
	local normalized_population = 0
	for name in pairs(normalized_names) do
		normalized_population = normalized_population + 1
		check(accepted_by_name[name] ~= nil,
			"Stage-B normalization introduced a foreign name")
	end
	check(#accepted_content_rows == 77 and normalized_population == 77 and
		substitution_count == 6,
		"Stage-B 83-to-77 name projection differs")
	local normalized, accepted = {}, {}
	for index = 1, #cultural_registrations do
		local registration = cultural_registrations[index]
		check(#registration.cells == 1 and
			registration.cells[1].node == cultural_rows[index].source_node,
			"cultural projection registration differs")
		normalized[index] = registration.id .. "/grug_nodes:bone_pile/24\n"
		accepted[index] = registration.id .. "/grug_nodes:bone_pile/24\n"
	end
	local normalized_digest = hex_sha256(table.concat(normalized))
	local accepted_digest = hex_sha256(table.concat(accepted))
	check(normalized_digest == accepted_digest, "Stage-B cultural normalization differs")
	local stage_b = {
		schema = "grug_wp40_r7_stage_b_receipt_v1", seed_slot = 1,
		seed_identity = "micro-seed-0",
		production_r6_content_sha256 = content_set.production_digest,
		accepted_r6_projection_sha256 = accepted_digest,
		name_map_population = 83, cultural_name_map_population = 6,
		cultural_substitution_count = substitution_count,
		inherited_cultural_access_count = 12,
		normalized_artifact_sha256 = normalized_digest,
		candidate_decisions_sha256 = normalized_digest,
		accepted_candidate_decisions_sha256 = accepted_digest, equal = true,
	}
	evidence_contract.validate_stage_b(stage_b)
	row("projection/stage_a_sha256",
		hex_sha256(evidence_contract.stage_a_bytes(stage_a)))
	row("projection/stage_b_sha256",
		hex_sha256(evidence_contract.stage_b_bytes(stage_b)))

	-- Install the actual public authority and protection wrapper around a
	-- deterministic representative session, then exercise stable queries and
	-- fail-closed behavior on both sides of publication.
	local saved_grug_core, saved_grug_zones = rawget(_G, "grug_core"),
		rawget(_G, "grug_zones")
	local protection_core = {}
	function protection_core.is_protected(pos) return pos.prior == true end
	function protection_core.sha256(bytes) return hex_sha256(bytes) end
	function protection_core.check_player_privs(name)
		return name == "bypass"
	end
	rawset(_G, "core", protection_core)
	rawset(_G, "grug_core", {})
	rawset(_G, "grug_zones", nil)
	function grug_core.get_player_faction(name)
		return name == "throng" and "throng" or "accord"
	end
	dofile(repo .. "/mods/CORE/grug_core/zone_authority.lua")
	check(grug_core.world_protected_for_faction({hard = false}, "accord") == true,
		"pre-publication protection did not fail closed")
	dofile(repo .. "/mods/CORE/grug_core/protection.lua")
	check(protection_core.is_protected({hard = false}, "alice") == true,
		"pre-publication engine wrapper did not fail closed")

	local race_ids = {"dwarf", "human", "elf", "undead", "orc", "troll"}
	local factions = {dwarf = "accord", human = "accord", elf = "accord",
		undead = "throng", orc = "throng", troll = "throng"}
	local anchors, position_anchor = {}, {}
	local function add_anchor(numeric_id, zone_id, slot_id, faction, race)
		local anchor = {id = string.format("anchor_%03d", numeric_id),
			numeric_id = numeric_id, zone_id = zone_id, slot_id = slot_id,
			x = numeric_id * 100, y = 20, z = numeric_id * -100,
			_faction = faction, _race = race}
		anchors[zone_id .. "\0" .. slot_id] = anchor
		position_anchor[anchor.x .. "/" .. anchor.z] = anchor
		return {zone_id = zone_id, slot_id = slot_id}
	end
	local payload = {schema = "grug_wp40_r7_consumer_payload_v1",
		races = {}, outposts = {}, rare_routes = {}}
	for index = 1, #race_ids do
		local race = race_ids[index]
		payload.races[index] = {race_id = race, faction_id = factions[race],
			start = add_anchor(index, race .. "_start", "start", factions[race], race),
			capital = add_anchor(index + 6, race .. "_capital", "capital",
				factions[race], race)}
	end
	local outpost_index = 0
	for race_index = 1, #race_ids do
		local race = race_ids[race_index]
		for local_index = 1, 4 do
			outpost_index = outpost_index + 1
			payload.outposts[outpost_index] = {race_id = race,
				faction_id = factions[race],
				anchor = add_anchor(24 + outpost_index,
					race .. "_outpost_" .. local_index,
					"outpost_" .. local_index,
					local_index <= 2 and factions[race] or nil, race)}
		end
	end
	local consumer_source = common.read_file(wp40 .. "/r7_consumer_payload.lua")
	local rare_block = consumer_source:match("local RARE_IDS = {(.-)}")
	check(rare_block, "consumer rare roster is absent")
	local rare_ids = {}
	for id in rare_block:gmatch('"([a-z0-9_]+)"') do
		rare_ids[#rare_ids + 1] = id
	end
	check(#rare_ids == 10, "consumer rare roster population differs")
	for index = 1, #rare_ids do
		payload.rare_routes[index] = {id = rare_ids[index],
			anchor = add_anchor(90 + index, "rare_zone_" .. index,
				"rare_" .. rare_ids[index], "accord", nil),
			patrol_offsets = {{x = -48, z = -24}, {x = 16, z = 40},
				{x = 56, z = -16}}}
	end
	local payload_bytes = {"schema\tgrug_wp40_r7_consumer_payload_v1\n"}
	for index = 1, #payload.races do
		local value = payload.races[index]
		payload_bytes[#payload_bytes + 1] = table.concat({"race", value.race_id,
			value.faction_id, value.start.zone_id, value.start.slot_id,
			value.capital.zone_id, value.capital.slot_id}, "\t") .. "\n"
	end
	for index = 1, #payload.outposts do
		local value = payload.outposts[index]
		payload_bytes[#payload_bytes + 1] = table.concat({"outpost", value.race_id,
			value.faction_id, value.anchor.zone_id, value.anchor.slot_id}, "\t") .. "\n"
	end
	for index = 1, #payload.rare_routes do
		local value = payload.rare_routes[index]
		local fields = {"rare", value.id, value.anchor.zone_id, value.anchor.slot_id}
		for offset = 1, #value.patrol_offsets do
			fields[#fields + 1] = tostring(value.patrol_offsets[offset].x)
			fields[#fields + 1] = tostring(value.patrol_offsets[offset].z)
		end
		payload_bytes[#payload_bytes + 1] = table.concat(fields, "\t") .. "\n"
	end
	payload.sha256 = hex_sha256(table.concat(payload_bytes))
	local session = {compatibility = {}}
	function session.get(id) return {id = id} end
	function session.at() return {id = "micro_zone"} end
	function session.neighbors() return {} end
	function session.travel_links() return {} end
	function session.anchor(zone_id, slot_id)
		return copy(anchors[zone_id .. "\0" .. slot_id])
	end
	function session.id_at(x, z)
		check(type(x) == "number" and type(z) == "number",
			"zone id_at signature differs")
		local anchor = position_anchor[x .. "/" .. z]
		return anchor and anchor.zone_id or "micro_zone"
	end
	function session.biome_at(x, z)
		check(type(x) == "number" and type(z) == "number",
			"zone biome_at signature differs")
		return "grug_meadows"
	end
	function session.race_region_at(x, z)
		local anchor = position_anchor[x .. "/" .. z]
		return anchor and anchor._race or "human"
	end
	function session.faction_at(pos) return pos._faction end
	function session.territory_rule_at() return "shared_editable" end
	function session.pvp_rule_at() return "contested" end
	function session.surface_mob_level_at() return 7 end
	function session.mob_level_at() return 7 end
	function session.guard_level_at() return 10 end
	function session.terrain_height_at() return 20 end
	function session.water_class_at() return "land" end
	function session.nearest_route_at() return nil end
	function session.nearest_hydrology_at() return nil end
	function session.housing_eligible_at() return false end
	function session.compatibility.surface_level_at() return 20 end
	function session.compatibility.mob_level_at() return 7 end
	function session.compatibility.guard_level_at() return 10 end
	function session.compatibility.open_sea_at() return false end
	function session.compatibility.territory_at() return "shared_editable" end
	function session.compatibility.zone_at() return "micro_zone" end
	function session.compatibility.world_protected_for_faction(pos)
		return pos.hard == true
	end
	local publish = grug_core.prepare_zone_authority(session, payload)
	check(not grug_core.zone_authority_installed() and rawget(_G, "grug_zones") == nil,
		"authority preparation published partial state")
	check(publish() == true and grug_core.zone_authority_installed(),
		"authority publication failed")
	local start = grug_core.start_position("accord", "human")
	local rare = grug_core.rare_route("grimtusk")
	check(start and start.y == 21 and rare and #rare == 3 and
		grug_zones.biome_at(start.x, start.z) == "grug_meadows",
		"representative stable query/anchor differs")
	check(protection_core.is_protected({hard = false}, "alice") == false and
		protection_core.is_protected({hard = true}, "alice") == true and
		protection_core.is_protected({hard = false, prior = true}, "alice") == true and
		protection_core.is_protected({hard = true}, "bypass") == false and
		protection_core.is_protected({hard = false}, "") == true,
		"protection wrapper semantics differ")
	row("authority/start", table.concat({start.x, start.y, start.z}, "/"))
	row("authority/rare_route_sha256", hex_sha256(graph(rare)))
	row("authority/protection", "pre_closed/post_open/hard/prior/bypass/empty")
	rawset(_G, "core", saved_core)
	rawset(_G, "grug_core", saved_grug_core)
	rawset(_G, "grug_zones", saved_grug_zones)

	-- The production harvest seam denies herbs until its sole authorizer exists,
	-- and only literal true opens the exact current request.
	local harvest_engine = {get_us_time = function() return 0 end,
		chat_send_player = function() end}
	local harvest = dofile(repo .. "/mods/ITEMS/grug_gathering/harvest.lua")({
		core = harvest_engine, materials = {}})
	local herb
	for index = 1, #p9g_rows do
		if p9g_rows[index].key == "gravemoss" then herb = p9g_rows[index] break end
	end
	check(herb, "representative herb row is absent")
	local allowed, reason = harvest.decision({}, nil, herb)
	check(allowed == false and reason == "profession_unavailable",
		"missing herb authorizer did not fail closed")
	harvest.register_herb_authorizer(function(_, key, group)
		return key == "gravemoss" and group == 1
	end)
	allowed, reason = harvest.decision({}, nil, herb)
	check(allowed == true and reason == nil, "authorized herb request was denied")
	expect_failure(function() harvest.register_herb_authorizer(function() end) end,
		"already registered")
	row("gathering/herb_authority", "closed/authorized/single_registration")

	-- Execute the actual changed shared R6 writer with the real R7 successor at
	-- its private tail seam.  The owner data is deliberately synthetic and
	-- bounded: exhaustive 512k-buffer/runtime authenticity belongs to the
	-- LuaJIT integration receipt, while this transaction is small enough for the
	-- one final fallback-interpreter process.
	function content_wrapper.surfaces()
		return {{id = corn_biome, top = support_name, filler = support_name,
			shore = support_name, bed = support_name, dust = support_name,
			filler_depth = 1, top_ref = support_ref, filler_ref = support_ref,
			shore_ref = support_ref, bed_ref = support_ref, dust_ref = 0}}
	end
	function content_wrapper.resources() return {} end
	function content_wrapper.cultural() return {} end
	function content_wrapper.decorations() return {} end
	function content_wrapper.wp43_projection()
		return {tiers = {{y_min = -31000, node = support_name}}, race_regions = {}}
	end
	function content_wrapper.content_ref(name) return production_ref[name] end
	function content_wrapper.param2_kind() return "none" end
	local empty_anchor_config = {new = function()
		return {bind_plan = function() end,
			settle = function()
				return {schema = "grug_wp40_r7_anchor_ledger_v1",
					roster_sha256 = anchor_roster_sha256, operations = {}, written = 0}
			end, metrics = function() return {schema = "micro_anchor_metrics"} end,
			roster = function() return {sha256 = anchor_roster_sha256} end}
	end}
	local successor = dofile(wp40 .. "/r7_successor.lua")(
		successor_config, empty_anchor_config).new(successor_dependencies)

	local settlement_hash = dofile(wp40 .. "/r6_hash.lua")(raw_sha256)
	local map_adapter_factory = dofile(wp40 .. "/map_adapter.lua")
	check(type(map_adapter_factory) == "function",
		"R5 map-adapter factory did not load")
	local settlement_factory = dofile(wp40 .. "/r6_settlement.lua")
	local micro_allocator = {}
	function micro_allocator.new_array() return {} end
	function micro_allocator.new_map() return {} end
	function micro_allocator.grow(_, values, _, old_size, new_size)
		for index = old_size + 1, new_size do values[index] = 0 end
	end
	function micro_allocator.map_put(_, values, _, key, value)
		values[key] = value
	end
	function micro_allocator.seal_construction() end
	function micro_allocator.enter_hotpath() end
	function micro_allocator.leave_hotpath() end
	function micro_allocator.metrics()
		return {hotpath_table_allocations = 0, construction_sealed = true}
	end
	local construction_identity = {value = {schema = "micro_identity"}}
	local r5_adapter = {}
	function r5_adapter.apply()
		return "micro_r5_projection"
	end
	local settlement_horizontal = {}
	function settlement_horizontal.static_exclusion_values_at() return nil end
	function settlement_horizontal.housing_mask_id_at() return nil end
	local planner_source = {}
	function planner_source.column_values_at(x, z)
		if x == 0 and z == 0 then
			return "land", 1, corn_zone, corn_biome, "human", 5
		end
		return "land", 1, "micro_no_zone", corn_biome, "human", 0
	end
	local source_anchor = {id = "micro_apex", position = {x = 10000, z = 10000}}
	local source = {claim_exclusions = {}, routes = {}, hard_protection = {},
		anchors = {source_anchor}, apex_sockets = {}, hydrology_profiles = {},
		hydrology = {}, hydrology_interfaces = {}}
	for index = 1, 24 do
		source.apex_sockets[index] = {id = "micro_socket_" .. index,
			anchor_id = source_anchor.id, offset = {x = index, z = 0}}
	end
	local settlement, settlement_fixture = settlement_factory.new({
		full_seed_string = "0", r5_adapter = r5_adapter, content = content_wrapper,
		templates = {}, hash = settlement_hash, horizontal = settlement_horizontal,
		planner_source = planner_source, construction_identity = construction_identity,
		cultural_registrations = {}, source = source, successor_tail = successor,
		counting_allocator = micro_allocator})

	local owner_min, owner_max = {x = -32, y = 0, z = -32},
		{x = 47, y = 79, z = 47}
	local full_column_values = {}
	for index = 1, 6400 * 12 do full_column_values[index] = 0 end
	local full_active_column = ((0 - owner_min.z) * 80 + (0 - owner_min.x)) + 1
	local column_base = (full_active_column - 1) * 12
	full_column_values[column_base + 5] = 5
	full_column_values[column_base + 7] = 1
	full_column_values[column_base + 8] = support_ref
	local column_start = {}
	for index = 1, full_active_column do column_start[index] = 1 end
	for index = full_active_column + 1, 6401 do column_start[index] = 2 end
	local r5_run_values = {5, 5, 7, 28, 0, 0, 0, 0, 0}
	local full_plan = {schema = "grug_wp40_r6_refinement_plan_v1",
		construction_identity = construction_identity.value, generation = 1,
		valid = true, min_x = owner_min.x, min_y = owner_min.y,
		min_z = owner_min.z, max_x = owner_max.x, max_y = owner_max.y,
		max_z = owner_max.z, r5_plan = {column_start = column_start,
			run_values = r5_run_values}, r5_generation = 1,
		column_values = full_column_values, column_count = 6400,
		candidate_cell_values = {}, candidate_cell_count = 0,
		candidate_values = {}, candidate_count = 0, stable_refs = {}}
	successor:plan_slice(owner_min, owner_max, full_plan, 1)

	local vm_module = dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
	local axis, volume = 112, 112 * 112 * 112
	local function fixed_array(count, value)
		local result = {}
		for index = 1, count do result[index] = value end
		return result
	end
	local function owner_vm()
		local data = fixed_array(volume, content_set.production.ignore_cid)
		local emerged_min = {x = owner_min.x - 16, y = owner_min.y - 16,
			z = owner_min.z - 16}
		for z = owner_min.z, owner_max.z do
			for y = owner_min.y, owner_max.y do
				for x = owner_min.x, owner_max.x do
					local index = ((z - emerged_min.z) * axis * axis) +
						((y - emerged_min.y) * axis) +
						(x - emerged_min.x) + 1
					data[index] = air_cid
				end
			end
		end
		return vm_module.new({minp = owner_min, maxp = owner_max,
			data = data, param2 = fixed_array(volume, 0),
			light = fixed_array(volume, 15), heightmap = fixed_array(6400, -31007),
			content_contract = content_set.production, water_level = 1,
			ignore_cid = content_set.production.ignore_cid,
			verify_inactive_tail = false})
	end
	local vm, _, observer = owner_vm()
	local saved_transaction_vector = rawget(_G, "vector")
	local transaction_vector_metatable = {}
	local plain_get_emerged_area = vm.get_emerged_area
	function vm.get_emerged_area(self)
		local emerged_min, emerged_max = plain_get_emerged_area(self)
		return setmetatable(emerged_min, transaction_vector_metatable),
			setmetatable(emerged_max, transaction_vector_metatable)
	end
	rawset(_G, "vector", {metatable = transaction_vector_metatable})
	local applied = settlement:apply(vm, owner_min, owner_max, full_plan, 1,
		"fixture")
	rawset(_G, "vector", saved_transaction_vector)
	local ledger = settlement_fixture.last_ledger()
	local run_values, run_count = settlement_fixture.run_values()
	check(type(applied) == "string" and applied:match("^applied_[cplq]+$") and
		type(ledger) == "table" and type(ledger.p9g) == "table" and
		ledger.p9g.accepted == 1 and run_count >= 2,
		"shared R6/P9G transaction differs")
	local accepted_root_y, p9g_run_count = ledger.p9g.operations[1].root_y, 0
	for run = 1, run_count do
		local base = (run - 1) * 9
		if run_values[base + 4] == 35 then
			p9g_run_count = p9g_run_count + 1
			check(run_values[base + 3] == 10 and run_values[base + 6] == 11 and
				run_values[base + 1] <= accepted_root_y and
				accepted_root_y <= run_values[base + 2],
				"P9G shared-run class/policy/root binding differs")
		end
	end
	check(p9g_run_count == 1,
		"P9G did not precede the one shared run derivation")
	local first_calls = observer.metrics()
	local first_snapshot = observer.snapshot()
	for z = first_snapshot.emin.z, first_snapshot.emax.z do
		for y = first_snapshot.emin.y, first_snapshot.emax.y do
			for x = first_snapshot.emin.x, first_snapshot.emax.x do
				if x < owner_min.x or x > owner_max.x or
						y < owner_min.y or y > owner_max.y or
						z < owner_min.z or z > owner_max.z then
					local index = ((z - first_snapshot.emin.z) * axis * axis) +
						((y - first_snapshot.emin.y) * axis) +
						(x - first_snapshot.emin.x) + 1
					check(first_snapshot.data[index] ==
						content_set.production.ignore_cid and
						first_snapshot.param2[index] == 0 and
						first_snapshot.light[index] == 15,
						"read-only halo bytes were not preserved")
				end
			end
		end
	end
	local light_seed_runs = settlement_fixture.last_light_seed_runs()
	check(first_calls.vm_get_data_calls == 1 and
		first_calls.vm_get_param2_calls == 1 and
		first_calls.vm_get_light_calls == 2 and
		first_calls.vm_set_data_calls == 1 and
		first_calls.vm_set_param2_calls <= 1 and
		light_seed_runs > 0 and
		first_calls.vm_set_lighting_calls == light_seed_runs + 1 and
		first_calls.vm_calc_lighting_calls == 1 and
		first_calls.vm_set_light_data_calls <= 1 and
		first_calls.vm_update_liquids_calls <= 1,
		"shared writer fetch/conditional commit bounds differ " .. table.concat({
			tostring(first_calls.vm_get_data_calls),
			tostring(first_calls.vm_get_param2_calls),
			tostring(first_calls.vm_get_light_calls),
			tostring(first_calls.vm_set_data_calls),
			tostring(first_calls.vm_set_param2_calls),
			tostring(first_calls.vm_set_lighting_calls),
			tostring(first_calls.vm_calc_lighting_calls),
			tostring(first_calls.vm_set_light_data_calls),
			tostring(first_calls.vm_update_liquids_calls)}, "/"))
	local run_fields = {}
	for index = 1, run_count * 9 do
		run_fields[index] = string.format("%.0f", run_values[index])
	end
	local writer_metrics, successor_metrics = settlement:metrics(), successor:metrics()
	check(writer_metrics.apply_calls == 1 and writer_metrics.replay_count == 1 and
		successor_metrics.p9g.settle_calls == 1 and
		successor_metrics.p9g.replay_calls == 1 and
		successor_metrics.schema == "grug_wp40_r7_successor_metrics_v1",
		"shared writer metrics differ")
	row("production/owner_transaction", applied .. "/" .. tostring(run_count))
	row("production/owner_run_sha256", hex_sha256(table.concat(run_fields, "\t")))
	row("production/owner_ledger_sha256", hex_sha256(graph(ledger)))
	row("production/commit_calls", table.concat({first_calls.vm_set_data_calls,
		first_calls.vm_set_param2_calls, first_calls.vm_set_light_data_calls,
		first_calls.vm_update_liquids_calls}, "/"))
	row("production/replay_metrics", table.concat({writer_metrics.apply_calls,
		writer_metrics.replay_count, successor_metrics.p9g.settle_calls,
		successor_metrics.p9g.replay_calls}, "/"))
	row("production/emerged_vector_normalized", "true")
	row("production/readonly_halo_ignore_preserved", "true")

	local missing = {}
	for index = 1, #changed_order do
		local relative = changed_order[index]
		if not executed[relative] then missing[#missing + 1] = relative end
	end
	check(#missing == 0, "changed modules not executed: " .. table.concat(missing, ","))
	row("source/executed_module_count", #changed_order)
	row("source/executed_module_roster_sha256",
		hex_sha256(table.concat(changed_order, "\n") .. "\n"))
	for index = 1, #changed_order do
		row("executed_module", changed_order[index])
	end
	rawset(_G, "dofile", saved_dofile)

	return rows
end
