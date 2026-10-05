--
-- Round 35 ruling 2.5, lane E: night mobs leave at dawn.
--
-- The spawn clock gates spawning only, so a mob spawned for the night stayed
-- through the day. Now a free region mob spawned under the night clock leaves
-- by day: it is removed quietly (no drops, no XP, no kill credit) with the
-- smoke puff of mobs_redo's own lifetimer despawn, unless it is in combat or a
-- player is within NEAR nodes; it leaves as soon as neither holds. Day is the
-- spawn clock's own day phase (spawn_regions.lua clock_now).
--
-- Who leaves: `_grug_spawn_clock == "night"` and an `_grug_area` tag of a
-- region KIND. Only SR.spawn_mob stamps the clock, for ambient region spawns
-- and for region camp members; camp members carry their camp's tag and stay
-- (as density.lua counts them). Underground and water rows, leaders, rares,
-- bosses and their summons, quest drops, vendors and guards never carry the
-- clock. The fields in `bound` are belt and braces for a mob that is bound to
-- something else all the same (tamed, owned, a camp post, a route).
--
-- NEAR is 32 nodes. Region mobs never spawn closer than mob_nospawn_range
-- (24) to a player, so a mob leaves a little farther out than mobs appear;
-- no ambient mob notices a player beyond 18 nodes (its view_range), so a mob
-- about to pick a fight with a player is never taken; and mobs are active
-- only within active_block_range mapblocks (4, about 48-64 nodes): a night
-- mob whose block wakes as a player walks up by day still stands beyond 32
-- nodes on its first check, so it leaves before the player reaches it.
--
-- Cost: one field test per mob step (do_custom); a night-spawned mob then
-- checks once a second: the time of day, a few of its own fields and, by day,
-- the distance of each connected player until one is near.
--

grug_mobs.DAWN_NEAR = 32
grug_mobs.DAWN_INTERVAL = 1
grug_mobs.dawn_stats = {left = 0}

local SR = grug_mobs.spawn_regions

-- Bound to something besides the region it was spawned in.
local function bound(ent)
	return ent.type == "npc" or ent.tamed == true or (ent.owner ~= nil and ent.owner ~= "")
		or ent._grug_camp_pos ~= nil or ent._grug_patrol_route ~= nil
		or ent._grug_rare_id ~= nil or ent._grug_boss_id ~= nil
		or ent._grug_boss_summon ~= nil or ent._grug_royal_summon ~= nil
		or ent._grug_royal_king ~= nil or ent._grug_leader ~= nil
		or ent._grug_tier == "rare" or ent._grug_tier == "boss"
end

-- In a fight: a target (mobs_redo `attack`), the attack or runaway state, an
-- engagement with a player (grug_core) or the evade run home after a fight.
function grug_mobs.mob_in_combat(ent)
	local t = ent.temp
	return ent.attack ~= nil or ent.state == "attack" or ent.state == "runaway"
		or (t ~= nil and (t.grug_engaged ~= nil or t.grug_evading ~= nil))
end

-- A free region mob spawned for the night, at `clock` ("day" or "night").
-- Pure; the fixture drives it directly.
function grug_mobs.dawn_candidate(ent, clock)
	if clock ~= "day" or ent._grug_spawn_clock ~= "night" then
		return false
	end
	local tag = ent._grug_area
	local unit = tag and SR.area_by_tag(tag)
	return unit ~= nil and not unit.is_camp and not bound(ent)
end

-- True when `ent` at `pos` leaves now: a candidate, out of combat, no player
-- within NEAR. `get_players` returns the player list; it is called only when
-- the rest holds.
function grug_mobs.dawn_leaves(ent, clock, pos, get_players)
	return grug_mobs.dawn_candidate(ent, clock) and not grug_mobs.mob_in_combat(ent)
		and SR.players_clear(pos, grug_mobs.DAWN_NEAR, get_players())
end

-- Called from do_custom on every step. Returns true when the mob left (the
-- object is removed; the caller stops the step).
function grug_mobs.dawn_tick(self, dtime)
	if self._grug_spawn_clock ~= "night" then
		return false
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_dawn_acc = (t.grug_dawn_acc or 0) + dtime
	if t.grug_dawn_acc < grug_mobs.DAWN_INTERVAL then
		return false
	end
	t.grug_dawn_acc = 0
	local pos = self.object:get_pos()
	if not pos or not grug_mobs.dawn_leaves(self, SR.clock_now(), pos, SR.players) then
		return false
	end
	mobs:effect(pos, 15, "mobs_tnt_smoke.png", 2, 4, 2, 0)
	mobs:remove(self)
	grug_mobs.dawn_stats.left = grug_mobs.dawn_stats.left + 1
	return true
end
