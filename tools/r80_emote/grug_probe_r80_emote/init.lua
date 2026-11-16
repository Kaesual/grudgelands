-- Disposable engine probe (Round 80 lane EMOTE). Never shipped:
-- tools/r80_emote/capture.py stages it through tools/luanti_headless.sh. It
-- reads one JSON request from <world>/r80emote_in, does it inside the server
-- and answers in <world>/r80emote_out (tools/r79_page's method). The
-- character owns Apprentice Riding and the Boat (owned_tier_ids wrapped).

local IN = core.get_worldpath() .. "/r80emote_in"
local OUT = core.get_worldpath() .. "/r80emote_out"

function grug_mounts.owned_tier_ids() return {1, 5} end

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

local OPS = {}

function OPS.status(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	local emotes = {}
	for index, entry in ipairs(grug_quickbar.emotes(player)) do emotes[index] = entry.id end
	return {online = true, enabled = grug_accounts.enabled(),
		prepared = grug_core.world_preparation_status().ready,
		cheer = grug_accounts.has_reward(request.name, "emote:cheer"),
		emotes = table.concat(emotes, ","),
		riding = grug_mounts.active[request.name] ~= nil,
		animation = player_api.get_animation(player).animation,
		pose = grug_visuals.current_pose(player)}
end

-- Finishes character creation; done once the character has arrived.
function OPS.ready(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	if not grug_core.world_preparation_status().ready then return {prepared = false} end
	if player:get_meta():get_string("grug_classes:arriving") ~= "" then return {arriving = true} end
	if not grug_classes.get_class(player) then
		submit(player, {faction_accord = "Accord"})
		submit(player, {race_human = "Human"})
		submit(player, {class_warrior = "Warrior"})
		submit(player, {create_character = "Create"})
		return {created = false}
	end
	core.close_formspec(request.name, "")
	core.set_timeofday(0.5)
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	return {done = true}
end

function OPS.quickbar(request)
	local player = core.get_player_by_name(request.name)
	player:set_camera({mode = "first"})
	return {shown = grug_quickbar.open(player)}
end

function OPS.close(request)
	core.close_formspec(request.name, grug_quickbar.FORMNAME)
	core.close_formspec(request.name, "r80emote:shot")
	return {}
end

function OPS.mount(request)
	local ok, why = grug_mounts.mount(core.get_player_by_name(request.name), 1)
	return {ok = ok, why = why}
end

function OPS.dismount(request)
	return {ok = grug_mounts.dismount(core.get_player_by_name(request.name), "manual", false)}
end

-- The emote, the way a quickbar click plays it, seen in the third-person
-- front camera.
function OPS.emote(request)
	local player = core.get_player_by_name(request.name)
	core.close_formspec(request.name, grug_quickbar.FORMNAME)
	player:set_camera({mode = "third_front"})
	local ok, why = grug_visuals.play_emote(player, request.emote)
	return {ok = ok, why = why}
end

function OPS.camera(request)
	core.get_player_by_name(request.name):set_camera({mode = request.mode})
	return {}
end

-- The Account page as sfinv builds it, under its own form name.
function OPS.account(request)
	local player = core.get_player_by_name(request.name)
	player:set_camera({mode = "first"})
	local context = sfinv.get_or_create_context(player)
	if context.page ~= grug_accounts.PAGE then sfinv.set_page(player, grug_accounts.PAGE) end
	core.show_formspec(request.name, "r80emote:shot", sfinv.get_formspec(player, context))
	return {page = context.page}
end

function OPS.shutdown()
	core.after(0.5, core.request_shutdown)
	return {}
end

local clock, last_id = 0, nil
core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < 0.1 then return end
	clock = 0
	local file = io.open(IN, "r")
	if not file then return end
	local text = file:read("*a")
	file:close()
	local request = core.parse_json(text, nil, true)
	if type(request) ~= "table" or request.id == last_id then return end
	last_id = request.id
	local ok, result = pcall(OPS[request.op], request)
	if not ok then result = {error = tostring(result)} end
	core.safe_file_write(OUT, core.write_json({id = request.id, result = result}))
end)
