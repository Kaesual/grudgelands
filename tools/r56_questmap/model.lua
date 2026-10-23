-- Round 56 lane QUESTMAP: every shipped quest as the game registers it.
--
--   local model = dofile(REPO .. "/tools/r56_questmap/model.lua")(REPO [, DATA])
--
-- DATA (optional, Round 57): a folder whose data/zones holds the quest files
-- to read instead of the shipped ones (a fixture's sample, a lane's draft);
-- the code stays the repository's.
-- Runs the REAL grug_quests registry.lua, labels.lua, npcs.lua, validate.lua
-- and loader.lua over the shipped zone files (data/zones), with the real
-- spawn recipes (tools/r28_b1/load_spawn_areas.lua), the real mob names
-- (data/names.json through names_core.lua), the real zone records
-- (grug_mapgen wp40/source/simple_map.lua) and the real XP formula
-- (grug_xp/init.lua) under a small engine stub. The loader's structure
-- checks run as at server start; the world checks (items, entities, level
-- fit) need the whole game and are left to the engine and
-- tools/r28_design/validate.py. Copper is the loader's (Q.quest_copper, or a
-- quest's own `copper`), XP grug_quests.reward_xp's (before the race bonus).
--
-- Returns {zones, quests, npcs, warnings}: plain tables, see build() below.
-- Plain Lua 5.1 / LuaJIT; reads only, writes nothing.
return function(repo, data_root)
	repo = repo or "."
	local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
	-- The globals the loaded files use, put back as they were at the end.
	local GLOBALS = {"core", "grug_core", "grug_zones", "grug_mobs", "grug_quests", "grug_xp",
		"grug_money", "grug_mapgen", "ItemStack", "vector"}
	local saved = {}
	for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
	local had_copy = table.copy

	local function deep_copy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for k, v in pairs(value) do out[deep_copy(k)] = deep_copy(v) end
		return out
	end
	table.copy = deep_copy

	-- The engine surface the loaded files touch at load; any other
	-- register_* call is a no-op.
	local warnings = {}
	local code = repo .. "/mods/PLAYER/grug_quests"
	local paths = {grug_quests = code,
		grug_mobs = repo .. "/mods/ENTITIES/grug_mobs", grug_xp = repo .. "/mods/PLAYER/grug_xp",
		grug_money = repo .. "/mods/PLAYER/grug_money", grug_mapgen = repo .. "/mods/MAPGEN/grug_mapgen"}
	local current = "grug_quests"
	local engine = {
		registered_items = {}, registered_aliases = {}, registered_entities = {},
		get_modpath = function(name) return paths[name] end,
		get_current_modname = function() return current end,
		get_dir_list = function(path)
			local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
			local out = {}
			for line in handle:lines() do out[#out + 1] = line end
			handle:close()
			return out
		end,
		parse_json = function(text) return (json.decode(text)) end,
		log = function(level, message) warnings[#warnings + 1] = level .. ": " .. message end,
		settings = {get = function() return nil end, get_bool = function() return nil end},
		get_mod_storage = function()
			return {get_string = function() return "" end, set_string = function() end,
				get_int = function() return 0 end, set_int = function() end}
		end,
	}
	rawset(_G, "core", setmetatable(engine, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return function() end end
		return nil
	end}))
	rawset(_G, "vector", {distance = function() return 0 end})
	rawset(_G, "ItemStack", function(item)
		local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
		return {get_name = function() return name end, get_count = function() return tonumber(count) or 1 end,
			is_empty = function() return name == "" end}
	end)

	-- Zones: the mapgen's own records.
	local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	local zone_by_id = {}
	for _, zone in ipairs(source.zones) do zone_by_id[zone.id] = zone end
	rawset(_G, "grug_zones", {
		get = function(id) return zone_by_id[id] end,
		id_at = function() return nil end,
		-- A named place's position (spawn_regions place): any spot will do,
		-- only its name is read.
		anchor = function() return {x = 0, z = 0} end,
	})

	-- Settlement sockets: every quest NPC stands on its own socket (sockets
	-- exist before terrain; their positions do not matter here). A PvP
	-- fortress is bound, so its three givers register (npcs.lua), and so are
	-- the Miner's Guild's camps and capitals with their foremen and leaders
	-- (Round 58, tools/r58_guildquests/guild_world.lua).
	local guild_world = dofile(repo .. "/tools/r58_guildquests/guild_world.lua")(repo)
	rawset(_G, "grug_mapgen", {mining_camps = guild_world.mining_camps})
	local sockets = {}
	rawset(_G, "grug_core", {
		register_tag_visibility = function() end,
		register_level_overlay = function() end,
		settlement_socket_anchor = function(key)
			return (key:find("^pvp_fortress_") or guild_world.anchor(key)) and {x = 0, y = 0, z = 0} or nil
		end,
		settlement_socket_settlements = function()
			local out = {}
			for key in pairs(sockets) do
				out[#out + 1] = {key = key, anchor = {x = 0, y = 0, z = 0}, race_id = guild_world.race_of[key]}
			end
			-- A camp under construction is of its builder's race, so its
			-- captain has a name on every world (labels.lua Q.captain_name).
			for _, site in ipairs(guild_world.mining_camps.under_construction) do
				out[#out + 1] = {key = site.id, anchor = {x = 0, y = 0, z = 0}, race_id = site.race}
			end
			table.sort(out, function(a, b) return a.key < b.key end)
			return out
		end,
		settlement_sockets_at = function(key) return sockets[key] or {} end,
		hud_layout = {side_text_width = function() return 38 end},
	})
	dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
	rawset(_G, "grug_mobs", {
		register_on_eligible_kill = function() end,
		register_participant_drop_hook = function() end,
		disposition = function() return "aggressive" end,
	})
	dofile(repo .. "/tools/r28_b1/load_spawn_areas.lua")(repo)
	grug_mobs.names = dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo)
	-- The PvP garrisons (grug_mobs init.lua): a camp's label and its guards'
	-- names. A captain's name follows the camp's race, rolled per world, so
	-- it stays unknown here.
	do
		local handle = assert(io.open(paths.grug_mobs .. "/data/pvp_names.json", "r"))
		local names = json.decode(handle:read("*a"))
		handle:close()
		grug_mobs.pvp_garrison = dofile(paths.grug_mobs .. "/pvp_garrison.lua").new(
			dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua"), names, guild_world.camp_catalog)
	end

	-- The XP formula (grug_quests.reward_xp) and the money format.
	for _, mod in ipairs({"grug_xp", "grug_money"}) do
		current = mod
		rawset(_G, mod, nil)
		dofile(paths[mod] .. "/init.lua")
	end
	current = "grug_quests"

	-- use.lua hooks the quest state (state.lua, not loaded: no players).
	rawset(_G, "grug_quests", {register_on_change = function() end})
	for _, file in ipairs({"registry", "labels", "npcs", "use"}) do dofile(code .. "/" .. file .. ".lua") end
	-- The quest files from here on (use.lua read its object kinds above).
	paths.grug_quests = data_root or code
	local base = paths.grug_quests .. "/"
	for _, npc in pairs(grug_quests.registered_npcs) do
		sockets[npc.settlement] = sockets[npc.settlement] or {}
		table.insert(sockets[npc.settlement], {id = npc.socket, role = "quest", pos = {x = 0, y = 0, z = 0}})
	end
	-- A new giver (loader.lua) looks for a free quest socket in its hub's
	-- settlement: offer every socket a new giver names there.
	do
		for _, name in ipairs(engine.get_dir_list(base .. "data/zones")) do
			local file = io.open(base .. "data/zones/" .. name)
			local data = file and json.decode(file:read("*a"))
			if file then file:close() end
			for _, hub in ipairs(type(data) == "table" and data.hubs or {}) do
				for _, giver in ipairs(hub.givers or {}) do
					if giver.new and giver.new.socket then
						sockets[hub.anchor] = sockets[hub.anchor] or {}
						table.insert(sockets[hub.anchor], {id = giver.new.socket, role = "quest",
							pos = {x = 0, y = 0, z = 0}})
					end
				end
			end
		end
	end
	for _, file in ipairs({"validate", "loader"}) do dofile(code .. "/" .. file .. ".lua") end
	local Q = grug_quests

	-- The model -------------------------------------------------------------
	local model = {zones = {}, quests = {}, npcs = {}, warnings = warnings}
	local hub_of = {} -- "<zone>/<npc>" -> hub id
	local zone_files = {}
	for _, file in ipairs(Q.quest_files) do
		local zone = zone_by_id[file.zone]
		local row = zone_files[file.zone]
		if not row then
			row = {id = file.zone, name = zone and zone.display_name or file.zone,
				faction = zone and zone.faction or false, race = zone and zone.race_region or false,
				level_min = zone and zone.level_min or false, level_max = zone and zone.level_max or false,
				territory = zone and zone.territory_rule or false,
				identity = false, hubs = {}, files = {}}
			zone_files[file.zone] = row
			model.zones[#model.zones + 1] = row
		end
		row.files[#row.files + 1] = file.name
		if not file.front then
			row.identity = file.data.identity or false
			for _, hub in ipairs(file.data.hubs or {}) do
				local givers = {}
				for _, giver in ipairs(hub.givers) do
					givers[#givers + 1] = {npc = giver.npc, lines = giver.lines}
					hub_of[file.zone .. "/" .. giver.npc] = hub.id
				end
				local place = grug_mobs.spawn_regions.place(hub.anchor)
				row.hubs[#row.hubs + 1] = {id = hub.id, anchor = hub.anchor,
					name = place and place.name or hub.id, givers = givers}
			end
		end
	end

	local function title_case(text)
		return (text:gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
	end
	local function npc_name(id)
		local npc = Q.registered_npcs[id]
		return npc and npc.title or id
	end
	-- An area's name (a kind, a camp or a PvP camp), or false.
	local function area_name(zone, ref)
		local target = ref and Q.placeholder_target(zone, ref)
		return target and target.name or false
	end
	-- The names a kill counts or an item's named source drops from, as the
	-- loader resolves them (labels.lua Q.target_names); a PvP captain's name
	-- follows his camp's race, which every world rolls.
	local function target_names(by_role, roles)
		local names, seen = {}, {}
		for index, list in ipairs(by_role) do
			if #list == 0 then
				local role = roles[index] or "?"
				list = {title_case(role) .. (role:find("^captain_") and " (named per world)" or "")}
			end
			for _, name in ipairs(list) do
				if not seen[name] then seen[name] = true; names[#names + 1] = name end
			end
		end
		return names
	end
	local function objective_row(def, raw, zone)
		local row = {type = def.type, count = def.count}
		if def.type == "kill" then
			row.roles = raw.roles or {}
			row.names = target_names(def.names, row.roles)
			row.area = def.area or false
			row.area_name = area_name(zone, def.area)
		elseif def.type == "item" then
			row.item = def.item or false
			row.group = def.group or false
			row.roles = raw.roles or {}
			row.area = raw.area and Q.validate.area_ref(raw.area, zone) or false
			row.area_name = area_name(zone, row.area)
			row.names = #row.roles > 0 and target_names(Q.target_names(Q.validate.target_names(raw), row.area or nil,
				zone), row.roles) or {}
		elseif def.type == "use" then
			row.place = def.place
			row.place_name = def.place_name or def.place
			row.object, row.label = def.object, def.label
		else
			row.npc = def.npc
			row.npc_name = npc_name(def.npc)
		end
		return row
	end
	local function fill(text, zone)
		return (Q.fill_names(text, zone):gsub("{[%w_]+:[^}]*}", "[place]"))
	end
	for _, entry in ipairs(Q.validate.each_quest(Q.quest_files)) do
		local raw, file = entry.quest, entry.file
		local def = Q.registered_quests[raw.id]
		-- Round 57: one row per quest, its variants (one per giver zone)
		-- with their own givers, turn-ins, hubs, objectives and text.
		local variants = {}
		for index, variant in ipairs(Q.validate.variants(file, raw)) do
			local registered = def.variant_by_key[variant.key]
			local rows = {}
			for i, objective in ipairs(registered.objectives) do
				rows[i] = objective_row(objective, variant.objectives[i], variant.zone)
			end
			local givers, giver_names, turnin_names = {}, {}, {}
			for _, npc in ipairs(registered.givers) do
				givers[#givers + 1] = npc
				giver_names[#giver_names + 1] = npc_name(npc)
			end
			for _, role in ipairs(registered.giver_roles) do
				giver_names[#giver_names + 1] = "every " .. role.role .. " of the " .. role.faction
			end
			for _, npc in ipairs(registered.turnins) do turnin_names[#turnin_names + 1] = npc_name(npc) end
			local zone = zone_by_id[variant.zone]
			variants[index] = {zone = variant.zone, zone_name = zone and zone.display_name or variant.zone,
				hub = givers[1] and hub_of[variant.zone .. "/" .. givers[1]] or false,
				givers = givers, giver_names = giver_names, turnins = registered.turnins,
				turnin_names = turnin_names, objectives = rows,
				text = fill(variant.text or raw.text, variant.zone)}
		end
		local objectives = variants[1].objectives
		local items = {}
		for _, item in ipairs(raw.rewards.items or {}) do
			items[#items + 1] = {item = item.item, count = item.count or 1}
		end
		-- Round 57 ruling 15: the choice, each with its fixed enchants.
		local choices = {}
		for _, choice in ipairs(raw.rewards.choices or {}) do
			local affixes = {}
			for _, affix in ipairs(choice.affixes or {}) do affixes[#affixes + 1] = affix.channel .. " " .. affix.stat end
			choices[#choices + 1] = {item = choice.item, count = choice.count or 1, affixes = affixes}
		end
		local drops = {}
		for _, drop in ipairs(def.quest_drops) do drops[#drops + 1] = drop.item end
		-- The text with its names filled (as the title, at load); a direction
		-- differs per world and stays a marker.
		local text = variants[1].text
		model.quests[#model.quests + 1] = {
			id = raw.id, title = def.title, zone = file.zone, file = file.name, front = file.front,
			hub = variants[1].hub, line = raw.line, variants = variants, shared = raw.variants ~= nil,
			story = raw.story == true, completion = raw.completion and fill(raw.completion, file.zone) or false,
			giver = def.npc, giver_name = npc_name(def.npc),
			turnin = def.turnin_npc, turnin_name = npc_name(def.turnin_npc),
			min_level = def.min_level, level = def.level,
			requires = def.prerequisites, objectives = objectives, quest_drops = drops,
			rewards = {weight = def.rewards.weight, copper = def.rewards.copper,
				copper_text = grug_money.format(def.rewards.copper), copper_fixed = raw.rewards.copper ~= nil,
				xp = Q.reward_xp(def), items = items, choices = choices},
			optional = raw.optional == true, climax = raw.climax == true, tags = raw.tags or {},
			duration_min = raw.duration_min or false, text = text, lesson = raw.lesson or false,
		}
	end
	for id, npc in pairs(Q.registered_npcs) do
		model.npcs[id] = {name = npc.title, settlement = npc.settlement}
	end

	for _, name in ipairs(GLOBALS) do rawset(_G, name, saved[name]) end
	table.copy = had_copy
	return model
end
