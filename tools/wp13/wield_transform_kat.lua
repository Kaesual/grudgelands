-- Known-answer test for the WIELD ATTACHMENT (playtest round 1, 2026-09-15).
--
-- The visuals lane cannot open a client, so the sword in a guard's hand is
-- checked the only other way there is: derive the transform from the mesh and
-- then print where the sprite's own corner points actually end up. This fixture
-- does both halves against the shipped sources --
--
--   * it reads `mods/BASE/player_api/models/character.b3d` itself (the NODE
--     tree, the mesh vertices, the bone weights and the UVs; plain-5.1 byte
--     arithmetic, no `string.unpack`, which the engine injects but a standalone
--     interpreter does not have), and
--   * it loads `mods/PLAYER/grug_visuals/wield_geometry.lua`, the real file the
--     mod uses, so the fixture and the engine cannot be checking different
--     numbers.
--
-- It then reimplements the engine's own attachment maths independently of that
-- file -- Irrlicht's Euler order for `set_attach` rotations
-- (`matrix4::setRotationRadians`, used by `GenericCAO::updateAttachments`) and
-- the wielditem extrusion's local axes (`createExtrusionMesh`,
-- src/client/wieldmesh.cpp:43) -- and reports the hilt, the grip and the tip
-- relative to the centre of the fist, for the arm hanging and for the arm
-- raised 90 degrees.
--
-- The NEGATIVE CONTROL is the version the user photographed: the numbers
-- shipped on 2026-09-14 put the hilt 3.7 units BEHIND the fist with the tip
-- sitting in it, and the last two rows print exactly that. A fixture that
-- cannot reproduce the reported defect has not modelled the engine.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/wp13/wield_transform_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp13/wield_transform_kat.lua")("."))'

local M = {}

local MODEL = "mods/BASE/player_api/models/character.b3d"
local GEOMETRY = "mods/PLAYER/grug_visuals/wield_geometry.lua"

-- The standard 64x32 character-skin layout: the head's FRONT quad -- the one
-- carrying the eyes -- is the 8x8 rectangle at texture pixels (8,8). That
-- convention is the only thing not measured here; the direction it implies is.
local FACE_UV = {u0 = 8, u1 = 16, v0 = 8, v1 = 16}
local SKIN_W, SKIN_H = 64, 32

--
-- Binary reading
--

local function read_file(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local body = handle:read("*a")
	handle:close()
	return body
end

local function i32(s, i)
	local b1, b2, b3, b4 = s:byte(i, i + 3)
	local v = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	if v >= 2147483648 then
		v = v - 4294967296
	end
	return v
end

-- IEEE-754 binary32, little endian, without bitwise operators.
local function f32(s, i)
	local b1, b2, b3, b4 = s:byte(i, i + 3)
	local sign = 1
	if b4 >= 128 then
		sign = -1
		b4 = b4 - 128
	end
	local exponent = b4 * 2 + math.floor(b3 / 128)
	local mantissa = (b3 % 128) * 65536 + b2 * 256 + b1
	if exponent == 0 then
		if mantissa == 0 then
			return 0
		end
		return sign * math.ldexp(mantissa / 8388608, -126)
	end
	if exponent == 255 then
		return sign * math.huge
	end
	return sign * math.ldexp(1 + mantissa / 8388608, exponent - 127)
end

--
-- The .b3d NODE tree, mesh and bone weights
--

local function parse_b3d(body)
	local nodes, order = {}, {}
	local verts, uvs, tris = {}, {}, {}
	local mesh_base = 0
	local walk

	local function node_chunk(from, to, parent)
		local stop = body:find("\0", from, true)
		local name = body:sub(from, stop - 1)
		local at = stop + 1
		local entry = {name = name, parent = parent, bone = {},
			pos = {f32(body, at), f32(body, at + 4), f32(body, at + 8)},
			-- b3d stores the quaternion as w, x, y, z.
			quat = {f32(body, at + 24), f32(body, at + 28),
				f32(body, at + 32), f32(body, at + 36)}}
		nodes[name] = entry
		order[#order + 1] = name
		walk(at + 40, to, name)
	end

	local function vrts_chunk(from, to)
		local flags = i32(body, from)
		local sets = i32(body, from + 4)
		local set_size = i32(body, from + 8)
		local at = from + 12
		local stride = 3
		if flags % 2 == 1 then
			stride = stride + 3 -- normal
		end
		if math.floor(flags / 2) % 2 == 1 then
			stride = stride + 4 -- colour
		end
		mesh_base = #verts
		while at < to do
			verts[#verts + 1] = {f32(body, at), f32(body, at + 4),
				f32(body, at + 8)}
			local uv_at = at + stride * 4
			uvs[#uvs + 1] = {f32(body, uv_at), f32(body, uv_at + 4)}
			at = at + (stride + sets * set_size) * 4
		end
	end

	local function tris_chunk(from, to)
		local at = from + 4 -- brush id
		local base = mesh_base
		while at < to do
			tris[#tris + 1] = {i32(body, at) + base + 1,
				i32(body, at + 4) + base + 1, i32(body, at + 8) + base + 1}
			at = at + 12
		end
	end

	local function bone_chunk(from, to, parent)
		local weights = nodes[parent].bone
		local at = from
		while at < to do
			weights[#weights + 1] = {id = i32(body, at) + 1,
				weight = f32(body, at + 4)}
			at = at + 8
		end
	end

	walk = function(from, to, parent)
		local at = from
		while at < to do
			local tag = body:sub(at, at + 3)
			local length = i32(body, at + 4)
			local from2, to2 = at + 8, at + 8 + length
			if tag == "BB3D" then
				walk(from2 + 4, to2, nil)
			elseif tag == "NODE" then
				node_chunk(from2, to2, parent)
			elseif tag == "MESH" then
				walk(from2 + 4, to2, parent)
			elseif tag == "VRTS" then
				vrts_chunk(from2, to2)
			elseif tag == "TRIS" then
				tris_chunk(from2, to2)
			elseif tag == "BONE" then
				bone_chunk(from2, to2, parent)
			end
			at = to2
		end
	end

	walk(1, #body + 1, nil)
	return {nodes = nodes, order = order, verts = verts, uvs = uvs, tris = tris}
end

--
-- 3x3 rotations, stored as the three IMAGES of the basis vectors (columns),
-- exactly the layout Irrlicht's matrix4 uses.
--

local IDENTITY = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}

local function apply(rot, v)
	local out = {0, 0, 0}
	for k = 1, 3 do
		for i = 1, 3 do
			out[i] = out[i] + rot[k][i] * v[k]
		end
	end
	return out
end

local function compose(a, b)
	return {apply(a, b[1]), apply(a, b[2]), apply(a, b[3])}
end

-- `core::Transform::buildMatrix` rotates with `quaternion::getMatrix_transposed`.
local function quat_rot(q)
	local w, x, y, z = q[1], q[2], q[3], q[4]
	local n = math.sqrt(w * w + x * x + y * y + z * z)
	if n > 0 then
		w, x, y, z = w / n, x / n, y / n, z / n
	end
	return {
		{1 - 2 * y * y - 2 * z * z, 2 * x * y - 2 * z * w, 2 * x * z + 2 * y * w},
		{2 * x * y + 2 * z * w, 1 - 2 * x * x - 2 * z * z, 2 * z * y - 2 * x * w},
		{2 * x * z - 2 * y * w, 2 * z * y + 2 * x * w, 1 - 2 * x * x - 2 * y * y},
	}
end

-- `matrix4::setRotationDegrees` == Rz(z) * Ry(y) * Rx(x), right handed.
local function euler_rot(rx, ry, rz)
	local d = math.pi / 180
	local cp, sp = math.cos(rx * d), math.sin(rx * d)
	local cy, sy = math.cos(ry * d), math.sin(ry * d)
	local cr, sr = math.cos(rz * d), math.sin(rz * d)
	return {
		{cy * cr, cy * sr, -sy},
		{sp * sy * cr - cp * sr, sp * sy * sr + cp * cr, sp * cy},
		{cp * sy * cr + sp * sr, cp * sy * sr - sp * cr, cp * cy},
	}
end

-- Rest transform of a bone in MODEL space: walk the parent chain down.
local function bone_frame(model, name)
	local chain = {}
	local at = name
	while at do
		table.insert(chain, 1, at)
		at = model.nodes[at].parent
	end
	local rot, origin = IDENTITY, {0, 0, 0}
	for _, step in ipairs(chain) do
		local entry = model.nodes[step]
		local moved = apply(rot, entry.pos)
		origin = {origin[1] + moved[1], origin[2] + moved[2],
			origin[3] + moved[3]}
		rot = compose(rot, quat_rot(entry.quat))
	end
	return rot, origin
end

--
-- Output formatting: rounded to three decimals so the two interpreters agree
-- byte for byte and a signed zero can never print as "-0.000".
--

local function num(v)
	local r = math.floor(v * 1000 + 0.5) / 1000
	if r == 0 then
		r = 0
	end
	return string.format("%.3f", r)
end

local function vec(v)
	return num(v[1]) .. "," .. num(v[2]) .. "," .. num(v[3])
end

function M.run(repo)
	repo = repo or "."
	local out, failures = {}, {}
	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end
	local function close(a, b, tolerance, message)
		check(math.abs(a - b) <= tolerance, message .. " (" .. num(a) ..
			" vs " .. num(b) .. ")")
	end

	--
	-- A. the mesh
	--
	local body = read_file(repo .. "/" .. MODEL)
	if not body then
		row("wp13_wield_result", "FAIL", 1)
		row("wp13_wield_failure", "cannot read " .. MODEL)
		return table.concat(out, "\n") .. "\n"
	end
	local model = parse_b3d(body)
	check(model.nodes["Arm_Right"] ~= nil, "character.b3d has no Arm_Right bone")
	if not model.nodes["Arm_Right"] then
		row("wp13_wield_result", "FAIL", #failures)
		row("wp13_wield_failure", failures[1])
		return table.concat(out, "\n") .. "\n"
	end

	local arm_rot, arm_origin = bone_frame(model, "Arm_Right")
	row("wp13_wield_bone", "Arm_Right", vec(arm_origin),
		"x->" .. vec(arm_rot[1]), "y->" .. vec(arm_rot[2]),
		"z->" .. vec(arm_rot[3]))
	-- The composition Ry(180) * Rx(180) = diag(-1, -1, 1): bone +y is model
	-- DOWN (along the hanging arm) and bone +z is model FORWARD.
	close(arm_rot[1][1], -1, 0.001, "bone +x is not model -x")
	close(arm_rot[2][2], -1, 0.001, "bone +y is not model -y (down the arm)")
	close(arm_rot[3][3], 1, 0.001, "bone +z is not model +z")
	close(arm_origin[1], 3.15, 0.001, "the shoulder is not at model x 3.15")
	close(arm_origin[2], 11.55, 0.001, "the shoulder is not at model y 11.55")

	-- How far the arm reaches past its joint, from the vertices the bone owns.
	local low, high
	for _, entry in ipairs(model.nodes["Arm_Right"].bone) do
		if entry.weight > 0.5 then
			local y = model.verts[entry.id][2]
			low = (low == nil or y < low) and y or low
			high = (high == nil or y > high) and y or high
		end
	end
	check(low ~= nil, "no vertex is weighted to Arm_Right")
	local reach = arm_origin[2] - (low or 0)
	-- The fist is the bottom third of the arm box (4 of the 12 skin pixels
	-- that cover it), so its centre sits one sixth of the box above the end.
	local fist = reach - (high - low) / 6
	row("wp13_wield_arm", "model_y", num(low or 0) .. ".." .. num(high or 0),
		"reach", num(reach), "fist_centre_bone_y", num(fist))
	close(reach, 5.25, 0.001, "the arm does not reach 5.25 units past its joint")

	-- Which way the character faces, from the head quad that carries the face.
	local head = {}
	for _, entry in ipairs(model.nodes["Head"].bone) do
		if entry.weight > 0.5 then
			head[entry.id] = true
		end
	end
	local face_normal
	for _, tri in ipairs(model.tris) do
		if head[tri[1]] then
			local inside = true
			for _, id in ipairs(tri) do
				local u, v = model.uvs[id][1] * SKIN_W, model.uvs[id][2] * SKIN_H
				if u < FACE_UV.u0 - 0.01 or u > FACE_UV.u1 + 0.01 or
						v < FACE_UV.v0 - 0.01 or v > FACE_UV.v1 + 0.01 then
					inside = false
				end
			end
			if inside then
				local a, b, c = model.verts[tri[1]], model.verts[tri[2]],
					model.verts[tri[3]]
				local e1 = {b[1] - a[1], b[2] - a[2], b[3] - a[3]}
				local e2 = {c[1] - a[1], c[2] - a[2], c[3] - a[3]}
				local n = {e1[2] * e2[3] - e1[3] * e2[2],
					e1[3] * e2[1] - e1[1] * e2[3],
					e1[1] * e2[2] - e1[2] * e2[1]}
				local len = math.sqrt(n[1] * n[1] + n[2] * n[2] + n[3] * n[3])
				face_normal = {n[1] / len, n[2] / len, n[3] / len}
			end
		end
	end
	check(face_normal ~= nil, "no head quad maps to the skin's face rectangle")
	if face_normal then
		row("wp13_wield_face", "uv", FACE_UV.u0 .. ".." .. FACE_UV.u1 .. "x" ..
			FACE_UV.v0 .. ".." .. FACE_UV.v1, "normal", vec(face_normal))
		close(face_normal[3], 1, 0.001,
			"the face quad does not look along model +z")
	end

	--
	-- B. the shipped numbers
	--
	local had = rawget(_G, "grug_visuals")
	rawset(_G, "grug_visuals", {})
	local chunk, load_error = loadfile(repo .. "/" .. GEOMETRY)
	if not chunk then
		rawset(_G, "grug_visuals", had)
		row("wp13_wield_result", "FAIL", 1)
		row("wp13_wield_failure", "cannot load " .. GEOMETRY .. ": " ..
			tostring(load_error))
		return table.concat(out, "\n") .. "\n"
	end
	chunk()
	local wield = rawget(_G, "grug_visuals").WIELD
	rawset(_G, "grug_visuals", had)

	check(wield ~= nil, GEOMETRY .. " sets no grug_visuals.WIELD")
	check(wield and wield.bone == "Arm_Right",
		"the wield entity does not hang off Arm_Right")
	row("wp13_wield_numbers", "pos",
		vec({wield.pos.x, wield.pos.y, wield.pos.z}), "rot",
		vec({wield.rot.x, wield.rot.y, wield.rot.z}), "size",
		num(wield.size.x) .. "," .. num(wield.size.y))
	-- The fist the derivation used has to be the fist the mesh has.
	close(wield.hand.y, fist, 0.001,
		"grug_visuals.WIELD.hand disagrees with the mesh's own fist centre")
	close(wield.sprite_edge, 40 * wield.size.x / 2, 1e-9,
		"sprite_edge is not 40 * size / 2")

	--
	-- C. the printed check: sprite points in the bone's frame and in model space
	--

	-- `pose` rotates the bone about its own local x, which is how both the walk
	-- and the mine animation move this arm (character.b3d KEYS, Arm_Right: the
	-- walk frames sit at +-32 degrees off the hanging rest pose, and mine frame
	-- 191 is 109 degrees off it). Positive raises the arm FORWARD.
	local function measure(label, pos, rot, raise)
		local frame = arm_rot
		if raise ~= 0 then
			frame = compose(arm_rot, euler_rot(raise, 0, 0))
		end
		local attach = euler_rot(rot.x, rot.y, rot.z)
		local hand_bone = {0, wield.hand.y, 0}
		local function to_model(v)
			local m = apply(frame, v)
			return {arm_origin[1] + m[1], arm_origin[2] + m[2],
				arm_origin[3] + m[3]}
		end
		local hand = to_model(hand_bone)
		-- A sprite point, image coordinates in [-0.5, 0.5] with v pointing up.
		local function sprite(u, v)
			local local_point = {u * wield.sprite_edge, v * wield.sprite_edge, 0}
			local turned = apply(attach, local_point)
			return to_model({pos.x + turned[1], pos.y + turned[2],
				pos.z + turned[3]})
		end
		local function relative(p)
			return {p[1] - hand[1], p[2] - hand[2], p[3] - hand[3]}
		end
		local hilt = relative(sprite(0, -0.5))
		local grip = relative(sprite(0, wield.grip_fraction))
		local tip = relative(sprite(0, 0.5))
		local blade = apply(frame, apply(attach, {0, 1, 0}))
		local flat = apply(frame, apply(attach, {0, 0, 1}))
		row(label, "hand", vec(hand), "hilt-hand", vec(hilt), "grip-hand",
			vec(grip), "tip-hand", vec(tip), "blade", vec(blade), "flat",
			vec(flat))
		return {hilt = hilt, grip = grip, tip = tip, blade = blade, flat = flat}
	end

	local hanging = measure("wp13_wield_hanging", wield.pos, wield.rot, 0)
	local raised = measure("wp13_wield_raised90", wield.pos, wield.rot, 90)

	-- The grip belongs IN the fist, both poses.
	for _, case in ipairs({{"hanging", hanging}, {"raised", raised}}) do
		local g = case[2].grip
		local distance = math.sqrt(g[1] * g[1] + g[2] * g[2] + g[3] * g[3])
		check(distance <= 0.001, "the grip is " .. num(distance) ..
			" units from the fist with the arm " .. case[1])
		local h = case[2].hilt
		local hilt_distance = math.sqrt(h[1] * h[1] + h[2] * h[2] + h[3] * h[3])
		check(hilt_distance <= 1.0, "the hilt end is " .. num(hilt_distance) ..
			" units from the fist with the arm " .. case[1] ..
			" -- it must stay inside the hand")
	end

	-- Hanging arm: forward, tilted up by exactly the declared angle, and the
	-- broad face of the blade standing vertical (a horizontal flat normal).
	local expect = math.sin(wield.tilt_up * math.pi / 180)
	close(hanging.blade[3], math.cos(wield.tilt_up * math.pi / 180), 0.002,
		"the blade does not point forward (model +z)")
	close(hanging.blade[2], expect, 0.002,
		"the blade is not tilted up by tilt_up degrees")
	close(hanging.blade[1], 0, 0.002, "the blade leans sideways")
	close(hanging.flat[2], 0, 0.002,
		"the blade is not held with its flat vertical (edge down)")
	check(hanging.tip[3] > 3, "the tip is not well in front of the fist (" ..
		num(hanging.tip[3]) .. ")")
	check(hanging.tip[2] > 0, "the tip is not above the fist")

	-- Raised arm: the same grip, the blade swung up with the arm.
	check(raised.blade[2] > 0.9, "the raised arm's blade does not point up (" ..
		num(raised.blade[2]) .. ")")
	check(raised.tip[2] > 3, "the raised arm's tip is not above the fist")

	--
	-- D. negative control: the version the user photographed
	--
	local OLD_POS = {x = 0, y = 5.5, z = -1.5}
	local OLD_ROT = {x = -90, y = 180, z = 0}
	local old_hanging = measure("wp13_wield_old_hanging", OLD_POS, OLD_ROT, 0)
	measure("wp13_wield_old_raised90", OLD_POS, OLD_ROT, 90)
	-- The reported picture: hilt far behind the fist, tip sitting in it.
	check(old_hanging.hilt[3] < -3,
		"the negative control does not reproduce the photographed hilt (" ..
		num(old_hanging.hilt[3]) .. ") -- the model of the engine is wrong")
	check(math.abs(old_hanging.tip[3]) < 1,
		"the negative control does not reproduce the tip in the fist (" ..
		num(old_hanging.tip[3]) .. ")")
	check(math.abs(old_hanging.flat[2]) > 0.9,
		"the negative control's flat is not horizontal -- the 90 degree roll " ..
		"this fix adds would then be wrong")

	table.sort(failures)
	row("wp13_wield_result", #failures == 0 and "PASS" or "FAIL", #failures)
	for _, message in ipairs(failures) do
		row("wp13_wield_failure", message)
	end
	return table.concat(out, "\n") .. "\n"
end

return function(repo)
	return M.run(repo)
end
