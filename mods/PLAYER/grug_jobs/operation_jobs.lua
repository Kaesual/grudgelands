-- Enchants and upgrades as crafting jobs (Round 45 lane EU; round45-plan.md
-- §4.6; ui-crafting-rework-plan.md §2.24, §2.26, §2.30-2.32, §4.6). The
-- player places the item in the target slot `grug_craft_target` (one slot,
-- created for every player at join; only equipment goes in). A job's start
-- takes the item in with the materials (jobs.lua's take_ingredients), so
-- while the job runs the item lives only in the job's `target`; the result
-- appears in the output area; a cancel returns the exact item and the
-- materials (jobs.lua's refund).
--   enchant  one station operation (station_operations.lua), 5 s; profession
--            XP like any counting craft: one per job, capped by the tier
--            (spec §2.22, §2.31);
--   upgrade  +N item levels up to 10 x the item's material tier, 1 s per
--            level, per level the operation's ingredients (one own material
--            of the item's tier) and for a weapon its weapon extra (a
--            Stick); no XP.
-- The item's rules (family, tier, channels, the cap) are grug_quality's
-- operation_plan, judged again at the start on the item as it is then.
--
-- API (the boxes, operation_box.lua):
--   grug_jobs.TARGET_LIST
--   grug_jobs.operation_target(stack)        -> whether the slot takes it
--   grug_jobs.start_operation(player, op_id, levels) -> ok, reason, info
--     ({code, max}: "busy", "recipe", "quantity", "profession", "station",
--      "cap", "target", "space", "ingredients"; `max` the levels that would
--      start for "cap" and "ingredients")

local TARGET = "grug_craft_target"
grug_jobs.TARGET_LIST = TARGET
-- Seconds of one enchant and of one upgrade level (spec §2.30).
local SECONDS = {enchant = 5, upgrade = 1}
grug_jobs.OPERATION_SECONDS = SECONDS

-- Equipment of an enchant or upgrade family (tools, plain blocks and
-- stacks of several never go in).
function grug_jobs.operation_target(stack)
	if not stack or stack:is_empty() or stack:get_count() ~= 1 then return false end
	local family = grug_items.family_for(stack)
	return family ~= nil and family ~= "tool"
end

-- An item left in the slot goes back into the inventory (the user,
-- 2026-10-09): the slot is drawn only in the enchant and upgrade boxes, so a
-- forgotten item would stay out of sight. Through the give helper, then the
-- output area; what fits nowhere stays in the slot (never dropped, never
-- lost). At join and when a profession is unlearned (state.lua).
function grug_jobs.return_operation_target(player)
	local inv = player:get_inventory()
	if inv:get_size(TARGET) < 1 then return end
	local stack = inv:get_stack(TARGET, 1)
	if stack:is_empty() then return end
	local left = grug_inventory.give(player, stack)
	if not left:is_empty() and inv:get_size(grug_jobs.OUTPUT_LIST) > 0 then
		left = inv:add_item(grug_jobs.OUTPUT_LIST, left)
	end
	inv:set_stack(TARGET, 1, left)
	if not left:is_empty() then
		core.log("action", "[grug_jobs] " .. player:get_player_name() ..
			"'s target item stays in its slot: no room")
	end
end

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	if inv:get_size(TARGET) ~= 1 then inv:set_size(TARGET, 1) end
	grug_jobs.ensure_output_area(player)
	grug_jobs.return_operation_target(player)
end)

-- One item, and only equipment, goes into the slot (a swap runs this check
-- in both directions). An accepted item returns nothing: the engine stops at
-- the first number (OR with short-circuit), so a later callback still judges
-- the list the item leaves.
core.register_allow_player_inventory_action(function(_, action, inventory, info)
	local stack
	if action == "move" and info.to_list == TARGET then
		stack = inventory:get_stack(info.from_list, info.from_index)
	elseif action == "put" and info.listname == TARGET then
		stack = info.stack
	else
		return nil
	end
	if not grug_jobs.operation_target(stack) then return 0 end
end)

-- Placing or taking the item changes the box (the list of valid enchants,
-- the preview, the levels): the open Crafting page is resent once.
core.register_on_player_inventory_action(function(player, action, _, info)
	local touched
	if action == "move" then
		touched = info.from_list == TARGET or info.to_list == TARGET
	else
		touched = info.listname == TARGET
	end
	if not touched then return end
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == "sfinv:crafting" then
		sfinv.set_player_inventory_formspec(player, context)
	end
end)

local function refused(reason, code, max)
	return false, reason, {code = code, max = max}
end

local function output_has_room(inv)
	for index = 1, inv:get_size(grug_jobs.OUTPUT_LIST) do
		if inv:get_stack(grug_jobs.OUTPUT_LIST, index):is_empty() then return true end
	end
	return false
end

-- Hands back what a refused begin took: the item into its slot, the
-- materials through the give helper (then the feet).
local function give_back(player, target, consumed)
	player:get_inventory():set_stack(TARGET, 1, target)
	for _, item in ipairs(consumed) do
		local left = grug_inventory.give(player, ItemStack(item))
		if not left:is_empty() then core.add_item(player:get_pos(), left) end
	end
end

-- Starts an enchant (`levels` ignored) or an upgrade of `levels` item levels
-- on the item in the target slot. Returns true, nil, the job copy; or false,
-- the reason and {code, max}.
function grug_jobs.start_operation(player, op_id, levels)
	grug_jobs.update_job(player, "start")
	if grug_jobs.job_state(player) then
		return refused("A crafting job is already running.", "busy")
	end
	local op = grug_jobs.station_operation(op_id)
	if not op then return refused("Unknown operation.", "recipe") end
	local quantity = 1
	if op.operation == "upgrade" then
		quantity = tonumber(levels)
		if not quantity or quantity < 1 or quantity % 1 ~= 0 then
			return refused("Enter a number of levels of 1 or more.", "quantity")
		end
	end
	local allowed, why = grug_jobs.can_craft_recipe(player, op)
	if not allowed then return refused(why, "profession") end
	local station_pos
	if op.station then
		local nearby
		nearby, station_pos = grug_jobs.station_nearby(player, op.station)
		if not nearby then
			local info = grug_jobs.station_info(op.station)
			return refused("Requires: " .. (info and info.display_name or op.station) ..
				" nearby", "station")
		end
	end
	local inv = player:get_inventory()
	-- The item as it is now: whatever changed since the page was drawn is
	-- judged here.
	local target = inv:get_stack(TARGET, 1)
	if op.operation == "upgrade" then
		local ilvl, cap = grug_items.upgrade_span(target)
		if ilvl and ilvl < cap and quantity > cap - ilvl then
			return refused("The cap is item level " .. cap .. " — levels reduced to " ..
				(cap - ilvl), "cap", cap - ilvl)
		end
	end
	local plan, reason = grug_items.operation_result(op, target, player, quantity)
	if not plan then return refused(reason, "target") end
	if not output_has_room(inv) then return refused("No space in the output area", "space", 0) end
	local ingredients = grug_jobs.operation_ingredients(op, target)
	local have = grug_jobs.crafts_from_counts(grug_jobs.ingredient_counts(player),
		{ingredients = ingredients})
	if have < 1 then return refused("Not enough ingredients", "ingredients", 0) end
	if quantity > have then
		return refused("Not enough ingredients — levels reduced to " .. have,
			"ingredients", have)
	end
	local consumed = grug_jobs.take_ingredients(player, ingredients, quantity)
	if not consumed then return refused("Not enough ingredients", "ingredients", 0) end
	inv:set_stack(TARGET, 1, ItemStack(""))
	local job, busy = grug_jobs.begin_job(player, {kind = op.operation, operation = op.id,
		quantity = quantity, consumed = consumed, target = target:to_string(),
		duration = quantity * SECONDS[op.operation]}, station_pos)
	if not job then
		give_back(player, target, consumed)
		return refused(busy, "busy")
	end
	return true, nil, job
end

-- The display name of a stack without its colour codes.
local function plain_name(stack)
	local text = stack:get_meta():get_string("description")
	if text == "" then return grug_core.item_name(stack:get_name()) end
	return core.strip_colors(text:match("^[^\n]*"))
end

-- A finished enchant or upgrade: the result of the operation on the stored
-- item, without the profession gate (an unlearned profession finishes its
-- job, without XP: no_xp); the sound and, for an enchant, the XP through
-- award_progress. An operation that is gone or refuses the item now returns
-- the item unchanged and the materials.
local function finish(player, job)
	local op = grug_jobs.station_operation(job.operation or "")
	local target = ItemStack(job.target or "")
	local plan = op and grug_items.operation_result(op, target, player, job.quantity)
	if not plan then
		core.log("warning", "[grug_jobs] " .. tostring(job.kind) .. " job " ..
			tostring(job.operation) .. " of " .. player:get_player_name() ..
			" could not finish; its item and materials are returned")
		local stacks = {}
		if not target:is_empty() then stacks[1] = target end
		for _, item in ipairs(job.consumed or {}) do stacks[#stacks + 1] = ItemStack(item) end
		return stacks, "Returned ingredients"
	end
	grug_jobs.award_progress(player, op, op.operation == "enchant" and 1 or job.quantity,
		job.no_xp)
	return {plan.output}, plain_name(plan.output)
end
grug_jobs.register_job_kind("enchant", {finish = finish})
grug_jobs.register_job_kind("upgrade", {finish = finish})

-- The output area's indicator and label (ui.lua): "Enchanting…" and
-- "Upgrading…" (the user, 2026-10-09), "Steel Sword +3 levels".
grug_jobs.JOB_RUN_LABELS.enchant = "Enchanting…"
grug_jobs.JOB_RUN_LABELS.upgrade = "Upgrading…"
local function target_name(job)
	local stack = ItemStack(job.target or "")
	if stack:is_empty() then return "" end
	local base = stack:get_meta():get_string("grug_base_name")
	return base ~= "" and base or grug_core.item_name(stack:get_name())
end
grug_jobs.JOB_TEXTS.enchant = target_name
grug_jobs.JOB_TEXTS.upgrade = function(job)
	local levels = job.quantity or 1
	return target_name(job) .. " +" .. levels .. (levels == 1 and " level" or " levels")
end
