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
local REGION_LABELS = {
	{"Dwarven Lands", -1800, -2350}, {"Human Lands", 0, -2350},
	{"Elven Lands", 1800, -2350}, {"Undead Lands", -1800, 2350},
	{"Orc Lands", 0, 2350}, {"Troll Lands", 1800, 2350},
	{"The Contested Front", 0, 0},
	{"Wyrmglass Crown", -3150, 0}, {"Stormscale Summit", 3150, 0},
}
local LABEL_W, LABEL_H = 3.4, 0.5

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function humanize(key)
	local text = tostring(key):gsub("_", " "):gsub("(%a)([%w']*)",
		function(first, rest) return first:upper() .. rest end)
	return text
end

atlas.register_marker_provider("settlement", function()
	local rows = grug_core.settlement_socket_settlements()
	local result = {}
	for index = 1, #rows do
		local row = rows[index]
		local label = row.display_name or LABELS[row.key] or humanize(row.key)
		result[index] = {id = row.key, label = label, position = row.anchor,
			kind = row.key:find("bandit_camp", 1, true) and "hostile" or "settlement",
			detail = label}
	end
	return result
end)

function grug_map.register_marker_provider(name, callback)
	return atlas.register_marker_provider(name, callback)
end

local function current_zone(player)
	if not grug_core.zone_authority_installed() then return "World map loading" end
	local zone = grug_zones.at(player:get_pos())
	return zone and (zone.display_name or humanize(zone.id)) or "Open sea"
end

local function page_content(player, context)
	local zoom = context.grug_map_zoom or 1
	local view = atlas.view()
	local fs = {"real_coordinates[true]",
		-- Focus outside the canvas prevents engine autoScroll from moving to a
		-- focused marker after the form is regenerated (including keyboard focus).
		("label[0.15,0.22;World — %dx]"):format(zoom),
		("label[2.35,0.22;Current: %s]"):format(esc(current_zone(player))),
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
		local lx = math.max(0, math.min(MAP_W * zoom - LABEL_W, sx - LABEL_W / 2))
		fs[#fs + 1] = ("hypertext[%.3f,%.3f;%s,%s;grug_map_region_%d;%s]"):format(
			lx, sy - LABEL_H / 2, LABEL_W, LABEL_H, index,
			esc("<global halign=center valign=middle color=#2a1c10><b>" ..
				row[1] .. "</b>"))
	end
	context.grug_map_marker_fields = {}
	local markers = atlas.collect_markers(player)
	context.grug_map_detail = nil
	for index = 1, #markers do
		local marker = markers[index]
		local sx, sy = atlas.world_to_screen(view, marker.position,
			0, 0, MAP_W * zoom, MAP_H * zoom)
		if sx then
			if marker.id == context.grug_map_selected then
				context.grug_map_detail = marker.detail
			end
			local field = atlas.field_id(marker.id)
			context.grug_map_marker_fields[field] = marker
			if marker.kind == "player" or marker.kind == "party" then
				local tint = marker.kind == "player" and "gold" or "cyan"
				local texture = ("grug_map_heading_%s_%02d.png"):format(tint,
					atlas.heading_frame(marker.heading))
				fs[#fs + 1] = ("style[%s;border=false]"):format(field)
				fs[#fs + 1] = ("image_button[%.3f,%.3f;0.42,0.42;%s;%s;;false;false]"):
					format(sx - 0.21, sy - 0.21, texture, field)
				-- Names stay in the hover/detail text to keep tightly grouped players
				-- legible even at continental scale.
			elseif marker.texture then
				fs[#fs + 1] = ("image_button[%.3f,%.3f;0.34,0.34;%s;%s;;false;false]"):
					format(sx - 0.17, sy - 0.17, esc(marker.texture), field)
			else
				local quest = marker.kind == "quest"
				local symbol = marker.kind == "home" and "H" or
					marker.kind == "innkeeper" and "I" or quest and ((marker.status == "ready" or marker.status == "active")
					and "?" or "!") or (marker.kind == "hostile" and "!" or "+")
				local color = quest and ((marker.status == "ready" or marker.status == "available")
					and "#ffd700" or "#c0c0c0") or "#ffe9a8"
				fs[#fs + 1] = ("style[%s;bgcolor=#2b2118cc;textcolor=%s]"):format(field, color)
				fs[#fs + 1] = ("button[%.3f,%.3f;0.32,0.32;%s;%s]"):
					format(sx - 0.16, sy - 0.16, field, symbol)
			end
			fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(marker.detail))
		end
	end
	fs[#fs + 1] = "scroll_container_end[]scroll_container_end[]"
	if not context.grug_map_detail then context.grug_map_selected = nil end
	if context.grug_map_detail then
		fs[#fs + 1] = ("label[0.15,0.62;Selected: %s]"):
			format(esc(context.grug_map_detail:match("[^\n]*")))
	end
	local home = grug_home.get(player)
	if home then
		local remaining = grug_home.remaining(player)
		local state = grug_home.is_pending(player) and "Preparing arrival" or
			(remaining > 0 and ("%d:%02d"):format(math.floor(remaining / 60), remaining % 60) or "Ready")
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.65;grug_map_home;Return home: %s (%s)]"):
			format(MAP_X, MAP_Y + MAP_H + 0.59, MAP_W, esc(home.label), esc(state))
	end
	-- Scrollbar starting values are transport state, not render semantics.
	-- Only signatures actually sent to the client may advance session.signature.
	local signature = table.concat(fs)
	table.insert(fs, 1, "set_focus[" .. (context.grug_map_focus or SCROLL_X) .. ";true]")
	fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=40;largestep=900;thumbsize=%d;arrows=hide]"):
		format(atlas.scroll_limit(zoom), math.max(1, math.floor((atlas.scroll_limit(zoom) + 1) / zoom)))
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;%.3f,0.28;horizontal;%s;%d]"):
		format(MAP_X, MAP_Y + MAP_H + 0.05, MAP_W, SCROLL_X, context.grug_map_scroll_x or 0)
	fs[#fs + 1] = ("scrollbar[%.3f,%.3f;0.28,%.3f;vertical;%s;%d]"):
		format(MAP_X + MAP_W + 0.05, MAP_Y, MAP_H, SCROLL_Y, context.grug_map_scroll_y or 0)
	return table.concat(fs), signature
end

local function make_form(player, context)
	local content, signature = page_content(player, context)
	return sfinv.make_formspec(player, context, content, false,
		("formspec_version[4]size[%s,%s]real_coordinates[false]"):
			format(UI.width, UI.height)), signature
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
		local form, signature = make_form(player, context)
		local session = active[player:get_player_name()]
		if session then session.signature = signature end
		return form
	end,
	on_player_receive_fields = function(self, player, context, fields)
		if fields.quit then
			-- The engine cannot report a later inventory reopen. Returning to
			-- Character makes the next Map tab click an explicit open event.
			sfinv.set_page(player, "grug_inventory:character")
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
						if session then session.scroll_quiet = 0.5 end
					end
					context[key] = atlas.clamp_scroll(tonumber(value), context.grug_map_zoom or 1)
				end
			end
		end
		if fields.grug_map_home then
			grug_home.return_home(player)
			sfinv.set_player_inventory_formspec(player, context)
			return true
		end
		if fields.grug_map_zoom_in or fields.grug_map_zoom_out then
			local old = context.grug_map_zoom or 1
			local zoom = fields.grug_map_zoom_in and math.min(4, old * 2) or math.max(1, old / 2)
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
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 0.5 then return end
	elapsed = elapsed % 0.5
	for name, session in pairs(active) do
		local player = core.get_player_by_name(name)
		local context = sfinv.contexts[name]
		if not player or not context or context.page ~= PAGE then
			active[name] = nil
		elseif (session.scroll_quiet or 0) > 0 then
			-- Avoid replacing native widgets during an actively moving scrollbar.
			-- Pending marker changes are rendered once scrolling has settled.
			session.scroll_quiet = math.max(0, session.scroll_quiet - 0.5)
		else
			local form, signature = make_form(player, context)
			if session.signature ~= signature then
				player:set_inventory_formspec(form)
				session.signature = signature
			end
		end
	end
end)
core.register_on_leaveplayer(function(player)
	active[player:get_player_name()] = nil
end)
core.register_on_dieplayer(function(player)
	if active[player:get_player_name()] then
		sfinv.set_page(player, "grug_inventory:character")
	end
end)
