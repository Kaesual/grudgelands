-- Round 67 lane CONTAINERS portable test (round67-plan.md rulings 27-33,
-- §6 CONTAINERS). Through tools/r44_ch/harness.lua (the REAL grug_inventory:
-- storage, ui, pages) plus the real default/node_formspec.lua,
-- default/containers.lua, default/chests.lua, default/nodes.lua (the
-- bookshelf), vessels/init.lua, the real claim model
-- (grug_housing/registry.lua) and interaction guard
-- (grug_housing/interaction.lua) under a small fake engine, it checks:
--   S  the player's sort byte-identical to the base commit 9fcf8093 (the
--      digest of sort_cases.lua's 60 cases, the 0.48.0 step's `sizes`
--      included) and a chest's Sort: the inventory's order over the whole
--      list, the shared cooldown, no Sort on shelves or for a locked
--      chest's non-owner;
--   L  the label: the field and its rights in the open world, an own claim,
--      a foreign claim with and without "everything", a draft claim and a
--      locked chest; 40 characters, control characters; the hover text;
--   U  the upgrade: 8 bars charged from the carried lists, the node swapped
--      with its meta and contents, the list grown, the next tier's bar, none
--      at the last tier, refused without bars or rights; an open chest with
--      a second viewer: both forms follow at their kept scroll position and
--      the lid closes on the new tier; a shelf's form stays open;
--   F  the form: four visible rows, the scrollbar beyond them, the rings,
--      the shelves' slot pictures; the bytes of a 96-slot chest form;
--   G  an old 16-slot shelf grows to 32 when opened, its items kept;
--   R  the direct recipes per tier (basic_recipes.lua) and the removed
--      "chest + Iron Bar" variant;
--   D  every tier drops itself (the open chest its closed tier, the blast
--      drops), and the tiers' textures exist.
--
-- Usage (repo root): luajit tools/r67_containers/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)

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

------------------------------------------------------------------------------
-- S1. The player's sort, byte-identical to the base commit (it also puts the
-- metadata-carrying ItemStack in place for everything below).
------------------------------------------------------------------------------
do
	local digest, left = dofile(repo .. "/tools/r67_containers/sort_cases.lua")(H)
	eq(digest, "e3c6fc8a", "S the player's sort: the base commit's digest")
	eq(left, 148, "S the 0.48.0 sizes leave the base commit's leftovers")
end

------------------------------------------------------------------------------
-- The fake engine around the harness (after tools/r491_view).
------------------------------------------------------------------------------
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

-- A node inventory; set_size keeps the items of a grown list (the engine's
-- InventoryList::setSize resizes the item vector).
local function node_inventory()
	local lists = {}
	local inv = {}
	function inv:set_size(list, size)
		local old = lists[list] or {}
		lists[list] = {}
		for i = 1, size do lists[list][i] = old[i] or ItemStack("") end
	end
	function inv:get_size(list) return #(lists[list] or {}) end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
		return out
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
			set_string = function(_, f, v) store[f] = v ~= "" and v or nil end,
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

local shown, receivers, afters = {}, {}, {}
local registered_nodes = {}
local now_us = 0
core.registered_nodes = registered_nodes
core.show_formspec = function(name, formname, formspec)
	shown[#shown + 1] = {name = name, form = formname, formspec = formspec}
end
core.close_formspec = function(name, formname) core.show_formspec(name, formname, "") end
core.get_node_or_nil = function(pos)
	local node = nodes[key(pos)]
	return node and {name = node.name, param2 = node.param2} or nil
end
core.get_node = function(pos) return core.get_node_or_nil(pos) or {name = "air", param2 = 0} end
core.swap_node = function(pos, node) nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0} end
core.get_meta = meta_at
core.get_player_by_name = function(name) return players[name] end
core.get_us_time = function() return now_us end
core.after = function(_, fn, ...) afters[#afters + 1] = {fn = fn, args = {...}} end
core.sound_play = noop
core.pos_to_string = function(pos) return "(" .. key(pos) .. ")" end
core.get_translator = function() return function(s) return s end end
-- Air above every chest: the lid opens (chest_lid_obstructed).
registered_nodes.air = {drawtype = "airlike"}
core.register_node = function(name, def)
	name = name:gsub("^:", "")
	def.name = name
	registered_nodes[name] = def
	core.registered_items[name] = def
end
core.register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end
core.register_lbm = noop
core.register_craft = noop
core.register_alias = noop
core.item_eat = function() return noop end
core.remove_node = function(pos) nodes[key(pos)], metas[key(pos)] = nil, nil end
local feed = {}
grug_core.feed = function(player, kind, text, k)
	feed[#feed + 1] = {name = player:get_player_name(), text = text, key = k}
	return true
end
local function run_afters()
	while #afters > 0 do
		local queue = afters
		afters = {}
		for _, job in ipairs(queue) do job.fn(unpack(job.args)) end
	end
end
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

-- The claims: the REAL model (registry.lua) on a memory store, the REAL
-- interaction guard, and core.is_protected as grug_housing answers it (the
-- node there is no placement target).
local store = {}
local clock = 1000000
local M = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
	storage = {
		get_string = function(k) return store[k] or "" end,
		set_string = function(k, v) store[k] = v ~= "" and v or nil end,
		keys = function()
			local out = {}
			for k in pairs(store) do out[#out + 1] = k end
			table.sort(out)
			return out
		end,
	},
	now = function() return clock end,
})
grug_housing = {claim_at = M.claim_at, is_active = M.is_active, permission = M.permission,
	STONE_ITEM = "grug_housing:claim_stone"}
local guards = {}
grug_core.register_interaction_guard = function(fn) guards[#guards + 1] = fn end
grug_core.register_protection_reason = noop
grug_core.interaction_guarded = function(pos, name)
	for _, guard in ipairs(guards) do
		if guard(pos, name) then return true end
	end
	return false
end
dofile(repo .. "/mods/PLAYER/grug_housing/interaction.lua")
core.is_protected = function(pos, name)
	return (M.protects(pos, name, function() return false end))
end

-- The real files.
default = setmetatable({
	get_translator = function(s, ...)
		local args = {...}
		return (s:gsub("@(%d)", function(i) return tostring(args[tonumber(i)]) end))
	end,
	get_inventory_drops = function(pos, list, drops)
		for _, stack in ipairs(meta_at(pos):get_inventory():get_list(list) or {}) do
			if not stack:is_empty() then drops[#drops + 1] = stack:to_string() end
		end
	end,
	set_inventory_action_loggers = noop,
	can_interact_with_node = function(player, pos)
		local owner = meta_at(pos):get_string("owner")
		return owner == "" or owner == player:get_player_name()
	end,
	node_sound_wood_defaults = function() return {} end,
	LIGHT_MAX = 14,
}, {__index = function() return noop end})
dofile(repo .. "/mods/BASE/default/node_formspec.lua")
dofile(repo .. "/mods/BASE/default/containers.lua")
dofile(repo .. "/mods/BASE/default/chests.lua")
do
	core.get_mapgen_setting = function() return "" end
	local ok, err = pcall(dofile, repo .. "/mods/BASE/default/nodes.lua")
	check(ok, "default/nodes.lua loads (" .. tostring(err) .. ")")
end
dofile(repo .. "/mods/BASE/vessels/init.lua")
local C = default.containers
local NODE_FORM = default.node_formspec.formname
local F = C.FIELDS
local SCROLL = grug_inventory.SCROLL_FIELDS.container

-- Items: planks, the bars, books and bottles, a few sortable goods.
local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("grug_materials:steel_bar", {description = "Steel Bar"})
item("grug_materials:abyssal_steel_bar", {description = "Abyssal Steel Bar"})
item("grug_materials:iron_bar", {description = "Iron Bar"})
item("default:book", {description = "Book", groups = {book = 1}})
item("vessels:glass_bottle", {description = "Empty Glass Bottle", groups = {vessel = 1}})

local function new_player(name, bags)
	local p = H.player(name, "warrior", bags or {})
	p.get_pos = function() return {x = 0, y = 0, z = 0} end
	players[name] = p
	return p
end

local serial = 0
local function place(name, at)
	serial = serial + 1
	local pos = at or {x = serial * 3, y = 0, z = 0}
	nodes[key(pos)] = {name = name, param2 = 2}
	local def = registered_nodes[name]
	if def.on_construct then def.on_construct(pos) end
	return pos, def
end
local function placed_by(name, player, at)
	local pos, def = place(name, at)
	if def.after_place_node then def.after_place_node(pos, player) end
	return pos, def
end
-- Stand the player beside `pos` (the forms check the reach).
local function near(player, pos)
	player.get_pos = function() return {x = pos.x + 1, y = pos.y, z = pos.z} end
end
local function open_chest(pos, player)
	near(player, pos)
	local node = core.get_node(pos)
	registered_nodes[node.name].on_rightclick(pos, node, player, ItemStack(""))
	run_afters()
	return last_shown(player:get_player_name())
end
local function close_chest(player)
	submit(player, "default:chest", {quit = "true"})
	run_afters()
end
local function stacks(pos, list)
	local out = {}
	for i, stack in ipairs(meta_at(pos):get_inventory():get_list(list)) do
		out[i] = stack:to_string()
	end
	return out
end
local function has(fs, text) return fs ~= nil and fs:find(text, 1, true) ~= nil end

------------------------------------------------------------------------------
-- R. The direct recipes; D. drops and textures.
------------------------------------------------------------------------------
do
	local catalog = dofile(repo .. "/mods/PLAYER/grug_jobs/basic_recipes.lua")
	local rows = {}
	for _, row in ipairs(catalog.recipes) do
		local parts = {}
		for _, entry in ipairs(row.ingredients) do
			parts[#parts + 1] = (entry.item or "group:" .. entry.group) .. "*" .. entry.n
		end
		table.sort(parts)
		rows[row.output] = rows[row.output] or {}
		table.insert(rows[row.output], table.concat(parts, "+") .. " -> " .. row.count)
	end
	local S, A, I = "grug_materials:steel_bar*8", "grug_materials:abyssal_steel_bar*8",
		"grug_materials:iron_bar*1"
	local function join(...)
		local parts = {...}
		table.sort(parts)
		return table.concat(parts, "+") .. " -> 1"
	end
	local WANT = {
		["default:chest"] = join("group:wood*8"),
		["default:chest_steel"] = join("group:wood*8", S),
		["default:chest_abyssal"] = join("group:wood*8", S, A),
		["default:chest_locked"] = join("group:wood*8", I),
		["default:chest_locked_steel"] = join("group:wood*8", S, I),
		["default:chest_locked_abyssal"] = join("group:wood*8", S, A, I),
		["default:bookshelf"] = join("default:book*3", "group:wood*6"),
		["default:bookshelf_steel"] = join("default:book*3", "group:wood*6", S),
		["default:bookshelf_abyssal"] = join("default:book*3", "group:wood*6", S, A),
		["vessels:shelf"] = join("group:vessel*3", "group:wood*6"),
		["vessels:shelf_steel"] = join("group:vessel*3", "group:wood*6", S),
		["vessels:shelf_abyssal"] = join("group:vessel*3", "group:wood*6", S, A),
	}
	for output, want in pairs(WANT) do
		eq(rows[output] and #rows[output], 1, "R " .. output .. ": one recipe")
		eq(rows[output] and rows[output][1], want, "R " .. output .. ": its ingredients")
		check(registered_nodes[output] ~= nil, "R " .. output .. " is registered")
	end

	for _, base in ipairs({"default:chest", "default:chest_locked"}) do
		for tier = 1, 3 do
			local name = C.tier_name(base, tier)
			eq(registered_nodes[name .. "_open"].drop, name, "D " .. name .. "_open drops its tier")
			eq(registered_nodes[name].drop, nil, "D " .. name .. " drops itself")
			eq(C.info(name).tier, tier, "D " .. name .. " is tier " .. tier)
			for _, tile in ipairs(registered_nodes[name .. "_open"].tiles) do
				local file = repo .. "/mods/BASE/default/textures/" .. tile.name
				local handle = io.open(file)
				check(handle ~= nil, "D " .. name .. ": " .. tile.name .. " exists")
				if handle then handle:close() end
			end
		end
	end
	local pos = place("default:chest_abyssal")
	meta_at(pos):get_inventory():set_stack("main", 70, ItemStack("t:apple 3"))
	local drops = registered_nodes["default:chest_abyssal"].on_blast(pos)
	eq(drops[#drops], "default:chest_abyssal", "D a blasted Abyssal Chest drops its tier")
	eq(drops[1], "t:apple 3 0", "D ...and its contents")
	for _, family in ipairs({{"default:bookshelf", "default", "default_bookshelf"},
			{"vessels:shelf", "vessels", "vessels_shelf"}}) do
		for tier = 1, 3 do
			local name = C.tier_name(family[1], tier)
			local def = registered_nodes[name]
			local spot = place(name)
			local blast = def.on_blast(spot)
			eq(blast[#blast], name, "D a blasted " .. name .. " drops its tier")
			eq(def.drop, nil, "D " .. name .. " drops itself")
			for _, tile in ipairs(def.tiles) do
				local file = repo .. "/mods/BASE/" .. (tile:match("^default_") and "default" or family[2]) ..
					"/textures/" .. tile
				local handle = io.open(file)
				check(handle ~= nil, "D " .. name .. ": " .. tile .. " exists")
				if handle then handle:close() end
			end
		end
	end
	eq(registered_nodes["default:chest_steel"].description, "Steel-Reinforced Chest", "D the name")
	eq(registered_nodes["default:chest_locked_abyssal"].description, "Locked Abyssal Chest",
		"D the locked name")
	eq(registered_nodes["vessels:shelf_steel"].description, "Steel-Reinforced Vessels Shelf",
		"D the shelf name")
end

------------------------------------------------------------------------------
-- F. The form.
------------------------------------------------------------------------------
local function list_element(fs, list)
	local w, h = fs:match("list%[nodemeta:[^;]+;" .. list .. ";0,0;(%d+),(%d+);%]")
	return tonumber(w), tonumber(h)
end
local function container_scroll(fs)
	return tonumber(fs:match("scrollbar%[[^%]]*;vertical;" .. SCROLL .. ";(%d+)%]"))
end
do
	local p = new_player("former", {20, 20, 20, 20})
	local station = grug_inventory.STATION
	for tier, rows in ipairs({4, 8, 12}) do
		local pos = place(C.tier_name("default:chest", tier))
		local fs = open_chest(pos, p).formspec
		eq(select(2, list_element(fs, "main")), rows, "F tier " .. tier .. ": the whole list, 8 wide")
		check(has(fs, ("scroll_container[%.3f,%.3f;9.750,4.750;%s;vertical;0.125]"):format(
			station.x, station.y, SCROLL)), "F tier " .. tier .. ": four rows visible")
		eq(container_scroll(fs), tier > 1 and 0 or nil,
			"F tier " .. tier .. ": a scrollbar only beyond four rows")
		local loc = "nodemeta:" .. key(pos)
		check(has(fs, "listring[" .. loc .. ";main]listring[current_player;grug_inbox]" ..
			"listring[current_player;main]"), "F tier " .. tier .. ": the rings")
		check(has(fs, "set_focus[" .. F.focus .. ";true]"), "F the focus sink")
		check(has(fs, F.sort) and has(fs, F.label), "F tier " .. tier .. ": Sort and the label")
		eq(has(fs, F.upgrade), tier < 3, "F tier " .. tier .. ": Upgrade below the last tier")
		if tier == 1 then
			check(has(fs, "item_image[") and has(fs, ";grug_materials:steel_bar]") and has(fs, "×8"),
				"F the Upgrade shows the Steel Bar ×8")
		elseif tier == 2 then
			check(has(fs, ";grug_materials:abyssal_steel_bar]"), "F then the Abyssal Steel Bar")
		end
		print(("R67 CONTAINERS the %d-slot chest form: %d bytes (four bags of 20)"):format(
			rows * 8, #fs))
		close_chest(p)
	end
	local pos = place("default:bookshelf_steel")
	near(p, pos)
	registered_nodes["default:bookshelf_steel"].on_rightclick(pos, core.get_node(pos), p, ItemStack(""))
	local fs = last_shown("former").formspec
	eq(select(2, list_element(fs, "books")), 8, "F a 64-slot shelf: 8 rows")
	local _, empties = fs:gsub("default_bookshelf_slot%.png", "")
	eq(empties, 64, "F a slot picture per empty slot")
	check(not has(fs, F.sort) and not has(fs, F.label), "F no Sort and no label on a shelf")
	check(has(fs, F.upgrade), "F the shelf's Upgrade")
	submit(p, NODE_FORM, {quit = "true"})
end

------------------------------------------------------------------------------
-- S2. A chest's Sort.
------------------------------------------------------------------------------
do
	local p = new_player("sorter")
	local pos = place("default:chest_steel")
	local inv = meta_at(pos):get_inventory()
	inv:set_stack("main", 3, ItemStack("s:apple 5"))
	inv:set_stack("main", 9, ItemStack("s:bar 4"))
	inv:set_stack("main", 40, ItemStack("s:sword_a"))
	inv:set_stack("main", 64, ItemStack("s:apple 4"))
	inv:set_stack("main", 50, ItemStack("s:bread 3"))
	open_chest(pos, p)
	now_us = 10000000
	submit(p, "default:chest", {[F.sort] = "Sort"})
	local got = stacks(pos, "main")
	eq(table.concat({got[1], got[2], got[3], got[4], got[5]}, "|"),
		"s:sword_a 1 0|s:bread 3 0|s:apple 7 0|s:apple 2 0|s:bar 4 0",
		"S the chest sorted like the inventory, across its whole list")
	eq(got[6] .. got[64], "", "S the free slots at the end")
	inv:set_stack("main", 64, ItemStack("s:Dirt 1"))
	submit(p, "default:chest", {[F.sort] = "Sort"})
	eq(stacks(pos, "main")[64], "s:Dirt 1 0", "S a click within the cooldown is ignored")
	now_us = now_us + grug_inventory.SORT_COOLDOWN_US
	submit(p, "default:chest", {[F.sort] = "Sort"})
	eq(stacks(pos, "main")[6], "s:Dirt 1 0", "S ...and works after it")
	close_chest(p)

	-- A locked chest sorts for its owner only.
	local owner, other = new_player("lockowner"), new_player("lockother")
	local locked = placed_by("default:chest_locked", owner)
	local linv = meta_at(locked):get_inventory()
	linv:set_stack("main", 5, ItemStack("s:bar 1"))
	now_us = now_us + 10000000
	default.can_interact_with_node = function() return true end -- a key holder
	local fs = open_chest(locked, other).formspec
	check(not has(fs, F.sort), "S no Sort for a locked chest's non-owner")
	submit(other, "default:chest", {[F.sort] = "Sort"})
	eq(stacks(locked, "main")[5], "s:bar 1 0", "S ...and its field changes nothing")
	close_chest(other)
	fs = open_chest(locked, owner).formspec
	check(has(fs, F.sort), "S the owner's Sort")
	submit(owner, "default:chest", {[F.sort] = "Sort"})
	eq(stacks(locked, "main")[1], "s:bar 1 0", "S ...sorts")
	close_chest(owner)
end

------------------------------------------------------------------------------
-- L. The label and its rights.
------------------------------------------------------------------------------
do
	eq(C.clean_label("  Ores\nand\27(c@#f00)gems  "), "Ores and (c@#f00)gems",
		"L control characters become spaces, the ends trimmed")
	eq(C.clean_label(("x"):rep(45)), ("x"):rep(40), "L at most 40 characters")
	eq(C.clean_label(("ä"):rep(41)), ("ä"):rep(40), "L UTF-8 characters count once")

	local function try(label, player, pos, want)
		local fs = open_chest(pos, player).formspec
		eq(has(fs, "field["), want, label .. ": the label field shown")
		eq(has(fs, F.upgrade), want, label .. ": the Upgrade shown")
		meta_at(pos):set_string(C.LABEL_KEY, "")
		submit(player, "default:chest", {[F.label] = "Mine", [F.save] = "Save"})
		eq(meta_at(pos):get_string(C.LABEL_KEY), want and "Mine" or "", label .. ": Save")
		meta_at(pos):set_string(C.LABEL_KEY, "")
		submit(player, "default:chest", {[F.label] = "Enter", key_enter_field = F.label})
		eq(meta_at(pos):get_string(C.LABEL_KEY), want and "Enter" or "", label .. ": Enter")
		close_chest(player)
	end
	local owner, friend, helper, stranger = new_player("claimer"), new_player("friend"),
		new_player("helper"), new_player("stranger")

	try("L open world, anyone", stranger, place("default:chest", {x = 5000, y = 0, z = 0}), true)

	M.issue("claimer", 30, false)
	local claim = M.create("claimer", {x = 0, y = 0, z = 1000})
	local inside = {x = 3, y = 1, z = 1003}
	place("default:chest", inside)
	try("L a draft claim protects nothing", stranger, inside, true)
	M.activate(claim, 5)
	M.set_permission(claim, "friend", "everything")
	M.set_permission(claim, "helper", "interact")
	try("L own claim", owner, inside, true)
	try("L foreign claim with everything", friend, inside, true)
	try("L foreign claim with interact only", helper, inside, false)
	local fs = open_chest(inside, helper).formspec
	check(has(fs, F.sort), "L ...who may still sort it")
	close_chest(helper)
	eq(grug_housing.interaction_refused(inside, "stranger"), true,
		"L a stranger in the claim cannot even open it")
	submit(stranger, "default:chest", {[F.label] = "x", [F.save] = "Save"})
	eq(meta_at(inside):get_string(C.LABEL_KEY), "", "L ...nor label it")

	local lockowner = new_player("lockowner2")
	local locked = placed_by("default:chest_locked", lockowner, {x = 7000, y = 0, z = 0})
	default.can_interact_with_node = function() return true end
	try("L a locked chest's owner", lockowner, locked, true)
	try("L a locked chest's non-owner (a key holder)", stranger, locked, false)

	-- The hover text: the label, then the chest's name.
	local pos = place("default:chest_steel")
	open_chest(pos, owner)
	submit(owner, "default:chest", {[F.label] = "Ores", [F.save] = "Save"})
	eq(meta_at(pos):get_string("infotext"), "Ores\nSteel-Reinforced Chest", "L the hover text")
	submit(owner, "default:chest", {[F.label] = "", [F.save] = "Save"})
	eq(meta_at(pos):get_string("infotext"), "Steel-Reinforced Chest", "L a cleared label")
	close_chest(owner)
	local lpos = placed_by("default:chest_locked_steel", lockowner)
	eq(meta_at(lpos):get_string("infotext"), "Locked Steel-Reinforced Chest (owned by lockowner2)",
		"L a locked chest's hover text names its owner")
	open_chest(lpos, lockowner)
	submit(lockowner, "default:chest", {[F.label] = "Gold", [F.save] = "Save"})
	eq(meta_at(lpos):get_string("infotext"), "Gold\nLocked Steel-Reinforced Chest (owned by lockowner2)",
		"L ...under its label")
	close_chest(lockowner)
	-- A label shows as text to whoever may not edit it.
	fs = open_chest(lpos, stranger).formspec
	check(has(fs, "label[") and has(fs, "Gold") and not has(fs, "field["),
		"L the label as text for a non-owner")
	close_chest(stranger)
end

------------------------------------------------------------------------------
-- U. The upgrade.
------------------------------------------------------------------------------
local function give(player, list, index, text)
	player:get_inventory():set_stack(list, index, ItemStack(text))
end
local function count(player, name)
	local n = 0
	for _, list in ipairs(grug_inventory.consume_lists(player:get_inventory())) do
		for _, stack in ipairs(player:get_inventory():get_list(list)) do
			if stack:get_name() == name then n = n + stack:get_count() end
		end
	end
	return n
end
do
	local a, b = new_player("upa", {8}), new_player("upb")
	local pos = placed_by("default:chest", a)
	local inv = meta_at(pos):get_inventory()
	inv:set_stack("main", 1, ItemStack("s:bar 7"))
	inv:set_stack("main", 32, ItemStack("s:apple 3"))
	meta_at(pos):set_string(C.LABEL_KEY, "Keep")
	C.update_infotext(pos)
	-- Two viewers of the open chest.
	open_chest(pos, a)
	open_chest(pos, b)
	eq(core.get_node(pos).name, "default:chest_open", "U the lid is open")
	-- Without the bars: refused.
	give(a, "main", 9, "grug_materials:steel_bar 5")
	submit(a, "default:chest", {[F.upgrade] = "", [SCROLL] = "VAL:0"})
	eq(core.get_node(pos).name, "default:chest_open", "U refused with 5 bars")
	eq(feed[#feed] and feed[#feed].text, "The upgrade needs 8 × Steel Bar.", "U ...and says why")
	eq(count(a, "grug_materials:steel_bar"), 5, "U ...nothing taken")
	-- With 9 bars across main and a bag: 8 taken.
	give(a, "grug_bag1_content", 2, "grug_materials:steel_bar 4")
	local before = #shown
	submit(a, "default:chest", {[F.upgrade] = ""})
	eq(core.get_node(pos).name, "default:chest_steel_open", "U the open chest's tier swapped")
	eq(core.get_node(pos).param2, 2, "U ...facing kept")
	eq(count(a, "grug_materials:steel_bar"), 1, "U 8 Steel Bars charged")
	eq(inv:get_size("main"), 64, "U the list grows to 64")
	eq(stacks(pos, "main")[1] .. "|" .. stacks(pos, "main")[32], "s:bar 7 0|s:apple 3 0",
		"U the contents stay")
	eq(meta_at(pos):get_string("infotext"), "Keep\nSteel-Reinforced Chest", "U the label stays")
	eq(default.chest.open_chests.upb.swap, "default:chest_steel", "U the second viewer follows")
	eq(#shown - before, 2, "U both viewers get the new form")
	eq(select(2, list_element(last_shown("upb").formspec, "main")), 8, "U ...with 64 slots")
	-- The second step keeps a viewer's scroll position.
	give(a, "main", 10, "grug_materials:abyssal_steel_bar 8")
	submit(a, "default:chest", {[F.upgrade] = "", [SCROLL] = "VAL:30"})
	eq(core.get_node(pos).name, "default:chest_abyssal_open", "U the next tier with Abyssal Steel Bars")
	eq(count(a, "grug_materials:abyssal_steel_bar"), 0, "U 8 Abyssal Steel Bars charged")
	eq(count(a, "grug_materials:steel_bar"), 1, "U ...no Steel Bars")
	eq(inv:get_size("main"), 96, "U the list grows to 96")
	eq(container_scroll(last_shown("upa").formspec), 30, "U the upgrader's scroll position kept")
	-- The last tier: no upgrade.
	check(not has(last_shown("upa").formspec, F.upgrade), "U no Upgrade at the last tier")
	submit(a, "default:chest", {[F.upgrade] = ""})
	eq(core.get_node(pos).name, "default:chest_abyssal_open", "U ...and its field changes nothing")
	-- Closing: the lid lands on the new tier.
	close_chest(b)
	eq(core.get_node(pos).name, "default:chest_abyssal_open", "U open while one viewer stays")
	close_chest(a)
	eq(core.get_node(pos).name, "default:chest_abyssal", "U the lid closes on the Abyssal Chest")

	-- A locked chest: the owner only, the owner kept.
	local owner, other = new_player("upowner"), new_player("upother")
	local locked = placed_by("default:chest_locked", owner)
	default.can_interact_with_node = function() return true end
	give(other, "main", 9, "grug_materials:steel_bar 8")
	open_chest(locked, other)
	submit(other, "default:chest", {[F.upgrade] = ""})
	eq(core.get_node(locked).name, "default:chest_locked_open", "U a non-owner cannot upgrade")
	eq(count(other, "grug_materials:steel_bar"), 8, "U ...and pays nothing")
	close_chest(other)
	give(owner, "main", 9, "grug_materials:steel_bar 8")
	open_chest(locked, owner)
	submit(owner, "default:chest", {[F.upgrade] = ""})
	eq(core.get_node(locked).name, "default:chest_locked_steel_open", "U the owner can")
	eq(meta_at(locked):get_string("owner"), "upowner", "U ...the owner stays")
	close_chest(owner)
	eq(core.get_node(locked).name, "default:chest_locked_steel", "U ...the lid closes on its tier")

	-- In a foreign claim with interact only: no upgrade.
	local helper = players.helper
	local inside = place("default:chest", {x = 4, y = 1, z = 1004})
	give(helper, "main", 9, "grug_materials:steel_bar 8")
	open_chest(inside, helper)
	submit(helper, "default:chest", {[F.upgrade] = ""})
	eq(core.get_node(inside).name, "default:chest_open", "U interact only: refused")
	close_chest(helper)

	-- A shelf: its node_formspec session stays open on the new tier.
	local reader = new_player("reader")
	local shelf = place("default:bookshelf")
	meta_at(shelf):get_inventory():set_stack("books", 2, ItemStack("default:book 3"))
	near(reader, shelf)
	registered_nodes["default:bookshelf"].on_rightclick(shelf, core.get_node(shelf), reader, ItemStack(""))
	give(reader, "main", 9, "grug_materials:steel_bar 8")
	submit(reader, NODE_FORM, {[F.upgrade] = ""})
	eq(core.get_node(shelf).name, "default:bookshelf_steel", "U the bookshelf's tier")
	eq(stacks(shelf, "books")[2], "default:book 3 0", "U ...its books stay")
	local last = last_shown("reader")
	eq(last.form .. ":" .. tostring(select(2, list_element(last.formspec, "books"))),
		NODE_FORM .. ":8", "U ...its open form shows 64 slots")
	eq(default.node_formspec.session_pos("reader") ~= nil, true, "U ...and stays open")
	eq(meta_at(shelf):get_string("infotext"), "Steel-Reinforced Bookshelf (0 written, 3 empty books)",
		"U ...its hover text names the tier")
	submit(reader, NODE_FORM, {quit = "true"})
end

------------------------------------------------------------------------------
-- G. An old 16-slot shelf grows to 32 when opened.
------------------------------------------------------------------------------
do
	local p = new_player("grower")
	for _, case in ipairs({{"default:bookshelf", "books", "default:book 2"},
			{"vessels:shelf", "vessels", "vessels:glass_bottle 5"}}) do
		local pos = place(case[1])
		local inv = meta_at(pos):get_inventory()
		eq(inv:get_size(case[2]), 32, "G a new " .. case[1] .. " has 32 slots")
		inv:set_size(case[2], 16) -- as made before Round 67
		inv:set_stack(case[2], 1, ItemStack(case[3]))
		inv:set_stack(case[2], 16, ItemStack(case[3]))
		near(p, pos)
		registered_nodes[case[1]].on_rightclick(pos, core.get_node(pos), p, ItemStack(""))
		eq(inv:get_size(case[2]), 32, "G an old " .. case[1] .. " grows to 32 when opened")
		eq(stacks(pos, case[2])[1] .. "|" .. stacks(pos, case[2])[16], case[3] .. " 0|" .. case[3] .. " 0",
			"G ...its items kept")
		submit(p, NODE_FORM, {quit = "true"})
		-- Never shrinking: a larger list stays.
		inv:set_size(case[2], 40)
		registered_nodes[case[1]].on_rightclick(pos, core.get_node(pos), p, ItemStack(""))
		eq(inv:get_size(case[2]), 40, "G " .. case[1] .. ": never shrinks")
		submit(p, NODE_FORM, {quit = "true"})
	end
end

if failures > 0 then
	print(("R67 CONTAINERS PORTABLE FAIL %d of %d checks"):format(failures, checks))
	error("R67 CONTAINERS portable fixture failed")
end
print(("R67 CONTAINERS PORTABLE PASS checks=%d"):format(checks))
