-- Disposable engine probe (Round 52 lane GRAPH): the new talent page's admin
-- preview and the Talents & Skills page with a scrolled skill row, for
-- screenshots. Never shipped: tools/r52_graph/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) is the Round 48 HUD probe's.
--
-- After the character is made (Accord, Human, Scout) the probe gives it the
-- `server` privilege, opens /talent_preview's page for every class (both
-- tabs, one selected node) and then shows the Talents & Skills
-- page as a form of its own (the server cannot open the inventory) with
-- every registered ability in the skill row -- in this probe only -- at the
-- start and scrolled. Each view logs "SHOT <name>" after SETTLE seconds.
local P = "[r52graph] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r52graph_settle") or "") or 3
local function log(msg) core.log("action", P .. msg) end

local graph = grug_classes.graph
local PREVIEW = "grug_classes:talent_preview"

local function receive(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function node_field(id)
	for index, node_id in ipairs(graph.node_ids) do
		if node_id == id then return "grug_graph_node_" .. index end
	end
end

local function show_talents(player, scroll)
	core.close_formspec(NAME, PREVIEW)
	local context = sfinv.get_or_create_context(player)
	context.page = "grug_classes:talents"
	context.grug_skills_scroll = scroll
	core.show_formspec(NAME, "grug_probe_r52_graph:talents", sfinv.get_formspec(player, context))
end

local function tab(index)
	return function(player) receive(player, PREVIEW, {["grug_graph_tab_" .. index] = "x"}) end
end
local function open(class_id)
	return function(player) graph.open_preview(player, class_id) end
end
-- Both trees of every class (the art step: the picked backgrounds and icons).
local SHOTS = {
	{name = "P1_preview_ember", act = open("mage")},
	{name = "P2_preview_rime", act = tab(2)},
	{name = "P3_preview_rime_cold_shock", act = function(player)
		receive(player, PREVIEW, {[node_field("cold_shock")] = "x"})
	end},
	{name = "P4_preview_bulwark", act = open("warrior")},
	{name = "P5_preview_ruin", act = tab(2)},
	{name = "P6_preview_mercy", act = open("priest")},
	{name = "P7_preview_reckoning", act = tab(2)},
	{name = "P8_preview_quarry", act = open("scout")},
	{name = "P9_preview_veil", act = tab(2)},
	{name = "S1_skills_row_start", act = function(player) show_talents(player, 0) end},
	{name = "S2_skills_row_scrolled", act = function(player) show_talents(player, 60) end},
}

-- Every registered ability counts as owned for the probe's character, so the
-- skill row holds more than eight (the shipped classes have at most eight).
local function own_everything()
	local is_unlocked = grug_abilities.is_unlocked
	function grug_abilities.is_unlocked(player, id)
		if player:get_player_name() == NAME then
			return grug_abilities.registered[id] ~= nil
		end
		return is_unlocked(player, id)
	end
	local unlocked_ids = grug_abilities.unlocked_ids
	function grug_abilities.unlocked_ids(player)
		if player:get_player_name() ~= NAME then return unlocked_ids(player) end
		local ids = {}
		for _, def in ipairs(grug_abilities.universal) do ids[#ids + 1] = def.id end
		for _, class_id in ipairs(grug_classes.class_ids) do
			for _, def in ipairs(grug_abilities.by_class[class_id] or {}) do
				ids[#ids + 1] = def.id
			end
		end
		return ids
	end
end

local state = {phase = "wait", clock = 0}

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r52graph_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
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
			receive(player, "", {faction_accord = "Accord"})
			receive(player, "", {race_human = "Human"})
			receive(player, "", {class_scout = "Scout"})
			receive(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local privs = core.get_player_privs(NAME)
		privs.server = true
		core.set_player_privs(NAME, privs)
		own_everything()
		grug_skills.rebuild(player)
		log(("skill row: %d skills"):format(#grug_abilities.unlocked_ids(player)))
		log(("window information: %s"):format(
			core.write_json(core.get_player_window_information(NAME) or {})))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("CHECK grug_classes:talents written: " ..
				tostring(player:get_meta():get_string("grug_classes:talents")))
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then shot.act(player) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log(("SHOT %s"):format(shot.name))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
