--
-- Round 30 Lane P3: the region maps' compact form and their world-folder
-- cache (docs/design/spawn_regions.md "Cache and memory"; the design is the
-- performance review's §3, docs/research/perf-review-2026-10.md).
--
-- Why: building the 38 recipe zones' maps from the analytic world took about
-- 9.5 s of every start, and the built maps kept about 22 MiB of per-cell
-- tables. A map is a function of its recipe, the world and the code, so a
-- later start of the same world reads it back from a file in milliseconds,
-- and the server keeps only the compact form either way.
--
-- THE COMPACT FORM of a built map (spawn_regions_core.build): the zone's cell
-- grid as a byte string of region ids (one byte, two above 255 regions), the
-- regions {kind or camp, belt, centroid, size}, the camps, the leaders and
-- the quest places (Round 36) by region id, the build's problems and warnings. `rehydrate` turns it back
-- into a map against the zone's freshly parsed recipe: the same regions,
-- camps, leaders, places and `region_at` answers as the built map, without its
-- `cells`, `order` and region `cells` (the tools read those from a fresh
-- build, spawn_regions.lua `SR.full_map`).
--
-- THE FILE <worldpath>/grug_region_maps.txt is used only when its key equals
-- this start's: the format, the full world seed, the mapgen tree digest, the
-- mapgen settings and the interpreter (the world-layout cache's key parts,
-- grug_mapgen.wp40.world_key), and a digest of the builder's own files.
-- Each zone block carries the digest of the zone's recipe file, so an edited
-- recipe rebuilds only its zone. The file ends in a SHA-256 over every byte
-- before it, so a truncated, edited or half-written file never decodes.
-- Every failure means a rebuild and an atomic replace, never a stop.
--
-- Plain Lua 5.1, no globals, no engine calls: hashing and file access are
-- injected, so offline tools run this same code.
--   deps.sha256(bytes) -> lowercase hex digest
--   deps.read(path) -> bytes, or nil when there is no such file
--   deps.write(path, bytes) -> true after an atomic replace
--     (core.safe_file_write: temp file, then rename)
--   deps.cell: the cell side in nodes (spawn_regions_core.CELL)
--
return function(deps)
	assert(type(deps) == "table" and type(deps.sha256) == "function" and
		type(deps.read) == "function" and type(deps.write) == "function" and
		type(deps.cell) == "number", "region map cache dependencies differ")
	local sha256, CELL = deps.sha256, deps.cell
	local floor, huge = math.floor, math.huge
	local byte, char, format = string.byte, string.char, string.format
	local M = {FORMAT = "grug_region_maps_v2", FILE = "grug_region_maps.txt"}
	local KEY_NAMES = {"format", "seed", "mapgen", "settings", "interpreter", "builder"}
	-- The eight neighbours in the builder's order (its fringe fallback).
	local N8 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

	local function finite(v)
		return type(v) == "number" and v == v and v > -huge and v < huge
	end

	--
	-- The compact form
	--

	-- The payload of a built map: plain data, no recipe objects.
	function M.compact(map)
		local i0, j0, i1, j1 = huge, huge, -huge, -huge
		for _, c in ipairs(map.order) do
			if c.i < i0 then i0 = c.i end
			if c.i > i1 then i1 = c.i end
			if c.j < j0 then j0 = c.j end
			if c.j > j1 then j1 = c.j end
		end
		local w, h = i1 - i0 + 1, j1 - j0 + 1
		local wide = #map.regions > 255
		local ids = {}
		for n = 1, w * h do ids[n] = 0 end
		for _, c in ipairs(map.order) do
			ids[(c.j - j0) * w + (c.i - i0) + 1] = c.region.id
		end
		local parts = {}
		for n = 1, #ids do
			local id = ids[n]
			parts[n] = wide and char(floor(id / 256), id % 256) or char(id)
		end
		local regions = {}
		for k, r in ipairs(map.regions) do
			assert(r.id == k, "region ids are not their list order")
			regions[k] = {id = r.camp and r.camp.id or r.kind.id, camp = r.camp ~= nil,
				belt = r.belt, x = r.x, z = r.z, size = r.size}
		end
		local camps = {}
		for k, u in ipairs(map.camps) do
			camps[k] = {id = u.id, x = u.x, z = u.z, region = u.region.id, score = u.score,
				slope = u.slope, poi_belt = u.poi_belt and u.poi_belt.index}
		end
		local leaders = {}
		for k, l in ipairs(map.leaders) do
			leaders[k] = {role = l.role, x = l.x, z = l.z, region = l.region.id,
				fallback = l.fallback}
		end
		local places = {}
		for k, p in ipairs(map.places) do
			places[k] = {id = p.id, x = p.x, z = p.z, region = p.region.id, fallback = p.fallback}
		end
		local problems, warnings = {}, {}
		for k, text in ipairs(map.problems) do problems[k] = text end
		for k, text in ipairs(map.warnings) do warnings[k] = text end
		return {i0 = i0, j0 = j0, w = w, h = h, wide = wide, grid = table.concat(parts),
			regions = regions, camps = camps, leaders = leaders, places = places,
			problems = problems, warnings = warnings}
	end

	-- The runtime map of a payload against the zone's parsed recipe, or nil
	-- and the reason when the payload does not fit the recipe (an unknown kind,
	-- camp, leader or place, a region id out of range, a wrong grid length).
	function M.rehydrate(zone_id, p, recipe)
		local i0, j0, w, h, grid = p.i0, p.j0, p.w, p.h, p.grid
		local width = p.wide and 2 or 1
		if type(grid) ~= "string" or #grid ~= w * h * width then
			return nil, "grid length differs"
		end
		local belts = recipe.belts
		local regions, by_kind = {}, {}
		for k, row in ipairs(p.regions) do
			local kind
			if row.camp then kind = recipe.camp_by_id[row.id] else kind = recipe.kind_by_id[row.id] end
			if not kind then
				return nil, "unknown " .. (row.camp and "camp " or "kind ") .. tostring(row.id)
			end
			local belt = belts[row.belt]
			if not belt then return nil, "belt " .. tostring(row.belt) .. " out of range" end
			local levels = belt.levels
			local r = {id = k, kind = kind, belt = row.belt, x = row.x, z = row.z,
				size = row.size, levels = kind.levels,
				level = floor((levels[1] + levels[2]) / 2 + 0.5)}
			regions[k] = r
			local list = by_kind[kind.id]
			if not list then
				list = {}
				by_kind[kind.id] = list
			end
			list[#list + 1] = r
		end
		local camps = {}
		for k, row in ipairs(p.camps) do
			local camp = recipe.camp_by_id[row.id]
			local region = regions[row.region]
			if not camp then return nil, "unknown camp " .. tostring(row.id) end
			if not region or region.kind ~= camp or region.camp then
				return nil, "camp " .. row.id .. " region differs"
			end
			local unit = {id = camp.id, camp = camp, x = row.x, z = row.z, tag = camp.tag,
				rosters = camp.rosters, is_camp = true, belt = camp.belt,
				levels_by_role = camp.levels_by_role, levels = camp.levels,
				score = row.score, slope = row.slope, region = region}
			if camp.site ~= "generate" then unit.site = camp.site end
			if row.poi_belt then
				unit.poi_belt = belts[row.poi_belt]
				if not unit.poi_belt then return nil, "camp " .. row.id .. " POI belt out of range" end
			end
			region.camp = unit
			camps[k] = unit
		end
		for _, r in ipairs(regions) do
			if recipe.camp_by_id[r.kind.id] == r.kind and not r.camp then
				return nil, "camp region " .. r.id .. " has no camp"
			end
		end
		local leader_by_role = {}
		for _, leader in ipairs(recipe.leaders) do leader_by_role[leader.role] = leader end
		local leaders = {}
		for k, row in ipairs(p.leaders) do
			local leader = leader_by_role[row.role]
			local region = regions[row.region]
			if not leader then return nil, "unknown leader " .. tostring(row.role) end
			if not region then return nil, "leader " .. row.role .. " region out of range" end
			leaders[k] = {role = row.role, x = row.x, z = row.z, level = leader.level,
				respawn = leader.respawn, region = region, fallback = row.fallback}
		end
		local places = {}
		for k, row in ipairs(p.places) do
			local place = recipe.place_by_id[row.id]
			local region = regions[row.region]
			if not place then return nil, "unknown place " .. tostring(row.id) end
			if not region then return nil, "place " .. row.id .. " region out of range" end
			places[k] = {id = row.id, name = place.name, x = row.x, z = row.z, region = region,
				fallback = row.fallback}
		end

		-- The grid: every id in range; the zone frame (spawn_regions_core
		-- zone_frame: centroid and bounding box of the land cell centres).
		local n_regions = #regions
		local function id_at(i, j)
			i, j = i - i0, j - j0
			if i < 0 or j < 0 or i >= w or j >= h then return 0 end
			local at = (j * w + i) * width + 1
			if width == 1 then return byte(grid, at) end
			local hi, lo = byte(grid, at, at + 1)
			return hi * 256 + lo
		end
		local sx, sz, n, x0, z0, x1, z1 = 0, 0, 0, huge, huge, -huge, -huge
		for j = j0, j0 + h - 1 do
			for i = i0, i0 + w - 1 do
				local id = id_at(i, j)
				if id > n_regions then return nil, "region id " .. id .. " out of range" end
				if id > 0 then
					local cx, cz = i * CELL + CELL / 2, j * CELL + CELL / 2
					sx, sz, n = sx + cx, sz + cz, n + 1
					x0, x1 = math.min(x0, cx), math.max(x1, cx)
					z0, z1 = math.min(z0, cz), math.max(z1, cz)
				end
			end
		end
		if n == 0 then return nil, "no land cell" end

		local map = {zone = zone_id, recipe = recipe, compact = true, cell_count = n,
			problems = p.problems, warnings = p.warnings, regions = regions,
			by_kind = by_kind, camps = camps, leaders = leaders, places = places,
			frame = {x = sx / n, z = sz / n,
				hx = math.max(CELL, (x1 - x0) / 2 + CELL / 2),
				hz = math.max(CELL, (z1 - z0) / 2 + CELL / 2)}}
		-- The region at a point: its cell's, else the nearest zone land cell
		-- among the eight around it (exactly the builder's region_at).
		function map.region_at(x, z)
			local i, j = floor(x / CELL), floor(z / CELL)
			local id = id_at(i, j)
			if id > 0 then return regions[id] end
			local best, bd
			for k = 1, 8 do
				local ni, nj = i + N8[k][1], j + N8[k][2]
				local nid = id_at(ni, nj)
				if nid > 0 then
					local dx, dz = ni * CELL + CELL / 2 - x, nj * CELL + CELL / 2 - z
					local d = dx * dx + dz * dz
					if not bd or d < bd then best, bd = nid, d end
				end
			end
			return best and regions[best] or nil
		end
		return map
	end

	--
	-- The file
	--

	-- The key as ordered {name, value} pairs; values are single-line text.
	function M.key(seed, mapgen, settings, interpreter, builder)
		local values = {M.FORMAT, seed, mapgen, settings, interpreter, builder}
		local parts = {}
		for index, name in ipairs(KEY_NAMES) do
			local value = values[index]
			if type(value) ~= "string" or value == "" or value:find("[\r\n]") then
				error("region map cache: key part " .. name .. " differs", 0)
			end
			parts[index] = {name, value}
		end
		return parts
	end

	-- One digest over named files: rows {{name, bytes}} in a fixed order.
	function M.files_digest(rows)
		local lines = {}
		for index, row in ipairs(rows) do
			lines[index] = row[1] .. " " .. sha256(row[2])
		end
		return sha256(table.concat(lines, "\n"))
	end

	local function num(v)
		if not finite(v) then error("region map cache: a number is not finite", 0) end
		return format("%.17g", v)
	end
	local function opt(v)
		return v == nil and "-" or num(v)
	end
	local function token(v)
		if type(v) ~= "string" or v == "" or v:find("%s") then
			error("region map cache: a name differs: " .. tostring(v), 0)
		end
		return v
	end
	local function text(v)
		if type(v) ~= "string" or v:find("[\r\n]") then
			error("region map cache: a log line spans lines", 0)
		end
		return v
	end

	-- One zone's block body: a count line, the rows, then the grid bytes.
	local function encode_body(p)
		local out = {format("grid %d %d %d %d %d %d %d %d %d %d %d\n", p.i0, p.j0, p.w, p.h,
			p.wide and 2 or 1, #p.regions, #p.camps, #p.leaders, #p.places, #p.problems,
			#p.warnings)}
		for _, r in ipairs(p.regions) do
			out[#out + 1] = format("r %s %d %d %s %s %d\n", token(r.id), r.camp and 1 or 0,
				r.belt, num(r.x), num(r.z), r.size)
		end
		for _, c in ipairs(p.camps) do
			out[#out + 1] = format("c %s %s %s %d %s %s %s\n", token(c.id), num(c.x), num(c.z),
				c.region, opt(c.score), opt(c.slope), opt(c.poi_belt))
		end
		for _, l in ipairs(p.leaders) do
			out[#out + 1] = format("l %s %s %s %d %s\n", token(l.role), num(l.x), num(l.z),
				l.region, l.fallback == nil and "-" or token(l.fallback))
		end
		for _, s in ipairs(p.places) do
			out[#out + 1] = format("s %s %s %s %d %s\n", token(s.id), num(s.x), num(s.z),
				s.region, s.fallback == nil and "-" or token(s.fallback))
		end
		for _, t in ipairs(p.problems) do out[#out + 1] = "p " .. text(t) .. "\n" end
		for _, t in ipairs(p.warnings) do out[#out + 1] = "w " .. text(t) .. "\n" end
		out[#out + 1] = p.grid
		return table.concat(out)
	end

	-- The file bytes: header, key lines, one length-framed block per zone in
	-- the given order ({zone, digest, payload}), and a trailer hash over
	-- everything before it. Deterministic for the same inputs.
	function M.encode(parts, entries)
		local out = {M.FORMAT .. "\n"}
		for _, part in ipairs(parts) do
			if part[1] ~= "format" then out[#out + 1] = part[1] .. "=" .. part[2] .. "\n" end
		end
		for _, e in ipairs(entries) do
			local body = encode_body(e.payload)
			out[#out + 1] = format("zone %s %s %d\n", token(e.zone), token(e.digest), #body)
			out[#out + 1] = body
			out[#out + 1] = "\n"
		end
		local head = table.concat(out)
		return head .. "end " .. sha256(head) .. "\n"
	end

	local function parse_num(s)
		local v = tonumber(s)
		return finite(v) and v or nil
	end
	local function parse_opt(s)
		if s == "-" then return true, nil end
		local v = parse_num(s)
		return v ~= nil, v
	end
	local function is_int(v)
		return v ~= nil and v == floor(v)
	end

	-- A zone block body back into a payload, or nil and the reason.
	local function decode_body(body)
		local pos = 1
		local function line()
			local stop = body:find("\n", pos, true)
			if not stop then return nil end
			local t = body:sub(pos, stop - 1)
			pos = stop + 1
			return t
		end
		local head = line()
		local i0, j0, w, h, width, nr, nc, nl, ns, np, nw = (head or ""):match(
			"^grid (%-?%d+) (%-?%d+) (%d+) (%d+) ([12]) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
		if not i0 then return nil, "grid line differs" end
		local p = {i0 = tonumber(i0), j0 = tonumber(j0), w = tonumber(w), h = tonumber(h),
			wide = width == "2", regions = {}, camps = {}, leaders = {}, places = {},
			problems = {}, warnings = {}}
		for k = 1, tonumber(nr) do
			local id, camp, belt, x, z, size = (line() or ""):match(
				"^r (%S+) ([01]) (%d+) (%S+) (%S+) (%d+)$")
			x, z = parse_num(x), parse_num(z)
			if not (id and x and z) then return nil, "region row " .. k .. " differs" end
			p.regions[k] = {id = id, camp = camp == "1", belt = tonumber(belt), x = x, z = z,
				size = tonumber(size)}
		end
		for k = 1, tonumber(nc) do
			local id, x, z, region, score, slope, poi_belt = (line() or ""):match(
				"^c (%S+) (%S+) (%S+) (%d+) (%S+) (%S+) (%S+)$")
			x, z = parse_num(x), parse_num(z)
			local ok1, sc = parse_opt(score or "")
			local ok2, sl = parse_opt(slope or "")
			local ok3, pb = parse_opt(poi_belt or "")
			if not (id and x and z and ok1 and ok2 and ok3) or (pb and not is_int(pb)) then
				return nil, "camp row " .. k .. " differs"
			end
			p.camps[k] = {id = id, x = x, z = z, region = tonumber(region), score = sc,
				slope = sl, poi_belt = pb}
		end
		for k = 1, tonumber(nl) do
			local role, x, z, region, fallback = (line() or ""):match(
				"^l (%S+) (%S+) (%S+) (%d+) (%S+)$")
			x, z = parse_num(x), parse_num(z)
			if not (role and x and z) then return nil, "leader row " .. k .. " differs" end
			p.leaders[k] = {role = role, x = x, z = z, region = tonumber(region),
				fallback = fallback ~= "-" and fallback or nil}
		end
		for k = 1, tonumber(ns) do
			local id, x, z, region, fallback = (line() or ""):match(
				"^s (%S+) (%S+) (%S+) (%d+) (%S+)$")
			x, z = parse_num(x), parse_num(z)
			if not (id and x and z) then return nil, "place row " .. k .. " differs" end
			p.places[k] = {id = id, x = x, z = z, region = tonumber(region),
				fallback = fallback ~= "-" and fallback or nil}
		end
		for k = 1, tonumber(np) do
			local t = (line() or ""):match("^p (.*)$")
			if not t then return nil, "problem line " .. k .. " differs" end
			p.problems[k] = t
		end
		for k = 1, tonumber(nw) do
			local t = (line() or ""):match("^w (.*)$")
			if not t then return nil, "warning line " .. k .. " differs" end
			p.warnings[k] = t
		end
		p.grid = body:sub(pos)
		if #p.grid ~= p.w * p.h * (p.wide and 2 or 1) then return nil, "grid length differs" end
		return p
	end

	-- `bytes` against the current key parts. Returns {zone_id -> {digest,
	-- payload}} on a match; otherwise nil, the reason and whether the file is
	-- damaged (a warning) rather than merely built for another key or format.
	-- Never raises.
	function M.decode(bytes, parts)
		if type(bytes) ~= "string" or bytes == "" then return nil, "empty cache file", true end
		local pos = 1
		local limit = #bytes
		local function line()
			local stop = bytes:find("\n", pos, true)
			if not stop or stop > limit then return nil end
			local t = bytes:sub(pos, stop - 1)
			pos = stop + 1
			return t
		end
		local header = line()
		if header == nil then return nil, "truncated header", true end
		if header ~= M.FORMAT then
			if header:match("^grug_region_maps_") then
				return nil, "format differs (" .. header .. ")", false
			end
			return nil, "not a region map cache file", true
		end
		-- The trailer: "end <sha256 of everything before>\n".
		local tail_start = bytes:find("end %x+\n$")
		if not tail_start or bytes:sub(tail_start - 1, tail_start - 1) ~= "\n" or
				bytes:sub(tail_start + 4, -2) ~= sha256(bytes:sub(1, tail_start - 1)) then
			return nil, "file hash differs or trailer missing", true
		end
		limit = tail_start - 1
		for _, part in ipairs(parts) do
			if part[1] ~= "format" then
				local t = line()
				if t == nil then return nil, "truncated key", true end
				local name, value = t:match("^([%a_]+)=(.*)$")
				if name ~= part[1] then return nil, "key line differs (" .. t .. ")", true end
				if value ~= part[2] then return nil, name .. " differs", false end
			end
		end
		local out = {}
		while pos <= limit do
			local t = line()
			local zone, digest, len = (t or ""):match("^zone (%S+) (%x+) (%d+)$")
			if not zone then return nil, "zone header differs", true end
			len = tonumber(len)
			if out[zone] then return nil, "zone " .. zone .. " twice", true end
			if pos + len > limit or bytes:sub(pos + len, pos + len) ~= "\n" then
				return nil, "zone " .. zone .. " truncated", true
			end
			local payload, why = decode_body(bytes:sub(pos, pos + len - 1))
			if not payload then return nil, "zone " .. zone .. ": " .. why, true end
			out[zone] = {digest = digest, payload = payload}
			pos = pos + len + 1
		end
		return out
	end

	function M.path(world_dir)
		return world_dir .. "/" .. M.FILE
	end

	-- Read and decode the world's cache file (see `decode` for the returns).
	-- A fourth return value is the file's byte count.
	function M.load(world_dir, parts)
		local bytes = deps.read(M.path(world_dir))
		if not bytes then return nil, "no cache file", false, 0 end
		local out, reason, damaged = M.decode(bytes, parts)
		return out, reason, damaged, #bytes
	end

	-- Encode and atomically replace the world's cache file. Returns success
	-- and the byte count.
	function M.store(world_dir, parts, entries)
		local bytes = M.encode(parts, entries)
		return deps.write(M.path(world_dir), bytes) == true, #bytes
	end

	return M
end
