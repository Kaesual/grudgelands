-- Release 0.45.1 lane MC: tuning probe for the riding camera (fix plan row
-- 8). Tools only, never shipped: copy this folder into a test world's
-- worldmods (README.md). It changes grug_mounts' camera values of the model
-- being ridden at runtime, for this server run only:
--
--   /mountcam                    the ridden model and its values
--   /mountcam <y> [z]            first person: height above the mount's feet, z along it
--   /mountcam third <y> [z]      third person: the point the camera looks over
--   /mountcam reset              the shipped values for the ridden model
--   /mountcam dump               a ready-to-paste Lua table of every changed model
--   /mountcam try <model>|off    ride any model (no purchase, faction or race needed)
--
-- Values are nodes, as in grug_mounts/catalog.lua `camera`. A change goes to
-- every model with the same mesh and size (the three horses), is applied at
-- once through grug_mounts.apply_camera and holds for every later ride; the
-- mount's step never writes the camera (it re-applies these same values only
-- if something replaced the sit pose).

local PREFIX = "[mountcam] "
-- The engine's clamp of the third-person offset (l_object.cpp
-- l_set_eye_offset), relative to the first-person height: y -1..+1.5, z +-0.5.
local THIRD_DOWN, THIRD_UP, THIRD_Z = 1, 1.5, 0.5

local function round(value)
	return tonumber(("%.2f"):format(value))
end

local function fmt(value)
	return ("%g"):format(round(value))
end

-- The shipped values, to tell a change from them (dump, reset).
local shipped = {}
for id, model in pairs(grug_mounts.MODELS) do
	shipped[id] = table.copy(model.camera)
end

local function model_id(model)
	for id, other in pairs(grug_mounts.MODELS) do
		if other == model then return id end
	end
end

-- The models sharing this one's mesh and size: one look, one camera.
local function siblings(model)
	local ids = {}
	for id, other in pairs(grug_mounts.MODELS) do
		if other.mesh == model.mesh and other.visual_size.x == model.visual_size.x and
				other.visual_size.y == model.visual_size.y then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

local function camera_text(camera)
	return ("{first = {y = %s, z = %s}, third = {y = %s, z = %s}}"):format(
		fmt(camera.first.y), fmt(camera.first.z), fmt(camera.third.y), fmt(camera.third.z))
end

local function changed(id)
	local a, b = grug_mounts.MODELS[id].camera, shipped[id]
	return round(a.first.y) ~= round(b.first.y) or round(a.first.z) ~= round(b.first.z) or
		round(a.third.y) ~= round(b.third.y) or round(a.third.z) ~= round(b.third.z)
end

local function dump_lines()
	local ids = {}
	for id in pairs(grug_mounts.MODELS) do
		if changed(id) then ids[#ids + 1] = id end
	end
	table.sort(ids)
	if #ids == 0 then return {"nothing changed yet"} end
	local lines = {"-- /mountcam dump: camera values for grug_mounts/catalog.lua", "{"}
	for _, id in ipairs(ids) do
		lines[#lines + 1] = ("\t%s = {camera = %s},"):format(id,
			camera_text(grug_mounts.MODELS[id].camera))
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
	local seat = model.attach_y * model.visual_size.y / 10
	return ("%s (%s), mesh %s, size %g, seat %s nodes above its feet: %s; shared by %s%s"):format(
		id, model.description, model.mesh, model.visual_size.y, fmt(seat),
		camera_text(model.camera), table.concat(siblings(model), ", "), third_note(model.camera))
end

local function log_dump(name)
	core.log("action", PREFIX .. "by " .. name .. ":\n" .. table.concat(dump_lines(), "\n"))
end

-- Writes y (and z) of `view` ("first" or "third") into every sibling and
-- re-applies the camera of every rider of one of them.
local function set_values(model, view, y, z)
	local ids = siblings(model)
	for _, id in ipairs(ids) do
		local camera = grug_mounts.MODELS[id].camera
		camera[view].y = y
		if z then camera[view].z = z end
	end
	local touched = {}
	for _, id in ipairs(ids) do touched[grug_mounts.MODELS[id]] = true end
	for name, record in pairs(grug_mounts.active) do
		local rider = core.get_player_by_name(name)
		if rider and touched[record.model] then grug_mounts.apply_camera(rider, record.model) end
	end
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
	params = "[<y> [<z>] | third <y> [<z>] | reset | dump | try <model>|off]",
	description = "0.45.1 probe: the riding camera of the mount you ride (nodes)",
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
		if w[1] == "reset" then
			local original = shipped[model_id(model)]
			set_values(model, "first", original.first.y, original.first.z)
			set_values(model, "third", original.third.y, original.third.z)
			log_dump(name)
			return true, PREFIX .. "shipped values: " .. describe(model)
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
