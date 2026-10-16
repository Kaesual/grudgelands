-- Round 50 lane HOTBAR portable test (round50-plan.md rulings 1-3, D1-D4,
-- §4 HOTBAR). Through tools/r44_ch/harness.lua (the REAL sfinv and
-- grug_inventory: hotbars.lua, equipment.lua, bags.lua with storage.lua,
-- ui.lua, pages.lua) plus the REAL grug_jobs registry/state/jobs.lua,
-- grug_quests registry/state.lua, grug_housing api.lua (registry model) and
-- soulbound.lua, grug_traders crown.lua, grug_repair service.lua,
-- grug_skills bound_items.lua, grug_core map_reset.lua, grug_quickbar,
-- default/node_formspec.lua and default/chests.lua, and pieces cut out of
-- grug_abilities/init.lua (the kit normalisation, the initial kit, the
-- switch callback) and grug_traders/trade.lua (the vendor's sell rows), under
-- a small fake engine. Checks, by letter:
--   J  joins: an existing character keeps its hotbar as A, B is empty; a
--      rejoin keeps both layouts and the label;
--   S  the switch: one swap of main[1..8] with the hidden list (wear and
--      metadata kept, empty slots too, main[9..] and the bags untouched), the
--      label, the shown layout a no-op, the anti-spam limit (0.25 s), the
--      callbacks before the swap, a failing callback changes nothing;
--   G  the guards: every move, put and take touching the hidden list is
--      refused, before equipment.lua (an equipment slot), bags.lua (a bag
--      slot, the quiver); give, fits, room_for, slot_order and the sort never
--      touch it; the soulbound rule counts it as carried (D3); a skill may
--      lie once per layout (bound_items.lua);
--   C  the consumers, by the study's numbers: a1/a2 crafting (count = take,
--      the inactive layout last), a4 ammunition, a5/a6 quests (counted and
--      taken last, rewards never into it), a7 the Claim Stone's activation
--      fuel, a8 the Fallen Crown, a9 the vendor's sell list (left out), a10
--      the repair quote (included), a12 holds_stone;
--   K  skills: normalize_kit keeps one copy per layout and cleans both; the
--      starter kit goes onto the shown layout (D1; that a talent unlock
--      places nothing is tools/r44_ts's, which runs grug_skills/page.lua);
--      the switch callback cancels input before the swap, ends the held
--      swing loop, flags the wield watcher, and the cooldown overlay follows
--      the skill to its slot on the new layout;
--   D  death and the map reset's player part leave both layouts alone;
--   U  the forms: the A/B buttons with the shown one marked in the full,
--      short and station views and the quickbar; a switch from an inventory
--      page, a node form (node_formspec), a chest and the quickbar re-shows
--      that form, keeps the bag view's scroll position, and a press within
--      the limit re-shows nothing. (The workspace, the Claim Stone form and
--      the mail's Write tab: tools/r491_view and tools/r48_mail, which own
--      those worlds.)
--
-- Usage (repo root): luajit tools/r50_hotbar/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)
local I = grug_inventory

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
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil, label)
end
local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end
local noop = function() end

--
-- The fake engine beyond the harness: stack metadata (the harness's stacks
-- carry name, count and wear), the rest of the InvRef surface, a clock.
--

local Stack = getmetatable(ItemStack("")).__index
local base_stack = ItemStack
function ItemStack(item)
	local stack = base_stack(item)
	if type(item) == "table" and item.fields then
		stack.fields = {}
		for key, value in pairs(item.fields) do stack.fields[key] = value end
	end
	return stack
end
local function meta_of(fields)
	return {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return math.floor(tonumber(fields[key]) or 0) end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
		get_keys = function()
			local keys = {}
			for key in pairs(fields) do keys[#keys + 1] = key end
			return keys
		end,
	}
end
function Stack:get_meta()
	self.fields = self.fields or {}
	return meta_of(self.fields)
end
function Stack:set_wear(wear) self.wear = wear end
local base_to_string = Stack.to_string
function Stack:to_string()
	local text = base_to_string(self)
	if text == "" then return "" end
	if self.wear and self.wear > 0 then text = text .. " wear=" .. self.wear end
	local keys = {}
	for key in pairs(self.fields or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do text = text .. " " .. key .. "=" .. self.fields[key] end
	return text
end
function Stack:equals(other) return self:to_string() == ItemStack(other):to_string() end
function Stack:get_short_description() return self.name end
local base_set_count = Stack.set_count
function Stack:set_count(n)
	base_set_count(self, n)
	if self.count <= 0 then self.fields = nil end
end

local clock = 1000000
core.get_us_time = function() return clock end
local function wait(seconds) clock = clock + math.floor(seconds * 1e6) end

local registered_nodes = {}
core.registered_nodes = registered_nodes
local dieplayer = {}
core.register_on_dieplayer = function(fn) dieplayer[#dieplayer + 1] = fn end
local shown = {}
core.show_formspec = function(name, formname, formspec)
	shown[#shown + 1] = {name = name, form = formname, formspec = formspec}
end
core.close_formspec = function(name, formname) core.show_formspec(name, formname, "") end
local players = {}
core.get_player_by_name = function(name) return players[name] end
core.override_item = function(name, fields)
	local def = core.registered_items[name] or registered_nodes[name]
	for k, v in pairs(fields) do def[k] = v end
end
core.serialize = function() return "return {}" end
core.deserialize = function() return nil end
core.get_node_or_nil = function() return nil end
core.settings = {get = function() return nil end}

local function last_shown(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

-- Players through the harness, their inventory completed with the calls the
-- loaded files make.
local function player(name, class_id, bags)
	local p = H.player(name, class_id or "warrior", bags)
	local inv = p.inv
	function inv:get_lists()
		local out = {}
		for list in pairs(self.lists) do out[list] = self:get_list(list) end
		return out
	end
	function inv:contains_item(list, item)
		local name = ItemStack(item):get_name()
		for _, stack in ipairs(self.lists[list] or {}) do
			if stack:get_name() == name then return true end
		end
		return false
	end
	function inv:remove_item(list, item)
		local want = ItemStack(item)
		local name, left = want:get_name(), want:get_count()
		for _, stack in ipairs(self.lists[list] or {}) do
			if left > 0 and stack:get_name() == name then
				local take = math.min(left, stack:get_count())
				stack:set_count(stack:get_count() - take)
				left = left - take
			end
		end
		return ItemStack(name .. " " .. (want:get_count() - left))
	end
	function inv:get_location() return {type = "player", name = name} end
	local set_stack = inv.set_stack
	function inv:set_stack(list, index, stack) -- the engine answers true
		set_stack(self, list, index, stack)
		return true
	end
	function p:get_hp() return 20 end
	function p:get_wielded_item() return inv:get_stack("main", 1) end
	players[name] = p
	return p
end

local STORE = I.HOTBAR_STORE
local function at(p, list, index) return p.inv:get_stack(list, index):to_string() end
local function row(p, list, from, to)
	local out = {}
	for i = from or 1, to or 8 do out[#out + 1] = at(p, list, i) end
	return table.concat(out, "|")
end
local function fill(p, list, from, to, item)
	for i = from, to do p.inv:set_stack(list, i, ItemStack(item)) end
end
-- Every non-empty stack of the player's inventory, in list order: nothing
-- lost or duplicated when two snapshots agree.
local function census(p)
	local names = {}
	for list in pairs(p.inv.lists) do names[#names + 1] = list end
	table.sort(names)
	local out = {}
	for _, list in ipairs(names) do
		for i = 1, p.inv:get_size(list) do
			local text = at(p, list, i)
			if text ~= "" then out[#out + 1] = text end
		end
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function item(name, def)
	def.description = def.description or name
	def.stack_max = def.stack_max or 99
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("t:dirt", {})
item("t:stick", {})
item("t:coal_lump", {})
item("default:coal_lump", {})
item("grug_smelting:charcoal", {})
item("grug_mobs:fallen_crown", {stack_max = 16})
item("grug_abilities:strike", {stack_max = 1, groups = {grug_ability = 1, grug_bound_skill = 1}})
item("grug_abilities:loose", {stack_max = 1, groups = {grug_ability = 1, grug_bound_skill = 1}})
item("grug_abilities:sprint", {stack_max = 1, groups = {grug_ability = 1, grug_bound_skill = 1}})
item("grug_housing:claim_stone", {stack_max = 1, groups = {grug_soulbound = 1}})
registered_nodes["default:chest"] = {description = "Chest"}

--
-- J. Joins
--
do
	local p = player("j_old")
	-- An existing character from before 0.50.0: its hotbar, no hidden list.
	p.inv.lists[STORE] = nil
	p:get_meta():set_string(I.HOTBAR_LAYOUT_KEY, "")
	fill(p, "main", 1, 3, "t:dirt 5")
	p.inv:set_stack("main", 4, ItemStack("grug_abilities:strike"))
	fill(p, "main", 9, 10, "t:stick 7")
	local before = row(p, "main", 1, 32)
	H.join(p)
	eq(p.inv:get_size(STORE), 8, "J the hidden list has eight slots after the join")
	eq(row(p, STORE), "|||||||", "J B is empty")
	eq(row(p, "main", 1, 32), before, "J the hotbar and main[9..] are unchanged")
	eq(I.active_hotbar(p), "A", "J the hotbar is A")
	-- A rejoin with B shown and items on A keeps everything.
	check(I.switch_hotbar(p, "B"), "J a switch to B")
	local hidden, label = row(p, STORE), I.active_hotbar(p)
	H.join(p)
	eq(row(p, STORE), hidden, "J a rejoin keeps the hidden layout")
	eq(I.active_hotbar(p), label, "J a rejoin keeps the label")
	eq(I.active_hotbar(p), "B", "J ...B")
end

--
-- S. The switch
--
local switch_calls = {}
local fail_switch = false
I.register_on_hotbar_switch(function(p, layout)
	switch_calls[#switch_calls + 1] = {name = p:get_player_name(), layout = layout,
		first = at(p, "main", 1), label = I.active_hotbar(p)}
	if fail_switch then error("a failing switch callback") end
end)
do
	local p = player("s_swap", "warrior", {16})
	wait(1)
	local sword = ItemStack("grug_gear:sword_bronze")
	sword:set_wear(1234)
	sword:get_meta():set_string("grug_quality", "3")
	p.inv:set_stack("main", 1, sword)
	p.inv:set_stack("main", 2, ItemStack("t:dirt 17"))
	p.inv:set_stack("main", 5, ItemStack("grug_abilities:strike"))
	fill(p, "main", 9, 32, "t:stick 3")
	fill(p, "grug_bag1_content", 1, 16, "t:dirt 2")
	local a_row = row(p, "main")
	local rest, bag = row(p, "main", 9, 32), row(p, "grug_bag1_content", 1, 16)
	local total = census(p)
	switch_calls = {}
	check(I.switch_hotbar(p, "B"), "S A -> B switches")
	eq(row(p, "main"), "|||||||", "S B is empty on the hotbar")
	eq(row(p, STORE), a_row, "S A waits in the hidden list, slot for slot")
	has(at(p, STORE, 1), "wear=1234", "S the sword's wear is kept")
	has(at(p, STORE, 1), "grug_quality=3", "S the sword's metadata is kept")
	eq(I.active_hotbar(p), "B", "S the label says B")
	eq(row(p, "main", 9, 32), rest, "S main[9..] is untouched")
	eq(row(p, "grug_bag1_content", 1, 16), bag, "S the bag is untouched")
	eq(census(p), total, "S nothing lost or duplicated")
	eq(#switch_calls, 1, "S the switch callbacks ran once")
	eq(switch_calls[1] and switch_calls[1].first, at(p, STORE, 1),
		"S ...before the swap (main[1] was still A's sword)")
	eq(switch_calls[1] and switch_calls[1].label, "A", "S ...and before the label changed")
	-- B gets its own items; the limit, the no-op, the way back.
	p.inv:set_stack("main", 3, ItemStack("t:coal_lump 4"))
	check(not I.switch_hotbar(p, "B"), "S the shown layout: no switch")
	wait(0.1)
	check(not I.switch_hotbar(p, "A"), "S 0.1 s later: refused (anti-spam)")
	eq(I.active_hotbar(p), "B", "S ...still B")
	wait(0.15)
	check(I.switch_hotbar(p, "A"), "S 0.25 s after the switch: allowed")
	eq(row(p, "main"), a_row, "S A is back, slot for slot, wear and metadata included")
	eq(row(p, STORE), "||t:coal_lump 4|||||", "S B's coal waits in the hidden list")
	check(not I.switch_hotbar(p, "C"), "S an unknown layout: nothing")
	-- A failing callback stops the switch before any write.
	wait(1)
	local frozen, frozen_hidden = row(p, "main"), row(p, STORE)
	fail_switch = true
	local ok = pcall(I.switch_hotbar, p, "B")
	fail_switch = false
	check(not ok, "S the failing callback raised")
	eq(row(p, "main"), frozen, "S ...the hotbar unchanged")
	eq(row(p, STORE), frozen_hidden, "S ...the hidden list unchanged")
	eq(I.active_hotbar(p), "A", "S ...the label unchanged")
	-- Rapid clicking: about four switches a second at most.
	wait(1)
	local before_clicks = census(p)
	local switched = 0
	for _ = 1, 20 do
		if I.switch_hotbar(p, I.active_hotbar(p) == "A" and "B" or "A") then
			switched = switched + 1
		end
		wait(0.05)
	end
	eq(switched, 4, "S 20 clicks in one second switch four times")
	eq(census(p), before_clicks, "S rapid switching keeps every stack")
end

--
-- G. The guards
--
do
	local p = player("g_scout", "scout", {16})
	local bow, bag = "grug_gear:bow_bronze", "grug_inventory:bag_small"
	wait(1)
	p.inv:set_stack("main", 1, ItemStack(bow))
	p.inv:set_stack("main", 2, ItemStack(bag))
	p.inv:set_stack("main", 3, ItemStack("grug_gear:arrow 40"))
	check(I.switch_hotbar(p, "B"), "G the bow, a bag and arrows go to the hidden list")
	local hidden, total = row(p, STORE), census(p)
	-- Moves out of it: into main, an equipment slot (equipment.lua would
	-- allow one item), a bag slot (bags.lua would allow a bag), the quiver
	-- (bags.lua would absorb the arrows itself).
	eq(H.move(p, STORE, 1, "main", 9), 0, "G hidden -> main: refused")
	eq(H.move(p, STORE, 1, "grug_weapon", 1), 0, "G hidden -> the weapon slot: refused")
	p.inv:set_stack("main", 10, ItemStack(bow))
	eq(H.allow(p, "move", {from_list = "main", from_index = 10, to_list = "grug_weapon",
		to_index = 1, count = 1}), 1, "G control: from main, equipment.lua allows the bow")
	p.inv:set_stack("main", 10, ItemStack(""))
	eq(H.move(p, STORE, 2, "grug_bag2", 1), 0, "G hidden -> a bag slot: refused")
	eq(H.move(p, STORE, 3, I.QUIVER_LIST, 1), 0, "G hidden -> the quiver: refused")
	eq(I.quiver_count(p), 0, "G ...no arrow reached the quiver")
	p.inv:set_stack("main", 9, ItemStack("t:dirt 3"))
	eq(H.move(p, "main", 9, STORE, 4), 0, "G main -> hidden: refused")
	eq(H.allow(p, "put", {listname = STORE, index = 4, stack = ItemStack("t:dirt")}), 0,
		"G a put into the hidden list: refused")
	eq(H.allow(p, "take", {listname = STORE, index = 1, stack = ItemStack(bow)}), 0,
		"G a take (drop) from the hidden list: refused")
	eq(H.allow(p, "move", {from_list = "main", from_index = 9, to_list = "main",
		to_index = 10, count = 3}), nil, "G the guard leaves other moves to the others")
	eq(row(p, STORE), hidden, "G the hidden list is unchanged")
	p.inv:set_stack("main", 9, ItemStack(""))
	eq(census(p), total, "G nothing lost or duplicated")
	-- The give order never reaches it; the sort never touches it.
	fill(p, "main", 1, 32, "t:stick 99")
	fill(p, "grug_bag1_content", 1, 16, "t:stick 99")
	eq(I.give(p, ItemStack("t:dirt 5")):to_string(), "t:dirt 5",
		"G a full inventory: give leaves all of it over (B's free slots stay free)")
	check(not I.fits(p, {ItemStack("t:dirt")}), "G fits: no room")
	eq(I.room_for(p, ItemStack("t:dirt 5")), 0, "G room_for: 0")
	for _, slot in ipairs(I.slot_order(p.inv)) do
		check(slot.list ~= STORE, "G slot_order leaves the hidden list out")
	end
	p.inv:set_stack("main", 20, ItemStack("t:dirt 1"))
	I.sort(p)
	eq(row(p, STORE), hidden, "G the sort leaves the hidden list as it is")
	eq(table.concat(I.carried_lists(p.inv), ","), "main,grug_bag1_content",
		"G carried_lists: main and the bags, not the hidden list")
	eq(table.concat(I.consume_lists(p.inv), ","), "main,grug_bag1_content," .. STORE,
		"G consume_lists: the hidden list last")
end

-- The soulbound rule (grug_housing/soulbound.lua, D3): the hidden list is a
-- carried list; the hotbars guard still refuses moving it there by hand.
local soulbound_allow
do
	local register = core.register_allow_player_inventory_action
	core.register_allow_player_inventory_action = function(fn)
		soulbound_allow = fn
		register(fn)
	end
	grug_housing = {}
	dofile(repo .. "/mods/PLAYER/grug_housing/soulbound.lua")
	core.register_allow_player_inventory_action = register
	local p = player("g_stone")
	wait(1)
	p.inv:set_stack("main", 1, ItemStack("grug_housing:claim_stone"))
	p.inv:set_stack("main", 9, ItemStack("grug_housing:claim_stone"))
	local info = {from_list = "main", from_index = 9, to_list = STORE, to_index = 2, count = 1}
	eq(soulbound_allow(p, "move", p.inv, info), nil,
		"G soulbound: the hidden list counts as carried")
	eq(soulbound_allow(p, "move", p.inv, {from_list = "main", from_index = 9,
		to_list = "craft", to_index = 1, count = 1}), 0, "G soulbound: the craft grid does not")
	eq(H.allow(p, "move", info), 0, "G ...a hand move into the hidden list is still refused")
	check(I.switch_hotbar(p, "B"), "G a switch carries the stone on the hotbar along")
	eq(at(p, STORE, 1), "grug_housing:claim_stone", "G ...into the hidden list")
end

--
-- C. The consumers (the study's a-numbers): today's order, the inactive
-- layout last, counting and taking alike.
--

-- Put `items` ({list, index, item}) on a fresh player whose hidden list is B
-- (A shown), so the hidden stacks are the inactive layout.
local consumer_serial = 0
local function consumer(class_id, bags, items)
	consumer_serial = consumer_serial + 1
	local p = player("c" .. consumer_serial, class_id or "warrior", bags)
	for _, entry in ipairs(items) do
		p.inv:set_stack(entry[1], entry[2], ItemStack(entry[3]))
	end
	return p
end

-- a4: ammunition, quiver -> main (the hotbar first) -> the bags -> B.
do
	local p = consumer("scout", {16}, {
		{I.QUIVER_LIST, 1, "grug_gear:arrow 3"}, {"main", 12, "grug_gear:arrow 2"},
		{"main", 2, "grug_gear:arrow 1"}, {"grug_bag1_content", 4, "grug_gear:arrow 2"},
		{STORE, 6, "grug_gear:arrow 5"}})
	eq(I.ammo_count(p), 13, "C a4 the count includes B")
	check(I.consume_ammo(p, 9), "C a4 a nine-arrow shot")
	eq(I.quiver_count(p), 0, "C a4 the quiver first")
	eq(at(p, "main", 2) .. at(p, "main", 12), "", "C a4 then main (the hotbar first)")
	eq(at(p, "grug_bag1_content", 4), "", "C a4 then the bag")
	eq(at(p, STORE, 6), "grug_gear:arrow 4", "C a4 B last: one of five taken")
	check(not I.consume_ammo(p, 5), "C a4 more than counted: refused")
	eq(at(p, STORE, 6), "grug_gear:arrow 4", "C a4 ...nothing taken")
	check(I.consume_ammo(p, 4), "C a4 exactly the count")
	eq(I.ammo_count(p), 0, "C a4 count and take agree")
end

-- a1/a2/a3: crafting ingredients (grug_jobs/jobs.lua): the bags, main[9..],
-- the hotbar, B last; ×N counts what the take finds.
grug_core.item_name = function(name) return tostring(name) end
grug_items = {crafted_output = function() return false end}
grug_jobs = {}
do
	core.get_modpath = function(name) return repo .. "/mods/PLAYER/" .. (name or "grug_inventory") end
	dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/jobs.lua")
	local recipe = grug_jobs.register_recipe({area = "basic", output = "t:coal_lump",
		ingredients = {{item = "t:stick", n = 4}}})
	local p = consumer("warrior", {16}, {
		{"grug_bag1_content", 1, "t:stick 2"}, {"main", 10, "t:stick 2"},
		{"main", 3, "t:stick 3"}, {STORE, 2, "t:stick 5"}})
	local counts = grug_jobs.ingredient_counts(p)
	eq(counts.items["t:stick"], 12, "C a1 the count includes B")
	eq(grug_jobs.crafts_from_counts(counts, recipe), 3, "C a3 ×N = 3 with B")
	local consumed = grug_jobs.take_ingredients(p, recipe.ingredients, 2)
	check(consumed ~= nil, "C a2 two crafts' worth taken")
	eq(at(p, "grug_bag1_content", 1) .. at(p, "main", 10), "", "C a2 the bag, then main[9..]")
	eq(at(p, "main", 3), "", "C a2 then the hotbar")
	eq(at(p, STORE, 2), "t:stick 4", "C a2 B last: one of five taken")
	eq(grug_jobs.crafts_from_counts(grug_jobs.ingredient_counts(p), recipe), 1,
		"C a3 the rest makes one more")
	check(grug_jobs.take_ingredients(p, recipe.ingredients, 1) ~= nil, "C a2 ...and it is taken")
	eq(at(p, STORE, 2), "", "C a2 count and take agree")
end

-- a5/a6: quest items (grug_quests/state.lua): counted with B, taken from
-- main[9..], the bags, the hotbar, B last; rewards never land on B.
function table.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end
do
	grug_quests = {}
	grug_xp.quest_reward = function() return 10 end
	grug_xp.add_xp = noop
	grug_money.MAX, grug_money.add = 10 ^ 9, noop
	grug_core.feed_item = noop
	grug_mobs.register_participant_drop_hook = noop
	grug_mobs.register_on_eligible_kill = noop
	dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/state.lua")
	local Q = grug_quests
	Q.quest_text = function(def) return def.description end -- labels.lua's
	Q.register_npc("elder", {settlement = "town", socket = "quest_1", title = "Elder"})
	Q.register_quest("dirt", {npc = "elder", title = "Dirt", description = "Bring dirt.",
		objectives = {{type = "item", item = "t:dirt", count = 6}},
		rewards = {weight = 1, items = {"t:coal_lump 2"}}})
	Q.register_quest("dirt_again", {npc = "elder", title = "More dirt", description = "Bring dirt.",
		objectives = {{type = "item", item = "t:dirt", count = 2}},
		rewards = {weight = 1, items = {"t:coal_lump 2"}}})
	local p = consumer("warrior", {16}, {
		{"main", 9, "t:dirt 2"}, {"grug_bag1_content", 1, "t:dirt 1"},
		{"main", 2, "t:dirt 1"}, {STORE, 3, "t:dirt 4"}})
	check(Q.accept(p, "dirt"), "C a5 the quest is accepted")
	local journal = Q.journal(p)
	eq(journal.quests[1] and journal.quests[1].objectives[1].count, 6,
		"C a5 progress counts B's dirt (2 + 1 + 1 + 2 of 4)")
	eq(journal.quests[1] and journal.quests[1].ready, true, "C a5 ready to turn in")
	local turned, why = Q.turn_in(p, "dirt")
	check(turned, "C a6 the turn-in succeeds (" .. tostring(why) .. ")")
	eq(at(p, "main", 2), "", "C a6 the hotbar's dirt is taken (before B)")
	eq(at(p, "grug_bag1_content", 1), "", "C a6 the bag's dirt is taken")
	eq(at(p, STORE, 3), "t:dirt 2", "C a6 B last: two of four taken")
	eq(at(p, "main", 9), "t:coal_lump 2", "C a6 the reward lands in main[9..]")
	-- Only B has free room: the reward is refused, B is never filled.
	fill(p, "main", 1, 32, "t:stick 99")
	fill(p, "grug_bag1_content", 1, 16, "t:stick 99")
	p.inv:set_stack(STORE, 5, ItemStack(""))
	check(Q.accept(p, "dirt_again"), "C a6 a second quest")
	local ok, message = Q.turn_in(p, "dirt_again")
	check(not ok, "C a6 no room outside B: the turn-in is refused")
	has(message, "Make room", "C a6 ...asking for room")
	eq(at(p, STORE, 3), "t:dirt 2", "C a6 ...and nothing is taken")
end

-- a7: the Claim Stone's activation fuel (grug_housing/api.lua over its real
-- registry model), the D section's map reset (grug_core/map_reset.lua) first.
local storage_data = {}
core.get_mod_storage = function()
	return {
		get_string = function(_, key) return storage_data[key] or "" end,
		set_string = function(_, key, value) storage_data[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return math.floor(tonumber(storage_data[key]) or 0) end,
		set_int = function(_, key, value) storage_data[key] = tostring(value) end,
		get_keys = function()
			local keys = {}
			for key in pairs(storage_data) do keys[#keys + 1] = key end
			return keys
		end,
	}
end
core.register_on_newplayer = noop
dofile(repo .. "/mods/CORE/grug_core/map_reset.lua")
do
	dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
	local p = consumer("warrior", {16}, {
		{"main", 9, "default:coal_lump 1"}, {"grug_bag1_content", 2, "grug_smelting:charcoal 1"},
		{"main", 4, "default:coal_lump 1"}, {STORE, 1, "default:coal_lump 3"},
		{STORE, 2, "grug_smelting:charcoal 2"}})
	grug_housing.model.create(p:get_player_name(), {x = 0, y = 0, z = 0})
	local ok, message = grug_housing.activate(p)
	check(ok, "C a7 activation with fuel on B (" .. tostring(message) .. ")")
	eq(at(p, "grug_bag1_content", 2) .. at(p, "main", 9) .. at(p, "main", 4), "",
		"C a7 the carried fuel first, charcoal and coal")
	eq(at(p, STORE, 2), "", "C a7 then B, charcoal first: both taken")
	eq(at(p, STORE, 1), "default:coal_lump 3", "C a7 ...B's coal stays (five lumps reached)")
	-- Not enough even with B: refused, nothing taken.
	local q = consumer("warrior", nil, {{"main", 9, "default:coal_lump 1"},
		{STORE, 1, "default:coal_lump 2"}})
	grug_housing.model.create(q:get_player_name(), {x = 500, y = 0, z = 0})
	local refused, why = grug_housing.activate(q)
	check(not refused, "C a7 three lumps with B: refused")
	has(why, "you have 3", "C a7 ...the count includes B")
	eq(at(q, STORE, 1), "default:coal_lump 2", "C a7 ...nothing taken")
	-- a12: the stone on B counts as carried (the Steward's check).
	local s = consumer("warrior", nil, {{STORE, 4, "grug_housing:claim_stone"}})
	check(grug_housing.holds_stone(s), "C a12 a Claim Stone on B is held")
end

-- a8: the Fallen Crown (grug_traders/crown.lua): main, equipment, bags, then
-- B; the gear to crown comes from those lists, not from B.
do
	grug_traders = {}
	grug_items = grug_items or {}
	grug_items.crown_preview = function() return "Crowned preview" end
	grug_items.crown_item = function(stack)
		local copy = ItemStack(stack)
		copy:get_meta():set_string("crowned", "1")
		return copy, "Crowned preview"
	end
	grug_money.take_with_inventory = function(p, _, changes)
		for _, change in ipairs(changes) do
			if not p.inv:get_stack(change.list, change.index):equals(change.expected) then
				return false, "changed"
			end
		end
		for _, change in ipairs(changes) do
			p.inv:set_stack(change.list, change.index, change.replacement)
		end
		return true
	end
	dofile(repo .. "/mods/ENTITIES/grug_traders/crown.lua")
	local p = consumer("warrior", {16}, {{"main", 9, "grug_gear:sword_bronze"},
		{"grug_bag1_content", 3, "grug_mobs:fallen_crown 1"}, {STORE, 1, "grug_mobs:fallen_crown 2"},
		{STORE, 2, "grug_gear:sword_steel"}})
	local rows = grug_traders.crown_rows(p)
	eq(#rows, 1, "C a8 one row: B's sword is not offered")
	eq(rows[1] and rows[1].list, "main", "C a8 ...the sword in main")
	check(grug_traders.crown_apply(p, rows[1]), "C a8 crowned")
	eq(at(p, "grug_bag1_content", 3), "", "C a8 the bag's crown first")
	eq(at(p, STORE, 1), "grug_mobs:fallen_crown 2", "C a8 B's crowns stay")
	p.inv:set_stack("main", 10, ItemStack("grug_gear:sword_bronze"))
	rows = grug_traders.crown_rows(p)
	local row_10
	for _, r in ipairs(rows) do if r.index == 10 then row_10 = r end end
	check(row_10 and grug_traders.crown_apply(p, row_10), "C a8 a second item: crowned")
	eq(at(p, STORE, 1), "grug_mobs:fallen_crown", "C a8 ...with a crown from B last")
end

-- a9: the vendor's sell rows (cut out of grug_traders/trade.lua) read the
-- carried lists: B is left out.
do
	local src = read("mods/ENTITIES/grug_traders/trade.lua")
	local block = src:match("\n(local function current_rows%(player%).-\n\treturn rows\nend)\n")
	check(block ~= nil, "C a9 current_rows found in trade.lua")
	grug_traders.stack_sell_price = function(stack)
		return stack:get_name() == "t:stick" and 3 or 0
	end
	grug_traders.sell_offer = function() return 0, 1 end
	local current_rows = assert(loadstring((block or "") .. "\nreturn current_rows", "=rows"))()
	local p = consumer("warrior", nil, {{"main", 9, "t:stick 5"}, {"main", 2, "t:stick 1"},
		{STORE, 1, "t:stick 7"}})
	local rows = current_rows(p)
	local lists = {}
	for _, r in ipairs(rows) do lists[#lists + 1] = r.list .. "#" .. r.index end
	eq(table.concat(lists, ","), "main#2,main#9", "C a9 main's sticks are offered, B's are not")
end

-- a10: the repair quote (grug_repair/service.lua) includes B.
do
	grug_repair = {}
	grug_gear.reference_purchase_price = function() return 1000 end
	grug_repair.refresh_stack = noop
	dofile(repo .. "/mods/ITEMS/grug_repair/service.lua")
	grug_repair.register_provider("test", function() return true end)
	local worn = ItemStack("grug_gear:sword_bronze")
	worn:set_wear(32768)
	local p = consumer("warrior", nil, {{STORE, 5, worn:to_string()}})
	p.inv:set_stack(STORE, 5, worn)
	local quote = grug_repair.quote(p, {kind = "test"})
	eq(quote and #quote.items, 1, "C a10 the worn sword on B is quoted")
	eq(quote and quote.items[1] and quote.items[1].list, STORE, "C a10 ...from the hidden list")
	check(quote and grug_repair.apply(p, quote), "C a10 the repair is applied")
	eq(p.inv:get_stack(STORE, 5):get_wear(), 0, "C a10 ...B's sword is repaired in place")
end

-- a11: the skill guard (grug_skills/bound_items.lua): one copy per layout.
do
	grug_skills = {}
	grug_abilities = grug_abilities or {}
	grug_abilities.is_unlocked = function() return true end
	grug_mounts = grug_mounts or {owns_tier = function() return false end}
	dofile(repo .. "/mods/PLAYER/grug_skills/bound_items.lua")
	local strike = ItemStack("grug_abilities:strike")
	local p = consumer("warrior", nil, {{STORE, 1, "grug_abilities:strike"}})
	local put = {listname = "main", index = 3, stack = strike}
	eq(H.allow(p, "put", put), nil, "C a11 Strike on B: a copy may go onto A's slot 3")
	p.inv:set_stack("main", 6, strike)
	eq(H.allow(p, "put", put), 0, "C a11 a second copy on the shown layout: refused")
	eq(H.allow(p, "move", {from_list = "main", from_index = 6, to_list = STORE, to_index = 2,
		count = 1}), 0, "C a11 a skill into the hidden list by hand: refused")
	eq(H.allow(p, "move", {from_list = "main", from_index = 6, to_list = "main", to_index = 12,
		count = 1}), 0, "C a11 a skill into main[9..]: refused (bound_items)")
end

--
-- K. Skills: grug_abilities/init.lua's kit normalisation, initial kit and
-- switch callback, cut out of the file and run against the real inventory.
--
local abilities_src = read("mods/PLAYER/grug_abilities/init.lua")
local function cut(pattern, label)
	local block = abilities_src:match(pattern)
	check(block ~= nil, "K " .. label .. " found in grug_abilities/init.lua")
	return block or ""
end
local unlocked = {strike = true, sprint = true, loose = true}
local item_defs = {}
for id in pairs(unlocked) do item_defs["grug_abilities:" .. id] = {id = id} end
grug_abilities.is_unlocked = function(_, id) return unlocked[id] == true end
grug_abilities.stack_for = function(_, id)
	return unlocked[id] and ItemStack("grug_abilities:" .. id) or nil
end
grug_abilities.registered = {strike = {id = "strike"}, sprint = {id = "sprint"},
	loose = {id = "loose"}}
grug_abilities.unlocked_ids = function()
	local out = {}
	for _, id in ipairs({"strike", "sprint", "loose"}) do
		if unlocked[id] then out[#out + 1] = id end
	end
	return out
end
local lists_block = table.concat({
	cut("\n(local function active_lists%(%).-\nend)\n", "active_lists"),
	cut("\n(local function representation_lists%(%).-\nend)\n", "representation_lists"),
}, "\n")
assert(loadstring(table.concat({"local item_defs, equipment_list = ...", lists_block,
	cut("\n(local function allowed_storage%(listname%).-\nend)\n", "allowed_storage"),
	cut("\n(function grug_abilities%.normalize_kit%(player%).-\nend)\n", "normalize_kit"),
}, "\n"), "=normalize"))(item_defs, {})
local grant_initial_kit = assert(loadstring(table.concat({lists_block,
	cut("\n(local META_INITIAL_KIT = .-\n)\n", "META_INITIAL_KIT"),
	cut("\n(local function insert_initial_ability%(.-\nend)\n", "insert_initial_ability"),
	cut("\n(local function place_on_hotbar%(.-\nend)\n\ngrug_classes%.register_on_class_chosen",
		"the kit block"),
	"return grant_initial_kit",
}, "\n"), "=kit"))()
do
	-- One copy per layout; both layouts cleaned at once.
	local p = consumer("warrior", nil, {{"main", 1, "grug_abilities:strike"},
		{"main", 2, "grug_abilities:loose"}, {STORE, 1, "grug_abilities:strike"},
		{STORE, 4, "grug_abilities:strike"}, {STORE, 2, "grug_abilities:loose"},
		{STORE, 3, "grug_abilities:sprint"}, {"main", 7, "grug_abilities:strike"}})
	grug_abilities.normalize_kit(p)
	eq(at(p, "main", 1), "grug_abilities:strike", "K Strike on A stays")
	eq(at(p, STORE, 1), "grug_abilities:strike", "K Strike on B stays too (one per layout)")
	eq(at(p, STORE, 4), "", "K a second Strike on B goes")
	eq(at(p, "main", 7), "", "K a second Strike on A goes")
	unlocked.loose = false
	grug_abilities.normalize_kit(p)
	eq(at(p, "main", 2) .. at(p, STORE, 2), "", "K a lost skill goes from both layouts")
	eq(at(p, STORE, 3), "grug_abilities:sprint", "K the other skills on B stay")
	unlocked.loose = true
	-- D1: a new character's kit goes onto the shown layout A; B stays empty.
	local fresh = player("k_fresh")
	fresh.inv:set_stack("main", 7, ItemStack("default:apple 10"))
	grant_initial_kit(fresh)
	eq(row(fresh, "main", 1, 3), "grug_abilities:strike|grug_abilities:sprint|grug_abilities:loose",
		"K a new character: the kit on A")
	eq(row(fresh, STORE), "|||||||", "K ...B empty")
	-- A class choice with B shown: the kit onto B, A (hidden) untouched.
	wait(1)
	check(I.switch_hotbar(fresh, "B"), "K switch to B")
	local a_row = row(fresh, STORE)
	grant_initial_kit(fresh)
	eq(row(fresh, "main", 1, 3), "grug_abilities:strike|grug_abilities:sprint|grug_abilities:loose",
		"K a kit grant with B shown fills B (A's copies do not count)")
	eq(row(fresh, STORE), a_row, "K ...A untouched")
end

-- The switch callback: cancels input, ends the swing loop, flags the wield
-- watcher and the cooldown overlay (the real cooldown_hud.lua).
do
	local mod = repo .. "/mods/PLAYER/grug_abilities/"
	local window = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	local hud = dofile(mod .. "cooldown_hud.lua")({math = dofile(mod .. "cooldown_math.lua"),
		ability_of = function(name) return name:match("^grug_abilities:(.+)$") end})
	hud.window_info = function() return window end
	local cancels, boundaries, dirty = {}, {}, {}
	grug_abilities.input = {cancel = function(p) cancels[#cancels + 1] = at(p, "main", 1) end}
	local reset_swing_boundary = function(p) boundaries[#boundaries + 1] = p:get_player_name() end
	assert(loadstring("local reset_swing_boundary, dirty, cooldown_hud = ...\n" ..
		cut("\n(grug_inventory%.register_on_hotbar_switch%(function%(player%).-\nend%))\n",
			"the switch callback"), "=switch"))(reset_swing_boundary, dirty, hud)
	local p = consumer("warrior", nil, {{"main", 1, "grug_abilities:strike"},
		{STORE, 3, "grug_abilities:strike"}})
	local huds, next_id = {}, 0
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add(def)
		next_id = next_id + 1
		huds[next_id] = def
		return next_id
	end
	function p:hud_change(id, stat, value) huds[id][stat] = value end
	function p:hud_remove(id) huds[id] = nil end
	hud.track(p, "strike", {expiry = clock + 5e6, duration = 5}, clock)
	local function covered()
		local slots = {}
		for slot in pairs(hud.state(p:get_player_name()).shown) do slots[#slots + 1] = slot end
		table.sort(slots)
		return table.concat(slots, ",")
	end
	eq(covered(), "1", "K the cooldown covers Strike on A's slot 1")
	wait(1)
	check(I.switch_hotbar(p, "B"), "K switch to B mid-cooldown")
	eq(#cancels, 1, "K the switch cancelled input once")
	eq(cancels[1], "grug_abilities:strike", "K ...before the swap")
	eq(boundaries[1], p:get_player_name(), "K the held swing loop ends (due time kept)")
	eq(dirty[p:get_player_name()], true, "K the wield watcher reads the slot again")
	hud.update(p, clock)
	eq(covered(), "3", "K the cooldown follows: B's Strike on slot 3, same timer")
	hud.forget(p:get_player_name())
end

--
-- D. Death and the map reset's player part
--
do
	local p = consumer("warrior", nil, {{"main", 1, "t:dirt 3"}, {STORE, 2, "t:stick 4"},
		{STORE, 8, "grug_housing:claim_stone"}})
	p:get_meta():set_string(I.HOTBAR_LAYOUT_KEY, "B")
	local before = census(p)
	for _, fn in ipairs(dieplayer) do fn(p) end
	eq(census(p), before, "D death keeps both layouts (" .. #dieplayer .. " death callbacks)")
	grug_core.map_reset.relocated(p)
	eq(census(p), before, "D the map reset's relocation keeps both layouts")
	eq(I.active_hotbar(p), "B", "D ...and the label")
end

--
-- U. The forms
--
local receivers = {}
core.register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end
local function submit(p, formname, fields)
	for _, fn in ipairs(receivers) do
		if fn(p, formname, fields) then return true end
	end
	return false
end
local SCROLL = I.SCROLL_FIELDS
local function button(fs, layout)
	local x, y, w, h = fs:match("button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);" ..
		I.HOTBAR_FIELDS[layout] .. ";" .. layout .. "%]")
	return tonumber(x), tonumber(y), tonumber(w), tonumber(h)
end
local function marked(fs)
	local out = {}
	for _, layout in ipairs({"A", "B"}) do
		if fs:find("style[" .. I.HOTBAR_FIELDS[layout] .. ";bgcolor=#c8962f", 1, true) then
			out[#out + 1] = layout
		end
	end
	return table.concat(out, ",")
end
local function scroll_value(fs, field)
	return tonumber(fs:match("scrollbar%[[^%]]*;vertical;" .. field .. ";(%d+)%]"))
end

-- The views: the buttons right of the hotbar's slots, inside the Hotbar box.
do
	local p = player("u_views", "warrior", {16, 16})
	local context = sfinv.get_or_create_context(p)
	context.page = "grug_inventory:inventory"
	local full = sfinv.get_formspec(p, context)
	local hx, hy = full:match("list%[current_player;main;([%d.]+),([%d.]+);8,1;%]")
	hx, hy = tonumber(hx), tonumber(hy)
	local ax, ay, aw, ah = button(full, "A")
	local bx, by, bw, bh = button(full, "B")
	check(ax ~= nil and bx ~= nil, "U the full view has the A and B buttons")
	if ax and bx and hx then
		check(ax > hx + 8 * 1.25 - 0.25, "U the buttons right of the hotbar's last slot")
		eq(ax, bx, "U ...one above the other")
		check(ay >= hy - 0.001 and by + bh <= hy + 1 + 0.001, "U ...within the slot row's height")
		check(ax + aw <= I.LAYOUT.box_x + I.LAYOUT.box_w, "U ...inside the Hotbar box")
	end
	eq(marked(full), "A", "U A is marked")
	has(full, "tooltip[grug_hotbar_b;Switch to hotbar B]", "U B's tooltip")
	context.page = "grug_inventory:character"
	local short = sfinv.get_formspec(p, context)
	check(button(short, "A") ~= nil and button(short, "B") ~= nil, "U the short view too")
	local station = I.station_formspec(p, "", 1, {})
	check(button(station, "A") ~= nil and button(station, "B") ~= nil, "U the station view too")
end

-- An inventory page: the switch re-sends the page at its scroll position;
-- the page's own handler never sees the button.
do
	local p = player("u_page", "warrior", {32, 32})
	sfinv.set_page(p, "grug_inventory:inventory")
	local sent = p.sent
	wait(1)
	check(H.click(p, {grug_hotbar_b = "B", [SCROLL.full] = "VAL:20"}), "U the page switch is handled")
	eq(I.active_hotbar(p), "B", "U ...B shown")
	eq(p.sent, sent + 1, "U ...the page re-sent once")
	eq(marked(p.formspec), "B", "U ...B marked")
	eq(scroll_value(p.formspec, SCROLL.full), 20, "U ...at the kept scroll position")
	check(not H.click(p, {grug_hotbar_a = "A"}), "U a press within the limit: not handled")
	eq(p.sent, sent + 1, "U ...nothing re-sent")
	eq(I.active_hotbar(p), "B", "U ...still B")
end

-- A node form (default/node_formspec.lua: furnace, bookshelf, vessels shelf).
local nodes = {}
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
core.get_node_or_nil = function(pos)
	local name = nodes[key(pos)]
	return name and {name = name, param2 = 0} or nil
end
core.get_node = function(pos) return core.get_node_or_nil(pos) or {name = "air"} end
core.swap_node = function(pos, node) nodes[key(pos)] = node.name end
vector = vector or {}
vector.new = vector.new or function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
vector.equals = vector.equals or function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
vector.distance = vector.distance or function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
default = setmetatable({get_translator = function(text) return text end,
	can_interact_with_node = function() return true end}, {__index = function() return noop end})
dofile(repo .. "/mods/BASE/default/node_formspec.lua")
do
	local p = player("u_node", "warrior", {16, 16})
	local pos = {x = 1, y = 0, z = 0}
	nodes[key(pos)] = "t:shelf"
	registered_nodes["t:shelf"] = {}
	local builds = 0
	local function build(_, viewer, context)
		builds = builds + 1
		return I.station_formspec(viewer, "label[0.4,0.4;Shelf]", 1, context)
	end
	check(default.node_formspec.show(p, pos, build), "U the node form opens")
	wait(1)
	local count = #shown
	check(submit(p, default.node_formspec.formname,
		{grug_hotbar_b = "B", [SCROLL.station] = "VAL:20"}), "U node form: handled")
	eq(I.active_hotbar(p), "B", "U node form: B shown")
	eq(#shown, count + 1, "U node form: re-shown once")
	local again = last_shown("u_node")
	eq(again and again.form, default.node_formspec.formname, "U node form: the same form")
	eq(again and marked(again.formspec), "B", "U node form: B marked")
	eq(again and scroll_value(again.formspec, SCROLL.station), 20,
		"U node form: at the kept scroll position")
	submit(p, default.node_formspec.formname, {grug_hotbar_a = "A"})
	eq(#shown, count + 1, "U node form: a press within the limit re-shows nothing")
end

-- A chest (default/chests.lua).
do
	local register_node = core.register_node
	core.register_node = function(name, def) registered_nodes[name] = def end
	core.after = function(_, fn, ...) return fn(...) end
	core.sound_play = noop
	dofile(repo .. "/mods/BASE/default/chests.lua")
	core.register_node = register_node
	local p = player("u_chest", "warrior", {16, 16})
	local pos = {x = 2, y = 0, z = 0}
	nodes[key(pos)] = "default:chest"
	core.get_meta = function()
		return {get_string = function() return "" end, set_string = noop,
			get_inventory = function() return {set_size = noop} end}
	end
	local def = registered_nodes["default:chest"]
	def.on_rightclick(pos, {name = "default:chest", param2 = 0}, p)
	eq(last_shown("u_chest") and last_shown("u_chest").form, "default:chest", "U the chest opens")
	wait(1)
	local count = #shown
	submit(p, "default:chest", {grug_hotbar_b = "B", [SCROLL.station] = "VAL:10"})
	eq(I.active_hotbar(p), "B", "U chest: B shown")
	eq(#shown, count + 1, "U chest: re-shown once")
	local again = last_shown("u_chest")
	eq(again and again.form, "default:chest", "U chest: the chest form")
	eq(again and marked(again.formspec), "B", "U chest: B marked")
	eq(again and scroll_value(again.formspec, SCROLL.station), 10,
		"U chest: at the kept scroll position")
	submit(p, "default:chest", {grug_hotbar_a = "A"})
	eq(#shown, count + 1, "U chest: a press within the limit re-shows nothing")
	submit(p, "default:chest", {quit = "true"})
	eq(default.chest.open_chests.u_chest, nil, "U chest: the quit still closes the chest")
end

-- The quickbar (E).
do
	local presses = {}
	grug_keys = {register_on_press = function(key, fn) presses[key] = fn end}
	grug_mounts = {owned_tier_ids = function() return {} end, active = {}, TIERS = {},
		owns_tier = function() return false end}
	dofile(repo .. "/mods/PLAYER/grug_quickbar/init.lua")
	local p = player("u_quick")
	presses.aux1(p)
	local first = last_shown("u_quick")
	eq(first and first.form, grug_quickbar.FORMNAME, "U the quickbar opens")
	check(first and button(first.formspec, "A") ~= nil and button(first.formspec, "B") ~= nil,
		"U the quickbar has the A and B buttons")
	eq(first and marked(first.formspec), "A", "U ...A marked")
	wait(1)
	local count = #shown
	submit(p, grug_quickbar.FORMNAME, {grug_hotbar_b = "B"})
	eq(I.active_hotbar(p), "B", "U quickbar: B shown")
	eq(#shown, count + 1, "U quickbar: re-shown once (not closed)")
	eq(last_shown("u_quick").form, grug_quickbar.FORMNAME, "U quickbar: the quickbar again")
	eq(marked(last_shown("u_quick").formspec), "B", "U quickbar: B marked")
	submit(p, grug_quickbar.FORMNAME, {grug_hotbar_a = "A"})
	eq(#shown, count + 1, "U quickbar: a press within the limit re-shows nothing")
	H.home.pending = false
	submit(p, grug_quickbar.FORMNAME, {grug_quickbar_home = "Return home"})
	eq(H.home.pending, true, "U quickbar: still open, a later click acts")
	eq(last_shown("u_quick").formspec, "", "U quickbar: ...and closes it")
end

if failures > 0 then
	error(("R50 HOTBAR PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R50 HOTBAR PORTABLE PASS checks=%d"):format(checks))
