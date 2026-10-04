-- Round 34 Lane F3 portable test (LuaJIT): rivers never cover a POI core.
--
--   luajit tools/r34_f3/portable_test.lua [REPO] [SEED ...]
--
-- Per SEED (default the three seeds that stopped at load before this lane,
-- "planner anchor tuple differs at 29"; 4282870288782723, whose river must
-- go round anchors 72 and 101 with only a narrow gap between their
-- clearances; 2996858566870034, whose tributary would join its parent across
-- anchor 31's core after the parent went round it; and 12345) the inland
-- water layout is built through the real height session (water_inputs, no
-- roads), then:
--   1. the build passes: its guard (`water_layout.wet_core`) found no core
--      within a river's wet limit;
--   2. checked here again, every POI core keeps a margin >= 0 to every wet
--      segment's wet limit; the closest core and its margin are printed;
--   3. seed 12345 has no detour conflict, so its layout text is the one main
--      built before this lane (sha256 pinned below): a course without a
--      conflict keeps the per-core detour exactly;
--   4. every tributary's junction stretch (its last segment) is at most 320
--      nodes (the reason at tools/seed_fleet/seed.lua JOIN_MAX);
--   5. the guard names the river and core: on the built layout a stand-in
--      core put on a wet vertex is reported with a river; the real cores pass.
-- Prints "R34 F3 PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local seeds = {}
for i = 2, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then
	seeds = {"17713522922938657774", "5575844014311305038", "6410640627505506314",
		"4282870288782723", "2996858566870034", "12345"}
end
-- the water layout text of seed 12345 on main f6d11c95 (before this lane)
local PINNED = {["12345"] = "f140b58b8913b6a01e2313d4f2563b7e425be89564ac6a2c9ce11aa71e9a1d54"}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local tdata = dofile(dir .. "/terrain_data.lua")
local P = tdata.water
local source = dofile(dir .. "/source/simple_map.lua")
local settlement = dofile(dir .. "/r7_settlement.lua")
local palette = dofile(dir .. "/../wp13/palette.lua")
local TWIN = {["default:dirt_with_dry_grass"] = "default:dry_dirt_with_dry_grass"}
local start_grounds = {}
for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" then
		local ground = palette.races[profile.race].ground
		start_grounds[profile.anchor_id] = {ground = TWIN[ground] or ground}
	end
end

-- The water layout of one seed as main builds it (the layout, its text and
-- the POI cores the build read).
local function build(seed)
	local simple_map_factory = dofile(dir .. "/simple_map.lua")(dofile(dir .. "/zone_field.lua"))
	local horizontal = simple_map_factory({source = source, schemas = dofile(dir .. "/schemas.lua"),
		canonical = dofile(dir .. "/canonical.lua"),
		deterministic = dofile(dir .. "/deterministic.lua"), raw_sha256 = sha,
		capital_protection = {}}).new(seed)
	local module = dofile(dir .. "/water_layout.lua")(P)
	local held = {}
	local plain = module.build
	module.build = function(s, opts)
		held.pois = opts.pois
		held.layout = plain(s, opts)
		return held.layout
	end
	local water = {module = module, authored = dofile(dir .. "/water_authored.lua")(P)}
	dofile(dir .. "/height.lua")({source = source, canonical = dofile(dir .. "/canonical.lua"),
		deterministic = dofile(dir .. "/deterministic.lua"), raw_sha256 = sha,
		horizontal_session = horizontal,
		terrain_field = dofile(dir .. "/terrain_field.lua")(tdata), water = water,
		reuse = {}, start_grounds = start_grounds}).new_runtime(seed)
	return module, held.layout, water.cache.text, held.pois
end

-- The closest approach of any wet segment's water to any core (negative:
-- the water reaches into the core's disc).
local function closest(layout, pois)
	local best, at = math.huge, "-"
	for _, r in ipairs(layout.rivers) do
		for i = 1, #r.x - 1 do
			local wa, wb = r.w[i], r.w[i + 1]
			if wa ~= 0 and wb ~= 0 then
				local la = wa > 0 and math.min(r.R[i], wa + P.WET_X) + P.WET_B or 0
				local lb = wb > 0 and math.min(r.R[i + 1], wb + P.WET_X) + P.WET_B or 0
				local lim = math.max(la, lb)
				if lim > 0 then
					local vx, vz = r.x[i + 1] - r.x[i], r.z[i + 1] - r.z[i]
					local l2 = vx * vx + vz * vz
					for _, p in ipairs(pois) do
						local ox, oz = p.x - r.x[i], p.z - r.z[i]
						local t = l2 > 0 and (ox * vx + oz * vz) / l2 or 0
						t = math.max(0, math.min(1, t))
						local ex, ez = ox - t * vx, oz - t * vz
						local m = math.sqrt(ex * ex + ez * ez) - lim - p.r
						if m < best then best, at = m, ("%s river %d"):format(p.id, r.id) end
					end
				end
			end
		end
	end
	return best, at
end

for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	local ok, module, layout, text, pois = pcall(build, seed)
	check(ok, ("seed %s: the water layout builds (%s)"):format(seed, tostring(module)))
	check(type(pois) == "table" and #pois > 90, "seed " .. seed .. ": the POI cores reached the build")
	local margin, at = closest(layout, pois)
	check(margin >= 0, ("seed %s: %s keeps its core dry (margin %.1f)"):format(seed, at, margin))
	-- a tributary's junction stretch stays short (bound and reason:
	-- tools/seed_fleet/seed.lua JOIN_MAX)
	local join = 0
	for _, r in ipairs(layout.rivers) do
		local n = #r.x
		if r.parent and n > 1 then
			local dx, dz = r.x[n] - r.x[n - 1], r.z[n] - r.z[n - 1]
			join = math.max(join, math.sqrt(dx * dx + dz * dz))
		end
	end
	check(join <= 320, ("seed %s: junction stretches at most 320 nodes (%.1f)"):format(seed, join))
	local digest = common.hex(sha(text))
	if PINNED[seed] then
		check(digest == PINNED[seed], ("seed %s: layout text unchanged (%s)"):format(seed, digest))
	end
	-- the guard: a stand-in core on the middle wet vertex of the longest river
	local river, wet
	for _, r in ipairs(layout.rivers) do
		if not river or #r.x > #river.x then river = r end
	end
	for i = math.floor(#river.x / 2), #river.x do
		if river.w[i] > 0 and river.w[i - 1] ~= 0 and river.w[i + 1] ~= 0 then wet = i; break end
	end
	check(wet ~= nil, "seed " .. seed .. ": a wet vertex for the guard")
	local probe = {x = river.x[wet], z = river.z[wet], r = 6, id = "probe", slot = "probe"}
	local rid, p = module.wet_core(module.deserialize(text), {pois[1], probe})
	check(type(rid) == "number" and p == probe,
		("seed %s: the guard names a river and the stand-in core"):format(seed))
	check(module.wet_core(module.deserialize(text), pois) == nil,
		"seed " .. seed .. ": the guard passes the real cores")
	print(("seed %s: closest core %s margin %.1f, longest junction stretch %.1f, layout %s, %.1f s")
		:format(seed, at, margin, join, digest:sub(1, 16), os.clock() - t0))
end
print(("R34 F3 PORTABLE PASS checks=%d"):format(checks))
