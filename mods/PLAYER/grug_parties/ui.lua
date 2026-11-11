-- The Social tab (Round 67 lane SOCIAL, rulings 1-8; the Party & PvP tab of
-- Round 44 lane PP before it; four cards since Round 76, rulings 7 and 8).
-- Left: the invitation and HUD settings, one party box (the current party,
-- or without one the pending invitations; a party member holds none) and
-- the clan card below it (grug_clans/social.lua installs it as
-- grug_parties.clan_section: grug_clans depends on this mod, so this file
-- never names grug_clans). Right: every online player of both factions, one
-- compact row each, with a favourite star, the clan mark and the Party and
-- Clan buttons, and the PvP section below it (grug_pvp/page.lua installs it
-- as grug_parties.pvp_section). The party, clan and player lists share one
-- row style (fix round 1, grug_parties.row_list). No inventory view: the
-- page has the whole window. Real coordinates.
--
-- Refresh (ruling 8 and its default): a change of the player list
-- (grug_parties.register_on_roster_change), of the viewer's own
-- invitations or of a clan (grug_parties.social_resend_all, Round 76)
-- re-sends the page, only to players whose current page this is, at most
-- once per SEND_GAP_US: changes in one server step make one
-- send, a change inside the gap is owed and goes out when it ends; the PvP
-- section's countdown too. Every build counts as a send (the player's own
-- clicks re-send at once). A scrollbar move holds every send for QUIET_US
-- (the map window's rule): a form rebuilt while the player drags the
-- scrollbar would break the drag. The client does not keep the scroll
-- position across a resend but sends it with every event, so it is kept
-- in the sfinv context and echoed (grug_inventory/ui.lua keep_scroll), for
-- each scrollbar in grug_parties.kept_scrolls.

local PAGE = "grug_parties:group"
grug_parties.PAGE = PAGE
local FAVORITES_KEY = "grug_parties:favorites"
grug_parties.FAVORITES_KEY = FAVORITES_KEY
grug_parties.SEND_GAP_US, grug_parties.QUIET_US = 2000000, 500000

-- The page body is 20 x 13.5 (grug_inventory UI.frame_w, frame_h). Four
-- cards (Round 76, fix round 1): party and clan on the left (8.6 wide), the
-- online players and PvP on the right (10.8 wide); the clan and PvP cards
-- draw their own panels at the container origin (clan 8.6 x 7.05, PvP 10.8
-- x 6.35).
local LEFT_X, LEFT_W = 0.2, 8.6
local BOX_Y, BOX_H = 0.85, 5.25
local CLAN_Y = 6.3
local LIST_X, LIST_Y, LIST_W, LIST_H = 9.0, 0.1, 10.8, 6.7
local PVP_Y = 7.0
-- The rows' scroll area inside the list card and its scrollbar right of it.
local VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 9.2, 0.85, 10.05, 5.8
-- The party's rows: six visible, scrolling from seven members.
local PARTY_X, PARTY_Y, PARTY_W, PARTY_ROWS = 0.4, 1.75, 7.85, 6
local BUTTONS_Y = 5.4
local ROW_H, ROW_PITCH = 0.54, 0.6
-- Real units per scrollbar unit: a row is six units.
local SCROLL_FACTOR = 0.1
local SCROLL_FIELD, PARTY_SCROLL = "grug_social_scroll", "grug_party_scroll"
local INVITES_SCROLL = "grug_party_inv_scroll"
-- The scrollbars whose position the page keeps across a resend, by field
-- (also the context key); the clan section adds its own.
grug_parties.kept_scrolls = {[SCROLL_FIELD] = true, [PARTY_SCROLL] = true, [INVITES_SCROLL] = true}
local SCROLLBAR_DEFAULTS = "scrollbaroptions[min=0;max=1000;smallstep=10;" ..
	"largestep=100;thumbsize=1;arrows=default]"
local FOCUS_FIELD = "grug_social_focus"
local INVITE_PREFIX, STAR_PREFIX = "grug_social_inv_", "grug_social_fav_"
local PICK_PREFIX, INVITER_PREFIX = "grug_party_pick_", "grug_party_ipick_"
-- Stands in for grug_parties.clan_section without grug_clans: no clan
-- mark, no Clan button, no clan card.
local NO_CLAN = {}
local STAR_ON, STAR_OFF = "#f0c419", "#9a9a9a"
local FACTION_ICONS = {accord = "grug_inventory_faction_accord.png",
	throng = "grug_inventory_faction_throng.png"}
-- Row tints: alternate rows, the own row, the selected row and its frame.
local ROW_ALT, ROW_OWN, ROW_SELECTED, ROW_FRAME = "#ffffff0b", "#bba06230", "#bba0626b", "#d4b77db3"
-- Party and clan columns (Round 76 fix rounds 1 and 2): class, race, name,
-- role, level and the last column ("Online", "Offline" or an age).
local COLUMNS = {class = 0.1, race = 0.55, name = 1.05, role = 3.85, level = 5.05, last = 5.95}
grug_parties.COLUMNS = COLUMNS
-- The status column's "Online" (the clan list's green).
local ONLINE_COLOR = "#b4dca4"
grug_parties.ONLINE_COLOR = ONLINE_COLOR

local function esc(value) return core.formspec_escape(tostring(value or "")) end
local function health_color_mode(player)
	return grug_parties.health_color_mode and
		grug_parties.health_color_mode(player) or "by_class"
end
local function notice(context, ok, message)
	context.grug_party_notice = (ok and "Success: " or "Refused: ") .. (message or "")
end

--
-- Favourites (ruling 6): player names in player meta FAVORITES_KEY as one
-- core.serialize'd sorted list ("" for none), like the recipe favourites.
-- Read at each build (a send at most every SEND_GAP_US), so no session cache.
--

local function favorites_of(player)
	local set = {}
	local text = player:get_meta():get_string(FAVORITES_KEY)
	local list = text ~= "" and core.deserialize(text) or nil
	for _, name in ipairs(type(list) == "table" and list or {}) do
		if type(name) == "string" then set[name] = true end
	end
	return set
end

function grug_parties.is_favorite(player, name)
	return favorites_of(player)[name] == true
end

-- Marks `name` a favourite or removes the mark; returns whether it is one
-- now. Only an online player becomes one (the star is on their row).
function grug_parties.toggle_favorite(player, name)
	local set = favorites_of(player)
	if type(name) ~= "string" or name == player:get_player_name() or
			(not set[name] and not grug_parties.is_online(name)) then
		return set[name] == true
	end
	set[name] = not set[name] or nil
	local list = {}
	for id in pairs(set) do list[#list + 1] = id end
	table.sort(list)
	player:get_meta():set_string(FAVORITES_KEY, #list > 0 and core.serialize(list) or "")
	return set[name] == true
end

--
-- The player list: one shared roster of the online players, rebuilt at the
-- first build after a roster change; each viewer sorts it and adds the
-- favourites and the invite buttons.
--

local roster
local function build_roster()
	local rows = {}
	for _, target in ipairs(core.get_connected_players()) do
		local name = target:get_player_name()
		if grug_parties.is_online(name) then
			local class, race = grug_classes.get_class(target), grug_classes.get_race(target)
			local class_def = class and grug_classes.registered_classes[class]
			local race_def = race and grug_classes.registered_races[race]
			rows[#rows + 1] = {name = name, key = name:lower(),
				faction = grug_factions.get_faction(target),
				class = class, class_name = class_def and class_def.name,
				race = race, race_name = race_def and race_def.name,
				level = grug_xp.get_level(target)}
		end
	end
	return rows
end

-- The viewer's order (ruling 5): its own faction, then the other one, then
-- players who have not chosen a faction yet; inside each, favourites first,
-- then by name (case-insensitive), favourites by name too.
local function sorted_rows(own_faction, favorites)
	roster = roster or build_roster()
	local rows = {}
	for index, row in ipairs(roster) do rows[index] = row end
	local function group(row)
		if not row.faction then return 3 end
		return row.faction == own_faction and 1 or 2
	end
	table.sort(rows, function(a, b)
		local ga, gb = group(a), group(b)
		if ga ~= gb then return ga < gb end
		local fa, fb = favorites[a.name] and 0 or 1, favorites[b.name] and 0 or 1
		if fa ~= fb then return fa < fb end
		if a.key ~= b.key then return a.key < b.key end
		return a.name < b.name
	end)
	return rows
end

local function icon(fs, x, y, texture, tip)
	if not texture or texture == "" then return end
	fs[#fs + 1] = ("image[%.2f,%.2f;0.42,0.42;%s]"):format(x, y + 0.06, esc(texture))
	if tip then
		fs[#fs + 1] = ("tooltip[%.2f,%.2f;0.42,0.42;%s]"):format(x, y + 0.06, esc(tip))
	end
end

--
-- The row lists (Round 76 fix round 1): Online Players, the party and the
-- clan share one row style. Exported for grug_clans/social.lua.
--

-- One list at list.x, list.y, list.w, list.visible rows high. With
-- list.field the area scrolls (a scrollbar right of it once the rows
-- overflow; the position kept in context[list.field], see kept_scrolls),
-- else it is a plain container holding only the rows given. Each row gets
-- its background (alternate rows faint, the own row tinted, the selected
-- row tinted stronger with a frame), then list.draw(body, row, y), then for
-- list.pick an invisible button over the whole row named list.pick ..
-- name: a click anywhere on the row selects it (the visible elements take
-- no clicks, so the button lies on top). list.prelude(fs) goes before the
-- rows (styles for their buttons).
function grug_parties.row_list(fs, context, list)
	local body = {}
	for index, row in ipairs(list.rows) do
		local y = (index - 1) * ROW_PITCH
		if row.name == list.selected then
			body[#body + 1] = ("box[0,%.2f;%.2f,%.2f;%s]"):format(y, list.w, ROW_H, ROW_SELECTED)
			body[#body + 1] = ("box[0,%.2f;%.2f,0.03;%s]box[0,%.2f;%.2f,0.03;%s]"):format(
				y, list.w, ROW_FRAME, y + ROW_H - 0.03, list.w, ROW_FRAME)
			body[#body + 1] = ("box[0,%.2f;0.03,%.2f;%s]box[%.2f,%.2f;0.03,%.2f;%s]"):format(
				y, ROW_H, ROW_FRAME, list.w - 0.03, y, ROW_H, ROW_FRAME)
		elseif row.name == list.own then
			body[#body + 1] = ("box[0,%.2f;%.2f,%.2f;%s]"):format(y, list.w, ROW_H, ROW_OWN)
		elseif index % 2 == 0 then
			body[#body + 1] = ("box[0,%.2f;%.2f,%.2f;%s]"):format(y, list.w, ROW_H, ROW_ALT)
		end
		list.draw(body, row, y, index)
		if list.pick then
			body[#body + 1] = ("image_button[0,%.2f;%.2f,%.2f;blank.png;%s%s;;false;false]"):format(
				y, list.w, ROW_H, list.pick, row.name)
		end
	end
	local view_h = list.visible * ROW_PITCH
	if list.field then
		local content_h = #list.rows * ROW_PITCH
		local max = math.max(0, math.ceil((content_h - view_h) / SCROLL_FACTOR - 1e-9))
		local value = math.max(0, math.min(max, math.floor(context[list.field] or 0)))
		context[list.field] = value
		if max > 0 then
			-- The thumb shows the visible share (grug_skills/page.lua).
			local thumb = math.max(1, math.floor(view_h / content_h * (max + 1) + 0.5))
			local step = ROW_PITCH / SCROLL_FACTOR
			fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;" ..
				"thumbsize=%d;arrows=default]"):format(max, step, math.floor(view_h / SCROLL_FACTOR), thumb)
			fs[#fs + 1] = ("scrollbar[%.2f,%.2f;0.3,%.2f;vertical;%s;%d]"):format(
				list.x + list.w + 0.1, list.y, view_h, list.field, value)
			fs[#fs + 1] = SCROLLBAR_DEFAULTS
		end
		if list.prelude then list.prelude(fs) end
		fs[#fs + 1] = ("scroll_container[%.2f,%.2f;%.2f,%.2f;%s;vertical;%.2f]"):format(
			list.x, list.y, list.w, view_h, list.field, SCROLL_FACTOR)
		fs[#fs + 1] = table.concat(body)
		fs[#fs + 1] = "scroll_container_end[]"
	else
		if list.prelude then list.prelude(fs) end
		fs[#fs + 1] = ("container[%.2f,%.2f]"):format(list.x, list.y)
		fs[#fs + 1] = table.concat(body)
		fs[#fs + 1] = "container_end[]"
	end
end

-- Small muted column heads above a party or clan list at x (the list's x)
-- and y: heads = {name, role, level, last}.
function grug_parties.column_heads(fs, x, y, heads, scale)
	fs[#fs + 1] = ("style_type[label;font_size=*%.3f]"):format(0.8 * scale)
	for index, key in ipairs({"name", "role", "level", "last"}) do
		if heads[index] then
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + COLUMNS[key], y,
				esc(core.colorize(grug_core.ui.colors.muted, heads[index])))
		end
	end
	fs[#fs + 1] = ("style_type[label;font_size=*%.3f]"):format(scale)
end

-- The cells of a party or clan row at y: row.class and row.race (icons),
-- row.label (the name; the own row is tinted, no "(you)"), row.role and
-- row.role_color, row.level, and the last column row.last and
-- row.last_color. row.muted greys an offline row.
function grug_parties.member_cells(fs, row, y)
	local muted = grug_core.ui.colors.muted
	local function text(x, value, color)
		if not value or value == "" then return end
		color = row.muted and muted or color
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x, y + ROW_H / 2,
			esc(color and core.colorize(color, value) or value))
	end
	icon(fs, COLUMNS.class, y, row.class and grug_core.status_icons.class_icon(row.class))
	icon(fs, COLUMNS.race, y, row.race and grug_core.status_icons.race_icon(row.race))
	text(COLUMNS.name, row.label)
	text(COLUMNS.role, row.role, row.role_color)
	if row.level then text(COLUMNS.level, "Lv " .. row.level) end
	text(COLUMNS.last, row.last, row.last_color)
end

-- One Online Players row at `y`: faction, the clan mark for a clan mate,
-- name, class, race and level left (icons with the word as tooltip), star
-- and the Party and Clan buttons right (Round 76 ruling 8), each only when
-- its API allows it.
local function list_row(fs, row, y, own, stars, clan)
	icon(fs, 0.1, y, FACTION_ICONS[row.faction],
		row.faction and grug_factions.display_name(row.faction))
	if row.mate then icon(fs, 0.55, y, clan.MARK, "Your clan") end
	fs[#fs + 1] = ("label[1.0,%.2f;%s]"):format(y + ROW_H / 2,
		esc(own and row.name .. " (you)" or row.name))
	icon(fs, 5.1, y, grug_core.status_icons.class_icon(row.class), row.class_name)
	icon(fs, 5.55, y, grug_core.status_icons.race_icon(row.race), row.race_name)
	fs[#fs + 1] = ("label[6.05,%.2f;Lv %d]"):format(y + ROW_H / 2, row.level or 1)
	if own then return end
	local star = STAR_PREFIX .. row.name
	local same = row.favorite and stars.on or stars.off
	same[#same + 1] = star
	fs[#fs + 1] = ("button[6.95,%.2f;0.5,0.5;%s;%s]tooltip[%s;%s]"):format(y + 0.02, star,
		row.favorite and "★" or "☆", star,
		row.favorite and "Remove from favorites" or "Add to favorites")
	if row.invite then
		fs[#fs + 1] = ("button[7.6,%.2f;1.1,0.5;%s%s;Party]tooltip[%s%s;Invite to your party]")
			:format(y + 0.02, INVITE_PREFIX, row.name, INVITE_PREFIX, row.name)
	end
	if row.clan_invite then
		fs[#fs + 1] = ("button[8.8,%.2f;1.1,0.5;%s%s;Clan]tooltip[%s%s;Invite to your clan]")
			:format(y + 0.02, clan.INVITE_PREFIX, row.name, clan.INVITE_PREFIX, row.name)
	end
end

local function online_list(fs, player, context, scale)
	local own = player:get_player_name()
	local own_faction = grug_factions.get_faction(player)
	local favorites = favorites_of(player)
	local rows = sorted_rows(own_faction, favorites)
	local clan = grug_parties.clan_section or NO_CLAN
	fs[#fs + 1] = grug_core.ui.heading(LIST_X + 0.3, LIST_Y + 0.35,
		("Online Players (%d)"):format(#rows), scale)
	-- The party's notice (Round 76 fix round 1): the party card has no free
	-- line, and most notices answer this list's Party button.
	if context.grug_party_notice then
		fs[#fs + 1] = ("style_type[label;font_size=*%.3f]label[%.2f,%.2f;%s]style_type[label;font_size=*%.3f]")
			:format(0.85 * scale, LIST_X + 3.2, LIST_Y + 0.35, esc(context.grug_party_notice), scale)
	end
	local stars = {on = {}, off = {}}
	local shown = {}
	for index, row in ipairs(rows) do
		local is_own = row.name == own
		shown[index] = {name = row.name, faction = row.faction, class = row.class,
			class_name = row.class_name, race = row.race, race_name = row.race_name,
			level = row.level, favorite = favorites[row.name], own = is_own,
			-- Enemy rows never have the button (eligible refuses them).
			invite = not is_own and row.faction ~= nil and row.faction == own_faction and
				grug_parties.can_invite(own, row.name),
			mate = not is_own and clan.mate ~= nil and clan.mate(own, row.name),
			clan_invite = not is_own and clan.can_invite ~= nil and clan.can_invite(own, row.name)}
	end
	grug_parties.row_list(fs, context, {x = VIEW_X, y = VIEW_Y, w = VIEW_W,
		visible = VIEW_H / ROW_PITCH, field = SCROLL_FIELD, rows = shown, own = own,
		draw = function(body, row, y) list_row(body, row, y, row.own, stars, clan) end,
		-- One style per star colour, before the buttons it names.
		prelude = function(out)
			local font = grug_core.ui.font_size(1.3, grug_core.ui.text_growth(player))
			for _, kind in ipairs({"on", "off"}) do
				if #stars[kind] > 0 then
					out[#out + 1] = ("style[%s;textcolor=%s;font_size=%s]"):format(
						table.concat(stars[kind], ","), kind == "on" and STAR_ON or STAR_OFF, font)
				end
			end
		end})
end

--
-- The party box (ruling 4): one card, the current party or the pending
-- invitations.
--

local function selected_member(view, context)
	for _, row in ipairs(view.members) do
		if row.name == context.grug_party_member then return row end
	end
	context.grug_party_member = view.members[1] and view.members[1].name or nil
	return view.members[1]
end

-- The one line under an invitation while the player owns an Expedition alone
-- (Round 71, concept section 4): accepting a foreign party ends it for good, and
-- since Round 72.1 gives the Deserter's Mark unless it was finished; nil
-- otherwise. grug_expeditions depends on this mod, so it is read at call time.
function grug_parties.invitation_warning(name)
	local expeditions = rawget(_G, "grug_expeditions")
	local run = expeditions and expeditions.run_of(name)
	if run and run.owner.kind == "player" then
		-- Round 72.1: the rule of runs.lua's joined-party end.
		if run.closing or expeditions.rewards_open(run) then
			return "Accepting ends your Expedition."
		end
		return "Accepting ends your Expedition and gives you the Deserter's Mark."
	end
	return nil
end

-- "0 Pending Invitations", "1 Pending Invitation", "2 Pending Invitations".
function grug_parties.pending_heading(count)
	return ("%d Pending Invitation%s"):format(count, count == 1 and "" or "s")
end

local function party_members(fs, player, context, view, scale)
	fs[#fs + 1] = grug_core.ui.heading(0.5, BOX_Y + 0.35,
		("Current Party (%d/10)"):format(#view.members), scale)
	-- Fix round 2: a status column, as the clan's (live HP is the Party
	-- HUD's; this page is not re-sent on HP changes).
	grug_parties.column_heads(fs, PARTY_X, PARTY_Y - 0.17, {"NAME", "ROLE", "LEVEL", "STATUS"}, scale)
	local own_name = player:get_player_name()
	local selected = selected_member(view, context)
	grug_parties.row_list(fs, context, {x = PARTY_X, y = PARTY_Y, w = PARTY_W,
		visible = PARTY_ROWS, field = PARTY_SCROLL, rows = view.members, own = own_name,
		selected = selected.name, pick = PICK_PREFIX,
		draw = function(body, row, y)
			-- The race of an online member from its player (the party stores none).
			local target = row.online and core.get_player_by_name(row.name)
			grug_parties.member_cells(body, {class = row.class,
				race = target and grug_classes.get_race(target),
				label = row.name, role = row.name == view.leader and "Leader" or nil,
				role_color = grug_core.ui.colors.accent, level = row.level,
				last = row.online and "Online" or "Offline",
				last_color = row.online and ONLINE_COLOR or nil, muted = not row.online}, y)
		end})
	if view.leader == own_name and selected.name ~= own_name then
		fs[#fs + 1] = ("button[4.30,%.2f;2.3,0.55;grug_party_transfer;Make leader]"):format(BUTTONS_Y)
		fs[#fs + 1] = ("button[6.80,%.2f;1.7,0.55;grug_party_kick;Kick]"):format(BUTTONS_Y)
	end
	fs[#fs + 1] = ("button[0.40,%.2f;1.7,0.55;grug_party_leave;Leave]"):format(BUTTONS_Y)
end

local function party_invitations(fs, name, context, pending, scale)
	fs[#fs + 1] = grug_core.ui.heading(0.5, BOX_Y + 0.35,
		grug_parties.pending_heading(#pending), scale)
	if #pending == 0 then
		context.grug_party_inviter = nil
		fs[#fs + 1] = grug_core.ui.prose(0.5, BOX_Y + 0.75, 7.9, 1.5,
			"You are not in a party.\nInvite a player of your faction with the Party " ..
			"button in the Online Players list.", true, scale)
		return
	end
	-- Fix round 2: the clan invitations' rows (class, race, inviter, party
	-- size, level, seconds left); a click on a row selects it.
	local rows, selected = {}, nil
	for index, row in ipairs(pending) do
		local inviter = core.get_player_by_name(row.inviter)
		rows[index] = {name = row.inviter,
			class = inviter and grug_classes.get_class(inviter) or nil,
			race = inviter and grug_classes.get_race(inviter) or nil,
			size = ("%d/10"):format(row.party and #row.party.members or 1),
			level = row.level, seconds = row.expires_in}
		if row.inviter == context.grug_party_inviter then selected = row.inviter end
	end
	selected = selected or pending[1].inviter
	context.grug_party_inviter = selected
	grug_parties.column_heads(fs, PARTY_X, PARTY_Y - 0.17, {"INVITED BY", "PARTY", "LEVEL", "EXPIRES"}, scale)
	grug_parties.row_list(fs, context, {x = PARTY_X, y = PARTY_Y, w = PARTY_W,
		visible = PARTY_ROWS, field = INVITES_SCROLL, rows = rows, selected = selected,
		pick = INVITER_PREFIX,
		draw = function(body, row, y)
			grug_parties.member_cells(body, {class = row.class, race = row.race, label = row.name,
				role = row.size, level = row.level, last = ("%d s"):format(row.seconds)}, y)
		end})
	fs[#fs + 1] = ("button[0.40,%.2f;1.7,0.55;grug_party_accept;Accept]"):format(BUTTONS_Y)
	fs[#fs + 1] = ("button[2.30,%.2f;1.7,0.55;grug_party_decline;Decline]"):format(BUTTONS_Y)
	local warning = grug_parties.invitation_warning(name)
	if warning then
		fs[#fs + 1] = ("label[4.15,%.2f;%s]"):format(BUTTONS_Y + 0.275,
			esc(core.colorize(grug_core.ui.colors.accent, warning)))
	end
end

local function content(player, context)
	local view = grug_parties.view(player)
	local scale = grug_core.ui.text_scale(player)
	local fs = {
		"real_coordinates[true]", grug_core.ui.fonts(scale),
		grug_core.ui.panel(LEFT_X, BOX_Y, LEFT_W, BOX_H),
		grug_core.ui.panel(LIST_X, LIST_Y, LIST_W, LIST_H),
		grug_core.ui.button_style("grug_party_leave", "danger", scale),
		grug_core.ui.button_style("grug_party_kick", "danger", scale),
		-- An invisible button with no action takes the focus at every send
		-- (0.45.1, module guide "Initial focus"): otherwise the engine focuses
		-- a read-only textarea, a row or a Party button. Forced, so it also
		-- applies when the inventory key opens the window.
		"set_focus[grug_social_focus;true]button[0,0;0,0;grug_social_focus;]",
		("checkbox[0.4,0.35;grug_party_invites;Invitations;%s]")
			:format(grug_parties.invitations_enabled(player) and "true" or "false"),
		"tooltip[grug_party_invites;Allow invitations from other players.]",
		("checkbox[2.6,0.35;grug_party_hud;Party HUD;%s]")
			:format(grug_parties.hud_enabled(player) and "true" or "false"),
		"label[4.65,0.35;Health colors]",
		("dropdown[6.4,0.1;2.3,0.5;grug_party_health_colors;All green,By class;%d;true]")
			:format(health_color_mode(player) == "by_class" and 2 or 1),
	}
	if view then
		party_members(fs, player, context, view, scale)
	else
		party_invitations(fs, player:get_player_name(), context,
			grug_parties.pending(player), scale)
	end
	online_list(fs, player, context, scale)
	local clan = grug_parties.clan_section
	if clan then
		fs[#fs + 1] = ("container[%.2f,%.2f]"):format(LEFT_X, CLAN_Y)
		fs[#fs + 1] = clan.get(player, context)
		fs[#fs + 1] = "container_end[]"
	end
	local pvp = grug_parties.pvp_section
	if pvp then
		fs[#fs + 1] = ("container[%.2f,%.2f]"):format(LIST_X, PVP_Y)
		fs[#fs + 1] = pvp.get(player, context, 0)
		fs[#fs + 1] = "container_end[]"
	end
	return table.concat(fs)
end

--
-- Sends (ruling 8). The coalescing state lives in the sfinv context
-- (sfinv drops it at leave): `sent` (the last build, core.get_us_time),
-- `pending` (a send is owed), `quiet` (no send before this) and `timer`
-- (a core.after is waiting).
--

local function send_state(context)
	local state = context.grug_social_send
	if not state then
		state = {pending = false, quiet = 0, timer = false}
		context.grug_social_send = state
	end
	return state
end

local flush
local function schedule(name, context, delay_us)
	local state = send_state(context)
	if state.timer then return end
	state.timer = true
	core.after(delay_us / 1000000, flush, name, context)
end

-- The owed send of `name`, once the gap and a quiet hold have passed; a
-- player who left the page or the server is owed nothing.
function flush(name, context)
	local state = send_state(context)
	state.timer = false
	local player = core.get_player_by_name(name)
	if not state.pending or sfinv.contexts[name] ~= context or
			context.page ~= PAGE or not player then
		state.pending = false
		return
	end
	local now = core.get_us_time()
	local at = math.max(state.sent and state.sent + grug_parties.SEND_GAP_US or now,
		state.quiet or 0)
	if at > now then
		schedule(name, context, at - now)
		return
	end
	sfinv.set_player_inventory_formspec(player, context)
end

-- Something `name`'s open page shows changed: send it at the end of this
-- step, or when the gap or a quiet hold ends.
local function request(name)
	local context = sfinv.contexts[name]
	if not context or context.page ~= PAGE then return end
	send_state(context).pending = true
	schedule(name, context, 0)
end

-- The player list changed: every viewer whose last build is older than the
-- change is asked, once per server step.
local everyone_owed, roster_version = false, 0
local function request_everyone()
	for name, context in pairs(sfinv.contexts) do
		if context.page == PAGE and send_state(context).version ~= roster_version then
			request(name)
		end
	end
	everyone_owed = false
end
grug_parties.register_on_roster_change(function()
	roster, roster_version = nil, roster_version + 1
	if not everyone_owed then
		everyone_owed = true
		core.after(0, request_everyone)
	end
end)

-- For the PvP section (grug_pvp/page.lua): its countdown and state changes
-- go through the same limiter, so the countdown may step by 2 s.
function grug_parties.social_resend(player)
	request(player:get_player_name())
end

-- For the clan section (grug_clans/social.lua): a change that may move a
-- Clan button or mark in anyone's list asks every viewer, through the same
-- limiter.
function grug_parties.social_resend_all()
	for name, context in pairs(sfinv.contexts) do
		if context.page == PAGE then request(name) end
	end
end

-- Each kept scrollbar's value from every event of the inventory form (CHG
-- for its own move, VAL for any other); a scrollbar's own move holds the
-- sends for QUIET_US and ends there, without a resend. Chains sfinv's hook
-- (api.lua GRUG PATCH).
local previous_handle_scroll = sfinv.handle_scroll
function sfinv.handle_scroll(player, context, fields)
	local moved = false
	for field in pairs(grug_parties.kept_scrolls) do
		local raw = fields[field]
		local kind, value
		if type(raw) == "string" then kind, value = raw:match("^(%u+):(%-?%d+)$") end
		if kind == "CHG" or kind == "VAL" then
			context[field] = math.max(0, tonumber(value))
		end
		moved = moved or kind == "CHG"
	end
	local handled = previous_handle_scroll(player, context, fields)
	if moved and context.page == PAGE then
		send_state(context).quiet = core.get_us_time() + grug_parties.QUIET_US
		return true
	end
	return handled
end

sfinv.register_page(PAGE, {title = "Social", on_enter = function(_, _, context)
	for field in pairs(grug_parties.kept_scrolls) do context[field] = 0 end
end, get = function(_, player, context)
	local state = send_state(context)
	state.sent, state.pending, state.version = core.get_us_time(), false, roster_version
	return sfinv.make_formspec(player, context, content(player, context), false)
end, on_player_receive_fields = function(_, player, context, fields)
	if fields.quit then return true end
	local pvp = grug_parties.pvp_section
	if pvp and pvp.on_fields(player, context, fields) then return true end
	-- Space or Enter on the focus button: nothing to do.
	if fields[FOCUS_FIELD] then return true end
	-- The clan card's fields and the rows' Clan buttons (its notice).
	local clan = grug_parties.clan_section
	if clan and clan.on_fields(player, context, fields) then
		sfinv.set_player_inventory_formspec(player, context)
		return true
	end
	-- A row's buttons name their player, never a place in the list.
	local invite_target, star_target, pick_target, inviter_pick
	for field in pairs(fields) do
		invite_target = invite_target or field:match("^" .. INVITE_PREFIX .. "(.+)$")
		star_target = star_target or field:match("^" .. STAR_PREFIX .. "(.+)$")
		pick_target = pick_target or field:match("^" .. PICK_PREFIX .. "(.+)$")
		inviter_pick = inviter_pick or field:match("^" .. INVITER_PREFIX .. "(.+)$")
	end
	local ok, message
	if inviter_pick then
		-- A click on an invitation's row selects it (the box checks it).
		context.grug_party_inviter = inviter_pick
	elseif pick_target then
		-- A click on a member's row selects it (the party box checks it).
		context.grug_party_member = pick_target
	elseif invite_target then
		ok, message = grug_parties.invite(player, invite_target)
	elseif star_target then
		grug_parties.toggle_favorite(player, star_target)
	elseif fields.grug_party_accept and context.grug_party_inviter then ok, message = grug_parties.accept(player, context.grug_party_inviter)
	elseif fields.grug_party_decline and context.grug_party_inviter then ok, message = grug_parties.decline(player, context.grug_party_inviter)
	elseif fields.grug_party_leave then ok, message = grug_parties.leave(player)
	elseif fields.grug_party_kick and context.grug_party_member then ok, message = grug_parties.kick(player, context.grug_party_member)
	elseif fields.grug_party_transfer and context.grug_party_member then ok, message = grug_parties.transfer_leader(player, context.grug_party_member)
	elseif fields.grug_party_invites and
			(fields.grug_party_invites == "true") ~= grug_parties.invitations_enabled(player) then
		ok, message = grug_parties.set_invitations_enabled(player, fields.grug_party_invites == "true")
	elseif fields.grug_party_hud and
			(fields.grug_party_hud == "true") ~= grug_parties.hud_enabled(player) then
		ok, message = grug_parties.set_hud_enabled(player, fields.grug_party_hud == "true")
	elseif fields.grug_party_health_colors then
		-- The dropdown sends its value with every event: only a change counts.
		local modes = {all_green = "1", by_class = "2"}
		local mode = fields.grug_party_health_colors == modes.by_class
			and "by_class" or fields.grug_party_health_colors == modes.all_green
			and "all_green" or nil
		if mode ~= health_color_mode(player) then
			ok, message = grug_parties.set_health_color_mode(player, mode)
		end
	end
	if ok ~= nil then notice(context, ok, message) end
	sfinv.set_player_inventory_formspec(player, context)
	return true
end})

-- The viewer's own invitations (the party box) changed; everything else
-- comes as a roster change.
grug_parties.register_on_change(function(name, reason)
	if reason == "invitation" then request(name) end
end)
