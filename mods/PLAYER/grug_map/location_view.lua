-- Zone and town names for players (Round 28 Lane M1; docs/design/world_map.md
-- "Zone and town names"): which name a position shows, when the entry banner
-- shows it (with the territory line and colour, Round 32). PURE Lua: it
-- calls nothing from `core`, so the portable fixture loads the real file.
-- location.lua is the runtime around it.

local L = {}

-- Each player's location is sampled every SAMPLE seconds; a banner shows its
-- name for DISPLAY seconds.
L.SAMPLE = 1.0
L.DISPLAY = 1.5
-- Shown where no zone owns the column (the open sea), as in the map window.
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

return L
