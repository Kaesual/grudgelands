-- Round 46 lane ID portable test (LuaJIT): the kind per group ingredient in
-- the crafting box (a dropdown) and the one torch recipe for coal or
-- charcoal (round46-plan.md §1 lane ID; the user's request of 2026-10-12).
--
--   luajit tools/r46_id/portable_test.lua [REPO]
--   luajit tools/r46_id/portable_test.lua [REPO] --bytes   only the byte counts
--
-- The engine, sfinv and grug_inventory stubs are tools/r45_ui's (copied);
-- the REAL grug_jobs registry.lua, state.lua, jobs.lua, overview.lua, ui.lua
-- and craft_box.lua run on them. Checks:
--   D  the dropdown: none with one kind (or none) carried, one per group
--      entry with two or more ("Automatic", then each carried kind with its
--      count, a stack with metadata not counted); it fits the box above the
--      quantity row;
--   C  the choice: a changed dropdown resends once and changes Max, the
--      list's ×N and the take (Craft now takes the chosen kind); two groups
--      choosing one item; back to Automatic; Automatic equals the count
--      without a choice; a dropdown value equal to the built one, a row
--      click carrying the old values and a pure scrollbar event change
--      nothing and resend nothing;
--   F  the fallback: a chosen kind used up or no longer carried, or a group
--      left with one kind, is Automatic on the next build; another recipe
--      starts on Automatic; the choice is page state only (no player meta);
--   T  the torch (stub catalog): coal or charcoal, the choice per kind; a
--      running job of a removed recipe id returns its ingredients;
--   E  exactness on the REAL Basic and Cooking catalogs (tools/r46_ck's
--      jobs_harness.lua; the Basic groups' members from the base catalog
--      tools/r45_rg/corpus_base.lua, charcoal's groups from grug_smelting):
--      for every recipe with a group entry on varied inventories, with no
--      choice and with each carried kind chosen (one group at a time, and
--      every group at once), ×N equals what take_ingredients takes (n fits,
--      n + 1 does not below the job ceiling), the take consumes no other
--      kind of a chosen group than another entry accepts, and no choice
--      equals the plain count; the real torch: one recipe of the coal
--      group, 10 per craft, the two old ids gone.
-- Prints the page bytes (a recipe with two group ingredients and the torch,
-- with and without dropdowns) and "R46 ID PORTABLE PASS checks=<n>".

local ROOT = arg and arg[1] or "."
local BYTES_ONLY = arg and arg[2] == "--bytes"
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
-- Two group ingredients that share members (Sweetroot Mash's shape: two of
-- a root, one staple, one grain) and the torch's coal-or-charcoal.
item("t:carrot", {description = "Carrot", groups = {root = 1, staple = 1}})
item("t:cassava", {description = "Cassava", groups = {root = 1, staple = 1}})
item("t:potato", {description = "Potato", groups = {staple = 1}})
item("t:grain", {description = "Wild Grain"})
item("t:mash", {description = "Sweetroot Mash", stack_max = 20})
item("t:coal", {description = "Coal Lump", groups = {coal = 1}})
item("t:charcoal", {description = "Charcoal", groups = {coal = 1}})
item("t:stick", {description = "Stick", groups = {stick = 1}})
item("t:torch", {description = "Torch"})
item("t:bread", {description = "Bread"})

grug_inventory = {}
dofile(ROOT .. "/mods/BASE/sfinv/api.lua")
sfinv.register_page("sfinv:crafting", {title = "Crafting", get = function() return "" end})
sfinv.register_page("grug_inventory:inventory", {title = "Inventory",
	get = function() return "INVENTORY" end})
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/ui.lua")

grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/state.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/jobs.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/overview.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/ui.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/craft_box.lua")
local J = grug_jobs

local mash = J.register_recipe({area = "basic", output = "t:mash",
	ingredients = {{group = "root", n = 2}, {group = "staple", n = 1},
		{item = "t:grain", n = 1}}})
local torch = J.register_recipe({area = "basic", output = "t:torch", count = 10,
	ingredients = {{group = "coal", n = 1}, {group = "stick", n = 1}}})
local bread = J.register_recipe({area = "basic", output = "t:bread",
	ingredients = {{item = "t:grain", n = 1}}})
for _, fn in ipairs(callbacks.loaded) do fn() end
local FIELDS = J.CRAFT_FIELDS
local OUT = J.OUTPUT_LIST
local PICK = "grug_craft_pick_"
local SCROLL = grug_inventory.SCROLL_FIELDS.short


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
local function select(player, id)
	for index, row in ipairs(st_of(player).rows) do
		if row == id then return click(player, {[FIELDS.row .. index] = ""}) end
	end
	error("recipe " .. id .. " not on the page")
end
-- The dropdowns of a build: index -> {x, y, w, h, items, selected}.
local function dropdowns(fs)
	local out = {}
	for x, y, w, h, index, items, selected in content(fs):gmatch(
			"dropdown%[([%d%.]+),([%d%.]+);([%d%.]+),([%d%.]+);" .. PICK ..
			"%d+_(%d+);(.-[^\\]);(%d+);true%]") do
		out[tonumber(index)] = {x = tonumber(x), y = tonumber(y), w = tonumber(w),
			h = tonumber(h), items = items, selected = tonumber(selected)}
	end
	return out
end
-- The name of the current build's dropdown `index` (the serial per build).
local function pick(player, index)
	local built = st_of(player).pick_rows
	return PICK .. (built and built.serial or 0) .. "_" .. index
end
local function n_dropdowns(fs)
	local total = 0
	for _ in pairs(dropdowns(fs)) do total = total + 1 end
	return total
end
local function max_of(fs)
	return tonumber(content(fs):match("label%[[%d%.]+,[%d%.]+;Max: (%d+)"))
end
-- The list row's ×N of a recipe (its label follows the row's name label).
local function row_n(fs, label)
	return tonumber(content(fs):match(label .. "%]label%[[%d%.]+,[%d%.]+;[^%]]-×(%d+)"))
end
local function rebuild(player) return click(player, {[FIELDS.recheck] = ""}) end
-- (Round 47: the result lands in the inventory; Take all is gone.)
local function finish_job(player)
	advance(3600)
	run_timers()
end
local BOX = J.CRAFT_BOX
local QUANTITY_Y = BOX.y + BOX.h - 1.5
-- Every dropdown inside the box's inner width, Max below the last row and
-- above the quantity row.
local function fits(fs, label)
	local ok = true
	local max_y = tonumber(content(fs):match("label%[[%d%.]+,([%d%.]+);Max: "))
	for index, d in pairs(dropdowns(fs)) do
		ok = check(d.x >= BOX.x + 0.2 - 1e-6 and d.x + d.w <= BOX.x + BOX.w - 0.2 + 1e-6 and
			d.h >= 0.5 and d.y + d.h <= (max_y or 0) - 0.2 + 1e-6,
			("%s: dropdown %d at %.2f,%.2f+%.2f,%.2f inside the box, above Max"):format(
			label, index, d.x, d.y, d.w, d.h)) and ok
	end
	check(max_y and max_y + 0.2 <= QUANTITY_Y + 1e-6, label .. ": Max above the quantity row")
	return ok
end

-- The --bytes measurement (runs on the base commit's files too): the page
-- with Sweetroot Mash's shape chosen and the torch chosen, while two kinds
-- of each group are carried.
local function bytes_report(label)
	local b = new_player("bytes_" .. label)
	put(b, "main", 9, "t:carrot 10")
	put(b, "main", 10, "t:cassava 4")
	put(b, "main", 11, "t:grain 5")
	put(b, "main", 12, "t:coal 3")
	put(b, "main", 13, "t:charcoal 5")
	put(b, "main", 14, "t:stick 20")
	open(b)
	select(b, mash.id)
	print(("bytes (%s): Crafting tab, two group ingredients chosen, two kinds each carried: " ..
		"content %d, page %d"):format(label, #content(b.formspec), #b.formspec))
	select(b, torch.id)
	print(("bytes (%s): Crafting tab, the torch chosen, coal and charcoal carried: " ..
		"content %d, page %d"):format(label, #content(b.formspec), #b.formspec))
	b.inv:set_stack("main", 10, ItemStack(""))
	b.inv:set_stack("main", 13, ItemStack(""))
	select(b, mash.id)
	print(("bytes (%s): Crafting tab, two group ingredients chosen, one kind carried: " ..
		"content %d, page %d"):format(label, #content(b.formspec), #b.formspec))
end
if BYTES_ONLY then
	bytes_report("bytes only")
	return
end

------------------------------------------------------------------------------
-- D. The dropdown.
------------------------------------------------------------------------------
local p = new_player("p")
put(p, "main", 9, "t:carrot 10")
put(p, "main", 10, "t:grain 5")
open(p)
select(p, mash.id)
eq(n_dropdowns(p.formspec), 0, "D one kind carried: no dropdown")
has(p.formspec, "Carrot or Cassava]", "D ... the row keeps the group's name")
eq(max_of(p.formspec), 3, "D Max with carrots only (3 per craft)")
-- Cassava with metadata does not count: still one kind.
put(p, "main", 11, "t:cassava 4 0 grug_tag=x")
rebuild(p)
eq(n_dropdowns(p.formspec), 0, "D a stack with metadata adds no kind")
put(p, "main", 11, "t:cassava 4")
rebuild(p)
local d = dropdowns(p.formspec)
eq(n_dropdowns(p.formspec), 2, "D two kinds carried: a dropdown per group entry")
eq(d[1] and d[1].items, "Automatic,Carrot (10),Cassava (4)",
	"D the root's dropdown: Automatic, then each carried kind with its count")
eq(d[2] and d[2].items, "Automatic,Carrot (10),Cassava (4)",
	"D the staple's dropdown: the potato is not carried")
eq(d[1] and d[1].selected, 1, "D Automatic is chosen")
lacks(p.formspec, pick(p, 3), "D an item entry has no dropdown")
fits(p.formspec, "D two dropdowns")
-- Automatic equals the count without a choice (today's behaviour).
local counts = J.ingredient_counts(p)
eq(max_of(p.formspec), J.crafts_from_counts(counts, mash), "D Automatic: the plain count")
eq(max_of(p.formspec), 4, "D Automatic: 4 (grain, then 8 + 4 of the 14 roots)")
eq(row_n(p.formspec, "Sweetroot Mash"), 4, "D the list's ×N agrees")
check(J.picked_ingredients(mash.ingredients, nil) == mash.ingredients and
	J.picked_ingredients(mash.ingredients, {}) == mash.ingredients,
	"D no choice: the recipe's own list")
put(p, "main", 12, "t:potato 2")
rebuild(p)
d = dropdowns(p.formspec)
eq(d[2] and d[2].items, "Automatic,Carrot (10),Cassava (4),Potato (2)",
	"D the staple's dropdown lists the potato too")
eq(d[1] and d[1].items, "Automatic,Carrot (10),Cassava (4)", "D ... the root's does not")
fits(p.formspec, "D three kinds")
p.inv:set_stack("main", 12, ItemStack(""))
rebuild(p)

------------------------------------------------------------------------------
-- C. The choice.
------------------------------------------------------------------------------
local sent = p.sent
click(p, {[pick(p, 1)] = "3"})
eq(p.sent, sent + 1, "C a changed dropdown resends once")
eq(st_of(p).picks and st_of(p).picks.root, "t:cassava", "C the root takes cassava")
d = dropdowns(p.formspec)
eq(d[1] and d[1].selected, 3, "C the dropdown shows the choice")
eq(d[2] and d[2].selected, 1, "C the other group stays Automatic")
eq(max_of(p.formspec), 2, "C Max: 4 cassava make 2")
eq(row_n(p.formspec, "Sweetroot Mash"), 2, "C the list's ×N follows the choice")
has(p.formspec, "item_image[5.6,", "C the row keeps its icon")
check(content(p.formspec):find("0.4,0.4;t:cassava]dropdown[", 1, true) ~= nil,
	"C the icon shows the chosen kind")
-- Both groups on cassava: three per craft.
click(p, {[pick(p, 2)] = "3"})
eq(max_of(p.formspec), 1, "C both groups on cassava: 4 make 1 (3 per craft)")
-- Back to Automatic for the staple.
click(p, {[pick(p, 2)] = "1"})
eq(st_of(p).picks.staple, nil, "C Automatic clears the choice")
eq(max_of(p.formspec), 2, "C Max back to 2")
-- The dropdowns' values every other event carries change nothing.
sent = p.sent
check(not click(p, {[pick(p, 1)] = "3", [pick(p, 2)] = "1"}),
	"C values equal to the built ones: not handled")
eq(p.sent, sent, "C ... and nothing is resent")
click(p, {[SCROLL] = "CHG:3", [pick(p, 1)] = "3"})
eq(p.sent, sent, "C a pure scrollbar event resends nothing")
eq(st_of(p).picks.root, "t:cassava", "C ... and keeps the choice")
-- A value out of range is ignored.
click(p, {[pick(p, 1)] = "9"})
eq(st_of(p).picks.root, "t:cassava", "C an index out of range changes nothing")
-- Craft now with the choice: cassava for the root, Automatic's carrot for
-- the staple.
click(p, {[FIELDS.qty] = "2", [FIELDS.go] = "Craft now", [pick(p, 1)] = "3", [pick(p, 2)] = "1"})
check(J.job_state(p) ~= nil, "C the job starts")
eq(count_of(p, "t:cassava"), 0, "C the take: all four cassava for the root")
eq(count_of(p, "t:carrot"), 8, "C ... one carrot per craft for the staple")
eq(count_of(p, "t:grain"), 3, "C ... and the grain")

------------------------------------------------------------------------------
-- F. The fallback.
------------------------------------------------------------------------------
eq(st_of(p).picks, nil, "F the chosen kind used up: Automatic on the next build")
eq(n_dropdowns(p.formspec), 0, "F ... and one kind left: no dropdown")
finish_job(p)
eq(count_of(p, "t:mash"), 2, "F the job made two")
-- A group left with one kind while the chosen kind is still carried.
put(p, "main", 11, "t:cassava 4")
rebuild(p)
click(p, {[pick(p, 1)] = "2"})
eq(st_of(p).picks.root, "t:carrot", "F the root takes carrot")
p.inv:set_stack("main", 9, ItemStack(""))
rebuild(p)
eq(st_of(p).picks, nil, "F the chosen kind no longer carried: Automatic")
-- A start with a kind gone since the page was built is refused, never a
-- take of another kind.
put(p, "main", 9, "t:carrot 10")
rebuild(p)
click(p, {[pick(p, 1)] = "3"})
p.inv:set_stack("main", 11, ItemStack(""))
click(p, {[FIELDS.qty] = "1", [FIELDS.go] = "Craft now", [pick(p, 1)] = "3"})
eq(J.job_state(p), nil, "F a stale choice starts nothing")
eq(count_of(p, "t:carrot"), 10, "F ... and takes nothing")
eq(st_of(p).picks, nil, "F ... and the page falls back to Automatic")
-- Another recipe starts on Automatic; a row click carries the old values.
put(p, "main", 11, "t:cassava 4")
put(p, "main", 13, "t:coal 3")
put(p, "main", 14, "t:charcoal 5")
put(p, "main", 15, "t:stick 20")
rebuild(p)
click(p, {[pick(p, 1)] = "3"})
eq(st_of(p).picks.root, "t:cassava", "F cassava chosen for the mash")
local rows = st_of(p).rows
local torch_row
for index, id in ipairs(rows) do if id == torch.id then torch_row = index end end
click(p, {[FIELDS.row .. torch_row] = "", [pick(p, 1)] = "3", [pick(p, 2)] = "1"})
eq(st_of(p).selected, torch.id, "F the torch chosen")
eq(st_of(p).picks, nil, "F another recipe: no choice (the old values ignored)")
-- A change made on the mash's page after the torch row was clicked (before
-- the torch's page arrived) names the old build's serial: ignored.
do
	local stale = PICK .. (st_of(p).pick_rows.serial - 1) .. "_1"
	local before = p.sent
	check(not click(p, {[stale] = "2"}), "F a stale page's dropdown change: not handled")
	eq(st_of(p).picks, nil, "F ... it chooses nothing on the new page")
	eq(p.sent, before, "F ... and resends nothing")
end
eq(dropdowns(p.formspec)[1] and dropdowns(p.formspec)[1].selected, 1,
	"F ... its dropdown on Automatic")
select(p, mash.id)
eq(dropdowns(p.formspec)[1] and dropdowns(p.formspec)[1].selected, 1,
	"F back to the mash: Automatic again")
local stored = false
for key in pairs(p.meta.fields) do
	if key:find("pick", 1, true) then stored = true end
end
check(not stored, "F the choice is never stored in player meta")

------------------------------------------------------------------------------
-- T. The torch: coal or charcoal.
------------------------------------------------------------------------------
select(p, torch.id)
d = dropdowns(p.formspec)
eq(d[1] and d[1].items, "Automatic,Charcoal (5),Coal Lump (3)",
	"T the torch's fuel: Charcoal or Coal Lump")
eq(d[2], nil, "T one kind of stick: no dropdown")
has(p.formspec, "Charcoal or Coal Lump", "T the group's name in the tooltip")
eq(max_of(p.formspec), 8, "T Automatic: 3 coal and 5 charcoal")
fits(p.formspec, "T the torch")
click(p, {[pick(p, 1)] = "3"})
eq(max_of(p.formspec), 3, "T coal lump chosen: 3")
click(p, {[pick(p, 1)] = "2"})
eq(max_of(p.formspec), 5, "T charcoal chosen: 5")
click(p, {[FIELDS.qty] = "5", [FIELDS.go] = "Craft now", [pick(p, 1)] = "2"})
eq(count_of(p, "t:charcoal"), 0, "T the take: the charcoal")
eq(count_of(p, "t:coal"), 3, "T ... and no coal")
finish_job(p)
eq(count_of(p, "t:torch"), 50, "T 5 crafts make 50 torches")
-- A job of a recipe id that is gone (the two old torch rows) returns its
-- ingredients at its end.
local old = new_player("old")
J.begin_job(old, {kind = "recipe", recipe = "default:torch|default:coal_lump*1+group:stick*1",
	quantity = 2, consumed = {"t:coal 2", "t:stick 2"}, duration = 2})
advance(3)
run_timers()
eq(count_of(old, "t:coal"), 2, "T a running job of the old id returns its coal")
eq(count_of(old, "t:stick"), 2, "T ... and its sticks")

bytes_report("this branch")

------------------------------------------------------------------------------
-- E. Exactness on the real Basic and Cooking catalogs.
------------------------------------------------------------------------------
local H = dofile(ROOT .. "/tools/r46_ck/jobs_harness.lua")(ROOT)
J = grug_jobs
local corpus = dofile(ROOT .. "/tools/r45_rg/corpus_base.lua")
for token, members in pairs(corpus.groups) do
	local group = token:match("^group:([%w_]+)$")
	if group then
		for _, name in ipairs(members) do
			H.items[name] = H.items[name] or {groups = {}}
			H.items[name].groups[group] = 1
		end
	end
end
do
	-- Charcoal's groups as grug_smelting registers them.
	local text = io.open(ROOT .. "/mods/ITEMS/grug_smelting/recipes.lua"):read("*a")
	local groups = text:match('register_craftitem%("grug_smelting:charcoal",.-groups = (%b{})')
	H.items["grug_smelting:charcoal"] = {groups = loadstring("return " .. groups)()}
	check(H.items["grug_smelting:charcoal"].groups.coal == 1, "E charcoal is in the coal group")
end
J.register_basic_catalog(dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_recipes.lua"))

-- The real torch.
local torches = J.recipes_for_output("default:torch")
eq(#torches, 1, "E one torch recipe")
local real_torch = torches[1]
eq(real_torch and real_torch.id, "default:torch|group:coal*1+group:stick*1",
	"E its id: the coal group and a stick")
eq(real_torch and real_torch.count, 10, "E 10 torches per craft")
eq(J.recipe("default:torch|default:coal_lump*1+group:stick*1"), nil, "E the coal row's id is gone")
eq(J.recipe("default:torch|grug_smelting:charcoal*1+group:stick*1"), nil,
	"E the charcoal row's id is gone")
do
	local player = H.player_with({"default:coal_lump 3", "grug_smelting:charcoal 5",
		"default:stick 20"})
	local c = J.ingredient_counts(player)
	eq(J.crafts_from_counts(c, real_torch), 8, "E the torch: coal and charcoal count")
	eq(J.crafts_from_counts(c, real_torch, {coal = "default:coal_lump"}), 3, "E ... coal chosen")
	eq(J.crafts_from_counts(c, real_torch, {coal = "grug_smelting:charcoal"}), 5,
		"E ... charcoal chosen")
end

-- A small deterministic generator (no math.random: the same cases every run).
local seed = 46
local function rand(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n
end
local function members_of(group)
	local out = {}
	for name, def in pairs(H.items) do
		if def.groups and (def.groups[group] or 0) > 0 then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end
local member_cache = {}
local function members(group)
	member_cache[group] = member_cache[group] or members_of(group)
	return member_cache[group]
end
local function ceiling_of(recipe)
	return math.floor(4 * 99 / recipe.count)
end
-- consumed itemstrings -> name -> count
local function tally(consumed)
	local out = {}
	for _, text in ipairs(consumed or {}) do
		local name, count = text:match("^(%S+) (%d+)")
		out[name] = (out[name] or 0) + tonumber(count)
	end
	return out
end
-- One inventory for `recipe`: per entry a few kinds with random counts
-- (overlapping members included), a stack of something else, split stacks.
local function inventory_for(recipe)
	local list = {}
	for _, entry in ipairs(recipe.ingredients) do
		local names = entry.item and {entry.item} or members(entry.group)
		local kinds = 1 + rand(3)
		for _ = 1, kinds do
			local name = names[1 + rand(#names)]
			list[#list + 1] = name .. " " .. (1 + rand(entry.n * 6 + 3))
			if rand(4) == 0 then list[#list + 1] = name .. " " .. (1 + rand(9)) end
		end
	end
	list[#list + 1] = "default:dirt " .. (1 + rand(20))
	-- Shuffle (the take order follows the slots).
	for index = #list, 2, -1 do
		local other = 1 + rand(index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end
local cases, recipes_checked, craftable = 0, 0, 0
local function exact(recipe, list, picks, label)
	local counts = J.ingredient_counts(H.player_with(list))
	local n = J.crafts_from_counts(counts, recipe, picks)
	local ingredients = J.picked_ingredients(recipe.ingredients, picks)
	local ceiling = ceiling_of(recipe)
	cases = cases + 1
	if n > 0 then craftable = craftable + 1 end
	local consumed = n > 0 and J.take_ingredients(H.player_with(list), ingredients, n)
	local ok = (n == 0 or consumed ~= nil) and (n > ceiling or
		J.take_ingredients(H.player_with(list), ingredients, n + 1) == nil)
	if not check(ok, ("E %s: ×%d is what the take takes (%s)"):format(recipe.id, n, label)) then
		print("  inventory: " .. table.concat(list, ", "))
	end
	if consumed and picks then
		-- No kind of a chosen group is taken unless another entry accepts it.
		for name in pairs(tally(consumed)) do
			local accepted = false
			for _, entry in ipairs(ingredients) do
				if J.ingredient_accepts(entry, name) then accepted = true end
			end
			check(accepted, ("E %s: %s taken only where an entry accepts it (%s)"):format(
				recipe.id, name, label))
		end
	end
	return n
end
for _, recipe in ipairs(J.recipes) do
	local groups = {}
	for _, entry in ipairs(recipe.ingredients) do
		if entry.group then groups[#groups + 1] = entry.group end
	end
	if #groups > 0 then
		recipes_checked = recipes_checked + 1
		for _ = 1, 6 do
			local list = inventory_for(recipe)
			local plain = exact(recipe, list, nil, "Automatic")
			eq(exact(recipe, list, {}, "no choice"), plain, "E " .. recipe.id .. ": {} equals Automatic")
			local carried = J.ingredient_counts(H.player_with(list)).items
			local all = {}
			for _, group in ipairs(groups) do
				for _, name in ipairs(members(group)) do
					if (carried[name] or 0) > 0 then
						exact(recipe, list, {[group] = name}, group .. "=" .. name)
						all[group] = all[group] or name
					end
				end
			end
			if #groups > 1 then exact(recipe, list, all, "every group chosen") end
		end
	end
end
check(recipes_checked >= 60, "E at least 60 recipes with a group entry (got " .. recipes_checked .. ")")
print(("E %d recipes with a group entry, %d inventory x choice cases, %d craftable"):format(
	recipes_checked, cases, craftable))

if failures > 0 then
	error(("R46 ID PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R46 ID PORTABLE PASS checks=%d"):format(checks))
