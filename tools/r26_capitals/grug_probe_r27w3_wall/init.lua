-- Round 27 wall fixes engine probe (disposable, never shipped), seed
-- 7522774488337609340 (the user's playtest world "test"; run with
-- tools/r26_capitals/engine_wall.sh):
--   1. Gor Drazhak where the playtest saw a square on the wall line and the
--      wall missing (around -139, 1616): every wall centre-line column within
--      SPOT_R of it carries masonry or stakes at the walk (two of the four
--      nodes from the walk down);
--   2. every gatehouse of the six capitals (the Kezamba south gate at
--      1760, 1619 is the one the playtest saw with its beams in the air): the
--      outermost column either side of the passage, in every row of the box,
--      is a tower that stands on the ground -- from its top edge node down,
--      only edge nodes until a solid node of the terrain, never air or water
--      under it; air under it that is covered on every side (a cave under the
--      ground's crust the tower stands in, not open to the sky) is logged, not
--      a tower in the air.
-- Ends the server itself; "RESULT PASS" is the verdict line.
local PREFIX = "[r27w3_wall_probe] "
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
	core.request_shutdown("r27w3 wall probe done", false, 0)
end

local floor, sqrt, abs = math.floor, math.sqrt, math.abs
local modpath = core.get_modpath("grug_mapgen")
local planner = dofile(modpath .. "/wp40/capital_planner.lua")
local blueprint = dofile(modpath .. "/wp40/r7_capital_blueprint.lua")
local city_edge = dofile(modpath .. "/wp13/city_edge.lua")(modpath .. "/wp13")
local CAPITALS = {{id = "anchor_008", key = "highcourt"}, {id = "anchor_007", key = "dur_brannoc"},
	{id = "anchor_010", key = "nhal_veyr"}, {id = "anchor_011", key = "gor_drazhak"},
	{id = "anchor_009", key = "lethariel"}, {id = "anchor_012", key = "kezamba"}}
local SPOT = {key = "gor_drazhak", x = -139, z = 1616}
local SPOT_R = 20

local function node_name(pos) return core.get_node(pos).name end
local function open_node(name)
	return name == "air" or name == "ignore" or name:find("water", 1, true) ~= nil
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
	local cfg = blueprint.CAPITALS[c.key]
	local edge_name = {}
	for _, name in ipairs(city_edge.names(cfg.race, dims.model)) do
		if name ~= "air" then edge_name[name] = true end
	end
	local W = L.wall
	local n = #W.pts
	for gi = 1, 4 do
		local g = L.gates[gi]
		local gx, gz = AX + g.x, AZ + g.z
		local reach = dims.width + 2
		jobs[#jobs + 1] = {label = c.key .. " gate " .. g.name,
			minp = {x = round(gx) - reach, y = g.y - 24, z = round(gz) - reach},
			maxp = {x = round(gx) + reach, y = g.y + 16, z = round(gz) + reach}, run = function()
				local towers, standing, bad, caves = 0, 0, {}, 0
				for z = round(gz) - reach, round(gz) + reach do
					for x = round(gx) - reach, round(gx) + reach do
						local lx, lz = x - AX, z - AZ
						local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
						local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
						if abs(dd) <= dims.depth + 0.5 and abs(ww) <= dims.width + 0.5 and
								abs(floor(ww + 0.5)) >= dims.width then
							towers = towers + 1
							-- the tower's top edge node, then down through edge
							-- nodes to the first other node: it must be solid
							local y = g.y + 16
							while y > g.y - 24 and not edge_name[node_name({x = x, y = y, z = z})] do
								y = y - 1
							end
							local ok = false
							if y > g.y - 24 then
								while y > g.y - 24 and edge_name[node_name({x = x, y = y, z = z})] do
									y = y - 1
								end
								local below = node_name({x = x, y = y, z = z})
								ok = y <= g.y - 24 or not open_node(below)
								-- a cave under the terrain's crust (the tower's
								-- foot in the ground, a void below it) is not a
								-- tower in the air: the air under it is floating
								-- only where it, or the node beside it, lies open
								-- to the sky (air for twelve nodes up)
								if not ok then
									local function sky(px, pz)
										for yy = y, y + 12 do
											if not open_node(node_name({x = px, y = yy, z = pz})) then return false end
										end
										return true
									end
									local open_air = false
									for _, d in ipairs({{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
										if sky(x + d[1], z + d[2]) then open_air = true end
									end
									if not open_air then
										ok = true
										caves = caves + 1
										log(("%s gate %s: a cave under the ground's crust below the tower column %d,%d (air at y %d, covered)"):format(
											c.key, g.name, x, z, y))
									end
								end
								if not ok then
									local stack = {}
									for yy = y - 6, y + 3 do
										stack[#stack + 1] = yy .. "=" .. node_name({x = x, y = yy, z = z})
									end
									bad[#bad + 1] = ("%d,%d,%d:%s [%s]"):format(x, y, z, below,
										table.concat(stack, " "))
								end
							else
								bad[#bad + 1] = ("%d,%d:no tower"):format(x, z)
							end
							if ok then standing = standing + 1 end
						end
					end
				end
				log(("%s gate %s at %d,%d: outer tower columns %d, standing on the ground %d (over a covered cave %d)%s"):format(
					c.key, g.name, round(gx), round(gz), towers, standing, caves,
					#bad > 0 and (" (unsupported " .. table.concat(bad, " ") .. ")") or ""))
				check(towers > 0 and standing == towers, c.key .. " gate " .. g.name .. " towers on the ground")
			end}
	end
	if c.key == SPOT.key then
		jobs[#jobs + 1] = {label = c.key .. " playtest spot",
			minp = {x = SPOT.x - SPOT_R - 4, y = -10, z = SPOT.z - SPOT_R - 4},
			maxp = {x = SPOT.x + SPOT_R + 4, y = 110, z = SPOT.z + SPOT_R + 4}, run = function()
				local seen, cols, closed, open = {}, 0, 0, {}
				for i = 1, n do
					local j = i % n + 1
					if not (W.gap[i] and W.gap[j]) then
						local a, b = W.pts[i], W.pts[j]
						for k = 0, 8 do
							local t = k / 8
							local lx, lz = a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2])
							local x, z = AX + round(lx), AZ + round(lz)
							local dx, dz = x - SPOT.x, z - SPOT.z
							local key = x .. "," .. z
							if dx * dx + dz * dz <= SPOT_R * SPOT_R and not seen[key] then
								seen[key] = true
								cols = cols + 1
								local wi = (t < 0.5) and i or j
								local top = floor(floor(W.walk[wi] + 0.5) / 2)
								local got = 0
								for y = top - 3, top do
									if not open_node(node_name({x = x, y = y, z = z})) then got = got + 1 end
								end
								if got >= 2 then closed = closed + 1 else open[#open + 1] = key end
							end
						end
					end
				end
				log(("%s playtest spot %d,%d: wall centre-line columns %d, walled %d%s"):format(
					c.key, SPOT.x, SPOT.z, cols, closed,
					#open > 0 and (" (open " .. table.concat(open, " ") .. ")") or ""))
				check(cols >= 20 and closed == cols, c.key .. " playtest spot walled")
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
