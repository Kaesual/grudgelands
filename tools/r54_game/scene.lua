-- Round 54 lane GAME's scene for the MODEL capture probe
-- (tools/r54_model/capture.sh, SCENE=tools/r54_game/scene.lua): the game's
-- own composition on the new models, with the baked test art.
--
-- Players are composed by the real grug_visuals.compose (metal T6, cloth
-- T1, an enchanted and a broken piece) and the capture player itself after
-- the real equip and apply (`mirror`). NPCs are the REAL entities: each is
-- added once off the studio, its mesh, textures and visual size are read
-- after its activation (definition mesh, apply_entity, level and elite or
-- boss tint) and it is removed; the figures wear exactly that. Everything is
-- built in `setup`, after the armor index exists. The camera looks along +z;
-- a figure at yaw pi faces it.
local PLAYER = "grug_visuals_character.b3d"
local PI = math.pi
local STAND, WALK = 0, 172
local FAR = {0, 0.5, -3.6}
local WIDE = {0, 0.9, -5.4}
local NEAR = {0, 0.5, -2.0}

local scene = {shots = {}}
local function log(msg) core.log("action", "[r54model] " .. msg) end

-- A composed player look on the player model.
local function player_textures(spec)
	local r = grug_visuals.compose(spec)
	return {r.skin, grug_visuals.CLOAK_NONE, r.armor, grug_visuals.WEAPON_NONE}
end

local function set_of(line, bracket)
	local armor = {}
	for _, slot in ipairs(grug_visuals.SLOTS) do
		armor[slot] = grug_gear.armor_item(slot, line, bracket)
	end
	return armor
end

local function fig(x, yaw, frame, mesh, textures, size, wield)
	return {at = {x, 0.5, 0}, yaw = yaw, frame = frame, mesh = mesh, textures = textures,
		size = size, wield = wield}
end

-- A real NPC's drawn look: add it, read it, remove it.
local function npc_look(name, pos)
	local obj = core.add_entity(pos, name)
	if not obj then
		log("npc " .. name .. ": add_entity failed")
		return nil
	end
	local props = obj:get_properties()
	local ent = obj:get_luaentity()
	local out = {mesh = props.mesh, textures = table.copy(props.textures),
		size = props.visual_size and props.visual_size.x or 1,
		tier = ent and ent._grug_tier, level = ent and ent._grug_level}
	log(("npc %s: mesh %s, %d textures, size %.2f, tier %s, level %s"):format(name, out.mesh,
		#out.textures, out.size, tostring(out.tier), tostring(out.level)))
	obj:remove()
	return out
end

function scene.setup(player)
	local shots = scene.shots
	local function shot(name, cam, pitch, figures)
		shots[#shots + 1] = {name = name, cam = cam, pitch = pitch, figures = figures}
	end

	-- Players: metal T6 and cloth T1 on three races each, standing and walking.
	local t6 = {}
	for i, race in ipairs({"human", "dwarf", "troll"}) do
		t6[i] = player_textures({race = race, armor = set_of("metal", 6)})
	end
	shot("P1_metal_T6_human_dwarf_troll_front", FAR, 0.18, {
		fig(-1.4, PI, STAND, PLAYER, t6[1]), fig(0, PI, STAND, PLAYER, t6[2]),
		fig(1.4, PI, STAND, PLAYER, t6[3])})
	shot("P2_metal_T6_3q_side_walk", FAR, 0.18, {
		fig(-1.4, PI * 0.75, STAND, PLAYER, t6[1]), fig(0, PI / 2, WALK, PLAYER, t6[2]),
		fig(1.4, PI * 0.75, WALK, PLAYER, t6[3])})
	local t1 = {}
	for i, race in ipairs({"elf", "orc", "undead"}) do
		t1[i] = player_textures({race = race, armor = set_of("cloth", 1)})
	end
	shot("P3_cloth_T1_elf_orc_undead_front", FAR, 0.18, {
		fig(-1.4, PI, STAND, PLAYER, t1[1]), fig(0, PI, STAND, PLAYER, t1[2]),
		fig(1.4, PI, STAND, PLAYER, t1[3])})
	shot("P4_cloth_T1_3q_side_walk", FAR, 0.18, {
		fig(-1.4, PI * 0.75, STAND, PLAYER, t1[1]), fig(0, PI / 2, WALK, PLAYER, t1[2]),
		fig(1.4, PI * 0.75, WALK, PLAYER, t1[3])})

	-- Enchanted and broken: metal T3 plain (left), the chest with a Strength
	-- prefix (red) and a Dexterity suffix (mint) (middle), the legs broken
	-- (right).
	local t3 = set_of("metal", 3)
	local plain = player_textures({race = "human", armor = t3})
	local enchanted = player_textures({race = "human", armor = t3,
		armor_enchant = {chest = {prefix = "str", suffix = "dex"}}})
	local broken = player_textures({race = "human", armor = t3, armor_broken = {legs = true}})
	shot("E1_T3_plain_enchanted_chest_broken_legs", FAR, 0.18, {
		fig(-1.4, PI, STAND, PLAYER, plain), fig(0, PI, STAND, PLAYER, enchanted),
		fig(1.4, PI, STAND, PLAYER, broken)})
	shot("E2_enchanted_chest_close", NEAR, 0.3, {fig(0, PI * 0.85, STAND, PLAYER, enchanted)})
	shot("E3_broken_legs_close", NEAR, 0.3, {fig(0, PI * 0.85, STAND, PLAYER, broken)})

	-- NPCs, as the game draws them.
	local off = vector.offset(player:get_pos(), 0, 44, 20)
	local npc = {
		guard = npc_look("grug_mobs:guard_accord", off),
		bandit = npc_look("grug_mobs:bandit", off),
		commander = npc_look("grug_mobs:commander_throng", off),
		king = npc_look("grug_mobs:king_orc", off),
		royal = npc_look("grug_mobs:royal_guard_orc", off),
		general_guard = npc_look("grug_mobs:royal_guard_human", off),
	}
	local function npc_fig(x, yaw, frame, look, wield)
		if not look then return nil end
		return fig(x, yaw, frame, look.mesh, look.textures, look.size, wield)
	end
	local function figures(list)
		local out = {}
		for _, f in ipairs(list) do if f then out[#out + 1] = f end end
		return out
	end
	shot("N1_guard_bandit_commander_front", WIDE, 0.12, figures({
		npc_fig(-1.6, PI, STAND, npc.guard, "grug_gear:sword_steel"),
		npc_fig(0, PI, STAND, npc.bandit, "grug_gear:dagger_iron"),
		npc_fig(1.8, PI, STAND, npc.commander, "grug_gear:sword_abyssal_steel")}))
	shot("N2_guard_bandit_commander_walk_3q", WIDE, 0.12, figures({
		npc_fig(-1.6, PI * 0.75, WALK, npc.guard, "grug_gear:sword_steel"),
		npc_fig(0, PI / 2, WALK, npc.bandit, "grug_gear:dagger_iron"),
		npc_fig(1.8, PI * 0.75, WALK, npc.commander, "grug_gear:sword_abyssal_steel")}))
	shot("N3_king_royalguard_orc_humanroyal_front", WIDE, 0.05, figures({
		npc_fig(-2.0, PI, STAND, npc.king, "grug_gear:greataxe_abyssal_steel"),
		npc_fig(0, PI, STAND, npc.royal, "grug_gear:sword_abyssal_steel"),
		npc_fig(2.0, PI, STAND, npc.general_guard, "grug_gear:sword_abyssal_steel")}))
	shot("N4_king_royalguard_walk_3q", WIDE, 0.05, figures({
		npc_fig(-2.0, PI * 0.75, WALK, npc.king, "grug_gear:greataxe_abyssal_steel"),
		npc_fig(0, PI / 2, WALK, npc.royal, "grug_gear:sword_abyssal_steel"),
		npc_fig(2.0, 0, STAND, npc.general_guard, "grug_gear:sword_abyssal_steel")}))

	-- Since the user's ruling of 2026-10-20 the royals carry no tier tint.
	shot("N5_king_royalguards_untinted_front", WIDE, 0.05, figures({
		npc_fig(-2.0, PI, STAND, npc.king, "grug_gear:greataxe_abyssal_steel"),
		npc_fig(0, PI * 0.85, STAND, npc.royal, "grug_gear:sword_abyssal_steel"),
		npc_fig(2.0, PI, STAND, npc.general_guard, "grug_gear:sword_abyssal_steel")}))

	-- The tints over the armor: the guard plain (its own tier), with the
	-- elite and with the boss tint of grug_mobs/levels.lua on every texture.
	if npc.guard then
		local function tinted(tint)
			local out = {}
			for i, t in ipairs(npc.guard.textures) do out[i] = t .. "^[colorize:" .. tint end
			return out
		end
		local g = npc.guard
		shot("X1_guard_plain_elite_boss_tint", FAR, 0.18, {
			fig(-1.4, PI, STAND, g.mesh, g.textures, 1),
			fig(0, PI, STAND, g.mesh, tinted("#ffa800:80"), 1),
			fig(1.4, PI, STAND, g.mesh, tinted("#a64dff:90"), 1)})
	end

	-- The real player path: equip metal T6 and a sword, apply, mirror.
	local inv = player:get_inventory()
	for slot, item in pairs(set_of("metal", 6)) do
		inv:set_stack("grug_" .. slot, 1, ItemStack(item))
	end
	inv:set_stack("grug_weapon", 1, ItemStack("grug_gear:sword_abyssal_steel"))
	grug_visuals.apply(player)
	local own = player:get_properties()
	log(("mirror: mesh %s, %d textures"):format(own.mesh, #own.textures))
	shot("G1_applied_player_front_3q_walk", FAR, 0.18, {
		{at = {-1.4, 0.5, 0}, yaw = PI, frame = STAND, mirror = true},
		{at = {0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mirror = true},
		{at = {1.4, 0.5, 0}, yaw = PI * 0.75, frame = WALK, mirror = true}})
end

return scene
