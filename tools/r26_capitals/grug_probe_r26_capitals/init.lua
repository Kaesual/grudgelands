-- Round 26 Lane W engine probe (disposable, never shipped): two planned
-- capitals in a real world (run with tools/r26_capitals/engine.sh):
--   1. the world's layout file holds the capital layouts; they parse with the
--      shipped planner;
--   2. per capital, after emerging the ground round a few wall points, two
--      towers and the north gate: masonry stands on the wall line up to the
--      planned walk, a tower rises to its crown with the walk passing through,
--      the gate passage is open and its tower columns stand;
--   3. the protected city: "town" (grug_zones.hard_protection_kind_at) halfway
--      between the core and the wall and 15 nodes beyond the wall, nothing 45
--      beyond it;
--   4. claims (Round 25 ruling 27, grug_housing): the capital's hard footprint
--      lies within the claim margin (16) of a point 30 beyond the wall and not
--      of one 75 beyond it; a stone (its axis-aligned 101 x 101 square
--      widened by the margin) 30 beyond the wall is refused as "town", one
--      whose widened square just clears the band's edge (~21 beyond the wall;
--      along a diagonal ray the square's corner reaches back furthest) not as
--      "town" (it may still be refused for other reasons, e.g. the capital
--      zone, ruling 22).
-- Ends the server itself; "RESULT PASS" is the verdict line.
local PREFIX = "[r26_capitals_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end
local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r26 capitals probe done", false, 0)
end

local floor, sqrt, max = math.floor, math.sqrt, math.max
local planner = dofile(core.get_modpath("grug_mapgen") .. "/wp40/capital_planner.lua")
local CAPITALS = {
	{id = "anchor_007", key = "dur_brannoc", player = "r26wdwarf", faction = "accord"},
	{id = "anchor_010", key = "nhal_veyr", player = "r26wundead", faction = "throng"},
}
local FACTIONS = {}
for _, c in ipairs(CAPITALS) do FACTIONS[c.player] = c.faction end
local previous_faction = grug_core.get_player_faction
grug_core.get_player_faction = function(name)
	return FACTIONS[name] or previous_faction(name)
end

local function solid(pos)
	local node = core.get_node(pos)
	return node.name ~= "air" and node.name ~= "ignore" and
		not node.name:find("water", 1, true), node.name
end
local function round(v) return floor(v + 0.5) end
-- the writer's walk top of a wall point (walk in half nodes)
local function walk_top(walk2)
	local h = floor(walk2 + 0.5) / 2
	return floor(h)
end

local function zone_check(name, pos)
	local world = {}
	for key, fn in pairs(grug_housing.placement_world) do world[key] = fn end
	world.cube_clear = function() return true end
	return grug_housing.model.validate(name, grug_core.get_player_faction(name), pos, world)
end

local jobs = {}
local function run_jobs(i)
	local job = jobs[i]
	if not job then return finish() end
	local started = core.get_us_time()
	core.emerge_area(job.minp, job.maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED %s %s in %.1f s"):format(job.label, core.pos_to_string(job.minp),
			(core.get_us_time() - started) / 1e6))
		job.run()
		run_jobs(i + 1)
	end)
end
local function area(x, z, y0, y1)
	return {x = x - 8, y = y0, z = z - 8}, {x = x + 8, y = y1, z = z + 8}
end

local function plan_capital(c, L)
	local AX, AZ = L.anchor.x, L.anchor.z
	local dims = planner.EDGE[L.kind]
	local W = L.wall
	local n = #W.pts
	log(("%s: kind %s, %d wall points, %d towers, %d plots"):format(c.key, L.kind, n,
		#W.turrets, #L.plots))
	check(#W.turrets > 0 and #L.plots > 30, c.key .. ": layout has towers and plots")
	-- wall points: dry, no gate gap within 10, spread round the loop
	local function usable(i)
		for d = -10, 10 do
			local k = (i - 1 + d) % n + 1
			if W.gap[k] or W.wet[k] or W.lake[k] then return false end
		end
		for _, t in ipairs(W.turrets) do
			local d = math.abs(t - i)
			if math.min(d, n - d) < 6 then return false end
		end
		return true
	end
	local picks = {}
	for _, f in ipairs({0.12, 0.45, 0.78}) do
		for d = 0, n do
			local i = (floor(f * n) + d) % n + 1
			if usable(i) then picks[#picks + 1] = i break end
		end
	end
	for _, i in ipairs(picks) do
		local p = W.pts[i]
		local x, z = AX + round(p[1]), AZ + round(p[2])
		local top = walk_top(W.walk[i])
		local minp, maxp = area(x, z, top - 40, top + 12)
		jobs[#jobs + 1] = {label = c.key .. " wall " .. i, minp = minp, maxp = maxp, run = function()
			local count = 0
			for y = top - 3, top do if solid({x = x, y = y, z = z}) then count = count + 1 end end
			local _, name = solid({x = x, y = top, z = z})
			log(("%s wall point %d at %d,%d walk top %d: %d of 4 solid (top %s)"):format(
				c.key, i, x, z, top, count, name))
			check(count >= 3, c.key .. " wall masonry at point " .. i)
		end}
	end
	-- two dry towers
	local towers = 0
	for _, ti in ipairs(W.turrets) do
		if towers < 2 and not W.wet[ti] then
			towers = towers + 1
			local p = W.pts[ti]
			local x, z = AX + round(p[1]), AZ + round(p[2])
			local top = walk_top(W.walk[ti])
			local minp, maxp = area(x, z, top - 40, top + 12)
			jobs[#jobs + 1] = {label = c.key .. " tower " .. ti, minp = minp, maxp = maxp, run = function()
				-- the tower's rim (TURRET - 1 out, off the wall line) rises to
				-- the crown; the centre carries the walk with air above
				local p2 = W.pts[ti % n + 1]
				local tx, tz = p2[1] - p[1], p2[2] - p[2]
				local l = sqrt(tx * tx + tz * tz)
				local nx, nz = -tz / l, tx / l
				local rx = x + round(nx * (dims.turret - 1))
				local rz = z + round(nz * (dims.turret - 1))
				local rim = 0
				for y = top + 1, top + 4 do if solid({x = rx, y = y, z = rz}) then rim = rim + 1 end end
				local walk_ok = solid({x = x, y = top, z = z})
				log(("%s tower %d at %d,%d: rim %d,%d solid %d of 4 above the walk, walk %s"):format(
					c.key, ti, x, z, rx, rz, rim, tostring(walk_ok)))
				check(rim >= 3, c.key .. " tower rim at point " .. ti)
			end}
		end
	end
	check(towers == 2, c.key .. ": two dry towers to check")
	-- the north gate: passage open, tower columns standing
	local g = L.gates.north
	local gx, gz = AX + g.x, AZ + g.z
	local minp, maxp = area(round(gx), round(gz), g.y - 30, g.y + 16)
	jobs[#jobs + 1] = {label = c.key .. " north gate", minp = minp, maxp = maxp, run = function()
		local open = 0
		for y = g.y + 2, g.y + 5 do
			if not solid({x = round(gx), y = y, z = round(gz)}) then open = open + 1 end
		end
		local towers_up = 0
		for _, s in ipairs({-1, 1}) do
			local ww = s * (dims.width - 1)
			local x, z = round(gx - g.dz * ww), round(gz + g.dx * ww)
			if solid({x = x, y = g.y + 8, z = z}) then towers_up = towers_up + 1 end
		end
		log(("%s north gate at %.0f,%.0f floor %d: passage open %d of 4, tower columns %d of 2"):format(
			c.key, gx, gz, g.y, open, towers_up))
		check(open == 4, c.key .. " north gate passage open")
		check(towers_up == 2, c.key .. " north gate tower columns")
	end}
	-- protection and claims (no map needed)
	local p = W.pts[picks[1]]
	local r = sqrt(p[1] * p[1] + p[2] * p[2])
	local ux, uz = p[1] / r, p[2] / r
	local function at(d)
		local x, z = round(AX + p[1] + ux * d), round(AZ + p[2] + uz * d)
		return {x = x, y = floor(grug_zones.terrain_height_at(x, z)) + 1, z = z}
	end
	local mid = at(-(r - 48) / 2)
	local band, beyond = at(15), at(45)
	local k_mid, k_band, k_beyond = grug_zones.hard_protection_kind_at(mid),
		grug_zones.hard_protection_kind_at(band), grug_zones.hard_protection_kind_at(beyond)
	log(("%s protection: inside %s -> %s, wall+15 %s -> %s, wall+45 %s -> %s"):format(c.key,
		core.pos_to_string(mid), tostring(k_mid), core.pos_to_string(band), tostring(k_band),
		core.pos_to_string(beyond), tostring(k_beyond)))
	check(k_mid == "town", c.key .. " inside the wall is the protected city")
	check(k_band == "town", c.key .. " the band beyond the wall is protected")
	check(k_beyond ~= "town", c.key .. " 45 beyond the wall is not the city")
	local R_CLAIM = grug_housing.model.RADIUS
	local clear = 21 + (R_CLAIM + grug_housing.model.SETTLEMENT_MARGIN) * (math.abs(ux) + math.abs(uz)) + 8
	local near, far, stone_far = at(30), at(75), at(clear)
	local m = grug_housing.model.SETTLEMENT_MARGIN
	local _, k_near = grug_zones.hard_footprint_in(near.x - m, near.z - m, near.x + m, near.z + m)
	local _, k_far = grug_zones.hard_footprint_in(far.x - m, far.z - m, far.x + m, far.z + m)
	local ok_near, code_near = zone_check(c.player, near)
	local ok_far, code_far = zone_check(c.player, stone_far)
	log(("%s claims (margin %d): wall+30 footprint %s, stone %s; wall+75 footprint %s; wall+%.0f stone %s"):format(
		c.key, m, tostring(k_near), ok_near and "ok" or tostring(code_near), tostring(k_far),
		clear, ok_far and "ok" or tostring(code_far)))
	check(k_near ~= nil, c.key .. " capital footprint within the claim margin at wall+30")
	check(not ok_near and code_near == "town", c.key .. " a stone at wall+30 is refused as town")
	check(k_far == nil, c.key .. " no capital footprint within the margin at wall+75")
	check(ok_far or code_far ~= "town", c.key .. " a stone clear of the band is not refused as town")
end

core.after(3, function()
	local path = core.get_worldpath() .. "/grug_world_layouts.txt"
	local f = io.open(path, "rb")
	if not check(f ~= nil, "world layout file " .. path) then return finish() end
	local all = f:read("*a")
	f:close()
	local section = all:match("section capital %d+ %x+\n(.-)\nsection ")
	if not check(section ~= nil, "capital section in the layout file") then return finish() end
	local texts = planner.split(section .. "\n")
	for _, c in ipairs(CAPITALS) do
		local ok, L = pcall(planner.deserialize, texts[c.id] or "")
		if check(ok, c.key .. " layout parses") then plan_capital(c, L) end
	end
	log(("%d emerge jobs"):format(#jobs))
	run_jobs(1)
end)
