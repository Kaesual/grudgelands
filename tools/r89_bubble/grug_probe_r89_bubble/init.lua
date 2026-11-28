-- Disposable engine probe (Round 89 lane BUBBLE). Never shipped:
-- tools/r89_bubble/capture.py stages it through tools/luanti_headless.sh. It
-- reads one JSON request from <world>/r89bubble_in, does it inside the
-- server and answers in <world>/r89bubble_out (tools/r80_emote's method).
-- The ops build a small stage in the air above the first character's
-- arrival (a grass floor, a snow wall, a glass wall and a water pool), set
-- up one scene (positions, looks, cameras, shields, a mount, the time of
-- day, a look variant of the bubble) and report each player's bubble.

local IN = core.get_worldpath() .. "/r89bubble_in"
local OUT = core.get_worldpath() .. "/r89bubble_out"
local bubble = grug_core.shield_bubble

-- Every character owns Apprentice Riding (the mounted shot).
function grug_mounts.owned_tier_ids() return {1} end

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

local stage -- the stage's origin, set by OPS.stage

local OPS = {}

function OPS.status(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	local object, color = bubble.shown(request.name)
	local attach = object and {object:get_attach()}
	return {online = true,
		prepared = grug_core.world_preparation_status().ready,
		riding = grug_mounts.active[request.name] ~= nil,
		absorb = grug_core.get_absorb(player),
		bubble = object ~= nil, color = color,
		attached = attach and attach[1] == player or false,
		forced_visible = attach and attach[5] or false,
		stature = (player:get_properties().visual_size or {}).y,
		race = grug_core.get_player_race(request.name)}
end

-- Finishes character creation; done once the character has arrived.
function OPS.ready(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	if not grug_core.world_preparation_status().ready then return {prepared = false} end
	if player:get_meta():get_string("grug_classes:arriving") ~= "" then return {arriving = true} end
	if not grug_classes.get_class(player) then
		submit(player, {["faction_" .. request.faction] = "x"})
		submit(player, {["race_" .. request.race] = "x"})
		submit(player, {class_warrior = "Warrior"})
		submit(player, {create_character = "Create"})
		return {created = false}
	end
	core.close_formspec(request.name, "")
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	return {done = true}
end

local function fill(minp, maxp, node)
	for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
			for z = minp.z, maxp.z do
				core.set_node({x = x, y = y, z = z}, {name = node})
			end
		end
	end
end

local function at(dx, dy, dz)
	return {x = stage.x + dx, y = stage.y + dy, z = stage.z + dz}
end

-- The stage, 30 nodes above `name`'s position, out of every guard's view
-- range (14). Floor y = stage.y - 1. Spots (feet positions, viewers look
-- toward +z):
--   open  (0, 0, 0)    open floor, the sky and the far terrain behind
--   snow  (14, 0, 0)   a snow wall 3 nodes behind (z + 3)
--   glass (-14, 0, 0)  a glass wall 2 nodes in front (z - 2)
--   water (-14, 0, 12) feet in a pool one node deep (its floor y - 2)
function OPS.stage(request)
	local player = core.get_player_by_name(request.name)
	local pos = vector.round(player:get_pos())
	stage = {x = pos.x, y = pos.y + 30, z = pos.z}
	fill(at(-20, -2, -30), at(20, -2, 20), "default:dirt")
	fill(at(-20, -1, -30), at(20, -1, 20), "default:dirt_with_grass")
	fill(at(-20, 0, -30), at(20, 6, 20), "air")
	fill(at(10, 0, 3), at(18, 4, 3), "default:snowblock")
	fill(at(12, 0, 1), at(16, 0, 2), "default:snow")
	fill(at(-18, 0, -2), at(-10, 4, -2), "default:glass")
	fill(at(-17, -1, 10), at(-11, -1, 14), "default:water_source")
	return {stage = stage}
end

local function clear_shield(player)
	local absorb = grug_core.get_absorb(player)
	if absorb > 0 then
		-- The real soak takes them all; the hit points come back.
		player:set_hp(player:get_hp() - absorb - 1, {type = "set_hp", from = "mod"})
		player:set_hp(player:get_properties().hp_max, {type = "set_hp", from = "mod"})
	end
end

local VARIANT_DEFAULT = {textures = nil, mesh = bubble.MESH, glow = bubble.GLOW}

-- One scene: request.players = {{name, spot, offset = {x, y, z}, yaw (deg),
-- pitch (deg), camera, shields = {ids...}, mount = bool}}, request.time,
-- request.variant = {opacity = 0..255, mesh = name, glow = n, look = name}; a
-- look names the textures capture.sh writes into this probe
-- (grug_probe_r89_bubble_<look>_<colour>.png, gen_bubble.py --look).
function OPS.scene(request)
	core.set_timeofday(request.time or 0.5)
	for _, row in ipairs(request.players) do
		local player = core.get_player_by_name(row.name)
		local riding = grug_mounts.active[row.name] ~= nil
		if riding and not row.mount then
			grug_mounts.dismount(player, "manual", false)
		end
		clear_shield(player)
		local o = row.offset or {x = 0, y = 0, z = 0}
		local s = row.spot
		-- Feet on the floor: a standing player's feet are half a node below
		-- the centre of the air node above the floor.
		player:set_pos(at(s[1] + o.x, s[2] + o.y - 0.5, s[3] + o.z))
		player:set_look_horizontal(math.rad(row.yaw or 0))
		player:set_look_vertical(math.rad(row.pitch or 0))
		player:set_camera({mode = row.camera or "first"})
		if row.mount and not riding then
			local ok, why = grug_mounts.mount(player, 1)
			if not ok then return {error = "mount: " .. tostring(why)} end
		end
		for _, id in ipairs(row.shields or {}) do
			grug_core.add_absorb(player, id, 1, 600, player)
		end
	end
	-- The look variant, on every bubble of this scene.
	local variant = request.variant or {}
	for _, row in ipairs(request.players) do
		local object, color = bubble.shown(row.name)
		if object then
			local texture = bubble.TEXTURES[color]
			if variant.look then
				texture = "grug_probe_r89_bubble_" .. variant.look .. "_" .. color .. ".png"
			end
			if variant.opacity then texture = texture .. "^[opacity:" .. variant.opacity end
			object:set_properties({textures = {texture},
				mesh = variant.mesh or VARIANT_DEFAULT.mesh,
				glow = variant.glow or VARIANT_DEFAULT.glow})
		end
	end
	return {time = request.time or 0.5}
end

function OPS.shutdown()
	core.after(0.5, core.request_shutdown)
	return {}
end

local clock, last_id = 0, nil
core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < 0.1 then return end
	clock = 0
	local file = io.open(IN, "r")
	if not file then return end
	local text = file:read("*a")
	file:close()
	local request = core.parse_json(text, nil, true)
	if type(request) ~= "table" or request.id == last_id then return end
	last_id = request.id
	local ok, result = pcall(OPS[request.op], request)
	if not ok then result = {error = tostring(result)} end
	core.safe_file_write(OUT, core.write_json({id = request.id, result = result}))
end)
