-- Disposable engine probe (Round 28 Lane A7). Never shipped:
-- tools/r28_a7_slots/run.sh stages it through tools/luanti_headless.sh.
--
-- After every mod has registered, it checks the class hand-slot rules over
-- the REAL item registry, the ability slots, the arrow and bow definitions,
-- the removed quiver item and recipe, and the melee/ability slot lists for
-- player stand-ins of each class (a headless server has no client).

local P = "[r28_slots_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then core.log("error", P .. "FAIL " .. msg) end
	end
	return ok
end

local function stand_in(class_id)
	local meta = {get_string = function(_, key)
		return key == "grug_classes:class" and class_id or ""
	end}
	return {get_meta = function() return meta end,
		is_player = function() return false end}
end

local function run()
	local I = grug_inventory
	-- 1. Hand acceptance over every registered hand item.
	local seen = {}
	for name, def in pairs(core.registered_items) do
		local groups = def.groups or {}
		if (groups.grug_equip_weapon or 0) > 0 or (groups.grug_equip_offhand or 0) > 0 then
			local stack = ItemStack(name)
			local family = (groups.grug_equip_weapon or 0) > 0 and
				grug_gear.weapon_family(stack) or nil
			local shield = (groups.grug_shield or 0) > 0
			local book = (groups.grug_spellbook or 0) > 0
			local blade = family == "sword" or family == "dagger"
			local expect = {
				scout = {grug_weapon = family == "bow", grug_offhand = blade},
				warrior = {grug_weapon = family == "sword" or family == "dagger" or
					family == "greataxe", grug_offhand = shield},
				mage = {grug_weapon = family == "staff" or family == "wand" or
					family == "dagger", grug_offhand = book},
			}
			expect.priest = expect.mage
			for class_id, lists in pairs(expect) do
				for list, want in pairs(lists) do
					check(I.hand_accepts(class_id, list, stack) == want,
						("%s %s %s: expected %s"):format(class_id, list, name, tostring(want)))
				end
			end
			if family then seen[family] = (seen[family] or 0) + 1 end
			if shield then seen.shield = (seen.shield or 0) + 1 end
			if book then seen.book = (seen.book or 0) + 1 end
			if family == "bow" then
				check(def._grug_hands == 1, name .. " is one-handed")
			end
		end
	end
	for _, key in ipairs({"sword", "dagger", "greataxe", "staff", "wand", "bow",
			"shield", "book"}) do
		check((seen[key] or 0) > 0, "registry has " .. key .. " items")
	end
	log("hand items per kind: sword " .. (seen.sword or 0) .. ", bow " ..
		(seen.bow or 0) .. ", shield " .. (seen.shield or 0) .. ", book " ..
		(seen.book or 0))

	-- 2. Ammunition and the removed quiver item / recipe.
	check(ItemStack("grug_gear:arrow"):get_stack_max() == 100, "arrows stack to 100")
	check(core.registered_items["grug_inventory:quiver"] == nil, "no quiver item")
	local recipes = core.get_all_craft_recipes("grug_gear:arrow") or {}
	for _, recipe in ipairs(recipes) do
		check(ItemStack(recipe.output):get_count() <= 100,
			"arrow craft yields at most one stack: " .. recipe.output)
	end
	for name in pairs(core.registered_items) do
		check(not name:find("quiver", 1, true), "no quiver-named item: " .. name)
	end
	check(I.quiver_capacity() == 500, "quiver holds 500")

	-- 3. Ability slots and the per-class lists behind them.
	local slot_of = function(id)
		local def = core.registered_items["grug_abilities:" .. id]
		return def and def._grug_ability_slot
	end
	check(slot_of("strike") == "melee", "Strike reads the melee slot")
	check(slot_of("opening") == "melee", "Opening reads the melee slot")
	check(slot_of("loose") == "weapon", "Loose reads the Ranged slot")
	check(slot_of("snare_shot") == "weapon", "Snare Shot reads the Ranged slot")
	for _, row in ipairs({{"scout", "grug_offhand", "Ranged", "Melee"},
			{"warrior", "grug_weapon", "Weapon", "Shield"},
			{"mage", "grug_weapon", "Weapon", "Caster offhand"},
			{"priest", "grug_weapon", "Weapon", "Caster offhand"}}) do
		local player = stand_in(row[1])
		check(I.melee_list(player) == row[2], row[1] .. " melee list " .. row[2])
		check(I.hand_list(player, "melee") == row[2], row[1] .. " melee ability list")
		check(I.slot_label(row[1], "grug_weapon") == row[3], row[1] .. " weapon label")
		check(I.slot_label(row[1], "grug_offhand") == row[4], row[1] .. " offhand label")
		check(I.has_quiver(player) == (row[1] == "scout"), row[1] .. " quiver slot")
	end
	check(I.hand_accepts("scout", "grug_weapon", ItemStack(I.STARTER_WEAPON.scout)),
		"Scout starter bow fits Ranged")
	check(I.hand_accepts("scout", "grug_offhand", ItemStack(I.STARTER_OFFHAND.scout)),
		"Scout starter sword fits Melee")

	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
