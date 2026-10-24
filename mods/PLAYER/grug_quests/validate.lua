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

local SNAKE = "^[a-z][a-z0-9_]*$"
local P = Q.placeholders
V.RACES = {dwarf = true, human = true, elf = true, undead = true, orc = true, troll = true}

local function key_set(keys)
	local out = {}
	for _, key in ipairs(keys) do out[key] = true end
	return out
end
-- The fields a quest, an objective, its rewards and a quest drop may carry
-- (design frame section 4.7; `lesson` ... `notes` are design notes the game
-- does not read; `tags`, Round 36, are what achievements count a quest as,
-- grug_achievements "quest_tag:<tag>"). Any other field is refused, so a
-- field nothing reads can never sit in a file looking as if it did
-- something.
-- Round 57: `story` (a story quest, ruling 13), `completion` (the closing
-- paragraph of the turn-in, ruling 14), `variants` (a quest given in
-- several zones, ruling 9; in place of `giver` and `turnin`) and `texts`
-- (a giver's or a race's own text); the reward `choices` (ruling 15).
-- `repeatable` is gone (ruling 11): an unknown field like any other.
V.QUEST_KEYS = key_set({"id", "line", "giver", "turnin", "variants", "min_level", "level", "requires", "title",
	"text", "texts", "completion", "story", "objectives", "rewards", "quest_drops", "lesson", "duration_min",
	"optional", "climax", "group", "notes", "tags"})
V.OBJECTIVE_KEYS = key_set({"type", "count", "roles", "area", "item", "group", "npc", "place", "object",
	"label", "hold"})
V.REWARD_KEYS = key_set({"weight", "copper", "items", "choices"})
V.CHOICE_KEYS = key_set({"item", "count", "affixes"})
V.AFFIX_KEYS = key_set({"channel", "stat"})
V.DROP_KEYS = key_set({"item", "chance", "roles", "area"})
-- A variant (Round 57): its zone, its givers and turn-ins (NPC ids, or
-- {role, faction} for every NPC of a role), the zone-bound fields of its
-- objectives and quest drops (one entry per base entry, in order), its own
-- text and completion text.
V.VARIANT_KEYS = key_set({"zone", "givers", "turnins", "objectives", "quest_drops", "text", "completion"})
V.ROLE_KEYS = key_set({"role", "faction"})
-- The fields a variant sets per objective type and per quest drop: what
-- names a zone's own targets and places.
V.OVERRIDE_KEYS = {kill = key_set({"roles", "area"}), item = key_set({"roles", "area"}),
	talk = key_set({"npc"}), use = key_set({"place"})}
V.DROP_OVERRIDE_KEYS = key_set({"roles", "area"})
V.FACTIONS = {accord = true, throng = true}
-- The file-level marker of a reworked quest file (Round 57, the plan's
-- §3): only such files follow the free-play rules, the reward budget, the
-- "never the requested item" rule and the night-count warning.
V.REWORK_FLAG = "reworked"
-- Ruling 17: per zone (capitals excepted) at most this many equipment
-- rewards with one and with two enchants.
V.BUDGET = {[1] = 2, [2] = 1}
-- Ruling 12: a night-only kill target asks about a third of the zone's day
-- counts (a day lasts 15 minutes, a night 5); outside this share of the
-- median day count it is a warning.
V.NIGHT_SHARE = {0.2, 0.5}

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

-- Kill and drop targets (`roles`) as entity names.
function V.target_names(row)
	local out = {}
	for i, role in ipairs(type(row.roles) == "table" and row.roles or {}) do
		out[i] = "grug_mobs:" .. tostring(role)
	end
	return out
end

-- Every field of `row` outside `allowed`, sorted.
local function unknown_keys(add, where, row, allowed)
	local unknown = {}
	for key in pairs(row) do
		if not allowed[key] then unknown[#unknown + 1] = tostring(key) end
	end
	table.sort(unknown)
	for _, key in ipairs(unknown) do
		add(where, ("unknown field '%s' [E-unknown-key]"):format(key))
	end
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

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = copy(child) end
	return out
end

-- A list entry with the override `row` applied: the fields of `allowed` it
-- sets replace the base's.
local function overridden(base, row, allowed)
	local out = copy(base)
	if type(out) == "table" and type(row) == "table" then
		for key in pairs(allowed or {}) do
			if row[key] ~= nil then out[key] = copy(row[key]) end
		end
	end
	return out
end

-- The variants of a quest (Round 57, ruling 9), each {key, zone, givers,
-- giver_roles, turnins, turnin_roles, objectives, quest_drops, text,
-- completion, row, index}: its objectives and quest drops are the quest's
-- with the variant's zone-bound fields (a bare area or place id is the
-- variant's zone). A quest without `variants` is one implicit variant of
-- its file's zone, its `giver` and its `turnin`. The loader registers these;
-- the checks run over them.
function V.variants(file, quest)
	local base_objectives = type(quest.objectives) == "table" and quest.objectives or {}
	local base_drops = type(quest.quest_drops) == "table" and quest.quest_drops or {}
	if quest.variants == nil then
		return {{key = file.zone, zone = file.zone, givers = {quest.giver}, giver_roles = {},
			turnins = {quest.turnin}, turnin_roles = {}, objectives = base_objectives,
			quest_drops = base_drops, implicit = true}}
	end
	local out = {}
	for index, row in ipairs(type(quest.variants) == "table" and quest.variants or {}) do
		if type(row) == "table" then
			local variant = {key = row.zone, zone = row.zone, givers = {}, giver_roles = {}, turnins = {},
				turnin_roles = {}, objectives = {}, quest_drops = {}, text = row.text,
				completion = row.completion, row = row, index = index}
			local function split(list, ids, roles)
				for _, entry in ipairs(type(list) == "table" and list or {}) do
					if type(entry) == "table" then roles[#roles + 1] = entry else ids[#ids + 1] = entry end
				end
			end
			split(row.givers, variant.givers, variant.giver_roles)
			split(row.turnins == nil and row.givers or row.turnins, variant.turnins, variant.turnin_roles)
			local objectives = type(row.objectives) == "table" and row.objectives or {}
			for i, base in ipairs(base_objectives) do
				variant.objectives[i] = overridden(base, objectives[i],
					type(base) == "table" and V.OVERRIDE_KEYS[base.type] or nil)
			end
			local drops = type(row.quest_drops) == "table" and row.quest_drops or {}
			for i, base in ipairs(base_drops) do
				variant.quest_drops[i] = overridden(base, drops[i], V.DROP_OVERRIDE_KEYS)
			end
			out[#out + 1] = variant
		end
	end
	return out
end

-- Whether a file carries the rework flag.
function V.reworked(file)
	return type(file.data) == "table" and file.data[V.REWORK_FLAG] == true
end

local function check_objective(add, where, count, objective, index)
	where = ("%s: objective %d"):format(where, index)
	if type(objective) ~= "table" then add(where, "must be an object [E-objective]"); return end
	unknown_keys(add, where, objective, V.OBJECTIVE_KEYS)
	if objective.type ~= "use" then
		for _, key in ipairs({"place", "object", "label", "hold"}) do
			if objective[key] ~= nil then
				add(where, ("only a use objective takes '%s' [E-objective]"):format(key))
			end
		end
	end
	if objective.type == "talk" then
		if count ~= 1 then add(where, "a talk objective must be the quest's only objective [E-talk-only]") end
		return
	end
	if objective.type == "use" then
		-- Round 36: one act at one place, done once (use.lua).
		if objective.count ~= nil and objective.count ~= 1 then
			add(where, "a use objective counts once: leave count out or write 1 [E-objective]")
		end
		if type(objective.place) ~= "string" or objective.place == "" then
			add(where, "a use objective needs a 'place': a clash site key or a quest place [E-objective]")
		end
		if not text(objective.label) then
			add(where, "a use objective needs a 'label', the act (\"Light the signal fire\") [E-objective]")
		end
		if not int(objective.hold, Q.USE_HOLD_MIN, Q.USE_HOLD_MAX) then
			add(where, ("a use objective's hold is whole seconds %d..%d [E-objective]")
				:format(Q.USE_HOLD_MIN, Q.USE_HOLD_MAX))
		end
		if not Q.use_objects[objective.object] then
			add(where, ("object %s is not a kind of data/use_objects.json [E-use-object]")
				:format(tostring(objective.object)))
		end
		for _, key in ipairs({"roles", "area", "item", "group", "npc"}) do
			if objective[key] ~= nil then
				add(where, ("a use objective takes no '%s' [E-objective]"):format(key))
			end
		end
		return
	end
	if not int(objective.count, 1) then add(where, "count must be an integer >= 1 [E-objective]") end
	if objective.type == "kill" then
		if not (type(objective.roles) == "table" and #objective.roles > 0) then
			add(where, "a kill objective needs a non-empty 'roles' list [E-objective]")
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
		add(where, ("type %s must be kill, item, talk or use [E-objective]"):format(tostring(objective.type)))
	end
end

-- An enchant list of a reward (Round 57): {channel, stat} rows; whether the
-- item takes them is a world check (grug_items.check_affixes).
local function check_affixes(add, where, affixes)
	if not list(affixes) or #affixes > 2 then
		add(where, "affixes are a list of at most two {\"channel\", \"stat\"} [E-rewards]")
		return
	end
	for i, affix in ipairs(affixes) do
		if type(affix) ~= "table" then
			add(where, ("affix %d must be an object [E-rewards]"):format(i))
		else
			unknown_keys(add, ("%s: affix %d"):format(where, i), affix, V.AFFIX_KEYS)
			if affix.channel ~= "prefix" and affix.channel ~= "suffix" then
				add(where, ("affix %d: channel is prefix or suffix [E-rewards]"):format(i))
			end
			if type(affix.stat) ~= "string" then add(where, ("affix %d needs a 'stat' [E-rewards]"):format(i)) end
		end
	end
end

local function check_rewards(add, where, rewards)
	if type(rewards) ~= "table" then add(where, "rewards must be an object [E-rewards]"); return end
	unknown_keys(add, where .. ": rewards", rewards, V.REWARD_KEYS)
	if rewards.weight == nil then
		add(where, "rewards need a 'weight' (kill equivalents at the reward level) [E-required]")
	elseif type(rewards.weight) ~= "number" or rewards.weight < 0 then
		add(where, "rewards.weight must be a number >= 0 (kill equivalents) [E-rewards]")
	end
	if rewards.copper ~= nil and not int(rewards.copper, 0) then
		add(where, "copper must be an integer >= 0 [E-rewards]")
	end
	if rewards.items ~= nil and not list(rewards.items) then
		add(where, "reward items are a list of {\"item\": id, \"count\": n} [E-rewards]")
	else
		for i, item in ipairs(rewards.items or {}) do
			if type(item) ~= "table" or type(item.item) ~= "string" or
					(item.count ~= nil and not int(item.count, 1)) then
				add(where, ("reward item %d must be {\"item\": id, \"count\": n >= 1} [E-rewards]"):format(i))
			end
		end
	end
	-- Round 57 ruling 15: a choice of 2..MAX_CHOICES rewards, each an item
	-- with a count and optional fixed enchants.
	if rewards.choices ~= nil then
		if not list(rewards.choices) or #rewards.choices < 2 or #rewards.choices > Q.MAX_CHOICES then
			add(where, ("reward choices are a list of 2..%d {\"item\", \"count\", \"affixes\"} [E-rewards]")
				:format(Q.MAX_CHOICES))
		else
			for i, choice in ipairs(rewards.choices) do
				local cwhere = ("%s: reward choice %d"):format(where, i)
				if type(choice) ~= "table" or type(choice.item) ~= "string" or
						(choice.count ~= nil and not int(choice.count, 1)) then
					add(cwhere, "must be {\"item\": id, \"count\": n >= 1, \"affixes\"?} [E-rewards]")
				else
					unknown_keys(add, cwhere, choice, V.CHOICE_KEYS)
					if choice.affixes ~= nil then check_affixes(add, cwhere, choice.affixes) end
				end
			end
		end
	end
end

-- Placeholders and compass words in a title or a text (Round 29 Q1,
-- labels.lua): the placeholder syntax, directions only in a text, no fixed
-- compass word; a shared quest's title (Round 57: given in several zones)
-- takes no placeholder at all. Whether each target and place exists is a
-- world check.
local function check_text(add, where, key, value, shared)
	if not text(value) then return end
	local found, problems = P.scan(value)
	for _, problem in ipairs(problems) do
		add(where, ("%s: %s [E-placeholder]"):format(key, problem))
	end
	for _, p in ipairs(found) do
		if key == "title" and shared then
			add(where, ("title: %s: a quest given in several zones has one name; its title takes no " ..
				"placeholder [E-placeholder]"):format(p.raw))
		elseif key == "title" and P.DIRECTIONS[p.kind] then
			add(where, ("title: %s: a title takes only {name:...}; directions belong in the text " ..
				"[E-placeholder]"):format(p.raw))
		end
	end
	for _, word in ipairs(P.compass_words(value)) do
		add(where, ("%s: fixed compass word '%s'; write a direction placeholder or neutral " ..
			"wording [E-compass]"):format(key, word))
	end
end

-- A variant's givers or turn-ins: NPC ids or {role, faction} rows.
local function check_npc_list(add, where, key, value, known, required)
	if value == nil and not required then return end
	if not list(value) or #value == 0 then
		add(where, ("'%s' must be a non-empty list of NPC ids or {\"role\", \"faction\"} [E-variant]"):format(key))
		return
	end
	for _, entry in ipairs(value) do
		if type(entry) == "table" then
			unknown_keys(add, where .. ": " .. key, entry, V.ROLE_KEYS)
			if type(entry.role) ~= "string" or not entry.role:match(SNAKE) or not V.FACTIONS[entry.faction] then
				add(where, ("a %s role is {\"role\": snake_case, \"faction\": \"accord\" | \"throng\"} [E-variant]")
					:format(key))
			end
		elseif type(entry) ~= "string" or not known[entry] then
			add(where, ("%s %s is not a registered quest NPC [E-unknown-npc]"):format(key, tostring(entry)))
		end
	end
end

-- The NPC ids of a list as one string.
local function names(list)
	local out = {}
	for _, entry in ipairs(list) do out[#out + 1] = tostring(entry) end
	return table.concat(out, ", ")
end

-- The shapes of a variant's zone-bound fields.
local function check_override(add, where, entry)
	if entry.roles ~= nil and not (type(entry.roles) == "table" and #entry.roles > 0) then
		add(where, "roles must be a non-empty list [E-objective]")
	end
	for _, key in ipairs({"area", "npc", "place"}) do
		if entry[key] ~= nil and (type(entry[key]) ~= "string" or entry[key] == "") then
			add(where, ("%s must be a non-empty string [E-objective]"):format(key))
		end
	end
end

-- A variant's own fields (Round 57): its zone, givers, turn-ins, the
-- zone-bound overrides of its objectives and quest drops, its texts.
local function check_variant_row(add, where, quest, row, known, zones)
	unknown_keys(add, where, row, V.VARIANT_KEYS)
	if type(row.zone) ~= "string" or not zones[row.zone] then
		add(where, ("zone %s has no quest file [E-variant]"):format(tostring(row.zone)))
	end
	check_npc_list(add, where, "givers", row.givers, known, true)
	check_npc_list(add, where, "turnins", row.turnins, known, false)
	local base = type(quest.objectives) == "table" and quest.objectives or {}
	if row.objectives ~= nil then
		if not list(row.objectives) or #row.objectives ~= #base then
			add(where, ("objectives must list one entry per objective of the quest (%d) [E-variant]"):format(#base))
		else
			for i, entry in ipairs(row.objectives) do
				local kind = type(base[i]) == "table" and base[i].type
				if type(entry) ~= "table" then
					add(where, ("objective %d must be an object [E-variant]"):format(i))
				else
					local owhere = ("%s: objective %d"):format(where, i)
					unknown_keys(add, owhere, entry, V.OVERRIDE_KEYS[kind] or {})
					check_override(add, owhere, entry)
				end
			end
		end
	end
	local drops = type(quest.quest_drops) == "table" and quest.quest_drops or {}
	if row.quest_drops ~= nil then
		if not list(row.quest_drops) or #row.quest_drops ~= #drops then
			add(where, ("quest_drops must list one entry per quest drop (%d) [E-variant]"):format(#drops))
		else
			for i, entry in ipairs(row.quest_drops) do
				if type(entry) ~= "table" then
					add(where, ("quest drop %d must be an object [E-variant]"):format(i))
				else
					local dwhere = ("%s: quest drop %d"):format(where, i)
					unknown_keys(add, dwhere, entry, V.DROP_OVERRIDE_KEYS)
					check_override(add, dwhere, entry)
				end
			end
		end
	end
	for _, key in ipairs({"text", "completion"}) do
		if row[key] ~= nil and not text(row[key]) then
			add(where, ("%s must be a non-empty string [E-text]"):format(key))
		end
		check_text(add, where, key, row[key])
	end
end

-- File, hub, line, quest and objective shapes plus references between the
-- files. `npcs` = the quest NPCs registered before the files load.
function V.structure(files, npcs)
	local errors = {}
	-- Hubs of the zones' own files: giver -> {zone, hub, lines}.
	local givers, new_givers, zones = {}, {}, {}
	for _, file in ipairs(files) do
		local add = reporter(errors, file)
		local data = file.data
		if not file.front then zones[file.zone] = true end
		if type(data) ~= "table" then
			add("file", "must be a JSON object [E-type]")
		else
			if data.zone ~= file.zone then
				add("zone", ("zone %s does not match the file name [E-zone-mismatch]"):format(tostring(data.zone)))
			end
			if data[V.REWORK_FLAG] ~= nil and data[V.REWORK_FLAG] ~= true then
				add("file", ("'%s' is true or left out [E-type]"):format(V.REWORK_FLAG))
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
								else
									if not V.RACES[new.race] then
										-- A warning, as in validate.py: the giver keeps the
										-- settlement's race (start_npcs.lua).
										core.log("warning", ("[grug_quests] zones/%s: %s: race %s is not one of " ..
											"dwarf, elf, human, orc, troll, undead [W-new-giver]"):format(file.name, where, new.race))
									end
									-- Round 57: a new giver may carry a role (Q.bind_role_givers).
									if new.role ~= nil and (type(new.role) ~= "string" or not new.role:match(SNAKE)) then
										add(where, "a new giver's role is snake_case [E-new-giver]")
									end
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
			unknown_keys(add, where, quest, V.QUEST_KEYS)
			local shared = quest.variants ~= nil
			local required = {"id", "line", "min_level", "level", "title", "text", "objectives", "rewards"}
			if not shared then
				table.insert(required, 3, "giver")
				table.insert(required, 4, "turnin")
			end
			for _, key in ipairs(required) do
				if quest[key] == nil then add(where, ("missing required field '%s' [E-required]"):format(key)) end
			end
			if type(quest.id) ~= "string" or not quest.id:match(SNAKE) then
				add(where, "quest id must be snake_case [E-id]")
			end
			if shared then
				-- Round 57 ruling 9: givers and turn-ins per variant.
				if quest.giver ~= nil or quest.turnin ~= nil then
					add(where, "a quest with variants names its givers and turn-ins there, not in " ..
						"'giver'/'turnin' [E-variant]")
				end
				if file.front then
					add(where, "a front quest has one giver: no variants [E-variant]")
				end
				if not list(quest.variants) or #quest.variants == 0 then
					add(where, "variants must be a non-empty list [E-variant]")
				elseif type(quest.variants[1]) == "table" and quest.variants[1].zone ~= file.zone then
					-- One home file per shared quest: its first variant's zone's.
					add(where, ("a shared quest lives in the file of its first variant's zone (%s) [E-variant]")
						:format(tostring(quest.variants[1].zone)))
				end
			end
			local seen_zone, seen_giver = {}, {}
			for _, variant in ipairs(V.variants(file, quest)) do
				local vwhere = variant.implicit and where or ("%s: variant %s"):format(where, tostring(variant.zone))
				if not variant.implicit then
					check_variant_row(add, vwhere, quest, variant.row, known, zones)
					if variant.zone ~= nil and seen_zone[variant.zone] then
						add(vwhere, "is the quest's second variant of this zone [E-variant]")
					end
					seen_zone[variant.zone or ""] = true
				end
				-- Each giver of a hub of the variant's zone file (the hub rule:
				-- a shared quest may be given in several hubs, Round 57).
				for _, npc in ipairs(variant.givers) do
					local giver = givers[npc]
					if seen_giver[npc] then
						add(vwhere, ("giver %s already gives this quest in another variant [E-variant]"):format(tostring(npc)))
					end
					seen_giver[npc] = true
					if not giver or giver.zone ~= variant.zone then
						add(vwhere, ("giver %s is not a giver of a hub in zones/%s.quests.json [E-giver-not-hub]")
							:format(tostring(npc), tostring(variant.zone)))
					elseif not giver.lines[quest.line] then
						add(vwhere, ("line %s is not one of %s's lines [E-line]"):format(tostring(quest.line), npc))
					end
				end
				if variant.implicit then
					if type(quest.turnin) ~= "string" or not known[quest.turnin] then
						add(where, ("turn-in %s is not a registered quest NPC [E-unknown-npc]"):format(tostring(quest.turnin)))
					end
				end
				-- A travel quest turns in at its talk target, and only there.
				for index, objective in ipairs(variant.objectives) do
					if type(objective) == "table" and objective.type == "talk" then
						local owhere = ("%s: objective %d"):format(vwhere, index)
						local turnin = #variant.turnins == 1 and #variant.turnin_roles == 0 and variant.turnins[1]
						if objective.npc ~= turnin then
							add(owhere, ("travel quests turn in at the talk target (%s, not %s) [E-talk-turnin]")
								:format(tostring(objective.npc), names(variant.turnins)))
						end
						if not known[objective.npc] then
							add(where, ("travel target %s is not a registered quest NPC [E-unknown-npc]")
								:format(tostring(objective.npc)))
						end
					end
				end
			end
			if file.front and quest.line ~= V.FRONT_LINE then
				add(where, ("front quests use the line 'front' (not %s) [E-front-line]"):format(tostring(quest.line)))
			elseif not file.front and quest.line == V.FRONT_LINE then
				add(where, ("line 'front' belongs to the front file zones/%s.front.quests.json [E-front-line]")
					:format(file.zone))
			end
			if not int(quest.min_level, 1, 60) then add(where, "min_level must be an integer 1..60 [E-levels]") end
			if not int(quest.level, 1, 60) then add(where, "level must be an integer 1..60 [E-levels]") end
			if quest.requires ~= nil and not list(quest.requires) then
				add(where, "requires must be a list of quest ids [E-type]")
			end
			for _, required_id in ipairs(type(quest.requires) == "table" and quest.requires or {}) do
				if not ids[required_id] then add(where, ("unknown quest %s in requires [E-unknown-requires]"):format(tostring(required_id))) end
			end
			if quest.tags ~= nil then
				local seen, ok = {}, list(quest.tags)
				for _, tag in ipairs(ok and quest.tags or {}) do
					if type(tag) ~= "string" or not tag:match(SNAKE) or seen[tag] then ok = false end
					if type(tag) == "string" then seen[tag] = true end
				end
				if not ok then add(where, "tags must be a list of distinct snake_case names [E-tags]") end
			end
			if quest.story ~= nil and type(quest.story) ~= "boolean" then
				add(where, "story is true or false [E-type]")
			end
			if not text(quest.title) then add(where, "title must be a non-empty string [E-text]") end
			if not text(quest.text) then add(where, "text must be a non-empty string [E-text]") end
			if quest.completion ~= nil and not text(quest.completion) then
				add(where, "completion must be a non-empty string [E-text]")
			end
			check_text(add, where, "title", quest.title, shared)
			check_text(add, where, "text", quest.text)
			check_text(add, where, "completion", quest.completion)
			-- A giver's or a race's own text (Round 57 ruling 9): keyed by a
			-- giver of this quest or a race.
			if quest.texts ~= nil then
				if type(quest.texts) ~= "table" or list(quest.texts) then
					add(where, "texts maps a giver's NPC id or a race to a text [E-texts]")
				else
					local giver_of = {}
					for _, variant in ipairs(V.variants(file, quest)) do
						for _, npc in ipairs(variant.givers) do giver_of[npc] = true end
					end
					local keys = {}
					for key in pairs(quest.texts) do keys[#keys + 1] = tostring(key) end
					table.sort(keys)
					for _, key in ipairs(keys) do
						if not giver_of[key] and not V.RACES[key] then
							add(where, ("texts: %s is neither a giver of this quest nor a race [E-texts]"):format(key))
						end
						if not text(quest.texts[key]) then
							add(where, ("texts: %s must be a non-empty string [E-text]"):format(key))
						end
						check_text(add, where, "texts." .. key, quest.texts[key])
					end
				end
			end
			if type(quest.objectives) ~= "table" or #quest.objectives == 0 then
				add(where, "objectives must be a non-empty list [E-objective]")
			else
				for index, objective in ipairs(quest.objectives) do
					check_objective(add, where, #quest.objectives, objective, index)
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
					unknown_keys(add, dwhere, drop, V.DROP_KEYS)
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
			if quest.rewards ~= nil then check_rewards(add, where, quest.rewards) end
		end
	end
	V.free_play(errors, rows)
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

-- Free play and story (Round 57 rulings 10 and 13), in reworked files only
-- (the rework flag, V.REWORK_FLAG; the files of levels 11-60 keep their
-- chains until their rework). Only story quests chain; a free quest needs
-- nothing but a level and has at most one follow-up (a quest that names it
-- in `requires`) per faction, rarely:
--   E-free-requires   a free quest requires at most one quest (it is that
--                     quest's follow-up);
--   E-free-follow-ups a free quest is required by at most one quest of a
--                     reworked file per faction (Round 59, V.free_follow_ups;
--                     a world check: the givers' factions are resolved once
--                     every mod loaded);
--   E-free-chain      a free follow-up has no free follow-up of its own (a
--                     chain of free quests).
-- Unreworked quests count as free; their own requires are never checked.
local function free_rows(rows)
	local by_id = {}
	for _, row in ipairs(rows) do
		if type(row.quest) == "table" and type(row.quest.id) == "string" then by_id[row.quest.id] = row end
	end
	local function requires(row)
		return type(row.quest.requires) == "table" and row.quest.requires or {}
	end
	local function free(row) return row and row.quest.story ~= true end
	return by_id, requires, free
end

function V.free_play(errors, rows)
	local by_id, requires, free = free_rows(rows)
	for _, row in ipairs(rows) do
		if by_id[row.quest and row.quest.id] == row and V.reworked(row.file) and free(row) then
			local add = reporter(errors, row.file)
			local own = requires(row)
			if #own > 1 then
				add(row.where, ("a free quest requires nothing but a level and at most the one quest it " ..
					"follows (%s); only story quests chain [E-free-requires]"):format(table.concat(own, ", ")))
			end
			for _, id in ipairs(own) do
				local prior = by_id[id]
				if prior and free(prior) and #requires(prior) > 0 then
					add(row.where, ("follows %s, itself a free follow-up: only story quests chain " ..
						"[E-free-chain]"):format(id))
				end
			end
		end
	end
end

-- The factions a quest is given to (Round 59, quests.md "Story and free
-- play"): the factions its givers serve over every variant, an NPC id's
-- (`npc_faction`, the resolved registry) or a role row's filter. A giver
-- that serves everyone (no faction) or of unknown faction gives it to both.
local FACTION_NAMES = {accord = "The Accord", throng = "The Throng"}
function V.giver_factions(file, quest, npc_faction)
	local set = {}
	for _, variant in ipairs(V.variants(file, quest)) do
		for _, npc in ipairs(variant.givers) do
			local faction = npc_faction(npc)
			if V.FACTIONS[faction] then set[faction] = true else set.accord, set.throng = true, true end
		end
		for _, role in ipairs(variant.giver_roles) do
			if V.FACTIONS[role.faction] then set[role.faction] = true end
		end
	end
	if next(set) == nil then set.accord, set.throng = true, true end
	return set
end

-- E-free-follow-ups (Round 59, the user's ruling of 2026-10-24): a free
-- quest's follow-ups are counted per faction, so it may have one follow-up
-- per faction; a follow-up given to both factions counts in each.
function V.free_follow_ups(errors, rows, npc_faction)
	local by_id, requires, free = free_rows(rows)
	local followers = {}
	for _, row in ipairs(rows) do
		if by_id[row.quest and row.quest.id] == row and V.reworked(row.file) then
			local factions
			for _, id in ipairs(requires(row)) do
				factions = factions or V.giver_factions(row.file, row.quest, npc_faction)
				followers[id] = followers[id] or {accord = {}, throng = {}}
				for faction in pairs(factions) do table.insert(followers[id][faction], row.quest.id) end
			end
		end
	end
	for _, row in ipairs(rows) do
		local after = by_id[row.quest and row.quest.id] == row and V.reworked(row.file) and free(row) and
			followers[row.quest.id]
		for _, faction in ipairs(after and {"accord", "throng"} or {}) do
			local list_of = after[faction]
			if #list_of > 1 then
				table.sort(list_of)
				reporter(errors, row.file)(row.where, ("a free quest has at most one follow-up per faction, not " ..
					"%d for %s (%s); only story quests chain [E-free-follow-ups]"):format(#list_of,
					FACTION_NAMES[faction], table.concat(list_of, ", ")))
			end
		end
	end
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

-- The PvP garrison an area names ("<zone>/<settlement key>" of a fortress
-- or Battlegrounds camp, Round 31), or nil.
local function garrison_area(world, area_ref)
	local zone_id, area_id = (area_ref or ""):match("^([^/]+)/(.+)$")
	local area = zone_id and world.area(zone_id, area_id)
	return area and area.garrison and area or nil
end

-- `faction` is the quest giver's: a PvP garrison's guards and captain are
-- targets only in their own area and only of the other faction's quests
-- (pvp-plan rulings 14 and 23; a player is never a target).
local function check_target(add, where, world, zone, name, area_ref, level, what, faction)
	local role = name:match("^grug_mobs:(.+)$") or name
	if not world.entity(name) then
		add(where, ("role %s is neither a sub-type nor an existing mob [E-unknown-role]"):format(role))
		return
	end
	local garrison = garrison_area(world, area_ref)
	local disposition = world.disposition(name)
	if garrison then
		if not faction or garrison.garrison ~= world.opposing_faction(faction) then
			add(where, ("%s is a garrison of the %s; only the other faction's quests target it " ..
				"[E-garrison-faction]"):format(area_ref, garrison.garrison))
		end
	elseif disposition == "critter" then
		add(where, ("critter %s is never a %s (Ruling 29) [E-critter-target]"):format(role, what))
		return
	elseif disposition == nil then
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
	local areas = world.zone_areas(zone)
	if #areas == 0 then return end
	for _, name in ipairs(V.target_names(objective)) do
		local role = name:match("^grug_mobs:(.+)$") or name
		if world.leader(role) then return end
		for _, area in ipairs(areas) do
			if area.roles[role] then return end
		end
	end
	warn(where, ("no kill target is spawned by %s's spawn recipe [W-recipe-target]"):format(zone))
end

-- Round 38: a kill objective or quest drop counts the names its roles and
-- area select (labels.lua Q.target_names); a role that selects no name
-- could never be credited. tools/r38_names/guarantee.py proves the rest.
local function check_names(add, where, world, zone, row)
	local mobs = V.target_names(row)
	if #mobs == 0 or not world.target_names then return end
	for i, list in ipairs(world.target_names(mobs, V.area_ref(row.area, zone), zone)) do
		if #list == 0 and world.entity(mobs[i]) then
			add(where, ("%s selects no mob name: no slot of data/names.json and no garrison name " ..
				"[E-no-name]"):format(mobs[i]:match("^grug_mobs:(.+)$") or mobs[i]))
		end
	end
end

-- Every placeholder's target (a kind or camp of the zone's recipe, a leader
-- or a PvP POI) and place (a settlement key or anchor id) exists. "From here"
-- points at a compact target: an open kind spreads over many patches, so it
-- takes the zone phrasing or a named place (a warning). `zone` is where the
-- text is read (a variant's zone, Round 57).
local function check_placeholders(add, warn, where, world, zone, key, value)
	if type(value) ~= "string" then return end
	for _, p in ipairs((P.scan(value))) do
		local ref = p.args[#p.args]
		local target, reason = world.placeholder_target(zone, ref)
		if not target then
			add(where, ("%s: %s: %s [E-placeholder-target]"):format(key, p.raw, tostring(reason)))
		elseif p.kind == "captain" and not (target.what == "poi" and world.captain_name(target.id)) then
			add(where, ("%s: %s: %s is no PvP camp with a captain [E-placeholder-target]"):format(key, p.raw, ref))
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

-- Whether `role` spawns only at night (true), by day (false) or neither
-- here (nil: a leader, no area of the zone holds it): in the objective's
-- area, else in the zone's kinds and camps (the recipe's day and night
-- rosters; a camp's are the same).
local function night_only(world, zone, role, area_ref)
	if world.leader(role) then return nil end
	local areas
	if area_ref then
		local zone_id, area_id = area_ref:match("^([^/]+)/(.+)$")
		areas = {zone_id and world.area(zone_id, area_id) or nil}
	else
		areas = world.zone_areas(zone)
	end
	local day, night = false, false
	for _, area in ipairs(areas) do
		local clocks = area.clocks and area.clocks[role]
		if clocks then day, night = day or clocks.day, night or clocks.night end
	end
	if not day and not night then return nil end
	return not day
end

local function median(values)
	table.sort(values)
	local n = #values
	if n == 0 then return nil end
	if n % 2 == 1 then return values[(n + 1) / 2] end
	return (values[n / 2] + values[n / 2 + 1]) / 2
end

-- Roles, areas, levels and items against the registries, per variant (Round
-- 57: each variant's own zone, givers and targets). Returns the errors and
-- the warnings.
function V.world(files, world)
	local errors, warnings = {}, {}
	-- Reworked files only (V.REWORK_FLAG): the reward budget per zone and
	-- the kill counts by spawn phase.
	local budget, day_counts, nights = {}, {}, {}
	for _, row in ipairs(each_quest(files)) do
		local quest = row.quest
		local add = reporter(errors, row.file)
		local warn = reporter(warnings, row.file)
		local reworked = V.reworked(row.file)
		local variants = V.variants(row.file, quest)
		for _, variant in ipairs(variants) do
			local zone = variant.zone
			local vwhere = variant.implicit and row.where or ("%s: variant %s"):format(row.where, tostring(zone))
			-- The faction the variant's givers serve (a garrison target's
			-- check); nil when unknown or mixed. `false` marks a giver
			-- serving everyone (no faction).
			local givers = {}
			for _, npc in ipairs(variant.givers) do
				givers[#givers + 1] = {name = npc, faction = world.npc_faction(npc) or false}
			end
			for _, role in ipairs(variant.giver_roles) do
				givers[#givers + 1] = {name = tostring(role.role), faction = role.faction}
			end
			local faction
			for index, giver in ipairs(givers) do
				if index == 1 then faction = giver.faction or nil
				elseif giver.faction ~= givers[1].faction then faction = nil end
			end
			-- Round 57: every giver has a turn-in of its own faction (a
			-- shared quest's variants and turn-ins may serve both factions).
			local turnin_factions = {}
			for _, npc in ipairs(variant.turnins) do
				turnin_factions[world.npc_faction(npc) or false] = true
			end
			for _, role in ipairs(variant.turnin_roles) do turnin_factions[role.faction] = true end
			for _, giver in ipairs(givers) do
				if giver.faction and not turnin_factions[giver.faction] then
					add(vwhere, ("giver %s serves %s, and no turn-in of the variant does [E-turnin-faction]")
						:format(giver.name, giver.faction))
				end
			end
			for index, objective in ipairs(variant.objectives) do
				local where = ("%s: objective %d"):format(vwhere, index)
				if objective.type == "kill" then
					local area = V.area_ref(objective.area, zone)
					for _, name in ipairs(V.target_names(objective)) do
						check_target(add, where, world, zone, name, area, quest.level, "kill target", faction)
					end
					check_recipe_targets(warn, where, world, zone, objective)
					check_names(add, where, world, zone, objective)
					if reworked then
						local roles, all_night, any = V.target_names(objective), true, false
						for _, name in ipairs(roles) do
							local night = night_only(world, zone, name:match("^grug_mobs:(.+)$") or name, area)
							if night ~= nil then any = true end
							if night ~= true then all_night = false end
						end
						if any and all_night then
							nights[zone] = nights[zone] or {}
							table.insert(nights[zone], {warn = warn, where = where, count = objective.count})
						elseif any and type(objective.count) == "number" then
							day_counts[zone] = day_counts[zone] or {}
							table.insert(day_counts[zone], objective.count)
						end
					end
				elseif objective.type == "use" then
					local place, reason = world.use_place(objective.place, zone)
					if not place then add(where, ("%s [E-use-place]"):format(tostring(reason))) end
				elseif objective.type == "item" then
					if objective.item then
						check_item(add, where, world, objective.item, "item")
					elseif not world.group((objective.group:gsub("^group:", ""))) then
						add(where, ("item group %s does not exist [E-unknown-group]"):format(objective.group))
					end
					for _, name in ipairs(objective.roles and V.target_names(objective) or {}) do
						check_target(add, where, world, zone, name, V.area_ref(objective.area, zone), quest.level,
							"item source", faction)
					end
				end
			end
			for index, drop in ipairs(variant.quest_drops) do
				local where = ("%s: quest drop %d"):format(vwhere, index)
				check_item(add, where, world, drop.item, "quest drop")
				for _, name in ipairs(V.target_names(drop)) do
					check_target(add, where, world, zone, name, V.area_ref(drop.area, zone), quest.level,
						"quest-drop source", faction)
				end
				check_names(add, where, world, zone, drop)
			end
			-- The texts read in this variant's zone.
			if variant.implicit or variant.index == 1 then
				check_placeholders(add, warn, row.where, world, zone, "title", quest.title)
			end
			check_placeholders(add, warn, vwhere, world, zone, "text", variant.text or quest.text)
			check_placeholders(add, warn, vwhere, world, zone, "completion", variant.completion or quest.completion)
			for key, value in pairs(type(quest.texts) == "table" and quest.texts or {}) do
				-- A giver's text is read in its variant, a race's where a giver
				-- of that race gives it.
				local own = false
				for _, npc in ipairs(variant.givers) do
					own = own or npc == key or (V.RACES[key] and (not world.npc_race or world.npc_race(npc) == key))
				end
				if own then
					check_placeholders(add, warn, vwhere, world, zone, "texts." .. tostring(key), value)
				end
			end
		end
		local rewards = quest.rewards
		for _, item in ipairs(rewards.items or {}) do
			check_item(add, row.where, world, item.item, "reward item")
		end
		local enchants = 0
		for index, choice in ipairs(rewards.choices or {}) do
			local where = ("%s: reward choice %d"):format(row.where, index)
			check_item(add, where, world, choice.item, "reward choice")
			if world.check_affixes and world.item(choice.item) then
				local ok, reason = world.check_affixes(choice.item, choice.affixes or {})
				if not ok then add(where, ("%s [E-reward-affixes]"):format(tostring(reason))) end
			end
			enchants = math.max(enchants, #(choice.affixes or {}))
		end
		if reworked then
			-- A reward is never the requested item (Round 56 §8, ruling 17).
			local rewarded = {}
			for _, item in ipairs(rewards.items or {}) do rewarded[#rewarded + 1] = item.item end
			for _, choice in ipairs(rewards.choices or {}) do rewarded[#rewarded + 1] = choice.item end
			for _, objective in ipairs(quest.objectives) do
				if objective.type == "item" then
					local group = objective.group and objective.group:gsub("^group:", "")
					for _, item in ipairs(rewarded) do
						if item == objective.item or (group and world.item_group and world.item_group(item, group)) then
							add(row.where, ("reward %s is the requested item %s: a reward is never what the " ..
								"quest asks for [E-reward-requested]"):format(item, objective.item or objective.group))
						end
					end
				end
			end
			-- Ruling 17: the zone's equipment rewards by enchant count, per
			-- zone the quest is given in (capitals excepted).
			if enchants > 0 then
				local counted = {}
				for _, variant in ipairs(variants) do
					local zone = variant.zone
					if zone and not counted[zone] and not (world.capital and world.capital(zone)) then
						counted[zone] = true
						budget[zone] = budget[zone] or {[1] = {}, [2] = {}}
						table.insert(budget[zone][math.min(enchants, 2)], {id = quest.id, level = quest.level, add = add,
							warn = warn, where = row.where})
					end
				end
			end
		end
	end
	local zones = {}
	for zone in pairs(budget) do zones[#zones + 1] = zone end
	table.sort(zones)
	for _, zone in ipairs(zones) do
		for enchants, limit in ipairs(V.BUDGET) do
			local list_of = budget[zone][enchants]
			table.sort(list_of, function(a, b) return a.id < b.id end)
			if #list_of > limit then
				local ids = {}
				for _, entry in ipairs(list_of) do ids[#ids + 1] = entry.id end
				local last = list_of[#list_of]
				last.add(last.where, ("%s has %d equipment rewards with %d enchant%s (%s); at most %d per zone, " ..
					"capitals excepted [E-reward-budget]"):format(zone, #list_of, enchants, enchants == 1 and "" or "s",
					table.concat(ids, ", "), limit))
			end
			local levels = {}
			for _, entry in ipairs(list_of) do
				if levels[entry.level] then
					entry.warn(entry.where, ("%s and %s reward equipment with %d enchant%s at the same level %d; " ..
						"spread them over the zone [W-reward-levels]"):format(levels[entry.level], entry.id, enchants,
						enchants == 1 and "" or "s", entry.level))
				end
				levels[entry.level] = levels[entry.level] or entry.id
			end
		end
	end
	-- Round 59: a free quest's follow-ups per faction (V.free_follow_ups).
	V.free_follow_ups(errors, each_quest(files), world.npc_faction)
	zones = {}
	for zone in pairs(nights) do zones[#zones + 1] = zone end
	table.sort(zones)
	for _, zone in ipairs(zones) do
		local reference = median(day_counts[zone] or {})
		for _, entry in ipairs(reference and nights[zone] or {}) do
			local share = entry.count / reference
			if share < V.NIGHT_SHARE[1] or share > V.NIGHT_SHARE[2] then
				entry.warn(entry.where, ("a night-only target's count %d is not about a third of the zone's day " ..
					"counts (median %s; one night is 5 minutes, a day 15) [W-night-count]")
					:format(entry.count, tostring(reference)))
			end
		end
	end
	return errors, warnings
end

-- The level range shown with an objective (Lane Q0): the levels its targets
-- are met at, so a player can judge them without a signal word in the name.
-- Per role, first match: a named leader's fixed level; in the objective's
-- area (a kind or camp) that role's levels there; the role's levels in the
-- kinds and camps of the quest zone's recipe (the level-fit check's source);
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
	local function add(names, area_ref)
		for _, name in ipairs(names) do
			local a, b = role_range(world, zone, quest.level, name:match("^grug_mobs:(.+)$") or name, area_ref)
			if a then lo, hi = math.min(lo or a, a), math.max(hi or b, b) end
		end
	end
	if objective.type == "kill" then
		add(V.target_names(objective), V.area_ref(objective.area, zone))
	elseif objective.type == "item" then
		if objective.roles then add(V.target_names(objective), V.area_ref(objective.area, zone)) end
		for _, drop in ipairs(objective.item and quest.quest_drops or {}) do
			if drop.item == objective.item then add(V.target_names(drop), V.area_ref(drop.area, zone)) end
		end
	end
	return lo and {lo, hi} or nil
end
