-- Round 45 playtest PT5 portable test: the shift-click inbox
-- (mods/PLAYER/grug_inventory/inbox.lua). Through tools/r44_ch/harness.lua
-- (the real grug_inventory equipment/bags/storage) plus the real inbox.lua,
-- with a model of the engine's shift-click (IMoveAction::apply with
-- move_somewhere: one-slot fit, allowPut on the player, then allowTake on
-- the source, an infinite source's stack reset, onTake, onPut; within the
-- player the harness's own move) it checks:
--   1. the list: one slot at join, a stray stack handed out at join (the
--      rest at the feet), nothing taken or moved out of it, the carried
--      lists never routed through it;
--   2. a creative (infinite) source and a chest with main full: into the
--      bag, the creative stack unchanged, the chest emptied; a partial fit
--      takes exactly what fits from both; the give order (main[9..] before
--      the hotbar); everything full: nothing moves and one "No room" line;
--   3. the crafting output area (a move within the player) into the bag;
--      arrows into a Scout's quiver first; bound skills and soulbound items
--      refused; room_for equals what give places;
--   4. the rings: every other-inventory list on our pages and the vendored
--      pages is followed by the inbox, `main` still goes to the first other
--      list; the engine's ring lookup on the furnace and chest rings.
-- Every case also checks the totals: no duplication, no loss, inbox empty.
--
-- Usage (repo root): luajit tools/r45_pt5/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)
dofile(repo .. "/mods/PLAYER/grug_inventory/inbox.lua")

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

local INBOX = grug_inventory.INBOX_LIST
local OUTPUT = "grug_craft_out"
eq(INBOX, "grug_inbox", "the list name the rings spell out")

-- The harness keeps the callback runners private; H.move holds them.
local function upvalue(fn, wanted)
	for i = 1, 64 do
		local name, value = debug.getupvalue(fn, i)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("no upvalue " .. wanted)
end
local allow = upvalue(H.move, "allow")
local after_action = upvalue(H.move, "after_action")

core.registered_items["t:dirt"] = {description = "dirt", stack_max = 99, groups = {}}
core.registered_items["t:stone"] = {description = "stone", stack_max = 99, groups = {}}
core.registered_items["t:skill"] = {description = "skill", stack_max = 1,
	groups = {grug_bound_skill = 1, grug_ability = 1}}
core.registered_items["t:claim"] = {description = "claim", stack_max = 1,
	groups = {grug_soulbound = 1}}

--
-- Players and sources
--

local function fill_list(inv, list, from, to, item)
	for i = from, to do inv:set_stack(list, i, ItemStack(item)) end
end

-- A player with a 16-slot bag; `main_free` free slots at the end of main,
-- `bag_free` at the end of the bag, the rest stone.
local serial = 0
local function new_player(main_free, bag_free, class_id)
	serial = serial + 1
	local p = H.player("p" .. serial, class_id or "warrior", {16})
	local inv = p:get_inventory()
	fill_list(inv, "main", 1, 32 - main_free, "t:stone 99")
	fill_list(inv, "main", 33 - main_free, 32, "")
	fill_list(inv, "grug_bag1_content", 1, 16 - bag_free, "t:stone 99")
	fill_list(inv, "grug_bag1_content", 17 - bag_free, 16, "")
	inv:set_size(OUTPUT, 4)
	return p
end

local function count(inv, list, name)
	local n = 0
	for _, s in ipairs(inv:get_list(list) or {}) do
		if s:get_name() == name then n = n + s:get_count() end
	end
	return n
end
local function carried(p, name)
	local inv = p:get_inventory()
	return count(inv, "main", name) + count(inv, "grug_bag1_content", name) +
		count(inv, grug_inventory.QUIVER_LIST, name)
end

-- An inventory of another kind (a chest's node meta, the creative
-- detached inventory): a holder's inventory with a 4-slot `main`.
local function new_source(kind)
	local holder = H.player("src" .. serial .. kind, "warrior")
	local inv = holder:get_inventory()
	inv:set_size("main", 4)
	local src = {inv = inv, taken = {}}
	-- The creative inventory's allow_take: -1 (infinite) for a creative
	-- player; a chest takes what is asked.
	function src.allow_take(stack) return kind == "creative" and -1 or stack:get_count() end
	function src.on_take(stack) src.taken[#src.taken + 1] = stack:to_string() end
	return src
end

-- The engine's shift-click from another inventory's list into the player's
-- `to_list` (IMoveAction::apply, move_somewhere): the whole stack, the
-- target's non-empty slots first, then the empty ones; per slot the fit,
-- allowPut on the player, then allowTake on the source.
local function shift_from(p, src, from_i, to_list)
	local inv = p:get_inventory()
	local left = src.inv:get_stack("main", from_i):get_count()
	for pass = 1, 2 do
		for i = 1, inv:get_size(to_list) do
			local item = src.inv:get_stack("main", from_i)
			if left > 0 and not item:is_empty() and
					inv:get_stack(to_list, i):is_empty() == (pass == 2) then
				if left < item:get_count() then item:set_count(left) end
				local rest = inv:get_stack(to_list, i):add_item(ItemStack(item))
				local n = item:get_count() - rest:get_count()
				if n > 0 then -- else: no callback at all
					item:set_count(n)
					local can_put = allow(p, "put", {listname = to_list, index = i,
						stack = ItemStack(item)})
					if can_put == nil then can_put = n end
					local can_take = src.allow_take(ItemStack(item))
					if can_take ~= -1 then n = math.min(n, can_take) end
					if can_put ~= -1 then n = math.min(n, can_put) end
					if n > 0 then
						local before = src.inv:get_stack("main", from_i)
						local s = src.inv:get_stack("main", from_i)
						local moving = s:take_item(n)
						src.inv:set_stack("main", from_i, s)
						local d = inv:get_stack(to_list, i)
						assert(d:add_item(moving):is_empty())
						inv:set_stack(to_list, i, d)
						if can_take == -1 then src.inv:set_stack("main", from_i, before) end
						local done = ItemStack(item)
						done:set_count(n)
						src.on_take(done)
						after_action(p, "put", {listname = to_list, index = i, stack = done})
						left = left - n
					end
				end
			end
		end
	end
end

local function feed_lines(p, key)
	local n = 0
	for _, line in ipairs(H.feed) do
		if line.name == p:get_player_name() and (key == nil or line.key == key) then
			n = n + 1
		end
	end
	return n
end

--
-- 1. The list
--

do
	local p = new_player(4, 16)
	local inv = p:get_inventory()
	eq(inv:get_size(INBOX), 1, "join: the inbox has one slot")
	inv:set_stack(INBOX, 1, ItemStack("t:dirt 50"))
	H.join(p)
	eq(H.get(p, INBOX, 1), "", "join: a stray stack leaves the inbox")
	eq(H.get(p, "main", 29), "t:dirt 50", "join: ... into main[9..] first")

	local full = new_player(0, 0)
	full:get_inventory():set_stack(INBOX, 1, ItemStack("t:dirt 5"))
	local dropped = #H.dropped
	H.join(full)
	eq(H.get(full, INBOX, 1), "", "join, everything full: the inbox is emptied")
	eq(H.dropped[dropped + 1], "t:dirt 5", "join, everything full: the stack lands at the feet")

	-- Nothing leaves the inbox by hand, nothing of the carried lists enters.
	inv:set_stack(INBOX, 1, ItemStack("t:dirt 3"))
	eq(allow(p, "take", {listname = INBOX, index = 1, stack = ItemStack("t:dirt 3")}), 0,
		"no take from the inbox")
	eq(H.move(p, INBOX, 1, "main", 30, 3), 0, "no move out of the inbox")
	inv:set_stack(INBOX, 1, ItemStack(""))
	inv:set_stack("main", 30, ItemStack("t:dirt 7"))
	eq(H.move(p, "main", 30, INBOX, 1, 7, true), 0, "main is never routed through it")
	eq(H.get(p, "main", 30), "t:dirt 7", "... and stays")
	eq(allow(p, "put", {listname = "main", index = 1, stack = ItemStack("t:dirt")}), nil,
		"other lists: the allow chain goes on")
end

--
-- 2. Other inventories
--

-- `setup(p, src)` then one shift-click of source slot 1; returns the moved
-- count, after checking the totals.
local function case(label, main_free, bag_free, kind, item, setup)
	local p = new_player(main_free, bag_free)
	local src = new_source(kind)
	src.inv:set_stack("main", 1, ItemStack(item))
	if setup then setup(p, src) end
	local name = ItemStack(item):get_name()
	local had, in_source = carried(p, name), count(src.inv, "main", name)
	shift_from(p, src, 1, INBOX)
	local gained = carried(p, name) - had
	local lost = in_source - count(src.inv, "main", name)
	eq(H.get(p, INBOX, 1), "", label .. ": the inbox ends empty")
	if kind == "creative" then
		eq(lost, 0, label .. ": the creative stack is unchanged")
	else
		eq(lost, gained, label .. ": what left the chest arrived (no loss, no duplication)")
	end
	local taken = 0
	for _, s in ipairs(src.taken) do taken = taken + ItemStack(s):get_count() end
	eq(taken, gained, label .. ": the source's on_take saw exactly that")
	return gained, p, src
end

do
	local gained, p = case("creative, main full", 0, 16, "creative", "t:dirt 99")
	eq(gained, 99, "creative, main full: all 99 arrive")
	eq(H.get(p, "grug_bag1_content", 1), "t:dirt 99", "creative, main full: in the bag")

	local src
	gained, p, src = case("chest, main full", 0, 16, "chest", "t:dirt 99")
	eq(gained, 99, "chest, main full: all 99 arrive")
	eq(H.get(p, "grug_bag1_content", 1), "t:dirt 99", "chest, main full: in the bag")
	eq(src.inv:get_stack("main", 1):to_string(), "", "chest, main full: the chest is empty")

	-- Partial fit: main and the bag full but one bag slot holding 70 dirt.
	local partial = function(pl)
		pl:get_inventory():set_stack("grug_bag1_content", 5, ItemStack("t:dirt 70"))
	end
	gained, p, src = case("chest, partial fit", 0, 0, "chest", "t:dirt 99", partial)
	eq(gained, 29, "chest, partial fit: 29 accepted")
	eq(src.inv:get_stack("main", 1):to_string(), "t:dirt 70", "chest, partial fit: 70 stay")
	eq(H.get(p, "grug_bag1_content", 5), "t:dirt 99", "chest, partial fit: the bag stack topped up")
	eq(feed_lines(p, "inbox_room"), 0, "chest, partial fit: no No-room line")
	gained = case("creative, partial fit", 0, 0, "creative", "t:dirt 99", partial)
	eq(gained, 29, "creative, partial fit: 29 accepted")

	-- The give order: a free hotbar slot, a free main[9..] slot and the bag.
	gained, p = case("chest, give order", 0, 16, "chest", "t:dirt 99", function(pl)
		pl:get_inventory():set_stack("main", 2, ItemStack(""))
		pl:get_inventory():set_stack("main", 12, ItemStack(""))
	end)
	eq(H.get(p, "main", 12), "t:dirt 99", "give order: main[9..] before the bag")
	eq(H.get(p, "main", 2), "", "give order: the hotbar stays free")

	-- A stack larger than one free slot: main[9..], then the bag.
	gained, p = case("chest, main then bag", 0, 16, "chest", "t:dirt 99", function(pl)
		pl:get_inventory():set_stack("main", 20, ItemStack("t:dirt 90"))
	end)
	eq(gained, 99, "main then bag: all 99 arrive")
	eq(H.get(p, "main", 20), "t:dirt 99", "main then bag: the partial main stack first")
	eq(H.get(p, "grug_bag1_content", 1), "t:dirt 90", "main then bag: the rest in the bag")

	-- Everything full: nothing moves, one keyed line.
	local before = #H.feed
	gained, p, src = case("chest, everything full", 0, 0, "chest", "t:dirt 99")
	eq(gained, 0, "everything full: nothing moves")
	eq(src.inv:get_stack("main", 1):to_string(), "t:dirt 99", "everything full: the chest keeps it")
	eq(#H.feed - before, 1, "everything full: one feed line")
	local line = H.feed[#H.feed] or {}
	eq(line.text, "No room in your inventory.", "everything full: the line")
	eq(line.key, "inbox_room", "everything full: keyed, so repeats replace it")
	gained = case("creative, everything full", 0, 0, "creative", "t:dirt 99")
	eq(gained, 0, "creative, everything full: nothing moves")
end

--
-- 3. Within the player, arrows, guarded items, room_for
--

do
	-- The crafting output area: a move within the player inventory.
	local p = new_player(0, 16)
	local inv = p:get_inventory()
	inv:set_stack(OUTPUT, 1, ItemStack("t:dirt 99"))
	eq(H.move(p, OUTPUT, 1, INBOX, 1, 99, true), 99, "output area: the move is accepted")
	eq(H.get(p, OUTPUT, 1), "", "output area: emptied")
	eq(H.get(p, "grug_bag1_content", 1), "t:dirt 99", "output area, main full: into the bag")
	eq(H.get(p, INBOX, 1), "", "output area: the inbox ends empty")
	-- Through the page's ring: the output list's next entry is the inbox.
	inv:set_stack(OUTPUT, 2, ItemStack("t:dirt 40"))
	local ring = "listring[current_player;grug_craft_out]listring[current_player;grug_inbox]" ..
		"listring[current_player;main]"
	eq(H.shift(p, ring, OUTPUT, 2), INBOX, "output area: the ring targets the inbox")
	eq(H.get(p, "grug_bag1_content", 1), "t:dirt 99", "output area ring: the bag stack is full")
	eq(H.get(p, "grug_bag1_content", 2), "t:dirt 40", "output area ring: the rest beside it")
	eq(H.get(p, OUTPUT, 2), "", "output area ring: emptied")
	local q = new_player(0, 0)
	q:get_inventory():set_stack(OUTPUT, 1, ItemStack("t:dirt 9"))
	eq(H.move(q, OUTPUT, 1, INBOX, 1, 9, true), 0, "output area, everything full: refused")
	eq(H.get(q, OUTPUT, 1), "t:dirt 9", "output area, everything full: stays")

	-- Arrows: a Scout's quiver first.
	local scout = new_player(4, 16, "scout")
	local src = new_source("chest")
	src.inv:set_stack("main", 1, ItemStack("grug_gear:arrow 100"))
	shift_from(scout, src, 1, INBOX)
	eq(grug_inventory.quiver_count(scout), 100, "arrows: into the Scout's quiver")
	eq(count(scout:get_inventory(), "main", "grug_gear:arrow"), 0, "arrows: not into main")
	eq(src.inv:get_stack("main", 1):to_string(), "", "arrows: the chest is empty")
	-- A full main and bag still take arrows while the quiver has room.
	local scout2 = new_player(0, 0, "scout")
	eq(grug_inventory.room_for(scout2, ItemStack("grug_gear:arrow 60")), 60,
		"room_for: a full inventory with quiver room")

	-- Guarded items never pass the inbox.
	local g = new_player(4, 16)
	eq(allow(g, "put", {listname = INBOX, index = 1, stack = ItemStack("t:skill")}), 0,
		"a bound skill is refused")
	eq(allow(g, "put", {listname = INBOX, index = 1, stack = ItemStack("t:claim")}), 0,
		"a soulbound item is refused")
	eq(feed_lines(g), 0, "guarded items: no No-room line")

	-- room_for is what give places, in several states.
	local states = {{0, 16}, {0, 0}, {3, 0}, {0, 2}, {32, 16}}
	for _, st in ipairs(states) do
		for _, item in ipairs({"t:dirt 99", "t:dirt 1", "t:stone 99", "grug_gear:arrow 100"}) do
			local pl = new_player(st[1], st[2])
			pl:get_inventory():set_stack("grug_bag1_content", 1, ItemStack("t:dirt 50"))
			local room = grug_inventory.room_for(pl, ItemStack(item))
			local left = grug_inventory.give(pl, ItemStack(item))
			eq(room, ItemStack(item):get_count() - left:get_count(),
				("room_for = give (main free %d, bag free %d, %s)"):format(st[1], st[2], item))
		end
	end
end

--
-- 4. The rings
--

-- The source with adjacent string literals joined (`"a" .. "b"`, comments
-- between them included), so a ring split over literals reads as one text.
local function joined_source(path)
	local f = assert(io.open(repo .. "/" .. path, "r"))
	local text = f:read("*a")
	f:close()
	local prev
	repeat
		prev = text
		text = text:gsub('"%s*%.%.%s*%-%-[^\n]*\n%s*', '" .. ')
		text = text:gsub('"%s*%.%.%s*"', "")
	until text == prev
	return text
end

-- Every listring naming another inventory's list (or the player's crafting
-- output and operation target) is followed by the inbox; `listring[]` is the
-- creative page's trash pair and `main`/the inbox never need one.
local function check_rings(path, expected)
	local text = joined_source(path)
	local found = 0
	for start in text:gmatch("()listring%[") do
		local head = text:sub(start, start + 40)
		local plain = head:match("^listring%[current_player;main%]") or
			head:match("^listring%[current_player;grug_inbox%]") or
			head:match("^listring%[%]")
		if not plain then
			local close = text:find("]", start, true)
			local after = text:sub(close + 1, close + 40)
			found = found + 1
			check(after:match("^listring%[current_player;grug_inbox%]") ~= nil,
				path .. ": ring entry " .. found .. " is followed by the inbox (" ..
				head:gsub("\n", " ") .. ")")
		end
	end
	eq(found, expected, path .. ": ring entries checked")
end
check_rings("mods/BASE/default/chests.lua", 1)
check_rings("mods/BASE/default/furnace.lua", 6)
check_rings("mods/BASE/default/nodes.lua", 1)
check_rings("mods/BASE/vessels/init.lua", 1)
check_rings("mods/BASE/creative/inventory.lua", 1)
check_rings("mods/PLAYER/grug_jobs/workspaces.lua", 1)
check_rings("mods/PLAYER/grug_jobs/operation_box.lua", 2)
check_rings("mods/PLAYER/grug_jobs/ui.lua", 1)
check_rings("mods/PLAYER/grug_housing/stone_form.lua", 1)

-- The engine's lookup (getNextInventoryRing: the entry after the FIRST one
-- naming the source list) on the rings as the pages send them.
local function next_ring(fs, location, list)
	local rings = H.rings(fs)
	for i, ring in ipairs(rings) do
		if ring.location == location and ring.list == list then
			local to = rings[i % #rings + 1]
			return to.location .. ";" .. to.list
		end
	end
end
local LOC = "nodemeta:1,2,3"
local furnace = ("listring[%s;dst]listring[current_player;grug_inbox]listring[current_player;main]" ..
	"listring[%s;src]listring[current_player;grug_inbox]listring[current_player;main]" ..
	"listring[%s;fuel]listring[current_player;grug_inbox]listring[current_player;main]")
	:format(LOC, LOC, LOC)
eq(next_ring(furnace, LOC, "dst"), "current_player;grug_inbox", "furnace: output -> inbox")
eq(next_ring(furnace, LOC, "src"), "current_player;grug_inbox", "furnace: input -> inbox")
eq(next_ring(furnace, LOC, "fuel"), "current_player;grug_inbox", "furnace: fuel -> inbox")
eq(next_ring(furnace, "current_player", "main"), LOC .. ";src", "furnace: main -> input, as before")
local chest = ("listring[%s;main]listring[current_player;grug_inbox]listring[current_player;main]")
	:format(LOC)
eq(next_ring(chest, LOC, "main"), "current_player;grug_inbox", "chest: chest -> inbox")
eq(next_ring(chest, "current_player", "main"), LOC .. ";main", "chest: main -> chest, as before")
local op = "listring[current_player;grug_craft_out]listring[current_player;grug_inbox]" ..
	"listring[current_player;main]listring[current_player;grug_craft_target]" ..
	"listring[current_player;grug_inbox]listring[current_player;main]" ..
	"listring[current_player;grug_craft_out]listring[current_player;grug_inbox]" ..
	"listring[current_player;main]"
eq(next_ring(op, "current_player", "main"), "current_player;grug_craft_target",
	"operation box: main -> the target slot, as before")
eq(next_ring(op, "current_player", "grug_craft_target"), "current_player;grug_inbox",
	"operation box: the target slot -> inbox")

if failures > 0 then
	print(("R45 PT5 PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R45 PT5 PORTABLE PASS checks=%d"):format(checks))
