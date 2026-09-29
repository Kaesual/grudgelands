#!/usr/bin/env python3
"""Disposable GAME_PATCH: instrument r7_mapgen's generated callback so every
chunk inside the coalprobe box logs native(v7 VM before writer) > final
(after writer) content-pair counts per depth band below the planned
terrain_y, per column class (static exclusion id + water class)."""
import difflib, os, sys
REPO = sys.argv[1]
name = 'mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua'
OLD = '''	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	if type(result) ~= "string" then fail("writer result differs") end
end)'''
NEW = '''	if not cp_box then
		local b = core.ipc_get("coalprobe:box")
		if type(b) == "table" then cp_box = b end
	end
	local inbox = cp_box and maxp.x >= cp_box.x0 and minp.x <= cp_box.x1 and
		maxp.z >= cp_box.z0 and minp.z <= cp_box.z1 and maxp.y >= cp_box.y0 and
		minp.y <= cp_box.y1
	local d0 = inbox and vmanip:get_data()
	local hm = get_heightmap()
	local hmin, hmax = 1e9, -1e9
	for i = 1, #hm do
		if hm[i] < hmin then hmin = hm[i] end
		if hm[i] > hmax then hmax = hm[i] end
	end
	local t_us, t_cpu = core.get_us_time(), os.clock()
	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	if type(result) ~= "string" then fail("writer result differs") end
	core.log("action", ("[r24t] %d,%d,%d us=%d cpu_us=%d hmin=%d hmax=%d"):format(
		minp.x, minp.y, minp.z, core.get_us_time() - t_us,
		math.floor((os.clock() - t_cpu) * 1e6), hmin, hmax))
	do
		local dd, pp = vmanip:get_data(), vmanip:get_param2_data()
		local a0, a1 = vmanip:get_emerged_area()
		local ax, ay = a1.x - a0.x + 1, a1.y - a0.y + 1
		local h1, h2 = 7, 11
		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				local i = (z - a0.z) * ax * ay + (y - a0.y) * ax + (minp.x - a0.x) + 1
				for x = minp.x, maxp.x do
					local key = cp_rank(dd[i]) * 256 + pp[i]
					h1 = (h1 * 31 + key) % 2147483647
					h2 = (h2 * 37 + key) % 2147483629
					i = i + 1
				end
			end
		end
		core.log("action", ("[r24d] %d,%d,%d %d-%d"):format(minp.x, minp.y, minp.z, h1, h2))
	end
	if inbox then
		local d1 = vmanip:get_data()
		local e0, e1 = vmanip:get_emerged_area()
		local ex, ey = e1.x - e0.x + 1, e1.y - e0.y + 1
		local src = built.planner_source
		local counts = {}
		for z = math.max(minp.z, cp_box.z0), math.min(maxp.z, cp_box.z1) do
			for x = math.max(minp.x, cp_box.x0), math.min(maxp.x, cp_box.x1) do
				local ok, _, eid = pcall(src.static_exclusion_values_at, x, z)
				if not ok then eid = "ERR" end
				local wc, _, _, _, _, ty = src.column_values_at(x, z)
				local cls = tostring(eid or "none") .. "~w" .. tostring(wc)
				local cc = counts[cls]
				if not cc then cc = {} counts[cls] = cc end
				local base = (z - e0.z) * ex * ey + (x - e0.x) + 1
				for y = math.max(minp.y, cp_box.y0), math.min(maxp.y, cp_box.y1) do
					local i = base + (y - e0.y) * ex
					local a, b = d0[i], d1[i]
					if a ~= cp_air or b ~= cp_air then
						local d = ty - y + 1
						local band
						if y < -100 then band = "t2"
						elseif d < 1 then band = "above"
						elseif d <= 4 then band = "01-04"
						elseif d <= 8 then band = "05-08"
						elseif d <= 16 then band = "09-16"
						elseif d <= 32 then band = "17-32"
						elseif d <= 64 then band = "33-64"
						else band = "65+" end
						local pk = a * 65536 + b
						local t = cc[band]
						if not t then t = {} cc[band] = t end
						t[pk] = (t[pk] or 0) + 1
						if y >= -100 and y <= -60 then
							t = cc.deep60_100
							if not t then t = {} cc.deep60_100 = t end
							t[pk] = (t[pk] or 0) + 1
						end
					end
				end
			end
		end
		local parts = {}
		for cls, cc in pairs(counts) do
			for band, t in pairs(cc) do
				for pk, v in pairs(t) do
					parts[#parts + 1] = cls .. "|" .. band .. "|" .. cp_name(math.floor(pk / 65536)) ..
						">" .. cp_name(pk % 65536) .. "=" .. v
				end
			end
		end
		core.log("action", ("[coalg] %d,%d,%d result=%s %s"):format(minp.x, minp.y, minp.z,
			tostring(result), table.concat(parts, ";")))
	end
end)'''
ANCH = 'local function get_heightmap() return core.get_mapgen_object("heightmap") end\n'
ADD = ANCH + '''local cp_box
local cp_air = core.get_content_id("air")
local cp_names = {}
-- content ids ranked by node name, so the digest does not depend on the
-- per-boot id assignment
local cp_ranks = {}
local function cp_rank(cid)
	local r = cp_ranks[cid]
	if not r then
		local name = core.get_name_from_content_id(cid)
		r = 0
		for k = 1, #name do r = (r * 131 + string.byte(name, k)) % 1000003 end
		cp_ranks[cid] = r
	end
	return r
end
local function cp_name(cid)
	local n = cp_names[cid]
	if not n then n = core.get_name_from_content_id(cid) cp_names[cid] = n end
	return n
end
'''
src = open(os.path.join(REPO, name)).read()
assert src.count(OLD) == 1 and src.count(ANCH) == 1
new = src.replace(OLD, NEW).replace(ANCH, ADD)
sys.stdout.write(''.join(difflib.unified_diff(src.splitlines(True), new.splitlines(True), 'a/' + name, 'b/' + name)))
name2 = 'mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua'
src2 = open(os.path.join(REPO, name2)).read()
A2 = 'mapgen_context = mapgen_context, writer_bounds = writer_bounds,'
assert src2.count(A2) == 1
new2 = src2.replace(A2, A2 + ' planner_source = r6_identity.planner_source,')
sys.stdout.write(''.join(difflib.unified_diff(src2.splitlines(True), new2.splitlines(True), 'a/' + name2, 'b/' + name2)))
