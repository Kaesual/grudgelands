-- Round 72.1 lane FINISH portable test (LuaJIT): finishing and cancelling an
-- Expedition, and the Deserter's Mark (docs/design/expeditions.md sections 3 to 5).
--
--   luajit tools/r721_finish/portable_test.lua [REPO]
--
-- The shipped grug_home (init, travel, waypoints, claim_home) and grug_expeditions
-- (init, runs, entry, registrar; the preparation and the template faked, the boss's
-- rewards_open a switch per run, the other sister files left out as tools/r72_waytab
-- does) on one fake engine with a clock:
-- A. Finish and Cancel: refused while preparing and for a member who does not lead;
--    Finish only once rewards_open, then Cancel no more; the solo owner may.
-- B. Finish at the registrar: the countdown banner inside, once a second, the notice
--    outside; a member sees the state without buttons; entry at T-11, refused at T-10,
--    on the click and on a trip's arrival; the end at 60 sends everyone out, a dead
--    player stays.
-- C. Cancel: a ready run never entered, at the registrar, with its confirmation, ends
--    at once; a running one from a waystone's tab, with its confirmation, counts down
--    and takes nobody in; refused while closing; the stone inside shows the state
--    alone to a member, and Finish to a solo owner, without confirmation.
-- D. The Deserter's Mark: only the canceller; it blocks opening and entering; its
--    status; a logout and a login 48 s later with the right time left; gone after
--    5 minutes, its saved end cleared at the next login.
-- E. A solo owner joins a foreign party: ended at once, marked unless rewards_open or
--    already finished.
-- F. A run left empty for 10 minutes ends without a mark.
-- G. The leader hands on: the new leader opens a run at once, the bearer cannot
--    enter it; as leader again the bearer still sees Cancel.
-- Prints "R721 FINISH PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
 checks = checks + 1
 if not ok then error("FAIL " .. label, 2) end
end

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
-- One clock for both: os.time() for the mark, core.get_us_time() for the countdown.
local now = 100000
os.time = function() return now end
local callbacks = {join={}, leave={}, die={}, fields={}, respawn={}, step={}, loaded={}}
local after, emerge, chat, feeds, banners = {}, {}, {}, {}, {}
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
 get_modpath=function(name)
  if name == "grug_mapgen" then return repo .. "/mods/MAPGEN/grug_mapgen" end
  return repo .. "/mods/PLAYER/" .. name
 end,
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
  table.sort(list, function(a, b) return a:get_player_name() < b:get_player_name() end)
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
 after=function(delay, fn) after[#after + 1] = {at=now + delay, fn=fn} end,
 get_us_time=function() return now * 1e6 end,
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
local in_combat, sources = {}, {}
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
 banner=function(p, text) banners[p:get_player_name()] = text; return true end,
 register_status_source=function(fn) sources[#sources + 1] = fn end,
 zone_authority_installed=function() return true end,
 map_reset={clear=function() end, register_on_relocate=function() end}})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local LOCATIONS = dofile(repo .. "/mods/PLAYER/grug_home/locations.lua")
local STONE = {}
for i, location in ipairs(LOCATIONS) do
 local anchor = {x=i * 1000, y=100, z=0}
 grug_core.register_settlement_sockets(location.id, location.race, anchor,
  {{id=location.socket, role="idle", x=0, y=1, z=0, dir={x=0, z=1}},
   {id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}},
   -- The guild house's clerk, whose socket the registrar takes over.
   {id="miners_guild/miners_guild_clerk", role="idle", x=2, y=1, z=2, dir={x=1, z=0}, tags={"work"}}})
 STONE[location.id] = vnew(anchor.x + 40, 101, 0)
 cells[key(STONE[location.id])] = "grug_mapgen:waystone"
end
for i, fortress in ipairs({{"pvp_fortress_accord", "human"}, {"pvp_fortress_throng", "orc"}}) do
 grug_core.register_settlement_sockets(fortress[1], fortress[2], {x=(#LOCATIONS + i) * 1000, y=100, z=0},
  {{id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}}, fortress[1])
end
rawset(_G, "grug_mobs", {register_start_socket_role=function() end})
rawset(_G, "grug_mounts", {dismount=function() end})
rawset(_G, "grug_materials", {resource_for_node=function() return nil end})
rawset(_G, "grug_factions", {get_faction=function(p) return p:get_meta():get_string("faction") end,
 display_name=function(id) return "The " .. id:sub(1, 1):upper() .. id:sub(2) end})
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")

rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
grug_housing.player_claim = function() return nil, "never" end
grug_housing.is_active = function() return true end

local function new_player(name, level)
 local data = {faction="accord"}
 local meta = {get_string=function(_, k) return data[k] or "" end,
  set_string=function(_, k, v) data[k] = v end}
 local p = {race="human", hp=20, level=level, pos=vnew(0, 101, 0), data=data,
  get_player_name=function() return name end, is_player=function() return true end,
  is_valid=function() return true end,
  hud_add=function() return 1 end, hud_remove=function() end,
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
 dofile(repo .. "/mods/CORE/grug_core/ui_rows.lua")
 core.register_on_joinplayer = join
end
dofile(repo .. "/mods/PLAYER/grug_home/init.lua")
local home = grug_home

-- grug_expeditions' environment: levels, parties with their change events, a
-- template of three places and a preparation that is done at once unless held.
default = {node_sound_stone_defaults=function() return {} end}
grug_xp = {get_level=function(p) return p.level end}
local parties, party_of, change_hooks = {}, {}, {}
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
 register_on_member_left=function() end,
 register_on_change=function(fn) change_hooks[#change_hooks + 1] = fn end,
}
local function party(id, leader, ...)
 parties[id] = {leader=leader, members={leader, ...}}
 for _, name in ipairs(parties[id].members) do party_of[name] = id end
end
local function emit(reason, ...)
 for _, name in ipairs({...}) do
  for _, fn in ipairs(change_hooks) do fn(name, reason) end
 end
end
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
local SISTERS = {["encounters.lua"]=true, ["guard.lua"]=true,
 ["chest.lua"]=true, ["loot.lua"]=true, ["traps.lua"]=true}
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
-- encounters.lua's gate, a switch per run here (its own rule: tools/r71_mobs).
local rewards = {}
E.rewards_open = function(run) return rewards[run] == true end
local ended = {}
E.register_on_end(function(run, why) ended[run] = why end)

-- Every task due by now, those they schedule for now included.
local function run_due()
 local ran = true
 while ran do
  ran = false
  local tasks = after; after = {}
  for _, task in ipairs(tasks) do
   if task.at <= now then
    task.fn()
    ran = true
   else
    after[#after + 1] = task
   end
  end
 end
end
local function advance(seconds)
 for _ = 1, seconds do
  now = now + 1
  run_due()
 end
end
-- Every pending emerge done, then the server step after it.
local function finish()
 local jobs = emerge; emerge = {}
 for _, job in ipairs(jobs) do job.fn(nil, 0, 0) end
 run_due()
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
 at_stone(p, id or "highcourt")
 fields(p, {waystone_tab_2="Expeditions"})
 return fs_of(p)
end
local function enter_by_tab(p, run, id)
 expeditions_tab(p, id)
 fields(p, {["enter_" .. run.id]="Enter"})
 finish()
 check(E.run_inside(p) == run, p:get_player_name() .. " entered")
end
local function registrar(p)
 shown[p:get_player_name()] = nil
 local npc = {_grug_socket_role=E.registrar.ROLE, _grug_start="highcourt",
  object={get_pos=function() return p:get_pos() end}}
 check(E.open_registrar(p, npc), "the registrar opens for " .. p:get_player_name())
 return fs_of(p)
end
local function last_feed(name, k)
 for i = #feeds, 1, -1 do
  if feeds[i].name == name and (not k or feeds[i].key == k) then return feeds[i].text end
 end
end
local function rejoin(p)
 for _, fn in ipairs(callbacks.leave) do fn(p) end
 return function()
  for _, fn in ipairs(callbacks.join) do fn(p) end
 end
end

local eve, cid = new_player("Eve", 25), new_player("Cid", 25)
local ann, bob, dee = new_player("Ann", 26), new_player("Bob", 25), new_player("Dee", 24)
party("p1", "Ann", "Bob", "Dee")
local CONFIRM = "Cancel this Expedition? You cannot open or enter an Expedition for 5 minutes."
check(E.CANCEL_CONFIRM == CONFIRM, "the confirmation's text")

-- A. Who may finish or cancel, and when.
hold_preparation = true
local run = assert(E.create(ann, "test_vault", 4))
local ok, why = E.can_finish(ann)
check(not ok and why == "Your Expedition is still being prepared. Wait until it is ready.",
 "A Finish refused while preparing: " .. tostring(why))
ok, why = E.can_cancel(ann)
check(not ok and why == "Your Expedition is still being prepared. Wait until it is ready.",
 "A Cancel refused while preparing")
local fs = registrar(ann)
check(not has(fs, ";cancel;") and not has(fs, ";finish;"), "A no button while preparing")
hold_preparation = false
table.remove(held, 1)(true)
check(run.state == "ready", "A ready")
ok, why = E.can_finish(ann)
check(not ok and why == "The Expedition can be finished once its boss is dead.", "A Finish before rewards_open")
ok, why = E.can_finish(bob)
check(not ok and why == "Only your party leader can finish the Expedition.", "A Finish: a member")
ok, why = E.can_cancel(dee)
check(not ok and why == "Only your party leader can cancel the Expedition.", "A Cancel: a member")
check(E.can_cancel(ann), "A the leader may cancel")
fs = registrar(ann)
check(has(fs, "button[2.3,9.15;3.1,0.6;cancel;Cancel]") and not has(fs, ";finish;"), "A the leader sees Cancel")
fs = registrar(bob)
check(not has(fs, ";cancel;") and not has(fs, ";finish;") and has(fs, ";enter;"), "A a member: Enter alone")
fs = expeditions_tab(bob, "dawnmere")
check(has(fs, "enter_" .. run.id) and has(fs, "Ready. It waits 10 minutes for you.") and
 not has(fs, "act_"), "A a member's tab: the state, no button")
rewards[run] = true
check(E.can_finish(ann), "A the leader may finish once rewards_open")
ok, why = E.can_cancel(ann)
check(not ok and why == "The boss is dead: finish the Expedition instead.", "A then no Cancel")
fs = registrar(ann)
check(has(fs, "button[2.3,9.15;3.1,0.6;finish;Finish]") and not has(fs, ";cancel;"), "A the leader sees Finish")
fs = expeditions_tab(ann, "highcourt")
check(has(fs, "act_finish_" .. run.id .. ";Finish]") and has(fs, "enter_" .. run.id), "A the tab: Finish and Enter")
local solo = assert(E.create(eve, "test_vault", 4))
rewards[solo] = true
check(E.can_finish(eve), "A the solo owner may finish")
E.end_run(solo, "test")

-- B. Finish at the registrar and the minute after it.
enter_by_tab(bob, run, "dawnmere")
feeds, banners = {}, {}
registrar(ann)
fields(ann, {finish="Finish"})
check(run.closing and run.closing.reason == "finished" and run.closing.by == "Ann" and
 E.closing_left(run) == 60 and run.state == "running", "B closing, a minute left")
check(has(fs_of(ann), "Finished. It ends in 60 seconds.") and not has(fs_of(ann), ";finish;"),
 "B the registrar shows the countdown")
check(last_feed("Ann") == "You finished the Expedition. It ends in 60 seconds.", "B the leader's line")
check(last_feed("Dee") == "Ann finished the Expedition. It ends in 60 seconds.", "B a member outside")
check(last_feed("Bob") == nil and banners.Bob == "This Expedition ends in 60 seconds.",
 "B inside: the banner, no line")
check(last_feed("Eve") == nil and banners.Eve == nil, "B nobody else")
ok, why = E.can_finish(ann)
check(not ok and why == "This Expedition is already closing.", "B no second Finish")
ok, why = E.can_cancel(ann)
check(not ok and why == "This Expedition is already closing.", "B no Cancel while closing")
advance(1)
check(banners.Bob == "This Expedition ends in 59 seconds.", "B once a second")
fs = expeditions_tab(dee, "dawnmere")
check(has(fs, "Finished. It ends in 59 seconds.") and not has(fs, "act_"), "B a member: the time left, no button")
advance(48)
check(E.closing_left(run) == 11 and E.may_enter(ann), "B at T-11 one may enter")
banners.Ann = nil
enter_by_tab(ann, run, "highcourt")
check(banners.Ann == "This Expedition ends in 11 seconds.", "B a late entrant sees the countdown")
-- A trip started at T-11 that arrives at T-10.
expeditions_tab(dee, "dawnmere")
fields(dee, {["enter_" .. run.id]="Enter"})
check(#emerge == 1, "B Dee's trip starts")
advance(1)
finish()
check(E.run_inside(dee) == nil and last_feed("Dee") == "This Expedition is closing.",
 "B refused on arrival at T-10")
ok, why = E.may_enter(dee)
check(not ok and why == "This Expedition is closing.", "B refused at the click")
fs = expeditions_tab(dee, "dawnmere")
check(has(fs, "This Expedition is closing.") and not has(fs, "enter_"), "B the tab says so")
check(banners.Ann == "This Expedition ends in 10 seconds." and banners.Bob == banners.Ann, "B both see 10")
ann.hp = 0
advance(9)
check(run.state ~= "ended" and banners.Bob == "This Expedition ends in 1 second.", "B one second")
advance(1)
check(run.state == "ended" and ended[run] == "finished", "B the end at 60, reason finished")
check(E.run_inside(bob) == nil and E.run_inside(ann) == nil and not E.run_of(ann), "B nobody inside, the slot free")
check(#emerge == 1, "B one way out: the dead player stays")
finish()
check(math.abs(bob.pos.x - STONE.dawnmere.x) < 2, "B back at the waystone of the way in")
check(last_feed("Dee") == "Your Expedition has ended.", "B the end's line")
check(not E.deserter_left(ann), "B Finish marks nobody")
ann.hp = 20

-- C. Cancel a ready run never entered, at the registrar, with its confirmation.
local own = assert(E.create(eve, "test_vault", 4))
fs = registrar(eve)
check(has(fs, ";cancel;Cancel]"), "C Cancel on a ready run")
fields(eve, {cancel="Cancel"})
fs = fs_of(eve)
check(has(fs, CONFIRM) and has(fs, ";cancel_confirm;Confirm]") and has(fs, ";cancel_back;Back]") and
 not has(fs, ";enter;"), "C the confirmation first")
check(own.state == "ready" and not E.deserter_left(eve), "C nothing yet")
fields(eve, {cancel_back="Back"})
check(has(fs_of(eve), ";cancel;Cancel]") and not has(fs_of(eve), CONFIRM), "C Back")
fields(eve, {cancel_confirm="Confirm"})
check(own.state == "ready", "C a Confirm without its question does nothing")
feeds = {}
fields(eve, {cancel="Cancel"})
fields(eve, {cancel_confirm="Confirm"})
check(own.state == "ended" and ended[own] == "cancelled", "C nobody inside: it ends at once")
check(last_feed("Eve", "expedition") == "Your Expedition was cancelled.", "C the end's line")
check(last_feed("Eve", "expedition_mark") == "Deserter's Mark: no Expeditions for 5:00.", "C the mark's line")
check(E.deserter_left(eve) == 300 and eve.data[E.DESERTER_META] == tostring(now + 300), "C the mark, saved")
check(has(fs_of(eve), "Deserter's Mark: no Expeditions for 5:00.") and not has(fs_of(eve), ";open;"),
 "C the registrar's list names the mark")

-- D. The Deserter's Mark.
local entries = sources[1](eve, now * 1e6)
check(#sources == 1 and entries and entries[1].id == "deserter_mark" and
 entries[1].expiry_us == (now + 300) * 1e6, "D a timed status")
check(sources[1](cid, now * 1e6) == nil, "D none without it")
ok, why = E.can_create(eve, "test_vault", 4)
check(not ok and why == "Deserter's Mark: no Expeditions for 5:00.", "D no Expedition opened")
local back = rejoin(eve)
check(not E.deserter_left(eve), "D offline, out of the rules' table")
advance(48)
back()
ok, why = E.can_create(eve, "test_vault", 4)
check(E.deserter_left(eve) == 252 and not ok and why == "Deserter's Mark: no Expeditions for 4:12.",
 "D after a login the time left: " .. tostring(why))
check(sources[1](eve, now * 1e6)[1].expiry_us == (now + 252) * 1e6, "D its status again")
advance(251)
check(E.deserter_left(eve) == 1, "D one second left")
advance(1)
check(not E.deserter_left(eve) and sources[1](eve, now * 1e6) == nil and E.can_create(eve, "test_vault", 4),
 "D gone after 5 minutes")
check(eve.data[E.DESERTER_META] ~= "", "D its saved end stays until the next login")
rejoin(eve)()
check(eve.data[E.DESERTER_META] == "", "D cleared at the login")

-- C. Cancel a running run from a waystone's tab: the countdown, nobody gets in.
local second = assert(E.create(ann, "test_vault", 4))
enter_by_tab(bob, second, "dawnmere")
fs = expeditions_tab(ann, "highcourt")
check(has(fs, "act_cancel_" .. second.id .. ";Cancel]") and has(fs, "Under way."), "C the tab's Cancel")
fields(bob, {["act_cancel_" .. second.id]="Cancel"})
check(not second.closing, "C a member's forged click acts on nothing")
fields(ann, {["act_cancel_" .. second.id]="Cancel"})
fs = fs_of(ann)
check(has(fs, CONFIRM) and has(fs, "act_confirm;Confirm]") and has(fs, "act_back;Back]") and
 not has(fs, "act_cancel_") and not second.closing, "C the tab asks first")
fields(ann, {act_back="Back"})
check(has(fs_of(ann), "act_cancel_" .. second.id) and not has(fs_of(ann), CONFIRM), "C the tab's Back")
feeds, banners = {}, {}
fields(ann, {["act_cancel_" .. second.id]="Cancel"})
fields(ann, {act_confirm="Confirm"})
check(second.closing and second.closing.reason == "cancelled" and second.state == "running", "C closing")
check(has(fs_of(ann), "Cancelled. It ends in 60 seconds.") and not has(fs_of(ann), "act_"),
 "C the tab shows it, no more buttons")
check(banners.Bob == "This Expedition was cancelled. It ends in 60 seconds.", "C the banner inside")
check(last_feed("Dee") == "Ann cancelled the Expedition. It ends in 60 seconds.", "C a member outside")
check(E.deserter_left(ann) == 300 and not E.deserter_left(bob) and not E.deserter_left(dee),
 "C only the canceller is marked")
ok, why = E.may_enter(dee)
check(not ok and why == "This Expedition was cancelled.", "C nobody gets in, at once")
ok, why = E.can_cancel(ann)
check(not ok and why == "This Expedition is already closing.", "C no second Cancel")
-- The stone inside: a member sees the state alone.
E.use_waystone(bob, second.places.start_waystone)
fields(bob, {waystone_tab_2="Expeditions"})
fs = fs_of(bob)
check(has(fs, "Your Expedition") and has(fs, "Cancelled. It ends in 60 seconds.") and not has(fs, "act_") and
 not has(fs, "enter_"), "C the stone inside: the state, no button, no Enter")
advance(60)
check(second.state == "ended" and ended[second] == "cancelled" and E.run_inside(bob) == nil,
 "C the end at 60, everyone out")
finish()

-- C. Finish at a stone inside, by a solo owner, needs no confirmation.
local cids = assert(E.create(cid, "test_vault", 4))
rewards[cids] = true
enter_by_tab(cid, cids, "highcourt")
E.use_waystone(cid, cids.places.start_waystone)
fields(cid, {waystone_tab_2="Expeditions"})
check(has(fs_of(cid), "act_finish_" .. cids.id .. ";Finish]") and not has(fs_of(cid), "enter_"),
 "C the stone inside: Finish")
fields(cid, {["act_finish_" .. cids.id]="Finish"})
check(cids.closing and cids.closing.reason == "finished" and banners.Cid == "This Expedition ends in 60 seconds.",
 "C finished from inside at once")
-- The Claim Stone's way: the same block and action through grug_home.
local block = home.expedition_actions(cid)
check(block and block.id == tostring(cids.id) and #block.buttons == 0, "C the block, closing: no button")
E.end_run(cids, "test")
finish()

-- E. A solo owner joins a foreign party.
local fay, ivy, jon = new_player("Fay", 25), new_player("Ivy", 25), new_player("Jon", 25)
new_player("Gus", 25)
party("p2", "Gus")
local function join_p2(p)
 local name = p:get_player_name()
 table.insert(parties.p2.members, name)
 party_of[name] = "p2"
 emit("membership", name)
end
local fays = assert(E.create(fay, "test_vault", 4))
join_p2(fay)
check(fays.state == "ended" and ended[fays] == "joined_party" and E.deserter_left(fay) == 300,
 "E unfinished: ended and marked")
local ivys = assert(E.create(ivy, "test_vault", 4))
rewards[ivys] = true
join_p2(ivy)
check(ivys.state == "ended" and ended[ivys] == "joined_party" and not E.deserter_left(ivy),
 "E rewards_open: no mark")
local jons = assert(E.create(jon, "test_vault", 4))
rewards[jons] = true
check(E.finish(jon), "E finished first")
rewards[jons] = false
join_p2(jon)
check(jons.state == "ended" and ended[jons] == "joined_party" and not E.deserter_left(jon),
 "E already finished: no mark")

-- F. Left empty for 10 minutes: no mark.
local kim = new_player("Kim", 25)
local kims = assert(E.create(kim, "test_vault", 4))
advance(599)
check(kims.state == "ready", "F still reserved")
advance(1)
check(kims.state == "ended" and ended[kims] == "empty" and not E.deserter_left(kim), "F lapsed, no mark")

-- G. The leader hands on.
local lea, max = new_player("Lea", 25), new_player("Max", 25)
party("p3", "Lea", "Max")
local leas = assert(E.create(lea, "test_vault", 4))
check(E.cancel(lea) and leas.state == "ended" and E.deserter_left(lea) == 300, "G cancelled, marked")
parties.p3.leader = "Max"
emit("leadership", "Lea", "Max")
local maxs = E.create(max, "test_vault", 4)
check(maxs and E.run_of(lea) == maxs, "G the new leader opens one at once")
ok, why = E.can_enter(lea)
check(not ok and why == "Deserter's Mark: no Expeditions for 5:00.", "G the bearer cannot enter")
check(E.can_enter(max), "G the new leader can")
fs = expeditions_tab(lea, "highcourt")
check(has(fs, "Deserter's Mark: no Expeditions for 5:00.") and not has(fs, "enter_") and not has(fs, "act_"),
 "G the bearer's tab: the mark, no button")
parties.p3.leader = "Lea"
emit("leadership", "Lea", "Max")
fs = expeditions_tab(lea, "highcourt")
check(has(fs, "Deserter's Mark: no Expeditions for 5:00.") and has(fs, "act_cancel_" .. maxs.id),
 "G a leader who cannot enter still sees Cancel")
E.end_run(maxs, "test")

for _, row in ipairs(chat) do
 check(not has(row[2], "Expedition"), "no Expedition text in chat: " .. row[2])
end
print("R721 FINISH PORTABLE PASS checks=" .. checks)
