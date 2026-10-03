-- Round 31 Lane DA2 portable test (LuaJIT): the dragon arenas
-- (round31-plan.md §6 item 11).
--
--   luajit tools/r31_da2/portable_test.lua [REPO]
--
-- A. The layout (grug_mapgen/wp40/arena_layout.lua, the real file) on both
--    arenas of the real source map: the radius is the mapgen profile's and
--    grug_mobs' (dragon_arena.lua) and lies inside the protected core square;
--    every hazard lies inside radius - 4, at least 9 from the spawn and 4.6
--    from every perch (the dragon's half width plus a margin); no 3 x 3 block
--    is all ember (a fissure is never wide enough for the dragon); a terrace
--    is level 1 or 2; the theme decides the hazards; the rim stones stand
--    only on the radius, sparse.
-- B. The rules (grug_mobs/dragon_arena.lua): inside at any height of the
--    band, never beyond the radius; the flight clamp; the reset decision;
--    the hazards' damage per second and slow; thin ice breaking after
--    standing still on one node.
-- C. boss_dragons.lua, the real file, on a fake engine: a player inside the
--    arena is a target at a height the old 8-node rule refused; a player
--    outside is neither acquired nor a target and cannot hurt the dragon; an
--    engaged dragon whose last hostile leaves resets once (full encounter
--    reset) and flies home, lands, and a re-pull starts a fresh, engaged
--    fight; the hazard tick deals 250 (ice water, with a slow) and 350
--    (ember) once a second through set_hp, never a punch, and thin ice
--    breaks into ice water under a player who stands on it.
-- Prints "R31 DA2 PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- A. Layout
-- ---------------------------------------------------------------------------
local layout = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/arena_layout.lua")
local rules = dofile(repo .. "/mods/ENTITIES/grug_mobs/dragon_arena.lua")
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local profile
for _, p in ipairs(source.anchor_profiles) do if p.id == "dragon" then profile = p end end
check(profile and profile.arena_radius == rules.RADIUS, "A radius: mapgen profile = grug_mobs")
check(profile.building_core_width / 2 >= profile.arena_radius + 1,
	"A the protected core square holds the radius (half-open square)")
local catalog = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r20_poi_catalog.lua")
local dragons_in_catalog = 0
for _, row in ipairs(catalog) do
	if row.kind == "dragon" then
		dragons_in_catalog = dragons_in_catalog + 1
		check(row.width == profile.building_core_width, row.key .. " blueprint width = core")
	end
end
check(dragons_in_catalog == 2, "A two dragon catalog rows")
local arenas = layout.arenas(source)
check(#arenas == 2, "A two arenas")
local seen_theme = {}
for _, a in ipairs(arenas) do
	seen_theme[a.id] = true
	local kinds, ember, rim = {}, {}, 0
	local R = a.radius
	for dz = -R - 1, R + 1 do
		for dx = -R - 1, R + 1 do
			local kind, detail = layout.hazard_at(a.theme, R, dx, dz, a.x + dx, a.z + dz)
			if kind then
				kinds[kind] = (kinds[kind] or 0) + 1
				local r = math.sqrt(dx * dx + dz * dz)
				if kind == "rim" then
					rim = rim + 1
					check(math.floor(r + 0.5) == R, a.id .. " rim on the radius")
					check(detail == 1 or detail == 2, a.id .. " rim height")
				else
					check(r <= R - layout.EDGE_MARGIN + 0.5, a.id .. " hazard inside the edge margin")
					check(r >= layout.SPAWN_CLEAR, a.id .. " hazard clear of the spawn")
					for _, p in ipairs(layout.PERCHES) do
						local ex, ez = dx - p[1], dz - p[2]
						check(ex * ex + ez * ez >= 4.6 * 4.6, ("%s hazard %d,%d clear of perch %d,%d")
							:format(a.id, dx, dz, p[1], p[2]))
					end
					if kind == "frost" then check(detail == 1 or detail == 2, a.id .. " terrace level") end
					if kind == "ember" then ember[dx .. "," .. dz] = true end
				end
			end
		end
	end
	check(rim >= 25 and rim <= 90, a.id .. " sparse rim stones (" .. rim .. ")")
	for key in pairs(ember) do
		local x, z = key:match("^(-?%d+),(-?%d+)$")
		x, z = tonumber(x), tonumber(z)
		local full = true
		for ez = 0, 2 do for ex = 0, 2 do
			if not ember[(x + ex) .. "," .. (z + ez)] then full = false end
		end end
		check(not full, a.id .. " no 3 x 3 ember block at " .. key)
	end
	if a.id == "wyrmglass" then
		check((kinds.thin_ice or 0) > 100 and (kinds.frost or 0) > 100, "A wyrmglass: ice and terraces")
		check(not kinds.ember and not kinds.trunk, "A wyrmglass: no jungle hazards")
	else
		check((kinds.ember or 0) > 50 and (kinds.basalt or 0) > 100 and (kinds.trunk or 0) >= 30,
			"A stormscale: fissures, basalt, trunks")
		check(not kinds.thin_ice and not kinds.frost, "A stormscale: no ice hazards")
	end
end
check(seen_theme.wyrmglass and seen_theme.stormscale, "A both themes")

-- ---------------------------------------------------------------------------
-- B. Rules
-- ---------------------------------------------------------------------------
do
	local arena = {x = 100, y = 50, z = -40, radius = 40}
	check(rules.inside(arena, {x = 100, y = 50, z = -40}), "B centre inside")
	check(rules.inside(arena, {x = 139, y = 50, z = -40}), "B r 39 inside")
	check(not rules.inside(arena, {x = 141, y = 50, z = -40}), "B r 41 outside")
	check(rules.inside(arena, {x = 110, y = 70, z = -40}), "B 20 above inside (any height)")
	check(not rules.inside(arena, {x = 110, y = 80, z = -40}), "B above the band outside")
	check(not rules.inside(arena, {x = 110, y = 38, z = -40}), "B below the band outside")
	local c = rules.clamp(arena, {x = 200, y = 60, z = -40}, 4)
	check(math.abs(c.x - 136) < 1e-9 and c.z == -40 and c.y == 60, "B clamp to radius - 4")
	local same = {x = 110, y = 60, z = -30}
	check(rules.clamp(arena, same, 4) == same, "B clamp leaves inside points")
	check(rules.should_reset(true, 0) and not rules.should_reset(true, 1) and
		not rules.should_reset(false, 0), "B reset only when engaged and nobody inside")
	local N = layout.NODES
	local dps, slow = rules.hazard(N, N.ice_water)
	check(dps == 250 and slow == true, "B ice water 250/s and slow")
	dps, slow = rules.hazard(N, N.ember)
	check(dps == 350 and slow == false, "B ember 350/s, no slow")
	check(rules.hazard(N, N.thin_ice) == nil and rules.hazard(N, "default:stone") == nil,
		"B no damage elsewhere")
	local entry, breaks = rules.ice_step(nil, 7, 0.5)
	check(entry and not breaks, "B ice: 0.5 s")
	entry, breaks = rules.ice_step(entry, 7, 0.5)
	check(entry and not breaks, "B ice: 1 s")
	local moved = rules.ice_step(entry, 8, 0.5)
	check(moved.time == 0.5, "B ice: a new node starts again")
	entry, breaks = rules.ice_step(entry, 7, 0.5)
	check(entry == nil and breaks, "B ice breaks after 1.5 s on one node")
end

-- ---------------------------------------------------------------------------
-- C. boss_dragons.lua on a fake engine
-- ---------------------------------------------------------------------------
local nodes = {}
local function nkey(p) return p.x .. "," .. p.y .. "," .. p.z end
local function round(v) return math.floor(v + 0.5) end
local players, globalsteps, defs = {}, {}, {}
local set_nodes = {}
local Player = {}
Player.__index = Player
function Player:get_pos() return self.pos end
function Player:get_hp() return self.hp end
function Player:set_hp(hp, reason) self.hp = hp; self.reasons[#self.reasons + 1] = reason end
function Player:get_player_name() return self.name end
function Player:is_player() return true end
function Player:get_luaentity() return nil end
local function new_player(name, pos)
	local p = setmetatable({name = name, pos = pos, hp = 5000, reasons = {}}, Player)
	players[#players + 1] = p
	return p
end
core = {
	registered_nodes = setmetatable({}, {__index = function() return {walkable = true} end}),
	get_modpath = function(mod)
		return repo .. (mod == "grug_mapgen" and "/mods/MAPGEN/grug_mapgen" or "/mods/ENTITIES/grug_mobs")
	end,
	register_node = function() end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_leaveplayer = function() end,
	get_connected_players = function() return players end,
	is_player = function(o) return type(o) == "table" and getmetatable(o) == Player end,
	get_objects_inside_radius = function(pos, r)
		local out = {}
		for _, p in ipairs(players) do
			local dx, dy, dz = p.pos.x - pos.x, p.pos.y - pos.y, p.pos.z - pos.z
			if dx * dx + dy * dy + dz * dz <= r * r then out[#out + 1] = p end
		end
		return out
	end,
	get_node_or_nil = function(p) return {name = nodes[nkey(p)] or "air"} end,
	set_node = function(p, n) nodes[nkey(p)] = n.name; set_nodes[#set_nodes + 1] = nkey(p) end,
	get_node_timer = function() return {start = function() end} end,
	hash_node_position = function(p) return nkey(p) end,
	line_of_sight = function() return true end,
	add_particlespawner = function() end, add_particle = function() end,
	add_entity = function() end, chat_send_player = function() end,
	sound_play = function() end,
}
vector = {round = function(p) return {x = round(p.x), y = round(p.y), z = round(p.z)} end}
mobs = {has_priv = function() return false end}
local statuses, slows, combat_marks = {}, {}, 0
grug_core = {
	ground_effect_protected = function() return false end,
	mark_in_combat = function() combat_marks = combat_marks + 1 end,
	set_status = function(_, id) statuses[#statuses + 1] = id end,
}
local resets = 0
grug_mobs = {
	register_homing_arrow = function() end,
	register_mob = function(name, def) defs[name] = def end,
	scale_attack_damage = function(v) return v * 1.5 end,
	slow_player = function(player) slows[#slows + 1] = player.name end,
	stamp_arrow_damage = function() end,
	boss_attempt_reset = function() end,
}
dofile(repo .. "/mods/ENTITIES/grug_mobs/boss_dragons.lua")
-- the encounter reset: what aggro.lua's leash_reset does for a dragon
-- (boss_leash_reset -> cancel_dragon_action, stop, full health)
function grug_mobs.leash_reset(self)
	resets = resets + 1
	grug_mobs.cancel_dragon_action(self)
	self:stop_attack()
	self.health = self.hp_max
end
local ARENA = {x = -3260, y = 101, z = -40, radius = 40}
grug_mobs.register_dragon_bosses({
	arena = function(id) return id == "dragon:wyrmglass" and ARENA or nil end,
	storage = {set_string = function() end},
	settle = function() end,
	player_enemy_of = function() return true end,
	respawn = 1800,
})
local def = defs["grug_mobs:ice_dragon"]
check(def and def._grug_no_leash == true and def._grug_leash_range == nil,
	"C the dragon has no distance or contact leash")
local velocity = {x = 0, y = 0, z = 0}
local dragon = {
	hp_max = 100000, health = 100000, damage = 50, fly = false,
	object = {
		pos = {x = ARENA.x, y = ARENA.y, z = ARENA.z},
		get_pos = function(self) return self.pos end,
		set_velocity = function(_, v) velocity = v end,
		set_acceleration = function() end, set_properties = function() end,
	},
	set_animation = function() end, yaw_to_pos = function() end,
	stop_attack = function(self) self.attack = nil; self.stopped = (self.stopped or 0) + 1 end,
	run_velocity = 6.5,
}
local function tick(dt) return def.do_custom(dragon, dt or 0.1, {}) end
local state = function() return dragon.temp.grug_dragon end

-- C1 a player 20 nodes above the floor, 30 away, inside: a target
local high = new_player("high", {x = ARENA.x + 30, y = ARENA.y + 20, z = ARENA.z})
dragon.attack = high
tick()
check(dragon.attack == high and state().engaged == true, "C1 a high player inside is a target")
check(dragon._grug_target_veto ~= nil and dragon._grug_target_veto(dragon, high) == false,
	"C1 acquisition allows players inside")
-- the flight stays inside the arena
local away = new_player("away", {x = ARENA.x + 45, y = ARENA.y, z = ARENA.z})
check(dragon._grug_target_veto(dragon, away) == true, "C2 acquisition vetoes players outside")
check(def.do_punch(dragon, away) == true, "C2 a punch from outside is cancelled")
check(def.do_punch(dragon, high) == nil, "C2 a punch from inside lands")
dragon.attack = away
tick()
check(dragon.attack == nil, "C2 an outside player is dropped as a target")
-- C3 the last hostile leaves: one reset, the flight home, the landing
dragon.health = 40000
dragon.object.pos = {x = ARENA.x + 20, y = ARENA.y + 6, z = ARENA.z}
players = {away}
local before = resets
tick(0.1)
check(dragon._grug_enraged == true, "C3 enraged below half health")
for _ = 1, 11 do tick(0.1) end
check(resets == before + 1, "C3 one encounter reset when nobody is left inside")
check(dragon.health == dragon.hp_max and state().engaged == false, "C3 full health, not engaged")
check(dragon._grug_enraged == nil, "C3 the enrage of the attempt is cleared")
check(state().mode == "returning", "C3 flying home")
tick(0.1)
check(velocity.x < 0, "C3 it steers back toward the spawn")
for _ = 1, 30 do tick(0.1) end
check(resets == before + 1, "C3 no second reset while nobody is there")
dragon.object.pos = {x = ARENA.x + 1, y = ARENA.y + 6, z = ARENA.z}
tick(0.1)
check(state().mode == "landing" or state().mode == "ground", "C3 lands at the spawn")
-- C4 a re-pull starts a fresh, engaged fight
players = {away, high}
dragon.attack = high
tick(0.1)
check(state().engaged == true and dragon.attack == high, "C4 a re-pull engages again")
for _ = 1, 12 do tick(0.1) end
check(resets == before + 1, "C4 no reset while a hostile is inside")

-- C5 the hazard tick
local step = globalsteps[#globalsteps]
local N = layout.NODES
local wader = new_player("wader", {x = 10, y = 5, z = 10})
nodes[nkey({x = 10, y = 5, z = 10})] = N.ice_water
local burner = new_player("burner", {x = 20, y = 5, z = 20})
nodes[nkey({x = 20, y = 5, z = 20})] = N.ember
players = {wader, burner}
for _ = 1, 4 do step(0.25) end
check(wader.hp == 5000 - 250 and burner.hp == 5000 - 350, "C5 one second: 250 and 350")
for _, p in ipairs({wader, burner}) do
	for _, r in ipairs(p.reasons) do
		check(r.type == "node_damage" and r.type ~= "punch", "C5 set_hp, never a punch")
	end
end
check(wader.reasons[1].custom_type == "grug_mobs:ice_water", "C5 the ice water death reason")
local wader_slowed = 0
for _, n in ipairs(slows) do if n == "wader" then wader_slowed = wader_slowed + 1 end end
check(wader_slowed >= 4, "C5 ice water slows every tick")
for _, n in ipairs(slows) do check(n ~= "burner", "C5 embers do not slow") end
-- thin ice: a player standing on it breaks it within 1.5 s
local skater = new_player("skater", {x = 30, y = 6, z = 30})
for dx = -1, 1 do for dz = -1, 1 do nodes[nkey({x = 30 + dx, y = 5, z = 30 + dz})] = N.thin_ice end end
players = {skater}
for _ = 1, 5 do step(0.25) end
check(nodes[nkey({x = 30, y = 5, z = 30})] == N.thin_ice, "C6 thin ice holds for 1.25 s")
step(0.25)
check(nodes[nkey({x = 30, y = 5, z = 30})] == N.ice_water and
	nodes[nkey({x = 31, y = 5, z = 30})] == N.ice_water and
	nodes[nkey({x = 31, y = 5, z = 31})] == N.thin_ice, "C6 it breaks under and beside the player")
check(skater.hp == 5000, "C6 standing on thin ice costs nothing")

print(("R31 DA2 PORTABLE PASS checks=%d"):format(checks))
