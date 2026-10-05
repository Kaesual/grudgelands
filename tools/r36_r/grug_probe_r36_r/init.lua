-- Disposable Round 36 lane R probe (tools/r36_r/engine.sh). Never shipped.
--
-- At the rift site only (its anchor's area forceloaded and emerged, nothing
-- else): a stand-in player (grug_mobs.rift_players seam) comes within 30
-- nodes, then
--   CRACK   the crack is written once (two void nodes per cell, all the
--           site's POI core), and a void node put back by hand is not
--           rewritten (the storage mark governs);
--   BOSS    the boss appears on the site's centre: level, tier, HP, its
--           encounter id, not saved with the map;
--   VOID    a level-60 mob dropped into the crack loses HP to the void's
--           damage per second;
--   RESET   the boss, fighting a stand-in target 30 nodes from home and
--           reset, heals and runs home untouchable, and arrives;
--   DEATH   killed, its return is booked 300 s ahead and it is not back
--           within the probe's wait;
--   PARTICLES the rift's spawner and particle counters over 10 s.
-- Every line carries "[r36r]"; the probe ends the server when done.
local P = "[r36r] "
local function log(s) core.log("action", P .. s) end

local VOID = "grug_mobs:rift_void"
local phase, phase_t, total_t = "wait", 0, 0
local s, emerge_done, standin, boss, target, mob
local results = {}
local void_sets = 0
local function result(name, ok, text)
	results[#results + 1] = {name = name, ok = ok}
	log(("%s %s: %s"):format(ok and "OK" or "FAIL", name, text))
end
local function set_phase(p)
	phase, phase_t = p, 0
	log("phase -> " .. p)
end

core.register_entity("grug_probe_r36_r:target", {
	initial_properties = {
		physical = false, pointable = true, static_save = false, hp_max = 100,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

core.register_on_mods_loaded(function()
	local set_node = core.set_node
	core.set_node = function(pos, node)
		if node and node.name == VOID then void_sets = void_sets + 1 end
		return set_node(pos, node)
	end
	grug_mobs.rift_players = function()
		return standin and {standin} or {}
	end
end)

local function forceload(a)
	for bx = math.floor((a.x - 40) / 16), math.floor((a.x + 40) / 16) do
		for bz = math.floor((a.z - 40) / 16), math.floor((a.z + 40) / 16) do
			for by = math.floor((a.y - 24) / 16), math.floor((a.y + 24) / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	core.emerge_area({x = a.x - 48, y = a.y - 32, z = a.z - 48},
		{x = a.x + 48, y = a.y + 32, z = a.z + 48}, function(_, _, remaining)
			if remaining == 0 then emerge_done = true end
		end)
end

local function voids_in_box()
	local box = grug_mobs.rift_rules.box(s.art, s.anchor)
	local list = core.find_nodes_in_area({x = box.min_x - 2, y = box.min_y, z = box.min_z - 2},
		{x = box.max_x + 2, y = box.max_y, z = box.max_z + 2}, {VOID})
	local inside, poi = 0, 0
	for _, p in ipairs(list) do
		if p.x >= box.min_x and p.x <= box.max_x and p.z >= box.min_z and p.z <= box.max_z then
			inside = inside + 1
		end
		if grug_core.world_feature_at(p) == "poi" then poi = poi + 1 end
	end
	return #list, inside, poi, list
end

local function find_boss()
	for _, obj in ipairs(core.get_objects_inside_radius(s.anchor, 80)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "grug_mobs:rift_boss" and (ent.health or 0) > 0 then return ent end
	end
end

local function finish()
	local ok = #results > 0
	for _, r in ipairs(results) do ok = ok and r.ok end
	log(ok and "RESULT PASS" or "RESULT FAIL")
	set_phase("off")
	core.request_shutdown("r36r probe done", false, 0)
end

local evade_started, death_due
core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			s = grug_mobs.rift_site()
			if not s then
				log("RESULT NOSITE")
				set_phase("off")
				core.request_shutdown("r36r no site", false, 0)
				return
			end
			log(("site %s (%s) anchor %s, %d crack cells"):format(s.key, s.art.label,
				core.pos_to_string(s.anchor), #s.cells))
			forceload(s.anchor)
			set_phase("emerge")
		end
	elseif phase == "emerge" then
		if phase_t > 4 and (emerge_done or phase_t > 120) then
			local a = s.anchor
			for index = 1, 3 do
				local c = s.cells[index]
				local names = {}
				for dy = -2, 2 do
					names[#names + 1] = core.get_node({x = a.x + c[1], y = a.y + dy, z = a.z + c[2]}).name
				end
				log(("cell %d,%d y-2..y+2: %s"):format(c[1], c[2], table.concat(names, " ")))
			end
			local centre = {}
			for dy = -1, 2 do centre[#centre + 1] = core.get_node({x = a.x, y = a.y + dy, z = a.z}).name end
			log("centre y-1..y+2: " .. table.concat(centre, " ") .. ", feature " ..
				tostring(grug_core.world_feature_at(a)))
			local n = voids_in_box()
			result("before", n == 0 and grug_mobs.storage:get_string("rift_crack:" .. s.key) == "",
				("%d void nodes, no mark before anyone came near"):format(n))
			set_phase("idle")
		end
	elseif phase == "idle" then
		-- Nobody near for 5 s: nothing happens.
		if phase_t > 5 then
			local n = voids_in_box()
			result("nobody near", n == 0 and not find_boss(), ("%d void nodes, boss %s"):format(n,
				tostring(find_boss() ~= nil)))
			local p = {x = s.anchor.x + 30, y = s.anchor.y + 1, z = s.anchor.z}
			standin = {get_pos = function() return {x = p.x, y = p.y, z = p.z} end,
				get_player_name = function() return "r36r_standin" end}
			set_phase("near")
		end
	elseif phase == "near" then
		if phase_t > 4 then
			local n, inside, poi = voids_in_box()
			local mark = grug_mobs.storage:get_string("rift_crack:" .. s.key)
			result("crack", n > 0 and n == void_sets and n == inside and n == poi and
				tostring(n) == mark and n == 2 * #s.cells,
				("%d void nodes (%d cells x 2 = %d), %d set_node calls, %d inside the box, %d POI core, mark %s")
				:format(n, #s.cells, 2 * #s.cells, void_sets, inside, poi, mark))
			boss = find_boss()
			if boss then
				local bp = boss.object:get_pos()
				result("boss", boss._grug_level == 60 and boss._grug_tier == "elite" and
					boss._grug_boss_id == "rift:" .. s.key and
					boss.object:get_properties().static_save == false,
					("level %s %s, HP %s/%s, id %s, at %s (%.1f from the centre), static_save %s")
					:format(tostring(boss._grug_level), tostring(boss._grug_tier), tostring(boss.health),
					tostring(boss.hp_max), tostring(boss._grug_boss_id), core.pos_to_string(vector.round(bp)),
					vector.distance({x = bp.x, y = 0, z = bp.z}, {x = s.anchor.x, y = 0, z = s.anchor.z}),
					tostring(boss.object:get_properties().static_save)))
			else
				result("boss", false, "no boss")
			end
			-- Put one void node back: the mark, not the world, decides.
			local c = s.cells[1]
			core.swap_node({x = s.anchor.x + c[1], y = s.anchor.y, z = s.anchor.z + c[2]},
				{name = "default:dirt"})
			set_phase("particles")
		end
	elseif phase == "particles" then
		if phase_t > 10 then
			local st = grug_mobs.rift_stats
			log(("PARTICLES %d spawners, %d particles in %.0f s for one near player " ..
				"(about %.0f alive at once per player, plus the boss's bursts)"):format(st.spawners,
				st.particles, total_t, grug_mobs.rift_rules.particles_alive()))
			local n = voids_in_box()
			result("written once", n == 2 * #s.cells - 1 and void_sets == 2 * #s.cells,
				("%d void nodes after one was put back, %d set_node calls in all"):format(n, void_sets))
			-- VOID: a level-60 mob in the crack.
			local c = s.cells[math.floor(#s.cells / 2)]
			local pos = {x = s.anchor.x + c[1], y = s.anchor.y - 1, z = s.anchor.z + c[2]}
			local obj = core.add_entity(pos, "grug_mobs:large_rat")
			mob = obj and obj:get_luaentity()
			if mob then
				grug_mobs.relevel(mob, 60)
				log(("VOID a level-60 rat at %s in %s"):format(core.pos_to_string(pos),
					core.get_node(pos).name))
			end
			set_phase("void")
		end
	elseif phase == "void" then
		if mob and mob.object then grug_mobs.root(mob, 1) end
		-- Its HP after the first tick's level assignment.
		if mob and not mob._probe_hp and phase_t > 0.5 then
			mob._probe_hp = mob.health
			log(("VOID HP %s/%s, standing in %s"):format(tostring(mob.health), tostring(mob.hp_max),
				tostring(mob.standing_in)))
		end
		if phase_t > 4 then
			local hp = mob and mob.object and mob.object:get_pos() and mob.health
			result("void damage", mob ~= nil and hp ~= nil and hp < mob._probe_hp,
				("HP %s -> %s after 3.5 s in the void (%s per second)"):format(tostring(mob and mob._probe_hp),
				tostring(hp), tostring(core.registered_nodes[VOID].damage_per_second)))
			if mob and mob.object then mob.object:remove() end
			-- RESET: drag the boss 30 nodes from home while it fights.
			boss = find_boss() or boss
			local home = boss._grug_home
			target = core.add_entity({x = home.x + 31, y = home.y + 1, z = home.z}, "grug_probe_r36_r:target")
			grug_mobs.place_on_ground(boss.object, {x = home.x + 30, y = home.y, z = home.z})
			boss.health = math.floor(boss.hp_max / 2)
			boss:do_attack(target)
			grug_mobs.leash_reset(boss)
			evade_started = total_t
			result("reset", boss.health == boss.hp_max and boss.temp.grug_evading ~= nil and not boss.attack,
				("HP %s/%s, evading %s, target %s"):format(tostring(boss.health), tostring(boss.hp_max),
				tostring(boss.temp.grug_evading ~= nil), tostring(boss.attack)))
			if target then target:remove() end
			set_phase("evade")
		end
	elseif phase == "evade" then
		local home, pos = boss._grug_home, boss.object:get_pos()
		local d = pos and math.sqrt((pos.x - home.x) ^ 2 + (pos.z - home.z) ^ 2) or -1
		if not boss.temp.grug_evading or phase_t > 50 then
			result("run home", not boss.temp.grug_evading and d >= 0 and d <= 5,
				("evade ended after %.1f s at %.1f nodes from home"):format(total_t - evade_started, d))
			-- DEATH.
			boss.health = 1
			local killer = core.add_entity(vector.add(pos, {x = 1, y = 0, z = 0}), "grug_probe_r36_r:target")
			boss.object:punch(killer, 1, {full_punch_interval = 1, damage_groups = {fleshy = 500}}, nil)
			if killer then killer:remove() end
			death_due = tonumber(grug_mobs.storage:get_string("rift_boss_due:" .. s.key))
			result("death", death_due ~= nil and math.abs(death_due - (os.time() + 300)) <= 2,
				("return booked %s s ahead"):format(tostring(death_due and death_due - os.time())))
			set_phase("after")
		end
	elseif phase == "after" then
		if phase_t > 15 then
			result("no early return", find_boss() == nil, "no boss 15 s after its death")
			finish()
		end
	end
end)
