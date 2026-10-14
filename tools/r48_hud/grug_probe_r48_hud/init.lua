-- Disposable engine probe (Round 48 lane HUD): the minimap's side elements
-- (the mail icon, the daytime band, "Now playing") with the minimap shown
-- and hidden, for screenshots. Never shipped: tools/r48_hud/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) is the Round 47 ML
-- probe's.
--
-- After the character is made (Accord, Human, Warrior, at its start town)
-- the probe accepts three quests, so the quest tracker shows, then sets
-- each shot's minimap switch, mail count, time of day and "Now playing"
-- track, waits SETTLE seconds (more than the band's 5 s check) and logs
-- "SHOT <name>".
local P = "[r48hud] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r48hud_settle") or "") or 7
local function log(msg) core.log("action", P .. msg) end

local DAY, NIGHT = 0.5, 0.9 -- 12:00 (position 15) and 21:36 (position 32)
-- The longest shipped title, so the corner stack shows its widest box.
local TRACK = grug_ambience.data.tracks.fantasy_orchestral_theme
local SHOTS = {
	{name = "S1_shown_mail0_day", shown = true, mail = 0, tod = DAY},
	{name = "S2_shown_mail3_day", shown = true, mail = 3, tod = DAY},
	{name = "S3_shown_mail9p_night", shown = true, mail = 12, tod = NIGHT},
	{name = "S4_shown_mail3_day_playing", shown = true, mail = 3, tod = DAY, playing = true},
	{name = "H1_hidden_mail0_day", shown = false, mail = 0, tod = DAY},
	{name = "H2_hidden_mail3_day", shown = false, mail = 3, tod = DAY},
	{name = "H3_hidden_mail9p_night_playing", shown = false, mail = 12, tod = NIGHT,
		playing = true},
	{name = "H4_hidden_mail3_day_playing", shown = false, mail = 3, tod = DAY, playing = true},
}

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r48hud_ack", "r")
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

local function show(player, shot)
	local minimap = grug_map.minimap
	minimap.set_enabled(player, shot.shown)
	minimap.set_mail_count(NAME, shot.mail)
	minimap.set_now_playing(NAME, shot.playing and TRACK or nil)
	core.set_timeofday(shot.tod)
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
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local huds, side = 0, {}
			for _, def in pairs(player:hud_get_all()) do
				huds = huds + 1
				local text = type(def.text) == "string" and def.text or ""
				if text:find("^grug_map_daytime_") or text:find("^grug_map_mail_") or
						text:find("^%[fill:") then
					side[#side + 1] = ("%s@%.4f,%.4f"):format(text, def.position.x, def.position.y)
				end
			end
			table.sort(side)
			log(("SHOT %s"):format(shot.name))
			log(("CHECK %s: %d HUD elements; side %s"):format(shot.name, huds,
				table.concat(side, " ")))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
