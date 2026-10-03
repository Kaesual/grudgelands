local huds = {}
local elapsed = 0
local WIDTH = grug_core.hud_layout.BAR_WIDTH
local CLASS_COLORS = {
	warrior = 0xa66a3f,
	mage = 0x4a9bd8,
	priest = 0xf2f2f2,
	scout = 0x6b7d32,
}

function grug_parties.health_bar_color(mode, class_id)
	if mode == "by_class" then return CLASS_COLORS[class_id] or 0x4caf50 end
	return 0x4caf50
end

local function health_color_mode(player)
	return grug_parties.health_color_mode and
		grug_parties.health_color_mode(player) or "by_class"
end

local function change(player, row, key, id, property, value)
	local previous = row[key]
	local equal = type(value) == "table" and previous and
		previous.x == value.x and previous.y == value.y or previous == value
	if not equal then player:hud_change(id, property, value); row[key] = value end
end
local function remove_rows(player, record, count)
	for i = #record.rows, count + 1, -1 do
		local row = record.rows[i]
		player:hud_remove(row.icon)
		player:hud_remove(row.label)
		player:hud_remove(row.track)
		player:hud_remove(row.fill)
		record.rows[i] = nil
	end
end
local function make_row(player, index, count, window)
	local layout = grug_core.hud_layout
	local anchor = layout.anchors.party_list
	local offset = layout.party_row_offset(index, count, false, window)
	local bar_offset = layout.party_row_offset(index, count, true, window)
	local function bar(color, layer)
		return player:hud_add({type="image",position=anchor.position,
			offset=bar_offset,alignment={x=1,y=1},
			scale={x=WIDTH,y=layout.PARTY_BAR_HEIGHT},text=layout.bar_texture(color),z_index=layer})
	end
	-- The member's class icon (Round 26 ruling 22), left of name and bar.
	local icon_scale = layout.party_icon_size(window) / 64
	return {
		icon=player:hud_add({type="image",position=anchor.position,
			offset=layout.party_icon_offset(index,count,window),alignment={x=1,y=1},
			scale={x=icon_scale,y=icon_scale},text="",z_index=2}),
		label=player:hud_add({type="text",position=anchor.position,
			offset=offset,alignment={x=1,y=1},
			text="",number=0xffffff,z_index=2}),
		track=bar(layout.COLOR.track,0), fill=bar(layout.COLOR.life,1),
	}
end
-- What the rows' places, the icon size and the name width follow: the
-- window's width and scalings and the row count. They are recomputed only
-- when this changes (Round 32, perf review R2).
local function layout_key(window, count)
	if not window then return tostring(count) end
	return ("%d %s %s %s"):format(count, tostring(window.size and window.size.x),
		tostring(window.real_hud_scaling), tostring(window.real_gui_scaling))
end
local function refresh(player)
	local name = player:get_player_name()
	local record = huds[name]
	if not record then return end
	-- Most players have no party: no rows to keep and nothing to read.
	if #record.rows == 0 and not grug_parties.in_party(name) then return end
	local view = grug_parties.hud_enabled(player) and grug_parties.view(player)
	if not view then remove_rows(player,record,0); record.layout = nil; return end
	local count = #view.members
	remove_rows(player,record,count)
	local layout = grug_core.hud_layout
	local color_mode = health_color_mode(player)
	local window = core.get_player_window_information(name)
	local key = layout_key(window, count)
	local relayout = key ~= record.layout
	if relayout then
		record.layout, record.width = key, layout.side_text_width(window)
	end
	local width = record.width
	local icon_scale = relayout and layout.party_icon_size(window) / 64
	for index, member in ipairs(view.members) do
		local row = record.rows[index]
		if not row then row=make_row(player,index,count,window);record.rows[index]=row end
		if relayout then
			change(player,row,"icon_offset",row.icon,"offset",layout.party_icon_offset(index,count,window))
			change(player,row,"icon_scale",row.icon,"scale",{x=icon_scale,y=icon_scale})
			change(player,row,"label_offset",row.label,"offset",layout.party_row_offset(index,count,false,window))
			local bar_offset = layout.party_row_offset(index,count,true,window)
			change(player,row,"track_offset",row.track,"offset",bar_offset)
			change(player,row,"fill_offset",row.fill,"offset",bar_offset)
		end
		change(player,row,"icon_texture",row.icon,"text",
			grug_core.status_icons.class_icon(member.class))
		local prefix = member.name == view.leader and "* " or ""
		local suffix = " [Lv " .. member.level .. "]" ..
			(member.online and ("  %d/%d"):format(member.hp,member.hp_max) or " [Offline]")
		local limit = math.max(4, math.min(18, width - #prefix - #suffix))
		local shown = member.name
		if #shown > limit then shown = shown:sub(1,limit-2) .. ".." end
		local label = prefix .. shown .. suffix
		change(player,row,"text",row.label,"text",label)
		local fill = member.online and grug_core.hud_layout.bar_fill(member.hp,member.hp_max) or 0
		local color = grug_parties.health_bar_color(color_mode, member.class)
		change(player,row,"width",row.fill,"scale",{x=math.max(1,fill),y=layout.PARTY_BAR_HEIGHT})
		change(player,row,"texture",row.fill,"text", fill > 0 and
			grug_core.hud_layout.bar_texture(color) or "")
	end
end
-- Each player is polled every SLOTS x SLOT_PERIOD = 0.5 s, in one of SLOTS
-- phases by join order, so many players never refresh in the same step
-- (Round 32, perf review R2; the quest tracker's pattern, grug_quests/hud.lua).
local SLOTS, SLOT_PERIOD = 5, 0.1
local slot_of, joined, current_slot = {}, 0, 0

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	huds[name] = {rows={}}
	joined = joined + 1
	slot_of[name] = joined % SLOTS + 1
	refresh(player)
end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	huds[name], slot_of[name] = nil, nil
end)
grug_parties.register_on_change(function(name)
	local player=core.get_player_by_name(name)
	if player then refresh(player) end
end)
core.register_globalstep(function(dtime)
	elapsed=elapsed+dtime
	if elapsed < SLOT_PERIOD then return end
	-- A stall longer than one period collapses to a single slot.
	elapsed=elapsed-SLOT_PERIOD
	if elapsed > SLOT_PERIOD then elapsed=0 end
	current_slot = current_slot % SLOTS + 1
	for name, slot in pairs(slot_of) do
		if slot == current_slot then
			local player = core.get_player_by_name(name)
			if player then refresh(player) end
		end
	end
end)
