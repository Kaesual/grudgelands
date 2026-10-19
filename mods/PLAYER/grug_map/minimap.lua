-- Our own minimap (Round 27, WP50; docs/design/world_map.md). It replaces
-- Luanti's native minimap: a round, north-up HUD window of about 440 nodes
-- of the pre-rendered world map, top right in the native minimap's box
-- (grug_core.hud_layout.minimap_box), with the player's arrow, party
-- members (rim arrows when outside), quest givers with their state, the
-- Housing Steward and the capital services, trainers (their profession's
-- icon since Round 44), innkeepers, the player's home and discovered
-- waystones (Round 29). Settlements, points of interest, kings and dragons
-- are baked into the minimap's own base image since Round 44 (base.lua,
-- bake.lua). Under it a line names the player's location (Round 28 M1,
-- location.lua), and while a capital's music plays a "Now playing" box under
-- that line names the track (0.45.1; grug_ambience tells it which).
--
-- Side elements (Round 48 lane HUD): the mail icon with its unread count
-- (grug_mail calls M.set_mail_count) and the daytime band stand in one row
-- left of the bezel, top-aligned with it (follow-up lane HUD2). With the
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
-- Claim mode (fix 0.50.2; docs/design/housing.md §2): while a player with a
-- faction holds a Claim Stone, the cell texture also holds the faction's
-- red overlay of forbidden ground (base.lua claim_overlay) and one red
-- rectangle per claim near the cell (grug_housing.claims_in, drafts
-- included), and a green square of the claim's size sits on the arrow. The
-- texture is built again on a cell change, a mode change or a change of the
-- claim set (grug_housing.claim_set_version) and sent only when its string
-- differs; the square changes only with the window. A switched-off minimap
-- appears for claim mode and goes after it. The preview is a guide:
-- grug_housing's validate alone decides a placement.
--
-- Claims outside claim mode (fix 0.50.2 lane HOME, ruling H4): the cell
-- texture frames the player's own claim in the square's green and every
-- other claim in yellow, one base pixel wide and without fill, drafts and
-- expired claims included (minimap_view.lua claim_frame). The texture is
-- built again on a cell change or a claim-set version change and sent only
-- when its string differs; with no claim near it is the plain map's.
--
-- Every server step only the cheap test runs (Round 37, audit CORE-04): the
-- map and its markers are placed again only when the map moved by a whole
-- screen pixel, the cell, the texture, the markers or the window changed;
-- the party arrows only then or when a member moved or turned to another of
-- the 16 heading frames. A player standing still with a still party costs
-- one position read, one wielded-item read and one read of the claim set's
-- version per step.

local atlas = grug_map.atlas
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
-- version (a repeatable's cooldown ends), the home, the discovered
-- waystones or the faction (Round 37); the ones near the window are picked
-- on each new cell.
local SLOW = 5.0
-- The window size and the location line are read again every WINDOW
-- seconds, not every step (Round 30, perf review #12): a resize relayouts
-- and a new location shows within that time (the client itself reports a
-- resize 0.2 s after it ends; the location is sampled about once a second).
local WINDOW = 0.5
local MARKER_SLOTS, PARTY_SLOTS = 24, 9
-- Drawn sizes in HUD pixels (scaled with HUD scaling like every HUD image).
local ICON, PARTY_ARROW, PLAYER_ARROW = 16, 20, 24
-- A rim arrow fills RIM_FILL of the bezel ring's width; its chevron spans
-- RIM_EXTENT of its 32 px texture from tip to back, outline included.
local RIM_FILL, RIM_EXTENT = 0.85, 21 / 32
local BEZEL = "grug_map_minimap_bezel.png"
local BEZEL_PX = 256
-- Kinds shown (ruling 8; kept in Round 44 by the user); settlements, camps,
-- kings and dragons are pixels of the base since Round 44.
local SHOWN = {quest = true, steward = true, service = true, trainer = true,
	innkeeper = true, home = true, waypoint = true}
local QUEST_TEXTURE = {available = "grug_map_quest_available.png",
	locked = "grug_map_quest_locked.png", ready = "grug_map_quest_ready.png",
	active = "grug_map_quest_active.png"}
local KIND_TEXTURE = {innkeeper = "grug_map_innkeeper.png", home = "grug_map_home.png",
	waypoint = "grug_map_waypoint.png"}
-- Which markers keep a slot when more than MARKER_SLOTS are in the circle
-- (the densest capital window holds 15 of these besides home and waystones,
-- Round 44; the mender's marker of Round 46 adds at most one).
local PRIORITY = {quest = 1, steward = 2, service = 2, home = 3, innkeeper = 4,
	trainer = 5, waypoint = 6}
local Z = {background = 10, map = 11, square = 12, marker = 20, bezel = 45, party = 50,
	player = 60}
-- Claim mode's colours (the plan's starting values, the user tunes them):
-- the claims in the overlay's red (base.lua CLAIM_RED, about 45 % opaque;
-- set by M.install), the player's square green, its fill about 30 % opaque,
-- its frame 80 %.
local SQUARE_FILL, SQUARE_EDGE = "#40d04a4d", "#40d04acc"
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
-- The claims (set by M.install when grug_housing is there): the Claim
-- Stone's item name and the claim's radius. Claim mode needs the overlays
-- too: their tiles by faction and the red.
local housing, STONE, RADIUS
local claim_tiles, CLAIM_RED
local players = {}
-- Unread letters per online player (M.set_mail_count), kept apart from the
-- minimap state so a count told before this mod's join callback is kept.
local mail_counts = {}
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
		square = image(player, Z.square, true), markers = {}, party = {}}
	for i = 1, MARKER_SLOTS do hud.markers[i] = image(player, Z.marker + i) end
	for i = 1, PARTY_SLOTS do hud.party[i] = image(player, Z.party + i) end
	-- The player's arrow is a compass element: the client turns it with the
	-- view every frame, so turning around sends nothing; it stays centred.
	hud.player = {id = player:hud_add({type = "compass", position = {x = 0, y = 0},
		alignment = {x = 0, y = 0}, size = {x = 1, y = 1}, direction = 0,
		text = "grug_map_heading_gold_00.png", z_index = Z.player}), x = 0, y = 0, size = 0}
	hud.location = {id = player:hud_add({type = "text", position = {x = 0, y = 0},
		alignment = {x = 0, y = 1}, text = "", number = LOCATION_COLOR,
		z_index = Z.bezel}), text = "", color = LOCATION_COLOR, x = 0, y = 0}
	hud.all = {hud.background, hud.map, hud.bezel, hud.square, hud.player, hud.location}
	for _, list in ipairs({hud.markers, hud.party}) do
		for _, element in ipairs(list) do hud.all[#hud.all + 1] = element end
	end
	state.hud, state.cell_x, state.cell_y, state.static = hud, nil, nil, nil
	state.near, state.frame_box, state.window = nil, nil, nil
	-- what the map, markers, party arrows and claim square were last drawn for
	state.mx, state.my, state.drawn_near, state.drawn_frame = nil, nil, nil, nil
	state.drawn_texture, state.square_frame, state.square_claim = nil, nil, nil
	state.party_shown, state.seen, state.members = nil, {}, {}
	for i = 1, PARTY_SLOTS do state.seen[i] = {} end
end

-- The side elements (Round 48): the mail icon, the daytime band and the
-- "Now playing" box, which stay while the minimap is hidden or unavailable.
local function create_side(player, state)
	local side = {mail = image(player, Z.bezel, true), band = image(player, Z.bezel, true),
		playing_box = image(player, Z.bezel, true),
		playing_icon = image(player, Z.bezel + 1, true)}
	side.playing_text = {id = player:hud_add({type = "text", position = {x = 0, y = 0},
		alignment = {x = 1, y = 1}, text = "", number = LOCATION_COLOR,
		z_index = Z.bezel + 1}), text = "", color = LOCATION_COLOR, x = 0, y = 0}
	side.all = {side.mail, side.band, side.playing_box, side.playing_icon, side.playing_text}
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
local PROVIDERS = {quest = true, service = true, home = true, waypoint = true}
local function static_markers(player)
	local result = {}
	for _, marker in ipairs(atlas.collect_markers(player, PROVIDERS)) do
		if SHOWN[marker.kind] then
			-- A marker's own texture wins over its kind's (the Claim Stone
			-- waypoint, Round 45 PT9).
			local texture = marker.kind == "quest" and QUEST_TEXTURE[marker.status] or
				marker.texture or KIND_TEXTURE[marker.kind]
			if texture then
				result[#result + 1] = {x = marker.position.x, z = marker.position.z,
					texture = texture, kind = marker.kind}
			end
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
	local parts = {version, home and home.id or "", grug_factions.get_faction(player) or ""}
	for _, row in ipairs(grug_home.known_waypoints(player)) do parts[#parts + 1] = row.id end
	-- The Claim Stone waypoint (Round 45 PT9) appears with its activation.
	local claim = grug_home.claim_waypoint(player)
	parts[#parts + 1] = claim and claim.id or ""
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

-- Draw order when more markers than slots are in the circle: the most
-- important first, then their usual order.
local function by_priority(a, b)
	local pa, pb = PRIORITY[a.marker.kind] or 9, PRIORITY[b.marker.kind] or 9
	if pa ~= pb then return pa < pb end
	return a.order < b.order
end
local function by_order(a, b) return a.order < b.order end

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
		g = V.now_playing_corner(box, placed.playing_right, placed.playing_top,
			track.title, track.artist)
	end
	return show(player, box, side.playing_box,
			("[fill:%dx%d:%s"):format(g.w, g.h, PLAYING_BOX_COLOR), g.x, g.y,
			exact(g.w, g.w, box)) +
		show(player, box, side.playing_icon, PLAYING_ICON, g.icon_x, g.icon_y,
			exact(g.icon, texture_size(PLAYING_ICON), box)) +
		show_text(player, box, side.playing_text, track.title .. "\n" .. track.artist,
			LOCATION_COLOR, g.text_x, g.text_y)
end

-- The mail icon for the player's unread count (hidden at 0).
local function draw_mail(player, state)
	local placed = state.side_layout.mail
	return show(player, state.box, state.side.mail,
		V.mail_texture(mail_counts[player:get_player_name()]), placed.x, placed.y,
		exact(placed.w, V.SIDE.mail_w, state.box))
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
-- SLOW tick. The mail icon and "Now playing" are drawn when they are told.
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
		local arrow = math.floor(PLAYER_ARROW * frame.hud + 0.5)
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
	local text, color = "", nil
	if location then text, color = location.text_of(player) end
	changes = changes + show_text(player, frame, hud.location, text, color or LOCATION_COLOR,
		frame.center_x, location_top(frame))
	return changes
end

-- Claim mode: the faction whose overlay the player sees while holding a
-- Claim Stone, or nil (another item, no faction, no overlays).
local function claim_mode(player)
	if not claim_tiles or player:get_wielded_item():get_name() ~= STONE then return nil end
	local faction = grug_factions.get_faction(player)
	return faction and claim_tiles[faction] and faction or nil
end

-- The claim part of the cell texture: the faction's overlay tiles and one
-- clipped rectangle per claim on the texture, in id order.
local function claim_layer(state)
	local min_x, min_z, max_x, max_z = V.texture_area(view, state.ox, state.oy)
	local rects = {}
	for _, claim in ipairs(housing.claims_in(min_x, min_z, max_x, max_z)) do
		local rect = V.claim_rect(view, state.ox, state.oy, claim.center.x, claim.center.z,
			RADIUS)
		if rect then rects[#rects + 1] = rect end
	end
	return {tiles = claim_tiles[state.claim], rects = rects, color = CLAIM_RED}
end

-- The claims near the cell outside claim mode: the others' frames first,
-- the player's own last (on top where two touch); nil when none is on the
-- texture, so the recipe is the plain map's.
local function frame_layer(name, state)
	local min_x, min_z, max_x, max_z = V.texture_area(view, state.ox, state.oy)
	local rects, own = {}, nil
	for _, claim in ipairs(housing.claims_in(min_x, min_z, max_x, max_z)) do
		if claim.owner == name then
			own = claim
		else
			V.claim_frame(view, state.ox, state.oy, claim.center.x, claim.center.z, RADIUS,
				OTHER_FRAME, rects)
		end
	end
	if own then
		V.claim_frame(view, state.ox, state.oy, own.center.x, own.center.z, RADIUS,
			OWN_FRAME, rects)
	end
	return rects[1] and {rects = rects} or nil
end

-- The player's green square in claim mode, hidden otherwise.
local function draw_square(player, state, frame)
	local element = state.hud.square
	if not state.claim then return show(player, frame, element, "") end
	local square = V.claim_square(view, frame, RADIUS)
	return show(player, frame, element,
		V.claim_square_texture(square, SQUARE_FILL, SQUARE_EDGE), square.x, square.y,
		exact(square.size, square.size, frame))
end

-- The map element and the markers inside the hole, for the map corner
-- mx/my. The rows are reused from step to step (`state.rows`), so a draw
-- builds no tables.
local function draw_map(player, state, frame, mx, my)
	local hud = state.hud
	local changes = show(player, frame, hud.map, state.texture, mx, my,
		exact(frame.drawn, view.pixels, frame))
	local limit = frame.hole - ICON / 2 * frame.hud
	local rows, visible, count = state.rows, state.visible, 0
	for index, marker in ipairs(state.near) do
		local x, y, distance = V.place(view, frame, state.ox, state.oy, mx, my,
			marker.x, marker.z)
		if distance <= limit then
			count = count + 1
			local row = rows[count]
			if not row then row = {}; rows[count] = row end
			row.marker, row.x, row.y, row.order = marker, x, y, index
			visible[count] = row
		end
	end
	for i = #visible, count + 1, -1 do visible[i] = nil end
	if count > MARKER_SLOTS then
		-- More markers than slots: keep the most important ones (quest givers
		-- first; party members have slots of their own), then draw the kept
		-- ones in their usual order.
		table.sort(visible, by_priority)
		for i = count, MARKER_SLOTS + 1, -1 do visible[i] = nil end
		table.sort(visible, by_order)
		count = MARKER_SLOTS
	end
	for i = 1, count do
		local row = visible[i]
		local texture = row.marker.texture
		changes = changes + show(player, frame, hud.markers[i], texture, row.x, row.y,
			ICON / texture_size(texture))
	end
	for i = count + 1, MARKER_SLOTS do
		changes = changes + show(player, frame, hud.markers[i], "")
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
	local inside = frame.hole - PARTY_ARROW / 2 * hud_px
	for i = 1, slot do
		local row = members[i]
		local x, y, distance = V.place(view, frame, state.ox, state.oy, mx, my, row.x, row.z)
		if distance <= inside then
			changes = changes + show(player, frame, hud.party[i], PARTY_TEXTURE[heading(row)],
				x, y, PARTY_ARROW / 32)
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
	local claim = claim_mode(player)
	if not state.enabled and not claim then
		remove(player, state)
		state.claim = nil
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
	if cx ~= state.cell_x or cy ~= state.cell_y or claim ~= state.claim or
			version ~= state.claim_version then
		if cx ~= state.cell_x or cy ~= state.cell_y then
			state.cell_x, state.cell_y = cx, cy
			state.ox, state.oy = V.origin(view, cx, cy)
			state.near = nil
		end
		state.claim, state.claim_version = claim, version
		-- The recipe is built again; the client gets it only when it differs.
		local layer
		if claim then
			layer = claim_layer(state)
		elseif housing then
			layer = frame_layer(player:get_player_name(), state)
		end
		local texture = V.texture(view, state.ox, state.oy, M.mask, layer)
		if texture ~= state.texture then
			state.texture = texture
			M.stats.textures = M.stats.textures + 1
		end
	end
	if frame ~= state.square_frame or state.claim ~= state.square_claim then
		state.square_frame, state.square_claim = frame, state.claim
		changes = changes + draw_square(player, state, frame)
	end
	if slow then state.party = nil end
	if slow or not state.static then
		local key = static_key(player)
		if not state.static or key ~= state.static_key then
			state.static, state.static_key, state.near = static_markers(player), key, nil
		end
	end
	if not state.near then
		-- the static markers under the cell's texture, in draw order
		state.near = {}
		local size = view.texture
		for _, marker in ipairs(state.static) do
			local px, py = V.base_pixel(view, marker.x, marker.z)
			if px >= state.ox and px <= state.ox + size and
					py >= state.oy and py <= state.oy + size then
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
	state.playing = track
	local player = state.side_layout and core.get_player_by_name(name)
	if player then
		M.stats.changes = M.stats.changes + draw_playing(player, state)
	end
end

-- The mail icon (Round 48, the round plan's interface 3.1; grug_mail calls
-- it on every change of the unread count and at join): `count` unread
-- letters and broadcasts, 0 hides the icon, 1-9 show the digit, more "9+".
-- The count is kept per player, so a relayout or a mode switch draws it
-- again.
function M.set_mail_count(name, count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	mail_counts[name] = count > 0 and count or nil
	local state = players[name]
	local player = state and state.side_layout and core.get_player_by_name(name)
	if player then
		M.stats.changes = M.stats.changes + draw_mail(player, state)
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
	-- the sea disc beyond the base: the open sea's colour (base.lua)
	BACKGROUND = M.mask .. "^[multiply:" .. grug_map.base.OPEN_SEA_HEX
	-- The claims' frames need grug_housing; claim mode the overlays
	-- (base.lua) too.
	housing = rawget(_G, "grug_housing")
	if housing then
		STONE, RADIUS = housing.STONE_ITEM, housing.RADIUS
		if mini.claim then
			claim_tiles = mini.claim
			CLAIM_RED = ("#%02x%02x%02x%02x"):format(unpack(grug_map.base.CLAIM_RED))
		end
	end
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
	players[name], where[name], mail_counts[name] = nil, nil, nil
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
