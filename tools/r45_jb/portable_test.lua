-- Round 45 lane JB portable test (LuaJIT): crafting jobs (round45-plan.md
-- §3, §4.3; ui-crafting-rework-plan.md §2.19-2.22, §2.31, §2.36, §4.4).
--
--   luajit tools/r45_jb/portable_test.lua [REPO]
--
-- Loads the REAL grug_inventory bags.lua (the give helper and the fit check
-- of storage.lua), the REAL grug_jobs registry.lua, state.lua and jobs.lua
-- under a stub engine with a wall clock, the microsecond counter, core.after
-- and player meta. Checks:
--   S  the start checks: busy, unknown recipe, quantity, profession, the
--      station within 4 nodes (once, at the start), output space (none,
--      reduced; partial stacks counted), ingredients (none, reduced);
--   O  the consumption order (bags, main[9..], the hotbar last), the
--      metadata rule for item and group entries, ×N from the same rule,
--      item entries before group entries;
--   C  completion by the online timer: the result in the output area, gear
--      through grug_items.crafted_output (one call per stack), several
--      stacks above stack_max, the feed line, the end hook, the craft sound
--      once, the achievement callback with the job's items; no step work;
--      the start hook (PT8): once per started job, with the nearest station
--      in range (none without a station); a forge job ends without a cue;
--   X  XP = min(crafts, XP left in the tier), only for progress recipes of
--      the current tier; a saturated profession advances at the job's end;
--      unlearning during a job finishes it without XP (also after relearning);
--   R  a server restart in the middle of a job (state survives, the timer is
--      re-armed at login, completes) and a logout with a login after the end
--      (completes at login); catch-up when the Crafting tab is built;
--   K  cancel: refunds everything with room, refused without room (no side
--      effects), a Stop after the end time completes; a target stack (EU) is
--      refunded; a job whose recipe is gone returns its ingredients;
--   A  the output area: created at join for every player, take-only (put,
--      move in and swaps refused, taking out allowed), Take all through the
--      give helper with the leftover kept.
-- Every job checks that no item is lost or duplicated.
-- Prints "R45 JB PORTABLE PASS checks=<n>" or the failures (exit 1).

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

------------------------------------------------------------------------------
-- Clock: real time in seconds; os.time() is its floor; the microsecond
-- counter starts at 0 with each server process.
------------------------------------------------------------------------------
local real, process_start = 1700000000.4, 1700000000.4
os.time = function() return math.floor(real) end
local afters = {}
local function advance(seconds) real = real + seconds end
-- Runs every core.after callback that is due, in order.
local function run_timers()
	local ran = true
	while ran do
		ran = false
		table.sort(afters, function(a, b) return a.at < b.at end)
		for index, entry in ipairs(afters) do
			-- (the engine counter has whole microseconds)
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
local callbacks = {allow = {}, join = {}, leave = {}, loaded = {}, globalstep = 0}
local dropped, feed_lines, chat, sounds = {}, {}, {}, {}
local online = {}
local nodes = {}
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
		return ("%.17g"):format(value) -- as builtin serialize.lua
	end
	return tostring(value)
end
core = {
	registered_items = {},
	registered_nodes = {},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.loaded, f) end,
	register_globalstep = function() callbacks.globalstep = callbacks.globalstep + 1 end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_inventory" end,
	get_current_modname = function() return "grug_inventory" end,
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	log = function() end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
	add_item = function(_, stack) dropped[#dropped + 1] = ItemStack(stack) end,
	handle_node_drops = function() end,
	get_us_time = function() return math.floor((real - process_start) * 1000000) end,
	after = function(delay, fn) afters[#afters + 1] = {at = real + delay, fn = fn} end,
	get_player_by_name = function(name) return online[name] end,
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
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {
	offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end,
	round = function(pos)
		return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
			z = math.floor(pos.z + 0.5)}
	end,
}

-- ItemStack double: name, count, wear and a metadata table; stacks merge
-- only when name, wear and metadata are identical (engine ItemStack::addItem).
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
	-- The engine reads every tool itemstring as one item.
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
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count, self.fields = "", 0, {} end
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken:set_count(n)
	self:set_count(self.count - n)
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

-- InvRef double.
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
local character_level = 5
local crafted_calls = 0
grug_core = {
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind, text = text}
		return true
	end,
	item_name = function(item)
		local name = type(item) == "string" and item or item:get_name()
		local def = core.registered_items[name:match("^%S*")]
		return def and def.description:match("^[^\n]*") or name
	end,
}
grug_classes = {get_class = function(player) return player.class_id end}
grug_gear = {initialize_weapon_tooltip = function() return false end}
grug_inventory = {refresh = function() end, refresh_character_tab = function() end}
grug_xp = {get_level = function() return character_level end}
grug_sounds = {play = function(event, player)
	sounds[#sounds + 1] = event .. "@" .. player:get_player_name()
end}
-- crafted_output: gear only (the real one returns false for anything else).
grug_items = {crafted_output = function(stack)
	local def = stack:get_definition()
	if not def or not def._gear then return false end
	crafted_calls = crafted_calls + 1
	stack:get_meta():set_int("grug_quality", 1)
	stack:get_meta():set_string("grug_base_name", def.description)
	return true
end}

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
item("t:torch", {description = "Torch"})
item("t:chest", {description = "Chest", stack_max = 99})
item("t:bar", {description = "Copper Bar"})
item("t:sword", {description = "Copper Sword", stack_max = 1, _gear = true,
	type = "tool", groups = {grug_equip_weapon = 1}})
item("t:pick", {description = "Old Pick", stack_max = 1, type = "tool"})
item("t:scrap", {description = "Scrap"})
item("t:meat", {description = "Meat"})
item("t:grain", {description = "Wild Grain"})
item("t:stew", {description = "Hearty Stew", stack_max = 20})
item("t:dirt", {description = "Dirt"})
item("t:stone", {description = "Stone"})
item("t:gem", {description = "Gem"})
core.registered_nodes["t:forge"] = {_grug_station = "forge"}
core.registered_nodes["t:bench"] = {_grug_station = "tailor_bench"}

dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
local I = grug_inventory
local BAG = {small = "grug_inventory:bag_small", medium = "grug_inventory:bag_medium"}

grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/state.lua")
local steps_before = callbacks.globalstep
local first_join, first_leave = #callbacks.join + 1, #callbacks.leave + 1
dofile(ROOT .. "/mods/PLAYER/grug_jobs/jobs.lua")
-- The join and leave callbacks jobs.lua registered (a restart replaces them).
local jobs_join, jobs_leave = first_join, first_leave
local J = grug_jobs
eq(callbacks.globalstep, steps_before, "C jobs.lua registers no globalstep")

J.register_ingredient_tier("t:bar", 1)
J.register_ingredient_tier("t:meat", 1)
local torch = J.register_recipe({area = "basic", output = "t:torch", count = 4,
	ingredients = {{item = "t:stick", n = 1}, {item = "t:coal", n = 1}}})
local chest = J.register_recipe({area = "basic", output = "t:chest",
	ingredients = {{group = "wood", n = 8}}})
local mixed = J.register_recipe({area = "basic", output = "t:gem",
	ingredients = {{group = "wood", n = 2}, {item = "t:oak", n = 1}}})
local melt = J.register_recipe({area = "basic", output = "t:scrap",
	ingredients = {{item = "t:pick", n = 2}}})
local sword = J.register_recipe({area = "weaponsmith", tier = 1, station = "forge",
	output = "t:sword", ingredients = {{item = "t:bar", n = 2}, {item = "t:stick", n = 1}},
	time = 3})
local stew = J.register_recipe({area = "cooking", tier = 1, output = "t:stew",
	ingredients = {{item = "t:meat", n = 1}, {item = "t:grain", n = 1}}, time = 1})
for _, fn in ipairs(callbacks.loaded) do fn() end

local awards = {}
J.register_on_award_progress(function(player, recipe, items)
	awards[#awards + 1] = {name = player:get_player_name(), recipe = recipe.id, items = items}
end)
-- Round 45 PT8: the start hook with the station the start found.
local starts = {}
J.register_on_job_start(function(player, job, station_pos)
	starts[#starts + 1] = {name = player:get_player_name(), recipe = job.recipe,
		pos = station_pos}
end)
local ends = {}
J.register_on_job_end(function(player, job, outcome, source)
	ends[#ends + 1] = {name = player:get_player_name(), outcome = outcome, source = source,
		recipe = job.recipe}
end)

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
local function join(player)
	online[player.name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
end
local function leave(player)
	online[player.name] = nil
	for _, f in ipairs(callbacks.leave) do f(player) end
end
local function new_player(name, opts)
	opts = opts or {}
	local inv = new_inventory()
	inv:set_size("main", 32)
	local meta = new_meta()
	local player = {name = name, inv = inv, meta = meta, pos = {x = 0.3, y = 10, z = -0.2}}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return true end
	function player:get_pos() return self.pos end
	if opts.join ~= false then join(player) end
	return player
end
local function equip_bag(player, i, bag)
	player.inv:set_stack(I.bag_list(i), 1, ItemStack(bag))
	player.inv:set_size(I.content_list(i), I.bag_slots_of(ItemStack(bag)))
end
local function put(player, list, index, itemstring)
	player.inv:set_stack(list, index, ItemStack(itemstring))
end
local function stack_at(player, list, index) return player.inv:get_stack(list, index) end
local function count_of(player, name, lists)
	local total = 0
	for list, stacks in pairs(player.inv.lists) do
		if not lists or lists[list] then
			for _, stack in ipairs(stacks) do
				if stack:get_name() == name then total = total + stack:get_count() end
			end
		end
	end
	return total
end
local function fill(player, list, from, to, itemstring)
	for index = from, to do put(player, list, index, itemstring) end
end
local function allow(player, action, info)
	for _, f in ipairs(callbacks.allow) do
		local r = f(player, action, player.inv, info)
		if r ~= nil then return r end
	end
	return nil
end
local function last_feed() return feed_lines[#feed_lines] and feed_lines[#feed_lines].text end
local function job_of(player) return J.job_state(player) end

------------------------------------------------------------------------------
-- A. The output area at join; take-only.
------------------------------------------------------------------------------
do
	local old = new_player("a_old", {join = false})
	eq(old.inv:get_size(OUT), 0, "A an old character has no output list before its join")
	join(old)
	eq(old.inv:get_size(OUT), 4, "A the join creates the 4 output slots")
	put(old, OUT, 2, "t:stone 5")
	join(old)
	eq(stack_at(old, OUT, 2):get_count(), 5, "A a second join keeps the output contents")
	eq(allow(old, "put", {listname = OUT, index = 1, stack = ItemStack("t:dirt")}), 0,
		"A nothing is put into the output area")
	eq(allow(old, "move", {from_list = "main", from_index = 9, to_list = OUT, to_index = 1,
		count = 1}), 0, "A nothing moves into the output area (a swap checks this too)")
	eq(allow(old, "move", {from_list = OUT, from_index = 2, to_list = "main", to_index = 9,
		count = 5}), nil, "A taking out of the output area is allowed")
	eq(allow(old, "take", {listname = OUT, index = 2, stack = ItemStack("t:stone 5")}), nil,
		"A dropping out of the output area is allowed")
end

eq(#afters, 0, "C no timer for players without a job")

------------------------------------------------------------------------------
-- O. Consumption order, the metadata rule, ×N.
------------------------------------------------------------------------------
do
	local p = new_player("o1")
	equip_bag(p, 1, BAG.small)
	put(p, "main", 1, "t:stick 10")          -- hotbar
	put(p, "main", 9, "t:stick 10")          -- main[9..]
	put(p, I.content_list(1), 3, "t:stick 10") -- bag
	put(p, "main", 10, "t:coal 30")
	local tagged = ItemStack("t:stick 50")
	tagged:get_meta():set_string("owner", "x")
	p.inv:set_stack("main", 11, tagged)
	local counts = J.ingredient_counts(p)
	eq(J.ingredient_have(counts, {item = "t:stick", n = 1}), 30,
		"O a stack with metadata does not count")
	eq(J.crafts_from_counts(counts, torch), 30, "O ×N from the same rule")
	local most, by_ingredients, by_space = J.max_craftable(p, torch)
	eq(by_ingredients, 30, "O max_craftable: the ingredient limit")
	eq(by_space, math.floor(4 * 99 / 4), "O max_craftable: the space limit")
	eq(most, 30, "O max_craftable: the smaller")
	local ok = J.start_job(p, torch.id, 15)
	check(ok, "O a 15-torch job starts")
	eq(stack_at(p, I.content_list(1), 3):get_count(), 0, "O the bag's sticks first")
	eq(stack_at(p, "main", 9):get_count(), 5, "O then main[9..]")
	eq(stack_at(p, "main", 1):get_count(), 10, "O the hotbar untouched while others last")
	eq(stack_at(p, "main", 11):get_count(), 50, "O the tagged stack is never consumed")
	eq(stack_at(p, "main", 10):get_count(), 15, "O coal consumed")
	local job = job_of(p)
	eq(#job.consumed, 2, "O the consumed stacks recorded per identity")
	eq(job.consumed[1], "t:stick 15 0", "O the consumed sticks")
	J.cancel_job(p)
	advance(1)

	-- The hotbar last: only when everything else is used up.
	local h = new_player("o2")
	put(h, "main", 2, "t:stick 4")
	put(h, "main", 20, "t:stick 1")
	put(h, "main", 21, "t:coal 5")
	check(J.start_job(h, torch.id, 3), "O a job that needs the hotbar starts")
	eq(stack_at(h, "main", 20):get_count(), 0, "O main[9..] emptied first")
	eq(stack_at(h, "main", 2):get_count(), 2, "O then the hotbar")
	J.cancel_job(h)

	-- Group entries: the same rule; item entries before group entries.
	local g = new_player("o3")
	put(g, "main", 9, "t:oak 3")
	put(g, "main", 10, "t:pine 6")
	local woody = ItemStack("t:pine 20")
	woody.fields = {grug_quality = "2"}
	g.inv:set_stack("main", 11, woody)
	counts = J.ingredient_counts(g)
	eq(J.ingredient_have(counts, {group = "wood", n = 1}), 9, "O a group counts plain stacks only")
	eq(J.crafts_from_counts(counts, chest), 1, "O ×N of a group recipe")
	local refused, reason, info = J.start_job(g, chest.id, 2)
	check(not refused, "O two chests refused")
	eq(info.code, "ingredients", "O the reason code")
	eq(info.max, 1, "O the quantity it would start")
	eq(reason, "Not enough ingredients — quantity reduced to 1", "O the reduction note")
	check(J.start_job(g, chest.id, 1), "O one chest starts")
	eq(count_of(g, "t:pine"), 21, "O the tagged pine stays, 5 plain pine left")
	eq(count_of(g, "t:oak"), 0, "O the group took the oak too")
	J.cancel_job(g)
	eq(count_of(g, "t:oak"), 3, "O cancel returns the oak")
	eq(count_of(g, "t:pine"), 26, "O cancel returns the pine")

	-- Tools as ingredients: one consumed entry per tool, all refunded.
	local t = new_player("o5")
	local worn = ItemStack("t:pick")
	worn.wear = 300
	put(t, "main", 9, "t:pick")
	t.inv:set_stack("main", 10, worn)
	put(t, "main", 11, "t:pick")
	check(J.start_job(t, melt.id, 1), "O a job consuming two tools starts")
	local tools = job_of(t).consumed
	eq(#tools, 2, "O each tool its own consumed entry")
	eq(tools[1] .. "|" .. tools[2], "t:pick 1 0|t:pick 1 300", "O the tools in consume order, wear kept")
	J.cancel_job(t)
	eq(count_of(t, "t:pick"), 3, "O cancel returns both tools")

	-- An item entry is served before a group entry that also accepts it.
	local m = new_player("o4")
	put(m, "main", 9, "t:oak 1")
	put(m, "main", 10, "t:pine 2")
	check(J.start_job(m, mixed.id, 1), "O overlapping entries: the item entry first")
	eq(count_of(m, "t:oak") + count_of(m, "t:pine"), 0, "O all three planks used")
	J.cancel_job(m)
end

------------------------------------------------------------------------------
-- S. Start checks.
------------------------------------------------------------------------------
do
	local p = new_player("s1")
	local ok, reason, info = J.start_job(p, "nope", 1)
	check(not ok and info.code == "recipe", "S an unknown recipe is refused")
	ok, reason, info = J.start_job(p, torch.id, 0)
	check(not ok and info.code == "quantity", "S quantity 0 is refused")
	ok, reason, info = J.start_job(p, torch.id, 1.5)
	check(not ok and info.code == "quantity", "S a fractional quantity is refused")
	ok, reason, info = J.start_job(p, torch.id, 1)
	check(not ok and info.code == "ingredients" and info.max == 0, "S no ingredients")
	eq(reason, "Not enough ingredients", "S the no-ingredients reason")
	put(p, "main", 9, "t:bar 10")
	put(p, "main", 10, "t:stick 10")
	ok, reason, info = J.start_job(p, sword.id, 1)
	check(not ok and info.code == "profession", "S an unlearned profession is refused")
	J.learn(p, "weaponsmith")
	ok, reason, info = J.start_job(p, sword.id, 1)
	check(not ok and info.code == "station", "S no forge nearby")
	eq(reason, "Requires: Forge nearby", "S the station reason")
	nodes[#nodes + 1] = {name = "t:bench", pos = {x = 1, y = 10, z = 0}}
	ok = J.start_job(p, sword.id, 1)
	check(not ok, "S another profession's station does not count")
	nodes[#nodes + 1] = {name = "t:forge", pos = {x = 5, y = 10, z = 0}}
	ok = J.start_job(p, sword.id, 1)
	check(not ok, "S a forge 5 nodes away is out of range")
	nodes[#nodes + 1] = {name = "t:forge", pos = {x = 4, y = 6, z = -4}}
	local starts_before = #starts
	ok = J.start_job(p, sword.id, 1)
	check(ok, "S a forge within 4 nodes (a corner of the box) allows the start")
	-- PT8: the start hook runs once, with the nearest forge in range (the
	-- one 5 nodes away is out of range, a refused start runs no hook).
	eq(#starts - starts_before, 1, "S one start hook for the started job")
	local start = starts[#starts]
	check(start and start.name == "s1" and start.recipe == sword.id and start.pos and
		start.pos.x == 4 and start.pos.y == 6 and start.pos.z == -4,
		"S the start hook gets the forge the job starts at")
	ok, reason, info = J.start_job(p, torch.id, 1)
	check(not ok and info.code == "busy", "S one job per player")
	eq(#starts - starts_before, 1, "S a refused start runs no start hook")
	-- The station counts once, at the start.
	nodes = {}
	advance(3.1)
	run_timers()
	eq(job_of(p), nil, "S the job ends without the forge (checked only at the start)")
	eq(stack_at(p, OUT, 1):get_name(), "t:sword", "S the sword is in the output area")

	-- Output space: none, reduced, partial stacks counted.
	local q = new_player("s2")
	fill(q, OUT, 1, 4, "t:stone 99")
	put(q, "main", 9, "t:meat 99")
	put(q, "main", 10, "t:grain 99")
	J.learn(q, "cooking")
	ok, reason, info = J.start_job(q, stew.id, 1)
	check(not ok and info.code == "space" and info.max == 0, "S a full output area")
	eq(reason, "No space in the output area", "S the no-space reason")
	put(q, OUT, 1, "t:stew 15")
	put(q, OUT, 2, "")
	eq(J.output_capacity(q, stew), 5 + 20, "S room: a partial stack plus an empty slot")
	ok, reason, info = J.start_job(q, stew.id, 30)
	check(not ok and info.code == "space" and info.max == 25, "S output limits the quantity")
	eq(reason, "Not enough space in the output area — quantity reduced to 25",
		"S the space note")
	eq(count_of(q, "t:meat"), 99, "S a refused start consumes nothing")
	local tagged = ItemStack("t:stew 1")
	tagged.fields = {grug_quality = "2"}
	q.inv:set_stack(OUT, 3, tagged)
	put(q, OUT, 2, "t:stew 19")
	eq(J.output_capacity(q, stew), 5 + 1, "S a stack with metadata takes no more")
end

------------------------------------------------------------------------------
-- C. Completion by the online timer; X. XP and achievements.
------------------------------------------------------------------------------
do
	local p = new_player("c1")
	J.learn(p, "cooking")
	put(p, "main", 9, "t:meat 99")
	put(p, "main", 10, "t:grain 99")
	local awards_before, sounds_before = #awards, #sounds
	local ok, _, job = J.start_job(p, stew.id, 10)
	check(ok, "C a 10-stew job starts")
	check(starts[#starts].name == "c1" and starts[#starts].pos == nil,
		"C a job without a station starts with no station position")
	eq(job.finish - job.start, 10, "C the job lasts quantity × time")
	eq(#afters > 0, true, "C the online timer is armed")
	advance(9.9)
	run_timers()
	check(job_of(p) ~= nil, "C still running at 9.9 s")
	check(stack_at(p, OUT, 1):is_empty(), "C nothing in the output area yet")
	advance(0.2)
	run_timers()
	eq(job_of(p), nil, "C the timer completed the job")
	eq(stack_at(p, OUT, 1):get_name() .. " " .. stack_at(p, OUT, 1):get_count(), "t:stew 10",
		"C the stew in the output area")
	eq(last_feed(), "Hearty Stew ×10 is ready", "C the HUD feed line")
	eq(#sounds - sounds_before, 1, "C the craft sound once per job")
	eq(sounds[#sounds], "craft_cooking@c1", "C the cooking cue")
	eq(#awards - awards_before, 1, "C one achievement callback per job")
	eq(awards[#awards].items, 10, "C the callback gets the job's items")
	eq(ends[#ends].outcome .. "/" .. ends[#ends].source, "completed/timer", "C the end hook")
	eq(J.crafts_in_tier(p, "cooking"), 10, "X 10 crafts give 10 XP (threshold 10)")

	-- XP = min(crafts, XP left); a Basic recipe gives none.
	local x = new_player("x1")
	J.learn(x, "cooking")
	put(x, "main", 9, "t:meat 99")
	put(x, "main", 10, "t:grain 99")
	J.start_job(x, stew.id, 4)
	advance(4)
	run_timers()
	eq(J.crafts_in_tier(x, "cooking"), 4, "X 4 crafts, 4 XP")
	J.start_job(x, stew.id, 15)
	advance(15)
	run_timers()
	eq(J.crafts_in_tier(x, "cooking"), 10, "X 15 crafts with 6 XP left give 6 (saturated)")
	eq(J.profession_level(x, "cooking"), 1, "X level 5: no advance yet")
	check(chat[#chat]:find("tier progress is ready", 1, true) ~= nil, "X the ready notice")
	-- A saturated profession advances at the job's end once the level allows.
	character_level = 11
	J.start_job(x, stew.id, 3)
	advance(3)
	run_timers()
	eq(J.profession_level(x, "cooking"), 2, "X a saturated profession advances at the job end")
	eq(J.crafts_in_tier(x, "cooking"), 0, "X the next tier starts at 0")
	eq(stack_at(x, OUT, 1):get_count() + stack_at(x, OUT, 2):get_count(), 22,
		"X the output area holds 4 + 15 + 3 stews")
	-- A T1 recipe at profession T2 gives no XP.
	J.take_all(x)
	J.start_job(x, stew.id, 2)
	advance(2)
	run_timers()
	eq(J.crafts_in_tier(x, "cooking"), 0, "X a lower-tier recipe gives no XP")
	character_level = 5
	local basic_awards = #awards
	put(x, "main", 11, "t:stick 5")
	put(x, "main", 12, "t:coal 5")
	J.start_job(x, torch.id, 2)
	advance(2)
	run_timers()
	eq(#awards, basic_awards, "X a Basic recipe gives no XP and no achievement")

	-- Gear: one stack per item, each through crafted_output; several stacks
	-- above stack_max.
	local smith = new_player("c2")
	J.learn(smith, "weaponsmith")
	-- PT8: two forges in range; the start names the nearer one. The forge
	-- has a station sound (station_sounds.lua's table), so the job's end
	-- plays no craft cue: the forge played it at the start.
	nodes = {{name = "t:forge", pos = {x = 3, y = 10, z = 3}},
		{name = "t:forge", pos = {x = 0, y = 10, z = 2}}}
	J.STATION_SOUNDS = {forge = {event = "craft_smithy", seconds = 1.5}}
	put(smith, "main", 9, "t:bar 10")
	put(smith, "main", 10, "t:stick 10")
	local calls = crafted_calls
	check(J.start_job(smith, sword.id, 3), "C three swords start")
	local start = starts[#starts]
	check(start and start.name == "c2" and start.pos and start.pos.x == 0 and
		start.pos.z == 2, "C the start hook gets the nearest forge")
	local sounds_at_start = #sounds
	advance(9)
	run_timers()
	eq(#sounds, sounds_at_start, "C a forge job's end plays no craft cue (PT8)")
	J.STATION_SOUNDS = nil
	eq(crafted_calls - calls, 3, "C crafted_output once per sword")
	for index = 1, 3 do
		local stack = stack_at(smith, OUT, index)
		check(stack:get_name() == "t:sword" and stack:get_count() == 1 and
			stack:get_meta():get_int("grug_quality") == 1,
			"C sword " .. index .. " in its own slot, made by crafted_output")
	end
	eq(last_feed(), "Copper Sword ×3 is ready", "C the gear feed line")
	nodes = {}

	local big = new_player("c3")
	put(big, "main", 9, "t:stick 99")
	put(big, "main", 10, "t:stick 99")
	put(big, "main", 11, "t:coal 99")
	put(big, OUT, 1, "t:torch 50")
	local most, _, by_space = J.max_craftable(big, torch)
	eq(by_space, math.floor((49 + 3 * 99) / 4), "C room: partial stack + 3 slots, per 4 torches")
	check(J.start_job(big, torch.id, 60), "C 60 crafts = 240 torches start")
	advance(60)
	run_timers()
	eq(stack_at(big, OUT, 1):get_count(), 99, "C the partial stack filled first")
	eq(stack_at(big, OUT, 2):get_count(), 99, "C then a stack of stack_max")
	eq(stack_at(big, OUT, 3):get_count(), 92, "C and the rest (50 + 240 = 290)")
	check(stack_at(big, OUT, 4):is_empty(), "C the fourth slot unused")
	eq(count_of(big, "t:torch"), 290, "C no torch lost or duplicated")
end

------------------------------------------------------------------------------
-- X. Unlearning during a job.
------------------------------------------------------------------------------
do
	local p = new_player("u1")
	J.learn(p, "weaponsmith")
	nodes = {{name = "t:forge", pos = {x = 0, y = 10, z = 0}}}
	put(p, "main", 9, "t:bar 10")
	put(p, "main", 10, "t:stick 10")
	check(J.start_job(p, sword.id, 2), "X a smith job starts")
	J.unlearn(p, "weaponsmith")
	check(job_of(p).no_xp == true, "X unlearning marks the job")
	J.learn(p, "weaponsmith")
	advance(6)
	run_timers()
	eq(job_of(p), nil, "X the job finishes")
	eq(count_of(p, "t:sword", {[OUT] = true}), 2, "X its swords are delivered")
	eq(J.crafts_in_tier(p, "weaponsmith"), 0, "X without XP, also after relearning")
	nodes = {}
end

------------------------------------------------------------------------------
-- R. Restart, logout and login, catch-up on opening the tab.
------------------------------------------------------------------------------
do
	local p = new_player("r1")
	J.learn(p, "cooking")
	put(p, "main", 9, "t:meat 50")
	put(p, "main", 10, "t:grain 50")
	check(J.start_job(p, stew.id, 20), "R a 20 s job starts")
	advance(5)
	run_timers()
	-- The restart.
	leave(p)
	afters = {}
	process_start = real + 3
	real = process_start
	-- jobs.lua's callbacks of the old process go; the new load adds its own.
	table.remove(callbacks.join, jobs_join)
	table.remove(callbacks.leave, jobs_leave)
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/jobs.lua")
	J.register_on_job_end(function(player, job, outcome, source)
		ends[#ends + 1] = {name = player:get_player_name(), outcome = outcome,
			source = source, recipe = job.recipe}
	end)
	check(job_of(p) ~= nil, "R the job survives the restart (player meta)")
	join(p)
	check(job_of(p) ~= nil, "R 8 s in: still running after the login")
	check(#afters == 1, "R the login re-arms the online timer")
	-- The restarted clock agrees with the old one within a second.
	advance(11)
	run_timers()
	check(job_of(p) ~= nil, "R 19 s in: still running")
	advance(2)
	run_timers()
	eq(job_of(p), nil, "R the job completes after the restart")
	eq(stack_at(p, OUT, 1):get_count(), 20, "R the 20 stews in the output area")
	eq(ends[#ends].source, "timer", "R completed by the re-armed timer")

	-- Logout, login after the end: completes at login.
	check(J.start_job(p, stew.id, 5), "R a 5 s job starts")
	leave(p)
	advance(30)
	run_timers()
	check(job_of(p) ~= nil, "R nothing runs for an offline player")
	join(p)
	eq(job_of(p), nil, "R the login completes a finished job")
	eq(ends[#ends].source, "join", "R completed at the join")
	eq(stack_at(p, OUT, 2):get_count(), 5, "R the stews delivered at login")
	eq(last_feed(), "Hearty Stew ×5 is ready", "R the feed line at login")

	-- Opening the Crafting tab catches up (the timer may come a step later).
	check(J.start_job(p, stew.id, 2), "R a 2 s job starts")
	advance(2.5)
	check(J.update_job(p, "open"), "R update_job completes a due job")
	eq(ends[#ends].source, "open", "R completed while the tab was built")
	run_timers()
	eq(stack_at(p, OUT, 2):get_count(), 7, "R the stale timer delivers nothing twice")
	check(not J.update_job(p, "open"), "R update_job without a job does nothing")
end

------------------------------------------------------------------------------
-- K. Cancel and refund.
------------------------------------------------------------------------------
do
	local p = new_player("k1")
	equip_bag(p, 1, BAG.small)
	put(p, I.content_list(1), 1, "t:stick 7")
	put(p, "main", 9, "t:stick 30")
	put(p, "main", 10, "t:coal 40")
	check(J.start_job(p, torch.id, 35), "K a 35-craft job starts")
	advance(10)
	local ok, outcome = J.cancel_job(p)
	check(ok and outcome == "cancelled", "K cancel with room")
	eq(job_of(p), nil, "K the job is gone")
	eq(count_of(p, "t:stick"), 37, "K every stick back")
	eq(count_of(p, "t:coal"), 40, "K every coal back")
	eq(count_of(p, "t:torch"), 0, "K nothing produced")
	eq(ends[#ends].outcome, "cancelled", "K the end hook on cancel")
	run_timers()
	eq(count_of(p, "t:torch"), 0, "K the cancelled job's timer does nothing")

	-- Without room: refused, nothing changes.
	local n = new_player("k2")
	fill(n, "main", 9, 11, "t:oak 99")
	put(n, "main", 12, "t:oak 3")
	check(J.start_job(n, chest.id, 25), "K a 25-chest job (200 planks) starts")
	fill(n, "main", 1, 32, "t:dirt 99")
	local before = {}
	for list, stacks in pairs(n.inv.lists) do
		for index, stack in ipairs(stacks) do before[list .. index] = stack:to_string() end
	end
	local job_before = n.meta:get_string(J.JOB_KEY)
	ok, outcome = J.cancel_job(n)
	check(not ok, "K cancel without room is refused")
	eq(outcome, "Not enough inventory space to cancel", "K the refusal text")
	local same = true
	for list, stacks in pairs(n.inv.lists) do
		for index, stack in ipairs(stacks) do
			if before[list .. index] ~= stack:to_string() then same = false end
		end
	end
	check(same, "K the refused cancel changed no slot")
	eq(n.meta:get_string(J.JOB_KEY), job_before, "K the refused cancel kept the job")
	-- Room for all but one stack: still refused (one dry run for everything).
	for index = 9, 10 do put(n, "main", index, "") end
	ok = J.cancel_job(n)
	check(not ok, "K two free slots for three refund stacks (99, 99, 2): refused")
	put(n, "main", 11, "")
	ok = J.cancel_job(n)
	check(ok, "K three free slots: the refund fits")
	eq(count_of(n, "t:oak"), 200, "K the planks back, split by stack_max")
	check(stack_at(n, "main", 9):get_count() == 99 and stack_at(n, "main", 11):get_count() == 2,
		"K the refund stacks are at most stack_max")

	-- Stop after the end time completes instead.
	local s = new_player("k3")
	put(s, "main", 9, "t:stick 5")
	put(s, "main", 10, "t:coal 5")
	check(J.start_job(s, torch.id, 2), "K a 2 s job starts")
	advance(2.01)
	ok, outcome = J.cancel_job(s)
	check(ok and outcome == "completed", "K a Stop after the end completes")
	eq(count_of(s, "t:torch", {[OUT] = true}), 8, "K the torches delivered, no refund")
	eq(count_of(s, "t:stick"), 3, "K the sticks stay consumed")
	ok, outcome = J.cancel_job(s)
	check(not ok, "K cancel without a job")

	-- A target stack (EU's enchant and upgrade jobs) is refunded too.
	local e = new_player("k4")
	local target = ItemStack("t:sword")
	target.fields = {grug_quality = "3"}
	local copy = J.begin_job(e, {kind = "test", consumed = {"t:gem 2 0"},
		target = target:to_string(), duration = 5})
	eq(copy.finish - copy.start, 5, "K begin_job sets the times")
	local stored = e.meta:get_string(J.JOB_KEY)
	local again, why = J.begin_job(e, {kind = "test", consumed = {"t:oak 1 0"}, duration = 1})
	check(again == nil and why == "A crafting job is already running.",
		"K begin_job refuses while a job runs")
	eq(e.meta:get_string(J.JOB_KEY), stored, "K the refused begin_job kept the stored job")
	ok = J.cancel_job(e)
	check(ok, "K the target job cancels")
	eq(count_of(e, "t:gem"), 2, "K the materials back")
	local found
	for _, stack in ipairs(e.inv.lists.main) do
		if stack:get_name() == "t:sword" then found = stack end
	end
	check(found and found:get_meta():get_string("grug_quality") == "3",
		"K the target back with its metadata")

	-- A job whose recipe is gone returns its ingredients at its end.
	local gone = new_player("k5")
	J.begin_job(gone, {kind = "recipe", recipe = "removed|x", quantity = 1,
		consumed = {"t:oak 3 0"}, duration = 1})
	advance(1)
	run_timers()
	eq(count_of(gone, "t:oak", {[OUT] = true}), 3, "K a removed recipe returns its ingredients")

	-- A job of an unknown kind (an EU job read by a build without EU) falls
	-- back to the recipe kind: its ingredients and its target come back.
	local lost = new_player("k6")
	local axe = ItemStack("t:sword")
	axe.fields = {grug_quality = "4"}
	J.begin_job(lost, {kind = "unknown_kind", consumed = {"t:gem 3 0"},
		target = axe:to_string(), duration = 1})
	advance(1)
	run_timers()
	eq(job_of(lost), nil, "K the unknown-kind job ends")
	eq(count_of(lost, "t:gem", {[OUT] = true}), 3, "K its ingredients come back")
	local back
	for _, stack in ipairs(lost.inv.lists[OUT]) do
		if stack:get_name() == "t:sword" then back = stack end
	end
	check(back and back:get_meta():get_string("grug_quality") == "4",
		"K its target comes back with its metadata")

	-- A hook inside the job's finish that rebuilds the Crafting page
	-- (update_job "open") cannot complete the job a second time.
	local nested = new_player("k7")
	J.learn(nested, "cooking")
	put(nested, "main", 9, "t:meat 20")
	put(nested, "main", 10, "t:grain 20")
	local inner
	J.register_on_award_progress(function(player)
		if player:get_player_name() == "k7" then inner = J.update_job(player, "open") end
	end)
	local ends_before = #ends
	check(J.start_job(nested, stew.id, 3), "K a 3-stew job starts")
	advance(3)
	run_timers()
	eq(inner, false, "K the nested update_job finds no job")
	eq(count_of(nested, "t:stew", {[OUT] = true}), 3, "K one delivery: 3 stews, not 6")
	eq(J.crafts_in_tier(nested, "cooking"), 3, "K one award: 3 XP")
	eq(#ends - ends_before, 1, "K one end hook")
end

------------------------------------------------------------------------------
-- A. Take all.
------------------------------------------------------------------------------
do
	local p = new_player("t1")
	equip_bag(p, 1, BAG.small)
	put(p, OUT, 1, "t:stew 20")
	put(p, OUT, 3, "t:stone 50")
	fill(p, "main", 9, 32, "t:dirt 99")
	put(p, "main", 30, "t:stone 60")
	local moved, left = J.take_all(p)
	check(moved and not left, "A Take all moves everything")
	eq(count_of(p, "t:stew", {[I.content_list(1)] = true}), 20, "A the stew spills into the bag")
	eq(stack_at(p, "main", 30):get_count(), 99, "A partial stacks fill first")
	eq(count_of(p, "t:stone"), 110, "A no stone lost")
	check(p.inv:is_empty(OUT), "A the output area is empty")
	-- Leftovers stay.
	fill(p, I.content_list(1), 1, 8, "t:dirt 99")
	fill(p, "main", 1, 8, "t:dirt 99")
	put(p, "main", 30, "t:stone 99")
	put(p, OUT, 2, "t:stone 120")
	moved, left = J.take_all(p)
	check(not moved and left, "A a full inventory moves nothing")
	eq(stack_at(p, OUT, 2):get_count(), 120, "A the leftover stays")
	put(p, "main", 31, "t:stone 90")
	moved, left = J.take_all(p)
	check(moved and left, "A a partial move keeps the rest")
	eq(stack_at(p, OUT, 2):get_count(), 111, "A 9 moved, 111 stay")
end

if failures > 0 then
	error(("R45 JB PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R45 JB PORTABLE PASS checks=%d"):format(checks))
