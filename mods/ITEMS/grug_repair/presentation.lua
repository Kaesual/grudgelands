-- Same normalized lifetime as the authoritative wear writers. Remainders
-- represent sub-wear units, not additional whole wear points.
function grug_repair.maximum_durability(stack)
 local def = stack:get_definition() or {}
 if def._grug_tool_uses then return def._grug_tool_uses end
 if def._grug_hoe_uses then return def._grug_hoe_uses end
 local tier = tonumber(def._grug_bracket or def._grug_tier) or 1
 return ({1000, 1500, 2000, 2500, 3000, 4000})[tier] or 4000
end

function grug_repair.durability(stack)
 if not grug_repair.eligible(stack) then return nil end
 local maximum = grug_repair.maximum_durability(stack)
 if grug_core.equipment_is_broken(stack) then return 0, maximum end
 local remainder = stack:get_meta():get_int("_grug_wear_remainder")
 local numerator = (65535 - stack:get_wear()) * maximum - remainder
 return math.max(0, math.min(maximum, math.ceil(numerator / 65535))), maximum
end

function grug_repair.durability_line(stack)
 local remaining, maximum = grug_repair.durability(stack)
 if not remaining then return nil end
 return ("Durability: %d / %d"):format(remaining, maximum) ..
  (grug_core.equipment_is_broken(stack) and " — Broken" or "")
end

function grug_repair.broken_image(image)
 if not image or image == "" then return image end
 return grug_gear.broken_image(image)
end

-- Remember only the original overrides while broken. Compare against our last
-- rendering so an intentional new enchant image replaces, rather than stacks
-- on, the old cracks. Empty originals restore the current definition default.
function grug_repair.refresh_appearance(stack)
 if not grug_repair.eligible(stack) then return false end
 local meta, def = stack:get_meta(), stack:get_definition() or {}
 local broken = grug_core.equipment_is_broken(stack)
 local changed = false
 for _, key in ipairs({"inventory_image", "wield_image"}) do
  local saved_key, drawn_key = "_grug_broken_base_" .. key, "_grug_broken_drawn_" .. key
  local current, drawn = meta:get_string(key), meta:get_string(drawn_key)
  if broken then
   local base = current
   if drawn ~= "" and current == drawn then base = meta:get_string(saved_key) end
   local image = base
   if image == "" then image = def[key] or "" end
   if type(image) == "table" then image = image.name or "" end
   if image == "" and key == "wield_image" then
    image = meta:get_string("_grug_broken_base_inventory_image")
    if image == "" then image = def.inventory_image or "" end
   end
   local desired = grug_repair.broken_image(image)
   if current ~= desired then meta:set_string(key, desired); changed = true end
   meta:set_string(saved_key, base)
   meta:set_string(drawn_key, desired)
  elseif drawn ~= "" then
   if current == drawn then
    meta:set_string(key, meta:get_string(saved_key)); changed = true
   end
   meta:set_string(saved_key, "")
   meta:set_string(drawn_key, "")
  end
 end
 return changed
end

function grug_repair.decorate_description(stack, description)
 if not grug_repair.eligible(stack) then return description end
 local lines = {}
 for line in tostring(description):gmatch("[^\n]+") do
  if not line:match("^Durability:") and not line:match("^Usable by:") and
    not line:match("^%d+ uses$") then lines[#lines + 1] = line end
 end
 lines[#lines + 1] = grug_gear.usable_by(stack)
 lines[#lines + 1] = grug_repair.durability_line(stack)
 return table.concat(lines, "\n")
end

function grug_repair.refresh_stack(stack, player)
 local before = stack:to_string()
 grug_repair.refresh_appearance(stack)
 if player then grug_gear.initialize_weapon_tooltip(stack, player)
 else
  grug_items.regenerate_description(stack)
 end
 local meta = stack:get_meta()
 local description = meta:get_string("description")
 if description == "" then description = (stack:get_definition() or {}).description or "" end
 meta:set_string("description", grug_repair.decorate_description(stack, description))
 return stack:to_string() ~= before
end
