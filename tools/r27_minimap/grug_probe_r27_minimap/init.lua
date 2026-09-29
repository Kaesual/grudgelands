-- Disposable engine probe (Round 27, WP50): stages the minimap screenshots.
-- Never shipped: tools/r27_minimap/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client.
--
-- For the joining client it completes character creation through the real
-- receive-fields chain (Accord, Human, Warrior) once world preparation is
-- ready, turns the player to face east (the arrow must point right), then:
--   MINIMAP  our minimap in play, the native one off;
--   OFF      our minimap switched off with the Map tab's switch: the top
--            right corner must be empty, so no native minimap is drawn;
--   MAPTAB   the real sfinv Map page (switch shown off, region labels).
-- It logs the HUD flags, the minimap's markers and per-player update cost
-- next to the quest tracker's and the Map tab's for comparison, then shuts
-- the server down.

local P = "[r27mm_probe] "
local NAME = "grugcap"
local SHUTDOWN_AFTER = 34

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function average_us(fn, rounds)
	local started = core.get_us_time()
	for _ = 1, rounds do fn() end
	return (core.get_us_time() - started) / rounds
end

local function report(player)
	local flags = player:hud_get_flags()
	log(("flags minimap=%s minimap_radar=%s"):format(tostring(flags.minimap),
		tostring(flags.minimap_radar)))
	local kinds = {}
	for _, def in pairs(player.hud_get_all and player:hud_get_all() or {}) do
		if def.type == "minimap" then kinds[#kinds + 1] = "NATIVE-MINIMAP-ELEMENT" end
		if def.type == "compass" then kinds[#kinds + 1] = "compass" end
		if type(def.text) == "string" and def.text:find("^grug_map_") then
			kinds[#kinds + 1] = def.text
		end
		if type(def.text) == "string" and def.text:find("^%[combine") then
			kinds[#kinds + 1] = def.text:sub(1, 60) .. "..."
		end
	end
	table.sort(kinds)
	log("hud " .. table.concat(kinds, " | "))
	local stats = grug_map.minimap.stats
	log(("minimap updates=%d avg_us=%.1f packets/update=%.2f textures=%d"):format(
		stats.updates, stats.us / math.max(1, stats.updates),
		stats.changes / math.max(1, stats.updates), stats.textures))
	local window = core.get_player_window_information(NAME)
	log(("window %s"):format(window and (window.size.x .. "x" .. window.size.y ..
		" hud " .. window.real_hud_scaling) or "none"))
	local quest_us = average_us(function()
		grug_quests.hud_text(grug_quests.journal(player), window)
	end, 200)
	local context = sfinv.get_or_create_context(player)
	local page = sfinv.pages["grug_map:atlas"]
	local map_us = average_us(function() page:get(player, context) end, 50)
	local markers_us = average_us(function() grug_map.atlas.collect_markers(player) end, 200)
	log(("compare us: quest tracker text %.1f, Map tab form %.1f, collect_markers %.1f"):
		format(quest_us, map_us, markers_us))
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if not grug_factions.get_faction(player) then
			submit(player, {choose_accord = "Accord"})
		elseif not grug_classes.get_race(player) then
			submit(player, {choose_human = "Human"})
		elseif not grug_classes.get_class(player) then
			submit(player, {choose_warrior = "Warrior"})
		end
		if grug_classes.get_class(player) then
			state.phase = "settle"
			state.settle = 0
			log("character complete at " .. core.pos_to_string(
				vector.round(player:get_pos())))
		end
	elseif state.phase == "settle" then
		state.settle = state.settle + 1
		core.close_formspec(NAME, "")
		-- east: yaw 0 faces +z, positive yaw turns toward -x
		player:set_look_horizontal(-math.pi / 2)
		player:set_look_vertical(0.3)
		if state.settle >= 8 then
			player:hud_set_flags({chat = false})
			state.phase = "ready"
			state.ready_at = core.get_us_time()
			log("READY")
		end
	elseif state.phase == "ready" then
		local since = (core.get_us_time() - state.ready_at) / 1e6
		if since > 6 and not state.shot then
			state.shot = true
			report(player)
			log("MINIMAP")
		elseif since > 14 and not state.off then
			state.off = true
			local context = sfinv.get_or_create_context(player)
			context.page = "grug_map:atlas"
			sfinv.pages["grug_map:atlas"]:on_enter(player, context)
			sfinv.pages["grug_map:atlas"]:on_player_receive_fields(player, context,
				{grug_map_minimap = "false"})
			log(("switched off: enabled=%s"):format(tostring(grug_map.minimap.enabled(player))))
		elseif since > 18 and not state.off_shot then
			state.off_shot = true
			report(player)
			log("OFF")
		elseif since > 24 and not state.maptab then
			state.maptab = true
			local context = sfinv.get_or_create_context(player)
			core.show_formspec(NAME, "grug_probe_r27_minimap:view",
				sfinv.get_formspec(player, context))
			log("MAPTAB")
		end
		if since > SHUTDOWN_AFTER then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
		end
	end
end)
