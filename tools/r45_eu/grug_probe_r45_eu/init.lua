-- Disposable Round 45 EU probe (never shipped), staged by the smoke boot
-- (tools/luanti_headless.sh with PROBE=tools/r45_eu/grug_probe_r45_eu). One
-- step after the load it checks, with the real registrations, items and
-- engine ItemStacks, for a stand-in player on a detached inventory (the
-- forge check and the character level are the probe's: no map is loaded):
--   data    588 enchants, 36 upgrades, progress only for enchants, every
--           upgrade level's own material registered and of its tier, the
--           Stick registered;
--   target  an engine itemstring of an enchanted sword comes back with the
--           same metadata (the job stores its target as one);
--   enchant a job: the item leaves the slot, ends after 5 s with the result
--           the preview showed, one XP;
--   upgrade +3 on a steel sword: 3 s, item level 24, three bars and three
--           sticks, no XP;
--   bytes   the Crafting page with the enchant box (a T3 sword, a chosen
--           enchant) and with the upgrade box (comparisons, never targets).
-- Ends with "PROBE PASS" or "PROBE FAIL <n>".
local P = "[r45eu_probe] "
local NAME = "r45eu_probe"
local failures = 0
local function log(text) core.log("action", P .. text) end
local function check(ok, label)
	if not ok then failures = failures + 1 end
	log((ok and "ok " or "FAIL ") .. label)
end

local function same_meta(a, b)
	local ta, tb = a:get_meta():to_table().fields, b:get_meta():to_table().fields
	for key, value in pairs(ta) do if tb[key] ~= value then return false, key end end
	for key, value in pairs(tb) do if ta[key] ~= value then return false, key end end
	return a:get_name() == b:get_name() and a:get_count() == b:get_count() and
		a:get_wear() == b:get_wear()
end

local function stand_in(inv)
	local fields = {}
	local meta = {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return math.floor(tonumber(fields[key]) or 0) end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
	}
	local player = {}
	function player:get_player_name() return NAME end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = -30000, z = 0} end
	function player:set_inventory_formspec(fs) self.formspec = fs end
	return player
end

local function count(inv, name)
	local total = 0
	for _, list in ipairs({"main", grug_jobs.TARGET_LIST, grug_jobs.OUTPUT_LIST}) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if stack:get_name() == name then total = total + stack:get_count() end
		end
	end
	return total
end

local function data_facts()
	local enchants, upgrades, own_ok = 0, 0, true
	for _, op in ipairs(grug_jobs.station_operations()) do
		if op.operation == "enchant" then
			enchants = enchants + 1
			own_ok = own_ok and op.progress == true
		else
			upgrades = upgrades + 1
			local item = op.ingredients[1] and op.ingredients[1].item
			own_ok = own_ok and op.progress == false and #op.ingredients == 1 and
				core.registered_items[item] ~= nil and grug_jobs.ingredient_tier(item) == op.tier
		end
	end
	check(enchants == 588 and upgrades == 36, ("data: %d enchants, %d upgrades"):format(
		enchants, upgrades))
	check(own_ok, "data: enchants count, upgrades never; one own material of the tier per level")
	check(core.registered_items["default:stick"] ~= nil, "data: the Stick is registered")
end

local function run(done)
	local J, Q = grug_jobs, grug_items
	local nearby, level, play = J.station_nearby, grug_xp.get_level, grug_sounds.play
	J.station_nearby = function(player, station)
		if player:get_player_name() == NAME then return true end
		return nearby(player, station)
	end
	grug_xp.get_level = function(player)
		if player and player.get_player_name and player:get_player_name() == NAME then return 30 end
		return level(player)
	end
	grug_sounds.play = function(event, target)
		if target and target.get_player_name and target:get_player_name() == NAME then return false end
		return play(event, target)
	end
	local inv = core.create_detached_inventory(NAME, {})
	inv:set_size("main", 32)
	inv:set_size(J.TARGET_LIST, 1)
	inv:set_size(J.OUTPUT_LIST, J.OUTPUT_SIZE)
	local player = stand_in(inv)
	J.learn(player, "weaponsmith", true)
	player:get_meta():set_int("grug_jobs:level:weaponsmith", 3)
	local op = J.station_operation("enchant:sword:prefix:str:t3")
	local sword = ItemStack("grug_gear:sword_steel")
	Q.crafted_output(sword, player)
	-- The target round trip.
	local enchanted = Q.operation_plan(op, sword, player).output
	local ok, key = same_meta(ItemStack(enchanted:to_string()), enchanted)
	check(ok, "target: an enchanted sword's itemstring keeps its metadata" ..
		(key and (" (differs: " .. key .. ")") or ""))
	-- An enchant job.
	inv:set_stack(J.TARGET_LIST, 1, sword)
	for index, entry in ipairs(op.ingredients) do
		inv:set_stack("main", 8 + index, ItemStack(entry.item .. " " .. entry.n))
	end
	local context = {page = "sfinv:crafting"}
	context.grug_craft = {slot = 3, page = 1, search = "", typed = "", only = false, qty = "1",
		rows = {}, box = "enchant", ench = op.id}
	-- (the first primary slot is tab 3)
	local page = J.crafting_page_content(player, context)
	log(("bytes: the Crafting page with the enchant box %d"):format(#page))
	check(page:find("grug_craft_ench_go;Enchant now]", 1, true) ~= nil,
		"enchant: the box offers Enchant now")
	local expected = Q.operation_plan(op, sword, player).output
	local started, reason = J.start_operation(player, op.id)
	check(started, "enchant: the job starts (" .. tostring(reason) .. ")")
	check(inv:get_stack(J.TARGET_LIST, 1):is_empty() and count(inv, "grug_gear:sword_steel") == 0,
		"enchant: the item lives only in the job")
	local job = J.job_state(player)
	check(job and math.abs(job.finish - job.start - 5) < 1e-6, "enchant: 5 s")
	local xp = J.crafts_in_tier(player, "weaponsmith")
	core.after(5.2, function()
		J.update_job(player, "open")
		local out = inv:get_stack(J.OUTPUT_LIST, 1)
		check(J.job_state(player) == nil and same_meta(out, expected),
			"enchant: the result is the preview's")
		check(J.crafts_in_tier(player, "weaponsmith") == xp + 1, "enchant: one XP")
		inv:set_stack(J.OUTPUT_LIST, 1, ItemStack(""))
		-- An upgrade job: +3 on a plain steel sword.
		local plain = ItemStack("grug_gear:sword_steel")
		Q.crafted_output(plain, player)
		inv:set_stack(J.TARGET_LIST, 1, plain)
		inv:set_stack("main", 9, ItemStack("grug_materials:steel_bar 5"))
		inv:set_stack("main", 10, ItemStack("default:stick 5"))
		context.grug_craft.box, context.grug_craft.levels = "upgrade", "3"
		page = J.crafting_page_content(player, context)
		log(("bytes: the Crafting page with the upgrade box %d"):format(#page))
		local upgrade = J.upgrade_operation("weaponsmith", 3)
		local up_ok, why = J.start_operation(player, upgrade.id, 3)
		check(up_ok, "upgrade: +3 starts (" .. tostring(why) .. ")")
		local up_job = J.job_state(player)
		check(up_job and math.abs(up_job.finish - up_job.start - 3) < 1e-6, "upgrade: 3 s")
		xp = J.crafts_in_tier(player, "weaponsmith")
		core.after(3.2, function()
			J.update_job(player, "open")
			local result = inv:get_stack(J.OUTPUT_LIST, 1)
			check(Q.effective_ilvl(result) == 24 and
				result:get_meta():get_int("grug_req_level") == 24, "upgrade: item level 24")
			check(count(inv, "grug_materials:steel_bar") == 2 and count(inv, "default:stick") == 2,
				"upgrade: three bars and three sticks")
			check(J.crafts_in_tier(player, "weaponsmith") == xp, "upgrade: no XP")
			J.station_nearby, grug_xp.get_level, grug_sounds.play = nearby, level, play
			core.remove_detached_inventory(NAME)
			done()
		end)
	end)
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		local ok, err = pcall(data_facts)
		if not ok then check(false, "data: " .. tostring(err)) end
		local started, run_err = pcall(run, function()
			log(failures == 0 and "PROBE PASS" or ("PROBE FAIL " .. failures))
		end)
		if not started then
			check(false, "run: " .. tostring(run_err))
			log("PROBE FAIL " .. failures)
		end
	end)
end)
