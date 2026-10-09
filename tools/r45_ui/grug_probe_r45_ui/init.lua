-- Disposable Round 45 UI probe (never shipped), staged by the smoke boot
-- (tools/luanti_headless.sh with PROBE=tools/r45_ui/grug_probe_r45_ui). One
-- step after the load it builds the Crafting tab with the real registry for
-- a stand-in player on a detached inventory and logs, with the prefix
-- [r45ui_probe]:
--   areas   recipes and pages per area;
--   list    the longest output names against the list's and the box's clip,
--           the most ingredient entries (more than five show "and N more"),
--           the group entries with their label and member count;
--   bytes   the page's formspec bytes (content and whole page) for Basic
--           page 1 with nothing chosen and with a recipe chosen, a
--           profession area, and a page during a job (comparisons, never
--           targets; the old Crafting page was 1148 / 1009 B of content);
--   sends   a job's start, end and cancel through the page's click handler.
-- Ends with "PROBE PASS" or "PROBE FAIL <n>".
local P = "[r45ui_probe] "
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
	function player:get_player_name() return "r45ui_probe" end
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

local AREAS = {"basic", "cooking", "weaponsmith", "armorsmith", "tailor",
	"leatherworker", "woodcarver", "goldsmith", "alchemist"}

local function list_facts()
	local J = grug_jobs
	for _, area in ipairs(AREAS) do
		local count = #J.recipes_in_area(area)
		log(("area %s: %d recipes, %d pages"):format(area, count,
			math.max(1, math.ceil(count / 10))))
	end
	local longest, most, groups, unnamed = {}, {}, {}, {}
	for _, recipe in ipairs(J.recipes) do
		local name = J.recipe_label(recipe.output)
		if name == recipe.output then unnamed[#unnamed + 1] = recipe.output end
		longest[#longest + 1] = name
		if #recipe.ingredients > (most.n or 0) then
			most = {n = #recipe.ingredients, id = recipe.id}
		end
		for _, entry in ipairs(recipe.ingredients) do
			if entry.group then groups[entry.group] = true end
		end
	end
	check(#unnamed == 0, "every output has a name" ..
		(#unnamed > 0 and (": " .. table.concat(unnamed, ", ")) or ""))
	table.sort(longest, function(a, b) return #a > #b end)
	local over_list, over_box = 0, 0
	for _, name in ipairs(longest) do
		if #name > 23 then over_list = over_list + 1 end
		local lines = grug_inventory.wrap_text(name, 22)
		if select(2, lines:gsub("\n", "")) > 1 then over_box = over_box + 1 end
	end
	log(("names: longest %q (%d chars); %d clipped in the list (23, full name as" ..
		" tooltip), %d beyond the box's two lines of 22"):format(longest[1] or "",
		#(longest[1] or ""), over_list, over_box))
	local many = 0
	for _, recipe in ipairs(J.recipes) do
		if #recipe.ingredients > 5 then many = many + 1 end
	end
	log(("ingredients: at most %d entries (%s); %d recipes above five"):format(most.n or 0,
		most.id or "", many))
	local names = {}
	for group in pairs(groups) do names[#names + 1] = group end
	table.sort(names)
	for _, group in ipairs(names) do
		local members = 0
		for name in pairs(core.registered_items) do
			if core.get_item_group(name, group) > 0 then members = members + 1 end
		end
		check(members > 0, ("group %s: %d members"):format(group, members))
	end
end

local function page_bytes()
	local J = grug_jobs
	local F = J.CRAFT_FIELDS
	-- The stand-in is no ObjectRef: the craft sound skips it.
	local play = grug_sounds.play
	grug_sounds.play = function(event, target)
		if target and target.get_player_name and target:get_player_name() == "r45ui_probe" then
			return false
		end
		return play(event, target)
	end
	local inv = core.create_detached_inventory("r45ui_probe", {})
	inv:set_size("main", 32)
	local player, fields = stand_in(inv)
	J.ensure_output_area(player)
	local context = {page = "sfinv:crafting"}
	local page = sfinv.pages["sfinv:crafting"]
	local function build(label)
		local fs = sfinv.get_formspec(player, context)
		local content = fs:match("real_coordinates%[false%](.*)$") or ""
		log(("bytes %s: content %d, page %d"):format(label, #content, #fs))
		return fs
	end
	local function click(event)
		return page:on_player_receive_fields(player, context, event)
	end
	local fs = build("Basic page 1, nothing chosen")
	check(fs:find("grug_craft_area1;Basic]", 1, true) ~= nil, "the Basic tab")
	check(fs:find("Page 1 of", 1, true) ~= nil, "the pager")
	click({[F.row .. "1"] = ""})
	build("Basic page 1, a recipe chosen")
	-- A profession area: Weaponsmith learned at T1.
	fields["grug_jobs:primary:1"] = "weaponsmith"
	fields["grug_jobs:level:weaponsmith"] = 1
	click({[F.area .. "3"] = "Weaponsmith"})
	click({[F.row .. "1"] = ""})
	fs = build("Weaponsmith page 1, a recipe chosen")
	check(fs:find("Requires: Forge nearby", 1, true) ~= nil, "the station hint without a forge")
	-- A Basic job: the first item-only recipe with a stackable output.
	click({[F.area .. "1"] = "Basic"})
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
	for _, entry in ipairs(basic.ingredients) do inv:add_item("main", entry.item .. " " .. entry.n * 5) end
	context.grug_craft.selected = basic.id
	local sent = player.sent
	click({[F.qty] = "5", [F.go] = "Craft now"})
	check(J.job_state(player) ~= nil, "the job starts from the page")
	check(player.sent == sent + 1, "the start sends once")
	fs = build("a page during a job, the recipe chosen")
	check(fs:find("animated_image[", 1, true) ~= nil, "the progress bar")
	sent = player.sent
	click({[F.stop] = "Stop"})
	check(J.job_state(player) == nil, "Stop cancels")
	check(player.sent == sent + 1, "the cancel sends once")
	core.remove_detached_inventory("r45ui_probe")
	grug_sounds.play = play
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		for _, step in ipairs({list_facts, page_bytes}) do
			local ok, err = pcall(step)
			if not ok then check(false, "error: " .. tostring(err)) end
		end
		log(failures == 0 and "PROBE PASS" or ("PROBE FAIL " .. failures))
	end)
end)
