-- The camp vendor's reputation page (spec §5.2, §10.7): lane CAMPNPC fills
-- this file; the window itself is grug_traders'. One page, six rows (one per
-- tier, both kinds), a row locked with "Reach Reputation Rank N" until the
-- own guild's rank reaches the row's tier; the rank is checked again at the
-- purchase. Prices in reputation (catalog.CONSUMABLES `price`), paid from
-- the balance through grug_guild.spend.
--
--   grug_guild.vendor_rows(player) -> six rows {tier, rank, unlocked, items}
--       `items` the two consumable rows of the tier (catalogue order)
--   grug_guild.buy(player, item) -> true | false, err
--       err "no_faction", "unknown", "rank", "insufficient", "full" (no room:
--       nothing spent)

-- Stubs (lane CAMPNPC): every row locked, as at rank 0.
function grug_guild.vendor_rows(player)
	local rows = {}
	for tier = 1, grug_guild.catalog.TIER_COUNT do
		rows[tier] = {tier = tier, rank = tier, unlocked = false, items = {
			grug_guild.consumable("ore_sense", tier),
			grug_guild.consumable("treasure_hunt", tier)}}
	end
	return rows
end

function grug_guild.buy(player, item)
	return false, "unavailable"
end
