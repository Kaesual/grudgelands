-- Round 72 lane WAYTAB portable test (LuaJIT): getting into an Expedition by
-- waystone (docs/planning/round72-plan.md section 2.10).
--
--   luajit tools/r72_waytab/portable_test.lua [REPO]
--
-- The shipped grug_home (init, travel, waypoints, claim_home) and grug_expeditions
-- (init, runs, entry; the preparation and the template faked, the sister files
-- left out as tools/r71_frame does) on one fake engine:
-- A. A capital waystone's window has the tabs Waystones and Expeditions and opens
--    on Waystones; no Expedition stone is ever a destination.
-- B. A stranger without a run: nothing listed, one line pointing to the Registrar.
-- C. A player-owned run: listed for its owner and entered from the tab; the way back
--    is that waystone's.
-- D. A party's run: listed for a member, who enters; a member below the entry level
--    sees the level refusal and a forged click is refused; a run being prepared says so.
-- E. Combat and the stone's reach: refused at the click in the window, and on the
--    trip's step in the feed.
-- F. The stones inside: the ordinary waystone window without tabs; a trip out to
--    another waystone keeps the place and the run, and the tab of that waystone
--    takes the player back in.
-- G. The Claim Stone's tab: listed and entered from the owner's activated stone, the
--    way back the innkeeper home's waystone; refused away from it.
-- H. An ended run is gone from the tab.
-- Prints "R72 WAYTAB PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
 checks = checks + 1
 if not ok then error("FAIL " .. label, 2) end
end

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local clock = 10000
os.time = function() return clock end
local callbacks = {join={}, leave={}, die={}, fields={}, respawn={}, step={}, loaded={}}
local after, emerge, chat, feeds = {}, {}, {}, {}
local shown = {} -- name -> {formname, fs}
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
-- World: "floor" up to y = 100, air above; beyond x 8000 (the Expedition slots) the
-- floor ends at y -111, a box's floor under the fake template's arrival.
local cells, storage_data = {}, {}
local function key(p) return round(p.x) .. "," .. round(p.y) .. "," .. round(p.z) end
local players = {}
local modname = "grug_home"
rawset(_G, "core", {
 get_modpath=function(name) return repo .. "/mods/PLAYER/" .. name end,
 get_current_modname=function() return modname end,
 dir_to_yaw=function() return 0 end, load_area=function() end,
 register_on_joinplayer=register("join"), register_on_leaveplayer=register("leave"),
 register_on_dieplayer=register("die"), register_on_player_receive_fields=register("fields"),
 register_on_respawnplayer=register("respawn"), register_globalstep=register("step"),
 register_on_mods_loaded=register("loaded"),
 register_node=function(name, def) core.registered_nodes[name] = def end,
 get_player_by_name=function(name) return players[name] end,
 get_connected_players=function()
  local list = {}
  for _, p in pairs(players) do list[#list + 1] = p end
  return list
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
 log=function() end,
 formspec_escape=function(s) return s end,
 colorize=function(_, s) return s end,
 chat_send_player=function(name, message) chat[#chat + 1] = {name, message} end,
 show_formspec=function(name, formname, fs) shown[name] = {formname=formname, fs=fs} end,
 close_formspec=function(name) shown[name] = nil end,
 after=function(delay, fn) after[#after + 1] = {delay=delay, fn=fn} end,
 emerge_area=function(minp, maxp, fn) emerge[#emerge + 1] = {fn=fn} end,
 EMERGE_CANCELLED=1, EMERGE_ERRORED=2,
 get_node_or_nil=function(pos)
  local name = cells[key(pos)]
  if name then return {name=name} end
  local top = pos.x >= 8000 and -111 or 100
  return {name=round(pos.y) <= top and "floor" or "air"}
 end,
 registered_nodes={floor={walkable=true}, air={walkable=false},
  ["grug_mapgen:waystone"]={walkable=true, drawtype="nodebox"},
  ["grug_housing:claim_stone"]={walkable=true}},
})
local in_combat = {}
rawset(_G, "grug_core", {
 FLASH_COLOR={notice=1, error=2}, flash=function() end,
 hold_movement=function() end, release_movement=function() end,
 get_player_race=function(name) return players[name].race end,
 in_combat=function(p) return in_combat[p:get_player_name()] == true end,
 invalidate_combat_identity=function() end,
 start_position=function() return vnew(0, 101, 0) end,
 feed=function(p, kind, text, k)
  feeds[#feeds + 1] = {name=p:get_player_name(), kind=kind, text=text, key=k}
  return true
 end,
 zone_authority_installed=function() return true end,
 map_reset={clear=function() end, register_on_relocate=function() end}})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
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
rawset(_G, "grug_mounts", {dismount=function() end})
rawset(_G, "grug_factions", {get_faction=function(p) return p:get_meta():get_string("faction") end,
 display_name=function(id) return "The " .. id:sub(1, 1):upper() .. id:sub(2) end})
core.get_us_time = function() return 0 end
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")

-- The real grug_housing interface file (is_draft, arrival_pos), the claim faked on it.
rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
local claims = {}
grug_housing.player_claim = function(name)
 local entry = claims[name]
 if not entry then return nil, "never" end
 return entry.claim, entry.state
end
grug_housing.is_active = function() return true end

local function new_player(name, level, race)
 local data = {faction="accord"}
 local meta = {get_string=function(_, k) return data[k] or "" end,
  set_string=function(_, k, v) data[k] = v end}
 local p = {race=race or "human", hp=20, level=level, pos=vnew(0, 101, 0), data=data,
  get_player_name=function() return name end, is_player=function() return true end,
  get_meta=function() return meta end, get_hp=function(self) return self.hp end,
  get_pos=function(self) return vnew(self.pos) end, get_look_horizontal=function() return 0 end,
  set_pos=function(self, pos) self.pos = vnew(pos) end}
 players[name] = p
 return p
end
do
 local join = core.register_on_joinplayer
 core.register_on_joinplayer = function() end
 dofile(repo .. "/mods/CORE/grug_core/ui.lua")
 core.register_on_joinplayer = join
end
dofile(repo .. "/mods/PLAYER/grug_home/init.lua")
local home = grug_home

-- grug_expeditions' environment: levels, parties, a template of three places and a
-- preparation that is done at once unless held.
default = {node_sound_stone_defaults=function() return {} end}
grug_xp = {get_level=function(p) return p.level end}
local parties, party_of = {}, {}
grug_parties = {
 view=function(p)
  local name = type(p) == "string" and p or p:get_player_name()
  local group = parties[party_of[name]]
  if not group then return nil end
  local rows = {}
  for i, member in ipairs(group.members) do
   rows[i] = {name=member, level=players[member].level, online=true}
  end
  return {id=party_of[name], leader=group.leader, members=rows}
 end,
 register_on_member_left=function() end, register_on_change=function() end,
}
local hold_preparation = false
local held = {}
local FAKE_PREPARATION = {
 init=function() end, cancel=function() end, status=function() return nil end,
 enqueue=function(run, _, finish)
  if hold_preparation then held[#held + 1] = finish else finish(true) end
 end,
}
local FAKE_TEMPLATE = {EXTENSION=".exp", resolve=function() end,
 load=function()
  return {places={arrival={x=8, y=2, z=8}, start_waystone={x=9, y=2, z=8},
   end_waystone={x=40, y=2, z=8}}, encounters={}}
 end}
local SISTERS = {["encounters.lua"]=true, ["guard.lua"]=true, ["registrar.lua"]=true,
 ["chest.lua"]=true, ["loot.lua"]=true}
local load_file = dofile
_G.dofile = function(file)
 local base = file:match("[^/]+$")
 if base == "preparation.lua" then return FAKE_PREPARATION end
 if base == "template.lua" then return FAKE_TEMPLATE end
 if SISTERS[base] then return end
 return load_file(file)
end
modname = "grug_expeditions"
load_file(repo .. "/mods/PLAYER/grug_expeditions/init.lua")
_G.dofile = load_file
modname = "grug_home"
local E = grug_expeditions
local left = {}
E.register_on_leave(function(_, name, why) left[#left + 1] = name .. " " .. why end)

local function deferred()
 local tasks = after; after = {}
 for _, task in ipairs(tasks) do
  if task.delay == 0 then task.fn() else after[#after + 1] = task end
 end
end
-- Every pending emerge done, then the server step after it.
local function finish()
 local jobs = emerge; emerge = {}
 for _, job in ipairs(jobs) do job.fn(nil, 0, 0) end
 deferred()
end
local function fs_of(p) return shown[p:get_player_name()] and shown[p:get_player_name()].fs or "" end
local function fields(p, values)
 local form = shown[p:get_player_name()]
 for _, fn in ipairs(callbacks.fields) do
  if fn(p, form and form.formname or "", values) then return end
 end
end
local function has(text, needle) return text:find(needle, 1, true) ~= nil end
local function at_stone(p, id)
 p.pos = vnew(STONE[id].x + 1, 101, 0)
 shown[p:get_player_name()] = nil
 home.use_waystone(p, STONE[id])
 return fs_of(p)
end
local function expeditions_tab(p, id)
 at_stone(p, id)
 fields(p, {waystone_tab_2="Expeditions"})
 return fs_of(p)
end
local function last_feed(name)
 for i = #feeds, 1, -1 do
  if feeds[i].name == name then return feeds[i].text end
 end
end
local NOTHING = "You have no Expedition to enter. The Expedition Registrar in a capital's " ..
 "guild house opens one."

local eve = new_player("Eve", 25)
local cid = new_player("Cid", 25)
local ann = new_player("Ann", 26)
local bob = new_player("Bob", 22)
local dee = new_player("Dee", 21)
parties.p1 = {leader="Ann", members={"Ann", "Bob", "Dee"}}
party_of.Ann, party_of.Bob, party_of.Dee = "p1", "p1", "p1"

-- A. The tabs.
local fs = at_stone(eve, "highcourt")
check(has(fs, "waystone_tab_1;Waystones]") and has(fs, "waystone_tab_2;Expeditions]"),
 "A a capital waystone has both tabs")
check(has(fs, grug_core.ui.button_style("waystone_tab_1", "selected")) and has(fs, "go_dawnmere"),
 "A it opens on the waystones")
check(not has(fs, "enter_") and not has(fs, "expedition:"), "A no Expedition stone is a destination")

-- B. A stranger without a run.
fs = expeditions_tab(cid, "highcourt")
check(has(fs, grug_core.ui.button_style("waystone_tab_2", "selected")), "B the tab selected")
check(has(fs, NOTHING) and not has(fs, "enter_"), "B nothing listed, one line to the Registrar")
check(not has(fs, "go_"), "B no waystone on the Expeditions tab")
fields(cid, {waystone_tab_1="Waystones"})
check(has(fs_of(cid), "go_dawnmere"), "B back to the waystones")

-- C. A player-owned run.
local solo = assert(E.create(eve, "test_vault", 4))
check(solo.state == "ready" and solo.level == 24, "C a ready run at level 24")
fs = expeditions_tab(eve, "highcourt")
check(has(fs, "Test Vault, level 24") and has(fs, "enter_" .. solo.id .. ";Enter]"), "C the owner's run listed")
fs = expeditions_tab(cid, "highcourt")
check(has(fs, NOTHING) and not has(fs, "enter_"), "C not for a stranger")
fields(cid, {["enter_" .. solo.id]="Enter"})
check(#emerge == 0 and has(fs_of(cid), "This Expedition has ended."), "C a stranger's forged click refused")
expeditions_tab(eve, "highcourt")
fields(eve, {["enter_" .. solo.id]="Enter"})
check(shown.Eve == nil and #emerge == 1, "C Enter starts the trip and closes the window")
finish()
check(E.run_inside(eve) == solo and solo.entered.Eve and solo.state == "running", "C the owner inside")
check(solo.origins.Eve == "highcourt" and E.saved_origin(eve) == "highcourt", "C the way back is that waystone")
check(math.abs(eve.pos.x - solo.places.arrival.x) < 0.01 and
 math.abs(eve.pos.y - (solo.places.arrival.y - 0.49)) < 0.01, "C at the run's arrival")

-- D. A party's run: a member, a level refusal, being prepared.
hold_preparation = true
local party = assert(E.create(ann, "test_vault", 4))
fs = expeditions_tab(bob, "dawnmere")
check(has(fs, "Your Expedition is still being prepared.") and not has(fs, "enter_"),
 "D being prepared: said, not listed")
hold_preparation = false
table.remove(held, 1)(true)
check(party.state == "ready", "D ready")
fs = expeditions_tab(bob, "dawnmere")
check(has(fs, "Test Vault, level 24") and has(fs, "enter_" .. party.id), "D a member sees the party's run")
fs = expeditions_tab(dee, "dawnmere")
check(has(fs, "This Expedition needs level 22.") and not has(fs, "enter_"), "D the level refusal, not listed")
fields(dee, {["enter_" .. party.id]="Enter"})
check(#emerge == 0 and has(fs_of(dee), "This Expedition needs level 22."), "D a forged click refused")
expeditions_tab(bob, "dawnmere")
fields(bob, {["enter_" .. party.id]="Enter"})
finish()
check(E.run_inside(bob) == party and party.origins.Bob == "dawnmere", "D the member inside, back to Dawnmere")

-- E. Combat and the stone's reach.
expeditions_tab(ann, "highcourt")
in_combat.Ann = true
fields(ann, {["enter_" .. party.id]="Enter"})
check(#emerge == 0 and has(fs_of(ann), "Cannot travel in combat."), "E combat refused in the window")
in_combat.Ann = nil
ann.pos = vnew(STONE.highcourt.x + 20, 101, 0)
fields(ann, {["enter_" .. party.id]="Enter"})
check(#emerge == 0 and has(fs_of(ann), "Stand at the waystone to travel."), "E away from the stone")
ann.pos = vnew(STONE.highcourt.x + 1, 101, 0)
fields(ann, {["enter_" .. party.id]="Enter"})
check(#emerge == 1, "E at the stone the trip starts")
in_combat.Ann = true
finish()
check(E.run_inside(ann) == nil and last_feed("Ann") == "Cannot travel in combat.",
 "E combat on the trip's step: refused in the feed")
in_combat.Ann = nil
expeditions_tab(ann, "highcourt")
fields(ann, {["enter_" .. party.id]="Enter"})
ann.pos = vnew(STONE.highcourt.x + 30, 101, 0)
finish()
check(E.run_inside(ann) == nil and last_feed("Ann") == "Travel canceled.", "E walked away: canceled")

-- F. The stones inside.
local inner = solo.places.start_waystone
eve.pos = vnew(solo.places.arrival.x, solo.places.arrival.y - 0.49, solo.places.arrival.z)
shown.Eve = nil
core.registered_nodes["grug_expeditions:waystone"].on_rightclick(inner, nil, eve)
fs = fs_of(eve)
check(has(fs, "Test Vault Waystone") and has(fs, "go_highcourt") and has(fs, "go_dawnmere"),
 "F an inner stone lists the player's waystones")
check(not has(fs, "waystone_tab_") and not has(fs, "enter_") and not has(fs, "You are here"),
 "F no Expeditions tab inside")
in_combat.Eve = true
fields(eve, {go_dawnmere="Travel"})
check(#emerge == 0 and E.run_inside(eve) == solo, "F the normal rules refuse combat")
in_combat.Eve = nil
fields(eve, {go_dawnmere="Travel"})
finish()
check(E.run_inside(eve) == nil and math.abs(eve.pos.x - STONE.dawnmere.x) < 2,
 "F a trip out to another waystone")
check(solo.entered.Eve and solo.state == "running" and left[#left] == "Eve travel",
 "F the place kept, the run on, the leave hook first")
fs = expeditions_tab(eve, "dawnmere")
check(has(fs, "enter_" .. solo.id), "F the run listed at the other waystone")
fields(eve, {["enter_" .. solo.id]="Enter"})
finish()
check(E.run_inside(eve) == solo and E.saved_origin(eve) == "dawnmere", "F back in by the tab")
shown.Cid = nil
E.use_waystone(cid, inner)
check(shown.Cid == nil and last_feed("Cid") == "You are not in an Expedition.", "F not inside: a notice")

-- G. The Claim Stone's tab.
local center = vnew(500, 101, 500)
claims.Ann = {state="placed", claim={id=7, owner="Ann", center=center, placed_at=clock,
 activated_at=clock, paid_until=clock + 3600}}
local rows, line = home.expedition_rows(ann)
check(#rows == 1 and rows[1].id == tostring(party.id) and line == nil, "G the run on the stone's tab")
local list
list, line = home.expedition_rows(cid)
check(#list == 0 and line == NOTHING, "G nothing for a stranger, the one line")
ann.pos = vnew(center.x + 20, 101, center.z)
local ok, why = home.expedition_from_claim(ann, tostring(party.id))
check(not ok and why == "Stand at your Claim Stone to travel.", "G away from the stone")
ok, why = home.expedition_from_claim(cid, tostring(party.id))
check(not ok and why == "You have no activated Claim Stone.", "G no stone, no way")
ann.pos = vnew(center.x + 2, 101, center.z)
check(home.expedition_from_claim(ann, tostring(party.id)), "G entered from the stone")
finish()
check(E.run_inside(ann) == party and party.origins.Ann == "dawnmere",
 "G the way back leads to the innkeeper home's waystone")

-- H. An ended run is gone from the tab.
E.end_run(party, "test")
fs = expeditions_tab(dee, "dawnmere")
check(has(fs, NOTHING) and not has(fs, "enter_"), "H an ended run is not listed")
for _, row in ipairs(chat) do
 check(not has(row[2], "Expedition"), "H no Expedition notice in chat: " .. row[2])
end

print("R72 WAYTAB PORTABLE PASS checks=" .. checks)
