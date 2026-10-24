-- Disposable Round 60 lane CAPITALS probe (tools/r60_capitals/engine.sh).
-- Never shipped.
--
-- Chapter 2's public register in Nhal Veyr on the running world (quests.md
-- "The capitals", settlements.md "Chapter 2's town place"): the place is
-- resolved through the shipped quest data and the real settlement socket
-- registry, the blocks round it are emerged and forceloaded, and its cell,
-- the node under it and its headroom are logged and checked (air over
-- walkable ground, as use.lua's town stand needs), with a top view of the
-- forecourt round it. The two story foremen are logged by their titles. A
-- Throng player stand-in at 29 with T3's prerequisites done takes T3 from
-- Ossa Quietregister and holds its claim notice: the object stands in the
-- socket's cell, only she observes it, the hold credits her and the quest
-- is ready at Iven Lastshift only. Every line carries "[r60cap]"; the probe
-- ends the server when done.
local P = "[r60cap] "
local function log(s) core.log("action", P .. s) end
local Q = grug_quests

local REF = "socket:nhal_veyr/miners_guild/miners_guild_public_register"
local QUEST, OSSA, IVEN = "story_throng_04", "r20_undead_capital_envoy", "r58_guild_leader_nhal_veyr"
local FOREMEN = {r58_foreman_mining_camp_frostbarrow_shelf = "Brodd Deeppeg",
	r58_foreman_mining_camp_ossuary_reach = "Rellis Shalemark",
	r58_foreman_mining_camp_mournfen = "Foreman"}

-- Player stand-ins (the ObjectRef calls the quest code makes; the server
-- has no client).
local fakes = {}
local function fake(name, pos, state)
	local meta = {["grug_quests:state"] = core.serialize(state), ["grug_factions:faction"] = "throng"}
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
local real_level = grug_xp.get_level
grug_xp.get_level = function(player)
	if fakes[player:get_player_name()] then return 29 end
	return real_level(player)
end

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
local function done()
	log("RESULT " .. (ok and "PASS" or "FAIL"))
	core.request_shutdown("r60cap probe done", false, 0)
end

local cell, emerged = nil, false
core.register_on_mods_loaded(function()
	local place, why = Q.use_place(REF)
	expect(place ~= nil, REF .. " resolves " .. tostring(why or ""))
	if place then
		cell = {pos = place.pos, name = place.name}
		log(("%s at %s (%s)"):format(REF, core.pos_to_string(place.pos), place.name))
	end
	for id, title in pairs(FOREMEN) do
		local npc = Q.registered_npcs[id]
		expect(npc ~= nil and npc.title == title, id .. " titled " .. tostring(npc and npc.title))
	end
end)

local function prepare()
	local at = cell.pos
	local lo = {x = at.x - 8, y = at.y - 4, z = at.z - 8}
	local hi = {x = at.x + 8, y = at.y + 6, z = at.z + 8}
	core.emerge_area(lo, hi, function(_, _, remaining)
		if remaining == 0 then emerged = true end
	end)
	for bx = math.floor(lo.x / 16), math.floor(hi.x / 16) do
		for bz = math.floor(lo.z / 16), math.floor(hi.z / 16) do
			for by = math.floor(lo.y / 16), math.floor(hi.y / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
end
local function def_of(pos) return core.registered_nodes[core.get_node(pos).name] end

-- A top view of the 13x13 round the place, one line per z row, at the
-- ground (y - 1) and at the cell's height: "." air, "#" walkable, "~"
-- other, "P" the place, "D" a door.
local function top_view()
	local p = cell.pos
	for _, dy in ipairs({-1, 0, 1}) do
		log(("top view at y%+d (rows z+6..z-6, columns x-6..x+6):"):format(dy))
		for dz = 6, -6, -1 do
			local row = {}
			for dx = -6, 6 do
				local pos = {x = p.x + dx, y = p.y + dy, z = p.z + dz}
				local name = core.get_node(pos).name
				local d = core.registered_nodes[name]
				local c = name == "air" and "." or (d and d.walkable and "#" or "~")
				if name:find("^doors:") then c = "D" end
				if dx == 0 and dz == 0 and dy == 0 then c = "P" end
				row[#row + 1] = c
			end
			log("  " .. table.concat(row))
		end
	end
end

local t, phase, phase_t = 0, "start", 0
local mira, nod, point, waited = nil, nil, nil, 0
local function set_phase(p) phase, phase_t = p, 0; log("phase -> " .. p) end
local function point_of(ref)
	for _, row in pairs(Q._use_points) do
		if row.place == ref then return row end
	end
end
core.register_globalstep(function(dtime)
	t, phase_t = t + dtime, phase_t + dtime
	if phase == "start" then
		if t < 3 then return end
		if not cell or not ok then return done() end
		prepare()
		set_phase("emerge")
	elseif phase == "emerge" then
		if not emerged and phase_t < 240 then return end
		log(("emerged %s after %d s"):format(tostring(emerged), math.floor(phase_t)))
		local p = cell.pos
		local here, under = core.get_node(p).name, core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
		local above = core.get_node({x = p.x, y = p.y + 1, z = p.z}).name
		log(("cell %s, under %s, above %s"):format(here, under, above))
		local d_under = def_of({x = p.x, y = p.y - 1, z = p.z})
		expect(emerged and here == "air" and above == "air" and d_under and d_under.walkable and
			d_under.liquidtype == "none", "the public register is air over walkable ground")
		top_view()
		local completed = {}
		for _, id in ipairs(Q.registered_quests[QUEST].prerequisites) do completed[id] = true end
		log("T3 requires " .. names(completed))
		mira = fake("probe_mira", vector.add(p, {x = 6, y = 0, z = 0}),
			{active = {}, completed = completed, tracked = {}, hud = true})
		nod = fake("probe_nod", vector.add(p, {x = 0, y = 0, z = 6}),
			{active = {}, completed = {}, tracked = {}, hud = true})
		expect(Q.status(nod, QUEST) ~= "available", "nod without the prerequisites may not take T3: " ..
			tostring(Q.status(nod, QUEST)))
		expect(Q.status(mira, QUEST) == "available", "mira may take " .. QUEST .. ": " .. Q.status(mira, QUEST))
		expect(Q.accept(mira, QUEST, OSSA), "mira takes " .. QUEST .. " from Ossa Quietregister")
		local def = Q.registered_quests[QUEST]
		local label = Q.objective_action(Q.variant_of(def, Q.active_entry(mira, QUEST)).objectives[1])
		expect(label == "Post the claim notice at Nhal Veyr", "the label reads " .. tostring(label))
		set_phase("approach")
	elseif phase == "approach" then
		if phase_t < 1 then return end
		phase_t, waited = 0, waited + 1
		for _, p in pairs(fakes) do Q.use_pass(p) end
		point = point_of(REF)
		if not (point and point.object) then
			if waited > 30 then expect(false, "the object appears"); return done() end
			return
		end
		local object, at_cell = point.object, cell.pos
		local at = object:get_pos()
		log(("object at %s, observers {%s}"):format(core.pos_to_string(at), names(object:get_observers())))
		expect(math.floor(at.x + 0.5) == at_cell.x and math.floor(at.z + 0.5) == at_cell.z and
			math.abs(at.y - (at_cell.y - 0.5 + Q.use_objects.claim_notice.size / 2)) < 0.01,
			"the object stands in the socket's cell")
		expect(names(object:get_observers()) == "probe_mira", "it is seen by mira only")
		mira.pos = vector.new(at.x + 1, at_cell.y, at.z)
		nod.pos = vector.new(at.x, at_cell.y, at.z + 1)
		mira.place, nod.place = true, true
		for _, p in ipairs({mira, nod}) do
			local ent = object:get_luaentity()
			local called, e = pcall(ent.on_rightclick, ent, p)
			log(("%s right-clicks: %s, holding %s"):format(p.name, called and "called" or tostring(e),
				tostring(Q._use_holds[p.name] ~= nil)))
		end
		expect(Q._use_holds.probe_mira and not Q._use_holds.probe_nod, "mira holds; nod cannot")
		set_phase("hold")
	elseif phase == "hold" then
		if phase_t < 4 then return end
		expect(Q.status(mira, QUEST) == "ready", "mira is credited: " .. Q.status(mira, QUEST))
		expect(Q.turns_in_at(mira, QUEST, IVEN) and not Q.turns_in_at(mira, QUEST, OSSA), "ready at Iven only")
		expect(not point.object:is_valid(), "the object, its last user credited, is gone")
		done()
		set_phase("end")
	end
end)
