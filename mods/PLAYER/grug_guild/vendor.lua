-- The camp vendor's reputation page (spec §5.2, §10.7; lane CAMPNPC): the
-- rows and the purchase; the window itself is grug_traders' (the camp
-- vendor's Buy mode, trade.lua). One page, six rows (one per tier, both
-- kinds), a row locked with "Reach Reputation Rank N" until the own guild's
-- rank reaches the row's rank; the rank is checked again at the purchase.
-- Prices in reputation (catalog.CONSUMABLES `price`), paid from the balance
-- through grug_guild.spend, so a purchase never lowers the lifetime or the
-- rank. Nothing new is saved: the balance is store.lua's.
--
--   grug_guild.vendor_rows(player) -> six rows {tier, rank, unlocked, items}
--       `items` the two consumable rows of the tier (catalogue order);
--       `rank` the rank that unlocks them; `unlocked` that rank reached
--   grug_guild.buy(player, item[, count]) -> true | false, err
--       `count` of the item (default 1, at most a stack, Round 84) for count
--       times its price, delivered and paid whole or not at all; err
--       "no_faction", "unknown", "count" (no whole count from 1 to a
--       stack), "rank", "insufficient", "full" (no room: nothing spent)

local catalog = grug_guild.catalog

function grug_guild.vendor_rows(player)
	local rank = grug_guild.rank(player)
	local rows = {}
	for tier = 1, catalog.TIER_COUNT do
		local items = {}
		for _, kind in ipairs(catalog.KINDS) do
			items[#items + 1] = catalog.consumable(kind, tier)
		end
		local needed = items[1].rank
		rows[tier] = {tier = tier, rank = needed, unlocked = rank >= needed, items = items}
	end
	return rows
end

function grug_guild.buy(player, item, count)
	if not player or not player.is_player or not player:is_player() or
			not catalog.guild(grug_factions.get_faction(player)) then
		return false, "no_faction"
	end
	local row = catalog.consumable_by_item(item)
	if not row or not core.registered_items[row.item] then return false, "unknown" end
	local stack = ItemStack(row.item)
	if count == nil then count = 1 end
	if type(count) ~= "number" or count ~= math.floor(count) or count < 1 or
			count > stack:get_stack_max() then
		return false, "count"
	end
	stack:set_count(count)
	local price = count * row.price
	if grug_guild.rank(player) < row.rank then return false, "rank" end
	if grug_guild.balance(player) < price then return false, "insufficient" end
	-- Room first, so a full bag spends nothing; the give below fills the
	-- same cells in this same callback.
	if not grug_inventory.fits(player, {stack}) then return false, "full" end
	local balance, err = grug_guild.spend(player, price)
	if not balance then return false, err end
	local rest = grug_inventory.give(player, stack)
	if not rest:is_empty() then
		-- fits() and give() share one cell order, so this never happens; never
		-- drop the item on the ground, say so loudly instead.
		core.log("error", ("[grug_guild] %s bought %s but %d did not fit"):format(
			player:get_player_name(), row.item, rest:get_count()))
	end
	core.log("action", ("[grug_guild] %s bought %d %s for %d reputation"):format(
		player:get_player_name(), count, row.item, price))
	return true
end
