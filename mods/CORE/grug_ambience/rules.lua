-- Ambience and music rules (Round 34 lane S2; round34-plan.md §2.1 rulings
-- 3-6, §4.2; Round 35 lane M, round35-plan.md §2.8: music only in the
-- capitals, either music or the bed; Round 52, round52-ambience-plan.md:
-- beds by biome group, three layers by the height relative to the terrain,
-- the cave verdict). PURE Lua: it calls nothing from `core`, so the portable fixture
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

-- `/music` and `/ambience`: "" (status), "on", "off", a volume or "debug"
-- (Round 52: the ambience's debug line; the music command refuses it).
-- Returns {on = bool} or {on = true, volume = n} (a volume above 0 also
-- switches the channel on, 0 switches it off), {debug = true}, {} for the
-- status, or nil for a bad word.
function R.parse_command(param)
	param = (param or ""):match("^%s*(.-)%s*%%?%s*$"):lower()
	if param == "" then return {} end
	if param == "on" then return {on = true} end
	if param == "off" then return {on = false} end
	if param == "debug" then return {debug = true} end
	local volume = param:match("^%d+$") and R.clamp_volume(param)
	if not volume then return nil end
	return {on = volume > 0, volume = volume}
end

-- The channel plays only when it is on and its volume is above zero.
function R.audible(on, volume)
	return on and volume > 0
end

-- ---------------------------------------------------------------------------
-- Sound keys and beds (Round 52: by biome group, round52-ambience-plan.md §2)
-- ---------------------------------------------------------------------------

-- The player's sound key: a zone override by atmosphere mood (data.overrides:
-- the Battlegrounds, the dragon islands, the open ocean) before the group of
-- the biome under the player; an ownerless column (`known` but no biome: the
-- deep ocean) is the ocean, a biome without a group false (no bed). nil
-- keeps the key the player has: nothing is known yet (no zone authority),
-- the player is in the underground mood, which hides the zone (the surface
-- layer is silent that deep anyway), or the biome is a neutral one
-- (data.neutral, 0.52.1: the beach, which also lies far inland; the surf
-- comes from the sea share, R.sea_blend). A neutral biome keeps only a
-- group key: an override key `current` (the dragon island's coast bed and
-- no surf, the ocean's surf alone) is dropped for false (no region bed;
-- the surf by the share), so landing on a beach from the channel or the
-- deep ocean does not carry them inland.
function R.sound_key(data, mood, known, biome, current)
	if mood == "underground" then return nil end
	if mood and data.overrides[mood] then return mood end
	if not known then return nil end
	if biome == nil then return "ocean" end
	if data.neutral[biome] then
		if current and data.overrides[current] then return false end
		return nil
	end
	return data.groups[biome] or false
end

-- The biome a start town looks like (0.52.1): `towns` is a list of the
-- start towns' anchors {race, x, z}; the nearest one within
-- data.town_reach of (x, z) names it through data.town_looks[race] (the
-- ground its composition lays). nil outside every start town's reach.
function R.start_town_look(data, towns, x, z)
	local best, best_d2 = nil, data.town_reach * data.town_reach
	for index = 1, #towns do
		local town = towns[index]
		local dx, dz = town.x - x, town.z - z
		local d2 = dx * dx + dz * dz
		if d2 <= best_d2 then best, best_d2 = town, d2 end
	end
	return best and data.town_looks[best.race] or nil
end

-- The bed keys to try for the surface layer, best first (an empty list:
-- silence), or nil when there is no key yet and no stream near the player
-- (the caller then keeps the bed it has). `s`: key (a sound key, false for
-- none), night, water ("stream" or nil), underwater.
--   underwater beats everything: the `underwater` bed (the caller plays it
--   at the full bed level, R.surface_levels);
--   stream water near the player overrides the region bed (no stream bed
--   ships); the region bed has a night variant where data.region names one
--   (falling back to the day bed when that has no shipped file), silence at
--   night where it says `night = false`, else the day bed plays at night
--   too. Since 0.52.1 the sea is no bed of this layer but a layer of its
--   own (R.sea_blend).
function R.bed_keys(data, s)
	if s.underwater then return {"underwater"} end
	local keys = {}
	if s.water == "stream" then keys[#keys + 1] = "stream" end
	local row = s.key and data.region[s.key]
	if row then
		if not (s.night and row.night == false) then
			if s.night and row.night then keys[#keys + 1] = row.night end
			keys[#keys + 1] = row.day
		end
	elseif s.key == nil and #keys == 0 then
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
-- pick_bed's result (nil keeps the bed). Since Round 52 the wind and cave
-- layers are silent there too.
function R.bed_wanted(wanted, music)
	if music then return false end
	return wanted
end

-- Hysteresis: a new surface bed must be wanted on two passes in a row
-- before it replaces the playing one, so walking along a river bank, a town
-- edge or a biome border does not swap beds every pass; diving in or coming
-- up changes at once, and so does music starting or ending: the bed and the
-- track then crossfade (the bed over D.crossfade, the track's fade-in or
-- D.music.fade_out), a short fade, never a hard cut.
-- `b` is the surface layer's state {key, want, seen, underwater, music};
-- `wanted` a key or false (silence); `underwater` and `music` this pass's
-- flags; `silent` true when the layer plays no sound now (0.52.1: then a
-- new key is taken at once, nothing would crossfade: e.g. coming ashore
-- after the surf played alone, the old key's bed must not start for a
-- pass). Returns true when the bed should change to `wanted` now.
function R.bed_should_change(b, wanted, underwater, music, silent)
	underwater, music = underwater == true, music == true
	local flipped = underwater ~= (b.underwater == true) or music ~= (b.music == true)
	b.underwater, b.music = underwater, music
	if wanted == b.key then
		b.want, b.seen = nil, 0
		return false
	end
	if b.key == nil or flipped or silent then
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

-- The gain of a layer at full level: the base bed gain, the player's
-- volume, halved in start towns and capitals (user, round34-plan.md §2.2;
-- in a capital the beds play only with music off).
function R.bed_gain(data, volume, town)
	return data.gains.bed * volume / 100 * (town and data.gains.town_bed or 1)
end

-- ---------------------------------------------------------------------------
-- Layers (Round 52 ruling 7, §3.2 steps 4, 5 and 11)
-- ---------------------------------------------------------------------------

-- A layer's level (a share of the bed level) changes the sound only when it
-- moved by LEVEL_STEP since the level last sent (the dead band: slow climbing
-- or hovering sends nothing every pass), and a silent layer starts only at
-- LEVEL_STEP. A layer whose level falls to 0 fades to LEVEL_FLOOR and keeps
-- its sound; only after FLOOR_PASSES passes in a row at 0 is it stopped
-- (faded to 0, which deletes the sound), so hovering at a threshold does not
-- restart loops every 2 s.
R.LEVEL_STEP = 0.03
R.LEVEL_FLOOR = 0.01
R.FLOOR_PASSES = 3

local function clamp01(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

-- The three layers' levels at `depth` nodes below the surface reference
-- (negative: above it; nil: unknown, then the surface plays alone) for a
-- player at absolute height `y`; `cave` is the cave probe's verdict.
-- Returns surface, wind, cave.
function R.layer_levels(data, depth, y, cave)
	if depth == nil then return 1, 0, 0 end
	local L = data.layers
	local up = -depth
	local surface
	if depth >= 0 then
		surface = 1 - depth / L.surface.down
	else
		surface = 1 - (up - L.surface.up_full) / (L.surface.up_zero - L.surface.up_full)
	end
	local wind = clamp01((up - L.wind.from) / (L.wind.full - L.wind.from)) * L.wind.level
	if depth <= L.peak.max_depth then
		local peak = clamp01((y - L.peak.y) / L.peak.ramp) * L.peak.level
		if peak > wind then wind = peak end
	end
	local cave_level = 0
	if cave then
		cave_level = clamp01((depth - L.cave.from) / (L.cave.full - L.cave.from)) * L.cave.level
	end
	return clamp01(surface), wind, cave_level
end

-- One pass of a layer. `l` is the layer's state {key, playing, level, base,
-- idle}: the bed key of its sound, whether a sound plays, the level and
-- the full-level gain last sent, the passes in a row at 0. `key` is the bed
-- it should play now (false: none), `target` its level, `base` the gain at
-- full level. Updates `l` and returns what the caller does with the sound:
--   "start"  play `l.key` at l.level * l.base, fading in;
--   "switch" fade the playing sound out (to 0) and start `l.key` like that;
--   "fade"   fade the playing sound to l.level * l.base;
--   "stop"   fade the playing sound to 0 (deleting it);
--   nil      nothing.
-- A stopped sound is never faded again: the caller drops its handle.
function R.layer_step(l, key, target, base)
	if l.playing and key ~= l.key then
		l.key = key
		if key and target >= R.LEVEL_STEP then
			l.level, l.base, l.idle = target, base, 0
			return "switch"
		end
		l.playing, l.level, l.idle = false, 0, 0
		return "stop"
	end
	l.key = key
	if not l.playing then
		if key and target >= R.LEVEL_STEP then
			l.playing, l.level, l.base, l.idle = true, target, base, 0
			return "start"
		end
		return nil
	end
	if target <= 0 then
		l.idle = l.idle + 1
		if l.idle >= R.FLOOR_PASSES then
			l.playing, l.level, l.idle = false, 0, 0
			return "stop"
		end
		if l.level ~= R.LEVEL_FLOOR or base ~= l.base then
			l.level, l.base = R.LEVEL_FLOOR, base
			return "fade"
		end
		return nil
	end
	l.idle = 0
	if target < R.LEVEL_FLOOR then target = R.LEVEL_FLOOR end
	if base ~= l.base or math.abs(target - l.level) >= R.LEVEL_STEP then
		l.level, l.base = target, base
		return "fade"
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- The sea (0.52.1, round52-ambience-plan.md §8)
-- ---------------------------------------------------------------------------

-- The classes of grug_zones.water_query_at that are the sea. A lake, a
-- river, a swamp pool (class "lake") and dry land (nil) are land for the
-- surf, whatever their size and whatever water node they hold.
R.SEA_CLASSES = {bay = true, belt = true, channel = true, open_sea = true}

-- The sample columns round the player: every `data.sea.step` nodes on x and
-- z, within `data.sea.radius` of the player's grid point (49 for 4 and 16).
-- A list of {dx, dz}.
function R.sea_points(data)
	local step, radius = data.sea.step, data.sea.radius
	local reach = math.floor(radius / step)
	local list = {}
	for i = -reach, reach do
		for j = -reach, reach do
			if (i * step) ^ 2 + (j * step) ^ 2 <= radius * radius then
				list[#list + 1] = {i * step, j * step}
			end
		end
	end
	return list
end

-- How the sound key's region bed meets the sea: "only" (the key is the sea
-- itself: the open ocean; the surf plays alone), "none" (the dragon
-- islands keep their own coast bed) or "blend" (every other key, and none).
function R.surf_mode(data, key)
	local row = key and data.region[key]
	return row and row.surf or "blend"
end

-- The surf's share of the surface level (0 to 1). `share` is the share of
-- sea columns among the samples (nil: unknown, no surf), `on_sea` whether
-- the player's own column is sea. On the water (or over it) only the surf
-- plays; on land the surf rises with the share and is full at
-- data.sea.full_share (a straight coast reads about a half at the water
-- line and nothing 16 nodes inland).
function R.sea_blend(data, mode, share, on_sea)
	if mode == "only" then return 1 end
	if mode == "none" or share == nil then return 0 end
	if on_sea then return 1 end
	return clamp01(share / data.sea.full_share)
end

-- The region bed's and the surf's levels from the surface level and the
-- blend; under water the surface layer plays the underwater bed at the full
-- bed level (no height curve: a diver hears it at any depth) and the surf
-- is silent.
function R.surface_levels(surface, blend, underwater)
	if underwater then return 1, 0 end
	return surface * (1 - blend), surface * blend
end

-- ---------------------------------------------------------------------------
-- The cave probe (Round 52 ruling 6, §3.2 step 6)
-- ---------------------------------------------------------------------------

-- Whether the probe runs this pass at `pos` (the caller runs it only below
-- data.cave.min_depth): when it never ran, when the player moved 2 nodes or
-- more since it last ran, or after 3 passes; otherwise the last share is
-- reused. `c` is the probe state {px, py, pz, age}.
function R.probe_due(c, pos)
	if c.px then
		local dx, dy, dz = pos.x - c.px, pos.y - c.py, pos.z - c.pz
		if dx * dx + dy * dy + dz * dz < 4 and c.age < 3 then
			c.age = c.age + 1
			return false
		end
	end
	c.px, c.py, c.pz, c.age = pos.x, pos.y, pos.z, 1
	return true
end

-- The cave verdict from this pass's open-air share, with the beds'
-- two-pass hysteresis: a new verdict must come on two passes in a row.
-- `c` holds {cave, want, seen}. Returns the verdict.
function R.cave_step(c, share, threshold)
	local now = share >= threshold
	if now == (c.cave == true) then
		c.want, c.seen = nil, 0
	elseif c.want == now then
		c.seen = c.seen + 1
	else
		c.want, c.seen = now, 1
	end
	if c.seen >= 2 then
		c.cave, c.want, c.seen = now, nil, 0
	end
	return c.cave == true
end

-- Whether the cave layer plays the deep bed at height `y`, from the last
-- answer `was`: in below data.deep_y - data.deep_band, out above
-- data.deep_y + data.deep_band.
function R.deep_cave(data, was, y)
	if was then return y < data.deep_y + data.deep_band end
	return y < data.deep_y - data.deep_band
end

-- ---------------------------------------------------------------------------
-- Calls
-- ---------------------------------------------------------------------------

-- Seconds until the next call: mostly minutes apart, never below the floor.
function R.next_call_delay(data, rand)
	return rand(data.call_gap[1], data.call_gap[2])
end

-- The call ids that fit state `s` and have a shipped sound, sorted, so a
-- seeded random pick is reproducible. `s`: key (the sound key), biome,
-- night, underwater, underground (the underground mood), surface (the
-- surface layer's level). None under water or underground; a call with
-- `surface` only while the surface layer is at least that level.
function R.eligible_calls(data, s, available)
	local list = {}
	if s.underwater or s.underground or not s.key then return list end
	for id, call in pairs(data.calls) do
		local time_ok = call.time == "any" or (call.time == "night") == (s.night == true)
		local where_ok = (call.keys and call.keys[s.key]) or
			(call.biomes and s.biome and call.biomes[s.biome])
		local level_ok = not call.surface or (s.surface or 0) >= call.surface
		if time_ok and where_ok and level_ok and available[call.sound] then
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

-- The track that really plays now, or nil (0.45.1, the "Now playing" box
-- under the minimap): only while a track plays, so the box hides in the
-- pause between two tracks, while a pick waits for its download, on leaving
-- the capital (with the fade-out) and with music off or at volume 0.
function R.now_playing(m)
	return m.phase == "play" and m.track or nil
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
