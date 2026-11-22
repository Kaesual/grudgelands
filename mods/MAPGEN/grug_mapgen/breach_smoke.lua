-- The arena "Breach Road"'s two hearths smoke (Round 85 lane BUILD,
-- round85-plan.md ruling 3): one 1 s spawner per hearth every second
-- through the one particle path (grug_core.particles, the effect
-- "breach_hearth_smoke" in particle_effects.lua, at most 18 live puffs for
-- the pair). An unattached spawner of at most 1 s goes only to the players
-- within max_block_send_distance of it (particles.lua), so a hearth nobody is
-- near costs one call and no packet. No sound.
--
--   dofile(modpath .. "/breach_smoke.lua")(core, grug_core.particles, world)
-- `world`: `breach_layout.lua` world(site), whose `hearths` hold each puff
-- origin (x, z the hearth's node centre, smoke_y above the datum).
return function(core_api, particles, world)
	local EFFECT, INTERVAL = "breach_hearth_smoke", 1
	local frames = {}
	for index, h in ipairs(world.hearths) do
		frames[index] = {caster = {x = h.x, y = h.smoke_y, z = h.z}}
	end
	local function puff()
		for index = 1, #frames do particles.play(EFFECT, frames[index]) end
		core_api.after(INTERVAL, puff)
	end
	core_api.after(INTERVAL, puff)
	return #frames
end
