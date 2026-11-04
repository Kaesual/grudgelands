-- The trash box of the Inventory tab (Round 69 rulings 1-2, spec
-- docs/design/inventory_equipment.md): one detached list per player, shown
-- only to that player, like the deposit slot (grug_money/coins.lua). A stack
-- put there leaves the list at once and waits in `sessions` for Undo until
-- the next discard or until the player leaves; nothing of it is saved, and
-- nothing can be taken from the list. No listring names it, so shift-click
-- never reaches it.
--
-- What may not be destroyed stays refused where it always was:
-- grug_housing/soulbound.lua and grug_skills/bound_items.lua wrap every
-- detached inventory's allow_put, and bags.lua answers the player-side half
-- of the move (a bag whose contents have no room stays, with its feed line).

local LIST = "trash"
local HINT_SECONDS = 6
local GHOST = "creative_trash_icon.png^[multiply:#cb9290^[opacity:184"
local GHOST_INSET, GHOST_SIZE = 0.125, 0.75
local TEXT_DX = 1.15 -- from the slot's left edge
local BUTTON_W, BUTTON_H, BUTTON_GAP = 1.7, 0.65, 0.1
local CHAR_W = 0.15 -- a label character on the page, as in the stat column
local NAME_IN_HINT = 16 -- so the longest hint stays three lines beside Undo
local BOUND_HINT = "%s can't be destroyed here: it is bound to you."
local ROOM_HINT = "No room in your inventory: make space, then press Undo."

-- Player name -> {stack = what Undo restores, hint = the danger line,
-- hint_id = which timer may clear it}.
local sessions = {}

local function box_name(name) return "grug_trash_" .. name end

-- The list[] location of the player's trash slot, for the Inventory page.
function grug_inventory.trash_location(player)
	return "detached:" .. box_name(player:get_player_name()), LIST
end

-- By characters (UTF-8), as long names are cut in the crafting list.
local function clip(text, limit)
	local count, cut = 0, nil
	for at in text:gmatch("()[^\128-\191]") do
		count = count + 1
		if count == limit - 1 then cut = at end
	end
	if count <= limit then return text end
	return text:sub(1, cut - 1) .. ".."
end

-- The stack's name and its count text (nothing for a single item).
local function stack_label(stack)
	local count = stack:get_count()
	return grug_core.item_name(stack), count > 1 and (" ×" .. count) or ""
end

local function clear_hint(name, hint_id)
	local session = sessions[name]
	if not session or session.hint_id ~= hint_id then return end
	session.hint = nil
	local player = core.get_player_by_name(name)
	if player then grug_inventory.refresh_inventory_page(player) end
end

local function show_hint(player, session, text)
	session.hint = text
	session.hint_id = (session.hint_id or 0) + 1
	core.after(HINT_SECONDS, clear_hint, player:get_player_name(), session.hint_id)
	grug_inventory.refresh_inventory_page(player)
end

local function discard(player, stack)
	local name = player:get_player_name()
	local session = sessions[name]
	session.stack, session.hint = ItemStack(stack), nil
	core.log("action", ("[grug_inventory] %s destroyed %s x%d"):format(name,
		stack:get_name(), stack:get_count()))
	grug_inventory.refresh_inventory_page(player)
end

-- Back through the give helper; what does not fit stays undoable.
function grug_inventory.trash_undo(player)
	local session = sessions[player:get_player_name()]
	if not session or not session.stack then return end
	local rest = grug_inventory.give(player, session.stack)
	if rest:is_empty() then
		session.stack, session.hint = nil, nil
		grug_inventory.refresh_inventory_page(player)
	else
		session.stack = rest
		show_hint(player, session, ROOM_HINT)
	end
end

-- The guards answer before the box's own allow_put and never call it for a
-- bound stack, so the hint watches their answer from outside. grug_skills
-- would wrap the box later (its render and join walks); walking now puts this
-- wrapper around both guards. builtin keeps the callbacks in
-- core.detached_inventories and the engine reads them there at every action.
local function hint_on_refusal(owner)
	local skills = rawget(_G, "grug_skills")
	if skills then skills.guard_detached() end
	local callbacks = core.detached_inventories[box_name(owner)]
	local guarded = callbacks.allow_put
	callbacks.allow_put = function(inv, listname, index, stack, actor)
		local count = guarded(inv, listname, index, stack, actor)
		if count == 0 and actor and actor:get_player_name() == owner then
			show_hint(actor, sessions[owner],
				BOUND_HINT:format(clip(grug_core.item_name(stack), NAME_IN_HINT)))
		end
		return count
	end
end

core.register_on_joinplayer(function(player)
	local owner = player:get_player_name()
	sessions[owner] = {}
	local box = core.create_detached_inventory(box_name(owner), {
		allow_put = function(_, _, _, stack, actor)
			if not actor or actor:get_player_name() ~= owner then return 0 end
			return stack:get_count()
		end,
		allow_take = function() return 0 end,
		allow_move = function() return 0 end,
		on_put = function(inv, listname, index, stack, actor)
			inv:set_stack(listname, index, ItemStack(""))
			discard(actor, stack)
		end,
	}, owner)
	box:set_size(LIST, 1)
	hint_on_refusal(owner)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	sessions[name] = nil
	core.remove_detached_inventory(box_name(name))
end)

-- What the box says: its lines, their colour, and the tooltip with what a
-- clip cut off. Beside Undo the text has less room.
local function box_text(session, chars)
	local colors = grug_core.ui.colors
	local name, count
	if session.stack then name, count = stack_label(session.stack) end
	if session.hint then
		local lines = {}
		local wrapped = grug_inventory.wrap_text(session.hint, chars)
		for line in wrapped:gmatch("[^\n]+") do
			lines[#lines + 1] = core.colorize(colors.danger, line)
		end
		return lines, session.hint .. (name and "\nUndo returns " .. name .. count or "")
	end
	if name then
		return {core.colorize(colors.muted, "Destroyed:"),
			core.colorize(colors.text, clip(name, chars - #count) .. count)}, name .. count
	end
	return {core.colorize(colors.muted, "Drag an item here to destroy it."),
		core.colorize(colors.muted, "You can undo the last one.")}
end

-- The slot at (x, y), its ghost over the always empty cell, the text and
-- Undo inside `w`. The neighbouring boxes' labels stay at `growth`; the text
-- follows text_scale, because it has to fit the box on a shrunk form too.
function grug_inventory.trash_content(player, x, y, w, growth)
	local esc = core.formspec_escape
	local location, list = grug_inventory.trash_location(player)
	local session = sessions[player:get_player_name()] or {}
	local text_x = x + TEXT_DX
	local text_w = x + w - text_x
	local fs = {
		("list[%s;%s;%.3f,%.3f;1,1;]"):format(location, list, x, y),
		("image[%.3f,%.3f;%.2f,%.2f;%s]"):format(x + GHOST_INSET, y + GHOST_INSET,
			GHOST_SIZE, GHOST_SIZE, esc(GHOST)),
	}
	if session.stack then
		text_w = text_w - BUTTON_W - BUTTON_GAP
		fs[#fs + 1] = grug_core.ui.button_style("grug_trash_undo", "normal", growth)
		fs[#fs + 1] = ("button[%.3f,%.3f;%.2f,%.2f;grug_trash_undo;Undo]"):format(
			x + w - BUTTON_W, y + (1 - BUTTON_H) / 2, BUTTON_W, BUTTON_H)
	end
	local lines, full = box_text(session, math.floor(text_w / CHAR_W))
	local step = #lines > 2 and 0.3 or 0.4
	fs[#fs + 1] = ("style_type[label;font_size=*%.3f]"):format(grug_core.ui.text_scale(player))
	for index, line in ipairs(lines) do
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(text_x,
			y + 0.5 + (index - (#lines + 1) / 2) * step, esc(line))
	end
	fs[#fs + 1] = "style_type[label;font_size=" .. grug_core.ui.font_size(nil, growth) .. "]"
	if full then
		fs[#fs + 1] = ("tooltip[%.3f,%.3f;%.3f,1;%s]"):format(text_x, y, text_w, esc(full))
	end
	return table.concat(fs)
end
