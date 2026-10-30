-- Presentation-only selectable rows. State belongs to the containing window;
-- scrolling is client-side and never schedules or sends a form.
local UI = grug_core.ui
local function esc(value) return core.formspec_escape(tostring(value or "")) end
local function clamp(value, maximum)
    value = tonumber(value)
    if not value or value ~= value then return 0 end
    return math.max(0, math.min(maximum, math.floor(value)))
end

-- UTF-8-safe display wrapping; the complete text remains in the tooltip.
local function lines(text, width)
    local chars = {}
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = char == "\n" and " " or char
    end
    if #chars <= width then return table.concat(chars), nil end
    local split = width
    for i = width, math.floor(width * 0.55), -1 do
        if chars[i] == " " then split = i; break end
    end
    local first = table.concat(chars, "", 1, split)
    local last = math.min(#chars, split + width)
    return first, table.concat(chars, "", split + 1, last) .. (last < #chars and "…" or "")
end

-- The compact variant (Round 67 ruling 19, the map window's quest list):
-- `spec.compact` makes every row one line of COMPACT_H units, the title cut
-- with "…" (whole in the tooltip), a smaller icon, no subtitle and the
-- row's `badge` text (e.g. "[Lv 12]", in `badge_color`) in a column at the
-- right edge, as wide as the longest badge needs. Rows without it keep
-- their form byte for byte.
local COMPACT_H, BADGE_CHAR = 0.6, 0.13

-- The badge column's width for compact rows (0 without badges).
local function badge_width(spec, scale)
    local longest = 0
    for _, row in ipairs(spec.rows) do
        if row.badge and not row.header then
            local _, extra = tostring(row.badge):gsub("[\128-\191]", "")
            longest = math.max(longest, #tostring(row.badge) - extra)
        end
    end
    return longest > 0 and (longest * BADGE_CHAR * math.max(1, scale) + 0.16) or 0
end

function UI.rows_reset(state, name)
    if state._ui_rows then state._ui_rows[name] = nil end
end

function UI.rows(state, spec)
    state._ui_rows = state._ui_rows or {}
    local saved = state._ui_rows[spec.name] or {scroll = 0}
    state._ui_rows[spec.name] = saved
    local scale, width = spec.scale or 1, spec.w - 0.28
    local rows, height = {}, 0
    local badge_w = spec.compact and badge_width(spec, scale) or 0
    for index, row in ipairs(spec.rows) do
        local text_x = row.icon and (spec.compact and 0.56 or 0.68) or 0.16
        local first, second = lines(row.title, math.max(8,
            math.floor((width - text_x - 0.16 - badge_w) / (0.17 * math.max(1, scale)))))
        local h
        if row.header then
            h = 0.55
        elseif spec.compact then
            h = COMPACT_H
            if second then first, second = first:gsub(" $", "") .. "…", nil end
        else
            h = math.max(spec.row_h or 1.25, second and 1.55 or 1.25)
        end
        rows[index] = {row = row, y = height, h = h, first = first, second = second, x = text_x}
        height = height + h
    end
    saved.max = math.max(0, math.ceil((height - spec.h) * 100))
    saved.scroll = clamp(saved.scroll, saved.max)
    if spec.reveal_selected then
        for _, item in ipairs(rows) do
            if item.row.selected and not item.row.header then
                local top = saved.scroll / 100
                if item.y < top then saved.scroll = clamp(item.y * 100, saved.max)
                elseif item.y + item.h > top + spec.h then
                    saved.scroll = clamp(math.ceil((item.y + item.h - spec.h) * 100), saved.max)
                end
                break
            end
        end
    end
    saved.selectable = {}
    saved.count = #rows
    local scroll = spec.name .. "_scroll"
    local fs = {("scrollbaroptions[min=0;max=%d;smallstep=35;largestep=%d;thumbsize=%d]"):
        format(saved.max, math.max(1, math.floor(spec.h * 80)), math.max(1, math.floor(saved.max * spec.h / math.max(spec.h, height)))),
        ("scrollbar[%.3f,%.3f;0.22,%.3f;vertical;%s;%d]"):
        format(spec.x + spec.w - 0.22, spec.y, spec.h, esc(scroll), saved.scroll),
        ("scroll_container[%.3f,%.3f;%.3f,%.3f;%s;vertical;0.01]"):
        format(spec.x, spec.y, width, spec.h, esc(scroll))}
    for index, item in ipairs(rows) do
        local row, y = item.row, item.y
        if row.header then
            fs[#fs + 1] = UI.heading(0.16, y + 0.28, row.title, scale)
        else
            saved.selectable[index] = true
            local field = spec.name .. "_row_" .. index
            fs[#fs + 1] = ("style[%s;border=false;bgimg=grug_ui_%s.png;bgimg_middle=6;" ..
                "padding=0;content_offset=0,0]style[%s:hovered;bgimg=grug_ui_nav_hover.png]" ..
                "style[%s:focused;bgimg=grug_ui_focus.png]style[%s:pressed;bgimg=grug_ui_pressed.png]" ..
                "button[0,%.3f;%.3f,%.3f;%s;]"):
                format(field, row.selected and "nav_selected" or "clear", field, field, field,
                    y, width, item.h - 0.06, field)
            if row.selected then
                fs[#fs + 1] = ("box[0,%.3f;0.035,%.3f;%s]"):format(y, item.h - 0.06, UI.colors.accent)
            end
            if row.icon and spec.compact then
                fs[#fs + 1] = ("image[0.12,%.3f;0.36,0.36;%s]"):format(y + 0.09, esc(row.icon))
            elseif row.icon then
                fs[#fs + 1] = ("image[0.12,%.3f;0.42,0.42;%s]"):format(y + 0.2, esc(row.icon))
            end
            fs[#fs + 1] = ("style_type[label;font=normal;font_size=*%.3f]label[%.3f,%.3f;%s]"):
                format(scale, item.x, y + (spec.compact and (item.h - 0.06) / 2 or 0.32), esc(item.first))
            if spec.compact and row.badge then
                local badge = tostring(row.badge)
                fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(width - badge_w + 0.08,
                    y + (item.h - 0.06) / 2,
                    esc(row.badge_color and core.colorize(row.badge_color, badge) or badge))
            end
            if item.second then
                fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(item.x, y + 0.69, esc(item.second))
            end
            if row.subtitle and not spec.compact then
                local subtitle, continuation = lines(row.subtitle, math.max(8,
                    math.floor((width - item.x - 0.16) / (0.15 * math.max(1, scale)))))
                fs[#fs + 1] = ("style_type[label;font_size=*%.3f]label[%.3f,%.3f;%s]"):
                    format(0.9 * scale, item.x, y + item.h - 0.3,
                        esc(core.colorize(UI.colors.muted, subtitle .. (continuation and "…" or ""))))
            end
            fs[#fs + 1] = ("tooltip[%s;%s]"):format(field,
                esc(row.tooltip or (row.title .. (row.subtitle and ("\n" .. row.subtitle) or ""))))
        end
    end
    fs[#fs + 1] = "scroll_container_end[]scrollbaroptions[min=0;max=1000;smallstep=10;largestep=100;thumbsize=0]"
    fs[#fs + 1] = ("style_type[label;font=normal;font_size=*%.3f]"):format(scale)
    return table.concat(fs)
end

function UI.rows_event(state, name, fields)
    local saved = state._ui_rows and state._ui_rows[name]
    if not saved then return nil, false end
    local raw = fields[name .. "_scroll"]
    local kind, value
    if type(raw) == "string" then kind, value = raw:match("^(%u+):(%-?%d+)$") end
    if kind == "CHG" or kind == "VAL" then saved.scroll = clamp(value, saved.max) end
    -- Only indices rendered as actual rows can select; headers and malformed
    -- client fields never enter an owner's id mapping.
    for index = 1, saved.count do
        if saved.selectable[index] and fields[name .. "_row_" .. index] then
            return index, kind == "CHG"
        end
    end
    return nil, kind == "CHG"
end
