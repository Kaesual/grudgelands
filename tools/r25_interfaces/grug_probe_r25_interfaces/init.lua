-- Disposable engine probe (Round 25 Lane C). Never shipped:
-- tools/r25_interfaces/run.sh stages it through tools/luanti_headless.sh.
--
-- 1. The Housing Manager socket in each of the six capitals (role and world
--    position from the real socket registry), then the NPC itself: the probe
--    force-loads and emerges each socket's block and waits for grug_mobs to
--    place a villager whose socket role is housing_manager there.
-- 2. The stone form, the Manager form and the Character status built with the
--    real engine helpers (formspec_escape, colorize, ItemStack, detached
--    inventories). Lane A's contract is still stubbed on this branch, so the
--    probe swaps in fakes for the contract functions only.

local P = "[r25_interfaces_probe] "
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
end

local H = grug_housing
local CAPITALS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
	"gor_drazhak", "kezamba"}

local function finish()
	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

-- A stand-in player: the real engine has no client in a headless run.
local function stand_in(name, pos)
	local p = {}
	function p:get_player_name() return name end
	function p:is_player() return true end
	function p:get_pos() return vector.new(pos) end
	function p:get_hp() return 20 end
	function p:get_look_horizontal() return 0 end
	function p:get_meta()
		return {get_string = function() return "" end, get_int = function() return 0 end}
	end
	function p:get_inventory()
		return {add_item = function(_, _, stack) return ItemStack("") end}
	end
	return p
end

local function forms()
	local captured = {}
	local real_show = core.show_formspec
	core.show_formspec = function(name, formname, fs)
		captured[#captured + 1] = {name = name, formname = formname, fs = fs}
	end
	local now = os.time()
	local claim = {id = 1, owner = "probe_owner", center = vector.new(0, 10, 0),
		placed_at = now, paid_until = now + 12 * 86400 + 4 * 3600 + 31 * 60 + 30,
		permissions = {probe_friend = "interact"}}
	local state = "placed"
	local fuel_calls = {}
	H.player_claim = function(name)
		if name == "probe_owner" then return claim, state end
		return nil, "never"
	end
	H.is_active = function(c) return c.paid_until > os.time() end
	H.remaining_seconds = function(c) return math.max(0, c.paid_until - os.time()) end
	H.permission = function(c, name)
		if name == c.owner then return "owner" end
		return c.permissions[name]
	end
	H.add_fuel = function(c, count)
		fuel_calls[#fuel_calls + 1] = count
		local accepted = math.min(count, 3)
		c.paid_until = c.paid_until + accepted * 26160
		H.notify_claim_changed(c, "fuel")
		return accepted
	end
	H.issue_stone = function() return true, "Here is your Claim Stone." end

	local owner = stand_in("probe_owner", {x = 0, y = 11, z = 0})
	check(H.open_stone_interface(owner, claim), "stone form opens for the owner")
	local fs = captured[#captured] and captured[#captured].fs or ""
	log("stone formspec bytes " .. #fs)
	check(fs:find("Fuel left: 12 d 4 h 31 min", 1, true) ~= nil, "stone form remaining time")
	check(fs:find("probe_friend — Interact", 1, true) ~= nil, "stone form access row")
	check(fs:find("item_image[0.4,1.4;1,1;default:coal_lump]", 1, true) ~= nil,
		"stone form lump display")

	-- A put through the real detached inventory and its registered callbacks.
	local invname = "grug_housing_fuel_probe_owner"
	local def = core.detached_inventories[invname]
	local inv = core.get_inventory({type = "detached", name = invname})
	check(def ~= nil and inv ~= nil and inv:get_size("fuel") == 1,
		"real detached fuel inventory with one slot")
	if def and inv then
		check(def.allow_put(inv, "fuel", 1, ItemStack("default:coalblock 2"), owner) == 0,
			"real ItemStack: coal block refused")
		check(def.allow_take(inv, "fuel", 1, ItemStack("default:coal_lump"), owner) == 0,
			"take refused")
		local stack = ItemStack("grug_smelting:charcoal 5")
		check(def.allow_put(inv, "fuel", 1, stack, owner) == 5, "charcoal allowed")
		inv:set_stack("fuel", 1, stack)
		def.on_put(inv, "fuel", 1, stack, owner)
		check(fuel_calls[#fuel_calls] == 5 and inv:get_stack("fuel", 1):is_empty(),
			"on_put burns into add_fuel and empties the slot")
		fs = captured[#captured].fs
		check(fs:find("Added 3\\, 2 returned", 1, true) ~= nil, "partial put message")
	end

	-- Access row through the real receive-fields chain.
	local handled = false
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(owner, "grug_housing:stone", {perm_name = "nobody_here", perm_interact = ""}) then
			handled = true
			break
		end
	end
	check(handled, "stone fields handled by the real chain")
	check(captured[#captured].fs:find("There is no player called nobody_here.", 1, true) ~= nil,
		"core.player_exists refuses an unknown name")

	-- Status on the Character page, per state.
	local page = H.character_status_formspec("probe_owner", 2.75, 3.8)
	-- 12 d 4 h 31 min plus the three lumps the partial put burnt (21 h 48 min).
	check(page:find("Claim Stone fuel: 13 d 2 h", 1, true) ~= nil, "status: remaining time")
	claim.paid_until = os.time() - 1
	page = H.character_status_formspec("probe_owner", 2.75, 3.8)
	check(page:find(core.get_color_escape_sequence("#ff6060") ..
		"Your Claim Stone needs fuel\\, anyone", 1, true) ~= nil, "status: empty fuel in red")
	state = "destroyed"
	page = H.character_status_formspec("probe_owner", 2.75, 3.8)
	check(page:find("Your Claim Stone has been destroyed", 1, true) ~= nil, "status: destroyed")
	check(H.character_status_formspec("someone_else", 2.75, 3.8) == "",
		"status: nothing before the first stone")
	check(sfinv.pages["grug_inventory:character"] ~= nil, "Character page registered")

	core.show_formspec = real_show
	return captured
end

local function manager_npcs()
	local rows = H.manager_sockets()
	check(#rows == 6, "six Manager sockets")
	local seen = {}
	for _, row in ipairs(rows) do
		seen[row.settlement] = true
		check(row.role == "housing_manager", row.settlement .. " socket role housing_manager")
		log(("manager socket %s %s at %s"):format(row.settlement, row.socket,
			core.pos_to_string(row.pos)))
	end
	for _, key in ipairs(CAPITALS) do check(seen[key], key .. " has a Manager") end

	-- Map marker: the service provider reads the socket role at mods-loaded.
	local ok, markers = pcall(grug_map.atlas.collect_markers,
		stand_in("probe_map", {x = 0, y = 0, z = 0}))
	if ok then
		local count = 0
		for _, marker in ipairs(markers) do
			if marker.label == "Housing Manager" then count = count + 1 end
		end
		check(count == 6, "six Housing Manager map markers (" .. count .. ")")
	else
		log("map markers not collected with a stand-in player: " .. tostring(markers))
	end

	for _, row in ipairs(rows) do
		core.forceload_block(row.pos, true)
		core.emerge_area(vector.subtract(row.pos, 8), vector.add(row.pos, 8))
	end
	local started = os.time()
	local found = {}
	local function scan()
		local pending = 0
		for _, row in ipairs(rows) do
			if not found[row.settlement] then
				for _, object in ipairs(core.get_objects_inside_radius(row.pos, 3)) do
					local entity = object:get_luaentity()
					if entity and entity._grug_socket_role == "housing_manager" and
							entity._grug_start == row.settlement then
						found[row.settlement] = true
						log(("manager npc %s %s \"%s\" at %s"):format(row.settlement,
							entity.name, tostring(entity._grug_npc_name),
							core.pos_to_string(vector.round(object:get_pos()))))
					end
				end
				if not found[row.settlement] then pending = pending + 1 end
			end
		end
		if pending == 0 or os.time() - started > 200 then
			for _, key in ipairs(CAPITALS) do
				check(found[key], key .. " Housing Manager NPC present")
			end
			for _, row in ipairs(rows) do core.forceload_free_block(row.pos, true) end
			finish()
			return
		end
		core.after(5, scan)
	end
	core.after(5, scan)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local ok, err = pcall(forms)
		check(ok, "forms built without error" .. (ok and "" or (": " .. tostring(err))))
		manager_npcs()
	end)
end)
