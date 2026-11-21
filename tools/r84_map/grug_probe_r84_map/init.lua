-- Disposable engine probe (Round 84 lane MAP): the letter icon and the
-- announcements icon under it, the feed line of a new announcement and the
-- map window before and after choosing Zones, for screenshots. Never
-- shipped: tools/r84_map/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) is tools/r48_hud's probe's.
--
-- After the character is made (Accord, Human, Warrior, at its start town)
-- the probe accepts three quests, so the quest tracker shows, then runs the
-- shots: the icons with counts told directly (as grug_mail tells them),
-- the minimap shown and hidden; one real grug_mail.send_broadcast (the
-- real counts and the feed line, shot at once: a feed line lives 2.5 s);
-- the map window opened, zoomed to 4x, then Zones chosen through the
-- window's own field handler. Each shot waits SETTLE seconds (more than
-- the band's 5 s check) unless it says otherwise, then logs "SHOT <name>".
local P = "[r84map] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r84map_settle") or "") or 7
local function log(msg) core.log("action", P .. msg) end

local TRACK = grug_ambience.data.tracks.fantasy_orchestral_theme

local function icons(letters, announcements, shown, playing)
	return function(player)
		local minimap = grug_map.minimap
		minimap.set_enabled(player, shown)
		minimap.set_mail_count(NAME, letters, announcements)
		minimap.set_now_playing(NAME, playing and TRACK or nil)
	end
end

local W = grug_map.window
local SHOTS = {
	{name = "M1_shown_letters3", run = icons(3, 0, true)},
	{name = "M2_shown_announcements2", run = icons(0, 2, true)},
	{name = "M3_shown_both", run = icons(3, 12, true)},
	{name = "M4_hidden_letters3_playing", run = icons(3, 0, false, true)},
	{name = "M5_hidden_announcements2_playing", run = icons(0, 2, false, true)},
	{name = "M6_hidden_both_playing", run = icons(3, 12, false, true)},
	{name = "F1_feed_new_announcement", settle = 0, run = function(player)
		icons(0, 0, true)(player)
		grug_mail.refresh_count(NAME)
		grug_mail.send_broadcast("Server restart tonight", "The server restarts at 8.", "probe")
	end},
	{name = "Z1_map_quests_4x", run = function(player)
		W.open(player)
		W.handle_fields(player, {grug_map_zoom_in = "+"})
		W.handle_fields(player, {grug_map_zoom_in = "+"})
	end},
	{name = "Z2_map_zones_4x", run = function(player)
		W.handle_fields(player, {grug_map_layer_zones = "Zones"})
	end},
}

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r84map_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The three lowest-level quests of the own faction without prerequisites.
local function accept_quests(player)
	local rows = {}
	for id, def in pairs(grug_quests.registered_quests) do
		local npc = grug_quests.registered_npcs[def.npc]
		if npc and npc.faction == "accord" and #def.prerequisites == 0 then
			rows[#rows + 1] = {id = id, level = def.level}
		end
	end
	table.sort(rows, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.id < b.id
	end)
	local accepted = 0
	for _, row in ipairs(rows) do
		if accepted >= 3 then break end
		if grug_quests.accept(player, row.id) then accepted = accepted + 1 end
	end
	log("accepted " .. accepted .. " quests")
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.25 then return end
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
		core.set_timeofday(0.5)
		log("character complete at " .. core.pos_to_string(vector.round(player:get_pos())))
		accept_quests(player)
		local info = core.get_player_window_information(NAME)
		log(("window information: %s; minimap available: %s"):format(
			core.write_json(info or {}), tostring(grug_map.minimap.available())))
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
		if state.waited == 0 then shot.run(player) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= (shot.settle or SETTLE) then
			state.logged = true
			local side = {}
			for _, def in pairs(player:hud_get_all()) do
				local text = type(def.text) == "string" and def.text or ""
				if text:find("^grug_map_mail_") or text:find("^grug_map_announce_") or
						text:find("^%[fill:") or text:find("^New announcement") then
					side[#side + 1] = ("%s@%.4f,%.4f"):format(text, def.position.x, def.position.y)
				end
			end
			table.sort(side)
			log(("SHOT %s"):format(shot.name))
			local session = W.sessions[NAME]
			log(("CHECK %s: side %s; map %s"):format(shot.name, table.concat(side, " "),
				session and session.open and ("layer %s zoom %s scroll %s,%s"):format(
					tostring(session.layer), tostring(session.zoom), tostring(session.scroll_x),
					tostring(session.scroll_y)) or "closed"))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
