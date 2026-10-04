-- Ambience and music rules (Round 34 lane S2; round34-plan.md §2.1 rulings
-- 3-6, §4.2). PURE Lua: it calls nothing from `core`, so the portable fixture
-- (tools/r34_s2/portable_test.lua) loads the real file. init.lua is the
-- runtime around it: the per-player slots, the water and node probes, the
-- sound calls, the music push and the settings.
--
-- `rand(a, b)` arguments behave like math.random(a, b) (integers); the
-- runtime passes math.random, the fixture a seeded stand-in.

local R = {}

-- Every online player is evaluated once per SLOTS * SLOT_PERIOD = 2 s, in
-- one of eight slots, so no step handles every player (AGENTS.md Round 32).
R.SLOTS = 8
R.SLOT_PERIOD = 0.25

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

R.DEFAULT_VOLUME = 100

-- A volume in whole percent 0-100, or nil when `value` is not a number.
function R.clamp_volume(value)
	value = tonumber(value)
	if not value or value ~= value then return nil end
	value = math.floor(value + 0.5)
	if value < 0 then return 0 end
	if value > 100 then return 100 end
	return value
end

-- `/music` and `/ambience`: "" (status), "on", "off" or a volume. Returns
-- {on = bool} or {on = true, volume = n} (a volume above 0 also switches the
-- channel on, 0 switches it off), {} for the status, or nil for a bad word.
function R.parse_command(param)
	param = (param or ""):match("^%s*(.-)%s*%%?%s*$"):lower()
	if param == "" then return {} end
	if param == "on" then return {on = true} end
	if param == "off" then return {on = false} end
	local volume = param:match("^%d+$") and R.clamp_volume(param)
	if not volume then return nil end
	return {on = volume > 0, volume = volume}
end

-- The channel plays only when it is on and its volume is above zero.
function R.audible(on, volume)
	return on and volume > 0
end

-- ---------------------------------------------------------------------------
-- Beds
-- ---------------------------------------------------------------------------

-- The bed keys to try for a state, best first (an empty list: silence), or
-- nil when the state names no mood at all (a manual non-mood /atmosphere
-- preset such as `godrays`, or `default` before the zone driver ran): the
-- caller then keeps the bed it has. A mood without a data.region row has no
-- bed. `s`: mood (an atmosphere mood or nil), night, water ("sea", "stream"
-- or nil), underwater, deep (the deep underground band).
--   underwater beats everything; the underground mood has no day or night
--   (deep first, then the plain cave beds); sea and stream water near the
--   player override the region bed; the region bed has a night variant where
--   data.region names one, else the day bed plays at night too.
function R.bed_keys(data, s)
	if s.underwater then return {"underwater"} end
	if s.mood == "underground" then
		if s.deep then return {"underground_deep", "underground"} end
		return {"underground"}
	end
	local row = s.mood and data.region[s.mood]
	local keys = {}
	if s.water == "sea" then keys[#keys + 1] = "sea" end
	if s.water == "stream" then keys[#keys + 1] = "stream" end
	if row then
		if s.night and row.night then keys[#keys + 1] = row.night end
		keys[#keys + 1] = row.day
	elseif not s.mood and #keys == 0 then
		return nil
	end
	return keys
end

-- The first key whose bed has at least one shipped sound, or false when
-- none has (silence), or nil when `keys` is nil (keep the current bed).
function R.pick_bed(data, keys, available)
	if not keys then return nil end
	for index = 1, #keys do
		local names = data.beds[keys[index]]
		if names then
			for n = 1, #names do
				if available[names[n]] then return keys[index] end
			end
		end
	end
	return false
end

-- A random shipped sound of bed `key`.
function R.bed_sound(data, key, available, rand)
	local names, count = data.beds[key], 0
	for n = 1, #names do
		if available[names[n]] then count = count + 1 end
	end
	local pick = rand(1, count)
	for n = 1, #names do
		if available[names[n]] then
			pick = pick - 1
			if pick == 0 then return names[n] end
		end
	end
end

-- Hysteresis: a new bed must be wanted on two passes in a row before it
-- replaces the playing one, so walking along a river bank or a town edge
-- does not swap beds every pass; diving in or coming up changes at once.
-- `b` is the player's bed state {key, want, seen, underwater}; `wanted` a
-- key or false (silence); `underwater` this pass's flag. Returns true when
-- the bed should change to `wanted` now.
function R.bed_should_change(b, wanted, underwater)
	underwater = underwater == true
	local flipped = underwater ~= (b.underwater == true)
	b.underwater = underwater
	if wanted == b.key then
		b.want, b.seen = nil, 0
		return false
	end
	if b.key == nil or flipped then
		b.want, b.seen = nil, 0
		return true
	end
	if b.want == wanted then
		b.seen = b.seen + 1
	else
		b.want, b.seen = wanted, 1
	end
	if b.seen >= 2 then
		b.want, b.seen = nil, 0
		return true
	end
	return false
end

-- The bed's gain: the base gain, the player's volume, quieter in towns
-- (the Town music pool carries their mood; user, round34-plan.md §2.2).
function R.bed_gain(data, volume, town)
	return data.gains.bed * volume / 100 * (town and data.gains.town_bed or 1)
end

-- ---------------------------------------------------------------------------
-- Calls
-- ---------------------------------------------------------------------------

-- Seconds until the next call: mostly minutes apart, never below the floor.
function R.next_call_delay(data, rand)
	return rand(data.call_gap[1], data.call_gap[2])
end

-- The call ids that fit state `s` and have a shipped sound, sorted, so a
-- seeded random pick is reproducible.
function R.eligible_calls(data, s, available)
	local list = {}
	if s.underwater or s.mood == "underground" or not s.mood then return list end
	for id, call in pairs(data.calls) do
		local time_ok = call.time == "any" or (call.time == "night") == (s.night == true)
		if time_ok and call.moods[s.mood] and available[call.sound] then
			list[#list + 1] = id
		end
	end
	table.sort(list)
	return list
end

-- ---------------------------------------------------------------------------
-- Music
-- ---------------------------------------------------------------------------

-- The pool a state draws from: Town inside start towns and capitals, else
-- by the atmosphere mood (§2.1 ruling 3); nil for a mood the table does not
-- know (the caller keeps the last group).
function R.music_group(data, mood, town)
	if town then return "town" end
	return mood and data.music_groups[mood] or nil
end

local function contains(list, value)
	for index = 1, #list do
		if list[index] == value then return true end
	end
	return false
end

-- A random track of `pool`, not `last` when the pool has another one.
local function pick_track(pool, last, rand)
	if #pool == 1 then return pool[1] end
	local candidates = {}
	for index = 1, #pool do
		if pool[index] ~= last then candidates[#candidates + 1] = pool[index] end
	end
	return candidates[rand(1, #candidates)]
end

-- A new player's music state. `on` is whether music is audible; the first
-- track starts 30-90 s after joining (ruling 3).
function R.music_new(data, now, on, rand)
	return {on = on, phase = "wait", delivered = {},
		start_at = now + rand(data.music.first[1], data.music.first[2])}
end

local function begin(m, data, now)
	local track = m.track
	m.phase, m.ends_at, m.last, m.track = "play", now + data.tracks[track].seconds, track, nil
	return "play", track
end

local function push(m, track, now)
	m.track, m.pushing, m.push_at = track, track, now
	return "push", track
end

-- One pass of the scheduler. `pool` is the list of track ids for the
-- player's group now. Returns an action and a track id: "push" (send the
-- file to the player), "play", or nil.
--   * a playing track is never cut (no switch on a group change, none in
--     combat); when it ends a random 3-8 min pause starts;
--   * PUSH_LEAD seconds before the pause ends the next track is picked from
--     the pool of that moment and pushed if the player does not have it yet;
--   * when the pause ends and the player has meanwhile moved to a group whose
--     pool does not hold the pick, the pick is redone once from the new pool;
--   * the track plays as soon as the pause is over and the file is there
--     (the push callback calls music_delivered for the same rule);
--   * a push that is not confirmed within push_timeout seconds is dropped
--     and a new pause starts; an empty pool retries after empty_retry s.
-- Nothing is pushed or played while music is off.
function R.music_step(m, data, now, pool, rand)
	if not m.on then return nil end
	if m.phase == "play" then
		if now < m.ends_at then return nil end
		m.phase, m.track, m.pushing = "wait", nil, nil
		m.start_at = now + rand(data.music.pause[1], data.music.pause[2])
		return nil
	end
	if not m.track then
		if now < m.start_at - data.music.push_lead then return nil end
		if #pool == 0 then
			m.start_at = math.max(m.start_at, now + data.music.empty_retry)
			return nil
		end
		local track = pick_track(pool, m.last, rand)
		if not m.delivered[track] then return push(m, track, now) end
		m.track = track
	end
	if now < m.start_at then return nil end
	if not m.repicked and #pool > 0 and not contains(pool, m.track) then
		m.repicked = true
		local track = pick_track(pool, m.last, rand)
		if not m.delivered[track] then return push(m, track, now) end
		m.track = track
	end
	if m.delivered[m.track] then
		m.repicked = nil
		return begin(m, data, now)
	end
	if not m.pushing or now - m.push_at > data.music.push_timeout then
		m.track, m.pushing, m.repicked = nil, nil, nil
		m.start_at = now + rand(data.music.pause[1], data.music.pause[2])
	end
	return nil
end

-- The push of `track` arrived at the client. Returns "play", track when it
-- should start now (the pause is over and it is still the pick).
function R.music_delivered(m, data, track, now)
	m.delivered[track] = true
	if m.pushing == track then m.pushing = nil end
	if m.on and m.phase == "wait" and m.track == track and now >= m.start_at then
		m.repicked = nil
		return begin(m, data, now)
	end
	return nil
end

-- A push that the engine refused: forget the pick, start a new pause.
function R.music_push_failed(m, data, now, rand)
	m.track, m.pushing, m.repicked = nil, nil, nil
	m.start_at = now + rand(data.music.pause[1], data.music.pause[2])
end

-- Music switched off or on (on/off or a volume of 0). Off: returns "stop"
-- when a track plays; nothing is pushed until it is on again. On: the next
-- track comes after a short delay (data.music.resume).
function R.music_set_on(m, data, on, now, rand)
	if on == m.on then return nil end
	m.on = on
	local playing = m.phase == "play"
	m.phase, m.track, m.pushing, m.repicked = "wait", nil, nil, nil
	if on then
		m.start_at = now + rand(data.music.resume[1], data.music.resume[2])
		return nil
	end
	return playing and "stop" or nil
end

-- ---------------------------------------------------------------------------
-- Forge and fire emitters
-- ---------------------------------------------------------------------------

-- The emitters to play near `pos`. `found` is find_nodes_in_area's grouped
-- result (node name -> positions), `kinds` node name -> kind, `limits` kind
-- -> how many play at once, `active` key -> true for the emitters playing
-- now and `key(pos)` their key. Per kind: a playing emitter stays while it
-- is among the nearest 2 * limit, so walking along a river does not restart
-- loops every pass; the free places go to the nearest others. Returns a
-- list of {pos, kind, d2}, sorted by kind, then distance.
function R.choose_emitters(found, kinds, pos, limits, active, key)
	-- Per kind only the nearest 2 * limit are kept, by insertion into a short
	-- sorted list: a river bank can return hundreds of flowing nodes, and
	-- they are neither all sorted nor each given a table.
	local best = {}
	local function before(d2, p, row)
		if d2 ~= row.d2 then return d2 < row.d2 end
		if p.x ~= row.pos.x then return p.x < row.pos.x end
		if p.y ~= row.pos.y then return p.y < row.pos.y end
		return p.z < row.pos.z
	end
	for name, list in pairs(found) do
		local kind = kinds[name]
		if kind then
			local rows = best[kind] or {}
			best[kind] = rows
			local keep = 2 * (limits[kind] or 1)
			for index = 1, #list do
				local p = list[index]
				local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
				local d2 = dx * dx + dy * dy + dz * dz
				local n = #rows
				if n < keep or before(d2, p, rows[n]) then
					local at = n + 1
					while at > 1 and before(d2, p, rows[at - 1]) do at = at - 1 end
					table.insert(rows, at, {pos = p, kind = kind, d2 = d2})
					if #rows > keep then rows[#rows] = nil end
				end
			end
		end
	end
	local out = {}
	local order = {}
	for kind in pairs(best) do order[#order + 1] = kind end
	table.sort(order)
	for _, kind in ipairs(order) do
		local rows = best[kind]
		local limit, chosen, picked = limits[kind] or 1, 0, {}
		for index = 1, #rows do
			if chosen < limit and active[key(rows[index].pos)] then
				picked[index], chosen = true, chosen + 1
			end
		end
		for index = 1, #rows do
			if chosen >= limit then break end
			if not picked[index] then picked[index], chosen = true, chosen + 1 end
		end
		for index = 1, #rows do
			if picked[index] then out[#out + 1] = rows[index] end
		end
	end
	return out
end

return R
