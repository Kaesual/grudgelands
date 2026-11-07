-- Disposable engine probe (Round 70 lane DEATH): the durability hints for
-- screenshots. Never shipped: tools/r70_death/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver follows
-- tools/r65_hud's probe.
--
-- A level 20 Warrior with a sword and a chest piece. Shot 1: fresh gear, no
-- hint. Shot 2: the sword below 15 %, the low hint. Shot 3: a death (the real
-- path, through set_hp) takes 10 %: logged per slot; the chest piece is then
-- set to broken, both hints. Shot 4: the sword repaired by hand, the broken
-- hint alone. Shot 5: both repaired, none.

local P = "[r70death] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r70death_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r70death_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function set_wear(player, list, share)
	local inv = player:get_inventory()
	local stack = inv:get_stack(list, 1)
	stack:set_wear(math.floor((1 - share) * 65535 + 0.5))
	grug_repair.refresh_stack(stack, player)
	inv:set_stack(list, 1, stack)
	grug_inventory.equipment_changed(player, list)
end

local function report(player, label)
	local inv = player:get_inventory()
	for _, list in ipairs({"grug_weapon", "grug_chest"}) do
		local remaining, maximum = grug_repair.durability(inv:get_stack(list, 1))
		log(("run %s %s %s / %s"):format(label, list, tostring(remaining), tostring(maximum)))
	end
end

local SHOTS = {
	{name = "D1_fresh", run = function(player)
		grug_xp.set_xp(player, grug_xp.xp_for_level(20))
		local inv = player:get_inventory()
		local names = {}
		for name in pairs(core.registered_items) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			if core.get_item_group(name, "grug_equip_chest") > 0 and
					inv:get_stack("grug_chest", 1):is_empty() then
				inv:set_stack("grug_chest", 1, ItemStack(name))
			end
		end
		inv:set_stack("grug_weapon", 1, ItemStack(grug_gear.weapon_item("sword", 2)))
		grug_inventory.equipment_changed(player)
		report(player, "fresh")
	end},
	{name = "D2_low", run = function(player) set_wear(player, "grug_weapon", 0.14) end},
	{name = "D3_both", run = function(player)
		player:set_armor_groups({fleshy = 100})
		player:set_hp(0, {type = "fall"})
		report(player, "death")
		player:respawn()
		core.after(1, core.close_formspec, NAME, "__builtin:death")
		set_wear(player, "grug_chest", 0)
		player:set_armor_groups({immortal = 1})
	end},
	{name = "D4_broken", run = function(player) set_wear(player, "grug_weapon", 1) end},
	{name = "D5_none", run = function(player) set_wear(player, "grug_chest", 1) end},
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
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:set_pos(vector.offset(player:get_pos(), 0, 6, 0))
		player:set_look_vertical(-0.25)
		state.phase = "next"
		state.shot = 1
	elseif state.phase == "next" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		state.waited, state.logged, state.ran = 0, false, false
		state.phase = "shoot"
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not state.ran then
			state.ran = true
			local ok, err = pcall(shot.run, player)
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.phase = "next"
		end
	end
end)
