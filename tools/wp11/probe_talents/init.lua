-- Disposable engine probe for WP11 lanes X1 + X2 (round 4, lane W1).
--
-- A headless server has no player connected, so everything gated on a
-- watching player -- the HUD, the chat commands' output, the hotbar -- cannot
-- be exercised here and is the user's playtest. What CAN be exercised, and is
-- exactly what this probe does, is the part that is pure server state:
--
--   * the 48 talents really registered inside the engine's own Lua, with the
--     load-time audit running for real rather than under a fixture stub;
--   * spends, gates and a respec driven through the shipped API on a fake
--     player object (a table with the PlayerMetaRef surface the persistence
--     path uses -- get_string/set_string/get_int/set_int);
--   * persistence: write, drop the cache, read back, compare;
--   * the neutral seams: the shipped cooldowns and ranges with no talent;
--   * the chat commands exist and carry no privilege requirement.
--
-- Every line is core.log("action", ...) with a "WP11PROBE" prefix so the run
-- can be grepped out of the server log.

local function say(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring((select(index, ...)))
	end
	core.log("action", "WP11PROBE\t" .. table.concat(parts, "\t"))
end

local failures = 0

local function check(condition, message)
	if not condition then
		failures = failures + 1
		say("FAIL", message)
	end
end

local function equal(got, want, message)
	check(got == want, message .. " -- got " .. tostring(got) ..
		", expected " .. tostring(want))
end

-- A fake player: the meta store plus the handful of accessors the talent
-- model and the two seams read. Deliberately NOT a real PlayerRef -- there is
-- none on a headless server, and inventing one would be the lie.
--
-- The properties/HP four are here because grug_classes.apply_stats now runs on
-- every talent change (it is the only writer of hp_max), so a spend touches
-- them: without them the probe would break at the first spend_talent.
local function fake_player(name, class, level)
	local values = {}
	local meta = {}
	function meta:get_string(key)
		return values[key] or ""
	end
	function meta:set_string(key, value)
		values[key] = value
	end
	function meta:get_int(key)
		return tonumber(values[key]) or 0
	end
	function meta:set_int(key, value)
		values[key] = tostring(value)
	end
	local properties = {hp_max = 20}
	local hp = 20
	local player = {}
	function player:get_player_name()
		return name
	end
	function player:is_player()
		return true
	end
	function player:get_meta()
		return meta
	end
	function player:get_properties()
		local copy = {}
		for key, value in pairs(properties) do
			copy[key] = value
		end
		return copy
	end
	function player:set_properties(fields)
		for key, value in pairs(fields) do
			properties[key] = value
		end
	end
	function player:get_hp()
		return hp
	end
	function player:set_hp(value)
		hp = value
	end
	meta:set_string("grug_classes:class", class)
	meta:set_int("grug_xp:xp", grug_xp.xp_for_level(level))
	return player
end

core.register_on_mods_loaded(function()
	local classes = grug_classes

	-- 1. The registry exists inside the engine, audited for real.
	equal(#classes.talent_ids, 48, "talents registered in the engine")
	equal(#classes.tree_ids, 6, "trees registered in the engine")
	say("registry", #classes.talent_ids, #classes.tree_ids)

	local player = fake_player("wp11probe", "warrior", 60)
	equal(classes.get_class(player), "warrior", "the fake player has a class")
	equal(grug_xp.get_level(player), 60, "the fake player is level 60")
	equal(classes.talent_points_total(player), 30, "points at level 60")

	-- 2. Spending through the shipped API, gates and all.
	for _ = 1, 5 do
		check(classes.spend_talent(player, "ironbound"), "spending Ironbound")
	end
	equal(classes.talent_rank(player, "ironbound"), 5, "Ironbound rank")
	equal(classes.talent_points_available(player), 25, "points left")
	equal(classes.get_talent_bonus(player, "armor_percent_add"), 5,
		"the summed bonus of a maxed tier-1 talent")
	local ok, reason = classes.can_spend_talent(player, "hold_ground")
	equal(ok, false, "a keystone at 5 in-tree points is refused")
	say("gate_refusal", tostring(reason))

	-- 3. Persistence: the string the engine actually stores, re-read.
	local stored = player:get_meta():get_string("grug_classes:talents")
	say("stored", stored)
	equal(stored, "ironbound=5", "the stored talent string")
	classes.invalidate_talents(player)
	equal(classes.talent_rank(player, "ironbound"), 5,
		"the rank survives a cache drop and a re-parse")
	equal(classes.talent_points_spent(player), 5, "spent after the re-parse")

	-- 4. A forged string is defused by the read path.
	player:get_meta():set_string("grug_classes:talents",
		"unknown_id=3,unbroken=9,ironbound=2")
	classes.invalidate_talents(player)
	equal(classes.talent_rank(player, "unknown_id"), 0, "unknown id dropped")
	equal(classes.talent_rank(player, "unbroken"), 0, "ungated capstone dropped")
	equal(classes.talent_rank(player, "ironbound"), 2, "the legal rank survives")
	equal(classes.talent_points_spent(player), 2, "the forged total is 2")

	-- 5. The respec is a full reset.
	local returned = classes.respec(player)
	equal(returned, 2, "the respec returned the spent points")
	equal(classes.talent_points_spent(player), 0, "nothing is spent after it")
	equal(player:get_meta():get_string("grug_classes:talents"), "",
		"the respec empties the stored string")

	-- 5b. A talent change re-applies derived stats, inside the engine. This is
	-- the review finding of 2026-09-16: apply_stats is the only writer of
	-- hp_max, so without the on_talents_changed consumer a spent point raised
	-- get_max_hp and left the character's real ceiling where it was.
	local body = fake_player("wp11hp", "warrior", 60)
	classes.apply_stats(body)
	local ceiling = body:get_properties().hp_max
	equal(ceiling, classes.get_max_hp(body),
		"the applied ceiling starts where the accessor says")
	for _ = 1, 5 do
		classes.spend_talent(body, "ironbound")
	end
	for _ = 1, 4 do
		classes.spend_talent(body, "weathered")
	end
	equal(body:get_properties().hp_max, ceiling + 12,
		"Weathered 4/4 must raise the APPLIED hp_max")
	classes.respec(body)
	equal(body:get_properties().hp_max, ceiling,
		"a respec must take the raised ceiling back")
	say("ceiling", ceiling, ceiling + 12)

	-- 5c. Ruling 20: an admin level drop wipes the talents and returns every
	-- point, free.
	local demoted = fake_player("wp11drop", "warrior", 60)
	for _ = 1, 5 do
		classes.spend_talent(demoted, "ironbound")
	end
	equal(classes.talent_points_spent(demoted), 5, "five spent before the drop")
	demoted:get_meta():set_int("grug_xp:xp", grug_xp.xp_for_level(4))
	classes.on_level_change_talents(demoted, 60, 4)
	equal(classes.talent_points_spent(demoted), 0,
		"an admin level drop wipes every rank")
	equal(classes.talent_points_available(demoted), 2,
		"and returns every point the new level allows")

	-- 6. The central per-player seams, with no talent ranked, inside the
	--    engine's own registry.
	local registered = grug_abilities.registered
	local neutral = fake_player("wp11neutral", "warrior", 60)
	equal(grug_abilities.effective_cooldown(neutral, registered.taunt), 8,
		"Taunt is 8 s without a talent")
	equal(grug_abilities.effective_cooldown(neutral, registered.charge), 10,
		"Charge is 10 s without a talent")
	local caster = fake_player("wp11mage", "mage", 60)
	equal(grug_abilities.effective_cooldown(caster, registered.blink), 15,
		"Blink is 15 s without a talent")
	equal(grug_abilities.get_range(caster, registered.fireball), 20,
		"Fireball reaches 20 m without a talent")
	local healer = fake_player("wp11priest", "priest", 60)
	equal(grug_abilities.effective_cooldown(healer, registered.smite), 2,
		"Smite is 2 s without a talent")
	say("seams", 8, 10, 15, 20, 2)

	-- ... and with talents, through the same seams. The ORDER matters and is
	-- the point: Bellow's tier-3 gate wants 12 points in Bulwark, which one
	-- chain of nine cannot reach, and Grudge's tier-4 gate wants 20.
	for _ = 1, 5 do
		classes.spend_talent(neutral, "ironbound")
	end
	for _ = 1, 4 do
		classes.spend_talent(neutral, "weathered")
	end
	for _ = 1, 5 do
		classes.spend_talent(neutral, "spite")
	end
	for _ = 1, 4 do
		classes.spend_talent(neutral, "affront")
	end
	for _ = 1, 3 do
		classes.spend_talent(neutral, "bellow")
	end
	for _ = 1, 3 do
		classes.spend_talent(neutral, "grudge")
	end
	equal(classes.talent_rank(neutral, "grudge"), 3, "Grudge reached 3/3")
	equal(grug_abilities.effective_cooldown(neutral, registered.taunt), 5,
		"Grudge 3/3 takes Taunt to 5 s")

	-- 7. Ruling 19: Hamstring is gated and no class kit carries it.
	equal(registered.hamstring.talent_gated, true, "Hamstring is talent-gated")
	equal(registered.renew.talent_gated, true, "Renew is still talent-gated")
	local kit_sizes = {}
	for _, class_id in ipairs(classes.class_ids) do
		local count = 0
		for _, def in ipairs(grug_abilities.universal) do
			if not def.talent_gated then
				count = count + 1
			end
		end
		for _, def in ipairs(grug_abilities.by_class[class_id] or {}) do
			if not def.talent_gated then
				count = count + 1
			end
		end
		kit_sizes[#kit_sizes + 1] = class_id .. "=" .. count
		equal(count, 4, "class " .. class_id ..
			" base kit is Strike plus three (ruling 19)")
	end
	say("kits", table.concat(kit_sizes, " "))

	-- 8. Ruling 25: the rage ledger the engine actually carries.
	equal(grug_abilities.RAGE_PER_SWING, 8, "rage per landed swing")
	equal(grug_abilities.RAGE_PER_HIT_TAKEN, 3, "rage per hit taken")
	equal(grug_abilities.RAGE_DECAY_PER_SECOND, 5, "rage decay per second")
	say("rage", grug_abilities.RAGE_PER_SWING,
		grug_abilities.RAGE_PER_HIT_TAKEN,
		grug_abilities.RAGE_DECAY_PER_SECOND)

	-- 9. Ruling 20: /class is gone, /race is not, and the three interim
	--    talent commands are there and player-reachable.
	equal(core.registered_chatcommands["class"], nil,
		"/class must not be registered any more")
	check(core.registered_chatcommands["race"] ~= nil, "/race is still there")
	for _, name in ipairs({"talents", "talent", "respec"}) do
		local def = core.registered_chatcommands[name]
		check(def ~= nil, "/" .. name .. " is registered")
		if def then
			-- builtin normalizes a missing `privs` to an EMPTY TABLE
			-- (builtin/game/chat.lua), so "no privilege" is an empty table
			-- here and nil only in a fixture that skips that step.
			check(next(def.privs or {}) == nil,
				"/" .. name .. " is player-reachable")
		end
	end

	say("RESULT", failures == 0 and "PASS" or "FAIL", failures)
end)
