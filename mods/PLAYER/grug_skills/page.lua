-- The skill catalog (Round 44, spec ui-crafting-rework-plan.md ruling 8 and
-- §3.4): one row under the talent tree of the Talents & Skills page, which
-- grug_classes/talents_ui.lua draws; this file installs the row as
-- grug_classes.skill_catalog_row. Each unlocked ability has its own slot of
-- a per-player detached list that is an infinite source and an infinite
-- destination: a drag onto a free hotbar slot copies the skill there
-- (bound_items.lua decides where a skill may land and keeps it to one copy),
-- and a drag of the carried copy back onto its own icon removes that copy
-- (the engine undoes the swap such a drop asks for and keeps the catalog's
-- stack). A talent that unlocks an ability puts it on a free hotbar slot,
-- else it waits here. Mounts and boats are not listed (they move to the
-- quickbar).
local detached = {}
local slots = {} -- player name -> ability id per catalog slot
local known = {} -- player name -> set of ability ids at the last rebuild

local function inv_name(name) return "grug_skills_" .. name end

local function entries(player)
	local result = {}
	for index, id in ipairs(grug_abilities.unlocked_ids(player)) do
		assert(index <= grug_inventory.HOTBAR_SIZE,
			"Skills ability row exceeds the decided class-kit limit")
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

-- After an entitlement change. With announce == true (a talent change) each
-- talent ability unlocked since the last rebuild goes onto a free hotbar
-- slot, or waits in the catalog when the hotbar is full; the feed says which.
local UNLOCK_LINES = {
	placed = " unlocked: it is on your hotbar.",
	full = " unlocked. Your hotbar is full: drag it from Talents & Skills.",
	carried = " unlocked. You already carry it.",
	locked = " unlocked. Drag it from Talents & Skills onto your hotbar.",
}
local function rebuild(player, announce)
	local name = player:get_player_name()
	local rows = fill(player)
	if not rows then return end
	local before, now = known[name] or {}, {}
	for _, id in ipairs(rows) do
		now[id] = true
		local def = grug_abilities.registered[id]
		if announce == true and def and def.talent_gated and not before[id] then
			local slot, why = grug_abilities.grant_to_hotbar(player, id)
			grug_core.feed(player, "notice", def.name ..
				(UNLOCK_LINES[slot and "placed" or why] or UNLOCK_LINES.locked))
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

-- The row: a hint, then the catalog on the hotbar's columns in a "Skills"
-- box like the Hotbar box (grug_inventory.LAYOUT). `y` is the hint's top, in
-- the page's real coordinates; the row is 1.9 high.
local function catalog_row(player, y)
	grug_skills.guard_detached()
	fill(player)
	local layout = grug_inventory.LAYOUT
	local location = "detached:" .. core.formspec_escape(inv_name(player:get_player_name()))
	local box_y = y + 0.4
	return ("label[%.3f,%.2f;%s]"):format(layout.x, y + 0.15, core.formspec_escape(
			"Drag skills onto the hotbar. Drag one back here to remove it.")) ..
		grug_inventory.area_box(layout.box_x, box_y, layout.box_w,
			layout.slot_box_h, "Skills") ..
		("list[%s;catalog;%.3f,%.3f;8,1;0]"):format(location, layout.x,
			box_y + layout.label_h)
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
