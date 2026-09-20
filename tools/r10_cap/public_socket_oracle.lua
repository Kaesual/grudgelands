-- Architectural fixtures distinguish authored workstation nodes from NPC feet.
-- The exception is closed over the decided seven station identifiers/nodes.
local nodes={forge="grug_jobs:forge",brewing_stand="grug_brewing:brewing_stand",
 tailor_bench="grug_jobs:tailor_bench",tanning_rack="grug_jobs:tanning_rack",
 carving_bench="grug_jobs:carving_bench",jewellers_bench="grug_jobs:jewellers_bench",
 furnace="default:furnace"}
return function(socket,name)
 if socket.role~="public_station" then return false end
 local station=socket.tags and socket.tags[1]
 assert(nodes[station] and nodes[station]==name,
  "authored public station socket/node differs: "..tostring(socket.id))
 return true
end
