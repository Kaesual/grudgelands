-- Round 72 lane RANGED portable test (round72-plan.md §2.4, §3.1, §4
-- RANGED): the ranged kings are ordinary ground ranged mobs. Loads the REAL
-- king definitions (cut out of grug_mobs/bosses.lua), the REAL attack-branch
-- decisions of mobs/api.lua do_states (dogswitch, the shot range and closing
-- helpers, the branch conditions and can_nav, cut out) and the REAL
-- mobs/grug_nav.lua and mobs/grug_obstacle.lua on a small fake engine (a
-- node grid, a sampling raycast, a grid search modelled on the engine's
-- pathfinder, copied from tools/r42_nv1/portable_test.lua). Checks:
--   K  the definitions: the Elf, Undead and Troll kings shoot their arrow
--      with a ranged phase (the archers' 10 s / 3 s rhythm), the melee kings
--      and the Generals' seat races are unchanged;
--   R  every registered ground `dogshoot` mob has a ranged phase (no mob is
--      left on upstream's branches); a flier without sight flies at its
--      target and never searches;
--   S  scenes, each king against a target, before (the Round 71 definition,
--      no switch) and after:
--        open   15 m on flat ground: it shoots, no search, it stands;
--        cover  12 m behind a wall: it walks, searches, gets round the wall,
--               sees and shoots;
--        ledge  a target on a 5-high pillar 10 m away, unreachable but in
--               sight: it shoots (the reset is BOSSRESET's);
--        far    30 m: it closes in and shoots inside its shot range;
--        rhythm 10 s ranged, then 3 s melee (it runs at the target), then
--               ranged again;
--        and, reported only, the melee phase against the ledge.
-- Prints the search counts per scene (the fake engine's searches; the
-- engine's costs are the probe's) and the shot cadence.
-- Usage (repo root): luajit tools/r72_ranged/portable_test.lua [REPO]
-- Prints "R72 RANGED PORTABLE PASS checks=<n>" or raises.
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
-- The text from `from` up to (not including) `to`.
local function cut(src, from, to, label)
	local s = src:find(from, 1, true)
	check(s ~= nil, "anchor " .. label)
	local e = src:find(to, s + #from, true)
	check(e ~= nil, "end anchor " .. label)
	return src:sub(s, e - 1)
end
local function load_in(src, env, label)
	local chunk = assert(loadstring(src, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

local api = read("mods/ENTITIES/mobs/api.lua")
local bosses = read("mods/ENTITIES/grug_mobs/bosses.lua")

-- ---------------------------------------------------------------------------
-- K. The king definitions (RACES and king_def cut out of bosses.lua).
-- ---------------------------------------------------------------------------
local STAMP = function() end -- grug_mobs.stamp_arrow_damage
local kings = load_in(cut(bosses, "local RACES = {", "\n-- Each king's name", "RACES") ..
	"\n" .. cut(bosses, "local function king_def(race, row)", "\nlocal ROYAL_FOLLOW_DISTANCE",
	"king_def") .. "\nreturn {races = RACES, def = king_def}",
	{grug_mobs = {stamp_arrow_damage = STAMP}}, "king_def")
local RANGED = {elf = "grug_mobs:arrow_entity", undead = "grug_mobs:rock_entity",
	troll = "grug_mobs:rock_entity"}
local defs = {}
for race, row in pairs(kings.races) do
	row.name = "King " .. race
	defs[race] = kings.def(race, row)
end
for race, def in pairs(defs) do
	if RANGED[race] then
		check(def.attack_type == "dogshoot" and def.arrow == RANGED[race]
			and def.arrow_override == STAMP and def.shoot_interval == 3,
			"K1 the " .. race .. " king shoots " .. RANGED[race] .. " with the shared lock")
		check(def.dogshoot_switch == 1 and def.dogshoot_count_max == 10
			and def.dogshoot_count2_max == 3,
			"K2 the " .. race .. " king has a ranged phase (10 s ranged, 3 s melee)")
		check(def.pathfinding == 1, "K3 the " .. race .. " king may search")
	else
		check(def.attack_type == "dogfight" and def.arrow == nil
			and def.dogshoot_switch == nil, "K4 the " .. race .. " king stays melee")
	end
end
-- The Generals take their seat race's king (bosses.lua): both melee.
local catalog = read("mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua")
for _, race in catalog:match("M%.SEAT_RACE = (%b{})"):gmatch("(%w+) = \"(%w+)\"") do
	check(defs[race] and defs[race].attack_type == "dogfight",
		"K5 a General's seat race (" .. race .. ") is a melee king: Generals unchanged")
end

-- ---------------------------------------------------------------------------
-- R. Every registered ground dogshoot mob has a ranged phase.
-- ---------------------------------------------------------------------------
do
	local files = {"bandit_archer", "bog_witch", "crystal_shard", "dungeon_master",
		"ember_wisp", "goblin_miners", "golem", "night_families", "rift",
		"skeleton_archer", "skeleton_raider", "zero_asset_variants", "bosses"}
	for _, name in ipairs(files) do
		local text = read("mods/ENTITIES/grug_mobs/" .. name .. ".lua")
		local dogshoot = select(2, text:gsub("attack_type%s*=%s*[^\n]*\"dogshoot\"", ""))
		local switches = select(2, text:gsub("dogshoot_switch%s*=%s*[^\n]*1", ""))
		check(dogshoot > 0 and switches >= dogshoot,
			"R1 " .. name .. ".lua: every dogshoot definition sets a dogshoot_switch ("
			.. dogshoot .. " / " .. switches .. ")")
	end
	-- No other file grug_mobs loads registers one (a new ranged family joins
	-- the list above).
	local loaded = 0
	for name in read("mods/ENTITIES/grug_mobs/init.lua"):gmatch("dofile%(modpath %.%. \"/([%w_]+)%.lua\"%)") do
		loaded = loaded + 1
		local text = read("mods/ENTITIES/grug_mobs/" .. name .. ".lua")
		local listed = false
		for _, n in ipairs(files) do listed = listed or n == name end
		check(listed or not text:find("attack_type%s*=%s*[^\n]*\"dogshoot\""),
			"R2 " .. name .. ".lua registers no unlisted dogshoot mob")
	end
	check(loaded > 40, "R2b grug_mobs' files found (" .. loaded .. ")")
end

-- ---------------------------------------------------------------------------
-- The fake engine (as tools/r42_nv1/portable_test.lua).
-- ---------------------------------------------------------------------------
local us = 1000000
local world = {} -- "x,y,z" -> node name; unset is air, below y 1 stone
local LIMIT = 200
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function fill(x1, y1, z1, x2, y2, z2, name)
	for x = math.min(x1, x2), math.max(x1, x2) do
		for y = math.min(y1, y2), math.max(y1, y2) do
			for z = math.min(z1, z2), math.max(z1, z2) do world[key(x, y, z)] = name end
		end
	end
end
local function name_at(x, y, z)
	local n = world[key(x, y, z)]
	if n then return n end
	return y <= 0 and "stone" or "air"
end
local function round(v) return math.floor(v + 0.5) end
vector = {
	distance = function(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end,
}
local NODES = {
	air = {name = "air", walkable = false},
	stone = {name = "stone", walkable = true},
}
core = {
	registered_nodes = NODES,
	registered_items = NODES,
	get_us_time = function() return us end,
}
function core.get_node_or_nil(pos)
	if math.abs(pos.x) > LIMIT or math.abs(pos.z) > LIMIT then return nil end
	return {name = name_at(round(pos.x), round(pos.y), round(pos.z))}
end
function core.get_node(pos)
	return {name = name_at(round(pos.x), round(pos.y), round(pos.z))}
end
-- A raycast that samples the segment and yields each non-air node once.
function core.raycast(from, to)
	local list, seen = {}, {}
	local steps = math.max(1, math.ceil(vector.distance(from, to) / 0.02))
	for i = 0, steps do
		local t = i / steps
		local x = round(from.x + (to.x - from.x) * t)
		local y = round(from.y + (to.y - from.y) * t)
		local z = round(from.z + (to.z - from.z) * t)
		local k = key(x, y, z)
		if not seen[k] and name_at(x, y, z) ~= "air" then
			seen[k] = true
			list[#list + 1] = {type = "node", under = {x = x, y = y, z = z}}
		end
	end
	local i = 0
	return {next = function()
		i = i + 1
		return list[i]
	end}
end
local function walkable(x, y, z)
	local def = NODES[name_at(x, y, z)]
	return not def or def.walkable == true
end
local searches = 0
-- The engine model (pathfinder.cpp): ends must not be walkable; the start
-- walks down to the ground up to max_drop, the goal up to max_jump.
function core.find_path(from, to, pad, jump, drop)
	searches = searches + 1
	us = us + 50
	if walkable(from.x, from.y, from.z) or walkable(to.x, to.y, to.z) then return nil end
	local function down(p, n)
		local y = p.y
		for _ = 1, n do
			if walkable(p.x, y - 1, p.z) then break end
			y = y - 1
		end
		return {x = p.x, y = y, z = p.z}
	end
	local s, g = down(from, drop), down(to, jump)
	local x1, x2 = math.min(from.x, to.x) - pad, math.max(from.x, to.x) + pad - 1
	local z1, z2 = math.min(from.z, to.z) - pad, math.max(from.z, to.z) + pad - 1
	local seen, queue, first = {[key(s.x, s.y, s.z)] = {}}, {s}, 1
	while first <= #queue do
		local c = queue[first]
		first = first + 1
		if c.x == g.x and c.y == g.y and c.z == g.z then
			local rev, k = {}, key(c.x, c.y, c.z)
			while k do
				local e = seen[k]
				rev[#rev + 1] = e.cell or s
				k = e.from
			end
			local path = {}
			for i = #rev, 1, -1 do path[#path + 1] = rev[i] end
			return path
		end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z, y = c.x + d[1], c.z + d[2], c.y
			if x >= x1 and x <= x2 and z >= z1 and z <= z2 then
				local ny
				if not walkable(x, y, z) then
					local yy = y
					while yy > y - drop - 1 and not walkable(x, yy - 1, z) do yy = yy - 1 end
					if walkable(x, yy - 1, z) and y - yy <= drop then ny = yy end
				else
					for up = 1, jump do
						if not walkable(x, y + up, z) and not walkable(c.x, c.y + up, c.z) then
							ny = y + up
							break
						end
					end
				end
				if ny then
					local k = key(x, ny, z)
					if not seen[k] then
						seen[k] = {from = key(c.x, c.y, c.z), cell = {x = x, y = ny, z = z}}
						queue[#queue + 1] = {x = x, y = ny, z = z}
					end
				end
			end
		end
	end
	return nil
end

local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
nav.init({obstacle = O, max_jump = 4, max_drop = 6})

-- ---------------------------------------------------------------------------
-- do_states' attack-branch decision, cut out of api.lua.
-- ---------------------------------------------------------------------------
local mob_class = {}
local line_of_sight = load_in("local mob_class = {}\n" ..
	cut(api, "function mob_class:line_of_sight(pos1, pos2)", "\n-- if not flying", "line_of_sight") ..
	"\nreturn mob_class.line_of_sight", {get_node = core.get_node}, "line_of_sight")
local dogswitch = load_in("local mob_class = {}\n" ..
	cut(api, "function mob_class:dogswitch(dtime)", "\n-- GRUG PATCH (Round 56 MOBAI", "dogswitch") ..
	"\nreturn mob_class.dogswitch", {}, "dogswitch")
local helpers = load_in(cut(api, "local GRUG_SHOT_RANGE_EXTRA = 4", "-- stop attack & reset vars",
	"shot range helpers") .. "\nreturn {range = grug_shot_range, closing = grug_ranged_closing}",
	{mobs = {}}, "shot range helpers")
local function fn(args, body)
	return assert(loadstring("local pathfinding_enable = true\nreturn function(" .. args ..
		") return " .. body .. " end"))()
end
local melee_branch = fn("self, ds_var, dist, in_sight, grug_closing", cut(api,
	"self.attack_type == \"dogfight\" or (self.attack_type == \"dogshoot\"\n", " then\n",
	"melee branch"))
local shoot_branch = fn("self, ds_var", cut(api, "self.attack_type == \"shoot\"\n", " then\n",
	"shoot branch"))
local can_nav = fn("self", cut(api, "local can_nav = ", "\n\t\t\tif can_nav then", "can_nav")
	:gsub("^local can_nav = ", ""))
-- The shoot branch's own navigation call (an ended episode, a stop).
local shoot_nav = fn("self", cut(api,
	"if self.attack_type == \"dogshoot\" and self.dogshoot_switch\n", " then\n", "shoot nav"):gsub("^if ", ""))
local function branch(m, ds_var, dist, in_sight)
	local closing = helpers.closing(m, ds_var, dist)
	if melee_branch(m, ds_var, dist, in_sight, closing) then return "dogfight" end
	if shoot_branch(m, ds_var) then return "shoot" end
	return nil
end

-- R3 a flier: without sight the dogfight branch (flies at it), no search.
do
	local wisp = {attack_type = "dogshoot", dogshoot_switch = 1, fly = true, pathfinding = 1,
		reach = 2, view_range = 16, temp = {}, set_velocity = function() end,
		set_animation = function() end}
	check(branch(wisp, 1, 10, false) == "dogfight" and not can_nav(wisp),
		"R3 a flier without sight flies at its target and never searches")
	check(branch(wisp, 1, 10, true) == "shoot", "R4 ... and shoots once it sees it")
end

-- ---------------------------------------------------------------------------
-- S. Scenes: one king, one standing target, 0.1 s steps.
-- ---------------------------------------------------------------------------
local DT = 0.1
local Y = 0.51 -- feet on the floor's top (y 0)
local target = {
	get_luaentity = function() return nil end,
	is_player = function() return true end,
	get_properties = function() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}} end,
}

-- A live king from its definition: the elite promotion's size (1.4) and the
-- physics box of a mob taller than two nodes (grug_obstacle.physics_box).
local function new_king(race, before)
	local def = defs[race]
	local m = {}
	for k, v in pairs(def) do m[k] = v end
	if before then -- the Round 71 definition
		m.dogshoot_switch, m.dogshoot_count_max, m.dogshoot_count2_max = nil, nil, nil
	end
	local c = def.collisionbox
	local box = {c[1] * 1.4, c[2] * 1.4, c[3] * 1.4, c[4] * 1.4, c[5] * 1.4, c[6] * 1.4}
	m._grug_cbox = O.physics_box(box, m)
	m.initial_properties = {stepheight = def.stepheight}
	m.dogshoot_count = 0
	m.timer = 0
	m.temp = {}
	m.line_of_sight = line_of_sight
	m.set_velocity = function() end
	m.set_animation = function(self, a) self.animation_current = a end
	m.attack = target
	return m
end

-- Can a body of half width `hw` stand with its feet cell at `p`?
local function free(p, hw, head)
	for _, dx in ipairs({-hw, hw}) do
		for _, dz in ipairs({-hw, hw}) do
			for h = 0, head - 1 do
				if walkable(round(p.x + dx), 1 + h, round(p.z + dz)) then return false end
			end
		end
	end
	return true
end

-- Run one scene for `seconds`; returns what happened.
local function run(m, start, tpos, seconds)
	searches = 0
	nav.forget(m.temp)
	local p = {x = start.x, y = Y, z = start.z}
	local out = {shots = 0, shot_at = {}, moved = 0, first_sight = nil, phases = {},
		give_up = false, melee_steps = 0, nil_steps = 0, min_dist = math.huge}
	local body_hw = (m._grug_cbox[4] - m._grug_cbox[1]) / 2
	local steps = math.floor(seconds / DT + 0.5)
	for i = 1, steps do
		us = us + math.floor(DT * 1e6)
		nav.begin_server_step(DT)
		O.begin_server_step()
		m.timer = m.timer + DT -- api.lua on_step, every step
		local dx, dy, dz = tpos.x - p.x, tpos.y - p.y, tpos.z - p.z
		local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
		if dist < out.min_dist then out.min_dist = dist end
		local in_sight = O.target_visible(m, p, tpos, false)
		if in_sight and not out.first_sight then out.first_sight = i * DT end
		local ds_var = m.attack_type == "dogshoot" and dogswitch(m, DT) or 0
		out.phases[#out.phases + 1] = ds_var
		local b = branch(m, ds_var, dist, in_sight)
		if b == "dogfight" then
			out.melee_steps = out.melee_steps + 1
			local goal = tpos
			local v = 0
			if can_nav(m) then
				local steer, outcome = nav.combat_step(m, p, DT, target, tpos, dist,
					dist <= m.reach and in_sight, false)
				if outcome == "give_up" then
					out.give_up = true
					break
				end
				if steer then goal = steer end
			end
			if dist > m.reach or not in_sight then v = m.run_velocity end
			if can_nav(m) then nav.command(m, p, v) end
			local gx, gz = goal.x - p.x, goal.z - p.z
			local l = math.sqrt(gx * gx + gz * gz)
			if v > 0 and l > 1e-6 then
				local d = math.min(l, v * DT)
				-- The engine's collision slides along a wall: the whole step,
				-- else its x part, else its z part.
				local mx, mz = gx / l * d, gz / l * d
				for _, q in ipairs({{x = p.x + mx, y = p.y, z = p.z + mz},
						{x = p.x + mx, y = p.y, z = p.z}, {x = p.x, y = p.y, z = p.z + mz}}) do
					if free(q, body_hw, 2) then
						out.moved = out.moved + vector.distance(p, q)
						p = q
						break
					end
				end
			end
		elseif b == "shoot" then
			if shoot_nav(m) then
				nav.combat_step(m, p, DT, target, tpos, dist, true, false)
				nav.command(m, p, 0)
			end
			-- The shot (api.lua: every shoot_interval, 60 % per step once due;
			-- here always), fired only with sight inside the shot range: the
			-- lock refuses anything else (grug_core.actor_projectile_lock).
			if m.timer > m.shoot_interval then
				m.timer = 0
				check(in_sight and dist <= helpers.range(m), "S0 a shot only with sight in range")
				out.shots = out.shots + 1
				out.shot_at[#out.shot_at + 1] = i * DT
			end
		else
			out.nil_steps = out.nil_steps + 1
		end
	end
	out.pos, out.searches = p, searches
	return out
end

local report = {}
for _, race in ipairs({"elf", "undead", "troll"}) do
	-- open: 15 m on flat ground.
	world = {}
	local before = run(new_king(race, true), {x = 0, z = 0}, {x = 15, y = Y, z = 0}, 9.5)
	local after = run(new_king(race), {x = 0, z = 0}, {x = 15, y = Y, z = 0}, 9.5)
	check(before.shots == 0 and before.moved == 0 and before.nil_steps == 95,
		"S1 before: the " .. race .. " king stands in the open and never shoots")
	check(after.shots == 3 and after.moved == 0 and after.searches == 0,
		"S2 after: the " .. race .. " king shoots every 3 s from where he stands, no search ("
		.. after.shots .. " shots, " .. after.searches .. " searches)")
	report[#report + 1] = race .. " open: shots at " .. table.concat(after.shot_at, ", ") .. " s"

	-- cover: a wall 4 high, z -4..4 at x 5, the target 12 m away behind it.
	world = {}
	fill(5, 1, -4, 5, 4, 4, "stone")
	local tpos = {x = 12, y = Y, z = 0}
	before = run(new_king(race, true), {x = 0, z = 0}, tpos, 9)
	after = run(new_king(race), {x = 0, z = 0}, tpos, 9)
	check(before.shots == 0 and before.moved == 0 and not before.first_sight,
		"S3 before: behind cover the " .. race .. " king stands, blind")
	check(after.first_sight and after.shots >= 1 and after.moved > 2 and not after.give_up,
		"S4 after: the " .. race .. " king walks round the wall (" ..
		string.format("%.1f", after.moved) .. " m), sees at " .. tostring(after.first_sight) ..
		" s and shoots (" .. after.shots .. " shots, " .. after.searches .. " searches)")
	check(after.searches >= 1 and after.searches <= 3, "S5 cover: one to three searches")
	report[#report + 1] = race .. " cover: moved " .. string.format("%.1f", after.moved) ..
		" m, sight at " .. after.first_sight .. " s, shots " .. after.shots ..
		", searches " .. after.searches

	-- ledge: a pillar 5 high at x 10; the target stands on it, unreachable.
	world = {}
	fill(10, 1, 0, 10, 5, 0, "stone")
	tpos = {x = 10, y = 5 + Y, z = 0}
	before = run(new_king(race, true), {x = 0, z = 0}, tpos, 9.5)
	after = run(new_king(race), {x = 0, z = 0}, tpos, 9.5)
	check(before.shots == 0, "S6 before: the " .. race .. " king never shoots at the ledge")
	check(after.first_sight == DT and after.shots == 3 and after.moved == 0
		and after.searches == 0 and not after.give_up,
		"S7 after: the " .. race .. " king shoots the target on the ledge, keeps it")

	-- far: 30 m on flat ground: closes in, then shoots inside the shot range.
	world = {}
	tpos = {x = 30, y = Y, z = 0}
	after = run(new_king(race), {x = 0, z = 0}, tpos, 9)
	check(after.shots >= 1 and after.pos.x >= 30 - helpers.range(new_king(race))
		and after.pos.x <= 30 - (helpers.range(new_king(race)) - 3) + 0.5,
		"S8 far: the " .. race .. " king closes to 3 m inside his shot range and shoots (at "
		.. string.format("%.1f", 30 - after.pos.x) .. " m)")

	-- rhythm: 10 s ranged, 3 s melee (he runs at the target), ranged again.
	world = {}
	local k = new_king(race)
	after = run(k, {x = 0, z = 0}, {x = 15, y = Y, z = 0}, 14)
	local first2, last2
	for i, v in ipairs(after.phases) do
		if v == 2 then
			first2 = first2 or i
			last2 = i
		end
	end
	check(first2 and math.abs(first2 * DT - 10.1) < 0.15 and math.abs((last2 - first2 + 1) * DT
		- 3.1) < 0.15 and after.phases[#after.phases] == 1,
		"S9 the " .. race .. " king's rhythm: ranged to 10 s, melee about 3 s, ranged again")
	check(after.moved > 8, "S10 in the melee phase the " .. race .. " king runs at his target ("
		.. string.format("%.1f", after.moved) .. " m)")
end

-- The melee phase against the ledge, reported, not pinned: the king runs to
-- the foot of the pillar, where the ledge hides his target; back in the
-- ranged phase he searches a way to it, which does not exist, and the
-- navigation gives the target up (aggro.lua give_up_target; from Round 72
-- BOSSRESET's boss floor decides a king's reset). The same as an archer's.
do
	world = {}
	fill(10, 1, 0, 10, 5, 0, "stone")
	local out = run(new_king("elf"), {x = 0, z = 0}, {x = 10, y = 5 + Y, z = 0}, 16)
	report[#report + 1] = "elf ledge 16 s (one melee phase): shots " .. out.shots ..
		", searches " .. out.searches .. ", gave up " .. tostring(out.give_up) ..
		", ended " .. string.format("%.1f", out.min_dist) .. " m from the target"
	check(out.shots >= 3, "S11 the ledge target is shot through the whole ranged phase")
end

for _, line in ipairs(report) do print("  " .. line) end
print("R72 RANGED PORTABLE PASS checks=" .. checks)
