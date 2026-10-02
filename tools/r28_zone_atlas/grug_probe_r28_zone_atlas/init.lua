-- Disposable engine probe (Round 28 Lane C0, zone facts atlas). Never shipped:
-- tools/r28_zone_atlas/probe.sh stages it through tools/luanti_headless.sh.
--
-- After every mod has loaded it dumps, as one JSON file in the world folder
-- (r28_zone_atlas_probe.json), what only the running game knows:
--   * every registered settlement with its anchor and its service sockets
--     (quest, vendor, trainer, innkeeper, riding trainer, housing steward,
--     king, displays) plus counts of the resident and guard sockets;
--   * the quest NPCs (settlement/socket bindings) and every registered quest;
--   * the mob registry (description, tier, disposition fields) and every
--     spawn ABM row (host nodes, height window);
--   * per named zone the day and night mob casts of its spawn recipe and, on
--     its region map for this seed, the land cells (32 x 32 nodes) where each
--     species spawns by day and by night with the level range it spawns at;
--   * the rares and camp types;
--   * the settlement core boxes of the world protection (scanned with
--     grug_core.world_feature_at around each settlement anchor).
-- No world is emerged; every query is analytic.

local P = "[r28_zone_atlas_probe] "
local function log(msg) core.log("action", P .. msg) end

local function round(v) return math.floor(v + 0.5) end
local function pos3(p) return {x = round(p.x), y = round(p.y), z = round(p.z)} end

-- Roles whose sockets are only counted (residents, guards).
local COUNT_ONLY = {idle = true, work = true, guard_patrol = true, guard_post = true}

local function copy_plain(t)
	local out = {}
	for k, v in pairs(t) do
		local kind = type(v)
		if kind == "string" or kind == "number" or kind == "boolean" then out[k] = v end
	end
	return out
end

local function run()
	local started = core.get_us_time()
	local out = {seed = core.get_mapgen_setting("seed"), settlements = {},
		quest_npcs = {}, quests = {}, mobs = {}, spawn_rows = {}, zones = {},
		rares = {}, camp_types = {}, feature_boxes = {}, starts = {}}

	-- 1. Settlements and their service sockets.
	for _, rec in ipairs(grug_core.settlement_socket_settlements()) do
		local sockets, counts = {}, {}
		for _, s in ipairs(grug_core.settlement_sockets_at(rec.key)) do
			counts[s.role] = (counts[s.role] or 0) + 1
			if not COUNT_ONLY[s.role] then
				sockets[#sockets + 1] = {id = s.id, role = s.role, pos = pos3(s.pos),
					kind = s.kind, profession = s.profession, activity = s.activity,
					tag = s.tags and s.tags[1] or nil}
			end
		end
		out.settlements[#out.settlements + 1] = {key = rec.key,
			display_name = rec.display_name, race_id = rec.race_id,
			anchor = pos3(rec.anchor), sockets = sockets, counts = counts}
	end
	for _, row in ipairs(grug_core.start_identities()) do
		out.starts[#out.starts + 1] = {race_id = row.race_id, faction_id = row.faction_id,
			anchor = pos3(row.anchor),
			capital = pos3(grug_core.capital_anchor(row.faction_id, row.race_id))}
	end
	log(("settlements: %d"):format(#out.settlements))

	-- 2. Quest NPCs and quests.
	for id, npc in pairs(grug_quests.registered_npcs) do
		out.quest_npcs[#out.quest_npcs + 1] = {id = id, settlement = npc.settlement,
			socket = npc.socket, title = npc.title}
	end
	table.sort(out.quest_npcs, function(a, b) return a.id < b.id end)
	for id, def in pairs(grug_quests.registered_quests) do
		local objectives = {}
		for _, o in ipairs(def.objectives) do
			local row = copy_plain(o)
			if o.mobs then row.mobs = table.copy(o.mobs) end
			objectives[#objectives + 1] = row
		end
		-- The text as the giver reads it on this seed (placeholders filled).
		local description = grug_quests.quest_text(def, true):gsub("\n\nRequirements:.*$", "")
		out.quests[#out.quests + 1] = {id = id, title = def.title, npc = def.npc,
			turnin_npc = def.turnin_npc, min_level = def.min_level, level = def.level,
			prerequisites = table.copy(def.prerequisites), objectives = objectives,
			xp = grug_quests.reward_xp(def), copper = def.rewards.copper,
			reward_items = table.copy(def.rewards.items), description = description,
			repeatable = def.repeatable}
	end
	table.sort(out.quests, function(a, b) return a.id < b.id end)
	log(("quest npcs: %d, quests: %d"):format(#out.quest_npcs, #out.quests))

	-- 3. Mob registry and spawn rows.
	for name, def in pairs(core.registered_entities) do
		if name:find("^grug_mobs:") or name:find("^grug_traders:") then
			local row = {name = name, description = def.description, type = def.type,
				passive = def.passive, attack_players = def.attack_players,
				attack_type = def.attack_type, view_range = def.view_range,
				hp_max = def.hp_max, light_damage = def.light_damage,
				disposition = grug_mobs.disposition and grug_mobs.disposition(name) or nil}
			for k, v in pairs(def) do
				if type(k) == "string" and k:find("^_grug_") and
						(type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
					row[k] = v
				end
			end
			out.mobs[#out.mobs + 1] = row
		end
	end
	table.sort(out.mobs, function(a, b) return a.name < b.name end)
	for _, abm in ipairs(core.registered_abms) do
		local name = type(abm.label) == "string" and abm.label:match("^(%S+) spawning$")
		if name then
			out.spawn_rows[#out.spawn_rows + 1] = {name = name,
				nodenames = table.copy(abm.nodenames or {}),
				neighbors = table.copy(abm.neighbors or {}),
				min_y = abm.min_y, max_y = abm.max_y,
				interval = abm.interval, chance = abm.chance}
		end
	end
	table.sort(out.spawn_rows, function(a, b) return a.name < b.name end)

	-- 4. Casts per zone from the spawn recipes (Round 28 S2: every named
	-- zone has one, the former ABM palettes are gone): the zone's region map
	-- for this seed (grug_mobs.spawn_regions), per mob and clock the land
	-- cells whose region (a kind or a camp) spawns it then and the role's
	-- level range there; the zone's level histogram by region level.
	local SR = grug_mobs.spawn_regions
	local regions_total = 0
	for _, zone_id in ipairs(SR.zone_ids()) do
		local map = SR.map(zone_id)
		if map then
			local cells, species, levels = 0, {}, {}
			local cast = {day = {}, night = {}}
			for _, r in ipairs(map.regions) do
				local unit = r.camp or r.kind
				local n = r.size -- the region's cell count (compact map, Round 30 P3)
				cells = cells + n
				levels[r.level] = (levels[r.level] or 0) + n
				for _, clock in ipairs({"day", "night"}) do
					for _, row in ipairs(unit.rosters[clock].list) do
						local name = "grug_mobs:" .. row.role
						local range = unit.levels_by_role[row.role]
						local s = species[name]
						if not s then
							s = {day = {count = 0}, night = {count = 0}}
							species[name] = s
						end
						local c = s[clock]
						c.count = c.count + n
						if not c.min or range[1] < c.min then c.min = range[1] end
						if not c.max or range[2] > c.max then c.max = range[2] end
						cast[clock][name] = true
					end
				end
			end
			regions_total = regions_total + #map.regions
			local row = {id = zone_id, recipe = true, land_points = cells,
				day_cast = {}, night_cast = {}, density_day = {}, density_night = {},
				level_histogram = {}, spawns = {}}
			for _, clock in ipairs({"day", "night"}) do
				for name in pairs(cast[clock]) do
					table.insert(row[clock .. "_cast"], name)
				end
				table.sort(row[clock .. "_cast"])
			end
			for level, n in pairs(levels) do
				row.level_histogram[#row.level_histogram + 1] = {level, n}
			end
			table.sort(row.level_histogram, function(a, b) return a[1] < b[1] end)
			for name, s in pairs(species) do
				row.spawns[#row.spawns + 1] = {name = name, day = s.day, night = s.night}
			end
			table.sort(row.spawns, function(a, b) return a.name < b.name end)
			out.zones[#out.zones + 1] = row
		end
	end
	log(("spawn regions: %d zones, %d regions"):format(#out.zones, regions_total))

	-- 5. Rares and camp types.
	for id, spec in pairs(grug_mobs.registered_rares or {}) do
		local route = {}
		for _, p in ipairs(spec.route or {}) do route[#route + 1] = pos3(p) end
		out.rares[#out.rares + 1] = {id = id, name = spec.name, mob = spec.mob,
			biome_hint = spec.biome_hint, respawn_min = spec.respawn_min,
			respawn_max = spec.respawn_max, route = route}
	end
	table.sort(out.rares, function(a, b) return a.id < b.id end)
	for id, def in pairs(grug_mobs.registered_camp_types or {}) do
		local row = copy_plain(def)
		row.id = id
		out.camp_types[#out.camp_types + 1] = row
	end
	table.sort(out.camp_types, function(a, b) return a.id < b.id end)

	-- 6. Settlement core boxes (world protection), scanned around each anchor.
	for _, s in ipairs(out.settlements) do
		local a = s.anchor
		local box, kind
		for dz = -48, 48 do
			for dx = -48, 48 do
				local k = grug_core.world_feature_at({x = a.x + dx, y = a.y + 1, z = a.z + dz})
				if k == "village" or k == "camp" or k == "poi" then
					kind = k
					if not box then
						box = {min_x = a.x + dx, max_x = a.x + dx, min_z = a.z + dz, max_z = a.z + dz}
					else
						if a.x + dx < box.min_x then box.min_x = a.x + dx end
						if a.x + dx > box.max_x then box.max_x = a.x + dx end
						if a.z + dz < box.min_z then box.min_z = a.z + dz end
						if a.z + dz > box.max_z then box.max_z = a.z + dz end
					end
				end
			end
		end
		if box then
			box.key, box.kind = s.key, kind
			out.feature_boxes[#out.feature_boxes + 1] = box
		end
	end

	out.seconds = (core.get_us_time() - started) / 1e6
	local path = core.get_worldpath() .. "/r28_zone_atlas_probe.json"
	local f = assert(io.open(path, "w"))
	f:write(assert(core.write_json(out, true)))
	f:close()
	log(("wrote %s in %.1f s"):format(path, out.seconds))
	log("RESULT PASS")
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local ok, err = pcall(run)
		if not ok then
			core.log("error", P .. "FAIL " .. tostring(err))
			core.request_shutdown("probe failed", false, 0)
		end
	end)
end)
