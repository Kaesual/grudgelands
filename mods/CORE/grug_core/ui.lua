-- Shared presentation only. Owners keep their fields, sessions, inventory
-- rules and timing. These helpers never send forms or schedule work.
local UI = {}
grug_core.ui = UI
UI.colors = {text = "#eeeae1", muted = "#a9aea4", accent = "#d4b77d",
	panel = "#0a10115e", selected = "#bba062", danger = "#cb9290"}

function UI.styles()
	return table.concat({
		"listcolors[#111a24b0;#344452cc;#d1c09a40;#0a1017f2;#eeeae1]",
		"style_type[button,button_exit;border=false;bgcolor=#ffffff;",
		"bgimg=grug_ui_button.png;bgimg_middle=6;padding=-4,-4,4,4;font_size=*1;textcolor=#e6e6dd;content_offset=0,0]",
		"style_type[button:hovered,button_exit:hovered;bgimg=grug_ui_hover.png]",
		"style_type[button:focused,button_exit:focused;bgimg=grug_ui_focus.png]",
		"style_type[button:pressed,button_exit:pressed;bgimg=grug_ui_pressed.png]",
		"style_type[field,pwdfield,textarea;textcolor=#eeeae1]",
		"style_type[table,textlist;font=normal]",
	})
end

local function window_report(player)
    return player and core.get_player_window_information and
        core.get_player_window_information(player:get_player_name()) or nil
end

-- The inventory window, the reference form of text_scale and text_growth.
local function inventory_size()
    local inventory = rawget(_G, "grug_inventory") and grug_inventory.UI or {}
    return inventory.frame_w or 20, inventory.window_h
end

-- Form text growth on a screen whose viewport ceiling grew (ui_window.lua,
-- Round 66 ruling 4): text grows as much as a fw x fh form does (default the
-- inventory window), so it keeps its 1080p proportion to the slots. Exactly
-- 1 on screens up to 1620 px high: their forms stay byte-identical.
function UI.text_growth(player, fw, fh, info)
    if not UI.form_growth then return 1 end
    local w, h = inventory_size()
    info = info or window_report(player)
    return info and UI.form_growth(info, fw or w, fh or h) or 1
end

-- Dense summaries must still fit when a fixed inventory form is shrunk by
-- the client but its user-scaled fonts are not. No polling or saved setting.
-- The fit is measured on the Full-HD ceiling; text_growth scales it up.
function UI.text_scale(player)
    if not player then return 1 end
    local report = window_report(player)
    local info = report
    if UI.window_information then info = UI.window_information(report, true) end
    if info and info.max_formspec_size then
        -- real_gui_scaling includes display density, not just the GUI setting.
        -- Compensate actual form shrink, bounded by the tested small-window scale.
        local rgs = math.max(1, info.real_gui_scaling or 1)
        local form_h = grug_inventory.UI.window_h
        return math.max(1 / rgs, math.min(1, info.max_formspec_size.y / form_h)) *
            UI.text_growth(player, nil, nil, report)
    end
    return 1
end

-- A font_size value for a literal size: `factor` (nil: the client default)
-- times a form's text growth. At growth 1 it is the literal itself ("*0.85",
-- "*1", "" for the default), so forms that do not grow keep their bytes.
function UI.font_size(factor, growth)
    if not growth or growth == 1 then
        return factor and ("*%g"):format(factor) or ""
    end
    return ("*%.3f"):format((factor or 1) * growth)
end

-- Scope supported native controls to the fitted text size. Checkboxes and
-- dropdowns retain the client font; their captions need room independently.
function UI.fonts(scale)
    return ("style_type[label,button,button_exit,field,textarea,table,textlist;font_size=*%.3f]"):
        format(scale or 1)
end

function UI.prepend(opaque)
	return (opaque and "bgcolor[#0b1118;true]" or "bgcolor[#05090c66;true]") ..
		"background9[0,0;1,1;grug_ui_window.png;true;6]" .. UI.styles() ..
		grug_sounds.CLICK_STYLE
end

-- Coordinates belong to the caller (real or an explicitly retained legacy
-- form). Backgrounds do not capture inventory input or rewrite slot styling.
function UI.panel(x, y, w, h)
	return ("background9[%.3f,%.3f;%.3f,%.3f;grug_ui_panel.png;false;6]"):
		format(x, y, w, h)
end

function UI.heading(x, y, text, scale)
    scale = scale or 1
    return ("style_type[label;font=bold;font_size=*%.3f]"):format(0.9 * scale) ..
        ("label[%.3f,%.3f;%s]"):format(x, y,
            core.formspec_escape(core.colorize(UI.colors.accent, text))) ..
        ("style_type[label;font=normal;font_size=*%.3f]"):format(scale)
end

-- `reset` is the label size restored afterwards (default 1; a grown form
-- passes its text growth).
function UI.title(x, y, text, scale, reset)
    return ("style_type[label;font=normal;font_size=*%.3f]"):format(1.1 * (scale or 1)) ..
        ("label[%.3f,%.3f;%s]"):format(x, y,
            core.formspec_escape(core.colorize(UI.colors.text, text))) ..
        "style_type[label;font_size=" .. UI.font_size(1, reset) .. "]"
end

-- Role styles apply to specific existing fields. Set normal explicitly when
-- a form reuses a name for an unselected state; no semantic color changes.
function UI.button_style(name, role, scale)
	local texture = role == "selected" and "selected" or
		role == "danger" and "danger" or "button"
	local color = role == "selected" and "#e6ca8d" or
		role == "danger" and "#e0aca0" or "#e6e6dd"
	return ("style[%s;border=false;bgcolor=#ffffff;bgimg=grug_ui_%s.png;" ..
		"bgimg_middle=6;padding=-4,-4,4,4;font_size=*%.3f;textcolor=%s;content_offset=0,0]"):
		format(core.formspec_escape(name), texture, scale or 1, color)
end

-- Navigation is distinct from actions: clear text tabs or a flat side-menu
-- selection, with one active edge. Fields and click handling stay with owners.
function UI.navigation_style(name, selected, x, y, w, h, vertical, scale)
	local field = core.formspec_escape(name)
	local color = selected and UI.colors.accent or UI.colors.muted
	local texture = vertical and selected and "nav_selected" or "clear"
	local fs = ("style[%s;border=false;bgcolor=#ffffff;bgimg=grug_ui_%s.png;" ..
		"bgimg_middle=6;padding=-6,-6,6,6;font_size=*%.3f;textcolor=%s;content_offset=0,0]" ..
		"style[%s:hovered;bgimg=grug_ui_nav_hover.png;textcolor=%s]" ..
		"style[%s:focused;bgimg=grug_ui_focus.png;textcolor=%s]" ..
		"style[%s:pressed;bgimg=grug_ui_pressed.png;textcolor=%s]"):
		format(field, texture, scale or 1, color, field, UI.colors.accent,
			field, UI.colors.accent, field, UI.colors.accent)
	if selected then
		fs = fs .. ("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(x,
			vertical and y or y + h - 0.035, vertical and 0.035 or w,
			vertical and h or 0.035, UI.colors.accent)
	end
	return fs
end

-- Native fitting within the capped viewport; no delayed corrective send.
-- On a grown ceiling the form's text defaults grow with it (text_growth).
function UI.frame(w, h, title, opaque, player)
	local growth = UI.text_growth(player, w, h)
	local fs = ("formspec_version[6]size[%.3f,%.3f]"):format(w, h) ..
		(UI.window_padding and UI.window_padding(player) or "")
	if opaque then fs = fs .. "no_prepend[]" .. UI.prepend(true) end
	if growth ~= 1 then fs = fs .. UI.fonts(growth) end
	if title then fs = fs .. UI.title(0.4, 0.45, title, growth, growth) end
	return fs
end

-- Service typography uses one body size. Section labels are quieter, never
-- tiny relative to body text. All content comes from the owning service.
-- Callers with a textarea type style pass its font scale for restoration.
-- Anonymous textareas remain read-only; editable field names stay untouched.
function UI.prose(x, y, w, h, text, muted, restore_font_scale, font_scale)
    return ("style_type[textarea;border=false;font_size=*%.3f]"):format(font_scale or restore_font_scale or 1) ..
        ("textarea[%.3f,%.3f;%.3f,%.3f;;;%s]"):format(x, y, w, h,
            core.formspec_escape(muted and core.colorize(UI.colors.muted, text) or text)) ..
        ("style_type[textarea;border=true;font_size=*%.3f]"):format(restore_font_scale or 1)
end

function UI.service_header(w, title, subtitle, icon, scale)
    scale = scale or 1
    return UI.fonts(scale) ..
        ("image[0.4,0.4;0.65,0.65;%s]"):format(icon or "grug_ui_icon_emblem.png") ..
        UI.title(1.25, 0.56, title, scale) ..
        ("style_type[label;font_size=*%.3f]"):format(scale) ..
        ("label[1.25,0.97;%s]box[0.4,1.35;%.3f,0.015;#d4b77d40]"):
            format(core.formspec_escape(core.colorize(UI.colors.muted, subtitle or "")), w - 0.8)
end

-- Native edit boxes cannot style their fill (GUIFormSpecMenu::createTextField).
-- Draw the desired surface behind a borderless native field; names and input
-- behavior stay with the caller. The helper never rewrites a finished form.
function UI.input_background(x, y, w, h, name)
	return ("box[%.3f,%.3f;%.3f,%.3f;#829c9655]" ..
		"box[%.3f,%.3f;%.3f,%.3f;#243235]style[%s;border=false;textcolor=#eeeae1]"):
		format(x, y, w, h, x + 0.015, y + 0.015, w - 0.03, h - 0.03,
			core.formspec_escape(name))
end
