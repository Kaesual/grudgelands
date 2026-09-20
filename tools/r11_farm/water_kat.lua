-- Small real-module KAT. Run with LuaJIT; no PUC runtime in Round 11.
local repo = assert(arg[1], "repository path required")
local function check(ok, message) assert(ok, message) end
local nodes, mutations, violations, floods = {}, 0, 0, 0
local loaded, mutation_ok, blocked, installed = true, true, false, true
local mods_loaded, liquid_changed
local core = {registered_nodes = {}, registered_items = {}}
local grug_core = {}
local function key(pos) return pos.x .. "/" .. pos.y .. "/" .. pos.z end
local function node_at(pos) return nodes[key(pos)] or {name = "air", param2 = 0} end
function core.get_node_or_nil(pos) if loaded then return node_at(pos) end end
function core.set_node(pos, node)
 if not mutation_ok then return false end
 nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
 mutations = mutations + 1
 return true
end
core.swap_node = core.set_node
function core.is_protected() return false end
function core.check_player_privs() return false end
function core.record_protection_violation() violations = violations + 1 end
function core.register_on_mods_loaded(fn) mods_loaded = fn end
function core.register_on_liquid_transformed(fn) liquid_changed = fn end
function core.override_item(name, patch)
 for k, v in pairs(patch) do core.registered_nodes[name][k] = v end
end
function core.register_craftitem(name, def) core.registered_items[name] = def end
local recipe
function core.register_craft(def) recipe = def end
function grug_core.zone_authority_installed() return installed end
function grug_core.get_player_faction() return "accord" end
function grug_core.world_protected_for_faction(pos) return pos.x < 0 end
function grug_core.combat_eye_pos() return {x=1,y=1,z=0} end
local grug_zones = {}
function grug_zones.territory_rule_at(pos)
 if pos.x < 0 then return "hard_protected" end
 return "accord_home"
end
local function stack(name)
 local data = {}
 local s = {name = name, count = 1}
 function s:get_count() return self.count end
 function s:get_name() return self.name end
 function s:get_definition() return core.registered_items[self.name] or {} end
 function s:get_meta()
  return {get_string=function(_,k) return data[k] or "" end,
    set_string=function(_,k,v) data[k]=v end}
 end
 return s
end
local env = setmetatable({core=core, grug_core=grug_core,
 grug_zones=grug_zones, ItemStack=stack}, {__index=_G})
local function load(relative)
 setfenv(assert(loadfile(repo .. "/" .. relative)),env)()
end
load("mods/CORE/grug_core/protection.lua")
check(core.is_protected({x=1,y=0,z=0},""), "anonymous player stays protected")
check(grug_core.world_alterable({x=1,y=0,z=0}), "neutral home territory allowed")
check(not grug_core.world_alterable({x=-1,y=0,z=0}), "hard volume protected")
installed=false
check(not grug_core.world_alterable({x=1,y=0,z=0}), "preinstall fail closed")
installed=true
grug_core.register_world_alteration_guard(function() return not blocked end)
blocked=true
check(not grug_core.world_alterable({x=1,y=0,z=0}), "claim guard applied")
blocked=false
core.registered_nodes.air={buildable_to=true, liquidtype="none"}
core.registered_nodes.flower={buildable_to=true, floodable=true,
 on_flood=function() floods=floods+1; return "original result" end}
core.registered_nodes.stone={buildable_to=false}
for _,family in ipairs({"water","river_water","lava"}) do
 for _,kind in ipairs({"source","flowing"}) do
  core.registered_nodes["default:"..family.."_"..kind] = {
    buildable_to=true, liquidtype=kind}
 end
end
load("mods/CORE/grug_core/water_guard.lua")
mods_loaded()
local flood=core.registered_nodes.flower.on_flood
check(flood({x=-1,y=0,z=0},{name="flower"},{name="default:water_flowing"})==true,
 "protected flower flood veto")
check(floods==0,"no original drop callback in protected flower")
check(flood({x=1,y=0,z=0},{name="flower"},{name="default:water_flowing"})=="original result",
 "ordinary original callback preserved")
check(flood({x=-1,y=0,z=0},{name="flower"},{name="default:lava_flowing"})=="original result",
 "lava unchanged by water-only guard")
local p={x=-1,y=0,z=0}
core.set_node(p,{name="default:water_flowing",param2=7})
liquid_changed({p},{{name="air",param2=11}})
check(node_at(p).name=="air" and node_at(p).param2==11,"protected air exact restoration")
core.set_node(p,{name="air"})
liquid_changed({p},{{name="default:river_water_source",param2=2}})
check(node_at(p).name=="default:river_water_source" and node_at(p).param2==2,
 "protected river source exact restoration")
local positions, old = {}, {}
for i=1,1600 do positions[i]={x=-1,y=0,z=i};old[i]={name="air",param2=i%16} end
for pass=1,10 do
 for i=1,#positions do nodes[key(positions[i])]={name="default:water_flowing"} end
 local before=mutations
 liquid_changed(positions,old)
 check(mutations-before==1600,"one restoration per transformed node, 100x16 boundary")
end
load("mods/ITEMS/grug_farming/bucket.lua")
local EMPTY,FILLED="grug_farming:empty_iron_bucket","grug_farming:water_bucket"
local user={}
function user:is_player() return true end
function user:get_player_name() return "tester" end
function user:get_wielded_item() return stack(EMPTY) end
local under={x=1,y=0,z=0}
local above={x=1,y=1,z=0}
local pointed={type="node",under=under,above=above}
local fill=core.registered_items[EMPTY].on_place
local place=core.registered_items[FILLED].on_place
for _,family in ipairs({"water","river_water"}) do
 core.set_node(under,{name="default:"..family.."_source"})
 local full=fill(stack(EMPTY),user,pointed)
 check(full:get_name()==FILLED and node_at(under).name=="air","source fill")
 local empty=place(full,user,pointed)
 check(empty:get_name()==EMPTY and node_at(under).name=="default:"..family.."_source",
 "family-preserving empty/filled exchange")
end
for _,name in ipairs({"default:water_flowing","default:river_water_flowing",
 "default:lava_source","default:lava_flowing"}) do
 core.set_node(under,{name=name})
 local before=mutations
 check(fill(stack(EMPTY),user,pointed):get_name()==EMPTY and mutations==before,
 "flow/lava fill refused")
end
core.set_node(under,{name="default:water_source"})
local before=mutations
blocked=true
check(fill(stack(EMPTY),user,pointed):get_name()==EMPTY and mutations==before,"claim fill refused")
blocked=false
mutation_ok=false
check(fill(stack(EMPTY),user,pointed):get_name()==EMPTY and mutations==before,"failed write preserves bucket")
mutation_ok=true
local full=fill(stack(EMPTY),user,pointed)
mutation_ok=false
check(place(full,user,pointed)==full,"failed placement preserves filled stack")
mutation_ok=true
check(place(stack(FILLED),user,pointed):get_name()==FILLED,"missing family refused")
loaded=false
check(fill(stack(EMPTY),user,pointed):get_name()==EMPTY,"unloaded source refused")
loaded=true
local far={type="node",under={x=999,y=0,z=0},above={x=999,y=1,z=0}}
check(fill(stack(EMPTY),user,far):get_name()==EMPTY,"unreachable source refused")
check(recipe.output==EMPTY and #recipe.recipe==2 and
 recipe.recipe[1][1]=="grug_materials:iron_bar" and recipe.recipe[1][2]=="" and
 recipe.recipe[1][3]=="grug_materials:iron_bar" and
 recipe.recipe[2][2]=="grug_materials:iron_bar","reference V recipe")
check(core.registered_items[EMPTY].stack_max==1 and
 core.registered_items[FILLED].stack_max==1,"single stack swap requires no extra inventory room")
print("R11_WATER_OK guards/flood/16000-boundary-events/bucket-transactions")
