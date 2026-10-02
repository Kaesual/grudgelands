local Q = grug_quests
local KEY = "grug_quests:state"
-- The one tracker cap (Round 24 ruling 23): the HUD tracker, the auto-track on
-- accept and the quest-log notice all read this constant.
Q.MAX_TRACKED = 10
-- Repeatable cooldowns count real seconds from turn-in (Round 28 ruling 42),
-- so a bounty is ready again after the same wait whether or not the server
-- was running in between. Fixtures replace the clock.
Q.clock = os.time
local callbacks, busy = {}, {}
-- `completed` keeps the first completion forever (prerequisites read it);
-- `cooldowns` holds when a completed repeatable may be accepted again.
local function load(player)
	local state = core.deserialize(player:get_meta():get_string(KEY)) or
		{active = {}, completed = {}, tracked = {}, hud = true}
	state.cooldowns = state.cooldowns or {}
	return state
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
-- Does an item objective accept this item name? One item, or any member of
-- the objective's group ("any log").
local function accepts(objective, name)
	if objective.item then return name == objective.item end
	return name ~= "" and core.get_item_group(name, objective.group) > 0
end
Q.accepts_item = accepts
-- Seconds until a completed repeatable may be taken again (0 = now).
local function cooldown_left(def, state)
	local ready_at = def.repeatable and state.cooldowns[def.id]
	return ready_at and math.max(0, ready_at - Q.clock()) or 0
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
-- Accept gate: `permitted` plus not active, not done (a repeatable after its
-- cooldown counts as not done).
local function offerable(player, def, state)
	if state.active[def.id] then return false, "This quest is not available." end
	if state.completed[def.id] then
		if not def.repeatable then return false, "This quest is not available." end
		local left = cooldown_left(def, state)
		if left > 0 then
			return false, ("Repeatable again in %s."):format(Q.cooldown_text(left))
		end
	end
	return permitted(player, def, state)
end
-- Item objectives draw from one snapshot, so two objectives never count the
-- same item twice: exact items first, then groups (matching names in sorted
-- order, deterministic). `allocation[index]` (item name -> count) is what
-- objective `index` counts; the turn-in takes exactly that, so the readiness
-- shown and the items taken can never disagree. A travel quest's
-- conversation is complete from the start (ruling 39).
local function progress(player, def, active, snapshot)
	local counts, rows, ready = table.copy(snapshot or holdings(player)), {}, true
	local allocation, names = {}, nil
	local function take(index, name, wanted)
		local amount = math.min(wanted, counts[name] or 0)
		if amount > 0 then
			counts[name] = counts[name] - amount
			allocation[index][name] = (allocation[index][name] or 0) + amount
		end
		return amount
	end
	for pass = 1, 2 do
		for index, objective in ipairs(def.objectives) do
			if objective.type == "item" and (pass == 1) == (objective.item ~= nil) then
				allocation[index] = {}
				if objective.item then
					take(index, objective.item, objective.count)
				else
					if not names then
						names = {}
						for name in pairs(counts) do names[#names + 1] = name end
						table.sort(names)
					end
					local got = 0
					for _, name in ipairs(names) do
						if got >= objective.count then break end
						if accepts(objective, name) then got = got + take(index, name, objective.count - got) end
					end
				end
			end
		end
	end
	for index, objective in ipairs(def.objectives) do
		local count
		if objective.type == "talk" then count = objective.count
		elseif objective.type == "kill" then count = active[index] or 0
		else
			count = 0
			for _, amount in pairs(allocation[index]) do count = count + amount end
		end
		rows[index] = {type = objective.type, item = objective.item, group = objective.group,
			mobs = objective.mobs, npc = objective.npc, count = count,
			required = objective.count, description = objective.description, levels = objective.levels}
		if count < objective.count then ready = false end
	end
	return rows, ready, allocation
end
function Q.status(player, id)
	local def, state = Q.registered_quests[id], load(player)
	if not def then return "unknown" end
	if state.active[id] then
		local _, ready = progress(player, def, state.active[id])
		return ready and "ready" or "active"
	end
	if state.completed[id] and not def.repeatable then return "completed" end
	local allowed, reason = offerable(player, def, state)
	return allowed and "available" or "locked", reason
end
-- One bounded state/holdings snapshot for one NPC viewer; no persistent cache.
function Q.npc_quests(player, npc)
	local state, rows, counts = load(player), {}, nil
	for id in pairs(Q.quests_by_npc[npc] or {}) do
		local def = Q.registered_quests[id]
		local relevant = (not state.completed[id] or def.repeatable ~= nil) and
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
				allowed, reason = offerable(player, def, state)
				status = allowed and "available" or "locked"
			end
			rows[#rows + 1] = {id = id, title = def.title, status = status, reason = reason,
				repeatable = def.repeatable ~= nil}
		end
	end
	table.sort(rows, function(a, b) return a.id < b.id end)
	return rows
end
function Q.accept(player, id)
	local def, state = Q.registered_quests[id], load(player)
	if not def then return false, "This quest is not available." end
	local allowed, reason = offerable(player, def, state)
	if not allowed then return false, reason end
	local count = 0
	for _ in pairs(state.active) do count = count + 1 end
	if count >= 20 then return false, "Your quest log is full (20 quests). Complete or abandon a quest first." end
	-- A travel quest's conversation counts from the start (ruling 39, see
	-- progress): the destination shows its "?" at once; the turn-in still
	-- needs the visit.
	state.active[id] = {}
	if #state.tracked < Q.MAX_TRACKED then state.tracked[#state.tracked + 1] = id end
	save(player, state)
	changed(player)
	return true
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
		if #state.tracked >= Q.MAX_TRACKED then
			return false, ("Track at most %d quests."):format(Q.MAX_TRACKED)
		end
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
			objectives = objectives, ready = ready, npc = def.turnin_npc,
			repeatable = def.repeatable ~= nil, travel = Q.is_travel(def),
			rewards = table.copy(def.rewards), reward_xp = Q.reward_xp(def)}
	end
	return {quests = rows, tracked = state.tracked, hud_enabled = state.hud ~= false}
end
-- Preflight copies every owned slot. Removing requirements and adding rewards
-- to the same copies accounts for space freed by this very hand-in.
local function settlement(player, def, active)
	local inv, rows = player:get_inventory(), {}
	for _, list in ipairs(owned_lists(player)) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			rows[#rows + 1] = {list = list, index = index, expected = ItemStack(stack), replacement = ItemStack(stack)}
		end
	end
	local _, ready, allocation = progress(player, def, active)
	if not ready then return nil, "You no longer have all required items." end
	for _, taken in pairs(allocation) do
		for name, amount in pairs(taken) do
			for _, row in ipairs(rows) do
				local stack = row.replacement
				if amount > 0 and stack:get_name() == name then
					local count = math.min(amount, stack:get_count())
					stack:take_item(count)
					amount = amount - count
				end
			end
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
	local rows, error_message = settlement(player, def, state.active[id])
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
	-- The reward items are in the inventory now (settlement checked they fit):
	-- one message-feed line each (Round 28 ruling 20).
	for _, reward in ipairs(def.rewards.items) do
		local stack = ItemStack(reward)
		grug_core.feed_item(player, stack, stack:get_count())
	end
	state.active[id], state.completed[id] = nil, true
	if def.repeatable then state.cooldowns[id] = Q.clock() + def.repeatable.cooldown end
	untrack(state, id)
	save(player, state)
	-- Persist the one-time claim before reward APIs publish callbacks.
	-- Both reward owners write their ledger before notifying consumers. A
	-- failing money observer must not prevent delivery of the XP reward.
	local money_ok, money_error = pcall(grug_money.add, player, def.rewards.copper)
	local xp_ok, xp_error = pcall(grug_xp.add_xp, player, Q.reward_xp(def), "quest")
	busy[name] = nil
	if not money_ok then error(money_error, 0) end
	if not xp_ok then error(xp_error, 0) end
	changed(player)
	return true
end
-- Does this mob count for a kill objective or quest drop? The entity name is
-- the role; an area limit is matched by the area tag the mob spawned with
-- (`_grug_area` = "<zone>/<kind or camp>", spawn_regions.lua), never by
-- where it died. Leaders carry no area.
local function mob_counts(target, mob, pos)
	if target.area and mob._grug_area ~= target.area then return false end
	if target.zone and grug_zones.id_at(pos.x, pos.z) ~= target.zone then return false end
	for _, name in ipairs(target.mobs) do
		if name == mob.name then return true end
	end
	return false
end
function Q.credit_kill(player, mob, pos)
	local state, dirty = load(player), false
	if grug_factions.same_faction(player, mob.object) then return end
	for id, counters in pairs(state.active) do
		local def = Q.registered_quests[id]
		if permitted(player, def, state) then
			for index, objective in ipairs(def.objectives) do
				if objective.type == "kill" and mob_counts(objective, mob, pos) then
					local before = counters[index] or 0
					counters[index] = math.min(objective.count, before + 1)
					dirty = dirty or counters[index] ~= before
				end
			end
		end
	end
	if dirty then save(player, state); changed(player) end
end
-- Into the player's inventory and bags; what does not fit drops at the feet.
local function give(player, item)
	local inv, rest = player:get_inventory(), ItemStack(item)
	for _, list in ipairs(owned_lists(player)) do
		if rest:is_empty() then break end
		rest = inv:add_item(list, rest)
	end
	if not rest:is_empty() then core.add_item(player:get_pos(), rest) end
	grug_core.feed_item(player, ItemStack(item), 1)
end
-- Quest-only drops (ruling 41): rolled once per eligible participant who has
-- the quest active and still needs the item, straight to that player, so a
-- group never competes for them. `participants` are player names (B2's
-- participant drop hook: the same set kill credit uses).
function Q.roll_quest_drops(mob, participants, pos)
	-- Most kills drop nothing for quests: one set lookup ends them here.
	if not Q.quest_drop_mobs[mob.name] then return end
	for _, name in ipairs(participants) do
		local player = core.get_player_by_name(name)
		if player then
			local state, counts, gained = load(player), nil, false
			for id in pairs(state.active) do
				local def = Q.registered_quests[id]
				if #def.quest_drops > 0 and permitted(player, def, state) then
					for _, drop in ipairs(def.quest_drops) do
						if mob_counts(drop, mob, pos) then
							local needed = 0
							for _, objective in ipairs(def.objectives) do
								if objective.item == drop.item then needed = needed + objective.count end
							end
							counts = counts or holdings(player)
							if (counts[drop.item] or 0) < needed and math.random(drop.chance) == 1 then
								give(player, drop.item)
								counts[drop.item], gained = (counts[drop.item] or 0) + 1, true
							end
						end
					end
				end
			end
			if gained then changed(player) end
		end
	end
end
grug_mobs.register_on_eligible_kill(Q.credit_kill)
grug_mobs.register_participant_drop_hook(Q.roll_quest_drops)
