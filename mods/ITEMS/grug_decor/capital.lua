-- Authored service dressing is intrinsically inert. No liquid/plant/fuel
-- groups, inventory or drops: protection is not the no-loot mechanism.
local function deny() return false end
local function zero() return 0 end
local function nothing() end
local function no_drops() return {} end
local function node(id, description, texture, boxes, extra)
 local def={description=description, tiles={texture}, paramtype="light",
  drawtype="nodebox", node_box={type="fixed",fixed=boxes},
  groups={not_in_creative_inventory=1}, drop="", diggable=false,
  can_dig=deny, on_dig=nothing, on_punch=nothing, on_rightclick=nothing,
  on_blast=no_drops, allow_metadata_inventory_put=zero,
  allow_metadata_inventory_take=zero, allow_metadata_inventory_move=zero,
  _grug_capital_display=true}
 for k,v in pairs(extra or {}) do def[k]=v end
 core.register_node("grug_decor:capital_"..id,def)
end
local table_box={{-.5,.1,-.5,.5,.35,.5},
 {-.4,-.5,-.4,-.25,.1,-.25},{.25,-.5,-.4,.4,.1,-.25},
 {-.4,-.5,.25,-.25,.1,.4},{.25,-.5,.25,.4,.1,.4}}
node("counter","Service Counter","default_wood.png",table_box)
node("anvil","Display Anvil","default_steel_block.png",
 {{-.3,-.5,-.3,.3,-.3,.3},{-.16,-.3,-.16,.16,.2,.16},{-.5,.2,-.3,.5,.4,.3}})
node("quench","Quenching Tub","default_wood.png",
 {{-.5,-.5,-.5,.5,-.3,.5},{-.5,-.3,-.5,-.35,.25,.5},
 {.35,-.3,-.5,.5,.25,.5},{-.35,-.3,-.5,.35,.25,-.35},
 {-.35,-.3,.35,.35,.25,.5}})
node("trough","Feed Trough","default_wood.png",table_box)
node("lava","Decorative Forge Embers","default_lava.png",
 {-.5,-.5,-.5,.5,-.35,.5},{light_source=6})
node("bedding","Stable Bedding","default_dry_grass.png",
 {-.5,-.5,-.5,.5,.5,.5})
node("rail","Stable Partition","default_wood.png",
 {{-.08,-.5,-.5,.08,-.2,.5},{-.08,.15,-.5,.08,.35,.5},
 {-.13,-.5,-.13,.13,.5,.13}})
node("loom","Cloth Loom","default_wood.png",
 {{-.5,-.5,-.15,-.35,.5,.15},{.35,-.5,-.15,.5,.5,.15},
 {-.5,.35,-.15,.5,.5,.15},{-.35,-.2,-.05,.35,.35,.05}},
 {drawtype="mesh",mesh="grug_decor_capital_loom.obj",
  tiles={"default_wood.png","wool_white.png"}})
node("cloth","Folded Cloth","wool_white.png",
 {{-.45,-.5,-.4,.45,-.25,.4},{-.35,-.25,-.3,.35,0,.3}})
node("herbs","Herb Display","default_papyrus.png",
 {-.4,-.5,-.4,.4,.4,.4},{drawtype="plantlike",walkable=false,
  use_texture_alpha="clip",sunlight_propagates=true})
node("hides","Drying Hide","default_wood.png",
 {{-.5,-.5,-.1,-.35,.5,.1},{.35,-.5,-.1,.5,.5,.1},
 {-.5,.35,-.1,.5,.5,.1},{-.35,-.15,-.05,.35,.35,.05}},
 {drawtype="mesh",mesh="grug_decor_capital_hides.obj",use_texture_alpha="clip",
  tiles={"default_wood.png","grug_mobs_item_light_leather.png"}})
node("timber","Timber Stack","default_tree.png",
 {{-.5,-.5,-.45,.5,-.15,-.05},{-.5,-.5,.05,.5,-.15,.45},
 {-.5,-.15,-.2,.5,.2,.2}})
node("carving","Carving Bench","default_wood.png",table_box)
node("case","Jeweller's Display Case","default_glass.png",
 {-.5,-.5,-.5,.5,.2,.5},{use_texture_alpha="clip",sunlight_propagates=true})

-- Fixed product plaques use existing shipped item artwork; the enclosing
-- frame/counter is authored by CAP. They have the same no-inventory/no-drop
-- contract as every other capital prop, not a player-editable item frame.
local products = {
 weaponsmith={"Weaponsmith", "grug_gear_item_sword_bronze.png"},
 armorsmith={"Armorsmith", "grug_gear_item_chest_metal_bronze.png"},
 tailor={"Tailor", "grug_gear_item_chest_cloth_patch.png"},
 leatherworker={"Leatherworker", "grug_gear_item_chest_leather_light.png"},
 woodcarver={"Woodcarver", "grug_gear_item_staff_wood.png"},
 goldsmith={"Goldsmith", "default_mese_crystal_fragment.png^[colorize:#4a8bd8:150"},
 alchemist={"Alchemist", "grug_traders_item_potion_healing_weak.png"},
 cooking={"Cooking", "default_clay_lump.png^[colorize:#d8a552:145"},
}
local names={}
for name in pairs(products) do names[#names+1]=name end
table.sort(names)
for _,name in ipairs(names) do
 local product=products[name]
 local front="wool_white.png^("..product[2]..")"
 node("product_"..name,product[1].." Product Display","default_wood.png",
  {-.5,-.5,-.12,.5,.5,.12},{paramtype2="facedir",
   tiles={"default_wood.png","default_wood.png","default_wood.png",
    "default_wood.png",front,front}})
end
