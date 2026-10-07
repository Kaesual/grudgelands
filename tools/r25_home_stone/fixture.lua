-- Round 25 Lane D portable fixture (LuaJIT): the Claim Stone as travel home.
--
--   luajit tools/r25_home_stone/fixture.lua [repo]
--
-- Loads the shipped grug_home (init, claim_home, travel, innkeeper), the real
-- grug_factions respawn hook, the real grug_housing interface file (api.lua,
-- whose stubs are then replaced by fake claims) and the real Map provider and
-- page, on a fake engine. Covers:
--   R  the Round 17 innkeeper regression (binding, auth, combat, cooldown,
--      failed/blocked emerge, stale/duplicate callbacks, reconnect, timeout,
--      respawn safety (Round 28 ruling 16: one held teleport), map output) --
--      the retired tools/round17/home_micro.lua;
--   S  set_home_claim / home_is_claim (refusals, owner, unfuelled message,
--      Round 26: a draft is refused);
--   T  travel to the arrival cube, cooldown, respawn stays at the innkeeper;
--   E  an expired (unfuelled) claim is still the target;
--   B  blocked arrival cube (solid, liquid, no headroom) falls back to the
--      innkeeper for that trip, with a message, the claim stays the home;
--   F  pick-up and destruction reset the target with a message, the offline
--      message at the next login, other events do not reset, stale targets;
--   M  the Map marker/button for a claim home;
--   D  no mod.conf dependency path leads from grug_home back to itself.
-- Prints "R25 HOME STONE FIXTURE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
 checks = checks + 1
 if not ok then failures[#failures + 1] = label end
end

local clock = 10000
os.time = function() return clock end

local callbacks = {join={}, leave={}, die={}, fields={}, respawn={}, loaded={}, step={}}
local after, emerge = {}, {}
local player, online = nil, true
local formname, formspec
local chat = {}
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

-- World: full "floor" nodes up to y = 100, air above, plus per-cell overrides.
local ground_height, unloaded = 100, false
local cells = {}
local function key(p) return round(p.x) .. "," .. round(p.y) .. "," .. round(p.z) end
local storage_data = {}
rawset(_G, "core", {
 get_modpath=function(name) return repo .. "/mods/PLAYER/" .. name end,
 get_current_modname=function() return "grug_home" end,
 dir_to_yaw=function() return 0 end, load_area=function() end,
 register_on_joinplayer=register("join"), register_on_leaveplayer=register("leave"),
 register_on_dieplayer=register("die"), register_on_player_receive_fields=register("fields"),
 register_on_respawnplayer=register("respawn"), register_on_mods_loaded=register("loaded"),
 register_globalstep=register("step"), register_on_punchplayer=function() end,
 register_chatcommand=function() end, register_on_player_hpchange=function() end,
 global_exists=function(name) return rawget(_G, name) ~= nil end,
 get_player_by_name=function(name)
  if online and player and name == player:get_player_name() then return player end
 end,
 get_mod_storage=function()
  return {get_string=function(_, k) return storage_data[k] or "" end,
   set_string=function(_, k, v) storage_data[k] = v ~= "" and v or nil end,
   get_keys=function()
    local keys = {}
    for k in pairs(storage_data) do keys[#keys + 1] = k end
    return keys
   end}
 end,
 formspec_escape=function(s) return s end,
 chat_send_player=function(name, message) chat[#chat + 1] = message end,
 show_formspec=function(_, name, fs) formname, formspec = name, fs end,
 after=function(delay, fn) after[#after + 1] = {delay=delay, fn=fn} end,
 emerge_area=function(minp, maxp, fn)
  emerge[#emerge + 1] = {fn=fn, center=vnew((minp.x + maxp.x) / 2, (minp.y + maxp.y) / 2,
   (minp.z + maxp.z) / 2)}
 end,
 EMERGE_CANCELLED=1, EMERGE_ERRORED=2,
 get_node_or_nil=function(pos)
  if unloaded then return nil end
  local name = cells[key(pos)]
  if name then return {name=name} end
  return {name=round(pos.y) <= ground_height and "floor" or "air"}
 end,
 registered_nodes={floor={walkable=true}, air={walkable=false},
  stone={walkable=true}, ["grug_housing:claim_stone"]={walkable=true},
  water={walkable=false, liquidtype="source"}, torch={walkable=false, drawtype="torchlike"},
  fire={walkable=false, damage_per_second=4}},
 registered_entities={},
})

local generation, dismounts = 0, 0
local holds = {} -- the movement aggregator's exclusive holds, by name
rawset(_G, "grug_core", {factions={accord={}, throng={}},
 -- Round 41: the platform's map reset (grug_core/map_reset.lua), idle here.
 map_reset={clear=function() end, register_on_relocate=function() end},
 hold_movement=function(_, name) holds[name] = true end,
 release_movement=function(_, name) holds[name] = nil end,
 get_player_race=function() return player.race end,
 in_combat=function(p) return p.combat end,
 invalidate_combat_identity=function() generation = generation + 1 end,
 start_position=function() return vnew(0, 101, 0) end,
 zone_authority_installed=function() return true end})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local defs = dofile(repo .. "/mods/PLAYER/grug_home/locations.lua")
for i, row in ipairs(defs) do
 grug_core.register_settlement_sockets(row.id, row.race, {x=i * 100, y=100, z=0},
  {{id=row.socket, role="idle", x=0, y=1, z=0, dir={x=0, z=1}},
   -- Round 29: every home location carries its waystone (grug_home waypoints).
   {id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}})
end
-- Round 31: both PvP fortresses carry one too (no home location).
for i, row in ipairs({{"pvp_fortress_accord", "human"}, {"pvp_fortress_throng", "orc"}}) do
 grug_core.register_settlement_sockets(row[1], row[2], {x=(#defs + i) * 100, y=100, z=0},
  {{id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}})
end
rawset(_G, "grug_mobs", {register_start_socket_role=function(role, fn)
 assert(role == "innkeeper" and fn({}, {race_id="elf"}) == "grug_mobs:villager_elf")
end, dragon_map_markers=function() return {} end})
rawset(_G, "grug_mounts", {dismount=function() dismounts = dismounts + 1 end})
dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")

-- The real grug_housing interface file; claims are faked on top of it.
rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
local claim_listeners = {}
local register_claim_listener = grug_housing.register_on_claim_changed
grug_housing.register_on_claim_changed = function(fn)
 claim_listeners[#claim_listeners + 1] = fn
 return register_claim_listener(fn)
end
local claims = {} -- owner name -> {claim=..., state=...}
grug_housing.player_claim = function(name)
 local entry = claims[name]
 if not entry then return nil, "never" end
 return entry.claim, entry.state
end
grug_housing.is_active = function(claim) return (claim.paid_until or 0) > os.time() end
local function fire(claim, event)
 for _, fn in ipairs(claim_listeners) do fn(claim, event) end
end
local next_claim = 0
local function place_claim(owner, center, paid)
 next_claim = next_claim + 1
 local claim = {id=next_claim, owner=owner, center=vnew(center), placed_at=clock,
  activated_at=clock, paid_until=clock + (paid or 3600)}
 claims[owner] = {claim=claim, state="placed"}
 cells[key(center)] = "grug_housing:claim_stone"
 return claim
end
local function remove_claim(owner, event)
 local entry = claims[owner]
 cells[key(entry.claim.center)] = nil
 entry.state = event == "destroyed" and "destroyed" or "carried"
 if event == "picked_up" then entry.claim = nil end
 return entry
end

local data = {["grug_factions:faction"]="accord"}
local meta = {get_string=function(_, k) return data[k] or "" end,
 set_string=function(_, k, v) data[k] = v end}
local moves = 0
player = {race="human", hp=20, pos=vnew(0, 100, 0),
 get_player_name=function() return "tester" end, is_player=function() return true end,
 get_meta=function() return meta end, get_hp=function(self) return self.hp end,
 get_pos=function(self) return self.pos end,
 set_pos=function(self, p) self.pos = vnew(p); moves = moves + 1 end,
 get_velocity=function() return vnew(0, 0, 0) end, add_velocity=function() end,
 get_look_horizontal=function() return 0 end}
local before_home = {}
for kind, list in pairs(callbacks) do before_home[kind] = #list end
dofile(repo .. "/mods/PLAYER/grug_home/init.lua")
local home = grug_home
check(#claim_listeners == 1, "D grug_home registers one claim-change listener")

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
local function event(kind)
 for i = before_home[kind] + 1, #callbacks[kind] do callbacks[kind][i](player) end
end
local function fields(values, name)
 for _, fn in ipairs(callbacks.fields) do fn(player, name or formname, values) end
end
local function npc(id)
 local row = home.location(id)
 local e = {_grug_start=id, _grug_socket=row.socket, _grug_socket_role="innkeeper"}
 e.object = {get_pos=function() return row.pos end, get_luaentity=function() return e end}
 return e, row
end
local function last_chat() return chat[#chat] or "" end
local function same(a, b) return vector.distance(a, b) < 1e-9 end
local function drop_timeouts() local kept = {}
 for _, t in ipairs(after) do if t.delay ~= 30 then kept[#kept + 1] = t end end
 after = kept
end

-- ---------------------------------------------------------------------------
-- R: Round 17 innkeeper regression
-- ---------------------------------------------------------------------------
check(#home.locations() == 12 and home.get(player).id == "dawnmere", "R default racial home")
local inn, row = npc("highcourt"); player.pos = vnew(row.pos)
check(home.open_innkeeper(player, inn) and formspec:find("Set home here", 1, true), "R innkeeper form")
fields({bind=true}, "grug_home:innkeeper:bogus"); check(home.get(player).id == "dawnmere", "R bogus form")
fields({bind=true}); check(home.get(player).id == "highcourt", "R bind")
check(formspec:find("This is your home", 1, true), "R this is your home")
check(not home.open_innkeeper(player, (npc("sunscar"))), "R enemy innkeeper refused")
player.combat = true; check(not home.return_home(player), "R combat refused"); player.combat = false
check(home.return_home(player) and not home.return_home(player), "R single pending request")
finish(core.EMERGE_ERRORED); check(moves == 0 and home.remaining(player) == 0, "R failed emerge")
unloaded = true; check(home.return_home(player), "R request (unloaded)"); finish(); unloaded = false
check(moves == 0, "R unloaded arrival")
check(home.return_home(player), "R request"); finish()
check(moves == 1 and home.remaining(player) == 1800, "R arrival charges cooldown")
check(generation == 1 and dismounts == 1, "R dismount and combat identity")
clock = clock + 10; check(home.remaining(player) == 1790, "R cooldown counts down")
check(not home.return_home(player), "R cooldown refuses")
-- Round 28 ruling 16: one teleport, straight to the bound innkeeper, held
-- until the emerge finishes.
check(callbacks.respawn[1](player) and moves == 2 and holds["grug_home:respawn"],
 "R respawn: one teleport, held")
check(same(player.pos, home.location("highcourt").arrival), "R respawn straight to the innkeeper")
finish()
check(moves == 2 and not holds["grug_home:respawn"] and home.remaining(player) == 1790,
 "R respawn released, no second teleport, keeps cooldown")
clock = clock + 1800
check(home.return_home(player), "R cancel request"); home.cancel(player); finish(); check(moves == 2, "R cancel")
check(home.return_home(player), "R combat request"); player.combat = true; finish(); player.combat = false
check(moves == 2, "R combat before arrival")
check(home.return_home(player), "R die request"); player.hp = 0; event("die"); player.hp = 20; finish()
check(moves == 2, "R death cancels")
check(home.return_home(player), "R rebind request"); data["grug_home:id"] = "dawnmere"; finish()
check(moves == 2, "R rebind stale")
data["grug_home:id"] = "highcourt"
check(home.return_home(player), "R reconnect request"); event("leave")
do local replacement = {}; for k, v in pairs(player) do replacement[k] = v end; player = replacement end
event("join"); finish(); check(moves == 2, "R reconnect is a new session")
check(home.return_home(player), "R duplicate request")
do local job = table.remove(emerge, 1); job.fn(nil, 0, 0); job.fn(nil, 0, 0); deferred() end
check(moves == 3 and home.remaining(player) == 1800, "R duplicate callback commits once")
clock = clock + 1800
local before = moves
check(callbacks.respawn[1](player) and moves == before + 1, "R respawn to the innkeeper")
finish(core.EMERGE_ERRORED)
check(moves == before + 2 and same(player.pos, vnew(1, 100.51, 0)) and
 not holds["grug_home:respawn"] and home.remaining(player) == 0,
 "R failed respawn: released, falls back to the start pocket")
before = moves
check(home.return_home(player), "R timeout request")
do local tasks = after; after = {}
 for _, t in ipairs(tasks) do if t.delay == 30 then t.fn() end end end
check(not home.is_pending(player), "R timeout releases"); finish(); check(moves == before, "R late emerge inert")
player.pos = vnew(row.pos); check(home.open_innkeeper(player, inn), "R reopen")
player.pos = vnew(0, 0, 0); fields({bind=true})
check(home.get(player).id == "highcourt", "R proximity revalidated (still highcourt)")
data["grug_home:ready_at"] = tostring(clock + 77)
check(home.get(player).id == "highcourt" and home.remaining(player) == 77, "R persisted deadline")
clock = clock + 77
after = {}

-- ---------------------------------------------------------------------------
-- S: set_home_claim / home_is_claim
-- ---------------------------------------------------------------------------
chat = {}
local ok, message = home.set_home_claim(player)
check(not ok and message == "You have no placed Claim Stone.", "S refused without claim (never)")
claims.tester = {claim=nil, state="carried"}
ok = home.set_home_claim(player); check(not ok, "S refused while carried")
claims.tester = {claim={id=50, owner="someone", center=vnew(0, 101, 0)}, state="placed"}
ok = home.set_home_claim(player); check(not ok, "S refused for a foreign owner")
check(not home.set_home_claim({is_player=function() return false end}), "S refused for a non-player")
-- Round 26 ruling 8: a draft (activated_at 0, the real api.lua is_draft) is
-- no home yet.
claims.tester = {claim={id=51, owner="tester", center=vnew(0, 101, 0), placed_at=clock,
 activated_at=0, paid_until=clock}, state="placed"}
ok, message = home.set_home_claim(player)
check(not ok and message == "Activate your Claim Stone first.", "S refused for a draft")
check(not home.home_is_claim(player), "S a draft is not the home")
claims.tester = nil
local stone_pos = vnew(700, 101, 700)
local claim = place_claim("tester", stone_pos)
check(not home.home_is_claim(player), "S claim not home before setting")
ok, message = home.set_home_claim(player)
check(ok and message == "Your Claim Stone is now your home.", "S set home: " .. tostring(message))
check(home.home_is_claim(player) and home.get(player).label == "Claim Stone", "S home is claim")
check(home.innkeeper(player).id == "highcourt", "S innkeeper binding kept for respawn")
ok, message = home.set_home_claim(player)
check(ok and message:find("already", 1, true), "S set twice")

-- ---------------------------------------------------------------------------
-- T: travel to the arrival cube, cooldown, respawn stays at the innkeeper
-- ---------------------------------------------------------------------------
local arrival = grug_housing.arrival_pos(claim)
local feet = vnew(round(arrival.x), round(arrival.y) - 0.49, round(arrival.z))
check(feet.y == stone_pos.y + 0.51 or feet.y > stone_pos.y + 0.5, "T feet above the stone")
moves = 0
check(home.return_home(player), "T request")
do local job = finish(); check(same(job.center, stone_pos), "T emerge around the stone") end
check(moves == 1 and same(player.pos, feet), "T arrived in the cube")
check(home.remaining(player) == 1800, "T usual cooldown charged")
chat = {}
check(not home.return_home(player) and last_chat() == "Return home is cooling down.", "T cooldown refuses")
-- Respawn ignores the claim: the innkeeper home, cooldown untouched.
local highcourt = home.location("highcourt")
check(callbacks.respawn[1](player), "T respawn hook")
do local job = finish(); check(same(job.center, highcourt.pos), "T respawn prepares the innkeeper") end
check(moves == 2, "T respawn is one teleport")
check(same(player.pos, highcourt.arrival) and home.remaining(player) == 1800, "T respawn at innkeeper")
check(home.home_is_claim(player), "T respawn keeps the claim home")
clock = clock + 1800
-- A claim picked up while the trip is pending cannot teleport.
check(home.return_home(player), "T pending request")
remove_claim("tester", "picked_up"); fire(claim, "picked_up")
moves = 0; finish(); check(moves == 0, "T stale claim trip inert")
drop_timeouts()

-- ---------------------------------------------------------------------------
-- E: an expired claim is still the target
-- ---------------------------------------------------------------------------
claim = place_claim("tester", stone_pos, -60)
chat = {}
ok, message = home.set_home_claim(player)
check(ok and message:find("no fuel", 1, true), "E unfuelled set message")
fire(claim, "expired"); fire(claim, "fuel"); fire(claim, "permission")
check(home.home_is_claim(player) and #chat == 0, "E expired/fuel/permission do not reset")
check(home.return_home(player), "E request"); finish()
check(same(player.pos, feet) and home.remaining(player) == 1800, "E travel to expired claim")
clock = clock + 1800

-- ---------------------------------------------------------------------------
-- B: blocked arrival falls back to the innkeeper for that trip
-- ---------------------------------------------------------------------------
local cell = vector.round(arrival)
local function blocked_trip(label, pos, name)
 cells[key(pos)] = name
 chat = {}
 check(home.return_home(player), label .. " request")
 local first = finish(); check(same(first.center, stone_pos), label .. " claim prepared first")
 check(last_chat():find("arrival is blocked", 1, true) and last_chat():find("Highcourt Innkeeper", 1, true),
  label .. " message: " .. last_chat())
 local second = finish(); check(same(second.center, highcourt.pos), label .. " innkeeper prepared")
 check(same(player.pos, highcourt.arrival) and home.remaining(player) == 1800, label .. " at innkeeper")
 check(home.home_is_claim(player), label .. " claim stays home")
 cells[key(pos)] = nil
 clock = clock + 1800
 drop_timeouts()
end
blocked_trip("B solid", cell, "stone")
blocked_trip("B liquid", cell, "water")
blocked_trip("B headroom", vnew(cell.x, cell.y + 1, cell.z), "stone")
blocked_trip("B damaging", cell, "fire")
-- An emerge failure keeps the old behaviour: nothing charged, no fallback.
chat = {}
check(home.return_home(player), "B failed emerge request"); finish(core.EMERGE_ERRORED)
check(home.remaining(player) == 0 and last_chat():find("unavailable", 1, true) and #emerge == 0,
 "B failed emerge charges nothing")
drop_timeouts()
check(home.return_home(player), "B free again"); finish()
check(same(player.pos, feet), "B cube free again arrives")
clock = clock + 1800

-- ---------------------------------------------------------------------------
-- F: pick-up and destruction reset the target, with a message
-- ---------------------------------------------------------------------------
chat = {}
remove_claim("tester", "picked_up"); fire(claim, "picked_up")
check(not home.home_is_claim(player) and home.get(player).id == "highcourt", "F picked up resets")
check(last_chat() == "Your Claim Stone was picked up. Your home is now the Highcourt Innkeeper.",
 "F picked up message: " .. last_chat())
-- Destroyed while offline: message at the next login.
claim = place_claim("tester", stone_pos)
check(home.set_home_claim(player), "F set again")
chat = {}
online = false; event("leave")
remove_claim("tester", "destroyed"); fire(claim, "destroyed")
check(#chat == 0 and data["grug_home:claim"] == tostring(claim.id), "F offline: nothing yet")
online = true; event("join")
check(last_chat() == "Your Claim Stone has been destroyed. Your home is now the Highcourt Innkeeper.",
 "F offline message at login: " .. last_chat())
check(not home.home_is_claim(player) and home.get(player).id == "highcourt", "F offline reset")
chat = {}; event("join"); check(#chat == 0, "F message delivered once")
-- Round 26: an admin removal resets the home with its own wording.
claim = place_claim("tester", stone_pos)
check(home.set_home_claim(player), "F set for the admin removal")
chat = {}
remove_claim("tester", "destroyed"); fire(claim, "removed")
check(last_chat() == "Your Claim Stone was removed by an admin. Your home is now the Highcourt Innkeeper.",
 "F admin removal message: " .. last_chat())
check(not home.home_is_claim(player) and home.get(player).id == "highcourt", "F admin removal reset")
-- A lost claim that is not the home gives no message.
claim = place_claim("tester", stone_pos)
chat = {}
remove_claim("tester", "destroyed"); fire(claim, "destroyed")
check(#chat == 0 and home.get(player).id == "highcourt", "F non-home claim silent")
-- A stale target (event lost) is dropped at login.
claim = place_claim("tester", stone_pos)
check(home.set_home_claim(player), "F set for stale test")
claims.tester = {claim=nil, state="needs_stone"}
check(not home.home_is_claim(player) and home.get(player).id == "highcourt", "F stale target not used")
chat = {}; event("join")
check(last_chat() == "Your Claim Stone is gone. Your home is now the Highcourt Innkeeper.",
 "F stale target dropped at login: " .. last_chat())
-- Binding an innkeeper replaces the claim home.
claim = place_claim("tester", stone_pos)
check(home.set_home_claim(player), "F set for rebinding")
local dawn_inn, dawn = npc("dawnmere"); player.pos = vnew(dawn.pos)
check(home.open_innkeeper(player, dawn_inn) and formspec:find("Set home here", 1, true), "F innkeeper offers binding")
fields({bind=true})
check(not home.home_is_claim(player) and home.get(player).id == "dawnmere", "F innkeeper binding clears claim home")

-- ---------------------------------------------------------------------------
-- M: Map marker and button
-- ---------------------------------------------------------------------------
check(home.set_home_claim(player), "M set")
data["grug_home:ready_at"] = tostring(clock + 77)
rawset(_G, "grug_map", {atlas=dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
rawset(_G, "grug_parties", {view=function() return nil end})
rawset(_G, "grug_jobs", {PROFESSIONS={}})
rawset(_G, "grug_quests", {registered_npcs={}, marker_states=function() return {}, 1 end})
-- providers.lua reads its own mod's files (location_view.lua) through its
-- mod name.
core.get_current_modname = function() return "grug_map" end
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
core.get_current_modname = function() return "grug_home" end
do
 local count, homes, at_stone = 0, 0, false
 for _, marker in ipairs(grug_map.atlas.collect_markers(player)) do
  if marker.kind == "innkeeper" or marker.kind == "home" then count = count + 1 end
  if marker.kind == "home" then
   homes = homes + 1
   at_stone = marker.position.x == stone_pos.x and marker.position.z == stone_pos.z
  end
 end
 -- Round 31 (ruling 13): the six own-faction innkeepers and the stone.
 check(count == 7 and homes == 1 and at_stone, "M one home marker at the stone")
end
local page
rawset(_G, "sfinv", {register_page=function(_, p) page = p end,
 make_formspec=function(_, _, fs) return fs end, contexts={}, set_page=function() end})
rawset(_G, "grug_zones", {at=function() return nil end})
rawset(_G, "grug_inventory", {UI={width=10.4, height=11.1}})
-- Round 27 minimap switch (page.lua asks it); this server has no world map.
grug_map.minimap = {available=function() return false end, enabled=function() return false end}
-- Round 31: the settlement icons ask each race's faction.
grug_core.start_identities = function()
 local result = {}
 for _, row in ipairs(defs) do
  if not result[row.race] then result[row.race] = true; result[#result + 1] = {race_id=row.race,
   faction_id=row.faction} end
 end
 return result
end
grug_core.faction_ids = grug_core.faction_ids or {"accord", "throng"}
dofile(repo .. "/mods/PLAYER/grug_map/page.lua")
check(not page.get(page, player, {}):find("Return home", 1, true), "M no Return home on the Map tab")
-- Round 30 ruling: Return home is on the Character page (the real
-- grug_inventory/pages.lua on stubs for everything but grug_home).
do
 local pages, sets = {}, 0
 rawset(_G, "sfinv", {pages=pages, pages_unordered={}, contexts={},
  register_page=function(name, def) def.name = name; pages[name] = def end,
  make_formspec=function(_, _, fs) return fs end, set_page=function() end,
  set_player_inventory_formspec=function() sets = sets + 1 end})
 rawset(_G, "grug_inventory", {equipment_slots={}, has_quiver=function() return false end,
  selected_button_style=function() return "" end, wrap_text=function(text) return text end})
 rawset(_G, "grug_classes", {get_class_def=function() return {resource="rage"} end,
  get_pool_breakdown=function() return {final=20} end, get_crit_chance=function() return 0 end,
  get_dodge_chance=function() return 0 end, get_class=function() return "warrior" end})
 rawset(_G, "grug_money", {format=function(c) return c .. "c" end, get=function() return 0 end,
  register_on_change=function() end,
  deposit_location=function() return "detached:grug_money_deposit_x", "deposit" end})
 rawset(_G, "grug_xp", {register_on_level_change=function() end})
 grug_core.get_armor_rating = function() return 0 end
 grug_core.armor_reduction = function() return 0 end
 grug_core.get_player_level = function() return 1 end
 grug_core.register_on_equipment_change = function() end
 grug_core.register_on_status_modifiers_changed = function() end
 player.get_properties = function() return {visual="mesh", mesh="m.b3d", textures={"t.png"}} end
 core.get_current_modname = function() return "grug_inventory" end
 dofile(repo .. "/mods/PLAYER/grug_inventory/pages.lua")
 core.get_current_modname = function() return "grug_home" end
 local character = pages["grug_inventory:character"]
 local context = {page="grug_inventory:character"}
 check(character.get(character, player, context):find(
  "grug_character_home;Return home: Claim Stone (2 min)]", 1, true), "M Character page button")
 data["grug_home:ready_at"] = tostring(clock)
 check(character.get(character, player, context):find("Return home: Claim Stone (Ready)]", 1, true),
  "M Character page button ready")
 check(not home.is_pending(player), "M no return under way before the click")
 check(character.on_player_receive_fields(character, player, context, {grug_character_home="x"}) and
  sets == 1, "M the button rebuilds the page")
 check(home.is_pending(player), "M the button starts the return home")
 check(character.get(character, player, context):find("Return home: Claim Stone (Preparing arrival)]",
  1, true), "M Character page button while arriving")
 player.get_properties = nil
end

-- ---------------------------------------------------------------------------
-- D: no dependency path from grug_home back to itself (depends and
--    optional_depends of every reachable mod.conf)
-- ---------------------------------------------------------------------------
do
 local packs = {"BASE", "CORE", "PLAYER", "ENTITIES", "ITEMS", "MAPGEN"}
 local graph = {}
 local function edges_of(name)
  if graph[name] then return graph[name] end
  local edges = {}
  graph[name] = edges
  for _, pack in ipairs(packs) do
   local file = io.open(repo .. "/mods/" .. pack .. "/" .. name .. "/mod.conf")
   if file then
    local text = "\n" .. file:read("*a"); file:close()
    for _, field in ipairs({"depends", "optional_depends"}) do
     for dep in (text:match("\n" .. field .. "%s*=%s*([^\n]*)") or ""):gmatch("[%w_]+") do
      edges[#edges + 1] = dep
     end
    end
    break
   end
  end
  return edges
 end
 check(table.concat(edges_of("grug_home"), " "):find("grug_housing", 1, true),
  "D grug_home optionally depends on grug_housing")
 local housing = edges_of("grug_housing")
 -- Lane A's grug_housing depends on grug_core, grug_mapgen and grug_mobs (and
 -- optionally on base mods); what matters is that none of them is grug_home.
 local housing_ok = #housing > 0
 for _, dep in ipairs(housing) do
  if dep == "grug_home" then housing_ok = false end
 end
 check(housing_ok and housing[1] == "grug_core",
  "D grug_housing does not depend on grug_home (" .. table.concat(housing, " ") .. ")")
 local seen, back = {}, false
 local function visit(name)
  for _, dep in ipairs(edges_of(name)) do
   if dep == "grug_home" then back = true end
   if not seen[dep] then seen[dep] = true; visit(dep) end
  end
 end
 visit("grug_home")
 local count = 0
 for _ in pairs(seen) do count = count + 1 end
 check(not back and count > 10, "D no cycle back to grug_home (" .. count .. " mods reached)")
end

if #failures > 0 then
 for _, label in ipairs(failures) do print("FAIL " .. label) end
 error(("R25 HOME STONE FIXTURE FAIL %d/%d"):format(#failures, checks), 0)
end
print(("R25 HOME STONE FIXTURE PASS checks=%d"):format(checks))
