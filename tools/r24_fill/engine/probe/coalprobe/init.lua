-- Disposable coal-density probe (never shipped). Finds the orc start, emerges
-- a box around it, then reads the finished map and logs node counts per depth
-- band below the actual local ground top, per column class.
local R = tonumber(core.settings:get("coalprobe_radius")) or 320
local STOP = tonumber(core.settings:get("coalprobe_stop")) or 280
local Y_LO = -112
local box, started, emerging, done = nil, nil, false, false
local emerge_done_at

local r24_dumps
local function log(s) core.log("action", "[coalp] " .. s) end

core.register_on_mods_loaded(function()
	local anchor
	for _, row in ipairs(grug_core.start_identities()) do
		log(("start %s %d,%d,%d"):format(row.race_id, row.anchor.x, row.anchor.y, row.anchor.z))
		if row.race_id == "orc" then anchor = row.anchor end
	end
	assert(anchor, "no orc start")
	local src = grug_mapgen.wp40.planner_source
	local top = -1000
	for x = anchor.x - R, anchor.x + R, 4 do
		for z = anchor.z - R, anchor.z + R, 4 do
			local _, _, _, _, _, ty, wy = src.column_values_at(x, z)
			if ty > top then top = ty end
			if wy and wy > top then top = wy end
		end
	end
	box = {x0 = anchor.x - R, x1 = anchor.x + R, z0 = anchor.z - R, z1 = anchor.z + R,
		y0 = Y_LO, y1 = top + 24, ax = anchor.x, az = anchor.z}
	core.ipc_set("coalprobe:box", box)
	if core.settings:get_bool("r24_scan", false) then
		local t0 = core.get_us_time()
		local SR, ST = tonumber(core.settings:get("r24_scan_radius")) or 1500, 6
		local ty = {}
		local function key(i, j) return i * 100000 + j end
		local n = math.floor(SR / ST)
		for i = -n, n do
			for j = -n, n do
				local _, _, _, _, _, t, wy = src.column_values_at(anchor.x + i * ST, anchor.z + j * ST)
				ty[key(i, j)] = wy and wy > t and -1000 or t
			end
		end
		local best_drop, best_high = {}, {}
		for i = -n + 1, n - 1 do
			for j = -n + 1, n - 1 do
				local t = ty[key(i, j)]
				local low = math.min(ty[key(i + 1, j)], ty[key(i - 1, j)], ty[key(i, j + 1)], ty[key(i, j - 1)])
				local x, z = anchor.x + i * ST, anchor.z + j * ST
				local cell = math.floor(x / 128) .. "," .. math.floor(z / 128)
				local d = t - low
				if low > -1000 and (not best_drop[cell] or d > best_drop[cell][1]) then best_drop[cell] = {d, x, z, t, low} end
				if not best_high[cell] or t > best_high[cell][1] then best_high[cell] = {t, x, z} end
			end
		end
		local a, b = {}, {}
		for _, v in pairs(best_drop) do a[#a + 1] = v end
		for _, v in pairs(best_high) do b[#b + 1] = v end
		table.sort(a, function(p, q) return p[1] > q[1] end)
		table.sort(b, function(p, q) return p[1] > q[1] end)
		for k = 1, math.min(25, #a) do
			local v = a[k]
			local _, _, zone, biome = src.column_values_at(v[2], v[3])
			log(("scan drop %d over 6 at %d,%d top %d low %d zone %s biome %s"):format(v[1], v[2], v[3], v[4], v[5], tostring(zone), tostring(biome)))
		end
		for k = 1, math.min(25, #b) do
			local v = b[k]
			local _, _, zone, biome = src.column_values_at(v[2], v[3])
			log(("scan high %d at %d,%d zone %s biome %s"):format(v[1], v[2], v[3], tostring(zone), tostring(biome)))
		end
		log(("scan_us=%d samples=%d"):format(core.get_us_time() - t0, (2 * n + 1) * (2 * n + 1)))
	end
	log(("box %d..%d x %d..%d z %d..%d y (terrain top %d)"):format(box.x0, box.x1,
		box.z0, box.z1, box.y0, box.y1, top))
end)

local BANDS = {{1, 4, "01-04"}, {5, 8, "05-08"}, {9, 16, "09-16"}, {17, 32, "17-32"},
	{33, 64, "33-64"}, {65, 100000, "65+"}}
local function band_of(d)
	if d < 1 then return "above" end
	for i = 1, #BANDS do if d <= BANDS[i][2] then return BANDS[i][3] end end
end

local ground_cache = {}
local function is_ground(cid)
	local g = ground_cache[cid]
	if g == nil then
		local name = core.get_name_from_content_id(cid)
		local def = core.registered_nodes[name]
		g = def ~= nil and def.walkable ~= false and (def.drawtype == nil or def.drawtype == "normal")
			and not (def.groups and ((def.groups.leaves or 0) > 0 or (def.groups.tree or 0) > 0))
			and name ~= "air" and name ~= "ignore"
		ground_cache[cid] = g
	end
	return g
end

local function analyse()
	local src = grug_mapgen.wp40.planner_source
	local counts, cols, topdiff = {}, {}, {}
	local tops, open = {}, {}
	local names = {}
	local function name(cid)
		local n = names[cid]
		if not n then n = core.get_name_from_content_id(cid) names[cid] = n end
		return n
	end
	local function add(key, n)
		counts[key] = (counts[key] or 0) + (n or 1)
	end
	local t0 = core.get_us_time()
	for tx = box.x0, box.x1, 80 do
		for tz = box.z0, box.z1, 80 do
			local x1, z1 = math.min(box.x1, tx + 79), math.min(box.z1, tz + 79)
			local vm = VoxelManip()
			local e0, e1 = vm:read_from_map({x = tx, y = box.y0, z = tz}, {x = x1, y = box.y1, z = z1})
			local data = vm:get_data()
			local ex, ey = e1.x - e0.x + 1, e1.y - e0.y + 1
			for z = tz, z1 do
				for x = tx, x1 do
					local _, eid = src.static_exclusion_values_at(x, z)
					local wc, _, zone, biome, race, ty, wy = src.column_values_at(x, z)
					local cls = (eid or "none") .. "~w" .. tostring(wc)
					cols[cls] = (cols[cls] or 0) + 1
					local base = (z - e0.z) * ex * ey + (x - e0.x) + 1
					local top
					for y = box.y1, box.y0, -1 do
						local cid = data[base + (y - e0.y) * ex]
						if is_ground(cid) then top = y break end
					end
					if top then
						tops[(z - box.z0) * 100000 + (x - box.x0)] = top
						if not eid then open[(z - box.z0) * 100000 + (x - box.x0)] = true end
						local diff = top - ty
						if diff < -8 then diff = "<-8" elseif diff > 8 then diff = ">8" end
						topdiff[tostring(diff)] = (topdiff[tostring(diff)] or 0) + 1
						local bkey = cls .. "|biome=" .. tostring(biome) .. "|zone=" .. tostring(zone)
						cols[bkey] = (cols[bkey] or 0) + 1
						local cc = counts[cls]
						if not cc then cc = {} counts[cls] = cc end
						for y = top, box.y0, -1 do
							local cid = data[base + (y - e0.y) * ex]
							local b = band_of(top - y + 1)
							if y < -100 then b = "t2" end
							local t = cc[b]
							if not t then t = {} cc[b] = t end
							t[cid] = (t[cid] or 0) + 1
							if y >= -100 and y <= -60 then
								t = cc.deep60_100
								if not t then t = {} cc.deep60_100 = t end
								t[cid] = (t[cid] or 0) + 1
							end
						end
					else
						add(cls .. "|notop|col")
					end
				end
			end
		end
	end
	log(("analyse_us=%d"):format(core.get_us_time() - t0))
	-- Tunnel simulation: 1 wide x 2 high, 50 long, along x or z, in open
	-- (non-excluded) columns only. Mode "flat": fixed y = top(start) - d.
	-- Mode "follow": y = top(column) - d per column. d uniform in 3..10 (the
	-- tunnel floor depth; the ceiling is at d-1).
	local coal_cid = core.get_content_id("default:stone_with_coal")
	local rng = PcgRandom(12345)
	local function key(x, z) return (z - box.z0) * 100000 + (x - box.x0) end
	for _, mode in ipairs({"flat", "follow"}) do
		local n, dug_sum, seen_sum, zero, zero_dug = 0, 0, 0, 0, 0
		local hist = {}
		local tries = 0
		while n < 2000 and tries < 20000 do
			tries = tries + 1
			local alongx = rng:next(0, 1) == 0
			local x0 = rng:next(box.x0 + 2, box.x1 - 52)
			local z0 = rng:next(box.z0 + 2, box.z1 - 52)
			local d = rng:next(3, 10)
			local ok = true
			for i = -1, 50 do
				for side = -1, 1 do
					local x = alongx and x0 + i or x0 + side
					local z = alongx and z0 + side or z0 + i
					if not open[key(x, z)] then ok = false break end
				end
				if not ok then break end
			end
			if ok then
				n = n + 1
				local y_flat = tops[key(x0, z0)] - d
				local dug, seen = 0, 0
				local seen_set = {}
				local ylo, yhi = 1e9, -1e9
				for i = 0, 49 do
					local x = alongx and x0 + i or x0
					local z = alongx and z0 or z0 + i
					local y = mode == "flat" and y_flat or tops[key(x, z)] - d
					if y < ylo then ylo = y end
					if y > yhi then yhi = y end
				end
				local tvm = VoxelManip()
				local te0, te1 = tvm:read_from_map({x = x0 - 1, y = ylo - 1, z = z0 - 1},
					{x = alongx and x0 + 50 or x0 + 1, y = yhi + 2, z = alongx and z0 + 1 or z0 + 50})
				local tdata = tvm:get_data()
				local tex, tey = te1.x - te0.x + 1, te1.y - te0.y + 1
				local function look(x, y, z, isdug)
					local k = x .. "," .. y .. "," .. z
					if seen_set[k] then return end
					seen_set[k] = true
					local cid = tdata[(z - te0.z) * tex * tey + (y - te0.y) * tex + (x - te0.x) + 1]
					if cid == coal_cid then
						if isdug then dug = dug + 1 else seen = seen + 1 end
					end
				end
				for i = 0, 49 do
					local x = alongx and x0 + i or x0
					local z = alongx and z0 or z0 + i
					local y = mode == "flat" and y_flat or tops[key(x, z)] - d
					look(x, y, z, true) look(x, y + 1, z, true)
				end
				for i = 0, 49 do
					local x = alongx and x0 + i or x0
					local z = alongx and z0 or z0 + i
					local y = mode == "flat" and y_flat or tops[key(x, z)] - d
					look(x, y - 1, z, false) look(x, y + 2, z, false)
					for h = 0, 1 do
						if alongx then look(x, y + h, z - 1, false) look(x, y + h, z + 1, false)
						else look(x - 1, y + h, z, false) look(x + 1, y + h, z, false) end
					end
				end
				dug_sum, seen_sum = dug_sum + dug, seen_sum + seen
				if dug + seen == 0 then zero = zero + 1 end
				if dug == 0 then zero_dug = zero_dug + 1 end
				local b = math.min(dug + seen, 20)
				hist[b] = (hist[b] or 0) + 1
			end
		end
		local hs = {}
		for b = 0, 20 do hs[#hs + 1] = tostring(hist[b] or 0) end
		log(("tunnel mode=%s n=%d mean_dug=%.3f mean_seen_faces=%.3f P(no coal dug or exposed)=%.3f P(no coal dug)=%.3f hist0..20=%s"):format(
			mode, n, dug_sum / n, seen_sum / n, zero / n, zero_dug / n, table.concat(hs, ",")))
	end
	log("topdiff " .. core.write_json(topdiff))
	for k, v in pairs(cols) do log(("col %s %d"):format(k, v)) end
	for cls, cc in pairs(counts) do
		if type(cc) == "table" then
			for b, t in pairs(cc) do
				for cid, v in pairs(t) do log(("cnt %s|%s|%s %d"):format(cls, b, name(cid), v)) end
			end
		else
			log(("cnt %s %d"):format(cls, cc))
		end
	end
end

-- Round 24 Lane B: after the coal stage, emerge and dump render boxes
-- (r24_boxes = "name:x0:z0:x1:z1:y0:y1;..."), one after the other, timing
-- each emerge; then a normal shutdown.
local function dump_box(b)
	local air = core.get_content_id("air")
	local names = {}
	local file = assert(io.open(core.get_worldpath() .. "/r24_dump_" .. b.name .. ".tsv", "w"))
	local count = 0
	for strip = b.z0, b.z1, 16 do
		local last = math.min(b.z1, strip + 15)
		local vm = VoxelManip()
		local e1, e2 = vm:read_from_map({x = b.x0, y = b.y0, z = strip}, {x = b.x1, y = b.y1, z = last})
		local area = VoxelArea(e1, e2)
		local data, param2 = vm:get_data(), vm:get_param2_data()
		for z = strip, last do
			for y = b.y0, b.y1 do
				for x = b.x0, b.x1 do
					local i = area:index(x, y, z)
					local cid = data[i]
					if cid ~= air then
						local name = names[cid]
						if not name then name = core.get_name_from_content_id(cid) names[cid] = name end
						file:write(x - b.x0, "\t", y, "\t", z - b.z0, "\t", name, "\t", param2[i], "\n")
						count = count + 1
					end
				end
			end
		end
	end
	file:close()
	log(("dump %s %d nodes"):format(b.name, count))
end
r24_dumps = function()
	local spec = core.settings:get("r24_boxes") or ""
	local boxes = {}
	for part in spec:gmatch("[^;]+") do
		local n, a, b, c, d, e, f = part:match("^(%w+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)$")
		if n then boxes[#boxes + 1] = {name = n, x0 = tonumber(a), z0 = tonumber(b), x1 = tonumber(c),
			z1 = tonumber(d), y0 = tonumber(e), y1 = tonumber(f)} end
	end
	local k = 0
	local function nextbox()
		k = k + 1
		local b = boxes[k]
		if not b then core.request_shutdown("coalprobe done", false, 0) return end
		local t0 = core.get_us_time()
		log(("box %s emerge start"):format(b.name))
		core.emerge_area({x = b.x0, y = b.y0, z = b.z0}, {x = b.x1, y = b.y1, z = b.z1},
			function(_, _, remaining)
				if remaining == 0 then
					log(("box %s emerge done s=%.1f"):format(b.name, (core.get_us_time() - t0) / 1e6))
					core.after(0, function()
						if b.name:sub(1, 4) ~= "time" then dump_box(b) end
						nextbox()
					end)
				end
			end)
	end
	nextbox()
end

core.register_globalstep(function(dtime)
	if done or not box then return end
	started = started or core.get_us_time()
	local el = (core.get_us_time() - started) / 1e6
	if not emerging and el > 1 then
		emerging = true
		log("emerge start")
		core.emerge_area({x = box.x0, y = box.y0, z = box.z0}, {x = box.x1, y = box.y1, z = box.z1},
			function(bp, action, remaining)
				if remaining == 0 then emerge_done_at = core.get_us_time() end
			end)
	end
	if emerge_done_at then
		done = true
		log(("emerge done t=%.1f"):format(el))
		analyse()
		r24_dumps()
	elseif el > STOP then
		done = true
		log(("TIMEOUT t=%.1f"):format(el))
		core.request_shutdown("coalprobe timeout", false, 0)
	end
end)
