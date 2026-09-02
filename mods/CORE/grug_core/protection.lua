-- One engine-facing protection boundary. The previous handler is captured
-- once, before installation, and is never rediscovered through core.
local previous_is_protected = core.is_protected

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
