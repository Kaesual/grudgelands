-- Round 44 lane TS portable test: the Talents & Skills tab. Loads, through
-- tools/r44_ts/harness.lua, the REAL sfinv, grug_inventory/ui.lua (frame and
-- views), the talent files, talents_ui.lua and grug_skills, plus the grant
-- code cut out of grug_abilities/init.lua, and checks:
--   1. the tree framework on a small tree with a branch (a node with two
--      parents and two children, two sections): node rectangles, connector
--      segments (down, across, down; one straight segment in a column),
--      every segment between the parent's bottom and the child's top;
--   2. today's data: a class's two trees as two sections of two linear
--      chains, drawn with the connectors before (under) the nodes, one
--      style per node state, a node click buys a rank;
--   3. one tab: grug_classes:talents is "Talents & Skills", the old Skills
--      page is gone; the catalog row (abilities only, no mounts) under the
--      tree text and above the short inventory, on the hotbar's columns;
--   4. the hotbar-only rule for each target list (hotbar, main[9..], every
--      bag, the potion belt, craft, equipment, the quiver), swaps, puts from
--      the catalog, one copy; mount items keep main and bags; and, on a
--      model of the engine's move (inventorymanager.cpp IMoveAction::apply),
--      a drag from the catalog onto the hotbar and a drag back that removes;
--   5. grants: grant_to_hotbar and grant_initial_kit with a free and with a
--      full hotbar (never main[9..] or a bag), and a talent unlock through
--      grug_skills (onto the hotbar, or the catalog when it is full).
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
-- 1. The framework on a small tree with a branch.
--

local area = {x = 0, y = 1, w = 10.3, section_gap = 0.3, pad = 0.1, col_gap = 0.2,
	node_h = 0.8, row_gap = 0.4, line = 0.1}
local sections = {{id = "left"}, {id = "right"}}
local nodes = {
	{id = "a", section = "left", row = 1, col = 1},
	{id = "b", section = "left", row = 1, col = 2},
	{id = "c", section = "left", row = 2, col = 1, requires = {"a", "b"}},
	{id = "d", section = "left", row = 3, col = 1, requires = {"c"}},
	{id = "e", section = "left", row = 3, col = 2, requires = {"c"}},
	{id = "f", section = "right", row = 1, col = 1},
	{id = "g", section = "right", row = 2, col = 1, requires = {"f"}},
}
local layout = grug_classes.layout_tree(sections, nodes, area)
local left, right = layout.sections.left, layout.sections.right
near(left.w, 5, "sections share the width")
near(right.x, 5.3, "the second section beside the first")
near(left.node_w, (5 - 0.2 - 0.2) / 2, "two columns in the left section")
near(right.node_w, 5 - 0.2, "one column in the right section")
local function rect(id) return layout.nodes[id] end
near(rect("a").x, 0.1, "a: column 1")
near(rect("b").x, 0.1 + left.node_w + 0.2, "b: column 2")
near(rect("c").y, 1 + 1.2, "c: row 2")
near(rect("e").y, 1 + 2.4, "e: row 3")
near(rect("g").x, 5.4, "g in the right section")
near(layout.bottom, 1 + 3 * 1.2 - 0.4, "the tree's bottom after three rows")
eq(#layout.connectors, 5, "one connector per requirement")

local by_pair = {}
for _, connector in ipairs(layout.connectors) do
	by_pair[connector.from .. ">" .. connector.to] = connector.segments
	local parent, child = rect(connector.from), rect(connector.to)
	for index, s in ipairs(connector.segments) do
		check(s.y >= parent.y + parent.h - 1e-9 and s.y + s.h <= child.y + 1e-9,
			connector.from .. ">" .. connector.to .. " segment " .. index ..
			" runs between the parent's bottom and the child's top")
		check(s.w > 0 and s.h > 0, connector.from .. ">" .. connector.to ..
			" segment " .. index .. " has a size")
	end
end
local function center(id) return rect(id).x + rect(id).w / 2 end
local straight = by_pair["a>c"]
eq(#straight, 1, "a > c: one straight segment in a column")
near(straight[1].x + straight[1].w / 2, center("a"), "a > c at the column's center")
near(straight[1].y, rect("a").y + 0.8, "a > c from a's bottom")
near(straight[1].y + straight[1].h, rect("c").y, "a > c into c's top")
local bent = by_pair["b>c"]
eq(#bent, 3, "b > c: down, across, down")
near(bent[1].x + bent[1].w / 2, center("b"), "down from b's center")
near(bent[2].y + bent[2].h / 2, rect("c").y - 0.2, "across in the gap above c's row")
near(bent[2].x, center("c") - 0.05, "the across starts at c's center")
near(bent[2].x + bent[2].w, center("b") + 0.05, "and ends at b's center")
near(bent[3].x + bent[3].w / 2, center("c"), "down into c's center")
near(bent[3].y + bent[3].h, rect("c").y, "ending at c's top")
eq(#by_pair["c>d"], 1, "c > d straight")
eq(#by_pair["c>e"], 3, "c > e bends to the second column")
near(by_pair["c>e"][1].y, rect("c").y + 0.8, "both children leave from c's bottom")
eq(#by_pair["f>g"], 1, "the right section's chain")

--
-- 2. Today's data, rendered.
--

local scout = H.make_player("scout", "scout", 30, "strong_draw=5,cold_eye=4,twin_shot=3,quiver=3")
H.join(scout)
local trees = grug_classes.trees_of_class("scout")
local data_sections, data_nodes = grug_classes.talent_tree_data(trees)
eq(#data_sections, 2, "two sections: the class's two trees")
eq(#data_nodes, 16, "sixteen nodes")
local data_layout = grug_classes.layout_tree(data_sections, data_nodes)
local links = 0
for _, node in ipairs(data_nodes) do
	local def = grug_classes.registered_talents[node.id]
	eq(node.row, def.tier, node.id .. ": row = tier")
	eq(def.chain, grug_classes.registered_trees[def.tree].chains[node.col],
		node.id .. ": column = chain")
	eq(#node.requires, def.tier > 1 and 1 or 0, node.id .. ": requires the talent above")
	if def.above then eq(node.requires[1], def.above.id, node.id .. ": its parent") end
	links = links + #node.requires
end
eq(#data_layout.connectors, links, "a connector per chain link")
for _, connector in ipairs(data_layout.connectors) do
	eq(#connector.segments, 1, connector.from .. ">" .. connector.to .. ": straight down its chain")
end
check(data_layout.bottom <= 7.0, "the tree ends before the page text")

local context = sfinv.get_or_create_context(scout)
local form = H.render(scout, "grug_classes:talents")
local page_bytes = #form
local first_node = form:find("image_button[", 1, true)
local last_box, connector_boxes = 0, 0
for start, color in form:gmatch("()box%[[^%]]-;(#%x+)%]") do
	if color == "#c9a65a" or color == "#5a5a5a" then
		connector_boxes = connector_boxes + 1
		last_box = math.max(last_box, start)
	end
end
eq(connector_boxes, 12, "twelve connector boxes")
check(first_node and last_box < first_node, "the connectors are drawn before the nodes")
local buttons = 0
for _ in form:gmatch("image_button%[") do buttons = buttons + 1 end
eq(buttons, 16, "sixteen node buttons")
has(form, "blank.png;grug_talent_pick_", "nodes are image buttons")
has(form, "Twin Shot *\n3/3]", "a node shows its name, mark and rank")
has(form, "label[0.40,1.23;Quarry — 15 points]", "a section title with its points")
for _, chain in ipairs({"Draw", "Ranging", "Blade", "Shadow"}) do
	check(form:find("label%[[%d.]+,1%.63;" .. chain .. "%]") ~= nil, "the column label " .. chain)
end
near(data_layout.sections.quarry.columns[2] + 0.05,
	tonumber(form:match("label%[([%d.]+),1%.63;Ranging%]")), "Ranging over its column")
local styles = 0
for _ in form:gmatch("style%[grug_talent_pick_") do styles = styles + 1 end
eq(styles, 3, "one style per node state (maxed, ranked, locked)")
eq(form:find("grug_talent_tree_", 1, true), nil, "no tree switch: both trees at once")

-- A click on an available node buys a rank and selects it.
local learner = H.make_player("learner", "scout", 30, "")
H.join(learner)
local lctx = sfinv.get_or_create_context(learner)
H.render(learner, "grug_classes:talents")
local field
for index, id in ipairs(grug_classes.talent_ids) do
	if id == "fine_edge" then field = "grug_talent_pick_" .. index end
end
sfinv.pages["grug_classes:talents"]:on_player_receive_fields(learner, lctx, {[field] = "x"})
eq(grug_classes.talent_rank(learner, "fine_edge"), 1, "the click bought a rank")
eq(lctx.grug_talent_selected, "fine_edge", "and selected the node")
has(learner.formspec, "style[" .. field .. ";bgcolor=#8a682f", "the selected node is gold")
-- A refused click selects the node and shows its text and the reason.
local locked_field
for index, id in ipairs(grug_classes.talent_ids) do
	if id == "untouchable" then locked_field = "grug_talent_pick_" .. index end
end
sfinv.pages["grug_classes:talents"]:on_player_receive_fields(learner, lctx, {[locked_field] = "x"})
eq(grug_classes.talent_rank(learner, "untouchable"), 0, "a locked node buys nothing")
eq(lctx.grug_talent_notice, nil, "no notice replaces the description")
local line = learner.formspec:match("textarea%[[^;]*;[^;]*;;;(.-)%]")
has(line, "Untouchable", "the line names the talent")
has(line, "Below 30% health", "with its text")
has(line, "needs", "and the reason")

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
local list_x, list_y = form:match("list%[detached:grug_skills_scout;catalog;([%d.]+),([%d.]+);8,1;0%]")
check(list_x ~= nil, "the catalog list is on the page")
near(tonumber(list_x), grug_inventory.VIEW_GEOMETRY.x, "on the hotbar's columns")
local text_y, text_h = form:match("textarea%[0.25,([%d.]+);13.00,([%d.]+);")
check(tonumber(list_y) >= tonumber(text_y) + tonumber(text_h), "under the tree's text")
check(tonumber(list_y) + 1 <= 9.5, "above the short inventory (9.5)")
check(form:find("list[detached:grug_skills_scout", 1, true) >
	form:find("real_coordinates[false]", 1, true), "drawn after the view, in the page content")
has(form, "list[current_player;main;0,0.000;8,3;8]", "the short inventory below")
local catalog = H.catalog("scout")
eq(catalog.inv:get_size("catalog"), 4, "four unlocked abilities, no mount")
for i = 1, 4 do
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

local abilities_src = read("mods/PLAYER/grug_abilities/init.lua")
local function cut(pattern, label)
	local block = abilities_src:match(pattern)
	check(block ~= nil, label .. " found in grug_abilities/init.lua")
	return block or ""
end
local grant_initial_kit = assert(loadstring(table.concat({
	cut("\n(local function representation_lists%(%).-\nend)\n", "representation_lists"),
	cut("\n(local META_INITIAL_KIT = .-\n)\n", "META_INITIAL_KIT"),
	cut("\n(local function insert_initial_ability%(.-\nend)\n", "insert_initial_ability"),
	cut("\n(local function place_on_hotbar%(.-\nend)\n\ngrug_classes%.register_on_class_chosen",
		"the grant block"),
	"return grant_initial_kit",
}, "\n"), "=grant"))()

local function fill_hotbar(target, except)
	local tinv = target:get_inventory()
	for i = 1, 8 do tinv:set_stack("main", i, i == except and "" or "default:apple") end
end
local function count_skills(target, list)
	local n, tinv = 0, target:get_inventory()
	for i = 1, tinv:get_size(list) do
		if tinv:get_stack(list, i):get_name():match("^grug_abilities:") then n = n + 1 end
	end
	return n
end
local function main_tail_empty(target)
	local tinv = target:get_inventory()
	for i = 9, 32 do
		if not tinv:get_stack("main", i):is_empty() then return false end
	end
	return true
end

local granted = H.make_player("granted", "scout", 30, "")
granted:get_inventory():set_size("grug_bag1_content", 8)
fill_hotbar(granted, 6)
eq(grug_abilities.grant_to_hotbar(granted, "sprint"), 6, "grant_to_hotbar: the free slot")
eq(granted:get_inventory():get_stack("main", 6):get_name(), "grug_abilities:sprint", "placed there")
eq(grug_abilities.grant_to_hotbar(granted, "sprint"), nil, "not when already carried")
eq(grug_abilities.grant_to_hotbar(granted, "loose"), nil, "a full hotbar: nowhere")
check(main_tail_empty(granted), "never main[9..]")
eq(count_skills(granted, "grug_bag1_content"), 0, "never a bag")

-- The kit after a later class change (initial kit already given).
local changer = H.make_player("changer", "scout", 30, "")
changer:get_meta():set_int("grug_abilities:initial_kit_given", 1)
fill_hotbar(changer)
grant_initial_kit(changer)
eq(count_skills(changer, "main"), 0, "kit with a full hotbar: nothing placed")
check(main_tail_empty(changer), "kit with a full hotbar: main[9..] untouched")
fill_hotbar(changer, 7)
changer:get_inventory():set_stack("main", 2, "")
grant_initial_kit(changer)
eq(changer:get_inventory():get_stack("main", 2):get_name(), "grug_abilities:sprint",
	"Sprint on its kit slot 2, which is free")
eq(changer:get_inventory():get_stack("main", 7):get_name(), "grug_abilities:strike",
	"Strike (kit slot 1 taken) on the first free hotbar slot")
eq(count_skills(changer, "main"), 2, "two placed, the others wait in the catalog")
check(main_tail_empty(changer), "main[9..] still untouched")

-- Character creation: supplies in main[9..] (the give helper's order), the
-- kit in kit order on the hotbar.
local fresh = H.make_player("fresh", "scout", 1, "")
fresh:get_inventory():set_stack("main", 9, "default:torch")
grant_initial_kit(fresh)
for index, id in ipairs({"strike", "sprint", "loose", "snare_shot"}) do
	eq(fresh:get_inventory():get_stack("main", index):get_name(), "grug_abilities:" .. id,
		"creation kit slot " .. index)
end
eq(fresh:get_inventory():get_stack("main", 9):get_name(), "default:torch", "supplies stay")
eq(fresh:get_meta():get_int("grug_abilities:initial_kit_given"), 1, "the kit is given")

-- A talent unlock through grug_skills: onto a free hotbar slot, else the
-- catalog only.
local function unlock(name, hotbar_free)
	local p = H.make_player(name, "scout", 30, "quiver=5,fletching=4,strong_draw=3")
	H.join(p)
	fill_hotbar(p, hotbar_free)
	local ok = grug_classes.spend_talent(p, "pinning_shot")
	check(ok, name .. ": Pinning Shot ranked")
	return p
end
local lucky = unlock("lucky", 4)
eq(lucky:get_inventory():get_stack("main", 4):get_name(), "grug_abilities:pinning_shot",
	"an unlock lands on the free hotbar slot")
has(lucky.feed and lucky.feed[#lucky.feed], "on your hotbar", "the feed says so")
local function unlock_carrying(name)
	local p = H.make_player(name, "scout", 30, "quiver=5,fletching=4,strong_draw=3")
	H.join(p)
	p:get_inventory():set_stack("main", 20, "grug_abilities:pinning_shot")
	check(grug_classes.spend_talent(p, "pinning_shot"), name .. ": Pinning Shot ranked")
	return p
end
local carrier = unlock_carrying("carrier")
has(carrier.feed and carrier.feed[#carrier.feed], "You already carry it",
	"a carried copy gets its own feed line")
eq(carrier:get_inventory():get_stack("main", 1):get_name(), "", "and no second copy")
local full = unlock("full", nil)
eq(count_skills(full, "main"), 0, "a full hotbar: the unlock is not placed")
check(main_tail_empty(full), "and not in main[9..]")
has(full.feed and full.feed[#full.feed], "hotbar is full", "the feed points to the catalog")
local fcat = H.catalog("full").inv
local listed = false
for i = 1, fcat:get_size("catalog") do
	if fcat:get_stack("catalog", i):get_name() == "grug_abilities:pinning_shot" then listed = true end
end
check(listed, "the catalog lists the unlocked skill")

print(("bytes: Talents & Skills page (level-30 Scout, 15 ranks) %d"):format(page_bytes))
if failures > 0 then
	print(("r44_ts: %d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("r44_ts: %d checks, 0 failures"):format(checks))
