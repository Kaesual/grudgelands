-- Round 72 lane TAGS: friend and foe nametags (round72-plan.md §2.8, §4
-- TAGS, §6). Loads the REAL grug_core/tag_carrier.lua under a small engine
-- stub and checks:
--   A  a guard and an NPC seen by a friend, a foe and both at once: the held
--      carrier serves its own side, a second carrier the other side, each
--      in its own colour (green/red, light green/light red), the text on
--      both, the HP bar and the visibility callbacks over both sides;
--   B  the foe carrier is made on approach and removed when the last foe
--      leaves (25/30 m hysteresis kept), and with the unit's removal;
--   C  a viewer without a faction sees the friend tag;
--   D  players of both sides see each other green or red; a player without
--      a faction stays white; the faction chosen later recolours;
--   E  a guard waits for its _grug_faction in its old colour; mobs without
--      a faction and capital displays keep their colours and get no second
--      carrier;
--   F  the carrier count with and without foes nearby (printed).
-- Usage (repo root): luajit tools/r72_tags/portable_test.lua [REPO]
local repo = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL " .. label) end
	return ok
end
local function eq(a, b, label)
	return check(a == b, label .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

------------------------------------------------------------------------------
-- Engine stub.
------------------------------------------------------------------------------
local registered, players, globalsteps, live = {}, {}, {}, {}
local function new_object(pos, entity)
	local o = {pos = pos, valid = true, entity = entity, props = {}}
	function o:is_valid() return self.valid end
	function o:get_pos() return self.valid and (self.parent and self.parent:get_pos() or self.pos) or nil end
	function o:get_properties() return self.props end
	function o:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function o:set_attach(parent) self.parent = parent end
	function o:get_attach() return self.parent end
	function o:get_luaentity() return self.entity end
	function o:is_player() return false end
	function o:set_observers(observers) self.observers = observers end
	function o:remove() self.valid = false; live[self] = nil end
	if entity then entity.object = o end
	return o
end
_G.core = {
	settings = {get = function() return nil end,
		get_bool = function(_, _, default) return default end},
	colorspec_to_colorstring = function(v) return v end,
	registered_entities = registered,
	register_entity = function(name, def) registered[name] = def end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	get_connected_players = function() return players end,
	add_entity = function(pos, name)
		local def = registered[name]
		local entity = setmetatable({name = name}, {__index = def})
		local o = new_object(pos, entity)
		live[o] = true
		if def.on_activate then def.on_activate(entity) end
		return o
	end,
}
_G.grug_core = {
	start_identities = function()
		return {{race_id = "human", faction_id = "accord"},
			{race_id = "orc", faction_id = "throng"}}
	end,
	settlement_socket_settlements = function()
		return {{key = "highcourt", race_id = "human"},
			{key = "gor_drazhak", race_id = "orc"}}
	end,
}
dofile(repo .. "/mods/CORE/grug_core/tag_carrier.lua")
-- grug_factions' one line: a player's faction from its meta.
grug_core.get_player_object_faction = function(player) return player.faction end

local CARRIER = "grug_core:tag_carrier"
local BAR = "grug_core:injured_hp_bar"
local visibility = {}
grug_core.register_tag_visibility(function(parent, observers, removed)
	local names = {}
	for name in pairs(observers) do names[#names + 1] = name end
	table.sort(names)
	visibility[#visibility + 1] = {parent = parent, names = table.concat(names, ","),
		removed = removed}
end)

local function player(name, faction, x)
	local p = {name = name, faction = faction, x = x or 0, y = 0, z = 0}
	function p:get_pos() return {x = self.x, y = self.y, z = self.z} end
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:is_valid() return true end
	function p:get_properties() return {} end
	function p:get_luaentity() return nil end
	return p
end
local function mob(fields, x)
	local entity = {health = 100, hp_max = 100}
	for k, v in pairs(fields) do entity[k] = v end
	local o = new_object({x = x or 0, y = 0, z = 0}, entity)
	live[o] = true
	return entity
end
local function pass()
	grug_core.refresh_tag_player_snapshot()
	grug_core.manage_tag_carriers()
end
local function children(parent)
	local list = {}
	for o in pairs(live) do
		if o.parent == parent.object and o.entity and o.entity.name == CARRIER then
			list[#list + 1] = o
		end
	end
	return list
end
local function names(set)
	local list = {}
	for name in pairs(set or {}) do list[#list + 1] = name end
	table.sort(list)
	return table.concat(list, ",")
end
local function carrier_count()
	local n = 0
	for o in pairs(live) do
		if o.entity and o.entity.name == CARRIER then n = n + 1 end
	end
	return n
end
local GREEN, RED = "#4bdc4b", "#ff4b4b"
local LIGHT_GREEN, LIGHT_RED = "#b9f5b0", "#ffb3b3"

------------------------------------------------------------------------------
-- A: a guard and an NPC seen by a friend, a foe and both at once.
------------------------------------------------------------------------------
local guard = mob({name = "grug_mobs:guard_accord", _grug_faction = "accord",
	health = 50}, 0)
local villager = mob({name = "grug_mobs:villager_human", _grug_start = "highcourt",
	passive = true}, 2)
local guard_tag = grug_core.create_tag_carrier(guard.object)
grug_core.set_tag_carrier_text(guard_tag, "Guard [Lv 40] 50/100")
local npc_tag = grug_core.create_tag_carrier(villager.object)
grug_core.set_tag_carrier_text(npc_tag, "Highcourt Farmer")
eq(guard_tag.props.nametag_color, GREEN, "A: a guard's held tag is green from its start")
eq(npc_tag.props.nametag_color, LIGHT_GREEN, "A: a villager's held tag is light green")

local friend = player("friend", "accord", 5)
local foe = player("foe", "throng", 200)
players[1], players[2] = friend, foe
pass()
eq(#children(guard), 1, "A: a friend alone: one carrier on the guard")
eq(names(guard_tag.observers), "friend", "A: the friend observes the held tag")
eq(#children(villager), 1, "A: a friend alone: one carrier on the villager")

foe.x = 4
pass()
local list = children(guard)
eq(#list, 2, "A: friend and foe: two carriers on the guard")
local guard_foe = list[1] == guard_tag and list[2] or list[1]
eq(names(guard_tag.observers), "friend", "A: both: the friend keeps the held tag")
eq(names(guard_foe.observers), "foe", "A: both: the foe sees only the second tag")
eq(guard_foe.props.nametag_color, RED, "A: the foe tag of a guard is red")
eq(guard_foe.props.nametag, "Guard [Lv 40] 50/100", "A: the foe tag carries the text")
list = children(villager)
local npc_foe = list[1] == npc_tag and list[2] or list[1]
eq(#list, 2, "A: friend and foe: two carriers on the villager")
eq(npc_foe.props.nametag_color, LIGHT_RED, "A: the foe tag of a villager is light red")
eq(names(npc_foe.observers), "foe", "A: the villager's foe tag: the foe only")

grug_core.set_tag_carrier_text(guard_tag, "Guard [Lv 40] 40/100")
eq(guard_foe.props.nametag, "Guard [Lv 40] 40/100", "A: a new text reaches the foe tag")
eq(guard_tag.props.nametag, "Guard [Lv 40] 40/100", "A: and the held tag")
eq(guard_tag.props.nametag_color, GREEN, "A: the held tag stays green after a text")

local bar
for o in pairs(live) do
	if o.entity and o.entity.name == BAR and o.parent == guard.object then bar = o end
end
check(bar ~= nil, "A: the injured guard has an HP bar")
eq(names(bar and bar.observers), "foe,friend", "A: the HP bar is seen by both sides")
local last
for _, call in ipairs(visibility) do
	if call.parent == villager.object and not call.removed then last = call end
end
eq(last and last.names, "foe,friend", "A: the visibility callback gets both sides")

-- The foe alone.
friend.x = 200
pass()
eq(names(guard_tag.observers), "", "A: the foe alone: nobody on the held tag")
eq(names(guard_foe.observers), "foe", "A: the foe alone: the foe tag stays")

------------------------------------------------------------------------------
-- B: made on approach, removed when the last foe leaves; hysteresis.
------------------------------------------------------------------------------
foe.x = 28
pass()
check(guard_foe:is_valid(), "B: a foe at 28 m keeps the foe tag (hysteresis)")
foe.x = 31
pass()
check(not guard_foe:is_valid(), "B: a foe beyond 30 m: the foe tag is removed")
eq(#children(guard), 1, "B: one carrier left on the guard")
visibility = {}
pass()
local reported = 0
for _, call in ipairs(visibility) do if call.parent == guard.object then reported = reported + 1 end end
eq(reported, 0, "B: nothing reported while nobody observes the guard")
foe.x = 27
pass()
eq(#children(guard), 1, "B: a foe at 27 m coming back is not shown (enters at 25)")
foe.x = 24
pass()
eq(#children(guard), 2, "B: a foe at 24 m: the foe tag is made again")
-- The unit's removal takes both carriers.
local tags = children(guard)
grug_core.remove_tag_carrier(guard_tag)
check(not tags[1]:is_valid() and not tags[2]:is_valid(), "B: removing the unit's tag removes both carriers")
grug_core.remove_tag_carrier(npc_tag)
eq(#children(villager), 0, "B: removing the villager's tag removes both carriers")

------------------------------------------------------------------------------
-- C: a viewer without a faction sees green.
------------------------------------------------------------------------------
players[1], players[2] = player("newcomer", nil, 3), nil
local guard2 = mob({name = "grug_mobs:guard_throng", _grug_faction = "throng"}, 0)
local tag2 = grug_core.create_tag_carrier(guard2.object)
grug_core.set_tag_carrier_text(tag2, "Throng Guard")
pass()
eq(#children(guard2), 1, "C: a factionless viewer makes no foe tag")
eq(names(tag2.observers), "newcomer", "C: a factionless viewer sees the held tag")
eq(tag2.props.nametag_color, GREEN, "C: and it is green")
grug_core.remove_tag_carrier(tag2)

------------------------------------------------------------------------------
-- D: players of both sides; a factionless player; a faction chosen later.
------------------------------------------------------------------------------
local anna = player("anna", "accord", 0)
local borg = player("borg", "throng", 3)
local cara = player("cara", "accord", 6)
local dirk = player("dirk", nil, 9)
players[1], players[2], players[3], players[4] = anna, borg, cara, dirk
local anna_tag = grug_core.create_tag_carrier(anna, "anna")
grug_core.set_tag_carrier_text(anna_tag, "anna [Lv 30]")
local dirk_tag = grug_core.create_tag_carrier(dirk, "dirk")
grug_core.set_tag_carrier_text(dirk_tag, "dirk [Lv 1]")
pass()
eq(names(anna_tag.observers), "cara,dirk", "D: Accord and factionless see Anna's held tag")
eq(anna_tag.props.nametag_color, GREEN, "D: Anna's held tag is green")
local anna_foe
for o in pairs(live) do
	if o.parent == anna and o ~= anna_tag and o.entity.name == CARRIER then anna_foe = o end
end
eq(names(anna_foe and anna_foe.observers), "borg", "D: Borg sees Anna's foe tag")
eq(anna_foe and anna_foe.props.nametag_color, RED, "D: and it is red")
check(anna_tag.observers.anna == nil and (anna_foe and anna_foe.observers.anna == nil),
	"D: a player never observes their own tag")
eq(dirk_tag.props.nametag_color, "#ffffff", "D: a player without a faction is white")
eq(names(dirk_tag.observers), "anna,borg,cara", "D: everyone sees the factionless player's one tag")
local bars = 0
for o in pairs(live) do if o.entity and o.entity.name == BAR then bars = bars + 1 end end
eq(bars, 0, "D: no HP bar on a player")
dirk.faction = "throng"
pass()
eq(dirk_tag.props.nametag_color, GREEN, "D: a faction chosen later recolours the held tag")
eq(names(dirk_tag.observers), "borg", "D: Dirk's own side sees the held tag")
local dirk_foe
for o in pairs(live) do
	if o.parent == dirk and o ~= dirk_tag and o.entity.name == CARRIER then dirk_foe = o end
end
eq(names(dirk_foe and dirk_foe.observers), "anna,cara", "D: the Accord sees Dirk's foe tag")
grug_core.remove_tag_carrier(anna_tag)
grug_core.remove_tag_carrier(dirk_tag)

------------------------------------------------------------------------------
-- E: a guard waiting for its faction; mobs without one; capital displays.
------------------------------------------------------------------------------
players[1], players[2], players[3], players[4] = player("acc", "accord", 1),
	player("thr", "throng", 2), nil, nil
local fresh = mob({name = "grug_mobs:guard_accord", _grug_start = "highcourt"}, 0)
local fresh_tag = grug_core.create_tag_carrier(fresh.object)
grug_core.set_tag_carrier_text(fresh_tag, "Guard")
eq(fresh_tag.props.nametag_color, "#b76cff", "E: a guard before its first tick keeps violet")
pass()
eq(#children(fresh), 1, "E: no foe tag before the faction is known")
eq(names(fresh_tag.observers), "acc,thr", "E: everyone sees the one violet tag meanwhile")
fresh._grug_faction = "accord"
pass()
eq(fresh_tag.props.nametag_color, GREEN, "E: once the faction is set the held tag turns green")
eq(#children(fresh), 2, "E: and the Throng viewer gets the foe tag")
eq(names(fresh_tag.observers), "acc", "E: the held tag keeps only its side")
grug_core.remove_tag_carrier(fresh_tag)

local wolf = mob({name = "grug_mobs:wolf", _grug_disposition = "aggressive"}, 0)
local wolf_tag = grug_core.create_tag_carrier(wolf.object)
grug_core.set_tag_carrier_text(wolf_tag, "Wolf")
local stag = mob({name = "grug_mobs:stag", _grug_disposition = "neutral"}, 0)
local stag_tag = grug_core.create_tag_carrier(stag.object)
grug_core.set_tag_carrier_text(stag_tag, "Stag")
local sentinel = mob({name = "grug_mobs:land_guard"}, 0)
local sentinel_tag = grug_core.create_tag_carrier(sentinel.object)
grug_core.set_tag_carrier_text(sentinel_tag, "Bedrock Sentinel")
local display = mob({name = "grug_mobs:capital_display", _grug_start = "highcourt",
	_grug_capital_display = true}, 0)
local display_tag = grug_core.create_tag_carrier(display.object)
grug_core.set_tag_carrier_text(display_tag, "Warhorse")
pass()
eq(wolf_tag.props.nametag_color, RED, "E: an aggressive mob stays red")
eq(stag_tag.props.nametag_color, "#ffd447", "E: a neutral mob stays yellow")
eq(sentinel_tag.props.nametag_color, "#b76cff", "E: the factionless Bedrock Sentinel keeps violet")
eq(display_tag.props.nametag_color, "#d8c5ff", "E: a capital display keeps lavender")
for _, unit in ipairs({wolf, stag, sentinel, display}) do
	eq(#children(unit), 1, "E: " .. unit.name .. " has one carrier with both sides near")
end
-- A king (aggressive by disposition) with a faction is a faction unit.
local king = mob({name = "grug_mobs:king_human", _grug_disposition = "aggressive",
	_grug_faction = "accord", health = 90}, 0)
local king_tag = grug_core.create_tag_carrier(king.object)
grug_core.set_tag_carrier_text(king_tag, "King")
pass()
eq(king_tag.props.nametag_color, GREEN, "E: a King is green for his side")
eq(#children(king), 2, "E: and has a foe tag for the other")
for _, t in ipairs({wolf_tag, stag_tag, sentinel_tag, display_tag, king_tag}) do
	grug_core.remove_tag_carrier(t)
end

------------------------------------------------------------------------------
-- F: carrier count with and without foes nearby (a capital square).
------------------------------------------------------------------------------
do
	local held = {}
	for i = 1, 30 do
		local unit = i <= 10 and mob({name = "grug_mobs:guard_accord",
			_grug_faction = "accord"}, i * 2) or mob({name = "grug_mobs:villager_human",
			_grug_start = "highcourt"}, i * 2)
		held[i] = grug_core.create_tag_carrier(unit.object)
	end
	players[1], players[2] = player("local", "accord", 0), nil
	pass()
	local without = carrier_count()
	players[2] = player("raider", "throng", 0)
	pass()
	local with = carrier_count()
	players[2].x = -100
	pass()
	local after = carrier_count()
	print(("F: 30 units: %d carriers without a foe, %d with a foe at the square's edge, %d after the foe left")
		:format(without, with, after))
	eq(without, 30, "F: no foe near: one carrier per unit")
	eq(with, 30 + 12, "F: a foe at x = 0: a second carrier for the 12 units within 25 m")
	eq(after, 30, "F: the foe gone: back to one per unit")
	for i = 1, 30 do grug_core.remove_tag_carrier(held[i]) end
end

print(("r72_tags: %d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
