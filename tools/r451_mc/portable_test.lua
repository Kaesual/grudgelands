-- Release 0.45.1 lane MC portable test (LuaJIT): the riding camera, the
-- quickbar's Dismount button and the first riding mount's banner (fix plan
-- rows 8 and 9). Loads the REAL grug_mounts (catalog, state, entity,
-- trainer, shipwright) and grug_quickbar under a minimal engine stub:
--   A. every mount model has a camera: first-person height above its seat by
--      about a sitting eye, a small z, third person inside the engine's clamp;
--      the boats keep the plain sitting eye (0.8, as before);
--   B. a summon of every model hands its values to the engine: the eye
--      height is the first-person height, the eye offsets carry z and the
--      third-person difference (tenths of a node);
--   C. the step's re-attach (a turn) leaves them alone, a value changed at
--      runtime (the probe's way) holds over the steps, and a pose change
--      mid-ride is undone (sit pose and camera back);
--   D. the dismount gives the standing eye back and zero offsets;
--   E. the quickbar shows Dismount below the mounts only while riding; a
--      click dismounts like the manual dismount and closes the window;
--   F. the banner "Press E to summon your mount": once per character, for
--      the first riding mount, when the dialogue closes; none for a later
--      tier, a boat, or a character who owned a mount before;
--   G. a flyer plays its flight loop in the air, hovering too; on the
--      ground (summoned, landed, on a slab, idle or moving) it holds one still
--      level frame without the wing sound (0.45.1 follow-ups);
--   H. the playtest's sizes, seats and centring (follow-up 3): the stag and
--      the bats grown with the displays kept, the tiger's and the stag's seat
--      on the back, the eagles' mesh centred under the rider, the boats'
--      hulls smaller with their physics kept, the ibex idling without the
--      head bob;
--   I. the user's tuned values (follow-up 4) and the bats' still-body ride mesh;
--   J. a boat only at the surface (the top two water nodes), every path.
--
--   luajit tools/r451_mc/portable_test.lua [REPO]
-- Prints "R451 MC PORTABLE PASS checks=<n>" or the failures (exit 1).

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
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. part .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. part .. ")")
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

-- Flat ground up to y = 0 (top at 0.5), air above.
-- `placed` holds single nodes on top (a slab for the flyers' ground cases).
local placed = {}
local function node_at(pos)
	local x, y, z = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	return placed[x .. "," .. y .. "," .. z] or (y <= 0 and "default:dirt" or "air")
end

local serial, shown, banners, feed_lines = {}, {}, {}, {}
local callbacks = {fields = {}}
local registered_entities = {}

core = {
	registered_nodes = {
		air = {walkable = false, liquidtype = "none"},
		["default:dirt"] = {walkable = true, liquidtype = "none"},
		["stairs:slab_stone"] = {walkable = true, liquidtype = "none"},
		["default:water_source"] = {walkable = false, liquidtype = "source", groups = {water = 3}},
		["default:ice"] = {walkable = true, liquidtype = "none"},
		["default:stone"] = {walkable = true, liquidtype = "none"},
	},
	registered_items = {},
	registered_entities = registered_entities,
	get_item_group = function(name, group)
		local def = core.registered_nodes[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_node_or_nil = function(pos) return {name = node_at(pos)} end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_craftitem = function() end,
	register_on_player_hpchange = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_shutdown = function() end,
	register_on_player_receive_fields = function(fn) callbacks.fields[#callbacks.fields + 1] = fn end,
	show_formspec = function(name, formname, fs)
		shown[#shown + 1] = {name = name, formname = formname, fs = fs}
	end,
	close_formspec = function(name, formname) core.show_formspec(name, formname, "") end,
	formspec_escape = function(text) return (tostring(text):gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text .. "(c@#ffffff)" end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_window_information = function() return nil end,
	log = function() end,
}
local players = {}
core.get_player_by_name = function(name) return players[name] end

local function receive_fields(player, formname, fields)
	for _, fn in ipairs(callbacks.fields) do
		if fn(player, formname, fields) then return true end
	end
	return false
end

local function new_object(pos, name, staticdata)
	local def = registered_entities[name]
	local object = {pos = copy(pos), velocity = {x = 0, y = 0, z = 0}, valid = true, props = {}}
	local entity = setmetatable({object = object, name = name}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:set_pos(p) self.pos = copy(p) end
	function object:get_velocity() return copy(self.velocity) end
	function object:set_velocity(v) self.velocity = copy(v) end
	function object:set_acceleration() end
	function object:set_yaw(y) self.yaw = y end
	function object:get_yaw() return self.yaw or 0 end
	function object:is_valid() return self.valid end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:set_armor_groups() end
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:get_properties() return self.props end
	function object:set_attach(parent, bone, position) self.parent, self.attach_pos = parent, copy(position) end
	function object:get_attach() return self.parent end
	function object:set_animation(range) self.anim = copy(range) end
	if entity.on_activate then entity.on_activate(entity, staticdata, 0) end
	if not object.valid then return nil end
	return object
end
core.add_entity = function(pos, name, staticdata) return new_object(pos, name, staticdata) end

-- A player whose properties and eye offsets are recorded as the engine keeps
-- them (eye height 1.47 standing, player_api's model default).
local function make_player(name, faction, race)
	local player = {name = name, pos = {x = 0, y = 0.5, z = 0}, hp = 20, meta = {},
		faction = faction, race = race, look = 0, eye_offset_calls = 0, attaches = 0,
		props = {visual_size = {x = 1, y = 1}, eye_height = 1.47},
		eye_first = {x = 0, y = 0, z = 0}, eye_third = {x = 0, y = 0, z = 0}}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_pos()
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function player:set_pos(p) self.pos = copy(p) end
	function player:get_hp() return self.hp end
	function player:set_attach(parent, bone, position, rotation)
		self.parent, self.attach_rotation = parent, copy(rotation)
		self.attaches = self.attaches + 1
	end
	function player:set_detach() self.parent = nil end
	function player:get_attach() return self.parent end
	function player:set_eye_offset(first, third)
		self.eye_first, self.eye_third = copy(first), copy(third)
		self.eye_offset_calls = self.eye_offset_calls + 1
	end
	function player:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function player:get_properties() return copy(self.props) end
	function player:get_look_horizontal() return self.look end
	function player:get_player_control() return {} end
	function player:hud_remove() end
	function player:get_inventory()
		return {get_stack = function() return {is_empty = function() return true end} end}
	end
	function player:get_meta()
		local meta = self.meta
		return {
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = v end,
		}
	end
	players[name] = player
	return player
end

------------------------------------------------------------------------------
-- Game stubs.
------------------------------------------------------------------------------
-- player_api: the animation per player and the eye height of its class, as
-- set_animation writes it on a class change (sit 0.8, every other 1.47).
local animations = {}
player_api = {player_attached = {}}
function player_api.set_animation(player, anim)
	local name = player:get_player_name()
	if animations[name] == anim then return end
	animations[name] = anim
	player:set_properties({eye_height = anim == "sit" and 0.8 or 1.47})
end
function player_api.get_animation(player)
	return {animation = animations[player:get_player_name()]}
end
local sounds_played = {}
grug_sounds = {play = function(event) sounds_played[#sounds_played + 1] = event return false end,
	stop = function() end}
grug_core = {
	FLIGHT_CEILING = 600,
	FLASH_COLOR = {error = 1, notice = 2},
	is_max_hp_clamp = function() return false end,
	in_combat = function() return false end,
	set_status = function() end,
	clear_status = function() end,
	flash = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), text = text, key = key}
		return true
	end,
	banner = function(player, text, color)
		banners[#banners + 1] = {name = player:get_player_name(), text = text, color = color}
		return true
	end,
	settlement_sockets_at = function()
		return {{id = "stable", role = "riding_trainer", pos = {x = 0, y = 0.5, z = 2}},
			{id = "dock", role = "shipwright", pos = {x = 0, y = 0.5, z = 2}}}
	end,
}
grug_zones = {
	water_class_at = function() return "land" end,
	id_at = function() return "heartland" end,
	get = function() return {territory_rule = "contested_land"} end,
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
grug_xp = {get_level = function() return 60 end}
grug_money = {take = function() return true end, format = function(c) return c .. " copper" end}
grug_mobs = {register_start_socket_role = function() end}
sfinv = {inventory_suspended = function() return false end}
grug_inventory = {POTION_BELT = "grug_potion_belt", POTION_BELT_SIZE = 4,
	home_state = function() return nil end}
grug_home = {return_home = function() end}
grug_keys = {register_on_press = function() end}

local function load(path) dofile(ROOT .. "/" .. path) end
grug_mounts = {}
load("mods/PLAYER/grug_mounts/catalog.lua")
load("mods/PLAYER/grug_mounts/state.lua")
load("mods/PLAYER/grug_mounts/entity.lua")
load("mods/PLAYER/grug_mounts/trainer.lua")
load("mods/PLAYER/grug_mounts/shipwright.lua")
load("mods/PLAYER/grug_quickbar/init.lua")

local MODELS = grug_mounts.MODELS
local function seat_of(model) return model.attach_y * model.visual_size.y / 10 end
local function camera_of(player) return grug_mounts.active[player:get_player_name()].model.camera end

-- The values the engine must hold for `camera` (tenths of a node).
local function check_engine(player, camera, label)
	near(player.props.eye_height, camera.first.y, label .. ": eye height = first-person y")
	near(player.eye_first.x, 0, label .. ": first x")
	near(player.eye_first.y, 0, label .. ": first offset y")
	near(player.eye_first.z, camera.first.z * 10, label .. ": first offset z")
	near(player.eye_third.y, (camera.third.y - camera.first.y) * 10, label .. ": third offset y")
	near(player.eye_third.z, camera.third.z * 10, label .. ": third offset z")
end

------------------------------------------------------------------------------
-- A. The catalog.
------------------------------------------------------------------------------
local model_count = 0
for id, model in pairs(MODELS) do
	model_count = model_count + 1
	local camera = model.camera
	if check(type(camera) == "table" and type(camera.first) == "table" and
			type(camera.third) == "table", id .. " has a camera") then
		for _, view in ipairs({"first", "third"}) do
			check(type(camera[view].y) == "number" and type(camera[view].z) == "number",
				id .. " " .. view .. " y and z are numbers")
		end
		local dy = camera.third.y - camera.first.y
		check(dy >= -1 and dy <= 1.5, id .. ": third y within the engine clamp (first -1..+1.5)")
		check(math.abs(camera.third.z) <= 0.5, id .. ": third z within the engine clamp")
		check(math.abs(camera.first.z) <= 0.5, id .. ": first z is small")
		eq(model.eye_y, nil, id .. ": the old eye_y is gone")
		local seat = seat_of(model)
		if model.id == "boat" or model.id == "improved_boat" then
			eq(camera.first.y, 0.8, id .. ": a boat keeps the sitting eye")
			eq(camera.third.y, 0.8, id .. ": a boat's third person as before")
			eq(camera.first.z, 0, id .. ": a boat's first z")
		else
			-- A sitting rider's eye above the seat, a sitting eye height give or
			-- take (the ibex's looks over its horns: 1.57, the user's value).
			check(camera.first.y >= seat + 0.6 and camera.first.y <= seat + 1.6,
				id .. ": first-person height a sitting eye above the seat (" ..
				camera.first.y .. " vs seat " .. seat .. ")")
			check(camera.first.z <= 0, id .. ": first person not ahead of the rider")
			check(camera.third.y >= seat + 0.5, id .. ": third person looks over the rider")
		end
	end
end
eq(model_count, 14, "every mount model is in the catalog")

------------------------------------------------------------------------------
-- B. Every model's values reach the engine on the summon.
------------------------------------------------------------------------------
-- {model, faction, race, tier}
local RIDES = {
	{"t1_accord", "accord", "human", 1}, {"t1_throng", "throng", "orc", 1},
	{"human", "accord", "human", 2}, {"dwarf", "accord", "dwarf", 2},
	{"elf", "accord", "elf", 2}, {"orc", "throng", "orc", 2},
	{"undead", "throng", "undead", 2}, {"troll", "throng", "troll", 2},
	{"expert_accord", "accord", "human", 3}, {"master_accord", "accord", "human", 4},
	{"expert_throng", "throng", "orc", 3}, {"master_throng", "throng", "orc", 4},
	{"boat", "accord", "human", 5}, {"improved_boat", "accord", "human", 6},
}
eq(#RIDES, model_count, "the rides cover every model")
for index, ride in ipairs(RIDES) do
	local player = make_player("rider" .. index, ride[2], ride[3])
	local ok = grug_mounts.spawn_entity(player, ride[4], {x = 0, y = 0.5, z = 0})
	check(ok == true, ride[1] .. " summoned")
	local record = grug_mounts.active[player:get_player_name()]
	eq(record and record.model, MODELS[ride[1]], ride[1] .. " is the ridden model")
	eq(animations[player:get_player_name()], "sit", ride[1] .. ": the sit pose")
	if record then check_engine(player, MODELS[ride[1]].camera, ride[1]) end
	grug_mounts.dismount(player, "manual", false)
end

------------------------------------------------------------------------------
-- C. Steps, a runtime change, a pose change mid-ride.
------------------------------------------------------------------------------
local function step_mount(player)
	local record = grug_mounts.active[player:get_player_name()]
	local entity = record.object:get_luaentity()
	entity.on_step(entity, 0.05, {touching_ground = true})
end

for _, ride in ipairs({{"t1_accord", "accord", "human", 1}, {"master_throng", "throng", "orc", 4}}) do
	local player = make_player("stepper_" .. ride[1], ride[2], ride[3])
	grug_mounts.spawn_entity(player, ride[4], {x = 0, y = 0.5, z = 0})
	local calls, attaches = player.eye_offset_calls, player.attaches
	step_mount(player)
	player.look = 1.2
	step_mount(player)
	step_mount(player)
	check(player.attaches > attaches, ride[1] .. ": the turn re-attaches the rider")
	eq(player.eye_offset_calls, calls, ride[1] .. ": the steps never write the camera")
	check_engine(player, MODELS[ride[1]].camera, ride[1] .. " after the re-attach")

	-- The probe's way: change the model's values, apply them once.
	local camera = MODELS[ride[1]].camera
	local saved = copy(camera)
	camera.first.y, camera.first.z, camera.third.y = camera.first.y + 0.5, -0.4, camera.third.y + 0.3
	grug_mounts.apply_camera(player, MODELS[ride[1]])
	player.look = -0.7
	step_mount(player)
	step_mount(player)
	check_engine(player, camera, ride[1] .. ": a runtime change holds over the steps")

	-- Something replaces the sit pose (and with it the eye height).
	player_api.set_animation(player, "stand")
	near(player.props.eye_height, 1.47, ride[1] .. ": the pose change reset the eye height")
	step_mount(player)
	eq(animations[player:get_player_name()], "sit", ride[1] .. ": the step restores the sit pose")
	check_engine(player, camera, ride[1] .. ": the step restores the camera")
	MODELS[ride[1]].camera = saved

	------------------------------------------------------------------------
	-- D. The dismount.
	------------------------------------------------------------------------
	grug_mounts.dismount(player, "manual", false)
	near(player.props.eye_height, 1.47, ride[1] .. ": the standing eye height back")
	near(player.eye_first.z, 0, ride[1] .. ": no first-person offset after the ride")
	near(player.eye_third.y, 0, ride[1] .. ": no third-person offset after the ride")
end

------------------------------------------------------------------------------
-- E. The quickbar's Dismount button.
------------------------------------------------------------------------------
local FORMNAME = grug_quickbar.FORMNAME
local quick = make_player("quick", "accord", "human")
quick.meta["grug_mounts:land_tier"] = 2
quick.meta["grug_mounts:water_tier"] = 5
local fs = grug_quickbar.formspec(quick)
lacks(fs, "grug_quickbar_dismount", "no Dismount while on foot")
-- On foot on the ground (a dismount steps the rider aside and up).
local function summon(player, tier_id)
	player.pos = {x = 0, y = 0.5, z = 0}
	grug_mounts.toggle(player, tier_id)
	return check(grug_mounts.is_mounted(player), player.name .. " summons tier " .. tier_id)
end
summon(quick, 2)
fs = grug_quickbar.formspec(quick)
has(fs, "grug_quickbar_dismount;Dismount]", "Dismount while riding")
local mount_at = fs:find("grug_quickbar_mount_5", 1, true)
local dismount_at = fs:find("grug_quickbar_dismount", 1, true)
local belt_at = fs:find("Potion belt", 1, true)
check(mount_at and dismount_at and belt_at and mount_at < dismount_at and dismount_at < belt_at,
	"Dismount below the mounts, above the potion belt")
local mount_y = tonumber(fs:match("image_button%[[%d.]+,([%d.]+);[^%]]*grug_quickbar_mount_5;"))
local button_y = tonumber(fs:match("button%[[%d.]+,([%d.]+);[^%]]*grug_quickbar_dismount;"))
check(mount_y and button_y and button_y >= mount_y + 1, "the button sits below the mount row")
local height_riding = tonumber(fs:match("size%[[%d.]+,([%d.]+)%]"))
grug_mounts.dismount(quick, "manual", false)
local height_foot = tonumber(grug_quickbar.formspec(quick):match("size%[[%d.]+,([%d.]+)%]"))
check(height_riding and height_foot and height_riding > height_foot, "the window grows by the button")

summon(quick, 2)
local feeds_before = #feed_lines
grug_quickbar.open(quick)
local sent = #shown
receive_fields(quick, FORMNAME, {grug_quickbar_dismount = "Dismount"})
check(not grug_mounts.is_mounted(quick), "Dismount dismounts")
eq(#feed_lines, feeds_before, "the manual dismount, without a notice")
near(quick.props.eye_height, 1.47, "Dismount restores the standing eye")
eq(shown[#shown].fs, "", "the click closes the window")
eq(#shown, sent + 1, "one close, nothing else sent")
-- A stale click (the ride ended meanwhile): nothing happens, the window closes.
grug_quickbar.open(quick)
receive_fields(quick, FORMNAME, {grug_quickbar_dismount = "Dismount"})
check(not grug_mounts.is_mounted(quick), "a stale Dismount changes nothing")
eq(shown[#shown].fs, "", "a stale Dismount closes the window")
-- After the close, the window's events do nothing.
summon(quick, 2)
receive_fields(quick, FORMNAME, {grug_quickbar_dismount = "Dismount"})
check(grug_mounts.is_mounted(quick), "a Dismount from a closed window does nothing")
grug_mounts.dismount(quick, "manual", false)

------------------------------------------------------------------------------
-- F. The first riding mount's banner.
------------------------------------------------------------------------------
eq(grug_mounts.SUMMON_HINT, "Press E to summon your mount", "the banner's text")
local function npc(role, player)
	return {_grug_socket_role = role,
		_grug_start = player.faction == "throng" and "nhal_veyr" or "highcourt",
		_grug_socket = role == "shipwright" and "dock" or "stable",
		object = {get_pos = function() return {x = 0, y = 0.5, z = 2} end}}
end
local function formname_of(player)
	for index = #shown, 1, -1 do
		if shown[index].name == player:get_player_name() and
				shown[index].formname:sub(1, 20) == "grug_mounts:service:" then
			return shown[index].formname
		end
	end
end
-- One visit: open, buy `tier_id`, close. Returns the banners shown before
-- and after the close.
local function visit(player, role, tier_id)
	check(grug_mounts.open_trainer(player, npc(role, player)), "the " .. role .. " opens")
	local formname = formname_of(player)
	local before = #banners
	receive_fields(player, formname, {["buy_" .. tier_id] = "Buy"})
	local at_purchase = #banners - before
	receive_fields(player, formname, {close = "Close", quit = "true"})
	return at_purchase, #banners - before
end

local fresh = make_player("fresh", "accord", "human")
local at_purchase, after_close = visit(fresh, "riding_trainer", 1)
check(grug_mounts.owns_tier(fresh, 1), "the first mount bought")
eq(at_purchase, 0, "no banner while the dialogue is open")
eq(after_close, 1, "the banner when the dialogue closes")
eq(banners[#banners].text, "Press E to summon your mount", "the banner's text shown")
eq(banners[#banners].name, "fresh", "to the buyer")
eq(fresh.meta["grug_mounts:summon_hint"], 1, "the once flag in player meta")
-- The dialogue again, closed without a purchase: nothing.
check(grug_mounts.open_trainer(fresh, npc("riding_trainer", fresh)), "the dialogue reopens")
local before = #banners
receive_fields(fresh, formname_of(fresh), {quit = "true"})
eq(#banners, before, "a later close without a purchase shows nothing")
at_purchase, after_close = visit(fresh, "riding_trainer", 2)
check(grug_mounts.owns_tier(fresh, 2), "the second tier bought")
eq(after_close, 0, "no banner for a later tier")

-- A character who owned a mount before 0.45.1 (no flag): nothing.
local veteran = make_player("veteran", "throng", "orc")
veteran.meta["grug_mounts:land_tier"] = 1
at_purchase, after_close = visit(veteran, "riding_trainer", 2)
check(grug_mounts.owns_tier(veteran, 2), "the veteran's tier 2 bought")
eq(after_close, 0, "no banner for a character who owned a mount")
eq(veteran.meta["grug_mounts:summon_hint"], nil, "no flag written for the veteran")

-- A boat is no riding mount: no banner; the first riding mount afterwards has it.
local sailor = make_player("sailor", "accord", "elf")
at_purchase, after_close = visit(sailor, "shipwright", 5)
check(grug_mounts.owns_tier(sailor, 5), "the boat bought")
eq(after_close, 0, "no banner for a boat")
at_purchase, after_close = visit(sailor, "riding_trainer", 1)
eq(after_close, 1, "the banner for the first riding mount after a boat")

-- The purchase itself answers the hint once (a flag already set: none).
local direct = make_player("direct", "accord", "human")
local ok, _, hint = grug_mounts.purchase(direct, 1)
check(ok and hint == true, "the first purchase answers the hint")
direct.meta["grug_mounts:land_tier"] = 0
ok, _, hint = grug_mounts.purchase(direct, 1)
check(ok and not hint, "the flag keeps it to once per character")

------------------------------------------------------------------------------
-- G. Flyers (0.45.1 follow-up, the user's ruling): in the air the flight loop,
-- hovering too; on the ground, idle or moving, the still `ground` frame of
-- the flight loop (level, no wing beat) and no wing sound. The ground's top
-- is y = 0.5 here; the flyer box's bottom is 0.1 under its origin.
------------------------------------------------------------------------------
for _, ride in ipairs({{"expert_accord", "accord", 3}, {"master_accord", "accord", 4},
		{"expert_throng", "throng", 3}, {"master_throng", "throng", 4}}) do
	local id = ride[1]
	local model = MODELS[id]
	local ground, move = model.animation.ground, model.animation.move
	check(ground and ground[1] == ground[2], id .. ": one still ground frame")
	check(ground and ground[1] >= move[1] and ground[1] <= move[2],
		id .. ": the ground frame is a frame of the flight loop")
	local flyer = make_player("flyer_" .. id, ride[2], "human")
	-- Summoned by a player standing on the ground (the box reaches 0.1 into it).
	grug_mounts.spawn_entity(flyer, ride[3], {x = 0, y = 0.5, z = 0})
	local record = grug_mounts.active[flyer:get_player_name()]
	local entity = record.object:get_luaentity()
	eq(entity._grug_animation, "ground", id .. ": summoned on the ground, the still frame at once")
	local controls = {}
	function flyer:get_player_control() return controls end
	local function at(y, label, expected, keys)
		controls = keys or {}
		record.object.pos = {x = 0, y = y, z = 0}
		local before = #sounds_played
		step_mount(flyer)
		eq(entity._grug_animation, expected, id .. ": " .. label)
		local wings = false
		for index = before + 1, #sounds_played do
			if sounds_played[index] == "mount_wings" then wings = true end
		end
		return wings
	end
	at(0.5, "idle where summoned", "ground")
	eq(record.visual.anim and record.visual.anim.x, ground[1], id .. ": the visual holds the ground frame")
	check(not at(0.5, "moving on the ground", "ground", {up = true}),
		id .. ": moving on the ground, no wing sound")
	-- Where the engine stops a landing: the box's bottom on the ground's top.
	at(0.6, "landed (resting on the ground's top)", "ground")
	at(0.6, "landed, pushing down", "ground", {sneak = true})
	at(0.69, "a hair above the ground", "ground")
	at(0.9, "hovering 0.3 above the ground", "move")
	check(at(0.9, "flying low over the ground", "move", {up = true}),
		id .. ": the wing sound in the air")
	at(12, "hovering high", "move")
	at(12, "descending", "move", {sneak = true})
	-- A slab (top at y = 1.0) at the middle: the flyer rests at 1.1.
	placed["0,1,0"] = "stairs:slab_stone"
	at(1.1, "resting on a slab", "ground")
	placed["0,1,0"] = nil
	at(1.1, "the slab gone: in the air", "move")
	at(0.6, "landed again", "ground")
	grug_mounts.dismount(flyer, "manual", false)
end

------------------------------------------------------------------------------
-- H. Sizes, seats and centring (0.45.1 follow-up 3).
------------------------------------------------------------------------------
local function size_of(id) return MODELS[id].visual_size.y end
eq(size_of("elf"), 9.6, "the stag at 120 %")
eq(size_of("expert_throng"), 3.9, "the cave bat at 130 %")
eq(size_of("master_throng"), 5.46, "the blood bat at 130 %")
eq(size_of("boat"), 0.98, "the rowboat's hull at 98 % (the user's value)")
eq(size_of("improved_boat"), 0.8, "the sailboat's hull at 80 %")
for id, old in pairs({elf = 8, undead = 1.7, expert_throng = 3, master_throng = 4.2}) do
	eq(MODELS[id].display_size and MODELS[id].display_size.y, old, id .. ": the display keeps its size")
end
do
	local file = assert(io.open(ROOT .. "/mods/ENTITIES/grug_mobs/capital_displays.lua"))
	local text = file:read("*a")
	file:close()
	check(text:find("visual_size=model.display_size or model.visual_size", 1, true) ~= nil,
		"the capital displays use the display size")
end
-- Seats measured on the backs (the back's top in the middle: tiger 1.52,
-- stag at 120 % 1.32; the horse's 1.41 under its 1.26 seat).
near(seat_of(MODELS.troll), 1.5225, "the tiger's seat on its back")
near(seat_of(MODELS.elf), 1.32, "the stag's seat on its back (the user's value)")
near(seat_of(MODELS.expert_throng), 2.496, "the cave bat's seat grows with it")
near(seat_of(MODELS.master_throng), 3.7128, "the blood bat's seat grows with it")
eq(MODELS.troll.camera.first.y, 2.4, "the tiger's camera (the user's value)")
eq(MODELS.expert_accord.camera.first.y, 2.8, "the eagle's camera (the user's value)")
eq(MODELS.master_accord.camera.first.y, 3.6, "the sea eagle's camera (the user's value)")
-- The boats: physics, water surface and seat in the hull.
for _, id in ipairs({"boat", "improved_boat"}) do
	local box = MODELS[id].collisionbox
	eq(table.concat(box, ","), "-0.45,-0.3,-0.45,0.45,0.7,0.45", id .. ": the physics box unchanged")
	check(seat_of(MODELS[id]) < 0.1 and seat_of(MODELS[id]) > 0, id .. ": the rider sits in the smaller hull")
end
eq(MODELS.boat.attach_z, 4.9, "the rowboat's bench shift (the user's value)")
-- Centring: the eagles' mesh moves left under the rider; nothing else moves.
for id, model in pairs(MODELS) do
	local expected = ({expert_accord = -0.65, master_accord = -0.87})[id] or nil
	eq(model.attach_x, expected, id .. ": the sideways shift")
end
for _, ride in ipairs({{"expert_accord", "accord", 3, -0.65}, {"master_accord", "accord", 4, -0.87},
		{"troll", "throng", 2, 0}}) do
	local rider = make_player("centred_" .. ride[1], ride[2], ride[1] == "troll" and "troll" or "human")
	grug_mounts.spawn_entity(rider, ride[3], {x = 0, y = 0.5, z = 0})
	local record = grug_mounts.active[rider:get_player_name()]
	near(record.visual.attach_pos.x, ride[4], ride[1] .. ": the visual's sideways attach")
	near(record.visual.attach_pos.y, -seat_of(MODELS[ride[1]]) * 10, ride[1] .. ": the visual under the seat")
	grug_mounts.dismount(rider, "manual", false)
end
-- The ridden ibex idles on the walk's first frame (no head bob); its walk
-- and every display keep the shared clips.
do
	local dwarf = make_player("ibex_rider", "accord", "dwarf")
	grug_mounts.spawn_entity(dwarf, 2, {x = 0, y = 0.5, z = 0})
	local record = grug_mounts.active.ibex_rider
	eq(record.visual.anim and record.visual.anim.x .. "-" .. record.visual.anim.y, "200-200",
		"the ridden ibex idles on one still frame")
	local controls = {up = true}
	function dwarf:get_player_control() return controls end
	step_mount(dwarf)
	eq(record.visual.anim.x .. "-" .. record.visual.anim.y, "200-300", "the ridden ibex walks its clip")
	controls = {}
	step_mount(dwarf)
	eq(record.visual.anim.x .. "-" .. record.visual.anim.y, "200-200", "and idles still again")
	eq(table.concat(MODELS.dwarf.animation.stand, ","), "1,100,30", "the displays keep the idle clip")
	grug_mounts.dismount(dwarf, "manual", false)
end

------------------------------------------------------------------------------
-- I. The user's tuned values (0.45.1 follow-up 4) and the ridden bats' mesh.
------------------------------------------------------------------------------
eq(MODELS.dwarf.camera.first.y, 2.8, "the ibex's camera (the user's value)")
eq(MODELS.elf.attach_y, 1.375, "the stag's seat (the user's value)")
eq(MODELS.orc.attach_y, 7.355, "the boar's seat (the user's value)")
near(seat_of(MODELS.orc), 1.140025, "the boar's seat at 1.14 nodes")
eq(size_of("undead"), 2.125, "the wolf at 125 % (the user's value)")
eq(MODELS.undead.attach_y, 8.382, "the wolf's seat (the user's value)")
eq(MODELS.undead.attach_z, 3.125, "the wolf's mesh shift (the user's value)")
eq(MODELS.undead.camera.first.y, 2.5, "the wolf's camera (the user's value)")
-- Tier 2 shares the selection box of its highest seat: now the wolf's.
near(MODELS.human.selectionbox[5], seat_of(MODELS.undead) + 1.8,
	"the tier-2 selection box covers the wolf's rider")
for _, id in ipairs({"expert_throng", "master_throng"}) do
	eq(MODELS[id].mesh, "grug_mounts_bat_ride.b3d", id .. ": ridden on the still-body copy")
	eq(MODELS[id].display_mesh, "grug_mobs_cave_bat.b3d", id .. ": the display keeps the original")
end
for id, model in pairs(MODELS) do
	if id ~= "expert_throng" and id ~= "master_throng" then
		eq(model.display_mesh, nil, id .. ": no display mesh of its own")
	end
end
do
	local file = io.open(ROOT .. "/mods/PLAYER/grug_mounts/models/grug_mounts_bat_ride.b3d", "rb")
	check(file ~= nil, "the bats' ride mesh ships (tools/r451_mc/gen_bat_ride_mesh.py --check)")
	if file then file:close() end
	file = assert(io.open(ROOT .. "/mods/ENTITIES/grug_mobs/capital_displays.lua"))
	local text = file:read("*a")
	file:close()
	check(text:find("mesh=model.display_mesh or model.mesh", 1, true) ~= nil,
		"the capital displays use the display mesh")
end

------------------------------------------------------------------------------
-- J. A boat only at the surface (0.45.1 follow-up 4): the feet in the top
-- water node or the one below (the surface at most 2 nodes over the feet),
-- through every summon path (the quickbar's toggle, mount, the re-summon on a
-- boat); deeper, under ice or under an overhang: refused.
------------------------------------------------------------------------------
do
	-- A column of water at x = 20: y = -5..0, its top y = 0.5; air above.
	local function column(top_node)
		for y = -5, 0 do placed["20," .. y .. ",0"] = "default:water_source" end
		placed["20,1,0"] = top_node
	end
	local function clear()
		for y = -5, 1 do placed["20," .. y .. ",0"] = nil end
	end
	local sailor2 = make_player("deep_sailor", "accord", "human")
	sailor2.meta["grug_mounts:water_tier"] = 6
	local function try_at(feet_y, label, expect_ok, expect_text, path)
		sailor2.pos = {x = 20, y = feet_y, z = 0}
		local ok, message
		if path == "toggle" then
			ok, message = grug_mounts.toggle(sailor2, 5)
		else
			ok, message = grug_mounts.mount(sailor2, 5)
		end
		eq(ok == true, expect_ok, "boat " .. label)
		if expect_text then
			check(type(message) == "string" and message:find(expect_text, 1, true) ~= nil,
				"boat " .. label .. ": " .. tostring(message))
		end
		if ok then
			near(grug_mounts.active.deep_sailor.object:get_pos().y, 0.5, "boat " .. label .. ": on the surface")
			grug_mounts.dismount(sailor2, nil, true)
		end
	end
	column(nil)
	try_at(0.1, "feet in the top water node (swimming at the surface)", true)
	try_at(-0.5, "feet at the bottom of the top node", true)
	try_at(-0.9, "feet in the second node (one under the surface)", true, nil, "toggle")
	try_at(-1.4, "feet 1.9 under the surface (second node)", true)
	try_at(-1.6, "feet in the third node (2.1 under the surface)", false, "Swim up to the surface")
	try_at(-3, "feet four nodes down", false, "Swim up to the surface", "toggle")
	try_at(-5, "feet at the bottom of a six-deep column", false, "Swim up to the surface")
	column("default:ice")
	try_at(0.1, "under ice", false, "no open water surface")
	column("default:stone")
	try_at(-0.9, "under an overhang", false, "no open water surface")
	-- A re-summon from a boat (the other boat's button): the boat sits on the
	-- surface, so the rule holds there.
	column(nil)
	sailor2.pos = {x = 20, y = 0.1, z = 0}
	check(grug_mounts.mount(sailor2, 5), "the rowboat on the surface")
	local ok = grug_mounts.toggle(sailor2, 6)
	check(ok, "switching to the sailboat from the rowboat")
	eq(grug_mounts.active.deep_sailor and grug_mounts.active.deep_sailor.tier, 6, "the sailboat replaced it")
	grug_mounts.dismount(sailor2, nil, true)
	clear()
end

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R451 MC PORTABLE PASS checks=%d"):format(checks))
