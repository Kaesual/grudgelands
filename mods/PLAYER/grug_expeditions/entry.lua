-- Getting in and out by waystone (Round 72, docs/planning/round72-plan.md section
-- 2.10). The Expeditions tab, which grug_home shows on every waystone outside the
-- Expeditions and on the Claim Stone, lists the run of the player's owner while they
-- may enter it and enters it as M.enter does at the registrar; the two stones inside
-- open the ordinary waystone window. Since Round 72.1 the tab also shows the run's
-- state and, for its leader, Finish or Cancel, and the stones inside have the tab
-- with that alone, never an Enter row. Every rule is runs.lua's.
local M = grug_expeditions

local NOTHING = "You have no Expedition to enter. The Expedition Registrar in a capital's " ..
	"guild house opens one."

local function notice(player, text)
	grug_core.feed(player, "notice", text, "expedition")
end

grug_home.register_expedition_tab({
	-- An owner has one Expedition at a time, so at most one row; with none the one
	-- line says why: no run, or the run's own refusal (being prepared, level, full).
	rows = function(player)
		local run = M.run_of(player)
		if not run then return {}, NOTHING end
		local ok, why = M.may_enter(player, run)
		if not ok then return {}, why end
		return {{id = tostring(run.id), label = ("%s, level %d"):format(
			M.definition(run.expedition).name, run.level)}}
	end,
	-- The way back leads to the waystone of the trip in; from the Claim Stone to the
	-- waystone of the innkeeper home, so a way back always names a waystone.
	enter = function(player, id, waystone, still)
		local run = M.run_of(player)
		if not run or tostring(run.id) ~= id then return false, "This Expedition has ended." end
		if not waystone then
			local inn = grug_home.innkeeper(player)
			waystone = inn and inn.id
		end
		return M.enter(player, waystone, still)
	end,
	-- The run of the player's owner below the rows: its state line, and for its
	-- leader Finish once it may end, else Cancel, which asks first. Nothing while it
	-- is prepared: the rows' line says so.
	actions = function(player)
		local run = M.run_of(player)
		if not run or run.state == "preparing" then return nil end
		local buttons = {}
		if M.can_finish(player, run) then
			buttons[1] = {action = "finish", label = "Finish"}
		elseif M.can_cancel(player, run) then
			buttons[1] = {action = "cancel", label = "Cancel", confirm = M.CANCEL_CONFIRM}
		end
		return {id = tostring(run.id), text = M.state_text(run), buttons = buttons}
	end,
	act = function(player, id, action)
		local run = M.run_of(player)
		if not run or tostring(run.id) ~= id then return false, "This Expedition has ended." end
		if action == "finish" then return M.finish(player) end
		if action == "cancel" then return M.cancel(player) end
		return false, "That is not possible here."
	end,
})

-- Both stones inside: the player's own waystones and Claim Stone, by the waystones'
-- rules from this stone, and the Expeditions tab without its rows (Round 72.1): the
-- run's state, Finish and Cancel. A trip out keeps the place and ends no run: its teleport
-- tells runs.lua, which takes the player off the run's inside and, through the leave
-- hook, off every pack's list.
function M.use_waystone(player, pos)
	local run = M.run_inside(player)
	if not run then return notice(player, "You are not in an Expedition.") end
	grug_home.show_waystones(player, {id = "expedition:" .. run.id,
		label = M.definition(run.expedition).name, pos = vector.new(pos or player:get_pos())})
end
