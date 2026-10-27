local quests, npcs = {}, {}
grug_quests.registered_quests = quests
grug_quests.registered_npcs = npcs
grug_quests.quests_by_npc = {}
grug_quests.npc_by_socket = {}
-- Mob names any quest-only drop can come from (roll_quest_drops' early
-- exit; Round 38: a drop counts by the name the mob shows).
grug_quests.quest_drop_names = {}
local function integer(n)
	return type(n) == "number" and n >= 0 and n <= 2147483647 and n % 1 == 0
end
-- `def`: {settlement, socket, title, race (a new giver's own), role (Round
-- 57: a giver role such as a camp foreman; a quest may name every NPC of a
-- role and faction as its givers or turn-ins, Q.bind_role_givers)}.
function grug_quests.register_npc(id, def)
	assert(type(id) == "string" and not npcs[id], "Duplicate quest NPC")
	assert(type(def.settlement) == "string" and type(def.socket) == "string")
	assert(def.role == nil or (type(def.role) == "string" and def.role ~= ""), "Invalid quest NPC role")
	local key = def.settlement .. "/" .. def.socket
	assert(not grug_quests.npc_by_socket[key], "Duplicate quest socket")
	grug_quests.npc_by_socket[key] = id
	npcs[id] = table.copy(def)
end
-- The one acceptance rule (Round 65 ruling 3): a quest is accepted from its
-- quest level - 2, at least 1, story quests and departures alike. The quest
-- level is the one source; quest data never names a minimum level
-- (tools/r28_design/r28common.py acceptance_level computes the same).
grug_quests.ACCEPT_BELOW = 2
function grug_quests.acceptance_level(level)
	return math.max(1, level - grug_quests.ACCEPT_BELOW)
end
-- The hold of a "use at a place" objective, in whole seconds.
grug_quests.USE_HOLD_MIN, grug_quests.USE_HOLD_MAX = 1, 15
-- A choice of rewards has 2..MAX_CHOICES entries (one row in the dialog).
grug_quests.MAX_CHOICES = 4
-- Objectives (Round 28 rulings 39 and 41): `kill` names `mobs` (entity
-- names; the loader turns design `roles` into them), optionally one spawn
-- `area` ("zone/area"); both only select `names` (per role, labels.lua
-- Q.target_names) and `name_set`: a kill counts by the name the mob shows
-- (Round 38);
-- `item` names one `item` or an item `group`; `talk` is a travel quest's
-- only objective; `use` (Round 36) names a `place` (a clash site's
-- settlement key or a recipe quest place "zone/id", use.lua), the `object`
-- kind shown there, the `label` of the act and its `hold` in seconds, and
-- counts once.
-- Variants (Round 57, ruling 9): one quest id and one completion, given in
-- several places. `def.variants` is a list of {key, zone, givers, turnins
-- (NPC ids; the turn-ins default to the givers), giver_roles, turnin_roles
-- ({role, faction}: every NPC of that role serving that faction, bound once
-- every mod is loaded), objectives, quest_drops (the zone-bound targets:
-- each variant counts its own zone's names), description, completion};
-- the counts and the rewards are the quest's own. A definition without
-- `variants` is one variant of `def.npc`, `def.turnin_npc`,
-- `def.objectives` and `def.quest_drops`, and those four fields always
-- read the first variant's. An NPC gives a quest in one variant only
-- (`def.giver_variant`), so the giver a player takes it from names the
-- variant (state.lua).
-- `def.story` (ruling 13) marks a story quest; `def.completion` is the
-- closing paragraph of the turn-in (ruling 14); `def.texts` maps a giver's
-- NPC id or race to its own text (ruling 9). `rewards.choices` (ruling 15)
-- is a list of {item = "name count", affixes = {{channel, stat}, ...}}: the
-- player picks one at the turn-in. Reward equipment is made at the quest's
-- reward level (grug_items.make_stack, state.lua).
-- A system quest (Round 48, mail plan §3.18) is registered by code with
-- `system = true`: no NPC, no objectives, no quest drops, no choice. Its
-- own mod accepts it through Q.accept and turns it in through Q.turn_in
-- (the one completion path); `turnin_text` is what the quest log and the
-- tracker show instead of "Return to <NPC>".
local function index_npc(npc, id)
	local index = grug_quests.quests_by_npc[npc] or {}
	grug_quests.quests_by_npc[npc] = index
	index[id] = true
end
local function set_of(list)
	local out = {}
	for _, value in ipairs(list) do out[value] = true end
	return out
end
local function check_variant(variant)
	for _, objective in ipairs(variant.objectives) do
		assert(integer(objective.count) and objective.count > 0)
		assert(objective.type == "item" or objective.type == "kill" or objective.type == "talk" or
			objective.type == "use")
		if objective.type == "item" then
			assert((type(objective.item) == "string") ~= (type(objective.group) == "string"),
				"An item objective names one item or one group")
		elseif objective.type == "talk" then
			assert(type(objective.npc) == "string" and objective.count == 1,
				"A conversation objective names one destination NPC")
			assert(#variant.objectives == 1 and #variant.turnins == 1 and #variant.turnin_roles == 0 and
				objective.npc == variant.turnins[1],
				"Travel handoffs contain only a conversation at their turn-in NPC")
		elseif objective.type == "use" then
			assert(type(objective.place) == "string" and type(objective.label) == "string" and
				objective.label ~= "" and grug_quests.use_objects[objective.object] and
				integer(objective.hold) and objective.hold >= grug_quests.USE_HOLD_MIN and
				objective.hold <= grug_quests.USE_HOLD_MAX and objective.count == 1,
				"A use objective names its place, object, label and hold and counts once")
		else
			assert(type(objective.mobs) == "table" and #objective.mobs > 0, "A kill objective names its mobs")
		end
	end
	for _, drop in ipairs(variant.quest_drops) do
		assert(type(drop.item) == "string" and integer(drop.chance) and drop.chance > 0 and
			type(drop.mobs) == "table" and #drop.mobs > 0, "Invalid quest drop")
		for name in pairs(drop.name_set or {}) do grug_quests.quest_drop_names[name] = true end
	end
end
function grug_quests.register_quest(id, def)
	assert(type(id) == "string" and not quests[id], "Duplicate quest")
	assert(type(def.title) == "string" and type(def.description) == "string")
	def = table.copy(def)
	def.id = id
	-- `min_level` is derived, never given (Round 65 ruling 3).
	assert(def.min_level == nil, "A quest names its level only; it is accepted from level - 2")
	def.level = def.level or 1
	def.prerequisites = def.prerequisites or {}
	def.rewards = def.rewards or {}
	def.rewards.copper = def.rewards.copper or 0
	def.rewards.items = def.rewards.items or {}
	def.rewards.choices = def.rewards.choices or {}
	-- Rewards are a weight in kill equivalents at the reward level (ruling 32).
	assert(type(def.rewards.weight) == "number" and def.rewards.weight >= 0, "Invalid quest reward weight")
	assert(integer(def.level) and def.level >= 1)
	def.min_level = grug_quests.acceptance_level(def.level)
	assert(integer(def.rewards.copper))
	-- Round 57 ruling 11: every quest is done exactly once.
	assert(def.repeatable == nil, "No repeatable quests")
	assert(#def.rewards.choices ~= 1 and #def.rewards.choices <= grug_quests.MAX_CHOICES,
		"A choice of rewards has 2.." .. grug_quests.MAX_CHOICES .. " entries")
	for _, choice in ipairs(def.rewards.choices) do
		assert(type(choice) == "table" and type(choice.item) == "string" and
			(choice.affixes == nil or type(choice.affixes) == "table"), "Invalid reward choice")
		choice.affixes = choice.affixes or {}
	end
	assert(def.texts == nil or type(def.texts) == "table")
	assert(def.completion == nil or type(def.completion) == "string")
	def.story = def.story == true
	if def.system then
		assert(def.npc == nil and def.turnin_npc == nil and #(def.objectives or {}) == 0 and
			#(def.quest_drops or {}) == 0 and def.variants == nil and #def.rewards.choices == 0 and
			type(def.turnin_text) == "string" and def.turnin_text ~= "",
			"A system quest has no NPC, objectives, quest drops or choice and names its turn-in text")
		def.variants = {{key = "system"}}
	elseif def.variants == nil then
		def.variants = {{key = def.zone or "main", zone = def.zone, givers = {def.npc},
			turnins = {def.turnin_npc or def.npc}, objectives = def.objectives, quest_drops = def.quest_drops}}
	end
	local requirements = {"Minimum level: " .. def.min_level}
	if #def.prerequisites > 0 then
		local titles = {}
		for _, prerequisite in ipairs(def.prerequisites) do
			local prior = assert(quests[prerequisite],
				"Register prerequisite before dependent quest: " .. prerequisite)
			titles[#titles + 1] = prior.title
		end
		requirements[#requirements + 1] = "Complete: " .. table.concat(titles, ", ")
	end
	local suffix = "\n\nRequirements: " .. table.concat(requirements, "; ") .. "."
	def.description = def.description .. suffix
	for key, text in pairs(def.texts or {}) do
		assert(type(key) == "string" and type(text) == "string", "Invalid quest text")
		def.texts[key] = text .. suffix
	end
	def.variant_by_key, def.variant_order, def.giver_variant = {}, {}, {}
	for _, variant in ipairs(def.variants) do
		assert(type(variant.key) == "string" and not def.variant_by_key[variant.key], "Duplicate quest variant")
		variant.givers = variant.givers or {}
		variant.turnins = variant.turnins or table.copy(variant.givers)
		variant.giver_roles = variant.giver_roles or {}
		variant.turnin_roles = variant.turnin_roles or table.copy(variant.giver_roles)
		variant.objectives = variant.objectives or {}
		variant.quest_drops = variant.quest_drops or {}
		if variant.description then variant.description = variant.description .. suffix end
		if not def.system then
			assert(#variant.objectives > 0, "A quest names its objectives")
			assert(#variant.givers + #variant.giver_roles > 0, "A quest variant names its givers")
		end
		check_variant(variant)
		variant.giver_set, variant.turnin_set = set_of(variant.givers), set_of(variant.turnins)
		for _, npc in ipairs(variant.givers) do
			assert(type(npc) == "string" and not def.giver_variant[npc], "An NPC gives a quest in one variant only")
			def.giver_variant[npc] = variant.key
			index_npc(npc, id)
		end
		for _, npc in ipairs(variant.turnins) do
			assert(type(npc) == "string")
			index_npc(npc, id)
		end
		def.variant_by_key[variant.key] = variant
		def.variant_order[#def.variant_order + 1] = variant.key
	end
	local first = def.variants[1]
	def.npc, def.turnin_npc = first.givers[1], first.turnins[1]
	def.objectives, def.quest_drops = first.objectives, first.quest_drops
	quests[id] = def
end
-- Round 57: every NPC of a variant's giver and turn-in roles ({role,
-- faction}) gives and takes it; bound once every mod registered its NPCs
-- and their factions are resolved (init.lua, after resolve_npc_factions).
function grug_quests.bind_role_givers()
	local ids = {}
	for id in pairs(npcs) do ids[#ids + 1] = id end
	table.sort(ids)
	local function of_role(row)
		local out = {}
		for _, npc in ipairs(ids) do
			if npcs[npc].role == row.role and npcs[npc].faction == row.faction then out[#out + 1] = npc end
		end
		return out
	end
	for id, def in pairs(quests) do
		for _, variant in ipairs(def.variants) do
			for _, row in ipairs(variant.giver_roles) do
				for _, npc in ipairs(of_role(row)) do
					assert((def.giver_variant[npc] or variant.key) == variant.key,
						"An NPC gives a quest in one variant only: " .. id)
					if not variant.giver_set[npc] then
						variant.givers[#variant.givers + 1], variant.giver_set[npc] = npc, true
					end
					def.giver_variant[npc] = variant.key
					index_npc(npc, id)
				end
			end
			for _, row in ipairs(variant.turnin_roles) do
				for _, npc in ipairs(of_role(row)) do
					if not variant.turnin_set[npc] then
						variant.turnins[#variant.turnins + 1], variant.turnin_set[npc] = npc, true
					end
					index_npc(npc, id)
				end
			end
		end
		local first = def.variants[1]
		def.npc, def.turnin_npc = first.givers[1], first.turnins[1]
	end
end
-- Quest copper when a quest names none (Round 29 Q1, economy-vendor-plan.md
-- section 4, the WP44 cutover column): round_half_up(0.08 x P(T) x weight),
-- at least 1c for a weight above 0, T the reward level's tier band (1-10 ->
-- 1, ..., 51-60 -> 6). Integer arithmetic, so a .5 rounds up exactly.
grug_quests.COPPER_PRICE = {25, 65, 160, 400, 1000, 2500}
function grug_quests.quest_copper(level, weight)
	if weight <= 0 then return 0 end
	local tier = math.max(1, math.min(6, math.floor((level - 1) / 10) + 1))
	return math.max(1, math.floor((8 * grug_quests.COPPER_PRICE[tier] * weight + 50) / 100))
end
-- The quest's reward XP before the race bonus (grug_xp.add_xp applies it).
function grug_quests.reward_xp(def)
	return grug_xp.quest_reward(def.level, def.rewards.weight)
end
-- A travel quest: one conversation at its destination, credited on accept
-- (ruling 39); the HUD reads "Travel to <NPC>".
function grug_quests.is_travel(def)
	return #def.objectives == 1 and def.objectives[1].type == "talk"
end
-- Ruling 13 (Round 31): a quest NPC serves only its faction, the faction of
-- its own race (a new giver may name one, loader.lua) or else of its
-- settlement's race, the race its quest shell is drawn as (grug_mobs
-- start_npcs.lua). Resolved once mods are loaded, when every settlement is
-- registered; an NPC whose race has no faction serves everyone. The race
-- (`race_id`) also picks a quest's text per race (labels.lua).
function grug_quests.resolve_npc_factions()
	local race_of = {}
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		race_of[record.key] = record.race_id
	end
	for _, npc in pairs(npcs) do
		npc.race_id = npc.race or race_of[npc.settlement]
		local race = grug_classes.registered_races[npc.race_id]
		npc.faction = race and race.faction or nil
	end
end
function grug_quests.validate_registry()
	local visiting, done = {}, {}
	local function visit(id)
		assert(quests[id], "Unknown prerequisite: " .. id)
		assert(not visiting[id], "Quest prerequisite cycle: " .. id)
		if done[id] then return end
		visiting[id] = true
		for _, prior in ipairs(quests[id].prerequisites) do visit(prior) end
		visiting[id], done[id] = nil, true
	end
	local sockets = {}
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
			sockets[record.key .. "/" .. socket.id] = socket
		end
	end
	local used = {}
	for id, npc in pairs(npcs) do
		local key = npc.settlement .. "/" .. npc.socket
		assert(sockets[key] and sockets[key].role == "quest", "Unknown quest socket: " .. id)
		assert(not used[key], "Duplicate quest socket: " .. id)
		used[key] = true
	end
	local items_api = rawget(_G, "grug_items")
	for id, def in pairs(quests) do
		visit(id)
		for _, variant in ipairs(def.variants) do
			-- A system quest has no NPC (register_quest).
			if not def.system then
				assert(#variant.givers > 0 and #variant.turnins > 0, "Quest without a giver or turn-in NPC: " .. id)
				for _, npc in ipairs(variant.givers) do assert(npcs[npc], "Unknown quest NPC: " .. id) end
				for _, npc in ipairs(variant.turnins) do assert(npcs[npc], "Unknown quest NPC: " .. id) end
				-- A quest never sends a player to an NPC that will not serve
				-- them: each giver has a turn-in of its own faction in its
				-- variant (Round 57: a shared quest may span both factions; a
				-- conversation's NPC is the turn-in NPC, register_quest).
				for _, giver in ipairs(variant.givers) do
					local paired = false
					for _, turnin in ipairs(variant.turnins) do
						if npcs[turnin].faction == npcs[giver].faction then paired = true end
					end
					assert(paired, "Quest turn-in NPC of another faction: " .. id)
				end
			end
			for _, objective in ipairs(variant.objectives) do
				if objective.type == "item" then
					assert(not objective.item or core.registered_items[objective.item], "Unknown quest item: " .. id)
				elseif objective.type == "talk" then
					assert(npcs[objective.npc], "Unknown conversation NPC: " .. id)
				elseif objective.type == "use" then
					assert(grug_quests.use_place(objective.place), "Unknown use place: " .. id)
				else
					for _, mob in ipairs(objective.mobs) do
						assert(core.registered_entities[mob], "Unknown quest mob: " .. id)
					end
				end
			end
			for _, drop in ipairs(variant.quest_drops) do
				assert(core.registered_items[drop.item], "Unknown quest drop: " .. id)
			end
		end
		for _, item in ipairs(def.rewards.items) do
			local stack = ItemStack(item)
			assert(not stack:is_empty() and core.registered_items[stack:get_name()], "Invalid quest reward")
		end
		for _, choice in ipairs(def.rewards.choices) do
			local stack = ItemStack(choice.item)
			assert(not stack:is_empty() and core.registered_items[stack:get_name()], "Invalid quest reward choice")
			assert(not items_api or items_api.check_affixes(choice.item, choice.affixes),
				"Invalid enchants on a reward choice: " .. id)
		end
	end
end
