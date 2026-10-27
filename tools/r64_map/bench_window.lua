-- Reuse the window fixture's engine stand-ins, then measure the real seed roster.
-- luajit tools/r64_map/bench_window.lua CODE_TREE HARNESS_TREE ROSTER
local tree,harness,roster_path=assert(arg[1]),assert(arg[2]),assert(arg[3])
local file=assert(io.open(harness .. "/tools/r44_mq/portable_test.lua","rb"))
local source=file:read("*a");file:close()
local cut=assert(source:find("W.window_size = window_size",1,true))
source=source:sub(1,cut+#"W.window_size = window_size"-1)
local at=assert(source:find('rawset(_G, "grug_map", {atlas',1,true))
local inject=([[
local roster=assert(loadfile(%q))()
settlements,sockets=roster.settlements,roster.sockets
grug_quests.registered_npcs=roster.npcs
local all_states={};for id in pairs(roster.npcs) do all_states[id]="available" end
grug_quests.marker_states=function() return all_states,1 end
grug_core.start_identities=function() return roster.identities end
grug_home.locations=function() return roster.homes end
for _,list in pairs(sockets) do for _,s in ipairs(list) do
 if s.profession then grug_jobs.PROFESSIONS[s.profession]={name=s.profession} end
end end
grug_mobs.dragon_map_markers=function() return roster.dragons end
]]):format(roster_path)
source=source:sub(1,at-1)..inject..source:sub(at)
source=source .. "\n" .. [[
local viewer=make_player("ann",{x=0,z=-1500},"accord")
local info={size={x=1920,y=1080},max_formspec_size={x=1920/72,y=1080/72},real_hud_scaling=1,real_gui_scaling=1}
for _,layer in ipairs({"quests","bosses","trainers","towns","pois","pvp","none"}) do
 for _,zoom in ipairs({1,2,4,8}) do
  local state=W.new_state();state.layer=layer;state.zoom=zoom
  local start=os.clock();local form=W.formspec(viewer,state,info)
  local elapsed=(os.clock()-start)*1e6
  local _,tips=form:gsub("tooltip%[","")
  print(("%s zoom=%d bytes=%d tooltips=%d CPU_us=%.0f"):format(layer,zoom,#form,tips,elapsed))
 end
end
]]
arg[1]=tree
assert(loadstring(source,"r64-window-stand-in"))()
