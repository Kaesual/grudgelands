-- Disposable engine probe (Round 66 lane FX): the priest's symbols for
-- screenshots. Never shipped: tools/r66_fx/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r66_equip's probe.
--
-- A 21 x 21 platform 40 m over the spawn (sky behind, nothing in the way);
-- the player stands 8 m from the target, looking at it a little upwards so
-- Final Word's 7 m column fits. While a shot waits, its effect is played
-- again and again with the real catalogue (grug_core.particles.play), as
-- the casts play it, so the client always has one in flight:
--   <effect>_grass   by day on grass;
--   <effect>_snow    by day on snow (the added light on bright ground);
--   <effect>_night   at midnight on grass.
-- Smite every 0.3 s, Final Word every 0.4 s, Censure's warning, book and
-- impact as area.delayed plays them (0.75 s delay, 6 m fall) every 0.8 s.

local P = "[r66fx] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r66fx_settle") or "") or 2
local DISTANCE, HALF = 8, 10

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0, replay = 0}
local base, target

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r66fx_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function floor(node)
	for x = -HALF, HALF do
		for z = -HALF, HALF do
			core.set_node(vector.offset(base, x, 0, z), {name = node})
		end
	end
end

local function play(id, frame)
	grug_core.particles.play(id, frame)
end

local EFFECTS = {
	smite = {every = 0.3, run = function()
		play("smite_hit", {target = target})
	end},
	final_word = {every = 0.4, run = function()
		play("final_word", {target = target})
	end},
	censure = {every = 0.8, run = function()
		local frame = {target = target, reach = 3, time = 0.75, height = 6}
		play("censure_warning", frame)
		play("censure_fall", frame)
		core.after(0.75, play, "censure_impact", {target = target, reach = 3})
	end},
}

local SHOTS = {}
for _, scene in ipairs({{"grass", "default:dirt_with_grass", 0.5}, {"snow", "default:snowblock", 0.5},
		{"night", "default:dirt_with_grass", 0}}) do
	for _, effect in ipairs({"smite", "final_word", "censure"}) do
		SHOTS[#SHOTS + 1] = {name = effect .. "_" .. scene[1], effect = effect, node = scene[2],
			time = scene[3]}
	end
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	local player = core.get_player_by_name(NAME)
	if not player then return end
	local shot = state.phase == "shoot" and SHOTS[state.shot]
	if shot and state.ran then
		state.replay = state.replay + dtime
		local effect = EFFECTS[shot.effect]
		if state.replay >= effect.every then
			state.replay = 0
			effect.run()
		end
	end
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_priest = "Priest"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		base = vector.offset(vector.round(player:get_pos()), 0, 40, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(base, -HALF - 2, -2, -HALF - 2),
			vector.offset(base, HALF + 2, 12, HALF + 2), function(_, _, remaining)
				if remaining > 0 then return end
				floor("default:dirt_with_grass")
				target = vector.offset(base, 0, 0.5, 0)
				player:set_pos(vector.offset(base, 0, 0.5, -DISTANCE))
				player:set_look_horizontal(0) -- facing +z, the target
				player:set_look_vertical(-0.2)
				log(("READY base=%s target=%s"):format(core.pos_to_string(base),
					core.pos_to_string(target)))
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
			end)
	elseif state.phase == "shoot" then
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran, state.replay = true, 0
			floor(shot.node)
			core.set_timeofday(shot.time)
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
