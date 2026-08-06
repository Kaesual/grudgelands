--
-- Faction guards (docs/design/world.md §1 "guard level", §4 "outposts &
-- patrols", §9 "world life").
--
-- END-TO-END FLOW of a guard post, so the pieces are findable from here:
--
--   1. grug_mapgen/structures.lua builds a 7x7 pad with a
--      grug_nodes:guard_banner in its middle at every anchor of
--      grug_core.outpost_anchors() (and one banner on every race-capital
--      spawn platform, world.md §3 "elite guards"), then registers the
--      outpost as a protected POI (grug_core.add_poi).
--   2. The banner arrives via VoxelManip, which fires NO node callbacks, so
--      the LBM "grug_mobs:guard_banner_init" (camps.lua) starts its node
--      timer on first load.
--   3. That timer is the camp mechanism of camps.lua: camp type
--      "guard_accord"/"guard_throng" — 2-3 guards, radius 15, spawned one at
--      a time while a player is near.
--   4. Each guard's LEVEL comes from the inverse guard field
--      (grug_core.guard_level_at via _grug_level_source = "guard",
--      levels.lua) — ~36 at the war coast, ~47 in the inner ring, 60+ in the
--      safe core.
--   5. At level 60+ the guard promotes itself to tier "elite" below (the
--      "elite city watch (60+)" of world.md §1), which also switches on the
--      2 s wind-up telegraph.
--   6. It defends its post: _grug_leash_range = 30 around the banner
--      (camps.lua writes the banner position into _grug_home).
--   7. The camp's designated patroller additionally carries
--      _grug_patrol_route and ambles to the neighbouring ring's outpost and
--      back (patrol.lua + the patrol leash exemption in aggro.lua).
--
-- NO mobs:spawn ROW, deliberately: guards are not wildlife. Every guard in
-- the world comes out of a guard post, which is also what gives it its
-- _grug_home and _grug_camp_pos.
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
--     the MVP; NPC-vs-NPC war would need its own design pass.)
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
	-- Ambient outpost patrol (world.md §4). Only the camp's designated
	-- patroller carries the route; every other guard holds its post.
	local route = self._grug_patrol_route
	if route then
		grug_mobs.route_tick(self, dtime, route.points, route, "wp")
	end
end

-- One def per faction; everything except description/texture/_grug_faction is
-- shared, so the two guards can never drift apart.
local function guard_def(faction, description, texture)
	return {
		description = description,
		type = "npc",
		_grug_faction = faction,

		-- Level from the INVERSE guard field (world.md §1), cap 70
		-- (levels.lua LEVEL_CAP.guard — capping at 60 would delete the elite
		-- city watch). The floor matches the field's own documented range
		-- (20..70) and is what a guard falls back to where the field has no
		-- value at all (ocean — which a guard post never is).
		_grug_level_source = "guard",
		_grug_min_level = 20,

		-- Outpost defender (world.md §4): 30 nodes around the banner, so a
		-- guard chases an intruder off the post and then walks back and
		-- heals instead of following them into the wilderness. The camp's
		-- patroller is exempt — see PATROL_LEASH_RANGE in aggro.lua.
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
		run_velocity = 4.4, -- aggressive-mob speed (biomes_mobs §0)
		jump = true,
		jump_height = 4,
		stepheight = 1.1,
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

		-- EMPTY ON PURPOSE, not a TODO left open: a faction NPC drops loot
		-- only when an ENEMY player kills it (the PvP branch of
		-- grug_mobs._item_drop_filter, aggro.lua) — a guard slain by a wolf
		-- or by its own side drops nothing at all. WHAT a PvP kill yields is
		-- an economy/loot question (WP7 money, WP9 PvP quests), so the honest
		-- state today is "no table yet".
		drops = {},

		water_damage = 0,
		lava_damage = 4,
		light_damage = 0,

		do_custom = guard_tick,
	}
end

grug_mobs.register_mob("grug_mobs:guard_accord",
	guard_def("accord", "Accord Guard", "grug_mobs_guard_accord.png"))
grug_mobs.register_mob("grug_mobs:guard_throng",
	guard_def("throng", "Throng Guard", "grug_mobs_guard_throng.png"))
