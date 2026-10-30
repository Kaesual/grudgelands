-- Disposable Round 67 WORLD probe (tools/r67_world/run.sh). Never shipped.
--
-- Ruling 26 (wide mobs, round67-plan.md §2 "Spiders") and ruling 25 (the
-- nametags), measured on one seed:
--   SOCKETS  every registered settlement's sockets by role: the idle and work
--            residents (the carriers ruling 25 removes) and no quest giver on
--            such a socket (its marker rides on the carrier);
--   CAVES    a cave volume under the land 400+ nodes from the first start,
--            generated and force-loaded, a stand-in anchor that answers
--            core.is_player 40 nodes above it (mobs_redo's count_mobs wants a
--            player in range; it is out of every mob's sight), and the real
--            underground spawn ABM. BEFORE window: the room check of the
--            wide mobs (grug_mobs.spawn_room_refused) only records its
--            verdict; AFTER window: it refuses. Every wide mob the ABM spawns
--            is checked 3 s later (grug_mobs.mob_stuck): a free one is
--            removed by the probe to keep the row's cap open; a stuck one
--            gets the navigation's give-up (grug_mobs.give_up_target), so
--            the real stuck cleanup removes it (nobody is connected, so
--            nobody watches). The elite/rare re-check counts its fallbacks.
--   FLOORS   the same cave volume read node by node: for each wide mob with
--            an underground row, the spawn spots of its row (stone or
--            stratum under a node where mobs_redo's one-column check passes)
--            and how many of them the room check keeps;
--   TOWN     the first start settlement force-loaded until its NPCs stand:
--            per socket role, how many NPCs and how many carry a nametag
--            carrier; the critters seen in the caves likewise.
-- Every line carries "[r67world]"; the probe ends the server when done.
local P = "[r67world] "
local function log(s) core.log("action", P .. s) end
local WINDOW = tonumber(core.settings:get("grug_r67_window") or "") or 75
local CHECK_AFTER = 3

-- ------------------------------------------------------------ the anchor
core.register_entity("grug_probe_r67_world:anchor", {
	initial_properties = {physical = false, pointable = false, static_save = false,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {0, 0, 0, 0, 0, 0}},
})
local anchor
local orig_is_player = core.is_player
core.is_player = function(object)
	if anchor and object == anchor then return true end
	return orig_is_player(object)
end

-- ------------------------------------------------------------ wrappers
local window = "off"
local attempt -- the last room verdict: {name, x, y, z, would}
local stats = {} -- window -> name -> {asked, would, refused, spawned, stuck, would_stuck}
local function row(w, name)
	stats[w] = stats[w] or {}
	local r = stats[w][name]
	if not r then
		r = {asked = 0, would = 0, refused = 0, spawned = 0, stuck = 0}
		stats[w][name] = r
	end
	return r
end
local pending = {} -- {ent, window, at, would}
local total_t = 0
local scale = {calls = 0, fallbacks = 0}
local gave_up = 0

core.register_on_mods_loaded(function()
	local refused = grug_mobs.spawn_room_refused
	grug_mobs.spawn_room_refused = function(name, pos)
		local verdict = refused(name, pos)
		local ent = core.registered_entities[name]
		local box = ent and ent.base_colbox
		local wide = box and (box[4] - box[1] > 1 or box[6] - box[3] > 1)
		if wide and window ~= "off" then
			local r = row(window, name)
			r.asked = r.asked + 1
			if verdict then r.would = r.would + 1 end
			attempt = {name = name, x = pos.x, z = pos.z, would = verdict}
			if window == "before" then return false end
			if verdict then r.refused = r.refused + 1 end
		end
		return verdict
	end
	local add = core.add_entity
	core.add_entity = function(pos, name, staticdata)
		local object = add(pos, name, staticdata)
		if object and attempt and staticdata == nil and name == attempt.name and
				pos.x == attempt.x and pos.z == attempt.z then
			local ent = object:get_luaentity()
			if ent then
				local r = row(window, name)
				r.spawned = r.spawned + 1
				pending[#pending + 1] = {ent = ent, window = window, at = total_t,
					would = attempt.would}
			end
			attempt = nil
		end
		return object
	end
	local tier_scale = grug_mobs.tier_scale
	grug_mobs.tier_scale = function(self, current, wanted)
		local s = tier_scale(self, current, wanted)
		if wanted > current then
			scale.calls = scale.calls + 1
			if s ~= wanted then
				scale.fallbacks = scale.fallbacks + 1
				log(("SCALE fallback %s %s at %s"):format(self.name, tostring(self._grug_tier),
					core.pos_to_string(vector.round(self.object:get_pos()))))
			end
		end
		return s
	end
end)

local function check_pending()
	local keep = {}
	for _, p in ipairs(pending) do
		local ent = p.ent
		local pos = ent.object and ent.object:get_pos()
		if not pos then
			-- gone already (removed by the cleanup or otherwise)
		elseif total_t - p.at < CHECK_AFTER then
			keep[#keep + 1] = p
		else
			local r = row(p.window, ent.name)
			if grug_mobs.mob_stuck(ent) then
				r.stuck = r.stuck + 1
				log(("STUCK %s window %s at %s (room check said %s)"):format(ent.name,
					p.window, core.pos_to_string(vector.round(pos)),
					p.would and "refuse" or "fits"))
				gave_up = gave_up + 1
				grug_mobs.give_up_target(ent)
			else
				ent.object:remove()
			end
		end
	end
	pending = keep
end

-- ------------------------------------------------------------ sites
local town, caves, emerge_left = nil, nil, 0
local function forceload(minp, maxp)
	for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
			for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	emerge_left = emerge_left + 1
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining == 0 then emerge_left = emerge_left - 1 end
	end)
end

local function socket_census()
	local settlements = grug_core.settlement_socket_settlements()
	local plain, total, quest_bad = 0, 0, 0
	local sample
	for _, s in ipairs(settlements) do
		local by = {}
		for _, socket in ipairs(grug_core.settlement_sockets_at(s.key)) do
			by[socket.role] = (by[socket.role] or 0) + 1
			total = total + 1
			if socket.role == "idle" or socket.role == "work" then
				plain = plain + 1
				if grug_quests.npc_by_socket[s.key .. "/" .. socket.id] then
					quest_bad = quest_bad + 1
					log("CHECK FAIL quest giver on " .. socket.role .. " socket " ..
						s.key .. "/" .. socket.id)
				end
			end
		end
		if not sample and s.race_id == "human" then sample = s.key end
		if s.key == sample or s.key == "highcourt" then
			local rows = {}
			for role, n in pairs(by) do rows[#rows + 1] = role .. "=" .. n end
			table.sort(rows)
			log(("SOCKETS %s: %s"):format(s.key, table.concat(rows, " ")))
		end
	end
	log(("SOCKETS all %d settlements: %d sockets, %d idle/work (one carrier each before " ..
		"Round 67), quest givers on idle/work sockets: %d"):format(#settlements, total, plain, quest_bad))
	return quest_bad == 0, sample
end

-- Every spot the row's matched node offers (a stone or stratum node), the
-- old rule (the one-column check: the nodes above up to the body's height
-- not walkable) and the new one on top (grug_mobs.spawn_room_refused).
local CENSUS_MOBS = {"grug_mobs:giant_spider", "grug_mobs:giant_rat", "grug_mobs:spiderling"}
local function floor_census(minp, maxp)
	local hosts = {}
	local function host(name)
		local h = hosts[name]
		if h == nil then
			h = name == "default:stone" or core.get_item_group(name, "grug_stratum") > 0
			hosts[name] = h
		end
		return h
	end
	local walkable = {}
	local function solid(name)
		local w = walkable[name]
		if w == nil then
			local def = core.registered_nodes[name]
			w = not def or def.walkable ~= false
			walkable[name] = w
		end
		return w
	end
	local heights = {}
	for _, name in ipairs(CENSUS_MOBS) do
		local box = core.registered_entities[name].base_colbox
		heights[name] = math.floor(math.max(0, box[5] - box[2]))
	end
	local old, kept = {}, {}
	for _, name in ipairs(CENSUS_MOBS) do old[name], kept[name] = 0, 0 end
	local get = core.get_node
	for x = minp.x + 2, maxp.x - 2 do
		for z = minp.z + 2, maxp.z - 2 do
			for y = minp.y + 1, maxp.y - 4 do
				local pos = {x = x, y = y, z = z}
				if host(get(pos).name) and not solid(get({x = x, y = y + 1, z = z}).name) then
					for _, name in ipairs(CENSUS_MOBS) do
						local free = true
						for n = 2, heights[name] + 1 do
							if solid(get({x = x, y = y + n, z = z}).name) then free = false break end
						end
						if free then
							old[name] = old[name] + 1
							if not grug_mobs.spawn_room_refused(name, pos) then
								kept[name] = kept[name] + 1
							end
						end
					end
				end
			end
		end
	end
	for _, name in ipairs(CENSUS_MOBS) do
		log(("FLOORS %s: %d spawn spots by the one-column check, %d with room (%.1f %%)"):format(
			name, old[name], kept[name], old[name] > 0 and 100 * kept[name] / old[name] or 0))
	end
end

local function cave_air(minp, maxp)
	return #core.find_nodes_in_area(minp, maxp, {"air"})
end

-- ------------------------------------------------------------ census
local function town_census()
	local anchor_pos = grug_core.settlement_socket_anchor(town.key)
	local by = {}
	for _, object in ipairs(core.get_objects_inside_radius(anchor_pos, 120)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_start == town.key and ent._grug_socket_role then
			local role = ent._grug_socket_role
			local r = by[role] or {npcs = 0, tagged = 0}
			by[role] = r
			r.npcs = r.npcs + 1
			local carrier = ent.temp and ent.temp.grug_tag_carrier
			if carrier and carrier:is_valid() then r.tagged = r.tagged + 1 end
		end
	end
	local rows, plain_tagged, plain, others, others_tagged = {}, 0, 0, 0, 0
	for role, r in pairs(by) do
		rows[#rows + 1] = ("%s=%d/%d"):format(role, r.tagged, r.npcs)
		if role == "idle" or role == "work" then
			plain, plain_tagged = plain + r.npcs, plain_tagged + r.tagged
		else
			others, others_tagged = others + r.npcs, others_tagged + r.tagged
		end
	end
	table.sort(rows)
	log(("TOWN %s NPCs by role (tagged/standing): %s"):format(town.key, table.concat(rows, " ")))
	log(("TOWN %s: %d idle/work residents, %d with a carrier; %d other NPCs, %d with a carrier"):format(
		town.key, plain, plain_tagged, others, others_tagged))
	return plain, plain_tagged, others, others_tagged
end

local critters = {seen = {}, tagged = 0, n = 0}
local function critter_census()
	if not caves then return end
	local c = caves.center
	for _, object in ipairs(core.get_objects_inside_radius(c, 72)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_disposition == "critter" and not critters.seen[ent] then
			critters.seen[ent] = true
			critters.n = critters.n + 1
			local carrier = ent.temp and ent.temp.grug_tag_carrier
			if carrier and carrier:is_valid() then critters.tagged = critters.tagged + 1 end
		end
	end
end

-- ------------------------------------------------------------ main
local phase, phase_t = "wait", 0
local census_ok = true
local function set_phase(p)
	phase, phase_t = p, 0
	log("phase -> " .. p .. " at " .. ("%.1f"):format(total_t))
end

local function finish()
	critter_census()
	local plain, plain_tagged, others, others_tagged = town_census()
	local ok = census_ok and plain_tagged == 0 and (others == 0 or others_tagged > 0)
	for _, w in ipairs({"before", "after"}) do
		local names = {}
		for name in pairs(stats[w] or {}) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local r = stats[w][name]
			log(("SPAWN %s %s: room asked %d, would refuse %d, refused %d, spawned %d, stuck %d"):format(
				w, name, r.asked, r.would, r.refused, r.spawned, r.stuck))
			if w == "after" and r.stuck > 0 then ok = false end
		end
	end
	log(("STUCK cleanup: give-ups by the probe %d, flagged %d, removed %d"):format(gave_up,
		grug_mobs.stuck_stats.flagged, grug_mobs.stuck_stats.removed))
	log(("SCALE elite/rare growth checks %d, fallbacks to the base size %d"):format(
		scale.calls, scale.fallbacks))
	log(("CRITTERS seen in the caves %d, with a carrier %d"):format(critters.n, critters.tagged))
	if critters.tagged > 0 then ok = false end
	log(ok and "RESULT PASS" or "RESULT FAIL")
	set_phase("off")
	core.request_shutdown("r67world probe done", false, 0)
end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			local sample
			census_ok, sample = socket_census()
			local a = grug_core.settlement_socket_anchor(sample)
			town = {key = sample, anchor = a}
			forceload({x = a.x - 64, y = a.y - 16, z = a.z - 64}, {x = a.x + 64, y = a.y + 24, z = a.z + 64})
			-- Cave candidates: land columns 400-700 nodes from the town.
			local candidates = {}
			for _, d in ipairs({400, 550, 700}) do
				for _, dir in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local x, z = math.floor(a.x + dir[1] * d), math.floor(a.z + dir[2] * d)
					if grug_zones.water_class_at(x, z) == "land" and #candidates < 2 then
						candidates[#candidates + 1] = {x = x, z = z}
					end
				end
			end
			caves = {candidates = candidates}
			for _, c in ipairs(candidates) do
				c.minp = {x = c.x - 40, y = -112, z = c.z - 40}
				c.maxp = {x = c.x + 40, y = -49, z = c.z + 40}
				forceload(c.minp, c.maxp)
			end
			log(("town %s at %s; %d cave candidates"):format(town.key,
				core.pos_to_string(a), #candidates))
			set_phase("emerge")
		end
	elseif phase == "emerge" then
		if phase_t > 5 and (emerge_left <= 0 or phase_t > 150) then
			local best, best_air
			for _, c in ipairs(caves.candidates) do
				local air = cave_air(c.minp, c.maxp)
				log(("cave candidate %d,%d: %d air nodes in y -112..-49"):format(c.x, c.z, air))
				if not best_air or air > best_air then best, best_air = c, air end
			end
			if not best then
				log("RESULT NOSITE")
				core.request_shutdown("r67world no site", false, 0)
				set_phase("off")
				return
			end
			caves.center = {x = best.x, y = -80, z = best.z}
			floor_census(best.minp, best.maxp)
			core.forceload_block({x = best.x, y = -9, z = best.z}, true, -1)
			anchor = core.add_entity({x = best.x, y = -9, z = best.z}, "grug_probe_r67_world:anchor")
			log(("caves at %d,%d (zone %s); anchor %s; window %d s each"):format(best.x, best.z,
				tostring(grug_zones.id_at(best.x, best.z)), tostring(anchor ~= nil), WINDOW))
			window = "before"
			set_phase("before")
		end
	elseif phase == "before" or phase == "after" then
		check_pending()
		if phase_t >= WINDOW then
			critter_census()
			if phase == "before" then
				window = "after"
				set_phase("after")
			else
				window = "off"
				set_phase("drain")
			end
		end
	elseif phase == "drain" then
		check_pending()
		if phase_t > CHECK_AFTER + 2 then finish() end
	end
end)
