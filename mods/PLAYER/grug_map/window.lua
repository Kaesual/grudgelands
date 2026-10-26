-- The map window (Round 44, the UI rework spec rulings 10, 12 and 14, §3.6;
-- docs/design/world_map.md "Map window"): its own formspec, opened by Z
-- (grug_keys' zoom edge) and by the Map tab, sized to FRACTION of the
-- player's max_formspec_size (core.get_player_window_information) with a
-- fixed fallback. Left the map with its overlay and the quest targets of
-- the selected quest, right the quest boxes (quest_box.lua); a header row
-- with the zoom, layer selector, location and minimap switch, below shared
-- inventory navigation and its close button.
--
-- The overlay (Round 47 lane ML, the work package's rulings 1-10; until
-- then Round 44's fixed set) is plain image[] elements with positional
-- tooltips. The player picks ONE marker layer in the toolbar selector
-- (layers.lua: quest givers, bosses, trainers, towns and travel, points of
-- interest, PvP, zone names, none). Selecting a quest is its own mode: only
-- its targets (targets.lua, with objective tooltips) and hand-in NPC are
-- shown. Choosing a layer deselects the quest. In every mode the player's gold arrow and the
-- party's cyan arrows (the member's name as tooltip). Every marker has a
-- tooltip; the client shows the first rect under the pointer
-- (guiFormSpecMenu.cpp drawMenu), so they are sent topmost first. The base
-- image carries only the region names (bake.lua). NPC layers show the own
-- faction only, settlement and place layers both (ruling 5).
--
-- Refresh (spec §3.6): event-driven. A click, zoom, quest selection or a
-- quest change sends the window again, at most once per SEND_GAP_US per
-- player; an event inside that gap is owed and goes out when the gap ends
-- (the trailing send). In a party the arrows are checked every PARTY_US and
-- the window is sent only when a member's arrow moved (every 2 s since
-- Round 47 ruling 8; 5 s before). A layer click is an event like a zoom
-- click. Alone, nothing is
-- sent without an event. A scrollbar move never sends (the client moves the
-- image and the overlay together; the server keeps the position and echoes
-- it on the next send) and holds every send for QUIET_US.
local modpath = core.get_modpath(core.get_current_modname())
local atlas = grug_map.atlas
local targets = dofile(modpath .. "/targets.lua")
local quest_box = dofile(modpath .. "/quest_box.lua")
local layers = dofile(modpath .. "/layers.lua")

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
W.PARTY_US = 2000000
-- A scrollbar move holds every send for QUIET_US (the old Map tab's rule):
-- a form rebuilt while the player drags the scrollbar would break the drag.
W.QUIET_US = 500000
local PASS = 0.1

-- Equal-width map and quest columns beneath one toolbar. The 9:8 image
-- fits and centers at 1x; zoomed artwork uses the full scroll viewport.
local PAD, HEADER_H, GAP, BAR, BAR_GAP = 0.25, 0.6, 0.3, 0.3, 0.05
local COLUMN_SHARE = 0.5
-- Overlay sizes in formspec units, constant at every zoom (only positions
-- scale): icons as before Round 44, trainers two thirds at 1x and 2x
-- (Round 44 ruling 12), arrows, the crosshair; rings at least RING_MIN across.
-- RING_MIN (the user, 2026-10-08: a ring clearly visible at zoom 1): the
-- ring texture is 32 px with a 1 px line, so below 32 screen pixels
-- nearest-neighbour scaling drops parts of the line. 0.7 units are about
-- 50 px at 1080p and 37 px at 720p (GUI scale 1, 72 and 53 px per unit),
-- about twice an icon.
local ICON, TRAINER_SMALL, ARROW, CROSSHAIR, RING_MIN = 0.34, 0.23, 0.42, 0.5, 0.7
-- The former baked icons (settlements, camps, bosses; Round 47): the
-- overlay's size, for the user's pick after the screenshots.
W.PLACE_ICON = 0.34
-- Arrows sit on a grid of ARROW_STEP units (about a screen pixel); the
-- party check compares these cells, so a move inside one sends nothing.
local ARROW_STEP = 0.02
local RING = "grug_map_ring.png^[multiply:#ff8c1a^[opacity:190"
-- A quest marker's texture by its value (grug_quests.marker_states): the
-- status, and a story quest's own (Round 57, "story_<status>").
local QUEST_TEXTURE = {}
for _, status in ipairs({"active", "ready", "available", "locked"}) do
	QUEST_TEXTURE[status] = "grug_map_quest_" .. status .. ".png"
	QUEST_TEXTURE["story_" .. status] = "grug_map_quest_story_" .. status .. ".png"
end
local SCROLL_X, SCROLL_Y = "grug_map_scroll_x", "grug_map_scroll_y"
local SCROLLBAR_DEFAULTS = "scrollbaroptions[min=0;max=1000;smallstep=10;" ..
	"largestep=100;thumbsize=1;arrows=default]"

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- The window's size {w, h} for a window information table (or nil).
function W.window_size(info, header_h)
	local max = type(info) == "table" and info.max_formspec_size
	local w, h = W.FALLBACK.x, W.FALLBACK.y
	if type(max) == "table" and type(max.x) == "number" and type(max.y) == "number" and
			max.x > 0 and max.y > 0 then
		w, h = max.x * W.FRACTION, max.y * W.FRACTION
	end
	w, h = math.max(W.MIN.x, w), math.max(W.MIN.y, h)
	return math.floor(w * 100) / 100, math.floor((h - (header_h or 0)) * 100) / 100
end

-- Geometry inside the body, excluding the shared inventory header.
function W.layout(w, h)
	local map_y = PAD + HEADER_H + 0.2
	local column = (w - 2 * PAD - GAP) * COLUMN_SHARE
	local viewport_w = column - BAR - BAR_GAP
	local viewport_h = h - map_y - PAD - BAR - BAR_GAP
	local map_w = math.min(viewport_w, viewport_h * 9 / 8)
	return {w = w, h = h, map_x = PAD, map_y = map_y,
		map_w = map_w, map_h = map_w * 8 / 9,
		viewport_w = viewport_w, viewport_h = viewport_h,
		column = {x = PAD + column + GAP, y = map_y, w = column, h = h - PAD - map_y}}
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

-- Marker textures by kind where the provider gives none.
local KIND_TEXTURE = {home = "grug_map_home.png", innkeeper = "grug_map_innkeeper.png"}

-- The session's layer (layers.lua), the default for a new or unknown one.
function W.layer_of(session)
	local layer = layers.BY_ID[session.layer or ""]
	if not layer then
		session.layer = layers.DEFAULT
		layer = layers.BY_ID[layers.DEFAULT]
	end
	return layer
end

-- The markers of a layer from its providers (each NPC of the own faction
-- only, providers.lua; settlements and places of both, layers.lua), in draw
-- order: the former baked kinds first in the baked layer's order, then the
-- rest in atlas.collect_markers' order. Zones and None have none.
function W.layer_markers(player, layer)
	if not layer.providers then return {} end
	local rows = atlas.collect_markers(player, layer.providers)
	local keyed = {}
	for index, marker in ipairs(rows) do
		keyed[index] = {marker = marker, rank = layers.ORDER[marker.kind] or math.huge,
			index = index}
	end
	table.sort(keyed, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		return a.index < b.index
	end)
	local result = {}
	for index, row in ipairs(keyed) do result[index] = row.marker end
	return result
end

-- The hand-in NPC of the selected quest (quest mode, ruling 2 and §3; the
-- turn-in of the variant the player took, Round 57): {id, title, position,
-- status} with status "ready" or "active" ("story_ready", "story_active"
-- for a story quest), or nil (an NPC of the other faction stays unmarked,
-- ruling 13 of Round 31).
function W.handin_mark(player, quest)
	local npc = quest and grug_map.quest_npc(quest.npc)
	if not npc or not grug_map.marker_visible(npc, grug_factions.get_faction(player) or "") then
		return nil
	end
	return {id = npc.id, title = npc.title, position = npc.position,
		status = (quest.story and "story_" or "") .. (quest.ready and "ready" or "active")}
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
	-- The targets of the variant the player took (Round 57): its own zone's.
	local variant = grug_quests.variant_of and grug_quests.variant_of(def, {variant = quest.variant})
	if variant then def = {objectives = variant.objectives, zone = variant.zone or def.zone} end
	return targets.targets(index, def, quest.objectives, player:get_pos(), lookup)
end

local function image(list, sx, sy, size, texture)
	list[#list + 1] = ("image[%.3f,%.3f;%.3f,%.3f;%s]"):format(sx - size / 2, sy - size / 2,
		size, size, esc(texture))
end
local function tip(list, sx, sy, size, text)
	if text and text ~= "" then
		list[#list + 1] = ("tooltip[%.3f,%.3f;%.3f,%.3f;%s]"):format(sx - size / 2,
			sy - size / 2, size, size, esc(text))
	end
end

-- The tooltip of quest targets marking `objectives` (indices into the
-- quest's objective rows): one objective line each.
local function objective_lines(quest, objectives)
	local lines = {}
	for _, k in ipairs(objectives or {}) do
		local row = quest.objectives[k]
		if row then lines[#lines + 1] = quest_box.objective_label(row) end
	end
	return table.concat(lines, "\n")
end

-- The overlay inside the map's scroll containers, bottom to top: in quest
-- mode the target rings, the hand-in NPC's question mark and the
-- crosshairs, else the layer's markers or zone labels; then the party's
-- arrows and the player's. Every tooltip after the images, topmost first.
local function overlay(fs, player, session, layout, quest, info)
	local zoom = session.zoom or 1
	local view = atlas.view()
	local mw, mh = layout.map_w * zoom, layout.map_h * zoom
	local function at(position)
		return atlas.world_to_screen(view, position, 0, 0, mw, mh)
	end
	-- Draw lists bottom to top, each with its tooltips.
	local under, icons, marks, crosses, arrows = {}, {}, {}, {}, {}
	local tips = {[under] = {}, [icons] = {}, [marks] = {}, [crosses] = {}, [arrows] = {}}
	session.target_count, session.marker_count = 0, 0
	if quest then
		local found = W.quest_targets(player, quest)
		if found then
			local units = mw / (view.max_x - view.min_x)
			for _, ring in ipairs(found.rings) do
				local sx, sy = at(ring)
				if sx then
					local size = math.max(RING_MIN, 2 * targets.ring_radius(ring.size, CELL) * units)
					image(under, sx, sy, size, RING)
					tip(tips[under], sx, sy, size, objective_lines(quest, ring.objectives))
					session.target_count = session.target_count + 1
				end
			end
			for _, spot in ipairs(found.crosshairs) do
				local sx, sy = at(spot)
				if sx then
					image(crosses, sx, sy, CROSSHAIR, "grug_map_crosshair.png")
					tip(tips[crosses], sx, sy, CROSSHAIR, objective_lines(quest, spot.objectives))
					session.target_count = session.target_count + 1
				end
			end
		end
		local mark = W.handin_mark(player, quest)
		local sx, sy
		if mark then sx, sy = at(mark.position) end
		if sx then
			image(marks, sx, sy, ICON, QUEST_TEXTURE[mark.status])
			tip(tips[marks], sx, sy, ICON, mark.title)
		end
	else
		local layer = W.layer_of(session)
		if layer.zones then
			local metrics = layers.zone_labels.metrics(info, session.zoom)
			for _, zone in ipairs(layers.zones) do
				local sx, sy = at(zone)
				if sx then
					layers.zone_labels.elements(under, sx, sy, zone.name, zone.band, metrics, esc,
						mw, mh)
					session.marker_count = session.marker_count + 1
				end
			end
		end
		for _, marker in ipairs(W.layer_markers(player, layer)) do
			local sx, sy = at(marker.position)
			local texture = marker.kind == "quest" and QUEST_TEXTURE[marker.status] or
				KIND_TEXTURE[marker.kind] or marker.texture
			if sx and texture then
				local size = layers.ORDER[marker.kind] and W.PLACE_ICON or
					(marker.kind == "trainer" and zoom <= 2 and TRAINER_SMALL) or ICON
				image(icons, sx, sy, size, texture)
				tip(tips[icons], sx, sy, size, marker.kind == "quest" and marker.label or marker.detail)
				session.marker_count = session.marker_count + 1
			end
		end
	end
	-- The arrows of every mode (ruling 3): the party's with the member's
	-- name, the player's on top, without a tooltip (§8 default).
	for _, marker in ipairs(atlas.collect_markers(player, layers.ARROWS)) do
		local cx, cy = arrow_cell(view, marker.position, layout, zoom)
		if cx then
			local tint = marker.kind == "player" and "gold" or "cyan"
			image(arrows, cx * ARROW_STEP, cy * ARROW_STEP, ARROW,
				("grug_map_heading_%s_%02d.png"):format(tint, atlas.heading_frame(marker.heading)))
			if marker.kind == "party" then
				tip(tips[arrows], cx * ARROW_STEP, cy * ARROW_STEP, ARROW, marker.label)
			end
		end
	end
	local order = {under, icons, marks, crosses, arrows}
	for _, list in ipairs(order) do
		for _, element in ipairs(list) do fs[#fs + 1] = element end
	end
	local count = 0
	for k = #order, 1, -1 do
		local list = tips[order[k]]
		for i = #list, 1, -1 do
			fs[#fs + 1] = list[i]
			count = count + 1
		end
	end
	session.tooltip_count = count
end

-- Stable layer indices in both modes; the additional quest entry comes last.
local function layer_selector(fs, layout, session, quest_mode)
	local labels, selected = {}, 1
	session.layer_ids = {}
	-- Dropdown values accompany unrelated submissions too. The extra entry
	-- represents quest mode so choosing the current layer is a real change.
	for _, layer in ipairs(layers.LIST) do
		local index = #labels + 1
		labels[index], session.layer_ids[index] = esc(layer.title), layer.id
		if not quest_mode and layer.id == W.layer_of(session).id then selected = index end
	end
	if quest_mode then
		labels[#labels + 1] = "Quest targets"
		selected = #labels
	end
	session.layer_choice = selected
	fs[#fs + 1] = ("dropdown[3.15,%.2f;3.3,0.6;grug_map_layer;%s;%d;true]"):
		format(PAD, table.concat(labels, ","), selected)
	fs[#fs + 1] = "tooltip[grug_map_layer;Choose a map layer — selecting a layer clears the quest selection.]"
end

-- A new session's state: zoom 1, the map's origin, the soft lock on the
-- player (atlas.zoom_view), no quest selection, the default layer.
function W.new_state()
	return {zoom = 1, scroll_x = 0, scroll_y = 0, follow = true, layer = layers.DEFAULT}
end

-- The whole window for `player` in state `session`, `info` the window
-- information (or nil).
function W.formspec(player, session, info)
	local width = W.window_size(info)
    local navigation_layout = grug_inventory.navigation_layout(player, session, width, info)
    local nav, header_h = grug_inventory.navigation(player, session, "grug_map:atlas", width, navigation_layout)
    local w, h = W.window_size(info, header_h)
    local layout = W.layout(w, h)
	session.layout = layout
	local zoom = session.zoom or 1
	local journal = grug_quests.journal(player)
	local quest = quest_box.selected(journal, session)
	local mw, mh = layout.map_w * zoom, layout.map_h * zoom
	local cy = PAD + HEADER_H / 2
	local right = w - PAD
	local minimap = grug_map.minimap.available() and
		("checkbox[%.2f,%.2f;grug_map_minimap;Show minimap;%s]"):format(right - 3.4, cy,
			tostring(grug_map.minimap.enabled(player))) or
		("label[%.2f,%.2f;No minimap available]"):format(right - 3.4, cy)
	local fs = {
		-- max_formspec_size assumes no padding (lua_api.md); the default 0.05
		-- would shrink the form to about 76 % of the screen.
		("formspec_version[6]size[%.2f,%.2f]padding[0,0]"):format(w, h + header_h),
		nav,
		("container[0,%.3f]"):format(header_h),
		-- The inventory key closes a form unless the focused element eats it
		-- (guiFormSpecMenu.cpp OnEvent; edit boxes, read-only ones included,
		-- and textlists do). Without this the engine focuses the quest text
		-- (its first edit box, setInitialFocus) and "i" does nothing. Forced
		-- on every send: a resend never leaves the focus in the quest list.
		-- A focused scrollbar keeps only the arrow keys (they scroll the map).
		("set_focus[%s;true]"):format(SCROLL_X),
		("label[%.2f,%.2f;Map]"):format(PAD, cy),
		("button[1.0,%.2f;0.6,0.6;grug_map_zoom_out;-]"):format(PAD),
		("label[1.75,%.2f;%dx]"):format(cy, zoom),
		("button[2.35,%.2f;0.6,0.6;grug_map_zoom_in;+]"):format(PAD),
		grug_core.ui.prose(6.7, PAD, w - 10.5, 0.65, "Current: " .. current_zone(player), true),
		minimap,
		("scroll_container[%.3f,%.3f;%.3f,%.3f;%s;horizontal;%.5f]"):format(layout.map_x,
			layout.map_y, layout.viewport_w, layout.viewport_h, SCROLL_X,
			atlas.scroll_factor(layout.map_w, layout.viewport_w, zoom)),
		-- The inner clipper spans the full scaled width so horizontal scrolling
		-- cannot expose an empty strip after leaving the first viewport.
		("scroll_container[0,0;%.3f,%.3f;%s;vertical;%.5f]"):format(math.max(mw, layout.viewport_w), layout.viewport_h,
			SCROLL_Y, atlas.scroll_factor(layout.map_h, layout.viewport_h, zoom)),
		("container[%.3f,%.3f]"):format(math.max(0, (layout.viewport_w - mw) / 2),
			math.max(0, (layout.viewport_h - mh) / 2)),
		("image[0,0;%.3f,%.3f;%s]"):format(mw, mh, esc(atlas.view().texture)),
	}
	overlay(fs, player, session, layout, quest, info)
	fs[#fs + 1] = "container_end[]scroll_container_end[]scroll_container_end[]"
	-- Scrollbar values are transport state: echoed from the last event.
	local limit = atlas.scroll_limit(zoom)
	local function bar_options(viewport, image_extent)
		local fraction = math.min(1, viewport / image_extent)
		return ("scrollbaroptions[min=0;max=%d;smallstep=40;largestep=900;thumbsize=%d;arrows=hide]"):
			format(limit, math.max(1, math.floor((limit + 1) * fraction)))
	end
	fs[#fs + 1] = bar_options(layout.viewport_w, mw)
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.3f,%.2f;horizontal;%s;%d]"):format(layout.map_x,
		layout.map_y + layout.viewport_h + BAR_GAP, layout.viewport_w, BAR, SCROLL_X, session.scroll_x or 0)
	fs[#fs + 1] = bar_options(layout.viewport_h, mh)
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.2f,%.3f;vertical;%s;%d]"):format(
		layout.map_x + layout.viewport_w + BAR_GAP, layout.map_y, BAR, layout.viewport_h, SCROLL_Y,
		session.scroll_y or 0)
	fs[#fs + 1] = SCROLLBAR_DEFAULTS
	layer_selector(fs, layout, session, quest ~= nil)
	fs[#fs + 1] = quest_box.content(session, journal, layout.column)
	fs[#fs + 1] = "container_end[]"
	return table.concat(fs)
end

--
-- Sessions, sends and the refresh rule
--

-- player name -> session: the window state (zoom, scroll, follow (the soft
-- lock, atlas.zoom_view), quest selection, the chosen layer), kept between
-- opens until the player leaves (the layer survives an opening, Round 47
-- §8 default: session only); open (see is_open), sent (the last send's
-- core.get_us_time), shown_zoom (its zoom), pending (a send is owed),
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
	session.shown_zoom = session.zoom or 1
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
		math.max(session.party_checked or 0, session.sent) + W.PARTY_US
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
	session.zoom, session.scroll_x, session.scroll_y, session.follow = 1, 0, 0, true
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
	local target, clicked = grug_inventory.navigation_target(player, session, fields)
	if clicked then
		if target and target ~= "grug_map:atlas" then
			session.open, session.pending = false, false
			if not sfinv.inventory_suspended(player) then
				sfinv.set_page(player, target)
				core.show_formspec(name, "", sfinv.get_formspec(player,
					sfinv.get_or_create_context(player)))
			else
				core.close_formspec(name, W.FORMNAME)
			end
		end
		return
	end
	session.open = true
	-- Every event carries both scrollbars (VAL, or CHG for the moved one):
	-- kept first, so a send below echoes the current view. A scrollbar
	-- event alone changes nothing else and sends nothing; it holds every
	-- send for QUIET_US. The player's own scrolling at 2x-8x ends the soft
	-- lock (atlas.zoom_view, atlas.scroll_event).
	if atlas.scroll_event(session, fields[SCROLL_X], fields[SCROLL_Y], session.shown_zoom, session.layout) then
		session.quiet_until = core.get_us_time() + W.QUIET_US
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
		-- The player cannot walk while the window is open: the position at
		-- the click is the soft lock's centre.
		atlas.zoom_view(session, fields.grug_map_zoom_in ~= nil, atlas.view(), player:get_pos(), session.layout)
		changed = true
	end
	-- A layer button (ruling 2): that layer, and the quest deselected.
	local choice = tonumber(fields.grug_map_layer)
	local requested = choice and choice ~= session.layer_choice and
		session.layer_ids and session.layer_ids[choice]
	for _, layer in ipairs(layers.LIST) do
		if fields["grug_map_layer_" .. layer.id] or requested == layer.id then
			if session.layer ~= layer.id or session.quest_selected then
				session.layer = layer.id
                -- Names need room on the half-width map. Enter this layer at
                -- 2x; the normal minus button still restores the whole-world view.
                if layer.zones and (session.zoom or 1) == 1 then
                    atlas.zoom_view(session, true, atlas.view(), player:get_pos(), session.layout)
                end
				quest_box.deselect(session)
				changed = true
			end
			break
		end
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
