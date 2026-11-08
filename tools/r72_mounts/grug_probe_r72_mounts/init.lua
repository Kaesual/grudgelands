-- Disposable Round 72 MOUNTS probe (never shipped): the enemy-town rule
-- (grug_mounts.enemy_town_at) on the real world authority and settlement
-- registry. Logs "[r72mounts]" lines, then shuts the server down:
--   * every start town and capital (a settlement anchor in a hard "town"
--     footprint): its race and faction, whether the rule calls it an enemy
--     town for the Accord, the Throng and a character without a faction,
--     and the territory rule of the zone at its anchor (the cross-check);
--   * the six start positions: enemy for the other faction only;
--   * the line: from each capital and start anchor east, the first column
--     the rule no longer holds;
--   * the cost of one question (core.get_us_time over many calls) inside a
--     town box and on open land.
--   PROBE=tools/r72_mounts/grug_probe_r72_mounts tools/luanti_headless.sh 120
local function log(fmt, ...)
	core.log("action", "[r72mounts] " .. fmt:format(...))
end

local function run()
	local faction_of_race = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	local footprints, towns, bad = {}, 0, 0
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local a = row.anchor
		local id, kind = grug_zones.hard_footprint_in(a.x, a.z, a.x, a.z)
		if kind == "town" then
			towns = towns + 1
			local faction = faction_of_race[row.race_id]
			local for_accord = grug_mounts.enemy_town_at("accord", a.x, a.z)
			local for_throng = grug_mounts.enemy_town_at("throng", a.x, a.z)
			local for_none = grug_mounts.enemy_town_at(nil, a.x, a.z)
			local zone = grug_zones.id_at(a.x, a.z)
			local record = zone and grug_zones.get(zone)
			local territory = record and record.territory_rule
			local ok = for_accord == (faction == "throng") and for_throng == (faction == "accord") and
				not for_none and territory == faction .. "_home"
			if not ok then bad = bad + 1 end
			if footprints[id] and footprints[id] ~= faction then bad = bad + 1 end
			footprints[id] = faction
			-- The line east of the anchor for the other faction.
			local other = faction == "accord" and "throng" or "accord"
			local edge
			for dx = 0, 400 do
				if not grug_mounts.enemy_town_at(other, a.x + dx, a.z) then edge = dx break end
			end
			log("town %s slot=%s race=%s faction=%s footprint=%s enemy_for_accord=%s " ..
				"enemy_for_throng=%s factionless=%s zone=%s territory=%s line_east=%s %s",
				row.key, row.slot, row.race_id, tostring(faction), tostring(id),
				tostring(for_accord), tostring(for_throng), tostring(for_none), tostring(zone),
				tostring(territory), tostring(edge), ok and "OK" or "MISMATCH")
		end
	end
	local distinct = 0
	for _ in pairs(footprints) do distinct = distinct + 1 end
	log("towns=%d footprints=%d mismatches=%d", towns, distinct, bad)
	for _, identity in ipairs(grug_core.start_identities()) do
		local p = grug_core.start_position(identity.faction_id, identity.race_id)
		local own = grug_mounts.enemy_town_at(identity.faction_id, p.x, p.z)
		local other = grug_mounts.enemy_town_at(identity.faction_id == "accord" and "throng" or "accord",
			p.x, p.z)
		local none = grug_mounts.enemy_town_at(nil, p.x, p.z)
		log("start %s %s pos=%d,%d own=%s other=%s factionless=%s %s", identity.race_id,
			identity.faction_id, p.x, p.z, tostring(own), tostring(other), tostring(none),
			(not own and other and not none) and "OK" or "MISMATCH")
	end
	-- Cost: 200 x 100 columns round the orc capital's anchor (inside its box)
	-- and on the same grid shifted 3000 nodes (open land), for an Accord rider.
	local capital = grug_core.capital_anchor("throng", "orc")
	for _, shift in ipairs({0, 3000}) do
		local started, calls, hits = core.get_us_time(), 0, 0
		for dz = -50, 49 do
			for dx = -100, 99 do
				calls = calls + 1
				if grug_mounts.enemy_town_at("accord", capital.x + dx + shift, capital.z + dz) then
					hits = hits + 1
				end
			end
		end
		local us = core.get_us_time() - started
		log("cost shift=%d calls=%d enemy=%d total_us=%d per_call_us=%.3f", shift, calls, hits, us,
			us / calls)
	end
	core.request_shutdown("r72mounts probe done")
end

core.register_on_mods_loaded(function()
	core.after(1, run)
end)
