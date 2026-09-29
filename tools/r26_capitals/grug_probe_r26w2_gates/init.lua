-- Round 26 playtest fix engine probe (disposable, never shipped), seed
-- 3464175725660475642 (the playtest world "test"; run with
-- tools/r26_capitals/engine_gates.sh):
--   1. all six capitals: at each of the four gates, after emerging the
--      ground round it, the wall closes against the gatehouse on both sides:
--      where the wall's centre line leaves the gatehouse box (across a flank,
--      or at a corner where the wall turns off the water), the first three
--      columns on it outside the box carry masonry or stakes at the walk; a
--      side that runs into the civic lake (the lake is the edge there) is
--      logged and skipped;
--   2. Lethariel's west wall where the playtest saw a V into the river (rays
--      -164 to -134 degrees): every walled point of that stretch carries
--      masonry at its walk, and the number of points over water is logged.
-- Ends the server itself; "RESULT PASS" is the verdict line.
local PREFIX = "[r26w2_gates_probe] "
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
	core.request_shutdown("r26w2 gates probe done", false, 0)
end

local floor, sqrt, abs, atan2 = math.floor, math.sqrt, math.abs, math.atan2
local planner = dofile(core.get_modpath("grug_mapgen") .. "/wp40/capital_planner.lua")
local CAPITALS = {{id = "anchor_008", key = "highcourt"}, {id = "anchor_007", key = "dur_brannoc"},
	{id = "anchor_010", key = "nhal_veyr"}, {id = "anchor_011", key = "gor_drazhak"},
	{id = "anchor_009", key = "lethariel"}, {id = "anchor_012", key = "kezamba"}}

local function solid(pos)
	local node = core.get_node(pos)
	return node.name ~= "air" and node.name ~= "ignore" and
		not node.name:find("water", 1, true), node.name
end
local function round(v) return floor(v + 0.5) end

local jobs = {}
local function run_jobs(i)
	local job = jobs[i]
	if not job then return finish() end
	local started = core.get_us_time()
	core.emerge_area(job.minp, job.maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED %s in %.1f s"):format(job.label, (core.get_us_time() - started) / 1e6))
		job.run()
		run_jobs(i + 1)
	end)
end

local function plan_capital(c, L)
	local AX, AZ = L.anchor.x, L.anchor.z
	local dims = planner.EDGE[L.kind]
	local W = L.wall
	local n = #W.pts
	-- the walk top of the wall point nearest a local column
	local function nearest(lx, lz)
		local best, bi
		for i = 1, n do
			local dx, dz = lx - W.pts[i][1], lz - W.pts[i][2]
			local d = dx * dx + dz * dz
			if not best or d < best then best, bi = d, i end
		end
		return bi
	end
	for gi = 1, 4 do
		local g = L.gates[gi]
		local gx, gz = AX + g.x, AZ + g.z
		jobs[#jobs + 1] = {label = c.key .. " gate " .. g.name,
			minp = {x = round(gx) - 20, y = g.y - 30, z = round(gz) - 20},
			maxp = {x = round(gx) + 20, y = g.y + 20, z = round(gz) + 20}, run = function()
				-- the wall points inside this gatehouse's box (a cyclic run);
				-- the wall leaves it at both ends of the run
				local function boxed(i)
					local p = W.pts[i]
					local dd = (p[1] - g.x) * g.dx + (p[2] - g.z) * g.dz
					local ww = -(p[1] - g.x) * g.dz + (p[2] - g.z) * g.dx
					return abs(dd) <= dims.depth + 0.5 and abs(ww) <= dims.width + 0.5
				end
				local first
				for i = 1, n do
					if boxed(i) and not boxed((i - 2) % n + 1) then first = i break end
				end
				if not check(first ~= nil, c.key .. " gate " .. g.name .. " wall through the box") then return end
				local last = first
				while boxed(last % n + 1) do last = last % n + 1 end
				for _, side in ipairs({{first, -1}, {last, 1}}) do
					-- the three centre-line columns next to the box on the wall's
					-- way out, from the last point inside onwards
					local cols, lake, detail, seen = 0, false, {}, {}
					local i = side[1]
					local steps = 0
					while #detail < 3 and steps < 12 do
						local j = (i - 1 + side[2]) % n + 1
						local a, b = W.pts[i], W.pts[j]
						if W.lake[j] then lake = true end
						for k = 0, 20 do
							local t = k / 20
							local lx, lz = a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2])
							local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
							local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
							local x, z = AX + round(lx), AZ + round(lz)
							local key = x .. "," .. z
							if #detail < 3 and not seen[key] and
									(abs(dd) > dims.depth + 0.5 or abs(ww) > dims.width + 0.5) then
								seen[key] = true
								local wi = nearest(lx, lz)
								local top = floor(floor(W.walk[wi] + 0.5) / 2)
								local got = 0
								for y = top - 3, top do if solid({x = x, y = y, z = z}) then got = got + 1 end end
								if got >= 2 then cols = cols + 1 end
								detail[#detail + 1] = ("%s:%d"):format(key, got)
							end
						end
						i, steps = j, steps + 1
					end
					log(("%s gate %s side %d: wall columns %d of %d next to the box (%s)%s"):format(
						c.key, g.name, side[2], cols, #detail, table.concat(detail, " "),
						lake and " [civic lake edge]" or ""))
					if not lake then
						check(cols == 3, c.key .. " gate " .. g.name .. " wall against the box " .. side[2])
					end
				end
			end}
	end
	if c.key == "lethariel" then
		local stretch = {}
		for i = 1, n do
			local p = W.pts[i]
			local deg = math.deg(atan2(p[2], p[1]))
			if deg >= -164 and deg <= -134 and not W.gap[i] and not W.lake[i] then
				stretch[#stretch + 1] = i
			end
		end
		local minx, maxx, minz, maxz = math.huge, -math.huge, math.huge, -math.huge
		for _, i in ipairs(stretch) do
			local p = W.pts[i]
			minx, maxx = math.min(minx, p[1]), math.max(maxx, p[1])
			minz, maxz = math.min(minz, p[2]), math.max(maxz, p[2])
		end
		jobs[#jobs + 1] = {label = "lethariel west stretch",
			minp = {x = AX + floor(minx) - 8, y = -10, z = AZ + floor(minz) - 8},
			maxp = {x = AX + floor(maxx) + 8, y = 90, z = AZ + floor(maxz) + 8}, run = function()
				local ok_pts, wet = 0, 0
				for _, i in ipairs(stretch) do
					local p = W.pts[i]
					local top = floor(W.walk[i] / 2)
					local x, z = AX + round(p[1]), AZ + round(p[2])
					if solid({x = x, y = top, z = z}) then ok_pts = ok_pts + 1 end
					if W.wet[i] then wet = wet + 1 end
				end
				log(("lethariel west stretch: %d points, walk masonry on %d, over water %d"):format(
					#stretch, ok_pts, wet))
				check(#stretch > 20 and ok_pts == #stretch, "lethariel west stretch walled")
			end}
	end
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
