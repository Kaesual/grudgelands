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
--   * per named zone the day and night mob casts (spawn_policy.lua) and, on a
--     24-node grid of dry land, where each cast species may spawn by day and by
--     night (grug_mobs.spawn_allowed, or the policy alone for the few species
--     whose own check reads map nodes) with the level range it spawns at,
--     also per logical biome (the builder matches biome top nodes against
--     the spawn rows' host nodes);
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
-- Species whose own _grug_spawn_check reads map nodes: only the policy is
-- evaluated for them (no world is loaded).
local NODE_CHECK = {
	["grug_mobs:skeleton_archer"] = true, ["grug_mobs:shore_crab"] = true,
	["grug_mobs:reef_lurker"] = true, ["grug_mobs:reed_angelfish"] = true,
	["grug_mobs:kraken"] = true,
}
local SHORE = {"grug_mobs:shore_crab", "grug_mobs:reef_lurker", "grug_mobs:gull"}
local STEP = 24

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
		local description = def.description:gsub("\n\nRequirements:.*$", "")
		out.quests[#out.quests + 1] = {id = id, title = def.title, npc = def.npc,
			turnin_npc = def.turnin_npc, min_level = def.min_level,
			prerequisites = table.copy(def.prerequisites), objectives = objectives,
			xp = def.rewards.xp, copper = def.rewards.copper,
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

	-- 4. Casts per zone and the spawn sampling.
	local zone_ids = grug_mobs.density_zone_ids()
	local per_zone = {}
	for _, zone_id in ipairs(zone_ids) do
		local day = grug_mobs.zone_clock_cast(zone_id, "day") or {}
		local night = grug_mobs.zone_clock_cast(zone_id, "night") or {}
		local candidates, seen = {}, {}
		for _, list in ipairs({day, night, SHORE}) do
			for _, name in ipairs(list) do
				if not seen[name] then seen[name] = true; candidates[#candidates + 1] = name end
			end
		end
		per_zone[zone_id] = {candidates = candidates, land = 0, levels = {},
			species = {}}
		out.zones[#out.zones + 1] = {id = zone_id, day_cast = day, night_cast = night,
			density_day = grug_mobs.zone_density_cast(zone_id, "day"),
			density_night = grug_mobs.zone_density_cast(zone_id, "night")}
	end
	local function allowed(name, pos)
		if NODE_CHECK[name] then return grug_mobs.spawn_policy_allows(name, pos) end
		return grug_mobs.spawn_allowed(name, pos)
	end
	local points = {}
	for z = -3200, 3200, STEP do
		for x = -3600, 3600, STEP do
			if grug_zones.water_class_at(x, z) == "land" then
				local zone_id = grug_zones.id_at(x, z)
				local zone = zone_id and per_zone[zone_id]
				if zone then
					local y = grug_zones.terrain_height_at(x, z)
					points[#points + 1] = {x = x, y = y, z = z, zone = zone,
						biome = grug_zones.biome_at(x, z) or "none"}
					zone.land = zone.land + 1
				end
			end
		end
	end
	for clock_index, clock in ipairs({"day", "night"}) do
		core.set_timeofday(clock == "day" and 0.5 or 0.0)
		for _, p in ipairs(points) do
			local zone = p.zone
			local pos = {x = p.x, y = p.y, z = p.z}
			local level = grug_zones.mob_level_at({x = p.x, y = p.y + 1, z = p.z})
			if clock_index == 1 and level then
				zone.levels[level] = (zone.levels[level] or 0) + 1
			end
			for _, name in ipairs(zone.candidates) do
				if allowed(name, pos) then
					local s = zone.species[name]
					if not s then
						s = {day = {count = 0}, night = {count = 0}}
						zone.species[name] = s
					end
					local c = s[clock]
					c.count = c.count + 1
					c.biomes = c.biomes or {}
					local b = c.biomes[p.biome]
					if not b then b = {count = 0}; c.biomes[p.biome] = b end
					b.count = b.count + 1
					if level then
						if not c.min or level < c.min then c.min = level end
						if not c.max or level > c.max then c.max = level end
						if not b.min or level < b.min then b.min = level end
						if not b.max or level > b.max then b.max = level end
					end
				end
			end
		end
	end
	core.set_timeofday(0.5)
	for _, row in ipairs(out.zones) do
		local zone = per_zone[row.id]
		row.land_points = zone.land
		row.level_histogram = {}
		for level, count in pairs(zone.levels) do
			row.level_histogram[#row.level_histogram + 1] = {level, count}
		end
		table.sort(row.level_histogram, function(a, b) return a[1] < b[1] end)
		row.spawns = {}
		for name, s in pairs(zone.species) do
			row.spawns[#row.spawns + 1] = {name = name, day = s.day, night = s.night,
				node_check_skipped = NODE_CHECK[name] or nil}
		end
		table.sort(row.spawns, function(a, b) return a.name < b.name end)
	end
	log(("spawn sampling: %d land points"):format(#points))

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
