-- Disposable engine probe (Round 57 lane QSYS): the quest dialog with a
-- choice of rewards, the story marker and the quest log's Story category,
-- for screenshots. Never shipped: tools/r57_qsys/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r48_mail's probe.
--
-- At Dawnmere it registers three probe quests through the real registry: a
-- story quest of the elder, a side quest of the elder with a choice of
-- three chest pieces (one fixed enchant each, item level 5) and a
-- completion text, and a side quest of the cook. Then it frames the elder
-- (story marker) and the cook (plain marker), opens the elder's dialog
-- through the real handler (the offer, the turn-in without and with a
-- pick), and shows the map window's quest log with the Story category and
-- the map's quest icons.

local P = "[r57qsys] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r57qsys_settle") or "") or 3
local Q = grug_quests
local ELDER, COOK = "r14_human_elder", "r20_human_start_cook"

local function log(msg) core.log("action", P .. msg) end

local function dirt(count)
	return {{type = "item", item = "default:dirt", count = count}}
end
Q.register_quest("probe_story_road", {title = "The Long Road", story = true, npc = ELDER,
	description = "The roads beyond Dawnmere are older than the town. Walk them with me, and bring a handful " ..
		"of earth from the fields.",
	min_level = 1, level = 2, rewards = {weight = 1}, objectives = dirt(1), zone = "elandor_dawnmere_fields"})
Q.register_quest("probe_choice_chest", {title = "Wolves at the Fence", npc = ELDER,
	description = "Something digs under the fence every night. Bring two clods of dirt to fill the holes, " ..
		"and I will see that you are dressed for the next one.",
	completion = "The fence holds again. The smith left these for whoever came back in one piece: take " ..
		"the one that suits you.",
	min_level = 1, level = 5, objectives = dirt(2), zone = "elandor_dawnmere_fields",
	rewards = {weight = 3, choices = {
		{item = "grug_gear:chest_cloth_patch", affixes = {{channel = "suffix", stat = "int"}}},
		{item = "grug_gear:chest_leather_light", affixes = {{channel = "prefix", stat = "dex"}}},
		{item = "grug_gear:chest_metal_bronze", affixes = {{channel = "prefix", stat = "str"}}}}}})
Q.register_quest("probe_cook_apples", {title = "Apples for the Pie", npc = COOK,
	description = "One apple short of a pie. Bring me one, please.",
	min_level = 1, level = 2, rewards = {weight = 1}, objectives = {{type = "item", item = "default:apple",
		count = 1}}, zone = "elandor_dawnmere_fields"})

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r57qsys_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function socket_pos(id)
	for _, socket in ipairs(grug_core.settlement_sockets_at("dawnmere")) do
		if socket.id == id then return socket.pos end
	end
end
local function npc_entity(socket)
	local pos = socket_pos(socket)
	for _, object in ipairs(core.get_objects_inside_radius(pos, 6)) do
		local entity = object:get_luaentity()
		if entity and entity._grug_start == "dawnmere" and entity._grug_socket == socket then return entity end
	end
end
local function face(player, target)
	local pos = player:get_pos()
	local dx, dz = target.x - pos.x, target.z - pos.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(0.12)
end

local SHOTS = {
	{name = "M1_story_marker", run = function(player)
		-- Between the elder (story marker: the story quest is available) and
		-- the cook (a plain marker), a little back.
		local elder, cook = socket_pos("hall_quest"), socket_pos("quest_cook")
		local mid = vector.multiply(vector.add(elder, cook), 0.5)
		local away = vector.normalize(vector.new(cook.z - elder.z, 0, elder.x - cook.x))
		local spread = vector.distance(elder, cook)
		local stand = vector.add(mid, vector.multiply(away, math.max(6, spread * 0.9)))
		stand.y = math.max(elder.y, cook.y) + 1
		player:set_pos(stand)
		face(player, mid)
		log(("elder %s cook %s stand %s; markers elder %s cook %s"):format(core.pos_to_string(elder),
			core.pos_to_string(cook), core.pos_to_string(vector.round(stand)),
			tostring(Q.marker_states(player)[ELDER]), tostring(Q.marker_states(player)[COOK])))
	end},
	{name = "M2_story_marker_close", run = function(player)
		local elder = socket_pos("hall_quest")
		local entity = npc_entity("hall_quest")
		local at = entity and entity.object:get_pos() or elder
		player:set_pos(vector.add(at, {x = 0, y = 0, z = -5}))
		face(player, at)
	end},
	{name = "D1_offer_choice", run = function(player)
		local entity = npc_entity("hall_quest")
		player:set_pos(vector.add(entity.object:get_pos(), {x = 0, y = 0, z = -3}))
		local rows = Q.npc_quests(player, ELDER)
		local index
		for i, row in ipairs(rows) do if row.id == "probe_choice_chest" then index = i end end
		log("elder rows " .. #rows .. ", the choice quest at " .. tostring(index))
		Q.open_npc(player, entity, index)
	end},
	{name = "D2_turnin_none", run = function(player)
		submit(player, "grug_quests:dialogue", {accept = "Accept"})
		player:get_inventory():add_item("main", "default:dirt 2")
		Q.open_npc(player, npc_entity("hall_quest"), "probe_choice_chest")
		submit(player, "grug_quests:dialogue", {turnin = "Complete"})
	end},
	{name = "D3_turnin_picked", run = function(player)
		submit(player, "grug_quests:dialogue", {choice_2 = "2"})
	end},
	{name = "Q2_map_story_icons", run = function(player)
		submit(player, "grug_quests:dialogue", {turnin = "Complete"})
		log("after Complete: " .. tostring(Q.status(player, "probe_choice_chest")) .. ", jerkin " ..
			tostring(player:get_inventory():contains_item("main", "grug_gear:chest_leather_light")))
		core.close_formspec(NAME, "grug_quests:dialogue")
		-- The elder's story quest is still on offer (the story icon), the
		-- cook's apples are ready (a plain icon).
		local W = grug_map.window
		W.open(player)
		local session = W.sessions[NAME]
		session.quest_selected, session.layer, session.zoom = nil, "quests", 4
		local centre = socket_pos("hall_quest")
		session.scroll_x, session.scroll_y = grug_map.atlas.centre_scroll(grug_map.atlas.view(), centre, 4)
		session.follow = false
		W.request(player)
		log("markers: elder " .. tostring(Q.marker_states(player)[ELDER]) .. ", cook " ..
			tostring(Q.marker_states(player)[COOK]))
	end},
	{name = "Q1_quest_log_story", run = function(player)
		Q.accept(player, "probe_story_road", ELDER)
		Q.accept(player, "probe_cook_apples", COOK)
		Q.accept(player, "dawnmere_hunt_01", ELDER)
		local W = grug_map.window
		local session = W.sessions[NAME]
		session.quest_selected, session.zoom, session.follow = "probe_story_road", 1, true
		W.request(player)
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
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.45)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local elder = socket_pos("hall_quest")
		state.phase = "emerge"
		core.emerge_area(vector.offset(elder, -40, -8, -40), vector.offset(elder, 40, 16, 40),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				player:set_pos(vector.offset(elder, 0, 1, -4))
				state.phase = "spawn"
				state.waited = 0
			end)
	elseif state.phase == "spawn" then
		-- The socket NPCs appear once their area is active.
		state.waited = state.waited + step
		if (npc_entity("hall_quest") and npc_entity("quest_cook")) or state.waited > 30 then
			log(("NPCs: elder %s, cook %s after %.1f s"):format(tostring(npc_entity("hall_quest") ~= nil),
				tostring(npc_entity("quest_cook") ~= nil), state.waited))
			state.phase = "shoot"
			state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
			log("READY")
		end
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
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
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
