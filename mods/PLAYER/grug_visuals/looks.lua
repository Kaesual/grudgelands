--
-- Character looks (round31-plan.md §2.1): the body features a character is
-- created with, as LAYERS on the 64x32 `character.b3d` skin.
--
-- The technique is the one VoxeLibre's mcl_skins uses (our own art, generated
-- by tools/wp13/gen_character_visuals.py): a plain white MASK coloured by a
-- texture modifier, with a DETAIL layer on top that carries the shading
-- (semi-transparent black and white) and every fixed-colour pixel. One mask
-- and one detail file serve every colour, so a new hair colour is a table
-- entry, never a PNG.
--
-- Pure: no ObjectRef, no player, no engine call. `look_texture` is the string
-- the composition writes; the preview tool (tools/r31_a) renders exactly this
-- string, and an offline fixture loads this file against a stub table.
--
-- Layer order (§2.1.3), bottom to top:
--   1. skin   the shared skin mask in the chosen tone, then the race's body
--             file (face, shading, the race dress);
--   2. eyes   the race's iris (undead: glow) mask in the chosen colour;
--   3. hair   the hairstyle mask in the hair colour and its detail --
--             dropped entirely under a helmet, which hides it;
--   (body armour: chest, legs, feet -- body boxes only, no head pixel)
--   4. helmet with the shared face window cut out, so the eyes and the
--             lower face stay visible through every helmet;
--   5. feature the race's lower-face feature (beard, tusks, ears, ...),
--             last, so it shows over the helmet.
--

local P = "grug_visuals_"

-- The shared layers. The skin mask covers the whole base body (head, torso,
-- arms, legs); the dress in each race's body file covers the clothed part.
local SKIN_MASK = P .. "skin_mask.png"
local HELMET_WINDOW = P .. "helmet_window.png"
local EYES_MASK = P .. "eyes_mask.png"

grug_visuals.SKIN_MASK = SKIN_MASK
grug_visuals.HELMET_WINDOW = HELMET_WINDOW

-- The five categories in the order a look lists them.
grug_visuals.LOOK_CATEGORIES = {"tone", "hair", "style", "eyes", "feature"}

--
-- Options per race (§2.1.2). Colours are ColorStrings for `[multiply`;
-- hairstyles and features are ids that name their files:
--   grug_visuals_<race>_hair_<id>_mask.png and grug_visuals_<race>_hair_<id>.png
--   grug_visuals_<race>_feature_<id>.png (+ _mask.png when it has a `tint`).
-- A feature's `tint` names the category whose colour fills its mask: "hair"
-- (beards) or "tone" (elf ears); a feature without one is fixed colour
-- (tusks, war paint, bone).
--
local LOOKS = {
	human = {
		tones = {"#efcfb0", "#e0b08c", "#c49468", "#8c5e40"},
		hair = {"#2a2420", "#4a3020", "#603c22", "#8c3c1c", "#d0b060", "#a8a4a0"},
		eyes = {"#2a3c62", "#4a2e16", "#3c6e46"},
		styles = {"crop", "swept", "long", "tail"},
		features = {
			{id = "stubble", tint = "hair"},
			{id = "beard", tint = "hair"},
			{id = "moustache", tint = "hair"},
		},
	},
	dwarf = {
		tones = {"#ecc2a0", "#d8a07c", "#b07e5a"},
		hair = {"#c45a2c", "#9c3a1c", "#5a3a22", "#2c2624", "#c8c4bc"},
		eyes = {"#4a2e16", "#506878", "#a07020"},
		styles = {"full", "crown", "braid"},
		features = {
			{id = "full", tint = "hair"},
			{id = "braided", tint = "hair"},
			{id = "forked", tint = "hair"},
			{id = "short", tint = "hair"},
		},
	},
	elf = {
		tones = {"#eedec8", "#e2e2ea", "#dcc098"},
		hair = {"#e4d8a8", "#d8dce4", "#c09040", "#24222c", "#8a3a2a"},
		eyes = {"#6c9878", "#7a5aa0", "#7c9cc0"},
		styles = {"long", "tail", "braid", "short"},
		features = {
			{id = "pointed", tint = "tone"},
			{id = "swept", tint = "tone"},
			{id = "marked", tint = "tone"},
		},
	},
	orc = {
		tones = {"#6c9448", "#567838", "#8ca050"},
		hair = {"#222024", "#3c2a1e", "#6c6a68", "#6a2a1c"},
		eyes = {"#d04830", "#d09a28", "#3a2414"},
		styles = {"topknot", "mohawk", "shaved", "braids"},
		features = {
			{id = "tusks_small"},
			{id = "tusks_large"},
			{id = "tusks_broken"},
			{id = "warpaint"},
		},
	},
	troll = {
		tones = {"#608496", "#588c84", "#707894"},
		hair = {"#2e3a60", "#9c2a2a", "#2a7a6c", "#d8d4c4", "#5c3a7c"},
		eyes = {"#eec44c", "#d84a3a", "#8cd0e0"},
		styles = {"mane", "crest", "swept", "twintails"},
		features = {
			{id = "tusks_small"},
			{id = "tusks_large"},
			{id = "tusks_huge"},
		},
	},
	undead = {
		tones = {"#96a48c", "#aaa89c", "#8896a0"},
		hair = {"#58525e", "#8c8a86", "#5c4c3c", "#26242a"},
		eyes = {"#c6de70", "#8ce0f0", "#f08a3c"},
		eyes_mask = P .. "eyes_undead_mask.png",
		styles = {"patchy", "stringy", "bald"},
		features = {
			{id = "jaw"},
			{id = "stitches"},
			{id = "nose"},
		},
	},
}

-- File names, built once. `options` maps a category to its option list so
-- the normalizer, the roll and the dialog count the same thing.
for race, def in pairs(LOOKS) do
	def.body = P .. race .. "_body.png"
	def.eyes_mask = def.eyes_mask or EYES_MASK
	def.style_files = {}
	for index, id in ipairs(def.styles) do
		local stem = P .. race .. "_hair_" .. id
		def.style_files[index] = {mask = stem .. "_mask.png", detail = stem .. ".png"}
	end
	for _, feature in ipairs(def.features) do
		local stem = P .. race .. "_feature_" .. feature.id
		feature.detail = stem .. ".png"
		if feature.tint then
			feature.mask = stem .. "_mask.png"
		end
	end
	def.options = {tone = def.tones, hair = def.hair, style = def.styles,
		eyes = def.eyes, feature = def.features}
end

grug_visuals.LOOKS = LOOKS

-- A look is {tone = i, hair = i, style = i, eyes = i, feature = i}, each an
-- index into the race's option list. Anything missing, fractional or out of
-- range becomes option 1, so a look can always be drawn.
function grug_visuals.normalize_look(race, look)
	local def = LOOKS[race]
	if not def then
		return nil
	end
	look = type(look) == "table" and look or {}
	local out = {}
	for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		local index = look[category]
		local count = #def.options[category]
		if type(index) ~= "number" or index ~= math.floor(index) or
				index < 1 or index > count then
			index = 1
		end
		out[category] = index
	end
	return out
end

-- One uniform pick per category. `random(n)` returns 1..n (math.random's
-- contract); the caller owns the generator.
function grug_visuals.roll_look(race, random)
	local def = LOOKS[race]
	if not def then
		return nil
	end
	random = random or math.random
	local out = {}
	for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		out[category] = random(#def.options[category])
	end
	return out
end

local function tinted(mask, colour)
	return "(" .. mask .. "^[multiply:" .. colour .. ")"
end

-- The texture string of a look, with armour in its place in the layer order.
-- `body_overlays` is a list of overlay strings for the body boxes (chest,
-- legs, feet), `helmet` the head overlay string or nil; both arrive resolved
-- (tier, broken crack, later enchant colours) from the caller. `look` must be
-- normalized.
function grug_visuals.look_texture(race, look, body_overlays, helmet)
	local def = LOOKS[race]
	local feature = def.features[look.feature]
	local parts = {
		tinted(SKIN_MASK, def.tones[look.tone]),
		def.body,
		tinted(def.eyes_mask, def.eyes[look.eyes]),
	}
	if not helmet then
		local files = def.style_files[look.style]
		parts[#parts + 1] = tinted(files.mask, def.hair[look.hair])
		parts[#parts + 1] = files.detail
	end
	for _, overlay in ipairs(body_overlays or {}) do
		parts[#parts + 1] = overlay
	end
	if helmet then
		parts[#parts + 1] = "(" .. helmet .. "^[mask:" .. HELMET_WINDOW .. ")"
	end
	if feature.mask then
		local colour = feature.tint == "tone" and def.tones[look.tone] or
			def.hair[look.hair]
		parts[#parts + 1] = tinted(feature.mask, colour)
	end
	parts[#parts + 1] = feature.detail
	return table.concat(parts, "^")
end
