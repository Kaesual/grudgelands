local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)

I_have_hands = {}

I_have_hands.indicator_delay = 20 * 3 -- Three-ish seconds

-- local mod_storage = core.get_mod_storage()

I_have_hands.allow_all = false                          --default for only nodes with inventories

local RayDistance = 2.2;                                --- best for this to be shorted than the player's reach
local hand_range = core.registered_items[""].range or 4 --- is 4 the default engine hand reach?

--invs to block
local blacklist = {
  --voxelibre
  "mcl_chests:shulker_box",
  "mcl_core:bedrock",
  "mcl_portals:end_portal_frame",
  "mcl_portals:portal",
  "mcl_flowers:_top",
  "mcl_beds:bed",
  "any:_door",
  --age of mending
  "aom_cooking:_top",
} --if the name contains any of

---@class holder
---@field inv table
---@field node table
---@field pressed_button boolean
---@field node_timer number
---@field held boolean
I_have_hands.Player_data = {}

dofile(mod_path .. "/utils.lua")
-- dofile(mod_path .. "/menu.lua")
dofile(mod_path .. "/data.lua")
dofile(mod_path .. "/commands.lua")
dofile(mod_path .. "/x_player_api_compat.lua")

---@class Animate
---@field player table The damn player
---@field rotation integer Not sure if this is vector
---@field object table Is this a table?
---@field frame integer Not sure if frame is the correct term here
---@field item_name string This is probabliy the only thing that is correct
local to_animate = {}

--what do i need?
-- held inv data
-- player_name
-- pressed_button boolean

---comment
---@param player_name string
---@return holder
local function getPlayerData(player_name)
  I_have_hands.Player_data[player_name] = I_have_hands.Player_data[player_name] or {}
  return I_have_hands.Player_data[player_name]
end

local function isBlacklisted(pos)
  for _, v in ipairs(blacklist) do
    -- if core.get_node(pos).name == v then
    --   return true
    -- end
    -- if utils.StringContains(core.get_node(pos).name, v) then
    --   return true
    -- end
    local b_node = utils.Split(v, ":")
    local node_name = core.get_node(pos).name
    if string.find(node_name, b_node[1]) or b_node[1] == "any" then
      if string.find(node_name, b_node[2]) then
        return true
      end
    end
  end
  return false
end

---@param pos table
---@param player_name string
---@return boolean
local function checkProtection(pos, player_name)
  local protected = core.is_protected(pos, player_name)
  local owner = core.get_meta(pos):get_string("owner")
  if owner ~= "" then
    if owner ~= player_name then
      core.chat_send_player(player_name, core.colorize("pink", "You are not the owner."))
      return true
    end
  end
  if protected then
    core.chat_send_player(player_name, core.colorize("pink", "This is protected"))
    return true
  end
  return false
end

local function runCompat(pos)
  -- core.log("compatibility stuff")
  local node = core.get_node(pos)
  local node_meta = core.get_meta(pos)
  local node_def = core.registered_nodes[node.name]
  local mod_origin = node_def.mod_origin

  -- -- MCL_FURANCE set the XP to zero
  -- if node_meta:get_int("xp") > 0 then
  --   node_meta:set_int("xp", 0)
  -- end

  --NOTE(COMPAT): this adds support for the storage_drawers mod
  if core.get_modpath("drawers") and drawers then
    if mod_origin == "drawers" then
      drawers.spawn_visuals(pos)
    end
  end

  --NOTE(COMPAT): pipeworks update pipe, on pickup
  if core.get_modpath("pipeworks") and pipeworks then
    -- if mod_origin == "pipeworks" then
    pipeworks.after_place(pos)
    -- end
  end

  --NOTE(COMPAT): armor_stand(voxelibre & mineclonia) on place down
  if core.get_modpath("mcl_armor_stand") then
    if mod_origin == "mcl_armor_stand" then
      -- core.log("yes armor")
      if core.get_modpath("mcl_armor") and mcl_armor then
        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 0)) do
          local luaentity = obj:get_luaentity()
          if luaentity and luaentity.name == "mcl_armor_stand:armor_entity" then
            -- luaentity:update_armor()
            mcl_armor.update(luaentity.object)
          end
        end
      end
    end
    --should make the armor stand update it visual.
  end
end


---will attach / remove the carry entity to the player
---@param pos any
---@param p_ref any
---@param p_data holder
---@param pickup boolean
function I_have_hands.carry_entity(pos, p_ref, p_data, pickup)
  if pickup == true then
    local node_item = p_data.node.name
    local node_def = core.registered_nodes[node_item]

    ---NOTE(COMPAT): voxelibre chests
    if node_def.mod_origin == "mcl_chests" then
      if node_def.drop ~= "" then
        node_item = node_def.drop
      end
    end

    local held = core.add_entity(pos, "i_have_hands:held")
    held:set_properties({
      wield_item = node_item
    })
    -- held:set_properties({ wield_item = p_data.node.name })
    -- held:set_properties({ visual_size = { x = 0.65, y = 0.65, z = 0.65 } })

    ---carry entity size and adjust bone to look like holding
    if core.get_modpath("core_player") and core_player then
      held:set_properties({ visual_size = { x = 0.04, y = 0.04, z = 0.04 } })
      held:set_attach(p_ref, "", vector.new(0, 1, 0.5), vector.new(0, 0, 0), true)
    else
      held:set_properties({ visual_size = { x = 0.35, y = 0.35, z = 0.35 } })
      held:set_attach(p_ref, "Body", vector.new(0, 4, -3.5), vector.new(0, 0, 0), true)
      p_ref:set_bone_override("Arm_Right",
        { rotation = { absolute = false, interpolation = 0, vec = { x = math.rad(45), y = 0, z = 0 } } })
      p_ref:set_bone_override("Arm_Left",
        { rotation = { absolute = false, interpolation = 0, vec = { x = math.rad(45), y = 0, z = 0 } } })
    end
    p_data.held = true
  else
    for _, obj in pairs(p_ref:get_children()) do
      local obj_name = obj:get_luaentity().name
      if obj_name == "i_have_hands:held" then
        obj:remove()
      end
    end

    ---reset arm bones
    if core.get_modpath("core_player") and core_player then
    else
      p_ref:set_bone_override("Arm_Right",
        { rotation = { absolute = false, interpolation = 0, vec = { x = 0, y = 0, z = 0 } } })
      p_ref:set_bone_override("Arm_Left",
        { rotation = { absolute = false, interpolation = 0, vec = { x = 0, y = 0, z = 0 } } })
    end
  end
  -- local ghost = core.add_entity(pos, "i_have_hands:ghost")
  -- ghost:set_rotation({ x = obj_rot.x, y = obj_rot.y + math.rad(-90), z = obj_rot.z })
  -- ghost:set_animation({ x = 0/24, y = 50/24}, 4, 0, false)
  Data.save_data()
end

---comment
---@param p_name string
---@param pointed_thing table
function I_have_hands.pickupInv(p_name, pointed_thing)
  local pos = pointed_thing.under
  local meta = core.get_meta(pos)
  local p_data = getPlayerData(p_name)
  local node = core.get_node(pos)
  -- core.log("interacted node: " .. core.colorize("#932222", dump(node)))
  local inv = meta:get_inventory()
  local at_least_one = 0

  ---this is where the option to allow pickup up normal nodes should be done
  if I_have_hands.allow_all == false then
    if inv ~= nil then
      -- core.log(core.colorize("#954823", "node: " .. node.name))
      for inv_name, inv_content in pairs(inv:get_lists()) do
        at_least_one = at_least_one + 1
        -- core.log("inv: " .. dump(inv_name))
      end
    end

    if at_least_one <= 0 then
      return
    end
  end

  --- check for protection
  if checkProtection(pos, p_name) then
    return
  end

  -- local node_def = core.registered_nodes[node.name]
  p_data.node = node
  p_data.inv = meta:to_table()
  local timer = core.get_node_timer(pos):get_timeout()
  if timer < 0 then
    timer = 1.0
  end
  p_data.node_timer = timer
  p_data.held = true

  local node_def = core.registered_nodes[node.name]
  -- core.log("mod_origin: "..node_def.mod_origin)
  ---FIXME: if mod_origin is age of mending need to switch to swap node
  if node_def.mod_origin == "aom_storage" or
      node_def.mod_origin == "mcl_armor_stand"
  then
    core.swap_node(pos, { name = "air" })
  else
    core.remove_node(pos)
  end

  I_have_hands.carry_entity(pos, core.get_player_by_name(p_name), p_data, true)

  -- core.set_node(pos,{ name = "air", param1 = p_data.node.param1, param2 = p_data.node.param2 })
  Data.save_data()
  core.sound_play({ name = "i_have_hands_pickup_node" },
    { pos = pos, pitch = math.random(0.7, 1.2), gain = 1 }, true)
  runCompat(pos)

  -- core.add_item(pos, ItemStack(node.name))
  -- end
end

function I_have_hands.putDownInv(p_name, pointed_thing)
  local p_data = getPlayerData(p_name)
  local p_ref = core.get_player_by_name(p_name)

  --FIXME: make sure spot is empty
  ---make sure node can be placed down
  local node_in_pos = core.get_node(pointed_thing.above)
  local node_in_pos_def = core.registered_nodes[node_in_pos.name]
  if node_in_pos_def.buildable_to then
    ---FIXME: why is the new_drop_pos not gettng the correct node??
  elseif node_in_pos.name ~= "air" then
    ---lets try the spot above, specificly when above & under are the same
    --- mainly for when the player is forced to drop the inv
    local new_drop_pos = pointed_thing.under
    if pointed_thing.above == pointed_thing.under then
      new_drop_pos = { pointed_thing.above.x, pointed_thing.above.y + 1, pointed_thing.above.z }
      -- core.log("drop pos: " .. dump(new_drop_pos))
      node_in_pos = core.get_node(new_drop_pos)
      ---set pointed_thing again
      pointed_thing = { type = "node", under = new_drop_pos, above = new_drop_pos }
      node_in_pos_def = core.registered_nodes[node_in_pos.name]
    end
    if node_in_pos_def.buildable_to then
      --- ok good to go
    elseif node_in_pos.name ~= "air" then
      return
    end
    -- core.log("not air")
  end

  --NOTE: the rotation
  -- p_data.node.param2 = core.dir_to_fourdir(p_ref:get_look_dir())

  --- check for protection
  if checkProtection(pointed_thing.above, p_name) then
    return
  end

  if p_data.node == nil then
    return
  end
  local stack, placed_pos = core.item_place_node(ItemStack(p_data.node.name), p_ref, pointed_thing)

  -- core.set_node(pos, { name = p_data.node.name, param1 = p_data.node.param1, param2 = p_data.node.param2 })

  local meta = core.get_meta(placed_pos)
  if meta ~= nil then
    meta:from_table(p_data.inv)
    ---NOTE(COMPAT): voxelibre/ furnace drops xp on brake. so set it to zero on place.
    if meta:get_float("xp") ~= "" then
      meta:set_float("xp", 0)
    end
  end

  --- make sure its been placed
  -- local check_node = core.get_node(pointed_thing.above)
  -- if check_node.name ~= p_data.node.name then
  --   core.log("node name: " .. check_node.name)
  --   core.log("something went wrong")
  --   core.log("pointed_thing: " .. dump(pointed_thing))
  --   core.log("item_place_node: " .. dump(placed_pos))
  --   core.log("is player nil? " .. dump(p_ref))
  --   Data.save_data()
  --   return
  -- end

  runCompat(placed_pos)

  local node_def = core.registered_nodes[p_data.node.name]
  if node_def ~= nil then
    if node_def.on_timer ~= nil and p_data.node_timer ~= nil then
      local node_timer = core.get_node_timer(placed_pos)
      if node_timer:is_started() == false then
        -- core.log("starting node timer..")
        node_timer:start(p_data.node_timer)
        -- node_timer:start(p_data.node_timer:get_timeout())
      end
    end
  end


  I_have_hands.carry_entity(placed_pos, p_ref, p_data, false)

  -- I_have_hands.spawn_ghost(pointed_thing.above,p_data)

  ---FIXME: these may need to be canceled, so check for that
  core.sound_play({ name = "i_have_hands_place_down_node" },
    { pos = placed_pos, pitch = math.random(0.7, 1.2), gain = 1 },
    true)
  p_data.node = nil
  p_data.node_timer = nil
  p_data.inv = nil -- clear it
  p_data.held = false
  Data.save_data()
end

-- core.register_on_leaveplayer(function(player_ref, timed_out)
--   local p_name = player_ref:get_player_name()
--   local p_data = getPlayerData(p_name)
--   local p_pos = player_ref:get_pos()
--   if p_data.inv ~= nil then
--     I_have_hands.putDownInv(p_name, p_pos)
--   end
-- end)

core.register_on_dieplayer(function(player_ref, reason)
  local p_name = player_ref:get_player_name()
  local p_data = getPlayerData(p_name)
  local p_pos = player_ref:get_pos()
  p_pos = vector.new(math.floor(p_pos.x + 0.5), math.floor(p_pos.y + 0.5), math.floor(p_pos.z + 0.5))
  if p_pos == nil then
    return
  end
  local place_pos = vector.new(p_pos.x, p_pos.y, p_pos.z)
  if p_data.inv ~= nil then
    local pointed_thing = { type = "node", under = place_pos, above = place_pos }
    I_have_hands.putDownInv(p_name, pointed_thing)
  end
end)


--- INDICATOR
---@class player_hud
---@field hud_delay number
local player_hud_id = {}

local function getPlayerHud(player_name)
  -- core.debug("player_huds are " .. #player_hud_id .. " in length.")
  for _, ph in ipairs(player_hud_id) do
    if ph.player_name == player_name then
      if ph.player_hud == nil then return nil end
      return ph.player_hud
    end
  end
end

---comment
---@param player_name any
---@return player_hud
local function getPlayerFromPlayerHuds(player_name)
  for _, ph in ipairs(player_hud_id) do
    if ph.player_name == player_name then
      return ph
    end
  end
  return nil
end

local function removePlayerHud(player)
  local hud_id = getPlayerHud(player:get_player_name())
  if hud_id ~= nil then
    player:hud_remove(hud_id)
    for index, ph in ipairs(player_hud_id) do
      if ph.player_name == player:get_player_name() then
        table.remove(player_hud_id, index)
      end
    end
  end
end

local function carryableIdicator(p, pos)
  local hud_id = getPlayerHud(p:get_player_name())
  local player_with_hud = getPlayerFromPlayerHuds(p:get_player_name())
  if player_with_hud == nil then
    local this_players_hud = {
      player_name = p:get_player_name(),
      player_hud = hud_id,
      hud_delay = I_have_hands.indicator_delay,
      chest_location = pos
    }
    table.insert(player_hud_id, this_players_hud)
  else
    -- core.debug("what do we have here? "..player_with_hud.hud_delay)
    if player_with_hud.hud_delay == 0 then
      if hud_id == nil then
        hud_id = p:hud_add({
          type = "text",
          position = { x = 0.5, y = 0.6 },
          direction = 0,
          name = "ihh",
          scale = { x = 1, y = 1 },
          -- text = "crouch & interact to lift this",
          text = "carry: crouch & interact",
          number = "0xFFFFFF",
          z_index = 0,
        })
      end
      player_with_hud.player_hud = hud_id
    end
    -- if player_with_hud.chest_location ~= raycast_result.under then
    --   removePlayerHud(p)
    -- end
  end
end

---NOTE(COMPAT): allseer
if core.get_modpath("allseer") and allseer then
  allseer.extra[mod_name] = function(raycast_result)
    if raycast_result.type == "object" then
      return ""
    end
    local node_timer = core.get_node_timer(raycast_result.under)
    return core.colorize("#956eb5", "node timer: ") .. node_timer:get_timeout()
  end
end

local function castTheRay(player, reach)
  -- start at player eye_height, end at raycast
  local p_dir = player:get_look_dir()
  local p_eye_height = player:get_properties().eye_height
  local p_pos = player:get_pos()
  p_pos.y = p_pos.y + p_eye_height -- take eye_height into account
  local new_pos = p_dir:multiply(reach):add(p_pos)

  local ray = Raycast(p_pos, new_pos, true, false, nil)

  ---FIXME: I AM HERE!!
  local pointed_thing = nil
  local object_in_way = false

  for point in ray do
    if point.type == "object" and point.ref == player then
      -- core.log("opp this is me, lets skip and go next")
    else
      if point.type == "node" and pointed_thing == nil then
        -- core.log(core.colorize("#917392", "pointed: " .. dump(point)))
        pointed_thing = point
      end
      if point.type == "object" and pointed_thing == nil then
        object_in_way = true
      end
    end
  end

  if object_in_way == true then
    -- core.log("seems like there is a block")
    return
  end
  return pointed_thing
end


---@class hud_id
---@field player_name string
---@field hud_id number

---@type hud_id[]
local carrying_inv = {}

local function getCarryingIndicatorId(player_name)
  for c_i, c_v in ipairs(carrying_inv) do
    if c_v.player_name == player_name then
      return c_i
    end
  end
  return nil
end

local function carryingIndicator(player_ref)
  local player_name = player_ref:get_player_name()
  local p_data = getPlayerData(player_name)
  if p_data.inv ~= nil then
    if getCarryingIndicatorId(player_name) == nil then
      local hud_id = player_ref:hud_add({
        type = "image",
        -- position = { x = 0.54, y = 0.54 },
        position = { x = 0.5, y = 0.6 },
        -- position = { x = 0.65, y = 0.8 },
        direction = 0,
        name = "ihh_carry",
        scale = { x = 4.5, y = 4.5 },
        -- text = "crouch & interact to lift this",
        text = "i_have_hands_indicator.png^[opacity:115",
        number = "0xFFFFFF",
        z_index = 0,
      })
      local new_hud = { player_name = player_name, hud_id = hud_id }
      table.insert(carrying_inv, new_hud)
    end
  else
    local hud_index = getCarryingIndicatorId(player_name)
    if hud_index ~= nil then
      player_ref:hud_remove(carrying_inv[hud_index].hud_id)
      table.remove(carrying_inv, hud_index)
    end
  end
end

local started = false

core.register_globalstep(function(dtime)
  if started == false then --- run this once
    started = true
    Data.load_data()
  end

  local all_players = core.get_connected_players()
  for _, player in pairs(all_players) do
    local p_control = player:get_player_control()

    --- (for debugging) lets see what is being pressed
    -- local log_controls = function()
    --   for key, value in pairs(p_control) do
    --     if value == true then
    --       core.log(string.format("%s : %s", dump(key), dump(value)))
    --     end
    --   end
    -- end
    -- log_controls()

    local p_name = player:get_player_name()
    local p_data = getPlayerData(p_name)

    ---make sure the player has the carry entity when they join
    if p_data.node ~= nil and p_data.held == nil then
      I_have_hands.carry_entity(player:get_pos(), player, p_data, true)
    end

    --- for picking up the player's reach is shorter
    --- for putting down reach will be whatever is is set for the hand
    local reach = RayDistance
    local item = player:get_wielded_item()
    if p_data.inv ~= nil then
      -- local item_reach = item:get_meta().range
      -- if item_reach ~= nil then
      --   reach = item_reach
      -- end
      reach = hand_range
    end

    carryingIndicator(player)

    ---lets not raycast if item is not ""
    if item:get_name() ~= "" then
      --- drop inv/node if wield item is not hand
      if p_data.inv ~= nil then
        local p_pos = player:get_pos()
        local drop_pos = { type = "node", under = p_pos, above = p_pos }
        I_have_hands.putDownInv(p_name, drop_pos)
      end
      removePlayerHud(player)
    else
      local pointed_thing = castTheRay(player, reach)
      if pointed_thing then
        local inv = core.get_inventory({ type = "node", pos = pointed_thing.under })
        local at_least_one = 0
        if inv ~= nil then
          for _, _ in pairs(inv:get_lists()) do
            at_least_one = at_least_one + 1
          end
        end
        if p_data.inv == nil and isBlacklisted(pointed_thing.under) == false then
          if I_have_hands.allow_all or at_least_one > 0 then
            local player_name = player:get_player_name()
            carryableIdicator(player, pointed_thing.under)
            local p_hud = getPlayerFromPlayerHuds(player_name)
            p_hud.hud_delay = p_hud.hud_delay - 1
          else
            removePlayerHud(player)
          end
        else
          removePlayerHud(player)
        end
      else
        removePlayerHud(player)
      end

      --- handle actaul pickup/putdown
      if p_control.place == true then
        if p_data.pressed_button ~= true then -- only just on the first click
          p_data.pressed_button = true
          if item:get_name() ~= "" then
            -- core.log("only work with empty hand")
            return
          end
          if pointed_thing then
            if pointed_thing.ref and pointed_thing.ref == player then
              -- if pointed_thing.type == "object" then
              --   core.log("pointed: " .. dump(pointed_thing))
              --   return
              -- end
              -- core.log("oop this is me")
              return
            end
            if p_data.inv == nil then
              -- core.log(core.colorize("#853729", "[ UP ] -> " .. core.colorize("#189784", dump(pointed_thing))))
              if pointed_thing.under then
                -- core.log("player data: " .. dump(p_data))
                if p_control.sneak == true then -- must be sneaking (as if to reach down for it)
                  if isBlacklisted(pointed_thing.under) == false then
                    I_have_hands.pickupInv(p_name, pointed_thing)
                  end
                end
              end
            else
              -- core.log(core.colorize("#853729", "[ DOWN ] -> " .. core.colorize("#189784", dump(pointed_thing))))
              -- else we place it down
              if pointed_thing.above then
                -- core.log("placing at: " .. dump(pointed_thing.above))
                I_have_hands.putDownInv(p_name, pointed_thing)
              end
            end
            --- check that hand is empty
          end
        end
      else
        p_data.pressed_button = false
      end
    end
  end
end)


---@param this_string string the string
---@param split string sub to split at
function Split(this_string, split)
  local new_word = {}
  local index = string.find(this_string, split)
  if index == nil then
    return nil
  end
  local split_index = index
  local split_start = ""
  for x = 0, split_index - 1, 1 do
    split_start = split_start .. string.sub(this_string, x, x)
  end
  new_word[1] = split_start

  local split_end = ""
  for x = split_index + #split, #this_string, 1 do
    split_end = split_end .. string.sub(this_string, x, x)
  end
  new_word[2] = split_end
  return new_word
end

local function placeDown(placer, rot, obj, above, frame, held_item_name)
  placer:set_bone_override("Arm_Right",
    { rotation = { absolute = false, interpolation = 0, vec = { x = 0, y = 0, z = 0 } } })
  placer:set_bone_override("Arm_Left",
    { rotation = { absolute = false, interpolation = 0, vec = { x = 0, y = 0, z = 0 } } })
  table.insert(to_animate,
    { player = placer, rot = rot, obj = obj, pos = above, frame = frame, item = held_item_name })
end

local function quantize_direction(yaw)
  local angle = math.deg(yaw) % 360 -- Convert yaw to degrees and get its modulo 360
  if angle < 45 or angle >= 315 then
    return math.rad(0)              -- Facing North
  elseif angle >= 45 and angle < 135 then
    return math.rad(90)             -- Facing East
  elseif angle >= 135 and angle < 225 then
    return math.rad(180)            -- Facing South
  else
    return math.rad(270)            -- Facing West
  end
end


local function particle(pos, color, dir)
  local velocity = dir
  local position = pos or { x = 0, y = 0, z = 0 }

  local set_color = ""
  if color ~= nil then
    set_color = "^[colorize:" .. color .. ":255"
  end

  core.add_particle({
    pos = position,
    velocity = velocity,
    acceleration = { x = 0, y = 0, z = 0 },
    -- Spawn particle at pos with velocity and acceleration

    expirationtime = 0.8,
    -- Disappears after expirationtime seconds

    size = 6,
    -- Scales the visual size of the particle texture.
    -- If `node` is set, size can be set to 0 to spawn a randomly-sized
    -- particle (just like actual node dig particles).

    collisiondetection = false,
    -- If true collides with `walkable` nodes and, depending on the
    -- `object_collision` field, objects too.

    collision_removal = false,
    -- If true particle is removed when it collides.
    -- Requires collisiondetection = true to have any effect.

    object_collision = false,
    -- If true particle collides with objects that are defined as
    -- `physical = true,` and `collide_with_objects = true,`.
    -- Requires collisiondetection = true to have any effect.

    vertical = false,
    -- If true faces player using y axis only

    texture = "i_have_hands_particle.png" .. set_color,
    -- The texture of the particle
    -- v5.6.0 and later: also supports the table format described in the
    -- following section, but due to a bug this did not take effect
    -- (beyond the texture name).
    -- v5.9.0 and later: fixes the bug.
    -- Note: "texture.animation" is ignored here. Use "animation" below instead.

    -- playername = "singleplayer",
    -- Optional, if specified spawns particle only on the player's client

    -- animation = { Tile Animation definition },
    -- Optional, specifies how to animate the particle texture

    glow = 0,
    -- Optional, specify particle self-luminescence in darkness.
    -- Values 0-14.

    -- node = { name = "ignore", param2 = 0 },
    -- Optional, if specified the particle will have the same appearance as
    -- node dig particles for the given node.
    -- `texture` and `animation` will be ignored if this is set.

    -- node_tile = 0,
    -- Optional, only valid in combination with `node`
    -- If set to a valid number 1-6, specifies the tile from which the
    -- particle texture is picked.
    -- Otherwise, the default behavior is used. (currently: any random tile)

    -- drag = { x = 0, y = 0, z = 0 },
    -- v5.6.0 and later: Optional drag value, consult the following section
    -- Note: Only a vector is supported here. Alternative forms like a single
    -- number are not supported.

    -- jitter = { min = 1, max = 10, bias = 0 },
    -- v5.6.0 and later: Optional jitter range, consult the following section

    -- bounce = { min = ..., max = ..., bias = 0 },
    -- v5.6.0 and later: Optional bounce range, consult the following section
  }
  )
end

--object, pos, frame
--not in use atm
local function animatePlace()
  for i, v in pairs(to_animate) do
    if v.frame == 0 then
      v.obj:set_detach()
      v.obj:set_yaw(v.rot)
      local obj_rot = v.obj:get_rotation()
      -- v.obj:set_rotation({ x = math.rad(-20), y = obj_rot.y, z = obj_rot.z })
      -- v.obj:set_rotation({ x = obj_rot.x+ math.rad(-90), y = obj_rot.y, z = obj_rot.z })
      -- v.obj:set_properties({ visual_size = { x = 0.5, y = 0.5, z = 0.5 } })
      -- v.obj:set_properties({ visual_size = { x = 0.6, y = 0.6, z = 0.6 } })
      v.obj:set_properties({ visual_size = { x = 0.65, y = 0.65, z = 0.65 } })
      -- v.obj:set_pos(v.pos)
      -- v.obj:set_properties({ pointable = true })

      local ghost = core.add_entity(v.pos, "i_have_hands:ghost")
      ghost:set_rotation({ x = obj_rot.x, y = obj_rot.y + math.rad(-90), z = obj_rot.z })
      v.obj:set_attach(ghost, "BONE", vector.new(0, 0, 0), vector.new(0, -90, 0))
      ghost:set_animation({ x = 0.40, y = 160 }, 4, 0, false)

      v["ghost"] = ghost
      core.sound_play({ name = "i_have_hands_pickup_node" }, { pos = v.pos, pitch = math.random(0.7, 1.2), gain = 1 },
        true)
    end
    if v.frame == 1 then
      -- local obj_rot = v.obj:get_rotation()
      -- v.obj:set_rotation({ x = math.rad(0), y = obj_rot.y, z = obj_rot.z })
      -- v.obj:set_properties({ visual_size = { x = 0.6, y = 0.6, z = 0.6 } })
      -- particle(vector.new(v.pos.x,v.pos.y-0.5,v.pos.z),"#ffffff",vector.new(0,0.5,1.5))
    end
    if v.frame == 2 then
      -- v.obj:set_properties({ visual_size = { x = 0.65, y = 0.65, z = 0.65 } })
    end
    if v.frame == 5 then
      local found_meta = data_storage:get_string(v.obj:get_luaentity().initial_pos)
      data_storage:set_string(v.obj:get_luaentity().initial_pos, "") --clear it
      core.set_node(v.pos, { name = v.item, param2 = core.dir_to_fourdir(core.yaw_to_dir(v.rot)) })
      core.sound_play({ name = "i_have_hands_place_down_node" }, { pos = v.pos, pitch = math.random(0.7, 1.2), gain = 1 },
        true)
      local node_sound = core.registered_nodes[v.item].sounds.place.name
      if node_sound ~= nil then
        core.sound_play({ name = node_sound }, { pos = v.pos, gain = 1 }, true)
      end
      core.get_node_timer(v.pos):start(1.0)
      local meta = core.get_meta(v.pos)

      local node_containers = {}
      for i, v in pairs(core.deserialize(found_meta)["data"]) do
        local found_container = {}
        for container, container_items in pairs(v) do
          local found_inv = {}
          if type(container_items) == "string" then
            found_container[container] = container_items
          else
            for slot, item in pairs(container_items) do
              found_inv[slot] = item
            end
            found_container[container] = found_inv
          end
        end
        node_containers[i] = found_container
      end
      meta:from_table(node_containers)

      -- MCL_FURANCE set the XP to zero
      if meta:get_int("xp") > 0 then
        meta:set_int("xp", 0)
      end

      --wait is all this running for all?
      -- for pipes it makes sense, not for drawers or amor_stands though

      --NOTE(COMPAT): this adds support for the storage_drawers mod
      if core.get_modpath("drawers") and drawers then
        drawers.spawn_visuals(v.pos)
      end
      --NOTE(COMPAT): pipeworks update pipe, on place down
      if core.get_modpath("pipeworks") and pipeworks then
        pipeworks.after_place(v.pos)
      end
      --NOTE(COMPAT): armor_stand(voxelibre & mineclonia) on place down
      if string.find(v.item, "mcl_armor_stand") then
        if core.get_modpath("mcl_armor_stand") then
          if core.get_modpath("mcl_armor") and mcl_armor then
            for _, obj in ipairs(minetest.get_objects_inside_radius(v.pos, 0)) do
              local luaentity = obj:get_luaentity()
              if luaentity and luaentity.name == "mcl_armor_stand:armor_entity" then
                -- luaentity:update_armor()
                mcl_armor.update(luaentity.object)
              end
            end
          end
        end
        --should make the armor stand update it visual.
      end
    end
    v.frame = v.frame + 1
    -- core.log("despawn in: " .. v.frame)
    if v.frame >= 10 then
      v.obj:remove()
      v.ghost:remove()
      v.obj = nil
      table.remove(to_animate, i)
    end
  end
end

local function isInventory(meta)
  if I_have_hands.allow_all == true then
    return true
  end
  local count = 0
  for _ in pairs(meta:to_table()["inventory"]) do count = count + 1 end
  if count < 1 then --inve have a value of 1 or greater
    return false
  end
  return true
end

local function find_empty_position(pos, radius)
  local x, y, z = pos.x, pos.y, pos.z
  local found = false
  local empty_pos = nil

  for r = 0, radius do
    for a = 0, 360, 10 do
      local dx = math.floor(r * math.cos(math.rad(a)))
      local dz = math.floor(r * math.sin(math.rad(a)))
      local nx, nz = x + dx, z + dz
      local ny = y

      while ny < 100 and not found do
        local node = core.get_node({ x = nx, y = ny, z = nz })
        if node.name == "air" then
          empty_pos = { x = nx, y = ny, z = nz }
          found = true
        end
        ny = ny + 1
      end
    end
  end

  return empty_pos
end

-- local handdef = core.registered_items[""]
-- local on_place = handdef and handdef.on_place

-- local function hands(itemstack, placer, pointed_thing)
--   local contains = false
--   if placer:get_player_control()["sneak"] == true then
--     -- core.debug("what is this?",core.get_node(pointed_thing.under).name)
--     -- core.debug(string.format("location: %s", dump(core.get_modpath("drawers"))))
--     -- core.debug(core.colorize("yellow", "howdy mate, ive got the shits"))
--     if #placer:get_children() > 0 then --this is getting all connect objects
--       for index, obj in pairs(placer:get_children()) do
--         -- core.debug(dump(obj:get_luaentity().name))
--         -- core.debug("got something: "..obj.name)
--         -- end
--         -- for index, value in pairs(placer:get_children()) do
--         local above = pointed_thing.above
--         -- core.debug("node: "..core.get_node(above).name)
--         if checkProtection(above, placer) == false then
--           if obj:get_luaentity().name == "i_have_hands:held" then
--             contains = true
--             -- core.debug("ok: "..type(held).."-"..held.."-")
--             local try_inside = core.registered_nodes[core.get_node(pointed_thing.under).name]
--             -- core.debug("buildabled? ",try_inside.buildable_to)
--             if core.get_node(above).name ~= "air" then
--               -- if core.get_node(above).name == "water" then
--               if utils.StringContains(core.get_node(above).name, "water") then
--                 --do nothing
--               else
--                 return itemstack
--               end
--             end
--             if #core.get_objects_inside_radius(above, 0.5) > 0 then
--               return itemstack
--             end
--             if try_inside.buildable_to == true then
--               above = pointed_thing.under
--             end


--             local held_item_name = core.registered_nodes[obj:get_properties().wield_item].name
--             -- local player_p = core.dir_to_fourdir(placer:get_look_dir())
--             -- obj:set_pos(above)
--             -- animatePlace(obj,above)

--             -- table.insert(to_animate,
--             --   { player = placer, rot = rot, obj = obj, pos = above, frame = 0, item = held_item_name })
--             local rot = quantize_direction(placer:get_look_horizontal())
--             placeDown(placer, rot, obj, above, 0, held_item_name)
--           end
--         end
--       end
--     end

--     if contains == false then
--       local is_blacklisted = false

--       if isBlacklisted(pointed_thing.under) then
--         is_blacklisted = true
--       end
--       if is_blacklisted == false then
--         if checkProtection(pointed_thing.under, placer) then
--           return itemstack
--         end
--         local meta = core.get_meta(pointed_thing.under)
--         if isInventory(meta) == false then
--           return itemstack
--         end
--         local obj = core.add_entity(placer:get_pos(), "i_have_hands:held")
--         -- local obj = core.add_entity(placer:get_pos(), "i_have_hands:held")
--         -- local ghost = core.add_entity(placer:get_pos(), "i_have_hands:ghost")
--         -- core.log("bones: "..dump(placer:get_bone_overrides()))

--         obj:set_attach(placer, "Body", { x = 0, y = 4, z = -3.4 }, { x = 0, y = math.rad(90), z = 0 }, true)
--         -- obj:set_attach(placer, "armR", { x = 0, y = 4, z = -3.4 }, { x = 0, y = math.rad(90), z = 0 }, true)

--         -- obj:set_attach(ghost, "", { x = 0, y = 4, z = -3.4 }, { x = 0, y = 0, z = 0 }, true)
--         -- ghost:set_attach(placer, "Body", { x = 0, y = 4, z = -3.4 }, { x = 0, y = math.rad(90), z = 0 }, true)
--         -- obj:set_attach(placer, "Arm_Right", { x = 0, y = 9, z = 3.2 }, { x = 0, y = math.rad(90), z = 0 }, true)
--         -- core.log(core.colorize("red","attach: "..dump(placer:get_bone_override("Arm_Right"))))
--         placer:set_bone_override("Arm_Right",
--           { rotation = { absolute = false, interpolation = 0, vec = { x = math.rad(45), y = 0, z = 0 } } })
--         placer:set_bone_override("Arm_Left",
--           { rotation = { absolute = false, interpolation = 0, vec = { x = math.rad(45), y = 0, z = 0 } } })
--         --NOTE: attaching to the head just does not look very good, so lets not do that.
--         -- obj:set_attach(placer, "Head", { x = 0, y = -2, z = -3.2 }, { x = 0, y = math.rad(90), z = 0 }, true)
--         obj:set_properties({
--           wield_item = core.registered_nodes[core.get_node(pointed_thing.under).name]
--               .name
--         })
--         obj:get_luaentity().initial_pos = vector.to_string(obj:get_pos())

--         --NOTE(COMPAT): this takes care of voxelibre chests
-- if utils.StringContains(core.registered_nodes[core.get_node(pointed_thing.under).name].name, "mcl_chests") then
--   obj:set_properties({ wield_item = "mcl_chests:chest" })
--   -- local drawtype = core.registered_nodes[core.get_node(pointed_thing.under).name].drawtype
--   -- if drawtype == "mesh" then
--   --   obj:set_properties({ wield_item = "mcl_chests:chest" })
--   -- end
--   -- obj:set_properties({ wield_item = "mcl_chests:"..name })
-- end

--         -- core.debug(core.colorize("yellow",dump(core.registered_nodes[core.get_node(pointed_thing.under).name])))
--         -- core.debug(core.colorize("blue", "all: \n" .. dump(meta:to_table())))
--         local node_containers = {}
--         for i, v in pairs(meta:to_table()) do
--           local found_container = {}
--           for container, container_items in pairs(v) do
--             local found_inv = {}
--             if type(container_items) == "table" then
--               for slot, item in pairs(container_items) do
--                 table.insert(found_inv, slot, item:to_string())
--               end
--               found_container[container] = found_inv
--             else
--               found_container[container] = container_items
--             end
--           end
--           node_containers[i] = found_container
--         end
--         local full_data = { node = core.get_node(pointed_thing.under), data = node_containers }
--         -- core.debug("full_data: ".. dump(full_data.data))

--         local pos = vector.to_string(obj:get_pos())
--         data_storage:set_string(pos, core.serialize(full_data))
--         obj:get_luaentity().initial_pos = pos
--         -- placer:get_meta():set_string("obj_obj",core.write_json(obj))

--         -- NOTE(COMPAT): age of meding support, may break in the future
--         --NOTE(COMPAT): armor_stand(voxelibre & mineclonia) on pickup
--         if string.find(core.get_node(pointed_thing.under).name, "aom_storage") or
--             string.find(core.get_node(pointed_thing.under).name, "mcl_armor_stand") then
--           core.swap_node(pointed_thing.under, core.registered_nodes["air"])
--         else
--           core.remove_node(pointed_thing.under)
--         end

--         core.sound_play({ name = "i_have_hands_pickup_node" },
--           { pos = pointed_thing.under, pitch = math.random(0.7, 1.2), gain = 1 }, true)

--         --NOTE(COMPAT): pipeworks update pipe, on pickup
--         if core.get_modpath("pipeworks") and pipeworks then
--           pipeworks.after_place(pointed_thing.under)
--         end

--         -- core.sound_play({ name = "i_have_hands_pickup" }, { pos = pointed_thing.under,gain = 0.1}, true)
--       end
--     end
--   end
--   --you know, return itemstack
-- end

-- local original_on_place = core.registered_items[""].on_place

-- core.override_item("", {
--   on_place = function(itemstack, placer, pointed_thing)
--     itemstack = on_place(itemstack, placer, pointed_thing)
--     hands(itemstack, placer, pointed_thing)

--     -- Call the original on_place function if it exists
--     -- if original_on_place then
--     --   return original_on_place(itemstack, placer, pointed_thing)
--     -- end
--     return itemstack
--   end,
--   -- on_secondary_use = function(itemstack, placer, pointed_thing)
--   --   hands(itemstack, placer, pointed_thing)
--   -- end
-- })

--check if the player is holding an inventory
local function isHolding(player)
  if #player:get_children() > 0 then --this is getting all connect objects
    for index, obj in pairs(player:get_children()) do
      if obj:get_luaentity().name == "i_have_hands:held" then
        -- core.debug("this dude is holding")
        return true
      end
      -- core.debug("nope not holding")
      return false
    end
  end
  return false
end

core.register_entity("i_have_hands:held", {
  selectionbox = { -0.0, -0.0, -0.0, 0.0, 0.0, 0.0, rotate = false },
  pointable = false,
  physical = false,
  collide_with_objects = false,
  -- visual = "mesh",
  -- mesh = "i_have_hands_ghost.glb",
  visual = "item",
  wield_item = "",
  -- visual_size = { x = 0.35, y = 0.35, z = 0.35 },
  _initial_pos = "",
  on_step = function(self, dtime, moveresult)
    -- core.debug(core.colorize("cyan", "dropping: \n" .. dump(data_storage:get_keys())))

    if self.object:get_attach() == nil then
      self.object:remove()
    end
    --   local contains = false
    --   for i, v in pairs(to_animate) do
    --     if v.obj == self.object then
    --       -- core.debug("should not delete this yet")
    --       contains = true
    --     end
    --   end
    --   if contains == false then
    --     local pos = self.object:get_luaentity().initial_pos
    --     for i, v in pairs(data_storage:get_keys()) do
    --       if v == pos then
    --         core.set_node(vector.from_string(pos), core.deserialize(data_storage:get_string(v))["node"])
    --         local meta = core.get_meta(vector.from_string(pos))
    --         meta:from_table(utils.DeserializeMetaData(core.deserialize(data_storage:get_string(v))["data"]))
    --         data_storage:set_string(v, "")
    --       end
    --     end
    --     self.object:remove()
    --   end
    -- end

    --updute pos and data
    -- if self.object:get_luaentity() then
    --   if self.object:get_luaentity().initial_pos ~= nil then
    --     local pos = self.object:get_luaentity().initial_pos
    --     local data = data_storage:get_string(pos)
    --     data_storage:set_string(pos)
    --     self.object:get_luaentity().initial_pos = vector.to_string(self.object:get_pos())
    --     data_storage:set_string(vector.to_string(self.object:get_pos()), data)
    --   end
    -- end
  end,
})


core.register_entity("i_have_hands:ghost", {
  selectionbox = { -0.0, -0.0, -0.0, 0.0, 0.0, 0.0, rotate = false },
  pointable = false,
  physical = false,
  collide_with_objects = false,
  visual = "mesh",
  mesh = "i_have_hands_ghost.glb",
  -- mesh = "place_animation.glb",
  -- visual = "item",
  -- wield_item = "",
  textures = { "blank.png", },
  visual_size = { x = 1, y = 1, z = 1 },
  _initial_pos = "",
  on_step = function(self, dtime, moveresult)
    -- core.debug(core.colorize("cyan", "dropping: \n" .. dump(data_storage:get_keys())))

    if #self.object:get_children() <= 0 then
      self.object:remove()
    end
    --   local contains = false
    --   for i, v in pairs(to_animate) do
    --     if v.obj == self.object then
    --       -- core.debug("should not delete this yet")
    --       contains = true
    --     end
    --   end
    --   if contains == false then
    --     local pos = self.object:get_luaentity().initial_pos
    --     for i, v in pairs(data_storage:get_keys()) do
    --       if v == pos then
    --         core.set_node(vector.from_string(pos), core.deserialize(data_storage:get_string(v))["node"])
    --         local meta = core.get_meta(vector.from_string(pos))
    --         meta:from_table(utils.DeserializeMetaData(core.deserialize(data_storage:get_string(v))["data"]))
    --         data_storage:set_string(v, "")
    --       end
    --     end
    --     self.object:remove()
    --   end
    -- end

    -- --updute pos and data
    -- if self.object:get_luaentity() then
    --   if self.object:get_luaentity().initial_pos ~= nil then
    --     local pos = self.object:get_luaentity().initial_pos
    --     local data = data_storage:get_string(pos)
    --     data_storage:set_string(pos)
    --     self.object:get_luaentity().initial_pos = vector.to_string(self.object:get_pos())
    --     data_storage:set_string(vector.to_string(self.object:get_pos()), data)
    --   end
    -- end
  end,
})

--FIXME: only raycast if the player's "hand" is empty (no need to cast when the player cant event pick it up to start with)
local function raycast()
  local player = core.get_connected_players()
  if #player > 0 then
    for _, p in ipairs(player) do
      local eye_height = p:get_properties().eye_height
      local player_look_dir = p:get_look_dir()
      local pos = p:get_pos():add(player_look_dir)
      local player_pos = { x = pos.x, y = pos.y + eye_height, z = pos.z }
      local new_pos = p:get_look_dir():multiply(RayDistance):add(player_pos)
      local raycast_result = core.raycast(player_pos, new_pos, false, false):next()
      if isHolding(p) then
        removePlayerHud(p)
        return
      end

      local hud_id = nil; --FIXME this need to be added to list of all player HUDS
      if raycast_result then
        local pointed_node = core.get_node(raycast_result.under)
        if isBlacklisted(raycast_result.under) then
          removePlayerHud(p)
          return
        end
        if p:get_wielded_item():get_name() ~= "" then
          removePlayerHud(p)
          return
        end
        if isInventory(core.get_meta(raycast_result.under)) then
          hud_id = getPlayerHud(p:get_player_name())
          local player_with_hud = getPlayerFromPlayerHuds(p:get_player_name())
          if player_with_hud == nil then
            local this_players_hud = {
              player_name = p:get_player_name(),
              player_hud = hud_id,
              hud_delay = 6,
              chest_location =
                  raycast_result.under
            }
            table.insert(player_hud_id, this_players_hud)
          else
            -- core.debug("what do we have here? "..player_with_hud.hud_delay)
            if player_with_hud.hud_delay == 0 then
              if hud_id == nil then
                hud_id = p:hud_add({
                  type = "text",
                  position = { x = 0.5, y = 0.6 },
                  direction = 0,
                  name = "ihh",
                  scale = { x = 1, y = 1 },
                  -- text = "crouch & interact to lift this",
                  text = "carry: crouch & interact",
                  number = "0xFFFFFF",
                  z_index = 0,
                })
              end
              player_with_hud.player_hud = hud_id
            end
            if player_with_hud.chest_location ~= raycast_result.under then
              removePlayerHud(p)
            end
          end
          -- core.debug("so wtf is this then? " .. tostring(hud_id))
        else
          removePlayerHud(p)
        end
        -- core.debug(string.format("what is this?",core.registered_nodes[pointed_node].name))
      else
        removePlayerHud(p)
      end
    end
  end
end

local function hotbarSlotNotEmpty()
  local player = core.get_connected_players()
  if #player > 0 then
    for _, p in ipairs(player) do
      if p:get_wielded_item():get_name() ~= "" then
        if #p:get_children() > 0 then --this is getting all connect objects
          for index, obj in pairs(p:get_children()) do
            if obj:get_luaentity().name == "i_have_hands:held" then
              local held_item_name = core.registered_nodes[obj:get_properties().wield_item].name
              placeDown(p, 0, obj, find_empty_position(p:get_pos(), 10), 0, held_item_name)
            end
          end
        end
      end
    end
  end
end

local function tickHudDelay()
  for _, h in pairs(player_hud_id) do
    if h.hud_delay > 0 then
      h.hud_delay = h.hud_delay - 1
    end
  end
end

-- local function addIndicator()

-- end


-- local ran_once = false
-- local tick = 0
-- core.register_globalstep(function(dtime)
--   -- raycast()
--   tick = tick + 0.5
--   if tick > 2 then
--     animatePlace()
--     raycast()
--     hotbarSlotNotEmpty()
--     tickHudDelay()
--     carryingIndicator()
--     tick = 0
--   end
--   if ran_once == false then
--     ran_once = true
--     for i, v in pairs(data_storage:get_keys()) do
--       local pos = vector.from_string(v)
--       core.set_node(pos, core.deserialize(data_storage:get_string(v))["node"])
--       local meta = core.get_meta(pos)
--       meta:from_table(utils.DeserializeMetaData(core.deserialize(data_storage:get_string(v))["data"]))
--       data_storage:set_string(v, "")
--     end
--   end
-- end)


-- core.register_on_dieplayer(function(ObjectRef, reason)
--   if #ObjectRef:get_children() > 0 then --this is getting all connect objects
--     for index, obj in pairs(ObjectRef:get_children()) do
--       if obj:get_luaentity().name == "i_have_hands:held" then
--         local held_item_name = core.registered_nodes[obj:get_properties().wield_item].name
--         placeDown(ObjectRef, 0, obj, find_empty_position(ObjectRef:get_pos(), 10), 0, held_item_name)
--       end
--     end
--   end
--   -- core.debug("what death? " .. ObjectRef:get_player_name())
-- end)
