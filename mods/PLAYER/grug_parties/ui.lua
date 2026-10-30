-- The Social tab (Round 67 lane SOCIAL, rulings 1-8; the Party & PvP tab of
-- Round 44 lane PP before it). Left: the invitation and HUD settings, one
-- party box (the current party, or without one the pending invitations;
-- a party member holds none) and the PvP section below it (grug_pvp/page.lua
-- installs it as grug_parties.pvp_section). Right, at full height: every
-- online player of both factions, one compact row each, with a favourite
-- star and an invite button. No inventory view: the page has the whole
-- window. Real coordinates.
--
-- Refresh (ruling 8 and its default): a change of the player list
-- (grug_parties.register_on_roster_change) or of the viewer's own
-- invitations re-sends the page, only to players whose current page this
-- is, at most once per SEND_GAP_US: changes in one server step make one
-- send, a change inside the gap is owed and goes out when it ends. Every
-- build counts as a send (the PvP section's countdown and the player's own
-- clicks re-send at once). A scrollbar move holds every send for QUIET_US
-- (the map window's rule): a form rebuilt while the player drags the
-- scrollbar would break the drag. The client does not keep the scroll
-- position across a resend but sends it with every event, so it is kept
-- in the sfinv context and echoed (grug_inventory/ui.lua keep_scroll).

local PAGE = "grug_parties:group"
grug_parties.PAGE = PAGE
local FAVORITES_KEY = "grug_parties:favorites"
grug_parties.FAVORITES_KEY = FAVORITES_KEY
grug_parties.SEND_GAP_US, grug_parties.QUIET_US = 2000000, 500000

-- The page body is 20 x 13.5 (grug_inventory UI.frame_w, frame_h).
local LEFT_X, LEFT_W = 0.2, 9.7
local BOX_Y, BOX_H = 0.85, 5.9
local PVP_Y = 6.95
local LIST_X, LIST_Y, LIST_W, LIST_H = 10.1, 0.1, 9.7, 13.2
-- The rows' scroll area inside the list card and its scrollbar right of it.
local VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 10.3, 0.85, 8.95, 12.25
local ROW_H, ROW_PITCH = 0.54, 0.6
-- Real units per scrollbar unit: a row is six units.
local SCROLL_FACTOR = 0.1
local SCROLL_FIELD = "grug_social_scroll"
local SCROLLBAR_DEFAULTS = "scrollbaroptions[min=0;max=1000;smallstep=10;" ..
	"largestep=100;thumbsize=1;arrows=default]"
local FOCUS_FIELD = "grug_social_focus"
local INVITE_PREFIX, STAR_PREFIX = "grug_social_inv_", "grug_social_fav_"
local STAR_ON, STAR_OFF = "#f0c419", "#9a9a9a"
local FACTION_ICONS = {accord = "grug_inventory_faction_accord.png",
	throng = "grug_inventory_faction_throng.png"}

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

-- One row at `y` of the scroll area: faction, name, class, race and level
-- left (icons with the word as tooltip), star and invite button right.
local function icon(fs, x, y, texture, tip)
	if not texture or texture == "" then return end
	fs[#fs + 1] = ("image[%.2f,%.2f;0.42,0.42;%s]"):format(x, y + 0.06, esc(texture))
	if tip then
		fs[#fs + 1] = ("tooltip[%.2f,%.2f;0.42,0.42;%s]"):format(x, y + 0.06, esc(tip))
	end
end
local function list_row(fs, index, row, y, own, stars)
	if own then
		fs[#fs + 1] = ("box[0,%.2f;%.2f,%.2f;#bba06230]"):format(y, VIEW_W, ROW_H)
	elseif index % 2 == 0 then
		fs[#fs + 1] = ("box[0,%.2f;%.2f,%.2f;#ffffff0b]"):format(y, VIEW_W, ROW_H)
	end
	icon(fs, 0.1, y, FACTION_ICONS[row.faction],
		row.faction and grug_factions.display_name(row.faction))
	fs[#fs + 1] = ("label[0.65,%.2f;%s]"):format(y + ROW_H / 2,
		esc(own and row.name .. " (you)" or row.name))
	icon(fs, 4.6, y, grug_core.status_icons.class_icon(row.class), row.class_name)
	icon(fs, 5.1, y, grug_core.status_icons.race_icon(row.race), row.race_name)
	fs[#fs + 1] = ("label[5.7,%.2f;Lv %d]"):format(y + ROW_H / 2, row.level or 1)
	if own then return end
	local star = STAR_PREFIX .. row.name
	local same = row.favorite and stars.on or stars.off
	same[#same + 1] = star
	fs[#fs + 1] = ("button[6.65,%.2f;0.5,0.5;%s;%s]tooltip[%s;%s]"):format(y + 0.02, star,
		row.favorite and "★" or "☆", star,
		row.favorite and "Remove from favorites" or "Add to favorites")
	if row.invite then
		fs[#fs + 1] = ("button[7.3,%.2f;1.55,0.5;%s%s;Invite]"):format(y + 0.02,
			INVITE_PREFIX, row.name)
	end
end

local function online_list(fs, player, context, scale)
	local own = player:get_player_name()
	local own_faction = grug_factions.get_faction(player)
	local favorites = favorites_of(player)
	local rows = sorted_rows(own_faction, favorites)
	fs[#fs + 1] = grug_core.ui.heading(LIST_X + 0.3, LIST_Y + 0.35,
		("Online Players (%d)"):format(#rows), scale)
	local content_h = #rows * ROW_PITCH
	local max = math.max(0, math.ceil((content_h - VIEW_H) / SCROLL_FACTOR - 1e-9))
	local value = math.max(0, math.min(max, math.floor(context.grug_social_scroll or 0)))
	context.grug_social_scroll = value
	if max > 0 then
		-- The thumb shows the visible share (grug_skills/page.lua).
		local thumb = math.max(1, math.floor(VIEW_H / content_h * (max + 1) + 0.5))
		local step = ROW_PITCH / SCROLL_FACTOR
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;" ..
			"thumbsize=%d;arrows=default]"):format(max, step, math.floor(VIEW_H / SCROLL_FACTOR), thumb)
		fs[#fs + 1] = ("scrollbar[%.2f,%.2f;0.3,%.2f;vertical;%s;%d]"):format(
			VIEW_X + VIEW_W + 0.1, VIEW_Y, VIEW_H, SCROLL_FIELD, value)
		fs[#fs + 1] = SCROLLBAR_DEFAULTS
	end
	fs[#fs + 1] = ("scroll_container[%.2f,%.2f;%.2f,%.2f;%s;vertical;%.2f]"):format(
		VIEW_X, VIEW_Y, VIEW_W, VIEW_H, SCROLL_FIELD, SCROLL_FACTOR)
	local stars = {on = {}, off = {}}
	local body = {}
	for index, row in ipairs(rows) do
		local is_own = row.name == own
		local shown = {name = row.name, faction = row.faction, class = row.class,
			class_name = row.class_name, race = row.race, race_name = row.race_name,
			level = row.level, favorite = favorites[row.name],
			-- Enemy rows never have the button (eligible refuses them).
			invite = not is_own and row.faction ~= nil and row.faction == own_faction and
				grug_parties.can_invite(own, row.name)}
		list_row(body, index, shown, (index - 1) * ROW_PITCH, is_own, stars)
	end
	-- One style per star colour, before the buttons it names.
	local font = grug_core.ui.font_size(1.3, grug_core.ui.text_growth(player))
	for _, kind in ipairs({"on", "off"}) do
		if #stars[kind] > 0 then
			fs[#fs + 1] = ("style[%s;textcolor=%s;font_size=%s]"):format(
				table.concat(stars[kind], ","), kind == "on" and STAR_ON or STAR_OFF, font)
		end
	end
	fs[#fs + 1] = table.concat(body)
	fs[#fs + 1] = "scroll_container_end[]"
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

-- "0 Pending Invitations", "1 Pending Invitation", "2 Pending Invitations".
function grug_parties.pending_heading(count)
	return ("%d Pending Invitation%s"):format(count, count == 1 and "" or "s")
end

local function party_members(fs, player, context, view, scale)
	fs[#fs + 1] = grug_core.ui.heading(0.5, BOX_Y + 0.35,
		("Current Party (%d/10)"):format(#view.members), scale)
	-- A table rather than a textlist so each member row can carry the
	-- class icon (Round 26 ruling 22); image 0 is blank (offline or no
	-- class yet), images 1..n are the class icons.
	local classes = grug_core.status_icons.CLASSES
	local image_index, images = {}, {"0=blank.png"}
	for index, id in ipairs(classes) do
		image_index[id] = index
		images[#images + 1] = index .. "=" .. esc(grug_core.status_icons.class_icon(id))
	end
	local cells = {}
	context.grug_party_member_rows = {}
	for index, row in ipairs(view.members) do
		context.grug_party_member_rows[index] = row.name
		cells[#cells + 1] = tostring(image_index[row.class] or 0)
		cells[#cells + 1] = esc((row.name == view.leader and "* " or "") .. row.name .. " [Lv " .. row.level .. "]" ..
			(row.online and ("  %d/%d HP"):format(row.hp, row.hp_max) or "  Offline"))
	end
	local selected = selected_member(view, context)
	local selected_index = 1
	for index, row in ipairs(view.members) do if row.name == selected.name then selected_index = index end end
	fs[#fs + 1] = "tablecolumns[image,align=center," ..
		table.concat(images, ",") .. ";text,padding=0.25]"
	fs[#fs + 1] = ("table[0.50,%.2f;9.1,3.3;grug_party_members;%s;%d]")
		:format(BOX_Y + 0.75, table.concat(cells, ","), selected_index)
	local own_name = player:get_player_name()
	local buttons_y = BOX_Y + 4.25
	if view.leader == own_name and selected.name ~= own_name then
		fs[#fs + 1] = ("button[7.80,%.2f;1.8,0.58;grug_party_kick;Kick]"):format(buttons_y)
		fs[#fs + 1] = ("button[4.80,%.2f;2.8,0.58;grug_party_transfer;Make leader]"):format(buttons_y)
	end
	fs[#fs + 1] = ("button[0.50,%.2f;1.8,0.58;grug_party_leave;Leave]"):format(buttons_y)
end

local function party_invitations(fs, context, pending, scale)
	fs[#fs + 1] = grug_core.ui.heading(0.5, BOX_Y + 0.35,
		grug_parties.pending_heading(#pending), scale)
	context.grug_party_invite_rows = {}
	if #pending == 0 then
		context.grug_party_inviter = nil
		fs[#fs + 1] = grug_core.ui.prose(0.5, BOX_Y + 0.75, 9.1, 1.5,
			"You are not in a party.\nInvite a player of your faction with the Invite " ..
			"button in the Online Players list.", true, scale)
		return
	end
	local invites, selected_index = {}, nil
	for index, row in ipairs(pending) do
		local size = row.party and #row.party.members or 1
		invites[index] = esc(("%s [Lv %d] (%d/10, %ds)"):format(row.inviter, row.level, size, row.expires_in))
		context.grug_party_invite_rows[index] = row.inviter
		if row.inviter == context.grug_party_inviter then selected_index = index end
	end
	if not selected_index then
		selected_index = 1
		context.grug_party_inviter = pending[1].inviter
	end
	fs[#fs + 1] = ("textlist[0.50,%.2f;9.1,3.3;grug_party_pending;%s;%d;true]")
		:format(BOX_Y + 0.75, table.concat(invites, ","), selected_index)
	fs[#fs + 1] = ("button[0.50,%.2f;1.8,0.58;grug_party_accept;Accept]"):format(BOX_Y + 4.25)
	fs[#fs + 1] = ("button[2.50,%.2f;1.8,0.58;grug_party_decline;Decline]"):format(BOX_Y + 4.25)
end

local function content(player, context)
	local view = grug_parties.view(player)
	local scale = grug_core.ui.text_scale(player)
	local fs = {
		"real_coordinates[true]", grug_core.ui.fonts(scale),
		grug_core.ui.panel(LEFT_X, BOX_Y, LEFT_W, BOX_H),
		grug_core.ui.panel(LIST_X, LIST_Y, LIST_W, LIST_H),
		"tableoptions[background=#00000000;border=false;highlight=#bba06255;highlight_text=#eeeae1]",
		grug_core.ui.button_style("grug_party_leave", "danger", scale),
		grug_core.ui.button_style("grug_party_kick", "danger", scale),
		-- An invisible button with no action takes the focus at every send
		-- (0.45.1, module guide "Initial focus"): otherwise the engine focuses
		-- a read-only textarea, the member table or an Invite button. Forced,
		-- so it also applies when the inventory key opens the window.
		"set_focus[grug_social_focus;true]button[0,0;0,0;grug_social_focus;]",
		("checkbox[0.4,0.35;grug_party_invites;Invitations;%s]")
			:format(grug_parties.invitations_enabled(player) and "true" or "false"),
		"tooltip[grug_party_invites;Allow invitations from other players.]",
		("checkbox[2.9,0.35;grug_party_hud;Party HUD;%s]")
			:format(grug_parties.hud_enabled(player) and "true" or "false"),
		"label[5.15,0.35;Health colors]",
		("dropdown[7.2,0.1;2.5,0.5;grug_party_health_colors;All green,By class;%d;true]")
			:format(health_color_mode(player) == "by_class" and 2 or 1),
	}
	if view then
		party_members(fs, player, context, view, scale)
	else
		party_invitations(fs, context, grug_parties.pending(player), scale)
	end
	if context.grug_party_notice then
		fs[#fs + 1] = grug_core.ui.prose(0.5, BOX_Y + 5.0, 9.1, 0.7, context.grug_party_notice, false, scale)
	end
	online_list(fs, player, context, scale)
	local pvp = grug_parties.pvp_section
	if pvp then
		fs[#fs + 1] = ("container[%.2f,%.2f]"):format(LEFT_X, PVP_Y)
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

-- For the PvP section's countdown (grug_pvp/page.lua): re-sends the open
-- page now, or owes it while the player drags the scrollbar.
function grug_parties.social_resend(player, context)
	if core.get_us_time() < send_state(context).quiet then
		request(player:get_player_name())
		return
	end
	sfinv.set_player_inventory_formspec(player, context)
end

-- The scrollbar's value from every event of the inventory form (CHG for its
-- own move, VAL for any other); its own move holds the sends for QUIET_US and
-- ends there, without a resend. Chains sfinv's hook (api.lua GRUG PATCH).
local previous_handle_scroll = sfinv.handle_scroll
function sfinv.handle_scroll(player, context, fields)
	local raw = fields[SCROLL_FIELD]
	local kind, value
	if type(raw) == "string" then kind, value = raw:match("^(%u+):(%-?%d+)$") end
	if kind == "CHG" or kind == "VAL" then
		context.grug_social_scroll = math.max(0, tonumber(value))
	end
	local handled = previous_handle_scroll(player, context, fields)
	if kind == "CHG" and context.page == PAGE then
		send_state(context).quiet = core.get_us_time() + grug_parties.QUIET_US
		return true
	end
	return handled
end

sfinv.register_page(PAGE, {title = "Social", on_enter = function(_, _, context)
	context.grug_social_scroll = 0
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
	if fields.grug_party_pending then
		local event = core.explode_textlist_event(fields.grug_party_pending)
		local rows = context.grug_party_invite_rows or {}
		if event.type == "CHG" and rows[event.index] then context.grug_party_inviter = rows[event.index] end
	end
	local view = grug_parties.view(player)
	if fields.grug_party_members and view then
		local event = core.explode_table_event(fields.grug_party_members)
		local rows = context.grug_party_member_rows or {}
		if event.type == "CHG" and rows[event.row] then context.grug_party_member = rows[event.row] end
	end
	-- A row's buttons name their player, never a place in the list.
	local invite_target, star_target
	for field in pairs(fields) do
		invite_target = invite_target or field:match("^" .. INVITE_PREFIX .. "(.+)$")
		star_target = star_target or field:match("^" .. STAR_PREFIX .. "(.+)$")
	end
	local ok, message
	if invite_target then
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
