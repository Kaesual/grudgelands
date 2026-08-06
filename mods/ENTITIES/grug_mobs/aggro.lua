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
-- A mob chasing a PLAYER resets when it is more than LEASH_RANGE from its
-- home position OR has had no player contact for LEASH_TIMEOUT seconds:
-- threat table cleared, target dropped, healed to full.
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
end

-- Default leash radius; a def may override it per mob with
-- _grug_leash_range (installed onto the entity by apply_aggro_fields above).
grug_mobs.LEASH_RANGE = 40 -- m from the home position
grug_mobs.LEASH_TIMEOUT = 15 -- s without player contact
-- Floor for NAMED RARES (rares.lua). A rare walks a 2-3 point patrol route
-- that is 150-250 m across, but `_grug_home` is only the point it happened to
-- spawn at — with a family radius it would reset the instant it aggroes at a
-- far waypoint, and a territorial family makes that fatal: Marrowclaw is a
-- Plaguehide Bear (radius 20), so every pull more than 20 m from its spawn
-- point would drop the target and heal it to full, i.e. an unkillable rare.
-- The contact timeout above still applies, so this widens the leash without
-- turning rares into world-spanning chasers.
grug_mobs.RARE_LEASH_RANGE = 300
local LEASH_INTERVAL = 1 -- s between checks (performance rule: throttled)

-- Full reset: forget everyone, drop the target, heal up.
function grug_mobs.leash_reset(self)
	grug_core.clear_threat(self)
	if self.temp then
		self.temp.grug_last_contact = nil
	end
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
		-- to leash, and the contact clock restarts with the next pull.
		self.temp.grug_last_contact = nil
		return
	end
	local now = grug_core.mono_time()
	if not self.temp.grug_last_contact then
		-- Fresh pull (acquired via general_attack/group_attack without a hit
		-- yet): seed the clock so the pull does not reset instantly.
		self.temp.grug_last_contact = now
	end
	if now - self.temp.grug_last_contact > grug_mobs.LEASH_TIMEOUT then
		grug_mobs.leash_reset(self)
		return
	end
	local pos = self.object and self.object:get_pos()
	local home = self._grug_home
	-- `home` comes back from staticdata as a plain table (no vector
	-- metatable) — vector.distance reads the components, that is fine, but
	-- never compare positions with `==` (luanti-lua.md).
	local range = self._grug_leash_range or grug_mobs.LEASH_RANGE
	if self._grug_rare_id then
		range = math.max(range, grug_mobs.RARE_LEASH_RANGE)
	end
	if pos and home and vector.distance(pos, home) > range then
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
