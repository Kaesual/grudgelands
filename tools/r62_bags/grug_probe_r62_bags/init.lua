-- Disposable engine probe (Round 62 lane BAGS): the Inventory page with four
-- 20-slot bags, for screenshots. Never shipped: tools/r62_bags/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) follows
-- tools/r50_hotbar's probe.
--
-- A new Warrior with two Great Cloth Bags and two Leather Rucksacks equipped
-- (each content list sized from its bag, as the bags' join sizes it), main[9..]
-- and every bag filled with one kind of item per list so the lists' borders
-- show, the last bag two cells short. Shots: the Inventory page (the player's
-- own inventory formspec, shown as a form) at the top and scrolled to the end
-- (the scroll value the page echoes from its context, grug_inventory.keep_scroll).
-- The log names each list's size, the grid's rows and the scrollbar's maximum.

local P = "[r62bags] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r62bags_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r62bags_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local BAGS = {"grug_inventory:bag_great", "grug_inventory:bag_leather_rucksack",
	"grug_inventory:bag_great", "grug_inventory:bag_leather_rucksack"}
local FILL = {"default:cobble 99", "default:dirt 99", "default:sand 99", "default:wood 99"}

local function show(player, scroll)
	local context = sfinv.get_or_create_context(player)
	sfinv.set_page(player, "grug_inventory:inventory")
	context.grug_inv_scroll = {full = scroll}
	local formspec = sfinv.get_formspec(player, context)
	log(("scroll %d: scrollbar max %s"):format(scroll,
		formspec:match("scrollbaroptions%[min=0;max=(%d+);") or "none"))
	core.show_formspec(NAME, "r62bags:inventory", formspec)
end

local SHOTS = {
	{name = "B1_inventory_top", run = function(player) show(player, 0) end},
	-- Beyond the maximum on purpose: the view clamps it to the end.
	{name = "B2_inventory_end", run = function(player) show(player, 1000) end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		local inv = player:get_inventory()
		for index = 9, 32 do inv:set_stack("main", index, ItemStack("default:stick 50")) end
		local sizes, slots = {}, 0
		for i, bag in ipairs(BAGS) do
			local stack = ItemStack(bag)
			inv:set_stack(grug_inventory.bag_list(i), 1, stack)
			local list = grug_inventory.content_list(i)
			local size = grug_inventory.bag_slots_of(stack)
			inv:set_size(list, size)
			for index = 1, size - (i == #BAGS and 2 or 0) do
				inv:set_stack(list, index, ItemStack(FILL[i]))
			end
			sizes[#sizes + 1] = ("%s %s = %d"):format(list,
				stack:get_short_description(), inv:get_size(list))
			slots = slots + inv:get_size(list)
		end
		local cells = inv:get_size("main") - 8 + slots
		log(("bags: %s; %d bag slots, %d grid cells, %d rows (%d visible)"):format(
			table.concat(sizes, ", "), slots, cells, math.ceil(cells / 8),
			grug_inventory.VIEW_ROWS.full))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			shot.run(player)
			log("ran " .. shot.name)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
