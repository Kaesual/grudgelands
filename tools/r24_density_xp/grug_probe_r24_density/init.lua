-- Disposable engine probe (Round 24 Lane F). Never shipped:
-- tools/r24_density_xp/run.sh stages it through tools/luanti_headless.sh
-- together with probe_player_shim.patch (mobs_redo count_mobs accepts the
-- stationary probe points below as players in range) and, for the baseline,
-- the reverse of the Lane F grug_mobs change.
--
-- Eight probe points, seed 4242424242: each start zone 170 nodes from its
-- start toward the front (band 1, level 3), plus Moonfall Wood and Redtusk
-- Savanna. Each point's 7x7-block column (y h-32..h+47) is force-loaded, so
-- the real natural spawn ABMs, policy, clocks, light and caps run there. A
-- day window then a night window; at the census times every live grug_mobs
-- entity within 56 nodes (horizontal) of a point is counted: budgeted
-- natural species (the Round 24 ruling 27 set), other natural rows
-- (critters etc.) and everything else (NPCs, camps).

local P = "[r24_density_probe] "
local WINDOW = tonumber(core.settings:get("r24_density_window")) or 120
local CENSUS = {60, 90, 120}
local RADIUS = 56

local POINTS = {
	{id = "hearthpine", x = -1800, z = -2380, h = 50},
	{id = "dawnmere", x = 0, z = -2380, h = 57},
	{id = "silverleaf", x = 1800, z = -2380, h = 28},
	{id = "stillgrave", x = -1800, z = 2380, h = 11},
	{id = "sunscar", x = 0, z = 2380, h = 41},
	{id = "kapok", x = 1800, z = 2380, h = 22},
	{id = "moonfall", x = 2400, z = -1600, h = 44},
	{id = "redtusk", x = 160, z = 2112, h = 96},
}

-- The Round 24 budgeted set, listed so the baseline (which lacks
-- grug_mobs.density_budgeted) is classified identically.
local BUDGETED = {}
for name in ([[ashen_treant bear blightfang_wolf boar bog_ooze bog_witch
carrion_crow crag_eagle crocodile fox frost_stray gaunt_stag giant_rat
giant_spider goblin_hound goblin_raider goblin_slinger gravewood_treant hyena
ibex jungle_ape jungle_boar jungle_lynx jungle_spider mesa_golem mountain_ram
pale_spider panther plague_boar plaguehide_bear poacher rift_spawn scorpion
serpent skeleton_archer skeleton_raider snow_leopard speargrass_tiger stag
stone_golem sun_dried_husk tapir viper vulture war_construct wisp wolf zebra
zombie]]):gmatch("%S+") do
	BUDGETED["grug_mobs:" .. name] = true
end

local function log(msg) core.log("action", P .. msg) end

local variant = grug_mobs.density_allows and "round24" or "baseline"

local function census(label)
	for _, point in ipairs(POINTS) do
		local center = {x = point.x, y = point.h, z = point.z}
		local budgeted, natural, other = 0, 0, 0
		local by_name = {}
		for _, object in ipairs(core.get_objects_inside_radius(center, 120)) do
			local ent = object:get_luaentity()
			local pos = object:get_pos()
			if ent and ent.name and ent.name:sub(1, 10) == "grug_mobs:" and pos then
				local dx, dz = pos.x - point.x, pos.z - point.z
				if dx * dx + dz * dz <= RADIUS * RADIUS then
					if BUDGETED[ent.name] and not ent._grug_camp_pos and
							not ent._grug_rare_id then
						budgeted = budgeted + 1
						local short = ent.name:sub(11)
						by_name[short] = (by_name[short] or 0) + 1
					elseif mobs.spawning_mobs[ent.name] then
						natural = natural + 1
					else
						other = other + 1
					end
				end
			end
		end
		local names = {}
		for name, count in pairs(by_name) do names[#names + 1] = name .. "=" .. count end
		table.sort(names)
		log(("census %s %s %s budgeted=%d natural_other=%d other=%d level=%s [%s]"):format(
			variant, label, point.id, budgeted, natural, other,
			tostring(grug_zones.mob_level_at(center)), table.concat(names, " ")))
	end
end

local function run_window(clock, done)
	core.set_timeofday(clock == "day" and 0.5 or 0.0)
	log(("window %s %s start (%d s)"):format(variant, clock, WINDOW))
	for _, second in ipairs(CENSUS) do
		core.after(second, function()
			-- Hold the clock inside its phase for the whole window.
			core.set_timeofday(clock == "day" and 0.5 or 0.0)
			census(clock .. "@" .. second)
			if second == CENSUS[#CENSUS] then done() end
		end)
	end
	for s = 20, WINDOW - 1, 20 do
		core.after(s, function() core.set_timeofday(clock == "day" and 0.5 or 0.0) end)
	end
end

local function start_measuring()
	local players = {}
	for _, point in ipairs(POINTS) do
		players[#players + 1] = {x = point.x, y = point.h + 2, z = point.z}
		log(("point %s zone=%s level=%s"):format(point.id,
			tostring(grug_zones.id_at(point.x, point.z)),
			tostring(grug_zones.mob_level_at({x = point.x, y = point.h, z = point.z}))))
	end
	mobs._grug_probe_players = players
	run_window("day", function()
		run_window("night", function()
			log("RESULT DONE " .. variant)
			core.request_shutdown("r24 density probe done", false, 0)
		end)
	end)
end

core.after(2, function()
	local pending = 0
	local t0 = core.get_us_time()
	for _, point in ipairs(POINTS) do
		local minp = {x = point.x - 56, y = point.h - 32, z = point.z - 56}
		local maxp = {x = point.x + 55, y = point.h + 47, z = point.z + 55}
		for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
		pending = pending + 1
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining == 0 then
				pending = pending - 1
				if pending == 0 then
					log(("emerged %d areas in %.1f s"):format(#POINTS,
						(core.get_us_time() - t0) / 1e6))
					core.after(1, start_measuring)
				end
			end
		end)
	end
end)
