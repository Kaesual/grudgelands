-- The capture scene of Round 55 lane MODEL (tools/r55_model/capture.sh, run
-- through tools/r54_model/capture.sh's probe; format in
-- tools/r54_model/grug_probe_r54_model/init.lua): the offhand test art
-- (tools/r55_model/stand_in.py: the shield at size steps 0 and 2, the book,
-- the wings) set directly on the player and NPC models, in Stand, Walk,
-- Block, Cast 1 and Sit from the front, the left (the shield side) and three
-- quarters; close-ups for the orientation glyphs (F on the shield front, B
-- on its back, F/B on the covers, L on the left page); the back card with a
-- sword image; the wings on a test cloak; and the capture player's own model
-- as the game composes it today (4 textures on the 7-buffer model). The
-- camera looks along +z; a figure at yaw pi faces it, at pi/2 shows its left.
local PLAYER, NPC = "grug_visuals_character.b3d", "grug_visuals_npc.b3d"
local SKIN = "r54model_steel_skin.png"
local ARMOR = "r54model_steel_atlas.png"
local CLOAK = "grug_achievements_cloak_boaring_work_1.png"
local SWORD = "grug_gear_item_sword_steel.png"
local BOW = "grug_gear_bow_wood.png"
local SHIELD0, SHIELD2 = "r55model_shield0.png", "r55model_shield2.png"
local BOOK, WINGS = "r55model_book.png", "r55model_wings.png"
local B = "blank.png"
local PI = math.pi
-- engine frames: stand, walk (mid-stride), block (held), cast 1 (held), sit
local POSES = {{"stand", 0}, {"walk", 172}, {"block", 380}, {"cast1", 230}, {"sit", 100}}
local WIDE = {0, 0.5, -4.6}
local FAR = {0, 0.5, -3.4}
local NEAR = {0, 0.5, -1.9}

-- textures: player {skin, cloak, armor, weapon, offhand, back, wings}
local function player(t)
	return {SKIN, t.cloak or B, t.armor or B, B, t.offhand or B, t.back or B, t.wings or B}
end

local function poses_row(mesh, textures, yaw)
	local out = {}
	for i, pose in ipairs(POSES) do
		out[i] = {at = {(i - 3) * 1.4, 0.5, 0}, yaw = yaw, frame = pose[2], mesh = mesh, textures = textures}
	end
	return out
end

local function one(textures, frame, yaw, mesh)
	return {{at = {0, 0.5, 0}, yaw = yaw, frame = frame, mesh = mesh or PLAYER, textures = textures}}
end

local function three(textures, list)
	local out = {}
	for i, f in ipairs(list) do
		out[i] = {at = {(i - 2) * 1.4, 0.5, 0}, yaw = f[2], frame = f[1], mesh = f[3] or PLAYER,
			textures = f[4] or textures}
	end
	return out
end

local shots = {}
local function add(shot) shots[#shots + 1] = shot end

-- the three items in the five poses, from three sides
for _, item in ipairs({{"S0", SHIELD0}, {"S2", SHIELD2}, {"BK", BOOK}}) do
	local tex = player({offhand = item[2]})
	add({name = item[1] .. "_poses_front", cam = WIDE, pitch = 0.15, figures = poses_row(PLAYER, tex, PI)})
	add({name = item[1] .. "_poses_left", cam = WIDE, pitch = 0.15, figures = poses_row(PLAYER, tex, PI / 2)})
	add({name = item[1] .. "_poses_3q", cam = WIDE, pitch = 0.15, figures = poses_row(PLAYER, tex, PI * 0.75)})
end

-- orientation close-ups: the shield (size 2) and the book
local s2, bk = player({offhand = SHIELD2}), player({offhand = BOOK})
add({name = "O1_shield_close_left", cam = NEAR, pitch = 0.3, figures = one(s2, 0, PI / 2)})
add({name = "O2_shield_close_front", cam = NEAR, pitch = 0.3, figures = one(s2, 0, PI)})
add({name = "O3_shield_close_block_front", cam = NEAR, pitch = 0.3, figures = one(s2, 380, PI)})
add({name = "O4_shield_close_back_inner", cam = NEAR, pitch = 0.3, figures = one(s2, 0, PI * 0.25)})
add({name = "O5_book_close_left", cam = NEAR, pitch = 0.3, figures = one(bk, 0, PI / 2)})
add({name = "O6_book_close_3q", cam = NEAR, pitch = 0.3, figures = one(bk, 0, PI * 0.75)})
add({name = "O7_book_close_above", cam = {0, 2.2, -1.2}, pitch = 0.9, figures = one(bk, 0, PI * 0.75)})
add({name = "O8_book_close_outer_back", cam = NEAR, pitch = 0.3, figures = one(bk, 0, PI * 0.35)})

-- the back card with a sword image (and a bow), with and without a cloak
local sword = player({back = SWORD})
add({name = "K1_back_sword_back_side_walk", cam = FAR, pitch = 0.18, figures = three(sword,
	{{0, 0}, {0, PI / 2}, {172, PI * 0.25}})})
add({name = "K2_back_sword_cloak_back_side_walk", cam = FAR, pitch = 0.18,
	figures = three(player({back = SWORD, cloak = CLOAK}), {{0, 0}, {0, PI / 2}, {172, PI * 0.25}})})
add({name = "K3_back_close_back", cam = NEAR, pitch = 0.2, figures = one(player({back = BOW}), 0, 0)})

-- the wings on a test cloak
local winged = player({cloak = CLOAK, wings = WINGS})
add({name = "W1_wings_back_side_front3q", cam = FAR, pitch = 0.18, figures = three(winged,
	{{0, 0}, {0, PI / 2}, {0, PI * 0.75}})})
add({name = "W2_wings_walk_back3q_side_sit", cam = FAR, pitch = 0.18, figures = three(winged,
	{{172, PI * 0.25}, {182, -PI / 2}, {100, PI / 2}})})
add({name = "W3_wings_close_back", cam = NEAR, pitch = 0.2, figures = one(winged, 0, 0)})

-- with the armor (metal, steel palette): clearance by eye
add({name = "A1_armor_shield_book_stand_block_3q", cam = FAR, pitch = 0.18, figures = three(nil, {
	{0, PI * 0.75, PLAYER, player({armor = ARMOR, offhand = SHIELD2})},
	{380, PI * 0.75, PLAYER, player({armor = ARMOR, offhand = SHIELD2})},
	{230, PI * 0.75, PLAYER, player({armor = ARMOR, offhand = BOOK})}})})

-- the NPC model: {skin, armor, weapon, offhand, back}
local npc_s = {SKIN, ARMOR, B, SHIELD2, SWORD}
add({name = "N1_npc_shield_front_walk_back", cam = FAR, pitch = 0.18, figures = three(npc_s,
	{{0, PI, NPC}, {172, PI / 2, NPC}, {0, 0, NPC}})})

-- the game as it is today (GAME not merged): the capture player's own model
-- and textures
add({name = "G1_unchanged_game_front_3q_walk", cam = FAR, pitch = 0.18, figures = {
	{at = {-1.4, 0.5, 0}, yaw = PI, frame = 0, mirror = true},
	{at = {0, 0.5, 0}, yaw = PI * 0.75, frame = 0, mirror = true},
	{at = {1.4, 0.5, 0}, yaw = PI * 0.25, frame = 172, mirror = true},
}})

return {shots = shots}
