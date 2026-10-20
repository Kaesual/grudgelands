-- Round 54 lane INTEG's scene for the MODEL capture probe
-- (SCENE=tools/r54_art/scene.lua tools/r54_model/capture.sh OUT_DIR): the
-- picked armor art as the game composes it (format: the probe's init.lua).
--
-- Per line T1, T3 and T6 side by side on two races (all six races over the
-- three lines): standing from the front, walking from three quarters, from
-- the back. Then metal T3 plain, with an enchanted chest and with broken
-- legs; armored NPCs as the real entities draw them; the capture player
-- after the real equip and apply (`mirror`); and last the inventory icons of
-- all 72 pieces in a grid (a formspec shown while that shot is taken), with
-- an enchanted and a broken icon and the Character page's slot ghosts.
-- Everything is composed by the real grug_visuals.compose in `setup`.
local PLAYER = "grug_visuals_character.b3d"
local PI = math.pi
local STAND, WALK = 0, 172
local FAR = {0, 0.5, -3.6}
local WIDE = {0, 0.9, -5.4}
local NEAR = {0, 0.5, -2.0}
local LINES = {
	{line = "metal", races = {"human", "troll"}},
	{line = "leather", races = {"elf", "orc"}},
	{line = "cloth", races = {"dwarf", "undead"}},
}
local TIERS = {1, 3, 6}
local ICONS_AFTER = "G1_applied_player_front_3q_walk"

local scene = {shots = {}}
local function log(msg) core.log("action", "[r54model] " .. msg) end

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
	local out = {mesh = props.mesh, textures = table.copy(props.textures),
		size = props.visual_size and props.visual_size.x or 1}
	log(("npc %s: mesh %s, %d textures, size %.2f"):format(name, out.mesh, #out.textures, out.size))
	obj:remove()
	return out
end

-- The icon grid: a column per line and slot, a row per tier; below it the
-- metal T3 icons enchanted (Strength prefix, Dexterity suffix) and broken,
-- and the four slot ghosts as the Character page draws them.
local function icon_formspec()
	local fs = {"formspec_version[6]size[16.4,10.2]bgcolor[#202024;true]",
		"style_type[label;font_size=*1.1]"}
	local x0, y0, step = 1.4, 0.9, 1.2
	local col = 0
	for _, entry in ipairs(LINES) do
		for _, slot in ipairs(grug_visuals.SLOTS) do
			local x = x0 + col * step
			fs[#fs + 1] = ("label[%.2f,0.5;%s]"):format(x, entry.line:sub(1, 1) .. " " .. slot)
			for bracket = 1, 6 do
				fs[#fs + 1] = ("item_image[%.2f,%.2f;1,1;%s]"):format(x, y0 + (bracket - 1) * step,
					grug_gear.armor_item(slot, entry.line, bracket))
			end
			col = col + 1
		end
	end
	for bracket = 1, 6 do
		fs[#fs + 1] = ("label[0.3,%.2f;T%d]"):format(y0 + (bracket - 1) * step + 0.5, bracket)
	end
	local y = y0 + 6 * step + 0.3
	fs[#fs + 1] = ("label[0.3,%.2f;metal T3: enchanted | broken | slot ghosts]"):format(y)
	for i, slot in ipairs(grug_visuals.SLOTS) do
		local def = core.registered_items[grug_gear.armor_item(slot, "metal", 3)]
		local image = def.inventory_image
		local x = x0 + (i - 1) * step
		fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(x, y + 0.4,
			core.formspec_escape(grug_gear.enchant_image(image, "str", "dex")))
		fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(x + 4 * step, y + 0.4,
			core.formspec_escape("(" .. image .. ")" .. grug_gear.BROKEN_MODIFIER))
		fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(x + 8 * step, y + 0.4,
			core.formspec_escape("grug_gear_item_" .. slot .. "_metal.png^[multiply:#666666"))
	end
	return table.concat(fs)
end

-- Shown once the probe has moved past ICONS_AFTER (its ack file names the
-- shot it is done with), i.e. while the last shot settles.
local shown = false
core.register_globalstep(function()
	if shown then return end
	local file = io.open(core.get_worldpath() .. "/r54model_ack", "r")
	if not file then return end
	local ack = file:read("*l") or ""
	file:close()
	if ack == ICONS_AFTER then
		shown = true
		core.show_formspec("grugcap", "r54integ:icons", icon_formspec())
		log("icon grid shown")
	end
end)

function scene.setup(player)
	local shots = scene.shots
	local function shot(name, cam, pitch, figures)
		shots[#shots + 1] = {name = name, cam = cam, pitch = pitch, figures = figures}
	end

	for _, entry in ipairs(LINES) do
		local a, b = entry.races[1], entry.races[2]
		local look = {}
		for _, race in ipairs(entry.races) do
			look[race] = {}
			for i, bracket in ipairs(TIERS) do
				look[race][i] = player_textures({race = race, armor = set_of(entry.line, bracket)})
			end
		end
		local L = entry.line
		shot(("%s_S_T1_T3_T6_%s_front"):format(L, a), FAR, 0.18, {
			fig(-1.4, PI, STAND, PLAYER, look[a][1]), fig(0, PI, STAND, PLAYER, look[a][2]),
			fig(1.4, PI, STAND, PLAYER, look[a][3])})
		shot(("%s_W_T1_T3_T6_%s_walk_3q"):format(L, b), FAR, 0.18, {
			fig(-1.4, PI * 0.75, WALK, PLAYER, look[b][1]), fig(0, PI * 0.75, WALK, PLAYER, look[b][2]),
			fig(1.4, PI * 0.75, WALK, PLAYER, look[b][3])})
		shot(("%s_B_T1_T3_T6_%s_back_walk"):format(L, b), FAR, 0.18, {
			fig(-1.4, 0, STAND, PLAYER, look[b][1]), fig(0, 0, STAND, PLAYER, look[b][2]),
			fig(1.4, PI * 0.25, WALK, PLAYER, look[b][3])})
	end

	-- Metal T3 plain (left), the chest with a Strength prefix (red) and a
	-- Dexterity suffix (mint) (middle), the legs broken (right).
	local t3 = set_of("metal", 3)
	local plain = player_textures({race = "human", armor = t3})
	local enchanted = player_textures({race = "human", armor = t3,
		armor_enchant = {chest = {prefix = "str", suffix = "dex"}}})
	local broken = player_textures({race = "human", armor = t3, armor_broken = {legs = true}})
	shot("E1_metal_T3_plain_enchanted_chest_broken_legs", FAR, 0.18, {
		fig(-1.4, PI, STAND, PLAYER, plain), fig(0, PI, STAND, PLAYER, enchanted),
		fig(1.4, PI, STAND, PLAYER, broken)})
	shot("E2_enchanted_chest_close", NEAR, 0.3, {fig(0, PI * 0.85, STAND, PLAYER, enchanted)})
	shot("E3_broken_legs_close", NEAR, 0.3, {fig(0, PI * 0.85, STAND, PLAYER, broken)})

	-- Armored NPCs, as the game draws them.
	local off = vector.offset(player:get_pos(), 0, 44, 20)
	local guard = npc_look("grug_mobs:guard_accord", off)
	local bandit = npc_look("grug_mobs:bandit", off)
	local king = npc_look("grug_mobs:king_orc", off)
	local figures = {}
	for _, f in ipairs({
		guard and fig(-1.8, PI, STAND, guard.mesh, guard.textures, guard.size, "grug_gear:sword_steel"),
		bandit and fig(0, PI * 0.75, WALK, bandit.mesh, bandit.textures, bandit.size, "grug_gear:dagger_iron"),
		king and fig(2.0, PI, STAND, king.mesh, king.textures, king.size, "grug_gear:greataxe_abyssal_steel"),
	}) do
		if f then figures[#figures + 1] = f end
	end
	shot("N1_guard_bandit_king", WIDE, 0.08, figures)

	-- The real player path: equip leather T6 and a sword, apply, mirror.
	local inv = player:get_inventory()
	for slot, item in pairs(set_of("leather", 6)) do
		inv:set_stack("grug_" .. slot, 1, ItemStack(item))
	end
	inv:set_stack("grug_weapon", 1, ItemStack("grug_gear:sword_abyssal_steel"))
	grug_visuals.apply(player)
	shot(ICONS_AFTER, FAR, 0.18, {
		{at = {-1.4, 0.5, 0}, yaw = PI, frame = STAND, mirror = true},
		{at = {0, 0.5, 0}, yaw = PI * 0.75, frame = STAND, mirror = true},
		{at = {1.4, 0.5, 0}, yaw = PI * 0.75, frame = WALK, mirror = true}})

	-- The icon grid (the formspec above covers the studio).
	shot("I1_icons_grid", FAR, 0.18, {})
end

return scene
