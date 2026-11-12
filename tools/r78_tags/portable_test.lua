-- Round 78 lane TAGS: nametags that never go missing (round78-plan.md
-- ruling 7, §4 TAGS). Loads the REAL grug_core/tag_carrier.lua, the REAL
-- grug_factions/init.lua and the REAL grug_mounts catalog/flight/entity
-- under a small engine stub and checks:
--   A  a player's carrier that is gone (the engine dropped it), invalid or
--      detached is rebuilt by refresh_player_tag even when the text is
--      unchanged, on the player, with the text it had, one carrier only;
--   B  the observer pass rebuilds a lost player carrier by itself and gives
--      it its viewers on the same pass (no refresh needed);
--   C  while the player stands where no map block is loaded (the character
--      waiting point at y = 31000) nothing is made; a text set meanwhile is
--      kept, and the pass rebuilds with it once the player is back on loaded
--      ground;
--   D  the re-ensure hooks: a grug_home teleport (waystones, return home,
--      respawn arrivals), a respawn, mounting and dismounting each rebuild a
--      lost carrier at once; a mounted player's carrier stays on the player
--      (carrier -> player -> mount) and a carrier lost while riding is
--      rebuilt on the player, not on the mount;
--   E  the foe twin: still made and served after the held carrier was
--      rebuilt; a lost or detached twin is made again by the pass;
--   F  the per-viewer add path the engine needs (serveractiveobject.cpp
--      getEffectiveObservers, player_sao.cpp getClientInitializationData,
--      clientenvironment.cpp addActiveObject): every rebuilt carrier is
--      attached to its parent before any viewer is put in its observer set,
--      and the parent player keeps no observer set of its own;
--   G  a leave removes the CURRENT carrier (a replacement included); a mob's
--      lost carrier is still forgotten, not rebuilt (players only).
-- Usage (repo root): luajit tools/r78_tags/portable_test.lua [REPO]
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
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end}

local CARRIER = "grug_core:tag_carrier"
local registered, live, events = {}, {}, {}
local connected, by_name = {}, {}
local callbacks = {join = {}, leave = {}, respawn = {}, hp = {}, mods_loaded = {}}
local serial = {}
-- No block is in memory above y = 30000 (the waiting point lies there).
local function loaded(pos) return pos.y < 30000 end

local function new_object(pos, name, staticdata)
	local def = registered[name]
	local o = {pos = copy(pos), valid = true, props = {}}
	local entity = def and setmetatable({object = o, name = name}, {__index = def})
	function o:is_valid() return self.valid end
	function o:get_pos()
		if not self.valid then return nil end
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function o:set_pos(p) self.pos = copy(p) end
	function o:get_properties() return self.props end
	function o:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function o:set_attach(parent)
		self.parent = parent
		events[#events + 1] = {kind = "attach", object = self}
	end
	function o:set_detach() self.parent = nil end
	function o:get_attach() return self.parent end
	function o:get_luaentity() return self.valid and entity or nil end
	function o:is_player() return false end
	function o:set_observers(observers)
		self.observers = observers
		events[#events + 1] = {kind = "observers", object = self, any = next(observers) ~= nil}
	end
	function o:set_armor_groups() end
	function o:set_velocity() end
	function o:set_acceleration() end
	function o:get_velocity() return {x = 0, y = 0, z = 0} end
	function o:set_yaw() end
	function o:get_yaw() return 0 end
	function o:set_animation() end
	function o:remove() self.valid = false; live[self] = nil end
	live[o] = true
	if entity and entity.on_activate then entity.on_activate(entity, staticdata, 0) end
	if not o.valid then return nil end
	return o
end

local function register(list) return function(fn) table.insert(callbacks[list], fn) end end
local noop = function() end
_G.core = {
	settings = {get = function() return nil end,
		get_bool = function(_, _, default) return default end},
	colorspec_to_colorstring = function(v) return v end,
	registered_entities = registered,
	registered_nodes = {air = {walkable = false, liquidtype = "none"},
		floor = {walkable = true, liquidtype = "none"}},
	get_item_group = function() return 0 end,
	register_entity = function(name, def) registered[name] = def end,
	register_globalstep = noop,
	get_connected_players = function() return connected end,
	get_player_by_name = function(name) return by_name[name] end,
	add_entity = function(pos, name, staticdata) return new_object(pos, name, staticdata) end,
	get_node_or_nil = function(pos)
		if not loaded(pos) then return nil end
		return {name = pos.y < 0 and "floor" or "air"}
	end,
	get_modpath = function(mod)
		local paths = {grug_factions = "/mods/PLAYER/grug_factions",
			grug_mounts = "/mods/PLAYER/grug_mounts"}
		return repo .. paths[mod]
	end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	get_us_time = function() return 0 end,
	after = noop,
	chat_send_player = noop,
	register_on_joinplayer = register("join"),
	register_on_leaveplayer = register("leave"),
	register_on_respawnplayer = register("respawn"),
	register_on_player_hpchange = register("hp"),
	register_on_mods_loaded = register("mods_loaded"),
	register_on_dieplayer = noop,
	register_on_punchplayer = noop,
	register_on_shutdown = noop,
	register_chatcommand = noop,
	get_player_window_information = function() return nil end,
}

_G.grug_core = {
	factions = {accord = {name = "Accord"}, throng = {name = "Throng"}},
	zone_authority_installed = function() return true end,
	start_identities = function()
		return {{race_id = "human", faction_id = "accord"},
			{race_id = "orc", faction_id = "throng"}}
	end,
	settlement_socket_settlements = function() return {} end,
	set_status = noop, clear_status = noop,
	is_max_hp_clamp = function() return false end,
	in_combat = function() return false end,
	feed = function() return true end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	FLIGHT_CEILING = 600,
	depth_below_surface = function(pos) return -0.5 - pos.y end,
}
dofile(repo .. "/mods/CORE/grug_core/tag_carrier.lua")
dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")

-- The rest of the mount mod's surface (as tools/r72_mounts).
player_api = {player_attached = {}, set_animation = noop,
	get_animation = function() return {animation = "stand"} end}
grug_sounds = {play = function() return false end, stop = function() return false end}
grug_zones = {water_class_at = function() return "land" end, id_at = function() return "home" end,
	get = function() return {territory_rule = "contested_land"} end,
	terrain_height_at = function() return -10 end,
	hard_footprint_in = function() return nil end}
grug_classes = {get_race = function(player) return player.race end,
	register_on_race_chosen = noop}
grug_mounts = {}
dofile(repo .. "/mods/PLAYER/grug_mounts/catalog.lua")
dofile(repo .. "/mods/PLAYER/grug_mounts/flight.lua")
dofile(repo .. "/mods/PLAYER/grug_mounts/entity.lua")

-- grug_home's teleport registry (the real one lives in grug_home/travel.lua).
local teleport_callbacks = {}
grug_home = {register_on_teleport = function(fn) teleport_callbacks[#teleport_callbacks + 1] = fn end,
	respawn = function() return true end}
for _, fn in ipairs(callbacks.mods_loaded) do fn() end
eq(#teleport_callbacks, 1, "D: grug_factions registers one grug_home teleport hook")

local function make_player(name, faction, x)
	local meta = {["grug_factions:faction"] = faction}
	local p = {name = name, pos = {x = x or 0, y = 0, z = 0}, hp = 20, race = "human"}
	function p:is_player() return true end
	function p:is_valid() return not self.gone end
	function p:get_player_name() return self.name end
	function p:get_pos()
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function p:set_pos(pos) self.pos = copy(pos) end
	function p:get_hp() return self.hp end
	function p:get_properties() return {hp_max = 20, visual_size = {x = 1, y = 1}} end
	function p:set_properties() end
	function p:get_luaentity() return nil end
	function p:get_meta()
		return {get_string = function(_, key) return meta[key] or "" end,
			set_string = function(_, key, value) meta[key] = value end,
			get_int = function(_, key) return tonumber(meta[key]) or 0 end,
			set_int = function(_, key, value) meta[key] = value end}
	end
	function p:set_nametag_attributes(attributes) self.nametag = attributes end
	function p:set_attach(parent) self.parent = parent end
	function p:set_detach() self.parent = nil end
	function p:get_attach() return self.parent end
	function p:set_eye_offset() end
	function p:set_camera() end
	function p:get_look_horizontal() return 0 end
	function p:get_player_control() return {} end
	function p:hud_remove() end
	-- A player has no observer set (unmanaged, F).
	function p:set_observers() self.managed = true end
	connected[#connected + 1] = p
	by_name[name] = p
	return p
end
local function join(p) for _, fn in ipairs(callbacks.join) do fn(p) end end
local function leave(p)
	for _, fn in ipairs(callbacks.leave) do fn(p, false) end
	p.gone = true
	for i = #connected, 1, -1 do if connected[i] == p then table.remove(connected, i) end end
	by_name[p.name] = nil
end
local function pass()
	grug_core.refresh_tag_player_snapshot()
	grug_core.manage_tag_carriers()
end
local function carriers_on(parent)
	local list = {}
	for o in pairs(live) do
		if o.valid and o.parent == parent and o:get_luaentity() and
				o:get_luaentity().name == CARRIER then
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
-- The one held carrier of a player (the twin is the one with foe observers).
local function held(p, foe_names)
	for _, o in ipairs(carriers_on(p)) do
		if names(o.observers) ~= foe_names then return o end
	end
end
-- The engine dropping a non-static entity (deactivateFarObjects).
local function drop(o) o.valid = false; live[o] = nil end
local function attach_before_viewers(o)
	local attached = false
	for _, event in ipairs(events) do
		if event.object == o then
			if event.kind == "attach" then attached = true end
			if event.kind == "observers" and event.any and not attached then return false end
		end
	end
	return attached
end

------------------------------------------------------------------------------
-- A: gone, invalid and detached carriers rebuilt by an unchanged refresh.
------------------------------------------------------------------------------
local anna = make_player("anna", "accord", 0)
local cara = make_player("cara", "accord", 5)
join(anna); join(cara)
pass()
local first = carriers_on(anna)[1]
eq(#carriers_on(anna), 1, "A: Anna has one carrier after joining")
eq(first and first.props.nametag, "anna [Lv 1] 20/20", "A: it carries her text")
eq(names(first and first.observers), "cara", "A: Cara observes it")

drop(first)
eq(grug_factions.refresh_player_tag(anna), false, "A: the text is unchanged")
local second = carriers_on(anna)[1]
eq(#carriers_on(anna), 1, "A: a dropped carrier is rebuilt by the unchanged refresh")
check(second and second ~= first, "A: a new entity")
eq(second and second.props.nametag, "anna [Lv 1] 20/20", "A: with the text it had")

second.parent = nil -- detached
grug_factions.refresh_player_tag(anna)
local third = carriers_on(anna)[1]
eq(#carriers_on(anna), 1, "A: a detached carrier is replaced")
check(not second.valid, "A: the detached one is removed")
eq(third and third.props.nametag, "anna [Lv 1] 20/20", "A: the replacement has the text")

-- hpchange runs before the change (hp + change is the new value).
for _, fn in ipairs(callbacks.hp) do fn(anna, -5) end
anna.hp = 15
eq(third.props.nametag, "anna [Lv 1] 15/20", "A: a changed text still reaches the live carrier")
eq(#carriers_on(anna), 1, "A: still one carrier")

------------------------------------------------------------------------------
-- B: the pass rebuilds by itself and gives the viewers at once.
------------------------------------------------------------------------------
pass()
drop(third)
pass()
local fourth = carriers_on(anna)[1]
eq(#carriers_on(anna), 1, "B: the pass rebuilt the lost carrier")
eq(names(fourth and fourth.observers), "cara", "B: Cara observes the replacement on the same pass")
eq(fourth and fourth.props.nametag, "anna [Lv 1] 15/20", "B: with the latest text")
check(attach_before_viewers(fourth), "F: attached before its first viewer")
pass()
eq(#carriers_on(anna), 1, "B: a second pass makes nothing more")

------------------------------------------------------------------------------
-- C: the waiting point: nothing is made there, the text is kept.
------------------------------------------------------------------------------
anna.pos = {x = 0, y = 31000, z = 0}
drop(fourth)
pass()
eq(#carriers_on(anna), 0, "C: no carrier where no block is loaded")
for _, fn in ipairs(callbacks.hp) do fn(anna, 5) end
anna.hp = 20
eq(#carriers_on(anna), 0, "C: a refresh at the waiting point makes none either")
pass()
eq(#carriers_on(anna), 0, "C: nor the next pass")
anna.pos = {x = 0, y = 0, z = 0}
pass()
local fifth = carriers_on(anna)[1]
eq(#carriers_on(anna), 1, "C: back on loaded ground: the pass rebuilds")
eq(fifth and fifth.props.nametag, "anna [Lv 1] 20/20", "C: with the text set while waiting")
eq(names(fifth and fifth.observers), "cara", "C: and Cara sees it")

------------------------------------------------------------------------------
-- D: the hooks.
------------------------------------------------------------------------------
local function lost_then(label, action)
	for _, o in ipairs(carriers_on(anna)) do drop(o) end
	action()
	local list = carriers_on(anna)
	eq(#list, 1, "D: " .. label .. " rebuilds the lost carrier at once")
	eq(list[1] and list[1].props.nametag, "anna [Lv 1] 20/20", "D: " .. label .. ": the text")
	return list[1]
end
lost_then("a grug_home teleport", function()
	anna.pos = {x = 400, y = 0, z = 0}
	for _, fn in ipairs(teleport_callbacks) do fn(anna) end
end)
lost_then("a respawn", function()
	for _, fn in ipairs(callbacks.respawn) do fn(anna) end
end)
anna.pos = {x = 0, y = 0, z = 0}
local riding = lost_then("mounting", function()
	assert(grug_mounts.spawn_entity(anna, 1, anna:get_pos()))
end)
local mount = anna:get_attach()
check(mount ~= nil and mount ~= anna, "D: Anna rides (attached to the mount)")
eq(riding and riding:get_attach(), anna, "D: the carrier hangs on the player, not the mount")
pass()
eq(#carriers_on(anna), 1, "D: riding: the pass keeps the one carrier")
eq(names(carriers_on(anna)[1].observers), "cara", "D: riding: Cara sees it")
drop(carriers_on(anna)[1])
pass()
local rebuilt = carriers_on(anna)[1]
eq(rebuilt and rebuilt:get_attach(), anna, "D: lost while riding: rebuilt on the player")
eq(#carriers_on(mount), 0, "D: and never on the mount")
lost_then("dismounting", function() grug_mounts.dismount(anna, "manual", false) end)
check(anna:get_attach() == nil, "D: Anna is on foot")

------------------------------------------------------------------------------
-- E: the foe twin.
------------------------------------------------------------------------------
local borg = make_player("borg", "throng", 3)
join(borg)
pass()
eq(#carriers_on(anna), 2, "E: a foe near: Anna has the held carrier and the twin")
local own = held(anna, "borg")
eq(names(own and own.observers), "cara", "E: the held carrier serves Cara")
drop(own)
pass()
local list = carriers_on(anna)
eq(#list, 2, "E: the held carrier rebuilt, the twin kept")
local twin
for _, o in ipairs(list) do if names(o.observers) == "borg" then twin = o end end
check(twin ~= nil, "E: Borg still sees the twin")
eq(twin and twin.props.nametag_color, "#ff4b4b", "E: the twin is red")
eq(names(held(anna, "borg") and held(anna, "borg").observers), "cara", "E: Cara sees the new held carrier")
drop(twin)
pass()
twin = nil
for _, o in ipairs(carriers_on(anna)) do if names(o.observers) == "borg" then twin = o end end
check(twin ~= nil, "E: a lost twin is made again by the pass")
eq(twin and twin.props.nametag, "anna [Lv 1] 20/20", "E: with the text")
twin.parent = nil
pass()
local twins = 0
for _, o in ipairs(carriers_on(anna)) do if names(o.observers) == "borg" then twins = twins + 1 end end
eq(twins, 1, "E: a detached twin is replaced by one on the player")
check(not twin.valid, "E: the detached twin is removed")

------------------------------------------------------------------------------
-- F: the parent player keeps no observer set of its own.
------------------------------------------------------------------------------
check(not anna.managed and not borg.managed and not cara.managed,
	"F: no player is given an observer set (its children keep their own)")

------------------------------------------------------------------------------
-- G: a leave removes the current carrier; a mob's is forgotten.
------------------------------------------------------------------------------
local before = carriers_on(anna)[1]
drop(held(anna, "borg"))
pass()
check(held(anna, "borg") ~= before, "G: replaced before the leave")
leave(anna)
eq(#carriers_on(anna), 0, "G: the leave removed the replacement and the twin")
pass()
eq(#carriers_on(anna), 0, "G: nothing comes back after the leave")

local wolf_entity = {name = "grug_mobs:wolf", _grug_disposition = "aggressive", health = 10, hp_max = 10}
local wolf = new_object({x = 2, y = 0, z = 0})
function wolf:get_luaentity() return wolf_entity end
wolf_entity.object = wolf
local wolf_tag = grug_core.create_tag_carrier(wolf)
grug_core.set_tag_carrier_text(wolf_tag, "Wolf")
pass()
drop(wolf_tag)
pass()
eq(#carriers_on(wolf), 0, "G: a mob's lost carrier is not rebuilt by the pass")
local again = grug_core.create_tag_carrier(wolf)
check(again and again.valid and again ~= wolf_tag, "G: the mob's next ensure makes a new one")

print(("r78_tags: %d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
