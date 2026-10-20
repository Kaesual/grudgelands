-- The default scene of grug_probe_r54_model (Round 54 lane MODEL): the
-- player and NPC models with metal T6 test art baked naively into the atlas
-- (tools/r54_model/naive_atlas.py; capture.sh writes the r54model_* textures),
-- standing and mid-walk from several sides, the weapon card beside the
-- world's wield entity, and the capture player's own look as the game
-- composes it. The camera looks along +z from z -3.4 (eye 1.47 above the
-- floor); a figure at yaw pi faces it.
local PLAYER, NPC = "grug_visuals_character.b3d", "grug_visuals_npc.b3d"
local STEEL = {"r54model_steel_skin.png", "blank.png", "r54model_steel_atlas.png", "blank.png"}
local T6 = {"r54model_T6_skin.png", "blank.png", "r54model_T6_atlas.png", "blank.png"}
local CLOAK = "grug_achievements_cloak_boaring_work_1.png"
local SWORD = "grug_gear_item_sword_steel.png"
local PI = math.pi
local STAND, WALK, WALK_OTHER = 0, 172, 182
local FAR = {0, 0.5, -3.4}
local NEAR = {0, 0.5, -2.0}

local function with(textures, slot, image)
	local out = {}
	for i, t in ipairs(textures) do out[i] = t end
	out[slot] = image
	return out
end

local function row(mesh, textures, frame, yaws)
	local out = {}
	for i, yaw in ipairs(yaws) do
		out[i] = {at = {(i - 2) * 1.4, 0.5, 0}, yaw = yaw, frame = frame, mesh = mesh, textures = textures}
	end
	return out
end

local function one(mesh, textures, frame, yaw)
	return {{at = {0, 0.5, 0}, yaw = yaw, frame = frame, mesh = mesh, textures = textures}}
end

local npc_steel = {STEEL[1], STEEL[3], STEEL[4]}

return {
	shots = {
		-- orientation (steel palette: the test art's letters read better)
		{name = "A1_stand_front_side_3q", cam = FAR, pitch = 0.18,
			figures = row(PLAYER, STEEL, STAND, {PI, PI / 2, PI * 0.75})},
		{name = "A2_stand_back_otherside_back3q", cam = FAR, pitch = 0.18,
			figures = row(PLAYER, STEEL, STAND, {0, -PI / 2, PI * 0.25})},
		{name = "A3_walk_front_side_3q", cam = FAR, pitch = 0.18,
			figures = row(PLAYER, STEEL, WALK, {PI, PI / 2, PI * 0.75})},
		{name = "A4_walk_back_otherside_back3q", cam = FAR, pitch = 0.18,
			figures = row(PLAYER, STEEL, WALK_OTHER, {0, -PI / 2, PI * 0.25})},
		{name = "C1_close_front", cam = NEAR, pitch = 0.3, figures = one(PLAYER, STEEL, STAND, PI)},
		{name = "C2_close_3q", cam = NEAR, pitch = 0.3, figures = one(PLAYER, STEEL, STAND, PI * 0.75)},
		{name = "C3_close_back", cam = NEAR, pitch = 0.3, figures = one(PLAYER, STEEL, STAND, 0)},
		{name = "C4_close_side", cam = NEAR, pitch = 0.3, figures = one(PLAYER, STEEL, STAND, PI / 2)},
		-- the tier's own palette
		{name = "T1_T6_front_3q_walk", cam = FAR, pitch = 0.18, figures = {
			{at = {-1.4, 0.5, 0}, yaw = PI, frame = STAND, mesh = PLAYER, textures = T6},
			{at = {0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mesh = PLAYER, textures = T6},
			{at = {1.4, 0.5, 0}, yaw = PI * 0.75, frame = WALK, mesh = PLAYER, textures = T6},
		}},
		-- the cloak behind the back panel
		{name = "K1_cloak_back_side_walk", cam = FAR, pitch = 0.18, figures = {
			{at = {-1.4, 0.5, 0}, yaw = 0, frame = STAND, mesh = PLAYER, textures = with(STEEL, 2, CLOAK)},
			{at = {0, 0.5, 0}, yaw = PI / 2, frame = STAND, mesh = PLAYER, textures = with(STEEL, 2, CLOAK)},
			{at = {1.4, 0.5, 0}, yaw = PI / 2, frame = WALK, mesh = PLAYER, textures = with(STEEL, 2, CLOAK)},
		}},
		-- the NPC model
		{name = "N1_npc_front_side_walk_3q", cam = FAR, pitch = 0.18, figures = {
			{at = {-1.4, 0.5, 0}, yaw = PI, frame = STAND, mesh = NPC, textures = npc_steel},
			{at = {0, 0.5, 0}, yaw = PI / 2, frame = WALK, mesh = NPC, textures = npc_steel},
			{at = {1.4, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mesh = NPC, textures = npc_steel},
		}},
		-- the weapon card (left), the world's wield entity (middle), both (right)
		{name = "W1_card_vs_wield_side", cam = NEAR, pitch = 0.3, figures = {
			{at = {-1.0, 0.5, 0}, yaw = PI / 2, frame = STAND, mesh = PLAYER, textures = with(STEEL, 4, SWORD)},
			{at = {0, 0.5, 0}, yaw = PI / 2, frame = STAND, mesh = PLAYER, textures = STEEL,
				wield = "grug_gear:sword_steel"},
			{at = {1.0, 0.5, 0}, yaw = PI / 2, frame = STAND, mesh = PLAYER, textures = with(STEEL, 4, SWORD),
				wield = "grug_gear:sword_steel"},
		}},
		{name = "W2_card_vs_wield_3q", cam = NEAR, pitch = 0.3, figures = {
			{at = {-1.0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mesh = PLAYER, textures = with(STEEL, 4, SWORD)},
			{at = {0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mesh = PLAYER, textures = STEEL,
				wield = "grug_gear:sword_steel"},
			{at = {1.0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mesh = PLAYER, textures = with(STEEL, 4, SWORD),
				wield = "grug_gear:sword_steel"},
		}},
		-- the game as it is: the capture player's own model and textures
		{name = "G1_unchanged_game_front_3q_walk", cam = FAR, pitch = 0.18, figures = {
			{at = {-1.4, 0.5, 0}, yaw = PI, frame = STAND, mirror = true},
			{at = {0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mirror = true},
			{at = {1.4, 0.5, 0}, yaw = PI * 0.75, frame = WALK, mirror = true},
		}},
	},
}
