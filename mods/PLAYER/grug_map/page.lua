local atlas = grug_map.atlas

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
			detail = label .. "\n" .. humanize(row.race_id) .. " settlement"}
	end
	return result
end)

atlas.register_marker_provider("player", function(player)
	if not player or not player:is_player() then return {} end
	return {{id = player:get_player_name(), label = "You are here",
		detail = "Your current position", kind = "player",
		position = player:get_pos()}}
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
	for index = 1, #markers do
		local marker = markers[index]
		local sx, sy = atlas.world_to_screen(view, marker.position,
			MAP_X, MAP_Y, MAP_W, MAP_H)
		if sx then
			local field = "grug_map_marker_" .. index
			context.grug_map_marker_fields[field] = marker
			local symbol = marker.kind == "player" and "@" or
				(marker.kind == "hostile" and "!" or "+")
			fs[#fs + 1] = ("style[%s;bgcolor=#2b2118cc;textcolor=#ffe9a8]"):
				format(field)
			fs[#fs + 1] = ("button[%.3f,%.3f;0.32,0.32;%s;%s]"):
				format(sx - 0.16, sy - 0.16, field, symbol)
			fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(marker.label))
		end
	end
	if context.grug_map_detail then
		fs[#fs + 1] = ("label[0.15,0.50;Selected: %s]"):
			format(esc(context.grug_map_detail:gsub("\n", " — ")))
	end
	return table.concat(fs)
end

sfinv.register_page("grug_map:atlas", {
	title = "Map",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context, page_content(player, context), false)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		local views = atlas.views()
		for index = 1, #views do
			local id = views[index].id
			if fields["grug_map_view_" .. id] then
				context.grug_map_view = id
				context.grug_map_detail = nil
				sfinv.set_page(player, "grug_map:atlas")
				return true
			end
		end
		for field, marker in pairs(context.grug_map_marker_fields or {}) do
			if fields[field] then
				context.grug_map_detail = marker.detail
				sfinv.set_page(player, "grug_map:atlas")
				return true
			end
		end
	end,
})
