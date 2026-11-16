-- Disposable engine probe (Round 80 lane FIXES). Never shipped:
-- tools/r80_fixes/water_drop.py stages it through tools/luanti_headless.sh.
-- It reads one JSON request from <world>/r80water_in and answers in
-- <world>/r80water_out (the pattern of tools/r79_page's probe).
--
-- The fall is the CLIENT's physics (clientenvironment.cpp, the liquid block
-- of step); the server only sees the position and speed the client reports
-- (TOSERVER_PLAYERPOS), sampled here on every server step. The game's
-- liquid setting reaches the client in the movement packet at join; the
-- per-run physics override `liquid_fluidity_smooth` MULTIPLIES it
-- (clientenvironment.cpp:153-154), so one client measures several values.
-- The probe writes that one field directly: it is a test mod, outside the
-- single-writer rule of grug_core/movement.lua, and the partial override
-- leaves every other field alone.

local IN = core.get_worldpath() .. "/r80water_in"
local OUT = core.get_worldpath() .. "/r80water_out"

local FLOOR_Y, SURFACE_Y = 120, 160          -- 40 nodes of water
local MAX_DROP = 60                           -- the highest platform above the surface
local TOP_Y = SURFACE_Y + MAX_DROP + 4        -- the air column of the tank
local HALF = 3                                -- 7 x 7 glass box, 5 x 5 water
local SETTLE, SAMPLE = 3.0, 5.0               -- seconds on the platform, then falling

local tank = {state = "none"}
local run = nil

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

local OPS = {}

function OPS.status(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	return {online = true, prepared = grug_core.world_preparation_status().ready}
end

-- Finishes character creation (as tools/r79_page's probe), then leaves the
-- physics to the game.
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
	return {done = true, pos = player:get_pos()}
end

local function write_tank(cx, cz)
	local minp = {x = cx - HALF, y = FLOOR_Y, z = cz - HALF}
	local maxp = {x = cx + HALF, y = TOP_Y, z = cz + HALF}
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()
	local glass = core.get_content_id("default:glass")
	local water = core.get_content_id("default:water_source")
	local air = core.get_content_id("air")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local wall = x == minp.x or x == maxp.x or z == minp.z or z == maxp.z
				local id = air
				if y == FLOOR_Y or (wall and y <= SURFACE_Y + 1) then
					id = glass
				elseif y <= SURFACE_Y then
					id = water
				end
				data[area:index(x, y, z)] = id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

-- Builds the tank above the player's x/z once its blocks exist.
function OPS.tank(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	if tank.state == "none" then
		local pos = vector.round(player:get_pos())
		tank.state, tank.x, tank.z = "emerging", pos.x, pos.z
		core.emerge_area({x = pos.x - HALF, y = FLOOR_Y, z = pos.z - HALF},
			{x = pos.x + HALF, y = TOP_Y, z = pos.z + HALF},
			function(_, _, remaining)
				if remaining == 0 then
					write_tank(tank.x, tank.z)
					tank.state = "ready"
				end
			end)
	end
	return {state = tank.state, x = tank.x, z = tank.z}
end

local function platform(y, node)
	for dx = -1, 1 do
		for dz = -1, 1 do
			core.set_node({x = tank.x + dx, y = y, z = tank.z + dz}, {name = node})
		end
	end
end

-- One drop from `height` nodes above the surface (30 when not given, at most
-- MAX_DROP): the override, the platform, the teleport; the step below
-- releases the player after SETTLE seconds and samples for SAMPLE seconds.
function OPS.drop(request)
	local player = core.get_player_by_name(request.name)
	if not player or tank.state ~= "ready" then return {error = "not ready"} end
	local height = math.min(MAX_DROP, math.floor(tonumber(request.height) or 30))
	player:set_physics_override({liquid_fluidity_smooth = request.factor})
	player:set_hp(player:get_properties().hp_max)
	player:set_breath(player:get_properties().breath_max or 10)
	platform(SURFACE_Y + height, "default:glass")
	player:set_pos({x = tank.x, y = SURFACE_Y + height + 0.5, z = tank.z})
	run = {name = request.name, factor = request.factor, height = height, t = 0,
		released = false, samples = {}, done = false}
	return {started = true}
end

function OPS.result()
	if not run then return {none = true} end
	if not run.done then return {done = false, t = run.t} end
	return {done = true, factor = run.factor, surface = SURFACE_Y + 0.5,
		start = SURFACE_Y + run.height + 0.5, samples = run.samples}
end

function OPS.shutdown()
	core.after(0.5, core.request_shutdown)
	return {}
end

local clock, last_id = 0, nil
core.register_globalstep(function(dtime)
	if run and not run.done then
		run.t = run.t + dtime
		local player = core.get_player_by_name(run.name)
		if not player then
			run.done = true
		elseif not run.released then
			if run.t >= SETTLE then
				run.released, run.t = true, 0
				platform(SURFACE_Y + run.height, "air")
			end
		else
			local pos, vel = player:get_pos(), player:get_velocity()
			run.samples[#run.samples + 1] = {t = run.t, y = pos.y, vy = vel.y}
			if run.t >= SAMPLE then run.done = true end
		end
	end
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
