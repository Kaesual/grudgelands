-- Scout class and its Sidestep window (docs/design/scout.md).

local SIDESTEP_DURATION = 3
local sidestep_expiry = {}

grug_classes.register_class({
	id = "scout",
	name = "Scout",
	description = "Ranged hunter and agile blade fighter. Carries a bow in\n" ..
		"the Ranged slot and a sword or dagger in the Melee slot, and survives\n" ..
		"through movement and dodge.",
	growth = {str = 1, int = 1, dex = 2},
	resource = "mana",
	armor_rank = 2,
})

-- Sidestep is a base ability, so its fixed +15 percentage points of dodge
-- live here, for 3 s (round53-plan.md §3). Shake Loose (Veil V11, the class
-- key sidestep_frees) also clears the slows and roots on the Scout at the
-- cast (the existing helper, roots included: the user's ruling); no
-- immunity follows.
function grug_classes.start_sidestep(player)
	local expiry = core.get_us_time() + SIDESTEP_DURATION * 1e6
	sidestep_expiry[player:get_player_name()] = expiry
	-- The status icon shares the window's expiry; death and leave clear both.
	if grug_core.set_status then
		grug_core.set_status(player, "sidestep", {
			label = "Sidestep", expiry_us = expiry,
		})
	end
	if grug_classes.get_talent_bonus(player, "sidestep_frees") > 0 then
		grug_core.clear_negative_move_modifiers(player)
	end
end

function grug_classes.sidestep_active(player)
	local name = player:get_player_name()
	local expiry = sidestep_expiry[name]
	if not expiry or core.get_us_time() >= expiry then
		sidestep_expiry[name] = nil
		return false
	end
	return true
end

function grug_classes.get_scout_dodge_add(player)
	return grug_classes.sidestep_active(player) and 15 or 0
end

-- Sidestep stays inside the ordinary dodge cap.
function grug_classes.get_scout_dodge_cap()
	return 30
end

local function clear_runtime(player)
	sidestep_expiry[player:get_player_name()] = nil
end

core.register_on_dieplayer(clear_runtime)
core.register_on_leaveplayer(clear_runtime)
