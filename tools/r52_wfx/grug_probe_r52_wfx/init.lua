-- Disposable engine probe (Round 52 lane WFX): does the item definition's
-- `wield_overlay` animation apply to an overlay NAME the stack meta
-- overrides (round52-class-plan.md C7)? Never shipped:
-- tools/r52_wfx/capture.sh stages it through tools/luanti_headless.sh with a
-- throwaway test strip (make_strip.py) and connects one real client. The
-- driver (character creation, SHOT / ack handshake) is the Round 48 HUD
-- probe's, as in tools/r52_graph.
--
-- Charge's definition gets an animated overlay here (8 frames, 0.5 s each)
-- under the shipped transparent name; the Warrior holds an iron sword and
-- Charge, whose stack meta names the test strip. Shots: first person twice
-- (one coloured block at the tip, changing over time, if the animation
-- applies; eight squashed stripes if not), the empty weapon slot (the skin
-- pass's transparent override over the bare hand), third person from the
-- front (the holder shows the sword alone).
local P = "[r52wfx] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r52wfx_settle") or "") or 3
local STRIP = "grug_probe_r52_wfx_strip.png"
local SWORD = "grug_gear:sword_iron"
local SKILL = "grug_abilities:charge"
local function log(msg) core.log("action", P .. msg) end

core.override_item(SKILL, {wield_overlay = {name = grug_abilities.NO_OVERLAY,
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 4.0}}})

local function receive(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function equip(player, item)
	local inv = player:get_inventory()
	inv:set_stack(grug_inventory.hand_list(player, "weapon"), 1, ItemStack(item or ""))
	grug_inventory.equipment_changed(player, grug_inventory.hand_list(player, "weapon"))
end

-- Charge on hotbar slot 1 (the wielded one), its meta naming `overlay`.
local function hold_skill(player, overlay)
	local inv = player:get_inventory()
	local at
	for i, stack in ipairs(inv:get_list("main")) do
		if stack:get_name() == SKILL then at = i break end
	end
	if not at then
		log("CHECK no Charge stack in main")
		return
	end
	local first, skill = inv:get_stack("main", 1), inv:get_stack("main", at)
	if overlay then skill:get_meta():set_string("wield_overlay", overlay) end
	inv:set_stack("main", at, first)
	inv:set_stack("main", 1, skill)
end

local function report(player, label)
	local stack = player:get_inventory():get_stack("main", 1)
	local meta = stack:get_meta()
	log(("CHECK %s: item=%s wield_image=%s wield_overlay=%s token=%s"):format(label,
		stack:get_name(), meta:get_string("wield_image"), meta:get_string("wield_overlay"),
		meta:get_string("grug_skin")))
end

local SHOTS = {
	{name = "A1_first_person_strip", act = function(player)
		equip(player, SWORD)
		hold_skill(player, STRIP)
		report(player, "A1")
	end},
	{name = "A2_first_person_strip_later", act = function(player) report(player, "A2") end},
	{name = "B_empty_slot", act = function(player)
		equip(player, nil)
		report(player, "B")
	end},
	{name = "C_third_person", act = function(player)
		equip(player, SWORD)
		hold_skill(player, STRIP)
		player:set_camera({mode = "third_front"})
		report(player, "C")
	end},
}

local state = {phase = "wait", clock = 0}

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r52wfx_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

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
			receive(player, "", {faction_accord = "Accord"})
			receive(player, "", {race_human = "Human"})
			receive(player, "", {class_warrior = "Warrior"})
			receive(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_look_vertical(-0.35)
		core.set_timeofday(0.5)
		local def = core.registered_items[SKILL]
		local overlay = def and def.wield_overlay
		log(("CHECK definition overlay: name=%s animation=%s"):format(
			type(overlay) == "table" and tostring(overlay.name) or tostring(overlay),
			type(overlay) == "table" and core.write_json(overlay.animation or {}) or "-"))
		local info = core.get_player_information(NAME) or {}
		log(("CHECK client protocol %s, version %s"):format(tostring(info.protocol_version),
			tostring(info.version_string)))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then shot.act(player) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log(("SHOT %s"):format(shot.name))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
