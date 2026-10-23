-- Reputation (spec §4, §10.3; lane REP): two numbers per character and
-- guild, the lifetime total (it decides the rank) and the spendable balance.
-- Earning adds to both, spending takes from the balance only, so spending
-- never lowers the rank.
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
--
-- Beside the contract (REP's own, for the displays and the achievements):
--   grug_guild.highest_rank(player) -> 0..10   the highest rank with either
--       guild (the achievement counter guild:rank reads it live)
--   grug_guild.summary(player) -> {faction, guild, rank, lifetime, balance,
--       next} | nil without a faction (`guild` the proper name, `next` the
--       lifetime the next rank needs, nil at the last rank)
--   grug_guild.format_points(points) -> "1,234"
--   grug_guild.reputation_formspec(x, y, points) -> formspec   the one place
--       reputation is drawn (the vendor's Trade-in tab, the Character page)
--   /guild_rep <player> <points>   (privilege server) add() with "admin"

local catalog = grug_guild.catalog

grug_guild.LIFETIME_PREFIX = "grug_guild:lifetime_"
grug_guild.BALANCE_PREFIX = "grug_guild:balance_"
-- Both numbers clamp here (the largest set_int).
grug_guild.MAX_POINTS = 2147483647
local MAX = grug_guild.MAX_POINTS

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

-- The factions that have a guild, sorted (pairs order is not reproducible).
local FACTIONS = {}
for faction in pairs(catalog.GUILDS) do FACTIONS[#FACTIONS + 1] = faction end
table.sort(FACTIONS)

-- The character's guild faction: its faction when that faction has a guild,
-- else nil (no character yet, or no faction chosen).
local function faction_of(player)
	if not player or not player.is_player or not player:is_player() then return nil end
	local faction = grug_factions.get_faction(player)
	return catalog.guild(faction) and faction or nil
end

-- A stored number, never below 0 (a hand-edited meta value).
local function read(meta, key)
	local value = meta:get_int(key)
	return value > 0 and value or 0
end

local function valid_amount(points)
	-- math.huge passes the floor test: an integer is finite.
	return type(points) == "number" and points >= 1 and points < math.huge and
		points == math.floor(points)
end

function grug_guild.lifetime(player)
	local faction = faction_of(player)
	if not faction then return 0 end
	return read(player:get_meta(), grug_guild.LIFETIME_PREFIX .. faction)
end

function grug_guild.balance(player)
	local faction = faction_of(player)
	if not faction then return 0 end
	return read(player:get_meta(), grug_guild.BALANCE_PREFIX .. faction)
end

function grug_guild.rank(player)
	return catalog.rank_for(grug_guild.lifetime(player))
end

function grug_guild.highest_rank(player)
	if not player or not player.get_meta then return 0 end
	local meta, best = player:get_meta(), 0
	for _, faction in ipairs(FACTIONS) do
		best = math.max(best, catalog.rank_for(read(meta, grug_guild.LIFETIME_PREFIX .. faction)))
	end
	return best
end

local function changed(player, faction, lifetime, balance)
	for _, fn in ipairs(grug_guild.registered_on_change) do
		fn(player, faction, lifetime, balance)
	end
end

function grug_guild.add(player, points, source)
	if not valid_amount(points) then return nil, "bad_amount" end
	local faction = faction_of(player)
	if not faction then return nil, "no_faction" end
	local meta = player:get_meta()
	local lifetime_key = grug_guild.LIFETIME_PREFIX .. faction
	local balance_key = grug_guild.BALANCE_PREFIX .. faction
	local before = read(meta, lifetime_key)
	local lifetime = math.min(before + points, MAX)
	local balance = math.min(read(meta, balance_key) + points, MAX)
	meta:set_int(lifetime_key, lifetime)
	meta:set_int(balance_key, balance)
	core.log("action", ("[grug_guild] %s +%d reputation (%s) with %s: lifetime %d, balance %d")
		:format(player:get_player_name(), points, tostring(source or "?"), faction, lifetime, balance))
	changed(player, faction, lifetime, balance)
	local old_rank, new_rank = catalog.rank_for(before), catalog.rank_for(lifetime)
	if new_rank > old_rank then
		for _, fn in ipairs(grug_guild.registered_on_rank_change) do
			fn(player, faction, new_rank, old_rank)
		end
	end
	return lifetime, balance
end

function grug_guild.spend(player, points)
	if not valid_amount(points) then return nil, "bad_amount" end
	local faction = faction_of(player)
	if not faction then return nil, "no_faction" end
	local meta = player:get_meta()
	local balance_key = grug_guild.BALANCE_PREFIX .. faction
	local balance = read(meta, balance_key)
	if balance < points then return nil, "insufficient" end
	balance = balance - points
	meta:set_int(balance_key, balance)
	local lifetime = read(meta, grug_guild.LIFETIME_PREFIX .. faction)
	core.log("action", ("[grug_guild] %s spent %d reputation with %s: balance %d")
		:format(player:get_player_name(), points, faction, balance))
	changed(player, faction, lifetime, balance)
	return balance
end

--
-- Display (one place for the words and the number format).
--

function grug_guild.summary(player)
	local faction = faction_of(player)
	if not faction then return nil end
	local meta = player:get_meta()
	local lifetime = read(meta, grug_guild.LIFETIME_PREFIX .. faction)
	local rank = catalog.rank_for(lifetime)
	return {faction = faction, guild = catalog.guild(faction).name, rank = rank,
		lifetime = lifetime, balance = read(meta, grug_guild.BALANCE_PREFIX .. faction),
		next = catalog.threshold(rank + 1)}
end

-- 1234567 -> "1,234,567".
function grug_guild.format_points(points)
	local text = tostring(math.floor(tonumber(points) or 0))
	local sign, digits = text:match("^(%-?)(%d+)$")
	if not digits then return text end
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return sign .. out:gsub("^,", "")
end

-- The reputation icon (guild art drop 02 P1, the pewter token, picked
-- 2026-10-23; lane LIFT): drawn before the number. Without it (nil) the
-- balance is drawn as text, "Reputation 1,234"; no caller changes.
grug_guild.REPUTATION_ICON = "grug_guild_reputation.png"

-- A label centred on `y` (real coordinates), starting at `x`.
function grug_guild.reputation_formspec(x, y, points)
	local number = grug_guild.format_points(points)
	if grug_guild.REPUTATION_ICON then
		return ("image[%.2f,%.2f;0.45,0.45;%s]label[%.2f,%.2f;%s]"):format(x, y - 0.225,
			core.formspec_escape(grug_guild.REPUTATION_ICON), x + 0.55, y,
			core.formspec_escape(number))
	end
	return ("label[%.2f,%.2f;%s]"):format(x, y,
		core.formspec_escape("Reputation " .. number))
end

-- A rank reached is worth a line in the feed (the cloaks at 3, 6 and 10
-- have their own achievement line).
grug_guild.register_on_rank_change(function(player, faction, new_rank)
	grug_core.feed(player, "notice", catalog.UI_NAME .. ": Reputation Rank " .. new_rank ..
		" reached", "grug_guild:rank")
end)

-- The Character page shows rank and balance: re-send it when open.
grug_guild.register_on_change(function(player)
	grug_inventory.refresh_character(player)
end)

--
-- The admin command (tests and the GUI checklist: "the winged cloak at rank
-- 10, admin-set").
--

local REFUSAL = {
	no_faction = "has no faction, so no guild",
	bad_amount = "needs a positive whole number of points",
}

core.register_chatcommand("guild_rep", {
	params = "<player> <points>",
	description = "Add " .. catalog.UI_NAME .. " reputation (lifetime and balance) " ..
		"with an online player's own guild",
	privs = {server = true},
	func = function(name, param)
		local target, amount = (param or ""):match("^%s*(%S+)%s+(%S+)%s*$")
		if not target then
			return false, "Usage: /guild_rep <player> <points>"
		end
		local player = core.get_player_by_name(target)
		if not player then
			return false, target .. " is not online."
		end
		-- Digits only: no inf, nan, 1e999 or fractions reach add().
		local points = amount:match("^%d+$") and tonumber(amount)
		if not points or points > grug_guild.MAX_POINTS then
			return false, "Points must be a whole number from 1 to " ..
				grug_guild.format_points(grug_guild.MAX_POINTS) .. "."
		end
		local lifetime, err = grug_guild.add(player, points, "admin")
		if not lifetime then
			return false, target .. " " .. (REFUSAL[err] or err) .. "."
		end
		core.log("action", ("[grug_guild] %s ran /guild_rep %s %s"):format(name, target, amount))
		local view = grug_guild.summary(player)
		return true, ("%s: %s Rank %d, lifetime %s, balance %s."):format(target, catalog.UI_NAME,
			view.rank, grug_guild.format_points(view.lifetime), grug_guild.format_points(view.balance))
	end,
})
