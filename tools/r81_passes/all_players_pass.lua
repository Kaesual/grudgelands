-- Round 81 PASSES: a test double of grug_core.register_player_pass for the
-- portable fixtures that load a file with a per-player pass and test what
-- the pass does, not how it spreads the players over the join slots (that
-- is tools/r81_passes/portable_test.lua, with the real player_slots.lua).
-- It keeps the old shape of those passes: one accumulator per pass; once it
-- reaches the period, every connected player in that call, with `elapsed`
-- the accumulated time.
--
--   dofile(repo .. "/tools/r81_passes/all_players_pass.lua")(grug_core, core)
--
-- `core` is the fixture's stub: its register_globalstep at registration,
-- its get_connected_players at each pass.
return function(grug_core, core)
	function grug_core.register_player_pass(period, fn)
		local acc = 0
		core.register_globalstep(function(dtime)
			acc = acc + dtime
			if acc < period then
				return
			end
			local elapsed = acc
			acc = 0
			for _, player in ipairs(core.get_connected_players()) do
				fn(player, elapsed)
			end
		end)
	end
end
