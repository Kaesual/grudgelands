-- Round 45 lane UI portable test (LuaJIT): the Crafting tab (round45-plan.md
-- §3, §4.4; ui-crafting-rework-plan.md §2.16-2.22, §2.33, §4.2-4.5).
--
--   luajit tools/r45_ui/portable_test.lua [REPO]
--
-- Loads the REAL vendored sfinv, grug_inventory's bags.lua (the give helper
-- and the fit check), ui.lua (the frame and the short view) and the REAL
-- grug_jobs registry.lua, state.lua, jobs.lua, overview.lua, ui.lua and
-- craft_box.lua under a stub engine with a wall clock, the microsecond
-- counter, core.after and player meta. Checks:
--   P  the page: the frame and the short view, the five area tabs (Basic
--      default), the tier progress, every element inside its column and
--      above the view (the window is the same on desktop and web, so the
--      risk at the web build's size is text running out of its column);
--   A  areas: an empty primary slot and an unlearned profession show how to
--      learn them; a learned one lists its recipes with the tier progress;
--   L  paging (10 per page, "Page x of y", clamped) and the search (Search
--      and Enter, at most once per second, a throttled request ignored
--      without a resend, the typed text echoed);
--   N  ×N and "Craftable only" against jobs.lua's ingredient rule (stacks
--      with metadata never count, group entries, the profession tier), one
--      inventory pass per build;
--   Q  the quantity field: Enter recalculates and never starts, Craft now
--      above the maximum lowers the field and shows the note without
--      starting, the last known value is echoed, Max, no field for
--      non-stackable outputs, the XP hint green and grey;
--   S  the station: "Requires: Forge nearby" with the button disabled (a
--      click only rebuilds), enabled with the forge within 4 nodes;
--   B  the progress bar: frame_start from the elapsed time on every build,
--      the frame duration, the texture's size;
--   J  sends per job: one at the start, one at the end (only while the
--      current page is Crafting), one at a cancel; a Stop refused without
--      room; no resend on a pure scrollbar event or on closing the window;
--      browsing while a job runs, a second job cannot start; Take all;
--   O  the professions overview in the crafting box while no recipe is
--      chosen, and gone from the Character tab.
-- Prints byte counts of the page (Basic page 1, a profession area, a page
-- during a job) and "R45 UI PORTABLE PASS checks=<n>" or the failures.

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
item("t:oak", {description = "Oak Plank", groups = {wood = 1}})
item("t:pine", {description = "Pine Plank", groups = {wood = 1}})
item("t:stick", {description = "Stick"})
item("t:coal", {description = "Coal"})
item("t:bar", {description = "Copper Bar"})
item("t:meat", {description = "Meat"})
item("t:grain", {description = "Wild Grain"})
item("t:stew", {description = "Hearty Stew", stack_max = 20})
item("t:sword", {description = "Copper Sword", stack_max = 1, type = "tool"})
item("t:axe", {description = "Iron Battle Axe", stack_max = 1, type = "tool"})
item("t:a_very_long_name", {description = "A Very Long Decorated Ceremonial Bookshelf of Oak"})
-- 24 numbered Basic outputs for paging (names sort as "Block 01".."Block 24").
for i = 1, 24 do
	item(("t:block%02d"):format(i), {description = ("Block %02d"):format(i)})
end
item("t:torch", {description = "Torch"})
core.registered_nodes["t:forge"] = {_grug_station = "forge"}

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

J.register_ingredient_tier("t:bar", 1)
J.register_ingredient_tier("t:meat", 1)
local torch = J.register_recipe({area = "basic", output = "t:torch", count = 4,
	ingredients = {{item = "t:stick", n = 1}, {item = "t:coal", n = 1}}})
local long = J.register_recipe({area = "basic", output = "t:a_very_long_name",
	ingredients = {{group = "wood", n = 6}}})
for i = 1, 24 do
	J.register_recipe({area = "basic", output = ("t:block%02d"):format(i),
		ingredients = {{item = "t:oak", n = i}}})
end
local sword = J.register_recipe({area = "weaponsmith", tier = 1, station = "forge",
	output = "t:sword", ingredients = {{item = "t:bar", n = 2}, {item = "t:stick", n = 1}},
	time = 3})
J.register_ingredient_tier("t:coal", 2)
local axe = J.register_recipe({area = "weaponsmith", tier = 2, station = "forge",
	output = "t:axe", ingredients = {{item = "t:bar", n = 1}, {item = "t:coal", n = 1}},
	time = 3})
local stew = J.register_recipe({area = "cooking", tier = 1, output = "t:stew",
	ingredients = {{item = "t:meat", n = 1}, {item = "t:grain", n = 1}}, time = 1})
for _, fn in ipairs(callbacks.loaded) do fn() end
eq(#J.recipes_in_area("basic"), 26, "setup: 26 Basic recipes")

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

------------------------------------------------------------------------------
-- Geometry: every element's rectangle (real coordinates).
------------------------------------------------------------------------------
local function plain_text(text)
	return (text:gsub("\27%(c@#%x+%)", ""):gsub("\\(.)", "%1"))
end
local function utf8_len(text)
	local _, extra = text:gsub("[\128-\191]", "")
	return #text - extra
end
-- {name, x, y, w, h} of each placed element; a label's width is estimated at
-- ui.lua's 6.6 characters per unit, its y centred.
local function rects(part)
	local out = {}
	for name, body in part:gmatch("([%w_]+)%[(.-[^\\])%]") do
		local x, y, w, h = body:match("^(%-?[%d%.]+),(%-?[%d%.]+);(%-?[%d%.]+),(%-?[%d%.]+)")
		if name == "list" then
			local lx, ly, cols, rows = body:match(";[%w_]+;(%-?[%d%.]+),(%-?[%d%.]+);(%d+),(%d+);")
			out[#out + 1] = {name = name, x = tonumber(lx), y = tonumber(ly),
				w = cols * 1.25 - 0.25, h = rows * 1.25 - 0.25}
		elseif name == "label" then
			local lx, ly, text = body:match("^(%-?[%d%.]+),(%-?[%d%.]+);(.*)$")
			out[#out + 1] = {name = name, x = tonumber(lx), y = tonumber(ly) - 0.2,
				w = utf8_len(plain_text(text)) / 6.6, h = 0.4, text = plain_text(text)}
		elseif name == "checkbox" then
			local lx, ly, text = body:match("^(%-?[%d%.]+),(%-?[%d%.]+);[%w_]+;(.-);")
			out[#out + 1] = {name = name, x = tonumber(lx), y = tonumber(ly) - 0.2,
				w = 0.5 + utf8_len(text) / 6.6, h = 0.4}
		elseif x and name ~= "tooltip" and name ~= "style" then
			out[#out + 1] = {name = name, x = tonumber(x), y = tonumber(y),
				w = tonumber(w), h = tonumber(h)}
		end
	end
	return out
end
-- Columns: the list, the crafting box, the output area; the tab row spans all.
local COLUMNS = {{0.2, 5.2}, {5.4, 10.2}, {10.4, 13.3}}
local function geometry_ok(fs, label)
	local part = content(fs)
	check(part:sub(1, 22) == "real_coordinates[true]", label .. ": real coordinates")
	local ok = true
	for _, r in ipairs(rects(part)) do
		local right, bottom = r.x + r.w, r.y + r.h
		if r.x < 0 or r.y < 0 or right > 13.5 + 1e-6 or bottom > 9.3 + 1e-6 then
			ok = check(false, ("%s: %s at %.2f,%.2f+%.2f,%.2f leaves the page area"):format(
				label, r.name, r.x, r.y, r.w, r.h))
		elseif r.y >= 0.95 then
			for _, column in ipairs(COLUMNS) do
				if r.x >= column[1] - 1e-6 and r.x < column[2] and right > column[2] + 0.05 then
					ok = check(false, ("%s: %s %q at %.2f,%.2f runs out of its column (%.2f)")
						:format(label, r.name, r.text or "", r.x, r.y, right))
				end
			end
		end
	end
	check(ok, label .. ": every element inside its column, above the view")
end
-- Every label's text in order, joined by spaces: wrapped sentences read
-- whole again.
local function label_text(fs)
	local parts = {}
	for body in fs:gmatch("label%[(.-[^\\])%]") do
		local text = body:match("^%-?[%d%.]+,%-?[%d%.]+;(.*)$")
		if text then parts[#parts + 1] = plain_text(text) end
	end
	return table.concat(parts, " ")
end
local function says(fs, sentence, label)
	return check(label_text(fs):find(sentence, 1, true) ~= nil,
		label .. " (missing text " .. sentence .. ")")
end
local function formspec_ok(fs, label)
	check(select(2, fs:gsub("%[", "")) - select(2, fs:gsub("\\%[", "")) ==
		select(2, fs:gsub("%]", "")) - select(2, fs:gsub("\\%]", "")),
		label .. ": balanced brackets")
end

------------------------------------------------------------------------------
-- P. The page.
------------------------------------------------------------------------------
local p = new_player("p")
local sent = p.sent
local fs = open(p)
eq(p.sent, sent + 1, "P opening the tab sends the page once")
formspec_ok(fs, "P page")
has(fs, "formspec_version[6]size[13.500,13.673]", "P the inventory window's frame")
has(fs, "grug_inv_scroll_short", "P the short inventory view")
eq(count(fs, "list[current_player;main;"), 2, "P main only in the view")
for index, label in ipairs({"Basic", "Cooking", "Primary 1", "Primary 2", "Alchemy"}) do
	has(fs, ("%s%d;%s]"):format(FIELDS.area, index, label), "P area tab " .. label)
end
has(fs, "style[grug_craft_area1;bgcolor=#8a682f", "P Basic is the default area, styled selected")
has(fs, "style[grug_craft_area2,grug_craft_area3,grug_craft_area4,grug_craft_area5;bgcolor=#3d3d3d",
	"P one style for the other tabs")
has(fs, "Basic: no tier", "P Basic has no tier")
has(fs, "list[current_player;grug_craft_out;10.6,1.65;2,2;]", "P the four output slots")
has(fs, "listring[current_player;grug_craft_out]listring[current_player;main]",
	"P shift-click moves the output into main")
has(fs, "grug_craft_take;Take all]", "P Take all")
has(fs, "No job running", "P idle status")
has(fs, "field_close_on_enter[grug_craft_search;false]", "P Enter in the search keeps the window")
geometry_ok(fs, "P Basic page 1")
print(("bytes: Crafting tab, Basic page 1, nothing chosen: content %d, page %d"):format(
	#content(fs), #fs))

------------------------------------------------------------------------------
-- O. The overview in the crafting box; gone from the Character tab.
------------------------------------------------------------------------------
says(fs, "No professions learned yet.", "O the overview while nothing is learned")
p.meta.fields["grug_jobs:primary:1"] = "weaponsmith"
p.meta.fields["grug_jobs:level:weaponsmith"] = 1
p.meta.fields["grug_jobs:crafts:weaponsmith"] = 4
fs = open(p)
has(fs, fs_escape("Weaponsmith — Tier 1"), "O the overview row in the crafting box")
has(fs, fs_escape("Crafts: 4/10 toward tier 2"), "O the overview progress")
geometry_ok(fs, "O overview")
-- The overview's rows wrap to the box (moved from the Character tab's
-- fixture, tools/r44_ch): the cap note, a T6 row, the footer; four capped
-- rows do not fit, the last ones point to the area tabs.
do
	local real_overview = J.profession_overview
	J.profession_overview = function()
		return {
			{name = "Weaponsmith", tier = 2, crafts = 15, needed = 15, capped = true,
				next_level = 21},
			{name = "Armorsmith", tier = 2, crafts = 3, needed = 15, capped = false,
				next_level = 21},
			{name = "Cooking", tier = 1, crafts = 4, needed = 10, capped = false,
				next_level = 11},
			{name = "Alchemy", tier = 6, crafts = 0, capped = false, next_level = 61},
		}
	end
	fs = open(p)
	has(fs, "label[5.60,1.35;Weaponsmith — Tier 2]", "O the first row at the box's top")
	says(fs, "Capped by your level: reach level 21, then craft once more for tier 3.",
		"O the cap note, wrapped")
	says(fs, "Alchemy — Tier 6 Highest tier reached.", "O a T6 row")
	says(fs, "Only crafts of the current tier count toward the next one.", "O the footer")
	lacks(fs, "More on the area tabs", "O every row fits")
	geometry_ok(fs, "O four rows")
	J.profession_overview = function()
		local out = {}
		for i = 1, 4 do
			out[i] = {name = "Prof " .. i, tier = 1, crafts = 10, needed = 10, capped = true,
				next_level = 11}
		end
		return out
	end
	fs = open(p)
	says(fs, "More on the area tabs above.", "O four capped rows: the pointer")
	lacks(fs, "Only crafts of the current", "O ... and no footer")
	geometry_ok(fs, "O four capped rows")
	J.profession_overview = real_overview
end
do
	local pages = io.open(ROOT .. "/mods/PLAYER/grug_inventory/pages.lua"):read("*a")
	lacks(pages, 'id = "professions"', "O no Professions mode on the Character tab")
	lacks(pages, "professions_content", "O the Character tab draws no overview")
	eq(J.character_professions_formspec, nil, "O the Character-page body builder is gone")
	local state = io.open(ROOT .. "/mods/PLAYER/grug_jobs/state.lua"):read("*a")
	lacks(state, "refresh_character_tab", "O a counted craft refreshes no Character tab")
end

------------------------------------------------------------------------------
-- A. Areas.
------------------------------------------------------------------------------
click(p, {[FIELDS.area .. "4"] = "Primary 2"})
says(p.formspec, "No primary profession yet. Learn one from its trainer in the capital.",
	"A an empty primary slot says how to learn one")
has(p.formspec, "style[grug_craft_area4;bgcolor=#8a682f", "A the chosen tab styled")
click(p, {[FIELDS.area .. "5"] = "Alchemy"})
says(p.formspec, "Not learned yet. Learn Alchemy from its trainer in the capital.",
	"A an unlearned profession says how to learn it")
has(p.formspec, "Not learned]", "A no tier progress while unlearned")
click(p, {[FIELDS.area .. "3"] = "Weaponsmith"})
fs = p.formspec
has(fs, "grug_craft_area3;Weaponsmith]", "A the primary slot's tab names its profession")
has(fs, "Tier 1 · 4/10", "A the tier progress")
has(fs, "box[12,0.45;0.52,0.25;#c9a24a]", "A the tier bar filled 4/10")
has(fs, "Copper Sword", "A the T1 recipe listed")
has(fs, "Iron Battle Axe", "A the T2 recipe listed too (every area shows all)")
check(fs:find("Copper Sword", 1, true) < fs:find("Iron Battle Axe", 1, true),
	"A tier order")
geometry_ok(fs, "A profession area")
print(("bytes: Crafting tab, a profession area (2 recipes): content %d, page %d"):format(
	#content(fs), #fs))

------------------------------------------------------------------------------
-- L. Paging and the search.
------------------------------------------------------------------------------
click(p, {[FIELDS.area .. "1"] = "Basic"})
fs = p.formspec
has(fs, "Page 1 of 3", "L 26 recipes: three pages")
eq(count(fs, "image_button["), 10, "L ten rows per page")
has(fs, "Block 01", "L tier order, then name: Block 01 first")
sent = p.sent
click(p, {[FIELDS.next] = ">"})
eq(p.sent, sent + 1, "L a page click resends once")
has(p.formspec, "Page 2 of 3", "L next page")
click(p, {[FIELDS.next] = ">"})
click(p, {[FIELDS.next] = ">"})
has(p.formspec, "Page 3 of 3", "L the last page clamps")
eq(count(p.formspec, "image_button["), 6, "L six rows on the last page")
click(p, {[FIELDS.prev] = "<"})
has(p.formspec, "Page 2 of 3", "L previous page")
-- The search: case-insensitive over the output's name, back to page 1.
advance(2)
sent = p.sent
click(p, {[FIELDS.search] = "block 2", [FIELDS.find] = "Search"})
eq(p.sent, sent + 1, "L a search resends once")
fs = p.formspec
has(fs, "Page 1 of 1", "L the search filters to one page")
eq(count(fs, "image_button["), 5, "L Block 20..24")
has(fs, "field[0.2,1.1;3.6,0.6;grug_craft_search;;block 2]", "L the typed text echoed")
-- A second search within a second is ignored: no resend, nothing changes.
advance(0.5)
sent = p.sent
click(p, {[FIELDS.search] = "torch", key_enter_field = FIELDS.search, key_enter = "true"})
eq(p.sent, sent, "L a search within a second: no resend")
eq(st_of(p).search, "block 2", "L ... and the applied search stays")
-- Other events still echo the typed text.
click(p, {[FIELDS.search] = "torch", [FIELDS.next] = ">"})
has(p.formspec, "grug_craft_search;;torch]", "L the last known text is echoed")
has(p.formspec, "Page 1 of 1", "L ... the list still shows the applied search")
advance(0.6)
sent = p.sent
click(p, {[FIELDS.search] = "torch", key_enter_field = FIELDS.search, key_enter = "true"})
eq(p.sent, sent + 1, "L Enter in the search field searches after a second")
eq(count(p.formspec, "image_button["), 1, "L one Torch")
advance(1.1)
click(p, {[FIELDS.search] = "zzz", [FIELDS.find] = "Search"})
has(p.formspec, "No recipe matches.", "L the empty result")
advance(1.1)
click(p, {[FIELDS.search] = "", [FIELDS.find] = "Search"})
has(p.formspec, "Page 1 of 3", "L an empty search shows everything")

------------------------------------------------------------------------------
-- N. ×N and "Craftable only" against jobs.lua's rule; one pass per build.
------------------------------------------------------------------------------
put(p, "main", 9, "t:oak 7")
put(p, "main", 10, "t:pine 5")
local tagged = ItemStack("t:oak 50")
tagged:get_meta():set_string("owner", "x")
p.inv:set_stack("main", 11, tagged)
put(p, "main", 1, "t:stick 3")
put(p, "main", 12, "t:coal 2")
local counts = J.ingredient_counts(p)
local reads = list_reads
fs = open(p)
local per_build = list_reads - reads
-- No bag: the pass reads `main` once.
eq(per_build, 1, "N one inventory pass per build")
has(fs, fs_escape("×") .. "7]", "N Block 01 ×7 (the tagged oak never counts)")
eq(J.crafts_from_counts(counts, J.recipes_in_area("basic")[2]), 7,
	"N jobs.lua's rule gives the same 7")
has(fs, "×" .. "1]", "N the long bookshelf: ×1 from the wood group (12 planks)")
click(p, {[FIELDS.only] = "true"})
fs = p.formspec
eq(st_of(p).only, true, "N Craftable only on")
has(fs, "checkbox[0.2,2;grug_craft_only;Craftable only;true]", "N the checkbox echoes its state")
has(fs, "Page 1 of 1", "N craftable rows only")
-- Blocks 01..07 (oak 7), the bookshelf (wood 12 >= 6), Torch (stick 3, coal 2).
eq(count(fs, "image_button["), 9, "N 7 blocks, the bookshelf, the torch")
lacks(fs, "Block 08", "N Block 08 needs 8 oak")
has(fs, "Torch", "N the torch")
geometry_ok(fs, "N craftable only")
-- In a profession area the tier counts: the T2 axe is not craftable at T1.
put(p, "main", 13, "t:bar 5")
click(p, {[FIELDS.area .. "3"] = "Weaponsmith"})
fs = p.formspec
has(fs, "Copper Sword", "N the T1 sword is craftable")
lacks(fs, "Iron Battle Axe", "N the T2 axe is not, at weaponsmith T1")
click(p, {[FIELDS.only] = "false"})
has(p.formspec, "Iron Battle Axe", "N without the filter the axe shows again")

------------------------------------------------------------------------------
-- Q. The crafting box and the quantity field.
------------------------------------------------------------------------------
local cook = new_player("cook")
cook.meta.fields["grug_jobs:learned:cooking"] = 1
cook.meta.fields["grug_jobs:level:cooking"] = 1
put(cook, "main", 9, "t:meat 30")
put(cook, "main", 10, "t:grain 12")
open(cook)
click(cook, {[FIELDS.area .. "2"] = "Cooking"})
click(cook, {[FIELDS.row .. "1"] = ""})
fs = cook.formspec
eq(st_of(cook).selected, stew.id, "Q a row click chooses the recipe")
has(fs, "box[0.2,2.35;5,0.56;#8a682f80]", "Q the chosen row is highlighted")
has(fs, "item_image[5.6,1.15;0.9,0.9;t:stew]", "Q the output's icon")
has(fs, "Cooking · Tier 1", "Q the area and tier")
has(fs, "label[5.6,2.35;Ingredients (have/need)]", "Q the ingredients heading")
has(fs, "item_image[5.6,2.6;0.4,0.4;t:meat]", "Q an ingredient icon")
has(fs, "30/1]", "Q have/need for one")
has(fs, "Max: 12]", "Q the maximum (12 grain)")
has(fs, "field[6.75,", "Q a quantity field for a stackable output")
has(fs, "grug_craft_qty;;1]", "Q the field's default is 1")
has(fs, "field_close_on_enter[grug_craft_qty;false]", "Q Enter keeps the window open")
has(fs, "grug_craft_max;Max]", "Q the Max button")
says(fs, "Crafting this will give you a Cooking experience point", "Q the XP hint")
has(fs, "(c@#7ae08a)Crafting this", "Q ... in green")
has(fs, "grug_craft_go;Craft now]", "Q Craft now")
geometry_ok(fs, "Q a stackable recipe")
-- Enter recalculates, never starts.
click(cook, {[FIELDS.qty] = "5", key_enter_field = FIELDS.qty, key_enter = "true"})
eq(J.job_state(cook), nil, "Q Enter never starts a job")
has(cook.formspec, "grug_craft_qty;;5]", "Q the typed value echoed")
has(cook.formspec, "30/5]", "Q have/need for the typed quantity")
click(cook, {[FIELDS.qty] = "x", key_enter_field = FIELDS.qty})
says(cook.formspec, "Enter a quantity of 1 or more.", "Q a bad quantity is named on Enter")
-- Craft now above the maximum lowers the field and does not start.
click(cook, {[FIELDS.qty] = "40", [FIELDS.go] = "Craft now"})
eq(J.job_state(cook), nil, "Q above the maximum: no job")
has(cook.formspec, "grug_craft_qty;;12]", "Q the field lowered to the maximum")
says(cook.formspec, "Not enough ingredients — quantity reduced to 12", "Q the note")
eq(count_of(cook, "t:meat"), 30, "Q nothing consumed")
-- Max fills the field from the build's own pass; a second click starts.
reads = list_reads
click(cook, {[FIELDS.qty] = "3", [FIELDS.max] = "Max"})
eq(list_reads - reads, 1, "Q a Max click: one inventory pass")
has(cook.formspec, "grug_craft_qty;;12]", "Q Max fills the maximum")
lacks(cook.formspec, "quantity reduced", "Q the note goes with the next click")

------------------------------------------------------------------------------
-- J. Sends per job; the bar; browsing while a job runs.
------------------------------------------------------------------------------
sent = cook.sent
click(cook, {[FIELDS.qty] = "12", [FIELDS.go] = "Craft now"})
local job = J.job_state(cook)
check(job ~= nil and job.quantity == 12, "J the job starts with the field's quantity")
eq(cook.sent, sent + 1, "J the start sends the page once")
fs = cook.formspec
has(fs, fs_escape(core.colorize("#5fd068", "Crafting…")), "J the green indicator")
has(fs, "Hearty Stew " .. fs_escape("×") .. "12", "J the job's label")
has(fs, "grug_craft_stop;Stop]", "J Craft now turned into Stop")
lacks(fs, "grug_craft_go;", "J no second start")
-- 12 s job: 1.5 x 12 s / 96 frames = 187.5 -> 188 ms; elapsed 0 -> frame 1.
has(fs, "animated_image[10.6,", "J the bar")
has(fs, ";grug_craft_bar;grug_jobs_progress_bar.png;96;188;1]", "J frame 1 at the start")
geometry_ok(fs, "J during a job")
print(("bytes: Crafting tab, a page during a job (recipe chosen): content %d, page %d"):format(
	#content(fs), #fs))
-- Half way: frame_start = 32 + 1 on every build (a page click rebuilds it).
advance(6)
click(cook, {[FIELDS.area .. "1"] = "Basic"})
has(cook.formspec, ";96;188;33]", "J frame_start from the elapsed time on every build")
has(cook.formspec, "grug_craft_stop;Stop]", "J Stop also while browsing another area")
has(cook.formspec, "Hearty Stew " .. fs_escape("×") .. "12", "J the job stays shown while browsing")
advance(3)
click(cook, {[FIELDS.next] = ">"})
has(cook.formspec, ";96;188;49]", "J three quarters: frame 49")
-- A second job cannot start (the button is Stop; a forged event is refused).
click(cook, {[FIELDS.area .. "2"] = "Cooking"})
click(cook, {[FIELDS.row .. "1"] = ""})
click(cook, {[FIELDS.qty] = "1", [FIELDS.go] = "Craft now"})
says(cook.formspec, "A crafting job is already running.", "J a second job is refused")
-- A pure scrollbar event of the view and closing the window: no resend.
sent = cook.sent
click(cook, {grug_inv_scroll_short = "CHG:10", [FIELDS.qty] = "1"})
eq(cook.sent, sent, "J no resend on a pure scrollbar event")
click(cook, {quit = "true"})
eq(cook.sent, sent, "J no resend when the window closes")
-- The end: one resend while the current page is Crafting.
advance(3.01)
run_timers()
eq(J.job_state(cook), nil, "J the job ended")
eq(cook.sent, sent + 1, "J the end sends the page once")
has(cook.formspec, "No job running", "J idle after the end")
has(cook.formspec, "grug_craft_go;Craft now]", "J Stop turned back into Craft now")
eq(cook.inv:get_stack(OUT, 1):get_count(), 12, "J the stews in the output area")
eq(feed_lines[#feed_lines], "Hearty Stew ×12 is ready", "J the feed line")
-- On another page the end sends nothing.
put(cook, "main", 9, "t:meat 5")
put(cook, "main", 10, "t:grain 5")
click(cook, {[FIELDS.qty] = "2", [FIELDS.go] = "Craft now"})
check(J.job_state(cook) ~= nil, "J a second job after the first")
sfinv.set_page(cook, "grug_inventory:inventory")
sent = cook.sent
advance(2.01)
run_timers()
eq(J.job_state(cook), nil, "J the job ended on another page")
eq(cook.sent, sent, "J ... and sent nothing")
fs = open(cook)
eq(cook.inv:get_stack(OUT, 1):get_count(), 14, "J the output area collects both")
-- Cancel: one resend, everything back.
click(cook, {[FIELDS.qty] = "3", [FIELDS.go] = "Craft now"})
eq(count_of(cook, "t:meat"), 0, "J the third job took the meat")
sent = cook.sent
click(cook, {[FIELDS.stop] = "Stop"})
eq(J.job_state(cook), nil, "J Stop cancels")
eq(cook.sent, sent + 1, "J the cancel sends the page once")
eq(count_of(cook, "t:meat"), 3, "J the refund")
-- A Stop refused without room keeps the job and shows the reason.
click(cook, {[FIELDS.qty] = "3", [FIELDS.go] = "Craft now"})
for index = 1, 32 do
	if cook.inv:get_stack("main", index):is_empty() then put(cook, "main", index, "t:torch 99") end
end
click(cook, {[FIELDS.stop] = "Stop"})
check(J.job_state(cook) ~= nil, "J a Stop without room keeps the job")
says(cook.formspec, "Not enough inventory space to cancel", "J the refusal")
-- Take all with a full inventory: the note, the stack stays.
click(cook, {[FIELDS.take] = "Take all"})
says(cook.formspec, "Not everything fit into your inventory.", "J Take all's leftover note")
eq(cook.inv:get_stack(OUT, 1):get_count(), 14, "J the stews stay in the output area")
for index = 9, 32 do put(cook, "main", index, "") end
click(cook, {[FIELDS.take] = "Take all"})
eq(cook.inv:get_stack(OUT, 1):get_count(), 0, "J Take all empties the output area")
eq(count_of(cook, "t:stew"), 14, "J into the inventory")
advance(4)
run_timers()
-- A job that ended while no timer ran (a logout, say) completes inside the
-- build that opens the tab, or inside the next start: still one send each.
put(cook, "main", 9, "t:meat 4")
put(cook, "main", 10, "t:grain 4")
click(cook, {[FIELDS.qty] = "1", [FIELDS.go] = "Craft now"})
check(J.job_state(cook) ~= nil, "J a short job")
sfinv.set_page(cook, "grug_inventory:inventory")
advance(1.5)
sent = cook.sent
open(cook)
eq(cook.sent, sent + 1, "J a job due at the tab's build completes in it: one send")
eq(J.job_state(cook), nil, "J ... the job completed")
has(cook.formspec, "No job running", "J ... and the build shows it")
click(cook, {[FIELDS.qty] = "1", [FIELDS.go] = "Craft now"})
advance(1.5)
sent = cook.sent
click(cook, {[FIELDS.qty] = "1", [FIELDS.go] = "Craft now"})
eq(cook.sent, sent + 1, "J a due job completed by the next start: one send")
check(J.job_state(cook) ~= nil, "J ... and the new job runs")
advance(2)
run_timers()

-- The bar's numbers, the texture.
do
	local bar = J.progress_bar(0, 0, 2.5, 0.27, {start = 100, finish = 101}, 100)
	has(bar, ";96;16;1]", "B a 1 s job: 16 ms frames, frame 1")
	bar = J.progress_bar(0, 0, 2.5, 0.27, {start = 100, finish = 101}, 100.999)
	has(bar, ";96;16;64]", "B just before the end: the last fill frame")
	bar = J.progress_bar(0, 0, 2.5, 0.27, {start = 100, finish = 101}, 102)
	has(bar, ";96;16;65]", "B past the end: the first full frame")
	eq(J.BAR_FRAMES, 96, "B 64 fill + 32 full frames")
	local png = io.open(ROOT .. "/mods/PLAYER/grug_jobs/textures/grug_jobs_progress_bar.png", "rb")
	check(png ~= nil, "B the texture is committed")
	if png then
		local data = png:read("*a")
		png:close()
		local function u32(at)
			local a, b, c, d = data:byte(at, at + 3)
			return ((a * 256 + b) * 256 + c) * 256 + d
		end
		eq(data:sub(13, 16), "IHDR", "B a PNG header")
		eq(u32(17), 66, "B 64 inner columns and a border")
		eq(u32(21), 7 * J.BAR_FRAMES, "B 96 frames of 7 rows stacked vertically")
	end
end

------------------------------------------------------------------------------
-- S. The station; the XP hint's grey; a non-stackable output.
------------------------------------------------------------------------------
local smith = new_player("smith")
smith.meta.fields["grug_jobs:primary:1"] = "weaponsmith"
smith.meta.fields["grug_jobs:level:weaponsmith"] = 2
smith.meta.fields["grug_jobs:crafts:weaponsmith"] = 0
put(smith, "main", 9, "t:bar 10")
put(smith, "main", 10, "t:stick 10")
put(smith, "main", 11, "t:coal 10")
open(smith)
click(smith, {[FIELDS.area .. "3"] = "Weaponsmith"})
click(smith, {[FIELDS.row .. "1"] = ""})
fs = smith.formspec
eq(st_of(smith).selected, sword.id, "S the sword chosen")
says(fs, "Requires: Forge nearby", "S the station hint")
has(fs, "(c@#ff9f5a)Requires: Forge nearby", "S ... as a warning")
has(fs, "style[grug_craft_recheck;", "S the button greyed")
has(fs, "grug_craft_recheck;Craft now]", "S ... and disabled (it cannot start)")
lacks(fs, "grug_craft_go;", "S no live Craft now")
lacks(fs, "field[6.75,", "S no quantity field for a non-stackable output")
says(fs, "Crafting this will not give you a Weaponsmith experience point",
	"S the XP hint below the profession tier")
has(fs, "(c@#8a8a8a)Crafting this will not", "S ... in grey")
geometry_ok(fs, "S station hint")
sent = smith.sent
click(smith, {[FIELDS.recheck] = "Craft now"})
eq(J.job_state(smith), nil, "S the disabled button never starts")
eq(smith.sent, sent + 1, "S ... a click rebuilds the page")
nodes[#nodes + 1] = {name = "t:forge", pos = {x = 3, y = 12, z = 0}}
click(smith, {[FIELDS.recheck] = "Craft now"})
has(smith.formspec, "grug_craft_go;Craft now]", "S with the forge within 4 nodes: enabled")
lacks(smith.formspec, "Requires: Forge", "S no hint")
click(smith, {[FIELDS.row .. "2"] = ""})
says(smith.formspec, "Crafting this will give you a Weaponsmith experience point",
	"S the hint for the current tier")
has(smith.formspec, "(c@#7ae08a)Crafting this", "S ... in green")
click(smith, {[FIELDS.go] = "Craft now"})
job = J.job_state(smith)
check(job ~= nil and job.quantity == 1, "S a non-stackable job of one")
-- A profession too low: disabled with the reason.
local novice = new_player("novice")
novice.meta.fields["grug_jobs:primary:1"] = "weaponsmith"
novice.meta.fields["grug_jobs:level:weaponsmith"] = 1
open(novice)
click(novice, {[FIELDS.area .. "3"] = "Weaponsmith"})
click(novice, {[FIELDS.row .. "2"] = ""})
says(novice.formspec, "Weaponsmith tier 2 required.", "S the tier gate named")
has(novice.formspec, "grug_craft_recheck;Craft now]", "S ... and the button disabled")
lacks(novice.formspec, "experience point", "S no XP hint for a tier above the profession")

------------------------------------------------------------------------------
-- Long names stay inside their column (the web build's window is the same).
------------------------------------------------------------------------------
local reader = new_player("reader")
put(reader, "main", 9, "t:oak 20")
open(reader)
click(reader, {[FIELDS.row .. "1"] = ""})
eq(st_of(reader).selected, long.id, "the long-named recipe chosen")
fs = reader.formspec
has(fs, "label[0.9,2.63;A Very Long Decorated..]", "the long name clipped in the list")
has(fs, "tooltip[grug_craft_row1;A Very Long Decorated Ceremonial Bookshelf of Oak]",
	"... in full as the row's tooltip")
lacks(fs, "tooltip[grug_craft_row2;", "no tooltip for a name that fits")
has(fs, "label[6.65,1.25;A Very Long Decorated]label[6.65,1.6;Ceremonial Bookshelf..]",
	"the box wraps the name to two lines, the rest clipped")
has(fs, "label[6.65,2;Basic · Tier 1]", "the area line below it")
has(fs, "Any Wood]", "a group entry: Any Wood")
has(fs, "tooltip[5.6,2.6;4.4,0.4;Oak Plank or Pine Plank]", "the group's members in a tooltip")
geometry_ok(fs, "long names")

------------------------------------------------------------------------------
-- F. A huge field value (a crafted client may send hundreds of kilobytes):
-- cut before the trim, so the event costs no noticeable time.
------------------------------------------------------------------------------
do
	local huge = "a" .. (" "):rep(300000) .. "b"
	local started = os.clock()
	click(reader, {[FIELDS.search] = huge, [FIELDS.qty] = huge, [FIELDS.next] = ">"})
	local spent = os.clock() - started
	check(spent < 0.2, ("F a 300 KB space-padded field is handled at once (%.3f s)"):format(spent))
	eq(st_of(reader).typed, "a", "F the search text cut, then trimmed")
	eq(st_of(reader).qty, "a", "F the quantity text cut, then trimmed")
	eq(J._clean_field("  12  ", 8), "12", "F a short value trimmed")
	eq(J._clean_field(("x"):rep(50), 40), ("x"):rep(40), "F a long value cut to the limit")
end

------------------------------------------------------------------------------
-- H. The Help and trainer texts after Round 45 (ST's merged result): no
-- recipe books, crafting grid, mixtures or Cooking trainer; the repair NPC
-- named from grug_jobs.MENDER_TITLE, never a literal.
------------------------------------------------------------------------------
do
	local function source(path)
		local f = assert(io.open(ROOT .. path))
		local text = f:read("*a")
		f:close()
		return text
	end
	local help = source("/mods/PLAYER/grug_inventory/help.lua")
	local trainers = source("/mods/PLAYER/grug_jobs/trainers.lua")
	for _, old in ipairs({"Basics book", "recipe book", "Crafting book", "crafting grid",
			"mixture", "Cooking trainer", "(grid and furnace)", "trainers for all eight",
			"Inventory > Crafting"}) do
		lacks(help, old, "H Help no longer says " .. old)
		lacks(trainers, old, "H the trainer dialog no longer says " .. old)
	end
	lacks(trainers, "choose its recipe", "H the learn notice names no recipe book")
	lacks(help, "Mender", "H Help never spells the repair NPC's title out")
	lacks(help, "Grudge-Free Repairs", "H ... not even the final one")
	has(help, "@MENDER@ in every start town and capital", "H the repair line takes the title")
	for _, part in ipairs({"Everyone knows Cooking from the start",
			"Alchemy (Brewing Stand): brews finished potions and elixirs",
			"Basic area of the Crafting tab", "Take all moves it into your inventory",
			"These stations open no window; furnaces and dual furnaces still do"}) do
		has(help, part, "H Help says: " .. part)
	end
	-- The page itself, with the title from the constant.
	core.get_game_info = function() return nil end
	core.log = function() end
	J.MENDER_TITLE = "Tinker's Bench"
	dofile(ROOT .. "/mods/PLAYER/grug_inventory/help.lua")
	local context = {page = "grug_inventory:help", grug_help_section = "basics"}
	local page = sfinv.get_formspec(reader, context)
	has(page, "and so does Tinker's Bench in every start town and capital",
		"H the Help page names the repair NPC by grug_jobs.MENDER_TITLE")
	lacks(page, "@MENDER@", "H no marker left on the page")
	J.MENDER_TITLE = nil
end

if failures > 0 then
	error(("R45 UI PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R45 UI PORTABLE PASS checks=%d"):format(checks))
