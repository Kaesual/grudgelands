-- Round 55 lane WEB portable test (LuaJIT): the offhand look and appearance
-- version 3 in the web export (tools/web_data/README.md, "Version 2
-- appearances" and "The offhand look").
--
--   luajit tools/r55_web/portable_test.lua [REPO]
--
-- Builds the export from the real game files (tools/web_data/build.lua).
-- Checks:
--   O  `offhand_look`: the setting's name; `enabled` is the default
--      settingtypes.txt gives it and what grug_visuals reads on a server
--      that never set it; `layers` holds the shield and the book, one file
--      per bracket, each the game's grug_visuals.offhand_file and following
--      the grammar's file rule, every shield and spellbook item's layer
--      among them; the layers and their `_ench.png` masks are all in
--      `texture_files` or none is, and all are while `enabled` is true (the
--      finish step cannot turn the look on without its files);
--   K  `back_card`: an exported class, a 32 x 16 texture whose left half is
--      the cloak's card and right half the body's (offhand-format.md §5),
--      and every hand item's image file 16 x 16, so a card's image fills its
--      half exactly;
--   V  the version 2 rule: the value 0.54.1 wrote for the Round 54 test
--      character (v2_sample.json), read as version 3 with `textures.offhand`
--      and `textures.wings` "none", is byte for byte the value the current
--      game writes for that character (tools/r54_web/test_character.json);
--      every file it names is still in `texture_files`, and it is within
--      the version 3 caps;
--   T  the addendum's test characters (test_warrior.json, test_scout.json,
--      scene.lua) are current (gen_test_characters.lua --check): version 3,
--      within the caps, the Warrior's offhand the bracket 6 shield layer.
-- Prints "R55 WEB PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(got, want, label)
	return check(got == want, label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end

local function read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

local web_data = dofile(ROOT .. "/tools/web_data/build.lua")
local data = web_data.build(ROOT)
local gv = grug_visuals
local look = data.offhand_look
local limits = data.appearance_limits

local listed, paths = {}, {}
for _, entry in ipairs(data.texture_files) do
	listed[entry.name] = true
	paths[entry.name] = entry.path
end

local function files_of(text)
	local out = {}
	for name in text:gmatch("[a-z0-9_]+%.png") do out[#out + 1] = name end
	return out
end

-- O. The setting and the layers.
check(type(look) == "table", "O offhand_look present")
eq(look.setting, "grug_offhand_visuals", "O the setting's name")
local default = (read("settingtypes.txt") or ""):match("\ngrug_offhand_visuals %b() bool (%a+)")
eq(tostring(look.enabled), default, "O enabled is the settingtypes.txt default")
eq(look.enabled, gv.OFFHAND_VISUALS == true, "O enabled is what grug_visuals reads by default")

local kinds = {}
for kind in pairs(look.layers) do kinds[#kinds + 1] = kind end
table.sort(kinds)
eq(table.concat(kinds, ","), "book,shield", "O the layer kinds")
local file_rule = data.texture_grammar.file
local file_pattern = "^[" .. file_rule.charset .. "]+" .. file_rule.suffix:gsub("%p", "%%%0") .. "$"
local present, absent = 0, 0
for _, kind in ipairs(kinds) do
	local list = look.layers[kind]
	eq(#list, #grug_gear.BRACKETS, "O one " .. kind .. " layer per bracket")
	for bracket, name in ipairs(list) do
		eq(name, gv.offhand_file(kind, bracket), "O " .. kind .. " bracket " .. bracket)
		check(name:match(file_pattern) ~= nil and #name <= data.texture_grammar.args.file.max_length,
			"O " .. name .. " follows the grammar's file rule")
		for _, file in ipairs({name, (name:gsub("%.png$", "_ench.png"))}) do
			if listed[file] then present = present + 1 else absent = absent + 1 end
		end
	end
end
check(present == 0 or absent == 0, ("O the layers and masks are all in texture_files or none " ..
	"(%d in, %d out)"):format(present, absent))
check(not look.enabled or absent == 0, "O enabled only with every layer and mask in texture_files")
local offhand_items = 0
for name in pairs(data.equippable_items) do
	local entry = gv.offhand_appearance[name]
	if entry then
		offhand_items = offhand_items + 1
		eq(look.layers[entry.kind][entry.bracket], entry.file, "O " .. name .. "'s layer listed")
	end
end
eq(offhand_items, 2 * #grug_gear.BRACKETS, "O every shield and spellbook has a layer")

-- K. The back card.
local card = look.back_card
local class_ids = {}
for _, class in ipairs(data.classes) do class_ids[class.id] = true end
check(class_ids[card.class] == true, "K the back card's class is exported: " .. tostring(card.class))
eq(card.width, 32, "K back texture width")
eq(card.height, 16, "K back texture height")
eq(card.cloak_x, 0, "K the cloak's card is the left half")
eq(card.body_x, 16, "K the body's card is the right half")
eq(card.rotate, 180, "K the image turned 180 degrees, grip up (2026-10-21)")
local function png_size(path)
	local text = read(path)
	if not text or text:sub(2, 4) ~= "PNG" then return nil end
	local function u32(at)
		local a, b, c, d = text:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end
for name, item in pairs(data.hand_items) do
	local file = files_of(item.wield_image)[1]
	local w, h = png_size(paths[file] or "")
	check(w == card.height and h == card.height, ("K %s's image %s is %dx%d"):format(name,
		tostring(file), card.height, card.height))
end

-- V. The version 2 rule.
local v2 = read("tools/r55_web/v2_sample.json") or ""
local v3 = (read("tools/r54_web/test_character.json") or ""):gsub("\n$", "")
v2 = v2:gsub("\n$", "")
check(v2:sub(1, 7) == '{"v":2,', "V the sample is a version 2 value")
local s, e = v2:find('"textures":%b{}')
local upgraded = s and ('{"v":3,' .. v2:sub(8, e - 1) .. ',"offhand":"none","wings":"none"}' ..
	v2:sub(e + 1)) or ""
eq(upgraded, v3, "V version 2 read as version 3 is the current game's value")
check(#v2 <= limits.json_max_bytes, "V the sample is within the version 3 JSON cap")
for name in v2:gmatch("[a-z0-9_]+%.png") do
	check(listed[name] == true, "V a version 2 file is still listed: " .. name)
end
for text in v2:gmatch('"([^"]*%.png[^"]*)"') do
	check(#text <= limits.texture_max_bytes, "V a version 2 string within the texture cap")
end

-- T. The test characters.
local status = os.execute("luajit " .. ROOT .. "/tools/r55_web/gen_test_characters.lua " ..
	ROOT .. " --check >/dev/null")
check(status == 0 or status == true, "T test_warrior.json, test_scout.json and scene.lua " ..
	"are current (run luajit tools/r55_web/gen_test_characters.lua)")
for _, name in ipairs({"test_warrior.json", "test_scout.json"}) do
	local text = (read("tools/r55_web/" .. name) or ""):gsub("\n$", "")
	check(text:sub(1, 7) == '{"v":3,', "T " .. name .. " is version 3")
	check(#text <= limits.json_max_bytes, "T " .. name .. " within the JSON cap")
end
local warrior = read("tools/r55_web/test_warrior.json") or ""
check(warrior:find('"offhand":"(' .. look.layers.shield[#grug_gear.BRACKETS], 1, true) ~= nil,
	"T the Warrior's offhand is the bracket 6 shield layer")

if failures > 0 then
	error(("R55 WEB PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print("R55 WEB PORTABLE PASS checks=" .. checks)
