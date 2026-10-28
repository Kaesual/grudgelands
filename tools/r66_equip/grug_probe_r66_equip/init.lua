-- Disposable engine probe (Round 66 lane EQUIP): the Character page for
-- screenshots. Never shipped: tools/r66_equip/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r62_bags' probe.
--
-- A new Mage with a Wand and a Spellbook equipped and a Staff in main[9].
-- Shots (the page shown as a form, as the inventory window draws it):
--   E0_feed_no_form   a feed line with no window open (where the feed sits);
--   E1_feed_page      the same feed line under the Character page (covered?);
--   E2_refusal_page   a real drag refusal (Staff onto Weapon, through the
--                     allow callbacks): the notice on the page;
--   E3_swap_page      the shift-click swap (the move onto the routing list):
--                     Staff equipped, Wand in its cell, the offhand blocked.
-- The feed line is fired again every half second while a shot waits, so it
-- is fresh (2.5 s) when the picture is taken.

local P = "[r66equip] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r66equip_settle") or "") or 2
local CHARACTER = "grug_inventory:character"

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r66equip_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- One move through every allow callback, as the engine asks them.
local function allow_move(player, info)
	local inv = player:get_inventory()
	for _, fn in ipairs(core.registered_allow_player_inventory_actions) do
		local r = fn(player, "move", inv, info)
		if r ~= nil then return r end
	end
	return nil
end

local FEED_TEXT = "Bronze Staff is two-handed: take Bronze Spellbook out first, " ..
	"or shift-click the Bronze Staff to swap both."
local feed_on = false

local function show_page(player)
	local context = sfinv.get_or_create_context(player)
	sfinv.set_page(player, CHARACTER)
	core.show_formspec(NAME, "r66equip:character", sfinv.get_formspec(player, context))
end

local function hands(player)
	local inv = player:get_inventory()
	return ("weapon=%s offhand=%s main9=%s"):format(inv:get_stack("grug_weapon", 1):to_string(),
		inv:get_stack("grug_offhand", 1):to_string(), inv:get_stack("main", 9):to_string())
end

local SHOTS = {
	{name = "E0_feed_no_form", run = function(player)
		core.close_formspec(NAME, "")
		feed_on = true
	end},
	{name = "E1_feed_page", run = function(player)
		feed_on = true
		show_page(player)
	end},
	{name = "E2_refusal_page", run = function(player)
		feed_on = false
		sfinv.set_page(player, CHARACTER)
		local r = allow_move(player, {from_list = "main", from_index = 9,
			to_list = "grug_weapon", to_index = 1, count = 1})
		log("drag refusal: allow=" .. tostring(r) .. " " .. hands(player))
		show_page(player)
	end},
	{name = "E3_swap_page", run = function(player)
		local r = allow_move(player, {from_list = "main", from_index = 9,
			to_list = grug_inventory.SHIFT_LIST, to_index = 1, count = 1})
		log("shift-click swap: allow=" .. tostring(r) .. " " .. hands(player))
		show_page(player)
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if feed_on then grug_core.feed(player, "notice", FEED_TEXT, "r66equip") end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_mage = "Mage"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		local inv = player:get_inventory()
		for _, item in ipairs({"grug_gear:wand_bronze", "grug_gear:spellbook_bronze",
				"grug_gear:staff_bronze"}) do
			if not core.registered_items[item] then log("MISSING " .. item) end
		end
		inv:set_stack("grug_weapon", 1, ItemStack("grug_gear:wand_bronze"))
		inv:set_stack("grug_offhand", 1, ItemStack("grug_gear:spellbook_bronze"))
		inv:set_stack("main", 9, ItemStack("grug_gear:staff_bronze"))
		grug_inventory.equipment_changed(player)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		log("READY " .. hands(player))
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
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
