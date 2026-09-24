local Q = grug_quests
local KEY = "grug_quests:state"
local callbacks, busy = {}, {}
local function load(player)
	local state = core.deserialize(player:get_meta():get_string(KEY))
	return state or {active = {}, completed = {}, tracked = {}, hud = true}
end
local function save(player, state)
	player:get_meta():set_string(KEY, core.serialize(state))
end
local function changed(player)
	for _, callback in ipairs(callbacks) do callback(player) end
end
function Q.register_on_change(callback) callbacks[#callbacks + 1] = callback end
local function owned_lists(player)
	local lists, inv = {"main"}, player:get_inventory()
	for i = 1, grug_inventory.BAG_COUNT do
		local bag = inv:get_stack(grug_inventory.bag_list(i), 1)
		if grug_inventory.bag_slots_of(bag) > 0 then
			lists[#lists + 1] = grug_inventory.content_list(i)
		end
	end
	return lists
end
local function holdings(player)
	local counts, inv = {}, player:get_inventory()
	for _, list in ipairs(owned_lists(player)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			local name = stack:get_name()
			counts[name] = (counts[name] or 0) + stack:get_count()
		end
	end
	return counts
end
local function permitted(player, def, state)
	if def.faction and def.faction ~= grug_factions.get_faction(player) then return false, "This quest belongs to another faction." end
	if def.race and def.race ~= grug_classes.get_race(player) then return false, "This quest belongs to another homeland." end
	if grug_xp.get_level(player) < def.min_level then return false, "Requires level " .. def.min_level .. "." end
	for _, id in ipairs(def.prerequisites) do
		if not state.completed[id] then return false, "Complete the preceding quest first." end
	end
	return true
end
local function progress(player, def, active, snapshot)
	local counts, rows, ready = table.copy(snapshot or holdings(player)), {}, true
	for index, objective in ipairs(def.objectives) do
		local count
		if objective.type == "kill" or objective.type == "talk" then count = active[index] or 0
		else
			count = math.min(objective.count, counts[objective.item] or 0)
			counts[objective.item] = (counts[objective.item] or 0) - count
		end
		rows[index] = {type = objective.type, item = objective.item, mobs = objective.mobs, npc = objective.npc,
			count = count, required = objective.count, description = objective.description}
		if count < objective.count then ready = false end
	end
	return rows, ready
end
function Q.status(player, id)
	local def, state = Q.registered_quests[id], load(player)
	if not def then return "unknown" end
	if state.completed[id] then return "completed" end
	if state.active[id] then
		local _, ready = progress(player, def, state.active[id])
		return ready and "ready" or "active"
	end
	local allowed, reason = permitted(player, def, state)
	return allowed and "available" or "locked", reason
end
-- One bounded state/holdings snapshot for one NPC viewer; no persistent cache.
function Q.npc_quests(player, npc)
	local state, rows, counts = load(player), {}, nil
	for id in pairs(Q.quests_by_npc[npc] or {}) do
		local def = Q.registered_quests[id]
		local relevant = not state.completed[id] and
			(not def.faction or def.faction == grug_factions.get_faction(player)) and
			(not def.race or def.race == grug_classes.get_race(player))
		for _, prior in ipairs(def.prerequisites) do
			if not state.completed[prior] then relevant = false end
		end
		local active = state.active[id]
		if relevant and (active and def.turnin_npc or def.npc) == npc then
			local status, reason
			if active then
				counts = counts or holdings(player)
				local _, ready = progress(player, def, active, counts)
				status = ready and "ready" or "active"
			else
				local allowed
				allowed, reason = permitted(player, def, state)
				status = allowed and "available" or "locked"
			end
			rows[#rows + 1] = {id = id, title = def.title, status = status, reason = reason}
		end
	end
	table.sort(rows, function(a, b) return a.id < b.id end)
	return rows
end
function Q.accept(player, id)
	local def, state = Q.registered_quests[id], load(player)
	if not def or state.active[id] or state.completed[id] then return false, "This quest is not available." end
	local allowed, reason = permitted(player, def, state)
	if not allowed then return false, reason end
	local count = 0
	for _ in pairs(state.active) do count = count + 1 end
	if count >= 20 then return false, "Your quest log is full (20 quests). Complete or abandon a quest first." end
	state.active[id] = {}
	if #state.tracked < 3 then state.tracked[#state.tracked + 1] = id end
	save(player, state)
	changed(player)
	return true
end
-- Called only after the dialogue owner verifies the live NPC and handoff
-- distance. Merely viewing its atlas marker or quest-log entry earns no credit.
function Q.credit_conversation(player, npc)
	if not Q.registered_npcs[npc] then return false end
	local state, dirty = load(player), false
	for id, counters in pairs(state.active) do
		local def = Q.registered_quests[id]
		if permitted(player, def, state) then
			for index, objective in ipairs(def.objectives) do
				if objective.type == "talk" and objective.npc == npc and
						(counters[index] or 0) < 1 then
					counters[index], dirty = 1, true
				end
			end
		end
	end
	if dirty then save(player, state); changed(player) end
	return dirty
end
local function untrack(state, id)
	for i = #state.tracked, 1, -1 do
		if state.tracked[i] == id then table.remove(state.tracked, i) end
	end
end
function Q.abandon(player, id)
	local state = load(player)
	if not state.active[id] then return false end
	state.active[id] = nil
	untrack(state, id)
	save(player, state)
	changed(player)
	return true
end
function Q.set_tracked(player, id, enabled)
	local state = load(player)
	if not state.active[id] then return false end
	untrack(state, id)
	if enabled then
		if #state.tracked >= 3 then return false, "Track at most three quests." end
		state.tracked[#state.tracked + 1] = id
	end
	save(player, state)
	changed(player)
	return true
end
function Q.set_hud_enabled(player, enabled)
	local state = load(player)
	state.hud = enabled == true
	save(player, state)
	changed(player)
end
function Q.journal(player)
	local state, rows = load(player), {}
	local counts = next(state.active) and holdings(player) or {}
	local ids = {}
	for id in pairs(state.active) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		local objectives, ready = progress(player, def, state.active[id], counts)
		rows[#rows + 1] = {id = id, title = def.title, description = def.description,
			objectives = objectives, ready = ready, npc = def.turnin_npc, rewards = table.copy(def.rewards)}
	end
	return {quests = rows, tracked = state.tracked, hud_enabled = state.hud ~= false}
end
-- Preflight copies every owned slot. Removing requirements and adding rewards
-- to the same copies accounts for space freed by this very hand-in.
local function settlement(player, def)
	local inv, rows = player:get_inventory(), {}
	for _, list in ipairs(owned_lists(player)) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			rows[#rows + 1] = {list = list, index = index, expected = ItemStack(stack), replacement = ItemStack(stack)}
		end
	end
	for _, objective in ipairs(def.objectives) do
		if objective.type == "item" then
			local remaining = objective.count
			for _, row in ipairs(rows) do
				local stack = row.replacement
				if stack:get_name() == objective.item then
					local take = math.min(remaining, stack:get_count())
					stack:take_item(take)
					remaining = remaining - take
				end
			end
			if remaining > 0 then return nil, "You no longer have all required items." end
		end
	end
	for _, reward in ipairs(def.rewards.items) do
		local rest = ItemStack(reward)
		-- Fill compatible partial stacks before spending an empty slot.
		for pass = 1, 2 do
			for _, row in ipairs(rows) do
				if (pass == 1 and not row.replacement:is_empty()) or (pass == 2 and row.replacement:is_empty()) then
					rest = row.replacement:add_item(rest)
				end
			end
		end
		if not rest:is_empty() then return nil, "Make room in your inventory or bags for the rewards." end
	end
	return rows
end
function Q.turn_in(player, id)
	local name, state = player:get_player_name(), load(player)
	local def = Q.registered_quests[id]
	if busy[name] or not def or not state.active[id] then return false, "This quest is not active." end
	local allowed, reason = permitted(player, def, state)
	if not allowed then return false, reason end
	local _, ready = progress(player, def, state.active[id])
	if not ready then return false, "The objectives are not complete." end
	if grug_money.get(player) + def.rewards.copper > grug_money.MAX then return false, "Your coin purse cannot hold the reward." end
	local rows, error_message = settlement(player, def)
	if not rows then return false, error_message end
	local inv = player:get_inventory()
	for _, row in ipairs(rows) do
		if not inv:get_stack(row.list, row.index):equals(row.expected) then return false, "Your inventory changed." end
	end
	busy[name] = true
	for i, row in ipairs(rows) do
		if not row.replacement:equals(row.expected) and not inv:set_stack(row.list, row.index, row.replacement) then
			for j = 1, i - 1 do inv:set_stack(rows[j].list, rows[j].index, rows[j].expected) end
			busy[name] = nil
			return false, "Your inventory changed."
		end
	end
	state.active[id], state.completed[id] = nil, true
	untrack(state, id)
	save(player, state)
	-- Persist the one-time claim before reward APIs publish callbacks.
	-- Both reward owners write their ledger before notifying consumers. A
	-- failing money observer must not prevent delivery of the XP reward.
	local money_ok, money_error = pcall(grug_money.add, player, def.rewards.copper)
	local xp_ok, xp_error = pcall(grug_xp.add_xp, player, def.rewards.xp, "quest")
	busy[name] = nil
	if not money_ok then error(money_error, 0) end
	if not xp_ok then error(xp_error, 0) end
	changed(player)
	return true
end
function Q.credit_kill(player, mob, pos)
	local state, dirty = load(player), false
	if grug_factions.same_faction(player, mob.object) then return end
	for id, counters in pairs(state.active) do
		local def = Q.registered_quests[id]
		if permitted(player, def, state) then
			for index, objective in ipairs(def.objectives) do
				if objective.type == "kill" and (not objective.zone or grug_zones.id_at(pos.x, pos.z) == objective.zone) then
					for _, target in ipairs(objective.mobs) do
						if target == mob.name then
							local before = counters[index] or 0
							counters[index] = math.min(objective.count, before + 1)
							dirty = dirty or counters[index] ~= before
							break
						end
					end
				end
			end
		end
	end
	if dirty then save(player, state); changed(player) end
end
grug_mobs.register_on_eligible_kill(Q.credit_kill)
