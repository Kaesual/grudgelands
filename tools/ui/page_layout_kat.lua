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

local M = {}

local LABEL_FONT_PX = 16
local LABEL_LINE_PX = LABEL_FONT_PX + 2
local LEGACY_UNIT_PX = 48
local LABEL_HEIGHT = LABEL_LINE_PX / LEGACY_UNIT_PX
local LABEL_BYTE_WIDTH = 9 / LEGACY_UNIT_PX

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

local function load_into(env, path)
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
	local hooks = {mods_loaded = {}}
	local core = {}
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
		},
		class_ids = {"warrior", "mage", "priest"},
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
			talent_percent = 3, final = final}
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
	function grug_core.get_armor_percent(player)
		return player._armor
	end
	function grug_core.get_armor_percent_raw(player)
		return player._armor_raw
	end
	function grug_core.register_on_equipment_change() end

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
	local texts, visuals = {}, {}
	local index = 0
	for kind, body in formspec:gmatch("([%a_]+)%[([^%]]*)%]") do
		index = index + 1
		local box
		if kind == "label" then
			local position, text = body:match("^([^;]+);(.*)$")
			local x, y = parse_pair(position or "")
			if x and y then
				box = {x = x, y = y - LABEL_HEIGHT / 2,
					w = label_width(text or ""), h = LABEL_HEIGHT,
					kind = kind, index = index}
			end
		elseif kind == "textarea" or kind == "hypertext" then
			local position, size = body:match("^([^;]+);([^;]+);")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index}
			end
		elseif kind == "list" then
			local position, size = body:match("^[^;]*;[^;]*;([^;]+);([^;]+);")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index}
			end
		elseif kind == "image" or kind == "item_image" then
			local position, size = body:match("^([^;]+);([^;]+);")
			local x, y = parse_pair(position or "")
			local w, h = parse_pair(size or "")
			if x and y and w and h then
				box = {x = x, y = y, w = w, h = h,
					kind = kind, index = index}
			end
		end
		if box then
			if kind == "label" or kind == "textarea" or kind == "hypertext" then
				texts[#texts + 1] = box
			else
				visuals[#visuals + 1] = box
			end
		end
	end
	return texts, visuals
end

local function intersects(a, b)
	local epsilon = 0.000001
	return a.x < b.x + b.w - epsilon and b.x < a.x + a.w - epsilon
		and a.y < b.y + b.h - epsilon and b.y < a.y + a.h - epsilon
end

local function overlap_failures(page_name, class_id, level, formspec)
	local texts, visuals = geometry(formspec)
	local failures = {}
	for _, text_box in ipairs(texts) do
		for _, visual_box in ipairs(visuals) do
			if intersects(text_box, visual_box) then
				failures[#failures + 1] = ("%s/%s/L%d %s[%d] intersects %s[%d]")
					:format(page_name, class_id, level, text_box.kind,
						text_box.index, visual_box.kind, visual_box.index)
			end
		end
	end
	return failures, #texts, #visuals
end

local function plain_count(text, needle)
	local count, start = 0, 1
	while true do
		local found = text:find(needle, start, true)
		if not found then
			return count
		end
		count = count + 1
		start = found + #needle
	end
end

local function run_checks(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	local env = build_env()
	for _, relative in ipairs({
		"mods/BASE/sfinv/api.lua",
		"mods/PLAYER/grug_classes/talents.lua",
		"mods/PLAYER/grug_inventory/pages.lua",
		"mods/PLAYER/grug_classes/talents_ui.lua",
	}) do
		local ok, problem = load_into(env, repo .. "/" .. relative)
		if not ok then
			return "r7_ui_layout_failure\tloading " .. relative .. " failed: " ..
				tostring(problem) .. "\nr7_ui_layout_result\tFAIL\t1\n"
		end
	end

	local rows, failures = {}, {}
	rows[#rows + 1] = ("r7_ui_layout_assumption\tlabel_font_px=%d\t" ..
		"label_line_px=%d\tlegacy_unit_px=%d"):format(
		LABEL_FONT_PX, LABEL_LINE_PX, LEGACY_UNIT_PX)
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
				local found, text_count, visual_count = overlap_failures(
					page_spec.name, class_id, level, formspec)
				if page_spec.name == "character" and text_count ~= 2 then
					found[#found + 1] = ("character/%s/L%d has %d text boxes, expected two")
						:format(class_id, level, text_count)
				end
				if page_spec.name == "talents" and
						(plain_count(formspec, "Eff/raw:") ~= 1 or
						not formspec:find("Armor ", 1, true)) then
					found[#found + 1] = ("talents/%s/L%d lacks one combined stat header")
						:format(class_id, level)
				end
				for _, failure in ipairs(found) do
					failures[#failures + 1] = failure
				end
				rows[#rows + 1] = ("r7_ui_layout\t%s\t%s\tL%d\t" ..
					"text=%d\tvisual=%d\t%s"):format(page_spec.name,
					class_id, level, text_count, visual_count,
					#found == 0 and "PASS" or "FAIL")
			end
		end
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
