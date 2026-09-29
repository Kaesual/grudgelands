-- The Claim Stone model (Round 25 Lane A, docs/planning/round25-housing-plan.md
-- rulings 1-12): claims and per-player records, their persistence, the claim
-- grid, fuel as a "paid until" time, permissions, daily limits and placement
-- validation. Pure: every engine or world access is injected, so the same
-- bytes run in the engine (api.lua) and in tools/r25_claim_core/fixture.lua.
--
--   api.storage   get_string(key), set_string(key, value), keys() -> array
--                 (mod storage; "" deletes a key)
--   api.now()     wall-clock seconds (os.time()); server downtime counts
--
-- Storage keys, one line each (player names are [A-Za-z0-9_-], so "|", ","
-- and "=" never occur inside a field):
--   next_id             the next claim id
--   claim:<id>          v1|owner|x|y|z|placed_at|paid_until|expired_for|perms
--                       perms = name=level,name=level
--   player:<name>       v1|state|claim_id|last_place_at|last_pickup_at
return function(api)
	assert(type(api) == "table" and type(api.storage) == "table" and
		type(api.now) == "function", "grug_housing registry: api missing")
	local storage, now = api.storage, api.now
	local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

	local M = {}
	M.RADIUS = 50            -- ruling 1: 101 x 101 around the stone
	M.MIN_Y = -100           -- rulings 1-2: the claim and the stone from y -100
	M.LUMP_SECONDS = 26160   -- ruling 10: one lump or charcoal, 7 h 16 min
	M.FUEL_MAX = 99          -- ruling 10: one fuel slot of 99 items
	M.DAY_SECONDS = 86400    -- ruling 9: once per 24 hours
	M.ISSUE_LEVEL = 20       -- ruling 7
	M.ZONE_LEVEL_MIN = 11    -- ruling 3
	M.ZONE_LEVEL_MAX = 30
	-- Interior lattice spacing of the zone check (see validate below). At 1
	-- every column of the square is checked (about 10 ms per placement in the
	-- engine-free fixture), so no forbidden column can be missed.
	M.SAMPLE_STEP = 1
	-- Ruling 27: a claim keeps this distance (in x and in z) from every
	-- POI, village and camp core and every town, capital or landmark
	-- footprint; the blend envelopes around them are no barrier.
	M.SETTLEMENT_MARGIN = 16
	M.CELL = 128             -- claim grid cell (nodes)
	local RADIUS, CELL = M.RADIUS, M.CELL

	local STATES = {never = true, carried = true, placed = true,
		destroyed = true, needs_stone = true}
	local LEVELS = {everything = true, interact = true}

	local claims = {}        -- id -> claim
	local grid = {}          -- grid[cell_z][cell_x] -> array of claims
	local players = {}       -- name -> record
	local next_id = 1
	local claim_count = 0

	-- Serialization -----------------------------------------------------------

	local function split(text, separator)
		local result, start = {}, 1
		while true do
			local at = text:find(separator, start, true)
			if not at then
				result[#result + 1] = text:sub(start)
				return result
			end
			result[#result + 1] = text:sub(start, at - 1)
			start = at + #separator
		end
	end

	local function encode_claim(claim)
		local names = {}
		for name in pairs(claim.permissions) do names[#names + 1] = name end
		table.sort(names)
		local perms = {}
		for index = 1, #names do
			perms[index] = names[index] .. "=" .. claim.permissions[names[index]]
		end
		local c = claim.center
		return table.concat({"v1", claim.owner, c.x, c.y, c.z, claim.placed_at,
			claim.paid_until, claim.expired_for, table.concat(perms, ",")}, "|")
	end

	local function decode_claim(id, text)
		local f = split(text, "|")
		if f[1] ~= "v1" or #f ~= 9 then return nil end
		local claim = {id = id, owner = f[2],
			center = {x = tonumber(f[3]), y = tonumber(f[4]), z = tonumber(f[5])},
			placed_at = tonumber(f[6]), paid_until = tonumber(f[7]),
			expired_for = tonumber(f[8]), permissions = {}}
		if claim.owner == "" or not claim.center.x or not claim.center.y or
				not claim.center.z or not claim.placed_at or
				not claim.paid_until or not claim.expired_for then
			return nil
		end
		if f[9] ~= "" then
			local rows = split(f[9], ",")
			for index = 1, #rows do
				local pair = split(rows[index], "=")
				if #pair == 2 and pair[1] ~= "" and LEVELS[pair[2]] then
					claim.permissions[pair[1]] = pair[2]
				end
			end
		end
		return claim
	end

	local function encode_player(rec)
		return table.concat({"v1", rec.state, rec.claim_id or 0,
			rec.last_place_at, rec.last_pickup_at}, "|")
	end

	local function decode_player(text)
		local f = split(text, "|")
		if f[1] ~= "v1" or #f ~= 5 or not STATES[f[2]] then return nil end
		local claim_id = tonumber(f[3])
		return {state = f[2], claim_id = claim_id ~= 0 and claim_id or nil,
			last_place_at = tonumber(f[4]) or 0,
			last_pickup_at = tonumber(f[5]) or 0}
	end

	local function save_claim(claim)
		storage.set_string("claim:" .. claim.id, encode_claim(claim))
	end

	local function save_player(name)
		storage.set_string("player:" .. name, encode_player(players[name]))
	end

	-- Claim grid --------------------------------------------------------------

	local function cell(value) return floor(value / CELL) end

	local function grid_add(claim)
		local c = claim.center
		for gz = cell(c.z - RADIUS), cell(c.z + RADIUS) do
			local row = grid[gz]
			if not row then row = {}; grid[gz] = row end
			for gx = cell(c.x - RADIUS), cell(c.x + RADIUS) do
				local list = row[gx]
				if not list then list = {}; row[gx] = list end
				list[#list + 1] = claim
			end
		end
	end

	local function grid_remove(claim)
		local c = claim.center
		for gz = cell(c.z - RADIUS), cell(c.z + RADIUS) do
			local row = grid[gz]
			for gx = cell(c.x - RADIUS), cell(c.x + RADIUS) do
				local list = row and row[gx]
				if list then
					for index = #list, 1, -1 do
						if list[index] == claim then table.remove(list, index) end
					end
					if #list == 0 then row[gx] = nil end
				end
			end
			if row and next(row) == nil then grid[gz] = nil end
		end
	end

	-- Loading -----------------------------------------------------------------

	function M.load()
		claims, grid, players, claim_count = {}, {}, {}, 0
		next_id = tonumber(storage.get_string("next_id")) or 1
		local keys = storage.keys()
		table.sort(keys)
		for index = 1, #keys do
			local key = keys[index]
			local id = tonumber(key:match("^claim:(%d+)$"))
			local name = key:match("^player:(.+)$")
			if id then
				local claim = decode_claim(id, storage.get_string(key))
				if claim then
					claims[id] = claim
					claim_count = claim_count + 1
					grid_add(claim)
					if id >= next_id then next_id = id + 1 end
				end
			elseif name then
				players[name] = decode_player(storage.get_string(key))
			end
		end
	end

	-- Queries -----------------------------------------------------------------

	local function round(value) return floor(value + 0.5) end

	function M.claim_at(pos)
		local y = round(pos.y)
		if y < M.MIN_Y then return nil end
		local x, z = round(pos.x), round(pos.z)
		local row = grid[floor(z / CELL)]
		if not row then return nil end
		local list = row[floor(x / CELL)]
		if not list then return nil end
		for index = 1, #list do
			local c = list[index].center
			if x >= c.x - RADIUS and x <= c.x + RADIUS and
					z >= c.z - RADIUS and z <= c.z + RADIUS then
				return list[index]
			end
		end
		return nil
	end

	function M.claim_by_id(id) return claims[id] end

	function M.claim_count() return claim_count end

	-- Every claim, ordered by id.
	function M.all_claims()
		local list = {}
		for _, claim in pairs(claims) do list[#list + 1] = claim end
		table.sort(list, function(a, b) return a.id < b.id end)
		return list
	end

	function M.is_active(claim)
		return claim ~= nil and claim.paid_until > now()
	end

	function M.remaining_seconds(claim)
		if not claim then return 0 end
		return max(0, claim.paid_until - now())
	end

	-- Lumps the fuel slot still takes: 99 minus the stack the remaining time
	-- stands for (a started lump counts as one).
	function M.fuel_room(claim)
		return max(0, M.FUEL_MAX - ceil(M.remaining_seconds(claim) / M.LUMP_SECONDS))
	end

	-- Whole unburnt lumps, returned on pick-up.
	function M.refund_lumps(claim)
		return floor(M.remaining_seconds(claim) / M.LUMP_SECONDS)
	end

	function M.permission(claim, name)
		if not claim or type(name) ~= "string" then return nil end
		if name == claim.owner then return "owner" end
		return claim.permissions[name]
	end

	-- The 3 x 3 x 3 air cube directly above the stone (ruling 6).
	function M.in_arrival_cube(claim, pos)
		local c = claim.center
		local x, y, z = round(pos.x), round(pos.y), round(pos.z)
		return x >= c.x - 1 and x <= c.x + 1 and z >= c.z - 1 and z <= c.z + 1 and
			y >= c.y + 1 and y <= c.y + 3
	end

	function M.arrival_cube_claim(pos)
		local claim = M.claim_at(pos)
		if claim and M.in_arrival_cube(claim, pos) then return claim end
		return nil
	end

	-- Whether a claim protects pos against name. `open_at(pos)` tells whether
	-- the node there is a placement target (air or buildable_to); it is asked
	-- only inside an arrival cube. World protection and the protection_bypass
	-- privilege are the engine wrapper's business (protection.lua).
	function M.protects(pos, name, open_at)
		local claim = M.claim_at(pos)
		if not claim then return false end
		if M.in_arrival_cube(claim, pos) and open_at(pos) then return true, claim end
		if claim.paid_until <= now() then return false end
		local level = M.permission(claim, name)
		if level == "owner" or level == "everything" then return false end
		return true, claim
	end

	-- Player records ----------------------------------------------------------

	local function record(name)
		local rec = players[name]
		if not rec then
			rec = {state = "never", last_place_at = 0, last_pickup_at = 0}
			players[name] = rec
		end
		return rec
	end

	function M.player_state(name)
		local rec = players[name]
		return rec and rec.state or "never"
	end

	function M.player_claim(name)
		local rec = players[name]
		if not rec then return nil, "never" end
		return rec.claim_id and claims[rec.claim_id] or nil, rec.state
	end

	-- Seconds until the player may place (or pick up) again; 0 when allowed.
	function M.place_wait(name)
		local rec = players[name]
		if not rec then return 0 end
		return max(0, rec.last_place_at + M.DAY_SECONDS - now())
	end

	function M.pickup_wait(name)
		local rec = players[name]
		if not rec then return 0 end
		return max(0, rec.last_pickup_at + M.DAY_SECONDS - now())
	end

	local function wait_text(seconds)
		local hours = floor(seconds / 3600)
		local minutes = ceil((seconds - hours * 3600) / 60)
		if minutes == 60 then hours, minutes = hours + 1, 0 end
		return ("%d h %02d min"):format(hours, minutes)
	end
	M.wait_text = wait_text

	-- Transitions -------------------------------------------------------------

	-- Ruling 7. `level` is the player's level, `holds_stone` whether the stone
	-- item is in the player's inventory. On success the state is "carried";
	-- the caller hands out the item.
	function M.can_issue(name, level, holds_stone)
		if (tonumber(level) or 0) < M.ISSUE_LEVEL then
			return false, "You need level " .. M.ISSUE_LEVEL ..
				" to receive a Claim Stone."
		end
		local rec = players[name]
		if rec and rec.state == "placed" and rec.claim_id and claims[rec.claim_id] then
			return false, "Your Claim Stone is already placed."
		end
		if holds_stone then
			return false, "You already carry a Claim Stone."
		end
		return true
	end

	function M.issue(name, level, holds_stone)
		local ok, message = M.can_issue(name, level, holds_stone)
		if not ok then return false, message end
		local rec = record(name)
		rec.state = "carried"
		rec.claim_id = nil
		save_player(name)
		return true, "You received a Claim Stone."
	end

	-- Ruling 8: a carried stone that was dropped (or otherwise lost).
	function M.stone_lost(name)
		local rec = players[name]
		if not rec or rec.state ~= "carried" then return false end
		rec.state = "needs_stone"
		save_player(name)
		return true
	end

	-- Placement validation (rulings 2, 3, 5, 6, 9, 22, 23, 27). `world`:
	--   water_class_at(x, z) "land" or "planned_water" (rivers, lakes, bay
	--                        water: allowed, ruling 23); "coastal_shelf",
	--                        "deep_ocean" and "immutable_dragon_channel"
	--                        refuse (the shelf has an owning zone, so the zone
	--                        check alone would not catch it)
	--   zone_at(x, z)        the zone record owning the column, or nil
	--                        (fields faction, territory_rule, level_min,
	--                        level_max, civic_no_hostiles)
	--   territory_at(x, z)   the territory rule of the column at the world top
	--                        ("hard_protected" wherever a town or landmark
	--                        column is, whatever its floor)
	--   feature_in(min_x, min_z, max_x, max_z, margin)  the kind ("site",
	--                        "town", "landmark") of a settlement core (POI,
	--                        village, camp) or a hard footprint (start town,
	--                        capital city, landmark) that comes within
	--                        `margin` nodes (in x and in z) of the inclusive
	--                        rectangle, or nil; exact or conservative
	--   cube_clear(pos)      true when the 3 x 3 x 3 cube above pos is air
	--
	-- Zone check: every column of the square's border (400 columns) first,
	-- then an interior lattice of spacing SAMPLE_STEP (1: every column, so the
	-- check is exact). For a larger step the bound is: a forbidden region that
	-- holds a column of the square and a column outside it contains a border
	-- column (a step between columns changes x and z by at most one each, so
	-- no path leaves the square without passing its outermost ring), so it is
	-- always found. Only a forbidden enclave lying wholly inside the square
	-- can be missed, and only if it holds no lattice column: every
	-- SAMPLE_STEP x SAMPLE_STEP block of columns inside the square holds one,
	-- so an enclave is missed only if it is narrower than SAMPLE_STEP in x or
	-- in z. Settlements are no sampling matter (ruling 27): feature_in tests
	-- the square widened by SETTLEMENT_MARGIN against the settlement cores
	-- and the hard footprints themselves.
	local function zone_problem(faction, home, water, zone, territory)
		if water == "coastal_shelf" then return "shelf" end
		if water ~= "land" and water ~= "planned_water" then return "sea" end
		if not zone then return "sea" end
		if zone.faction and zone.faction ~= faction then return "enemy" end
		if zone.level_min < M.ZONE_LEVEL_MIN then return "low_level" end
		if zone.level_max > M.ZONE_LEVEL_MAX then return "high_level" end
		-- Ruling 22: the capital zones (L20-30, civic) are not eligible; the
		-- seven L11-30 zones per faction are.
		if zone.civic_no_hostiles then return "capital_zone" end
		if zone.territory_rule ~= home then return "not_home" end
		if territory == "hard_protected" then return "town" end
		if territory == "immutable" then return "sea" end
		if territory ~= home then return "not_home" end
		return nil
	end

	local MESSAGES = {
		too_deep = "A Claim Stone cannot stand below y = " .. M.MIN_Y .. ".",
		no_faction = "Choose a faction first.",
		already_placed = "Your Claim Stone is already placed.",
		overlap = "Too close to another home: claims may not overlap.",
		town = "Too close to a town: the claim (101 x 101) must stay " ..
			M.SETTLEMENT_MARGIN .. " nodes away from it.",
		landmark = "Too close to a protected landmark: the claim must stay " ..
			M.SETTLEMENT_MARGIN .. " nodes away from it.",
		site = "Too close to a village, camp or point of interest: the claim " ..
			"must stay " .. M.SETTLEMENT_MARGIN .. " nodes away from its buildings.",
		sea = "The claim (101 x 101) may not reach over the open sea.",
		shelf = "The claim (101 x 101) may not reach over the coastal shelf.",
		enemy = "The claim (101 x 101) may not reach into enemy territory.",
		low_level = "The claim (101 x 101) may not reach into a level 1-10 zone.",
		high_level = "The claim (101 x 101) may not reach into a level 31+ zone.",
		capital_zone = "The claim (101 x 101) may not reach into a capital's zone.",
		not_home = "The whole claim (101 x 101) must lie in your faction's home land.",
		cube = "The 3 x 3 x 3 space above the stone must be empty.",
	}
	M.MESSAGES = MESSAGES

	-- The sample columns (offsets from the centre) in a fixed order.
	local sample_offsets
	do
		sample_offsets = {x = {}, z = {}}
		local function add(dx, dz)
			local n = #sample_offsets.x + 1
			sample_offsets.x[n], sample_offsets.z[n] = dx, dz
		end
		for d = -RADIUS, RADIUS do
			add(d, -RADIUS)
			add(d, RADIUS)
		end
		for d = -RADIUS + 1, RADIUS - 1 do
			add(-RADIUS, d)
			add(RADIUS, d)
		end
		local inner = {}
		for d = -RADIUS + M.SAMPLE_STEP, RADIUS - 1, M.SAMPLE_STEP do
			inner[#inner + 1] = d
		end
		for i = 1, #inner do
			for j = 1, #inner do add(inner[j], inner[i]) end
		end
	end
	M.SAMPLE_COUNT = #sample_offsets.x

	-- Returns true, or false, code, message.
	function M.validate(name, faction, pos, world)
		local function refuse(code, message)
			return false, code, message or MESSAGES[code]
		end
		local x, y, z = round(pos.x), round(pos.y), round(pos.z)
		if y < M.MIN_Y then return refuse("too_deep") end
		if faction ~= "accord" and faction ~= "throng" then
			return refuse("no_faction")
		end
		local rec = players[name]
		if rec and rec.state == "placed" and rec.claim_id and claims[rec.claim_id] then
			return refuse("already_placed")
		end
		local wait = M.place_wait(name)
		if wait > 0 then
			return refuse("daily_place", "You can place a Claim Stone again in " ..
				wait_text(wait) .. ".")
		end
		for _, other in pairs(claims) do
			local c = other.center
			if math.abs(c.x - x) <= 2 * RADIUS and math.abs(c.z - z) <= 2 * RADIUS then
				return refuse("overlap")
			end
		end
		local kind = world.feature_in(x - RADIUS, z - RADIUS, x + RADIUS,
			z + RADIUS, M.SETTLEMENT_MARGIN)
		if kind then return refuse(MESSAGES[kind] and kind or "site") end
		local home = faction .. "_home"
		local offsets_x, offsets_z = sample_offsets.x, sample_offsets.z
		for index = 1, #offsets_x do
			local sx, sz = x + offsets_x[index], z + offsets_z[index]
			local water = world.water_class_at(sx, sz)
			local zone = world.zone_at(sx, sz)
			local territory = zone and world.territory_at(sx, sz) or nil
			local problem = zone_problem(faction, home, water, zone, territory)
			if problem then return refuse(problem) end
		end
		-- Last: the one refusal the player can fix on the spot.
		if not world.cube_clear({x = x, y = y, z = z}) then return refuse("cube") end
		return true
	end

	-- Ruling 3-6 accepted: the new claim, empty (fuel is added through the
	-- stone). The placed-at time starts the owner's 24 h placing limit.
	function M.create(name, pos)
		local t = now()
		local claim = {id = next_id, owner = name,
			center = {x = round(pos.x), y = round(pos.y), z = round(pos.z)},
			placed_at = t, paid_until = t, expired_for = t, permissions = {}}
		next_id = next_id + 1
		storage.set_string("next_id", tostring(next_id))
		claims[claim.id] = claim
		claim_count = claim_count + 1
		grid_add(claim)
		save_claim(claim)
		local rec = record(name)
		rec.state, rec.claim_id, rec.last_place_at = "placed", claim.id, t
		save_player(name)
		return claim
	end

	-- `reason` "picked_up": the owner carries the stone again and starts the
	-- 24 h pick-up limit; "destroyed": the owner's state becomes "destroyed".
	function M.remove(claim, reason)
		if not claims[claim.id] then return false end
		claims[claim.id] = nil
		claim_count = claim_count - 1
		grid_remove(claim)
		storage.set_string("claim:" .. claim.id, "")
		local rec = record(claim.owner)
		if rec.claim_id == claim.id then rec.claim_id = nil end
		if reason == "picked_up" then
			rec.state, rec.last_pickup_at = "carried", now()
		else
			rec.state = "destroyed"
		end
		save_player(claim.owner)
		return true
	end

	-- Ruling 10: burns up to count lumps into paid_until; returns the number
	-- accepted (never more than the slot still takes).
	function M.add_fuel(claim, count)
		count = floor(tonumber(count) or 0)
		if not claim or not claims[claim.id] or count <= 0 then return 0 end
		local accepted = min(count, M.fuel_room(claim))
		if accepted <= 0 then return 0 end
		claim.paid_until = max(now(), claim.paid_until) + accepted * M.LUMP_SECONDS
		save_claim(claim)
		return accepted
	end

	function M.set_permission(claim, name, level)
		if not claim or not claims[claim.id] then return false, "No such claim." end
		if type(name) ~= "string" or not name:match("^[%w_%-]+$") then
			return false, "Invalid player name."
		end
		if name == claim.owner then return false, "The owner always has access." end
		if level ~= nil and not LEVELS[level] then
			return false, "Unknown permission level."
		end
		claim.permissions[name] = level
		save_claim(claim)
		if level then return true, name .. ": " .. level .. "." end
		return true, name .. " removed."
	end

	-- Claims whose fuel ran out since the last scan (each paid_until reported
	-- once), ordered by id. A claim placed empty is not reported.
	function M.expiry_scan()
		local t, result = now(), {}
		for _, claim in pairs(claims) do
			if claim.paid_until <= t and claim.expired_for ~= claim.paid_until then
				claim.expired_for = claim.paid_until
				save_claim(claim)
				result[#result + 1] = claim
			end
		end
		table.sort(result, function(a, b) return a.id < b.id end)
		return result
	end

	return M
end
