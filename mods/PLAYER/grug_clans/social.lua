-- The clan card of the Social tab and the clan parts of its Online Players
-- rows (Round 76 lane SOCIAL, rulings 7 and 8). The page is grug_parties's
-- (grug_parties/ui.lua); grug_clans depends on grug_parties, so this file
-- installs the card there as grug_parties.clan_section, the way
-- grug_pvp/page.lua installs the PvP section. It reads only the clan API
-- (init.lua): a button shows when its can_* allows it, and the action asks
-- the rule again at the click.
--
-- Real coordinates, in an 8.6 x 7.05 card at the caller's container (fix
-- round 1): the heading and the "Clan invitations" switch; with a clan two
-- tabs, "Online (n)" (the default) and "Offline (n)", pages of PAGE_ROWS
-- members with "‹ p / P ›", and the buttons for the selected row; without
-- one the pending clan invitations. The rows are grug_parties.row_list's
-- (the Online Players style); a click on a row selects it. Only the shown
-- page is in the formspec. Tab, page and selection live in the sfinv context
-- (session only); a tab or page change clears the selection, and so does a
-- refresh that moves the selected member off the shown page. The line under
-- the list shows the last button's notice until the next selection, tab or
-- page change, else a hint for the selection (fix round 2).
--
-- Refresh: through the Social tab's limiter. A change that can move a Clan
-- button or a clan mark in any list (membership, role, presence, the
-- switch) asks every viewer; the others only the players named.

local CARD_W, CARD_H = 8.6, 7.05
local LIST_X, LIST_Y, LIST_W = 0.2, 1.7, 7.85
local PAGE_ROWS = 7
-- Without a clan: the invitations' list, scrolling (ten at most).
local INVITES_Y, INVITES_ROWS, INVITES_SCROLL = 1.05, 8, "grug_clan_inv_scroll"
local TABS_Y, NOTICE_Y, BUTTONS_Y = 0.7, 6.05, 6.3
local INVITE_PREFIX = "grug_social_clan_"
local PICK_PREFIX, INVITER_PREFIX = "grug_clan_pick_", "grug_clan_ipick_"
local ROLE_NAMES = {leader = "Leader", captain = "Captain", member = "Member"}
local ROLE_ORDER = {leader = 1, captain = 2, member = 3}
local ROLE_COLORS = {leader = "#d4b77d", captain = grug_clans.COLOR}
local ONLINE_COLOR = "#b4dca4"
local EVERYONE = {membership = true, role = true, presence = true, preferences = true}
grug_parties.kept_scrolls[INVITES_SCROLL] = true

local function esc(value) return core.formspec_escape(tostring(value or "")) end
local function notice(context, ok, message)
	context.grug_clan_notice = (ok and "Success: " or "Refused: ") .. (message or "")
end
local function race_of(name)
	local player = core.get_player_by_name(name)
	return player and grug_classes.get_race(player) or nil
end

-- "5 min ago", "3 h ago", "2 d ago" since a stored os.time(); "Offline"
-- without one.
local function age(last_online, now)
	if type(last_online) ~= "number" then return "Offline" end
	local seconds = math.max(0, (now or os.time()) - last_online)
	if seconds < 3600 then return ("%d min ago"):format(math.max(1, math.floor(seconds / 60))) end
	if seconds < 86400 then return ("%d h ago"):format(math.floor(seconds / 3600)) end
	return ("%d d ago"):format(math.floor(seconds / 86400))
end

-- The card's order: online members first (leader, captains, members, each
-- by name), then offline ones by most recent logout, then by name.
local function ordered(members)
	local rows = {}
	for index, member in ipairs(members) do rows[index] = member end
	table.sort(rows, function(a, b)
		if a.online ~= b.online then return a.online end
		if a.online then
			local ra, rb = ROLE_ORDER[a.role] or 4, ROLE_ORDER[b.role] or 4
			if ra ~= rb then return ra < rb end
		else
			local ta, tb = a.last_online or 0, b.last_online or 0
			if ta ~= tb then return ta > tb end
		end
		local ka, kb = a.name:lower(), b.name:lower()
		if ka ~= kb then return ka < kb end
		return a.name < b.name
	end)
	return rows
end

-- The rows of the tab (online or offline, in the card's order), the page
-- (clamped) and the page count.
local function tab_rows(view, tab, page)
	local rows = {}
	for _, row in ipairs(ordered(view.members)) do
		if row.online == (tab == "online") then rows[#rows + 1] = row end
	end
	local pages = math.max(1, math.ceil(#rows / PAGE_ROWS))
	page = math.max(1, math.min(pages, math.floor(tonumber(page) or 1)))
	return rows, page, pages
end
local function counts(view)
	local online = 0
	for _, row in ipairs(view.members) do
		if row.online then online = online + 1 end
	end
	return online, #view.members - online
end

-- A tab: the shown one as the selected plate, the other flat and muted.
local function tab_button(fs, x, field, label, on, scale)
	if on then
		fs[#fs + 1] = grug_core.ui.button_style(field, "selected", scale)
	else
		fs[#fs + 1] = ("box[%.2f,%.2f;1.9,0.55;#ffffff0a]"):format(x, TABS_Y)
		fs[#fs + 1] = ("style[%s;border=false;bgimg=grug_ui_clear.png;bgimg_middle=6;" ..
			"textcolor=%s]"):format(field, grug_core.ui.colors.muted)
	end
	fs[#fs + 1] = ("button[%.2f,%.2f;1.9,0.55;%s;%s]"):format(x, TABS_Y, field, esc(label))
end
-- A page arrow; at the end of the pages it is drawn inactive (a click there
-- changes nothing).
local function arrow(fs, x, field, label, active)
	if not active then
		fs[#fs + 1] = ("box[%.2f,%.2f;0.55,0.55;#ffffff0a]"):format(x, TABS_Y)
		fs[#fs + 1] = ("style[%s;border=false;bgimg=grug_ui_clear.png;textcolor=#a9aea459]"):format(field)
	end
	fs[#fs + 1] = ("button[%.2f,%.2f;0.55,0.55;%s;%s]"):format(x, TABS_Y, field, label)
end

local function members_card(fs, player, context, view, scale)
	local own = player:get_player_name()
	local tab = context.grug_clan_tab == "offline" and "offline" or "online"
	local rows, page, pages = tab_rows(view, tab, context.grug_clan_page)
	context.grug_clan_tab, context.grug_clan_page = tab, page
	local first = (page - 1) * PAGE_ROWS
	local shown = {}
	for index = first + 1, math.min(#rows, first + PAGE_ROWS) do shown[#shown + 1] = rows[index] end
	-- The selection holds only while its member is on the shown page.
	local selected
	for _, row in ipairs(shown) do
		if row.name == context.grug_clan_member then selected = row.name end
	end
	context.grug_clan_member = selected
	local online, offline = counts(view)
	fs[#fs + 1] = grug_core.ui.heading(0.3, 0.32, ("Clan (%d/%d)")
		:format(#view.members, grug_clans.MAX_MEMBERS), scale)
	tab_button(fs, 0.2, "grug_clan_tab_online", ("Online (%d)"):format(online), tab == "online", scale)
	tab_button(fs, 2.2, "grug_clan_tab_offline", ("Offline (%d)"):format(offline), tab == "offline", scale)
	arrow(fs, 6.05, "grug_clan_prev", "‹", page > 1)
	fs[#fs + 1] = ("label[6.72,%.2f;%d / %d]"):format(TABS_Y + 0.28, page, pages)
	arrow(fs, 7.65, "grug_clan_next", "›", page < pages)
	grug_parties.column_heads(fs, LIST_X, LIST_Y - 0.17,
		{"NAME", "ROLE", "LEVEL", tab == "online" and "STATUS" or "LAST ONLINE"}, scale)
	local now = os.time()
	grug_parties.row_list(fs, context, {x = LIST_X, y = LIST_Y, w = LIST_W, visible = PAGE_ROWS,
		rows = shown, own = own, selected = selected, pick = PICK_PREFIX,
		draw = function(body, row, y)
			grug_parties.member_cells(body, {class = row.class,
				race = row.online and race_of(row.name) or nil,
				label = row.name, role = ROLE_NAMES[row.role], role_color = ROLE_COLORS[row.role], level = row.level,
				last = row.online and "Online" or age(row.last_online, now),
				last_color = row.online and ONLINE_COLOR or nil, muted = not row.online}, y)
		end})
	fs[#fs + 1] = ("button[0.20,%.2f;1.7,0.55;grug_clan_leave;Leave]"):format(BUTTONS_Y)
	-- The line under the list (fix round 2, the mockup's hints): a notice
	-- from a button press while it is shown, else what the selection allows.
	if not context.grug_clan_notice then
		local hint
		local own_role, target_role = grug_clans.role_of(own), nil
		for _, row in ipairs(shown) do
			if row.name == selected then target_role = row.role end
		end
		if not selected then hint = "Click a member to select them."
		elseif selected == own then hint = "Selected: you."
		elseif own_role == "member" then hint = "Members can only leave."
		elseif own_role == "captain" and target_role ~= "member" then
			hint = "Captains cannot act on the leader or other captains."
		else hint = ("Selected: %s."):format(selected) end
		fs[#fs + 1] = ("label[0.25,%.2f;%s]"):format(NOTICE_Y,
			esc(core.colorize(grug_core.ui.colors.muted, hint)))
	end
	if not selected or selected == own then return end
	if grug_clans.can_promote(own, selected) then
		fs[#fs + 1] = ("button[2.10,%.2f;2.0,0.55;grug_clan_promote;Make captain]"):format(BUTTONS_Y)
	elseif grug_clans.can_demote(own, selected) then
		fs[#fs + 1] = ("button[2.10,%.2f;2.0,0.55;grug_clan_demote;Make member]"):format(BUTTONS_Y)
	end
	if grug_clans.can_transfer(own, selected) then
		fs[#fs + 1] = ("button[4.30,%.2f;2.1,0.55;grug_clan_transfer;Make leader]"):format(BUTTONS_Y)
	end
	if grug_clans.can_kick(own, selected) then
		fs[#fs + 1] = ("button[6.60,%.2f;1.7,0.55;grug_clan_kick;Kick]"):format(BUTTONS_Y)
	end
end

local function invitations_card(fs, player, context, scale)
	local pending = grug_clans.pending(player)
	fs[#fs + 1] = grug_core.ui.heading(0.3, 0.32, ("%d Pending Clan Invitation%s")
		:format(#pending, #pending == 1 and "" or "s"), scale)
	if #pending == 0 then
		context.grug_clan_inviter = nil
		fs[#fs + 1] = grug_core.ui.prose(0.25, 0.75, 8.1, 1.5,
			"You are not in a clan.\nInvite a player of your faction with the Clan " ..
			"button in the Online Players list.", true, scale)
		return
	end
	local selected
	for _, row in ipairs(pending) do
		if row.inviter == context.grug_clan_inviter then selected = row.inviter end
	end
	selected = selected or pending[1].inviter
	context.grug_clan_inviter = selected
	local rows = {}
	for index, row in ipairs(pending) do
		local inviter = core.get_player_by_name(row.inviter)
		rows[index] = {name = row.inviter,
			class = inviter and grug_classes.get_class(inviter) or nil,
			race = inviter and grug_classes.get_race(inviter) or nil,
			size = row.clan_size > 0 and ("%d/%d"):format(row.clan_size, grug_clans.MAX_MEMBERS)
				or "new clan",
			level = row.level, seconds = row.expires_in}
	end
	grug_parties.column_heads(fs, LIST_X, INVITES_Y - 0.17,
		{"INVITED BY", "CLAN", "LEVEL", "EXPIRES"}, scale)
	grug_parties.row_list(fs, context, {x = LIST_X, y = INVITES_Y, w = LIST_W,
		visible = INVITES_ROWS, field = INVITES_SCROLL, rows = rows, selected = selected,
		pick = INVITER_PREFIX,
		draw = function(body, row, y)
			grug_parties.member_cells(body, {class = row.class, race = row.race, label = row.name,
				role = row.size, level = row.level, last = ("%d s"):format(row.seconds)}, y)
		end})
	fs[#fs + 1] = grug_core.ui.button_style("grug_clan_accept", "confirm", scale)
	fs[#fs + 1] = ("button[0.20,%.2f;1.7,0.55;grug_clan_accept;Accept]"):format(BUTTONS_Y)
	fs[#fs + 1] = ("button[2.10,%.2f;1.7,0.55;grug_clan_decline;Decline]"):format(BUTTONS_Y)
end

local function card(player, context)
	local scale = grug_core.ui.text_scale(player)
	local fs = {grug_core.ui.fonts(scale), grug_core.ui.panel(0, 0, CARD_W, CARD_H),
		grug_core.ui.button_style("grug_clan_leave", "danger", scale),
		grug_core.ui.button_style("grug_clan_kick", "danger", scale),
		("checkbox[5.55,0.32;grug_clan_invites;Clan invitations;%s]")
			:format(grug_clans.invitations_enabled(player) and "true" or "false"),
		"tooltip[grug_clan_invites;Allow clan invitations from other players.]"}
	local view = grug_clans.view(player)
	if view then
		members_card(fs, player, context, view, scale)
	else
		invitations_card(fs, player, context, scale)
	end
	if context.grug_clan_notice then
		fs[#fs + 1] = ("style_type[label;font_size=*%.3f]label[0.25,%.2f;%s]style_type[label;font_size=*%.3f]")
			:format(0.9 * scale, NOTICE_Y, esc(context.grug_clan_notice), scale)
	end
	return table.concat(fs)
end

-- A tab or page change: the new page (clamped at build) and no selection;
-- an inactive arrow changes nothing.
local function turn(player, context, tab, step)
	local view = grug_clans.view(player)
	if not view then return end
	local old_tab, old_page = context.grug_clan_tab or "online", context.grug_clan_page or 1
	local _, page = tab_rows(view, tab, step == 0 and 1 or old_page + step)
	if tab ~= old_tab or page ~= old_page then context.grug_clan_member = nil end
	-- A new view of the list: the hint line again.
	context.grug_clan_notice = nil
	context.grug_clan_tab, context.grug_clan_page = tab, page
end

-- True when the fields were the clan's (the caller re-sends the page).
local function on_fields(player, context, fields)
	local invite_target, pick, inviter_pick
	for field in pairs(fields) do
		invite_target = invite_target or field:match("^" .. INVITE_PREFIX .. "(.+)$")
		pick = pick or field:match("^" .. PICK_PREFIX .. "(.+)$")
		inviter_pick = inviter_pick or field:match("^" .. INVITER_PREFIX .. "(.+)$")
	end
	local member, inviter = context.grug_clan_member, context.grug_clan_inviter
	local tab = context.grug_clan_tab == "offline" and "offline" or "online"
	local ok, message
	if invite_target then
		ok, message = grug_clans.invite(player, invite_target)
	elseif pick then
		-- A new selection: its hint replaces the last notice.
		context.grug_clan_member, context.grug_clan_notice = pick, nil
	elseif inviter_pick then
		context.grug_clan_inviter = inviter_pick
	elseif fields.grug_clan_tab_online then turn(player, context, "online", 0)
	elseif fields.grug_clan_tab_offline then turn(player, context, "offline", 0)
	elseif fields.grug_clan_prev then turn(player, context, tab, -1)
	elseif fields.grug_clan_next then turn(player, context, tab, 1)
	elseif fields.grug_clan_accept and inviter then ok, message = grug_clans.accept(player, inviter)
	elseif fields.grug_clan_decline and inviter then ok, message = grug_clans.decline(player, inviter)
	elseif fields.grug_clan_leave then ok, message = grug_clans.leave(player)
	elseif fields.grug_clan_kick and member then ok, message = grug_clans.kick(player, member)
	elseif fields.grug_clan_promote and member then ok, message = grug_clans.promote(player, member)
	elseif fields.grug_clan_demote and member then ok, message = grug_clans.demote(player, member)
	elseif fields.grug_clan_transfer and member then ok, message = grug_clans.transfer_leader(player, member)
	elseif fields.grug_clan_invites then
		local enabled = fields.grug_clan_invites == "true"
		if enabled ~= grug_clans.invitations_enabled(player) then
			ok, message = grug_clans.set_invitations_enabled(player, enabled)
		end
	else
		return false
	end
	if ok ~= nil then notice(context, ok, message) end
	return true
end

grug_parties.clan_section = {
	get = card,
	on_fields = on_fields,
	-- The Online Players rows: the mark for a clan mate and the Clan button.
	MARK = "grug_clans_mark.png",
	INVITE_PREFIX = INVITE_PREFIX,
	mate = function(viewer, name) return grug_clans.same_clan(viewer, name) end,
	can_invite = function(viewer, name) return grug_clans.can_invite(viewer, name) end,
	-- For tools/r76_social.
	age = age,
	ordered = ordered,
	PAGE_ROWS = PAGE_ROWS,
}

grug_clans.register_on_change(function(names, reason)
	if EVERYONE[reason] then
		grug_parties.social_resend_all()
		return
	end
	for name in pairs(names) do
		local player = core.get_player_by_name(name)
		if player then grug_parties.social_resend(player) end
	end
end)
