-- Round 28 Lane B2 portable test (LuaJIT): mob sub-types and loot by band,
-- rulings 35 and 36.
--
--   luajit tools/r28_b2/portable_test.lua [ROOT]
--
-- Loads the REAL grug_mobs disposition.lua, levels.lua, aggro.lua, verbs.lua,
-- the real base families boar.lua, zombie.lua, wolf.lua and
-- start_zone_families.lua, and subtypes.lua, under a minimal `core` stub
-- (with a small JSON decoder standing in for core.parse_json). The
-- registration stub does what init.lua's grug_mobs.register_mob does for this
-- test: keep the base definition, apply the disposition and the level config.
--
-- 1. Without data (no data/ files at all): nothing registered, every
--    mob is its own family, the alert rule is the same-name rule for every
--    pair, every mob at every level drops its static list, no item.
-- 2. With the sample catalogue tools/r28_b2/sample/data/: registrations,
--    sizes and boxes (rotate kept), elite scale on top, disposition and the
--    fields it forces, level clamp, display and tint by zone (persisted,
--    idempotent, under the elite tint), drops by band with fallback and
--    leader bonus, family alert, the pack and swarm verbs, the participant
--    drop hook, and the loot items (own icon or tinted placeholder).
-- 3. Load errors: role collision, duplicate disposition, unknown base,
--    unknown tint, unknown drop item.
-- Prints "R28 B2 PORTABLE PASS checks=<n>" or exits 1 listing failures.

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
local function near(a, b, label)
	return check(type(a) == "number" and math.abs(a - b) < 1e-9,
		label .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

------------------------------------------------------------------------------
-- A small JSON decoder (core.parse_json is engine C++).
------------------------------------------------------------------------------
local function json_decode(text)
	local pos = 1
	local function ws()
		pos = text:find("[^ \t\r\n]", pos) or #text + 1
	end
	local value
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = text:sub(pos, pos)
			if c == "" then error("unterminated string") end
			if c == '"' then pos = pos + 1 break end
			if c == "\\" then
				local e = text:sub(pos + 1, pos + 1)
				local map = {n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/"}
				out[#out + 1] = map[e] or error("unsupported escape \\" .. e)
				pos = pos + 2
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = text:sub(pos, pos)
		if c == "{" then
			local obj = {}
			pos = pos + 1
			ws()
			if text:sub(pos, pos) == "}" then pos = pos + 1 return obj end
			while true do
				ws()
				local k = str()
				ws()
				assert(text:sub(pos, pos) == ":", "expected : at " .. pos)
				pos = pos + 1
				obj[k] = value()
				ws()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "}" then return obj end
				assert(d == ",", "expected , at " .. pos)
			end
		elseif c == "[" then
			local arr = {}
			pos = pos + 1
			ws()
			if text:sub(pos, pos) == "]" then pos = pos + 1 return arr end
			while true do
				arr[#arr + 1] = value()
				ws()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "]" then return arr end
				assert(d == ",", "expected , at " .. pos)
			end
		elseif c == '"' then
			return str()
		elseif text:sub(pos, pos + 3) == "true" then
			pos = pos + 4 return true
		elseif text:sub(pos, pos + 4) == "false" then
			pos = pos + 5 return false
		elseif text:sub(pos, pos + 3) == "null" then
			pos = pos + 4 return nil
		end
		local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		assert(num and num ~= "", "unexpected character at " .. pos)
		pos = pos + #num
		return tonumber(num)
	end
	local ok, result = pcall(value)
	return ok and result or nil
end

------------------------------------------------------------------------------
-- Virtual files: a test catalogue in memory, served to subtypes.lua's io.open.
------------------------------------------------------------------------------
local virtual = {}
-- Virtual directory listings for core.get_dir_list (the mod's textures/).
local virtual_dirs = {}
local real_open = io.open
io.open = function(path, mode)
	local text = virtual[path]
	if text then
		return {read = function() return text end, close = function() end}
	end
	return real_open(path, mode)
end

local function deep_copy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do out[deep_copy(k, seen)] = deep_copy(v, seen) end
	return out
end
table.copy = function(t) return deep_copy(t) end
function math.round(x)
	if x < 0 then return math.ceil(x - 0.5) end
	return math.floor(x + 0.5)
end

local api_src = assert(real_open(ROOT .. "/mods/ENTITIES/mobs/api.lua")):read("*a")
local scale_src = api_src:match("\nfunction mobs:scale_mob%(.-\nend\n")
assert(scale_src, "mobs:scale_mob not found in api.lua")

------------------------------------------------------------------------------
-- One fresh world: globals, real files, the stubbed registration.
------------------------------------------------------------------------------
local KAPOK = "kragmar_kapok_cradle"
local EXISTING_ITEMS = {"mobs:meat_raw", "mobs:leather", "grug_mobs:boar_tusk",
	"grug_mobs:light_leather", "grug_mobs:zombie_flesh", "grug_mobs:linen_scrap",
	"grug_materials:iron_bar", "grug_materials:bronze_bar", "grug_mobs:fang",
	"grug_mobs:scaled_hide", "grug_mobs:venom_sac"}

local function new_world(modpath)
	local w = {registered = {}, order = {}, items = {}, item_calls = 0,
		mods_loaded = {}, base_defs = {}, objects = {}}
	_G.core = {
		settings = {get = function() return nil end,
			get_bool = function(_, _, default) return default end},
		log = function() end,
		registered_entities = {},
		registered_items = {},
		get_modpath = function() return modpath end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function(path) return virtual_dirs[path] end,
		parse_json = json_decode,
		colorize = function(color, text) return "(" .. color .. ")" .. text end,
		register_craftitem = function(name, def)
			w.item_calls = w.item_calls + 1
			name = name:gsub("^:", "")
			assert(not core.registered_items[name], "re-registered " .. name)
			core.registered_items[name] = def
			w.items[name] = def
		end,
		register_on_mods_loaded = function(fn) w.mods_loaded[#w.mods_loaded + 1] = fn end,
		register_on_leaveplayer = function() end,
		register_on_dieplayer = function() end,
		get_objects_inside_radius = function() return w.objects end,
		is_player = function(o) return type(o) == "table" and o.is_player_stub == true end,
		get_gametime = function() return 1000 end,
	}
	for _, id in ipairs(EXISTING_ITEMS) do core.registered_items[id] = {description = id} end
	_G.vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
	_G.grug_core = {format_k = function(v) return tostring(v) end,
		set_tag_carrier_text = function() end,
		mono_time = function() return 100 end,
		sync_tag_carrier_box = function() end,
		mob_level_at = function() return w.field_level end,
		get_player_faction = function(name) return w.factions and w.factions[name] end}
	_G.grug_zones = {
		mob_level_at = function() return w.field_level end,
		guard_level_at = function() return 60 end,
		id_at = function(x) return x < 0 and KAPOK or "elandor_dawnmere_fields" end,
	}
	_G.grug_xp = {mob_xp = function(l) return 25 + 5 * l end, LEVEL_OFFSET = 5}
	_G.grug_factions = {same_faction = function(player, _) return player.same_faction == true end}
	_G.grug_mobs = {}
	w.rows = {}
	_G.mobs = {spawn = function(_, row) w.rows[row.name] = row end}
	assert(loadstring(scale_src))()
	local dir = ROOT .. "/mods/ENTITIES/grug_mobs/"
	dofile(dir .. "disposition.lua")
	-- Round 38: the names file of the data, where it has one.
	local names_file = real_open(modpath .. "/data/names.json")
	if names_file then
		names_file:close()
		-- names.lua reads names_core.lua beside the data's modpath: the mod's.
		local real_dofile = dofile
		_G.dofile = function(path)
			if path == modpath .. "/names_core.lua" then path = dir .. "names_core.lua" end
			return real_dofile(path)
		end
		real_dofile(dir .. "names.lua")
		_G.dofile = real_dofile
	end
	dofile(dir .. "levels.lua")
	dofile(dir .. "aggro.lua")
	dofile(dir .. "verbs.lua")
	function grug_mobs.ensure_tag_carrier() return {} end
	function grug_mobs.atlas_textures(texture, slots)
		local list = {}
		for i = 1, slots do list[i] = texture end
		return list
	end
	-- What init.lua's register_mob does for this test.
	function grug_mobs.copy_base_def(name)
		local def = w.base_defs[name]
		return def and table.copy(def) or nil
	end
	function grug_mobs.register_mob(name, def)
		w.base_defs[name] = table.copy(def)
		def._grug_disposition = grug_mobs.apply_disposition(name, def)
		grug_mobs.register_level_cfg(name, def)
		w.registered[name] = def
		w.order[#w.order + 1] = name
		core.registered_entities[name] = def
	end
	dofile(dir .. "boar.lua")
	dofile(dir .. "boar_variants.lua")
	dofile(dir .. "zombie.lua")
	dofile(dir .. "wolf.lua")
	dofile(dir .. "start_zone_families.lua")
	dofile(dir .. "bear.lua")
	dofile(dir .. "rabbit.lua")
	w.base_count = #w.order
	dofile(dir .. "subtypes.lua")
	for _, fn in ipairs(w.mods_loaded) do fn() end
	return w
end

-- A live entity of a registered name: the def's fields through the
-- prototype, the object stub with properties as mob_activate leaves them.
local function spawn(w, name, x, staticdata)
	local def = w.registered[name]
	local self = setmetatable({name = name}, {__index = def})
	for k, v in pairs(staticdata or {}) do self[k] = table.copy(v) end
	local props = {visual_size = table.copy(def.visual_size),
		collisionbox = table.copy(def.collisionbox),
		selectionbox = table.copy(def.selectionbox or def.collisionbox),
		textures = nil}
	local obj = {props = props, pos = {x = x or 10, y = 5, z = 0}}
	function obj:get_pos() return self.pos end
	function obj:get_properties() return self.props end
	function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function obj:set_armor_groups() end
	function obj:is_valid() return true end
	self.object = obj
	self.base_size = table.copy(def.visual_size)
	self.base_colbox = table.copy(def.collisionbox)
	self.base_selbox = table.copy(def.selectionbox or def.collisionbox)
	self.base_texture = self.base_texture or table.copy(def.textures[1])
	self.temp = {}
	if def.after_activate then def.after_activate(self, "", def, 0) end
	return self
end

-- What mobs_redo's staticdata keeps: every plain field (no functions, no temp).
local function staticdata(self)
	local out = {}
	for k, v in pairs(self) do
		if type(v) ~= "function" and k ~= "temp" and k ~= "object" then out[k] = v end
	end
	return out
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k, v in pairs(b) do if not same(v, a[k]) then return false end end
	return true
end

local function rows_of(list)
	local out = {}
	for _, r in ipairs(list or {}) do out[#out + 1] = r.name .. "/" .. r.chance .. "/" .. r.min .. "-" .. r.max end
	table.sort(out)
	return table.concat(out, " ")
end

local function tagged(self)
	self._grug_player_tag = {name = "ann", until_t = 2000}
	return self
end

------------------------------------------------------------------------------
-- 1. Without data: today's behaviour.
------------------------------------------------------------------------------
do
	-- A modpath without data/: the shipped catalogue (Lane E1) needs every
	-- base family, which this test does not load.
	local w = new_world("/virtual/no_data")
	check(#w.order == w.base_count and next(grug_mobs.subtypes) == nil,
		"no data: no sub-type registered")
	check(w.item_calls == 0, "no data: no loot item registered")
	local all_equal, fam_equal = true, true
	for _, a in ipairs(w.order) do
		if grug_mobs.family_of(a) ~= a:match(":(.+)$") then fam_equal = false end
		for _, b in ipairs(w.order) do
			local da, db = w.registered[a], w.registered[b]
			local ea = {name = a, group_attack = da.group_attack, _grug_disposition = da._grug_disposition}
			local eb = {name = b, group_attack = db.group_attack, _grug_disposition = db._grug_disposition}
			-- Today a neutral mob never helps (group_attack is off, and no
			-- neutral family carries the pack or swarm verb), and only a mob
			-- that takes part in group alerts calls its own name (Round 37 F).
			local today = a == b and da._grug_disposition ~= "neutral"
				and da.group_attack == true
			if grug_mobs.alert_kin(ea, eb) ~= today then all_equal = false end
			if da._grug_disposition == "neutral" and da.group_attack ~= false then all_equal = false end
		end
	end
	check(fam_equal, "no data: every mob is its own family (its role)")
	check(all_equal, "no data: alert kin == same entity name with group_attack (never neutral) for every pair (" ..
		#w.order .. " mobs)")
	local static_ok = true
	for _, name in ipairs(w.order) do
		for level = 1, 60 do
			local self = tagged(spawn(w, name))
			self._grug_level = level
			if grug_mobs.band_drop_rows(self) ~= nil then static_ok = false end
			local out = grug_mobs._item_drop_filter(self, w.registered[name].drops)
			if not same(out, w.registered[name].drops) then static_ok = false end
		end
	end
	check(static_ok, "no data: every mob at levels 1-60 drops its static list")
	check(grug_mobs._item_drop_filter(spawn(w, "grug_mobs:zombie"),
		w.registered["grug_mobs:zombie"].drops) == nil, "no tag: no drops")
	local empty = grug_mobs._item_drop_filter(tagged(spawn(w, "grug_mobs:boar")), {})
	check(type(empty) == "table" and #empty == 0, "no data: empty static list stays empty")
end

------------------------------------------------------------------------------
-- 2. The sample catalogue.
------------------------------------------------------------------------------
local SAMPLE = ROOT .. "/tools/r28_b2/sample"
-- The rat tail has its own icon; the fur patch and the ledger do not.
virtual_dirs[SAMPLE .. "/textures"] = {"grug_mobs_item_bone.png", "grug_mobs_rat_tail.png"}
local w = new_world(SAMPLE)
local R = w.registered
local boar, small = R["grug_mobs:boar"], R["grug_mobs:small_boar"]

check(#w.order == w.base_count + 9, "nine sub-types registered")
for _, role in ipairs({"small_boar", "aggressive_boar", "boar_matriarch", "large_rat",
		"rat_king_odo", "braindead_zombie", "young_wolf", "grizzled_wolf", "bear_cub"}) do
	check(R["grug_mobs:" .. role] ~= nil, "registered grug_mobs:" .. role)
end
check(small and small.description == "Small Boar", "display name is the description")
check(small.mesh == boar.mesh and same(small.animation, boar.animation),
	"model and animations of the base")
check(type(small.do_custom) == "function"
	and small.do_custom ~= w.base_defs["grug_mobs:boar"].do_custom,
	"the base's verb chain behind the sub-type's name guard")

-- Sizes and boxes.
near(small.visual_size.x, boar.visual_size.x * 0.85, "small boar visual x")
near(small.visual_size.y, boar.visual_size.y * 0.85, "small boar visual y")
for i = 1, 6 do
	near(small.collisionbox[i], boar.collisionbox[i] * 0.85, "small boar collisionbox " .. i)
	near(small.selectionbox[i], boar.selectionbox[i] * 0.85, "small boar selectionbox " .. i)
end
check(small.selectionbox.rotate == true, "rotated selection box stays rotated")
local rat, large = R["grug_mobs:giant_rat"], R["grug_mobs:large_rat"]
-- A leader (Lane S1): the one leader size in place of the catalogue's 1.3,
-- and 1.5 times the HP of its level and tier.
check(grug_mobs.LEADER.size == 1.15 and grug_mobs.LEADER.hp == 1.5, "leader constants 1.15 x size, 1.5 x HP")
near(R["grug_mobs:rat_king_odo"].visual_size.x, rat.visual_size.x * 1.15, "rat king visual: leader size")
near(R["grug_mobs:rat_king_odo"].collisionbox[5], rat.collisionbox[5] * 1.15, "rat king box top: leader size")
do
	w.field_level = 10
	local king = spawn(w, "grug_mobs:rat_king_odo")
	grug_mobs.ensure_init(king)
	local hp = grug_mobs.stats_for(king._grug_level, king._grug_tier)
	check(king._grug_level == 10 and king.hp_max == math.floor(1.5 * hp + 0.5), "leader HP x1.5 (" ..
		tostring(king.hp_max) .. " vs " .. hp .. ")")
	local plain = spawn(w, "grug_mobs:braindead_zombie")
	grug_mobs.ensure_init(plain)
	check(plain.hp_max == grug_mobs.stats_for(plain._grug_level, plain._grug_tier),
		"a non-leader keeps the plain HP")
end
check(boar.visual_size.x == 1 and boar.collisionbox[5] == 0.86, "base boar unchanged")

-- Elite tier on top of the size factor (A3's 1.4, boxes with it).
w.field_level = 30
local matriarch = spawn(w, "grug_mobs:boar_matriarch")
grug_mobs.ensure_init(matriarch)
check(matriarch._grug_tier == "elite", "matriarch is elite")
near(matriarch.object.props.visual_size.x, 1.2 * 1.4, "elite matriarch visual 1.2 x 1.4")
near(matriarch.object.props.collisionbox[5], 0.86 * 1.2 * 1.4, "elite matriarch box top")
check(matriarch.object.props.selectionbox.rotate == true, "elite keeps the rotated box")
check(matriarch._grug_level == 8, "level clamped to the sub-type's range (field 30 -> 8)")

-- Level clamp.
local s1 = spawn(w, "grug_mobs:small_boar")
grug_mobs.ensure_init(s1)
check(s1._grug_level == 3, "small boar: field 30 clamps to 3")
w.field_level = nil
local s2 = spawn(w, "grug_mobs:small_boar")
grug_mobs.ensure_init(s2)
check(s2._grug_level == 1, "small boar: no field value -> range floor 1")

-- Disposition.
check(grug_mobs.disposition("grug_mobs:small_boar") == "neutral", "small boar neutral")
check(grug_mobs.disposition("grug_mobs:aggressive_boar") == "aggressive", "aggressive boar aggressive")
check(grug_mobs.disposition("grug_mobs:young_wolf") == "neutral", "young wolf neutral")
check(small.group_attack == false and small.attack_players == false,
	"neutral: no group alert, no acquisition")
local aggr = R["grug_mobs:aggressive_boar"]
-- Round 37 F (user ruling 2026-10-06): a start-band role (levels end at 10
-- or below) fights alone; the 12-14 grizzled wolf keeps its base's alert.
check(aggr.group_attack == false and aggr.attack_players == true,
	"aggressive boar (start band): acquisition, no group alert")
check(R["grug_mobs:grizzled_wolf"].group_attack == true,
	"grizzled wolf (12-14): the wolf def's group_attack stays")
check(boar.group_attack == false, "base boar still neutral")
check(R["grug_mobs:young_wolf"].group_attack == false, "young wolf: no group alert")
check(R["grug_mobs:wolf"].group_attack == true, "base wolf keeps its group alert")

local ok_dup = pcall(grug_mobs.register_disposition, "grug_mobs:boar", "neutral")
check(not ok_dup, "a duplicate disposition name is an error")
check(not pcall(grug_mobs.register_disposition, "grug_mobs:x_new", "angry"),
	"an unknown disposition is an error")

-- Name (data/names.json, Round 38) and tint by zone.
local kapok = spawn(w, "grug_mobs:small_boar", -10)
check(kapok.description == "Small Jungle Boar", "Kapok display name")
check(kapok._grug_variant_zone == KAPOK, "spawn zone persisted")
check(kapok.base_texture[1] == "grug_mobs_boar_jungle.png"
	and kapok.base_texture[2] == "grug_mobs_blank.png", "jungle texture on the body slot only")
local home = spawn(w, "grug_mobs:small_boar", 10)
check(home.description == "Small Boar", "other zone: plain display name")
check(same(home.base_texture, boar.textures[1]), "other zone: base texture unchanged")
-- Reload far away: the spawn zone decides, nothing stacks.
local reload = spawn(w, "grug_mobs:small_boar", 10, staticdata(kapok))
check(reload.description == "Small Jungle Boar"
	and reload.base_texture[1] == "grug_mobs_boar_jungle.png", "reload keeps the spawn zone's variant")
local lr = spawn(w, "grug_mobs:large_rat", -10)
local lr2 = spawn(w, "grug_mobs:large_rat", -10, staticdata(lr))
local lr3 = spawn(w, "grug_mobs:large_rat", -10, staticdata(lr2))
check(lr3.base_texture[1] == "grug_mobs_giant_rat.png^[multiply:#9fbf7f",
	"modifier tint applied once over three activations")
check(lr3.description == "Large Rat", "a role the names file does not name: its display")
-- Elite tint over the zone tint (the authored elite matriarch in Kapok).
w.field_level = 2
local mk = spawn(w, "grug_mobs:boar_matriarch", -10)
grug_mobs.ensure_init(mk)
check(mk.base_texture[1] == "grug_mobs_boar_jungle.png^[colorize:#ffa800:80",
	"elite gold over the jungle texture")
local back = spawn(w, "grug_mobs:boar_matriarch", -10, staticdata(mk))
check(back._grug_base_texture[1] == "grug_mobs_boar_jungle.png"
	and back.base_texture[1] == "grug_mobs_boar_jungle.png^[colorize:#ffa800:80",
	"pristine texture stays the zone tint after reload, gold on top")

-- Authored identity beats the base family's spawn roll (the bear row's
-- 1-in-10 Elder Bear: rename + set_tier elite before the first tick).
local elder_roll = w.rows["grug_mobs:bear"] and w.rows["grug_mobs:bear"].on_spawn
check(type(elder_roll) == "function", "bear spawn row carries the elder roll")
local real_random = math.random
math.random = function() return 1 end
local cub = spawn(w, "grug_mobs:bear_cub")
elder_roll(cub)
local plain = spawn(w, "grug_mobs:bear")
elder_roll(plain)
math.random = real_random
grug_mobs.ensure_init(cub)
R["grug_mobs:bear_cub"].do_custom(cub, 0.1)
check(cub._grug_tier == "normal" and cub.description == "Bear Cub",
	"bear cub: no Elder roll (tier " .. tostring(cub._grug_tier) .. ", " ..
	tostring(cub.description) .. ")")
near(cub.object.props.visual_size.x, R["grug_mobs:bear"].visual_size.x * 0.8,
	"bear cub keeps its authored size (no elite scale)")
grug_mobs.set_tier(cub, "rare")
check(cub._grug_tier == "normal", "set_tier leaves an authored tier alone")
grug_mobs.ensure_init(plain)
check(plain._grug_tier == "elite" and plain.description == "Elder Bear",
	"a base bear still rolls its Elder (unchanged)")
local cub2 = spawn(w, "grug_mobs:bear_cub", 10, staticdata(cub))
cub2.description = "Elder Bear"
R["grug_mobs:bear_cub"].do_custom(cub2, 0.1)
check(cub2.description == "Bear Cub", "the name guard also holds after a reload")

-- Drops by band.
check(grug_mobs.level_band(1) == 1 and grug_mobs.level_band(10) == 1
	and grug_mobs.level_band(11) == 2 and grug_mobs.level_band(60) == 6
	and grug_mobs.level_band(70) == 6, "band = floor((level - 1) / 10) + 1, 1..6")
local function drops_at(name, level, extra)
	local self = tagged(spawn(w, name))
	self._grug_level = level
	for k, v in pairs(extra or {}) do self[k] = v end
	return grug_mobs._item_drop_filter(self, R[name].drops)
end
check(rows_of(drops_at("grug_mobs:small_boar", 2)) ==
	"grug_mobs:boar_tusk/1/1-1 mobs:meat_raw/1/1-1", "small boar band 1 rows")
check(same(drops_at("grug_mobs:aggressive_boar", 12), boar.drops),
	"no band-2 rows: the base's static drops")
check(rows_of(drops_at("grug_mobs:braindead_zombie", 4)) ==
	"grug_materials:bronze_bar/20/1-1 grug_mobs:zombie_flesh/1/1-1", "braindead zombie band 1")
local z5 = rows_of(drops_at("grug_mobs:zombie", 5))
check(z5 == "grug_materials:bronze_bar/20/1-1 grug_mobs:zombie_flesh/1/1-1"
	and not z5:find("iron_bar"), "existing zombie (family = role) uses the zombie table: no iron")
check(rows_of(drops_at("grug_mobs:zombie", 15)):find("grug_materials:iron_bar/10/1-1", 1, true),
	"zombie band 2 without rows: static drops (iron) as fallback")
check(rows_of(drops_at("grug_mobs:large_rat", 2)) == "grug_mobs:rat_tail/1/1-1", "large rat band 1")
check(same(drops_at("grug_mobs:large_rat", 15), rat.drops), "empty band list: the base's static drops")
check(rows_of(drops_at("grug_mobs:rat_king_odo", 10)) ==
	"grug_mobs:rat_fur_patch/1/2-3 grug_mobs:rat_tail/1/1-1", "leader sub-type gets the bonus")
check(rows_of(drops_at("grug_mobs:large_rat", 2, {_grug_leader = true})) ==
	"grug_mobs:rat_fur_patch/1/2-3 grug_mobs:rat_tail/1/1-1", "placed leader (_grug_leader) gets the bonus")
check(same(drops_at("grug_mobs:young_wolf", 5), R["grug_mobs:wolf"].drops),
	"family without a table: the base's static drops")
check(same(drops_at("grug_mobs:giant_rat", 2), rat.drops), "giant rat is not in family rat")
local first = drops_at("grug_mobs:small_boar", 2)
first[1].min = 99
check(drops_at("grug_mobs:small_boar", 2)[1].min == 1, "rows are fresh copies")
check(#drops_at("grug_mobs:rat_king_odo", 10) == 2, "the filter returns the band rows")

-- Family alert.
local function ent(name)
	return {name = name, group_attack = R[name].group_attack,
		_grug_disposition = R[name]._grug_disposition}
end
check(grug_mobs.family_of("grug_mobs:small_boar") == "boar"
	and grug_mobs.family_of("small_boar") == "boar"
	and grug_mobs.family_of("grug_mobs:boar") == "boar", "family_of: sub-type, role, existing")
check(not grug_mobs.alert_kin(ent("grug_mobs:aggressive_boar"), ent("grug_mobs:boar_matriarch")),
	"start band: aggressive boar and matriarch fight alone")
check(grug_mobs.alert_kin(ent("grug_mobs:grizzled_wolf"), ent("grug_mobs:wolf"))
	and grug_mobs.alert_kin(ent("grug_mobs:wolf"), ent("grug_mobs:grizzled_wolf")),
	"grizzled wolf and wolf share the family")
check(not grug_mobs.alert_kin(ent("grug_mobs:small_boar"), ent("grug_mobs:aggressive_boar")),
	"a neutral small boar does not pull aggressive boars")
check(not grug_mobs.alert_kin(ent("grug_mobs:aggressive_boar"), ent("grug_mobs:small_boar")),
	"aggressive boars do not pull a neutral small boar")
check(not grug_mobs.alert_kin(ent("grug_mobs:braindead_zombie"), ent("grug_mobs:zombie"))
	and not grug_mobs.alert_kin(ent("grug_mobs:zombie"), ent("grug_mobs:braindead_zombie")),
	"start band: the braindead zombie neither calls nor answers the zombie")
check(not grug_mobs.alert_kin(ent("grug_mobs:large_rat"), ent("grug_mobs:rat_king_odo")),
	"start band: the large rat does not call the rat king")
check(not grug_mobs.alert_kin(ent("grug_mobs:large_rat"), ent("grug_mobs:giant_rat")),
	"family rat does not include the giant rat (its own family)")
check(not grug_mobs.alert_kin(ent("grug_mobs:large_rat"), ent("grug_mobs:braindead_zombie")),
	"other family: no alert")
check(not grug_mobs.alert_kin(ent("grug_mobs:large_rat"), ent("grug_mobs:large_rat")),
	"start band: not even the same name")
check(grug_mobs.alert_kin(ent("grug_mobs:giant_rat"), ent("grug_mobs:giant_rat")),
	"same name with group_attack")
check(not grug_mobs.alert_kin(ent("grug_mobs:young_wolf"), ent("grug_mobs:young_wolf")),
	"neutral: not even the same name")

-- The swarm verb (giant-rat base): one engaged large rat calls kin only.
local player = {is_player_stub = true, get_pos = function() return {x = 0, y = 0, z = 0} end}
local function idle(name)
	local e = spawn(w, name)
	e._cmi_is_mob = true
	e.state = "stand"
	e.do_attack = function(s, target) s.called = target end
	return e
end
local caller = idle("grug_mobs:large_rat")
caller.state, caller.attack = "attack", player
local king, giant, zomb = idle("grug_mobs:rat_king_odo"), idle("grug_mobs:giant_rat"),
	idle("grug_mobs:braindead_zombie")
w.objects = {}
for _, e in ipairs({caller, king, giant, zomb}) do
	w.objects[#w.objects + 1] = {get_luaentity = function() return e end}
end
large.do_custom(caller, 1)
check(king.called == nil, "swarm: a start-band large rat calls nobody")
check(giant.called == nil and zomb.called == nil, "swarm: giant rat and zombie stay")

-- The pack verb (wolf base): a fleeing wolf calls wolves, never a young wolf.
local wolf_def = R["grug_mobs:wolf"]
local fleeing = idle("grug_mobs:wolf")
fleeing.state, fleeing.attack, fleeing.hp_max, fleeing.health = "attack", player, 100, 10
fleeing.yaw_to_pos = function() end
local pup, mate = idle("grug_mobs:young_wolf"), idle("grug_mobs:wolf")
local grizzled = idle("grug_mobs:grizzled_wolf")
w.objects = {}
for _, e in ipairs({fleeing, pup, mate, grizzled}) do
	w.objects[#w.objects + 1] = {get_luaentity = function() return e end}
end
wolf_def.do_custom(fleeing, 1)
check(mate.called == player and pup.called == nil, "pack: wolf yes, neutral young wolf no")
check(grizzled.called == player, "pack: the aggressive grizzled wolf answers (family)")

-- A fleeing neutral young wolf calls nobody, not even another young wolf.
local young = idle("grug_mobs:young_wolf")
young.state, young.attack, young.hp_max, young.health = "attack", player, 100, 10
young.yaw_to_pos = function() end
local pup2, mate2 = idle("grug_mobs:young_wolf"), idle("grug_mobs:wolf")
w.objects = {}
for _, e in ipairs({young, pup2, mate2}) do
	w.objects[#w.objects + 1] = {get_luaentity = function() return e end}
end
R["grug_mobs:young_wolf"].do_custom(young, 1)
check(young.state == "runaway", "the young wolf flees (the pack verb ran)")
check(pup2.called == nil and mate2.called == nil, "pack: a neutral young wolf is a single pull")

-- Participant drop hook.
local got = {}
grug_mobs.register_participant_drop_hook(function(self, names, pos)
	got[#got + 1] = {self = self, names = names, pos = pos}
end)
local function pl(name, same_faction)
	return {get_player_name = function() return name end, same_faction = same_faction}
end
local victim = spawn(w, "grug_mobs:large_rat")
grug_mobs.run_participant_drop_hooks(victim, {pl("ann"), pl("bob"), pl("guard_friend", true)},
	{x = 1, y = 2, z = 3})
check(#got == 1 and got[1].self == victim and table.concat(got[1].names, ",") == "ann,bob"
	and got[1].pos.y == 2, "hook once, eligible names without the own faction")
grug_mobs.run_participant_drop_hooks(victim, {pl("guard_friend", true)}, {x = 0, y = 0, z = 0})
grug_mobs.run_participant_drop_hooks(victim, {}, {x = 0, y = 0, z = 0})
check(#got == 1, "no hook call without an eligible participant")
local init_src = assert(real_open(ROOT .. "/mods/ENTITIES/grug_mobs/init.lua")):read("*a")
check(init_src:find("\tif only then def.description = only end\n\tbase_defs[name] = table.copy(def)", 1, true)
	~= nil, "init.lua keeps the base definition before any wrapper (named by data/names.json, Round 38)")
check(init_src:find("grug_mobs.run_participant_drop_hooks(self, eligible, death_pos)", 1, true)
	~= nil, "award_kill_xp runs the hooks with the quest credit's eligible list")
check(api_src:find("grug_mobs.alert_kin(self, ent)", 1, true) ~= nil,
	"mobs_redo group alert asks alert_kin")
local filter_at = api_src:find("drops = grug_mobs._item_drop_filter(self, drops)", 1, true)
local empty_at = api_src:find("if not drops or #drops == 0 then return end", 1, true)
check(filter_at and empty_at and filter_at < empty_at,
	"item_drop: the filter runs before the empty-list return")

-- Items.
local tail = w.items["grug_mobs:rat_tail"]
check(tail and tail.short_description == "Rat Tail"
	and tail.description:find("^Rat Tail\n") ~= nil, "rat tail: name and flavour line")
check(tail.inventory_image == "grug_mobs_rat_tail.png", "own icon <mod>_<name>.png when it ships")
check(w.items["grug_mobs:rat_fur_patch"].inventory_image:find("%^%[multiply:") ~= nil
	and w.items["grug_mobs:crop_ledger"].inventory_image:find("%^%[multiply:") ~= nil,
	"placeholder image (a tinted texture) without an own icon")
check(tail._grug_icon_brief == "A pale pink rat tail curled into an S on a dark plate.",
	"icon brief kept for C4")
check(tail.groups.grug_material == 1, "signature item is a mob material")
-- Vendor payouts are grug_traders' price module (Round 29), not a def field.
check(tail._grug_sell_price == nil and grug_mobs.loot_item_tiers["grug_mobs:rat_tail"] == 1,
	"signature tier 1: ingredient tier 1, no price field")
check(w.items["grug_mobs:crop_ledger"] ~= nil, "quest item registered")
check(w.items["grug_mobs:crop_ledger"]._grug_sell_price == nil
	and grug_mobs.loot_item_tiers["grug_mobs:crop_ledger"] == nil,
	"quest item: no price field, no ingredient tier")
check(w.items["grug_mobs:boar_tusk"] == nil
	and grug_mobs.loot_item_tiers["grug_mobs:boar_tusk"] == nil, "existing id not re-registered")
local band_items = grug_mobs.band_drop_items()
check(band_items["grug_mobs:rat_fur_patch"] and band_items["grug_mobs:rat_fur_patch"].rat
	and band_items["grug_mobs:rat_tail"].rat, "band drop items: band rows and leader bonus")
check(w.item_calls == 3, "exactly three new items")

------------------------------------------------------------------------------
-- 3. Load errors.
------------------------------------------------------------------------------
local BAD = "/virtual/bad"
local function bad_world(files, label, pattern)
	for _, f in ipairs({"subtypes", "items", "drops", "tints"}) do
		virtual[BAD .. "/data/" .. f .. ".json"] = files[f] or "[]"
	end
	local ok, err = pcall(new_world, BAD)
	check(not ok and tostring(err):find(pattern, 1, true) ~= nil,
		label .. " (" .. tostring(err) .. ")")
end
local function st(fields)
	local base = '{"role": "x_role", "family": "x", "base": "grug_mobs:boar", "display": "X",' ..
		' "size": 1.0, "disposition": "aggressive", "levels": [1, 2]'
	return "[" .. base .. (fields or "") .. "}]"
end
for _, f in ipairs({"subtypes", "items", "drops", "tints"}) do
	virtual[BAD .. "/data/" .. f .. ".json"] = f == "subtypes" and st() or "[]"
end
check(pcall(new_world, BAD) and grug_mobs.subtype("x_role") ~= nil,
	"a clean one-entry catalogue loads")
bad_world({subtypes = st():gsub("x_role", "boar")}, "role collides with an existing entity",
	"collides with the existing entity")
bad_world({subtypes = st():gsub("grug_mobs:boar", "grug_mobs:nothing")}, "unknown base",
	"is not an existing grug_mobs registration")
bad_world({subtypes = st(', "tint_by_zone": {"z": "nope"}')}, "unknown tint", "is not in tints.json")
bad_world({subtypes = st():gsub('"aggressive"', '"angry"')}, "unknown disposition",
	"disposition must be")
bad_world({drops = '[{"family": "boar", "bands": {"1": [{"item": "grug_mobs:nope", "chance": 1}]}}]'},
	"unknown drop item", "unknown item grug_mobs:nope")
bad_world({drops = '[{"family": "boar", "bands": {"7": []}}]'}, "band key out of range", "is not 1..6")
bad_world({items = '[{"id": "grug_mobs:x_item", "name": "X", "kind": "trophy"}]'}, "unknown item kind",
	"kind must be signature, generic or quest")
-- The rabbit (critter) has no attack_type: an aggressive sub-type of it would
-- acquire players and never strike.
bad_world({subtypes = st():gsub("grug_mobs:boar", "grug_mobs:rabbit")},
	"aggressive sub-type of a base without attack_type", "has no attack_type")
bad_world({tints = '[{"id": "t", "texture": "a.png", "modifier": "^[x"}]'}, "tint with both kinds",
	"exactly one of texture or modifier")

print(("R28 B2 PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("R28 B2 PORTABLE FAIL", 0) end
