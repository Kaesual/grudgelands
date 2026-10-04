-- The Crownbinder (round33-plan.md §2.5, item_tiers.md §4): one in every
-- capital applies a Fallen Crown to one item. The item's level becomes its
-- tier's top + 5 and every enchant gains one tier; the operation itself and
-- its refusals belong to grug_items (lane C4). This file is the NPC's side:
-- which items it is offered, the fee, and the one atomic payment.
--
-- The fee is one hour of band-6 net solo income (item_tiers.md §4, rounded by
-- economy.md §4.1), derived and checked by tools/r29_e4/income.py, plus the
-- Fallen Crown itself.

grug_traders.CROWN_FEE = 14700
grug_traders.CROWN_ITEM = "grug_mobs:fallen_crown"

local FORM_PREFIX = "grug_traders:crown:"
local PAGE_SIZE = 6
local RANGE = 6 -- m, as the trade window

--
-- THE CALLS into the crown operation (grug_items, grug_quality/init.lua):
--   grug_items.crown_preview(stack)       -> preview text | nil, reason
--   grug_items.crown_item(stack, player)  -> crowned copy, preview text
--                                         | nil, refusal reason
-- Both work on a copy and never change the stack they are given.
--
local function crown_api(name)
	local items = rawget(_G, "grug_items")
	return items and type(items[name]) == "function" and items[name] or nil
end
local UNAVAILABLE = "The Crownbinder cannot work on this item."

function grug_traders.crown_preview(stack)
	local preview = crown_api("crown_preview")
	if not preview then return nil, UNAVAILABLE end
	return preview(ItemStack(stack))
end

function grug_traders.crown_operation(stack, player)
	local crown = crown_api("crown_item")
	if not crown then return nil, UNAVAILABLE end
	return crown(ItemStack(stack), player)
end

-- Every list a player owns items in: the main inventory, the equipment slots
-- and the bag contents.
local function owned_lists()
	local lists = {"main"}
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		lists[#lists + 1] = slot.list
	end
	for i = 1, grug_inventory.BAG_COUNT do
		lists[#lists + 1] = grug_inventory.content_list(i)
	end
	return lists
end

local function is_gear(stack)
	return core.get_item_group(stack:get_name(), "grug_gear") > 0
end

-- The first Fallen Crown the player carries: list, index, stack; or nil.
local function find_crown(inv)
	for _, list in ipairs(owned_lists()) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			if stack:get_name() == grug_traders.CROWN_ITEM then
				return list, index, stack
			end
		end
	end
	return nil
end

-- A worn item must stay wearable: the crown raises its level requirement, and
-- the level gate runs only on equip. Returns the refusal, or nil.
local function worn_refusal(player, list, crowned)
	if not grug_inventory.is_equipment_list(list) then return nil end
	local ok, required = grug_core.can_use_item_level(player, crowned)
	if ok then return nil end
	return "The crowned item needs level " .. tostring(required) ..
		"; take it off first."
end

-- Every gear item the player owns, with the operation's preview: a row with
-- `result` and `text` can be crowned, a row with only `reason` cannot.
function grug_traders.crown_rows(player)
	local rows = {}
	local inv = player:get_inventory()
	for _, list in ipairs(owned_lists()) do
		for index, stack in ipairs(inv:get_list(list) or {}) do
			if not stack:is_empty() and is_gear(stack) then
				local text, reason = grug_traders.crown_preview(stack)
				if text and grug_inventory.is_equipment_list(list) then
					local crowned = grug_traders.crown_operation(stack, player)
					reason = crowned and worn_refusal(player, list, crowned) or nil
					if reason then text = nil end
				end
				rows[#rows + 1] = {list = list, index = index,
					expected = ItemStack(stack), result = text ~= nil,
					text = text, reason = reason}
			end
		end
	end
	return rows
end

-- Crowns the item of one row: re-reads the exact stack, asks the operation
-- again, then takes the fee and one Fallen Crown and writes the crowned item
-- in one transaction (grug_money.take_with_inventory). Returns ok, message.
function grug_traders.crown_apply(player, row)
	if not row then return false, "Choose an item." end
	local inv = player:get_inventory()
	local current = inv:get_stack(row.list, row.index)
	if not current:equals(row.expected) then
		return false, "That item has changed. Look again."
	end
	local crowned, reason = grug_traders.crown_operation(current, player)
	if not crowned then return false, reason end
	local worn = worn_refusal(player, row.list, crowned)
	if worn then return false, worn end
	-- crown_item rebuilds the description; a weapon's "Effective at level"
	-- line is grug_gear's own.
	grug_gear.initialize_weapon_tooltip(crowned, player)
	local crown_list, crown_index, crown_stack = find_crown(inv)
	if not crown_list then
		return false, "You need a Fallen Crown."
	end
	if grug_money.get(player) < grug_traders.CROWN_FEE then
		return false, "You need " .. grug_money.format(grug_traders.CROWN_FEE) .. "."
	end
	local rest = ItemStack(crown_stack)
	rest:take_item(1)
	local ok, failure = grug_money.take_with_inventory(player, grug_traders.CROWN_FEE, {
		{list = row.list, index = row.index, expected = current, replacement = crowned},
		{list = crown_list, index = crown_index, expected = crown_stack, replacement = rest},
	})
	if not ok then return false, failure end
	if grug_inventory.is_equipment_list(row.list) then
		grug_inventory.equipment_changed(player)
	end
	return true, "Crowned: " .. (crowned:get_short_description() or crowned:get_name()) .. "."
end

--
-- The window
--

local sessions, serial = {}, 0

local function esc(text) return core.formspec_escape(tostring(text or "")) end

local function first_line(stack)
	return stack:get_short_description() or stack:get_name()
end

local function form(player, session)
	local rows = session.rows
	local pages = math.max(1, math.ceil(#rows / PAGE_SIZE))
	session.page = math.max(1, math.min(pages, session.page))
	local _, _, crown = find_crown(player:get_inventory())
	local fs = {"formspec_version[4]size[12,9.4]",
		"label[0.4,0.45;Crownbinder]",
		"label[0.4,0.95;" .. esc("\"A crown remembers its king. Lend me one, " ..
			"and your gear will remember it too.\"") .. "]",
		"label[0.4,1.45;" .. esc("Fee: " .. grug_money.format(grug_traders.CROWN_FEE) ..
			" and one Fallen Crown. Once per item.") .. "]",
		"label[0.4,1.9;" .. esc("Your money: " ..
			grug_money.format(grug_money.get(player)) .. "    Fallen Crown: " ..
			(crown and "yes" or "none")) .. "]"}
	local first = (session.page - 1) * PAGE_SIZE + 1
	for i = first, math.min(#rows, first + PAGE_SIZE - 1) do
		local row, y = rows[i], 2.4 + (i - first) * 0.9
		fs[#fs + 1] = ("item_image[0.4,%.2f;0.8,0.8;%s]"):format(y, esc(row.expected:get_name()))
		fs[#fs + 1] = ("label[1.4,%.2f;%s]"):format(y + 0.2, esc(first_line(row.expected)))
		-- A read-only textarea wraps the preview ("Item level 50 becomes 55.
		-- Strength becomes T7. ...") inside the row.
		fs[#fs + 1] = ("textarea[1.4,%.2f;8,0.55;;;%s]"):format(y + 0.4,
			esc(row.result and (row.text or "") or (row.reason or "")))
		if row.result then
			fs[#fs + 1] = ("button[9.6,%.2f;2,0.8;crown_%d;Crown]"):format(y, i)
		end
	end
	if #rows == 0 then
		fs[#fs + 1] = "label[0.4,2.8;You carry no equipment.]"
	end
	if session.status then
		fs[#fs + 1] = "label[0.4,8.55;" .. esc(session.status) .. "]"
	end
	fs[#fs + 1] = "button[4.2,8.2;0.7,0.7;previous;<]button[6.6,8.2;0.7,0.7;next;>]"
	fs[#fs + 1] = ("label[5.25,8.55;%d / %d]"):format(session.page, pages)
	fs[#fs + 1] = "button_exit[9.6,8.2;2,0.7;close;Close]"
	return table.concat(fs)
end

local function show(player, session)
	core.show_formspec(player:get_player_name(), session.formname, form(player, session))
end

local function permitted(player, session)
	if not player or not player:is_player() or player:get_hp() <= 0 then
		return false
	end
	local pos = player:get_pos()
	if not pos or vector.distance(pos, session.pos) > RANGE then return false end
	return grug_factions.serves(session.faction, player)
end

-- Opened by the NPC (vendors.lua): `faction` is the faction it serves.
function grug_traders.open_crownbinder(player, nametag, pos, faction)
	if not player or not player:is_player() or not pos then return end
	if not grug_factions.serves(faction, player) then
		grug_factions.refuse(player, nametag, faction)
		return
	end
	serial = serial + 1
	local session = {pos = vector.new(pos), faction = faction, page = 1,
		formname = FORM_PREFIX .. serial, rows = grug_traders.crown_rows(player)}
	sessions[player:get_player_name()] = session
	show(player, session)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #FORM_PREFIX) ~= FORM_PREFIX then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session or session.formname ~= formname then return true end
	if fields.quit or not permitted(player, session) then
		sessions[name] = nil
		return true
	end
	-- One action per packet, from the rows actually rendered.
	for i = 1, #session.rows do
		if fields["crown_" .. i] then
			local ok, message = grug_traders.crown_apply(player, session.rows[i])
			if ok then grug_core.feed(player, "notice", message, "crown") end
			session.rows = grug_traders.crown_rows(player)
			session.status = message
			show(player, session)
			return true
		end
	end
	if fields.next or fields.previous then
		session.page = session.page + (fields.next and 1 or -1)
		show(player, session)
	end
	return true
end)

local function clear(player) sessions[player:get_player_name()] = nil end
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
