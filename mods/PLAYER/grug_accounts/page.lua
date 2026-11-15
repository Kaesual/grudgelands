-- The Account page (Round 79, round79-plan.md §4 PAGE): an inventory page
-- that names the website account a character is linked to, lists the
-- account's rewards and takes a link code. A view of the API in init.lua
-- that decides nothing itself: "linked" is account_of, the link flow's state
-- and lines are link_state, the reason a link cannot start is can_link and
-- the rewards are rewards_of with the catalogue's icon and hint. A button
-- calls the API; its answer arrives later through register_on_link_state and
-- re-sends the page. The tab shows only while enabled() (the bridge is
-- active and the game holds a list). Real coordinates in the 20 x 13.5 body.
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

-- One card in the middle of the body; every view keeps the action row and
-- the status line at the same height.
local CARD_X, CARD_Y, CARD_W, CARD_H = 3.5, 0.6, 13, 6.6
local X, W = CARD_X + 0.5, CARD_W - 1
local ROW_Y, BUTTON_W, BUTTON_H, FIELD_W = 4.7, 2.6, 0.7, 6.2
local STATUS_Y, STATUS_H = 5.6, 1.3
local REWARDS_Y, REWARD_H = 3.85, 1.0

local CODE, LINK = "grug_account_code", "grug_account_link"
local CONFIRM, CANCEL = "grug_account_confirm", "grug_account_cancel"
local FOCUS = "grug_account_focus"
local WAITING = {checking = true, confirming = true}
local INERT_TEXT = "#8a8f86"

local TEXT = {
	intro = "Rewards on your website account reach all your characters.",
	how = "To link this character, sign in on " .. grug_accounts.WEBSITE .. ". Link it " ..
		"there with its name and password, or create a link code there and enter it here.",
	checking = "Checking your code with the website. This can take a few seconds, please wait.",
	confirming = "Linking your character. This can take a few seconds, please wait.",
	warning = "Only link to your own account. Only an administrator can undo a link.",
	no_rewards = "Your account has no rewards yet.",
}

-- Wrapped text in `color` (a nameless textarea: it wraps and clips inside
-- its rectangle, so a long account name never leaves the card).
local function prose(fs, x, y, w, h, text, color, size, scale)
	fs[#fs + 1] = ("style_type[textarea;textcolor=%s]"):format(color or UI.colors.text)
	fs[#fs + 1] = UI.prose(x, y, w, h, text, false, scale, (size or 1.05) * scale)
	fs[#fs + 1] = ("style_type[textarea;textcolor=%s]"):format(UI.colors.text)
end

local function button(fs, name, x, label, role, scale)
	fs[#fs + 1] = UI.button_style(name, role, scale)
	fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(x, ROW_Y, BUTTON_W, BUTTON_H,
		name, esc(label))
end

-- A button while the website is asked: the same place and size, dimmed,
-- and a field the page ignores.
local function inert(fs, x, label, scale)
	local name = ("grug_account_wait_%d"):format(#fs)
	fs[#fs + 1] = ("style[%s,%s:hovered,%s:pressed,%s:focused;border=false;bgcolor=#ffffff;" ..
		"bgimg=%s;bgimg_middle=6;padding=-4,-4,4,4;font_size=*%.3f;textcolor=%s;" ..
		"content_offset=0,0]"):format(name, name, name, name,
		esc("grug_ui_button.png^[opacity:110"), scale, INERT_TEXT)
	fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,%.3f;%s;%s]"):format(x, ROW_Y, BUTTON_W, BUTTON_H,
		name, esc(label))
end

local function card(fs, h, scale)
	fs[#fs + 1] = UI.panel(CARD_X, CARD_Y, CARD_W, h)
	fs[#fs + 1] = UI.heading(X, CARD_Y + 0.45, "WEBSITE ACCOUNT", scale)
	fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,0.015;#d4b77d40]"):format(X, CARD_Y + 0.8, W)
end

-- Not linked: what an account gives, how to link, the code field, Link and
-- the status line (a refusal, the wait, or why a link cannot start now).
local function unlinked(fs, player, context, state, scale)
	card(fs, CARD_H, scale)
	prose(fs, X, 1.6, W, 2.5, TEXT.intro .. "\n" .. TEXT.how, nil, 1.05, scale)
	fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(X, ROW_Y - 0.3,
		esc(core.colorize(UI.colors.muted, "Link code")))
	fs[#fs + 1] = UI.input_background(X, ROW_Y, FIELD_W, BUTTON_H, CODE)
	fs[#fs + 1] = ("field[%.3f,%.3f;%.3f,%.3f;%s;;%s]field_close_on_enter[%s;false]"):format(
		X, ROW_Y, FIELD_W, BUTTON_H, CODE, esc(context.grug_account_code or ""), CODE)
	if WAITING[state.state] then
		inert(fs, X + FIELD_W + 0.3, "Link", scale)
	else
		button(fs, LINK, X + FIELD_W + 0.3, "Link", nil, scale)
	end
	local lines, color = {}, UI.colors.accent
	if state.state == "refused" and state.message then
		lines[1], color = state.message, UI.colors.danger
	elseif state.state == "checking" then
		lines[1] = TEXT.checking
	end
	if not WAITING[state.state] then
		local ok, reason = grug_accounts.can_link(player)
		if not ok and reason and reason ~= lines[1] then lines[#lines + 1] = reason end
	end
	if #lines > 0 then
		prose(fs, X, STATUS_Y, W, STATUS_H, table.concat(lines, "\n"), color, 1.05, scale)
	end
end

-- The website's offer, and the same view while the confirmation is sent.
-- link_state names the account only in the offer, so the page keeps the
-- name it showed (in the sfinv context) for the wait that follows.
local function offer(fs, player, context, state, scale)
	if state.state == "offer" then context.grug_account_offer = state.account_name end
	card(fs, CARD_H, scale)
	prose(fs, X, 1.6, W, 1.75, ("Link %s to the website account %s?"):format(
		player:get_player_name(), state.account_name or context.grug_account_offer or ""),
		nil, 1.15, scale)
	prose(fs, X, 3.4, W, 0.95, TEXT.warning, UI.colors.accent, 1.05, scale)
	if state.state == "confirming" then
		inert(fs, X, "Link", scale)
		inert(fs, X + BUTTON_W + 0.3, "Cancel", scale)
		prose(fs, X, STATUS_Y, W, STATUS_H, TEXT.confirming, UI.colors.accent, 1.05, scale)
	else
		button(fs, CONFIRM, X, "Link", "confirm", scale)
		button(fs, CANCEL, X + BUTTON_W + 0.3, "Cancel", "danger", scale)
	end
end

-- In character creation (user, 2026-11-15): the one line can_link gives,
-- no code field and no Link.
local function creating(fs, reason, scale)
	card(fs, CARD_H, scale)
	prose(fs, X, 1.6, W, 1.4, reason, UI.colors.accent, 1.15, scale)
end

-- Linked: the account's name and its rewards, one row each (icon, name and
-- kind, where to use it).
local function linked(fs, player, account, scale)
	local rewards, by_id = grug_accounts.rewards_of(player:get_player_name()), {}
	for _, entry in ipairs(grug_accounts.catalog()) do by_id[entry.id] = entry end
	card(fs, math.max(CARD_H, REWARDS_Y - CARD_Y + math.max(1, #rewards) * REWARD_H + 0.3), scale)
	prose(fs, X, 1.6, W, 1.4, "Linked to the website account " .. account.name .. ".", nil, 1.15, scale)
	fs[#fs + 1] = UI.heading(X, REWARDS_Y - 0.35, "ACCOUNT REWARDS", scale)
	if #rewards == 0 then
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(X, REWARDS_Y + 0.3,
			esc(core.colorize(UI.colors.muted, TEXT.no_rewards)))
	end
	for index, reward in ipairs(rewards) do
		local entry = by_id[reward.id] or {}
		local y = REWARDS_Y + (index - 1) * REWARD_H
		local kind = reward.kind:sub(1, 1):upper() .. reward.kind:sub(2)
		if entry.icon then
			fs[#fs + 1] = ("image[%.3f,%.3f;0.8,0.8;%s]"):format(X, y + 0.05, esc(entry.icon))
		end
		fs[#fs + 1] = ("style_type[label;font=bold;font_size=*%.3f]"):format(scale)
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(X + 1.0, y + 0.25, esc(reward.name ..
			"  " .. core.colorize(UI.colors.muted, kind)))
		fs[#fs + 1] = ("style_type[label;font=normal;font_size=*%.3f]"):format(0.9 * scale)
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(X + 1.0, y + 0.65,
			esc(core.colorize(UI.colors.muted, entry.hint or "")))
		fs[#fs + 1] = ("style_type[label;font=normal;font_size=*%.3f]"):format(scale)
	end
end

local function content(player, context)
	local scale = UI.text_scale(player)
	-- The focus sits on an invisible button (module guide "Initial focus"):
	-- the code field would eat the inventory key.
	local fs = {"real_coordinates[true]", UI.fonts(scale),
		("set_focus[%s;true]button[0,0;0,0;%s;]"):format(FOCUS, FOCUS)}
	local account = grug_accounts.account_of(player:get_player_name())
	local state = grug_accounts.link_state(player)
	if account then
		linked(fs, player, account, scale)
	elseif state.state == "offer" or state.state == "confirming" then
		offer(fs, player, context, state, scale)
	else
		if grug_accounts.in_creation(player) then
			creating(fs, select(2, grug_accounts.can_link(player)) or "", scale)
		else
			unlinked(fs, player, context, state, scale)
		end
	end
	return table.concat(fs)
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
		if fields.quit or fields[FOCUS] then return true end
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
