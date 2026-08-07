--
-- Leash/reset, drop tagging and the loot pipeline (combat_stats.md §3/§4).
--
-- The threat table itself lives in grug_core/combat.lua (it is shared with
-- the ability kits); everything here is the mob-side half: when does a mob
-- give up a chase, and who is allowed to loot it.
--

--
-- Leash / reset (combat_stats.md §4)
--
-- A mob chasing a PLAYER resets when it has been dragged more than
-- LEASH_RANGE from where THAT CHASE BEGAN, or when it has had no player
-- contact for LEASH_TIMEOUT seconds: threat table cleared, target dropped,
-- healed to full.
--
-- "Dragged from where the chase began", not "far from home" (fixed in the WP6
-- review, B4): the anti-kiting rule of combat_stats §4 is about how far a
-- player may PULL a mob, and `_grug_home` is only the point the mob happened
-- to activate at. A wandering mob drifts away from its home on its own — a
-- bear or jungle ape with the territorial 20 m radius reaches the edge of its
-- own leash within a minute of idle walking — and from then on EVERY
-- leash_check during combat fired: reset, heal to full, once a second,
-- forever. That mob was literally unkillable. Measuring against a per-chase
-- anchor (temp.grug_chase_anchor, seeded with the contact clock and dropped
-- with the chase) makes the rule mean what it says and makes it impossible
-- for a mob to out-drift its own leash while idle.
--
-- THE TWO POSITIONS DO DIFFERENT JOBS, and both are load-bearing:
--   * `temp.grug_chase_anchor` governs the DRAG DISTANCE — how far a player
--     may pull this mob before it gives up. Per chase, runtime only.
--   * `_grug_home` governs WHERE AN EVADED MOB ENDS UP — leash_reset snaps it
--     back there when it has strayed further than its own radius (see the
--     evade block there) — and, for a camp-bound mob, HOW FAR IT MAY DRIFT
--     WHILE IDLE (roam_check below, world.md §4a). Persistent, one per mob,
--     set at first activation (levels.lua ensure_init) or by the camp that
--     spawned it (camps.lua).
-- What `_grug_home` is NOT is an identity: a camp counts its members by
-- `_grug_camp_pos`, which camps.lua sets alongside it — and which is also
-- what tells the roam cap apart from wildlife.
--
-- "Player contact" reading (decided WP6-T2): contact is a hit BETWEEN the
-- mob and its target — grug_core.run_player_hit_mob (player hits mob), a
-- taunt, and our own threat-driven target switches all refresh
-- `temp.grug_last_contact`. The reverse direction (mob hits player) has no
-- cheap reliable hook — mob melee lands engine-side via object:punch, and
-- routing it through the central hp-change modifier would mean tracking
-- puncher->mob identity for every player hit in the game. It does not need
-- one: a mob that reaches its victim gets hit back within 15 s in any real
-- fight, and a target that neither hits nor is hit for 15 s is by
-- definition out of contact. That is exactly the spec's intent — "fleeing
-- works by breaking contact". A player who runs but keeps shooting stays
-- engaged; a player who just runs is dropped.
--
-- Mob-vs-NPC combat is deliberately NOT leashed (guards fighting wolves
-- must not reset mid-fight); the leash only governs player chases.
--
-- Opt-out: `_grug_no_leash = true` in the def (zombie: "never leashes";
-- kraken: has its own hand-rolled open-sea leash).
--

--
-- Runtime field installation. Custom def fields do NOT reach the entity:
-- mobs_redo's register_mob copies an EXPLICIT field list into the entity
-- table (api.lua:3196ff) and mob_activate only layers staticdata on top. So
-- everything an api.lua patch reads off `self` must be installed at runtime
-- — the same reason _grug_faction is set in do_custom (init.lua). Called
-- from the do_custom and do_punch wrappers; `cfg` is the per-registration
-- upvalue table built in grug_mobs.register_mob.
--
function grug_mobs.apply_aggro_fields(self, cfg)
	-- Gate for the item_drop GRUG PATCH: only mobs registered through us
	-- follow the player-tag rule, vanilla mobs_redo mobs are untouched.
	if not self._grug_drop_rule then
		self._grug_drop_rule = true
	end
	if cfg.no_leash and not self._grug_no_leash then
		self._grug_no_leash = true
	end
	-- Read by the soft de-aggro GRUG PATCH in do_states; only the opt-out
	-- value needs to exist on the entity (nil means "rule applies").
	if cfg.soft_deaggro == false and self._grug_soft_deaggro ~= false then
		self._grug_soft_deaggro = false
	end
	-- Per-def leash radius (the "territorial" verb of bear/ape, ~20 m —
	-- biomes_mobs.md §3.1 "guards radius, short chase"). nil keeps the
	-- global default, so nothing changes for every other mob.
	if cfg.leash_range and self._grug_leash_range ~= cfg.leash_range then
		self._grug_leash_range = cfg.leash_range
	end
	-- Give-up distance for the do_states GRUG PATCH in mobs/api.lua. OURS
	-- only, unconditionally and with no def field: vanilla mobs_redo gives up
	-- at view_range, which for a ground mob is <= 16 m and therefore below the
	-- 25 m soft de-aggro AND below the 40 m leash — i.e. neither of the two
	-- rules combat_stats §3/§4 actually specifies could ever fire. The leash
	-- below is what ends a grug chase; this number only has to stay out of its
	-- way, hence 40 + 5 m of hysteresis margin.
	--
	-- Kraken included on purpose (no special case): its view_range is 20, so
	-- 45 EXTENDS its chase — but it runs its own hand-rolled open-sea leash
	-- (strayed(), kraken.lua) and _grug_no_leash, so that leash still governs
	-- when it turns around, exactly as before.
	if self._grug_chase_range ~= grug_mobs.CHASE_RANGE then
		self._grug_chase_range = grug_mobs.CHASE_RANGE
	end
end

-- Default leash radius; a def may override it per mob with
-- _grug_leash_range (installed onto the entity by apply_aggro_fields above).
grug_mobs.LEASH_RANGE = 40 -- m dragged from where the chase began
grug_mobs.LEASH_TIMEOUT = 15 -- s without player contact
-- Give-up distance handed to the api.lua do_states patch (see
-- apply_aggro_fields): must sit ABOVE LEASH_RANGE so the leash — not the
-- mob's eyesight — is what ends a chase, with a little hysteresis so a mob
-- hovering exactly at the leash edge does not flip between the two rules.
grug_mobs.CHASE_RANGE = 45
-- Floor for NAMED RARES (rares.lua): the maximum distance a rare may be
-- DRAGGED from the spot where the pull happened. A rare is the fight of a
-- region, not a mob you tow home in twenty metres — and its family radius
-- would otherwise decide that for it (Marrowclaw is a Plaguehide Bear,
-- radius 20). The contact timeout above still applies, so this widens the
-- drag allowance without turning rares into world-spanning chasers.
-- (Since the WP6 review the leash measures drag from the chase anchor, not
-- distance from `_grug_home`, so this is no longer load-bearing against the
-- route length — a rare that aggroes at a far waypoint anchors THERE. It
-- stays as the deliberate "a rare may be kited a long way" allowance.)
grug_mobs.RARE_LEASH_RANGE = 300
-- Floor for OUTPOST PATROLLERS (world.md §4, camps.lua/guard.lua): a patroller
-- is 250-850 nodes from its post by design, and its guard def carries a 30 m
-- leash meant for guards standing ON the post. Effectively "no distance
-- leash": a patroller leashes by CONTACT TIMEOUT only, and the 15 s rule above
-- still keeps it from chasing anyone across the continent.
-- It has to be a floor applied HERE and not a field on the entity, because
-- apply_aggro_fields re-writes _grug_leash_range from the def on every tick.
grug_mobs.PATROL_LEASH_RANGE = 2000
local LEASH_INTERVAL = 1 -- s between checks (performance rule: throttled)

-- Full reset: forget everyone, drop the target, heal up.
function grug_mobs.leash_reset(self)
	grug_core.clear_threat(self)
	if self.temp then
		self.temp.grug_last_contact = nil
		-- The chase is over, so its drag anchor is too: the NEXT pull anchors
		-- wherever the mob stands then (see leash_check).
		self.temp.grug_chase_anchor = nil
	end
	-- A reset mob is UNTAGGED (combat_stats §3, the documented "no seeding"
	-- rule): it forgot the fight, healed to full and dropped the target, so
	-- the loot rights of whoever poked it before must not survive either —
	-- otherwise a player could tag a mob, walk out of the leash, and let a
	-- guard or a fall kill it for them within the 60 s window.
	self._grug_player_tag = nil
	if type(self.stop_attack) == "function" then
		self:stop_attack()
	end
	local hp_max = self.hp_max
	if hp_max and hp_max > 0 then
		self.health = hp_max
		-- Keep mobs_redo's damage bookkeeping in sync, otherwise the next
		-- check_for_death (api.lua:821) reads the jump as a change and can
		-- play a damage sound (same reason levels.lua apply_stats does it).
		self.old_health = self.health
		if type(self.update_tag) == "function" then
			self:update_tag()
		end
	end
	--
	-- EVADE: snap back to `_grug_home`.
	--
	-- This is the MVP of WoW's evade-walk, and it is what puts the DISTANCE
	-- bound back that the chase-anchor rewrite took out. The anchor governs how
	-- far a mob may be DRAGGED; nothing governed where it ends up, so a garrison
	-- could be walked off its post one pull at a time:
	--   * a guard is `type = "npc"` — it never despawns and never expires, so a
	--     stray guard is stray FOREVER;
	--   * count_camp_mobs (camps.lua) only counts within radius + 16, so the post
	--     counts the stray as dead and refills behind it — strays accumulate
	--     without bound, one per pull, and the same holds for bandit/mirefolk
	--     camps;
	--   * for a named rare the drift also widens the duplicate window: the
	--     spawner's find_existing scan is SCAN_RADIUS = 100 around the route
	--     points, so a rare parked further out than that reads as gone. A reset
	--     rare returning to its spawn point — which is on its route — closes
	--     that on its own.
	-- Teleport rather than walk-home because the alternative is a second
	-- pathfinding state machine (mobs_redo has none: go_to() fakes an attack
	-- target, which our threat/leash/telegraph code all mis-reads — see
	-- patrol.lua). A mob that has just dropped its target, healed to full and
	-- gone idle is exactly the moment where a snap is invisible in practice.
	--
	-- Threshold is the DEF radius: 25 for a camp mob, 30 for a guard, the 40 m
	-- default otherwise — i.e. "further from your post than your post reaches".
	-- Horizontal only (a mob on a ledge above its home is not stray).
	-- The RARE/PATROL floors of leash_check are deliberately NOT applied here:
	-- they widen how far a mob may be dragged, which is a different question
	-- from where it belongs.
	--
	-- The designated PATROLLER is the one exemption: being far from its post is
	-- its entire job (world.md §4), and snapping it home after every timed-out
	-- fight would delete the ambient-patrol feature. Its drift is bounded
	-- instead by PATROL_INTERVAL in camps.lua.
	--
	-- Zombie and Kraken carry `_grug_no_leash` and therefore never reach this
	-- function at all — unchanged for them.
	local home = self._grug_home
	local pos = self.object and self.object:get_pos()
	if home and pos and not self._grug_patrol_route then
		local range = self._grug_leash_range or grug_mobs.LEASH_RANGE
		local dx, dz = pos.x - home.x, pos.z - home.z
		if dx * dx + dz * dz > range * range then
			-- Same ground correction every hand placement uses (init.lua):
			-- `_grug_home` is a FEET position (the camp node, the spawn point),
			-- and an entity's position is its collisionbox origin.
			grug_mobs.place_on_ground(self.object, home)
		end
	end
end

local function leash_check(self)
	local target = self.attack
	if self.state ~= "attack" or not target or not core.is_player(target) then
		-- Not chasing a player (idle, or fighting another mob/NPC): nothing
		-- to leash, and the contact clock restarts with the next pull. The
		-- drag anchor goes with it — it describes ONE chase.
		self.temp.grug_last_contact = nil
		self.temp.grug_chase_anchor = nil
		return
	end
	local pos = self.object and self.object:get_pos()
	local now = grug_core.mono_time()
	if not self.temp.grug_last_contact then
		-- Fresh pull (acquired via general_attack/group_attack without a hit
		-- yet): seed the clock so the pull does not reset instantly.
		self.temp.grug_last_contact = now
	end
	-- ... and, in the same breath, WHERE the chase began. That point — not
	-- `_grug_home` — is what the distance rule measures against (see the
	-- header): the spec's anti-kiting rule is about how far a player may drag
	-- a mob, and a mob that merely WANDERED past its own leash radius must not
	-- be resetting (i.e. healing to full) once a second for the rest of its
	-- life. Runtime-only (self.temp): a chase does not survive an unload, and
	-- the mob re-anchors on its next pull.
	if not self.temp.grug_chase_anchor and pos then
		self.temp.grug_chase_anchor = {x = pos.x, y = pos.y, z = pos.z}
	end
	if now - self.temp.grug_last_contact > grug_mobs.LEASH_TIMEOUT then
		grug_mobs.leash_reset(self)
		return
	end
	local anchor = self.temp.grug_chase_anchor
	-- `anchor` is a plain table (no vector metatable) — vector.distance reads
	-- the components, that is fine, but never compare positions with `==`
	-- (luanti-lua.md).
	local range = self._grug_leash_range or grug_mobs.LEASH_RANGE
	if self._grug_rare_id then
		range = math.max(range, grug_mobs.RARE_LEASH_RANGE)
	end
	if self._grug_patrol_route then
		range = math.max(range, grug_mobs.PATROL_LEASH_RANGE)
	end
	if pos and anchor and vector.distance(pos, anchor) > range then
		grug_mobs.leash_reset(self)
	end
end

--
-- Roam cap: the SOFT half of place binding (world.md §4a)
--
-- "Place-bound NPCs are bound to their anchor: after losing aggro they return
-- to it (the evade snap-home above), and while idle they roam only a small
-- radius around it (~10-20 nodes)." The evade is the hard reset for a mob
-- that was DRAGGED away; this is the bound on the mob's own drifting.
--
-- Why it is needed at all: mobs_redo's idle walk is an unbounded random walk
-- (do_states picks a random yaw and walks, api.lua:2150ff) — nothing in it
-- ever pulls a mob back. A bandit camp therefore dissolved into the landscape
-- over an evening, and every member that drifted past radius + 16 was counted
-- as dead by camps.lua and refilled behind (the same failure mode the evade
-- was written for, only slower). With the cap the head count's margin is a
-- real bound in the IDLE case too, not just after a fight.
--
-- Deliberately a gentle steer and not a teleport: an idle mob walking home is
-- invisible in the good way, and the snap is reserved for the moment a mob
-- has just dropped a chase (where it is equally invisible). Reuses the patrol
-- nudge (patrol.lua walk_toward) — never mobs_redo's go_to(), which fakes an
-- attack target and would blind the mob to players; see patrol.lua.
--
-- 20 nodes: world.md §4a's roam radius, and the value has to sit STRICTLY
-- above every camp radius (bandit 12, mirefolk 10, guards 15 — camps.lua) or
-- this rule fights the spawner. At 15 it did exactly that: camps.lua's
-- free_spot_near places a member anywhere out to `radius`, so a guard could
-- be spawned at 15.0 and land on an integer node 15-16 out, which this check
-- read as stray on its very first idle tick — a fresh guard immediately
-- walking back to the banner. 20 clears the widest camp by a full node of
-- rounding slack and still sits comfortably inside every leash radius
-- (bandit/mirefolk 25, guard 30), so the two rules never fight from the
-- other side either.
local ROAM_RADIUS = 20

local function roam_check(self)
	-- CAMP-BOUND ONLY. `_grug_camp_pos` is the identity ("I belong to that
	-- anchor"), `_grug_home` merely a position every mob has — wildlife keeps
	-- its unbounded wander, which is what wildlife is for.
	if not self._grug_camp_pos then
		return
	end
	-- The designated patroller is §4's one exemption: being far from its post
	-- is its entire job (same exemption as the evade above).
	if self._grug_patrol_route then
		return
	end
	-- Idle only: fighting, fleeing and flopping own the movement. Identical
	-- test to route_tick's, and it is what makes this rule invisible in
	-- combat — a guard chasing an intruder is never steered home.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return
	end
	local home = self._grug_home
	local pos = self.object and self.object:get_pos()
	if not home or not pos then
		return
	end
	-- Horizontal only, like the evade: a mob on the ledge above its fire is
	-- not stray.
	local dx, dz = pos.x - home.x, pos.z - home.z
	if dx * dx + dz * dz <= ROAM_RADIUS * ROAM_RADIUS then
		return
	end
	grug_mobs.walk_toward(self, home.x, home.z, pos)
end

-- Called on every do_custom tick; does real work once a second. This IS the
-- per-mob 1 Hz slot, so the threat-switch drain rides along in it rather than
-- opening a second accumulator.
function grug_mobs.leash_tick(self, dtime)
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_leash_acc = (t.grug_leash_acc or 0) + dtime
	if t.grug_leash_acc < LEASH_INTERVAL then
		return
	end
	t.grug_leash_acc = 0
	-- Nametag proximity gate (levels.lua, combat_stats §6). First in the slot
	-- and BEFORE every early return below: it has nothing to do with leashing
	-- or threat, and a no-leash mob (zombie, kraken) needs the same culling as
	-- everyone else.
	grug_mobs.tag_gate_tick(self)
	-- Trailing edge of grug_core's 0.25 s check_switch throttle: run a target
	-- re-evaluation that the throttle parked, so the last (heaviest) hit of a
	-- burst cannot lose a legitimate switch. Deliberately BEFORE the no-leash
	-- early return — threat targeting has nothing to do with leashing, and the
	-- zombie and the kraken have threat tables like everyone else.
	grug_core.recheck_switch(self)
	-- Idle roam cap (world.md §4a). Also BEFORE the no-leash early return:
	-- being bound to an anchor is not the same question as being leashed to a
	-- chase, and a camp family that ever opts out of the leash must still
	-- stay at its camp. Costs one field test for every other mob.
	roam_check(self)
	if self._grug_no_leash then
		return
	end
	leash_check(self)
end

--
-- Player drop tag (combat_stats.md §3)
--
-- Every player hit stamps `_grug_player_tag = {name = ..., until_t = ...}`
-- on the mob. A plain field, so it PERSISTS through unload/reload — which is
-- why the deadline uses core.get_gametime() (world seconds) and not the
-- mono clock: the window has to survive the mob being unloaded with the
-- player still nearby. Gametime pauses while the server is empty; a tag
-- surviving an empty server is harmless (nobody can farm what nobody hits).
--

grug_mobs.TAG_TIME = 60 -- s of player-tag validity

function grug_mobs.tag_player(self, player)
	self._grug_player_tag = {
		name = player:get_player_name(),
		until_t = core.get_gametime() + grug_mobs.TAG_TIME,
	}
end

--
-- Drop hooks (professions.md §3, consumed by WP10's Leatherworker ×5).
-- fn(self, drops_copy, tagger_name) may mutate the COPY in place or return a
-- replacement list. Nothing is registered today — the pipeline just exists.
--

grug_mobs.registered_drop_hooks = {}

function grug_mobs.register_drop_hook(fn)
	table.insert(grug_mobs.registered_drop_hooks, fn)
end

function grug_mobs.run_drop_hooks(self, drops, tagger_name)
	for _, fn in ipairs(grug_mobs.registered_drop_hooks) do
		local out = fn(self, drops, tagger_name)
		if out then
			drops = out
		end
	end
	return drops
end

--
-- Loot gate, called from the GRUG PATCH in mobs/api.lua item_drop (only for
-- mobs registered through grug_mobs, i.e. `_grug_drop_rule`). Returns the
-- drop list to roll — a COPY, so the hooks can never corrupt the def's own
-- table — or nil when this mob must not drop anything at all.
--
--   (a) faction NPC: loot only from a PvP kill by an ENEMY-faction player;
--       NPC-vs-mob and friendly kills never drop (kills LotT's armor litter)
--   (b) normal mob: loot only with a live player tag (damaged by a player
--       within the last 60 s) — no seeding a wolf and letting guards farm it
--
function grug_mobs._item_drop_filter(self, drops)
	local tagger
	if self._grug_faction then
		local killer = self.cause_of_death and self.cause_of_death.puncher
		if not killer or not core.is_player(killer) then
			return nil
		end
		local kf = grug_core.get_player_faction(killer:get_player_name())
		if not kf or kf ~= grug_core.opposing_faction(self._grug_faction) then
			return nil
		end
		tagger = killer:get_player_name()
	else
		local tag = self._grug_player_tag
		if not tag or not tag.name or
				(tag.until_t or 0) < core.get_gametime() then
			return nil
		end
		tagger = tag.name
	end
	local copy = {}
	for i = 1, #drops do
		copy[i] = table.copy(drops[i])
	end
	return grug_mobs.run_drop_hooks(self, copy, tagger)
end
