-- Disposable engine probe (Round 86 lane ROADS): road cut walls as the
-- engine generates them. For each spot of the setting `r86roads_spots`
-- ("name:cx,cz,wx,wz;..." the road's centre point and the wall's column, from
-- tools/r86_roads/census.lua's sections) it emerges the ground round it,
-- logs the ground across the section and announces two views for
-- tools/r86_roads/capture.sh: standing on the road looking up at the cut,
-- and from across the road, above it, at the whole cut. Never shipped. The
-- driver follows tools/r85_build's probe.

local P = "[r86roads] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r86roads_settle") or "") or 5
local REACH = 56

local function log(msg) core.log("action", P .. msg) end

local spots = {}
for name, cx, cz, wx, wz in (core.settings:get("r86roads_spots") or ""):gmatch(
		"([%w_]+):(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)") do
	spots[#spots + 1] = {name = name, cx = tonumber(cx), cz = tonumber(cz), wx = tonumber(wx),
		wz = tonumber(wz)}
end

local state = {phase = "wait", clock = 0, spot = 1}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r86roads_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- the highest walkable node's top at a column (generated ground)
local function ground(x, z, s)
	for y = s.hi, s.lo, -1 do
		local def = core.registered_nodes[core.get_node(vector.new(x, y, z)).name]
		if def and def.walkable then return y + 1 end
	end
	return 0
end

local function view(player, from, to)
	player:set_pos(from)
	local eye = vector.offset(from, 0, 1.5, 0)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

-- the two views of a spot (after its ground is known)
local function shots_of(s)
	local nx, nz = s.wx - s.cx, s.wz - s.cz
	local len = math.sqrt(nx * nx + nz * nz)
	nx, nz = nx / len, nz / len
	local road = ground(s.cx, s.cz, s)
	local top = ground(s.wx, s.wz, s)
	-- the ground across the section, every 2 nodes from the centre outwards
	local row = {}
	for d = 0, 40, 2 do
		row[#row + 1] = tostring(ground(math.floor(s.cx + d * nx + 0.5), math.floor(s.cz + d * nz + 0.5), s))
	end
	log(("%s road %d wall top %d section %s"):format(s.name, road, top, table.concat(row, " ")))
	local mid = vector.new(s.cx + nx * 18, road + (top - road) * 0.5, s.cz + nz * 18)
	return {
		{name = s.name .. "_on_road", from = vector.new(s.cx - nx * 2, road, s.cz - nz * 2),
			to = mid},
		{name = s.name .. "_across", from = vector.new(s.cx - nx * 30, road + 14, s.cz - nz * 30),
			to = vector.new(s.cx + nx * 14, road + (top - road) * 0.4, s.cz + nz * 14)},
	}
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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		state.phase = "next"
	elseif state.phase == "next" then
		local s = spots[state.spot]
		if not s then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		state.phase = "emerging"
		player:set_pos(vector.new(s.cx, 200, s.cz))
		local t0 = core.get_us_time()
		-- the planned ground's range round the spot (no emerge above or below)
		local q = grug_mapgen.wp40.planner_source
		local lo, hi = math.huge, -math.huge
		for dz = -REACH, REACH, 8 do
			for dx = -REACH, REACH, 8 do
				local y = select(6, q.column_values_at(s.cx + dx, s.cz + dz))
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
		end
		s.lo, s.hi = lo - 8, hi + 8
		core.emerge_area(vector.new(s.cx - REACH, s.lo, s.cz - REACH),
			vector.new(s.cx + REACH, s.hi, s.cz + REACH), function(_, _, remaining)
				if remaining ~= 0 then return end
				log(("%s emerged in %.1f s"):format(s.name, (core.get_us_time() - t0) / 1e6))
				state.shots = shots_of(s)
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				state.phase = "shoot"
			end)
	elseif state.phase == "shoot" then
		local shot = state.shots[state.shot]
		if not shot then
			state.spot = state.spot + 1
			state.phase = "next"
			return
		end
		if not state.ran then
			state.ran = true
			local ok, err = pcall(view, player, shot.from, shot.to)
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
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
