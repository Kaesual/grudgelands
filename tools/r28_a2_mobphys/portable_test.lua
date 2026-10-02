-- Round 28 Lane A2 (mob physics) portable test (LuaJIT).
--
--   luajit tools/r28_a2_mobphys/portable_test.lua [repo]
--
-- Loads the REAL grug_mobs env_damage.lua and separation.lua on a fake
-- engine (a node grid and fake mob objects). Checks:
--   E  ruling 6: environmental shares of hp_max per tick (sun 5, lava 20,
--      fire 10, water 10, suffocation 5 %), elite/rare half, boss and king
--      immune, at least 1 HP, fall damage ceil(hp_max * (d - 6) / 20);
--   K  ruling 7: knockback = 0.25 m x swing interval along attacker -> mob,
--      horizontal; tier gate (normal/critter only, knock_back = false never);
--      the destination test (box free of walkable/unknown/hurting nodes,
--      floor under the feet), and the displacement itself (move_to);
--   S  ruling 5: out of the target's column, sideways drift off an
--      overlapping engaged mob, at most once per second, contact-run hold.
-- Prints "R28 A2 MOBPHYS PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

-- ---------------------------------------------------------------------------
-- fake engine
-- ---------------------------------------------------------------------------
local nodes = {} -- "x,y,z" -> name; absent = air
local param2s = {} -- "x,y,z" -> param2; absent = 0
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local registered_nodes = {
	air = {name = "air", walkable = false},
	stone = {name = "stone"},
	-- the real default:snow boxes and a stairs-mod bottom slab
	snow = {name = "snow", drawtype = "nodebox",
		node_box = {type = "fixed", fixed = {{-0.5, -0.5, -0.5, 0.5, -0.25, 0.5}}},
		collision_box = {type = "fixed",
			fixed = {{-0.5, -0.5, -0.5, 0.5, -6 / 16, 0.5}}}},
	slab = {name = "slab", drawtype = "nodebox", paramtype2 = "facedir",
		node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5}}},
	lava = {name = "lava", walkable = false, damage_per_second = 8},
	grass = {name = "grass", walkable = false},
	ignore = {name = "ignore", walkable = false},
}
local unloaded = {}
local objects = {}

_G.core = {
	registered_nodes = registered_nodes,
	get_node_or_nil = function(pos)
		local k = key(pos.x, pos.y, pos.z)
		if unloaded[k] then return nil end
		return {name = nodes[k] or "air", param2 = param2s[k] or 0}
	end,
	get_objects_inside_radius = function(pos, radius)
		local found = {}
		for _, object in ipairs(objects) do
			local p = object:get_pos()
			local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
			if dx * dx + dy * dy + dz * dz <= radius * radius then
				found[#found + 1] = object
			end
		end
		return found
	end,
}
_G.grug_mobs = {}
-- The real box helpers (Round 30 P2): separation reads collision boxes
-- through mobs/grug_obstacle.lua.
_G.mobs = {grug_obstacle = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")}

local function load(path)
	local chunk = assert(loadfile(repo .. "/" .. path))
	chunk()
end
load("mods/ENTITIES/grug_mobs/env_damage.lua")
load("mods/ENTITIES/grug_mobs/separation.lua")

local function def_at(x, y, z)
	local k = key(x, y, z)
	if unloaded[k] then return nil end
	return registered_nodes[nodes[k] or "air"], param2s[k] or 0
end

local function floor_plate(y, x0, x1, z0, z1)
	for x = x0, x1 do
		for z = z0, z1 do nodes[key(x, y, z)] = "stone" end
	end
end

local MOB_BOX = {-0.4, 0, -0.4, 0.4, 1.8, 0.4} -- feet at the object pos
local PLAYER_BOX = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}

local function new_object(pos, cbox, ent)
	local o = {pos = {x = pos.x, y = pos.y, z = pos.z}, cbox = cbox,
		yaw = 0, moves = 0, ent = ent}
	function o:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function o:get_properties() return {collisionbox = self.cbox, hp_max = 20} end
	function o:get_yaw() return self.yaw end
	function o:get_luaentity() return self.ent end
	function o:is_player() return self.ent == nil end
	function o:move_to(p, continuous)
		self.pos = {x = p.x, y = p.y, z = p.z}
		self.moves = self.moves + 1
		self.continuous = continuous
	end
	objects[#objects + 1] = o
	return o
end

local function new_mob(pos, fields)
	local ent = {_cmi_is_mob = true, state = "attack", temp = {},
		knock_back = true, name = "grug_mobs:wolf"}
	for k, v in pairs(fields or {}) do ent[k] = v end
	ent.object = new_object(pos, fields and fields.cbox or MOB_BOX, ent)
	return ent
end

-- ---------------------------------------------------------------------------
-- E: environmental damage (ruling 6)
-- ---------------------------------------------------------------------------
local share = grug_mobs.env_damage_share
local scale = grug_mobs.env_damage_scale
check(scale("normal", "grug_mobs:zombie") == 1, "E normal full")
check(scale(nil, "grug_mobs:zombie") == 1, "E nil tier full")
check(scale("critter", "grug_mobs:rabbit") == 1, "E critter full")
check(scale("elite", "grug_mobs:zombie") == 0.5, "E elite half")
check(scale("rare", "grug_mobs:zombie") == 0.5, "E rare half")
check(scale("boss", "grug_mobs:ice_dragon") == 0, "E boss immune")
check(scale("elite", "grug_mobs:king_human") == 0, "E king immune")
check(scale("elite", "grug_mobs:royal_guard_human") == 0.5,
	"E royal guard is an ordinary elite")
-- The motivating case: L30 zombie, 764 HP, 6.4 min in the sun before.
check(share(764, 5, 1) == 39, "E L30 zombie sun 39/s")
check(math.ceil(764 / share(764, 5, 1)) == 20, "E L30 zombie dies in 20 s of sun")
check(share(764, 5, 0.5) == 20, "E elite sun half (ceil 19.1)")
check(share(764, 20, 1) == 153, "E lava 20 %")
check(share(1000, 20, 1) == 200, "E exact multiple stays exact")
check(share(764, 10, 1) == 77, "E fire/water 10 %")
check(share(1, 5, 1) == 1, "E at least 1 HP (critter pool)")
check(share(764, 5, 0) == 0, "E immune takes nothing")
check(share(0, 5, 1) == 0, "E empty pool")
local fall = grug_mobs.fall_damage_share
check(fall(764, 4, 1) == 153, "E fall d=10: ceil(764*4/20)")
check(fall(20, 0.5, 1) == 1, "E fall small excess rounds up")
check(fall(764, 4, 0.5) == 77, "E fall elite half")
check(fall(764, 4, 0) == 0, "E fall boss/king immune")
check(fall(764, 0, 1) == 0, "E no excess no damage")
-- self-level wrappers read hp_max, tier and name
local zombie = {hp_max = 764, _grug_tier = "normal", name = "grug_mobs:zombie"}
check(grug_mobs.env_damage(zombie, "sun") == 39, "E env_damage sun via self")
check(grug_mobs.env_damage(zombie, "lava") == 153, "E env_damage lava via self")
check(grug_mobs.env_damage(zombie, "suffocation") == 39, "E suffocation 5 %")
check(grug_mobs.env_damage(zombie, "water") == 77, "E water 10 %")
check(grug_mobs.env_damage(zombie, "fire") == 77, "E fire 10 %")
check(grug_mobs.env_damage(zombie, "nonsense") == 0, "E unknown kind 0")
local king = {hp_max = 5000, _grug_tier = "elite", name = "grug_mobs:king_orc"}
check(grug_mobs.env_damage(king, "lava") == 0, "E king in lava 0")
check(grug_mobs.fall_damage(king, 10) == 0, "E king falls free")
check(grug_mobs.fall_damage(zombie, 4) == 153, "E fall via self")

-- ---------------------------------------------------------------------------
-- K: knockback (ruling 7)
-- ---------------------------------------------------------------------------
check(grug_mobs.KNOCKBACK_PER_SECOND == 0.25, "K constant c = 0.25")
local function kb_len(interval)
	local dx, dz = grug_mobs.knockback_offset({x = 0, y = 0, z = 0},
		{x = 3, y = 5, z = 4}, interval)
	return math.sqrt(dx * dx + dz * dz), dx, dz
end
local len, dx, dz = kb_len(0.7)
check(near(len, 0.175), "K dagger 0.7 s -> 0.175 m")
check(near(dx / len, 0.6) and near(dz / len, 0.8), "K along attacker -> mob")
check(near(kb_len(1.0), 0.25), "K sword 1.0 s -> 0.25 m")
check(near(kb_len(1.4), 0.35), "K battle axe 1.4 s -> 0.35 m")
check(near(kb_len(1.4 / 1.12), 0.3125), "K attack-speed affix shortens it")
check(grug_mobs.knockback_offset({x = 1, y = 0, z = 1}, {x = 1, y = 3, z = 1}, 1)
	== nil, "K same column: no direction, no knockback")
check(grug_mobs.can_be_knocked_back({knock_back = true}), "K default tier")
check(grug_mobs.can_be_knocked_back({knock_back = true, _grug_tier = "critter"}),
	"K critter")
for _, tier in ipairs({"elite", "rare", "boss"}) do
	check(not grug_mobs.can_be_knocked_back({knock_back = true, _grug_tier = tier}),
		"K no knockback for " .. tier)
end
check(not grug_mobs.can_be_knocked_back({knock_back = false}),
	"K knock_back = false (Kraken) never")

-- destination test on a stone floor at y = 0 (feet stand at y = 0.5)
floor_plate(0, -5, 10, -5, 10)
local fits = grug_mobs.box_fits_at
check(fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K open floor fits")
check(fits({x = 0, y = 1.5, z = 0}, {-0.4, -1, -0.4, 0.4, 0.8, 0.4}, def_at),
	"K offset box (cbox[2] < 0) fits")
nodes[key(2, 1, 0)] = "stone" -- a wall block at x = 2
check(not fits({x = 1.5, y = 0.5, z = 0}, MOB_BOX, def_at),
	"K box reaching into the wall does not fit")
check(fits({x = 1.0, y = 0.5, z = 0}, MOB_BOX, def_at),
	"K box short of the wall fits")
check(fits({x = 1.12, y = 0.5, z = 0}, MOB_BOX, def_at),
	"K box touching the wall within tolerance fits")
nodes[key(2, 1, 0)] = nil
nodes[key(0, 2, 0)] = "stone" -- a ceiling block at head height
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K low ceiling blocks")
nodes[key(0, 2, 0)] = nil
nodes[key(0, 1, 0)] = "grass"
check(fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K plants do not block")
nodes[key(0, 1, 0)] = "lava"
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K lava blocks")
nodes[key(0, 1, 0)] = "slab"
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at),
	"K a slab above the feet of a mob on stone blocks")
nodes[key(0, 1, 0)] = nil
nodes[key(0, 0, 0)] = nil -- a hole in the floor under the destination
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K no floor, no fit")
nodes[key(0, 0, 0)] = "lava"
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K lava is no floor")
nodes[key(0, 0, 0)] = "stone"
unloaded[key(0, 1, 0)] = true
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K unloaded blocks")
unloaded[key(0, 1, 0)] = nil
nodes[key(0, 1, 0)] = "ignore"
check(not fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K ignore blocks")
nodes[key(0, 1, 0)] = nil
check(fits({x = 0, y = 0.5, z = 0}, MOB_BOX, def_at), "K grid restored")
-- ledge: floor ends at x = 10 (the plate spans x <= 10)
check(not fits({x = 10.6, y = 0.5, z = 0}, MOB_BOX, def_at),
	"K never over a ledge")

-- snow dust (collision top -6/16) on the stone floor at y = 0: a mob on the
-- snow has its feet at y = 1 - 0.375 = 0.625
local ON_SNOW = 1 - 6 / 16
for x = 3, 6 do nodes[key(x, 1, 0)] = "snow" end
check(fits({x = 4, y = ON_SNOW, z = 0}, MOB_BOX, def_at),
	"K snow: on snow to snow fits")
check(fits({x = 4.4, y = ON_SNOW, z = 0}, MOB_BOX, def_at),
	"K snow: box spanning two snow nodes fits")
check(fits({x = 7.2, y = ON_SNOW, z = 0}, MOB_BOX, def_at),
	"K snow: off the snow onto bare stone (0.125 lower) fits")
check(not fits({x = 3, y = 0.5, z = 0}, MOB_BOX, def_at),
	"K snow: a snow layer above the feet of a mob on stone blocks")
nodes[key(4, 2, 0)] = "stone"
check(not fits({x = 4, y = ON_SNOW, z = 0}, MOB_BOX, def_at),
	"K snow: a full block in the box still blocks")
nodes[key(4, 2, 0)] = nil
nodes[key(4, 0, 0)] = nil
check(fits({x = 4, y = ON_SNOW, z = 0}, MOB_BOX, def_at),
	"K snow: the snow node itself is support")
nodes[key(4, 0, 0)] = "stone"
for x = 3, 6 do nodes[key(x, 1, 0)] = nil end

-- bottom slabs at y = 1 (top at y = 1.0): a mob on a slab has feet at 1.0
nodes[key(3, 1, 2)], nodes[key(4, 1, 2)] = "slab", "slab"
check(fits({x = 3.5, y = 1.0, z = 2}, MOB_BOX, def_at),
	"K slab: on slab to slab fits")
param2s[key(4, 1, 2)] = 2 -- turned about y: still a bottom slab
check(fits({x = 4, y = 1.0, z = 2}, MOB_BOX, def_at),
	"K slab: a y-rotated slab is still low")
param2s[key(4, 1, 2)] = 20 -- upside down: the slab fills the top half
check(not fits({x = 4, y = 1.0, z = 2}, MOB_BOX, def_at),
	"K slab: an upside-down slab blocks")
param2s[key(4, 1, 2)] = nil
nodes[key(4, 1, 2)] = "stone"
check(not fits({x = 3.7, y = 1.0, z = 2}, MOB_BOX, def_at),
	"K slab: never half into the full block beside it")
nodes[key(4, 1, 2)] = nil
check(fits({x = 4.3, y = 1.0, z = 2}, MOB_BOX, def_at),
	"K slab: off the slab onto the floor half a node lower fits")
nodes[key(4, 0, 2)] = nil
check(not fits({x = 4.3, y = 1.0, z = 2}, MOB_BOX, def_at),
	"K slab: but not over a hole")
nodes[key(4, 0, 2)] = "stone"
nodes[key(3, 1, 2)] = nil

-- melee_knockback end to end on fake objects
objects = {}
local player = new_object({x = 0, y = 0.5, z = 0}, PLAYER_BOX)
local wolf = new_mob({x = 1.8, y = 0.5, z = 0})
check(grug_mobs.melee_knockback(wolf, player, 1.0), "K wolf pushed")
check(near(wolf.object.pos.x, 2.05) and near(wolf.object.pos.z, 0)
	and near(wolf.object.pos.y, 0.5), "K 0.25 m back, horizontal only")
check(wolf.object.continuous == true, "K interpolated move_to")
nodes[key(3, 1, 0)] = "stone"
check(not grug_mobs.melee_knockback(wolf, player, 1.4), "K wall behind: none")
check(near(wolf.object.pos.x, 2.05), "K wall behind: position unchanged")
nodes[key(3, 1, 0)] = nil
local elite = new_mob({x = -1.8, y = 0.5, z = 0}, {_grug_tier = "elite"})
check(not grug_mobs.melee_knockback(elite, player, 1.0)
	and elite.object.moves == 0, "K elite stays")

-- ---------------------------------------------------------------------------
-- S: separation (ruling 5)
-- ---------------------------------------------------------------------------
-- column push
local px, pz = grug_mobs.column_push({x = 0.3, y = 0, z = 0},
	{x = 0, y = 0, z = 0}, 0.7, 0, -1)
check(near(px, 0.4) and near(pz, 0), "S column: out to the hold distance")
px, pz = grug_mobs.column_push({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0},
	0.7, 0, -1)
check(near(px, 0) and near(pz, -0.5), "S column: same spot backs off, capped")
check(grug_mobs.column_push({x = 0.8, y = 0, z = 0}, {x = 0, y = 0, z = 0}, 0.7)
	== nil, "S outside the column: nothing")
-- sideways push: own target straight ahead along +z, neighbour to the left
px, pz = grug_mobs.sideways_push({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 2},
	{x = -0.3, y = 0, z = 0}, 0.5, 1)
check(px > 0 and near(pz, 0), "S sideways: away from the neighbour")
check(near(px, 0.3), "S sideways: half the overlap + eps")
px, pz = grug_mobs.sideways_push({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 2},
	{x = 0, y = 0, z = -0.2}, 0.6, -1)
local tie_x = px
check(near(math.abs(px), 0.35) and near(pz, 0),
	"S sideways: tie picks a side, still perpendicular")
px = grug_mobs.sideways_push({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 2},
	{x = 0, y = 0, z = -0.2}, 0.6, 1)
check(near(px, -tie_x), "S sideways: the other tie picks the other side")
px = grug_mobs.sideways_push({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 2},
	{x = -0.3, y = 0, z = 0}, 5, 1)
check(near(px, 0.5), "S sideways: capped at 0.5 m")

-- separation_step on fake objects
objects = {}
player = new_object({x = 0, y = 0.5, z = 0}, PLAYER_BOX)
local a = new_mob({x = 0.2, y = 0.5, z = 0}, {attack = player})
grug_mobs.separation_step(a, 0.09, a.object:get_pos(), player:get_pos())
check(near(a.object.pos.x, 0.7) and a.object.moves == 1,
	"S first tick: pushed out of the column to radius sum 0.7")
check(near(a.temp.grug_separation_hold, 0.7), "S hold cached")
grug_mobs.separation_step(a, 0.09, a.object:get_pos(), player:get_pos())
check(a.object.moves == 1, "S rate limit: nothing before 1 s")
a.object.pos.x = 0.1
for _ = 1, 10 do
	grug_mobs.separation_step(a, 0.09, a.object:get_pos(), player:get_pos())
end
check(a.object.moves == 1, "S rate limit: 0.9 s still nothing")
grug_mobs.separation_step(a, 0.09, a.object:get_pos(), player:get_pos())
check(a.object.moves == 2 and near(a.object.pos.x, 0.6),
	"S after 1 s: next push (capped 0.5)")
-- contact-run hold: radii 0.7 + margin 0.5
check(grug_mobs.holds_column(a, {x = 1.1, y = 0.5, z = 0}, {x = 0, y = 0.5, z = 0}),
	"S hold: inside radii + margin stops the run")
check(not grug_mobs.holds_column(a, {x = 1.3, y = 0.5, z = 0},
	{x = 0, y = 0.5, z = 0}), "S hold: beyond it the run continues")
check(not grug_mobs.holds_column({temp = {}}, {x = 0, y = 0, z = 0},
	{x = 0, y = 0, z = 0}), "S hold: no cache yet, run unchanged")

-- two engaged mobs on one spot at contact distance drift apart sideways
objects = {}
player = new_object({x = 0, y = 0.5, z = 0}, PLAYER_BOX)
local m1 = new_mob({x = 0, y = 0.5, z = 1.8}, {attack = player})
local m2 = new_mob({x = 0.1, y = 0.5, z = 1.8}, {attack = player})
grug_mobs.separation_step(m1, 0.09, m1.object:get_pos(), player:get_pos())
grug_mobs.separation_step(m2, 0.09, m2.object:get_pos(), player:get_pos())
check(m1.object.moves == 1 and m2.object.moves == 1, "S both overlapping mobs move")
check(m1.object.pos.x < 0 and m2.object.pos.x > 0.1, "S they move apart")
check(near(m1.object.pos.z, 1.8, 0.05) and near(m2.object.pos.z, 1.8, 0.05),
	"S sideways: (nearly) perpendicular to the line to the target")
local gap = m2.object.pos.x - m1.object.pos.x
check(gap > 0.6, "S gap grew from 0.1 m")
-- a neighbour not engaged is left alone
objects = {}
player = new_object({x = 0, y = 0.5, z = 0}, PLAYER_BOX)
local busy = new_mob({x = 0, y = 0.5, z = 1.8}, {attack = player})
new_mob({x = 0.1, y = 0.5, z = 1.8}, {state = "stand"})
grug_mobs.separation_step(busy, 0.09, busy.object:get_pos(), player:get_pos())
check(busy.object.moves == 0, "S idle neighbour: no drift")
-- a neighbour on a different level does not overlap
objects = {}
player = new_object({x = 0, y = 0.5, z = 0}, PLAYER_BOX)
local low = new_mob({x = 0, y = 0.5, z = 1.8}, {attack = player})
new_mob({x = 0.1, y = 2.5, z = 1.8}, {attack = player})
grug_mobs.separation_step(low, 0.09, low.object:get_pos(), player:get_pos())
check(low.object.moves == 0, "S vertically apart: no drift")
-- a blocked side means no move at all
objects = {}
player = new_object({x = 0, y = 0.5, z = 0}, PLAYER_BOX)
nodes[key(-1, 1, 2)] = "stone"
local wall_mob = new_mob({x = -0.2, y = 0.5, z = 1.8}, {attack = player})
new_mob({x = 0.1, y = 0.5, z = 1.8}, {attack = player})
grug_mobs.separation_step(wall_mob, 0.09, wall_mob.object:get_pos(),
	player:get_pos())
check(wall_mob.object.moves == 0, "S wall on the drift side: stays")
nodes[key(-1, 1, 2)] = nil

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R28 A2 MOBPHYS PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print("R28 A2 MOBPHYS PORTABLE PASS checks=" .. checks)
