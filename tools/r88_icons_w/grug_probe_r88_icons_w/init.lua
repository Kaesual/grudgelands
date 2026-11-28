-- Disposable engine probe (Round 88 lane ICONS-W): every potion, elixir and
-- draught with its own bottle, for screenshots. Never shipped:
-- tools/r88_icons_w/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r62_bags's probe.
--
-- A new Warrior with one Great Cloth Bag; one family per row, tiers left to
-- right: the hotbar holds Healing I-VI and the merchant's Weak Healing
-- Potion, the main grid Mana, then Vigor, then Focus (each row ends with the
-- single-tier draughts), the bag Precision and Stoneskin. Shots: the
-- Inventory page (the player's own inventory formspec, shown as a form) and
-- the plain view with the HUD hotbar. The log names every item and its image.

local P = "[r88iconsw] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r88iconsw_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r88iconsw_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local A = "grug_alchemy:"
local function tiers(stem)
	local out = {}
	for tier = 1, 6 do out[tier] = A .. stem .. tier end
	return out
end
local function row(list, ...)
	for _, item in ipairs({...}) do list[#list + 1] = item end
	return list
end
-- {list name, first index, items}
local LAYOUT = {
	{"main", 1, row(tiers("potion_healing_t"), "grug_traders:potion_healing_weak")},
	{"main", 9, row(tiers("potion_mana_t"), A .. "potion_antivenom", A .. "potion_swiftness")},
	{"main", 17, row(tiers("elixir_vigor_t"), A .. "potion_cave", A .. "elixir_deepwater")},
	{"main", 25, tiers("elixir_focus_t")},
	{"bag", 1, tiers("elixir_precision_t")},
	{"bag", 9, tiers("elixir_stoneskin_t")},
}

local function show(player)
	sfinv.set_page(player, "grug_inventory:inventory")
	local context = sfinv.get_or_create_context(player)
	core.show_formspec(NAME, "r88iconsw:inventory", sfinv.get_formspec(player, context))
end

local SHOTS = {
	{name = "W1_inventory_all_bottles", run = show},
	{name = "W2_hotbar_healing", run = function() core.close_formspec(NAME, "r88iconsw:inventory") end},
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
		for index = 1, inv:get_size("main") do inv:set_stack("main", index, ItemStack("")) end
		local bag = ItemStack("grug_inventory:bag_great")
		inv:set_stack(grug_inventory.bag_list(1), 1, bag)
		local bag_list = grug_inventory.content_list(1)
		inv:set_size(bag_list, grug_inventory.bag_slots_of(bag))
		local placed = 0
		for _, entry in ipairs(LAYOUT) do
			local list = entry[1] == "bag" and bag_list or entry[1]
			for offset, item in ipairs(entry[3]) do
				local def = core.registered_items[item]
				local stack = ItemStack(item .. " 5")
				inv:set_stack(list, entry[2] + offset - 1, stack)
				placed = placed + 1
				log(("items %s[%d] %s = %s"):format(list, entry[2] + offset - 1, item,
					def and def.inventory_image or "UNREGISTERED"))
			end
		end
		log(("items placed %d, main %d, %s %d"):format(placed, inv:get_size("main"),
			bag_list, inv:get_size(bag_list)))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_look_horizontal(0)
		player:set_look_vertical(-0.3)
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
