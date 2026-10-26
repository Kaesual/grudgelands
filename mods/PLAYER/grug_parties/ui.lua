-- The Party & PvP tab (spec §3.8, Round 44 lane PP): the party section on
-- left (current party, online players of the own faction, pending invitations),
-- the invitation and HUD settings above, and the PvP section beside it
-- (grug_pvp/page.lua installs it as grug_parties.pvp_section). No inventory
-- view: the page has the whole window. Real coordinates.

local PAGE = "grug_parties:group"
grug_parties.PAGE = PAGE
-- Three party cards share the left column; PvP uses the full right column.
local PVP_Y = 0.85

local function esc(value) return core.formspec_escape(tostring(value or "")) end
local function health_color_mode(player)
	return grug_parties.health_color_mode and
		grug_parties.health_color_mode(player) or "by_class"
end
local function notice(context, ok, message)
	context.grug_party_notice = (ok and "Success: " or "Refused: ") .. (message or "")
end
local function refresh(player)
	if sfinv.get_page(player) == PAGE then sfinv.set_page(player, PAGE) end
end

local function selected_member(view, context)
	if not view then return nil end
	for _, row in ipairs(view.members) do
		if row.name == context.grug_party_member then return row end
	end
	context.grug_party_member = view.members[1] and view.members[1].name or nil
	return view.members[1]
end

local function rebuild_roster(player, context)
	local initial = context.grug_party_online_rows == nil
	local own_name = player:get_player_name()
	local own_faction = grug_factions.get_faction(player)
	local rows = {}
	for _, target in ipairs(core.get_connected_players()) do
		local name = target:get_player_name()
		if name ~= own_name and own_faction and
				grug_factions.get_faction(target) == own_faction then
			local status = {}
			local label = name .. " [Lv " .. grug_xp.get_level(target) .. "]"
			if not grug_parties.invitations_enabled(target) then
				status[#status + 1] = "Invites off"
			end
			if grug_parties.view(target) then status[#status + 1] = "In party" end
			rows[#rows + 1] = {name = name,
				label = #status > 0 and label .. " (" .. table.concat(status, ", ") .. ")" or label}
		end
	end
	table.sort(rows, function(a, b) return a.name < b.name end)
	context.grug_party_online_rows = rows
	local selected
	for _, row in ipairs(rows) do
		if row.name == context.grug_party_online then selected = row.name end
	end
	context.grug_party_online = selected or
		(initial and rows[1] and rows[1].name or nil)
end

local function online_roster(player, context)
	if not context.grug_party_online_rows then rebuild_roster(player, context) end
	return context.grug_party_online_rows
end

local function content(player, context)
	local view, pending = grug_parties.view(player), grug_parties.pending(player)
	local scale = grug_core.ui.text_scale(player)
	local fs = {
		"real_coordinates[true]", grug_core.ui.fonts(scale),
		grug_core.ui.panel(0.2, 0.85, 11.6, 4.25),
		grug_core.ui.panel(0.2, 5.3, 11.6, 3.4),
		grug_core.ui.panel(0.2, 8.9, 11.6, 3.4),
		"tableoptions[background=#00000000;border=false;highlight=#bba06255;highlight_text=#eeeae1]",
		grug_core.ui.button_style("grug_party_leave", "danger", scale),
		grug_core.ui.button_style("grug_party_kick", "danger", scale),
		-- Refresh takes the focus at every send (0.45.1): otherwise the engine
		-- focuses a read-only textarea or the member table, and both eat the
		-- inventory key. Unforced it would not apply when the inventory key
		-- opens the window; Space or Enter on Refresh is harmless.
		"set_focus[grug_party_refresh;true]",
		("checkbox[0.4,0.35;grug_party_invites;Invitations;%s]")
			:format(grug_parties.invitations_enabled(player) and "true" or "false"),
		"tooltip[grug_party_invites;Allow invitations from other players.]",
		("checkbox[5.0,0.35;grug_party_hud;Party HUD;%s]")
			:format(grug_parties.hud_enabled(player) and "true" or "false"),
		"label[10.20,0.35;Health colors]",
		("dropdown[12.5,0.1;4.5,0.5;grug_party_health_colors;All green,By class;%d;true]")
			:format(health_color_mode(player) == "by_class" and 2 or 1),
		grug_core.ui.heading(0.5, 1.2, "Current party", scale),
		grug_core.ui.heading(0.5, 5.65, "Online same-faction players", scale),
		grug_core.ui.heading(0.5, 9.25, "Pending invitations", scale),
	}
	-- Index -1 actively clears GUITable's preserved dynamic selection. Index 0
	-- skips setSelected and can leave an old row highlighted after a refresh.
	local online, online_labels, online_index = online_roster(player, context), {}, -1
	for index, row in ipairs(online) do
		online_labels[index] = esc(row.label)
		if row.name == context.grug_party_online then online_index = index end
	end
	if #online > 0 then
		fs[#fs + 1] = ("textlist[0.50,6.05;11.0,1.60;grug_party_online_list;%s;%d;true]")
			:format(table.concat(online_labels, ","), online_index)
	end
	fs[#fs + 1] = "button[0.50,7.95;1.8,0.58;grug_party_invite;Invite]"
	fs[#fs + 1] = "button[2.50,7.95;1.8,0.58;grug_party_refresh;Refresh]"
	if #online == 0 then
		fs[#fs + 1] = grug_core.ui.prose(0.5, 6.05, 11.0, 1.6,
			"No other same-faction players are online.", true, scale)
	end
	local invites = {}
	for _, row in ipairs(pending) do
		local size = row.party and #row.party.members or 1
		invites[#invites + 1] = esc(("%s [Lv %d] (%d/10, %ds)"):format(row.inviter, row.level, size, row.expires_in))
	end
	local selected_index
	context.grug_party_invite_rows = {}
	for index, row in ipairs(pending) do
		context.grug_party_invite_rows[index] = row.inviter
		if row.inviter == context.grug_party_inviter then selected_index = index end
	end
	if not selected_index then
		selected_index = 1
		context.grug_party_inviter = pending[1] and pending[1].inviter or nil
	end
	if #pending > 0 then
		fs[#fs + 1] = ("textlist[0.50,9.65;11.0,1.60;grug_party_pending;%s;%d;true]")
			:format(table.concat(invites, ","), selected_index)
	end
	fs[#fs + 1] = "button[0.50,11.55;1.8,0.58;grug_party_accept;Accept]"
	fs[#fs + 1] = "button[2.50,11.55;1.8,0.58;grug_party_decline;Decline]"
	if #pending == 0 then
		fs[#fs + 1] = grug_core.ui.prose(0.5, 9.65, 11.0, 1.6, "No pending invitations.", true, scale)
	end
	if view then
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
		fs[#fs + 1] = ("table[0.50,1.60;11.0,2.45;grug_party_members;%s;%d]")
			:format(table.concat(cells, ","), selected_index)
		local own_name = player:get_player_name()
		if view.leader == own_name and selected.name ~= own_name then
			fs[#fs + 1] = "button[9.70,4.25;1.8,0.58;grug_party_kick;Kick]"
			fs[#fs + 1] = "button[6.70,4.25;2.8,0.58;grug_party_transfer;Make leader]"
		end
		fs[#fs + 1] = "button[0.50,4.25;1.8,0.58;grug_party_leave;Leave]"
	else
		fs[#fs + 1] = grug_core.ui.prose(0.5, 1.6, 11.0, 1.5,
			"You are not in a party.\nSelect an online same-faction player below to invite them.", true, scale)
	end
	if context.grug_party_notice then
		fs[#fs + 1] = grug_core.ui.prose(0.5, 12.5, 11.0, 0.65, context.grug_party_notice, false, scale)
	end
	local pvp = grug_parties.pvp_section
	if pvp then
		fs[#fs + 1] = ("container[12.1,%.2f]"):format(PVP_Y)
		fs[#fs + 1] = pvp.get(player, context, 0)
		fs[#fs + 1] = "container_end[]"
	end
	return table.concat(fs)
end

sfinv.register_page(PAGE, {title = "Party & PvP", on_enter = function(_, player, context)
	rebuild_roster(player, context)
end, get = function(_, player, context)
	return sfinv.make_formspec(player, context, content(player, context), false)
end, on_player_receive_fields = function(_, player, context, fields)
	if fields.quit then return true end
	local pvp = grug_parties.pvp_section
	if pvp and pvp.on_fields(player, context, fields) then return true end
	if fields.grug_party_online_list then
		local event = core.explode_textlist_event(fields.grug_party_online_list)
		local rows = context.grug_party_online_rows or {}
		if event.type == "CHG" and rows[event.index] then
			context.grug_party_online = rows[event.index].name
		end
	end
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
	local ok, message
	if fields.grug_party_invite and context.grug_party_online then
		ok, message = grug_parties.invite(player, context.grug_party_online)
	elseif fields.grug_party_invite then
		ok, message = false, "Select an online same-faction player."
	elseif fields.grug_party_refresh then
		rebuild_roster(player, context)
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
		local modes = {all_green = "1", by_class = "2"}
		local mode = fields.grug_party_health_colors == modes.by_class
			and "by_class" or fields.grug_party_health_colors == modes.all_green
			and "all_green" or nil
		ok, message = grug_parties.set_health_color_mode(player, mode)
	end
	if ok ~= nil then notice(context, ok, message) end
	refresh(player)
end})

grug_parties.register_on_change(function(name, reason)
	local player = core.get_player_by_name(name)
	if player then
		if reason == "level" and sfinv.get_page(player) == PAGE then
			rebuild_roster(player, sfinv.get_or_create_context(player))
		end
		refresh(player)
	end
end)
