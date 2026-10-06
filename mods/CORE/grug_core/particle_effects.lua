-- The particle effect catalogue (Round 40): every effect the game plays,
-- as emitters for grug_core.particles.play (particles.lua explains the
-- fields). The player-skill effects are the accepted V3 catalogue
-- (tools/r40_v3/effects.py, round40-plan.md §2.15): counts, times, shapes,
-- colours and sizes as the user took them, single colour, no art sprite.
-- Counts are before grug_particle_scale. Where the build differs from the
-- catalogue, the line says so (and effects.py carries the same numbers).

local register = grug_core.particles.register
local FIRE = "mobs_fire_particle.png"

local function spawner(n, time, def)
	def.kind, def.n, def.time = "spawner", n, time
	return def
end

local function single(n, def)
	def.kind, def.n = "single", n
	return def
end

-- Ice Nova (and Frostbind's ranged nova): a flat ring of frost motes from the
-- feet out to the nova's radius in a third of a second, over a slower mist.
-- The ring's speed carries it to frame.reach exactly (14 m/s in the
-- catalogue reaches 5.2 m for the 5 m nova; "reach" lands on the radius).
register("ice_nova", {
	single(48, {color = "#bfe8ff", shape = {"disc", {0, 0.25, 0}, 0.4, true},
		radial = "reach", exp = {0.34, 0.34}, size = {2.5, 2.5}, glow = 10}),
	spawner(16, 0.1, {color = "#e6f6ff", shape = {"disc", {0, 0.15, 0}, 0.6, false},
		radial = {3, 5}, exp = {0.6, 0.8}, size = {4, 6}, glow = 4}),
})

-- Fireball impact (Brand's 2 m splash shows through the same impact):
-- embers in a half dome that fall back, and a short dark puff.
register("fireball", {
	spawner(28, 0.05, {at = "target", tex = FIRE, shape = {"sphere", {0, 1, 0}, 0.2, false},
		vel = {{-5, 1, -5}, {5, 6, 5}}, acc = {0, -12, 0}, exp = {0.4, 0.8},
		size = {1, 2}, glow = 14}),
	spawner(10, 0.1, {at = "target", color = "#3a2a22", shape = {"sphere", {0, 1, 0}, 0.4, false},
		vel = {{-0.6, 0.5, -0.6}, {0.6, 1.5, 0.6}}, exp = {0.8, 1.2}, size = {3, 5}, glow = 0}),
})

-- Smite: no projectile; motes appear 2.5 m above the target, slam down onto
-- it and vanish on contact, and a small flash ring at its feet.
register("smite", {
	spawner(24, 0.12, {at = "target", color = "#fff4c2", shape = {"disc", {0, 3.3, 0}, 0.9, false},
		attract = {origin = {0, 1, 0}, strength = 5, kill = true}, exp = {0.25, 0.3},
		size = {2, 3}, glow = 14}),
	spawner(12, 0.05, {at = "target", color = "#ffe9a0", shape = {"disc", {0, 0.15, 0}, 0.3, true},
		radial = {4, 5}, exp = {0.2, 0.3}, size = {2, 2.5}, glow = 14}),
})

-- Mighty Blow: a diagonal red slash hanging in front of the warrior (upper
-- right to lower left), plus today's six blood drops on the target, kept
-- exactly as they were (no fade).
register("mighty_blow", {
	spawner(20, 0.08, {color = "#d8263a", shape = {"line", {1.2, 2, -0.5}, {1.2, 0.6, 0.6}},
		exp = {0.3, 0.4}, size = {3, 4}, glow = 10}),
	spawner(6, 0.2, {at = "target", tex = "mobs_blood.png", fade = false,
		shape = {"box", {-0.5, 0, -0.5}, {0.5, 1, 0.5}}, vel = {{-2, 0, -2}, {2, 3, 2}},
		exp = {0.3, 0.7}, size = {1.5, 3}, glow = 10}),
})

-- A skill arrow's trail: an unattached spawner along the launch line
-- (frame.from -> frame.to) over the flight time (frame.time, at most 1 s),
-- tinted per skill (frame.color). grug_projectiles plays it for a launch
-- that asks for it.
register("skill_arrow", {
	spawner(30, "frame", {color = "#e9e4d0", shape = {"line", "frame"},
		vel = {{-0.2, -0.1, -0.2}, {0.2, 0.2, 0.2}}, exp = {0.3, 0.45}, size = {1, 1.5},
		glow = 6}),
})

-- Charge: a low dust ring around the target on arrival ...
register("charge_ring", {
	spawner(14, 0.05, {at = "target", color = "#b8a27a", shape = {"disc", {0, 0.1, 0}, 0.5, true},
		radial = {4, 5}, exp = {0.3, 0.45}, size = {3, 4}, glow = 0}),
})

-- ... and the dust kicked up along the dash's ground path, frame.from to
-- frame.to over frame.time (grug_abilities.charge_dust lifts the feet
-- positions 0.1 m).
register("charge_dust", {
	spawner(18, "frame", {color = "#b8a27a", shape = {"line", "frame"},
		vel = {{-0.5, 0.3, -0.5}, {0.5, 1.2, 0.5}}, exp = {0.4, 0.7}, size = {2.5, 4}, glow = 0}),
})

-- Hamstring: a short low red cut across the target's legs.
register("hamstring", {
	single(6, {at = "target", color = "#c0303f", shape = {"line", {-0.4, 0.4, -0.3}, {0.4, 0.35, 0.3}},
		exp = {0.25, 0.3}, size = {2.5, 3}, glow = 8}),
})

-- Taunt: a few orange motes jump up above the target's head.
register("taunt", {
	single(6, {at = "target", color = "#ff8a3a", shape = {"box", {-0.2, 2.1, -0.2}, {0.2, 2.3, 0.2}},
		vel = {{-0.2, 1.2, -0.2}, {0.2, 2, 0.2}}, exp = {0.5, 0.7}, size = {2.5, 3}, glow = 12}),
})

-- Bellow (Taunt's area talent): an orange shock ring along the ground out to
-- the Bellow radius (frame.reach; 20 m/s in the catalogue for 8 m).
register("bellow", {
	single(40, {color = "#ff8a3a", shape = {"disc", {0, 0.2, 0}, 0.4, true}, radial = "reach",
		exp = {0.4, 0.4}, size = {2.5, 2.5}, glow = 10}),
})

-- Hold Ground: a golden ring of motes at the feet that rises slowly.
register("hold_ground", {
	spawner(24, 0.1, {color = "#e8c06a", shape = {"disc", {0, 0.1, 0}, 1, true},
		vel = {{0, 0.5, 0}, {0, 1.2, 0}}, exp = {0.7, 0.9}, size = {2, 2.5}, glow = 12}),
})

-- Blink: violet motes rush into the spot the mage leaves (caster) and burst
-- at the arrival point (target).
register("blink", {
	spawner(14, 0.1, {color = "#b06aff", shape = {"sphere", {0, 1, 0}, 1, true},
		attract = {origin = {0, 1, 0}, strength = 3, kill = true}, exp = {0.3, 0.4},
		size = {2, 2.5}, glow = 12}),
	spawner(14, 0.05, {at = "target", color = "#b06aff", shape = {"sphere", {0, 1, 0}, 0.2, false},
		radial = {3, 4}, exp = {0.3, 0.4}, size = {2, 2.5}, glow = 12}),
})

-- Cinderfall: embers rain from four metres into the real circle
-- (frame.reach, 3 m without the talent; the box keeps the catalogue's
-- 2.1 m half width per 3 m).
register("cinderfall", function(frame)
	local half = 2.1 * (frame.reach or 3) / 3
	return {spawner(36, 0.4, {at = "target", tex = FIRE,
		shape = {"box", {-half, 4, -half}, {half, 4, half}},
		vel = {{-0.3, -10, -0.3}, {0.3, -8, 0.3}}, exp = {0.4, 0.5}, size = {1.5, 2.5},
		glow = 14})}
end, {reach = 3})

-- Glacial Ward: frost motes appear on a shell around the mage and drift in.
register("glacial_ward", {
	spawner(20, 0.2, {color = "#bfe8ff", shape = {"sphere", {0, 1, 0}, 1.1, true},
		attract = {origin = {0, 1, 0}, strength = 2.5, kill = true}, exp = {0.4, 0.5},
		size = {2, 2.5}, glow = 10}),
})

-- Heal: golden-green motes rise around the healed player; Hearten's splash
-- gives each splashed ally four of them.
register("heal", {
	spawner(12, 0.1, {at = "target", color = "#d8f0a0", shape = {"disc", {0, 0.1, 0}, 0.5, false},
		vel = {{0, 1.5, 0}, {0, 2.5, 0}}, exp = {0.7, 0.9}, size = {2, 2.5}, glow = 12}),
})
register("heal_splash", {
	spawner(4, 0.1, {at = "target", color = "#d8f0a0", shape = {"disc", {0, 0.1, 0}, 0.5, false},
		vel = {{0, 1.5, 0}, {0, 2.5, 0}}, exp = {0.7, 0.9}, size = {2, 2.5}, glow = 12}),
})

-- Shield: a pale-gold shell of motes flashes around the shielded player.
register("shield_spell", {
	spawner(18, 0.05, {at = "target", color = "#ffe9a0", shape = {"sphere", {0, 1, 0}, 0.9, true},
		exp = {0.35, 0.45}, size = {2, 2.5}, glow = 12}),
})

-- Mend: three motes rise from the player on the cast and on each tick.
register("mend", {
	single(3, {at = "target", color = "#d8f0a0", shape = {"disc", {0, 0.6, 0}, 0.4, false},
		vel = {{0, 1.2, 0}, {0, 1.8, 0}}, exp = {0.6, 0.8}, size = {2, 2.5}, glow = 12}),
})

-- Word of Ruin: dark violet motes peel off the target and stream to the
-- priest's chest (an attractor at the caster).
register("word_of_ruin", {
	spawner(16, 0.3, {at = "target", color = "#6a2a9a", shape = {"sphere", {0, 1, 0}, 0.5, false},
		attract = {at = "caster", origin = {0, 1.2, 0}, strength = 2, kill = true},
		exp = {0.6, 0.7}, size = {2, 2.5}, glow = 6}),
})

-- Snare Shot landed: a green ring springs out around the target's legs.
register("snare_hit", {
	spawner(10, 0.05, {at = "target", color = "#79a65a", shape = {"disc", {0, 0.4, 0}, 0.2, true},
		radial = {2, 2.5}, exp = {0.4, 0.5}, size = {2, 2.5}, glow = 6}),
})

-- Pinning Shot landed: teal motes drop onto the target's feet.
register("pinning_hit", {
	single(8, {at = "target", color = "#4f8f67", shape = {"disc", {0, 1.6, 0}, 0.5, false},
		vel = {{0, -8, 0}, {0, -6, 0}}, exp = {0.2, 0.25}, size = {2, 2.5}, glow = 8}),
})

-- Sidestep: a pale-green shimmer around the scout.
register("sidestep", {
	single(8, {color = "#a8e0c0", shape = {"sphere", {0, 1, 0}, 0.6, true},
		vel = {{0, 0.2, 0}, {0, 0.6, 0}}, exp = {0.35, 0.45}, size = {2, 2.5}, glow = 10}),
})

-- Sprint: a puff of dust kicked up behind the scout.
register("sprint", {
	single(8, {color = "#b8a27a", shape = {"box", {-0.6, 0.05, -0.3}, {-0.2, 0.2, 0.3}},
		vel = {{-2, 0.5, -0.5}, {-1, 1.5, 0.5}}, exp = {0.4, 0.6}, size = {3, 4}, glow = 0}),
})

-- Opening landed: a brief white flash of sparks at the target.
register("opening", {
	single(6, {at = "target", color = "#ffffff", shape = {"sphere", {0, 1.1, 0}, 0.15, false},
		vel = {{-2, -1, -2}, {2, 2, 2}}, exp = {0.15, 0.2}, size = {1.5, 2}, glow = 14}),
})

-- The shared proc flash: a quick ring of motes in the proc's colour
-- (frame.color, grug_core.PROC_COLORS) rises around the player.
register("proc", {
	single(8, {color = "#ffcf40", shape = {"disc", {0, 0.3, 0}, 0.6, true},
		vel = {{0, 1.5, 0}, {0, 2.2, 0}}, exp = {0.4, 0.5}, size = {2, 2.5}, glow = 12}),
})

-- One colour per proc (the talent windows and trinket specials that fire).
grug_core.PROC_COLORS = {
	ruination = "#ff5a3a",    -- Warrior: Mighty Blow's window
	unbroken = "#e8c06a",     -- Warrior: low-health armor window
	whitehot = "#ffcf40",     -- Mage: a critical Fireball
	last_word = "#a66bd4",    -- Priest: Word of Ruin at low health
	untouchable = "#a8e0c0",  -- Scout: low-health dodge window
	last_light = "#ffe9a0",   -- trinket: the low-health shield
	reclaimer = "#7ae08a",    -- trinket: the kill restore
}

-- Plays the proc flash around `player` in the colour of `proc`.
function grug_core.proc_flash(player, proc)
	local pos = player and player:get_pos()
	if pos then
		grug_core.particles.play("proc", {caster = pos, color = grug_core.PROC_COLORS[proc]})
	end
end

-- Unchanged looks moved onto the helper (combat.lua): the critical hit's
-- gold sparks and the absorb shield's soak.
register("crit", {
	spawner(8, 0.15, {at = "target", color = "#ffd100", fade = false,
		shape = {"box", {-0.4, 0.6, -0.4}, {0.4, 1.4, 0.4}}, vel = {{-1, 1, -1}, {1, 3, 1}},
		exp = {0.3, 0.6}, size = {2, 3}}),
})
register("absorb", {
	spawner(6, 0.15, {at = "target", color = "#ffe9a0", fade = false,
		shape = {"box", {-0.4, 0.4, -0.4}, {0.4, 1.4, 0.4}}, vel = {{-1, 0, -1}, {1, 2, 1}},
		exp = {0.2, 0.5}, size = {1.5, 2.5}}),
})
