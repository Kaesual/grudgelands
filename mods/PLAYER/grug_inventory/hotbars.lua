-- Two hotbar layouts, A and B (Round 50 rulings 1-3, D1-D3; spec
-- docs/design/inventory_equipment.md "Hotbar layouts"). The engine's hotbar
-- always shows main[1..8] (no API points it at another list), so a switch
-- exchanges main[1..8] with the eight stacks of the hidden player list
-- grug_inventory.HOTBAR_STORE in one step, and player meta names the layout
-- now on main[1..8] (both in storage.lua, the data model). The hidden list
--  * is created empty at join and never shrunk: an existing character keeps
--    its hotbar as A, B starts empty (ruling 1); the engine saves it with
--    `main` and the meta;
--  * never takes an item automatically (it is not in the give order) and is
--    never sorted; consumers count and take from it last (consume_lists);
--  * refuses every inventory action, so a modified client cannot address
--    the undrawn list. init.lua loads this file before every other of this
--    mod's: the engine stops at the first allow callback that answers, and
--    equipment.lua and bags.lua answer for their own slots.
-- A switch first runs the register_on_hotbar_switch callbacks (grug_abilities
-- cancels a pending cast, eating, the bow's draw and held input there, so a
-- fresh press is needed), then swaps and re-sends the inventory page. One
-- switch per HOTBAR_SWITCH_US: an anti-spam limit, not a cooldown.
--
-- The switch buttons are ui.lua's hotbar_switch element; every form that
-- draws them passes its fields to hotbar_switch_fields and re-shows itself
-- when it answers true. The inventory pages do that here, through sfinv's
-- event hook.

grug_inventory.HOTBAR_SWITCH_US = 250000

local last_switch = {} -- player name -> core.get_us_time() of the last switch
local switch_callbacks = {}

-- fn(player, layout) runs right before a switch to `layout` exchanges the
-- rows: cancels and flags, nothing that may refuse.
function grug_inventory.register_on_hotbar_switch(fn)
	switch_callbacks[#switch_callbacks + 1] = fn
end

-- Makes `layout` ("A" or "B") the visible hotbar. Returns true when it
-- switched; false for the layout already shown or within the anti-spam limit.
function grug_inventory.switch_hotbar(player, layout)
	if layout ~= "A" and layout ~= "B" or
			grug_inventory.active_hotbar(player) == layout then
		return false
	end
	local name = player:get_player_name()
	local now = core.get_us_time()
	if last_switch[name] and now - last_switch[name] < grug_inventory.HOTBAR_SWITCH_US then
		return false
	end
	last_switch[name] = now
	for _, fn in ipairs(switch_callbacks) do fn(player, layout) end
	-- Both rows read first, both written back-to-back: nothing in between
	-- can see or change half a swap.
	local inv = player:get_inventory()
	local store, size = grug_inventory.HOTBAR_STORE, grug_inventory.HOTBAR_SIZE
	if inv:get_size(store) < size then inv:set_size(store, size) end
	local main, hidden = inv:get_list("main"), inv:get_list(store)
	for index = 1, size do
		main[index], hidden[index] = hidden[index], main[index]
	end
	inv:set_list("main", main)
	inv:set_list(store, hidden)
	player:get_meta():set_string(grug_inventory.HOTBAR_LAYOUT_KEY, layout)
	-- The inventory page marks the shown layout: the cached page follows
	-- (and an open one is re-shown, the switch made on it included).
	if sfinv.enabled then sfinv.set_player_inventory_formspec(player) end
	return true
end

-- A form's event: switches when one of the buttons was pressed. True when
-- it switched (the caller re-shows its form); false for anything else.
function grug_inventory.hotbar_switch_fields(player, fields)
	for layout, field in pairs(grug_inventory.HOTBAR_FIELDS) do
		if fields[field] then return grug_inventory.switch_hotbar(player, layout) end
	end
	return false
end

core.register_allow_player_inventory_action(function(_, action, _, info)
	local store = grug_inventory.HOTBAR_STORE
	if action == "move" then
		if info.from_list == store or info.to_list == store then return 0 end
	elseif info.listname == store then
		return 0
	end
end)

core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	if inv:get_size(grug_inventory.HOTBAR_STORE) < grug_inventory.HOTBAR_SIZE then
		inv:set_size(grug_inventory.HOTBAR_STORE, grug_inventory.HOTBAR_SIZE)
	end
end)

core.register_on_leaveplayer(function(player)
	last_switch[player:get_player_name()] = nil
end)

-- The inventory pages: after ui.lua's scroll hook (installed at its load),
-- so the event's scroll value is kept before the switch re-sends the page;
-- the page itself never sees the button.
core.register_on_mods_loaded(function()
	local previous = sfinv.handle_scroll
	function sfinv.handle_scroll(player, context, fields)
		if previous(player, context, fields) then return true end
		return grug_inventory.hotbar_switch_fields(player, fields)
	end
end)
