local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function tier_status(player, tier_id)
	local tier = grug_mounts.TIERS[tier_id]
	if grug_mounts.owns_tier(player, tier_id) then return "Owned", false end
	local price = grug_mounts.price_for_tier(tier_id)
	if not price then return "Price pending", false end
	return grug_money.format(price), true
end

local function formspec(player)
	local fragments = {
		"box[5.45,0.20;3.60,4.65;#151515d8]",
		"label[5.70,0.42;Riding]",
		"label[5.70,0.76;Universal skill — no profession slot]",
	}
	local level = grug_xp.get_level(player)
	local row = 0
	for tier_id = 1, 4 do
		local tier = grug_mounts.TIERS[tier_id]
		if level >= tier.level then
			local status, can_buy = tier_status(player, tier_id)
			local y = 1.18 + row * 0.86
			fragments[#fragments + 1] = ("label[5.70,%.2f;%s (L%d)]")
				:format(y, esc(tier.name), tier.level)
			if can_buy then
				fragments[#fragments + 1] = ("button[7.22,%.2f;1.55,0.62;" ..
					"grug_mounts_buy_%d;Buy %s]"):format(y - 0.18, tier_id,
					esc(status))
			else
				fragments[#fragments + 1] = ("label[7.28,%.2f;%s]")
					:format(y, esc(status))
			end
			row = row + 1
		end
	end
	if row == 0 then
		fragments[#fragments + 1] = "label[5.70,1.35;First riding tier unlocks at level 15.]"
	end
	return {size = "size[9.25,5.15]", fragments = fragments}
end

function grug_mounts.trainer_hook(context)
	if context.action == "formspec" then return formspec(context.player) end
	if context.action ~= "fields" then return false end
	for tier_id = 1, 4 do
		if context.fields["grug_mounts_buy_" .. tier_id] then
			local ok, message = grug_mounts.purchase(context.player, tier_id)
			core.chat_send_player(context.player:get_player_name(), message)
			return true
		end
	end
	return false
end

grug_jobs.register_trainer_hook(grug_mounts.trainer_hook)
