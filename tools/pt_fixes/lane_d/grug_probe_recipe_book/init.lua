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
--           styles, the tooltip line, Back) and, since Round 41, every element
--           inside a slot that accepts several items (a group token with two or
--           more distinct item labels: its icons, targets, tooltips and "+N").
--           Emitted on the baseline game too; run.sh compares both runs line by
--           line, proving the grid and every other element are byte-identical
--           to the baseline (BASE_REV, the Round 41 base by default).
--   CHECK - (current game only) clickability oracle over every rendered icon
--           (single cells and the small icons of multi-item slots),
--           invisible-overlay shape, the multi-item slot layouts against an
--           independent group oracle (2 / 3 / 4 / 3 + "+N" icons in label
--           order, the complete list in every tooltip of the slot, "+N" never
--           clickable), stick/stone on the stone pickaxe, book and station
--           switches, a jump and Back from a small icon, discovery/lock gates
--           and the bounded Back history.

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
	-- `veteran` (Round 41): the highest character level and tier 6 in every
	-- profession, so no recipe is held back by a tier.
	local level = setup.veteran and 6 or 1
	if setup.veteran then meta:set_int("grug_xp:xp", 1000000000) end
	for slot, profession in ipairs(setup.primaries or {}) do
		meta:set_string("grug_jobs:primary:" .. slot, profession)
		meta:set_int("grug_jobs:level:" .. profession, level)
	end
	for _, profession in ipairs(setup.secondaries or {}) do
		meta:set_int("grug_jobs:learned:" .. profession, 1)
		meta:set_int("grug_jobs:level:" .. profession, level)
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

-- The ingredient grid (ui.lua append_recipe) and the small icons of a slot
-- that accepts several items (Round 41): 0.37 icons centred in 0.41 quarters.
local CELL_X, CELL_Y, CELL_STEP = 1.25, 5.65, 0.9
local QUARTER, ICON = 0.41, 0.37
local INSET = (QUARTER - ICON) / 2

local function xy(text)
	local x, y = (text or ""):match("^([%d.]+),([%d.]+)$")
	return tonumber(x), tonumber(y)
end

-- The "x,y" of the grid cell containing a point.
local function cell_at(x, y)
	local column = math.floor((x - CELL_X) / CELL_STEP + 1e-6)
	local row = math.floor((y - CELL_Y) / CELL_STEP + 1e-6)
	return ("%.2f,%.2f"):format(CELL_X + column * CELL_STEP, CELL_Y + row * CELL_STEP)
end

local function near(a, b) return a and b and math.abs(a - b) < 1e-3 end

-- The entry of `list` ({x, y, ...}) at (x, y), or nil.
local function at(list, x, y)
	for _, entry in ipairs(list) do
		if near(entry.x, x) and near(entry.y, y) then return entry end
	end
end

local function parse(fs)
	local view = {elements = elements(fs), cells = {}, overlays = {},
		styles = {}, tooltips = {}, list = {}, order = {},
		-- Round 41: multi-item slots by cell "x,y", their icons, the 0.41
		-- targets and tooltips.
		slots = {}, slot_cells = {}, quarter_overlays = {}, quarter_tooltips = {}}
	local function slot(cell)
		if not view.slots[cell] then
			view.slots[cell] = {cell = cell, icons = {}}
			view.slot_cells[#view.slot_cells + 1] = cell
		end
		return view.slots[cell]
	end
	for index, element in ipairs(view.elements) do
		local kind, body = element:match("^([%w_]+)%[(.*)%]$")
		local parts = body and split_escaped(body, ";") or {}
		if kind == "item_image" and parts[2] == "0.82,0.82" then
			view.cells[parts[1]] = unescape(parts[3])
			view.order[parts[1]] = index
			view.cell_positions = view.cell_positions or {}
			view.cell_positions[#view.cell_positions + 1] = parts[1]
		elseif kind == "item_image" and parts[2] == ("%.2f,%.2f"):format(ICON, ICON) then
			local x, y = xy(parts[1])
			local icons = slot(cell_at(x, y)).icons
			icons[#icons + 1] = {x = x - INSET, y = y - INSET, item = unescape(parts[3]),
				index = index, raw = element}
		elseif kind == "image_button" and parts[2] == ("%.2f,%.2f"):format(QUARTER, QUARTER) then
			local x, y = xy(parts[1])
			view.quarter_overlays[#view.quarter_overlays + 1] = {x = x, y = y,
				field = parts[4], texture = parts[3], raw = element, index = index,
				pos = parts[1]}
		elseif kind == "tooltip" and parts[2] == ("%.2f,%.2f"):format(QUARTER, QUARTER) then
			local x, y = xy(parts[1])
			view.quarter_tooltips[#view.quarter_tooltips + 1] = {x = x, y = y,
				text = unescape(parts[3])}
		elseif kind == "label" and (parts[2] or ""):match("^%+%d+$") then
			local x, y = xy(parts[1])
			if x and x >= CELL_X and y >= CELL_Y and y < CELL_Y + 3 * CELL_STEP then
				local entry = slot(cell_at(x, y))
				entry.more, entry.more_x, entry.more_y = tonumber(parts[2]:sub(2)), x, y
			end
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

-- Whether an element's first position lies inside one of `cells` ("x,y" of
-- 0.82 grid cells).
local function inside_cells(element, cells)
	if not cells or #cells == 0 or element:match("^box%[") then return false end
	local x, y = element:match("^[%w_]+%[([%d.]+),([%d.]+)[;%]]")
	x, y = tonumber(x), tonumber(y)
	if not x then return false end
	for _, cell in ipairs(cells) do
		local cx, cy = xy(cell)
		if x >= cx - 1e-6 and x < cx + 0.82 and y >= cy - 1e-6 and y < cy + 0.82 then
			return true
		end
	end
	return false
end

-- The formspec with every element the navigation lane added removed, and
-- every element inside `cells` (the multi-item slots, Round 41) except their
-- background boxes: must equal the baseline game's formspec byte for byte.
local function normalized(fs, cells)
	local kept = {}
	for _, element in ipairs(elements(fs)) do
		if element:match("^style%[grug_jobs_cell_") or
				element:match("^image_button%[[^%]]-;grug_jobs_cell_[%d_]+;") or
				element:match("^button%[[^%]]-;grug_jobs_back;") or
				element:match("^style_type%[label;font_size=") or
				inside_cells(element, cells) then
			-- added by the navigation lane, or a multi-item slot (Round 41)
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

-- Independent group oracle (Round 41): the items a group token accepts, one
-- {item, label} per distinct first description line (its alphabetically first
-- item), in label order.
local group_oracle_cache = {}
local function group_entries(token)
	if group_oracle_cache[token] then return group_oracle_cache[token] end
	local groups = token:match("^group:(.+)$")
	local first = {}
	for name, def in pairs(core.registered_items) do
		local all = true
		for group in groups:gmatch("[^,]+") do
			if core.get_item_group(name, group) <= 0 then all = false break end
		end
		if all then
			local label = def.description and def.description ~= "" and def.description or name
			label = label:match("^[^\n]+") or name
			if not first[label] or name < first[label] then first[label] = name end
		end
	end
	local labels = {}
	for label in pairs(first) do labels[#labels + 1] = label end
	table.sort(labels)
	local entries = {}
	for index, label in ipairs(labels) do entries[index] = {item = first[label], label = label} end
	group_oracle_cache[token] = entries
	return entries
end

-- The route a (book, station, output, alternative) view shows, rebuilt from
-- the public records with the book's listing rule.
local function route_of(player, book, station, output, alternative)
	local seen = 0
	for _, record in ipairs(grug_jobs.book_records(player, book, station)) do
		local key = record.station_operation and record.id or record.output_name
		local listed
		if record.profession == "general" then
			listed = grug_jobs.recipe_discovered(player, record)
		elseif book == "station" then
			listed = grug_jobs.recipe_progress_unlocked(player, record) == true
		else
			listed = true
		end
		if key == output and listed then
			seen = seen + 1
			if seen == alternative then return record end
		end
	end
end

-- The route's cells whose group token accepts two or more distinct items:
-- {cell = "x,y", token, entries}, in cell order.
local function multi_slots(route)
	local result = {}
	if not route then return result end
	for _, cell in ipairs(grug_jobs._book_recipe_cells(route)) do
		if cell.token:match("^group:") then
			local entries = group_entries(cell.token)
			if #entries > 1 then
				result[#result + 1] = {cell = ("%.2f,%.2f"):format(
					CELL_X + (cell.column - 1) * CELL_STEP, CELL_Y + (cell.row - 1) * CELL_STEP),
					token = cell.token, entries = entries}
			end
		end
	end
	return result
end

local function multi_cells(route)
	local cells = {}
	for _, slot in ipairs(multi_slots(route)) do cells[#cells + 1] = slot.cell end
	return cells
end

local function openable(player)
	local books = {"general"}
	for slot = 1, grug_jobs.PRIMARY_SLOTS do
		local profession = grug_jobs.primary_at(player, slot)
		if profession then books[#books + 1] = profession end
	end
	for _, profession in ipairs(grug_jobs.SECONDARY_PROFESSIONS) do
		if grug_jobs.has(player, profession) then books[#books + 1] = profession end
	end
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
	{label = "alchemist", setup = {primaries = {"leatherworker"},
		secondaries = {"alchemist"}}},
	{label = "outfitter", setup = {primaries = {"armorsmith", "tailor"}}},
	{label = "goldsmith", setup = {primaries = {"goldsmith"}}},
}

local function dump_all(patched)
	local total = {}
	for _, scenario in ipairs(SCENARIOS) do
		local player = make_player("probe_dump_" .. scenario.label, scenario.setup)
		for _, view in ipairs(views_of(player)) do
			each_route(player, view, function(fs, _, output, alternative)
				local digest = core.sha1(normalized(fs, multi_cells(route_of(player,
					view.book, view.station, output, alternative))))
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

local stats = {routes = 0, cells = 0, clickable = 0, undiscovered = {}, locked = {},
	icons = 0, icon_clickable = 0, slot_sizes = {}}
-- Icon quarters inside a cell per item count (an independent copy of ui.lua's
-- layout; more than four items use the first three places of four).
local SLOT_PLACES = {
	[2] = {{0, 0.205}, {0.41, 0.205}},
	[3] = {{0, 0}, {0.41, 0}, {0.205, 0.41}},
	[4] = {{0, 0}, {0.41, 0}, {0, 0.41}, {0.41, 0.41}},
}

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
	local function mismatch(text)
		bad = bad + 1
		if bad <= 10 then core.log("error", P .. text) end
	end
	for _, view in ipairs(views_of(player)) do
		each_route(player, view, function(fs, parsed, output, alternative)
			stats.routes = stats.routes + 1
			local where = ("%s %s/%s %s #%d"):format(label, view.book,
				view.station or "-", output, alternative)
			-- An inert ingredient feeds the discovery and lock cases below.
			local function inert(item)
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
			local overlay_count = #parsed.quarter_overlays
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
					inert(item)
				end
				if not ok then
					mismatch("cell mismatch " .. where .. " " .. pos ..
						" item=" .. item .. " known=" .. tostring(known[item] == true) ..
						" overlay=" .. tostring(overlay and overlay.raw))
				end
			end
			-- Round 41: the multi-item slots against the group oracle.
			local route = route_of(player, view.book, view.station, output, alternative)
			if not route then mismatch("no route for " .. where) end
			local expected = multi_slots(route)
			if #expected ~= #parsed.slot_cells then
				mismatch(("slot count %s: %d expected, %d drawn"):format(where,
					#expected, #parsed.slot_cells))
			end
			for _, want in ipairs(expected) do
				local got = parsed.slots[want.cell]
				local n = #want.entries
				local shown = n > 4 and 3 or n
				stats.slot_sizes[n] = (stats.slot_sizes[n] or 0) + 1
				local names = {}
				for index, entry in ipairs(want.entries) do names[index] = entry.label end
				local list = table.concat(names, " or ")
				local cell_tip = parsed.tooltips[want.cell]
				if not got or #got.icons ~= shown or got.more ~= (n > 4 and n - 3 or nil) or
						parsed.cells[want.cell] ~= nil then
					mismatch(("slot layout %s %s (%s, %d items): %s icons, more %s"):format(
						where, want.cell, want.token, n, got and #got.icons or "no",
						tostring(got and got.more)))
				elseif not cell_tip or (cell_tip:gsub("\n", " ")) ~= list then
					mismatch(("slot tooltip %s %s: %q, expected the list %q"):format(where,
						want.cell, tostring(cell_tip), list))
				else
					local cx, cy = xy(want.cell)
					local places = SLOT_PLACES[n > 4 and 4 or n]
					for index = 1, shown do
						local icon = got.icons[index]
						local qx, qy = cx + places[index][1], cy + places[index][2]
						local overlay = at(parsed.quarter_overlays, qx, qy)
						local tip = at(parsed.quarter_tooltips, qx, qy)
						stats.cells = stats.cells + 1
						stats.icons = stats.icons + 1
						local ok = icon.item == want.entries[index].item and
							near(icon.x, qx) and near(icon.y, qy)
						if known[icon.item] then
							stats.clickable = stats.clickable + 1
							stats.icon_clickable = stats.icon_clickable + 1
							linked = linked + 1
							local style = overlay and parsed.styles[overlay.field]
							ok = ok and overlay ~= nil and overlay.texture == "blank.png" and
								overlay.raw == ("image_button[%s;0.41,0.41;blank.png;%s;;false;false]"):
									format(overlay.pos, overlay.field) and
								overlay.field:match("^grug_jobs_cell_%d+_" .. index .. "$") ~= nil and
								overlay.index > icon.index and
								style ~= nil and style.raw == STYLE:format(overlay.field) and
								style.index < overlay.index and
								tip ~= nil and tip.text == cell_tip .. TOOLTIP_LINE
						else
							ok = ok and overlay == nil and tip == nil
							inert(icon.item)
						end
						if not ok then
							mismatch(("slot icon %s %s #%d item=%s expected=%s known=%s overlay=%s"):format(
								where, want.cell, index, icon.item, want.entries[index].item,
								tostring(known[icon.item] == true), tostring(overlay and overlay.raw)))
						end
					end
					if n > 4 and at(parsed.quarter_overlays, cx + QUARTER, cy + QUARTER) then
						mismatch("a \"+N\" marker is clickable in " .. where)
					end
				end
			end
			if overlay_count ~= linked then
				mismatch("stray overlay " .. where)
			end
		end)
	end
	check(bad == 0, label .. ": every cell and every icon of a multi-item slot is " ..
		"clickable exactly when an openable book lists its item, with the invisible " ..
		"overlay shape and tooltip line; every multi-item slot has its layout and " ..
		"the complete list in each tooltip")
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

-- Round 41: the small icon of a multi-item slot showing `item`, and its field.
local function icon_of(view, item)
	for _, cell in ipairs(view.slot_cells) do
		for _, icon in ipairs(view.slots[cell].icons) do
			if icon.item == item then return icon end
		end
	end
end

local function icon_field(view, icon)
	local overlay = icon and at(view.quarter_overlays, icon.x, icon.y)
	return overlay and overlay.field
end

-- Every ingredient a view draws: single cells and small icons.
local function drawn_items(view)
	local items = {}
	for _, pos in ipairs(view.cell_positions) do items[#items + 1] = view.cells[pos] end
	for _, cell in ipairs(view.slot_cells) do
		for _, icon in ipairs(view.slots[cell].icons) do items[#items + 1] = icon.item end
	end
	return items
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
	view = click_list(player, view, "grug_materials:pick_stone")
	check(view and view.selected == "grug_materials:pick_stone",
		"search 'pick' and select the stone pickaxe")
	if not view then return end
	local before = view
	local stick = cell_of(view, "default:stick")
	check(stick ~= nil and field_of(view, stick) ~= nil,
		"stone pickaxe: the stick cell is clickable")
	-- Round 41: the stone cells are group:stone, a slot of many items: three
	-- small icons and a "+N" marker.
	local stone = view.slots[view.slot_cells[1] or ""]
	local stone_items = {}
	for _, icon in ipairs(stone and stone.icons or {}) do stone_items[#stone_items + 1] = icon.item end
	log("stone slot shows " .. table.concat(stone_items, " ") .. " +" ..
		tostring(stone and stone.more))
	check(stone ~= nil and #stone.icons == 3 and (stone.more or 0) > 0 and
		#view.slot_cells == 3, "stone pickaxe: three stone slots of three icons and \"+N\"")
	local cobble = icon_of(view, "default:cobble")
	if cobble then
		check(icon_field(view, cobble) == nil, "stone pickaxe: the cobble icon is not clickable")
	else
		log("stone pickaxe: cobble is not among the three icons (informational)")
	end
	check(before.back == nil, "no Back button before any ingredient jump")
	-- Clicking a non-clickable cell does nothing (no field exists; a forged
	-- field for it is ignored too). Cell 1 of the stone pickaxe is a stone
	-- slot (slots 1-3 are stone); its icons answer to grug_jobs_cell_1_<n>.
	local inert_icon
	for index, icon in ipairs(stone and stone.icons or {}) do
		if not icon_field(view, icon) then inert_icon = index break end
	end
	check(send(player, {grug_jobs_cell_1 = "", grug_jobs_search = "pick"}) == nil,
		"a forged click on the stone slot is ignored (no redraw)")
	if inert_icon then
		check(send(player, {["grug_jobs_cell_1_" .. inert_icon] = "",
			grug_jobs_search = "pick"}) == nil,
			"a forged click on an inert stone icon is ignored (no redraw)")
	end
	check(send(player, {grug_jobs_cell_1_4 = "", grug_jobs_search = "pick"}) == nil,
		"a forged click on the \"+N\" place is ignored (no redraw)")
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
	check(back.selected == "grug_materials:pick_stone" and back.title == "Basics" and
		back.search == "pick" and back.page == before.page and
		back.alternative == before.alternative and back.back == nil,
		"Back restores book, page, search, output and alternative")
	check(normalized(shown[name]) == normalized((
		grug_jobs.book_formspec(player, "general", nil, 1, "pick", "grug_materials:pick_stone", 1))),
		"restored view is the same formspec as the original stone pickaxe view")
	-- Bounded history: 25 jumps keep the latest 20.
	for _ = 1, 25 do
		local v = parse(send(player, {grug_jobs_search = "pick", grug_jobs_do_search = ""}))
		v = click_list(player, v, "grug_materials:pick_stone")
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
-- Whether the (book, station) view offers `output` through a live list
-- button (a greyed, locked output cannot be selected by a click).
local function host_craftable(player, book, station, output)
	for _, record in ipairs(grug_jobs.book_records(player, book, station)) do
		if record.output_name == output and route_known(player, record) then return true end
	end
	return false
end

-- Returns whether a switching ingredient was found; `optional` leaves a
-- missing one unchecked (the caller tries several views).
local function test_switch(label, setup, book, station, need_stay, optional)
	local player = make_player("probe_switch_" .. label, setup)
	if setup.see_all then
		-- Discovery is tested elsewhere: here every Basics route is revealed, so
		-- a station's bars and other furnace products are clickable.
		local names = {}
		for name in pairs(core.registered_items) do names[#names + 1] = name end
		grug_jobs.mark_seen(player, names)
	end
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
		local positions = core.registered_items[output] and
			host_craftable(player, book, station, output) and view.cell_positions or {}
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
	if not optional then
		check(found_switch ~= nil, label .. ": found an ingredient that switches books")
	end
	if need_stay then
		check(found_stay ~= nil, label .. ": found an ingredient that keeps the station view")
	elseif not found_stay then
		log(label .. ": no same-view ingredient found (informational)")
	end
	return found_switch ~= nil
end

-- The inverse-route rule on concrete cells.
local function test_inverse()
	local player = make_player("probe_inverse", {})
	grug_jobs.mark_seen(player, {"stairs:slab_cobble", "stairs:stair_cobble"})
	local cobble_listed = set_of(outputs_of(player, "general", nil))["default:cobble"]
	check(cobble_listed == true, "slab/stair -> cobble routes are listed after discovery")
	local _, cobble = render(player, "general", nil, "default:cobble", 1)
	check(cobble.selected == "default:cobble" and (cobble.alternatives or 0) >= 1,
		"the cobble recipe is browsable (" .. tostring(cobble.alternatives) .. " routes)")
	-- Round 41: cobble shows as an icon of the stone pickaxe's stone slot (if
	-- among its first three) and as the single cell of the cobble slab.
	local _, view = render(player, "general", nil, "grug_materials:pick_stone", 1)
	local icon = icon_of(view, "default:cobble")
	if icon then
		check(icon_field(view, icon) == nil,
			"the cobble icon stays inert after slab_cobble and stair_cobble are discovered")
	end
	grug_jobs.mark_seen(player, {"default:cobble"})
	_, view = render(player, "general", nil, "stairs:slab_cobble", 1)
	local cell = view.selected == "stairs:slab_cobble" and cell_of(view, "default:cobble")
	if cell then
		check(field_of(view, cell) == nil and
			not (view.tooltips[cell] or ""):find("Click to view recipe", 1, true),
			"the cobble cell of the cobble slab stays inert after slab_cobble and stair_cobble are discovered")
	else
		log("cobble slab route not listed or without a cobble cell (informational)")
	end
	check(icon ~= nil or cell, "cobble was drawn somewhere to check the inverse rule on")
	-- A bar keeps a furnace route: the jump lands on it, not on block -> bar.
	grug_jobs.open_book(player, "general")
	local list = parse(send(player, {grug_jobs_search = "pick_bronze", grug_jobs_do_search = ""}))
	local host = click_list(player, list, "grug_materials:pick_bronze")
	local bar = host and cell_of(host, "grug_materials:bronze_bar")
	check(bar ~= nil and field_of(host, bar) ~= nil, "bronze pickaxe: the bronze bar is clickable")
	if bar then
		local after = parse(send(player, {[field_of(host, bar)] = "", grug_jobs_search = ""}))
		local inputs = drawn_items(after)
		check(after.selected == "grug_materials:bronze_bar" and
			not table.concat(inputs, ","):find("bronze_block", 1, true),
			"bronze bar jump shows a smelting route, not the block unpacking (" ..
			table.concat(inputs, ",") .. ")")
	end
	-- Planks: tree -> planks keeps wood clickable; the jump avoids slabs/stairs.
	-- Round 41: the stick's wood is group:wood, a multi-item slot; the jump
	-- starts from a small icon, and Back returns to the stick.
	_, view = render(player, "general", nil, "default:stick", 1)
	local wood = view.slots[view.slot_cells[1] or ""]
	local planks
	for _, candidate in ipairs(wood and wood.icons or {}) do
		if icon_field(view, candidate) then planks = candidate break end
	end
	check(planks ~= nil, "stick recipe: a planks icon (" ..
		tostring(planks and planks.item) .. ") of the wood slot is clickable")
	if planks then
		grug_jobs.open_book(player, "general")
		list = parse(send(player, {grug_jobs_search = "default:stick", grug_jobs_do_search = ""}))
		host = click_list(player, list, "default:stick")
		local after = host and parse(send(player, {[icon_field(host, planks)] = "",
			grug_jobs_search = ""}))
		local text = table.concat(after and drawn_items(after) or {}, ",")
		check(after ~= nil and after.selected == planks.item and
			not text:find("slab", 1, true) and not text:find("stair", 1, true),
			"planks jump from a small icon shows the tree route (" .. text .. ")")
		check(after ~= nil and after.back ~= nil, "Back appears after a jump from a small icon")
		local back = after and parse(send(player, {grug_jobs_back = "", grug_jobs_search = ""}))
		check(back ~= nil and back.selected == "default:stick" and back.search == "default:stick",
			"Back after a small-icon jump returns to the stick")
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
	-- Round 41: deterministic order, a concrete main material of a route that
	-- navigation uses (never an inverse one), and the item drawn as a single
	-- cell or as an icon of a multi-item slot.
	local items = {}
	for item in pairs(stats.undiscovered) do items[#items + 1] = item end
	table.sort(items)
	local inverse = inverse_oracle().inverse
	local function field(view, item)
		local pos = cell_of(view, item)
		if pos then return true, field_of(view, pos) end
		local icon = icon_of(view, item)
		return icon ~= nil, icon_field(view, icon)
	end
	for _, item in ipairs(items) do
		local case = stats.undiscovered[item]
		local player = make_player("probe_disc", case.setup)
		local material
		for _, record in ipairs(records_with_output(player, "general", item)) do
			local declaration = record.basics_presentation
			if not inverse[record] and declaration and
					type(declaration.main_material) == "string" and
					not declaration.main_material:match("^group:") then
				material = declaration.main_material
				break
			end
		end
		if material then
			local _, view = render(player, case.book, case.station, case.output,
				case.alternative)
			local drawn, before = field(view, item)
			check(view.selected == case.output and drawn and before == nil,
				"undiscovered " .. item .. " is not clickable in " .. case.where)
			grug_jobs.mark_seen(player, material)
			_, view = render(player, case.book, case.station, case.output,
				case.alternative)
			local _, after = field(view, item)
			check(after ~= nil, item .. " becomes clickable after seeing " .. material)
			return
		end
	end
	check(false, "found an undiscovered ingredient with a concrete main material")
end

-- Lock gate: the shipped progression authority (grug_jobs.recipe_progress_unlocked,
-- the same check that refuses above-tier crafts) is forced to refuse every
-- route producing one clickable profession ingredient; the cell must turn
-- inert while its host recipe stays listed, and clickable again afterwards.
-- The first book (in this order) with a clickable ingredient made only by
-- that book's recipes (Round 41: the weaponsmith catalogue has none since
-- its bars moved to Basics).
local LOCK_BOOKS = {
	{book = "weaponsmith", setup = {primaries = {"weaponsmith"}}},
	{book = "alchemist", setup = {secondaries = {"alchemist"}}},
	{book = "cooking", setup = {secondaries = {"cooking"}}},
	{book = "leatherworker", setup = {primaries = {"leatherworker"}}},
	{book = "tailor", setup = {primaries = {"tailor"}}},
}

local function test_locked()
	local player, book, case
	for _, candidate in ipairs(LOCK_BOOKS) do
		book = candidate.book
		player = make_player("probe_lock_" .. book, candidate.setup)
		local profession_outputs = set_of(outputs_of(player, book, nil))
		for _, output in ipairs(outputs_of(player, book, nil)) do
			local _, view = render(player, book, nil, output, 1)
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
		if case then break end
	end
	check(case ~= nil, "found a profession ingredient made only by its book's recipes (" ..
		tostring(case and book) .. ")")
	if not case then return end
	local original = grug_jobs.recipe_progress_unlocked
	grug_jobs.recipe_progress_unlocked = function(p, recipe)
		if recipe and recipe.output_name == case.item then
			return false, "Tier 6 required."
		end
		return original(p, recipe)
	end
	local ok, err = pcall(function()
		local _, view = render(player, book, nil, case.output, 1)
		check(view.cells[case.pos] == case.item and
			field_of(view, case.pos) == nil and
			not (view.tooltips[case.pos] or ""):find("Click to view recipe", 1, true),
			"locked " .. case.item .. " is not clickable in " .. case.output)
	end)
	grug_jobs.recipe_progress_unlocked = original
	check(ok, "locked scenario ran without error " .. tostring(err or ""))
	local _, view = render(player, book, nil, case.output, 1)
	check(field_of(view, case.pos) ~= nil, case.item .. " is clickable again once unlocked")
end

local function run_all()
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		local origin = core.callback_origins and core.callback_origins[fn]
		if origin and origin.mod == "grug_jobs" then handlers[#handlers + 1] = fn end
	end
	-- The current build (Round 41) has the station return; the baseline
	-- (BASE_REV, ui.lua reverted) does not.
	local patched = type(grug_jobs.close_to_origin) == "function"
	dump_all(patched)
	if not patched then
		log("RESULT BASELINE (no multi-item slots in this build)")
		core.request_shutdown("recipe book probe done", false, 0)
		return
	end
	for _, scenario in ipairs(SCENARIOS) do
		sweep(scenario.label, scenario.setup,
			make_player("probe_sweep_" .. scenario.label, scenario.setup))
	end
	log(("sweep routes=%d cells=%d clickable=%d (of them small icons %d, clickable %d)"):format(
		stats.routes, stats.cells, stats.clickable, stats.icons, stats.icon_clickable))
	local sizes = {}
	for n, count in pairs(stats.slot_sizes) do sizes[#sizes + 1] = {n, count} end
	table.sort(sizes, function(a, b) return a[1] < b[1] end)
	for index, size in ipairs(sizes) do sizes[index] = size[1] .. " items: " .. size[2] end
	log("multi-item slots drawn per item count: " .. table.concat(sizes, ", "))
	for _, n in ipairs({2, 3, 4, 5}) do
		local seen = 0
		for size, count in pairs(stats.slot_sizes) do
			if size == n or (n == 5 and size > 4) then seen = seen + count end
		end
		if n == 3 then
			log("slots with 3 items: " .. seen .. " (informational: no shipped group has three)")
		else
			check(seen > 0, ("the sweep drew %s-item slots (%d)"):format(
				n == 5 and "more-than-4" or tostring(n), seen))
		end
	end
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
	-- Round 41: weapons moved to Basics; the weaponsmith book's one item host
	-- is the forge (steel, furnace, stone bricks), so a veteran who has seen
	-- every material is needed, and the station case takes the first station
	-- view that offers a switch (the forge lists only enchant operations now).
	test_switch("weaponsmith", {primaries = {"weaponsmith"}, veteran = true, see_all = true},
		"weaponsmith", nil)
	local station_switch
	for _, station in ipairs({"forge", "tanning_rack", "tailor_bench", "carving_bench",
			"jewellers_bench", "dual_furnace", "brewing_stand", "furnace"}) do
		if test_switch(station, {primaries = {"weaponsmith", "leatherworker"},
				secondaries = {"cooking", "alchemist"}, veteran = true, see_all = true},
				"station", station, false, true) then
			station_switch = station
			break
		end
	end
	check(station_switch ~= nil, "a station view has an ingredient that switches books (" ..
		tostring(station_switch) .. ")")
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
