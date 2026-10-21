-- Enchant colours on the body, the offhand item and an NPC's weapon
-- (round31-plan.md §2.2, character_visuals.md). Pure: no ObjectRef, no
-- inventory; apply.lua reads the affixes and hands them in, a fixture loads
-- this file against stubs.
--
-- The colours and the masks belong to grug_gear (enchant_colors.lua); compose
-- lays them over each worn piece's own files (its atlas layer and its skin
-- layer, each with its mask) and over the offhand layer. This file only turns
-- the stacks' affixes into compose's `armor_enchant` and `offhand_enchant`
-- seams.

-- The prefix and suffix stat of an affix list (grug_items.get_affixes).
function grug_visuals.affix_pair(affixes)
	local prefix, suffix
	for _, affix in ipairs(type(affixes) == "table" and affixes or {}) do
		if affix.channel == "prefix" then
			prefix = affix.stat
		elseif affix.channel == "suffix" then
			suffix = affix.stat
		end
	end
	return prefix, suffix
end

-- {prefix = stat, suffix = stat} with the stats that have a colour, nil
-- when neither has one.
local function coloured(prefix, suffix)
	local colors = grug_gear.ENCHANT_COLORS
	prefix = prefix and colors[prefix] and prefix or nil
	suffix = suffix and colors[suffix] and suffix or nil
	if not prefix and not suffix then
		return nil
	end
	return {prefix = prefix, suffix = suffix}
end

-- The colours of one worn armour item: {prefix = stat, suffix = stat} with
-- the stats that have a colour, nil for a plain piece or anything that is
-- not armour.
function grug_visuals.armor_enchant(itemname, prefix, suffix)
	if not grug_visuals.armor_appearance[itemname] then
		return nil
	end
	return coloured(prefix, suffix)
end

-- The same for the offhand item (Round 55, compose's `offhand_enchant`): nil
-- for a plain one or anything the model does not draw (a Scout's blade).
function grug_visuals.offhand_enchant(itemname, prefix, suffix)
	if not grug_visuals.offhand_appearance[itemname] then
		return nil
	end
	return coloured(prefix, suffix)
end

-- compose's `armor_enchant` from {slot = {name = itemname, affixes = {...}}};
-- nil when no worn piece is enchanted, so a plain set keeps its old key.
function grug_visuals.armor_enchants(worn)
	local enchants
	for _, slot in ipairs(grug_visuals.SLOTS) do
		local piece = worn[slot]
		if piece then
			local enchant = grug_visuals.armor_enchant(piece.name,
				grug_visuals.affix_pair(piece.affixes))
			if enchant then
				enchants = enchants or {}
				enchants[slot] = enchant
			end
		end
	end
	return enchants
end
