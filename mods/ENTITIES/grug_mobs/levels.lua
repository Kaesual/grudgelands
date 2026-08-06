--
-- Level & tier engine (combat_stats.md §3/§6, biomes_mobs.md §0).
--
-- Every mob gets its level ONCE, on its first active tick, from the level
-- field at its position; HP/damage/XP are DERIVED from that level and the
-- tier, never hand-written in a mob def.
--
--   HP = 15 + 5*L   damage = 2 + 0.4*L   XP = 10*L
--   elite: x3 HP, x1.8 dmg, x4 XP, armor 80, scale x1.6, gold tint
--   rare:  x5 HP, x2.2 dmg, x6 XP, armor 70, scale x2,   violet tint
--
-- ENGINE vs. DEF CONTRACT (the one rule for the whole mod):
--   * HP (hp_min/hp_max/health), damage and XP are ALWAYS engine-owned.
--     A def that hand-sets them is overridden — do not write them.
--   * armor is engine-owned only when the tier says so (elite 80 / rare
--     70) or when the def leaves it nil (then: normal = 100). An explicit
--     def armor at tier "normal" is kept (Kraken: 70).
--   * Everything else (speeds, view_range, drops, visuals) stays def-owned;
--     the tier visuals (scale/tint) are layered on top of them at runtime.
--
-- Persistence note: mobs_redo serializes every plain entity field into
-- staticdata (api.lua clean_staticdata:2790) and re-applies fields whose
-- name is an object-property name (is_property_name:2842) on activation.
-- So `self.hp_max` is not read by mobs_redo at runtime, but storing it
-- makes the raised max survive unload/reload for free. Function fields are
-- dropped by the serializer — anything callable must be re-installed on
-- every activation (see ensure_init).
--

local MAX_LEVEL = 60
grug_mobs.MAX_LEVEL = MAX_LEVEL

-- Hard ceilings per level source. The mob field is the 1..60 progression
-- axis; grug_core.guard_level_at is documented 20..70 (world.md §1: the
-- capital watch is 60+), so capping guards at 60 would silently delete the
-- elite city watch. `_grug_fixed_level` bypasses both (Kraken = 100).
local LEVEL_CAP = {mob = MAX_LEVEL, guard = 70}

local TIERS = {
	normal = {hp = 1, dmg = 1, xp = 1, armor = nil, scale = 1,
		tint = nil, prefix = ""},
	elite = {hp = 3, dmg = 1.8, xp = 4, armor = 80, scale = 1.6,
		tint = "#ffa800:80", prefix = "Elite "},
	-- UTF-8 written literally: \u{} escapes are LuaJIT-only (luanti-lua.md).
	rare = {hp = 5, dmg = 2.2, xp = 6, armor = 70, scale = 2,
		tint = "#a64dff:90", prefix = "★ "},
}

local function tier_def(tier)
	return TIERS[tier] or TIERS.normal
end

-- mob name -> level/tier config from the def (see register_level_cfg)
local level_cfg = {}

local function round1(x)
	return math.floor(x * 10 + 0.5) / 10
end

-- Derived stats for a level/tier pair. Single source of truth — every
-- other place asks here instead of repeating a formula.
function grug_mobs.stats_for(level, tier)
	local t = tier_def(tier)
	return math.floor((15 + 5 * level) * t.hp + 0.5),
		round1((2 + 0.4 * level) * t.dmg),
		math.floor(10 * level * t.xp + 0.5)
end

--
-- Nametag (combat_stats.md §6): global, viewer-independent, neutral white.
-- Con colors are per viewer and live in the HUD target frame instead.
--

function grug_mobs.tag_text(self)
	local hp_max = self.hp_max or 0
	if hp_max <= 0 then
		local prop = self.object and self.object:get_properties()
		hp_max = prop and prop.hp_max or math.max(1, self.health or 1)
	end
	local hp = math.max(0, math.floor(self.health or 0))
	return tier_def(self._grug_tier).prefix
		.. (self.description or self.name or "?")
		.. " [Lv " .. (self._grug_level or 1) .. "] " .. hp .. "/" .. hp_max
end

-- Per-entity replacement for mobs_redo's mob_class:update_tag (api.lua:623),
-- which hardcodes a green->red HP color we do not want and which we must
-- not patch. Installing it as an instance field means mobs_redo's own calls
-- reach us: check_for_death (api.lua:830) calls update_tag on EVERY health
-- change, which is exactly the "update on damage" requirement — no polling
-- and no throttle needed, and no write happens unless the text changed.
local function update_tag(self)
	if not self.object then
		return
	end
	local text = grug_mobs.tag_text(self)
	if text == self._grug_tag then
		return
	end
	self._grug_tag = text
	self.object:set_properties({nametag = text, nametag_color = "#ffffff"})
end
grug_mobs.update_tag = update_tag

--
-- Stat application
--

-- Applies the derived stats to the live entity. `keep_fraction` preserves
-- the current HP percentage (tier promotion of a wounded mob); otherwise
-- the mob ends up at full HP.
local function apply_stats(self, keep_fraction)
	if not self.object then
		return
	end
	local hp, damage, xp = grug_mobs.stats_for(
		self._grug_level or 1, self._grug_tier)
	local fraction = 1
	if keep_fraction then
		local old_max = self.hp_max
		if not old_max or old_max <= 0 then
			local prop = self.object:get_properties()
			old_max = prop and prop.hp_max or 0
		end
		if old_max > 0 and self.health then
			fraction = math.min(1, math.max(0, self.health / old_max))
		end
	end
	self.hp_max = hp
	self.hp_min = hp -- mobs_redo rolls health in hp_min..hp_max (api.lua:2922)
	self.object:set_properties({hp_max = hp})
	self.health = math.max(1, math.floor(hp * fraction + 0.5))
	-- Keep mobs_redo's damage bookkeeping in sync so raising the max does
	-- not read as "was healed" and trigger a spurious damage sound.
	self.old_health = self.health
	self.damage = damage
	self._grug_xp = xp

	local armor = tier_def(self._grug_tier).armor
	if armor then
		self.armor = armor
	elseif self.armor == nil then
		self.armor = 100
	end
	-- mobs_redo also accepts a full armor-group table; never flatten one.
	if type(self.armor) == "number" then
		self.object:set_armor_groups({fleshy = self.armor, immortal = 1})
	end
end

--
-- Tier visuals: scale + tint (combat_stats.md §3 readability rules)
--

local function tint_textures(textures, tint)
	if type(textures) == "string" then
		return textures .. "^[colorize:" .. tint
	end
	local out = {}
	for i = 1, #textures do
		out[i] = textures[i] .. "^[colorize:" .. tint
	end
	return out
end

-- Idempotent, and correct across tier CHANGES: the pristine texture list is
-- remembered once (so colorize never stacks) and the scale is applied
-- relative to the scale already in place — mobs:scale_mob(..., true)
-- overwrites base_size/base_colbox/base_selbox, which persist in
-- staticdata, so applying the same factor twice would double the mob.
local function apply_tier_visuals(self)
	local tier = self._grug_tier or "normal"
	local applied = self._grug_visual_tier or "normal"
	if applied == tier then
		self._grug_visual_tier = tier
		return
	end
	local factor = tier_def(tier).scale / tier_def(applied).scale
	if factor ~= 1 then
		mobs:scale_mob(self, factor, factor, true)
	end
	if self._grug_base_texture == nil then
		self._grug_base_texture = self.base_texture
	end
	local textures = self._grug_base_texture
	local tint = tier_def(tier).tint
	if textures and tint then
		textures = tint_textures(textures, tint)
	end
	if textures then
		self.base_texture = textures -- reapplied by mob_activate on reload
		self.textures = textures
		self.object:set_properties({textures = textures})
	end
	self._grug_visual_tier = tier
end

--
-- Level assignment
--

local function resolve_level(self, cfg)
	if cfg.fixed then
		-- Hand-set level: bypasses the field AND the source cap on purpose
		-- (the Kraken is L100, kraken.lua).
		return math.max(1, cfg.fixed)
	end
	local cap = LEVEL_CAP[cfg.source] or MAX_LEVEL
	local pos = self.object and self.object:get_pos()
	local level
	if pos then
		if cfg.source == "guard" then
			level = grug_core.guard_level_at(pos)
		else
			level = grug_core.mob_level_at(pos)
		end
	end
	-- The field has no value here (open water surface, ocean for guards):
	-- the def floor is the documented fallback.
	level = level or cfg.min
	level = math.max(cfg.min, math.min(cfg.max or cap, level))
	return math.max(1, math.min(cap, math.round(level)))
end

-- Called from grug_mobs.register_mob for every mob def. Also normalizes the
-- def's armor so a mob is never armor-less during the single step between
-- activation and its first do_custom tick (mobs_redo builds the armor
-- groups from def.armor at activation; nil would mean "no fleshy group" =
-- invulnerable).
function grug_mobs.register_level_cfg(name, def)
	local tier = def._grug_tier or "normal"
	level_cfg[name] = {
		min = def._grug_min_level or 1,
		max = def._grug_max_level,
		source = def._grug_level_source or "mob",
		fixed = def._grug_fixed_level,
		tier = tier,
		xp_override = def._grug_xp_reward,
	}
	def.armor = tier_def(tier).armor or def.armor or 100
end

-- First-tick initialization + per-activation re-hooks. Cheap enough to call
-- on every step: two field comparisons in the steady state.
function grug_mobs.ensure_init(self)
	local cfg = level_cfg[self.name]
	if not cfg then
		return
	end
	if not self._grug_home then
		-- Leash home (combat_stats.md §4, aggro.lua). Plain field -> the
		-- home is the FIRST activation position and survives unload; a mob
		-- reloaded far from home leashes back to where it spawned.
		local pos = self.object and self.object:get_pos()
		if pos then
			self._grug_home = {x = pos.x, y = pos.y, z = pos.z}
		end
	end
	if not self._grug_level then
		-- Plain fields persist via staticdata, so this runs exactly once
		-- per mob, not once per activation.
		self._grug_level = resolve_level(self, cfg)
		self._grug_tier = self._grug_tier or cfg.tier
		apply_tier_visuals(self)
		apply_stats(self, false)
	end
	if self.update_tag ~= update_tag then
		-- Function fields never reach staticdata -> re-install on every
		-- activation. The cached tag text IS a plain field and survives,
		-- while the fresh object's nametag property does not: drop the
		-- cache so the tag is written once for the new object.
		self.update_tag = update_tag
		self._grug_tag = nil
		update_tag(self)
	end
end

-- XP a player earns for killing this mob, before the gray rule.
-- An explicit `_grug_xp_reward` in the def wins (Kraken: 0 = never a farm).
function grug_mobs.kill_xp(self)
	local cfg = level_cfg[self.name]
	if cfg and cfg.xp_override then
		return cfg.xp_override
	end
	if self._grug_xp then
		return self._grug_xp
	end
	local _, _, xp = grug_mobs.stats_for(self._grug_level or 1, self._grug_tier)
	return xp
end

-- Promote/demote a live mob to `tier` ("normal"/"elite"/"rare"): applies the
-- multipliers, scale, tint and nametag. Idempotent, and safe to call before
-- the mob's first tick (the tier is stored and picked up by ensure_init).
-- Used by the rare spawner and by any def-independent tier decision.
function grug_mobs.set_tier(ent, tier)
	if not ent or not ent.object then
		return
	end
	ent._grug_tier = TIERS[tier] and tier or "normal"
	if not ent._grug_level then
		return -- not initialized yet; ensure_init applies everything at once
	end
	apply_tier_visuals(ent)
	apply_stats(ent, true) -- keep the wounded fraction
	update_tag(ent)
end
