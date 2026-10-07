-- The Claim Stone model (Round 25 Lane A, docs/planning/round25-housing-plan.md
-- rulings 1-12 and 30-32; Round 26 rulings 8-10): claims and per-player
-- records, their persistence, the claim grid, drafts and activation, fuel as a
-- "paid until" time, permissions, the pick-up lock and placement validation.
-- Pure: every engine or world access is injected, so the same bytes run in
-- the engine (api.lua) and in tools/r25_claim_core/fixture.lua.
--
-- A placed stone starts as a DRAFT (activated_at 0): it reserves its square
-- against other claims and keeps its arrival cube, but protects nothing and
-- is not active; it disappears DRAFT_SECONDS after placing unless the owner
-- activates it. Activation pays ACTIVATION_LUMPS lumps at once and starts the
-- fuel and the protection. For PICKUP_LOCK_SECONDS after activation the owner
-- cannot pick the stone up; that is the only lock (no placing lock).
--
--   api.storage   get_string(key), set_string(key, value), keys() -> array
--                 (mod storage; "" deletes a key)
--   api.now()     wall-clock seconds (os.time()); server downtime counts
--
-- Storage keys, one line each (player names are [A-Za-z0-9_-], so "|", ","
-- and "=" never occur inside a field):
--   next_id             the next claim id
--   claim:<id>          v2|owner|x|y|z|placed_at|activated_at|paid_until|
--                       expired_for|perms  (activated_at 0: a draft)
--                       perms = name=level,name=level
--   player:<name>       v2|state|claim_id
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
	M.DRAFT_SECONDS = 300    -- R26 ruling 8: an unactivated stone lasts 5 min
	M.ACTIVATION_LUMPS = 5   -- R26 ruling 9: activation pays 5 lumps at once
	M.PICKUP_LOCK_SECONDS = 43200 -- R26 ruling 10: 12 h after activation
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
		destroyed = true, removed = true, needs_stone = true}
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
		return table.concat({"v2", claim.owner, c.x, c.y, c.z, claim.placed_at,
			claim.activated_at, claim.paid_until, claim.expired_for,
			table.concat(perms, ",")}, "|")
	end

	local function decode_claim(id, text)
		local f = split(text, "|")
		if f[1] ~= "v2" or #f ~= 10 then return nil end
		local claim = {id = id, owner = f[2],
			center = {x = tonumber(f[3]), y = tonumber(f[4]), z = tonumber(f[5])},
			placed_at = tonumber(f[6]), activated_at = tonumber(f[7]),
			paid_until = tonumber(f[8]), expired_for = tonumber(f[9]),
			permissions = {}}
		if claim.owner == "" or not claim.center.x or not claim.center.y or
				not claim.center.z or not claim.placed_at or
				not claim.activated_at or not claim.paid_until or
				not claim.expired_for then
			return nil
		end
		if f[10] ~= "" then
			local rows = split(f[10], ",")
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
		return table.concat({"v2", rec.state, rec.claim_id or 0}, "|")
	end

	local function decode_player(text)
		local f = split(text, "|")
		if f[1] ~= "v2" or #f ~= 3 or not STATES[f[2]] then return nil end
		local claim_id = tonumber(f[3])
		return {state = f[2], claim_id = claim_id ~= 0 and claim_id or nil}
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

	-- The platform's map reset (grug_core/map_reset.lua, the upgrade
	-- contract; Round 41 ruling 9): the claims are map-bound and go, also a
	-- record that does not decode. A player whose stone stood needs a new one
	-- from the Housing Steward, as after losing it; a carried stone and every
	-- other record stay, and so does the id counter (monotonic). Runs on the
	-- loaded registry; idempotent.
	function M.map_reset()
		local keys = storage.keys()
		for index = 1, #keys do
			if keys[index]:match("^claim:") then storage.set_string(keys[index], "") end
		end
		claims, grid, claim_count = {}, {}, 0
		storage.set_string("next_id", tostring(next_id))
		for name, rec in pairs(players) do
			if rec.state == "placed" then
				rec.state, rec.claim_id = "needs_stone", nil
				save_player(name)
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

	-- A placed stone that was never activated (R26 ruling 8).
	function M.is_draft(claim)
		return claim ~= nil and claim.activated_at == 0
	end

	-- Seconds until a draft disappears; 0 for an activated claim.
	function M.draft_remaining(claim)
		if not M.is_draft(claim) then return 0 end
		return max(0, claim.placed_at + M.DRAFT_SECONDS - now())
	end

	-- Active: activated and fuelled. A draft is never active.
	function M.is_active(claim)
		return claim ~= nil and claim.activated_at ~= 0 and claim.paid_until > now()
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
	-- only inside an arrival cube, where it refuses every placement, for a
	-- draft and an empty stone too. `digging(pos, name)` (optional) tells
	-- whether name is punching or digging a node there that is not air: a
	-- buildable_to node in the cube (snow) is then judged like any other node
	-- of the claim, so the owner can dig it (R26 ruling 12). World protection
	-- and the protection_bypass privilege are the engine wrapper's business
	-- (protection.lua). A draft or an empty claim protects nothing else.
	function M.protects(pos, name, open_at, digging)
		local claim = M.claim_at(pos)
		if not claim then return false end
		if M.in_arrival_cube(claim, pos) and open_at(pos) and
				not (digging and digging(pos, name)) then
			return true, claim
		end
		if not M.is_active(claim) then return false end
		local level = M.permission(claim, name)
		if level == "owner" or level == "everything" then return false end
		return true, claim
	end

	-- Player records ----------------------------------------------------------

	local function record(name)
		local rec = players[name]
		if not rec then
			rec = {state = "never"}
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

	-- Seconds until the owner may pick the stone up (R26 ruling 10: 12 h
	-- after activation; a draft never waits). There is no placing lock.
	function M.pickup_wait(claim)
		if not claim or M.is_draft(claim) then return 0 end
		return max(0, claim.activated_at + M.PICKUP_LOCK_SECONDS - now())
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

	-- Placement validation (rulings 2, 3, 5, 6, 22, 23, 27). `world`:
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
	--   fixed                true when the four column queries above never
	--                        change their answer (the engine's world: the
	--                        zone layout is fixed per world); the zone scan's
	--                        result is then kept per faction and column
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

	-- The zone scan of the square around column x/z: the first problem code
	-- in the fixed column order, or nil.
	local function scan(faction, x, z, world)
		local home = faction .. "_home"
		local offsets_x, offsets_z = sample_offsets.x, sample_offsets.z
		for index = 1, #offsets_x do
			local sx, sz = x + offsets_x[index], z + offsets_z[index]
			local water = world.water_class_at(sx, sz)
			local zone = world.zone_at(sx, sz)
			local territory = zone and world.territory_at(sx, sz) or nil
			local problem = zone_problem(faction, home, water, zone, territory)
			if problem then return problem end
		end
		return nil
	end

	-- The scan's answer per faction and column for a `fixed` world (Round
	-- 37, audit PLY-04): a held right-click repeats on_place about four
	-- times a second, and a spot is scanned once. The scan reads no y, so a
	-- stone placed higher or lower on the same column shares the answer.
	-- At most SCAN_CACHE entries, then it starts empty again.
	M.SCAN_CACHE = 64
	local scans, scan_count = {}, 0
	local function scan_problem(faction, x, z, world)
		if not world.fixed then return scan(faction, x, z, world) end
		local key = faction .. "|" .. x .. "|" .. z
		local known = scans[key]
		if known ~= nil then return known or nil end
		local problem = scan(faction, x, z, world)
		if scan_count >= M.SCAN_CACHE then scans, scan_count = {}, 0 end
		scans[key], scan_count = problem or false, scan_count + 1
		return problem
	end

	-- Returns true, or false, code, message. The refusals keep this order:
	-- the cheap ones first (depth, faction, one claim, overlap with another
	-- claim, settlements), then the zone scan, and last the arrival cube,
	-- the one refusal the player can fix on the spot. A spot that fails
	-- the scan and the cube shows the scan's message, so the cube cannot
	-- spare the scan; the per-column result above spares its repeats.
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
		-- Drafts reserve their square too (R26 ruling 8).
		for _, other in pairs(claims) do
			local c = other.center
			if math.abs(c.x - x) <= 2 * RADIUS and math.abs(c.z - z) <= 2 * RADIUS then
				return refuse("overlap")
			end
		end
		local kind = world.feature_in(x - RADIUS, z - RADIUS, x + RADIUS,
			z + RADIUS, M.SETTLEMENT_MARGIN)
		if kind then return refuse(MESSAGES[kind] and kind or "site") end
		local problem = scan_problem(faction, x, z, world)
		if problem then return refuse(problem) end
		if not world.cube_clear({x = x, y = y, z = z}) then return refuse("cube") end
		return true
	end

	-- Rulings 3-6 accepted: the new claim, a draft (R26 ruling 8) until the
	-- owner activates it.
	function M.create(name, pos)
		local t = now()
		local claim = {id = next_id, owner = name,
			center = {x = round(pos.x), y = round(pos.y), z = round(pos.z)},
			placed_at = t, activated_at = 0, paid_until = t, expired_for = t,
			permissions = {}}
		next_id = next_id + 1
		storage.set_string("next_id", tostring(next_id))
		claims[claim.id] = claim
		claim_count = claim_count + 1
		grid_add(claim)
		save_claim(claim)
		local rec = record(name)
		rec.state, rec.claim_id = "placed", claim.id
		save_player(name)
		return claim
	end

	-- `reason` "picked_up": the owner carries the stone again; "draft_expired":
	-- the draft crumbled, the owner needs a new stone ("needs_stone", issued
	-- at once); "removed": an admin removed it (state "removed", a new stone
	-- at once); anything else ("destroyed"): the owner's state becomes
	-- "destroyed".
	function M.remove(claim, reason)
		if not claims[claim.id] then return false end
		claims[claim.id] = nil
		claim_count = claim_count - 1
		grid_remove(claim)
		storage.set_string("claim:" .. claim.id, "")
		local rec = record(claim.owner)
		if rec.claim_id == claim.id then rec.claim_id = nil end
		if reason == "picked_up" then
			rec.state = "carried"
		elseif reason == "draft_expired" then
			rec.state = "needs_stone"
		elseif reason == "removed" then
			rec.state = "removed"
		else
			rec.state = "destroyed"
		end
		save_player(claim.owner)
		return true
	end

	-- R26 ruling 9: activation of a draft with `count` lumps, at least
	-- ACTIVATION_LUMPS, at most FUEL_MAX. Starts the fuel, the protection and
	-- the pick-up lock. Returns the lumps burnt, or 0 and a reason code
	-- ("no_claim", "active", "too_few").
	function M.activate(claim, count)
		count = floor(tonumber(count) or 0)
		if not claim or not claims[claim.id] then return 0, "no_claim" end
		if not M.is_draft(claim) then return 0, "active" end
		if count < M.ACTIVATION_LUMPS then return 0, "too_few" end
		local accepted = min(count, M.FUEL_MAX)
		local t = now()
		claim.activated_at = t
		claim.paid_until = t + accepted * M.LUMP_SECONDS
		save_claim(claim)
		return accepted
	end

	-- Drafts whose DRAFT_SECONDS ran out, ordered by id; the caller removes
	-- them (reason "draft_expired"). Wall-clock time, so server downtime
	-- counts as it does for fuel.
	function M.draft_scan()
		local t, result = now(), {}
		for _, claim in pairs(claims) do
			if claim.activated_at == 0 and claim.placed_at + M.DRAFT_SECONDS <= t then
				result[#result + 1] = claim
			end
		end
		table.sort(result, function(a, b) return a.id < b.id end)
		return result
	end

	-- Ruling 10: burns up to count lumps into paid_until; returns the number
	-- accepted (never more than the slot still takes). A draft takes no fuel:
	-- it is activated first (R26 ruling 9).
	function M.add_fuel(claim, count)
		count = floor(tonumber(count) or 0)
		if not claim or not claims[claim.id] or count <= 0 or M.is_draft(claim) then
			return 0
		end
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
	-- once), ordered by id. A draft is never reported.
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
