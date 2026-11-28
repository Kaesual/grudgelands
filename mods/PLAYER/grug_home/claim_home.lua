-- Round 25 "Home stone" (docs/planning/round25-housing-plan.md, ruling 14):
-- the player's own placed Claim Stone can be the home. Arrival is the arrival
-- cube above the stone (travel.lua), with the usual cooldown on a return.
-- An unfuelled claim still counts; only pick-up and destruction reset the
-- target to the innkeeper home, with a message (at the next login when the
-- owner is offline). Respawn goes to the same home (Round 69, retiring Round
-- 25 ruling 25).
--
-- The target is stored as the claim id, never as a position; it is valid only
-- while grug_housing reports that very claim as the player's placed claim.
-- Round 86: a member of an account claim reads its account's claim (state
-- "member"), per character: each member sets it as home, travels and
-- respawns there, and every member hears of its loss.
local housing = rawget(_G, "grug_housing")
local CLAIM_KEY = "grug_home:claim"
local LOST_PREFIX = "claim_lost:"
local storage = core.get_mod_storage()

local function placed_claim(name)
 if not housing then return nil end
 local claim, state = housing.player_claim(name)
 if (state == "placed" or state == "member") and type(claim) == "table" and claim.id ~= nil and
   housing.is_owner(claim, name) and type(claim.center) == "table" then
  return claim
 end
end

-- `label` names the kind of home ("Home: Claim Stone" on the Character page
-- and the quickbar, the innkeeper's "Your home" line); `name` is the home's
-- own name (grug_housing.home_name, read afresh at every call, so a rename
-- shows at the next look), which the waystone list and the map show (Round
-- 89 ruling 6).
local function claim_row(player, claim)
 local faction = grug_factions.get_faction(player)
 local arrival = housing.arrival_pos(claim)
 if not faction or type(arrival) ~= "table" then return nil end
 local c = claim.center
 return {id="claim:" .. tostring(claim.id), claim=tostring(claim.id), faction=faction,
  label="Claim Stone", name=housing.home_name(claim), pos=vector.new(c.x,c.y,c.z),
  arrival=vector.new(arrival.x,arrival.y,arrival.z)}
end

-- THE home of return and respawn: the bound placed claim, else the innkeeper
-- home.
-- A claim row carries `claim` (its id); innkeeper rows do not.
function grug_home.get(player)
 local id = player:get_meta():get_string(CLAIM_KEY)
 if id ~= "" then
  local claim = placed_claim(player:get_player_name())
  local row = claim and tostring(claim.id) == id and claim_row(player, claim)
  if row then return row end
 end
 return grug_home.innkeeper(player)
end

-- Round 45 PT9: the owner's Claim Stone as a waypoint (labelled with the
-- home's name in every waystone's list since Round 89, waypoints.lua),
-- whether or not it is the travel home: the placed, activated claim's row,
-- else nil. A draft is none yet; an
-- unfuelled stone still is; it goes with the stone (pick-up, destruction, an
-- admin removal). Same id as the claim home row.
function grug_home.claim_waypoint(player)
 local claim = placed_claim(player:get_player_name())
 if not claim or (housing.is_draft and housing.is_draft(claim)) then return nil end
 local row = claim_row(player, claim)
 if row then
  row.label = row.name
  -- Round 86: the account stone's own look.
  row.texture = claim.kind == "account" and housing.ACCOUNT_STONE_TEXTURE or housing.STONE_TEXTURE
 end
 return row
end

function grug_home.home_is_claim(player)
 local row = grug_home.get(player)
 return row ~= nil and row.claim ~= nil
end

-- Called by the stone interface (owner only). Returns ok, message.
function grug_home.set_home_claim(player)
 if not player or not player.is_player or not player:is_player() then
  return false, "Only a player can set a home."
 end
 local name = player:get_player_name()
 local claim = placed_claim(name)
 if not claim then return false, "You have no placed Claim Stone." end
 -- Round 26 ruling 8: a draft is no home yet; it may crumble in minutes.
 if housing.is_draft and housing.is_draft(claim) then
  return false, "Activate your Claim Stone first."
 end
 if not claim_row(player, claim) then return false, "Your Claim Stone cannot be your home." end
 local id = tostring(claim.id)
 local meta = player:get_meta()
 if meta:get_string(CLAIM_KEY) == id then return true, "Your Claim Stone is already your home." end
 grug_home.cancel(player)
 meta:set_string(CLAIM_KEY, id)
 storage:set_string(LOST_PREFIX .. name, "")
 if housing.is_active(claim) then return true, "Your Claim Stone is now your home." end
 return true, "Your Claim Stone is now your home. It has no fuel, but you still travel and respawn there."
end

-- Binding an innkeeper makes it the home again (innkeeper.lua).
function grug_home.clear_home_claim(player)
 player:get_meta():set_string(CLAIM_KEY, "")
end

local LOST = {picked_up="was picked up", destroyed="has been destroyed",
 removed="was removed by an admin",
 -- Round 86: a member left its account's home (or lost the link).
 left="is no longer yours: you left your account's home",
 unlinked="is no longer yours: your character is no longer linked to its account",
 faction="is no longer yours: your faction changed"}
local function fall_back(player, event)
 grug_home.clear_home_claim(player)
 local inn = grug_home.innkeeper(player)
 core.chat_send_player(player:get_player_name(), "Your Claim Stone " ..
  (LOST[event] or "is gone") .. ". Your home is now " ..
  (inn and ("the " .. inn.label .. " Innkeeper") or "your innkeeper") .. ".")
end

-- Applies a recorded pick-up/destruction, then drops a claim target that is
-- no longer the player's placed claim (e.g. an event lost in a crash).
local function deliver(player)
 local name = player:get_player_name()
 local id = player:get_meta():get_string(CLAIM_KEY)
 local key = LOST_PREFIX .. name
 local lost = storage:get_string(key)
 if lost ~= "" then
  storage:set_string(key, "")
  local event, lost_id = lost:match("^(%S+) (.+)$")
  if id ~= "" and lost_id == id then fall_back(player, event); return end
 end
 if id ~= "" then
  local claim = placed_claim(name)
  if not claim or tostring(claim.id) ~= id then fall_back(player, nil) end
 end
end

-- Records the loss of `claim` for `name` and delivers it when online
-- (Round 86: also called by grug_housing when a member leaves).
function grug_home.claim_lost(name, claim, event)
 storage:set_string(LOST_PREFIX .. name, event .. " " .. tostring(claim.id))
 local player = core.get_player_by_name(name)
 if player then deliver(player) end
end

if housing then
 housing.register_on_claim_changed(function(claim, event)
  if not LOST[event] or type(claim) ~= "table" or
    type(claim.owner) ~= "string" or claim.id == nil then return end
  -- Round 86: every member of an account claim.
  for _, name in ipairs(housing.owner_names(claim)) do
   grug_home.claim_lost(name, claim, event)
  end
 end)
end
core.register_on_joinplayer(deliver)
-- The deletion of a character (Round 83; grug_core/character_delete.lua): its
-- pending notice goes. Listed after grug_housing's clear, whose claim removal
-- writes none anyway (the event "deleted" is no loss).
function grug_home.forget_character(name)
 storage:set_string(LOST_PREFIX .. name, "")
end
-- The platform's map reset (grug_core/map_reset.lua): the claim target is
-- map-bound player state; a relocated character's home is its innkeeper.
grug_core.map_reset.register_on_relocate(grug_home.clear_home_claim)
