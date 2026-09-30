-- Disposable engine probe (Round 27, WP50): stages the minimap screenshots.
-- Never shipped: tools/r27_minimap/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client.
--
-- For the joining client it completes character creation through the real
-- receive-fields chain (Accord, Human, Warrior) once world preparation is
-- ready, turns the player to face east (the arrow must point right), then:
--   BEFORE   (glide) the player walked to 1.5 nodes before a grid-cell edge;
--   AFTER    walked on to 1.5 nodes past it and turned north: the texture
--            was swapped, the map must not jump, the arrow points up;
--   OFF      our minimap switched off with the Map tab's switch: the top
--            right corner must be empty, so no native minimap is drawn;
--   MAPTAB   the real sfinv Map page (switch shown off, region labels).
-- It logs the HUD flags, the minimap's markers and per-player update cost
-- next to the quest tracker's and the Map tab's for comparison, then shuts
-- the server down.

local P = "[r27mm_probe] "
local NAME = "grugcap"
local SHUTDOWN_AFTER = 90

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

-- The next grid-cell edge east of x (minimap_view geometry) and the ground
-- height at x/z.
local function cell_edge(x, z)
	local mm = grug_map.minimap
	local v = mm.geometry()
	local cx = mm.view.cell(v, x, z)
	return v.min_x + (cx + 1) * v.grid * v.npp
end
local function ground(x, z, y0)
	for y = y0 + 12, y0 - 12, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		local def = node and core.registered_nodes[node.name]
		if def and def.walkable then return y + 1 end
	end
	return y0
end
-- Walks the player east in 0.3-node server steps to `target` (a glide as
-- the client would see it while walking).
local function walk_to(player, target)
	local pos = player:get_pos()
	local step = target > pos.x and 0.3 or -0.3
	if math.abs(target - pos.x) <= 0.3 then
		player:set_pos({x = target, y = ground(target, pos.z, math.floor(pos.y)), z = pos.z})
		return true
	end
	local x = pos.x + step
	player:set_pos({x = x, y = ground(x, pos.z, math.floor(pos.y)), z = pos.z})
	return false
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
		-- Each shot's log line is followed by a 4 s wait in capture.sh before
		-- the screenshot, so the player holds still for HOLD seconds after it.
		local HOLD = 6
		local now = core.get_us_time() / 1e6
		local since = now - state.ready_at / 1e6
		if not state.edge then
			local pos = player:get_pos()
			state.edge = cell_edge(pos.x, pos.z)
			log(("cell edge at x %.2f (player x %.2f)"):format(state.edge, pos.x))
			-- start a few nodes before it, then walk
			walk_to(player, state.edge - 6)
			player:set_pos({x = state.edge - 6, y = ground(state.edge - 6, pos.z,
				math.floor(pos.y)), z = pos.z})
		end
		if not state.before then
			if walk_to(player, state.edge - 1.5) and since > 6 then
				state.before, state.at = true, now
				state.before_texture = grug_map.minimap.texture_of(player)
				report(player)
				log("texture " .. tostring(state.before_texture):sub(1, 80))
				log("BEFORE")
			end
		elseif not state.after then
			if now > state.at + HOLD and walk_to(player, state.edge + 1.5) then
				player:set_look_horizontal(0)
				state.after, state.at = true, now
				local texture = grug_map.minimap.texture_of(player)
				log("texture " .. tostring(texture):sub(1, 80))
				log(("swapped=%s"):format(tostring(texture ~= state.before_texture)))
				report(player)
				log("AFTER")
			end
		elseif not state.off then
			if now > state.at + HOLD then
				state.off, state.at = true, now
				local context = sfinv.get_or_create_context(player)
				context.page = "grug_map:atlas"
				sfinv.pages["grug_map:atlas"]:on_enter(player, context)
				sfinv.pages["grug_map:atlas"]:on_player_receive_fields(player, context,
					{grug_map_minimap = "false"})
				log(("switched off: enabled=%s"):format(tostring(grug_map.minimap.enabled(player))))
			end
		elseif not state.off_shot then
			if now > state.at + 2 then
				state.off_shot, state.at = true, now
				report(player)
				log("OFF")
			end
		elseif not state.maptab then
			if now > state.at + HOLD then
				state.maptab, state.at = true, now
				local context = sfinv.get_or_create_context(player)
				core.show_formspec(NAME, "grug_probe_r27_minimap:view",
					sfinv.get_formspec(player, context))
				log("MAPTAB")
			end
		elseif now > state.at + HOLD + 2 or since > SHUTDOWN_AFTER then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
		end
	end
end)
