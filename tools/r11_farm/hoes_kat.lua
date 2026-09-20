local repo=assert(arg[1],"repository path required")
local core={registered_items={},registered_nodes={
 ["default:dirt"]={groups={soil=1}},
 ["grug_farming:soil"]={groups={soil=1}},
}}
local nodes,creative,protected,success={},false,false,true
local function key(p) return p.x.."/"..p.y.."/"..p.z end
function core.get_node_or_nil(p) return nodes[key(p)] or {name="air"} end
function core.set_node(p,n) if not success then return false end;nodes[key(p)]=n;return true end
function core.register_tool(n,d) core.registered_items[n]=d end
local recipes={}
function core.register_craft(d) recipes[#recipes+1]=d end
function core.is_protected() return protected end
function core.record_protection_violation() end
function core.is_creative_enabled() return creative end
function core.sound_play() end
local env=setmetatable({core=core,grug_materials={},
 grug_farming={SOIL_DRY="grug_farming:soil",SOIL_WET="grug_farming:soil_wet"}}, {__index=_G})
function core.get_modpath(name) return repo.."/mods/ITEMS/"..name end
function core.get_current_modname() return "grug_materials" end
function env.dofile(path) return setfenv(assert(loadfile(path)),env)() end
env.dofile(repo.."/mods/ITEMS/grug_materials/registry.lua")
local callbacks={start_soil_timer=function() end,soil_timer=function() end}
setfenv(assert(loadfile(repo.."/mods/ITEMS/grug_farming/hoes.lua")),env)()(callbacks)
local function stack(name)
 local values={};local s={wear=0,name=name}
 function s:get_name() return self.name end
 function s:get_wear() return self.wear end
 function s:set_wear(wear) self.wear=wear end
 function s:get_definition() return core.registered_items[self.name] end
 function s:get_meta() return {get_int=function(_,k) return values[k] or 0 end,
  set_int=function(_,k,v) values[k]=v end} end
 return s
end
local user={is_player=function() return true end,get_player_name=function() return "p" end}
local below,above={x=0,y=0,z=0},{x=0,y=1,z=0}
local point={type="node",under=below,above=above}
local count=0
for name,def in pairs(core.registered_items) do
 count=count+1
 local s=stack(name)
 for n=1,def._grug_hoe_uses do
  nodes[key(below)]={name="default:dirt"}
  def.on_use(s,user,point)
  assert(nodes[key(below)].name=="grug_farming:soil","conversion failed")
  assert((s.wear==65535)==(n==def._grug_hoe_uses),"wrong authored lifetime "..name)
 end
 nodes[key(below)]={name="default:dirt"}
 assert(def.on_use(s,user,point)==s and s:get_name()==name and
  nodes[key(below)].name=="default:dirt","broken hoe must stay/refuse")
 s:set_wear(0) -- a repair resets the bar; stale fractional metadata cannot leak
 def.on_use(s,user,point)
 assert(s.wear==math.floor(65535/def._grug_hoe_uses),"repaired remainder leaked")
 local before=s.wear
 def.on_use(s,user,point)
 assert(s.wear==before,"already tilled soil spent wear")
 nodes[key(below)]={name="default:dirt"};creative=true
 def.on_use(s,user,point);creative=false
 assert(s.wear==before,"Creative spent wear")
 nodes[key(below)]={name="default:dirt"};protected=true
 def.on_use(s,user,point);protected=false
 assert(s.wear==before and nodes[key(below)].name=="default:dirt","protection failed")
 success=false;def.on_use(s,user,point);success=true
 assert(s.wear==before,"failed node mutation spent wear")
end
assert(count==7 and #recipes==14,"seven hoe/two layout catalog")
print("R11_HOES_OK seven-exact-lifetimes/broken-preservation/repair/Creative/protection")
