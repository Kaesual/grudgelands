-- The purchase record is the one source of what a character owns (Round 44:
-- no mount item is handed out; the quickbar lists owned_tier_ids). One
-- highest-owned tier per movement mode; boats are the water mode.
local META_KEY = {
	land = "grug_mounts:land_tier",
	flight = "grug_mounts:flight_tier",
	water = "grug_mounts:water_tier",
}
local owned_changed = {}

local function meta_key(mode)
	return assert(META_KEY[mode], "unknown mount mode")
end

function grug_mounts.highest_owned(player, mode)
	if not player or not player.is_player or not player:is_player() then return 0 end
	return player:get_meta():get_int(meta_key(mode))
end

function grug_mounts.owns_tier(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	return tier ~= nil and grug_mounts.highest_owned(player, tier.mode) >= tier_id
end

function grug_mounts.owned_tier_ids(player)
	local ids = {}
	for tier_id = 1, #grug_mounts.TIERS do
		if grug_mounts.owns_tier(player, tier_id) then ids[#ids + 1] = tier_id end
	end
	return ids
end

function grug_mounts.register_on_owned_tiers_changed(func)
	owned_changed[#owned_changed + 1] = func
end

local function prerequisite_met(player, tier_id)
	if tier_id == 1 then return grug_mounts.highest_owned(player, "land") == 0 end
	if tier_id == 2 then return grug_mounts.highest_owned(player, "land") == 1 end
	if tier_id == 3 then return grug_mounts.highest_owned(player, "land") >= 2 and grug_mounts.highest_owned(player, "flight") == 0 end
	if tier_id == 4 then return grug_mounts.highest_owned(player, "flight") == 3 end
	if tier_id == 5 then return grug_mounts.highest_owned(player, "water") == 0 end
	if tier_id == 6 then return grug_mounts.highest_owned(player, "water") == 5 end
	return false
end

-- What the Riding Trainer and the Shipwright show for one tier (Round 28 ruling 19), in this
-- order: "owned"; "level" (the character is below tier.level); "previous"
-- (the preceding tier is not owned yet -- for a tier not owned this is the
-- same rule prerequisite_met applies); "buy".
-- Returns the state and, for "buy", the price.
function grug_mounts.tier_state(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	if not tier then return nil end
	if grug_mounts.owns_tier(player, tier_id) then return "owned" end
	if grug_xp.get_level(player) < tier.level then return "level" end
	if not prerequisite_met(player, tier_id) then return "previous" end
	return "buy", grug_mounts.PRICES[tier_id]
end

function grug_mounts.purchase(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	if not tier then return false, "Unknown riding tier." end
	if grug_xp.get_level(player) < tier.level then return false, ("Requires level %d."):format(tier.level) end
	if not prerequisite_met(player, tier_id) then
		if grug_mounts.owns_tier(player, tier_id) then return false, "You already own this " ..
			(tier.mode == "water" and "boat." or "riding tier.") end
		return false, "Buy the preceding " .. (tier.mode == "water" and "boat" or "riding tier") .. " first."
	end
	if not grug_mounts.model_for(player, tier_id) then return false, "Choose a faction and race before buying a mount." end
	local price = grug_mounts.PRICES[tier_id]
	if not grug_money.take(player, price) then return false, "You do not have enough money." end
	player:get_meta():set_int(meta_key(tier.mode), tier_id)
	for _, func in ipairs(owned_changed) do func(player) end
	return true, tier.name .. (tier.mode == "water" and " bought. " or " learned. ") ..
		grug_mounts.QUICKBAR_TIP
end
