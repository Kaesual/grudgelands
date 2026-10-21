-- Round 54 lane VIEW portable test: the Character tab's 3D view
-- (round54-plan.md §4 VIEW, §3 preview seam). Through tools/r44_ch/harness.lua
-- (the REAL sfinv, grug_inventory equipment/bags/ui/pages) it checks:
--   A. the preview seam is used when present: its mesh and its four textures
--      {skin, cloak, armor, weapon} reach model[] unchanged, read back the way
--      the engine parses the element (guiFormSpecMenu.cpp parseModel: split
--      at unescaped ";" and ",", then unescape_string per texture), so every
--      entry is escaped exactly once and the list separators stay raw;
--   B. the weapon card: the main hand's image for an equipped weapon (a
--      sword, the Scout's bow with a modifier carrying commas), blank.png
--      bare-handed, the off-hand never; an equipment change re-sends the
--      open page with the new weapon;
--   C. the fallback without the seam: the live properties, and player_api's
--      registry before the player model exists;
--   D. the order the refresh relies on: grug_inventory loads after
--      grug_visuals (optional_depends), so grug_visuals' equipment-change
--      pass is registered, and runs, before the page's refresh;
--   E. the REAL seam (grug_visuals.preview cut from apply.lua, hand_image
--      from appearance.lua) gives what the stand-in gives: the mesh, an
--      empty card bare-handed, the sword's and the bow's image.
--
-- Usage (repo root): luajit tools/r54_view/portable_test.lua [repo]

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r44_ch/harness.lua")(repo)

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end

-- The engine's split (src/util/string.h): an escaped character stays in the
-- token WITH its backslash; only an unescaped delimiter splits.
local function split(text, delim)
	local tokens, current, escaped = {}, {}, false
	for i = 1, #text do
		local c = text:sub(i, i)
		if escaped then
			current[#current + 1] = "\\" .. c
			escaped = false
		elseif c == delim then
			tokens[#tokens + 1] = table.concat(current)
			current = {}
		elseif c == "\\" then
			escaped = true
		else
			current[#current + 1] = c
		end
	end
	tokens[#tokens + 1] = table.concat(current)
	return tokens
end
-- unescape_string: drop each backslash, keep the character after it.
local function unescape(text)
	return (text:gsub("\\(.)", "%1"))
end

-- The model[] element named grug_preview, parsed as the client does: the
-- element's body up to its unescaped "]", its parts, the mesh and the list.
local function model_element(fs)
	local start = fs:find("model[", 1, true)
	while start do
		local body, i = {}, start + #"model["
		while i <= #fs do
			local c = fs:sub(i, i)
			if c == "\\" then
				body[#body + 1] = fs:sub(i, i + 1)
				i = i + 2
			elseif c == "]" then
				break
			else
				body[#body + 1] = c
				i = i + 1
			end
		end
		local parts = split(table.concat(body), ";")
		if unescape(parts[3] or "") == "grug_preview" then
			local textures = {}
			for index, texture in ipairs(split(parts[5] or "", ",")) do
				textures[index] = unescape(texture)
			end
			return {parts = parts, mesh = unescape(parts[4] or ""), textures = textures}
		end
		start = fs:find("model[", i, true)
	end
	return nil
end

local function same_list(actual, expected, label)
	local ok = #actual == #expected
	for index = 1, math.max(#actual, #expected) do
		ok = ok and actual[index] == expected[index]
	end
	return check(ok, label .. " (got {" .. table.concat(actual, " | ") .. "}, expected {" ..
		table.concat(expected, " | ") .. "})")
end

--
-- A. The seam, used when present, escaped once per entry
--

local harness_preview = grug_visuals.preview
local TRICKY = {
	"(base.png^[multiply:#a0b0c0)^(hair.png^[hsl:0,20,0)",
	"blank.png",
	"(grug_armor_metal_t6_chest.png^[colorize:#ffcc00:48)^[combine:16x16:0,0=a.png",
	"grug_gear_item_bow_steel.png^[hsl:-30,10,0;weird]name\\x",
}
local calls = 0
grug_visuals.preview = function(player)
	calls = calls + 1
	return {mesh = "grug_visuals_character.b3d", textures = TRICKY}
end
local wa = H.player("wa", "warrior", {16})
local fs = H.page(wa, "stats")
local model = model_element(fs)
check(model ~= nil, "A the grug_preview model element")
check(calls >= 1, "A the page asks the seam")
eq(model and model.mesh, "grug_visuals_character.b3d", "A the seam's mesh")
same_list(model and model.textures or {}, TRICKY,
	"A the four textures read back exactly as the engine parses them")
eq(model and #model.parts, 6, "A the element's parts (rect, name, mesh, textures, view)")
-- Escaped once: a doubled escape would leave a backslash after unescaping
-- (the round trip above), a joined-list escape would read back as ONE texture.
eq(model and #model.textures, 4, "A four slots, not one joined texture")
check(fs:find("hair.png^\\[hsl:0\\,20\\,0)", 1, true) ~= nil,
	"A a comma inside a texture is escaped, the separators are not")

--
-- B. The weapon card through the seam's shape (the harness's stand-in)
--

grug_visuals.preview = harness_preview
core.registered_items["grug_gear:sword_steel"].inventory_image = "grug_gear_item_sword_steel.png"
core.registered_items["grug_gear:bow_bronze"].inventory_image =
	"grug_gear_item_bow_bronze.png^[hsl:-20,10,0"
core.registered_items["grug_gear:shield_bronze"].inventory_image = "grug_gear_item_shield_bronze.png"

local bare = H.player("bare", "mage", {16})
local bare_model = model_element(H.page(bare, "stats"))
same_list(bare_model.textures, {"character.png", "blank.png", "blank.png", "blank.png"},
	"B bare-handed: a blank weapon card")

local sw = H.player("sw", "warrior", {16})
H.put(sw, "grug_weapon", 1, "grug_gear:sword_steel")
H.put(sw, "grug_offhand", 1, "grug_gear:shield_bronze")
H.equipment_change(sw, "grug_weapon")
local sw_model = model_element(H.page(sw, "stats"))
eq(sw_model.textures[4], "grug_gear_item_sword_steel.png", "B a sword on the weapon card")
check(not H.page(sw, "stats"):find("grug_gear_item_shield_bronze.png", 1, true),
	"B the off-hand shield is not drawn")

local sc = H.player("sc", "scout", {16})
H.put(sc, "grug_weapon", 1, "grug_gear:bow_bronze")
H.equipment_change(sc, "grug_weapon")
local sc_model = model_element(H.page(sc, "stats"))
eq(sc_model.textures[4], "grug_gear_item_bow_bronze.png^[hsl:-20,10,0",
	"B the Scout's bow (Ranged main hand) on the card, its modifier intact")
eq(#sc_model.textures, 4, "B the bow's commas do not split the list")

-- An equip and an unequip re-send the open Character page with the new card.
local live = H.player("live", "warrior", {16})
H.page(live, "stats")
local sent = live.sent
H.put(live, "grug_weapon", 1, "grug_gear:sword_steel")
H.equipment_change(live, "grug_weapon")
check(live.sent > sent, "B an equip re-sends the Character page")
eq(model_element(live.formspec).textures[4], "grug_gear_item_sword_steel.png",
	"B ... showing the new weapon")
H.put(live, "grug_weapon", 1, "")
H.equipment_change(live, "grug_weapon")
eq(model_element(live.formspec).textures[4], "blank.png", "B an unequip blanks the card")
sent = live.sent
H.equipment_change(live, "grug_weapon", "durability_metadata")
eq(live.sent, sent, "B pure wear re-sends nothing (as before)")

--
-- C. The fallback without the seam
--

grug_visuals.preview = nil
local fb = H.player("fb", "warrior", {16})
local fb_model = model_element(H.page(fb, "stats"))
eq(fb_model.mesh, "character.b3d", "C no seam: the live mesh")
same_list(fb_model.textures, {"character.png"}, "C no seam: the live textures")
function fb:get_properties()
	return {visual = "upright_sprite", textures = {"player.png", "player_back.png"}}
end
local early = model_element(H.page(fb, "stats"))
eq(early.mesh, "character.b3d", "C before player_api's model: its default mesh")
same_list(early.textures, {"character.png"}, "C ... with player_api's registered textures")
grug_visuals.preview = harness_preview

--
-- D. The refresh order
--

local conf = io.open(repo .. "/mods/PLAYER/grug_inventory/mod.conf"):read("*a")
local optional = conf:match("optional_depends%s*=%s*([^\n]*)") or ""
check((", " .. optional .. ","):find("[ ,]grug_visuals[ ,]") ~= nil,
	"D grug_inventory loads after grug_visuals (optional_depends)")
local visuals_conf = io.open(repo .. "/mods/PLAYER/grug_visuals/mod.conf"):read("*a")
check(not visuals_conf:find("grug_inventory", 1, true),
	"D grug_visuals does not depend on grug_inventory (no cycle)")

--
-- E. The real seam matches the stand-in (once grug_visuals has it): its
-- function and hand_image are cut from the game's files and run against the
-- real equipment.lua; compose and player_spec are stubbed (the composed
-- strings are lane GAME's, tools/r54_game).
--

local function source(path)
	local file = io.open(repo .. path)
	local text = file and file:read("*a") or ""
	if file then file:close() end
	return text
end
local apply_src = source("/mods/PLAYER/grug_visuals/apply.lua")
local preview_src = apply_src:match("\n(function grug_visuals%.preview%(player%).-\nend)\n")
if preview_src then
	local appearance_src = source("/mods/PLAYER/grug_visuals/appearance.lua")
	local hand_src = appearance_src:match("\n(local function image_name%(image%).-\nend)\n") ..
		"\n" .. appearance_src:match("\n(function grug_visuals%.hand_image%(stack%).-\nend)\n")
	local compose_src = source("/mods/PLAYER/grug_visuals/compose.lua")
	local real = {
		PLAYER_MODEL = apply_src:match('grug_visuals%.PLAYER_MODEL = "([^"]+)"'),
		CLOAK_NONE = apply_src:match('grug_visuals%.CLOAK_NONE = "([^"]+)"'),
		WEAPON_NONE = compose_src:match('grug_visuals%.WEAPON_NONE = "([^"]+)"'),
		-- Round 55: the offhand look's slots (off here: OFFHAND_VISUALS unset).
		BACK_NONE = compose_src:match('grug_visuals%.BACK_NONE = "([^"]+)"'),
		WINGS_NONE = compose_src:match('grug_visuals%.WINGS_NONE = "([^"]+)"'),
	}
	local saved = {}
	for key, value in pairs(real) do saved[key], grug_visuals[key] = grug_visuals[key], value end
	saved.compose, saved.player_spec = grug_visuals.compose, grug_visuals.player_spec
	grug_visuals.player_spec = function() return {} end
	grug_visuals.compose = function()
		return {skin = "skin.png", armor = "armor.png", offhand = "blank.png"}
	end
	-- cloak_source is the file's local: nil here, the "No cloak" path.
	assert(loadstring(hand_src, "hand_image"))()
	assert(loadstring(preview_src, "preview"))()
	eq(real.PLAYER_MODEL, H.PREVIEW_MESH, "E the real seam's mesh is the stand-in's")
	local rb = H.player("rb", "warrior", {16})
	same_list(model_element(H.page(rb, "stats")).textures,
		{"skin.png", real.CLOAK_NONE, "armor.png", "blank.png", "blank.png", real.BACK_NONE,
			real.WINGS_NONE},
		"E the real seam bare-handed: skin, no cloak, armor, a blank card, blank offhand look")
	H.put(rb, "grug_weapon", 1, "grug_gear:sword_steel")
	H.equipment_change(rb, "grug_weapon")
	-- the card mirrors its image across the anti-diagonal (the Character tab, 2026-10-21)
	eq(model_element(rb.formspec or H.page(rb, "stats")).textures[4],
		"grug_gear_item_sword_steel.png^[transformFYR90", "E the real seam: the sword on the card")
	local rs = H.player("rs", "scout", {16})
	H.put(rs, "grug_weapon", 1, "grug_gear:bow_bronze")
	H.equipment_change(rs, "grug_weapon")
	eq(model_element(H.page(rs, "stats")).textures[4],
		"grug_gear_item_bow_bronze.png^[hsl:-20,10,0^[transformFYR90", "E the real seam: the Scout's bow")
	for key, value in pairs(saved) do grug_visuals[key] = value end
	grug_visuals.preview = harness_preview
else
	-- GAME's seam is on main since Round 54: a pattern that stops matching is a failure, never a silent skip.
	failures, checks = failures + 1, checks + 1
	print("FAIL E grug_visuals.preview not found in apply.lua (the cut pattern no longer matches)")
end

if failures > 0 then
	error(("r54_view: %d/%d failures"):format(failures, checks), 0)
end
print(("r54_view: PASS checks=%d"):format(checks))
