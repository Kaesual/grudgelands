-- Disposable engine probe (Round 26 Lane I): stages a HUD for the status-icon
-- screenshot. Never shipped: tools/r26_status_icons/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client.
--
-- For the joining client it completes character creation through the real
-- receive-fields chain (Accord, Human, Warrior) once world preparation is
-- ready, waits for the class (applied at the arrival teleport), then starts
-- statuses through the real game paths where one exists:
--   food        grug_food.eat with a real Bread stack (item image icon)
--   shield      grug_core.add_absorb with a Turn Aside dodge modifier
--               (shield + talent_turn_aside from the combat.lua source)
--   untouchable grug_classes.start_talent_window
--   slowed      grug_core.set_move_modifier "mob_web" (movement source)
--   rooted      grug_core.set_root (movement source)
--   combat      grug_core.mark_in_combat, renewed every second
-- and through grug_core.set_status for the rest: an elixir (Focus variant),
-- poison and a PvP tag (no WP41 mechanics exist yet; neutral gold frame).
-- The party is a STAGED view (grug_parties.view replaced for this client
-- only): one member per class, so the class icons can be seen.
-- It logs "[status_icons_probe] READY" and shuts the server down
-- SHUTDOWN_AFTER seconds later.

local P = "[status_icons_probe] "
local NAME = "grugcap"
local SHUTDOWN_AFTER = 45
local LONG = 600

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0, ready_at = nil}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local real_view = grug_parties.view
function grug_parties.view(player)
	if player:get_player_name() ~= NAME then return real_view(player) end
	local own_max = player:get_properties().hp_max or 100
	return {id = "probe", leader = NAME, faction = "accord", members = {
		{name = NAME, online = true, level = 12, hp = player:get_hp(),
			hp_max = own_max, class = grug_classes.get_class(player)},
		{name = "Brannoc", online = true, level = 12, hp = 140, hp_max = 180,
			class = "mage"},
		{name = "Ilsa", online = true, level = 11, hp = 175, hp_max = 190,
			class = "priest"},
		{name = "Tamsin", online = true, level = 12, hp = 90, hp_max = 210,
			class = "scout"},
		{name = "Oswin", online = false, level = 10},
	}}
end

-- A passive critter held 5 m ahead on the look ray, so the target frame
-- (top centre) is on screen too.
local function hold_target()
	local obj = state.target
	if not obj or not obj:get_pos() then
		obj = core.add_entity(state.target_pos, "grug_mobs:wild_turkey")
		state.target = obj
	end
	if obj then
		obj:set_pos(state.target_pos)
		obj:set_velocity({x = 0, y = 0, z = 0})
	end
end

local function stage(player)
	player:hud_set_flags({chat = false})
	local yaw = math.rad(200)
	local pos = player:get_pos()
	state.target_pos = {x = pos.x - math.sin(yaw) * 5, y = pos.y + 0.05,
		z = pos.z + math.cos(yaw) * 5}
	player:set_look_horizontal(yaw)
	player:set_look_vertical(math.atan(1.25 / 5))
	hold_target()
	local stack = ItemStack("grug_cooking:bread 3")
	grug_food.eat(stack, player, 1, "dish", "hearty")
	log("food status " .. tostring(grug_core.get_status(player, "food") ~= nil))
	grug_core.set_status(player, "elixir", {label = "Elixir of Focus III",
		duration = 900, variant = "focus"})
	grug_core.add_absorb(player, "power_word_shield", 60, LONG, player, {},
		{dodge_percent = 10})
	grug_classes.start_talent_window(player, "untouchable", LONG)
	grug_core.set_move_modifier(player, "mob_web", {speed = -0.4}, LONG)
	grug_core.set_root(player, LONG)
	grug_core.set_status(player, "poisoned", {label = "Poisoned", duration = 42})
	grug_core.set_status(player, "pvp_tagged", {label = "PvP", duration = 60})
	grug_core.mark_in_combat(player)
	local ids = {}
	for _, entry in ipairs(grug_core.status_display(player)) do
		ids[#ids + 1] = entry.id .. "=" .. entry.caption .. "{" .. entry.texture .. "}"
	end
	log("row " .. table.concat(ids, " "))
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if not grug_factions.get_faction(player) then
			submit(player, {choose_accord = "Accord"})
		elseif not grug_classes.get_race(player) then
			submit(player, {choose_human = "Human"})
		elseif not grug_classes.get_class(player) then
			submit(player, {choose_warrior = "Warrior"})
		end
		if grug_classes.get_class(player) then
			state.phase = "settle"
			state.settle = 0
			log("character complete at " .. core.pos_to_string(
				vector.round(player:get_pos())))
		end
	elseif state.phase == "settle" then
		state.settle = state.settle + 1
		if state.settle >= 6 then
			core.close_formspec(NAME, "")
			stage(player)
			state.phase = "ready"
			state.ready_at = core.get_us_time()
			log("READY")
		end
	elseif state.phase == "ready" then
		grug_core.mark_in_combat(player)
		hold_target()
		if core.get_us_time() - state.ready_at > SHUTDOWN_AFTER * 1e6 then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
		end
	end
end)
