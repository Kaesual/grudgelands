-- Round 28 Lane A5 portable test: respawn without launch (ruling 16), death
-- messages that name the shooter (ruling 17) and stations that drop their
-- contents when dug (ruling 18). Loads the REAL game files under a minimal
-- `core` stub: grug_core/movement.lua, grug_core/death_messages.lua,
-- grug_home/travel.lua, grug_jobs/workspaces.lua (+ automatic.lua).
--
-- Usage (repo root): luajit tools/r28_a5_player/portable_test.lua [ROOT]
-- Prints "R28 A5 PORTABLE PASS checks=<n>" or the failures.

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
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return setmetatable(out, getmetatable(value))
end
table.copy = deep_copy

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local vector = {}
rawset(_G, "vector", vector)
local vmeta = {__index = vector}
function vector.new(x, y, z)
	if type(x) == "table" then return setmetatable({x = x.x, y = x.y, z = x.z}, vmeta) end
	return setmetatable({x = x or 0, y = y or 0, z = z or 0}, vmeta)
end
function vector.copy(v) return vector.new(v) end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
function vector.round(v)
	return vector.new(math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
end
function vector.equals(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end

-- ItemStack: "name count" strings, enough for drops and inventories.
local stack_meta = {}
stack_meta.__index = stack_meta
local function ItemStack(value)
	if getmetatable(value) == stack_meta then return setmetatable({name = value.name, count = value.count}, stack_meta) end
	local name, count = "", 0
	if type(value) == "table" then
		name, count = value.name or "", value.count or 1
	elseif type(value) == "string" and value ~= "" then
		local n, c = value:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	end
	return setmetatable({name = name, count = count}, stack_meta)
end
function stack_meta:is_empty() return self.name == "" or self.count <= 0 end
function stack_meta:get_count() return self.count end
function stack_meta:get_name() return self.name end
function stack_meta:to_string()
	if self:is_empty() then return "" end
	return self.count == 1 and self.name or (self.name .. " " .. self.count)
end
function stack_meta:to_table() return {name = self.name, count = self.count} end

local function new_inventory()
	local inv = {lists = {}}
	function inv:get_size(list) return self.lists[list] and #self.lists[list] or 0 end
	function inv:set_size(list, size)
		self.lists[list] = self.lists[list] or {}
		for i = 1, size do self.lists[list][i] = self.lists[list][i] or ItemStack("") end
	end
	function inv:get_stack(list, i) return ItemStack((self.lists[list] or {})[i] or "") end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:get_list(list) return self.lists[list] end
	function inv:get_lists() return self.lists end
	function inv:is_empty(list)
		for _, s in ipairs(self.lists[list] or {}) do if not s:is_empty() then return false end end
		return true
	end
	return inv
end

local serial = {}
local afters, now = {}, 0
local emerges = {}
local node_metas = {}
local world = {}       -- pos key -> node name (overrides the terrain rule)
local protected = {}   -- pos key -> true
local players = {}
local chat = {}
local callbacks = {join = {}, leave = {}, die = {}, mods_loaded = {}}
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end

local core = {
	registered_nodes = {
		air = {walkable = false, drawtype = "airlike"},
		["default:stone"] = {walkable = true, drawtype = "normal"},
	},
	registered_entities = {},
	EMERGE_CANCELLED = 0, EMERGE_ERRORED = 1, EMERGE_FROM_MEMORY = 2,
	EMERGE_FROM_DISK = 3, EMERGE_GENERATED = 4,
	serialize = function(value) serial[#serial + 1] = deep_copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and deep_copy(serial[index]) or nil
	end,
	after = function(delay, fn, ...)
		afters[#afters + 1] = {at = now + delay, fn = fn, args = {...}}
	end,
	emerge_area = function(p1, p2, cb) emerges[#emerges + 1] = {p1 = p1, p2 = p2, cb = cb} end,
	load_area = function() end,
	get_node_or_nil = function(pos)
		local name = world[key(vector.round(pos))]
		if name then return {name = name} end
		-- Terrain rule: solid ground up to y = 9, air above.
		return {name = math.floor(pos.y + 0.5) <= 9 and "default:stone" or "air"}
	end,
	get_player_by_name = function(name) return players[name] end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name = name, text = text} end,
	chat_send_all = function() end,
	is_player = function(p)
		local t = type(p)
		return (t == "userdata" or t == "table") and type(p.is_player) == "function" and p:is_player()
	end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_mods_loaded = function(fn) callbacks.mods_loaded[#callbacks.mods_loaded + 1] = fn end,
	register_globalstep = function() end,
	register_on_player_receive_fields = function() end,
	register_lbm = function() end,
	get_modpath = function(mod)
		local paths = {grug_jobs = "mods/PLAYER/grug_jobs"}
		return ROOT .. "/" .. assert(paths[mod], mod)
	end,
	get_meta = function(pos)
		local k = key(pos)
		if not node_metas[k] then
			local meta = {fields = {}, inv = new_inventory()}
			function meta:get_string(name) return self.fields[name] or "" end
			function meta:set_string(name, value) self.fields[name] = value end
			function meta:get_int(name) return tonumber(self.fields[name]) or 0 end
			function meta:set_int(name, value) self.fields[name] = tostring(value) end
			function meta:get_inventory() return self.inv end
			function meta:mark_as_private() end
			function meta:to_table() return {fields = deep_copy(self.fields)} end
			node_metas[k] = meta
		end
		return node_metas[k]
	end,
	is_protected = function(pos) return protected[key(pos)] == true end,
	override_item = function(name, fields)
		local def = assert(core.registered_nodes[name], name)
		for k, v in pairs(fields) do def[k] = v end
	end,
	remove_node = function(pos) world[key(pos)] = "air"; node_metas[key(pos)] = nil end,
	get_gametime = function() return 0 end,
	get_us_time = function() return now * 1e6 end,
}
core.get_node = core.get_node_or_nil
rawset(_G, "core", core)
rawset(_G, "ItemStack", ItemStack)

local function run_afters(until_time)
	now = math.max(now, until_time or now)
	local ran = true
	while ran do
		ran = false
		for i, entry in ipairs(afters) do
			if entry.at <= now then
				table.remove(afters, i)
				entry.fn(unpack(entry.args))
				ran = true
				break
			end
		end
	end
end

------------------------------------------------------------------------------
-- Game surface the real files call.
------------------------------------------------------------------------------
local grug_core = {mono_time = function() return now end}
rawset(_G, "grug_core", grug_core)
local dismounts, invalidations = 0, 0
grug_core.invalidate_combat_identity = function() invalidations = invalidations + 1 end
grug_core.in_combat = function() return false end
local START = vector.new(100, 10, 100)
grug_core.start_position = function() return vector.new(START) end
grug_core.get_player_race = function() return "human" end
rawset(_G, "grug_mounts", {dismount = function() dismounts = dismounts + 1 end})
rawset(_G, "grug_factions", {get_faction = function() return "accord" end})

local HOMES = {
	dawnmere = {id = "dawnmere", label = "Dawnmere", pos = vector.new(0, 10, 0)},
	highcourt = {id = "highcourt", label = "Highcourt", pos = vector.new(500, 10, 500)},
}
for _, row in pairs(HOMES) do row.arrival = vector.offset(row.pos, 1, -0.49, 0) end
local grug_home = {}
rawset(_G, "grug_home", grug_home)
-- Bound innkeeper, else the starting-town innkeeper (dawnmere).
function grug_home.innkeeper(player)
	local row = HOMES[player:get_meta():get_string("grug_home:id")] or HOMES.dawnmere
	return deep_copy(row)
end
grug_home.get = grug_home.innkeeper

dofile(ROOT .. "/mods/CORE/grug_core/movement.lua")
dofile(ROOT .. "/mods/CORE/grug_core/death_messages.lua")
dofile(ROOT .. "/mods/PLAYER/grug_home/travel.lua")

-- A player stand-in. get_velocity() reports the STALE server-side speed of a
-- lethal fall; any add_velocity call is recorded as a launch.
local function new_player(name)
	local p = {name = name, pos = vector.new(30, 40, 30), hp = 20, log = {},
		physics = {speed = 1, jump = 1, gravity = 1}, fields = {}}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return vector.new(self.pos) end
	function p:set_pos(v)
		self.log[#self.log + 1] = {kind = "set_pos", pos = vector.new(v)}
		self.pos = vector.new(v)
	end
	function p:get_velocity() return vector.new(0, -38, 0) end
	function p:add_velocity(v) self.log[#self.log + 1] = {kind = "add_velocity", v = v} end
	function p:get_hp() return self.hp end
	function p:get_physics_override() return deep_copy(self.physics) end
	function p:set_physics_override(o)
		for k, v in pairs(o) do self.physics[k] = v end
		self.log[#self.log + 1] = {kind = "physics", gravity = o.gravity, speed_walk = o.speed_walk}
	end
	local meta = {}
	function meta.get_string(_, k) return p.fields[k] or "" end
	function meta.set_string(_, k, v) p.fields[k] = v end
	function p:get_meta() return meta end
	players[name] = p
	return p
end
local function count(p, kind)
	local n = 0
	for _, entry in ipairs(p.log) do if entry.kind == kind then n = n + 1 end end
	return n
end
local function first(p, kind, pred)
	for i, entry in ipairs(p.log) do
		if entry.kind == kind and (not pred or pred(entry)) then return i, entry end
	end
end
local function finish_emerge(action)
	local entry = table.remove(emerges, 1)
	entry.cb(nil, action or core.EMERGE_GENERATED, 0)
	run_afters()
end

------------------------------------------------------------------------------
-- Ruling 16: respawn is one teleport, held until emerged, no launch.
------------------------------------------------------------------------------
do
	local p = new_player("faller")
	eq(grug_home.respawn(p), true, "respawn handled by grug_home")
	eq(count(p, "set_pos"), 1, "respawn: exactly one teleport before emerge")
	local _, tp = first(p, "set_pos")
	check(tp and vector.distance(tp.pos, HOMES.dawnmere.arrival) < 1e-9,
		"unbound player respawns at the starting-town innkeeper arrival")
	local hold_index = first(p, "physics", function(e) return e.gravity == 0 end)
	check(hold_index ~= nil and hold_index < (first(p, "set_pos")),
		"hold (gravity 0) is written before the teleport")
	eq(grug_core.is_movement_held(p, "grug_home:respawn"), true, "held while the area emerges")
	eq(p.physics.gravity, 0, "no gravity while held")
	eq(p.physics.speed_walk, 0, "no movement while held")
	eq(#emerges, 1, "one emerge for the home area")
	-- Another system's slow lands during the hold and must survive release.
	grug_core.set_move_modifier(p, "probe_slow", {speed = -0.4}, 60)
	eq(p.physics.gravity, 0, "a modifier during the hold keeps the hold")
	finish_emerge()
	eq(grug_core.is_movement_held(p, "grug_home:respawn"), false, "released after the emerge")
	eq(p.physics.gravity, 1, "gravity handed back")
	check(math.abs((p.physics.speed or 0) - 0.6) < 1e-9, "the slow survives the release (speed 0.6)")
	eq(count(p, "set_pos"), 1, "respawn: still one teleport after the emerge")
	eq(count(p, "add_velocity"), 0, "respawn adds no velocity")
	eq(p.fields["grug_home:ready_at"], nil, "respawn charges no travel cooldown")
	eq(dismounts, 1, "the teleport dismounts")
end

do
	local p = new_player("bound")
	p.fields["grug_home:id"] = "highcourt"
	grug_home.respawn(p)
	eq(count(p, "set_pos"), 1, "bound: one teleport")
	local _, tp = first(p, "set_pos")
	check(tp and vector.distance(tp.pos, HOMES.highcourt.arrival) < 1e-9,
		"bound player goes straight to the bound innkeeper")
	check(vector.distance(emerges[1].p1, vector.offset(HOMES.highcourt.pos, -16, -8, -16)) < 1e-9,
		"the bound home's area is emerged")
	finish_emerge()
	eq(count(p, "set_pos"), 1, "bound: no start-town hop")
	check(not first(p, "set_pos", function(e) return vector.distance(e.pos, START) < 3 end),
		"bound: never placed at the start position")
	eq(count(p, "add_velocity"), 0, "bound: no velocity added")
end

do
	local p = new_player("errored")
	grug_home.respawn(p)
	finish_emerge(core.EMERGE_ERRORED)
	eq(grug_core.is_movement_held(p), false, "failed emerge: released")
	eq(count(p, "set_pos"), 2, "failed emerge: falls back once to the start pocket")
	local last
	for i = #p.log, 1, -1 do if p.log[i].kind == "set_pos" then last = p.log[i] break end end
	check(last and vector.distance(last.pos, vector.offset(START, 1, -0.49, 0)) < 1e-9,
		"failed emerge: start pocket arrival")
	check(chat[#chat] and chat[#chat].name == "errored" and chat[#chat].text:find("starting town", 1, true) ~= nil,
		"failed emerge: message")
	eq(count(p, "add_velocity"), 0, "failed emerge: no velocity added")
end

do
	local p = new_player("unsafe")
	world[key(vector.new(1, 10, 0))] = "default:stone" -- the arrival's headroom is blocked
	grug_home.respawn(p)
	finish_emerge()
	world[key(vector.new(1, 10, 0))] = nil
	eq(grug_core.is_movement_held(p), false, "unsafe arrival: released")
	eq(count(p, "set_pos"), 2, "unsafe arrival: start pocket fallback")
end

do
	local p = new_player("stalled")
	grug_home.respawn(p)
	run_afters(now + 29)
	eq(grug_core.is_movement_held(p), true, "stalled emerge: held before the timeout")
	run_afters(now + 2)
	eq(grug_core.is_movement_held(p), false, "stalled emerge: released at the timeout")
	eq(count(p, "set_pos"), 2, "stalled emerge: start pocket fallback")
	table.remove(emerges, 1)
end

do
	local p = new_player("rebinds")
	grug_home.respawn(p)
	grug_home.cancel(p) -- e.g. "Set home here" at the innkeeper while held
	eq(grug_core.is_movement_held(p), false, "cancel releases the respawn hold")
	finish_emerge()
	eq(count(p, "set_pos"), 1, "canceled respawn: no further teleport")
end

do
	-- Death during the hold: the aggregator's death reset and grug_home.cancel.
	local p = new_player("dies_again")
	grug_home.respawn(p)
	p.hp = 0
	for _, fn in ipairs(callbacks.die) do fn(p, {type = "fall"}) end
	eq(grug_core.is_movement_held(p), false, "death drops the hold")
	finish_emerge()
	eq(count(p, "set_pos"), 1, "dead player is not moved again")
end

do
	-- Return travel: one teleport, no hold, no velocity, cooldown charged.
	local p = new_player("traveller")
	p.fields["grug_home:id"] = "highcourt"
	eq(grug_home.return_home(p), true, "return home accepted")
	eq(count(p, "set_pos"), 0, "travel waits for the emerge")
	eq(grug_core.is_movement_held(p), false, "travel holds nothing")
	finish_emerge()
	eq(count(p, "set_pos"), 1, "travel: one teleport")
	local _, tp = first(p, "set_pos")
	check(tp and vector.distance(tp.pos, HOMES.highcourt.arrival) < 1e-9, "travel arrives at the home")
	eq(count(p, "add_velocity"), 0, "travel adds no velocity")
	check(p.fields["grug_home:ready_at"] ~= nil, "travel charges the cooldown")
end

------------------------------------------------------------------------------
-- Ruling 17: death messages name the shooter, never a technical name.
------------------------------------------------------------------------------
local function new_object(entity, alive)
	local o = {entity = entity, alive = alive ~= false}
	function o:is_player() return false end
	function o:get_luaentity() return self.alive and self.entity or nil end
	if entity then entity.object = o end
	return o
end
local function new_victim_player(name)
	local o = {}
	function o:is_player() return true end
	function o:get_player_name() return name end
	return o
end
local function message(object)
	return grug_core.death_message("victim", {type = "punch", object = object})
end
local function projectile(name, label, source)
	return new_object({name = name, _grug_projectile_label = label, _grug_source = source})
end
local archer = new_object({name = "grug_mobs:skeleton_archer", description = "Skeleton Archer"})
local witch = new_object({name = "grug_mobs:bog_witch", description = "Bog Witch"})
local dragon = new_object({name = "grug_mobs:ice_dragon", description = "Frost Wyrm", _grug_boss_id = "dragon:x"})
local gone = new_object({name = "grug_mobs:skeleton_archer", description = "Skeleton Archer"}, false)
local cases = {
	{"mob melee", new_object({name = "grug_mobs:boar", description = "Boar"}), "mob", "Boar"},
	{"arrow, archer alive", projectile("grug_mobs:arrow_entity", "an arrow", archer), "mob", "Skeleton Archer"},
	{"arrow, archer gone", projectile("grug_mobs:arrow_entity", "an arrow", gone), "mob", "an arrow"},
	{"fireball, shooter gone", projectile("grug_mobs:dungeon_fireball", "a fireball", gone), "mob", "a fireball"},
	{"hex bottle, witch alive", projectile("grug_mobs:hex_bottle", "a hex bottle", witch), "mob", "Bog Witch"},
	{"hex bottle, witch gone", projectile("grug_mobs:hex_bottle", "a hex bottle", gone), "mob", "a hex bottle"},
	{"dragon breath, dragon alive", projectile("grug_mobs:ice_breath", "frost breath", dragon), "mob", "Frost Wyrm"},
	{"dragon breath, dragon gone", projectile("grug_mobs:ice_breath", "frost breath", gone), "mob", "frost breath"},
	{"unlabelled projectile, shooter gone", projectile("grug_mobs:odd_entity", nil, gone), "mob", "a hostile creature"},
	{"mob without description", new_object({name = "grug_mobs:thing", description = "grug_mobs:thing"}), "mob", "a hostile creature"},
	{"projectile of a player", projectile("grug_mobs:arrow_entity", "an arrow", new_victim_player("Archer")), "player", "Archer"},
	{"player", new_victim_player("Rival"), "player", "Rival"},
}
for _, case in ipairs(cases) do
	local category, line = message(case[2])
	eq(category, case[3], case[1] .. ": category")
	check(line:find(case[4], 1, true) ~= nil, case[1] .. ": names " .. case[4] .. " (" .. line .. ")")
	check(not line:find("grug_mobs:", 1, true) and not line:find("%w+:%w+_"), case[1] .. ": no technical name (" .. line .. ")")
end
-- Boss-encounter counting resolves the same source.
check(grug_core.damage_source(projectile("grug_mobs:ice_breath", "frost breath", dragon)) == dragon,
	"damage_source: breath resolves to the live dragon")
eq(grug_core.damage_source(projectile("grug_mobs:ice_breath", "frost breath", gone)), nil,
	"damage_source: breath of a gone dragon resolves to nothing")
check(grug_core.damage_source(archer) == archer, "damage_source: a mob is its own source")

------------------------------------------------------------------------------
-- Ruling 18: stations can be dug whenever protection allows and drop
-- everything, every player's saved workspace record included.
------------------------------------------------------------------------------
rawset(_G, "default", {get_inventory_drops = function(pos, list, drops)
	local inv = core.get_meta(pos):get_inventory()
	for i = 1, inv:get_size(list) do
		local stack = inv:get_stack(list, i)
		if stack:get_count() > 0 then drops[#drops + 1] = stack:to_table() end
	end
end})
local public = {}
rawset(_G, "grug_jobs", {is_public_station = function(_, pos) return public[key(pos)] == true end})
grug_core.interaction_protected = function() return false end
-- The vendored furnace's empty-only can_dig, which the workspace must replace.
core.registered_nodes["default:furnace"] = {description = "Furnace",
	can_dig = function(pos)
		local inv = core.get_meta(pos):get_inventory()
		return inv:is_empty("fuel") and inv:is_empty("dst") and inv:is_empty("src")
	end}
core.registered_nodes["grug_jobs:forge"] = {description = "Forge", _grug_station = "forge"}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/workspaces.lua")
for _, fn in ipairs(callbacks.mods_loaded) do fn() end

local digger = new_player("digger")
digger.pos = vector.new(0, 20, 0)
local PREFIX = "grug_jobs:workspace:"
local function station_at(pos, name)
	world[key(pos)] = name
	node_metas[key(pos)] = nil
	local def = core.registered_nodes[name]
	def.on_construct(pos)
	return def, core.get_meta(pos)
end
local function as_strings(drops)
	local out = {}
	for _, item in ipairs(drops) do
		local s = ItemStack(item)
		out[s:get_name()] = (out[s:get_name()] or 0) + s:get_count()
	end
	return out
end

do
	local pos = vector.new(0, 20, 2)
	local def, meta = station_at(pos, "grug_jobs:forge")
	meta:get_inventory():set_stack("craft", 1, ItemStack("default:steel_ingot 3"))
	meta:set_string(PREFIX .. "alice", core.serialize({lists = {output = {"grug_gear:sword 1"}}}))
	meta:set_string(PREFIX .. "bob", core.serialize({lists = {craft = {"default:coal_lump 2", ""}}}))
	eq(def.can_dig(pos, digger), true, "a full profession station with others' records can be dug")
	local drops = {ItemStack("grug_jobs:forge")}
	def.preserve_metadata(pos, {name = "grug_jobs:forge"}, meta:to_table().fields, drops)
	local got = as_strings(drops)
	eq(got["grug_jobs:forge"], 1, "dig drops the station")
	eq(got["default:steel_ingot"], 3, "dig drops the node list")
	eq(got["grug_gear:sword"], 1, "dig drops alice's saved record")
	eq(got["default:coal_lump"], 2, "dig drops bob's saved record")
	protected[key(pos)] = true
	eq(def.can_dig(pos, digger), false, "protection still refuses the dig")
	protected[key(pos)] = nil
	public[key(pos)] = true
	eq(def.can_dig(pos, digger), false, "an authored public station stays undiggable")
	local blast = def.on_blast(pos)
	eq(#blast, 0, "an authored public station is blast-immune")
	public[key(pos)] = nil
	local far = new_player("far")
	far.pos = vector.new(0, 20, 30)
	eq(def.can_dig(pos, far), false, "out of reach refuses the dig")
	local blasted = as_strings(def.on_blast(pos))
	eq(blasted["grug_jobs:forge"], 1, "blast drops the station")
	eq(blasted["default:steel_ingot"], 3, "blast drops the node list")
	eq(blasted["grug_gear:sword"], 1, "blast drops saved records")
end

do
	local pos = vector.new(0, 20, 4)
	local def, meta = station_at(pos, "default:furnace")
	local inv = meta:get_inventory()
	inv:set_stack("src", 1, ItemStack("default:iron_lump 4"))
	inv:set_stack("fuel", 1, ItemStack("default:coal_lump 5"))
	inv:set_stack("dst", 2, ItemStack("default:steel_ingot 1"))
	eq(def._grug_station, "furnace", "default:furnace is installed as a station")
	eq(def.can_dig(pos, digger), true, "the vendored empty-only can_dig is overridden")
	local drops = {ItemStack("default:furnace")}
	def.preserve_metadata(pos, {name = "default:furnace"}, meta:to_table().fields, drops)
	local got = as_strings(drops)
	eq(got["default:iron_lump"], 4, "furnace dig drops src")
	eq(got["default:coal_lump"], 5, "furnace dig drops fuel")
	eq(got["default:steel_ingot"], 1, "furnace dig drops dst")
end

if failures == 0 then
	print(("R28 A5 PORTABLE PASS checks=%d"):format(checks))
else
	error(("R28 A5 PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
