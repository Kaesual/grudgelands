--
-- The pure half of grug_visuals (docs/research/wp13-character-visuals-contract.md
-- §2, docs/design/character_visuals.md, docs/technical/armor-format.md).
--
-- ONE function composes what a humanoid looks like -- players and mobs alike
-- -- so the two can never fight over the model's texture list. It is pure,
-- deterministic and cached by its own key string: the same spec always yields
-- the same table, and the same table is handed back on a repeat call.
--
-- CALLERS MUST TREAT THE RESULT AS READ-ONLY. It is the cache entry, not a
-- copy; the engine copies `textures` into the object properties, which is the
-- only consumer that needs its own storage.
--
-- Nothing in this file touches an ObjectRef, an inventory or a player. Its
-- only engine contact is `core.log` for the unknown-race warning, which is why
-- an offline check can load it against a stub `core` and check every race x
-- line x slot x bracket combination in plain Lua 5.1 (the WP13
-- character-visuals KAT did, until it was retired in Round 22).
--

--
-- Races. A race is drawn from its look layers (looks.lua); `stature` is the
-- VISUAL-ONLY scale of the contract's §1 -- collision box and eye height stay
-- exactly what player_api's model says, so every race walks through the
-- two-node doors of its own houses.
--
-- ONE SCALAR PER RACE, not an (x, y, z) triple (playtest round 2, 2026-09-15).
-- The first version made dwarves and orcs broader AND lower (1.10/0.88 and
-- 1.12/0.98), which is a nicer body language and is why it was written that
-- way -- but a non-uniform parent scale is applied to the ATTACHED wield
-- entity too, in model axes, after that entity's own rotation. On a sprite
-- whose weapon runs along the image's diagonal that is a shear: the blade
-- comes out longer, thinner and tilted, which is exactly what the player saw
-- on a player and not on a 1:1 guard. `wield_geometry.lua` section 9 works
-- through why no `visual_size` on the child can cancel it while the parent's
-- vertical and horizontal scales differ, and therefore why the anisotropy is
-- what had to go. Six distinct sizes survive; "broad" now belongs to the skin
-- art, which is where a shape difference the engine cannot shear belongs.
--
-- The window is 0.85..1.12 (asserted below, and again by the KAT).
--
local STATURE_MIN, STATURE_MAX = 0.85, 1.12

local RACES = {
	human = {stature = 1.00},
	dwarf = {stature = 0.90},
	elf = {stature = 1.06},
	undead = {stature = 0.94},
	orc = {stature = 1.08},
	troll = {stature = 1.12},
}

-- `size` is the engine-shaped form of `stature`, built once so no consumer has
-- to remember that a scalar stature is three equal numbers.
for _, race in pairs(RACES) do
	race.size = {x = race.stature, y = race.stature, z = race.stature}
end

grug_visuals.RACES = RACES
grug_visuals.STATURE_MIN = STATURE_MIN
grug_visuals.STATURE_MAX = STATURE_MAX

-- The race a spec falls back to when it names one nobody registered art for
-- (contract §2). Also what a character without a chosen race wears -- that is
-- the normal state on the spawn platform and warns about nothing.
grug_visuals.FALLBACK_RACE = "human"

for id, race in pairs(RACES) do
	for _, axis in ipairs({"x", "y", "z"}) do
		assert(race.size[axis] >= STATURE_MIN and race.size[axis] <= STATURE_MAX,
			"grug_visuals: stature of " .. id .. " outside the visual-only window")
	end
end

--
-- Armor art (Round 54, docs/technical/armor-format.md §2, §7). Armor is a set
-- of low-poly boxes baked into the character model with one atlas texture: a
-- worn piece draws its slot's ATLAS LAYER into the model's `armor` texture
-- and, for chest, legs and feet, its INNER PAINT (the skin layer) onto the
-- skin under the boxes. Three lines x four slots x six material tiers, baked
-- by tools/r54_armor; the palettes carry each tier's colours, so no piece is
-- tinted at runtime. A box a piece does not use is transparent in its layer,
-- so the model never changes with the gear.
--
grug_visuals.SLOTS = {"head", "chest", "legs", "feet"}
grug_visuals.LINES = {"cloth", "leather", "metal"}

local SLOTS = grug_visuals.SLOTS
local ARMOR_RANK_LINE = {"cloth", "leather", "metal"}
local LINE_ART = {cloth = "cloth", leather = "leather", metal = "metal"}

grug_visuals.ARMOR_RANK_LINE = ARMOR_RANK_LINE
grug_visuals.LINE_ART = LINE_ART

-- The model's armor and weapon slots when nothing is worn or shown: the
-- engine's builtin transparent texture, like the cloak's "No cloak".
grug_visuals.ARMOR_NONE = "blank.png"
grug_visuals.WEAPON_NONE = "blank.png"

-- ARMOR_ART[line][slot][bracket] = {atlas = file, skin = file or nil}: the
-- baked files of a piece (armor-format.md §7, named by the grade's key; the
-- head has no skin region, so no skin layer). Each has its enchant mask
-- `<stem>_ench.png` next to it.
local ARMOR_ART = {}
for _, line in ipairs(grug_visuals.LINES) do
	ARMOR_ART[line] = {}
	for _, slot in ipairs(SLOTS) do
		ARMOR_ART[line][slot] = {}
		for bracket, materials in ipairs(grug_gear.MATERIALS) do
			local stem = "grug_armor_" .. line .. "_" .. materials[line].key .. "_" .. slot
			ARMOR_ART[line][slot][bracket] = {atlas = stem .. ".png",
				skin = slot ~= "head" and stem .. "_skin.png" or nil}
		end
	end
end
grug_visuals.ARMOR_ART = ARMOR_ART

--
-- Bracket resolution. `bracket` wins; `level` is the shorthand a mob uses
-- because its own level is an engine-owned runtime value (grug_mobs/levels.lua)
-- and nobody should re-derive the ten-level ladder by hand.
--
local function bracket_count()
	return #grug_gear.BRACKETS
end

local function normalize_bracket(bracket, level)
	if type(bracket) ~= "number" then
		bracket = grug_gear.bracket_for_level(level)
	end
	bracket = math.floor(bracket)
	if bracket < 1 then
		bracket = 1
	elseif bracket > bracket_count() then
		bracket = bracket_count()
	end
	return bracket
end

grug_visuals.normalize_bracket = normalize_bracket

--
-- What an equipped item looks like. Built ONCE from the real item registry
-- (`grug_visuals.index_armor`) rather than parsed out of item names: the line
-- is the `grug_armor_class` group every armor piece already carries for the
-- equip filter, the slot is its `grug_equip_<slot>` group and the bracket is
-- `_grug_bracket`. An armor item from a later WP therefore shows up on the
-- model without an edit here, and an item that is not armor at all resolves
-- to nothing and is simply not drawn.
--
local armor_appearance = {}
grug_visuals.armor_appearance = armor_appearance

function grug_visuals.index_armor(items)
	for name in pairs(armor_appearance) do
		armor_appearance[name] = nil
	end
	-- Every cached composition was built against the OLD index; a re-index
	-- that kept them would hand back a skin the registry no longer describes.
	for key in pairs(grug_visuals.cache) do
		grug_visuals.cache[key] = nil
	end
	local count = 0
	for name, def in pairs(items) do
		local groups = type(def) == "table" and def.groups or nil
		if type(groups) == "table" then
			local slot = nil
			for _, candidate in ipairs(SLOTS) do
				if (groups["grug_equip_" .. candidate] or 0) > 0 then
					slot = candidate
				end
			end
			local rank = groups.grug_armor_class
			local line = type(rank) == "number" and ARMOR_RANK_LINE[rank] or nil
			if slot and line then
				armor_appearance[name] = {slot = slot, line = line,
					bracket = normalize_bracket(def._grug_bracket, nil)}
				count = count + 1
			end
		end
	end
	return count
end

--
-- The composition itself.
--
--     grug_visuals.compose{race = "dwarf", look = {tone = 2, ...},
--         armor = {head = itemname_or_nil, chest = ..., legs = ..., feet = ...},
--         weapon = itemname_or_nil}
--     -> {skin = ..., armor = ..., textures = {...}, visual_size = {x=,y=,z=},
--         stature = ..., weapon = ..., key = ...}
--
-- `skin` is the 64x32 skin (the race look with the worn pieces' inner paint),
-- `armor` the atlas texture of the worn pieces (ARMOR_NONE without any). The
-- model's texture list is the caller's: a player wears skin, cloak, armor and
-- weapon (apply.lua); `textures` is an entity's whole list -- skin, armor and
-- an empty weapon card for an ARMORED NPC (a spec with `armor_line`, on the
-- NPC model grug_visuals_npc.b3d), the skin alone for anybody else (on
-- character.b3d).
--
-- A race is drawn from its look layers (looks.lua, round31-plan.md §2.1):
--   * `look`        the five option indices (normalized here; missing means
--                   option 1 everywhere);
--   * `royal`       "guard" (the race's royal tabard) or "king" (tabard and
--                   crown);
-- Extra spec fields for the mob side, all normalized BEFORE the key is built:
--   * `skin`        an explicit base texture INSTEAD of a race's layers (the
--                   mirefolk keep their own fish-folk skin and are not a
--                   playable race);
--   * `armor_line`  "cloth"/"leather"/"metal" -- a whole set in one line, for
--                   an NPC that has no inventory to read;
--   * `bracket`     1..6 for that set, or
--   * `level`       a character level the bracket is derived from;
--   * `weapon_family` a grug_gear weapon family ("sword", "dagger", ...) whose
--                   item name is built at the resolved bracket.
-- `armor.torso` is accepted as a spelling of `armor.chest` (the contract's §2
-- signature says `torso`, every slot, group and list in the game says `chest`).
--
-- ENCHANT COLOURS ON ARMOUR (round31-plan.md §2.2): `armor_enchant[slot] =
-- {prefix = stat, suffix = stat}` colours that piece through the masks of
-- its own files (grug_gear.enchant_layers), inside the piece's parentheses
-- on the skin and on the atlas alike (enchant.lua builds it from the worn
-- stacks). `armor_layers[slot]` is an extra skin-space string appended inside
-- that piece's skin layer -- "(<skin layer>^<colours>^<layers>)" -- the War
-- Commander's tabard over his chest piece. Both are part of the cache key.
--
-- ZONE COLOURS (Round 54): `armor_colors = {a = "#rrggbb", b = "#rrggbb"}`
-- lays every piece's zone A (cloth: tabard panels, padding) and zone B
-- (fittings) in those colours, full strength through the same zone masks,
-- under any enchant colours (the War Commander's faction colours). A `royal`
-- spec that wears armour (kings, royal guards and Generals, in the guards'
-- metal line) gets them by default as the royal variant -- zone A in the
-- people's royal cloth colour, zone B in ROYAL_GOLD -- and a king wears no
-- helmet box, so his face and crown show.
--
-- Composition is texture modifiers only, every armour piece in its own
-- parentheses (a piece's colours and cracks must never reach what lies under
-- it), so there is nothing per frame and nothing the web build has to do
-- differently.
--
local cache = {}
local warned_race = {}

grug_visuals.cache = cache

local function warn_unknown_race(race)
	local id = tostring(race)
	if not warned_race[id] then
		warned_race[id] = true
		core.log("warning", "[grug_visuals] unknown race \"" .. id ..
			"\" -- drawn as " .. grug_visuals.FALLBACK_RACE)
	end
end

local ROYAL_KINDS = {guard = true, king = true}

-- Zone colours over one baked file: each zone's mask frame (`<stem>_ench.png`,
-- frame 0 zone A, frame 1 zone B) shaded in the colour at full strength.
local function zone_layers(file, a, b)
	local mask = file:sub(1, -5) .. "_ench.png"
	return "(" .. mask .. "^[verticalframe:2:0^[multiply:" .. a .. ")^(" ..
		mask .. "^[verticalframe:2:1^[multiply:" .. b .. ")"
end

-- One piece's layer: the baked file with the piece's colours (and, on the
-- skin, the extra layers), cracked as a whole when broken, in its own
-- parentheses.
local function piece_layer(file, piece, extra, zones)
	local out = file
	if zones then
		out = out .. "^" .. zone_layers(file, zones.a, zones.b)
	end
	if piece.prefix or piece.suffix then
		local colours = grug_gear.enchant_layers(file, piece.prefix, piece.suffix)
		if colours then
			out = out .. "^" .. colours
		end
	end
	if extra then
		out = out .. "^" .. extra
	end
	if piece.broken then
		out = grug_gear.broken_image(out)
	end
	return "(" .. out .. ")"
end

local function is_colour(value)
	return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

-- A content digest of a texture list (its length and two 32-bit polynomial
-- hashes): what an entity keeps to know its drawn list is current. Compose's
-- key covers the INPUTS; a retuned colour, file or modifier changes the output
-- under the same key, and only a digest of the output catches that on an NPC
-- whose list came back from staticdata. Computed once per cache entry.
local function digest(textures)
	local text = table.concat(textures, "\n")
	local h1, h2 = 0, 5381
	for index = 1, #text do
		local byte = text:byte(index)
		h1 = (h1 * 31 + byte) % 4294967296
		h2 = (h2 * 33 + byte) % 4294967291
	end
	return #text .. ":" .. string.format("%08x%08x", h1, h2)
end

local function stat_or_nil(value)
	return type(value) == "string" and value ~= "" and value or nil
end

function grug_visuals.compose(spec)
	if type(spec) ~= "table" then
		spec = {}
	end

	-- Race (or an explicit skin) and the look.
	local race = spec.race
	if race ~= nil and RACES[race] == nil then
		warn_unknown_race(race)
		race = grug_visuals.FALLBACK_RACE
	end
	local skin = spec.skin
	if type(skin) ~= "string" or skin == "" then
		skin = nil
	end
	if not race and not skin then
		race = grug_visuals.FALLBACK_RACE
	end
	local look = not skin and grug_visuals.normalize_look(race, spec.look) or nil
	local royal = not skin and ROYAL_KINDS[spec.royal] and spec.royal or nil
	-- Stature belongs to a RACE. A spec that only names a skin (a humanoid mob
	-- that is nobody's race) keeps whatever size its own definition set.
	local size = race and RACES[race].size or nil
	local stature = race and RACES[race].stature or nil

	-- Armor: the per-slot items first, the line shorthand for whatever is left.
	local line_default = spec.armor_line
	if line_default ~= nil and LINE_ART[line_default] == nil then
		line_default = nil
	end
	local bracket_default = normalize_bracket(spec.bracket, spec.level)

	local pieces = {}
	local armor = type(spec.armor) == "table" and spec.armor or nil
	local layers = type(spec.armor_layers) == "table" and spec.armor_layers or {}
	local enchants = type(spec.armor_enchant) == "table" and spec.armor_enchant or {}
	for index, slot in ipairs(SLOTS) do
		local itemname = nil
		if armor then
			itemname = armor[slot]
			if itemname == nil and slot == "chest" then
				itemname = armor.torso
			end
		end
		local entry = type(itemname) == "string" and armor_appearance[itemname]
			or nil
		local piece = nil
		if entry then
			piece = {line = entry.line, bracket = entry.bracket,
				broken = spec.armor_broken and spec.armor_broken[slot] == true}
		elseif line_default then
			piece = {line = line_default, bracket = bracket_default}
		end
		if piece then
			local extra = layers[slot]
			piece.layers = type(extra) == "string" and extra ~= "" and extra or nil
			local enchant = enchants[slot]
			if type(enchant) == "table" then
				piece.prefix = stat_or_nil(enchant.prefix)
				piece.suffix = stat_or_nil(enchant.suffix)
			end
		end
		pieces[index] = piece
	end
	-- A king wears no helmet (SLOTS[1]): his face and crown show.
	if royal == "king" then
		pieces[1] = nil
	end

	-- Zone colours: the spec's, else the royal variant's (armour only).
	-- (Only the spec's colours enter the key: the royal ones follow from
	-- `royal` and the race, which it covers.)
	local zones, own_zones = nil, nil
	local colors = spec.armor_colors
	if type(colors) == "table" and is_colour(colors.a) and is_colour(colors.b) then
		zones = {a = colors.a:lower(), b = colors.b:lower()}
		own_zones = zones
	elseif royal and grug_visuals.ROYAL[race] then
		zones = {a = grug_visuals.ROYAL[race].cloth, b = grug_visuals.ROYAL_GOLD}
	end

	-- Weapon: a plain item name, or the family shorthand at the set's bracket.
	local weapon = spec.weapon
	if type(weapon) ~= "string" or weapon == "" then
		weapon = nil
	end
	if not weapon and type(spec.weapon_family) == "string" then
		-- grug_gear owns the name: since the WP13 round-2 merge an item is
		-- called after its MATERIAL, not after its bracket number, and this is
		-- the one place that used to build `_b<n>` by hand.
		weapon = grug_gear.weapon_item(spec.weapon_family, bracket_default)
	end

	-- The key covers every normalized input, and nothing else: two specs that
	-- differ only in a field the composition ignores share one cache entry.
	-- Semicolon, not a pipe: a hand-run bitwise-operator grep sweep of
	-- docs/research/luanti-lua.md matches `"|"` even inside a string.
	local key = (race or "-") .. ";" .. (skin or "-") .. ";" ..
		(look and grug_visuals.look_string(look) or "-") .. ";" .. (royal or "-") ..
		";" .. (line_default and "npc" or "-") .. ";" ..
		(own_zones and own_zones.a .. "," .. own_zones.b or "-")
	for index = 1, #SLOTS do
		local piece = pieces[index]
		local part = "-"
		if piece then
			part = piece.line .. piece.bracket .. (piece.broken and "!" or "")
			if piece.prefix or piece.suffix then
				part = part .. "*" .. (piece.prefix or "") .. "," .. (piece.suffix or "")
			end
			if piece.layers then
				part = part .. "+" .. piece.layers
			end
		end
		key = key .. ";" .. part
	end
	key = key .. ";" .. (weapon or "-")

	local hit = cache[key]
	if hit then
		return hit
	end

	-- Every piece in its own parentheses, on the atlas and (but the head) on
	-- the skin.
	local atlas, inner, helmet = {}, {}, false
	for index, slot in ipairs(SLOTS) do
		local piece = pieces[index]
		if piece then
			helmet = helmet or slot == "head"
			local art = ARMOR_ART[LINE_ART[piece.line]][slot][piece.bracket]
			atlas[#atlas + 1] = piece_layer(art.atlas, piece, nil, zones)
			if art.skin then
				inner[#inner + 1] = piece_layer(art.skin, piece, piece.layers, zones)
			end
		end
	end

	local texture
	if skin then
		texture = skin
		for _, layer in ipairs(inner) do
			texture = texture .. "^" .. layer
		end
	else
		local attire, headwear = nil, nil
		if royal then
			attire, headwear = grug_visuals.royal_attire(race, royal == "king")
		end
		-- The helmet is a box (armor-format.md §2): under it the hair is
		-- dropped, and the face stays the race's.
		texture = grug_visuals.look_texture(race, look, {attire = attire,
			body = inner, helmet = helmet, headwear = headwear})
	end
	local armor_texture = #atlas > 0 and table.concat(atlas, "^") or
		grug_visuals.ARMOR_NONE

	local result = {skin = texture, armor = armor_texture, visual_size = size,
		stature = stature, weapon = weapon, key = key}
	if line_default then
		result.textures = {texture, armor_texture, grug_visuals.WEAPON_NONE}
	else
		result.textures = {texture}
	end
	result.digest = digest(result.textures)
	cache[key] = result
	return result
end
