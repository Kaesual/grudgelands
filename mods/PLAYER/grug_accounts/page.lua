-- The Account page (Round 79, round79-plan.md §4 PAGE; Round 86: the
-- layout "The Charter", tools/r84_account_mock): an inventory page that
-- names the website account a character is linked to, lists the account's
-- rewards and takes a link code. A view of the API in init.lua that decides
-- nothing itself: "linked" is account_of, the link flow's state and lines
-- are link_state, the reason a link cannot start is can_link, the rewards
-- are rewards_of and what linking gives is default_rewards, both with the
-- catalogue's icon and hint. A button calls the API; its answer arrives
-- later through register_on_link_state and re-sends the page. The tab shows
-- only while enabled() (the bridge is active and the game holds a list).
-- Real coordinates in the 20 x 13.5 body.
--
-- The Charter: a framed panel on the left with the crest (and before
-- linking the rewards every linked account gets, or after it the account),
-- the action column on the right (the steps and the code field, the offer,
-- or the account's rewards). Coordinates and text sizes are the mock-up
-- builder's (tools/r84_account_mock/layouts.py), each text size times the
-- player's text scale.
--
-- While the website is asked (checking, confirming) the buttons are drawn
-- inert in their place, so the layout does not jump. The code the player
-- typed is kept in the sfinv context (session only, never stored or logged)
-- and echoed into the field, so a re-send keeps it while the page is open;
-- so is the offered account's name for the wait after Link.

-- grug_accounts' and grug_bridge's portable fixtures load init.lua without
-- sfinv: they get no page.
if not rawget(_G, "sfinv") then return end

local PAGE = "grug_accounts:account"
grug_accounts.PAGE = PAGE
local UI = grug_core.ui
local esc = core.formspec_escape

local TEXT, MUTED, GOLD = "#eeeae1", "#b8bdb4", UI.colors.accent
local RULE, ERROR = "#d1c09a47", "#efafa2"

-- The panel (its frame, the crest's centre line) and the action column.
local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 0.43, 0.30, 7.32, 12.82
local PANEL_CX = 4.09
local STRIP_X, STRIP_W = 1.12, 5.94
local COL_X, COL_W = 8.49, 10.76
local CREST = "grug_creation_crest.png"
-- The linked column's rewards sit between its first rule and the help block.
local REWARDS_TOP, REWARDS_BOTTOM, HELP_Y = 3.15, 9.40, 9.56
-- Rough text widths in form units per character at size 1 (the mock's
-- Arimo at 1366 x 768 with a margin): a text that would not fit gets a
-- smaller size or wraps.
local PER_CHAR, PER_CHAR_BOLD = 0.17, 0.18

local CODE, LINK = "grug_account_code", "grug_account_link"
local CONFIRM, CANCEL = "grug_account_confirm", "grug_account_cancel"
local FOCUS = "grug_account_focus"
local ACTIONS = {[LINK] = true, [CONFIRM] = true, [CANCEL] = true}
local WAITING = {checking = true, confirming = true}
local INERT_TEXT = "#8a8f86"

local TEXT_OF = {
	title = "Link your character",
	connect = "Connect %s to your Grudgelands website account.",
	step1 = "Open the website",
	step2 = "Sign in and choose \"" .. grug_accounts.ADD_ENTRY .. "\"",
	step2_line = "Then \"" .. grug_accounts.CODE_BUTTON .. "\". The code is valid for 10 minutes.",
	-- The link by password (web-accounts.md §6a), the way that needs no code.
	password = "Or link it there with this character's name and password.",
	step3 = "Enter your 10-character code",
	gets = "Every linked account gets",
	checking = "Checking your code with the website. This can take a few seconds, please wait.",
	confirming = "Linking your character. This can take a few seconds, please wait.",
	confirm_title = "Confirm your account",
	confirm_line = "Link %s to the website account",
	own = "Only link to your own account.",
	undo = "Only a website administrator can undo a link.",
	rewards = "Your rewards",
	use = "Use these on every character linked to your account.",
	no_rewards = "Your account has no rewards yet.",
	help = "Missing a reward or want to unlink?",
	ask = "Ask a website administrator.",
}

local function chars(text)
	return select(2, text:gsub("[^\128-\191]", ""))
end

-- The size at most `size` (at least `min`) a text needs to fit `width`, or
-- nil when it does not fit even at `min`.
local function fit(text, size, min, width, bold)
	local need = chars(text) * (bold and PER_CHAR_BOLD or PER_CHAR)
	if need * size <= width then return size end
	local fitted = width / need
	if fitted >= min then return fitted end
	return nil
end

--
-- Drawing: one formspec list `fs` and the player's text scale.
--

local Draw = {}
Draw.__index = Draw

local function new_draw(scale)
	return setmetatable({fs = {}, scale = scale, texts = 0}, Draw)
end

function Draw:add(text)
	self.fs[#self.fs + 1] = text
end

-- A colour without alpha is drawn opaque (the engine's box[] would give it
-- alpha 140).
function Draw:box(x, y, w, h, color)
	if #color == 7 then color = color .. "ff" end
	self:add(("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(x, y, w, h, color))
end

function Draw:image(x, y, w, h, texture)
	self:add(("image[%.3f,%.3f;%.3f,%.3f;%s]"):format(x, y, w, h, esc(texture)))
end

-- One line; `y` is its midline (real coordinates).
function Draw:text(x, y, value, size, color, bold)
	self:add(("style_type[label;font=%s;font_size=*%.3f]"):format(bold and "bold" or "normal",
		size * self.scale))
	self:add(("label[%.3f,%.3f;%s]"):format(x, y, esc(core.colorize(color or TEXT, value))))
end

-- Wrapped text in a nameless textarea (it wraps and clips inside its
-- rectangle); `y` is the midline of its first line.
function Draw:para(x, y, w, h, value, size, color, bold)
	local top = y - 0.25 * size
	self:add(("style_type[textarea;textcolor=%s;font=%s]"):format(color or TEXT,
		bold and "bold" or "normal"))
	self:add(UI.prose(x, top, w, h, value, false, self.scale, size * self.scale))
	self:add(("style_type[textarea;textcolor=%s;font=normal]"):format(TEXT))
end

-- One line centred in [x, x + w] around the midline `y`: a flat button
-- without a background (a label cannot centre on every client); the page
-- ignores its click.
function Draw:centred(x, y, w, value, size, color, bold)
	self.texts = self.texts + 1
	local name = ("grug_account_text_%d"):format(self.texts)
	self:add(("style[%s,%s:hovered,%s:pressed,%s:focused;border=false;bgimg=blank.png;" ..
		"bgimg_middle=0;padding=0,0,0,0;content_offset=0,0;font=%s;font_size=*%.3f;textcolor=%s]"):format(
		name, name, name, name, bold and "bold" or "normal", size * self.scale, color or TEXT))
	local h = 0.4 + 0.35 * size
	self:add(("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(x, y - h / 2, w, h, name, esc(value)))
end

-- A line that shrinks to fit `w`, or wraps at `min` into `lines` lines.
function Draw:fitted(x, y, w, value, size, min, color, bold, centred, lines)
	local fitted = fit(value, size, min, w, bold)
	if fitted and centred then
		self:centred(x, y, w, value, fitted, color, bold)
	elseif fitted then
		self:text(x, y, value, fitted, color, bold)
	else
		if centred then self:add("style_type[textarea;halign=center]") end
		self:para(x, y, w, (lines or 2) * 0.5 * min + 0.2, value, min, color, bold)
		if centred then self:add("style_type[textarea;halign=left]") end
	end
end

function Draw:button(name, x, y, w, h, label, role)
	self:add(UI.button_style(name, role, 1.04 * self.scale))
	self:add(("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(x, y, w, h, name, esc(label)))
end

-- The website's address; the client asks before it opens a browser.
function Draw:website(x, y, w, h)
	self:add(UI.button_style("grug_account_website", nil, 1.04 * self.scale))
	self:add(("button_url[%.3f,%.3f;%.3f,%.3f;grug_account_website;%s;%s]"):format(x, y, w, h,
		esc("Open website"), esc(grug_accounts.WEBSITE_URL)))
end

-- A button while the website is asked: the same place and size, dimmed,
-- and a field the page ignores.
function Draw:inert(x, y, w, h, label)
	local name = ("grug_account_wait_%d"):format(#self.fs)
	self:add(("style[%s,%s:hovered,%s:pressed,%s:focused;border=false;bgcolor=#ffffff;" ..
		"bgimg=%s;bgimg_middle=6;padding=-4,-4,4,4;font_size=*%.3f;textcolor=%s;" ..
		"content_offset=0,0]"):format(name, name, name, name,
		esc("grug_ui_button.png^[opacity:110"), 1.04 * self.scale, INERT_TEXT))
	self:add(("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(x, y, w, h, name, esc(label)))
end

-- A reward as the mock draws it: the framed icon, the name and the kind
-- beside it, the hint below when `hint`; the whole row carries the hint as
-- its tooltip.
function Draw:reward(entry, x, y, size, w, hint, name_size)
	self:box(x, y, size, size, "#a995674b")
	self:box(x + 0.025, y + 0.025, size - 0.05, size - 0.05, "#263034")
	if entry.icon then self:image(x + 0.08, y + 0.08, size - 0.16, size - 0.16, entry.icon) end
	local start = x + size + 0.25
	local kind = entry.kind:sub(1, 1):upper() .. entry.kind:sub(2)
	self:text(start, y + size * 0.32, entry.name, fit(entry.name, name_size or 1.15, 0.8,
		x + w - start, true) or 0.8, TEXT, true)
	self:text(start, y + size * 0.72, kind, 0.95, MUTED)
	if hint and entry.hint then self:text(start, y + size + 0.19, entry.hint, 0.98, MUTED) end
	self:add(("tooltip[%.3f,%.3f;%.3f,%.3f;%s]"):format(x, y, w, size,
		esc(entry.name .. " · " .. kind .. ". " .. (entry.hint or ""))))
end

function Draw:step(x, y, number, title)
	self:text(x, y, tostring(number), 0.99, GOLD, true)
	self:text(x + 0.52, y, title, 1.13, TEXT, true)
end

--
-- The panel
--

local function frame(d)
	d:box(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, "#97805c")
	d:box(PANEL_X + 0.025, PANEL_Y + 0.025, PANEL_W - 0.05, PANEL_H - 0.05, "#203033")
	for _, x in ipairs({PANEL_X + 0.17, PANEL_X + PANEL_W - 0.19}) do
		d:box(x, PANEL_Y + 0.02, 0.018, PANEL_H - 0.03, "#b3996648")
	end
	for _, y in ipairs({PANEL_Y + 0.19, PANEL_Y + 12.60}) do
		d:box(PANEL_X + 0.17, y, PANEL_W - 0.34, 0.018, "#b3996648")
	end
end

local function crest(d, size, top)
	d:image(PANEL_CX - size / 2, top, size, size, CREST)
end

-- Before linking: the crest and what every linked account gets (the
-- website's default_rewards), or the crest alone when it names none.
local function panel_offer(d, defaults)
	frame(d)
	if #defaults == 0 then
		crest(d, 5.88, 3.58)
		return
	end
	local many = #defaults > 1
	if many then crest(d, 4.75, 0.68) else crest(d, 5.62, 1.12) end
	local y = many and 5.81 or 7.15
	d:box(STRIP_X, y, STRIP_W, 0.018, RULE)
	d:text(STRIP_X, y + 0.54, TEXT_OF.gets, 1.06, GOLD, true)
	for index, entry in ipairs(defaults) do
		d:reward(entry, STRIP_X, y + 1.06 + (index - 1) * 1.28, many and 1.04 or 1.65, STRIP_W)
	end
	if not many and defaults[1].hint then
		d:fitted(STRIP_X, y + 3.18, STRIP_W, defaults[1].hint, 1.02, 0.8, MUTED)
	end
end

local function panel_crest(d)
	frame(d)
	crest(d, 5.88, 3.58)
end

local function panel_linked(d, player, account)
	frame(d)
	crest(d, 5.48, 1.70)
	local inner = 6.6
	d:centred(PANEL_CX - inner / 2, 8.00, inner, "LINKED WEBSITE ACCOUNT", 0.93, GOLD, true)
	d:fitted(PANEL_CX - inner / 2, 9.04, inner, account.name, 2.10, 1.0, TEXT, false, true, 3)
	d:centred(PANEL_CX - inner / 2, 10.03 + (fit(account.name, 2.10, 1.0, inner) and 0 or 0.45),
		inner, "Linked to " .. player:get_player_name(), 1.06, MUTED)
end

--
-- The column
--

local function identity(d, subtitle)
	d:text(COL_X, 1.29, "WEBSITE ACCOUNT", 0.9, GOLD, true)
	d:text(COL_X, 2.17, TEXT_OF.title, 2.06)
	if subtitle then d:para(COL_X, 3.02, COL_W, 0.85, subtitle, 1.05, MUTED) end
end

-- The status line under the code field: a refusal, the wait, or why a link
-- cannot start now.
local function status(d, x, y, w, lines, color)
	if #lines > 0 then d:para(x, y, w, 0.95, table.concat(lines, "\n"), 1.0, color) end
end

-- Not linked: the steps, the code field, Check code and the status line.
local function unlinked(d, player, context, state)
	panel_offer(d, grug_accounts.default_rewards())
	local x, w = COL_X, COL_W
	identity(d, TEXT_OF.connect:format(player:get_player_name()))
	d:box(x, 3.83, w, 0.018, RULE)
	d:step(x, 4.67, 1, TEXT_OF.step1)
	d:text(x + 0.52, 5.41, grug_accounts.WEBSITE, 1.09)
	d:website(x + 6.78, 4.68, 3.54, 0.82)
	d:step(x, 6.84, 2, TEXT_OF.step2)
	d:text(x + 0.52, 7.51, TEXT_OF.step2_line, 1.03, MUTED)
	d:text(x + 0.52, 8.07, TEXT_OF.password, 0.95, MUTED)
	-- The gold edge makes the editable row the strongest control on the page.
	d:add(("background9[%.3f,8.660;%.3f,3.820;grug_ui_panel.png;false;6]"):format(x, w))
	d:box(x, 8.66, 0.065, 3.82, GOLD)
	d:step(x + 0.38, 9.42, 3, TEXT_OF.step3)
	local fx, fy, fw, fh = x + 0.44, 10.14, 6.11, 1.00
	d:add(UI.input_background(fx, fy, fw, fh, CODE))
	-- The native field draws its text at its left edge: it starts inside the
	-- background, as the mock's inset.
	d:add(("field[%.3f,%.3f;%.3f,%.3f;%s;;%s]field_close_on_enter[%s;false]"):format(
		fx + 0.15, fy, fw - 0.15, fh, CODE, esc(context.grug_account_code or ""), CODE))
	if WAITING[state.state] then
		d:inert(x + 6.77, fy, 3.52, fh, "Check code")
	else
		d:button(LINK, x + 6.77, fy, 3.52, fh, "Check code", "selected")
	end
	local lines, color = {}, GOLD
	if state.state == "refused" and state.message then
		lines[1], color = state.message, ERROR
	elseif state.state == "checking" then
		lines[1] = TEXT_OF.checking
	end
	if not WAITING[state.state] then
		-- Why Check code cannot start now replaces a refusal: the status has
		-- room for two lines, and this is the one that still holds.
		local ok, reason = grug_accounts.can_link(player)
		if not ok and reason then lines = {reason} end
	end
	status(d, fx, 11.81, w - 0.88, lines, color)
end

-- The website's offer, and the same view while the confirmation is sent.
-- link_state names the account only in the offer, so the page keeps the
-- name it showed (in the sfinv context) for the wait that follows.
local function offer(d, player, context, state)
	if state.state == "offer" then context.grug_account_offer = state.account_name end
	panel_crest(d)
	local x, y, w = COL_X, 4.42, COL_W
	identity(d)
	d:text(x, y, TEXT_OF.confirm_title, 1.45, TEXT, true)
	d:text(x, y + 1.03, TEXT_OF.confirm_line:format(player:get_player_name()), 1.12)
	d:fitted(x, y + 1.85, w, state.account_name or context.grug_account_offer or "", 1.65, 1.1,
		GOLD, true, false, 2)
	d:text(x, y + 3.03, TEXT_OF.own, 1.02)
	d:text(x, y + 3.57, TEXT_OF.undo, 1.02, MUTED)
	if state.state == "confirming" then
		d:inert(x, y + 4.19, 3.7, 0.89, "Confirm link")
		d:inert(x + 3.94, y + 4.19, 2.45, 0.89, "Cancel")
		status(d, x, y + 5.65, w, {TEXT_OF.confirming}, GOLD)
	else
		d:button(CONFIRM, x, y + 4.19, 3.7, 0.89, "Confirm link", "confirm")
		d:button(CANCEL, x + 3.94, y + 4.19, 2.45, 0.89, "Cancel", "danger")
	end
end

-- In character creation (user, 2026-11-15): the one line can_link gives,
-- no code field and no button.
local function creating(d, reason)
	panel_crest(d)
	identity(d)
	d:para(COL_X, 4.67, COL_W, 1.4, reason, 1.15, GOLD)
end

-- The linked column's rewards: one or two as the mock's wide rows, more in
-- two columns whose rows shrink to fit above the help block (the hint below
-- each while a row has room, else only in its tooltip).
local function owned(d, rewards)
	local x, w = COL_X, COL_W
	if #rewards <= 2 then
		for index, entry in ipairs(rewards) do
			local y = 3.35 + (index - 1) * 2.38
			d:box(x, y - 0.20, w, 0.018, RULE)
			d:reward(entry, x + 0.12, y + 0.20, 1.37, w - 0.24, true)
		end
		return
	end
	local gap = 0.3
	local column_w = (w - gap) / 2
	local rows = math.ceil(#rewards / 2)
	local pitch = math.min(2.0, (REWARDS_BOTTOM - REWARDS_TOP) / rows)
	local roomy = pitch >= 1.45
	local size = roomy and 0.8 or math.max(0.5, math.min(0.8, pitch - 0.15))
	for index, entry in ipairs(rewards) do
		local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
		local y = REWARDS_TOP + row * pitch
		if column == 0 then d:box(x, y, w, 0.018, RULE) end
		local cx = x + column * (column_w + gap)
		d:reward(entry, cx + 0.12, y + 0.15, size, column_w - 0.24, false, roomy and 1.05 or 0.95)
		if roomy and entry.hint then
			d:fitted(cx + 0.12, y + 0.15 + size + 0.27, column_w - 0.24, entry.hint, 0.9, 0.7, MUTED)
		end
	end
end

-- Linked: the account on the panel, its rewards with a hint how to use
-- each, and where to ask about a missing reward or an unlink.
local function linked(d, player, account)
	panel_linked(d, player, account)
	local by_id = {}
	for _, entry in ipairs(grug_accounts.catalog()) do by_id[entry.id] = entry end
	local rewards = {}
	for _, reward in ipairs(grug_accounts.rewards_of(player:get_player_name())) do
		local entry = by_id[reward.id] or {}
		rewards[#rewards + 1] = {id = reward.id, kind = reward.kind, name = reward.name,
			icon = entry.icon, hint = entry.hint}
	end
	local x, w = COL_X, COL_W
	d:text(x, 1.40, TEXT_OF.rewards, 2.06)
	if #rewards > 0 then
		d:text(x, 2.32, TEXT_OF.use, 1.05, MUTED)
		owned(d, rewards)
	else
		d:box(x, 3.3, w, 0.018, RULE)
		d:text(x, 4.15, TEXT_OF.no_rewards, 1.15)
	end
	d:box(x, HELP_Y, w, 0.022, RULE)
	d:text(x, HELP_Y + 0.55, TEXT_OF.help, 1.04, TEXT, true)
	d:text(x, HELP_Y + 1.12, TEXT_OF.ask, 1.02, MUTED)
	d:text(x, HELP_Y + 1.99, grug_accounts.WEBSITE, 1.02)
	d:website(x + 4.2, HELP_Y + 1.61, 3.15, 0.76)
end

local function content(player, context)
	local d = new_draw(UI.text_scale(player))
	-- The focus sits on an invisible button (module guide "Initial focus"):
	-- the code field would eat the inventory key.
	d:add("real_coordinates[true]")
	d:add(UI.fonts(d.scale))
	d:add(("set_focus[%s;true]button[0,0;0,0;%s;]"):format(FOCUS, FOCUS))
	local account = grug_accounts.account_of(player:get_player_name())
	local state = grug_accounts.link_state(player)
	if account then
		linked(d, player, account)
	elseif state.state == "offer" or state.state == "confirming" then
		offer(d, player, context, state)
	elseif grug_accounts.in_creation(player) then
		creating(d, select(2, grug_accounts.can_link(player)) or "")
	else
		unlinked(d, player, context, state)
	end
	d:add(("style_type[label;font=normal;font_size=*%.3f]"):format(d.scale))
	return table.concat(d.fs)
end

-- The name whose click is being handled: the handler re-sends the page once
-- at its end, so the state callbacks it causes send nothing.
local handling

local function redraw(player)
	local name = player:get_player_name()
	local context = sfinv.contexts[name]
	if context and context.page == PAGE and handling ~= name then
		sfinv.set_player_inventory_formspec(player, context)
	end
end

sfinv.register_page(PAGE, {
	title = "Website Account",
	is_in_nav = function() return grug_accounts.enabled() end,
	get = function(_, player, context)
		return sfinv.make_formspec(player, context, content(player, context), false)
	end,
	on_player_receive_fields = function(_, player, context, fields)
		if fields[CODE] then context.grug_account_code = fields[CODE] end
		-- Only the actions re-send the page: the focus, a centred text, an
		-- inert button and "Open website" (the client opens it) do not.
		local acted = fields.key_enter_field == CODE
		for field in pairs(ACTIONS) do acted = acted or fields[field] ~= nil end
		if fields.quit or not acted then return true end
		local state = grug_accounts.link_state(player).state
		handling = player:get_player_name()
		if (fields[LINK] or fields.key_enter_field == CODE) and not WAITING[state] then
			grug_accounts.request_link(player, fields[CODE] or context.grug_account_code or "")
		elseif fields[CONFIRM] then
			grug_accounts.confirm_link(player)
		elseif fields[CANCEL] then
			grug_accounts.cancel_link(player)
		end
		handling = nil
		sfinv.set_player_inventory_formspec(player, context)
		return true
	end,
})

-- The answer arrived or a timeout ended the request; the list changed a
-- binding or the rewards; the character finished its creation.
grug_accounts.register_on_link_state(redraw)
grug_accounts.register_on_change(function(names)
	for _, name in ipairs(names) do
		local player = core.get_player_by_name(name)
		if player then redraw(player) end
	end
end)
grug_classes.register_on_arrival(redraw)
-- The website changed what every linked account gets: every open page,
-- linked or not (sfinv keeps a context only for online characters).
grug_accounts.register_on_defaults(function()
	for name, context in pairs(sfinv.contexts) do
		local player = context.page == PAGE and core.get_player_by_name(name)
		if player then redraw(player) end
	end
end)
