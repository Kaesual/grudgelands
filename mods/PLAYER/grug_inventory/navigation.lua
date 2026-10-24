-- Shared visual navigation; sfinv still owns pages, contexts and lifecycle.
-- Each rendered bar keeps its own id mapping, including the separate map.
local UI = grug_inventory.UI
UI.header_h = 2.20
UI.window_h = UI.frame_h + UI.header_h
local PREFIX = "grug_ui_tab_"

local function visible(player, context, id)
	local page = sfinv.pages[id]
	return page and (not page.is_in_nav or page:is_in_nav(player, context))
end

function grug_inventory.navigation(player, context, selected, width)
	width = width or UI.frame_w
	local ids, titles = {}, {}
	for _, page in ipairs(sfinv.pages_unordered) do
		if visible(player, context, page.name) then
			ids[#ids + 1], titles[#titles + 1] = page.name, page.title
		end
	end
	context.grug_ui_nav = ids
	local fs = {"real_coordinates[true]",
		grug_core.ui.heading(0.35, 0.38, "GRUDGELANDS"),
		("button_exit[%.3f,0.12;0.6,0.55;grug_ui_close;X]"):format(width - 0.95)}
	-- Seven ordinary pages fit one row; privileged pages use a second one.
	-- A single fixed header height keeps every tab stable even across grants.
	local per_row, gap = 7, 0.07
	for start = 1, #ids, per_row do
		local last, weight = math.min(start + per_row - 1, #ids), 0
		for index = start, last do weight = weight + #titles[index] + 5 end
		local x, y = 0.35, 0.80 + math.floor((start - 1) / per_row) * 0.66
		local available = width - 0.7 - (last - start) * gap
		for index = start, last do
			local w = available * (#titles[index] + 5) / weight
			local field = PREFIX .. index
			fs[#fs + 1] = grug_core.ui.button_style(field,
				ids[index] == selected and "selected" or "normal")
			fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.58;%s;%s]"):format(x, y, w,
				field, core.formspec_escape(titles[index]))
			x = x + w + gap
		end
	end
	return table.concat(fs)
end

-- Returns (id, clicked). A stale/revoked id is a consumed click, never an
-- action forwarded to the page which happened to receive the packet.
function grug_inventory.navigation_target(player, context, fields)
	for field in pairs(fields) do
		local index = field:match("^" .. PREFIX .. "(%d+)$")
		if index then
			local id = (context.grug_ui_nav or {})[tonumber(index)]
			return id and visible(player, context, id) and id or nil, true
		end
	end
	if fields.sfinv_nav_tabs then
		local id = (context.nav or {})[tonumber(fields.sfinv_nav_tabs)]
		return id and visible(player, context, id) and id or nil, true
	end
	return nil, false
end

local handle_scroll = sfinv.handle_scroll
function sfinv.handle_scroll(player, context, fields)
	local id, clicked = grug_inventory.navigation_target(player, context, fields)
	if clicked then
		grug_inventory.keep_scroll(context, fields)
		if id and id ~= context.page then sfinv.set_page(player, id) end
		return true
	end
	if not visible(player, context, context.page) then
		sfinv.set_page(player, sfinv.get_homepage_name(player))
		return true
	end
	return handle_scroll(player, context, fields)
end

-- Revocation can also reach a build before the next input event. Leave the
-- restricted page through its lifecycle and build the normal homepage.
local get_formspec = sfinv.get_formspec
function sfinv.get_formspec(player, context)
	if not visible(player, context, context.page) then
		local old = sfinv.pages[context.page]
		if old and old.on_leave then old:on_leave(player, context) end
		context.page = sfinv.get_homepage_name(player)
		local home = sfinv.pages[context.page]
		if home and home.on_enter then home:on_enter(player, context) end
	end
	return get_formspec(player, context)
end
