-- Destructibility rules (docs/design/world.md §2) as one central
-- core.is_protected override:
--   R1 — own faction continent: free digging/building except protected
--        zones (currently the six race-capital spawn platforms; villages and
--        outposts follow with WP13/WP6).
--   R2 — enemy continent: nothing may be dug or placed (torches included).
--   R3 — ocean: everything outside the two continent rectangles (strait,
--        coastal ocean, open sea) is locked for everyone. Sole exception
--        later: guild housing cubes (R5), which get their own WP.
-- R4 (ore respawn) is deferred to the outpost/mining-zone WPs.

local old_is_protected = core.is_protected

local CAMP_HALF = grug_core.CAMP_HALF

-- Protected zone of a race capital's spawn platform (world.md §2):
--   * horizontally ONLY the platform footprint (|dx|, |dz| <= CAMP_HALF).
--     The terrain right next to a platform stays diggable on purpose — the
--     platform is terrain-adaptive, so its edge can end up against a hillside
--     or in a pocket, and a player who spawns there must be able to dig out.
--   * vertically from POI_PROTECT_DEPTH below the platform upward without a
--     limit: no towers over the capital, no tunnel sabotage from directly
--     below, while mining deeper down stays free.
-- The WP13 structures (real capitals, villages, outposts) will reuse the
-- vertical rule with a LARGER horizontal zone that includes >= 10 nodes of
-- surrounding terrain — spec'd in docs/design/world.md §2.
-- Footprints never overlap (capitals are 550+ nodes apart), so the first
-- matching capital decides.
local function in_capital_zone(pos)
	for race_id, capital in pairs(grug_core.capitals) do
		if math.abs(pos.x - capital.x) <= CAMP_HALF and
				math.abs(pos.z - capital.z) <= CAMP_HALF then
			-- Undecided platform (chunk never generated): the fallback y is
			-- what get_spawn_pos would use too.
			local platform_y = grug_core.get_camp_platform_y(race_id)
				or grug_core.CAMP_PLATFORM_Y
			return pos.y >= platform_y - grug_core.POI_PROTECT_DEPTH
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
