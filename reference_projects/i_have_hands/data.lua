local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)

local mod_storage = core.get_mod_storage()

Data = {}

function Data.save_data()
  local data = {}
  ---@class holder
  for player_name, p_data in pairs(I_have_hands.Player_data) do
    if p_data.inv ~= nil then
      -- core.log("will save this..")
      -- data[player_name] = data[player_name]
      data[player_name] = {}
      ---TODO: itemstacks need to be serialized
      --- itemstack to table
      local inv_data = {}
      for inv_name, inv in pairs(p_data.inv.inventory) do
        for slot, item in ipairs(inv) do
          if type(item) ~= "string" then
            inv[slot] = item:to_string()
          end
        end
        inv_data[inv_name] = inv
      end
      -- data[player_name] = p_data
      data[player_name].inv = p_data.inv
      data[player_name].inv.inventory = inv_data
      data[player_name].node = p_data.node
    end
  end
  -- core.log("[trying to save]: "..dump(data))
  local json = core.write_json(data)
  if json == nil then
    -- core.log("failed to save data")
    return
  end
  mod_storage:set_string("player_data", json)
  -- core.log("saved!")
end

function Data.load_data()
  local data = mod_storage:get_string("player_data")
  if data == "" then
    -- core.log("what is wrong?"..dump(data))
    -- core.log("no data")
    return
  end
  local parsed_data = core.parse_json(data)
  if parsed_data == nil then
    -- core.log("no data to parse")
    return
  end
  ---@class holder
  for player_name, p_data in pairs(parsed_data) do
    local inv_data = {}
    if p_data.inv and p_data.inv.inventory then
      for inv_name, inv in pairs(p_data.inv.inventory) do
        for slot, item in ipairs(inv) do
          inv[slot] = ItemStack(item)
        end
        inv_data[inv_name] = inv
      end
    end
    I_have_hands.Player_data[player_name] = p_data
    I_have_hands.Player_data[player_name].inv.inventory = inv_data
  end
  mod_storage:set_string("player_data", "") --- i gotta clear it
  -- core.log("what does this look like? "..dump(parsed_data))
  -- core.log("loaded_data")
end
