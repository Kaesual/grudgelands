-- Round 36 Lane F2 portable test (LuaJIT): the held left button across a
-- hotbar switch (the user's playtest finding of 2026-10-05).
--
--   luajit tools/r36_f2/portable_test.lua [repo]
--
-- Loads the REAL grug_abilities/input.lua on a fake engine (the pattern of
-- tools/r32_f2) and drives a fake player whose wield index changes while the
-- button stays down. Every case prints one "CASE <id> <observed>" line (so a
-- run on the old input.lua gives the "before" column) and checks the rule:
-- a press held across a switch is the same press, decided again for the new
-- item as if it had been pressed with it: the key-down decision (gather or
-- combat), a combat lock keeps its foe while that foe is not gone for the new
-- item's reach, a self or support skill fires once where a fresh press
-- would, no tap is pending (the press began before the item), nothing is
-- reported (a held press stays quiet: refusals and "Evading"), clocks and
-- cooldowns stay, and digging goes on in both directions (can_dig accepts
-- the node the client keeps digging).
--   S  combat holds switched to every kind of item (attack cast and swing,
--      self, support, movement, the bow, a cooldown, a tool, an empty slot
--      and back, a miss beside the foe, an evading foe, a scroll through a
--      self skill, switching back to a skill on cooldown);
--   D  digging holds switched both ways (empty hand, a tool, attack, self
--      and support skills; a pending tap; a threat in the crosshair; air;
--      a dropped item);
--   K  what stays as it was: a carried right button, a stun, a switch in the
--      same step as a fresh press, the zero range on exactly one stack.
-- Prints "R36 F2 PORTABLE PASS checks=<n>" or the failures.

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

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local EYE = vector.new(0, 1.47, 0)
local clock = 0
local hits = {} -- what the next ray returns, nearest first
local swings, casts, flashes, notices, pickups = {}, {}, {}, 0, 0
local stunned = false
local cooldown_until = {} -- ability id -> clock until which it is not ready

local function new_mob(name)
	local m = {kind = "mob", health = 10, gone = false, name = name, z = 2}
	function m:get_pos() return not self.gone and vector.new(0, 1, self.z) or nil end
	function m:is_player() return false end
	function m:get_luaentity()
		if self.gone then return nil end
		return {name = "test:mob", health = self.health, _cmi_is_mob = true,
			temp = {grug_evading = self.evading}}
	end
	return m
end
local ally = {kind = "ally"}
function ally:get_pos() return vector.new(0, 1, 2) end
function ally:is_player() return true end
function ally:get_hp() return 20 end
function ally:get_luaentity() return nil end
local drop = {kind = "drop"}
function drop:get_pos() return vector.new(0, 1, 1) end
function drop:is_player() return false end
function drop:get_luaentity() return {name = "__builtin:item"} end

local function alive(ref)
	if not ref:get_pos() then return false end
	if ref:is_player() then return ref:get_hp() > 0 end
	local ent = ref:get_luaentity()
	return ent ~= nil and (ent.health or 0) > 0
end
local function hostile(ref) return ref.kind == "mob" and alive(ref) end

local loaded = {}
core = {
	registered_nodes = {
		["test:dirt"] = {walkable = true, groups = {crumbly = 3}},
	},
	registered_entities = {
		["__builtin:item"] = {on_punch = function() pickups = pickups + 1 end},
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

local function new_stack(name, meta)
	local st = {name = name or "", meta = {}}
	for k, v in pairs(meta or {}) do st.meta[k] = v end
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
local function copy_stack(st) return new_stack(st.name, st.meta) end
function ItemStack(name) return new_stack(type(name) == "string" and name or "") end

-- The hotbar: 1 Strike, 2 Fireball, 3 Ward, 4 Heal, 5 Blink, 6 Mighty Blow,
-- 7 Loose, 8 a pickaxe (an ordinary tool), 9 empty.
local SLOTS = {strike = 1, fireball = 2, ward = 3, heal = 4, blink = 5, mighty_blow = 6, loose = 7,
	tool = 8, empty = 9}
local main = {}
local function fill_hotbar()
	for id, i in pairs(SLOTS) do
		main[i] = new_stack(i <= 7 and "grug_abilities:" .. id or (id == "tool" and "test:pickaxe" or ""))
	end
end
fill_hotbar()
local wield_index = 1
local inventory = {
	get_stack = function(_, _, i) return copy_stack(main[i]) end,
	set_stack = function(_, _, i, st) main[i] = copy_stack(st) end,
	get_list = function()
		local out = {}
		for i, st in ipairs(main) do out[i] = copy_stack(st) end
		return out
	end,
}

grug_mobs = {evade_notice = function() notices = notices + 1 end}
grug_core = {
	combat_eye_pos = function() return vector.copy(EYE) end,
	combat_actor = function(ref) return ref end,
	aim_raycast = function(o, d, liquids) return core.raycast(o, d, true, liquids) end,
	unseen_by = function() return false end,
	is_stunned = function() return stunned end,
	player_has_live_mount = function() return false end,
	register_on_stun = function() end,
	-- The combat-ray rules over the same hit list (tools/r32_f2): dropped items
	-- are passed through, a walkable node ends the ray, the first actor is
	-- classified; a mob evading home is still reported as a target, as the
	-- real ray does (the predicate refuses it).
	combat_ray = function(_, range)
		for _, hit in ipairs(hits) do
			local d = vector.distance(EYE, hit.intersection_point)
			if hit.type == "node" then
				return {status = "aim_miss", reason = "node"}
			elseif hit.ref.kind ~= "drop" then
				local r = {target = hit.ref, distance = d, pointed = hit, status = "aim_miss", reason = "object"}
				if d > range then
					r.reason = "out_of_range"
				elseif hostile(hit.ref) then
					r.status, r.reason = "target", "hostile"
				end
				return r
			end
		end
		return {status = "aim_miss", reason = "empty"}
	end,
}

local defs = {
	strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike"},
	mighty_blow = {id = "mighty_blow", kind = "swing", target_kind = "hostile", name = "Mighty Blow"},
	fireball = {id = "fireball", kind = "cast", target_kind = "hostile", name = "Fireball", cooldown = 5},
	loose = {id = "loose", kind = "cast", target_kind = "hostile", name = "Loose"},
	ward = {id = "ward", kind = "cast", target_kind = "self", name = "Ward", cooldown = 20},
	heal = {id = "heal", kind = "cast", target_kind = "friendly", name = "Heal"},
	blink = {id = "blink", kind = "cast", target_kind = "self", name = "Blink", repeat_policy = "once",
		cooldown = 15},
}
local function ready(def) return not cooldown_until[def.id] or clock >= cooldown_until[def.id] end
grug_abilities = {
	registered = defs,
	is_unlocked = function() return true end,
	get_range = function(_, def) return def.id == "fireball" and 20 or 3 end,
	valid_target = function(_, ref, kind)
		if kind == "friendly" then return ref.kind == "ally" end
		return kind == "hostile" and hostile(ref) and not ref.evading
	end,
	evading_target = function(_, ref) return ref.kind == "mob" and alive(ref) and ref.evading == true end,
	support_refused = function() return false end,
	flash = function(_, message) flashes[#flashes + 1] = message end,
	cancel_bow_draw = function() end,
	start_bow_draw = function() return true end,
	try_cast = function(_, def)
		casts[#casts + 1] = def.id
		if def.cooldown then cooldown_until[def.id] = clock + def.cooldown * 1000000 end
		return true
	end,
}

local function wielded_def()
	local name = main[wield_index].name
	return name:sub(1, 15) == "grug_abilities:" and defs[name:sub(16)] or nil
end
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
	selected = function() return wielded_def() end,
	swing = function(_, def) swings[#swings + 1] = def.id end,
	cast_refusal = function(_, def) return not ready(def) and def.name .. " is not ready." or nil end,
	swing_refusal = function() return nil end,
	delay_strike = function() end,
	within_hand_reach = function() return true end,
})
for _, f in ipairs(loaded) do f() end

local controls = {dig = false, place = false}
local player = {
	get_player_name = function() return "p" end,
	get_player_control = function() return controls end,
	get_inventory = function() return inventory end,
	get_wield_list = function() return "main" end,
	get_wield_index = function() return wield_index end,
	get_wielded_item = function() return copy_stack(main[wield_index]) end,
	set_wielded_item = function(_, st)
		main[wield_index] = copy_stack(st)
		return true
	end,
	get_hp = function() return 20 end,
	get_pos = function() return vector.new(0, 0, 0) end,
	get_look_dir = function() return vector.new(0, 0, 1) end,
}

-- Hits: a hand-diggable node 1.5 m ahead, an actor at 1 m (in front of it).
local NODE = {type = "node", under = vector.new(0, 1, 2), above = vector.new(0, 1, 1),
	intersection_point = vector.new(0, 1.47, 1.5)}
local function at(ref, z) return {type = "object", ref = ref, intersection_point = vector.new(0, 1.47, z or 1)} end
local function aim(...) hits = {...} end
local function step()
	clock = clock + 50000
	input.step(player)
end
local function hold(n) for _ = 1, n or 1 do step() end end
local function press() controls.dig = true; step() end
local function release() controls.dig, controls.place = false, false; hold(4) end
local function log_reset() swings, casts, flashes, notices, pickups = {}, {}, {}, 0, 0 end
-- A clean start: every stack pointing, nothing pressed, every cooldown over.
local function start(slot)
	controls.dig, controls.place, stunned = false, false, false
	fill_hotbar()
	wield_index = SLOTS[slot]
	clock = clock + 60000000
	hold(4)
	log_reset()
end
local function to(slot) wield_index = SLOTS[slot] end
-- Switch and let the server see it in one step, as the 0.05 s input pass does.
local function switch(slot) to(slot); step() end
local function range0(slot) return main[SLOTS[slot]].meta.range == "0" end
local function zeroed()
	local list = {}
	for id, i in pairs(SLOTS) do if main[i].meta.range then list[#list + 1] = id end end
	table.sort(list)
	return #list > 0 and table.concat(list, ",") or "none"
end
local function can_dig() return input.can_dig(player, NODE.under, core.get_node_or_nil(NODE.under)) end
local function list(t) return #t > 0 and table.concat(t, ",") or "-" end
local function seen()
	return ("casts=%s swings=%s flashes=%d notices=%d pickups=%d zero=%s dig=%s"):format(list(casts),
		list(swings), #flashes, notices, pickups, zeroed(), tostring(can_dig()))
end
-- A combat hold with Strike on a mob in the crosshair.
local function fighting(mob)
	start("strike")
	aim(at(mob), NODE)
	press()
	hold(2)
	check(range0("strike") and #swings == 3, "setup: Strike fights the mob")
	log_reset()
end

------------------------------------------------------------------------------
-- S: combat holds.
------------------------------------------------------------------------------
do -- S1 Strike -> Fireball at the foe: the cast fires in the switch step.
	local m = new_mob("s1")
	fighting(m)
	switch("fireball")
	local o = seen()
	case("S1", "Strike->Fireball at foe: " .. o)
	check(list(casts) == "fireball" and #swings == 0, "S1 Fireball casts at once, no Strike in that step")
	check(range0("fireball") and not range0("strike"), "S1 the zero range moved to the Fireball stack")
	check(not can_dig(), "S1 still combat: no dig")
	hold(3)
	check(#casts == 1 and #swings == 3, "S1 held: Fireball on cooldown, Strike falls back (no double fire)")
	check(#flashes == 0, "S1 held: quiet")
	release()
	check(zeroed() == "none", "S1 release restores every stack")
end

do -- S2 Strike -> Fireball on cooldown: Strike falls back, nothing reported.
	local m = new_mob("s2")
	fighting(m)
	cooldown_until.fireball = clock + 10000000
	switch("fireball")
	case("S2", "Strike->Fireball not ready: " .. seen())
	check(#casts == 0 and list(swings) == "strike", "S2 the refused cast falls back to Strike")
	check(#flashes == 0, "S2 no refusal message on a carried press")
	release()
end

do -- S3 Strike -> Mighty Blow (a swing skill).
	local m = new_mob("s3")
	fighting(m)
	switch("mighty_blow")
	case("S3", "Strike->Mighty Blow: " .. seen())
	check(list(swings) == "mighty_blow" and range0("mighty_blow"), "S3 Mighty Blow swings at once")
	release()
end

do -- S4-S6 Strike -> a self or support skill at the foe: one cast, then the hold strikes.
	for _, id in ipairs({"ward", "heal", "blink"}) do
		local m = new_mob(id)
		fighting(m)
		switch(id)
		local o = seen()
		hold(3)
		local label = ({ward = "S4", heal = "S5", blink = "S6"})[id]
		case(label, "Strike->" .. defs[id].name .. " at foe: " .. o .. " | held 3: casts=" .. list(casts) ..
			" swings=" .. #swings)
		check(list(casts) == id and #swings == 3, label .. " " .. id .. ": one cast as a fresh press would, then " ..
			"Strike while held")
		check(range0(id) and not range0("strike"), label .. " combat goes on with the new stack")
		release()
	end
end

do -- S7 Strike -> Loose: Loose's left button is Strike.
	local m = new_mob("s7")
	fighting(m)
	switch("loose")
	case("S7", "Strike->Loose at foe: " .. seen())
	check(#casts == 0 and list(swings) == "strike" and range0("loose"), "S7 Loose strikes, combat goes on")
	release()
end

do -- S8 a miss beside the living foe, switch to Fireball: combat kept, nothing dug.
	local m = new_mob("s8")
	fighting(m)
	aim(NODE)
	hold()
	switch("fireball")
	case("S8", "miss beside foe, Strike->Fireball: " .. seen())
	check(range0("fireball") and not can_dig() and #casts == 0, "S8 the lock carries: no dig, no cast at nothing")
	aim(at(m), NODE)
	hold()
	check(list(casts) == "fireball", "S8 the foe back in the crosshair takes the Fireball")
	release()
end

do -- S9 a miss beside the living foe, switch to Ward: one Ward, nothing dug.
	local m = new_mob("s9")
	fighting(m)
	aim(NODE)
	hold()
	switch("ward")
	case("S9", "miss beside foe, Strike->Ward: " .. seen())
	check(list(casts) == "ward" and not can_dig(), "S9 Ward once (a fresh press there would), no dig")
	release()
end

do -- S10/S11 Strike -> a tool or an empty slot and back while held.
	for _, slot in ipairs({"tool", "empty"}) do
		local m = new_mob("s10" .. slot)
		fighting(m)
		switch(slot)
		local away, away_zero = seen(), zeroed()
		hold(2)
		local still = #swings + #casts
		switch("strike")
		local back = seen()
		local label = slot == "tool" and "S10" or "S11"
		case(label, "Strike->" .. slot .. ": " .. away .. " | back to Strike: " .. back)
		check(away_zero == "none" and still == 0, label .. " away: combat ended, no skill action")
		check(list(swings) == "strike" and range0("strike"), label .. " back: combat again at once")
		release()
	end
end

do -- S12 Fireball -> Strike -> Fireball within the cooldown: no second cast.
	local m = new_mob("s12")
	start("fireball")
	aim(at(m), NODE)
	press()
	check(list(casts) == "fireball", "S12 setup: Fireball fires on the press")
	switch("strike")
	switch("fireball")
	case("S12", "Fireball->Strike->Fireball: " .. seen())
	check(list(casts) == "fireball" and list(swings) == "strike,strike", "S12 the cooldown holds: Strike falls back")
	check(#flashes == 0, "S12 the refusal after the switch is quiet")
	release()
end

do -- S13 an evading foe in the crosshair: quiet; a self skill still fires.
	local m = new_mob("s13")
	fighting(m)
	m.evading = true
	hold()
	log_reset()
	switch("fireball")
	local o = seen()
	switch("ward")
	case("S13", "foe evading, Strike->Fireball: " .. o .. " | ->Ward: casts=" .. list(casts) ..
		" notices=" .. notices)
	check(notices == 0 and #flashes == 0, "S13 no 'Evading' and no message on a carried press")
	check(list(casts) == "ward", "S13 Fireball does nothing at the evader, Ward fires as a fresh press would")
	release()
	-- The fresh press at the evader still says so (Round 36 §2.14.1).
	start("fireball")
	aim(at(m), NODE)
	press()
	check(notices == 1, "S13 a fresh press at the evader still shows 'Evading'")
	release()
end

do -- S14 healing an ally: Strike -> Heal at the ally heals it and repeats on it.
	start("strike")
	aim(at(ally), NODE)
	press()
	check(#casts == 0, "S14 setup: Strike at an ally does nothing")
	switch("heal")
	hold(2)
	local o = seen()
	switch("ward")
	case("S14", "Strike->Heal at ally, held 2: " .. o .. " | ->Ward: casts=" .. list(casts))
	check(list(casts) == "heal,heal,heal,ward", "S14 Heal at once and held on that ally; Ward once")
	release()
end

do -- S15 the scroll wheel passing Ward on the way to Fireball.
	local m = new_mob("s15")
	fighting(m)
	switch("ward")
	switch("fireball")
	case("S15", "Strike->Ward->Fireball, one step each: " .. seen())
	check(list(casts) == "ward,fireball", "S15 a skill the server sees for one step is pressed once")
	release()
	fighting(m)
	to("ward")
	to("fireball") -- both inside one 0.05 s pass: the server sees Fireball only
	step()
	check(list(casts) == "fireball", "S15 a slot skipped between two passes is never pressed")
	release()
end

------------------------------------------------------------------------------
-- D: digging holds (the client keeps digging across a wield change).
------------------------------------------------------------------------------
do -- D1-D3 the empty hand digging, then a skill.
	for _, id in ipairs({"strike", "blink", "heal", "fireball"}) do
		start("empty")
		aim(NODE)
		press()
		hold(2)
		local before = can_dig()
		switch(id)
		local o = seen()
		hold(2)
		local later = can_dig()
		release()
		local label = ({strike = "D1", blink = "D2", heal = "D3", fireball = "D4"})[id]
		case(label, "hand digging ->" .. defs[id].name .. ": " .. o .. " | 0.1 s later dig=" .. tostring(later))
		check(before, label .. " setup: the hand digs")
		check(later and #casts == 0 and #swings == 0, label .. " " .. id .. ": the dig goes on, nothing fires")
	end
	-- No tap after a carried switch: a quick release does not blink.
	start("empty")
	aim(NODE)
	press()
	switch("blink")
	check(can_dig(), "D2 no pending tap blocks the dig at the switch")
	controls.dig = false
	step()
	check(#casts == 0, "D2 a release right after the switch is no tap: no Blink")
	release()
end

do -- D5 a skill digging, then the empty hand or a tool; D6 a tool, then a skill.
	for _, pair in ipairs({{"strike", "empty", "D5"}, {"strike", "tool", "D5"}, {"tool", "strike", "D6"},
			{"strike", "fireball", "D7"}, {"heal", "ward", "D7"}}) do
		start(pair[1])
		aim(NODE)
		press()
		hold(5) -- past a support skill's tap window
		local before = can_dig()
		switch(pair[2])
		local o = seen()
		hold(2)
		local later = can_dig()
		case(pair[3], pair[1] .. " digging ->" .. pair[2] .. ": " .. o .. " | later dig=" .. tostring(later))
		check(before and later and #casts == 0, pair[3] .. " " .. pair[1] .. "->" .. pair[2] .. ": the dig goes on")
		release()
	end
end

do -- D8 a pending tap (Blink pressed on a node), switched within 200 ms.
	start("blink")
	aim(NODE)
	press()
	check(not can_dig(), "D8 setup: the tap window holds the dig")
	switch("strike")
	local o = seen()
	release()
	case("D8", "Blink tap pending ->Strike: " .. o .. " | released: casts=" .. list(casts))
	check(#casts == 0, "D8 the old item's tap is dropped, nothing cast on release")
	start("blink")
	aim(NODE)
	press()
	switch("strike")
	check(can_dig(), "D8 Strike digs at once after the switch")
	release()
end

do -- D9 digging, then an attacking skill with a threat in the crosshair: combat.
	start("empty")
	aim(NODE)
	press()
	aim(at(new_mob("d9")), NODE)
	hold()
	check(#swings == 0, "D9 setup: the empty hand never attacks through input")
	switch("fireball")
	case("D9", "hand, mob in crosshair ->Fireball: " .. seen())
	check(list(casts) == "fireball" and range0("fireball"), "D9 the key-down decision: combat, Fireball")
	release()
end

do -- D10 held on air, then Blink: one Blink, as a fresh press on air.
	start("strike")
	aim()
	press()
	hold(2)
	switch("blink")
	hold(3)
	case("D10", "Strike on air ->Blink, held 3: " .. seen())
	check(list(casts) == "blink", "D10 Blink once, never repeated while held")
	release()
end

do -- D11 held on a dropped item: one pickup attempt for the new item.
	start("empty")
	aim(at(drop), NODE)
	press()
	switch("strike")
	hold(3)
	case("D11", "hand on loot ->Strike, held 3: " .. seen())
	check(pickups == 1, "D11 one pickup attempt, as a fresh press makes")
	release()
end

------------------------------------------------------------------------------
-- K: what stays.
------------------------------------------------------------------------------
do -- K1 a right button held across a switch stays cancelled until released.
	start("loose")
	aim(NODE)
	controls.place = true
	step()
	switch("strike")
	controls.dig = true
	hold(2)
	case("K1", "RMB held Loose->Strike, LMB added: " .. seen())
	check(not can_dig() and #swings == 0, "K1 a carried right press cancels until both are released")
	release()
end

do -- K2 a stun cancels; a switch while stunned does not lift it.
	local m = new_mob("k2")
	fighting(m)
	stunned = true
	step()
	stunned = false
	switch("fireball")
	hold(2)
	case("K2", "stunned mid-hold, ->Fireball: " .. seen())
	check(#casts == 0 and #swings == 0 and zeroed() == "none", "K2 the stun's cancel holds until release")
	release()
end

do -- K3 a switch in the same step as a fresh press: an ordinary press.
	local m = new_mob("k3")
	start("strike")
	aim(at(m), NODE)
	to("fireball")
	controls.dig = true
	step()
	case("K3", "switch and press in one step: " .. seen())
	check(list(casts) == "fireball" and #flashes == 0, "K3 a fresh press with the new item")
	release()
	start("strike")
	cooldown_until.fireball = clock + 10000000
	aim(at(m), NODE)
	to("fireball")
	controls.dig = true
	step()
	check(#flashes == 1, "K3 a fresh press still reports its refusal")
	release()
end

do -- K4 one stack at a time holds the zero range, also over a run of switches.
	local m = new_mob("k4")
	fighting(m)
	for _, slot in ipairs({"mighty_blow", "ward", "tool", "loose", "empty", "fireball", "strike"}) do
		switch(slot)
		local z = zeroed()
		local want = (slot == "tool" or slot == "empty") and "none" or slot
		check(z == want, "K4 after ->" .. slot .. " zero range on " .. z .. " (want " .. want .. ")")
	end
	release()
	check(zeroed() == "none", "K4 release restores every stack")
end

if failures == 0 then
	print("R36 F2 PORTABLE PASS checks=" .. checks)
else
	error(("R36 F2 PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
