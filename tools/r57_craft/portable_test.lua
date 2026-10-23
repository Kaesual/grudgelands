-- Round 57 lane CRAFT portable test (LuaJIT): the crafting queue, layout C,
-- favourites and the recursive Basic unlock (round57-plan.md rulings 1-4, 6,
-- 7; docs/design/professions.md §1.2).
--
--   luajit tools/r57_craft/portable_test.lua [REPO]
--
-- Loads the REAL vendored sfinv, grug_inventory's bags.lua (the give helper
-- and the fit check) and ui.lua (the frame), the REAL grug_jobs
-- registry.lua, state.lua, jobs.lua, overview.lua, ui.lua, craft_box.lua,
-- basic_unlock.lua, operation_jobs.lua and queue_box.lua under r45_ui's
-- stub engine (a wall clock, the microsecond counter, core.after, player
-- meta), with one stand-in enchant operation. Checks:
--   Q  the queue: five jobs (one an enchant) accepted while a job runs, the
--      sixth refused with a message and nothing taken; inputs and the
--      enchant's target taken at queueing (the slot is free again); the
--      station checked when queued, never when a waiting job starts; each
--      waiting job starts at the end of the one before; the running job
--      stays in grug_jobs:job in Round 56's format, only the waiting ones
--      in grug_jobs:queue;
--   C  cancel: a waiting job's ✕ returns its ingredients and the enchant's
--      target whole; a cancel that does not fit is refused (nothing
--      changes); a stale ✕ never cancels another job; the stop button
--      stops the running job (refund as before) and the next starts now;
--   O  an old save: only grug_jobs:job (a Round 56 job, no queue key) reads
--      and completes at the login; a queue the format cannot read is
--      dropped with the job kept;
--   F  offline: three jobs, the player logs out with a full inventory and
--      back in after all have ended: every one completes in order, each
--      from the end of the one before, every output survives in the grown
--      overflow, nothing drops; the drain shrinks it back;
--   L  layout C: Craft ×N while idle, Queue ×N while a job runs, the job
--      strip (the bar, the small stop button, one line, View Queue [N])
--      under every box (another recipe, the overview, a details box), no
--      countdown, the output slots only while filled, the queue view
--      (rows, ✕, "◀ Back to recipe", "N of 5 slots"), a full queue greys
--      the button, every element inside its column;
--   V  favourites: the star toggles a recipe, saved in player meta (a
--      rejoin reads it), "Favorites only" alone and with "Craftable only";
--   U  the recursive Basic unlock: learning a profession unlocks the Basic
--      recipes its tier-1 recipes need, recursively (Thread, then Patch
--      Bolt), not a reverse step (block from stairs); a tier advance adds
--      that tier's; /prof's admin_set the tiers up to N; the join catches a
--      character up that is already past a tier; "held once" still works;
--      the unlock stays after an unlearn.
-- Prints "R57 CRAFT PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local online, nodes, feed_lines, dropped = {}, {}, {}, {}
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
	add_item = function(_, stack) dropped[#dropped + 1] = ItemStack(stack) end,
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
	-- (Round 47: the recipe scan reads every list.)
	function inv:get_lists()
		local out = {}
		for name, l in pairs(self.lists) do
			out[name] = {}
			for i = 1, #l do out[name][i] = ItemStack(l[i]) end
		end
		return out
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

grug_items = {
	crafted_output = function() return false end,
	-- The stand-in enchant's rules: a cloak takes it; the result is the
	-- cloak with the stat written into its meta.
	family_for = function(stack) return stack:get_name() == "t:cloak" and "cloak" or nil end,
	AFFIXES = {str = {label = "Strength"}},
	operation_result = function(op, target)
		if target:is_empty() then return nil, "Place an item in the Target slot." end
		local out = ItemStack(target)
		out:get_meta():set_string("grug_enchanted", op.enchant_stat)
		return {output = out}
	end,
	upgrade_span = function() return nil, "no upgrade here" end,
}

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("t:log", {description = "Aspen Log"})
item("t:plank", {description = "Aspen Wood Planks"})
item("t:meat", {description = "Meat"})
item("t:grain", {description = "Wild Grain"})
item("t:stew", {description = "Hearty Stew", stack_max = 20})
item("t:linen", {description = "Linen Scrap"})
item("t:thread", {description = "Thread"})
item("t:bolt", {description = "Patch Bolt"})
item("t:bolt_block", {description = "Patch Bolt Bundle"})
item("t:leather", {description = "Light Leather"})
item("t:bag", {description = "Small Bag", stack_max = 1})
item("t:silk", {description = "Silk Scrap"})
item("t:silk_bolt", {description = "Silk Bolt"})
item("t:robe", {description = "Silk Robe", stack_max = 1})
item("t:dust", {description = "Arcane Dust"})
item("t:cloak", {description = "Patch Cloak", stack_max = 1})
item("t:dirt", {description = "Dirt"})
item("t:stone", {description = "Stone"})
core.registered_nodes["t:bench"] = {_grug_station = "tailor_bench"}

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
dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_unlock.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/operation_jobs.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/queue_box.lua")
local J = grug_jobs

-- The recipes: Basic planks (1 s each), the Basic chain Linen Scrap ->
-- Thread -> Patch Bolt with a reverse pair (bundle <-> bolts), a Cooking
-- stew, a Tailor T1 bag on bolts and a T2 robe on silk bolts.
J.register_ingredient_tier("t:meat", 1)
J.register_ingredient_tier("t:leather", 1)
J.register_ingredient_tier("t:silk", 2)
local plank = J.register_recipe({area = "basic", output = "t:plank", count = 4,
	ingredients = {{item = "t:log", n = 1}}})
local thread = J.register_recipe({area = "basic", output = "t:thread", count = 2,
	ingredients = {{item = "t:linen", n = 1}}})
local bolt = J.register_recipe({area = "basic", output = "t:bolt",
	ingredients = {{item = "t:linen", n = 2}, {item = "t:thread", n = 1}}})
local bundle = J.register_recipe({area = "basic", output = "t:bolt_block",
	ingredients = {{item = "t:bolt", n = 9}}})
local unbundle = J.register_recipe({area = "basic", output = "t:bolt", count = 9,
	ingredients = {{item = "t:bolt_block", n = 1}}})
local silk_bolt = J.register_recipe({area = "basic", output = "t:silk_bolt",
	ingredients = {{item = "t:silk", n = 2}, {item = "t:thread", n = 1}}})
local stew = J.register_recipe({area = "cooking", tier = 1, output = "t:stew",
	ingredients = {{item = "t:meat", n = 1}, {item = "t:grain", n = 1}}, time = 1})
local bag = J.register_recipe({area = "tailor", tier = 1, station = "tailor_bench",
	output = "t:bag", ingredients = {{item = "t:bolt", n = 2}, {item = "t:leather", n = 1}},
	time = 3})
local robe = J.register_recipe({area = "tailor", tier = 2, station = "tailor_bench",
	output = "t:robe", ingredients = {{item = "t:silk_bolt", n = 2}, {item = "t:silk", n = 1}},
	time = 3})
for _, fn in ipairs(callbacks.loaded) do fn() end

-- The stand-in enchant (station_operations.lua is not loaded here).
local ENCHANT = {id = "enchant:cloak:prefix:str:t1", operation = "enchant", profession = "tailor",
	tier = 1, station = "tailor_bench", enchant_stat = "str", enchant_channel = "prefix",
	ingredients = {{item = "t:dust", n = 1}}, progress = true}
J.station_operation = function(id) return id == ENCHANT.id and ENCHANT or nil end
J.operation_ingredients = function(op) return op.ingredients end

local F = J.CRAFT_FIELDS
local OUT, TARGET = J.OUTPUT_LIST, J.TARGET_LIST
local ends = {}
J.register_on_job_end(function(player, job, outcome, source)
	ends[#ends + 1] = {name = player:get_player_name(), kind = job.kind, recipe = job.recipe,
		start = job.start, finish = job.finish, outcome = outcome, source = source}
end)

local function new_meta()
	local fields = {}
	return {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return math.floor(tonumber(fields[key]) or 0) end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
		fields = fields,
	}
end
local function join(player)
	online[player.name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
end
local function leave(player)
	online[player.name] = nil
	for _, f in ipairs(callbacks.leave) do f(player) end
	sfinv.contexts[player.name] = nil
end
local function new_player(name, opts)
	opts = opts or {}
	local inv = new_inventory()
	inv:set_size("main", 32)
	local player = {name = name, inv = inv, meta = opts.meta or new_meta(), sent = 0,
		pos = {x = 0.3, y = 10, z = -0.2}}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return self.meta end
	function player:is_player() return true end
	function player:get_pos() return self.pos end
	function player:set_inventory_formspec(fs)
		self.sent = self.sent + 1
		self.formspec = fs
	end
	if opts.join ~= false then join(player) end
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
local function fill_empty(player, itemstring)
	local filled = {}
	for index = 1, player.inv:get_size("main") do
		if player.inv:get_stack("main", index):is_empty() then
			put(player, "main", index, itemstring)
			filled[#filled + 1] = index
		end
	end
	return filled
end
local function clear_slots(player, slots)
	for _, index in ipairs(slots) do put(player, "main", index, "") end
end
local function at_bench() nodes = {{name = "t:bench", pos = {x = 2, y = 10, z = 0}}} end
local function away() nodes = {} end
local function open(player)
	sfinv.set_page(player, "sfinv:crafting")
	return player.formspec
end
local function click(player, fields)
	for _, f in ipairs(callbacks.receive) do
		local r = f(player, "", fields)
		if r then return r end
	end
end
local function st_of(player) return sfinv.get_or_create_context(player).grug_craft end
local function content(fs) return fs:match("real_coordinates%[false%](.*)$") or "" end
local function raw(player, key) return player.meta:get_string(key) end
local function decoded(player, key)
	local text = raw(player, key)
	return text ~= "" and core.deserialize(text) or nil
end
local function learn_cooking(player)
	player.meta:set_int("grug_jobs:learned:cooking", 1)
	player.meta:set_int("grug_jobs:level:cooking", 1)
end
-- Selects the first list row whose recipe is `recipe` in area tab `slot`.
local function choose(player, slot, recipe)
	open(player)
	click(player, {[F.area .. slot] = "x"})
	for index, id in ipairs(st_of(player).rows) do
		if id == recipe.id then
			click(player, {[F.row .. index] = "x"})
			return true
		end
	end
	return false
end

-- Geometry (r45_ui's rule, two columns in layout C).
local function plain_text(text)
	return (text:gsub("\27%(c@#%x+%)", ""):gsub("\\(.)", "%1"))
end
local function utf8_len(text)
	local _, extra = text:gsub("[\128-\191]", "")
	return #text - extra
end
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
local COLUMNS = {{0.2, 5.2}, {5.4, 13.3}}
local function geometry_ok(fs, label)
	local ok = true
	for _, r in ipairs(rects(content(fs))) do
		local right, bottom = r.x + r.w, r.y + r.h
		if r.x < 0 or r.y < 0 or right > 13.5 + 1e-6 or
				bottom > grug_inventory.VIEW_GEOMETRY.top - 0.1 + 0.01 then
			ok = check(false, ("%s: %s at %.2f,%.2f+%.2f,%.2f leaves the page area"):format(
				label, r.name, r.x, r.y, r.w, r.h))
		elseif r.y >= 0.95 then
			for _, column in ipairs(COLUMNS) do
				-- (a checkbox of the list may run into the gap before the box:
				-- "Favorites only" beside "Craftable only", Round 57)
				local limit = column[2] + ((r.name == "checkbox" and column[2] < 5.3) and 0.2 or 0.05)
				if r.x >= column[1] - 1e-6 and r.x < column[2] and right > limit then
					ok = check(false, ("%s: %s %q at %.2f,%.2f runs out of its column (%.2f)")
						:format(label, r.name, r.text or "", r.x, r.y, right))
				end
			end
		end
	end
	check(ok, label .. ": every element inside its column, above the view")
	local opened = select(2, fs:gsub("%[", "")) - select(2, fs:gsub("\\%[", ""))
	local closed = select(2, fs:gsub("%]", "")) - select(2, fs:gsub("\\%]", ""))
	eq(opened, closed, label .. ": balanced brackets")
end
local function queue_button(n) return F.queue .. ";" .. core.formspec_escape("View Queue [" ..
	n .. "]") .. "]" end

------------------------------------------------------------------------------
-- Q. Five jobs, one an enchant; the sixth refused.
------------------------------------------------------------------------------
do
	local p = new_player("q")
	learn_cooking(p)
	J.learn(p, "tailor", true)
	at_bench()
	put(p, "main", 9, "t:meat 20")
	put(p, "main", 10, "t:grain 20")
	put(p, "main", 11, "t:log 10")
	put(p, "main", 12, "t:dust 3")
	local t0 = J.now()
	local ok, reason, info = J.start_job(p, stew.id, 3)
	check(ok, "Q the first job starts")
	local job = J.job_state(p)
	check(job and not info.queued, "Q ... and runs at once")
	eq(raw(p, J.QUEUE_KEY), "", "Q nothing waits")
	-- The running job is the Round 56 record: the same keys, no queue fields.
	local record = decoded(p, J.JOB_KEY)
	local allowed = {kind = true, recipe = true, quantity = true, consumed = true, start = true,
		finish = true, delivered = true, picks = true, target = true, no_xp = true,
		operation = true}
	local extra = {}
	for key in pairs(record or {}) do
		if not allowed[key] then extra[#extra + 1] = key end
	end
	eq(table.concat(extra, ","), "", "Q the running job keeps Round 56's format")
	-- Four more while it runs: planks, the enchant, a stew, planks.
	ok, reason, info = J.start_job(p, plank.id, 2)
	check(ok and info.queued, "Q the second job waits")
	eq(count_of(p, "t:log"), 8, "Q its logs are taken when queued")
	-- The enchant: the station is checked when it is queued.
	put(p, TARGET, 1, "t:cloak")
	away()
	ok, reason, info = J.start_operation(p, ENCHANT.id)
	check(not ok and info.code == "station", "Q away from the bench the enchant is refused")
	check(not p.inv:get_stack(TARGET, 1):is_empty(), "Q ... and the cloak stays in its slot")
	at_bench()
	ok, reason, info = J.start_operation(p, ENCHANT.id)
	check(ok and info.queued, "Q at the bench the enchant waits")
	check(p.inv:get_stack(TARGET, 1):is_empty(), "Q the cloak left the slot (the next can go in)")
	eq(count_of(p, "t:dust"), 2, "Q its dust is taken")
	check(J.start_job(p, stew.id, 2), "Q the fourth job waits")
	check(J.start_job(p, plank.id, 1), "Q the fifth job waits")
	local queue = J.queue_state(p)
	eq(#queue, 4, "Q four wait beside the running one")
	eq(queue[2].kind, "enchant", "Q the enchant waits second")
	eq(ItemStack(queue[2].target):get_name(), "t:cloak", "Q ... holding the cloak")
	check(J.queue_full(p), "Q the queue is full at five")
	-- The sixth: refused, nothing taken.
	local logs, stored = count_of(p, "t:log"), raw(p, J.QUEUE_KEY)
	ok, reason, info = J.start_job(p, plank.id, 1)
	check(not ok and info.code == "busy", "Q the sixth job is refused")
	eq(reason, J.QUEUE_FULL, "Q ... with the message")
	eq(count_of(p, "t:log"), logs, "Q ... and nothing taken")
	put(p, TARGET, 1, "t:cloak")
	ok, reason, info = J.start_operation(p, ENCHANT.id)
	check(not ok and info.code == "busy", "Q a sixth enchant is refused too")
	check(not p.inv:get_stack(TARGET, 1):is_empty(), "Q ... its cloak stays in the slot")
	eq(raw(p, J.QUEUE_KEY), stored, "Q the queue is unchanged")
	put(p, TARGET, 1, "")
	-- Each waiting job starts where the one before ended, without the bench.
	away()
	local finish = job.finish
	advance(3)
	run_timers()
	job = J.job_state(p)
	check(job and job.recipe == plank.id, "Q the planks run next")
	check(job and math.abs(job.start - finish) < 1e-6, "Q ... from the stew's end")
	eq(job and job.finish - job.start, 2, "Q ... for their own time")
	eq(count_of(p, "t:stew"), 3, "Q the stews are made")
	local record2 = decoded(p, J.JOB_KEY)
	check(record2 and record2.id == nil and record2.duration == nil,
		"Q a started job is a plain running record")
	finish = job.finish
	advance(2)
	run_timers()
	job = J.job_state(p)
	check(job and job.kind == "enchant", "Q the enchant starts away from the bench")
	check(job and math.abs(job.start - finish) < 1e-6, "Q ... from the planks' end")
	advance(5)
	run_timers()
	local cloak
	for _, stack in ipairs(p.inv:get_list("main")) do
		if stack:get_name() == "t:cloak" then cloak = stack end
	end
	check(cloak and cloak:get_meta():get_string("grug_enchanted") == "str",
		"Q the enchanted cloak arrives")
	advance(3)
	run_timers()
	eq(J.job_state(p), nil, "Q all five done")
	eq(raw(p, J.QUEUE_KEY), "", "Q the queue key is empty again")
	eq(count_of(p, "t:stew"), 5, "Q 3 + 2 stews")
	eq(count_of(p, "t:plank"), 12, "Q 2 + 1 plank crafts of 4")
	eq(J.crafts_in_tier(p, "tailor"), 1, "Q the enchant counted as a craft")
	eq(#dropped, 0, "Q nothing dropped")
end

------------------------------------------------------------------------------
-- C. Cancel a waiting job, a refused cancel, a stale ✕, the stop button.
------------------------------------------------------------------------------
do
	local c = new_player("c")
	learn_cooking(c)
	J.learn(c, "tailor", true)
	at_bench()
	put(c, "main", 9, "t:meat 10")
	put(c, "main", 10, "t:grain 10")
	put(c, "main", 11, "t:log 10")
	put(c, "main", 12, "t:dust 2")
	local cloak = ItemStack("t:cloak")
	cloak:get_meta():set_string("grug_quality", "3")
	c.inv:set_stack(TARGET, 1, cloak)
	check(J.start_job(c, stew.id, 5), "C a running stew job")
	check(J.start_operation(c, ENCHANT.id), "C an enchant waits")
	check(J.start_job(c, plank.id, 3), "C planks wait")
	eq(count_of(c, "t:dust"), 1, "C the dust is held by the queue")
	open(c)
	click(c, {[F.queue] = "View Queue"})
	local fs = c.formspec
	has(fs, "Crafting queue", "C the queue view")
	local queue = J.queue_state(c)
	has(fs, F.unqueue .. queue[1].id .. ";✕]", "C a ✕ per waiting job")
	-- ✕ on the enchant: the cloak (whole, its meta kept) and the dust back.
	click(c, {[F.unqueue .. queue[1].id] = "✕"})
	eq(#J.queue_state(c), 1, "C the enchant left the queue")
	eq(count_of(c, "t:dust"), 2, "C its dust is back")
	local back
	for _, stack in ipairs(c.inv:get_list("main")) do
		if stack:get_name() == "t:cloak" then back = stack end
	end
	check(back and back:get_meta():get_string("grug_quality") == "3",
		"C the cloak is back with its metadata")
	-- A refused cancel: no room for the logs (their stack full too).
	put(c, "main", 11, "t:log 99")
	local filled = fill_empty(c, "t:dirt 99")
	local before = raw(c, J.QUEUE_KEY)
	local id = J.queue_state(c)[1].id
	click(c, {[F.unqueue .. id] = "✕"})
	eq(raw(c, J.QUEUE_KEY), before, "C a cancel without room changes nothing")
	has(c.formspec, "Not enough inventory space to cancel", "C ... and says why")
	-- A stale ✕ (an id no job waits under) cancels nothing.
	clear_slots(c, filled)
	click(c, {[F.unqueue .. (id + 7)] = "✕"})
	eq(raw(c, J.QUEUE_KEY), before, "C a stale ✕ cancels nothing")
	has(c.formspec, "That job is no longer waiting.", "C ... and says so")
	-- The stop button: the stew's ingredients back, the planks start now.
	advance(1.5)
	local stop_at = J.now()
	click(c, {[F.stop] = "■"})
	local job = J.job_state(c)
	check(job and job.recipe == plank.id, "C stop: the planks start")
	check(job and math.abs(job.start - stop_at) < 1e-6, "C ... now, not at the stew's end")
	eq(count_of(c, "t:stew"), 1, "C the finished stew stays")
	eq(count_of(c, "t:meat"), 9, "C the unfinished stews' meat is back")
	eq(#J.queue_state(c), 0, "C nothing waits")
	advance(3)
	run_timers()
	eq(count_of(c, "t:plank"), 12, "C the planks are made")
end

------------------------------------------------------------------------------
-- O. An old save: grug_jobs:job only (Round 56), no queue key.
------------------------------------------------------------------------------
do
	local meta = new_meta()
	local now = J.now()
	meta:set_string(J.JOB_KEY, core.serialize({kind = "recipe", recipe = stew.id, quantity = 2,
		consumed = {"t:meat 2 0", "t:grain 2 0"}, start = now - 10, finish = now - 8,
		delivered = 0}))
	local o = new_player("o", {meta = meta})
	eq(count_of(o, "t:stew"), 2, "O the old job completes at the login")
	eq(raw(o, J.JOB_KEY), "", "O ... and leaves no job")
	eq(raw(o, J.QUEUE_KEY), "", "O ... and no queue")
	-- One still running at the login keeps running, then completes.
	leave(o)
	now = J.now()
	meta:set_string(J.JOB_KEY, core.serialize({kind = "recipe", recipe = stew.id, quantity = 1,
		consumed = {"t:meat 1 0", "t:grain 1 0"}, start = now - 0.5, finish = now + 0.5,
		delivered = 0}))
	join(o)
	check(J.job_state(o) ~= nil, "O a job still running at the login runs on")
	advance(0.6)
	run_timers()
	eq(count_of(o, "t:stew"), 3, "O ... and completes")
	-- A queue the format cannot read is dropped; the running job stays.
	learn_cooking(o)
	put(o, "main", 9, "t:meat 2")
	put(o, "main", 10, "t:grain 2")
	check(J.start_job(o, stew.id, 2), "O a job")
	meta:set_string(J.QUEUE_KEY, "return {{kind = 'recipe'}}")
	eq(#J.queue_state(o), 0, "O an unreadable entry is dropped")
	check(J.job_state(o) ~= nil, "O ... and the running job stays")
	advance(2)
	run_timers()
end

------------------------------------------------------------------------------
-- F. Offline: three jobs end while the player is away with a full
-- inventory; every output survives in the grown overflow.
------------------------------------------------------------------------------
do
	local f = new_player("f")
	learn_cooking(f)
	put(f, "main", 9, "t:meat 10")
	put(f, "main", 10, "t:grain 10")
	put(f, "main", 11, "t:log 60")
	check(J.start_job(f, stew.id, 2), "F a running stew job")
	check(J.start_job(f, plank.id, 50), "F 50 plank crafts wait (200 planks)")
	check(J.start_job(f, stew.id, 3), "F three stews wait")
	-- The inventory fills up and the overflow holds four stacks already.
	local filled = fill_empty(f, "t:dirt 99")
	for index = 1, 4 do put(f, OUT, index, "t:stone 99") end
	local before = #ends
	local logout = J.now()
	leave(f)
	advance(100)
	run_timers()
	eq(#ends, before, "F nothing completes while offline (no timer for an absent player)")
	join(f)
	eq(#ends - before, 3, "F all three complete at the login")
	local a, b, c = ends[before + 1], ends[before + 2], ends[before + 3]
	check(a and b and c and a.recipe == stew.id and b.recipe == plank.id and c.recipe == stew.id,
		"F ... in queue order")
	check(a and math.abs(a.finish - (logout + 2)) < 1e-6, "F the first ends at its own time")
	check(a and b and math.abs(b.start - a.finish) < 1e-6, "F the second starts at the first's end")
	check(b and c and math.abs(c.start - b.finish) < 1e-6, "F the third at the second's end")
	eq(J.job_state(f), nil, "F nothing runs")
	eq(#dropped, 0, "F nothing dropped")
	eq(count_of(f, "t:stew"), 5, "F every stew survives")
	eq(count_of(f, "t:plank"), 200, "F every plank survives")
	check(f.inv:get_size(OUT) > 4, "F the overflow grew (" .. f.inv:get_size(OUT) .. " slots)")
	-- The page shows the first row of it with "+N more".
	local fs = open(f)
	has(fs, "list[current_player;grug_craft_out;", "F the overflow row is drawn")
	has(fs, "more", "F ... with the slots beyond the row counted")
	geometry_ok(fs, "F the grown overflow")
	-- Room again: the drain empties it and shrinks it back.
	clear_slots(f, filled)
	advance(J.OVERFLOW_POLL)
	run_timers()
	check(f.inv:is_empty(OUT), "F the drain empties the overflow")
	eq(f.inv:get_size(OUT), 4, "F ... and shrinks it back to 4 slots")
	eq(count_of(f, "t:plank") + count_of(f, "t:stew") + count_of(f, "t:stone"), 200 + 5 + 396,
		"F nothing lost on the way")
end

------------------------------------------------------------------------------
-- L. Layout C.
------------------------------------------------------------------------------
do
	local l = new_player("l")
	learn_cooking(l)
	put(l, "main", 9, "t:meat 20")
	put(l, "main", 10, "t:grain 20")
	put(l, "main", 11, "t:log 20")
	check(choose(l, 2, stew), "L the stew chosen")
	local fs = l.formspec
	has(fs, F.go .. ";Craft ×1]", "L Craft ×N while idle")
	has(fs, "No job running", "L the idle strip")
	lacks(fs, F.stop .. ";", "L no stop button while idle")
	lacks(fs, F.queue .. ";", "L no View Queue while idle")
	lacks(fs, "list[current_player;grug_craft_out;", "L no output slots while empty")
	has(fs, "checkbox[" .. J._fs_number(2.75) .. ",2;" .. F.fav_only .. ";Favorites only;false]",
		"L Favorites only beside Craftable only")
	geometry_ok(fs, "L idle")
	click(l, {[F.qty] = "4", [F.go] = "Craft ×4"})
	fs = l.formspec
	check(J.job_state(l) ~= nil, "L the click starts the job")
	has(fs, F.go .. ";Queue ×4]", "L Queue ×N while a job runs")
	has(fs, "animated_image[5.6,", "L the bar in the strip")
	has(fs, F.stop .. ";■]", "L the small stop button")
	has(fs, "Hearty Stew ×4", "L one line names the job")
	has(fs, queue_button(0), "L View Queue [0]")
	lacks(fs, " s left", "L no countdown")
	geometry_ok(fs, "L running")
	-- The strip stays on another recipe, on the overview and on a details box.
	check(choose(l, 1, plank), "L another recipe")
	has(l.formspec, "animated_image[5.6,", "L the bar stays on another recipe")
	has(l.formspec, F.go .. ";Queue ×1]", "L ... and it queues")
	click(l, {[F.area .. "2"] = "Cooking"})
	has(l.formspec, "animated_image[5.6,", "L the bar on the overview (no recipe chosen)")
	has(l.formspec, queue_button(0), "L ... and View Queue")
	lacks(l.formspec, "Recipe details", "L no details button before lane DETAILS")
	J.register_craft_box("details", {build = function() return "label[5.6,1.5;DETAILS PAGE]" end,
		fields = function() return false end})
	check(choose(l, 1, plank), "L the planks again")
	has(l.formspec, F.details .. ";Recipe details]", "L the details seam once a details box exists")
	click(l, {[F.details] = "Recipe details"})
	has(l.formspec, "DETAILS PAGE", "L the details box opens")
	has(l.formspec, "animated_image[5.6,", "L ... with the bar")
	has(l.formspec, F.stop .. ";■]", "L ... the stop button")
	has(l.formspec, queue_button(0), "L ... and View Queue")
	-- The queue view.
	click(l, {[F.qty] = "2", [F.go] = "Queue ×2"})
	check(choose(l, 1, plank), "L back at the planks")
	click(l, {[F.qty] = "2", [F.go] = "Queue ×2"})
	eq(#J.queue_state(l), 1, "L a job waits")
	has(l.formspec, queue_button(1), "L View Queue [1]")
	click(l, {[F.queue] = "View Queue [1]"})
	fs = l.formspec
	has(fs, "Crafting queue", "L the queue view")
	has(fs, "2 of 5 slots", "L ... its slots")
	has(fs, "Aspen Wood Planks ×8", "L ... the waiting job's line")
	has(fs, F.back .. ";" .. core.formspec_escape("◀ Back to recipe") .. "]", "L ... Back to recipe")
	has(fs, "style[" .. F.queue .. ";bgcolor=#8a682f", "L View Queue in the selection colour")
	has(fs, "animated_image[5.6,", "L the bar under the queue view")
	geometry_ok(fs, "L the queue view")
	click(l, {[F.back] = "x"})
	has(l.formspec, F.go .. ";Queue ×2]", "L Back returns to the recipe")
	-- Full: the button greys with the message.
	for _ = 1, 3 do click(l, {[F.qty] = "1", [F.go] = "Queue ×1"}) end
	eq(#J.queue_state(l), 4, "L the queue is full")
	fs = l.formspec
	has(fs, F.recheck .. ";Queue ×1]", "L a full queue greys the button")
	has(fs, "The crafting queue is full", "L ... with the message")
	-- The output slots only while filled.
	put(l, OUT, 1, "t:stone 3")
	fs = open(l)
	has(fs, "list[current_player;grug_craft_out;5.6,", "L the output row while filled")
	geometry_ok(fs, "L a full queue and the overflow")
	put(l, OUT, 1, "")
	advance(30)
	run_timers()
	eq(J.job_state(l), nil, "L the queue runs empty")
end

------------------------------------------------------------------------------
-- V. Favourites.
------------------------------------------------------------------------------
do
	local v = new_player("v")
	learn_cooking(v)
	-- (Tailor lists the bolt, which the inventory cannot make: no thread)
	J.learn(v, "tailor", true)
	put(v, "main", 11, "t:log 5")
	put(v, "main", 12, "t:linen 5")
	check(choose(v, 1, plank), "V the planks chosen")
	has(v.formspec, F.fav .. ";☆]", "V the empty star")
	click(v, {[F.fav] = "☆"})
	has(v.formspec, F.fav .. ";★]", "V a click marks it")
	check(J.is_favorite(v, plank.id), "V ... as a favourite")
	has(raw(v, J.FAVORITES_KEY), plank.id, "V saved in player meta")
	check(choose(v, 1, thread), "V the thread chosen")
	click(v, {[F.fav] = "☆"})
	-- The bolt is listed (linen held) but not craftable without thread.
	check(choose(v, 1, bolt), "V the bolt chosen")
	click(v, {[F.fav] = "☆"})
	click(v, {[F.fav_only] = "true"})
	local rows = st_of(v).rows
	eq(#rows, 3, "V Favorites only lists the three favourites")
	click(v, {[F.only] = "true"})
	rows = st_of(v).rows
	local set = {}
	for _, id in ipairs(rows) do set[id] = true end
	check(#rows == 2 and set[plank.id] and set[thread.id], "V both: the craftable favourites")
	click(v, {[F.fav_only] = "false"})
	check(#st_of(v).rows >= 2, "V Favorites off again")
	-- Unmark, rejoin: read from meta.
	check(choose(v, 1, thread), "V the thread again")
	click(v, {[F.fav] = "★"})
	check(not J.is_favorite(v, thread.id), "V a second click unmarks it")
	leave(v)
	join(v)
	check(J.is_favorite(v, plank.id) and J.is_favorite(v, bolt.id) and
		not J.is_favorite(v, thread.id), "V a rejoin reads the favourites")
	open(v)
	click(v, {[F.fav_only] = "true"})
	click(v, {[F.area .. "2"] = "Cooking"})
	has(v.formspec, "No favorite here yet.", "V an area without favourites says how to mark one")
end

------------------------------------------------------------------------------
-- U. The recursive Basic unlock.
------------------------------------------------------------------------------
do
	local tailor1 = J.needed_basic("tailor", 1)
	local in1 = {}
	for _, id in ipairs(tailor1) do in1[id] = true end
	check(in1[bolt.id] and in1[thread.id], "U tailor T1 needs the bolt, then the thread")
	check(not in1[unbundle.id] and not in1[bundle.id], "U never the reverse step (bundle <-> bolts)")
	check(not in1[silk_bolt.id], "U not T2's silk bolt")
	local u = new_player("u")
	check(not J.recipe_known(u, thread) and not J.recipe_known(u, bolt),
		"U a fresh character knows neither")
	local feeds = #feed_lines
	J.learn(u, "tailor")
	check(J.recipe_known(u, thread) and J.recipe_known(u, bolt), "U learning Tailor unlocks both")
	check(not J.recipe_known(u, unbundle), "U ... not the reverse step")
	eq(feed_lines[feeds + 1], "New recipes: Patch Bolt and 1 more", "U one feed line")
	has(raw(u, J.BASIC_UNLOCKED_KEY), bolt.id, "U the store holds the bolt")
	check(raw(u, J.BASIC_UNLOCKED_KEY):sub(1, 2) == "1 ", "U ... in the held set's format")
	-- The tier advance adds tier 2's.
	check(not J.recipe_known(u, silk_bolt), "U the silk bolt waits for tier 2")
	u.meta:set_int("grug_jobs:crafts:tailor", 10)
	character_level = 15
	local advanced = J.record_craft(u, "tailor", 1, 1)
	check(advanced, "U the tier advances")
	check(J.recipe_known(u, silk_bolt), "U ... and unlocks the silk bolt")
	-- /prof's admin_set: every tier up to N.
	local a = new_player("a")
	J.admin_set(a, "tailor", 2, 1)
	check(J.recipe_known(a, bolt) and J.recipe_known(a, silk_bolt), "U admin_set unlocks tiers 1-2")
	-- The join's catch-up: a character already at tier 2 without the store.
	local meta = new_meta()
	meta:set_string("grug_jobs:primary:1", "tailor")
	meta:set_int("grug_jobs:level:tailor", 2)
	local j = new_player("j", {meta = meta})
	check(J.recipe_known(j, bolt) and J.recipe_known(j, silk_bolt), "U the join catches up")
	-- Held once still works; the unlock stays after an unlearn.
	local h = new_player("h")
	put(h, "main", 9, "t:linen 1")
	J.scan_held(h, true)
	check(J.recipe_known(h, thread), "U held once still unlocks")
	J.unlearn(u, "tailor")
	check(J.recipe_known(u, bolt), "U the unlock stays after an unlearn")
	leave(u)
	join(u)
	check(J.recipe_known(u, silk_bolt), "U ... and across a rejoin")
	-- The tailor's list shows the bag; Basic lists the unlocked chain.
	open(j)
	click(j, {[F.area .. "1"] = "Basic"})
	local listed = {}
	for _, id in ipairs(st_of(j).rows) do listed[id] = true end
	check(listed[bolt.id] and listed[thread.id] and listed[silk_bolt.id],
		"U Basic lists the unlocked recipes")
	eq(#bag.ingredients + #robe.ingredients, 4, "U (the recipes' own lists unchanged)")
end

if failures > 0 then
	error(("R57 CRAFT PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 CRAFT PORTABLE PASS checks=%d"):format(checks))
