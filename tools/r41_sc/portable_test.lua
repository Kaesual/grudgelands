-- Round 41 lane SC portable test (LuaJIT): the bow's missed release
-- (round41-plan.md §2 ruling 5, §4.3).
--
--   luajit tools/r41_sc/portable_test.lua [repo]
--
-- Loads the REAL grug_abilities/input.lua and scout.lua on a fake engine and
-- drives a Scout with Loose wielded the way the engine does: the control
-- state the server sees once per server step (0.09 s), and the native item
-- call (init.lua's on_place / on_secondary_use -> input.right_native) that
-- the client sends on a press edge. Every case prints one
-- "CASE <id> <observed>" line and checks the rule:
--   T  a tap from rest fires one weak arrow, as before the change, also when
--      it is released within the grace;
--   H  a second empty-air call during a live draw fires the drawn arrow at
--      once with the draw time it has, and the held button draws again; a
--      later release fires the second arrow;
--   G  a renewed draw released within 0.2 s (counted at the last step that
--      saw the button down) is cancelled silently: no arrow, no ammunition;
--      held past it, it fires; a further press inside the grace cancels
--      silently and draws again;
--   N  node calls (a press on a node, the engine's place repeats) never
--      count as a new press;
--   F  the first native call after a draw starts belongs to the starting
--      press, also when the draw began on the control state before it;
--   O  an object call counts like an empty-air call;
--   A  the last arrow: the shot fires, the new draw is refused with "You need
--      an arrow.";
--   R  the zero pointing range stays on through a renewal and is gone after
--      the release.
-- Prints "R41 SC PORTABLE PASS checks=<n>" or the failures.

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
local function case(id, observed) print(("CASE %-4s %s"):format(id, observed)) end

------------------------------------------------------------------------------
-- vector (the subset input.lua and scout.lua use).
------------------------------------------------------------------------------
vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local BOW = "grug_gear:bow_wood"
local STEP_US = 90000 -- dedicated_server_step: one control report, one pass
local clock = 1000000000
local globalsteps, loaded = {}, {}
local function noop() end

core = {
	registered_nodes = {},
	registered_entities = {["__builtin:item"] = {on_punch = noop}},
	registered_items = {
		[BOW] = {_grug_bow_draw_time = 2.5, inventory_image = "grug_gear_bow_wood.png"},
	},
	get_us_time = function() return clock end,
	check_player_privs = function() return true end,
	get_node_or_nil = function() return nil end,
	is_protected = function() return false end,
	get_item_group = function(name, group)
		return group == "grug_ability" and name:sub(1, 15) == "grug_abilities:" and 1 or 0
	end,
	override_item = noop,
	register_on_mods_loaded = function(f) loaded[#loaded + 1] = f end,
	register_globalstep = function(f) globalsteps[#globalsteps + 1] = f end,
	register_on_dieplayer = noop,
	register_on_leaveplayer = noop,
	register_on_joinplayer = noop,
}

local function new_stack(name, count)
	local st = {name = name or "", count = count or (name and name ~= "" and 1 or 0),
		wear = 0, meta = {}}
	function st:get_name() return self.name end
	function st:get_count() return self.count end
	function st:is_empty() return self.name == "" or self.count <= 0 end
	function st:get_wear() return self.wear end
	function st:set_wear(w) self.wear = w end
	function st:get_tool_capabilities() return {damage_groups = {fleshy = 10}} end
	function st:get_meta()
		local m = self.meta
		return {
			get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) if v == "" then m[k] = nil else m[k] = v end end,
		}
	end
	return st
end
local function copy_stack(st)
	local c = new_stack(st.name, st.count)
	c.wear = st.wear
	for k, v in pairs(st.meta) do c.meta[k] = v end
	return c
end
function ItemStack(name) return new_stack(type(name) == "string" and name or "") end

local main = {new_stack("grug_abilities:loose")}
local inventory = {
	get_stack = function(_, _, i) return copy_stack(main[i]) end,
	set_stack = function(_, _, i, st) main[i] = copy_stack(st) end,
	get_list = function()
		local out = {}
		for i, st in ipairs(main) do out[i] = copy_stack(st) end
		return out
	end,
}

local controls = {}
local player = {}
function player:get_player_name() return "scout" end
function player:get_player_control() return controls end
function player:get_inventory() return inventory end
function player:get_wield_list() return "main" end
function player:get_wield_index() return 1 end
function player:get_wielded_item() return copy_stack(main[1]) end
function player:set_wielded_item(st) main[1] = copy_stack(st); return true end
function player:get_hp() return 20 end
function player:get_pos() return vector.new(0, 0, 0) end
function player:get_look_dir() return vector.new(0, 0, 1) end
core.get_player_by_name = function(name) return name == "scout" and player or nil end

local ammo = 20
local shots, flashes = {}, {}

player_api = {register_control_animation_override = noop}
grug_core = setmetatable({
	is_stunned = function() return false end,
	player_has_live_mount = function() return false end,
	get_equipped_weapon = function() return new_stack(BOW) end,
	equipment_is_broken = function() return false end,
	combat_eye_pos = function() return vector.new(0, 1.47, 0) end,
	combat_actor = function(ref) return ref end,
	aim_raycast = function() return function() return nil end end,
	unseen_by = function() return false end,
	combat_ray = function() return {status = "aim_miss", reason = "empty"} end,
	set_move_stance = noop,
	clear_move_stance = noop,
	particles = {play = noop, facing = noop},
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
end})
grug_projectiles = {
	register = noop,
	spawn_batch = function(_, launches, consume)
		if not consume() then return false end
		for _, launch in ipairs(launches) do
			shots[#shots + 1] = {multiplier = launch.data.damage / 10, speed = launch.speed,
				at = clock}
		end
		return true
	end,
}
grug_inventory = {
	ammo_count = function() return ammo end,
	consume_ammo = function(_, count)
		if ammo < count then return false end
		ammo = ammo - count
		return true
	end,
	is_bow = function(st) return st ~= nil and st:get_name() == BOW end,
}
grug_classes = {
	get_talent_bonus = function() return 0 end,
	get_ranged_bonus = function() return 0 end,
	get_race_perk = function() return 0 end,
}
grug_gear = {strip_enchant = function(image) return image end}
grug_visuals = {resume_animation = noop}

local defs = {}
grug_abilities = {
	registered = defs,
	register_ability = function(def) defs[def.id] = def end,
	is_unlocked = function() return true end,
	get_range = function() return 25 end,
	valid_target = function() return false end,
	evading_target = function() return false end,
	support_refused = function() return false end,
	flash = function(_, message) flashes[#flashes + 1] = message end,
	delay_strike = noop,
	crosshair = {set_ring = noop},
}

dofile(ROOT .. "/mods/PLAYER/grug_abilities/scout.lua")
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
	selected = function(p)
		local name = p:get_wielded_item():get_name()
		return name:sub(1, 15) == "grug_abilities:" and defs[name:sub(16)] or nil
	end,
	swing = noop,
	cast_refusal = function() return nil end,
	swing_refusal = function() return nil end,
	delay_strike = noop,
	within_hand_reach = function() return true end,
})
grug_abilities.input = input
for _, f in ipairs(loaded) do f() end
check(defs.loose ~= nil and grug_abilities.renew_bow_draw ~= nil and input.right_native ~= nil,
	"setup: Loose, renew_bow_draw and right_native exist")

------------------------------------------------------------------------------
-- Driving it.
------------------------------------------------------------------------------
-- One server step: the contextual input pass first (init.lua registers it
-- before scout.lua's draw loop), then the draw loop.
local function step(n)
	for _ = 1, n or 1 do
		clock = clock + STEP_US
		input.step(player)
		for _, f in ipairs(globalsteps) do f(STEP_US / 1e6) end
	end
end
local AIR = {type = "nothing"}
local NODE = {type = "node", under = vector.new(0, 0, 3), above = vector.new(0, 1, 3)}
local MOB = {type = "object", ref = {}}
-- The engine's interact packet: its controls first, then the item callback.
local function native(pointed) input.right_native(player, pointed) end
local function down() controls = {place = true} end
local function up() controls = {} end
local function drawing() return grug_abilities.scout_draw_active(player) end
local function range0() return main[1].meta.range == "0" end
local function start(arrows)
	up()
	step(4)
	main = {new_stack("grug_abilities:loose")}
	ammo = arrows or 20
	shots, flashes = {}, {}
	clock = clock + 10000000
	step(2)
end
local function mult(i) return shots[i] and ("%.3f"):format(shots[i].multiplier) or "-" end
local function seen()
	return ("shots=%d ammo=%d drawing=%s zero=%s m1=%s m2=%s flashes=%s"):format(#shots, ammo,
		tostring(drawing()), tostring(range0()), mult(1), mult(2),
		#flashes > 0 and table.concat(flashes, "|") or "-")
end
local function expected(fraction)
	return grug_abilities.loose_draw_multiplier(fraction)
end
local function near(a, b) return a and b and math.abs(a - b) < 1e-6 end

------------------------------------------------------------------------------
-- T: a tap from rest behaves as before.
------------------------------------------------------------------------------
do -- T1 press and release one step later: one weak arrow.
	start()
	down(); native(AIR); local t0 = clock
	step()
	up(); step()
	case("T1", seen())
	check(#shots == 1 and ammo == 19 and not drawing(), "T1 a tap from rest fires one arrow")
	check(near(shots[1] and shots[1].multiplier, expected(2 * STEP_US / 2.5e6)),
		"T1 with the draw time it had (" .. mult(1) .. ")")
	check(clock - t0 < 200000, "T1 released within 0.2 s, still fired (no grace from rest)")
	check(not range0(), "T1 range restored")
end

do -- T2 the tap's press seen by the control state first, its call a step later.
	start()
	down(); step()
	native(AIR) -- the starting press's own call, late
	up(); step()
	case("T2", seen())
	check(#shots == 1 and ammo == 19, "T2 one arrow, the late call is the starting press's")
end

------------------------------------------------------------------------------
-- H: held, a missed release, held on.
------------------------------------------------------------------------------
do -- H1
	start()
	down(); native(AIR); local t0 = clock
	step(10) -- 0.9 s drawn
	check(#shots == 0 and drawing(), "H1 setup: drawing, nothing fired")
	native(AIR) -- release + press between two control reports
	local fired_at = clock
	case("H1a", seen())
	check(#shots == 1 and ammo == 19, "H1 the drawn arrow fires at once")
	check(near(shots[1] and shots[1].multiplier, expected((fired_at - t0) / 2.5e6)),
		"H1 with the draw time it had (" .. mult(1) .. ")")
	check(drawing() and range0(), "H1 the held button draws again at once, range still zero")
	step(10) -- held on 0.9 s
	up(); step()
	case("H1b", seen())
	check(#shots == 2 and ammo == 18 and not drawing(), "H1 the release fires the second arrow")
	check(near(shots[2] and shots[2].multiplier, expected(11 * STEP_US / 2.5e6)),
		"H1 the second draw counts from the new press (" .. mult(2) .. ")")
	check(not range0() and #flashes == 0, "H1 range restored, nothing reported")
end

------------------------------------------------------------------------------
-- G: the grace of a renewed draw.
------------------------------------------------------------------------------
do -- G1 a quick tap: the release reaches the server two steps after the press.
	start()
	down(); native(AIR)
	step(10)
	native(AIR) -- the tap's press
	step() -- still seen down (the release falls after this report)
	up(); step(); step()
	case("G1", seen())
	check(#shots == 1 and ammo == 19, "G1 one quick tap fires exactly one arrow, no ammunition for the second")
	check(not drawing() and not range0(), "G1 the renewed draw ended silently")
	check(#flashes == 0, "G1 nothing reported")
end

do -- G2 seen down for two steps (0.18 s) after the press: still inside the grace.
	start()
	down(); native(AIR)
	step(10)
	native(AIR)
	step(2)
	up(); step()
	case("G2", seen())
	check(#shots == 1 and ammo == 19 and not drawing(), "G2 0.18 s held: cancelled")
end

do -- G3 seen down for three steps (0.27 s): past the grace, a weak second arrow.
	start()
	down(); native(AIR)
	step(10)
	native(AIR)
	step(3)
	up(); step()
	case("G3", seen())
	check(#shots == 2 and ammo == 18, "G3 held past the grace: the renewed draw fires")
	check(near(shots[2] and shots[2].multiplier, expected(4 * STEP_US / 2.5e6)),
		"G3 with its own draw time up to the release report (" .. mult(2) .. ")")
end

do -- G4 two missed releases in a row: the second press falls in the grace.
	start()
	down(); native(AIR)
	step(10)
	native(AIR) -- first tap: fires the long draw
	step()
	native(AIR) -- second tap 0.09 s later: the renewed draw ends inside the grace
	case("G4a", seen())
	check(#shots == 1 and ammo == 19 and drawing(), "G4 no arrow from the cancelled draw, drawing again")
	step(10)
	up(); step()
	case("G4b", seen())
	check(#shots == 2 and ammo == 18, "G4 the held third draw fires on release")
end

------------------------------------------------------------------------------
-- N: node calls never count.
------------------------------------------------------------------------------
do -- N1 a press that began on a node, then place repeats during the draw.
	start()
	down(); native(NODE)
	step(3)
	native(NODE); step(3); native(NODE)
	case("N1a", seen())
	check(#shots == 0 and drawing(), "N1 node repeats fire nothing")
	native(AIR) -- a real new press after the node press
	case("N1b", seen())
	check(#shots == 1 and drawing(), "N1 an empty-air call after the node press is a new press")
	up(); step(4)
end

do -- N2 a node call as the second call: never a new press.
	start()
	down(); native(AIR)
	step(5)
	native(NODE)
	case("N2", seen())
	check(#shots == 0 and drawing(), "N2 a node call during a draw fires nothing")
	up(); step()
	check(#shots == 1, "N2 the release fires once")
end

------------------------------------------------------------------------------
-- F: the starting press's call.
------------------------------------------------------------------------------
do -- F1 the draw starts on the control state; its call arrives later.
	start()
	down(); step(3)
	check(drawing(), "F1 setup: the step started the draw")
	native(AIR)
	case("F1a", seen())
	check(#shots == 0 and drawing(), "F1 the late first call belongs to the starting press")
	step(3)
	native(AIR)
	case("F1b", seen())
	check(#shots == 1 and drawing(), "F1 the next call is a new press")
	up(); step(4)
end

------------------------------------------------------------------------------
-- O: an object call counts.
------------------------------------------------------------------------------
do -- O1
	start()
	down(); native(AIR)
	step(5)
	native(MOB)
	case("O1", seen())
	check(#shots == 1 and drawing(), "O1 an object call during a draw is a new press")
	up(); step(4)
end

------------------------------------------------------------------------------
-- A: the last arrow.
------------------------------------------------------------------------------
do -- A1
	start(1)
	down(); native(AIR)
	step(5)
	native(AIR)
	case("A1", seen())
	check(#shots == 1 and ammo == 0, "A1 the last arrow fires")
	check(not drawing() and not range0(), "A1 no new draw without arrows, range restored")
	check(flashes[1] == "You need an arrow.", "A1 the new press says why")
	up(); step(2)
	check(#shots == 1, "A1 nothing more on release")
end

------------------------------------------------------------------------------
-- R: release and new hold (no missed release) unchanged.
------------------------------------------------------------------------------
do -- R1 release seen, then a fresh press: two ordinary draws.
	start()
	down(); native(AIR)
	step(5)
	up(); step()
	down(); native(AIR)
	step(5)
	up(); step()
	case("R1", seen())
	check(#shots == 2 and ammo == 18, "R1 two seen releases, two arrows")
	check(near(shots[2] and shots[2].multiplier, expected(6 * STEP_US / 2.5e6)),
		"R1 the fresh press's draw has no grace and its full time (" .. mult(2) .. ")")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print("R41 SC PORTABLE PASS checks=" .. checks)
