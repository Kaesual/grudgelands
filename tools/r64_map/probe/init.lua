-- Disposable headless probe: immutable seed roster for the before/after HUD benchmark.
core.after(0, function()
 local result = {seed=core.get_mapgen_setting("seed"), settlements={}, sockets={}, npcs={},
  identities=grug_core.start_identities(), homes=grug_home.locations(), layers=grug_map.layers.rows,
  dragons=grug_mobs.dragon_map_markers()}
 for _, row in ipairs(grug_core.settlement_socket_settlements()) do
  result.settlements[#result.settlements+1] = {key=row.key,race_id=row.race_id,
   anchor=row.anchor,slot=row.slot,display_name=row.display_name}
  local list = {}
  for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
   list[#list+1] = {id=socket.id,role=socket.role,profession=socket.profession,
    spawn=socket.spawn,pos=socket.pos}
  end
  result.sockets[row.key]=list
 end
 for id,npc in pairs(grug_quests.registered_npcs) do
  result.npcs[id]={settlement=npc.settlement,socket=npc.socket,title=npc.title,faction=npc.faction}
 end
 assert(core.safe_file_write(core.get_worldpath() .. "/r64-roster.lua", core.serialize(result)))
 core.log("action", "[r64_probe] benchmark roster exported")
end)
