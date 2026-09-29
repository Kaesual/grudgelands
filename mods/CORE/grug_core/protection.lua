-- One engine-facing protection boundary. The previous handler is captured
-- once, before installation, and is never rediscovered through core.
local previous_is_protected = core.is_protected

-- System mutations have no player faction. Home territory is mutable for its
-- residents, but authored/immutable content is not mutable for water or plants.
-- Additional system guards (for example a Claim Stone's arrival cube) fail
-- closed when they return false, independently of player protection bypass.
-- They guard system mutations such as liquid flow.
local world_alteration_guards = {}

function grug_core.register_world_alteration_guard(guard)
	assert(type(guard) == "function", "world alteration guard must be a function")
	world_alteration_guards[#world_alteration_guards + 1] = guard
end

-- True when a registered world alteration guard refuses pos. The liquid guard
-- asks this alone for liquids other than water (water_guard.lua).
function grug_core.world_alteration_guarded(pos)
	for index = 1, #world_alteration_guards do
		if world_alteration_guards[index](pos) == false then return true end
	end
	return false
end

-- Natural renewal guards (Round 25 ruling 14): a guard returns false where
-- nothing may regrow (an active Claim Stone's claim). They are separate from
-- the world alteration guards above, so water keeps flowing inside claims.
local natural_renewal_guards = {}

function grug_core.register_natural_renewal_guard(guard)
	assert(type(guard) == "function", "natural renewal guard must be a function")
	natural_renewal_guards[#natural_renewal_guards + 1] = guard
end

-- The territory part alone: whether the world itself may change here (towns,
-- landmarks, the open sea and other immutable ground refuse). Generation
-- never consults claims.
function grug_core.natural_ground_alterable(pos)
	if not grug_core.zone_authority_installed() then return false end
	local territory = grug_zones.territory_rule_at(pos)
	return territory == "accord_home" or territory == "throng_home" or
		territory == "contested_land"
end

-- Whether natural renewal (grug_farming/renewal.lua) may place here: the
-- territory rule plus every natural renewal guard.
function grug_core.natural_renewal_allowed(pos)
	if not grug_core.natural_ground_alterable(pos) then return false end
	for index = 1, #natural_renewal_guards do
		if natural_renewal_guards[index](pos) == false then return false end
	end
	return true
end

function grug_core.world_alterable(pos)
	if not grug_core.natural_ground_alterable(pos) then return false end
	return not grug_core.world_alteration_guarded(pos)
end

function core.is_protected(pos, name)
	-- Preserve the existing bypass behavior: Grudgelands adds no restriction,
	-- but another handler may still object.
	if name ~= "" and
			core.check_player_privs(name, {protection_bypass = true}) then
		return previous_is_protected(pos, name)
	end

	-- Empty/offline actors remain protected. This also avoids consulting
	-- player state that cannot be resolved authoritatively.
	if name == "" then
		return true
	end

	local faction = grug_core.get_player_faction(name)
	if grug_core.world_protected_for_faction(pos, faction) then
		return true
	end
	return previous_is_protected(pos, name)
end

-- Player-facing reason for a refused edit (Round 24 ruling 7), or nil when
-- the position is not protected for this player. It only EXPLAINS the answer
-- core.is_protected gives above; it never decides it.
local PROTECTION_HINTS = {
	town = "Town – protected",
	landmark = "Landmark – protected",
	accord_home = "Accord home territory – protected",
	throng_home = "Throng home territory – protected",
	immutable = "Open sea – protected",
	no_faction = "Protected – choose a faction first",
}

function grug_core.protection_reason(pos, name)
	if not core.is_protected(pos, name) then return nil end
	if name == "" or not grug_core.zone_authority_installed() then
		return "protected"
	end
	local faction = grug_core.get_player_faction(name)
	if faction ~= "accord" and faction ~= "throng" then return "no_faction" end
	local kind = grug_zones.hard_protection_kind_at(pos)
	if kind == "town" or kind == "landmark" then return kind end
	local territory = grug_zones.territory_rule_at(pos)
	if territory == "immutable" or territory == "accord_home" or
			territory == "throng_home" then
		return territory
	end
	return "protected"
end

function grug_core.protection_hint(pos, name)
	local reason = grug_core.protection_reason(pos, name)
	if not reason then return nil end
	return PROTECTION_HINTS[reason] or "Protected"
end
