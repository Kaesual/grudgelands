local root=arg[1] or "."
local objects, players, steps={}, {}, {}
local scans=0
core={registered_entities={},register_entity=function(n,d) core.registered_entities[n]=d end,
 register_globalstep=function(f) steps[#steps+1]=f end,
 get_connected_players=function() scans=scans+1;return players end,
 get_player_by_name=function(n) for _,p in ipairs(players) do if p.name==n then return p end end end,
 register_on_player_receive_fields=function() end,register_on_leaveplayer=function() end}
local function object(pos)
 local o={pos=pos,valid=true,properties={},observers=nil}
 function o:is_valid() return self.valid end
 function o:get_pos() return self.pos end
 function o:get_properties() return self.properties end
 function o:set_properties(p) for k,v in pairs(p) do self.properties[k]=v end end
 function o:get_luaentity() return self.entity end
 function o:set_observers(set) self.observers={};for k,v in pairs(set) do self.observers[k]=v end end
 function o:set_attach(parent) self.parent=parent end
 function o:get_attach() return self.parent end
 function o:remove() self.valid=false end
 return o
end
function core.add_entity(pos,name)
 local o=object(pos);local def=assert(core.registered_entities[name])
 o.entity={object=o,name=name}; o:set_properties(def.initial_properties)
 if def.on_activate then def.on_activate(o.entity) end
 assert(o.observers and next(o.observers)==nil,"child must activate with empty observer set")
 objects[#objects+1]=o;return o
end
local p={name="alice",pos={x=24,y=0,z=0}}
function p:get_player_name() return self.name end
function p:get_pos() return self.pos end
players[1]=p
grug_core={}
grug_quests={registered_npcs={elder={settlement="home",socket="elder"}},npc_by_socket={["home/elder"]="elder"}}
local state="available"
function grug_quests.npc_quests() return {{status=state}} end
dofile(root.."/mods/CORE/grug_core/tag_carrier.lua")
dofile(root.."/mods/PLAYER/grug_quests/npc.lua")
local parent=object({x=0,y=0,z=0})
parent.entity={object=parent,_grug_start="home",_grug_socket="elder"}
local carrier=assert(grug_core.create_tag_carrier(parent))
steps[1](1)
assert(scans==1 and carrier.observers.alice)
local function visible(mesh)
 local n=0
 for _,o in ipairs(objects) do if o.valid and o.properties.mesh==mesh and o.observers.alice then n=n+1 end end
 return n
end
assert(visible("grug_quests_exclamation.obj")==1)
state="ready";p.pos.x=29;steps[1](1)
assert(scans==2 and carrier.observers.alice)
assert(visible("grug_quests_question.obj")==1 and visible("grug_quests_exclamation.obj")==0)
p.pos.x=31;steps[1](1)
assert(not carrier.observers.alice and visible("grug_quests_question.obj")==0)
p.pos.x=27;steps[1](1);assert(not carrier.observers.alice)
p.pos.x=24;steps[1](1);assert(carrier.observers.alice)
grug_core.remove_tag_carrier(carrier)
for _,o in ipairs(objects) do assert(not o.valid,"marker child survives carrier removal") end
assert(scans==5)
print("r14-quests-visibility: PASS original meshes, empty activation observers, shared25/30 hysteresis, live state refresh, child cleanup, one player scan")
