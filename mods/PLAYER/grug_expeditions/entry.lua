-- Getting in and out by waystone (Round 72, docs/planning/round72-plan.md section
-- 2.10). The Expeditions tab, which grug_home shows on every waystone outside the
-- Expeditions and on the Claim Stone, lists the run of the player's owner while they
-- may enter it and enters it as M.enter does at the registrar; the two stones inside
-- open the ordinary waystone window without that tab. Every rule is runs.lua's.
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
})

-- Both stones inside: the player's own waystones and Claim Stone, by the waystones'
-- rules from this stone. A trip out keeps the place and ends no run: its teleport
-- tells runs.lua, which takes the player off the run's inside and, through the leave
-- hook, off every pack's list.
function M.use_waystone(player, pos)
	local run = M.run_inside(player)
	if not run then return notice(player, "You are not in an Expedition.") end
	grug_home.show_waystones(player, {id = "expedition:" .. run.id,
		label = M.definition(run.expedition).name, pos = vector.new(pos or player:get_pos())})
end
