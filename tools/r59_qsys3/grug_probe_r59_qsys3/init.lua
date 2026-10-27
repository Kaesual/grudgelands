-- Disposable Round 59 lane QSYS3 probe (tools/r59_qsys3/engine.sh). Never
-- shipped.
--
-- A town place on the running world (quests.md "Town places"): no shipped
-- template carries a `quest_place` socket yet, so once every mod has loaded
-- the probe registers a probe settlement with one `quest_place` socket in
-- the cell in front of Highcourt's guild leader, inside the Miner's Guild
-- house (under its roof), and loads a probe quest file through
-- grug_quests' loader and world checks: one "use at a place" objective at
-- `socket:r59_probe_hall/hall_floor`. The house is emerged and forceloaded;
-- player stand-ins (the ObjectRef calls the quest code makes; the server
-- has no client) walk up:
--   ANN  holds the act to the end: credited, the object hidden from her;
--   CID  stands there without the quest: never an observer.
-- Logged: the cell and its roof, the map's place lookup, the label, the
-- object's position and observers, the hold, the credit, a refused ref and
-- the cost of the per-player pass. Every line carries "[r59qsys3]"; the
-- probe ends the server when done.
local P = "[r59qsys3] "
local function log(s) core.log("action", P .. s) end
local Q = grug_quests

local KEY, SOCKET = "r59_probe_hall", "hall_floor"
local REF = "socket:" .. KEY .. "/" .. SOCKET
local GIVER = "r58_guild_leader_highcourt"
local FILES = {{name = "elandor_highcourt.quests.json", zone = "elandor_highcourt", front = false,
	data = {zone = "elandor_highcourt", hubs = {{id = "probe", givers = {{npc = GIVER, lines = {"probe"}}}}},
		quests = {{id = "r59q_ledger", line = "probe", giver = GIVER, turnin = GIVER, level = 20,
			title = "r59q_ledger", text = "Probe text. Not shipped.",
			objectives = {{type = "use", place = REF, object = "courier_ledger", label = "Search the ledger shelf",
				hold = 3}}, rewards = {weight = 1}}}}}}

-- Player stand-ins.
local fakes = {}
local function fake(name, pos)
	local meta = {}
	local p = {name = name, pos = vector.new(pos), hp = 20, place = false}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return vector.new(self.pos) end
	function p:get_player_control() return {place = self.place} end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end,
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = tostring(v) end}
	end
	local inv = {}
	function inv:get_list() return {} end
	function inv:get_stack() return ItemStack("") end
	function p:get_inventory() return inv end
	fakes[name] = p
	return p
end
local real_get_player = core.get_player_by_name
core.get_player_by_name = function(name) return fakes[name] or real_get_player(name) end

local ok = true
local function expect(cond, what)
	log((cond and "ok   " or "FAIL ") .. what)
	ok = ok and cond
end
local function names(set)
	local out = {}
	for n in pairs(set or {}) do out[#out + 1] = n end
	table.sort(out)
	return table.concat(out, ",")
end
local pass_us, passes = 0, 0
local function pass_all()
	for _, p in pairs(fakes) do
		local t0 = core.get_us_time()
		Q.use_pass(p)
		pass_us, passes = pass_us + core.get_us_time() - t0, passes + 1
	end
end
local function point_of()
	for _, point in pairs(Q._use_points) do
		if point.place == REF then return point end
	end
end
local function count_of(p, id)
	for _, row in ipairs(Q.journal(p).quests) do
		if row.id == id then return row.objectives[1].count end
	end
	return Q.status(p, id)
end
local function done()
	log(("COST use_pass: %d calls, %.1f us mean"):format(passes, passes > 0 and pass_us / passes or 0))
	log("RESULT " .. (ok and "PASS" or "FAIL"))
	core.request_shutdown("r59qsys3 probe done", false, 0)
end

-- The guild leader's socket, read once every mod has loaded; the house is
-- emerged round it once the server runs.
local leader, cell, emerged = nil, nil, false
core.register_on_mods_loaded(function()
	for _, socket in ipairs(grug_core.settlement_sockets_at("highcourt")) do
		if socket.id == "miners_guild/miners_guild_leader" then leader = socket end
	end
	expect(leader ~= nil, "Highcourt's guild leader socket exists")
	if leader then
		log(("guild leader socket at %s facing (%d, %d)"):format(core.pos_to_string(leader.pos),
			leader.dir.x, leader.dir.z))
	end
end)

local function prepare()
	local at = leader.pos
	local lo = {x = at.x - 12, y = at.y - 8, z = at.z - 12}
	local hi = {x = at.x + 12, y = at.y + 12, z = at.z + 12}
	core.emerge_area(lo, hi, function(_, _, remaining) if remaining == 0 then emerged = true end end)
	for bx = math.floor(lo.x / 16), math.floor(hi.x / 16) do
		for bz = math.floor(lo.z / 16), math.floor(hi.z / 16) do
			for by = math.floor(lo.y / 16), math.floor(hi.y / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
end

-- The roof over a cell (the first walkable node up to 12 above), or nil.
local function roof_of(pos)
	for dy = 1, 12 do
		local name = core.get_node({x = pos.x, y = pos.y + dy, z = pos.z}).name
		local def = core.registered_nodes[name]
		if def and def.walkable then return dy .. " " .. name end
	end
end
local function walkable(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def and def.walkable
end
-- The hall's floor: the nearest cell to the leader at its height, free over
-- walkable ground, under a roof and on no socket of the house.
local function hall_cell()
	local taken = {}
	for _, socket in ipairs(grug_core.settlement_sockets_at("highcourt")) do
		taken[core.pos_to_string(socket.pos)] = true
	end
	local best, best_d
	for dx = -6, 6 do
		for dz = -6, 6 do
			local pos = {x = leader.pos.x + dx, y = leader.pos.y, z = leader.pos.z + dz}
			local d = dx * dx + dz * dz
			if d > 1 and not taken[core.pos_to_string(pos)] and not walkable(pos) and
					not walkable({x = pos.x, y = pos.y + 1, z = pos.z}) and
					walkable({x = pos.x, y = pos.y - 1, z = pos.z}) and
					core.get_node(pos).name == "air" and roof_of(pos) and (not best_d or d < best_d) then
				best, best_d = pos, d
			end
		end
	end
	return best
end

-- The probe settlement, its quest file and the checks that need no player.
local function install()
	grug_core.register_settlement_sockets(KEY, "human", {x = 0, y = 0, z = 0},
		{{id = SOCKET, role = "quest_place", x = cell.x, y = cell.y, z = cell.z,
			dir = {x = 1, z = 0}}}, "Highcourt")
	local good, err = pcall(Q.load_quest_files, table.copy(FILES))
	expect(good, "the probe quest file loads " .. tostring(err or ""))
	good, err = pcall(Q.validate_quest_data, table.copy(FILES))
	expect(good, "the probe quest passes the world checks " .. tostring(err or ""))
	local refused, why = Q.use_place("socket:highcourt/miners_guild/miners_guild_leader")
	expect(refused == nil and tostring(why):find("not a quest_place", 1, true) ~= nil,
		"the leader's own socket is no town place: " .. tostring(why))
	local xz = grug_map.window.target_lookup.place(REF)
	expect(xz and xz.x == cell.x and xz.z == cell.z, "the map's quest target lookup gives the cell " ..
		(xz and core.pos_to_string({x = xz.x, y = xz.y or 0, z = xz.z}) or "nil"))
	local def = Q.registered_quests.r59q_ledger
	local label = def and Q.objective_action(def.objectives[1])
	expect(label == "Search the ledger shelf at Highcourt", "the label reads " .. tostring(label))
end

local t, phase, phase_t = 0, "start", 0
local ann, cid, point
local waited = 0
local function set_phase(p) phase, phase_t = p, 0; log("phase -> " .. p) end
core.register_globalstep(function(dtime)
	t, phase_t = t + dtime, phase_t + dtime
	if phase == "start" then
		if t < 3 then return end
		if not leader or not ok then return done() end
		prepare()
		set_phase("emerge")
	elseif phase == "emerge" then
		if not emerged and phase_t < 120 then return end
		log("emerged " .. tostring(emerged) .. " after " .. math.floor(phase_t) .. " s")
		cell = emerged and hall_cell()
		if not cell then expect(false, "a free roofed cell in the guild house"); return done() end
		local below = core.get_node({x = cell.x, y = cell.y - 1, z = cell.z})
		log(("the probe's town place at %s: %s on %s, roof %s"):format(core.pos_to_string(cell),
			core.get_node(cell).name, below.name, tostring(roof_of(cell))))
		expect(roof_of(cell) ~= nil, "the cell lies under a roof (no open air)")
		install()
		if not ok then return done() end
		ann = fake("probe_ann", vector.add(cell, {x = 10, y = 0, z = 0}))
		cid = fake("probe_cid", vector.add(cell, {x = 0, y = 0, z = 10}))
		expect(Q.accept(ann, "r59q_ledger"), "ann accepts the probe quest; cid takes nothing")
		set_phase("approach")
	elseif phase == "approach" then
		if phase_t < 1 then return end
		phase_t, waited = 0, waited + 1
		pass_all()
		point = point_of()
		if not (point and point.object) then
			if waited > 30 then expect(false, "the object appears"); return done() end
			return
		end
		local object = point.object
		local at = object:get_pos()
		log(("object at %s, observers {%s}"):format(core.pos_to_string(at), names(object:get_observers())))
		expect(math.floor(at.x + 0.5) == cell.x and math.floor(at.z + 0.5) == cell.z and
			math.abs(at.y - (cell.y - 0.5 + Q.use_objects.courier_ledger.size / 2)) < 0.01,
			"the object stands in the socket's cell")
		expect(names(object:get_observers()) == "probe_ann", "it is seen by ann only")
		ann.pos = vector.new(at.x + 1, cell.y, at.z)
		cid.pos = vector.new(at.x, cell.y, at.z + 1)
		ann.place, cid.place = true, true
		for _, p in ipairs({ann, cid}) do
			local ent = object:get_luaentity()
			local called, e = pcall(ent.on_rightclick, ent, p)
			log(("%s right-clicks: %s, holding %s"):format(p.name, called and "called" or tostring(e),
				tostring(Q._use_holds[p.name] ~= nil)))
		end
		expect(Q._use_holds.probe_ann and not Q._use_holds.probe_cid, "ann holds; cid cannot")
		set_phase("hold")
	elseif phase == "hold" then
		if phase_t < 4 then return end
		log(("credits: ann %s, cid %s"):format(tostring(count_of(ann, "r59q_ledger")),
			tostring(count_of(cid, "r59q_ledger"))))
		expect(count_of(ann, "r59q_ledger") == 1 and Q.status(ann, "r59q_ledger") == "ready", "ann is credited")
		expect(not point.object:is_valid(), "the object, its last user credited, is gone")
		done()
		set_phase("end")
	end
end)
