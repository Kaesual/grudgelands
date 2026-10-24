-- Round 44 lane TS portable test: the Talents & Skills tab. Loads, through
-- tools/r44_ts/harness.lua, the REAL sfinv, grug_inventory/ui.lua (frame and
-- views), the talent files (since Round 53 the graph talents and their page,
-- talent_graph_ui.lua), talents_ui.lua and grug_skills, plus the grant code
-- cut out of grug_abilities/init.lua, and checks:
--   1. (Round 44's tree framework, layout_tree: retired in Round 53 with the
--      old trees; the graph page's layout is tools/r52_graph's);
--   2. the class's graph trees on the page: one tab per tree, the
--      connectors before (under) the nodes, one style per node state, a
--      node click buys a rank and selects it, a refused click shows the
--      node's text and the reason, the respec control;
--   3. one tab: grug_classes:talents is "Talents & Skills", the old Skills
--      page is gone; the catalog row (abilities only, no mounts) under the
--      tree text and above the short inventory, on the hotbar's columns, in
--      a "Skills" box like the Hotbar box (Round 45 playtest), its slots in a
--      horizontal scroll container with room for the bar below (Round 52
--      C13; the scrolling itself: tools/r52_graph);
--   4. the hotbar-only rule for each target list (hotbar, main[9..], every
--      bag, the potion belt, craft, equipment, the quiver), swaps, puts from
--      the catalog, one copy; mount items keep main and bags; and, on a
--      model of the engine's move (inventorymanager.cpp IMoveAction::apply),
--      a drag from the catalog onto the hotbar and a drag back that removes;
--   5. grants: grant_initial_kit with a free and with a full hotbar (Round
--      49: the rightmost non-skill item moves into the inventory through the
--      real give helper and the skill takes its slot; with no room anywhere
--      nothing moves; never main[9..] or a bag), the starter supplies on
--      hotbar 7 and 8 at creation, and a talent unlock through grug_skills,
--      which places nothing (Round 50 D1: it waits in the catalog, the feed
--      says so; grant_to_hotbar is gone).
-- Prints the page's formspec bytes (a comparison, not a target).
--
-- Usage (repo root): luajit tools/r44_ts/portable_test.lua [repo]

local repo = arg and arg[1] or "."
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
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local H = dofile(repo .. "/tools/r44_ts/harness.lua")(repo)

--
-- 2. The class's graph trees on the page.
--

local graph = grug_classes.graph
-- A level-30 Scout with 15 ranks in Quarry.
local RANKS = "quarry_bowcraft=4,quarry_true_draw=1,quarry_quiver=3,quarry_firm_aim=2," ..
	"quarry_snare_shot=1,quarry_measured_breath=3,quarry_long_view=1"
local scout = H.make_player("scout", "scout", 30, RANKS)
H.join(scout)
eq(grug_classes.talent_points_spent(scout), 15, "the stored ranks read back")
local context = sfinv.get_or_create_context(scout)
local form = H.render(scout, "grug_classes:talents")
local page_bytes = #form
has(form, "grug_graph_tab_1;Quarry (15)]", "a tab per tree with its points: Quarry")
has(form, "grug_graph_tab_2;Veil (0)]", "and Veil")
has(form, "label[5.75,0.45;Talent points available: 0 of 15]", "the points")
local first_node = form:find("image_button[", 1, true)
local last_box, connector_boxes = 0, 0
for start, color in form:gmatch("()box%[[^%]]-;(#%x+)%]") do
	if color == "#c9a65a" or color == "#5a5a5a" then
		connector_boxes = connector_boxes + 1
		last_box = math.max(last_box, start)
	end
end
check(connector_boxes > 0, "the connectors are drawn")
check(first_node and last_box < first_node, "the connectors are drawn before the nodes")
local buttons = 0
for _ in form:gmatch("image_button%[[^%]]-;grug_graph_node_") do buttons = buttons + 1 end
eq(buttons, #graph.trees.quarry.nodes, "a node button per Quarry node")
local styles = 0
for _ in form:gmatch("style%[grug_graph_node_") do styles = styles + 1 end
eq(styles, 3, "one style per node state (maxed, ranked, locked)")
eq(form:find("grug_talent_pick_", 1, true), nil, "no old tree node")

-- A click on an available node buys a rank and selects it.
local learner = H.make_player("learner", "scout", 30, "")
H.join(learner)
local lctx = sfinv.get_or_create_context(learner)
H.render(learner, "grug_classes:talents")
local page = sfinv.pages["grug_classes:talents"]
page:on_player_receive_fields(learner, lctx, {grug_graph_tab_2 = "x"})
has(learner.formspec, grug_core.ui.button_style("grug_graph_tab_2", "selected"), "a tab click shows Veil")
local field = graph.node_field("veil_fine_edge")
page:on_player_receive_fields(learner, lctx, {[field] = "x"})
eq(grug_classes.talent_rank(learner, "veil_fine_edge"), 1, "the click bought a rank")
eq(lctx.grug_talent_selected, "veil_fine_edge", "and selected the node")
has(learner.formspec, grug_core.ui.button_style(field, "selected"), "the selected node is gold")
-- A refused click selects the node and shows its text and the reason.
local locked_field = graph.node_field("veil_close_dance")
page:on_player_receive_fields(learner, lctx, {[locked_field] = "x"})
eq(grug_classes.talent_rank(learner, "veil_close_dance"), 0, "a locked node buys nothing")
eq(lctx.grug_talent_notice, nil, "no notice replaces the description")
local line = learner.formspec:match("textarea%[[^;]*;[^;]*;;;(.-)%]")
has(line, "Close Dance", "the line names the talent")
has(line, "Unlocks Close Dance", "with its text")
has(line, "needs 20 points in Veil", "and the reason")
-- The respec control: free first, then confirmed, the points back.
has(learner.formspec, "grug_talent_respec;Respec: Free]", "the respec button")
page:on_player_receive_fields(learner, lctx, {grug_talent_respec = "x"})
has(learner.formspec, "grug_talent_respec_confirm;Confirm]", "a confirm step")
has(learner.formspec, "Reset every talent rank?", "with its question in the strip")
page:on_player_receive_fields(learner, lctx, {grug_talent_respec_confirm = "x"})
eq(grug_classes.talent_points_spent(learner), 0, "the respec returned every point")
has(learner.formspec, "Talents reset: 1 points returned\\, nothing charged.", "and says so")
has(learner.formspec, "label[9.90,0.45;No ranks spent]", "nothing left to reset")

--
-- 3. One tab and the catalog row.
--

eq(sfinv.pages["grug_classes:talents"].title, "Talents & Skills", "the tab's title")
eq(sfinv.pages["grug_skills:skills"], nil, "the Skills page is gone")
local in_table = 0
for _, name in ipairs(grug_inventory.TAB_ORDER) do
	if name == "grug_classes:talents" then in_table = in_table + 1 end
	check(name ~= "grug_skills:skills", "TAB_ORDER has no Skills entry")
end
eq(in_table, 1, "one TAB_ORDER entry")

scout.mount_tier = 1
form = H.render(scout, "grug_classes:talents")
-- Round 52 C13: the list sits at 0,0 in a horizontal scroll container, which
-- takes the slots' place.
local list_x, list_y = form:match("scroll_container%[([%d.]+),([%d.]+);[%d.]+,1;" ..
	"grug_skills_scroll;horizontal;[%d.]+%]list%[detached:grug_skills_scout;catalog;0,0;8,1;0%]")
check(list_x ~= nil, "the catalog list is on the page")
check(math.abs(tonumber(list_x) - grug_inventory.VIEW_GEOMETRY.x) < 0.001,
	"on the hotbar's columns")
local text_y, text_h = form:match("textarea%[0.25,([%d.]+);13.00,([%d.]+);")
local hint_x, hint_y = form:match("label%[([%d.]+),([%d.]+);Drag skills onto the hotbar")
hint_x, hint_y = tonumber(hint_x), tonumber(hint_y)
-- The Skills box: the Hotbar box's place across, its colour and label style,
-- a gap above the short view's Inventory box.
local L = grug_inventory.LAYOUT
local bx, by, bw, bh, color, lx, ly = form:match(
	"background9%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]+);false;6%]label%[([%d.]+),([%d.]+);Skills%]")
bx, by, bw, bh, lx, ly = tonumber(bx), tonumber(by), tonumber(bw), tonumber(bh),
	tonumber(lx), tonumber(ly)
if check(bx ~= nil, "the catalog in a Skills box, labelled inside") then
	-- Round 52 C13: 0.3 higher, for the scrollbar under the slots.
	check(math.abs(bx - L.box_x) < 0.001 and math.abs(bw - L.box_w) < 0.001 and
		math.abs(bh - L.slot_box_h - 0.3) < 0.001,
		"the Skills box as wide as the Hotbar box, with room for the bar")
	eq(color, "grug_ui_panel.png", "the Skills panel texture")
	check(math.abs(lx - tonumber(list_x)) < 0.001 and ly > by and ly < tonumber(list_y),
		"its label top left above the slots")
	check(tonumber(list_y) > by and tonumber(list_y) + 1 < by + bh, "the slots inside the box")
	check(math.abs(by + bh + L.gap - grug_inventory.VIEW_GEOMETRY.top) < 0.001,
		"the box a gap above the short inventory's box")
	check(by >= tonumber(text_y) + tonumber(text_h), "under the tree's text")
	-- The hint beside the label, in the label's strip (Round 45 PT2
	-- follow-up: seven rows leave no room for a line of its own).
	check(hint_x and hint_x > lx and math.abs(hint_y - ly) < 0.001,
		"the hint beside the Skills label")
end
check(form:find("list[detached:grug_skills_scout", 1, true) >
	form:find("real_coordinates[false]", 1, true), "drawn after the view, in the page content")
-- Round 48 INV: the view prints each element's column, so x is "0.000".
has(form, "list[current_player;main;0.000,0.000;8,3;8]", "the short inventory below")
local catalog = H.catalog("scout")
eq(catalog.inv:get_size("catalog"), 5, "five unlocked abilities (True Draw ranked), no mount")
for i = 1, 5 do
	check(catalog.inv:get_stack("catalog", i):get_name():match("^grug_abilities:") ~= nil,
		"catalog slot " .. i .. " is an ability")
end
eq(read("mods/PLAYER/grug_skills/page.lua"):find("room_for_item", 1, true), nil,
	"the catalog take no longer checks room in main")

--
-- 4. The hotbar-only rule.
--

local player = H.make_player("rules", "scout", 30, "")
H.join(player)
local inv = player:get_inventory()
for i = 1, 4 do inv:set_size("grug_bag" .. i .. "_content", 8 * i) end
inv:set_size("grug_weapon", 1)
inv:set_size("grug_quiver_content", 1)
local LOOSE = "grug_abilities:loose"
inv:set_stack("main", 1, LOOSE)
inv:set_stack("main", 12, "default:torch")
local function move(from_list, from_index, to_list, to_index)
	return H.allow(player, "move", inv, {from_list = from_list, from_index = from_index,
		to_list = to_list, to_index = to_index, count = 1})
end
for index = 2, 8 do eq(move("main", 1, "main", index), nil, "skill to hotbar slot " .. index) end
for _, index in ipairs({9, 16, 32}) do eq(move("main", 1, "main", index), 0, "skill to main[" .. index .. "]") end
for i = 1, 4 do eq(move("main", 1, "grug_bag" .. i .. "_content", 1), 0, "skill into bag " .. i) end
for _, list in ipairs({"grug_potion_belt", "craft", "grug_weapon", "grug_quiver_content",
		"grug_bag1"}) do
	eq(move("main", 1, list, 1), 0, "skill into " .. list)
end
-- A swap is asked again with the sides swapped: the torch onto the skill's
-- slot would push the skill to main[12].
eq(move("main", 12, "main", 1), nil, "the torch's own direction")
eq(move("main", 1, "main", 12), 0, "the reverse direction refuses the swap")
-- A stray skill (from before the rule) may go to the hotbar, nowhere else.
inv:set_stack("main", 20, "grug_abilities:sprint")
inv:set_stack("grug_bag2_content", 3, "grug_abilities:strike")
eq(move("main", 20, "main", 5), nil, "a stray in main[9..] onto the hotbar")
eq(move("main", 20, "main", 21), 0, "but not within main[9..]")
eq(move("grug_bag2_content", 3, "main", 6), nil, "a stray in a bag onto the hotbar")
eq(move("grug_bag2_content", 3, "grug_bag2_content", 4), 0, "but not within the bag")
-- Mount items keep main and the bags.
inv:set_stack("main", 2, "grug_mounts:horse")
inv:get_stack("main", 2) -- (copies: set the owner on the stored stack)
inv.lists.main[2]:get_meta():set_string("grug_mounts:owner", "rules")
player.mount_tier = 1
eq(move("main", 2, "main", 14), nil, "a mount item to main[9..]")
eq(move("main", 2, "grug_bag1_content", 2), nil, "a mount item into a bag")
eq(move("main", 2, "grug_potion_belt", 1), 0, "but not into the belt")
inv:set_stack("main", 2, "")

-- Puts from the catalog: a free hotbar slot, one copy.
local function put(listname, index, item)
	return H.allow(player, "put", inv, {listname = listname, index = index,
		stack = ItemStack(item), count = 1})
end
local SNARE = "grug_abilities:snare_shot"
eq(put("main", 3, SNARE), nil, "a catalog skill onto a free hotbar slot")
eq(put("main", 9, SNARE), 0, "not onto main[9]")
eq(put("grug_bag1_content", 1, SNARE), 0, "not into a bag")
eq(put("grug_potion_belt", 1, SNARE), 0, "not into the belt")
eq(put("main", 3, LOOSE), 0, "not a second copy (Loose sits in slot 1)")
eq(put("main", 1, LOOSE), nil, "onto its own copy: the catalog's drag-back swap")
eq(put("main", 4, "grug_abilities:opening"), 0, "not an ability the player lacks")

--
-- 4b. The drags on a model of the engine's move.
--

-- One drag of a one-item stack between two inventories, after
-- IMoveAction::apply (src/inventorymanager.cpp:355-610): nil allows the whole
-- stack, -1 is an infinite side; a drop on an occupied slot is a swap that
-- needs the reverse pair of answers too; an infinite source keeps its stack
-- (and hands the destination's old stack to the destination list's first
-- empty slot), an infinite destination keeps its stack and undoes a swap.
local function side(owner, inventory, list, index)
	local s = {inv = inventory, list = list, index = index}
	if inventory:get_location().type == "detached" then
		local cb = H.catalog(owner:get_player_name()).callbacks
		s.allow_take = function(stack) return cb.allow_take(inventory, list, index, stack, owner) end
		s.allow_put = function(stack) return cb.allow_put(inventory, list, index, stack, owner) end
		s.on_take = function(stack) if cb.on_take then cb.on_take(inventory, list, index, stack, owner) end end
	else
		local info = {listname = list, index = index}
		s.allow_take = function(stack)
			info.stack = stack
			return H.allow(owner, "take", inventory, info)
		end
		s.allow_put = function(stack)
			info.stack = stack
			return H.allow(owner, "put", inventory, info)
		end
	end
	return s
end
local function allowed(v) return v == nil or v == -1 or v >= 1 end
local function drag(from, to)
	local src = from.inv:get_stack(from.list, from.index)
	local dst = to.inv:get_stack(to.list, to.index)
	local swap = not dst:is_empty()
	local put_n, take_n = to.allow_put(src), from.allow_take(src)
	if not (allowed(put_n) and allowed(take_n)) then return "refused" end
	if swap and not (allowed(from.allow_put(dst)) and allowed(to.allow_take(dst))) then
		return "refused"
	end
	from.inv:set_stack(from.list, from.index, swap and dst or "")
	to.inv:set_stack(to.list, to.index, src)
	if take_n == -1 then
		if swap and src:get_name() ~= dst:get_name() then
			for i = 1, to.inv:get_size(to.list) do
				if to.inv:get_stack(to.list, i):is_empty() then
					to.inv:set_stack(to.list, i, dst)
					break
				end
			end
		end
		from.inv:set_stack(from.list, from.index, src)
	end
	if put_n == -1 then
		to.inv:set_stack(to.list, to.index, dst)
		if swap then from.inv:set_stack(from.list, from.index, "") end
	end
	if from.on_take then from.on_take(src) end
	return "moved"
end

local cat = H.catalog("rules")
local slot_of = {}
for i = 1, cat.inv:get_size("catalog") do slot_of[cat.inv:get_stack("catalog", i):get_name()] = i end
local function from_catalog(item) return side(player, cat.inv, "catalog", slot_of[item]) end
local function at(list, index) return side(player, inv, list, index) end
for i = 1, 8 do inv:set_stack("main", i, "") end
inv:set_stack("main", 20, "")
inv:set_stack("grug_bag2_content", 3, "")
inv:set_stack("main", 5, "default:torch")

eq(drag(from_catalog(LOOSE), at("main", 3)), "moved", "catalog > free hotbar slot")
eq(inv:get_stack("main", 3):get_name(), LOOSE, "the skill is on the hotbar")
eq(inv:get_stack("main", 3):get_description(), "Loose (fresh)", "as a fresh stack")
eq(cat.inv:get_stack("catalog", slot_of[LOOSE]):get_name(), LOOSE, "the catalog keeps it")
eq(drag(from_catalog(LOOSE), at("main", 4)), "refused", "not a second copy")
eq(drag(from_catalog(SNARE), at("main", 10)), "refused", "catalog > main[10] refused")
eq(drag(from_catalog(SNARE), at("grug_bag1_content", 1)), "refused", "catalog > bag refused")
eq(drag(from_catalog(SNARE), at("main", 5)), "refused", "catalog > a slot holding a torch refused")
eq(inv:get_stack("main", 5):get_name(), "default:torch", "the torch stays")
eq(drag(at("main", 3), from_catalog(SNARE)), "refused", "back onto another skill's icon: refused")
eq(inv:get_stack("main", 3):get_name(), LOOSE, "and the skill stays")
eq(drag(at("main", 3), from_catalog(LOOSE)), "moved", "back onto its own icon")
eq(inv:get_stack("main", 3):get_name(), "", "removes the hotbar copy")
eq(cat.inv:get_stack("catalog", slot_of[LOOSE]):get_name(), LOOSE, "the catalog still lists it")
inv:set_stack("main", 18, LOOSE)
eq(drag(at("main", 18), from_catalog(LOOSE)), "moved", "a stray in main[9..] back onto its icon")
eq(inv:get_stack("main", 18):get_name(), "", "removes the stray")
local carried = 0
for _, list in ipairs({"main", "grug_bag1_content", "grug_bag2_content",
		"grug_bag3_content", "grug_bag4_content"}) do
	for i = 1, inv:get_size(list) do
		if inv:get_stack(list, i):get_name():match("^grug_abilities:") then carried = carried + 1 end
	end
end
eq(carried, 0, "no skill left anywhere")
local stranger = H.make_player("stranger", "scout", 30, "")
local foreign = cat.callbacks.allow_take(cat.inv, "catalog", 1, cat.inv:get_stack("catalog", 1), stranger)
eq(foreign, 0, "another player cannot take from the catalog")

--
-- 5. Grants.
--

-- Round 49 ruling 10: with no free hotbar slot a non-skill item makes room
-- through the REAL give helper and fit check (grug_inventory/storage.lua);
-- the quiver and the weapon-tooltip setup are not part of this test.
grug_gear = {initialize_weapon_tooltip = function() end}
grug_inventory.add_to_quiver = function(_, stack) return stack end
grug_inventory.has_quiver = function() return false end
core.register_on_item_pickup = function() end
dofile(repo .. "/mods/PLAYER/grug_inventory/storage.lua")

local abilities_src = read("mods/PLAYER/grug_abilities/init.lua")
local function cut(pattern, label)
	local block = abilities_src:match(pattern)
	check(block ~= nil, label .. " found in grug_abilities/init.lua")
	return block or ""
end
local grant_initial_kit = assert(loadstring(table.concat({
	cut("\n(local function active_lists%(%).-\nend)\n", "active_lists"),
	cut("\n(local function representation_lists%(%).-\nend)\n", "representation_lists"),
	cut("\n(local META_INITIAL_KIT = .-\n)\n", "META_INITIAL_KIT"),
	cut("\n(local function insert_initial_ability%(.-\nend)\n", "insert_initial_ability"),
	cut("\n(local function place_on_hotbar%(.-\nend)\n\ngrug_classes%.register_on_class_chosen",
		"the grant block"),
	"return grant_initial_kit",
}, "\n"), "=grant"))()

-- The hotbar full of `item` (default one apple) except slot `except`.
local function fill_hotbar(target, except, item)
	local tinv = target:get_inventory()
	for i = 1, 8 do tinv:set_stack("main", i, i == except and "" or item or "default:apple") end
end
-- main[9..] and every sized bag full of torch stacks: no room anywhere.
local function fill_inventory(target)
	local tinv = target:get_inventory()
	for i = 9, 32 do tinv:set_stack("main", i, "default:torch 99") end
	for b = 1, 4 do
		local list = "grug_bag" .. b .. "_content"
		for i = 1, tinv:get_size(list) do tinv:set_stack(list, i, "default:torch 99") end
	end
end
local function count_skills(target, list, from)
	local n, tinv = 0, target:get_inventory()
	for i = from or 1, tinv:get_size(list) do
		if tinv:get_stack(list, i):get_name():match("^grug_abilities:") then n = n + 1 end
	end
	return n
end
local function name_of(target, list, index)
	return target:get_inventory():get_stack(list, index):get_name()
end
local function snapshot(target)
	local tinv, out = target:get_inventory(), {}
	for _, list in ipairs({"main", "grug_bag1_content"}) do
		for i = 1, tinv:get_size(list) do out[#out + 1] = tinv:get_stack(list, i):to_string() end
	end
	return table.concat(out, ",")
end

-- Round 50 D1: grant_to_hotbar (the talent-unlock grant) is gone; the
-- kit's own placement (place_on_hotbar) is checked through grant_initial_kit
-- below and by tools/r49_inv.
check(grug_abilities.grant_to_hotbar == nil, "no talent-unlock grant (Round 50 D1)")

-- The kit after a later class change (initial kit already given).
local changer = H.make_player("changer", "scout", 30, "")
changer:get_meta():set_int("grug_abilities:initial_kit_given", 1)
fill_hotbar(changer, nil, "default:apple 99")
fill_inventory(changer)
grant_initial_kit(changer)
eq(count_skills(changer, "main"), 0, "kit with a full hotbar and no room: nothing placed")
fill_hotbar(changer, 7, "default:apple 99")
changer:get_inventory():set_stack("main", 2, "")
grant_initial_kit(changer)
eq(name_of(changer, "main", 2), "grug_abilities:sprint", "Sprint on its kit slot 2, which is free")
eq(name_of(changer, "main", 7), "grug_abilities:strike",
	"Strike (kit slot 1 taken) on the first free hotbar slot")
eq(count_skills(changer, "main"), 2, "two placed, the others wait in the catalog (no room)")
eq(count_skills(changer, "main", 9), 0, "main[9..] holds no skill")
-- With room in the inventory the full hotbar makes room for each.
local roomy = H.make_player("roomy", "scout", 30, "")
roomy:get_meta():set_int("grug_abilities:initial_kit_given", 1)
fill_hotbar(roomy, nil, "default:apple 99")
grant_initial_kit(roomy)
for slot, id in pairs({[8] = "strike", [7] = "sprint", [6] = "loose", [5] = "snare_shot"}) do
	eq(name_of(roomy, "main", slot), "grug_abilities:" .. id, "kit with room: slot " .. slot)
end
for slot = 9, 12 do
	eq(roomy:get_inventory():get_stack("main", slot):to_string(), "default:apple 99",
		"kit with room: an apple stack moved to main[" .. slot .. "]")
end
eq(count_skills(roomy, "main", 9), 0, "kit with room: main[9..] holds no skill")

-- Character creation: the starter supplies on hotbar 7 and 8 (grug_factions,
-- Round 49), the kit in kit order on the hotbar.
local fresh = H.make_player("fresh", "scout", 1, "")
fresh:get_inventory():set_stack("main", 7, "default:apple 10")
fresh:get_inventory():set_stack("main", 8, "default:torch 10")
grant_initial_kit(fresh)
for index, id in ipairs({"strike", "sprint", "loose", "snare_shot"}) do
	eq(name_of(fresh, "main", index), "grug_abilities:" .. id, "creation kit slot " .. index)
end
eq(fresh:get_inventory():get_stack("main", 7):to_string(), "default:apple 10",
	"the apples stay on slot 7")
eq(fresh:get_inventory():get_stack("main", 8):to_string(), "default:torch 10",
	"the torches stay on slot 8")
eq(fresh:get_meta():get_int("grug_abilities:initial_kit_given"), 1, "the kit is given")

-- A talent unlock through grug_skills places nothing (Round 50 D1): with a
-- free hotbar slot, a full hotbar or a full inventory alike it waits in the
-- catalog, and the feed says where to find it.
local function unlock(name, hotbar_free, item, full_inventory)
	local p = H.make_player(name, "scout", 30, "quarry_bowcraft=2")
	H.join(p)
	fill_hotbar(p, hotbar_free, item)
	if full_inventory then fill_inventory(p) end
	local ok = grug_classes.spend_talent(p, "quarry_true_draw")
	check(ok, name .. ": True Draw ranked")
	return p
end
for _, case in ipairs({{"lucky", 4}, {"pushed", nil, "default:apple 99"},
		{"full", nil, "default:apple 99", true}}) do
	local p = unlock(case[1], case[2], case[3], case[4])
	eq(count_skills(p, "main"), 0, case[1] .. ": the unlock is not placed")
	has(p.feed and p.feed[#p.feed], "Drag it from Talents & Skills onto your hotbar",
		case[1] .. ": the feed points to the catalog")
	local cat = H.catalog(case[1]).inv
	local listed = false
	for i = 1, cat:get_size("catalog") do
		if cat:get_stack("catalog", i):get_name() == "grug_abilities:true_draw" then listed = true end
	end
	check(listed, case[1] .. ": the catalog lists the unlocked skill")
end

print(("bytes: Talents & Skills page (level-30 Scout, 15 ranks in Quarry) %d"):format(page_bytes))
if failures > 0 then
	error(("r44_ts: %d checks, %d failures"):format(checks, failures), 0)
end
print(("r44_ts: %d checks, 0 failures"):format(checks))
