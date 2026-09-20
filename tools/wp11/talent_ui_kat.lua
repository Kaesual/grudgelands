-- Known-answer test for WP11 lane X4. Loads the real talent model and sfinv
-- page, then drives purchases, paid/free respecs, level notices and rendering.
--
-- Usage:
--   luajit          -e 'io.write(dofile("tools/wp11/talent_ui_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp11/talent_ui_kat.lua")("."))'

local M = {}

local function build_env(repo, clock)
	local function noop() end
	local core = {}
	function core.register_on_player_hpchange() end
	function core.get_item_group() return 0 end
	function core.get_us_time()
		return clock.us
	end
	function core.colorize(color, text)
		return text
	end
	function core.chat_send_player(name, text)
		clock.chat[#clock.chat + 1] = name .. ": " .. text
	end
	function core.register_chatcommand(name, def)
		clock.commands[name] = def
	end
	function core.register_on_leaveplayer(func)
		clock.leave[#clock.leave + 1] = func
	end
	function core.register_on_dieplayer(func)
		clock.die[#clock.die + 1] = func
	end
	function core.register_on_mods_loaded(func)
		clock.mods_loaded[#clock.mods_loaded + 1] = func
	end
	function core.formspec_escape(value)
		return tostring(value):gsub("\\", "\\\\"):gsub("]", "\\]")
			:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
	end

	local classes = {
		registered_classes = {
			warrior = {id = "warrior", name = "Warrior"},
			mage = {id = "mage", name = "Mage"},
			priest = {id = "priest", name = "Priest"},
			scout = {id = "scout", name = "Scout"},
		},
		class_ids = {"warrior", "mage", "priest", "scout"},
	}
	function classes.get_class(player)
		return player._class
	end
	function classes.register_on_class_chosen(func)
		clock.class_chosen[#clock.class_chosen + 1] = func
	end
	function classes.apply_stats(player) end
	function classes.get_crit_chance(player)
		return player._crit or 0.30
	end
	function classes.get_crit_chance_raw(player)
		return player._crit_raw or 0.42
	end
	function classes.get_dodge_chance(player)
		return player._dodge or 0.20
	end
	function classes.get_dodge_chance_raw(player)
		return player._dodge_raw or 0.20
	end
	function classes.pool_percent_amount(player, pool, percent)
		local level = player._level
		local base = math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
		local factor = pool == "hp" and player._class == "warrior" and 1.2 or 1
		return math.floor(base * factor * percent / 100 + 0.5)
	end

	local xp = {_callbacks = {}}
	function xp.get_level(player)
		return player._level
	end
	function xp.register_on_level_change(func)
		xp._callbacks[#xp._callbacks + 1] = func
	end

	local money = {}
	function money.take(player, copper)
		clock.take_calls = clock.take_calls + 1
		clock.take_amounts[#clock.take_amounts + 1] = copper
		if player._money < copper then
			return false
		end
		player._money = player._money - copper
		return true
	end
	function money.format(copper)
		return tostring(copper) .. "c"
	end

	local grug_core = {}
	function grug_core.absorb_modifier() return 0 end
	function grug_core.clear_absorb_modifiers() end
	function grug_core.get_armor_rating(player) return player._armor or 60 end
	function grug_core.get_player_level(player) return player._level end
	function grug_core.armor_reduction(rating, level, cap)
		return math.min(cap, rating / (rating + 85 * level + 400))
	end

	function grug_core.get_armor_percent(player)
		return player._armor or 60
	end
	local grug_inventory = {}
	function grug_inventory.get_equipped_armor(player)
		return player._armor_raw or 67
	end

	local sfinv = {pages = {}, pages_unordered = {}, contexts = {}}
	function sfinv.get_nav_fs() return "" end
	local function seed_page(name, title)
		local def = {name = name, title = title, get = noop}
		sfinv.pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
	end
	seed_page("grug_inventory:character", "Character")
	seed_page("grug_inventory:bags", "Bags")
	seed_page("sfinv:crafting", "Crafting")
	function sfinv.register_page(name, def)
		def.name = name
		sfinv.pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
	end
	function sfinv.make_formspec(player, context, content, show_inv)
		return content
	end
	function sfinv.get_page(player)
		local context = sfinv.contexts[player:get_player_name()]
		return context and context.page or "grug_inventory:character"
	end
	function sfinv.set_page(player, page)
		local context = sfinv.contexts[player:get_player_name()]
		context.page = page
		clock.refreshes = clock.refreshes + 1
	end

	local env = {
		core = core,
		grug_core = grug_core,
		grug_classes = classes,
		grug_xp = xp,
		grug_money = money,
		grug_inventory = grug_inventory,
		sfinv = sfinv,
		math = math, string = string, table = table,
		pairs = pairs, ipairs = ipairs, next = next,
		type = type, tostring = tostring, tonumber = tonumber,
		select = select, assert = assert, error = error, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, unpack = unpack,
	}
	env._G = env
	return env
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

local function make_player(env, name, class_id, level, money)
	local player = {
		_name = name, _class = class_id, _level = level, _money = money or 0,
		_meta = make_meta(),
	}
	function player:get_player_name()
		return self._name
	end
	function player:is_player()
		return true
	end
	function player:get_meta()
		return self._meta
	end
	env.sfinv.contexts[name] = {page = "grug_classes:talents"}
	return player
end

local function run_checks(repo)
	repo = repo or "."
	local failures, rows = {}, {}
	local function check(value, message)
		if not value then
			failures[#failures + 1] = message
		end
	end
	local function equal(got, want, message)
		check(got == want, message .. " -- got " .. tostring(got) ..
			", expected " .. tostring(want))
	end
	local function row(...)
		local values = {}
		for index = 1, select("#", ...) do
			values[index] = tostring((select(index, ...)))
		end
		rows[#rows + 1] = table.concat(values, "\t")
	end

	local clock = {
		us = 1000000, chat = {}, commands = {}, leave = {}, die = {},
		mods_loaded = {}, class_chosen = {}, refreshes = 0, take_calls = 0,
		take_amounts = {},
	}
	local env = build_env(repo, clock)
	for _, relative in ipairs({
		"mods/PLAYER/grug_classes/talents.lua",
		"mods/PLAYER/grug_inventory/ui.lua",
		"mods/PLAYER/grug_classes/talents_ui.lua",
	}) do
		local ok, problem = load_into(env, repo .. "/" .. relative)
		if not ok then
			failures[#failures + 1] = "loading " .. relative .. " failed: " ..
				tostring(problem)
			table.sort(failures)
			return "wp11_talent_ui_failure\t" .. failures[1] ..
				"\nwp11_talent_ui_result\tFAIL\t1\n"
		end
	end
	local balance_mutation = tonumber(os.getenv("R6_BALANCE_MUTATION") or "") or 0
	if balance_mutation == 12 then
		env.grug_classes.talent_description_for = function(player, def)
			return def.description
		end
	elseif balance_mutation == 13 then
		env.grug_classes.registered_talents.hold_ground.description =
			"New skill: absorbs 20/30/40 + 2x floor(Str/10)."
	end
	local classes = env.grug_classes
	local page = env.sfinv.pages["grug_classes:talents"]
	check(page ~= nil, "the sfinv Talents page is not registered")

	-- Navigation: the page is third, after Character and Bags, without a
	-- vendored-sfinv patch.
	for _, callback in ipairs(clock.mods_loaded) do
		callback()
	end
	equal(env.sfinv.pages_unordered[1].name, "grug_inventory:character",
		"Character navigation position")
	equal(env.sfinv.pages_unordered[2].name, "grug_inventory:bags",
		"Bags navigation position")
	equal(env.sfinv.pages_unordered[3].name, "grug_classes:talents",
		"Talents navigation position")

	local function field_index(id)
		for index, candidate in ipairs(classes.talent_ids) do
			if candidate == id then
				return index
			end
		end
	end
	local function submit(player, field)
		local fields = {}
		fields[field] = "true"
		return page:on_player_receive_fields(player,
			env.sfinv.contexts[player:get_player_name()], fields)
	end
	local function pick(player, id)
		return submit(player, "grug_talent_pick_" .. field_index(id))
	end

	-- Real model through the real page: select then buy, gate/prerequisite
	-- refusal, acceptance after the chain is maxed, and the level-2 budget.
	local buyer = make_player(env, "buyer", "warrior", 60, 0)
	pick(buyer, "ironbound")
	equal(classes.talent_rank(buyer, "ironbound"), 0,
		"first click only selects a talent")
	pick(buyer, "ironbound")
	equal(classes.talent_rank(buyer, "ironbound"), 1,
		"second click buys one rank")
	pick(buyer, "weathered")
	pick(buyer, "weathered")
	equal(classes.talent_rank(buyer, "weathered"), 0,
		"a locked tier gate cannot be field-spoofed")
	check(env.sfinv.contexts.buyer.grug_talent_notice:find("needs 5 points", 1, true),
		"the tree-point gate refusal is shown")
	local chained = make_player(env, "chained", "warrior", 60, 0)
	for _ = 1, 5 do
		check(classes.spend_talent(chained, "spite"),
			"opposite chain supplies a gate point")
	end
	pick(chained, "weathered")
	pick(chained, "weathered")
	equal(classes.talent_rank(chained, "weathered"), 0,
		"a missing hard-chain prerequisite cannot be field-spoofed")
	check(env.sfinv.contexts.chained.grug_talent_notice:find(
		"needs Ironbound", 1, true) ~= nil,
		"the hard-chain refusal is shown")
	pick(buyer, "ironbound")
	for _ = 1, 4 do
		pick(buyer, "ironbound")
	end
	equal(classes.talent_rank(buyer, "ironbound"), 5,
		"tier-1 prerequisite maxed")
	pick(buyer, "weathered")
	pick(buyer, "weathered")
	equal(classes.talent_rank(buyer, "weathered"), 1,
		"tier-2 rank accepted after gate and prerequisite")

	local level_two = make_player(env, "level_two", "warrior", 2, 0)
	pick(level_two, "ironbound")
	pick(level_two, "ironbound")
	pick(level_two, "ironbound")
	equal(classes.talent_rank(level_two, "ironbound"), 1,
		"the one-point level-2 budget refuses a second rank")

	-- Drive every respec through the real page handler: first free, replay-safe
	-- confirmation, insufficient funds, then a paid reset through the public
	-- money API.
	local payer = make_player(env, "payer", "warrior", 15, 100)
	check(classes.spend_talent(payer, "ironbound"), "payer's first rank")
	local free_before = payer._money
	submit(payer, "grug_talent_respec")
	check(env.sfinv.contexts.payer.grug_talent_respec_pending,
		"free respec request awaits confirmation")
	equal(classes.talent_rank(payer, "ironbound"), 1,
		"free respec request alone preserved ranks")
	submit(payer, "grug_talent_respec_confirm")
	local charged_free = free_before - payer._money
	equal(classes.talent_rank(payer, "ironbound"), 0,
		"confirmed first respec reset ranks")
	equal(charged_free, 0, "first respec charge")
	equal(payer._money, 100, "first respec left money untouched")
	equal(clock.take_calls, 0, "free respec did not call money.take")
	equal(payer:get_meta():get_int("grug_classes:respec_used"), 1,
		"first respec permanently consumed the free reset")
	equal(env.sfinv.contexts.payer.grug_talent_respec_pending, nil,
		"successful confirmation cleared pending state")

	check(classes.spend_talent(payer, "ironbound"), "payer's second build")
	equal(classes.respec_price(payer), 65, "level-15 placeholder bracket price")
	submit(payer, "grug_talent_respec_confirm")
	equal(classes.talent_rank(payer, "ironbound"), 1,
		"repeated confirmation without a request preserved ranks")
	equal(payer._money, 100,
		"repeated confirmation without a request preserved money")
	equal(clock.take_calls, 0,
		"repeated confirmation without a request skipped money.take")

	payer._money = 64
	submit(payer, "grug_talent_respec")
	submit(payer, "grug_talent_respec_confirm")
	equal(classes.talent_rank(payer, "ironbound"), 1,
		"underfunded respec preserved ranks")
	equal(payer._money, 64, "underfunded respec preserved money")
	equal(clock.take_calls, 1, "underfunded respec called money.take once")
	equal(clock.take_amounts[1], 65,
		"underfunded respec requested the bracket price")
	equal(env.sfinv.contexts.payer.grug_talent_respec_pending, nil,
		"underfunded confirmation cleared pending state")
	check(env.sfinv.contexts.payer.grug_talent_notice:find(
		"You need 65c", 1, true) ~= nil,
		"underfunded refusal is shown by the handler")

	payer._money = 100
	local paid_before = payer._money
	submit(payer, "grug_talent_respec")
	submit(payer, "grug_talent_respec_confirm")
	local charged_paid = paid_before - payer._money
	equal(classes.talent_rank(payer, "ironbound"), 0,
		"confirmed paid respec reset ranks")
	equal(charged_paid, 65, "paid respec charged bracket price")
	equal(payer._money, 35, "paid respec atomic balance")
	equal(clock.take_calls, 2, "paid respec made exactly one more money call")
	equal(clock.take_amounts[2], 65,
		"paid respec requested the bracket price")
	equal(env.sfinv.contexts.payer.grug_talent_respec_pending, nil,
		"paid confirmation cleared pending state")

	-- The handler has no target-player field: spoofed foreign-class and target
	-- fields still affect neither a different player nor another class's tree.
	local alice = make_player(env, "alice", "warrior", 60, 0)
	local bob = make_player(env, "bob", "warrior", 60, 0)
	classes.spend_talent(bob, "ironbound")
	pick(alice, "tinder")
	pick(alice, "tinder")
	equal(classes.talent_rank(alice, "tinder"), 0,
		"foreign-class field spoof refused")
	equal(classes.talent_rank(bob, "ironbound"), 1,
		"another player's talents were untouched")

	-- Level-up notice only on a real level change that grants a point; join's
	-- nil old level remains silent and the text points at the inventory page.
	local levelled = make_player(env, "levelled", "mage", 2, 0)
	classes.on_level_change_talents(levelled, nil, 2)
	equal(#clock.chat, 0, "join emitted no talent notice")
	classes.on_level_change_talents(levelled, 1, 2)
	equal(#clock.chat, 1, "level 2 emitted one talent notice")
	check(clock.chat[1]:find("Open Inventory > Talents", 1, true) ~= nil,
		"level notice names the Talents page")

	-- Builder: expected buttons, locked plain label, data tooltip, escaped
	-- fixture names, raw/effective stats and raised cap display.
	local class_def = classes.registered_classes.warrior
	local ironbound = classes.registered_talents.ironbound
	local saved_class_name, saved_name, saved_description = class_def.name,
		ironbound.name, ironbound.description
	class_def.name = "War;rior]"
	ironbound.name = "Iron;bound]"
	ironbound.description = "Armor; bonus] from data"
	local render_player = make_player(env, "render", "warrior", 60, 0)
	local render_context = env.sfinv.contexts.render
	local fs = classes.talent_formspec_content(render_player, render_context)
	check(fs:find("War\\;rior\\]", 1, true) ~= nil,
		"class name is formspec-escaped")
	check(fs:find("Iron\\;bound\\]", 1, true) ~= nil,
		"talent name is formspec-escaped")
	check(fs:find("Armor\\; bonus\\] from data", 1, true) ~= nil,
		"talent-data tooltip is escaped")
	check(fs:find("grug_talent_pick_" .. field_index("ironbound"), 1, true) ~= nil,
		"available rank button rendered")
	check(fs:find("grug_talent_pick_" .. field_index("weathered"), 1, true) == nil,
		"locked talent has no click target")
	check(fs:find("Crit 30.0/42.0% (30)", 1, true) ~= nil,
		"raw crit is shown beside effective crit")
	check(fs:find("Armor 60.0 x 1.00 + 0.0 = 60.0 (own-level", 1, true) ~= nil,
		"armor rating breakdown and own-level reduction are shown")
	check(fs:find("1.5% = 49 HP", 1, true) ~= nil and
		fs:find("6% = 194 HP", 1, true) ~= nil,
		"Weathered tooltip shows percent and current L60 absolute HP")
	check(fs:find("20% = 539 absorb", 1, true) ~= nil and
		fs:find("40% = 1078 absorb", 1, true) ~= nil and
		not fs:find("2x floor(Str/10)", 1, true),
		"Hold Ground tooltip uses neutral-pool percent and absolute absorb")
	class_def.name, ironbound.name, ironbound.description = saved_class_name,
		saved_name, saved_description

	local caps = make_player(env, "caps", "warrior", 60, 0)
	caps:get_meta():set_string("grug_classes:talents",
		"heavy_hand=5,stoke=4,broadstroke=3,keen_edge=5,onset=3,ruination=1")
	classes.invalidate_talents(caps)
	classes.start_talent_window(caps, "ruination", 10)
	local cap_fs = classes.talent_formspec_content(caps, env.sfinv.contexts.caps)
	check(cap_fs:find("Crit 30.0/42.0% (50)", 1, true) ~= nil,
		"running rule-breaker displays its raised crit cap")

	check(clock.commands.talents ~= nil, "/talents read-only summary remains")
	equal(clock.commands.talent, nil, "/talent mutation command removed")
	equal(clock.commands.respec, nil, "/respec mutation command removed")

	row("wp11_talent_ui", "tree_buttons", 2,
		"first_free", charged_free, "paid", charged_paid,
		"level_notices", #clock.chat)
	table.sort(failures)
	row("wp11_talent_ui_result", #failures == 0 and "PASS" or "FAIL", #failures)
	for _, failure in ipairs(failures) do
		row("wp11_talent_ui_failure", failure)
	end
	return table.concat(rows, "\n") .. "\n"
end

function M.run(repo)
	local ok, result = pcall(run_checks, repo)
	if ok then
		return result
	end
	return "wp11_talent_ui_failure\tthe fixture raised: " .. tostring(result) ..
		"\nwp11_talent_ui_result\tFAIL\t1\n"
end

return function(repo)
	return M.run(repo)
end
