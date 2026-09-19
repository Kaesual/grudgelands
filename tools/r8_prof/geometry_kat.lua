-- Geometry KAT for crafting-page book slots and the item-grid recipe book.

return function(repo)
	local saved = {core = rawget(_G, "core"), grug_jobs = rawget(_G, "grug_jobs"),
		sfinv = rawget(_G, "sfinv"), grug_smelting = rawget(_G, "grug_smelting")}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_jobs", saved.grug_jobs)
		rawset(_G, "sfinv", saved.sfinv)
		rawset(_G, "grug_smelting", saved.grug_smelting)
	end
	local function fail(message) restore() error("r8 profession geometry: " .. message, 0) end
	local function check(value, message) if not value then fail(message) end end
	local mutation = tonumber(os.getenv("R8_PROF_GEOMETRY_MUTATION") or "") or 0

	local callbacks = {}
	local core = {registered_items = {}, registered_nodes = {}}
	rawset(_G, "core", core)
	function core.formspec_escape(value)
		if mutation == 2 then return tostring(value) end
		return tostring(value):gsub("\\", "\\\\"):gsub("]", "\\]")
			:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
	end
	function core.register_on_player_receive_fields(fn) callbacks[#callbacks + 1] = fn end
	function core.register_on_leaveplayer() end
	function core.show_formspec() end
	function core.get_all_craft_recipes(name)
		if name == "test:universal" then
			return {{method = "normal", items = {"test:universal_input"},
				output = "test:universal"}}
		elseif name == "test:universal_same_inputs" then
			return {{method = "normal",
				items = {"test:universal_t1", "test:universal_base"},
				output = "test:universal_same_inputs"}}
		end
		return {}
	end
	local sfinv = {pages = {['sfinv:crafting'] = {}}}
	rawset(_G, "sfinv", sfinv)
	function sfinv.override_page(name, definition) sfinv.pages[name] = definition end
	function sfinv.make_formspec(player, context, content) return "size[8,9.1]" .. content end
	function sfinv.set_page() end

	local learned = {}
	local recipes = {}
	for index = 1, 40 do
		local tier = math.min(6, math.floor((index - 1) / 7) + 1)
		local output = ("test:output_%02d"):format(index)
		local input = ("test:input_%02d"):format(index)
		core.registered_items[output] = {description = index == 1 and
			"Output X];button[0,0;1,1;pwn;Pwn]" or "Output " .. index}
		core.registered_items[input] = {description = index == 1 and
			"Input X];button[0,0;1,1;pwn;Pwn]" or "Input " .. index}
		recipes[index] = {profession = "cooking", tier = tier, station = "grid",
			inputs = {{input, input}}, flat_inputs = {input, input}, width = 2,
			output = output, output_name = output,
			hint = index == 1 and "Hint X];button[0,0;1,1;pwn;Pwn]" or
				"Crafting grid"}
	end
	core.registered_items["test:universal"] = {description = "Universal"}
	core.registered_items["test:universal_input"] = {description = "Input"}
	core.registered_items["test:universal_same_inputs"] = {
		description = "Universal same inputs"}
	core.registered_items["test:universal_t1"] = {description = "Tier input"}
	core.registered_items["test:universal_base"] = {description = "Base input"}
	local grug_jobs = {
		PROFESSIONS = {blacksmith = {name = "Blacksmith", class = "primary"},
			alchemist = {name = "Alchemist", class = "primary"},
			cooking = {name = "Cooking", class = "secondary"}},
		PRIMARY_SLOTS = 2,
		BOOK_TEXTURE = "grug_jobs_book.png",
		_item_name = function(value) return tostring(value):match("^([^%s]+)") end,
		_flatten_inputs = function(value) return value end,
		recipe_for_output = function() return nil end,
		recipe_for_craft = function() return nil end,
		station_handler = function() return nil end,
	}
	rawset(_G, "grug_jobs", grug_jobs)
	function grug_jobs.primary_at(player, slot) return player.primaries[slot] end
	function grug_jobs.has(player, profession) return player.learned[profession] == true end
	function grug_jobs.profession_level(player, profession) return player.prof_level or 1 end
	function grug_jobs.recipes_for(profession, station) return recipes end

	dofile(repo .. "/mods/PLAYER/grug_jobs/ui.lua")

	local function player(primaries, cooking)
		return {primaries = primaries, learned = {cooking = cooking}, prof_level = 6,
			get_player_name = function() return "layout" end}
	end
	local scenarios = {
		{"none", player({}, false)},
		{"one", player({"blacksmith"}, false)},
		{"two", player({"blacksmith", "alchemist"}, false)},
		{"two_cooking", player({"blacksmith", "alchemist"}, true)},
	}
	local report = {}
	local function inside(x, y, w, h, form_w, form_h, label)
		check(x >= 0 and y >= 0 and x + w <= form_w + 0.0001 and
			y + h <= form_h + 0.0001, label .. " escaped the form")
	end
	local function rectangles(formspec)
		local rows = {}
		for kind, x, y, w, h in formspec:gmatch(
			"([%a_]+)%[([%d%.%-]+),([%d%.%-]+);([%d%.%-]+),([%d%.%-]+);") do
			if kind == "image_button" or kind == "item_image_button" or
					kind == "button" or kind == "button_exit" or kind == "field" then
				rows[#rows + 1] = {kind = kind, x = tonumber(x), y = tonumber(y),
					w = tonumber(w), h = tonumber(h)}
			end
		end
		return rows
	end
	local function overlap(a, b)
		return a.x < b.x + b.w and b.x < a.x + a.w and
			a.y < b.y + b.h and b.y < a.y + a.h
	end

	for index = 1, #scenarios do
		local label, actor = scenarios[index][1], scenarios[index][2]
		local formspec = grug_jobs.crafting_page_content(actor)
		if mutation == 1 and index == 1 then
			formspec = formspec:gsub("0.10,3.34", "8.10,3.34", 1)
		end
		local controls = rectangles(formspec)
		check(#controls == 4, label .. " crafting page does not have four book slots")
		for control = 1, #controls do
			inside(controls[control].x, controls[control].y, controls[control].w,
				controls[control].h, 8, 9.1, label .. " book slot " .. control)
			for other = control + 1, #controls do
				check(not overlap(controls[control], controls[other]),
					label .. " book slots overlap")
			end
		end
		local empty = select(2, formspec:gsub("%[colorize:#777777:180", ""))
		local expected_empty = ({none = 3, one = 2, two = 1, two_cooking = 0})[label]
		check(empty == expected_empty, label .. " empty-slot count differs")
		report[#report + 1] = table.concat({"crafting", label, "slots=4",
			"empty=" .. empty, "inside", "nonoverlap"}, "\t") .. "\n"
	end

	local actor = scenarios[4][2]
	local formspec, page, pages = grug_jobs.book_formspec(actor, "cooking", nil, 1)
	check(page == 1 and pages == 3,
		"40 recipe outputs did not paginate at fourteen items per page")
	local page_one_items = select(2, formspec:gsub("item_image_button%[", ""))
	check(page_one_items == 14, "first item page does not contain fourteen outputs")
	local last_formspec, last_page = grug_jobs.book_formspec(actor, "cooking", nil, 3)
	local last_items = select(2, last_formspec:gsub("item_image_button%[", ""))
	check(last_page == 3 and last_items == 12,
		"last item page does not contain the remaining twelve outputs")
	check(formspec:find("field[0.3,0.72;3.7,0.7;grug_jobs_search", 1, true) and
		formspec:find("grug_jobs_do_search", 1, true) and
		formspec:find("grug_jobs_clear_search", 1, true),
		"search field or actions left the book header")
	local searched, search_page, search_pages = grug_jobs.book_formspec(actor,
		"cooking", nil, 1, "output x")
	local searched_items = select(2, searched:gsub("item_image_button%[", ""))
	check(search_page == 1 and search_pages == 1 and searched_items == 1,
		"text search did not reduce the output grid")
	local grid_slots = select(2, formspec:gsub(
		"box%[[%d%.]+,[%d%.]+;0%.82,0%.82;#20202066%]", ""))
	check(grid_slots == 9, "selected grid recipe does not show nine grid cells")
	check(formspec:find("X];button[", 1, true) == nil and
		formspec:find("X\\]\\;button\\[", 1, true) ~= nil,
		"book text was not formspec-escaped")
	local controls = rectangles(formspec)
	for index = 1, #controls do
		inside(controls[index].x, controls[index].y, controls[index].w,
			controls[index].h, 10, 9.8, "book control")
		for other = index + 1, #controls do
			check(not overlap(controls[index], controls[other]),
				"book controls overlap")
		end
	end
	inside(1.25, 5.65, 2.62, 2.62, 10, 9.8, "selected recipe grid")
	inside(4.15, 6.55, 0.9, 0.7, 10, 9.8, "recipe arrow")
	inside(5.25, 6.35, 1.1, 1.1, 10, 9.8, "recipe output")
	report[#report + 1] = "book\trecipes=40\tcapacity=14\tpages=3\t" ..
		"last=12\tsearch=1\tgrid=3x3\tinside\tnonoverlap\n"
	local general = grug_jobs.book_records(actor, "general")
	check(#general == 2 and general[1].output_name == "test:universal" and
		general[2].output_name == "test:universal_same_inputs",
		"universal recipe disappeared from the general book")
	report[#report + 1] = "escaping\tdescription+input+hint\tgeneral_recipes_listed\n"
	restore()
	return table.concat(report)
end
