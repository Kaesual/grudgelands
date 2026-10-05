-- Disposable Round 36 lane F probe (tools/r36_f/engine.sh). Never shipped.
--
-- Free mobs run home only from outside their wander radius (round36-plan.md
-- §2.14.2). On flat land 120+ nodes from a start (forceloaded, no
-- player) one Wolf (a free damage-pursuit mob) per case is spawned at a home
-- point and set on a stand-in target, which hits it once (the reset must heal
-- it) and then walks away. No effective player damage arrives, so the 15 s
-- clock since the first aggro ends the fight while the target keeps moving:
--   INSIDE   the target walks to 6-20 nodes from home: the reset finds the
--            mob inside its 32-node wander radius, so it must heal, drop the
--            target and never evade;
--   OUTSIDE  the target walks to 55-60 nodes from home: the mob must evade
--            (untouchable, running home) and be a normal mob again once back
--            inside the wander radius, not at 4 nodes, and then stay there.
-- Once a second each case logs the mob's state, grug_evading, its distance to
-- home and its health. Every line carries "[r36f]"; the probe ends the server.
local P = "[r36f] "
local MOB = "grug_mobs:wolf"
local function log(s) core.log("action", P .. s) end

core.register_entity("grug_probe_r36_f:target", {
	initial_properties = {
		physical = false, pointable = true, static_save = false, hp_max = 100,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

local function hdist(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- A straight line of land from x - 16 to x + 80 (and 4 nodes to each side),
-- authority heights within 6 nodes of its start: room for the walk away.
-- Searched 120-600 nodes around the six starts, nearest rings first.
local STARTS = {{"accord", "human"}, {"accord", "dwarf"}, {"accord", "elf"},
	{"throng", "undead"}, {"throng", "orc"}, {"throng", "troll"}}
local function line_ok(x, z)
	local h0 = grug_zones.terrain_height_at(x, z)
	if not h0 or h0 <= 3 then return nil end
	for i = -16, 80, 4 do
		for _, dz in ipairs({-4, 0, 4}) do
			local h = grug_zones.terrain_height_at(x + i, z + dz)
			if grug_zones.water_class_at(x + i, z + dz) ~= "land" or not h or
					math.abs(h - h0) > 6 then
				return nil
			end
		end
	end
	return h0
end
local function find_site()
	for d = 120, 600, 16 do
		for _, sr in ipairs(STARTS) do
			local start = grug_core.start_position(sr[1], sr[2])
			if start then
				for _, dir in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local x, z = math.floor(start.x + dir[1] * d), math.floor(start.z + dir[2] * d)
					local h = line_ok(x, z)
					if h then return {x = x, z = z, h = h, zone = grug_zones.id_at(x, z)} end
				end
			end
		end
	end
end

local emerge_done
local function forceload(c)
	for bx = math.floor((c.x - 24) / 16), math.floor((c.x + 88) / 16) do
		for bz = math.floor((c.z - 24) / 16), math.floor((c.z + 24) / 16) do
			for by = math.floor((c.h - 16) / 16), math.floor((c.h + 16) / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	core.emerge_area({x = c.x - 24, y = c.h - 16, z = c.z - 24},
		{x = c.x + 88, y = c.h + 16, z = c.z + 24}, function(_, _, remaining)
			if remaining == 0 then emerge_done = true end
		end)
end

-- The standing height of column (x, z): the first walkable node from above.
local function ground(x, z, h)
	for y = h + 12, h - 12, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable then return y + 0.5 end
	end
	return h + 0.5
end

local site
local cases = {
	{name = "INSIDE", near = 6, far = 20, speed = 1.5},
	{name = "OUTSIDE", near = 55, far = 60, speed = 4},
}
local case_index, c = 0, nil
local results = {}

local function begin_case()
	case_index = case_index + 1
	c = cases[case_index]
	if not c then return false end
	local home = {x = site.x, y = ground(site.x, site.z, site.h), z = site.z}
	local obj = core.add_entity({x = home.x, y = home.y + 1, z = home.z}, MOB)
	local ent = obj and obj:get_luaentity()
	if not ent then
		log("RESULT FAIL could not spawn " .. MOB)
		return false
	end
	grug_mobs.place_on_ground(obj, home)
	ent._grug_home = {x = home.x, y = home.y, z = home.z}
	c.mob, c.home, c.t, c.log_t, c.dir = ent, home, 0, 0, 1
	c.tx = home.x + 6
	c.target = core.add_entity({x = c.tx, y = ground(c.tx, home.z, site.h), z = home.z},
		"grug_probe_r36_f:target")
	ent:do_attack(c.target)
	-- The stand-in hits it once: a reset must heal it.
	obj:punch(c.target, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = 6}}, nil)
	c.hp_max = ent.hp_max
	c.hp_hit = ent.health
	log(("%s start: %s at %s, damage_pursuit=%s free_roamer=%s level=%s hp %s/%s"):format(
		c.name, MOB, core.pos_to_string(home), tostring(grug_mobs.damage_pursuit(ent)),
		tostring(grug_mobs.free_roamer(ent)), tostring(ent._grug_level), tostring(ent.health),
		tostring(ent.hp_max)))
	return true
end

local function finish_case()
	local ok
	if c.name == "INSIDE" then
		ok = c.reset_t ~= nil and not c.evaded and c.reset_dist ~= nil and c.reset_dist < 32 and
			c.reset_hp == c.hp_max
	else
		ok = c.reset_t ~= nil and c.evaded and c.reset_dist ~= nil and c.reset_dist > 32 and
			c.evade_end_dist ~= nil and c.evade_end_dist > 24 and c.evade_end_dist <= 32.5 and
			c.after_min ~= nil and c.after_min > 20
	end
	log(("%s summary: target dropped at %s s, reset at %s s (%s nodes from home, hp %s/%s after a hit to %s), evaded %s, " ..
		"evade ended at %s nodes after %s s, nearest home after it %s; %s"):format(c.name,
		c.drop_t and ("%.1f"):format(c.drop_t) or "-",
		c.reset_t and ("%.1f"):format(c.reset_t) or "-", c.reset_dist and ("%.1f"):format(c.reset_dist) or "-",
		tostring(c.reset_hp), tostring(c.hp_max), tostring(c.hp_hit), tostring(c.evaded == true),
		c.evade_end_dist and ("%.1f"):format(c.evade_end_dist) or "-",
		c.evade_len and ("%.1f"):format(c.evade_len) or "-",
		c.after_min and ("%.1f"):format(c.after_min) or "-", ok and "PASS" or "FAIL"))
	results[#results + 1] = ok
	if c.target and c.target:get_pos() then c.target:remove() end
	if c.mob.object:get_pos() then c.mob.object:remove() end
end

local function case_step(dtime)
	c.t = c.t + dtime
	local ent = c.mob
	local pos = ent.object:get_pos()
	if not pos then
		log(c.name .. " mob gone")
		finish_case()
		return true
	end
	local d = hdist(pos, c.home)
	local evading = ent.temp and ent.temp.grug_evading ~= nil
	-- The target walks away and keeps moving between `near` and `far`.
	if c.target and c.target:get_pos() then
		c.tx = c.tx + c.dir * c.speed * dtime
		if c.tx > c.home.x + c.far then c.dir = -1 end
		if c.tx < c.home.x + c.near then c.dir = 1 end
		c.target:set_pos({x = c.tx, y = ground(math.floor(c.tx + 0.5), c.home.z, site.h),
			z = c.home.z})
	end
	if not c.drop_t and c.t > 2 and ent.attack == nil then
		c.drop_t = c.t
		log(("%s target dropped at t=%.1f, %.1f nodes from home"):format(c.name, c.t, d))
	end
	-- The leash reset is the one that heals (the stand-in's hit is not healed
	-- by anything else within the probe's time).
	if not c.reset_t and c.t > 2 and ent.health == ent.hp_max then
		c.reset_t, c.reset_dist, c.reset_hp = c.t, d, ent.health
		log(("%s reset at t=%.1f, %.1f nodes from home, evading=%s, hp %s/%s"):format(c.name,
			c.t, d, tostring(evading), tostring(ent.health), tostring(ent.hp_max)))
		if c.target then c.target:remove(); c.target = nil end
	end
	if evading and not c.evaded then
		c.evaded, c.evade_start = true, c.t
	end
	if c.evaded and not evading and not c.evade_end_dist then
		c.evade_end_dist, c.evade_len = d, c.t - c.evade_start
		log(("%s evade ended at t=%.1f, %.1f nodes from home"):format(c.name, c.t, d))
	end
	if c.evade_end_dist then
		c.after_min = math.min(c.after_min or d, d)
	end
	c.log_t = c.log_t + dtime
	if c.log_t >= 1 then
		c.log_t = 0
		log(("%s t=%.0f state=%s attack=%s evading=%s home_dist=%.1f hp=%s/%s"):format(c.name,
			c.t, tostring(ent.state), tostring(ent.attack ~= nil), tostring(evading), d,
			tostring(ent.health), tostring(ent.hp_max)))
	end
	local done
	if c.name == "INSIDE" then
		done = (c.reset_t and c.t > c.reset_t + 8) or c.t > 50
	else
		done = (c.evade_end_dist and c.t > c.evade_start + c.evade_len + 8) or c.t > 90
	end
	if done then
		finish_case()
		return true
	end
	return false
end

local phase, phase_t, total_t = "wait", 0, 0
core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			site = find_site()
			if not site then
				log("RESULT NOSITE")
				phase = "off"
				core.request_shutdown("r36f no site", false, 0)
				return
			end
			log(("site %d,%d h %d zone %s"):format(site.x, site.z, site.h, tostring(site.zone)))
			core.set_timeofday(0.5)
			forceload(site)
			phase, phase_t = "emerge", 0
		end
	elseif phase == "emerge" then
		if phase_t > 4 and (emerge_done or phase_t > 90) then
			phase = begin_case() and "case" or "end"
		end
	elseif phase == "case" then
		if case_step(dtime) then
			phase = begin_case() and "case" or "end"
		end
	elseif phase == "end" then
		local ok = #results == #cases
		for _, r in ipairs(results) do ok = ok and r end
		log(ok and "RESULT PASS" or "RESULT FAIL")
		phase = "off"
		core.request_shutdown("r36f probe done", false, 0)
	end
end)
