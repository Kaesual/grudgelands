-- The trade-in (spec §5, §10.4): lane REP fills this file. Materials for
-- reputation at the guild houses' exchange counter and the camp vendors, by
-- the catalogue's rates (grug_guild.exchange_rate). Whole lots only, as the
-- vendor's Sell tab sells lot goods: the rest stays with the player.
--
--   grug_guild.trade_in_rows(player) -> list of rows, catalogue order:
--       {item, count, lot, points, lots, total, rest} for every exchange
--       item the player carries in grug_inventory.consume_lists (counts
--       summed over the lists); `lots` = floor(count / lot), `total` =
--       lots * points, `rest` = count - lots * lot
--   grug_guild.trade_in(player, item) -> points, lifetime, balance | nil, err
--       takes every whole lot of the item (after every check, as the Sell
--       tab's All) and credits grug_guild.add(player, total, "trade_in");
--       err "no_faction", "not_exchanged" (no rate or a pending row),
--       "too_few" (below one lot)

-- Stubs (lane REP).
function grug_guild.trade_in_rows(player)
	return {}
end

function grug_guild.trade_in(player, item)
	return nil, "unavailable"
end
