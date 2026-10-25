-- The skill catalog (Round 44, spec ui-crafting-rework-plan.md ruling 8 and
-- §3.4): one row under the talent tree of the Talents & Skills page, which
-- grug_classes/talents_ui.lua draws; this file installs the row as
-- grug_classes.skill_catalog_row. Each unlocked ability has its own slot of
-- a per-player detached list that is an infinite source and an infinite
-- destination: a drag onto a free hotbar slot copies the skill there
-- (bound_items.lua decides where a skill may land and keeps it to one copy),
-- and a drag of the carried copy back onto its own icon removes that copy
-- (the engine undoes the swap such a drop asks for and keeps the catalog's
-- stack). A talent that unlocks an ability leaves it here (Round 50 D1).
-- Mounts and boats are not listed (they move to the quickbar). The row
-- scrolls horizontally, so any number of owned skills fits (Round 52 C13).
local detached = {}
local slots = {} -- player name -> ability id per catalog slot
local known = {} -- player name -> set of ability ids at the last rebuild

local function inv_name(name) return "grug_skills_" .. name end

local function entries(player)
	local result = {}
	for index, id in ipairs(grug_abilities.unlocked_ids(player)) do
		result[index] = id
	end
	return result
end

-- Fills the catalog with fresh stacks of the unlocked abilities.
local function fill(player)
	local name = player:get_player_name()
	local inv = detached[name]
	if not inv then return nil end
	local rows = entries(player)
	slots[name] = rows
	inv:set_size("catalog", #rows)
	for i, id in ipairs(rows) do
		inv:set_stack("catalog", i, grug_abilities.stack_for(player, id))
	end
	return rows
end

-- After an entitlement change. With announce == true (a talent change) the
-- feed names each talent ability unlocked since the last rebuild; it waits
-- in the catalog and is never placed on a hotbar (Round 50 D1: the player
-- chooses the layout and the slot).
local UNLOCK_LINE = " unlocked. Drag it from Talents & Skills onto your hotbar."
local function rebuild(player, announce)
	local name = player:get_player_name()
	local rows = fill(player)
	if not rows then return end
	local before, now = known[name] or {}, {}
	for _, id in ipairs(rows) do
		now[id] = true
		local def = grug_abilities.registered[id]
		if announce == true and def and def.talent_gated and not before[id] then
			grug_core.feed(player, "notice", def.name .. UNLOCK_LINE)
		end
	end
	known[name] = now
end

grug_skills.rebuild = rebuild
local function create(player)
	local name = player:get_player_name()
	local function slot_stack(actor, index)
		local id = slots[name] and slots[name][index]
		return id and grug_abilities.stack_for(actor, id)
	end
	local callbacks = {
		allow_move = function() return 0 end,
		allow_take = function(_, listname, index, stack, actor)
			if not actor or actor:get_player_name() ~= name or listname ~= "catalog" then return 0 end
			local fresh = slot_stack(actor, index)
			if not fresh or fresh:get_name() ~= stack:get_name() then return 0 end
			return -1
		end,
		on_take = function(_, _, index, stack, actor)
			local fresh = slot_stack(actor, index)
			if not fresh then return end
			local inv = actor:get_inventory()
			for i = 1, inv:get_size("main") do
				if inv:get_stack("main", i):get_name() == stack:get_name() then
					inv:set_stack("main", i, fresh); break
				end
			end
		end,
		-- Only the skill of that very slot: a different stack would come back
		-- out of the swap into the player's inventory (the engine's
		-- infinite-source rule), not be removed.
		allow_put = function(_, listname, index, stack, actor)
			if not actor or actor:get_player_name() ~= name or listname ~= "catalog" then return 0 end
			local fresh = slot_stack(actor, index)
			if fresh and fresh:get_name() == stack:get_name() and
					grug_skills.is_entitled(actor, stack) then return -1 end
			return 0
		end,
	}
	detached[name] = core.create_detached_inventory(inv_name(name), callbacks, name)
	rebuild(player)
end

-- The row: the catalog on the hotbar's columns in a "Skills" box like the
-- Hotbar box (grug_inventory.LAYOUT), the hint beside the box's label. `y`
-- is the box's top, in the page's real coordinates; the box is the Hotbar
-- box's height (1.5) plus BAR_H for the scrollbar under the slots.
--
-- The scroll position (Round 52 C13): the slots sit in a horizontal
-- scroll_container as wide as the hotbar's eight; past eight skills a
-- scrollbar below them moves it a slot per step. The client does not keep
-- the bar across a resend but sends its value with every event of the form
-- (grug_inventory/ui.lua keep_scroll), so the hook below keeps it in the
-- sfinv context and the row echoes it: a talent refresh or a rebuild does
-- not jump back to the start. A drag works from any position: the list's
-- slot index does not depend on the scroll.
local HINT_DX = 2.1 -- the hint starts this far right of the "Skills" label
local SCROLL_FIELD = "grug_skills_scroll"
local PITCH = 1.25 -- a list slot and its spacing in real coordinates
local SCROLL_FACTOR = 0.125 -- real units per scrollbar unit: a slot is 10
local SLOT_STEPS = PITCH / SCROLL_FACTOR
local BAR_GAP, BAR_SIZE = 0.06, 0.24
local BAR_H = 0.3 -- the room for the scrollbar under the slots
local SCROLLBAR_DEFAULTS = "scrollbaroptions[min=0;max=1000;smallstep=10;" ..
	"largestep=100;thumbsize=1;arrows=default]"

local function catalog_row(player, y, context)
	grug_skills.guard_detached()
	local rows = fill(player) or {}
	local layout = grug_inventory.LAYOUT
	local view_w = grug_inventory.VIEW_GEOMETRY.width
	local visible = grug_inventory.HOTBAR_SIZE
	local location = "detached:" .. core.formspec_escape(inv_name(player:get_player_name()))
	local slots_y = y + layout.label_h
	local fs = {
		grug_inventory.area_box(layout.box_x, y, layout.box_w,
			layout.slot_box_h + BAR_H, "Skills"),
		("style_type[label;font_size=*%.3f]label[%.3f,%.3f;%s]" ..
			"style_type[label;font_size=]"):format(0.75 * grug_core.ui.text_scale(player), layout.x + HINT_DX,
			y + layout.label_h / 2, core.formspec_escape(
				"Drag to hotbar; back to remove.")),
	}
	local max = math.max(0, #rows - visible) * SLOT_STEPS
	if max > 0 then
		local stored = context and context.grug_skills_scroll or 0
		local value = math.max(0, math.min(max, math.floor(stored)))
		-- The thumb shows the visible share (grug_inventory/ui.lua inventory_view).
		local thumb = math.max(1, math.floor(visible * (max + 1) / #rows + 0.5))
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;" ..
			"thumbsize=%d;arrows=hide]"):format(max, SLOT_STEPS, visible * SLOT_STEPS, thumb)
		fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.3f,%.3f;horizontal;%s;%d]"):format(layout.x,
			slots_y + 1 + BAR_GAP, view_w, BAR_SIZE, SCROLL_FIELD, value)
		fs[#fs + 1] = SCROLLBAR_DEFAULTS
	end
	fs[#fs + 1] = ("scroll_container[%.3f,%.3f;%.3f,1;%s;horizontal;%.3f]"):format(
		layout.x, slots_y, view_w, SCROLL_FIELD, SCROLL_FACTOR)
	fs[#fs + 1] = ("list[%s;catalog;0,0;%d,1;0]"):format(location, math.max(visible, #rows))
	fs[#fs + 1] = "scroll_container_end[]"
	return table.concat(fs)
end

-- Keeps the row's scroll value of every event in the sfinv context; a pure
-- scrollbar event ends here and is not re-sent (the chain of sfinv's hook).
local previous_handle_scroll = sfinv.handle_scroll
function sfinv.handle_scroll(player, context, fields)
	local pure = previous_handle_scroll(player, context, fields)
	local raw = fields[SCROLL_FIELD]
	local kind, value
	if type(raw) == "string" then
		kind, value = raw:match("^(%u+):(%-?%d+)$")
	end
	if kind == "CHG" or kind == "VAL" then
		context.grug_skills_scroll = math.max(0, tonumber(value))
		pure = pure or kind == "CHG"
	end
	return pure
end

grug_skills.catalog_row = catalog_row
grug_classes.skill_catalog_row = catalog_row

core.register_on_joinplayer(function(player) core.after(0, function(name)
	local current = core.get_player_by_name(name); if current then create(current) end
end, player:get_player_name()) end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name(); core.remove_detached_inventory(inv_name(name))
	detached[name], slots[name], known[name] = nil, nil, nil
end)
grug_classes.register_on_class_chosen(rebuild)
if grug_classes.register_on_talents_changed then
	grug_classes.register_on_talents_changed(function(player) rebuild(player, true) end)
end
grug_classes.register_on_race_chosen(rebuild)
grug_factions.register_on_faction_chosen(rebuild)
