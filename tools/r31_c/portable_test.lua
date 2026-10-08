-- Round 31 Lane C portable test (LuaJIT): the clean-up after Round 30
-- (round31-plan.md §1 C, BACKLOG "Round 30 carry-overs").
--
--   luajit tools/r31_c/portable_test.lua [REPO] [SEED]   (seed default 42)
--
--   D  dropped query caches (grug_mapgen planner_source.drop_caches): on the
--      analytic world of the seed (tools/r28_zone_atlas/world.lua, as main
--      builds it) three zones' region maps are built through the game's
--      spawn_regions.lua; after the drop the column cache is empty, every
--      world query on a sample grid answers exactly as before, the same
--      maps build byte-identically, and the heap after a full collection is
--      printed before and after (a comparison, never a target);
--   H  held objective counts: Q.journal_key caps every held count at what
--      one quest's item objectives take of it (the most over the active
--      quests); over-gathering changes neither the key nor the markers nor
--      the journal (no markers_changed on the tracker poll); on random
--      inventories equal keys always give equal journals and markers;
--   T  a turn-in whose money or XP reward raises still saves the state and
--      runs the change callbacks and markers_changed, then re-raises;
--   G  the Map tab's zone grid (grug_map/location.lua): a world of more than
--      255 zones places its markers, logs a warning and stores no file (the
--      encode assert is inside the pcall); an ordinary world stores the file
--      and the next start reads it back.
-- Prints "R31 C PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg[1] or "."
local seed = arg[2] or "42"
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function heap()
	collectgarbage("collect")
	collectgarbage("collect")
	return collectgarbage("count") / 1024
end

-- ---------------------------------------------------------------------------
-- D: dropped query caches
-- ---------------------------------------------------------------------------
do
	local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha = common.new_sha256()
	local MOBS = repo .. "/mods/ENTITIES/grug_mobs"
	local zone_files = {}
	for _, row in ipairs(W.source.zones) do
		local f = io.open(MOBS .. "/data/zones/" .. row.id .. ".spawns.json", "rb")
		if f then f:close(); zone_files[#zone_files + 1] = row.id .. ".spawns.json" end
	end
	local function noop() end
	local env = setmetatable({}, {__index = _G})
	env._G = env
	env.core = {
		get_modpath = function(name)
			if name == "grug_mapgen" then return repo .. "/mods/MAPGEN/grug_mapgen" end
			if name == "grug_core" then return repo .. "/mods/CORE/grug_core" end
			return MOBS
		end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function() return zone_files end,
		parse_json = json.parse,
		register_globalstep = noop, register_on_mods_loaded = noop, register_lbm = noop,
		settings = {get = function() return nil end, get_bool = function() return nil end},
		get_us_time = function() return os.clock() * 1e6 end,
		get_worldpath = function() return nil end,
		sha256 = function(bytes) return common.hex(raw_sha(bytes)) end,
		safe_file_write = function() return false end,
		log = noop,
	}
	env.grug_zones = W.session
	env.grug_mapgen = {wp40 = {planner_source = W.planner_source,
		road_polylines = W.wp40.road_polylines}}
	env.grug_core = {register_level_overlay = noop}
	env.grug_mobs = {storage = {get_int = function() return 0 end, set_int = noop},
		settle_mob_death = noop}
	local chunk = assert(loadfile(MOBS .. "/spawn_regions.lua"))
	setfenv(chunk, env)
	chunk()
	local SR = env.grug_mobs.spawn_regions
	local ZONES = {"elandor_dawnmere_fields", "kragmar_redtusk_savanna", "front_shattered_line"}
	local function maps()
		local out = {}
		for index, zone in ipairs(ZONES) do
			local full = assert(SR.full_map(zone))
			out[index] = {zone = zone, digest = "-", payload = SR.cache.compact(full)}
		end
		return SR.cache.encode({}, out)
	end
	-- Every query the region builder, the map base and the zone grid ask, on
	-- a 97-node grid over the world (a prime pitch crosses the memo slots).
	local P, Z = W.planner_source, W.session
	local function answers()
		local out = {}
		for x = -3000, 3000, 97 do
			for z = -3000, 3000, 97 do
				local v = {P.column_values_at(x, z)}
				for i = 1, 20 do v[i] = tostring(v[i]) end
				out[#out + 1] = table.concat(v, " ") .. "|" .. tostring(Z.id_at(x, z)) .. "|" ..
					tostring(Z.water_class_at(x, z)) .. "|" .. tostring(Z.terrain_height_at(x, z)) ..
					"|" .. tostring(Z.biome_at(x, z)) .. "|" .. tostring(Z.surface_mob_level_at(x, z))
			end
		end
		return table.concat(out, "\n")
	end
	local built = maps()
	local warm = answers()
	check(P.metrics().runtime_column_cache_entries > 0, "D the builds fill the column cache")
	local before = heap()
	P.drop_caches()
	local after = heap()
	eq(P.metrics().runtime_column_cache_entries, 0, "D the drop empties the column cache")
	check(answers() == warm, "D every query answers the same after the drop")
	P.drop_caches()
	check(maps() == built, "D the same region maps build byte-identically after the drop")
	print(("R31 C D seed %s: heap after the builds %.1f MiB, after the drop %.1f MiB")
		:format(seed, before, after))
end

-- ---------------------------------------------------------------------------
-- Fake engine for the quest and map files
-- ---------------------------------------------------------------------------
local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do out[deep_copy(k, seen)] = deep_copy(v, seen) end
	return out
end
table.copy = function(value) return deep_copy(value) end
local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local keys, parts = {}, {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		for _, k in ipairs(keys) do parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k]) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local Stack = {}
Stack.__index = Stack
function ItemStack(value)
	if getmetatable(value) == Stack then return setmetatable({name = value.name, count = value.count}, Stack) end
	local name, count = "", 0
	if type(value) == "string" and value ~= "" then
		local n, c = value:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	end
	return setmetatable({name = name, count = count}, Stack)
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count == 0 end
function Stack:equals(other) return self:get_name() == other:get_name() and self.count == other.count end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	self.count = self.count - n
	local name = self.name
	if self.count == 0 then self.name = "" end
	return ItemStack(name .. " " .. n)
end
function Stack:add_item(item)
	item = ItemStack(item)
	if item:is_empty() then return item end
	if self:is_empty() then self.name, self.count = item.name, item.count; return ItemStack("") end
	if self.name ~= item.name then return item end
	local moved = math.min(99 - self.count, item.count)
	self.count, item.count = self.count + moved, item.count - moved
	if item.count == 0 then item.name = "" end
	return item
end

local registered, logs, writes = {}, {}, {}
local us = 1000000
local players = {}
local item_groups = {["default:tree"] = {log = 1}, ["default:pine_tree"] = {log = 1}}
local files = {}
core = {
	registered_items = {["grug_food:raw_meat"] = {description = "Raw Meat"},
		["default:tree"] = {description = "Tree"}, ["default:pine_tree"] = {description = "Pine Tree"},
		["default:dirt"] = {description = "Dirt"}},
	registered_entities = {},
	get_translated_string = function(_, text) return text end,
	get_us_time = function() return us end,
	get_item_group = function(name, group) return (item_groups[name] or {})[group] or 0 end,
	serialize = serialize,
	deserialize = function(text)
		if text == "" then return nil end
		return assert(loadstring("return " .. text))()
	end,
	log = function(level, text) logs[#logs + 1] = {level, text} end,
	get_player_by_name = function(name) return players[name] end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		return list
	end,
	get_player_window_information = function() return nil end,
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name)
		if name == "grug_core" then return repo .. "/mods/CORE/grug_core" end
		return repo .. "/mods/PLAYER/" .. name
	end,
	get_worldpath = function() return "/r31c-world" end,
	-- A distinct stand-in digest is enough: the key only has to repeat.
	sha256 = function(bytes)
		local h = 5381
		for i = 1, #bytes do h = (h * 33 + bytes:byte(i)) % 4294967296 end
		return ("%08x%d"):format(h, #bytes)
	end,
	safe_file_write = function(path, bytes) writes[#writes + 1] = path; files[path] = bytes; return true end,
	add_item = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then
		return function(fn)
			registered[key] = registered[key] or {}
			registered[key][#registered[key] + 1] = fn
		end
	end
end})
local function each(kind, ...)
	for _, fn in ipairs(registered[kind] or {}) do fn(...) end
end
local real_open = io.open
io.open = function(path, mode)
	if files[path] then
		local data = files[path]
		return {read = function() return data end, close = function() end}
	end
	if type(path) == "string" and path:find("^/r31c%-world/") then return nil end
	return real_open(path, mode)
end

local function new_player(name)
	local p = {name = name, meta = {}, huds = {}, next_hud = 0, lists = {main = {}}}
	for i = 1, 16 do p.lists.main[i] = ItemStack("") end
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = 0, y = 10, z = 0} end
	function p:get_meta()
		local m = self.meta
		return {get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) m[k] = v ~= "" and v or nil end}
	end
	function p:get_inventory()
		local lists = self.lists
		return {
			get_list = function(_, list)
				local out = {}
				for i, s in ipairs(lists[list] or {}) do out[i] = ItemStack(s) end
				return out
			end,
			get_stack = function(_, list, i) return ItemStack(lists[list][i]) end,
			set_stack = function(_, list, i, s) lists[list][i] = ItemStack(s); return true end,
			add_item = function(_, list, s)
				local rest = ItemStack(s)
				for _, slot in ipairs(lists[list]) do
					if rest:is_empty() then break end
					rest = slot:add_item(rest)
				end
				return rest
			end,
		}
	end
	function p:give(item) return self:get_inventory():add_item("main", item) end
	function p:set(items)
		for i = 1, 16 do self.lists.main[i] = ItemStack(items[i] or "") end
	end
	function p:hud_add(def) self.next_hud = self.next_hud + 1; self.huds[self.next_hud] = deep_copy(def); return self.next_hud end
	function p:hud_change(id, stat, value) self.huds[id][stat] = value end
	return p
end

-- ---------------------------------------------------------------------------
-- The quest files
-- ---------------------------------------------------------------------------
grug_core = {feed_item = function() end, feed = function() return true end,
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
	zone_authority_installed = function() return true end,
	FEED_COLOR = {notice = 0xf0e6c8}}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
grug_inventory = {BAG_COUNT = 0,
	-- Round 44: quest drops go through grug_inventory.give (main-only here).
	give = function(player, stack) return player:get_inventory():add_item("main", stack) end}
grug_factions = {same_faction = function() return false end}
grug_xp = {get_level = function() return 10 end, add_xp = function() end,
	quest_reward = function() return 10 end,
	register_on_level_change = function() end}
grug_money = {MAX = 1e9, get = function() return 0 end, add = function() end}
grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end}
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "hud"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests
Q.register_npc("elder", {settlement = "s", socket = "a", title = "Elder Maren"})
Q.register_npc("hunter", {settlement = "s", socket = "b", title = "Hunter Brosk"})
local function quest(id, def)
	def.title, def.description = id, "Text of " .. id
	def.rewards = {weight = 1, copper = 5}
	Q.register_quest(id, def)
end
quest("meat", {npc = "elder", objectives = {{type = "item", item = "grug_food:raw_meat", count = 2}}})
quest("feast", {npc = "hunter", objectives = {{type = "item", item = "grug_food:raw_meat", count = 4}}})
quest("logs", {npc = "hunter", objectives = {{type = "item", group = "log", count = 3},
	{type = "item", item = "default:tree", count = 1}}})

local marker_calls = 0
Q.register_on_markers_changed(function() marker_calls = marker_calls + 1 end)
local hud_step = registered.register_globalstep[1]
local function hud_poll()
	for _ = 1, 5 do hud_step(0.1) end
end

-- ---------------------------------------------------------------------------
-- H: held objective counts
-- ---------------------------------------------------------------------------
do
	local ann = new_player("ann")
	players.ann = ann
	each("register_on_joinplayer", ann)
	check(Q.accept(ann, "meat") and Q.accept(ann, "logs"), "H accept two item quests")
	ann:set({"grug_food:raw_meat 1"})
	local _, held = Q.journal_key(ann)
	eq(held, "grug_food:raw_meat 1", "H one meat of two")
	ann:set({"grug_food:raw_meat 5"})
	_, held = Q.journal_key(ann)
	eq(held, "grug_food:raw_meat 2", "H five meat count as the two the quest takes")
	-- tree: the group objective takes 3 and the item objective 1 of it.
	ann:set({"default:tree 9", "default:pine_tree 9"})
	_, held = Q.journal_key(ann)
	eq(held, "default:pine_tree 3,default:tree 4", "H a quest's objectives on one item add up")
	-- a second quest on meat: the most one quest takes.
	check(Q.accept(ann, "feast"), "H accept a second meat quest")
	ann:set({"grug_food:raw_meat 9"})
	_, held = Q.journal_key(ann)
	eq(held, "grug_food:raw_meat 4", "H two quests on one item: the larger need")
	-- over-gathering on the tracker poll: no markers_changed, no journal.
	ann:set({"grug_food:raw_meat 4"})
	hud_poll()
	local journals, real = 0, Q.journal
	Q.journal = function(...) journals = journals + 1; return real(...) end
	marker_calls = 0
	ann:set({"grug_food:raw_meat 7"})
	hud_poll()
	ann:set({"grug_food:raw_meat 12"})
	hud_poll()
	eq(marker_calls, 0, "H over-gathering tells the markers nothing")
	eq(journals, 0, "H over-gathering builds no journal")
	ann:set({"grug_food:raw_meat 3"})
	hud_poll()
	eq(marker_calls, 1, "H falling below the need tells the markers")
	eq(journals, 1, "H ...and builds the journal")
	Q.journal = real
	-- equal keys give equal journals and markers on random inventories.
	local names = {"grug_food:raw_meat", "default:tree", "default:pine_tree", "default:dirt"}
	local by_key, agree = {}, true
	math.randomseed(31)
	for _ = 1, 400 do
		local items = {}
		for slot, name in ipairs(names) do
			local n = math.random(0, 7)
			if n > 0 then items[slot] = name .. " " .. n end
		end
		ann:set(items)
		local raw, key = Q.journal_key(ann)
		us = us + 2000000
		local states = Q.marker_states(ann)
		local rows = {}
		for _, q in ipairs(Q.journal(ann).quests) do
			local counts = {}
			for i, o in ipairs(q.objectives) do counts[i] = o.count end
			rows[#rows + 1] = q.id .. "=" .. table.concat(counts, ",") .. (q.ready and "!" or "")
		end
		local marks = {}
		for _, npc in ipairs({"elder", "hunter"}) do marks[#marks + 1] = tostring(states[npc]) end
		local seen = table.concat(rows, ";") .. "|" .. table.concat(marks, ",")
		local k = raw .. "\n" .. key
		if by_key[k] and by_key[k] ~= seen then agree = false end
		by_key[k] = seen
	end
	check(agree, "H equal keys give equal journals and markers (400 inventories)")
end

-- ---------------------------------------------------------------------------
-- T: a failed turn-in reward still tells the markers
-- ---------------------------------------------------------------------------
do
	local ann = players.ann
	local changes = 0
	Q.register_on_change(function() changes = changes + 1 end)
	for _, reward in ipairs({"money", "xp"}) do
		ann:set({"grug_food:raw_meat 9"})
		local id = reward == "money" and "meat" or "feast"
		local real_add, real_xp = grug_money.add, grug_xp.add_xp
		if reward == "money" then
			grug_money.add = function() error("money observer failed") end
		else
			grug_xp.add_xp = function() error("xp observer failed") end
		end
		changes, marker_calls = 0, 0
		local ok, err = pcall(Q.turn_in, ann, id)
		grug_money.add, grug_xp.add_xp = real_add, real_xp
		check(not ok and tostring(err):find(reward .. " observer failed", 1, true),
			"T the " .. reward .. " failure is raised")
		eq(Q.status(ann, id), "completed", "T the " .. reward .. " failure keeps the saved turn-in")
		check(changes >= 1, "T the change callbacks run after a failed " .. reward .. " reward")
		check(marker_calls >= 1, "T the markers are told after a failed " .. reward .. " reward")
	end
end

-- ---------------------------------------------------------------------------
-- G: the zone grid with more than 255 zones
-- ---------------------------------------------------------------------------
local zone_count = 300
grug_zones = {
	id_at = function(x, z)
		local cell = math.floor((x + 3600) / 96) + math.floor((z + 3600) / 96) * 75
		return "zone_" .. (cell % zone_count + 1)
	end,
	get = function(id) return {id = id, numeric_id = tonumber(id:match("%d+")), display_name = id,
		level_min = 1, level_max = 10} end,
	water_class_at = function() return "land" end,
	hard_footprint_in = function() return nil end,
}
grug_home = {locations = function() return {} end}
grug_mapgen = {wp40 = {world_key = {seed = "1", source = "s", settings = "x", interpreter = "j"}}}
-- One server start: a fresh atlas and location.lua, then the mods-loaded
-- hook that places the zone markers.
local function start_map()
	grug_map = {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")}
	grug_map.atlas.set_base_texture("base.png")
	grug_map.page_layout = {map_w = 12.37, region_labels = {}}
	grug_map.static_marker_positions = function() return {} end
	registered.register_on_mods_loaded = {}
	logs, writes = {}, {}
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	local ok, err = pcall(each, "register_on_mods_loaded")
	local placed = #grug_map.atlas.collect_markers(nil, {zone = true})
	local warned, read = false, false
	for _, row in ipairs(logs) do
		warned = warned or (row[1] == "warning" and row[2]:find("zone grid is not stored: .*too many zones") ~= nil)
		read = read or row[2]:find("from the file", 1, true) ~= nil
	end
	return ok, err, placed, warned, read
end
do
	local ok, err, placed, warned = start_map()
	check(ok, "G more than 255 zones do not stop the load: " .. tostring(err))
	check(placed > 255, "G ...their markers are placed (" .. placed .. ")")
	check(warned, "G ...a warning names the unstored grid")
	eq(#writes, 0, "G ...and no file is written")
	zone_count = 3
	local ok2, err2, placed2, warned2, read2 = start_map()
	check(ok2 and placed2 == 3 and not warned2 and #writes == 1 and not read2,
		"G an ordinary world samples and stores the grid: " .. tostring(err2))
	local ok3, _, placed3, _, read3 = start_map()
	check(ok3 and placed3 == 3 and read3 and #writes == 0, "G the next start reads it back")
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	print(("R31 C PORTABLE FAIL checks=%d failures=%d"):format(checks, #failures))
	os.exit(1)
end
print(("R31 C PORTABLE PASS checks=%d"):format(checks))
