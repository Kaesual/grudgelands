local atlas = grug_map.atlas
local active, elapsed = {}, 0
local PAGE = "grug_map:atlas"

-- Keep the shared legacy window sizing/scaling, then draw the map in real units.
-- Engine legacy spacing: 5/4 horizontally, 15/13 vertically, plus window padding
-- and button allowance (guiFormSpecMenu.cpp). Fit the atlas inside that window.
local UI = grug_inventory.UI
local PAGE_W = (UI.width - 1) * 5 / 4 + 1.75
local PAGE_H = (UI.height - 1) * 15 / 13 + 1.75 + 7 / 26
local MAP_Y, GUTTER = 0.85, 0.33
local MAP_W = math.min(PAGE_W - 0.8 - GUTTER, (PAGE_H - MAP_Y - 1.5) * 9 / 8)
local MAP_H = MAP_W * 8 / 9
local MAP_X = (PAGE_W - MAP_W - GUTTER) / 2
local SCROLL_X, SCROLL_Y = "grug_map_scroll_x", "grug_map_scroll_y"
local LABELS = {
	hearthpine = "Hearthpine", dawnmere = "Dawnmere", silverleaf = "Silverleaf",
	stillgrave = "Stillgrave", sunscar = "Sunscar", kapok = "Kapok Cradle",
	dur_brannoc = "Dur Brannoc", highcourt = "Highcourt",
	lethariel = "Lethariel", nhal_veyr = "Nhal Veyr",
	gor_drazhak = "Gor Drazhak", kezamba = "Kezamba",
	copperfell_village = "Copperfell Village",
	copperfell_outpost = "Copperfell Outpost",
	copperfell_bandit_camp = "Copperfell Bandit Camp",
	goldmead_village = "Goldmead Village", goldmead_outpost = "Goldmead Outpost",
	goldmead_bandit_camp = "Goldmead Bandit Camp",
	starbough_village = "Starbough Village", starbough_outpost = "Starbough Outpost",
	starbough_bandit_camp = "Starbough Bandit Camp",
	mournfen_village = "Mournfen Village", mournfen_outpost = "Mournfen Outpost",
	mournfen_bandit_camp = "Mournfen Bandit Camp",
	redtusk_village = "Redtusk Village", redtusk_outpost = "Redtusk Outpost",
	redtusk_bandit_camp = "Redtusk Bandit Camp",
	raincall_village = "Raincall Village", raincall_outpost = "Raincall Outpost",
	raincall_bandit_camp = "Raincall Bandit Camp",
}

-- Region names were baked into the old shipped atlas image. The per-world base
-- carries no text, so they are a formspec layer under the markers, positioned
-- like every marker through world_to_screen (fixed macro layout, world_zones.md
-- §7.1). At whole-world scale 38 zone names would be unreadable.
-- Each row: text, world x, world z, box width, box height (formspec units).
-- The island boxes are narrow so the name wraps onto the island itself.
-- A hypertext box shows a scrollbar (the small dark box right of a name,
-- Round 27 ruling 12) as soon as its text is taller than the box, so the
-- boxes are wide and tall enough for the bold name at the smallest usual
-- window (1280 x 720, where a formspec unit is about 46 px): one line on
-- the mainland, two on the islands, with room for one more wrapped line.
-- The text stays centred.
local REGION_LABELS = {
	{"Dwarven Lands", -1800, -2350, 4.6, 1.3}, {"Human Lands", 0, -2350, 4.6, 1.3},
	{"Elven Lands", 1800, -2350, 4.6, 1.3}, {"Undead Lands", -1800, 2350, 4.6, 1.3},
	{"Orc Lands", 0, 2350, 4.6, 1.3}, {"Troll Lands", 1800, 2350, 4.6, 1.3},
	{"The Contested Front", 0, 0, 4.6, 1.3},
	{"Wyrmglass Crown", -3150, 0, 2.4, 2.0}, {"Stormscale Summit", 3150, 0, 2.4, 2.0},
}
-- The map's width and the region names, for the zone markers' placement
-- (location.lua keeps them clear of every marker and name).
grug_map.page_layout = {map_w = MAP_W, region_labels = REGION_LABELS}
-- Dark text over a light halo of four offset copies reads on land and sea.
local LABEL_TEXT, LABEL_HALO, HALO = "#2a1c10", "#f3e8c8", 0.025
local HALO_OFFSETS = {{-HALO, -HALO}, {HALO, -HALO}, {-HALO, HALO}, {HALO, HALO}}
-- Round 30 ruling (perf review #3): while the tab is open, its arrows and
-- markers are brought up to date at most every REBUILD seconds, and only
-- when the signature below changed. Clicks still answer at once.
local REBUILD_US = 2000000
-- Round 32 (perf review R1): the poll runs every PASS seconds and reads at
-- most CHECKS_PER_PASS signatures and builds at most BUILDS_PER_PASS forms
-- per pass. Viewers that are due wait in the order they fell due, so none
-- starves; a viewer's phase is its own last read or build, so viewers who
-- opened the tab together drift apart once they are served in different
-- passes. A scrollbar move defers a viewer's rebuild by QUIET_US.
local PASS, CHECKS_PER_PASS, BUILDS_PER_PASS = 0.1, 8, 2
local QUIET_US = 500000
-- Player and party arrows are drawn on a grid of ARROW_STEP formspec units
-- (about a screen pixel), so a move changes the form only when it shows.
local ARROW_STEP = 0.02

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function humanize(key)
	local text = tostring(key):gsub("_", " "):gsub("(%a)([%w']*)",
		function(first, rest) return first:upper() .. rest end)
	return text
end

-- Settlement icons per viewer faction (Round 31): settlement_icons.lua
-- holds the rule and the one list of hidden classes.
local icons = dofile(core.get_modpath("grug_map") .. "/settlement_icons.lua")
-- Hostile camps (Round 32 §2.2): a red "X", never the quest giver's gold
-- "!" (an available quest).
local HOSTILE_SYMBOL, HOSTILE_COLOR = "X", "#ff5a4a"

-- The marker lists per viewer faction ("" for a player without one), built
-- once on first use: the registry is complete before any player opens the map.
local settlements_for
local function build_settlement_markers()
	local faction_of_race = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	local rows = grug_core.settlement_socket_settlements()
	settlements_for = {}
	for _, viewer in ipairs({"", unpack(grug_core.faction_ids)}) do
		local list = {}
		for index = 1, #rows do
			local row = rows[index]
			local owner = faction_of_race[row.race_id]
			if icons.visible(row.slot, owner, viewer) then
				local label = row.display_name or LABELS[row.key] or humanize(row.key)
				list[#list + 1] = {id = row.key, label = label, position = row.anchor,
					kind = icons.hostile(row.slot) and "hostile" or "settlement",
					detail = label}
			end
		end
		settlements_for[viewer] = list
	end
end
atlas.register_marker_provider("settlement", function(player)
	if not settlements_for then build_settlement_markers() end
	return settlements_for[player and grug_factions.get_faction(player) or ""] or {}
end)

function grug_map.register_marker_provider(name, callback)
	return atlas.register_marker_provider(name, callback)
end

local function current_zone(player)
	if not grug_core.zone_authority_installed() then return "World map loading" end
	-- The same text as the minimap line and the entry banner (Round 28 M1).
	local text = grug_map.location and grug_map.location.text_of(player) or ""
	if text ~= "" then return text end
	local zone = grug_zones.at(player:get_pos())
	return zone and (zone.display_name or humanize(zone.id)) or "Open sea"
end

-- An arrow's place on the map image as whole ARROW_STEPs, or nil off the map.
local function arrow_cell(view, position, zoom)
	local sx, sy = atlas.world_to_screen(view, position, 0, 0, MAP_W * zoom, MAP_H * zoom)
	if not sx then return nil end
	return math.floor(sx / ARROW_STEP + 0.5), math.floor(sy / ARROW_STEP + 0.5)
end

-- Everything the form shows that can change while the tab is open, read
-- without building the form (Round 30, perf review #3): the zoom, the
-- selection, the location label, the minimap switch, each arrow's grid
-- place and heading frame, the quest markers' version
-- (grug_quests.marker_states), the home (which innkeeper or Claim Stone is
-- marked as home), the discovered waystones and the faction (which NPC
-- markers the player sees, Round 31). Every other marker and label
-- is fixed for the server's run; scroll values are transport state (see
-- page_content).
local function signature(player, context)
	local zoom, view, name = context.grug_map_zoom or 1, atlas.view(), player:get_player_name()
	local parts = {zoom, context.grug_map_selected or "", current_zone(player),
		tostring(grug_map.minimap.available() and grug_map.minimap.enabled(player))}
	local function arrow(other)
		local x, y = arrow_cell(view, other:get_pos(), zoom)
		parts[#parts + 1] = ("%s@%s,%s/%d"):format(other:get_player_name(), tostring(x),
			tostring(y), atlas.heading_frame(other:get_look_horizontal()))
	end
	arrow(player)
	local group = grug_parties.view(player)
	for _, member in ipairs(group and group.members or {}) do
		local other = member.name ~= name and core.get_player_by_name(member.name)
		if other then arrow(other) end
	end
	local _, version = grug_quests.marker_states(player)
	parts[#parts + 1] = version
	local home = grug_home.get(player)
	parts[#parts + 1] = home and home.id or ""
	for _, row in ipairs(grug_home.known_waypoints(player)) do parts[#parts + 1] = row.id end
	-- The faction picks the NPC markers (Round 31, ruling 13) and the
	-- settlement icons.
	parts[#parts + 1] = grug_factions.get_faction(player) or ""
	return table.concat(parts, "|")
end

local function page_content(player, context)
	local zoom = context.grug_map_zoom or 1
	local view = atlas.view()
	local fs = {"real_coordinates[true]",
		-- Focus outside the canvas prevents engine autoScroll from moving to a
		-- focused marker after the form is regenerated (including keyboard focus).
		("label[0.15,0.22;World — %dx]"):format(zoom),
		("label[2.35,0.22;Current: %s]"):format(esc(current_zone(player))),
		-- Round 27 ruling 10: the per-player minimap switch, or a note when
		-- this server has no world map for it.
		grug_map.minimap.available() and
			("checkbox[%.3f,0.26;grug_map_minimap;Show minimap;%s]"):format(PAGE_W - 4.75,
				tostring(grug_map.minimap.enabled(player))) or
			("label[%.3f,0.22;No minimap available]"):format(PAGE_W - 4.75),
		("button[%.3f,0.02;0.60,0.48;grug_map_zoom_out;-]"):format(PAGE_W - 1.72),
		("button[%.3f,0.02;0.60,0.48;grug_map_zoom_in;+]"):format(PAGE_W - 1.02),
		("scroll_container[%s,%s;%s,%s;%s;horizontal;%.5f]"):
			format(MAP_X, MAP_Y, MAP_W, MAP_H, SCROLL_X, MAP_W / 1000),
		-- The inner clipper spans the full scaled width so horizontal scrolling
		-- cannot expose an empty strip after leaving the first viewport.
		("scroll_container[0,0;%s,%s;%s;vertical;%.5f]"):
			format(MAP_W * zoom, MAP_H, SCROLL_Y, MAP_H / 1000),
		("image[0,0;%s,%s;%s]"):format(MAP_W * zoom, MAP_H * zoom,
			esc(view.texture))}
	for index, row in ipairs(REGION_LABELS) do
		local sx, sy = atlas.world_to_screen(view, {x = row[2], z = row[3]},
			0, 0, MAP_W * zoom, MAP_H * zoom)
		local w, h = row[4], row[5]
		-- Clamp the box into the image; the text stays centred in the box.
		local lx = math.max(0, math.min(MAP_W * zoom - w, sx - w / 2))
		local function text(dx, dy, color, suffix)
			fs[#fs + 1] = ("hypertext[%.3f,%.3f;%s,%s;grug_map_region_%d%s;%s]"):
				format(lx + dx, sy - h / 2 + dy, w, h, index, suffix,
				esc("<global halign=center valign=middle color=" .. color ..
					"><b>" .. row[1] .. "</b>"))
		end
		for halo, offset in ipairs(HALO_OFFSETS) do
			text(offset[1], offset[2], LABEL_HALO, "_" .. halo)
		end
		text(0, 0, LABEL_TEXT, "")
	end
	context.grug_map_marker_fields = {}
	local markers = atlas.collect_markers(player)
	context.grug_map_detail = nil
	-- One style[] per look, naming every marker that has it, before the
	-- markers (a style must precede its elements).
	local styles, looks, elements = {}, {}, {}
	local function style(look, field)
		if not styles[look] then styles[look] = {}; looks[#looks + 1] = look end
		local names = styles[look]
		names[#names + 1] = field
	end
	for index = 1, #markers do
		local marker = markers[index]
		local arrow = marker.kind == "player" or marker.kind == "party"
		local sx, sy
		if arrow then
			sx, sy = arrow_cell(view, marker.position, zoom)
			if sx then sx, sy = sx * ARROW_STEP, sy * ARROW_STEP end
		else
			sx, sy = atlas.world_to_screen(view, marker.position, 0, 0, MAP_W * zoom, MAP_H * zoom)
		end
		if sx then
			if marker.id == context.grug_map_selected then
				context.grug_map_detail = marker.detail
			end
			local field = atlas.field_id(marker.id)
			context.grug_map_marker_fields[field] = marker
			if arrow then
				local tint = marker.kind == "player" and "gold" or "cyan"
				local texture = ("grug_map_heading_%s_%02d.png"):format(tint,
					atlas.heading_frame(marker.heading))
				style("border=false", field)
				elements[#elements + 1] = ("image_button[%.3f,%.3f;0.42,0.42;%s;%s;;false;false]"):
					format(sx - 0.21, sy - 0.21, texture, field)
				-- Names stay in the hover/detail text to keep tightly grouped players
				-- legible even at continental scale.
			elseif marker.texture then
				elements[#elements + 1] = ("image_button[%.3f,%.3f;0.34,0.34;%s;%s;;false;false]"):
					format(sx - 0.17, sy - 0.17, esc(marker.texture), field)
			else
				local quest = marker.kind == "quest"
				local symbol = marker.kind == "home" and "H" or
					marker.kind == "innkeeper" and "I" or quest and ((marker.status == "ready" or marker.status == "active")
					and "?" or "!") or (marker.kind == "hostile" and HOSTILE_SYMBOL or "+")
				local color = quest and ((marker.status == "ready" or marker.status == "available")
					and "#ffd700" or "#c0c0c0") or
					(marker.kind == "hostile" and HOSTILE_COLOR or "#ffe9a8")
				style("bgcolor=#2b2118cc;textcolor=" .. color, field)
				elements[#elements + 1] = ("button[%.3f,%.3f;0.32,0.32;%s;%s]"):
					format(sx - 0.16, sy - 0.16, field, symbol)
			end
			elements[#elements + 1] = ("tooltip[%s;%s]"):format(field, esc(marker.detail))
		end
	end
	for _, look in ipairs(looks) do
		fs[#fs + 1] = ("style[%s;%s]"):format(table.concat(styles[look], ","), look)
	end
	for _, element in ipairs(elements) do fs[#fs + 1] = element end
	fs[#fs + 1] = "scroll_container_end[]scroll_container_end[]"
	if not context.grug_map_detail then context.grug_map_selected = nil end
	if context.grug_map_detail then
		fs[#fs + 1] = ("label[0.15,0.62;Selected: %s]"):
			format(esc(context.grug_map_detail:match("[^\n]*")))
	end
	-- Return home lives on the Character page (Round 30 ruling): its live
	-- countdown costs a small form there, not this one.
	-- Scrollbar starting values are transport state, not render semantics:
	-- they stay out of the signature. Only signatures actually sent to the
	-- client may advance session.signature.
	table.insert(fs, 1, "set_focus[" .. (context.grug_map_focus or SCROLL_X) .. ";true]")
	fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=40;largestep=900;thumbsize=%d;arrows=hide]"):
		format(atlas.scroll_limit(zoom), math.max(1, math.floor((atlas.scroll_limit(zoom) + 1) / zoom)))
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.3f,0.28;horizontal;%s;%d]"):
		format(MAP_X, MAP_Y + MAP_H + 0.05, MAP_W, SCROLL_X, context.grug_map_scroll_x or 0)
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;0.28,%.3f;vertical;%s;%d]"):
		format(MAP_X + MAP_W + 0.05, MAP_Y, MAP_H, SCROLL_Y, context.grug_map_scroll_y or 0)
	return table.concat(fs)
end

-- The form and its signature (taken after the content, which may drop a
-- selection whose marker is gone).
local function make_form(player, context)
	local content = page_content(player, context)
	return sfinv.make_formspec(player, context, content, false,
		("formspec_version[4]size[%s,%s]real_coordinates[false]"):
			format(UI.width, UI.height)), signature(player, context)
end

sfinv.register_page(PAGE, {
	title = "Map",
	on_enter = function(self, player, context)
		context.grug_map_focus = SCROLL_X
		context.grug_map_zoom = 1
		context.grug_map_scroll_x, context.grug_map_scroll_y = 0, 0
		context.grug_map_selected, context.grug_map_detail = nil, nil
		active[player:get_player_name()] = {}
	end,
	on_leave = function(self, player)
		active[player:get_player_name()] = nil
	end,
	get = function(self, player, context)
		local form, sig = make_form(player, context)
		local session = active[player:get_player_name()]
		if session then session.signature, session.checked = sig, core.get_us_time() end
		return form
	end,
	on_player_receive_fields = function(self, player, context, fields)
		if fields.quit then
			-- The engine cannot report a later inventory reopen. Returning to
			-- the homepage (Inventory, the "i" page) makes the next Map tab
			-- click an explicit open event.
			sfinv.set_page(player, sfinv.get_homepage_name(player))
			return true
		end
		-- Buttons submit VAL for both axes; a scrollbar movement submits CHG.
		-- Validate both before zoom/home/detail so their redraw uses current scroll.
		for _, axis in ipairs({"x", "y"}) do
			local key = "grug_map_scroll_" .. axis
			local raw = fields[key]
			if type(raw) == "string" then
				local kind, value = raw:match("^(%u+):([+-]?%d+)$")
				if kind == "CHG" or kind == "VAL" then
					if kind == "CHG" then
						context.grug_map_focus = key
						local session = active[player:get_player_name()]
						if session then session.quiet_until = core.get_us_time() + QUIET_US end
					end
					context[key] = atlas.clamp_scroll(tonumber(value), context.grug_map_zoom or 1)
				end
			end
		end
		if fields.grug_map_minimap and grug_map.minimap.available() then
			grug_map.minimap.set_enabled(player, fields.grug_map_minimap == "true")
			sfinv.set_player_inventory_formspec(player, context)
			return true
		end
		if fields.grug_map_zoom_in or fields.grug_map_zoom_out then
			local old = context.grug_map_zoom or 1
			local zoom = atlas.step_zoom(old, fields.grug_map_zoom_in ~= nil)
			context.grug_map_scroll_x = atlas.zoom_scroll(context.grug_map_scroll_x or 0, old, zoom)
			context.grug_map_scroll_y = atlas.zoom_scroll(context.grug_map_scroll_y or 0, old, zoom)
			context.grug_map_zoom = zoom
			sfinv.set_player_inventory_formspec(player, context)
			return true
		end
		for field, marker in pairs(context.grug_map_marker_fields or {}) do
			if fields[field] then
				context.grug_map_detail = marker.detail
				context.grug_map_selected = marker.id
				sfinv.set_player_inventory_formspec(player, context)
				return true
			end
		end
	end,
})

-- Only an explicit tab-entry session is polled. Updating the cached inventory
-- form does not open a menu; the client updates it in place if it is visible
-- (lua_api.md, set_inventory_formspec). Stable button names survive rebuilds.
-- The signature is read at most every REBUILD_US after the last read or
-- build, and the form is built only when it changed; each pass serves the
-- longest-waiting due viewers within its budget (PASS above).
local function longest_waiting(a, b)
	if a.session.checked ~= b.session.checked then
		return a.session.checked < b.session.checked
	end
	return a.name < b.name
end
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < PASS then return end
	elapsed = elapsed % PASS
	local now = core.get_us_time()
	local due = {}
	for name, session in pairs(active) do
		local player = core.get_player_by_name(name)
		local context = sfinv.contexts[name]
		if not player or not context or context.page ~= PAGE or
				sfinv.inventory_suspended(player) then
			-- A suspended inventory belongs to character creation (ruling 32);
			-- this direct write must not replace it.
			active[name] = nil
		elseif now < (session.quiet_until or 0) then
			-- Avoid replacing native widgets during an actively moving scrollbar.
			-- Pending marker changes are rendered once scrolling has settled.
		elseif now - (session.checked or 0) >= REBUILD_US then
			session.checked = session.checked or 0
			due[#due + 1] = {name = name, session = session, player = player, context = context}
		end
	end
	table.sort(due, longest_waiting)
	local builds = 0
	for index = 1, math.min(#due, CHECKS_PER_PASS) do
		local row = due[index]
		local session = row.session
		if signature(row.player, row.context) ~= session.signature then
			if builds == BUILDS_PER_PASS then break end
			builds = builds + 1
			local form, sig = make_form(row.player, row.context)
			row.player:set_inventory_formspec(form)
			session.signature = sig
		end
		session.checked = now
	end
end)
core.register_on_leaveplayer(function(player)
	active[player:get_player_name()] = nil
end)
core.register_on_dieplayer(function(player)
	if active[player:get_player_name()] then
		sfinv.set_page(player, sfinv.get_homepage_name(player))
	end
end)
