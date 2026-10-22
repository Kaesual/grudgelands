-- The hood's headless shots (Round 56 lane HOOD; a scene for
-- tools/r54_model/capture.sh, staged as the probe's scene.lua, with the media
-- of tools/r56_hood/shots.py passed as MODELS). The cloth and leather head
-- pieces at T1, T3 and T6 and the metal T3 helm on the player model: the
-- shipped head layer (with its chin strip) and, on cloth and leather, the
-- placeholder hood over it (test art, never shipped). Per piece one row from
-- the front, the side and the back, and one row from the side with the head
-- nodding down 50 degrees, level and up 60 (the head look's clamp); the T6
-- pieces also nod seen from behind. The camera looks along +z from z -2.1,
-- a little above head height; a figure at yaw pi faces it.
local PLAYER = "grug_visuals_character.b3d"
local PI = math.pi
local CAM = {0, 0.6, -2.1}
local PIECES = {
	{"cloth_T1", "grug_armor_cloth_patch_head.png", "r56hood_cloth_T1.png"},
	{"cloth_T3", "grug_armor_cloth_heavy_head.png", "r56hood_cloth_T3.png"},
	{"cloth_T6", "grug_armor_cloth_stormweave_head.png", "r56hood_cloth_T6.png"},
	{"leather_T1", "grug_armor_leather_light_head.png", "r56hood_leather_T1.png"},
	{"leather_T3", "grug_armor_leather_heavy_head.png", "r56hood_leather_T3.png"},
	{"leather_T6", "grug_armor_leather_nightscale_head.png", "r56hood_leather_T6.png"},
	{"metal_T3", "grug_armor_metal_steel_head.png", nil},
}

local function textures(layer, hood)
	return {"r56hood_human_bald.png", "blank.png", hood and (layer .. "^" .. hood) or layer,
		"blank.png", "blank.png", "blank.png", "blank.png"}
end

local function row(tex, figs)
	local out = {}
	for i, f in ipairs(figs) do
		out[i] = {at = {(i - 2) * 0.85, 0.5, 0}, yaw = f[1], head = f[2], frame = 0, mesh = PLAYER,
			textures = tex}
	end
	return out
end

local shots = {}
for _, p in ipairs(PIECES) do
	local tex = textures(p[2], p[3])
	shots[#shots + 1] = {name = p[1] .. "_front_side_back", cam = CAM, pitch = 0.12,
		figures = row(tex, {{PI}, {PI / 2}, {0}})}
	shots[#shots + 1] = {name = p[1] .. "_nod_side", cam = CAM, pitch = 0.12,
		figures = row(tex, {{PI / 2, -50}, {PI / 2, 0}, {PI / 2, 60}})}
	if p[1]:find("T6") then
		shots[#shots + 1] = {name = p[1] .. "_nod_back3q", cam = CAM, pitch = 0.12,
			figures = row(tex, {{PI * 0.25, -50}, {PI * 0.25, 0}, {PI * 0.25, 60}})}
	end
end

return {shots = shots}
