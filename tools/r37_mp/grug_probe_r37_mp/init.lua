-- Disposable Round 37 lane MP probe (tools/r37_mp/engine.sh). Never shipped.
--
-- Two boots of one world (KEEP=1, then ROOT=), only around Grimtusk's first
-- route point (forceloaded, nothing else):
--   BOOT 1  a stand-in player there (the rare spawner's seam
--           grug_mobs.rare_players, and the unload despawn decision's player
--           list while no real player is connected); six wild boars around
--           it; Grimtusk spawns. Then the server shuts down: the stand-in
--           leaves in the shutdown callbacks, before the engine saves the
--           objects, exactly as the engine kicks real players first.
--   BOOT 2  AWAY     the stand-in back, the rare's block not active yet: no
--                    second Grimtusk, the record says alive;
--           RESTART  the area forceloaded again: the six boars and the one
--                    Grimtusk (same generation) are there;
--           DEDUPE   a second copy of the current generation and a copy of
--                    an older one, added through add_entity, remove
--                    themselves;
--           LOST     Grimtusk removed without a death (as an admin would):
--                    about a minute later one new Grimtusk of the next
--                    generation stands, never two.
-- A stand-in has no ObjectRef, so mobs:add_mob's "a player in range" test
-- (count_mobs) cannot see it: the probe stands in add_mob's placement for it.
-- Grimtusk's route is pinned to its first point so the run stays in one
-- forceloaded area. Every line carries "[r37mp]"; the probe ends the server.
local P = "[r37mp] "
local function log(s) core.log("action", P .. s) end
local probe_storage = core.get_mod_storage()
local boot = probe_storage:get_int("boot") + 1
probe_storage:set_int("boot", boot)

local WILD = 6
local RARE = "grimtusk"
local phase, phase_t, total_t = "wait", 0, 0
local spot, standin, emerge_done
local results = {}
local function result(name, ok, text)
	results[#results + 1] = {name = name, ok = ok}
	log(("%s %s: %s"):format(ok and "OK" or "FAIL", name, text))
end
local function set_phase(p)
	phase, phase_t = p, 0
	log("boot " .. boot .. " phase -> " .. p)
end

local function make_standin(pos)
	standin = {
		get_pos = function() return {x = pos.x, y = pos.y, z = pos.z} end,
		get_player_name = function() return "r37mp_standin" end,
	}
end

core.register_on_mods_loaded(function()
	grug_mobs.rare_players = function() return standin and {standin} or {} end
	local decide = mobs.despawn_distance_decision
	mobs.despawn_distance_decision = function(self, pos, players, roll)
		if standin and (not players or #players == 0) then players = {standin} end
		return decide(self, pos, players, roll)
	end
	mobs.add_mob = function(_, pos, def)
		local object = core.add_entity(pos, def.name, def._grug_authored and
			core.serialize({_grug_authored = true}) or nil)
		return object and object:get_luaentity()
	end
	local spec = grug_mobs.registered_rares[RARE]
	spec.route = {spec.route[1]}
end)
-- The engine kicks the players after the shutdown callbacks and before it
-- saves the objects; the stand-in leaves at the same point.
core.register_on_shutdown(function() standin = nil end)

local function walkable(node)
	local def = node and core.registered_nodes[node.name]
	return def and def.walkable
end
local function ground(x, z, y0)
	for y = y0 + 16, y0 - 16, -1 do
		local here = core.get_node({x = x, y = y, z = z})
		local above = core.get_node({x = x, y = y + 1, z = z})
		if walkable(here) and above.name == "air" then return {x = x, y = y + 1, z = z} end
	end
end

local function forceload(a)
	emerge_done = false
	for bx = math.floor((a.x - 32) / 16), math.floor((a.x + 32) / 16) do
		for bz = math.floor((a.z - 32) / 16), math.floor((a.z + 32) / 16) do
			for by = math.floor((a.y - 16) / 16), math.floor((a.y + 16) / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	core.emerge_area({x = a.x - 40, y = a.y - 24, z = a.z - 40},
		{x = a.x + 40, y = a.y + 24, z = a.z + 40}, function(_, _, remaining)
			if remaining == 0 then emerge_done = true end
		end)
end

local function census()
	local wild, rares, gens = 0, 0, {}
	for _, obj in ipairs(core.get_objects_inside_radius(spot, 80)) do
		local ent = obj:get_luaentity()
		if ent and (ent.health or 0) > 0 then
			if ent._grug_probe_wild then wild = wild + 1 end
			if ent._grug_rare_id == RARE then
				rares = rares + 1
				gens[#gens + 1] = tostring(ent._grug_live_gen)
			end
		end
	end
	return wild, rares, table.concat(gens, ",")
end
local function record()
	local st = grug_mobs.storage
	return st:get_int("rare_alive:" .. RARE), st:get_int("live_gen:rare:" .. RARE),
		st:get_string("live_pos:rare:" .. RARE)
end
local function find_rare()
	for _, obj in ipairs(core.get_objects_inside_radius(spot, 80)) do
		local ent = obj:get_luaentity()
		if ent and ent._grug_rare_id == RARE and (ent.health or 0) > 0 then return ent end
	end
end

local function finish()
	local ok = #results > 0
	for _, r in ipairs(results) do ok = ok and r.ok end
	log(ok and "RESULT PASS" or "RESULT FAIL")
	set_phase("off")
	core.request_shutdown("r37mp probe done", false, 0)
end

local gen_before, injected
core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "off" then return end
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			spot = vector.new(grug_mobs.registered_rares[RARE].route[1])
			log(("boot %d: %s route point %s"):format(boot, RARE, core.pos_to_string(spot)))
			if boot == 1 then
				forceload(spot)
				set_phase("emerge")
			else
				local s = core.string_to_pos(probe_storage:get_string("standin"))
				make_standin(s)
				local alive, gen = record()
				gen_before = gen
				log(("boot 2 record: alive %d, generation %d, last place %s"):format(alive, gen,
					select(3, record())))
				set_phase("away")
			end
		end
	elseif phase == "emerge" then
		if phase_t > 4 and (emerge_done or phase_t > 120) then
			local s = ground(spot.x + 6, spot.z, spot.y) or vector.offset(spot, 6, 0, 0)
			make_standin(s)
			probe_storage:set_string("standin", core.pos_to_string(s))
			local placed = 0
			for i = 1, WILD do
				local a = i * math.pi * 2 / WILD
				local g = ground(math.floor(s.x + math.cos(a) * 12), math.floor(s.z + math.sin(a) * 12), s.y)
				local obj = g and core.add_entity(g, "grug_mobs:boar")
				local ent = obj and obj:get_luaentity()
				if ent then
					ent._grug_probe_wild = true
					grug_mobs.place_on_ground(obj, g)
					placed = placed + 1
				end
			end
			log(("boot 1: stand-in at %s, %d wild boars placed"):format(core.pos_to_string(s), placed))
			set_phase("spawn")
		end
	elseif phase == "spawn" then
		if find_rare() or phase_t > 45 then
			set_phase("settle")
		end
	elseif phase == "settle" then
		if phase_t > 10 then
			local wild, rares, gens = census()
			local alive, gen, last = record()
			probe_storage:set_int("wild", wild)
			log(("BOOT1 wild %d, Grimtusk %d (generations %s), record alive %d generation %d at %s")
				:format(wild, rares, gens, alive, gen, last))
			result("boot 1", wild == WILD and rares == 1 and alive == 1,
				("%d of %d wild boars, %d Grimtusk"):format(wild, WILD, rares))
			finish()
		end
	elseif phase == "away" then
		if phase_t > 20 then
			local _, rares = census()
			local alive, gen = record()
			result("away", rares == 0 and alive == 1 and gen == gen_before,
				("rare's block inactive, stand-in near: %d Grimtusk active, alive %d, generation %d -> %d")
				:format(rares, alive, gen_before, gen))
			forceload(spot)
			local live = grug_mobs.liveness
			local last = live and live.last_pos("rare:" .. RARE)
			if last and vector.distance(last, spot) > 24 then forceload(last) end
			set_phase("load")
		end
	elseif phase == "load" then
		if phase_t > 5 and (emerge_done or phase_t > 60) and phase_t > 8 then
			local wild, rares, gens = census()
			local was = probe_storage:get_int("wild")
			log(("BOOT2 wild %d (boot 1: %d), Grimtusk %d (generations %s)"):format(wild, was, rares, gens))
			result("restart keeps the mobs", wild == was and was == WILD,
				("%d of the %d wild boars near the stand-in are back"):format(wild, was))
			result("restart one rare", rares == 1 and gens == tostring(gen_before),
				("%d Grimtusk, generations %s, recorded %d"):format(rares, gens, gen_before))
			local rare = find_rare()
			if rare then
				local p = rare.object:get_pos()
				for _, gen in ipairs({gen_before, gen_before - 1}) do
					core.add_entity(vector.offset(p, 2, 0, 2), "grug_mobs:boar", core.serialize({
						_grug_rare_id = RARE, _grug_live_key = "rare:" .. RARE,
						_grug_live_gen = gen, _grug_authored = true, lifetimer = 30000,
						description = "Grimtusk"}))
				end
				injected = true
			end
			set_phase("dedupe")
		end
	elseif phase == "dedupe" then
		if phase_t > 2 then
			local _, rares, gens = census()
			result("dedupe", injected and rares == 1 and gens == tostring(gen_before),
				("after a current and an older copy were added: %d Grimtusk (generations %s)")
				:format(rares, gens))
			local rare = find_rare()
			if rare then rare.object:remove() end
			set_phase("lost")
		end
	elseif phase == "lost" then
		local _, rares, gens = census()
		if rares > 1 then
			result("lost", false, ("%d Grimtusk at once (generations %s)"):format(rares, gens))
			finish()
		elseif rares == 1 or phase_t > 110 then
			local alive, gen = record()
			result("lost", rares == 1 and gens == tostring(gen_before + 1) and alive == 1,
				("removed without a death: after %.0f s %d Grimtusk, generation %s (was %d)")
				:format(phase_t, rares, gens, gen_before))
			finish()
		end
	end
end)
