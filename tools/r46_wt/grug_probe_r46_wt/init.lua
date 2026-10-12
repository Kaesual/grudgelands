-- Disposable engine probe (Round 46 lane WT: the waiting point). Never
-- shipped: tools/r46_wt/engine.py stages it through tools/luanti_headless.sh
-- on a fresh world whose staged minetest.conf raises grug_reset_world to 1,
-- and connects real network clients (tools/r46_wt/engine.py on
-- tools/r43_it/client.py), so the engine's own map generation around
-- connected players (active blocks, block sending) runs for them.
--
--   setup    each named character joins once as a new player and leaves; at
--            its leave the probe writes its saved state (below) and puts it
--            at its OLD position, which the engine saves with the player;
--   measure  they join again while the world preparation runs; the probe
--            logs the loaded position (a join callback inserted first), the
--            position after the join, and every generated chunk
--            (core.register_on_generated) near each old position, near the
--            engine's new-player spawn (around 0,0) and at the waiting point;
--   end      once the teleports are done and every client has left: a
--            summary, "RESULT PASS|FAIL", and a normal shutdown.
--
-- The characters (faction, race, class warrior):
--   oldhero  accord human, no reset record (a backlog), OLD A
--   leaver   throng orc, no reset record (a backlog), OLD B; leaves while
--            waiting, comes back after the preparation
--   arriver  accord elf, record 1, arriving mark set, OLD C; leaves while
--            waiting, comes back after the preparation
--   steady   throng troll, record 1, complete: the control, never moved, OLD D
--   newbie   a new player (no setup), creates throng troll after readiness

local P = "[r46_wt_probe] "
local WAIT = {x = 0, y = 31000, z = 0}
local RECORD_KEY = "grug_core:reset_world"
local ARRIVING_KEY = "grug_classes:arriving"
local SETUP = {
	oldhero = {faction = "accord", race = "human", old = {x = 1400, y = 30, z = 900}},
	leaver = {faction = "throng", race = "orc", old = {x = -1500, y = 30, z = 1000}},
	arriver = {faction = "accord", race = "elf", old = {x = 1300, y = 30, z = -1300},
		record = 1, arriving = true},
	steady = {faction = "throng", race = "troll", old = {x = -1400, y = 30, z = -1200},
		record = 1},
}
-- A chunk is "near" a position when its box meets the cube of this half
-- size around it: the block-sending generate reach (max_block_generate_
-- distance 10 + 1 blocks = 176 nodes) plus one chunk (80).
local NEAR = 256
local failures, checks = 0, 0
local clock = 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end
local function ps(pos) return pos and core.pos_to_string(vector.round(pos)) or "nil" end
core.register_globalstep(function(dtime) clock = clock + dtime end)

local function prep() return grug_core.world_preparation_status() end

--
-- Generated chunks.
--
local chunks = {} -- {minp, maxp, t, ready}
local function meets(minp, maxp, pos, r)
	return maxp.x >= pos.x - r and minp.x <= pos.x + r and
		maxp.y >= pos.y - r and minp.y <= pos.y + r and
		maxp.z >= pos.z - r and minp.z <= pos.z + r
end
-- The watched places: each old position, the engine's spawn search area
-- around (0, 0) near the surface, and the waiting point's air layer.
local function classify(minp, maxp)
	for name, row in pairs(SETUP) do
		if meets(minp, maxp, row.old, NEAR) then return "old:" .. name end
	end
	if maxp.y > 29000 then return "waiting point" end
	if meets(minp, maxp, {x = 0, y = 20, z = 0}, 400) then return "engine spawn" end
	return "other"
end
core.register_on_generated(function(minp, maxp)
	local class = classify(minp, maxp)
	chunks[#chunks + 1] = {class = class, t = clock, ready = prep().ready}
	if class ~= "other" then
		log(("chunk %s..%s (%s) t=%.1f ready=%s"):format(ps(minp), ps(maxp), class, clock,
			tostring(prep().ready)))
	end
end)

--
-- Joins and leaves.
--
local joins, seen = {}, {}
local function state(player)
	local meta = player:get_meta()
	return ("record=%q arriving=%q race=%q backlog=%s stasis=%s"):format(
		meta:get_string(RECORD_KEY), meta:get_string(ARRIVING_KEY),
		meta:get_string("grug_classes:race"),
		tostring(grug_core.map_reset.needs_relocation(player)),
		tostring(grug_core.player_in_creation_stasis(player:get_player_name())))
end

-- First of every join callback: the position and state the engine loaded.
-- Registered (for its callback origin), then moved to the front.
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local row = {loaded = player:get_pos(), ready = prep().ready, t = clock}
	joins[name] = joins[name] or {}
	table.insert(joins[name], row)
	log(("join %s #%d: loaded %s, preparation ready=%s (%d/%d), %s"):format(name,
		#joins[name], ps(row.loaded), tostring(row.ready), prep().completed, prep().total,
		state(player)))
end)
table.insert(core.registered_on_joinplayers, 1, table.remove(core.registered_on_joinplayers))
-- Last of every join callback.
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local row = joins[name][#joins[name]]
	row.after = player:get_pos()
	log(("join %s #%d: after the join callbacks %s, %s"):format(name, #joins[name],
		ps(row.after), state(player)))
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local row = SETUP[name]
	if row and not seen[name] then
		-- The setup leave: the saved character and its old position.
		seen[name] = true
		local meta = player:get_meta()
		meta:set_string("grug_factions:faction", row.faction)
		meta:set_string("grug_classes:race", row.race)
		meta:set_string("grug_classes:class", "warrior")
		meta:set_string(RECORD_KEY, row.record and tostring(row.record) or "")
		meta:set_string(ARRIVING_KEY, row.arriving and "1" or "")
		player:set_pos(row.old)
		log(("setup %s: saved at %s, %s"):format(name, ps(row.old), state(player)))
		return
	end
	log(("leave %s at %s, %s"):format(name, ps(player:get_pos()), state(player)))
end)

local arrivals = {}
grug_classes.register_on_arrival(function(player)
	arrivals[player:get_player_name()] = player:get_pos()
	log(("arrival %s at %s"):format(player:get_player_name(), ps(player:get_pos())))
end)

local ready_at
grug_core.register_on_preparation_progress(function(status)
	if status.ready and not ready_at then
		ready_at = clock
		log(("READY t=%.1f (%d/%d)"):format(clock, status.completed, status.total))
	end
end)

--
-- The end: every teleport done and every client gone.
--
local function at_start(name, pos)
	local row = SETUP[name] or {faction = "throng", race = "troll"}
	local start = grug_core.start_position(row.faction, row.race)
	return start and pos and vector.distance(start, pos) < 1.5
end

local function summary()
	local counts, during, after = {}, {}, {}
	for _, c in ipairs(chunks) do
		counts[c.class] = (counts[c.class] or 0) + 1
		local bucket = c.ready and after or during
		bucket[c.class] = (bucket[c.class] or 0) + 1
	end
	local classes = {"old:oldhero", "old:leaver", "old:arriver", "old:steady",
		"engine spawn", "waiting point", "other"}
	for _, class in ipairs(classes) do
		log(("chunks %-14s total=%d during-preparation=%d after=%d"):format(class,
			counts[class] or 0, during[class] or 0, after[class] or 0))
	end
	log(("chunks generated in all: %d; preparation ready at t=%s"):format(#chunks,
		ready_at and ("%.1f"):format(ready_at) or "never"))
	-- The old positions lie away from every start, so the counts are clean.
	for name, row in pairs(SETUP) do
		local nearest = math.huge
		for _, faction in ipairs(grug_core.faction_ids) do
			for race in pairs(grug_classes.registered_races) do
				local ok, start = pcall(grug_core.start_position, faction, race)
				if ok and start then
					nearest = math.min(nearest, vector.distance(start, row.old))
				end
			end
		end
		check(nearest > 2 * NEAR + 160, ("OLD %s is %.0f nodes from the nearest start"):format(
			name, nearest))
	end

	-- The joins during the preparation.
	for name, row in pairs(SETUP) do
		local first = joins[name] and joins[name][2]
		check(first and vector.equals(vector.round(first.loaded), row.old),
			name .. " joined with its old position " .. ps(first and first.loaded))
		check(first and not first.ready, name .. " joined during the preparation")
	end
	local nb = joins.newbie and joins.newbie[1]
	check(nb and not nb.ready, "newbie joined during the preparation")
	for _, name in ipairs({"oldhero", "leaver", "arriver", "newbie"}) do
		local row = joins[name] and joins[name][name == "newbie" and 1 or 2]
		check(row and row.after and vector.equals(row.after, WAIT),
			name .. " waits at the waiting point after its join: " .. ps(row and row.after))
	end
	local st = joins.steady and joins.steady[2]
	check(st and st.after and vector.equals(vector.round(st.after), SETUP.steady.old),
		"steady (complete, no backlog) keeps its position: " .. ps(st and st.after))
	-- Generation around the moved players: none at their old positions, none
	-- at the engine spawn; the control generates around its old position.
	for _, name in ipairs({"oldhero", "leaver", "arriver"}) do
		check((counts["old:" .. name] or 0) == 0, "no chunk generated around " .. name ..
			"'s old position (" .. (counts["old:" .. name] or 0) .. ")")
	end
	check((counts["engine spawn"] or 0) == 0, "no chunk generated at the engine spawn (" ..
		(counts["engine spawn"] or 0) .. ")")
	check((counts["old:steady"] or 0) > 0, "the control generated around its old position (" ..
		(counts["old:steady"] or 0) .. ")")
	log(("waiting point chunks: %d (reported, no target)"):format(counts["waiting point"] or 0))

	-- The disconnects at the waiting point.
	local lv = joins.leaver and joins.leaver[3]
	check(lv and vector.equals(lv.loaded, WAIT), "leaver came back at the waiting point " ..
		ps(lv and lv.loaded))
	local ar = joins.arriver and joins.arriver[3]
	check(ar and vector.equals(ar.loaded, WAIT), "arriver came back at the waiting point " ..
		ps(ar and ar.loaded))
end

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	log("end: " .. reason)
	summary()
	log(("RESULT %s checks=%d failures=%d t=%.1fs"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures, clock))
	core.after(1, function() core.request_shutdown("r46 wt probe done") end)
end

-- The settled state, read from the teleports' own records.
local final = {}
local function settled()
	local done = true
	for _, name in ipairs({"oldhero", "leaver", "arriver", "newbie", "steady"}) do
		local player = core.get_player_by_name(name)
		if player and not final[name] and
				not grug_core.player_in_creation_stasis(name) and prep().ready then
			final[name] = player:get_pos()
			local meta = player:get_meta()
			if name == "oldhero" or name == "leaver" then
				check(at_start(name, final[name]), name .. " relocated to its race start " ..
					ps(final[name]))
				check(meta:get_string(RECORD_KEY) == "1", name .. "'s record is written")
				check(arrivals[name] == nil, name .. ": no arrival flow")
			elseif name == "arriver" or name == "newbie" then
				check(at_start(name, final[name]), name .. " arrived at its race start " ..
					ps(final[name]))
				check(arrivals[name] ~= nil, name .. ": the arrival flow ran")
				check(meta:get_string(ARRIVING_KEY) == "", name .. "'s arriving mark is cleared")
			else
				check(vector.equals(vector.round(final[name]), SETUP.steady.old),
					"steady released where it stood " .. ps(final[name]))
			end
			log("SETTLED " .. name)
		end
		done = done and final[name] ~= nil
	end
	return done
end

local all_settled = false
local function poll()
	if finished then return end
	if not all_settled and settled() then
		all_settled = true
		log("ALL SETTLED t=" .. ("%.1f"):format(clock))
	end
	if all_settled and #core.get_connected_players() == 0 then
		finish("every teleport done, every client left")
		return
	end
	if clock > 240 then
		check(false, "the run did not settle within 240 s")
		finish("timeout")
		return
	end
	core.after(0.5, poll)
end
core.after(1, poll)
log("loaded: reset applied=" .. grug_core.map_reset.applied)
