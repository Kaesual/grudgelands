-- 0.49.1 lane DROP portable test (LuaJIT): drops that a client draws sliding
-- and cannot pick up.
--
--   luajit tools/r491_drop/portable_test.lua [repo]
--
-- The cause (tools/r491_drop/repro.sh, a real client over a lossy link): a
-- drop's stop is one unreliable position update; a client that loses it keeps
-- the flight's sideways velocity and draws the drop sliding on, while the
-- server's copy lies still, and the press's server ray never finds the drop
-- the player clicks.
--   A  the item entity (the REAL mods/BASE/default/item_entity.lua over a
--      fake builtin item): a drop coming to rest sends its position twice
--      more, 0.5 s and 2 s after the rest, then never again; a drop sliding
--      on ice is sent once it stops; an attached item, an item removed in
--      its step and an item lying still from the start send nothing;
--   B  the press (the REAL mods/PLAYER/grug_abilities/input.lua on a fake
--      engine, the pattern of tools/r36_f2): the plain drop on flat ground
--      is picked up at once by the press, exactly once; a punched drop the
--      server ray misses is picked up within the engine's reach and not
--      beyond it; a combat press still goes through the loot; a held repeat
--      and a press without a punch pick up nothing; without a skill the
--      native pickup runs.
-- Every case prints one "CASE <id> <observed>" line (a run on the old files,
-- with arg[1] a copy of them, gives the "before" column). Prints
-- "R491 DROP PORTABLE PASS checks=<n>" or the failures.

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

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.distance(a, b)
	local d = vector.subtract(a, b)
	return math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
end
function table.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

------------------------------------------------------------------------------
-- A: the item entity.
------------------------------------------------------------------------------
do
	local builtin_moving -- what the fake builtin step sets moving_state to
	local builtin_removes = false
	local builtin = {
		set_item = function() end,
		on_step = function(self, _, moveresult)
			if builtin_removes then self.object.removed = true end
			if moveresult and moveresult.collides and builtin_moving ~= nil then
				self.moving_state = builtin_moving
			end
		end,
	}
	local registered
	minetest = {
		registered_entities = {["__builtin:item"] = builtin},
		registered_items = {},
		features = {},
		register_entity = function(_, def) registered = def end,
		log = function() end,
	}
	dofile(ROOT .. "/mods/BASE/default/item_entity.lua")
	minetest = nil
	check(registered ~= nil, "A item_entity.lua registers the item")

	local function new_item()
		local obj = {pos = vector.new(1, 2, 3), sends = {}, clock = 0}
		function obj:get_pos() return not self.removed and vector.copy(self.pos) or nil end
		function obj:set_pos(p)
			self.sends[#self.sends + 1] = {t = self.clock, pos = vector.copy(p)}
		end
		return setmetatable({object = obj, moving_state = true}, {__index = registered})
	end
	local DT = 0.09
	local AIR, GROUND = {collides = false}, {collides = true}
	local function run(e, n, moveresult)
		for _ = 1, n do
			e.object.clock = e.object.clock + DT
			e:on_step(DT, moveresult)
		end
	end
	local function times(e)
		local out = {}
		for i, s in ipairs(e.object.sends) do out[i] = ("%.2f"):format(s.t) end
		return #out > 0 and table.concat(out, ",") or "-"
	end

	do -- A1 a mob drop: about a second in the air, then at rest for 5 s.
		local e = new_item()
		builtin_moving = false
		run(e, 12, AIR)
		local landed = e.object.clock + DT
		run(e, 56, GROUND)
		local sends = e.object.sends
		case("A1", "flight 1.1 s, rest 5 s: resends at " .. times(e) .. (" (landed %.2f)"):format(landed))
		check(#sends == 2, "A1 two resends after the landing")
		check(sends[1] and sends[1].t - landed >= 0.5 - 1e-9 and sends[1].t - landed < 0.5 + DT,
			"A1 the first 0.5 s after the rest")
		check(sends[2] and sends[2].t - landed >= 2 - 1e-9 and sends[2].t - landed < 2 + DT,
			"A1 the second 2 s after the rest")
		check(sends[1] and vector.distance(sends[1].pos, e.object.pos) == 0,
			"A1 a resend keeps the drop where it lies")
		check(e._grug_resync == nil and e._grug_unsettled == nil, "A1 nothing pending afterwards")
	end

	do -- A2 a drop lying still from the start sends nothing.
		local e = new_item()
		e.moving_state = false
		builtin_moving = false
		run(e, 40, GROUND)
		case("A2", "still from the start: resends " .. #e.object.sends)
		check(#e.object.sends == 0, "A2 no resend for a drop that never moved")
	end

	do -- A3 sliding on ice: the resends count from the stop, not the landing.
		local e = new_item()
		run(e, 8, AIR)
		builtin_moving = true
		run(e, 30, GROUND) -- sliding, 2.7 s
		local slid = #e.object.sends
		builtin_moving = false
		local stopped = e.object.clock + DT
		run(e, 30, GROUND)
		local s = e.object.sends
		case("A3", ("ice: resends while sliding %d, after the stop at %s"):format(slid, times(e)))
		check(slid == 0, "A3 nothing while it slides (the engine sends a moving item)")
		check(#s == 2 and s[1].t - stopped >= 0.5 - 1e-9 and s[2].t - stopped >= 2 - 1e-9,
			"A3 two resends from the stop")
	end

	do -- A4 a second landing (the node below dug) resends again.
		local e = new_item()
		builtin_moving = false
		run(e, 10, AIR)
		run(e, 30, GROUND)
		run(e, 5, AIR)
		run(e, 30, GROUND)
		case("A4", "two landings: resends " .. #e.object.sends)
		check(#e.object.sends == 4, "A4 two resends per landing")
	end

	do -- A5 attached (no moveresult) and removed in the step: nothing, no error.
		local e = new_item()
		run(e, 20, nil)
		local attached = #e.object.sends
		local r = new_item()
		builtin_moving = false
		run(r, 10, AIR)
		run(r, 1, GROUND)
		builtin_removes = true
		local ok = pcall(run, r, 30, GROUND)
		builtin_removes = false
		case("A5", ("attached: resends %d; removed: ok=%s resends %d"):format(attached,
			tostring(ok), #r.object.sends))
		check(attached == 0, "A5 an attached item sends nothing")
		check(ok and #r.object.sends == 0, "A5 a removed item sends nothing and raises nothing")
	end
end

------------------------------------------------------------------------------
-- B: the press (fake engine as in tools/r36_f2).
------------------------------------------------------------------------------
local EYE = vector.new(0, 1.47, 0)
local clock = 0
local hits = {}
local swings, casts, pickups = {}, {}, {}
local loaded = {}

local function new_mob()
	local m = {kind = "mob"}
	function m:get_pos() return vector.new(0, 1, 2) end
	function m:is_player() return false end
	function m:get_luaentity() return {name = "test:mob", health = 10, _cmi_is_mob = true, temp = {}} end
	return m
end
-- A drop: its server ObjectRef and its luaentity (what on_punch receives).
local function new_drop(z)
	local ref = {kind = "drop", z = z}
	local ent = {name = "__builtin:item", object = ref}
	function ref:get_pos() return vector.new(0, 0.3, self.z) end
	function ref:is_player() return false end
	function ref:get_luaentity() return ent end
	return ref, ent
end

core = {
	registered_nodes = {["test:dirt"] = {walkable = true, groups = {crumbly = 3}}},
	registered_entities = {
		["__builtin:item"] = {on_punch = function(ent) pickups[#pickups + 1] = ent end},
	},
	get_us_time = function() return clock end,
	check_player_privs = function() return true end,
	get_node_or_nil = function() return {name = "test:dirt"} end,
	is_protected = function() return false end,
	get_dig_params = function(groups) return {diggable = groups.crumbly ~= nil} end,
	get_item_group = function(name, group)
		return group == "grug_ability" and name:sub(1, 15) == "grug_abilities:" and 1 or 0
	end,
	raycast = function()
		local i = 0
		return function()
			i = i + 1
			return hits[i]
		end
	end,
	override_item = function() end,
	register_on_mods_loaded = function(f) loaded[#loaded + 1] = f end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_joinplayer = function() end,
}
local function new_stack(name)
	local st = {name = name or "", meta = {}}
	function st:get_name() return self.name end
	function st:get_tool_capabilities() return {} end
	function st:get_meta()
		local m = self.meta
		return {
			get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) if v == "" then m[k] = nil else m[k] = v end end,
		}
	end
	return st
end
function ItemStack(name) return new_stack(type(name) == "string" and name or "") end

local wielded = "grug_abilities:strike"
local inventory = {
	get_stack = function() return new_stack(wielded) end,
	set_stack = function() end,
	get_list = function() return {new_stack(wielded)} end,
}
grug_mobs = {evade_notice = function() end}
grug_core = {
	combat_eye_pos = function() return vector.copy(EYE) end,
	combat_actor = function(ref) return ref end,
	aim_raycast = function(o, d, liquids) return core.raycast(o, d, true, liquids) end,
	unseen_by = function() return false end,
	is_stunned = function() return false end,
	player_has_live_mount = function() return false end,
	register_on_stun = function() end,
	-- dropped items are passed through, a walkable node ends the ray
	combat_ray = function(_, range)
		for _, hit in ipairs(hits) do
			local d = vector.distance(EYE, hit.intersection_point)
			if hit.type == "node" then
				return {status = "aim_miss", reason = "node"}
			elseif hit.ref.kind ~= "drop" then
				local r = {target = hit.ref, distance = d, pointed = hit, status = "aim_miss", reason = "object"}
				if d > range then r.reason = "out_of_range"
				elseif hit.ref.kind == "mob" then r.status, r.reason = "target", "hostile" end
				return r
			end
		end
		return {status = "aim_miss", reason = "empty"}
	end,
}
local defs = {
	strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike"},
	heal = {id = "heal", kind = "cast", target_kind = "friendly", name = "Heal"},
}
grug_abilities = {
	registered = defs,
	is_unlocked = function() return true end,
	get_range = function() return 3 end,
	valid_target = function(_, ref, kind)
		return kind == "hostile" and ref.kind == "mob"
	end,
	evading_target = function() return false end,
	support_refused = function() return false end,
	flash = function() end,
	cancel_bow_draw = function() end,
	start_bow_draw = function() return true end,
	try_cast = function(_, def) casts[#casts + 1] = def.id; return true end,
}
local function wielded_def()
	return wielded:sub(1, 15) == "grug_abilities:" and defs[wielded:sub(16)] or nil
end
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
	selected = function() return wielded_def() end,
	swing = function(_, def) swings[#swings + 1] = def.id end,
	cast_refusal = function() return nil end,
	swing_refusal = function() return nil end,
	delay_strike = function() end,
	within_hand_reach = function() return true end,
})
for _, f in ipairs(loaded) do f() end
local item_punch = core.registered_entities["__builtin:item"].on_punch

local controls = {dig = false, place = false}
local player = {
	get_player_name = function() return "p" end,
	get_player_control = function() return controls end,
	get_inventory = function() return inventory end,
	get_wield_list = function() return "main" end,
	get_wield_index = function() return 1 end,
	get_wielded_item = function() return new_stack(wielded) end,
	set_wielded_item = function() return true end,
	get_hp = function() return 20 end,
	get_pos = function() return vector.new(0, 0, 0) end,
	get_look_dir = function() return vector.new(0, -0.6, 0.8) end,
	is_player = function() return true end,
}
-- The ground under and behind the drop (the ray misses a drop it passes over).
local GROUND = {type = "node", under = vector.new(0, -1, 2), above = vector.new(0, 0, 2),
	intersection_point = vector.new(0, -0.5, 2.6)}
local function at(ref) return {type = "object", ref = ref, intersection_point = ref:get_pos()} end
local function aim(...) hits = {...} end
local function step() clock = clock + 50000; input.step(player) end
local function release() controls.dig = false; for _ = 1, 4 do step() end end
local function reset()
	controls.dig = false
	clock = clock + 60000000
	for _ = 1, 4 do step() end
	swings, casts, pickups = {}, {}, {}
end
-- The client's click on a drop: the native punch, the button reported with it.
local function click(ent) controls.dig = true; item_punch(ent, player) end
local function seen()
	return ("pickups=%d swings=%d casts=%d"):format(#pickups, #swings, #casts)
end

do -- B1 the plain case: a drop on flat ground under the crosshair.
	reset()
	local ref, ent = new_drop(2)
	aim(at(ref), GROUND)
	click(ent)
	local first = #pickups
	for _ = 1, 4 do step() end
	click(ent) -- the client repeats its punch while the button is held
	case("B1", "flat ground, ray on the drop: " .. seen())
	check(first == 1 and pickups[1] == ent, "B1 picked up by the press itself, at once")
	check(#pickups == 1 and #swings == 0, "B1 exactly once, nothing else")
	release()
end

do -- B2 the server ray misses the drop the client drew (it slid there).
	reset()
	local ref, ent = new_drop(2.5)
	aim(GROUND)
	click(ent)
	case("B2", "punched drop, ray misses it (2.6 m): " .. seen())
	check(#pickups == 1 and pickups[1] == ent, "B2 the punched drop is picked up")
	check(#swings == 0 and #casts == 0, "B2 nothing else")
	release()
end

do -- B3 ... but not beyond the engine's own reach (4 + 2.6 m).
	reset()
	local ref, ent = new_drop(7)
	aim(GROUND)
	click(ent)
	case("B3", "punched drop 7 m away, ray misses: " .. seen())
	check(#pickups == 0, "B3 no pickup beyond 6.6 m")
	release()
end

do -- B4 loot never hides a hostile: a combat press goes through the loot.
	reset()
	local ref, ent = new_drop(1.5)
	aim(at(ref), at(new_mob()), GROUND)
	click(ent)
	case("B4", "punched drop with a hostile behind it: " .. seen())
	check(#pickups == 0 and #swings == 1, "B4 the press attacks, no pickup")
	release()
end

do -- B5 a held press reaching a punched drop picks up nothing.
	reset()
	aim(GROUND)
	controls.dig = true
	step() -- the press began on the ground (no punch)
	step()
	local ref, ent = new_drop(2)
	item_punch(ent, player)
	case("B5", "held press, then a punch on a drop: " .. seen())
	check(#pickups == 0, "B5 no pickup from a held press")
	release()
end

do -- B6 a press without a punch at a drop the ray misses picks up nothing.
	reset()
	aim(GROUND)
	controls.dig = true
	step()
	case("B6", "press without a punch, ray misses: " .. seen())
	check(#pickups == 0, "B6 no pickup without a punched drop")
	release()
end

do -- B7 a support skill: the punched drop is picked up, the skill not cast.
	reset()
	wielded = "grug_abilities:heal"
	local ref, ent = new_drop(2.5)
	aim(GROUND)
	click(ent)
	case("B7", "Heal selected, punched drop, ray misses: " .. seen())
	check(#pickups == 1 and #casts == 0, "B7 pickup, no cast")
	release()
	wielded = "grug_abilities:strike"
end

do -- B8 without a skill the native pickup runs (the wrapper delegates).
	reset()
	wielded = "test:pickaxe"
	local ref, ent = new_drop(2.5)
	aim(GROUND)
	item_punch(ent, player)
	case("B8", "no skill selected: " .. seen())
	check(#pickups == 1, "B8 native pickup")
	wielded = "grug_abilities:strike"
	release()
end

if failures == 0 then
	print("R491 DROP PORTABLE PASS checks=" .. checks)
else
	error(("R491 DROP PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
