-- Round 54 lane MODEL portable test (LuaJIT): the armor in the character
-- models (round54-plan.md §4 MODEL, docs/technical/armor-format.md).
--
--   luajit tools/r54_model/portable_test.lua [repo]   (VERBOSE=1 lists every check)
--
-- Reads the REAL models grug_visuals_character.b3d (player) and
-- grug_visuals_npc.b3d (armored NPCs) and the REAL wield_geometry.lua.
-- Checks:
--   B  the bones: Head, the arms, the legs, Panel_Front and Panel_Back hang
--      under Body; the player model has the Cloak under Body, the NPC model
--      none; every vertex rides exactly one bone with weight 1;
--   U  the buffers in the texture order: player skin, cloak, armor, weapon;
--      NPC skin, armor, weapon (the first buffers: Round 55's offhand, back
--      and wings follow, tools/r55_model); the frame counts (player 0-484,
--      NPC 0-220);
--      every armor UV inside the 128x64 atlas;
--   S  the swing sign in every frame of every played clip (player_api's
--      stand, sit, lay, walk, mine, walk_mine and the pose clips): a swung
--      front panel moves its hem forward, a swung back panel and the cloak
--      move theirs backward, in the body's own frame; the cloak never
--      swings less than the back panel; walking swings the panels;
--   W  the weapon card: its eight corners are the 16x16 sprite square of
--      grug_visuals.wield_transform(1, "tool") on Arm_Right (the world wield
--      entity at stature 1), image u along the entity's +x and v along -y,
--      a hair off the plane on each side, the same in both models.
-- Prints "R54 MODEL PORTABLE PASS checks=<n>" or the failures.

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

-- --- a minimal B3D reader ------------------------------------------------------
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end

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
	local model = {nodes = {}, verts = {}, buffers = {}, weights = {}}
	local function parse(at, stop, parent)
		while at < stop do
			local tag, size = data:sub(at, at + 3), i32(at + 4)
			local body, finish = at + 8, at + 8 + size
			if tag == "BB3D" or tag == "MESH" then
				parse(body + 4, finish, parent)
			elseif tag == "NODE" then
				local zero = data:find("\0", body, true)
				local node = {name = data:sub(body, zero - 1), parent = parent, keys = {}}
				local v = zero + 1
				node.pos = {f32(v), f32(v + 4), f32(v + 8)}
				-- file order w, x, y, z; Irrlicht quaternions are (X, Y, Z, W)
				node.rot = {f32(v + 28), f32(v + 32), f32(v + 36), f32(v + 24)}
				model.nodes[node.name] = node
				parse(v + 40, finish, node)
			elseif tag == "VRTS" then
				assert(i32(body) == 1 and i32(body + 4) == 1 and i32(body + 8) == 2,
					"normals and one UV set")
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
					local w = f32(k + 4)
					if w > 0 then
						local list = model.weights[i32(k)] or {}
						list[#list + 1] = {bone = parent.name, w = w}
						model.weights[i32(k)] = list
					end
				end
			elseif tag == "KEYS" and parent then
				assert(i32(body) == 7, "keys with position, scale and rotation")
				for k = body + 4, finish - 1, 44 do
					parent.keys[i32(k)] = {pos = {f32(k + 4), f32(k + 8), f32(k + 12)},
						rot = {f32(k + 32), f32(k + 36), f32(k + 40), f32(k + 28)}}
				end
			end
			at = finish
		end
	end
	parse(1, #data + 1, nil)
	return model
end

-- Irrlicht's quaternion rotation (getMatrix_transposed, applied the way
-- transformVect applies it), as tools/r40_an2/portable_test.lua uses it.
local function rotate(q, v)
	local n = math.sqrt(q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4])
	local X, Y, Z, W = q[1] / n, q[2] / n, q[3] / n, q[4] / n
	local m = {[0] = 1 - 2 * Y * Y - 2 * Z * Z, 2 * X * Y - 2 * Z * W, 2 * X * Z + 2 * Y * W, 0,
		2 * X * Y + 2 * Z * W, 1 - 2 * X * X - 2 * Z * Z, 2 * Z * Y - 2 * X * W, 0,
		2 * X * Z - 2 * Y * W, 2 * Z * Y + 2 * X * W, 1 - 2 * X * X - 2 * Y * Y}
	return {m[0] * v[1] + m[4] * v[2] + m[8] * v[3],
		m[1] * v[1] + m[5] * v[2] + m[9] * v[3],
		m[2] * v[1] + m[6] * v[2] + m[10] * v[3]}
end
local function unrotate(q, v) return rotate({-q[1], -q[2], -q[3], q[4]}, v) end
local function sub(a, b) return {a[1] - b[1], a[2] - b[2], a[3] - b[3]} end
local function add(a, b) return {a[1] + b[1], a[2] + b[2], a[3] + b[3]} end
local function dist(a, b)
	local d = sub(a, b)
	return math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
end

-- The played ranges in engine frames (file frame = engine frame + 1).
local BASE_PLAYED = {{0, 79}, {81, 160}, {162, 166}, {168, 187}, {189, 198}, {200, 219}}
local WALK = {168, 187}

local player = load_model("mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d")
local npc = load_model("mods/PLAYER/grug_visuals/models/grug_visuals_npc.b3d")

-- --- B and U --------------------------------------------------------------------
-- Triangles per buffer of the first `n` buffers (Round 55 appends three).
local function count_tris(model, n)
	local out = {}
	for i = 1, math.min(n, #model.buffers) do out[i] = #model.buffers[i] end
	return table.concat(out, ",")
end
-- Vertices the first `n` buffers use.
local function count_verts(model, n)
	local seen, count = {}, 0
	for i = 1, math.min(n, #model.buffers) do
		for _, tri in ipairs(model.buffers[i]) do
			for _, v in ipairs(tri) do
				if not seen[v] then seen[v], count = true, count + 1 end
			end
		end
	end
	return count
end
local function frames(model)
	local n = 0
	for _ in pairs(model.nodes.Body.keys) do n = n + 1 end
	return n
end
-- Round 56 (lane HOOD): the armor buffer gains the hood, 8 faces = 32 vertices, 16 triangles.
for _, case in ipairs({
	{"player", player, "84,12,352,4", 485, true},
	{"npc", npc, "84,352,4", 221, false},
}) do
	local name, model, tris, frame_count, cloak = case[1], case[2], case[3], case[4], case[5]
	local body = model.nodes.Body
	for _, bone in ipairs({"Head", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right",
			"Panel_Front", "Panel_Back"}) do
		check(model.nodes[bone] and model.nodes[bone].parent == body,
			"B " .. name .. ": " .. bone .. " hangs under Body")
	end
	if cloak then
		check(model.nodes.Cloak and model.nodes.Cloak.parent == body, "B player: Cloak under Body")
	else
		check(model.nodes.Cloak == nil, "B npc: no Cloak bone")
	end
	local loose = 0
	for i = 0, #model.verts - 1 do
		local list = model.weights[i]
		if not (list and #list == 1 and list[1].w == 1) then loose = loose + 1 end
	end
	eq(loose, 0, "B " .. name .. ": vertices not on exactly one bone with weight 1")
	eq(count_tris(model, cloak and 4 or 3), tris, "U " .. name .. ": triangles per buffer in texture order")
	eq(frames(model), frame_count, "U " .. name .. ": keyed frames")
	-- the armor buffer: its vertices' UVs inside the atlas
	local outside, armor_tris = 0, model.buffers[cloak and 3 or 2]
	for _, tri in ipairs(armor_tris) do
		for _, v in ipairs(tri) do
			local uv = model.verts[v + 1].uv
			if uv[1] < 0 or uv[1] > 1 or uv[2] < 0 or uv[2] > 1 then outside = outside + 1 end
		end
	end
	eq(outside, 0, "U " .. name .. ": armor UVs outside the atlas")
end
-- Round 55 appends the offhand, back and wings buffers: these count the
-- first four (player) and three (NPC) buffers' vertices only.
eq(count_verts(player, 4), 904, "U player vertices: 168 body, 24 cloak, 704 armor (672 boxes, 32 hood), 8 card")
eq(count_verts(npc, 3), 880, "U npc vertices: 168 body, 704 armor (672 boxes, 32 hood), 8 card")

-- --- S: the swing sign ------------------------------------------------------------
-- A swing bone's hem: the mean of its lowest vertices at bind (model space).
local function hem_of(model, bone)
	local low, pts = math.huge, {}
	for i = 0, #model.verts - 1 do
		local list = model.weights[i]
		if list and list[1].bone == bone then
			local p = model.verts[i + 1].pos
			if p[2] < low - 1e-6 then low, pts = p[2], {p}
			elseif math.abs(p[2] - low) <= 1e-6 then pts[#pts + 1] = p end
		end
	end
	local sum = {0, 0, 0}
	for _, p in ipairs(pts) do sum = add(sum, p) end
	return {sum[1] / #pts, sum[2] / #pts, sum[3] / #pts}
end
-- The angle a swing bone's key turns it about its own x, in degrees.
local function key_angle(node, file_frame)
	local q = node.keys[file_frame].rot
	return math.deg(2 * math.atan2(q[1], q[4]))
end
-- Where the hem moves at a frame, in the body's rest frame (model axes):
-- the bone's key turns the hem about its hinge; Body's own motion is left
-- out, so a leaning torso does not count as a swing.
local function hem_move(model, bone, hem, file_frame)
	local body, node = model.nodes.Body, model.nodes[bone]
	local local_hem = unrotate(body.rot, sub(hem, body.pos))
	local key = node.keys[file_frame]
	local from_pivot = unrotate(node.rot, sub(local_hem, node.pos))
	local moved = add(key.pos, rotate(key.rot, from_pivot))
	return rotate(body.rot, sub(moved, local_hem))
end

local function played_frames(model, with_poses)
	local list = {}
	for _, r in ipairs(BASE_PLAYED) do
		for f = r[1], r[2] do list[#list + 1] = f end
	end
	if with_poses then
		for f = 221, 484 do list[#list + 1] = f end
	end
	return list
end

for _, case in ipairs({{"player", player, true}, {"npc", npc, false}}) do
	local name, model, poses = case[1], case[2], case[3]
	local movers = {{"Panel_Front", 1, -1}, {"Panel_Back", -1, 1}}
	if poses then movers[#movers + 1] = {"Cloak", -1, 1} end
	for _, mover in ipairs(movers) do
		local bone, away, sign = mover[1], mover[2], mover[3]
		local hem = hem_of(model, bone)
		local wrong, still, peak = {}, 0, 0
		for _, frame in ipairs(played_frames(model, poses)) do
			local angle = sign * key_angle(model.nodes[bone], frame + 1)
			local move = hem_move(model, bone, hem, frame + 1)
			if angle < 0 or (angle > 1 and move[3] * away <= 0) then
				wrong[#wrong + 1] = frame
			end
			if angle <= 1 then still = still + 1 end
			if frame >= WALK[1] and frame <= WALK[2] then peak = math.max(peak, angle) end
		end
		check(#wrong == 0, "S " .. name .. ": " .. bone .. " swings its hem "
			.. (away > 0 and "forward" or "backward") .. " in every played frame"
			.. (#wrong > 0 and (" (wrong at " .. table.concat(wrong, ", ", 1, math.min(#wrong, 10)) .. ")") or ""))
		check(peak > 40, "S " .. name .. ": " .. bone .. " swings out walking (peak "
			.. string.format("%.1f", peak) .. " deg)")
	end
	if poses then
		local below = {}
		for _, frame in ipairs(played_frames(model, true)) do
			if key_angle(model.nodes.Cloak, frame + 1) < key_angle(model.nodes.Panel_Back, frame + 1) - 1e-3 then
				below[#below + 1] = frame
			end
		end
		check(#below == 0, "S player: the cloak never swings less than the back panel"
			.. (#below > 0 and (" (below at " .. table.concat(below, ", ", 1, math.min(#below, 10)) .. ")") or ""))
	end
end

-- --- W: the weapon card -------------------------------------------------------------
grug_visuals = {}
dofile(ROOT .. "/mods/PLAYER/grug_visuals/wield_geometry.lua")
local wt = grug_visuals.wield_transform(1, "tool")
-- set_attach's rotation: Rz(z) * Ry(y) * Rx(x), right-handed about the bone's
-- axes (wield_geometry.lua section 7).
local function euler(v)
	local x, y, z = math.rad(wt.rot.x), math.rad(wt.rot.y), math.rad(wt.rot.z)
	-- Rx
	v = {v[1], v[2] * math.cos(x) - v[3] * math.sin(x), v[2] * math.sin(x) + v[3] * math.cos(x)}
	-- Ry
	v = {v[1] * math.cos(y) + v[3] * math.sin(y), v[2], -v[1] * math.sin(y) + v[3] * math.cos(y)}
	-- Rz
	return {v[1] * math.cos(z) - v[2] * math.sin(z), v[1] * math.sin(z) + v[2] * math.cos(z), v[3]}
end
local edge = wt.sprite_edge
for _, case in ipairs({{"player", player, 4}, {"npc", npc, 3}}) do
	local name, model, index = case[1], case[2], case[3]
	local body, arm = model.nodes.Body, model.nodes.Arm_Right
	local card = model.buffers[index]
	local seen, worst = {}, 0
	for _, tri in ipairs(card) do
		for _, v in ipairs(tri) do seen[v] = true end
	end
	local n = 0
	for v in pairs(seen) do
		n = n + 1
		local vert = model.verts[v + 1]
		local u, w = vert.uv[1], vert.uv[2]
		local entity = {(u - 0.5) * edge, (0.5 - w) * edge, 0}
		local bone_local = add({wt.pos.x, wt.pos.y, wt.pos.z}, euler(entity))
		local expected = add(body.pos, rotate(body.rot, add(arm.pos, rotate(arm.rot, bone_local))))
		worst = math.max(worst, dist(vert.pos, expected))
		local list = model.weights[v]
		check(list and list[1].bone == "Arm_Right", "W " .. name .. ": card vertex " .. v .. " rides Arm_Right")
	end
	eq(n, 8, "W " .. name .. ": the card has eight corners")
	check(worst < 0.02, "W " .. name .. ": card corners at the wield entity's sprite square (off by "
		.. string.format("%.4f", worst) .. ")")
end

if failures > 0 then
	error(("R54 MODEL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R54 MODEL PORTABLE PASS checks=%d"):format(checks))
