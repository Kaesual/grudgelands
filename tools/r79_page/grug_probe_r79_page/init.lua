-- Disposable engine probe (Round 79 lane PAGE). Never shipped:
-- tools/r79_page/capture.py stages it through tools/luanti_headless.sh. It
-- reads one JSON request from <world>/r79page_in, does it inside the server
-- and answers in <world>/r79page_out, as tools/r691_bridge's probe does. A
-- request may hold a link code (the page's field); nothing here logs a
-- request. `show` draws an inventory page as sfinv builds it and shows it
-- under its own form name, so the screenshot holds exactly that build.

local IN = core.get_worldpath() .. "/r79page_in"
local OUT = core.get_worldpath() .. "/r79page_out"
local PAGE = grug_accounts.PAGE

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

local OPS = {}

function OPS.status(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	local account = grug_accounts.account_of(request.name)
	return {online = true, enabled = grug_accounts.enabled(),
		prepared = grug_core.world_preparation_status().ready,
		state = grug_accounts.link_state(player).state,
		account_name = account and account.name,
		cloak = grug_accounts.has_reward(request.name, "cloak:supporter"),
		selected = grug_achievements.selected_cloak(player)}
end

-- Every tab a creative administrator sees, so the bar is at its fullest.
function OPS.privs(request)
	local privs = core.get_player_privs(request.name)
	privs.creative, privs.mail_admin = true, true
	core.set_player_privs(request.name, privs)
	return {}
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
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	return {done = true}
end

function OPS.show(request)
	local player = core.get_player_by_name(request.name)
	local context = sfinv.get_or_create_context(player)
	if context.page ~= request.page then sfinv.set_page(player, request.page) end
	local formspec = sfinv.get_formspec(player, context)
	core.show_formspec(request.name, "r79page:shot", formspec)
	return {page = context.page, bytes = #formspec,
		picker = formspec:find("grug_cloak", 1, true) ~= nil,
		account_tab = formspec:find(";Account]", 1, true) ~= nil}
end

-- The Account page's buttons, through the page's own handler.
function OPS.click(request)
	local player = core.get_player_by_name(request.name)
	local context = sfinv.get_or_create_context(player)
	if context.page ~= PAGE then sfinv.set_page(player, PAGE) end
	sfinv.pages[PAGE]:on_player_receive_fields(player, context, request.fields)
	return {state = grug_accounts.link_state(player).state}
end

function OPS.select_cloak(request)
	return {ok = grug_achievements.select_cloak(core.get_player_by_name(request.name), request.cloak)}
end

function OPS.shutdown()
	core.after(0.5, core.request_shutdown)
	return {}
end

local clock, last_id = 0, nil
core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < 0.2 then return end
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
