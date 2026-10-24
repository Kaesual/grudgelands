-- Disposable Round 59 lane STORYQUESTS probe (tools/r59_storyquests/
-- engine.sh). Never shipped.
--
-- Chapter 1's six town places on the running world (quests.md "Chapter 1 in
-- the capitals", settlements.md "Chapter 1's town places"): each place is
-- resolved through the shipped quest data and the real settlement socket
-- registry, the blocks round it are emerged and forceloaded, and its cell,
-- the node under it and its headroom are logged and checked (air over
-- walkable ground, as use.lua's town stand needs). At Highcourt a player
-- stand-in with story_accord_01 done takes story_accord_02 from Alis
-- Cartwright and holds its quest object at the dispatch yard: the object
-- stands in the socket's cell, only she observes it, the hold credits her
-- and the quest is ready at Alis only. Every line carries "[r59sq]"; the
-- probe ends the server when done.
local P = "[r59sq] "
local function log(s) core.log("action", P .. s) end
local Q = grug_quests

local PLACES = {
	{"highcourt", "socket:highcourt/market_store/market_store_dispatch_yard"},
	{"dur_brannoc", "socket:dur_brannoc/forge_ore_yard/forge_ore_yard_loading_apron"},
	{"lethariel", "socket:lethariel/market_bowyer/market_bowyer_timber_check"},
	{"gor_drazhak", "socket:gor_drazhak/warren_cook_court/warren_cook_court_water_depot"},
	{"kezamba", "socket:kezamba/shore_store/shore_store_witness_landing"},
	{"nhal_veyr", "socket:nhal_veyr/homes_mourners_hall/homes_mourners_hall_receiving_court"},
}
local QUEST, BEFORE, LEADER = "story_accord_02", "story_accord_01", "r58_guild_leader_highcourt"

-- Player stand-ins (the ObjectRef calls the quest code makes; the server
-- has no client).
local fakes = {}
local function fake(name, pos, state)
	local meta = {["grug_quests:state"] = core.serialize(state)}
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
	if fakes[player:get_player_name()] then return 20 end
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
	core.request_shutdown("r59sq probe done", false, 0)
end

local cells, pending = {}, 0
core.register_on_mods_loaded(function()
	for _, row in ipairs(PLACES) do
		local place, why = Q.use_place(row[2])
		expect(place ~= nil, row[2] .. " resolves " .. tostring(why or ""))
		if place then
			cells[#cells + 1] = {capital = row[1], ref = row[2], pos = place.pos, name = place.name}
			log(("%s at %s (%s)"):format(row[2], core.pos_to_string(place.pos), place.name))
		end
	end
end)

local function prepare()
	for _, cell in ipairs(cells) do
		local at = cell.pos
		local lo = {x = at.x - 8, y = at.y - 4, z = at.z - 8}
		local hi = {x = at.x + 8, y = at.y + 6, z = at.z + 8}
		pending = pending + 1
		core.emerge_area(lo, hi, function(_, _, remaining)
			if remaining == 0 then pending = pending - 1; cell.emerged = true end
		end)
		for bx = math.floor(lo.x / 16), math.floor(hi.x / 16) do
			for bz = math.floor(lo.z / 16), math.floor(hi.z / 16) do
				for by = math.floor(lo.y / 16), math.floor(hi.y / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
	end
end
local function def_of(pos) return core.registered_nodes[core.get_node(pos).name] end

local t, phase, phase_t = 0, "start", 0
local ann, cid, point, waited = nil, nil, nil, 0
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
		if #cells ~= #PLACES or not ok then return done() end
		prepare()
		set_phase("emerge")
	elseif phase == "emerge" then
		if pending > 0 and phase_t < 240 then return end
		log(("emerged %d of %d after %d s"):format(#cells - pending, #cells, math.floor(phase_t)))
		for _, cell in ipairs(cells) do
			local p = cell.pos
			local here, under = core.get_node(p).name, core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
			local above = core.get_node({x = p.x, y = p.y + 1, z = p.z}).name
			log(("%s: cell %s, under %s, above %s"):format(cell.capital, here, under, above))
			local d_under = def_of({x = p.x, y = p.y - 1, z = p.z})
			expect(cell.emerged and here == "air" and above == "air" and d_under and d_under.walkable and
				d_under.liquidtype == "none", cell.capital .. "'s town place is air over walkable ground")
		end
		local hc = cells[1]
		ann = fake("probe_ann", vector.add(hc.pos, {x = 6, y = 0, z = 0}),
			{active = {}, completed = {[BEFORE] = true}, tracked = {}, hud = true})
		cid = fake("probe_cid", vector.add(hc.pos, {x = 0, y = 0, z = 6}),
			{active = {}, completed = {}, tracked = {}, hud = true})
		expect(Q.status(ann, QUEST) == "available", "ann may take " .. QUEST .. ": " .. Q.status(ann, QUEST))
		expect(Q.accept(ann, QUEST, LEADER), "ann takes " .. QUEST .. " from Alis Cartwright")
		local def = Q.registered_quests[QUEST]
		local label = Q.objective_action(Q.variant_of(def, Q.active_entry(ann, QUEST)).objectives[1])
		expect(label == "Secure the dispatch record at Highcourt", "the label reads " .. tostring(label))
		set_phase("approach")
	elseif phase == "approach" then
		if phase_t < 1 then return end
		phase_t, waited = 0, waited + 1
		for _, p in pairs(fakes) do Q.use_pass(p) end
		point = point_of(cells[1].ref)
		if not (point and point.object) then
			if waited > 30 then expect(false, "the object appears"); return done() end
			return
		end
		local object, cell = point.object, cells[1].pos
		local at = object:get_pos()
		log(("object at %s, observers {%s}"):format(core.pos_to_string(at), names(object:get_observers())))
		expect(math.floor(at.x + 0.5) == cell.x and math.floor(at.z + 0.5) == cell.z and
			math.abs(at.y - (cell.y - 0.5 + Q.use_objects.dispatch_record.size / 2)) < 0.01,
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
		expect(Q.status(ann, QUEST) == "ready", "ann is credited: " .. Q.status(ann, QUEST))
		expect(Q.turns_in_at(ann, QUEST, LEADER) and
			not Q.turns_in_at(ann, QUEST, "r58_guild_leader_dur_brannoc"), "ready at Alis only")
		expect(not point.object:is_valid(), "the object, its last user credited, is gone")
		done()
		set_phase("end")
	end
end)
