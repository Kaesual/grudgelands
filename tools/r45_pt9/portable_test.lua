-- Round 45 PT9 portable test (LuaJIT): the owner's Claim Stone as a waypoint.
--
--   luajit tools/r45_pt9/portable_test.lua [REPO]
--
-- A. The pure rules (grug_home/waypoints_core.lua): the Claim Stone entry,
--    "travel" with a claim row, else "no_claim"; a claim target needs no
--    visit.
-- B. The shipped grug_home (init, claim_home, travel, waypoints) with the real
--    grug_housing api.lua (claims faked on top) on a fake engine: no stone,
--    a carried stone and a draft read "No claim stone" (never "Not yet
--    visited"); an activated stone, also unfuelled, offers Travel; the trip
--    emerges the stone, lands in its arrival cube, charges no cooldown and
--    leaves the travel home alone; a blocked cube leaves the player in place
--    with a message; a stone picked up during the emerge or a stale button
--    goes nowhere; a moved stone is reached at its new place; a destroyed
--    one reads "No claim stone" again; only the owner sees it.
-- C. The Map: the stone is a "Your Claim Stone" waypoint marker with the
--    stone's own texture unless it is the travel home (then the home marker
--    alone marks it).
-- D. From the stone (the follow-up: the stone form's Waypoints tab calls
--    grug_home.travel_from_claim): to a discovered own waystone, beside it,
--    no cooldown; refused without an activated stone, away from the stone,
--    in combat, to an unvisited or enemy stone; canceled when the stone goes
--    during the emerge.
-- Prints "R45 PT9 PORTABLE PASS checks=<n>" or raises on the first failure.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
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
local ROWS = {
 {id="hearth", label="hearth", faction="accord", race="dwarf", start=true, pos={x=0, y=10, z=0}},
 {id="dawn", label="dawn", faction="accord", race="human", start=true, pos={x=100, y=10, z=0}},
}
local entry = R.claim_entry(nil)
check(entry.state == "no_claim" and entry.row.id == R.CLAIM_ID and
 entry.row.label == "Your Claim Stone", "A no claim: no_claim")
local claim_row = {id="claim:7", claim="7", faction="accord", label="Your Claim Stone",
 pos={x=500, y=20, z=500}}
entry = R.claim_entry(claim_row)
check(entry.state == "travel" and entry.row == claim_row, "A claim: travel")
check(#R.entries(ROWS, "accord", {}, "human", "dawn") == 2, "A the waystone list itself unchanged")
check(R.refusal({alive=true, faction="accord", race="human", set={}, origin=ROWS[2],
 target=claim_row, at_origin=true}) == nil, "A claim target needs no visit")
check(R.refusal({alive=true, faction="accord", race="human", set={}, origin=ROWS[2],
 target=claim_row, at_origin=true, in_combat=true}) == "Cannot travel in combat.", "A claim in combat")

-- ---------------------------------------------------------------------------
-- B: the shipped modules on a fake engine
-- ---------------------------------------------------------------------------
local clock = 10000
os.time = function() return clock end
local callbacks = {join={}, leave={}, die={}, fields={}, respawn={}, step={}, loaded={}}
local after, emerge, chat = {}, {}, {}
local formname, formspec
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
local cells, storage_data = {}, {}
local function key(p) return round(p.x) .. "," .. round(p.y) .. "," .. round(p.z) end
local player, other
rawset(_G, "core", {
 get_modpath=function(name) return repo .. "/mods/PLAYER/" .. name end,
 get_current_modname=function() return "grug_home" end,
 dir_to_yaw=function() return 0 end, load_area=function() end,
 register_on_joinplayer=register("join"), register_on_leaveplayer=register("leave"),
 register_on_dieplayer=register("die"), register_on_player_receive_fields=register("fields"),
 register_on_respawnplayer=register("respawn"), register_globalstep=register("step"),
 register_on_mods_loaded=register("loaded"),
 get_player_by_name=function(name)
  if player and name == player:get_player_name() then return player end
  if other and name == other:get_player_name() then return other end
 end,
 get_connected_players=function() return {player} end,
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
 colorize=function(_, s) return s end,
 chat_send_player=function(_, message) chat[#chat + 1] = message end,
 show_formspec=function(_, name, fs) formname, formspec = name, fs end,
 close_formspec=function() end,
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
  ["grug_mapgen:waystone"]={walkable=true, drawtype="nodebox"},
  ["grug_housing:claim_stone"]={walkable=true}},
})
local dismounts = 0
rawset(_G, "grug_core", {
 FLASH_COLOR={notice=1, error=2}, flash=function() end,
 faction_ids={"accord", "throng"},
 hold_movement=function() end, release_movement=function() end,
 get_player_race=function(name) return core.get_player_by_name(name).race end,
 in_combat=function(p) return p.combat end,
 invalidate_combat_identity=function() end,
 start_position=function() return vnew(0, 101, 0) end,
 zone_authority_installed=function() return true end,
 map_reset={clear=function() end, register_on_relocate=function() end}})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
-- Every home location at x = 1000 * index, its waystone 40 east of it.
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
for i, fortress in ipairs({{"pvp_fortress_accord", "human"}, {"pvp_fortress_throng", "orc"}}) do
 grug_core.register_settlement_sockets(fortress[1], fortress[2], {x=(#LOCATIONS + i) * 1000, y=100, z=0},
  {{id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}}, fortress[1])
end
rawset(_G, "grug_mobs", {register_start_socket_role=function() end})
rawset(_G, "grug_mounts", {dismount=function() dismounts = dismounts + 1 end})
rawset(_G, "grug_factions", {get_faction=function(p) return p:get_meta():get_string("faction") end,
 display_name=function(id) return "The " .. id:sub(1, 1):upper() .. id:sub(2) end})
core.get_us_time = function() return 0 end
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")

-- The real grug_housing interface file (is_draft, arrival_pos); the
-- player's claim state is faked on top of it.
rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
local claims = {} -- owner -> {claim, state}
grug_housing.player_claim = function(name)
 local entry = claims[name]
 if not entry then return nil, "never" end
 return entry.claim, entry.state
end
grug_housing.is_active = function(claim)
 return claim.activated_at ~= 0 and claim.paid_until > os.time()
end
local next_id = 0
local function place(owner, center, activated, fuel)
 next_id = next_id + 1
 local claim = {id=next_id, owner=owner, center=vnew(center), placed_at=clock,
  activated_at=activated and clock or 0, paid_until=clock + (fuel or 3600)}
 claims[owner] = {claim=claim, state="placed"}
 cells[key(center)] = "grug_housing:claim_stone"
 return claim
end
local function lose(owner, state)
 cells[key(claims[owner].claim.center)] = nil
 claims[owner] = {claim=nil, state=state}
end

local function new_player(name, faction, race)
 local data = {faction=faction}
 local meta = {get_string=function(_, k) return data[k] or "" end,
  set_string=function(_, k, v) data[k] = v end}
 return {race=race, hp=20, pos=vnew(0, 101, 0), data=data,
  get_player_name=function() return name end, is_player=function() return true end,
  get_meta=function() return meta end, get_hp=function(self) return self.hp end,
  get_pos=function(self) return self.pos end, get_look_horizontal=function() return 0 end,
  set_pos=function(self, p) self.pos = vnew(p) end}
end
player = new_player("tester", "accord", "human")
other = new_player("neighbour", "accord", "human")
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
local function drop_timeouts() local kept = {}
 for _, t in ipairs(after) do if t.delay ~= 30 then kept[#kept + 1] = t end end
 after = kept
end
local function fields(who, values)
 for _, fn in ipairs(callbacks.fields) do fn(who, formname, values) end
end
local function last_chat() return chat[#chat] or "" end
local function count(text, pattern) local _, n = text:gsub(pattern, ""); return n end
local function open(who, at)
 who.pos = vnew(STONE[at].x + 1, 101, 0)
 formspec = nil
 home.use_waystone(who, STONE[at])
 return formspec or ""
end

-- No stone, a carried stone, a draft: "No claim stone", no button.
local fs = open(player, "dawnmere")
check(fs:find("Your Claim Stone", 1, true) and count(fs, "No claim stone") == 1 and
 not fs:find("go_claim", 1, true), "B never had a stone: No claim stone")
check(count(fs, "Not yet visited") == 6, "B the waystones keep Not yet visited (six unvisited)")
check(home.claim_waypoint(player) == nil, "B no waypoint without a stone")
claims.tester = {claim=nil, state="carried"}
fs = open(player, "dawnmere")
check(count(fs, "No claim stone") == 1 and not fs:find("go_claim", 1, true), "B carried: No claim stone")
local stone_pos = vnew(700, 101, 700)
place("tester", stone_pos, false)
fs = open(player, "dawnmere")
check(count(fs, "No claim stone") == 1 and not fs:find("go_claim", 1, true) and
 home.claim_waypoint(player) == nil, "B draft: no waypoint")
-- A stale or forged button without a stone goes nowhere.
fields(player, {go_claim="Travel"})
check(#emerge == 0 and last_chat() == "You have no activated Claim Stone.", "B stale button refused")

-- Activated: Travel, also when unfuelled.
claims.tester.claim.activated_at = clock
fs = open(player, "dawnmere")
check(fs:find("go_claim", 1, true) and not fs:find("No claim stone", 1, true), "B activated: Travel")
local row = home.claim_waypoint(player)
check(row and row.label == "Your Claim Stone" and row.pos.x == 700, "B the waypoint row")
check(fs:find("Your Claim Stone", 1, true) > fs:find("pvp_fortress_accord", 1, true),
 "B the stone closes the list, after the fortress")
claims.tester.claim.paid_until = clock - 60
fs = open(player, "dawnmere")
check(fs:find("go_claim", 1, true), "B unfuelled stone stays a waypoint")
-- Only the owner sees it.
fs = open(other, "dawnmere")
check(count(fs, "No claim stone") == 1 and not fs:find("go_claim", 1, true), "B another player: own entry only")
open(player, "dawnmere")

-- A trip: no cooldown, travel home untouched, lands in the arrival cube.
player.data["grug_home:ready_at"] = "12345"
player.combat = true; fields(player, {go_claim="Travel"}); player.combat = false
check(last_chat() == "Cannot travel in combat." and #emerge == 0, "B combat refused")
fields(player, {go_claim="Travel"})
check(#emerge == 1 and home.is_pending(player), "B trip starts")
local job = finish()
check(job.center.x == 700 and job.center.z == 700, "B emerges around the stone")
check(player.pos.x == 700 and player.pos.z == 700 and math.abs(player.pos.y - 101.51) < 1e-9,
 "B lands in the arrival cube above the stone")
check(player.data["grug_home:ready_at"] == "12345" and not home.home_is_claim(player) and
 dismounts == 1, "B no cooldown, the travel home unchanged")
drop_timeouts()

-- Blocked cube: stays at the origin, with a message.
cells[key(vnew(700, 102, 700))] = "stone"
open(player, "highcourt"); fields(player, {go_claim="Travel"}); finish()
check(player.pos.x == STONE.highcourt.x + 1 and
 last_chat() == "Your Claim Stone's arrival is blocked.", "B blocked cube stays, with the blocked message")
cells[key(vnew(700, 102, 700))] = nil
drop_timeouts()
-- A failed emerge keeps the unavailable message.
open(player, "highcourt"); fields(player, {go_claim="Travel"}); finish(core.EMERGE_ERRORED)
check(player.pos.x == STONE.highcourt.x + 1 and
 last_chat() == "Your Claim Stone cannot be reached right now. Please try again.", "B failed emerge stays")
drop_timeouts()

-- Picked up during the emerge: the trip is canceled.
open(player, "highcourt"); fields(player, {go_claim="Travel"})
lose("tester", "carried"); finish()
check(player.pos.x == STONE.highcourt.x + 1 and
 last_chat() == "Your Claim Stone is gone. Travel canceled.", "B stone gone during the emerge")
drop_timeouts()

-- Moved: placed and activated elsewhere, reached at its new place; replaced
-- under the same button while a list was open (a new claim id) the trip
-- goes to the stone the player has at the click.
local moved = vnew(-300, 101, 40)
place("tester", moved, true)
fs = open(player, "highcourt")
check(fs:find("go_claim", 1, true), "B moved stone: Travel again")
fields(player, {go_claim="Travel"}); finish()
check(player.pos.x == -300 and player.pos.z == 40, "B moved stone reached at its new place")
drop_timeouts()
claims.tester.claim.id = 99 -- the claim changes between click and arrival
open(player, "highcourt"); fields(player, {go_claim="Travel"})
claims.tester.claim = {id=100, owner="tester", center=vnew(moved), placed_at=clock,
 activated_at=clock, paid_until=clock + 60}
finish()
check(player.pos.x == STONE.highcourt.x + 1 and last_chat():find("gone", 1, true),
 "B a replaced claim during the emerge cancels")
drop_timeouts()

-- Destroyed (by another player's pick or a vanished node): No claim stone.
lose("tester", "destroyed")
fs = open(player, "highcourt")
check(count(fs, "No claim stone") == 1 and not fs:find("go_claim", 1, true), "B destroyed: No claim stone")

-- ---------------------------------------------------------------------------
-- C: the Map
-- ---------------------------------------------------------------------------
grug_housing.STONE_TEXTURE = "claim_stone_look.png" -- stone.lua's TEXTURE
rawset(_G, "grug_map", {atlas=dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
rawset(_G, "grug_parties", {view=function() return nil end})
rawset(_G, "grug_quests", {registered_npcs={}, marker_states=function() return {}, 1 end})
core.get_current_modname = function() return "grug_map" end
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
core.get_current_modname = function() return "grug_home" end
local function markers(kind)
 local result = {}
 for _, marker in ipairs(grug_map.atlas.collect_markers(player, {[kind]=true})) do
  result[#result + 1] = marker
 end
 return result
end
local function claim_marks(kind)
 local result = {}
 for _, marker in ipairs(markers(kind)) do
  if marker.position.x == moved.x and marker.position.z == moved.z then result[#result + 1] = marker end
 end
 return result
end
check(#claim_marks("waypoint") == 0, "C no stone, no marker")
place("tester", moved, false)
check(#claim_marks("waypoint") == 0, "C draft, no marker")
claims.tester.claim.activated_at = clock
local marks = claim_marks("waypoint")
check(#marks == 1 and marks[1].label == "Your Claim Stone" and marks[1].kind == "waypoint" and
 marks[1].texture == "claim_stone_look.png", "C activated stone: one waypoint marker in the stone's look")
check(home.set_home_claim(player), "C set the stone as the travel home")
check(#claim_marks("waypoint") == 0 and #claim_marks("home") == 1, "C the home marker alone marks the home stone")

-- ---------------------------------------------------------------------------
-- D: from the stone to the waystones
-- ---------------------------------------------------------------------------
local function from_stone(id) chat = {}; return home.travel_from_claim(player, id) end
player.pos = vnew(moved.x + 2, 101, moved.z)
player.data["grug_home:ready_at"] = "777"
local ok, why = from_stone("highcourt")
check(ok and #emerge == 1 and home.is_pending(player), "D trip from the stone starts")
job = finish()
check(job.center.x == STONE.highcourt.x and player.pos.x == STONE.highcourt.x + 1 and
 player.pos.z == 0, "D arrives beside the waystone")
check(player.data["grug_home:ready_at"] == "777", "D no cooldown")
drop_timeouts()
player.pos = vnew(moved.x + 2, 101, moved.z)
ok, why = from_stone("hearthpine")
check(not ok and why == "You have not visited that waystone yet.", "D unvisited refused")
ok, why = from_stone("sunscar")
check(not ok and why == "That waystone is not on your path.", "D enemy refused")
ok, why = from_stone("nowhere")
check(not ok and why == "That waystone is not on your path.", "D unknown id refused")
player.combat = true; ok, why = from_stone("highcourt"); player.combat = false
check(not ok and why == "Cannot travel in combat.", "D combat refused")
player.pos = vnew(moved.x + 9, 101, moved.z)
ok, why = from_stone("highcourt")
check(not ok and why == "Stand at your Claim Stone to travel.", "D away from the stone refused")
player.pos = vnew(moved.x + 2, 101, moved.z)
ok = from_stone("highcourt"); lose("tester", "destroyed"); finish()
check(ok and player.pos.x == moved.x + 2 and last_chat() == "Travel canceled.",
 "D stone gone during the emerge cancels")
drop_timeouts()
ok, why = from_stone("highcourt")
check(not ok and why == "You have no activated Claim Stone." and #emerge == 0, "D no stone refused")
place("tester", moved, false)
ok, why = from_stone("highcourt")
check(not ok and why == "You have no activated Claim Stone.", "D draft refused")

print("R45 PT9 PORTABLE PASS checks=" .. checks)
