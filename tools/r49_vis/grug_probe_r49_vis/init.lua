-- Disposable engine probe (Round 49 lane VIS): the item in the third-person
-- hand (a dirt block, a pickaxe) and the half-buried onion in the world, for
-- screenshots. Never shipped: tools/r49_vis/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) is the Round 48 HUD probe's.
--
-- After the character is made (Accord, Human, Warrior, at its start town)
-- the probe freezes it, places a Wild Onion, a field Wild Onion stage 4 and
-- stage 3 two nodes ahead, then per shot sets the wielded item and the
-- camera mode (`set_camera`, clients >= 5.12), waits SETTLE seconds (past
-- the one-second wield poll) and logs "SHOT <name>" with the hand entity's
-- size.
local P = "[r49vis] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r49vis_settle") or "") or 4
local function log(msg) core.log("action", P .. msg) end

local DOWN = 0.62 -- radians: the onions two nodes ahead, from eye height
local SHOTS = {
	{name = "A_third_front_dirt", item = "default:dirt", mode = "third_front"},
	{name = "B_third_front_pick", item = "default:pick_steel", mode = "third_front"},
	{name = "C_third_back_dirt", item = "default:dirt", mode = "third"},
	{name = "D_third_back_pick", item = "default:pick_steel", mode = "third"},
	{name = "E_first_dirt", item = "default:dirt", mode = "first"},
	{name = "F_onions", item = "", mode = "first", pitch = DOWN},
}

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r49vis_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- Two nodes ahead (+z, the look direction set below): wild, field 4, field 3
-- on their own ground, with clear air above and between.
local function stage_onions(base)
	for dx = -2, 2 do
		for dz = 1, 3 do
			for dy = 0, 3 do
				core.set_node({x = base.x + dx, y = base.y + dy, z = base.z + dz}, {name = "air"})
			end
			core.set_node({x = base.x + dx, y = base.y - 1, z = base.z + dz},
				{name = "default:dirt_with_grass"})
		end
	end
	local z = base.z + 2
	core.set_node({x = base.x - 1, y = base.y - 1, z = z}, {name = "default:dirt_with_grass"})
	core.set_node({x = base.x, y = base.y - 1, z = z}, {name = "grug_farming:soil_wet"})
	core.set_node({x = base.x + 1, y = base.y - 1, z = z}, {name = "grug_farming:soil_wet"})
	core.set_node({x = base.x - 1, y = base.y, z = z}, {name = "grug_mapgen:wild_onion_source"})
	core.set_node({x = base.x, y = base.y, z = z}, {name = "grug_farming:wild_onion_4"})
	core.set_node({x = base.x + 1, y = base.y, z = z}, {name = "grug_farming:wild_onion_3"})
	log("onions at " .. core.pos_to_string({x = base.x, y = base.y, z = z}) ..
		": wild, field 4, field 3 (left to right as seen)")
end

local function hand_size(player)
	for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), 3)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "grug_visuals:wield" then
			local props = obj:get_properties()
			return ("%s size %.4f"):format(props.wield_item ~= "" and props.wield_item or
				tostring(props.textures[1]), props.visual_size.x)
		end
	end
	return "no hand entity"
end

local function show(player, shot)
	player:set_wielded_item(ItemStack(shot.item))
	player:set_camera({mode = shot.mode})
	player:set_look_horizontal(0)
	player:set_look_vertical(shot.pitch or 0)
	core.set_timeofday(0.5)
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
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local base = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(base))
		stage_onions(base)
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			player:set_camera({mode = "any"})
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log(("SHOT %s"):format(shot.name))
			log(("CHECK %s: %s"):format(shot.name, hand_size(player)))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
