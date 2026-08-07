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
-- for a mob to out-drift its own leash while idle. `_grug_home` stays: camps
-- still return-to and identify by it (camps.lua), it just no longer decides
-- the leash.
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

-- Called on every do_custom tick; does real work once a second.
function grug_mobs.leash_tick(self, dtime)
	if self._grug_no_leash then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_leash_acc = (t.grug_leash_acc or 0) + dtime
	if t.grug_leash_acc < LEASH_INTERVAL then
		return
	end
	t.grug_leash_acc = 0
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
