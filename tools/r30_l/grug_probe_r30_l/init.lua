-- Round 30 Lane L engine probe (disposable, never shipped): the piers and
-- beaches at the four dragon-island boat landings on a real world.
--
-- Per landing (`source.island_landings`): the shore point is found as the
-- mapgen finds it (walking the boat line from the landing toward the
-- mainland to the first sea column), a box round it is emerged and the
-- generated nodes are read:
-- 1. DECK: 2 wide at y 2 over every water column 1..10 out, in the zone's
--    planks (Wyrmglass pine, Stormscale jungle wood);
-- 2. POSTS: at 10, 7, 4 and 1 out every post column is trunk from the floor
--    up (no water left under it), the side posts carry a fence at y 3;
-- 3. BEACH: sand top nodes at y 1..3 within 12 nodes either side of the
--    boat line (at least 150), and the boat-line column's top 8 land
--    columns no higher than y 3;
-- 4. WALK: from the pier head, over walkable top nodes (deck, ground; no
--    water, no fence), stepping at most one node up or down between
--    4-neighbours, the back of the beach (top node y 3) is reached. The
--    highest top reached within 40 nodes is logged.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r30_l_probe] "
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

local source = dofile(core.get_modpath("grug_mapgen") .. "/wp40/source/simple_map.lua")
local WOOD = {dwarf = {"default:pine_wood", "default:pine_tree", "default:fence_pine_wood"},
	troll = {"default:junglewood", "default:jungletree", "default:fence_junglewood"}}
local REACH, Y0, Y1 = 40, -16, 40

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r30 l probe done", false, 0)
end

local function name_at(x, y, z) return core.get_node({x = x, y = y, z = z}).name end
local function liquid(name)
	local def = core.registered_nodes[name]
	return def ~= nil and (def.liquidtype or "none") ~= "none"
end
-- The top walkable node of a column within Y0..Y1 and whether water stands
-- on it; a fence is no floor.
local function top_at(x, z)
	for y = Y1, Y0, -1 do
		local name = name_at(x, y, z)
		local def = core.registered_nodes[name]
		if liquid(name) then return nil end
		if def and def.walkable and not name:find("fence") then return y end
	end
	return nil
end

local function landing(row, done)
	local path
	for _, p in ipairs(source.boat_paths) do if p.id == row.boat_path_id then path = p end end
	local line = path.centreline
	local dx = line[#line - 1].x - line[#line].x
	local dz = line[#line - 1].z - line[#line].z
	local ux, uz = 0, 0
	if math.abs(dx) >= math.abs(dz) then ux = dx > 0 and 1 or -1 else uz = dz > 0 and 1 or -1 end
	local sx, sz
	for k = 0, 160 do
		local x, z = row.position.x + k * ux, row.position.z + k * uz
		if grug_zones.water_class_at(x, z) ~= "land" then
			if k > 0 then sx, sz = x - ux, z - uz end
			break
		end
	end
	if not check(sx ~= nil, row.id .. " shore point") then return done() end
	local vx, vz = -uz, ux
	local function at(a, b) return sx + a * ux + b * vx, sz + a * uz + b * vz end
	local wood = WOOD[source.zones[row.zone_numeric_id].race_region]
	local t0 = core.get_us_time()
	core.emerge_area({x = sx - REACH, y = Y0, z = sz - REACH}, {x = sx + REACH, y = Y1, z = sz + REACH},
		function(_, _, remaining)
			if remaining > 0 then return end
			local ok, err = pcall(function()
				log(("%s: shore %d,%d emerged in %.1f s"):format(row.id, sx, sz,
					(core.get_us_time() - t0) / 1000000))
				local function water(x, z) return liquid(name_at(x, 1, z)) end
				-- 1. deck
				local deck = 0
				for a = 1, 10 do
					for b = 0, 1 do
						local x, z = at(a, b)
						if water(x, z) then
							deck = deck + 1
							check(name_at(x, 2, z) == wood[1], ("%s deck at %d out, %d across: %s")
								:format(row.id, a, b, name_at(x, 2, z)))
						end
					end
				end
				log(("%s: %d deck columns over water, deck node %s"):format(row.id, deck,
					name_at(at(10, 0), 2, select(2, at(10, 0)))))
				check(deck >= 16, row.id .. " deck over at least 16 water columns")
				-- 2. posts
				local floors = {}
				for _, a in ipairs({10, 7, 4, 1}) do
					for b = -1, 2 do
						local x, z = at(a, b)
						if water(x, z) then
							local top = (b == -1 or b == 2) and 2 or 1
							local y = top
							while y > Y0 and name_at(x, y, z) == wood[2] do y = y - 1 end
							local below = name_at(x, y, z)
							check(not liquid(below) and y < top, ("%s post at %d out, %d across stands on %s")
								:format(row.id, a, b, below))
							floors[#floors + 1] = y
							if top == 2 then
								check(name_at(x, 3, z) == wood[3], ("%s fence at %d out, %d across")
									:format(row.id, a, b))
							end
						end
					end
				end
				log(("%s: post rows stand on floors y %s"):format(row.id, table.concat(floors, ",")))
				-- 3. beach
				local sand, high = 0, 0
				for b = -12, 12 do
					local first
					for a = 12, -20, -1 do
						local x, z = at(a, b)
						local y = top_at(x, z)
						if y and y >= 1 and y <= 3 and name_at(x, y, z) == "default:sand" and
								a <= 0 and a >= -11 then
							sand = sand + 1
						end
						if not first and y then first = a end
					end
					if math.abs(b) <= 6 and first then
						for a = first, first - 7, -1 do
							local x, z = at(a, b)
							local y = top_at(x, z)
							-- the deck's land end stands on the beach (top y 2)
							if not (b >= 0 and b <= 1 and a >= -1 and y == 2) and
									(y == nil or y > 3) then
								high = high + 1
							end
						end
					end
				end
				log(("%s: %d sand top nodes at y 1..3, %d middle columns above y 3"):format(row.id, sand, high))
				check(sand >= 150, row.id .. " beach of at least 150 sand columns")
				check(high == 0, row.id .. " beach middle no higher than y 3")
				-- 4. walk
				local hx, hz = at(10, 0)
				local seen, queue, head = {[hx .. "," .. hz] = true}, {{hx, hz, top_at(hx, hz)}}, 1
				local reached, max_top = false, -100
				while head <= #queue do
					local x, z, y = queue[head][1], queue[head][2], queue[head][3]
					head = head + 1
					if y == 3 and math.abs((x - sx) * vx + (z - sz) * vz) <= 12 and
							name_at(x, y, z) == "default:sand" then
						reached = true
					end
					if y > max_top then max_top = y end
					for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
						local nx, nz = x + d[1], z + d[2]
						local key = nx .. "," .. nz
						if not seen[key] and math.abs(nx - sx) <= REACH and math.abs(nz - sz) <= REACH then
							local ny = top_at(nx, nz)
							if ny and math.abs(ny - y) <= 1 and
									core.registered_nodes[name_at(nx, ny + 1, nz)].walkable ~= true then
								seen[key] = true
								queue[#queue + 1] = {nx, nz, ny}
							end
						end
					end
				end
				log(("%s: walk from the pier head reaches %d columns, highest top y %d"):format(row.id,
					#queue, max_top))
				check(reached, row.id .. " walk from the pier head to the back of the beach")
			end)
			check(ok, row.id .. " scenario ran (" .. tostring(err) .. ")")
			done()
		end)
end

core.after(2, function()
	local index = 0
	local function step()
		index = index + 1
		if index > #source.island_landings then return finish() end
		landing(source.island_landings[index], step)
	end
	step()
end)
