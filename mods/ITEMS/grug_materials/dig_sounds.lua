-- Dig sounds for the two tool groups of our own (Round 35). A node without a
-- `dig` sound plays the engine default "__group": `default_dig_<group>` of
-- the group the tool digs it by. Ores, coal and gem ores are dug by
-- `grug_resource` and sand by `grug_loose`, which have no such file, so they
-- were silent. A node of either group without its own dig sound gets the
-- shipped one of its kind: a resource the stone's, loose ground the crumbly
-- one (what dirt and a bare hand on sand play). Existing files only (user).

grug_materials.RESOURCE_DIG_SOUND = {name = "default_dig_cracky", gain = 0.5}
grug_materials.LOOSE_DIG_SOUND = {name = "default_dig_crumbly", gain = 0.4}

-- The dig sound a node definition lacks, or nil when it has one or needs none.
function grug_materials.missing_dig_sound(def)
	if def.sounds and def.sounds.dig then return nil end
	local groups = def.groups or {}
	if (groups.grug_resource or 0) > 0 then return grug_materials.RESOURCE_DIG_SOUND end
	if (groups.grug_loose or 0) > 0 then return grug_materials.LOOSE_DIG_SOUND end
	return nil
end

-- After every mod: grug_nodes and others register loose ground of their own.
core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		local dig = grug_materials.missing_dig_sound(def)
		if dig then
			local sounds = table.copy(def.sounds or {})
			sounds.dig = table.copy(dig)
			core.override_item(name, {sounds = sounds})
		end
	end
end)
