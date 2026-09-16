--
-- Faction guards (docs/design/world.md §1 "guard level", §4 "outposts &
-- patrols", §9 "world life").
--
-- END-TO-END FLOW of a guard post, so the pieces are findable from here:
--
--   1. R7's single writer authors a guard banner at every stable outpost and
--      capital anchor. The same authenticated authority owns their hard
--      protection volumes.
--   2. The banner arrives via VoxelManip, which fires NO node callbacks, so
--      the LBM "grug_mobs:guard_banner_init" (camps.lua) starts its node
--      timer. That LBM runs at EVERY mapblock activation, not once: a
--      `run_at_every_load = false` LBM never runs on blocks generated after
--      its introduction (lua_api.md:10312-10316), which is every block mapgen
--      ever puts a banner in — see the long note at the LBM itself.
--   3. That timer is the camp mechanism of camps.lua: camp type
--      "guard_accord"/"guard_throng" — 2-3 guards, radius 15, refilled one
--      RESPAWN SLOT at a time (world.md §4a; 180-360 s per slot, owed
--      refills catch up when a dormant post reactivates) while a player is
--      near.
--   4. Each guard's LEVEL comes from the inverse guard field
--      (grug_zones.guard_level_at via _grug_level_source = "guard",
--      levels.lua) — ~36 at the war coast, ~47 in the inner ring, 60+ in the
--      safe core.
--   5. At level 60+ the guard promotes itself to tier "elite" below (the
--      "elite city watch (60+)" of world.md §1), which also switches on the
--      2 s wind-up telegraph.
--   6. It defends its post: _grug_leash_range = 30 around the banner
--      (camps.lua writes the banner position into _grug_home), and while
--      idle it stays within the 15-node roam cap of world.md §4a
--      (aggro.lua) instead of wandering off the pad.
--   7. The camp's designated patroller additionally carries
--      _grug_patrol_route and ambles to the neighbouring ring's outpost and
--      back (patrol.lua + the patrol leash exemption in aggro.lua).
--
-- THE SECOND SOURCE OF GUARDS, since WP13: the six START SETTLEMENTS. Their
-- watch does not come out of a banner at all -- a blueprint exports two
-- `guard_post` sockets and one `guard_patrol` loop, `start_npcs.lua` places
-- this same entity on them, and the reasons that is a registry and not a
-- banner are written out in that file's header. Such a guard carries
-- `_grug_post_*` (its authored standing position and facing), `_grug_start`
-- and `_grug_socket`; its level still comes from the guard field below, and
-- its targeting is untouched -- the user's 2026-09-14 ruling is that the
-- faction veto is the single rule everywhere.
--
-- NO mobs:spawn ROW, deliberately: guards are not wildlife. Every guard in
-- the world comes out of a guard post or a start socket, which is also what
-- gives it its _grug_home and (at an outpost) its _grug_camp_pos.
--
-- TARGETING (combat_stats.md §4, world.md §9):
--   * attack_players = true, but the faction veto in init.lua drops
--     own-faction AND factionless players — a guard only ever attacks
--     players of the ENEMY faction.
--   * attack_monsters = true: guards fight the world's hostiles, which is
--     the "visible patrols that really fight nature mobs" of world.md §9.
--     Verified against the roster: every hostile family is registered with
--     type = "monster" (bandit.lua, mirefolk.lua, wolf/bear/spider/…), while
--     harmless critters are type = "animal" and stay untouched — a guard
--     does not butcher rabbits.
--   * attack_npcs = false: never guard vs. guard, not even across factions.
--     (Enemy guards ignoring each other is a deliberate simplification for
--     the MVP; NPC-vs-NPC war would need its own design pass.) This is again
--     a PER-DEF choice, and it is this def's: playtest round 1 applied it to
--     every mob through `grug_mobs.register_mob`, which also stopped every
--     hostile from ever fighting a guard, and the user's round-2 ruling
--     (2026-09-15) reversed that. A hostile now keeps mobs_redo's default and
--     engages the watch; what nothing may touch is a NON-COMBATANT settlement
--     NPC, and that veto is a property of the villager, the elder and the
--     vendor (`grug_mobs.noncombatant`, verbs.lua), not of the attacker.
--   * owner stays "" — nobody owns a guard, and mobs_redo's owner checks
--     (general_attack, follow) must never match a real player name.
--
-- MESH: `character.b3d`, the engine/MTG player model, referenced BY NAME —
-- Luanti's media namespace is flat, so a mob in grug_mobs may point at a mesh
-- that physically lives in mods/BASE/player_api/models without copying it
-- (wp6_model_notes §5). Same geometry/animation block as bandit.lua.
--

-- world.md §1: "elite city watch (60+)". The auto-promotion runs on the
-- guard's own do_custom, AFTER init.lua's wrapper called ensure_init — so
-- _grug_level is already assigned when we look at it.
local ELITE_LEVEL = 60

local function guard_tick(self, dtime)
	-- Tier decision, exactly ONCE per mob. `_grug_elite_checked` is a plain
	-- boolean field, so it persists in staticdata: a guard that was promoted
	-- (or judged too low) never re-rolls on the next activation, and a guard
	-- demoted by anything else is not silently promoted again.
	if not self._grug_elite_checked then
		self._grug_elite_checked = true
		if (self._grug_level or 0) >= ELITE_LEVEL
				and (self._grug_tier or "normal") == "normal" then
			-- x3 HP, x1.8 damage, armor 80, x1.6 scale, gold tint — and the
			-- 2 s wind-up telegraph (telegraph.lua fires for elite/rare).
			grug_mobs.set_tier(self, "elite")
		end
	end
	-- A SOCKET GUARD CLAIMS ITS SOCKET, once per activation: a twin standing on
	-- a socket somebody else already holds removes itself rather than joining
	-- the watch (start_npcs.lua's claim registry, playtest round 1 — a world
	-- that lost markers had ~50 guards in one start). Nothing else in this tick
	-- may run for a mob that is about to be removed.
	self.temp = self.temp or {}
	if self._grug_start and not self.temp.grug_socket_claimed then
		self.temp.grug_socket_claimed = true
		if not grug_mobs.start_npc_claim(self) then
			-- FALSE, not nil: mobs_redo's on_step returns as soon as do_custom
			-- answers false (api.lua "run custom function"), which is how a mob
			-- that has just removed itself skips the rest of its own step.
			return false
		end
	end
	-- Ambient outpost patrol (world.md §4). Only the camp's designated
	-- patroller carries the route; every other guard holds its post.
	-- `rescue` is on: a guard walking an authored loop through a settlement is
	-- exactly the mob the stuck rescue was written for (patrol.lua).
	local route = self._grug_patrol_route
	if route then
		grug_mobs.route_tick(self, dtime, route.points, route, "wp", true)
	end
	-- A START SETTLEMENT's post guard holds its authored socket and faces its
	-- authored direction while idle (start_npcs.lua, WP13). An outpost guard
	-- carries no post field at all and keeps aggro.lua's 20-node camp roam cap
	-- instead, so the two never steer the same mob.
	if self._grug_post_x then
		grug_mobs.start_post_tick(self, dtime)
	end
end

-- WP13 character visuals: the Accord watch is human, the Throng watch orc --
-- the two most distinct silhouettes of their sides, so the faction stays
-- readable at a distance now that the skin is composed rather than painted per
-- faction (the old per-faction PNGs remain the definition fallback for a build
-- without grug_visuals).
local GUARD_RACE = {accord = "human", throng = "orc"}

-- One def per faction; everything except description/texture/_grug_faction is
-- shared, so the two guards can never drift apart.
local function guard_def(faction, description, texture)
	return {
		description = description,
		type = "npc",
		_grug_faction = faction,

		-- Metal line at the bracket its own level buys (contract §2). The
		-- level IS the tier here: the elite city watch of world.md §1 starts at
		-- 60, which is exactly where grug_gear's sixth bracket starts, so a
		-- promoted guard wears the Grand set without a second rule. `faction`
		-- is read from the closure, not from `self`: mobs_redo installs
		-- `_grug_faction` only on the first do_custom tick, which is later than
		-- this.
		_grug_visual = function(self)
			return {
				race = GUARD_RACE[faction],
				armor_line = "metal",
				level = self._grug_level,
				weapon_family = "sword",
			}
		end,

		-- Level from the INVERSE guard field (world.md §1), cap 70
		-- (levels.lua LEVEL_CAP.guard — capping at 60 would delete the elite
		-- city watch). The floor matches the field's own documented range
		-- (20..70) and is what a guard falls back to where the field has no
		-- value at all (ocean — which a guard post never is).
		_grug_level_source = "guard",
		_grug_min_level = 20,

		-- Outpost defender (world.md §4): an intruder may drag a guard 30
		-- nodes from where the fight started before it gives up, heals and
		-- RUNS BACK to the banner (aggro.lua leash_reset's evade, which uses
		-- `_grug_home` — camps.lua wrote the banner position there), instead of
		-- following them into the wilderness. That return is what keeps a post
		-- manned: a guard is type npc and never despawns, so one walked off its
		-- post would otherwise be gone for good. The camp's designated
		-- patroller is exempt from both halves — see PATROL_LEASH_RANGE and the
		-- evade block in aggro.lua.
		_grug_leash_range = 30,

		reach = 2,
		attack_type = "dogfight",
		attack_players = true,
		attack_monsters = true,
		attack_npcs = false,
		attack_animals = false,
		group_attack = true, -- a post answers as one
		pathfinding = 1,
		owner = "",

		walk_velocity = 1.2,
		run_velocity = 4.6, -- aggressive-mob speed (biomes_mobs §0)
		jump = true,
		jump_height = 4,
		stepheight = 1.1,
		-- THE ONE EXCEPTION to T10's cliff rule of 6 (boar.lua) besides the
		-- golem, and for a different reason: a guard is `type = "npc"`, so it
		-- never despawns and its lifetimer never expires. Wildlife self-heals
		-- from a bad drop — the mob is culled and the ABM makes another one —
		-- but a guard that walks off a 6-node ledge into a pit it cannot climb
		-- out of (stepheight 1.1, jump_height 4) is removed from its post
		-- PERMANENTLY, and the camp head count still sees it, so the post never
		-- refills either. 4 costs a little chase reach at ledges and buys back
		-- the invariant that a post stays manned.
		fear_height = 4,
		view_range = 14,
		-- No day_toggle / docile_by_day: a watch stands day AND night.

		visual = "mesh",
		mesh = "character.b3d",
		textures = {{texture}},
		-- The player's own geometry (wp6_model_notes §5): the mesh measures
		-- 17.0 units = 1.70 nodes at size 1, which is the player collisionbox
		-- height.
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		makes_footstep_sound = true,

		-- Frame ranges from mods/BASE/player_api/init.lua via
		-- wp6_model_notes §5: stand 0-79, walk 168-187, mine 189-198 (used as
		-- the punch clip).
		animation = {
			stand_start = 0, stand_end = 79, stand_speed = 30,
			walk_start = 168, walk_end = 187, walk_speed = 30,
			run_start = 168, run_end = 187, run_speed = 45,
			punch_start = 189, punch_end = 198, punch_speed = 30,
		},

		-- PvP-ONLY LOOT (items_crafting.md §5.6: "Faction NPC kills
		-- additionally drop war trophies (vendor 5-10c) + heavy cloth 1/3
		-- (combat_stats player-tag PvP rule)"). This table only ever
		-- materializes on a kill by an ENEMY-faction PLAYER: the faction branch
		-- of grug_mobs._item_drop_filter (aggro.lua:529-538) returns nil for a
		-- guard slain by a mob, by a factionless player or by its own side, and
		-- api.lua's item_drop then drops nothing at all.
		--
		-- chance = N is a 1-in-N roll (api.lua:751,
		-- `if random(drops[n].chance) == 1`): the trophy is guaranteed at 1-2
		-- pieces x 5c, which IS the 5-10c band of §5.6, and the heavy cloth is
		-- the literal "1/3" of the same line.
		drops = {
			{name = "grug_mobs:war_trophy", chance = 1, min = 1, max = 2},
			{name = "grug_mobs:heavy_cloth", chance = 3, min = 1, max = 1},
		},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,

		do_custom = guard_tick,

		-- A start settlement's guard post is a respawn slot (world.md §4a,
		-- start_npcs.lua): its death frees the slot and books the refill. An
		-- outpost guard carries no start fields and this is a no-op for it.
		-- MUST return nil: any truthy return skips the removal of the mob
		-- (api.lua:870-874, "skips removal of mob").
		on_die = function(self)
			if self._grug_start and self._grug_socket then
				grug_mobs.start_guard_died(self)
			end
		end,
	}
end

grug_mobs.register_mob("grug_mobs:guard_accord",
	guard_def("accord", "Accord Guard", "grug_mobs_guard_accord.png"))
grug_mobs.register_mob("grug_mobs:guard_throng",
	guard_def("throng", "Throng Guard", "grug_mobs_guard_throng.png"))
