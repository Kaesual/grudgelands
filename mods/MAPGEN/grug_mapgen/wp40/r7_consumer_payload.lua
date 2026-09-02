-- Closed main-environment payload for the R7 consumer installer. Coordinates
-- remain private to the authenticated R4 session; this graph contains only
-- stable anchor references and the ten reviewed rare patrol offsets. The
-- ordered offsets below are the exact authored payload from
-- source/catalog.lua's rare_anchor rows (numeric IDs 91..100). R7 freezes the
-- complete returned graph in its source projection, so this is the sole live
-- copy rather than a second policy hidden in a consumer.

return function(source, authored_source, sha256_hex)
	local RARE_IDS = {
		"grimtusk", "old_whitefang", "korgans_bane", "silkfang",
		"marrowclaw", "dustwing", "emerald_coil", "ashmaw",
		"bonerattle_north", "bonerattle_south",
	}
	local function fail(message)
		error("WP40 R7 consumer payload: " .. message, 0)
	end
	if type(sha256_hex) ~= "function" then
		fail("SHA-256 seam differs")
	end
	if type(source) ~= "table" or type(source.anchors) ~= "table" or
			type(source.zones) ~= "table" or #source.anchors ~= 100 or
			#source.zones ~= 38 or type(authored_source) ~= "table" or
			type(authored_source.anchors) ~= "table" or
			#authored_source.anchors ~= 100 then
		fail("source population differs")
	end
	local function anchor_ref(anchor, required_slot)
		local zone = source.zones[anchor.zone_numeric_id]
		if type(zone) ~= "table" or type(zone.id) ~= "string" or
			(type(required_slot) == "string" and anchor.slot_id ~= required_slot) then
			fail("anchor identity differs")
		end
		return {zone_id = zone.id, slot_id = anchor.slot_id}, zone
	end
	local starts, capitals = {}, {}
	for index = 1, 6 do
		local reference, zone = anchor_ref(source.anchors[index], "start")
		if starts[zone.race_region] or type(zone.race_region) ~= "string" or
				type(zone.faction) ~= "string" then
			fail("start roster differs")
		end
		starts[zone.race_region] = {reference = reference,
			faction = zone.faction}
	end
	for index = 7, 12 do
		local reference, zone = anchor_ref(source.anchors[index], "capital")
		if capitals[zone.race_region] or type(zone.race_region) ~= "string" or
				type(zone.faction) ~= "string" then
			fail("capital roster differs")
		end
		capitals[zone.race_region] = {reference = reference,
			faction = zone.faction}
	end
	local races = {}
	for _, race in ipairs({"dwarf", "human", "elf", "undead", "orc", "troll"}) do
		local start, capital = starts[race], capitals[race]
		if not start or not capital or start.faction ~= capital.faction then
			fail("race anchor pairing differs")
		end
		races[#races + 1] = {race_id = race, faction_id = start.faction,
			start = start.reference, capital = capital.reference}
	end
	local outposts = {}
	for index = 25, 48 do
		local reference, zone = anchor_ref(source.anchors[index])
		local race = zone.race_region
		if not source.anchors[index].slot_id:match("^outpost_%d+$") or
				type(race) ~= "string" or not starts[race] then
			fail("outpost roster differs")
		end
		outposts[#outposts + 1] = {race_id = race,
			faction_id = starts[race].faction, anchor = reference}
	end
	local rare_routes = {}
	for offset = 1, 10 do
		local anchor = source.anchors[90 + offset]
		local authored = authored_source.anchors[90 + offset]
		local reference = anchor_ref(anchor)
		local zone = source.zones[anchor.zone_numeric_id]
		if anchor.numeric_id ~= authored.numeric_id or
				authored.zone_id ~= zone.id or authored.slot_id ~= anchor.slot_id or
				authored.patrol_coordinate_space ~=
					"selected_candidate_relative" or
				type(authored.patrol_offsets) ~= "table" or
				#authored.patrol_offsets ~= 3 or
				not anchor.slot_id:match("^rare_") then
			fail("rare roster differs")
		end
		local patrol = {}
		for index = 1, #authored.patrol_offsets do
			local point = authored.patrol_offsets[index]
			if type(point) ~= "table" or type(point.x) ~= "number" or
					type(point.z) ~= "number" then
				fail("rare patrol authority differs")
			end
			patrol[index] = {x = point.x, z = point.z}
		end
		rare_routes[offset] = {id = RARE_IDS[offset], anchor = reference,
			patrol_offsets = patrol}
	end
	local payload = {schema = "grug_wp40_r7_consumer_payload_v1",
		races = races, outposts = outposts, rare_routes = rare_routes}
	local bytes = {"schema\tgrug_wp40_r7_consumer_payload_v1\n"}
	for index = 1, #races do
		local row = races[index]
		bytes[#bytes + 1] = table.concat({"race", row.race_id,
			row.faction_id, row.start.zone_id, row.start.slot_id,
			row.capital.zone_id, row.capital.slot_id}, "\t") .. "\n"
	end
	for index = 1, #outposts do
		local row = outposts[index]
		bytes[#bytes + 1] = table.concat({"outpost", row.race_id,
			row.faction_id, row.anchor.zone_id, row.anchor.slot_id}, "\t") .. "\n"
	end
	for index = 1, #rare_routes do
		local row, fields = rare_routes[index], {"rare", rare_routes[index].id,
			rare_routes[index].anchor.zone_id,
			rare_routes[index].anchor.slot_id}
		for offset = 1, #row.patrol_offsets do
			fields[#fields + 1] = tostring(row.patrol_offsets[offset].x)
			fields[#fields + 1] = tostring(row.patrol_offsets[offset].z)
		end
		bytes[#bytes + 1] = table.concat(fields, "\t") .. "\n"
	end
	payload.sha256 = sha256_hex(table.concat(bytes))
	if type(payload.sha256) ~= "string" or #payload.sha256 ~= 64 or
			not payload.sha256:match("^[0-9a-f]+$") then
		fail("SHA-256 result differs")
	end
	return payload
end
