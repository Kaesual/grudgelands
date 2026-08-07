-- Weak Healing Potion (items_crafting.md §3.6 + §8.2).
--
-- "Healing Potion (instant 30% HP — the combat_stats standard; vendor's weak
-- 15% stays the floor)": this is that floor. 15% of max HP, 8c at the vendor,
-- and the ONLY potion of WP7 — the Alchemist's 30% version and everything
-- above it is WP10 (professions.md §4: the vendor sells the lowest tier of a
-- category, nothing more).

grug_traders.POTION_HEAL_FRACTION = 0.15 -- §3.6 "vendor's weak 15%"

--
-- SHARED instant-potion cooldown (§3.6: "One shared 60 s cooldown for instant
-- potions"). It is shared on purpose: WP10's alchemy healing/mana potions must
-- gate on the SAME clock, so they call grug_traders.potion_cooldown_left() and
-- grug_traders.start_potion_cooldown() instead of opening a second timer.
-- (The "one elixir buff at a time" half of §3.6 is a WP10 concern — an elixir
-- is not an instant potion and must not touch this cooldown.)
--
-- Stored as an ABSOLUTE os.time() expiry in PLAYER META, as a STRING:
--   * `PlayerMetaRef:set_int` is a genuine 32-bit signed store
--     (l_metadata.cpp l_set_int -> luaL_checkint), so an absolute unix
--     expiry would wrap in January 2038 and the shared cooldown would
--     silently disappear for good. set_string has no such ceiling.
--   * meta is a string map underneath (set_int writes itos(value), same
--     file), so a value written by the old set_int reads back through
--     get_string unchanged — no migration needed, the key name is the same.
--
-- Why an absolute expiry in meta at all, not a Lua table:
--   * player meta is auto-persisted, so a relog cannot wipe the cooldown —
--     relogging to chain-chug potions is exactly the exploit the shared
--     cooldown exists to prevent;
--   * os.time() is wall clock (whitelisted by the engine sandbox — the
--     security layer keeps os.clock/date/difftime/getenv/time, see
--     docs/research/luanti-lua.md), so the cooldown keeps running while the
--     player is offline and across a server restart. grug_core.mono_time() is
--     deliberately NOT used here: it restarts at every server start, which
--     would hand every player a free potion after a restart.
--
grug_traders.POTION_COOLDOWN = 60 -- seconds

local META_POTION_CD = "grug_traders:potion_cd"

-- Remaining seconds of the shared instant-potion cooldown; 0 = ready.
function grug_traders.potion_cooldown_left(player)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	-- Empty (never set), garbage or NaN all mean "ready".
	local expiry = tonumber(player:get_meta():get_string(META_POTION_CD))
	if not expiry or expiry ~= expiry then
		return 0
	end
	local left = expiry - os.time()
	if left <= 0 then
		return 0
	end
	return left
end

-- Starts the shared cooldown (default: the full 60 s).
function grug_traders.start_potion_cooldown(player, seconds)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	seconds = tonumber(seconds) or grug_traders.POTION_COOLDOWN
	player:get_meta():set_string(META_POTION_CD,
		tostring(os.time() + math.floor(seconds)))
end

--
-- The item.
--
-- _grug_sell_price = 2 is the same 25% buy-back rate grug_gear uses
-- (floor(8 * 0.25) = 2), so buying at 8c and selling back at 2c can never be
-- an income stream.
--

core.register_craftitem("grug_traders:potion_healing_weak", {
	description = "Weak Healing Potion\nRestores 15% of your health",
	inventory_image = "grug_traders_item_potion_healing_weak.png",
	stack_max = 20,
	-- Group dispatch (AGENTS.md): WP10's potions join this group instead of
	-- being name-listed anywhere.
	groups = {grug_potion = 1, grug_potion_instant = 1},
	_grug_sell_price = 2,

	on_use = function(itemstack, user, pointed_thing)
		if not user or not user:is_player() then
			return -- nil: the engine leaves the stack alone
		end
		local name = user:get_player_name()
		-- Never heal a corpse: a dead player is resurrected by respawning,
		-- not by drinking, and grug_core.heal_player refuses hp <= 0 anyway.
		if user:get_hp() <= 0 then
			return
		end
		local left = grug_traders.potion_cooldown_left(user)
		if left > 0 then
			core.chat_send_player(name,
				"You cannot drink another potion for " .. left .. " s.")
			return -- no heal, no consumption
		end
		local max_hp = user:get_properties().hp_max
		if user:get_hp() >= max_hp then
			-- Not in the §3.6 spec, added deliberately: silently burning a
			-- potion (and a 60 s cooldown) on a full health bar is a misclick
			-- tax, not a rule. Reported as a WP7 deviation.
			core.chat_send_player(name, "You are already at full health.")
			return
		end
		local amount = math.max(1,
			math.floor(max_hp * grug_traders.POTION_HEAL_FRACTION + 0.5))
		-- The central heal path: clamps to max HP and reports heal threat.
		-- no_crit because its first argument is the healer, so without the flag
		-- the DRINKER's crit chance would turn §3.6's flat 15% into 22.5%.
		grug_core.heal_player(user, user, amount, {no_crit = true})
		grug_traders.start_potion_cooldown(user)
		-- ItemStack copy semantics: on_use gets a COPY, so the modified stack
		-- has to be returned for the engine to write it back.
		itemstack:take_item(1)
		return itemstack
	end,
})
