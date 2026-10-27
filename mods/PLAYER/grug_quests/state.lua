local Q = grug_quests
local KEY = "grug_quests:state"
-- The one tracker cap (Round 24 ruling 23): the HUD tracker, the auto-track on
-- accept and the quest-log notice all read this constant.
Q.MAX_TRACKED = 10
local callbacks, turn_in_callbacks, busy = {}, {}, {}
-- The decoded state per player name, keyed by the raw meta string it came
-- from (Round 30, perf review #1): {raw = string, state = table}. Readers
-- share the cached table, so a table `load` returns is never written to;
-- mutating paths take `editable`'s copy, and `save` caches what it stores.
-- Cleared on leave.
local cache = {}
-- `completed` keeps the completion forever (prerequisites read it; every
-- quest is done once, Round 57 ruling 11). An active entry holds its
-- objective counters by index and, since Round 57, the `variant` and the
-- `giver` it was taken from (an entry without them follows the quest's
-- first variant). Returns the shared read-only state and the raw string.
local function load(player)
	local name, raw = player:get_player_name(), player:get_meta():get_string(KEY)
	local entry = cache[name]
	if not entry or entry.raw ~= raw then
		local state = core.deserialize(raw) or
			{active = {}, completed = {}, tracked = {}, hud = true}
		-- A quest id the game no longer registers is dropped from the active
		-- and tracked quests (the upgrade contract: unknown ids in saved state
		-- never crash); `completed` is only looked up by id (as an old
		-- state's `cooldowns` of the removed repeatables, never read).
		for id in pairs(state.active or {}) do
			if not Q.registered_quests[id] then state.active[id] = nil end
		end
		local tracked = state.tracked or {}
		for i = #tracked, 1, -1 do
			if not Q.registered_quests[tracked[i]] then table.remove(tracked, i) end
		end
		entry = {raw = raw, state = state}
		cache[name] = entry
	end
	return entry.state, raw
end
-- A private copy to change and then `save`.
local function editable(player)
	return table.copy((load(player)))
end
local function save(player, state)
	local raw = core.serialize(state)
	player:get_meta():set_string(KEY, raw)
	cache[player:get_player_name()] = {raw = raw, state = state}
end
-- For fixtures: the cache, to prove that no reader writes into it.
Q._state_cache = cache
-- player name -> {raw, fresh, expires, states, version}: Q.marker_states'
-- memo.
local marker_memo, marker_callbacks = {}, {}
-- The markers may differ: the next marker_states call recomputes, and the
-- consumers that keep their own copy (the minimap) are told. Called on every
-- quest change, and without one when the held objective items change (the
-- tracker HUD's journal_key, hud.lua) or the level does (below).
function Q.markers_changed(player)
	local memo = marker_memo[player:get_player_name()]
	if memo then memo.fresh = false end
	for _, callback in ipairs(marker_callbacks) do callback(player) end
end
function Q.register_on_markers_changed(callback) marker_callbacks[#marker_callbacks + 1] = callback end
local function changed(player)
	-- Holdings may have changed with the state (a quest drop).
	Q.markers_changed(player)
	for _, callback in ipairs(callbacks) do callback(player) end
end
-- A level unlocks quests (the acceptance level) and moves the "soon" marker
-- without a quest change.
grug_xp.register_on_level_change(function(player) Q.markers_changed(player) end)
-- player name -> {raw, quests}: the item objectives of the active quests,
-- per raw state (Q.journal_key).
local item_memo = {}
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	cache[name], marker_memo[name], item_memo[name] = nil, nil, nil
end)
function Q.register_on_change(callback) callbacks[#callbacks + 1] = callback end
-- fn(player, quest_id, def) once per completed turn-in, after the state and
-- the rewards are stored (Round 36: grug_achievements counts quests and
-- quest tags with it).
function Q.register_on_turn_in(callback) turn_in_callbacks[#turn_in_callbacks + 1] = callback end
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
-- Quest items count from the owned lists and the inactive hotbar layout
-- (Round 50 ruling 3); rewards land only in the owned lists (settlement).
local STORE = grug_inventory.HOTBAR_STORE
local function holdings(player)
	local counts, inv = {}, player:get_inventory()
	local lists = owned_lists(player)
	lists[#lists + 1] = STORE
	for _, list in ipairs(lists) do
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
-- The variant of quest `def` an active entry follows (Round 57, ruling 9):
-- the one it was taken in, else the first (an entry saved before variants,
-- a quest accepted without an NPC, or a variant the data no longer has).
function Q.variant_of(def, active)
	return active and active.variant and def.variant_by_key[active.variant] or
		def.variant_by_key[def.variant_order[1]]
end
-- The NPC to return to: the giver the quest was taken from when it is one
-- of the variant's turn-ins (Round 58: a role quest's turn-ins are every
-- foreman of the role, the nearest is where it came from), else the first
-- turn-in of the variant that serves the player (Round 57: a shared quest's
-- turn-ins may serve both factions). `active` is the quest's active entry.
function Q.turnin_for(player, variant, active)
	local giver = active and active.giver
	if giver and variant.turnin_set and variant.turnin_set[giver] then return giver end
	if #variant.turnins <= 1 then return variant.turnins[1] end
	for _, npc in ipairs(variant.turnins) do
		local row = Q.registered_npcs[npc]
		if row and grug_factions.serves(row.faction, player) then return npc end
	end
	return variant.turnins[1]
end
-- `level`, if given, is the player's level read once for a whole pass.
local function permitted(player, def, state, level)
	if (level or grug_xp.get_level(player)) < def.min_level then
		return false, "Requires level " .. def.min_level .. "."
	end
	for _, id in ipairs(def.prerequisites) do
		if not state.completed[id] then return false, "Complete the preceding quest first." end
	end
	return true
end
-- Accept gate: `permitted` plus not active and not done. One completion per
-- player counts everywhere (Round 57 ruling 9: no giver of a shared quest
-- offers it again).
local function offerable(player, def, state, level)
	if state.active[def.id] or state.completed[def.id] then return false, "This quest is not available." end
	return permitted(player, def, state, level)
end
-- Item objectives draw from one snapshot, so two objectives never count the
-- same item twice: exact items first, then groups (matching names in sorted
-- order, deterministic). `allocation[index]` (item name -> count) is what
-- objective `index` counts; the turn-in takes exactly that, so the readiness
-- shown and the items taken can never disagree. A travel quest's
-- conversation is complete from the start (ruling 39).
local function progress(player, def, active, snapshot)
	local objectives = Q.variant_of(def, active).objectives
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
		for index, objective in ipairs(objectives) do
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
	for index, objective in ipairs(objectives) do
		local count
		if objective.type == "talk" then count = objective.count
		elseif objective.type == "kill" or objective.type == "use" then count = active[index] or 0
		else
			count = 0
			for _, amount in pairs(allocation[index]) do count = count + amount end
		end
		rows[index] = {type = objective.type, item = objective.item, group = objective.group,
			mobs = objective.mobs, names = objective.names, npc = objective.npc, count = count,
			required = objective.count, description = objective.description, levels = objective.levels,
			label = objective.label, place_name = objective.place_name}
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
	if state.completed[id] then return "completed" end
	local allowed, reason = offerable(player, def, state)
	return allowed and "available" or "locked", reason
end
-- Whether quest `id` is in the player's log ("active") or turned in
-- ("completed"), else nil: the cached state only, no progress, so other
-- mods may ask it every second (grug_mobs' rift boss, Round 36).
function Q.quest_held(player, id)
	local state = load(player)
	if state.active[id] then return "active" end
	if state.completed[id] then return "completed" end
	return nil
end
-- What quest `def` shows at `npc` for this player: "ready", "active",
-- "available" or "locked" (with the reason), or nil when it is not listed
-- there. `pass` carries one holdings snapshot and one level read through
-- the pass (`pass.counts`, `pass.level`).
-- An active quest is listed only at the turn-ins of the variant it was
-- taken in, an open one at every giver of any variant (Round 57).
local function status_at(player, npc, def, state, pass)
	local id = def.id
	if state.completed[id] then return nil end
	for _, prior in ipairs(def.prerequisites) do
		if not state.completed[prior] then return nil end
	end
	local active = state.active[id]
	if active then
		if not Q.variant_of(def, active).turnin_set[npc] then return nil end
	elseif not def.giver_variant[npc] then
		return nil
	end
	if active then
		pass.counts = pass.counts or holdings(player)
		local _, ready = progress(player, def, active, pass.counts)
		return ready and "ready" or "active"
	end
	pass.level = pass.level or grug_xp.get_level(player)
	local allowed, reason = offerable(player, def, state, pass.level)
	return allowed and "available" or "locked", reason
end
-- Whether the player hands quest `id` in at `npc`: active and `npc` a
-- turn-in of the variant they took (Round 57).
function Q.turns_in_at(player, id, npc)
	local def, active = Q.registered_quests[id], load(player).active[id]
	return def ~= nil and active ~= nil and Q.variant_of(def, active).turnin_set[npc] == true
end
-- The active entry of quest `id` (shared, read-only), or nil.
function Q.active_entry(player, id)
	return load(player).active[id]
end
-- The dialog's order inside a category (Round 65 ruling 5).
local ROW_ORDER = {ready = 1, available = 2, active = 3}
-- One bounded state/holdings snapshot for one NPC viewer: the rows to list
-- (ready, available and active quests; Round 65 ruling 1 lists no locked
-- quest) and the hint level, the lowest acceptance level among the quests
-- here that only the player's level holds back (nil when there is none).
function Q.npc_quests(player, npc)
	local state, rows, pass = load(player), {}, {}
	local hint
	for id in pairs(Q.quests_by_npc[npc] or {}) do
		local def = Q.registered_quests[id]
		local status, reason = status_at(player, npc, def, state, pass)
		if status == "locked" then
			hint = math.min(hint or def.min_level, def.min_level)
		elseif status then
			rows[#rows + 1] = {id = id, title = def.title, status = status, reason = reason,
				story = def.story, level = def.level}
		end
	end
	-- Story quests first (the dialog's "Story" category, Round 57), then
	-- ready, available, in progress; then the quest level, the title, the id.
	table.sort(rows, function(a, b)
		if a.story ~= b.story then return a.story end
		if a.status ~= b.status then return ROW_ORDER[a.status] < ROW_ORDER[b.status] end
		if a.level ~= b.level then return a.level < b.level end
		if a.title ~= b.title then return a.title < b.title end
		return a.id < b.id
	end)
	return rows, hint
end
-- How far above the player's level a giver's next quest may open for the
-- grey "soon" marker (Round 65 ruling 2).
Q.SOON_LEVELS = 2
-- The marker of every quest NPC for this player (Round 30, perf review #1):
-- NPC id -> the most urgent status of its rows in Q.npc_quests (ready, then
-- available, active); without one, "locked" (the grey "!", Round 65 ruling
-- 2) when its next quest opens at most Q.SOON_LEVELS above the player's
-- level (the hint level of Q.npc_quests); else the NPC is absent. A story quest
-- (Round 57 ruling 13) of that status makes it the story marker
-- ("story_ready" ...): the status stays visible on its own, and a ready
-- side quest still wins over an available story quest. One state load, one
-- level read and one holdings snapshot for all NPCs. Memoized per player
-- until something it depends on changes (Round 37, audit PLY-06): the raw
-- state (a quest change) or Q.markers_changed (held objective items, the
-- level). Also returns a version that rises whenever the markers differ
-- from the previous result, for cheap change tests (the Map tab).
-- Read-only: the table is shared until the next change.
local MARKER_PRIORITY = {ready = 1, available = 2, active = 3}
Q.MARKER_STATUSES = {"ready", "available", "active", "locked"}
-- A marker value's status and whether it is a story marker.
function Q.marker_parts(value)
	local status = type(value) == "string" and value:match("^story_(.+)$")
	if status then return status, true end
	return value, false
end
function Q.marker_states(player)
	local name = player:get_player_name()
	local state, raw = load(player)
	local memo = marker_memo[name]
	if memo and memo.fresh and memo.raw == raw then
		return memo.states, memo.version
	end
	local states, pass = {}, {}
	pass.level = grug_xp.get_level(player)
	local soon = pass.level + Q.SOON_LEVELS
	for npc, ids in pairs(Q.quests_by_npc) do
		local best, story, next_level, next_story
		for id in pairs(ids) do
			local def = Q.registered_quests[id]
			local status = status_at(player, npc, def, state, pass)
			if status == "locked" then
				-- The next quest: the lowest acceptance level (the hint's).
				if not next_level or def.min_level < next_level then
					next_level, next_story = def.min_level, def.story
				elseif def.min_level == next_level and def.story then
					next_story = true
				end
			elseif status and (not best or MARKER_PRIORITY[status] < MARKER_PRIORITY[best]) then
				best, story = status, def.story
			elseif status and status == best and def.story then
				story = true
			end
		end
		if not best and next_level and next_level <= soon then best, story = "locked", next_story end
		states[npc] = best and (story and "story_" .. best or best) or nil
	end
	local same = memo ~= nil
	if same then
		for npc, status in pairs(memo.states) do
			if states[npc] ~= status then same = false; break end
		end
		for npc in pairs(states) do
			if memo.states[npc] == nil then same = false; break end
		end
	end
	if not same then
		memo = {states = states, version = (memo and memo.version or 0) + 1}
		marker_memo[name] = memo
	end
	memo.raw, memo.fresh = raw, true
	return memo.states, memo.version
end
-- The quest log holds at most MAX_ACTIVE quests (quests.md).
Q.MAX_ACTIVE = 20
local function active_count(state)
	local count = 0
	for _ in pairs(state.active) do count = count + 1 end
	return count
end
-- Whether the log is full: Q.accept would refuse any quest (a system
-- quest's grant skips it then, grug_mail quest.lua).
function Q.log_full(player)
	return active_count(load(player)) >= Q.MAX_ACTIVE
end
-- `npc`: the giver the quest is taken from (the dialog); its variant is the
-- one the player follows (Round 57). Without one (a system quest, a
-- fixture) the quest's first variant.
function Q.accept(player, id, npc)
	local def, state = Q.registered_quests[id], editable(player)
	if not def then return false, "This quest is not available." end
	local variant = npc and def.giver_variant[npc]
	if npc and not variant then return false, "This quest is not available." end
	local allowed, reason = offerable(player, def, state)
	if not allowed then return false, reason end
	if active_count(state) >= Q.MAX_ACTIVE then
		return false, ("Your quest log is full (%d quests). Complete or abandon a quest first."):format(Q.MAX_ACTIVE)
	end
	-- A travel quest's conversation counts from the start (ruling 39, see
	-- progress): the destination shows its "?" at once; the turn-in still
	-- needs the visit.
	state.active[id] = {variant = variant, giver = npc}
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
	local state = editable(player)
	if not state.active[id] then return false end
	state.active[id] = nil
	untrack(state, id)
	save(player, state)
	changed(player)
	grug_sounds.play("quest_abandon", player)
	return true
end
function Q.set_tracked(player, id, enabled)
	local state = editable(player)
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
	local state = editable(player)
	state.hud = enabled == true
	save(player, state)
	changed(player)
end
-- `counts`, if given, is the holdings snapshot Q.journal_key returned.
function Q.journal(player, counts)
	local state, rows = load(player), {}
	counts = counts or next(state.active) and holdings(player) or {}
	local ids = {}
	for id in pairs(state.active) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def, active = Q.registered_quests[id], state.active[id]
		local variant = Q.variant_of(def, active)
		local objectives, ready = progress(player, def, active, counts)
		rows[#rows + 1] = {id = id, title = def.title, description = Q.quest_text(def, false, active),
			objectives = objectives, ready = ready, npc = Q.turnin_for(player, variant, active),
			variant = variant.key, zone = variant.zone or def.zone, story = def.story,
			travel = Q.is_travel(def), turnin_text = def.turnin_text,
			rewards = table.copy(def.rewards), reward_xp = Q.reward_xp(def)}
	end
	return {quests = rows, tracked = table.copy(state.tracked), hud_enabled = state.hud ~= false}
end
-- The tracker's change test (Round 30, perf review #5): the raw state string
-- and, as one string, the count of every held item that an active item
-- objective accepts, capped at what one quest's objectives can take of it
-- (Round 31 C: items beyond that change no allocation, so over-gathering
-- changes neither the key nor the markers). Equal keys give equal
-- journals. The third value is the holdings snapshot read for it, for
-- Q.journal.
function Q.journal_key(player)
	local state, raw = load(player)
	if not next(state.active) then return raw, "" end
	-- The active quests' item objectives, per raw state. Without any, no
	-- held item can change the journal or a marker (Round 37, audit
	-- PLY-05): no inventory read, and an empty snapshot for Q.journal.
	local memo = item_memo[player:get_player_name()]
	if not memo or memo.raw ~= raw then
		local quests = {}
		for id in pairs(state.active) do
			local objectives = {}
			local def = Q.registered_quests[id]
			for _, objective in ipairs(Q.variant_of(def, state.active[id]).objectives) do
				if objective.type == "item" then objectives[#objectives + 1] = objective end
			end
			if #objectives > 0 then quests[#quests + 1] = objectives end
		end
		memo = {raw = raw, quests = quests}
		item_memo[player:get_player_name()] = memo
	end
	local quests = memo.quests
	if #quests == 0 then return raw, "", {} end
	local counts, names = holdings(player), {}
	for name, count in pairs(counts) do
		if count > 0 then
			-- The most any one quest takes of this item (each quest's
			-- progress allocates from its own copy of the snapshot).
			local needed = 0
			for _, objectives in ipairs(quests) do
				local sum = 0
				for _, objective in ipairs(objectives) do
					if accepts(objective, name) then sum = sum + objective.count end
				end
				if sum > needed then needed = sum end
			end
			if needed > 0 then names[#names + 1] = name .. " " .. math.min(count, needed) end
		end
	end
	table.sort(names)
	return raw, table.concat(names, ","), counts
end
-- The reward stacks of a turn-in: the reward items and the picked choice
-- (Round 57), each made by grug_items.make_stack: equipment at the quest's
-- reward level with its fixed enchants, every stack with the receiver's
-- tooltip as grug_inventory.give initialises one (the turn-in writes its
-- slots itself, so it must not skip that).
local function reward_stacks(player, def, choice)
	local rows = {}
	for _, item in ipairs(def.rewards.items) do rows[#rows + 1] = {item = item} end
	if choice then rows[#rows + 1] = def.rewards.choices[choice] end
	local items_api, out = rawget(_G, "grug_items"), {}
	for index, row in ipairs(rows) do
		local stack
		if items_api and items_api.make_stack then
			stack = assert(items_api.make_stack(row.item, def.level, row.affixes, player))
		else
			-- Fixtures without grug_quality: the plain stack.
			stack = ItemStack(row.item)
		end
		out[index] = stack
	end
	return out
end
Q.reward_stacks = reward_stacks
-- Preflight copies every owned slot, in the give helper's order (main[9..],
-- the bags, the hotbar last), so rewards land where any other item would.
-- Removing requirements and adding rewards to the same copies accounts for
-- space freed by this very hand-in. The inactive hotbar layout's slots come
-- after them: requirements are taken from it last, rewards never land in it.
local function settlement(player, def, active, rewards)
	local inv, rows, hotbar, hidden = player:get_inventory(), {}, {}, {}
	local lists = owned_lists(player)
	lists[#lists + 1] = STORE
	for _, list in ipairs(lists) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			local row = {list = list, index = index, expected = ItemStack(stack), replacement = ItemStack(stack)}
			if list == STORE then
				hidden[#hidden + 1] = row
			elseif list == "main" and index <= 8 then
				hotbar[#hotbar + 1] = row
			else
				rows[#rows + 1] = row
			end
		end
	end
	for _, row in ipairs(hotbar) do rows[#rows + 1] = row end
	local takes = {}
	for _, row in ipairs(rows) do takes[#takes + 1] = row end
	for _, row in ipairs(hidden) do takes[#takes + 1] = row end
	local _, ready, allocation = progress(player, def, active)
	if not ready then return nil, "You no longer have all required items." end
	for _, taken in pairs(allocation) do
		for name, amount in pairs(taken) do
			for _, row in ipairs(takes) do
				local stack = row.replacement
				if amount > 0 and stack:get_name() == name then
					local count = math.min(amount, stack:get_count())
					stack:take_item(count)
					amount = amount - count
				end
			end
		end
	end
	for _, reward in ipairs(rewards) do
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
	return takes
end
-- `choice`: the index of the picked reward of `rewards.choices` (Round 57
-- ruling 15); a quest with a choice refuses without one.
function Q.turn_in(player, id, choice)
	local name, state = player:get_player_name(), editable(player)
	local def = Q.registered_quests[id]
	if busy[name] or not def or not state.active[id] then return false, "This quest is not active." end
	local allowed, reason = permitted(player, def, state)
	if not allowed then return false, reason end
	local _, ready = progress(player, def, state.active[id])
	if not ready then return false, "The objectives are not complete." end
	if #def.rewards.choices > 0 then
		choice = tonumber(choice)
		if not choice or not def.rewards.choices[choice] then return false, "Choose your reward first." end
	else
		choice = nil
	end
	if grug_money.get(player) + def.rewards.copper > grug_money.MAX then return false, "Your coin purse cannot hold the reward." end
	local rewards = reward_stacks(player, def, choice)
	local rows, error_message = settlement(player, def, state.active[id], rewards)
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
	for _, stack in ipairs(rewards) do
		grug_core.feed_item(player, stack, stack:get_count())
	end
	state.active[id], state.completed[id] = nil, true
	untrack(state, id)
	save(player, state)
	-- Persist the one-time claim before reward APIs publish callbacks.
	-- Both reward owners write their ledger before notifying consumers. A
	-- failing money observer must not prevent delivery of the XP reward.
	local money_ok, money_error = pcall(grug_money.add, player, def.rewards.copper)
	local xp_ok, xp_error = pcall(grug_xp.add_xp, player, Q.reward_xp(def), "quest")
	busy[name] = nil
	-- The state is saved: the markers and the tracker follow it even when a
	-- reward observer failed.
	changed(player)
	grug_sounds.play("quest_complete", player)
	-- The turn-in hook, once per turn-in; one failing observer keeps
	-- neither the others nor the reward errors from running.
	local hook_error
	for _, callback in ipairs(turn_in_callbacks) do
		local ok, err = pcall(callback, player, id, def)
		if not ok and not hook_error then hook_error = err end
	end
	if not money_ok then error(money_error, 0) end
	if not xp_ok then error(xp_error, 0) end
	if hook_error then error(hook_error, 0) end
	return true
end
-- Does this mob count for a kill objective or quest drop? Round 38, the
-- quest-name guarantee: a mob counts when the name it shows is one of the
-- target's names (labels.lua Q.target_names, resolved at load from the
-- roles and area), whatever its area, level or spawn place; no mob of
-- another name counts. The name is the mob's description, the text its
-- nametag prints after the tier prefix (grug_mobs names.lua).
local function mob_counts(target, mob)
	return target.name_set[mob.description] == true
end
-- Most kills credit nothing: the shared state is only read, and copied
-- once a counter actually rises. A kill of the player's own faction (its
-- guards) credits nothing; the load checks let only the other faction's
-- quests name a garrison (validate.lua, E-garrison-faction).
function Q.credit_kill(player, mob, pos)
	if grug_factions.same_faction(player, mob.object) then return end
	local state, copy = load(player), nil
	for id, counters in pairs(state.active) do
		local def = Q.registered_quests[id]
		if permitted(player, def, state) then
			for index, objective in ipairs(Q.variant_of(def, counters).objectives) do
				if objective.type == "kill" and mob_counts(objective, mob) then
					local before = counters[index] or 0
					local after = math.min(objective.count, before + 1)
					if after ~= before then
						copy = copy or editable(player)
						copy.active[id][index] = after
					end
				end
			end
		end
	end
	if copy then save(player, copy); changed(player) end
end
-- "Use at a place" (Round 36). A use point is one act at one place: the
-- objective's place, object kind and label, as one key. Every active,
-- permitted quest with an unfinished use objective of that key is credited
-- by one finished hold (use.lua).
function Q.use_key(objective)
	return objective.place .. "|" .. objective.object .. "|" .. objective.label
end
-- player name -> {raw, needs}: the use points the player still needs, per
-- quest state string (use.lua asks every second).
local use_memo = {}
core.register_on_leaveplayer(function(player) use_memo[player:get_player_name()] = nil end)
-- The use points the player still needs, as a list of objectives (shared,
-- read-only), one per key.
function Q.use_needs(player)
	local state, raw = load(player)
	local name = player:get_player_name()
	local memo = use_memo[name]
	if memo and memo.raw == raw then return memo.needs end
	local needs, seen = {}, {}
	for id, counters in pairs(state.active) do
		local def = Q.registered_quests[id]
		if def and permitted(player, def, state) then
			for index, objective in ipairs(Q.variant_of(def, counters).objectives) do
				if objective.type == "use" and (counters[index] or 0) < objective.count then
					local key = Q.use_key(objective)
					if not seen[key] then
						seen[key] = true
						needs[#needs + 1] = objective
					end
				end
			end
		end
	end
	table.sort(needs, function(a, b) return Q.use_key(a) < Q.use_key(b) end)
	use_memo[name] = {raw = raw, needs = needs}
	return needs
end
-- Credits one finished use at `key`; true when a counter rose.
function Q.credit_use(player, key)
	local state, copy = load(player), nil
	for id, counters in pairs(state.active) do
		local def = Q.registered_quests[id]
		if def and permitted(player, def, state) then
			for index, objective in ipairs(Q.variant_of(def, counters).objectives) do
				if objective.type == "use" and Q.use_key(objective) == key and
						(counters[index] or 0) < objective.count then
					copy = copy or editable(player)
					copy.active[id][index] = objective.count
				end
			end
		end
	end
	if copy then save(player, copy); changed(player) end
	return copy ~= nil
end
-- Through the give helper (main[9..], the bags, the hotbar last). A quest
-- item is soulbound (Round 60, grug_mobs items.json kind `quest`), so it is
-- never dropped at the feet, where anyone could take it: the roll waits for
-- room (Q.roll_quest_drops), and the item drops again on a later kill.
local function give(player, item)
	grug_inventory.give(player, item)
	grug_core.feed_item(player, ItemStack(item), 1)
end
-- Quest-only drops (ruling 41): rolled once per eligible participant who has
-- the quest active and still needs the item, straight to that player, so a
-- group never competes for them; no roll while the item would not fit (the
-- feed says so once per kill). `participants` are player names (B2's
-- participant drop hook: the same set kill credit uses).
function Q.roll_quest_drops(mob, participants, pos)
	-- Most kills drop nothing for quests: one set lookup ends them here.
	if not Q.quest_drop_names[mob.description] then return end
	for _, name in ipairs(participants) do
		local player = core.get_player_by_name(name)
		if player then
			local state, counts, gained, full = load(player), nil, false, nil
			for id, active in pairs(state.active) do
				local def = Q.registered_quests[id]
				local variant = Q.variant_of(def, active)
				if #variant.quest_drops > 0 and permitted(player, def, state) then
					for _, drop in ipairs(variant.quest_drops) do
						if mob_counts(drop, mob) then
							local needed = 0
							for _, objective in ipairs(variant.objectives) do
								if objective.item == drop.item then needed = needed + objective.count end
							end
							counts = counts or holdings(player)
							if (counts[drop.item] or 0) < needed then
								if not grug_inventory.fits(player, drop.item) then
									full = full or drop.item
								elseif math.random(drop.chance) == 1 then
									give(player, drop.item)
									counts[drop.item], gained = (counts[drop.item] or 0) + 1, true
								end
							end
						end
					end
				end
			end
			if gained then changed(player) end
			if full then
				local def = core.registered_items[full]
				grug_core.feed(player, "notice", "No room for " .. (def and def.short_description or full) ..
					"; it can drop on a later kill.")
			end
		end
	end
end
grug_mobs.register_on_eligible_kill(Q.credit_kill)
grug_mobs.register_participant_drop_hook(Q.roll_quest_drops)
