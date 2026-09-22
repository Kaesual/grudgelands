local atlas = grug_map.atlas
local active, elapsed = {}, 0
local PAGE = "grug_map:atlas"

-- The 900 x 800 media is displayed at the same 9:8 ratio. This page carries
-- no inventory rows, so the atlas uses the full custom-page height.
local MAP_X, MAP_Y, MAP_W, MAP_H = 0.15, 0.85, 10.1, 8.9778
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
		local label = LABELS[row.key] or humanize(row.key)
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
	context.grug_map_view = context.grug_map_view or "world"
	local view = atlas.view(context.grug_map_view)
	-- sfinv's wrapper and navigation are legacy-coordinate formspecs. Switching
	-- here affects only this page content (which the wrapper appends after nav)
	-- and makes image and marker coordinates share one real unit system.
	local fs = {"real_coordinates[true]",
		("label[0.15,0.15;%s]"):format(esc(view.label)),
		("label[2.35,0.15;Current: %s]"):format(esc(current_zone(player))),
		("image[%s,%s;%s,%s;%s]"):format(MAP_X, MAP_Y, MAP_W, MAP_H,
			esc(view.texture))}
	local views = atlas.views()
	for index = 1, #views do
		local row = views[index]
		local x = 0.15 + (index - 1) * 1.44
		local label = row.id == context.grug_map_view and "> " .. row.view.label or
			row.view.label
		fs[#fs + 1] = ("button[%.2f,10.05;1.4,0.65;grug_map_view_%s;%s]"):
			format(x, row.id, esc(label))
	end
	context.grug_map_marker_fields = {}
	local markers = atlas.collect_markers(player)
	context.grug_map_detail = nil
	for index = 1, #markers do
		local marker = markers[index]
		local sx, sy = atlas.world_to_screen(view, marker.position,
			MAP_X, MAP_Y, MAP_W, MAP_H)
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
	if not context.grug_map_detail then context.grug_map_selected = nil end
	if context.grug_map_detail then
		fs[#fs + 1] = ("label[0.15,0.50;Selected: %s]"):
			format(esc(context.grug_map_detail:match("[^\n]*")))
	end
	local home = grug_home.get(player)
	if home then
		local remaining = grug_home.remaining(player)
		local state = grug_home.is_pending(player) and "Preparing arrival" or
			(remaining > 0 and ("%d:%02d"):format(math.floor(remaining / 60), remaining % 60) or "Ready")
		fs[#fs + 1] = ("button[0.15,10.85;10.1,0.65;grug_map_home;Return home: %s (%s)]"):
			format(esc(home.label), esc(state))
	end
	return table.concat(fs)
end

local function make_form(player, context)
	-- v1/v2 legacy-sort images ABOVE buttons, hiding every marker behind the
	-- atlas raster. v3 preserves definition order. Keep the wrapper size/nav
	-- in legacy units, then page_content switches only the map to real units.
	return sfinv.make_formspec(player, context, page_content(player, context), false,
		"formspec_version[3]size[10.4,11.7]real_coordinates[false]")
end

sfinv.register_page(PAGE, {
	title = "Map",
	on_enter = function(self, player)
		active[player:get_player_name()] = {}
	end,
	on_leave = function(self, player)
		active[player:get_player_name()] = nil
	end,
	get = function(self, player, context)
		local form = make_form(player, context)
		local session = active[player:get_player_name()]
		if session then session.form = form end
		return form
	end,
	on_player_receive_fields = function(self, player, context, fields)
		if fields.quit then
			-- The engine cannot report a later inventory reopen. Returning to
			-- Character makes the next Map tab click an explicit open event.
			sfinv.set_page(player, "grug_inventory:character")
			return true
		end
		if fields.grug_map_home then
			grug_home.return_home(player)
			sfinv.set_page(player, PAGE)
			return true
		end
		local views = atlas.views()
		for index = 1, #views do
			local id = views[index].id
			if fields["grug_map_view_" .. id] then
				context.grug_map_view = id
				context.grug_map_detail = nil
				context.grug_map_selected = nil
				sfinv.set_page(player, "grug_map:atlas")
				return true
			end
		end
		for field, marker in pairs(context.grug_map_marker_fields or {}) do
			if fields[field] then
				context.grug_map_detail = marker.detail
				context.grug_map_selected = marker.id
				sfinv.set_page(player, "grug_map:atlas")
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
		else
			local form = make_form(player, context)
			if session.form ~= form then
				player:set_inventory_formspec(form)
				session.form = form
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
