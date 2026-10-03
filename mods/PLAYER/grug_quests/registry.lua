local quests, npcs = {}, {}
grug_quests.registered_quests = quests
grug_quests.registered_npcs = npcs
grug_quests.quests_by_npc = {}
grug_quests.npc_by_socket = {}
-- Entity names any quest-only drop can come from (roll_quest_drops' early exit).
grug_quests.quest_drop_mobs = {}
local function integer(n)
	return type(n) == "number" and n >= 0 and n <= 2147483647 and n % 1 == 0
end
function grug_quests.register_npc(id, def)
	assert(type(id) == "string" and not npcs[id], "Duplicate quest NPC")
	assert(type(def.settlement) == "string" and type(def.socket) == "string")
	local key = def.settlement .. "/" .. def.socket
	assert(not grug_quests.npc_by_socket[key], "Duplicate quest socket")
	grug_quests.npc_by_socket[key] = id
	npcs[id] = table.copy(def)
end
-- Objectives (Round 28 rulings 39 and 41): `kill` names `mobs` (entity
-- names; the loader turns design `roles` into them), optionally limited to
-- one spawn `area` ("zone/area", credited by the mob's `_grug_area` tag),
-- and `zones`, the zone each target's label names it in (labels.lua);
-- `item` names one `item` or an item `group`; `talk` is a travel quest's
-- only objective.
function grug_quests.register_quest(id, def)
	assert(type(id) == "string" and not quests[id], "Duplicate quest")
	assert(type(def.title) == "string" and type(def.description) == "string")
	def = table.copy(def)
	def.id = id
	def.turnin_npc = def.turnin_npc or def.npc
	def.min_level = def.min_level or 1
	def.level = def.level or def.min_level
	def.prerequisites = def.prerequisites or {}
	def.rewards = def.rewards or {}
	def.rewards.copper = def.rewards.copper or 0
	def.rewards.items = def.rewards.items or {}
	def.quest_drops = def.quest_drops or {}
	-- Rewards are a weight in kill equivalents at the reward level (ruling 32).
	assert(type(def.rewards.weight) == "number" and def.rewards.weight >= 0, "Invalid quest reward weight")
	assert(integer(def.min_level) and def.min_level >= 1 and integer(def.level) and def.level >= 1)
	assert(integer(def.rewards.copper))
	assert(not def.repeatable or (integer(def.repeatable.cooldown) and def.repeatable.cooldown > 0))
	assert(type(def.objectives) == "table" and #def.objectives > 0)
	for _, objective in ipairs(def.objectives) do
		assert(integer(objective.count) and objective.count > 0)
		assert(objective.type == "item" or objective.type == "kill" or objective.type == "talk")
		if objective.type == "item" then
			assert((type(objective.item) == "string") ~= (type(objective.group) == "string"),
				"An item objective names one item or one group")
		elseif objective.type == "talk" then
			assert(type(objective.npc) == "string" and objective.count == 1,
				"A conversation objective names one destination NPC")
			assert(#def.objectives == 1 and objective.npc == def.turnin_npc,
				"Travel handoffs contain only a conversation at their turn-in NPC")
		else
			assert(type(objective.mobs) == "table" and #objective.mobs > 0, "A kill objective names its mobs")
		end
	end
	for _, drop in ipairs(def.quest_drops) do
		assert(type(drop.item) == "string" and integer(drop.chance) and drop.chance > 0 and
			type(drop.mobs) == "table" and #drop.mobs > 0, "Invalid quest drop")
		for _, name in ipairs(drop.mobs) do grug_quests.quest_drop_mobs[name] = true end
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
	def.description = def.description .. "\n\nRequirements: " ..
		table.concat(requirements, "; ") .. "."
	quests[id] = def
	for _, npc in ipairs({def.npc, def.turnin_npc}) do
		local index = grug_quests.quests_by_npc[npc] or {}
		grug_quests.quests_by_npc[npc] = index
		index[id] = true
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
-- registered; an NPC whose race has no faction serves everyone.
function grug_quests.resolve_npc_factions()
	local race_of = {}
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		race_of[record.key] = record.race_id
	end
	for _, npc in pairs(npcs) do
		local race = grug_classes.registered_races[npc.race or race_of[npc.settlement]]
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
	for id, def in pairs(quests) do
		visit(id)
		assert(npcs[def.npc] and npcs[def.turnin_npc], "Unknown quest NPC: " .. id)
		-- A quest never sends a player to an NPC that will not serve them (a
		-- conversation's NPC is the turn-in NPC, register_quest).
		assert(npcs[def.turnin_npc].faction == npcs[def.npc].faction,
			"Quest turn-in NPC of another faction: " .. id)
		for _, objective in ipairs(def.objectives) do
			if objective.type == "item" then
				assert(not objective.item or core.registered_items[objective.item], "Unknown quest item: " .. id)
			elseif objective.type == "talk" then
				assert(npcs[objective.npc], "Unknown conversation NPC: " .. id)
			else
				for _, mob in ipairs(objective.mobs) do
					assert(core.registered_entities[mob], "Unknown quest mob: " .. id)
				end
			end
		end
		for _, drop in ipairs(def.quest_drops) do
			assert(core.registered_items[drop.item], "Unknown quest drop: " .. id)
		end
		for _, item in ipairs(def.rewards.items) do
			local stack = ItemStack(item)
			assert(not stack:is_empty() and core.registered_items[stack:get_name()], "Invalid quest reward")
		end
	end
end
