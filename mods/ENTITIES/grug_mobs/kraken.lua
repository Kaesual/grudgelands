-- Kraken Guard: the deep-sea deterrent of the open sea (world.md §2b,
-- biomes_mobs.md §3.1). Level 100 is HAND-SET — the one exception to the
-- level field (grug_core.mob_level_at returns nil on the open water
-- surface). It exists to make sea travel a bad idea, not as content:
-- no drops, no XP, and it never leaves the open sea (leash below).

-- Slack before the leash bites: the Kraken may chase a swimmer this far
-- into the coastal ocean, then it lets go. Well short of the 1500-node
-- coastal band, so it can never reach a beach.
local LEASH_SLACK = 200
-- Continent centre line (grug_core geometry): the open sea lies AWAY from it.
local SEAT_Z = (grug_core.CONTINENT_Z_MIN + grug_core.CONTINENT_Z_MAX) / 2

-- Has the Kraken strayed more than LEASH_SLACK nodes into the coastal
-- ocean? Probes open_sea_at at a point pushed LEASH_SLACK nodes away from
-- the nearer continent centre, i.e. in the direction the open sea lies.
local function strayed(pos)
	local cz = pos.z >= 0 and SEAT_Z or -SEAT_Z
	local out = vector.normalize(vector.new(pos.x, 0, pos.z - cz))
	return not grug_core.open_sea_at(vector.new(
		pos.x + out.x * LEASH_SLACK, pos.y, pos.z + out.z * LEASH_SLACK))
end

grug_mobs.register_mob("grug_mobs:kraken", {
	description = "Kraken Guard",
	type = "monster",
	passive = false,
	-- A deterrent, not content: killing it must never be an XP or loot
	-- farm at the world edge.
	_grug_xp_reward = 0,
	_grug_spawn_check = grug_core.open_sea_at,

	-- L100 stats from the combat_stats formulas, hand-set for level 100:
	-- hp 15 + 5*100, damage 2 + 0.4*100. Armor 70 = rare tier.
	hp_min = 515,
	hp_max = 515,
	armor = 70,
	damage = 42,
	reach = 4, -- huge model, tentacles
	attack_type = "dogfight",
	attack_players = true,
	group_attack = false,
	knock_back = 0, -- an oversized boss must not be pushed around

	-- Swims: mobs_redo treats fly + fly_in as "moves inside this node type",
	-- so the Kraken stays in water. floats is inert while fly is set
	-- (falling() bails out for flying mobs) but keeps the def honest.
	fly = true,
	fly_in = "default:water_source",
	floats = 1,
	jump = false,
	fall_damage = 0,
	fear_height = 0,
	walk_velocity = 3,
	run_velocity = 5, -- must outswim a player
	view_range = 20,

	visual = "mesh",
	mesh = "grug_mobs_kraken.b3d",
	textures = {{"grug_mobs_kraken.png"}},
	visual_size = {x = 6, y = 6},
	collisionbox = {-0.8, 0.0, -0.8, 0.8, 1.8, 0.8},
	makes_footstep_sound = false,

	-- Frame ranges from VoxeLibre's squid def (one swim loop); punch reuses
	-- it, the model has no attack animation.
	animation = {
		stand_start = 1, stand_end = 60, stand_speed = 15,
		walk_start = 1, walk_end = 60, walk_speed = 25,
		run_start = 1, run_end = 60, run_speed = 40,
		punch_start = 1, punch_end = 60, punch_speed = 40,
	},

	drops = {}, -- no drops (biomes_mobs.md §3.1)

	water_damage = 0,
	lava_damage = 0,
	light_damage = 0,

	-- Verb "drags under": on top of the melee damage the hit yanks the
	-- victim downward, so a swimmer loses the surface (and their breath).
	-- mobs_redo calls this as self:custom_attack(self, p), so the extra
	-- arguments are useless — the current target is self.attack. Returning
	-- true lets the normal melee damage run afterwards.
	custom_attack = function(self)
		local target = self.attack
		if not target then
			return true
		end
		-- Same target resolution mobs_redo uses for the punch itself: a
		-- rider is dragged down together with whatever carries them.
		target = target:get_attach() or target
		target:add_velocity(vector.new(0, -8, 0))
		return true
	end,

	-- Leash: the Kraken guards the open sea and must never follow a swimmer
	-- back towards the coast where low-level players are. Once it has
	-- strayed it drops its target and holds position; the check re-runs
	-- once a second, so a re-acquired target is dropped again. (mobs_redo
	-- despawns monsters with no player nearby anyway — belt and braces.)
	do_custom = function(self, dtime)
		self.temp = self.temp or {} -- runtime only, never hits staticdata
		local t = self.temp
		t.grug_leash_timer = (t.grug_leash_timer or 0) + dtime
		if t.grug_leash_timer < 1 then
			return
		end
		t.grug_leash_timer = 0
		local pos = self.object:get_pos()
		if pos and strayed(pos) then
			if self.attack then
				self:stop_attack()
			end
			self.state = "stand"
		end
	end,
})

-- Open sea only: the water surface far from both continents (biomes_mobs.md
-- §4). Zone gating cannot express this — zone "ocean" includes the coastal
-- ocean — hence the _grug_spawn_check above. 24 h, aoc 1: one Kraken in the
-- area is already a death sentence.
-- NB mobs_redo spawns one node ABOVE the matched node and checks the height
-- limits against THAT position; sea level is y = 1, so the surface spawn
-- position is y = 2 and max_height must leave room for it.
mobs:spawn({
	name = "grug_mobs:kraken",
	nodes = {"default:water_source"},
	neighbors = {"air"}, -- water touching air = the surface
	interval = 60,
	chance = 12000,
	active_object_count = 1,
	min_height = -10,
	max_height = 4,
})
