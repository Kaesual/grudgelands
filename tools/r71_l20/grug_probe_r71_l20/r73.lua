-- Round 73 lane SEAM: one run of the redesigned Stilled Seam at level 20, from the
-- registrar to the chest (run.sh with SCENARIO=r73). Questions: the route over the new
-- relief, start to end; a pack follows into the sorting pit and out; the armed ambush
-- springs once when its zone is crossed and its pack engages; the boss fight on the
-- arena's relief and its reset when the player leaves the room; the lava stays as
-- written; the critters are there. The probe moves the character by set_pos along the
-- route's lines at a walk (no grug_home teleport: the ambush sees it as a walk), its
-- feet on each column's floor. `BURST <name>` lines are run.sh's cue for a screenshot.
local E = grug_expeditions
local TR = E.traps
local us = core.get_us_time
local EAST, WEST, NORTH, SOUTH = 3 * math.pi / 2, math.pi / 2, math.pi, 0 -- yaw 0 looks to +z

-- The route's lines through the rooms and passages (stilled_seam.py passage_plan), x, z.
local ROUTE = {{20, 26}, {24, 20}, {29, 20}, {36, 17.5}, {43, 21.5}, {51, 28}, {60, 26}, {66, 22},
	{68, 21.5}, {77, 19.5}, {101, 19.5}, {106, 24}, {106, 34}, {105, 38}, {98.5, 47}, {98.5, 61},
	{97.5, 66}, {100, 71}, {104, 72}}
local AFTER_C = {{104, 76}, {101.5, 80}, {98, 89}, {98.5, 99}, {100, 104}, {100, 108}, {92, 105.5},
	{86, 108}, {80, 108}}
local TO_CHEST = {{80, 108}, {72, 106}, {62, 107}, {55, 107.5}, {40, 107.5}, {35, 105.5}, {30, 106.5},
	{23, 108}}

return function(lib, player)
	local NAME = lib.NAME
	lib.keep_alive = player
	grug_xp.set_xp(player, grug_xp.xp_for_level(20))
	local springs, dust = {}, 0
	local spring_room = E._spring_room
	E._spring_room = function(run, room, p)
		springs[#springs + 1] = room
		lib.logf("SPRING room %s at %s", room, core.pos_to_string(vector.subtract(p:get_pos(), run.minp), 1))
		return spring_room(run, room, p)
	end
	local play = grug_core.particles.play
	grug_core.particles.play = function(id, frame)
		if id == "expedition_ambush_dust" then dust = dust + 1 end
		return play(id, frame)
	end

	local run = assert(E.create(player, "stilled_seam", 0))
	local t0 = us()
	lib.wait_for(function() return run.state == "ready" end, 120)
	lib.logf("ready after %.1f s, level %d", (us() - t0) / 1e6, run.level)
	lib.check(run.state == "ready" and run.level == 20, "ready at level 20")
	core.load_area(run.minp, run.maxp)
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")

	local function rel(x, y, z) return {x = run.minp.x + x, y = run.minp.y + y, z = run.minp.z + z} end
	local function walkable(x, y, z)
		local def = core.registered_nodes[core.get_node(rel(x, y, z)).name]
		return not def or def.walkable ~= false
	end
	-- A column's floor: the first air row with ground under it, from the roof down.
	local function floor_at(x, z)
		x, z = math.floor(x + 0.5), math.floor(z + 0.5)
		for y = 16, 2, -1 do
			if walkable(x, y - 1, z) and not walkable(x, y, z) and not walkable(x, y + 1, z) then return y end
		end
	end
	local function stand(x, z, yaw)
		local y = floor_at(x, z) or 5
		player:set_pos(rel(x, y - 0.49, z))
		if yaw then
			player:set_look_horizontal(yaw)
			player:set_look_vertical(0.1)
		end
	end
	local function mobs(filter)
		local out = {}
		for object in core.objects_in_area(run.minp, run.maxp) do
			local ent = not object:is_player() and object:get_luaentity()
			if ent and ent._grug_expedition == run.id and (not filter or filter(ent)) then out[#out + 1] = object end
		end
		return out
	end
	-- Critters by their object (Round 73 run: keyed by position, a moving critter
	-- counted many times; fixed after the run, not run again).
	local critters_seen = {}
	local function note_critters()
		for _, object in ipairs(mobs(function(e) return e._grug_scenery end)) do critters_seen[object] = true end
	end
	-- A pack mob's home, relative to the box.
	local function home(ent)
		return ent._grug_home and vector.subtract(ent._grug_home, run.minp) or {x = -99, y = 0, z = -99}
	end
	-- Pack c (bay c) stays for the pit test.
	local function bay_c(ent)
		local h = home(ent)
		return h.x >= 98 and h.z >= 66 and h.z <= 86
	end
	-- Kills every pack mob of the run but bay c's (and `spare`'s), as scenario.lua does
	-- (a raw punch is vetoed by the player-punch veto: in the Round 73 run every pack
	-- lived and followed the character; fixed after the run, not run again).
	local function clear(spare, all)
		for _, object in ipairs(mobs(function(e) return e._grug_pack and not e._grug_boss_id end)) do
			local ent = object:get_luaentity()
			if not (spare and spare(ent)) and (all or not bay_c(ent)) then
				ent.health = 0
				ent:check_for_death({type = "unknown"})
			end
		end
		lib.wait(0.3)
	end
	-- A walk along the lines at `speed` nodes a second; the packs on the way die as
	-- they appear (`spare` keeps some), the floor's height under every step.
	local lowest, highest = 99, -99
	local function walk(lines, speed, spare)
		for i = 1, #lines - 1 do
			local a, b = lines[i], lines[i + 1]
			local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			local yaw = math.atan2(-(b[1] - a[1]), b[2] - a[2])
			local s, last = 0, us()
			while s < len do
				local now = us()
				s = math.min(len, s + speed * (now - last) / 1e6)
				last = now
				local x, z = a[1] + (b[1] - a[1]) * s / len, a[2] + (b[2] - a[2]) * s / len
				local h = floor_at(x, z)
				if h then lowest, highest = math.min(lowest, h), math.max(highest, h) end
				stand(x, z, yaw)
				coroutine.yield()
				clear(spare)
				note_critters()
			end
		end
	end

	local function lava()
		local out = {}
		for _, box in ipairs({{110, 0, 20, 124, 16, 38}, {68, 0, 90, 82, 16, 104}}) do
			for _, pos in ipairs(core.find_nodes_in_area(rel(box[1], box[2], box[3]), rel(box[4], box[5], box[6]),
					{"default:lava_source", "default:lava_flowing"})) do
				local p = vector.subtract(pos, run.minp)
				out[#out + 1] = ("%d,%d,%d/%d"):format(p.x, p.y, p.z, core.get_node(pos).param2)
			end
		end
		table.sort(out)
		return table.concat(out, " ")
	end
	local written = lava()
	lib.logf("LAVA %d cells written", select(2, written:gsub("/", "")))

	local chosen = TR.chosen(run)
	local armed = chosen and chosen.ambush and chosen.ambush[1] and chosen.ambush[1].room
	lib.logf("ARMED ambush %s of %d", tostring(armed), chosen and #chosen.ambush or 0)
	lib.check(chosen and #chosen.ambush == 1, "one ambush candidate armed")

	-- The route to bay c, every pack but the armed ambush's dying as it appears. The
	-- shots: the cart bay lit, the haulage drift dark with its end light.
	stand(20, 26, EAST)
	lib.wait(1)
	walk({ROUTE[1], ROUTE[2], ROUTE[3], ROUTE[4], ROUTE[5], ROUTE[6]}, 6)
	stand(51, 28, EAST)
	lib.wait(1.5)
	clear()
	lib.log("BURST cart_bay")
	lib.wait(1)
	walk({ROUTE[6], ROUTE[7], ROUTE[8], ROUTE[9]}, 6)
	stand(78, 19.5, EAST)
	lib.wait(1)
	lib.log("BURST haulage_dark")
	lib.wait(1)
	-- Across an ambush zone at a walk, watching what springs: the pack mobs whose home
	-- lies within four nodes of `zone` ({x, z}).
	local function cross(lines, label, zone)
		local n0 = #springs
		local fresh = {}
		local d0 = dust
		local t_start = us()
		for i = 1, #lines - 1 do
			local a, b = lines[i], lines[i + 1]
			local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			local s, last = 0, us()
			while s < len do
				local now = us()
				s = math.min(len, s + 4 * (now - last) / 1e6)
				last = now
				stand(a[1] + (b[1] - a[1]) * s / len, a[2] + (b[2] - a[2]) * s / len,
					math.atan2(-(b[1] - a[1]), b[2] - a[2]))
				coroutine.yield()
				if #springs > n0 and not fresh.at then
					fresh.at = (us() - t_start) / 1e6
				end
			end
		end
		lib.wait(1)
		local spiders = mobs(function(e)
			local h = home(e)
			return e._grug_pack and math.abs(h.x - zone[1]) <= 4 and math.abs(h.z - zone[2]) <= 4
		end)
		lib.logf("CROSS %s: springs %d -> %d, dust %d -> %d, pack mobs %d, in combat %s", label, n0, #springs,
			d0, dust, #spiders, tostring(grug_core.in_combat(player)))
		return #springs - n0, spiders
	end
	local sprung, spiders = cross({{78, 19.5}, {92, 19.5}}, "haulage", {84, 19.5})
	if armed == "haulage" then
		-- Once in the run, by this crossing or by a knockback into the zone before it.
		lib.check(#springs == 1 and springs[1] == "haulage", "the haulage ambush springs once")
		lib.check(#spiders == 2 and dust >= 1, "two spiders from the alcoves, the dust burst")
		lib.check(grug_core.in_combat(player), "its pack engages at once")
		stand(84, 21, NORTH)
		lib.log("BURST ambush")
		lib.wait(1)
		clear()
		stand(76, 19.5, EAST)
		lib.wait(0.5)
		lib.check(cross({{76, 19.5}, {92, 19.5}}, "haulage again", {84, 19.5}) == 0, "crossing again springs nothing")
	else
		lib.check(sprung == 0, "the unarmed haulage candidate stays quiet")
	end
	clear()
	walk({{92, 19.5}, ROUTE[11], ROUTE[12], ROUTE[13], ROUTE[14], ROUTE[15]}, 6)
	stand(112, 30, EAST)
	lib.wait(1)
	lib.log("BURST lava_fall")
	lib.wait(1)
	stand(98.5, 46, SOUTH)
	lib.wait(1)
	lib.log("BURST drift_dark")
	lib.wait(1)
	sprung, spiders = cross({{98.5, 46}, {98.5, 58}}, "drift", {98.5, 52})
	if armed == "drift" then
		-- Once in the run, by this crossing or by a knockback into the zone before it.
		lib.check(#springs == 1 and springs[1] == "drift", "the drift ambush springs once")
		lib.check(#spiders == 2 and dust >= 1, "two spiders from the alcoves, the dust burst")
		lib.check(grug_core.in_combat(player), "its pack engages at once")
		stand(98.5, 50, SOUTH)
		player:set_look_horizontal(WEST + 0.6)
		lib.log("BURST ambush")
		lib.wait(1)
		clear()
		stand(98.5, 45, SOUTH)
		lib.wait(0.5)
		lib.check(cross({{98.5, 45}, {98.5, 58}}, "drift again", {98.5, 52}) == 0, "crossing again springs nothing")
	else
		lib.check(sprung == 0, "the unarmed drift candidate stays quiet")
	end
	clear()

	-- Pack c follows into the sorting pit and out of it.
	walk({{98.5, 58}, ROUTE[17], ROUTE[18], ROUTE[19]}, 6)
	local pit, rim = {110, 80}, {103, 70}
	lib.logf("PIT floor %s at the pit, %s at the rim", tostring(floor_at(pit[1], pit[2])), tostring(floor_at(rim[1], rim[2])))
	local function follow(to, label)
		local h = floor_at(to[1], to[2])
		local best = 99
		local got = lib.wait_for(function()
			stand(to[1], to[2])
			for _, object in ipairs(mobs(function(e) return e._grug_pack and e.name == "grug_mobs:giant_spider" end)) do
				local p = vector.subtract(object:get_pos(), run.minp)
				local d = math.sqrt((p.x - to[1]) ^ 2 + (p.z - to[2]) ^ 2)
				best = math.min(best, d)
				-- A spider's feet are 0.75 under its middle (spider.lua collisionbox).
				if d <= 3 and math.abs(p.y - 0.75 - (h - 0.5)) <= 1 then return true end
			end
			return false
		end, 15)
		lib.logf("FOLLOW %s: %s, closest spider %.1f", label, got and ("%.1f s"):format(got) or "no", best)
		return got
	end
	lib.check(follow(pit, "into the pit") ~= nil, "pack c follows into the pit")
	lib.check(follow(rim, "out to the rim") ~= nil, "and out of it")
	clear(nil, true)

	-- On to the working face; bay d's pack dies as it appears.
	walk(AFTER_C, 6)
	clear(nil, true)
	local function boss_of()
		for _, object in ipairs(mobs(function(e) return e._grug_boss_id end)) do return object end
	end
	stand(78, 108, WEST)
	lib.wait(1.5)
	local boss = boss_of()
	lib.check(boss ~= nil, "Flintback stands in his court")
	local ent = boss and boss:get_luaentity()
	if ent then
		lib.log("BURST court")
		lib.wait(1)
		-- The fight on the arena's relief: the character at the deep pit, then on the rim
		-- terrace; Flintback walks after it.
		grug_core.deal_ability_damage(player, boss, 50)
		local seen_y = {}
		for _, at in ipairs({{64, 112}, {67, 96}, {75, 116}}) do
			lib.wait_for(function()
				stand(at[1], at[2])
				local p = boss:get_pos()
				-- Flintback's feet: 1.4 under his middle (golem collisionbox x the elite scale).
				if p then seen_y[math.floor(p.y - 1.4 - run.minp.y + 1)] = true end
				return p and vector.distance(p, player:get_pos()) < 3.5
			end, 10)
		end
		local ys = {}
		for y in pairs(seen_y) do ys[#ys + 1] = y end
		table.sort(ys)
		lib.logf("BOSS stood at y %s, health %d/%d", table.concat(ys, ","), ent.health, ent.hp_max)
		lib.check(#ys >= 2, "Flintback walks the arena's levels")
		-- The character leaves the room: alone, it resets him at once.
		walk({{75, 116}, {78, 108}, {86, 108}}, 6)
		local healed = lib.wait_for(function()
			stand(86, 108)
			return ent.health == ent.hp_max
		end, 15)
		lib.logf("BOSS reset: healed after %s s at %s", tostring(healed),
			core.pos_to_string(vector.subtract(boss:get_pos(), run.minp), 1))
		lib.check(healed ~= nil, "leaving the room resets Flintback")
		lib.wait_for(function() return not grug_core.in_combat(player) end, 10)
		-- The kill, from inside the court, for the door.
		lib.wait_for(function() return not (ent.temp and ent.temp.grug_evading) end, 45)
		stand(70, 106)
		lib.wait(0.5)
		for _ = 1, 40 do
			if not boss:get_pos() then break end
			grug_core.deal_ability_damage(player, boss, 2000)
			lib.wait(0.2)
		end
		lib.check(boss_of() == nil, "Flintback is dead")
	end
	lib.wait(0.5)
	lib.check(E.rewards_open(run), "the door and the chest open on the boss")
	walk(TO_CHEST, 6)
	lib.check(vector.distance(player:get_pos(), rel(23, 5, 108)) < 1.5, "the character reaches the chest")

	note_critters()
	local critters = 0
	for _ in pairs(critters_seen) do critters = critters + 1 end
	lib.logf("CRITTERS seen %d", critters)
	lib.check(critters >= 3, "the critters are there")
	lib.logf("ROUTE floor from y %d to %d", lowest, highest)
	local now = lava()
	lib.check(now == written, "the lava stays as written")
	if now ~= written then lib.logf("LAVA now %s", now) end
	lib.logf("springs %d, dust plays %d", #springs, dust)
	E.end_run(run, "probe")
	lib.keep_alive = nil
end
