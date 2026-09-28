-- Disposable engine probe (playtest fix lane D, recipe-book ingredient
-- navigation). Never shipped: tools/pt_fixes/lane_d/run.sh stages it through
-- tools/luanti_headless.sh.
--
-- A headless server has no client, so each "player" is a plain table answering
-- the two accessors the book reads (name and meta). Everything else is the
-- shipped code on the real engine with the real recipe catalog: book records,
-- discovery, profession gates, make_formspec and the book's receive-fields
-- handler. core.show_formspec is intercepted for probe names only.
--
-- Two parts:
--   DUMP  - for a fixed set of players/books/recipes, a digest of the book
--           formspec with the new elements removed (cell overlays, their
--           styles, the tooltip line, Back). Emitted on the unpatched game too;
--           run.sh compares both runs line by line, proving the grid and every
--           other element are byte-identical to before.
--   CHECK - (patched game only) clickability oracle over every rendered recipe,
--           invisible-overlay shape, stick/stone on the stone pickaxe, book and
--           station switches, discovery/lock gates and the bounded Back history.

local P = "[recipe_book_probe] "
local BOOK_FORM = "grug_jobs:book"
local TOOLTIP_LINE = "\nClick to view recipe"
local failures, checks = 0, 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

--
-- Probe players and the formspec capture.
--
local shown = {}
local probe_names = {}
local show_formspec = core.show_formspec
core.show_formspec = function(name, formname, formspec)
	if probe_names[name] then
		if formname == BOOK_FORM then shown[name] = formspec end
		return true
	end
	return show_formspec(name, formname, formspec)
end

local serial = 0
local function make_player(name, setup)
	serial = serial + 1
	name = name .. "_" .. serial
	probe_names[name] = true
	local holder = ItemStack("default:stick")
	local player = {
		get_player_name = function() return name end,
		get_meta = function() return holder:get_meta() end,
		is_player = function() return true end,
	}
	local meta = player:get_meta()
	for slot, profession in ipairs(setup.primaries or {}) do
		meta:set_string("grug_jobs:primary:" .. slot, profession)
		meta:set_int("grug_jobs:level:" .. profession, 1)
	end
	for _, profession in ipairs(setup.secondaries or {}) do
		meta:set_int("grug_jobs:learned:" .. profession, 1)
		meta:set_int("grug_jobs:level:" .. profession, 1)
	end
	return player
end

local handlers = {}
local function send(player, fields)
	shown[player:get_player_name()] = nil
	for _, fn in ipairs(handlers) do
		if fn(player, BOOK_FORM, fields) then break end
	end
	return shown[player:get_player_name()]
end

--
-- Formspec parsing.
--
local function elements(fs)
	local out, buf, i, n = {}, {}, 1, #fs
	while i <= n do
		local c = fs:sub(i, i)
		if c == "\\" then
			buf[#buf + 1] = fs:sub(i, i + 1)
			i = i + 2
		else
			buf[#buf + 1] = c
			if c == "]" then
				out[#out + 1] = table.concat(buf)
				buf = {}
			end
			i = i + 1
		end
	end
	return out
end

local function split_escaped(body, sep)
	local parts, buf, i = {}, {}, 1
	while i <= #body do
		local c = body:sub(i, i)
		if c == "\\" then
			buf[#buf + 1] = body:sub(i, i + 1)
			i = i + 2
		else
			if c == sep then
				parts[#parts + 1] = table.concat(buf)
				buf = {}
			else
				buf[#buf + 1] = c
			end
			i = i + 1
		end
	end
	parts[#parts + 1] = table.concat(buf)
	return parts
end

local function unescape(value) return (value:gsub("\\(.)", "%1")) end

local function parse(fs)
	local view = {elements = elements(fs), cells = {}, overlays = {},
		styles = {}, tooltips = {}, list = {}, order = {}}
	for index, element in ipairs(view.elements) do
		local kind, body = element:match("^([%w_]+)%[(.*)%]$")
		local parts = body and split_escaped(body, ";") or {}
		if kind == "item_image" and parts[2] == "0.82,0.82" then
			view.cells[parts[1]] = unescape(parts[3])
			view.order[parts[1]] = index
			view.cell_positions = view.cell_positions or {}
			view.cell_positions[#view.cell_positions + 1] = parts[1]
		elseif kind == "item_image" and parts[1] == "5.25,6.35" then
			view.selected = unescape(parts[3])
		elseif kind == "image_button" and parts[2] == "0.82,0.82" then
			view.overlays[parts[1]] = {field = parts[4], texture = parts[3],
				raw = element, index = index}
		elseif kind == "style" then
			view.styles[parts[1]] = {raw = element, index = index}
		elseif kind == "tooltip" and parts[2] == "0.82,0.82" then
			view.tooltips[parts[1]] = unescape(parts[3])
		elseif kind == "label" and parts[1] == "0.25,0.25" then
			view.title = unescape(parts[2])
		elseif kind == "label" and parts[1] == "8.0,0.82" then
			view.page = unescape(parts[2])
		elseif kind == "label" and parts[1] == "7.48,6.55" then
			local a, k = parts[2]:match("^(%d+) / (%d+)$")
			view.alternative, view.alternatives = tonumber(a), tonumber(k)
		elseif kind == "field" and parts[3] == "grug_jobs_search" then
			view.search = unescape(parts[5] or "")
		elseif kind == "item_image_button" then
			view.list[#view.list + 1] = {item = unescape(parts[3]), field = parts[4]}
		elseif kind == "button" and parts[3] == "grug_jobs_back" then
			view.back = element
		end
	end
	view.cell_positions = view.cell_positions or {}
	return view
end

-- The formspec with every element this lane adds removed: must equal the
-- unpatched game's formspec byte for byte.
local function normalized(fs)
	local kept = {}
	for _, element in ipairs(elements(fs)) do
		if element:match("^style%[grug_jobs_cell_") or
				element:match("^image_button%[[^%]]-;grug_jobs_cell_%d+;") or
				element:match("^button%[[^%]]-;grug_jobs_back;") then
			-- added by this lane
		else
			if element:match("^tooltip%[") then
				local stripped = element:gsub(TOOLTIP_LINE:gsub("%p", "%%%0") .. "%]$", "]")
				element = stripped
			end
			kept[#kept + 1] = element
		end
	end
	return table.concat(kept)
end

--
-- Book helpers.
--
local function outputs_of(player, book, station)
	local _, _, _, outputs = grug_jobs.book_formspec(player, book, station, 1, "", nil, 1)
	return outputs or {}
end

local function set_of(list)
	local result = {}
	for _, value in ipairs(list) do result[value] = true end
	return result
end

local function openable(player)
	local books = {"general"}
	for slot = 1, grug_jobs.PRIMARY_SLOTS do
		local profession = grug_jobs.primary_at(player, slot)
		if profession then books[#books + 1] = profession end
	end
	if grug_jobs.has(player, "cooking") then books[#books + 1] = "cooking" end
	return books
end

-- Every book view to dump and sweep for a player.
local STATIONS = {"furnace", "dual_furnace", "brewing_stand", "grid", "forge",
	"tanning_rack", "tailor_bench", "carving_bench", "jewellers_bench"}
local function views_of(player)
	local views = {}
	for _, book in ipairs(openable(player)) do views[#views + 1] = {book = book} end
	for _, station in ipairs(STATIONS) do
		views[#views + 1] = {book = "station", station = station}
	end
	return views
end

local function render(player, book, station, output, alternative)
	local fs = grug_jobs.book_formspec(player, book, station, 1, "", output, alternative)
	return fs, parse(fs)
end

-- Calls fn(view, fs, parsed, output, alternative) for every recipe route the
-- view lists.
local function each_route(player, view, fn)
	for _, output in ipairs(outputs_of(player, view.book, view.station)) do
		local fs, parsed = render(player, view.book, view.station, output, 1)
		fn(fs, parsed, output, 1)
		for alternative = 2, parsed.alternatives or 1 do
			local fs2, parsed2 = render(player, view.book, view.station, output, alternative)
			fn(fs2, parsed2, output, alternative)
		end
	end
end

local SCENARIOS = {
	{label = "fresh", setup = {}},
	{label = "crafter", setup = {primaries = {"weaponsmith", "woodcarver"},
		secondaries = {"cooking"}}},
	{label = "alchemist", setup = {primaries = {"alchemist", "leatherworker"}}},
	{label = "outfitter", setup = {primaries = {"armorsmith", "tailor"}}},
	{label = "goldsmith", setup = {primaries = {"goldsmith"}}},
}

local function dump_all(patched)
	local total = {}
	for _, scenario in ipairs(SCENARIOS) do
		local player = make_player("probe_dump_" .. scenario.label, scenario.setup)
		for _, view in ipairs(views_of(player)) do
			each_route(player, view, function(fs, _, output, alternative)
				local digest = core.sha1(normalized(fs))
				total[#total + 1] = digest
				log(("DUMP %s %s %s %s %d %s"):format(scenario.label, view.book,
					view.station or "-", output, alternative, digest))
			end)
		end
	end
	log(("DUMP total routes=%d digest=%s"):format(#total,
		core.sha1(table.concat(total, "\n"))))
end

--
-- Checks (patched game only).
--
local STYLE = "style[%s;border=false;bgimg=blank.png;bgimg_hovered=blank.png;" ..
	"bgimg_pressed=blank.png]"

local stats = {routes = 0, cells = 0, clickable = 0, undiscovered = {}, locked = {}}

local function records_with_output(player, book, item)
	local result = {}
	for _, record in ipairs(grug_jobs.book_records(player, book, nil)) do
		if record.output_name == item and record.operation ~= "enchant" then
			result[#result + 1] = record
		end
	end
	return result
end

-- Independent re-implementation of the inverse-route rule over the static
-- catalog (Basics plus every profession book).
local ALL_BOOKS = {"general"}
for profession in pairs(grug_jobs.PROFESSIONS) do ALL_BOOKS[#ALL_BOOKS + 1] = profession end
table.sort(ALL_BOOKS)

local function one_ingredient(record)
	local slots = grug_jobs._flatten_inputs(record.inputs or {})
	if #slots == 0 then return nil end
	for index = 2, #slots do if slots[index] ~= slots[1] then return nil end end
	return slots[1], #slots
end

local oracle
local function inverse_oracle()
	if oracle then return oracle end
	local player = make_player("probe_oracle", {})
	local shaping, all = {}, {}
	for _, book in ipairs(ALL_BOOKS) do
		for _, record in ipairs(grug_jobs.book_records(player, book, nil)) do
			if record.operation ~= "enchant" then
				all[#all + 1] = {book = book, record = record}
				local y, slots = one_ingredient(record)
				if y then
					local key = record.output_name .. "\0" .. y
					shaping[key] = math.max(shaping[key] or 0, slots)
				end
			end
		end
	end
	local inverse, routes, dropped = {}, {}, 0
	for _, entry in ipairs(all) do
		local record = entry.record
		local y, slots = one_ingredient(record)
		local forward = y and shaping[y .. "\0" .. record.output_name]
		local item = record.output_name
		routes[item] = routes[item] or {total = 0, inverse = 0, books = {}}
		routes[item].total = routes[item].total + 1
		routes[item].books[entry.book] = true
		if forward and slots < forward then
			inverse[record] = true
			log(("inverse route [%s] %s <- %dx %s (forward route %d slots)"):format(
				entry.book, item, slots, y, forward))
			dropped = dropped + 1
			routes[item].inverse = routes[item].inverse + 1
		end
	end
	oracle = {inverse = inverse, routes = routes, dropped = dropped}
	return oracle
end

-- Same as the book: general routes need discovery, profession routes the
-- progression gate.
local function route_known(player, record)
	if record.profession == "general" then
		return grug_jobs.recipe_discovered(player, record)
	end
	return grug_jobs.recipe_progress_unlocked(player, record) == true
end

-- Items with a known, non-inverse route in the (book, station) view, and the
-- first such alternative per item in listing order.
local function navigable(player, book, station)
	local inverse = inverse_oracle().inverse
	local items, first, count = {}, {}, {}
	for _, record in ipairs(grug_jobs.book_records(player, book, station)) do
		if record.operation ~= "enchant" and route_known(player, record) then
			local item = record.output_name
			count[item] = (count[item] or 0) + 1
			if not inverse[record] and not items[item] then
				items[item] = true
				first[item] = count[item]
			end
		end
	end
	return items, first
end

local changed = {inert = {}, alternative = {}}

local function sweep(label, setup, player)
	local known = {}
	local old_known = {}
	for _, book in ipairs(openable(player)) do
		for item in pairs(set_of(outputs_of(player, book, nil))) do
			-- Enchant operations are listed by id and never appear in a cell.
			if core.registered_items[item] then old_known[item] = book end
		end
		local items, first = navigable(player, book, nil)
		for item in pairs(items) do
			known[item] = true
			if first[item] ~= 1 then
				changed.alternative[item .. " (" .. book .. " -> #" .. first[item] .. ")"] = true
			end
		end
	end
	for item, book in pairs(old_known) do
		if not known[item] then changed.inert[item] = true end
	end
	local exists_general = {}
	for _, record in ipairs(grug_jobs.book_records(player, "general", nil)) do
		exists_general[record.output_name] = true
	end
	local exists_profession = {}
	for profession in pairs(grug_jobs.PROFESSIONS) do
		for _, record in ipairs(grug_jobs.book_records(player, profession, nil)) do
			if record.operation ~= "enchant" then
				exists_profession[record.output_name] = profession
			end
		end
	end
	local bad = 0
	for _, view in ipairs(views_of(player)) do
		each_route(player, view, function(fs, parsed, output, alternative)
			stats.routes = stats.routes + 1
			local where = ("%s %s/%s %s #%d"):format(label, view.book,
				view.station or "-", output, alternative)
			local overlay_count = 0
			for _ in pairs(parsed.overlays) do overlay_count = overlay_count + 1 end
			local linked = 0
			for _, pos in ipairs(parsed.cell_positions) do
				local item = parsed.cells[pos]
				local overlay = parsed.overlays[pos]
				local tooltip = parsed.tooltips[pos] or ""
				local has_line = tooltip:sub(-#TOOLTIP_LINE) == TOOLTIP_LINE
				stats.cells = stats.cells + 1
				local ok = true
				if known[item] then
					stats.clickable = stats.clickable + 1
					linked = linked + 1
					local style = overlay and parsed.styles[overlay.field]
					ok = overlay ~= nil and overlay.texture == "blank.png" and
						overlay.raw == ("image_button[%s;0.82,0.82;blank.png;%s;;false;false]"):
							format(pos, overlay.field) and
						overlay.index > parsed.order[pos] and
						style ~= nil and style.raw == STYLE:format(overlay.field) and
						style.index < overlay.index and has_line
				else
					ok = overlay == nil and not tooltip:find("Click to view recipe", 1, true)
					local nav = inverse_oracle().routes[item]
					if exists_general[item] and not stats.undiscovered[item] and
							nav and nav.total > nav.inverse then
						stats.undiscovered[item] = {where = where, setup = setup,
							book = view.book, station = view.station, output = output,
							alternative = alternative}
					end
					if exists_profession[item] then
						stats.locked[item] = where .. " (" .. exists_profession[item] .. ")"
					end
				end
				if not ok then
					bad = bad + 1
					if bad <= 10 then
						core.log("error", P .. "cell mismatch " .. where .. " " .. pos ..
							" item=" .. item .. " known=" .. tostring(known[item] == true) ..
							" overlay=" .. tostring(overlay and overlay.raw))
					end
				end
			end
			if overlay_count ~= linked then
				bad = bad + 1
				core.log("error", P .. "stray overlay " .. where)
			end
		end)
	end
	check(bad == 0, label .. ": every cell is clickable exactly when an openable " ..
		"book lists its item, with the invisible overlay shape and tooltip line")
end

local function click_list(player, view, item)
	for _, entry in ipairs(view.list) do
		if entry.item == item then
			return parse(send(player, {[entry.field] = "", grug_jobs_search = view.search}))
		end
	end
end

local function cell_of(view, item)
	for _, pos in ipairs(view.cell_positions) do
		if view.cells[pos] == item then return pos end
	end
end

local function field_of(view, pos)
	return view.overlays[pos] and view.overlays[pos].field
end

local function list_has(view, item)
	for _, entry in ipairs(view.list) do
		if entry.item == item then return true end
	end
	return false
end

local function test_pickaxe()
	local player = make_player("probe_click", {})
	local name = player:get_player_name()
	grug_jobs.open_book(player, "general")
	local view = parse(send(player, {grug_jobs_search = "pick", grug_jobs_do_search = ""}))
	view = click_list(player, view, "default:pick_stone")
	check(view and view.selected == "default:pick_stone",
		"search 'pick' and select the stone pickaxe")
	if not view then return end
	local before = view
	local stick = cell_of(view, "default:stick")
	check(stick ~= nil and field_of(view, stick) ~= nil,
		"stone pickaxe: the stick cell is clickable")
	local stone
	for _, pos in ipairs(view.cell_positions) do
		if view.cells[pos] ~= "default:stick" then stone = pos end
	end
	log("stone cell shows " .. tostring(stone and view.cells[stone]))
	check(stone ~= nil and field_of(view, stone) == nil,
		"stone pickaxe: the stone cell is not clickable")
	check(before.back == nil, "no Back button before any ingredient jump")
	-- Clicking a non-clickable cell does nothing (no field exists; a forged
	-- field for it is ignored too).
	-- Cell 1 of the stone pickaxe is a stone cell (slots 1-3 are stone).
	check(field_of(view, view.cell_positions[1]) == nil and
		send(player, {grug_jobs_cell_1 = "", grug_jobs_search = "pick"}) == nil,
		"a forged click on the stone cell is ignored (no redraw)")
	if not stick then return end
	local after = parse(send(player, {[field_of(before, stick)] = "",
		grug_jobs_search = "pick"}))
	local _, stick_first = navigable(player, "general", nil)
	check(after.selected == "default:stick" and after.title == "Basics" and
		after.search == "" and after.alternative == stick_first["default:stick"] and
		list_has(after, "default:stick"),
		"click stick: Basics shows the stick recipe, search cleared, alternative 1, " ..
		"page " .. tostring(after.page) .. " lists the stick")
	check(after.back ~= nil, "Back button appears after the jump")
	local back = parse(send(player, {grug_jobs_back = "", grug_jobs_search = ""}))
	check(back.selected == "default:pick_stone" and back.title == "Basics" and
		back.search == "pick" and back.page == before.page and
		back.alternative == before.alternative and back.back == nil,
		"Back restores book, page, search, output and alternative")
	check(normalized(shown[name]) == normalized(
		grug_jobs.book_formspec(player, "general", nil, 1, "pick", "default:pick_stone", 1)),
		"restored view is the same formspec as the original stone pickaxe view")
	-- Bounded history: 25 jumps keep the latest 20.
	for _ = 1, 25 do
		local v = parse(send(player, {grug_jobs_search = "pick", grug_jobs_do_search = ""}))
		v = click_list(player, v, "default:pick_stone")
		local pos = cell_of(v, "default:stick")
		send(player, {[field_of(v, pos)] = "", grug_jobs_search = "pick"})
	end
	local backs = 0
	local current = parse(shown[name])
	while current.back and backs < 50 do
		current = parse(send(player, {grug_jobs_back = "", grug_jobs_search = ""}))
		backs = backs + 1
	end
	check(backs == 20, "history is bounded to 20 entries (" .. backs .. " Back presses)")
end

local function title_of(book, station)
	local fs = grug_jobs.book_formspec(make_player("probe_title", {}), book, station, 1, "", nil, 1)
	return parse(fs).title
end

-- Find a clickable cell in `view` whose item the current view does not list;
-- click it and expect the first openable book that lists the item, unfiltered.
local function test_switch(label, setup, book, station, need_stay)
	local player = make_player("probe_switch_" .. label, setup)
	local listed_here = navigable(player, book, station)
	local owner_of = {}
	for _, candidate in ipairs(openable(player)) do
		for item in pairs((navigable(player, candidate, nil))) do
			owner_of[item] = owner_of[item] or candidate
		end
	end
	local found_switch, found_stay
	for _, output in ipairs(outputs_of(player, book, station)) do
		local _, view = render(player, book, station, output, 1)
		-- Enchant operations are listed under their id; the list button shows
		-- the preview item, so only item outputs can be selected by click here.
		local positions = core.registered_items[output] and view.cell_positions or {}
		for _, pos in ipairs(positions) do
			local item = view.cells[pos]
			if field_of(view, pos) then
				if not listed_here[item] and not found_switch then
					found_switch = {output = output, pos = pos, item = item}
				elseif listed_here[item] and not found_stay then
					found_stay = {output = output, pos = pos, item = item}
				end
			end
		end
		if found_switch and found_stay then break end
	end
	local home = title_of(book, station)
	for kind, case in pairs({switch = found_switch, stay = found_stay}) do
		grug_jobs.open_book(player, book, station)
		local start = parse(send(player, {grug_jobs_search = "", grug_jobs_do_search = ""}))
		-- Select the host recipe through the real list/page controls.
		local view = start
		for _ = 1, 50 do
			if list_has(view, case.output) then break end
			view = parse(send(player, {grug_jobs_next = "", grug_jobs_search = ""}))
		end
		view = click_list(player, view, case.output)
		local field = view and field_of(view, case.pos)
		local after = field and parse(send(player, {[field] = "", grug_jobs_search = ""}))
		local expected = kind == "stay" and home or
			title_of(owner_of[case.item], nil)
		local _, first
		if kind == "stay" then _, first = navigable(player, book, station)
		else _, first = navigable(player, owner_of[case.item], nil) end
		check(after ~= nil and after.selected == case.item and after.title == expected and
			after.alternative == first[case.item] and list_has(after, case.item),
			("%s %s: %s -> %s opens %q (got %q)"):format(label, kind, case.output,
				case.item, tostring(expected), tostring(after and after.title)))
		local back = after and parse(send(player, {grug_jobs_back = "", grug_jobs_search = ""}))
		check(back ~= nil and back.title == home and back.selected == case.output,
			label .. " " .. kind .. ": Back returns to " .. home)
	end
	check(found_switch ~= nil, label .. ": found an ingredient that switches books")
	if need_stay then
		check(found_stay ~= nil, label .. ": found an ingredient that keeps the station view")
	elseif not found_stay then
		log(label .. ": no same-view ingredient found (informational)")
	end
end

-- The inverse-route rule on concrete cells.
local function test_inverse()
	local player = make_player("probe_inverse", {})
	local _, view = render(player, "general", nil, "default:pick_stone", 1)
	local stone = view.cell_positions[1]
	check(view.cells[stone] == "default:cobble", "stone pickaxe stone cell shows cobble")
	grug_jobs.mark_seen(player, {"stairs:slab_cobble", "stairs:stair_cobble"})
	local cobble_listed = set_of(outputs_of(player, "general", nil))["default:cobble"]
	check(cobble_listed == true, "slab/stair -> cobble routes are listed after discovery")
	local _, cobble = render(player, "general", nil, "default:cobble", 1)
	check(cobble.selected == "default:cobble" and (cobble.alternatives or 0) >= 1,
		"the cobble recipe is browsable (" .. tostring(cobble.alternatives) .. " routes)")
	_, view = render(player, "general", nil, "default:pick_stone", 1)
	check(field_of(view, stone) == nil and
		not (view.tooltips[stone] or ""):find("Click to view recipe", 1, true),
		"cobble stays inert after slab_cobble and stair_cobble are discovered")
	-- A bar keeps a furnace route: the jump lands on it, not on block -> bar.
	grug_jobs.open_book(player, "general")
	local list = parse(send(player, {grug_jobs_search = "pick_bronze", grug_jobs_do_search = ""}))
	local host = click_list(player, list, "default:pick_bronze")
	local bar = host and cell_of(host, "grug_materials:bronze_bar")
	check(bar ~= nil and field_of(host, bar) ~= nil, "bronze pickaxe: the bronze bar is clickable")
	if bar then
		local after = parse(send(player, {[field_of(host, bar)] = "", grug_jobs_search = ""}))
		local inputs = {}
		for _, pos in ipairs(after.cell_positions) do inputs[#inputs + 1] = after.cells[pos] end
		check(after.selected == "grug_materials:bronze_bar" and
			not table.concat(inputs, ","):find("bronze_block", 1, true),
			"bronze bar jump shows a smelting route, not the block unpacking (" ..
			table.concat(inputs, ",") .. ")")
	end
	-- Planks: tree -> planks keeps wood clickable; the jump avoids slabs/stairs.
	_, view = render(player, "general", nil, "default:stick", 1)
	local wood = view.cell_positions[1]
	check(wood ~= nil and field_of(view, wood) ~= nil,
		"stick recipe: the planks cell (" .. tostring(wood and view.cells[wood]) .. ") is clickable")
	if wood then
		grug_jobs.open_book(player, "general")
		list = parse(send(player, {grug_jobs_search = "default:stick", grug_jobs_do_search = ""}))
		host = click_list(player, list, "default:stick")
		local after = host and parse(send(player, {[field_of(host, wood)] = "",
			grug_jobs_search = ""}))
		local inputs = {}
		for _, pos in ipairs(after and after.cell_positions or {}) do
			inputs[#inputs + 1] = after.cells[pos]
		end
		local text = table.concat(inputs, ",")
		check(after ~= nil and after.selected == view.cells[wood] and
			not text:find("slab", 1, true) and not text:find("stair", 1, true),
			"planks jump shows the tree route (" .. text .. ")")
	end
end

local function report_rule()
	local data = inverse_oracle()
	local inert_everywhere = {}
	for item, info in pairs(data.routes) do
		if info.inverse > 0 and info.inverse == info.total then
			inert_everywhere[#inert_everywhere + 1] = item
		end
	end
	table.sort(inert_everywhere)
	log(("inverse routes dropped from navigation: %d"):format(data.dropped))
	log("items whose every route is inverse: " .. table.concat(inert_everywhere, " "))
	local list = {}
	for item in pairs(changed.inert) do list[#list + 1] = item end
	table.sort(list)
	log("click target lost (visible in some scenario, now inert): " ..
		(#list > 0 and table.concat(list, " ") or "none"))
	list = {}
	for item in pairs(changed.alternative) do list[#list + 1] = item end
	table.sort(list)
	log("click lands on a later alternative: " ..
		(#list > 0 and table.concat(list, " ") or "none"))
end

-- Discovery gate: an undiscovered Basics ingredient becomes clickable once its
-- main material is seen.
local function test_discovery()
	for item, case in pairs(stats.undiscovered) do
		local player = make_player("probe_disc", case.setup)
		local material
		for _, record in ipairs(records_with_output(player, "general", item)) do
			local declaration = record.basics_presentation
			if declaration and type(declaration.main_material) == "string" and
					not declaration.main_material:match("^group:") then
				material = declaration.main_material
				break
			end
		end
		if material then
			local _, view = render(player, case.book, case.station, case.output,
				case.alternative)
			local pos = cell_of(view, item)
			check(view.selected == case.output and pos ~= nil and
				field_of(view, pos) == nil,
				"undiscovered " .. item .. " is not clickable in " .. case.where)
			grug_jobs.mark_seen(player, material)
			_, view = render(player, case.book, case.station, case.output,
				case.alternative)
			check(pos ~= nil and field_of(view, pos) ~= nil,
				item .. " becomes clickable after seeing " .. material)
			return
		end
	end
	check(false, "found an undiscovered ingredient with a concrete main material")
end

-- Lock gate: the shipped progression authority (grug_jobs.recipe_progress_unlocked,
-- the same check that refuses above-tier crafts) is forced to refuse every
-- route producing one clickable profession ingredient; the cell must turn
-- inert while its host recipe stays listed, and clickable again afterwards.
local function test_locked()
	local player = make_player("probe_lock", {primaries = {"weaponsmith"}})
	local profession_outputs = set_of(outputs_of(player, "weaponsmith", nil))
	local case
	for _, output in ipairs(outputs_of(player, "weaponsmith", nil)) do
		local _, view = render(player, "weaponsmith", nil, output, 1)
		for _, pos in ipairs(view.cell_positions) do
			local item = view.cells[pos]
			-- Hosts may be enchant operations (rendered by their list key).
			if field_of(view, pos) and profession_outputs[item] and item ~= output and
					#records_with_output(player, "general", item) == 0 then
				case = {output = output, pos = pos, item = item}
				break
			end
		end
		if case then break end
	end
	check(case ~= nil, "found a weaponsmith ingredient made only by weaponsmith recipes")
	if not case then return end
	local original = grug_jobs.recipe_progress_unlocked
	grug_jobs.recipe_progress_unlocked = function(p, recipe)
		if recipe and recipe.output_name == case.item then
			return false, "Weaponsmith tier 6 required."
		end
		return original(p, recipe)
	end
	local ok, err = pcall(function()
		local _, view = render(player, "weaponsmith", nil, case.output, 1)
		check(view.cells[case.pos] == case.item and
			field_of(view, case.pos) == nil and
			not (view.tooltips[case.pos] or ""):find("Click to view recipe", 1, true),
			"locked " .. case.item .. " is not clickable in " .. case.output)
	end)
	grug_jobs.recipe_progress_unlocked = original
	check(ok, "locked scenario ran without error " .. tostring(err or ""))
	local _, view = render(player, "weaponsmith", nil, case.output, 1)
	check(field_of(view, case.pos) ~= nil, case.item .. " is clickable again once unlocked")
end

local function run_all()
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		local origin = core.callback_origins and core.callback_origins[fn]
		if origin and origin.mod == "grug_jobs" then handlers[#handlers + 1] = fn end
	end
	-- Patched build? Any overlay in the fresh Basics book tells.
	local patched = false
	local probe = make_player("probe_detect", {})
	for _, output in ipairs(outputs_of(probe, "general", nil)) do
		local fs = grug_jobs.book_formspec(probe, "general", nil, 1, "", output, 1)
		if fs:find("grug_jobs_cell_", 1, true) then patched = true break end
	end
	dump_all(patched)
	if not patched then
		log("RESULT BASELINE (no ingredient links in this build)")
		core.request_shutdown("recipe book probe done", false, 0)
		return
	end
	for _, scenario in ipairs(SCENARIOS) do
		sweep(scenario.label, scenario.setup,
			make_player("probe_sweep_" .. scenario.label, scenario.setup))
	end
	log(("sweep routes=%d cells=%d clickable=%d"):format(stats.routes, stats.cells,
		stats.clickable))
	local u, l = 0, 0
	for item, case in pairs(stats.undiscovered) do
		u = u + 1
		if u <= 5 then log("undiscovered not clickable: " .. item .. " in " .. case.where) end
	end
	for item, where in pairs(stats.locked) do
		l = l + 1
		if l <= 5 then log("locked not clickable: " .. item .. " in " .. where) end
	end
	check(u > 0, "sweep saw undiscovered ingredients with a recipe (" .. u .. ")")
	log("sweep saw " .. l .. " naturally locked profession ingredients " ..
		"(informational; the lock gate is forced in test_locked)")
	report_rule()
	test_pickaxe()
	test_inverse()
	test_discovery()
	test_locked()
	test_switch("weaponsmith", {primaries = {"weaponsmith"}}, "weaponsmith", nil)
	test_switch("forge", {primaries = {"weaponsmith"}}, "station", "forge")
	test_switch("grid", {}, "station", "grid", true)
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("recipe book probe done", false, 0)
end

core.after(1, function()
	local ok, err = xpcall(run_all, debug.traceback)
	if not ok then
		core.log("error", P .. "FAIL probe crashed: " .. tostring(err))
		log(("RESULT FAIL checks=%d failures=%d"):format(checks, failures + 1))
		core.request_shutdown("recipe book probe crashed", false, 0)
	end
end)
