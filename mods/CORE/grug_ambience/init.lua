-- Ambience and music per player (Round 34 lane S2; round34-plan.md §2.1
-- rulings 3-6, §4.2). Why: the game was silent outside a few node sounds.
--
--   * a quiet looped bed per state, to the player only: the region by the
--     atmosphere mood the player already carries (grug_core.get_atmosphere),
--     a night bed after dusk where crickets fit, sea and stream water near
--     the player, under water, the underground and its deep band; in start
--     towns and capitals the bed plays at half gain. A change crossfades
--     (core.sound_fade). Where music plays the bed is silent (Round 35);
--   * sparse calls by mood and time of day, a per-player timer, placed at a
--     point around the player (Round 34: distant thunder on the dragon
--     islands only);
--   * loops at hearths and camp fires and flowing water (never at a water
--     source) near the player: one find_nodes_in_area per pass above ground,
--     the nearest two of each kind, positional, to that player only (Round
--     45 PT8: none at forges and anvils);
--   * music only in the six capitals (Round 35, round35-plan.md §2.8): each
--     capital's rotation plays from entering the city (grug_map's
--     location.capital_of, with a few nodes of hysteresis at the border) with
--     short pauses, and fades out on leaving (rules.lua music_step). Music
--     files live in music/, outside every sounds/ folder, so the first join
--     downloads none of them; each track is pushed to one player with
--     core.dynamic_add_media (the next one while the current one plays),
--     only while that player has music on, and plays in the push callback
--     (lua_api.md dynamic_add_media);
--   * while a track really plays, a "Now playing" box under the minimap names
--     its title and artist (0.45.1; drawn by grug_map minimap.lua). It is
--     told only when the playing track changes (sync_now_playing): after
--     each scheduler pass, a delivery and a music switch;
--   * music and ambience on/off and volume per player in player meta, applied
--     at once; the Help page's Sound sub-page and /music, /ambience.
--
-- Round 34 (round34-plan.md §2.2a): a bed per zone, no stream and no
-- underwater bed; data.lua holds every name, so another bed is data only.
--
-- Cost: one pass per player every 2 s, spread over eight slots of 0.25 s
-- (AGENTS.md Round 32): a mood and town lookup, one get_node_raw read for
-- under water (33 when sea or stream beds exist), one find_nodes_in_area
-- above ground, a few sound packets when something changes. grug_ambience.stats holds comparison figures for the
-- report (tools/r34_s2 probe).
--
-- A /atmosphere preset (atmosphere.lua, admin A/B test) pauses the zone
-- driver: a forced mood drives the bed like the zone would (so each mood's
-- bed can be checked in place); a preset that is no mood (default, off,
-- godrays, hearthpine) keeps the bed the player had.
--
-- Pure rules: rules.lua; names, gains and rotations: data.lua.

grug_ambience = {}

local modpath = core.get_modpath(core.get_current_modname())
local R = dofile(modpath .. "/rules.lua")
local D = dofile(modpath .. "/data.lua")
grug_ambience.rules, grug_ambience.data = R, D

local MOODS = grug_core.atmosphere_moods or {}
local floor, random = math.floor, math.random

-- ---------------------------------------------------------------------------
-- What is shipped
-- ---------------------------------------------------------------------------

-- Sound-group names with a file in sounds/ (`name.ogg` or `name.<digit>.ogg`)
-- and the music files in music/. Only these are ever played or pushed, so a
-- name in data.lua without an approved, shipped file stays silent.
local available = {}
for _, file in ipairs(core.get_dir_list(modpath .. "/sounds", false) or {}) do
	local base = file:match("^(.-)%.%d%.ogg$") or file:match("^(.-)%.ogg$")
	if base then available[base] = true end
end
local music_files = {}
for _, file in ipairs(core.get_dir_list(modpath .. "/music", false) or {}) do
	music_files[file] = true
end
local rotations = {}
for capital, list in pairs(D.rotations) do
	local shipped = {}
	for _, id in ipairs(list) do
		local track = D.tracks[id]
		if track and music_files[track.file] then shipped[#shipped + 1] = id end
	end
	rotations[capital] = shipped
end
local NO_ROTATION = {}
-- Read by the engine probes (tools/r34_s2, tools/r35_m), which may mark
-- names available.
grug_ambience.available, grug_ambience.rotations = available, rotations

-- Comparison figures: passes, their summed microseconds, the node searches,
-- their microseconds and the positions they returned, sounds started,
-- pushes.
local stats = {passes = 0, us = 0, finds = 0, find_us = 0, found = 0, plays = 0,
	pushes = 0}
grug_ambience.stats = stats

local function now_seconds()
	return core.get_us_time() / 1000000
end

-- ---------------------------------------------------------------------------
-- Player state and settings
-- ---------------------------------------------------------------------------

-- name -> {slot, music_on, music_volume, ambience_on, ambience_volume,
-- bed = {key, handle, gain, want, seen, underwater, music}, emitters =
-- {[hash] = {handle, gain, kind}}, next_call, music = rules music state,
-- track_handle, track_gain, shown_track (the track the minimap's box names)}
local states = {}

local META = {
	music_off = "grug_ambience:music_off",
	music_volume = "grug_ambience:music_volume",
	ambience_off = "grug_ambience:ambience_off",
	ambience_volume = "grug_ambience:ambience_volume",
}

local function read_settings(player, st)
	local meta = player:get_meta()
	st.music_on = meta:get_int(META.music_off) ~= 1
	st.music_volume = R.clamp_volume(meta:get(META.music_volume)) or R.DEFAULT_VOLUME.music
	st.ambience_on = meta:get_int(META.ambience_off) ~= 1
	st.ambience_volume = R.clamp_volume(meta:get(META.ambience_volume)) or
		R.DEFAULT_VOLUME.ambience
end

local function music_audible(st) return R.audible(st.music_on, st.music_volume) end
local function ambience_audible(st) return R.audible(st.ambience_on, st.ambience_volume) end

-- Fades a handle to `gain` over about `seconds` (0 deletes the sound).
local function fade(handle, from, gain, seconds)
	local step = math.abs(gain - from) / seconds
	if step > 0 then core.sound_fade(handle, step, gain) end
end

-- ---------------------------------------------------------------------------
-- Beds, calls and emitters
-- ---------------------------------------------------------------------------

local function stop_bed(st)
	local bed = st.bed
	if bed.handle then fade(bed.handle, bed.gain, 0, D.crossfade) end
	bed.handle, bed.key, bed.gain, bed.want, bed.seen = nil, nil, 0, nil, 0
	bed.underwater, bed.music = nil, nil
end

-- Crossfades to bed `key` (false: silence).
local function switch_bed(name, st, key, gain)
	local bed = st.bed
	if bed.handle then fade(bed.handle, bed.gain, 0, D.crossfade) end
	bed.handle, bed.key, bed.gain = nil, key, gain
	if key then
		local sound = R.bed_sound(D, key, available, random)
		bed.handle = core.sound_play({name = sound, gain = gain},
			{to_player = name, loop = true, fade = gain / D.crossfade}, false)
		stats.plays = stats.plays + 1
	end
end

local function stop_emitters(st)
	for hash, emitter in pairs(st.emitters) do
		fade(emitter.handle, emitter.gain, 0, D.crossfade)
		st.emitters[hash] = nil
	end
end

local function emitter_gain(st, kind)
	return D.gains[kind] * st.ambience_volume / 100
end

-- Kind -> hearing distance. The engine ignores max_hear_distance for a
-- to_player sound, so the choice below drops nodes farther than this.
local emitter_hears = {}
for kind, spec in pairs(D.emitters) do emitter_hears[kind] = spec.hear end

-- Node name -> emitter kind and the names searched, filled once every node
-- is registered: data.lua's nodes plus every other flowing liquid whose
-- source is default or river water (a grug liquid joins by itself).
local emitter_kinds, emitter_names, emitter_limits = {}, {}, {}
for kind, spec in pairs(D.emitters) do emitter_limits[kind] = spec.limit end
core.register_on_mods_loaded(function()
	for node, kind in pairs(D.emitter_nodes) do emitter_kinds[node] = kind end
	for node, def in pairs(core.registered_nodes) do
		local source = def.liquid_alternative_source
		if def.liquidtype == "flowing" and (source == "default:water_source" or
				source == "default:river_water_source") then
			emitter_kinds[node] = "water"
		end
	end
	for node in pairs(emitter_kinds) do
		if core.registered_nodes[node] then emitter_names[#emitter_names + 1] = node end
	end
	table.sort(emitter_names)
end)

-- The loops near `pos`: start the chosen ones, fade out the rest.
local function update_emitters(name, st, pos)
	local reach = D.emitter_reach
	local started = core.get_us_time()
	local found = core.find_nodes_in_area(
		{x = pos.x - reach.x, y = pos.y - reach.y, z = pos.z - reach.z},
		{x = pos.x + reach.x, y = pos.y + reach.y, z = pos.z + reach.z},
		emitter_names, true)
	stats.finds = stats.finds + 1
	stats.find_us = stats.find_us + (core.get_us_time() - started)
	local keep = {}
	if next(found) then
		for _, list in pairs(found) do stats.found = stats.found + #list end
		local active = {}
		for hash in pairs(st.emitters) do active[hash] = true end
		for _, row in ipairs(R.choose_emitters(found, emitter_kinds, pos, emitter_limits,
				emitter_hears, active, core.hash_node_position)) do
			local spec = D.emitters[row.kind]
			if available[spec.sound] then
				local hash = core.hash_node_position(row.pos)
				keep[hash] = true
				if not st.emitters[hash] then
					local gain = emitter_gain(st, row.kind)
					st.emitters[hash] = {kind = row.kind, gain = gain,
						handle = core.sound_play({name = spec.sound, gain = gain},
							{to_player = name, pos = row.pos, loop = true,
								fade = gain / D.crossfade}, false)}
					stats.plays = stats.plays + 1
				end
			end
		end
	end
	for hash, emitter in pairs(st.emitters) do
		if not keep[hash] then
			fade(emitter.handle, emitter.gain, 0, D.crossfade)
			st.emitters[hash] = nil
		end
	end
end

-- One call at a random point around `pos`. The gain is scaled by the
-- distance: the client attenuates positional sounds as 3 / distance
-- (src/client/sound/playing_sound.cpp setGain), so `gains.call` is the gain
-- heard at the call's distance.
local function play_call(name, st, pos, id)
	local call = D.calls[id]
	local angle = random() * 2 * math.pi
	local distance = random(call.distance[1], call.distance[2])
	core.sound_play({name = call.sound,
			gain = D.gains.call * st.ambience_volume / 100 * distance / 3},
		{to_player = name,
			pos = {x = pos.x + math.cos(angle) * distance, y = pos.y + 6,
				z = pos.z + math.sin(angle) * distance}}, true)
	stats.plays = stats.plays + 1
end

-- ---------------------------------------------------------------------------
-- Water probe
-- ---------------------------------------------------------------------------

-- Content id -> "sea" (default water) or "stream" (river water: rivers and
-- lakes, r7_content.lua), filled once every node is registered.
local water_kind = {}
core.register_on_mods_loaded(function()
	for node, kind in pairs({["default:water_source"] = "sea",
			["default:water_flowing"] = "sea",
			["default:river_water_source"] = "stream",
			["default:river_water_flowing"] = "stream"}) do
		if core.registered_nodes[node] then water_kind[core.get_content_id(node)] = kind end
	end
end)

-- Sixteen columns round the player (eight directions at 3 and 7 nodes),
-- read one and two nodes below the feet: a bank one or two nodes above the
-- water still hears it. Thresholds: a sixth of the 32 reads sea, or three
-- river reads, make the water bed. Read only when a sea or stream bed
-- exists (none this round).
local RING = {}
for _, radius in ipairs({3, 7}) do
	for step = 0, 7 do
		local angle = step * math.pi / 4
		RING[#RING + 1] = {floor(math.cos(angle) * radius + 0.5),
			floor(math.sin(angle) * radius + 0.5)}
	end
end
local SEA_READS, STREAM_READS = 6, 3
local WATER_BEDS = D.beds.sea ~= nil or D.beds.stream ~= nil
local EYE_HEIGHT = 1.625
local get_node_raw = core.get_node_raw

-- Returns the water near the player ("sea", "stream" or nil) and whether
-- the eye is under water.
local function probe_water(pos)
	local x, y, z = floor(pos.x + 0.5), floor(pos.y + 0.5), floor(pos.z + 0.5)
	if water_kind[get_node_raw(x, floor(pos.y + EYE_HEIGHT + 0.5), z)] then
		return nil, true
	end
	if not WATER_BEDS then return nil, false end
	local sea, stream = 0, 0
	for index = 1, #RING do
		local offset = RING[index]
		for dy = -2, -1 do
			local kind = water_kind[get_node_raw(x + offset[1], y + dy, z + offset[2])]
			if kind == "sea" then
				sea = sea + 1
			elseif kind == "stream" then
				stream = stream + 1
			end
		end
	end
	if sea >= SEA_READS then return "sea", false end
	if stream >= STREAM_READS then return "stream", false end
	return nil, false
end

-- ---------------------------------------------------------------------------
-- Music
-- ---------------------------------------------------------------------------

local location = grug_map.location
-- The minimap's "Now playing" box (0.45.1). The portable fixtures' fake
-- grug_map has no minimap.
local minimap = grug_map.minimap

-- Tells the minimap the track that plays now (nil: none) when it differs
-- from the one told last, so a pass that changes nothing sends nothing.
local function sync_now_playing(name, st)
	local track = R.now_playing(st.music)
	if track == st.shown_track then return end
	st.shown_track = track
	if minimap then minimap.set_now_playing(name, track and D.tracks[track]) end
end

local function music_gain(st)
	return D.gains.music * st.music_volume / 100
end

-- A pushed file is played by its name without the extension.
local function play_track(name, st, track)
	local gain = music_gain(st)
	local sound = D.tracks[track].file:match("^(.-)%.ogg$")
	st.track_handle, st.track_gain = core.sound_play({name = sound, gain = gain},
		{to_player = name, fade = gain / 2}, false), gain
	stats.plays = stats.plays + 1
	core.log("action", "[grug_ambience] music for " .. name .. ": " .. track)
end

local function stop_track(st)
	if st.track_handle then fade(st.track_handle, st.track_gain, 0, D.music.fade_out) end
	st.track_handle = nil
end

local push_warned = false
local function push_track(name, st, track)
	local ok = core.dynamic_add_media({
		filepath = modpath .. "/music/" .. D.tracks[track].file,
		to_player = name, ephemeral = false, client_cache = true,
	}, function(player_name)
		local current = states[player_name]
		if not current then return end
		local action, which = R.music_delivered(current.music, D, track, now_seconds())
		if action == "play" then
			play_track(player_name, current, which)
			sync_now_playing(player_name, current)
		end
	end)
	stats.pushes = stats.pushes + 1
	if not ok then
		R.music_push_failed(st.music, D, track, now_seconds())
		if not push_warned then
			push_warned = true
			core.log("warning", "[grug_ambience] music push refused: " .. track)
		end
	end
end

-- The music pass, before the bed's (the bed follows R.music_active).
local function music_pass(name, st, now)
	local capital = location.capital_of(name)
	local action, track = R.music_step(st.music, D, now, capital,
		capital and rotations[capital] or NO_ROTATION, random)
	if action == "push" then
		push_track(name, st, track)
	elseif action == "play" then
		play_track(name, st, track)
	elseif action == "stop" then
		stop_track(st)
	end
	-- A track's end (the pause) returns no action, so compare every pass.
	sync_now_playing(name, st)
end

-- ---------------------------------------------------------------------------
-- The per-player pass
-- ---------------------------------------------------------------------------

local scratch = {}

local function evaluate(name, st, now, night)
	local player = core.get_player_by_name(name)
	if not player then return end
	local started = core.get_us_time()
	local pos = player:get_pos()
	local mood = grug_core.get_atmosphere(name)
	if not MOODS[mood] then mood = nil end
	local town = location.in_town(name)
	music_pass(name, st, now)
	if ambience_audible(st) then
		local water, underwater = probe_water(pos)
		scratch.mood, scratch.night, scratch.water = mood, night, water
		scratch.underwater, scratch.deep = underwater, pos.y < D.deep_y
		local music = R.music_active(st.music)
		local wanted = R.bed_wanted(R.pick_bed(D, R.bed_keys(D, scratch), available), music)
		local gain = R.bed_gain(D, st.ambience_volume, town)
		if wanted ~= nil and R.bed_should_change(st.bed, wanted, underwater, music) then
			switch_bed(name, st, wanted, gain)
		elseif st.bed.handle and gain ~= st.bed.gain then
			fade(st.bed.handle, st.bed.gain, gain, D.crossfade)
			st.bed.gain = gain
		end
		if now >= st.next_call then
			st.next_call = now + R.next_call_delay(D, random)
			local calls = R.eligible_calls(D, scratch, available)
			if #calls > 0 then play_call(name, st, pos, calls[random(1, #calls)]) end
		end
		if underwater or mood == "underground" then
			stop_emitters(st)
		else
			update_emitters(name, st, pos)
		end
	end
	stats.passes = stats.passes + 1
	stats.us = stats.us + (core.get_us_time() - started)
end

local join_counter = 0
local accumulator, current_slot = 0, 0

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < R.SLOT_PERIOD then return end
	-- As atmosphere_zones.lua: subtract to keep the rate, collapse a stall.
	accumulator = accumulator - R.SLOT_PERIOD
	if accumulator > R.SLOT_PERIOD then accumulator = 0 end
	current_slot = current_slot % R.SLOTS + 1
	local now, night
	for name, st in pairs(states) do
		if st.slot == current_slot then
			if not now then
				now = now_seconds()
				night = not grug_core.is_day_phase(core.get_timeofday())
			end
			evaluate(name, st, now, night)
		end
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local now = now_seconds()
	join_counter = join_counter + 1
	local st = {slot = join_counter % R.SLOTS + 1,
		bed = {gain = 0, seen = 0}, emitters = {},
		next_call = now + R.next_call_delay(D, random)}
	read_settings(player, st)
	st.music = R.music_new(music_audible(st))
	states[name] = st
end)

core.register_on_leaveplayer(function(player)
	states[player:get_player_name()] = nil
end)

-- ---------------------------------------------------------------------------
-- Settings: one entry point for the Help page and the chat commands
-- ---------------------------------------------------------------------------

-- Sets `channel` ("music" or "ambience") for an online player: `on` and/or
-- `volume` (nil keeps the value). Stored in player meta and applied at once.
function grug_ambience.set(player, channel, on, volume)
	local name = player:get_player_name()
	local st = states[name]
	if not st then return false end
	local meta = player:get_meta()
	local key_on, key_volume = channel .. "_on", channel .. "_volume"
	local was_audible = R.audible(st[key_on], st[key_volume])
	-- Switching on a channel left at volume 0 restores the default volume,
	-- so "on" is never silent.
	if on == true and volume == nil and st[key_volume] == 0 then
		volume = R.DEFAULT_VOLUME[channel]
	end
	if on ~= nil then
		st[key_on] = on
		meta:set_int(META[channel .. "_off"], on and 0 or 1)
	end
	if volume ~= nil then
		st[key_volume] = volume
		meta:set_int(META[key_volume], volume)
	end
	local audible = R.audible(st[key_on], st[key_volume])
	if channel == "music" then
		-- Off: the track fades out and the capital's bed fades in on the next
		-- pass; on: the next pass starts the capital's rotation.
		if audible ~= was_audible then
			if R.music_set_on(st.music, audible) == "stop" then
				stop_track(st)
			end
			sync_now_playing(name, st)
		elseif audible and st.track_handle then
			local gain = music_gain(st)
			fade(st.track_handle, st.track_gain, gain, D.volume_fade)
			st.track_gain = gain
		end
	elseif not audible then
		stop_bed(st)
		stop_emitters(st)
	else
		-- Gains follow on the next pass (bed) or here (loops); a channel that
		-- was silent starts its bed on the next pass.
		for _, emitter in pairs(st.emitters) do
			local gain = emitter_gain(st, emitter.kind)
			fade(emitter.handle, emitter.gain, gain, D.volume_fade)
			emitter.gain = gain
		end
		if st.bed.handle then
			local gain = R.bed_gain(D, st.ambience_volume, location.in_town(name))
			fade(st.bed.handle, st.bed.gain, gain, D.volume_fade)
			st.bed.gain = gain
		end
	end
	return true
end

-- {on, volume} of `channel` for an online player, or nil.
function grug_ambience.get(player, channel)
	local st = states[player:get_player_name()]
	if not st then return nil end
	return {on = st[channel .. "_on"], volume = st[channel .. "_volume"]}
end

local function status_line(label, setting)
	return ("%s: %s, volume %d%%."):format(label, setting.on and "on" or "off",
		setting.volume)
end

local COMMAND_HELP = {
	music = "Music (it plays in the six capitals): switch on or off, or set the " ..
		"volume in percent (default " .. R.DEFAULT_VOLUME.music .. ")",
	ambience = "Ambience: switch on or off, or set the volume in percent",
}

for _, channel in ipairs({"music", "ambience"}) do
	local label = channel == "music" and "Music" or "Ambience"
	core.register_chatcommand(channel, {
		params = "[on|off|<0-100>]",
		description = COMMAND_HELP[channel],
		func = function(name, param)
			local player = core.get_player_by_name(name)
			if not player then return false, "Only an online player can change this." end
			local command = R.parse_command(param)
			if not command then return false, "Use /" .. channel .. " on, off or 0-100." end
			if command.on ~= nil or command.volume ~= nil then
				grug_ambience.set(player, channel, command.on, command.volume)
			end
			return true, status_line(label, grug_ambience.get(player, channel))
		end,
	})
end

-- The Help page's Sound sub-page (grug_inventory/help.lua): the controls in
-- legacy formspec coordinates from (x, y), and the field handler. Volumes
-- are a dropdown in steps of 5 % (the music default is 35 %; a scrollbar
-- would send a field on every drag step).
local VOLUME_STEP = 5
local VOLUME_STEPS = {}
for step = 0, 100 / VOLUME_STEP do
	VOLUME_STEPS[#VOLUME_STEPS + 1] = (step * VOLUME_STEP) .. " %"
end
local VOLUME_ITEMS = table.concat(VOLUME_STEPS, ",")

-- The dropdown entry showing `volume` (the nearest step).
local function volume_index(volume)
	return floor(volume / VOLUME_STEP + 0.5) + 1
end

local CONTROLS = {
	{channel = "music", label = "Music"},
	{channel = "ambience", label = "Ambience"},
}

function grug_ambience.settings_formspec(player, x, y)
	local fs = {}
	for index, row in ipairs(CONTROLS) do
		local setting = grug_ambience.get(player, row.channel) or
			{on = true, volume = R.DEFAULT_VOLUME[row.channel]}
		local top = y + (index - 1) * 0.9
		fs[#fs + 1] = ("checkbox[%.2f,%.2f;grug_ambience_%s;%s;%s]"):format(x, top + 0.2,
			row.channel, core.formspec_escape(row.label), setting.on and "true" or "false")
		fs[#fs + 1] = ("label[%.2f,%.2f;Volume]"):format(x + 2.6, top + 0.1)
		fs[#fs + 1] = ("dropdown[%.2f,%.2f;2.0;grug_ambience_%s_volume;%s;%d;true]"):format(
			x + 3.8, top, row.channel, VOLUME_ITEMS, volume_index(setting.volume))
	end
	return table.concat(fs)
end

-- Applies the Sound sub-page's fields; true when something changed. A
-- dropdown is sent with every submit of the page, so only a new entry acts
-- (a volume between two steps, set with the chat command, stays).
function grug_ambience.handle_settings_fields(player, fields)
	local changed = false
	for _, row in ipairs(CONTROLS) do
		local channel = row.channel
		local setting = grug_ambience.get(player, channel)
		if setting then
			local box = fields["grug_ambience_" .. channel]
			if box == "true" or box == "false" then
				grug_ambience.set(player, channel, box == "true", nil)
				changed = true
			end
			local index = tonumber(fields["grug_ambience_" .. channel .. "_volume"])
			if index and index >= 1 and index <= #VOLUME_STEPS and
					index ~= volume_index(setting.volume) then
				grug_ambience.set(player, channel, nil, (index - 1) * VOLUME_STEP)
				changed = true
			end
		end
	end
	return changed
end
