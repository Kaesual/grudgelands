-- Round 48 lane BAGS portable test (LuaJIT): the bags at half size, the sort
-- into target sizes and the online part of the migration step 0.48.0
-- (round48-plan.md §4.6, sell-fuel-daytime-plan.md §3.7). Loads the REAL
-- grug_inventory bags.lua (which loads storage.lua) and
-- grug_core/migrations.lua under a minimal engine stub (r44_ih's ItemStack
-- and InvRef doubles: stacks merge only when name, wear and metadata are
-- identical; set_size truncates) and a grug_mail stand-in for
-- grug_mail.send_system(to, kind, from, subject, body, stacks) (round plan
-- §3.2) that keeps the letters and can be made to fail:
--   A. the eight bags: 4 / 8 / 12 / 16 slots, cloth and leather alike, and
--      their descriptions;
--   B. the sort without sizes (the Sort button): order, merge, nothing left
--      over, a sorted inventory unchanged;
--   C. the sort into target sizes: the order kept, identical stacks merged,
--      leftovers from the end of the order in the cells beyond the targets
--      and returned, soulbound and bound items never left over (both keep a
--      target cell), the hotbar untouched, nothing lost or duplicated;
--   D. the handler: four full 32-slot bags and a full main[9..] -> main
--      and 4 x 16 bag cells filled, 64 stacks in 16 letters of four, kind
--      "npc" from "Lost and Found", the lists shrunk, one feed line after
--      the join; a second run sends nothing and writes nothing;
--   E. a failing send: the handler raises, the unsent stacks stay beyond
--      the new sizes, the bags' join callback keeps them, a rerun sends only
--      the rest; nothing lost or duplicated;
--   F. a character without bags: nothing written, no letter; one with bags
--      that fit: sorted, no letter.
--
--   luajit tools/r48_bags/portable_test.lua [REPO]
-- Prints "R48 BAGS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
-- Engine surface (as tools/r44_ih/portable_test.lua).
------------------------------------------------------------------------------
local callbacks = {join = {}}
local feed_lines, afters, writes = {}, {}, 0
local online = {}
core = {
	registered_items = {},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_inventory" end,
	get_current_modname = function() return "grug_inventory" end,
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	log = function() end,
	add_item = function() error("nothing may be dropped") end,
	after = function(_, fn) afters[#afters + 1] = fn end,
	get_player_by_name = function(name) return online[name] end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})

local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
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
	-- "name count wear k=v;k=v" (this stub's to_string) or "name count".
	local name, count, wear, meta = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)%s*(.*)$")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
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
	function inv:set_stack(list, i, stack)
		writes = writes + 1
		self.lists[list][i] = ItemStack(stack)
	end
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
	return inv
end

------------------------------------------------------------------------------
-- Mod surface.
------------------------------------------------------------------------------
grug_core = {
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind,
			text = text, key = key}
		return true
	end,
}
grug_classes = {get_class = function() return "warrior" end}
grug_gear = {initialize_weapon_tooltip = function() return false end}
grug_inventory = {refresh = function() end}

-- grug_mail.send_system stand-in: `fail_at` makes the n-th call fail.
local letters, mail_calls, fail_at = {}, 0, nil
grug_mail = {
	send_system = function(to, kind, from, subject, body, stacks)
		mail_calls = mail_calls + 1
		if fail_at and mail_calls == fail_at then return false, "mailbox stand-in refused" end
		assert(type(stacks) == "table" and #stacks >= 1 and #stacks <= 4, "1-4 stacks")
		local copy = {}
		for index, item in ipairs(stacks) do copy[index] = item end
		letters[#letters + 1] = {to = to, kind = kind, from = from, subject = subject,
			body = body, stacks = copy}
		return true
	end,
}

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("t:apple", {description = "Apple", groups = {grug_food = 1, grug_food_tier = 1}})
item("t:dirt", {description = "Dirt"})
item("t:stone", {description = "Stone"})
item("t:claim", {description = "Warded Claim Stone", stack_max = 1, groups = {grug_soulbound = 1}})
item("t:skill", {description = "Skill", stack_max = 1, groups = {grug_bound_skill = 1}})
item("t:sword_t1", {description = "Bronze Sword", stack_max = 1, _grug_bracket = 1,
	groups = {grug_equip_weapon = 1}})
item("t:sword_t3", {description = "Steel Sword", stack_max = 1, _grug_bracket = 3,
	groups = {grug_equip_weapon = 1}})
item("t:pick", {description = "Pick", stack_max = 1, groups = {pickaxe = 1}})
-- Distinct rest items, so nothing merges in the full-bag case: z:junk_NNN.
for index = 1, 200 do
	item(("z:junk_%03d"):format(index), {description = ("Junk %03d"):format(index)})
end

dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(ROOT .. "/mods/CORE/grug_core/migrations.lua")
local I = grug_inventory

local function new_player(name)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local player = {inv = inv}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	for _, f in ipairs(callbacks.join) do f(player) end
	online[name] = player
	return player
end
-- A bag as a 0.47.0 world stored it: the bag item and a content list of the
-- old size (bags.lua's join callback has not run under the new sizes yet).
local function old_bag(player, i, bag, old_size)
	player.inv:set_stack(I.bag_list(i), 1, ItemStack(bag))
	player.inv:set_size(I.content_list(i), old_size)
end

-- Every item counted over the player's lists and the letters (to_string
-- without the count as the identity).
local function census(player, extra_letters)
	local total = {}
	local function add(stack)
		stack = ItemStack(stack)
		if stack:is_empty() then return end
		local one = ItemStack(stack)
		one.count = 1
		local key = one:to_string()
		total[key] = (total[key] or 0) + stack:get_count()
	end
	for _, list in pairs(player.inv.lists) do
		for _, stack in ipairs(list) do add(stack) end
	end
	for _, letter in ipairs(extra_letters or {}) do
		for _, s in ipairs(letter.stacks) do add(s) end
	end
	return total
end
local function same_census(a, b, label)
	local ok = true
	for key, count in pairs(a) do
		if b[key] ~= count then ok = false; print("  " .. key .. " " .. count .. " -> " .. tostring(b[key])) end
	end
	for key, count in pairs(b) do
		if a[key] == nil then ok = false; print("  new " .. key .. " " .. count) end
	end
	return check(ok, label .. ": nothing lost or duplicated")
end
local function name_at(player, list, i) return player.inv:get_stack(list, i):get_name() end

local handler = grug_core.migrations.handlers["0.48.0"]

------------------------------------------------------------------------------
-- A. The eight bags.
------------------------------------------------------------------------------
do
	local sizes = {bag_small = 4, bag_leather_pouch = 4, bag_medium = 8, bag_leather_satchel = 8,
		bag_large = 12, bag_leather_pack = 12, bag_great = 16, bag_leather_rucksack = 16}
	local names = {bag_small = "Small Bag", bag_medium = "Medium Bag", bag_large = "Large Bag",
		bag_great = "Great Cloth Bag", bag_leather_pouch = "Leather Pouch",
		bag_leather_satchel = "Leather Satchel", bag_leather_pack = "Leather Pack",
		bag_leather_rucksack = "Leather Rucksack"}
	local count = 0
	for name, def in pairs(core.registered_items) do
		if (def.groups.bagslots or 0) > 0 then count = count + 1 end
		local id = name:match("^grug_inventory:(.+)$")
		if id and sizes[id] then
			eq(def.groups.bagslots, sizes[id], "A " .. id .. " slots")
			eq(def.description, names[id] .. " (" .. sizes[id] .. " slots)", "A " .. id .. " description")
		end
	end
	eq(count, 8, "A eight bags")
end

------------------------------------------------------------------------------
-- B. The sort without sizes (the Sort button).
------------------------------------------------------------------------------
do
	local p = new_player("button")
	old_bag(p, 1, "grug_inventory:bag_small", 4)
	p.inv:set_stack("main", 1, ItemStack("t:pick"))
	p.inv:set_stack("main", 9, ItemStack("t:dirt 40"))
	p.inv:set_stack("main", 12, ItemStack("t:apple 5"))
	p.inv:set_stack(I.content_list(1), 2, ItemStack("t:sword_t1"))
	p.inv:set_stack(I.content_list(1), 4, ItemStack("t:dirt 70"))
	local before = census(p)
	local changed, left = I.sort(p)
	check(changed, "B the Sort button sorts")
	eq(#left, 0, "B nothing left over")
	eq(name_at(p, "main", 9), "t:sword_t1", "B weapons first")
	eq(name_at(p, "main", 10), "t:apple", "B consumables next")
	eq(p.inv:get_stack("main", 11):to_string(), "t:dirt 99 0", "B dirt merged to a full stack")
	eq(p.inv:get_stack("main", 12):to_string(), "t:dirt 11 0", "B the merge's rest")
	eq(name_at(p, "main", 1), "t:pick", "B hotbar untouched")
	eq(p.inv:get_size(I.content_list(1)), 4, "B the bag keeps its size")
	same_census(before, census(p), "B")
	check(not I.sort(p), "B a sorted inventory does not change")
end

------------------------------------------------------------------------------
-- C. The sort into target sizes.
------------------------------------------------------------------------------
do
	-- main[9..] (24) full of junk except one Claim Stone; one 8-slot bag (old
	-- Small Bag) full: a stray skill, a sword, apples and junk. Target 4.
	local p = new_player("sorter")
	old_bag(p, 1, "grug_inventory:bag_small", 8)
	local bag = I.content_list(1)
	p.inv:set_stack("main", 3, ItemStack("t:stone 7"))
	for index = 9, 32 do
		p.inv:set_stack("main", index, ItemStack(("z:junk_%03d"):format(index)))
	end
	p.inv:set_stack("main", 20, ItemStack("t:claim"))
	p.inv:set_stack(bag, 1, ItemStack("t:apple 50"))
	p.inv:set_stack(bag, 2, ItemStack("t:skill"))
	p.inv:set_stack(bag, 3, ItemStack("z:junk_150"))
	p.inv:set_stack(bag, 4, ItemStack("t:apple 60"))
	p.inv:set_stack(bag, 5, ItemStack("t:sword_t3"))
	p.inv:set_stack(bag, 6, ItemStack("z:junk_151"))
	p.inv:set_stack(bag, 7, ItemStack("z:junk_152"))
	p.inv:set_stack(bag, 8, ItemStack("t:sword_t1"))
	local before = census(p)
	-- 33 stacks; the apples merge to 99 + 11: 32 stacks for 28 target cells. The
	-- Claim Stone and the skill sort last ("warded" after "skill" after "junk")
	-- but keep their cells: junk_032 and junk_150..152 are left over.
	local _, left = I.sort(p, {[bag] = 4})
	eq(#left, 4, "C four stacks left over")
	local ok = true
	for index, cell in ipairs(left) do
		ok = ok and cell.list == bag and cell.index == 4 + index and
			name_at(p, bag, 4 + index) == cell.stack:get_name()
	end
	check(ok, "C the leftovers sit beyond the target size, in order, as returned")
	eq(left[1].stack:get_name(), "z:junk_032", "C leftovers are the end of the order (1)")
	eq(left[4].stack:get_name(), "z:junk_152", "C leftovers are the end of the order (4)")
	eq(name_at(p, "main", 9), "t:sword_t3", "C the higher-tier weapon first")
	eq(name_at(p, "main", 10), "t:sword_t1", "C then the lower one")
	eq(p.inv:get_stack("main", 11):to_string(), "t:apple 99 0", "C apples merged")
	eq(p.inv:get_stack("main", 12):to_string(), "t:apple 11 0", "C the merge's rest")
	local claim_at, skill_at
	for _, list in ipairs({"main", bag}) do
		for index = 1, p.inv:get_size(list) do
			local name = name_at(p, list, index)
			if name == "t:claim" then claim_at = list .. index end
			if name == "t:skill" then skill_at = {list, index} end
		end
	end
	-- Round 49 ruling 3: the stone may lie in a bag, so it keeps any target
	-- cell (the last one, by its name), no longer main's last.
	eq(claim_at, bag .. "4", "C the Claim Stone keeps a target cell")
	check(skill_at and (skill_at[1] == "main" or skill_at[2] <= 4),
		"C the bound skill keeps a target cell")
	for _, cell in ipairs(left) do
		check(cell.stack:get_name() ~= "t:claim" and cell.stack:get_name() ~= "t:skill",
			"C no guarded stack left over")
	end
	eq(p.inv:get_stack("main", 3):to_string(), "t:stone 7 0", "C hotbar untouched")
	same_census(before, census(p), "C")
end

------------------------------------------------------------------------------
-- D. The handler: four full 32-slot bags.
------------------------------------------------------------------------------
local function full_character(name)
	local p = new_player(name)
	local n = 0
	local function next_junk()
		n = n + 1
		return ItemStack(("z:junk_%03d"):format(n))
	end
	p.inv:set_stack("main", 1, ItemStack("t:pick"))
	p.inv:set_stack("main", 5, ItemStack("t:apple 3"))
	for index = 9, 32 do p.inv:set_stack("main", index, next_junk()) end
	for i = 1, 4 do
		old_bag(p, i, i % 2 == 0 and "grug_inventory:bag_leather_rucksack" or
			"grug_inventory:bag_great", 32)
		for index = 1, 32 do p.inv:set_stack(I.content_list(i), index, next_junk()) end
	end
	p.inv:set_stack("main", 9, ItemStack("t:claim"))
	return p
end

do
	letters, mail_calls, fail_at, feed_lines, afters = {}, 0, nil, {}, {}
	local p = full_character("hoarder")
	local before = census(p)
	handler.character(p, "1")
	eq(#letters, 16, "D sixteen letters")
	local four, meta_ok = true, true
	for _, letter in ipairs(letters) do
		four = four and #letter.stacks == 4
		meta_ok = meta_ok and letter.to == "hoarder" and letter.kind == "npc" and
			letter.from == "Lost and Found" and letter.subject == "Your bags got smaller" and
			letter.body:find("half as much", 1, true) ~= nil
	end
	check(four, "D four stacks per letter")
	check(meta_ok, "D kind npc, from Lost and Found, the subject and body")
	for i = 1, 4 do
		eq(p.inv:get_size(I.content_list(i)), 16, "D bag " .. i .. " shrunk to 16")
		check(not p.inv:get_stack(I.content_list(i), 16):is_empty(), "D bag " .. i .. " full")
	end
	local main_full = true
	for index = 9, 32 do main_full = main_full and not p.inv:get_stack("main", index):is_empty() end
	check(main_full, "D main[9..] full")
	eq(p.inv:get_stack("main", 1):to_string(), "t:pick 1 0", "D hotbar slot 1 untouched")
	eq(p.inv:get_stack("main", 5):to_string(), "t:apple 3 0", "D hotbar slot 5 untouched")
	same_census(before, census(p, letters), "D")
	eq(#afters, 1, "D one feed line queued for after the join")
	for _, fn in ipairs(afters) do fn() end
	check(#feed_lines == 1 and feed_lines[1].text:find("16 letters", 1, true) ~= nil,
		"D the feed line names the 16 letters")
	-- The bags' join callback afterwards keeps the new sizes.
	for _, f in ipairs(callbacks.join) do f(p) end
	eq(p.inv:get_size(I.content_list(1)), 16, "D the join keeps 16")
	-- A second run changes nothing.
	writes, afters = 0, {}
	handler.character(p, "1")
	eq(#letters, 16, "D a second run sends nothing")
	eq(writes, 0, "D a second run writes nothing")
	eq(#afters, 0, "D a second run queues no feed line")
end

------------------------------------------------------------------------------
-- E. A failing send.
------------------------------------------------------------------------------
do
	letters, mail_calls, fail_at, feed_lines, afters = {}, 0, 3, {}, {}
	local p = full_character("unlucky")
	local before = census(p)
	local ok = pcall(handler.character, p, "1")
	check(not ok, "E the handler raises when a send fails")
	eq(#letters, 2, "E two letters went out")
	same_census(before, census(p, letters), "E after the failure")
	eq(p.inv:get_size(I.content_list(4)), 32, "E the lists are not shrunk yet")
	-- The rest of the join (the runner holds the character but the other
	-- join callbacks still run): the bags' callback keeps the unsent stacks.
	for _, f in ipairs(callbacks.join) do f(p) end
	same_census(before, census(p, letters), "E after the bags' join callback")
	check(p.inv:get_size(I.content_list(4)) > 16, "E the bag with unsent stacks is kept")
	-- The next join runs the handler again.
	fail_at = nil
	handler.character(p, "1")
	eq(#letters, 16, "E the rerun sends the other fourteen")
	same_census(before, census(p, letters), "E after the rerun")
	for i = 1, 4 do
		eq(p.inv:get_size(I.content_list(i)), 16, "E bag " .. i .. " shrunk to 16")
	end
end

------------------------------------------------------------------------------
-- F. Without bags; with bags that fit.
------------------------------------------------------------------------------
do
	letters, mail_calls, fail_at, afters = {}, 0, nil, {}
	local p = new_player("bagless")
	p.inv:set_stack("main", 20, ItemStack("t:dirt 5"))
	p.inv:set_stack("main", 9, ItemStack("z:junk_001"))
	writes = 0
	handler.character(p, "1")
	eq(writes, 0, "F without bags nothing is written")
	eq(#letters + #afters, 0, "F without bags no letter, no feed line")

	local q = new_player("tidy")
	old_bag(q, 2, "grug_inventory:bag_medium", 16)
	q.inv:set_stack(I.content_list(2), 14, ItemStack("t:dirt 5"))
	local before = census(q)
	handler.character(q, "1")
	eq(#letters + #afters, 0, "F bags that fit: no letter, no feed line")
	eq(q.inv:get_size(I.content_list(2)), 8, "F the Medium Bag's list is 8 now")
	eq(name_at(q, "main", 9), "t:dirt", "F sorted once")
	same_census(before, census(q), "F")
end

if failures > 0 then
	error("R48 BAGS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R48 BAGS PORTABLE PASS checks=" .. checks)
