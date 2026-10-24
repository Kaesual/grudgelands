-- Round 60 lane HERBS portable fixture (LuaJIT; round60-plan.md §2 point 9):
-- the Alchemy herbs grow in their tier's level band, in every race's zones.
--
--   luajit tools/r60_herbs/portable_test.lua REPO [--table]
--
--   A. The gates stay: Gravemoss, Dragonweed and Crimson Lotus are healing
--      herbs of the Alchemy groups 1, 2 and 3 (harvest.lua VALID_HERBS) and
--      not farmable; Sunleaf stays an ungated spice (its hashed WP33
--      `farmable` field unchanged; grug_farming decides what is a crop),
--      Stormkelp a spice and Wild Cocoa a found-only food.
--   B. Every zone a gathering row lists has that row's hosts: at least 10 %
--      of the zone's biome targets (simple_map.lua) for an Alchemy herb, more
--      than none for every other row.
--   C. Per race and tier (tools/r60_herbs/reach.lua `tier_zones`: the start
--      zone for T1, the 11-20 zone for T2, the 21-30 zones for T3, the
--      contested 31-40 zone for T4, the band's fronts for T5 and T6), every
--      herb and cooking input of every recipe of the tier grows in those
--      zones. Mob loot is not checked (out of the lane's files; `--table`
--      lists the gaps).
--   D. The manifest digest: the catalogue's EXPECTED_MANIFEST_SHA256 is the
--      SHA-256 of its canonical bytes, and wp40/r7_manifest.lua pins the
--      same digest (both are checked at boot, so a data edit that misses
--      one stops the server).
-- `--table` also prints the herb table and the per race and tier verdicts
-- (the lane report's tables).
-- Prints "R60 HERBS PORTABLE PASS checks=<n>" or raises.

local ROOT = arg and arg[1] or "."
local TABLE = arg and arg[2] == "--table"
local checks, failures = 0, 0

local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end

local reach = dofile(ROOT .. "/tools/r60_herbs/reach.lua")
local world = reach.load(ROOT)
local rows = {}
for _, row in ipairs(world.gathering.p9g_sources()) do rows[row.key] = row end

-- A. The gates.
do
	for key, group in pairs({gravemoss = 1, dragonweed = 2, crimson_lotus = 3}) do
		local row = rows[key]
		check(row and row.harvest_kind == "healing_herb" and row.required_group == group and
			row.farmable == false, "A " .. key .. " is a gated healing herb of group " .. group)
	end
	check(rows.sunleaf.harvest_kind == "spice" and rows.sunleaf.required_group == 1 and
		rows.sunleaf.farmable == true, "A sunleaf stays an ungated spice, its catalogue fields unchanged")
	check(rows.stormkelp.harvest_kind == "spice", "A stormkelp stays a spice")
	check(rows.wild_cocoa.harvest_kind == "found_only_food", "A wild cocoa stays found-only")
	local file = assert(io.open(ROOT .. "/mods/ITEMS/grug_gathering/harvest.lua", "rb"))
	local harvest = file:read("*a")
	file:close()
	for key, group in pairs({gravemoss = 1, dragonweed = 2, crimson_lotus = 3}) do
		check(harvest:find('%["grug_gathering:' .. key .. '"%] = ' .. group .. ',') ~= nil,
			"A harvest.lua gates " .. key .. " at group " .. group)
	end
end

-- B. Every listed zone has the row's hosts.
local alchemy_herb = {}
for _, row in ipairs(reach.herb_rows(world)) do alchemy_herb[row.key] = true end
for _, row in ipairs(world.gathering.p9g_sources()) do
	for _, zone_id in ipairs(row.zones) do
		local zone = world.zone_by_id[zone_id]
		check(zone ~= nil, "B " .. row.key .. " lists a real zone " .. zone_id)
		if zone then
			local _, share = reach.host_biomes(world, row, zone_id)
			local least = alchemy_herb[row.key] and 10 or 1
			check(share >= least, ("B %s has hosts in %s (%d %%, at least %d)")
				:format(row.key, zone_id, share, least))
		end
	end
end

-- C. Herb and cooking inputs per race and tier; mob loot only listed.
local function is_mob(token) return token:sub(1, 10) == "grug_mobs:" end
local verdicts = {}
for tier = 1, 6 do
	for _, race in ipairs(reach.RACES) do
		local result, zones = reach.missing(world, race, tier)
		check(#zones > 0, ("C %s has zones for T%d"):format(race, tier))
		local gaps, loot = {}, {}
		for _, entry in ipairs(result) do
			for _, token in ipairs(entry.missing) do
				if is_mob(token) then
					loot[#loot + 1] = entry.row.id .. ": " .. token
				else
					gaps[#gaps + 1] = entry.row.id .. ": " .. token
				end
			end
		end
		check(#gaps == 0, ("C %s T%d herbs and cooking goods in %s (missing %s)")
			:format(race, tier, table.concat(zones, ", "), table.concat(gaps, "; ")))
		verdicts[#verdicts + 1] = {race = race, tier = tier, zones = zones,
			total = #result, gaps = gaps, loot = loot, result = result}
	end
end

-- D. The manifest digest and its mapgen pin.
do
	local common = dofile(ROOT .. "/tools/wp40/r6/common.lua")
	local sha256 = common.new_sha256()
	local manifest = world.gathering.manifest()
	local digest = common.hex(sha256(manifest.canonical_bytes))
	check(digest == manifest.sha256, "D the catalogue's digest is its canonical bytes' (" ..
		digest .. ")")
	local file = assert(io.open(ROOT .. "/mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua", "rb"))
	local text = file:read("*a")
	file:close()
	check(text:find('"' .. digest .. '"', 1, true) ~= nil,
		"D wp40/r7_manifest.lua pins the gathering digest")
end

if TABLE then
	local function short(item) return (item:gsub("^[%w_]+:", "")) end
	print("Herbs (key, gate group, tiers, density 1/N, zone: host biomes share %):")
	for _, row in ipairs(reach.herb_rows(world)) do
		local tiers = reach.tiers_using(world, row.raw_item)
		print(("%s  %s %d  T%s  1/%d"):format(row.key, row.harvest_kind, row.required_group,
			table.concat(tiers, ",T"), row.fill_denominator))
		for _, zone_id in ipairs(row.zones) do
			local biomes, share = reach.host_biomes(world, row, zone_id)
			print(("    %-32s %s  %d"):format(zone_id,
				table.concat(biomes, "+"):gsub("grug_", ""), share))
		end
	end
	print("Per race and tier (recipes brewable / all; mob-loot gaps):")
	for _, v in ipairs(verdicts) do
		local brewable = 0
		for _, entry in ipairs(v.result) do
			if #entry.missing == 0 then brewable = brewable + 1 end
		end
		local loot = {}
		for _, line in ipairs(v.loot) do loot[#loot + 1] = short(line:match(": (.+)$")) ..
			" (" .. line:match("^(.-):") .. ")" end
		print(("T%d %-6s %d/%d  %s"):format(v.tier, v.race, brewable, v.total,
			#loot > 0 and ("loot missing: " .. table.concat(loot, ", ")) or "all"))
	end
end

if failures > 0 then
	error(("R60 HERBS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R60 HERBS PORTABLE PASS checks=%d"):format(checks))
