local PAGE = "grug_parties:group"

local function esc(value) return core.formspec_escape(tostring(value or "")) end
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
			if not grug_parties.invitations_enabled(target) then
				status[#status + 1] = "Invites off"
			end
			if grug_parties.view(target) then status[#status + 1] = "In party" end
			rows[#rows + 1] = {name = name,
				label = #status > 0 and name .. " (" .. table.concat(status, ", ") .. ")" or name}
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
	local fs = {
		"real_coordinates[true]",
		("checkbox[0.20,0.22;grug_party_invites;Allow invitations;%s]")
			:format(grug_parties.invitations_enabled(player) and "true" or "false"),
		("checkbox[3.25,0.22;grug_party_hud;Party HUD;%s]")
			:format(grug_parties.hud_enabled(player) and "true" or "false"),
		"label[0.20,0.78;Online same-faction players]",
		"label[5.18,0.78;Pending invitations]",
	}
	local online, online_labels, online_index = online_roster(player, context), {}, 0
	for index, row in ipairs(online) do
		online_labels[index] = esc(row.label)
		if row.name == context.grug_party_online then online_index = index end
	end
	fs[#fs + 1] = ("textlist[0.20,1.12;4.55,2.15;grug_party_online_list;%s;%d;false]")
		:format(table.concat(online_labels, ","), online_index)
	fs[#fs + 1] = "button[0.20,3.40;1.35,0.58;grug_party_invite;Invite]"
	fs[#fs + 1] = "button[1.72,3.40;1.35,0.58;grug_party_refresh;Refresh]"
	local invites = {}
	for _, row in ipairs(pending) do
		local size = row.party and #row.party.members or 1
		invites[#invites + 1] = esc(("%s (%d/10, %ds)"):format(row.inviter, size, row.expires_in))
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
	fs[#fs + 1] = ("textlist[5.18,1.12;5.02,2.15;grug_party_pending;%s;%d;false]")
		:format(table.concat(invites, ","), selected_index)
	fs[#fs + 1] = "button[5.18,3.40;1.35,0.58;grug_party_accept;Accept]"
	fs[#fs + 1] = "button[6.70,3.40;1.35,0.58;grug_party_decline;Decline]"
	if view then
		fs[#fs + 1] = "label[0.20,4.25;Current party]"
		local members = {}
		context.grug_party_member_rows = {}
		for index, row in ipairs(view.members) do
			context.grug_party_member_rows[index] = row.name
			members[#members + 1] = esc((row.name == view.leader and "* " or "") .. row.name ..
				(row.online and ("  %d/%d HP"):format(row.hp, row.hp_max) or "  Offline"))
		end
		local selected = selected_member(view, context)
		local selected_index = 1
		for index, row in ipairs(view.members) do if row.name == selected.name then selected_index = index end end
		fs[#fs + 1] = ("textlist[0.20,4.58;4.55,1.45;grug_party_members;%s;%d;false]")
			:format(table.concat(members, ","), selected_index)
		local own_name = player:get_player_name()
		if view.leader == own_name and selected.name ~= own_name then
			fs[#fs + 1] = "button[0.20,6.15;1.35,0.58;grug_party_kick;Kick]"
			fs[#fs + 1] = "button[1.72,6.15;1.90,0.58;grug_party_transfer;Make leader]"
		end
		fs[#fs + 1] = "button[3.80,6.15;1.15,0.58;grug_party_leave;Leave]"
	else
		fs[#fs + 1] = "textarea[0.20,4.25;4.55,1.05;;;You are not in a party. Select an online same-faction player above.]"
	end
	if context.grug_party_notice then
		fs[#fs + 1] = "textarea[5.18,4.25;5.02,1.45;;;" .. esc(context.grug_party_notice) .. "]"
	end
	return table.concat(fs)
end

sfinv.register_page(PAGE, {title = "Group", on_enter = function(_, player, context)
	rebuild_roster(player, context)
end, get = function(_, player, context)
	return sfinv.make_formspec(player, context, content(player, context), true)
end, on_player_receive_fields = function(_, player, context, fields)
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
		local event = core.explode_textlist_event(fields.grug_party_members)
		local rows = context.grug_party_member_rows or {}
		if event.type == "CHG" and rows[event.index] then context.grug_party_member = rows[event.index] end
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
	end
	if ok ~= nil then notice(context, ok, message) end
	refresh(player)
end})

grug_parties.register_on_change(function(name)
	local player = core.get_player_by_name(name)
	if player then refresh(player) end
end)

core.register_on_mods_loaded(function()
	local page, ordered, inserted = sfinv.pages[PAGE], {}, false
	for _, def in ipairs(sfinv.pages_unordered) do
		if def ~= page then ordered[#ordered + 1] = def end
		if def.name == "grug_quests:quests" then ordered[#ordered + 1] = page; inserted = true end
	end
	if not inserted then ordered[#ordered + 1] = page end
	sfinv.pages_unordered = ordered
end)
