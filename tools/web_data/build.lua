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
			races[#races + 1] = {id = id, name = def.name, faction = def.faction,
				visual_size = vec3(art.size)}
		end
	end

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
	assert(#model_def.textures == 2, "web_data: the player model has not two textures")
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
		textures = array({"body", "cloak"}),
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
	local hand_items, equippable = {}, {}
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

	return {
		schema = M.SCHEMA,
		appearance_version = contract.version,
		appearance_limits = {texture_max_bytes = contract.texture_max,
			json_max_bytes = contract.json_max},
		texture_grammar = plain(contract.grammar),
		texture_files = texture_files(root, contract.grammar),
		levels = {max_level = grug_xp.MAX_LEVEL, start_xp = start_xp},
		factions = factions,
		races = races,
		classes = classes,
		model = model,
		wield = wield,
		hand_items = hand_items,
		equippable_items = equippable,
	}
end

return M
