-- 0.49.1 lane VIEW portable test (fix-0.49.1-plan.md ruling 6, §4 VIEW):
-- every station form shows the player's whole combined bag through
-- grug_inventory's station view. Through tools/r44_ch/harness.lua (the REAL
-- sfinv, grug_inventory equipment/bags/ui/pages) plus the real inbox.lua,
-- default/node_formspec.lua, default/furnace.lua, default/chests.lua,
-- default/nodes.lua (the bookshelf), vessels/init.lua,
-- grug_housing/stone_form.lua and grug_jobs/workspaces.lua under a small
-- fake engine, for players with 0, 1 and 4 bags it checks per form:
--   L  the lists: formspec_version 6 and the station width; the station's
--      own lists above the view; main[9..] and every bag's content list in
--      one scroll_container three rows high; the hotbar main[1..8] below it,
--      outside the scroll area, the only player list outside it;
--   R  the rings: a station list -> the inbox, main -> the station's list as
--      before, every bag -> the same list as main (none for an empty slot);
--      a modelled shift-click from a bag lands in the station's list;
--   S  the scroll position: a pure scrollbar event re-sends nothing, the
--      next re-show (node_formspec.refresh, the workspace's one-second
--      re-show, a Claim Stone redraw) echoes it, clamped to the range;
--   V  per viewer: two players at one bookshelf get their own bags.
--
-- Usage (repo root): luajit tools/r491_view/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)
dofile(repo .. "/mods/PLAYER/grug_inventory/inbox.lua")

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end

--
-- The fake engine around the harness
--

local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local noop = function() end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}
function table.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

local function node_inventory()
	local lists = {}
	local inv = {}
	function inv:set_size(list, size)
		lists[list] = lists[list] or {}
		for i = 1, size do lists[list][i] = lists[list][i] or ItemStack("") end
	end
	function inv:get_size(list) return #(lists[list] or {}) end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_lists() return lists end
	function inv:set_list(list, values)
		lists[list] = {}
		for i, v in ipairs(values) do lists[list][i] = ItemStack(v) end
	end
	function inv:get_stack(list, i) return ItemStack(lists[list] and lists[list][i] or "") end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
	function inv:is_empty(list)
		for _, s in ipairs(lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	return inv
end

local nodes, metas, players = {}, {}, {}
local function meta_at(pos)
	local k = key(pos)
	if not metas[k] then
		local store, inv = {}, node_inventory()
		metas[k] = {
			get_string = function(_, f) return store[f] or "" end,
			set_string = function(_, f, v) store[f] = v end,
			get_int = function(_, f) return math.floor(tonumber(store[f]) or 0) end,
			set_int = function(_, f, v) store[f] = v end,
			get_float = function(_, f) return tonumber(store[f]) or 0 end,
			set_float = function(_, f, v) store[f] = v end,
			get_inventory = function() return inv end,
			mark_as_private = function() end,
			to_table = function() return {fields = store} end,
		}
	end
	return metas[k]
end

local shown = {}
local registered_nodes = {}
local receivers, globalsteps = {}, {}
core.registered_nodes = registered_nodes
core.show_formspec = function(name, formname, formspec)
	shown[#shown + 1] = {name = name, form = formname, formspec = formspec}
end
core.close_formspec = function(name, formname) core.show_formspec(name, formname, "") end
core.get_node_or_nil = function(pos)
	local name = nodes[key(pos)]
	return name and {name = name, param2 = 0} or nil
end
core.get_node = function(pos) return core.get_node_or_nil(pos) or {name = "air"} end
core.swap_node = function(pos, node) nodes[key(pos)] = node.name end
core.get_meta = meta_at
core.get_player_by_name = function(name) return players[name] end
core.get_node_timer = function()
	return {start = function() end, stop = function() end, is_started = function() return true end}
end
core.get_gametime = function() return 100 end
core.get_us_time = function() return 1 end
core.after = function(_, fn, ...) return fn(...) end
core.sound_play = function() end
core.hash_node_position = function(pos) return key(pos) end
core.item_eat = function() return noop end
core.get_translator = function() return function(s) return s end end
core.serialize = function() return "return {}" end
core.deserialize = function() return nil end
core.register_node = function(name, def)
	registered_nodes[name:gsub("^:", "")] = def
end
core.override_item = function(name, fields)
	for k, v in pairs(fields) do registered_nodes[name][k] = v end
end
core.register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end
core.register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end
core.create_detached_inventory = function() return node_inventory() end
core.remove_detached_inventory = function() end

local function submit(player, formname, fields)
	for _, fn in ipairs(receivers) do
		if fn(player, formname, fields) then return true end
	end
	return false
end
local function last_shown(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

-- Players through the harness (real bag lists), with an hp and a place.
local function new_player(name, bags)
	local p = H.player(name, "warrior", bags)
	function p:get_hp() return 20 end
	players[name] = p
	return p
end

--
-- The real form files
--

default = setmetatable({
	get_translator = function(s) return s end,
	get_inventory_drops = noop,
	set_inventory_action_loggers = noop,
	can_interact_with_node = function() return true end,
	LIGHT_MAX = 14,
}, {__index = function()
	-- default.node_sound_*_defaults, register_fence and the other helpers
	-- nodes.lua calls at load time: nothing they return matters here.
	return noop
end})
dofile(repo .. "/mods/BASE/default/node_formspec.lua")
dofile(repo .. "/mods/BASE/default/furnace.lua")
dofile(repo .. "/mods/BASE/default/chests.lua")
dofile(repo .. "/mods/BASE/vessels/init.lua")

-- nodes.lua registers every default node; only the bookshelf is used, the
-- rest loads through permissive stubs.
do
	local real_get_mapgen_setting = core.get_mapgen_setting
	core.get_mapgen_setting = function() return "" end
	core.register_alias = noop
	core.register_lbm = noop
	core.register_craft = noop
	local ok, err = pcall(dofile, repo .. "/mods/BASE/default/nodes.lua")
	check(ok, "default/nodes.lua loads (" .. tostring(err) .. ")")
	core.get_mapgen_setting = real_get_mapgen_setting
end

-- The Claim Stone form (grug_housing/stone_form.lua) with its ui helpers and
-- a placed, active claim.
local CLAIM = {id = 7, owner = "stone", center = {x = 0, y = 0, z = 0},
	permissions = {}}
grug_housing = {
	ACTIVATION_LUMPS = 4, LUMP_SECONDS = 26160, FUEL_MAX = 99, PICKUP_LOCK_SECONDS = 43200,
	player_claim = function(name) if name == CLAIM.owner then return CLAIM, "placed" end end,
	permission = function(claim, name) return name == claim.owner and "owner" or nil end,
	is_draft = function() return false end,
	is_active = function() return true end,
	remaining_seconds = function() return 86400 * 3 end,
	pickup_wait = function() return 0 end,
	is_fuel = function() return true end,
}
local stone_ui = {
	esc = function(text) return core.formspec_escape(text) end,
	text = function(text) return core.formspec_escape(text) end,
	lumps = function(seconds) return math.ceil(seconds / 26160) end,
	format_remaining = function() return "3 d" end,
	DAY = 86400, RED = "#ff6060", DISPLAY_FUEL = "default:coal_lump",
}
dofile(repo .. "/mods/PLAYER/grug_housing/stone_form.lua")(stone_ui)

-- The profession workspaces (grug_jobs/workspaces.lua) with a stand-in for
-- the automatic process (its own fixtures test it).
grug_core.interaction_protected = function() return false end
local public = {}
grug_jobs = {
	station_info = function(station)
		return station == "furnace" and {display_name = "Furnace", node = "default:furnace"} or
			{display_name = "Dual Furnace", node = "grug_smelting:dual_furnace"}
	end,
	is_public_station = function(_, pos) return public[key(pos)] == true end,
}
local fractions = {0, 0}
local stub_automatic = {sizes = {furnace = {src = 1, fuel = 1, dst = 4},
	dual_furnace = {input = 2, fuel = 1, output = 2}},
	advance = noop, running = function() return false end,
	fractions = function() return fractions[1], fractions[2] end,
	fuel_time = function() return 0 end, personal_light_deadline = function() return 0 end,
	personal_light_active = function() return false end}
local workspaces
do
	local real_dofile = dofile
	dofile = function(file)
		if file:match("/automatic%.lua$") then return stub_automatic end
		return real_dofile(file)
	end
	core.get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end
	workspaces = real_dofile(repo .. "/mods/PLAYER/grug_jobs/workspaces.lua")
	dofile = real_dofile
end

--
-- Reading a station form
--

local STATION = grug_inventory.STATION
local SCROLL = grug_inventory.SCROLL_FIELDS.station
local PITCH = STATION.pitch

local function num(s) return tonumber(s) end

-- The parts of a form: size, the scroll container's geometry and lists, the
-- lists outside it, the scrollbar value.
local function parse(fs)
	local form = {lists = {}, inner = {}}
	local w, h = fs:match("^formspec_version%[6%]size%[([%d.]+),([%d.]+)%]")
	form.w, form.h = num(w), num(h)
	local before, inside, after = fs:match("^(.*)scroll_container%[(.-)scroll_container_end%[%](.*)$")
	form.container = inside ~= nil
	if not inside then return form end
	local cx, cy, cw, ch, field = inside:match("^([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+);vertical;")
	form.cx, form.cy, form.cw, form.ch, form.field = num(cx), num(cy), num(cw), num(ch), field
	for loc, list, x, y, lw, lh, start in inside:gmatch(
			"list%[([^;]+);([^;]+);([%d.]+),([%d.]+);(%d+),(%d+);(%d*)%]") do
		form.inner[#form.inner + 1] = {loc = loc, list = list, x = num(x), y = num(y),
			w = num(lw), h = num(lh), start = num(start) or 0}
	end
	for _, part in ipairs({before, after}) do
		for loc, list, x, y, lw, lh, start in part:gmatch(
				"list%[([^;]+);([^;]+);([%d.]+),([%d.]+);(%d+),(%d+);(%d*)%]") do
			form.lists[#form.lists + 1] = {loc = loc, list = list, x = num(x), y = num(y),
				w = num(lw), h = num(lh), start = num(start) or 0}
		end
	end
	form.scroll = num(fs:match("scrollbar%[[^%]]*;vertical;" .. SCROLL .. ";(%d+)%]"))
	return form
end

-- The engine's getNextInventoryRing: the entry after the FIRST one naming
-- the list.
local function next_ring(fs, location, list)
	local rings = H.rings(fs)
	for i, ring in ipairs(rings) do
		if ring.location == location and ring.list == list then
			local to = rings[i % #rings + 1]
			return to.location .. ";" .. to.list
		end
	end
end

local BAGS = {
	none = {},
	one = {16},
	four = {16, 8, 16, 8},
}
local function bag_lists(player)
	local out = {}
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		if player:get_inventory():get_size(list) > 0 then out[#out + 1] = list end
	end
	return out
end

-- The checks every station form shares. `station` = {location, lists =
-- {own list names}, target = the list main and the bags ring to}.
local function check_form(label, player, fs, station)
	local form = parse(fs)
	eq(form.w, tonumber(("%.3f"):format(STATION.width)), label .. ": L the station width")
	check(form.container, label .. ": L a scroll container")
	if not form.container then return form end
	eq(form.field, SCROLL, label .. ": L the station view's scroll field")
	eq(form.ch, 3 * PITCH - 0.25, label .. ": L three rows visible")
	-- main[9..] and the bags, in order, inside the scroll area.
	local seen, slots = {}, {}
	for _, l in ipairs(form.inner) do
		check(l.loc == "current_player", label .. ": L only the player's lists scroll")
		seen[l.list] = true
		slots[l.list] = (slots[l.list] or 0) + l.w * l.h
	end
	eq(slots.main, 24, label .. ": L main[9..] scrolls")
	eq(form.inner[1] and form.inner[1].start, 8, label .. ": L the grid starts at main[9]")
	for _, list in ipairs(bag_lists(player)) do
		eq(slots[list], player:get_inventory():get_size(list), label .. ": L " .. list .. " scrolls")
	end
	for i = #bag_lists(player) + 1, grug_inventory.BAG_COUNT do
		check(not seen[grug_inventory.content_list(i)], label .. ": L no list for empty bag slot " .. i)
	end
	-- Outside: the hotbar below the scroll area, the station's own lists above.
	local hotbar, own = 0, 0
	for _, l in ipairs(form.lists) do
		if l.loc == "current_player" then
			check(l.list == "main" and l.w == 8 and l.h == 1 and l.start == 0,
				label .. ": L the only player list outside is the hotbar (" .. l.list .. ")")
			check(l.y > form.cy + form.ch, label .. ": L the hotbar is below the scroll area")
			eq(l.x, form.cx, label .. ": L the hotbar under the grid's columns")
			hotbar = hotbar + 1
		else
			own = own + 1
			check(l.y + l.h * PITCH - 0.25 < form.cy, label .. ": L " .. l.list .. " above the view")
			check(l.x + l.w * PITCH - 0.25 <= form.w, label .. ": L " .. l.list .. " inside the form")
		end
		check(l.y + l.h * PITCH - 0.25 <= form.h, label .. ": L " .. l.list .. " inside the form height")
	end
	eq(hotbar, 1, label .. ": L one hotbar")
	eq(own, #station.lists, label .. ": L the station's own lists")
	-- Rings.
	for _, list in ipairs(station.lists) do
		if station.inbox ~= false then
			eq(next_ring(fs, station.location, list), "current_player;grug_inbox",
				label .. ": R " .. list .. " -> the inbox")
		end
	end
	local target = station.location .. ";" .. station.target
	eq(next_ring(fs, "current_player", "main"), target, label .. ": R main -> " .. station.target)
	for _, list in ipairs(bag_lists(player)) do
		eq(next_ring(fs, "current_player", list), target, label .. ": R " .. list .. " -> " ..
			station.target .. ", like main")
	end
	for i = #bag_lists(player) + 1, grug_inventory.BAG_COUNT do
		eq(next_ring(fs, "current_player", grug_inventory.content_list(i)), nil,
			label .. ": R no ring for empty bag slot " .. i)
	end
	return form
end

-- The scroll range of a player's view: rows beyond three, ten units each.
local function scroll_max(player)
	local slots = 24
	for _, list in ipairs(bag_lists(player)) do slots = slots + player:get_inventory():get_size(list) end
	return math.max(0, math.ceil(slots / 8) - 3) * 10
end

-- Stand the player beside `pos` (node_formspec and the workspaces check the
-- reach).
local function near(player, pos)
	player.get_pos = function() return {x = pos.x + 1, y = pos.y, z = pos.z} end
end

local serial = 0
local function place(name)
	serial = serial + 1
	local pos = {x = serial * 3, y = 0, z = 0}
	nodes[key(pos)] = name
	local def = registered_nodes[name]
	if def and def.on_construct then def.on_construct(pos) end
	return pos, def
end

--
-- The node_formspec forms: furnace (default), bookshelf, vessels shelf
--

local NODE_FORM = default.node_formspec.formname

-- Open the node's form, check it, then the scroll: a pure event sends
-- nothing, a refresh echoes the value, an over-range value is clamped.
local function node_form_case(label, node, station, bags_key, prepare)
	local player = new_player(label:gsub("%W", "") .. "_" .. bags_key, BAGS[bags_key])
	local pos, def = place(node)
	near(player, pos)
	station.location = default.node_formspec.location(pos)
	if prepare then prepare(pos) end
	def.on_rightclick(pos, {name = node}, player, ItemStack(""))
	local last = last_shown(player:get_player_name())
	eq(last and last.form, NODE_FORM, label .. " " .. bags_key .. ": opens through node_formspec")
	local fs = last and last.formspec or ""
	local form = check_form(label .. " " .. bags_key, player, fs, station)
	local max = scroll_max(player)
	eq(form.scroll, max > 0 and 0 or nil, label .. " " .. bags_key ..
		": S a scrollbar only when the bags need one, at the top")
	if max > 0 then
		local before = #shown
		check(submit(player, NODE_FORM, {[SCROLL] = "CHG:10"}),
			label .. " " .. bags_key .. ": S the scroll event is handled")
		eq(#shown, before, label .. " " .. bags_key .. ": S a pure scroll event sends nothing")
		default.node_formspec.refresh(pos)
		eq(parse(last_shown(player:get_player_name()).formspec).scroll, 10,
			label .. " " .. bags_key .. ": S the re-show keeps the scroll position")
		submit(player, NODE_FORM, {[SCROLL] = "VAL:" .. (max + 50), something = "x"})
		default.node_formspec.refresh(pos)
		eq(parse(last_shown(player:get_player_name()).formspec).scroll, max,
			label .. " " .. bags_key .. ": S a value from any event, clamped to the range")
	end
	submit(player, NODE_FORM, {quit = "true"})
	return fs, player, pos
end

for _, bags_key in ipairs({"none", "one", "four"}) do
	node_form_case("furnace", "default:furnace",
		{lists = {"src", "fuel", "dst"}, target = "src"}, bags_key)
	local fs = node_form_case("burning furnace", "default:furnace_active",
		{lists = {"src", "fuel", "dst"}, target = "src"}, bags_key, function(pos)
			meta_at(pos):set_int("fuel_percent", 40)
			meta_at(pos):set_int("item_percent", 70)
		end)
	check(fs:find("default_furnace_fire_bg.png^[lowpart:40:default_furnace_fire_fg.png", 1, true),
		"burning furnace " .. bags_key .. ": the fire at its percentage")
	check(fs:find("gui_furnace_arrow_bg.png^[lowpart:70:gui_furnace_arrow_fg.png^[transformR270", 1, true),
		"burning furnace " .. bags_key .. ": the arrow at its percentage")
	local shelf = node_form_case("bookshelf", "default:bookshelf",
		{lists = {"books"}, target = "books"}, bags_key)
	local _, empties = shelf:gsub("default_bookshelf_slot%.png", "")
	eq(empties, 16, "bookshelf " .. bags_key .. ": an empty slot picture per empty slot")
	local vessels = node_form_case("vessels shelf", "vessels:shelf",
		{lists = {"vessels"}, target = "vessels"}, bags_key)
	local _, vessel_empties = vessels:gsub("vessels_shelf_slot%.png", "")
	eq(vessel_empties, 16, "vessels shelf " .. bags_key .. ": an empty slot picture per empty slot")
end

-- A modelled shift-click from a bag at the bookshelf: into the shelf.
do
	local player = new_player("shifter", {16})
	local pos, def = place("default:bookshelf")
	near(player, pos)
	def.on_rightclick(pos, {name = "default:bookshelf"}, player, ItemStack(""))
	local fs = last_shown("shifter").formspec
	eq(next_ring(fs, "current_player", "grug_bag1_content"),
		default.node_formspec.location(pos) .. ";books", "R a bag shift-click targets the shelf")
end

-- V: two viewers of one bookshelf, each with their own bags; a refresh
-- re-shows each their own form.
do
	local light = new_player("light", {})
	local heavy = new_player("heavy", {16, 8, 16, 8})
	local pos, def = place("default:bookshelf")
	near(light, pos)
	near(heavy, pos)
	def.on_rightclick(pos, {name = "default:bookshelf"}, light, ItemStack(""))
	def.on_rightclick(pos, {name = "default:bookshelf"}, heavy, ItemStack(""))
	meta_at(pos):get_inventory():set_stack("books", 1, ItemStack("default:book"))
	default.node_formspec.refresh(pos)
	local a, b = last_shown("light").formspec, last_shown("heavy").formspec
	check(not a:find("grug_bag1_content", 1, true), "V a viewer without bags gets no bag list")
	check(b:find("grug_bag4_content", 1, true) ~= nil, "V a viewer with four bags gets all four")
	local _, empties = a:gsub("default_bookshelf_slot%.png", "")
	eq(empties, 15, "V the refresh shows the new book to both viewers")
end

--
-- Chests (core.show_formspec, never re-shown while open)
--

for _, bags_key in ipairs({"none", "one", "four"}) do
	for _, node in ipairs({"default:chest", "default:chest_locked"}) do
		local player = new_player("chest_" .. bags_key .. node:gsub("%W", ""), BAGS[bags_key])
		local pos, def = place(node)
		def.on_rightclick(pos, {name = node, param2 = 0}, player, ItemStack(""))
		local last = last_shown(player:get_player_name())
		eq(last and last.form, "default:chest", node .. " " .. bags_key .. ": the chest form")
		check_form(node .. " " .. bags_key, player, last and last.formspec or "",
			{location = "nodemeta:" .. key(pos), lists = {"main"}, target = "main"})
		submit(player, "default:chest", {quit = "true"})
	end
end

--
-- The Claim Stone form
--

for _, bags_key in ipairs({"none", "one", "four"}) do
	local name = "stone"
	players[name] = nil
	local player = new_player(name, BAGS[bags_key])
	check(grug_housing.open_stone_interface(player, CLAIM), "stone " .. bags_key .. ": opens")
	local fs = last_shown(name).formspec
	local label = "stone " .. bags_key
	check_form(label, player, fs, {location = "detached:grug_housing_fuel_" .. name,
		lists = {"fuel"}, target = "fuel", inbox = false})
	check(fs:find("button_exit[7.25,6.75;3.1,0.8;close;Close]", 1, true) ~= nil,
		label .. ": the stone's own content is kept")
	local max = scroll_max(player)
	if max > 0 then
		local before = #shown
		check(submit(player, "grug_housing:stone", {[SCROLL] = "CHG:10", perm_name = "zed"}),
			label .. ": S the scroll event is handled")
		eq(#shown, before, label .. ": S a pure scroll event redraws nothing")
		submit(player, "grug_housing:stone", {[SCROLL] = "VAL:10", stone_tab = "1"})
		fs = last_shown(name).formspec
		eq(parse(fs).scroll, 10, label .. ": S the redraw keeps the scroll position")
		check(fs:find("perm_name;Player name;zed]", 1, true) ~= nil,
			label .. ": S the typed name survives the scroll event")
	end
	submit(player, "grug_housing:stone", {quit = "true"})
end

--
-- The profession workspaces (furnace and dual furnace, shared and personal)
--

local WORKSPACE = "grug_jobs:workspace"
for _, bags_key in ipairs({"none", "one", "four"}) do
	for _, case in ipairs({
		{station = "furnace", node = "default:furnace", personal = false,
			lists = {"dst", "src", "fuel"}, target = "src"},
		{station = "furnace", node = "default:furnace", personal = true,
			lists = {"dst", "src", "fuel"}, target = "src"},
		{station = "dual_furnace", node = "grug_smelting:dual_furnace", personal = false,
			lists = {"output", "input", "fuel"}, target = "input"},
	}) do
		local label = ("workspace %s %s %s"):format(case.station,
			case.personal and "personal" or "shared", bags_key)
		local name = label:gsub("%W", "")
		local player = new_player(name, BAGS[bags_key])
		registered_nodes[case.node] = registered_nodes[case.node] or {}
		registered_nodes[case.node]._grug_station = case.station
		local pos = place(case.node)
		near(player, pos)
		public[key(pos)] = case.personal or nil
		fractions = {0.4, 0.7}
		check(workspaces.open(pos, player), label .. ": opens")
		local last = last_shown(name)
		eq(last and last.form, WORKSPACE, label .. ": the workspace form")
		local fs = last and last.formspec or ""
		local location = case.personal and fs:match("list%[(detached:[^;]+);") or
			"nodemeta:" .. key(pos)
		check_form(label, player, fs, {location = location, lists = case.lists,
			target = case.target})
		check(fs:find("default_furnace_fire_bg.png^[lowpart:40:default_furnace_fire_fg.png", 1, true),
			label .. ": the fire at its percentage")
		check(fs:find("gui_furnace_arrow_bg.png^[lowpart:70:gui_furnace_arrow_fg.png", 1, true),
			label .. ": the arrow at its percentage")
		local max = scroll_max(player)
		if max > 0 then
			local before = #shown
			check(submit(player, WORKSPACE, {[SCROLL] = "CHG:10"}), label .. ": S the scroll event is handled")
			eq(#shown, before, label .. ": S a pure scroll event re-sends nothing")
			-- The one-second re-show of the burning furnace.
			for _, step in ipairs(globalsteps) do step(1.1) end
			eq(#shown, before + 1, label .. ": S the one-second re-show")
			eq(parse(last_shown(name).formspec).scroll, 10, label .. ": S the re-show keeps the scroll position")
			submit(player, WORKSPACE, {[SCROLL] = "VAL:" .. max, something = "x"})
			eq(parse(last_shown(name).formspec).scroll, max, label .. ": S another event keeps it too")
		end
		submit(player, WORKSPACE, {quit = "true"})
	end
end

if failures > 0 then
	print(("R491 VIEW PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R491 VIEW PORTABLE PASS checks=%d"):format(checks))
