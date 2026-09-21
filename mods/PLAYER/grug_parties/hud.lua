local huds = {}
local elapsed = 0
local ROW_HEIGHT = 30
local WIDTH = grug_core.hud_layout.BAR_WIDTH

local function change(player, row, key, id, property, value)
	local previous = row[key]
	local equal = type(value) == "table" and previous and
		previous.x == value.x and previous.y == value.y or previous == value
	if not equal then player:hud_change(id, property, value); row[key] = value end
end
local function remove_rows(player, record, count)
	for i = #record.rows, count + 1, -1 do
		local row = record.rows[i]
		player:hud_remove(row.label)
		player:hud_remove(row.track)
		player:hud_remove(row.fill)
		record.rows[i] = nil
	end
end
local function make_row(player, index)
	local layout = grug_core.hud_layout
	local anchor = layout.anchors.party_list
	local y = anchor.offset.y + (index - 1) * ROW_HEIGHT
	local function bar(color, layer)
		return player:hud_add({type="image",position=anchor.position,
			offset={x=anchor.offset.x,y=y+18},alignment={x=1,y=1},
			scale={x=WIDTH,y=6},text=layout.bar_texture(color),z_index=layer})
	end
	return {
		label=player:hud_add({type="text",position=anchor.position,
			offset={x=anchor.offset.x,y=y},alignment={x=1,y=1},
			text="",number=0xffffff,z_index=2}),
		track=bar(layout.COLOR.track,0), fill=bar(layout.COLOR.life,1),
	}
end
local function refresh(player)
	local record = huds[player:get_player_name()]
	if not record then return end
	local view = grug_parties.hud_enabled(player) and grug_parties.view(player)
	if not view then remove_rows(player,record,0); return end
	remove_rows(player,record,#view.members)
	for index, member in ipairs(view.members) do
		local row = record.rows[index]
		if not row then row=make_row(player,index);record.rows[index]=row end
		local name = member.name
		if #name > 18 then name = name:sub(1,16) .. ".." end
		local label = (member.name == view.leader and "* " or "") .. name
		if member.online then
			label = label .. ("  %d/%d"):format(member.hp,member.hp_max)
		else
			label = label .. " [Offline]"
		end
		change(player,row,"text",row.label,"text",label)
		local fill = member.online and grug_core.hud_layout.bar_fill(member.hp,member.hp_max) or 0
		change(player,row,"width",row.fill,"scale",{x=math.max(1,fill),y=6})
		change(player,row,"texture",row.fill,"text", fill > 0 and
			grug_core.hud_layout.bar_texture(grug_core.hud_layout.COLOR.life) or "")
	end
end
core.register_on_joinplayer(function(player)
	huds[player:get_player_name()] = {rows={}}
	refresh(player)
end)
core.register_on_leaveplayer(function(player) huds[player:get_player_name()] = nil end)
grug_parties.register_on_change(function(name)
	local player=core.get_player_by_name(name)
	if player then refresh(player) end
end)
core.register_globalstep(function(dtime)
	elapsed=elapsed+dtime
	if elapsed < 0.5 then return end
	elapsed=elapsed%0.5
	for _,player in ipairs(core.get_connected_players()) do refresh(player) end
end)
