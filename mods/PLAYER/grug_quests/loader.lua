-- Quest content is data: one file per zone (Round 28 Section B "Content
-- migration", design frame section 4.7),
--   data/zones/<zone_id>.quests.json        the zone's hubs, givers, lines
--                                            and quests;
--   data/zones/<zone_id>.front.quests.json  front quests given by that
--                                            zone's givers on line `front`.
-- The loader checks the files (validate.lua), registers new givers at free
-- quest sockets, then every quest in prerequisite order (requires may cross
-- zones). Roles, areas, levels and items are checked once every mod loaded.
local Q = grug_quests
local V = Q.validate
local DIR = core.get_modpath(core.get_current_modname()) .. "/data/zones"

local function fail(errors)
	error("[grug_quests] quest data errors:\n  " .. table.concat(errors, "\n  "), 0)
end

local function read_files()
	local names = core.get_dir_list(DIR, false) or {}
	table.sort(names)
	local files, errors = {}, {}
	for _, name in ipairs(names) do
		local zone = name:match("^(.+)%.front%.quests%.json$")
		local front = zone ~= nil
		zone = zone or name:match("^(.+)%.quests%.json$")
		if zone then
			local handle = io.open(DIR .. "/" .. name, "r")
			local data = handle and core.parse_json(handle:read("*a"))
			if handle then handle:close() end
			if type(data) ~= "table" then
				errors[#errors + 1] = ("zones/%s: not readable JSON"):format(name)
			end
			files[#files + 1] = {name = name, zone = zone, front = front, data = data}
		end
	end
	if #errors > 0 then fail(errors) end
	return files
end

-- One quest of a file as a registry definition.
local function definition(file, quest)
	local objectives = {}
	for index, objective in ipairs(quest.objectives) do
		local row = {type = objective.type, count = objective.count or 1}
		if objective.type == "kill" then
			row.mobs = V.target_names(objective)
			row.area = V.area_ref(objective.area, file.zone)
			row.zones = Q.target_zones(row.mobs, row.area, file.zone) -- labels.lua
		elseif objective.type == "item" then
			row.item = objective.item
			row.group = objective.group and objective.group:gsub("^group:", "") or nil
		else
			row.npc = objective.npc
		end
		objectives[index] = row
	end
	local drops = {}
	for index, drop in ipairs(quest.quest_drops or {}) do
		drops[index] = {item = drop.item, chance = drop.chance, mobs = V.target_names(drop),
			area = V.area_ref(drop.area, file.zone)}
	end
	local rewards = quest.rewards
	local copper = rewards.copper
	if copper == nil then copper = Q.quest_copper(quest.level, rewards.weight) end
	local items = {}
	for index, item in ipairs(rewards.items or {}) do
		items[index] = item.item .. " " .. (item.count or 1)
	end
	return {
		title = Q.fill_names(quest.title, file.zone), description = quest.text,
		npc = quest.giver, turnin_npc = quest.turnin,
		min_level = quest.min_level, level = quest.level, prerequisites = quest.requires or {},
		objectives = objectives, quest_drops = drops,
		repeatable = quest.repeatable and {cooldown = quest.repeatable.cooldown} or nil,
		rewards = {weight = rewards.weight, copper = copper, items = items},
		zone = file.zone, line = quest.line, source = "zones/" .. file.name,
	}
end

-- The settlement holding a free quest socket of a hub: the hub's anchor when
-- it is a settlement key, else the settlement of the hub's zone that has a
-- quest socket with this id. Free = no quest NPC is bound to it yet.
local function free_socket_settlement(zone, hub, socket_id)
	local found = {}
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		if record.key == hub.anchor or (grug_zones.id_at(record.anchor.x, record.anchor.z) == zone) then
			for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
				if socket.id == socket_id and socket.role == "quest" then
					found[#found + 1] = record.key
				end
			end
		end
	end
	if #found ~= 1 then
		return nil, (#found == 0 and "no quest socket %s in the hub's settlement" or
			"quest socket %s is ambiguous in this zone"):format(socket_id)
	end
	if Q.npc_by_socket[found[1] .. "/" .. socket_id] then
		return nil, ("quest socket %s of %s already has a quest NPC"):format(socket_id, found[1])
	end
	return found[1]
end

-- New givers (`{"npc", "new": {name, race, socket}}`) stand on a free quest
-- socket: the socket-bound NPC system already places a quest shell there;
-- registering the NPC gives it this name, race (start_npcs.lua) and dialogue.
local function register_new_givers(files)
	local errors = {}
	for _, file in ipairs(files) do
		for _, hub in ipairs(not file.front and file.data.hubs or {}) do
			for _, giver in ipairs(hub.givers) do
				if giver.new then
					local key, message = free_socket_settlement(file.zone, hub, giver.new.socket)
					if key then
						Q.register_npc(giver.npc, {settlement = key, socket = giver.new.socket,
							title = giver.new.name, race = giver.new.race})
					else
						errors[#errors + 1] = ("zones/%s: hub %s: giver %s: %s [E-new-giver]")
							:format(file.name, hub.id, giver.npc, message)
					end
				end
			end
		end
	end
	if #errors > 0 then fail(errors) end
end

local function register_quests(files)
	local rows, done = {}, {}
	for _, row in ipairs(V.each_quest(files)) do rows[row.quest.id] = row end
	local ids = {}
	for id in pairs(rows) do ids[#ids + 1] = id end
	table.sort(ids)
	-- validate.lua already refused unknown prerequisites and cycles.
	local function visit(id)
		if done[id] then return end
		done[id] = true
		local row = rows[id]
		for _, required in ipairs(row.quest.requires or {}) do visit(required) end
		Q.register_quest(id, definition(row.file, row.quest))
	end
	for _, id in ipairs(ids) do visit(id) end
end

-- What validate.lua's world checks ask, from the spawn recipes (an area a
-- quest names is a kind or a camp of its zone's recipe, Lane S1, or a PvP
-- POI's garrison, Round 31), the sub-type catalogue (B2) and the registries.
local function read_json(path)
	local handle = io.open(path, "r")
	if not handle then return nil end
	local data = core.parse_json(handle:read("*a"))
	handle:close()
	return data
end

local function world_view()
	local areas = grug_mobs.spawn_regions
	local mobs_data = core.get_modpath("grug_mobs") .. "/data"
	local catalogue = read_json(mobs_data .. "/subtypes.json")
	if type(catalogue) == "table" and not catalogue[1] then catalogue = catalogue.subtypes end
	local levels = {}
	for _, row in ipairs(type(catalogue) == "table" and catalogue or {}) do
		if type(row) == "table" and type(row.role) == "string" then levels[row.role] = row.levels end
	end
	local groups
	local zone_cache = {}
	-- A fortress's or Battlegrounds camp's garrison, "<zone>/<settlement
	-- key>" (the `_grug_area` lane G's garrisons carry): its roles at their
	-- levels and, as `garrison`, its faction.
	local function garrison_area(zone, id)
		local garrison = grug_mobs.pvp_garrison
		local row = garrison and garrison.poi(id)
		local record = row and row.zone_id == zone and grug_zones.get(zone)
		if not record then return nil end
		local by_role = garrison.area_roles(id, {record.level_min, record.level_max})
		local roles, lo, hi = {}, nil, nil
		for role, range in pairs(by_role) do
			roles[role] = true
			lo, hi = math.min(lo or range[1], range[1]), math.max(hi or range[2], range[2])
		end
		return {levels = {lo, hi}, levels_by_role = by_role, roles = roles, garrison = row.faction}
	end
	local function area(zone, id)
		local found = areas.get_area(zone, id)
		if not found then return garrison_area(zone, id) end
		return {levels = found.levels, levels_by_role = found.levels_by_role,
			roles = areas.area_roles(zone, id) or {}}
	end
	return {
		entity = function(name) return core.registered_entities[name] end,
		disposition = function(name)
			local def = core.registered_entities[name]
			return def and def._grug_disposition or grug_mobs.disposition(name)
		end,
		role_levels = function(role) return levels[role] end,
		-- The faction a quest giver serves (registry.lua, resolved before
		-- these checks) and the one it fights.
		npc_faction = function(npc) return (Q.registered_npcs[npc] or {}).faction end,
		opposing_faction = function(faction) return grug_core.opposing_faction(faction) end,
		leader = function(role) return areas.leader(role) end,
		-- {level_min, level_max} of a named zone (base mobs' surface levels).
		zone_band = function(zone)
			local record = grug_zones.get(zone)
			return record and record.level_min and {record.level_min, record.level_max} or nil
		end,
		area = area,
		zone_areas = function(zone)
			if zone_cache[zone] then return zone_cache[zone] end
			local out = {}
			for _, id in ipairs(areas.zone_area_ids(zone)) do
				out[#out + 1] = area(zone, id)
			end
			zone_cache[zone] = out
			return out
		end,
		item = function(name)
			return core.registered_items[name] ~= nil or core.registered_aliases[name] ~= nil
		end,
		-- Quest text placeholders (labels.lua): a target and a named place.
		placeholder_target = Q.placeholder_target,
		place = function(ref) return areas.place(ref) end,
		group = function(name)
			if not groups then
				groups = {}
				for _, def in pairs(core.registered_items) do
					for group in pairs(def.groups or {}) do groups[group] = true end
				end
			end
			return groups[name] == true
		end,
	}
end

-- Checks, new givers and quests of a set of files; the zone files at load,
-- a probe's sample files later.
function Q.load_quest_files(files)
	local errors = V.structure(files, Q.registered_npcs)
	if #errors > 0 then fail(errors) end
	register_new_givers(files)
	register_quests(files)
end

-- The world checks, once every mod has loaded; then each registered
-- objective's level range (Lane Q0), computed once here and read by the
-- dialogue and the quest log.
function Q.validate_quest_data(files)
	files = files or Q.quest_files
	local world = world_view()
	local found, warnings = V.world(files, world)
	for _, message in ipairs(warnings) do
		core.log("warning", "[grug_quests] " .. message)
	end
	if #found > 0 then fail(found) end
	for _, row in ipairs(V.each_quest(files)) do
		local def = Q.registered_quests[row.quest.id]
		for index, objective in ipairs(def and row.quest.objectives or {}) do
			def.objectives[index].levels = V.objective_levels(world, row.file.zone, row.quest, objective)
		end
	end
end

Q.quest_files = read_files()
Q.load_quest_files(Q.quest_files)
