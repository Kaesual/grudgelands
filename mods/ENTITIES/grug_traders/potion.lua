-- Weak Healing Potion (items_crafting.md §3.6, economy.md §2, item_tiers.md §5).
--
-- The vendor's potion: a fixed 35 HP, half of the Alchemist's Healing Potion
-- I, 8c at the vendor (professions.md §4: the vendor sells the lowest tier of
-- a category, nothing more).

grug_traders.POTION_HEAL_AMOUNT = 35

--
-- SHARED instant-potion cooldown (item_tiers.md §5: "one shared 60-second
-- potion cooldown for every potion"). The alchemy potions and draughts gate on
-- the SAME clock, so they call grug_traders.potion_cooldown_left() and
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

-- Starts the shared cooldown (the full 60 s).
function grug_traders.start_potion_cooldown(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	player:get_meta():set_string(META_POTION_CD,
		tostring(os.time() + grug_traders.POTION_COOLDOWN))
end

--
-- The item. Its buy-back is the vendor rule of prices.lua: 5% of its 8c,
-- rounded up.
--

core.register_craftitem("grug_traders:potion_healing_weak", {
	description = "Weak Healing Potion\nRestores " ..
		grug_traders.POTION_HEAL_AMOUNT .. " HP at once",
	inventory_image = "grug_traders_item_potion_healing_weak.png",
	stack_max = 20,
	-- Group dispatch (AGENTS.md): WP10's potions join this group instead of
	-- being name-listed anywhere.
	groups = {grug_potion = 1, grug_potion_instant = 1},

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
		local amount = grug_traders.POTION_HEAL_AMOUNT
		if grug_core.trinket_instant_potion then
			amount = math.max(1, math.floor(
				grug_core.trinket_instant_potion(user, amount) + 0.5))
		end
		-- The central heal path: clamps to max HP and reports heal threat.
		-- no_crit because its first argument is the healer, so without the flag
		-- the DRINKER's crit chance would double the potion's fixed amount.
		grug_core.heal_player(user, user, amount, {no_crit = true})
		grug_traders.start_potion_cooldown(user)
		grug_sounds.play("potion_drink", user)
		-- ItemStack copy semantics: on_use gets a COPY, so the modified stack
		-- has to be returned for the engine to write it back.
		itemstack:take_item(1)
		return itemstack
	end,
})
