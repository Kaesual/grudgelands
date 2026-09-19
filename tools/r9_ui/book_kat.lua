-- Real-code KAT for recipe-book presentation and per-player discovery.
-- Usage: <lua> -e 'io.write(dofile(".../book_kat.lua")("/abs/repo"))'

return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("R9-UI book KAT: absolute repository root required", 0)
	end
	local saved = {core = rawget(_G, "core"), grug_jobs = rawget(_G, "grug_jobs"),
		grug_xp = rawget(_G, "grug_xp"), sfinv = rawget(_G, "sfinv"),
		grug_smelting = rawget(_G, "grug_smelting")}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_jobs", saved.grug_jobs)
		rawset(_G, "grug_xp", saved.grug_xp)
		rawset(_G, "sfinv", saved.sfinv)
		rawset(_G, "grug_smelting", saved.grug_smelting)
	end
	local function fail(message)
		restore()
		error("R9-UI book KAT: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local hooks = {steps = {}, leave = {}, receive = {}}
	local shown, pages, closed = {}, {}, 0
	local writes = 0
	local recipes = {}
	local groups = {
		["test:iron"] = {metal = 1},
		["test:copper"] = {metal = 1},
		["test:hybrid"] = {metal = 1, rare = 1},
	}
	local function stack(name)
		return {get_name = function() return name end}
	end
	local function serialize(values)
		local out = {"return {"}
		for index = 1, #values do out[#out + 1] = string.format("%q,", values[index]) end
		out[#out + 1] = "}"
		return table.concat(out)
	end
	rawset(_G, "core", {
		registered_items = {}, registered_nodes = {},
		formspec_escape = function(value)
			return tostring(value):gsub("([%[%];,])", "\\%1")
		end,
		serialize = serialize,
		deserialize = function(value)
			local chunk = loadstring(value)
			return chunk and chunk() or nil
		end,
		get_item_group = function(name, group)
			return groups[name] and groups[name][group] or 0
		end,
		get_all_craft_recipes = function(name) return recipes[name] end,
		register_globalstep = function(fn) hooks.steps[#hooks.steps + 1] = fn end,
		register_on_leaveplayer = function(fn) hooks.leave[#hooks.leave + 1] = fn end,
		register_on_player_receive_fields = function(fn)
			hooks.receive[#hooks.receive + 1] = fn
		end,
		show_formspec = function(name, formname, formspec)
			shown[#shown + 1] = {name = name, formname = formname, formspec = formspec}
		end,
		close_formspec = function() closed = closed + 1 end,
		chat_send_player = function() end,
	})
	rawset(_G, "sfinv", {
		override_page = function() end,
		make_formspec = function(_, _, content) return content end,
		set_page = function(_, page) pages[#pages + 1] = page end,
	})
	rawset(_G, "grug_xp", {get_level = function(player) return player.level end})
	rawset(_G, "grug_smelting", {RECIPES = {}})
	rawset(_G, "grug_jobs", {
		PROFESSIONS = {
			blacksmith = {name = "Blacksmith", class = "primary"},
			cooking = {name = "Cooking", class = "secondary"},
		},
		PRIMARY_SLOTS = 2,
		STATIONS = {grid = true, furnace = true, dual_furnace = true,
			brewing_stand = true, forge = true, tanning_rack = true,
			tailor_bench = true, carving_bench = true, jewellers_bench = true},
	})
	local function item_name(value)
		if type(value) == "string" then return value:match("^%s*([^%s]+)") or "" end
		if type(value) == "table" and type(value.get_name) == "function" then
			return value:get_name()
		end
		return ""
	end
	local function flatten(value, out)
		out = out or {}
		if type(value) == "string" or
				(type(value) == "table" and type(value.get_name) == "function") then
			local name = item_name(value)
			if name ~= "" then out[#out + 1] = name end
		elseif type(value) == "table" then
			local maximum = 0
			for key in pairs(value) do
				if type(key) == "number" and key > maximum then maximum = key end
			end
			for index = 1, maximum do flatten(value[index], out) end
		end
		return out
	end
	grug_jobs._item_name = item_name
	grug_jobs._flatten_inputs = flatten
	grug_jobs.recipe_for_craft = function() return nil end

	local profession_recipes = {
		{
			profession = "blacksmith", tier = 1, station = "grid",
			inputs = {{"test:a", "", "group:metal"}, {"", "test:b", ""}},
			flat_inputs = {"test:a", "group:metal", "test:b"},
			output = "test:widget", output_name = "test:widget", hint = "Exact grid",
		},
		{
			profession = "blacksmith", tier = 1, station = "furnace",
			inputs = {"test:ore"}, flat_inputs = {"test:ore"},
			output = "test:widget", output_name = "test:widget", hint = "Smelt",
		},
		{
			profession = "blacksmith", tier = 2, station = "forge",
			inputs = {"group:metal,rare", "test:t2"},
			flat_inputs = {"group:metal,rare", "test:t2"},
			output = "test:t2_output", output_name = "test:t2_output",
			hint = "Forge",
		},
	}
	grug_jobs.recipes_for = function(profession, station)
		local result = {}
		if profession ~= "blacksmith" then return result end
		for index = 1, #profession_recipes do
			if not station or profession_recipes[index].station == station then
				result[#result + 1] = profession_recipes[index]
			end
		end
		return result
	end

	for _, name in ipairs({"test:a", "test:b", "test:iron", "test:copper",
		"test:hybrid", "test:ore", "test:t2", "test:widget", "test:t2_output",
		"test:engine", "test:shapeless"}) do
		core.registered_items[name] = {description = name:gsub("test:", "")}
	end
	recipes["test:engine"] = {{method = "normal", width = 3,
		items = {[1] = "test:a", [3] = "test:b", [5] = "test:iron"},
		output = "test:engine"}}
	recipes["test:shapeless"] = {{method = "normal", width = 0,
		items = {"test:a", "test:b", "test:iron"}, output = "test:shapeless"}}

	local values = {}
	local metadata = {
		get_string = function(_, key) return values[key] or "" end,
		set_string = function(_, key, value) values[key] = value writes = writes + 1 end,
		get_int = function(_, key) return tonumber(values[key]) or 0 end,
		set_int = function(_, key, value) values[key] = tostring(value) end,
	}
	local inventory = {main = {stack("test:a")}, craft = {stack("test:copper")}}
	local player = {
		level = 60,
		get_player_name = function() return "tester" end,
		get_meta = function() return metadata end,
		get_inventory = function()
			return {get_list = function(_, listname) return inventory[listname] end}
		end,
	}
	core.get_connected_players = function() return {player} end

	dofile(root .. "/mods/PLAYER/grug_jobs/state.lua")
	dofile(root .. "/mods/PLAYER/grug_jobs/discovery.lua")
	dofile(root .. "/mods/PLAYER/grug_jobs/ui.lua")

	check(grug_jobs.DISCOVERY_META_KEY == "grug_jobs:seen_items",
		"discovery meta key differs")
	check(#hooks.steps == 1, "discovery did not register one globalstep")
	hooks.steps[1](1.9)
	check(writes == 0, "inventory scan ran before two seconds")
	hooks.steps[1](0.1)
	check(writes == 1 and grug_jobs.discovery_seen(player, "test:a") and
		grug_jobs.discovery_seen(player, "group:metal"),
		"main/craft scan or group discovery differs")
	check(values[grug_jobs.DISCOVERY_META_KEY]:match("^return {%s*\"test:a\"," ..
		"%s*\"test:copper\","), "seen set is not a sorted serialized array")

	local learned = grug_jobs.learn(player, "blacksmith")
	check(learned and grug_jobs.discovery_seen(player, "test:b") and
		grug_jobs.discovery_seen(player, "test:ore") and
		grug_jobs.discovery_seen(player, "group:metal"),
		"learning did not mark every T1 input seen")
	check(not grug_jobs.discovery_seen(player, "test:t2"),
		"learning marked a T2 input seen")
	local writes_after_learn = writes
	grug_jobs.mark_seen(player, {"test:a", "test:b"})
	check(writes == writes_after_learn, "unchanged discovery set was rewritten")
	grug_jobs.unlearn(player, "blacksmith")
	check(grug_jobs.discovery_seen(player, "test:b"), "unlearning erased discovery")
	grug_jobs.learn(player, "blacksmith")

	local profession = grug_jobs.book_records(player, "blacksmith")
	check(#profession == 3, "profession book mixed or lost records")
	check(profession[1].width == 3 and profession[1].method == "normal" and
		profession[1].shapeless == false, "registry cache metadata differs")
	local cells = grug_jobs._book_recipe_cells(profession[1])
	check(#cells == 3 and cells[1].column == 1 and cells[1].row == 1 and
		cells[2].column == 3 and cells[2].row == 1 and
		cells[3].column == 2 and cells[3].row == 2,
		"shaped recipe lost exact cells")

	local general = grug_jobs.book_records(player, "general")
	local by_output = {}
	for index = 1, #general do by_output[general[index].output_name] = general[index] end
	check(by_output["test:engine"].width == 3 and
		by_output["test:engine"].method == "normal" and
		by_output["test:engine"].shapeless == false and
		by_output["test:engine"].display_items[2] == "" and
		by_output["test:engine"].display_items[5] == "test:iron",
		"engine shaped cache metadata differs")
	check(by_output["test:shapeless"].width == 0 and
		by_output["test:shapeless"].shapeless == true,
		"engine shapeless metadata differs")

	metadata:set_int("grug_jobs:level:blacksmith", 2)
	local counts = grug_jobs.book_undiscovered_counts(player, profession)
	check(counts[1] == 0 and counts[2] == 1,
		"undiscovered tier counts differ")
	grug_jobs.mark_seen(player, {"test:hybrid", "test:t2"})
	check(grug_jobs.recipe_discovered(player, profession[3]),
		"multi-group token did not accept one matching seen item")
	local formspec = grug_jobs.book_formspec(player, "blacksmith", nil, 1,
		"widget")
	check(formspec:find("test:widget", 1, true) and
		not formspec:find("test:t2_output", 1, true),
		"search did not filter listed outputs")
	check(formspec:find("button_exit", 1, true) == nil and
		formspec:find("grug_jobs_close", 1, true), "Close is still button_exit")

	local station_ids = {"forge", "tanning_rack", "tailor_bench",
		"carving_bench", "jewellers_bench"}
	for index = 1, #station_ids do
		local _, item = grug_jobs.book_station_icon(station_ids[index])
		check(item == false, station_ids[index] .. " lacks its fallback icon")
	end
	core.registered_nodes["test:forge"] = {_grug_station = "forge",
		inventory_image = "test_forge.png"}
	local icon, item = grug_jobs.book_station_icon("forge")
	check(icon == "test:forge" and item == true,
		"registered station inventory presentation was not selected")
	local dual = grug_jobs._book_recipe_cells({station = "dual_furnace",
		flat_inputs = {"test:a", "test:b"}})
	local brewing = grug_jobs._book_recipe_cells({station = "brewing_stand",
		flat_inputs = {"test:a", "test:b", "test:ore"}})
	check(#dual == 2 and dual[1].row == 2 and dual[2].column == 3 and
		#brewing == 3 and brewing[3].column == 2 and brewing[3].row == 3,
		"custom station slot layouts differ")

	grug_jobs.open_book(player, "blacksmith")
	check(shown[#shown].formspec:find("1 / 2", 1, true),
		"same-output alternatives were not grouped")
	hooks.receive[1](player, "grug_jobs:book", {grug_jobs_alt_next = true})
	check(shown[#shown].formspec:find("2 / 2", 1, true),
		"alternative next action did not cycle")
	hooks.receive[1](player, "grug_jobs:book", {grug_jobs_close = true})
	check(pages[#pages] == "sfinv:crafting" and closed == 1,
		"Close did not return through sfinv.set_page")

	restore()
	return table.concat({
		"R9-UI book KAT PASS",
		"meta=grug_jobs:seen_items",
		"format=sorted_serialized_item_array",
		"cache=width,method,shapeless",
		"exact_grid=pass",
		"alternatives=2",
		"stations=9",
		"close=sfinv:crafting\n",
	}, " ")
end
