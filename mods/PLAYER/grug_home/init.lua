grug_home = {}
local path = core.get_modpath(core.get_current_modname())
local definitions = dofile(path .. "/locations.lua")
local locations, ordered, defaults = {}, {}, {}
for index, definition in ipairs(definitions) do
 local socket = grug_core.assign_innkeeper_socket(definition.id, definition.socket)
 local row = {id=definition.id, race=definition.race, faction=definition.faction,
  label=definition.label, socket=socket.id, pos=socket.pos,
  arrival=vector.offset(socket.pos,1,-0.49,0)}
 locations[row.id] = row
 ordered[index] = row
 if index <= 6 then defaults[row.race] = row.id end
end
local function copy(row)
 if not row then return nil end
 return {id=row.id, race=row.race, faction=row.faction, label=row.label,
  socket=row.socket, pos=vector.new(row.pos), arrival=vector.new(row.arrival)}
end
function grug_home.locations()
 local result = {}
 for i,row in ipairs(ordered) do result[i] = copy(row) end
 return result
end
function grug_home.location(id) return copy(locations[id]) end
function grug_home.get(player)
 local faction = grug_factions.get_faction(player)
 local row = locations[player:get_meta():get_string("grug_home:id")]
 if not row or row.faction ~= faction then
  row = locations[defaults[grug_core.get_player_race(player:get_player_name())]]
 end
 if row and row.faction == faction then return copy(row) end
end

grug_mobs.register_start_socket_role("innkeeper", function(socket, settlement)
 return "grug_mobs:villager_" .. settlement.race_id
end)
dofile(path .. "/travel.lua")
dofile(path .. "/innkeeper.lua")
