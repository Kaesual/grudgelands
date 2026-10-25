-- Ambience and music per player (Round 34 lane S2; round34-plan.md §2.1
-- rulings 3-6, §4.2). Why: the game was silent outside a few node sounds.
--
--   * quiet looped beds to the player only, in three layers since Round 52
--     (round52-ambience-plan.md): the SURFACE bed by the sound group of the
--     biome under the player (or a zone override by the atmosphere mood the
--     player carries: the Battlegrounds, the dragon islands, the open
--     ocean), a night bed after dusk where one fits; the SEA layer (0.52.1),
--     the surf, which takes over the surface level at the coast by the
--     share of sea columns round the player (the map's water query, so a
--     lake never plays it); the CAVE bed in real caves (a sampled open-air
--     probe tells a cave from a dug tunnel) and its deep variant; the WIND
--     at height and on high peaks. Their levels follow the height relative
--     to the terrain (grug_core.depth_below_surface); in start towns and
--     capitals every layer plays at half gain. A bed change crossfades
--     (core.sound_fade). Where music plays (Round 35) every layer is
--     silent; under water only the surface layer's underwater bed plays.
--     A start town sounds like it looks (0.52.1): its key is the group of
--     the biome its ground is (data.town_looks), not of the cell under it;
--   * sparse calls by sound key and time of day, a per-player timer, placed
--     at a point around the player (distant thunder on the dragon islands);
--   * loops at hearths and camp fires and flowing water (never at a water
--     source) near the player: one find_nodes_in_area per pass out of water,
--     the nearest two of each kind, positional, to that player only (Round
--     45 PT8: none at forges and anvils). Round 47: both burning furnaces
--     are their own, quieter kind, and a dug or destroyed one stops at once
--     for every listener (its on_destruct, stop_emitters_at);
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
-- Round 34 (round34-plan.md §2.2a): no stream bed (0.52.1: an underwater
-- pool); data.lua holds every name, so another bed is data only.
--
-- Cost: one pass per player every 2 s, spread over eight slots of 0.25 s
-- (AGENTS.md Round 32): a mood and town lookup, the depth below the surface
-- (from the player's column memo in grug_core, a zone query only on a new
-- node column), one get_node_raw read for under water (33 while a stream
-- bed exists), the sea share where the surface layer is audible (50 table
-- lookups in a memo shared by every player; a water query only for a
-- column never asked before), 75 more reads for the cave probe only deeper
-- than 4 nodes and only after a move of 2 nodes or every third pass, one
-- find_nodes_in_area out of water, a few sound packets when something
-- changes. grug_ambience.stats and grug_core.depth_stats hold comparison
-- figures for the reports (tools/r52_amb probe). `/ambience debug` shows a
-- player their own state in one HUD line.
--
-- A /atmosphere preset (atmosphere.lua, admin A/B test) pauses the zone
-- driver: a forced Battlegrounds, dragon-island or ocean mood overrides the
-- biome group like the zone would; any other preset leaves the biome group
-- in charge (since Round 52 a forced `underground` no longer drives the
-- beds: the depth does; /ambience debug shows it).
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
-- Round 52: the cave probes and their microseconds. 0.52.1: the sea shares,
-- their microseconds and the water queries they asked (memo misses).
local stats = {passes = 0, us = 0, finds = 0, find_us = 0, found = 0, plays = 0,
	pushes = 0, probes = 0, probe_us = 0, seas = 0, sea_us = 0, sea_queries = 0}
grug_ambience.stats = stats

local function now_seconds()
	return core.get_us_time() / 1000000
end

-- ---------------------------------------------------------------------------
-- Player state and settings
-- ---------------------------------------------------------------------------

-- name -> {slot, music_on, music_volume, ambience_on, ambience_volume,
-- layers = {surface, sea, cave, wind} (each a rules layer state plus handle
-- and gain; the surface one also {want, seen, underwater, music}),
-- sound_key (the group or override last known), cave = {cave, want, seen,
-- share, px, py, pz, age}, deep (the cave layer plays the deep bed),
-- emitters = {[hash] = {handle, gain, kind}}, next_call, music = rules
-- music state, track_handle, track_gain, shown_track (the track the
-- minimap's box names), debug = {id, text} while /ambience debug is on}
local states = {}
local LAYERS = {"surface", "sea", "cave", "wind"}

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

-- The layers' sounds. A layer keeps its handle and the gain last sent
-- (fade() computes the step from it); rules.lua layer_step decides.
local function new_layer()
	return {playing = false, level = 0, base = 0, idle = 0, seen = 0, gain = 0}
end

local function apply_layer(name, layer, action)
	if not action then return end
	local gain = layer.level * layer.base
	if action == "fade" then
		fade(layer.handle, layer.gain, gain, D.layer_fade)
		layer.gain = gain
		return
	end
	-- A sound faded to 0 is deleted by the engine: its handle is dropped.
	if layer.handle then fade(layer.handle, layer.gain, 0, D.crossfade) end
	layer.handle, layer.gain, layer.sound = nil, 0, nil
	if action == "start" or action == "switch" then
		local sound = R.bed_sound(D, layer.key, available, random)
		layer.handle = core.sound_play({name = sound, gain = gain},
			{to_player = name, loop = true, fade = gain / D.crossfade}, false)
		-- The file of a pool that plays (the debug line names it).
		layer.gain, layer.sound = gain, sound
		stats.plays = stats.plays + 1
	end
end

-- Silences every layer at once (ambience switched off); the next pass with
-- ambience on starts the beds afresh.
local function stop_layers(st)
	for _, id in ipairs(LAYERS) do
		local layer = st.layers[id]
		if layer.handle then fade(layer.handle, layer.gain, 0, D.crossfade) end
		st.layers[id] = new_layer()
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

-- Fades out every listener's loop at `pos` over D.stop_fade (Round 47
-- ruling 16). The on_destruct of a `stop_on_destruct` kind's node calls it
-- (hooked below), so a dug or blown-up furnace falls silent at once rather
-- than on the next pass: one table lookup per online player, on that node
-- event only. A furnace that goes out (swap_node, no on_destruct) still
-- fades on the next pass.
local function stop_emitters_at(pos)
	local hash = core.hash_node_position(pos)
	for _, st in pairs(states) do
		local emitter = st.emitters[hash]
		if emitter then
			fade(emitter.handle, emitter.gain, 0, D.stop_fade)
			st.emitters[hash] = nil
		end
	end
end
grug_ambience.stop_emitters_at = stop_emitters_at

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
	-- on_destruct runs on every removal (a dig, an explosion's on_blast, a
	-- set_node over it), never on swap_node; the node's own one still runs.
	for node, kind in pairs(D.emitter_nodes) do
		local def = core.registered_nodes[node]
		if def and D.emitters[kind] and D.emitters[kind].stop_on_destruct then
			local previous = def.on_destruct
			core.override_item(node, {on_destruct = function(pos)
				stop_emitters_at(pos)
				if previous then return previous(pos) end
			end})
		end
	end
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
-- lakes, r7_content.lua), filled once every node is registered. Only the
-- eye's node and the stream reads use it: default water is also the water
-- of authored lakes and swamp pools, so since 0.52.1 the sea near the
-- player comes from the map (sea_share below), never from a node.
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
-- water still hears it. Three river reads of the 32 make the stream bed.
-- Read only when a stream bed exists (none ships).
local RING = {}
for _, radius in ipairs({3, 7}) do
	for step = 0, 7 do
		local angle = step * math.pi / 4
		RING[#RING + 1] = {floor(math.cos(angle) * radius + 0.5),
			floor(math.sin(angle) * radius + 0.5)}
	end
end
local STREAM_READS = 3
local STREAM_BED = D.beds.stream ~= nil
local EYE_HEIGHT = 1.625
local get_node_raw = core.get_node_raw

-- Returns the water near the player ("stream" or nil) and whether the eye
-- is under water (any water: the sea, a lake, a river).
local function probe_water(pos)
	local x, y, z = floor(pos.x + 0.5), floor(pos.y + 0.5), floor(pos.z + 0.5)
	if water_kind[get_node_raw(x, floor(pos.y + EYE_HEIGHT + 0.5), z)] then
		return nil, true
	end
	if not STREAM_BED then return nil, false end
	local stream = 0
	for index = 1, #RING do
		local offset = RING[index]
		for dy = -2, -1 do
			if water_kind[get_node_raw(x + offset[1], y + dy, z + offset[2])] == "stream" then
				stream = stream + 1
			end
		end
	end
	if stream >= STREAM_READS then return "stream", false end
	return nil, false
end

-- ---------------------------------------------------------------------------
-- Sea share (0.52.1, round52-ambience-plan.md §8)
-- ---------------------------------------------------------------------------

-- grug_zones is installed by grug_mapgen after every CORE file has loaded
-- (grug_core/zone_authority.lua), so it is looked up on first use, like
-- atmosphere_zones.lua does.
local zones_api
local function zone_api()
	if zones_api then return zones_api end
	local installed = grug_core.zone_authority_installed
	if not (installed and installed()) then return nil end
	zones_api = rawget(_G, "grug_zones")
	return zones_api
end

-- Two memos shared by every player, since the world's layout is fixed for
-- the life of the server and an entry never goes stale: node column ->
-- whether it is sea (R.SEA_CLASSES), and grid point -> the share round it.
-- A water query costs some 7-10 us on a column never asked and below 1 us
-- again (engine.sh coast, seed 12345); a pass whose grid point is known
-- (standing, or ground walked before) costs two lookups. Both are emptied
-- at SEA_MEMO_MAX entries together (a few MB at most).
local SEA_MEMO_MAX = 65536
local sea_memo, share_memo, sea_memo_count = {}, {}, 0
local SEA_CLASSES = R.SEA_CLASSES

-- An exact number key per node column: |x|, |z| stay far below 2^24.
local function column_key(x, z)
	return (x + 16777216) * 33554432 + (z + 16777216)
end

-- Counts one new entry, emptying both memos first when they are full.
local function memo_room()
	if sea_memo_count >= SEA_MEMO_MAX then sea_memo, share_memo, sea_memo_count = {}, {}, 0 end
	sea_memo_count = sea_memo_count + 1
end

local function sea_column(zones, x, z)
	local key = column_key(x, z)
	local sea = sea_memo[key]
	if sea == nil then
		sea = SEA_CLASSES[zones.water_query_at(x, z) or ""] == true
		stats.sea_queries = stats.sea_queries + 1
		memo_room()
		sea_memo[key] = sea
	end
	return sea
end

local SEA_POINTS = R.sea_points(D)
local SEA_STEP = D.sea.step

-- The share of sea columns among the samples round `pos` (on a grid of
-- D.sea.step nodes, so every player near one grid point shares it) and
-- whether the player's own column is sea; nil while no zone authority
-- exists.
local function sea_share(pos)
	local zones = zone_api()
	if not zones then return nil end
	local started = core.get_us_time()
	local gx, gz = floor(pos.x / SEA_STEP + 0.5) * SEA_STEP, floor(pos.z / SEA_STEP + 0.5) * SEA_STEP
	local key = column_key(gx, gz)
	local share = share_memo[key]
	if not share then
		local sea = 0
		for index = 1, #SEA_POINTS do
			local point = SEA_POINTS[index]
			if sea_column(zones, gx + point[1], gz + point[2]) then sea = sea + 1 end
		end
		share = sea / #SEA_POINTS
		memo_room()
		share_memo[key] = share
	end
	local on_sea = sea_column(zones, floor(pos.x + 0.5), floor(pos.z + 0.5))
	stats.seas = stats.seas + 1
	stats.sea_us = stats.sea_us + (core.get_us_time() - started)
	return share, on_sea
end
grug_ambience.sea_share = sea_share

-- ---------------------------------------------------------------------------
-- Cave probe (Round 52 ruling 6, round52-ambience-plan.md §3.2 step 6)
-- ---------------------------------------------------------------------------

-- Content id -> true for open air: a node a player walks through that is no
-- liquid (air, plants, torches ...), filled once every node is registered.
-- `ignore` (an unloaded node) is solid.
local open_air = {}
core.register_on_mods_loaded(function()
	for node, def in pairs(core.registered_nodes) do
		if node ~= "ignore" and def.walkable == false and
				(def.liquidtype or "none") == "none" then
			open_air[core.get_content_id(node)] = true
		end
	end
end)

local GRID_XZ, GRID_Y = D.cave.grid_xz, D.cave.grid_y
local GRID_COUNT = #GRID_XZ * #GRID_XZ * #GRID_Y

-- The share of open air on the probe's grid round the player's feet: a few
-- dozen get_node_raw reads, no allocation. A real cave is wide and high
-- open space; a dug tunnel holds only a line or two of the grid.
local function cave_share(pos)
	local x0, y0, z0 = floor(pos.x + 0.5), floor(pos.y + 0.5), floor(pos.z + 0.5)
	local open = 0
	for iy = 1, #GRID_Y do
		local y = y0 + GRID_Y[iy]
		for ix = 1, #GRID_XZ do
			local x = x0 + GRID_XZ[ix]
			for iz = 1, #GRID_XZ do
				if open_air[get_node_raw(x, y, z0 + GRID_XZ[iz])] then open = open + 1 end
			end
		end
	end
	return open / GRID_COUNT
end
grug_ambience.cave_share = cave_share

-- This pass's cave verdict (the probe only deeper than D.cave.min_depth,
-- its share reused while the player stays near the last probe; nearer the
-- surface the verdict resets, and the cave layer is silent there anyway).
local function cave_pass(st, pos, depth)
	local c = st.cave
	if not depth or depth <= D.cave.min_depth then
		c.cave, c.want, c.seen, c.share, c.px = false, nil, 0, nil, nil
		return false
	end
	if R.probe_due(c, pos) then
		local started = core.get_us_time()
		c.share = cave_share(pos)
		stats.probes = stats.probes + 1
		stats.probe_us = stats.probe_us + (core.get_us_time() - started)
	end
	return R.cave_step(c, c.share, D.cave.threshold)
end

-- ---------------------------------------------------------------------------
-- Debug line (/ambience debug, §3.2 step 9)
-- ---------------------------------------------------------------------------

-- One small HUD text line, top left, for the player who switched it on: the
-- biome, the sound group, the depth, the cave share and verdict, the sea
-- share ("on" on a sea column, "-" where it is not asked) and the four
-- layers' levels (`levels`: surface, sea, cave, wind; "surface" is the
-- region bed's, or the underwater bed's while diving), and the file the
-- surface layer plays (0.52.1: which of a pool, e.g. the two underwater
-- beds). The biome is the start town's look there, marked "(town)". Sent
-- only when the shown text changed.
-- Sends `text` when it differs from the line shown.
local function set_debug_text(player, st, text)
	if text ~= st.debug.text then
		st.debug.text = text
		player:hud_change(st.debug.id, "text", text)
	end
end

-- The line while the ambience is off or at volume 0 (no pass runs then).
local DEBUG_OFF = "ambience: off"

local function percent(value) return floor(value * 100 + 0.5) end

local function show_debug(player, st, biome, look, depth, share, on_sea, levels)
	local c = st.cave
	local bed = st.layers.surface.sound
	local text = ("ambience: %s%s / %s | bed %s | depth %s | cave %s %s | sea share %s | " ..
		"surface %d%% sea %d%% cave %d%% wind %d%%"):format(
		biome and biome:gsub("^grug_", "") or "-", look and " (town)" or "",
		tostring(st.sound_key or "-"), bed and bed:gsub("^grug_ambience_", "") or "-",
		depth and ("%.1f"):format(depth) or "-",
		c.share and ("%d%%"):format(percent(c.share)) or "-",
		c.cave and "cave" or "no",
		on_sea and "on" or share and ("%d%%"):format(percent(share)) or "-",
		percent(levels[1]), percent(levels[2]), percent(levels[3]), percent(levels[4]))
	set_debug_text(player, st, text)
end

local function set_debug(player, st, on)
	if on and not st.debug then
		st.debug = {text = "ambience: (next pass)"}
		st.debug.id = player:hud_add({type = "text", position = {x = 0, y = 0.3},
			offset = {x = 8, y = 0}, alignment = {x = 1, y = 1}, number = 0xFFFFFF,
			style = 4, text = st.debug.text, z_index = 100})
	elseif not on and st.debug then
		player:hud_remove(st.debug.id)
		st.debug = nil
	end
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

local scratch, call_state, levels = {}, {}, {}

-- The start towns' anchors {race, x, z} (rules.lua start_town_look),
-- read once from the settlement registry, which grug_mapgen fills at load.
local start_towns

-- The biome the start town round `pos` looks like, or nil: only inside a
-- town (grug_map's location, sampled every second) that is no capital.
local function town_look(name, pos, town)
	if not town or location.capital_of(name) then return nil end
	if not start_towns then
		local list = {}
		local rows = grug_core.settlement_socket_settlements and
			grug_core.settlement_socket_settlements() or {}
		for _, row in ipairs(rows) do
			if row.slot == "start" and D.town_looks[row.race_id] then
				list[#list + 1] = {race = row.race_id, x = row.anchor.x, z = row.anchor.z}
			end
		end
		if #list == 0 then return nil end
		start_towns = list
	end
	return R.start_town_look(D, start_towns, pos.x, pos.z)
end

-- The sea, cave and wind layers' beds: the surf, the deep cave bed below
-- D.deep_y (else the cave bed), the wind; false when none ships.
local SEA_KEYS, CAVE_KEYS, DEEP_CAVE_KEYS, WIND_KEYS = {"sea"}, {"cave"}, {"cave_deep", "cave"}, {"wind"}

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
		local depth, column
		if grug_core.depth_below_surface then
			depth, column = grug_core.depth_below_surface(pos, name)
		end
		-- A start town sounds like it looks, not like the cell under it.
		local look = town_look(name, pos, town)
		local biome = look or (column and column.biome)
		local key = R.sound_key(D, mood, column ~= nil or look ~= nil, biome, st.sound_key)
		if key ~= nil then st.sound_key = key end
		local water, underwater = probe_water(pos)
		local music = R.music_active(st.music)
		local cave = cave_pass(st, pos, depth)
		local surface_level, wind_level, cave_level = R.layer_levels(D, depth, pos.y, cave)
		local base = R.bed_gain(D, st.ambience_volume, town)
		-- The sea share: only where the surf can be heard and blends.
		local quiet = underwater or music
		local mode, share, on_sea = R.surf_mode(D, st.sound_key), nil, nil
		if not quiet and mode == "blend" and surface_level > 0 then
			share, on_sea = sea_share(pos)
		end
		local region_level, sea_level = R.surface_levels(surface_level,
			R.sea_blend(D, mode, share, on_sea), underwater)
		-- The surface bed: the sound key's bed, the underwater bed while
		-- diving; the beds' hysteresis; music and diving switch at once.
		scratch.key, scratch.night, scratch.water = st.sound_key, night, water
		scratch.underwater = underwater
		local layers = st.layers
		local surface = layers.surface
		local wanted = R.bed_wanted(R.pick_bed(D, R.bed_keys(D, scratch), available), music)
		local surface_key = surface.key
		if wanted ~= nil and R.bed_should_change(surface, wanted, underwater, music,
				not surface.playing) then
			surface_key = wanted
		end
		apply_layer(name, surface, R.layer_step(surface, surface_key, region_level, base))
		-- The sea, the cave and the wind: silent under water and where music
		-- plays.
		local sea_key = not quiet and R.pick_bed(D, SEA_KEYS, available)
		apply_layer(name, layers.sea, R.layer_step(layers.sea, sea_key, sea_level, base))
		st.deep = R.deep_cave(D, st.deep, pos.y)
		local cave_key = not quiet and R.pick_bed(D, st.deep and DEEP_CAVE_KEYS or CAVE_KEYS, available)
		apply_layer(name, layers.cave, R.layer_step(layers.cave, cave_key, cave_level, base))
		local wind_key = not quiet and R.pick_bed(D, WIND_KEYS, available)
		apply_layer(name, layers.wind, R.layer_step(layers.wind, wind_key, wind_level, base))
		if now >= st.next_call then
			st.next_call = now + R.next_call_delay(D, random)
			call_state.key, call_state.biome, call_state.night = st.sound_key, biome, night
			call_state.underwater, call_state.underground = underwater, mood == "underground"
			-- The region bed's level: no owl over the sea.
			call_state.surface = region_level
			local calls = R.eligible_calls(D, call_state, available)
			if #calls > 0 then play_call(name, st, pos, calls[random(1, #calls)]) end
		end
		-- Since Round 52 the loops play underground as well (a burning
		-- furnace in a mine is heard); only under water they stop.
		if underwater then
			stop_emitters(st)
		else
			update_emitters(name, st, pos)
		end
		if st.debug then
			levels[1], levels[2], levels[3], levels[4] = region_level, sea_level, cave_level, wind_level
			show_debug(player, st, biome, look, depth, share, on_sea, levels)
		end
	elseif st.debug then
		set_debug_text(player, st, DEBUG_OFF)
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
		layers = {surface = new_layer(), sea = new_layer(), cave = new_layer(), wind = new_layer()},
		cave = {seen = 0, age = 0}, emitters = {},
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
		stop_layers(st)
		stop_emitters(st)
	else
		-- Gains follow here; a channel that was silent starts its beds on
		-- the next pass.
		for _, emitter in pairs(st.emitters) do
			local gain = emitter_gain(st, emitter.kind)
			fade(emitter.handle, emitter.gain, gain, D.volume_fade)
			emitter.gain = gain
		end
		local base = R.bed_gain(D, st.ambience_volume, location.in_town(name))
		for _, id in ipairs(LAYERS) do
			local layer = st.layers[id]
			if layer.handle then
				local gain = layer.level * base
				fade(layer.handle, layer.gain, gain, D.volume_fade)
				layer.base, layer.gain = base, gain
			end
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
	ambience = "Ambience: switch on or off, set the volume in percent, or " ..
		"toggle a debug line (biome, depth, cave, sea share, layer levels)",
}
local COMMAND_PARAMS = {music = "[on|off|<0-100>]", ambience = "[on|off|<0-100>|debug]"}

for _, channel in ipairs({"music", "ambience"}) do
	local label = channel == "music" and "Music" or "Ambience"
	core.register_chatcommand(channel, {
		params = COMMAND_PARAMS[channel],
		description = COMMAND_HELP[channel],
		func = function(name, param)
			local player = core.get_player_by_name(name)
			if not player then return false, "Only an online player can change this." end
			local command = R.parse_command(param)
			if command and command.debug and channel == "ambience" then
				local st = states[name]
				if not st then return false, "Only an online player can change this." end
				set_debug(player, st, not st.debug)
				return true, "Ambience debug line " .. (st.debug and "on." or "off.")
			end
			if not command or command.debug then
				return false, "Use /" .. channel .. " on, off or 0-100."
			end
			if command.on ~= nil or command.volume ~= nil then
				grug_ambience.set(player, channel, command.on, command.volume)
			end
			return true, status_line(label, grug_ambience.get(player, channel))
		end,
	})
end

-- The Help page's Sound sub-page (grug_inventory/help.lua): the controls in
-- real formspec coordinates from (x, y), and the field handler. Volumes
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
		fs[#fs + 1] = ("checkbox[%.2f,%.2f;grug_ambience_%s;%s;%s]"):format(x, top + 0.325,
			row.channel, core.formspec_escape(row.label), setting.on and "true" or "false")
		fs[#fs + 1] = ("label[%.2f,%.2f;Volume]"):format(x + 2.6, top + 0.325)
		fs[#fs + 1] = ("dropdown[%.2f,%.2f;2.4,0.65;grug_ambience_%s_volume;%s;%d;true]"):format(
			x + 4.2, top, row.channel, VOLUME_ITEMS, volume_index(setting.volume))
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
