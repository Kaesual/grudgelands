-- Enchant colours on the body and on an NPC's weapon (round31-plan.md §2.2,
-- character_visuals.md). Pure: no ObjectRef, no inventory; apply.lua reads
-- the affixes and hands them in, a fixture loads this file against stubs.
--
-- The colours and the masks belong to grug_gear (enchant_colors.lua); this
-- file only finds the worn overlay a piece is drawn with, whose mask the
-- layers must use, and builds compose's `armor_layers` seam from it.

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

-- The colour layers of one worn armour item: the overlay compose draws for it
-- carries the masks. nil for a plain piece or anything that is not armour.
function grug_visuals.armor_layer(itemname, slot, prefix, suffix)
	local entry = grug_visuals.armor_appearance[itemname]
	if not entry or (not prefix and not suffix) then
		return nil
	end
	local art = grug_visuals.OVERLAY[grug_visuals.LINE_ART[entry.line]]
	local overlay = art and art[slot] and art[slot][entry.bracket]
	return overlay and grug_gear.enchant_layers(overlay, prefix, suffix) or nil
end

-- compose's `armor_layers` from {slot = {name = itemname, affixes = {...}}};
-- nil when no worn piece is enchanted, so a plain set keeps its old key.
function grug_visuals.armor_layers(worn)
	local layers
	for _, slot in ipairs(grug_visuals.SLOTS) do
		local piece = worn[slot]
		if piece then
			local layer = grug_visuals.armor_layer(piece.name, slot,
				grug_visuals.affix_pair(piece.affixes))
			if layer then
				layers = layers or {}
				layers[slot] = layer
			end
		end
	end
	return layers
end
