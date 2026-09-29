-- Round 26 Lane W (playtest fix): wall-gatehouse gaps, portably (LuaJIT).
--
--   luajit tools/r26_capitals/gate_gaps.lua <repo> --layouts FILE ...
--   luajit tools/r26_capitals/gate_gaps.lua <repo> <out.tsv> seed [seed ...]
--
-- Builds every capital's city edge with the SHIPPED writer of <repo>
-- (`r7_capital_blueprint.source` -> `wp13/city_edge.lua`) on synthetic dry
-- ground (the nearest wall point's walk less the walk height; the gatehouse
-- box at its floor; no roads) and walks the wall's centre line round each
-- gate: every column on it within GATE_REACH of the gate that lies outside
-- the gatehouse box (and off the civic lake's open stretch and its ends) must carry an edge
-- cell. A column that carries none is a gap between the wall and the
-- gatehouse. With --layouts it reads render.lua's layout files; otherwise it
-- plans each seed (tools/r26_capitals/world.lua, the planner of <repo>) and
-- writes one TSV line per seed:
--   seed  total_gap_columns  capitals_with_gaps  key[gates=a,b;cols=N] ...
-- Prints a summary and never fails: it measures.
local repo = arg[1]
assert(repo and arg[2], "usage: gate_gaps.lua <repo> (--layouts FILE ... | <out.tsv> seed ...)")
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local planner = dofile(wp40 .. "/capital_planner.lua")
local blueprint = dofile(wp40 .. "/r7_capital_blueprint.lua")
local floor, sqrt, abs, max = math.floor, math.sqrt, math.abs, math.max
local KEY = {anchor_007 = "dur_brannoc", anchor_008 = "highcourt", anchor_009 = "lethariel",
	anchor_010 = "nhal_veyr", anchor_011 = "gor_drazhak", anchor_012 = "kezamba"}
local GATE_REACH = 14   -- beyond the gatehouse's larger half extent

local function check_layout(text)
	local L = planner.deserialize(text)
	local key = KEY[L.anchor.id]
	local cfg = blueprint.CAPITALS[key]
	local dims = planner.EDGE[cfg.edge]
	local source = blueprint.source(key, L, text)
	local AX, AZ = L.anchor.x, L.anchor.z
	local edge = source.overlay.make({x = AX, z = AZ})
	local W = L.wall
	local n = #W.pts
	local height = dims.opts.WALL_HEIGHT
	local function column(x, z)
		local lx, lz = x - AX, z - AZ
		for c = 1, 4 do
			local g = L.gates[c]
			local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
			local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
			if abs(dd) <= dims.depth + 1 and abs(ww) <= dims.width + 1 then
				return g.y, nil, false
			end
		end
		local best, bi
		for i = 1, n do
			local dx, dz = lx - W.pts[i][1], lz - W.pts[i][2]
			local d = dx * dx + dz * dz
			if not best or d < best then best, bi = d, i end
		end
		return floor(W.walk[bi] / 2) - height, nil, false
	end
	local out = {key = key, gates = {}, cols = 0}
	local R = max(dims.depth, dims.width) + GATE_REACH
	for c = 1, 4 do
		local g = L.gates[c]
		local cells = edge.cells({min_x = floor(AX + g.x - R - 4), max_x = floor(AX + g.x + R + 4),
			min_z = floor(AZ + g.z - R - 4), max_z = floor(AZ + g.z + R + 4)}, column)
		local present = {}
		for _, cell in ipairs(cells) do
			if cell.name ~= "air" then present[(cell.x - AX) .. ":" .. (cell.z - AZ)] = true end
		end
		local missing, seen = 0, {}
		for i = 1, n do
			local j = i % n + 1
			if not (W.lake[i] or W.lake[j]) then
				local a, b = W.pts[i], W.pts[j]
				local ux, uz = b[1] - a[1], b[2] - a[2]
				local len = sqrt(ux * ux + uz * uz)
				local steps = max(1, floor(len / 0.25))
				for s = 0, steps do
					local t = s / steps
					local x, z = a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2])
					local rx, rz = x - g.x, z - g.z
					if rx * rx + rz * rz <= R * R then
						local dd = rx * g.dx + rz * g.dz
						local ww = -rx * g.dz + rz * g.dx
						if not (abs(dd) <= dims.depth + 0.5 and abs(ww) <= dims.width + 0.5) then
							local k = floor(x + 0.5) .. ":" .. floor(z + 0.5)
							if not seen[k] then
								seen[k] = true
								if not present[k] then missing = missing + 1 end
							end
						end
					end
				end
			end
		end
		if missing > 0 then
			out.gates[#out.gates + 1] = g.name
			out.cols = out.cols + missing
		end
	end
	return out
end

local function check_text(all)
	local section = all:match("section capital %d+ %x+\n(.-)\nsection ") or all
	local texts, order = planner.split(section .. "\n")
	local res = {}
	for _, id in ipairs(order) do res[#res + 1] = check_layout(texts[id]) end
	return res
end

local function line(tag, res)
	local total, caps, parts = 0, 0, {}
	for _, r in ipairs(res) do
		total = total + r.cols
		if r.cols > 0 then caps = caps + 1 end
		parts[#parts + 1] = ("%s[gates=%s;cols=%d]"):format(r.key, table.concat(r.gates, ","), r.cols)
	end
	return table.concat({tag, total, caps, table.concat(parts, " ")}, "\t"), total, caps
end

if arg[2] == "--layouts" then
	for i = 3, #arg do
		local f = assert(io.open(arg[i]))
		local text = f:read("*a")
		f:close()
		print((line(arg[i], check_text(text))))
	end
else
	local W = dofile(here .. "/world.lua")(repo)
	local out = assert(io.open(arg[2], "a"))
	for i = 3, #arg do
		local ok, run = pcall(W.plan, arg[i])
		local l
		if ok then
			l = line(arg[i], check_text(run.text))
		else
			l = arg[i] .. "\tERROR\t" .. tostring(run):gsub("[\t\n]", " ")
		end
		out:write(l, "\n")
		out:flush()
		io.stderr:write(l, "\n")
	end
	out:close()
end
