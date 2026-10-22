-- The picked hood's headless shots (Round 56 lane HOODFINISH; a scene for
-- tools/r54_model/capture.sh, SCENE=tools/r56_hood/finish_scene.lua). The
-- shipped art as the game composes it (grug_visuals.compose in `setup`): a
-- human in the whole cloth or leather set at T1, T3 and T6. Per tier one row
-- from the front, the side and the back, and one row from the side with the
-- head nodding down 50 degrees, level and up 60 (the head look's clamp); the T6
-- sets also nod seen from behind. Then the T3 head piece of each line enchanted
-- (Strength prefix, zone A red; Dexterity suffix, zone B mint) from the side,
-- three quarters behind and behind, and a real bandit (the NPC model in cloth)
-- from the front, three quarters behind and behind. The camera looks along +z
-- from z -2.1, a little above head height; a figure at yaw pi faces it.
local PLAYER = "grug_visuals_character.b3d"
local PI = math.pi
local CAM = {0, 0.6, -2.1}
local WIDE = {0, 0.7, -3.4}
local SETS = {{"cloth", 1}, {"cloth", 3}, {"cloth", 6}, {"leather", 1}, {"leather", 3}, {"leather", 6}}

local scene = {shots = {}}
local function log(msg) core.log("action", "[r56hoodfinish] " .. msg) end

local function set_of(line, bracket)
	local armor = {}
	for _, slot in ipairs(grug_visuals.SLOTS) do
		armor[slot] = grug_gear.armor_item(slot, line, bracket)
	end
	return armor
end

-- The player's texture list: skin, cloak, armor, weapon, offhand, back, wings.
local function player_textures(spec)
	local r = grug_visuals.compose(spec)
	return {r.skin, grug_visuals.CLOAK_NONE, r.armor, grug_visuals.WEAPON_NONE,
		grug_visuals.OFFHAND_NONE, grug_visuals.BACK_NONE, grug_visuals.WINGS_NONE}
end

local function row(figs, mesh, textures, spacing, size, wield)
	local out = {}
	for i, f in ipairs(figs) do
		out[i] = {at = {(i - 2) * (spacing or 0.85), 0.5, 0}, yaw = f[1], head = f[2], frame = 0,
			mesh = mesh or PLAYER, textures = textures, size = size, wield = wield}
	end
	return out
end

-- A real NPC's drawn look: add it, read it, remove it (as tools/r54_art/scene.lua).
local function npc_look(name, pos)
	local obj = core.add_entity(pos, name)
	if not obj then
		log("npc " .. name .. ": add_entity failed")
		return nil
	end
	local props = obj:get_properties()
	local out = {mesh = props.mesh, textures = table.copy(props.textures),
		size = props.visual_size and props.visual_size.x or 1}
	log(("npc %s: mesh %s, %d textures {%s}, size %.2f"):format(name, out.mesh, #out.textures,
		table.concat(out.textures, ", "), out.size))
	obj:remove()
	return out
end

function scene.setup(player)
	local shots = scene.shots
	local function shot(name, cam, figures)
		shots[#shots + 1] = {name = name, cam = cam, pitch = 0.12, figures = figures}
	end
	for _, s in ipairs(SETS) do
		local name = ("%s_T%d"):format(s[1], s[2])
		local tex = player_textures({race = "human", armor = set_of(s[1], s[2])})
		shot(name .. "_front_side_back", CAM, row({{PI}, {PI / 2}, {0}}, PLAYER, tex))
		shot(name .. "_nod_side", CAM, row({{PI / 2, -50}, {PI / 2, 0}, {PI / 2, 60}}, PLAYER, tex))
		if s[2] == 6 then
			shot(name .. "_nod_back3q", CAM, row({{PI * 0.25, -50}, {PI * 0.25, 0}, {PI * 0.25, 60}}, PLAYER, tex))
		end
	end
	for _, line in ipairs({"cloth", "leather"}) do
		local tex = player_textures({race = "human", armor = set_of(line, 3),
			armor_enchant = {head = {prefix = "str", suffix = "dex"}}})
		shot(line .. "_T3_head_enchanted", CAM, row({{PI / 2}, {PI * 0.25}, {0}}, PLAYER, tex))
	end
	local bandit = npc_look("grug_mobs:bandit", vector.offset(player:get_pos(), 0, 44, 20))
	if bandit then
		shot("npc_bandit_cloth", WIDE, row({{PI}, {PI * 0.25}, {0}}, bandit.mesh, bandit.textures, 1.1,
			bandit.size, "grug_gear:dagger_iron"))
	end
end

return scene
