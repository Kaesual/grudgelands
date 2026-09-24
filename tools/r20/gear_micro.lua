-- Invoked inside the real r13 enchant/catalog fixture, with its engine doubles.
-- No independent runtime entrypoint: included in the round's final digest pair.
return function(repo, definitions, check)
 local classes = {"warrior", "scout", "mage", "priest"}
 local permitted = {
  warrior={sword=true, dagger=true, greataxe=true},
  scout={bow=true, sword=true, dagger=true},
  mage={staff=true, wand=true, dagger=true},
  priest={staff=true, wand=true, dagger=true},
 }
 grug_classes.get_class = function(player) return player.class end
 local cases = 0
 for _, class in ipairs(classes) do
  for _, family in ipairs({"sword", "dagger", "greataxe", "bow", "staff", "wand"}) do
   for tier = 1, 6 do
    local stack = ItemStack(grug_gear.weapon_item(family, tier))
    check(grug_gear.can_equip_weapon({class=class}, stack) ==
     (permitted[class][family] == true), "weapon permission matrix")
    local text = grug_gear.usable_by(stack)
    check(text:find("Usable by:", 1, true) == 1, "stable permission tooltip")
    cases = cases + 1
   end
  end
 end
 local axe = grug_items.POOLS.greataxe
 check(table.concat(axe, ",") == "str,attack_speed_percent,crit_percent,max_hp_percent",
  "Battle Axe pool must exclude Dex/Mana")
 check(table.concat(grug_items.POOLS.dagger, ",") ==
  "str,dex,int,attack_speed_percent,crit_percent,max_hp_percent,max_mana_percent",
  "shared dagger pool")
 for _, class in ipairs(classes) do
  check(grug_gear.can_equip_weapon({class=class}, ItemStack(grug_gear.weapon_item("dagger", 1))),
   "dagger universal permission")
 end

 grug_repair = {}
 dofile(repo .. "/mods/ITEMS/grug_repair/service.lua")
 dofile(repo .. "/mods/ITEMS/grug_repair/presentation.lua")
 grug_core.equipment_is_broken = function(stack) return stack:get_wear() >= 65535 end
 for _, tier in ipairs({1, 3, 6}) do
  local stack = ItemStack(grug_gear.weapon_item("sword", tier))
  local remaining, maximum = grug_repair.durability(stack)
  check(remaining == maximum, "new weapon durability")
  local wear = math.floor(65535 / maximum)
  stack:set_wear(wear)
  stack:get_meta():set_int("_grug_wear_remainder", 65535 % maximum)
  check(grug_repair.durability(stack) == maximum - 1, "exact first fixed-cost use")
  local amount = (maximum - 1) * 65535
  stack:set_wear(math.floor(amount / maximum))
  stack:get_meta():set_int("_grug_wear_remainder", amount % maximum)
  check(grug_repair.durability(stack) == 1, "exact last fixed-cost use")
  stack:set_wear(65535)
  check(grug_repair.durability(stack) == 0, "broken durability")
 end
 for _, key in ipairs({"_grug_tool_uses", "_grug_hoe_uses"}) do
  definitions["test:durability_tool"] = {description="Test tool", type="tool",
   groups={pickaxe=1}, [key]=300, inventory_image="tool.png"}
  local stack = ItemStack("test:durability_tool")
  stack:set_wear(1)
  check(grug_repair.durability(stack) == 300, "positive fractional remainder rounds up")
  stack:set_wear(218)
  stack:get_meta():set_int("_grug_wear_remainder", 135)
  check(grug_repair.durability(stack) == 299, "normalized tool/hoe exact event")
 end

 local stack = ItemStack(grug_gear.weapon_item("dagger", 6))
 local meta = stack:get_meta()
 meta:set_string("inventory_image", "custom.png^[multiply:#ff8899")
 meta:set_string("wield_image", "custom_wield.png^[resize:64x64")
 meta:set_string("grug_ench", core.serialize({{channel="prefix", stat="int", value=6, tier=6}}))
 stack:set_wear(65535)
 grug_items.regenerate_description(stack)
 local icon, wield = meta:get_string("inventory_image"), meta:get_string("wield_image")
 check(icon == "(custom.png^[multiply:#ff8899)^[cracko:1:4", "cracked custom inventory image")
 check(wield == "(custom_wield.png^[resize:64x64)^[cracko:1:4", "cracked custom wield image")
 check(meta:get_string("description"):find("Broken", 1, true), "broken tooltip")
 grug_items.regenerate_description(stack)
 check(meta:get_string("inventory_image") == icon and meta:get_string("wield_image") == wield,
  "repeat refresh accumulated cracks")
 meta:set_string("inventory_image", "new_enchant.png^[multiply:#88ff99")
 grug_items.regenerate_description(stack)
 stack:set_wear(0)
 grug_items.regenerate_description(stack)
 check(meta:get_string("inventory_image") == "new_enchant.png^[multiply:#88ff99" and
  meta:get_string("wield_image") == "custom_wield.png^[resize:64x64", "repair restores current enchant art")
 check(not meta:get_string("description"):find("Broken", 1, true), "repair clears broken label")
 check(grug_items.get_affixes(stack)[1].stat == "int", "refresh converted fixed enchant")
 local ordinary = ItemStack(grug_gear.weapon_item("sword", 1))
 ordinary:set_wear(65535)
 grug_repair.refresh_appearance(ordinary)
 ordinary:set_wear(0)
 grug_repair.refresh_appearance(ordinary)
 check(ordinary:get_meta():get_string("inventory_image") == "" and
  ordinary:get_meta():get_string("wield_image") == "", "repair restores definition image fallback")

 for name, def in pairs(definitions) do
  local groups = def.groups or {}
  if (groups.grug_armor_class or 0) > 0 and name:find("grug_gear:", 1, true) == 1 then
   local caps = def.tool_capabilities or {}
   check(def.type == "tool" and next(caps.groupcaps) == nil and
    caps.damage_groups.fleshy == 0 and not groups.grug_equip_weapon,
    "native wearable bars must not grant attack/dig/weapon capabilities")
  end
 end
 grug_visuals = {}
 dofile(repo .. "/mods/PLAYER/grug_visuals/compose.lua")
 grug_visuals.index_armor(definitions)
 local chest = grug_gear.armor_item("chest", "cloth", 1)
 local intact = grug_visuals.compose({race="human", armor={chest=chest}})
 local broken = grug_visuals.compose({race="human", armor={chest=chest}, armor_broken={chest=true}})
 check(intact.key ~= broken.key and not intact.textures[1]:find("cracko", 1, true),
  "armor break cache key")
 check(broken.textures[1]:find("grug_visuals_skin_human.png^((grug_visuals_", 1, true) == 1 and
  broken.textures[1]:find("^[cracko:1:4)", 1, true), "cracks belong inside armor layer")
 check(grug_visuals.compose({race="human", armor={chest=chest}}) == intact,
  "armor repair returns intact composition")

 -- Load the real derived-stat functions after enchant checks so this cannot
 -- disturb the fixture's existing aggregate setup.
 grug_core.register_on_status_modifiers_changed = function() end
 grug_xp.register_on_level_change = function() end
 dofile(repo .. "/mods/PLAYER/grug_classes/stats.lua")
 grug_classes.get_attributes = function() return {str=30, dex=80, int=90} end
 for _, class in ipairs(classes) do
  check(grug_classes.get_melee_bonus({class=class}) == (class == "scout" and 8 or 3),
   "Scout melee Dex; other classes Strength")
 end
 check(grug_classes.get_spell_power_bonus({class="mage"}) == 9,
  "caster dagger keeps Intelligence spell scaling")
 dofile(repo .. "/tools/r20/gear_boundary.lua")(repo, check)
 return "PASS r20 gear permissions=144 pools durability fractions broken-art repair armor-layer scout-dex real-equip wear-service-cache\n"
end
