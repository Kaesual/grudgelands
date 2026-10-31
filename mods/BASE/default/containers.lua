-- default/containers.lua

-- GRUG PATCH (whole file, Round 67 lane CONTAINERS; round67-plan.md rulings
-- 27-33): the tiers, labels, sort and upgrade of the storage containers.
-- Chests, locked chests, bookshelves and vessels shelves come in three tiers
-- on the same models, only the textures differ: Wooden (32 slots),
-- Steel-Reinforced (T3, 64) and Abyssal (T6, 96). Their forms show the
-- container's list 8 wide, four rows at a time, more rows scroll
-- (grug_inventory.station_list), and below it one action row: on chests a
-- label and Sort, on every container below the last tier an Upgrade that
-- charges 8 bars of the next tier and swaps the node in place. swap_node
-- keeps the meta and the contents (lua_api.md core.swap_node) and the grown
-- list keeps its items (InventoryList::setSize, src/inventory.cpp, resizes
-- the item vector). The registering files (chests.lua, nodes.lua,
-- vessels/init.lua) call `register`; their forms call `form`, their field
-- handlers `receive`. grug_inventory and grug_core are used at run time
-- only, as the other node forms do.

local S = default.get_translator

local api = {}
default.containers = api

-- The tiers: the node name's suffix, the name's prefix word, the slots and
-- the bar an upgrade into the tier costs (UPGRADE_BARS of it).
api.TIERS = {
	{suffix = "", slots = 32},
	{suffix = "_steel", title = "Steel-Reinforced", slots = 64,
		bar = "grug_materials:steel_bar"},
	{suffix = "_abyssal", title = "Abyssal", slots = 96,
		bar = "grug_materials:abyssal_steel_bar"},
}
api.UPGRADE_BARS = 8
api.VISIBLE_ROWS = 4
-- The label (ruling 28 and the coordinator default): node meta, at most this
-- many characters, shown on the chest's front (grug_text, Round 68).
api.LABEL_KEY = "grug_label"
api.LABEL_MAX = 40

local FIELDS = {label = "grug_container_label", save = "grug_container_save",
	sort = "grug_container_sort", upgrade = "grug_container_upgrade",
	focus = "grug_container_focus"}
api.FIELDS = FIELDS

-- [node name] = {base = the wooden tier's node, tier, name = the closed
-- node, list, kind = "chest", "locked" or "shelf", open = true for a chest's
-- open variant, refresh = fn(pos) after an upgrade (the hover text)}.
local nodes = {}
-- [base][tier] = the closed node of that tier.
local families = {}

-- The node name of `base` (the wooden tier's) at `tier`.
function api.tier_name(base, tier)
	return base .. api.TIERS[tier].suffix
end

-- "Chest", "Steel-Reinforced Chest", "Locked Abyssal Chest", ...
function api.description(noun, tier, prefix)
	local title = api.TIERS[tier].title
	return (prefix and prefix .. " " or "") .. (title and title .. " " or "") .. noun
end

function api.register(name, def)
	local entry = {base = def.base, tier = def.tier, name = name, list = def.list,
		kind = def.kind, refresh = def.refresh}
	nodes[name] = entry
	families[def.base] = families[def.base] or {}
	families[def.base][def.tier] = name
	if def.open then
		local open = {}
		for key, value in pairs(entry) do open[key] = value end
		open.open = true
		nodes[def.open] = open
	end
end

-- The entry of a container node, or nil.
function api.info(name)
	return nodes[name]
end

-- A container's list grows to its tier's size, never shrinks (shelves made
-- before Round 67 have 16 slots; ruling 29 makes them 32).
function api.ensure_size(pos)
	local entry = nodes[core.get_node(pos).name]
	if not entry then return end
	local inv = core.get_meta(pos):get_inventory()
	local slots = api.TIERS[entry.tier].slots
	if inv:get_size(entry.list) < slots then inv:set_size(entry.list, slots) end
end

--
-- Rights. Sort follows the use of the chest (a claim's "interact" is
-- enough: its items could be moved by hand); the label and the upgrade
-- follow core.is_protected, as writing a sign does (a claim's "everything",
-- inactive and draft claims protect nothing). A locked chest answers only
-- its owner for all three.
--

local function owner_only(pos, entry, name)
	return entry.kind == "locked" and core.get_meta(pos):get_string("owner") ~= name
end

function api.may_sort(pos, player, entry)
	local name = player:get_player_name()
	if entry.kind == "shelf" or owner_only(pos, entry, name) then return false end
	return not grug_core.interaction_guarded(pos, name)
end

function api.may_edit(pos, player, entry)
	local name = player:get_player_name()
	if owner_only(pos, entry, name) then return false end
	if entry.kind == "locked" then return true end
	return not core.is_protected(pos, name)
end

--
-- The label.
--

-- Plain text of at most LABEL_MAX characters: control characters (newlines,
-- colour escapes) become spaces, the ends are trimmed; UTF-8 characters
-- count once (a byte 0x80-0xBF continues one).
function api.clean_label(text)
	text = tostring(text or ""):gsub("%c", " ")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	local count = 0
	for index = 1, #text do
		local byte = text:byte(index)
		if byte < 0x80 or byte >= 0xC0 then
			count = count + 1
			if count > api.LABEL_MAX then
				text = text:sub(1, index - 1):gsub("%s+$", "")
				break
			end
		end
	end
	return text
end

-- A chest's hover text: its name (a locked chest's with its owner).
-- GRUG PATCH (Round 68 follow-up, the user 2026-10-31): the label shows only
-- on the chest's front (grug_text), not in the hover text.
function api.update_infotext(pos)
	local entry = nodes[core.get_node(pos).name]
	if not entry then return end
	local meta = core.get_meta(pos)
	local def = core.registered_nodes[entry.name]
	local text = def and def.description or ""
	local owner = meta:get_string("owner")
	if entry.kind == "locked" and owner ~= "" then
		text = S("@1 (owned by @2)", text, owner)
	end
	meta:set_string("infotext", text)
	-- GRUG PATCH (Round 68 TEXT): the label on the chest's front follows
	-- (grug_text, at run time only like grug_core): a save, a clear and
	-- the upgrade's swap to the next tier's node (its ink) all pass here.
	local text_mod = rawget(_G, "grug_text")
	if text_mod then text_mod.refresh(pos) end
end

--
-- The upgrade (ruling 30).
--

local function first_line(text)
	return (core.strip_colors(text or ""):match("^[^\n]*"))
end

local function bar_name(bar)
	local def = core.registered_items[bar]
	return first_line(def and def.description or bar)
end

-- The bars count and are taken where a crafting cost is: the carried lists,
-- then the inactive hotbar layout (grug_inventory.consume_lists).
local function bars_held(inv, bar)
	local count = 0
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if stack:get_name() == bar then count = count + stack:get_count() end
		end
	end
	return count
end

local function take_bars(inv, bar, count)
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			if count <= 0 then return end
			if stack:get_name() == bar then
				local taken = math.min(count, stack:get_count())
				stack:take_item(taken)
				inv:set_stack(list, index, stack)
				count = count - taken
			end
		end
	end
end

-- The next tier's closed node and tier record, or nil at the last tier.
function api.next_tier(entry)
	local tier = api.TIERS[entry.tier + 1]
	if not tier then return nil end
	return families[entry.base][entry.tier + 1], tier
end

-- The Upgrade button's field names the tier it upgrades to, so a repeated
-- submit (a double click, a slow connection, a second viewer's form sent
-- before the upgrade's re-show) cannot charge for the tier after it.
function api.upgrade_field(tier)
	return FIELDS.upgrade .. "_" .. tier
end

-- Upgrades the container at `pos` for `player` to tier `to` (the next tier
-- only): true, or false and the reason for the player (nil for a stale
-- `to`). Open forms follow (chests.lua retarget, node_formspec retarget
-- and refresh) at their kept scroll position.
function api.upgrade(pos, player, to)
	local node = core.get_node(pos)
	local entry = nodes[node.name]
	if not entry or to ~= entry.tier + 1 then return false end
	local target, tier = api.next_tier(entry)
	if not target then return false end
	if not api.may_edit(pos, player, entry) then
		return false, S("You may not upgrade this container.")
	end
	local inv = player:get_inventory()
	if bars_held(inv, tier.bar) < api.UPGRADE_BARS then
		return false, S("The upgrade needs @1 × @2.", api.UPGRADE_BARS, bar_name(tier.bar))
	end
	take_bars(inv, tier.bar, api.UPGRADE_BARS)
	local name = entry.open and target .. "_open" or target
	core.swap_node(pos, {name = name, param2 = node.param2})
	core.get_meta(pos):get_inventory():set_size(entry.list, tier.slots)
	core.log("action", ("%s upgrades %s to %s at %s"):format(player:get_player_name(),
		node.name, name, core.pos_to_string(pos)))
	-- The open forms first: a shelf's hover text update refreshes them.
	default.node_formspec.retarget(pos, name)
	local upgraded = nodes[name]
	if upgraded and upgraded.refresh then upgraded.refresh(pos) end
	if default.chest and default.chest.retarget then default.chest.retarget(pos, target) end
	default.node_formspec.refresh(pos)
	return true
end

--
-- The form.
--

local ROW_GAP, BUTTON_H = 0.15, 0.65
local SAVE_W, SORT_W, UPGRADE_W, GAP = 1.2, 1.3, 2.7, 0.15

local function esc(text)
	return core.formspec_escape(text)
end

-- The action row at y: the label (an editable field with Save for whoever
-- may edit it, else the label as text), Sort and Upgrade, right-aligned.
local function action_row(pos, player, entry, y)
	local station = grug_inventory.STATION
	local x = station.x
	local right = station.box_x + station.box_w - (station.x - station.box_x)
	local ui = grug_core.ui
	local fs = {}
	local edit = api.may_edit(pos, player, entry)
	local target, tier = api.next_tier(entry)
	local upgrade_x = right - UPGRADE_W
	if target and edit then
		local text_y = y + BUTTON_H / 2
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,%.3f;%s;]"):format(upgrade_x, y,
			UPGRADE_W, BUTTON_H, api.upgrade_field(entry.tier + 1))
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(upgrade_x + 0.2, text_y,
			esc(S("Upgrade")))
		fs[#fs + 1] = ("item_image[%.3f,%.3f;0.45,0.45;%s]"):format(
			upgrade_x + UPGRADE_W - 1.0, y + (BUTTON_H - 0.45) / 2, tier.bar)
		fs[#fs + 1] = ("label[%.3f,%.3f;×%d]"):format(upgrade_x + UPGRADE_W - 0.5,
			text_y, api.UPGRADE_BARS)
		local def = core.registered_nodes[target]
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(api.upgrade_field(entry.tier + 1), esc(S(
			"Upgrade to @1 (@2 slots) for @3 × @4. The contents stay.",
			def and def.description or target, tier.slots, api.UPGRADE_BARS,
			bar_name(tier.bar))))
	end
	if entry.kind == "shelf" then return table.concat(fs) end
	local sort_x = upgrade_x - GAP - SORT_W
	if api.may_sort(pos, player, entry) then
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(sort_x, y, SORT_W,
			BUTTON_H, FIELDS.sort, esc(S("Sort")))
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(FIELDS.sort,
			esc(S("Sort this chest like the inventory.")))
	end
	local label = core.get_meta(pos):get_string(api.LABEL_KEY)
	local save_x = sort_x - GAP - SAVE_W
	if edit then
		local w = save_x - 0.1 - x
		fs[#fs + 1] = ui.input_background(x, y, w, BUTTON_H, FIELDS.label)
		fs[#fs + 1] = ("field[%.3f,%.3f;%.3f,%.3f;%s;;%s]"):format(x, y, w, BUTTON_H,
			FIELDS.label, esc(label))
		fs[#fs + 1] = ("field_close_on_enter[%s;false]"):format(FIELDS.label)
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(FIELDS.label, esc(S(
			"Label: shown when pointing at the chest (up to @1 characters)",
			api.LABEL_MAX)))
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(save_x, y, SAVE_W,
			BUTTON_H, FIELDS.save, esc(S("Save")))
	elseif label ~= "" then
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(x, y + BUTTON_H / 2, esc(label))
	end
	return table.concat(fs)
end

-- The container's part of its station form (grug_inventory.station_box at
-- the top: the list, its rings and the action row) and the box's bottom
-- edge. `slot_image` (optional): the picture on each empty slot.
function api.form(pos, player, context, slot_image)
	local entry = nodes[core.get_node(pos).name]
	if not entry then return "", grug_inventory.STATION.margin end
	local station = grug_inventory.STATION
	local location = default.node_formspec.location(pos)
	local inv = core.get_meta(pos):get_inventory()
	local list_h = api.VISIBLE_ROWS * station.pitch - 0.25
	local growth = grug_core.ui.text_growth(player)
	local def = core.registered_nodes[entry.name]
	local box, bottom = grug_inventory.station_box(def and def.description or "",
		list_h + ROW_GAP + BUTTON_H, growth)
	return table.concat({
		box,
		-- An invisible button takes the focus at every send (as the
		-- Inventory page's, 0.45.1): otherwise the engine focuses the label
		-- field, which eats the inventory key, or the last button.
		("set_focus[%s;true]button[0,0;0,0;%s;]"):format(FIELDS.focus, FIELDS.focus),
		grug_inventory.station_list(location, entry.list, inv:get_size(entry.list),
			api.VISIBLE_ROWS, context, slot_image,
			slot_image and inv:get_list(entry.list) or nil),
		"listring[" .. location .. ";" .. entry.list .. "]listring[current_player;grug_inbox]" ..
			"listring[current_player;main]",
		action_row(pos, player, entry, station.y + list_h + ROW_GAP),
	}), bottom
end

--
-- The fields of the action row. `context` is the form session's (the Sort
-- cooldown lives there). Returns true when the fields were the row's.
--

function api.receive(pos, player, fields, context)
	local entry = nodes[core.get_node(pos).name]
	if not entry then return false end
	local at = player:get_pos()
	if not at or vector.distance(at, pos) > default.node_formspec.max_distance then
		return false
	end
	if fields[FIELDS.sort] then
		if api.may_sort(pos, player, entry) then
			context = context or {}
			local now = core.get_us_time()
			if now >= (context.grug_container_sort_ready or 0) then
				context.grug_container_sort_ready = now + grug_inventory.SORT_COOLDOWN_US
				grug_inventory.sort_list(core.get_meta(pos):get_inventory(), entry.list)
			end
		end
		return true
	end
	if fields[FIELDS.label] and entry.kind ~= "shelf" and
			(fields[FIELDS.save] or fields.key_enter_field == FIELDS.label) then
		if api.may_edit(pos, player, entry) then
			core.get_meta(pos):set_string(api.LABEL_KEY, api.clean_label(fields[FIELDS.label]))
			api.update_infotext(pos)
		end
		return true
	end
	for tier = 2, #api.TIERS do
		if fields[api.upgrade_field(tier)] then
			local ok, why = api.upgrade(pos, player, tier)
			if not ok and why then
				grug_core.feed(player, "notice", why, "container_upgrade")
			end
			return true
		end
	end
	return false
end
