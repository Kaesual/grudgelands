-- Disposable Round 72 TAGS probe (tools/r72_tags/run.sh). Never shipped.
--
-- The question: on real entities, do a start town's guards and tagged NPCs
-- resolve to their faction (combat_stats.md "Nametag categories")? The
-- first race's start is force-loaded until its NPCs stand; then, per socket
-- role, the colour of each NPC's held carrier and its number of carriers.
-- Nobody is connected, so no foe carrier may exist and every guard's held
-- tag must be the friend green and every other tagged NPC's the light green.
-- Every line carries "[r72tags]"; the probe ends the server when done.
local P = "[r72tags] "
local function log(s) core.log("action", P .. s) end
local GREEN, LIGHT = "#4bdc4b", "#b9f5b0"
local GUARD_ROLES = {guard_post = true, guard_patrol = true, captain = true,
	commander = true, king = true}

local function hex(c)
	if type(c) == "string" then return c:lower():sub(1, 7) end
	if type(c) ~= "table" then return tostring(c) end
	return ("#%02x%02x%02x"):format(c.r or 0, c.g or 0, c.b or 0)
end

local total_t, key, anchor, emerge_left, settled_at = 0, nil, nil, nil, nil
local last_count, stable = -1, 0

local function census(final)
	local by, count, bad = {}, 0, 0
	for _, object in ipairs(core.get_objects_inside_radius(anchor, 90)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_start == key and ent._grug_socket_role then
			count = count + 1
			local role = ent._grug_socket_role
			local carrier = ent.temp and ent.temp.grug_tag_carrier
			local colour = "none"
			if carrier and carrier:is_valid() then
				colour = hex(carrier:get_properties().nametag_color)
			end
			local carriers = 0
			for _, child in ipairs(object:get_children()) do
				local c = child:get_luaentity()
				if c and c.name == "grug_core:tag_carrier" then carriers = carriers + 1 end
			end
			local want = GUARD_ROLES[role] and GREEN or
				(role == "idle" or role == "work") and "none" or LIGHT
			local ok = colour == want and carriers == (want == "none" and 0 or 1)
			if not ok then bad = bad + 1 end
			local row_key = role .. " " .. colour .. " carriers=" .. carriers ..
				(ok and "" or " UNEXPECTED")
			by[row_key] = (by[row_key] or 0) + 1
		end
	end
	if final then
		local rows = {}
		for k, n in pairs(by) do rows[#rows + 1] = k .. ": " .. n end
		table.sort(rows)
		for _, row in ipairs(rows) do log(row) end
		log(("%s: %d NPCs, %d unexpected"):format(key, count, bad))
	end
	return count, bad
end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	if not key then
		if total_t < 3 or not grug_core.zone_authority_installed() then return end
		local identity = grug_core.start_identities()[1]
		for _, record in ipairs(grug_core.settlement_socket_settlements()) do
			if record.race_id == identity.race_id then key = record.key; break end
		end
		anchor = grug_core.settlement_socket_anchor(key)
		log(("start %s of %s at %s"):format(key, identity.faction_id, core.pos_to_string(anchor)))
		local minp = {x = anchor.x - 64, y = anchor.y - 16, z = anchor.z - 64}
		local maxp = {x = anchor.x + 64, y = anchor.y + 24, z = anchor.z + 64}
		for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
		emerge_left = 1
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining == 0 then emerge_left = 0; settled_at = total_t end
		end)
		return
	end
	if not settled_at or total_t - settled_at < 10 then return end
	-- Every 5 s; done once the count held for three looks (and the carrier
	-- pass, once a second, has visited every carrier since).
	if math.floor(total_t / 5) == math.floor((total_t - dtime) / 5) then return end
	local count = census(false)
	stable = (count == last_count and count > 0) and stable + 1 or 0
	last_count = count
	if stable >= 3 or total_t - settled_at > 150 then
		local n, bad = census(true)
		log((n > 0 and bad == 0) and "RESULT PASS" or "RESULT FAIL")
		core.request_shutdown("r72tags probe done", false, 0)
		key = false
	end
end)
