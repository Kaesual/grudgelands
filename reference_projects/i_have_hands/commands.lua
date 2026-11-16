local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)

-- TODO:plan on adding a formspec menu for settings

dofile(minetest.get_modpath("i_have_hands") .. "/utils.lua")

core.register_chatcommand("dropinv",{
  param = "",
  -- Short parameter description.  See the below note.
  description = "Make the player drop what they are carrying.",
  -- General description of the command's purpose.
  -- privs = {},
  -- Required privileges to run. See `core.check_player_privs()` for
  -- the format and see [Privileges] for an overview of privileges.
  func = function(player_name, param)
    local player_ref = core.get_player_by_name(player_name)
    local pos = player_ref:get_pos()
    local new_pos = {x=math.floor(pos.x+0.5),y=math.floor(pos.y+0.5),z=math.floor(pos.z+0.5)}
    local pointed_thing = {type="node",under=new_pos,above=new_pos}
    core.log("dropping now..")
    I_have_hands.putDownInv(player_name,pointed_thing)
  end,
})

--- formspec
core.register_chatcommand("ihh", {
  params = "[ help | allow_all ]",
  description = "global settings for i_have_hands mod",
  privs = {ihh_global=true},
  func = function(name, param)
    -- core.log("player: "..name.." cmd: "..param)
    if param == nil then
      return
    end
    local fields = utils.Split(param, " ")
    local msg = "[ihh] "
    if fields[1] == "help" then
      msg = msg .. "commands are: help, allow_all"
    elseif fields[1] == "allow_all" then
      if fields[2] == nil then
        I_have_hands.allow_all = not I_have_hands.allow_all
      else
        I_have_hands.allow_all = fields[2]
      end
      if I_have_hands.allow_all == true then
        msg = msg .. "You can pickup just about every block/node"
      else
        msg = msg .. "Can only pickup most blocks/nodes that have an inventory"
      end
    else
      msg = msg .. "commands are: help, allow_all"
    end
    core.chat_send_player(name, core.colorize("YELLOW", msg))
  end
})

core.register_privilege("ihh_global", "set global settings for i_have_hands")
