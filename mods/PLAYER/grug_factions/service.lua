-- Ruling 13 (Round 31, pvp-plan.md): the NPC's faction, not the place,
-- decides whom it serves. Quest givers, vendors, trainers, innkeepers,
-- stewards and waystones serve only their own faction; an NPC without a
-- faction serves everyone. Every refusal is the same line. Needs only
-- grug_factions.get_faction and display_name, so fixtures load it on fakes.

-- Does an NPC of `npc_faction` (nil: of no faction) serve this player? A
-- player without a faction yet (character creation) is nobody's.
function grug_factions.serves(npc_faction, player)
	return npc_faction == nil or grug_factions.get_faction(player) == npc_faction
end

-- The one refusal line: "<Bess Honeycrust> I serve only The Accord."
function grug_factions.refusal(subject, npc_faction)
	return "<" .. subject .. "> I serve only " ..
		(grug_factions.display_name(npc_faction) or npc_faction) .. "."
end

-- Says the refusal line to the player, at most once every two seconds per
-- player: a held mouse button clicks again and again.
local REFUSE_US = 2000000
local said = {}
function grug_factions.refuse(player, subject, npc_faction)
	local name, now = player:get_player_name(), core.get_us_time()
	if said[name] and now - said[name] < REFUSE_US then return end
	said[name] = now
	core.chat_send_player(name, grug_factions.refusal(subject, npc_faction))
end
core.register_on_leaveplayer(function(player) said[player:get_player_name()] = nil end)
