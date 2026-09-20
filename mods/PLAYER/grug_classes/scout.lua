-- Scout class and runtime windows (docs/design/scout.md).

local META_UNTOUCHABLE_READY = "grug_classes:untouchable_ready"
local sidestep_expiry = {}

grug_classes.register_class({
	id = "scout",
	name = "Scout",
	description = "Ranged hunter and agile blade fighter. Uses a bow or\n" ..
		"main-hand melee weapon and survives through movement and dodge.",
	growth = {str = 1, int = 1, dex = 2},
	resource = "mana",
	armor_rank = 2,
})

-- Sidestep is a base ability, so its fixed +15 percentage points do not live
-- in the talent registry. Shake Loose adds movement immunity to this same
-- four-second window; Untouchable uses the talent registry's timed bonus.
function grug_classes.start_sidestep(player)
	sidestep_expiry[player:get_player_name()] = core.get_us_time() + 4e6
	if grug_classes.get_talent_bonus(player, "root_slow_immunity") > 0 then
		grug_core.set_move_immunity(player, 4)
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

function grug_classes.get_scout_dodge_cap(player)
	return math.max(30,
		grug_classes.get_talent_bonus(player, "dodge_cap_override"))
end

-- The central HP modifier has already resolved dodge, armor and absorb when
-- this callback runs. Only a surviving hostile punch that crosses below 30%
-- starts the six-second window; its 180-second cooldown persists through a
-- reconnect and is not reset by death.
core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change >= 0 or reason.type ~= "punch" or
			grug_classes.talent_rank(player, "untouchable") <= 0 then
		return
	end
	local hp_after = player:get_hp() + hp_change
	local properties = player:get_properties() or {}
	local max_hp = tonumber(properties.hp_max) or 0
	if hp_after <= 0 or max_hp <= 0 or hp_after >= max_hp * 0.30 then
		return
	end
	local now = os.time()
	local meta = player:get_meta()
	if now < (tonumber(meta:get_string(META_UNTOUCHABLE_READY)) or 0) then
		return
	end
	meta:set_string(META_UNTOUCHABLE_READY, tostring(now + 180))
	grug_classes.start_talent_window(player, "untouchable", 6)
end, false)

local function clear_runtime(player)
	sidestep_expiry[player:get_player_name()] = nil
end

core.register_on_dieplayer(clear_runtime)
core.register_on_leaveplayer(clear_runtime)
