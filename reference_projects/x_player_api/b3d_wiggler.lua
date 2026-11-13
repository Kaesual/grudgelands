-- x_player_api/b3d_wiggler.lua
-- Pure Lua B3D Model Rotation Wiggler for Luanti
-- Resolves Irrlicht skeletal animation matrix decomposition bug (Issue #15692)
--
-- Portions adapted with credit and appreciation from:
--   modlib (https://github.com/appgurueu/modlib) and character_anim by Lars Mueller (LMD / appgurueu)
--   Licensed under the MIT License:
--   Copyright (c) 2020-2024 Lars Mueller
--
-- Problem Background:
-- When a bone rotation in a .b3d model is an exact 180-degree rotation around a cardinal axis,
-- Irrlicht's CMatrix4<T>::getScale() assumes off-diagonal entries are 0 and returns negative scale
-- (-1, 1, -1) with an identity rotation (0, 0, 0), flipping attached wielditems backwards.
--
-- Solution:
-- Perturbs perfect rotations by +/- 1e-3 radians (< 0.05 degrees), breaking zero off-diagonals
-- and forcing Irrlicht to calculate true positive Euclidean scale (1, 1, 1).
-- This pure Lua implementation has ZERO external mod dependencies and preserves all keyframes.

x_player_api = x_player_api or {}

local floor = math.floor
local frexp = math.frexp
local abs = math.abs
local sqrt = math.sqrt

local engine = rawget(_G, "core") or rawget(_G, "minetest")
local str_pack = rawget(string, "pack")
local str_unpack = rawget(string, "unpack")
local has_native_pack = type(str_pack) == "function" and type(str_unpack) == "function"

---Read 32-bit unsigned integer (little-endian)
---@param str string
---@param pos integer
---@return integer val
local function read_u32_le(str, pos)
	if has_native_pack then
		return (str_unpack("<I4", str, pos))
	end
	local b1, b2, b3, b4 = str:byte(pos, pos + 3)
	if not b4 then return 0 end
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

---Read 32-bit IEEE-754 float (little-endian)
---@param str string
---@param pos integer
---@return number val
local function read_f32_le(str, pos)
	if has_native_pack then
		return (str_unpack("<f", str, pos))
	end
	local b1, b2, b3, b4 = str:byte(pos, pos + 3)
	if not b4 then return 0.0 end
	local sign = (b4 >= 128) and -1 or 1
	local exp = (b4 % 128) * 2 + floor(b3 / 128)
	local mant = ((b3 % 128) * 256 + b2) * 256 + b1
	if exp == 0 then
		if mant == 0 then return 0.0 end
		return sign * (mant / 8388608) * (2 ^ -126)
	elseif exp == 255 then
		return (mant == 0) and (sign * (1 / 0)) or (0 / 0)
	end
	return sign * (1 + mant / 8388608) * (2 ^ (exp - 127))
end

---Write 32-bit IEEE-754 float (little-endian)
---@param val number
---@return string bytes 4-byte binary string
local function write_f32_le(val)
	if has_native_pack then
		return str_pack("<f", val)
	end
	if val == 0 then
		return string.char(0, 0, 0, 0)
	end
	local sign = 0
	if val < 0 then
		sign = 128
		val = -val
	end
	local mant, exp = frexp(val)
	mant = mant * 2 - 1
	exp = exp - 1 + 127
	if exp <= 0 then
		mant = (val / (2 ^ -126)) * 8388608
		exp = 0
	elseif exp >= 255 then
		return string.char(0, 0, 128, sign + 127)
	else
		mant = floor(mant * 8388608 + 0.5)
	end
	local b1 = mant % 256
	mant = floor(mant / 256)
	local b2 = mant % 256
	mant = floor(mant / 256)
	local b3 = (exp % 2) * 128 + mant
	local b4 = sign + floor(exp / 2)
	return string.char(b1, b2, b3, b4)
end

---Check if quaternion produces an Irrlicht-buggy matrix (zero off-diagonals and ~180 degree rotation)
---@param _w number
---@param x number
---@param y number
---@param z number
---@return boolean is_perfect True if rotation causes matrix decomposition flip
local function is_perfect_rotation(_w, x, y, z)
	-- Identity rotation (0 deg) has x=y=z=0, off-diagonals are zero but scale is positive (+1, +1, +1).
	if abs(x) + abs(y) + abs(z) < 1e-5 then
		return false
	end
	local m11 = 1.0 - 2.0 * (y * y + z * z)
	local m22 = 1.0 - 2.0 * (x * x + z * z)
	local m33 = 1.0 - 2.0 * (x * x + y * y)
	local diag_abs_sum = abs(m11) + abs(m22) + abs(m33)
	return abs(diag_abs_sum - 3.0) < 1e-5
end

---Perturb a perfect rotation quaternion by +/- 1e-3 to break zero off-diagonals
---@param w number
---@param x number
---@param y number
---@param z number
---@return number nw, number nx, number ny, number nz
local function wiggle_quaternion(w, x, y, z)
	if not is_perfect_rotation(w, x, y, z) then
		return w, x, y, z
	end
	for _, sign in ipairs({1e-3, -1e-3}) do
		local nw = w + sign
		local nx = x + sign
		local ny = y + sign
		local nz = z + sign
		local len = sqrt(nw * nw + nx * nx + ny * ny + nz * nz)
		if len > 0 then
			nw = nw / len
			nx = nx / len
			ny = ny / len
			nz = nz / len
			if not is_perfect_rotation(nw, nx, ny, nz) then
				return nw, nx, ny, nz
			end
		end
	end
	return w, x, y, z
end

---Process raw B3D binary data and wiggle all perfect NODE and KEYS rotation quaternions
---@param data string Binary B3D file contents
---@return string patched_data, integer nodes_wiggled, integer keys_wiggled
function x_player_api.wiggle_b3d_data(data)
	if #data < 12 or data:sub(1, 4) ~= "BB3D" then
		return data, 0, 0
	end

	local nodes_wiggled = 0
	local keys_wiggled = 0

	local rope = {}
	local last_pos = 1

	local function emit_up_to(pos)
		if pos > last_pos then
			table.insert(rope, data:sub(last_pos, pos - 1))
			last_pos = pos
		end
	end

	local function walk_chunks(start_pos, end_pos)
		local pos = start_pos
		while pos < end_pos do
			if pos + 7 > end_pos then break end
			local chunk_tag = data:sub(pos, pos + 3)
			local chunk_size = read_u32_le(data, pos + 4)
			local payload_start = pos + 8
			local payload_end = payload_start + chunk_size
			if payload_end > #data + 1 then break end

			if chunk_tag == "NODE" then
				local zero_idx = data:find("\0", payload_start, true)
				if zero_idx and zero_idx < payload_end then
					local rot_offset = zero_idx + 1 + 12 + 12 -- name\0 + 3 floats pos + 3 floats scale
					if rot_offset + 15 <= payload_end then
						local w = read_f32_le(data, rot_offset)
						local x = read_f32_le(data, rot_offset + 4)
						local y = read_f32_le(data, rot_offset + 8)
						local z = read_f32_le(data, rot_offset + 12)
						if is_perfect_rotation(w, x, y, z) then
							local nw, nx, ny, nz = wiggle_quaternion(w, x, y, z)
							emit_up_to(rot_offset)
							table.insert(rope, write_f32_le(nw))
							table.insert(rope, write_f32_le(nx))
							table.insert(rope, write_f32_le(ny))
							table.insert(rope, write_f32_le(nz))
							last_pos = rot_offset + 16
							nodes_wiggled = nodes_wiggled + 1
						end
						walk_chunks(rot_offset + 16, payload_end)
					end
				end
			elseif chunk_tag == "KEYS" then
				if payload_start + 4 <= payload_end then
					local flags = read_u32_le(data, payload_start)
					local k_pos = payload_start + 4
					while k_pos < payload_end do
						k_pos = k_pos + 4 -- frame
						if (flags % 2) >= 1 then -- bit 0: position
							k_pos = k_pos + 12
						end
						if (floor(flags / 2) % 2) >= 1 then -- bit 1: scale
							k_pos = k_pos + 12
						end
						if (floor(flags / 4) % 2) >= 1 then -- bit 2: rotation
							if k_pos + 15 <= payload_end then
								local w = read_f32_le(data, k_pos)
								local x = read_f32_le(data, k_pos + 4)
								local y = read_f32_le(data, k_pos + 8)
								local z = read_f32_le(data, k_pos + 12)
								if is_perfect_rotation(w, x, y, z) then
									local nw, nx, ny, nz = wiggle_quaternion(w, x, y, z)
									emit_up_to(k_pos)
									table.insert(rope, write_f32_le(nw))
									table.insert(rope, write_f32_le(nx))
									table.insert(rope, write_f32_le(ny))
									table.insert(rope, write_f32_le(nz))
									last_pos = k_pos + 16
									keys_wiggled = keys_wiggled + 1
								end
							end
							k_pos = k_pos + 16
						end
					end
				end
			end

			pos = payload_end
		end
	end

	walk_chunks(13, #data + 1)

	if nodes_wiggled == 0 and keys_wiggled == 0 then
		return data, 0, 0
	end

	emit_up_to(#data + 1)
	return table.concat(rope), nodes_wiggled, keys_wiggled
end

---Locate a model file on disk across all active mods
---@param filename string
---@return string|nil full_path
local function find_model_path(filename)
	if not engine then return nil end

	-- Priority 1: Check bridge mod (x_player_bridge) if present, which bundles modern player models
	if engine.get_modpath then
		local bridge_path = engine.get_modpath("x_player_bridge")
		if bridge_path then
			local candidate = bridge_path .. "/models/" .. filename
			local f = io.open(candidate, "rb")
			if f then
				f:close()
				return candidate
			end
		end
	end

	-- Priority 2: Check x_player_api base mod models
	if engine.get_modpath then
		local api_path = engine.get_modpath("x_player_api")
		if api_path then
			local candidate = api_path .. "/models/" .. filename
			local f = io.open(candidate, "rb")
			if f then
				f:close()
				return candidate
			end
		end
	end

	-- Priority 3: Check currently executing registering mod
	local this_mod = engine.get_current_modname and engine.get_current_modname()
	local this_path = this_mod and engine.get_modpath and engine.get_modpath(this_mod)
	if this_path then
		local candidate = this_path .. "/models/" .. filename
		local f = io.open(candidate, "rb")
		if f then
			f:close()
			return candidate
		end
	end

	-- Priority 4: Search remaining active mods in reverse order
	if engine.get_modnames and engine.get_modpath then
		local modnames = engine.get_modnames()
		for i = #modnames, 1, -1 do
			local mod = modnames[i]
			local mpath = engine.get_modpath(mod)
			if mpath then
				local candidate = mpath .. "/models/" .. filename
				local f = io.open(candidate, "rb")
				if f then
					f:close()
					return candidate
				end
			end
		end
	end
	return nil
end

---Cache of already processed models and registered media to prevent duplicate dynamic_add_media calls
local processed_models = {}
local added_dynamic_media = {}

---Scan and wiggle a specific B3D model, registering dynamic media and redirection if needed
---@param mesh_name string The original mesh filename (e.g. "character.b3d")
---@param full_path? string Optional absolute path to the mesh file
---@return string resolved_name The model name to use (original or redirected)
function x_player_api.scan_and_wiggle_b3d_model(mesh_name, full_path)
	if not mesh_name or not mesh_name:match("%.b3d$") then
		return mesh_name
	end

	if mesh_name:find("^_wiggled_") then
		return mesh_name
	end

	if processed_models[mesh_name] then
		return processed_models[mesh_name]
	end

	full_path = full_path or find_model_path(mesh_name)
	if not full_path then
		processed_models[mesh_name] = mesh_name
		return mesh_name
	end

	local f = io.open(full_path, "rb")
	if not f then
		processed_models[mesh_name] = mesh_name
		return mesh_name
	end
	local raw_data = f:read("*a")
	f:close()

	local wiggled_data, nodes_count, keys_count = x_player_api.wiggle_b3d_data(raw_data)
	if nodes_count == 0 and keys_count == 0 then
		processed_models[mesh_name] = mesh_name
		if engine.log then
			engine.log("info", string.format(
				"[x_player_api] B3D model '%s' verified clean (0 un-wiggled rotations).",
				mesh_name
			))
		end
		return mesh_name
	end

	local target_name = "_wiggled_" .. mesh_name
	processed_models[mesh_name] = target_name
	processed_models[target_name] = target_name

	if not added_dynamic_media[target_name] then
		added_dynamic_media[target_name] = true
		if engine.dynamic_add_media then
			if engine.get_worldpath then
				local media_dir = engine.get_worldpath() .. "/x_player_api_media"
				if engine.mkdir then engine.mkdir(media_dir) end
				local out_path = media_dir .. "/" .. target_name
				local out_file = io.open(out_path, "wb")
				if out_file then
					out_file:write(wiggled_data)
					out_file:close()
					engine.dynamic_add_media({
						filepath = out_path,
						filename = target_name,
					})
				else
					engine.dynamic_add_media({
						filename = target_name,
						filedata = wiggled_data,
					})
				end
			else
				engine.dynamic_add_media({
					filename = target_name,
					filedata = wiggled_data,
				})
			end
		end
	end

	-- If model definition was already registered under mesh_name, update its mesh field and alias target
	if x_player_api.registered_models and x_player_api.registered_models[mesh_name] then
		local def = x_player_api.registered_models[mesh_name]
		def.mesh = target_name
		x_player_api.registered_models[target_name] = def
	end

	if engine and engine.log then
		engine.log("action", string.format(
			"[x_player_api] Wiggled B3D model '%s' -> '%s' (%d nodes, %d keys) to fix Irrlicht decomposition bug.",
			mesh_name, target_name, nodes_count, keys_count
		))
	end

	return target_name
end

---Scan all registered B3D models and apply dynamic wiggling to any unpatched models
function x_player_api.scan_and_wiggle_registered_b3d_models()
	if not x_player_api.registered_models then return end
	for _, def in pairs(x_player_api.registered_models) do
		if def.mesh and def.mesh:match("%.b3d$") and not def.mesh:find("^_wiggled_") then
			local resolved = x_player_api.scan_and_wiggle_b3d_model(def.mesh)
			if resolved and resolved ~= def.mesh then
				def.mesh = resolved
				x_player_api.registered_models[resolved] = def
			end
		end
	end
end

-- Automatically scan registered models once all mods finish loading
if engine and engine.register_on_mods_loaded then
	engine.register_on_mods_loaded(function()
		x_player_api.scan_and_wiggle_registered_b3d_models()
	end)
end

-- Export helpers for unit testing
x_player_api._b3d_wiggler_test = {
	is_perfect_rotation = is_perfect_rotation,
	wiggle_quaternion = wiggle_quaternion,
	read_u32_le = read_u32_le,
	read_f32_le = read_f32_le,
	write_f32_le = write_f32_le,
	processed_models = processed_models,
	added_dynamic_media = added_dynamic_media,
}

return x_player_api
