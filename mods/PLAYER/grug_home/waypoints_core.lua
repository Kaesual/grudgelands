-- The waystone rules (Round 29, WP17; docs/design/world.md section 6), pure:
-- no engine calls, so tools/r29_w/portable_test.lua runs them as they ship.
--
-- A row is one waystone: {id, label, faction, race, start, pos}. `start` is
-- true for the six starts; the others are the six capitals and the two PvP
-- fortresses (Round 31). A faction's network is its own seven rows.
-- Discovery is per character: the stored list plus the character's own
-- start, which counts as discovered from creation.

local M = {}

-- Unlock reach: horizontal distance, and the same height either way.
M.REACH = 8

-- The stored list: waystone ids separated by single spaces.
function M.decode(text)
 local set = {}
 for id in string.gmatch(text or "", "%S+") do set[id] = true end
 return set
end

-- Always in the rows' own order, so the stored text never depends on table
-- iteration.
function M.encode(set, rows)
 local ids = {}
 for _, row in ipairs(rows) do
  if set[row.id] then ids[#ids + 1] = row.id end
 end
 return table.concat(ids, " ")
end

function M.network(rows, faction)
 local result = {}
 for _, row in ipairs(rows) do
  if faction ~= nil and row.faction == faction then result[#result + 1] = row end
 end
 return result
end

function M.known(set, row, race)
 return set[row.id] == true or (row.start == true and row.race == race)
end

function M.near(row, pos)
 if type(pos) ~= "table" then return false end
 local dx, dy, dz = pos.x - row.pos.x, pos.y - row.pos.y, pos.z - row.pos.z
 return dy <= M.REACH and dy >= -M.REACH and dx * dx + dz * dz <= M.REACH * M.REACH
end

-- The own-faction waystones within reach of `pos` that are not yet known.
function M.newly_found(rows, faction, set, race, pos)
 local result = {}
 for _, row in ipairs(M.network(rows, faction)) do
  if not M.known(set, row, race) and M.near(row, pos) then
   result[#result + 1] = row
  end
 end
 return result
end

-- Round 45 PT9: the owner's activated Claim Stone is a waypoint of its own,
-- the last entry of every list. Its button is always CLAIM_ID; without a
-- stone (none, a draft, picked up or destroyed) the entry reads "No claim
-- stone".
M.CLAIM_ID = "claim"
M.CLAIM_LABEL = "Your Claim Stone"

-- The travel list shown at waystone `here_id`: every own-faction waystone in
-- order, each "here", "travel" (known) or "unknown", then the Claim Stone:
-- "travel" with `claim` (its row), else "no_claim".
function M.entries(rows, faction, set, race, here_id, claim)
 local result = {}
 for _, row in ipairs(M.network(rows, faction)) do
  local state = row.id == here_id and "here" or
   (M.known(set, row, race) and "travel" or "unknown")
  result[#result + 1] = {row = row, state = state}
 end
 if faction ~= nil then
  result[#result + 1] = claim and {row = claim, state = "travel"} or
   {row = {id = M.CLAIM_ID, label = M.CLAIM_LABEL}, state = "no_claim"}
 end
 return result
end

-- Why a trip from `origin` to `target` may not start, or nil when it may.
-- `t`: alive, faction, race, set, origin, target, at_origin, in_combat,
-- pending. Travel is free and has no cooldown, so nothing else refuses it.
-- A Claim Stone target (a row with `claim`) needs no visit.
function M.refusal(t)
 if not t.alive then return "You cannot travel now." end
 if not t.origin or t.faction == nil or t.origin.faction ~= t.faction then
  return "This waystone does not answer you."
 end
 if not t.at_origin then return "Stand at the waystone to travel." end
 if not t.target or t.target.faction ~= t.faction then
  return "That waystone is not on your path."
 end
 if t.target.id == t.origin.id then return "You are already here." end
 if not t.target.claim and not M.known(t.set or {}, t.target, t.race) then
  return "You have not visited that waystone yet."
 end
 if t.in_combat then return "Cannot travel in combat." end
 if t.pending then return "Travel is already being prepared." end
 return nil
end

return M
