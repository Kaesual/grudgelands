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

-- Unchanged looks moved onto the helper: the critical hit's gold sparks and
-- the absorb shield's soak (combat.lua), the level-up burst (grug_xp).
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
register("level_up", {
	spawner(18, 0.2, {color = "#ffd100", fade = false,
		shape = {"box", {-0.5, 0.2, -0.5}, {0.5, 1.8, 0.5}}, vel = {{-1, 1, -1}, {1, 3, 1}},
		exp = {0.35, 0.7}, size = {1.5, 3}}),
})

------------------------------------------------------------------------------
-- Bosses and mob specials (Round 40 PM): the `boss` and `mob` cards of the
-- accepted catalogue, played from grug_mobs. Looks the catalogue keeps
-- ("stays", "keep the wind-up") or lists as unchanged are moved here with
-- today's numbers and textures (fade = false), so grug_particle_scale
-- reaches them too.
------------------------------------------------------------------------------

-- The kings' and Generals' signature (bosses.lua, a 2 s wind-up). Shatter:
-- an exact ring of stone dust on the blast radius (frame.reach) at the
-- king's feet, each mote living the whole wind-up (frame.time) ...
register("king_windup_ring", function(frame)
	local life = frame.time or 2
	return {single(40, {at = "target", color = "#b0a090", fade = false,
		shape = {"disc", {0, 0.1, 0}, frame.reach or 6, true}, vel = {{0, 0.1, 0}, {0, 0.1, 0}},
		exp = {life, life}, size = {3.5, 3.5}, glow = 4})}
end, {reach = 6, time = 2})

-- ... then a ring of dust bursting out along the ground to the radius
-- (frame.reach; 17 m/s in the catalogue reaches 6.4 m) and thrown chunks.
register("king_shatter", {
	single(48, {at = "target", color = "#b0a090", shape = {"disc", {0, 0.2, 0}, 0.6, true},
		radial = "reach", exp = {0.34, 0.34}, size = {3.5, 3.5}, glow = 0}),
	spawner(12, 0.05, {at = "target", tex = "grug_mobs_rock.png",
		shape = {"sphere", {0, 0.3, 0}, 1, false}, vel = {{-3, 4, -3}, {3, 7, 3}},
		acc = {0, -12, 0}, exp = {0.7, 0.9}, size = {3, 4}, glow = 0}),
})

-- Cleave: red motes rise across the cone in front of the king, one 1 s
-- spawner per wind-up second, then a red arc sweeps across it at 3.5 m.
register("king_cleave_windup", {
	spawner(16, 1, {color = "#c03030", shape = {"box", {1, 0.1, -2.5}, {6, 0.3, 2.5}},
		vel = {{0, 0.4, 0}, {0, 1, 0}}, exp = {0.6, 0.9}, size = {3, 4}, glow = 6}),
})
register("king_cleave", {
	spawner(30, 0.12, {color = "#e03a3a", shape = {"line", {3.5, 1.2, -2}, {3.5, 1, 2}},
		exp = {0.3, 0.4}, size = {3.5, 4.5}, glow = 10}),
})

-- The other kits' wind-up: motes in the kit's colour (frame.color, bosses.lua
-- KIT_COLORS) rise around the king, one 1 s spawner per wind-up second ...
register("king_aura", {
	spawner(20, 1, {color = "#e8c06a", shape = {"disc", {0, 0.2, 0}, 1, false},
		vel = {{0, 0.8, 0}, {0, 1.6, 0}}, exp = {0.7, 0.9}, size = {2.5, 3}, glow = 10}),
})

-- ... and the resolve: a rise in the kit's colour on each creature it
-- touched (a rallied guard, the regrowing troll, a summoned raider).
register("king_resolve", {
	spawner(12, 0.1, {at = "target", color = "#e8c06a", shape = {"disc", {0, 0.1, 0}, 0.6, false},
		vel = {{0, 1.5, 0}, {0, 2.5, 0}}, exp = {0.6, 0.8}, size = {2.5, 3}, glow = 10}),
})

-- Every elite's and rare's wind-up (telegraph.lua): today's orange smoke
-- burst, kept ...
register("elite_windup", {
	spawner(24, 0.4, {color = "#ff5a1e", fade = false,
		shape = {"box", {-0.7, 0.2, -0.7}, {0.7, 1.8, 0.7}}, vel = {{-0.5, 1, -0.5}, {0.5, 3, 0.5}},
		exp = {0.3, 0.7}, size = {2.5, 4}, glow = 8}),
})

-- ... and the cone hit: an orange arc sweeps across the 90 degree cone at
-- the elite's reach (frame.reach; the catalogue's 3 m and +-2.6 m).
register("elite_cone", function(frame)
	local reach = frame.reach or 3
	local half = reach * 2.6 / 3
	return {spawner(20, 0.12, {color = "#ff6a2a",
		shape = {"line", {reach, 1.1, -half}, {reach, 1, half}}, exp = {0.3, 0.4},
		size = {3, 4}, glow = 10})}
end, {reach = 3})

-- The dragons (boss_dragons.lua). Breath wind-up: glowing motes on a shell
-- gather into the breath's launch point (caster) and vanish there; frost or
-- fire by frame.color.
register("breath_windup", {
	spawner(20, 1, {color = "#8ee8ff", shape = {"sphere", {0, 0, 0}, 1.6, true},
		attract = {origin = {0, 0, 0}, strength = 1.5, kill = true}, exp = {0.7, 0.9},
		size = {2.5, 3.5}, glow = 14}),
})

-- The breath's muzzle burst (54 motes), kept, frost or fire.
local function breath_burst(tex)
	return {spawner(54, 0.35, {tex = tex, fade = false, shape = {"box", {-2, 0, -2}, {2, 3, 2}},
		vel = {{-3, 0.5, -3}, {3, 5, 3}}, exp = {0.4, 1.6}, size = {2, 6}, glow = 10})}
end
register("breath_burst_rime", breath_burst("default_snow.png^[colorize:#8ee8ff:120"))
register("breath_burst_scorch", breath_burst("default_item_smoke.png^[colorize:#ff7338:210"))

-- A breath bolt's trail: one mote per call at the bolt (caster); the bolt
-- plays it up to 12 times (boss_dragons.lua TUNING.trail_particles, under
-- the scale), frost or fire by frame.color.
register("breath_trail", {
	single(1, {color = "#8ee8ff", shape = {"box", {0, 0, 0}, {0, 0, 0}},
		vel = {{-0.3, -0.3, -0.3}, {0.3, 0.3, 0.3}}, exp = {0.3, 0.5}, size = {3, 4}, glow = 12}),
})

-- A breath bolt's ground patch (rime or scorch), kept.
register("dragon_patch_rime", {
	spawner(36, 0.25, {tex = "default_snow.png^[colorize:#8ee8ff:120", fade = false,
		shape = {"box", {-1, 0, -1}, {1, 0.5, 1}}, vel = {{-1, 0.2, -1}, {1, 1.5, 1}},
		exp = {0.4, 1.2}, size = {1.5, 3.5}, glow = 8}),
})
register("dragon_patch_scorch", {
	spawner(36, 0.25, {tex = "default_item_smoke.png^[colorize:#ff5a20:210", fade = false,
		shape = {"box", {-1, 0, -1}, {1, 0.5, 1}}, vel = {{-1, 0.2, -1}, {1, 1.5, 1}},
		exp = {0.4, 1.2}, size = {1.5, 3.5}, glow = 10}),
})

-- Stormscale's lightning: the warning ring, kept (32 motes on the exact
-- circle of frame.reach for the wind-up, frame.time) ...
register("lightning_ring", function(frame)
	local life = frame.time or 1.5
	return {single(32, {at = "target", tex = "grug_mobs_rock.png^[colorize:#fff27a:230",
		fade = false, shape = {"disc", {0, 0.1, 0}, frame.reach or 2, true}, exp = {life, life},
		size = {3, 3}, glow = 12})}
end, {reach = 2, time = 1.5})

-- ... and the strike: a white-yellow column drops from 8 m onto the spot,
-- with a ground burst.
register("lightning_strike", {
	spawner(24, 0.08, {at = "target", color = "#ffffff", shape = {"line", {0, 8, 0}, {0, 0.2, 0}},
		exp = {0.15, 0.25}, size = {4, 5}, glow = 14}),
	spawner(48, 0.05, {at = "target", color = "#fff27a", shape = {"disc", {0, 0.2, 0}, 0.4, true},
		radial = {6, 7}, exp = {0.3, 0.4}, size = {2.5, 3.5}, glow = 14}),
})

-- The wing gust: the warning ring at its reach (frame.reach) for the whole
-- wind-up (frame.time), kept ...
register("gust_windup", function(frame)
	local life = frame.time or 1.25
	return {single(40, {at = "target", tex = "default_item_smoke.png^[colorize:#d8eef4:150",
		fade = false, shape = {"disc", {0, 0.2, 0}, frame.reach or 8, true},
		vel = {{0, 0.3, 0}, {0, 0.3, 0}}, exp = {life, life}, size = {4, 4}, glow = 6})}
end, {reach = 8, time = 1.25})

-- ... and on release a pale ring blowing outward to the reach (frame.reach;
-- 18 m/s in the catalogue reaches 8 m).
register("gust_release", {
	single(48, {at = "target", color = "#d8eef4", shape = {"disc", {0, 0.5, 0}, 1, true},
		radial = "reach", exp = {0.39, 0.39}, size = {3.5, 3.5}, glow = 6}),
})

-- The take-off dust and the dive's wind-up, kept.
register("dragon_takeoff", {
	spawner(48, 0.4, {tex = "default_item_smoke.png^[colorize:#d8eef4:130", fade = false,
		shape = {"box", {-4, 0, -4}, {4, 3, 4}}, vel = {{-3, 0.5, -3}, {3, 5, 3}},
		exp = {0.4, 1.6}, size = {2, 6}, glow = 3}),
})
register("dive_windup", {
	spawner(80, 1, {tex = "default_item_smoke.png^[colorize:#ffd24a:190", fade = false,
		shape = {"box", {-5, 0, -5}, {5, 4, 5}}, vel = {{-3, 0.5, -3}, {3, 5, 3}},
		exp = {0.4, 1.6}, size = {2, 6}, glow = 10}),
})

-- The dive's slam: an exact gold ring out to the slam's reach (frame.reach;
-- 18 m/s in the catalogue reaches 7.1 m) and a dust cloud.
register("dive_slam", {
	single(48, {at = "target", color = "#e8c06a", shape = {"disc", {0, 0.2, 0}, 1, true},
		radial = "reach", exp = {0.34, 0.34}, size = {4, 4}, glow = 10}),
	spawner(32, 0.2, {at = "target", color = "#a89a80", shape = {"disc", {0, 0.2, 0}, 3, false},
		vel = {{-1, 0.5, -1}, {1, 2, 1}}, exp = {0.8, 1.2}, size = {5, 7}, glow = 0}),
})

-- Enrage at half health: a red burst around the dragon.
register("enrage", {
	spawner(96, 0.5, {at = "target", color = "#e03030", shape = {"box", {-7, 0, -7}, {7, 4, 7}},
		vel = {{-3, 0.5, -3}, {3, 5, 3}}, exp = {0.4, 1.6}, size = {2, 6}, glow = 10}),
})

-- A dark puff where a whelp appears.
register("whelp_arrival", {
	spawner(16, 0.1, {at = "target", color = "#40384a", shape = {"sphere", {0, 0.8, 0}, 0.6, false},
		vel = {{-1, 0.5, -1}, {1, 2, 1}}, exp = {0.6, 0.9}, size = {4, 6}, glow = 0}),
})

-- The Kraken's drag: bubbles around the dragged player.
register("kraken_drag", {
	spawner(16, 0.1, {at = "target", tex = "mobs_bubble_particle.png",
		shape = {"sphere", {0, 1, 0}, 0.6, false}, vel = {{-0.5, 1, -0.5}, {0.5, 2.5, 0.5}},
		exp = {0.5, 0.8}, size = {2, 3}, glow = 0}),
})

-- Mob specials (verbs.lua and the families). A spider's web: white strands
-- burst at the player's legs and sink.
register("web", {
	single(8, {at = "target", color = "#f0f0f0", shape = {"box", {-0.3, 0.2, -0.3}, {0.3, 0.6, 0.3}},
		vel = {{-1, -0.2, -1}, {1, 0.3, 1}}, acc = {0, -1, 0}, exp = {0.7, 0.9}, size = {2, 3},
		glow = 0}),
})

-- Poison: green bubbles rise from the player when poisoned, two on each tick.
local POISON_BUBBLE = "mobs_bubble_particle.png^[multiply:#7ac943"
register("poison", {
	single(6, {at = "target", tex = POISON_BUBBLE, shape = {"disc", {0, 0.8, 0}, 0.4, false},
		vel = {{0, 0.8, 0}, {0, 1.4, 0}}, exp = {0.5, 0.7}, size = {2, 2.5}, glow = 4}),
})
register("poison_tick", {
	single(2, {at = "target", tex = POISON_BUBBLE, shape = {"disc", {0, 0.8, 0}, 0.4, false},
		vel = {{0, 0.8, 0}, {0, 1.4, 0}}, exp = {0.5, 0.7}, size = {2, 2.5}, glow = 4}),
})

-- A pounce or a boar's charge: dust at the take-off (caster) and where it
-- lands (target); each moment plays with its own anchor only.
local POUNCE_DUST = {color = "#b8a27a", shape = {"box", {-0.4, 0.05, -0.4}, {0.4, 0.2, 0.4}},
	vel = {{-1.5, 0.4, -1.5}, {1.5, 1.2, 1.5}}, exp = {0.4, 0.6}, size = {3, 4}, glow = 0}
local function copy(def, extra)
	local out = {}
	for key, value in pairs(def) do out[key] = value end
	for key, value in pairs(extra or {}) do out[key] = value end
	return out
end
register("pounce", {
	single(6, copy(POUNCE_DUST)),
	single(6, copy(POUNCE_DUST, {at = "target"})),
})

-- The ambusher breaking cover: a splash, or a dirt burst on land
-- (frame.color).
register("ambush", {
	spawner(14, 0.05, {at = "target", color = "#9cc8e0", shape = {"disc", {0, 0.2, 0}, 0.6, false},
		vel = {{-2, 2, -2}, {2, 4, 2}}, acc = {0, -10, 0}, exp = {0.5, 0.7}, size = {2.5, 3.5},
		glow = 0}),
})

-- The ooze's damage aura, on a tick that hurt someone: a few green bubbles
-- pop on the ground within its radius (frame.reach).
register("ooze_aura", function(frame)
	return {single(5, {at = "target", tex = "mobs_bubble_particle.png^[multiply:#6aa83a",
		shape = {"disc", {0, 0.1, 0}, frame.reach or 2, false}, vel = {{0, 0.3, 0}, {0, 0.8, 0}},
		exp = {0.5, 0.7}, size = {2.5, 3.5}, glow = 2})}
end, {reach = 2})

-- The treant's slowing aura, while it slows someone: brown leaves drift
-- down within its 3 m.
register("treant_aura", {
	single(5, {at = "target", color = "#7a5a32", shape = {"disc", {0, 3, 0}, 3, false},
		vel = {{-0.3, -0.8, -0.3}, {0.3, -0.5, 0.3}}, exp = {1.8, 2.2}, size = {2.5, 3}, glow = 0}),
})

-- The Oerkki's blink: a violet puff where it leaves (caster) and today's
-- puff where it arrives (target, kept).
register("oerkki_blink", {
	spawner(12, 0.2, {color = "#7030a0", shape = {"box", {-0.5, 0, -0.5}, {0.5, 1, 0.5}},
		vel = {{-2, 0, -2}, {2, 3, 2}}, exp = {0.3, 0.7}, size = {1.5, 3}, glow = 10}),
	spawner(12, 0.2, {at = "target", color = "#7030a0", fade = false,
		shape = {"box", {-0.4, 0, -0.4}, {0.4, 1.4, 0.4}}, exp = {0.2, 0.5}, size = {1, 2},
		glow = 4}),
})

-- The Wisp's blink: pale puffs where it leaves and where it arrives.
local WISP_PUFF = {color = "#dff4ff", shape = {"sphere", {0, 1, 0}, 0.3, false},
	vel = {{-0.8, 0, -0.8}, {0.8, 1, 0.8}}, exp = {0.4, 0.6}, size = {2, 3}, glow = 12}
register("wisp_blink", {
	single(5, copy(WISP_PUFF)),
	single(5, copy(WISP_PUFF, {at = "target"})),
})

-- A mob projectile's impact (caster = the projectile): a small puff tinted
-- per projectile (frame.color, the arrow's `impact`).
register("projectile_impact", {
	single(5, {color = "#a08860", shape = {"sphere", {0, 0, 0}, 0.15, false},
		vel = {{-1.5, -0.5, -1.5}, {1.5, 1.5, 1.5}}, acc = {0, -8, 0}, exp = {0.3, 0.45},
		size = {1.5, 2}, glow = 0}),
})

-- Unchanged looks moved onto the helper: the Bog Witch's hex bottle and the
-- Rift Spawn's burst.
register("hex_bottle", {
	spawner(16, 0.25, {at = "target", color = "#7b2fa3", fade = false,
		shape = {"box", {-0.4, 0, -0.4}, {0.4, 1.4, 0.4}}, exp = {0.2, 0.6}, size = {1, 2.5},
		glow = 5}),
})
register("rift_spawn_burst", {
	spawner(32, 0.25, {tex = "mobs_tnt_smoke.png^[colorize:#6d36b5:70", fade = false,
		shape = {"box", {-0.5, 0, -0.5}, {0.5, 1.5, 0.5}}, vel = {{-3, 0, -3}, {3, 5, 3}},
		exp = {0.3, 0.8}, size = {2, 5}, glow = 5}),
})
