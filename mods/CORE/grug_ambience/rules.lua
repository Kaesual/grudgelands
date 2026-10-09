-- Ambience and music rules (Round 34 lane S2; round34-plan.md §2.1 rulings
-- 3-6, §4.2; Round 35 lane M, round35-plan.md §2.8: music only in the
-- capitals, either music or the bed). PURE Lua: it calls nothing from `core`, so the portable fixture
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

-- The volume a player starts with, per channel (Round 35: music quieter).
R.DEFAULT_VOLUME = {music = 35, ambience = 100}

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

-- Either music or the bed (Round 35): where music plays (R.music_active)
-- the bed is silent, else the bed the state asks for. `wanted` is
-- pick_bed's result (nil keeps the bed).
function R.bed_wanted(wanted, music)
	if music then return false end
	return wanted
end

-- Hysteresis: a new bed must be wanted on two passes in a row before it
-- replaces the playing one, so walking along a river bank or a town edge
-- does not swap beds every pass; diving in or coming up changes at once, and
-- so does music starting or ending: the bed and the track then crossfade
-- (the bed over D.crossfade, the track's fade-in or D.music.fade_out), a
-- short fade, never a hard cut.
-- `b` is the player's bed state {key, want, seen, underwater, music};
-- `wanted` a key or false (silence); `underwater` and `music` this pass's
-- flags. Returns true when the bed should change to `wanted` now.
function R.bed_should_change(b, wanted, underwater, music)
	underwater, music = underwater == true, music == true
	local flipped = underwater ~= (b.underwater == true) or music ~= (b.music == true)
	b.underwater, b.music = underwater, music
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

-- The bed's gain: the base gain, the player's volume, quieter in start
-- towns and capitals (user, round34-plan.md §2.2; in a capital the bed plays
-- only with music off).
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

-- Music plays for a player only in a capital (round35-plan.md §2.8), one
-- rotation per capital; the runtime passes the capital the player counts as
-- in (grug_map.location.capital_of, with its border hysteresis) and that
-- capital's rotation of shipped tracks.
--
-- Music state: on (music audible), capital (where it plays now, nil:
-- nowhere), phase ("idle", "wait" for the pick to start, "play"), track (the
-- pick waiting or playing), next (the pick after it, pushed while `track`
-- plays), index (position in the rotation), delivered (track -> true once
-- the client has the file), pushing and push_at (the push in flight), hold
-- (no push before this time, after a refused one), start_at, ends_at.

-- A new player's music state: silent until the player is in a capital.
function R.music_new(on)
	return {on = on, phase = "idle", delivered = {}, hold = 0}
end

-- Whether music has the player's ear now: music on and in a capital with a
-- rotation. The bed is silent then (R.bed_wanted).
function R.music_active(m)
	return m.on and m.capital ~= nil
end

local function next_track(m, rotation)
	m.index = m.index % #rotation + 1
	return rotation[m.index]
end

local function push(m, track, now)
	m.pushing, m.push_at = track, now
	return "push", track
end

local function begin(m, data, now)
	m.phase, m.ends_at = "play", now + data.tracks[m.track].seconds
	return "play", m.track
end

-- One pass of the scheduler. Returns an action and a track id: "push" (send
-- the file to the player), "play", "stop" (fade the playing track out), or
-- nil.
--   * entering a capital starts its rotation at a random place: the first
--     track plays at once, or as soon as its push arrives;
--   * leaving it (or a capital with no shipped track) stops the playing
--     track with a fade and forgets every pick;
--   * PUSH_LEAD seconds before a track ends the next one of the rotation is
--     pushed if the player does not have it yet; after a track a pause of
--     data.music.pause, then the next track plays (or as soon as its push
--     arrives);
--   * a push not confirmed within push_timeout seconds is given up and the
--     rotation moves on; a refused one holds every push for retry seconds.
-- Nothing is pushed or played while music is off.
function R.music_step(m, data, now, capital, rotation, rand)
	if not m.on then return nil end
	if capital and #rotation == 0 then capital = nil end
	if capital ~= m.capital then
		local playing = m.phase == "play"
		m.capital, m.track, m.next, m.pushing = capital, nil, nil, nil
		if capital then
			m.phase, m.start_at, m.index = "wait", now, rand(1, #rotation) - 1
		else
			m.phase = "idle"
		end
		if playing then return "stop" end
	end
	if m.phase == "play" then
		if now >= m.ends_at then
			m.phase, m.start_at = "wait", now + data.music.pause
			m.track, m.next = m.next, nil
		elseif not m.next and now >= m.ends_at - data.music.push_lead and now >= m.hold then
			m.next = next_track(m, rotation)
			if not m.delivered[m.next] then return push(m, m.next, now) end
		end
		return nil
	end
	if m.phase ~= "wait" then return nil end
	if not m.track then
		if now < m.hold then return nil end
		m.track = next_track(m, rotation)
		if not m.delivered[m.track] then return push(m, m.track, now) end
	end
	if now < m.start_at then return nil end
	if m.delivered[m.track] then return begin(m, data, now) end
	if m.pushing ~= m.track or now - m.push_at > data.music.push_timeout then
		-- Never pushed (a hold came between), lost or refused: move on.
		m.track, m.pushing = nil, nil
	end
	return nil
end

-- The push of `track` arrived at the client. Returns "play", track when it
-- should start now (the pick waits and its start time has come).
function R.music_delivered(m, data, track, now)
	m.delivered[track] = true
	if m.pushing == track then m.pushing = nil end
	if m.on and m.phase == "wait" and m.track == track and now >= m.start_at then
		return begin(m, data, now)
	end
	return nil
end

-- A push that the engine refused: forget it and push nothing for a while;
-- the pick it was for is skipped.
function R.music_push_failed(m, data, track, now)
	if m.pushing == track then m.pushing = nil end
	if m.track == track and m.phase == "wait" then m.track = nil end
	if m.next == track then m.next = nil end
	m.hold = now + data.music.retry
end

-- Music switched off or on (on/off or a volume of 0). Off: returns "stop"
-- when a track plays; nothing is pushed until it is on again. On: the next
-- pass starts the capital's rotation if the player is in one.
function R.music_set_on(m, on)
	if on == m.on then return nil end
	m.on = on
	local playing = m.phase == "play"
	m.phase, m.capital, m.track, m.next, m.pushing = "idle", nil, nil, nil, nil
	if not on and playing then return "stop" end
	return nil
end

-- ---------------------------------------------------------------------------
-- Emitters (fire and flowing water)
-- ---------------------------------------------------------------------------

-- The emitters to play near `pos`. `found` is find_nodes_in_area's grouped
-- result (node name -> positions), `kinds` node name -> kind, `limits` kind
-- -> how many play at once, `hears` kind -> hearing distance (a node farther
-- away is no candidate), `active` key -> true for the emitters playing
-- now and `key(pos)` their key. Per kind: a playing emitter stays while it
-- is among the nearest 2 * limit, so walking along a river does not restart
-- loops every pass; the free places go to the nearest others. Returns a
-- list of {pos, kind, d2}, sorted by kind, then distance.
function R.choose_emitters(found, kinds, pos, limits, hears, active, key)
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
			local hear = hears[kind] or math.huge
			local hear2 = hear * hear
			for index = 1, #list do
				local p = list[index]
				local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
				local d2 = dx * dx + dy * dy + dz * dz
				local n = #rows
				if d2 <= hear2 and (n < keep or before(d2, p, rows[n])) then
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
