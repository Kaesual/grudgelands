-- Disposable engine probe (Round 68 lane TEXT): written wall signs and
-- labelled chests for screenshots. Never shipped: tools/r68_text/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) follows
-- tools/r67_social's probe.
--
-- The scene is built in the air 30 nodes above the arrival point (stone
-- backing, noon). Signs are written through the node's own form handler
-- (the override grug_text installs; a protected spot falls back to the
-- meta and grug_text.refresh, logged), chest labels through the container
-- API's update_infotext like a label save. Each shot moves the floating
-- player to a view; the probe logs the text entities it finds.

local P = "[r68text] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r68text_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}
local O

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r68text_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function at(x, y, z) return vector.add(O, vector.new(x, y, z)) end
local function stone(x, y, z) core.set_node(at(x, y, z), {name = "default:stone"}) end

local function sign(player, x, y, z, name, param2, text)
	local pos = at(x, y, z)
	core.set_node(pos, {name = name, param2 = param2})
	core.registered_nodes[name].on_receive_fields(pos, "", {quit = "true", text = text}, player)
	if core.get_meta(pos):get_string("text") ~= text then
		log("write refused at " .. core.pos_to_string(pos) .. " (protected): meta + refresh")
		core.get_meta(pos):set_string("text", text)
		grug_text.refresh(pos)
	end
end

local function chest(x, y, z, name, param2, label)
	local pos = at(x, y, z)
	core.set_node(pos, {name = name, param2 = param2})
	core.get_meta(pos):set_string(default.containers.LABEL_KEY, default.containers.clean_label(label))
	default.containers.update_infotext(pos)
end

local WOOD, IRON = "default:sign_wall_wood", "grug_materials:iron_sign_wall"
local LONG = "Pneumonoultramicroscopicsilicovolcanoconiosis"
local CUT = "The old mill road runs north past the inn; travellers keep to the lit " ..
	"path after dark and ask for the key at the smithy."

local function build(player)
	-- Front wall (z = 3) with four signs facing the viewer at z < 3.
	for x = -5, 5 do for y = -1, 3 do stone(x, y, 3) end end
	sign(player, -3, 1, 2, WOOD, 4, "Welcome to Hearthpine Mill & Inn")
	sign(player, -1, 1, 2, IRON, 4, "Iron gate shuts at dusk")
	sign(player, 1, 1, 2, WOOD, 4, LONG)
	sign(player, 3, 1, 2, WOOD, 4, CUT)
	sign(player, -1, 2, 2, WOOD, 4, "Ünïcode: Größe ŽЖΩ ☃")
	-- A pillar at (20, 1, 0) with a sign on each side.
	for y = 0, 2 do stone(20, y, 0) end
	sign(player, 21, 1, 0, WOOD, 3, "East side")
	sign(player, 19, 1, 0, IRON, 2, "West side")
	sign(player, 20, 1, 1, WOOD, 5, "North side")
	sign(player, 20, 1, -1, IRON, 4, "South side")
	-- A floor (y = -1) at x 40..44 with floor signs, a ceiling (y = 3) with two.
	for x = 39, 45 do for z = -2, 2 do stone(x, -1, z); stone(x, 3, z) end end
	sign(player, 41, 0, 0, WOOD, 1, "On the floor: wood")
	sign(player, 43, 0, 0, IRON, 1, "On the floor: iron")
	sign(player, 41, 2, 0, WOOD, 0, "Ceiling wood")
	sign(player, 43, 2, 0, IRON, 0, "Ceiling iron")
	-- Chests at x 60..70 facing the viewer at z < 0 (facedir 0), three tiers,
	-- normal and locked; a floor below them.
	for x = 58, 72 do for z = -4, 1 do stone(x, -1, z) end end
	local labels = {"Iron ore and coal from the deep mine", "Seeds", "Bread, cheese & ale",
		"Gems", "Tools for the smithy and forge", "Abyssal crystals"}
	local i = 0
	for tier = 1, 3 do
		for _, base in ipairs({"default:chest", "default:chest_locked"}) do
			i = i + 1
			chest(56 + 2 * i, 0, 0, default.containers.tier_name(base, tier), 0, labels[i])
		end
	end
	-- Two chests and a sign facing +z (facedir 2, wallmounted 5), seen from the north.
	for x = 79, 85 do for z = -1, 3 do stone(x, -1, z) end end
	for x = 79, 85 do stone(x, 0, -1); stone(x, 1, -1) end
	chest(81, 0, 0, "default:chest", 2, "Facing north")
	chest(83, 0, 0, "default:chest_locked_abyssal", 2, "Locked and facing north")
	sign(player, 82, 1, 0, WOOD, 5, "North face")
end

local function count_entities()
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(at(40, 0, 0), 80)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "grug_text:text" then n = n + 1 end
	end
	return n
end

local function view(player, x, y, z, yaw, pitch)
	player:set_pos(at(x, y, z))
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(pitch))
end

local function open_chests(open)
	local i = 0
	for tier = 1, 3 do
		for _, base in ipairs({"default:chest", "default:chest_locked"}) do
			i = i + 1
			local name = default.containers.tier_name(base, tier)
			core.swap_node(at(56 + 2 * i, 0, 0), {name = open and name .. "_open" or name, param2 = 0})
		end
	end
end

-- The player's eyes are about 1.5 above its position.
local SHOTS = {
	{name = "T1_wall_signs", run = function(p) view(p, 0, -0.3, -2.2, 0, 0) end},
	{name = "T2_sides_east_south", run = function(p) view(p, 23, -0.4, -3, 45, 5) end},
	{name = "T3_sides_west_north", run = function(p) view(p, 17, -0.4, 3, 225, 5) end},
	{name = "T4_floor_signs", run = function(p) view(p, 42, 0.8, -2.2, 0, 55) end},
	{name = "T5_ceiling_signs", run = function(p) view(p, 42, -1.2, -1.6, 0, -50) end},
	{name = "T6_chests_closed", run = function(p) open_chests(false); view(p, 65, -0.6, -3.6, 0, 18) end},
	{name = "T7_chests_open", run = function(p) open_chests(true); view(p, 65, -0.6, -3.6, 0, 18) end},
	{name = "T8_chests_close_up", run = function(p) view(p, 59, -0.9, -1.8, 0, 12) end},
	{name = "T9_facing_north", run = function(p) view(p, 82, -0.6, 3.2, 180, 15) end},
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
		build(player)
		log(("built at %s: %d text entities"):format(core.pos_to_string(O), count_entities()))
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
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
