-- Round 26 Lane W: the protected city (`capital_protection.lua`) on planned
-- layouts, without the engine (LuaJIT).
--
--   luajit tools/r26_capitals/check_protection.lua <repo> <layouts.txt> ...
--
-- <layouts.txt>: render.lua's layout file (the world layout file's capital
-- section). Per capital: the shape builds (it fails when the protected city
-- leaves its reserved square), every wall-band column, every turret disc and
-- every gatehouse box is a member, and the band reaches at least BAND nodes
-- beyond the outermost turret or gatehouse column (sampled). Prints one line
-- per capital and "R26 PROTECTION CHECK PASS", or raises.
local repo = arg[1]
assert(repo and arg[2], "usage: check_protection.lua <repo> <layouts.txt> ...")
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local planner = dofile(dir .. "/capital_planner.lua")
local protection = dofile(dir .. "/capital_protection.lua")
local floor, sqrt, min = math.floor, math.sqrt, math.min
local checks = 0
for i = 2, #arg do
	local f = assert(io.open(arg[i]))
	local all = f:read("*a")
	f:close()
	local section = assert(all:match("section capital %d+ %x+\n(.-)\nsection meta"), "no capital section")
	local texts, order = planner.split(section .. "\n")
	for _, id in ipairs(order) do
		local L = planner.deserialize(texts[id])
		local dims = planner.EDGE[L.kind]
		local shape = protection.build(L)
		local AX, AZ = L.anchor.x, L.anchor.z
		local function member(lx, lz)
			checks = checks + 1
			return shape.member(AX + floor(lx + 0.5), AZ + floor(lz + 0.5))
		end
		local bad = 0
		local W = L.wall
		for k, p in ipairs(W.pts) do
			if not W.gap[k] and not W.lake[k] then
				for dz = -dims.half, dims.half do
					for dx = -dims.half, dims.half do
						if not member(p[1] + dx, p[2] + dz) then bad = bad + 1 end
					end
				end
			end
		end
		local outer = {}
		for _, t in ipairs(W.turrets) do
			local p = W.pts[t]
			for dz = -dims.turret, dims.turret do
				for dx = -dims.turret, dims.turret do
					if dx * dx + dz * dz <= dims.turret * dims.turret + 1 then
						if not member(p[1] + dx, p[2] + dz) then bad = bad + 1 end
					end
				end
			end
			outer[#outer + 1] = {p[1], p[2], dims.turret}
		end
		for c = 1, 4 do
			local g = L.gates[c]
			for dd = -dims.depth, dims.depth do
				for ww = -dims.width, dims.width do
					if not member(g.x + g.dx * dd - g.dz * ww, g.z + g.dz * dd + g.dx * ww) then
						bad = bad + 1
					end
				end
			end
			outer[#outer + 1] = {g.x, g.z, sqrt(dims.depth * dims.depth + dims.width * dims.width)}
		end
		-- the band beyond each turret / gatehouse, outward along the ray
		local thin = math.huge
		for _, o in ipairs(outer) do
			local r = sqrt(o[1] * o[1] + o[2] * o[2])
			local ux, uz = o[1] / r, o[2] / r
			local d = o[3]
			while member(o[1] + ux * (d + 1), o[2] + uz * (d + 1)) and d < 80 do d = d + 1 end
			thin = min(thin, d - o[3])
		end
		print(("%s %-10s %-16s turrets %2d  outside the shape %d  thinnest band beyond a tower/gatehouse %d"):format(
			arg[i]:match("([^/]+/[^/]+)/layouts.txt$") or arg[i], id, L.kind, #W.turrets, bad, thin))
		assert(bad == 0, id .. ": edge columns outside the protected city")
		assert(thin >= protection.BAND - 1, id .. ": protected band thinner than BAND")
	end
end
print(("R26 PROTECTION CHECK PASS checks=%d"):format(checks))
