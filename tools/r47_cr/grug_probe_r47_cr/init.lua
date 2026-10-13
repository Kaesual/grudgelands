-- Disposable Round 47 CR probe (never shipped), staged by one headless boot
-- (tools/luanti_headless.sh with PROBE=tools/r47_cr/grug_probe_r47_cr). One
-- step after the load it builds the Crafting tab with the real registry
-- and the real Basic catalog for a stand-in player on a detached inventory
-- and logs, with the prefix [r47cr_probe]:
--   fresh   a fresh character's Basic list (its first scan, silent): the
--           rows, the pager, the known count against the catalog;
--   held    the list after a tree and coal are held: the feed line, the
--           new rows;
--   overflow the right column without and with something in the overflow
--           (the formspec part dumped);
--   deliver a 2-craft job of planks, one craft per second, read back after
--           1.2 s and 2.3 s (real engine clock and core.after).
-- Ends with "PROBE PASS" or "PROBE FAIL <n>".
local P = "[r47cr_probe] "
local NAME = "r47cr_probe"
local failures = 0
local function log(text) core.log("action", P .. text) end
local function check(ok, label)
	if not ok then failures = failures + 1 end
	log((ok and "ok " or "FAIL ") .. label)
end

local function stand_in(inv)
	local fields = {}
	local meta = {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(fields[key]) or 0 end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
	}
	local player = {sent = 0}
	function player:get_player_name() return NAME end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = -30000, z = 0} end
	function player:set_inventory_formspec(fs)
		self.sent = self.sent + 1
		self.formspec = fs
	end
	return player, fields
end

-- The rows' names of a build (the list's labels between the icon and ×N).
local function rows_of(fs)
	local rows = {}
	for name in fs:gmatch("label%[0%.9,[%d%.]+;([^%]]-)%]label%[4%.45,") do
		rows[#rows + 1] = name
	end
	return rows
end

local function probe(done)
	local J = grug_jobs
	local feed, play = grug_core.feed, grug_sounds.play
	local lines = {}
	grug_core.feed = function(player, kind, text, key)
		if player and player.get_player_name and player:get_player_name() == NAME then
			lines[#lines + 1] = text
			return true
		end
		return feed(player, kind, text, key)
	end
	-- The stand-in is no ObjectRef: the craft sound skips it.
	grug_sounds.play = function(event, target)
		if target and target.get_player_name and target:get_player_name() == NAME then
			return false
		end
		return play(event, target)
	end
	local function restore()
		grug_core.feed, grug_sounds.play = feed, play
		core.remove_detached_inventory(NAME)
	end
	local inv = core.create_detached_inventory(NAME, {})
	inv:set_size("main", 32)
	local player, fields = stand_in(inv)
	J.ensure_output_area(player)
	local context = {page = "sfinv:crafting"}
	local function build(label)
		local fs = sfinv.get_formspec(player, context)
		local content = fs:match("real_coordinates%[false%](.*)$") or ""
		log(("bytes %s: content %d, page %d"):format(label, #content, #fs))
		return content
	end

	-- A fresh character: the first scan is the page build's (silent).
	local fs = build("a fresh character's Basic page")
	local rows = rows_of(fs)
	log("fresh rows: " .. table.concat(rows, " | "))
	log("fresh pager: " .. (fs:match("Page %d+ of %d+") or "?"))
	local known = 0
	for _, recipe in ipairs(J.recipes_in_area("basic")) do
		if J.recipe_known(player, recipe) then known = known + 1 end
	end
	log(("fresh: %d of %d Basic recipes known"):format(known, #J.recipes_in_area("basic")))
	check(known == 5, "a fresh character knows the five starter recipes")
	check(#lines == 0, "the first scan says nothing")
	check(fields[J.HELD_KEY] == "1", "the first scan stores the empty set")

	-- Held once: a tree and coal.
	inv:set_stack("main", 9, "default:tree 2")
	inv:set_stack("main", 10, "default:coal_lump 1")
	fs = build("after holding a tree and coal")
	rows = rows_of(fs)
	log("held rows: " .. table.concat(rows, " | "))
	log("held feed: " .. (lines[1] or "(none)"))
	check(lines[1] ~= nil and lines[1]:find("^New recipe") ~= nil, "the feed line")
	log("held set: " .. (fields[J.HELD_KEY] or ""))

	-- The overflow: hidden while empty, shown with the item.
	local right = fs:match("(box%[10%.4,0%.95;.*)$") or ""
	log("overflow empty, right column: " .. right)
	check(not right:find("grug_craft_out", 1, true), "no overflow slots while empty")
	inv:set_stack(J.OUTPUT_LIST, 1, "default:wood 5")
	fs = build("with something in the overflow")
	right = fs:match("(box%[10%.4,0%.95;.*)$") or ""
	log("overflow shown, right column: " .. right)
	check(right:find("list[current_player;grug_craft_out;", 1, true) ~= nil,
		"the overflow slots while it holds something")
	inv:set_stack(J.OUTPUT_LIST, 1, "")

	-- Per-craft delivery on the engine clock: 3 crafts of planks.
	local planks = J.recipes_for_output("default:wood")
	local recipe
	for _, r in ipairs(planks) do
		if r.ingredients[1].item == "default:tree" then recipe = r end
	end
	check(recipe ~= nil, "the planks-from-tree recipe")
	if not recipe then restore() return done() end
	local ok, reason = J.start_job(player, recipe.id, 2)
	check(ok, "a 2-craft job of planks starts (" .. tostring(reason) .. ")")
	local function planks_held()
		local n = 0
		for _, stack in ipairs(inv:get_list("main")) do
			if stack:get_name() == "default:wood" then n = n + stack:get_count() end
		end
		return n
	end
	core.after(1.2, function()
		J.update_job(player, "open")
		log(("deliver at 1.2 s: %d planks, job %s"):format(planks_held(),
			J.job_state(player) and "running" or "done"))
		check(planks_held() == 4 and J.job_state(player) ~= nil, "one craft delivered at 1.2 s")
		core.after(1.1, function()
			J.update_job(player, "open")
			log(("deliver at 2.3 s: %d planks, job %s"):format(planks_held(),
				J.job_state(player) and "running" or "done"))
			check(planks_held() == 8 and J.job_state(player) == nil, "both at the end")
			restore()
			done()
		end)
	end)
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		local function finish()
			log(failures == 0 and "PROBE PASS" or ("PROBE FAIL " .. failures))
		end
		local ok, err = pcall(probe, finish)
		if not ok then
			check(false, "error: " .. tostring(err))
			finish()
		end
	end)
end)
