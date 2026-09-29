-- Disposable engine probe (Round 26 map follow-ups): stages the Map tab for
-- the 8x zoom / Housing Steward icon screenshot. Never shipped:
-- tools/r26_map/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client.
--
-- For the joining client it completes character creation through the real
-- receive-fields chain (Accord, Human, Warrior) once world preparation is
-- ready, then shows the real sfinv Map page as a formspec: first at 1x
-- (OVERVIEW), then at 8x scrolled so the Highcourt Housing Steward sits in the
-- middle, with that marker selected (ZOOM8). It logs the Steward marker and
-- shuts the server down SHUTDOWN_AFTER seconds after READY.

local P = "[r26map_probe] "
local NAME = "grugcap"
local SHUTDOWN_AFTER = 30

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function steward_marker(player)
	for _, marker in ipairs(grug_map.atlas.collect_markers(player)) do
		if marker.label == "Housing Steward" and marker.id:find("highcourt", 1, true) then
			return marker
		end
	end
end

local function show_map(player, zoom, marker)
	local context = sfinv.get_or_create_context(player)
	context.page = "grug_map:atlas"
	sfinv.pages["grug_map:atlas"]:on_enter(player, context)
	context.grug_map_zoom = zoom
	if marker then
		local atlas, view = grug_map.atlas, grug_map.atlas.view()
		-- Scroll units are thousandths of the unzoomed viewport (atlas.lua).
		local fx = (marker.position.x - view.min_x) / (view.max_x - view.min_x)
		local fz = (view.max_z - marker.position.z) / (view.max_z - view.min_z)
		context.grug_map_scroll_x = atlas.clamp_scroll((fx * zoom - 0.5) * 1000, zoom)
		context.grug_map_scroll_y = atlas.clamp_scroll((fz * zoom - 0.5) * 1000, zoom)
		context.grug_map_selected = marker.id
	end
	core.show_formspec(NAME, "grug_probe_r26_map:view", sfinv.get_formspec(player, context))
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
		if state.settle >= 6 then
			core.close_formspec(NAME, "")
			player:hud_set_flags({chat = false})
			state.phase = "ready"
			state.ready_at = core.get_us_time()
			local marker = steward_marker(player)
			log("steward " .. (marker and (marker.id .. " kind=" .. marker.kind ..
				" texture=" .. tostring(marker.texture) .. " at " ..
				core.pos_to_string(marker.position)) or "MISSING"))
			state.marker = marker
			log("READY")
		end
	elseif state.phase == "ready" then
		local since = (core.get_us_time() - state.ready_at) / 1e6
		if since > 2 and not state.overview then
			state.overview = true
			show_map(player, 1, nil)
			log("OVERVIEW")
		elseif since > 10 and not state.zoom8 then
			state.zoom8 = true
			show_map(player, 8, state.marker)
			log("ZOOM8")
		end
		if since > SHUTDOWN_AFTER then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
		end
	end
end)
