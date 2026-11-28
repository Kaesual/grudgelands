-- Our own minimap (Round 27, WP50; docs/design/world_map.md). It replaces
-- Luanti's native minimap: a round, north-up HUD window of about 440 nodes
-- of the pre-rendered world map, top right in the native minimap's box
-- (grug_core.hud_layout.minimap_box), with the player's arrow, party
-- members (rim arrows when outside), quest givers with their state, the
-- Housing Steward and the capital services, trainers (their profession's
-- icon since Round 44), innkeepers, the player's home and discovered
-- waystones (Round 29). Settlements, points of interest, kings and dragons
-- use the same separate markers as the world map (Round 64; sized by the
-- drawn minimap since Round 66, marker_px below; since Round 67 at their
-- anchors, never displaced, stacked by importance, markers.rank). Under it a line names the player's location (Round 28 M1,
-- location.lua), and while a capital's music plays a "Now playing" box under
-- that line names the track (0.45.1; grug_ambience tells it which).
--
-- Side elements (Round 48 lane HUD): the mail icon with its unread count
-- (grug_mail calls M.set_mail_count) and the daytime band stand in one row
-- left of the bezel, top-aligned with it (follow-up lane HUD2), the
-- announcements icon with its own count under the mail icon, or in its
-- place while no letter is unread (Round 84). With the
-- minimap hidden or unavailable the row stays right-aligned in the top-right
-- corner of the minimap's box, with "Now playing" below it (ruling 2.1 of
-- the round plan). They are separate from the minimap's own
-- elements: created at the first step, never removed while the player is
-- online, placed again when the window or the mode changes (geometry:
-- minimap_view.lua side_layout). The band is checked on the SLOW tick and
-- sends one hud_change when its position (one per 30 real seconds)
-- changes; the globalstep runs this part also when the minimap is
-- unavailable.
--
-- Glide (test variant for the playtest): the arrow stays in the centre and
-- the map moves under it pixel by pixel. The map is ONE
-- image element whose texture is the player's grid cell (ruling 9: the
-- client builds a new texture only on entering a new cell); the element is
-- moved so the player's own pixel lies at the centre, and an opaque bezel
-- covers what overhangs the round hole (HUD images are never clipped).
-- Geometry, and why a cell swap moves no pixel: minimap_view.lua. Markers
-- are separate elements that move with the map. hud_change sends a packet
-- on every call, so every element keeps what was last sent and only
-- differences (whole screen pixels) are sent.
--
-- Claim mode (fix 0.50.2; by map chunks since Round 86 lane PREVIEW;
-- docs/design/housing.md §2 "Placement preview"): while a player with a
-- faction holds a Claim Stone (any of grug_housing.STONE_ITEMS), the cell
-- texture shows the chunk grid: every chunk on it that placement refuses
-- for the chunk's own sake (grug_housing.chunk_refusal: the claim mask, a
-- claim already there, the quota, in validate's order; every chunk without
-- a mask) filled red, a faint line on every chunk edge, the claims framed
-- as outside claim mode, and the chunk the player stands in framed green,
-- green inside too when it is free. A line left of the bezel, on a dark box
-- (minimap_view.lua hint_box), says what the player's chunk is: free, or
-- why not (grug_housing.claim_hint). The
-- texture and the line are built again on a cell change, a mode change, a
-- change of the claim set (grug_housing.claim_set_version) or of the
-- player's chunk, and sent only when their strings differ: no work per
-- step beyond the chunk of the position. A switched-off minimap appears for
-- claim mode and goes after it. A chunk the preview leaves clear can still
-- refuse a stone for the spot or the player (the chunk's edge, the arrival
-- cube, depth, a stone already placed); validate's line says so.
--
-- Claims outside claim mode (fix 0.50.2 lane HOME, ruling H4): the cell
-- texture frames the player's own claim in the square's green and every
-- other claim in yellow, one base pixel wide and without fill, drafts and
-- expired claims included (minimap_view.lua claim_frame). The texture is
-- built again on a cell change or a claim-set version change and sent only
-- when its string differs; with no claim near it is the plain map's.
--
-- Flight mode (fix 0.53.1 ruling 2; docs/design/mounts.md §4): while a
-- player with a faction sits on a flying mount (grug_mounts.is_flying), the
-- cell texture also holds the faction's red no-fly overlay (base.lua
-- flight_overlay, the dismount's own rule), under any claim layer. The
-- texture is built again when the mode changes (mounting, dismounting, a
-- ground mount for a flyer), within the step's cheap test, never by a
-- globalstep of its own. A switched-off minimap stays off.
--
-- Every server step only the cheap test runs (Round 37, audit CORE-04): the
-- map and its markers are placed again only when the map moved by a whole
-- screen pixel, the cell, the texture, the markers or the window changed;
-- the party arrows only then or when a member moved or turned to another of
-- the 16 heading frames. A player standing still with a still party costs
-- one position read, one wield-index read, one read of the claim set's
-- version and one mount-table read per step (in claim mode also the chunk
-- of the position, two divisions); the held item's name is read only when
-- the wield index changes and every WINDOW seconds (Round 81,
-- wielded_name).

local atlas = grug_map.atlas
local markers = grug_map.markers or dofile(core.get_modpath("grug_map") .. "/markers.lua")
local layout = grug_core.hud_layout
local V = dofile(core.get_modpath(core.get_current_modname()) .. "/minimap_view.lua")
local M = {view = V}
grug_map.minimap = M

-- Ruling 10: a per-player switch on the Map tab, stored in player meta, on
-- by default.
local META = "grug_map:minimap_hidden"
-- The map, markers and party members are checked every server step. The static
-- markers are asked from their providers when the quest markers change
-- (grug_quests.markers_changed: a quest change, held objective items, a
-- level), on joining, and when the SLOW check (every SLOW seconds, each
-- player in its own phase) finds their key changed: the quest markers'
-- version, the home, the discovered waystones or the faction (Round 37);
-- the ones near the window are picked on each new cell.
local SLOW = 5.0
-- The window size and the location line are read again every WINDOW
-- seconds, not every step (Round 30, perf review #12): a resize relayouts
-- and a new location shows within that time (the client itself reports a
-- resize 0.2 s after it ends; the location is sampled about once a second).
local WINDOW = 0.5
local PARTY_SLOTS = 9
-- The arrows' drawn size in HUD pixels at the reference (scaled with HUD
-- scaling like every HUD image; markers.ARROW, the markers' markers.SIZE);
-- the markers and arrows inside the hole at most, see marker_px.
local PARTY_ARROW, PLAYER_ARROW = markers.ARROW, markers.ARROW
-- A rim arrow fills RIM_FILL of the bezel ring's width; its chevron spans
-- RIM_EXTENT of its 32 px texture from tip to back, outline included.
local RIM_FILL, RIM_EXTENT = 0.85, 21 / 32
local BEZEL = "grug_map_minimap_bezel.png"
local BEZEL_PX = 256
-- Every fixed place and own-faction service is now a separate marker.
-- The pool grows to the visible roster; all slots stay below the bezel.
local Z = {background = 10, map = 11, marker = 20, bezel = 45, party = 50,
	player = 60}
-- Claim mode's colours (the plan's starting values, the user tunes them):
-- refused chunks in the old overlay's red (base.lua CLAIM_RED, about 45 %
-- opaque; set by M.install), the grid's lines black at about 27 % (the
-- short colour form keeps the texture string short), the
-- player's chunk in the old square's green, its fill about 30 % opaque,
-- its frame 80 %. The line beside the bezel: a free chunk in that green
-- lightened, a refused one in that red lightened, on a box of the "Now
-- playing" box's grey (fix round 1), about 58 % opaque (fix round 2: at 30 %
-- the red stayed weak over white cloud); HINT_GAP HUD px from the bezel.
local SQUARE_FILL, SQUARE_EDGE = "#40d04a4d", "#40d04acc"
local GRID = "#0004"
local HINT_FREE, HINT_REFUSED, HINT_GAP = 0x8fe596, 0xff9c8c, 6
local HINT_BOX = "#34343494"
-- The claims' frames outside claim mode (lane HOME's starting values, the
-- user tunes them): the own claim in the square's frame green, the others
-- in a yellow.
local OWN_FRAME, OTHER_FRAME = SQUARE_EDGE, "#f0d040cc"
-- The location line (Round 28 M1, location.lua): centred under the bezel,
-- LOCATION_GAP HUD px below it, in its territory status's colour (Round 32,
-- location.lua), else the feed's calm notice colour.
local LOCATION_GAP, LOCATION_COLOR = 4, 0xf0e6c8
-- The "Now playing" box (0.45.1, geometry in minimap_view.lua
-- now_playing_box): the inventory window's background (default's
-- gui_formbg.png, #343434) at 30 % alpha, the note icon (the user's pick,
-- 24 px art), the text in the location line's calm colour.
local PLAYING_BOX_COLOR = "#3434344d"
local PLAYING_ICON = "grug_ambience_note.png"

local base, view -- set by M.install

-- Round 66 ruling 5: the markers and the arrows inside the hole keep the
-- share of the hole they have on a 1920x1080 desktop at HUD scale 1 (21 px
-- there since Round 67, the arrows 32), never above that x HUD scaling,
-- never below markers.MIN. The box is
-- a quarter of the window's height in real pixels whatever the HUD scaling
-- (hud_layout.minimap_box), so HUD-scaled markers alone outgrow it on a
-- high-density screen. Kept on the frame (a new one per window change).
local REFERENCE_WINDOW = {size = {x = 1920, y = 1080}, real_hud_scaling = 1,
	real_gui_scaling = 1}
local reference_hole -- for `view`, reset by M.install
local function marker_px(frame)
	if not frame.marker then
		reference_hole = reference_hole or V.frame(view, layout.minimap_box(REFERENCE_WINDOW)).hole
		frame.marker = markers.fit(markers.metrics({real_hud_scaling = frame.hud}),
			frame.hole, reference_hole)
	end
	return frame.marker
end
M.marker_px = marker_px
-- The claims (set by M.install when grug_housing is there); claim mode
-- needs its chunk preview (chunk_refusal, Round 86): `ORIGIN` the first
-- node of chunk 0, `CHUNK` its side. Every Claim Stone item turns claim mode
-- on (grug_housing.is_stone_item, Round 86).
local housing, ORIGIN, CHUNK
local claim_ready, CLAIM_RED
-- The no-fly overlays' tiles by faction (set by M.install when base.lua
-- rendered them).
local flight_tiles
local players = {}
-- Unread letters and unread announcements per online player
-- (M.set_mail_count), kept apart from the minimap state so a count told
-- before this mod's join callback is kept.
local mail_counts, announce_counts = {}, {}
-- Positions read once per server step (`step`), shared by every party
-- member's minimap: name -> {step, player, x, z, frame}; the heading frame
-- is read only when a party arrow needs it.
local where, step = {}, 0
local function locate(name, player)
	local row = where[name]
	if row and row.step == step then return row end
	player = player or core.get_player_by_name(name)
	if not player then return nil end
	local at = player:get_pos()
	row = row or {}
	where[name] = row
	row.step, row.player, row.x, row.z, row.frame = step, player, at.x, at.z, nil
	return row
end
local function heading(row)
	if not row.frame then row.frame = atlas.heading_frame(row.player:get_look_horizontal()) end
	return row.frame
end
-- `bytes` estimates what the hud_changes cost on the wire: a reliable
-- TOCLIENT_HUDCHANGE is about 18 bytes of headers plus its value. `drawn`
-- counts the updates that placed the map and markers again, `party` those
-- that placed the party arrows again.
M.stats = {updates = 0, us = 0, changes = 0, bytes = 0, textures = 0, drawn = 0, party = 0}
local function sent(bytes)
	M.stats.bytes = M.stats.bytes + 18 + bytes
	return 1
end

-- Texture sizes, read once from the PNG header of the owning mod's file
-- (every texture here is named after its mod). 16 if not found.
local sizes = {}
local modnames
local function texture_size(name)
	local known = sizes[name]
	if known then return known end
	modnames = modnames or core.get_modnames()
	local size = 16
	for _, mod in ipairs(modnames) do
		if name:sub(1, #mod + 1) == mod .. "_" then
			local file = io.open(core.get_modpath(mod) .. "/textures/" .. name, "rb")
			if file then
				local header = file:read(24)
				file:close()
				if header and #header == 24 and header:sub(13, 16) == "IHDR" then
					local a, b, c, d = header:byte(17, 20)
					size = ((a * 256 + b) * 256 + c) * 256 + d
				end
				break
			end
		end
	end
	sizes[name] = size
	return size
end

function M.enabled(player)
	return player:get_meta():get_string(META) ~= "1"
end

-- One HUD image element: what was last sent, so only changes are sent.
-- `corner` elements are placed by their top-left pixel, the others by
-- their centre.
local function image(player, z, corner)
	local align = corner and 1 or 0
	return {id = player:hud_add({type = "image", position = {x = 0, y = 0},
		alignment = {x = align, y = align}, scale = {x = 1, y = 1}, text = "",
		z_index = z}), text = "", x = 0, y = 0, scale = 1}
end

-- Shows `text` at screen pixel x/y (fractional is rounded) with `scale`;
-- "" hides the element. Positions are fractions of the window: the client
-- rounds position x width to the pixel (hud.cpp), offsets would be scaled.
local function show(player, frame, element, text, x, y, scale)
	local changes = 0
	if text == "" then
		if element.text ~= "" then
			player:hud_change(element.id, "text", "")
			element.text, changes = "", sent(2)
		end
		return changes
	end
	x, y = math.floor(x + 0.5), math.floor(y + 0.5)
	if element.x ~= x or element.y ~= y then
		player:hud_change(element.id, "position", {x = x / frame.width, y = y / frame.height})
		element.x, element.y, changes = x, y, changes + sent(8)
	end
	if element.scale ~= scale then
		player:hud_change(element.id, "scale", {x = scale, y = scale})
		element.scale, changes = scale, changes + sent(8)
	end
	if element.text ~= text then
		player:hud_change(element.id, "text", text)
		element.text, changes = text, changes + sent(2 + #text)
	end
	return changes
end

-- The scale that draws a `texture_px` texture exactly `px` screen pixels
-- wide: the client truncates texture_px x scale x HUD factor, so a quarter
-- pixel more keeps the whole pixel (minimap_view.lua side_layout counts
-- on it for the drawn heights).
local function exact(px, texture_px, frame)
	return (px + 0.25) / (texture_px * frame.hud)
end

-- The location line: a text element placed by its top centre at screen
-- pixel x/y in `color`; "" hides it. Like show(), only changes are sent.
local function show_text(player, frame, element, text, color, x, y)
	local changes = 0
	if text ~= "" then
		x, y = math.floor(x + 0.5), math.floor(y + 0.5)
		if element.x ~= x or element.y ~= y then
			player:hud_change(element.id, "position", {x = x / frame.width, y = y / frame.height})
			element.x, element.y, changes = x, y, changes + sent(8)
		end
		if element.color ~= color then
			player:hud_change(element.id, "number", color)
			element.color, changes = color, changes + sent(4)
		end
	end
	if element.text ~= text then
		player:hud_change(element.id, "text", text)
		element.text, changes = text, changes + sent(2 + #text)
	end
	return changes
end

local function remove(player, state)
	if not state.hud then return end
	for _, element in ipairs(state.hud.all) do player:hud_remove(element.id) end
	state.hud = nil
end

-- Texture names by heading frame and rim direction, built once.
local PARTY_TEXTURE, RIM_TEXTURE = {}, {}
for index = 0, 15 do PARTY_TEXTURE[index] = ("grug_map_heading_cyan_%02d.png"):format(index) end
for index = 0, V.RIM_FRAMES - 1 do RIM_TEXTURE[index] = ("grug_map_rim_cyan_%02d.png"):format(index) end
local BACKGROUND -- the sea disc under the map, set by M.install

local function create(player, state)
	local hud = {background = image(player, Z.background, true),
		map = image(player, Z.map, true), bezel = image(player, Z.bezel, true),
		markers = {}, by_marker = {}, party = {}}
	for i = 1, PARTY_SLOTS do hud.party[i] = image(player, Z.party + i) end
	-- The player's arrow is a compass element: the client turns it with the
	-- view every frame, so turning around sends nothing; it stays centred.
	hud.player = {id = player:hud_add({type = "compass", position = {x = 0, y = 0},
		alignment = {x = 0, y = 0}, size = {x = 1, y = 1}, direction = 0,
		text = "grug_map_heading_gold_00.png", z_index = Z.player}), x = 0, y = 0, size = 0}
	hud.location = {id = player:hud_add({type = "text", position = {x = 0, y = 0},
		alignment = {x = 0, y = 1}, text = "", number = LOCATION_COLOR,
		z_index = Z.bezel}), text = "", color = LOCATION_COLOR, x = 0, y = 0}
	-- Claim mode's line left of the bezel (Round 86), right-aligned, its
	-- last line ending at the bezel's bottom, on its box (fix round 1).
	hud.claim_box = image(player, Z.bezel - 1, true)
	hud.claim_hint = {id = player:hud_add({type = "text", position = {x = 0, y = 0},
		alignment = {x = -1, y = -1}, text = "", number = HINT_FREE,
		z_index = Z.bezel}), text = "", color = HINT_FREE, x = 0, y = 0}
	hud.all = {hud.background, hud.map, hud.bezel, hud.player, hud.location, hud.claim_box,
		hud.claim_hint}
	for _, list in ipairs({hud.markers, hud.party}) do
		for _, element in ipairs(list) do hud.all[#hud.all + 1] = element end
	end
	state.hud, state.cell_x, state.cell_y, state.static = hud, nil, nil, nil
	state.near, state.frame_box, state.window = nil, nil, nil
	-- what the map, markers, party arrows and claim line were last drawn for
	state.mx, state.my, state.drawn_near, state.drawn_frame = nil, nil, nil, nil
	state.drawn_texture, state.hint_frame, state.hint_drawn = nil, nil, nil
	state.party_shown, state.seen, state.members = nil, {}, {}
	for i = 1, PARTY_SLOTS do state.seen[i] = {} end
end

-- The side elements (Round 48): the mail icon, the announcements icon
-- (Round 84), the daytime band and the "Now playing" box, which stay while
-- the minimap is hidden or unavailable.
local function create_side(player, state)
	local side = {mail = image(player, Z.bezel, true), band = image(player, Z.bezel, true),
		announce = image(player, Z.bezel, true), playing_box = image(player, Z.bezel, true),
		playing_icon = image(player, Z.bezel + 1, true)}
	side.playing_text = {id = player:hud_add({type = "text", position = {x = 0, y = 0},
		alignment = {x = 1, y = 1}, text = "", number = LOCATION_COLOR,
		z_index = Z.bezel + 1}), text = "", color = LOCATION_COLOR, x = 0, y = 0}
	side.all = {side.mail, side.announce, side.band, side.playing_box, side.playing_icon,
		side.playing_text}
	state.side, state.side_box, state.side_frame, state.side_layout = side, nil, nil, nil
	return side
end

-- The minimap box for the player's window (read every WINDOW seconds);
-- kept as the same table while nothing in it changed.
local function read_box(player, state)
	local box = layout.minimap_box(core.get_player_window_information(player:get_player_name()))
	local last = state.box
	if not last or last.size ~= box.size or last.center_x ~= box.center_x or
			last.center_y ~= box.center_y or last.hud ~= box.hud or last.gui ~= box.gui or
			last.width ~= box.width or last.height ~= box.height then
		state.box = box
	end
end

-- The markers that do not move by themselves (ruling 8): quest givers with
-- their state, the Steward, trainers, innkeepers, home and waystones.
local PROVIDERS = {quest=true, service=true, home=true, waypoint=true,
 settlement=true, poi=true, boss=true}
-- Each at its anchor (Round 67 ruling 20: overlaps are allowed), with its
-- importance (markers.rank) for the z-index.
local function static_markers(player)
 local result = {}
 for _, marker in ipairs(atlas.collect_markers(player, PROVIDERS)) do
  -- The clash-site landmark already represents this place on the minimap.
  local texture = marker.kind ~= "rift_boss" and markers.texture(marker)
  if texture then
   result[#result+1] = {id=marker.id, x=marker.position.x, z=marker.position.z,
    texture=texture, kind=marker.kind, rank=markers.rank(marker)}
  end
 end
 return result
end

-- What the static markers depend on besides the faction's fixed service and
-- giver lists, read without asking the providers: the parts of the Map
-- tab's signature (page.lua) that are markers.
local function static_key(player)
	local _, version = grug_quests.marker_states(player)
	local home = grug_home.get(player)
	local function location_key(row)
  local pos = row and row.pos
  return row and (row.id .. ":" .. (pos and (pos.x .. ":" .. pos.z) or "")) or ""
 end
 local parts = {version, location_key(home), grug_factions.get_faction(player) or ""}
	for _, row in ipairs(grug_home.known_waypoints(player)) do parts[#parts + 1] = location_key(row) end
	-- The Claim Stone waypoint (Round 45 PT9) appears with its activation.
	local claim = grug_home.claim_waypoint(player)
	parts[#parts + 1] = location_key(claim)
	return table.concat(parts, "|")
end

-- The other members' names, asked from grug_parties only when the party
-- changes (or on the SLOW refresh); positions are read every step.
local function party_names(player, state)
	if not state.party then
		local name = player:get_player_name()
		state.party = {}
		local group = grug_parties.view(player)
		for _, member in ipairs(group and group.members or {}) do
			if member.name ~= name then state.party[#state.party + 1] = member.name end
		end
	end
	return state.party
end

-- Every element resends its position on the next show: after a window
-- change the same pixel is a different fraction of the window.
local function forget_positions(hud)
	for _, element in ipairs(hud.all) do element.x, element.y = nil, nil end
end

-- The location line's top (real screen pixels).
local function location_top(frame)
	return frame.center_y + frame.diameter / 2 + LOCATION_GAP * frame.hud
end

-- The "Now playing" box for `state.playing` (a track row of grug_ambience's
-- data: title and artist; nil hides it): under the location line with the
-- minimap shown, below the side row in the corner otherwise. Called only when
-- the track or the side layout changed; like show(), only what changed is
-- sent.
local function draw_playing(player, state)
	local side, box, track = state.side, state.box, state.playing
	if not track then
		return show(player, box, side.playing_box, "") +
			show(player, box, side.playing_icon, "") +
			show_text(player, box, side.playing_text, "")
	end
	local frame, placed = state.side_frame, state.side_layout
	local g
	if frame then
		g = V.now_playing_box(frame, location_top(frame), track.title, track.artist)
	else
		local name = player:get_player_name()
		local _, top = V.side_stack(placed, mail_counts[name], announce_counts[name])
		g = V.now_playing_corner(box, placed.playing_right, top, track.title, track.artist)
	end
	return show(player, box, side.playing_box,
			("[fill:%dx%d:%s"):format(g.w, g.h, PLAYING_BOX_COLOR), g.x, g.y,
			exact(g.w, g.w, box)) +
		show(player, box, side.playing_icon, PLAYING_ICON, g.icon_x, g.icon_y,
			exact(g.icon, texture_size(PLAYING_ICON), box)) +
		show_text(player, box, side.playing_text, track.title .. "\n" .. track.artist,
			LOCATION_COLOR, g.text_x, g.text_y)
end

-- The mail icon and the announcements icon for the player's unread counts
-- (each hidden at 0; the announcements icon under the mail icon or in its
-- place, V.side_stack).
local function draw_mail(player, state)
	local name, mail = player:get_player_name(), state.side_layout.mail
	local announce = V.side_stack(state.side_layout, mail_counts[name], announce_counts[name])
	return show(player, state.box, state.side.mail, V.mail_texture(mail_counts[name]),
			mail.x, mail.y, exact(mail.w, V.SIDE.mail_w, state.box)) +
		show(player, state.box, state.side.announce, V.announce_texture(announce_counts[name]),
			announce.x, announce.y, exact(announce.w, V.SIDE.announce_w, state.box))
end

-- The daytime band at the world clock's current position.
local function draw_band(player, state)
	local placed = state.side_layout.band
	local position = V.daytime_position(core.get_timeofday(), grug_core.DAY_PHASE_START,
		grug_core.DAY_PHASE_END)
	return show(player, state.box, state.side.band, V.daytime_texture(position),
		placed.x, placed.y, exact(placed.w, V.SIDE.band_w, state.box))
end

-- The side elements: placed again when the window or the mode (minimap
-- shown, or hidden or unavailable) changed; otherwise only the band, on the
-- SLOW tick. The two mail icons and "Now playing" are drawn when they are
-- told.
local function update_side(player, state, slow)
	if not state.box then read_box(player, state) end
	if not state.side then create_side(player, state) end
	local frame = view and state.hud and state.frame or false
	if state.side_box ~= state.box or state.side_frame ~= frame then
		state.side_box, state.side_frame = state.box, frame
		state.side_layout = V.side_layout(state.box, frame or nil)
		forget_positions(state.side)
		return draw_mail(player, state) + draw_band(player, state) +
			draw_playing(player, state)
	end
	if slow then return draw_band(player, state) end
	return 0
end

-- What depends only on the window: the frame, the sea disc, the bezel and
-- the arrow's place and size. The location line is read here too.
local function update_window(player, state)
	local hud, changes = state.hud, 0
	if not state.box then read_box(player, state) end
	local box = state.box
	if state.frame_box ~= box then
		state.frame_box, state.frame = box, V.frame(view, box)
		forget_positions(hud)
		local frame = state.frame
		local sea = math.floor(frame.hole + 2)
		changes = changes + show(player, frame, hud.background, BACKGROUND,
			frame.center_x - sea, frame.center_y - sea, exact(2 * sea, view.pixels, frame))
		changes = changes + show(player, frame, hud.bezel, BEZEL,
			frame.center_x - frame.diameter / 2, frame.center_y - frame.diameter / 2,
			exact(frame.diameter, BEZEL_PX, frame))
		-- The arrow sits at the centre; the compass element's size is in raw
		-- pixels.
		local x, y = frame.arrow_x, frame.arrow_y
		local arrow = math.floor(PLAYER_ARROW * marker_px(frame) / markers.SIZE + 0.5)
		local element = hud.player
		if element.x ~= x or element.y ~= y then
			player:hud_change(element.id, "position", {x = x / frame.width, y = y / frame.height})
			element.x, element.y, changes = x, y, changes + sent(8)
		end
		if element.size ~= arrow then
			player:hud_change(element.id, "size", {x = arrow, y = arrow})
			element.size, changes = arrow, changes + sent(8)
		end
	end
	local frame = state.frame
	local location = grug_map.location
	local text, color, home = "", nil, false
	if location then text, color, home = location.text_of(player) end
	local x, top = frame.center_x, location_top(frame)
	-- Round 86: a home's name with the house icon before it, both centred
	-- together (hud_layout.icon_before, the line's default font at the GUI
	-- scaling); the icon's top on the text's, its middle at the letters'
	-- (0.6 of an em down, HOME_ICON_EM 1.2 high). A line wider than the
	-- bezel ends at the bezel's right edge and grows to the left, as "Now
	-- playing" does (a name of 24 characters is wider). Its element is
	-- added at the first home.
	if home and text ~= "" then
		local icon = layout.icon_before(text, math.floor(layout.FONT_PX * frame.gui), false)
		x = x + math.min(0, frame.center_x + frame.diameter / 2 - (x + icon.width / 2))
		if not hud.home_icon then
			hud.home_icon = image(player, Z.bezel, true)
			hud.all[#hud.all + 1] = hud.home_icon
		end
		local texture = grug_housing.HOME_ICON
		changes = changes + show(player, frame, hud.home_icon, texture,
			x + icon.icon_x - icon.size / 2, top,
			exact(icon.size, texture_size(texture), frame))
		x = x + icon.text_x
	elseif hud.home_icon then
		changes = changes + show(player, frame, hud.home_icon, "")
	end
	changes = changes + show_text(player, frame, hud.location, text, color or LOCATION_COLOR,
		x, top)
	return changes
end

-- The wielded item's name for claim mode (Round 81 HOT; audit X4-07, X4-02:
-- get_wielded_item copies the stack, every step for every player before).
-- Read again when the wield index changed (a number, no copy: a slot
-- switch shows at once) and on the window check (`fresh`, every WINDOW
-- seconds, and every refresh): a change inside the held slot (a stack
-- dragged into it, a hotbar layout switch, a pickup, a placed Claim Stone)
-- shows within WINDOW.
local function wielded_name(player, state, fresh)
	local index = player:get_wield_index()
	if fresh or index ~= state.wield_index then
		state.wield_index, state.wield_name = index, player:get_wielded_item():get_name()
	end
	return state.wield_name
end

-- Claim mode: the faction whose preview the player sees while holding a
-- Claim Stone, or nil (another item, no faction, no grug_housing preview).
local function claim_mode(player, state, fresh)
	if not claim_ready or not housing.is_stone_item(wielded_name(player, state, fresh)) then
		return nil
	end
	return grug_factions.get_faction(player)
end

-- The chunk index of node coordinate v (a position rounded to its node, as
-- grug_housing's claim_at).
local function chunk_of(v)
	return math.floor((math.floor(v + 0.5) - ORIGIN) / CHUNK)
end

-- Flight mode: the faction whose no-fly overlay the player sees while on a
-- flying mount, or nil (on foot, a ground mount or a boat, no faction, no
-- overlays).
local function flight_mode(player)
	if not flight_tiles or not grug_mounts.is_flying(player) then return nil end
	local faction = grug_factions.get_faction(player)
	return faction and flight_tiles[faction] and faction or nil
end

-- A claim's chunk as the centre and half side the view's claim geometry
-- takes (minimap_view.lua: columns centre +- half): cx, cz, half.
local function chunk_square(claim)
	local x0, z0, x1, z1 = housing.claim_bounds(claim)
	return (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2
end

-- Claim mode's part of the cell texture (Round 86), in drawing order: every
-- refused chunk on the texture in red, a run of refused chunks along a row
-- in one fill, grown over the next rows while they hold the same run; a
-- grid line on every chunk edge on the texture; the claims'
-- frames as outside claim mode (the others' yellow, the own green last);
-- the player's chunk (state.chunk_x/z) framed green, green inside too when
-- it is free. Returns the layer and the player's chunk's refusal (code and
-- kind; nil when free).
local function claim_layer(name, state)
	local cols, rows = V.chunk_cells(view, state.ox, state.oy, CHUNK, ORIGIN)
	local faction, rects, by_col, by_row = state.claim, {}, {}, {}
	for _, col in ipairs(cols) do by_col[col[1]] = col end
	-- `above`: the previous row's runs by their x span; a run of the same
	-- span in the next row grows that fill downward instead of adding one
	local above = {}
	for _, row in ipairs(rows) do
		by_row[row[1]] = row
		local here, x0 = {}, nil
		for index = 1, #cols + 1 do
			local col = cols[index]
			local refused = col and housing.chunk_refusal(faction, col[1], row[1])
			if refused and not x0 then x0 = col[2] end
			if not refused and x0 then
				local x1 = cols[index - 1][3]
				local key = x0 * 4096 + x1
				local rect = above[key]
				if rect then
					rect.h = row[3] - rect.y
				else
					rect = {x = x0, y = row[2], w = x1 - x0, h = row[3] - row[2], color = CLAIM_RED}
					rects[#rects + 1] = rect
				end
				here[key], x0 = rect, nil
			end
		end
		above = here
	end
	local size = view.combined
	for _, col in ipairs(cols) do
		if col[4] >= 0 then rects[#rects + 1] = {x = col[4], y = 0, w = 1, h = size, color = GRID} end
	end
	for _, row in ipairs(rows) do
		if row[4] >= 0 then rects[#rects + 1] = {x = 0, y = row[4], w = size, h = 1, color = GRID} end
	end
	local own
	local function frame(claim, color)
		local x0, z0 = housing.claim_bounds(claim)
		local col, row = by_col[math.floor((x0 - ORIGIN) / CHUNK)], by_row[math.floor((z0 - ORIGIN) / CHUNK)]
		if col and row then V.cell_frame(view, col, row, color, rects) end
	end
	for _, claim in ipairs(housing.claims_in(V.texture_area(view, state.ox, state.oy))) do
		if housing.is_owner(claim, name) then own = claim else frame(claim, OTHER_FRAME) end
	end
	if own then frame(own, OWN_FRAME) end
	local code, kind = housing.chunk_refusal(faction, state.chunk_x, state.chunk_z)
	local col, row = by_col[state.chunk_x], by_row[state.chunk_z]
	if col and row then
		if not code then
			rects[#rects + 1] = {x = col[2], y = row[2], w = col[3] - col[2], h = row[3] - row[2],
				color = SQUARE_FILL}
		end
		V.cell_frame(view, col, row, SQUARE_EDGE, rects)
	end
	return {rects = rects}, code, kind
end

-- The claims near the cell outside claim mode: the others' frames first,
-- the player's own last (on top where two touch); nil when none is on the
-- texture, so the recipe is the plain map's.
local function frame_layer(name, state)
	local min_x, min_z, max_x, max_z = V.texture_area(view, state.ox, state.oy)
	local rects, own = {}, nil
	for _, claim in ipairs(housing.claims_in(min_x, min_z, max_x, max_z)) do
		if housing.is_owner(claim, name) then
			own = claim
		else
			local cx, cz, half = chunk_square(claim)
			V.claim_frame(view, state.ox, state.oy, cx, cz, half, OTHER_FRAME, rects)
		end
	end
	if own then
		local cx, cz, half = chunk_square(own)
		V.claim_frame(view, state.ox, state.oy, cx, cz, half, OWN_FRAME, rects)
	end
	return rects[1] and {rects = rects} or nil
end

-- Claim mode's line (state.hint, state.hint_free) left of the bezel on its
-- dark box, both ending at the bezel's bottom (minimap_view.lua hint_box);
-- both hidden outside claim mode.
local function draw_hint(player, state, frame)
	local hud = state.hud
	if not state.hint then
		return show(player, frame, hud.claim_box, "") + show_text(player, frame, hud.claim_hint, "")
	end
	local g = V.hint_box(frame, state.hint, HINT_GAP)
	return show(player, frame, hud.claim_box, ("[fill:%dx%d:%s"):format(g.w, g.h, HINT_BOX),
			g.x, g.y, exact(g.w, g.w, frame)) +
		show_text(player, frame, hud.claim_hint, state.hint,
			state.hint_free and HINT_FREE or HINT_REFUSED, g.text_x, g.text_y)
end

-- The map element and the markers inside the hole, for the map corner
-- mx/my. The rows are reused from step to step (`state.rows`), so a draw
-- reuses marker rows; small wanted/free lists maintain stable HUD ids.
local function draw_map(player, state, frame, mx, my)
	local hud = state.hud
	local changes = show(player, frame, hud.map, state.texture, mx, my,
		exact(frame.drawn, view.pixels, frame))
	local size = marker_px(frame)
	local limit = frame.hole - size / 2
	local rows, visible, count = state.rows, state.visible, 0
 local wanted, free = {}, {}
	for index, marker in ipairs(state.near) do
		local x, y, distance = V.place(view, frame, state.ox, state.oy, mx, my,
			marker.x, marker.z)
		if distance <= limit then
			count = count + 1
			local row = rows[count]
			if not row then row = {}; rows[count] = row end
			row.marker, row.x, row.y, row.order = marker, x, y, index
   wanted[marker.id] = true
			visible[count] = row
		end
	end
	for i = #visible, count + 1, -1 do visible[i] = nil end
 -- Stable ids keep their HUD elements while other markers enter/leave.
 for _, element in ipairs(hud.markers) do
  if not wanted[element.marker_id] then
   if element.marker_id then hud.by_marker[element.marker_id] = nil end
   element.marker_id = nil
   changes = changes + show(player,frame,element,"")
   free[#free+1] = element
  end
 end
 for i = 1, count do
  local row = visible[i]
  local id, texture = row.marker.id, row.marker.texture
  local element = hud.by_marker[id]
  if not element then
   element = table.remove(free)
   if not element then
    element = image(player,Z.marker)
    hud.markers[#hud.markers+1], hud.all[#hud.all+1] = element, element
   end
   element.marker_id, hud.by_marker[id] = id, element
  end
  -- by importance (markers.rank: 0 to 10), all under the bezel
  local z = Z.marker + row.marker.rank
  if element.z ~= z then
   player:hud_change(element.id,"z_index",z)
   element.z = z
   changes = changes + sent(4)
  end
  changes = changes + show(player,frame,element,texture,row.x,row.y,
   exact(size,texture_size(texture),frame))
 end
	return changes
end

-- The party members' arrows: placed again when the map moved (`moved`) or
-- a member came, went, moved or turned to another heading frame since the
-- last draw (`state.seen`, one reused row per slot).
local function draw_party(player, state, frame, mx, my, moved)
	local members, seen, slot = state.members, state.seen, 0
	local same = not moved
	for _, member in ipairs(party_names(player, state)) do
		local row = slot < PARTY_SLOTS and locate(member)
		if row then
			slot = slot + 1
			members[slot] = row
			local last, facing = seen[slot], heading(row)
			if last.name ~= member or last.x ~= row.x or last.z ~= row.z or
					last.frame ~= facing then
				last.name, last.x, last.z, last.frame, same = member, row.x, row.z, facing, false
			end
		end
	end
	if same and slot == state.party_shown then return 0 end
	state.party_shown = slot
	M.stats.party = M.stats.party + 1
	local hud, hud_px, changes = state.hud, frame.hud, 0
	local arrow = PARTY_ARROW * marker_px(frame) / markers.SIZE
	local inside = frame.hole - arrow / 2
	for i = 1, slot do
		local row = members[i]
		local x, y, distance = V.place(view, frame, state.ox, state.oy, mx, my, row.x, row.z)
		if distance <= inside then
			changes = changes + show(player, frame, hud.party[i], PARTY_TEXTURE[heading(row)],
				x, y, exact(arrow, 32, frame))
		else
			-- On the bezel, above it and its N plate (a party member due
			-- north matters more than the letter), filling the ring.
			local rx, ry, index = V.rim(frame, x - frame.center_x, y - frame.center_y)
			local ring = frame.diameter / 2 - frame.hole
			local size = RIM_FILL * ring / RIM_EXTENT
			changes = changes + show(player, frame, hud.party[i], RIM_TEXTURE[index], rx, ry,
				size / (32 * hud_px))
		end
	end
	for i = slot + 1, PARTY_SLOTS do
		changes = changes + show(player, frame, hud.party[i], "")
	end
	return changes
end

-- `window` asks for the window and location check (every WINDOW seconds).
local function update(player, state, slow, window)
	if state.enabled == nil then state.enabled = M.enabled(player) end
	-- Claim mode shows the minimap even when it is switched off (ruling 6).
	local claim = claim_mode(player, state, slow or window)
	if not state.enabled and not claim then
		remove(player, state)
		state.claim, state.flight = nil, nil
		return 0
	end
	if not state.hud then create(player, state) end
	local changes = 0
	if window or slow or not state.frame_box or state.frame_box ~= state.box then
		changes = changes + update_window(player, state)
	end
	local frame = state.frame
	local pos = locate(player:get_player_name(), player)
	local cx, cy = V.cell(view, pos.x, pos.z)
	local version = housing and housing.claim_set_version() or nil
	local flight = flight_mode(player)
	-- In claim mode the player's chunk too (it can change inside a cell).
	local chunk_x, chunk_z
	if claim then chunk_x, chunk_z = chunk_of(pos.x), chunk_of(pos.z) end
	if cx ~= state.cell_x or cy ~= state.cell_y or claim ~= state.claim or
			version ~= state.claim_version or flight ~= state.flight or
			chunk_x ~= state.chunk_x or chunk_z ~= state.chunk_z then
		if cx ~= state.cell_x or cy ~= state.cell_y then
			state.cell_x, state.cell_y = cx, cy
			state.ox, state.oy = V.origin(view, cx, cy)
			state.near = nil
		end
		state.claim, state.claim_version, state.flight = claim, version, flight
		state.chunk_x, state.chunk_z = chunk_x, chunk_z
		-- The recipe and claim mode's line are built again; the client gets
		-- them only when they differ.
		local layer
		state.hint = nil
		if claim then
			local code, kind
			layer, code, kind = claim_layer(player:get_player_name(), state)
			state.hint, state.hint_free = housing.claim_hint(code, kind), code == nil
		elseif housing then
			layer = frame_layer(player:get_player_name(), state)
		end
		local texture = V.texture(view, state.ox, state.oy, M.mask, layer,
			flight and flight_tiles[flight])
		if texture ~= state.texture then
			state.texture = texture
			M.stats.textures = M.stats.textures + 1
		end
	end
	if frame ~= state.hint_frame or state.hint ~= state.hint_drawn then
		state.hint_frame, state.hint_drawn = frame, state.hint
		changes = changes + draw_hint(player, state, frame)
	end
	if slow then state.party = nil end
	if slow or not state.static then
		local key = static_key(player)
		if not state.static or key ~= state.static_key then
			state.static, state.static_key, state.near = static_markers(player), key, nil
		end
	end
	-- Another frame draws the markers at another size: the margin below.
	if state.near_frame ~= frame then state.near, state.near_frame = nil, frame end
	if not state.near then
		-- the static markers under the cell's texture, in draw order
		state.near = {}
		local size = view.texture
		local margin = marker_px(frame) / frame.f
		for _, marker in ipairs(state.static) do
			local px, py = V.base_pixel(view, marker.x, marker.z)
			if px >= state.ox-margin and px <= state.ox+size+margin and
     py >= state.oy-margin and py <= state.oy+size+margin then
				state.near[#state.near + 1] = marker
			end
		end
	end

	-- The map: texture and position change in the same step, so a new cell
	-- lines up with the old one to the pixel. Nothing to place when the map
	-- corner, the markers near the cell and the frame are what was drawn.
	local px, py = V.base_pixel(view, pos.x, pos.z)
	local mx, my = V.map_corner(view, frame, state.cell_x, state.cell_y, px, py)
	local moved = mx ~= state.mx or my ~= state.my or state.near ~= state.drawn_near or
		frame ~= state.drawn_frame or state.texture ~= state.drawn_texture
	if moved then
		state.mx, state.my, state.drawn_near, state.drawn_frame = mx, my, state.near, frame
		state.drawn_texture = state.texture
		M.stats.drawn = M.stats.drawn + 1
		changes = changes + draw_map(player, state, frame, mx, my)
	end
	return changes + draw_party(player, state, frame, mx, my, moved)
end

-- Redraw one player's minimap now (the Map tab's switch, a quest change);
-- the side elements follow the mode at once.
function M.refresh(player)
	local state = players[player:get_player_name()]
	if not state then return end
	if view then update(player, state, true) end
	update_side(player, state, false)
end

-- The "Now playing" box (0.45.1): grug_ambience tells the track that
-- really plays (its data row with title and artist) or nil, only when that
-- changes. It is drawn under the location line, or in the top-right corner
-- with the minimap hidden or unavailable (Round 48).
function M.set_now_playing(name, track)
	local state = players[name]
	if not state then return end
	local shown = state.playing ~= nil
	state.playing = track
	local player = core.get_player_by_name(name)
	if not player then return end
	if state.side_layout then
		M.stats.changes = M.stats.changes + draw_playing(player, state)
	end
	-- The quest tracker's boxes make room for the box (or take it back) at
	-- once when it comes or goes, not at their next 0.5 s poll (Round 65).
	if shown ~= (track ~= nil) then grug_quests.hud_refresh(player) end
end

-- Whether `name`'s "Now playing" box shows: the quest tracker (grug_quests
-- hud.lua, Round 65) keeps its boxes clear of it.
function M.now_playing(name)
	local state = players[name]
	return state ~= nil and state.playing ~= nil
end

-- The mail icons (Round 48, the round plan's interface 3.1; grug_mail calls
-- it on every change of an unread count and at join): `letters` unread
-- letters on the mail icon, `announcements` unread announcements on the
-- icon under it (Round 84 default 15; until then one count for both); 0
-- hides an icon, 1-9 show the digit, more "9+". The counts are kept per
-- player, so a relayout or a mode switch draws them again.
function M.set_mail_count(name, letters, announcements)
	letters = math.max(0, math.floor(tonumber(letters) or 0))
	announcements = math.max(0, math.floor(tonumber(announcements) or 0))
	mail_counts[name] = letters > 0 and letters or nil
	announce_counts[name] = announcements > 0 and announcements or nil
	local state = players[name]
	local player = state and state.side_layout and core.get_player_by_name(name)
	if player then
		-- "Now playing" in the corner follows the stack's height.
		M.stats.changes = M.stats.changes + draw_mail(player, state) +
			(state.side_frame and 0 or draw_playing(player, state))
	end
end

function M.set_enabled(player, enabled)
	player:get_meta():set_string(META, enabled and "" or "1")
	local state = players[player:get_player_name()]
	if state then state.enabled = enabled and true or false end
	M.refresh(player)
end

-- Ruling 5: the native minimap is off for everyone. The flags remove the
-- builtin minimap element (builtin/game/hud.lua), so the client's V key only
-- reports "Minimap currently disabled by game or mod"; the single "off" mode
-- is the backstop.
local function native_off(player)
	player:hud_set_flags({minimap = false, minimap_radar = false})
	player:set_minimap_modes({{type = "off", label = "Minimap off"}}, 0)
end

-- Called from init.lua with base.lua's result; the minimap shows its
-- `minimap` base (normal size on every server, user ruling 2026-10-06).
-- Without tiles (the base failed to render) or without its mask (the world
-- folder cannot be written) the native minimap stays off and ours is not
-- shown; the Map tab says so.
function M.install(installed)
	local mini = installed.minimap
	if not mini or not mini.tiles then return end
	local candidate = V.new(mini, atlas.view())
	local ok, err = pcall(function()
		grug_map.base.add_media(grug_map.base.MASK,
			grug_map.base.mask_png(candidate.pixels, 0))
	end)
	if not ok then
		core.log("error", "[grug_map] minimap unavailable: " .. tostring(err))
		return
	end
	base, view, M.mask = mini, candidate, grug_map.base.MASK
	reference_hole = nil
	-- the sea disc beyond the base: the open sea's colour (base.lua)
	BACKGROUND = M.mask .. "^[multiply:" .. grug_map.base.OPEN_SEA_HEX
	-- The claims' frames need grug_housing; claim mode its chunk preview too
	-- (Round 86: nothing is baked into the base for it any more).
	housing = rawget(_G, "grug_housing")
	claim_ready = housing ~= nil and type(housing.chunk_refusal) == "function"
	if claim_ready then
		ORIGIN, CHUNK = housing.CHUNK_ORIGIN, housing.CHUNK
		CLAIM_RED = ("#%02x%02x%02x%02x"):format(unpack(grug_map.base.CLAIM_RED))
	end
	flight_tiles = mini.flight
end

-- False when the world map base or the minimap's mask is missing.
function M.available()
	return view ~= nil
end

-- For engine probes: the geometry (minimap_view's table) and a player's
-- current cell texture.
function M.geometry()
	return view
end

function M.texture_of(player)
	local state = players[player:get_player_name()]
	return state and state.texture
end

-- The faction whose claim preview the player sees now, or nil.
function M.claim_of(player)
	local state = players[player:get_player_name()]
	return state and state.claim
end

-- The faction whose no-fly overlay the player sees now, or nil.
function M.flight_of(player)
	local state = players[player:get_player_name()]
	return state and state.flight
end

-- Each player's SLOW refresh has its own phase, so the marker providers are
-- not asked for every player in the same step: players joining one after
-- another start JOIN_PHASE seconds apart (SLOW / JOIN_PHASE phases).
local JOIN_PHASE = 0.2
local joined = 0
core.register_on_joinplayer(function(player)
	native_off(player)
	joined = joined + 1
	players[player:get_player_name()] = {slow = (joined * JOIN_PHASE) % SLOW,
		rows = {}, visible = {}}
end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	players[name], where[name], mail_counts[name], announce_counts[name] = nil, nil, nil, nil
end)
grug_parties.register_on_change(function(name)
	local state = players[name]
	if state then state.party = nil end
end)
grug_quests.register_on_markers_changed(function(player)
	local state = player and players[player:get_player_name()]
	if state then state.static = nil end
end)
-- A new faction (creation or an admin change) shows other NPC markers
-- (Round 31, ruling 13): ask the providers again on the next step.
grug_factions.register_on_faction_chosen(function(player)
	local state = players[player:get_player_name()]
	if state then state.static = nil end
end)

-- Every step: the minimap (when available) and the side elements, which
-- also run while the minimap is hidden or unavailable (Round 48); the
-- window is read every WINDOW seconds for both.
core.register_globalstep(function(dtime)
	step = step + 1
	for _, player in ipairs(core.get_connected_players()) do
		local state = players[player:get_player_name()]
		if state then
			state.slow = (state.slow or 0) + dtime
			local is_slow = state.slow >= SLOW
			if is_slow then state.slow = state.slow % SLOW end
			state.window = (state.window or 0) + dtime
			local window = state.window >= WINDOW
			if window then state.window = 0 end
			local started = core.get_us_time()
			if window or is_slow then read_box(player, state) end
			local changes = 0
			if view then changes = update(player, state, is_slow, window) end
			changes = changes + update_side(player, state, is_slow)
			M.stats.updates = M.stats.updates + 1
			M.stats.us = M.stats.us + (core.get_us_time() - started)
			M.stats.changes = M.stats.changes + changes
		end
	end
end)
