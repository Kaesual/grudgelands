-- The web-data export (round39-web-data-plan.md §3, §4.2): what a realm website
-- needs to show a character -- level curve, faction, race and class names, the
-- player model's frames, the hand attachment, the hand items' images and the
-- closed sets an appearance texture string stays inside. README.md next to
-- this file describes every field.
--
-- Route: LuaJIT with stubs. The REAL registration files run against a
-- permissive engine stub (every unknown `core.*` call is a no-op), so the
-- numbers, names and item lists are the game's own and nothing here keeps a
-- second copy of them. Engine callbacks (joins, mods_loaded, globalsteps) never
-- run; nothing exported depends on them. The item registrations come from
-- grug_gear, which registers every equippable item (a headless engine probe on
-- 2026-10-06 listed the same 156 equippable items); a mod that starts
-- registering equippable items joins `load_game` below.
--
-- Pure output: no time, no host path, keys sorted, lists in registration order
-- -- the committed web_data.json changes only when the game does.
--
--   local web_data = dofile(ROOT .. "/tools/web_data/build.lua")
--   local text = web_data.encode(web_data.build(ROOT))

local M = {}

-- The export's own format version; raised on any incompatible change to
-- web_data.json (README "Versions").
M.SCHEMA = 1

------------------------------------------------------------------------------
-- Deterministic JSON
------------------------------------------------------------------------------

local ARRAY = {}

-- Marks `t` as a JSON array (an empty Lua table is otherwise an object).
local function array(t)
	return setmetatable(t or {}, ARRAY)
end

local function encode_number(value)
	assert(value == value and value ~= math.huge and value ~= -math.huge,
		"web_data: a number is not finite")
	if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
		return string.format("%d", value)
	end
	-- Ten significant digits: exact for every authored value, and the same
	-- text on every platform for the derived ones (wield positions).
	local text = string.format("%.10g", value)
	return text
end

local function encode_string(value)
	return '"' .. value:gsub('[%c"\\]', function(char)
		if char == '"' then return '\\"' end
		if char == "\\" then return "\\\\" end
		if char == "\n" then return "\\n" end
		if char == "\t" then return "\\t" end
		return string.format("\\u%04x", char:byte())
	end) .. '"'
end

local encode_value

local function is_array(value)
	return getmetatable(value) == ARRAY
end

local function sorted_keys(value)
	local keys = {}
	for key in pairs(value) do
		assert(type(key) == "string", "web_data: an object key is not a string")
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

-- A container of scalars only goes on one line; everything else one entry per
-- line.
local function inline(value)
	local parts = {}
	if is_array(value) then
		for _, item in ipairs(value) do
			if type(item) == "table" then return nil end
			parts[#parts + 1] = encode_value(item, "")
		end
		return "[" .. table.concat(parts, ", ") .. "]"
	end
	for _, key in ipairs(sorted_keys(value)) do
		if type(value[key]) == "table" then return nil end
		parts[#parts + 1] = encode_string(key) .. ": " .. encode_value(value[key], "")
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

function encode_value(value, indent)
	local kind = type(value)
	if kind == "string" then return encode_string(value) end
	if kind == "number" then return encode_number(value) end
	if kind == "boolean" then return value and "true" or "false" end
	assert(kind == "table", "web_data: cannot encode a " .. kind)
	local one_line = inline(value)
	if one_line then return one_line end
	local inner = indent .. "  "
	local parts = {}
	if is_array(value) then
		for _, item in ipairs(value) do
			parts[#parts + 1] = inner .. encode_value(item, inner)
		end
		return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
	end
	for _, key in ipairs(sorted_keys(value)) do
		parts[#parts + 1] = inner .. encode_string(key) .. ": " ..
			encode_value(value[key], inner)
	end
	return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

function M.encode(data)
	return encode_value(data, "") .. "\n"
end

-- A plain deep copy of foreign data (the texture grammar): Lua
-- sequences become arrays, everything else objects with string keys.
local function plain(value)
	if type(value) ~= "table" then return value end
	local out = {}
	local n = #value
	local count = 0
	for _ in pairs(value) do count = count + 1 end
	if n > 0 and n == count then
		for index = 1, n do out[index] = plain(value[index]) end
		return array(out)
	end
	for key, item in pairs(value) do out[tostring(key)] = plain(item) end
	return out
end

------------------------------------------------------------------------------
-- Files
------------------------------------------------------------------------------

local function read(path)
	local handle = assert(io.open(path, "rb"), "web_data: cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end

local function exists(path)
	local handle = io.open(path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

-- The PNG names in one directory, sorted (byte order).
local function list_png(dir)
	local names = {}
	local pipe = assert(io.popen("ls -1 '" .. dir .. "' 2>/dev/null"))
	for name in pipe:lines() do
		if name:match("^[%w_%.%-]+%.png$") then names[#names + 1] = name end
	end
	pipe:close()
	table.sort(names)
	return names
end

------------------------------------------------------------------------------
-- Loading the game's registration files
------------------------------------------------------------------------------

local function permissive(base)
	return setmetatable(base or {}, {__index = function()
		return function() end
	end})
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = copy(item) end
	return out
end

-- Runs one `name = %b{}` assignment cut out of a file that cannot load whole
-- (grug_core/init.lua starts the whole world layout).
local function run_assignment(path, name)
	local escaped = name:gsub("[%.%-]", "%%%0")
	local block = read(path):match("\n(" .. escaped .. " = %b{})")
	assert(block, "web_data: " .. name .. " not found in " .. path)
	assert(loadstring(block, "=" .. name))()
end

local MODS = {
	player_api = "mods/BASE/player_api",
	grug_core = "mods/CORE/grug_core",
	grug_xp = "mods/PLAYER/grug_xp",
	grug_factions = "mods/PLAYER/grug_factions",
	grug_classes = "mods/PLAYER/grug_classes",
	grug_inventory = "mods/PLAYER/grug_inventory",
	grug_gear = "mods/ITEMS/grug_gear",
	grug_visuals = "mods/PLAYER/grug_visuals",
}

-- Sets the engine and mod globals the export reads. Returns the registered
-- items.
local function load_game(root)
	local items = {}
	local current = "player_api"
	core = permissive({
		registered_items = items,
		get_modpath = function(name)
			return MODS[name] and root .. "/" .. MODS[name] or nil
		end,
		get_current_modname = function() return current end,
		colorize = function(_, text) return text end,
		-- grug_visuals/init.lua reads grug_offhand_visuals (Round 55): the
		-- default, as on a server that never set it.
		settings = {get_bool = function(_, _, default) return default end},
		register_item = function(name, def) items[name] = def end,
		register_tool = function(name, def) items[name] = def end,
		register_craftitem = function(name, def) items[name] = def end,
		register_node = function(name, def) items[name] = def end,
	})
	minetest = core
	table.copy = table.copy or copy

	local function load(mod, file)
		current = mod
		dofile(root .. "/" .. MODS[mod] .. "/" .. file)
	end

	load("player_api", "init.lua")

	-- grug_core: the faction table and the class icons (a pure file), cut out
	-- of a mod whose init builds the world layout.
	grug_core = permissive({
		zone_authority_installed = function() return true end,
	})
	run_assignment(root .. "/" .. MODS.grug_core .. "/init.lua", "grug_core.factions")
	run_assignment(root .. "/" .. MODS.grug_core .. "/init.lua", "grug_core.faction_ids")
	load("grug_core", "status_icons.lua")

	load("grug_xp", "init.lua")
	load("grug_factions", "init.lua")

	-- grug_classes: the registry and the classes; of its sub-files only
	-- scout.lua registers one (the others are stats, talents and windows).
	do
		local real_dofile = dofile
		dofile = function(path)
			if path:match("/scout%.lua$") then return real_dofile(path) end
			return nil
		end
		current = "grug_classes"
		local ok, err = pcall(real_dofile, root .. "/" .. MODS.grug_classes .. "/init.lua")
		dofile = real_dofile
		assert(ok, err)
		-- grug_visuals registers its look panel through selection.lua, which
		-- stays unloaded.
		setmetatable(grug_classes, getmetatable(permissive()))
	end

	-- grug_inventory: only its equipment slot table (which list takes which
	-- group); the rest is the character window.
	grug_inventory = permissive({})
	run_assignment(root .. "/" .. MODS.grug_inventory .. "/equipment.lua",
		"grug_inventory.equipment_slots")

	load("grug_gear", "init.lua")
	load("grug_visuals", "init.lua")
	return items
end

------------------------------------------------------------------------------
-- The export
------------------------------------------------------------------------------

-- The appearance contract in grug_visuals (appearance.lua, plan §3): the
-- version, the two byte caps and the closed texture grammar, read and never
-- defaulted.
local function appearance_contract(gv)
	local function need(key, kind)
		local value = gv[key]
		assert(type(value) == kind, "web_data: grug_visuals." .. key ..
			" is not a " .. kind .. " (the appearance contract, plan §3)")
		return value
	end
	local grammar = need("APPEARANCE_TEXTURE", "table")
	assert(type(grammar.dirs) == "table" and type(grammar.engine_files) == "table",
		"web_data: the texture grammar names no directories or engine files")
	return {
		version = need("APPEARANCE_VERSION", "number"),
		texture_max = need("APPEARANCE_TEXTURE_MAX", "number"),
		json_max = need("APPEARANCE_JSON_MAX", "number"),
		grammar = grammar,
	}
end

-- Version 1 of the appearance (up to 0.53.x; Round 54 raised it to 2): a
-- character who has not joined since keeps such a value, whose body carries
-- the old armour overlays (README "Version 1 appearances"). Frozen history,
-- not read from the game, which no longer has it: the two byte caps and the
-- nesting depth of version 1, and every file a version 1 body named for a
-- worn piece -- the overlay `grug_visuals_<line>_<slot>_<grade>.png` of every
-- line, slot and grade (the grade keys of grug_gear.MATERIALS, which item ids
-- still carry), its enchant mask `..._ench.png` and the helmet's face window.
-- tools/r54_web checks the list against bodies the old game composed.
local V1 = {version = 1, texture_max_bytes = 2048, json_max_bytes = 10240, max_depth = 4,
	helmet_window = "grug_visuals_helmet_window.png"}

local function appearance_v1(gv)
	local files = {V1.helmet_window}
	for _, line in ipairs(gv.LINES) do
		for _, slot in ipairs(gv.SLOTS) do
			for _, materials in ipairs(grug_gear.MATERIALS) do
				local stem = "grug_visuals_" .. line .. "_" .. slot .. "_" .. materials[line].key
				files[#files + 1] = stem .. ".png"
				files[#files + 1] = stem .. "_ench.png"
			end
		end
	end
	table.sort(files)
	return {version = V1.version, texture_max_bytes = V1.texture_max_bytes,
		json_max_bytes = V1.json_max_bytes, max_depth = V1.max_depth,
		armor_files = array(files)}
end

-- Every PNG a stored texture string may name or a modifier may draw: the
-- files of the grammar's directories (repository paths) and its engine files.
local function texture_files(root, grammar)
	local files, seen = {}, {}
	local function add(entry)
		assert(not seen[entry.name], "web_data: texture " .. entry.name ..
			" is listed twice")
		seen[entry.name] = true
		files[#files + 1] = entry
	end
	for _, dir in ipairs(grammar.dirs) do
		local names = list_png(root .. "/" .. dir)
		assert(#names > 0, "web_data: no PNG in " .. dir)
		for _, name in ipairs(names) do
			add({name = name, engine = false, path = dir .. "/" .. name})
		end
	end
	for _, name in pairs(grammar.engine_files) do
		add({name = name, engine = true})
	end
	table.sort(files, function(a, b) return a.name < b.name end)
	return array(files)
end

-- The offhand look (Round 55, docs/technical/offhand-format.md; README "The
-- offhand look"): whether the game draws it, the baked layer files a stored
-- `textures.offhand` names, and the Scout's back card, which no appearance
-- stores. `enabled` is the setting's default at this commit (the stub in
-- load_game answers every get_bool with its default, as a server that never
-- set it), checked against the default settingtypes.txt states. `layers`
-- comes from the game's own offhand index (index_armor: item group and
-- bracket), one file per kind and bracket; the files ship with the finish
-- step's art, and texture_files lists them from then on. The back card's
-- class is apply.lua's local, its texture size and the two halves are what
-- grug_visuals.back_card writes.
local OFFHAND_SETTING = "grug_offhand_visuals"

local function offhand_look(root, gv, items)
	local default = read(root .. "/settingtypes.txt"):match("\n" ..
		OFFHAND_SETTING .. " %b() bool (%a+)")
	assert(default, "web_data: settingtypes.txt has no bool " .. OFFHAND_SETTING)
	local enabled = gv.OFFHAND_VISUALS == true
	assert(tostring(enabled) == default, "web_data: grug_visuals.OFFHAND_VISUALS (" ..
		tostring(enabled) .. ") is not the default settingtypes.txt gives " ..
		OFFHAND_SETTING .. " (" .. default .. ")")

	gv.index_armor(items)
	local layers = {}
	for name, entry in pairs(gv.offhand_appearance) do
		local list = layers[entry.kind] or array()
		layers[entry.kind] = list
		assert(list[entry.bracket] == nil or list[entry.bracket] == entry.file,
			"web_data: two offhand layers for " .. entry.kind .. " bracket " ..
			entry.bracket .. " (" .. name .. ")")
		list[entry.bracket] = entry.file
	end
	for kind, list in pairs(layers) do
		for bracket = 1, #grug_gear.BRACKETS do
			assert(list[bracket], "web_data: no " .. kind .. " layer for bracket " .. bracket)
		end
	end

	local class = read(root .. "/" .. MODS.grug_visuals .. "/apply.lua")
		:match('\nlocal BACK_CARD_CLASS = "([%w_]+)"')
	assert(class, "web_data: apply.lua names no BACK_CARD_CLASS")
	local function card(on_cloak)
		local w, h, x, y, rest = gv.back_card("x.png", on_cloak)
			:match("^%[combine:(%d+)x(%d+):(%d+),(%d+)=x%.png(.*)$")
		-- the image may be turned (counter-clockwise, as [transformR<deg>)
		local turn = rest == "" and "0" or rest and rest:match("^\\%^%[transformR(%d+)$")
		assert(w and y == "0" and turn, "web_data: grug_visuals.back_card wrote an unknown form")
		return tonumber(w), tonumber(h), tonumber(x), tonumber(turn)
	end
	local width, height, cloak_x, rotate = card(true)
	local body_width, body_height, body_x, body_rotate = card(false)
	assert(width == body_width and height == body_height and rotate == body_rotate,
		"web_data: the two back cards differ in size or turn")
	return {setting = OFFHAND_SETTING, enabled = enabled, layers = layers,
		back_card = {class = class, width = width, height = height,
			cloak_x = cloak_x, body_x = body_x, rotate = rotate}}
end

local function vec3(v)
	return {x = v.x, y = v.y, z = v.z}
end

-- The first line of an item description, colour escapes removed.
local function display_name(def, itemname)
	local text = type(def.description) == "string" and def.description or itemname
	text = text:gsub("\27%([^)]*%)", ""):gsub("\27.", "")
	return (text:gsub("\n.*", ""))
end

-- The image the hand entity draws: the world-wield override, else the wield
-- image, else the inventory image (grug_visuals.wield_appearance and the
-- engine's wielditem; per-stack meta is per character, in the appearance).
local function wield_image(def)
	if type(def._grug_world_wield_image) == "string" and def._grug_world_wield_image ~= "" then
		return def._grug_world_wield_image
	end
	if type(def.wield_image) == "string" and def.wield_image ~= "" then
		return def.wield_image
	end
	return def.inventory_image or ""
end

------------------------------------------------------------------------------
-- Character creation (Round 80.1, README "Character creation")
------------------------------------------------------------------------------

-- The width and height in the PNG's IHDR chunk (bytes 17-24, big-endian).
local function png_size(path)
	local handle = assert(io.open(path, "rb"), "web_data: cannot read " .. path)
	local head = handle:read(24) or ""
	handle:close()
	assert(#head == 24 and head:sub(1, 8) == "\137PNG\r\n\26\n" and
		head:sub(13, 16) == "IHDR", "web_data: " .. path .. " is not a PNG")
	local function u32(at)
		local a, b, c, d = head:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end

-- A strict, small JSON reader for the wide renders' anchor file: objects,
-- arrays, strings without escapes beyond \" \\ \/, numbers, true and false.
-- Anything else (null included) fails.
local function json_decode(text, source)
	local at = 1
	local function fail(what)
		error("web_data: " .. source .. ": " .. what .. " at byte " .. at, 0)
	end
	local function skip()
		at = text:find("[^ \t\r\n]", at) or #text + 1
	end
	local value
	local function string_value()
		local out, from = {}, at + 1
		while true do
			local stop = text:find('["\\]', from)
			if not stop then fail("an unterminated string") end
			out[#out + 1] = text:sub(from, stop - 1)
			if text:sub(stop, stop) == '"' then
				at = stop + 1
				return table.concat(out)
			end
			local escaped = text:sub(stop + 1, stop + 1)
			if not escaped:match('["\\/]') then fail("an unsupported escape") end
			out[#out + 1] = escaped
			from = stop + 2
		end
	end
	function value()
		skip()
		local char = text:sub(at, at)
		if char == "{" then
			local out = {}
			at = at + 1
			skip()
			if text:sub(at, at) == "}" then at = at + 1 return out end
			while true do
				skip()
				if text:sub(at, at) ~= '"' then fail("a key that is not a string") end
				local key = string_value()
				skip()
				if text:sub(at, at) ~= ":" then fail("a missing ':'") end
				at = at + 1
				if out[key] ~= nil then fail("the key " .. key .. " twice") end
				out[key] = value()
				skip()
				local sep = text:sub(at, at)
				at = at + 1
				if sep == "}" then return out end
				if sep ~= "," then fail("a missing ',' or '}'") end
			end
		elseif char == "[" then
			local out = {}
			at = at + 1
			skip()
			if text:sub(at, at) == "]" then at = at + 1 return out end
			while true do
				out[#out + 1] = value()
				skip()
				local sep = text:sub(at, at)
				at = at + 1
				if sep == "]" then return out end
				if sep ~= "," then fail("a missing ',' or ']'") end
			end
		elseif char == '"' then
			return string_value()
		end
		if text:sub(at, at + 3) == "true" then at = at + 4 return true end
		if text:sub(at, at + 4) == "false" then at = at + 5 return false end
		local number = text:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", at)
		if not number or not tonumber(number) then fail("an unknown value") end
		at = at + #number
		return tonumber(number)
	end
	local result = value()
	skip()
	if at <= #text then fail("text after the value") end
	return result
end

-- Where the creation pictures are and which licence file covers them. The
-- names are the creation window's (grug_classes/creation_window.lua); the
-- wide renders for the website live outside every mod (round80.1-plan.md
-- §3.1), with their own licence file and the figure anchors of their render
-- receipts in wide.json.
local CREATION = {
	textures = MODS.grug_classes .. "/textures/",
	license = MODS.grug_classes .. "/LICENSE-media.md",
	banners = "mods/MAPGEN/grug_mapgen/textures/",
	banner_license = "mods/MAPGEN/grug_mapgen/LICENSE-media.md",
	media = "tools/web_data/media/",
	media_license = "tools/web_data/media/LICENSE-media.md",
	anchors = "tools/web_data/media/wide.json",
	camera = MODS.grug_classes .. "/creation_camera.lua",
}

-- One picture: its repository path, its pixel size and the licence file that
-- names it. A missing picture, a missing licence file or a licence file that
-- does not name the picture fails the export.
local function creation_picture(root, path, license)
	assert(exists(root .. "/" .. path), "web_data: missing creation picture " .. path)
	assert(exists(root .. "/" .. license), "web_data: missing licence file " ..
		license .. " (for " .. path .. ")")
	local name = path:match("[^/]+$")
	assert(read(root .. "/" .. license):find(name, 1, true),
		"web_data: " .. license .. " does not name " .. name)
	local width, height = png_size(root .. "/" .. path)
	return {path = path, width = width, height = height, license = license}
end

-- The figure anchor of a wide race picture (common brief of Round 80.1):
-- `x`, `y` the standing point as fractions of the picture's width and height
-- (0,0 top left), `node` the screen height of one node standing upright there
-- as a fraction of the picture's height.
local function figure_anchor(entry, race)
	local figure = type(entry) == "table" and entry.figure
	assert(type(figure) == "table", "web_data: " .. CREATION.anchors ..
		" has no figure for " .. race)
	local out = {}
	for _, key in ipairs({"x", "y", "node"}) do
		local value = figure[key]
		assert(type(value) == "number" and value > 0 and value < 1,
			"web_data: " .. CREATION.anchors .. ": " .. race .. ".figure." .. key ..
			" is not a fraction")
		out[key] = value
	end
	for key in pairs(figure) do
		assert(out[key], "web_data: " .. CREATION.anchors .. ": " .. race ..
			".figure has the unknown field " .. key)
	end
	return out
end

-- The camera the creation window's model preview uses
-- (grug_visuals/creation.lua), as tools/character_creation_preview/native.py
-- generated it; the field of view is the engine's fixed GUIScene value the
-- generated comment names.
local function creation_camera(root)
	local path = root .. "/" .. CREATION.camera
	local camera = dofile(path)
	local out = {}
	for _, key in ipairs({"height_fraction", "aspect", "pitch", "scene_aspect"}) do
		assert(type(camera[key]) == "number", "web_data: " .. CREATION.camera ..
			" has no number " .. key)
		out[key] = camera[key]
	end
	local fov = read(path):match("%-%-[^\n]-(%d+)%-degree vertical FOV")
	assert(fov, "web_data: " .. CREATION.camera .. " names no vertical FOV")
	out.fov = tonumber(fov)
	return out
end

-- A registered race's or class's description, as the creation window shows it
-- (line breaks included).
local function description(def, what)
	assert(type(def.description) == "string" and def.description ~= "",
		"web_data: " .. what .. " " .. def.id .. " has no description")
	return def.description
end

-- The look per race: the stored `grug_visuals:appearance` value (as a table)
-- of a character of that race with option 1 in every look category, no cloak
-- and nothing worn or held -- built as apply.lua builds it, so its body is
-- the race's `bare_body`.
local function race_appearance(gv, race)
	local spec = {race = race}
	return gv.appearance(spec, gv.compose(spec), gv.CLOAK_NONE, nil, gv.WINGS_NONE)
end

local function creation(root, gv, races, classes)
	local anchors_path = root .. "/" .. CREATION.anchors
	assert(exists(anchors_path), "web_data: missing " .. CREATION.anchors ..
		" (the wide renders' figure anchors)")
	local anchors = json_decode(read(anchors_path), CREATION.anchors)
	assert(type(anchors) == "table", "web_data: " .. CREATION.anchors .. " is not an object")

	local function own(name)
		return creation_picture(root, CREATION.textures .. name, CREATION.license)
	end
	local function wide(name)
		return creation_picture(root, CREATION.media .. name, CREATION.media_license)
	end

	local intro = own("grug_creation_intro.png")
	intro.wide = wide("grug_creation_intro_wide.png")

	local factions = {}
	for _, id in ipairs(grug_core.faction_ids) do
		factions[id] = {banner = creation_picture(root, CREATION.banners ..
			"grug_mapgen_faction_banner_" .. id .. ".png", CREATION.banner_license)}
	end

	local by_race = {}
	for _, race in ipairs(races) do
		local id = race.id
		local backdrop = own("grug_creation_" .. id .. ".png")
		backdrop.wide = wide("grug_creation_" .. id .. "_wide.png")
		backdrop.wide.figure = figure_anchor(anchors[id], id)
		by_race[id] = {backdrop = backdrop, icon = own("grug_race_" .. id .. ".png"),
			description = description(grug_classes.registered_races[id], "race"),
			appearance = race_appearance(gv, id)}
	end
	for id in pairs(anchors) do
		assert(by_race[id], "web_data: " .. CREATION.anchors .. " names " .. id ..
			", which is no exported race")
	end

	local by_class = {}
	for _, class in ipairs(classes) do
		by_class[class.id] = {description = description(
			grug_classes.registered_classes[class.id], "class")}
	end

	return {camera = creation_camera(root), intro = intro,
		crest = own("grug_creation_crest.png"), factions = factions,
		races = by_race, classes = by_class}
end

-- Which equipment list is which appearance slot (plan §2.4).
local LIST_SLOT = {
	grug_head = "head", grug_chest = "chest", grug_legs = "legs",
	grug_feet = "feet", grug_weapon = "mainhand", grug_offhand = "offhand",
	grug_trinket1 = "trinket", grug_trinket2 = "trinket",
}
local HAND_SLOT = {mainhand = true, offhand = true}

function M.build(root)
	local items = load_game(root)
	local gv = grug_visuals
	local contract = appearance_contract(gv)

	-- Levels: start_xp[i] is the XP at which level i starts (1-based in Lua,
	-- index 0 in the JSON array is level 1).
	local start_xp = array()
	for level = 1, grug_xp.MAX_LEVEL do
		start_xp[level] = grug_xp.xp_for_level(level)
	end

	local factions = array()
	for _, id in ipairs(grug_core.faction_ids) do
		local def = grug_core.factions[id]
		factions[#factions + 1] = {id = id, name = grug_factions.display_name(id),
			color = def.color}
	end

	local races = array()
	for _, faction in ipairs(grug_core.faction_ids) do
		for _, id in ipairs(grug_classes.race_ids[faction] or {}) do
			local def = grug_classes.registered_races[id]
			local art = assert(gv.RACES[id], "web_data: race " .. id .. " has no art")
			-- A new character's body: option 1 in every look category,
			-- nothing worn (the fallback for a body a website cannot use).
			races[#races + 1] = {id = id, name = def.name, faction = def.faction,
				visual_size = vec3(art.size), bare_body = gv.compose({race = id}).skin}
		end
	end

	-- The class list the party UI draws icons for is the second source: a
	-- class registered in a sub-file this loader skips would otherwise be
	-- missing without a word.
	local class_list = table.concat(grug_classes.class_ids, ",")
	assert(class_list == table.concat(grug_core.status_icons.CLASSES, ","),
		"web_data: registered classes " .. class_list .. " differ from " ..
		"grug_core.status_icons.CLASSES")
	local classes = array()
	for _, id in ipairs(grug_classes.class_ids) do
		local def = grug_classes.registered_classes[id]
		local icon = grug_core.status_icons.class_icon(id)
		assert(icon ~= "", "web_data: class " .. id .. " has no icon")
		local path = MODS.grug_classes .. "/textures/" .. icon
		assert(exists(root .. "/" .. path), "web_data: missing " .. path)
		classes[#classes + 1] = {id = id, name = def.name, icon = path}
	end

	-- The player model: the file, its texture slots and the two frame ranges.
	local model_def = assert(player_api.registered_models[gv.PLAYER_MODEL],
		"web_data: the player model is not registered")
	assert(#model_def.textures == 7, "web_data: the player model has not seven textures")
	local b3d = MODS.grug_visuals .. "/models/" .. gv.PLAYER_MODEL
	assert(exists(root .. "/" .. b3d), "web_data: missing " .. b3d)
	local animations = {}
	for _, name in ipairs({"stand", "walk"}) do
		local range = model_def.animations[name]
		animations[name] = {start = range.x, ["end"] = range.y}
	end
	local model = {
		b3d = b3d,
		gltf = "tools/web_data/model/" .. gv.PLAYER_MODEL:gsub("%.b3d$", ".glb"),
		textures = array({"body", "cloak", "armor", "weapon", "offhand", "back", "wings"}),
		fps = model_def.animation_speed,
		animations = animations,
	}

	-- The hand attachment per race and pose (wield_geometry.lua): a player's
	-- weapon is compensated for its race's stature.
	local poses = {}
	for _, pose in pairs(gv.POSE) do poses[#poses + 1] = pose end
	table.sort(poses)
	local by_race = {}
	for _, race in ipairs(races) do
		local per_pose = {}
		for _, pose in ipairs(poses) do
			local t = gv.wield_transform(gv.RACES[race.id].stature, pose)
			per_pose[pose] = {pos = vec3(t.pos), rot = vec3(t.rot),
				size = {x = t.size.x, y = t.size.y}}
		end
		by_race[race.id] = per_pose
	end
	local wield = {bone = gv.WIELD.bone, poses = array(poses), races = by_race}

	-- Items, by the equipment groups the slot lists take.
	local list_group = {}
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		assert(LIST_SLOT[slot.list], "web_data: unknown equipment list " .. slot.list)
		list_group[slot.list] = slot.group
	end
	local hand_items, equippable, list_items = {}, {}, {}
	local names = {}
	for name in pairs(items) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local def = items[name]
		local groups = def.groups or {}
		local equip, hand = false, false
		for list, group in pairs(list_group) do
			if (groups[group] or 0) > 0 then
				equip = true
				list_items[list] = (list_items[list] or 0) + 1
				hand = hand or HAND_SLOT[LIST_SLOT[list]] == true
			end
		end
		if equip then
			equippable[name] = {name = display_name(def, name),
				inventory_image = def.inventory_image or ""}
		end
		if hand then
			hand_items[name] = {wield_image = wield_image(def),
				wield_scale = vec3(def.wield_scale or {x = 1, y = 1, z = 1})}
		end
	end

	-- Every equipment list takes at least one exported item: a registration
	-- the stub missed fails here instead of shrinking the export.
	for list in pairs(list_group) do
		assert(list_items[list], "web_data: no exported item fits " .. list)
	end

	return {
		schema = M.SCHEMA,
		appearance_version = contract.version,
		appearance_limits = {texture_max_bytes = contract.texture_max,
			json_max_bytes = contract.json_max},
		appearance_v1 = appearance_v1(gv),
		texture_grammar = plain(contract.grammar),
		texture_files = texture_files(root, contract.grammar),
		levels = {max_level = grug_xp.MAX_LEVEL, start_xp = start_xp},
		factions = factions,
		races = races,
		classes = classes,
		creation = creation(root, gv, races, classes),
		model = model,
		offhand_look = offhand_look(root, gv, items),
		wield = wield,
		hand_items = hand_items,
		equippable_items = equippable,
	}
end

return M
