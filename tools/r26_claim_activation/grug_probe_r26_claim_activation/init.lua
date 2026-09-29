-- Disposable engine probe (Round 26 Lane S). Never shipped:
-- tools/r26_claim_activation/run.sh stages it through tools/luanti_headless.sh
-- on seed 4242424242 (the eligible Accord spot of the Round 25 probes).
--
-- End to end with the real grug_housing, grug_home, grug_mobs and grug_map,
-- with stand-in players (a headless server has no client):
--   1. Steward: six sockets, the dialog titled "Housing Steward" with the
--      activation lines, the map service markers, the NPC name in the source;
--      a level-20 stand-in receives the stone.
--   2. Draft: placing sets the half-transparent draft node; it protects
--      nothing (another player builds, no interaction or spawn guard), keeps
--      the arrival cube, reserves its square, survives a pick dig by another
--      player, is no home; the form shows the activation button.
--   3. Draft pick-up at once through the form, then placing again at once.
--   4. Activation: refused with 3 lumps, done with 3 coal + 2 charcoal;
--      fuelled node, protection, interaction and spawn guard on.
--   5. Pick-up lock: refused right after activation; allowed once the
--      activation time is moved 12 h back (faked clock); placing again at once.
--   6. Draft expiry: the placed-at time moved 5 min back; the periodic check
--      removes claim and node; a new stone from the Steward at once.
--   7. Snow in the arrival cube: placing into it refused, digging it allowed
--      for the owner (through the installed dig wrapper), refused for others.
--   8. Admin command: /claim_remove <player>, here, orphans.

local P = "[r26_claim_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end

local H = grug_housing
local model = H.model
local OWNER, OTHER, ADMIN = "r26owner", "r26other", "r26admin"
local SPOT = {x = -2400, z = -2399}
local SNOW = "grug_probe_r26_claim_activation:snow"

local function finish()
	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

-- A buildable_to test node whose on_dig and on_punch only record what
-- is_protected answers inside the dig context (grug_housing wraps them on the
-- first server step, grug_abilities at mods-loaded, like default:snow).
local dig_seen = {}
core.register_node(SNOW, {
	description = "Probe snow", tiles = {"default_snow.png"}, buildable_to = true,
	groups = {crumbly = 3, not_in_creative_inventory = 1},
	on_dig = function(pos, _, digger)
		local name = digger:get_player_name()
		dig_seen[#dig_seen + 1] = "dig " .. name .. ":" .. tostring(core.is_protected(pos, name))
		return true
	end,
	on_punch = function(pos, _, puncher)
		local name = puncher:get_player_name()
		dig_seen[#dig_seen + 1] = "punch " .. name .. ":" ..
			tostring(core.is_protected(pos, name))
	end,
})

local shown = {}
core.show_formspec = function(name, formname, fs)
	shown[#shown + 1] = {name = name, formname = formname, fs = fs}
end
local function last_form(name)
	for i = #shown, 1, -1 do
		if not name or shown[i].name == name then return shown[i] end
	end
	return {fs = "", formname = ""}
end
local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return true end
	end
	return false
end

local FACTION = {[OWNER] = "accord", [OTHER] = "accord", [ADMIN] = "accord"}
local previous_faction = grug_core.get_player_faction
grug_core.get_player_faction = function(name)
	return FACTION[name] or previous_faction(name)
end

local stand_ins = {}
local function stand_in(name, wield)
	local inv = core.create_detached_inventory("r26_main_" .. name, {}, name)
	inv:set_size("main", 32)
	local meta = {["grug_factions:faction"] = "accord", ["grug_xp:xp"] = "0"}
	local p = {pos = vector.new(0, 0, 0), wield = ItemStack(wield or "")}
	function p:get_player_name() return name end
	function p:is_player() return true end
	function p:get_pos() return vector.new(self.pos) end
	function p:get_hp() return 20 end
	function p:get_look_horizontal() return 0 end
	function p:get_player_control() return {} end
	function p:get_inventory() return inv end
	function p:get_wielded_item() return ItemStack(self.wield) end
	function p:set_wielded_item(stack) self.wield = ItemStack(stack) return true end
	function p:get_meta()
		return {
			get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end,
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = tostring(v) end,
		}
	end
	stand_ins[name] = p
	return p, inv, meta
end
local real_get_player = core.get_player_by_name
core.get_player_by_name = function(name)
	return stand_ins[name] or real_get_player(name)
end

local function count_item(inv, item)
	local n = 0
	for _, stack in ipairs(inv:get_list("main")) do
		if stack:get_name() == item then n = n + stack:get_count() end
	end
	return n
end

local function surface(x, z)
	local top = grug_zones.terrain_height_at(x, z) + 24
	for y = top, top - 64, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		local def = core.registered_nodes[node.name]
		if def and def.walkable and not def.buildable_to then return y end
	end
end

local events = {}
H.register_on_claim_changed(function(claim, event)
	events[#events + 1] = event .. ":" .. claim.id
end)

local owner, inv = stand_in(OWNER)
local other, _, other_meta = stand_in(OTHER, "default:pick_steel")
other_meta["grug_xp:xp"] = tostring(100 * 59 * 59) -- no tool-level shortfall
local admin = stand_in(ADMIN)
local steward, pos

local function place()
	local stack = inv:remove_item("main", ItemStack(H.STONE_ITEM))
	local left = core.registered_items[H.STONE_ITEM].on_place(stack, owner,
		{type = "node", under = {x = pos.x, y = pos.y - 1, z = pos.z}, above = pos})
	if not left:is_empty() then inv:add_item("main", left) end
	return left:is_empty()
end

local function form_pick_up()
	submit(owner, "grug_housing:stone", {pick_up = ""})
	submit(owner, "grug_housing:stone", {confirm_pick_up = ""})
end

local function status() return (H.character_status(OWNER) or {}).text or "" end

-- 1. Steward
local function step_steward()
	local rows = H.manager_sockets()
	check(#rows == 6, "six Steward sockets")
	local highcourt
	for _, row in ipairs(rows) do
		if row.settlement == "highcourt" then highcourt = row end
	end
	steward = {_grug_socket_role = "housing_manager", _grug_start = "highcourt",
		_grug_socket = highcourt.socket, object = {get_pos = function() return highcourt.pos end}}
	owner.pos = vector.offset(highcourt.pos, 2, 0, 0)
	check(H.open_manager(owner, steward), "Steward dialog opens")
	local fs = last_form(OWNER).fs
	check(fs:find("label[0.4,0.5;Housing Steward]", 1, true) ~= nil, "dialog title Housing Steward")
	check(fs:find("Manager", 1, true) == nil, "no Manager in the dialog")
	check(fs:find("Activate it within 5 minutes with 5 coal lumps or charcoal", 1, true) ~= nil,
		"dialog explains the activation")
	check(fs:find("stays in place for 12 hours", 1, true) ~= nil, "dialog names the 12 h lock")
	-- Map: the service markers (best effort with a stand-in player).
	local ok, markers = pcall(grug_map.atlas.collect_markers, owner)
	if ok then
		local stewards, managers = 0, 0
		for _, m in ipairs(markers) do
			if m.label == "Housing Steward" then stewards = stewards + 1 end
			if m.label:find("Manager", 1, true) then managers = managers + 1 end
		end
		check(stewards == 6 and managers == 0, ("map: %d Housing Steward markers, %d Manager"):format(
			stewards, managers))
	else
		log("map markers not collectable with a stand-in: " .. tostring(markers))
	end
	-- The NPC name is set in grug_mobs' socket-role setup (no NPC is spawned
	-- by this probe): the shipped source line.
	local file = io.open(core.get_modpath("grug_mobs") .. "/start_npcs.lua", "r")
	local source = file and file:read("*a") or ""
	if file then file:close() end
	check(source:find('entity._grug_npc_name = "Housing Steward"', 1, true) ~= nil and
		source:find('"Housing Manager"', 1, true) == nil, "NPC name Housing Steward")
	owner:get_meta():set_string("grug_xp:xp", tostring(100 * 19 * 19))
	submit(owner, "grug_housing:manager", {receive = ""})
	check(count_item(inv, H.STONE_ITEM) == 1, "level 20 receives the stone")
	core.get_auth_handler().create_auth(OTHER, "")
end

-- 2-7, once the spot is emerged.
local function scenario()
	local y = surface(SPOT.x, SPOT.z)
	if not check(y ~= nil, "surface at the spot") then return end
	pos = {x = SPOT.x, y = y + 1, z = SPOT.z}
	for dy = 0, 3 do
		for dz = -1, 1 do
			for dx = -1, 1 do
				core.set_node({x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}, {name = "air"})
			end
		end
	end
	owner.pos = vector.offset(pos, 2, 0, 0)
	other.pos = vector.offset(pos, 3, 0, 0)
	local inside = {x = pos.x + 10, y = pos.y + 1, z = pos.z + 10}
	local cube = {x = pos.x + 1, y = pos.y + 2, z = pos.z}

	-- 2. Draft
	check(place(), "stone placed")
	local claim, state = H.player_claim(OWNER)
	if not check(claim ~= nil and state == "placed", "state placed") then return end
	check(core.get_node(pos).name == H.DRAFT_STONE, "the placed node is the draft")
	check(core.registered_nodes[H.DRAFT_STONE].use_texture_alpha == "blend",
		"draft renders half-transparent")
	check(H.is_draft(claim) and not H.is_active(claim), "draft, not active")
	check(not core.is_protected(inside, OTHER), "draft: another player builds")
	check(core.is_protected(cube, OWNER), "draft keeps the arrival cube")
	check(not grug_core.interaction_guarded(inside, OTHER), "draft: no interaction guard")
	check(not grug_mobs.claim_refuses_spawn("grug_mobs:wolf", inside), "draft: wolves spawn")
	local world = {}
	for key, fn in pairs(H.placement_world) do world[key] = fn end
	world.cube_clear = function() return true end
	local ok, code = model.validate(OTHER, "accord", {x = pos.x + 60, y = pos.y, z = pos.z}, world)
	check(not ok and code == "overlap", "draft reserves its square (" .. tostring(code) .. ")")
	core.node_dig(pos, core.get_node(pos), other)
	check(core.get_node(pos).name == H.DRAFT_STONE and model.claim_by_id(claim.id) ~= nil,
		"another player cannot dig the draft")
	local ok_home, msg_home = grug_home.set_home_claim(owner)
	check(not ok_home and msg_home == "Activate your Claim Stone first.", "a draft is no home")
	check(status():find("^Your Claim Stone is not active yet: activate it within 5 min") ~= nil,
		"status: draft (" .. status() .. ")")
	check(H.open_stone_interface(owner, claim), "draft form opens")
	local fs = last_form(OWNER).fs
	check(fs:find("activate;Activate (5 coal)", 1, true) ~= nil and
		fs:find("list[detached:", 1, true) == nil, "draft form: activation button, no fuel slot")

	-- 3. Draft pick-up at once, place again at once.
	form_pick_up()
	check(last_form(OWNER).formname == "grug_housing:notice", "draft picked up at once")
	check(count_item(inv, H.STONE_ITEM) == 1 and core.get_node(pos).name == "air",
		"stone back, node gone")
	check(place(), "placed again at once (no placing lock)")
	claim = H.player_claim(OWNER)

	-- 4. Activation
	inv:add_item("main", ItemStack("default:coal_lump 3"))
	H.open_stone_interface(owner, claim)
	submit(owner, "grug_housing:stone", {activate = ""})
	check(H.is_draft(claim) and last_form(OWNER).fs:find("you have 3", 1, true) ~= nil,
		"3 lumps: refused")
	inv:add_item("main", ItemStack("grug_smelting:charcoal 4"))
	submit(owner, "grug_housing:stone", {activate = ""})
	check(not H.is_draft(claim) and H.is_active(claim), "activated with 5 lumps")
	check(count_item(inv, "default:coal_lump") == 0 and
		count_item(inv, "grug_smelting:charcoal") == 2, "3 coal and 2 charcoal taken")
	check(H.remaining_seconds(claim) >= 5 * H.LUMP_SECONDS - 2, "5 lumps burning")
	check(core.get_node(pos).name == H.STONE_ITEM, "fuelled node after activation")
	fs = last_form(OWNER).fs
	check(fs:find("list[detached:grug_housing_fuel_" .. OWNER, 1, true) ~= nil and
		fs:find("Pick-up possible in 1", 1, true) ~= nil, "form: fuel slot and lock line")
	check(core.is_protected(inside, OTHER) and not core.is_protected(inside, OWNER),
		"active: others refused, owner builds")
	check(grug_core.interaction_guarded(inside, OTHER), "active: interaction guarded")
	check(grug_mobs.claim_refuses_spawn("grug_mobs:wolf", inside), "active: no hostile spawn")
	core.node_dig(pos, core.get_node(pos), other)
	check(core.get_node(pos).name == H.STONE_ITEM, "nobody digs the fuelled stone")

	-- 5. Pick-up lock
	form_pick_up()
	local refusal = last_form(OWNER).fs:match("stays in place for another ([^%.]+)%.")
	log("lock refusal: " .. tostring(refusal))
	check(refusal ~= nil and model.claim_by_id(claim.id) ~= nil and
		core.get_node(pos).name == H.STONE_ITEM, "pick-up refused right after activation")
	claim.activated_at = os.time() - H.PICKUP_LOCK_SECONDS - 1 -- faked clock
	H.open_stone_interface(owner, claim)
	form_pick_up()
	check(last_form(OWNER).formname == "grug_housing:notice" and
		model.claim_by_id(claim.id) == nil, "pick-up allowed 12 h after activation")
	-- floor(remaining / LUMP): 5 when the pick-up falls in the activation's
	-- second, 4 once a second has burnt.
	local back = count_item(inv, "default:coal_lump")
	check(back == 4 or back == 5, "whole unburnt lumps returned (" .. back .. ")")
	check(place(), "placed again at once after the pick-up")
	claim = H.player_claim(OWNER)

	-- 6. Draft expiry (faked clock), checked after the next periodic step.
	claim.placed_at = os.time() - H.DRAFT_SECONDS
	local expired_id = claim.id
	core.after(6, function()
		local ok6, err6 = pcall(function()
		check(model.claim_by_id(expired_id) == nil and core.get_node(pos).name == "air",
			"expired draft: claim and node gone")
		local _, st = H.player_claim(OWNER)
		check(st == "needs_stone", "expired draft: needs_stone")
		local seen = false
		for _, e in ipairs(events) do
			if e == "draft_expired:" .. expired_id then seen = true end
		end
		check(seen, "draft_expired event")
		owner.pos = vector.offset(steward.object:get_pos(), 2, 0, 0)
		H.open_manager(owner, steward)
		submit(owner, "grug_housing:manager", {receive = ""})
		check(count_item(inv, H.STONE_ITEM) == 1, "a new stone from the Steward at once")

		-- 7. Snow in the arrival cube of an active claim.
		owner.pos = vector.offset(pos, 2, 0, 0)
		check(place(), "placed for the snow test")
		local c7 = H.player_claim(OWNER)
		inv:add_item("main", ItemStack("default:coal_lump 5"))
		H.open_stone_interface(owner, c7)
		submit(owner, "grug_housing:stone", {activate = ""})
		check(H.is_active(c7), "activated for the snow test")
		core.set_node(cube, {name = SNOW})
		check(core.is_protected(cube, OWNER), "snow in the cube: placing into it refused")
		local def = core.registered_nodes[SNOW]
		def.on_dig(cube, core.get_node(cube), owner)
		def.on_punch(cube, core.get_node(cube), owner)
		def.on_dig(cube, core.get_node(cube), other)
		log("snow: " .. table.concat(dig_seen, ", "))
		check(table.concat(dig_seen, ",") == "dig r26owner:false,punch r26owner:false,dig r26other:true",
			"snow in the cube: the owner digs and punches it, others not")
		check(core.is_protected(cube, OWNER), "outside the dig the cube refuses again")
		core.set_node(cube, {name = "air"}) -- the probe node does not dig itself

		-- 8. Admin command.
		local cmd = core.registered_chatcommands.claim_remove
		check(cmd ~= nil and cmd.privs and cmd.privs.server == true, "/claim_remove needs server")
		admin.pos = vector.offset(pos, 5, 0, 5)
		local ok8, msg8 = cmd.func(ADMIN, "here")
		log("claim_remove here: " .. tostring(msg8))
		check(ok8 and model.claim_by_id(c7.id) == nil and core.get_node(pos).name == "air" and
			select(2, H.player_claim(OWNER)) == "destroyed", "here: the claim and its stone removed")
		owner.pos = vector.offset(steward.object:get_pos(), 2, 0, 0)
		H.open_manager(owner, steward)
		submit(owner, "grug_housing:manager", {receive = ""})
		owner.pos = vector.offset(pos, 2, 0, 0)
		check(place(), "placed again after the admin removal")
		local c8 = H.player_claim(OWNER)
		ok8, msg8 = cmd.func(ADMIN, OWNER)
		log("claim_remove player: " .. tostring(msg8))
		check(ok8 and model.claim_by_id(c8.id) == nil and core.get_node(pos).name == "air",
			"<player>: the draft and its stone removed")
		local orphan = {x = pos.x + 4, y = pos.y, z = pos.z + 4}
		core.set_node(orphan, {name = H.STONE_ITEM})
		ok8, msg8 = cmd.func(ADMIN, "orphans")
		log("claim_remove orphans: " .. tostring(msg8))
		check(ok8 and core.get_node(orphan).name == "air", "orphans: the orphaned stone removed")
		ok8, msg8 = cmd.func(ADMIN, "nobody_here")
		check(not ok8, "unknown player: refused (" .. tostring(msg8) .. ")")
		log("EVENTS " .. table.concat(events, " "))
		end)
		if not ok6 then check(false, "probe error: " .. tostring(err6)) end
		finish()
	end)
	return true
end

local function run()
	step_steward()
	core.emerge_area({x = SPOT.x - 8, y = -20, z = SPOT.z - 8},
		{x = SPOT.x + 8, y = 120, z = SPOT.z + 8}, function(_, _, remaining)
		if remaining > 0 then return end
		local ok, scheduled = pcall(scenario)
		if not ok then check(false, "probe error: " .. tostring(scheduled)) end
		if not ok or not scheduled then finish() end
	end)
end

core.register_on_mods_loaded(function()
	core.after(3, function()
		local ok, err = pcall(run)
		if not ok then
			check(false, "probe error: " .. tostring(err))
			finish()
		end
	end)
end)
