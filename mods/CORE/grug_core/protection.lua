-- Destructibility rules (docs/design/world.md §2) as one central
-- core.is_protected override:
--   R1 — own faction territory: free digging/building except protected zones
--        (currently the spawn camps; capitals/outposts follow with WP13/WP6).
--   R2 — enemy territory: nothing may be dug or placed (torches included).
--   R3 — neutral borderland: locked for everyone (fair PvP battlefield).
--   Housing frontier (|z| > HOUSING_Z): locked until plots (R5) ship.
-- R4 (ore respawn) is deferred to the outpost/mining-zone WPs.

local old_is_protected = core.is_protected

local function in_camp_zone(pos)
	local r = grug_core.CAMP_PROTECT_RADIUS
	for _, def in pairs(grug_core.factions) do
		local s = def.spawn
		if math.abs(pos.x - s.x) <= r and math.abs(pos.z - s.z) <= r then
			return true
		end
	end
	return false
end

function core.is_protected(pos, name)
	if name ~= "" and
			core.check_player_privs(name, {protection_bypass = true}) then
		return old_is_protected(pos, name)
	end

	local territory = grug_core.territory_at(pos)
	if territory == "neutral" then
		return true -- R3
	end
	if math.abs(pos.z) > grug_core.HOUSING_Z then
		return true -- housing frontier, plots not implemented yet
	end
	-- Factionless actors (offline names, mods asking with "") get the safe
	-- default: protected.
	if grug_core.get_player_faction(name) ~= territory then
		return true -- R2
	end
	if in_camp_zone(pos) then
		return true -- protected zone inside own territory
	end
	return old_is_protected(pos, name) -- R1, other mods may still object
end
