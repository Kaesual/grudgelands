-- Known-answer geometry test for the Character and Talents sfinv pages.
-- It loads the real page builders and the real sfinv make_formspec template,
-- then renders every shipped class at levels 1 and 60.
--
-- Formspec label[] has no explicit size. These legacy-coordinate pages use
-- Luanti's default 16 px font and a 48 px inventory-cell unit. The collision
-- model therefore gives a label an 18 px line box (16 px plus 2 px leading),
-- or 0.375 formspec units, centred on its y coordinate. Width is conservatively
-- estimated at 9 px per source byte; UTF-8 and formspec escapes consequently
-- overestimate rather than hide overlap. The acceptance layout separates text
-- and inventory art vertically, so font-width variation cannot manufacture a
-- pass. textarea[] and hypertext[] use their explicit parameter sizes.
--
-- Usage (ABSOLUTE repository root required):
--   luajit -e 'io.write(dofile("tools/ui/page_layout_kat.lua")("/abs/repo"))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/ui/page_layout_kat.lua")("/abs/repo"))'
-- Read-only mutation checks:
--   R7_UI_MUTATION=1 moves the rendered Respec button beyond the right edge.
--   R7_UI_MUTATION=2 moves the tabheader to 99,99.
--   R7_UI_MUTATION=3 shortens the rendered form to size[8,5].
--   R7_UI_MUTATION=4 removes the active-status term from Character pool lines.

local M = {}

local LABEL_FONT_PX = 16
local LABEL_LINE_PX = LABEL_FONT_PX + 2
local LEGACY_UNIT_PX = 48
local LABEL_HEIGHT = LABEL_LINE_PX / LEGACY_UNIT_PX
local LABEL_BYTE_WIDTH = 9 / LEGACY_UNIT_PX
local FORM_MARGIN = 0.10
local EXPECTED_FORM_W = 10.4
local EXPECTED_FORM_H = 11.1
local EXPECTED_TAB_X = 0
local EXPECTED_TAB_Y = 0
-- The vendored legacy sfinv template places its three-row main list at 6.35;
-- its last slot edge is therefore 9.35 even though size[] remains 9.1 high.
-- This is the sole accepted legacy cell-edge allowance, and applies only to
-- that exact lower current_player/main list; every other element is bounded by
-- size[] itself.
local LEGACY_LIST_BOTTOM_ALLOWANCE = 0.25

local EQUIPMENT_SLOTS = {
	{list = "grug_head", label = "Head"},
	{list = "grug_chest", label = "Chest"},
	{list = "grug_legs", label = "Legs"},
	{list = "grug_feet", label = "Feet"},
	{list = "grug_weapon", label = "Weapon"},
	{list = "grug_offhand", label = "Offhand"},
	{list = "grug_trinket1", label = "Trinket 1"},
	{list = "grug_trinket2", label = "Trinket 2"},
}
local EQUIPMENT_LISTS = {}
for _, slot in ipairs(EQUIPMENT_SLOTS) do
	EQUIPMENT_LISTS[slot.list] = true
end

local function load_into(env, path)
	local root = path:match("^(.-)/mods/")
	if root then
		env.core.get_modpath = function() return root .. "/mods/PLAYER/grug_classes" end
		env.core.get_current_modname = function() return "grug_classes" end
		env.dofile = function(file)
			local loader = assert(loadfile(file)); setfenv(loader, env); return loader()
		end
	end
	local chunk, load_error = loadfile(path)
	if not chunk then
		return false, load_error
	end
	setfenv(chunk, env)
	return pcall(chunk)
end

local function make_meta()
	local values = {}
	local meta = {}
	function meta:get_string(key)
		return values[key] or ""
	end
	function meta:set_string(key, value)
		values[key] = tostring(value)
	end
	function meta:get_int(key)
		return tonumber(values[key]) or 0
	end
	function meta:set_int(key, value)
		values[key] = tostring(value)
	end
	return meta
end

local function empty_stack()
	local meta = make_meta()
	return {
		is_empty = function() return true end,
		get_definition = function() return {} end,
		get_meta = function() return meta end,
	}
end

local function build_env()
	local hooks = {mods_loaded = {}, status_modifiers = {}}
	local core = {}
	function core.register_on_player_hpchange() end
	function core.get_item_group() return 0 end
	function core.get_us_time()
		return 1000000
	end
	function core.colorize(color, text)
		return text
	end
	function core.chat_send_player() end
	function core.register_chatcommand() end
	function core.register_on_leaveplayer() end
	function core.register_on_dieplayer() end
	function core.register_on_joinplayer() end
	function core.register_on_player_receive_fields() end
	function core.register_on_mods_loaded(func)
		hooks.mods_loaded[#hooks.mods_loaded + 1] = func
	end
	function core.formspec_escape(value)
		return tostring(value):gsub("\\", "\\\\"):gsub("]", "\\]")
			:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
	end
	function core.log() end

	local classes = {
		registered_classes = {
			warrior = {id = "warrior", name = "Warrior", resource = "rage"},
			mage = {id = "mage", name = "Mage", resource = "mana"},
			priest = {id = "priest", name = "Priest", resource = "mana"},
			scout = {id = "scout", name = "Scout", resource = "mana"},
		},
		class_ids = {"warrior", "mage", "priest", "scout"},
	}
	function classes.get_class(player)
		return player._class
	end
	function classes.get_class_def(player)
		return classes.registered_classes[player._class]
	end
	function classes.register_on_class_chosen() end
	function classes.apply_stats() end
	function classes.get_crit_chance(player)
		return player._crit
	end
	function classes.get_crit_chance_raw(player)
		return player._crit_raw
	end
	function classes.get_dodge_chance(player)
		return player._dodge
	end
	function classes.get_dodge_chance_raw(player)
		return player._dodge_raw
	end
	function classes.pool_percent_amount(player, pool, percent)
		local base = player._level == 1 and 26 or 2696
		local factor = pool == "hp" and player._hp_factor or 1
		return math.floor(base * factor * percent / 100 + 0.5)
	end
	function classes.get_pool_breakdown(player, pool)
		local base = player._level == 1 and 26 or 2696
		local factor = pool == "hp" and player._hp_factor or 1
		local final_by_class = player._level == 1 and {
			warrior = 34, mage = 26, priest = 29,
		} or {
			warrior = 3559, mage = 2669, priest = 2966,
		}
		local final = pool == "mana"
			and (player._level == 1 and 29 or 2966)
			or final_by_class[player._class]
		return {base = base, class_factor = factor, gear_percent = 7,
			talent_percent = 3, status_percent = 5, final = final}
	end

	local xp = {}
	function xp.get_level(player)
		return player._level
	end
	function xp.register_on_level_change() end

	local money = {}
	function money.take()
		return true
	end
	function money.format(value)
		return tostring(value) .. "c"
	end

	local grug_core = {}
	function grug_core.get_armor_rating(player) return player._armor or 60 end
	function grug_core.get_player_level(player) return player._level end
	function grug_core.armor_reduction(rating, level, cap)
		return math.min(cap, rating / (rating + 85 * level + 400))
	end

	function grug_core.get_armor_percent(player)
		return player._armor
	end
	function grug_core.get_armor_percent_raw(player)
		return player._armor_raw
	end
	function grug_core.register_on_equipment_change() end
	function grug_core.register_on_status_modifiers_changed(callback)
		hooks.status_modifiers[#hooks.status_modifiers + 1] = callback
	end

	local inventory_api = {
		equipment_slots = EQUIPMENT_SLOTS,
		BAG_COUNT = 4,
		bag_list = function(index) return "grug_bag" .. index end,
		content_list = function(index) return "grug_bag_contents" .. index end,
		bag_slots_of = function() return 0 end,
	}

	local env = {
		core = core,
		minetest = core, -- vendored sfinv still uses the historical alias
		grug_core = grug_core,
		grug_classes = classes,
		grug_xp = xp,
		grug_money = money,
		grug_inventory = inventory_api,
		grug_factions = {},
		player_api = {registered_models = {['character.b3d'] = {
			textures = {"character.png"},
		}}},
		math = math, string = string, table = table,
		pairs = pairs, ipairs = ipairs, next = next,
		type = type, tostring = tostring, tonumber = tonumber,
		select = select, assert = assert, error = error, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, unpack = unpack,
		dump = function(value) return tostring(value) end,
	}
	env._G = env
	return env, hooks
end

local function make_player(class_id, level)
	local factors = {warrior = 1.20, mage = 0.90, priest = 1.00}
	local first_talents = {
		warrior = "ironbound=1",
		mage = "tinder=1",
		priest = "gentle_hand=1",
	}
	local inventory = {}
	function inventory:get_stack()
		return empty_stack()
	end
	local player = {
		_class = class_id,
		_level = level,
		_hp_factor = factors[class_id],
		_crit = 0.18,
		_crit_raw = 0.24,
		_dodge = 0.12,
		_dodge_raw = 0.16,
		_armor = 35,
		_armor_raw = 41,
		_meta = make_meta(),
		_inventory = inventory,
	}
	if level == 60 then
		player._meta:set_string("grug_classes:talents", first_talents[class_id])
	end
	function player:get_player_name()
		return self._class .. "_l" .. self._level
	end
	function player:is_player()
		return true
	end
	function player:get_meta()
		return self._meta
	end
	function player:get_inventory()
		return self._inventory
	end
	function player:get_properties()
		return {visual = "mesh", mesh = "character.b3d",
			textures = {"character.png"}}
	end
	return player
end

local function parse_pair(text)
	local x, y = text:match("^%s*([%+%-]?[%d%.]+)%s*,%s*([%+%-]?[%d%.]+)%s*$")
	return tonumber(x), tonumber(y)
end

local function label_width(text)
	-- Drop escape introducers; byte counting remains conservative for UTF-8.
	local visible = text:gsub("\\(.)", "%1")
	return #visible * LABEL_BYTE_WIDTH
end

local function geometry(formspec)
	local texts, visuals, controls, elements = {}, {}, {}, {}
	local form
	local index = 0
	for kind, body in formspec:gmatch("([%a_]+)%[([^%]]*)%]") do
		index = index + 1
		local box
		if kind == "size" then
			local w, h = parse_pair(body)
			if w and h then
				form = {x = 0, y = 0, w = w, h = h, kind = kind, index = index}
			end
		elseif kind == "label" then
			local position, text = body:match("^([^;]+);(.*)$")
			local x, y = parse_pair(position or "")
			if x and y then
				box = {x = x, y = y - LABEL_HEIGHT / 2,
					w = label_width(text or ""), h = LABEL_HEIGHT,
					kind = kind, index = index, text = text or ""}
			end
		elseif kind == "textarea" or kind == "hypertext" then
			local position, size = body:match("^([^;]+);([^;]+);")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index,
					text = body:match("^[^;]+;[^;]+;[^;]*;[^;]*;(.*)$") or ""}
			end
		elseif kind == "list" then
			local location, listname, position, size =
				body:match("^([^;]*);([^;]*);([^;]+);([^;]+);")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index, location = location,
					listname = listname}
			end
		elseif kind == "image" or kind == "item_image" or kind == "model" then
			local position, size = body:match("^([^;]+);([^;]+);")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index}
			end
		elseif kind == "button" then
			local position, size, name, text =
				body:match("^([^;]+);([^;]+);([^;]*);(.*)$")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index, name = name, text = text or ""}
			end
		elseif kind == "image_button" then
			local position, size, texture, name, text =
				body:match("^([^;]+);([^;]+);([^;]*);([^;]*);(.*)$")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h, kind = kind,
					index = index, texture = texture, name = name, text = text or ""}
			end
		elseif kind == "tabheader" then
			local position, name = body:match("^([^;]+);([^;]*);")
			local x, y = parse_pair(position or "")
			if x and y then
				box = {x = x, y = y, w = 0, h = 0,
					kind = kind, index = index, name = name}
			end
		end
		if box then
			elements[#elements + 1] = box
			if kind == "label" or kind == "textarea" or kind == "hypertext" then
				texts[#texts + 1] = box
			elseif kind == "list" or kind == "image" or kind == "item_image" or
					kind == "model" then
				visuals[#visuals + 1] = box
			else
				controls[#controls + 1] = box
			end
		end
	end
	return texts, visuals, controls, elements, form
end

local function intersects(a, b)
	local epsilon = 0.000001
	return a.x < b.x + b.w - epsilon and b.x < a.x + a.w - epsilon
		and a.y < b.y + b.h - epsilon and b.y < a.y + a.h - epsilon
end

local function overlap_failures(page_name, class_id, level, formspec)
	local texts, visuals, controls, elements, form = geometry(formspec)
	local failures = {}
	if not form then
		failures[#failures + 1] = page_name .. " has no parsed size[] bound"
	else
		if math.abs(form.w - EXPECTED_FORM_W) > 0.000001 or
				math.abs(form.h - EXPECTED_FORM_H) > 0.000001 then
			failures[#failures + 1] = ("%s/%s/L%d form is %.2fx%.2f, expected %.1fx%.1f")
				:format(page_name, class_id, level, form.w, form.h,
					EXPECTED_FORM_W, EXPECTED_FORM_H)
		end
		for _, element in ipairs(elements) do
			local right_margin = (element.kind == "label" or
				element.kind == "textarea" or element.kind == "hypertext")
				and FORM_MARGIN or 0
			local legacy_lower_main = element.kind == "list" and
				element.location == "current_player" and
				element.listname == "main" and element.x == 1.2 and
				element.y == 8.35 and element.w == 8 and element.h == 3
			local bottom_allowance = legacy_lower_main
				and LEGACY_LIST_BOTTOM_ALLOWANCE or 0
			if element.x < 0 or element.y < 0 or
					element.x + element.w > form.w - right_margin or
					element.y + element.h > form.h + bottom_allowance then
				failures[#failures + 1] = ("%s/%s/L%d %s[%d] exceeds %.1fx%.1f usable form")
					:format(page_name, class_id, level, element.kind,
						element.index, form.w, form.h)
			end
		end
	end
	for _, text_box in ipairs(texts) do
		for _, visual_box in ipairs(visuals) do
			if intersects(text_box, visual_box) then
				failures[#failures + 1] = ("%s/%s/L%d %s[%d] intersects %s[%d]")
					:format(page_name, class_id, level, text_box.kind,
						text_box.index, visual_box.kind, visual_box.index)
			end
		end
	end

	local equipment_slots = 0
	for _, visual_box in ipairs(visuals) do
		if visual_box.kind == "list" and EQUIPMENT_LISTS[visual_box.listname] then
			equipment_slots = equipment_slots + 1
		end
	end
	if page_name == "character" and equipment_slots ~= #EQUIPMENT_SLOTS then
		failures[#failures + 1] = ("character/%s/L%d has %d equipment slots, expected %d")
			:format(class_id, level, equipment_slots, #EQUIPMENT_SLOTS)
	end

	local tabheaders = {}
	for _, control in ipairs(controls) do
		if control.kind == "tabheader" then
			tabheaders[#tabheaders + 1] = control
		end
	end
	if #tabheaders ~= 1 then
		failures[#failures + 1] = ("%s/%s/L%d has %d tabheaders, expected one")
			:format(page_name, class_id, level, #tabheaders)
	elseif tabheaders[1].x ~= EXPECTED_TAB_X or
			tabheaders[1].y ~= EXPECTED_TAB_Y or
			tabheaders[1].name ~= "sfinv_nav_tabs" then
		failures[#failures + 1] = ("%s/%s/L%d tabheader is %.2f,%.2f/%s, expected 0,0/sfinv_nav_tabs")
			:format(page_name, class_id, level, tabheaders[1].x,
				tabheaders[1].y, tostring(tabheaders[1].name))
	end

	if page_name == "talents" then
		local headers, tier_one = {}, {}
		for _, text_box in ipairs(texts) do
			if text_box.text and (text_box.text:match("^Crit ") or
					text_box.text:match("^Dodge ") or text_box.text:match("^Armor ")) then
				headers[#headers + 1] = text_box
			elseif text_box.text and text_box.text:match("^T1 ") then
				tier_one[#tier_one + 1] = text_box
			end
		end
		for _, control in ipairs(controls) do
			if (control.kind == "button" or control.kind == "image_button") and
					control.text and control.text:match("^T1 ") then
				tier_one[#tier_one + 1] = control
			end
		end
		if #headers ~= 3 then
			failures[#failures + 1] = ("talents/%s/L%d has %d stat headers, expected three")
				:format(class_id, level, #headers)
		end
		if #tier_one ~= 2 then
			failures[#failures + 1] = ("talents/%s/L%d has %d T1 elements, expected two")
				:format(class_id, level, #tier_one)
		end
		for _, header in ipairs(headers) do
			for _, first_tier in ipairs(tier_one) do
				if intersects(header, first_tier) or
						header.y + header.h > first_tier.y then
					failures[#failures + 1] = ("talents/%s/L%d %s header reaches T1 %s[%d]")
						:format(class_id, level, header.text:match("^(%S+)") or "stat",
							first_tier.kind, first_tier.index)
				end
			end
		end
	end
	return failures, #texts, #visuals, #controls, equipment_slots
end

local function run_checks(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	local env, hooks = build_env()
	for _, relative in ipairs({
		"mods/BASE/sfinv/api.lua",
		"mods/PLAYER/grug_classes/talents.lua",
		"mods/PLAYER/grug_inventory/ui.lua",
		"mods/PLAYER/grug_inventory/pages.lua",
		"mods/PLAYER/grug_classes/talents_ui.lua",
	}) do
		local ok, problem = load_into(env, repo .. "/" .. relative)
		if not ok then
			return "r7_ui_layout_failure\tloading " .. relative .. " failed: " ..
				tostring(problem) .. "\nr7_ui_layout_result\tFAIL\t1\n"
		end
	end

	local mutation = tonumber(os.getenv("R7_UI_MUTATION") or "") or 0
	local mutation_hits = 0
	local rows, failures = {}, {}
	if #hooks.status_modifiers ~= 1 then
		failures[#failures + 1] = ("pages registered %d status modifier hooks, expected one")
			:format(#hooks.status_modifiers)
	end
	local help = env.sfinv.pages["grug_inventory:help"]:get(
		make_player("mage", 60), {page = "grug_inventory:help",
			nav_titles = {"Character", "Bags", "Talents", "Help"}, nav_idx = 4})
	if not help:find("S the active status percentage", 1, true) then
		failures[#failures + 1] = "Help does not define the Character S term"
	end
	if not help:find("Troll multiplier applies only out of combat", 1, true) then
		failures[#failures + 1] = "Help does not limit Troll regeneration to out of combat"
	end
	rows[#rows + 1] = ("r7_ui_layout_assumption\tlabel_font_px=%d\t" ..
		"label_line_px=%d\tlegacy_unit_px=%d\tform=%.1fx%.1f"):format(
			LABEL_FONT_PX, LABEL_LINE_PX, LEGACY_UNIT_PX,
			EXPECTED_FORM_W, EXPECTED_FORM_H)
	for _, class_id in ipairs({"warrior", "mage", "priest"}) do
		for _, level in ipairs({1, 60}) do
			local player = make_player(class_id, level)
			for _, page_spec in ipairs({
				{name = "character", id = "grug_inventory:character", nav = 1},
				{name = "talents", id = "grug_classes:talents", nav = 3},
			}) do
				local context = {page = page_spec.id,
					nav_titles = {"Character", "Bags", "Talents", "Help"},
					nav_idx = page_spec.nav}
				local page = env.sfinv.pages[page_spec.id]
				local formspec = page:get(player, context)
				local changed
				if mutation == 1 then
					formspec, changed = formspec:gsub(
						"button%[7%.55,1%.30;2%.65,0%.5;grug_talent_respec;",
						"button[11.65,1.30;2.65,0.5;grug_talent_respec;", 1)
				elseif mutation == 2 then
					formspec, changed = formspec:gsub("tabheader%[0,0;",
						"tabheader[99,99;", 1)
				elseif mutation == 3 then
					formspec, changed = formspec:gsub("size%[10%.4,11%.1%]",
						"size[8,5]", 1)
				elseif mutation == 4 then
					formspec, changed = formspec:gsub("%+S[%d%.%-]+", "")
				else
					changed = 0
				end
				mutation_hits = mutation_hits + changed
				local found, text_count, visual_count, control_count, slot_count = overlap_failures(
					page_spec.name, class_id, level, formspec)
				if page_spec.name == "character" and
						not formspec:find("+S5", 1, true) then
					found[#found + 1] = ("character/%s/L%d omits active status term S")
						:format(class_id, level)
				end
				if page_spec.name == "character" and text_count ~= 8 then
					found[#found + 1] = ("character/%s/L%d has %d text boxes, expected eight")
						:format(class_id, level, text_count)
				end
				for _, failure in ipairs(found) do
					failures[#failures + 1] = failure
				end
				rows[#rows + 1] = ("r7_ui_layout\t%s\t%s\tL%d\t" ..
					"text=%d\tvisual=%d\tcontrols=%d\tslots=%d\t%s")
					:format(page_spec.name, class_id, level, text_count, visual_count,
					control_count, slot_count,
					#found == 0 and "PASS" or "FAIL")
			end
		end
	end
	local expected_mutation_hits = {[1] = 3, [2] = 12, [3] = 12, [4] = 10}
	if mutation ~= 0 and mutation_hits ~= expected_mutation_hits[mutation] then
		failures[#failures + 1] = ("mutation %d changed %d formspecs, expected %s")
			:format(mutation, mutation_hits,
				tostring(expected_mutation_hits[mutation]))
	end
	rows[#rows + 1] = ("r7_ui_layout_result\t%s\t%d"):format(
		#failures == 0 and "PASS" or "FAIL", #failures)
	table.sort(failures)
	for _, failure in ipairs(failures) do
		rows[#rows + 1] = "r7_ui_layout_failure\t" .. failure
	end
	return table.concat(rows, "\n") .. "\n"
end

function M.run(repo)
	local ok, result = pcall(run_checks, repo)
	if ok then
		return result
	end
	return "r7_ui_layout_failure\tthe fixture raised: " .. tostring(result) ..
		"\nr7_ui_layout_result\tFAIL\t1\n"
end

return function(repo)
	return M.run(repo)
end
