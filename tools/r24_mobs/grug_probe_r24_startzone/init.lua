-- Disposable engine probe (Round 24 Lane D2, ruling 26). Never shipped:
-- tools/r24_mobs/run.sh stages it through tools/luanti_headless.sh.
--
-- For each start zone it samples surface columns on a 24-node grid, sorts
-- them into the level bands of the start-zone gradient (1: L1-3, 2: L4-6,
-- 3: L7-10) and asks the real spawn gate (mobs:spawn_abm_check: the zone
-- palette policy, clocks, level floors, domains and per-mob checks) for every
-- grug_mobs species with a surface spawn row, once at noon and once at
-- midnight. A species counts for a cell when the gate admits it on at least
-- one sampled column of that band and its spawn row can stand on one of the
-- zone's surface nodes (the fertile surfaces of the zone's biomes, gravel,
-- sand and the start-town ground; world_zones.md §7). Hostile (H), prey that
-- fights back (P) and passive critters (C) are marked.
--
-- The quest audit reads every registered quest of a race chain whose kill
-- objective names no zone (the start-zone chain) and reports the level range
-- at which each target can spawn in that race's start zone. A quest whose
-- targets cannot spawn at or below its level is a finding.
--
-- Ruling 25 in the real mapgen: a strip ahead of the Sunscar start is
-- emerged and every level-banded plant there must stand on a column whose
-- content level (surface_mob_level_at, the start-zone gradient) lies in the
-- plant's band.

local P = "[r24_startzone_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end

local ZONES = {
	{race = "dwarf", zone = "elandor_hearthpine_vale", x = -1800, z = -2550},
	{race = "human", zone = "elandor_dawnmere_fields", x = 0, z = -2550},
	{race = "elf", zone = "elandor_silverleaf_glades", x = 1800, z = -2550},
	{race = "undead", zone = "kragmar_stillgrave_hollow", x = -1800, z = 2550},
	{race = "orc", zone = "kragmar_sunscar_flats", x = 0, z = 2550},
	{race = "troll", zone = "kragmar_kapok_cradle", x = 1800, z = 2550},
}

-- Fertile surfaces per biome (world_zones.md §7 vegetation table).
local BIOME_GROUND = {
	grug_meadows = {"default:dirt_with_grass", "default:dirt",
		"grug_nodes:dirt_with_forest_litter"},
	grug_pine_hills = {"default:dirt_with_coniferous_litter",
		"grug_nodes:dirt_with_forest_litter", "default:dirt_with_grass"},
	grug_elf_forest = {"grug_nodes:dirt_with_silver_litter",
		"grug_nodes:dirt_with_forest_litter", "default:dirt_with_grass"},
	grug_deep_forest = {"grug_nodes:dirt_with_forest_litter",
		"default:dirt_with_coniferous_litter", "default:dirt_with_grass"},
	grug_jungle_edge = {"default:dirt_with_rainforest_litter",
		"grug_nodes:dirt_with_canopy_litter", "grug_nodes:mud"},
	grug_savanna = {"default:dry_dirt_with_dry_grass", "default:dry_dirt",
		"grug_nodes:mesa_clay"},
	grug_badlands = {"grug_nodes:mesa_clay", "default:dry_dirt"},
	grug_blight = {"grug_nodes:blight_dirt", "grug_nodes:dirt_with_bone_litter"},
	grug_bone_forest = {"grug_nodes:blight_dirt", "grug_nodes:dirt_with_bone_litter"},
	grug_crags = {"default:gravel"},
	grug_swamp = {"grug_nodes:mud"},
}
local COMMON_GROUND = {"default:gravel", "default:sand"}

local BANDS = {{1, 3}, {4, 6}, {7, 10}}
local CLOCKS = {{"day", 0.5}, {"night", 0.0}}

local function band_of(level)
	for index, band in ipairs(BANDS) do
		if level >= band[1] and level <= band[2] then return index end
	end
end

-- Surface spawn rows: species -> set of host nodes (mobs_redo ABM labels are
-- "<name> spawning"; cave rows on stone are left out by the ground sets).
local function spawn_hosts()
	local hosts = {}
	for _, abm in ipairs(core.registered_abms) do
		local name = abm.label and abm.label:match("^(grug_mobs:[%w_]+) spawning$")
		if name then
			hosts[name] = hosts[name] or {}
			for _, node in ipairs(abm.nodenames or {}) do hosts[name][node] = true end
		end
	end
	return hosts
end

local function role(name)
	local def = core.registered_entities[name]
	if not def then return "?" end
	if def.passive then return "C" end
	if def.attack_players == false then return "P" end
	return "H"
end

local content_test

local function run()
	local hosts = spawn_hosts()
	local names = {}
	for name in pairs(hosts) do names[#names + 1] = name end
	table.sort(names)
	log(("%d species with spawn rows"):format(#names))

	-- per zone: samples per band
	local results = {}
	for _, z in ipairs(ZONES) do
		local record = grug_zones.get(z.zone)
		local ground = {}
		for _, node in ipairs(COMMON_GROUND) do ground[node] = true end
		for _, biome in ipairs(record.biomes) do
			for _, node in ipairs(BIOME_GROUND[biome.id] or {}) do ground[node] = true end
		end
		local start_ground = {
			dwarf = "default:dirt_with_coniferous_litter", human = "default:dirt_with_grass",
			elf = "grug_nodes:dirt_with_silver_litter", undead = "grug_nodes:blight_dirt",
			orc = "default:dry_dirt_with_dry_grass",
			troll = "default:dirt_with_rainforest_litter"}
		ground[start_ground[z.race]] = true
		local samples = {{}, {}, {}}
		for gx = z.x - 1100, z.x + 1100, 24 do
			for gz = z.z - 900, z.z + 900, 24 do
				if grug_zones.id_at(gx, gz) == z.zone and
						grug_zones.water_class_at(gx, gz) == "land" then
					local y = math.max(1, grug_zones.terrain_height_at(gx, gz) + 1)
					local pos = {x = gx, y = y, z = gz}
					local level = grug_zones.mob_level_at(pos)
					local band = level and band_of(level)
					if band then
						local list = samples[band]
						list[#list + 1] = {pos = pos, level = level}
					end
				end
			end
		end
		local zone_result = {samples = samples, cells = {}}
		for band = 1, 3 do
			zone_result.cells[band] = {}
			for _, clock in ipairs(CLOCKS) do
				core.set_timeofday(clock[2])
				local cell = {}
				for _, name in ipairs(names) do
					local host_ok = false
					for node in pairs(hosts[name]) do
						if ground[node] then host_ok = true break end
					end
					if host_ok then
						local low, high
						for _, sample in ipairs(samples[band]) do
							if not mobs:spawn_abm_check(sample.pos, {name = "air"}, name) then
								low = math.min(low or 99, sample.level)
								high = math.max(high or 0, sample.level)
							end
						end
						if low then cell[name] = {low = low, high = high} end
					end
				end
				zone_result.cells[band][clock[1]] = cell
			end
		end
		results[z.race] = zone_result
		for band = 1, 3 do
			for _, clock in ipairs(CLOCKS) do
				local cell = zone_result.cells[band][clock[1]]
				local row, fighters = {}, 0
				for _, name in ipairs(names) do
					local range = cell[name]
					if range then
						local r = role(name)
						if r ~= "C" then fighters = fighters + 1 end
						row[#row + 1] = ("%s(%s %d-%d)"):format(name:sub(11), r, range.low,
							range.high)
					end
				end
				log(("species %s band %d %s [%d columns]: %s"):format(z.race, band,
					clock[1], #samples[band], #row > 0 and table.concat(row, " ") or "-"))
				if #samples[band] > 0 then
					check(fighters > 0, ("%s band %d %s has a hostile or huntable species"):format(
						z.race, band, clock[1]))
				end
			end
		end
	end
	core.set_timeofday(0.5)

	-- Quest audit.
	local ids = {}
	for id in pairs(grug_quests.registered_quests) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local quest = grug_quests.registered_quests[id]
		local zone_result = quest.race and results[quest.race]
		for _, objective in ipairs(quest.objectives) do
			if zone_result and objective.type == "kill" and not objective.zone then
				local level = quest.target_level or quest.min_level
				local parts, best = {}, nil
				for _, mob in ipairs(objective.mobs) do
					local low, high
					for band = 1, 3 do
						for _, clock in ipairs(CLOCKS) do
							local range = zone_result.cells[band][clock[1]][mob]
							if range then
								low = math.min(low or 99, range.low)
								high = math.max(high or 0, range.high)
							end
						end
					end
					parts[#parts + 1] = ("%s %s"):format(mob:sub(11),
						low and ("L%d-%d"):format(low, high) or "never")
					if low and (not best or low < best) then best = low end
				end
				log(("quest %s (level %d): %s"):format(id, level, table.concat(parts, ", ")))
				check(best ~= nil and best <= level, ("%s: a target spawns at or below level %d"):format(
					id, level))
			end
		end
	end
	content_test()
end

-- Ruling 25 in the real mapgen: emerge a strip ahead of the Sunscar start
-- (d 170-240 toward Redtusk, where the gradient runs through bands 1-3 and
-- the old zone field read 9-10) and check every level-banded plant the writer
-- placed there against the content level of its column: cassava needs L1-6,
-- wild grain L4-20 (world_content_catalog.lua).
local PLANT_BANDS = {
	["grug_mapgen:cassava_source"] = {1, 6},
	["grug_mapgen:wild_grain_source"] = {4, 20},
}

content_test = function()
	local x0, x1, z0, z1 = -100, 100, 2550 - 240, 2550 - 170
	local low, high = math.huge, -math.huge
	local levels = {}
	for x = x0, x1, 4 do
		for z = z0, z1, 4 do
			local y = grug_zones.terrain_height_at(x, z)
			low, high = math.min(low, y), math.max(high, y)
			local level = grug_zones.surface_mob_level_at(x, z)
			if level then levels[level] = (levels[level] or 0) + 1 end
		end
	end
	local shares = {}
	for level = 1, 20 do
		if levels[level] then shares[#shares + 1] = ("L%d:%d"):format(level, levels[level]) end
	end
	log("strip content levels (4-node grid): " .. table.concat(shares, " "))
	local minp = vector.new(x0, low - 2, z0)
	local maxp = vector.new(x1, high + 3, z1)
	log("emerging " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	local t0 = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			log(("emerge took %.1f s"):format((core.get_us_time() - t0) / 1e6))
			local names = {}
			for name in pairs(PLANT_BANDS) do names[#names + 1] = name end
			local found = core.find_nodes_in_area(vector.new(x0, low - 2, z0),
				vector.new(x1, high + 3, z1), names)
			local counts, bad = {}, 0
			for _, pos in ipairs(found) do
				local name = core.get_node(pos).name
				local band = PLANT_BANDS[name]
				local level = grug_zones.surface_mob_level_at(pos.x, pos.z)
				counts[name] = (counts[name] or 0) + 1
				if not level or level < band[1] or level > band[2] then
					bad = bad + 1
					log(("%s at %s on level %s"):format(name, core.pos_to_string(pos),
						tostring(level)))
				end
			end
			for _, name in ipairs(names) do
				log(("%s: %d in the strip"):format(name, counts[name] or 0))
			end
			check(#found > 0, "the strip holds level-banded plants")
			check(bad == 0, "every level-banded plant stands on a column of its level band")
			log(("RESULT %s checks=%d failures=%d"):format(
				failures == 0 and "PASS" or "FAIL", checks, failures))
			core.request_shutdown("r24 start-zone probe done", false, 0)
		end)
	end)
end

core.after(2, function()
	local ok, err = pcall(run)
	if not ok then
		core.log("error", P .. "FAIL probe crashed: " .. tostring(err))
		core.request_shutdown("r24 start-zone probe crashed", false, 0)
	end
end)
