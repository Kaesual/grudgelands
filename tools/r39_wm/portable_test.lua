-- Round 39 lane WM portable test (LuaJIT): the player meta the realm website
-- reads (round39-web-data-plan.md §2.1, §3, §4.1).
--
--   luajit tools/r39_wm/portable_test.lua [REPO]
--   luajit tools/r39_wm/portable_test.lua REPO examples   (prints two values)
--
-- Loads the REAL grug_gear, grug_quality, grug_repair (service and
-- presentation), grug_achievements' rules and catalogue, grug_xp and every
-- grug_visuals file but the creation panel, under a permissive engine stub
-- with ItemStack metadata and wear, and drives grug_visuals.apply on fake
-- players. Checks:
--   L  `grug_xp:level`: written on every XP change and on join, recomputed
--      from XP, capped at 60, a decimal integer string;
--   A  `grug_visuals:appearance`: valid JSON in the contract's shape for an
--      empty, a full, a broken, an enchanted, a Scout and a shield/spellbook
--      loadout; a hand slot's item, broken state and enchant update it; no
--      write when nothing changed (also across a rejoin); the wielded item
--      never appears;
--   G  the closed texture grammar: every body (every race and look, bare and
--      under the worst armour), every cloak and every hand image (every item,
--      plain, enchanted, broken) parses under grug_visuals.APPEARANCE_TEXTURE,
--      names only files in its directories and stays within
--      APPEARANCE_TEXTURE_MAX; the worst-case JSON within APPEARANCE_JSON_MAX.
-- Prints the measured maxima and "R39 WM PORTABLE PASS checks=<n>", or the
-- failures.

local ROOT = arg and arg[1] or "."
local MODE = arg and arg[2] or "test"
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
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read_file(path)
	local handle = assert(io.open(path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function file_exists(path)
	local handle = io.open(path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

------------------------------------------------------------------------------
-- Engine stub: unknown functions are no-ops; items, callbacks recorded.
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function()
		return function() end
	end})
end
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
	grug_repair = ROOT .. "/mods/ITEMS/grug_repair",
	grug_visuals = ROOT .. "/mods/PLAYER/grug_visuals",
	grug_xp = ROOT .. "/mods/PLAYER/grug_xp",
}
local current_mod = "grug_gear"
local serial = {}
local joins, leaves, equipment_consumers, globalsteps = {}, {}, {}, {}
core = permissive({
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_node = function(name, def) registered[name] = def end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = {mod = current_mod, fn = fn} end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = {mod = current_mod, fn = fn} end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	get_connected_players = function() return {} end,
	add_entity = function()
		local obj = {}
		function obj:set_properties() end
		function obj:set_attach() end
		function obj:get_attach() return true end
		function obj:get_pos() return {x = 0, y = 0, z = 0} end
		function obj:remove() end
		return obj
	end,
})
table.copy = table.copy or function(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = table.copy(item) end
	return out
end
vector = permissive({offset = function(pos) return pos end, new = function(x, y, z)
	return {x = x, y = y, z = z} end})

grug_core = permissive({
	level_scale = function() return 1 end,
	register_on_equipment_change = function(fn) equipment_consumers[#equipment_consumers + 1] = fn end,
	hud_layout = permissive({XP_WIDTH = 100, COLOR = {}, rows = {xp = {height = 4}},
		bar_fill = function(value, total, width) return math.floor(width * value / total) end}),
})
-- The real broken predicate, cut out of combat.lua.
do
	local body = read_file(ROOT .. "/mods/CORE/grug_core/combat.lua")
		:match("\n(function grug_core%.equipment_is_broken%(.-\nend)\n")
	check(body ~= nil, "equipment_is_broken found in combat.lua")
	assert(loadstring(body))()
end
grug_classes = permissive({get_melee_bonus = function() return 0 end,
	talent_points_at = function(level) return level end,
	registered_races = {}, race_ids = {}})
grug_mobs = permissive({})
grug_inventory = permissive({})
grug_jobs = permissive({})
grug_sounds = permissive({})
grug_xp = permissive({get_level = function() return 10 end})

-- ItemStack with real metadata semantics (set_string("") removes a key), wear
-- and copies (ItemStack(stack) copies name, wear and metadata).
local function new_meta(fields)
	fields = fields or {}
	local meta = {fields = fields}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = value end
	end
	function meta:get_int(key) return tonumber(fields[key]) or 0 end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
ItemStack = function(source)
	local name, wear, fields = source or "", 0, {}
	if type(source) == "table" then
		name, wear = source:get_name(), source:get_wear()
		for key, value in pairs(source:get_meta().fields) do fields[key] = value end
	end
	local meta = new_meta(fields)
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_count() return name == "" and 0 or 1 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return wear end
	function stack:set_wear(value) wear = value end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	function stack:to_string()
		local keys = {}
		for key in pairs(meta.fields) do keys[#keys + 1] = key end
		table.sort(keys)
		local out = name
		for _, key in ipairs(keys) do out = out .. " " .. key .. "=" .. meta.fields[key] end
		return out
	end
	return stack
end
PcgRandom = function(seed)
	local state = seed
	return {next = function(_, low, high)
		state = (state * 1103515245 + 12345) % 2147483648
		return low + state % (high - low + 1)
	end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
current_mod = "grug_repair"
grug_repair = {}
dofile(ROOT .. "/mods/ITEMS/grug_repair/service.lua")
dofile(ROOT .. "/mods/ITEMS/grug_repair/presentation.lua")

-- grug_achievements' pure rules on the real catalogue: the cloak source its
-- init.lua installs (texture and selected id).
local R = dofile(ROOT .. "/mods/PLAYER/grug_achievements/core.lua")
local book = R.build(dofile(ROOT .. "/mods/PLAYER/grug_achievements/catalog.lua"))

-- player_api's record of the base model, which apply.lua copies.
local textures_set = {}
player_api = {
	registered_models = {["character.b3d"] = {animation_speed = 30,
		textures = {"character.png"}, animations = {stand = {x = 0, y = 79}},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}, stepheight = 0.6,
		eye_height = 1.47}},
	register_model = function() end,
	set_model = function() end,
	set_textures = function(player, list)
		textures_set[player:get_player_name()] = (textures_set[player:get_player_name()] or 0) + 1
	end,
}

-- Races and the per-player stand-ins grug_visuals reads at call time.
for _, id in ipairs({"human", "dwarf", "elf", "orc", "troll", "undead"}) do
	grug_classes.registered_races[id] = {id = id}
end
grug_classes.get_race = function(player) return player._race end
local HAND_LIST = {weapon = "grug_weapon", offhand = "grug_offhand"}
local function slot_copy(player, list)
	local stack = player:get_inventory():get_stack(list, 1)
	return not stack:is_empty() and ItemStack(stack) or nil
end
grug_inventory.get_cosmetic_weapon = function(player) return slot_copy(player, "grug_weapon") end
grug_inventory.get_cosmetic_offhand = function(player) return slot_copy(player, "grug_offhand") end
grug_inventory.get_cosmetic_hand = function(player, slot)
	return slot_copy(player, HAND_LIST[slot] or "grug_weapon")
end

current_mod = "grug_visuals"
grug_visuals = {}
for _, file in ipairs({"looks", "compose", "enchant", "wield_geometry", "appearance", "apply"}) do
	dofile(ROOT .. "/mods/PLAYER/grug_visuals/" .. file .. ".lua")
end
grug_visuals.index_armor(registered)
grug_visuals.register_cloak_source(function(player)
	-- The body of grug_achievements' registration (checked against it below).
	local meta = player:get_meta()
	return R.cloak_texture(book, meta), R.selected(book, meta)
end)
check(read_file(ROOT .. "/mods/PLAYER/grug_achievements/init.lua"):find(
	"return R.cloak_texture(book, meta), R.selected(book, meta)", 1, true) ~= nil,
	"grug_achievements' cloak source returns the texture and the selected id")

current_mod = "grug_xp"
grug_xp = nil
dofile(ROOT .. "/mods/PLAYER/grug_xp/init.lua")

local V = grug_visuals
local META = V.APPEARANCE_META
local TEX = V.APPEARANCE_TEXTURE

------------------------------------------------------------------------------
-- Fake players.
------------------------------------------------------------------------------
local writes = {}
local function new_player(name, race)
	local fields, lists, writes_of = {}, {}, {}
	writes[name] = writes_of
	local meta = new_meta(fields)
	local set_string = meta.set_string
	function meta:set_string(key, value)
		writes_of[key] = (writes_of[key] or 0) + 1
		set_string(self, key, value)
	end
	local inv = {}
	function inv:get_stack(list, index)
		local stack = lists[list] and lists[list][index]
		return stack and ItemStack(stack) or ItemStack("")
	end
	function inv:set_stack(list, index, stack)
		lists[list] = lists[list] or {}
		lists[list][index] = ItemStack(stack)
	end
	local player = {_race = race, _wielded = ItemStack("")}
	function player:is_player() return true end
	function player:get_player_name() return name end
	function player:get_meta() return meta end
	function player:get_inventory() return inv end
	function player:get_wielded_item() return ItemStack(self._wielded) end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:set_properties() end
	function player:hud_add() return 1 end
	function player:hud_change() end
	return player
end

local function join(player, mod)
	for _, row in ipairs(joins) do
		if row.mod == mod then row.fn(player) end
	end
end
local function leave(player)
	for _, row in ipairs(leaves) do row.fn(player) end
end
-- An equipment write as the game does it: the list, then the seam.
local function equip(player, list, stack, reason)
	player:get_inventory():set_stack(list, 1, stack or ItemStack(""))
	for _, fn in ipairs(equipment_consumers) do fn(player, list, reason) end
end

-- A gear stack as the game holds it: affixes in meta, the enchant image by
-- grug_quality, the cracks by grug_repair.
local function gear_stack(name, prefix, suffix, broken)
	local stack = ItemStack(name)
	local affixes = {}
	if prefix then affixes[#affixes + 1] = {channel = "prefix", stat = prefix, tier = 3, value = 5} end
	if suffix then affixes[#affixes + 1] = {channel = "suffix", stat = suffix, tier = 3, value = 5} end
	if #affixes > 0 then
		stack:get_meta():set_string("grug_ench", core.serialize(affixes))
	end
	grug_items.refresh_enchant_image(stack, affixes)
	if broken then stack:set_wear(65535) end
	grug_repair.refresh_appearance(stack)
	return stack
end

------------------------------------------------------------------------------
-- A tiny JSON reader: the stored value must be valid JSON.
------------------------------------------------------------------------------
local function json_decode(text)
	local pos = 1
	local function fail(what) error("JSON: " .. what .. " at " .. pos, 0) end
	local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
	local value
	local function str()
		pos = pos + 1
		local out = {}
		while true do
			local char = text:sub(pos, pos)
			if char == "" then fail("unterminated string") end
			if char == '"' then pos = pos + 1; return table.concat(out) end
			if char == "\\" then
				local esc = text:sub(pos + 1, pos + 1)
				if esc == "u" then
					out[#out + 1] = string.char(tonumber(text:sub(pos + 2, pos + 5), 16))
					pos = pos + 6
				else
					out[#out + 1] = ({['"'] = '"', ["\\"] = "\\", n = "\n"})[esc] or fail("escape")
					pos = pos + 2
				end
			else
				if char:byte() < 32 then fail("control character") end
				out[#out + 1] = char
				pos = pos + 1
			end
		end
	end
	value = function()
		skip()
		local char = text:sub(pos, pos)
		if char == "{" then
			local out = {}
			pos = pos + 1; skip()
			if text:sub(pos, pos) == "}" then pos = pos + 1; return out end
			while true do
				skip()
				if text:sub(pos, pos) ~= '"' then fail("key") end
				local key = str(); skip()
				if text:sub(pos, pos) ~= ":" then fail("colon") end
				pos = pos + 1
				out[key] = value(); skip()
				local sep = text:sub(pos, pos); pos = pos + 1
				if sep == "}" then return out end
				if sep ~= "," then fail("object separator") end
			end
		elseif char == "[" then
			local out = {}
			pos = pos + 1; skip()
			if text:sub(pos, pos) == "]" then pos = pos + 1; return out end
			while true do
				out[#out + 1] = value(); skip()
				local sep = text:sub(pos, pos); pos = pos + 1
				if sep == "]" then return out end
				if sep ~= "," then fail("array separator") end
			end
		elseif char == '"' then
			return str()
		elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
		elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
		else
			local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			if not number or number == "" then fail("value") end
			pos = pos + #number
			return tonumber(number)
		end
	end
	local result = value(); skip()
	if pos <= #text then fail("trailing data") end
	return result
end

------------------------------------------------------------------------------
-- The grammar: a parser built from APPEARANCE_TEXTURE alone.
------------------------------------------------------------------------------
local used_modifiers, used_files, max_depth_seen = {}, {}, 0
local file_dir = {}
local function file_known(name)
	if file_dir[name] == nil then
		file_dir[name] = false
		for _, dir in ipairs(TEX.dirs) do
			if file_exists(ROOT .. "/" .. dir .. "/" .. name) then file_dir[name] = dir end
		end
	end
	return file_dir[name]
end
local FILE_PATTERN = "^[" .. TEX.file.charset .. "]+" .. TEX.file.suffix:gsub("%.", "%%.")
-- Argument patterns straight from the data, and the file rule agreeing with
-- the file kind.
local ARG_PATTERN = {}
for kind, spec in pairs(TEX.args) do ARG_PATTERN[kind] = spec.pattern end

-- Returns nil or the reason the string is outside the grammar.
local function grammar_error(text)
	local pos = 1
	local chain
	local function file()
		local name = text:match(FILE_PATTERN, pos)
		if not name then return nil, "file expected at " .. pos end
		if not name:find(ARG_PATTERN.file) or #name > TEX.args.file.max_length then
			return nil, "file " .. name .. " outside the file kind"
		end
		if not file_known(name) then return nil, "file " .. name .. " in none of the directories" end
		used_files[name] = true
		pos = pos + #name
		return true
	end
	local function modifier()
		local name = text:match("^[a-z]+", pos)
		local spec = name and TEX.modifiers[name]
		if not spec then return nil, "modifier " .. tostring(name) .. " not in the set" end
		used_modifiers[name] = true
		pos = pos + #name
		for _, kind in ipairs(spec) do
			if text:sub(pos, pos) ~= ":" then return nil, name .. ": too few arguments" end
			pos = pos + 1
			if kind == "file" then
				local ok, why = file()
				if not ok then return nil, why end
			else
				local arg = text:match("^[^%^:%(%)%[]+", pos) or ""
				local value = tonumber(arg)
				if not arg:find(ARG_PATTERN[kind]) or (kind == "int" and
						(value < TEX.args.int.min or value > TEX.args.int.max)) then
					return nil, name .. ": argument " .. arg .. " is no " .. kind
				end
				pos = pos + #arg
			end
		end
		return true
	end
	local function part(depth, first)
		local char = text:sub(pos, pos)
		if char == "(" then
			if depth + 1 > TEX.max_depth then return nil, "deeper than max_depth" end
			if depth + 1 > max_depth_seen then max_depth_seen = depth + 1 end
			pos = pos + 1
			local ok, why = chain(depth + 1)
			if not ok then return nil, why end
			if text:sub(pos, pos) ~= ")" then return nil, "unclosed group at " .. pos end
			pos = pos + 1
			return true
		elseif char == "[" then
			if first then return nil, "a chain starts with a modifier at " .. pos end
			pos = pos + 1
			return modifier()
		end
		return file()
	end
	chain = function(depth)
		local ok, why = part(depth, true)
		if not ok then return nil, why end
		while text:sub(pos, pos) == "^" do
			pos = pos + 1
			ok, why = part(depth, false)
			if not ok then return nil, why end
		end
		return true
	end
	if text:find("\\", 1, true) then return "escape character" end
	local ok, why = chain(0)
	if not ok then return why end
	if pos <= #text then return "trailing text at " .. pos end
	return nil
end

-- One stored string: grammar and cap, longest per kind remembered.
local longest = {body = "", cloak = "", hand = ""}
local function texture_ok(kind, text, label)
	local why = grammar_error(text)
	if not check(why == nil, "G " .. label .. " parses: " .. tostring(why) .. " in " .. text) then
		return
	end
	check(#text <= V.APPEARANCE_TEXTURE_MAX, "G " .. label .. " within the cap (" .. #text .. ")")
	if #text > #longest[kind] then longest[kind] = text end
end

-- [cracko draws the engine's crack_anylength.png
-- (reference_projects/luanti/src/client/imagesource.cpp, "[crack").
eq(TEX.args.color.form, "#rrggbb", "G the colour form")
check(("#9a2b10"):find(TEX.args.color.pattern) and not ("#9A2B10"):find(TEX.args.color.pattern)
	and ("-100"):find(TEX.args.int.pattern) and not ("1000"):find(TEX.args.int.pattern),
	"G the argument patterns accept and refuse as described")
eq(TEX.engine_files.cracko, "crack_anylength.png", "G [cracko's engine file")
for name in pairs(TEX.engine_files) do
	check(TEX.modifiers[name] ~= nil, "G engine file of a listed modifier: " .. name)
end
for _, spec in pairs(TEX.modifiers) do
	for _, kind in ipairs(spec) do
		local spec = TEX.args[kind]
		check(spec ~= nil and type(spec.pattern) == "string" and type(spec.description) == "string",
			"G argument kind defined: " .. kind)
	end
end

------------------------------------------------------------------------------
-- L. grug_xp:level.
------------------------------------------------------------------------------
do
	local level_of = function(player) return player:get_meta():get_string("grug_xp:level") end
	local ann = new_player("ann", "human")
	join(ann, "grug_xp")
	eq(level_of(ann), "1", "L a new character's join writes level 1")
	grug_xp.add_xp(ann, grug_xp.xp_for_level(5) + 3)
	eq(level_of(ann), "5", "L add_xp writes the new level")
	grug_xp.add_xp(ann, 1)
	eq(level_of(ann), "5", "L an XP change within the level keeps it")
	grug_xp.set_xp(ann, grug_xp.xp_for_level(17))
	eq(level_of(ann), "17", "L set_xp at a level start")
	grug_xp.set_xp(ann, grug_xp.xp_for_level(17) - 1)
	eq(level_of(ann), "16", "L set_xp lowering a level")
	grug_xp.add_xp(ann, 10 * grug_xp.xp_for_level(60))
	eq(level_of(ann), "60", "L capped at MAX_LEVEL")
	eq(grug_xp.get_xp(ann), grug_xp.xp_for_level(60), "L XP capped too")
	-- XP stays the authority: a stale level is recomputed on join.
	ann:get_meta():set_string("grug_xp:level", "42")
	ann:get_meta():set_int("grug_xp:xp", grug_xp.xp_for_level(9))
	join(ann, "grug_xp")
	eq(level_of(ann), "9", "L join recomputes the level from XP")
	eq(grug_xp.get_level(ann), 9, "L get_level derives from XP")
	check(level_of(ann):find("^%d+$") ~= nil, "L a decimal integer string")
	local bob = new_player("bob", "orc")
	grug_xp.set_xp(bob, 0 / 0)
	eq(level_of(bob), "", "L a refused set_xp writes nothing")
end

------------------------------------------------------------------------------
-- A. grug_visuals:appearance through apply.
------------------------------------------------------------------------------
local function stored(player)
	local text = player:get_meta():get_string(META)
	local ok, data = pcall(json_decode, text)
	check(ok, "A " .. player:get_player_name() .. " stores valid JSON: " .. tostring(data))
	return ok and data or {slots = {}, textures = {}, look = {}}, text
end
local function count_keys(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end
-- The shape of §3, checked on every decoded value.
local function shape_ok(data, label)
	eq(data.v, V.APPEARANCE_VERSION, label .. " v")
	check(V.RACES[data.race] ~= nil, label .. " race id")
	for _, category in ipairs(V.LOOK_CATEGORIES) do
		check(type(data.look[category]) == "number", label .. " look." .. category)
	end
	eq(count_keys(data.look), 5, label .. " five look fields")
	check(type(data.cloak) == "string" and (data.cloak == "none" or book.cloak[data.cloak] ~= nil),
		label .. " cloak id")
	eq(data.visual_size.x, V.RACES[data.race].stature, label .. " visual size")
	eq(count_keys(data.textures), 2, label .. " two textures")
	texture_ok("body", data.textures.body, label .. " body")
	if data.textures.cloak ~= "none" then texture_ok("cloak", data.textures.cloak, label .. " cloak") end
	for slot, entry in pairs(data.slots) do
		local hand = slot == "mainhand" or slot == "offhand"
		check(hand or slot == "head" or slot == "chest" or slot == "legs" or slot == "feet",
			label .. " slot name " .. slot)
		check(registered[entry.item] ~= nil, label .. " " .. slot .. " item registered")
		check(type(entry.broken) == "boolean", label .. " " .. slot .. " broken flag")
		check(type(entry.enchant) == "table" and #entry.enchant <= 2, label .. " " .. slot .. " enchant list")
		for _, id in ipairs(entry.enchant) do
			check(grug_gear.ENCHANT_COLORS[id] ~= nil, label .. " " .. slot .. " enchant id " .. id)
		end
		eq(count_keys(entry), hand and 5 or 3, label .. " " .. slot .. " field count")
		if hand then
			check(V.POSE[entry.pose] == entry.pose, label .. " " .. slot .. " pose id")
			texture_ok("hand", entry.image, label .. " " .. slot .. " image")
		end
	end
	return data
end

local EXAMPLES = {}
do
	-- Empty: a raceless newcomer and a created character with nothing worn.
	local cid = new_player("cid", nil)
	join(cid, "grug_visuals")
	local data, text = stored(cid)
	shape_ok(data, "A empty raceless")
	eq(data.race, "human", "A a raceless character is drawn human")
	eq(count_keys(data.slots), 0, "A empty: no slot")
	eq(data.cloak, "none", "A empty: no cloak")
	eq(data.textures.cloak, "none", "A empty: no cloak texture")

	local dee = new_player("dee", "dwarf")
	dee:get_meta():set_string("grug_visuals:look", "2,3,1,2,4")
	join(dee, "grug_visuals")
	data, text = stored(dee)
	shape_ok(data, "A plain")
	eq(data.race, "dwarf", "A plain: race")
	eq(data.look.feature, 4, "A plain: the stored look")
	eq(data.visual_size.y, 0.9, "A plain: dwarf stature")
	eq(writes.dee[META], 1, "A plain: written once on join")
	eq(data.textures.body, V.compose(V.player_spec(dee)).textures[1], "A plain: the composed body")
	EXAMPLES.plain = text

	-- Nothing changed: no write, also not across a rejoin.
	V.apply(dee)
	V.apply(dee)
	eq(writes.dee[META], 1, "A unchanged: no second write")
	leave(dee)
	join(dee, "grug_visuals")
	eq(writes.dee[META], 1, "A rejoin with the same look: no write")
	-- An older or foreign value is replaced on the next join.
	local current = dee:get_meta():get_string(META)
	dee:get_meta():set_string(META, '{"v":0}')
	leave(dee)
	join(dee, "grug_visuals")
	eq(dee:get_meta():get_string(META), current, "A an older entry is replaced on join")
	writes.dee[META] = 1

	-- The wielded item never appears, and the wield poll never writes.
	registered["test:pickaxe"] = {groups = {pickaxe = 1}, inventory_image = "test_pickaxe.png"}
	dee._wielded = ItemStack("test:pickaxe")
	V.apply(dee)
	for _, fn in ipairs(globalsteps) do fn(2) end
	eq(writes.dee[META], 1, "A wielding a tool writes nothing")
	check(not dee:get_meta():get_string(META):find("test", 1, true),
		"A the wielded item is not stored")

	-- Full: four armour pieces, sword and shield (a warrior).
	local eve = new_player("eve", "human")
	join(eve, "grug_visuals")
	for _, slot in ipairs(V.SLOTS) do
		equip(eve, "grug_" .. slot, ItemStack(grug_gear.armor_item(slot, "metal", 4)))
	end
	equip(eve, "grug_weapon", gear_stack("grug_gear:sword_steel"))
	equip(eve, "grug_offhand", gear_stack("grug_gear:shield_steel"))
	data = shape_ok(stored(eve), "A full")
	eq(count_keys(data.slots), 6, "A full: six slots")
	eq(data.slots.chest.item, grug_gear.armor_item("chest", "metal", 4), "A full: chest item")
	eq(data.slots.mainhand.pose, "tool", "A full: a sword in the tool pose")
	eq(data.slots.offhand.pose, "forward", "A full: a shield in the forward pose")
	eq(data.slots.offhand.image, registered["grug_gear:shield_steel"].inventory_image,
		"A full: the plain shield image")
	eq(#data.slots.head.enchant, 0, "A full: plain pieces have no enchant")
	eq(data.slots.head.broken, false, "A full: nothing broken")

	-- Broken and enchanted armour; the hand slots change item, state, enchant.
	local before = writes.eve[META]
	equip(eve, "grug_head", gear_stack(grug_gear.armor_item("head", "metal", 4), "str", "dex", true))
	data = shape_ok(stored(eve), "A broken")
	eq(data.slots.head.broken, true, "A broken: the helmet")
	eq(table.concat(data.slots.head.enchant, ","), "str,dex", "A enchanted: prefix, then suffix")
	check(data.textures.body:find(grug_gear.BROKEN_MODIFIER, 1, true) ~= nil, "A broken: cracked body")
	check(data.textures.body:find("_ench.png^[verticalframe", 1, true) ~= nil, "A enchanted: colour layers")
	eq(writes.eve[META], before + 1, "A one equipment change, one write")
	local function hand_change(list, stack, label)
		local old = eve:get_meta():get_string(META)
		equip(eve, list, stack)
		check(eve:get_meta():get_string(META) ~= old, "A " .. label .. " updates the entry")
		return shape_ok(stored(eve), "A " .. label)
	end
	data = hand_change("grug_offhand", gear_stack("grug_gear:shield_bronze"), "offhand item")
	eq(data.slots.offhand.item, "grug_gear:shield_bronze", "A offhand item stored")
	data = hand_change("grug_offhand", gear_stack("grug_gear:shield_bronze", nil, nil, true), "offhand broken")
	eq(data.slots.offhand.broken, true, "A offhand broken stored")
	check(data.slots.offhand.image:find(grug_gear.BROKEN_MODIFIER, 1, true) ~= nil, "A broken offhand image")
	data = hand_change("grug_offhand", gear_stack("grug_gear:shield_bronze", "armor_rating", nil, true),
		"offhand enchant")
	eq(table.concat(data.slots.offhand.enchant, ","), "armor_rating", "A offhand enchant stored")
	data = hand_change("grug_weapon", gear_stack("grug_gear:sword_steel", nil, "crit_percent"), "mainhand enchant")
	eq(table.concat(data.slots.mainhand.enchant, ","), "crit_percent", "A a suffix alone")
	check(data.slots.mainhand.image:find("grug_gear_item_sword_steel_ench.png", 1, true) ~= nil,
		"A the enchanted sword image carries its mask")
	data = hand_change("grug_weapon", gear_stack("grug_gear:sword_steel", nil, "crit_percent", true), "mainhand broken")
	eq(data.slots.mainhand.broken, true, "A mainhand broken stored")
	data = hand_change("grug_offhand", nil, "offhand removed")
	eq(data.slots.offhand, nil, "A an empty slot is absent")
	-- Pure wear changes nothing.
	before = writes.eve[META]
	for _, fn in ipairs(equipment_consumers) do fn(eve, "grug_weapon", "durability_metadata") end
	eq(writes.eve[META], before, "A pure wear writes nothing")

	-- A spellbook (a mage with a dagger) and a cloak change.
	local fay = new_player("fay", "elf")
	join(fay, "grug_visuals")
	equip(fay, "grug_weapon", gear_stack("grug_gear:dagger_iron", "int"))
	equip(fay, "grug_offhand", gear_stack("grug_gear:spellbook_iron", "max_mana_percent", "int"))
	data = shape_ok(stored(fay), "A spellbook")
	eq(data.slots.offhand.item, "grug_gear:spellbook_iron", "A spellbook stored")
	check(data.slots.offhand.image:find("grug_gear_spellbook_ench.png", 1, true) ~= nil,
		"A the enchanted spellbook image")
	before = writes.fay[META]
	check(R.select(book, fay:get_meta(), "plain_grey"), "A a default cloak selectable")
	V.apply(fay)
	data = shape_ok(stored(fay), "A cloak")
	eq(data.cloak, "plain_grey", "A the cloak id")
	eq(data.textures.cloak, "grug_achievements_cloak_plain_grey.png", "A the cloak texture")
	eq(writes.fay[META], before + 1, "A a cloak change writes once")

	-- A Scout: the bow is the mainhand, the blade the offhand; enchanted,
	-- partly broken gear and an earned cloak.
	local gus = new_player("gus", "troll")
	gus:get_meta():set_string("grug_visuals:look", "3,2,4,1,3")
	gus:get_meta():set_string(R.KEY_CLOAKS, "hunter_2")
	check(R.select(book, gus:get_meta(), "hunter_2"), "A an earned cloak selectable")
	join(gus, "grug_visuals")
	equip(gus, "grug_head", gear_stack(grug_gear.armor_item("head", "leather", 5), "dex", "crit_percent"))
	equip(gus, "grug_chest", gear_stack(grug_gear.armor_item("chest", "leather", 5), "dex", nil, true))
	equip(gus, "grug_legs", gear_stack(grug_gear.armor_item("legs", "leather", 5)))
	equip(gus, "grug_feet", gear_stack(grug_gear.armor_item("feet", "cloth", 5), nil, "dodge_percent"))
	equip(gus, "grug_weapon", gear_stack("grug_gear:bow_embersteel", "dex", "attack_speed_percent"))
	equip(gus, "grug_offhand", gear_stack("grug_gear:dagger_embersteel", "str", nil, true))
	-- An ability item in the hand shows the Melee blade in game; never stored.
	registered["test:ability"] = {groups = {grug_ability = 1}, _grug_ability_slot = "melee"}
	gus._wielded = ItemStack("test:ability")
	V.apply(gus)
	local text
	data, text = stored(gus)
	shape_ok(data, "A scout")
	eq(data.slots.mainhand.pose, "bow", "A scout: the bow in the mainhand")
	eq(data.slots.offhand.pose, "tool", "A scout: the blade in the offhand")
	eq(data.slots.offhand.broken, true, "A scout: the broken blade")
	eq(data.slots.chest.broken, true, "A scout: the broken chest")
	eq(data.cloak, "hunter_2", "A scout: the cloak")
	EXAMPLES.scout = text
end

------------------------------------------------------------------------------
-- G. The worst case and the grammar over everything a string can hold.
------------------------------------------------------------------------------
local STATS = grug_gear.ENCHANT_ORDER
local PAIRS = {{}}
for _, a in ipairs(STATS) do
	PAIRS[#PAIRS + 1] = {a}
	PAIRS[#PAIRS + 1] = {nil, a}
	for _, b in ipairs(STATS) do
		if a ~= b then PAIRS[#PAIRS + 1] = {a, b} end
	end
end

-- Hand images: every item a hand slot takes, plain, every enchant pair, broken.
local hand_items, longest_item = {}, ""
for name, def in pairs(registered) do
	local groups = def.groups or {}
	if (groups.grug_equip_weapon or 0) > 0 or (groups.grug_equip_offhand or 0) > 0 then
		hand_items[#hand_items + 1] = name
		if #name > #longest_item then longest_item = name end
	end
end
table.sort(hand_items)
check(#hand_items > 12, "G hand items found (" .. #hand_items .. ")")
for _, name in ipairs(hand_items) do
	for _, pair in ipairs(PAIRS) do
		for _, broken in ipairs({false, true}) do
			texture_ok("hand", V.hand_image(gear_stack(name, pair[1], pair[2], broken)),
				name .. " " .. tostring(pair[1]) .. "/" .. tostring(pair[2]) ..
				(broken and " broken" or ""))
		end
	end
end

-- Cloaks: every texture of the catalogue.
for _, cloak in ipairs(book.cloaks) do
	if cloak.texture then texture_ok("cloak", cloak.texture, "cloak " .. cloak.id) end
end

-- Bodies. The worst piece per slot first (the longest string any item,
-- enchant pair and broken state gives that slot), then every look of every
-- race bare, under the worst set, and under it without a helmet.
local function body_of(race, look, pieces)
	local armor, broken, worn = {}, {}, {}
	for slot, piece in pairs(pieces) do
		local affixes = {}
		if piece.prefix then affixes[#affixes + 1] = {channel = "prefix", stat = piece.prefix} end
		if piece.suffix then affixes[#affixes + 1] = {channel = "suffix", stat = piece.suffix} end
		armor[slot] = piece.name
		broken[slot] = piece.broken
		worn[slot] = {name = piece.name, affixes = affixes}
	end
	return V.compose({race = race, look = look, armor = armor, armor_broken = broken,
		armor_layers = V.armor_layers(worn)}).textures[1]
end
local worst = {}
local base_length = #body_of("human", nil, {})
for _, slot in ipairs(V.SLOTS) do
	local best, best_length = nil, -1
	for _, line in ipairs(V.LINES) do
		for bracket = 1, #grug_gear.BRACKETS do
			local name = grug_gear.armor_item(slot, line, bracket)
			if registered[name] then
				for _, pair in ipairs(PAIRS) do
					for _, broken in ipairs({false, true}) do
						local piece = {name = name, prefix = pair[1], suffix = pair[2], broken = broken}
						local body = body_of("human", nil, {[slot] = piece})
						texture_ok("body", body, name .. " " .. tostring(pair[1]) .. "/" ..
							tostring(pair[2]) .. (broken and " broken" or ""))
						local length = #body - base_length
						if length > best_length then best, best_length = piece, length end
					end
				end
			end
		end
	end
	worst[slot] = best
end
local worst_body_set = {head = worst.head, chest = worst.chest, legs = worst.legs, feet = worst.feet}
local no_helmet = {chest = worst.chest, legs = worst.legs, feet = worst.feet}
local bodies = 0
for race, def in pairs(V.LOOKS) do
	local o = def.options
	for tone = 1, #o.tone do for hair = 1, #o.hair do for style = 1, #o.style do
		for eyes = 1, #o.eyes do for feature = 1, #o.feature do
			local look = {tone = tone, hair = hair, style = style, eyes = eyes, feature = feature}
			texture_ok("body", body_of(race, look, {}), race .. " bare")
			texture_ok("body", body_of(race, look, worst_body_set), race .. " worst set")
			texture_ok("body", body_of(race, look, no_helmet), race .. " worst set, no helmet")
			bodies = bodies + 3
		end end
	end end end
end

-- The modifiers, the depth: every listed one occurs, nothing unlisted does.
for name in pairs(TEX.modifiers) do
	check(used_modifiers[name], "G modifier " .. name .. " occurs in a stored string")
end
eq(max_depth_seen, TEX.max_depth, "G max_depth is the deepest nesting")
local dirs_used = {}
for name in pairs(used_files) do dirs_used[file_dir[name]] = true end
for _, dir in ipairs(TEX.dirs) do
	check(dirs_used[dir], "G directory " .. dir .. " is used")
end

-- The whole value's bound: an appearance with the longest of every part at
-- once (not one reachable character: an upper bound of all of them).
do
	local enchant = {"max_mana_percent", "attack_speed_percent"}
	local longest_race, longest_cloak_id = "", ""
	for race in pairs(V.RACES) do if #race > #longest_race then longest_race = race end end
	for _, cloak in ipairs(book.cloaks) do
		if #cloak.id > #longest_cloak_id then longest_cloak_id = cloak.id end
	end
	local longest_armor = ""
	for name, def in pairs(registered) do
		if def.groups and def.groups.grug_armor_class and #name > #longest_armor then
			longest_armor = name
		end
	end
	local slots = {}
	for _, slot in ipairs(V.SLOTS) do
		slots[slot] = {item = longest_armor, broken = false, enchant = enchant}
	end
	for _, slot in ipairs({"mainhand", "offhand"}) do
		slots[slot] = {item = longest_item, broken = false, enchant = enchant,
			pose = "edge_down", image = longest.hand}
	end
	local json = V.appearance_json({v = V.APPEARANCE_VERSION, race = longest_race,
		look = {tone = 10, hair = 10, style = 10, eyes = 10, feature = 10},
		cloak = longest_cloak_id, visual_size = {x = 1.12, y = 1.12, z = 1.12},
		textures = {body = longest.body, cloak = longest.cloak}, slots = slots})
	local ok = pcall(json_decode, json)
	check(ok, "G the worst-case JSON parses")
	local textures = #longest.body + #longest.cloak + 2 * #longest.hand
	check(#json <= V.APPEARANCE_JSON_MAX, "G the worst-case JSON within APPEARANCE_JSON_MAX")
	eq(V.APPEARANCE_JSON_MAX, 4 * V.APPEARANCE_TEXTURE_MAX + V.APPEARANCE_JSON_OVERHEAD,
		"G APPEARANCE_JSON_MAX is four texture caps and the overhead")
	check(#json - textures <= V.APPEARANCE_JSON_OVERHEAD,
		"G the overhead within the fixed allowance")
	print(("measured: body %d, cloak %d, hand %d bytes (cap %d); JSON %d bytes, %d outside "
		.. "the texture strings (cap %d); depth %d; %d bodies, %d hand items"):format(
		#longest.body, #longest.cloak, #longest.hand, V.APPEARANCE_TEXTURE_MAX, #json,
		#json - textures, V.APPEARANCE_JSON_MAX, max_depth_seen, bodies, #hand_items))
	local names = {}
	for name in pairs(used_modifiers) do names[#names + 1] = name end
	table.sort(names)
	print("modifiers: " .. table.concat(names, ", "))
end

if MODE == "examples" then
	print("plain: " .. EXAMPLES.plain)
	print("scout: " .. EXAMPLES.scout)
	print("longest body: " .. longest.body)
end

if failures > 0 then
	error(("R39 WM PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print("R39 WM PORTABLE PASS checks=" .. checks)
