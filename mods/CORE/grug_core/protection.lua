-- One engine-facing protection boundary. The previous handler is captured
-- once, before installation, and is never rediscovered through core.
local previous_is_protected = core.is_protected

-- System mutations have no player faction. Home territory is mutable for its
-- residents, but authored/immutable content is not mutable for water or plants.
-- Additional system guards (for example active Housing reservations) fail
-- closed when they return false, independently of player protection bypass.
local world_alteration_guards = {}

function grug_core.register_world_alteration_guard(guard)
	assert(type(guard) == "function", "world alteration guard must be a function")
	world_alteration_guards[#world_alteration_guards + 1] = guard
end

function grug_core.world_alterable(pos)
	if not grug_core.zone_authority_installed() then return false end
	local territory = grug_zones.territory_rule_at(pos)
	if territory ~= "accord_home" and territory ~= "throng_home" and
			territory ~= "contested_land" and territory ~= "holy_grounds" then
		return false
	end
	for index = 1, #world_alteration_guards do
		if world_alteration_guards[index](pos) == false then return false end
	end
	return true
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
