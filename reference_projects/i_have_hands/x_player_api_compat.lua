-- i_have_hands/x_player_api_compat.lua
-- Native integration with x_player_api dual-format player models.
-- Ported from the former x_player_bridge mod (modules/wield/i_have_hands.lua
-- and modules/locomotion/carts.lua) so the bridge mod is no longer needed:
--   * Calibrated dual-arm posture while carrying a container (GLB + B3D)
--   * Upright standing posture while riding carts and minecarts

local mod_name = core.get_current_modname()

-- x_player_api is listed in optional_depends, so when enabled it is fully
-- loaded before this mod (see mod.conf). Skip silently when absent.
if not core.get_modpath("x_player_api") or not rawget(_G, "x_player_api") then
  core.log("action", "[" .. mod_name .. "] x_player_api not found, model integration skipped")
  return
end

local enable_carrying = core.settings:get_bool("i_have_hands.enable_carrying_posture", true)
local enable_cart_posture = core.settings:get_bool("i_have_hands.enable_cart_posture", true)

-- Calibrated dual-arm carrying posture (radians)
local PITCH = math.rad(118)
local YAW   = math.rad(4)
local ROLL  = math.rad(6)

-- GLB bone coordinate space: positive X elevates arm forward/up
local ROT_R = { x =  PITCH, y = -YAW, z =  ROLL }
local ROT_L = { x =  PITCH, y =  YAW, z = -ROLL }

-- B3D bone coordinate space: negative X elevates arm forward/up; Y and Z match wider GLB opening
local B3D_ROT_R = { x = -PITCH, y = -YAW, z =  ROLL }
local B3D_ROT_L = { x = -PITCH, y =  YAW, z = -ROLL }

local ZERO_ROT = { x = 0, y = 0, z = 0 }

---@type table<string, boolean>
local carrying_cache = {}

---Check whether a player is actively carrying a container from i_have_hands
---@param player ObjectRef Target player
---@return boolean is_carrying
local function is_carrying_block(player)
  if not player or not player:is_player() then
    return false
  end
  local name = player:get_player_name()
  local p_data = I_have_hands.Player_data[name]
  if p_data and p_data.held then
    return true
  end
  -- Fallback: scan attached children for the carry entity
  if not player.get_children then
    return false
  end
  local children = player:get_children()
  if not children then
    return false
  end
  for i = 1, #children do
    local child = children[i]
    if child and child:is_valid() then
      local ent = child:get_luaentity()
      if ent and ent.name == "i_have_hands:held" then
        return true
      end
    end
  end
  return false
end

---Apply dual-arm carrying posture to the player's visual proxies
---@param player ObjectRef Target player
local function apply_carrying_posture(player)
  x_player_api.set_bone_override(player, "Arm_Right", nil, ROT_R, true, 0.15, true, B3D_ROT_R)
  x_player_api.set_bone_override(player, "Arm_Left",  nil, ROT_L, true, 0.15, true, B3D_ROT_L)
end

---Reset player arms to the resting bind pose
---@param player ObjectRef Target player
local function reset_carrying_posture(player)
  x_player_api.set_bone_override(player, "Arm_Right", nil, ZERO_ROT, true, 0.15, true, ZERO_ROT)
  x_player_api.set_bone_override(player, "Arm_Left",  nil, ZERO_ROT, true, 0.15, true, ZERO_ROT)
end

-- Expose helpers for external mods and debugging
I_have_hands.is_carrying_block = is_carrying_block
I_have_hands.apply_carrying_posture = apply_carrying_posture
I_have_hands.reset_carrying_posture = reset_carrying_posture

---Apply or reset the carrying posture once per step for one player
---@param player ObjectRef Target player
local function step_carrying_posture(player)
  local name = player:get_player_name()
  local carrying = is_carrying_block(player)
  local was_carrying = carrying_cache[name]

  if carrying then
    apply_carrying_posture(player)
    carrying_cache[name] = true
  elseif was_carrying then
    reset_carrying_posture(player)
    carrying_cache[name] = nil
  end
end

if enable_carrying then
  -- Route carrying into the x_player_api semantic state (action "carry")
  x_player_api.register_action_evaluator(75, function(player, _ctx)
    if is_carrying_block(player) then
      return "carry"
    end
    return nil
  end)

  -- Wrap step_head_tracking so look-based arm tracking yields to the carrying
  -- posture instead of clobbering the raised arms every step, and apply the
  -- posture right after head tracking ran.
  -- The flag name matches the former x_player_bridge hook guard so the wrap
  -- is never installed twice if the legacy bridge is ever present.
  if x_player_api.step_head_tracking and not x_player_api._i_have_hands_bridge_hooked then
    local orig_step_head_tracking = x_player_api.step_head_tracking
    x_player_api.step_head_tracking = function(player, dtime, semantic_state)
      local carrying = is_carrying_block(player)
      local ht_cfg = x_player_api.head_tracking and x_player_api.head_tracking.config
      local old_arm_tracking
      if carrying and ht_cfg then
        old_arm_tracking = ht_cfg.enable_arm_tracking
        ht_cfg.enable_arm_tracking = false
      end

      orig_step_head_tracking(player, dtime, semantic_state)

      if carrying and ht_cfg then
        ht_cfg.enable_arm_tracking = old_arm_tracking
      end

      step_carrying_posture(player)
    end
    x_player_api._i_have_hands_bridge_hooked = true
  end

  core.register_on_leaveplayer(function(player)
    if player and player:is_player() then
      carrying_cache[player:get_player_name()] = nil
    end
  end)

  core.register_on_dieplayer(function(player)
    if player and player:is_player() then
      local name = player:get_player_name()
      if carrying_cache[name] or is_carrying_block(player) then
        reset_carrying_posture(player)
        carrying_cache[name] = nil
      end
    end
  end)

  core.register_on_respawnplayer(function(player)
    if player and player:is_player() then
      local name = player:get_player_name()
      carrying_cache[name] = nil
      reset_carrying_posture(player)
    end
  end)
end

if enable_cart_posture then
  ---Check whether a player is attached to a cart or rail vehicle
  ---@param player ObjectRef Target player
  ---@return boolean in_cart
  local function is_player_in_cart(player)
    if not player or not player:is_player() then
      return false
    end

    local parent = player:get_attach()
    if not parent then
      return false
    end

    local luaentity = parent:get_luaentity()
    if not luaentity then
      return false
    end

    local name = luaentity.name or ""
    if name == "carts:cart"
        or name:find(":cart", 1, true)
        or name:find("cart:", 1, true)
        or name:find("minecart", 1, true)
        or luaentity.railtype ~= nil
        or luaentity.is_cart == true then
      return true
    end

    return false
  end

  I_have_hands.is_player_in_cart = is_player_in_cart

  -- Preserve upright standing posture while riding minecarts and rail vehicles
  x_player_api.register_locomotion_evaluator(70, function(player, _context)
    if is_player_in_cart(player) then
      return "stand"
    end
    return nil
  end)
end
