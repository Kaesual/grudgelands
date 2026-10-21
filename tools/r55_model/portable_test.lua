-- Round 55 lane MODEL portable test (LuaJIT): the offhand parts in the
-- character models (round55-plan.md §4 MODEL, docs/technical/offhand-format.md).
--
--   luajit tools/r55_model/portable_test.lua [repo]   (VERBOSE=1 lists every check)
--
-- Reads the REAL models grug_visuals_character.b3d (player) and
-- grug_visuals_npc.b3d (armored NPCs), both written by
-- tools/r33_c3/gen_cloak_model.py from tools/r55_offhand/params.json, and
-- the REAL pose clip table of grug_visuals/apply.lua. Checks:
--   B  the bones: Offhand_Shield and Offhand_Book hang under Arm_Left in
--      both models, bound at their pivot with no turn;
--   U  the buffers in the contract's texture order: player skin, cloak,
--      armor, weapon, offhand, back, wings; NPC skin, armor, weapon,
--      offhand, back. The offhand buffer (three shield copies of 28
--      triangles plus the optional 4-triangle boss, the book's 62) rides
--      only the two offhand bones, each with vertices, its UVs inside the
--      atlas; the back card is 8 vertices and 4 triangles on Body (the
--      player's may ride the Cloak), UV 0..1 over the whole image; the
--      player's wings are 2 x 6 triangles on the Cloak;
--   K  a key in every frame of both offhand bones (player 0-484, NPC
--      0-220, as many as Body's), the identity on the single frames
--      between player_api's ranges;
--   S  the Block key's sign: in the first frame of the block clip (and of
--      block_walk) the shield's up turns forward, so the raised arm stands
--      the shield upright in front of the chest; at stand frame 0 the
--      shield bone holds the arm's turn.
-- Prints "R55 MODEL PORTABLE PASS checks=<n>" or the failures.

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

-- --- a minimal B3D reader (as tools/r54_model/portable_test.lua) --------------
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
				local node = {name = data:sub(body, zero - 1), parent = parent, keys = {}, nkeys = 0}
				local v = zero + 1
				node.pos = {f32(v), f32(v + 4), f32(v + 8)}
				-- file order w, x, y, z; Irrlicht quaternions are (X, Y, Z, W)
				node.rot = {f32(v + 28), f32(v + 32), f32(v + 36), f32(v + 24)}
				model.nodes[node.name] = node
				parse(v + 40, finish, node)
			elseif tag == "VRTS" then
				for k = body + 12, finish - 1, 32 do
					model.verts[#model.verts + 1] = {
						pos = {f32(k), f32(k + 4), f32(k + 8)},
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
					if f32(k + 4) > 0 then model.weights[i32(k)] = parent.name end
				end
			elseif tag == "KEYS" and parent then
				assert(i32(body) == 7, "keys with position, scale and rotation")
				for k = body + 4, finish - 1, 44 do
					parent.keys[i32(k)] = {f32(k + 32), f32(k + 36), f32(k + 40), f32(k + 28)}
					parent.nkeys = parent.nkeys + 1
				end
			end
			at = finish
		end
	end
	parse(1, #data + 1, nil)
	return model
end

-- Irrlicht's quaternion rotation (getMatrix_transposed, applied the way
-- transformVect applies it), as tools/r54_model/portable_test.lua uses it.
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

local player = load_model("mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d")
local npc = load_model("mods/PLAYER/grug_visuals/models/grug_visuals_npc.b3d")
local BONES = {"Offhand_Shield", "Offhand_Book"}
-- The single frames between player_api's ranges (engine frames).
local BETWEEN = {80, 161, 167, 188, 199, 220}

-- The block clips' first frames, from apply.lua's POSE_CLIPS.
local apply_src = read("mods/PLAYER/grug_visuals/apply.lua")
local bs, bw = apply_src:match("block = {stand = {x = (%d+), y = %d+}, walk = {x = (%d+), y = %d+}")
check(bs and bw, "S apply.lua registers the block clip")
local BLOCK = {tonumber(bs) or 0, tonumber(bw) or 0}

-- The bones a buffer's vertices ride: {bone = count}, and its vertex count.
local function buffer_bones(model, index)
	local seen, out, n = {}, {}, 0
	for _, tri in ipairs(model.buffers[index] or {}) do
		for _, v in ipairs(tri) do
			if not seen[v] then
				seen[v] = true
				n = n + 1
				local bone = model.weights[v] or "?"
				out[bone] = (out[bone] or 0) + 1
			end
		end
	end
	return out, n, seen
end
local function only(bones, allowed)
	for bone in pairs(bones) do
		if not allowed[bone] then return false end
	end
	return true
end

for _, case in ipairs({
	{"player", player, 7, 485, true},
	{"npc", npc, 5, 221, false},
}) do
	local name, model, buffers, frames, is_player = case[1], case[2], case[3], case[4], case[5]
	local arm, body = model.nodes.Arm_Left, model.nodes.Body
	-- B
	for _, bone in ipairs(BONES) do
		local node = model.nodes[bone]
		check(node and node.parent == arm, "B " .. name .. ": " .. bone .. " hangs under Arm_Left")
		check(node and math.abs(node.rot[4]) > 1 - 1e-6, "B " .. name .. ": " .. bone .. " bound with no turn")
	end
	-- U
	eq(#model.buffers, buffers, "U " .. name .. ": mesh buffers (texture slots)")
	local off = is_player and 5 or 4
	local bones, n, seen = buffer_bones(model, off)
	check(only(bones, {Offhand_Shield = true, Offhand_Book = true}),
		"U " .. name .. ": the offhand buffer rides only the offhand bones")
	check((bones.Offhand_Shield or 0) > 0 and (bones.Offhand_Book or 0) > 0,
		"U " .. name .. ": both offhand bones carry vertices")
	local tris = #(model.buffers[off] or {})
	check(tris == 3 * 28 + 62 or tris == 3 * 32 + 62, "U " .. name .. ": offhand triangles " .. tris ..
		" (three shields of 28, with the boss 32, and the book's 62)")
	local outside = 0
	for v in pairs(seen) do
		local uv = model.verts[v + 1].uv
		if uv[1] < 0 or uv[1] > 1 or uv[2] < 0 or uv[2] > 1 then outside = outside + 1 end
	end
	eq(outside, 0, "U " .. name .. ": offhand UVs outside the atlas")
	bones, n, seen = buffer_bones(model, off + 1)
	eq(n, 8, "U " .. name .. ": back card vertices")
	eq(#(model.buffers[off + 1] or {}), 4, "U " .. name .. ": back card triangles")
	check(only(bones, is_player and {Body = true, Cloak = true} or {Body = true}),
		"U " .. name .. ": the back card rides " .. (is_player and "Body or the Cloak" or "Body"))
	local corners = {}
	for v in pairs(seen) do
		local uv = model.verts[v + 1].uv
		corners[uv[1] .. "," .. uv[2]] = (corners[uv[1] .. "," .. uv[2]] or 0) + 1
	end
	check(corners["0,0"] == 2 and corners["1,0"] == 2 and corners["1,1"] == 2 and corners["0,1"] == 2,
		"U " .. name .. ": the back card's UVs are the image's corners, once per side")
	if is_player then
		bones, n = buffer_bones(model, 7)
		eq(#model.buffers[7], 12, "U player: wings triangles (2 x 6)")
		check(only(bones, {Cloak = true}) and n > 0, "U player: the wings ride the Cloak")
	end
	-- K
	eq(body.nkeys, frames, "K " .. name .. ": Body's keyed frames")
	for _, bone in ipairs(BONES) do
		local node = model.nodes[bone]
		local missing = 0
		for f = 1, frames do
			if not node.keys[f] then missing = missing + 1 end
		end
		eq(node.nkeys, frames, "K " .. name .. ": " .. bone .. " keyed frames")
		eq(missing, 0, "K " .. name .. ": " .. bone .. " frames without a key")
		local turned = {}
		for _, f in ipairs(BETWEEN) do
			if math.abs(node.keys[f + 1][4]) < 1 - 1e-6 then turned[#turned + 1] = f end
		end
		check(#turned == 0, "K " .. name .. ": " .. bone .. " holds the arm's turn between the ranges"
			.. (#turned > 0 and (" (turned at " .. table.concat(turned, ", ") .. ")") or ""))
	end
	-- S: the shield's up (model +y at rest) at a frame, relative to the arm
	-- (the arm's own swing taken out), in model axes (+z forward)
	local shield = model.nodes.Offhand_Shield
	local function shield_up(f)
		local up = unrotate(arm.rot, unrotate(body.rot, {0, 1, 0}))
		return rotate(body.rot, rotate(arm.rot, rotate(shield.keys[f + 1], up)))
	end
	local rest = shield_up(0)
	check(rest[2] > 1 - 1e-5, "S " .. name .. ": at stand frame 0 the shield holds the arm's turn")
	if is_player then
		for i, f in ipairs(BLOCK) do
			local up = shield_up(f)
			check(up[3] > 0.5, ("S player: %s frame %d turns the shield's top forward (up %.2f, %.2f, %.2f)")
				:format(i == 1 and "block" or "block_walk", f, up[1], up[2], up[3]))
		end
	end
end

if failures > 0 then
	error(("R55 MODEL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R55 MODEL PORTABLE PASS checks=%d"):format(checks))
