-- Disposable 0.49.1 DROP probe (never shipped), staged by
-- tools/r491_drop/repro.sh through tools/luanti_headless.sh. One real client
-- ("grugdrop", with the client mod r491scan) hovers 8 nodes above the
-- waystone of Bannerbreak Warhold (pvp_fortress_throng) and looks down.
--
-- Phase DROPS: WAVES waves of six drops, thrown the way every mob drop is
-- (mobs/api.lua item_drop, grug_mobs/aggro.lua drop_coin_bag,
-- grug_quality's gear hook): core.add_item at about a mob's centre height,
-- then set_velocity({random() - 0.5, 5, random() - 0.5}). Tools only (one per
-- stack, so no two merge). Per drop the server logs its landing (LAND: the
-- horizontal velocity of the last step in the air, which is the velocity the
-- client keeps when the stop is lost, and the landing step's travel, which
-- decides whether the engine sends the stop a second time) and once a second
-- its server position (SRV).
--
-- Phase LEADS (server side only, away from the scanned square): drops against
-- a fortress wall, inside a wall node and on steps, each tracked until it
-- rests (LEAD lines: time to rest, path, force_out pushes, still moving).
--
-- OBJ lines count the objects within 128 nodes (the default
-- active_object_send_range_blocks) and how many of them move.
-- Ends with "[r491drop] shutdown".
local P = "[r491drop] "
local NAME = "grugdrop"
local WAVES = tonumber(core.settings:get("r491drop_waves") or "") or 20
local function log(msg) core.log("action", P .. msg) end
local function now() return core.get_us_time() / 1e6 end

local tracked = {} -- entity -> record
local records = {}
local TOOLS = {}

-- Per-step tracking of the probe's drops (probe only).
core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_tools) do
		if def.description and def.description ~= "" and
				(def.groups or {}).not_in_creative_inventory ~= 1 then
			TOOLS[#TOOLS + 1] = name
		end
	end
	table.sort(TOOLS)
	local item = core.registered_entities["__builtin:item"]
	local step = item.on_step
	item.on_step = function(self, dtime, moveresult, ...)
		-- the engine has already moved the object when on_step runs: the
		-- step's travel is from the previous step's position, and the
		-- velocity read here is the one the last step left (what was sent)
		local rec = tracked[self]
		local vel_before = self.object:get_velocity()
		local result = step(self, dtime, moveresult, ...)
		local pos = self.object:get_pos()
		local before = rec and rec.prev
		if rec then rec.prev = pos and vector.copy(pos) end
		if rec and pos and before then
			local dx, dy, dz = pos.x - before.x, pos.y - before.y, pos.z - before.z
			local d = math.sqrt(dx * dx + dy * dy + dz * dz)
			rec.path = rec.path + d
			if self.force_out and not rec.in_force then rec.force_outs = rec.force_outs + 1 end
			rec.in_force = self.force_out ~= nil
			if moveresult and moveresult.collides and not rec.landed then
				rec.landed = now()
				rec.land_pos = vector.copy(pos)
				-- the velocity the server had sent last (the step before) and the
				-- travel of the landing step itself
				rec.last_air_v = vel_before
				rec.land_d = d
				log(("LAND n=%d kind=%s t=%.2f x=%.3f y=%.3f z=%.3f vx=%.3f vz=%.3f d=%.3f flight=%.2f"):format(
					rec.n, rec.kind, rec.landed, pos.x, pos.y, pos.z, vel_before.x, vel_before.z, d,
					rec.landed - rec.born))
			end
			if d > 0.001 then rec.last_move = now() end
		end
		return result
	end
end)

local function ground_y(x, z, top)
	for y = top, top - 24, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable then return y end
	end
end

local function throw(pos, n, kind, vel)
	local stack = ItemStack(TOOLS[(n - 1) % #TOOLS + 1])
	local obj = core.add_item(pos, stack)
	if not obj then
		log(("NOSPAWN n=%d kind=%s"):format(n, kind))
		return
	end
	obj:set_velocity(vel or {x = math.random() - 0.5, y = 5, z = math.random() - 0.5})
	local ent = obj:get_luaentity()
	local rec = {n = n, kind = kind, ent = ent, born = now(), path = 0, force_outs = 0,
		spawn = vector.copy(pos), prev = vector.copy(pos)}
	tracked[ent] = rec
	records[#records + 1] = rec
	log(("SPAWN n=%d kind=%s t=%.2f x=%.3f y=%.3f z=%.3f"):format(n, kind, rec.born,
		pos.x, pos.y, pos.z))
end

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local state = {phase = "wait", clock = 0, obj_clock = 0, srv_clock = 0}
local site

local function count_objects()
	local all, moving = 0, 0
	for _, obj in ipairs(core.get_objects_inside_radius(site, 128)) do
		all = all + 1
		local v = obj:get_velocity()
		if v and (math.abs(v.x) + math.abs(v.y) + math.abs(v.z)) > 0.05 then moving = moving + 1 end
	end
	log(("OBJ t=%.2f all=%d moving=%d"):format(now(), all, moving))
end

local function log_servers()
	local t = now()
	for _, rec in ipairs(records) do
		local pos = rec.ent.object and rec.ent.object:get_pos()
		if pos and rec.kind == "drop" then
			local v = rec.ent.object:get_velocity()
			log(("SRV t=%.2f n=%d x=%.3f y=%.3f z=%.3f vx=%.3f vy=%.3f vz=%.3f"):format(t, rec.n,
				pos.x, pos.y, pos.z, v.x, v.y, v.z))
		end
	end
end

-- Lead cases: a column next to a wall at least three nodes higher (the low
-- side's top node and the direction to the wall), searched 9-30 nodes from
-- the waystone, outside the scanned square.
local function find_walls(limit)
	local found = {}
	for r = 9, 30 do
		for _, dir in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			for off = -r, r, 3 do
				local x = site.x + dir[1] * r + (dir[1] == 0 and off or 0)
				local z = site.z + dir[2] * r + (dir[2] == 0 and off or 0)
				local g = ground_y(x, z, site.y + 12)
				if g then
					for _, w in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
						local wg = ground_y(x + w[1], z + w[2], site.y + 16)
						if wg and wg >= g + 3 and #found < limit then
							found[#found + 1] = {x = x, z = z, g = g, w = w}
							break
						end
					end
				end
			end
		end
		if #found >= limit then break end
	end
	return found
end

local function find_steps(limit)
	local found = {}
	for r = 9, 30 do
		for off = -r, r, 2 do
			local x, z = site.x + off, site.z - r
			local g = ground_y(x, z, site.y + 12)
			local g2 = g and ground_y(x + 1, z, site.y + 12)
			if g and g2 and math.abs(g2 - g) == 1 and #found < limit then
				found[#found + 1] = {x = x, z = z, g = math.max(g, g2)}
			end
		end
		if #found >= limit then break end
	end
	return found
end

local function lead_cases()
	local n = 1000
	local walls = find_walls(8)
	local steps = find_steps(6)
	log(("LEADS walls=%d steps=%d"):format(#walls, #steps))
	for _, w in ipairs(walls) do
		-- a mob pressed against the wall: centre 0.3 from the face, thrown
		-- toward the wall
		n = n + 1
		throw({x = w.x + w.w[1] * 0.2, y = w.g + 1.4, z = w.z + w.w[2] * 0.2}, n, "wall",
			{x = w.w[1] * 0.5, y = 5, z = w.w[2] * 0.5})
		-- a mob centre inside the wall node itself (a mob pushed into it)
		n = n + 1
		throw({x = w.x + w.w[1], y = w.g + 1.4, z = w.z + w.w[2]}, n, "inside")
	end
	for _, s in ipairs(steps) do
		n = n + 1
		throw({x = s.x + 0.5, y = s.g + 1.4, z = s.z}, n, "step")
	end
end

local function lead_report()
	local t = now()
	for _, rec in ipairs(records) do
		if rec.kind ~= "drop" then
			local pos = rec.ent.object and rec.ent.object:get_pos()
			local v = pos and rec.ent.object:get_velocity()
			local moving = v and (math.abs(v.x) + math.abs(v.y) + math.abs(v.z)) > 0.01
			log(("LEAD n=%d kind=%s rest_after=%s path=%.2f force_outs=%d moving_now=%s final=%s spawn=%s"):format(
				rec.n, rec.kind, rec.last_move and ("%.2f"):format(rec.last_move - rec.born) or "-",
				rec.path, rec.force_outs, tostring(moving), pos and core.pos_to_string(pos, 2) or "gone",
				core.pos_to_string(rec.spawn, 2)))
		end
	end
	local drops, still = 0, 0
	for _, rec in ipairs(records) do
		if rec.kind == "drop" then
			drops = drops + 1
			if rec.last_move and t - rec.last_move < 2 then still = still + 1 end
		end
	end
	log(("DROPS total=%d moved_in_last_2s=%d"):format(drops, still))
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if site then
		state.obj_clock = state.obj_clock + dtime
		if state.obj_clock >= 2 then state.obj_clock = 0; count_objects() end
		state.srv_clock = state.srv_clock + dtime
		if state.srv_clock >= 1 then state.srv_clock = 0; log_servers() end
	end
	if state.clock < 0.5 then return end
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_throng = "Throng"})
			submit(player, {race_orc = "Orc"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		for _, socket in ipairs(grug_core.settlement_sockets_at("pvp_fortress_throng")) do
			if socket.id == "travel_waypoint" and socket.role == "waypoint" then
				site = vector.round(socket.pos)
			end
		end
		if not site then
			log("no fortress waypoint; shutdown")
			core.request_shutdown("r491drop no site", false, 0)
			state.phase = "off"
			return
		end
		log("character complete; fortress waystone at " .. core.pos_to_string(site) ..
			" zone " .. tostring(grug_zones.id_at(site.x, site.z)))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		core.set_timeofday(0.5)
		state.phase = "emerge"
		state.started = now()
		state.pending = true
		core.emerge_area({x = site.x - 40, y = site.y - 12, z = site.z - 40},
			{x = site.x + 40, y = site.y + 24, z = site.z + 40}, function(_, _, remaining)
				if remaining == 0 then state.pending = false end
			end)
	elseif state.phase == "emerge" then
		if state.pending then return end
		log(("emerge done in %.1f s"):format(now() - state.started))
		player:set_pos({x = site.x + 0.5, y = site.y + 8, z = site.z + 0.5})
		player:set_look_vertical(1.5)
		state.phase, state.wave, state.wait = "settle", 0, 0
	elseif state.phase == "settle" then
		state.wait = state.wait + 0.5
		player:set_pos({x = site.x + 0.5, y = site.y + 8, z = site.z + 0.5})
		if state.wait >= 8 then
			state.phase, state.wait = "drops", 0
			log("DROPS begin")
		end
	elseif state.phase == "drops" then
		state.wait = state.wait + 0.5
		if state.wait < 3 then return end
		state.wait = 0
		state.wave = state.wave + 1
		for i = 1, 6 do
			local x = site.x + math.random() * 9 - 4.5
			local z = site.z + math.random() * 9 - 4.5
			local g = ground_y(math.floor(x + 0.5), math.floor(z + 0.5), site.y + 6) or site.y - 1
			throw({x = x, y = g + 1.4, z = z}, (state.wave - 1) * 6 + i, "drop")
		end
		if state.wave >= WAVES then state.phase, state.wait = "after", 0 end
	elseif state.phase == "after" then
		state.wait = state.wait + 0.5
		if state.wait == 12 then lead_cases() end
		if state.wait >= 30 then
			lead_report()
			log("shutdown")
			state.phase = "off"
			core.request_shutdown("r491drop probe done", false, 0)
		end
	end
end)
