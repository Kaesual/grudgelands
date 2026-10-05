-- Round 36 lane G portable test (LuaJIT): the dragon arenas after the user's
-- 2026-10-05 playtest -- wider ember fissures, larger ice fields, ice water
-- that refreezes after 2 minutes, and a telegraphed push.
--
--   luajit tools/r36_g/portable_test.lua [REPO]
--
-- A. The layout (grug_mapgen/wp40/arena_layout.lua, the real file) on both
--    arenas of the real source map: every fissure three or four wide and
--    written whole (each step's full width is ember, nothing clipped by the
--    edge or the clearances); every ice field one node wider than Round 31's
--    and whole (each main circle all thin ice or terrace); the counts grow;
--    the clearances hold (spawn 9, perches 4.6, edge 4) and no 5 x 5 block is
--    ember; the trunks are whole; from the spawn every floor cell, terrace
--    and trunk is reachable without stepping on ember or thin ice; every
--    ember cell is at most two steps from that floor, every thin-ice cell at
--    most six; the layout is deterministic (a second load, the same cells).
-- B. The ice water (grug_mapgen/world_nodes.lua, the real file, on a fake
--    engine): it starts a 120 s timer, freezes back to thin ice when the
--    timer runs out with nobody in it, and with a player in it looks again
--    after 5 s instead of freezing.
-- C. The push rule (grug_mobs/dragon_arena.lua): the full push (16 nodes per
--    second and 5 up, about 6.4 nodes of travel) away from the dragon; near
--    the edge it is weakened so that even a player slowed to 60 % stays within
--    radius - 4, and with less than a node of room there is none.
-- D. boss_dragons.lua, the real file, on a fake engine: on the ground, with
--    a hostile player within 8 nodes and the gust ready, the dragon winds up
--    (the growl, the flight clip, a 40-particle ring at 8 nodes for the
--    1.25 s wind-up, a feed line for players within 16), pushes nobody
--    during the wind-up, then everyone within 8 (not beyond) with 16 / 5 and
--    holds its breath back 2 s; no gust in flight or with nobody in reach;
--    a dive's slam delays the gust to at least 4 s and its own knockback
--    (7 / 2.8) stays inside the arena too; near the edge the gust's push is
--    weakened or dropped; at most a few hundred particles per gust.
-- Prints "R36 G PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- A. Layout
-- ---------------------------------------------------------------------------
local LAYOUT = repo .. "/mods/MAPGEN/grug_mapgen/wp40/arena_layout.lua"
local layout = dofile(LAYOUT)
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local arenas = layout.arenas(source)
check(#arenas == 2, "A two arenas")
local function key(x, z) return x .. "," .. z end

-- Round 31's sizes, for the comparison.
local OLD_ICE_RADII = {4.5, 4.5, 4.5, 4, 4, 4, 4}
local OLD_EMBER, OLD_THIN_ICE = 121, 437

for _, f in ipairs(layout.FISSURES) do
	check(f[5] == 3 or f[5] == 4, "A fissure width 3 or 4")
end
check(#layout.ICE == #OLD_ICE_RADII, "A seven ice fields")
for index, b in ipairs(layout.ICE) do
	check(b[3] == OLD_ICE_RADII[index] + 1, "A ice field " .. index .. " one node wider")
end
check(layout.ICE_REFREEZE == 120, "A ice water refreezes after 120 s")

local function grid(a)
	local cells, counts = {}, {}
	local R = a.radius
	for dz = -R - 1, R + 1 do
		for dx = -R - 1, R + 1 do
			local kind, detail = layout.hazard_at(a.theme, R, dx, dz, a.x + dx, a.z + dz)
			if kind then
				cells[key(dx, dz)] = kind
				counts[kind] = (counts[kind] or 0) + 1
				if kind == "trunk" then cells[key(dx, dz)] = "trunk" end
				local _ = detail
			end
		end
	end
	return cells, counts
end

-- The cells a fissure's definition covers (arena_layout.lua's own walk).
local ZIGZAG = {0, 1, 1, 0, -1, -1, 0, 1, 0, -1}
local function fissure_steps(f)
	local x1, z1, x2, z2, width = f[1], f[2], f[3], f[4], f[5]
	local steps = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	local along_x = math.abs(x2 - x1) >= math.abs(z2 - z1)
	local out = {}
	for i = 0, steps do
		local x = x1 + math.floor((x2 - x1) * i / steps + 0.5)
		local z = z1 + math.floor((z2 - z1) * i / steps + 0.5)
		local off = ZIGZAG[(i % #ZIGZAG) + 1]
		local row = {}
		for w = 0, width - 1 do
			if along_x then row[#row + 1] = {x, z + off + w}
			else row[#row + 1] = {x + off + w, z} end
		end
		out[#out + 1] = row
	end
	return out
end

local digests = {}
for _, a in ipairs(arenas) do
	local cells, counts = grid(a)
	local R = a.radius
	-- clearances and the edge (DA2's rules, still holding)
	for k, kind in pairs(cells) do
		if kind ~= "rim" then
			local dx, dz = k:match("^(-?%d+),(-?%d+)$")
			dx, dz = tonumber(dx), tonumber(dz)
			local r = math.sqrt(dx * dx + dz * dz)
			check(r <= R - layout.EDGE_MARGIN + 0.5, a.id .. " hazard inside the edge margin")
			check(r >= layout.SPAWN_CLEAR, a.id .. " hazard clear of the spawn")
			for _, p in ipairs(layout.PERCHES) do
				local ex, ez = dx - p[1], dz - p[2]
				check(ex * ex + ez * ez >= 4.6 * 4.6, a.id .. " hazard clear of a perch")
			end
		end
	end
	if a.id == "stormscale" then
		for index, f in ipairs(layout.FISSURES) do
			for _, row in ipairs(fissure_steps(f)) do
				check(#row >= 3, "A fissure " .. index .. " at least three wide at every step")
				for _, c in ipairs(row) do
					check(cells[key(c[1], c[2])] == "ember",
						("A fissure %d whole at %d,%d"):format(index, c[1], c[2]))
				end
			end
		end
		check(counts.ember >= 2 * OLD_EMBER, ("A ember cells %d >= 2 x %d"):format(counts.ember, OLD_EMBER))
		check(counts.trunk == 38, "A the five trunks whole (38 cells)")
		for k, kind in pairs(cells) do
			if kind == "ember" then
				local x, z = k:match("^(-?%d+),(-?%d+)$")
				x, z = tonumber(x), tonumber(z)
				local full = true
				for ez = 0, 4 do for ex = 0, 4 do
					if cells[key(x + ex, z + ez)] ~= "ember" then full = false end
				end end
				check(not full, "A no 5 x 5 ember block at " .. k)
			end
		end
	else
		for index, b in ipairs(layout.ICE) do
			local r = b[3]
			for dz = math.floor(b[2] - r), math.ceil(b[2] + r) do
				for dx = math.floor(b[1] - r), math.ceil(b[1] + r) do
					local ex, ez = dx - b[1], dz - b[2]
					if ex * ex + ez * ez <= r * r then
						local kind = cells[key(dx, dz)]
						check(kind == "thin_ice" or kind == "frost",
							("A ice field %d whole at %d,%d"):format(index, dx, dz))
					end
				end
			end
		end
		check(counts.thin_ice > OLD_THIN_ICE, ("A thin ice cells %d > %d"):format(counts.thin_ice, OLD_THIN_ICE))
	end
	-- Reachability: a walk from the spawn over every cell that is not ember,
	-- thin ice or a rim stone (terraces and trunks are one step up).
	local blocked = {ember = true, thin_ice = true, rim = true}
	local seen, queue, head = {[key(0, 0)] = 0}, {{0, 0}}, 1
	while queue[head] do
		local c = queue[head]
		head = head + 1
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z = c[1] + d[1], c[2] + d[2]
			local k = key(x, z)
			if not seen[k] and x * x + z * z <= (R - 1) * (R - 1) and not blocked[cells[k] or ""] then
				seen[k] = true
				queue[#queue + 1] = {x, z}
			end
		end
	end
	for dz = -R, R do
		for dx = -R, R do
			local k = key(dx, dz)
			local kind = cells[k]
			if dx * dx + dz * dz <= (R - 1) * (R - 1) and not blocked[kind or ""] then
				check(seen[k], ("A %s %s at %d,%d reachable from the spawn"):format(a.id, kind or "floor", dx, dz))
			end
		end
	end
	-- Walking out: steps from each hazard cell to the reachable floor.
	local worst = 0
	local dist, frontier = {}, {}
	for k in pairs(seen) do dist[k] = 0; frontier[#frontier + 1] = k end
	local level = 0
	while #frontier > 0 do
		level = level + 1
		local nextf = {}
		for _, k in ipairs(frontier) do
			local x, z = k:match("^(-?%d+),(-?%d+)$")
			x, z = tonumber(x), tonumber(z)
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local n = key(x + d[1], z + d[2])
				local kind = cells[n]
				if dist[n] == nil and (kind == "ember" or kind == "thin_ice") then
					dist[n] = level
					nextf[#nextf + 1] = n
					if level > worst then worst = level end
				end
			end
		end
		frontier = nextf
	end
	for k, kind in pairs(cells) do
		if kind == "ember" then check(dist[k] and dist[k] <= 2, a.id .. " ember cell " .. k .. " within two steps of floor") end
		if kind == "thin_ice" then check(dist[k] and dist[k] <= 6, a.id .. " ice cell " .. k .. " within six steps of floor") end
	end
	-- Deterministic: the sorted cell list as a digest string.
	local list = {}
	for k, kind in pairs(cells) do list[#list + 1] = k .. "=" .. kind end
	table.sort(list)
	digests[a.id] = table.concat(list, ";")
	print(("  %s: %s, deepest hazard cell %d steps from floor"):format(a.id, (function()
		local parts = {}
		for kind, n in pairs(counts) do parts[#parts + 1] = kind .. "=" .. n end
		table.sort(parts)
		return table.concat(parts, " ")
	end)(), worst))
end
do
	local again = dofile(LAYOUT)
	for _, a in ipairs(again.arenas(source)) do
		local list = {}
		local R = a.radius
		for dz = -R - 1, R + 1 do
			for dx = -R - 1, R + 1 do
				local kind = again.hazard_at(a.theme, R, dx, dz, a.x + dx, a.z + dz)
				if kind then list[#list + 1] = key(dx, dz) .. "=" .. kind end
			end
		end
		table.sort(list)
		check(table.concat(list, ";") == digests[a.id], "A deterministic layout " .. a.id)
	end
end

-- ---------------------------------------------------------------------------
-- B. Ice water refreeze (world_nodes.lua on a fake engine)
-- ---------------------------------------------------------------------------
do
	local defs, timers, set = {}, {}, {}
	local objects = {}
	local engine = {
		register_node = function(name, def) defs[name] = def end,
		get_node_timer = function(pos)
			return {start = function(_, t) timers[#timers + 1] = {pos = pos, t = t} end}
		end,
		get_objects_inside_radius = function() return objects end,
		set_node = function(pos, node) set[#set + 1] = {pos = pos, name = node.name} end,
	}
	local quiet = function() return {} end
	default = setmetatable({}, {__index = function() return quiet end})
	local nodes = {crop_visual = function() return {} end}
	local gathering = {source_can_dig = function() return function() end end}
	dofile(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")(engine,
		repo .. "/mods/MAPGEN/grug_mapgen", nodes, gathering)
	local N = layout.NODES
	local water = defs[N.ice_water]
	check(water and water.on_construct and water.on_timer, "B the ice water node")
	local pos = {x = 1, y = 2, z = 3}
	water.on_construct(pos)
	check(#timers == 1 and timers[1].t == 120, "B a broken node starts a 120 s timer")
	local player = {is_player = function() return true end}
	objects = {player}
	check(water.on_timer(pos) == false and #set == 0 and timers[2] and timers[2].t == 5,
		"B with a player in it: no freeze, a look again after 5 s")
	objects = {{is_player = function() return false end}}
	check(water.on_timer(pos) == false and #set == 1 and set[1].name == N.thin_ice and #timers == 2,
		"B nobody in it: thin ice again, no new timer")
	default = nil
end

-- ---------------------------------------------------------------------------
-- C. The push rule
-- ---------------------------------------------------------------------------
local rules = dofile(repo .. "/mods/ENTITIES/grug_mobs/dragon_arena.lua")
local ARENA = {x = -3260, y = 101, z = -40, radius = 40}
local LIMIT = ARENA.radius - rules.PUSH_EDGE
do
	check(math.abs(rules.push_travel(16) - 6.4) < 1e-9, "C a 16 push carries 6.4 nodes")
	local v = rules.push(ARENA, {x = ARENA.x, y = 0, z = ARENA.z}, {x = ARENA.x + 4, y = 0, z = ARENA.z}, 16, 5)
	check(v and math.abs(v.x - 16) < 1e-9 and v.z == 0 and v.y == 5, "C the full push away from the dragon")
	v = rules.push(ARENA, {x = ARENA.x + 3, y = 0, z = ARENA.z + 4}, {x = ARENA.x, y = 0, z = ARENA.z}, 16, 5)
	check(v and math.abs(v.x + 16 * 0.6) < 1e-9 and math.abs(v.z + 16 * 0.8) < 1e-9, "C the direction is horizontal, away")
	check(rules.push(ARENA, {x = 1, y = 0, z = 1}, {x = 1, y = 5, z = 1}, 16, 5) == nil, "C no direction, no push")
	v = rules.push(nil, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 1}, 16, 5)
	check(v and math.abs(v.z - 16) < 1e-9, "C no arena: the full push")
	-- every direction and distance: a player slowed to 60 % lands within the limit
	local pushed, weakened, dropped = 0, 0, 0
	for r10 = 0, 395, 5 do
		local r = r10 / 10
		for deg = 0, 350, 10 do
			local a = deg * math.pi / 180
			local pos = {x = ARENA.x + r * math.cos(a), y = 0, z = ARENA.z + r * math.sin(a)}
			for odeg = 0, 270, 90 do
				local o = odeg * math.pi / 180
				local origin = {x = pos.x + 3 * math.cos(o), y = 0, z = pos.z + 3 * math.sin(o)}
				local vel = rules.push(ARENA, origin, pos, 16, 5)
				if vel then
					local h = math.sqrt(vel.x * vel.x + vel.z * vel.z)
					local travel = rules.push_travel(h) / rules.SLOW_FLOOR
					local ex, ez = pos.x - ARENA.x + vel.x / h * travel, pos.z - ARENA.z + vel.z / h * travel
					check(ex * ex + ez * ez <= LIMIT * LIMIT + 1e-6, "C even a slowed player stays within radius - 4")
					pushed = pushed + 1
					if h < 16 - 1e-9 then weakened = weakened + 1 end
				else
					dropped = dropped + 1
				end
			end
		end
	end
	check(pushed > 0 and weakened > 0 and dropped > 0, "C full, weakened and dropped pushes all occur")
	v = rules.push(ARENA, {x = ARENA.x + 28, y = 0, z = ARENA.z}, {x = ARENA.x + 34, y = 0, z = ARENA.z}, 16, 5)
	check(v and v.x > 0 and v.x < 16, "C at radius 34 outward: weakened")
	check(rules.push(ARENA, {x = ARENA.x + 30, y = 0, z = ARENA.z}, {x = ARENA.x + 35.5, y = 0, z = ARENA.z}, 16, 5) == nil,
		"C at radius 35.5 outward: none")
	v = rules.push(ARENA, {x = ARENA.x + 38, y = 0, z = ARENA.z}, {x = ARENA.x + 34, y = 0, z = ARENA.z}, 16, 5)
	check(v and math.abs(v.x + 16) < 1e-9, "C at radius 34 pushed inward: the full push")
end

-- ---------------------------------------------------------------------------
-- D. boss_dragons.lua on a fake engine
-- ---------------------------------------------------------------------------
local players, defs = {}, {}
local Player = {}
Player.__index = Player
function Player:get_pos() return self.pos end
function Player:get_hp() return self.hp end
function Player:set_hp(hp) self.hp = hp end
function Player:get_player_name() return self.name end
function Player:is_player() return true end
function Player:get_luaentity() return nil end
function Player:add_velocity(v) self.pushes[#self.pushes + 1] = v end
function Player:punch() self.punched = (self.punched or 0) + 1 end
local function new_player(name, pos)
	local p = setmetatable({name = name, pos = pos, hp = 50000, pushes = {}}, Player)
	players[#players + 1] = p
	return p
end
local particles, sounds, feeds = {}, {}, {}
core = {
	registered_nodes = setmetatable({}, {__index = function() return {walkable = true} end}),
	get_modpath = function(mod)
		return repo .. (mod == "grug_mapgen" and "/mods/MAPGEN/grug_mapgen" or "/mods/ENTITIES/grug_mobs")
	end,
	register_node = function() end, register_globalstep = function() end,
	register_on_leaveplayer = function() end, register_on_dieplayer = function() end,
	register_on_player_hpchange = function() end,
	get_connected_players = function() return players end,
	colorize = function(_, t) return t end,
	is_player = function(o) return type(o) == "table" and getmetatable(o) == Player end,
	get_objects_inside_radius = function(pos, r)
		local out = {}
		for _, p in ipairs(players) do
			local dx, dy, dz = p.pos.x - pos.x, p.pos.y - pos.y, p.pos.z - pos.z
			if dx * dx + dy * dy + dz * dz <= r * r then out[#out + 1] = p end
		end
		return out
	end,
	get_node_or_nil = function() return {name = "default:stone"} end,
	set_node = function() end,
	get_node_timer = function() return {start = function() end} end,
	get_player_by_name = function(name)
		for _, p in ipairs(players) do if p.name == name then return p end end
	end,
	hash_node_position = function(p) return p.x .. "," .. p.y .. "," .. p.z end,
	line_of_sight = function() return true end,
	add_particlespawner = function(def) particles[#particles + 1] = {amount = def.amount, spawner = true} end,
	add_particle = function(def) particles[#particles + 1] = {amount = 1, pos = def.pos, life = def.expirationtime} end,
	add_entity = function() end, chat_send_player = function() end,
	sound_play = function() end,
}
vector = {round = function(p) return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)} end}
mobs = {has_priv = function() return false end}
grug_core = {
	register_on_effective_heal = function() end,
	register_on_effective_absorb = function() end,
	clear_status = function() end, disengage_target = function() end,
	ground_effect_protected = function() return false end,
	mark_in_combat = function() end, set_status = function() end,
	feed = function(player, kind, text, k)
		feeds[#feeds + 1] = {name = player.name, kind = kind, text = text, key = k}
		return true
	end,
}
grug_mobs = {
	register_homing_arrow = function() end,
	register_mob = function(name, def) defs[name] = def end,
	scale_attack_damage = function(v) return v end,
	slow_player = function() end,
	stamp_arrow_damage = function() end,
	leash_reset = function() end,
}
grug_sounds = {play = function(event) sounds[#sounds + 1] = event; return false end}
dofile(repo .. "/mods/ENTITIES/grug_mobs/boss_dragons.lua")
grug_mobs.register_dragon_bosses({
	arena = function(id) return id == "dragon:wyrmglass" and ARENA or nil end,
	storage = {set_string = function() end},
	settle = function() end,
	player_enemy_of = function() return true end,
	respawn = 1800,
})
local T = grug_mobs.DRAGON_TUNING
check(T.gust_radius == 8 and T.gust_push == 16 and T.gust_lift == 5 and T.gust_windup == 1.25 and
	T.gust_cooldown == 12 and T.gust_after_dive == 4 and T.gust_recover == 2 and T.gust_slow == nil,
	"D the gust's numbers")
local def = defs["grug_mobs:ice_dragon"]
local function new_dragon(dx)
	local d = {
		hp_max = 100000, health = 100000, damage = 50, fly = false, _grug_boss_id = "dragon:wyrmglass",
		anims = {},
		object = {pos = {x = ARENA.x + (dx or 0), y = ARENA.y, z = ARENA.z}},
		run_velocity = 6.5,
	}
	d.object.get_pos = function(o) return o.pos end
	d.object.set_velocity = function() end
	d.object.set_acceleration = function() end
	d.object.set_properties = function() end
	d.set_animation = function(self, name) self.anims[#self.anims + 1] = name end
	d.yaw_to_pos = function() end
	d.stop_attack = function(self) self.attack = nil end
	return d
end
local function tick(d, n, dt)
	for _ = 1, n or 1 do def.do_custom(d, dt or 0.1, {}) end
end
local function reset_logs()
	for i = #particles, 1, -1 do particles[i] = nil end
	for i = #sounds, 1, -1 do sounds[i] = nil end
	for i = #feeds, 1, -1 do feeds[i] = nil end
end
local function push_count(p) return #p.pushes end

-- D1 the telegraphed gust on the ground
do
	players = {}
	local near = new_player("near", {x = ARENA.x + 4, y = ARENA.y, z = ARENA.z})
	local mid = new_player("mid", {x = ARENA.x, y = ARENA.y, z = ARENA.z - 7.5})
	local far = new_player("far", {x = ARENA.x - 10, y = ARENA.y, z = ARENA.z})
	local d = new_dragon()
	d.attack = near
	tick(d)
	local st = d.temp.grug_dragon
	check(st.mode == "ground" and st.action == nil, "D1 on the ground, nothing running")
	st.gust, st.primary = 0, 0.5
	reset_logs()
	tick(d)
	check(st.action and st.action.kind == "gust", "D1 the gust winds up first")
	check(st.gust >= T.gust_cooldown - 0.2, "D1 the cooldown restarts at the wind-up")
	local growl = false
	for _, e in ipairs(sounds) do if e == "telegraph" then growl = true end end
	check(growl, "D1 the wind-up growl")
	check(d.anims[#d.anims] == "fly", "D1 the spread wings (the flight clip)")
	local ring = 0
	for _, p in ipairs(particles) do
		if p.pos then
			local dx, dz = p.pos.x - ARENA.x, p.pos.z - ARENA.z
			if math.abs(math.sqrt(dx * dx + dz * dz) - T.gust_radius) < 1e-6 and p.life == T.gust_windup then
				ring = ring + 1
			end
		end
	end
	check(ring == 40, "D1 a 40-particle ring at the gust's reach for the whole wind-up")
	local fed = {}
	for _, f in ipairs(feeds) do
		if f.text:find("spreads its wings") and f.key == "dragon_gust" then fed[f.name] = true end
	end
	check(fed.near and fed.mid and fed.far, "D1 a feed line for everyone within 16")
	tick(d, 12)
	check(push_count(near) == 0 and push_count(mid) == 0, "D1 nobody pushed during the wind-up")
	check(st.action and st.action.kind == "gust", "D1 still winding up at 1.2 s")
	local before_release = #particles
	tick(d)
	check(st.action == nil, "D1 the gust released at 1.3 s")
	check(push_count(near) == 1 and push_count(mid) == 1 and push_count(far) == 0,
		"D1 everyone within 8 pushed once, nobody beyond")
	local v = near.pushes[1]
	check(math.abs(v.x - 16) < 1e-9 and math.abs(v.z) < 1e-9 and v.y == 5, "D1 16 nodes per second away and 5 up")
	v = mid.pushes[1]
	check(math.abs(v.z + 16) < 1e-9 and math.abs(v.x) < 1e-9, "D1 the second player pushed his own way")
	check(rules.push_travel(16) >= 5, "D1 several nodes of travel")
	check(st.primary >= T.gust_recover - 1e-9, "D1 breath held back after the gust")
	local amount = 0
	for _, p in ipairs(particles) do amount = amount + p.amount end
	check(amount <= 200 and #particles > before_release, "D1 a modest particle count per gust (" .. amount .. ")")
	tick(d, 18)
	check(st.action == nil, "D1 no breath within 1.9 s of the gust")
	tick(d, 3)
	check(st.action and st.action.kind == "breath", "D1 the breath after the recovery")
	tick(d, 30)
	check(push_count(near) == 1, "D1 no second gust before its cooldown")
end

-- D2 no gust in flight, none with nobody in reach
do
	players = {}
	local p = new_player("flier", {x = ARENA.x + 20, y = ARENA.y, z = ARENA.z})
	local d = new_dragon()
	d.attack = p
	tick(d)
	local st = d.temp.grug_dragon
	st.primary = 99
	tick(d)
	check(st.mode == "air", "D2 a far target: the dragon flies")
	st.gust = 0
	tick(d, 20)
	check(not (st.action and st.action.kind == "gust") and push_count(p) == 0, "D2 no gust in flight")
	players = {}
	local q = new_player("reach", {x = ARENA.x + 10, y = ARENA.y, z = ARENA.z})
	local g = new_dragon()
	g.attack = q
	tick(g)
	local gs = g.temp.grug_dragon
	gs.gust, gs.primary = 0, 99
	tick(g, 10)
	check(gs.mode == "ground" and gs.action == nil and gs.gust == 0, "D2 nobody within 8: no gust, it stays ready")
	q.pos = {x = ARENA.x + 6, y = ARENA.y, z = ARENA.z}
	tick(g)
	check(gs.action and gs.action.kind == "gust", "D2 a player steps within 8: the gust begins")
end

-- D3 the dive's slam delays the gust; its knockback stays inside too
do
	players = {}
	local target = new_player("dived", {x = ARENA.x + 15, y = ARENA.y, z = ARENA.z})
	local close = new_player("close", {x = ARENA.x + 3, y = ARENA.y, z = ARENA.z})
	local d = new_dragon()
	d.attack = target
	tick(d)
	local st = d.temp.grug_dragon
	st.primary, st.gust = 99, 99
	tick(d)
	check(st.mode == "air", "D3 airborne")
	st.primary, st.gust = 0, 0.5
	tick(d)
	check(st.action and st.action.kind == "dive_warn", "D3 the dive winds up")
	for _ = 1, 50 do
		if not st.action then break end
		tick(d)
	end
	check(st.action == nil and st.mode == "landing", "D3 the dive slammed down")
	check(st.gust >= T.gust_after_dive - 0.2, "D3 the gust waits after the slam (" .. st.gust .. ")")
	check(push_count(close) == 1 and math.abs(close.pushes[1].x - 7) < 1e-9 and
		math.abs(close.pushes[1].y - 2.8) < 1e-9, "D3 the slam's knockback, 7 and 2.8")
	-- the slam near the edge: a player at radius 35.5 is not knocked out
	players = {}
	local edge_target = new_player("edge_t", {x = ARENA.x + 35, y = ARENA.y, z = ARENA.z + 14})
	local edge = new_player("edge", {x = ARENA.x + 35.5, y = ARENA.y, z = ARENA.z})
	local e = new_dragon(31)
	e.attack = edge_target
	tick(e)
	local es = e.temp.grug_dragon
	es.primary, es.gust = 99, 99
	tick(e)
	es.primary = 0
	tick(e)
	check(es.action and es.action.kind == "dive_warn", "D3 a dive at the edge")
	for _ = 1, 50 do
		if not es.action then break end
		tick(e)
	end
	check(es.action == nil and edge.punched == 1, "D3 the slam hit the player at the edge")
	check(push_count(edge) == 0, "D3 ...without a knockback past radius - 4")
end

-- D4 the gust near the edge: weakened or dropped
do
	players = {}
	local edge = new_player("edge", {x = ARENA.x + 34, y = ARENA.y, z = ARENA.z})
	local inner = new_player("inner", {x = ARENA.x + 28, y = ARENA.y, z = ARENA.z + 7})
	local d = new_dragon(28)
	d.attack = edge
	tick(d)
	local st = d.temp.grug_dragon
	st.gust, st.primary = 0, 99
	tick(d, 14)
	check(push_count(edge) == 1, "D4 the player at radius 34 is pushed")
	local v = edge.pushes[1]
	local h = math.sqrt(v.x * v.x + v.z * v.z)
	check(h > 0 and h < 16, "D4 ...weakened (" .. h .. ")")
	check(34 + rules.push_travel(h) / rules.SLOW_FLOOR <= LIMIT + 1e-6, "D4 ...and stays within radius - 4")
	check(push_count(inner) == 1 and math.abs(inner.pushes[1].z - 16) < 1e-9,
		"D4 a player with room is pushed in full")
end

print(("R36 G PORTABLE PASS checks=%d"):format(checks))
