-- Callable Round 16 atmosphere/audio/density fixture for the final portable runner.
return function(root)
 local function load_in(env, path)
  return setfenv(assert(loadfile(root .. "/" .. path)), env)()
 end

 -- Shared clock and sunlight/night-vision ownership.
 local env = setmetatable({}, {__index = _G})
 local timeofday = 0.9
 local settings, steps, joins, leaves, shutdowns = {}, {}, {}, {}, {}
 local speeds = {}
 env.core = {
  settings = {
   get_bool = function(_, _, fallback) return fallback end,
   get = function(_, key) return settings[key] end,
   set = function(_, key, value)
    assert(key == "time_speed")
    settings[key] = value
    speeds[#speeds + 1] = tonumber(value)
   end,
  },
  register_globalstep = function(fn) steps[#steps + 1] = fn end,
  register_on_shutdown = function(fn) shutdowns[#shutdowns + 1] = fn end,
  register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
  register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
  register_chatcommand = function() end,
  check_player_privs = function() return true end,
  get_player_by_name = function() return nil end,
  get_timeofday = function() return timeofday end,
  time_to_day_night_ratio = function(value)
   return value >= 0.25 and value <= 0.75 and 1 or 0.175
  end,
  get_connected_players = function() return env.players end,
  log = function() end,
 }
 env.grug_core = {}
 env.players = {}
 load_in(env, "mods/CORE/grug_core/atmosphere.lua")
 local ratios = {}
 local player = {name = "clock"}
 function player:is_player() return true end
 function player:get_player_name() return self.name end
 function player:set_lighting() end
 function player:set_sky() end
 function player:set_clouds() end
 function player:override_day_night_ratio(ratio) ratios[#ratios + 1] = ratio or false end
 env.players[1] = player
 for _, fn in ipairs(joins) do fn(player) end
 assert(ratios[#ratios] == 0.30)
 env.grug_core.set_night_vision(player, env.grug_core.NIGHT_VISION_RATIO)
 assert(ratios[#ratios] == 0.45)
 timeofday = 0.5
 for _, fn in ipairs(steps) do fn(1) end
 assert(speeds[#speeds] == 60 and ratios[#ratios] == false)
 timeofday = 0.9
 for _, fn in ipairs(steps) do fn(1) end
 assert(speeds[#speeds] == 108 and ratios[#ratios] == 0.45)
 env.grug_core.set_night_vision(player, nil)
 assert(ratios[#ratios] == 0.30)
 assert(env.grug_core.is_day_phase(0.1875))
 assert(env.grug_core.is_day_phase(0.8125))
 assert(not env.grug_core.is_day_phase(0.8126))
 for _, fn in ipairs(leaves) do fn(player) end
 for _, fn in ipairs(shutdowns) do fn() end
 assert(settings.time_speed == "72")

 -- The central row transformer raises only fightable surface populations.
 local spawn_env = setmetatable({}, {__index = _G})
 spawn_env.core = {get_timeofday = function() return 0.5 end}
 spawn_env.grug_core = {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125}
 spawn_env.grug_zones = {}
 spawn_env.grug_mobs = {}
 load_in(spawn_env, "mods/ENTITIES/grug_mobs/spawn_policy.lua")
 local function role(name, fields)
  fields.clock = fields.clock or "day"
  spawn_env.grug_mobs.register_spawn_role(name, fields)
 end
 role("fixture:normal", {type = "animal"})
 role("fixture:critter", {type = "animal", _grug_tier = "critter"})
 role("fixture:npc", {type = "npc"})
 local normal = spawn_env.grug_mobs.prepare_spawn_row({name = "fixture:normal",
  chance = 1000, active_object_count = 4, max_height = 200})
 assert(normal.chance == 769 and normal.active_object_count == 5)
 local critter = spawn_env.grug_mobs.prepare_spawn_row({name = "fixture:critter",
  chance = 1000, active_object_count = 4, max_height = 200})
 assert(critter.chance == 1000 and critter.active_object_count == 4)
 local npc = spawn_env.grug_mobs.prepare_spawn_row({name = "fixture:npc",
  chance = 1000, active_object_count = 4, max_height = 200})
 assert(npc.chance == 1000 and npc.active_object_count == 4)
 local cave = spawn_env.grug_mobs.prepare_spawn_row({name = "fixture:normal",
  chance = 1000, active_object_count = 4, max_height = -40})
 assert(cave.chance == 1000 and cave.active_object_count == 4)
 role("fixture:night", {type = "monster", clock = "night"})
 local night = spawn_env.grug_mobs.prepare_spawn_row({name = "fixture:night",
  chance = 1000, active_object_count = 4, max_height = 200})
 assert(night.chance == 769 and night.active_object_count == 7)

 -- Alchemy sounds are emitted after successful settlement only.
 local alchemy = setmetatable({}, {__index = _G})
 local sounds, statuses, visions = {}, {}, {}
 alchemy.core = {
  get_item_group = function() return 0 end,
  chat_send_player = function() end,
  sound_play = function(spec, params, ephemeral)
   sounds[#sounds + 1] = {spec = spec, params = params, ephemeral = ephemeral}
  end,
  register_on_dieplayer = function() end,
  register_on_leaveplayer = function() end,
 }
 alchemy.grug_alchemy = {POTION_PERCENT = 30, POTION_COOLDOWN = 60}
 alchemy.grug_inventory = {equipment_slots = {}}
 alchemy.grug_traders = {
  potion_cooldown_left = function() return 0 end,
  start_potion_cooldown = function() end,
 }
 alchemy.grug_classes = {
  get_max_hp = function() return 100 end,
  get_max_mana = function() return 100 end,
 }
 alchemy.grug_abilities = {restore_mana = function() return 30 end}
 local poisoned = false
 alchemy.grug_mobs = {clear_poison = function() return poisoned end}
 alchemy.grug_core = {
  can_use_item_level = function() return true end,
  heal_player = function(_, target, amount) target.hp = target.hp + amount end,
  set_move_modifier = function() end,
  set_status = function(_, id, status) statuses[id] = status; return status end,
  set_night_vision = function(_, ratio) visions[#visions + 1] = ratio or false; return true end,
  NIGHT_VISION_RATIO = 0.45,
 }
 load_in(alchemy, "mods/ITEMS/grug_alchemy/effects.lua")
 local consumer = {name = "alchemy", hp = 50}
 function consumer:is_player() return true end
 function consumer:get_player_name() return self.name end
 function consumer:get_hp() return self.hp end
 function consumer:get_inventory() return {get_stack = function() return {} end} end
 local function stack()
  return {count = 1, take_item = function(self) self.count = self.count - 1 end}
 end
 local healing = stack()
 alchemy.grug_alchemy.potion_use("health", 60)(healing, consumer)
 assert(healing.count == 0 and #sounds == 1)
 assert(sounds[1].spec == "grug_alchemy_drink" and sounds[1].ephemeral == true)
 assert(sounds[1].params.to_player == "alchemy")
 consumer.hp = 100
 local refused = stack()
 alchemy.grug_alchemy.potion_use("health", 60)(refused, consumer)
 assert(refused.count == 1 and #sounds == 1)
 poisoned = false
 local antivenom = stack()
 alchemy.grug_alchemy.utility_use("antivenom", 0)(antivenom, consumer)
 assert(antivenom.count == 1 and #sounds == 1)
 poisoned = true
 alchemy.grug_alchemy.utility_use("antivenom", 0)(antivenom, consumer)
 assert(antivenom.count == 0 and #sounds == 2)
 local cave_draught = stack()
 alchemy.grug_alchemy.utility_use("cave", 600)(cave_draught, consumer)
 assert(cave_draught.count == 0 and #sounds == 3 and visions[#visions] == 0.45)
 statuses.alchemy_cave.on_expire(consumer)
 assert(visions[#visions] == false)
 local elixir = stack()
 alchemy.grug_alchemy.elixir_use({label = "Fixture", duration = 10})(elixir, consumer)
 assert(elixir.count == 0 and #sounds == 4)

 return "atmosphere:15-5:light-floor:night-vision:audio-success-only:density-1.3:ok"
end
