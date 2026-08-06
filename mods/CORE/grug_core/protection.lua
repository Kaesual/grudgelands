-- Destructibility rules (docs/design/world.md §2) as one central
-- core.is_protected override:
--   R1 — own faction continent: free digging/building except protected
--        zones (currently the race capitals; outposts follow with WP13/WP6).
--   R2 — enemy continent: nothing may be dug or placed (torches included).
--   R3 — ocean: everything outside the two continent rectangles (strait,
--        coastal ocean, open sea) is locked for everyone. Sole exception
--        later: guild housing cubes (R5), which get their own WP.
-- R4 (ore respawn) is deferred to the outpost/mining-zone WPs.

local old_is_protected = core.is_protected

local function in_capital_zone(pos)
	local r = grug_core.CAMP_PROTECT_RADIUS
	for _, capital in pairs(grug_core.capitals) do
		if math.abs(pos.x - capital.x) <= r and
				math.abs(pos.z - capital.z) <= r then
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
	if territory == "ocean" then
		return true -- R3
	end
	-- Factionless actors (offline names, mods asking with "") get the safe
	-- default: protected.
	if grug_core.get_player_faction(name) ~= territory then
		return true -- R2
	end
	if in_capital_zone(pos) then
		return true -- protected zone inside the own continent
	end
	return old_is_protected(pos, name) -- R1, other mods may still object
end
