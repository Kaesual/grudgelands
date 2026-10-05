-- Disposable Round 35 lane E probe (tools/r35_e/engine.sh). Never shipped.
--
-- Night mobs leave at dawn (round35-plan.md §2.5). On land 120+ nodes from
-- the Undead start (forceloaded, no player), just before dawn, the probe puts
-- down Large Grave Rats as the region spawn does (spawn_regions.lua
-- SR.spawn_mob: tag, clock, level; mobs:add_mob itself refuses to spawn
-- without a player) with the Stillgrave Dead Furrows tag:
--   NIGHT    four under the night clock: each must leave within a few seconds
--            of dawn;
--   FIGHTER  one more under the night clock, attacking a stand-in target: it
--            must stay while it fights and leave once the target is gone
--            (removed 20 s after dawn);
--   DAY      one under the day clock: it must stay.
-- COST: every grug_mobs.dawn_tick call is timed (all mobs in the area).
-- Every line carries "[r35e]"; the probe ends the server when done.
local P = "[r35e] "
local function log(s) core.log("action", P .. s) end
local now_us = core.get_us_time
local TAG = "kragmar_stillgrave_hollow/dead_furrows"
local ROLE = "large_rat"

local cost = {us = 0, n = 0}
core.register_on_mods_loaded(function()
	local orig = grug_mobs.dawn_tick
	grug_mobs.dawn_tick = function(self, dtime)
		local t0 = now_us()
		local r = orig(self, dtime)
		cost.us = cost.us + (now_us() - t0)
		cost.n = cost.n + 1
		return r
	end
end)

core.register_entity("grug_probe_r35_e:target", {
	initial_properties = {
		physical = false, pointable = true, static_save = false, hp_max = 100,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

local phase, phase_t, total_t, log_t = "wait", 0, 0, 0
local site, emerge_done, target
local groups = {night = {}, fighter = {}, day = {}}
local dawn_at, target_gone_at
local left_at = {} -- object -> seconds after dawn it was gone
local fighter_seen_fighting = 0

local function set_phase(p)
	phase, phase_t = p, 0
	log("phase -> " .. p)
end

local function alive(obj)
	return obj:get_pos() ~= nil and obj:get_luaentity() ~= nil
end

local function find_site()
	local start = grug_core.start_position("throng", "undead")
	if not start then return nil end
	for d = 120, 400, 20 do
		for _, dir in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z = math.floor(start.x + dir[1] * d), math.floor(start.z + dir[2] * d)
			local ok = grug_zones.water_class_at(x, z) == "land"
			for _, o in ipairs({{-12, -12}, {12, -12}, {-12, 12}, {12, 12}}) do
				ok = ok and grug_zones.water_class_at(x + o[1], z + o[2]) == "land"
			end
			local h = grug_zones.terrain_height_at(x, z)
			if ok and h and h > 3 then
				return {x = x, z = z, h = h, zone = grug_zones.id_at(x, z)}
			end
		end
	end
end

local function forceload(c)
	for bx = math.floor((c.x - 24) / 16), math.floor((c.x + 24) / 16) do
		for bz = math.floor((c.z - 24) / 16), math.floor((c.z + 24) / 16) do
			for by = math.floor((c.h - 16) / 16), math.floor((c.h + 16) / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	core.emerge_area({x = c.x - 32, y = c.h - 24, z = c.z - 32},
		{x = c.x + 32, y = c.h + 24, z = c.z + 32}, function(_, _, remaining)
			if remaining == 0 then emerge_done = true end
		end)
end

-- SR.spawn_mob's own steps (spawn_regions.lua) without mobs:add_mob, which
-- refuses to spawn with no player in the area: the entity on the ground
-- point, the unit's tag, the spawn clock and a level in the role's range.
local function spawn_like_region(unit, g, clock)
	local obj = core.add_entity({x = g.x, y = g.y + 1, z = g.z}, "grug_mobs:" .. ROLE)
	local ent = obj and obj:get_luaentity()
	if not ent then return nil end
	ent._grug_area = unit.tag
	ent._grug_spawn_clock = clock
	local range = unit.levels_by_role[ROLE]
	grug_mobs.relevel(ent, math.random(range[1], range[2]))
	return ent
end

local function spawn(group, clock, dx, dz)
	local SR = grug_mobs.spawn_regions
	local unit = SR.area_by_tag(TAG)
	local why = "no unit"
	for i = 0, 6 do
		local g = unit and SR.ground_at(site.x + dx + i, site.z + dz, math.floor(site.h), 24)
		local ent = g and spawn_like_region(unit, g, clock)
		if ent then
			groups[group][#groups[group] + 1] = ent.object
			return ent
		end
		why = unit and (g and ("no room at " .. core.pos_to_string(g) .. " " .. g.node) or
			("no ground, node " .. core.get_node({x = site.x + dx + i, y = math.floor(site.h),
			z = site.z + dz}).name)) or why
	end
	log("spawn failed: " .. group .. ": " .. why)
end

local function counts()
	local out = {}
	for _, name in ipairs({"night", "fighter", "day"}) do
		local n = 0
		for _, obj in ipairs(groups[name]) do
			if alive(obj) then n = n + 1 end
		end
		out[#out + 1] = name .. " " .. n .. "/" .. #groups[name]
	end
	return table.concat(out, ", ")
end

local function finish()
	local ok = #groups.night == 4 and #groups.fighter == 1 and #groups.day == 1
	local worst = 0
	for _, obj in ipairs(groups.night) do
		local t = left_at[obj]
		ok = ok and t ~= nil
		worst = math.max(worst, t or 999)
	end
	local fighter = groups.fighter[1]
	local ft = fighter and left_at[fighter]
	ok = ok and ft ~= nil and target_gone_at ~= nil and ft >= target_gone_at and
		fighter_seen_fighting > 0
	ok = ok and groups.day[1] ~= nil and alive(groups.day[1])
	log(("night rats gone %.1f s after dawn at the latest; fighter fought %d steps after dawn, " ..
		"target removed %.1f s after dawn, fighter gone %.1f s after dawn; day rat %s")
		:format(worst, fighter_seen_fighting, target_gone_at or -1, ft or -1,
		groups.day[1] and alive(groups.day[1]) and "still there" or "gone"))
	log(("dawn_stats.left = %d"):format(grug_mobs.dawn_stats.left))
	log(("COST dawn_tick %d calls, %.3f us per call, %.1f ms total"):format(cost.n,
		cost.n > 0 and cost.us / cost.n or 0, cost.us / 1000))
	log(ok and "RESULT PASS" or "RESULT FAIL")
	set_phase("off")
	core.request_shutdown("r35e probe done", false, 0)
end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			site = find_site()
			if not site then
				log("RESULT NOSITE")
				set_phase("off")
				core.request_shutdown("r35e no site", false, 0)
				return
			end
			log(("site %d,%d h %d zone %s"):format(site.x, site.z, site.h, tostring(site.zone)))
			forceload(site)
			set_phase("emerge")
		end
	elseif phase == "emerge" then
		if phase_t > 4 and (emerge_done or phase_t > 90) then
			core.set_timeofday(0.170)
			for i = 1, 4 do spawn("night", "night", -12 + i * 5, -10) end
			local fighter = spawn("fighter", "night", 0, 8)
			spawn("day", "day", 8, -4)
			if fighter then
				local p = fighter.object:get_pos()
				target = core.add_entity({x = p.x + 1.5, y = p.y, z = p.z}, "grug_probe_r35_e:target")
				fighter:do_attack(target)
			end
			log("spawned: " .. counts() .. ", time " .. core.get_timeofday())
			set_phase("night")
		end
	elseif phase == "night" or phase == "day" then
		local clock = grug_mobs.spawn_regions.clock_now()
		if phase == "night" and clock == "day" then
			dawn_at = total_t
			set_phase("day")
		end
		local since = dawn_at and total_t - dawn_at
		for _, list in pairs(groups) do
			for _, obj in ipairs(list) do
				if not left_at[obj] and not alive(obj) then
					left_at[obj] = since or -1
					log(("a mob left at %s"):format(since and ("%.2f s after dawn"):format(since) or "night"))
				end
			end
		end
		local fighter = groups.fighter[1]
		if since and fighter and alive(fighter) and target and target:get_pos() then
			local ent = fighter:get_luaentity()
			if ent and ent.attack then fighter_seen_fighting = fighter_seen_fighting + 1 end
		end
		if since and since > 20 and target and target:get_pos() then
			target:remove()
			target_gone_at = since
			log(("target removed at %.1f s after dawn"):format(since))
		end
		log_t = log_t + dtime
		if log_t >= 2 then
			log_t = 0
			log(("t %.1f tod %.4f clock %s: %s"):format(total_t, core.get_timeofday(), clock, counts()))
		end
		if since and (since > 75 or (target_gone_at and fighter and left_at[fighter] and since > 30)) then
			finish()
		end
		if phase == "night" and phase_t > 120 then
			log("no dawn after 120 s")
			finish()
		end
	end
end)
