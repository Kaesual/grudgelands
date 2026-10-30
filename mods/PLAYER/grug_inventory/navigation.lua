-- Shared visual navigation; sfinv still owns pages, contexts and lifecycle.
-- Each rendered bar keeps its own id mapping, including the separate map.
local UI = grug_inventory.UI
UI.header_h = 1.5 -- one row; navigation_layout returns the actual height
UI.window_h = UI.frame_h + UI.header_h
local PREFIX = "grug_ui_tab_"

local function visible(player, context, id)
	local page = sfinv.pages[id]
	return page and (not page.is_in_nav or page:is_in_nav(player, context))
end

-- Compact captions keep every page visible; tooltips retain full titles.
local captions = {
    ["grug_classes:talents"] = {"Talents", "talents"},
    ["grug_inventory:inventory"] = {"Inventory", "inventory"},
    ["grug_inventory:character"] = {"Character", "character"},
    ["sfinv:crafting"] = {"Crafting", "crafting"},
    ["grug_parties:group"] = {"Social", "party"},
    ["grug_map:atlas"] = {"Map & Quests", "map"},
    ["grug_inventory:help"] = {"Help", "help"},
    ["grug_mail:admin"] = {"Admin Mail", "mail"},
}

-- `selected` (optional) is the page being drawn: the Creative category row
-- shows only on a creative:* page (Round 67 ruling 9), so every other page
-- keeps the one-row header. The map window passes none.
function grug_inventory.navigation_layout(player, context, width, info, selected)
    local ids, titles, primary, categories = {}, {}, {}, {}
    for _, page in ipairs(sfinv.pages_unordered) do
        if visible(player, context, page.name) then
            ids[#ids + 1], titles[#titles + 1] = page.name, page.title
            local group = page.name:match("^creative:") and categories or primary
            group[#group + 1] = #ids
        end
    end
    if #categories > 0 then primary[#primary + 1] = categories[1] end
    local show_categories = #categories > 0 and type(selected) == "string" and
        selected:match("^creative:") ~= nil
    return {ids = ids, titles = titles, primary = primary, categories = categories,
        per_row = #primary, height = UI.header_h + (show_categories and 0.54 or 0),
        show_categories = show_categories}
end

function grug_inventory.navigation(player, context, selected, width, layout)
    width = width or UI.frame_w
    layout = layout or grug_inventory.navigation_layout(player, context, width, nil, selected)
    local ids, titles = layout.ids, layout.titles
    context.grug_ui_nav = ids
    context.grug_ui_creative = layout.categories[1] and ids[layout.categories[1]] or nil
    context.grug_ui_header_h = layout.height
    local esc, accent = core.formspec_escape, grug_core.ui.colors.accent
    local faction = grug_factions and grug_factions.get_faction and grug_factions.get_faction(player)
    local emblem = (faction == "accord" or faction == "throng")
        and ("grug_inventory_faction_" .. faction .. ".png")
        or ("grug_ui_icon_emblem.png^[multiply:" .. accent)
    local faction_name = faction and grug_factions.display_name and grug_factions.display_name(faction) or ""
    local text_scale = grug_core.ui.text_scale(player)
    local growth = grug_core.ui.text_growth(player)
    local level = grug_xp and grug_xp.get_level and grug_xp.get_level(player)
    -- Text navigation stays unboxed on hover and press. Keyboard focus has
    -- its own visible fill; the active page keeps its underline.
    local fs = {"real_coordinates[true]",
        "image[0.28,0.17;0.46,0.55;" .. esc(emblem) .. "]",
        grug_core.ui.title(0.95, 0.28, "GRUDGELANDS", text_scale, growth),
        ("style_type[label;font_size=*%.3f]"):format(0.65 * text_scale),
        ("label[0.95,0.62;%s]"):format(esc(core.colorize(accent, string.upper(faction_name)))),
        ("style_type[label;font_size=*%.3f]"):format(0.85 * text_scale),
        ("label[%.3f,0.27;%s]"):format(width - 4.1, esc(player:get_player_name())),
        ("style_type[label;font_size=*%.3f]"):format(0.65 * text_scale),
        ("label[%.3f,0.61;%s]"):format(width - 4.1,
            esc(core.colorize(grug_core.ui.colors.muted, level and ("Level " .. level) or ""))),
        "style_type[label;font_size=" .. grug_core.ui.font_size(1, growth) .. "]",
        "style[grug_ui_close;bgimg=grug_ui_clear.png;bgimg_middle=6;padding=-6,-6,6,6;font_size=" ..
            grug_core.ui.font_size(1.1, growth) .. "]",
        ("button_exit[%.3f,0.14;0.45,0.5;grug_ui_close;×]"):format(width - 0.75),
        ("box[0.25,0.80;%.3f,0.015;#d1c09a2b]"):format(width - 0.5)}
    -- Translation markup is not visible text and must not inflate widths.
    local function caption_weight(label)
        local plain = core.get_translated_string and core.get_translated_string("", label) or label
        return #plain + 3.5
    end
    local gap = 0.05
    local function row(indices, y, categories)
        local weight = 0
        local function label(index)
            if not categories and ids[index]:match("^creative:") then return "Creative" end
            return captions[ids[index]] and captions[ids[index]][1] or titles[index]
        end
        for _, index in ipairs(indices) do weight = weight + caption_weight(label(index)) end
        local x, available = 0.25, width - 0.5 - (#indices - 1) * gap
        for _, index in ipairs(indices) do
            local caption = label(index)
            local w = available * caption_weight(caption) / weight
            local field = not categories and ids[index]:match("^creative:") and "grug_ui_creative" or PREFIX .. index
            local active = ids[index] == selected or (not categories and
                ids[index]:match("^creative:") and selected:match("^creative:"))
            local color = active and accent or grug_core.ui.colors.muted
            fs[#fs + 1] = ("style[%s;bgimg=grug_ui_clear.png;bgimg_middle=6;padding=-6,-6,6,6;" ..
                "font_size=*%.3f;textcolor=%s;content_offset=0,0]"):format(field, 1.1 * text_scale, color)
            fs[#fs + 1] = ("style[%s:hovered;bgimg=grug_ui_clear.png;textcolor=%s]" ..
                "style[%s:pressed;bgimg=grug_ui_clear.png;textcolor=%s]"):
                format(field, accent, field, accent)
            fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.46;%s;%s]"):format(x, y, w, field, esc(caption))
            fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(titles[index]))
            if active then
                fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,0.035;%s]"):format(x, y + 0.47, w, accent)
            end
            x = x + w + gap
        end
    end
    row(layout.primary, 0.89, false)
    if layout.show_categories then row(layout.categories, 1.43, true) end
    return table.concat(fs), layout.height
end

-- Returns (id, clicked). A stale/revoked id is a consumed click, never an
-- action forwarded to the page which happened to receive the packet.
function grug_inventory.navigation_target(player, context, fields)
	if fields.grug_ui_creative then
		local id = context.grug_ui_creative
		return id and visible(player, context, id) and id or nil, true
	end
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

	if not visible(player, context, context.page) then
		local page = sfinv.pages[context.page]
		-- Explicit refusal-only hook preserves the owner's audit behavior;
		-- never dispatch an unauthorized ordinary page action.
		if page and page.on_navigation_denied then
			if page:on_navigation_denied(player, context, fields) then return true end
		end
		sfinv.set_page(player, sfinv.get_homepage_name(player))
		return true
	end
	if fields.grug_ui_close then
		-- button_exit submits dropdown/text values, unlike Escape. Preserve
		-- scroll state, then give the existing owners the same quit-only
		-- event as Escape so cleanup still runs without an accidental action.
		grug_inventory.keep_scroll(context, fields)
		local quit = {quit = "true"}
		if not handle_scroll(player, context, quit) then
			local page = sfinv.pages[context.page]
			if page and page.on_player_receive_fields then
				page:on_player_receive_fields(player, context, quit)
			end
		end
		return true
	end
	if clicked then
		grug_inventory.keep_scroll(context, fields)
		if id and id ~= context.page then sfinv.set_page(player, id) end
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
