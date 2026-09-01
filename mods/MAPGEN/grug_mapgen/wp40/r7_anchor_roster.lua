-- Closed R7 activation roster derived only from the authenticated R4 anchors.

return function(source, zones_session, raw_sha256)
	local function fail(message)
		error("WP40 R7 anchor roster: " .. message, 0)
	end
	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end
	if type(source) ~= "table" or type(source.anchors) ~= "table" or
			#source.anchors ~= 100 or type(source.zones) ~= "table" or
			type(zones_session) ~= "table" or type(zones_session.anchor) ~= "function" or
			type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end
	local rows, ids, family_counts = {}, {}, {capital = 0, outpost = 0, bandit = 0}
	local function add(index, family, content_ref)
		local authored = source.anchors[index]
		local zone = authored and source.zones[authored.zone_numeric_id]
		if type(authored) ~= "table" or authored.numeric_id ~= index or
				type(zone) ~= "table" or type(zone.id) ~= "string" then
			fail("source anchor differs at " .. index)
		end
		local anchor = zones_session.anchor(zone.id, authored.slot_id)
		if type(anchor) ~= "table" or anchor.numeric_id ~= index or
				anchor.id ~= string.format("anchor_%03d", index) or
				anchor.zone_numeric_id ~= authored.zone_numeric_id or
				anchor.slot_id ~= authored.slot_id or type(anchor.x) ~= "number" or
				type(anchor.y) ~= "number" or type(anchor.z) ~= "number" or
				anchor.x % 1 ~= 0 or anchor.y % 1 ~= 0 or anchor.z % 1 ~= 0 or
				anchor.y < 1 or ids[anchor.id] then
			fail("stable anchor differs at " .. index)
		end
		if family == "capital" and anchor.slot_id ~= "capital" then
			fail("capital slot differs")
		elseif family == "outpost" and not anchor.slot_id:match("^outpost_%d+$") then
			fail("outpost slot differs")
		elseif family == "bandit" and not anchor.slot_id:match("^bandit_%d+$") then
			fail("bandit slot differs")
		end
		ids[anchor.id] = true
		family_counts[family] = family_counts[family] + 1
		rows[#rows + 1] = {id = anchor.id, numeric_id = index,
			zone_id = zone.id, slot_id = anchor.slot_id, family = family,
			content_ref = content_ref, x = anchor.x, y = anchor.y, z = anchor.z}
	end
	for index = 7, 12 do add(index, "capital", 2) end
	for index = 25, 48 do add(index, "outpost", 2) end
	for index = 49, 60 do add(index, "bandit", 1) end
	if #rows ~= 42 or family_counts.capital ~= 6 or family_counts.outpost ~= 24 or
			family_counts.bandit ~= 12 then
		fail("closed population differs")
	end
	local bytes = {"schema\tgrug_wp40_r7_anchor_roster_v1\n"}
	for index = 1, #rows do
		local row = rows[index]
		bytes[#bytes + 1] = table.concat({"anchor", row.id, row.numeric_id,
			row.zone_id, row.slot_id, row.family, row.content_ref,
			row.x, row.y, row.z}, "\t") .. "\n"
	end
	local digest = raw_sha256(table.concat(bytes))
	if type(digest) ~= "string" or #digest ~= 32 then fail("SHA-256 seam differs") end
	local function copy_rows()
		local copy = {}
		for index = 1, #rows do
			local row, item = rows[index], {}
			for key, value in pairs(row) do item[key] = value end
			copy[index] = item
		end
		return copy
	end
	return {schema = "grug_wp40_r7_anchor_roster_v1", sha256 = hex(digest),
		rows = rows, canonical_bytes = table.concat(bytes), copy_rows = copy_rows}
end
