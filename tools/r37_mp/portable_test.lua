-- Round 37 lane MP portable test (round37-plan.md §2.1.5, §2.1.6, §2.4, §4.3;
-- audit package P3, MOC-04, MOC-05). Loads the REAL code under small stubs:
-- grug_mobs/liveness.lua and rares.lua in full, grug_core/homing.lua in full,
-- and the touched pieces cut out of mobs/api.lua, grug_mobs/bosses.lua,
-- boss_dragons.lua, verbs.lua, start_npcs.lua and init.lua. Checks:
--   A  MOB-03 the active-mob limit: a wild mob reactivating at the limit is
--      removed and add_mob refuses one; an NPC, a mob authored by its
--      definition (the dragons, the rift boss) and one authored by its
--      spawner (a rare, a leader, through add_mob) activate at the limit, are
--      not counted and keep the mark in their staticdata.
--   S  MOB-06 a shutdown makes no despawn decision: with no player left the
--      saved copy is the mob, not the terminal marker.
--   R  MOC-01 the rares: one Grimtusk per generation; no absence counts
--      while nobody is near or while its last place is inactive (also with a
--      player at another route point, hours of game time); a restart keeps
--      it; a stale or second copy removes itself on activation; a rare gone
--      without a kill is lost after a minute at its active last place, the
--      next one is a new generation and the old copy removes itself.
--   D  MOC-03 the dragon: the same rule on the boss pass; lost, it gets the
--      warned return (warning, 60 s, "has returned"), the old copy is stale.
--   B  MOC-02 Bone Call: at most four raiders, the King's faction (the
--      acquisition veto reads it), gone on the encounter reset.
--   G  MOC-06 a royal guard killed outside a reset or the King's death
--      returns after 15 minutes (wall clock); the King's death books the group.
--   F  MOC-04 the breath fan and the King's volley: the middle shot homes and
--      the locked target takes one hit (three before), a side shot hits a
--      bystander, passes a player the shooter would not attack, and makes the
--      breath's ground patch where it lands (hit_node).
--   P  MOC-05 patches only into air: snow, plants and water stay, a patch
--      renews a patch, the terrain guard still refuses.
--   W  the wiring: the activation claim runs first, the spawners hand in
--      their marks and generations.
-- Usage (repo root): luajit tools/r37_mp/portable_test.lua [REPO]
-- Prints "R37 MP PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
-- A piece of `text` from the plain anchor `from` to the first `to` after it
-- (after `after` when given).
local function cut(text, from, to, label, after)
	local a = text:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor")
	local search = a
	if after then
		search = text:find(after, a, true)
		check(search ~= nil, label .. ": inner anchor")
	end
	local b, e = text:find(to, search, true)
	check(b ~= nil, label .. ": end anchor")
	return text:sub(a, e)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

-- ---------------------------------------------------------------------------
-- Engine stubs
-- ---------------------------------------------------------------------------
local function vec(x, y, z) return {x = x, y = y, z = z} end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x or 0, y or 0, z or 0)
	end,
	offset = function(p, x, y, z) return vec(p.x + x, p.y + y, p.z + z) end,
	subtract = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
	add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end,
	multiply = function(a, s) return vec(a.x * s, a.y * s, a.z * s) end,
	length = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	round = function(p)
		return vec(math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5))
	end,
}

-- A flat serializer, enough for staticdata of plain fields.
local function serialize(value)
	local t = type(value)
	if t == "table" then
		local parts = {}
		for k, v in pairs(value) do
			local sv = serialize(v)
			if sv then parts[#parts + 1] = "[" .. serialize(k) .. "] = " .. sv end
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" then
		return tostring(value)
	end
	return nil
end
local function deserialize(text)
	if not text or text == "" then return nil end
	return assert(loadstring("return " .. text:gsub("^return ", "")))()
end

local function new_storage()
	local data = {}
	return {
		data = data,
		get_int = function(_, k) return math.floor(tonumber(data[k]) or 0) end,
		set_int = function(_, k, v) data[k] = tostring(v) end,
		get_string = function(_, k) return data[k] or "" end,
		set_string = function(_, k, v) data[k] = v end,
	}
end

local objects = {} -- every live object, for radius scans
local function new_object(pos, ent)
	local o = {pos = vec(pos.x, pos.y, pos.z), removed = false, props = {},
		vel = vec(0, 0, 0), ent = ent}
	function o:get_pos()
		if self.removed then return nil end
		return vec(self.pos.x, self.pos.y, self.pos.z)
	end
	function o:set_pos(p) self.pos = vec(p.x, p.y, p.z) end
	function o:remove() self.removed = true end
	function o:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function o:get_properties() return self.props end
	function o:get_luaentity() if self.removed then return nil end return self.ent end
	function o:is_player() return false end
	function o:set_velocity(v) self.vel = vec(v.x, v.y, v.z) end
	function o:get_velocity() return vec(self.vel.x, self.vel.y, self.vel.z) end
	function o:set_armor_groups() end
	function o:set_texture_mod() end
	function o:set_animation() end
	function o:get_yaw() return 0 end
	function o:get_attach() return nil end
	objects[#objects + 1] = o
	return o
end

local players = {}
local function new_player(name, pos, faction)
	local p = {name = name, pos = vec(pos.x, pos.y, pos.z), hp = 1000, punched = 0,
		faction = faction, props = {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return vec(self.pos.x, self.pos.y, self.pos.z) end
	function p:get_hp() return self.hp end
	function p:get_luaentity() return nil end
	function p:get_attach() return nil end
	function p:get_velocity() return vec(0, 0, 0) end
	function p:get_properties() return self.props end
	function p:punch() self.punched = self.punched + 1 end
	players[#players + 1] = p
	objects[#objects + 1] = p
	return p
end

local function inside(list, pos, radius)
	local result = {}
	for _, o in ipairs(list) do
		local p = o:get_pos()
		if p and vector.distance(p, pos) <= radius then result[#result + 1] = o end
	end
	return result
end

-- The node world for the projectile part: walkable ground at y <= 0.
local world = {}
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
local function node_at(p)
	local r = vector.round(p)
	local n = world[key(r)]
	if n then return n end
	return {name = r.y <= 0 and "default:dirt" or "air"}
end
local registered_nodes = {
	air = {walkable = false, buildable_to = true},
	["default:dirt"] = {walkable = true},
	["default:snow"] = {walkable = true, buildable_to = true},
	["default:grass_1"] = {walkable = false, buildable_to = true},
	["default:water_source"] = {walkable = false, buildable_to = true},
	["grug_mobs:dragon_rime"] = {walkable = false, buildable_to = true},
	["grug_mobs:dragon_scorch"] = {walkable = false, buildable_to = true},
}

-- A node-only ray: samples along a -> b, yields each non-air node crossed.
local function raycast(a, b)
	local list, last = {}, nil
	local length = vector.distance(a, b)
	local steps = math.max(1, math.ceil(length / 0.05))
	local prev = vector.round(a)
	for i = 0, steps do
		local t = i / steps
		local p = vec(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
		local r = vector.round(p)
		if not last or key(r) ~= key(last) then
			if node_at(r).name ~= "air" then
				list[#list + 1] = {type = "node", under = r, above = prev,
					intersection_point = p}
			end
			prev = last or r
			last = r
		end
	end
	local i = 0
	return function() i = i + 1 return list[i] end
end

local gametime, wall = 1000, 2000000000
local active = function() return false end -- compare_block_status(pos, "active")
local logs, chats, broadcasts, shutdown = {}, {}, {}, {}
local steps = {}
core = {
	log = function(_, text) logs[#logs + 1] = text end,
	serialize = serialize,
	deserialize = deserialize,
	get_gametime = function() return gametime end,
	get_us_time = function() return 0 end,
	compare_block_status = function(pos, cond) return cond == "active" and active(pos) end,
	get_connected_players = function() return players end,
	get_player_by_name = function(name)
		for _, p in ipairs(players) do if p.name == name then return p end end
	end,
	is_player = function(o) return type(o) == "table" and o.is_player ~= nil and o:is_player() end,
	get_objects_inside_radius = function(pos, radius) return inside(objects, pos, radius) end,
	get_node_or_nil = function(p) return node_at(p) end,
	get_node = function(p) return node_at(p) end,
	set_node = function(p, n) world[key(vector.round(p))] = {name = n.name} end,
	get_node_timer = function() return {start = function() end} end,
	registered_nodes = registered_nodes,
	registered_entities = {},
	get_item_group = function() return 0 end,
	raycast = raycast,
	add_particle = function() end,
	add_particlespawner = function() end,
	sound_play = function() end,
	chat_send_player = function(name, text) chats[#chats + 1] = {name, text} end,
	chat_send_all = function(text) broadcasts[#broadcasts + 1] = text end,
	colorize = function(_, text) return text end,
	pos_to_string = function(p) return "(" .. p.x .. "," .. p.y .. "," .. p.z .. ")" end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_shutdown = function(fn) shutdown[#shutdown + 1] = fn end,
	settings = {get = function() return nil end, get_bool = function() return nil end},
}
setmetatable(core, {__index = function(_, k)
	if type(k) == "string" and k:match("^register_") then return function() end end
	return nil
end})
grug_sounds = {play = function() return false end}

-- ---------------------------------------------------------------------------
-- A  MOB-03, S  MOB-06: the touched pieces of mobs/api.lua.
-- ---------------------------------------------------------------------------
local api = read("mods/ENTITIES/mobs/api.lua")
local function api_cut(from, to, label, after) return cut(api, from, to, "api " .. label, after) end
local api_source = table.concat({
	"local active_limit = 2\nlocal active_mobs = 0\nlocal remove_far = true\n",
	api_cut("local active_mob_counted = setmetatable", "\nend\n", "counted"),
	api_cut("local function at_limit()", "\nend\n", "at_limit"),
	api_cut("local function grug_authored(self, tmp)", "\nend\n", "grug_authored"),
	"\n", api_cut("local grug_shutting_down = false",
		"core.register_on_shutdown(function() grug_shutting_down = true end)", "shutdown"),
	"\n", api_cut("local function get_distance(a, b)", "\nend\n", "get_distance"),
	api_cut("local function remove_mob(self)", "\nend\n", "remove_mob"),
	api_cut("function mob_class:on_deactivate(removal)", "\nend\n", "on_deactivate"),
	api_cut("local function clean_staticdata(self)", "\nend\n", "clean_staticdata"),
	api_cut("local DESPAWN_MIN_DISTANCE = 48",
		"return (roll or random()) < chance, nearest\nend\n", "despawn"),
	api_cut("function mob_class:mob_staticdata()", "\nend\n", "staticdata"),
	api_cut("local is_property_name = {", "\n}\n", "properties"),
	api_cut("function mob_class:mob_activate(staticdata, def, dtime)", "\nend\n", "activate"),
	api_cut("local function count_mobs(pos, mob_name)", "\nend\n", "count_mobs"),
	api_cut("function mobs:add_mob(pos, def)", "\nend\n", "add_mob"),
	"\nreturn function() return active_mobs end\n",
}, "")
local mob_class = {}
function mob_class:set_yaw() end
function mob_class:set_animation() end
local api_mobs = {spawning_mobs = {}}
local protos = {}
local api_env = {
	mob_class = mob_class, mobs = api_mobs, random = math.random, pi = math.pi,
	table_copy = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end,
	use_cmi = false, use_vh1 = false, square = math.sqrt, aoc_range = 64,
	is_player = core.is_player,
	grug_obstacle = {cancel_path_request = function() end},
	grug_mobs = {},
}
local active_count = load_in(api_source, api_env, "api")

local api_core_add -- core.add_entity for the api part
local function proto(name, fields)
	local p = setmetatable({name = name, type = "monster", hp_min = 10, health = 0,
		armor = 100, texture_mods = "", lifetimer = 180,
		base_texture = {"x.png"}, base_colbox = {-0.5, 0, -0.5, 0.5, 1, 0.5}},
		{__index = mob_class})
	for k, v in pairs(fields or {}) do p[k] = v end
	protos[name] = p
	core.registered_entities[name] = p
	api_mobs.spawning_mobs[name] = {aoc = 9}
	return p
end
proto("grug_mobs:boar")
proto("grug_mobs:guard_accord", {type = "npc"})
proto("grug_mobs:rift_boss", {_grug_authored = true})
-- An activation as the engine runs it: a fresh table over the prototype.
local function activate(name, pos, staticdata)
	local ent = setmetatable({}, {__index = protos[name]})
	ent.object = new_object(pos, ent)
	ent.object.props.hp_max = 20
	ent:mob_activate(staticdata, {textures = {{"x.png"}}}, 0)
	return ent
end
api_core_add = function(pos, name, staticdata)
	local ent = activate(name, pos, staticdata)
	if ent.object.removed then return nil end
	return ent.object
end
local real_add_entity = core.add_entity
core.add_entity = api_core_add

local at = vec(0, 10, 0)
local wild1 = activate("grug_mobs:boar", at)
local wild2 = activate("grug_mobs:boar", at)
check(active_count() == 2 and not wild1.object.removed and not wild2.object.removed,
	"A1 two wild mobs fill the limit of 2")
local wild3 = activate("grug_mobs:boar", at)
check(wild3.object.removed and active_count() == 2,
	"A2 a wild mob reactivating at the limit is removed (upstream rule kept)")
local guard = activate("grug_mobs:guard_accord", at)
check(not guard.object.removed and active_count() == 2,
	"A3 an NPC activates at the limit and is not counted")
local boss = activate("grug_mobs:rift_boss", at)
check(not boss.object.removed and active_count() == 2,
	"A4 a definition-authored actor (rift boss, dragons) activates at the limit, uncounted")
local stored_rare = activate("grug_mobs:boar", at, serialize({_grug_authored = true,
	_grug_rare_id = "grimtusk"}))
check(not stored_rare.object.removed and stored_rare._grug_rare_id == "grimtusk" and
	active_count() == 2, "A5 a stored rare reactivates at the limit from its staticdata")
-- add_mob needs a player in range (count_mobs).
local adder = new_player("adder", vec(0, 10, 5), "accord")
local plain = api_env.mobs.add_mob(api_env.mobs, at, {name = "grug_mobs:boar"})
check(plain == nil and active_count() == 2, "A6 add_mob refuses a wild mob at the limit")
local leader = api_env.mobs.add_mob(api_env.mobs, at,
	{name = "grug_mobs:boar", ignore_count = true, _grug_authored = true})
check(leader ~= nil and leader._grug_authored == true and active_count() == 2,
	"A7 add_mob places an authored mob (rare, leader) at the limit, uncounted")
leader.remove_ok = true
local saved = deserialize(leader:mob_staticdata())
check(saved and saved._grug_authored == true and saved._grug_despawn_terminal == nil,
	"A8 the mark is in the authored mob's staticdata")
leader:on_deactivate(false)
guard:on_deactivate(false)
check(active_count() == 2, "A9 deactivating an uncounted actor leaves the count")
wild1:on_deactivate(false)
check(active_count() == 1, "A10 deactivating a counted mob debits it")
local wild4 = activate("grug_mobs:boar", at)
check(not wild4.object.removed and active_count() == 2, "A11 below the limit a wild mob activates")

-- S: the shutdown. No player is left when the engine saves the objects.
for i = #players, 1, -1 do players[i] = nil end
wild2.remove_ok = true
local before = deserialize(wild2:mob_staticdata())
check(before and before._grug_despawn_terminal == true,
	"S1 with no player near, an unload still culls an eligible wild mob")
check(#shutdown == 1, "S2 api.lua registers one shutdown callback")
shutdown[1]()
local after = deserialize(wild2:mob_staticdata())
check(after and after._grug_despawn_terminal == nil and after.name == nil and
	after.state == "stand", "S3 during a shutdown the saved copy is the mob itself")
core.add_entity = real_add_entity
for i = #objects, 1, -1 do objects[i] = nil end

-- ---------------------------------------------------------------------------
-- R  MOC-01: liveness.lua and rares.lua, the real files.
-- ---------------------------------------------------------------------------
local storage = new_storage()
local deactivate_base = function() end
local function load_rares()
	steps = {}
	grug_mobs = {storage = storage, registered_rares = nil}
	mobs = {mob_class = {on_deactivate = deactivate_base}}
	grug_core = {
		rare_route = function(id)
			-- Each rare its own stretch; Grimtusk's points 160 apart on x.
			local base = id == "grimtusk" and 0 or 10000 + #id * 1000
			return {vec(base, 1, 0), vec(base + 80, 1, 0), vec(base + 160, 1, 0)}
		end,
		get_player_faction = function(name)
			local p = core.get_player_by_name(name)
			return p and p.faction
		end,
	}
	grug_zones = {faction_at = function() return "accord" end}
	grug_mobs.claim_refuses_spawn = function() return false end
	grug_mobs.set_tier = function() end
	grug_mobs.place_on_ground = function() end
	grug_mobs.add_mob = function(pos, def)
		local ent = {name = def.name, _grug_authored = def._grug_authored}
		for k, v in pairs(def._grug_staticdata or {}) do ent[k] = v end
		ent.object = new_object(pos, ent)
		-- The first activation inside add_entity (init.lua's wrapper).
		grug_mobs.live_claim(ent)
		return ent
	end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/liveness.lua")
	dofile(repo .. "/mods/ENTITIES/grug_mobs/rares.lua")
	return steps[1]
end
-- route_pos needs air over solid ground at the route points.
world = {}
local rare_step = load_rares()
check(type(rare_step) == "function", "R0 rares.lua registers its one globalstep")
local function pass(step, seconds)
	gametime = gametime + seconds
	wall = wall + seconds
	step(seconds)
end
local function rares_of(id)
	local list = {}
	for _, o in ipairs(objects) do
		local ent = o.ent
		if ent and not o.removed and ent._grug_rare_id == id then list[#list + 1] = ent end
	end
	return list
end
local function deactivate(ent, removal) mobs.mob_class.on_deactivate(ent, removal) end
local function reactivate(ent)
	-- The stored copy comes back as a new Lua entity with its saved fields.
	local copy = {}
	for k, v in pairs(ent) do if k ~= "object" then copy[k] = v end end
	copy.object = new_object(ent.object.pos, copy)
	local kept = grug_mobs.live_claim(copy)
	return copy, kept
end

-- Active blocks: around each player, 64 nodes (active_block_range 4).
active = function(pos)
	for _, p in ipairs(players) do
		if vector.distance(p:get_pos(), pos) <= 64 then return true end
	end
	return false
end
local route = grug_core.rare_route("grimtusk")
local visitor = new_player("visitor", vec(route[1].x + 10, 1, 0), "accord")
pass(rare_step, 10)
local list = rares_of("grimtusk")
check(#list == 1 and storage:get_int("rare_alive:grimtusk") == 1,
	"R1 a player near the route: one Grimtusk spawns")
local first = list[1]
check(first._grug_live_key == "rare:grimtusk" and first._grug_live_gen == 1 and
	first._grug_authored == true, "R2 it carries its key, generation 1 and the authored mark")
check(storage:get_string("live_pos:rare:grimtusk") == route[1].x .. " 1 0",
	"R3 its place is recorded at once")
local sightings = 0
for _, c in ipairs(chats) do if c[2]:find("Grimtusk", 1, true) then sightings = sightings + 1 end end
check(sightings == 1, "R4 one faction broadcast")

-- The player walks away; the rare's block unloads with it.
players[1] = nil
deactivate(first, false)
first.object.removed = true -- out of memory, on disk
for _ = 1, 6 * 360 do pass(rare_step, 10) end -- six hours of game time
check(#rares_of("grimtusk") == 0 and storage:get_int("rare_alive:grimtusk") == 1 and
	storage:get_int("live_absent:rare:grimtusk") == 0,
	"R5 six hours with nobody near: nothing counts, no second Grimtusk")
-- A player at the route's FAR end: its last place stays inactive.
players[1] = visitor
visitor.pos = vec(route[3].x + 10, 1, 0)
for _ = 1, 6 * 360 do pass(rare_step, 10) end
check(#rares_of("grimtusk") == 0 and storage:get_int("rare_alive:grimtusk") == 1,
	"R6 a player at another route point for six hours: the unseen rare is not lost")

-- A restart: the modules come back empty, storage persists.
rare_step = load_rares()
visitor.pos = vec(route[1].x + 5, 1, 0)
local back, kept = reactivate(first)
check(kept and not back.object.removed, "R7 after a restart the stored Grimtusk claims its key")
local twin, twin_kept = reactivate(first)
check(not twin_kept and twin.object.removed and twin.object.props.static_save == false,
	"R8 a second copy of the current generation removes itself (no static copy)")
local old = {}
for k, v in pairs(first) do if k ~= "object" then old[k] = v end end
old._grug_live_gen = 0
old.object = new_object(route[1], old)
check(not grug_mobs.live_claim(old) and old.object.removed,
	"R9 a copy of an older generation removes itself")
for _ = 1, 30 do pass(rare_step, 10) end
check(#rares_of("grimtusk") == 1, "R10 while it stands, exactly one Grimtusk")

-- A death nobody reported (lava, an admin): removed where it stood.
back.object.pos = vec(route[1].x + 3, 1, 0)
deactivate(back, true)
back.object.removed = true
for _ = 1, 5 do pass(rare_step, 10) end
check(storage:get_int("rare_alive:grimtusk") == 1 and
	storage:get_int("live_absent:rare:grimtusk") == 50,
	"R11 missing at its active last place: 50 s count, not lost yet")
pass(rare_step, 10)
check(storage:get_int("rare_alive:grimtusk") == 0 and
	storage:get_int("rare_next:grimtusk") == gametime, "R12 a minute missing there: lost, respawn released")
pass(rare_step, 10)
list = rares_of("grimtusk")
check(#list == 1 and list[1]._grug_live_gen == 2, "R13 the next Grimtusk is generation 2")
local ghost, ghost_kept = reactivate(first)
check(not ghost_kept and ghost.object.removed, "R14 the lost generation-1 copy removes itself on load")
-- A kill books the ordinary 2-4 h respawn and nothing comes before it.
grug_mobs.rare_killed("grimtusk")
list[1].object.removed = true
deactivate(list[1], true)
for _ = 1, 700 do pass(rare_step, 10) end -- about 1.9 h
check(#rares_of("grimtusk") == 0, "R15 after a kill nothing returns before the respawn")
for _ = 1, 100 do pass(rare_step, 10) end -- past 2 h: the booked respawn
list = rares_of("grimtusk")
check(#list <= 1, "R16 never two at once")
if #list == 0 then for _ = 1, 800 do pass(rare_step, 10) end list = rares_of("grimtusk") end
check(#list == 1 and list[1]._grug_rare_id == "grimtusk" and list[1]._grug_live_gen == 3 and
	list[1].description == "Grimtusk" and list[1].lifetimer == 30000,
	"R17 the respawned rare carries its identity and generation from its first staticdata")
-- A death without a player's lethal hit (a guard, lava, a fall) goes through
-- the shared death boundary, which books the ordinary respawn.
local settle = load_in("local kill_loot_hooks = {}\n" ..
	cut(read("mods/ENTITIES/grug_mobs/init.lua"), "function grug_mobs.settle_mob_death(self)",
		"\nend\n", "settle") .. "return grug_mobs.settle_mob_death\n",
	{grug_core = {disengage_mob = function() end}}, "settle")
grug_mobs.award_kill_xp = function() end
local victim = list[1]
settle(victim)
victim.object.removed = true
deactivate(victim, true)
local due = storage:get_int("rare_next:grimtusk")
check(storage:get_int("rare_alive:grimtusk") == 0 and due >= gametime + 7200 and
	due <= gametime + 14400, "R18 a rare killed by a guard or lava books its 2-4 h respawn")
for _ = 1, 30 do pass(rare_step, 10) end
check(#rares_of("grimtusk") == 0, "R19 and no fresh rare a minute later (the liveness 'lost' is for removals only)")
settle(victim)
check(storage:get_int("rare_next:grimtusk") == due, "R20 a second settle books nothing twice")
for i = #objects, 1, -1 do objects[i] = nil end
for i = #players, 1, -1 do players[i] = nil end

-- ---------------------------------------------------------------------------
-- D  MOC-03: the dragon pass of bosses.lua.
-- ---------------------------------------------------------------------------
local bosses = read("mods/ENTITIES/grug_mobs/bosses.lua")
local dragon_source = "local storage = ...\nlocal DRAGONS = {wyrmglass = {name = \"The Ice Dragon\", " ..
	"entity = \"grug_mobs:ice_dragon\", x = 0, z = 0}}\n" ..
	cut(bosses, "local function dragon_pos(row, dx, dz)", "\nend\n", "dragon_pos") ..
	cut(bosses, "-- The dragon's liveness key (liveness.lua) is its boss id.", "\nend)\n",
		"dragon pass", "core.register_globalstep(function(dtime)")
steps = {}
local dragon_env = {
	os = {time = function() return wall end},
	grug_zones = {terrain_height_at = function() return 0 end},
}
core.add_entity = function(pos, name, staticdata)
	local ent = {name = name}
	for k, v in pairs(deserialize(staticdata) or {}) do ent[k] = v end
	ent.object = new_object(pos, ent)
	if not grug_mobs.live_claim(ent) then return nil end
	storage:set_string("boss:dragon:wyrmglass:alive", "1") -- the def's after_activate
	return ent.object
end
local chunk = assert(loadstring(dragon_source, "=dragon pass"))
setfenv(chunk, setmetatable(dragon_env, {__index = _G}))
chunk(storage)
local dragon_step = steps[1]
local function dragons()
	local result = {}
	for _, o in ipairs(objects) do
		if o.ent and not o.removed and o.ent.name == "grug_mobs:ice_dragon" then
			result[#result + 1] = o.ent
		end
	end
	return result
end
local keeper = new_player("keeper", vec(10, 1, 0), "throng")
pass(dragon_step, 10)
local dl = dragons()
check(#dl == 1 and dl[1]._grug_live_gen == 1 and
	storage:get_string("boss:dragon:wyrmglass:alive") == "1" and #broadcasts == 0,
	"D1 the first dragon is created without a warning, generation 1")
local dragon1 = dl[1]
players[1] = nil
deactivate(dragon1, false)
dragon1.object.removed = true
for _ = 1, 100 do pass(dragon_step, 10) end
check(storage:get_string("boss:dragon:wyrmglass:alive") == "1" and #dragons() == 0,
	"D2 unloaded with nobody near: alive stays, nothing respawns")
-- Back, then removed without on_die (/clear_mobs) while the keeper stands by.
players[1] = keeper
local d_back = reactivate(dragon1)
deactivate(d_back, true)
d_back.object.removed = true
for _ = 1, 5 do pass(dragon_step, 10) end
check(storage:get_string("boss:dragon:wyrmglass:alive") == "1", "D3 50 s missing: not lost yet")
pass(dragon_step, 10)
check(storage:get_string("boss:dragon:wyrmglass:alive") == "" and
	tonumber(storage:get_string("boss:dragon:wyrmglass:due")) == wall,
	"D4 a minute missing at its active place: lost, the return is due now")
pass(dragon_step, 10)
local warned = false
for _, c in ipairs(chats) do if c[2]:find("returns in 60 seconds", 1, true) then warned = true end end
check(warned and #dragons() == 0, "D5 the ordinary 60 s warning runs first")
for _ = 1, 6 do pass(dragon_step, 10) end
dl = dragons()
check(#dl == 1 and dl[1]._grug_live_gen == 2 and broadcasts[#broadcasts] and
	broadcasts[#broadcasts]:find("has returned", 1, true),
	"D6 then the dragon has returned, generation 2")
local stale_dragon, stale_kept = reactivate(dragon1)
check(not stale_kept and stale_dragon.object.removed, "D7 the lost dragon's old copy removes itself")
core.add_entity = real_add_entity
for i = #objects, 1, -1 do objects[i] = nil end
for i = #players, 1, -1 do players[i] = nil end

-- ---------------------------------------------------------------------------
-- B  MOC-02: Bone Call, and init.lua's faction veto.
-- ---------------------------------------------------------------------------
local resets = 0
local bone_source = "local royal_reset\n" ..
	cut(bosses, "local BONE_CALL_CAP = 4", "\tremove_royal_summons(self)\nend\n", "bone call",
		"royal_reset = function(self)") ..
	"return bone_call, royal_reset\n"
local bone_call, royal_reset = load_in(bone_source, {grug_mobs = {
	royal_encounter_reset = function() resets = resets + 1 end}}, "bone call")
core.add_entity = function(pos, name)
	local ent = {name = name, health = 30}
	ent.object = new_object(pos, ent)
	return ent.object
end
local king = {_grug_boss_id = "king:undead", health = 100}
king.object = new_object(vec(0, 1, 0), king)
local function summons()
	local n, faction_ok = 0, true
	for _, o in ipairs(objects) do
		local e = o.ent
		if e and not o.removed and e._grug_royal_summon == "king:undead" and e.health > 0 then
			n = n + 1
			faction_ok = faction_ok and e._grug_faction == "throng"
		end
	end
	return n, faction_ok
end
for _ = 1, 5 do bone_call(king, "throng") end
local n, faction_ok = summons()
check(n == 4 and faction_ok, "B1 five casts leave four raiders, all of the King's faction")
for _, o in ipairs(objects) do
	if o.ent and o.ent._grug_royal_summon then o.ent.health = 0 break end
end
bone_call(king, "throng")
check(summons() == 4, "B2 a fallen raider is replaced up to the cap only")
royal_reset(king)
check(summons() == 0 and resets == 1, "B3 the encounter reset restores the retinue and removes the raiders")
core.add_entity = real_add_entity
for i = #objects, 1, -1 do objects[i] = nil end

local init = read("mods/ENTITIES/grug_mobs/init.lua")
local veto = load_in(cut(init, "local function faction_veto(s, player)", "\n\tend\n", "faction veto") ..
	"return faction_veto\n", {faction = nil, grug_core = {get_player_faction = function(name)
		return ({t = "throng", a = "accord"})[name]
	end}}, "faction veto")
local function pl(name) return {get_player_name = function() return name end} end
local raider = {_grug_faction = "throng"}
check(veto(raider, pl("t")) and not veto(raider, pl("a")) and veto(raider, pl("nobody")),
	"B4 a raider with the King's faction spares the Throng, attacks the Accord")
check(not veto({}, pl("t")) and not veto({}, pl("a")), "B5 a factionless monster vetoes nobody")
check(init:find("grug_factions.get_object_faction(self.attack) ==\n\t\t\t\t\t\tself._grug_faction", 1, true) ~= nil,
	"B6 a mob with an instance faction stops attacking its own faction")

-- ---------------------------------------------------------------------------
-- G  MOC-06: royal guards return on their own.
-- ---------------------------------------------------------------------------
local npcs = read("mods/ENTITIES/grug_mobs/start_npcs.lua")
local booked = {}
local slot_a = {id = "royal_1", placed = true, royal = true}
local slot_k = {id = "king", placed = true, royal = true, leader = true}
local row = {key = "cap", slots = {slot_a, slot_k}, by_socket = {royal_1 = slot_a, king = slot_k}}
local royal_source = cut(npcs, "-- A royal guard's or bodyguard's return after its death",
	"\nend\n", "royal", "function grug_mobs.royal_king_died(self)") ..
	"return ROYAL_RETURN\n"
local g_mobs = {}
local royal_return = load_in(royal_source, {
	grug_mobs = g_mobs, by_key = {cap = row}, os = {time = function() return wall end},
	mark_free = function(_, slot, due) slot.placed = false slot.due = due booked[slot.id] = due end,
	claims_of = function() return {} end, storage = new_storage(),
	due_key = function(a, b) return a .. ":" .. b end,
}, "royal")
check(royal_return == 900, "G1 the return interval is 15 minutes")
g_mobs.royal_guard_died({_grug_start = "cap", _grug_socket = "royal_1"})
check(booked.royal_1 == wall + 900 and booked.royal_1 > 1000000000,
	"G2 a guard killed outside a fight is due in 15 minutes, on the wall clock")
check(npcs:find("slot.due > 1000000000 and wall_now or now", 1, true) ~= nil and
	npcs:find("ROYAL_HOLD", 1, true) == nil, "G3 serve compares that due with the wall clock; no endless hold")
slot_a.placed = true
g_mobs.royal_king_died({_grug_start = "cap"})
check(booked.royal_1 == wall + 900, "G4 the King's death books the whole group the same 15 minutes")

-- ---------------------------------------------------------------------------
-- F  MOC-04 and P  MOC-05: the fan, the shots and the patches.
-- ---------------------------------------------------------------------------
grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/homing.lua")
local verbs = read("mods/ENTITIES/grug_mobs/verbs.lua")
local arrow_defs = {}
grug_mobs = {scale_attack_damage = function(x) return x end}
mobs = {has_priv = function(name) return name == "peaceful" end,
	is_invisible = function() return false end,
	register_arrow = function(_, name, def)
	arrow_defs[name] = def
	core.registered_entities[name] = {initial_properties = {}}
end}
load_in(cut(verbs, "local STRAIGHT_REACH = 0.7", "\nend\n", "verbs fan",
	"function grug_mobs.stamp_straight_arrow(ent, mob)") ..
	cut(verbs, "function grug_mobs.register_simple_arrow(name, opts)", "\nend\n", "simple arrow"),
	{}, "verbs fan")
local dragons_src = read("mods/ENTITIES/grug_mobs/boss_dragons.lua")
local protected = function() return false end
local placed = {}
local dragon_part = load_in(table.concat({
	"local TUNING = {trail_particles = 18}\nlocal function burst() end\n",
	cut(dragons_src, "local RIME = \"grug_mobs:dragon_rime\"",
		"local effect_node = {rime = RIME, scorch = SCORCH}\n", "effects"),
	cut(dragons_src, "local hostile_player = function(player)", "\nend\n", "hostile"),
	cut(dragons_src, "local function rounded_column(pos, y)",
		"grug_mobs.place_dragon_ground_effect = place_ground_effect\n", "patches"),
	cut(dragons_src, "local function projectile_hit(self, player)", "\nend\n", "projectile_hit"),
	cut(dragons_src, "local function projectile_node(self, pos)", "\nend\n", "projectile_node"),
	cut(dragons_src, "local function projectile_trail(self, dtime)", "\nend\n", "trail"),
	cut(dragons_src, "local function register_breath_arrow(", "\nend\n", "breath arrow"),
	cut(dragons_src, "local function shoot_breath(self, action, opts)", "\nend\n", "shoot_breath"),
	"register_breath_arrow(\"grug_mobs:ice_breath\", \"t.png\", \"rime\", \"frost breath\")\n",
	"return {shoot = shoot_breath, place = place_ground_effect}\n",
}, ""), {grug_core = {ground_effect_protected = function(pos, actor) return protected(pos, actor) end}},
	"dragon part")
local real_set_node = core.set_node
core.set_node = function(p, n) placed[#placed + 1] = vector.round(p) real_set_node(p, n) end

-- Projectiles as the engine moves them: velocity, then on_step.
local shots = {}
core.add_entity = function(pos, name)
	local def = arrow_defs[name]
	local ent = {name = name, velocity = def.velocity, lifetime = def.lifetime or 4.5,
		timer = 0, on_step = def.on_step}
	ent.object = new_object(pos, ent)
	if def.on_activate then def.on_activate(ent) end
	shots[#shots + 1] = ent
	return ent.object
end
local function fly(seconds)
	for _ = 1, math.floor(seconds / 0.05) do
		for _, s in ipairs(shots) do
			local o = s.object
			if not o.removed then
				o.pos = vector.add(o.pos, vector.multiply(o.vel, 0.05))
				s:on_step(0.05)
			end
		end
	end
end
-- The shooter: a dragon facing a target 20 nodes south.
local function shooter(pos, target, vetoed)
	local ent = {health = 18000, damage = 100, _grug_level = 70, view_range = 48}
	ent.object = new_object(pos, ent)
	ent.attack = target
	ent._grug_ignore_player = function(_, p) return p == vetoed end
	return ent
end
-- A side line's point at horizontal distance d, for a launch from `from` at
-- `to` turned by `degrees` (shoot_breath's rotation).
local function side_point(from, to, degrees, t)
	local a = degrees * math.pi / 180
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	dx, dz = dx * math.cos(a) - dz * math.sin(a), dx * math.sin(a) + dz * math.cos(a)
	return vec(from.x + dx * t, from.y + dy * t, from.z + dz * t)
end
local function breath_scene(all_homing)
	shots, placed, world = {}, {}, {}
	for i = #objects, 1, -1 do objects[i] = nil end
	for i = #players, 1, -1 do players[i] = nil end
	local target = new_player("target", vec(0, 1, 20), "accord")
	local from = vec(0, 1 + 5, 0) -- dragon feet at y 1, eye height 5
	local to = vec(0, 2, 20)
	-- A bystander on the +15 degree line where it passes 1 node above the
	-- target's height; a vetoed player on the -15 degree line short of it.
	local p_by = side_point(from, to, 15, 1)
	local bystander = new_player("bystander", vec(p_by.x, 1, p_by.z), "accord")
	local p_veto = side_point(from, to, -15, 0.8)
	local outsider = new_player("outsider", vec(p_veto.x, p_veto.y - 0.9, p_veto.z), "accord")
	local p_calm = side_point(from, to, 15, 0.6)
	local peaceful = new_player("peaceful", vec(p_calm.x, p_calm.y - 0.9, p_calm.z), "accord")
	local dragon = shooter(vec(0, 1, 0), target, outsider)
	local real = grug_mobs.stamp_straight_arrow
	if all_homing then grug_mobs.stamp_straight_arrow = grug_mobs.stamp_arrow_damage end
	dragon_part.shoot(dragon, {target = target, actor_name = "target"},
		{eye_height = 5, arrow = "grug_mobs:ice_breath", effect = "rime"})
	grug_mobs.stamp_straight_arrow = real
	fly(3)
	return target, bystander, outsider, peaceful
end
local target, bystander, outsider = breath_scene(true)
check(target.punched == 3, "F1 before: three homing shots, the locked target takes three hits")
local peaceful
target, bystander, outsider, peaceful = breath_scene(false)
local homing, straight = 0, 0
for _, s in ipairs(shots) do
	if s._grug_lock then homing = homing + 1 elseif s._grug_straight then straight = straight + 1 end
end
check(#shots == 3 and homing == 1 and straight == 2, "F2 now: the middle shot homes, the two side shots fly straight")
check(target.punched == 1, "F3 the locked target takes one hit")
check(bystander.punched == 1, "F4 a side shot hits a bystander in its line")
check(outsider.punched == 0 and peaceful.punched == 0,
	"F5 a player the shooter would not attack (its veto, a peaceful player) is passed")
local ground = 0
for _, p in ipairs(placed) do
	if world[key(p)] and world[key(p)].name == "grug_mobs:dragon_rime" and p.y == 1 then
		ground = ground + 1
	end
end
check(ground >= 2, "F6 the homing hit and the side shot that lands leave rime patches (hit_node)")
local all_gone = true
for _, s in ipairs(shots) do all_gone = all_gone and s.object.removed end
check(all_gone, "F7 every shot ended (hit, ground or lifetime)")
-- A side shot never hits the locked target itself, even in its line.
shots, world = {}, {}
for i = #objects, 1, -1 do objects[i] = nil end
for i = #players, 1, -1 do players[i] = nil end
local close = new_player("close", vec(0, 1, 3), "accord")
local d2 = shooter(vec(0, 1, 0), close, nil)
dragon_part.shoot(d2, {target = close, actor_name = "close"},
	{eye_height = 1, arrow = "grug_mobs:ice_breath", effect = "rime"})
fly(3)
check(close.punched == 1, "F8 a target close enough to touch the side lines still takes one hit")

-- The King's volley.
grug_mobs.register_simple_arrow("grug_mobs:arrow_entity", {label = "an arrow",
	texture = "a.png", velocity = 14})
local shoot_volley = load_in(cut(bosses, "local function shoot(self, target, arrow, offset_angle)",
	"\nend\n", "volley") .. "return shoot\n", {}, "volley")
shots, world = {}, {}
for i = #objects, 1, -1 do objects[i] = nil end
for i = #players, 1, -1 do players[i] = nil end
local v_target = new_player("vt", vec(0, 1, 16), "throng")
local v_from, v_to = vec(0, 3.2, 0), vec(0, 2, 16)
local p_side = side_point(v_from, v_to, 0.16 * 180 / math.pi, 1)
local v_by = new_player("vb", vec(p_side.x, 1, p_side.z), "throng")
local elf_king = shooter(vec(0, 1, 0), v_target, nil)
elf_king.damage = 50
for _, angle in ipairs({-0.16, 0, 0.16}) do
	shoot_volley(elf_king, v_target, "grug_mobs:arrow_entity", angle)
end
fly(5)
check(v_target.punched == 1 and v_by.punched == 1,
	"F9 the King's volley: one arrow on the target, a side arrow on a bystander")

-- P: the patches only go into air.
local function place_at(column_node, x)
	world = {}
	if column_node then world[key(vec(x, 1, 0))] = {name = column_node} end
	placed = {}
	local ok = dragon_part.place("rime", vec(x, 1.2, 0), "actor")
	return ok, world[key(vec(x, 1, 0))] and world[key(vec(x, 1, 0))].name or "air",
		world[key(vec(x, 2, 0))] and world[key(vec(x, 2, 0))].name or "air"
end
local ok, low, high = place_at(nil, 0)
check(ok and low == "grug_mobs:dragon_rime", "P1 bare ground: the patch lies in the air above it")
ok, low = place_at("default:grass_1", 1)
check(not ok and low == "default:grass_1", "P2 a plant is never replaced")
ok, low = place_at("default:water_source", 2)
check(not ok and low == "default:water_source", "P3 water is never replaced")
ok, low, high = place_at("default:snow", 3)
check(low == "default:snow" and (not ok or high == "grug_mobs:dragon_rime"),
	"P4 snow stays; a patch may only lie in the air above it")
world = {[key(vec(4, 1, 0))] = {name = "grug_mobs:dragon_rime"}}
check(dragon_part.place("rime", vec(4, 1.2, 0), "actor") and
	world[key(vec(4, 1, 0))].name == "grug_mobs:dragon_rime", "P5 a patch renews a patch")
world = {}
protected = function() return true end
check(not dragon_part.place("rime", vec(5, 1.2, 0), "actor") and
	world[key(vec(5, 1, 0))] == nil, "P6 the terrain guard still refuses (towns, POIs)")
protected = function() return false end
core.set_node = real_set_node
core.add_entity = real_add_entity

-- ---------------------------------------------------------------------------
-- W  The wiring.
-- ---------------------------------------------------------------------------
local wrapper = cut(init, "local old_tag_after_activate = def.after_activate", "\tend\n", "tag wrapper")
check(wrapper:find("if not grug_mobs.live_claim(self) then return end", 1, true) ~= nil and
	wrapper:find("live_claim", 1, true) < wrapper:find("old_tag_after_activate(self", 1, true),
	"W1 the activation claim runs before every other after_activate")
check(init:find("core.registered_entities[name]._grug_authored = true", 1, true) ~= nil,
	"W2 grug_mobs publishes a definition's _grug_authored on the prototype")
local dragon_def = cut(dragons_src, "local function dragon_def(id, opts, callbacks)", "\nend\n", "dragon def")
check(dragon_def:find("_grug_authored = true", 1, true) ~= nil, "W3 the dragons are authored")
local rift = read("mods/ENTITIES/grug_mobs/rift.lua")
check(cut(rift, "grug_mobs.register_mob(\"grug_mobs:rift_boss\"", "\n})\n", "rift def"):find(
	"_grug_authored = true", 1, true) ~= nil, "W4 the rift boss (Isquarre) is authored")
local regions = read("mods/ENTITIES/grug_mobs/spawn_regions.lua")
check(cut(regions, "function SR.leader_tick(now, players, zone_ids)", "\nend\n", "leaders"):find(
	"_grug_authored = true", 1, true) ~= nil, "W5 the leaders are placed as authored")
local rares_src = read("mods/ENTITIES/grug_mobs/rares.lua")
check(cut(rares_src, "local function try_spawn(id, spec)", "\nend\n", "try_spawn"):find(
	"_grug_authored = true", 1, true) ~= nil, "W6 the rares are placed as authored")
local api_now = read("mods/ENTITIES/mobs/api.lua")
local branch = cut(api_now, "-- or are we a mob?", "objs[n] = nil", "mob branch")
check(branch:find("or (self._grug_faction and ent._grug_faction == self._grug_faction)", 1, true) ~= nil,
	"W8 general_attack's mob branch skips a mob of the own faction")
local same = load_in("return function(self, ent) return (self._grug_faction and " ..
	"ent._grug_faction == self._grug_faction) == true end", {}, "faction filter")
check(same({_grug_faction = "throng"}, {_grug_faction = "throng"}) and
	not same({_grug_faction = "throng"}, {}) and not same({}, {_grug_faction = "throng"}),
	"W9 a Throng guard skips the King's raiders, a factionless mob nobody")
check(cut(bosses, "local function spawn_dragon(id, row)", "\nend\n", "spawn_dragon"):find(
	"_grug_live_gen = grug_mobs.liveness.next_generation(key)", 1, true) ~= nil,
	"W7 a dragon's spawn hands in its next generation")

print("R37 MP PORTABLE PASS checks=" .. checks)
