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
		"bgimg=grug_ui_button.png;bgimg_middle=6;padding=-4,-4,4,4;font_size=*0.85;textcolor=#eeeae1]",
		"style_type[button:hovered,button_exit:hovered;bgimg=grug_ui_hover.png]",
		"style_type[button:focused,button_exit:focused;bgimg=grug_ui_hover.png]",
		"style_type[button:pressed,button_exit:pressed;bgimg=grug_ui_pressed.png]",
		"style_type[field,pwdfield,textarea;textcolor=#eeeae1]",
		"style_type[table,textlist;font=normal]",
	})
end

-- Dense summaries must still fit when a fixed inventory form is shrunk by
-- the client but its user-scaled fonts are not. No polling or saved setting.
function UI.text_scale(player)
    if not player then return 1 end
    local info = core.get_player_window_information and
        core.get_player_window_information(player:get_player_name())
    if info and info.max_formspec_size then
        -- real_gui_scaling includes display density, not just the GUI setting.
        -- Compensate actual form shrink, bounded by the tested small-window scale.
        local rgs = math.max(1, info.real_gui_scaling or 1)
        local form_h = grug_inventory.UI.window_h
        return math.max(1 / rgs, math.min(1, info.max_formspec_size.y / form_h))
    end
    return 1
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

function UI.heading(x, y, text)
    return "style_type[label;font=bold;font_size=*0.75]" ..
        ("label[%.3f,%.3f;%s]"):format(x, y,
            core.formspec_escape(core.colorize(UI.colors.accent, text))) ..
        "style_type[label;font=normal;font_size=*1]"
end

function UI.title(x, y, text, scale)
    return ("style_type[label;font=normal;font_size=*%.3f]"):format(1.1 * (scale or 1)) ..
        ("label[%.3f,%.3f;%s]"):format(x, y,
            core.formspec_escape(core.colorize(UI.colors.text, text))) ..
        "style_type[label;font_size=*1]"
end

-- Role styles apply to specific existing fields. Set normal explicitly when
-- a form reuses a name for an unselected state; no semantic color changes.
function UI.button_style(name, role)
	local texture = role == "selected" and "selected" or
		role == "danger" and "danger" or "button"
	return ("style[%s;border=false;bgcolor=#ffffff;bgimg=grug_ui_%s.png;" ..
		"bgimg_middle=6;padding=-4,-4,4,4;font_size=*0.85;textcolor=#eeeae1]"):format(core.formspec_escape(name), texture)
end

-- At large desktop resolutions, native slots grow with the screen while
-- fonts keep their DPI/GUI size. Cap the preferred slot scale with padding,
-- retaining the client's ordinary fit/shrink behavior when its window resizes.
-- Engine: GUIFormSpecMenu::getFixedImgsize and calculateImgsize. Padding must
-- follow size/position/anchor and precede no_prepend or any visible element.
function UI.readable_padding(player, w, h)
	if not player or not core.get_player_window_information then return "" end
	local info = core.get_player_window_information(player:get_player_name())
	local size = info and info.size
	local scale = info and info.real_gui_scaling
	if not size or not scale or scale <= 0 or size.x <= 0 or size.y <= 0 or
			size.y / scale < 1080 then return "" end
	local pixels = 0.5555 * 96 * scale
	local x = math.max(0.05, 0.5 - 0.5 * w * pixels / size.x)
	local y = math.max(0.05, 0.5 - 0.5 * h * pixels / size.y)
	return ("padding[%.6f,%.6f]"):format(x, y)
end

function UI.frame(w, h, title, opaque, player)
	local fs = ("formspec_version[6]size[%.3f,%.3f]"):format(w, h) ..
		UI.readable_padding(player, w, h)
	if opaque then fs = fs .. "no_prepend[]" .. UI.prepend(true) end
	if title then fs = fs .. UI.title(0.4, 0.45, title) end
	return fs
end

-- Service typography uses one body size. Section labels are quieter, never
-- tiny relative to body text. All content comes from the owning service.
-- Callers with a textarea type style pass its font scale for restoration.
-- Anonymous textareas remain read-only; editable field names stay untouched.
function UI.prose(x, y, w, h, text, muted, restore_font_scale)
    return "style_type[textarea;border=false;font_size=*0.85]" ..
        ("textarea[%.3f,%.3f;%.3f,%.3f;;;%s]"):format(x, y, w, h,
            core.formspec_escape(muted and core.colorize(UI.colors.muted, text) or text)) ..
        ("style_type[textarea;border=true;font_size=*%.3f]"):format(restore_font_scale or 1)
end

function UI.service_header(w, title, subtitle, icon)
    return "style_type[label;font_size=*0.85]" ..
        ("image[0.4,0.4;0.65,0.65;%s]"):format(icon or "grug_ui_icon_emblem.png") ..
        UI.title(1.25, 0.56, title) ..
        "style_type[label;font_size=*0.85]" ..
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
