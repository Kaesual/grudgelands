local COOLDOWN = 1800
local pending, sessions = {}, {}
local function name_of(player) return player:get_player_name() end
local function notify(player, message) core.chat_send_player(name_of(player), message) end
local function teleport(player, position)
 grug_mounts.dismount(player, nil, true)
 grug_core.invalidate_combat_identity(player)
 player:set_pos(position)
 local velocity = player:get_velocity()
 if velocity then
  player:add_velocity({x=-velocity.x,y=-velocity.y,z=-velocity.z})
 end
end
function grug_home.cancel(player)
 local name = name_of(player)
 pending[name] = nil
 sessions[name] = {}
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

-- Travel goes to grug_home.get (a placed Claim Stone or the innkeeper home);
-- respawn always goes to the innkeeper home.
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
 local identity = {session=sessions[name], id=row.id,
  faction=grug_factions.get_faction(player), race=grug_core.get_player_race(name)}
 local function land(p, arrival)
  teleport(p, arrival)
  local actual = p:get_pos()
  if actual and vector.distance(actual, arrival) < 0.1 then
   if not respawn then
    p:get_meta():set_string("grug_home:ready_at", tostring(os.time() + COOLDOWN))
   end
  end
 end
 -- Prepares one destination and calls arrive(player, current home, failed)
 -- on the normal server step. Each phase owns its own pending token.
 local function prepare(target, arrive)
  local phase = {identity=identity}
  pending[name] = phase
  local failed, finished = false, false
  local function finish()
   if finished then return end
   finished = true
   -- Defer out of emerge callbacks: all state and node queries are performed
   -- together on the normal server step immediately before the teleport.
   core.after(0, function()
    if pending[name] ~= phase or sessions[name] ~= identity.session then return end
    pending[name] = nil
    local p = core.get_player_by_name(name)
    if not p or p:get_hp() <= 0 then return end
    local current = resolve(p)
    if not current or current.id ~= identity.id or
      grug_factions.get_faction(p) ~= identity.faction or
      grug_core.get_player_race(name) ~= identity.race then return end
    if not respawn and (grug_core.in_combat(p) or grug_home.remaining(p) > 0) then
     notify(p, "Return home canceled."); return
    end
    arrive(p, current, failed)
   end)
  end
  core.emerge_area(vector.offset(target.pos,-16,-8,-16), vector.offset(target.pos,16,8,16),
   function(_, action, remaining)
    if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then failed = true end
    if remaining == 0 then finish() end
   end)
  -- A stalled emerge must not lock the button forever; later callbacks cannot
  -- complete after this token has been released.
  core.after(30, function()
   if pending[name] == phase then
    pending[name] = nil
    local p = core.get_player_by_name(name)
    if p then notify(p, "Home arrival timed out. Please try again.") end
   end
  end)
 end
 local function unavailable(p) notify(p, "Home arrival is unavailable. Please try again.") end
 prepare(row, function(p, current, failed)
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
  prepare(inn, function(q, _, inn_failed)
   local fallback = grug_home.innkeeper(q)
   fallback = not inn_failed and fallback and safe_arrival(fallback)
   if not fallback then return unavailable(q) end
   land(q, fallback)
  end)
 end)
 return true
end
function grug_home.return_home(player) return request(player, false) end
function grug_home.respawn(player)
 grug_home.cancel(player)
 if not grug_home.innkeeper(player) then return false end
 -- A revived player must not wait at the death location if emerge fails.
 -- Starts are generated during world preparation; load only this saved pocket
 -- synchronously, validate its floor/headroom, then await the bound home there.
 local spawn = grug_core.start_position(grug_factions.get_faction(player),
  grug_core.get_player_race(name_of(player)))
 if not spawn then return false end
 core.load_area(vector.offset(spawn,-2,-2,-2),vector.offset(spawn,2,3,2))
 local fallback = safe_arrival({pos=spawn})
 if not fallback then return false end
 teleport(player, fallback)
 return request(player, true)
end
core.register_on_joinplayer(grug_home.cancel)
core.register_on_leaveplayer(function(player)
 local name = name_of(player)
 pending[name], sessions[name] = nil, nil
end)
core.register_on_dieplayer(grug_home.cancel)
