-- The trade-in (spec §5, §10.4; lane REP): materials for reputation at the
-- guild houses' exchange counter and the camp vendors, by the catalogue's
-- rates (grug_guild.exchange_rate). Whole lots only, as the vendor's Sell
-- tab sells lot goods: the rest stays with the player. The window is
-- grug_traders' (the Trade-in tab of a vendor whose definition carries
-- `guild = true`).
--
--   grug_guild.trade_in_rows(player) -> list of rows, catalogue order:
--       {item, count, lot, points, lots, total, rest} for every exchange
--       item the player carries in grug_inventory.consume_lists (counts
--       summed over the lists); `lots` = floor(count / lot), `total` =
--       lots * points, `rest` = count - lots * lot
--   grug_guild.trade_in(player, item, requested_lots) -> points, lifetime, balance | nil, err
--       takes the requested whole lots (omitted means All, as the Sell
--       tab's All) and credits grug_guild.add(player, total, "trade_in");
--       err "no_faction", "not_exchanged" (no rate or a pending row),
--       "too_few" (below one lot)
--
-- As the Sell tab's lots (grug_traders/trade.lua): a row counts every stack
-- of the item over the lists, whatever its meta (quality, wear), and the
-- take is the engine's remove_item (by name, meta ignored), list by list in
-- the same order, so a count never promises what the take cannot find.

local catalog = grug_guild.catalog

function grug_guild.trade_in_rows(player)
	local inv = player and player.get_inventory and player:get_inventory()
	if not inv then return {} end
	local counts = {}
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			local name = stack:get_name()
			if name ~= "" and catalog.exchange_rate(name) then
				counts[name] = (counts[name] or 0) + stack:get_count()
			end
		end
	end
	local rows = {}
	for _, rate in ipairs(catalog.EXCHANGE) do
		local count = counts[rate.item]
		if count and count > 0 then
			local lots = math.floor(count / rate.lot)
			rows[#rows + 1] = {item = rate.item, count = count, lot = rate.lot,
				points = rate.points, lots = lots, total = lots * rate.points,
				rest = count - lots * rate.lot}
		end
	end
	return rows
end

function grug_guild.trade_in(player, item, requested_lots)
	if not grug_guild.summary(player) then return nil, "no_faction" end
	local rate = catalog.exchange_rate(item)
	if not rate then return nil, "not_exchanged" end
	local row
	for _, entry in ipairs(grug_guild.trade_in_rows(player)) do
		if entry.item == item then
			row = entry
			break
		end
	end
	if not row or row.lots < 1 then return nil, "too_few" end
	-- Omitted means All for existing callers. Explicit quantities are whole
	-- lots; reject malformed or unavailable amounts before removing anything.
	local wanted_lots = requested_lots
	if wanted_lots == nil then wanted_lots = row.lots end
	if type(wanted_lots) ~= "number" or wanted_lots ~= math.floor(wanted_lots) or
			wanted_lots < 1 or wanted_lots > row.lots then return nil, "too_few" end
	-- Every check has passed: take the requested whole lots.
	local inv = player:get_inventory()
	local wanted = wanted_lots * rate.lot
	local removed = 0
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		if removed >= wanted then break end
		local take = ItemStack(item)
		take:set_count(wanted - removed)
		removed = removed + inv:remove_item(list, take):get_count()
	end
	-- removed == wanted: counted and taken over the same lists in this same
	-- call. Should it ever fall short, credit only the whole lots taken and
	-- give the part lot back, so no unit is lost and none counts twice.
	local lots = math.floor(removed / rate.lot)
	local rest = removed - lots * rate.lot
	if rest > 0 then
		local back = ItemStack(item)
		back:set_count(rest)
		grug_inventory.give(player, back)
	end
	if lots < 1 then return nil, "too_few" end
	local points = lots * rate.points
	local lifetime, balance = grug_guild.add(player, points, "trade_in")
	return points, lifetime, balance
end
