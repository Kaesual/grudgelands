-- Round 55 lane WEB: the two test characters of the kaesual offhand addendum,
-- as the game composes them with the offhand look ON (the setting
-- grug_offhand_visuals, as after the finish step), and the capture scene that
-- photographs them.
--
-- Loads the real game files through the web export's loader
-- (tools/web_data/build.lua) and composes with the game's own functions
-- (grug_visuals.compose, appearance, appearance_json, back_card), the gear of
-- tools/r55_game's capture probe, so its Character tab shots show the same
-- characters (except the enchant colours there):
--   * a Warrior: a human in the metal line's top tier (abyssal steel) on
--     every slot, an abyssal steel sword in the main hand and an abyssal
--     steel shield in the offhand, enchanted (prefix Strength, suffix
--     Dexterity: the enchant colours in textures.offhand), no cloak;
--   * a Scout: a human in the leather line's bracket 4 on every slot, the
--     bracket 4 bow in the main hand (the Weapon slot), the bracket 4 sword in
--     the offhand (the Melee slot) and the plain grey cloak.
-- Writes
--   tools/r55_web/test_warrior.json  the stored appearance values, exactly as
--   tools/r55_web/test_scout.json    the game writes them to player meta with
--                                    the setting on (with it off, offhand
--                                    and wings are "none");
--   tools/r55_web/scene.lua          the scene for tools/r55_web/capture.sh:
--                                    the exported .glb beside the game's
--                                    .b3d with the seven textures a website
--                                    draws (the back card by the README's
--                                    rule: the bow in the hand, the blade on
--                                    the card), and the game's look of the
--                                    Warrior with the hand entity.
--
--   luajit tools/r55_web/gen_test_characters.lua           # rewrite all three
--   luajit tools/r55_web/gen_test_characters.lua --check   # exit 1 if stale

local ROOT, mode = ".", "write"
for _, value in ipairs(arg or {}) do
	if value == "--check" then mode = "check" else ROOT = value end
end
local DIR = ROOT .. "/tools/r55_web/"

local web_data = dofile(ROOT .. "/tools/web_data/build.lua")
web_data.build(ROOT)
local gv = grug_visuals
local items = core.registered_items
gv.index_armor(items)
gv.OFFHAND_VISUALS = true

local function group(name, g)
	local d = items[name]
	return d and d.groups and d.groups[g] or 0
end

-- A hand slot as apply.lua stores it for a plain stack (grug_visuals.hand_image
-- without stack meta: the definition's images).
-- An enchanted stack carries its coloured inventory image in its meta
-- (grug_items.refresh_enchant_image), which hand_image falls back to.
local function hand(name, enchant)
	local def = assert(items[name], "gen_test_characters: unknown " .. name)
	local image = def._grug_world_wield_image or def.wield_image or def.inventory_image
	local ids = {}
	if enchant then
		ids = {enchant.prefix, enchant.suffix}
		image = grug_gear.enchant_image(def.inventory_image, enchant.prefix, enchant.suffix)
	end
	return {item = name, broken = false, enchant = ids,
		pose = gv.pose_for(name, group, def._grug_wield_pose), image = image}
end

local function character(c)
	local armor, worn = {}, {}
	for _, slot in ipairs(gv.SLOTS) do
		local name = grug_gear.armor_item(slot, c.line, c.bracket)
		assert(gv.armor_appearance[name], "gen_test_characters: unknown " .. tostring(name))
		armor[slot] = name
		worn[slot] = {name = name, affixes = {}}
	end
	local spec = {race = "human", armor = armor, worn = worn,
		armor_enchant = gv.armor_enchants(worn), offhand_item = c.offhand,
		offhand_enchant = c.offhand_enchant}
	local result = gv.compose(spec)
	local data = gv.appearance(spec, result, c.cloak_texture, c.cloak_id)
	data.slots.mainhand = hand(c.mainhand)
	data.slots.offhand = hand(c.offhand, c.offhand_enchant)
	local json = gv.appearance_json(data)
	assert(#json <= gv.APPEARANCE_JSON_MAX, "gen_test_characters: over the JSON cap")
	return data, json
end

local warrior, warrior_json = character({line = "metal", bracket = 6,
	mainhand = grug_gear.weapon_item("sword", 6), offhand = "grug_gear:shield_" ..
		grug_gear.MATERIALS[6].metal.key, offhand_enchant = {prefix = "str", suffix = "dex"}})
local scout, scout_json = character({line = "leather", bracket = 4,
	mainhand = grug_gear.weapon_item("bow", 4), offhand = grug_gear.weapon_item("sword", 4),
	cloak_texture = "grug_achievements_cloak_plain_grey.png", cloak_id = "plain_grey"})
assert(warrior.textures.offhand ~= "none", "gen_test_characters: the Warrior's shield is not drawn")
assert(warrior.slots.mainhand.pose == "tool", "gen_test_characters: the sword is not in the tool pose")
assert(scout.textures.offhand == "none", "gen_test_characters: the Scout's blade drew an offhand layer")

-- The seven textures a website draws (model.textures): "none" is blank, the
-- weapon card stays empty, the back card follows the README's rule for a
-- website that draws slots.mainhand in the hand (the blade on the card).
local B = "blank.png"
local function slot(value) return value == "none" and B or value end
local function textures(data, back)
	local t = data.textures
	return {t.body, slot(t.cloak), slot(t.armor), B, slot(t.offhand), back or B, slot(t.wings)}
end
local scout_back = gv.back_card(scout.slots.offhand.image, true)
local scout_no_cloak = textures(scout, gv.back_card(scout.slots.offhand.image, false))
scout_no_cloak[2] = B

local function quote(text)
	return ("%q"):format(text):gsub("\\\n", "\\n")
end
local function list(t)
	local out = {}
	for i, value in ipairs(t) do out[i] = "\t" .. quote(value) .. "," end
	return "{\n" .. table.concat(out, "\n") .. "\n}"
end

local scene = ([[
-- Generated by tools/r55_web/gen_test_characters.lua; do not edit. The scene
-- of the kaesual offhand addendum's test characters for
-- tools/r55_web/capture.sh (through tools/r54_model/capture.sh; MODELS= a
-- directory with tools/web_data/model/grug_visuals_character.glb, the test
-- art baked by tools/r55_offhand/bake.py and the test wings as
-- r55web_wings_test.png): R* the exported .glb (left) beside the game's .b3d
-- (right) with the seven textures a website draws, at the stand pose's
-- frame 0 (the Scout's back card by the web README's rule: the bow in the
-- hand, the blade on the card; without a cloak the body's card; with the
-- test wings); G* the game's look of the Warrior, the .b3d with the hand
-- entity holding the sword in its pose (tool), standing and walking. The
-- camera looks along +z; a figure at yaw pi faces it, at pi/2 shows its left.
local GLB, B3D = "grug_visuals_character.glb", "grug_visuals_character.b3d"
local WARRIOR = %s
local SCOUT = %s
local SCOUT_NO_CLOAK = %s
local SCOUT_WINGS = {}
for i, texture in ipairs(SCOUT) do SCOUT_WINGS[i] = texture end
SCOUT_WINGS[7] = "r55web_wings_test.png"
local SWORD = %s
local PI = math.pi
local STAND, WALK = 0, 172
local NEAR = {0, 0.5, -2.6}
local FAR = {0, 0.5, -3.4}

local function pair(textures, yaw)
	return {
		{at = {-0.6, 0.5, 0}, yaw = yaw, frame = STAND, mesh = GLB, textures = textures},
		{at = {0.6, 0.5, 0}, yaw = yaw, frame = STAND, mesh = B3D, textures = textures},
	}
end

local function game(at, yaw, frame)
	return {at = at, yaw = yaw, frame = frame, mesh = B3D, textures = WARRIOR, wield = SWORD}
end

return {
	shots = {
		{name = "R1_warrior_glb_b3d_front", cam = NEAR, pitch = 0.25, figures = pair(WARRIOR, PI)},
		{name = "R2_warrior_glb_b3d_left", cam = NEAR, pitch = 0.25, figures = pair(WARRIOR, PI / 2)},
		{name = "R3_warrior_glb_b3d_3q", cam = NEAR, pitch = 0.25, figures = pair(WARRIOR, PI * 0.7)},
		{name = "R4_warrior_glb_b3d_back", cam = NEAR, pitch = 0.25, figures = pair(WARRIOR, 0)},
		{name = "R5_scout_glb_b3d_back", cam = NEAR, pitch = 0.25, figures = pair(SCOUT, 0)},
		{name = "R6_scout_glb_b3d_back_3q", cam = NEAR, pitch = 0.25, figures = pair(SCOUT, PI * 0.2)},
		{name = "R7_scout_glb_b3d_front", cam = NEAR, pitch = 0.25, figures = pair(SCOUT, PI)},
		{name = "R8_scout_no_cloak_glb_b3d_back", cam = NEAR, pitch = 0.25,
			figures = pair(SCOUT_NO_CLOAK, 0)},
		{name = "R9_scout_test_wings_glb_b3d_back_3q", cam = NEAR, pitch = 0.25,
			figures = pair(SCOUT_WINGS, PI * 0.2)},
		{name = "G1_game_warrior_3q_left_walk", cam = FAR, pitch = 0.18, figures = {
			game({-1.4, 0.5, 0}, PI * 0.75, STAND),
			game({0, 0.5, 0}, PI / 2, STAND),
			game({1.4, 0.5, 0}, PI * 0.75, WALK),
		}},
	},
}
]]):format(list(textures(warrior)), list(textures(scout, scout_back)), list(scout_no_cloak),
	quote(warrior.slots.mainhand.item))

local outputs = {
	["test_warrior.json"] = warrior_json .. "\n",
	["test_scout.json"] = scout_json .. "\n",
	["scene.lua"] = scene,
}
local stale = false
for _, name in ipairs({"test_warrior.json", "test_scout.json", "scene.lua"}) do
	local path = DIR .. name
	if mode == "check" then
		local handle = io.open(path, "rb")
		local committed = handle and handle:read("*a")
		if handle then handle:close() end
		if committed ~= outputs[name] then
			print("gen_test_characters: " .. path .. " is stale")
			stale = true
		end
	else
		local handle = assert(io.open(path, "wb"))
		handle:write(outputs[name])
		handle:close()
		print("gen_test_characters: wrote " .. path .. " (" .. #outputs[name] .. " bytes)")
	end
end
if stale then
	os.exit(1)
end
if mode == "check" then
	print("gen_test_characters: up to date")
end
print(("Warrior: offhand %d, JSON %d bytes; Scout: back card %d, JSON %d bytes"):format(
	#warrior.textures.offhand, #warrior_json, #scout_back, #scout_json))
