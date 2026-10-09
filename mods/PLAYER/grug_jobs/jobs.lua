-- Crafting jobs (Round 45 lane JB; round45-plan.md §3, §4.3,
-- ui-crafting-rework-plan.md §2.19-2.22, §2.31, §2.36, §4.4). Every craft is
-- a timed job of the player's own: one job per player, the whole quantity as
-- one job. The ingredients are consumed at the start, the finished stacks
-- appear in the player's output area at the end, Cancel/Stop refunds
-- everything (one job: nothing was produced yet).
--
-- Job state: player meta JOB_KEY, one core.serialize'd table
--   {kind = "recipe", recipe = <registry id>, quantity = <crafts>,
--    consumed = {<itemstring>, ...}, target = <itemstring> | nil,
--    start = <seconds>, finish = <seconds>, no_xp = true | nil}
-- `consumed` holds the taken stacks (itemstrings of at most stack_max each)
-- for the refund; `target` is the stack an enchant or an
-- upgrade works on (lane EU); `no_xp` is set when the job's profession was
-- unlearned while it ran. Times are os.time() seconds with a sub-second part
-- (grug_jobs.now), so jobs survive restarts and logouts.
--
-- Completion: a core.after timer only for an online player with a running
-- job; at login and whenever the Crafting tab is built (update_job) the
-- state catches up. Nothing runs per step.
--
-- API (lane UI, ST and EU):
--   grug_jobs.start_job(player, recipe_id, quantity) -> ok, reason, info
--   grug_jobs.cancel_job(player)                     -> ok, reason
--   grug_jobs.job_state(player)                      -> nil | copy of the job
--   grug_jobs.update_job(player, source)             -> true when it completed
--   grug_jobs.ingredient_counts(player)              -> counts (one pass)
--   grug_jobs.ingredient_have(counts, entry)         -> count
--   grug_jobs.crafts_from_counts(counts, recipe)     -> crafts the counts allow
--   grug_jobs.output_capacity(player, recipe)        -> crafts the output area holds
--   grug_jobs.max_craftable(player, recipe[, counts]) -> n, by_ingredients, by_space
--   grug_jobs.is_ingredient_stack(stack)             -> the metadata rule
--   grug_jobs.station_nearby(player, station)        -> bool
--   grug_jobs.take_all(player)                       -> moved, left
--   grug_jobs.register_on_job_end(fn(player, job, outcome, source))
--   grug_jobs.register_job_kind(kind, {finish = fn(player, job) -> stacks, label})
--   grug_jobs.begin_job(player, job), grug_jobs.take_ingredients(player,
--     ingredients, quantity) (the parts start_job uses, for EU's kinds)

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

-- One pass over the hotbar, `main` and the bags: {items = {name -> count},
-- groups = {}} (group totals filled on demand by ingredient_have).
function grug_jobs.ingredient_counts(player)
	local inv = player:get_inventory()
	local items = {}
	for _, list in ipairs(grug_inventory.carried_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if plain(stack) then
				local name = stack:get_name()
				items[name] = (items[name] or 0) + stack:get_count()
			end
		end
	end
	return {items = items, groups = {}}
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

function grug_jobs.crafts_from_counts(counts, recipe)
	local crafts
	for _, entry in ipairs(recipe.ingredients) do
		local n = math.floor(grug_jobs.ingredient_have(counts, entry) / entry.n)
		if crafts == nil or n < crafts then crafts = n end
	end
	return crafts or 0
end

-- The slots ingredients are taken from, in order: the bags, main[9..], the
-- hotbar last.
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
	return slots
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

-- Takes `quantity` times the ingredient list (item entries before group
-- entries, so a group never eats an item another entry names) from the
-- consume order. Returns the consumed itemstrings, or nil and nothing changed
-- when the inventory falls short.
function grug_jobs.take_ingredients(player, ingredients, quantity)
	local inv = player:get_inventory()
	local slots = consume_order(inv)
	local lists = {}
	for _, slot in ipairs(slots) do
		lists[slot.list] = lists[slot.list] or inv:get_list(slot.list) or {}
		slot.stack = lists[slot.list][slot.index] or ItemStack("")
	end
	local ordered = {}
	for _, entry in ipairs(ingredients) do
		if entry.item then ordered[#ordered + 1] = entry end
	end
	for _, entry in ipairs(ingredients) do
		if entry.group then ordered[#ordered + 1] = entry end
	end
	local taken = {}
	for _, entry in ipairs(ordered) do
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
-- The output area: four take-only slots (spec §2.20). A job's start counts
-- the room (partial stacks of the same item and several stacks of
-- stack_max); nothing else puts items here during a job, so the room the
-- start counted is there at the end.
--

function grug_jobs.ensure_output_area(player)
	local inv = player:get_inventory()
	if inv:get_size(OUTPUT) ~= OUTPUT_SIZE then inv:set_size(OUTPUT, OUTPUT_SIZE) end
end

-- How many items of `name` (without metadata) the output area still holds.
local function output_room(inv, name)
	local probe = ItemStack(name)
	local most = probe:get_stack_max()
	local room = 0
	for index = 1, inv:get_size(OUTPUT) do
		local stack = inv:get_stack(OUTPUT, index)
		if stack:is_empty() then
			room = room + most
		elseif stack:get_name() == name and plain(stack) and stack:get_wear() == 0 then
			room = room + math.max(0, most - stack:get_count())
		end
	end
	return room
end

-- How many crafts of `recipe` the output area holds.
function grug_jobs.output_capacity(player, recipe)
	return math.floor(output_room(player:get_inventory(), recipe.output) / recipe.count)
end

-- The largest quantity a job of `recipe` may start with now, and both
-- limits (the ingredients, the output area); `counts` from
-- ingredient_counts may be passed to share one inventory pass.
function grug_jobs.max_craftable(player, recipe, counts)
	local by_ingredients = grug_jobs.crafts_from_counts(
		counts or grug_jobs.ingredient_counts(player), recipe)
	local by_space = grug_jobs.output_capacity(player, recipe)
	return math.min(by_ingredients, by_space), by_ingredients, by_space
end

-- Puts finished stacks into the output area; what does not fit (the start
-- counted the room, so only a later rule change could cause it) goes through
-- the give helper, then to the player's feet.
local function deliver(player, stacks)
	local inv = player:get_inventory()
	for _, stack in ipairs(stacks) do
		local left = inv:add_item(OUTPUT, stack)
		if not left:is_empty() then left = grug_inventory.give(player, left) end
		if not left:is_empty() then
			core.log("warning", "[grug_jobs] output of " .. player:get_player_name() ..
				" did not fit; dropped at the player: " .. left:to_string())
			core.add_item(player:get_pos(), left)
		end
	end
end

-- Take all (spec §2.20): every output stack through the give helper; what
-- does not fit stays. Returns whether anything moved and whether anything
-- is left.
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

-- Take-only: nothing is put or moved into the output area (a swap runs
-- this check in both directions, so a swap cannot fill it either).
core.register_allow_player_inventory_action(function(_, action, _, info)
	if (action == "move" and info.to_list == OUTPUT) or
			(action == "put" and info.listname == OUTPUT) then
		return 0
	end
end)

--
-- Stations (spec §2.27, §4.7): a recipe's station kind within 4 nodes,
-- checked once at the start.
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
	local pos = vector.round(player:get_pos())
	local found = core.find_nodes_in_area(
		vector.offset(pos, -STATION_RADIUS, -STATION_RADIUS, -STATION_RADIUS),
		vector.offset(pos, STATION_RADIUS, STATION_RADIUS, STATION_RADIUS), names)
	return found ~= nil and #found > 0
end

--
-- Kinds, timer, completion.
--

local end_callbacks = {}
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

-- A finished recipe job: quantity × count items as stacks of stack_max;
-- gear through grug_items.crafted_output (base name, quality, item level,
-- description, weapon tooltip); the XP, sound and achievements once for the
-- whole job (award_progress). A job whose recipe is gone returns its
-- ingredients.
grug_jobs.register_job_kind("recipe", {
	finish = function(player, job)
		local recipe = grug_jobs.recipe(job.recipe)
		local stacks = {}
		if not recipe then
			for _, item in ipairs(job.consumed or {}) do split(item, stacks) end
			return stacks, "Returned ingredients"
		end
		local total = recipe.count * job.quantity
		stacks_of(ItemStack(recipe.output), total, stacks)
		local items = rawget(_G, "grug_items")
		if items and type(items.crafted_output) == "function" then
			for _, stack in ipairs(stacks) do items.crafted_output(stack, player) end
		end
		grug_jobs.award_progress(player, recipe, job.quantity, job.no_xp)
		return stacks, feed_label(recipe.output, total)
	end,
})

local timers = {}

local function finished(job)
	return grug_jobs.now() >= job.finish
end

local function run_end(player, job, outcome, source)
	for index = 1, #end_callbacks do
		end_callbacks[index](player, job, outcome, source)
	end
end

local function complete(player, job, source)
	timers[player:get_player_name()] = nil
	local kind = kinds[job.kind or "recipe"] or kinds.recipe
	local stacks, label = kind.finish(player, job)
	write_job(player, nil)
	deliver(player, stacks)
	if label then grug_core.feed(player, "notice", label .. " is ready") end
	run_end(player, job, "completed", source)
end

local schedule
-- Completes the running job when its end time has passed, else makes sure
-- the online timer runs. Returns true when it completed the job.
function grug_jobs.update_job(player, source)
	local job = read_job(player)
	if not job then return false end
	if finished(job) then
		complete(player, job, source or "open")
		return true
	end
	if not timers[player:get_player_name()] then schedule(player, job) end
	return false
end

schedule = function(player, job)
	local name = player:get_player_name()
	local token = {}
	timers[name] = token
	core.after(math.max(0.05, job.finish - grug_jobs.now()), function()
		if timers[name] ~= token then return end
		timers[name] = nil
		local online = core.get_player_by_name(name)
		if online then grug_jobs.update_job(online, "timer") end
	end)
end

-- Stores a job whose inputs are already taken: `job.duration` seconds from
-- now. EU's kinds start through this.
function grug_jobs.begin_job(player, job)
	local now = grug_jobs.now()
	job.kind = job.kind or "recipe"
	job.consumed = job.consumed or {}
	job.start = now
	job.finish = now + job.duration
	job.duration = nil
	write_job(player, job)
	schedule(player, job)
	return copy_job(job)
end

local function refused(reason, code, max)
	return false, reason, {code = code, max = max}
end

-- Starts a job of `quantity` crafts. Returns true, nil, the job copy; or
-- false, the reason and {code, max}: code "busy", "recipe", "quantity",
-- "profession", "station", "space" or "ingredients"; `max` (space and
-- ingredients) is the quantity that would start, 0 when none.
function grug_jobs.start_job(player, recipe_id, quantity)
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
	if recipe.station and not grug_jobs.station_nearby(player, recipe.station) then
		local info = grug_jobs.station_info(recipe.station)
		return refused("Requires: " .. (info and info.display_name or recipe.station) ..
			" nearby", "station")
	end
	local most, by_ingredients, by_space = grug_jobs.max_craftable(player, recipe)
	if by_space < 1 then return refused("No space in the output area", "space", 0) end
	if by_ingredients < 1 then return refused("Not enough ingredients", "ingredients", 0) end
	if quantity > most then
		if by_space < by_ingredients then
			return refused("Not enough space in the output area — quantity reduced to " ..
				most, "space", most)
		end
		return refused("Not enough ingredients — quantity reduced to " .. most,
			"ingredients", most)
	end
	local consumed = grug_jobs.take_ingredients(player, recipe.ingredients, quantity)
	if not consumed then
		-- Only when two entries of one recipe accept the same item.
		return refused("Not enough ingredients", "ingredients", 0)
	end
	return true, nil, grug_jobs.begin_job(player, {kind = "recipe", recipe = recipe.id,
		quantity = quantity, consumed = consumed, duration = quantity * recipe.time})
end

-- The stacks a cancel hands back: every consumed stack and the target.
local function refund_of(job)
	local stacks = {}
	for _, item in ipairs(job.consumed or {}) do split(item, stacks) end
	if job.target and job.target ~= "" then split(job.target, stacks) end
	return stacks
end

-- Cancel/Stop (spec §2.19): after the end time the job completes instead
-- (true, "completed"); otherwise everything is refunded (true, "cancelled"),
-- or nothing happens when the inventory cannot hold it (a dry run first).
function grug_jobs.cancel_job(player)
	local job = read_job(player)
	if not job then return false, "No crafting job is running." end
	if finished(job) then
		complete(player, job, "stop")
		return true, "completed"
	end
	local refund = refund_of(job)
	if not grug_inventory.fits(player, refund) then
		return false, "Not enough inventory space to cancel"
	end
	timers[player:get_player_name()] = nil
	write_job(player, nil)
	for _, stack in ipairs(refund) do
		local left = grug_inventory.give(player, stack)
		if not left:is_empty() then core.add_item(player:get_pos(), left) end
	end
	run_end(player, job, "cancelled", "stop")
	return true, "cancelled"
end

-- Unlearning a profession lets its running job finish without XP
-- (state.lua's unlearn calls this).
function grug_jobs.forfeit_job_xp(player, profession)
	local job = read_job(player)
	local recipe = job and job.recipe and grug_jobs.recipe(job.recipe)
	if recipe and recipe.profession == profession and not job.no_xp then
		job.no_xp = true
		write_job(player, job)
	end
end

-- The output area exists for every player (old ones too) before the job
-- catches up; grug_core's migration runner joins before this.
core.register_on_joinplayer(function(player)
	grug_jobs.ensure_output_area(player)
	grug_jobs.update_job(player, "join")
end)

core.register_on_leaveplayer(function(player)
	timers[player:get_player_name()] = nil
end)
