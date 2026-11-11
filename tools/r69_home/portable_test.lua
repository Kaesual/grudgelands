-- Round 69 lane HOME portable fixture (LuaJIT): respawn goes where the home
-- teleport goes, and every path ends held-to-valid.
--
--   luajit tools/r69_home/portable_test.lua [repo]
--
-- Loads the shipped grug_home (init, claim_home, travel, innkeeper) and the
-- real grug_factions respawn hook on a fake engine, with fake claims on top
-- of the real grug_housing interface file. A run's every teleport and the
-- moment the hold is released are logged and judged:
--   A  one resolver: respawn and return home end at the same place for a
--      claim (fuelled, unfuelled), a bound innkeeper and no binding;
--   C  no cooldown read or started, no combat refusal;
--   L  the arrival: one teleport, on the stone, into a block core.load_area
--      had to bring in;
--   B  a cube blocked before the respawn: never in the cube, straight to the
--      innkeeper; blocked while emerging: held, on to the innkeeper;
--   P  a claim's area failing or timing out ends at the innkeeper, the
--      innkeeper's at the start pocket, no valid pocket releases the hold;
--   O  a claim lost while dead, or between the request and the arrival;
--   S  the session: death, leave and rejoin on every leg;
--   I  an innkeeper's blocked authored side: the first free other side;
--   H  no faction and creation stasis behave as before.
-- Prints "R69 HOME PASS checks=<n>" or the failures.
rawset(_G, "grug_sounds", {play = function() return false end, CLICK_STYLE = ""})
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
 checks = checks + 1
 if not ok then failures[#failures + 1] = label end
end

local clock = 10000
os.time = function() return clock end

local callbacks = {join={}, leave={}, die={}, fields={}, respawn={}, loaded={}, step={}}
local after, emerge, chat = {}, {}, {}
local player, online = nil, true
local function register(kind) return function(fn) callbacks[kind][#callbacks[kind] + 1] = fn end end
local vmeta = {}
local function vnew(x, y, z)
 if type(x) == "table" then return setmetatable({x=x.x, y=y or x.y, z=z or x.z}, vmeta) end
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

-- World: full "floor" nodes up to y = 100, air above, plus overrides. Mapblocks
-- in `unloaded` read as nil until core.load_area touches them; `lost` ones stay.
local cells, unloaded, lost, load_calls = {}, {}, {}, 0
local function key(p) return round(p.x) .. "," .. round(p.y) .. "," .. round(p.z) end
local function block_of(p)
 return math.floor(round(p.x) / 16) .. "," .. math.floor(round(p.y) / 16) .. "," ..
  math.floor(round(p.z) / 16)
end
local storage_data = {}
rawset(_G, "core", {
 get_modpath=function(name) return repo .. "/mods/PLAYER/" .. name end,
 get_current_modname=function() return "grug_home" end,
 dir_to_yaw=function() return 0 end,
 load_area=function(a, b)
  load_calls = load_calls + 1
  b = b or a
  for y = round(a.y), round(b.y) do
   for x = round(a.x), round(b.x) do
    for z = round(a.z), round(b.z) do
     unloaded[block_of({x=x, y=y, z=z})] = nil
    end
   end
  end
 end,
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
 chat_send_player=function(_, message) chat[#chat + 1] = message end,
 show_formspec=function() end,
 after=function(delay, fn) after[#after + 1] = {delay=delay, fn=fn} end,
 emerge_area=function(minp, maxp, fn)
  emerge[#emerge + 1] = {fn=fn, center=vnew((minp.x + maxp.x) / 2, (minp.y + maxp.y) / 2,
   (minp.z + maxp.z) / 2)}
 end,
 EMERGE_CANCELLED=1, EMERGE_ERRORED=2,
 get_node_or_nil=function(pos)
  local block = block_of(pos)
  if unloaded[block] or lost[block] then return nil end
  local name = cells[key(pos)]
  if name then return {name=name} end
  return {name=round(pos.y) <= 100 and "floor" or "air"}
 end,
 registered_nodes={floor={walkable=true}, air={walkable=false},
  stone={walkable=true}, ["grug_housing:claim_stone"]={walkable=true},
  water={walkable=false, liquidtype="source"},
  fire={walkable=false, damage_per_second=4}},
 registered_entities={},
})

local holds, trail = {}, {} -- the hold, and {pos=, held=} per teleport
local no_start = false
rawset(_G, "grug_core", {factions={accord={}, throng={}},
 map_reset={clear=function() end, register_on_relocate=function() end},
 hold_movement=function(_, name) holds[name] = true end,
 release_movement=function(p, name)
  if holds[name] then holds[name] = nil; trail.released_at = vnew(p:get_pos()) end
 end,
 get_player_race=function() return player.race end,
 in_combat=function(p) return p.combat end,
 invalidate_combat_identity=function() end,
 start_position=function() if not no_start then return vnew(0, 101, 0) end end,
 zone_authority_installed=function() return true end})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local defs = dofile(repo .. "/mods/PLAYER/grug_home/locations.lua")
for i, row in ipairs(defs) do
 grug_core.register_settlement_sockets(row.id, row.race, {x=i * 100, y=100, z=0},
  {{id=row.socket, role="idle", x=0, y=1, z=0, dir={x=0, z=1}},
   {id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}})
end
for i, row in ipairs({{"pvp_fortress_accord", "human"}, {"pvp_fortress_throng", "orc"}}) do
 grug_core.register_settlement_sockets(row[1], row[2], {x=(#defs + i) * 100, y=100, z=0},
  {{id="travel_waypoint", role="waypoint", x=40, y=1, z=0, dir={x=0, z=1}}})
end
rawset(_G, "grug_mobs", {register_start_socket_role=function() end,
 dragon_map_markers=function() return {} end})
rawset(_G, "grug_mounts", {dismount=function() end})
dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")

rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
local claim_listeners = {}
do
 local register_claim_listener = grug_housing.register_on_claim_changed
 grug_housing.register_on_claim_changed = function(fn)
  claim_listeners[#claim_listeners + 1] = fn
  return register_claim_listener(fn)
 end
end
local claims = {}
grug_housing.player_claim = function(name)
 local entry = claims[name]
 if not entry then return nil, "never" end
 return entry.claim, entry.state
end
grug_housing.is_active = function(claim) return (claim.paid_until or 0) > os.time() end
local next_claim = 0
local function place_claim(owner, center, paid)
 next_claim = next_claim + 1
 local claim = {id=next_claim, owner=owner, center=vnew(center), placed_at=clock,
  activated_at=clock, paid_until=clock + (paid or 3600)}
 claims[owner] = {claim=claim, state="placed"}
 cells[key(center)] = "grug_housing:claim_stone"
 return claim
end
local function lose_claim(owner, event)
 local entry = claims[owner]
 local claim = entry.claim
 cells[key(claim.center)] = nil
 claims[owner] = event == "destroyed" and {claim=claim, state="destroyed"} or nil
 for _, fn in ipairs(claim_listeners) do fn(claim, event) end
end

local data, meta
local function new_player(fields)
 data = {["grug_factions:faction"]="accord"}
 for k, v in pairs(fields or {}) do data[k] = v end
 meta = {get_string=function(_, k) return data[k] or "" end,
  set_string=function(_, k, v) data[k] = v end}
 player = {race="human", hp=20, pos=vnew(5000, 300, 5000),
  get_player_name=function() return "tester" end, is_player=function() return true end,
  get_meta=function() return meta end, get_hp=function(self) return self.hp end,
  get_pos=function(self) return self.pos end,
  set_pos=function(self, p)
   self.pos = vnew(p)
   trail[#trail + 1] = {pos=vnew(p), held=holds["grug_home:respawn"] == true}
  end,
  get_velocity=function() return vnew(0, 0, 0) end, add_velocity=function() end,
  get_look_horizontal=function() return 0 end}
 return player
end
new_player()
core.colorize = function(_, text) return text end
local factions_joins = #callbacks.join
dofile(repo .. "/mods/PLAYER/grug_home/init.lua")
local home = grug_home
local home_joins = {unpack(callbacks.join, factions_joins + 1)}

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
local function timeout()
 local tasks = after; after = {}
 for _, t in ipairs(tasks) do if t.delay == 30 then t.fn() else after[#after + 1] = t end end
end
local function same(a, b) return vector.distance(a, b) < 1e-9 end
local function last_chat() return chat[#chat] or "" end
local function held() return holds["grug_home:respawn"] == true end
local function reset()
 after, emerge, chat = {}, {}, {}
 trail = {}
 cells, unloaded, lost = {}, {}, {}
 holds = {}
 claims = {}
 load_calls = 0
 no_start = false
end
local function respawn() return callbacks.respawn[1](player) end
-- A run is over: nothing pending, the hold gone, every teleport held.
local function ended(label, pos)
 check(not held(), label .. ": hold released")
 check(not home.is_pending(player), label .. ": nothing pending")
 check(pos == nil or same(player.pos, pos), label .. ": ends at the expected place")
 check(pos == nil or (trail.released_at and same(trail.released_at, pos)),
  label .. ": released only there")
 for _, step in ipairs(trail) do check(step.held, label .. ": every teleport held") end
 emerge = {}
 after = {}
end

local stone_pos = vnew(700, 101, 700)
local FEET = vnew(700, 101.51, 700)
local BLOCK_CELL = vnew(700, 102, 700)
local HEAD_CELL = vnew(700, 103, 700)
local START = vnew(1, 100.51, 0)
local highcourt = home.location("highcourt")
local dawnmere = home.location("dawnmere")

local function claim_player(paid)
 reset()
 new_player({["grug_home:id"]="highcourt"})
 local claim = place_claim("tester", stone_pos, paid)
 assert(home.set_home_claim(player))
 trail, chat = {}, {}
 return claim
end

-- ---------------------------------------------------------------------------
-- A: one resolver
-- ---------------------------------------------------------------------------
local function agree(label, setup, place)
 setup()
 check(home.return_home(player), label .. " return request"); finish()
 local returned = vnew(player.pos)
 setup()
 check(respawn(), label .. " respawn hook"); finish()
 check(same(returned, player.pos) and same(player.pos, place()),
  label .. ": respawn and return home end at the same place")
 ended(label, place())
end
agree("A claim", function() claim_player() end, function() return FEET end)
agree("A unfuelled", function() claim_player(-60) end, function() return FEET end)
agree("A innkeeper", function() reset(); new_player({["grug_home:id"]="highcourt"}) end,
 function() return highcourt.arrival end)
agree("A none", function() reset(); new_player() end, function() return dawnmere.arrival end)

-- ---------------------------------------------------------------------------
-- C: no cooldown, no combat
-- ---------------------------------------------------------------------------
claim_player()
data["grug_home:ready_at"] = tostring(clock + 900)
player.combat = true
check(respawn() and same(player.pos, FEET), "C respawn ignores cooldown and combat")
finish()
check(home.remaining(player) == 900, "C cooldown neither read nor changed")
ended("C", FEET)
claim_player()
check(respawn(), "C2 request"); finish()
check(data["grug_home:ready_at"] == nil, "C respawn starts no cooldown")
ended("C2", FEET)

-- ---------------------------------------------------------------------------
-- L: the arrival
-- ---------------------------------------------------------------------------
claim_player()
check(respawn() and held() and #trail == 1, "L one teleport, held")
check(same(player.pos, FEET), "L straight to the feet position on the stone, not the cell centre")
check(player.pos.y > stone_pos.y + 0.5 and player.pos.y < stone_pos.y + 0.6, "L on the stone's top")
do local job = finish(); check(same(job.center, stone_pos), "L the claim's area is emerged") end
check(#trail == 1, "L no second teleport")
ended("L", FEET)
-- The stone's block is not in memory: core.load_area brings the cube in.
claim_player()
unloaded[block_of(BLOCK_CELL)] = true
unloaded[block_of(HEAD_CELL)] = true
check(respawn() and load_calls == 1 and same(player.pos, FEET), "L unloaded cube read after load_area")
finish()
ended("L unloaded", FEET)
-- A cube across two mapblocks: both are loaded.
do
 reset(); new_player({["grug_home:id"]="highcourt"})
 local upper = vnew(700, 94, 700) -- cell 95, head 96: blocks 5 and 6
 place_claim("tester", upper)
 assert(home.set_home_claim(player)); trail, chat = {}, {}
 for y = 95, 96 do cells[key({x=700, y=y, z=700})] = "air" end
 unloaded[block_of({x=700, y=95, z=700})] = true
 unloaded[block_of({x=700, y=96, z=700})] = true
 check(respawn() and same(player.pos, vnew(700, 94.51, 700)), "L cube across two mapblocks")
 finish(); ended("L two blocks", vnew(700, 94.51, 700))
end

-- ---------------------------------------------------------------------------
-- B: blocked
-- ---------------------------------------------------------------------------
local function blocked_early(label, pos, name)
 claim_player()
 cells[key(pos)] = name
 check(respawn() and held(), label .. " held")
 check(#trail == 1 and same(trail[1].pos, highcourt.arrival), label .. " never in the cube")
 check(last_chat():find("arrival is blocked", 1, true) and last_chat():find("Highcourt Innkeeper", 1, true),
  label .. " message: " .. last_chat())
 check(held(), label .. " held while the innkeeper's area emerges")
 local job = finish(); check(same(job.center, highcourt.pos), label .. " innkeeper prepared")
 check(#trail == 1 and home.home_is_claim(player), label .. " one teleport, the claim stays home")
 ended(label, highcourt.arrival)
end
blocked_early("B solid", BLOCK_CELL, "stone")
blocked_early("B liquid", BLOCK_CELL, "water")
blocked_early("B damaging", BLOCK_CELL, "fire")
blocked_early("B headroom", HEAD_CELL, "stone")
-- The block is gone from the map: the same, not a stranded player.
claim_player()
lost[block_of(BLOCK_CELL)] = true
check(respawn() and same(player.pos, highcourt.arrival), "B unreadable cube ends at the innkeeper")
finish(); ended("B unreadable", highcourt.arrival)
-- Blocked while the player waits there: held on, moved out.
claim_player()
check(respawn() and same(player.pos, FEET), "B late request")
cells[key(BLOCK_CELL)] = "stone"
finish()
check(held(), "B late: still held after the check, the way the release used to go")
check(same(player.pos, highcourt.arrival), "B late: out of the cube at once")
check(last_chat():find("arrival is blocked", 1, true), "B late message")
do local job = finish(); check(same(job.center, highcourt.pos), "B late: innkeeper prepared") end
check(#trail == 2, "B late: one more teleport, no third")
ended("B late", highcourt.arrival)

-- ---------------------------------------------------------------------------
-- P: an area that cannot be prepared
-- ---------------------------------------------------------------------------
claim_player()
check(respawn(), "P failed request"); finish(core.EMERGE_ERRORED)
check(held() and same(player.pos, highcourt.arrival), "P failed claim area: on to the innkeeper, held")
finish(); ended("P failed claim", highcourt.arrival)
claim_player()
check(respawn(), "P stalled request")
clock = clock + 29; deferred(); check(held(), "P stalled: held before the timeout")
timeout()
check(held() and same(player.pos, highcourt.arrival), "P stalled claim: on to the innkeeper, held")
table.remove(emerge, 1) -- the stalled claim area's emerge never comes
finish(); ended("P stalled claim", highcourt.arrival)
-- The stalled claim area's late emerge does not touch the next leg.
claim_player()
check(respawn(), "P late request"); timeout()
do local stale = table.remove(emerge, 1); stale.fn(nil, 0, 0); deferred() end
check(held() and home.is_pending(player), "P the stale emerge does not end the innkeeper leg")
finish(); ended("P late emerge", highcourt.arrival)
-- The innkeeper fails too: the start pocket, held until there.
local function to_start(label, spoil)
 claim_player()
 cells[key(BLOCK_CELL)] = "stone"
 check(respawn(), label .. " request")
 spoil()
 check(not held() and same(player.pos, START), label .. ": the start pocket")
 check(last_chat():find("starting town", 1, true), label .. " message")
 ended(label, START)
end
to_start("P innkeeper emerge failed", function() finish(core.EMERGE_ERRORED) end)
to_start("P innkeeper timeout", function()
 check(held(), "P innkeeper timeout: held"); timeout()
end)
-- Every side of the innkeeper blocked (0.75.4: one blocked side is not enough).
local function block_inn(row, sides)
 for _, s in ipairs(sides) do
  cells[key(vnew(row.pos.x + s[1], row.pos.y + 1, row.pos.z + s[2]))] = "stone"
 end
end
local ALL_SIDES = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
to_start("P innkeeper unsafe", function()
 block_inn(highcourt, ALL_SIDES)
 finish()
end)
-- No valid pocket: the hold must not stay on.
local function nothing_left(label, spoil)
 reset(); new_player({["grug_home:id"]="highcourt"})
 spoil()
 check(respawn(), label .. " request")
 check(held(), label .. " held")
 finish(core.EMERGE_ERRORED)
 check(not held() and last_chat() == "Home arrival is unavailable.", label .. ": released, told")
 emerge, after = {}, {}
end
nothing_left("P no start", function() no_start = true end)
nothing_left("P bad pocket", function() cells[key(vnew(1, 102, 0))] = "stone" end)

-- ---------------------------------------------------------------------------
-- I: the innkeeper's other sides (0.75.4). Lethariel's and Kezamba's authored
-- side stood in a barrel stack: a blocked side moves the arrival to the first
-- free other side of the same socket, in the order +x, -x, +z, -z.
-- ---------------------------------------------------------------------------
local function beside(row, dx, dz) return vnew(row.pos.x + dx, row.pos.y - 0.49, row.pos.z + dz) end
check(same(highcourt.arrival, beside(highcourt, 1, 0)), "I the authored side is +x here")
local function inn_player(blocked)
 reset(); new_player({["grug_home:id"]="highcourt"})
 block_inn(highcourt, blocked)
 trail, chat = {}, {}
end
-- A return home: the next free side, one teleport, the cooldown started.
inn_player({{1, 0}})
check(home.return_home(player), "I return request"); finish()
check(same(player.pos, beside(highcourt, -1, 0)) and #trail == 1, "I return lands on -x")
check(home.remaining(player) > 0, "I return starts the cooldown")
emerge, after = {}, {}
inn_player({{1, 0}, {-1, 0}})
check(home.return_home(player), "I return request 2"); finish()
check(same(player.pos, beside(highcourt, 0, 1)), "I two sides blocked: +z")
emerge, after = {}, {}
-- Headroom counts: a free floor under a blocked head is a blocked side.
inn_player({})
cells[key(vnew(highcourt.pos.x + 1, highcourt.pos.y, highcourt.pos.z))] = "stone"
check(home.return_home(player), "I return request 3"); finish()
check(same(player.pos, beside(highcourt, -1, 0)), "I feet blocked: -x")
emerge, after = {}, {}
-- Every side blocked: the return stays where it was and says so.
inn_player(ALL_SIDES)
local before = vnew(player.pos)
check(home.return_home(player), "I return request 4"); finish()
check(same(player.pos, before) and #trail == 0, "I all sides blocked: not moved")
check(last_chat() == "Home arrival is unavailable. Please try again.", "I all sides blocked message")
check(home.remaining(player) == 0, "I all sides blocked: no cooldown")
emerge, after = {}, {}
-- A respawn waits on the free side from the first teleport on (the area is in
-- memory) and is not moved again.
inn_player({{1, 0}})
check(respawn() and held() and #trail == 1 and same(player.pos, beside(highcourt, -1, 0)),
 "I respawn waits on -x")
finish()
check(#trail == 1, "I respawn: no second teleport")
ended("I respawn", beside(highcourt, -1, 0))
-- The socket's blocks not in memory but on disk: core.load_area brings them in
-- and the respawn still waits on the free side from the first teleport.
inn_player({{1, 0}})
for dx = -1, 1 do for dy = -1, 1 do for dz = -1, 1 do
 unloaded[block_of(vector.offset(highcourt.pos, dx, dy, dz))] = true
end end end
check(respawn() and #trail == 1 and same(player.pos, beside(highcourt, -1, 0)),
 "I unloaded socket: load_area, waits on -x")
finish(); ended("I unloaded socket", beside(highcourt, -1, 0))
-- The socket's block not generated yet: the authored side to wait on, the free
-- side on arrival.
inn_player({{1, 0}})
-- (the socket stands on a mapblock edge: every block of its 3 x 3 x 3 box)
for dx = -1, 1 do for dy = -1, 1 do for dz = -1, 1 do
 lost[block_of(vector.offset(highcourt.pos, dx, dy, dz))] = true
end end end
check(respawn() and same(player.pos, highcourt.arrival), "I unread socket: waits on the authored side")
lost = {}
finish()
check(#trail == 2, "I unread socket: one move on arrival")
ended("I unread socket", beside(highcourt, -1, 0))
-- A blocked claim hands on to an innkeeper whose authored side is blocked.
claim_player()
cells[key(BLOCK_CELL)] = "stone"
block_inn(highcourt, {{1, 0}})
check(respawn() and #trail == 1 and same(player.pos, beside(highcourt, -1, 0)),
 "I claim blocked: waits on the innkeeper's free side")
finish(); ended("I claim to inn", beside(highcourt, -1, 0))
claim_player()
block_inn(highcourt, {{1, 0}})
check(home.return_home(player), "I claim return request")
cells[key(BLOCK_CELL)] = "stone"
finish()
check(last_chat():find("arrival is blocked", 1, true), "I claim return: blocked message")
finish()
check(same(player.pos, beside(highcourt, -1, 0)), "I claim return: the innkeeper's free side")
emerge, after = {}, {}

-- ---------------------------------------------------------------------------
-- O: the claim goes
-- ---------------------------------------------------------------------------
for _, event in ipairs({"picked_up", "destroyed", "removed"}) do
 -- While dead, online.
 claim_player()
 player.hp = 0
 for _, fn in ipairs(callbacks.die) do fn(player, {type="fall"}) end
 lose_claim("tester", event)
 player.hp = 20
 check(last_chat():find("Your home is now the Highcourt Innkeeper", 1, true), "O " .. event .. " message")
 check(respawn() and same(player.pos, highcourt.arrival), "O " .. event .. " while dead: the innkeeper")
 finish(); ended("O " .. event .. " dead", highcourt.arrival)
 -- Between the request and the arrival.
 claim_player()
 check(respawn() and same(player.pos, FEET), "O " .. event .. " request")
 lose_claim("tester", event)
 finish()
 check(held() and same(player.pos, highcourt.arrival), "O " .. event .. " on the way: on to the innkeeper, held")
 do local job = finish(); check(same(job.center, highcourt.pos), "O " .. event .. " innkeeper prepared") end
 ended("O " .. event .. " on the way", highcourt.arrival)
end
-- Offline: the next login delivers, the stale target never counts.
claim_player()
claims.tester = {claim=nil, state="carried"}
for _, fn in ipairs(home_joins) do fn(player) end
check(last_chat():find("Claim Stone is gone", 1, true), "O login message")
check(respawn() and same(player.pos, highcourt.arrival), "O offline: the innkeeper")
finish(); ended("O offline", highcourt.arrival)
-- The claim goes while its area failed: the emerge of the home that replaced
-- it decides, not the old one's error.
claim_player()
check(respawn(), "O failed request")
lose_claim("tester", "destroyed")
finish(core.EMERGE_ERRORED)
check(held() and home.is_pending(player), "O failed: on to the innkeeper")
finish(); ended("O failed", highcourt.arrival)
-- The whole home is gone on arrival (the character lost its faction).
claim_player()
check(respawn(), "O no home request")
data["grug_factions:faction"] = nil
finish()
check(not held(), "O no home on arrival: released")
emerge, after = {}, {}

-- ---------------------------------------------------------------------------
-- S: the session
-- ---------------------------------------------------------------------------
local function dies(label, leg)
 claim_player()
 if leg == "inn" then cells[key(BLOCK_CELL)] = "stone" end
 check(respawn(), label .. " request")
 local moved = #trail
 player.hp = 0
 for _, fn in ipairs(callbacks.die) do fn(player, {type="fall"}) end
 check(not held(), label .. " the death drops the hold")
 finish(); timeout()
 check(#trail == moved and not home.is_pending(player), label .. " nothing moves the dead player")
 emerge, after = {}, {}
end
dies("S dies at the claim", "claim")
dies("S dies at the innkeeper", "inn")
claim_player()
check(respawn(), "S leave request")
for _, fn in ipairs(callbacks.leave) do fn(player) end
online = false
finish(); timeout()
online = true
for _, fn in ipairs(home_joins) do fn(player) end
check(#trail == 1 and not held(), "S leaving ends the trip, the join clears the hold")
emerge, after = {}, {}
-- A return home is still refused while a respawn is under way, not merged.
claim_player()
check(respawn(), "S duplicate request")
check(not home.return_home(player), "S a second trip is refused")
finish(); ended("S duplicate", FEET)

-- ---------------------------------------------------------------------------
-- H: the hook's other branches
-- ---------------------------------------------------------------------------
reset(); new_player(); data["grug_factions:faction"] = nil
check(respawn() == nil and #trail == 0 and not held(), "H no faction: the engine's respawn, as before")
reset(); new_player()
grug_core.player_in_creation_stasis = function() return true end
check(respawn() == true and #trail == 0 and not held(), "H creation stasis: nothing moves")
grug_core.player_in_creation_stasis = nil

-- ---------------------------------------------------------------------------
-- R: a respawn row (Round 71, an Expedition's start waystone)
-- ---------------------------------------------------------------------------
local ROW_FEET = vnew(8000, 100.51, 8000)
local row_live = false
home.register_respawn_home(function()
 if row_live then return {id="expedition:1", pos=vnew(8000, 102, 8000), arrival=ROW_FEET} end
end)
reset(); new_player({["grug_home:id"]="highcourt"})
row_live = true
check(respawn() and same(player.pos, ROW_FEET) and held(), "R the respawn goes to the row, held")
finish()
ended("R row", ROW_FEET)
-- The row lapses during the emerge: the ordinary home takes over, still held.
reset(); new_player({["grug_home:id"]="highcourt"})
check(respawn() and same(player.pos, ROW_FEET), "R the row again")
row_live = false
finish()
check(same(player.pos, highcourt.arrival) and held(), "R a lapsed row follows the home")
finish()
ended("R lapsed", highcourt.arrival)
-- A return home never asks the row.
reset(); new_player({["grug_home:id"]="highcourt"})
row_live = true
check(home.return_home(player), "R return request")
finish()
check(same(player.pos, highcourt.arrival), "R return home ignores the row")
row_live = false

-- ---------------------------------------------------------------------------
-- G: the real grug_expeditions/guard.lua on this path: a death in a box whose run
-- is gone ends in the capital the player came from, also through the look on
-- arrival, which no longer stands in a box (ruling 7 of Round 71)
-- ---------------------------------------------------------------------------
local BOX = vnew(9000, 300, 9000)
local guard_die = #callbacks.die + 1
local guard_leave = #callbacks.leave + 1
local live_run
vector.add = function(a, n) return vnew(a.x + n, a.y + n, a.z + n) end
vector.subtract = function(a, n) return vnew(a.x - n, a.y - n, a.z - n) end
rawset(_G, "grug_expeditions", {
 catalogue={SLOTS=100},
 slot_box=function() return BOX, BOX end,
 slot_at=function(pos) return pos.x >= 8900 and 1 or nil end,
 run_at=function(pos) return pos.x >= 8900 and live_run or nil end,
 belongs=function() return true end,
 saved_origin=function(p)
  local origin = p:get_meta():get_string("grug_expeditions:origin")
  return origin ~= "" and origin or nil
 end,
})
grug_mobs.set_spawn_free_field = function() end
grug_mounts.register_summon_guard = function() end
grug_core.register_world_exception = function() end
-- Round 72 (MINT): guard.lua also holds the boxes' lava; tools/r72_mint tests it.
grug_core.register_lava_hold = function() end
dofile(repo .. "/mods/PLAYER/grug_expeditions/guard.lua")
local capital_feet = home.waystone_arrival("highcourt")
local function boxed(origin)
 reset(); new_player({["grug_home:id"]="dawnmere", ["grug_expeditions:origin"]=origin})
 player.pos = vnew(BOX)
end
boxed("highcourt")
check(respawn() and same(player.pos, capital_feet) and held(), "G the first look: the capital, held")
finish()
ended("G capital", capital_feet)
check(not same(capital_feet, dawnmere.arrival), "G the capital is not the home")
-- It answers only for that respawn: a forced one from elsewhere goes home.
player.pos = vnew(5000, 300, 5000)
check(respawn() and same(player.pos, dawnmere.arrival), "G the answer does not outlive its trip")
finish()
ended("G later", dawnmere.arrival)
-- A death or a leave between the looks forgets it.
for _, event in ipairs({{"die", guard_die}, {"leave", guard_leave}}) do
 boxed("highcourt")
 check(respawn() and same(player.pos, capital_feet), "G " .. event[1] .. " request")
 callbacks[event[1]][event[2]](player)
 finish()
 check(same(player.pos, dawnmere.arrival), "G " .. event[1] .. " between the looks: the home")
 finish()
 ended("G " .. event[1], dawnmere.arrival)
end
-- No saved capital: the ordinary home. A run of theirs: the start waystone, as ever.
boxed(nil)
check(respawn() and same(player.pos, dawnmere.arrival), "G nothing saved: the home")
finish()
ended("G no origin", dawnmere.arrival)
boxed("highcourt")
local ROW_START = vnew(9001, 300.51, 9001)
live_run = {id=1, entered={tester=true}, places={arrival=vnew(9001, 301, 9001)}}
grug_expeditions.start_arrival = function() return ROW_START end
check(respawn() and same(player.pos, ROW_START) and held(), "G in a live run: the start waystone")
live_run = nil

if #failures > 0 then
 for _, label in ipairs(failures) do print("FAIL " .. label) end
 error(("R69 HOME FAIL %d/%d"):format(#failures, checks), 0)
end
print("R69 HOME PASS checks=" .. checks)
