-- Item-family permissions are independent of the current tooltip viewer.
local CLASS_WEAPONS = {
 warrior = {sword=true, dagger=true, greataxe=true},
 scout = {bow=true, sword=true, dagger=true},
 mage = {staff=true, wand=true, dagger=true},
 priest = {staff=true, wand=true, dagger=true},
}
local CLASS_ORDER = {"warrior", "scout", "mage", "priest"}
local CLASS_NAMES = {warrior="Warrior", scout="Scout", mage="Mage", priest="Priest"}

function grug_gear.weapon_family(stack)
 local def = stack:get_definition() or {}
 local groups = def.groups or {}
 if (groups.grug_equip_weapon or 0) <= 0 then return nil end
 if def._grug_weapon_family then return def._grug_weapon_family end
 for _, family in ipairs({"bow", "staff", "wand", "sword"}) do
  if (groups[family] or 0) > 0 then return family end
 end
 return nil
end

function grug_gear.can_equip_weapon(player, stack)
 local family = grug_gear.weapon_family(stack)
 local allowed = CLASS_WEAPONS[grug_classes.get_class(player)]
 return family ~= nil and allowed ~= nil and allowed[family] == true
end

function grug_gear.usable_by(stack)
 local def = stack:get_definition() or {}
 local groups = def.groups or {}
 local family = grug_gear.weapon_family(stack)
 local rank = groups.grug_armor_class or 0
 local names = {}
 for _, class in ipairs(CLASS_ORDER) do
  local armor_rank = class == "warrior" and 3 or class == "scout" and 2 or 1
  if (family and CLASS_WEAPONS[class][family]) or
    (not family and (groups.grug_equip_weapon or 0) == 0 and rank <= armor_rank) then
   names[#names + 1] = CLASS_NAMES[class]
  end
 end
 return "Usable by: " .. (#names == 4 and "All classes" or
  (#names > 0 and table.concat(names, ", ") or "No class"))
end

-- Opaque pixels only: transparent silhouettes stay transparent.
function grug_gear.broken_image(image)
 if not image or image == "" then return image end
 return "(" .. image .. ")^[cracko:1:4"
end
