-- Packed containers (Round 50 lane PGAME, docs/planning/round50-plan.md
-- rulings 5-8, D5-D7 and §3). Before a map reset the migration tool packs
-- every container of every claim into one item, grug_housing:packed_container,
-- which waits in its owner's Claim Stone inventory (recovered.lua). Its item
-- meta carries
--   node    the container's node name
--   lists   core.serialize'd {list name = {item string, ...}}, slot order kept
--   seq     the tool's pass
-- and, once the first start's clean-up ran (recovered.lua), `description`
-- ("Packed Chest, 14 stacks" with the contents) and the container's image.
--
-- The item is soulbound (group grug_soulbound, soulbound.lua): it lives only
-- in the carried lists, so chests, stations, mail, trades, the inbox and the
-- vendors refuse it. Dropping it is refused (it stays, unlike the Claim
-- Stone). Placing it restores the container through the node's own placement
-- (core.item_place_node: protection, on_construct, after_place_node, so a
-- locked chest belongs to the placer) and then fills its lists; a failed
-- placement keeps the item. D7: a furnace comes back unlit with its fuel in
-- the fuel list (its timer starts at the player's first touch), a locked
-- chest's old owner and every node's facing are not restored.

local P = {}
grug_housing.packed = P

P.ITEM = "grug_housing:packed_container"
-- What D6's extra stacks and an unrestorable node's stacks are packed into.
P.CHEST = "default:chest"

-- The containers this version restores, with the list sizes their
-- on_construct sets (tools/r50_pgame pins them to the vendored code). The
-- clean-up (recovered.lua) moves every stack beyond a size, or in a list the
-- node does not have, into additional packed chests (D6); a node not listed
-- here, nor dropping one that is (an open chest, a lit furnace), is packed
-- into chests whole.
P.CONTAINER_LISTS = {
	["default:chest"] = {main = 32},
	["default:chest_locked"] = {main = 32},
	["default:furnace"] = {src = 1, fuel = 1, dst = 4},
	["default:bookshelf"] = {books = 16},
	["vessels:shelf"] = {vessels = 16},
}

-- How many content lines the tooltip names before "and N more".
P.TOOLTIP_LINES = 8
local CONTENT_COLOR = "#c8c8c8"
local NOTE_COLOR = "#a0a0a0"

-- Whether this version knows the item (an alias counts: ItemStack resolves it).
function P.registered(name)
	return name ~= "" and (core.registered_items[name] ~= nil or
		(core.registered_aliases or {})[name] ~= nil)
end

-- The node a packed `node` is restored as: itself when it is a listed
-- container, else the listed container it drops (an open chest, a lit
-- furnace), else nil.
function P.restorable(node)
	if P.CONTAINER_LISTS[node] then return node end
	local def = core.registered_nodes[node]
	if def and type(def.drop) == "string" and def.drop ~= "" then
		local base = ItemStack(def.drop):get_name()
		if P.CONTAINER_LISTS[base] and core.registered_nodes[base] then return base end
	end
	return nil
end

-- The packed lists of a stack: {list name = {[index] = item string}}; an
-- unreadable value counts as empty.
function P.lists(stack)
	local text = stack:get_meta():get_string("lists")
	local lists = text ~= "" and core.deserialize(text, true) or nil
	if type(lists) ~= "table" then return {} end
	local result = {}
	for listname, list in pairs(lists) do
		if type(listname) == "string" and type(list) == "table" then
			local copy = {}
			for index, item in pairs(list) do
				if type(index) == "number" and type(item) == "string" then copy[index] = item end
			end
			result[listname] = copy
		end
	end
	return result
end

-- The highest index of a sparse list.
local function last_index(list)
	local last = 0
	for index in pairs(list) do
		if index > last then last = index end
	end
	return last
end

-- Every non-empty stack of `lists`, list names sorted, slots in order.
function P.stacks(lists)
	local names, result = {}, {}
	for listname in pairs(lists) do names[#names + 1] = listname end
	table.sort(names)
	for _, listname in ipairs(names) do
		local list = lists[listname]
		for index = 1, last_index(list) do
			local stack = ItemStack(list[index] or "")
			if not stack:is_empty() then result[#result + 1] = stack end
		end
	end
	return result
end

-- A new packed item for `node` with `lists`, of pass `seq`.
function P.make(node, lists, seq)
	local stack = ItemStack(P.ITEM)
	local meta = stack:get_meta()
	meta:set_string("node", node)
	meta:set_string("lists", core.serialize(lists))
	meta:set_string("seq", tostring(seq or ""))
	return stack
end

local function first_line(text)
	return (tostring(text or ""):match("^[^\n]*"))
end

local function tile_name(tile)
	if type(tile) == "table" then tile = tile.name or tile.image end
	return type(tile) == "string" and tile or nil
end

-- The container's look as an item image: its own inventory image, else a
-- cube of its tiles (top, front, right side, as the engine draws a block in
-- the inventory); nil when the node has neither (the item's own icon then).
function P.image(node)
	local def = core.registered_nodes[node]
	if not def then return nil end
	if type(def.inventory_image) == "string" and def.inventory_image ~= "" then
		return def.inventory_image
	end
	if def.drawtype ~= nil and def.drawtype ~= "normal" then return nil end
	local tiles = def.tiles or {}
	local top = tile_name(tiles[1])
	if not top then return nil end
	local front = tile_name(tiles[6]) or tile_name(tiles[#tiles]) or top
	local side = tile_name(tiles[3]) or tile_name(tiles[#tiles]) or top
	-- [inventorycube takes "&" for "^" inside its parts.
	local function part(name) return (name:gsub("%^", "&")) end
	return "[inventorycube{" .. part(top) .. "{" .. part(front) .. "{" .. part(side)
end

-- The tooltip: "Packed <container>, N stacks", up to TOOLTIP_LINES stacks,
-- the rest counted, and how to unpack it.
function P.description(node, lists)
	local def = core.registered_nodes[node]
	local label = def and first_line(def.description) or node
	if label == "" then label = node end
	local stacks = P.stacks(lists)
	local lines = {("Packed %s, %s"):format(label, #stacks == 0 and "empty" or
		#stacks == 1 and "1 stack" or #stacks .. " stacks")}
	for index = 1, math.min(#stacks, P.TOOLTIP_LINES) do
		local stack = stacks[index]
		local text = first_line(stack:get_short_description())
		if stack:get_count() > 1 then text = text .. " ×" .. stack:get_count() end
		lines[#lines + 1] = core.colorize(CONTENT_COLOR, text)
	end
	if #stacks > P.TOOLTIP_LINES then
		lines[#lines + 1] = core.colorize(CONTENT_COLOR,
			("and %d more"):format(#stacks - P.TOOLTIP_LINES))
	end
	lines[#lines + 1] = core.colorize(NOTE_COLOR, "Place it to unpack it. Soulbound: " ..
		"it cannot be dropped, stored, mailed or sold.")
	return table.concat(lines, "\n")
end

-- Writes the description and the image into `stack`'s meta (the clean-up).
function P.describe(stack)
	local meta = stack:get_meta()
	local node = meta:get_string("node")
	meta:set_string("description", P.description(node, P.lists(stack)))
	local image = P.image(node) or ""
	meta:set_string("inventory_image", image)
	meta:set_string("wield_image", image)
	return stack
end

local function tell(player, text)
	if grug_core.flash then grug_core.flash(player, text) end
	core.chat_send_player(player:get_player_name(), text)
end

-- The packed stacks that do not fit the placed node's inventory: a list it
-- lacks or a slot beyond its size. The clean-up leaves none for a listed
-- container; this only guards against a list size that changed since.
local function misfits(inv, lists)
	for listname, list in pairs(lists) do
		local size = inv:get_size(listname)
		for index, item in pairs(list) do
			if index > size and not ItemStack(item):is_empty() then return true end
		end
	end
	return false
end

-- Places the container at the pointed spot and fills it. Returns the packed
-- stack, one taken on success; unchanged on any failure.
local function on_place(itemstack, placer, pointed_thing)
	-- A click on a door, a chest or a station opens it, unless sneaking.
	local clicked = grug_core.node_rightclick(itemstack, placer, pointed_thing)
	if clicked then return clicked end
	if not placer or not placer:is_player() or not pointed_thing or
			pointed_thing.type ~= "node" then
		return itemstack
	end
	local meta = itemstack:get_meta()
	local node = meta:get_string("node")
	if not P.CONTAINER_LISTS[node] or not core.registered_nodes[node] then
		-- The clean-up turns every other node into packed chests (D6).
		tell(placer, "This packed container cannot be unpacked here.")
		return itemstack
	end
	local lists = P.lists(itemstack)
	local _, pos = core.item_place_node(ItemStack(node), placer, pointed_thing)
	if not pos then return itemstack end
	local inv = core.get_meta(pos):get_inventory()
	if misfits(inv, lists) then
		core.remove_node(pos)
		tell(placer, "This packed container no longer fits its contents.")
		core.log("warning", ("[grug_housing] packed %s of %s does not fit at %s; kept"):format(
			node, placer:get_player_name(), core.pos_to_string(pos)))
		return itemstack
	end
	local def = core.registered_nodes[node]
	for listname, list in pairs(lists) do
		local first
		for index, item in pairs(list) do
			local stack = ItemStack(item)
			if not stack:is_empty() then
				inv:set_stack(listname, index, stack)
				first = first or {index = index, stack = stack}
			end
		end
		-- The shelves count their contents into the infotext on a put; a
		-- timer node (the furnace) starts at the player's first touch (D7).
		if first and def.on_metadata_inventory_put and not def.on_timer then
			def.on_metadata_inventory_put(pos, listname, first.index, first.stack, placer)
		end
	end
	core.log("action", ("[grug_housing] %s unpacked %s at %s"):format(
		placer:get_player_name(), node, core.pos_to_string(pos)))
	itemstack:take_item(1)
	return itemstack
end

core.register_craftitem(P.ITEM, {
	description = "Packed Container\nPlace it to unpack it. Soulbound: it " ..
		"cannot be dropped, stored, mailed or sold.",
	-- The packed chest's look; a packed item shows its own container's
	-- image through its meta (P.describe).
	inventory_image = "[inventorycube{default_chest_top.png{default_chest_front.png" ..
		"{default_chest_side.png",
	stack_max = 1,
	groups = {not_in_creative_inventory = 1, grug_soulbound = 1},
	-- The server restores the node; no client guess.
	node_placement_prediction = "",
	on_place = on_place,
	-- Ruling 6: refused, the item stays.
	on_drop = function(itemstack, dropper)
		if dropper and dropper:is_player() then
			tell(dropper, "A packed container cannot be dropped: place it to unpack it.")
		end
		return itemstack
	end,
})
