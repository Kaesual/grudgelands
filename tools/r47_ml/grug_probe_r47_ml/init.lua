-- Disposable engine probe (Round 47 lane ML): the map window's marker layers
-- for screenshots. Never shipped: tools/r47_ml/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) is the Round 47 TA probe's.
--
-- After the character is made (Accord, Human, Warrior, at its start town)
-- the probe accepts the lowest-level kill quest of the own faction and two
-- more, then shows the map window in every layer, the zone layer at 1x and
-- 4x, the Towns layer at a second icon size, and quest mode. For each shot
-- it logs "SHOT <name> <x> <y>": a screen pixel over one marker (or "- -"),
-- where capture.sh puts the pointer so the screenshot shows its tooltip.
local P = "[r47ml] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r47ml_settle") or "") or 4
local function log(msg) core.log("action", P .. msg) end

local W = grug_map.window
local atlas = grug_map.atlas

-- {name, layer, zoom, pick(player) -> a world position for the pointer or
-- nil, icon (W.PLACE_ICON for the shot), quest = true for quest mode}
local function nearest(rows, pos, pred)
	local best, best_d
	for _, row in ipairs(rows) do
		if not pred or pred(row) then
			local dx, dz = row.position.x - pos.x, row.position.z - pos.z
			local d = dx * dx + dz * dz
			if not best_d or d < best_d then best, best_d = row, d end
		end
	end
	return best and best.position
end
local function markers(player, layer)
	return W.layer_markers(player, grug_map.layers.BY_ID[layer])
end
local SHOTS = {
	{name = "L1_quests_1x", layer = "quests", zoom = 1,
		pick = function(p) return nearest(markers(p, "quests"), p:get_pos()) end},
	{name = "L2_bosses_1x", layer = "bosses", zoom = 1,
		pick = function(p) return nearest(markers(p, "bosses"), p:get_pos(),
			function(row) return row.kind == "king" end) end},
	{name = "L3_trainers_4x", layer = "trainers", zoom = 4,
		pick = function(p) return nearest(markers(p, "trainers"), p:get_pos()) end},
	{name = "L4_towns_1x", layer = "towns", zoom = 1,
		pick = function(p) return nearest(markers(p, "towns"), p:get_pos(),
			function(row) return row.kind == "capital" end) end},
	{name = "L4b_towns_1x_icon045", layer = "towns", zoom = 1, icon = 0.45,
		pick = function(p) return nearest(markers(p, "towns"), p:get_pos(),
			function(row) return row.kind == "village" end) end},
	{name = "L5_pois_1x", layer = "pois", zoom = 1,
		pick = function(p) return nearest(markers(p, "pois"), p:get_pos()) end},
	{name = "L6_pvp_1x", layer = "pvp", zoom = 1,
		pick = function(p) return nearest(markers(p, "pvp"), p:get_pos()) end},
	{name = "L7_zones_1x", layer = "zones", zoom = 1},
	{name = "L7b_zones_4x", layer = "zones", zoom = 4},
	{name = "L8_none_1x", layer = "none", zoom = 1},
	{name = "Q1_quest_mode_2x", layer = "quests", zoom = 2, quest = true,
		pick = function(p)
			local mark = W.handin_mark(p, W.probe_quest)
			return mark and mark.position
		end},
}

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r47ml_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The lowest-level quests of the own faction without prerequisites (a kill
-- quest first), accepted.
local function accept_quests(player)
	local rows = {}
	for id, def in pairs(grug_quests.registered_quests) do
		local npc = grug_quests.registered_npcs[def.npc]
		if npc and npc.faction == "accord" and #def.prerequisites == 0 then
			local kill = false
			for _, objective in ipairs(def.objectives) do
				if objective.type == "kill" then kill = true end
			end
			rows[#rows + 1] = {id = id, level = def.level, kill = kill}
		end
	end
	table.sort(rows, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.id < b.id
	end)
	local accepted, kill = 0, nil
	for _, row in ipairs(rows) do
		if accepted >= 3 then break end
		if (row.kill and not kill) or (kill and accepted < 3) then
			local ok, why = grug_quests.accept(player, row.id)
			log(("accept %s (level %d): %s %s"):format(row.id, row.level, tostring(ok), tostring(why or "")))
			if ok then
				accepted = accepted + 1
				if row.kill and not kill then kill = row.id end
			end
		end
	end
	return kill
end

-- The screen pixel of world `pos` in the window as the client draws it: the
-- form centred on the screen at the client's pixels per unit, the map's
-- scroll offset taken off.
local function screen_of(player, session, pos)
	local info = core.get_player_window_information(NAME)
	if not (info and info.size and info.max_formspec_size and pos) then return nil end
	local px = info.size.x / info.max_formspec_size.x
	local layout = session.layout
	local zoom = session.zoom or 1
	local sx, sy = atlas.world_to_screen(atlas.view(), pos, 0, 0, layout.map_w * zoom,
		layout.map_h * zoom)
	if not sx then return nil end
	local ox = (info.size.x - layout.w * px) / 2
	local oy = (info.size.y - layout.h * px) / 2
	sx = sx - (session.scroll_x or 0) * layout.map_w / 1000
	sy = sy - (session.scroll_y or 0) * layout.map_h / 1000
	return math.floor(ox + (layout.map_x + sx) * px + 0.5),
		math.floor(oy + (layout.map_y + sy) * px + 0.5)
end

local function show(player, shot)
	W.PLACE_ICON = shot.icon or 0.34
	W.open(player)
	local session = W.sessions[NAME]
	session.layer = shot.layer
	session.zoom = shot.zoom
	session.scroll_x, session.scroll_y = atlas.centre_scroll(atlas.view(), player:get_pos(), shot.zoom)
	session.follow = shot.zoom == 1
	session.quest_selected = shot.quest and W.probe_quest and W.probe_quest.id or nil
	W.request(player)
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(0.4)
		log("character complete at " .. core.pos_to_string(vector.round(player:get_pos())))
		local kill = accept_quests(player)
		for _, quest in ipairs(grug_quests.journal(player).quests) do
			if quest.id == kill then W.probe_quest = quest end
		end
		local info = core.get_player_window_information(NAME)
		log(("window information: %s"):format(core.write_json(info or {})))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local session = W.sessions[NAME]
			local x, y = screen_of(player, session, shot.pick and shot.pick(player))
			log(("SHOT %s %s %s"):format(shot.name, x or "-", y or "-"))
			log(("CHECK %s: %d bytes, layer %s, zoom %dx, %d button rows, markers %d, targets %d, " ..
				"map tooltips %d"):format(shot.name, session.bytes or 0, tostring(session.layer),
				session.zoom, session.layout.buttons.rows, session.marker_count or 0,
				session.target_count or 0, session.tooltip_count or 0))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
