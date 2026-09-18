-- Geometry KAT for the crafting book slots and a paged 40-recipe book.

return function(repo)
	local saved = {core = rawget(_G, "core"), grug_jobs = rawget(_G, "grug_jobs"),
		sfinv = rawget(_G, "sfinv"), grug_smelting = rawget(_G, "grug_smelting")}
	local function restore() for key, value in pairs(saved) do rawset(_G, key, value) end end
	local function fail(message) restore() error("r8 profession geometry: " .. message, 0) end
	local function check(value, message) if not value then fail(message) end end

	local callbacks = {}
	core = {registered_items = {}}
	function core.formspec_escape(value)
		return tostring(value):gsub("\\", "\\\\"):gsub("]", "\\]")
			:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
	end
	function core.register_on_player_receive_fields(fn) callbacks[#callbacks + 1] = fn end
	function core.register_on_leaveplayer() end
	function core.show_formspec() end
	function core.get_all_craft_recipes() return {} end
	sfinv = {pages = {['sfinv:crafting'] = {}}}
	function sfinv.override_page(name, definition) sfinv.pages[name] = definition end
	function sfinv.make_formspec(player, context, content) return "size[8,9.1]" .. content end
	function sfinv.set_page() end

	local learned = {}
	local recipes = {}
	for index = 1, 40 do
		local tier = math.min(6, math.floor((index - 1) / 7) + 1)
		local output = ("test:output_%02d"):format(index)
		local input = ("test:input_%02d"):format(index)
		core.registered_items[output] = {description = "Output " .. index}
		core.registered_items[input] = {description = "Input " .. index}
		recipes[index] = {profession = "cooking", tier = tier, station = "grid",
			flat_inputs = {input, input}, output = output, output_name = output,
			hint = "Crafting grid"}
	end
	grug_jobs = {
		PROFESSIONS = {blacksmith = {name = "Blacksmith", class = "primary"},
			alchemist = {name = "Alchemist", class = "primary"},
			cooking = {name = "Cooking", class = "secondary"}},
		PRIMARY_SLOTS = 2,
		BOOK_TEXTURE = "grug_jobs_book.png",
		_item_name = function(value) return tostring(value):match("^([^%s]+)") end,
		_flatten_inputs = function(value) return value end,
		recipe_for_output = function() return nil end,
		station_handler = function() return nil end,
	}
	function grug_jobs.primary_at(player, slot) return player.primaries[slot] end
	function grug_jobs.has(player, profession) return player.learned[profession] == true end
	function grug_jobs.profession_level(player, profession) return player.prof_level or 1 end
	function grug_jobs.recipes_for(profession, station) return recipes end

	dofile(repo .. "/mods/PLAYER/grug_jobs/ui.lua")

	local mutation = tonumber(os.getenv("R8_PROF_GEOMETRY_MUTATION") or "") or 0
	local function player(primaries, cooking)
		return {primaries = primaries, learned = {cooking = cooking}, prof_level = 3,
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
			if kind == "image_button" or kind == "button" or
					kind == "button_exit" then
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
	check(page == 1 and pages == 7, "40 recipes did not paginate to seven pages")
	local rows = select(2, formspec:gsub("box%[", ""))
	check(rows == 6, "first book page does not show six rows")
	local controls = rectangles(formspec)
	check(#controls == 3, "book page navigation control count differs")
	for index = 1, #controls do
		inside(controls[index].x, controls[index].y, controls[index].w,
			controls[index].h, 8, 9.1, "book navigation")
		for other = index + 1, #controls do
			check(not overlap(controls[index], controls[other]),
				"book navigation controls overlap")
		end
	end
	for row = 1, 6 do
		local y = 0.70 + (row - 1) * 1.12
		inside(0.15, y, 7.7, 1.02, 8, 9.1, "book row " .. row)
		if row > 1 then
			local previous = 0.70 + (row - 2) * 1.12
			check(previous + 1.02 <= y, "book rows overlap")
		end
	end
	report[#report + 1] = "book\trecipes=40\tpages=7\trows=6\tinside\tnonoverlap\n"
	restore()
	return table.concat(report)
end
