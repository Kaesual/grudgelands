-- Round 29 waystones (WP17, docs/design/world.md section 6): one waystone at
-- the centre of every start's and capital's waypoint pad, placed by the
-- mapgen (`grug_mapgen:waystone`, whose right-click lands here), and since
-- Round 31 one on the waypoint pad of each faction's PvP fortress (pvp-plan
-- ruling 18). A faction's network is its three starts, three capitals and
-- its fortress: seven stones. Standing within reach of
-- an own-faction stone, or right-clicking it, discovers it for the
-- character; the own start counts as discovered from creation. From a stone
-- a player travels to any discovered stone of the network: instant, free,
-- no cooldown, alive and out of combat, through grug_home.travel (the home
-- return's own emerge, validation and teleport). Enemy stones are inert.
-- Since Round 45 (PT9) every list ends with the owner's activated Claim
-- Stone, "Your Claim Stone" (grug_home.claim_waypoint, claim_home.lua),
-- reached the same way and landing in its arrival cube; without one the
-- entry reads "No claim stone". The stone is an origin too: its owner travels
-- from it to the discovered waystones (grug_home.travel_from_claim, the stone
-- form's Waypoints tab).
local path = core.get_modpath(core.get_current_modname())
local rules = dofile(path .. "/waypoints_core.lua")
local KEY = "grug_home:waypoints"
local SIDES = {{x=1,z=0},{x=-1,z=0},{x=0,z=1},{x=0,z=-1}}

-- The registry: the `travel_waypoint` socket of every home location and of
-- both fortresses, which is the cell the mapgen wrote the waystone into.
-- Built at load like the innkeeper homes; a settlement without one is a
-- broken blueprint. A fortress has no innkeeper, so it is no home location:
-- its label and seat race come from the settlement registry by its key
-- (`r31_pvp_catalog.lua`).
local FORTRESSES = {{key="pvp_fortress_accord", faction="accord"},
 {key="pvp_fortress_throng", faction="throng"}}
local rows, by_id, by_cell = {}, {}, {}
local function cell_key(pos)
 return pos.x .. "," .. pos.y .. "," .. pos.z
end
local function add_row(id, label, faction, race, start)
 local socket
 for _, entry in ipairs(grug_core.settlement_sockets_at(id)) do
  if entry.id == "travel_waypoint" and entry.role == "waypoint" then socket = entry end
 end
 if not socket then
  error("[grug_home] waystone socket missing: " .. id, 0)
 end
 -- A socket without its own arrival side (the starts, the fortresses)
 -- arrives on +x first (arrival_at below).
 local row = {id=id, label=label, faction=faction, race=race, start=start,
  pos=socket.pos, side=socket.arrival}
 rows[#rows + 1] = row
 by_id[row.id] = row
 by_cell[cell_key(row.pos)] = row
end
for index, location in ipairs(grug_home.locations()) do
 add_row(location.id, location.label, location.faction, location.race, index <= 6)
end
local settlements = {}
for _, row in ipairs(grug_core.settlement_socket_settlements()) do settlements[row.key] = row end
for _, fortress in ipairs(FORTRESSES) do
 local row = settlements[fortress.key]
 if not row then error("[grug_home] fortress missing: " .. fortress.key, 0) end
 add_row(fortress.key, row.display_name or fortress.key, fortress.faction, row.race_id, false)
end

local function known_set(player)
 return rules.decode(player:get_meta():get_string(KEY))
end
local function race_of(player)
 return grug_core.get_player_race(player:get_player_name())
end

local function discover(player, set, row)
 set[row.id] = true
 player:get_meta():set_string(KEY, rules.encode(set, rows))
 local text = "Waypoint discovered: " .. row.label
 grug_core.flash(player, text, grug_core.FLASH_COLOR.notice)
 core.chat_send_player(player:get_player_name(), text)
end

-- The discovered stones of the player's own network, for the map markers.
function grug_home.known_waypoints(player)
 local set, race, result = known_set(player), race_of(player), {}
 for _, row in ipairs(rules.network(rows, grug_factions.get_faction(player))) do
  if rules.known(set, row, race) then
   result[#result + 1] = {id=row.id, label=row.label, pos=vector.new(row.pos)}
  end
 end
 return result
end

-- The first free side of the destination stone: the socket's own arrival
-- side first (a capital plot's turned +x, else +x), then the others.
local function arrival_at(row)
 local first = row.side or SIDES[1]
 local order = {first}
 for _, side in ipairs(SIDES) do
  if side.x ~= first.x or side.z ~= first.z then order[#order + 1] = side end
 end
 for _, side in ipairs(order) do
  local arrival = grug_home.safe_arrival(vector.offset(row.pos, side.x, -0.49, side.z))
  if arrival then return arrival end
 end
end

local dialogs, serial = {}, 0
local function form(player, origin)
 local entries = rules.entries(rows, grug_factions.get_faction(player),
  known_set(player), race_of(player), origin.id)
 entries[#entries + 1] = rules.claim_entry(grug_home.claim_waypoint(player))
 local fs = {"formspec_version[3]size[7,", tostring(1.9 + 0.7 * #entries), "]",
  "label[0.4,0.5;", core.formspec_escape(origin.label .. " Waystone"), "]"}
 for index, entry in ipairs(entries) do
  local y = 0.6 + 0.7 * index
  fs[#fs + 1] = ("label[0.4,%.2f;%s]"):format(y, core.formspec_escape(entry.row.label))
  if entry.state == "here" then
   fs[#fs + 1] = ("label[4.2,%.2f;You are here]"):format(y)
  elseif entry.state == "travel" then
   fs[#fs + 1] = ("button[4.2,%.2f;2.4,0.6;go_%s;Travel]"):format(y - 0.3,
    entry.row.claim and rules.CLAIM_ID or entry.row.id)
  elseif entry.state == "no_claim" then
   fs[#fs + 1] = ("label[4.2,%.2f;%s]"):format(y,
    core.colorize("#8a8a8a", "No claim stone"))
  else
   fs[#fs + 1] = ("label[4.2,%.2f;%s]"):format(y,
    core.colorize("#8a8a8a", "Not yet visited"))
  end
 end
 fs[#fs + 1] = ("button_exit[4.9,%.2f;1.7,0.6;close;Close]"):format(1.1 + 0.7 * #entries)
 return table.concat(fs)
end

-- Right-click on a waystone (grug_mapgen's node). Discovers an own-faction
-- stone and opens its travel list; an enemy stone only answers with the
-- refusal line every service of the other faction gives (Round 31).
function grug_home.use_waystone(player, pos)
 local row = by_cell[cell_key(vector.round(pos))]
 local name = player:get_player_name()
 if not row then return end
 if player:get_hp() <= 0 then return end
 if not grug_factions.serves(row.faction, player) then
  grug_factions.refuse(player, "Waystone", row.faction)
  return
 end
 local set = known_set(player)
 if not rules.known(set, row, race_of(player)) then discover(player, set, row) end
 serial = serial + 1
 local formname = "grug_home:waystone:" .. serial
 dialogs[name] = {formname=formname, origin=row.id}
 core.show_formspec(name, formname, form(player, row))
end

-- Whether the player stands at the origin: a waystone's reach, or that of
-- the owner's Claim Stone while it is still the same activated stone.
local function at_origin(player, origin)
 if origin.claim then
  local current = grug_home.claim_waypoint(player)
  if not current or current.id ~= origin.id then return false end
 end
 return rules.near(origin, player:get_pos())
end

-- Starts a trip from `origin` (a waystone, or the owner's Claim Stone) to
-- `target` (a waystone, or the Claim Stone): ok, or false and the refusal.
-- On the server step after the emerge the trip still needs the same living,
-- out-of-combat player of the same faction at the origin, and a Claim Stone
-- target still the owner's activated stone.
local function start_trip(player, origin, target)
 local name = player:get_player_name()
 local faction = grug_factions.get_faction(player)
 local refusal = rules.refusal({alive=player:get_hp() > 0, faction=faction,
  race=race_of(player), set=known_set(player), origin=origin, target=target,
  at_origin=origin ~= nil and at_origin(player, origin),
  in_combat=grug_core.in_combat(player), pending=grug_home.is_pending(player)})
 if refusal then return false, refusal end
 local unavailable = target.claim and
  "Your Claim Stone cannot be reached right now. Please try again." or
  "The " .. target.label .. " waystone cannot be reached right now. Please try again."
 return grug_home.travel(player, {pos=target.pos, unavailable=unavailable,
  check=function(p)
   if p:get_hp() <= 0 or grug_factions.get_faction(p) ~= faction then return false end
   if grug_core.in_combat(p) or not at_origin(p, origin) then
    core.chat_send_player(name, "Travel canceled.")
    return false
   end
   if target.claim then
    local current = grug_home.claim_waypoint(p)
    if not current or current.id ~= target.id then
     core.chat_send_player(name, "Your Claim Stone is gone. Travel canceled.")
     return false
    end
   end
   return true
  end,
  arrival=function()
   if not target.claim then return arrival_at(target) end
   -- Emerged, but the arrival cube is not free (as Return home says it).
   local arrival = grug_home.claim_arrival(target)
   if not arrival then return nil, "Your Claim Stone's arrival is blocked." end
   return arrival
  end}), "Travel is already being prepared."
end

core.register_on_player_receive_fields(function(player, formname, fields)
 if formname:sub(1, 19) ~= "grug_home:waystone:" then return false end
 local name = player:get_player_name()
 local dialog = dialogs[name]
 if not dialog or dialog.formname ~= formname then return true end
 if fields.quit then dialogs[name] = nil; return true end
 local target
 for field in pairs(fields) do
  local id = field:match("^go_(.+)$")
  if id == rules.CLAIM_ID then
   target = grug_home.claim_waypoint(player)
   if not target then
    core.chat_send_player(name, "You have no activated Claim Stone.")
    return true
   end
  elseif id then
   target = by_id[id]
  end
 end
 if not target then return true end
 local ok, refusal = start_trip(player, by_id[dialog.origin], target)
 if not ok then
  core.chat_send_player(name, refusal)
  return true
 end
 dialogs[name] = nil
 core.close_formspec(name, formname)
 return true
end)

-- Round 45 PT9 follow-up: the owner's activated Claim Stone is an origin as
-- well (the stone form's Waypoints tab, grug_housing/stone_form.lua): from it
-- to any discovered waystone of the own network, by the waystones' rules.
-- Returns ok, or false and the refusal line.
function grug_home.travel_from_claim(player, id)
 local origin = grug_home.claim_waypoint(player)
 if not origin then return false, "You have no activated Claim Stone." end
 return start_trip(player, origin, by_id[id])
end

-- Discovery by proximity: once a second, every player against the stones of
-- their own network.
local elapsed = 0
core.register_globalstep(function(dtime)
 elapsed = elapsed + dtime
 if elapsed < 1 then return end
 elapsed = 0
 for _, player in ipairs(core.get_connected_players()) do
  local faction = grug_factions.get_faction(player)
  if faction and player:get_hp() > 0 then
   local set = known_set(player)
   for _, row in ipairs(rules.newly_found(rows, faction, set, race_of(player),
     player:get_pos())) do
    discover(player, set, row)
   end
  end
 end
end)

local function clear(player) dialogs[player:get_player_name()] = nil end
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
