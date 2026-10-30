-- Disposable engine probe (Round 67 lane MAP): the minimap and the map
-- window for screenshots (the window at about 90 % of the screen, markers
-- at their anchors at 21 px, the flat layer buttons, the compact quest list
-- and the quest HUD in the same order). Never shipped:
-- tools/r67_map/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) is tools/r66_map's probe.
--
-- The character is raised to level 45 and takes the own faction's story
-- quests without prerequisites and a spread of side quests (accept tracks
-- the first ten). Shot 1: the minimap at the own faction's first capital;
-- shot 2: the map window on the Quests layer; shot 3: the Travel layer at
-- 2x. The window information and the window's geometry are logged.

local P = "[r67map] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r67map_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r67map_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function capital()
	local accord = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		if identity.faction_id == "accord" then accord[identity.race_id] = true end
	end
	local rows = {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		if row.slot == "capital" and accord[row.race_id] then rows[#rows + 1] = row end
	end
	table.sort(rows, function(a, b) return a.key < b.key end)
	return rows[1]
end

-- The story quests without prerequisites and every fifth side quest by
-- level, of the own faction, as far as the log takes them.
local function accept_quests(player)
	local story, side = {}, {}
	for id, def in pairs(grug_quests.registered_quests) do
		local npc = grug_quests.registered_npcs[def.npc]
		if npc and npc.faction == "accord" and #(def.prerequisites or {}) == 0 then
			local list = def.story and story or side
			list[#list + 1] = {id = id, level = def.level}
		end
	end
	local function by_level(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.id < b.id
	end
	table.sort(story, by_level)
	table.sort(side, by_level)
	local wanted = {}
	for _, row in ipairs(story) do wanted[#wanted + 1] = row end
	for i = 1, #side, 5 do wanted[#wanted + 1] = side[i] end
	local accepted = {story = 0, side = 0}
	for _, row in ipairs(wanted) do
		if accepted.story + accepted.side >= 14 then break end
		local ok = grug_quests.accept(player, row.id)
		if ok then
			local kind = grug_quests.registered_quests[row.id].story and "story" or "side"
			accepted[kind] = accepted[kind] + 1
		end
	end
	log(("accepted %d story and %d side quests"):format(accepted.story, accepted.side))
end

local function window_line(player)
	local info = core.get_player_window_information(NAME)
	if info then
		log(("window %dx%d hud %.2f gui %.2f max %.2fx%.2f"):format(info.size.x, info.size.y,
			info.real_hud_scaling, info.real_gui_scaling, info.max_formspec_size.x,
			info.max_formspec_size.y))
	end
end

local function open(player, layer, zoom)
	local W = grug_map.window
	W.sessions[NAME] = W.new_state()
	W.sessions[NAME].layer = layer
	W.open(player)
	local session = W.sessions[NAME]
	if zoom and zoom > 1 then
		session.layer = layer
		submit(player, W.FORMNAME, {grug_map_zoom_in = "+"})
	end
	local layout = session.layout
	log(("map window %s %.2f x %.2f units, map %.2f units, viewport %.2f, column %.2f, " ..
		"button rows %d, markers %d, tooltips %d, bytes %d"):format(layer, layout.w, layout.form_h,
		layout.map_w, layout.viewport_w, layout.column.w, layout.buttons.rows,
		session.marker_count or -1, session.tooltip_count or -1, session.bytes or -1))
end

local SHOTS = {
	{name = "M1_minimap_capital", run = function(player)
		local row = assert(capital(), "no Accord capital")
		player:set_pos({x = row.anchor.x + 30, y = row.anchor.y + 60, z = row.anchor.z + 30})
		log(("capital %s at %d,%d"):format(row.key, row.anchor.x, row.anchor.z))
		window_line(player)
	end},
	{name = "M2_map_window_quests", run = function(player)
		open(player, "quests")
	end},
	{name = "M3_map_window_travel_2x", run = function(player)
		open(player, "towns", 2)
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if not grug_map.minimap.available() then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:set_look_vertical(0.6)
		grug_xp.set_xp(player, grug_xp.xp_for_level(45))
		accept_quests(player)
		state.phase = "next"
		state.shot = 1
	elseif state.phase == "next" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		state.waited, state.logged, state.ran = 0, false, false
		state.phase = "shoot"
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not state.ran then
			state.ran = true
			local ok, err = pcall(shot.run, player)
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.phase = "next"
		end
	end
end)
