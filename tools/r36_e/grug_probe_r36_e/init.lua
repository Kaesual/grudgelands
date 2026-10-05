-- Disposable Round 36 lane E probe (tools/r36_e/engine.sh). Never shipped.
--
-- "Use at a place" in the real engine (round36-plan.md §2.5): a probe quest
-- file (never shipped) with one use objective at a clash site (Saltgate
-- Remnant, r20_anchor_076) and one at the rule-placed quest place of
-- Stormvault Heights (snowfield_cairn), loaded through grug_quests'
-- loader and world checks. Both places are emerged and forceloaded; player
-- stand-ins (tables with the ObjectRef calls the quest code makes; the
-- server has no client) walk up:
--   ANN  holds the signal fire at the clash site to the end: credited;
--   BOB  holds it too and takes damage after a second (the engine's
--        hp-change callbacks): interrupted, not credited;
--   CID  stands there without the quest: never an observer;
--   DAN  holds the banner at the quest place: credited.
-- Logged: each place's position, the objects' observers (get_observers),
-- the holds, the credits and the cost of the per-player pass. Every line
-- carries "[r36e]"; the probe ends the server when done.
local P = "[r36e] "
local function log(s) core.log("action", P .. s) end
local Q = grug_quests
local SR = grug_mobs.spawn_regions

local GIVER = "r20_anchor_027_host"
local CLASH = "r20_anchor_076"
local SPOT = "elandor_stormvault_heights/snowfield_cairn"
local function use(place, label, object)
	return {type = "use", place = place, object = object, label = label, hold = 3}
end
local function quest(id, objective)
	return {id = id, line = "probe", giver = GIVER, turnin = GIVER, min_level = 1, level = 35,
		title = id, text = "Probe text. Not shipped.", objectives = {objective}, rewards = {weight = 1}}
end
local FILES = {{name = "elandor_stormvault_heights.quests.json", zone = "elandor_stormvault_heights",
	front = false, data = {zone = "elandor_stormvault_heights",
		hubs = {{id = "probe", givers = {{npc = GIVER, lines = {"probe"}}}}},
		quests = {quest("r36e_fire", use(CLASH, "Light the signal fire", "signal_fire")),
			quest("r36e_banner", use("snowfield_cairn", "Plant the banner", "banner"))}}}}
Q.load_quest_files(table.copy(FILES))

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

local pass_us, passes = 0, 0
local function pass_all()
	for _, p in pairs(fakes) do
		local t0 = core.get_us_time()
		Q.use_pass(p)
		pass_us, passes = pass_us + core.get_us_time() - t0, passes + 1
	end
end
local function point_of(place, label)
	for _, point in pairs(Q._use_points) do
		if point.place == place and point.objective.label == label then return point end
	end
end
local function names(set)
	local out = {}
	for n in pairs(set or {}) do out[#out + 1] = n end
	table.sort(out)
	return table.concat(out, ",")
end
local function count_of(p, id)
	for _, row in ipairs(Q.journal(p).quests) do
		if row.id == id then return row.objectives[1].count end
	end
	return Q.status(p, id)
end

local places, emerged = {}, 0
local function prepare(xz)
	local h = math.floor(grug_zones.terrain_height_at(xz.x, xz.z))
	local lo, hi = {x = xz.x - 24, y = h - 24, z = xz.z - 24}, {x = xz.x + 24, y = h + 24, z = xz.z + 24}
	core.emerge_area(lo, hi, function(_, _, remaining) if remaining == 0 then emerged = emerged + 1 end end)
	for bx = math.floor(lo.x / 16), math.floor(hi.x / 16) do
		for bz = math.floor(lo.z / 16), math.floor(hi.z / 16) do
			for by = math.floor(lo.y / 16), math.floor(hi.y / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	return {x = xz.x, y = h + 1, z = xz.z}
end

local ok = true
local function expect(cond, what)
	log((cond and "ok   " or "FAIL ") .. what)
	ok = ok and cond
end

core.register_on_mods_loaded(function()
	local good, err = pcall(Q.validate_quest_data, table.copy(FILES))
	expect(good, "the probe quests pass the world checks " .. tostring(err or ""))
	places.clash = SR.place(CLASH)
	places.spot = Q.use_place_xz(SPOT)
	log(("clash site %s at (%s, %s); quest place %s at (%s, %s)"):format(CLASH,
		places.clash and places.clash.x, places.clash and places.clash.z, SPOT,
		places.spot and places.spot.x, places.spot and places.spot.z))
end)

local t, phase, phase_t = 0, "start", 0
local ann, bob, cid, dan, fire, banner
local function set_phase(p) phase, phase_t = p, 0; log("phase -> " .. p) end
-- The engine's hp-change call for a stand-in: only grug_quests' callback
-- (the others want a real player's inventory and HUD).
local function hurt(p, amount)
	for _, fn in ipairs(core.registered_on_player_hpchanges.loggers) do
		if debug.getinfo(fn, "S").source:find("grug_quests/use.lua", 1, true) then fn(p, -amount, {type = "punch"}) end
	end
end
local function near(p, object, dx)
	local at = object:get_pos()
	p.pos = vector.new(at.x + dx, at.y, at.z + 1)
end
local function done()
	log(("COST use_pass: %d calls, %.1f us mean"):format(passes, passes > 0 and pass_us / passes or 0))
	log("RESULT " .. (ok and "PASS" or "FAIL"))
	core.request_shutdown("r36e probe done", false, 0)
end

core.register_globalstep(function(dtime)
	t, phase_t = t + dtime, phase_t + dtime
	if phase == "start" then
		if t < 3 then return end
		if not (places.clash and places.spot) then expect(false, "both places resolve"); return done() end
		places.clash3 = prepare(places.clash)
		places.spot3 = prepare(places.spot)
		set_phase("emerge")
	elseif phase == "emerge" then
		if emerged < 2 and phase_t < 120 then return end
		log("emerged " .. emerged .. "/2 after " .. math.floor(phase_t) .. " s")
		ann = fake("probe_ann", vector.add(places.clash3, {x = 12, y = 0, z = 0}))
		bob = fake("probe_bob", vector.add(places.clash3, {x = -12, y = 0, z = 0}))
		cid = fake("probe_cid", vector.add(places.clash3, {x = 0, y = 0, z = 12}))
		dan = fake("probe_dan", vector.add(places.spot3, {x = 12, y = 0, z = 0}))
		expect(Q.accept(ann, "r36e_fire") and Q.accept(bob, "r36e_fire") and Q.accept(dan, "r36e_banner"),
			"ann and bob accept the signal fire, dan the banner; cid takes nothing")
		set_phase("approach")
	elseif phase == "approach" then
		if phase_t < 1 then return end
		phase_t = 0
		pass_all()
		fire, banner = point_of(CLASH, "Light the signal fire"), point_of(SPOT, "Plant the banner")
		if not (fire and fire.object and banner and banner.object) then
			if t > 200 then expect(false, "both objects appear"); return done() end
			return
		end
		local fo, bo = fire.object, banner.object
		log(("signal fire object at %s, observers {%s}"):format(core.pos_to_string(fo:get_pos()),
			names(fo:get_observers())))
		log(("banner object at %s, observers {%s}"):format(core.pos_to_string(bo:get_pos()),
			names(bo:get_observers())))
		expect(names(fo:get_observers()) == "probe_ann,probe_bob", "the fire is seen by ann and bob only")
		expect(names(bo:get_observers()) == "probe_dan", "the banner is seen by dan only")
		near(ann, fo, 2); near(bob, fo, -2); near(cid, fo, 0); near(dan, bo, 2)
		ann.place, bob.place, dan.place = true, true, true
		-- The right-click: the entity's real callback (wrapped by contextual
		-- input), as the engine calls it.
		for _, row in ipairs({{ann, fo}, {bob, fo}, {dan, bo}, {cid, fo}}) do
			local ent = row[2]:get_luaentity()
			local called, e = pcall(ent.on_rightclick, ent, row[1])
			log(("%s right-clicks: %s, holding %s"):format(row[1].name, called and "called" or tostring(e),
				tostring(Q._use_holds[row[1].name] ~= nil)))
		end
		expect(Q._use_holds.probe_ann and Q._use_holds.probe_bob and Q._use_holds.probe_dan and
			not Q._use_holds.probe_cid, "ann, bob and dan hold; cid cannot")
		set_phase("hold")
	elseif phase == "hold" then
		if phase_t >= 1.2 and Q._use_holds.probe_bob then
			hurt(bob, 3)
			log("bob takes 3 damage: holding " .. tostring(Q._use_holds.probe_bob ~= nil))
		end
		if phase_t < 4 then return end
		log(("credits: ann %s, bob %s, cid %s, dan %s"):format(tostring(count_of(ann, "r36e_fire")),
			tostring(count_of(bob, "r36e_fire")), tostring(count_of(cid, "r36e_fire")),
			tostring(count_of(dan, "r36e_banner"))))
		expect(count_of(ann, "r36e_fire") == 1 and Q.status(ann, "r36e_fire") == "ready", "ann is credited")
		expect(count_of(bob, "r36e_fire") == 0, "bob, interrupted by damage, is not")
		expect(Q.status(cid, "r36e_fire") ~= "ready", "cid has nothing")
		expect(count_of(dan, "r36e_banner") == 1, "dan is credited at the rule-placed place")
		local fo = fire.object
		log("signal fire observers after the holds {" .. names(fo:is_valid() and fo:get_observers() or nil) .. "}")
		expect(fo:is_valid() and names(fo:get_observers()) == "probe_bob", "the fire stays for bob alone")
		expect(not banner.object:is_valid(), "the banner, its last user credited, is gone")
		bob.pos = vector.add(bob.pos, {x = 80, y = 0, z = 0})
		pass_all()
		expect(not fo:is_valid(), "bob walks away: the fire is gone")
		done()
		set_phase("end")
	end
end)
