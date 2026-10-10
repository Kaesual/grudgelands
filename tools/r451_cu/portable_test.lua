-- Release 0.45.1 lane CU portable test (LuaJIT): the Crafting tab's fixes
-- and the tab order (0.45.1 fix plan rows 1, 3, 6, 10, 13).
--
--   luajit tools/r451_cu/portable_test.lua [REPO]
--
-- The engine stub and the player double are tools/r45_ui's (copied); it
-- loads the REAL vendored sfinv, grug_inventory's bags.lua and ui.lua, the
-- REAL grug_jobs registry.lua, state.lua, jobs.lua, overview.lua, ui.lua and
-- craft_box.lua, and grug_map's page.lua. Checks:
--   G  group ingredients: one member reads as its name, two as "A or B",
--      three as "A, B or C"; four or more as the hand-kept name ("Any
--      wool", "Any stone", "Any planks", "Any fruit", "Any berry") or, for a
--      group without one, the generated "Any <Group Name>"; members of the
--      same name count once; the tooltip lists every member; the icon is
--      the member the player carries most of (the stacks have/need count:
--      not one with metadata), else the first by name, per player;
--   Q  "−" and "+" at the quantity: "−" only above 1, "+" only below the
--      maximum, an invalid value counts as 1, one inventory pass per click,
--      no buttons and no resend for a non-stackable output, the row inside
--      the box;
--   S  "×" at the search: empties the field and the applied search, page 1,
--      at once inside the search's one-second limit, and it does not start
--      that limit;
--   F  focus: every build sets the focus to Search (set_focus[...;true],
--      before the search field), except the resend that answers Enter in a
--      field; closing the window after it resends once with the focus set;
--   T  the tab order (Map & Quests before Help) and the Map tab's title.
-- Prints "R451 CU PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
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
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function has(text, needle, label)
	return check(type(text) == "string" and text:find(needle, 1, true) ~= nil,
		label .. " (missing " .. needle .. ")")
end
local function lacks(text, needle, label)
	return check(type(text) == "string" and text:find(needle, 1, true) == nil,
		label .. " (found " .. needle .. ")")
end

------------------------------------------------------------------------------
-- Clock: real time in seconds; os.time() is its floor; the microsecond
-- counter starts at 0 with the process.
------------------------------------------------------------------------------
local real, process_start = 1700000000.4, 1700000000.4
os.time = function() return math.floor(real) end
local afters = {}
local function advance(seconds) real = real + seconds end
local function run_timers()
	local ran = true
	while ran do
		ran = false
		table.sort(afters, function(a, b) return a.at < b.at end)
		for index, entry in ipairs(afters) do
			if entry.at <= real + 0.00001 then
				table.remove(afters, index)
				entry.fn()
				ran = true
				break
			end
		end
	end
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local callbacks = {allow = {}, join = {}, leave = {}, loaded = {}, receive = {}}
local online, nodes, feed_lines = {}, {}, {}
local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local parts = {}
		for key, item in pairs(value) do
			parts[#parts + 1] = "[" .. serialize(key) .. "]=" .. serialize(item)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	elseif kind == "number" then
		return ("%.17g"):format(value)
	end
	return tostring(value)
end
local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
end
local list_reads = 0
local furnace_recipes = {}
core = {
	registered_items = {},
	registered_nodes = {},
	formspec_escape = fs_escape,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.loaded, f) end,
	register_on_player_receive_fields = function(f) table.insert(callbacks.receive, f) end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	get_modpath = function(name) return ROOT .. "/mods/PLAYER/" .. (name or "grug_inventory") end,
	get_current_modname = function() return "grug_inventory" end,
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	log = function() end,
	chat_send_player = function() end,
	add_item = function() end,
	handle_node_drops = function() end,
	get_us_time = function() return math.floor((real - process_start) * 1000000) end,
	after = function(delay, fn) afters[#afters + 1] = {at = real + delay, fn = fn} end,
	get_player_by_name = function(name) return online[name] end,
	get_connected_players = function() return {} end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local fn = loadstring(text)
		if not fn then return nil end
		setfenv(fn, {})
		local ok, value = pcall(fn)
		return ok and value or nil
	end,
	find_nodes_in_area = function(minp, maxp, names)
		local wanted, found = {}, {}
		for _, name in ipairs(names) do wanted[name] = true end
		for _, node in ipairs(nodes) do
			local p = node.pos
			if wanted[node.name] and p.x >= minp.x and p.x <= maxp.x and
					p.y >= minp.y and p.y <= maxp.y and p.z >= minp.z and p.z <= maxp.z then
				found[#found + 1] = p
			end
		end
		return found
	end,
	get_translator = function() return function(text) return text end end,
	-- Engine cooking recipes (furnace): input name -> output name.
	get_craft_result = function(input)
		local out = input.method == "cooking" and furnace_recipes[input.items[1]:get_name()]
		return {item = ItemStack(out or ""), time = out and 5 or 0}, {items = {}}
	end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
minetest = core
dump = function(value) return tostring(value) end
vector = {
	offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end,
	round = function(pos)
		return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
			z = math.floor(pos.z + 0.5)}
	end,
}

-- ItemStack double: name, count, wear and a metadata table.
local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_keys()
	local keys = {}
	for key in pairs(self.fields) do keys[#keys + 1] = key end
	return keys
end
local function meta_string(fields)
	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. fields[key] end
	return table.concat(parts, ";")
end
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({fields = {}}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear
		for key, value in pairs(item.fields or {}) do self.fields[key] = value end
		return self
	end
	local name, count, wear, meta = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)%s*(.*)$")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	local def = core.registered_items[self.name]
	if def and def.type == "tool" and self.count > 1 then self.count = 1 end
	self.wear = tonumber(wear) or 0
	for key, value in (meta or ""):gmatch("([^=;]+)=([^;]*)") do self.fields[key] = value end
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_meta() return setmetatable({fields = self.fields}, Meta) end
function Stack:set_count(c)
	self.count = c
	if c <= 0 then self.name, self.count, self.fields = "", 0, {} end
end
function Stack:take_item(c)
	c = math.min(c or 1, self.count)
	local taken = ItemStack(self)
	taken:set_count(c)
	self:set_count(self.count - c)
	return taken
end
local function compatible(a, b)
	return a.name == b.name and a.wear == b.wear and
		meta_string(a.fields) == meta_string(b.fields)
end
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		local fit = math.min(other.count, ItemStack(other):get_stack_max())
		self.name, self.count, self.wear = other.name, fit, other.wear
		self.fields = {}
		for key, value in pairs(other.fields) do self.fields[key] = value end
		other:set_count(other.count - fit)
		return other
	end
	if not compatible(self, other) then return other end
	local fit = math.max(0, math.min(other.count, self:get_stack_max() - self.count))
	self.count = self.count + fit
	other:set_count(other.count - fit)
	return other
end
function Stack:to_string()
	if self:is_empty() then return "" end
	local meta = meta_string(self.fields)
	return self.name .. " " .. self.count .. " " .. self.wear .. (meta ~= "" and " " .. meta or "")
end

local function new_inventory()
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i)
		local l = self.lists[list]
		return ItemStack(l and l[i] or "")
	end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:get_list(list)
		list_reads = list_reads + 1
		local l = self.lists[list]
		if not l then return nil end
		local out = {}
		for i = 1, #l do out[i] = ItemStack(l[i]) end
		return out
	end
	function inv:is_empty(list)
		for _, s in ipairs(self.lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	function inv:add_item(list, stack)
		stack = ItemStack(stack)
		local l = self.lists[list]
		for pass = 1, 2 do
			for i = 1, #l do
				if not stack:is_empty() and ((pass == 1 and not l[i]:is_empty()) or
						(pass == 2 and l[i]:is_empty())) then
					stack = l[i]:add_item(stack)
				end
			end
		end
		return stack
	end
	return inv
end

------------------------------------------------------------------------------
-- Mod surface.
------------------------------------------------------------------------------
local character_level = 15
grug_core = {
	feed = function(player, kind, text)
		feed_lines[#feed_lines + 1] = text
		return true
	end,
	item_name = function(item)
		local name = type(item) == "string" and item or item:get_name()
		local def = core.registered_items[name:match("^%S*")]
		return def and def.description:match("^[^\n]*") or name
	end,
	plain_text = function(text) return (tostring(text or ""):gsub("\27%([^)]*%)", "")) end,
}
grug_classes = {get_class = function() return "warrior" end}
grug_gear = {initialize_weapon_tooltip = function() return false end}
grug_xp = {get_level = function() return character_level end}
grug_sounds = {play = function() end}
grug_items = {crafted_output = function() return false end}

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end

-- Items: members of the groups the labels need.
item("t:carrot", {description = "Carrot", groups = {one = 1, two = 1}})
item("t:cassava", {description = "Cassava", groups = {two = 1}})
item("t:apple", {description = "Apple", groups = {three = 1}})
item("t:pear", {description = "Pear", groups = {three = 1}})
item("t:plum", {description = "Plum", groups = {three = 1}})
-- A second item named "Plum": the three-group still has three names.
item("t:plum_b", {description = "Plum", groups = {three = 1}})
for _, colour in ipairs({"Blue", "Green", "Red", "White"}) do
	item("t:wool_" .. colour:lower(), {description = colour .. " Wool", groups = {wool = 1}})
end
for _, kind in ipairs({"Cobblestone", "Desert Stone", "Sandstone", "Stone"}) do
	item("t:stone_" .. kind:lower():gsub(" ", "_"), {description = kind, groups = {stone = 1}})
end
for _, kind in ipairs({"Acacia", "Aspen", "Oak", "Pine"}) do
	item("t:plank_" .. kind:lower(), {description = kind .. " Plank", groups = {wood = 1}})
end
for _, kind in ipairs({"Apple", "Blueberries", "Sunberry", "Blightberry"}) do
	local groups = {grug_cooking_fruit = 1}
	if kind ~= "Apple" then groups.grug_cooking_berry = 1 end
	item("t:fruit_" .. kind:lower(), {description = kind, groups = groups})
end
item("t:fruit_jungle", {description = "Jungle Berry", groups = {grug_cooking_berry = 1}})
for _, kind in ipairs({"Basil", "Dill", "Mint", "Sage"}) do
	item("t:herb_" .. kind:lower(), {description = kind, groups = {grug_misc_herb = 1}})
end
item("t:soup", {description = "Soup", stack_max = 20})
item("t:hammer", {description = "Hammer", stack_max = 1, type = "tool"})
for i = 1, 24 do
	item(("t:block%02d"):format(i), {description = ("Wall %02d"):format(i)})
end
item("t:stick", {description = "Stick"})

grug_inventory = {}
dofile(ROOT .. "/mods/BASE/sfinv/api.lua")
-- sfinv's own init.lua registers the Crafting page the game overrides.
sfinv.register_page("sfinv:crafting", {title = "Crafting", get = function() return "" end})
sfinv.register_page("grug_inventory:inventory", {title = "Inventory",
	get = function() return "INVENTORY" end})
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/ui.lua")
local I = grug_inventory

grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/state.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/jobs.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/overview.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/ui.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/craft_box.lua")
local J = grug_jobs

-- One recipe per group shape; the soup (stackable) for the quantity row,
-- the hammer (not stackable) for its absence; 24 walls (after them by
-- name) for paging.
local function recipe(output, ingredients, area)
	return J.register_recipe({area = area or "basic", output = output, ingredients = ingredients})
end
local soup = recipe("t:soup", {{group = "one", n = 1}, {group = "two", n = 1},
	{group = "three", n = 1}, {group = "wool", n = 1}, {group = "stone", n = 1}})
item("t:soup2", {description = "Soup Two", stack_max = 20})
local soup2 = recipe("t:soup2", {{group = "wood", n = 1}, {group = "grug_cooking_fruit", n = 1},
	{group = "grug_cooking_berry", n = 1}, {group = "grug_misc_herb", n = 1}})
local hammer = recipe("t:hammer", {{item = "t:stick", n = 1}})
for i = 1, 24 do
	recipe(("t:block%02d"):format(i), {{item = "t:stick", n = 1}})
end
for _, fn in ipairs(callbacks.loaded) do fn() end

local FIELDS = J.CRAFT_FIELDS
local OUT = J.OUTPUT_LIST

local function new_meta()
	local fields = {}
	return {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(fields[key]) or 0 end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
		fields = fields,
	}
end
local function new_player(name)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local meta = new_meta()
	local player = {name = name, inv = inv, meta = meta, sent = 0,
		pos = {x = 0.3, y = 10, z = -0.2}}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return true end
	function player:get_pos() return self.pos end
	function player:set_inventory_formspec(fs)
		self.sent = self.sent + 1
		self.formspec = fs
	end
	online[name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
	return player
end
local function put(player, list, index, itemstring)
	player.inv:set_stack(list, index, ItemStack(itemstring))
end
local function count_of(player, name)
	local total = 0
	for _, stacks in pairs(player.inv.lists) do
		for _, stack in ipairs(stacks) do
			if stack:get_name() == name then total = total + stack:get_count() end
		end
	end
	return total
end
local function context_of(player) return sfinv.get_or_create_context(player) end
-- Opens the Crafting tab (a tab click: sfinv.set_page sends it).
local function open(player)
	sfinv.set_page(player, "sfinv:crafting")
	return player.formspec
end
-- One event of the inventory formspec, through sfinv's real handler.
local function click(player, fields)
	for _, f in ipairs(callbacks.receive) do
		local r = f(player, "", fields)
		if r then return r end
	end
end
-- The page's own part of a build (after the frame's real_coordinates[false]).
local function content(fs)
	return fs:match("real_coordinates%[false%](.*)$") or ""
end
local function st_of(player) return context_of(player).grug_craft end
local function count(text, needle)
	local found, from = 0, 1
	while true do
		local a, b = text:find(needle, from, true)
		if not a then return found end
		found, from = found + 1, b + 1
	end
end


-- The labels of a build's ingredient rows, in order, and their icons.
local function ingredient_labels(fs)
	local out = {}
	for icon, text in fs:gmatch("item_image%[5%.6,[%d%.]+;0%.4,0%.4;([^%]]*)%]label%[6%.1,[%d%.]+;(.-[^\\])%]") do
		out[#out + 1] = {icon = icon, label = text}
	end
	return out
end
-- Selects a recipe by its row on the current page.
local function select(player, id)
	for index, row in ipairs(st_of(player).rows) do
		if row == id then return click(player, {[FIELDS.row .. index] = ""}) end
	end
	error("recipe " .. id .. " not on the page")
end

------------------------------------------------------------------------------
-- G. Group ingredients.
------------------------------------------------------------------------------
local g = new_player("g")
open(g)
select(g, soup.id)
local rows = ingredient_labels(g.formspec)
eq(#rows, 5, "G five ingredient rows")
eq(rows[1] and rows[1].label, "Carrot", "G one member: its name")
eq(rows[2] and rows[2].label, "Carrot or Cassava", "G two members: A or B")
eq(rows[3] and rows[3].label, "Apple\\, Pear or Plum", "G three members (one name twice): A, B or C")
eq(rows[4] and rows[4].label, "Any wool", "G four or more: the hand-kept name (wool)")
eq(rows[5] and rows[5].label, "Any stone", "G ... stone")
has(g.formspec, ";Apple or Pear or Plum]", "G the tooltip lists every member")
has(g.formspec, ";Blue Wool or Green Wool or Red Wool or\nWhite Wool]", "G ... all four wools (wrapped)")
-- Icons without anything carried: the first member by name.
eq(rows[2] and rows[2].icon, "t:carrot", "G icon: the first member when none is carried")
eq(rows[4] and rows[4].icon, "t:wool_blue", "G ... Blue Wool first by name")
eq(rows[3] and rows[3].icon, "t:apple", "G ... Apple first")
-- The member carried most of; a stack with metadata does not count.
put(g, "main", 9, "t:wool_red 3")
put(g, "main", 10, "t:wool_white 5")
put(g, "main", 11, "t:wool_green 9 0 grug_tag=x")
put(g, "main", 12, "t:plum_b 2")
put(g, "main", 13, "t:pear 2")
click(g, {[FIELDS.recheck] = ""})
rows = ingredient_labels(g.formspec)
eq(rows[4] and rows[4].icon, "t:wool_white", "G icon: the member carried most of")
eq(rows[3] and rows[3].icon, "t:pear", "G ... a tie keeps the first by name (Pear before Plum)")
has(g.formspec, "8/1]", "G have/need unchanged: the group total (3 + 5 plain wool)")
-- Per player: another player sees the first member again.
local h = new_player("h")
open(h)
select(h, soup.id)
rows = ingredient_labels(h.formspec)
eq(rows[4] and rows[4].icon, "t:wool_blue", "G the icon is per player")
-- The other hand-kept names and the generated fallback.
select(h, soup2.id)
rows = ingredient_labels(h.formspec)
eq(rows[1] and rows[1].label, "Any planks", "G wood reads Any planks")
eq(rows[2] and rows[2].label, "Any fruit", "G grug_cooking_fruit reads Any fruit")
eq(rows[3] and rows[3].label, "Any berry", "G grug_cooking_berry reads Any berry")
eq(rows[4] and rows[4].label, "Any Grug Misc Herb",
	"G four members without a hand-kept name: the generated label")

------------------------------------------------------------------------------
-- Q. "−" and "+" at the quantity.
------------------------------------------------------------------------------
local q = new_player("q")
-- Enough for three soups: the maximum is 3.
put(q, "main", 9, "t:carrot 6")
put(q, "main", 10, "t:apple 3")
put(q, "main", 11, "t:wool_red 3")
put(q, "main", 12, "t:stone_stone 3")
open(q)
select(q, soup.id)
has(q.formspec, "Max: 3]", "Q setup: the maximum is 3")
local X = 5.6
local row = {}
for name, x, w in q.formspec:gmatch("(%a+)%[([%d%.]+),7%.54;([%d%.]+),0%.6;") do
	row[#row + 1] = {name = name, x = tonumber(x), w = tonumber(w)}
end
eq(#row, 4, "Q the row: −, the field, +, Max")
local ok = #row == 4
for index, r in ipairs(row) do
	if r.x + r.w > X + 4.4 + 1e-6 then ok = false end
	if index > 1 and r.x < row[index - 1].x + row[index - 1].w then ok = false end
end
check(ok and row[1].x >= X + 8 / 6.6, "Q the row fits the box after the label, no overlap")
has(q.formspec, "grug_craft_minus;−]", "Q the − button")
has(q.formspec, "grug_craft_plus;+]", "Q the + button")
has(q.formspec, "grug_craft_max;Max]", "Q Max stays")
local function qty_of(player) return player.formspec:match("grug_craft_qty;;([^%]]*)%]") end
local sent = q.sent
click(q, {[FIELDS.qty] = "1", [FIELDS.minus] = "−"})
eq(qty_of(q), "1", "Q − at 1 does nothing")
eq(q.sent, sent + 1, "Q ... one resend")
local reads = list_reads
click(q, {[FIELDS.qty] = "1", [FIELDS.plus] = "+"})
eq(qty_of(q), "2", "Q + below the maximum adds one")
eq(list_reads - reads, 1, "Q a + click: one inventory pass")
click(q, {[FIELDS.qty] = "2", [FIELDS.plus] = "+"})
eq(qty_of(q), "3", "Q + up to the maximum")
click(q, {[FIELDS.qty] = "3", [FIELDS.plus] = "+"})
eq(qty_of(q), "3", "Q + at the maximum does nothing")
click(q, {[FIELDS.qty] = "3", [FIELDS.minus] = "−"})
eq(qty_of(q), "2", "Q − above 1 takes one")
-- The typed value counts (the click carries the field).
click(q, {[FIELDS.qty] = "7", [FIELDS.minus] = "−"})
eq(qty_of(q), "6", "Q − from a typed value above the maximum")
click(q, {[FIELDS.qty] = "7", [FIELDS.plus] = "+"})
eq(qty_of(q), "7", "Q + above the maximum does nothing")
click(q, {[FIELDS.qty] = "x", [FIELDS.minus] = "−"})
eq(qty_of(q), "1", "Q an invalid value counts as 1: − makes it 1")
click(q, {[FIELDS.qty] = "0", [FIELDS.plus] = "+"})
eq(qty_of(q), "2", "Q ... + makes it 2")
click(q, {[FIELDS.qty] = "2.5", [FIELDS.plus] = "+"})
eq(qty_of(q), "2", "Q ... 2.5 counts as 1 too")
-- Nothing carried: the maximum is 0, + stays at 1.
local empty = new_player("empty")
open(empty)
select(empty, soup.id)
click(empty, {[FIELDS.qty] = "1", [FIELDS.plus] = "+"})
eq(qty_of(empty), "1", "Q + with a maximum of 0 does nothing")
-- A non-stackable output: no row, a forged click changes nothing.
select(q, hammer.id)
lacks(q.formspec, "grug_craft_minus", "Q no − for a non-stackable output")
lacks(q.formspec, "grug_craft_plus", "Q no + for a non-stackable output")
sent = q.sent
click(q, {[FIELDS.plus] = "+"})
eq(q.sent, sent, "Q a forged + for a non-stackable output: no resend")

------------------------------------------------------------------------------
-- S. "×" at the search.
------------------------------------------------------------------------------
local s = new_player("s")
local fs = open(s)
has(fs, "field[0.2,1.1;3,0.6;grug_craft_search;;]", "S the narrower field")
has(fs, "button[3.3,1.1;0.5,0.6;grug_craft_clear;×]", "S × right of the field")
has(fs, "button[3.9,1.1;1.3,0.6;grug_craft_find;Search]", "S then Search")
local pages_all = fs:match("Page 1 of (%d+)")
click(s, {[FIELDS.next] = ">"})
click(s, {[FIELDS.next] = ">"})
has(s.formspec, "Page 3 of " .. pages_all, "S setup: page 3")
advance(2)
click(s, {[FIELDS.search] = "wall 1", [FIELDS.find] = "Search"})
eq(st_of(s).search, "wall 1", "S setup: a search applied")
check(s.formspec:find("Page 1 of " .. pages_all, 1, true) == nil, "S setup: the search filters")
-- × within the second: at once.
sent = s.sent
click(s, {[FIELDS.search] = "wall 1", [FIELDS.clear] = "×"})
eq(s.sent, sent + 1, "S × resends at once, inside the search's second")
eq(st_of(s).search, "", "S × clears the applied search")
has(s.formspec, "grug_craft_search;;]", "S × empties the field")
has(s.formspec, "Page 1 of " .. pages_all, "S × shows the whole list from page 1")
-- From page 3 of the full list, × goes back to page 1.
click(s, {[FIELDS.next] = ">"})
click(s, {[FIELDS.next] = ">"})
click(s, {[FIELDS.search] = "", [FIELDS.clear] = "×"})
eq(st_of(s).page, 1, "S × returns to page 1")
-- × does not start the limit: a search right after it runs.
advance(1.5)
click(s, {[FIELDS.search] = "", [FIELDS.clear] = "×"})
sent = s.sent
click(s, {[FIELDS.search] = "wall 2", [FIELDS.find] = "Search"})
eq(s.sent, sent + 1, "S a search right after × runs (× sets no limit)")
eq(st_of(s).search, "wall 2", "S ... and applies")
-- The limit itself still holds for Search.
sent = s.sent
click(s, {[FIELDS.search] = "wall 3", [FIELDS.find] = "Search"})
eq(s.sent, sent, "S a second search within the second: ignored")

------------------------------------------------------------------------------
-- F. Focus.
------------------------------------------------------------------------------
local FOCUS = "set_focus[grug_craft_find;true]"
local f = new_player("f")
fs = open(f)
has(fs, FOCUS, "F a fresh build focuses Search")
local at, field_at = fs:find(FOCUS, 1, true), fs:find("field[0.2,1.1;", 1, true)
check(at and field_at and at < field_at, "F set_focus comes before the search field and Search")
eq(count(fs, "set_focus["), 1, "F one set_focus")
advance(2)
-- Enter in the search field: the answer leaves the focus there.
sent = f.sent
click(f, {[FIELDS.search] = "wall", key_enter_field = FIELDS.search, key_enter = "true"})
eq(f.sent, sent + 1, "F Enter in the search resends")
lacks(f.formspec, "set_focus[", "F ... without set_focus (the field keeps the focus)")
-- Closing the window then resends once, with the focus on Search.
click(f, {quit = "true"})
eq(f.sent, sent + 2, "F closing after it resends once")
has(f.formspec, FOCUS, "F ... with the focus on Search")
click(f, {quit = "true"})
eq(f.sent, sent + 2, "F a second close: no resend")
-- Enter in the quantity field the same; the next click sets the focus again.
put(f, "main", 9, "t:stick 5")
click(f, {[FIELDS.search] = "", [FIELDS.clear] = "×"})
select(f, hammer.id)
has(f.formspec, FOCUS, "F a click's resend focuses Search")
select(f, soup.id)
click(f, {[FIELDS.qty] = "2", key_enter_field = FIELDS.qty, key_enter = "true"})
lacks(f.formspec, "set_focus[", "F Enter in the quantity: no set_focus")
click(f, {[FIELDS.qty] = "2", [FIELDS.plus] = "+"})
has(f.formspec, FOCUS, "F the next click: set_focus again")
sent = f.sent
click(f, {quit = "true"})
eq(f.sent, sent, "F closing after a click's resend: no resend")
-- A throttled Enter (no resend) leaves no flag behind.
advance(2)
click(f, {[FIELDS.search] = "a", [FIELDS.find] = "Search"})
sent = f.sent
click(f, {[FIELDS.search] = "b", key_enter_field = FIELDS.search, key_enter = "true"})
eq(f.sent, sent, "F a throttled Enter: no resend")
click(f, {[FIELDS.next] = ">"})
has(f.formspec, FOCUS, "F ... and the next build focuses Search")
-- Enter in a field and ×: × answers with the focus on Search.
advance(2)
click(f, {[FIELDS.search] = "c", key_enter_field = FIELDS.search, key_enter = "true"})
click(f, {[FIELDS.search] = "c", [FIELDS.clear] = "×"})
has(f.formspec, FOCUS, "F × focuses Search")

------------------------------------------------------------------------------
-- T. Tabs.
------------------------------------------------------------------------------
eq(table.concat(I.TAB_ORDER, ","), "grug_inventory:inventory,grug_inventory:character," ..
	"grug_classes:talents,sfinv:crafting,grug_parties:group,grug_map:atlas," ..
	"grug_inventory:help", "T the order: Map & Quests before Help")
grug_map = {}
dofile(ROOT .. "/mods/PLAYER/grug_map/page.lua")
for _, name in ipairs({"grug_inventory:character", "grug_classes:talents",
		"grug_parties:group", "grug_inventory:help"}) do
	sfinv.register_page(name, {title = name, get = function() return "" end})
end
I.order_tabs()
local names, titles = {}, {}
for _, def in ipairs(sfinv.pages_unordered) do
	names[#names + 1], titles[#titles + 1] = def.name, def.title
end
eq(table.concat(names, ","), table.concat(I.TAB_ORDER, ","), "T sfinv's pages follow the order")
eq(sfinv.pages["grug_map:atlas"].title, "Map & Quests", "T the map's tab reads Map & Quests")
local handle = io.open(ROOT .. "/mods/PLAYER/grug_inventory/help.lua")
local help = handle:read("*a")
handle:close()
has(help, "(Z or the Map & Quests tab)", "T Help names the tab by its new title")

if failures > 0 then
	error(("R451 CU PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R451 CU PORTABLE PASS checks=%d"):format(checks))
