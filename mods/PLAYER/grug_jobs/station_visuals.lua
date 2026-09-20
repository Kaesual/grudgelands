-- Appearance only; station inventory/access/recipe behavior stays factory-owned.
-- VoxeLibre anvil silhouette: mods/ITEMS/mcl_anvils/init.lua:383-391.
local anvil = {
 {-6/16,-8/16,-6/16,6/16,-4/16,6/16},
 {-5/16,-4/16,-4/16,5/16,-3/16,4/16},
 {-4/16,-3/16,-2/16,4/16,2/16,2/16},
 {-8/16,2/16,-5/16,8/16,8/16,5/16},
}
local top="grug_jobs_anvil_top.png^[transformR90"
local base="grug_jobs_anvil_base.png"
local side="grug_jobs_anvil_side.png"
return {
 forge={tiles={top,base,side},boxes=anvil,groups={cracky=2},
  sounds=default.node_sound_metal_defaults},
 jewellers_bench={tiles={top.."^[colorize:#c7a45b:120",base,side},
  boxes=anvil,groups={cracky=2},sounds=default.node_sound_metal_defaults},
 tailor_bench={tiles={"grug_jobs_loom_top.png","grug_jobs_loom_bottom.png",
  "grug_jobs_loom_side.png","grug_jobs_loom_side.png",
  "grug_jobs_loom_side.png","grug_jobs_loom_front.png"},
  boxes={{-0.5,-0.5,-0.5,0.5,0.5,0.5}},groups={choppy=2},
  sounds=default.node_sound_wood_defaults},
 carving_bench={texture="default_wood.png",boxes={
  {-0.5,0.25,-0.45,0.5,0.4,0.45},
  {-0.43,-0.5,-0.38,-0.31,0.25,-0.26},
  {0.31,-0.5,-0.38,0.43,0.25,-0.26},
  {-0.43,-0.5,0.26,-0.31,0.25,0.38},
  {0.31,-0.5,0.26,0.43,0.25,0.38},
 },groups={choppy=2},sounds=default.node_sound_wood_defaults},
}
