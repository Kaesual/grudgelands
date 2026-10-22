-- Round 56 lane HOOD portable test (LuaJIT): the hood, the first polygon part
-- of the armor catalog (docs/technical/armor-format.md §1a), in the REAL
-- models, the atlas and the shipped tier selection.
--
--   luajit tools/r56_hood/portable_test.lua [repo]   (VERBOSE=1 lists every check)
--
-- Reads tools/r56_hood/hood.json (the schema file), tools/r54_armor/data/
-- atlas.json, the models grug_visuals_character.b3d and grug_visuals_npc.b3d
-- and tools/r54_art/art/tiers.json. Checks:
--   A  the atlas: the hood's sheet lies whole inside the 128x64 atlas, below
--      every box sheet (the boxes keep rows 0-41), clear of them; each face's
--      rectangle is the sheet's corner plus the schema's rect;
--   M  each model (player, NPC) carries the hood at the end of its armor
--      buffer: one vertex per face corner, in schema order, at the schema
--      point in model units (x flipped, 0.525 per pixel), the face's normal
--      (x flipped) and its atlas UV (sheet corner plus the schema uv); every
--      hood vertex rides Head with weight 1; each face is a fan of
--      (corners - 2) triangles, every one wound along the face's normal
--      (the generator's convention for the boxes);
--   S  the shipped selection: a tier that wears the hood is a cloth or leather
--      tier (ruling 15: metal leaves it transparent) and wears the helm too.
-- Prints "R56 HOOD PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local VERBOSE = os.getenv("VERBOSE")
local function check(ok, label)
	checks = checks + 1
	if VERBOSE and ok then print("ok   " .. label) end
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local json = dofile(ROOT .. "/tools/r28_b4_quests/json.lua")

-- --- a minimal B3D reader (vertices, buffers, bone weights) ------------------------
local function load_model(path)
	local data = read(path)
	local function i32(at)
		local a, b, c, d = data:byte(at, at + 3)
		local v = a + b * 256 + c * 65536 + d * 16777216
		return v >= 2147483648 and v - 4294967296 or v
	end
	local function f32(at)
		local a, b, c, d = data:byte(at, at + 3)
		local sign = d >= 128 and -1 or 1
		local e = (d % 128) * 2 + math.floor(c / 128)
		local m = ((c % 128) * 256 + b) * 256 + a
		if e == 0 then return sign * math.ldexp(m, -149) end
		return sign * math.ldexp(1 + m / 8388608, e - 127)
	end
	local model = {verts = {}, buffers = {}, weights = {}}
	local function parse(at, stop, parent)
		while at < stop do
			local tag, size = data:sub(at, at + 3), i32(at + 4)
			local body, finish = at + 8, at + 8 + size
			if tag == "BB3D" or tag == "MESH" then
				parse(body + 4, finish, parent)
			elseif tag == "NODE" then
				local zero = data:find("\0", body, true)
				parse(zero + 41, finish, data:sub(body, zero - 1))
			elseif tag == "VRTS" then
				for k = body + 12, finish - 1, 32 do
					model.verts[#model.verts + 1] = {
						pos = {f32(k), f32(k + 4), f32(k + 8)},
						normal = {f32(k + 12), f32(k + 16), f32(k + 20)},
						uv = {f32(k + 24), f32(k + 28)}}
				end
			elseif tag == "TRIS" then
				local tris = {}
				for k = body + 4, finish - 1, 12 do
					tris[#tris + 1] = {i32(k), i32(k + 4), i32(k + 8)}
				end
				model.buffers[#model.buffers + 1] = tris
			elseif tag == "BONE" and parent then
				for k = body, finish - 1, 8 do
					local list = model.weights[i32(k)] or {}
					list[#list + 1] = {bone = parent, w = f32(k + 4)}
					model.weights[i32(k)] = list
				end
			end
			at = finish
		end
	end
	parse(1, #data + 1, nil)
	return model
end

local function sub(a, b) return {a[1] - b[1], a[2] - b[2], a[3] - b[3]} end
local function cross(a, b)
	return {a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]}
end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function near(a, b, eps)
	for i = 1, #a do
		if math.abs(a[i] - b[i]) > eps then return false end
	end
	return true
end

local PX = 0.525
local hood = json.decode(read("tools/r56_hood/hood.json"))
local atlas = json.decode(read("tools/r54_armor/data/atlas.json"))
local AW, AH = atlas.size[1], atlas.size[2]

-- Each face's outward normal (Newell), in the catalog frame.
local function newell(face)
	local n = {0, 0, 0}
	for i = 1, #face.v do
		local p, q = hood.vertices[face.v[i] + 1], hood.vertices[face.v[i % #face.v + 1] + 1]
		n[1] = n[1] + (p[2] - q[2]) * (p[3] + q[3])
		n[2] = n[2] + (p[3] - q[3]) * (p[1] + q[1])
		n[3] = n[3] + (p[1] - q[1]) * (p[2] + q[2])
	end
	local l = math.sqrt(dot(n, n))
	return {n[1] / l, n[2] / l, n[3] / l}
end

-- --- A: the atlas ---------------------------------------------------------------------
local part = atlas.parts and atlas.parts.hood
if check(part ~= nil, "A atlas.json has parts.hood") then
	local x, y, w, h = part.rect[1], part.rect[2], part.rect[3], part.rect[4]
	eq(w .. "x" .. h, hood.sheet[1] .. "x" .. hood.sheet[2], "A the hood's atlas rect has the schema's sheet size")
	check(x >= 0 and y >= 0 and x + w <= AW and y + h <= AH, "A the hood's sheet inside the atlas")
	local lowest = 0
	for id, box in pairs(atlas.boxes) do
		local bx, by, bw, bh = box.rect[1], box.rect[2], box.rect[3], box.rect[4]
		lowest = math.max(lowest, by + bh)
		check(not (bx < x + w and x < bx + bw and by < y + h and y < by + bh), "A hood clear of box " .. id)
	end
	eq(lowest, 42, "A the box sheets keep rows 0-41")
	check(y >= lowest, "A the hood below every box sheet")
	for _, face in ipairs(hood.faces) do
		local r = part.faces[face.name]
		check(r and r[1] == x + face.rect[1] and r[2] == y + face.rect[2] and r[3] == face.rect[3]
			and r[4] == face.rect[4], "A " .. face.name .. ": atlas rect = sheet corner + schema rect")
	end
end

-- --- M: the models --------------------------------------------------------------------
local corners = 0
for _, face in ipairs(hood.faces) do corners = corners + #face.v end
for _, case in ipairs({
	{"player", "mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d", 3},
	{"npc", "mods/PLAYER/grug_visuals/models/grug_visuals_npc.b3d", 2},
}) do
	local name, model, armor = case[1], load_model(case[2]), nil
	armor = model.buffers[case[3]]
	-- the armor buffer's vertices, in order: the boxes' (24 each), then the hood's
	local used, list = {}, {}
	for _, tri in ipairs(armor) do
		for _, v in ipairs(tri) do
			if not used[v] then used[v] = true; list[#list + 1] = v end
		end
	end
	table.sort(list)
	eq(#list, 672 + corners, "M " .. name .. ": armor vertices = 28 boxes x 24 + the hood's face corners")
	local first = list[#list - corners + 1]
	local tail = {}
	for _, tri in ipairs(armor) do
		if tri[1] >= first then tail[#tail + 1] = tri end
	end
	local at, ti = first, 1
	for _, face in ipairs(hood.faces) do
		local n = newell(face)
		local mn = {-n[1], n[2], n[3]}
		local ok_pos, ok_uv, ok_n, ok_bone = true, true, true, true
		for k = 1, #face.v do
			local vert = model.verts[at + k]                -- 0-based vertex `at + k - 1`
			local p = hood.vertices[face.v[k] + 1]
			ok_pos = ok_pos and vert and near(vert.pos, {-PX * p[1], PX * p[2], PX * p[3]}, 1e-4)
			ok_uv = ok_uv and vert and near(vert.uv, {(part.rect[1] + face.uv[k][1]) / AW,
				(part.rect[2] + face.uv[k][2]) / AH}, 1e-5)
			ok_n = ok_n and vert and near(vert.normal, mn, 1e-4)
			local w = model.weights[at + k - 1]
			ok_bone = ok_bone and w and #w == 1 and w[1].bone == "Head" and w[1].w == 1
		end
		check(ok_pos, "M " .. name .. " " .. face.name .. ": corners at the schema points (model units)")
		check(ok_uv, "M " .. name .. " " .. face.name .. ": UVs = the sheet's atlas corner + the schema uv")
		check(ok_n, "M " .. name .. " " .. face.name .. ": the face's normal on every corner")
		check(ok_bone, "M " .. name .. " " .. face.name .. ": every corner rides Head with weight 1")
		-- a fan of #v - 2 triangles over these corners, each wound along the normal
		local ok_fan = true
		for _ = 1, #face.v - 2 do
			local tri = tail[ti]
			ti = ti + 1
			if not tri then ok_fan = false; break end
			for _, v in ipairs(tri) do
				if v < at or v >= at + #face.v then ok_fan = false end
			end
			if ok_fan then
				local a, b, c = model.verts[tri[1] + 1].pos, model.verts[tri[2] + 1].pos, model.verts[tri[3] + 1].pos
				ok_fan = dot(cross(sub(b, a), sub(c, a)), mn) > 0
			end
		end
		check(ok_fan, "M " .. name .. " " .. face.name .. ": " .. (#face.v - 2) ..
			" triangles over its corners, wound along its normal")
		at = at + #face.v
	end
	eq(ti - 1, #tail, "M " .. name .. ": no other triangle uses the hood's vertices")
end

-- --- S: the shipped tier selection ---------------------------------------------------------
local tiers = json.decode(read("tools/r54_art/art/tiers.json"))
for _, line in ipairs({"metal", "leather", "cloth"}) do
	for tid, tier in pairs(tiers[line]) do
		local on = {}
		for _, id in ipairs(tier.on) do on[id] = true end
		if on.hood then
			check(line ~= "metal", "S " .. line .. " " .. tid .. ": metal leaves the hood transparent (ruling 15)")
			check(on.helm, "S " .. line .. " " .. tid .. ": the hood worn with the helm (§1a)")
		end
	end
end

if failures > 0 then
	error(("R56 HOOD PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R56 HOOD PORTABLE PASS checks=%d"):format(checks))
