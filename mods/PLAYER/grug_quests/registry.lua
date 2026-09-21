local quests, npcs = {}, {}
grug_quests.registered_quests = quests
grug_quests.registered_npcs = npcs
grug_quests.quests_by_npc = {}
grug_quests.npc_by_socket = {}
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
function grug_quests.register_quest(id, def)
	assert(type(id) == "string" and not quests[id], "Duplicate quest")
	assert(type(def.title) == "string" and type(def.description) == "string")
	def = table.copy(def)
	def.id = id
	def.turnin_npc = def.turnin_npc or def.npc
	def.min_level = def.min_level or 1
	def.prerequisites = def.prerequisites or {}
	def.rewards = def.rewards or {}
	def.rewards.xp = def.rewards.xp or 0
	def.rewards.copper = def.rewards.copper or 0
	def.rewards.items = def.rewards.items or {}
	assert(integer(def.min_level) and def.min_level >= 1)
	assert(integer(def.rewards.xp) and integer(def.rewards.copper))
	assert(type(def.objectives) == "table" and #def.objectives > 0)
	for _, objective in ipairs(def.objectives) do
		assert(integer(objective.count) and objective.count > 0)
		assert(objective.type == "item" or objective.type == "kill")
		if objective.type == "item" then assert(type(objective.item) == "string")
		else
			objective.mobs = objective.mobs or {objective.mob}
			assert(#objective.mobs > 0)
		end
	end
	quests[id] = def
	for _, npc in ipairs({def.npc, def.turnin_npc}) do
		local index = grug_quests.quests_by_npc[npc] or {}
		grug_quests.quests_by_npc[npc] = index
		index[id] = true
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
		for _, objective in ipairs(def.objectives) do
			if objective.type == "item" then
				assert(core.registered_items[objective.item], "Unknown quest item: " .. id)
			else
				for _, mob in ipairs(objective.mobs) do
					assert(core.registered_entities[mob], "Unknown quest mob: " .. id)
				end
			end
		end
		for _, item in ipairs(def.rewards.items) do
			local stack = ItemStack(item)
			assert(not stack:is_empty() and core.registered_items[stack:get_name()], "Invalid quest reward")
		end
	end
end
