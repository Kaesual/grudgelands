-- Environmental damage for mobs in percent of their pool (Round 28 ruling 6,
-- combat_stats.md "Environmental damage").
--
-- The vendored mobs_redo applies flat per-mob amounts (lava 4, sun 2, ...),
-- which made high-level mobs nearly immortal: an L30 zombie (764 HP) lasted
-- 6.4 minutes in the sun. For a grug_mobs mob the def values are now only
-- on/off switches; the GRUG PATCH in mobs/api.lua (`grug_env_damage`,
-- `falling`) asks this file for the amount. Same shape as the player rules in
-- grug_core/environment_damage.lua: a share of the pool, rounded up, at least
-- 1 HP for any positive pool.

-- Share of hp_max per environment tick (mobs_redo ticks once per second).
grug_mobs.ENV_DAMAGE_PERCENT = {
	sun = 5, -- light_damage > 0 and the light in its min/max window
	lava = 20,
	fire = 10,
	water = 10, -- only mobs whose water_damage switch is on
	suffocation = 5,
}

local KING_PREFIX = "grug_mobs:king_"
-- A fortress General is the king chassis without a crown (Round 31).
local GENERAL_PREFIX = "grug_mobs:general_"

-- 0 = immune, 0.5 = half, 1 = full. Bosses (the boss tier: the dragons), the
-- kings and the fortress Generals are immune. A king or General is an
-- elite-tier actor (bosses.lua king_def), so the tier alone cannot tell him
-- from his guards; his registered name is the static marker.
-- Elite and rare tiers take half. Positive tests only: a tier added later is
-- full damage until someone decides otherwise.
function grug_mobs.env_damage_scale(tier, name)
	if tier == "boss" then
		return 0
	end
	if type(name) == "string" and (name:sub(1, #KING_PREFIX) == KING_PREFIX or
			name:sub(1, #GENERAL_PREFIX) == GENERAL_PREFIX) then
		return 0
	end
	if tier == "elite" or tier == "rare" then
		return 0.5
	end
	return 1
end

-- ceil(hp_max * percent * scale / 100), at least 1 when anything is due.
function grug_mobs.env_damage_share(hp_max, percent, scale)
	hp_max = tonumber(hp_max) or 0
	if hp_max <= 0 or scale <= 0 or percent <= 0 then
		return 0
	end
	return math.max(1, math.ceil(hp_max * percent * scale / 100))
end

-- Fall damage with the player's shape: ceil(hp_max * (d - 6) / 20). `excess`
-- is the fall height beyond 6 nodes after the floor's fall_damage_add_percent.
function grug_mobs.fall_damage_share(hp_max, excess, scale)
	hp_max = tonumber(hp_max) or 0
	if hp_max <= 0 or scale <= 0 or excess <= 0 then
		return 0
	end
	return math.max(1, math.ceil(hp_max * excess * scale / 20))
end

local function pool(self)
	if self.hp_max then
		return self.hp_max
	end
	local props = self.object and self.object:get_properties()
	return props and props.hp_max or 0
end

-- `kind` is a key of ENV_DAMAGE_PERCENT. The caller has already tested the
-- mob's own switch and the node.
function grug_mobs.env_damage(self, kind)
	return grug_mobs.env_damage_share(pool(self),
		grug_mobs.ENV_DAMAGE_PERCENT[kind] or 0,
		grug_mobs.env_damage_scale(self._grug_tier, self.name))
end

function grug_mobs.fall_damage(self, excess)
	return grug_mobs.fall_damage_share(pool(self), excess,
		grug_mobs.env_damage_scale(self._grug_tier, self.name))
end
