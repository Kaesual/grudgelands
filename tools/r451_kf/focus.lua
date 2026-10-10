-- 0.45.1 lane KF: a model of the element a formspec window focuses when the
-- client builds it, after the engine (reference_projects/luanti,
-- src/gui/guiFormSpecMenu.cpp), and whether that element eats a plain letter
-- key such as the inventory key.
--
--   local focus = dofile(repo .. "/tools/r451_kf/focus.lua")
--   local got = focus.initial(formspec, {new_form = bool, preserved = name})
--   -- got = {type = "textarea", name = "", kind = "editbox", eats = true,
--   --        how = "first editbox"} or nil (nothing focusable)
--
-- The engine's steps, modelled:
--   * regenerateGui: on the same form (the form name equals the last one
--     shown in this window) the focused element's name is kept
--     (opts.preserved); a new form starts with none. The inventory's form
--     name is "", the same as a fresh window's last name, so the inventory
--     is never a new form.
--   * parseSetFocus: set_focus[name;force] takes effect when forced or on a
--     new form; it names the element to focus.
--   * while parsing, an element of a focusable type (checkbox, scrollbar,
--     the buttons, table, textlist, dropdown, pwdfield, an editable field or
--     textarea) whose name is the one to focus gets the focus; one parsed
--     before the set_focus does not.
--   * afterwards, when nothing got it or a tabheader has it,
--     setInitialFocus over the window's direct children (not the contents
--     of a scroll_container): 1. the first empty edit box, 2. the first edit
--     box, 3. the first table (a textlist included), 4. the last button,
--     5. the first other element that is neither static text nor a
--     tabheader.
-- Edit boxes are field[] with a name, pwdfield[] and every textarea[] (a
-- read-only one too: CGUIEditBox::processKey consumes every character key
-- even when not writable). A textlist[] is a GUITable as well (parseTextList),
-- and tables search as the player types (GUITable::OnEvent consumes every
-- character key). Buttons, dropdowns and scrollbars pass letters on to the
-- window, which closes on the inventory key; a focused checkbox (or a
-- dropdown's open list) gets that key forwarded
-- (GUIFormSpecMenu::preprocessEvent, list boxes and checkboxes only).

local M = {}

-- Elements split at unescaped "]", their fields at unescaped ";".
local function split(text, sep)
	local out, piece, i = {}, {}, 1
	while i <= #text do
		local c = text:sub(i, i)
		if c == "\\" then
			piece[#piece + 1] = text:sub(i, i + 1)
			i = i + 1
		elseif c == sep then
			out[#out + 1] = table.concat(piece)
			piece = {}
		else
			piece[#piece + 1] = c
		end
		i = i + 1
	end
	return out, table.concat(piece)
end

function M.elements(fs)
	local list = {}
	local raw = split(fs, "]")
	for _, text in ipairs(raw) do
		local kind, args = text:match("^%s*([%w_]+)%[(.*)$")
		if kind then
			local parts, last = split(args, ";")
			parts[#parts + 1] = last
			list[#list + 1] = {type = kind, parts = parts}
		end
	end
	return list
end

local BUTTONS = {button = true, button_exit = true, button_url = true,
	button_url_exit = true, button_key = true, image_button = true,
	image_button_exit = true, item_image_button = true}
local OTHER = {list = true, checkbox = true, image = true, animated_image = true,
	item_image = true, dropdown = true, hypertext = true,
	box = true, scrollbar = true, scroll_container = true, model = true}
-- The parsers that compare the element's name with the one to focus.
local FOCUSABLE = {checkbox = true, scrollbar = true, table = true,
	textlist = true, dropdown = true, pwdfield = true}
for kind in pairs(BUTTONS) do FOCUSABLE[kind] = true end
-- The name field's index per type (positioned forms; field[] and textarea[]
-- with three or four fields are the legacy "simple" form, name first).
local NAME_AT = {checkbox = 2, scrollbar = 4, table = 3, textlist = 3,
	dropdown = 3, pwdfield = 3, tabheader = 2, field = 3, textarea = 3}
for kind in pairs(BUTTONS) do NAME_AT[kind] = 3 end
NAME_AT.image_button, NAME_AT.image_button_exit = 4, 4
NAME_AT.item_image_button = 4

-- An element's name, GUI kind ("editbox", "table", "button", "tab",
-- "static", "other" or nil for no child element) and default text.
function M.describe(e)
	local kind, at = e.type, NAME_AT[e.type]
	-- tabheader[X,Y;H;name;...] and [X,Y;W,H;name;...] carry a size first.
	if kind == "tabheader" and (e.parts[2] or ""):match("^[%d.,%s-]+$") then at = 3 end
	if (kind == "field" or kind == "textarea") and #e.parts <= 4 then at = 1 end
	local name = at and e.parts[at] or ""
	if kind == "field" or kind == "textarea" or kind == "pwdfield" then
		if kind == "field" and name == "" then return name, "static" end
		local label, default = e.parts[at + 1] or "", e.parts[at + 2] or ""
		if kind == "pwdfield" then default = "" end
		-- A read-only textarea shows its label when its default is empty
		-- (createTextField swaps them).
		if kind == "textarea" and name == "" and default == "" then default = label end
		return name, "editbox", default
	end
	if kind == "table" or kind == "textlist" then return name, "table" end
	if BUTTONS[kind] then return name, "button" end
	if kind == "tabheader" then return name, "tab" end
	if kind == "label" or kind == "vertlabel" then return name, "static" end
	if OTHER[kind] then return name, "other" end
	return name, nil
end

local EATS = {editbox = true, table = true}
local YES = {["true"] = true, yes = true, on = true, ["1"] = true}

-- The element focused when the window is built; see the header.
function M.initial(fs, opts)
	opts = opts or {}
	local focus_name = opts.preserved
	local focused, how
	local children, depth = {}, 0
	if focus_name then how = "kept by name" end
	for _, e in ipairs(M.elements(fs)) do
		local name, kind, default = M.describe(e)
		local entry = {type = e.type, name = name, kind = kind, default = default,
			eats = EATS[kind] == true}
		if e.type == "set_focus" then
			local force = YES[e.parts[2] or ""] == true
			if force or opts.new_form then
				focus_name, how = e.parts[1], "set_focus"
			end
		elseif e.type == "scroll_container_end" then
			depth = depth - 1
		elseif kind then
			local editable = kind ~= "editbox" or e.type == "pwdfield" or name ~= ""
			if focus_name and name == focus_name and editable and
					(FOCUSABLE[e.type] or kind == "editbox") then
				focused = entry
			end
			if depth == 0 then children[#children + 1] = entry end
			if e.type == "scroll_container" then depth = depth + 1 end
		end
	end
	if focused and focused.kind ~= "tab" then
		focused.how = how
		return focused
	end
	local function pick(rule, test, last)
		local from, to, step = 1, #children, 1
		if last then from, to, step = #children, 1, -1 end
		for i = from, to, step do
			if test(children[i]) then
				children[i].how = rule
				return children[i]
			end
		end
	end
	return pick("first empty editbox", function(c)
			return c.kind == "editbox" and (c.default or "") == "" end)
		or pick("first editbox", function(c) return c.kind == "editbox" end)
		or pick("first table", function(c) return c.kind == "table" end)
		or pick("last button", function(c) return c.kind == "button" end, true)
		or pick("first other", function(c)
			return c.kind ~= "static" and c.kind ~= "tab" end)
end

-- The formspec without its set_focus[] elements (what the engine would pick
-- on its own).
function M.without_set_focus(fs)
	return (fs:gsub("set_focus%[[^%]]*%]", ""))
end

return M
