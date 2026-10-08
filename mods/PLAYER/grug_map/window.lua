-- The map window (Round 44, the UI rework spec rulings 10, 12 and 14, §3.6;
-- docs/design/world_map.md "Map window"): its own formspec, opened by Z
-- (grug_keys' zoom edge) and by the Map tab, sized to FRACTION of the
-- player's max_formspec_size (core.get_player_window_information) with a
-- fixed fallback. Left the map with its overlay and the quest targets of
-- the selected quest, right the quest boxes (quest_box.lua); a header row
-- with the zoom, the location, the minimap switch, "Back to inventory" and
-- the close button.
--
-- The overlay (ruling 12, with the user's additions of 2026-10-08) is plain
-- image[] elements: the player's and the party's arrows, the home,
-- discovered waystones, the own faction's trainers (two thirds size at zoom
-- 1x and 2x), Housing Stewards, capital services and innkeepers, and a
-- question mark at the NPC of each active quest (silver in progress, gold
-- ready to hand in) with the NPC's name as its only tooltip. Settlements,
-- camps, bosses and region names are pixels of the base image (bake.lua);
-- of the other faction nothing is drawn beyond that baked layer except the
-- selected quest's own targets.
--
-- Refresh (spec §3.6): event-driven. A click, zoom, quest selection or a
-- quest change sends the window again, at most once per SEND_GAP_US per
-- player; an event inside that gap is owed and goes out when the gap ends
-- (the trailing send). In a party the arrows are checked every PARTY_US and
-- the window is sent only when a member's arrow moved. Alone, nothing is
-- sent without an event. A scrollbar move never sends (the client moves the
-- image and the overlay together; the server keeps the position and echoes
-- it on the next send) and holds every send for QUIET_US.
local modpath = core.get_modpath(core.get_current_modname())
local atlas = grug_map.atlas
local targets = dofile(modpath .. "/targets.lua")
local quest_box = dofile(modpath .. "/quest_box.lua")

local W = {}
grug_map.window = W
W.FORMNAME = "grug_map:window"
-- 80-90 % of the largest formspec the client shows unshrunk (ruling 10);
-- the fallback for clients that do not report it (before 5.7); a floor
-- under which the layout would not fit (the client shrinks a form larger
-- than its screen itself).
W.FRACTION = 0.85
W.FALLBACK = {x = 20, y = 12}
W.MIN = {x = 16, y = 10}
W.SEND_GAP_US = 1000000
W.PARTY_US = 5000000
-- A scrollbar move holds every send for QUIET_US (the old Map tab's rule):
-- a form rebuilt while the player drags the scrollbar would break the drag.
W.QUIET_US = 500000
local PASS = 0.1

-- Layout in real coordinates: the header row, the 9:8 map with its
-- scrollbars, the quest column (at least COLUMN_MIN wide, COLUMN_SHARE of
-- the window, plus whatever the map's aspect leaves).
local PAD, HEADER_H, GAP, BAR, BAR_GAP = 0.25, 0.6, 0.3, 0.3, 0.05
local COLUMN_MIN, COLUMN_SHARE = 6.5, 0.3
-- Overlay sizes in formspec units, constant at every zoom (only positions
-- scale): icons as before Round 44, trainers two thirds at 1x and 2x
-- (ruling 12), arrows, the crosshair; rings at least RING_MIN across.
-- RING_MIN (the user, 2026-10-08: a ring clearly visible at zoom 1): the
-- ring texture is 32 px with a 1 px line, so below 32 screen pixels
-- nearest-neighbour scaling drops parts of the line. 0.7 units are about
-- 50 px at 1080p and 37 px at 720p (GUI scale 1, 72 and 53 px per unit),
-- about twice an icon.
local ICON, TRAINER_SMALL, ARROW, CROSSHAIR, RING_MIN = 0.34, 0.23, 0.42, 0.5, 0.7
-- Arrows sit on a grid of ARROW_STEP units (about a screen pixel); the
-- party check compares these cells, so a move inside one sends nothing.
local ARROW_STEP = 0.02
local RING = "grug_map_ring.png^[multiply:#ff8c1a^[opacity:190"
local QUEST_TEXTURE = {active = "grug_map_quest_active.png", ready = "grug_map_quest_ready.png"}
local SCROLL_X, SCROLL_Y = "grug_map_scroll_x", "grug_map_scroll_y"
local SCROLLBAR_DEFAULTS = "scrollbaroptions[min=0;max=1000;smallstep=10;" ..
	"largestep=100;thumbsize=1;arrows=default]"

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- The window's size {w, h} for a window information table (or nil).
function W.window_size(info)
	local max = type(info) == "table" and info.max_formspec_size
	local w, h = W.FALLBACK.x, W.FALLBACK.y
	if type(max) == "table" and type(max.x) == "number" and type(max.y) == "number" and
			max.x > 0 and max.y > 0 then
		w, h = max.x * W.FRACTION, max.y * W.FRACTION
	end
	w, h = math.max(W.MIN.x, w), math.max(W.MIN.y, h)
	return math.floor(w * 100) / 100, math.floor(h * 100) / 100
end

-- Where everything sits in a w x h window.
function W.layout(w, h)
	local map_y = PAD + HEADER_H + 0.2
	local avail_h = h - map_y - PAD - BAR - BAR_GAP
	local column = math.max(COLUMN_MIN, w * COLUMN_SHARE)
	local avail_w = w - 2 * PAD - BAR - BAR_GAP - GAP - column
	local map_w = math.min(avail_w, avail_h * 9 / 8)
	local map_h = map_w * 8 / 9
	local column_x = PAD + map_w + BAR_GAP + BAR + GAP
	return {w = w, h = h, map_x = PAD, map_y = map_y, map_w = map_w, map_h = map_h,
		column = {x = column_x, y = map_y, w = w - PAD - column_x, h = h - PAD - map_y}}
end

--
-- The quest target index (targets.lua), built once every region map is
-- ready (grug_mobs builds them in its own mods-loaded hook, which runs
-- first: grug_map depends on grug_mobs).
--
local index, index_stats = {roles = {}, areas = {}, leaders = {}, entries = 0}, nil
local CELL = 32
core.register_on_mods_loaded(function()
	local SR = grug_mobs.spawn_regions
	CELL = SR.core and SR.core.CELL or CELL
	local started = core.get_us_time()
	index = targets.build({
		zone_ids = SR.zone_ids,
		map = function(zone) return SR.zone_has_recipe(zone) and SR.map(zone) or nil end,
		leader_roles = SR.leader_roles,
		leader_pos = SR.leader_pos,
	})
	index_stats = targets.size(index)
	index_stats.ms = (core.get_us_time() - started) / 1000
	core.log("action", ("[grug_map] quest target index: %d roles, %d regions, %d areas, " ..
		"%d leaders in %.1f ms"):format(index_stats.roles, index_stats.entries,
		index_stats.areas, index_stats.leaders, index_stats.ms))
end)
grug_map.quest_targets = {
	stats = function() return index_stats or targets.size(index) end,
	index = function() return index end,
}

--
-- The window's content
--

local function current_zone(player)
	if not grug_core.zone_authority_installed() then return "World map loading" end
	local text = grug_map.location and grug_map.location.text_of(player) or ""
	if text ~= "" then return text end
	local zone = grug_zones.at(player:get_pos())
	return zone and zone.display_name or "Open sea"
end

-- An arrow's place on the zoomed map as whole ARROW_STEPs, or nil off the
-- map.
local function arrow_cell(view, position, layout, zoom)
	local sx, sy = atlas.world_to_screen(view, position, 0, 0, layout.map_w * zoom,
		layout.map_h * zoom)
	if not sx then return nil end
	return math.floor(sx / ARROW_STEP + 0.5), math.floor(sy / ARROW_STEP + 0.5)
end

-- The markers of the overlay (ruling 12) from the providers: player and
-- party arrows, the home, waystones, trainers and (the user, 2026-10-08)
-- the Housing Steward, the capital services and the innkeepers, each NPC of
-- the own faction only (providers.lua), like the minimap; no zone markers.
local PROVIDERS = {player = true, party = true, home = true, waypoint = true, service = true}
local KINDS = {player = true, party = true, home = true, waypoint = true, trainer = true,
	steward = true, service = true, innkeeper = true}
local KIND_TEXTURE = {home = "grug_map_home.png", innkeeper = "grug_map_innkeeper.png"}
function W.overlay_markers(player)
	local result = {}
	for _, marker in ipairs(atlas.collect_markers(player, PROVIDERS)) do
		if KINDS[marker.kind] then result[#result + 1] = marker end
	end
	return result
end

-- The question marks (ruling 12): the hand-in NPC of every active quest,
-- gold when one of its quests is ready, else silver; own faction only.
-- {{id, title, position, status}} in id order.
function W.quest_marks(player, journal)
	local faction = grug_factions.get_faction(player) or ""
	local by_id, ids = {}, {}
	for _, quest in ipairs(journal.quests) do
		local npc = grug_map.quest_npc(quest.npc)
		if npc and grug_map.marker_visible(npc, faction) then
			local mark = by_id[npc.id]
			if not mark then
				mark = {id = npc.id, title = npc.title, position = npc.position, status = "active"}
				by_id[npc.id] = mark
				ids[#ids + 1] = npc.id
			end
			if quest.ready then mark.status = "ready" end
		end
	end
	table.sort(ids)
	local result = {}
	for k, id in ipairs(ids) do result[k] = by_id[id] end
	return result
end

-- Settlement key -> anchor (a garrison camp's place), built on first need.
local anchors
local function anchor_of(key)
	if not anchors then
		anchors = {}
		for _, row in ipairs(grug_core.settlement_socket_settlements()) do anchors[row.key] = row.anchor end
	end
	return anchors[key]
end
-- Roles outside the region maps that have a place of their own: the rift
-- boss at his clash site (grug_mobs rift.lua).
local ROLE_PLACES = {
	rift_boss = function()
		local rules = grug_mobs.rift_rules
		return rules and grug_mobs.spawn_regions.place(rules.SITE) or nil
	end,
}
local lookup = {
	npc = function(id)
		local npc = grug_map.quest_npc(id)
		return npc and npc.position or nil
	end,
	place = function(ref) return grug_quests.use_place_xz(ref) end,
	area = function(ref) return anchor_of(ref:match("/(.+)$") or ref) end,
	role = function(role) return ROLE_PLACES[role] and ROLE_PLACES[role]() or nil end,
}
W.target_lookup = lookup

-- The selected quest's targets for the player (targets.lua), or nil.
function W.quest_targets(player, quest)
	if not quest then return nil end
	local def = grug_quests.registered_quests[quest.id]
	if not def then return nil end
	return targets.targets(index, def, quest.objectives, player:get_pos(), lookup)
end

local function image(list, sx, sy, size, texture)
	list[#list + 1] = ("image[%.3f,%.3f;%.3f,%.3f;%s]"):format(sx - size / 2, sy - size / 2,
		size, size, esc(texture))
end

-- The overlay inside the map's scroll containers, bottom to top: rings,
-- trainers, home and waystones, question marks (with their tooltips),
-- crosshairs, party arrows, the player's arrow.
local function overlay(fs, player, session, layout, journal, quest)
	local zoom = session.zoom or 1
	local view = atlas.view()
	local mw, mh = layout.map_w * zoom, layout.map_h * zoom
	local function at(position)
		return atlas.world_to_screen(view, position, 0, 0, mw, mh)
	end
	local rings, icons, marks, crosses, arrows = {}, {}, {}, {}, {}
	local found = W.quest_targets(player, quest)
	session.target_count = 0
	if found then
		local units = mw / (view.max_x - view.min_x)
		for _, ring in ipairs(found.rings) do
			local sx, sy = at(ring)
			if sx then
				local size = math.max(RING_MIN, 2 * targets.ring_radius(ring.size, CELL) * units)
				image(rings, sx, sy, size, RING)
				session.target_count = session.target_count + 1
			end
		end
		for _, spot in ipairs(found.crosshairs) do
			local sx, sy = at(spot)
			if sx then
				image(crosses, sx, sy, CROSSHAIR, "grug_map_crosshair.png")
				session.target_count = session.target_count + 1
			end
		end
	end
	for _, marker in ipairs(W.overlay_markers(player)) do
		local arrow = marker.kind == "player" or marker.kind == "party"
		if arrow then
			local cx, cy = arrow_cell(view, marker.position, layout, zoom)
			if cx then
				local tint = marker.kind == "player" and "gold" or "cyan"
				image(arrows, cx * ARROW_STEP, cy * ARROW_STEP, ARROW,
					("grug_map_heading_%s_%02d.png"):format(tint, atlas.heading_frame(marker.heading)))
			end
		else
			local sx, sy = at(marker.position)
			if sx then
				local texture = KIND_TEXTURE[marker.kind] or marker.texture
				local size = marker.kind == "trainer" and zoom <= 2 and TRAINER_SMALL or ICON
				if texture then image(icons, sx, sy, size, texture) end
			end
		end
	end
	for _, mark in ipairs(W.quest_marks(player, journal)) do
		local sx, sy = at(mark.position)
		if sx then
			image(marks, sx, sy, ICON, QUEST_TEXTURE[mark.status])
			marks[#marks + 1] = ("tooltip[%.3f,%.3f;%.3f,%.3f;%s]"):format(sx - ICON / 2,
				sy - ICON / 2, ICON, ICON, esc(mark.title))
		end
	end
	for _, list in ipairs({rings, icons, marks, crosses, arrows}) do
		for _, element in ipairs(list) do fs[#fs + 1] = element end
	end
end

-- A new session's state: zoom 1, the map's origin, no quest selection.
function W.new_state()
	return {zoom = 1, scroll_x = 0, scroll_y = 0}
end

-- The whole window for `player` in state `session`, `info` the window
-- information (or nil).
function W.formspec(player, session, info)
	local w, h = W.window_size(info)
	local layout = W.layout(w, h)
	session.layout = layout
	local zoom = session.zoom or 1
	local journal = grug_quests.journal(player)
	local quest = quest_box.selected(journal, session)
	local mw, mh = layout.map_w * zoom, layout.map_h * zoom
	local cy = PAD + HEADER_H / 2
	local right = w - PAD
	local minimap = grug_map.minimap.available() and
		("checkbox[%.2f,%.2f;grug_map_minimap;Show minimap;%s]"):format(right - 7.1, cy,
			tostring(grug_map.minimap.enabled(player))) or
		("label[%.2f,%.2f;No minimap available]"):format(right - 7.1, cy)
	local fs = {
		-- max_formspec_size assumes no padding (lua_api.md); the default 0.05
		-- would shrink the form to about 76 % of the screen.
		("formspec_version[6]size[%.2f,%.2f]padding[0,0]"):format(w, h),
		("label[%.2f,%.2f;Map]"):format(PAD, cy),
		("button[1.0,%.2f;0.6,0.6;grug_map_zoom_out;-]"):format(PAD),
		("label[1.75,%.2f;%dx]"):format(cy, zoom),
		("button[2.35,%.2f;0.6,0.6;grug_map_zoom_in;+]"):format(PAD),
		("label[3.3,%.2f;Current: %s]"):format(cy, esc(current_zone(player))),
		minimap,
		("button[%.2f,%.2f;3.2,0.6;grug_map_back;Back to inventory]"):format(right - 3.95, PAD),
		("button_exit[%.2f,%.2f;0.6,0.6;grug_map_close;X]"):format(right - 0.6, PAD),
		("scroll_container[%.3f,%.3f;%.3f,%.3f;%s;horizontal;%.5f]"):format(layout.map_x,
			layout.map_y, layout.map_w, layout.map_h, SCROLL_X, layout.map_w / 1000),
		-- The inner clipper spans the full scaled width so horizontal scrolling
		-- cannot expose an empty strip after leaving the first viewport.
		("scroll_container[0,0;%.3f,%.3f;%s;vertical;%.5f]"):format(mw, layout.map_h,
			SCROLL_Y, layout.map_h / 1000),
		("image[0,0;%.3f,%.3f;%s]"):format(mw, mh, esc(atlas.view().texture)),
	}
	overlay(fs, player, session, layout, journal, quest)
	fs[#fs + 1] = "scroll_container_end[]scroll_container_end[]"
	-- Scrollbar values are transport state: echoed from the last event.
	local limit = atlas.scroll_limit(zoom)
	fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=40;largestep=900;thumbsize=%d;arrows=hide]"):
		format(limit, math.max(1, math.floor((limit + 1) / zoom)))
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.3f,%.2f;horizontal;%s;%d]"):format(layout.map_x,
		layout.map_y + layout.map_h + BAR_GAP, layout.map_w, BAR, SCROLL_X, session.scroll_x or 0)
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.2f,%.3f;vertical;%s;%d]"):format(
		layout.map_x + layout.map_w + BAR_GAP, layout.map_y, BAR, layout.map_h, SCROLL_Y,
		session.scroll_y or 0)
	fs[#fs + 1] = SCROLLBAR_DEFAULTS
	fs[#fs + 1] = quest_box.content(session, journal, layout.column)
	return table.concat(fs)
end

--
-- Sessions, sends and the refresh rule
--

-- player name -> session: the window state (zoom, scroll, quest selection),
-- kept between opens until the player leaves; open (see is_open), sent
-- (the last send's core.get_us_time), pending (a send is owed),
-- quiet_until (no send before this, after a scrollbar move), party_sig
-- (the arrows at the last send), party_checked, sends (a counter for
-- probes).
local sessions = {}
W.sessions = sessions

-- The window is open from a send or any other event of it until its quit
-- or until any other form is shown: another form, the death screen, the
-- inventory ("Back to inventory") or a close of every form replace it
-- silently, and a refresh must never pop it back over them (or over the
-- game once that form is closed). Every form the server shows passes the
-- wrapper below, which closes the session. A send that crosses a close
-- shows the window again while its quit arrives after it; the next event
-- of the window then proves it is shown and marks it open again.
-- default/node_formspec.lua's shown_form is the backstop: a form other
-- than the window there always means closed.
function W.is_open(name)
	local session = sessions[name]
	if not session or not session.open then return false end
	local shown = default.node_formspec.shown_form(name)
	if shown ~= nil and shown ~= W.FORMNAME then
		session.open = false
		return false
	end
	return true
end

-- Any other form shown (or every form closed) ends the window's session.
local show_formspec = core.show_formspec
function core.show_formspec(playername, formname, formspec)
	local session = sessions[playername]
	if session and formname ~= W.FORMNAME and (formspec ~= "" or formname == "") then
		session.open = false
	end
	return show_formspec(playername, formname, formspec)
end

-- The party's arrow cells ("" outside a party): the party check sends only
-- when this differs from the last send's.
function W.party_signature(player, session)
	if not grug_parties.in_party(player) then return "" end
	local group = grug_parties.view(player)
	local layout, zoom, view = session.layout, session.zoom or 1, atlas.view()
	local parts = {}
	for _, member in ipairs(group and group.members or {}) do
		local other = member.online and core.get_player_by_name(member.name)
		if other and layout then
			local x, y = arrow_cell(view, other:get_pos(), layout, zoom)
			parts[#parts + 1] = member.name .. "@" .. tostring(x) .. "," .. tostring(y)
		end
	end
	return table.concat(parts, "|")
end

-- Whether a send may go out now; otherwise it is owed (pending) and the
-- pass sends it once SEND_GAP_US has passed since the last one.
function W.may_send(session, now)
	if now >= (session.quiet_until or 0) and
			(not session.sent or now - session.sent >= W.SEND_GAP_US) then
		return true
	end
	session.pending = true
	return false
end

local function send(player, session, now)
	local name = player:get_player_name()
	local form = W.formspec(player, session, core.get_player_window_information(name))
	session.sent, session.pending, session.open = now, false, true
	session.party_sig = W.party_signature(player, session)
	session.sends = (session.sends or 0) + 1
	session.bytes = #form
	core.show_formspec(name, W.FORMNAME, form)
end

-- Something the open window shows changed: send it (now or owed).
function W.request(player)
	local name = player:get_player_name()
	local session = sessions[name]
	if not session or not W.is_open(name) then return end
	if session.busy then
		session.dirty = true
		return
	end
	local now = core.get_us_time()
	if W.may_send(session, now) then send(player, session, now) end
end

-- The pass (every PASS seconds) serves the open windows that are due: an
-- owed send once SEND_GAP_US has passed since the last, else in a party the
-- arrows' check every PARTY_US after the last check or send. Longest
-- waiting first, at most CHECKS_PER_PASS party checks and BUILDS_PER_PASS
-- sends per pass (AGENTS.md: no pass handles every player in one step), so
-- many windows opened together drift apart; a send the budget defers stays
-- owed and is first in the next pass.
W.CHECKS_PER_PASS, W.BUILDS_PER_PASS = 8, 2
local function due_at(session)
	local at = session.pending and session.sent + W.SEND_GAP_US or
		(session.party_checked or session.sent) + W.PARTY_US
	return math.max(at, session.quiet_until or 0)
end
function W.pass(now)
	local due = {}
	for name, session in pairs(sessions) do
		if session.sent and W.is_open(name) then
			local at = due_at(session)
			local player = now >= at and core.get_player_by_name(name)
			if player then due[#due + 1] = {at = at, name = name, player = player, session = session} end
		end
	end
	table.sort(due, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.name < b.name
	end)
	local builds, checks = 0, 0
	for _, row in ipairs(due) do
		local session = row.session
		if not session.pending then
			if checks < W.CHECKS_PER_PASS then
				checks = checks + 1
				session.party_checked = now
				if W.party_signature(row.player, session) ~= session.party_sig then
					session.pending = true
				end
			end
		end
		if session.pending and builds < W.BUILDS_PER_PASS then
			builds = builds + 1
			send(row.player, session, now)
		end
	end
end

-- Opens the window (Z, the Map tab): always sent at once, at zoom 1 over
-- the whole map, with no quest selected (targets show only after a click).
function W.open(player)
	if sfinv.inventory_suspended(player) or (player:get_hp() or 1) <= 0 then return false end
	local name = player:get_player_name()
	local session = sessions[name] or W.new_state()
	sessions[name] = session
	session.zoom, session.scroll_x, session.scroll_y = 1, 0, 0
	session.quest_selected, session.quest_abandon, session.quest_notice = nil, nil, nil
	session.pending, session.dirty, session.busy, session.party_checked = false, nil, nil, nil
	session.quiet_until = nil
	send(player, session, core.get_us_time())
	return true
end

-- "Back to inventory": the inventory window at its homepage.
function W.back(player)
	local session = sessions[player:get_player_name()]
	if session then session.open = false end
	if sfinv.inventory_suspended(player) then
		core.close_formspec(player:get_player_name(), W.FORMNAME)
		return
	end
	sfinv.set_page(player, sfinv.get_homepage_name(player))
	core.show_formspec(player:get_player_name(), "",
		sfinv.get_formspec(player, sfinv.get_or_create_context(player)))
end

function W.handle_fields(player, fields)
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then return end
	if fields.quit then
		session.open = false
		return
	end
	session.open = true
	-- Every event carries both scrollbars (VAL, or CHG for the moved one):
	-- kept first, so a send below echoes the current view. A scrollbar
	-- event alone changes nothing else and sends nothing; it holds every
	-- send for QUIET_US.
	for _, axis in ipairs({"x", "y"}) do
		local raw = fields["grug_map_scroll_" .. axis]
		local kind, value
		if type(raw) == "string" then kind, value = raw:match("^(%u+):([+-]?%d+)$") end
		if kind == "CHG" or kind == "VAL" then
			session["scroll_" .. axis] = atlas.clamp_scroll(tonumber(value), session.zoom or 1)
		end
		if kind == "CHG" then session.quiet_until = core.get_us_time() + W.QUIET_US end
	end
	if fields.grug_map_back then
		W.back(player)
		return
	end
	local changed = false
	session.busy = true
	if fields.grug_map_minimap and grug_map.minimap.available() then
		grug_map.minimap.set_enabled(player, fields.grug_map_minimap == "true")
		changed = true
	end
	if fields.grug_map_zoom_in or fields.grug_map_zoom_out then
		local old = session.zoom or 1
		local zoom = atlas.step_zoom(old, fields.grug_map_zoom_in ~= nil)
		session.scroll_x = atlas.zoom_scroll(session.scroll_x or 0, old, zoom)
		session.scroll_y = atlas.zoom_scroll(session.scroll_y or 0, old, zoom)
		session.zoom = zoom
		changed = true
	end
	local quest_changed = quest_box.handle(player, session, fields)
	session.busy = nil
	if changed or quest_changed or session.dirty then
		session.dirty = nil
		W.request(player)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= W.FORMNAME then return false end
	W.handle_fields(player, fields)
	return true
end)

-- A quest change (accept, kill credit, abandon, held objective items, a
-- level) while the window is open: the boxes and marks follow.
grug_quests.register_on_markers_changed(function(player) W.request(player) end)

grug_keys.register_on_press("zoom", function(player) W.open(player) end)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < PASS then return end
	elapsed = 0
	W.pass(core.get_us_time())
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)

return W
