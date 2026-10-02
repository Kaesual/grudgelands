-- Load-time checks of the zone quest files (Round 28 rulings 29, 39-45,
-- design frame sections 2.5 and 4.7). A designer's mistake stops the server
-- at load with every finding listed; each message names the file and the
-- quest. The rules are those of tools/r28_design/validate.py (its finding
-- codes in brackets); the atlas-only checks (giver zone and anchor, front
-- reservation, race tracks) and its warnings stay in that tool.
--
-- `structure(files)` needs nothing but the files; `world(files, world)` runs
-- after every mod loaded and asks `world` (loader.lua builds it from the
-- spawn-area, sub-type and item registries) about roles, areas and items.
-- A file is {name = "<zone>.quests.json", zone = "<zone>", front = bool,
-- data = decoded JSON}.
local Q = grug_quests
local V = {}
Q.validate = V

-- A kill target's level range [lo, hi] fits a quest of reward level L when
-- every level lies within L +- LEVEL_SLACK (containment).
V.LEVEL_SLACK = 3
V.MAX_GIVERS_PER_HUB = 2
V.MAX_LINES_PER_GIVER = 2
V.FRONT_LINE = "front"
-- Today's contested-zone quests ask for enemy faction guards. Only legacy
-- kill objectives (`mobs`, the mechanical split) may name them.
V.LEGACY_GUARDS = {["grug_mobs:guard_accord"] = true, ["grug_mobs:guard_throng"] = true}

local SNAKE = "^[a-z][a-z0-9_]*$"
local P = Q.placeholders
V.RACES = {dwarf = true, human = true, elf = true, undead = true, orc = true, troll = true}

local function int(value, lo, hi)
	return type(value) == "number" and value % 1 == 0 and (not lo or value >= lo) and
		(not hi or value <= hi)
end

local function text(value)
	return type(value) == "string" and value:find("%S") ~= nil
end

local function list(value)
	return type(value) == "table" and (next(value) == nil or value[1] ~= nil)
end

-- Kill and drop targets as entity names: design `roles` or legacy `mobs`.
function V.target_names(row)
	local out = {}
	if type(row.roles) == "table" then
		for i, role in ipairs(row.roles) do out[i] = "grug_mobs:" .. tostring(role) end
	elseif type(row.mobs) == "table" then
		for i, name in ipairs(row.mobs) do out[i] = tostring(name) end
	end
	return out
end

-- "zone/area"; a bare area id means the quest file's own zone.
function V.area_ref(ref, zone)
	if type(ref) ~= "string" or ref == "" then return nil end
	if ref:find("/", 1, true) then return ref end
	return zone .. "/" .. ref
end

local function reporter(errors, file)
	return function(where, message)
		errors[#errors + 1] = ("zones/%s: %s: %s"):format(file.name, where, message)
	end
end

-- Every quest of every file, as {file, quest, where}.
local function each_quest(files)
	local out = {}
	for _, file in ipairs(files) do
		local quests = type(file.data) == "table" and file.data.quests
		if type(quests) == "table" then
			for index, quest in ipairs(quests) do
				local where = type(quest) == "table" and type(quest.id) == "string" and
					("quest " .. quest.id) or ("quests[" .. index .. "]")
				out[#out + 1] = {file = file, quest = quest, where = where}
			end
		end
	end
	return out
end
V.each_quest = each_quest

local function check_objective(add, where, quest, objective, index)
	where = ("%s: objective %d"):format(where, index)
	if type(objective) ~= "table" then add(where, "must be an object [E-objective]"); return end
	if objective.type == "talk" then
		if #quest.objectives ~= 1 then add(where, "a talk objective must be the quest's only objective [E-talk-only]") end
		if objective.npc ~= quest.turnin then
			add(where, ("travel quests turn in at the talk target (%s, not %s) [E-talk-turnin]")
				:format(tostring(objective.npc), tostring(quest.turnin)))
		end
		return
	end
	if not int(objective.count, 1) then add(where, "count must be an integer >= 1 [E-objective]") end
	if objective.type == "kill" then
		local roles, mobs = objective.roles, objective.mobs
		if not ((type(roles) == "table" and #roles > 0) or (type(mobs) == "table" and #mobs > 0)) then
			add(where, "a kill objective needs a non-empty 'roles' list [E-objective]")
		elseif roles and mobs then
			add(where, "name the targets once ('roles'; 'mobs' is legacy-only) [E-objective]")
		end
		if objective.area ~= nil and type(objective.area) ~= "string" then
			add(where, "area must be 'zone_id/area_id' [E-area]")
		end
	elseif objective.type == "item" then
		if (type(objective.item) == "string") == (type(objective.group) == "string") then
			add(where, "an item objective names exactly one of 'item' or 'group' [E-objective]")
		end
		-- Optional source of a dropped item (Lane Q0): `roles`, optionally
		-- one `area`, shown as the targets' level range.
		if objective.roles ~= nil and not (type(objective.roles) == "table" and #objective.roles > 0) then
			add(where, "an item's source 'roles' must be a non-empty list [E-objective]")
		end
		if objective.area ~= nil and (type(objective.area) ~= "string" or objective.roles == nil) then
			add(where, "an item's source area is 'zone_id/area_id' next to its 'roles' [E-area]")
		end
	else
		add(where, ("type %s must be kill, item or talk [E-objective]"):format(tostring(objective.type)))
	end
end

local function check_rewards(add, where, rewards)
	if type(rewards) ~= "table" then add(where, "rewards must be an object [E-rewards]"); return end
	if rewards.weight ~= nil then
		if type(rewards.weight) ~= "number" or rewards.weight < 0 then
			add(where, "rewards.weight must be a number >= 0 (kill equivalents) [E-rewards]")
		end
	elseif not int(rewards.xp, 0) then
		add(where, "rewards need a 'weight' (kill equivalents at the reward level) [E-required]")
	end
	if rewards.copper ~= nil and not int(rewards.copper, 0) then
		add(where, "copper must be an integer >= 0 [E-rewards]")
	end
	if rewards.items ~= nil and not list(rewards.items) then
		add(where, "reward items are a list of {\"item\": id, \"count\": n} [E-rewards]")
		return
	end
	for i, item in ipairs(rewards.items or {}) do
		if type(item) ~= "table" or type(item.item) ~= "string" or
				(item.count ~= nil and not int(item.count, 1)) then
			add(where, ("reward item %d must be {\"item\": id, \"count\": n >= 1} [E-rewards]"):format(i))
		end
	end
end

-- Placeholders and compass words in the title and text (Round 29 Q1,
-- labels.lua): the placeholder syntax, directions only in the text, no fixed
-- compass word. Whether each target and place exists is a world check.
local function check_texts(add, where, quest)
	for _, key in ipairs({"title", "text"}) do
		if text(quest[key]) then
			local found, problems = P.scan(quest[key])
			for _, problem in ipairs(problems) do
				add(where, ("%s: %s [E-placeholder]"):format(key, problem))
			end
			for _, p in ipairs(found) do
				if key == "title" and P.DIRECTIONS[p.kind] then
					add(where, ("title: %s: a title takes only {name:...}; directions belong in the text " ..
						"[E-placeholder]"):format(p.raw))
				end
			end
			for _, word in ipairs(P.compass_words(quest[key])) do
				add(where, ("%s: fixed compass word '%s'; write a direction placeholder or neutral " ..
					"wording [E-compass]"):format(key, word))
			end
		end
	end
end

-- File, hub, line, quest and objective shapes plus references between the
-- files. `npcs` = the quest NPCs registered before the files load.
function V.structure(files, npcs)
	local errors = {}
	-- Hubs of the zones' own files: giver -> {zone, hub, lines}.
	local givers, new_givers = {}, {}
	for _, file in ipairs(files) do
		local add = reporter(errors, file)
		local data = file.data
		if type(data) ~= "table" then
			add("file", "must be a JSON object [E-type]")
		else
			if data.zone ~= file.zone then
				add("zone", ("zone %s does not match the file name [E-zone-mismatch]"):format(tostring(data.zone)))
			end
			if not file.front then
				for h, hub in ipairs(type(data.hubs) == "table" and data.hubs or {}) do
					local hub_where = "hub " .. tostring(type(hub) == "table" and hub.id or h)
					local list_of = type(hub) == "table" and type(hub.givers) == "table" and hub.givers or {}
					if type(hub) ~= "table" or not text(hub.id) then add(hub_where, "needs an id [E-id]") end
					if #list_of > V.MAX_GIVERS_PER_HUB then
						add(hub_where, ("%d givers (at most %d per hub) [E-givers]"):format(#list_of, V.MAX_GIVERS_PER_HUB))
					end
					for _, giver in ipairs(list_of) do
						local npc = type(giver) == "table" and giver.npc
						local where = hub_where .. ": giver " .. tostring(npc)
						local lines = type(giver) == "table" and giver.lines
						if type(npc) ~= "string" then
							add(where, "needs an 'npc' id [E-npc]")
						else
							if type(lines) ~= "table" or #lines == 0 then
								add(where, "needs a non-empty 'lines' list [E-lines]")
								lines = {}
							elseif #lines > V.MAX_LINES_PER_GIVER then
								add(where, ("%d lines (at most %d per giver) [E-lines]"):format(#lines, V.MAX_LINES_PER_GIVER))
							end
							if givers[npc] then
								add(where, ("already gives quests in hub %s/%s [E-giver-twice]")
									:format(givers[npc].zone, tostring(givers[npc].hub)))
							else
								local set = {}
								for _, line in ipairs(lines) do set[line] = true end
								givers[npc] = {zone = file.zone, hub = hub.id, lines = set}
							end
							if giver.new ~= nil then
								local new = giver.new
								if not npc:match(SNAKE) then
									add(where, "a new giver's npc id must be snake_case [E-new-giver]")
								elseif npcs[npc] then
									add(where, "is already a registered quest NPC; drop 'new' [E-new-giver]")
								elseif new_givers[npc] then
									add(where, "new giver is also declared in " .. new_givers[npc] .. " [E-duplicate]")
								end
								new_givers[npc] = file.name
								if type(new) ~= "table" or not text(new.name) or not text(new.race) or
										not text(new.socket) then
									add(where, "'new' must be {\"name\", \"race\", \"socket\"} [E-new-giver]")
								elseif not V.RACES[new.race] then
									-- A warning, as in validate.py: the giver keeps the
									-- settlement's race (start_npcs.lua).
									core.log("warning", ("[grug_quests] zones/%s: %s: race %s is not one of " ..
										"dwarf, elf, human, orc, troll, undead [W-new-giver]"):format(file.name, where, new.race))
								end
							elseif not npcs[npc] then
								add(where, "is not a registered quest NPC [E-unknown-npc]")
							end
						end
					end
				end
			end
		end
	end
	local known = {}
	for npc in pairs(npcs) do known[npc] = true end
	for npc in pairs(new_givers) do known[npc] = true end
	local ids = {}
	local rows = each_quest(files)
	for _, row in ipairs(rows) do
		local quest = row.quest
		if type(quest) == "table" and type(quest.id) == "string" then
			if ids[quest.id] then
				reporter(errors, row.file)(row.where, "also in zones/" .. ids[quest.id].name .. " [E-duplicate]")
			else
				ids[quest.id] = row.file
			end
		end
	end
	for _, row in ipairs(rows) do
		local file, quest, where = row.file, row.quest, row.where
		local add = reporter(errors, file)
		if type(quest) ~= "table" then
			add(where, "must be an object [E-type]")
		else
			for _, key in ipairs({"id", "line", "giver", "turnin", "min_level", "level", "title",
					"text", "objectives", "rewards"}) do
				if quest[key] == nil then add(where, ("missing required field '%s' [E-required]"):format(key)) end
			end
			if type(quest.id) ~= "string" or not quest.id:match(SNAKE) then
				add(where, "quest id must be snake_case [E-id]")
			end
			local giver = givers[quest.giver]
			if not giver or giver.zone ~= file.zone then
				add(where, ("giver %s is not a giver of a hub in zones/%s.quests.json [E-giver-not-hub]")
					:format(tostring(quest.giver), file.zone))
			elseif not giver.lines[quest.line] then
				add(where, ("line %s is not one of %s's lines [E-line]"):format(tostring(quest.line), quest.giver))
			end
			if file.front and quest.line ~= V.FRONT_LINE then
				add(where, ("front quests use the line 'front' (not %s) [E-front-line]"):format(tostring(quest.line)))
			elseif not file.front and quest.line == V.FRONT_LINE then
				add(where, ("line 'front' belongs to the front file zones/%s.front.quests.json [E-front-line]")
					:format(file.zone))
			end
			if type(quest.turnin) ~= "string" or not known[quest.turnin] then
				add(where, ("turn-in %s is not a registered quest NPC [E-unknown-npc]"):format(tostring(quest.turnin)))
			end
			if not int(quest.min_level, 1, 60) then add(where, "min_level must be an integer 1..60 [E-levels]") end
			if not int(quest.level, 1, 60) then add(where, "level must be an integer 1..60 [E-levels]") end
			if quest.requires ~= nil and not list(quest.requires) then
				add(where, "requires must be a list of quest ids [E-type]")
			end
			for _, required in ipairs(type(quest.requires) == "table" and quest.requires or {}) do
				if not ids[required] then add(where, ("unknown quest %s in requires [E-unknown-requires]"):format(tostring(required))) end
			end
			if not text(quest.title) then add(where, "title must be a non-empty string [E-text]") end
			if not text(quest.text) then add(where, "text must be a non-empty string [E-text]") end
			check_texts(add, where, quest)
			if type(quest.objectives) ~= "table" or #quest.objectives == 0 then
				add(where, "objectives must be a non-empty list [E-objective]")
			else
				for index, objective in ipairs(quest.objectives) do
					check_objective(add, where, quest, objective, index)
					if type(objective) == "table" and objective.type == "talk" and not known[objective.npc] then
						add(where, ("travel target %s is not a registered quest NPC [E-unknown-npc]")
							:format(tostring(objective.npc)))
					end
				end
			end
			local wanted = {}
			for _, objective in ipairs(type(quest.objectives) == "table" and quest.objectives or {}) do
				if type(objective) == "table" and objective.type == "item" and objective.item then
					wanted[objective.item] = true
				end
			end
			if quest.quest_drops ~= nil and not list(quest.quest_drops) then
				add(where, "quest_drops must be a list [E-type]")
			end
			for index, drop in ipairs(type(quest.quest_drops) == "table" and quest.quest_drops or {}) do
				local dwhere = ("%s: quest drop %d"):format(where, index)
				if type(drop) ~= "table" then
					add(dwhere, "must be an object [E-type]")
				else
					if not wanted[drop.item] then
						add(dwhere, ("quest drop %s has no item objective in this quest [E-quest-drop-pair]")
							:format(tostring(drop.item)))
					end
					if not int(drop.chance, 1) then add(dwhere, "chance (1 in N) must be an integer >= 1 [E-chance]") end
					if type(drop.roles) ~= "table" or #drop.roles == 0 then
						add(dwhere, "quest drop needs a non-empty 'roles' list [E-required]")
					end
					if drop.area ~= nil and type(drop.area) ~= "string" then
						add(dwhere, "area must be 'zone_id/area_id' [E-area]")
					end
				end
			end
			if quest.repeatable ~= nil and not (type(quest.repeatable) == "table" and
					int(quest.repeatable.cooldown, 1)) then
				add(where, "repeatable must be {\"cooldown\": seconds} [E-repeatable]")
			end
			if quest.rewards ~= nil then check_rewards(add, where, quest.rewards) end
		end
	end
	-- Prerequisite cycles across all files.
	local state, by_id = {}, {}
	for _, row in ipairs(rows) do
		if type(row.quest) == "table" and type(row.quest.id) == "string" then by_id[row.quest.id] = row end
	end
	local function visit(id, path)
		state[id] = 1
		local row = by_id[id]
		for _, required in ipairs(type(row.quest.requires) == "table" and row.quest.requires or {}) do
			if state[required] == 1 then
				reporter(errors, row.file)(row.where, ("prerequisite cycle: %s -> %s [E-cycle]")
					:format(table.concat(path, " -> "), required))
			elseif by_id[required] and not state[required] then
				path[#path + 1] = required
				visit(required, path)
				path[#path] = nil
			end
		end
		state[id] = 2
	end
	local sorted = {}
	for id in pairs(by_id) do sorted[#sorted + 1] = id end
	table.sort(sorted)
	for _, id in ipairs(sorted) do
		if not state[id] then visit(id, {id}) end
	end
	return errors
end

-- The level range a kill or drop target is met at: a named leader's fixed
-- level (a leader has no area), else the referenced area's levels, else the
-- levels of all areas of the quest's zone hosting the role, else the role's
-- own levels; nil when unknown (no check).
local function target_levels(add, where, world, zone, name, area_ref)
	local role = name:match("^grug_mobs:(.+)$") or name
	local leader = world.leader(role)
	if leader then
		if area_ref then
			add(where, ("%s is a leader at a fixed spot, not in an area: drop the area [E-leader-area]"):format(role))
		end
		return leader.level, leader.level
	end
	if area_ref then
		local zone_id, area_id = area_ref:match("^([^/]+)/(.+)$")
		local area = zone_id and world.area(zone_id, area_id)
		if not area then
			add(where, ("area %s does not exist [E-unknown-area]"):format(area_ref))
			return nil
		end
		if not area.roles[role] then
			add(where, ("%s does not spawn in %s [E-role-not-in-area]"):format(role, area_ref))
		end
		return area.levels[1], area.levels[2]
	end
	local lo, hi
	for _, area in ipairs(world.zone_areas(zone)) do
		if area.roles[role] then
			lo = math.min(lo or area.levels[1], area.levels[1])
			hi = math.max(hi or area.levels[2], area.levels[2])
		end
	end
	if lo then return lo, hi end
	local levels = world.role_levels(role)
	if levels then return levels[1], levels[2] end
	return nil
end

local function check_target(add, where, world, zone, name, area_ref, level, what, legacy)
	local role = name:match("^grug_mobs:(.+)$") or name
	if not world.entity(name) then
		add(where, ("role %s is neither a sub-type nor an existing mob [E-unknown-role]"):format(role))
		return
	end
	local disposition = world.disposition(name)
	if disposition == "critter" then
		add(where, ("critter %s is never a %s (Ruling 29) [E-critter-target]"):format(role, what))
		return
	end
	if disposition == nil and not (legacy and V.LEGACY_GUARDS[name]) then
		add(where, ("%s is an NPC or guard, not a %s [E-not-a-mob]"):format(role, what))
		return
	end
	local lo, hi = target_levels(add, where, world, zone, name, area_ref)
	if lo and type(level) == "number" and not (lo >= level - V.LEVEL_SLACK and hi <= level + V.LEVEL_SLACK) then
		add(where, ("%s is met at levels %d-%d; all must lie within quest level %d +-%d (%d-%d) [E-level-fit]")
			:format(role, lo, hi, level, V.LEVEL_SLACK, level - V.LEVEL_SLACK, level + V.LEVEL_SLACK))
	end
end

local function check_item(add, where, world, item, what)
	if not world.item(item) then add(where, ("%s %s is not a registered item [E-unknown-item]"):format(what, item)) end
end

-- A kill objective without an area in a zone with a spawn recipe, none of
-- whose targets that recipe spawns (a kind or a camp of the zone) and none
-- of which is a leader (a leader of any zone counts: it stands at its own
-- rule-placed spot, so a front file may name another zone's leader): in such
-- a zone only the recipe's roles appear on the surface (Lane S1), so the
-- quest cannot be met there. A warning, not an error: the targets may live
-- in another zone on purpose.
local function check_recipe_targets(warn, where, world, zone, objective)
	if objective.area then return end
	local kill_zone = type(objective.zone) == "string" and objective.zone or zone
	local areas = world.zone_areas(kill_zone)
	if #areas == 0 then return end
	for _, name in ipairs(V.target_names(objective)) do
		-- Guards stand at their guard posts, never in a recipe's regions.
		if V.LEGACY_GUARDS[name] then return end
		local role = name:match("^grug_mobs:(.+)$") or name
		if world.leader(role) then return end
		for _, area in ipairs(areas) do
			if area.roles[role] then return end
		end
	end
	warn(where, ("no kill target is spawned by %s's spawn recipe [W-recipe-target]"):format(kill_zone))
end

-- Every placeholder's target (a kind or camp of the zone's recipe or a
-- leader) and place (a settlement key or anchor id) exists. "From here"
-- points at a compact target: an open kind spreads over many patches, so it
-- takes the zone phrasing or a named place (a warning).
local function check_placeholders(add, warn, where, world, zone, quest)
	for _, key in ipairs({"title", "text"}) do
		for _, p in ipairs((P.scan(quest[key]))) do
			local ref = p.args[#p.args]
			local target, reason = world.placeholder_target(zone, ref)
			if not target then
				add(where, ("%s: %s: %s [E-placeholder-target]"):format(key, p.raw, tostring(reason)))
			elseif p.kind == "dir_from_giver" and target.type == "open" then
				warn(where, ("%s: %s: %s is an open kind spread over many patches; use {zone_area:...} or " ..
					"{dir_of:<place>:...} [W-placeholder-spread]"):format(key, p.raw, ref))
			end
			if p.kind == "dir_of" and not world.place(p.args[1]) then
				add(where, ("%s: %s: %s is not a settlement key or anchor id [E-placeholder-place]")
					:format(key, p.raw, p.args[1]))
			end
		end
	end
end

-- Roles, areas, levels and items against the registries. Returns the errors
-- and the warnings.
function V.world(files, world)
	local errors, warnings = {}, {}
	for _, row in ipairs(each_quest(files)) do
		local quest, zone = row.quest, row.file.zone
		local add = reporter(errors, row.file)
		local warn = reporter(warnings, row.file)
		for index, objective in ipairs(quest.objectives) do
			local where = ("%s: objective %d"):format(row.where, index)
			if objective.type == "kill" then
				local area = V.area_ref(objective.area, zone)
				for _, name in ipairs(V.target_names(objective)) do
					check_target(add, where, world, zone, name, area, quest.level, "kill target",
						objective.roles == nil)
				end
				check_recipe_targets(warn, where, world, zone, objective)
			elseif objective.type == "item" then
				if objective.item then
					check_item(add, where, world, objective.item, "item")
				elseif not world.group((objective.group:gsub("^group:", ""))) then
					add(where, ("item group %s does not exist [E-unknown-group]"):format(objective.group))
				end
				for _, name in ipairs(objective.roles and V.target_names(objective) or {}) do
					check_target(add, where, world, zone, name, V.area_ref(objective.area, zone), quest.level,
						"item source", false)
				end
			end
		end
		for index, drop in ipairs(quest.quest_drops or {}) do
			local where = ("%s: quest drop %d"):format(row.where, index)
			check_item(add, where, world, drop.item, "quest drop")
			for _, name in ipairs(V.target_names(drop)) do
				check_target(add, where, world, zone, name, V.area_ref(drop.area, zone), quest.level,
					"quest-drop source", false)
			end
		end
		for _, item in ipairs(quest.rewards.items or {}) do
			check_item(add, row.where, world, item.item, "reward item")
		end
		check_placeholders(add, warn, row.where, world, zone, quest)
	end
	return errors, warnings
end

-- The level range shown with an objective (Lane Q0): the levels its targets
-- are met at, so a player can judge them without a signal word in the name.
-- Per role, first match: a named leader's fixed level; in the objective's
-- area (a kind or camp) that role's levels there; the role's levels in the
-- kinds and camps of the kill zone's recipe (the level-fit check's source);
-- its catalogue levels within the quest level +- LEVEL_SLACK; a base mob
-- (no catalogue row) in a zone without a recipe: the zone's level band
-- within the quest level +- LEVEL_SLACK. A recipe zone spawns only its own
-- roles on the surface, so a base mob there adds nothing.
local function role_range(world, zone, level, role, area_ref)
	local leader = world.leader(role)
	if leader then return leader.level, leader.level end
	if area_ref then
		local zone_id, area_id = area_ref:match("^([^/]+)/(.+)$")
		local area = zone_id and world.area(zone_id, area_id)
		local range = area and area.levels_by_role[role]
		if range then return range[1], range[2] end
		return nil
	end
	local areas, lo, hi = world.zone_areas(zone), nil, nil
	for _, area in ipairs(areas) do
		local range = area.levels_by_role[role]
		if range then
			lo = math.min(lo or range[1], range[1])
			hi = math.max(hi or range[2], range[2])
		end
	end
	if lo then return lo, hi end
	local own = world.role_levels(role) or (#areas == 0 and world.zone_band(zone))
	if not own then return nil end
	lo, hi = math.max(own[1], level - V.LEVEL_SLACK), math.min(own[2], level + V.LEVEL_SLACK)
	if lo > hi then return nil end
	return lo, hi
end

-- {lo, hi} for one objective of `quest` (design data) in `zone`, or nil: a
-- kill objective's targets; an item objective's named source (`roles`) and
-- the quest drops of its item. The union over the roles.
function V.objective_levels(world, zone, quest, objective)
	local lo, hi
	local function add(names, area_ref, kill_zone)
		for _, name in ipairs(names) do
			local a, b = role_range(world, kill_zone, quest.level, name:match("^grug_mobs:(.+)$") or name, area_ref)
			if a then lo, hi = math.min(lo or a, a), math.max(hi or b, b) end
		end
	end
	if objective.type == "kill" then
		add(V.target_names(objective), V.area_ref(objective.area, zone),
			type(objective.zone) == "string" and objective.zone or zone)
	elseif objective.type == "item" then
		if objective.roles then add(V.target_names(objective), V.area_ref(objective.area, zone), zone) end
		for _, drop in ipairs(objective.item and quest.quest_drops or {}) do
			if drop.item == objective.item then add(V.target_names(drop), V.area_ref(drop.area, zone), zone) end
		end
	end
	return lo and {lo, hi} or nil
end
