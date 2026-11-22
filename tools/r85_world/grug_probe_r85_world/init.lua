-- Round 85 lane WORLD engine probe (disposable, never shipped): the arena
-- "Breach Road"'s ground as the engine generates it on a real world.
--
-- The site comes from the world's placement text (`breach_layout.lua`
-- from_placement); the hull, its blend and 4 nodes beyond are emerged and
-- each column's generated ground (the highest walkable node that is no
-- tree, leaves or plant, between the planned ground - 12 and + 24) is
-- compared
-- with the planned ground (`planner_source.column_values_at`):
-- 1. HULL: every hull column's ground at the datum, no liquid from the datum
--    - 4 to the datum + 8;
-- 2. BLEND: every other column's ground at its planned height (the share,
--    the largest difference and the nodes on the differing columns are
--    logged; at least 95 % match: bush stems, cacti and swamp pools differ
--    anywhere in the world);
-- The planned ground's grade is checked offline (tools/r85_world/site.lua,
-- the seed fleet): ground that matches it carries no cut wall.
-- Ends the server itself; "RESULT PASS" is the verdict line.
local PREFIX = "[r85_world_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end
local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local L = dofile(wp40 .. "/breach_layout.lua")

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r85 world probe done", false, 0)
end

local function liquid(name)
	local def = core.registered_nodes[name]
	return def ~= nil and (def.liquidtype or "none") ~= "none"
end
-- ground: a walkable node that is no tree, leaves or plant (a road's
-- surface counts; a bush stem or a cactus does too and shows as a
-- difference, as does a swamp pool's column, whose water is no ground)
local function ground_node(name)
	local def = core.registered_nodes[name]
	if not def or not def.walkable then return false end
	local g = def.groups or {}
	return (g.tree or 0) == 0 and (g.leaves or 0) == 0 and (g.plant or 0) == 0 and
		(g.flora or 0) == 0
end

core.after(2, function()
	local site = L.from_placement(grug_mapgen.wp40.placement_layout_text)
	local planner = grug_mapgen.wp40.planner_source
	local r = site.reach + 4
	local x0, x1 = site.x - L.HALF_X - r, site.x + L.HALF_X + r
	local z0, z1 = site.z - L.HALF_Z - r, site.z + L.HALF_Z + r
	local planned, lo, hi = {}, math.huge, -math.huge
	for z = z0, z1 do
		for x = x0, x1 do
			local y = select(6, planner.column_values_at(x, z))
			planned[(z - z0) * (x1 - x0 + 1) + (x - x0)] = y
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
	end
	log(("site %d,%d datum %d reach %d; emerging x %d..%d z %d..%d y %d..%d"):format(site.x,
		site.z, site.y, site.reach, x0, x1, z0, z1, lo - 12, hi + 24))
	local t0 = core.get_us_time()
	core.emerge_area({x = x0, y = lo - 12, z = z0}, {x = x1, y = hi + 24, z = z1},
		function(_, _, remaining)
			if remaining > 0 then return end
			local ok, err = pcall(function()
				log(("emerged in %.1f s"):format((core.get_us_time() - t0) / 1000000))
				local width = x1 - x0 + 1
				local got = {}
				local hull_bad, hull_wet, same, total, worst = 0, 0, 0, 0, 0
				local odd = {}
				for z = z0, z1 do
					for x = x0, x1 do
						local p = planned[(z - z0) * width + (x - x0)]
						local top
						for y = p + 24, p - 12, -1 do
							if ground_node(core.get_node({x = x, y = y, z = z}).name) then top = y break end
						end
						got[(z - z0) * width + (x - x0)] = top or p
						if L.in_hull(x - site.x, z - site.z) then
							if top ~= site.y then hull_bad = hull_bad + 1 end
							for y = site.y - 4, site.y + 8 do
								if liquid(core.get_node({x = x, y = y, z = z}).name) then
									hull_wet = hull_wet + 1
									break
								end
							end
						else
							total = total + 1
							if top == p then
								same = same + 1
							else
								worst = math.max(worst, math.abs((top or p) - p))
								local name = core.get_node({x = x, y = top or p, z = z}).name ..
									((top or p) > p and " above" or " below")
								odd[name] = (odd[name] or 0) + 1
							end
						end
					end
				end
				log(("hull: %d columns off the datum, %d with liquid"):format(hull_bad, hull_wet))
				check(hull_bad == 0, "the hull's ground at the datum")
				check(hull_wet == 0, "no liquid on the hull")
				log(("blend and beyond: %d of %d columns at their planned ground (%.2f %%), " ..
					"largest difference %d"):format(same, total, 100 * same / total, worst))
				local names = {}
				for name, count in pairs(odd) do names[#names + 1] = {name, count} end
				table.sort(names, function(a, b)
					if a[2] ~= b[2] then return a[2] > b[2] end
					return a[1] < b[1]
				end)
				for i = 1, math.min(6, #names) do
					log(("  differing: %d columns with %s"):format(names[i][2], names[i][1]))
				end
				check(same >= 0.95 * total, "the generated ground is the planned ground")
			end)
			check(ok, "probe ran (" .. tostring(err) .. ")")
			finish()
		end)
end)
