-- Round 49 lane INV portable test (LuaJIT; round49-gameplay-draft.md rulings
-- 3, 4 and 10). Loads the REAL grug_inventory/storage.lua (the give helper,
-- the fit check, the sort), grug_housing api.lua (over its real registry
-- model and an in-memory mod storage) and soulbound.lua, and cuts the
-- starter kit out of grug_factions/init.lua and place_on_hotbar out of
-- grug_abilities/init.lua, under a small engine stub:
--   A. the Claim Stone into `main` and each bag's content list (move and
--      put), refused by every other player list, a chest and a detached
--      inventory;
--   B. the give helper treats it like any other item (main[9..], then a
--      bag); the sort keeps it in the bag;
--   C. the Steward's model per case (can_receive_stone): below level 20, a
--      stone carried in main or in a bag, a placed stone, none (the button);
--      a full inventory keeps the button and issue_stone refuses; after a
--      hand-out the reason "You already carry a Claim Stone.";
--   D. the starter kit: apples on hotbar 7, torches on 8; a taken slot
--      leaves the supply to the give helper;
--   E. a granted skill on a full hotbar: the rightmost non-skill item moves
--      into the inventory and the skill takes its slot; skills never move;
--      with no room anywhere nothing moves. Nothing is lost or duplicated.
--
--   luajit tools/r49_inv/portable_test.lua [REPO]
-- Prints "R49 INV PORTABLE PASS checks=<n>", or the failures and raises.

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
local function read(path)
	local file = assert(io.open(ROOT .. "/" .. path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end

------------------------------------------------------------------------------
-- Engine surface: stacks (name, count, stack_max), inventories, callbacks.
------------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack
function ItemStack(value)
	local name, count = "", 0
	if type(value) == "table" then
		name, count = value.name or "", value.count or 1
	elseif type(value) == "string" and value ~= "" then
		local n, c = value:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	end
	return setmetatable({name = name, count = count}, Stack)
end
function Stack:is_empty() return self.name == "" or self.count <= 0 end
function Stack:get_name() return self:is_empty() and "" or self.name end
function Stack:get_count() return self.count end
function Stack:set_count(n) self.count = n end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_meta()
	return {get_int = function() return 0 end, get_string = function() return "" end}
end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:to_string()
	if self:is_empty() then return "" end
	return self.count == 1 and self.name or self.name .. " " .. self.count
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack({name = self.name, count = n})
	self.count = self.count - n
	if self.count <= 0 then self.name, self.count = "", 0 end
	return taken
end
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		local moved = math.min(other.count, other:get_stack_max())
		self.name, self.count = other.name, moved
		other.count = other.count - moved
		return other.count > 0 and other or ItemStack("")
	end
	if other.name ~= self.name then return other end
	local moved = math.min(other.count, self:get_stack_max() - self.count)
	self.count = self.count + moved
	other.count = other.count - moved
	return other.count > 0 and other or ItemStack("")
end

local function new_inventory()
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old, new = self.lists[list] or {}, {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_size(list) return self.lists[list] and #self.lists[list] or 0 end
	function inv:get_stack(list, index)
		return ItemStack(self.lists[list] and self.lists[list][index] or "")
	end
	function inv:set_stack(list, index, stack) self.lists[list][index] = ItemStack(stack) end
	function inv:get_list(list)
		if not self.lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(self.lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_lists()
		local out = {}
		for name in pairs(self.lists) do out[name] = self:get_list(name) end
		return out
	end
	function inv:contains_item(list, item)
		local name = ItemStack(item):get_name()
		for _, stack in ipairs(self.lists[list] or {}) do
			if stack:get_name() == name then return true end
		end
		return false
	end
	function inv:is_empty(list)
		for _, stack in ipairs(self.lists[list] or {}) do
			if not stack:is_empty() then return false end
		end
		return true
	end
	return inv
end

local allow_player, mods_loaded = {}, {}
local storage_data = {}
core = {
	registered_items = {}, registered_nodes = {}, detached_inventories = {},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(fn) allow_player[#allow_player + 1] = fn end,
	register_on_player_inventory_action = function() end,
	register_on_joinplayer = function() end,
	register_on_item_pickup = function() end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do core.registered_items[name][key] = value end
	end,
	create_detached_inventory = function(name, callbacks)
		core.detached_inventories[name] = callbacks
		return {}
	end,
	get_modpath = function(name)
		assert(name == "grug_housing")
		return ROOT .. "/mods/PLAYER/grug_housing"
	end,
	get_mod_storage = function()
		return {
			get_string = function(_, key) return storage_data[key] or "" end,
			set_string = function(_, key, value) storage_data[key] = value ~= "" and value or nil end,
			get_keys = function()
				local keys = {}
				for key in pairs(storage_data) do keys[#keys + 1] = key end
				return keys
			end,
		}
	end,
	log = function() end,
	strip_colors = function(text) return text end,
}
local function item(name, def)
	def.name = name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
local function node(name, def)
	item(name, def)
	core.registered_nodes[name] = def
end
local STONE = "grug_housing:claim_stone"
node(STONE, {description = "Claim Stone", stack_max = 1, groups = {grug_soulbound = 1}})
node("default:chest", {description = "Chest"})
item("default:apple", {description = "Apple"})
item("default:torch", {description = "Torch"})
item("t:sword", {description = "Sword", stack_max = 1, groups = {grug_equip_weapon = 1}})
item("t:pick", {description = "Pick", stack_max = 1})
item("grug_abilities:strike", {description = "Strike", stack_max = 1,
	groups = {grug_ability = 1, grug_bound_skill = 1}})
item("grug_abilities:loose", {description = "Loose", stack_max = 1,
	groups = {grug_ability = 1, grug_bound_skill = 1}})

-- grug_inventory: the bag list names (bags.lua) and the REAL storage.lua.
grug_gear = {initialize_weapon_tooltip = function() end}
grug_inventory = {BAG_COUNT = 4}
function grug_inventory.content_list(i) return "grug_bag" .. i .. "_content" end
function grug_inventory.add_to_quiver(_, stack) return stack end
function grug_inventory.has_quiver() return false end
dofile(ROOT .. "/mods/PLAYER/grug_inventory/storage.lua")
local I = grug_inventory

-- grug_housing: the REAL api.lua (registry model) and soulbound.lua.
grug_core = {map_reset = {clear = function() end}}
grug_xp = {get_level = function(player) return player.level end}
grug_housing = {}
dofile(ROOT .. "/mods/PLAYER/grug_housing/api.lua")
dofile(ROOT .. "/mods/PLAYER/grug_housing/soulbound.lua")
for _, fn in ipairs(mods_loaded) do fn() end
local H = grug_housing

local BAGS = {"grug_bag1_content", "grug_bag2_content", "grug_bag3_content",
	"grug_bag4_content"}
local function new_player(name, level, bag_sizes)
	local inv = new_inventory()
	inv:set_size("main", 32)
	inv:set_size("craft", 9)
	for i = 1, 4 do
		inv:set_size("grug_bag" .. i, 1)
		inv:set_size(BAGS[i], bag_sizes and bag_sizes[i] or 0)
	end
	for _, list in ipairs({"grug_potion_belt", "grug_quiver_content", "grug_mail_out",
			"grug_inbox", "grug_equip_offhand", "grug_equip_chest"}) do
		inv:set_size(list, 4)
	end
	return {level = level or 1, inv = inv,
		is_player = function() return true end,
		get_player_name = function() return name end,
		get_inventory = function() return inv end}
end
local function fill(p, list, from, to, itemstring)
	for index = from, to do p.inv:set_stack(list, index, itemstring) end
end
local function name_at(p, list, index) return p.inv:get_stack(list, index):get_name() end
-- Every item name with its total count, over every list: nothing lost or
-- duplicated.
-- `no_skills` leaves the skills out (a grant adds one).
local function census(p, no_skills)
	local totals, keys = {}, {}
	for _, stacks in pairs(p.inv:get_lists()) do
		for _, stack in ipairs(stacks) do
			if not stack:is_empty() and not (no_skills and
					stack:get_name():match("^grug_abilities:")) then
				totals[stack:get_name()] = (totals[stack:get_name()] or 0) + stack:get_count()
			end
		end
	end
	for key, count in pairs(totals) do keys[#keys + 1] = key .. "=" .. count end
	table.sort(keys)
	return table.concat(keys, ",")
end
local function where(p, itemname)
	local lists = {}
	for list in pairs(p.inv:get_lists()) do lists[#lists + 1] = list end
	table.sort(lists)
	for _, list in ipairs(lists) do
		for index = 1, p.inv:get_size(list) do
			if name_at(p, list, index) == itemname then return list .. "#" .. index end
		end
	end
	return nil
end
local function allow(p, action, info)
	for _, fn in ipairs(allow_player) do
		local answer = fn(p, action, p.inv, info)
		if answer ~= nil then return answer end
	end
	return nil
end

------------------------------------------------------------------------------
-- A. The guard: every carried list, nothing else.
------------------------------------------------------------------------------
do
	local p = new_player("a", 20, {4, 8, 12, 16})
	p.inv:set_stack("main", 1, STONE)
	p.inv:set_stack(BAGS[2], 3, STONE)
	local stone = ItemStack(STONE)
	for _, list in ipairs({"main", BAGS[1], BAGS[2], BAGS[3], BAGS[4]}) do
		eq(allow(p, "move", {from_list = "main", from_index = 1, to_list = list,
			to_index = 2, count = 1}), nil, "A move from the hotbar into " .. list)
		eq(allow(p, "move", {from_list = BAGS[2], from_index = 3, to_list = list,
			to_index = 1, count = 1}), nil, "A move from a bag into " .. list)
		eq(allow(p, "put", {listname = list, index = 1, stack = stone}), nil,
			"A put into " .. list)
	end
	for _, list in ipairs({"craft", "grug_bag1", "grug_potion_belt", "grug_quiver_content",
			"grug_mail_out", "grug_inbox", "grug_equip_offhand", "grug_equip_chest"}) do
		eq(allow(p, "move", {from_list = "main", from_index = 1, to_list = list,
			to_index = 1, count = 1}), 0, "A refused: main to " .. list)
		eq(allow(p, "move", {from_list = BAGS[2], from_index = 3, to_list = list,
			to_index = 1, count = 1}), 0, "A refused: a bag to " .. list)
		eq(allow(p, "put", {listname = list, index = 1, stack = stone}), 0,
			"A refused: a put into " .. list)
	end
	eq(allow(p, "put", {listname = "craft", index = 1, stack = ItemStack("default:apple")}),
		nil, "A an apple goes anywhere")
	eq(core.registered_items["default:chest"].allow_metadata_inventory_put(nil, "main", 1,
		stone, p), 0, "A a chest refuses the stone")
	core.create_detached_inventory("trade", {allow_put = function() return 5 end})
	eq(core.detached_inventories.trade.allow_put(nil, "give", 1, stone, p), 0,
		"A a detached inventory (a trade) refuses the stone")
end

------------------------------------------------------------------------------
-- B. The give helper and the sort treat the stone like any other item.
------------------------------------------------------------------------------
do
	local p = new_player("b1", 20, {4})
	I.give(p, STONE)
	eq(where(p, STONE), "main#9", "B give: main[9..] first, as for any item")
	local q = new_player("b2", 20, {4})
	fill(q, "main", 9, 32, "default:torch 99")
	I.give(q, STONE)
	eq(where(q, STONE), BAGS[1] .. "#1", "B give: a full main[9..] -> the bag")
	check(I.fits(q, {STONE, STONE, STONE}), "B fits: the bag cells count for the stone")

	-- The sort: main[9..] full of weapons, the stone in the bag stays there.
	local r = new_player("b3", 20, {4})
	fill(r, "main", 9, 32, "t:sword")
	r.inv:set_stack(BAGS[1], 2, STONE)
	r.inv:set_stack(BAGS[1], 4, "default:apple 5")
	local before = census(r)
	I.sort(r)
	eq(where(r, STONE), BAGS[1] .. "#2", "B sort: the stone stays in the bag (after the apples)")
	eq(name_at(r, BAGS[1], 1), "default:apple", "B sort: consumables before the rest")
	eq(census(r), before, "B sort: nothing lost or duplicated")
	-- A stone in main[9..] is sorted like any other item too, behind the
	-- weapons, into the bag.
	local s = new_player("b4", 20, {4})
	fill(s, "main", 10, 32, "t:sword")
	s.inv:set_stack(BAGS[1], 3, "t:sword")
	s.inv:set_stack("main", 9, STONE)
	before = census(s)
	I.sort(s)
	eq(where(s, STONE), BAGS[1] .. "#1", "B sort: a stone in main moves into the bag by its order")
	eq(census(s), before, "B sort: nothing lost or duplicated (2)")
end

------------------------------------------------------------------------------
-- C. The Steward's model per case (the window draws the button from it).
------------------------------------------------------------------------------
do
	local function receive(p) return {H.can_receive_stone(p)} end
	local low = new_player("c_low", 19, {4})
	local r = receive(low)
	eq(r[1], false, "C level 19: no button")
	eq(r[2], "You need level 20 to receive a Claim Stone.", "C level 19: the reason")

	local fresh = new_player("c_fresh", 20, {4})
	eq(receive(fresh)[1], true, "C level 20 without a stone: the button")

	local carrier = new_player("c_main", 25, {4})
	carrier.inv:set_stack("main", 3, STONE)
	r = receive(carrier)
	eq(r[1], false, "C a stone on the hotbar: no button")
	eq(r[2], "You already carry a Claim Stone.", "C a stone on the hotbar: the reason")

	local bagged = new_player("c_bag", 25, {4, 4, 8})
	bagged.inv:set_stack(BAGS[3], 5, STONE)
	r = receive(bagged)
	eq(r[1], false, "C a stone in a bag: no button")
	eq(r[2], "You already carry a Claim Stone.", "C a stone in a bag: the reason")

	local placer = new_player("c_placed", 30, {4})
	H.model.issue("c_placed", 30, false)
	H.model.create("c_placed", {x = 100, y = 10, z = 100})
	r = receive(placer)
	eq(r[1], false, "C a placed stone: no button")
	eq(r[2], "Your Claim Stone is already placed.", "C a placed stone: the reason")

	-- A full inventory keeps the button; the click refuses.
	local full = new_player("c_full", 20, {4})
	fill(full, "main", 1, 32, "default:torch 99")
	fill(full, BAGS[1], 1, 4, "default:torch 99")
	eq(receive(full)[1], true, "C a full inventory keeps the button")
	local ok, message = H.issue_stone(full)
	eq(ok, false, "C a full inventory: the click refuses")
	eq(message, "Make room in your inventory for the Claim Stone.", "C ...and says why")
	eq(where(full, STONE), nil, "C ...and gives nothing")
	eq(H.model.player_state("c_full"), "never", "C ...and records nothing")

	-- A hand-out: the stone like any item, then the reason in place of the
	-- button.
	ok, message = H.issue_stone(fresh)
	eq(ok, true, "C the hand-out")
	eq(message, "You received a Claim Stone.", "C the hand-out's line")
	eq(where(fresh, STONE), "main#9", "C the stone lands where any item would")
	r = receive(fresh)
	eq(r[1], false, "C after the hand-out: no button")
	eq(r[2], "You already carry a Claim Stone.", "C after the hand-out: the reason")
	ok = H.issue_stone(fresh)
	eq(ok, false, "C a second click gives nothing")
	eq(census(fresh), STONE .. "=1", "C one stone")
end

------------------------------------------------------------------------------
-- D. The starter kit (grug_factions/init.lua).
------------------------------------------------------------------------------
do
	local src = read("mods/PLAYER/grug_factions/init.lua")
	local kits = src:match("\n(local starter_kits = {.-\n})\n")
	local give = src:match("\n(local function give_starter_kit%(.-\nend)\n")
	check(kits ~= nil and give ~= nil, "D the starter kit found in grug_factions/init.lua")
	local give_starter_kit = assert(loadstring(table.concat({kits or "", give or "",
		"return give_starter_kit"}, "\n"), "=kit"))()
	for _, faction in ipairs({"accord", "throng"}) do
		local p = new_player("d_" .. faction, 1)
		give_starter_kit(p, faction)
		eq(p.inv:get_stack("main", 7):to_string(), "default:apple 10", "D " .. faction .. ": apples on 7")
		eq(p.inv:get_stack("main", 8):to_string(), "default:torch 10", "D " .. faction .. ": torches on 8")
		eq(census(p), "default:apple=10,default:torch=10", "D " .. faction .. ": nothing else")
	end
	local taken = new_player("d_taken", 1)
	taken.inv:set_stack("main", 7, "t:pick")
	give_starter_kit(taken, "accord")
	eq(name_at(taken, "main", 7), "t:pick", "D a taken slot stays")
	eq(taken.inv:get_stack("main", 9):to_string(), "default:apple 10",
		"D ...and its supply goes through the give helper")
	eq(taken.inv:get_stack("main", 8):to_string(), "default:torch 10", "D the free slot 8 still")
end

------------------------------------------------------------------------------
-- E. A granted skill on a full hotbar (grug_abilities place_on_hotbar).
------------------------------------------------------------------------------
do
	local src = read("mods/PLAYER/grug_abilities/init.lua")
	local block = src:match("\n(local function place_on_hotbar%(.-\n\treturn nil\nend)\n")
	check(block ~= nil, "E place_on_hotbar found in grug_abilities/init.lua")
	local place = assert(loadstring((block or "") .. "\nreturn place_on_hotbar", "=place"))()
	local function skill(id) return ItemStack("grug_abilities:" .. id) end

	-- A free slot first.
	local p = new_player("e_free", 1, {4})
	fill(p, "main", 1, 8, "default:apple 99")
	p.inv:set_stack("main", 4, "")
	eq(place(p, p.inv, skill("strike")), 4, "E a free slot first")
	eq(p.inv:get_stack("main", 9):to_string(), "", "E ...nothing moves")

	-- A full hotbar: the rightmost non-skill item moves into the inventory.
	local q = new_player("e_full", 1, {4})
	fill(q, "main", 1, 8, "default:apple 99")
	q.inv:set_stack("main", 8, "t:pick")
	q.inv:set_stack("main", 3, "grug_abilities:strike")
	local before = census(q, true)
	eq(place(q, q.inv, skill("loose")), 8, "E a full hotbar: the rightmost slot")
	eq(name_at(q, "main", 8), "grug_abilities:loose", "E the skill takes the slot")
	eq(name_at(q, "main", 9), "t:pick", "E the item moved into main[9..] (the give helper)")
	eq(census(q, true), before, "E nothing lost or duplicated")

	-- Skills never move: skills on 6..8, the room comes from slot 5.
	local r = new_player("e_skills", 1, {4})
	fill(r, "main", 1, 5, "default:apple 99")
	fill(r, "main", 6, 8, "grug_abilities:strike")
	eq(place(r, r.inv, skill("loose")), 5, "E skills never move: slot 5")
	eq(r.inv:get_stack("main", 9):to_string(), "default:apple 99", "E slot 5's apples moved")
	local all = new_player("e_all", 1, {4})
	fill(all, "main", 1, 8, "grug_abilities:strike")
	eq(place(all, all.inv, skill("loose")), nil, "E a hotbar of skills: nowhere")

	-- main[9..] full: the item goes into a bag; a soulbound stone too.
	local s = new_player("e_bag", 1, {4})
	fill(s, "main", 1, 32, "default:torch 99")
	s.inv:set_stack("main", 8, STONE)
	eq(place(s, s.inv, skill("loose")), 8, "E the stone on slot 8 makes room")
	eq(where(s, STONE), BAGS[1] .. "#1", "E ...into the bag (Round 49 ruling 3)")

	-- No room anywhere: the skill waits in the catalog, nothing moves.
	local t = new_player("e_none", 1, {4})
	fill(t, "main", 1, 32, "default:torch 99")
	fill(t, BAGS[1], 1, 4, "default:torch 99")
	before = census(t)
	eq(place(t, t.inv, skill("loose")), nil, "E no room anywhere: nowhere")
	eq(census(t), before, "E no room anywhere: nothing moved")
	-- ...except a partial stack the item merges into (the give helper's
	-- partial stacks come first, the hotbar's included).
	t.inv:set_stack("main", 8, "default:apple 5")
	t.inv:set_stack("main", 1, "default:apple 50")
	before = census(t, true)
	eq(place(t, t.inv, skill("loose")), 8, "E a merge makes room too")
	eq(t.inv:get_stack("main", 1):to_string(), "default:apple 55", "E ...onto the hotbar's apples")
	eq(census(t, true), before, "E merge: nothing lost or duplicated")
end

if failures > 0 then
	error(("R49 INV PORTABLE FAIL checks=%d failures=%d"):format(checks, failures), 0)
end
print(("R49 INV PORTABLE PASS checks=%d"):format(checks))
