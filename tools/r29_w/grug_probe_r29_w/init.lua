-- Disposable engine probe (Round 29 Lane W). Never shipped:
-- tools/r29_w/probe.sh stages it through tools/luanti_headless.sh.
--
--   SOCKETS  the twelve `travel_waypoint` sockets and the six capitals'
--            `shipwright` sockets, read from the real registry;
--   WORLD    Dawnmere's and Highcourt's waystones emerged (a small box round
--            each): the node at the socket, the waystones counted in the box,
--            the pad's signature cross under it and a valid arrival beside
--            it (grug_home.safe_arrival); the Highcourt shipwright spot.
-- Then it shuts the server down.

local P = "[r29w_probe] "
local function log(msg) core.log("action", P .. msg) end
local ok = true
local function expect(cond, msg)
	log((cond and "ok   " or "FAIL ") .. msg)
	ok = ok and cond
end
local function fmt(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end

local stones, ships = {}, {}
local function sockets()
	for _, location in ipairs(grug_home.locations()) do
		for _, s in ipairs(grug_core.settlement_sockets_at(location.id)) do
			if s.id == "travel_waypoint" then stones[location.id] = s end
			if s.role == "shipwright" then ships[location.id] = s end
		end
		local s = stones[location.id]
		expect(s ~= nil and s.role == "waypoint", "SOCKET " .. location.id ..
			" travel_waypoint " .. (s and fmt(s.pos) or "missing"))
	end
	for _, capital in ipairs({"highcourt", "lethariel", "dur_brannoc", "gor_drazhak",
			"nhal_veyr", "kezamba"}) do
		local s = ships[capital]
		expect(s ~= nil, "SOCKET " .. capital .. " shipwright " ..
			(s and (s.id .. " " .. fmt(s.pos)) or "missing"))
	end
end

local function check_stone(id, done)
	local s = stones[id]
	local p = s.pos
	local minp, maxp = vector.offset(p, -24, -8, -24), vector.offset(p, 24, 8, 24)
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("WORLD %s emerged in %.1f s"):format(id, (core.get_us_time() - started) / 1e6))
		local node = core.get_node(p).name
		local found = core.find_nodes_in_area(minp, maxp, {"grug_mapgen:waystone"})
		expect(node == "grug_mapgen:waystone" and #found == 1,
			("WORLD %s node at socket %s = %s, waystones in box %d"):format(id, fmt(p), node, #found))
		local below = {}
		for _, d in ipairs({{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}}) do
			below[#below + 1] = core.get_node(vector.offset(p, d[1], -1, d[2])).name
		end
		local same = true
		for i = 2, #below do same = same and below[i] == below[1] end
		expect(same, ("WORLD %s pad cross under the stone: %s"):format(id, table.concat(below, " ")))
		local arrival = grug_home.safe_arrival(vector.offset(p, 1, -0.49, 0))
		expect(arrival ~= nil, ("WORLD %s arrival beside the stone %s"):format(id,
			arrival and ("(%.2f,%.2f,%.2f)"):format(arrival.x, arrival.y, arrival.z) or "blocked"))
		done()
	end)
end

local function check_ship(done)
	local s = ships.highcourt
	if not s then return done() end
	local p = s.pos
	core.emerge_area(vector.offset(p, -12, -4, -12), vector.offset(p, 12, 6, 12), function(_, _, remaining)
		if remaining > 0 then return end
		local feet, head = core.get_node(p).name, core.get_node(vector.offset(p, 0, 1, 0)).name
		local ground = core.get_node(vector.offset(p, 0, -1, 0)).name
		local def = core.registered_nodes[ground]
		expect(feet == "air" and head == "air" and def and def.walkable,
			("WORLD highcourt shipwright spot %s: feet %s, head %s, ground %s"):format(
				fmt(p), feet, head, ground))
		done()
	end)
end

local function finish()
	log(ok and "RESULT PASS" or "RESULT FAIL")
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local good, err = pcall(function()
			sockets()
			check_stone("dawnmere", function()
				check_stone("highcourt", function() check_ship(finish) end)
			end)
		end)
		if not good then
			log("RESULT FAIL " .. tostring(err))
			core.request_shutdown("probe failed", false, 0)
		end
	end)
end)
