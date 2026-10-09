-- Disposable Round 45 JB probe (never shipped), staged by the smoke boot
-- (tools/luanti_headless.sh with PROBE=tools/r45_jb/grug_probe_r45_jb). One
-- step after the load it logs, with the prefix [r45jb_probe]:
--   overlaps  recipes with two ingredient entries that accept one item (the
--             ×N count assumes none; the start stays exact anyway);
--   stackable outputs crafted_output changes although they stack (their
--             output room would be counted too high);
--   stations  the nodes per profession station kind;
--   engine    ItemStack counts above stack_max, get_keys on a fresh stack,
--             core.serialize keeping sub-second times;
--   cycle     one Basic job and one gear job on a detached inventory with a
--             stand-in player: consumption, completion, the output stacks,
--             crafted_output's metadata, the refund.
-- Ends with "PROBE PASS" or "PROBE FAIL <n>".
local P = "[r45jb_probe] "
local failures = 0
local function log(text) core.log("action", P .. text) end
local function check(ok, label)
	if not ok then failures = failures + 1 end
	log((ok and "ok " or "FAIL ") .. label)
end

local function accepts(entry, name)
	if entry.item then return entry.item == name end
	return core.get_item_group(name, entry.group) > 0
end

local function registry_facts()
	local J = grug_jobs
	local overlaps = {}
	for _, recipe in ipairs(J.recipes) do
		local list = recipe.ingredients
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local hit
				if a.item then hit = accepts(b, a.item)
				elseif b.item then hit = accepts(a, b.item)
				else
					for name in pairs(core.registered_items) do
						if accepts(a, name) and accepts(b, name) then hit = true break end
					end
				end
				if hit then overlaps[#overlaps + 1] = recipe.id end
			end
		end
	end
	log("recipes " .. #J.recipes .. ", overlapping entries in " .. #overlaps ..
		(#overlaps > 0 and (": " .. table.concat(overlaps, ", ")) or ""))
	local stackable = {}
	for _, recipe in ipairs(J.recipes) do
		local stack = ItemStack(recipe.output .. " 2")
		if stack:get_stack_max() > 1 then
			local ok, changed = pcall(grug_items.crafted_output, stack, nil)
			if not ok or changed then stackable[#stackable + 1] = recipe.output end
		end
	end
	log("stackable outputs crafted_output changes: " .. #stackable ..
		(#stackable > 0 and (": " .. table.concat(stackable, ", ")) or ""))
	local kinds = {}
	for _, kind in pairs(J.PROFESSION_STATIONS) do kinds[kind] = 0 end
	for _, def in pairs(core.registered_nodes) do
		if def._grug_station and kinds[def._grug_station] then
			kinds[def._grug_station] = kinds[def._grug_station] + 1
		end
	end
	for kind, count in pairs(kinds) do check(count > 0, "station " .. kind .. " nodes " .. count) end
end

local function engine_facts()
	check(ItemStack("default:stick 150"):get_count() == 150, "an ItemStack holds 150 sticks")
	check(#ItemStack("default:stick"):get_meta():get_keys() == 0, "a fresh stack has no meta keys")
	local t = 1700000000.123456
	local back = core.deserialize(core.serialize({finish = t}))
	check(back and back.finish == t, "core.serialize keeps sub-second times")
	local now = grug_jobs.now()
	check(math.abs(now - os.time()) <= 1, "grug_jobs.now() is within a second of os.time()")
end

local function stand_in(inv)
	local fields = {}
	local meta = {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(fields[key]) or 0 end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
	}
	local player = {}
	function player:get_player_name() return "r45jb_probe" end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = -30000, z = 0} end
	return player, fields
end

local function cycle()
	local J = grug_jobs
	local inv = core.create_detached_inventory("r45jb_probe", {})
	inv:set_size("main", 32)
	local player, fields = stand_in(inv)
	J.ensure_output_area(player)
	check(inv:get_size(J.OUTPUT_LIST) == 4, "the output area has 4 slots")
	-- A Basic job with item entries only.
	local basic
	for _, recipe in ipairs(J.recipes_in_area("basic")) do
		local items_only = true
		for _, entry in ipairs(recipe.ingredients) do
			if not entry.item then items_only = false end
		end
		if items_only and ItemStack(recipe.output):get_stack_max() >= 10 then basic = recipe break end
	end
	check(basic ~= nil, "a Basic recipe with item entries: " .. (basic and basic.id or "none"))
	if not basic then return end
	for _, entry in ipairs(basic.ingredients) do inv:add_item("main", entry.item .. " " .. entry.n * 30) end
	local counts = J.ingredient_counts(player)
	local most, by_ingredients, by_space = J.max_craftable(player, basic, counts)
	log(("basic %s: max %d (ingredients %d, space %d)"):format(basic.id, most, by_ingredients, by_space))
	local quantity = math.min(30, most)
	local ok, reason = J.start_job(player, basic.id, quantity)
	check(ok, "the Basic job starts " .. tostring(reason))
	local job = J.job_state(player)
	check(job and math.abs(job.finish - job.start - quantity * basic.time) < 1e-6,
		"the job lasts quantity x time")
	ok = J.cancel_job(player)
	check(ok, "cancel refunds")
	for _, entry in ipairs(basic.ingredients) do
		check(inv:contains_item("main", entry.item .. " " .. entry.n * 30),
			"refunded " .. entry.item)
	end
	J.start_job(player, basic.id, quantity)
	job = core.deserialize(fields[J.JOB_KEY])
	job.finish = J.now() - 0.01
	fields[J.JOB_KEY] = core.serialize(job)
	check(J.update_job(player, "open"), "a due job completes on update")
	local total = 0
	for index = 1, 4 do
		local stack = inv:get_stack(J.OUTPUT_LIST, index)
		if stack:get_name() == basic.output then total = total + stack:get_count() end
		check(stack:get_count() <= stack:get_stack_max(), "output slot " .. index .. " within stack_max")
	end
	check(total == quantity * basic.count, "the output holds quantity x count (" .. total .. ")")
	local moved = J.take_all(player)
	check(moved and inv:is_empty(J.OUTPUT_LIST), "Take all empties the output area")
	-- A gear job: crafted_output on each stack.
	local gear
	for _, recipe in ipairs(J.recipes_in_area("weaponsmith")) do
		if recipe.tier == 1 then gear = recipe break end
	end
	check(gear ~= nil, "a T1 weaponsmith recipe: " .. (gear and gear.id or "none"))
	if not gear then return end
	J.begin_job(player, {kind = "recipe", recipe = gear.id, quantity = 2, duration = 0})
	check(J.update_job(player, "open"), "the gear job completes")
	local made = 0
	for index = 1, 4 do
		local stack = inv:get_stack(J.OUTPUT_LIST, index)
		if stack:get_name() == gear.output then
			made = made + 1
			local meta = stack:get_meta()
			check(meta:get_int("grug_quality") == 1 and meta:get_int("grug_ilvl") > 0,
				("gear stack %d: quality %d, item level %d"):format(index,
				meta:get_int("grug_quality"), meta:get_int("grug_ilvl")))
		end
	end
	check(made == 2, "two gear stacks, one per item")
	core.remove_detached_inventory("r45jb_probe")
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		for _, step in ipairs({registry_facts, engine_facts, cycle}) do
			local ok, err = pcall(step)
			if not ok then check(false, "error: " .. tostring(err)) end
		end
		log(failures == 0 and "PROBE PASS" or ("PROBE FAIL " .. failures))
	end)
end)
