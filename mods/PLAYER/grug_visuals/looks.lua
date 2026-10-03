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
-- Pure: no ObjectRef, no player, no engine call. `look_texture` builds the
-- string `compose` writes; the preview tool (tools/r31_a) renders exactly this
-- string, and an offline fixture loads this file against a stub table.
--
-- Layer order (§2.1.3), bottom to top:
--   1. skin     the shared skin mask in the chosen tone, then the race's body
--               file (face, shading, the race dress);
--   2. eyes     the race's iris (undead: glow) mask in the chosen colour;
--   3. hair     the hairstyle mask in the hair colour and its detail --
--               dropped entirely under a helmet, which hides it;
--   (attire: a royal tabard; body armour: chest, legs, feet -- body boxes
--   only, no head pixel)
--   4. helmet   with the shared face window cut out, so the eyes and the
--               lower face stay visible through every helmet;
--   (headwear: a king's crown)
--   5. feature  the race's lower-face feature (beard, tusks, ears, ...),
--               last, so it shows over the helmet.
--

local P = "grug_visuals_"

-- The shared layers. The skin mask covers the whole base body (head, torso,
-- arms, legs); the dress in each race's body file covers the clothed part.
local SKIN_MASK = P .. "skin_mask.png"
local HELMET_WINDOW = P .. "helmet_window.png"
local EYES_MASK = P .. "eyes_mask.png"

grug_visuals.SKIN_MASK = SKIN_MASK
grug_visuals.HELMET_WINDOW = HELMET_WINDOW

-- The five categories in the order a look lists them, with the dialog's
-- label for each.
grug_visuals.LOOK_CATEGORIES = {"tone", "hair", "style", "eyes", "feature"}

--
-- Options per race (§2.1.2). Colours are ColorStrings for `[multiply`;
-- hairstyles and features are ids that name their files:
--   grug_visuals_<race>_hair_<id>_mask.png and grug_visuals_<race>_hair_<id>.png
--   grug_visuals_<race>_feature_<id>.png (+ _mask.png when it has a `tint`).
-- A feature's `tint` names the category whose colour fills its mask: "hair"
-- (beards) or "tone" (elf ears); a feature without one is fixed colour
-- (tusks, war paint, bone). `name` is what the creation dialog shows.
--
local LOOKS = {
	human = {
		tones = {"#efcfb0", "#e0b08c", "#c49468", "#8c5e40"},
		hair = {"#2a2420", "#4a3020", "#603c22", "#8c3c1c", "#d0b060", "#a8a4a0"},
		eyes = {"#2a3c62", "#4a2e16", "#3c6e46"},
		styles = {
			{id = "crop", name = "Short crop"},
			{id = "swept", name = "Side parting"},
			{id = "long", name = "Long"},
			{id = "tail", name = "Ponytail"},
		},
		features = {
			{id = "stubble", name = "Stubble", tint = "hair"},
			{id = "beard", name = "Short beard", tint = "hair"},
			{id = "moustache", name = "Moustache", tint = "hair"},
		},
	},
	dwarf = {
		tones = {"#ecc2a0", "#d8a07c", "#b07e5a"},
		hair = {"#c45a2c", "#9c3a1c", "#5a3a22", "#2c2624", "#c8c4bc"},
		eyes = {"#4a2e16", "#506878", "#a07020"},
		styles = {
			{id = "full", name = "Full"},
			{id = "crown", name = "Bald crown"},
			{id = "braid", name = "Braid"},
		},
		features = {
			{id = "full", name = "Full beard", tint = "hair"},
			{id = "braided", name = "Braided beard", tint = "hair"},
			{id = "forked", name = "Forked beard", tint = "hair"},
			{id = "short", name = "Short beard", tint = "hair"},
		},
	},
	elf = {
		tones = {"#eedec8", "#e2e2ea", "#dcc098"},
		hair = {"#e4d8a8", "#d8dce4", "#c09040", "#24222c", "#8a3a2a"},
		eyes = {"#6c9878", "#7a5aa0", "#7c9cc0"},
		styles = {
			{id = "long", name = "Long"},
			{id = "tail", name = "High tail"},
			{id = "braid", name = "Crown braid"},
			{id = "short", name = "Short"},
		},
		features = {
			{id = "pointed", name = "Pointed ears", tint = "tone"},
			{id = "swept", name = "Long ears", tint = "tone"},
			{id = "marked", name = "Ears and marking", tint = "tone"},
		},
	},
	orc = {
		tones = {"#6c9448", "#567838", "#8ca050"},
		hair = {"#222024", "#3c2a1e", "#6c6a68", "#6a2a1c"},
		eyes = {"#d04830", "#d09a28", "#3a2414"},
		styles = {
			{id = "topknot", name = "Topknot"},
			{id = "mohawk", name = "Mohawk"},
			{id = "shaved", name = "Shaved"},
			{id = "braids", name = "Braids"},
		},
		features = {
			{id = "tusks_small", name = "Small tusks"},
			{id = "tusks_large", name = "Large tusks"},
			{id = "tusks_broken", name = "Broken tusk"},
			{id = "warpaint", name = "War paint"},
		},
	},
	troll = {
		tones = {"#608496", "#588c84", "#707894"},
		hair = {"#2e3a60", "#9c2a2a", "#2a7a6c", "#d8d4c4", "#5c3a7c"},
		eyes = {"#eec44c", "#d84a3a", "#8cd0e0"},
		styles = {
			{id = "mane", name = "Mane"},
			{id = "crest", name = "Crest"},
			{id = "swept", name = "Swept back"},
			{id = "twintails", name = "Twin tails"},
		},
		features = {
			{id = "tusks_small", name = "Small tusks"},
			{id = "tusks_large", name = "Large tusks"},
			{id = "tusks_huge", name = "Huge tusks"},
		},
	},
	undead = {
		tones = {"#96a48c", "#aaa89c", "#8896a0"},
		hair = {"#58525e", "#8c8a86", "#5c4c3c", "#26242a"},
		eyes = {"#c6de70", "#8ce0f0", "#f08a3c"},
		eyes_mask = P .. "eyes_undead_mask.png",
		styles = {
			{id = "patchy", name = "Patchy"},
			{id = "stringy", name = "Stringy"},
			{id = "bald", name = "Bald"},
		},
		features = {
			{id = "jaw", name = "Exposed jaw"},
			{id = "stitches", name = "Stitches"},
			{id = "nose", name = "Sunken nose"},
		},
	},
}

-- The royal colours of each people: a king's and his guards' tabard (cloth
-- panel and trim band), the colours the Round 8 royal skins were painted in.
local ROYAL = {
	human = {cloth = "#3058aa", trim = "#e2ecff"},
	dwarf = {cloth = "#4e74a4", trim = "#d2e2f4"},
	elf = {cloth = "#468468", trim = "#e0f2d6"},
	undead = {cloth = "#5c407a", trim = "#d8c4ea"},
	orc = {cloth = "#9a302a", trim = "#f8ca60"},
	troll = {cloth = "#22768e", trim = "#cceeec"},
}
grug_visuals.ROYAL = ROYAL

-- A king's one fixed look per people (§2.1.6): the same face every time he
-- appears, chosen to read as the eldest of his court.
grug_visuals.KING_LOOKS = {
	human = {tone = 2, hair = 6, style = 3, eyes = 1, feature = 2},
	dwarf = {tone = 2, hair = 5, style = 3, eyes = 2, feature = 2},
	elf = {tone = 1, hair = 2, style = 3, eyes = 2, feature = 3},
	orc = {tone = 2, hair = 3, style = 4, eyes = 1, feature = 2},
	troll = {tone = 3, hair = 4, style = 1, eyes = 3, feature = 3},
	undead = {tone = 2, hair = 2, style = 2, eyes = 2, feature = 1},
}

-- File names, built once. `options` maps a category to its option list so
-- the normalizer, the roll and the dialog count the same thing.
for race, def in pairs(LOOKS) do
	def.body = P .. race .. "_body.png"
	def.eyes_mask = def.eyes_mask or EYES_MASK
	for _, style in ipairs(def.styles) do
		local stem = P .. race .. "_hair_" .. style.id
		style.mask = stem .. "_mask.png"
		style.detail = stem .. ".png"
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

-- The stored form: "tone,hair,style,eyes,feature". `parse_look` answers nil
-- for anything that is not five numbers, and normalizes the rest.
function grug_visuals.look_string(look)
	local parts = {}
	for index, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		parts[index] = tostring(look[category])
	end
	return table.concat(parts, ",")
end

function grug_visuals.parse_look(race, text)
	if type(text) ~= "string" then
		return nil
	end
	local values = {}
	for number in text:gmatch("[^,]+") do
		values[#values + 1] = tonumber(number)
	end
	if #values ~= #grug_visuals.LOOK_CATEGORIES then
		return nil
	end
	local look = {}
	for index, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		look[category] = values[index]
	end
	return grug_visuals.normalize_look(race, look)
end

--
-- NPC looks (§2.1.6). An NPC rolls ONE number the first time it is drawn and
-- keeps it in a plain field (`_grug_look_seed`, saved with the entity like the
-- bandit's race roll); its look is derived from that number for whatever race
-- it is drawn as. That is what lets a settlement NPC roll before the placement
-- engine has told it where it stands (`core.add_entity` activates first,
-- `install` writes the settlement after) and still keep one face for good.
--
-- The derivation is the MINSTD generator (multiplier 48271, modulus 2^31 - 1):
-- every product stays below 2^53, so it is exact in every Lua build.
--
local SEED_MODULUS = 2147483647

function grug_visuals.look_from_seed(race, seed)
	local def = LOOKS[race]
	if not def then
		return nil
	end
	local state = math.floor(tonumber(seed) or 1) % SEED_MODULUS
	if state == 0 then
		state = 1
	end
	local look = {}
	for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		state = state * 48271 % SEED_MODULUS
		look[category] = state % #def.options[category] + 1
	end
	return look
end

-- The look of an NPC entity drawn as `race`, rolled on first use. `random`
-- is math.random unless a caller (a fixture) brings its own.
function grug_visuals.npc_look(entity, race, random)
	local seed = entity._grug_look_seed
	if type(seed) ~= "number" then
		seed = (random or math.random)(1, SEED_MODULUS - 1)
		entity._grug_look_seed = seed
	end
	return grug_visuals.look_from_seed(race, seed)
end

local function tinted(mask, colour)
	return "(" .. mask .. "^[multiply:" .. colour .. ")"
end

-- The royal attire of a people: the tabard for a royal guard, the tabard and
-- the crown for a king. Returns the attire list and the headwear list for
-- `look_texture`'s `parts`.
function grug_visuals.royal_attire(race, king)
	local colours = ROYAL[race]
	if not colours then
		return nil, nil
	end
	local tabard = tinted(P .. "tabard_mask.png", colours.cloth) .. "^" ..
		tinted(P .. "tabard_trim_mask.png", colours.trim) .. "^" ..
		P .. "tabard.png"
	return {tabard}, king and {P .. "crown.png"} or nil
end

-- The texture string of a look. `look` must be normalized. `parts` places
-- whatever else the character wears in the layer order above; every field is
-- optional and every entry arrives as a finished overlay string from the
-- caller (compose.lua):
--   attire    clothing over the race dress (a royal tabard);
--   body      body armour, chest, legs, feet;
--   helmet    the head overlay -- the face window is cut from it here, so
--             anything inside it (lane B's colour layers) is cut as well;
--   headwear  over the head, under the feature (a king's crown).
function grug_visuals.look_texture(race, look, parts)
	local def = LOOKS[race]
	parts = parts or {}
	local feature = def.features[look.feature]
	local out = {
		tinted(SKIN_MASK, def.tones[look.tone]),
		def.body,
		tinted(def.eyes_mask, def.eyes[look.eyes]),
	}
	if not parts.helmet then
		local style = def.styles[look.style]
		out[#out + 1] = tinted(style.mask, def.hair[look.hair])
		out[#out + 1] = style.detail
	end
	for _, list in ipairs({parts.attire or {}, parts.body or {}}) do
		for _, overlay in ipairs(list) do
			out[#out + 1] = overlay
		end
	end
	if parts.helmet then
		out[#out + 1] = "(" .. parts.helmet .. "^[mask:" .. HELMET_WINDOW .. ")"
	end
	for _, overlay in ipairs(parts.headwear or {}) do
		out[#out + 1] = overlay
	end
	if feature.mask then
		local colour = feature.tint == "tone" and def.tones[look.tone] or
			def.hair[look.hair]
		out[#out + 1] = tinted(feature.mask, colour)
	end
	out[#out + 1] = feature.detail
	return table.concat(out, "^")
end
