-- Round 25 Lane A2: claim census and validation cost, old rule (the
-- blend-envelope boxes of grug_zones.claim_exclusion_in, main before A2) vs
-- ruling 27, on the same world build (tools/r25_road_poi/world.lua, seed
-- 4242424242) and the same lattice as tools/r25_claim_core/fixture.lua.
--   luajit tools/r25_claim_distance/census_compare.lua <repo> new
--   luajit tools/r25_claim_distance/census_compare.lua <tree> old
--     (<tree>: an export of mods/ and tools/ at c79827e4)
-- evidence/census.txt holds both outputs.
local repo, mode = arg[1], arg[2]
local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, "4242424242")
local Z = W.session
local registry = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
local data = {}
local M = registry({storage = {get_string = function(k) return data[k] or "" end,
	set_string = function(k, v) data[k] = v end,
	keys = function() return {} end}, now = function() return 1800000000 end})
M.load()
local records = {}
local world = {}
function world.zone_at(x, z)
	local id = Z.id_at(x, z)
	if not id then return nil end
	local r = records[id]
	if not r then r = Z.get(id); records[id] = r end
	return r
end
function world.territory_at(x, z) return Z.territory_rule_at({x = x, y = 30000, z = z}) end
function world.water_class_at(x, z) return Z.water_class_at(x, z) end
function world.cube_clear() return true end
local feature
if mode == "old" then
	function world.exclusion_in(a, b, c, d) return Z.claim_exclusion_in(a, b, c, d) end
	feature = function(x, z) return Z.claim_exclusion_in(x - 50, z - 50, x + 50, z + 50) end
else
	function world.feature_in(a, b, c, d, m)
		if W.protection.boxes_in(a, b, c, d, m) then return "site" end
		local _, kind = Z.hard_footprint_in(a - m, b - m, c + m, d + m)
		return kind
	end
	feature = function(x, z) return world.feature_in(x - 50, z - 50, x + 50, z + 50, 16) end
end
local centres = {}
for x = -2600, 2600, 101 do
	for z = -2600, 2600, 101 do
		local zone = world.zone_at(x, z)
		if zone and zone.faction then centres[#centres + 1] = {x, z, zone.faction} end
	end
end
local census = {}
local t = os.clock()
for _, c in ipairs(centres) do
	local ok, code = M.validate("p", c[3], {x = c[1], y = Z.terrain_height_at(c[1], c[2]) + 1,
		z = c[2]}, world)
	code = ok and "ok" or code
	census[code] = (census[code] or 0) + 1
end
local full = (os.clock() - t) * 1000 / #centres
-- accepted centres only (the full 10201-column scan), best of 3 passes
local ok_centres = {}
for _, c in ipairs(centres) do
	local y = Z.terrain_height_at(c[1], c[2]) + 1
	if M.validate("p", c[3], {x = c[1], y = y, z = c[2]}, world) then
		ok_centres[#ok_centres + 1] = {x = c[1], y = y, z = c[2], f = c[3]}
	end
end
local ok_best = math.huge
for _ = 1, 3 do
	local t0 = os.clock()
	for _, c in ipairs(ok_centres) do M.validate("p", c.f, c, world) end
	ok_best = math.min(ok_best, (os.clock() - t0) * 1000 / #ok_centres)
end
-- the feature check alone, best of 5 passes over all centres
local best = math.huge
for _ = 1, 5 do
	local t0 = os.clock()
	for _, c in ipairs(centres) do feature(c[1], c[2]) end
	best = math.min(best, (os.clock() - t0) * 1e6 / #centres)
end
local codes = {}
for k, v in pairs(census) do codes[#codes + 1] = k .. " " .. v end
table.sort(codes)
print(("%s: %d centres, %s"):format(mode, #centres, table.concat(codes, ", ")))
print(("%s: %.2f ms per validation (census mean), %.2f ms per accepted validation," ..
	" settlement check alone %.1f us per centre"):format(mode, full, ok_best, best))
