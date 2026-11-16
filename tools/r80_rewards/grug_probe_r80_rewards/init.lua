-- Disposable engine probe (Round 80 lane REWARDS), after Round 79's
-- grug_probe_r79_page. Never shipped: tools/r80_rewards/capture.py stages it
-- through tools/luanti_headless.sh. It reads one JSON request from
-- <world>/r80rewards_in, does it inside the server and answers in
-- <world>/r80rewards_out. `show` draws an inventory page as sfinv builds it
-- (optionally with a stub reward list, to show the card's room) under its own
-- form name; `figures` stands frozen copies of the character's own look (the
-- real cloak source after a real select_cloak: texture and wings) in the air
-- in front of the camera.

local IN = core.get_worldpath() .. "/r80rewards_in"
local OUT = core.get_worldpath() .. "/r80rewards_out"
local FIGURE = "grug_probe_r80_rewards:figure"
local SKY = 160 -- the shots' height: open sky behind the figures

core.register_entity(FIGURE, {
	initial_properties = {physical = false, pointable = false, static_save = false,
		visual = "mesh", textures = {}},
})

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

local figures = {}
local function clear()
	for _, obj in ipairs(figures) do obj:remove() end
	figures = {}
end

-- A stub reward list for `show` (the fixture's stub catalogue, as a shot):
-- the real catalogue, then Cheer (the EMOTE lane's reward, not on this
-- branch: no icon here), then numbered extras up to `count`.
local function stub(count)
	local list = {}
	for _, entry in ipairs(grug_accounts.catalog()) do list[#list + 1] = entry end
	list[#list + 1] = {id = "emote:cheer", kind = "emote", name = "Cheer",
		hint = "Play it from the quickbar (E)."}
	local n = 1
	while #list < count do
		list[#list + 1] = {id = "cloak:extra" .. n, kind = "cloak", name = "Extra reward " .. n,
			hint = "Choose it on the Character page.", icon = list[1].icon}
		n = n + 1
	end
	while #list > count do list[#list] = nil end
	return list
end

local OPS = {}

function OPS.status(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	local account = grug_accounts.account_of(request.name)
	return {online = true, enabled = grug_accounts.enabled(),
		prepared = grug_core.world_preparation_status().ready,
		account_name = account and account.name,
		rewards = #grug_accounts.rewards_of(request.name),
		catalog = #grug_accounts.catalog(),
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
		submit(player, {class_priest = "Priest"})
		submit(player, {create_character = "Create"})
		return {created = false}
	end
	core.close_formspec(request.name, "")
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	core.set_timeofday(0.5)
	return {done = true}
end

function OPS.show(request)
	local player = core.get_player_by_name(request.name)
	local context = sfinv.get_or_create_context(player)
	if context.page ~= request.page then sfinv.set_page(player, request.page) end
	local real_catalog, real_rewards = grug_accounts.catalog, grug_accounts.rewards_of
	if request.stub then
		local list = stub(request.stub)
		grug_accounts.catalog = function() return list end
		grug_accounts.rewards_of = function() return list end
	end
	local ok, formspec = pcall(sfinv.get_formspec, player, context)
	grug_accounts.catalog, grug_accounts.rewards_of = real_catalog, real_rewards
	if not ok then error(formspec) end
	core.show_formspec(request.name, "r80rewards:shot", formspec)
	return {page = context.page, bytes = #formspec,
		picker = formspec:find("grug_cloak", 1, true) ~= nil}
end

function OPS.select_cloak(request)
	return {ok = grug_achievements.select_cloak(core.get_player_by_name(request.name), request.cloak)}
end

-- Frozen copies of the character's look in the air: request.figures is a
-- list of {x, yaw}; the camera (the player) stands `distance` behind them,
-- looking at them along +z. The look is the player's own object properties
-- (grug_visuals.apply wrote them: body, armour, cloak, wings) and its
-- current animation frame.
function OPS.figures(request)
	local player = core.get_player_by_name(request.name)
	core.close_formspec(request.name, "")
	if not request.keep then clear() end
	local props = player:get_properties()
	local range = player:get_animation()
	local base = vector.new(0, SKY, 0)
	for _, fig in ipairs(request.figures) do
		local obj = core.add_entity(base + vector.new(fig.x, 0, fig.z or 0), FIGURE)
		obj:set_properties({visual = props.visual, mesh = props.mesh, textures = props.textures,
			visual_size = props.visual_size, backface_culling = props.backface_culling,
			use_texture_alpha = props.use_texture_alpha})
		obj:set_yaw(fig.yaw)
		obj:set_animation({x = range.x, y = range.x}, 0, 0, false)
		figures[#figures + 1] = obj
	end
	local eye = props.eye_height or 1.47
	player:set_pos(base + vector.new(request.cam_x or 0, (request.cam_y or 1.0) - eye,
		-(request.distance or 3.6)))
	player:set_look_horizontal(0)
	player:set_look_vertical(request.pitch or 0.1)
	player:hud_set_flags({crosshair = false, wielditem = false, minimap = false,
		minimap_radar = false})
	return {figures = #figures, textures = #props.textures, wings = props.textures[7]}
end

function OPS.clear()
	clear()
	return {}
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
