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
 return "formspec_version[3]size[7,3]label[0.4,0.5;" ..
  core.formspec_escape(row.label .. " Innkeeper") .. "]" ..
  (home and home.id == row.id and "label[0.4,1.3;This is your home]" or
   "button[0.4,1.1;4,0.7;bind;Set home here]") ..
  "button_exit[4.8,2.1;1.7,0.6;close;Close]"
end
function grug_home.open_innkeeper(player,entity)
 local row = permitted(player,entity)
 if not row then return false end
 local name = player:get_player_name()
 serial = serial + 1
 local formname = "grug_home:innkeeper:" .. serial
 dialogs[name] = {entity=entity,formname=formname}
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
  core.show_formspec(name,formname,form(player,row))
 end
 return true
end)
local function clear(player) dialogs[player:get_player_name()] = nil end
core.register_on_joinplayer(clear)
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
