-- Round 29 Lane W portable test (LuaJIT): waystone travel (WP17).
--
--   luajit tools/r29_w/portable_test.lua [REPO]
--
-- A. The pure rules (grug_home/waypoints_core.lua): the stored list, a
--    faction's network, the own start known from creation, the unlock reach
--    (8 horizontal, 8 up or down), the travel list states and every travel
--    refusal (dead, enemy origin, away from the origin, enemy or same
--    target, not yet visited, combat, a trip already pending).
-- B. The shipped grug_home (init, travel, waypoints) on a fake engine:
--    proximity discovery once a second with one message, enemy stones never
--    unlocked, right-click on an own stone discovers it and lists the seven
--    own stones (Round 31: the fortress is the seventh) (here / Travel / Not yet visited), right-click on an enemy
--    stone answers with a line only; travel refused in combat, to an
--    unvisited stone and to an enemy stone; a trip emerges, dismounts and
--    arrives beside the destination stone (the next free side when the
--    first is blocked), never touches the home cooldown, is canceled by
--    combat during the emerge, stays in place when no side is free, and a
--    second request while one is pending is refused.
-- C. The mapgen data: every start blueprint has one waystone, at its
--    `travel_waypoint` socket, on a signature-stone cross; every capital
--    core has one at its socket; the shared stable publishes the
--    `shipwright` socket beside the Riding Trainer, clear of the mount
--    lanes, and the socket registry accepts the role.
-- Prints "R29 W PORTABLE PASS checks=<n>" or raises on the first failure.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
 checks = checks + 1
 if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- A: rules
-- ---------------------------------------------------------------------------
local R = dofile(repo .. "/mods/PLAYER/grug_home/waypoints_core.lua")
local function row(id, faction, race, start, x, y, z)
 return {id=id, label=id, faction=faction, race=race, start=start, pos={x=x, y=y, z=z}}
end
local ROWS = {
 row("hearth", "accord", "dwarf", true, 0, 10, 0),
 row("dawn", "accord", "human", true, 100, 10, 0),
 row("sunscar", "throng", "orc", true, 200, 10, 0),
 row("highcourt", "accord", "human", false, 300, 10, 0),
 row("gor", "throng", "orc", false, 400, 10, 0),
}
check(next(R.decode("")) == nil and R.decode(nil) and next(R.decode(nil)) == nil, "A empty list")
local set = R.decode("highcourt  dawn")
check(set.highcourt and set.dawn and not set.hearth, "A decode")
check(R.encode({highcourt=true, dawn=true, gor=true}, ROWS) == "dawn highcourt gor", "A encode in row order")
local accord = R.network(ROWS, "accord")
check(#accord == 3 and accord[1].id == "hearth" and accord[3].id == "highcourt", "A network order")
check(#R.network(ROWS, nil) == 0, "A no faction, no network")
check(R.known({}, ROWS[2], "human") and not R.known({}, ROWS[1], "human"), "A own start known")
check(not R.known({}, ROWS[4], "human") and R.known({highcourt=true}, ROWS[4], "human"), "A capital by list")
local hc = ROWS[4]
check(R.near(hc, {x=308, y=10, z=0}) and R.near(hc, {x=300, y=18, z=0}) and
 R.near(hc, {x=300, y=2, z=0}), "A reach edges inside")
check(not R.near(hc, {x=306, y=10, z=6}) and not R.near(hc, {x=300, y=19, z=0}) and
 not R.near(hc, {x=300, y=1, z=0}) and not R.near(hc, nil), "A reach edges outside")
local found = R.newly_found(ROWS, "accord", {}, "human", {x=301, y=10, z=1})
check(#found == 1 and found[1].id == "highcourt", "A newly found")
check(#R.newly_found(ROWS, "accord", {highcourt=true}, "human", {x=301, y=10, z=1}) == 0, "A known not found again")
check(#R.newly_found(ROWS, "accord", {}, "human", {x=401, y=10, z=0}) == 0, "A enemy stone never found")
local entries = R.entries(ROWS, "accord", {}, "human", "highcourt")
check(#entries == 3 and entries[1].state == "unknown" and entries[2].state == "travel" and
 entries[3].state == "here", "A entries")
local base = {alive=true, faction="accord", race="human", set={}, origin=hc, target=ROWS[2],
 at_origin=true, in_combat=false, pending=false}
local function refusal(changes)
 local t = {}
 for k, v in pairs(base) do t[k] = v end
 for k, v in pairs(changes or {}) do t[k] = v end
 return R.refusal(t)
end
check(refusal() == nil, "A allowed")
check(refusal({alive=false}) ~= nil, "A dead")
check(refusal({origin=ROWS[5]}) == "This waystone does not answer you.", "A enemy origin")
check(refusal({faction=false}) ~= nil, "A no faction")
check(refusal({at_origin=false}) == "Stand at the waystone to travel.", "A away from origin")
check(refusal({target=ROWS[3]}) == "That waystone is not on your path.", "A enemy target")
check(refusal({target=hc}) == "You are already here.", "A same stone")
check(refusal({target=ROWS[1]}) == "You have not visited that waystone yet.", "A unvisited")
check(refusal({target=ROWS[1], set={hearth=true}}) == nil, "A visited")
check(refusal({in_combat=true}) == "Cannot travel in combat.", "A combat")
check(refusal({pending=true}) == "Travel is already being prepared.", "A pending")

-- ---------------------------------------------------------------------------
-- B: the shipped module on a fake engine
-- ---------------------------------------------------------------------------
local callbacks = {join={}, leave={}, die={}, fields={}, respawn={}, step={}}
local after, emerge, chat, flashes = {}, {}, {}, {}
local formname, formspec, closed
local function register(kind) return function(fn) callbacks[kind][#callbacks[kind] + 1] = fn end end
local vmeta = {}
local function vnew(x, y, z)
 if type(x) == "table" then return setmetatable({x=x.x, y=x.y, z=x.z}, vmeta) end
 return setmetatable({x=x, y=y, z=z}, vmeta)
end
local function round(n) return math.floor(n + 0.5) end
rawset(_G, "vector", {new=vnew,
 offset=function(p, x, y, z) return vnew(p.x + x, p.y + y, p.z + z) end,
 round=function(p) return vnew(round(p.x), round(p.y), round(p.z)) end,
 distance=function(a, b)
  local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
 end})
-- World: "floor" up to y = 100, air above, per-cell overrides.
local cells = {}
local function key(p) return round(p.x) .. "," .. round(p.y) .. "," .. round(p.z) end
local player
rawset(_G, "core", {
 get_modpath=function(name) return repo .. "/mods/PLAYER/" .. name end,
 get_current_modname=function() return "grug_home" end,
 dir_to_yaw=function() return 0 end, load_area=function() end,
 register_on_joinplayer=register("join"), register_on_leaveplayer=register("leave"),
 register_on_dieplayer=register("die"), register_on_player_receive_fields=register("fields"),
 register_on_respawnplayer=register("respawn"), register_globalstep=register("step"),
 get_player_by_name=function(name) if player and name == player:get_player_name() then return player end end,
 get_connected_players=function() return {player} end,
 get_mod_storage=function()
  local data = {}
  return {get_string=function(_, k) return data[k] or "" end,
   set_string=function(_, k, v) data[k] = v end}
 end,
 formspec_escape=function(s) return s end,
 colorize=function(_, s) return s end,
 chat_send_player=function(_, message) chat[#chat + 1] = message end,
 show_formspec=function(_, name, fs) formname, formspec = name, fs end,
 close_formspec=function(_, name) closed = name end,
 after=function(delay, fn) after[#after + 1] = {delay=delay, fn=fn} end,
 emerge_area=function(minp, maxp, fn)
  emerge[#emerge + 1] = {fn=fn, center=vnew((minp.x + maxp.x) / 2, (minp.y + maxp.y) / 2,
   (minp.z + maxp.z) / 2)}
 end,
 EMERGE_CANCELLED=1, EMERGE_ERRORED=2,
 get_node_or_nil=function(pos)
  local name = cells[key(pos)]
  if name then return {name=name} end
  return {name=round(pos.y) <= 100 and "floor" or "air"}
 end,
 registered_nodes={floor={walkable=true}, air={walkable=false}, stone={walkable=true},
  ["grug_mapgen:waystone"]={walkable=true, drawtype="nodebox"}},
})
local dismounts, generation = 0, 0
rawset(_G, "grug_core", {
 FLASH_COLOR={notice=1, error=2},
 flash=function(_, text) flashes[#flashes + 1] = text end,
 hold_movement=function() end, release_movement=function() end,
 get_player_race=function() return player.race end,
 in_combat=function(p) return p.combat end,
 invalidate_combat_identity=function() generation = generation + 1 end,
 start_position=function() return vnew(0, 101, 0) end,
 -- Round 41: the platform's map reset (grug_core/map_reset.lua), idle here.
 map_reset={register_on_relocate=function() end}})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
-- Every home location at x = 1000 * index; the innkeeper at the anchor, the
-- waystone 40 east of it, the anchor's ground at y = 100.
local LOCATIONS = dofile(repo .. "/mods/PLAYER/grug_home/locations.lua")
local STONE = {}
for i, location in ipairs(LOCATIONS) do
 local anchor = {x=i * 1000, y=100, z=0}
 grug_core.register_settlement_sockets(location.id, location.race, anchor,
  {{id=location.socket, role="idle", x=0, y=1, z=0, dir={x=0, z=1}},
   {id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}})
 STONE[location.id] = vnew(anchor.x + 40, 101, 0)
 cells[key(STONE[location.id])] = "grug_mapgen:waystone"
end
-- The two PvP fortresses (Round 31, the seventh stone of each network).
for i, fortress in ipairs({{"pvp_fortress_accord", "human", "Ashenward Bastion"},
  {"pvp_fortress_throng", "orc", "Bannerbreak Warhold"}}) do
 local anchor = {x=(#LOCATIONS + i) * 1000, y=100, z=0}
 grug_core.register_settlement_sockets(fortress[1], fortress[2], anchor,
  {{id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}}, fortress[3])
 STONE[fortress[1]] = vnew(anchor.x + 40, 101, 0)
 cells[key(STONE[fortress[1]])] = "grug_mapgen:waystone"
end
rawset(_G, "grug_mobs", {register_start_socket_role=function() end})
rawset(_G, "grug_mounts", {dismount=function() dismounts = dismounts + 1 end})
rawset(_G, "grug_factions", {get_faction=function(p) return p:get_meta():get_string("faction") end,
 display_name=function(id) return "The " .. id:sub(1, 1):upper() .. id:sub(2) end})
-- The shared refusal line (Round 31, ruling 13) on the fake faction table.
core.get_us_time = function() return 0 end
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
local data = {faction="accord"}
local meta = {get_string=function(_, k) return data[k] or "" end,
 set_string=function(_, k, v) data[k] = v end}
player = {race="human", hp=20, pos=vnew(0, 101, 0),
 get_player_name=function() return "tester" end, is_player=function() return true end,
 get_meta=function() return meta end, get_hp=function(self) return self.hp end,
 get_pos=function(self) return self.pos end,
 set_pos=function(self, p) self.pos = vnew(p) end}
dofile(repo .. "/mods/PLAYER/grug_home/init.lua")
local home = grug_home

local function deferred()
 local tasks = after; after = {}
 for _, task in ipairs(tasks) do
  if task.delay == 0 then task.fn() else after[#after + 1] = task end
 end
end
local function finish(action)
 local job = table.remove(emerge, 1); assert(job, "no pending emerge")
 job.fn(nil, action or 0, 0); deferred()
 return job
end
local function step() for _, fn in ipairs(callbacks.step) do fn(1.0) end end
local function fields(values)
 for _, fn in ipairs(callbacks.fields) do fn(player, formname, values) end
end
local function last_chat() return chat[#chat] or "" end
local function known() return data["grug_home:waypoints"] or "" end
local function drop_timeouts() local kept = {}
 for _, t in ipairs(after) do if t.delay ~= 30 then kept[#kept + 1] = t end end
 after = kept
end

-- Discovery by proximity.
player.pos = vnew(STONE.highcourt.x + 5, 101, 5)
step()
check(known() == "highcourt" and flashes[#flashes] == "Waypoint discovered: Highcourt" and
 last_chat() == "Waypoint discovered: Highcourt", "B proximity discovers with one message")
local messages = #chat
step()
check(#chat == messages and known() == "highcourt", "B discovered once")
player.pos = vnew(STONE.sunscar.x + 1, 101, 0); step()
check(known() == "highcourt", "B enemy stone not discovered by proximity")
player.pos = vnew(STONE.lethariel.x + 9, 101, 0); step()
check(known() == "highcourt", "B outside the reach")

-- Right-click on an enemy stone: a line, no list, nothing unlocked.
formspec = nil
home.use_waystone(player, STONE.sunscar)
check(formspec == nil and last_chat() == "<Waystone> I serve only The Throng." and
 known() == "highcourt", "B enemy stone inert")
-- Right-click on an own stone: discovered, list of seven.
player.pos = vnew(STONE.lethariel.x + 2, 101, 0)
home.use_waystone(player, STONE.lethariel)
check(known() == "highcourt lethariel", "B right-click discovers")
check(formspec and formspec:find("Lethariel Waystone", 1, true) and
 formspec:find("You are here", 1, true) and formspec:find("go_dawnmere", 1, true) and
 formspec:find("go_highcourt", 1, true) and not formspec:find("go_lethariel", 1, true) and
 not formspec:find("go_sunscar", 1, true), "B list: here, own start, discovered capital")
local _, unknown = formspec:gsub("Not yet visited", "")
check(unknown == 4, "B list: four not yet visited (with the fortress)")

-- Refusals.
player.combat = true; fields({go_highcourt="Travel"})
check(last_chat() == "Cannot travel in combat." and #emerge == 0, "B combat refused")
player.combat = false
fields({go_hearthpine="Travel"})
check(last_chat() == "You have not visited that waystone yet." and #emerge == 0, "B unvisited refused")
fields({go_sunscar="Travel"})
check(#emerge == 0, "B enemy target refused")
player.pos = vnew(STONE.lethariel.x + 20, 101, 0); fields({go_highcourt="Travel"})
check(last_chat() == "Stand at the waystone to travel." and #emerge == 0, "B away from origin")

-- A trip: emerge, dismount, beside the stone, no cooldown.
player.pos = vnew(STONE.lethariel.x + 2, 101, 0)
data["grug_home:ready_at"] = "12345"
fields({go_highcourt="Travel"})
check(#emerge == 1 and closed == formname, "B trip starts, list closes")
check(home.is_pending(player), "B pending while emerging")
home.use_waystone(player, STONE.lethariel); fields({go_dawnmere="Travel"})
check(last_chat() == "Travel is already being prepared." and #emerge == 1, "B second trip refused")
local job = finish()
check(job.center.x == STONE.highcourt.x and job.center.z == STONE.highcourt.z, "B emerges the destination")
check(player.pos.x == STONE.highcourt.x + 1 and player.pos.z == 0 and
 math.abs(player.pos.y - 100.51) < 1e-9, "B arrives beside the stone")
check(dismounts == 1 and generation == 1, "B dismounts, combat identity reset")
check(data["grug_home:ready_at"] == "12345" and not home.is_pending(player), "B home cooldown untouched")
drop_timeouts()

-- The first side blocked: the next free side.
cells[key(vnew(STONE.dawnmere.x + 1, 101, 0))] = "stone"
home.use_waystone(player, STONE.highcourt); fields({go_dawnmere="Travel"}); finish()
check(player.pos.x == STONE.dawnmere.x - 1 and player.pos.z == 0, "B next free side")
drop_timeouts()
-- Combat during the emerge cancels; no side free leaves the player in place.
home.use_waystone(player, STONE.dawnmere); fields({go_highcourt="Travel"})
player.combat = true; finish(); player.combat = false
check(player.pos.x == STONE.dawnmere.x - 1 and last_chat() == "Travel canceled.", "B combat during emerge")
drop_timeouts()
for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
 cells[key(vnew(STONE.highcourt.x + d[1], 102, d[2]))] = "stone"
end
home.use_waystone(player, STONE.dawnmere); fields({go_highcourt="Travel"}); finish()
check(player.pos.x == STONE.dawnmere.x - 1 and last_chat():find("cannot be reached", 1, true),
 "B no free side: stays with a message")
drop_timeouts()
-- A failed emerge and a stalled one leave the player in place.
home.use_waystone(player, STONE.dawnmere); fields({go_hearthpine="Travel"})
check(#emerge == 0, "B hearthpine still unvisited")
player.pos = vnew(STONE.hearthpine.x, 101, 3); step()
check(known() == "highcourt lethariel hearthpine" or known() == "hearthpine highcourt lethariel",
 "B hearthpine discovered")
home.use_waystone(player, STONE.hearthpine); fields({go_dawnmere="Travel"})
finish(core.EMERGE_ERRORED)
check(player.pos.x == STONE.hearthpine.x and last_chat():find("cannot be reached", 1, true),
 "B failed emerge stays")
home.use_waystone(player, STONE.hearthpine); fields({go_dawnmere="Travel"})
for _, t in ipairs(after) do if t.delay == 30 then t.fn() end end
check(not home.is_pending(player) and last_chat():find("cannot be reached", 1, true),
 "B stalled emerge releases")
table.remove(emerge, 1)
-- The map seam: known stones only, own network.
local marks = home.known_waypoints(player)
check(#marks == 4, "B known_waypoints: own start plus three discovered")
data.faction = "throng"
check(#home.known_waypoints(player) == 0, "B known_waypoints follows the faction")
data.faction = "accord"

-- ---------------------------------------------------------------------------
-- C: mapgen data
-- ---------------------------------------------------------------------------
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local RACE = {hearthpine="dwarf", dawnmere="human", silverleaf="elf", stillgrave="undead",
 sunscar="orc", kapok="troll"}
for start, race in pairs(RACE) do
 local bp = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_" .. start .. "_blueprint.lua")
 if type(bp) == "function" then bp = bp() end
 local socket
 for _, s in ipairs(bp.landmarks.sockets) do
  if s.id == "travel_waypoint" then socket = s end
 end
 check(socket and socket.role == "waypoint" and socket.y == 1, "C " .. start .. " socket")
 local at, stones = {}, 0
 for _, c in ipairs(bp.cells) do
  at[c.x .. "," .. c.y .. "," .. c.z] = c.name
  if c.name == "grug_mapgen:waystone" then stones = stones + 1 end
 end
 local sig = palettes.new(race).node("signature")
 check(stones == 1 and at[socket.x .. ",1," .. socket.z] == "grug_mapgen:waystone",
  "C " .. start .. " one waystone at the socket")
 local cross = true
 for d = -3, 3 do
  cross = cross and at[(socket.x + d) .. ",0," .. socket.z] == sig and
   at[socket.x .. ",0," .. (socket.z + d)] == sig
 end
 check(cross, "C " .. start .. " signature cross")
 local x1, z1 = socket.x + 1, socket.z
 -- Nothing written there (a blueprint that writes no air leaves the cleared
 -- pad above its ground course) or air.
 check((at[x1 .. ",1," .. z1] or "air") == "air" and (at[x1 .. ",2," .. z1] or "air") == "air",
  "C " .. start .. " arrival side open")
end
for _, capital in ipairs({"highcourt", "lethariel", "dur_brannoc", "gor_drazhak", "nhal_veyr", "kezamba"}) do
 local bp = dofile(wp13 .. "/" .. capital .. ".lua")(wp13).core()
 local socket
 for _, s in ipairs(bp.landmarks.sockets) do
  if s.id == "travel_waypoint" then socket = s end
 end
 local stones, here = 0, false
 for _, c in ipairs(bp.cells) do
  if c.name == "grug_mapgen:waystone" then
   stones = stones + 1
   here = c.x == socket.x and c.y == socket.y and c.z == socket.z
  end
 end
 check(stones == 1 and here, "C " .. capital .. " waystone at the socket")
end
local services = dofile(wp13 .. "/capital_services.lua")
local sockets = {{id="market_stable_gate_idle", role="idle", x=0, y=1, z=-6}}
services.decorate("highcourt", "market_stable", {put=function() end}, nil, sockets, nil)
local ship, trainer, resident
for _, s in ipairs(sockets) do
 if s.role == "shipwright" then ship = s end
 if s.role == "riding_trainer" then trainer = s end
 if s.role == "idle" and s.spawn ~= false then resident = s end
end
check(ship and trainer and ship.x == 8 and ship.z == trainer.z and resident.x == -8,
 "C shipwright beside the Riding Trainer, resident on the west fence")
for _, s in ipairs(sockets) do
 if s.role == "mount_display" or (s.tags and s.tags[1] == "mount_walk") then
  check(math.abs(s.x) <= 5, "C mount lanes stay inside x = +-5")
 end
end
grug_core.register_settlement_sockets("shipyard_probe", "human", {x=0, y=0, z=0},
 {{id="shipwright", role="shipwright", x=8, y=1, z=-6, dir={x=0, z=-1}}})
check(grug_core.settlement_sockets_at("shipyard_probe")[1].role == "shipwright", "C registry accepts shipwright")

print("R29 W PORTABLE PASS checks=" .. checks)
