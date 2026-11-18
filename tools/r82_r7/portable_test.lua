-- Round 82 lane R7 (plan §4 R7): the per-chunk settlement transaction and
-- P9G scan (audit M4-01, M4-02), the blueprint rebuild on a layout-cache hit
-- (M4-03) and the small items around them.
--
--   luajit tools/r82_r7/portable_test.lua REPO [measure]
--
-- Part A (always): the seed fleet's runtime (tools/seed_fleet/runtime.lua)
-- of seed 12345 writes a fixed set of surface chunks (two capital cores, a
-- village and four land chunks away from every settlement) and prints per
-- chunk its written hash, its plan and write CPU seconds and how often the
-- writer asked the planner source's column query. "measure" stops there, so
-- the same file measures the round's base tree too (REPO = an export of it).
-- Identity is not this part's job: tools/r82_gen/compare.sh compares the
-- written chunks with the round's reference.
--
-- Part B (the branch): the layout cache's sixth section, the prepared
-- handover (M4-03). It is encoded and decoded through layout_cache.lua and
-- must come back equal; then main is constructed as on a cache hit twice,
-- from the four layout texts alone (the old hit) and from the texts plus the
-- decoded handover (the new hit), and everything main reads from the
-- prepared blueprints must agree: the manifest, the preparation identity,
-- the sockets, the camp sites, the protection rows and the terrain audit.
--
-- Part C: the small items (M4-07 zone overlay key, M4-10 byte order).
local repo, mode = arg[1], arg[2]
assert(repo, "usage: portable_test.lua REPO [measure]")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local SEED = "12345"

local failures = 0
local function check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL " .. message)
	end
end

local started = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, SEED)
print(("runtime of seed %s: main %.2f s, build %.2f s"):format(SEED,
	R.seconds.main, R.seconds.build))

-- A canonical text of plain data (sorted keys, numbers exact).
local function canonical(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, out)
			out[#out + 1] = "="
			canonical(value[key], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif kind == "number" then
		out[#out + 1] = ("%.17g"):format(value)
	elseif kind == "string" then
		out[#out + 1] = ("%q"):format(value)
	else
		out[#out + 1] = tostring(value)
	end
	return out
end
local function digest(value)
	local hex = {}
	for _, byte in ipairs({R.sha(table.concat(canonical(value, {}))):byte(1, 8)}) do
		hex[#hex + 1] = ("%02x"):format(byte)
	end
	return table.concat(hex)
end

-- PART A. The chunk holding a column's ground.
local function ground_chunk(x, z)
	local y = R.ground_at(x, z)
	return {x = R.origin(x), y = R.origin(math.max(y, 1)), z = R.origin(z)}
end
local zones = R.built.zones_session
local sockets = R.main.settlement_sockets(R.built)
local columns = {}
local capitals_taken = 0
for _, row in ipairs(sockets) do
	if row.slot == "capital" and capitals_taken < 2 then
		capitals_taken = capitals_taken + 1
		columns[#columns + 1] = {"capital core " .. row.key, row.anchor.x, row.anchor.z}
	end
end
for _, row in ipairs(sockets) do
	if row.slot:find("^village") then
		columns[#columns + 1] = {"village " .. row.key, row.anchor.x, row.anchor.z}
		break
	end
end
-- land away from every settlement: the first land column of a fixed walk
-- whose chunk holds no settlement anchor within 200 nodes
local far = 0
for step = 0, 2000 do
	if far >= 4 then break end
	local x = -4000 + (step * 1931) % 8000
	local z = -3600 + (step * 2711) % 7200
	if zones.water_class_at(x, z) == "land" and R.ground_at(x, z) >= 1 then
		local clear = true
		for _, row in ipairs(sockets) do
			if math.abs(row.anchor.x - x) < 200 and math.abs(row.anchor.z - z) < 200 then
				clear = false
				break
			end
		end
		if clear then
			far = far + 1
			columns[#columns + 1] = {"land " .. x .. "," .. z, x, z}
		end
	end
end

local source = R.planner_source
local queries = 0
local column_values_at = source.column_values_at
source.column_values_at = function(x, z)
	queries = queries + 1
	return column_values_at(x, z)
end
local total_plan, total_write, total_queries = 0, 0, 0
for _, column in ipairs(columns) do
	local minp = ground_chunk(column[2], column[3])
	queries = 0
	local result = R.chunk(minp, {after_plan = function() queries = 0 end})
	total_plan = total_plan + result.plan_seconds
	total_write = total_write + result.write_seconds
	total_queries = total_queries + queries
	print(("chunk %d,%d,%d %s: hash %s plan %.3f s write %.3f s column queries in the write %d"):format(
		minp.x, minp.y, minp.z, column[1], result.data_hash, result.plan_seconds,
		result.write_seconds, queries))
end
source.column_values_at = column_values_at
print(("chunks %d: plan %.3f s, write %.3f s, column queries in the writes %d"):format(
	#columns, total_plan, total_write, total_queries))

-- The settlement palettes the successor builds per transaction before this
-- lane (M4-01): one palette per settlement, timed alone.
do
	local palette = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/palette.lua")
	local roster = dofile(wp40 .. "/r7_settlement.lua").roster
	local t0 = os.clock()
	for _ = 1, 20 do
		for index = 1, #roster do palette.new(roster[index].race) end
	end
	print(("palette.new for the %d roster rows: %.2f ms per transaction"):format(#roster,
		(os.clock() - t0) / 20 * 1000))
end

if mode == "measure" then
	print(("measured in %.1f s"):format(os.clock() - started))
	return
end

-- PART B. The prepared handover through the layout cache (M4-03).
do
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local cache = dofile(wp40 .. "/layout_cache.lua")({
		sha256 = function(bytes) return common.hex(R.sha(bytes)) end,
		list_dir = function() return {} end, write = function() return true end,
		identity = function() return "x" end})
	local handover = R.main.prepared_handover()
	local key = cache.key(SEED, "source", "settings", "interpreter")
	local texts = {placement = R.main.placement_layout_text(),
		water = R.main.water_layout_text(), road = R.main.road_layout_text(),
		capital = R.main.capital_layout_text(), prepared = handover}
	local t0 = os.clock()
	local bytes = cache.encode(key, texts, {seconds = {}})
	local t1 = os.clock()
	local decoded, reason = cache.decode(bytes, key)
	local t2 = os.clock()
	check(decoded ~= nil, "the cache file decodes: " .. tostring(reason))
	local count, prepared_bytes = 0, #cache.encode_plain(handover)
	for _ in pairs(handover) do count = count + 1 end
	print(("handover: %d blueprints, %d bytes in the cache, encoded in %.3f s, " ..
		"file decoded in %.3f s"):format(count, prepared_bytes, t1 - t0, t2 - t1))
	check(decoded and digest(decoded.prepared) == digest(handover),
		"the decoded handover equals the built one")
	-- a damaged prepared section is a miss
	local broken = bytes:gsub("bounds", "bounbs", 1)
	check(cache.decode(broken, key) == nil, "an edited prepared section does not decode")

	-- main on a cache hit, before (texts only) and after (texts and handover)
	local runtime_factory = dofile(wp40 .. "/r7_runtime.lua")
	local native = dofile(wp40 .. "/r7_native.lua")
	local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
	local projection = handoff.project(rawget(_G, "grug_materials"))
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local schematics = repo .. "/mods/BASE/default/schematics"
	local function hit(prepared)
		local t = os.clock()
		local runtime = runtime_factory(R.fake, wp40, schematics, projection, catalog,
			decoded.water, decoded.road, decoded.capital, prepared, decoded.placement)
		local built = runtime.build_authority(native.identities())
		return runtime, built, os.clock() - t
	end
	local old_runtime, old_built, old_seconds = hit(nil)
	local new_runtime, new_built, new_seconds = hit(decoded.prepared)
	print(("main on a cache hit: runtime construction %.2f s before, %.2f s after"):format(
		old_seconds, new_seconds))
	check(old_built.manifest.sha256 == new_built.manifest.sha256, "the manifest is the same")
	check(old_built.manifest.sha256 == R.main.build_authority(native.identities()).manifest.sha256,
		"the hit's manifest is the first start's")
	check(old_built.preparation_source.identity == new_built.preparation_source.identity,
		"the preparation identity is the same")
	local old_sockets = old_runtime.settlement_sockets(old_built)
	local new_sockets = new_runtime.settlement_sockets(new_built)
	check(digest(old_sockets) == digest(new_sockets), "the settlement sockets are the same")
	check(digest(old_sockets) == digest(sockets), "the hit's sockets are the first start's")
	check(digest(old_runtime.prepared_handover()) == digest(decoded.prepared),
		"the old hit rebuilds the cached handover")
	check(digest(old_runtime.settlement_terrain_findings(old_built)) ==
		digest(new_runtime.settlement_terrain_findings(new_built)),
		"the terrain audit is the same")
	local camp_sites = dofile(wp40 .. "/r69_camp_sites.lua")
	local function sites(rows, prepared)
		local out = {}
		for _, site in ipairs(camp_sites(wp40, R.sha, rows, prepared)) do
			out[#out + 1] = site.key
		end
		return out
	end
	check(digest(sites(old_sockets, old_runtime.prepared_handover())) ==
		digest(sites(new_sockets, decoded.prepared)), "the camp sites are the same")
	print(("cache hit consumers compared: manifest %s, sockets %s, handover %s"):format(
		new_built.manifest.sha256:sub(1, 16), digest(new_sockets), digest(decoded.prepared)))
end

-- PART C. The small items.
do
	-- M4-10: every Round 14 palette is in byte order (the order the settlement
	-- loader checks).
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	local builder = dofile(wp40 .. "/r14_poi_blueprint.lua")
	local checked = 0
	for _, profile in ipairs(settlement.roster) do
		if profile.blueprint_file == "r14_poi_blueprint.lua" then
			local blueprint = builder({full_seed = SEED, raw_sha256 = R.sha}, profile)
			if type(blueprint) == "function" then blueprint = blueprint() end
			for index = 2, #blueprint.palette do
				check(settlement.less_bytes(blueprint.palette[index - 1], blueprint.palette[index]),
					profile.key .. " palette is in byte order")
			end
			checked = checked + 1
		end
	end
	check(checked == 18, "18 Round 14 settlements build from the one builder")
end

-- M4-09: a grown capital plan reuses the first try's sample grid and masks.
-- A capital of seed 12345 is planned again with a target area so small that
-- a named plot is left out and a larger retry wins; that plan must equal the
-- one planned from scratch at the winning area.
do
	local W = dofile(repo .. "/tools/r26_capitals/world.lua")(repo)
	local planner = W.planner
	local captured = {}
	local original = planner.plan
	planner.plan = function(seed, I, opt)
		captured[#captured + 1] = {seed = seed, I = I, opt = opt}
		return original(seed, I, opt)
	end
	W.plan(SEED)
	planner.plan = original
	local proven
	for _, call in ipairs(captured) do
		if proven then break end
		local opt = {}
		for key, value in pairs(call.opt or {}) do opt[key] = value end
		opt.TARGET_AREA = (opt.TARGET_AREA or planner.DEFAULTS.TARGET_AREA) * 0.5
		opt.GROW, opt.GROW_TRIES = 0.5, 2
		local grown = planner.plan(call.seed, call.I, opt)
		if grown.P.TARGET_AREA ~= opt.TARGET_AREA then
			local scratch_opt = {}
			for key, value in pairs(opt) do scratch_opt[key] = value end
			scratch_opt.TARGET_AREA, scratch_opt.GROW_TRIES = grown.P.TARGET_AREA, 0
			local scratch = planner.plan(call.seed, call.I, scratch_opt)
			check(planner.serialize(grown) == planner.serialize(scratch),
				call.I.anchor.id .. ": the grown plan equals the plan from scratch")
			print(("capital retry: %s won at area %.0f (asked %.0f), layouts equal"):format(
				call.I.anchor.id, grown.P.TARGET_AREA, opt.TARGET_AREA))
			proven = true
		end
	end
	check(proven, "a capital retry was planned and compared")
end

print(("r82_r7: %s in %.1f s"):format(failures == 0 and "OK" or (failures .. " failures"),
	os.clock() - started))
if failures > 0 then error("r82_r7: " .. failures .. " failures", 0) end
