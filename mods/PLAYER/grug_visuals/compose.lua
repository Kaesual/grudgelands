--
-- The pure half of grug_visuals (docs/research/wp13-character-visuals-contract.md
-- §2, docs/design/character_visuals.md).
--
-- ONE function composes what a humanoid on `character.b3d` looks like --
-- players and mobs alike -- so the two can never fight over the model's
-- texture list. It is pure, deterministic and cached by its own key string:
-- the same spec always yields the same table, and the same table is handed
-- back on a repeat call.
--
-- CALLERS MUST TREAT THE RESULT AS READ-ONLY. It is the cache entry, not a
-- copy; the engine copies `textures` into the object properties, which is the
-- only consumer that needs its own storage.
--
-- Nothing in this file touches an ObjectRef, an inventory or a player. Its
-- only engine contact is `core.log` for the unknown-race warning, which is why
-- tools/wp13/character_visuals_kat.lua can load it against a stub `core` and
-- check every race x line x slot x bracket combination in plain Lua 5.1.
--

--
-- Races. `skin` is the base layer in the `character.png` layout shipped by
-- player_api; `stature` is the VISUAL-ONLY scale of the contract's §1 --
-- collision box and eye height stay exactly what player_api's model says, so
-- every race walks through the two-node doors of its own houses.
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
	human = {skin = "grug_visuals_skin_human.png", stature = 1.00},
	dwarf = {skin = "grug_visuals_skin_dwarf.png", stature = 0.90},
	elf = {skin = "grug_visuals_skin_elf.png", stature = 1.06},
	undead = {skin = "grug_visuals_skin_undead.png", stature = 0.94},
	orc = {skin = "grug_visuals_skin_orc.png", stature = 1.08},
	troll = {skin = "grug_visuals_skin_troll.png", stature = 1.12},
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
-- Armor overlays. TWO art lines (the two grug_gear registers) x four slots,
-- tinted per bracket with grug_gear's own six colours -- never a copy of that
-- table, so a palette edit there moves the armor on the model with it.
--
-- `leather` borrows the cloth cut: grug_gear registers no leather item today
-- (its only wearer, the Rogue, is Phase 2), and one fabric silhouette is a
-- better placeholder than a missing overlay. The map is explicit so the day
-- leather art exists, exactly this line changes.
--
grug_visuals.SLOTS = {"head", "chest", "legs", "feet"}
grug_visuals.LINES = {"cloth", "metal"}

local SLOTS = grug_visuals.SLOTS
local ARMOR_RANK_LINE = {"cloth", "leather", "metal"}
local LINE_ART = {cloth = "cloth", leather = "cloth", metal = "metal"}

grug_visuals.ARMOR_RANK_LINE = ARMOR_RANK_LINE
grug_visuals.LINE_ART = LINE_ART

local OVERLAY = {}
for _, line in ipairs(grug_visuals.LINES) do
	OVERLAY[line] = {}
	for _, slot in ipairs(SLOTS) do
		OVERLAY[line][slot] = "grug_visuals_" .. line .. "_" .. slot .. ".png"
	end
end
grug_visuals.OVERLAY = OVERLAY

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
--     grug_visuals.compose{race = "dwarf",
--         armor = {head = itemname_or_nil, chest = ..., legs = ..., feet = ...},
--         weapon = itemname_or_nil}
--     -> {textures = {...}, visual_size = {x=,y=,z=}, weapon = ..., key = ...}
--
-- Extra spec fields beyond the contract's three, all of them for the mob side
-- and all of them normalized BEFORE the cache key is built:
--   * `skin`        an explicit base texture (the mirefolk keep their own
--                   fish-folk skin and are not a playable race);
--   * `armor_line`  "cloth"/"leather"/"metal" -- a whole set in one line, for
--                   an NPC that has no inventory to read;
--   * `bracket`     1..6 for that set, or
--   * `level`       a character level the bracket is derived from;
--   * `weapon_family` a grug_gear weapon family ("sword", "dagger", ...) whose
--                   item name is built at the resolved bracket.
-- `armor.torso` is accepted as a spelling of `armor.chest` (the contract's §2
-- signature says `torso`, every slot, group and list in the game says `chest`).
--
-- Composition is texture modifiers only -- `^` and `^[multiply` -- so there is
-- nothing per frame and nothing the web build has to do differently.
--
local cache = {}
local warned_race = {}

grug_visuals.cache = cache

local function warn_unknown_race(race)
	local id = tostring(race)
	if not warned_race[id] then
		warned_race[id] = true
		core.log("warning", "[grug_visuals] unknown race \"" .. id ..
			"\" -- wearing the " .. grug_visuals.FALLBACK_RACE .. " skin")
	end
end

function grug_visuals.compose(spec)
	if type(spec) ~= "table" then
		spec = {}
	end

	-- Race and base skin.
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
	if not skin then
		skin = RACES[race].skin
	end
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
		if entry then
			pieces[index] = {line = entry.line, bracket = entry.bracket}
		elseif line_default then
			pieces[index] = {line = line_default, bracket = bracket_default}
		end
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
	-- Semicolon, not a pipe: the fifth plain-5.1 grep sweep of
	-- docs/research/luanti-lua.md flags `"|"` as a possible bitwise operator,
	-- and a separator nobody has to re-adjudicate on every review is free.
	local key = (race or "-") .. ";" .. skin
	for index = 1, #SLOTS do
		local piece = pieces[index]
		key = key .. ";" ..
			(piece and (piece.line .. piece.bracket) or "-")
	end
	key = key .. ";" .. (weapon or "-")

	local hit = cache[key]
	if hit then
		return hit
	end

	local texture = skin
	for index, slot in ipairs(SLOTS) do
		local piece = pieces[index]
		if piece then
			-- Parenthesised, because `^[multiply` applies to EVERYTHING to its
			-- left otherwise: `a^b^[multiply:c` tints the skin too
			-- (src/client/imagesource.cpp, the top-level `^` split).
			texture = texture .. "^(" .. OVERLAY[LINE_ART[piece.line]][slot] ..
				"^[multiply:" .. grug_gear.BRACKET_TINT[piece.bracket] .. ")"
		end
	end

	local result = {textures = {texture}, visual_size = size,
		stature = stature, weapon = weapon, key = key}
	cache[key] = result
	return result
end
