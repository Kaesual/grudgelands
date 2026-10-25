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
    ["grug_parties:group"] = {"Party", "party"},
    ["grug_map:atlas"] = {"Map & Quests", "map"},
    ["grug_inventory:help"] = {"Help", "help"},
    ["grug_mail:admin"] = {"Admin Mail", "mail"},
}

function grug_inventory.navigation_layout(player, context, width, info)
    local ids, titles = {}, {}
    for _, page in ipairs(sfinv.pages_unordered) do
        if visible(player, context, page.name) then
            ids[#ids + 1], titles[#titles + 1] = page.name, page.title
        end
    end
    if not info and core.get_player_window_information then
        info = core.get_player_window_information(player:get_player_name())
    end
    -- Fonts do not shrink when a tall form hits the screen's height limit.
    -- Give larger GUI fonts more horizontal space instead of clipping labels.
    local per_row = 7
    if info and (info.real_gui_scaling or 1) > 1.2 and info.size and info.size.x < 1500 then
        per_row = 4
    end
    local ppu, font_scale = 53.33, 1
    if info and info.size and info.max_formspec_size then
        ppu = info.size.y / info.max_formspec_size.y
        local form_h = UI.frame_h + UI.header_h + math.max(0, math.ceil(#ids / per_row) - 1) * 0.54
        ppu = ppu * math.min(1, info.max_formspec_size.y / form_h)
        font_scale = info.real_gui_scaling or 1
    end
    return {ids = ids, titles = titles, per_row = per_row, ppu = ppu, font_scale = font_scale,
        height = UI.header_h + math.max(0, math.ceil(#ids / per_row) - 1) * 0.54}
end

function grug_inventory.navigation(player, context, selected, width, layout)
    width = width or UI.frame_w
    layout = layout or grug_inventory.navigation_layout(player, context, width)
    local ids, titles = layout.ids, layout.titles
    context.grug_ui_nav = ids
    context.grug_ui_header_h = layout.height
    local esc, accent = core.formspec_escape, grug_core.ui.colors.accent
    local faction = grug_factions and grug_factions.get_faction and grug_factions.get_faction(player)
    local faction_name = faction and grug_factions.display_name and grug_factions.display_name(faction) or ""
    local text_scale = grug_core.ui.text_scale(player)
    local level = grug_xp and grug_xp.get_level and grug_xp.get_level(player)
    -- Clear buttons inherit the theme's hover/focus/pressed images. Keep
    -- their six-pixel nine-slice corners in every state; cancel only the
    -- content inset so labels/icons stay in place when the state changes.
    local fs = {"real_coordinates[true]",
        "image[0.28,0.17;0.46,0.55;" .. esc("grug_ui_icon_emblem.png^[multiply:" .. accent) .. "]",
        grug_core.ui.title(0.95, 0.28, "GRUDGELANDS", text_scale),
        ("style_type[label;font_size=*%.3f]"):format(0.65 * text_scale),
        ("label[0.95,0.62;%s]"):format(esc(core.colorize(accent, string.upper(faction_name)))),
        ("style_type[label;font_size=*%.3f]"):format(0.85 * text_scale),
        ("label[%.3f,0.27;%s]"):format(width - 4.1, esc(player:get_player_name())),
        ("style_type[label;font_size=*%.3f]"):format(0.65 * text_scale),
        ("label[%.3f,0.61;%s]"):format(width - 4.1,
            esc(core.colorize(grug_core.ui.colors.muted, level and ("Level " .. level) or ""))),
        "style_type[label;font_size=*1]",
        "style[grug_ui_close;bgimg=grug_ui_clear.png;bgimg_middle=6;padding=-6,-6,6,6;font_size=*1.1]",
        ("button_exit[%.3f,0.14;0.45,0.5;grug_ui_close;×]"):format(width - 0.75),
        ("box[0.25,0.80;%.3f,0.015;#d1c09a2b]"):format(width - 0.5)}
    -- Translation markup is not visible text and must not inflate widths.
    local function caption_weight(label)
        local plain = core.get_translated_string and core.get_translated_string("", label) or label
        return #plain + 3.5
    end
    local per_row, gap = layout.per_row, 0.05
    for start = 1, #ids, per_row do
        local last, weight = math.min(start + per_row - 1, #ids), 0
        for index = start, last do
            local label = captions[ids[index]] and captions[ids[index]][1] or titles[index]
            weight = weight + caption_weight(label)
        end
        local x, y = 0.25, 0.89 + math.floor((start - 1) / per_row) * 0.54
        local available = width - 0.5 - (last - start) * gap
        for index = start, last do
            local caption = captions[ids[index]] or {titles[index], "creative"}
            local w = available * caption_weight(caption[1]) / weight
            local field = PREFIX .. index
            local active = ids[index] == selected
            local color = active and accent or grug_core.ui.colors.muted
            -- Prefer readable captions when a narrow tab cannot also fit its icon.
            local icon = w * (layout.ppu or 53.33) >=
                (#caption[1] * 7.1 + 24) * (layout.font_scale or 1)
            fs[#fs + 1] = ("style[%s;bgimg=grug_ui_clear.png;bgimg_middle=6;padding=-6,-6,6,6;" ..
                "font_size=*0.85;textcolor=%s;content_offset=%d,0]"):format(field, color, icon and 6 or 0)
            fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.46;%s;%s]"):format(x, y, w, field, esc(caption[1]))
            if icon then
                fs[#fs + 1] = ("image[%.3f,%.3f;0.27,0.27;%s]"):
                format(x + 0.09, y + 0.09, esc("grug_ui_icon_" .. caption[2] .. ".png^[multiply:" .. color))
            end
            fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(titles[index]))
            if active then
                fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,0.035;%s]"):format(x, y + 0.47, w, accent)
            end
            x = x + w + gap
        end
    end
    return table.concat(fs), layout.height
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
