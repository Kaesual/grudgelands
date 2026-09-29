-- Round 24 Lane D portable fixture (LuaJIT): the start-zone spawn gradient
-- (ruling 18) on the real zones.lua/simple_map.lua world of two seeds.
--
--   luajit tools/r24_mobs/levels_fixture.lua <repo> [seed ...]
--
-- For each of the six starts it walks node by node along five lines parallel
-- to the front direction (start x and +-150, +-300) and checks:
--   * the 150-node start band is unchanged (1 to 100 nodes, 2 to 150);
--   * behind the start (within 45 degrees of straight back, out to the home
--     coast) the level is the top of band 1;
--   * from the start line toward the front the level never falls and rises by
--     at most one per node (no jump behind the start band);
--   * the last node before the front neighbour is in band 3, so the border
--     step to the next zone stays what it was.
-- surface_mob_level_at is the unchanged content level (zone field plus start
-- band), i.e. exactly what mob_level_at returned at y >= 0 before Round 24, so
-- it serves as the "old" column. The fixture prints the level table along the
-- start line, the border steps and the start-zone area shares where
-- level-gated families may spawn, old and new.
local repo = assert(arg[1], "usage: levels_fixture.lua <repo> [seed ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"4242424242", "10536739806879207652"} end

local failures, checks = 0, 0
local function check(ok, message)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. message)
	end
	return ok
end

local STARTS = {
	{race = "dwarf", x = -1800, z = -2550, direction = 1},
	{race = "human", x = 0, z = -2550, direction = 1},
	{race = "elf", x = 1800, z = -2550, direction = 1},
	{race = "undead", x = -1800, z = 2550, direction = -1},
	{race = "orc", x = 0, z = 2550, direction = -1},
	{race = "troll", x = 1800, z = 2550, direction = -1},
}
local LINES = {0, -150, 150, -300, 300}

local function spawn_level(session, x, z)
	return session.mob_level_at({x = x, y = 10, z = z})
end

for _, seed in ipairs(seeds) do
	local world = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, seed)
	local S = world.session
	print(("seed %s"):format(seed))
	for _, start in ipairs(STARTS) do
		local home = S.id_at(start.x, start.z)
		check(home ~= nil, start.race .. ": start column lies in a zone")
		local steps = {}
		for _, dx in ipairs(LINES) do
			local x = start.x + dx
			local previous, border_step
			for d = -600, 1200 do
				local z = start.z + start.direction * d
				local id = S.id_at(x, z)
				local new = spawn_level(S, x, z)
				local old = S.surface_mob_level_at(x, z)
				local ddx, ddz = x - start.x, z - start.z
				local distance_sq = ddx * ddx + ddz * ddz
				if id == home and old then
					local where = ("%s dx %d d %d (level %s)"):format(start.race, dx, d,
						tostring(new))
					if distance_sq <= 100 * 100 then
						check(new == 1, where .. ": level 1 inside 100 nodes")
					elseif distance_sq <= 150 * 150 then
						check(new == 2, where .. ": level 2 inside 150 nodes")
					elseif d < 0 and -d >= math.abs(dx) then
						check(new == 3, where .. ": top of band 1 behind the start")
					end
					if d > 0 and previous and new then
						check(new >= previous and new - previous <= 1, where ..
							(": rises by at most one per node (%d -> %d)"):format(previous, new))
					end
					if d >= 0 then previous = new or previous end
				elseif d > 0 and previous and id then
					local zone = S.get(id)
					if zone.level_min > 10 then
						border_step = {d = d, inside = previous, outside = new}
						break
					end
				end
			end
			if check(border_step ~= nil, ("%s dx %d: front border found"):format(start.race, dx)) then
				check(border_step.inside >= 7, ("%s dx %d: band 3 at the front border (%d)"):format(
					start.race, dx, border_step.inside))
				steps[#steps + 1] = ("dx %+d: d %d %d->%d"):format(dx, border_step.d,
					border_step.inside, border_step.outside)
			end
		end
		-- The start-line table.
		local row = {}
		for d = -300, 400, 25 do
			local z = start.z + start.direction * d
			local id = S.id_at(start.x, z)
			local level = spawn_level(S, start.x, z)
			row[#row + 1] = ("%d:%s%s"):format(d, level and tostring(level) or "w",
				id ~= home and "*" or "")
		end
		print(("  %-6s %s"):format(start.race, home))
		print("    start line (d toward the front, * = next zone): " .. table.concat(row, " "))
		print("    border steps: " .. table.concat(steps, "; "))

		-- Area shares of the start zone (16-node grid) where the level-gated
		-- families may spawn: L>=4 (fox, ibex, tapir, scorpion, viper) and
		-- L>=7 (Sun-Dried Husk in Sunscar, Poacher in Silverleaf).
		local total, old4, new4, old7, new7 = 0, 0, 0, 0, 0
		local near_old7, near_new7
		for gx = start.x - 1100, start.x + 1100, 16 do
			for gz = start.z - 900, start.z + 900, 16 do
				if S.id_at(gx, gz) == home then
					local old = S.surface_mob_level_at(gx, gz)
					local new = spawn_level(S, gx, gz)
					if old and new then
						total = total + 1
						local ddx, ddz = gx - start.x, gz - start.z
						local distance = math.sqrt(ddx * ddx + ddz * ddz)
						if ddz * start.direction < 0 and
								-ddz * start.direction >= math.abs(ddx) and distance > 150 then
							check(new == 3, ("%s grid %d %d (level %d): top of band 1 " ..
								"behind the start"):format(start.race, gx, gz, new))
						end
						if old >= 4 then old4 = old4 + 1 end
						if new >= 4 then new4 = new4 + 1 end
						if old >= 7 then
							old7 = old7 + 1
							if not near_old7 or distance < near_old7 then near_old7 = distance end
						end
						if new >= 7 then
							new7 = new7 + 1
							if not near_new7 or distance < near_new7 then near_new7 = distance end
						end
					end
				end
			end
		end
		print(("    area L>=4 old %.0f%% new %.0f%%; L>=7 old %.0f%% new %.0f%%;" ..
			" nearest L>=7 old %d new %d nodes"):format(100 * old4 / total,
			100 * new4 / total, 100 * old7 / total, 100 * new7 / total,
			near_old7 or -1, near_new7 or -1))
		check((near_new7 or 1e9) >= 150, start.race .. ": no band 3 inside the start band")
	end
end

print(("checks %d failures %d"):format(checks, failures))
print(failures == 0 and "RESULT PASS" or "RESULT FAIL")
