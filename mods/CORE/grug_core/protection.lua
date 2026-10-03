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

-- Interaction protection (Round 25 ruling 18). The engine asks
-- core.is_protected only for digging and placing; right-clicks, node
-- inventories and node forms are guarded separately. A guard is
-- fn(pos, name) -> true when that player may NOT interact at pos
-- (grug_housing: an active claim without at least "interact" permission).
-- Guards never change digging or placing; core.is_protected alone decides
-- those.
local interaction_guards = {}

function grug_core.register_interaction_guard(guard)
	assert(type(guard) == "function", "interaction guard must be a function")
	interaction_guards[#interaction_guards + 1] = guard
end

local function bypasses(name)
	return name ~= "" and
		core.check_player_privs(name, {protection_bypass = true})
end

-- True when a registered guard refuses this interaction. Players with the
-- protection_bypass privilege are never refused. The privilege is looked up
-- only after a guard refused, so the common case (no claim here) costs one
-- guard call.
function grug_core.interaction_guarded(pos, name)
	for index = 1, #interaction_guards do
		if interaction_guards[index](pos, name) then
			return not bypasses(name)
		end
	end
	return false
end

-- For interaction gates that used to ask core.is_protected (grug_jobs
-- stations): the unchanged world rule for the player's faction plus the
-- guards. It never consults dig/place-only protection, so a claim's
-- "interact" permission is enough to use a station there.
function grug_core.interaction_protected(pos, name)
	if bypasses(name) then return false end
	if name == "" then return true end
	if grug_core.world_protected_for_faction(pos,
			grug_core.get_player_faction(name)) then
		return true
	end
	return grug_core.interaction_guarded(pos, name)
end

-- Reasons for protection that is not the world's own (Round 25: claims). A
-- provider is fn(pos, name) -> key, hint text; nil when it does not apply.
-- The first provider that answers wins, and the world reason wins over every
-- provider.
local reason_providers = {}

function grug_core.register_protection_reason(provider)
	assert(type(provider) == "function",
		"protection reason provider must be a function")
	reason_providers[#reason_providers + 1] = provider
end

-- A creature's ground effect on behalf of a player (dragon scorch and rime,
-- grug_mobs boss_dragons.lua): the zone and territory rule, then the other
-- protection handlers, but not the road and POI layer (Round 25 rulings
-- 15-16 protect roads and settlement cores from player digging and placing;
-- a dragon's own arena core keeps its breath patches). On a road or core the
-- handlers this file wrapped answer instead of core.is_protected, which
-- would answer from that layer.
function grug_core.ground_effect_protected(pos, actor_name)
	if not actor_name or actor_name == "" then return true end
	local faction = grug_core.get_player_faction(actor_name)
	if grug_core.zone_protected_for_faction(pos, faction) then return true end
	if grug_core.world_feature_at(pos) then
		return previous_is_protected(pos, actor_name)
	end
	return core.is_protected(pos, actor_name)
end

-- Player-facing reason for a refused edit (Round 24 ruling 7), or nil when
-- the position is not protected for this player. It only EXPLAINS the answer
-- core.is_protected gives above; it never decides it. A provider's reason
-- also returns its hint text as the second value.
local PROTECTION_HINTS = {
	town = "Town – protected",
	landmark = "Landmark – protected",
	-- Round 25 rulings 15-16 (grug_core.world_feature_at)
	road = "Road – protected",
	bridge = "Bridge – protected",
	village = "Village – protected",
	camp = "Camp – protected",
	fortress = "Fortress – protected",
	poi = "Point of interest – protected",
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
	-- The world reason applies only where the world rule itself refuses this
	-- faction; own home territory refused by a claim is not a territory
	-- refusal.
	if grug_core.world_protected_for_faction(pos, faction) then
		local kind = grug_zones.hard_protection_kind_at(pos)
		if kind == "town" or kind == "landmark" then return kind end
		-- Roads and settlement cores protect for everyone (Round 25 rulings
		-- 15-17), home territory or not, and win over claim reasons.
		local feature = grug_core.world_feature_at(pos)
		if feature then return feature end
		local territory = grug_zones.territory_rule_at(pos)
		if territory == "immutable" or territory == "accord_home" or
				territory == "throng_home" then
			return territory
		end
		return "protected"
	end
	for index = 1, #reason_providers do
		local key, text = reason_providers[index](pos, name)
		if key then return key, text end
	end
	return "protected"
end

function grug_core.protection_hint(pos, name)
	local reason, text = grug_core.protection_reason(pos, name)
	if not reason then return nil end
	return text or PROTECTION_HINTS[reason] or "Protected"
end
