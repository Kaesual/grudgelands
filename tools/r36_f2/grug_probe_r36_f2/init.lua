-- Disposable Round 36 lane F2 probe (tools/r36_f2/engine.sh). Never shipped.
--
-- Digging with the left button held across a hotbar switch (the user's
-- playtest finding of 2026-10-05). The client predicts a dig: it keeps its
-- crack time across a wield change (game.cpp processPlayerInteraction stops
-- only on release or on pointing elsewhere), removes the node at the end and
-- sends DIGGING_COMPLETED; the server then runs the node's on_dig with the
-- item wielded NOW (serverpackethandler.cpp, node_on_dig), and a node still
-- there is re-sent, so the client sees it come back. A headless server has
-- no client, so a stand-in player (a table the engine's Lua accepts as a
-- player, core.is_player) holds the dig: the real input pass
-- (grug_abilities.input.step) runs on it every server step while it presses,
-- switches its wield index and keeps holding; then the probe runs exactly
-- what DIGGING_COMPLETED runs, the node's registered on_dig (our input
-- wrapper around core.node_dig), and logs the node afterwards. Air: the dig
-- was accepted; dirt: refused (the client's node reappears).
-- Every line carries "[r36f2]"; the probe ends the server.
local P = "[r36f2] "
local function log(s) core.log("action", P .. s) end

local NAME = "r36f2probe"
local NODE = "default:dirt"
local FEET = {x = 40, y = 400, z = 40}
local AT = {x = 40, y = 401, z = 42} -- the dug node, 2 nodes ahead
-- Hotbar: 1 Strike, 2 empty hand, 3 Blink (a self skill), 4 Fireball.
local SLOT = {strike = 1, hand = 2, blink = 3, fireball = 4}
local CASES = {
	{"hand", "hand"}, {"strike", "strike"}, -- no switch: both dig
	{"hand", "strike"}, {"strike", "hand"}, {"hand", "blink"}, {"strike", "fireball"},
}

-- The stand-in's player meta: mod storage is a real metadata ref (only
-- available at load time).
local meta = core.get_mod_storage()
local inv, controls, wield, look
local fake = {}
local function setup()
	inv = core.create_detached_inventory(NAME, {})
	inv:set_size("main", 8)
	inv:set_stack("main", SLOT.strike, "grug_abilities:strike")
	inv:set_stack("main", SLOT.blink, "grug_abilities:blink")
	inv:set_stack("main", SLOT.fireball, "grug_abilities:fireball")
	meta:set_string("grug_classes:class", "mage")
	controls, wield, look = {dig = false, place = false}, SLOT.hand, vector.new(0, 0, 1)
	function fake:is_player() return true end
	function fake:is_valid() return true end
	function fake:get_player_name() return NAME end
	function fake:get_player_control() return controls end
	function fake:get_inventory() return inv end
	function fake:get_wield_list() return "main" end
	function fake:get_wield_index() return wield end
	function fake:get_wielded_item() return inv:get_stack("main", wield) end
	function fake:set_wielded_item(stack) inv:set_stack("main", wield, stack); return true end
	function fake:get_hp() return 20 end
	function fake:get_pos() return vector.copy(FEET) end
	function fake:get_velocity() return vector.zero() end
	function fake:get_look_dir() return vector.copy(look) end
	function fake:get_look_horizontal() return 0 end
	function fake:get_look_vertical() return 0 end
	function fake:get_properties() return {eye_height = 1.625} end
	function fake:get_eye_offset() return vector.zero(), vector.zero(), vector.zero() end
	function fake:get_attach() return nil end
	function fake:get_meta() return meta end
	setmetatable(fake, {__index = function(_, key)
		log("MISSING method " .. tostring(key))
		return function() return nil end
	end})
	-- interact for the stand-in (core.check_player_privs reads the auth), and
	-- protection_bypass: a factionless stand-in finds the world protected, and
	-- protection is not what this probe asks.
	core.get_auth_handler().create_auth(NAME, "")
	core.set_player_privs(NAME, {interact = true, protection_bypass = true})
	-- Aim at the node's centre from the combat eye (twice: the eye moves
	-- slightly with the look direction).
	for _ = 1, 2 do
		local eye = grug_core.combat_eye_pos(fake)
		look = vector.direction(eye, AT)
	end
end

local ready, case_index, phase, t = false, 0, nil, 0
local results = {}
local function input_step() grug_abilities.input.step(fake) end

local function begin_case()
	case_index = case_index + 1
	local c = CASES[case_index]
	if not c then return false end
	core.set_node(AT, {name = NODE})
	wield, controls.dig = SLOT[c[1]], false
	phase, t = "settle", 0
	return true
end

local function finish_case()
	local c = CASES[case_index]
	local node = core.get_node(AT)
	local def = core.registered_nodes[node.name]
	local ok, err = pcall(def.on_dig, vector.copy(AT), node, fake)
	local after = core.get_node(AT).name
	local accepted = after == "air"
	results[#results + 1] = accepted
	log(("CASE %s -> %s: held dig, switched, DIGGING_COMPLETED: on_dig %s; node after: %s (%s)"):format(
		c[1], c[2], ok and "ran" or ("raised: " .. tostring(err)), after,
		accepted and "dig accepted" or "dig refused, the client's node reappears"))
end

-- One input pass per server step (the real pass runs every 0.05 s or more):
-- 3 released, 4 pressed, the switch, 4 more held, then the completed dig.
core.register_globalstep(function()
	if not ready then return end
	if not phase and not begin_case() then
		ready = false
		local all = true
		for _, accepted in ipairs(results) do all = all and accepted end
		log(("RESULT %s cases=%d accepted=%d"):format(all and "PASS" or "FAIL", #results,
			(function() local n = 0; for _, a in ipairs(results) do if a then n = n + 1 end end; return n end)()))
		core.request_shutdown("r36f2 probe done", false, 0)
		return
	end
	t = t + 1
	if phase == "settle" then
		input_step()
		if t >= 3 then phase, t, controls.dig = "press", 0, true end
	elseif phase == "press" then
		input_step()
		if t >= 4 then
			phase, t = "held", 0
			wield = SLOT[CASES[case_index][2]]
		end
	elseif phase == "held" then
		input_step()
		if t >= 4 then
			finish_case()
			phase, t, controls.dig = "release", 0, false
		end
	elseif phase == "release" then
		input_step()
		if t >= 4 then phase = nil end
	end
end)

core.register_on_mods_loaded(function()
	core.after(1, function()
		local p1, p2 = vector.offset(FEET, -8, -8, -8), vector.offset(FEET, 8, 8, 8)
		core.forceload_block(FEET, true, -1)
		core.emerge_area(p1, p2, function(_, _, remaining)
			if remaining > 0 then return end
			setup()
			-- Clear the probe's space (the sky at y 400 is air already).
			for dx = -1, 1 do
				for dy = 0, 3 do
					for dz = -1, 3 do
						local p = vector.offset(FEET, dx, dy, dz)
						if core.get_node(p).name ~= "air" then core.set_node(p, {name = "air"}) end
					end
				end
			end
			log(("site %s, node %s at %s, protected=%s, look=%s"):format(core.pos_to_string(FEET), NODE,
				core.pos_to_string(AT), tostring(core.is_protected(AT, NAME)), core.pos_to_string(look, 2)))
			ready = true
		end)
	end)
end)
