-- Round 37 lane F portable test (LuaJIT): the user's rulings of 2026-10-06.
--
--   luajit tools/r37_f/portable_test.lua [ROOT]
--
-- S  Start zones fight alone: the roles the six start zones' recipes place
--    are exactly the sub-types whose levels end at or below 10 (zone bands
--    from simple_map.lua, roles from the shipped recipes); the REAL
--    subtypes.lua, loaded on the shipped catalogue with every base stubbed
--    as a group-alert mob, registers each of them without group_attack and
--    alert_kin pulls none of them (same name, family or base), while the
--    11-20 rats keep their alert and answer each other. The pack and swarm
--    verbs and mobs_redo's alert all ask alert_kin / group_attack.
-- R  The Salt Reef Lurker: a day minor role of a shore kind in every belt of
--    Gravesalt Escarpment and The Skyglass Canopy, in no other recipe (not
--    the dragon islands); an elite crab with its own unique name and crab
--    loot in its level band.
-- M  The minimap base per quality: the REAL base.lua names a normal-size
--    minimap copy only at high, none for a crop; downscale averages exactly
--    the source pixels whose centres fall in each target pixel; install at
--    high (shrunk sizes, stub world) announces both tile sets, returns the
--    copy as `minimap`, and a second install reads both from the cache; at
--    normal the minimap base is the base itself. minimap.lua installs from
--    `installed.minimap`.
-- Q  Round 41 lane MAP, the same virtual world folder: high -> normal removes
--    the extra base tiles and the minimap copy (count logged) and nothing
--    else of the folder; normal -> high removes nothing; a refused delete
--    is a warning and the base is still served; a crash after the first
--    tile write, then the old quality again, renders instead of passing
--    mixed tiles as current.
-- Prints "R37 F PORTABLE PASS checks=<n>" or exits 1 listing failures.

local ROOT = arg and arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end

local function read(path)
	local f = assert(io.open(path, "rb"), "cannot read " .. path)
	local text = f:read("*a")
	f:close()
	return text
end

------------------------------------------------------------------------------
-- A small JSON decoder (core.parse_json is engine C++), as tools/r28_b2.
------------------------------------------------------------------------------
local function json_decode(text)
	local pos = 1
	local function ws() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
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
				if e == "u" then
					-- names and notes only: any placeholder character will do
					out[#out + 1] = "?"
					pos = pos + 6
				else
					out[#out + 1] = map[e] or error("unsupported escape \\" .. e)
					pos = pos + 2
				end
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

local function deep_copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

------------------------------------------------------------------------------
-- The shipped data: zone bands, recipes, catalogue.
------------------------------------------------------------------------------
local MOBS = ROOT .. "/mods/ENTITIES/grug_mobs"
local band_max, zone_ids = {}, {}
for id, lo, hi in read(ROOT .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"):gmatch(
		'zone%(%d+,"([%w_]+)","[^"]*","[^"]*",[^,]*,"[^"]*","[^"]*",(%d+),(%d+)') do
	band_max[id] = tonumber(hi)
	zone_ids[#zone_ids + 1] = id
	assert(tonumber(lo) <= tonumber(hi))
end
check(#zone_ids == 38, "S 38 zone records read (" .. #zone_ids .. ")")

local recipes = {}
local function walk_roles(node, out)
	if type(node) ~= "table" then return end
	for k, v in pairs(node) do
		if k == "role" and type(v) == "string" then out[v] = true else walk_roles(v, out) end
	end
end
local roles_in = {} -- role -> {zone = true}
for _, id in ipairs(zone_ids) do
	local data = json_decode(read(MOBS .. "/data/zones/" .. id .. ".spawns.json"))
	recipes[id] = data.recipe
	local roles = {}
	walk_roles(data.recipe, roles)
	for role in pairs(roles) do
		roles_in[role] = roles_in[role] or {}
		roles_in[role][id] = true
	end
end
local catalogue = json_decode(read(MOBS .. "/data/subtypes.json"))
local SUB = {}
for _, row in ipairs(catalogue) do SUB[row.role] = row end

local start_roles, home_roles = {}, {}
for role, zones in pairs(roles_in) do
	for id in pairs(zones) do
		if band_max[id] <= 10 then start_roles[role] = true else home_roles[role] = true end
	end
end
local n_start, rule_ok, overlap = 0, true, {}
for role in pairs(start_roles) do
	n_start = n_start + 1
	if not (SUB[role] and SUB[role].levels[2] <= 10) then rule_ok = false end
	if home_roles[role] then overlap[#overlap + 1] = role end
end
for role in pairs(home_roles) do
	if SUB[role] and SUB[role].levels[2] <= 10 then rule_ok = false end
end
check(n_start >= 30, "S start-zone recipes place " .. n_start .. " roles")
check(rule_ok and #overlap == 0,
	"S start-zone roles == sub-types whose levels end at <= 10 (overlap: " ..
	table.concat(overlap, ",") .. ")")

------------------------------------------------------------------------------
-- S: the REAL subtypes.lua on the shipped catalogue, every base a group-alert
-- mob (the worst case: the rule must switch the alert off by itself).
------------------------------------------------------------------------------
local registered = {}
rawset(_G, "core", {
	get_modpath = function() return MOBS end,
	get_current_modname = function() return "grug_mobs" end,
	get_dir_list = function() return {} end,
	parse_json = json_decode,
	colorize = function(_, text) return text end,
	registered_items = {},
	registered_entities = {},
	register_craftitem = function(name, def) core.registered_items[name:gsub("^:", "")] = def end,
	register_on_mods_loaded = function() end,
	log = function() end,
})
rawset(_G, "grug_mobs", {
	LEADER = {size = 1.15, hp = 1.5},
	disposition = function() return "aggressive" end,
	copy_base_def = function(base)
		return {name = base, group_attack = true, attack_type = "dogfight",
			visual_size = {x = 1, y = 1}, collisionbox = {-0.5, 0, -0.5, 0.5, 1, 0.5}}
	end,
	register_disposition = function() end,
	register_mob = function(name, def)
		-- what apply_disposition does to group_attack (disposition.lua)
		def._grug_disposition = def._grug_disposition
		registered[name] = def
	end,
})
-- The disposition is applied in register_mob by the real code; mirror its
-- group_attack half for the catalogue's neutral roles.
local real_register = grug_mobs.register_mob
grug_mobs.register_mob = function(name, def)
	local role = name:match("^grug_mobs:(.+)$")
	def._grug_disposition = SUB[role] and SUB[role].disposition
	if def._grug_disposition == "neutral" then def.group_attack = false end
	real_register(name, def)
end
dofile(MOBS .. "/subtypes.lua")
check(grug_mobs.START_BAND_MAX == 10, "S START_BAND_MAX is 10")

local function ent(role)
	local def = registered["grug_mobs:" .. role]
	return {name = "grug_mobs:" .. role, group_attack = def.group_attack,
		_grug_disposition = def._grug_disposition}
end
local base_ent = function(base) return {name = base, group_attack = true} end
local bad = {}
for role in pairs(start_roles) do
	local sub = SUB[role]
	if sub then
		local e = ent(role)
		local kin = base_ent(sub.base)
		if e.group_attack ~= false or grug_mobs.alert_kin(e, e)
				or grug_mobs.alert_kin(e, kin) or grug_mobs.alert_kin(kin, e) then
			bad[#bad + 1] = role
		end
	end
end
table.sort(bad)
check(#bad == 0, "S every start-zone role fights alone (" .. table.concat(bad, ",") .. ")")
local large, rabid, monstrous = ent("large_rat"), ent("rabid_rat"), ent("monstrous_rat")
local granary, mangy = ent("granary_rat"), ent("mangy_rat")
check(not grug_mobs.alert_kin(large, rabid) and not grug_mobs.alert_kin(monstrous, rabid),
	"S start rats do not call each other")
check(granary.group_attack == true and mangy.group_attack == true,
	"S the 11-20 rats keep their base's group_attack")
check(grug_mobs.alert_kin(granary, granary) and grug_mobs.alert_kin(granary, mangy)
	and grug_mobs.alert_kin(mangy, granary), "S the 11-20 rats call their own name and family")
check(not grug_mobs.alert_kin(granary, large) and not grug_mobs.alert_kin(large, granary),
	"S an 11-20 rat does not pull a start rat, nor the reverse")
check(ent("reed_jungle_lynx").group_attack == true and
	ent("prowling_jungle_lynx").group_attack == false,
	"S the Kapok lynx fights alone, the 11-30 lynx keeps its pack")
check(not grug_mobs.alert_kin(ent("confused_bandit"), ent("confused_bandit"))
	and not grug_mobs.alert_kin(ent("confused_bandit"), ent("grave_robber_chief")),
	"S start camp defenders and chiefs: no group alert")
check(grug_mobs.alert_kin(ent("quarrelsome_bandit"), ent("quarrelsome_bandit")),
	"S an 11-15 camp still answers as one")
-- Every caller of a group alert asks the same rule.
local verbs = read(MOBS .. "/verbs.lua")
local _, kin_calls = verbs:gsub("grug_mobs%.alert_kin%(self, ent%)", "")
check(kin_calls == 2, "S pack_hunter and camp_swarm both ask alert_kin")
local api = read(ROOT .. "/mods/ENTITIES/mobs/api.lua")
check(api:find("if ent.group_attack and ent.state ~= \"attack\"", 1, true) ~= nil
	and api:find("grug_mobs.alert_kin(self, ent)", 1, true) ~= nil,
	"S mobs_redo's alert needs the answer's group_attack and asks alert_kin")

------------------------------------------------------------------------------
-- R: the Salt Reef Lurker.
------------------------------------------------------------------------------
local lurker = SUB.salt_reef_lurker
check(lurker and lurker.base == "grug_mobs:reef_lurker" and lurker.tier == "elite"
	and lurker.family == "crab" and lurker.levels[1] >= 51,
	"R salt_reef_lurker: an elite crab of the 51-60 band")
-- Who bears the name: the catalogue displays and, since Round 38, every
-- slot of data/names.json (one source per slot key).
local bearers = {}
for _, row in ipairs(catalogue) do
	bearers[row.display] = bearers[row.display] or {}
	bearers[row.display][row.role] = true
end
for key, text in pairs(json_decode(read(MOBS .. "/data/names.json")).names) do
	bearers[text] = bearers[text] or {}
	bearers[text][key:match("^[^/]+/([^/]+)/")] = true
end
local others = {}
for source in pairs(bearers[lurker.display] or {}) do
	if source ~= "salt_reef_lurker" then others[#others + 1] = source end
end
check(bearers[lurker.display] and #others == 0 and lurker.display ~= "Reef Lurker",
	"R its name '" .. lurker.display .. "' is unique and not the base's (" .. table.concat(others, ",") .. ")")
local placed = {}
for id in pairs(roles_in.salt_reef_lurker or {}) do placed[#placed + 1] = id end
table.sort(placed)
check(table.concat(placed, ",") == "front_gravesalt_escarpment,front_skyglass_canopy",
	"R placed in Gravesalt and Skyglass only (" .. table.concat(placed, ",") .. ")")
for _, id in ipairs({"front_gravesalt_escarpment", "front_skyglass_canopy"}) do
	local all = true
	for _, belt in ipairs(recipes[id].belts) do
		local shore = belt.kinds.shore
		local ok = shore and type(shore.day) == "table" and #shore.day == 2
			and shore.day[2].role == "salt_reef_lurker"
			and shore.day[2].weight * 4 <= shore.day[1].weight + shore.day[2].weight
			and shore.night == "open"
		if not ok then all = false end
	end
	check(all, "R " .. id .. ": every belt has a shore kind with the lurker as day minor role")
end
local drops = json_decode(read(MOBS .. "/data/drops.json"))
local crab_band
for _, row in ipairs(drops) do
	if row.family == "crab" then crab_band = row.bands["6"] end
end
check(lurker.drops == "crab" and crab_band and #crab_band > 0, "R crab loot in band 6 (51-60)")

------------------------------------------------------------------------------
-- M: the minimap base per quality.
------------------------------------------------------------------------------
local WORLD = "/virtual-world"
local files, media, encodes, settings = {}, {}, 0, {}
local real_open = io.open
io.open = function(path, mode)
	if path:sub(1, #WORLD) == WORLD then
		local data = files[path]
		if not data then return nil end
		return {read = function() return data end, close = function() end}
	end
	return real_open(path, mode)
end
rawset(_G, "core", {
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_map" end,
	get_current_modname = function() return "grug_map" end,
	get_worldpath = function() return WORLD end,
	get_us_time = function() return 0 end,
	log = function() end,
	settings = {get = function(_, key) return settings[key] end},
	sha256 = function(text)
		local h = 0
		for i = 1, #text, 7 do h = (h * 31 + text:byte(i)) % 2147483647 end
		return tostring(h) .. ":" .. #text
	end,
	get_mapgen_setting = function() return "42" end,
	encode_png = function(w, h) encodes = encodes + 1 return ("PNG%dx%d"):format(w, h) end,
	safe_file_write = function(path, data) files[path] = data return true end,
	dynamic_add_media = function(def)
		media[#media + 1] = def.filename
		files[def.filepath] = files[def.filepath] or "?"
		return true
	end,
})
rawset(_G, "grug_core", {
	zone_authority_installed = function() return true end,
	start_identities = function() return {} end,
})
rawset(_G, "grug_zones", {
	water_class_at = function(x) return x < -3000 and "deep_ocean" or "land" end,
	id_at = function(x) return x < 0 and "west" or "east" end,
	get = function(id) return {id = id, race_region = "human", numeric_id = id == "west" and 1 or 2,
		level_min = 1, pvp_rule = "peaceful"} end,
	terrain_height_at = function(x, z) return (x + z) % 97 end,
})
local base = dofile(ROOT .. "/mods/PLAYER/grug_map/base.lua")
local hi, no = base.spec("high"), base.spec("normal")
check(no.minimap == nil, "M normal: the minimap shows the base itself")
check(hi.minimap and hi.minimap.quality == "normal" and hi.minimap.width == 1080
	and hi.minimap.height == 960, "M high: a 1080x960 normal minimap copy")
check(base.spec("high", {width = 200, height = 100}).minimap == nil, "M a crop has no copy")

-- downscale: a gradient, the real 10:3 ratio at a tenth of the size
local W, H, w, h = 360, 320, 108, 96
local src = {}
for j = 0, H - 1 do
	for i = 0, W - 1 do src[j * W + i + 1] = ((i % 256) * 256 + j % 256) * 256 + (i + j) % 256 end
end
local out = base.downscale(src, W, H, w, h)
local exact = #out == w * h
for t = 0, w * h - 1, 37 do
	local tx, ty = t % w, math.floor(t / w)
	local r, g, b, n = 0, 0, 0, 0
	for j = 0, H - 1 do
		if math.floor((j + 0.5) * h / H) == ty then
			for i = 0, W - 1 do
				if math.floor((i + 0.5) * w / W) == tx then
					local p = src[j * W + i + 1]
					r, g, b = r + math.floor(p / 65536), g + math.floor(p / 256) % 256, b + p % 256
					n = n + 1
				end
			end
		end
	end
	local want = (math.floor(r / n + 0.5) * 256 + math.floor(g / n + 0.5)) * 256 + math.floor(b / n + 0.5)
	if n < 9 or n > 16 or out[t + 1] ~= want then exact = false end
end
check(exact, "M downscale: each pixel the mean of the 3-4 x 3-4 sources centred in it")
local flat = {}
for k = 1, W * H do flat[k] = 0x336699 end
local flat_out, same = base.downscale(flat, W, H, w, h), true
for k = 1, w * h do same = same and flat_out[k] == 0x336699 end
check(same, "M downscale keeps a flat colour")

-- install at high, with the qualities shrunk so the stub world renders fast
base.QUALITY.normal.width, base.QUALITY.normal.height = 108, 96
base.QUALITY.high.width, base.QUALITY.high.height = 360, 320
base.QUALITY.high.relief_step, base.QUALITY.normal.relief_step = 400, 400
local VIEW = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
settings.grug_map_quality = "high"
local first = base.install(VIEW)
local function names_of(list, prefix)
	local n = 0
	for _, name in ipairs(list) do if name:sub(1, #prefix) == prefix then n = n + 1 end end
	return n
end
check(first.quality == "high" and first.width == 360 and #first.tiles == 1,
	"M high install: the Map tab keeps the high base")
check(first.minimap and first.minimap.quality == "normal" and first.minimap.width == 108
	and first.minimap.height == 96 and first.minimap.tiles[1].name == "grug_map_mini_0_0.png",
	"M high install: the minimap base is the normal-size copy")
check(names_of(media, "grug_map_base_") == 1 and names_of(media, "grug_map_mini_") == 1
	and encodes == 2, "M high install: both tile sets rendered and announced")
media, encodes = {}, 0
local second = base.install(VIEW)
check(encodes == 0 and names_of(media, "grug_map_base_") == 1 and names_of(media, "grug_map_mini_") == 1
	and second.minimap.quality == "normal", "M second start: both read from the cache")
files[WORLD .. "/grug_map_mini_0_0.png"] = nil
media, encodes = {}, 0
base.install(VIEW)
check(encodes == 2, "M a missing minimap tile re-renders")
settings.grug_map_quality = "normal"
media, encodes = {}, 0
local normal = base.install(VIEW)
check(normal.minimap == normal and names_of(media, "grug_map_mini_") == 0 and encodes == 1,
	"M normal install: one base serves both, no copy")
local minimap_src = read(ROOT .. "/mods/PLAYER/grug_map/minimap.lua")
check(minimap_src:find("local mini = installed.minimap", 1, true) ~= nil
	and minimap_src:find("V.new(mini, atlas.view())", 1, true) ~= nil,
	"M minimap.lua installs from the minimap base")
local V = dofile(ROOT .. "/mods/PLAYER/grug_map/minimap_view.lua")
local v = V.new({quality = "normal", width = 1080, height = 960, tiles = {}}, VIEW)
check(v.grid == 2 and v.reduce == 1 and v.pixels == 72, "M normal geometry: grid 2, 72 px cells")

------------------------------------------------------------------------------
-- Q (Round 41 lane MAP): stale tiles and a crash-safe key, on the same
-- virtual world folder with 128 px tiles (normal 1 base tile, high 3 x 3 base
-- tiles plus 1 minimap tile).
------------------------------------------------------------------------------
local real_remove = os.remove
local logs, refuse = {}, {}
core.log = function(level, text) logs[#logs + 1] = level .. " " .. text end
core.get_dir_list = function(path, dirs)
	assert(path == WORLD and dirs == false, "Q lists only the world folder's files")
	local names = {}
	for full in pairs(files) do
		local name = full:sub(#WORLD + 2)
		if full:sub(1, #WORLD + 1) == WORLD .. "/" and not name:find("/", 1, true) then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end
os.remove = function(path)
	if path:sub(1, #WORLD) ~= WORLD then return real_remove(path) end
	if refuse[path] then return nil, path .. ": Permission denied" end
	if files[path] == nil then return nil, path .. ": No such file or directory" end
	files[path] = nil
	return true
end
local function world_names(pattern)
	local out = {}
	for _, name in ipairs(core.get_dir_list(WORLD, false)) do
		if name:find(pattern) then out[#out + 1] = name end
	end
	return out
end
local function logged(pattern)
	for _, line in ipairs(logs) do if line:find(pattern) then return line end end
end
for path in pairs(files) do files[path] = nil end
base.TILE = 128
local OTHER = {"grug_map_zone_grid.txt", "grug_map_base_notes.png", "grug_map_base_1_1.png.bak",
	"map_meta.txt", "grug_map_mini_x_0.png"}
for _, name in ipairs(OTHER) do files[WORLD .. "/" .. name] = "keep" end

settings.grug_map_quality = "high"
logs, media, encodes = {}, {}, 0
base.install(VIEW)
check(#world_names("^grug_map_base_%d+_%d+%.png$") == 9 and #world_names("^grug_map_mini_%d+_%d+%.png$") == 1
	and logged("removed 0 stale world map tiles"), "Q high render: 9 base and 1 minimap tile, nothing stale")
settings.grug_map_quality = "normal"
logs, media, encodes = {}, {}, 0
local q_normal = base.install(VIEW)
local kept = true
for _, name in ipairs(OTHER) do kept = kept and files[WORLD .. "/" .. name] == "keep" end
check(encodes == 1 and q_normal.quality == "normal"
	and table.concat(world_names("^grug_map_base_%d+_%d+%.png$"), ",") == "grug_map_base_0_0.png"
	and #world_names("^grug_map_mini_%d+_%d+%.png$") == 0
	and logged("removed 9 stale world map tiles"),
	"Q high -> normal: the 8 extra base tiles and the minimap tile are removed, the count logged")
check(kept, "Q no other file of the world folder is touched")
settings.grug_map_quality = "high"
logs, media, encodes = {}, {}, 0
base.install(VIEW)
check(encodes == 10 and #world_names("^grug_map_base_%d+_%d+%.png$") == 9
	and logged("removed 0 stale world map tiles"), "Q normal -> high removes nothing")

-- A failed delete is a warning, never an error.
local stale = WORLD .. "/grug_map_base_2_2.png"
settings.grug_map_quality = "normal"
base.install(VIEW)
files[stale] = "stale"
refuse[stale] = true
logs, media, encodes = {}, {}, 0
local refused = base.install(VIEW)
check(encodes == 0 and refused.tiles and files[stale] == "stale"
	and logged("^warning .*grug_map_base_2_2%.png") and not logged("^error"),
	"Q a refused delete warns and the cache hit still serves the base")
refuse[stale] = nil

-- A crash after the first tile write (normal -> high), then the old quality
-- again: the key was invalidated first, so the start renders.
local writes, real_write = 0, core.safe_file_write
core.safe_file_write = function(path, data)
	if path:find("%.png$") then
		writes = writes + 1
		if writes == 2 then error("simulated crash") end
	end
	return real_write(path, data)
end
settings.grug_map_quality = "high"
base.install(VIEW)
core.safe_file_write = real_write
check(writes == 2 and files[WORLD .. "/grug_map_base_0_0.png"] == "PNG128x128",
	"Q crash: the first high tile replaced the normal one")
settings.grug_map_quality = "normal"
logs, media, encodes = {}, {}, 0
base.install(VIEW)
check(encodes == 1 and files[WORLD .. "/grug_map_base_0_0.png"] == "PNG108x96",
	"Q crash, then the old quality: renders again, no mixed tiles pass as current")
logs, media, encodes = {}, {}, 0
base.install(VIEW)
check(encodes == 0, "Q the next start reads the cache again")
os.remove = real_remove
io.open = real_open

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R37 F PORTABLE FAIL checks=%d failures=%d"):format(checks, #failures), 0)
end
print(("R37 F PORTABLE PASS checks=%d"):format(checks))
