-- Selection and scroll state are transient presentation only.
local repo = arg[1] or "."
core = {formspec_escape = function(s) return tostring(s) end,
    colorize = function(_, s) return s end}
grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_rows.lua")
local UI, state = grug_core.ui, {}
local spec = {name = "quests", x = 0, y = 0, w = 5, h = 3,
    rows = {{title = "Story", header = true}}}
for i = 2, 20 do spec.rows[i] = {title = "Quest " .. i, subtitle = "Available"} end
local fs = UI.rows(state, spec)
assert(fs:find("scroll_container[", 1, true))
local maximum = tonumber(fs:match("max=(%d+)"))
local thumb = tonumber(fs:match("thumbsize=(%d+)"))
assert(thumb < maximum, "overflow must leave a movable scrollbar thumb")
assert(not fs:find("quests_row_1;", 1, true), "header is not selectable")
assert(UI.rows_event(state, "quests", {quests_row_1 = true}) == nil)
assert(UI.rows_event(state, "quests", {quests_row_99 = true}) == nil)
local row, changed = UI.rows_event(state, "quests", {quests_scroll = "CHG:100"})
assert(row == nil and changed and state._ui_rows.quests.scroll == 100)
row, changed = UI.rows_event(state, "quests", {quests_scroll = "VAL:175", quests_row_5 = true})
assert(row == 5 and not changed and state._ui_rows.quests.scroll == 175)
assert(UI.rows(state, spec):find(";quests_scroll;175]", 1, true))
UI.rows_event(state, "quests", {quests_scroll = "CHG:99999999999999999999"})
assert(state._ui_rows.quests.scroll == state._ui_rows.quests.max)
UI.rows_event(state, "quests", {quests_scroll = "CHG:-2"})
assert(state._ui_rows.quests.scroll == 0)
UI.rows_event(state, "quests", {quests_scroll = "CHG:nan"})
assert(state._ui_rows.quests.scroll == 0)
UI.rows_event(state, "quests", {quests_scroll = "VAL:175"})
spec.rows = {{title = "One remaining"}}
UI.rows(state, spec)
assert(state._ui_rows.quests.scroll == 0 and state._ui_rows.quests.max == 0)
assert(UI.rows_event(state, "quests", {quests_row_5 = true}) == nil)
UI.rows_reset(state, "quests")
assert(state._ui_rows.quests == nil)
assert(UI.rows_event(state, "quests", {quests_row_1 = true}) == nil)
spec.rows = {{title = string.rep("Ä", 100), subtitle = "Sender", selected = true}}
fs = UI.rows(state, spec)
assert(fs:find("grug_ui_nav_selected.png", 1, true))
assert(fs:find(string.rep("Ä", 100), 1, true), "tooltip retains full UTF-8 title")
spec.rows = {}
for i = 1, 20 do spec.rows[i] = {title = "Row " .. i, selected = i == 18} end
spec.reveal_selected = true
UI.rows(state, spec)
assert(state._ui_rows.quests.scroll > 0, "initial ready quest is revealed")
UI.rows_event(state, "quests", {quests_scroll = "VAL:25"})
spec.reveal_selected = false
UI.rows(state, spec)
assert(state._ui_rows.quests.scroll == 25, "ordinary redraw preserves deliberate scroll")
print("ui_rows: PASS selection, headers, scroll preservation/clamping, stale indices, UTF-8")
