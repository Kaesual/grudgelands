-- Round 29 waystones (WP17, docs/design/world.md section 6): one waystone at
-- the centre of every start's and capital's waypoint pad, placed by the
-- mapgen (`grug_mapgen:waystone`, whose right-click lands here). A faction's
-- network is its three starts and three capitals. Standing within reach of
-- an own-faction stone, or right-clicking it, discovers it for the
-- character; the own start counts as discovered from creation. From a stone
-- a player travels to any discovered stone of the network: instant, free,
-- no cooldown, alive and out of combat, through grug_home.travel (the home
-- return's own emerge, validation and teleport). Enemy stones are inert.
local path = core.get_modpath(core.get_current_modname())
local rules = dofile(path .. "/waypoints_core.lua")
local KEY = "grug_home:waypoints"
local SIDES = {{x=1,z=0},{x=-1,z=0},{x=0,z=1},{x=0,z=-1}}

-- The registry: the `travel_waypoint` socket of every home location, which
-- is the cell the mapgen wrote the waystone into. Built at load like the
-- innkeeper homes; a location without one is a broken blueprint.
local rows, by_id, by_cell = {}, {}, {}
local function cell_key(pos)
 return pos.x .. "," .. pos.y .. "," .. pos.z
end
for index, location in ipairs(grug_home.locations()) do
 local socket
 for _, entry in ipairs(grug_core.settlement_sockets_at(location.id)) do
  if entry.id == "travel_waypoint" and entry.role == "waypoint" then socket = entry end
 end
 if not socket then
  error("[grug_home] waystone socket missing: " .. location.id, 0)
 end
 local row = {id=location.id, label=location.label, faction=location.faction,
  race=location.race, start=index <= 6, pos=socket.pos, side=socket.arrival}
 rows[#rows + 1] = row
 by_id[row.id] = row
 by_cell[cell_key(row.pos)] = row
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
 local fs = {"formspec_version[3]size[7,", tostring(1.9 + 0.7 * #entries), "]",
  "label[0.4,0.5;", core.formspec_escape(origin.label .. " Waystone"), "]"}
 for index, entry in ipairs(entries) do
  local y = 0.6 + 0.7 * index
  fs[#fs + 1] = ("label[0.4,%.2f;%s]"):format(y, core.formspec_escape(entry.row.label))
  if entry.state == "here" then
   fs[#fs + 1] = ("label[4.2,%.2f;You are here]"):format(y)
  elseif entry.state == "travel" then
   fs[#fs + 1] = ("button[4.2,%.2f;2.4,0.6;go_%s;Travel]"):format(y - 0.3, entry.row.id)
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

core.register_on_player_receive_fields(function(player, formname, fields)
 if formname:sub(1, 19) ~= "grug_home:waystone:" then return false end
 local name = player:get_player_name()
 local dialog = dialogs[name]
 if not dialog or dialog.formname ~= formname then return true end
 if fields.quit then dialogs[name] = nil; return true end
 local target
 for field in pairs(fields) do
  local id = field:match("^go_(.+)$")
  if id then target = by_id[id] end
 end
 if not target then return true end
 local origin = by_id[dialog.origin]
 local faction = grug_factions.get_faction(player)
 local refusal = rules.refusal({alive=player:get_hp() > 0, faction=faction,
  race=race_of(player), set=known_set(player), origin=origin, target=target,
  at_origin=rules.near(origin, player:get_pos()),
  in_combat=grug_core.in_combat(player), pending=grug_home.is_pending(player)})
 if refusal then
  core.chat_send_player(name, refusal)
  return true
 end
 dialogs[name] = nil
 core.close_formspec(name, formname)
 -- On the server step after the emerge the trip still needs the same
 -- living, out-of-combat player of the same faction at the origin stone.
 grug_home.travel(player, {pos=target.pos, unavailable=
  "The " .. target.label .. " waystone cannot be reached right now. Please try again.",
  check=function(p)
   if p:get_hp() <= 0 or grug_factions.get_faction(p) ~= faction then return false end
   if grug_core.in_combat(p) or not rules.near(origin, p:get_pos()) then
    core.chat_send_player(name, "Travel canceled.")
    return false
   end
   return true
  end,
  arrival=function() return arrival_at(target) end})
 return true
end)

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
