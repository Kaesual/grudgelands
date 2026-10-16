-- Crafting jobs (Round 45 lane JB; round45-plan.md §3, §4.3,
-- ui-crafting-rework-plan.md §2.19-2.22, §2.31, §2.36, §4.4; Round 47 lane
-- CR, round47-plan.md ruling 18). Every craft is a timed job of the player's
-- own: one job per player, the whole quantity as one job. The ingredients
-- are consumed at the start, which needs room in the inventory for the
-- whole order once they are taken. Each craft's result goes into the
-- inventory (the give helper) as it finishes; what no longer fits (the
-- inventory filled meanwhile) waits in the overflow slots, which empty
-- themselves into the inventory as soon as there is room. Cancel/Stop
-- refunds the ingredients of the crafts not yet delivered.
--
-- Job state: player meta JOB_KEY, one core.serialize'd table
--   {kind = "recipe", recipe = <registry id>, quantity = <crafts>,
--    consumed = {<itemstring>, ...}, target = <itemstring> | nil,
--    start = <seconds>, finish = <seconds>, no_xp = true | nil,
--    delivered = <crafts delivered> | nil, picks = {<group> = <item>} | nil}
-- `consumed` holds the taken stacks (itemstrings of at most stack_max each)
-- for the refund; `target` is the stack an enchant or an
-- upgrade works on (lane EU: kind "enchant" or "upgrade", `operation` the
-- station operation id, `quantity` the levels; operation_jobs.lua); `no_xp`
-- is set when the job's profession was
-- unlearned while it ran; `delivered` counts the crafts of a recipe job
-- already delivered (each lasts (finish - start) / quantity), `picks` the
-- kinds the player chose (the refund takes in the same order). Times are
-- os.time() seconds with a sub-second part (grug_jobs.now), so jobs survive
-- restarts and logouts. A job stored before Round 47 has no `delivered`: it
-- delivers everything at its end, as it would have.
--
-- Completion: a core.after timer only for an online player with a running
-- job, at the next craft's end; at login and whenever the Crafting tab is
-- built (update_job) the state catches up. The overflow drain is a
-- core.after poll only for players whose overflow holds something. Nothing
-- runs per step.
--
-- API (lane UI, ST and EU):
--   grug_jobs.start_job(player, recipe_id, quantity[, picks]) -> ok, reason, info
--   grug_jobs.cancel_job(player)                     -> ok, reason
--   grug_jobs.job_state(player)                      -> nil | copy of the job
--   grug_jobs.update_job(player, source)             -> true when it completed
--   grug_jobs.ingredient_counts(player)              -> counts (one pass)
--   grug_jobs.ingredient_have(counts, entry)         -> count
--   grug_jobs.picked_ingredients(ingredients, picks) -> the list with the chosen kinds
--   grug_jobs.crafts_from_counts(counts, recipe[, picks]) -> crafts the counts allow
--   grug_jobs.output_fits(player, ingredients, quantity, stacks[, counts])
--                                                    -> whether stacks fit after the take
--   grug_jobs.max_craftable(player, recipe[, counts[, picks]])
--                                                    -> n, by_ingredients, by_space
--   grug_jobs.is_ingredient_stack(stack)             -> the metadata rule
--   grug_jobs.station_nearby(player, station)        -> bool, nearest pos
--   grug_jobs.take_all(player)                       -> moved, left
--   grug_jobs.watch_overflow(player)                 (the drain poll)
--   grug_jobs.register_on_job_start(fn(player, job, station_pos))
--   grug_jobs.register_on_job_end(fn(player, job, outcome, source))
--   grug_jobs.register_job_kind(kind, {finish = fn(player, job) -> stacks, label})
--   grug_jobs.begin_job(player, job[, station_pos]) -> job copy | nil, reason
--     (a job runs),
--   grug_jobs.take_ingredients(player, ingredients, quantity) (the parts
--     start_job uses, for EU's kinds)

local JOB_KEY = "grug_jobs:job"
local OUTPUT = "grug_craft_out"
local OUTPUT_SIZE = 4
local STATION_RADIUS = 4
local HOTBAR = 8

grug_jobs.JOB_KEY = JOB_KEY
grug_jobs.OUTPUT_LIST = OUTPUT
grug_jobs.OUTPUT_SIZE = OUTPUT_SIZE
grug_jobs.STATION_RADIUS = STATION_RADIUS

-- os.time() has whole seconds only, which would end a 1 s job anywhere
-- between 0 and 1 s after its start. The clock is os.time() anchored once per
-- process plus the engine's microsecond counter: exact inside one server run,
-- within a second across a restart.
local clock_base = os.time() - core.get_us_time() / 1000000
function grug_jobs.now()
	return clock_base + core.get_us_time() / 1000000
end

--
-- Job state.
--

local function read_job(player)
	local text = player:get_meta():get_string(JOB_KEY)
	if text == "" then return nil end
	local job = core.deserialize(text)
	if type(job) ~= "table" or type(job.finish) ~= "number" then
		core.log("warning", "[grug_jobs] unreadable job of " ..
			player:get_player_name() .. " dropped")
		player:get_meta():set_string(JOB_KEY, "")
		return nil
	end
	return job
end

local function write_job(player, job)
	player:get_meta():set_string(JOB_KEY, job and core.serialize(job) or "")
end

local function copy_job(job)
	local copy = {}
	for key, value in pairs(job) do copy[key] = value end
	copy.consumed = {}
	for index, item in ipairs(job.consumed or {}) do copy.consumed[index] = item end
	if job.picks then
		copy.picks = {}
		for group, item in pairs(job.picks) do copy.picks[group] = item end
	end
	return copy
end

-- A copy of the running job, or nil; `recipe` is the registry record when the
-- job names one. No side effects: callers that show it run update_job first.
function grug_jobs.job_state(player)
	local job = read_job(player)
	if not job then return nil end
	local copy = copy_job(job)
	copy.recipe_def = job.recipe and grug_jobs.recipe(job.recipe) or nil
	return copy
end

--
-- Ingredients (round45-plan.md §3): only stacks without metadata count, for
-- item and group entries alike; the count (UI's ×N) and the consumption use
-- this one rule, so ×N never promises more than a job can take.
--

function grug_jobs.is_ingredient_stack(stack)
	return not stack:is_empty() and #stack:get_meta():get_keys() == 0
end
local plain = grug_jobs.is_ingredient_stack

-- The slots ingredients are counted and taken from, in order: the bags,
-- main[9..], the hotbar, the inactive hotbar layout last (Round 50 ruling 3).
local function consume_order(inv)
	local slots = {}
	local function add(list, from, to)
		for index = from, to do slots[#slots + 1] = {list = list, index = index} end
	end
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		add(list, 1, inv:get_size(list))
	end
	local size = inv:get_size("main")
	add("main", HOTBAR + 1, size)
	add("main", 1, math.min(HOTBAR, size))
	add(grug_inventory.HOTBAR_STORE, 1, inv:get_size(grug_inventory.HOTBAR_STORE))
	return slots
end

-- One pass over the consume order: {items = {name -> count}, groups = {},
-- order = {{name, count}, ...}, lists = {list -> stacks}}
-- (group totals filled on demand by ingredient_have; `order` the ingredient
-- stacks in the consume order, for the dry-run take of crafts_from_counts;
-- `lists` the copies the pass read, for the room check of output_fits, which
-- never writes them).
function grug_jobs.ingredient_counts(player)
	local inv = player:get_inventory()
	local items, order, lists = {}, {}, {}
	for _, slot in ipairs(consume_order(inv)) do
		lists[slot.list] = lists[slot.list] or inv:get_list(slot.list) or {}
		local stack = lists[slot.list][slot.index]
		if stack and plain(stack) then
			local name = stack:get_name()
			items[name] = (items[name] or 0) + stack:get_count()
			order[#order + 1] = {name, stack:get_count()}
		end
	end
	return {items = items, groups = {}, order = order, lists = lists}
end

function grug_jobs.ingredient_have(counts, entry)
	if entry.item then return counts.items[entry.item] or 0 end
	local total = counts.groups[entry.group]
	if total == nil then
		total = 0
		for name, count in pairs(counts.items) do
			if core.get_item_group(name, entry.group) > 0 then total = total + count end
		end
		counts.groups[entry.group] = total
	end
	return total
end

-- Whether a carried item satisfies two entries of `ingredients` (one item
-- in two groups, or a named item inside a group): only then can the take
-- fall short of the per-entry totals. Two item entries never share a name.
local function overlapping(counts, ingredients)
	for _, entry in ipairs(ingredients) do
		if entry.group then
			for name in pairs(counts.items) do
				if core.get_item_group(name, entry.group) > 0 then
					for _, other in ipairs(ingredients) do
						if other ~= entry and grug_jobs.ingredient_accepts(other, name) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

-- The take of take_ingredients (item entries before group entries, each in
-- the consume order) on a copy of the counted stacks: whether `quantity`
-- crafts fit.
local function dry_take(order, ingredients, quantity)
	local left = {}
	for index, row in ipairs(order) do left[index] = row[2] end
	local ordered = {}
	for _, entry in ipairs(ingredients) do
		if entry.item then ordered[#ordered + 1] = entry end
	end
	for _, entry in ipairs(ingredients) do
		if entry.group then ordered[#ordered + 1] = entry end
	end
	for _, entry in ipairs(ordered) do
		local need = entry.n * quantity
		for index, row in ipairs(order) do
			if need <= 0 then break end
			if left[index] > 0 and grug_jobs.ingredient_accepts(entry, row[1]) then
				local piece = math.min(need, left[index])
				left[index] = left[index] - piece
				need = need - piece
			end
		end
		if need > 0 then return false end
	end
	return true
end

-- The ingredient list with the kinds a player chose (Round 46 lane ID, the
-- crafting box's dropdowns): `picks` maps a group to one of its members, and
-- each group entry of that group becomes an entry of that item. Two entries
-- of one item merge (a group may pick the item another entry names, or two
-- groups the same item), so the per-entry totals and the take stay exact.
-- Without picks (Automatic) the list itself, unchanged.
function grug_jobs.picked_ingredients(ingredients, picks)
	if not picks or next(picks) == nil then return ingredients end
	local list, at = {}, {}
	for _, entry in ipairs(ingredients) do
		local item = entry.item
		if not item and picks[entry.group] and
				grug_jobs.ingredient_accepts(entry, picks[entry.group]) then
			item = picks[entry.group]
		end
		if not item then
			list[#list + 1] = entry
		elseif at[item] then
			list[at[item]].n = list[at[item]].n + entry.n
		else
			list[#list + 1] = {item = item, n = entry.n}
			at[item] = #list
		end
	end
	return list
end

-- The crafts the counted stacks allow: the per-entry totals, and when one
-- item could serve two entries (Round 46: carrot and cassava are both a root
-- and a staple) the largest quantity the take itself succeeds with, so ×N
-- never promises more than a job can take. That search runs over the
-- quantity by halving (the take only gets harder as the quantity grows),
-- from the per-entry total (Round 47: no longer capped above the output
-- area's ceiling, which no longer limits a job). `picks`
-- (picked_ingredients) counts the chosen kinds instead of their groups.
function grug_jobs.crafts_from_counts(counts, recipe, picks)
	local ingredients = grug_jobs.picked_ingredients(recipe.ingredients, picks)
	local crafts
	for _, entry in ipairs(ingredients) do
		local n = math.floor(grug_jobs.ingredient_have(counts, entry) / entry.n)
		if crafts == nil or n < crafts then crafts = n end
	end
	crafts = crafts or 0
	if crafts > 0 and counts.order and overlapping(counts, ingredients) then
		local high = crafts
		if dry_take(counts.order, ingredients, high) then return high end
		local low = 0 -- low always fits, high never does
		while high - low > 1 do
			local middle = math.floor((low + high) / 2)
			if dry_take(counts.order, ingredients, middle) then
				low = middle
			else
				high = middle
			end
		end
		return low
	end
	return crafts
end

-- Stacks of at most stack_max holding `count` items like `stack`. Built by
-- count, never from a counted itemstring: the engine reads every tool
-- itemstring as one item (ItemStack::deSerialize).
local function stacks_of(stack, count, into)
	local most = math.max(1, stack:get_stack_max())
	while count > 0 do
		local piece = ItemStack(stack)
		piece:set_count(math.min(most, count))
		into[#into + 1] = piece
		count = count - piece:get_count()
	end
	return into
end

-- The entries in the order of the take: item entries before group entries
-- (so a group never eats an item another entry names), each kept in its
-- list order. The refund of unfinished crafts walks the same order.
local function take_order(ingredients)
	local ordered = {}
	for _, entry in ipairs(ingredients) do
		if entry.item then ordered[#ordered + 1] = entry end
	end
	for _, entry in ipairs(ingredients) do
		if entry.group then ordered[#ordered + 1] = entry end
	end
	return ordered
end

-- The take of `quantity` times the ingredient list from the consume order,
-- on working copies of the slots: the slots ({list, index, stack, changed})
-- and the taken pieces, or nil when the lists fall short. `given` (the
-- lists of ingredient_counts) stands in for the inventory's lists; it is
-- never written.
local function plan_take(inv, ingredients, quantity, given)
	local slots = consume_order(inv)
	local lists = {}
	for _, slot in ipairs(slots) do
		if not lists[slot.list] then
			lists[slot.list] = given and given[slot.list] or inv:get_list(slot.list) or {}
		end
		slot.stack = ItemStack(lists[slot.list][slot.index] or "")
	end
	local taken = {}
	for _, entry in ipairs(take_order(ingredients)) do
		local need = entry.n * quantity
		for _, slot in ipairs(slots) do
			if need <= 0 then break end
			local stack = slot.stack
			if plain(stack) and grug_jobs.ingredient_accepts(entry, stack:get_name()) then
				local piece = stack:take_item(math.min(need, stack:get_count()))
				need = need - piece:get_count()
				slot.changed = true
				-- Merged into the previous piece while it stays a valid stack.
				local last = taken[#taken]
				local rest = last and last:add_item(piece) or piece
				if not rest:is_empty() then taken[#taken + 1] = rest end
			end
		end
		if need > 0 then return nil end
	end
	return slots, taken
end

-- Takes `quantity` times the ingredient list (take_order) from the consume
-- order. Returns the consumed itemstrings, or nil and nothing changed when
-- the inventory falls short.
function grug_jobs.take_ingredients(player, ingredients, quantity)
	local inv = player:get_inventory()
	local slots, taken = plan_take(inv, ingredients, quantity)
	if not slots then return nil end
	for _, slot in ipairs(slots) do
		if slot.changed then inv:set_stack(slot.list, slot.index, slot.stack) end
	end
	local consumed = {}
	for index, piece in ipairs(taken) do consumed[index] = piece:to_string() end
	return consumed
end

-- A stored stack (an itemstring) as stacks of at most stack_max.
local function split(item, into)
	local stack = ItemStack(item)
	return stacks_of(stack, stack:get_count(), into)
end

--
-- Room (Round 47 ruling 18): a job starts only when everything it makes
-- fits into the inventory once its ingredients are taken. The check takes
-- them on copies and fits the result into those copies in the give
-- helper's order, partial stacks counted (grug_inventory.fits); nothing is
-- written.
--

-- Whether `stacks` fit into the inventory once `quantity` times
-- `ingredients` are taken. `counts` (ingredient_counts) lends the lists
-- its pass read, so a build reads no list twice.
function grug_jobs.output_fits(player, ingredients, quantity, stacks, counts)
	local inv = player:get_inventory()
	local slots = plan_take(inv, ingredients, quantity, counts and counts.lists)
	if not slots then return false end
	local after = {}
	for _, slot in ipairs(slots) do
		after[slot.list] = after[slot.list] or {}
		after[slot.list][slot.index] = slot.stack
	end
	return grug_inventory.fits(player, stacks, after)
end

-- The stacks `quantity` crafts of `recipe` make, before crafted_output.
local function made_by(recipe, quantity)
	return stacks_of(ItemStack(recipe.output), recipe.count * quantity, {})
end

-- The most crafts, up to `most`, whose result fits once their ingredients
-- are taken (0 when none does). A search by halving: fitting gets harder
-- as the quantity grows, apart from a slot that a larger take empties,
-- which the search may miss (the start checks its exact quantity).
local function room_crafts(player, recipe, most, counts, picks)
	if most < 1 then return 0 end
	local ingredients = grug_jobs.picked_ingredients(recipe.ingredients, picks)
	local function fits(quantity)
		return grug_jobs.output_fits(player, ingredients, quantity,
			made_by(recipe, quantity), counts)
	end
	if fits(most) then return most end
	local low, high = 0, most -- high never fits
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if fits(middle) then low = middle else high = middle end
	end
	return low
end

-- The largest quantity a job of `recipe` may start with now, and both
-- limits: the ingredients and the room (the crafts of those whose result
-- fits, never above the ingredient limit). `counts` from ingredient_counts
-- may be passed to share one inventory pass, `picks` the chosen kinds
-- (picked_ingredients).
function grug_jobs.max_craftable(player, recipe, counts, picks)
	counts = counts or grug_jobs.ingredient_counts(player)
	local by_ingredients = grug_jobs.crafts_from_counts(counts, recipe, picks)
	local by_space = room_crafts(player, recipe, by_ingredients, counts, picks)
	return by_space, by_ingredients, by_space
end

--
-- The overflow (Round 47 ruling 18): the four take-only slots of the
-- output list. Finished items go into the inventory; what no longer fits
-- (the inventory filled during the job) waits here and moves into the
-- inventory as soon as there is room: a poll every OVERFLOW_POLL seconds,
-- only while the list holds something. What fits nowhere drops at the
-- player's feet. ui.lua draws the slots only while they hold something.
--

local OVERFLOW_POLL = 1
grug_jobs.OVERFLOW_POLL = OVERFLOW_POLL

function grug_jobs.ensure_output_area(player)
	local inv = player:get_inventory()
	if inv:get_size(OUTPUT) ~= OUTPUT_SIZE then inv:set_size(OUTPUT, OUTPUT_SIZE) end
end

-- The open Crafting page follows a change of what it shows (ui.lua
-- installs it; absent in harnesses without the page).
local function refresh_page(player)
	if grug_jobs.refresh_crafting_page then grug_jobs.refresh_crafting_page(player) end
end

-- Take all: every overflow stack through the give helper; what does not
-- fit stays. Returns whether anything moved and whether anything is left.
function grug_jobs.take_all(player)
	local inv = player:get_inventory()
	local moved, left_any = false, false
	for index = 1, inv:get_size(OUTPUT) do
		local stack = inv:get_stack(OUTPUT, index)
		if not stack:is_empty() then
			local count = stack:get_count()
			local left = grug_inventory.give(player, stack)
			if left:get_count() ~= count then
				moved = true
				inv:set_stack(OUTPUT, index, left)
			end
			if not left:is_empty() then left_any = true end
		end
	end
	return moved, left_any
end

-- The drain: one poll chain per player while the overflow holds something
-- (a token per chain, so a rejoin never runs two). Each poll moves what
-- fits; the chain ends, and the open page drops the slots, when the list
-- is empty (the player may also have taken it out by hand).
local draining = {}
function grug_jobs.watch_overflow(player)
	local name = player:get_player_name()
	if draining[name] or player:get_inventory():is_empty(OUTPUT) then return end
	local token = {}
	draining[name] = token
	local function poll()
		if draining[name] ~= token then return end
		local online = core.get_player_by_name(name)
		if not online then
			draining[name] = nil
			return
		end
		grug_jobs.take_all(online)
		if online:get_inventory():is_empty(OUTPUT) then
			draining[name] = nil
			refresh_page(online)
			return
		end
		core.after(OVERFLOW_POLL, poll)
	end
	core.after(OVERFLOW_POLL, poll)
end

-- Delivers finished stacks: the inventory first, then the overflow, then
-- the player's feet. Returns true when the overflow went from empty to
-- holding something (the page then shows the slots).
local function deliver(player, stacks)
	local inv = player:get_inventory()
	local was_empty = inv:is_empty(OUTPUT)
	local overflowed = false
	for _, stack in ipairs(stacks) do
		local left = grug_inventory.give(player, stack)
		if not left:is_empty() then
			overflowed = true
			left = inv:add_item(OUTPUT, left)
		end
		if not left:is_empty() then
			core.log("warning", "[grug_jobs] output of " .. player:get_player_name() ..
				" did not fit; dropped at the player: " .. left:to_string())
			core.add_item(player:get_pos(), left)
		end
	end
	-- Items arrived without an inventory action: the recipe scan looks soon.
	if grug_jobs.held_dirty then grug_jobs.held_dirty(player) end
	if overflowed then grug_jobs.watch_overflow(player) end
	return was_empty and not inv:is_empty(OUTPUT)
end

-- Take-only: nothing is put or moved into the overflow (a swap runs
-- this check in both directions, so a swap cannot fill it either).
core.register_allow_player_inventory_action(function(_, action, _, info)
	if (action == "move" and info.to_list == OUTPUT) or
			(action == "put" and info.listname == OUTPUT) then
		return 0
	end
end)

--
-- Stations (spec §2.27, §4.7): a recipe's station kind within 4 nodes,
-- checked once at the start. The second result is the nearest such node, the
-- station the job starts at (its sound plays there, station_sounds.lua).
--

local station_names = {}
function grug_jobs.station_nearby(player, station)
	local names = station_names[station]
	if not names then
		names = {}
		for name, def in pairs(core.registered_nodes) do
			if def._grug_station == station then names[#names + 1] = name end
		end
		station_names[station] = names
	end
	if #names == 0 then return false end
	local at = player:get_pos()
	local pos = vector.round(at)
	local found = core.find_nodes_in_area(
		vector.offset(pos, -STATION_RADIUS, -STATION_RADIUS, -STATION_RADIUS),
		vector.offset(pos, STATION_RADIUS, STATION_RADIUS, STATION_RADIUS), names)
	if not found or #found == 0 then return false end
	local nearest, best
	for index = 1, #found do
		local p = found[index]
		local dx, dy, dz = p.x - at.x, p.y - at.y, p.z - at.z
		local d2 = dx * dx + dy * dy + dz * dz
		if not best or d2 < best then nearest, best = p, d2 end
	end
	return true, nearest
end

--
-- Kinds, timer, completion.
--

local start_callbacks, end_callbacks = {}, {}
-- fn(player, job, station_pos) after a job started (begin_job); station_pos
-- is the station the start found nearby, nil for a job without a station.
function grug_jobs.register_on_job_start(fn)
	start_callbacks[#start_callbacks + 1] = fn
end

-- fn(player, job, outcome, source) after a job ended: outcome "completed" or
-- "cancelled"; source "timer", "join", "open" (the Crafting tab is being
-- built), "start" or "stop". UI resends an open Crafting page from here.
function grug_jobs.register_on_job_end(fn)
	end_callbacks[#end_callbacks + 1] = fn
end

local kinds = {}
-- def.finish(player, job) -> the finished stacks, the feed label. EU adds
-- its enchant and upgrade kinds here.
function grug_jobs.register_job_kind(kind, def)
	kinds[kind] = def
end

local function feed_label(name, total)
	local label = grug_core.item_name(name)
	return total > 1 and (label .. " ×" .. total) or label
end

-- The stacks `crafts` crafts of `recipe` make: count items each as stacks
-- of stack_max; gear through grug_items.crafted_output (base name, quality,
-- item level, description, weapon tooltip).
local function recipe_stacks(player, recipe, crafts)
	local stacks = made_by(recipe, crafts)
	local items = rawget(_G, "grug_items")
	if items and type(items.crafted_output) == "function" then
		for _, stack in ipairs(stacks) do items.crafted_output(stack, player) end
	end
	return stacks
end

-- What a job hands back for the crafts it has not delivered. With none
-- delivered: every consumed stack and the target. Else each entry's share
-- of the unfinished crafts: the consumed stacks hold the take's items in
-- its order (take_order of the job's picks), each entry's n x quantity in
-- a row, so walking them entry by entry returns each entry's own kinds. A
-- job whose recipe is gone returns each consumed stack's share, rounded
-- down.
local function unfinished_of(job)
	local stacks = {}
	local delivered = job.delivered or 0
	if delivered <= 0 then
		for _, item in ipairs(job.consumed or {}) do split(item, stacks) end
		if job.target and job.target ~= "" then split(job.target, stacks) end
		return stacks
	end
	local left = job.quantity - delivered
	local pool = {}
	for index, item in ipairs(job.consumed or {}) do pool[index] = ItemStack(item) end
	local recipe = job.recipe and grug_jobs.recipe(job.recipe)
	if not recipe then
		for _, stack in ipairs(pool) do
			stacks_of(stack, math.floor(stack:get_count() * left / job.quantity), stacks)
		end
		return stacks
	end
	-- `at` is the stack the walk stands in, `rest` its items not yet walked.
	local at, rest = 1, pool[1] and pool[1]:get_count() or 0
	local ingredients = grug_jobs.picked_ingredients(recipe.ingredients, job.picks)
	for _, entry in ipairs(take_order(ingredients)) do
		local block, back = entry.n * job.quantity, entry.n * left
		while block > 0 and pool[at] do
			local part = math.min(block, rest)
			local returned = math.min(back, part)
			if returned > 0 then stacks_of(pool[at], returned, stacks) end
			back, block, rest = back - returned, block - part, rest - part
			if rest <= 0 then
				at = at + 1
				rest = pool[at] and pool[at]:get_count() or 0
			end
		end
	end
	return stacks
end

-- A finished recipe job: the crafts not yet delivered (recipe_stacks); the
-- XP, sound and achievements once for the whole job (award_progress). A job
-- whose recipe is gone, and a job of an unknown kind (which falls back to
-- this one), returns what it has not delivered of its ingredients and its
-- target.
grug_jobs.register_job_kind("recipe", {
	finish = function(player, job)
		local recipe = grug_jobs.recipe(job.recipe)
		if not recipe or (job.kind or "recipe") ~= "recipe" then
			return unfinished_of(job), "Returned ingredients"
		end
		local stacks = recipe_stacks(player, recipe, job.quantity - (job.delivered or 0))
		grug_jobs.award_progress(player, recipe, job.quantity, job.no_xp)
		return stacks, feed_label(recipe.output, recipe.count * job.quantity)
	end,
})

local timers = {}

local function finished(job)
	return grug_jobs.now() >= job.finish
end

-- A recipe job of several crafts delivers each as it finishes, the last
-- one with the job's end; anything else, and a job stored before Round 47
-- (no `delivered`), delivers at its end only.
local function per_craft(job)
	return (job.kind or "recipe") == "recipe" and (job.quantity or 1) > 1 and
		job.delivered ~= nil
end
local function craft_seconds(job)
	return (job.finish - job.start) / job.quantity
end

-- When the job next needs the clock: the end of its next craft, or its end.
local function next_end(job)
	if not per_craft(job) then return job.finish end
	return math.min(job.finish, job.start + ((job.delivered or 0) + 1) * craft_seconds(job))
end

local function run_end(player, job, outcome, source)
	for index = 1, #end_callbacks do
		end_callbacks[index](player, job, outcome, source)
	end
end

-- Delivers the crafts finished since the last delivery (not the last one,
-- which complete delivers). The count is stored first: a callback inside
-- the delivery finds the job as it now is. An overflow that appears resends
-- an open page, unless the caller builds or answers one ("open", "start").
local function deliver_due(player, job, source)
	if not per_craft(job) then return end
	local recipe = job.recipe and grug_jobs.recipe(job.recipe)
	if not recipe then return end
	local delivered = job.delivered or 0
	local due = math.min(job.quantity - 1,
		math.floor((grug_jobs.now() - job.start) / craft_seconds(job) + 0.000001))
	if due <= delivered then return end
	job.delivered = due
	write_job(player, job)
	if deliver(player, recipe_stacks(player, recipe, due - delivered)) and
			source ~= "open" and source ~= "start" then
		refresh_page(player)
	end
end

-- The job and its timer go before finish runs: a callback inside it (a
-- Crafting page rebuilt by an XP or achievement hook calls update_job) finds
-- no job, so nothing completes twice.
local function complete(player, job, source)
	timers[player:get_player_name()] = nil
	write_job(player, nil)
	local kind = kinds[job.kind or "recipe"] or kinds.recipe
	local stacks, label = kind.finish(player, job)
	deliver(player, stacks)
	if label then grug_core.feed(player, "notice", label .. " is ready") end
	run_end(player, job, "completed", source)
end

local schedule
-- Completes the running job when its end time has passed, else delivers
-- the crafts finished so far and makes sure the online timer runs. Returns
-- true when it completed the job.
function grug_jobs.update_job(player, source)
	local job = read_job(player)
	if not job then return false end
	if finished(job) then
		complete(player, job, source or "open")
		return true
	end
	deliver_due(player, job, source)
	if not timers[player:get_player_name()] then schedule(player, job) end
	return false
end

schedule = function(player, job)
	local name = player:get_player_name()
	local token = {}
	timers[name] = token
	core.after(math.max(0.05, next_end(job) - grug_jobs.now()), function()
		if timers[name] ~= token then return end
		timers[name] = nil
		local online = core.get_player_by_name(name)
		if online then grug_jobs.update_job(online, "timer") end
	end)
end

-- Stores a job whose inputs are already taken: `job.duration` seconds from
-- now, and runs the start callbacks with `station_pos` (station_nearby's
-- node, not stored). Returns the job copy, or nil and the reason while a job
-- runs (a due one completes first): the caller still holds the inputs it took
-- and gives them back. EU's kinds start through this.
function grug_jobs.begin_job(player, job, station_pos)
	grug_jobs.update_job(player, "start")
	if read_job(player) then return nil, "A crafting job is already running." end
	local now = grug_jobs.now()
	job.kind = job.kind or "recipe"
	job.consumed = job.consumed or {}
	job.start = now
	job.finish = now + job.duration
	job.duration = nil
	write_job(player, job)
	schedule(player, job)
	for index = 1, #start_callbacks do
		start_callbacks[index](player, copy_job(job), station_pos)
	end
	return copy_job(job)
end

local function refused(reason, code, max)
	return false, reason, {code = code, max = max}
end

local NO_ROOM = "Not enough room in inventory"
grug_jobs.NO_ROOM = NO_ROOM

-- Starts a job of `quantity` crafts. Returns true, nil, the job copy; or
-- false, the reason and {code, max}: code "busy", "recipe", "quantity",
-- "profession", "station", "space" or "ingredients"; `max` (space and
-- ingredients) is the quantity that would start, 0 when none. "space":
-- the whole order's result does not fit into the inventory once its
-- ingredients are taken (Round 47 ruling 18). `picks`
-- (picked_ingredients): the count and the take use the chosen kinds; a
-- chosen kind the player no longer carries refuses as "ingredients".
function grug_jobs.start_job(player, recipe_id, quantity, picks)
	-- A job past its end completes first; a running one blocks.
	grug_jobs.update_job(player, "start")
	if read_job(player) then
		return refused("A crafting job is already running.", "busy")
	end
	local recipe = grug_jobs.recipe(recipe_id)
	if not recipe then return refused("Unknown recipe.", "recipe") end
	quantity = tonumber(quantity)
	if not quantity or quantity < 1 or quantity % 1 ~= 0 then
		return refused("Enter a quantity of 1 or more.", "quantity")
	end
	local allowed, reason = grug_jobs.can_craft_recipe(player, recipe)
	if not allowed then return refused(reason, "profession") end
	local station_pos
	if recipe.station then
		local nearby
		nearby, station_pos = grug_jobs.station_nearby(player, recipe.station)
		if not nearby then
			local info = grug_jobs.station_info(recipe.station)
			return refused("Requires: " .. (info and info.display_name or recipe.station) ..
				" nearby", "station")
		end
	end
	local counts = grug_jobs.ingredient_counts(player)
	local by_ingredients = grug_jobs.crafts_from_counts(counts, recipe, picks)
	if by_ingredients < 1 then return refused("Not enough ingredients", "ingredients", 0) end
	local ingredients = grug_jobs.picked_ingredients(recipe.ingredients, picks)
	-- The exact quantity's room (made_by only once the ingredients allow it).
	if quantity > by_ingredients or not grug_jobs.output_fits(player, ingredients, quantity,
			made_by(recipe, quantity), counts) then
		local most = room_crafts(player, recipe, math.min(quantity, by_ingredients), counts,
			picks)
		if quantity > by_ingredients and most == by_ingredients then
			return refused("Not enough ingredients — quantity reduced to " .. most,
				"ingredients", most)
		end
		if most < 1 then return refused(NO_ROOM, "space", 0) end
		return refused(NO_ROOM .. " — quantity reduced to " .. most, "space", most)
	end
	local consumed = grug_jobs.take_ingredients(player, ingredients, quantity)
	if not consumed then
		-- Only when two entries of one recipe accept the same item.
		return refused("Not enough ingredients", "ingredients", 0)
	end
	local kept
	for group, item in pairs(picks or {}) do
		kept = kept or {}
		kept[group] = item
	end
	return true, nil, grug_jobs.begin_job(player, {kind = "recipe", recipe = recipe.id,
		quantity = quantity, consumed = consumed, picks = kept, delivered = 0,
		duration = quantity * recipe.time}, station_pos)
end

-- Cancel/Stop (spec §2.19): after the end time the job completes instead
-- (true, "completed"); otherwise the crafts finished by now are delivered
-- and what it has not delivered is refunded
-- (true, "cancelled") and the crafts it delivered count for XP and
-- achievements (without the craft sound), or nothing happens when the
-- inventory cannot hold the refund (a dry run first).
function grug_jobs.cancel_job(player)
	local job = read_job(player)
	if not job then return false, "No crafting job is running." end
	if finished(job) then
		complete(player, job, "stop")
		return true, "completed"
	end
	-- The crafts finished by now are made (a late timer delivers them here).
	deliver_due(player, job, "stop")
	local refund = unfinished_of(job)
	if not grug_inventory.fits(player, refund) then
		return false, "Not enough inventory space to cancel"
	end
	timers[player:get_player_name()] = nil
	write_job(player, nil)
	for _, stack in ipairs(refund) do
		local left = grug_inventory.give(player, stack)
		if not left:is_empty() then core.add_item(player:get_pos(), left) end
	end
	local recipe = (job.delivered or 0) > 0 and job.recipe and grug_jobs.recipe(job.recipe)
	if recipe then grug_jobs.award_progress(player, recipe, job.delivered, job.no_xp, true) end
	run_end(player, job, "cancelled", "stop")
	return true, "cancelled"
end

-- Unlearning a profession lets its running job finish without XP
-- (state.lua's unlearn calls this); an enchant or upgrade job names its
-- station operation (lane EU).
function grug_jobs.forfeit_job_xp(player, profession)
	local job = read_job(player)
	local recipe = job and (job.recipe and grug_jobs.recipe(job.recipe) or
		job.operation and grug_jobs.station_operation and
		grug_jobs.station_operation(job.operation))
	if recipe and recipe.profession == profession and not job.no_xp then
		job.no_xp = true
		write_job(player, job)
	end
end

-- The output list exists for every player (old ones too) before the job
-- catches up (offline crafts are delivered here, as they would have been
-- online); an overflow left from before starts draining. grug_core's
-- migration runner joins before this.
core.register_on_joinplayer(function(player)
	grug_jobs.ensure_output_area(player)
	grug_jobs.update_job(player, "join")
	grug_jobs.watch_overflow(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	timers[name], draining[name] = nil, nil
end)
