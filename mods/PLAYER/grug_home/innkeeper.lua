local dialogs, serial = {}, 0
local function permitted(player, entity)
 if not player or not player:is_player() or player:get_hp() <= 0 or not entity or
   entity._grug_socket_role ~= "innkeeper" or not entity.object then return nil end
 local row = grug_home.location(entity._grug_start)
 if not row or row.socket ~= entity._grug_socket or
   row.faction ~= grug_factions.get_faction(player) then return nil end
 local pos, npc = player:get_pos(), entity.object:get_pos()
 if not pos or not npc or vector.distance(pos,npc) > 8 or
   vector.distance(npc,row.pos) > 2 or entity.object:get_luaentity() ~= entity then return nil end
 return row
end
local function form(player,row)
 local home = grug_home.get(player)
 local UI = grug_core.ui
 return UI.frame(9, 4.7, nil, nil, player) .. "set_focus[close;true]" .. UI.service_header(9, row.label .. " Innkeeper", "A place to return to") ..
  UI.panel(0.4, 1.6, 8.2, 1.9) .. UI.heading(0.65, 1.92, "YOUR HOME") ..
  UI.prose(0.65, 2.2, 7.7, 1.0, (home and home.label or "No home set") .. "\n" ..
   (home and home.id == row.id and "This is your home." or "Set " .. row.label .. " as your home.")) ..
  (home and home.id == row.id and "" or UI.button_style("bind", "selected") ..
   "button[0.4,3.8;3,0.6;bind;Set home here]") ..
  "button_exit[6.9,3.8;1.7,0.6;close;Close]"
end
function grug_home.open_innkeeper(player,entity)
 local row = permitted(player,entity)
 if not row then return false end
 local name = player:get_player_name()
 serial = serial + 1
 local formname = "grug_home:innkeeper:" .. serial
 dialogs[name] = {entity=entity,formname=formname}
 grug_sounds.play("npc_innkeeper", player)
 core.show_formspec(name,formname,form(player,row))
 return true
end
core.register_on_player_receive_fields(function(player,formname,fields)
 if formname:sub(1,20) ~= "grug_home:innkeeper:" then return false end
 local name = player:get_player_name()
 local dialog = dialogs[name]
 if not dialog or dialog.formname ~= formname then return true end
 local row = permitted(player,dialog.entity)
 if fields.quit or not row then dialogs[name] = nil; return true end
 if fields.bind then
  grug_home.cancel(player)
  player:get_meta():set_string("grug_home:id",row.id)
  grug_home.clear_home_claim(player)
  core.show_formspec(name,formname,form(player,row))
 end
 return true
end)
local function clear(player) dialogs[player:get_player_name()] = nil end
core.register_on_joinplayer(clear)
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
