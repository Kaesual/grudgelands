-- Round 81 lane UI portable test (LuaJIT; round81-plan.md §4 UI, audit
-- P3-03, P2-04, P3-02, P2-01, P5-02, P1-01).
--
--   luajit tools/r81_ui/portable_test.lua [REPO]
--
-- Every section loads the REAL file(s) under a small stub engine and
-- prints its counts, so one run on the base tree and one on the branch give
-- the before/after numbers (the fixture file itself is the branch's; the
-- checks that only hold for the new code run when its seam exists).
--   G  grug_inventory.give (storage.lua, through bags.lua) over a fixed case
--      table: random inventories (main, 0-4 bags, the belt, a Scout's
--      quiver), stacks with and without metadata, wear, counts beyond
--      stack_max, through give, the pickup callback and the dug-drop
--      override. The digest of every outcome (leftover, every list, what
--      dropped) must be the same on the base and the branch; the stacks the
--      inventory copies per give are counted for a miner's dig.
--   U  grug_jobs/basic_unlock.lua: a miner digging a held stone is not
--      scanned per node (get_lists per dig counted), a new token is scanned
--      within 0.5 s, the held set's string is read once per session.
--   Q  the quiver total on the Character page (bags.lua): a Scout's shots,
--      refunds and pickups re-send the page about once a second, the first
--      change at once, the player's own action at once, the last change
--      always shown.
--   K  grug_achievements/init.lua: one Achievements re-send per kill, none
--      for a counter the shown rows do not count; the rows record their
--      counters.
--   M  grug_mail/store.lua: a Letters-row click's five box reads decode
--      the stored string once per change; every read is a fresh table.
--   I  grug_repair/runtime.lua: a captured shot wears the captured bow, read
--      slot by slot (the weapon slot first) instead of list by list.
--   V  grug_visuals/compose.lua: the compose cache keeps two generations of
--      2048 entries; a hit in the old one is the same table, a dropped entry
--      composes again equal.
--   luajit tools/r81_ui/portable_test.lua BASE_TREE base   (the base's numbers)
-- Prints "R81 UI PORTABLE PASS checks=<n>" or raises with the failures.

local ROOT = arg and arg[1] or "."
-- `base` as the second argument: the run on the base tree, for its numbers
-- (the checks of the new behaviour are skipped).
local BRANCH = not (arg and arg[2] == "base")
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

-- A 32-bit digest of a string (no bit operators: plain 5.1).
local function digest(text)
	local h = 5381
	for index = 1, #text do h = (h * 33 + text:byte(index)) % 4294967296 end
	return ("%08x"):format(h)
end

-- A deterministic generator (LCG).
local seed = 12345
local function rand(low, high)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return low + math.floor(seed / 65536) % (high - low + 1)
end

-- core.after on a fake clock.
local clock, timers = 0, {}
local function after(delay, fn) timers[#timers + 1] = {at = clock + delay, fn = fn} end
local function advance(seconds)
	local target = clock + seconds
	while true do
		local first, index = nil, nil
		for i, timer in ipairs(timers) do
			if timer.at <= target and (not first or timer.at < first.at) then first, index = timer, i end
		end
		if not first then break end
		table.remove(timers, index)
		clock = math.max(clock, first.at)
		first.fn()
	end
	clock = target
end

------------------------------------------------------------------------------
-- ItemStack and InvRef doubles (engine ItemStack::addItem: stacks merge only
-- when name, wear and metadata are identical; get_list/get_stack copy).
------------------------------------------------------------------------------
local registered = {}
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
	local name, count, wear = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	self.wear = tonumber(wear) or 0
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_definition() return registered[self.name] end
function Stack:get_stack_max()
	local def = registered[self.name]
	return def and def.stack_max or 99
end
function Stack:get_meta() return setmetatable({fields = self.fields}, Meta) end
function Stack:set_wear(wear) self.wear = wear end
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
	if self.name ~= other.name or self.wear ~= other.wear or
			meta_string(self.fields) ~= meta_string(other.fields) then
		return other
	end
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

local copies, writes = 0, 0
local function new_inventory()
	local inv = {lists = {}, reads = 0}
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i)
		copies = copies + 1
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
		copies = copies + #l
		return out
	end
	function inv:get_lists()
		self.reads = self.reads + 1
		local out = {}
		for name in pairs(self.lists) do out[name] = self:get_list(name) end
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

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	registered[name] = def
end
item("grug_gear:arrow", {description = "Arrow", stack_max = 100, groups = {grug_arrow = 1}})
item("t:dirt", {description = "Dirt"})
item("t:stone", {description = "Stone", groups = {stone = 1}})
item("t:apple", {description = "Apple", groups = {grug_food = 1}})
item("t:clay", {description = "Clay Lump"})
item("t:potion", {description = "Potion", stack_max = 20, groups = {grug_potion = 1}})
item("t:pick", {description = "Pick", stack_max = 1})
item("t:sword", {description = "Sword", stack_max = 1, groups = {grug_equip_weapon = 1}})

------------------------------------------------------------------------------
-- G. The give helper's outcomes (P3-03).
------------------------------------------------------------------------------
local feet = {}
local refreshes = {}
local online = {}
local give_seam = {}
local callbacks = {pickup = {}, join = {}, leave = {}, allow = {}, action = {}, loaded = {}}
core = setmetatable({
	registered_items = registered,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_item_pickup = function(f) table.insert(callbacks.pickup, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.loaded, f) end,
	register_craftitem = function(name, def) item(name, def) end,
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_inventory" end,
	get_current_modname = function() return "grug_inventory" end,
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	get_player_by_name = function(name) return online[name] end,
	after = after,
	log = function() end,
	add_item = function(_, stack) feet[#feet + 1] = ItemStack(stack):to_string() end,
	handle_node_drops = function() end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end}
grug_core = {feed = function() return true end}
grug_classes = {get_class = function(player) return player.class_id end}
grug_gear = {initialize_weapon_tooltip = function() return false end}
local character_page = {}
grug_inventory = {
	refresh = function() end,
	refresh_character = function(player)
		if not character_page[player:get_player_name()] then return false end
		refreshes[#refreshes + 1] = {name = player:get_player_name(), at = clock}
		return true
	end,
}
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
local I = grug_inventory
if BRANCH then check(I.register_on_give ~= nil, "G the give seam exists") end
if I.register_on_give then
	I.register_on_give(function(player, name) give_seam[#give_seam + 1] = name end)
end

local function new_player(name, class_id)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local player = {inv = inv, class_id = class_id}
	function player:get_player_name() return name end
	function player:get_inventory() return self.inv end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	for _, f in ipairs(callbacks.join) do f(player) end
	online[name] = player
	return player
end

local function dump(inv)
	local parts = {}
	local names = {}
	for list in pairs(inv.lists) do names[#names + 1] = list end
	table.sort(names)
	for _, list in ipairs(names) do
		local cells = {}
		for i, stack in ipairs(inv.lists[list]) do cells[i] = stack:to_string() end
		parts[#parts + 1] = list .. "=" .. table.concat(cells, ",")
	end
	return table.concat(parts, "|")
end

local POOL = {"t:dirt", "t:stone", "t:apple", "t:clay", "t:potion", "grug_gear:arrow",
	"t:pick", "t:sword"}
local function random_stack(max_count)
	local name = POOL[rand(1, #POOL)]
	local stack = ItemStack(name)
	stack.count = rand(1, max_count or registered[name].stack_max)
	if rand(1, 6) == 1 then stack.fields.note = "n" .. rand(1, 2) end
	if registered[name].stack_max == 1 and rand(1, 3) == 1 then stack.wear = rand(1, 3) * 1000 end
	return stack
end

do
	local outcomes, leftovers, dropped = {}, 0, 0
	local SIZES = {8, 12, 16, 20}
	for case = 1, 1500 do
		local player = new_player("g" .. case, case % 3 == 0 and "scout" or "warrior")
		local inv = player.inv
		for i = 1, rand(0, 4) do inv:set_size(I.content_list(i), SIZES[rand(1, 4)]) end
		-- Fill: every cell taken in a third of the cases (leftovers, drops at
		-- the feet), few free cells in another third, many in the rest.
		local empty_odds = ({[0] = 3, 12, 1000000})[case % 3]
		-- In a fixed order (pairs' order over string keys may differ per run).
		local fill = {"main", I.POTION_BELT, I.QUIVER_LIST}
		for i = 1, I.BAG_COUNT do fill[#fill + 1] = I.content_list(i) end
		for _, list in ipairs(fill) do
			local cells = inv.lists[list] or {}
			do
				for index = 1, #cells do
					if rand(1, empty_odds) ~= 1 then
						local stack = random_stack()
						if list == I.POTION_BELT then stack.name = "t:potion"; stack.count = rand(1, 20) end
						if list == I.QUIVER_LIST then stack.name = "grug_gear:arrow"; stack.fields = {} end
						cells[index] = stack
					end
				end
			end
		end
		feet = {}
		local way = rand(1, 3)
		local results = {}
		for _ = 1, rand(1, 3) do
			local stack = random_stack(250)
			if way == 1 then
				results[#results + 1] = I.give(player, stack):to_string()
			elseif way == 2 then
				for _, f in ipairs(callbacks.pickup) do
					results[#results + 1] = f(stack, player):to_string()
				end
			else
				core.handle_node_drops({x = 0, y = 0, z = 0}, {stack:to_string(), "t:stone 3"}, player)
			end
		end
		outcomes[#outcomes + 1] = case .. ">" .. table.concat(results, ",") .. ">" ..
			dump(inv) .. ">" .. table.concat(feet, ",")
		for _, left in ipairs(results) do
			if left ~= "" then leftovers = leftovers + 1 end
		end
		if #feet > 0 then dropped = dropped + 1 end
		online["g" .. case] = nil
	end
	local all = table.concat(outcomes, "\n")
	print(("G give case table: %d cases (%d gives with a leftover, %d cases with drops at " ..
		"the feet), outcome digest %s"):format(#outcomes, leftovers, dropped, digest(all)))
	-- The digest of the base (09c92f5f) under this very case table: the
	-- branch must give every outcome byte for byte.
	if BRANCH then eq(digest(all), "5f86d0a7", "G every outcome as on the base") end

	-- A miner: main half full with a partial stone stack at main[12], four
	-- bags of 20 half full; 1,000 dug stones.
	local miner = new_player("miner", "warrior")
	for i = 1, 4 do miner.inv:set_size(I.content_list(i), 20) end
	for list, cells in pairs(miner.inv.lists) do
		if list == "main" or list:match("_content$") then
			for index = 1, #cells do
				if index % 2 == 0 then cells[index] = ItemStack("t:dirt 50") end
			end
		end
	end
	miner.inv.lists.main[12] = ItemStack("t:stone 10")
	copies, writes = 0, 0
	local seam_before = #give_seam
	for _ = 1, 1000 do core.handle_node_drops({x = 0, y = 0, z = 0}, {"t:stone"}, miner) end
	print(("G a miner's 1,000 dug stones: %.1f stacks copied and %.2f written per dig"):format(
		copies / 1000, writes / 1000))
	local stones = 0
	for _, cells in pairs(miner.inv.lists) do
		for _, stack in ipairs(cells) do
			if stack.name == "t:stone" then stones = stones + stack.count end
		end
	end
	eq(stones, 1010, "G the miner holds every stone")
	if BRANCH then
		check(copies / 1000 < 40, "G a dig merging into main copies main only")
		eq(#give_seam - seam_before, 1000, "G the give seam hears every placed stone")
		local full = new_player("full", "warrior")
		for index = 1, 32 do full.inv.lists.main[index] = ItemStack("t:dirt 99") end
		local before = #give_seam
		eq(I.give(full, "t:clay 3"):to_string(), "t:clay 3 0", "G nothing fits: all left over")
		eq(#give_seam, before, "G ... and the seam hears nothing")
	end
end

------------------------------------------------------------------------------
-- Q. The quiver total's re-sends (P3-02).
------------------------------------------------------------------------------
do
	local scout = new_player("scout", "scout")
	scout.inv.lists.main[10] = ItemStack("grug_gear:arrow 100")
	I.give(scout, "grug_gear:arrow 300")
	character_page.scout = true
	advance(5)
	refreshes = {}
	local last_change, events = 0, 0
	-- 20 s: a shot every 0.5 s, every other shot refunded, a pickup every 3 s.
	for tick = 1, 40 do
		advance(0.5)
		I.consume_ammo(scout, 1)
		events = events + 1
		if tick % 2 == 0 then I.refund_ammo(scout, 1); events = events + 1 end
		if tick % 6 == 0 then
			for _, f in ipairs(callbacks.pickup) do f(ItemStack("grug_gear:arrow 2"), scout) end
			events = events + 1
		end
		last_change = clock
	end
	advance(3)
	local count = #refreshes
	print(("Q a Scout's 20 s of shots: %d quiver changes, %d Character page re-sends"):format(
		events, count))
	check(#refreshes > 0 and refreshes[#refreshes].at >= last_change,
		"Q the last change is always re-sent")
	if BRANCH then
		check(count <= 22, "Q about one re-send a second")
		-- Quiet for longer than the window: the next shot re-sends at once.
		advance(5)
		refreshes = {}
		I.consume_ammo(scout, 1)
		eq(#refreshes, 1, "Q a lone shot re-sends at once")
		I.consume_ammo(scout, 1)
		eq(#refreshes, 1, "Q a second shot within the second waits")
		I.unload_quiver(scout, 1)
		eq(#refreshes, 2, "Q the player's own action re-sends at once")
		advance(1.5)
		eq(#refreshes, 2, "Q ... and leaves nothing for the window's end")
		I.consume_ammo(scout, 1)
		advance(0.2)
		I.consume_ammo(scout, 1)
		advance(1.5)
		eq(#refreshes, 4, "Q a held-back change is re-sent at the window's end")
		character_page.scout = nil
		I.consume_ammo(scout, 1)
		advance(2)
		eq(#refreshes, 4, "Q another page selected: nothing re-sent")
	end
end

------------------------------------------------------------------------------
-- U. The Basic unlock's scans (P2-04), the REAL basic_unlock.lua.
------------------------------------------------------------------------------
do
	local steps, dig, give_hooks, ucallbacks = {}, {}, {}, {join = {}, leave = {}, action = {}}
	local held_reads = 0
	local saved_core = core
	core = {
		get_item_group = saved_core.get_item_group,
		register_on_joinplayer = function(f) table.insert(ucallbacks.join, f) end,
		register_on_leaveplayer = function(f) table.insert(ucallbacks.leave, f) end,
		register_on_player_inventory_action = function(f) table.insert(ucallbacks.action, f) end,
		register_on_dignode = function(f) dig[#dig + 1] = f end,
		register_globalstep = function(f) steps[#steps + 1] = f end,
		get_player_by_name = function(name) return online[name] end,
		is_creative_enabled = function() return false end,
		log = function() end,
	}
	local recipes = {
		{id = "basic:furnace", area = "basic", output = "t:furnace", ingredients = {{group = "stone", n = 8}}},
		{id = "basic:brick", area = "basic", output = "t:brick", ingredients = {{item = "t:clay", n = 4}}},
		{id = "basic:salad", area = "basic", output = "t:salad",
			ingredients = {{item = "t:apple", n = 1}, {item = "t:dirt", n = 1}}},
		{id = "basic:pickstew", area = "basic", output = "t:pickstew",
			ingredients = {{item = "t:pick", n = 1}, {item = "t:potion", n = 1}}},
		{id = "basic:bolt", area = "basic", output = "t:bolt",
			ingredients = {{item = "grug_gear:arrow", n = 1}, {item = "t:sword", n = 1}}},
	}
	local feed = {}
	grug_core = {feed = function(_, _, text) feed[#feed + 1] = text return true end,
		item_name = function(name) return name end}
	grug_jobs = {
		recipes_in_area = function(area) return area == "basic" and recipes or {} end,
		ingredient_token = function(entry) return entry.item or ("group:" .. entry.group) end,
		PROFESSIONS = {}, profession_level = function() return 0 end,
		recipe = function() return nil end,
	}
	local real_inventory = grug_inventory
	grug_inventory = {register_on_give = function(f) give_hooks[#give_hooks + 1] = f end}
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_unlock.lua")
	local J = grug_jobs
	local miner = {inv = new_inventory(), fields = {}}
	miner.inv:set_size("main", 32)
	miner.inv.lists.main[1] = ItemStack("t:stone 20")
	function miner:get_player_name() return "unlock_miner" end
	function miner:get_inventory() return self.inv end
	function miner:is_player() return true end
	function miner:get_meta()
		local fields = self.fields
		return {
			get_string = function(_, key)
				if key == J.HELD_KEY then held_reads = held_reads + 1 end
				return fields[key] or ""
			end,
			set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		}
	end
	online.unlock_miner = miner
	for _, f in ipairs(ucallbacks.join) do f(miner) end
	check(J.recipe_known(miner, recipes[1]), "U the first scan knows the furnace (stone held)")
	local function step(seconds)
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			for _, f in ipairs(steps) do f(0.1) end
		end
	end
	local function dig_stone(name)
		for _, f in ipairs(dig) do f({x = 0, y = 0, z = 0}, {name = "t:stone"}, miner) end
		for _, f in ipairs(give_hooks) do f(miner, name or "t:stone") end
	end
	step(0.6)
	local reads, held_before = miner.inv.reads, held_reads
	for _ = 1, 100 do
		dig_stone()
		step(0.5)
	end
	print(("U 100 dug stones in 50 s: %d inventory scans (get_lists), %d reads of the held " ..
		"set's string"):format(miner.inv.reads - reads, held_reads - held_before))
	if BRANCH then
		check(miner.inv.reads - reads <= 6, "U a held drop: only the 10 s sweeps scan")
		eq(held_reads - held_before, 0, "U the held set's string is not read again")
	end
	-- A new token: scanned within 0.5 s, on both trees.
	miner.inv.lists.main[2] = ItemStack("t:clay 4")
	dig_stone("t:clay")
	step(0.55)
	check(J.recipe_known(miner, recipes[2]), "U a new token is scanned within 0.5 s")
	eq(feed[#feed], "New recipe: t:brick", "U ... and announced")
	online.unlock_miner = nil
	-- The case table: 12 characters, each 40 arrivals of a random pool item
	-- through the give helper (with a dug node) or an inventory action, a
	-- step of 0.5 s after each; the feed lines and the known recipes after
	-- every step must be the same on the base and the branch.
	local trace = {}
	for case = 1, 12 do
		local name = "unlock_" .. case
		local p = {inv = new_inventory(), fields = {}}
		p.inv:set_size("main", 32)
		p.get_player_name = function() return name end
		p.get_inventory, p.is_player, p.get_meta = miner.get_inventory, miner.is_player, miner.get_meta
		online[name] = p
		for _, f in ipairs(ucallbacks.join) do f(p) end
		for event = 1, 40 do
			local stack = random_stack()
			p.inv.lists.main[event % 32 + 1] = stack
			if rand(1, 3) == 1 then
				for _, f in ipairs(ucallbacks.action) do f(p, "move", p.inv, {}) end
			else
				for _, f in ipairs(dig) do f({x = 0, y = 0, z = 0}, {name = "t:stone"}, p) end
				for _, f in ipairs(give_hooks) do f(p, stack:get_name()) end
			end
			step(0.5)
			local known = {}
			for _, recipe in ipairs(recipes) do
				known[#known + 1] = J.recipe_known(p, recipe) and "1" or "0"
			end
			trace[#trace + 1] = name .. ":" .. event .. ":" .. table.concat(known) .. ":" ..
				tostring(feed[#feed])
		end
		online[name] = nil
	end
	local all = table.concat(trace, "\n")
	print(("U unlock case table: %d events, outcome digest %s"):format(#trace, digest(all)))
	if BRANCH then eq(digest(all), "b1f13536", "U every unlock and line as on the base") end
	grug_inventory = real_inventory
	core = saved_core
end

------------------------------------------------------------------------------
-- K. The Achievements tab's re-sends (P2-01), the REAL grug_achievements.
------------------------------------------------------------------------------
do
	local saved_core = core
	local eligible_kill
	local tab_sends, page_sends = 0, 0
	local function new_meta()
		local data = {}
		return {data = data,
			get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value ~= "" and value or nil end,
			get_int = function(_, key) return tonumber(data[key]) or 0 end,
			set_int = function(_, key, value) data[key] = tostring(value) end}
	end
	core = {
		get_modpath = function() return ROOT .. "/mods/PLAYER/grug_achievements" end,
		get_current_modname = function() return "grug_achievements" end,
		register_on_joinplayer = function() end,
		register_on_mods_loaded = function() end,
		register_on_dieplayer = function() end,
		register_chatcommand = function() end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		formspec_escape = function(text) return (text:gsub("[\\%[%];,]", "\\%0")) end,
		colorize = function(_, text) return text end,
		log = function() end,
		get_mod_storage = function() return new_meta() end,
	}
	grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
	grug_jobs = {register_on_award_progress = function() end}
	grug_core = {feed = function() return true end,
		get_player_faction = function() return "accord" end}
	local real_inventory = grug_inventory
	grug_inventory = {
		refresh_character = function() page_sends = page_sends + 1 end,
		refresh_character_tab = function(_, tab)
			if tab == "achievements" then tab_sends = tab_sends + 1 end
		end,
	}
	grug_visuals = {register_cloak_source = function() end, apply = function() end}
	sfinv = {set_player_inventory_formspec = function() end, contexts = {}}
	grug_mobs = {
		register_on_eligible_kill = function(fn) eligible_kill = fn end,
		register_on_boss_kill = function() end,
		subtype = function() return nil end,
		registered_cadence = {["grug_mobs:boar"] = true, ["grug_mobs:zombie"] = true},
	}
	dofile(ROOT .. "/mods/CORE/grug_core/ui.lua")
	dofile(ROOT .. "/mods/PLAYER/grug_achievements/init.lua")
	local A = grug_achievements
	local meta = new_meta()
	local hunter = {get_meta = function() return meta end,
		get_player_name = function() return "hunter" end, is_player = function() return true end}
	eq(#A.kill_counters("grug_mobs:boar"), 2, "K a boar feeds two counters")
	-- The rows of the tab's first page, as the page builds them.
	local context = {}
	sfinv.contexts.hunter = context
	A.character_achievements_formspec(hunter, context, {x = 10, y = 1.25, w = 9.3, h = 6})
	local shown = context.grug_achievement_counters
	if BRANCH then check(shown ~= nil, "K the rows record their counters") end
	if shown then
		local rows = 0
		for _ in pairs(shown) do rows = rows + 1 end
		check(rows > 0, "K the rows record their counters (" .. rows .. ")")
		context.grug_achievement_counters = {["kill:animal"] = true, ["kill:family:boar"] = true}
	end
	-- 30 boars while the rows show both of their counters (Boaring Work I
	-- is earned at the 10th: that kill re-sends the whole page instead).
	for _ = 1, 30 do eligible_kill(hunter, {name = "grug_mobs:boar"}) end
	print(("K 30 boar kills, both counters shown: %d tab re-sends, %d page re-sends"):format(
		tab_sends, page_sends))
	if BRANCH then
		eq(tab_sends + page_sends, 30, "K one re-send per kill")
	end
	tab_sends, page_sends = 0, 0
	sfinv.contexts.hunter.grug_achievement_counters = {["kill:zombie"] = true}
	for _ = 1, 30 do eligible_kill(hunter, {name = "grug_mobs:boar"}) end
	print(("K 30 boar kills, other counters shown: %d tab re-sends, %d page re-sends"):format(
		tab_sends, page_sends))
	if BRANCH then
		eq(tab_sends, 0, "K no re-send for counters the rows do not show")
	end
	grug_inventory = real_inventory
	core = saved_core
end

------------------------------------------------------------------------------
-- M. The mail store's decodes (P5-02), the REAL store.lua.
------------------------------------------------------------------------------
do
	local saved_core = core
	local storage, decodes = {}, 0
	local Storage = {}
	Storage.__index = Storage
	function Storage:get_string(key) return storage[key] or "" end
	function Storage:set_string(key, value) storage[key] = value ~= "" and value or nil end
	function Storage:get_int(key) return tonumber(storage[key]) or 0 end
	function Storage:set_int(key, value) storage[key] = tostring(value) end
	-- A plain serializer: sorted keys, strings %q, a fresh table per decode.
	local function ser(value)
		if type(value) == "table" then
			local keys = {}
			for key in pairs(value) do keys[#keys + 1] = key end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			local parts = {}
			for _, key in ipairs(keys) do
				parts[#parts + 1] = "[" .. ser(key) .. "]=" .. ser(value[key])
			end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif type(value) == "string" then
			return ("%q"):format(value)
		end
		return tostring(value)
	end
	core = {
		get_mod_storage = function() return setmetatable({}, Storage) end,
		serialize = function(value) return "return " .. ser(value) end,
		deserialize = function(text)
			decodes = decodes + 1
			return assert(loadstring(text))()
		end,
		log = function() end,
	}
	local now = 1800000000
	local real_time = os.time
	os.time = function() return now end
	grug_mail = {}
	local M = dofile(ROOT .. "/mods/PLAYER/grug_mail/model.lua")
	grug_mail.model = M
	local S = dofile(ROOT .. "/mods/PLAYER/grug_mail/store.lua")
	local box = M.new_box()
	box.letters = {}
	for id = 1, 50 do
		M.deliver(box, M.letter(id, "player", "Sender", "Subject " .. id,
			string.rep("x", 400) .. id, {}, now))
	end
	S.save_box("Brakka", box)
	S.save_broadcasts({{id = 99, subject = "News", body = "Hello", time = now}})
	-- A click on an unread letter: selected_letter, open_letter (which marks
	-- it read and saves), unread_count, counts_of, letters_tab; the
	-- broadcasts twice.
	decodes = 0
	local first = S.box("Brakka")
	local second = S.box("Brakka")
	check(first ~= second and first.letters ~= second.letters, "M every read is a fresh table")
	first.letters[1].subject = "changed, never saved"
	eq(S.box("Brakka").letters[1].subject, "Subject 50", "M a caller's change stays its own")
	local letter = M.find(second.letters, 50)
	M.mark_read(letter)
	S.save_box("Brakka", second)
	local after_save = S.box("Brakka")
	check(M.find(after_save.letters, 50).read == true, "M a read after a save sees the save")
	S.broadcasts()
	S.box("Brakka")
	S.box("Brakka")
	S.broadcasts()
	print(("M an unread letter's click (6 box reads, 2 broadcast reads, 1 save): %d decodes"):format(
		decodes))
	-- Prune semantics: an expired letter goes at the read, saved once.
	now = now + 31 * 24 * 3600
	local expired = S.box("Brakka")
	eq(#expired.letters, 0, "M expired letters go at the read")
	eq(#S.box("Brakka").letters, 0, "M ... and stay gone")
	os.time = real_time
	core = saved_core
end

------------------------------------------------------------------------------
-- I. A captured shot's wear (I2-09), the REAL grug_repair/runtime.lua.
------------------------------------------------------------------------------
do
	local saved_core, real_inventory = core, grug_inventory
	local archer = new_player("archer", "scout")
	core = setmetatable({get_mod_storage = function() return {get_string = function() return "" end,
		set_string = function() end} end,
		is_creative_enabled = function() return false end},
		{__index = function(_, key) if key:match("^register_") then return function() end end end})
	grug_core = setmetatable({equipment_is_broken = function() return false end},
		{__index = function(_, key) if key:match("^register_") then return function() end end end})
	grug_sounds = {play = function() end}
	grug_inventory = {BAG_COUNT = 4, content_list = real_inventory.content_list,
		is_equipment_list = function(list) return list == "grug_weapon" end,
		equipment_changed = function() end}
	grug_repair = {eligible = function(stack) return stack.name == "t:bow" end,
		maximum_durability = function() return 100 end, refresh_durability = function() end}
	dofile(ROOT .. "/mods/ITEMS/grug_repair/runtime.lua")
	local inv = archer.inv
	inv:set_size("grug_weapon", 1)
	inv:set_size("grug_offhand", 1)
	for i = 1, 4 do inv:set_size(I.content_list(i), 20) end
	for index = 1, 32 do inv.lists.main[index] = ItemStack("t:dirt 5") end
	local bow = ItemStack("t:bow")
	bow.fields._grug_repair_item_id = "repair:7"
	inv.lists.grug_weapon[1] = bow
	copies = 0
	grug_repair.wear_outgoing(archer, {id = "shot1", item_ids = {"repair:7"}})
	local in_hand = copies
	inv.lists.grug_bag2_content[5] = inv.lists.grug_weapon[1]
	inv.lists.grug_weapon[1] = ItemStack("")
	copies = 0
	grug_repair.wear_outgoing(archer, {id = "shot2", item_ids = {"repair:7"}})
	print(("I a captured shot's wear: %d stacks read with the bow in hand, %d with it in " ..
		"the second bag"):format(in_hand, copies))
	eq(inv.lists.grug_bag2_content[5].wear, 2 * 655, "I both shots wore the captured bow")
	if BRANCH then
		-- The find and the wear's own read of the stack.
		eq(in_hand, 2, "I the bow in hand: the weapon slot read")
		eq(copies, 1 + 1 + 32 + 20 + 5 + 1, "I swapped away: read up to the bow")
	end
	core, grug_inventory = saved_core, real_inventory
end

------------------------------------------------------------------------------
-- V. The compose cache (P1-01), the REAL looks.lua and compose.lua.
------------------------------------------------------------------------------
do
	local saved_core = core
	core = setmetatable({log = function() end, get_us_time = function() return 1 end},
		{__index = function() return function() end end})
	grug_visuals = {}
	-- One material grade per line: the composes below name skins only.
	grug_gear = {MATERIALS = {{cloth = {key = "c"}, leather = {key = "l"}, metal = {key = "m"}}},
		BRACKETS = {1}, bracket_for_level = function() return 1 end}
	dofile(ROOT .. "/mods/PLAYER/grug_visuals/looks.lua")
	dofile(ROOT .. "/mods/PLAYER/grug_visuals/compose.lua")
	grug_visuals.index_armor({})
	local function compose(i) return grug_visuals.compose({skin = "skin_" .. i .. ".png"}) end
	local first = compose(0)
	check(compose(0) == first, "V a repeat call is the same table")
	for i = 1, 3000 do compose(i) end
	check(compose(0) == first, "V an old-generation hit is the same table")
	for i = 3001, 9000 do compose(i) end
	local again = compose(0)
	local cache = grug_visuals.cache
	if not BRANCH and cache then
		local entries = 0
		for _ in pairs(cache) do entries = entries + 1 end
		print(("V 9,001 distinct looks: %d cache entries (unbounded)"):format(entries))
	else
		print("V 9,001 distinct looks: at most 4,096 cache entries (two generations of 2,048)")
		check(cache == nil, "V the cache is not exported")
		check(again ~= first, "V a dropped entry is composed again")
	end
	eq(again.key, first.key, "V ... with the same key")
	eq(again.digest, first.digest, "V ... and the same digest")
	core = saved_core
end

if failures > 0 then
	error(("R81 UI PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R81 UI PORTABLE PASS checks=%d"):format(checks))
