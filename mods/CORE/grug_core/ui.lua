-- Shared presentation only. Owners keep their fields, sessions, inventory
-- rules and timing. These helpers never send forms or schedule work.
local UI = {}
grug_core.ui = UI
UI.colors = {text = "#e5e8eb", muted = "#a7b2bc", accent = "#d4b77d",
	panel = "#0a1017a5", selected = "#bba062", danger = "#cb9290"}

function UI.styles()
	return table.concat({
		"listcolors[#111a24b0;#344452cc;#55637188;#0a1017f2;#e5e8eb]",
		"style_type[button,button_exit;border=false;bgcolor=#ffffff;",
		"bgimg=grug_ui_button.png;bgimg_middle=6;textcolor=#e5e8eb]",
		"style_type[button:hovered,button_exit:hovered;bgimg=grug_ui_hover.png]",
		"style_type[button:focused,button_exit:focused;bgimg=grug_ui_hover.png]",
		"style_type[button:pressed,button_exit:pressed;bgimg=grug_ui_pressed.png]",
		"style_type[field,pwdfield,textarea;textcolor=#e5e8eb]",
		"style_type[table,textlist;font=normal]",
	})
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
	return ("label[%.3f,%.3f;%s]"):format(x, y,
		core.formspec_escape(core.colorize(UI.colors.accent, text)))
end

-- Role styles apply to specific existing fields. Set normal explicitly when
-- a form reuses a name for an unselected state; no semantic color changes.
function UI.button_style(name, role)
	local texture = role == "selected" and "selected" or
		role == "danger" and "danger" or "button"
	return ("style[%s;border=false;bgcolor=#ffffff;bgimg=grug_ui_%s.png;" ..
		"bgimg_middle=6;textcolor=#e5e8eb]"):format(core.formspec_escape(name), texture)
end

function UI.frame(w, h, title, opaque)
	local fs = ("formspec_version[6]size[%.3f,%.3f]"):format(w, h)
	if opaque then fs = fs .. "no_prepend[]" .. UI.prepend(true) end
	if title then fs = fs .. UI.heading(0.4, 0.45, title) end
	return fs
end

-- grug_core depends on grug_sounds (which depends on default), so this
-- replaces the old default prepend after its click styles were installed.
-- Explicit no_prepend forms opt in using UI.prepend themselves.
core.register_on_joinplayer(function(player)
	player:set_formspec_prepend(UI.prepend(false))
end)
