-- Disposable Round 84 lane ELITE probe (tools/r84_elite/engine.sh). Never
-- shipped.
--
-- At one leader's spot (Dawnmere's bandit chief; a few forceloaded blocks,
-- no player), three objects are added:
--   DUMMY  a plain probe entity, `static_save = false` set after its add
--          (the 0.83.0 pattern, outside the game's code);
--   OLD    a leader sub-type added the 0.83.0 way (static_save = false
--          after the add), its `_grug_unsaved` mark lifted for the add so
--          the claim does not remove it at once;
--   NEW    another leader sub-type through grug_mobs.add_entity_unsaved
--          (the placing mark add_mob_unsaved sets too; mobs:add_mob itself
--          places nothing without a player near).
-- Then the blocks are released, saved and unloaded (a short unload timeout)
-- with the objects alive, and loaded again. Expected from the engine
-- reading (docs/technical/upstream-workarounds.md §11): DUMMY comes back
-- (the add-time snapshot survived), OLD's snapshot comes back and removes
-- itself (one log line), NEW does not come back.
-- Every line carries "[r84elite]"; the probe ends the server when done.
local P = "[r84elite] "
-- The engine's own logger, taken before the wrapper below, and a hard cap:
-- no probe writes unbounded output.
local real_log = core.log
local logged, LOG_CAP = 0, 200
local function log(s)
	logged = logged + 1
	if logged <= LOG_CAP then real_log("action", P .. s) end
end

local DUMMY = "grug_probe_r84_elite:dummy"
local OLD = "grug_mobs:confused_bandit_chief"
local NEW = "grug_mobs:foreman_nog"
local phase, phase_t, total_t = "wait", 0, 0
local spot, emerge_done, results = nil, false, {}
local removals = {}

core.register_entity(DUMMY, {
	initial_properties = {
		physical = false, pointable = false, hp_max = 1,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
	},
})

local function result(name, ok, text)
	results[#results + 1] = ok
	log(("%s %s: %s"):format(ok and "OK" or "FAIL", name, text))
end
local function set_phase(p)
	phase, phase_t = p, 0
	log("phase -> " .. p)
end

core.register_on_mods_loaded(function()
	-- The map's unload timer, short (read by the engine at every pass).
	core.settings:set("server_unload_unused_data_timeout", "3")
	-- Only the claim's own line counts (it starts with "[grug_mobs]"; the
	-- probe's lines go to real_log and never come through here).
	local game_log = core.log
	core.log = function(level, text)
		if type(text) == "string" and #removals < 10 and text:sub(1, 12) == "[grug_mobs] " and
				text:find("which the map never saves, removed itself", 1, true) then
			removals[#removals + 1] = text
		end
		return game_log(level, text)
	end
end)

local function blocks(fn)
	for bx = math.floor((spot.x - 16) / 16), math.floor((spot.x + 16) / 16) do
		for bz = math.floor((spot.z - 16) / 16), math.floor((spot.z + 16) / 16) do
			for by = math.floor((spot.y - 16) / 16), math.floor((spot.y + 16) / 16) do
				fn({x = bx * 16, y = by * 16, z = bz * 16})
			end
		end
	end
end

local function counts()
	local out = {[DUMMY] = 0, [OLD] = 0, [NEW] = 0}
	for _, obj in ipairs(core.get_objects_inside_radius(spot, 40)) do
		local ent = obj:get_luaentity()
		if ent and out[ent.name] then out[ent.name] = out[ent.name] + 1 end
	end
	return out
end
local function show(c)
	return ("dummy %d, old-way leader %d, unsaved leader %d"):format(c[DUMMY], c[OLD], c[NEW])
end

local function finish()
	local ok = #results > 0
	for _, r in ipairs(results) do ok = ok and r end
	log(ok and "RESULT PASS" or "RESULT FAIL")
	set_phase("off")
	core.request_shutdown("r84elite probe done", false, 0)
end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			spot = grug_mobs.spawn_regions.leader_pos(OLD:sub(11))
			if not spot then
				log("RESULT NOSPOT")
				set_phase("off")
				core.request_shutdown("r84elite no spot", false, 0)
				return
			end
			spot.y = spot.y + 2
			log("spot " .. core.pos_to_string(spot))
			blocks(function(p) core.forceload_block(p, true, -1) end)
			core.emerge_area({x = spot.x - 16, y = spot.y - 16, z = spot.z - 16},
				{x = spot.x + 16, y = spot.y + 16, z = spot.z + 16}, function(_, _, remaining)
					if remaining == 0 then emerge_done = true end
				end)
			set_phase("emerge")
		end
	elseif phase == "emerge" then
		if phase_t > 4 and (emerge_done or phase_t > 120) then
			local dummy = core.add_entity(spot, DUMMY)
			if dummy then dummy:set_properties({static_save = false}) end
			-- mobs:add_mob places nothing without a player near, so both
			-- leaders come through core.add_entity with the staticdata
			-- mobs:add_mob would hand in (the authored mark).
			local authored = core.serialize({_grug_authored = true})
			local proto = core.registered_entities[OLD]
			proto._grug_unsaved = nil
			local old = core.add_entity({x = spot.x + 2, y = spot.y, z = spot.z}, OLD, authored)
			proto._grug_unsaved = true
			if old then old:set_properties({static_save = false}) end
			local new = grug_mobs.add_entity_unsaved({x = spot.x - 2, y = spot.y, z = spot.z},
				NEW, authored)
			local c = counts()
			local new_save = new and new:get_properties().static_save
			result("added", c[DUMMY] == 1 and c[OLD] == 1 and c[NEW] == 1 and new_save == false,
				show(c) .. ", unsaved leader static_save " .. tostring(new_save))
			set_phase("hold")
		end
	elseif phase == "hold" then
		-- Long enough for a map save to write the add-time snapshots.
		if phase_t > 8 then
			blocks(function(p) core.forceload_free_block(p, true) end)
			set_phase("away")
		end
	elseif phase == "away" then
		local c = counts()
		if math.floor(phase_t) ~= math.floor(phase_t - dtime) then log("away: " .. show(c)) end
		if (c[DUMMY] + c[OLD] + c[NEW] == 0 and phase_t > 6) or phase_t > 90 then
			result("unloaded", c[DUMMY] + c[OLD] + c[NEW] == 0,
				("%s after %.0f s"):format(show(c), phase_t))
			blocks(function(p) core.forceload_block(p, true, -1) end)
			set_phase("back")
		end
	elseif phase == "back" then
		if phase_t > 6 then
			local c = counts()
			local lines = #removals
			log("back: " .. show(c) .. ", removal lines " .. lines)
			for i = 1, lines do log("removal: " .. removals[i]) end
			result("engine keeps the snapshot", c[DUMMY] == 1,
				"the dummy made unsaved after its add came back: " .. c[DUMMY])
			result("old snapshot removes itself", c[OLD] == 0 and #removals == 1 and
				removals[1]:find(OLD, 1, true) ~= nil, ("old-way leader %d, %d removal line(s)")
				:format(c[OLD], #removals))
			result("unsaved leader leaves none", c[NEW] == 0, "unsaved leader " .. c[NEW])
			finish()
		end
	end
end)
