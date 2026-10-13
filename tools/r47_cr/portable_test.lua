-- Round 47 lane CR portable test (LuaJIT): the Basic recipe unlock
-- (round47-plan.md ruling 19, §4.8; grug_jobs/basic_unlock.lua).
--
--   luajit tools/r47_cr/portable_test.lua [REPO]
--
-- Loads the REAL grug_jobs registry.lua with the REAL Basic catalog
-- (basic_recipes.lua through register_basic_catalog; stand-in items for its
-- names, the groups' members set here) and the REAL basic_unlock.lua under a
-- stub engine with player meta, inventories and the globalstep. Checks:
--   T  the starter set: sticks and every wooden tool are known from the
--      start, nothing else of Basic; profession recipes are not its
--      business (always true);
--   F  the first scan: a character without the key (a new one, or an
--      existing one at its first login after the update) is scanned at its
--      join, silently; what it holds is known at once; the key is written;
--   G  a group ingredient counts when any member was held; an item entry
--      only by its own name; items with metadata count (held is held); any
--      list counts (the overflow);
--   M  "New recipe: X" for one, "New recipes: X and N more" for several,
--      one line per scan, the open page resent unless the scan is quiet;
--      nothing for a scan that unlocks nothing;
--   S  when the scan runs: an inventory action or a dug node in the
--      player's slot within 0.5 s, every 10 s without one (a pickup), one
--      slot's players per step; a rejoin reads the stored set;
--   P  the stored set: format, the tokens only a Basic recipe names, its
--      size for a character that has held ~300 items (printed), the scan's
--      cost per pass (printed, a comparison).
-- Prints "R47 CR PORTABLE PASS checks=<n>" or the failures (exit 1).

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
-- Engine surface.
------------------------------------------------------------------------------
local callbacks = {join = {}, leave = {}, loaded = {}, action = {}, dig = {}, step = {}}
local online, feed_lines, refreshes = {}, {}, {}
core = {
	registered_items = {},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.loaded, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_dignode = function(f) table.insert(callbacks.dig, f) end,
	register_globalstep = function(f) table.insert(callbacks.step, f) end,
	get_player_by_name = function(name) return online[name] end,
	log = function() end,
}

local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	if type(item) == "table" then
		return setmetatable({name = item.name, count = item.count, meta = item.meta}, Stack)
	end
	local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
	return setmetatable({name = name or "", count = name ~= "" and (tonumber(count) or 1) or 0},
		Stack)
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end

local function new_inventory()
	local inv = {lists = {}, reads = 0}
	function inv:set_size(list, size)
		self.lists[list] = self.lists[list] or {}
		for i = 1, size do self.lists[list][i] = self.lists[list][i] or ItemStack("") end
	end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:get_lists()
		self.reads = self.reads + 1
		local out = {}
		for name, l in pairs(self.lists) do
			out[name] = {}
			for i = 1, #l do out[name][i] = ItemStack(l[i]) end
		end
		return out
	end
	return inv
end
local function new_meta()
	local fields = {}
	return {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		fields = fields,
	}
end

------------------------------------------------------------------------------
-- Mod surface; the REAL registry and catalog with stand-in items.
------------------------------------------------------------------------------
grug_core = {
	feed = function(player, kind, text)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind, text = text}
		return true
	end,
	item_name = function(name)
		local def = core.registered_items[name]
		return def and def.description or name
	end,
}
grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
local catalog = dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_recipes.lua")

-- Every name the catalog uses becomes a stand-in item; the groups get
-- members by name (the real ones come from the item definitions).
local GROUP_OF = {
	["default:wood"] = {wood = 1}, ["default:pine_wood"] = {wood = 1},
	["default:acacia_wood"] = {wood = 1}, ["default:junglewood"] = {wood = 1},
	["default:aspen_wood"] = {wood = 1}, ["default:stick"] = {stick = 1},
	["default:cobble"] = {stone = 1}, ["default:desert_cobble"] = {stone = 1},
	["default:coal_lump"] = {coal = 1}, ["wool:white"] = {wool = 1}, ["wool:red"] = {wool = 1},
}
local function item(name, description, groups)
	if core.registered_items[name] then return end
	core.registered_items[name] = {description = description or name,
		groups = groups or GROUP_OF[name] or {}}
end
item("default:stick", "Stick")
item("default:wood", "Wooden Planks")
item("default:pine_wood", "Pine Wood Planks")
item("default:tree", "Apple Tree")
item("default:coal_lump", "Coal Lump")
item("default:torch", "Torch")
item("grug_smelting:charcoal", "Charcoal", {coal = 1})
local function walk(name) item(name) end
for _, row in ipairs(catalog.recipes) do
	walk(row.output)
	for _, entry in ipairs(row.ingredients) do if entry.item then walk(entry.item) end end
end
for _, row in ipairs(catalog.stairs) do
	walk(row[2])
	for _, kind in ipairs({"stair_", "stair_inner_", "stair_outer_", "slab_"}) do
		walk("stairs:" .. kind .. row[1])
	end
end
for _, row in ipairs(catalog.walls) do walk(row[1]); walk(row[2]) end
-- A member for every group the catalog names and the table above leaves out.
for _, row in ipairs(catalog.recipes) do
	for _, entry in ipairs(row.ingredients) do
		if entry.group then
			local found = false
			for _, def in pairs(core.registered_items) do
				if def.groups[entry.group] then found = true end
			end
			if not found then item("t:" .. entry.group, "Any " .. entry.group, {[entry.group] = 1}) end
		end
	end
end
grug_jobs.register_basic_catalog(catalog)
-- A profession recipe: never the unlock's business.
item("t:stew", "Hearty Stew")
item("t:meat", "Meat")
grug_jobs.register_ingredient_tier("t:meat", 1)
local stew = grug_jobs.register_recipe({area = "cooking", tier = 1, output = "t:stew",
	ingredients = {{item = "t:meat", n = 1}}, time = 1})
for _, fn in ipairs(callbacks.loaded) do fn() end

local J = grug_jobs
J.refresh_crafting_page = function(player) refreshes[#refreshes + 1] = player:get_player_name() end
dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_unlock.lua")
eq(#callbacks.step, 1, "S one globalstep")

local basic = J.recipes_in_area("basic")
local function recipe_for(output, first_item)
	for _, recipe in ipairs(J.recipes_for_output(output)) do
		if not first_item or (recipe.ingredients[1].item == first_item) then return recipe end
	end
end
local function known_outputs(player)
	local out, n = {}, 0
	for _, recipe in ipairs(basic) do
		if J.recipe_known(player, recipe) then
			out[recipe.output] = true
			n = n + 1
		end
	end
	return out, n
end

local function new_player(name, items, meta_fields)
	local inv = new_inventory()
	inv:set_size("main", 32)
	inv:set_size("grug_craft_out", 4)
	for index, itemstring in ipairs(items or {}) do inv:set_stack("main", index, itemstring) end
	local meta = new_meta()
	for key, value in pairs(meta_fields or {}) do meta.fields[key] = value end
	local player = {name = name, inv = inv, meta = meta}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return true end
	return player
end
local function join(player)
	online[player.name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
end
local function leave(player)
	online[player.name] = nil
	for _, f in ipairs(callbacks.leave) do f(player) end
end
local function step(seconds)
	local steps = math.floor(seconds / 0.05 + 0.5)
	for _ = 1, steps do
		for _, f in ipairs(callbacks.step) do f(0.05) end
	end
end
local function lines_of(name)
	local out = {}
	for _, line in ipairs(feed_lines) do
		if line.name == name then out[#out + 1] = line.text end
	end
	return out
end

------------------------------------------------------------------------------
-- T. The starter set.
------------------------------------------------------------------------------
do
	local p = new_player("t1")
	join(p)
	local known, n = known_outputs(p)
	for _, name in ipairs({"default:stick", "grug_materials:pick_wood", "grug_materials:axe_wood",
			"grug_materials:shovel_wood", "grug_farming:hoe"}) do
		check(known[name], "T " .. name .. " is known from the start")
	end
	eq(n, 5, "T nothing else of Basic (" .. #basic .. " recipes)")
	check(not known["default:torch"], "T the torch is not")
	check(J.recipe_known(p, stew), "T a profession recipe is not the unlock's business")
	eq(#lines_of("t1"), 0, "T no feed line for an empty inventory")
	eq(p.meta.fields[J.HELD_KEY], "1", "T the first scan stores the (empty) set")
	leave(p)
end

------------------------------------------------------------------------------
-- F. The first scan (a new character's first join; an existing character's
-- first login after the update): silent, everything held counts.
------------------------------------------------------------------------------
do
	local old = new_player("f1", {"default:tree 3", "default:coal_lump 5", "default:stick 7",
		"default:cobble 20"})
	join(old)
	local known, n = known_outputs(old)
	check(known["default:wood"], "F planks from the tree it carries")
	check(known["default:torch"], "F the torch from coal and sticks")
	check(known["default:furnace"], "F the furnace from any stone")
	check(not known["default:chest"], "F not the chest (no planks held)")
	eq(#lines_of("f1"), 0, "F the first scan is silent")
	eq(#refreshes, 0, "F ... and resends nothing")
	check(n > 5, "F more than the starter set (" .. n .. ")")
	local stored = old.meta.fields[J.HELD_KEY]
	eq(stored, "1 default:coal_lump default:cobble default:stick default:tree " ..
		"group:coal group:stick group:stone", "F the stored set: the format word, the tokens sorted")
	-- A rejoin reads the set back; nothing is new, nothing is said.
	leave(old)
	old.inv:set_stack("main", 1, "")
	old.inv:set_stack("main", 2, "")
	join(old)
	check(known_outputs(old)["default:torch"], "F the rejoin remembers what was held")
	eq(#lines_of("f1"), 0, "F ... silently")
	leave(old)
end

------------------------------------------------------------------------------
-- G. Groups, item entries, metadata; M. the feed line.
------------------------------------------------------------------------------
do
	local p = new_player("g1")
	join(p)
	-- Charcoal is a coal-group member: the black dye (any coal) unlocks, the
	-- torch (any coal and any stick) not yet.
	p.inv:set_stack("main", 9, "grug_smelting:charcoal 1")
	eq(J.scan_held(p), 1, "G charcoal: one recipe of the coal group")
	eq(lines_of("g1")[1], "New recipe: dye:black", "M one recipe by name")
	eq(refreshes[#refreshes], "g1", "M the open page is resent")
	check(not known_outputs(p)["default:torch"], "G the torch still needs a stick")
	eq(J.scan_held(p), 0, "M a scan with nothing new unlocks nothing")
	eq(#lines_of("g1"), 1, "M ... and says nothing")
	-- A stick (the stick group): the torch, with the charcoal held before
	-- and gone now, and the ladder (sticks only).
	p.inv:set_stack("main", 9, "")
	p.inv:set_stack("main", 10, "default:stick 1")
	eq(J.scan_held(p), 2, "G the stick: two recipes")
	eq(lines_of("g1")[2], "New recipes: Torch and 1 more", "M two in one line, the first by name")
	-- Pine planks: any-wood recipes unlock, oak-plank recipes do not.
	local before = #refreshes
	p.inv:set_stack("main", 11, "default:pine_wood 1")
	local unlocked = J.scan_held(p, true)
	check(unlocked > 1, "G a group member unlocks the group's recipes (" .. unlocked .. ")")
	local known = known_outputs(p)
	check(known["default:chest"], "G the chest from pine planks (any wood)")
	check(not known["default:fence_rail_wood"], "G the oak-plank rails need oak planks")
	check(known["default:fence_rail_pine_wood"], "G the pine rails need pine planks: held")
	local line = lines_of("g1")[3]
	check(line and line:match("^New recipes: .+ and " .. (unlocked - 1) .. " more$") ~= nil,
		"M several in one line with the count (" .. tostring(line) .. ")")
	eq(#lines_of("g1"), 3, "M one line per scan")
	eq(#refreshes, before, "M a quiet scan resends nothing")
	-- Held is held: a stack with metadata counts (unlike an ingredient).
	local tagged = ItemStack("default:tree 1")
	tagged.meta = {owner = "x"}
	p.inv:set_stack("main", 12, tagged)
	J.scan_held(p)
	check(known_outputs(p)["default:wood"], "G a stack with metadata counts as held")
	-- Any list counts: the overflow too.
	p.inv:set_stack("grug_craft_out", 1, "default:clay_lump 4")
	J.scan_held(p)
	check(known_outputs(p)["default:clay"], "G an item in the overflow counts")
	leave(p)
end

------------------------------------------------------------------------------
-- S. When the scan runs.
------------------------------------------------------------------------------
do
	local a, b = new_player("s1"), new_player("s2")
	join(a)
	join(b)
	step(0.6)
	local reads_a, reads_b = a.inv.reads, b.inv.reads
	-- A pickup (no inventory action): only the sweep finds it.
	-- (The sweep is the 20th visit of the player's slot, 0.5 s apart, the
	-- first within 0.5 s of the join: between 9.5 and 10 s after it.)
	a.inv:set_stack("main", 1, "default:tree 1")
	step(8.5)
	check(not known_outputs(a)["default:wood"], "S before the sweep the pickup is not scanned")
	step(1)
	check(known_outputs(a)["default:wood"], "S the 10 s sweep finds it")
	eq(lines_of("s1")[1], "New recipe: Wooden Planks", "S the sweep's scan says it")
	-- An inventory action: scanned in the player's slot, within 0.5 s.
	b.inv:set_stack("main", 1, "default:clay_lump 4")
	for _, f in ipairs(callbacks.action) do f(b, "move", b.inv, {}) end
	step(0.55)
	check(known_outputs(b)["default:clay"], "S an inventory action: scanned within 0.5 s")
	-- A dug node, the same.
	b.inv:set_stack("main", 2, "default:papyrus 3")
	for _, f in ipairs(callbacks.dig) do f({x = 0, y = 0, z = 0}, {name = "default:papyrus"}, b) end
	step(0.55)
	check(known_outputs(b)["default:paper"], "S a dug node: scanned within 0.5 s")
	-- A delivered craft (jobs.lua calls held_dirty).
	b.inv:set_stack("main", 3, "default:paper 3")
	J.held_dirty(b)
	step(0.55)
	check(known_outputs(b)["default:book"], "S a crafted delivery: scanned within 0.5 s")
	-- Per pass: one slot's players. Over 10 s each player is read about
	-- 20 / 20 times (one sweep, no actions), never every step.
	reads_a, reads_b = a.inv.reads, b.inv.reads
	step(10)
	eq(a.inv.reads - reads_a, 1, "S ten quiet seconds: one sweep scan of s1")
	eq(b.inv.reads - reads_b, 1, "S ... and one of s2")
	leave(a)
	leave(b)
	step(1)
	eq(a.inv.reads - reads_a, 1, "S no scan after a leave")
end

------------------------------------------------------------------------------
-- P. The stored set: size for ~300 held items, cost per pass.
------------------------------------------------------------------------------
do
	-- Every item a Basic recipe names, a member of each of its groups, and
	-- items no recipe needs up to 300 distinct.
	local names, seen = {}, {}
	local function hold(name)
		if not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	for _, recipe in ipairs(basic) do
		for _, entry in ipairs(recipe.ingredients) do
			if entry.item then
				hold(entry.item)
			else
				local member
				for name, def in pairs(core.registered_items) do
					if def.groups[entry.group] and (not member or name < member) then member = name end
				end
				hold(member)
			end
		end
	end
	local needed = #names
	local extra = 0
	while #names < 300 do
		extra = extra + 1
		local name = ("grug_gear:junk_item_%03d"):format(extra)
		item(name)
		names[#names + 1] = name
	end
	local p = new_player("p1")
	join(p)
	local plain = 0
	for i = 1, 300 do plain = plain + #names[i] + 1 end
	-- Held 300 items, 32 at a time (one list's worth per scan).
	for from = 1, 300, 32 do
		for slot = 1, 32 do p.inv:set_stack("main", slot, names[from + slot - 1] or "") end
		J.scan_held(p, true)
	end
	local stored = p.meta.fields[J.HELD_KEY]
	local _, words = stored:gsub("%S+", "")
	local _, n = known_outputs(p)
	print(("P a character that held 300 distinct items (%d of them Basic ingredients): " ..
		"%d tokens stored, %d bytes (all 300 names would be %d bytes); %d of %d Basic " ..
		"recipes known"):format(needed, words - 1, #stored, plain, n, #basic))
	check(#stored < plain, "P the stored set is smaller than the names held")
	check(not stored:find("junk", 1, true), "P a name no Basic recipe needs is not stored")
	eq(n, #basic, "P with every ingredient held, every Basic recipe is listed")
	-- The cost of one scan of a full inventory (main 32, 4 bags of 16, the
	-- other lists), nothing new: a comparison, not a target.
	local q = new_player("p2")
	for i = 1, 4 do q.inv:set_size("grug_bag" .. i .. "_content", 16) end
	q.inv:set_size("grug_quiver", 4)
	q.inv:set_size("grug_potion_belt", 4)
	for slot = 1, 32 do q.inv:set_stack("main", slot, names[slot * 3]) end
	for i = 1, 4 do
		for slot = 1, 16 do
			q.inv:set_stack("grug_bag" .. i .. "_content", slot, names[(i * 16 + slot) % 300 + 1])
		end
	end
	join(q)
	local runs = 2000
	local started = os.clock()
	for _ = 1, runs do J.scan_held(q, true) end
	local spent = (os.clock() - started) / runs
	print(("P one scan of %d slots (nothing new): %.1f us under LuaJIT"):format(
		32 + 64 + 4 + 4 + 4 + 1, spent * 1000000))
	check(spent < 0.01, "P a scan is cheap")
end

if failures > 0 then
	error(("R47 CR PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R47 CR PORTABLE PASS checks=%d"):format(checks))
