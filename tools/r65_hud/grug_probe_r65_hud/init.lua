-- Disposable engine probe (Round 65 lane HUD): the boxed quest HUD for
-- screenshots. Never shipped: tools/r65_hud/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r62_templatefix's
-- probe.
--
-- The character is set to level 20 and given ten active, tracked quests of
-- mixed levels (the longest title among them) by writing the quest state;
-- the tracker's 0.5 s poll draws them. Shot 1 looks at a bright midday sky
-- over the start town; shot 2 follows a level-up to 30 and three untracked
-- quests (colours, order and the stack's centring change).

local P = "[r65hud] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r65hud_settle") or "") or 3
local KEY = "grug_quests:state"

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r65hud_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- Ten quests: the first quest at each of these levels (by id), and the
-- quest with the longest title.
local LEVELS = {4, 10, 12, 18, 20, 20, 22, 25, 34, 45}
local function pick()
	local ids = {}
	for id in pairs(grug_quests.registered_quests) do ids[#ids + 1] = id end
	table.sort(ids)
	local chosen, used, longest = {}, {}, nil
	for _, id in ipairs(ids) do
		local def = grug_quests.registered_quests[id]
		if not longest or #def.title > #grug_quests.registered_quests[longest].title then
			longest = id
		end
	end
	chosen[1], used[longest] = longest, true
	for _, level in ipairs(LEVELS) do
		for _, id in ipairs(ids) do
			if #chosen < 10 and not used[id] and grug_quests.registered_quests[id].level == level then
				chosen[#chosen + 1], used[id] = id, true
				break
			end
		end
	end
	return chosen
end

local SHOTS = {
	{name = "H1_ten_tracked_level20", run = function(player)
		grug_xp.set_xp(player, grug_xp.xp_for_level(20))
		local ids = pick()
		local s = {active = {}, completed = {}, tracked = {}, hud = true}
		for _, id in ipairs(ids) do
			s.active[id] = {}
			s.tracked[#s.tracked + 1] = id
			local def = grug_quests.registered_quests[id]
			log(("quests %s level %d %q"):format(id, def.level, def.title))
		end
		player:get_meta():set_string(KEY, core.serialize(s))
		state.ids = ids
	end},
	{name = "H2_level30_three_untracked", run = function(player)
		grug_xp.set_xp(player, grug_xp.xp_for_level(30))
		for i = 2, 4 do grug_quests.set_tracked(player, state.ids[i], false) end
		log("level " .. grug_xp.get_level(player))
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
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		player:set_pos(vector.offset(player:get_pos(), 0, 6, 0))
		player:set_look_vertical(-0.25)
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
