-- Round 81 lane SOCIAL: before/after numbers (a comparison, not a target).
-- Runs the REAL files of the repository at arg[1] in the fake engines of
-- harness.lua; run it once on the base and once on the branch:
--
--   luajit tools/r81_social/measure.lua [repo]
--
-- Tags: 100 players in two towns, 1500 mob carriers and the players' own,
-- per simulated second (eight 1/8 s steps). Parties: 100 players in ten
-- parties of ten, per second of HUD polling, and one level-up. Housing:
-- 1000 activated claims, one 5 s cycle of stone.lua's pass.
local repo = arg and arg[1] or "."
local H = dofile((arg and arg[2] or repo) .. "/tools/r81_social/harness.lua")
local random = math.random
math.randomseed(81)

local function allocated(fn)
	if jit then jit.off() end
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	fn()
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then jit.on() end
	return grown
end

do
	local W = H.tags(repo)
	local players = {}
	for i = 1, 100 do
		local town = i % 2 == 0 and 0 or 400
		players[i] = W.player("p" .. i, i % 3 == 0 and "throng" or "accord",
			town + random(-80, 80), 0, random(-80, 80))
	end
	for i = 1, 1500 do
		local town = i % 2 == 0 and 0 or 400
		local fields = {name = "grug_mobs:wolf", _grug_disposition = "aggressive"}
		if i % 5 == 0 then fields = {name = "grug_mobs:guard_accord", _grug_faction = "accord"} end
		local entity = W.mob(fields, town + random(-150, 150), 0, random(-150, 150))
		grug_core.create_tag_carrier(entity.object)
	end
	for _, p in ipairs(players) do grug_core.create_tag_carrier(p, p.name) end
	for _ = 1, 3 do W.second() end
	W.counters.faction = 0
	local kb = allocated(function() W.second() end)
	local faction = W.counters.faction
	local t0 = os.clock()
	for _ = 1, 20 do W.second() end
	local ms = (os.clock() - t0) * 1000 / 20
	print(("tags: faction reads/s %d, allocated KB/s %.1f, CPU ms per simulated s %.2f"):format(
		faction, kb, ms))
end

do
	local W = H.parties(repo, H.party_groups(10, 10))
	for k = 1, 10 do
		for i = 1, 10 do
			W.join(W.player(("p%d_%d"):format(k, i), "accord", "mage", 10 + i))
		end
	end
	W.step(1)
	W.counters.properties, W.counters.meta, W.counters.level, W.counters.class = 0, 0, 0, 0
	W.step(1)
	print(("parties HUD poll per s: get_properties %d, player meta reads %d, level reads %d, class reads %d"):format(
		W.counters.properties, W.counters.meta, W.counters.level, W.counters.class))
	W.changes = {}
	local p = W.players.p3_3
	p.level = 40
	for _, fn in ipairs(W.level_callbacks) do fn(p) end
	local level = 0
	for _, change in ipairs(W.changes) do if change.reason == "level" then level = level + 1 end end
	print(("parties level-up: change callbacks with reason level %d"):format(level))
end

do
	local W = H.stone(repo)
	W.claims(1000)
	W.step(5) -- warm: one cycle
	W.counters.get_node, W.counters.all_claims = 0, 0
	local most, t0 = 0, os.clock()
	for _ = 1, 8 do
		local before = W.counters.get_node
		W.step(5 / 8)
		most = math.max(most, W.counters.get_node - before)
	end
	local ms = (os.clock() - t0) * 1000
	print(("housing 1000 claims, one 5 s cycle: get_node %d (most in one step %d), all_claims copies %d, CPU ms %.2f"):format(
		W.counters.get_node, most, W.counters.all_claims, ms))
	local M = W.model
	local t1 = os.clock()
	for _ = 1, 200 do M.expiry_scan(); M.draft_scan() end
	print(("housing scans with nothing due: CPU ms per scan pair %.3f"):format((os.clock() - t1) * 1000 / 200))
end
