local COOLDOWN = 1800
-- The movement-aggregator hold that keeps a respawned player in place, with no
-- gravity, until the home area is emerged (Round 28 ruling 16).
local RESPAWN_HOLD = "grug_home:respawn"
local pending, sessions = {}, {}
local function name_of(player) return player:get_player_name() end
local function notify(player, message) core.chat_send_player(name_of(player), message) end
-- A teleport only writes the position. It never adds a velocity derived from
-- get_velocity(): the server keeps a dead player's pre-impact speed (it ignores
-- a dead client's position packets), and subtracting it launched a respawned
-- player upward by about the speed of the lethal fall.
local function teleport(player, position)
 grug_mounts.dismount(player, nil, true)
 grug_core.invalidate_combat_identity(player)
 player:set_pos(position)
end
function grug_home.cancel(player)
 local name = name_of(player)
 pending[name] = nil
 sessions[name] = {}
 grug_core.release_movement(player, RESPAWN_HOLD)
end
function grug_home.remaining(player)
 local deadline = tonumber(player:get_meta():get_string("grug_home:ready_at")) or 0
 if deadline ~= deadline or deadline == math.huge or deadline == -math.huge then return 0 end
 return math.max(0, math.ceil(deadline - os.time()))
end
function grug_home.is_pending(player) return pending[name_of(player)] ~= nil end

-- A loaded, passable, dry and harmless cell a player may stand in.
local function passable(pos)
 local node = core.get_node_or_nil(pos)
 local def = node and core.registered_nodes[node.name]
 return def ~= nil and node.name ~= "ignore" and not def.walkable and
  not (def.liquidtype and def.liquidtype ~= "none") and
  (def.damage_per_second or 0) <= 0
end

-- The registry's fixed arrival stands on the top of a full ground node.
-- Ignore unloaded, liquid, damaging, partial-height and obstructed cells.
-- No player coordinate or alternate settlement can become the destination.
local function safe_arrival(row)
 local arrival = row.arrival or vector.offset(row.pos,1,-0.49,0)
 local ground = {x=arrival.x,y=math.floor(arrival.y),z=arrival.z}
 local floor = core.get_node_or_nil(ground)
 local def = floor and core.registered_nodes[floor.name]
 if not def or floor.name == "ignore" or not def.walkable or
   (def.drawtype and def.drawtype ~= "normal") or
   (def.liquidtype and def.liquidtype ~= "none") or
   (def.damage_per_second or 0) > 0 then return nil end
 for dy=1,2 do
  if not passable({x=ground.x,y=ground.y+dy,z=ground.z}) then return nil end
 end
 return vector.new(arrival)
end

-- A claim home arrives in the arrival cube above the Claim Stone. Lane A keeps
-- the cube free; stale claim data must still never put a player into a solid
-- node, so the arrival cell and the one above it are checked. The feet stand
-- on the arrival cell's floor (on the stone when the cell is the cube's
-- bottom layer).
local function claim_arrival(row)
 local cell = vector.round(row.arrival)
 if not passable(cell) or not passable({x=cell.x,y=cell.y+1,z=cell.z}) then return nil end
 return vector.new(cell.x, cell.y - 0.49, cell.z)
end

-- A respawn whose home cannot be prepared ends in the saved start pocket.
-- Starts are generated during world preparation, so this pocket is loaded
-- synchronously and its floor/headroom validated before the move.
local function start_fallback(player)
 local spawn = grug_core.start_position(grug_factions.get_faction(player),
  grug_core.get_player_race(name_of(player)))
 if not spawn then return false end
 core.load_area(vector.offset(spawn,-2,-2,-2),vector.offset(spawn,2,3,2))
 local arrival = safe_arrival({pos=spawn})
 if not arrival then return false end
 teleport(player, arrival)
 return true
end

-- THE ONE TRAVEL PATH: home return, respawn and the waystones
-- (waypoints.lua) all end here. `trip.pos` is the destination; its area is
-- emerged and then, deferred out of the emerge callbacks onto the normal
-- server step, `trip.check(player)` decides whether the trip still stands
-- (it tells the player itself when not) and `trip.arrive(player, failed)`
-- validates the arrival and moves the player through `teleport`. A stalled
-- emerge ends in `trip.timeout(player)` after 30 s instead of locking travel
-- forever. Each call owns its own pending token; a newer trip, a death, a
-- join or a leave (grug_home.cancel) makes every later callback a no-op.
local function prepare(name, trip)
 local session = sessions[name]
 local phase = {}
 pending[name] = phase
 local failed, finished = false, false
 local function finish()
  if finished then return end
  finished = true
  core.after(0, function()
   if pending[name] ~= phase or sessions[name] ~= session then return end
   pending[name] = nil
   local p = core.get_player_by_name(name)
   if p and trip.check(p) then trip.arrive(p, failed) end
  end)
 end
 core.emerge_area(vector.offset(trip.pos,-16,-8,-16), vector.offset(trip.pos,16,8,16),
  function(_, action, remaining)
   if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then failed = true end
   if remaining == 0 then finish() end
  end)
 core.after(30, function()
  if pending[name] == phase then
   pending[name] = nil
   local p = core.get_player_by_name(name)
   if p then trip.timeout(p) end
  end
 end)
end

-- Travel goes to grug_home.get (a placed Claim Stone or the innkeeper home);
-- respawn always goes to the innkeeper home: the bound one, else the
-- starting-town innkeeper (grug_home.innkeeper).
local function request(player, respawn)
 local name = name_of(player)
 local resolve = respawn and grug_home.innkeeper or grug_home.get
 local row = resolve(player)
 if not row then return false end
 if pending[name] then return false end
 if not respawn then
  if player:get_hp() <= 0 then return false end
  if grug_core.in_combat(player) then notify(player, "Cannot return home in combat."); return false end
  if grug_home.remaining(player) > 0 then notify(player, "Return home is cooling down."); return false end
 end
 sessions[name] = sessions[name] or {}
 local identity = {id=row.id, faction=grug_factions.get_faction(player),
  race=grug_core.get_player_race(name)}
 if respawn then
  -- The one respawn teleport: straight to the home's registry arrival, held
  -- there (no movement, no gravity) until the area is emerged and validated.
  -- The check below releases the hold on every path.
  grug_core.hold_movement(player, RESPAWN_HOLD)
  teleport(player, row.arrival)
  grug_sounds.play("respawn", player)
 end
 local function land(p, arrival)
  -- A respawned player already waits at the arrival; it is not moved again.
  local at = p:get_pos()
  if not (respawn and at and vector.distance(at, arrival) < 0.1) then
   teleport(p, arrival)
  end
  local actual = p:get_pos()
  if actual and vector.distance(actual, arrival) < 0.1 then
   if not respawn then
    p:get_meta():set_string("grug_home:ready_at", tostring(os.time() + COOLDOWN))
    grug_sounds.play("travel", p)
   end
  end
 end
 local function unavailable(p)
  if not respawn then
   return notify(p, "Home arrival is unavailable. Please try again.")
  end
  grug_core.release_movement(p, RESPAWN_HOLD)
  if p:get_hp() > 0 and start_fallback(p) then
   notify(p, "Your home could not be prepared. You woke in your starting town.")
  else
   notify(p, "Home arrival is unavailable.")
  end
 end
 -- The trip stands while the player lives and the home, faction and race
 -- are the ones it was asked for; a return also needs the player out of
 -- combat and the cooldown not restarted.
 local function check(p)
  if respawn then grug_core.release_movement(p, RESPAWN_HOLD) end
  if p:get_hp() <= 0 then return false end
  local current = resolve(p)
  if not current or current.id ~= identity.id or
    grug_factions.get_faction(p) ~= identity.faction or
    grug_core.get_player_race(name) ~= identity.race then return false end
  if not respawn and (grug_core.in_combat(p) or grug_home.remaining(p) > 0) then
   notify(p, "Return home canceled."); return false
  end
  return true
 end
 local function timeout(p)
  if respawn then return unavailable(p) end
  notify(p, "Home arrival timed out. Please try again.")
 end
 -- Prepares one destination and calls arrive(player, current home, failed).
 local function go(target, arrive)
  prepare(name, {pos=target.pos, check=check, timeout=timeout,
   arrive=function(p, failed) arrive(p, resolve(p), failed) end})
 end
 go(row, function(p, current, failed)
  if failed then return unavailable(p) end
  if not current.claim then
   local arrival = safe_arrival(current)
   if not arrival then return unavailable(p) end
   return land(p, arrival)
  end
  local arrival = claim_arrival(current)
  if arrival then return land(p, arrival) end
  -- Blocked arrival cube: this trip goes to the innkeeper home instead; the
  -- claim stays the travel home (only pick-up and destruction reset it).
  local inn = grug_home.innkeeper(p)
  if not inn then return unavailable(p) end
  notify(p, "Your Claim Stone's arrival is blocked. Returning to the " ..
   inn.label .. " Innkeeper instead.")
  go(inn, function(q, _, inn_failed)
   local fallback = grug_home.innkeeper(q)
   fallback = not inn_failed and fallback and safe_arrival(fallback)
   if not fallback then return unavailable(q) end
   land(q, fallback)
  end)
 end)
 return true
end

-- The waystones' entry into the same path (waypoints.lua). `trip.pos` is
-- the destination stone, `trip.check(player)` runs on the server step after
-- the emerge, `trip.arrival(player)` returns a validated arrival position or
-- nil, and `trip.unavailable` is the message for a failed preparation: the
-- player then stays where they are. Nothing is charged and the home cooldown
-- is not touched. Returns false while another trip is being prepared.
function grug_home.travel(player, trip)
 local name = name_of(player)
 if pending[name] then return false end
 sessions[name] = sessions[name] or {}
 prepare(name, {pos=trip.pos, check=trip.check,
  arrive=function(p, failed)
   local arrival = not failed and trip.arrival(p)
   if not arrival then return notify(p, trip.unavailable) end
   teleport(p, arrival)
   grug_sounds.play("travel", p)
  end,
  timeout=function(p) notify(p, trip.unavailable) end})
 return true
end

-- The arrival rule of every registry destination, for a position standing
-- on the top of the ground node below it (see safe_arrival).
function grug_home.safe_arrival(position)
 return safe_arrival({arrival=position})
end
function grug_home.return_home(player) return request(player, false) end
function grug_home.respawn(player)
 grug_home.cancel(player)
 return request(player, true)
end
core.register_on_joinplayer(grug_home.cancel)
core.register_on_leaveplayer(function(player)
 local name = name_of(player)
 pending[name], sessions[name] = nil, nil
end)
core.register_on_dieplayer(grug_home.cancel)
