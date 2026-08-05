wob_core = {}

-- Welt-Layout: Allianz-Territorium im Sueden (z < 0), Horde im Norden (z > 0).
-- Die Grenze verlaeuft entlang z = 0; Schwierigkeit steigt mit |z| (Distanz
-- zur Grenze). Spawn-Positionen sind Platzhalter, bis der eigene Mapgen
-- Fraktionslager setzt (y wird beim Teleport per Surface-Suche korrigiert).
wob_core.BORDER_Z = 0

wob_core.factions = {
	alliance = {
		id = "alliance",
		name = "Allianz",
		color = "#3f6fce",
		spawn = vector.new(0, 8, -200),
	},
	horde = {
		id = "horde",
		name = "Horde",
		color = "#c41e3a",
		spawn = vector.new(0, 8, 200),
	},
}

wob_core.faction_ids = {"alliance", "horde"}

function wob_core.opposing_faction(faction_id)
	return faction_id == "alliance" and "horde" or "alliance"
end

-- Findet eine sichere Oberflaechen-Position nahe pos (fuer Spawns/Teleports),
-- solange der Mapgen noch keine garantierten Lager-Plattformen setzt.
function wob_core.find_surface(pos)
	for y = 80, -16, -1 do
		local p = vector.new(pos.x, y, pos.z)
		local node = core.get_node_or_nil(p)
		local below = core.get_node_or_nil(vector.offset(p, 0, -1, 0))
		if node and below and node.name == "air" and
				below.name ~= "air" and below.name ~= "ignore" and
				core.get_item_group(below.name, "liquid") == 0 then
			return p
		end
	end
	return pos
end
