-- Known-answer test for the HUD BARS (round 4 lane H, 2026-09-16).
--
-- The user's ruling of 2026-09-16 (docs/research/hud-bars-task-card.md
-- section 1) rejects the half-heart statbars -- "half hearts are an ugly
-- approximation" -- and asks for a thin point-accurate life bar plus one
-- mana-OR-rage bar directly above the hotbar. This fixture proves the four
-- things that ruling can actually be broken by:
--
--   A  THE ARITHMETIC. `grug_core.hud_layout.bar_fill` is loaded from the
--      real file and driven over the whole 0..325 hit-point range of a
--      level-60 Warrior (combat_stats.md section 2) and the 0..384 mana pool
--      of a level-60 Mage. It must be monotone, never negative, never wider
--      than the bar, never read FULL while one point is missing and never
--      read EMPTY while one point is left. That last pair is the entire
--      difference between this and a statbar, whose one heart is 16 HP at
--      that level.
--   B  THE LAYOUT. The rows of the shared table must not overlap, must climb
--      away from the hotbar in order, and must hand out well-formed element
--      definitions -- an `image` for a bar, never a `statbar`.
--   C  THE SOURCES. The four offsets that used to live in three different
--      mods must be gone, every `hud_add` in those mods must go through the
--      layout table, and the flag call that hides the builtin hearts and
--      bubbles must be there. A bar with the hearts still on is not the
--      ruling, and a bar whose offsets are guessed again is the defect the
--      card names.
--   D  THE LIVE MOD. The real mods/PLAYER/grug_abilities/init.lua is loaded
--      under a stub engine and its real join callback is driven with a fake
--      player, so what is checked is the elements the engine would actually
--      receive: the flags, the three bars, the colour each class selects,
--      and -- because `hud_change` sends a packet whether the value changed
--      or not -- that an unchanged player costs ZERO packets.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/ui/hud_bars_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/ui/hud_bars_kat.lua")("."))'

local M = {}

local LAYOUT = "mods/CORE/grug_core/hud_layout.lua"
local ABILITIES = "mods/PLAYER/grug_abilities/init.lua"
local XP = "mods/PLAYER/grug_xp/init.lua"
local MONEY = "mods/PLAYER/grug_money/init.lua"

-- combat_stats.md section 2, the level-60 anchors.
local WARRIOR_HP = 325
local MAGE_MANA = 384

local function read(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local body = handle:read("*a")
	handle:close()
	return body
end

-- Load the real layout file on its own. It touches nothing but `grug_core`,
-- which is the whole reason it is a separate file.
local function load_layout(repo)
	local host = {}
	local env = {
		grug_core = host,
		math = math, string = string, table = table,
		type = type, pairs = pairs, ipairs = ipairs, tostring = tostring,
		setmetatable = setmetatable,
	}
	env._G = env
	local chunk, load_error = loadfile(repo .. "/" .. LAYOUT)
	if not chunk then
		return nil, "cannot load " .. LAYOUT .. ": " .. tostring(load_error)
	end
	setfenv(chunk, env)
	local ok, run_error = pcall(chunk)
	if not ok then
		return nil, "loading " .. LAYOUT .. " failed: " .. tostring(run_error)
	end
	return host.hud_layout
end

--
-- The fake player. Only what the join path and the HUD path touch; every
-- other method is a no-op, so a mod that starts calling something new during
-- join shows up as a nil-free but visibly wrong fixture rather than a crash.
--
local function fake_player(name, hp, hp_max, breath, breath_max)
	local noop = function() end
	local player = {
		_name = name,
		_hp = hp,
		_props = {hp_max = hp_max, breath_max = breath_max},
		_breath = breath,
		_elements = {},
		_next_id = 0,
		_writes = {},
		_flags = nil,
	}
	function player:get_player_name()
		return player._name
	end
	function player:get_hp()
		return player._hp
	end
	function player:get_properties()
		-- A fresh table every call, exactly like the engine's.
		return {hp_max = player._props.hp_max,
			breath_max = player._props.breath_max}
	end
	function player:set_properties(props)
		for key, value in pairs(props) do
			player._props[key] = value
		end
	end
	function player:get_breath()
		return player._breath
	end
	function player:hud_add(def)
		player._next_id = player._next_id + 1
		local copy = {}
		for key, value in pairs(def) do
			copy[key] = value
		end
		player._elements[player._next_id] = copy
		return player._next_id
	end
	function player:hud_change(id, stat, value)
		local element = player._elements[id]
		if not element then
			return false
		end
		element[stat] = value
		player._writes[#player._writes + 1] = {id = id, stat = stat,
			value = value}
		return true
	end
	function player:hud_get(id)
		return player._elements[id]
	end
	function player:hud_remove(id)
		player._elements[id] = nil
	end
	function player:hud_set_flags(flags)
		player._flags = flags
	end
	function player:get_wield_index()
		return 1
	end
	function player:get_player_control()
		return {}
	end
	function player:get_wielded_item()
		return {get_name = function() return "" end}
	end
	-- An empty inventory: `sync_kit` runs on join and walks the lists. It has
	-- nothing to grant here (the environment's `dofile` is a no-op, so the
	-- ability catalog never loads), but it must walk something.
	function player:get_inventory()
		local inv = {}
		function inv.get_lists()
			return {main = {}}
		end
		function inv.get_list()
			return {}
		end
		function inv.get_size()
			return 0
		end
		return setmetatable(inv, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end
	function player:get_meta()
		return setmetatable({}, {__index = function()
			return noop
		end})
	end
	function player:is_player()
		return true
	end
	return setmetatable(player, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})
end

--
-- Load the real ability mod under a stub engine. Same shape as
-- tools/wp13/ability_rightclick_kat.lua: `setfenv` keeps the stubs out of
-- this fixture's globals, and the environment's `dofile` is a no-op so the
-- real ability catalog (kits.lua, which needs the whole game) is not pulled
-- in. The four registrations this fixture drives are captured instead of
-- swallowed.
--
local function load_abilities(repo, layout, class_of)
	local noop = function() end
	local hooks = {join = {}, leave = {}, hpchange = {}, globalstep = {}}
	local core_stub = {registered_nodes = {}, registered_items = {},
		registered_entities = {}, registered_tools = {}}

	function core_stub.register_on_joinplayer(func)
		hooks.join[#hooks.join + 1] = func
	end
	function core_stub.register_on_leaveplayer(func)
		hooks.leave[#hooks.leave + 1] = func
	end
	function core_stub.register_on_player_hpchange(func, modifier)
		hooks.hpchange[#hooks.hpchange + 1] = {func = func,
			modifier = modifier}
	end
	function core_stub.register_globalstep(func)
		hooks.globalstep[#hooks.globalstep + 1] = func
	end
	function core_stub.get_modpath()
		return repo .. "/mods/PLAYER/grug_abilities"
	end
	function core_stub.get_current_modname()
		return "grug_abilities"
	end
	function core_stub.get_us_time()
		return 0
	end
	function core_stub.get_connected_players()
		return hooks.connected or {}
	end
	function core_stub.register_tool(itemname, def)
		core_stub.registered_tools[itemname] = def
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	local function stub_table(fields)
		return setmetatable(fields or {}, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end

	local grug_core = stub_table({hud_layout = layout})
	function grug_core.in_combat()
		return false
	end

	local grug_classes = stub_table({registered_classes = {}})
	function grug_classes.get_class_def(player)
		return class_of[player:get_player_name()]
	end
	function grug_classes.get_max_mana(player)
		local def = class_of[player:get_player_name()]
		if not def or def.resource ~= "mana" then
			return 0
		end
		return MAGE_MANA
	end
	function grug_classes.get_race_perk()
		return nil
	end

	local env = {
		core = core_stub,
		vector = stub_table(),
		grug_core = grug_core,
		grug_classes = grug_classes,
		grug_factions = stub_table(),
		grug_xp = stub_table(),
		grug_mobs = stub_table(),
		grug_inventory = stub_table(),
		grug_projectiles = stub_table(),
		grug_gear = stub_table({BRACKETS = {}}),
		dofile = noop,
		math = math, table = table, string = string, os = os, io = io,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, select = select,
		unpack = unpack, error = error, assert = assert, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal,
	}
	env._G = env

	local chunk, load_error = loadfile(repo .. "/" .. ABILITIES)
	if not chunk then
		return nil, "cannot load " .. ABILITIES .. ": " .. tostring(load_error)
	end
	setfenv(chunk, env)
	local ok, run_error = pcall(chunk)
	if not ok then
		return nil, "loading " .. ABILITIES .. " failed: " .. tostring(run_error)
	end
	return {hooks = hooks, env = env, abilities = env.grug_abilities}
end

function M.run(repo)
	repo = repo or "."
	local out, failures = {}, {}

	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local function check(ok, message)
		if not ok then
			failures[#failures + 1] = message
		end
		return ok
	end
	local function finish()
		table.sort(failures)
		row("hud_bars_result", #failures == 0 and "PASS" or "FAIL", #failures)
		for _, message in ipairs(failures) do
			row("hud_bars_failure", message)
		end
		return table.concat(out, "\n") .. "\n"
	end

	local layout, layout_error = load_layout(repo)
	if not check(layout ~= nil, layout_error or "") then
		return finish()
	end

	--
	-- A. the arithmetic
	--
	local width = layout.BAR_WIDTH
	local floor = layout.MIN_FILL
	check(type(width) == "number" and width > 0, "BAR_WIDTH is not a width")
	check(type(floor) == "number" and floor >= 1,
		"MIN_FILL is below one pixel, so a living player can draw nothing")

	row("hud_bars_geometry", "bar_width", tostring(width),
		"bar_height", tostring(layout.BAR_HEIGHT),
		"min_fill", tostring(floor))

	check(layout.bar_fill(0, WARRIOR_HP) == 0, "0 HP does not draw an empty bar")
	check(layout.bar_fill(WARRIOR_HP, WARRIOR_HP) == width,
		"full HP does not draw a full bar")
	check(layout.bar_fill(-5, WARRIOR_HP) == 0, "negative HP draws something")
	check(layout.bar_fill(WARRIOR_HP + 50, WARRIOR_HP) == width,
		"over-full HP draws past the end of the bar")
	check(layout.bar_fill(10, 0) == 0, "a zero maximum draws something")
	check(layout.bar_fill(nil, WARRIOR_HP) == 0, "a nil value draws something")

	-- The two guards that make this not-a-statbar.
	local nearly_full = layout.bar_fill(WARRIOR_HP - 1, WARRIOR_HP)
	local nearly_dead = layout.bar_fill(1, WARRIOR_HP)
	row("hud_bars_resolution", "hp_max", tostring(WARRIOR_HP),
		"at_324", tostring(nearly_full), "at_1", tostring(nearly_dead),
		"full", tostring(width))
	check(nearly_full < width,
		"324 of " .. WARRIOR_HP .. " HP reads as a full bar (" ..
		nearly_full .. " of " .. width .. " px)")
	check(nearly_dead > 0,
		"1 of " .. WARRIOR_HP .. " HP reads as an empty bar")

	-- The same two, over the deepest mana pool in the game.
	check(layout.bar_fill(MAGE_MANA - 1, MAGE_MANA) < width,
		(MAGE_MANA - 1) .. " of " .. MAGE_MANA .. " mana reads as full")
	check(layout.bar_fill(1, MAGE_MANA) > 0,
		"1 of " .. MAGE_MANA .. " mana reads as empty")

	-- Monotone, bounded, and no value in between escapes the guards.
	local function sweep(maximum, label)
		local previous = -1
		local bad_order, bad_bound = 0, 0
		for value = 0, maximum do
			local px = layout.bar_fill(value, maximum)
			if px < previous then
				bad_order = bad_order + 1
			end
			if px < 0 or px > width then
				bad_bound = bad_bound + 1
			end
			if value > 0 and value < maximum and (px <= 0 or px >= width) then
				bad_bound = bad_bound + 1
			end
			previous = px
		end
		row("hud_bars_sweep", label, "max", tostring(maximum),
			"order_faults", tostring(bad_order),
			"bound_faults", tostring(bad_bound))
		check(bad_order == 0, label .. ": the bar is not monotone")
		check(bad_bound == 0,
			label .. ": a partial value drew a full, empty or impossible bar")
	end
	sweep(WARRIOR_HP, "warrior_hp")
	sweep(MAGE_MANA, "mage_mana")
	sweep(100, "rage")
	sweep(10, "breath")

	-- The anchors of combat_stats.md section 2, for the record.
	local anchors = {}
	for _, hp_max in ipairs({30, 75, 175, 325}) do
		anchors[#anchors + 1] = hp_max .. "=" ..
			layout.bar_fill(math.floor(hp_max / 2), hp_max)
	end
	row("hud_bars_half", table.concat(anchors, " "))

	--
	-- B. the layout
	--
	check(#layout.order >= 5, "the column lost rows")
	local previous_top, overlaps, above = nil, 0, 0
	local shape = {}
	for index, id in ipairs(layout.order) do
		local r = layout.rows[id]
		check(r ~= nil, "row " .. id .. " is in the order but not in the table")
		if r then
			shape[#shape + 1] = id .. "=" .. r.top .. ".." .. r.bottom
			check(r.bottom == r.top + r.height, id .. " has an inconsistent height")
			check(r.middle > r.top and r.middle < r.bottom,
				id .. "'s centre is outside its own row")
			check(r.bottom <= 0, id .. " is drawn below the bottom of the screen")
			if previous_top then
				-- The stack climbs: every row sits fully above the last one.
				if r.bottom > previous_top then
					overlaps = overlaps + 1
				end
				if r.top >= previous_top then
					above = above + 1
				end
			end
			previous_top = r.top
		end
		check(index == r.index, id .. " has the wrong index")
	end
	row("hud_bars_rows", table.concat(shape, " "))
	check(overlaps == 0, "two rows of the HUD column overlap")
	check(above == 0, "the HUD column does not climb in order")

	local life = layout.rows.life
	local secondary = layout.rows.secondary
	local breath = layout.rows.breath
	check(life and secondary and breath, "one of the three bar rows is missing")
	if life and secondary and breath then
		check(secondary.kind == "bar" and life.kind == "bar" and
			breath.kind == "bar", "a bar row is not marked as a bar")
		-- The ruling puts the mana/rage bar DIRECTLY above the hotbar slots.
		check(secondary.index == 1,
			"the mana/rage bar is not the row closest to the hotbar")
		check(life.bottom <= secondary.top,
			"the life bar is not above the mana/rage bar")
	end

	local bar_def = layout.bar_element("life", 42, layout.COLOR.life, 1)
	check(bar_def ~= nil and bar_def.type == "image",
		"a bar is not an image element (a statbar is the approximation the " ..
		"ruling rejects)")
	if bar_def then
		check(bar_def.scale.x == 42, "bar_element ignored the width it was given")
		check(bar_def.scale.y == life.height, "a bar is not its row's height")
		check(bar_def.alignment.x == 1 and bar_def.alignment.y == 1,
			"a bar is not anchored at its top left, so it drains from " ..
			"its centre instead of from its end")
		check(bar_def.offset.x == -width / 2, "a bar is not centred")
		check(bar_def.offset.y == life.top, "a bar is not on its own row")
		check(bar_def.text:find("[colorize", 1, true) ~= nil,
			"a bar is not tinted through a texture modifier")
	end
	check(layout.bar_element("life", 0, nil, 0).text == "",
		"a colourless bar still names a texture, so a reserved row draws")
	check(layout.bar_element("xp", 10, 0xffffff, 0) == nil,
		"a text row hands out a bar element")

	local text_def = layout.text_element("xp", {number = 1, text = "x"})
	check(text_def ~= nil and text_def.type == "text",
		"text_element does not produce a text element")
	if text_def then
		check(text_def.offset.y == layout.rows.xp.middle,
			"a text row is not centred on its row")
		check(text_def.alignment.x == 0 and text_def.alignment.y == 0,
			"a text row is not centred")
		check(text_def.number == 1 and text_def.text == "x",
			"text_element dropped the caller's own fields")
	end
	-- The two free anchors keep exactly the positions the elements had
	-- before the table existed.
	local flash_def = layout.text_element("flash", {})
	check(flash_def ~= nil and flash_def.position.y == 0.35 and
		flash_def.position.x == 0.5, "the error flash moved off its anchor")
	local reticle_def = layout.image_element("reticle", {})
	check(reticle_def ~= nil and reticle_def.position.y == 0.5 and
		reticle_def.position.x == 0.5 and reticle_def.scale.x == 1 and
		reticle_def.scale.y == 1, "the weapon-ready reticle moved or resized")
	check(layout.text_element("nonesuch") == nil,
		"an unknown element silently gets a position")

	--
	-- C. the sources
	--
	local sources = {}
	for _, path in ipairs({ABILITIES, XP, MONEY}) do
		local body = read(repo .. "/" .. path)
		if not check(body ~= nil, "cannot read " .. path) then
			return finish()
		end
		sources[path] = body
	end

	local stale = 0
	for _, path in ipairs({ABILITIES, XP, MONEY}) do
		local body = sources[path]
		for _, literal in ipairs({"-135", "-110", "-85", "-70"}) do
			if body:find("y%s*=%s*" .. literal) then
				stale = stale + 1
				check(false, path .. " still writes a literal HUD offset " ..
					literal)
			end
		end
		-- Every HUD element in a consumer mod is built by the layout table.
		local direct = 0
		for tail in body:gmatch("hud_add%s*%(%s*([^\n]*)") do
			if not tail:find("hud_layout") and not tail:find("^layout%.") then
				direct = direct + 1
			end
		end
		check(direct == 0, path .. " builds " .. direct ..
			" HUD element(s) without the shared layout table")
		check(body:find('type%s*=%s*"statbar"') == nil,
			path .. " registers a statbar")
	end
	row("hud_bars_sources", "stale_offsets", tostring(stale))

	local abilities_body = sources[ABILITIES]
	check(abilities_body:find("hud_set_flags") ~= nil,
		"nothing turns the builtin bars off, so the hearts are still there")
	check(abilities_body:find("healthbar%s*=%s*false") ~= nil,
		"the builtin health statbar is not switched off")
	check(abilities_body:find("breathbar%s*=%s*false") ~= nil,
		"the builtin breath statbar is not switched off")

	--
	-- D. the live mod
	--
	local classes = {
		warrior = {id = "warrior", resource = "rage"},
		mage = {id = "mage", resource = "mana"},
		none = nil,
	}
	local class_of = {}
	local loaded, load_error = load_abilities(repo, layout, class_of)
	if not check(loaded ~= nil, load_error or "") then
		return finish()
	end
	check(#loaded.hooks.join >= 1, "the mod registers no join callback")
	check(#loaded.hooks.leave >= 1, "the mod registers no leave callback")
	check(#loaded.hooks.hpchange >= 1,
		"nothing reacts to a hit point change any more")

	local function join(name, class, hp, hp_max, breath, breath_max)
		class_of[name] = class
		local player = fake_player(name, hp, hp_max, breath, breath_max)
		for _, func in ipairs(loaded.hooks.join) do
			func(player)
		end
		player._writes = {}
		return player
	end

	-- Element bookkeeping: find the three elements of one row by their
	-- offset, which is the layout's own answer.
	local function row_elements(player, id)
		local r = layout.rows[id]
		local bars, label = {}, nil
		for _, element in pairs(player._elements) do
			if element.type == "image" and element.offset and
					element.offset.y == r.top then
				bars[#bars + 1] = element
			elseif element.type == "text" and element.offset and
					element.offset.y == r.middle then
				label = element
			end
		end
		return bars, label
	end

	local warrior = join("warrior_kat", classes.warrior, WARRIOR_HP,
		WARRIOR_HP, 10, 10)
	check(warrior._flags ~= nil and warrior._flags.healthbar == false and
		warrior._flags.breathbar == false,
		"joining does not hide the builtin hearts and bubbles")

	local counts = {}
	for _, id in ipairs({"life", "secondary", "breath"}) do
		local bars, label = row_elements(warrior, id)
		counts[#counts + 1] = id .. "=" .. #bars .. "+" .. (label and 1 or 0)
		check(#bars == 2, id .. " is not a track plus a foreground (" ..
			#bars .. " image elements)")
		check(label ~= nil, id .. " has no number label inside it")
	end
	row("hud_bars_elements", table.concat(counts, " "))

	-- The Warrior is at full health and full breath: a full life bar, a rage
	-- bar at zero, and nothing at all in the breath row.
	local function fill_of(player, id)
		local bars = row_elements(player, id)
		local track, fore
		for _, element in ipairs(bars) do
			if element.scale.x == layout.BAR_WIDTH and element.z_index == 0 then
				track = element
			else
				fore = element
			end
		end
		-- The foreground is the one that is NOT the full-width track; at full
		-- value both are full width, so fall back on z_index.
		if not fore then
			for _, element in ipairs(bars) do
				if element.z_index ~= 0 then
					fore = element
				end
			end
		end
		if not track then
			for _, element in ipairs(bars) do
				if element.z_index == 0 then
					track = element
				end
			end
		end
		return track, fore
	end

	local life_track, life_fore = fill_of(warrior, "life")
	check(life_track ~= nil and life_track.text ~= "",
		"the life bar has no track")
	check(life_fore ~= nil and life_fore.scale.x == layout.BAR_WIDTH,
		"a Warrior at full health does not draw a full life bar")

	local rage_track, rage_fore = fill_of(warrior, "secondary")
	check(rage_fore ~= nil and rage_fore.scale.x == 0,
		"a Warrior at 0 rage draws a filled bar")
	check(rage_fore ~= nil and
		rage_fore.text:find(("%06x"):format(layout.COLOR.rage), 1, true) ~= nil,
		"the Warrior's secondary bar is not the rage colour")
	check(rage_track ~= nil and rage_track.text ~= "",
		"the rage bar has no track")

	local breath_track = fill_of(warrior, "breath")
	check(breath_track ~= nil and breath_track.text == "",
		"the breath bar is drawn while the player is not short of air")

	-- The exact numbers live INSIDE the bars (coordinator decision 1 on the
	-- card's open question 1) -- and the old separate "Mana 84 / 148" line
	-- is gone.
	local _, life_label = row_elements(warrior, "life")
	check(life_label ~= nil and
		life_label.text == WARRIOR_HP .. " / " .. WARRIOR_HP,
		"the life bar does not carry the exact numbers")
	check(abilities_body:find('"Mana %%d / %%d"') == nil and
		abilities_body:find('"Rage %%d / 100"') == nil,
		"the separate resource text line is still registered")

	-- A Mage gets the mana colour; a character with no class yet gets a
	-- reserved but blank row, and the row above it does not move.
	local mage = join("mage_kat", classes.mage, 148, 148, 10, 10)
	local _, mana_fore = fill_of(mage, "secondary")
	check(mana_fore ~= nil and
		mana_fore.text:find(("%06x"):format(layout.COLOR.mana), 1, true) ~= nil,
		"the Mage's secondary bar is not the mana colour")
	check(mana_fore ~= nil and mana_fore.scale.x == layout.BAR_WIDTH,
		"a Mage joins without a full mana bar")

	local classless = join("classless_kat", nil, 30, 30, 10, 10)
	local blank_track, blank_fore = fill_of(classless, "secondary")
	check(blank_track ~= nil and blank_track.text == "",
		"a character with no class draws an empty track")
	check(blank_fore ~= nil and blank_fore.scale.x == 0,
		"a character with no class draws a secondary fill")
	local classless_life = select(1, fill_of(classless, "life"))
	check(classless_life ~= nil and
		classless_life.offset.y == layout.rows.life.top,
		"the life row moved for a character with no class")

	-- The packet gate. `hud_change` sends on every call, so an unchanged
	-- player must produce no calls at all. The shared 0.5 s pass is the
	-- worst cadence there is.
	local step = loaded.hooks.globalstep
	check(#step >= 1, "the mod has no globalstep to ride")
	loaded.env.core.get_connected_players = function()
		return {warrior}
	end
	warrior._writes = {}
	for _ = 1, 4 do
		for _, func in ipairs(step) do
			func(0.6)
		end
	end
	row("hud_bars_idle_packets", tostring(#warrior._writes), "over",
		"4 ticks")
	check(#warrior._writes == 0,
		"an idle player costs " .. #warrior._writes ..
		" HUD packet(s) per 4 ticks")

	-- One hit point lost: the bar moves, the label moves, and nothing else
	-- is written.
	warrior._hp = WARRIOR_HP - 1
	warrior._writes = {}
	for _, func in ipairs(step) do
		func(0.6)
	end
	local moved_scale, moved_text = 0, 0
	for _, write in ipairs(warrior._writes) do
		if write.stat == "scale" then
			moved_scale = moved_scale + 1
		elseif write.stat == "text" then
			moved_text = moved_text + 1
		end
	end
	row("hud_bars_one_point", "scale_writes", tostring(moved_scale),
		"text_writes", tostring(moved_text),
		"total", tostring(#warrior._writes))
	check(moved_text == 1, "losing one hit point does not update the number")
	check(#warrior._writes <= 2,
		"one hit point costs " .. #warrior._writes .. " HUD packets")
	local _, hurt_fore = fill_of(warrior, "life")
	check(hurt_fore ~= nil and hurt_fore.scale.x < layout.BAR_WIDTH,
		"a Warrior one hit point down still reads as untouched")

	-- Under water: the breath row fills in and empties out again.
	warrior._breath = 4
	warrior._writes = {}
	for _, func in ipairs(step) do
		func(0.6)
	end
	local water_track, water_fore = fill_of(warrior, "breath")
	local _, water_label = row_elements(warrior, "breath")
	check(water_track ~= nil and water_track.text ~= "",
		"the breath bar does not appear under water")
	check(water_fore ~= nil and water_fore.scale.x > 0 and
		water_fore.scale.x < layout.BAR_WIDTH,
		"the breath bar does not show a partial value")
	check(water_label ~= nil and water_label.text == "4 / 10",
		"the breath bar carries no numbers")
	warrior._breath = 10
	for _, func in ipairs(step) do
		func(0.6)
	end
	local dry_track = fill_of(warrior, "breath")
	check(dry_track ~= nil and dry_track.text == "",
		"the breath bar does not disappear once the air is back")

	-- Taking a hit. The engine runs EVERY non-modifier callback, in
	-- registration order, and only then stores the new hit points
	-- (`builtin/game/register.lua:560`, `src/server/player_sao.cpp:519-535`).
	-- So the fixture runs them all, with `get_hp()` still returning the old
	-- value throughout -- which is exactly how the rage hook, registered
	-- after the HUD hook, used to paint the life bar back to full.
	local loggers = 0
	for _, entry in ipairs(loaded.hooks.hpchange) do
		if not entry.modifier then
			loggers = loggers + 1
		end
	end
	row("hud_bars_hpchange_loggers", tostring(loggers))
	if check(loggers >= 1, "the HUD registers no hit point change callback") then
		warrior._hp = WARRIOR_HP
		for _, func in ipairs(step) do
			func(0.6)
		end
		for _, entry in ipairs(loaded.hooks.hpchange) do
			if not entry.modifier then
				entry.func(warrior, -100, {type = "punch"})
			end
		end
		local _, predicted = fill_of(warrior, "life")
		local expected = layout.bar_fill(WARRIOR_HP - 100, WARRIOR_HP)
		row("hud_bars_prediction", "expected", tostring(expected),
			"drawn", tostring(predicted and predicted.scale.x))
		check(predicted ~= nil and predicted.scale.x == expected,
			"the life bar does not follow a hit before the engine stores it")

		-- And the shared pass takes the real value back over: the engine
		-- clamped the hit to 250 rather than the 225 that was predicted.
		warrior._hp = 250
		for _, func in ipairs(step) do
			func(0.6)
		end
		local _, corrected = fill_of(warrior, "life")
		check(corrected ~= nil and
			corrected.scale.x == layout.bar_fill(250, WARRIOR_HP),
			"the prediction is never corrected by the shared pass")
	end

	-- Leaving drops the ids.
	for _, func in ipairs(loaded.hooks.leave) do
		func(warrior)
	end
	warrior._writes = {}
	loaded.env.core.get_connected_players = function()
		return {}
	end
	for _, func in ipairs(step) do
		func(0.6)
	end
	check(#warrior._writes == 0, "a player who left is still being drawn")

	return finish()
end

return function(repo)
	return M.run(repo)
end
