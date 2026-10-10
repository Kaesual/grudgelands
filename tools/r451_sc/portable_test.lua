-- Release 0.45.1 lane SC portable test (LuaJIT): a reliable click with a
-- self or support skill selected (fix plan row 5, the user's playtest
-- finding of 2026-10-10: Ice Nova dropped about every third click at the
-- ground).
--
--   luajit tools/r451_sc/portable_test.lua [repo]
--
-- Loads the REAL grug_abilities/input.lua on a fake engine and drives it the
-- way the engine does: the press arrives at once as a native punch
-- (input.press, the node on_punch wrapper), the server step (0.09 s) runs
-- the input pass, and the release is only seen at the pass after the
-- client's control report. The skill list is read from the shipped
-- kits.lua and scout.lua, so every self and friendly skill is covered.
-- Every case prints one "CASE <id> <observed>" line and checks the rule:
--   W  a press at a node whose release the server sees 0.25-0.33 s later
--      casts, for every self and friendly skill; seen at 0.40 s it is a
--      hold and casts nothing;
--   A  the aimed node changes during the click (another node, air, a
--      hostile, an ally): the tap still casts, once;
--   H  a hold past the window digs (can_dig) and casts nothing, also when
--      the crosshair wandered;
--   N  the native dig guard: a completion inside the tap before 0.2 s is
--      refused (Creative's fast hand, the Round 20 limit) and the click
--      still casts; one at 0.3 s (the hand's dig_immediate time) is
--      accepted once, its original on_dig runs once and the release casts
--      nothing; a refused one past 0.2 s (protected ground) is a hold too;
--   X  a self skill pressed at an actor that is no target of its own (an
--      ally for Ice Nova, an NPC, a forbidden ally) fires once on the
--      fresh press; heals and hostile skills there act as before;
--   F  the food RMB press: a release seen within 0.35 s is the click, a
--      longer hold starts eating and eats one serving at 1.5 s;
--   T  the targeted (hostile) skills share no tap: at a node they dig at
--      once and a quick release casts nothing; at a mob they act at the
--      press; a self skill at air casts at the press, as before.
-- Prints "R451 SC PORTABLE PASS checks=<n>" or the failures.

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
-- vector (the subset input.lua uses).
------------------------------------------------------------------------------
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
-- The shipped skill list: id, kind, target_kind and the input-relevant flags
-- of every registration in kits.lua and scout.lua (the header of each block,
-- before its first function).
------------------------------------------------------------------------------
local defs = {}
for _, file in ipairs({"kits.lua", "scout.lua"}) do
	local f = assert(io.open(ROOT .. "/mods/PLAYER/grug_abilities/" .. file))
	local text = f:read("*a")
	f:close()
	for block in text:gmatch("register_ability%((.-)\n}%)") do
		local head = block:match("^(.-)function") or block
		local id = head:match('id = "([%w_]+)"')
		if id then
			defs[id] = {id = id, name = id, kind = head:match('kind = "(%w+)"'),
				target_kind = head:match('target_kind = "(%w+)"'),
				offensive = head:match("offensive = true") ~= nil,
				repeat_policy = head:match('repeat_policy = "(%w+)"')}
		end
	end
end
local support_ids = {}
for id, def in pairs(defs) do
	if def.kind == "cast" and (def.target_kind == "self" or def.target_kind == "friendly") then
		support_ids[#support_ids + 1] = id
	end
end
table.sort(support_ids)
check(#support_ids >= 9 and defs.ice_nova and defs.ice_nova.target_kind == "self" and
	defs.ice_nova.offensive and defs.heal and defs.heal.target_kind == "friendly" and
	defs.fireball and defs.fireball.target_kind == "hostile",
	"setup: the shipped skill list reads (" .. table.concat(support_ids, ",") .. ")")
defs.strike = defs.strike or {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike"}

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local clock = 1000000000
local hits = {}
local casts, swings, flashes, dug = {}, {}, {}, {}
local mods_loaded = {}
local protected, violations = nil, 0 -- protected: the x of protected nodes
local mob = {get_luaentity = function() return {name = "test:mob"} end,
	get_pos = function() return vector.new(0, 1, 2) end, is_player = function() return false end}
local ally = {get_luaentity = function() return nil end,
	get_pos = function() return vector.new(0, 1, 2) end, is_player = function() return true end}
-- An NPC (no target for anyone) and an ally the PvP flag forbids supporting.
local npc = {get_luaentity = function() return {name = "test:npc"} end,
	get_pos = function() return vector.new(0, 1, 2) end, is_player = function() return false end}
local refused = {get_luaentity = function() return nil end,
	get_pos = function() return vector.new(0, 1, 2) end, is_player = function() return true end}
-- grug_food, as input.lua reaches it (rawget): what the food press did.
local food_log = {}
grug_food = {
	is_food = function(name) return name == "test:bread" end,
	begin_hold = function() food_log[#food_log + 1] = "begin"; return true end,
	step_hold = function() end,
	consume_held = function() food_log[#food_log + 1] = "eat" end,
	end_hold = function() end,
	click = function(_, target) food_log[#food_log + 1] = "click:" .. target.type end,
}

local function node_def(groups)
	return {walkable = true, groups = groups,
		on_dig = function(pos) dug[#dug + 1] = pos.x .. "," .. pos.y .. "," .. pos.z; return true end,
		on_punch = function() end}
end
core = {
	registered_nodes = {["test:dirt"] = node_def({crumbly = 3}), ["test:torch"] = node_def({dig_immediate = 3})},
	registered_entities = {["__builtin:item"] = {on_punch = function() end}},
	get_us_time = function() return clock end,
	check_player_privs = function() return true end,
	get_node_or_nil = function(pos) return {name = pos.x == 1 and "test:torch" or "test:dirt"} end,
	is_protected = function(pos) return protected == pos.x end,
	record_protection_violation = function() violations = violations + 1 end,
	get_dig_params = function(groups) return {diggable = (groups.crumbly or groups.dig_immediate) ~= nil} end,
	get_item_group = function() return 0 end,
	raycast = function()
		local i = 0
		return function() i = i + 1; return hits[i] end
	end,
	override_item = function(name, changes)
		local def = core.registered_nodes[name]
		if def then for k, v in pairs(changes) do def[k] = v end end
	end,
	register_on_mods_loaded = function(f) mods_loaded[#mods_loaded + 1] = f end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_joinplayer = function() end,
}
function ItemStack()
	return {get_name = function() return "" end, get_tool_capabilities = function() return {groupcaps = {}} end,
		get_meta = function() return {get_string = function() return "" end, set_string = function() end} end}
end
grug_core = {
	combat_eye_pos = function() return vector.new(0, 1.47, 0) end,
	combat_actor = function(ref) return ref end,
	aim_raycast = function(o, d, liquids) return core.raycast(o, d, true, liquids) end,
	unseen_by = function() return false end,
	is_stunned = function() return false end,
	player_has_live_mount = function() return false end,
	register_on_stun = function() end,
	combat_ray = function()
		for _, hit in ipairs(hits) do
			if hit.type == "node" then return {status = "aim_miss", reason = "node"} end
			if hit.ref == mob then
				return {status = "target", reason = "hostile", target = mob, distance = 2, pointed = hit}
			end
			return {status = "aim_miss", reason = "object", target = hit.ref, distance = 2, pointed = hit}
		end
		return {status = "aim_miss", reason = "empty"}
	end,
}
local cooldown_until = {}
grug_abilities = {
	registered = defs,
	is_unlocked = function() return true end,
	get_range = function() return 20 end,
	valid_target = function(_, ref, kind)
		return (ref == mob and kind == "hostile") or (ref == ally and kind == "friendly")
	end,
	evading_target = function() return false end,
	support_refused = function(_, ref) return ref == refused end,
	flash = function(_, msg) flashes[#flashes + 1] = msg end,
	cancel_bow_draw = function() end,
	try_cast = function(_, def)
		casts[#casts + 1] = def.id
		cooldown_until[def.id] = clock + 1000000
		return true
	end,
}
local wielded = "strike"
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
	selected = function() return defs[wielded] end,
	swing = function(_, def) swings[#swings + 1] = def.id end,
	cast_refusal = function(_, def)
		return cooldown_until[def.id] and clock < cooldown_until[def.id] and "not ready" or nil
	end,
	swing_refusal = function() return nil end,
	delay_strike = function() end,
	within_hand_reach = function() return true end,
})
for _, f in ipairs(mods_loaded) do f() end

local controls = {dig = false, place = false}
local player = {
	get_player_name = function() return "p" end,
	get_player_control = function() return controls end,
	get_inventory = function() return nil end,
	get_wield_list = function() return "main" end,
	get_wield_index = function() return 1 end,
	get_wielded_item = function()
		local name = wielded:find(":", 1, true) and wielded or "grug_abilities:" .. wielded
		return {get_name = function() return name end}
	end,
	set_wielded_item = function() return true end,
	get_hp = function() return 20 end,
	get_pos = function() return vector.new(0, 0, 0) end,
	get_look_dir = function() return vector.new(0, 0, 1) end,
	is_player = function() return true end,
}

local NODE = {type = "node", under = vector.new(0, 1, 2), above = vector.new(0, 1, 1),
	intersection_point = vector.new(0, 1.47, 1.5)}
local NODE2 = {type = "node", under = vector.new(0, 0, 2), above = vector.new(0, 1, 2),
	intersection_point = vector.new(0, 1, 1.8)}
local TORCH = {type = "node", under = vector.new(1, 1, 2), above = vector.new(1, 1, 1),
	intersection_point = vector.new(0.5, 1.47, 1.5)}
local function at(ref) return {type = "object", ref = ref, intersection_point = vector.new(0, 1.47, 1)} end
local function aim(...) hits = {...} end

local STEP_US = 90000 -- dedicated_server_step: one input pass per server step
local pressed_at
local function pass() input.step(player) end
-- A fresh selection, every cooldown over, nothing pressed.
local function select(id)
	wielded = id
	controls.dig, controls.place = false, false
	clock = clock + 5000000
	pass()
	casts, swings, flashes, dug = {}, {}, {}, {}
end
-- The press: the native punch at the node arrives with its controls.
local function press()
	controls.dig = true
	pressed_at = clock
	input.press(player)
end
-- Server passes while held, until (not including) `ms` after the press.
local function held_until(ms)
	while clock + STEP_US < pressed_at + ms * 1000 do
		clock = clock + STEP_US
		pass()
	end
end
-- The release the server sees at the input pass `ms` after the press.
local function release_seen(ms)
	held_until(ms)
	clock = pressed_at + ms * 1000
	controls.dig = false
	pass()
end
-- The engine's dig completion at `ms` after the press: the node's on_dig.
local function complete_dig(hit, ms)
	held_until(ms)
	clock = pressed_at + ms * 1000
	local pos = hit.under
	local name = core.get_node_or_nil(pos).name
	core.registered_nodes[name].on_dig(pos, {name = name}, player)
end
local function can_dig(hit)
	return input.can_dig(player, (hit or NODE).under, core.get_node_or_nil((hit or NODE).under))
end
local function list(t) return #t > 0 and table.concat(t, ",") or "-" end

------------------------------------------------------------------------------
-- W: the window, for every self and friendly skill.
------------------------------------------------------------------------------
for _, id in ipairs(support_ids) do
	local seen = {}
	for _, ms in ipairs({120, 250, 290, 330, 400}) do
		select(id)
		aim(NODE)
		press()
		release_seen(ms)
		seen[#seen + 1] = ms .. "ms:" .. #casts
		if ms < 350 then
			check(#casts == 1 and casts[1] == id, "W " .. id .. " released, seen after " .. ms .. " ms: one cast")
		else
			check(#casts == 0, "W " .. id .. " released, seen after " .. ms .. " ms: a hold, no cast")
		end
	end
	case("W", id .. " (" .. defs[id].target_kind .. (defs[id].offensive and ", offensive" or "") ..
		") at a node, casts by release delay: " .. table.concat(seen, " "))
end

------------------------------------------------------------------------------
-- A: the aimed node changes during the click.
------------------------------------------------------------------------------
for _, id in ipairs(support_ids) do
	local seen = {}
	for _, path in ipairs({{"node", NODE2}, {"air"}, {"hostile", at(mob), NODE}, {"ally", at(ally), NODE}}) do
		select(id)
		aim(NODE)
		press()
		held_until(100)
		aim(unpack(path, 2))
		release_seen(290)
		seen[#seen + 1] = path[1] .. ":" .. list(casts)
		check(#casts == 1 and casts[1] == id and #swings == 0,
			"A " .. id .. " NODE -> " .. path[1] .. " during the click: one cast (" .. list(casts) .. ")")
	end
	case("A", id .. " aim moved during the click: " .. table.concat(seen, " "))
end

------------------------------------------------------------------------------
-- H: a hold past the window digs and casts nothing.
------------------------------------------------------------------------------
for _, id in ipairs({"ice_nova", "blink", "heal"}) do
	select(id)
	aim(NODE)
	press()
	local early = can_dig()
	held_until(380)
	local later = can_dig()
	aim(NODE2) -- the crosshair wanders on in the hold: the new node digs
	clock = clock + STEP_US
	pass()
	local wandered = can_dig(NODE2)
	release_seen(800)
	case("H", id .. " held 0.8 s: dig at press=" .. tostring(early) .. " after the window=" ..
		tostring(later) .. " wandered=" .. tostring(wandered) .. " casts=" .. list(casts))
	check(not early and later and wandered and #casts == 0,
		"H " .. id .. ": the tap holds the dig, the hold digs, nothing is cast")
end

------------------------------------------------------------------------------
-- N: the native dig guard against the tap.
------------------------------------------------------------------------------
do
	select("ice_nova")
	aim(TORCH)
	press()
	complete_dig(TORCH, 164) -- Creative's fast hand
	local refused = #dug == 0
	release_seen(250)
	case("N1", "Ice Nova, a dig completed after 0.164 s, released: dug=" .. #dug .. " casts=" .. list(casts))
	check(refused and #dug == 0 and list(casts) == "ice_nova",
		"N1 a completion before 0.2 s is refused and the click still casts")

	select("ice_nova")
	aim(TORCH)
	press()
	complete_dig(TORCH, 300) -- the hand's dig_immediate time
	release_seen(330)
	case("N2", "Ice Nova, a dig completed after 0.3 s, released: dug=" .. #dug .. " casts=" .. list(casts))
	check(#dug == 1 and #casts == 0, "N2 a completion at 0.3 s is accepted once and ends the tap as a hold")

	select("blink")
	aim(NODE)
	press()
	release_seen(250)
	complete_dig(NODE, 260) -- a stray completion after the release: no press holds it
	check(#casts == 1 and #dug == 0, "N3 no dig after the tap's release")

	-- A protected torch in a town: the completion is refused (the hint), and
	-- it still proves the hold, so the release casts nothing.
	protected, violations = 1, 0
	select("blink")
	aim(TORCH)
	press()
	complete_dig(TORCH, 300)
	release_seen(330)
	case("N4", "Blink on a protected torch, refused completion after 0.3 s, released: dug=" .. #dug ..
		" violations=" .. violations .. " casts=" .. list(casts))
	check(#dug == 0 and violations == 1 and #casts == 0,
		"N4 a refused completion past 0.2 s is a hold too: the hint, no cast")
	-- A quick tap there still casts (Blink in a town).
	select("blink")
	aim(TORCH)
	press()
	release_seen(250)
	check(list(casts) == "blink" and #dug == 0, "N4 a tap on protected ground casts")
	protected = nil
end

------------------------------------------------------------------------------
-- X: a self skill at an actor that is no target of its own (0.45.1, the
-- user's answers): it fires once on the fresh press; heals unchanged.
------------------------------------------------------------------------------
local function fresh_at(id, ref)
	select(id)
	aim(at(ref), NODE)
	press()
	local at_press = list(casts)
	held_until(800)
	local held = list(casts)
	release_seen(800)
	return at_press, held, list(casts)
end
do
	local p, h, r = fresh_at("ice_nova", ally)
	case("X1", "Ice Nova at an ally: press=" .. p .. " held=" .. h .. " released=" .. r)
	check(p == "ice_nova" and r == "ice_nova", "X1 Ice Nova at an ally fires once on the fresh press")
	p, h, r = fresh_at("blink", ally)
	check(p == "blink" and r == "blink", "X1 Blink at an ally fires once, as before")
	p, h, r = fresh_at("heal", ally)
	check(p == "heal", "X1 Heal at an ally heals it, as before")
	for _, id in ipairs(support_ids) do
		p, h, r = fresh_at(id, npc)
		case("X2", id .. " at an NPC: press=" .. p .. " released=" .. r)
		if defs[id].target_kind == "self" then
			check(p == id and r == id, "X2 " .. id .. " at an NPC fires once on the fresh press")
		else
			check(r == "-", "X2 " .. id .. " at an NPC does nothing, as before")
		end
		p, h, r = fresh_at(id, refused)
		check(p == id and r == id, "X3 " .. id .. " at a forbidden ally: one attempt on the fresh press " ..
			"(a heal refuses inside try_cast)")
	end
	p, h, r = fresh_at("fireball", npc)
	check(r == "-" and #swings == 0, "X4 a hostile skill at an NPC does nothing, as before")
end

------------------------------------------------------------------------------
-- F: the food RMB click or hold, the same window (0.45.1).
------------------------------------------------------------------------------
local function food_press(ms)
	wielded = "test:bread"
	controls.dig, controls.place = false, false
	clock = clock + 5000000
	pass()
	food_log = {}
	aim(NODE)
	controls.place = true
	pressed_at = clock
	input.food_native(player, {type = "node", under = NODE.under, above = NODE.above})
	held_until(ms)
	clock = pressed_at + ms * 1000
	controls.place = false
	pass()
	return list(food_log)
end
do
	local seen = {}
	for _, ms in ipairs({120, 250, 330, 400, 1700}) do
		local log = food_press(ms)
		seen[#seen + 1] = ms .. "ms:" .. log
		if ms < 350 then
			check(log == "click:node", "F food released, seen after " .. ms .. " ms: the click (" .. log .. ")")
		elseif ms < 1500 then
			check(log == "begin", "F food released, seen after " .. ms .. " ms: a hold, no click, no eating (" ..
				log .. ")")
		else
			check(log == "begin,eat", "F food held 1.7 s: eats one serving (" .. log .. ")")
		end
	end
	case("F", "food RMB by release delay: " .. table.concat(seen, " "))
end

------------------------------------------------------------------------------
-- T: the targeted skills and air, unchanged.
------------------------------------------------------------------------------
do
	select("fireball")
	aim(NODE)
	press()
	local digs = can_dig()
	release_seen(250)
	case("T1", "Fireball at a node, released after 0.25 s: dig at press=" .. tostring(digs) ..
		" casts=" .. list(casts))
	check(digs and #casts == 0, "T1 a hostile skill digs at once and has no tap")

	select("fireball")
	aim(at(mob), NODE)
	press()
	release_seen(250)
	check(list(casts) == "fireball", "T2 a hostile skill at a mob casts at the press")

	select("ice_nova")
	aim()
	press()
	local at_press = list(casts)
	release_seen(250)
	case("T3", "Ice Nova at air: at the press=" .. at_press .. " after the release=" .. list(casts))
	check(at_press == "ice_nova" and list(casts) == "ice_nova", "T3 a self skill at air casts once at the press")
end

if failures == 0 then
	print("R451 SC PORTABLE PASS checks=" .. checks)
else
	error(("R451 SC PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
