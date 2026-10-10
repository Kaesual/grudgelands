-- Release 0.45.1 lane MC: tuning probe for the riding camera, the mount's
-- size and the rider's seat (fix plan row 8, playtest follow-ups). Tools only,
-- never shipped: copy this folder into a test world's worldmods (README.md).
-- It changes grug_mounts' values of the model being ridden at runtime, for
-- this server run only:
--
--   /mountcam                      the ridden model and its values
--   /mountcam <y> [z]              first person: height above the mount's feet, z along it
--   /mountcam third <y> [z]        third person: the point the camera looks over
--   /mountcam seat <y> [z [x]]     where the rider sits on the mount (re-summons it)
--   /mountcam scale <factor>       the mount's size, 1 = as shipped (re-summons it)
--   /mountcam reset                the shipped values for the ridden model
--   /mountcam dump                 a ready-to-paste Lua table of every changed model
--   /mountcam try <model>|off      ride any model (no purchase, faction or race needed)
--
-- Values are nodes. The camera (catalog `camera`) is applied at once through
-- grug_mounts.apply_camera; the mount's step never writes it. Seat and size
-- are read when a mount is summoned, so those commands re-summon the ridden
-- mount in place. A change goes to every model with the same mesh and shipped
-- size (the three horses) and holds for every later ride.

local PREFIX = "[mountcam] "
-- The engine's clamp of the third-person offset (l_object.cpp
-- l_set_eye_offset), relative to the first-person height: y -1..+1.5, z +-0.5.
local THIRD_DOWN, THIRD_UP, THIRD_Z = 1, 1.5, 0.5

local function round(value, digits)
	return tonumber(("%." .. (digits or 2) .. "f"):format(value))
end

local function fmt(value, digits)
	return ("%g"):format(round(value, digits) + 0) -- + 0: no "-0"
end

-- The shipped values, to tell a change from them (dump, reset).
local shipped = {}
for id, model in pairs(grug_mounts.MODELS) do
	shipped[id] = {camera = table.copy(model.camera), visual_size = table.copy(model.visual_size),
		attach_y = model.attach_y, attach_x = model.attach_x or 0, attach_z = model.attach_z or 0}
end

local function model_id(model)
	for id, other in pairs(grug_mounts.MODELS) do
		if other == model then return id end
	end
end

-- The models sharing this one's mesh and shipped size: one look, one set.
local function siblings(model)
	local own = shipped[model_id(model)]
	local ids = {}
	for id, other in pairs(grug_mounts.MODELS) do
		if other.mesh == model.mesh and shipped[id].visual_size.x == own.visual_size.x and
				shipped[id].visual_size.y == own.visual_size.y then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

-- The rider's place on the mount, nodes: y above the mount's feet, z toward
-- its head, x to the right. The catalog stores it as the seat height
-- (attach_y, times the size) and the mesh's shift under the rider (attach_z,
-- attach_x, tenths of a node, the other way round).
local function seat_of(model)
	return {y = model.attach_y * model.visual_size.y / 10,
		z = -(model.attach_z or 0) / 10, x = -(model.attach_x or 0) / 10}
end

local function camera_text(camera)
	return ("{first = {y = %s, z = %s}, third = {y = %s, z = %s}}"):format(
		fmt(camera.first.y), fmt(camera.first.z), fmt(camera.third.y), fmt(camera.third.z))
end

local function model_text(model)
	return ("visual_size = {x = %s, y = %s}, attach_y = %s, attach_z = %s, attach_x = %s,\n\t\tcamera = %s"):format(
		fmt(model.visual_size.x, 3), fmt(model.visual_size.y, 3), fmt(model.attach_y, 3),
		fmt(model.attach_z or 0, 3), fmt(model.attach_x or 0, 3), camera_text(model.camera))
end

local function changed(id)
	local model, b = grug_mounts.MODELS[id], shipped[id]
	local a = model.camera
	return round(a.first.y) ~= round(b.camera.first.y) or round(a.first.z) ~= round(b.camera.first.z) or
		round(a.third.y) ~= round(b.camera.third.y) or round(a.third.z) ~= round(b.camera.third.z) or
		round(model.visual_size.y, 3) ~= round(b.visual_size.y, 3) or
		round(model.attach_y, 3) ~= round(b.attach_y, 3) or
		round(model.attach_z or 0, 3) ~= round(b.attach_z, 3) or
		round(model.attach_x or 0, 3) ~= round(b.attach_x, 3)
end

local function dump_lines()
	local ids = {}
	for id in pairs(grug_mounts.MODELS) do
		if changed(id) then ids[#ids + 1] = id end
	end
	table.sort(ids)
	if #ids == 0 then return {"nothing changed yet"} end
	local lines = {"-- /mountcam dump: values for grug_mounts/catalog.lua (attach_* in tenths of a node)", "{"}
	for _, id in ipairs(ids) do
		local model = grug_mounts.MODELS[id]
		local seat = seat_of(model)
		lines[#lines + 1] = ("\t%s = { -- seat y %s z %s x %s nodes, size %s x shipped"):format(id,
			fmt(seat.y), fmt(seat.z), fmt(seat.x),
			fmt(model.visual_size.y / shipped[id].visual_size.y, 3))
		lines[#lines + 1] = "\t\t" .. model_text(model) .. ","
		lines[#lines + 1] = "\t},"
	end
	lines[#lines + 1] = "}"
	return lines
end

-- What the engine makes of the third-person values (it clamps silently).
local function third_note(camera)
	local dy = camera.third.y - camera.first.y
	local notes = {}
	if dy < -THIRD_DOWN or dy > THIRD_UP then
		notes[#notes + 1] = ("third y is kept within %s..%s (first y -%g..+%g)"):format(
			fmt(camera.first.y - THIRD_DOWN), fmt(camera.first.y + THIRD_UP), THIRD_DOWN, THIRD_UP)
	end
	if math.abs(camera.third.z) > THIRD_Z then
		notes[#notes + 1] = ("third z is kept within -%g..%g"):format(THIRD_Z, THIRD_Z)
	end
	return #notes > 0 and ("; the engine clamps: " .. table.concat(notes, ", ")) or ""
end

local function describe(model)
	local id = model_id(model)
	local seat = seat_of(model)
	return ("%s (%s), mesh %s, size %s (%s x shipped), seat y %s z %s x %s; camera %s; shared by %s%s"):format(
		id, model.description, model.mesh, fmt(model.visual_size.y, 3),
		fmt(model.visual_size.y / shipped[id].visual_size.y, 3), fmt(seat.y), fmt(seat.z), fmt(seat.x),
		camera_text(model.camera), table.concat(siblings(model), ", "), third_note(model.camera))
end

local function log_dump(name)
	core.log("action", PREFIX .. "by " .. name .. ":\n" .. table.concat(dump_lines(), "\n"))
end

-- Every rider of one of `ids`: re-applies the camera, or (seat, size: read on
-- the summon) summons the same mount again in place.
local function refresh(ids, resummon)
	local touched = {}
	for _, id in ipairs(ids) do touched[grug_mounts.MODELS[id]] = true end
	for name, record in pairs(grug_mounts.active) do
		local rider = core.get_player_by_name(name)
		if rider and touched[record.model] then
			if resummon then
				local pos = record.object and record.object:is_valid() and record.object:get_pos()
				local tier = record.tier
				grug_mounts.dismount(rider, nil, true)
				if pos then grug_mounts.spawn_entity(rider, tier, pos) end
			else
				grug_mounts.apply_camera(rider, record.model)
			end
		end
	end
end

-- Writes y (and z) of `view` ("first" or "third") into every sibling.
local function set_values(model, view, y, z)
	local ids = siblings(model)
	for _, id in ipairs(ids) do
		local camera = grug_mounts.MODELS[id].camera
		camera[view].y = y
		if z then camera[view].z = z end
	end
	refresh(ids, false)
end

-- The rider's seat (nodes, seat_of's axes) into every sibling.
local function set_seat(model, y, z, x)
	local ids = siblings(model)
	for _, id in ipairs(ids) do
		local other = grug_mounts.MODELS[id]
		other.attach_y = y * 10 / other.visual_size.y
		if z then other.attach_z = -z * 10 end
		if x then other.attach_x = -x * 10 end
	end
	refresh(ids, true)
end

-- The size, `factor` times the shipped one; the seat height and the mesh's
-- shifts grow with it, the camera stays.
local function set_scale(model, factor)
	local ids = siblings(model)
	for _, id in ipairs(ids) do
		local other = grug_mounts.MODELS[id]
		local size = shipped[id].visual_size
		local ratio = size.y * factor / other.visual_size.y
		other.visual_size = {x = size.x * factor, y = size.y * factor}
		if other.attach_z then other.attach_z = other.attach_z * ratio end
		if other.attach_x then other.attach_x = other.attach_x * ratio end
	end
	refresh(ids, true)
end

local function reset(model)
	local ids = siblings(model)
	for _, id in ipairs(ids) do
		local other, original = grug_mounts.MODELS[id], shipped[id]
		other.camera = table.copy(original.camera)
		other.visual_size = table.copy(original.visual_size)
		other.attach_y = original.attach_y
		other.attach_z = original.attach_z ~= 0 and original.attach_z or nil
		other.attach_x = original.attach_x ~= 0 and original.attach_x or nil
	end
	refresh(ids, true)
end

-- /mountcam try <model>: ride any model, whatever the character's faction,
-- race and purchases (probe only: grug_mounts.model_for answers the forced
-- model for the tier of its kind until /mountcam try off).
local TRY_TIER = {t1_accord = 1, t1_throng = 1, human = 2, dwarf = 2, elf = 2, orc = 2,
	undead = 2, troll = 2, expert_accord = 3, expert_throng = 3, master_accord = 4,
	master_throng = 4, boat = 5, improved_boat = 6}
local forced = {}
local model_for = grug_mounts.model_for
function grug_mounts.model_for(player, tier_id)
	local id = player and player.get_player_name and forced[player:get_player_name()]
	if id and TRY_TIER[id] == tier_id then return grug_mounts.MODELS[id] end
	return model_for(player, tier_id)
end

local function try(player, id)
	local name = player:get_player_name()
	if id == "off" then
		forced[name] = nil
		return true, PREFIX .. "your own mounts again (the next summon)"
	end
	if not TRY_TIER[id] then
		local ids = {}
		for key in pairs(TRY_TIER) do ids[#ids + 1] = key end
		table.sort(ids)
		return false, PREFIX .. "models: " .. table.concat(ids, ", ")
	end
	forced[name] = id
	if grug_mounts.active[name] then grug_mounts.dismount(player, nil, true) end
	local ok, message = grug_mounts.mount(player, TRY_TIER[id])
	if not ok then return false, PREFIX .. tostring(message) end
	return true, PREFIX .. describe(grug_mounts.active[name].model)
end

core.register_on_leaveplayer(function(player) forced[player:get_player_name()] = nil end)

local function words(param)
	local out = {}
	for w in param:gmatch("%S+") do out[#out + 1] = w end
	return out
end

core.register_chatcommand("mountcam", {
	params = "[<y> [<z>] | third <y> [<z>] | seat <y> [<z> [<x>]] | scale <factor> | reset | dump | try <model>|off]",
	description = "0.45.1 probe: camera, seat and size of the mount you ride (nodes)",
	func = function(name, param)
		local w = words(param)
		if w[1] == "dump" then
			log_dump(name)
			return true, table.concat(dump_lines(), "\n")
		end
		local player = core.get_player_by_name(name)
		if w[1] == "try" then
			if not player then return false, PREFIX .. "player not found" end
			if not core.check_player_privs(name, {server = true}) then
				return false, PREFIX .. "/mountcam try needs the server privilege"
			end
			return try(player, w[2] or "")
		end
		local record = grug_mounts.active[name]
		if not player or not record or not record.model then
			return false, PREFIX .. "ride a mount or boat first (E)"
		end
		local model = record.model
		if not w[1] then
			return true, PREFIX .. describe(model)
		end
		if not core.check_player_privs(name, {server = true}) then
			return false, PREFIX .. "changing values needs the server privilege"
		end
		local id = model_id(model)
		if w[1] == "reset" then
			reset(model)
			log_dump(name)
			return true, PREFIX .. "shipped values: " .. describe(grug_mounts.MODELS[id])
		end
		if w[1] == "seat" then
			local y, z, x = tonumber(w[2]), w[3] and tonumber(w[3]), w[4] and tonumber(w[4])
			if not y or (w[3] and not z) or (w[4] and not x) then
				return false, PREFIX .. "usage: /mountcam seat <y> [<z> [<x>]]  (nodes, e.g. /mountcam seat 1.5 0 0.05)"
			end
			set_seat(model, y, z, x)
			log_dump(name)
			return true, PREFIX .. describe(grug_mounts.MODELS[id])
		end
		if w[1] == "scale" then
			local factor = tonumber(w[2])
			if not factor or factor < 0.3 or factor > 3 then
				return false, PREFIX .. "usage: /mountcam scale <factor>  (0.3..3, 1 = as shipped)"
			end
			set_scale(model, factor)
			log_dump(name)
			return true, PREFIX .. describe(grug_mounts.MODELS[id])
		end
		local view, first_arg = "first", 1
		if w[1] == "third" then view, first_arg = "third", 2 end
		local y = tonumber(w[first_arg])
		local z = w[first_arg + 1] and tonumber(w[first_arg + 1])
		if not y or (w[first_arg + 1] and not z) then
			return false, PREFIX .. "usage: /mountcam [third] <y> [<z>]  (nodes, e.g. /mountcam 2.4 -0.2)"
		end
		set_values(model, view, y, z)
		log_dump(name)
		return true, PREFIX .. describe(model)
	end,
})

core.log("action", PREFIX .. "loaded: /mountcam (0.45.1 riding camera probe, never shipped)")
