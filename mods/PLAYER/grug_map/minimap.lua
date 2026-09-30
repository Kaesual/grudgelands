-- Our own minimap (Round 27, WP50; docs/design/world_map.md). It replaces
-- Luanti's native minimap: a round, north-up HUD window of about 900 nodes
-- of the pre-rendered world map, top right in the native minimap's box
-- (grug_core.hud_layout.minimap_box), with the player's arrow, party
-- members (rim arrows when outside), quest givers with their state, the
-- Housing Steward, trainers, innkeepers and the player's home.
--
-- Glide (test variant for the playtest): the arrow stays in the centre and
-- the map moves under it pixel by pixel, every server step. The map is ONE
-- image element whose texture is the player's grid cell (ruling 9: the
-- client builds a new texture only on entering a new cell); the element is
-- moved so the player's own pixel lies at the centre, and an opaque bezel
-- covers what overhangs the round hole (HUD images are never clipped).
-- Geometry, and why a cell swap moves no pixel: minimap_view.lua. Markers
-- are separate elements that move with the map. hud_change sends a packet
-- on every call, so every element keeps what was last sent and only
-- differences (whole screen pixels) are sent.

local atlas = grug_map.atlas
local layout = grug_core.hud_layout
local V = dofile(core.get_modpath(core.get_current_modname()) .. "/minimap_view.lua")
local M = {view = V}
grug_map.minimap = M

-- Ruling 10: a per-player switch on the Map tab, stored in player meta, on
-- by default.
local META = "grug_map:minimap_hidden"
-- The map, markers and party members move every server step. The static
-- markers are asked from their providers on a quest change, on joining and
-- every SLOW seconds (a quest may unlock with a level), each player in its
-- own phase; the ones near the window are picked on each new cell.
local SLOW = 5.0
local MARKER_SLOTS, PARTY_SLOTS = 24, 9
-- Drawn sizes in HUD pixels (scaled with HUD scaling like every HUD image).
local ICON, PARTY_ARROW, RIM_ARROW, PLAYER_ARROW = 16, 20, 16, 24
local BEZEL = "grug_map_minimap_bezel.png"
local BEZEL_PX = 256
local SEA = "#1c3a52"
-- Kinds shown (ruling 8); settlements, camps, kings and dragons stay on the
-- Map tab only.
local SHOWN = {quest = true, steward = true, trainer = true, innkeeper = true,
	home = true}
local QUEST_TEXTURE = {available = "grug_map_quest_available.png",
	locked = "grug_map_quest_locked.png", ready = "grug_map_quest_ready.png",
	active = "grug_map_quest_active.png"}
local KIND_TEXTURE = {innkeeper = "grug_map_innkeeper.png", home = "grug_map_home.png"}
-- Which markers keep a slot when more than MARKER_SLOTS are in the circle.
local PRIORITY = {quest = 1, steward = 2, home = 3, innkeeper = 4, trainer = 5}
local Z = {background = 10, map = 11, marker = 20, bezel = 45, party = 50, player = 60}

local base, view -- set by M.install
local players = {}
-- `bytes` estimates what the hud_changes cost on the wire: a reliable
-- TOCLIENT_HUDCHANGE is about 18 bytes of headers plus its value.
M.stats = {updates = 0, us = 0, changes = 0, bytes = 0, textures = 0}
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
-- pixel more keeps the whole pixel.
local function exact(px, texture_px, frame)
	return (px + 0.25) / (texture_px * frame.hud)
end

local function remove(player, state)
	if not state.hud then return end
	for _, element in ipairs(state.hud.all) do player:hud_remove(element.id) end
	state.hud = nil
end

local function create(player, state)
	local hud = {background = image(player, Z.background, true),
		map = image(player, Z.map, true), bezel = image(player, Z.bezel, true),
		markers = {}, party = {}}
	for i = 1, MARKER_SLOTS do hud.markers[i] = image(player, Z.marker + i) end
	for i = 1, PARTY_SLOTS do hud.party[i] = image(player, Z.party + i) end
	-- The player's arrow is a compass element: the client turns it with the
	-- view every frame, so turning around sends nothing; it stays centred.
	hud.player = {id = player:hud_add({type = "compass", position = {x = 0, y = 0},
		alignment = {x = 0, y = 0}, size = {x = 1, y = 1}, direction = 0,
		text = "grug_map_heading_gold_00.png", z_index = Z.player}), x = 0, y = 0, size = 0}
	hud.all = {hud.background, hud.map, hud.bezel, hud.player}
	for _, list in ipairs({hud.markers, hud.party}) do
		for _, element in ipairs(list) do hud.all[#hud.all + 1] = element end
	end
	state.hud, state.cell_x, state.cell_y, state.static = hud, nil, nil, nil
	state.near, state.box = nil, nil
end

-- The markers that do not move by themselves (ruling 8): quest givers with
-- their state, the Steward, trainers, innkeepers and home.
local PROVIDERS = {quest = true, service = true, home = true}
local function static_markers(player)
	local result = {}
	for _, marker in ipairs(atlas.collect_markers(player, PROVIDERS)) do
		if SHOWN[marker.kind] then
			local texture = marker.kind == "quest" and QUEST_TEXTURE[marker.status] or
				KIND_TEXTURE[marker.kind] or marker.texture
			if texture then
				result[#result + 1] = {x = marker.position.x, z = marker.position.z,
					texture = texture, kind = marker.kind}
			end
		end
	end
	return result
end

-- The other members' names, asked from grug_parties only when the party
-- changes (or on the SLOW refresh); positions are read every step.
local function party_members(player, state)
	local name = player:get_player_name()
	if not state.party then
		state.party = {}
		local group = grug_parties.view(player)
		for _, member in ipairs(group and group.members or {}) do
			if member.name ~= name then state.party[#state.party + 1] = member.name end
		end
	end
	local result = {}
	for _, member in ipairs(state.party) do
		local other = core.get_player_by_name(member)
		if other then
			local pos = other:get_pos()
			result[#result + 1] = {x = pos.x, z = pos.z,
				frame = atlas.heading_frame(other:get_look_horizontal())}
		end
	end
	return result
end

-- Every element resends its position on the next show: after a window
-- change the same pixel is a different fraction of the window.
local function forget_positions(hud)
	for _, element in ipairs(hud.all) do element.x, element.y = nil, nil end
end

local function update(player, state, slow)
	if state.enabled == nil then state.enabled = M.enabled(player) end
	if not state.enabled then
		remove(player, state)
		return 0
	end
	if not state.hud then create(player, state) end
	local hud, changes = state.hud, 0
	local box = layout.minimap_box(core.get_player_window_information(player:get_player_name()))
	local last = state.box
	if not last or last.size ~= box.size or last.center_x ~= box.center_x or
			last.center_y ~= box.center_y or last.hud ~= box.hud or
			last.width ~= box.width or last.height ~= box.height then
		state.box, state.frame = box, V.frame(view, box)
		forget_positions(hud)
	end
	local frame = state.frame
	local pos = player:get_pos()
	local cx, cy = V.cell(view, pos.x, pos.z)
	if cx ~= state.cell_x or cy ~= state.cell_y then
		state.cell_x, state.cell_y = cx, cy
		state.ox, state.oy = V.origin(view, cx, cy)
		state.texture = V.texture(view, state.ox, state.oy, M.mask)
		state.near = nil
		M.stats.textures = M.stats.textures + 1
	end
	if slow or not state.static then
		state.static, state.near, state.party = static_markers(player), nil, nil
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
	-- lines up with the old one to the pixel.
	local px, py = V.base_pixel(view, pos.x, pos.z)
	local mx, my = V.map_corner(view, frame, state.ox, state.oy, px, py)
	changes = changes + show(player, frame, hud.map, state.texture, mx, my,
		exact(frame.drawn, view.texture, frame))
	local sea = math.floor(frame.hole + 2)
	changes = changes + show(player, frame, hud.background,
		M.mask .. "^[multiply:" .. SEA, frame.center_x - sea, frame.center_y - sea,
		exact(2 * sea, view.texture, frame))
	changes = changes + show(player, frame, hud.bezel, BEZEL,
		frame.center_x - frame.diameter / 2, frame.center_y - frame.diameter / 2,
		exact(frame.diameter, BEZEL_PX, frame))

	local hud_px = frame.hud
	local limit = frame.hole - ICON / 2 * hud_px
	local visible = {}
	for index, marker in ipairs(state.near) do
		local x, y, distance = V.place(view, frame, state.ox, state.oy, mx, my,
			marker.x, marker.z)
		if distance <= limit then
			visible[#visible + 1] = {marker = marker, x = x, y = y, order = index}
		end
	end
	if #visible > MARKER_SLOTS then
		-- More markers than slots: keep the most important ones (quest givers
		-- first; party members have slots of their own), then draw the kept
		-- ones in their usual order.
		table.sort(visible, function(a, b)
			local pa, pb = PRIORITY[a.marker.kind] or 9, PRIORITY[b.marker.kind] or 9
			if pa ~= pb then return pa < pb end
			return a.order < b.order
		end)
		for i = #visible, MARKER_SLOTS + 1, -1 do visible[i] = nil end
		table.sort(visible, function(a, b) return a.order < b.order end)
	end
	for i, row in ipairs(visible) do
		local texture = row.marker.texture
		changes = changes + show(player, frame, hud.markers[i], texture, row.x, row.y,
			ICON / texture_size(texture))
	end
	for i = #visible + 1, MARKER_SLOTS do
		changes = changes + show(player, frame, hud.markers[i], "")
	end

	local party = party_members(player, state)
	local inside = frame.hole - PARTY_ARROW / 2 * hud_px
	for i = 1, PARTY_SLOTS do
		local member = party[i]
		if not member then
			changes = changes + show(player, frame, hud.party[i], "")
		else
			local x, y, distance = V.place(view, frame, state.ox, state.oy, mx, my,
				member.x, member.z)
			if distance <= inside then
				changes = changes + show(player, frame, hud.party[i],
					("grug_map_heading_cyan_%02d.png"):format(member.frame), x, y,
					PARTY_ARROW / 32)
			else
				-- On the bezel, above it and its N plate (a party member due
				-- north matters more than the letter), never wider than the ring.
				local rx, ry, index = V.rim(frame, x - frame.center_x, y - frame.center_y)
				local ring = frame.diameter / 2 - frame.hole
				local px = math.min(RIM_ARROW * hud_px, 0.8 * ring)
				changes = changes + show(player, frame, hud.party[i],
					("grug_map_rim_cyan_%02d.png"):format(index), rx, ry, px / (32 * hud_px))
			end
		end
	end

	-- The arrow sits at the centre; the compass element's size is in raw
	-- pixels.
	local x = math.floor(frame.center_x + 0.5)
	local y = math.floor(frame.center_y + 0.5)
	local arrow = math.floor(PLAYER_ARROW * hud_px + 0.5)
	local element = hud.player
	if element.x ~= x or element.y ~= y then
		player:hud_change(element.id, "position", {x = x / frame.width, y = y / frame.height})
		element.x, element.y, changes = x, y, changes + sent(8)
	end
	if element.size ~= arrow then
		player:hud_change(element.id, "size", {x = arrow, y = arrow})
		element.size, changes = arrow, changes + sent(8)
	end
	return changes
end

-- Redraw one player's minimap now (the Map tab's switch, a quest change).
function M.refresh(player)
	local state = players[player:get_player_name()]
	if state and view then update(player, state, true) end
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

-- Called from init.lua with base.lua's result. Without tiles (the base failed
-- to render) or without its mask (the world folder cannot be written) the
-- native minimap stays off and ours is not shown; the Map tab says so.
function M.install(installed)
	if not installed.tiles then return end
	local candidate = V.new(installed, atlas.view())
	local ok, err = pcall(function()
		grug_map.base.add_media(grug_map.base.MASK,
			grug_map.base.mask_png(candidate.texture, 0))
	end)
	if not ok then
		core.log("error", "[grug_map] minimap unavailable: " .. tostring(err))
		return
	end
	base, view, M.mask = installed, candidate, grug_map.base.MASK
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

-- Each player's SLOW refresh has its own phase, so the marker providers are
-- not asked for every player in the same step: players joining one after
-- another start JOIN_PHASE seconds apart (SLOW / JOIN_PHASE phases).
local JOIN_PHASE = 0.2
local joined = 0
core.register_on_joinplayer(function(player)
	native_off(player)
	joined = joined + 1
	players[player:get_player_name()] = {slow = (joined * JOIN_PHASE) % SLOW}
end)
core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)
grug_parties.register_on_change(function(name)
	local state = players[name]
	if state then state.party = nil end
end)
grug_quests.register_on_change(function(player)
	local state = player and players[player:get_player_name()]
	if state then state.static = nil end
end)

core.register_globalstep(function(dtime)
	if not view then return end
	for _, player in ipairs(core.get_connected_players()) do
		local state = players[player:get_player_name()]
		if state then
			state.slow = (state.slow or 0) + dtime
			local is_slow = state.slow >= SLOW
			if is_slow then state.slow = state.slow % SLOW end
			local started = core.get_us_time()
			local changes = update(player, state, is_slow)
			M.stats.updates = M.stats.updates + 1
			M.stats.us = M.stats.us + (core.get_us_time() - started)
			M.stats.changes = M.stats.changes + changes
		end
	end
end)
