-- Reputation (spec §10.3): lane REP fills this file. Until then every
-- character reads as rank 0 with nothing to spend.
--
-- Saved per character in player meta, one pair per guild (by faction id,
-- so an admin's /faction leaves both guilds' values in place), integers
-- (set_int, clamped at 2147483647), missing = 0, created on first use:
--   grug_guild:lifetime_<faction>   the lifetime total; it decides the rank
--   grug_guild:balance_<faction>    the spendable balance
-- No position, so nothing map-bound: both survive a map reset like money.
--
--   grug_guild.lifetime(player) -> integer   the own guild's, 0 without a faction
--   grug_guild.balance(player) -> integer
--   grug_guild.rank(player) -> 0..10         catalog.rank_for(lifetime)
--   grug_guild.add(player, points, source) -> lifetime, balance | nil, err
--       points a positive integer, added to both numbers; source a short
--       word for the action log ("trade_in", "admin"); err "no_faction" or
--       "bad_amount". Fires the change callbacks, and the rank callbacks
--       when the rank rose.
--   grug_guild.spend(player, points) -> balance | nil, err
--       refused ("insufficient") when the balance is short; never lowers the
--       lifetime; err also "no_faction" or "bad_amount". Fires the change
--       callbacks.
--   grug_guild.register_on_change(fn(player, faction, lifetime, balance))
--   grug_guild.register_on_rank_change(fn(player, faction, new_rank, old_rank))
--       the achievement series' hook (counter guild:rank, spec §6).

grug_guild.LIFETIME_PREFIX = "grug_guild:lifetime_"
grug_guild.BALANCE_PREFIX = "grug_guild:balance_"

grug_guild.registered_on_change = {}
grug_guild.registered_on_rank_change = {}

function grug_guild.register_on_change(fn)
	assert(type(fn) == "function", "grug_guild.register_on_change: function expected")
	table.insert(grug_guild.registered_on_change, fn)
end

function grug_guild.register_on_rank_change(fn)
	assert(type(fn) == "function", "grug_guild.register_on_rank_change: function expected")
	table.insert(grug_guild.registered_on_rank_change, fn)
end

-- Stubs (lane REP).
function grug_guild.lifetime(player)
	return 0
end

function grug_guild.balance(player)
	return 0
end

function grug_guild.rank(player)
	return 0
end

function grug_guild.add(player, points, source)
	return nil, "unavailable"
end

function grug_guild.spend(player, points)
	return nil, "insufficient"
end
