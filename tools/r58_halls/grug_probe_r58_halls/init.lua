-- Disposable engine probe (Round 58 lane HALLS): the Miner's Guild houses in
-- the engine, for screenshots and a check. Never shipped:
-- tools/r58_halls/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, camera, SHOT /
-- ack handshake) is lane FT's probe's (tools/r51_ft), from lanes LK and TC.
--
-- Per capital: the hall's sockets from the registry (the leader at the back,
-- the porter in the forecourt), an emerged box round them (a region, never
-- the world), then
--   check  the nodes the house writes: the frieze's six tier stones in a row
--          behind the leader and the plaque over the door, read in the world;
--   shots  outside (in front of the forecourt, looking at the door) and
--          inside (just inside the door, looking at the leader's desk).

local P = "[r58halls] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r58halls_settle") or "") or 6
local TIME_OF_DAY = 0.45
local ONLY = {}
for label in (core.settings:get("r58halls_only") or ""):gmatch("[^,%s]+") do ONLY[label] = true end

local function log(msg) core.log("action", P .. msg) end

local CAPITALS = {
	{key = "dur_brannoc", plaque = "grug_materials:gold_block"},
	{key = "gor_drazhak", plaque = "grug_materials:copper_block"},
	{key = "lethariel", plaque = "grug_materials:gold_block"},
}
local TIERS = {"default:stone", "grug_materials:t2_stone", "grug_materials:t3_stone",
	"grug_materials:t4_stone", "grug_materials:t5_stone", "grug_materials:t6_stone"}

local halls, SHOTS = {}, {}

local function socket_pos(key, id)
	for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do
		if socket.id == id then return socket.pos, socket end
	end
end

local function find_halls()
	for _, cap in ipairs(CAPITALS) do
		if next(ONLY) == nil or ONLY[cap.key] then
			local leader = socket_pos(cap.key, "miners_guild_leader")
			local porter = socket_pos(cap.key, "miners_guild_porter")
			local exchange = socket_pos(cap.key, "miners_guild_exchange")
			if leader and porter and exchange then
				halls[#halls + 1] = {cap = cap, leader = leader, porter = porter,
					exchange = exchange}
				log("hall " .. cap.key .. ": leader " .. core.pos_to_string(leader) ..
					", porter " .. core.pos_to_string(porter) .. ", exchange " ..
					core.pos_to_string(exchange))
			else
				log("hall " .. cap.key .. " missing: no hall sockets")
			end
		end
	end
end

local function yaw_to(from, to)
	return math.deg(math.atan2(-(to.x - from.x), to.z - from.z))
end

local function survey(hall)
	local key = hall.cap.key
	-- the hall's axis, from the street side to the back wall
	local d = vector.subtract(hall.leader, hall.porter)
	local ax = math.abs(d.x) > math.abs(d.z) and (d.x > 0 and 1 or -1) or 0
	local az = ax == 0 and (d.z > 0 and 1 or -1) or 0
	-- the frieze: one node behind the leader, y + 1 (the layer above the feet)
	local back = {x = hall.leader.x + ax * 2, y = hall.leader.y + 1, z = hall.leader.z + az * 2}
	local found = {}
	for offset = -4, 4 do
		local p = {x = back.x + az * offset, y = back.y, z = back.z + ax * offset}
		local name = core.get_node(p).name
		for tier, stone in ipairs(TIERS) do
			if name == stone then found[tier] = true end
		end
	end
	local tiers = 0
	for tier = 1, #TIERS do if found[tier] then tiers = tiers + 1 end end
	-- the plaque: over the door, three nodes up, one node towards the hall
	-- from the porter's row and up to three nodes sideways
	local plaque = 0
	local minp = vector.subtract(hall.porter, {x = 4, y = 0, z = 4})
	local maxp = vector.add(hall.porter, {x = 4, y = 5, z = 4})
	plaque = #core.find_nodes_in_area(minp, maxp, {hall.cap.plaque})
	log(("CHECK %s: frieze %d of 6 tier stones behind the leader, plaque %d (%s)")
		:format(key, tiers, plaque, (tiers == 6 and plaque == 1) and "ok" or "MISSING"))
	-- outside: 12 back along the axis from the porter, 5 up, looking at the door
	local out = {x = hall.porter.x - ax * 12 + az * 3, y = hall.porter.y + 5,
		z = hall.porter.z - az * 12 + ax * 3}
	SHOTS[#SHOTS + 1] = {name = key .. "_outside", pos = out,
		yaw = yaw_to(out, hall.porter), pitch = 14, first = true}
	-- inside: three in from the porter (the first row past the door), at
	-- eye height, looking at the leader
	local inside = {x = hall.porter.x + ax * 3, y = hall.porter.y + 1.9,
		z = hall.porter.z + az * 3}
	SHOTS[#SHOTS + 1] = {name = key .. "_inside", pos = inside,
		yaw = yaw_to(inside, hall.leader), pitch = 8}
end

---------------------------------------------------------------------------
-- The driver (lane FT's, from lanes LK and TC)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r58halls_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function hide_hud(player)
	player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
		wielditem = false, breathbar = false, minimap = false, minimap_radar = false,
		basic_debug = false, chat = false})
	for id in pairs(player:hud_get_all() or {}) do
		player:hud_remove(id)
	end
	player:set_clouds({density = 0})
	player:set_properties({is_visible = false, show_on_minimap = false,
		visual_size = {x = 0, y = 0, z = 0}})
end

local function hold(player, shot)
	player:set_pos({x = shot.pos.x, y = shot.pos.y - 1.625, z = shot.pos.z})
	player:set_look_horizontal(math.rad(shot.yaw))
	player:set_look_vertical(math.rad(shot.pitch))
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
		log("character complete at " .. core.pos_to_string(vector.round(player:get_pos())))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		find_halls()
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for _, hall in ipairs(halls) do
			local c = hall.leader
			state.pending = state.pending + 1
			local t0 = core.get_us_time()
			core.emerge_area({x = c.x - 32, y = c.y - 12, z = c.z - 32},
				{x = c.x + 32, y = c.y + 30, z = c.z + 32}, function(_, _, remaining)
					if remaining == 0 then
						state.pending = state.pending - 1
						log(("emerged %s (%.1f s after its request)"):format(hall.cap.key,
							(core.get_us_time() - t0) / 1e6))
						survey(hall)
					end
				end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		hide_hud(player)
		state.phase = "shoot"
		state.shot = 1
		state.waited = 0
		state.logged = false
		log("READY " .. #SHOTS .. " shots")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		core.set_timeofday(TIME_OF_DAY)
		hold(player, shot)
		hide_hud(player)
		state.waited = state.waited + step
		local wait = shot.first and SETTLE * 2 or SETTLE
		if not state.logged and state.waited >= wait then
			state.logged = true
			log("SHOT " .. shot.name .. " at " .. core.pos_to_string(vector.round(shot.pos)))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited = 0
			state.logged = false
		end
	end
end)
