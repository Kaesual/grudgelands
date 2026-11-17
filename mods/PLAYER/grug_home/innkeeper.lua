local dialogs, serial = {}, 0
-- The home row of the live innkeeper on its own socket (the row's position),
-- within talking range, for the row's faction (grug_core.npc_window_permitted).
local function permitted(player, entity)
 if type(entity) ~= "table" then return nil end
 local row = grug_home.location(entity._grug_start)
 if not row or row.socket ~= entity._grug_socket or
   not grug_core.npc_window_permitted(player, entity, "innkeeper", row.faction,
    {socket_pos = row.pos}) then return nil end
 return row
end
local function form(player,row)
 local home = grug_home.get(player)
 local UI = grug_core.ui
 local growth = UI.text_growth(player, 9, 4.7)
 return UI.frame(9, 4.7, nil, nil, player) .. "set_focus[close;true]" .. UI.service_header(9, row.label .. " Innkeeper", "A place to return to", nil, growth) ..
  UI.panel(0.4, 1.6, 8.2, 1.9) .. UI.heading(0.65, 1.92, "YOUR HOME", growth) ..
  UI.prose(0.65, 2.2, 7.7, 1.0, (home and home.label or "No home set") .. "\n" ..
   (home and home.id == row.id and "This is your home." or "Set " .. row.label .. " as your home."), false, growth) ..
  (home and home.id == row.id and "" or UI.button_style("bind", "selected", growth) ..
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
