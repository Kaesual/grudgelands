-- Round 39 lane WE portable test (LuaJIT): the web-data export
-- (round39-web-data-plan.md §4.2, tools/web_data/README.md).
--
--   luajit tools/web_data/portable_test.lua [REPO]
--
-- Regenerates the export from the real game files and checks:
--   C  the committed tools/web_data/web_data.json is byte for byte current
--      (otherwise: luajit tools/web_data/export.lua);
--   V  versions and limits: schema 1, the appearance version and both byte
--      caps positive integers;
--   T  the texture files: sorted, unique, PNG names; a repository file exists
--      at its path and follows the grammar's file rule, an engine texture
--      carries no path;
--   L  the level table: level 1 at 0 XP, strictly rising, max_level entries;
--   F  factions, races and classes: unique ids, a name each, faction colours
--      as #rrggbb, every race of a listed faction with its stature as a
--      uniform visual size, every class icon on disk;
--   M  the model: the .b3d (and the .glb of tools/web_data/model) on disk,
--      the frame rate and the stand and walk ranges;
--   W  the hand attachment: every race x every pose, numbers only;
--   I  the items: every hand item equippable, its wield image's PNGs among
--      the texture files; every equippable item named and its inventory
--      image's PNGs in the game's media.
-- Prints "R39 WE PORTABLE PASS checks=<n>" or the failures.

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

local function exists(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

local function is_int(value)
	return type(value) == "number" and value == math.floor(value)
end

local function pngs(texture)
	local out = {}
	for name in texture:gmatch("[%w_%.%-]+%.png") do out[#out + 1] = name end
	return out
end

local web_data = dofile(ROOT .. "/tools/web_data/build.lua")
local ok, data = pcall(web_data.build, ROOT)
if not ok then
	print("FAIL the export does not build: " .. tostring(data))
	print("R39 WE PORTABLE FAIL")
	os.exit(1)
end

-- C. The committed file is current.
local text = web_data.encode(data)
check(web_data.encode(data) == text, "C the encoding is deterministic")
local handle = io.open(ROOT .. "/tools/web_data/web_data.json", "rb")
local committed = handle and handle:read("*a")
if handle then handle:close() end
check(committed == text, "C tools/web_data/web_data.json is current " ..
	"(run luajit tools/web_data/export.lua)")

-- V. Versions and limits.
check(data.schema == 1, "V schema is 1")
check(is_int(data.appearance_version) and data.appearance_version >= 1,
	"V appearance_version is a positive integer")
local limits = data.appearance_limits
check(is_int(limits.texture_max_bytes) and limits.texture_max_bytes > 0,
	"V texture_max_bytes is a positive integer")
check(is_int(limits.json_max_bytes) and limits.json_max_bytes > limits.texture_max_bytes,
	"V json_max_bytes is an integer above texture_max_bytes")
check(type(data.texture_grammar) == "table" and next(data.texture_grammar) ~= nil,
	"V the texture grammar is present")

-- T. Texture files.
local texture_names = {}
local file_rule = data.texture_grammar.file or {}
local file_pattern = "^[" .. tostring(file_rule.charset) .. "]+" ..
	tostring(file_rule.suffix):gsub("%p", "%%%0") .. "$"
check(#data.texture_files > 0, "T texture files listed")
for index, entry in ipairs(data.texture_files) do
	local label = "T " .. tostring(entry.name)
	check(type(entry.name) == "string" and entry.name:match("^[%w_%.%-]+%.png$") ~= nil,
		label .. " is a PNG name")
	check(index == 1 or data.texture_files[index - 1].name < entry.name,
		label .. " sorted and unique")
	if entry.engine == true then
		check(entry.path == nil, label .. " (engine) has no path")
	else
		check(entry.engine == false and type(entry.path) == "string" and
			entry.path:sub(-#entry.name - 1) == "/" .. entry.name and exists(entry.path),
			label .. " exists at its path")
		check(entry.name:match(file_pattern) ~= nil and
			#entry.name <= data.texture_grammar.args.file.max_length,
			label .. " follows the grammar's file rule")
	end
	texture_names[entry.name] = true
end

-- L. Levels.
local levels = data.levels
check(is_int(levels.max_level) and #levels.start_xp == levels.max_level,
	"L one start per level")
check(levels.start_xp[1] == 0, "L level 1 starts at 0 XP")
for level = 2, #levels.start_xp do
	check(is_int(levels.start_xp[level]) and
		levels.start_xp[level] > levels.start_xp[level - 1],
		"L level " .. level .. " starts above level " .. (level - 1))
end

-- F. Factions, races, classes.
local faction_ids, race_ids = {}, {}
for _, faction in ipairs(data.factions) do
	check(not faction_ids[faction.id], "F faction " .. faction.id .. " unique")
	faction_ids[faction.id] = true
	check(type(faction.name) == "string" and faction.name ~= "",
		"F faction " .. faction.id .. " named")
	check(type(faction.color) == "string" and
		faction.color:match("^#%x%x%x%x%x%x$") ~= nil, "F faction " .. faction.id .. " colour")
end
check(#data.factions == 2, "F two factions")
for _, race in ipairs(data.races) do
	check(not race_ids[race.id], "F race " .. race.id .. " unique")
	race_ids[race.id] = true
	check(type(race.name) == "string" and race.name ~= "", "F race " .. race.id .. " named")
	check(faction_ids[race.faction] == true, "F race " .. race.id .. " of a listed faction")
	local size = race.visual_size
	check(size.x == size.y and size.y == size.z and
		size.x >= grug_visuals.STATURE_MIN and size.x <= grug_visuals.STATURE_MAX,
		"F race " .. race.id .. " visual size uniform and in the stature window")
end
for id in pairs(grug_classes.registered_races) do
	check(race_ids[id] == true, "F registered race " .. id .. " exported")
end
local class_ids = {}
for _, class in ipairs(data.classes) do
	check(not class_ids[class.id], "F class " .. class.id .. " unique")
	class_ids[class.id] = true
	check(type(class.name) == "string" and class.name ~= "", "F class " .. class.id .. " named")
	check(exists(class.icon), "F class " .. class.id .. " icon on disk")
end
for id in pairs(grug_classes.registered_classes) do
	check(class_ids[id] == true, "F registered class " .. id .. " exported")
end

-- M. Model.
local model = data.model
check(exists(model.b3d), "M the .b3d exists")
check(exists(model.gltf), "M the .glb exists (lane WG)")
check(is_int(model.fps) and model.fps > 0, "M frame rate")
check(#model.textures == 2 and model.textures[1] == "body" and model.textures[2] == "cloak",
	"M texture slots body, cloak")
for _, name in ipairs({"stand", "walk"}) do
	local range = model.animations[name]
	check(range and is_int(range.start) and is_int(range["end"]) and
		range.start >= 0 and range.start < range["end"], "M " .. name .. " frame range")
end

-- W. Wield transforms.
local wield = data.wield
check(type(wield.bone) == "string" and wield.bone ~= "", "W bone named")
local pose_count = 0
for _ in pairs(grug_visuals.POSE) do pose_count = pose_count + 1 end
check(#wield.poses == pose_count, "W every pose listed")
local function vec_ok(v, axes)
	for _, axis in ipairs(axes) do
		if type(v[axis]) ~= "number" then return false end
	end
	return true
end
for _, race in ipairs(data.races) do
	for _, pose in ipairs(wield.poses) do
		local t = wield.races[race.id] and wield.races[race.id][pose]
		check(t and vec_ok(t.pos, {"x", "y", "z"}) and vec_ok(t.rot, {"x", "y", "z"}) and
			vec_ok(t.size, {"x", "y"}) and t.size.x > 0,
			"W " .. race.id .. " " .. pose .. " transform")
	end
end

-- I. Items.
local media = {}
local pipe = assert(io.popen("cd '" .. ROOT .. "' && find mods -path '*/textures/*.png'"))
for path in pipe:lines() do media[path:match("[^/]+$")] = true end
pipe:close()
local hand_count = 0
for name, item in pairs(data.hand_items) do
	hand_count = hand_count + 1
	check(data.equippable_items[name] ~= nil, "I hand item " .. name .. " equippable")
	local images = pngs(item.wield_image)
	check(#images > 0, "I hand item " .. name .. " has a wield image")
	for _, png in ipairs(images) do
		check(texture_names[png] == true, "I hand item " .. name .. ": " .. png ..
			" among the texture files")
	end
	check(vec_ok(item.wield_scale, {"x", "y", "z"}), "I hand item " .. name .. " wield scale")
end
check(hand_count > 0, "I hand items listed")
for name, item in pairs(data.equippable_items) do
	check(type(item.name) == "string" and item.name ~= "" and not item.name:find("\n"),
		"I " .. name .. " named")
	local images = pngs(item.inventory_image)
	check(#images > 0, "I " .. name .. " has an inventory image")
	for _, png in ipairs(images) do
		check(media[png] == true, "I " .. name .. ": " .. png .. " in the game's media")
	end
end

if failures > 0 then
	print("R39 WE PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
	os.exit(1)
end
print("R39 WE PORTABLE PASS checks=" .. checks)
