-- Round 87: geographic road occupancy and the two map generations on disk.
local repo = arg[1] or "."
local housing = repo .. "/mods/PLAYER/grug_housing/"
local CM = dofile(housing .. "claim_mask.lua")
local ref = dofile(housing .. "road_reference.lua")(CM)
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local function digest(bytes) return common.hex(sha(bytes)) end
local function road(x, z, reach) return {X = x, Z = z, reach = reach} end
local home = {id = "home", level_min = 11, level_max = 20, faction = "accord",
	territory_rule = "accord_home"}
local function housing_at(x, z) return x >= -33 and z >= 0 end
local route = road({-100, 49, -31}, {0, 0, 0}, 0)
local occupied = {["0 0"] = true}
local added = ref.collect(route, housing_at, occupied)
assert(added["-1 0"] and added["1 0"] and not added["0 0"])
assert(not added["-2 0"] and not occupied["1 0"])
assert(not next(ref.collect(road({-40, -34}, {0, 0}, 0), housing_at, {})))
assert(ref.collect(road({-40, -34}, {0, 0}, 1), housing_at, {})["-1 0"])
local captured = ref.capture({roads = {route}, zones = {home}, zone_at = function(x, z)
	if housing_at(x, z) then return home end
end})
assert(captured["-1 0"] and captured["0 0"] and captured["1 0"])
local seed = "17713522922938657774"
local first = ref.advance(seed, 2, nil, function() return captured end)
local bytes = ref.encode(first, digest)
local read = assert(ref.decode(bytes, digest))
assert(read.seed == seed and not read.previous_reset and not next(read.previous))
assert(ref.encode(read, digest) == bytes)
assert(not ref.advance(seed, 2, read, function() error("warm capture") end))
local function reset()
	return ref.advance(seed, 3, read, function() return occupied end)
end
local second = assert(ref.decode(ref.encode(reset(), digest), digest))
assert(second.previous_reset == 2 and second.previous["1 0"] and not second.chunks["1 0"])
assert(ref.encode(reset(), digest) == ref.encode(second, digest))
assert(not ref.advance(seed, 3, second, function() error("capture after restart") end))
assert(not ref.advance("12345", 4, second, function() return {} end).previous_reset)
assert(not ref.advance(seed, 1, second, function() return {} end).previous_reset)
assert(not ref.decode(bytes:sub(1, -5), digest))
assert(not ref.decode(bytes:gsub("current", "broken"), digest))
print("PASS road occupancy, zone edges, first capture, restart, rollover and damage")
