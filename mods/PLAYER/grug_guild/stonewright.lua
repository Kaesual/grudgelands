-- The Stonewright (Round 70, spec §5.3): the guild service that converts
-- stone at the guild house for a copper fee, by the recipes of the catalogue
-- (catalog.STONEWRIGHT). Whole lots only, as the trade-in: the rest stays with
-- the player. The rank unlocks a recipe and spending never lowers it. The
-- window is grug_traders' (a vendor whose definition carries `stonewright =
-- true`); nothing here is saved. The five ornamented stones and the two
-- machines are registered in nodes.lua.
--
--   grug_guild.stonewright_rows(player) -> one row per recipe, catalogue order
--       {recipe, unlocked, lots, short}: `lots` the whole lots the player's
--       goods and money pay for, `short` what is missing for the first lot
--       ("Need 10 Cobblestone"'s input row {item, count} or "money"), nil
--       with lots >= 1; an empty list for a character without a guild
--   grug_guild.stonewright_make(player, id, requested_lots) -> made, fee | nil, err
--       makes the requested whole lots (omitted means All) and returns the
--       outputs made and the copper paid; err "no_faction", "unknown", "rank",
--       "too_few", "money", "full" (no room once the inputs are gone: nothing
--       changed)
--
-- As the trade-in (exchange.lua): a count sums every stack of an item over
-- grug_inventory.consume_lists, whatever its meta. The take is planned on
-- copies of the lists, so the room check sees the inventory as it will be and
-- a refusal changes nothing; a full bag can convert its own stacks.

local catalog = grug_guild.catalog

-- The inventory after `lots` of a recipe: list name -> every stack of the list
-- (copies), for the lists it touches; nil when the goods fall short.
local function plan_take(inv, recipe, lots)
	local after = {}
	for _, input in ipairs(recipe.inputs) do
		local need = input.count * lots
		for _, list in ipairs(grug_inventory.consume_lists(inv)) do
			if need < 1 then break end
			local stacks = after[list] or inv:get_list(list) or {}
			for _, stack in ipairs(stacks) do
				if need < 1 then break end
				if stack:get_name() == input.item then
					need = need - stack:take_item(need):get_count()
					after[list] = stacks
				end
			end
		end
		if need > 0 then return nil end
	end
	return after
end

local function carried(inv, item)
	local count = 0
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if stack:get_name() == item then count = count + stack:get_count() end
		end
	end
	return count
end

-- Whole lots of a recipe: by the goods, by the money, and what stops the
-- first lot.
local function lots_of(inv, money, recipe)
	local lots, short = math.huge, nil
	for _, input in ipairs(recipe.inputs) do
		local possible = math.floor(carried(inv, input.item) / input.count)
		if possible < 1 and not short then short = input end
		lots = math.min(lots, possible)
	end
	local by_money = math.floor(money / recipe.fee)
	if by_money < 1 and not short then short = "money" end
	return math.min(lots, by_money), short
end

-- `count` of an item as stacks of at most its stack size: the engine's
-- add_item puts a whole stack into an empty slot, however large.
local function output_stacks(item, count)
	local stacks = {}
	while count > 0 do
		local stack = ItemStack(item)
		stack:set_count(math.min(count, stack:get_stack_max()))
		stacks[#stacks + 1] = stack
		count = count - stack:get_count()
	end
	return stacks
end

function grug_guild.stonewright_rows(player)
	local inv = player and player.get_inventory and player:get_inventory()
	if not inv or not grug_guild.summary(player) then return {} end
	local rank = grug_guild.rank(player)
	local money = grug_money.get(player)
	local rows = {}
	for index, recipe in ipairs(catalog.STONEWRIGHT) do
		local lots, short = lots_of(inv, money, recipe)
		rows[index] = {recipe = recipe, unlocked = rank >= recipe.rank, lots = lots, short = short}
	end
	return rows
end

function grug_guild.stonewright_make(player, id, requested_lots)
	if not grug_guild.summary(player) then return nil, "no_faction" end
	local recipe = catalog.stonewright_recipe(id)
	if not recipe or not core.registered_items[recipe.output] then return nil, "unknown" end
	if grug_guild.rank(player) < recipe.rank then return nil, "rank" end
	local inv = player:get_inventory()
	local available, short = lots_of(inv, grug_money.get(player), recipe)
	if available < 1 then return nil, short == "money" and "money" or "too_few" end
	local lots = requested_lots
	if lots == nil then lots = available end
	if type(lots) ~= "number" or lots ~= math.floor(lots) or lots < 1 or lots > available then
		return nil, "too_few"
	end
	local after = plan_take(inv, recipe, lots)
	if not after then return nil, "too_few" end
	local count = lots * recipe.output_count
	local stacks = output_stacks(recipe.output, count)
	if not grug_inventory.fits(player, stacks, after) then return nil, "full" end
	local fee = lots * recipe.fee
	-- grug_money.take is atomic: a refusal here has changed nothing.
	if not grug_money.take(player, fee) then return nil, "money" end
	for list, planned in pairs(after) do
		for index, stack in ipairs(planned) do
			if inv:get_stack(list, index):get_count() ~= stack:get_count() then
				inv:set_stack(list, index, stack)
			end
		end
	end
	for _, stack in ipairs(stacks) do
		local rest = grug_inventory.give(player, stack)
		if not rest:is_empty() then
			-- fits() and give() share one cell order, so this never happens; never
			-- drop the goods on the ground, say so loudly instead.
			core.log("error", ("[grug_guild] %s made %s but %d did not fit"):format(
				player:get_player_name(), recipe.output, rest:get_count()))
		end
	end
	core.log("action", ("[grug_guild] %s made %d %s for %dc"):format(
		player:get_player_name(), count, recipe.output, fee))
	return count, fee
end
