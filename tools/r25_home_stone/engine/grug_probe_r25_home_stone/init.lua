-- Round 25 Lane D engine probe (disposable, never shipped): the Claim Stone
-- as travel home on the real engine. tools/r25_home_stone/engine/run.sh
-- stages it through tools/luanti_headless.sh.
--
-- A headless server has no client, so the "player" is a plain table with the
-- accessors grug_home reads; core.get_player_by_name and chat_send_player are
-- intercepted for the probe name only. grug_housing.player_claim (a stub on
-- main until Lane A lands) is faked for the probe name only.
--   1. grug_home loaded with grug_housing first: its claim listener is live.
--   2. A faked claim home teleports into the arrival cube above a real stone
--      node in an emerged sky pocket, and charges the 30-minute cooldown.
--   3. A solid node in the arrival cube sends that trip to the innkeeper home.
--   4. notify_claim_changed(..., "destroyed") resets the home with a message.
-- Ends the server itself; "RESULT PASS" is the verdict line.
local PREFIX = "[r25_home_probe] "
local NAME = "r25_home_probe"
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
 checks = checks + 1
 if ok then log("ok   " .. label) else
  failures = failures + 1
  core.log("error", PREFIX .. "FAIL " .. label)
 end
 return ok
end
local done = false
local function finish()
 if done then return end
 done = true
 log(("RESULT %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
  checks, failures))
 core.request_shutdown("r25 home stone probe done", false, 0)
end

-- Probe player ------------------------------------------------------------
local holder = ItemStack("default:stick")
local chat = {}
local player = {pos = vector.new(0, 300, 0), hp = 20}
function player.get_player_name() return NAME end
function player.is_player() return true end
function player.get_meta() return holder:get_meta() end
function player.get_hp(self) return self.hp end
function player.get_pos(self) return vector.new(self.pos) end
function player.set_pos(self, pos) self.pos = vector.new(pos) end
function player.get_velocity() return vector.new(0, 0, 0) end
function player.add_velocity() end
function player.get_look_horizontal() return 0 end
local get_player_by_name = core.get_player_by_name
core.get_player_by_name = function(name)
 if name == NAME then return player end
 return get_player_by_name(name)
end
local chat_send_player = core.chat_send_player
core.chat_send_player = function(name, message)
 if name == NAME then chat[#chat + 1] = message; log("chat: " .. message); return end
 return chat_send_player(name, message)
end
local meta = player.get_meta()
meta:set_string("grug_factions:faction", "accord")
meta:set_string("grug_classes:race", "human")

-- Faked claim ---------------------------------------------------------------
local claim, state = nil, "never"
local player_claim = grug_housing.player_claim
grug_housing.player_claim = function(name)
 if name == NAME then return claim, state end
 return player_claim(name)
end

local function wait_for(predicate, timeout, then_fn, label)
 local waited = 0
 local function poll()
  if predicate() then return then_fn(true) end
  waited = waited + 0.5
  if waited >= timeout then check(false, label .. " (timed out)"); return then_fn(false) end
  core.after(0.5, poll)
 end
 poll()
end

local function run()
 check(type(grug_home.set_home_claim) == "function" and
  type(grug_home.home_is_claim) == "function", "grug_home exports the claim API")
 check(grug_home.get(player).id == "dawnmere" and not grug_home.home_is_claim(player),
  "probe player starts with the innkeeper home")
 local ok = grug_home.set_home_claim(player)
 check(not ok, "set_home_claim refuses without a placed claim")

 local start = grug_core.start_position("accord", "human")
 local center = vector.new(math.floor(start.x) + 40, 260, math.floor(start.z) + 40)
 local started = core.get_us_time()
 core.emerge_area(vector.offset(center, -16, -8, -16), vector.offset(center, 16, 8, 16),
  function(_, _, remaining)
   if remaining > 0 then return end
   core.after(0, function()
    log(("sky pocket emerged in %.1f s at %s"):format((core.get_us_time() - started) / 1e6,
     core.pos_to_string(center)))
    core.set_node(center, {name = "default:stone"})
    claim = {id = "probe-1", owner = NAME, center = vector.new(center),
     placed_at = os.time(), paid_until = os.time() + 3600}
    state = "placed"
    local set_ok, message = grug_home.set_home_claim(player)
    check(set_ok and grug_home.home_is_claim(player), "set_home_claim: " .. tostring(message))
    local arrival = grug_housing.arrival_pos(claim)
    local cell = vector.round(arrival)
    local feet = vector.new(cell.x, cell.y - 0.49, cell.z)
    log("arrival_pos " .. core.pos_to_string(arrival) .. ", expected feet " ..
     core.pos_to_string(feet) .. ", node there " .. core.get_node(cell).name)
    check(grug_home.return_home(player), "return_home accepted")
    wait_for(function() return not grug_home.is_pending(player) end, 60, function()
     log("after travel: pos " .. core.pos_to_string(player.pos) .. " remaining " ..
      grug_home.remaining(player))
     check(vector.distance(player.pos, feet) < 0.01, "teleported into the arrival cube")
     -- Wall clock: the poll may land a second or two after the charge.
     check(grug_home.remaining(player) >= 1795, "30-minute cooldown charged")
     -- Blocked cube: this trip goes to the innkeeper home instead.
     core.set_node(cell, {name = "default:stone"})
     meta:set_string("grug_home:ready_at", "0")
     chat = {}
     local inn = grug_home.innkeeper(player)
     check(grug_home.return_home(player), "blocked: return_home accepted")
     wait_for(function() return not grug_home.is_pending(player) end, 120, function()
      log("after blocked travel: pos " .. core.pos_to_string(player.pos))
      local blocked_msg = false
      for _, line in ipairs(chat) do
       if line:find("arrival is blocked", 1, true) then blocked_msg = true end
      end
      check(blocked_msg, "blocked: fallback message")
      check(vector.distance(player.pos, inn.arrival) < 0.01,
       "blocked: arrived at the " .. inn.label .. " innkeeper")
      check(grug_home.home_is_claim(player), "blocked: claim stays the home")
      -- Destruction resets the home through the claim listener.
      chat = {}
      state, claim = "destroyed", claim
      grug_housing.notify_claim_changed(claim, "destroyed")
      check(not grug_home.home_is_claim(player) and grug_home.get(player).id == "dawnmere",
       "destroyed: home is the innkeeper again")
      check(chat[1] == "Your Claim Stone has been destroyed. Your home is now the Dawnmere Innkeeper.",
       "destroyed: message " .. tostring(chat[1]))
      finish()
     end, "blocked trip finished")
    end, "claim trip finished")
   end)
  end)
end

core.after(2, run)
core.after(280, function()
 if not done then check(false, "probe watchdog"); finish() end
end)
