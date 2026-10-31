-- Disposable engine probe (Round 68 lane SIGNS): the standing sign, the
-- waypost and the notice board with text, for screenshots. Never shipped:
-- tools/r68_signs/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) is tools/r68_text's probe.
--
-- The scene is built in the air 30 nodes above the arrival point (a stone
-- floor, noon). Nodes are set directly with their param2 (the placement
-- rules are the fixture's); one notice board goes through the real
-- on_place and logs whether it was placed. Texts are written through
-- grug_signs.write (a protected spot falls back to the meta and
-- grug_text.refresh, logged). Each shot moves the floating player to a
-- view; the probe logs the text entities it finds and the notice board's
-- texture string length.
--
-- r68signs_mode = compare (capture.sh MODE=compare): the notice board's two
-- half meshes against the one-piece model they were cut from (staged by
-- capture.sh as this probe's `grug_probe_r68_signs_whole.obj` on a node
-- drawn as the board's node drew it before), at each of the four turns,
-- front and angle, at one spot from one camera, no text, no clouds: the
-- shots C_halves_* and C_whole_* differ only in which meshes draw.

local P = "[r68signs] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r68signs_settle") or "") or 3
local MODE = core.settings:get("r68signs_mode") or ""
local WHOLE = "grug_probe_r68_signs:board_whole"

core.register_node(WHOLE, {
	description = "Notice board, one piece (probe)",
	drawtype = "mesh",
	mesh = "grug_probe_r68_signs_whole.obj",
	tiles = {"grug_signs_notice_board.png"},
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	groups = {not_in_creative_inventory = 1},
})

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local O

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r68signs_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function at(x, y, z) return vector.add(O, vector.new(x, y, z)) end
local function stone(x, y, z) core.set_node(at(x, y, z), {name = "default:stone"}) end

local STANDING, WAYPOST = "grug_signs:standing_sign", "grug_signs:waypost"
local BOARD, PART = "grug_signs:notice_board", "grug_signs:notice_board_part"

local function write(player, pos, text, also)
	grug_signs.write(pos, {quit = "true", text = text}, player, also)
	if core.get_meta(pos):get_string("text") ~= text then
		log("write refused at " .. core.pos_to_string(pos) .. " (protected): meta + refresh")
		core.get_meta(pos):set_string("text", text)
		grug_text.refresh(pos)
	end
end

local function put(player, x, y, z, name, param2, text)
	local pos = at(x, y, z)
	core.set_node(pos, {name = name, param2 = param2})
	if text then write(player, pos, text) end
	return pos
end

-- A board: the part at (x, y, z), the board to the reader's right.
local function board(player, x, y, z, param2, text)
	local look = core.facedir_to_dir(param2)
	local part = at(x, y, z)
	local main = vector.add(part, vector.new(look.z, 0, -look.x))
	core.set_node(part, {name = PART, param2 = param2})
	core.set_node(main, {name = BOARD, param2 = param2})
	write(player, main, text, part)
	return main
end

local SEVEN = "ASHFORD NOTICE BOARD\nMarket opens at sunrise\nFresh bread at the square\n" ..
	"Miners meet by the old well\nBring a lantern after dusk\nLeave parcels with the clerk\n" ..
	"All travellers are welcome"
local main_board

local function build(player)
	for x = -6, 42 do for z = -8, 8 do stone(x, -1, z) end end
	-- Front row, readers looking +z: a chest, planks and a wall sign for
	-- scale (the wood beside the signs' wood), the
	-- standing sign, a waypost turned so a face looks at the viewer (its
	-- arrow points +x), the notice board.
	for x = -1, 0 do for y = 0, 1 do stone(x, y, 1) end end
	core.set_node(at(-2, 0, 0), {name = "default:wood"})
	core.set_node(at(-3, 0, 0), {name = "default:chest", param2 = 0})
	core.get_meta(at(-3, 0, 0)):set_string(default.containers.LABEL_KEY, "Seeds and tools")
	default.containers.update_infotext(at(-3, 0, 0))
	put(player, -1, 1, 0, "default:sign_wall_wood", 4, "")
	core.registered_nodes["default:sign_wall_wood"].on_receive_fields(at(-1, 1, 0), "",
		{quit = "true", text = "Wall sign: same scale"}, player)
	if core.get_meta(at(-1, 1, 0)):get_string("text") == "" then
		core.get_meta(at(-1, 1, 0)):set_string("text", "Wall sign: same scale")
		grug_text.refresh(at(-1, 1, 0))
	end
	put(player, 2, 0, 0, STANDING, 0, "Welcome to\nAshford\nRest a while\nTravel safely")
	put(player, 4, 0, 0, WAYPOST, 60, "Eastmarch")
	main_board = board(player, 6, 0, 0, 0, SEVEN)
	-- Standing signs turned: 0, 15, 30, 45 and -30 degrees.
	for i, p2 in ipairs({0, 10, 20, 30, 220}) do
		put(player, 10 + 3 * i, 0, 0, STANDING, p2, ("Turned %d\nfour lines\nof fifteen\ncharacters"):
			format(math.floor(p2 * 1.5 + 0.5) % 360))
	end
	-- A stack of three wayposts pointing different ways.
	put(player, 32, 0, 0, WAYPOST, 0, "Ashford")
	put(player, 32, 1, 0, WAYPOST, 60, "Eastmarch")
	put(player, 32, 2, 0, WAYPOST, 150, "Old Mill")
	-- A board read looking +x (4dir 1) through the real on_place, else set.
	local item = ItemStack(BOARD)
	player:set_look_horizontal(math.rad(-90))
	player:set_look_vertical(0)
	local def = core.registered_nodes[BOARD]
	def.on_place(item, player, {type = "node", under = at(38, -1, 3), above = at(38, 0, 3)})
	local placed = core.get_node(at(38, 0, 2))
	log(("on_place read looking +x: part %s, board %s param2 %d"):format(core.get_node(at(38, 0, 3)).name,
		placed.name, placed.param2))
	if placed.name == BOARD then
		write(player, at(38, 0, 2), "Turned a quarter\nThe board stands on the reader's right",
			at(38, 0, 3))
	else
		board(player, 38, 0, 3, 1, "Turned a quarter\nThe board stands on the reader's right")
	end
end

local function count_entities()
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(at(18, 0, 0), 60)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "grug_text:text" then n = n + 1 end
	end
	return n
end

local function board_texture()
	for _, obj in ipairs(core.get_objects_inside_radius(main_board, 1.5)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "grug_text:text" and vector.equals(ent._grug_pos, main_board) then
			return obj:get_properties().textures[1]
		end
	end
	return ""
end

local function view(player, x, y, z, yaw, pitch)
	player:set_pos(at(x, y, z))
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(pitch))
end

-- Compare mode: one spot, the board's node at (0, 0, 0) turned by param2,
-- the part beside it (halves) or the one-piece node alone with air where
-- the part stood (whole, as the board's node drew it before).
local function compare_set(state, param2)
	for x = -1, 1 do for z = -1, 1 do
		local pos = at(x, 0, z)
		if core.get_node(pos).name ~= "air" then core.remove_node(pos) end
	end end
	local look = core.facedir_to_dir(param2)
	local part = vector.subtract(at(0, 0, 0), vector.new(look.z, 0, -look.x))
	if state == "halves" then
		core.set_node(part, {name = PART, param2 = param2})
		core.set_node(at(0, 0, 0), {name = BOARD, param2 = param2})
	else
		core.set_node(at(0, 0, 0), {name = WHOLE, param2 = param2})
	end
	log(("compare %s param2 %d: board %s, part side %s"):format(state, param2,
		core.get_node(at(0, 0, 0)).name, core.get_node(part).name))
	-- The board's middle, relative to O: half way to the part.
	return vector.multiply(vector.subtract(part, O), 0.5), look
end

-- A fixed sky for compare mode: plain, no clouds, sun, moon or stars, full
-- daylight (the zone moods would otherwise change it between shots).
local function still_sky(player)
	player:set_sky({type = "plain", base_color = "#8cbafa", clouds = false})
	player:set_clouds({density = 0})
	player:set_sun({visible = false, sunrise_visible = false})
	player:set_moon({visible = false})
	player:set_stars({visible = false})
	player:override_day_night_ratio(1)
end

-- The camera 4.5 nodes from the board's middle, along the reader's look
-- (front) or 40 degrees round to the reader's right (angle), looking 20
-- degrees up: the crosshair passes over the roof (no selection box drawn)
-- and the board sits in the lower half of the picture.
local function compare_view(player, middle, look, angle)
	local yaw = math.atan2(-look.x, look.z) + math.rad(angle)
	local dir = vector.new(-math.sin(yaw), 0, math.cos(yaw))
	local eye = vector.subtract(vector.add(middle, vector.new(0, 0.4, 0)), vector.multiply(dir, 4.5))
	view(player, eye.x, eye.y - 1.5, eye.z, math.deg(yaw), -20)
	still_sky(player)
end

local COMPARE = {}
for _, state in ipairs({"halves", "whole"}) do
	for param2 = 0, 3 do
		for _, angle in ipairs({0, 40}) do
			COMPARE[#COMPARE + 1] = {
				name = ("C_%s_r%d_%s"):format(state, param2, angle == 0 and "front" or "angle"),
				run = function(p)
					local middle, look = compare_set(state, param2)
					compare_view(p, middle, look, angle)
				end,
			}
		end
	end
end

-- The player's eyes are about 1.5 above its position.
local SHOTS = {
	{name = "S1_front_with_scale", run = function(p) view(p, 2.5, -0.6, -5, 0, 8) end},
	{name = "S2_back", run = function(p) view(p, 2.5, -0.6, 5, 180, 8) end},
	{name = "S3_notice_board_close", run = function(p) view(p, 6.5, -0.7, -2.4, 0, 6) end},
	{name = "S3b_notice_board_angle", run = function(p) view(p, 8.6, -0.7, -2.2, 40, 6) end},
	{name = "S4_standing_turned", run = function(p) view(p, 19, -0.6, -5.5, 0, 8) end},
	{name = "S5_standing_turned_side", run = function(p) view(p, 26, -0.6, -4, 40, 8) end},
	{name = "S6_waypost_stack_a", run = function(p) view(p, 29.5, 0.2, -2.5, -45, 12) end},
	{name = "S7_waypost_stack_b", run = function(p) view(p, 34.5, 0.2, 2.5, 135, 12) end},
	{name = "S8_waypost_stack_c", run = function(p) view(p, 32, 0.2, -3.5, 0, 12) end},
	{name = "S9_board_turned", run = function(p) view(p, 34.5, -0.6, 2.5, -90, 6) end},
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
		O = vector.round(vector.add(player:get_pos(), vector.new(0, 30, 0)))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:hud_set_flags({crosshair = false, wielditem = false})
		core.set_timeofday(0.5)
		if MODE == "compare" then
			for x = -12, 12 do for z = -12, 12 do stone(x, -1, z) end end
			still_sky(player)
			player:hud_set_flags({hotbar = false, healthbar = false, breathbar = false,
				minimap = false, minimap_radar = false, chat = false})
			SHOTS = COMPARE
		else
			build(player)
			log(("built at %s: %d text entities"):format(core.pos_to_string(O), count_entities()))
			log(("notice board texture string: %d bytes"):format(#board_texture()))
		end
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log(("entities at the end: %d"):format(count_entities()))
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			core.set_timeofday(0.5)
			shot.run(player)
			log("ran " .. shot.name .. ", text entities " .. count_entities())
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			if MODE == "compare" then still_sky(player) end
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
