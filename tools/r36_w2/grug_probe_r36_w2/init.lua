-- Disposable Round 36 lane W2 probe (tools/r36_w2/engine.sh). Never shipped.
--
-- Which way does a placed bench seat face? Highcourt's square round its
-- anchor is emerged; every Highcourt seat (`stairs:stair_wood`, upright,
-- open above, on a floor, with room for feet beside it) is measured:
--   RAISED  the engine's own geometry: a ray straight down onto each quarter
--           of the cell; the side whose two quarters are hit half a node
--           higher is the raised half, the backrest. It is compared with the
--           seat's param2 (`core.facedir_to_dir`).
--   WALLS   the cells on the raised side (behind the sitter) and on the low
--           side (before the sitter's knees): a house wall when the three
--           columns there (along the bench) are walkable blocks at the
--           seat's course with a block, a pane or a door above.
-- Each seat is counted as "back to a wall", "facing a wall", both or
-- neither, and the first seats of each kind are logged in full. Every line
-- carries "[r36w2]"; the probe ends the server when done.
local P = "[r36w2] "
local function log(s) core.log("action", P .. s) end

local SEAT = "stairs:stair_wood"
local R, DOWN, UP = 64, 12, 20
local STEP = {[0] = {0, 1}, {1, 0}, {0, -1}, {-1, 0}}

local function walkable(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable == true
end
local function stair(name) return name:find("^stairs:stair") ~= nil end
local function wall(name) return walkable(name) and not stair(name) end
-- A block of a house wall: a walkable full node.
local FULL = {normal = true, glasslike = true, glasslike_framed = true, allfaces = true,
	allfaces_optional = true}
local function block(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable == true and FULL[def.drawtype or "normal"] == true
end

-- The height above the cell's floor where a ray straight down first meets
-- the node at p, at the point (p.x + dx, p.z + dz).
local function height(p, dx, dz)
	local x, z = p.x + dx, p.z + dz
	for pt in core.raycast({x = x, y = p.y + 1.45, z = z}, {x = x, y = p.y - 0.45, z = z},
			false, false) do
		if pt.type == "node" and vector.equals(pt.under, p) then
			return pt.intersection_point.y - (p.y - 0.5)
		end
	end
end

-- The raised half: the facedir whose two quarters stand higher than the
-- other two, and the four heights as text.
local function raised_side(p)
	local h = {}
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do
			h[sx .. "," .. sz] = height(p, 0.25 * sx, 0.25 * sz) or -1
		end
	end
	local text = ("(-,-)=%.2f (-,+)=%.2f (+,-)=%.2f (+,+)=%.2f"):format(h["-1,-1"], h["-1,1"],
		h["1,-1"], h["1,1"])
	for d = 0, 3 do
		local s = STEP[d]
		local hi, lo = {}, {}
		for key, v in pairs(h) do
			local sx, sz = key:match("^(-?%d+),(-?%d+)$")
			if tonumber(sx) * s[1] + tonumber(sz) * s[2] > 0 then hi[#hi + 1] = v else lo[#lo + 1] = v end
		end
		if math.min(hi[1], hi[2]) > math.max(lo[1], lo[2]) + 0.25 then return d, text end
	end
	return nil, text
end

local function run()
	local center = grug_core.capital_anchor("accord", "human")
	log("Highcourt anchor " .. core.pos_to_string(center))
	local p1 = {x = center.x - R, y = center.y - DOWN, z = center.z - R}
	local p2 = {x = center.x + R, y = center.y + UP, z = center.z + R}
	local t0 = core.get_us_time()
	core.emerge_area(p1, p2, function(_, _, remaining)
		if remaining > 0 then return end
		log(("emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
		local vm = core.get_voxel_manip()
		local e1, e2 = vm:read_from_map(p1, p2)
		local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
		local data, param2 = vm:get_data(), vm:get_param2_data()
		local c_seat = core.get_content_id(SEAT)
		local function name_at(x, y, z)
			if not area:contains(x, y, z) then return "ignore" end
			return core.get_name_from_content_id(data[area:index(x, y, z)])
		end
		local counts = {seats = 0, agree = 0, disagree = 0, back = 0, front = 0, both = 0, neither = 0}
		local shown = {back = 0, front = 0}
		for z = p1.z + 1, p2.z - 1 do
			for y = p1.y + 1, p2.y - 1 do
				for x = p1.x + 1, p2.x - 1 do
					local i = area:index(x, y, z)
					if data[i] == c_seat and param2[i] < 4 and name_at(x, y + 1, z) == "air" and
							wall(name_at(x, y - 1, z)) then
						-- room for feet beside it, and not a step of a stairway
						local feet = false
						for d = 0, 3 do
							local s = STEP[d]
							local nx, nz = x + s[1], z + s[2]
							if name_at(nx, y, nz) == "air" and name_at(nx, y + 1, nz) == "air" and
									wall(name_at(nx, y - 1, nz)) then
								feet = true
							end
						end
						local u = STEP[param2[i]]
						if feet and not stair(name_at(x + u[1], y + 1, z + u[2])) then
							local p = {x = x, y = y, z = z}
							counts.seats = counts.seats + 1
							local d, heights = raised_side(p)
							local dir = core.facedir_to_dir(param2[i])
							if d ~= nil and STEP[d][1] == dir.x and STEP[d][2] == dir.z then
								counts.agree = counts.agree + 1
							else
								counts.disagree = counts.disagree + 1
								log(("DISAGREE %s param2=%d dir=%s raised=%s %s"):format(core.pos_to_string(p),
									param2[i], core.pos_to_string(dir), tostring(d), heights))
							end
							if d ~= nil then
								local b, f = STEP[d], STEP[(d + 2) % 4]
								local back = {name_at(x + b[1], y, z + b[2]), name_at(x + b[1], y + 1, z + b[2])}
								local front = {name_at(x + f[1], y, z + f[2]), name_at(x + f[1], y + 1, z + f[2])}
								-- a house wall: three columns wide along the bench, each a
								-- block at the seat's course and a block, a pane or a door
								-- above it (a lone post, a lamp or a table is none)
								local function house(s)
									for k = -1, 1 do
										local cx, cz = x + s[1] + k * s[2], z + s[2] + k * s[1]
										local up = name_at(cx, y + 1, cz)
										if not block(name_at(cx, y, cz)) or not (block(up) or
												up:find("^xpanes:") or up:find("^doors:")) then
											return false
										end
									end
									return true
								end
								local bw, fw = house(b), house(f)
								local kind = (bw and fw) and "both" or bw and "back" or fw and "front" or "neither"
								counts[kind] = counts[kind] + 1
								if shown[kind] and shown[kind] < 3 then
									shown[kind] = shown[kind] + 1
									log(("SEAT %s %s param2=%d facedir_to_dir=%s quarter heights %s -> raised half %s; behind %s/%s, before %s/%s"):format(
										kind == "back" and "back-to-wall" or "facing-wall", core.pos_to_string(p),
										param2[i], core.pos_to_string(dir), heights, core.pos_to_string(
										{x = b[1], y = 0, z = b[2]}), back[1], back[2], front[1], front[2]))
								end
							end
						end
					end
				end
			end
		end
		log(("COUNT seats=%d raised-half-is-param2-dir=%d other=%d back-to-a-house-wall=%d facing-a-house-wall=%d both=%d neither=%d")
			:format(counts.seats, counts.agree, counts.disagree, counts.back, counts.front, counts.both,
				counts.neither))
		log("RESULT DONE")
		core.request_shutdown("r36w2 probe done", false, 1)
	end)
end

local waited = 0
local function wait()
	waited = waited + 1
	if grug_core.zone_authority_installed and grug_core.zone_authority_installed() and
			grug_core.capital_anchor("accord", "human") then
		run()
	elseif waited < 60 then
		core.after(1, wait)
	else
		log("RESULT no capital anchor")
		core.request_shutdown("r36w2 probe failed", false, 1)
	end
end
core.after(1, wait)
