-- Disposable engine probe (Round 78 lane EMOTE): the quickbar's emote buttons
-- and third-person frames of the emotes, for screenshots. Never shipped:
-- tools/r78_emote/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r67_social's probe.
--
-- One real player (an Accord Human Warrior) at its start town, frozen, at
-- noon. The quickbar lists Apprentice Riding and the Boat (owned_tier_ids
-- wrapped). Shots: the window on foot, the window riding (Dance greyed),
-- then in the third-person front camera the seated Wave, the standing Wave
-- and two moments of the Dance. An emote starts when its SHOT is logged
-- (`go`), so the screenshot about 1-1.5 s later lands inside it; a shot's
-- own `settle` shortens the wait for a later moment of an emote its `run`
-- started.

local P = "[r78emote] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r78emote_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r78emote_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

function grug_mounts.owned_tier_ids() return {1, 5} end

local function emote(player, which)
	-- Again here: a dismount's own camera release (grug_mounts, 1 s) ends after it.
	player:set_camera({mode = "third_front"})
	local ok, why = grug_visuals.play_emote(player, which)
	log(("emote %s: %s %s, animation %s"):format(which, tostring(ok), tostring(why),
		player_api.get_animation(player).animation))
end

local function front(player)
	core.close_formspec(NAME, grug_quickbar.FORMNAME)
	player:set_camera({mode = "third_front"})
end

local SHOTS = {
	{name = "Q1_quickbar_foot", run = function(player) grug_quickbar.open(player) end},
	{name = "Q2_quickbar_riding", run = function(player)
		core.close_formspec(NAME, grug_quickbar.FORMNAME)
		log("mount: " .. tostring(grug_mounts.mount(player, 1)))
		grug_quickbar.open(player)
	end},
	{name = "E1_wave_seated", run = front, go = function(player) emote(player, "wave") end},
	{name = "E2_wave", run = function(player)
		log("dismount: " .. tostring(grug_mounts.dismount(player, "manual", false)))
		front(player)
	end, go = function(player) emote(player, "wave") end},
	{name = "E3_dance", run = front, go = function(player) emote(player, "dance") end},
	{name = "E4_dance_later", settle = 0.5, run = function(player) emote(player, "dance") end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.25 then return end
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
		core.set_timeofday(0.5)
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
		if not state.logged and state.waited >= (shot.settle or SETTLE) then
			state.logged = true
			if shot.go then shot.go(player) end
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
