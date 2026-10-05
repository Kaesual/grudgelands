-- Zone and town names for players (Round 28 Lane M1; docs/design/world_map.md
-- "Zone and town names"): which name a position shows, when the entry banner
-- shows it (with the territory line and colour, Round 32), and where each
-- zone's marker sits on the Map tab. PURE Lua: it calls nothing from `core`, so the
-- portable fixture loads the real file.
-- location.lua is the runtime around it.

local L = {}

-- Each player's location is sampled every SAMPLE seconds; a banner shows its
-- name for DISPLAY seconds.
L.SAMPLE = 1.0
L.DISPLAY = 1.5
-- Shown where no zone owns the column (the open sea), as on the Map tab.
L.OPEN_SEA = "Open sea"

-- ---------------------------------------------------------------------------
-- Which name a position shows
-- ---------------------------------------------------------------------------

-- `opts`:
--   zone_at(x, z)      -> zone id or nil (grug_zones.id_at)
--   names              zone id -> display name
--   towns              {{name, x, z, footprint, capital}, ...}: the start
--                      towns and capital cities, `footprint` the id of the
--                      hard footprint that holds them, `capital` the
--                      settlement key of a capital city (nil for a start
--                      town)
--   reach              half the largest town footprint's square: a town is
--                      only asked about inside this box round its anchor
--   footprint_at(x, z) -> id of the hard footprint holding the column, or
--                      nil (grug_zones.hard_footprint_in on the one column)
-- Returns two functions:
--   resolve(x, z) -> the text: the town's name inside a start town or a
--     capital city, else the zone's display name, else OPEN_SEA; inside a
--     town also true (grug_ambience's quieter town bed, Round 34) and the
--     town's row (its `capital` key: Round 35's capital music);
--   town_at(x, z) -> the town row whose footprint holds the column, or nil.
function L.resolver(opts)
	local zone_at, names, towns = opts.zone_at, opts.names, opts.towns
	local reach, footprint_at = opts.reach, opts.footprint_at
	local by_footprint = {}
	for _, town in ipairs(towns) do by_footprint[town.footprint] = town end
	local function town_at(x, z)
		for index = 1, #towns do
			local town = towns[index]
			if math.abs(x - town.x) <= reach and math.abs(z - town.z) <= reach then
				-- Inside one town's box: one exact query decides. Towns are far
				-- apart, so no other box can hold the point too.
				return by_footprint[footprint_at(x, z) or false]
			end
		end
		return nil
	end
	local function resolve(x, z)
		local town = town_at(x, z)
		if town then return town.name, true, town end
		local id = zone_at(x, z)
		if not id then return L.OPEN_SEA end
		return names[id] or id
	end
	return resolve, town_at
end

-- ---------------------------------------------------------------------------
-- Which capital a player counts as in (Round 35, capital music)
-- ---------------------------------------------------------------------------

-- Hysteresis at a capital's border, in nodes: a player who counted as in a
-- capital stays in it while its city is within this distance.
L.CAPITAL_MARGIN = 8
local CAPITAL_RING = {}
do
	local m, d = L.CAPITAL_MARGIN, math.floor(L.CAPITAL_MARGIN * 0.7071 + 0.5)
	for _, offset in ipairs({{m, 0}, {-m, 0}, {0, m}, {0, -m}, {d, d}, {d, -d},
			{-d, d}, {-d, -d}}) do
		CAPITAL_RING[#CAPITAL_RING + 1] = offset
	end
end

-- The capital (settlement key) a player at (x, z) counts as in, or nil.
-- `here` is the town row at the column (resolve's third value, or nil),
-- `prev` the capital the player counted as in at the last sample, `town_at`
-- the resolver's second function. Inside a city: that city's capital (a
-- start town: none). Outside every city: `prev` while one of eight columns
-- on a ring of CAPITAL_MARGIN nodes round the player lies in `prev`'s city
-- (up to eight footprint queries, only while leaving), else none. So the
-- music starts on the first step into the city and ends a few nodes out,
-- and walking along the border does not toggle it.
function L.capital_at(town_at, prev, x, z, here)
	if here then return here.capital end
	if not prev then return nil end
	for index = 1, #CAPITAL_RING do
		local offset = CAPITAL_RING[index]
		local town = town_at(x + offset[1], z + offset[2])
		if town and town.capital == prev then return prev end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Entry banner debounce (one state per player)
-- ---------------------------------------------------------------------------

-- The territory at the player's position (Round 32 §2.3; grug_pvp's
-- territory_at, from the position, never from the flag): the banner's second
-- line and the colour of both banner lines and of the line under the
-- minimap. Green, yellow and red as the target frame's (grug_mobs
-- target_frame.lua), the yellow a little deeper so it stays apart from the
-- calm notice colour. No status (the open sea, a player without a faction):
-- no line, the notice colour.
L.TERRITORY = {
	friendly = {line = "Friendly Territory", color = 0x55ff55},
	contested = {line = "Contested Territory (PvP)", color = 0xffdd33},
	enemy = {line = "Enemy Territory (PvP)", color = 0xff5555},
}

-- The second line for a status ("" for none).
function L.line(status)
	local row = status and L.TERRITORY[status]
	return row and row.line or ""
end

-- The colour for a status, `neutral` for none.
function L.color(status, neutral)
	local row = status and L.TERRITORY[status]
	return row and row.color or neutral
end

-- `shown` and `shown_status` are what the last display said, `current` and
-- `status` the last sample, `busy_until` the end of the running display (nil
-- when none runs).
function L.new_state()
	return {shown = nil, shown_status = nil, current = nil, status = nil,
		busy_until = nil}
end

-- A new sample: location `text` and territory `status` at time `now`.
-- Returns the text to display now, or nil. A display starts when the
-- location or the status differs from what was shown last (crossing y -501
-- under friendly or enemy land shows the same name again with the new line;
-- inside a contested zone the status stays and nothing shows). While a
-- display runs nothing new starts.
function L.sample(state, text, now, status)
	state.current, state.status = text, status
	if state.busy_until or text == nil then return nil end
	if text == state.shown and status == state.shown_status then return nil end
	state.shown, state.shown_status, state.busy_until = text, status, now + L.DISPLAY
	return text
end

-- Called while a display runs, with a fresh sample `text` and `status`.
-- Before the display ends: nil. When it ends: the next text to display if
-- the location or the status now differs from what was just shown, else
-- false (hide).
function L.expire(state, text, now, status)
	if not state.busy_until or now < state.busy_until then return nil end
	state.busy_until, state.current, state.status = nil, text, status
	if text ~= nil and (text ~= state.shown or status ~= state.shown_status) then
		state.shown, state.shown_status, state.busy_until = text, status, now + L.DISPLAY
		return text
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Map tab texts
-- ---------------------------------------------------------------------------

-- "Dawnmere Fields (levels 1–10)"; "(level 60)" for a single-level zone.
function L.zone_tooltip(record)
	local name = record.display_name or record.id
	local low, high = record.level_min, record.level_max
	if type(low) ~= "number" or type(high) ~= "number" then return name end
	if low == high then return ("%s (level %d)"):format(name, low) end
	return ("%s (levels %d–%d)"):format(name, low, high)
end

-- The King marker names the settlement: "King of <city>". A description
-- that names the king himself keeps that name: "<name>, King of <city>".
function L.king_label(description, city)
	if type(description) ~= "string" or description == "" or
			description:find("^King of ") then
		return "King of " .. city
	end
	return description .. ", King of " .. city
end

-- ---------------------------------------------------------------------------
-- Zone marker placement
-- ---------------------------------------------------------------------------

-- `grid`: {nx, nz, step, min_x, max_z, cells}; cells[gz * nx + gx + 1] is the
-- zone id owning the land at the centre of cell gx/gz (gz grows southward,
-- i.e. toward -z), false for water. Returns each land cell's chamfer
-- distance (3 per straight, 4 per diagonal step) to the nearest cell that is
-- not its own zone's land, or the grid edge; 0 for water.
function L.depths(grid)
	local nx, nz, cells = grid.nx, grid.nz, grid.cells
	local depth = {}
	local huge = math.huge
	local function relax(gx, gz, dx, dz, weight, own)
		local x, z = gx + dx, gz + dz
		if x < 0 or x >= nx or z < 0 or z >= nz then return weight end
		local other = z * nx + x + 1
		if cells[other] ~= own then return weight end
		return depth[other] + weight
	end
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			local index = gz * nx + gx + 1
			local own = cells[index]
			if own then
				local d = huge
				d = math.min(d, relax(gx, gz, -1, 0, 3, own))
				d = math.min(d, relax(gx, gz, -1, -1, 4, own))
				d = math.min(d, relax(gx, gz, 0, -1, 3, own))
				d = math.min(d, relax(gx, gz, 1, -1, 4, own))
				depth[index] = d
			else
				depth[index] = 0
			end
		end
	end
	for gz = nz - 1, 0, -1 do
		for gx = nx - 1, 0, -1 do
			local index = gz * nx + gx + 1
			local own = cells[index]
			if own then
				local d = depth[index]
				d = math.min(d, relax(gx, gz, 1, 0, 3, own))
				d = math.min(d, relax(gx, gz, 1, 1, 4, own))
				d = math.min(d, relax(gx, gz, 0, 1, 3, own))
				d = math.min(d, relax(gx, gz, -1, 1, 4, own))
				depth[index] = d
			end
		end
	end
	return depth
end

-- How clear world point x/z is of `obstacles` ({x, z, rx, rz, soft}: a
-- marker, or with `soft` a region name, occupies |dx| < rx and |dz| < rz
-- round x/z): the smallest max(|dx| / rx, |dz| / rz) over the markers and
-- over the names, each capped at 1 (1 = clear of all).
local function clearance(x, z, obstacles)
	local hard, soft = 1, 1
	for index = 1, #obstacles do
		local o = obstacles[index]
		local score = math.max(math.abs(x - o.x) / o.rx, math.abs(z - o.z) / o.rz)
		if o.soft then
			if score < soft then soft = score end
		elseif score < hard then
			hard = score
		end
	end
	return hard, soft
end

-- One marker per zone, in `order` (zone ids), at the land cell of that zone
-- farthest from its border and coast (the pole of inaccessibility on the
-- grid), nudged deterministically: the deepest cell that is clear of every
-- obstacle and of the markers placed before it (a square of `gap` nodes
-- round each), or, if no cell is, the one clearest of markers, then of
-- names, then the deepest (an icon on an icon is worse than an icon on a
-- name's text; the island names cover almost their whole island). Ties go
-- to the lower cell index. Zones without land in the grid get no marker.
-- Returns zone id -> {x, z}.
function L.place_labels(grid, order, obstacles, gap)
	local depth = L.depths(grid)
	local nx, step, cells = grid.nx, grid.step, grid.cells
	local by_zone = {}
	for index = 1, #cells do
		local id = cells[index]
		if id then
			local list = by_zone[id]
			if not list then list = {} by_zone[id] = list end
			list[#list + 1] = index
		end
	end
	local function centre(index)
		local gx, gz = (index - 1) % nx, math.floor((index - 1) / nx)
		return grid.min_x + (gx + 0.5) * step, grid.max_z - (gz + 0.5) * step
	end
	local placed, result = {}, {}
	for _, id in ipairs(order) do
		local list = by_zone[id]
		if list then
			table.sort(list, function(a, b)
				if depth[a] ~= depth[b] then return depth[a] > depth[b] end
				return a < b
			end)
			-- Only obstacles that can reach the zone's cells matter.
			local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
			for _, index in ipairs(list) do
				local x, z = centre(index)
				min_x, max_x = math.min(min_x, x), math.max(max_x, x)
				min_z, max_z = math.min(min_z, z), math.max(max_z, z)
			end
			local near = {}
			for _, set in ipairs({obstacles, placed}) do
				for _, o in ipairs(set) do
					if o.x + o.rx > min_x and o.x - o.rx < max_x and
							o.z + o.rz > min_z and o.z - o.rz < max_z then
						near[#near + 1] = o
					end
				end
			end
			local best, best_hard, best_soft = list[1], -1, -1
			for _, index in ipairs(list) do
				local x, z = centre(index)
				local hard, soft = clearance(x, z, near)
				if hard > best_hard or (hard == best_hard and soft > best_soft) then
					best, best_hard, best_soft = index, hard, soft
				end
				if hard >= 1 and soft >= 1 then break end
			end
			local x, z = centre(best)
			result[id] = {x = x, z = z}
			placed[#placed + 1] = {x = x, z = z, rx = gap, rz = gap}
		end
	end
	return result
end

-- The obstacle a region name (a centred bold label on the Map tab) makes at
-- the smallest usual window: `text` wrapped into a box `box_w` formspec
-- units wide, about CHAR units per character and LINE units per line, plus
-- half a marker (`marker`) round it. `nodes` converts units to nodes.
L.CHAR, L.LINE = 0.2, 0.45
function L.text_obstacle(text, x, z, box_w, marker, nodes)
	local per_line = math.max(1, math.floor(box_w / L.CHAR))
	local lines, widest, current = 1, 0, 0
	for word in text:gmatch("%S+") do
		local length = current == 0 and #word or current + 1 + #word
		if current > 0 and length > per_line then
			lines, widest, current = lines + 1, math.max(widest, current), #word
		else
			current = length
		end
	end
	widest = math.max(widest, current)
	return {x = x, z = z, soft = true,
		rx = (math.min(box_w, widest * L.CHAR) / 2 + marker / 2) * nodes,
		rz = (lines * L.LINE / 2 + marker / 2) * nodes}
end

return L
