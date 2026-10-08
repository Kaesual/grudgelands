-- Round 36 lane R portable test (LuaJIT): the rift, the rift boss and the war
-- commanders (round36-plan.md §2.1, §2.3, §4.3).
--   S  the site: one constant among the four candidates; every candidate's
--      crack cells avoid the composition's central clearance, its props and
--      the box's outer ring, sit on the REAL blueprint's ground with air
--      above, and every crack node is the site's own POI core in the REAL
--      world-protection index (world_protection.lua over index128.lua);
--   C  the crack at runtime through the REAL rift.lua: nothing while the area
--      is not loaded; written once when a player is near (two void nodes per
--      cell, all inside the protected box, the storage mark); a second load
--      writes nothing; the void node (not walkable, damage per second,
--      unbreakable, not placeable, liquid movement);
--   P  particles: only for near players, one spawner per crack stretch every
--      period, the alive count in the hundreds at most;
--   B  the boss: appears only with a player within 48 nodes and none within
--      6 of its spot, once; static, homed, its encounter id, a fresh ledger;
--      its death settles the ledger and books the return 5 minutes of
--      wall-clock time later, not a second earlier;
--   L  the lockout through the REAL bosses.lua ledger: the first kill gives
--      boss loot and starts the 24-hour lockout, a kill inside it gives the
--      locked reward (grug_quality: an elite's roll; tools/r33_c1 checks the
--      roll), after 24 h boss loot again; every credited kill reaches
--      register_on_boss_kill as "rift:<site>"; a reset clears the ledger and
--      never runs the dragon's cancel;
--   V  the void's damage: a share of the victim's own pool a second through
--      grug_core's REAL node_pool_damage (about 9 s at any level), lava
--      untouched; the void pulse: an evading or targetless boss never lands
--      a pulse it was winding up; an idle boss away from its spot walks back
--      on the shared fixed walk (patrol.lua `walk_fixed`, Round 42), an
--      evading one leaves the way home to the evade;
--   R  leash and reset through the REAL aggro.lua: the boss is no free
--      (damage-pursuit) mob, is dragged at most its own 24 nodes, then heals,
--      forgets, clears its ledger and runs home untouchable, and is a normal
--      mob again at home; the contact timeout resets it too;
--   W  the war commanders: only the Throng War Camp of Gravesalt Escarpment
--      and the Accord War Camp of The Skyglass Canopy carry one; his post on
--      the REAL high-camp blueprint (open floor, beside the captain); placed
--      through the REAL start_npcs.lua and guard.lua (entity, level 60, elite,
--      name, quest area, post) and back 270-330 s after his death; a camp
--      without a commander has none; the captain stays a normal leader and
--      his quest drop path stays open (quest area roles).
--
--   luajit tools/r36_r/portable_test.lua [REPO]
-- Prints "R36 R PORTABLE PASS checks=<n>" or the failures (exit 1).

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg and arg[1] or "."
local checks, failures = 0, 0
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
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
local function read(path)
	local handle = assert(io.open(path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs"
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local R = dofile(mobs_dir .. "/rift_core.lua")
local poi_rows = dofile(wp40 .. "/r20_poi_catalog.lua")
_G.core = {}
local build_r20 = dofile(wp40 .. "/r20_poi_blueprint.lua")
local wp = dofile(wp40 .. "/world_protection.lua")
local index128 = dofile(wp40 .. "/index128.lua")

-- Test anchors: a placement height per candidate (the fitted height is the
-- seed's; the rules are relative to it).
local ANCHOR_Y = {r20_anchor_076 = 140, r20_anchor_077 = 152, r20_anchor_084 = 96,
	r20_anchor_085 = 210}
local function blueprint(art)
	return build_r20({}, {art = art, blueprint_schema = "r36_r_test"})
end
local function cell_at(bp)
	local at = {}
	for _, cell in ipairs(bp.cells) do at[cell.x .. "," .. cell.y .. "," .. cell.z] = cell.name end
	return function(x, y, z) return at[x .. "," .. y .. "," .. z] end
end

------------------------------------------------------------------------------
-- S. The site and the crack plan.
------------------------------------------------------------------------------
local protection_rows, sites = {}, {}
do
	check(R.CANDIDATES[R.SITE] ~= nil, "S the site is one of the four candidates")
	local labels, count = {}, 0
	for key in pairs(R.CANDIDATES) do
		count = count + 1
		local art = R.site_row(poi_rows, key)
		labels[#labels + 1] = art and art.label
		check(art and art.kind == "clash", "S " .. key .. " is a clash site")
		check(art and (art.zone_id == "front_gravesalt_escarpment" or
			art.zone_id == "front_skyglass_canopy"), "S " .. key .. " lies in a 51-60 zone")
		local anchor = {x = art.x, y = ANCHOR_Y[key], z = art.z}
		local bp = blueprint(art)
		sites[key] = {art = art, anchor = anchor, bp = bp}
		protection_rows[#protection_rows + 1] = {key = key, slot = art.slot, anchor = anchor,
			bounds = bp.bounds}
	end
	eq(count, 4, "S four candidates")
	table.sort(labels)
	eq(table.concat(labels, ", "), "Cloudwatch Fall, Saltgate Remnant, Skyroot Crossing, Tombroad Ambush",
		"S the candidates of round36-plan.md §2.1")
	eq(R.SITE, "r20_anchor_077", "S the default site is Tombroad Ambush")
	-- The constant is the only place the site lives.
	local src = read(mobs_dir .. "/rift_core.lua")
	local _, sites_named = src:gsub('\nM%.SITE = "r20_anchor_%d+"', "")
	eq(sites_named, 1, "S one SITE constant")
	local rift_src = read(mobs_dir .. "/rift.lua")
	check(not rift_src:find("r20_anchor_", 1, true), "S rift.lua names no site")
end
local protection = wp.new(index128, {boxes = wp.settlement_boxes(protection_rows)})
for key, s in pairs(sites) do
	local art, anchor = s.art, s.anchor
	local cells = R.crack_cells(art, R.CANDIDATES[key])
	s.cells = cells
	check(#cells >= 20, "S " .. key .. " a crack of at least 20 cells (" .. #cells .. ")")
	local at = cell_at(s.bp)
	local ground = at(-8, 0, -8)
	local ok_cells, prop_free, clear, inside, poi = true, true, true, true, true
	local seen = {}
	for _, cell in ipairs(cells) do
		local x, z = cell[1], cell[2]
		if seen[x .. "," .. z] then ok_cells = false end
		seen[x .. "," .. z] = true
		if math.abs(x) <= 2 and math.abs(z) <= 2 then clear = false end
		-- The real composition: its ground at y 0, nothing authored above.
		if at(x, 0, z) ~= ground then prop_free = false end
		for y = 1, 3 do
			if at(x, y, z) ~= "air" then prop_free = false end
		end
		-- No prop cell next to the crack either (a prop's 3 x 3).
		for _, prop in ipairs(art.props) do
			if math.abs(x - prop[2]) <= 1 and math.abs(z - prop[3]) <= 1 then prop_free = false end
		end
		if x <= -8 or x >= 7 or z <= -8 or z >= 7 then inside = false end
	end
	for _, node in ipairs(R.crack_nodes(cells, anchor)) do
		if protection.kind_at(node.x, node.y, node.z) ~= "poi" then poi = false end
	end
	check(ok_cells, "S " .. key .. " every crack cell once")
	check(clear, "S " .. key .. " the central actor clearance stays whole")
	check(prop_free, "S " .. key .. " the crack runs over open ground of the composition, never a prop")
	check(inside, "S " .. key .. " the crack keeps a node of floor inside the box's edge")
	check(poi, "S " .. key .. " every crack node is the site's protected POI core")
	eq(#R.crack_nodes(cells, anchor), 2 * #cells, "S " .. key .. " two void nodes per cell")
	-- 4-connected runs between the waypoints: a gap only where a prop
	-- footprint or the clearance takes cells.
	local gaps = 0
	for index = 2, #cells do
		local a, b = cells[index - 1], cells[index]
		if math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) > 2 then gaps = gaps + 1 end
	end
	check(gaps <= 2, "S " .. key .. " a jagged line, broken at most twice (" .. gaps .. ")")
end
do
	eq(R.respawn_due(1000), 1300, "S the boss returns 5 minutes after its death")
	check(R.may_spawn(false, 0, 1), "S a first spawn needs no due time")
	check(not R.may_spawn(true, 0, 5000), "S never a second boss")
	check(not R.may_spawn(false, 1300, 1299) and R.may_spawn(false, 1300, 1300),
		"S not a second before its time")
	local alive = R.particles_alive()
	check(alive >= 20 and alive <= 300, "S about " .. alive .. " particles alive per player (hundreds at most)")
	eq(R.boss_id("r20_anchor_077"), "rift:r20_anchor_077", "S the encounter id")
	eq(dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo).required("rift_boss"), "Isquarre the Tithe-Eater",
		"S the story bible name (names.json)")
end

------------------------------------------------------------------------------
-- The engine model for C, P, B, L, R and W.
------------------------------------------------------------------------------
local catalog = dofile(wp40 .. "/r31_pvp_catalog.lua")
local source = dofile(wp40 .. "/source/simple_map.lua")
local M = dofile(mobs_dir .. "/pvp_garrison.lua")
local names = json.parse(read(mobs_dir .. "/data/pvp_names.json"))
local G = M.new(catalog, names)
local zone_of = {}
for _, zone in ipairs(source.zones) do zone_of[zone.id] = zone end
local function band_of(row)
	local zone = zone_of[row.zone_id]
	return {zone.level_min, zone.level_max}
end

local serial, steps, loaded, logs, chat, spawners = {}, {}, {}, {}, {}, {}
local gametime, walltime = 5000, 1700000000
os.time = function() return walltime end -- luacheck: ignore
local store = {}
local storage = {
	get_string = function(_, k) return store[k] or "" end,
	set_string = function(_, k, v) store[k] = v end,
	get_int = function(_, k) return math.floor(tonumber(store[k]) or 0) end,
	set_int = function(_, k, v) store[k] = tostring(v) end,
}
-- The world: a map of node names; `unloaded` hides it from get_node_or_nil.
local world, set_calls, unloaded = {}, 0, false
local function key3(p) return p.x .. "," .. p.y .. "," .. p.z end
local live, players = {}, {}
local function noop() end
local registered_nodes = {}
local function walkable_def() return {walkable = true} end
registered_nodes.air = {walkable = false}
registered_nodes["default:stone"] = walkable_def()
_G.core = setmetatable({
	registered_entities = {},
	registered_nodes = registered_nodes,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_node = function(name, def) registered_nodes[name] = def end,
	after = noop,
	get_gametime = function() return gametime end,
	pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
	get_node_or_nil = function(p)
		if unloaded then return nil end
		return {name = world[key3(p)] or "air"}
	end,
	get_node = function(p) return {name = world[key3(p)] or "air"} end,
	set_node = function(p, node) set_calls = set_calls + 1; world[key3(p)] = node.name end,
	compare_block_status = function() return false end,
	dir_to_yaw = function(d) return math.atan2(-d.x, d.z) end,
	get_mod_storage = function() return storage end,
	get_modpath = function(name)
		return name == "grug_mapgen" and repo .. "/mods/MAPGEN/grug_mapgen" or mobs_dir
	end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	get_connected_players = function() return players end,
	add_particlespawner = function(def) spawners[#spawners + 1] = def end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
	get_objects_inside_radius = function()
		local out = {}
		for _, entity in ipairs(live) do
			if entity.object.valid then out[#out + 1] = entity.object end
		end
		return out
	end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
_G.vector = {
	new = function(x, y, z) return {x = x, y = y, z = z} end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

local function activate(name, staticdata, pos)
	local def = assert(core.registered_entities[name], name)
	local object = {pos = copy(pos), valid = true, props = {}}
	local entity = setmetatable({name = name, object = object}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:set_pos(p) self.pos = copy(p) end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:is_player() return false end
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:get_properties() return self.props end
	-- mobs_redo's activation gives every mob its health.
	entity.health = 100
	for k, v in pairs(core.deserialize(staticdata) or {}) do entity[k] = v end
	live[#live + 1] = entity
	return object, entity
end
core.add_entity = function(pos, name, staticdata) return (activate(name, staticdata, pos)) end

local function new_player(name, faction, pos)
	local meta_store = {}
	local player = {name = name, faction = faction, pos = copy(pos), hp = 2696}
	function player:get_player_name() return self.name end
	function player:get_pos() return copy(self.pos) end
	function player:get_hp() return self.hp end
	function player:is_player() return true end
	function player:get_meta()
		return {
			get_int = function(_, k) return math.floor(tonumber(meta_store[k]) or 0) end,
			set_int = function(_, k, v) meta_store[k] = tostring(v) end,
			get_string = function(_, k) return meta_store[k] or "" end,
			set_string = function(_, k, v) meta_store[k] = v end,
		}
	end
	return player
end
local function player_named(name)
	for _, p in ipairs(players) do if p.name == name then return p end end
	return nil
end
core.get_player_by_name = player_named

local player_hit_mob
_G.grug_core = setmetatable({
	register_on_player_hit_mob = function(fn) player_hit_mob = fn end,
	get_player_faction = function(name)
		local p = player_named(name)
		return p and p.faction or nil
	end,
	opposing_faction = function(id) return id == "accord" and "throng" or "accord" end,
	world_feature_at = function(p)
		return protection.kind_at(math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5))
	end,
	feed = noop, feed_item = noop,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local IDENTITIES = {}
for faction, races in pairs(catalog.FACTION_RACES) do
	for _, race in ipairs(races) do IDENTITIES[#IDENTITIES + 1] = {race_id = race, faction_id = faction} end
end
grug_core.start_identities = function() return IDENTITIES end
grug_core.start_anchor = function() return nil end
grug_core.capital_anchor = function() return nil end
grug_core.start_ready = function() return false end
local site = sites[R.SITE]
_G.grug_zones = {
	get = function(id) return zone_of[id] end,
	anchor = function(zone_id, slot)
		local art = site.art
		if zone_id == art.zone_id and slot == art.slot then return copy(site.anchor) end
		return nil
	end,
}

_G.mobs = {mob_class = {}}
function mobs:remove(entity) entity.object:remove() end
local settled, resets, dragon_cancels = {}, {}, 0
_G.grug_mobs = {
	-- Round 38: the shipped names (bosses.lua and rift.lua read them).
	names = dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo),
	storage = storage,
	pvp_garrison = G,
	place_on_ground = function(object, pos) object:set_pos(pos) end,
	face_yaw = noop,
	clear_boss_activity = noop,
	register_dragon_bosses = noop,
	cancel_dragon_action = function() dragon_cancels = dragon_cancels + 1 end,
	LEADER = {size = 1.15, hp = 1.5},
	set_tier = function(entity, tier) entity._grug_tier = tier end,
	relevel = function(entity, level) entity._grug_level = level end,
	refresh_visual = noop,
	register_mob = function(name, def) core.registered_entities[name] = def end,
	register_simple_arrow = function(name, def) core.registered_entities[name] = def end,
	stamp_arrow_damage = noop,
	root = noop,
	walk_toward = function(self, x, z) self._walked_to = {x = x, z = z} end,
	-- patrol.lua's fixed walk (Round 42 NV2; its own test is tools/r42_nv2).
	walk_fixed = function(self, dtime, pos, x, y, z, key, owner)
		self._walked_to = {x = x, z = z}
		self._walk = {x = x, y = y, z = z, key = key, owner = owner}
		return 0
	end,
	walk_follow = noop,
	walk_clear = function(self, owner) self._walk_cleared = owner or true end,
	-- routes.lua (Round 42 NV3; not loaded here).
	route_settlement = noop,
}
dofile(mobs_dir .. "/guard.lua")
dofile(mobs_dir .. "/bosses.lua")
local carrier_text = {}
grug_mobs.noncombatant = function(def) return def end
grug_mobs.set_plain_tag = function(self, text) carrier_text[self] = text end
function mobs:register_mob(name, def) core.registered_entities[name] = def end
dofile(mobs_dir .. "/start_villagers.lua")
-- Only start_npcs.lua's and rift.lua's passes run below (not the dragon clock).
steps = {}
dofile(mobs_dir .. "/start_npcs.lua")
local npc_steps = steps
steps = {}
dofile(mobs_dir .. "/rift.lua")
local rift_steps = steps

------------------------------------------------------------------------------
-- C. The crack at runtime.
------------------------------------------------------------------------------
local VOID = "grug_mobs:rift_void"
local anchor = site.anchor
-- The composition on the anchor, natural stone beneath it.
local function lay_site()
	world = {}
	local at = cell_at(site.bp)
	for x = -8, 7 do
		for z = -8, 7 do
			for y = -10, -1 do
				world[key3({x = anchor.x + x, y = anchor.y + y, z = anchor.z + z})] = "default:stone"
			end
		end
	end
	for _, cell in ipairs(site.bp.cells) do
		if cell.name ~= "air" then
			registered_nodes[cell.name] = registered_nodes[cell.name] or walkable_def()
			world[key3({x = anchor.x + cell.x, y = anchor.y + cell.y, z = anchor.z + cell.z})] = cell.name
		end
	end
	return at
end
lay_site()
local function rift_pass(seconds)
	walltime = walltime + seconds
	for _, fn in ipairs(rift_steps) do fn(seconds) end
end
local function at_site(dx, dz) return {x = anchor.x + dx, y = anchor.y + 1, z = anchor.z + dz} end

do
	local def = registered_nodes[VOID]
	check(def ~= nil, "C the void node is registered")
	check(def.walkable == false and def.pointable == false and def.diggable == false and
		def.buildable_to == false and def.floodable == false, "C void: not walkable, pointed, dug, built over or flooded")
	check((def.damage_per_second or 0) > 0, "C void: damage per second")
	check(def.liquid_move_physics == true and def.drowning == 0, "C void: liquid movement, no drowning")
	check(def.groups.not_in_creative_inventory == 1 and def.drop == "", "C void: never in a player's hands")
	eq(def.is_ground_content, false, "C void: no cave carves it")

	players[1] = new_player("far", "accord", at_site(200, 0))
	rift_pass(1)
	eq(set_calls, 0, "C nobody near: nothing written")
	players[1].pos = at_site(30, 0)
	unloaded = true
	rift_pass(1)
	eq(set_calls, 0, "C the area not loaded: nothing written")
	eq(store["rift_crack:" .. R.SITE], nil, "C ...and nothing recorded")
	unloaded = false
	rift_pass(1)
	local written = 0
	local box = R.box(site.art, anchor)
	local boxed = true
	for k, name in pairs(world) do
		if name == VOID then
			written = written + 1
			local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if x < box.min_x or x > box.max_x or z < box.min_z or z > box.max_z or
					y < box.min_y or y > box.max_y then boxed = false end
		end
	end
	eq(written, 2 * #site.cells, "C a player near: the crack is written, two nodes per cell")
	eq(set_calls, written, "C ...each node once")
	check(boxed, "C ...all inside the site's protected box")
	eq(store["rift_crack:" .. R.SITE], tostring(written), "C ...and recorded in mod storage")
	for _, cell in ipairs(site.cells) do
		local x, z = anchor.x + cell[1], anchor.z + cell[2]
		check(world[key3({x = x, y = anchor.y, z = z})] == VOID and
			world[key3({x = x, y = anchor.y - 1, z = z})] == VOID and
			world[key3({x = x, y = anchor.y - 2, z = z})] == "default:stone",
			"C cell " .. cell[1] .. "," .. cell[2] .. ": void two deep on ground")
	end
	rift_pass(1)
	eq(set_calls, written, "C the next pass writes nothing")
	-- A second load: a fresh rift.lua over the same storage and an untouched
	-- copy of the site writes nothing.
	lay_site()
	set_calls = 0
	steps = {}
	dofile(mobs_dir .. "/rift.lua")
	rift_steps = steps
	rift_pass(1)
	eq(set_calls, 0, "C a second load writes nothing")
	local any_void = false
	for _, name in pairs(world) do any_void = any_void or name == VOID end
	check(not any_void, "C ...the mark, not the world, decides")
	-- A world where a cell fails (a node placed above it) skips that cell.
	store["rift_crack:" .. R.SITE] = nil
	lay_site()
	local first = site.cells[1]
	world[key3({x = anchor.x + first[1], y = anchor.y + 1, z = anchor.z + first[2]})] = "default:stone"
	set_calls = 0
	rift_pass(1)
	eq(set_calls, 2 * (#site.cells - 1), "C a cell with something on it stays floor")
	-- Back to the written site for the rest.
	store["rift_crack:" .. R.SITE] = nil
	lay_site()
	rift_pass(1)
end

------------------------------------------------------------------------------
-- P. Particles.
------------------------------------------------------------------------------
do
	spawners = {}
	local stats = grug_mobs.rift_stats
	local before = stats.particles
	players[1].pos = at_site(300, 0)
	for _ = 1, 10 do rift_pass(1) end
	eq(#spawners, 0, "P nobody near: no particles")
	players[1].pos = at_site(20, 20)
	players[2] = new_player("two", "throng", at_site(-20, 30))
	spawners, before = {}, stats.particles
	local boss_bursts = 0
	for _ = 1, 10 do rift_pass(1) end
	local stretches = math.ceil(#site.cells / 8)
	local per_player = {}
	local total = 0
	for _, def in ipairs(spawners) do
		if def.playername then
			per_player[def.playername] = (per_player[def.playername] or 0) + 1
			total = total + def.amount
			check(def.time == R.PARTICLE_PERIOD, "P a spawner lasts one period")
		else
			boss_bursts = boss_bursts + 1
		end
	end
	eq(per_player.far, 2 * stretches, "P two periods: one spawner per stretch each (player one)")
	eq(per_player.two, 2 * stretches, "P ...and per stretch for the second player")
	check(total <= 2 * 2 * R.PARTICLE_AMOUNT + 2 * stretches,
		"P " .. total .. " particles in 10 s for two players")
	check(stats.particles - before >= total, "P the counters follow")
	print(("P particles: %d spawners, %d particles in 10 s for 2 players, about %d alive per player")
		:format(#spawners - boss_bursts, total, R.particles_alive()))
end

------------------------------------------------------------------------------
-- B. The boss.
------------------------------------------------------------------------------
local BOSS = "grug_mobs:rift_boss"
local function bosses()
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid and entity.name == BOSS then out[#out + 1] = entity end
	end
	return out
end
local boss
do
	-- The P passes spawned it already (players at about 28 and 36 nodes):
	-- start this section from a clean slate.
	for _, entity in ipairs(bosses()) do entity.object:remove() end
	local def = core.registered_entities[BOSS]
	eq(def._grug_fixed_level, 60, "B a level-60 boss")
	eq(def._grug_tier, "elite", "B ...an elite")
	eq(def.mesh, "grug_mobs_dungeon_master.b3d", "B ...on an existing mesh")
	eq(def._grug_voice, "giant", "B ...with an approved voice family")
	eq(def.description, "Isquarre the Tithe-Eater", "B ...under its story bible name")
	eq(def._grug_leash_range, 24, "B its own leash radius")
	check((def._grug_hp_scale or 1) > 1, "B sized for a group")
	players[1].pos = at_site(60, 0)
	players[2].pos = at_site(0, 70)
	rift_pass(1)
	eq(#bosses(), 0, "B nobody within 48 nodes: no boss")
	players[1].pos = at_site(3, 2)
	rift_pass(1)
	eq(#bosses(), 0, "B a player on its spot: no boss on his head")
	players[1].pos = at_site(30, 0)
	chat = {}
	rift_pass(1)
	local list = bosses()
	eq(#list, 1, "B a player near: the boss appears")
	boss = list[1]
	eq(boss._grug_boss_id, "rift:" .. R.SITE, "B ...in its encounter")
	eq(boss.object.props.static_save, false, "B ...never saved with the map")
	check(boss._grug_home and boss._grug_home.x == anchor.x and boss._grug_home.z == anchor.z,
		"B ...homed on the site's centre")
	check(#chat >= 1, "B ...and the players near hear of it")
	rift_pass(1); rift_pass(1)
	eq(#bosses(), 1, "B never a second one")
end

------------------------------------------------------------------------------
-- L. The ledger and the lockout.
------------------------------------------------------------------------------
do
	local rewards, kills = {}, {}
	grug_mobs.register_boss_reward_hook(function(self, id, player, locked)
		rewards[#rewards + 1] = {id = id, name = player:get_player_name(), locked = locked}
		return {}
	end)
	grug_mobs.register_on_boss_kill(function(player, id)
		kills[#kills + 1] = player:get_player_name() .. "@" .. id
	end)
	local id = "rift:" .. R.SITE
	local function engage()
		for _, p in ipairs(players) do player_hit_mob(p, boss) end
	end
	local function last(name)
		for index = #rewards, 1, -1 do
			if rewards[index].name == name then return rewards[index] end
		end
	end
	players[1].pos = at_site(10, 0)
	players[2].pos = at_site(-10, 0)
	engage()
	local t0 = walltime
	boss.on_die(boss)
	boss.object:remove()
	eq(#rewards, 2, "L the first kill rewards both participants")
	check(last("far").locked == false and last("two").locked == false, "L ...with boss loot")
	eq(players[1]:get_meta():get_int("grug_boss_lockout:" .. id), t0 + 24 * 3600,
		"L ...and starts the 24-hour lockout")
	eq(#kills, 2, "L the kill reaches register_on_boss_kill")
	eq(kills[1]:match("@(.+)$"), id, "L ...as the rift's encounter id")
	eq(tonumber(store["rift_boss_due:" .. R.SITE]), t0 + 300, "B the death books the return in 5 minutes")
	rift_pass(298)
	eq(#bosses(), 0, "B not back before 5 minutes")
	rift_pass(2)
	local list = bosses()
	eq(#list, 1, "B back after 5 minutes")
	boss = list[1]
	-- One hour later: inside the lockout.
	rift_pass(3600)
	engage()
	boss.on_die(boss)
	boss.object:remove()
	check(last("far").locked == true and last("two").locked == true,
		"L a kill inside the lockout gives the locked reward (an elite's loot)")
	eq(players[1]:get_meta():get_int("grug_boss_lockout:" .. id), t0 + 24 * 3600,
		"L ...and does not move the lockout")
	eq(#kills, 4, "L ...and still counts as a boss kill")
	-- A third player joins fresh: boss loot for him only.
	players[3] = new_player("fresh", "throng", at_site(0, 10))
	rift_pass(300)
	boss = bosses()[1]
	engage()
	boss.on_die(boss)
	boss.object:remove()
	check(last("fresh").locked == false and last("far").locked == true,
		"L the lockout is per character")
	-- After 24 hours boss loot again.
	walltime = t0 + 24 * 3600
	rift_pass(1)
	boss = bosses()[1]
	if not boss then rift_pass(300); boss = bosses()[1] end
	engage()
	boss.on_die(boss)
	boss.object:remove()
	check(last("far").locked == false, "L after 24 hours boss loot again")
	-- A reset clears the ledger: a kill after it credits nobody.
	rift_pass(300)
	boss = bosses()[1]
	engage()
	local before, cancels = #rewards, dragon_cancels
	grug_mobs.boss_leash_reset(boss)
	eq(dragon_cancels, cancels, "L the rift boss's reset runs no dragon cancel")
	boss.on_die(boss)
	boss.object:remove()
	eq(#rewards, before, "L a reset clears the ledger: the kill after it credits nobody")
	-- Proximity alone never credits.
	rift_pass(300)
	boss = bosses()[1]
	before = #rewards
	boss.on_die(boss)
	boss.object:remove()
	eq(#rewards, before, "L standing near without a hit credits nothing")
	rift_pass(300)
	boss = bosses()[1]
end

------------------------------------------------------------------------------
-- V. The void's damage, the pulse after a reset, the route.
------------------------------------------------------------------------------
do
	-- grug_core's real environment_damage.lua (its once-a-second pass is not run).
	core.get_item_group = function(name, group)
		local def = registered_nodes[name]
		return def and def.groups and def.groups[group] or 0
	end
	local saved_steps = steps
	steps = {}
	dofile(repo .. "/mods/CORE/grug_core/environment_damage.lua")
	steps = saved_steps
	local function share(node, pool)
		return grug_core.node_pool_damage({type = "node_damage", from = "engine", node = node}, pool)
	end
	local percent = registered_nodes[VOID].groups.grug_pool_damage
	check(percent and percent > 0, "V the void hurts by a share of the pool")
	for _, level in ipairs({41, 50, 60}) do
		local pool = math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
		local hit = share(VOID, pool)
		local seconds = pool / hit
		check(hit and seconds >= 8 and seconds <= 10,
			("V a level-%d pool (%d) lasts %.1f s in the void (%d a second)"):format(level, pool, seconds, hit or 0))
	end
	registered_nodes["default:lava_source"] = {groups = {lava = 3}}
	eq(share("default:lava_source", 2696), nil, "V lava keeps its own rule")
	eq(share(VOID, 0), 0, "V no pool, no share")
	eq(grug_core.node_pool_damage({type = "punch"}, 2696), nil, "V a punch is no node damage")
	local combat = read(repo .. "/mods/CORE/grug_core/combat.lua")
	check(combat:find("grug_core.node_pool_damage(reason", 1, true) ~= nil,
		"V the central hp modifier applies it")

	-- The pulse.
	local hits = 0
	local real_hit = grug_mobs.boss_hit_players
	grug_mobs.boss_hit_players = function() hits = hits + 1 end
	local tick = core.registered_entities[BOSS].do_custom
	local function prepare(ent)
		ent.set_velocity = noop
		ent.set_animation = noop
		ent.update_tag = noop
		ent.temp = ent.temp or {}
	end
	prepare(boss)
	boss.state, boss.attack = "attack", players[1]
	boss.temp.grug_rift_pulse = 0
	tick(boss, 0.1)
	check(boss.temp.grug_rift_cast ~= nil and boss.temp.grug_telegraph, "V a fight winds the pulse up")
	tick(boss, 1); tick(boss, 1.1)
	eq(hits, 1, "V ...and lands it on a target")
	boss.temp.grug_rift_pulse = 0
	tick(boss, 0.1)
	check(boss.temp.grug_rift_cast ~= nil, "V a second wind-up")
	boss.temp.grug_evading = {started = 0}
	boss.attack, boss.state = nil, "stand"
	tick(boss, 1); tick(boss, 1.1)
	eq(hits, 1, "V an evading boss never lands it")
	check(boss.temp.grug_rift_cast == nil and not boss.temp.grug_telegraph, "V ...the wind-up and its mark are gone")
	boss.temp.grug_evading = nil
	boss.state, boss.attack = "attack", players[1]
	boss.temp.grug_rift_pulse = 0
	tick(boss, 0.1)
	boss.attack, boss.state = nil, "stand"
	tick(boss, 2.5)
	eq(hits, 1, "V nor a boss that lost its target")
	grug_mobs.boss_hit_players = real_hit

	-- The way home: the shared fixed walk (Round 42 NV2).
	boss.temp = {}
	boss._walk = nil
	local home = boss._grug_home
	boss.object.pos = {x = home.x + 12, y = home.y, z = home.z}
	tick(boss, 1)
	local w = boss._walk
	check(w and w.owner == "rift" and w.key == "home" and w.x == home.x
		and w.y == home.y and w.z == home.z, "V an idle boss walks home on the fixed walk")
	boss._walk = nil
	boss.temp.grug_evading = {started = 0}
	tick(boss, 1)
	eq(boss._walk, nil, "V an evading boss leaves its way home to the evade")
	boss.temp.grug_evading = nil
	boss._walk_cleared = nil
	boss.object.pos = {x = home.x + 2, y = home.y, z = home.z}
	tick(boss, 1)
	eq(boss._walk_cleared, "rift", "V back at its spot the walk ends")
end

------------------------------------------------------------------------------
-- R. Leash and reset (the real aggro.lua).
------------------------------------------------------------------------------
do
	local mono = 0
	grug_core.mono_time = function() return mono end
	grug_core.clear_threat = noop
	grug_core.recheck_switch = noop
	grug_core.prune_engagement = noop
	grug_mobs.idle_health_tick = noop
	grug_mobs.roam_avoid_tick = noop
	dofile(mobs_dir .. "/aggro.lua")
	local def = core.registered_entities[BOSS]
	boss.hp_max, boss.health = 16176, 9000
	boss.temp = {}
	boss.object.pos = {x = anchor.x, y = anchor.y + 1, z = anchor.z}
	boss.stop_attack = function(self) self.attack = nil; self.state = "stand" end
	grug_mobs.apply_aggro_fields(boss, {damage_pursuit = false, leash_range = def._grug_leash_range})
	eq(grug_mobs.damage_pursuit(boss), false, "R the boss is no free (damage-pursuit) mob")
	eq(grug_mobs.free_roamer(boss), false, "R ...and no free roamer")
	local fresh = {_grug_damage_pursuit_candidate = true}
	eq(grug_mobs.damage_pursuit(fresh), true, "R a free mob keeps its own rule")
	-- A pull at home, then a drag.
	boss.state, boss.attack = "attack", players[1]
	player_hit_mob(players[1], boss)
	grug_mobs.leash_tick(boss, 1)
	check(boss.temp.grug_chase_anchor ~= nil, "R the chase anchors where it began")
	boss.object.pos = {x = anchor.x + 20, y = anchor.y + 1, z = anchor.z}
	mono = mono + 1
	grug_mobs.leash_tick(boss, 1)
	eq(boss.health, 9000, "R dragged 20 nodes: still fighting")
	boss.object.pos = {x = anchor.x + 25, y = anchor.y + 1, z = anchor.z}
	mono = mono + 1
	grug_mobs.leash_tick(boss, 1)
	eq(boss.health, 16176, "R dragged past 24 nodes: healed")
	eq(boss.attack, nil, "R ...the target dropped")
	check(boss.temp.grug_evading ~= nil, "R ...and running home untouchable")
	mono = mono + 1
	grug_mobs.leash_tick(boss, 1)
	check(boss._walked_to and boss._walked_to.x == anchor.x, "R the run heads for its spot")
	boss.object.pos = {x = anchor.x + 2, y = anchor.y + 1, z = anchor.z}
	mono = mono + 1
	grug_mobs.leash_tick(boss, 1)
	eq(boss.temp.grug_evading, nil, "R at home: a normal mob again")
	-- The contact timeout.
	boss.health = 5000
	boss.state, boss.attack = "attack", players[1]
	grug_mobs.leash_tick(boss, 1)
	mono = mono + grug_mobs.LEASH_TIMEOUT + 1
	grug_mobs.leash_tick(boss, 1)
	eq(boss.health, 16176, "R no contact for 15 s: reset")
	eq(boss.temp.grug_evading, nil, "R ...inside its radius: no run")
	boss.object:remove()
end

------------------------------------------------------------------------------
-- W. The war commanders.
------------------------------------------------------------------------------
local COMMANDED = {
	pvp_camp_gravesalt_escarpment_throng_high = "throng",
	pvp_camp_skyglass_canopy_accord_high = "accord",
}
do
	local count = 0
	for _, row in ipairs(catalog.rows) do
		local spec = G.commander(row.key)
		if COMMANDED[row.key] then
			count = count + 1
			local where = "W " .. row.key
			check(spec ~= nil, where .. " has a commander")
			eq(spec.entity, "grug_mobs:commander_" .. row.faction, where .. " entity")
			eq(spec.faction, COMMANDED[row.key], where .. " of the camp's faction")
			check(spec.level_min == 60 and spec.level_max == 60, where .. " level 60")
			eq(spec.tier, "elite", where .. " an elite")
			check(spec.respawn[1] == 270 and spec.respawn[2] == 330, where .. " back like a captain")
			eq(spec.area, row.zone_id .. "/" .. row.key, where .. " the camp's quest area")
			eq(spec.name, row.faction == "accord" and "War Commander Greyvow"
				or "War Commander Stonegrudge", where .. " the story bible's name")
			local roles = G.area_roles(row.key, band_of(row))
			check(roles["commander_" .. row.faction] and roles["commander_" .. row.faction][1] == 60,
				where .. " a kill objective may name him")
			check(roles["captain_" .. row.faction] and roles["captain_" .. row.faction][1] == 60,
				where .. " ...and the captain stays a target at 60")
		else
			eq(spec, nil, "W " .. row.key .. " has none")
			eq(G.area_roles(row.key, band_of(row))["commander_" .. row.faction], nil,
				"W " .. row.key .. " names none")
		end
	end
	eq(count, 2, "W exactly the two camps")
	eq(M.pvp_kind("grug_mobs:commander_throng"), "captain", "W a commander counts as a captain")
	local broken = copy(names)
	broken.commanders.pvp_camp_skyglass_canopy_accord_low = "Wrong"
	check(not pcall(M.new, catalog, broken), "W a commander in a lower camp stops the load")
	broken = copy(names)
	broken.commanders.pvp_fortress_accord = "Wrong"
	check(not pcall(M.new, catalog, broken), "W a commander in a fortress stops the load")
	-- His post on the real high-camp blueprint, for every race and turn.
	local build31 = dofile(wp40 .. "/r31_pvp_poi_blueprint.lua")
	for _, faction in ipairs({"accord", "throng"}) do
		for _, race in ipairs(catalog.FACTION_RACES[faction]) do
			for turns = 0, 3 do
				local bp = build31({}, {art = {kind = "pvp_camp_high", faction = faction, race = race,
					turns = turns}, blueprint_schema = "r36_r_test", numeric_id = 1})
				-- The registry's form: a world position per socket (here the
				-- blueprint's own cell coordinates).
				local registered = {}
				for index, socket in ipairs(bp.landmarks.sockets) do
					registered[index] = {id = socket.id, role = socket.role, yaw = 0,
						pos = {x = socket.x, y = socket.y, z = socket.z}}
				end
				local post = M.commander_socket(registered)
				local where = ("W %s %s turn %d"):format(faction, race, turns)
				if check(post ~= nil, where .. " a commander post") then
					local at = cell_at(bp)
					local p = post.pos
					check(at(p.x, p.y, p.z) == "air" and at(p.x, p.y + 1, p.z) == "air",
						where .. " on open floor")
					check(at(p.x, p.y - 1, p.z) ~= nil and at(p.x, p.y - 1, p.z) ~= "air",
						where .. " ...with ground under it")
					local captain
					for _, socket in ipairs(registered) do
						if socket.role == "captain" then captain = socket end
						check(not (socket.pos.x == p.x and socket.pos.z == p.z),
							where .. " ...on no other socket (" .. socket.id .. ")")
					end
					local dx, dz = p.x - captain.pos.x, p.z - captain.pos.z
					eq(dx * dx + dz * dz, 25, where .. " ...five nodes beside the captain")
				end
			end
		end
	end
	local low = build31({}, {art = {kind = "pvp_camp_low", faction = "accord", race = "human",
		turns = 0}, blueprint_schema = "r36_r_test", numeric_id = 1})
	check(M.commander_socket({}) == nil, "W no captain, no post")
	check(low.landmarks ~= nil, "W the lower camp builds")
end

-- Placement through the real start_npcs.lua.
local POIS = {
	{key = "pvp_camp_gravesalt_escarpment_throng_high", kind = "pvp_camp_high", faction = "throng",
		race = "undead", anchor = {x = -1900, y = 120, z = 300}},
	{key = "pvp_camp_skyglass_canopy_accord_high", kind = "pvp_camp_high", faction = "accord",
		race = "elf", anchor = {x = 1900, y = 90, z = -300}},
	{key = "pvp_camp_skyglass_canopy_throng_high", kind = "pvp_camp_high", faction = "throng",
		race = "troll", anchor = {x = 2000, y = 80, z = 300}},
}
local build31 = dofile(wp40 .. "/r31_pvp_poi_blueprint.lua")
for _, poi in ipairs(POIS) do
	local bp = build31({}, {art = {kind = poi.kind, faction = poi.faction, race = poi.race, turns = 0},
		blueprint_schema = "r36_r_test", numeric_id = 1})
	grug_core.register_settlement_sockets(poi.key, bp.landmarks.race, poi.anchor,
		bp.landmarks.sockets, poi.key)
end
_G.grug_quests = {}
dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
dofile(repo .. "/mods/PLAYER/grug_quests/npcs.lua")
for _, fn in ipairs(loaded) do fn() end
local function heartbeat(seconds)
	gametime = gametime + seconds
	walltime = walltime + seconds
	for _, fn in ipairs(npc_steps) do fn(5) end
end
local function holders(key)
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid and entity._grug_start == key then
			check(out[entity._grug_socket] == nil, "W one NPC on " .. key .. "/" .. tostring(entity._grug_socket))
			out[entity._grug_socket] = entity
		end
	end
	return out
end
local function die(entity)
	if entity.on_die then entity.on_die(entity) end
	entity.object:remove()
end
do
	heartbeat(5)
	for _, poi in ipairs(POIS) do
		local placed = holders(poi.key)
		local commander = placed.commander
		local where = "W " .. poi.key
		if COMMANDED[poi.key] then
			if check(commander ~= nil, where .. " the commander is placed") then
				eq(commander.name, "grug_mobs:commander_" .. poi.faction, where .. " entity")
				eq(commander._grug_level, 60, where .. " level 60")
				eq(commander._grug_tier, "elite", where .. " elite")
				eq(commander._grug_elite_checked, true, where .. " no later promotion")
				eq(commander.description, names.commanders[poi.key], where .. " named")
				eq(commander._grug_area, G.area(poi.key), where .. " quest area")
				local post = M.commander_socket(grug_core.settlement_sockets_at(poi.key))
				check(commander._grug_post_x == post.pos.x and commander._grug_post_z == post.pos.z,
					where .. " holds his post")
				check(commander._grug_home and commander._grug_home.x == post.pos.x, where .. " homed there")
				eq(commander._grug_faction or core.registered_entities[commander.name]._grug_faction,
					poi.faction, where .. " of the camp's faction")
			end
		else
			eq(commander, nil, where .. " has no commander")
		end
		local captain = placed.captain
		if check(captain ~= nil, where .. " the captain is placed") then
			eq(captain._grug_tier or "normal", "normal", where .. " the captain stays a normal leader")
			eq(captain._grug_level, 60, where .. " ...at level 60")
			eq(captain._grug_area, G.area(poi.key), where .. " ...in the camp's quest area")
		end
	end
	local def = core.registered_entities["grug_mobs:commander_accord"]
	check(math.abs(def.visual_size.x - 1.15) < 1e-9, "W a commander is drawn at a leader's 1.15")
	eq(def._grug_hp_scale, 1.5, "W ...with a leader's HP")
	eq(def._grug_pvp_kind, "captain", "W ...counted as a captain by grug_pvp")
	-- Respawn like a captain.
	local key = "pvp_camp_gravesalt_escarpment_throng_high"
	local commander = holders(key).commander
	local t0 = gametime
	die(commander)
	local due = tonumber(store["startnpcdue:" .. key .. ":commander"])
	check(due and due >= t0 + 270 and due <= t0 + 330,
		"W the commander is due in 270-330 s (" .. tostring(due and due - t0) .. ")")
	heartbeat(265)
	eq(holders(key).commander, nil, "W not back before his time")
	heartbeat(70)
	local back = holders(key).commander
	check(back ~= nil and back ~= commander, "W a fresh commander after about 5 min")
	eq(back and back._grug_tier, "elite", "W ...an elite again")
end

-- The captain's quest-drop path: grug_quests rolls a quest drop for a mob
-- whose shown name is one of the drop row's names (state.lua mob_counts,
-- Round 38); the captain shows his camp race's name, which the drop row
-- selects by his role and camp area.
do
	local state = read(repo .. "/mods/PLAYER/grug_quests/state.lua")
	check(state:find("return target.name_set[mob.description] == true", 1, true) ~= nil,
		"W quest drops match the mob's shown name")
	check(state:find("grug_mobs.register_participant_drop_hook(Q.roll_quest_drops)", 1, true) ~= nil,
		"W ...through the participant drop hook every eligible kill runs")
end

------------------------------------------------------------------------------
-- E. Who calls the boss up (Round 36 review): only a player with a finale
--    in the quest log or turned in (grug_quests.quest_held); a chapter-3
--    player alone at the tally-stone meets no boss.
------------------------------------------------------------------------------
do
	check(R.eligible(function(id) return id == "throng_main_finale" and "active" or nil end),
		"E the Throng's finale in the log is eligible")
	check(R.eligible(function(id) return id == "accord_main_final" and "completed" or nil end),
		"E the Accord's finished line is eligible")
	check(not R.eligible(function(id) return id == "throng_main_07" and "active" or nil end),
		"E a chapter-3 step is not")
	local held = {}
	grug_quests = {quest_held = function(player, id)
		local row = held[player:get_player_name()]
		return row and row[id] or nil
	end}
	local function clear()
		for _, entity in ipairs(bosses()) do entity.object:remove() end
		store["rift_boss_due:" .. R.SITE] = nil
		rift_pass(1)
	end
	for i = #players, 1, -1 do players[i] = nil end
	players[1] = new_player("lone", "throng", at_site(30, 0))
	held.lone = {throng_main_07 = "active"}
	clear()
	for _ = 1, 3 do rift_pass(1) end
	eq(#bosses(), 0, "E a chapter-3 player alone: no boss")
	held.lone = {throng_main_finale = "active"}
	rift_pass(1)
	eq(#bosses(), 1, "E with the finale active: the boss appears")
	held.lone = {throng_main_07 = "active"}
	rift_pass(1)
	eq(#bosses(), 1, "E a boss already up stays")
	clear()
	held.lone = {throng_main_finale = "completed", throng_main_final = "completed"}
	rift_pass(1)
	eq(#bosses(), 1, "E a finished player still calls him (the lockout decides the loot)")
	clear()
	held.lone = {}
	players[2] = new_player("ally", "accord", at_site(-30, 10))
	held.ally = {accord_main_collector = "active"}
	rift_pass(1)
	eq(#bosses(), 1, "E one eligible player among the near ones is enough")
	grug_quests = nil
end

if failures > 0 then
	error(("R36 R PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R36 R PORTABLE PASS checks=%d"):format(checks))
