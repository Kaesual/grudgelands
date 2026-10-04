-- Round 33 Lane C1 probe (never shipped): from the REAL resolved payouts
-- (grug_traders.sell_price) it prints the mean Common payout of each tier's
-- drop pool, before (the catalog's 18 weapons and armour) and after (the 26
-- items of grug_gear.drop_pool), which tools/r33_c1/drop_income.py turns into
-- drop income per band. Then one real roll of each drop kind on registered
-- items: a normal kill, a boss, a trinket, the requirement, the sale value.
-- Ends with "RESULT PASS" or "RESULT FAIL".

local function log(text)
	core.log("action", "[r33_c1_probe] " .. text)
end

core.register_on_mods_loaded(function()
	local ok = true
	local function check(cond, label)
		if not cond then ok = false; log("FAIL " .. label) end
	end
	log("tier | before: items, mean payout | after: items, mean payout, unsold")
	for tier = 1, 6 do
		local before, after, zero = 0, 0, {}
		local all = grug_gear.catalog[tier].all
		for _, item in ipairs(all) do before = before + grug_traders.sell_price(item) end
		local pool = grug_gear.drop_pool[tier]
		for _, item in ipairs(pool) do
			local payout = grug_traders.sell_price(item)
			after = after + payout
			if payout == 0 then zero[#zero + 1] = item:gsub("^grug_gear:", "") end
		end
		log(("%d | %d %.2f | %d %.2f | %s"):format(tier, #all, before / #all, #pool,
			after / #pool, table.concat(zero, " ")))
	end
	-- One real roll of each kind.
	local wolf = {name = "grug_mobs:wolf", _grug_tier = "elite", _grug_level = 37}
	local found
	for seed = 1, 400 do
		for _, stack in ipairs(grug_items.roll_mob_gear(wolf, seed)) do
			if stack:get_meta():get_int("grug_quality") == 2 then found = found or stack end
		end
	end
	check(found ~= nil, "an elite kill drops a blue item")
	if found then
		log("blue drop: " .. found:get_meta():get_string("description"):gsub("\n", " | "))
		check(found:get_meta():get_int("grug_req_level") == 37, "its requirement is 37")
		check(grug_traders.stack_sell_price(found) ==
			3 * grug_traders.sell_price(found:get_name()), "it sells at x3")
	end
	local king = {name = "grug_mobs:king_human", _grug_boss_id = "king:human",
		_grug_royal_king = true, _grug_tier = "elite", _grug_level = 65}
	local rewards = grug_items.roll_mob_gear(king, 42)
	check(#rewards >= 2, "a King drops two items")
	for _, stack in ipairs(rewards) do
		log("King drop: " .. stack:get_meta():get_string("description"):gsub("\n", " | "))
	end
	local trinket = ItemStack("grug_gear:mercy_seal_t4")
	grug_items.roll_enchants(trinket, 34, 1, 5)
	check(#grug_items.get_affixes(trinket) == 1, "a trinket rolls one enchant")
	log("trinket: " .. trinket:get_meta():get_string("description"):gsub("\n", " | "))
	log("helm definition: " .. core.registered_items["grug_gear:head_metal_steel"]
		.description:gsub("\n", " | "))
	log(ok and "RESULT PASS" or "RESULT FAIL")
end)
