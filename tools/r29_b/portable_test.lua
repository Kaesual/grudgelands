-- Round 29 Lane B portable test (LuaJIT): boats as water mounts and the
-- Kraken retune. Loads the REAL grug_mounts files (catalog, state, entity,
-- items, trainer, shipwright) and grug_mobs/kraken.lua under a minimal `core`
-- stub with a small node world:
--   A. summon rules: feet in water (source and river flowing), the surface
--      and its centring, out of water, too deep, closed surface, combat, dead;
--   B. the water-surface controller: floating, rising, falling, glide limit;
--   C. water contact (ruling 8): removal within the one-second check;
--   D. the eject seams: HP-change observer and entity on_punch, both leaving
--      the rider in the water; disembark onto land within 2 nodes, else water;
--   E. one mount or boat: replacement of a horse, refusal keeps the horse;
--   F. purchase gating: Shipwright rows, own faction, levels, Learn Boat
--      first, purchase at the shipped price, the owned ids the quickbar
--      lists; the retired boat item;
--   G. Kraken speed switch: 10 in deep ocean, 5 elsewhere, leash, view range,
--      and the switch writing the speed base while a slow runs;
--   H. riding tiers 1-4 bought in order through the Riding Trainer dialogue
--      at the shipped prices (grug_mounts.PRICES, which
--      `python3 tools/r29_e4/income.py --check` ties to the income estimate):
--      level gate, preceding tier, one copper short, the exact price taken
--      (Round 30 lane C).
--
--   luajit tools/r29_b/portable_test.lua [REPO]
-- Prints "R29 B PORTABLE PASS checks=<n>" or the failures.

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
}
function ItemStack(name) return {name = name or ""} end

local world = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set_node(x, y, z, name) world[key(x, y, z)] = name end
local function node_at(pos)
	local x, y, z = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	return world[key(x, y, z)] or (y <= -40 and "default:dirt" or "air")
end

local serial, entities, chat, shown = {}, {}, {}, {}
local callbacks = {hp = {}, die = {}, leave = {}, join = {}, shutdown = {}, fields = {}}
local registered_entities, registered_items = {}, {}

core = {
	registered_nodes = {
		air = {walkable = false, liquidtype = "none"},
		["default:dirt"] = {walkable = true, liquidtype = "none"},
		["default:ice"] = {walkable = true, liquidtype = "none"},
		["default:water_source"] = {walkable = false, liquidtype = "source", groups = {water = 3}},
		["default:river_water_flowing"] = {walkable = false, liquidtype = "flowing", groups = {water = 3}},
	},
	registered_items = registered_items,
	registered_entities = registered_entities,
	get_item_group = function(name, group)
		local def = core.registered_nodes[name] or registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_node_or_nil = function(pos) return {name = node_at(pos)} end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_craftitem = function(name, def) registered_items[name] = def end,
	register_on_player_hpchange = function(fn) callbacks.hp[#callbacks.hp + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_shutdown = function(fn) callbacks.shutdown[#callbacks.shutdown + 1] = fn end,
	register_on_player_receive_fields = function(fn) callbacks.fields[#callbacks.fields + 1] = fn end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name = name, text = text} end,
	show_formspec = function(name, formname, fs) shown[#shown + 1] = {name = name, formname = formname, fs = fs} end,
	formspec_escape = function(text) return (tostring(text):gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text .. "(c@#ffffff)" end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_window_information = function() return nil end,
	after = function() end,
	log = function() end,
}

local players = {}
core.get_player_by_name = function(name) return players[name] end

-- Entity ObjectRefs.
local function new_object(pos, name, staticdata)
	local def = registered_entities[name]
	local object = {pos = copy(pos), velocity = {x = 0, y = 0, z = 0},
		acceleration = {x = 0, y = 0, z = 0}, valid = true, props = {}}
	local entity = setmetatable({object = object, name = name}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:set_pos(p) self.pos = copy(p) end
	function object:get_velocity() return copy(self.velocity) end
	function object:set_velocity(v) self.velocity = copy(v) end
	function object:add_velocity(v)
		self.velocity = {x = self.velocity.x + v.x, y = self.velocity.y + v.y, z = self.velocity.z + v.z}
	end
	function object:set_acceleration(a) self.acceleration = copy(a) end
	function object:set_yaw(y) self.yaw = y end
	function object:get_yaw() return self.yaw or 0 end
	function object:is_valid() return self.valid end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:set_armor_groups(g) self.armor = g end
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:get_properties() return self.props end
	function object:set_attach(parent) self.parent = parent end
	function object:get_attach() return self.parent end
	function object:set_animation() end
	if entity.on_activate then entity.on_activate(entity, staticdata, 0) end
	if not object.valid then return nil end
	entities[#entities + 1] = entity
	return object
end
core.add_entity = function(pos, name, staticdata) return new_object(pos, name, staticdata) end

local function make_player(name, faction, race)
	local player = {name = name, pos = {x = 0, y = 0, z = 0}, hp = 20, meta = {},
		control = {}, look = 0, faction = faction, race = race, punched = 0}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_pos()
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function player:set_pos(p) self.pos = copy(p) end
	function player:get_hp() return self.hp end
	function player:set_attach(parent) self.parent = parent end
	function player:set_detach() self.parent = nil end
	function player:get_attach() return self.parent end
	function player:set_eye_offset() end
	function player:set_properties() end
	function player:get_properties() return {visual_size = {x = 1, y = 1}} end
	function player:get_look_horizontal() return self.look end
	function player:get_player_control() return self.control end
	function player:hud_remove() end
	function player:get_meta()
		local meta = self.meta
		return {
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = v end,
			get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end,
		}
	end
	-- PlayerRef:punch -> HP change -> the observers, like the engine.
	function player:punch()
		self.punched = self.punched + 1
		for _, fn in ipairs(callbacks.hp) do fn(self, -5) end
		self.hp = self.hp - 5
		return 0
	end
	players[name] = player
	return player
end

player_api = {player_attached = {}, set_animation = function() end}
local combat = {}
local statuses = {}
local feed_lines = {}
grug_core = {
	FLIGHT_CEILING = 600,
	-- Mirrors grug_core.is_max_hp_clamp (environment_damage.lua; tools/r37_cb).
	is_max_hp_clamp = function(reason)
		return reason ~= nil and reason.type == "set_hp" and reason.from == "engine"
	end,
	FLASH_COLOR = {error = 1, notice = 2},
	in_combat = function(player) return combat[player:get_player_name()] == true end,
	set_status = function(player, id, def) statuses[player:get_player_name()] = def end,
	clear_status = function(player) statuses[player:get_player_name()] = nil end,
	flash = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	-- Mount notices go to the message feed (Round 32 F3); recorded like chat.
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind,
			text = text, key = key}
		return true
	end,
}
local water_class = "deep_ocean"
grug_zones = {
	water_class_at = function() return water_class end,
	at = function() return {id = "z", territory_rule = "accord_home"} end,
	terrain_height_at = function() return 0 end,
}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end,
}
grug_classes = {
	get_race = function(player) return player.race end,
	register_on_race_chosen = function() end,
}
local level = 1
grug_xp = {get_level = function() return level end}
local money = 0
grug_money = {
	take = function(_, amount) if money < amount then return false end money = money - amount return true end,
	format = function(c) return c .. " copper" end,
}
grug_inventory = {BAG_COUNT = 0, equipment_slots = {}, content_list = function(i) return "bag" .. i end}
local roles = {}
grug_mobs = {register_start_socket_role = function(role, fn) roles[role] = fn end}
local sockets = {}
grug_core.settlement_sockets_at = function(key) return sockets[key] or {} end

local function load(path) dofile(ROOT .. "/" .. path) end
grug_mounts = {}
load("mods/PLAYER/grug_mounts/catalog.lua")
load("mods/PLAYER/grug_mounts/state.lua")
load("mods/PLAYER/grug_mounts/entity.lua")
load("mods/PLAYER/grug_mounts/items.lua")
load("mods/PLAYER/grug_mounts/trainer.lua")
load("mods/PLAYER/grug_mounts/shipwright.lua")

local CONTROLLER = registered_entities["grug_mounts:mount"]

local function step(entity, dtime)
	-- The engine moves the object, then calls on_step.
	local o = entity.object
	o.pos = {x = o.pos.x + o.velocity.x * dtime, y = o.pos.y + o.velocity.y * dtime,
		z = o.pos.z + o.velocity.z * dtime}
	CONTROLLER.on_step(entity, dtime)
end
local function controller_of(player)
	local record = grug_mounts.active[player:get_player_name()]
	return record and record.object:get_luaentity()
end
local function last_chat() return chat[#chat] and chat[#chat].text end
local function last_feed() return feed_lines[#feed_lines] and feed_lines[#feed_lines].text end
local function clear_world() for k in pairs(world) do world[k] = nil end end
-- A pond: water at y = -3..0 over x, z in [-3, 3], dirt banks at y = 0 around
-- it and dirt below; the surface node is y = 0, its top y = 0.5.
local function pond()
	clear_world()
	for x = -6, 6 do
		for z = -6, 6 do
			for y = -10, -4 do set_node(x, y, z, "default:dirt") end
			local inside = math.abs(x) <= 3 and math.abs(z) <= 3
			for y = -3, 0 do set_node(x, y, z, inside and "default:water_source" or "default:dirt") end
		end
	end
end

------------------------------------------------------------------------------
-- A. Summon rules.
------------------------------------------------------------------------------
local ada = make_player("ada", "accord", "human")
ada.meta["grug_mounts:water_tier"] = 6
ada.meta["grug_mounts:land_tier"] = 1
eq(grug_mounts.TIERS[5].mode, "water", "tier 5 is a water mount")
eq(grug_mounts.TIERS[5].speed, 4, "base boat 4 nodes/s")
eq(grug_mounts.TIERS[6].speed, 8, "improved boat 8 nodes/s")
eq(grug_mounts.TIERS[5].level, 15, "base boat from level 15")
eq(grug_mounts.TIERS[6].level, 30, "improved boat from level 30")
local boat_item = registered_items["grug_mounts:boat"]
check(boat_item and boat_item.stack_max == 1 and boat_item.groups.grug_bound_skill == 1 and
	boat_item._grug_mount_tier == 5, "boat item: bound skill, one per stack")
eq(boat_item.on_drop().name, "", "dropping deletes the boat item")
-- Round 44: the item is retired (the quickbar summons from the purchase
-- record), so it has no use of its own; it stays registered for old stacks.
check(boat_item.on_use == nil and boat_item.on_secondary_use == nil and
	boat_item.on_place == nil, "the retired boat item does nothing when used")
check(registered_items["grug_mounts:improved_boat"].inventory_image ==
	"grug_mounts_icon_improved_boat.png", "improved boat icon name")

pond()
ada.pos = {x = 2.3, y = -40, z = 0}
local ok, message = grug_mounts.mount(ada, 5)
check(not ok and message:find("water", 1, true), "refused out of water: " .. tostring(message))
ada.pos = {x = 5, y = 0.5, z = 0} -- on the bank next to the water
ok, message = grug_mounts.mount(ada, 5)
check(not ok and message:find("stand or swim in water", 1, true), "refused on the bank beside the water")
ada.pos = {x = 2.3, y = -2.6, z = 0.2} -- swimming at depth: feet in the y = -3 node
ok = grug_mounts.mount(ada, 5)
check(ok, "summoned while swimming")
local boat = controller_of(ada)
local p = boat and boat.object:get_pos()
check(p and p.x == 2 and p.y == 0.5 and p.z == 0, "spawned on the surface, centred on the water node")
eq(ada:get_attach(), boat and boat.object, "rider attached to the boat")
eq(statuses.ada and statuses.ada.variant, "water", "boat status icon variant")
eq(statuses.ada and statuses.ada.detail, "4 nodes/s on water", "Effects shows the speed")
eq(statuses.ada and statuses.ada.label, "Boat", "Effects shows the tier")
eq(boat.object.props.stepheight, 0, "a boat never steps up")
grug_mounts.dismount(ada, "manual", false)

-- River water, flowing, one node deep over ground: standing in it counts.
clear_world()
set_node(0, -1, 0, "default:dirt"); set_node(0, 0, 0, "default:river_water_flowing")
ada.pos = {x = 0, y = -0.5, z = 0}
ok = grug_mounts.mount(ada, 6)
check(ok, "summoned standing in flowing river water")
eq(controller_of(ada).object:get_pos().y, 0.5, "river surface")
eq(statuses.ada.detail, "8 nodes/s on water", "improved boat speed shown")
grug_mounts.dismount(ada, nil, true)

-- Closed surface (ice) and a column deeper than the surface scan.
set_node(0, 1, 0, "default:ice")
ada.pos = {x = 0, y = -0.5, z = 0}
ok, message = grug_mounts.mount(ada, 5)
check(not ok and message:find("open water surface", 1, true), "refused under ice")
clear_world()
for y = -30, 0 do set_node(0, y, 0, "default:water_source") end
ada.pos = {x = 0, y = -30, z = 0}
ok, message = grug_mounts.mount(ada, 5)
check(not ok and message:find("surface", 1, true), "refused deep below the surface")
ada.pos = {x = 0, y = -10, z = 0}
check((grug_mounts.mount(ada, 5)), "summoned within the surface scan")
grug_mounts.dismount(ada, nil, true)
combat.ada = true
ok, message = grug_mounts.mount(ada, 5)
check(not ok and message:find("combat", 1, true), "refused in combat")
combat.ada = nil
ada.hp = 0
check(not grug_mounts.mount(ada, 5), "refused while dead")
ada.hp = 20

------------------------------------------------------------------------------
-- B. Controller.
------------------------------------------------------------------------------
pond()
ada.pos = {x = 0, y = 0, z = 0}
check((grug_mounts.mount(ada, 5)), "summoned for the controller")
boat = controller_of(ada)
ada.control = {up = true}
ada.look = 0
step(boat, 0.1)
local v = boat.object.velocity
near(v.z, 4 * 1.5 * 0.1, "accelerates at 1.5 x speed per second")
near(v.y, 0, "floats on the surface")
for _ = 1, 20 do step(boat, 0.05) end
near(boat.object.velocity.z, 4, "reaches 4 nodes/s")
ada.control = {}
step(boat, 0.1)
near(boat.object.velocity.z, 4 - 0.6, "brakes gradually")
ada.control = {right = true}
boat.object.velocity = {x = 0, y = 0, z = 0}
for _ = 1, 20 do step(boat, 0.05) end
near(boat.object.velocity.x, 4, "A/D strafe at full speed")
ada.control = {}
boat.object.velocity = {x = 0, y = 0, z = 0}
boat.object.pos = {x = 0, y = -1.2, z = 0}
step(boat, 0.0)
eq(boat.object.velocity.y, 2, "submerged boat rises")
boat.object.pos = {x = 0, y = 0.7, z = 0}
step(boat, 0.0)
check(boat.object.velocity.y < 0, "boat above the surface settles down")
grug_mounts.dismount(ada, nil, true)

------------------------------------------------------------------------------
-- C. Water contact (ruling 8).
------------------------------------------------------------------------------
pond()
ada.pos = {x = 3, y = 0, z = 0}
check((grug_mounts.mount(ada, 5)), "summoned at the pond edge")
boat = controller_of(ada)
for z = -3, 3 do for y = -3, 0 do set_node(3, y, z, "default:dirt") end end -- water dug out
step(boat, 0.5)
check(grug_mounts.is_mounted(ada), "still boating before the one-second check")
eq(boat.object.acceleration.y, -9.81, "off the water the boat falls")
step(boat, 0.5)
check(not grug_mounts.is_mounted(ada), "removed by the water-contact check")
check(not boat.object:is_valid(), "the boat entity is gone")
eq(last_feed(), "Your boat left the water.", "water-contact message in the feed")
eq(feed_lines[#feed_lines].key, "mount", "mount notices share one keyed feed line")
eq(#chat, 0, "mount notices never go to chat")
check(grug_mounts.boat_touches_water({x = 0, y = 0.5, z = 0}), "surface boat touches water (node below)")
check(not grug_mounts.boat_touches_water({x = 5, y = 1, z = 0}), "bank position touches no water")

------------------------------------------------------------------------------
-- D. Eject seams and disembarking.
------------------------------------------------------------------------------
pond()
ada.pos = {x = 3, y = 0, z = 1}
grug_mounts.mount(ada, 5)
boat = controller_of(ada)
for _, fn in ipairs(callbacks.hp) do fn(ada, -1) end
check(not grug_mounts.is_mounted(ada), "damage ejects (HP-change seam)")
check(ada.pos.x == 3 and ada.pos.y == 0.5 and ada.pos.z == 1, "ejected rider stays in the water")
check(not boat.object:is_valid(), "the boat vanishes on eject")
ada.pos = {x = 3, y = 0, z = 1} -- swimming again
grug_mounts.mount(ada, 5)
boat = controller_of(ada)
local mob = {}
CONTROLLER.on_punch(boat, mob, 1, {}, nil)
eq(ada.punched, 1, "a punch on the boat reaches the rider")
check(not grug_mounts.is_mounted(ada), "damage ejects (entity on_punch seam)")
eq(ada.pos.x, 3, "punched rider stays in the water")

-- Manual disembark: the nearest free land cell within 2 nodes.
ada.pos = {x = 3, y = 0, z = 1}
grug_mounts.mount(ada, 5)
grug_mounts.toggle(ada, 5)
check(not grug_mounts.is_mounted(ada), "the boat item again disembarks")
check(ada.pos.x == 4 and ada.pos.y == 0.5 and ada.pos.z == 1, "landed on the bank next to the boat")
ada.pos = {x = 0, y = 0, z = 0}
grug_mounts.mount(ada, 5)
grug_mounts.toggle(ada, 5)
check(ada.pos.x == 0 and ada.pos.y == 0.5 and ada.pos.z == 0, "open water: the rider stays in the water")
eq(#entities - 0 > 0 and (function()
	for _, e in ipairs(entities) do if e.object:is_valid() then return false end end
	return true end)(), true, "no boat remains in the world")
-- A one-node wall beside the boat with land behind it: no landing across it.
pond()
for z = -6, 6 do
	for y = -3, 0 do set_node(2, y, z, "default:water_source") end
	for y = 1, 3 do set_node(2, y, z, "default:dirt") end -- the wall above x = 2
	set_node(3, 0, z, "default:dirt"); set_node(4, 0, z, "default:dirt") -- land behind it
end
for x = -3, 1 do for z = -3, 3 do set_node(x, 0, z, "default:water_source") end end
ada.pos = {x = 1, y = 0, z = 0}
grug_mounts.mount(ada, 5)
grug_mounts.toggle(ada, 5)
check(ada.pos.x == 1 and ada.pos.y == 0.5 and ada.pos.z == 0,
	"a wall between boat and land: the rider stays in the water")
for z = -6, 6 do for y = 1, 3 do set_node(2, y, z, "air") end end
set_node(2, 0, 0, "default:dirt") -- a bank one node out, land beyond it
ada.pos = {x = 0, y = 0, z = 0}
grug_mounts.mount(ada, 5)
grug_mounts.toggle(ada, 5)
check(ada.pos.x == 2 and ada.pos.y == 0.5 and ada.pos.z == 0, "open bank two nodes out: landed")
pond()
ada.pos = {x = 3, y = 0, z = 1}
grug_mounts.mount(ada, 5)
for _, fn in ipairs(callbacks.leave) do fn(ada) end
check(not grug_mounts.is_mounted(ada) and not controller_of(ada), "logout disembarks")

------------------------------------------------------------------------------
-- E. One mount or boat.
------------------------------------------------------------------------------
-- A land mount carries the rider into one node of water over ground.
clear_world()
set_node(0, -1, 0, "default:dirt"); set_node(0, 0, 0, "default:water_source")
ada.pos = {x = 0, y = -0.5, z = 0}
check((grug_mounts.mount(ada, 1)), "horse summoned")
local horse = controller_of(ada)
grug_mounts.toggle(ada, 5)
local record = grug_mounts.active.ada
eq(record and record.mode, "water", "the boat item replaces the horse")
check(not horse.object:is_valid(), "the horse is gone")
grug_mounts.toggle(ada, 1)
eq(grug_mounts.active.ada and grug_mounts.active.ada.mode, "land", "a mount item replaces the boat")
grug_mounts.dismount(ada, nil, true)
-- Boat to boat on open water, both ways.
pond()
ada.pos = {x = 0, y = -1, z = 0}
check((grug_mounts.mount(ada, 5)), "Boat summoned for the switch")
local first = controller_of(ada)
grug_mounts.toggle(ada, 6)
eq(grug_mounts.active.ada and grug_mounts.active.ada.tier, 6, "Boat -> Improved Boat on water")
check(not first.object:is_valid(), "the Boat is gone after the switch")
eq(controller_of(ada).object:get_pos().y, 0.5, "the Improved Boat floats on the same surface")
grug_mounts.toggle(ada, 5)
eq(grug_mounts.active.ada and grug_mounts.active.ada.tier, 5, "Improved Boat -> Boat on water")
grug_mounts.dismount(ada, nil, true)
ada.pos = {x = 0, y = 2, z = 0} -- on land, out of the water
grug_mounts.mount(ada, 1)
horse = controller_of(ada)
grug_mounts.toggle(ada, 5)
check(grug_mounts.is_mounted(ada) and horse.object:is_valid(), "refused boat keeps the horse")
grug_mounts.dismount(ada, nil, true)

------------------------------------------------------------------------------
-- F. Shipwright and purchase gating.
------------------------------------------------------------------------------
check(roles.shipwright ~= nil, "shipwright socket role registered")
eq(roles.shipwright({}, {race_id = "dwarf"}), "grug_mobs:villager_dwarf", "shipwright is a villager")
local bo = make_player("bo", "accord", "elf")
local function boat_states()
	return tostring((grug_mounts.tier_state(bo, 5))) .. "," .. tostring((grug_mounts.tier_state(bo, 6)))
end
level = 14
eq(boat_states(), "level,level", "level 14: Requires level 15")
level = 15
eq(boat_states(), "buy,level", "level 15: the Boat is for sale")
level = 30
eq(boat_states(), "buy,previous", "level 30 without the Boat: learn it first")
eq(select(2, grug_mounts.tier_state(bo, 5)), grug_mounts.PRICES[1], "the Boat costs like Apprentice Riding")
eq(grug_mounts.PRICES[6], grug_mounts.PRICES[2], "the Improved Boat costs like Journeyman Riding")
money = 100
ok = grug_mounts.purchase(bo, 5)
check(not ok, "not enough money")
money = 5000
ok, message = grug_mounts.purchase(bo, 5)
check(ok and message == "Boat bought. Press E to open your mounts.", "Boat bought: " .. tostring(message))
eq(money, 5000 - grug_mounts.PRICES[5], "Boat price taken")
eq(boat_states(), "owned,buy", "Improved Boat for sale after the Boat")
level = 29
eq(boat_states(), "owned,level", "level 29: Requires level 30")
level = 30
ok = grug_mounts.purchase(bo, 6)
check(ok, "Improved Boat bought")
eq(boat_states(), "owned,owned", "both boats owned")
check(grug_mounts.owns_tier(bo, 5), "buying the improved boat keeps the base boat")
eq(table.concat(grug_mounts.owned_tier_ids(bo), ","), "5,6", "the quickbar lists both boats")
eq(grug_mounts.highest_owned(bo, "land"), 0, "boats are no riding tier")
ok, message = grug_mounts.purchase(bo, 6)
check(not ok and message == "You already own this boat.", "no second purchase")

-- The dialogue, bound to a live Shipwright of the own faction.
local npc = {pos = {x = 10, y = 5, z = 10}, valid = true}
function npc:get_pos() return self.pos end
local shipwright = {_grug_socket_role = "shipwright", _grug_start = "lethariel",
	_grug_socket = "riding.shipwright", object = npc}
sockets.lethariel = {{id = "riding.shipwright", role = "shipwright", pos = {x = 10, y = 5, z = 10}}}
local cy = make_player("cy", "accord", "dwarf")
cy.pos = {x = 11, y = 5, z = 10}
level = 30
check(grug_mounts.open_trainer(cy, shipwright), "own-faction Shipwright opens")
local fs = shown[#shown].fs
check(fs:find("label[0.4,0.4;Shipwright]", 1, true) ~= nil, "Shipwright title")
check(fs:find("Boat (L15)", 1, true) and fs:find("Improved Boat (L30)", 1, true), "two rows")
check(fs:find("buy_5;Buy " .. grug_mounts.PRICES[5] .. " copper", 1, true) ~= nil, "Buy button with the price")
check(fs:find("Learn Boat first", 1, true) ~= nil, "Learn Boat first")
check(not fs:find("Riding", 1, true), "no riding tier in the Shipwright dialogue")
money = 1000
local formname = shown[#shown].formname
for _, fn in ipairs(callbacks.fields) do fn(cy, formname, {buy_1 = true}) end
eq(grug_mounts.highest_owned(cy, "land"), 0, "a riding tier cannot be bought at the Shipwright")
for _, fn in ipairs(callbacks.fields) do fn(cy, formname, {buy_5 = true}) end
eq(grug_mounts.highest_owned(cy, "water"), 5, "Boat bought through the dialogue")
local throng = make_player("dee", "throng", "orc")
throng.pos = {x = 11, y = 5, z = 10}
check(not grug_mounts.open_trainer(throng, shipwright), "an enemy capital's Shipwright refuses")
check(not grug_mounts.open_trainer(cy, {_grug_socket_role = "idle", _grug_start = "lethariel",
	_grug_socket = "riding.shipwright", object = npc}), "only the service roles open")
-- The Riding Trainer keeps its four rows.
local trainer = {_grug_socket_role = "riding_trainer", _grug_start = "lethariel",
	_grug_socket = "riding.trainer", object = npc}
sockets.lethariel[2] = {id = "riding.trainer", role = "riding_trainer", pos = {x = 10, y = 5, z = 10}}
check(grug_mounts.open_trainer(cy, trainer), "Riding Trainer opens")
fs = shown[#shown].fs
check(fs:find("Master Riding (L60)", 1, true) and not fs:find("Boat", 1, true),
	"Riding Trainer lists the four riding tiers only")

------------------------------------------------------------------------------
-- G. Kraken speed switch (ruling 7).
------------------------------------------------------------------------------
local kraken_def
grug_mobs.register_mob = function(name, def) if name == "grug_mobs:kraken" then kraken_def = def end end
mobs = {spawn = function() end}
load("mods/ENTITIES/grug_mobs/kraken.lua")
eq(kraken_def.view_range, 40, "view range 40")
eq(kraken_def.run_velocity, 5, "base run velocity 5")
local stopped = 0
local guard = setmetatable({object = {get_pos = function() return {x = 0, y = 1, z = 0} end},
	attack = {}, run_velocity = 5,
	stop_attack = function(self) self.attack = nil; stopped = stopped + 1 end}, {__index = kraken_def})
water_class = "deep_ocean"
kraken_def.do_custom(guard, 0.5)
eq(guard.run_velocity, 5, "no switch before the one-second tick")
kraken_def.do_custom(guard, 0.5)
eq(guard.run_velocity, 10, "10 nodes/s in deep ocean")
check(guard.attack ~= nil, "keeps its target in deep ocean")
check(guard.run_velocity > grug_mounts.TIERS[6].speed, "faster than the improved boat")
water_class = "coastal_shelf"
kraken_def.do_custom(guard, 1)
eq(guard.run_velocity, 5, "5 nodes/s outside deep ocean")
eq(stopped, 1, "leash: drops the target outside deep ocean")
eq(guard.state, "stand", "leash: holds position")
water_class = "channel"
kraken_def.do_custom(guard, 1)
eq(guard.run_velocity, 5, "5 nodes/s in a dragon channel")
-- A slow saved the base speeds: the switch writes the base, not the live field.
guard._grug_speed_base = {walk = 3, run = 5}
guard.run_velocity = 2.5
water_class = "deep_ocean"
kraken_def.do_custom(guard, 1)
eq(guard._grug_speed_base.run, 10, "switch writes the speed base while slowed")
eq(guard.run_velocity, 2.5, "the slowed live speed stays the effect engine's")

------------------------------------------------------------------------------
-- H. Riding tiers 1-4 at the shipped prices, through the real dialogue and
--    purchase code.
------------------------------------------------------------------------------
local ed = make_player("ed", "accord", "human")
ed.pos = {x = 11, y = 5, z = 10}
local function trainer_buy(tier_id)
	check(grug_mounts.open_trainer(ed, trainer), "Riding Trainer opens for tier " .. tier_id)
	local form = shown[#shown]
	for _, fn in ipairs(callbacks.fields) do fn(ed, form.formname, {["buy_" .. tier_id] = true}) end
	return form.fs
end
for tier_id = 1, 4 do
	local tier, price = grug_mounts.TIERS[tier_id], grug_mounts.PRICES[tier_id]
	local name = tier.name
	check(type(price) == "number" and price > 0, name .. ": a shipped price")
	if tier_id < 4 then
		level = 60
		eq((grug_mounts.tier_state(ed, tier_id + 1)), "previous", name .. ": comes before the next tier")
		money = 1000000
		check(not grug_mounts.purchase(ed, tier_id + 1), name .. ": the next tier cannot be skipped to")
	end
	level = tier.level - 1
	eq((grug_mounts.tier_state(ed, tier_id)), "level", name .. ": below level " .. tier.level)
	money = price
	trainer_buy(tier_id)
	eq(grug_mounts.owns_tier(ed, tier_id), false, name .. ": not bought below its level")
	eq(money, price, name .. ": nothing taken below its level")
	level = tier.level
	local state, shown_price = grug_mounts.tier_state(ed, tier_id)
	eq(state, "buy", name .. ": for sale at level " .. tier.level)
	eq(shown_price, price, name .. ": the dialogue's price is the shipped price")
	money = price - 1
	local fs = trainer_buy(tier_id)
	check(fs:find(("buy_%d;Buy %d copper"):format(tier_id, price), 1, true) ~= nil,
		name .. ": the Buy button shows " .. price .. " copper")
	eq(grug_mounts.owns_tier(ed, tier_id), false, name .. ": one copper short is refused")
	eq(money, price - 1, name .. ": nothing taken when one copper short")
	money = price + 7
	trainer_buy(tier_id)
	check(grug_mounts.owns_tier(ed, tier_id), name .. ": bought")
	eq(money, 7, name .. ": exactly the shipped price taken")
	eq((grug_mounts.tier_state(ed, tier_id)), "owned", name .. ": owned afterwards")
	ok, message = grug_mounts.purchase(ed, tier_id)
	check(not ok and message == "You already own this riding tier.", name .. ": no second purchase")
end
eq(grug_mounts.highest_owned(ed, "land"), 2, "riding: the two land tiers")
eq(grug_mounts.highest_owned(ed, "flight"), 4, "riding: the two flight tiers")
eq(table.concat(grug_mounts.owned_tier_ids(ed), ","), "1,2,3,4", "the quickbar lists the four riding tiers")
eq(grug_mounts.highest_owned(ed, "water"), 0, "riding tiers are no boat")

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R29 B PORTABLE PASS checks=%d"):format(checks))
