-- Disposable engine probe (Round 25 Lane C). Never shipped:
-- tools/r25_interfaces/run.sh stages it through tools/luanti_headless.sh on
-- seed 4242424242 (the seed of Lane A's claim probe).
--
-- End to end with the REAL claim core (Lane A), the interfaces (Lane C) and
-- the home stone (Lane D), with a stand-in player (a headless server has no
-- client): the stand-in has a real detached inventory as its main list and an
-- in-memory meta.
--   1. The six capitals carry the housing_manager socket.
--   2. The Highcourt Manager refuses a level-19 player and issues a stone to
--      the same player at level 20 (issue_stone through the form).
--   3. The stone is placed through its real on_place at Lane A's eligible
--      Accord spot.
--   4. The stone form opens; fuel is put through the real detached-inventory
--      callbacks (full accept, then a partial one with the rest returned);
--      the form shows the remaining time.
--   5. A permission is added through the form (a real auth entry).
--   6. "Set as home" (Lane D) binds the claim.
--   7. The Character status line follows.
--   8. Pick up through the confirmation: the stone and the unburnt lumps
--      come back, the home falls back, the status says "not placed yet".

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
	return ok
end

local H = grug_housing
local OWNER, FRIEND = "r25c_owner", "r25c_friend"
local CAPITALS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
	"gor_drazhak", "kezamba"}
local SPOT = {x = -2400, z = -2399} -- tools/r25_claim_core evidence, same seed

local function finish()
	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

-- Captured forms.
local shown = {}
core.show_formspec = function(name, formname, fs)
	shown[#shown + 1] = {name = name, formname = formname, fs = fs}
end
local function last_form() return shown[#shown] or {fs = "", formname = ""} end
local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return true end
	end
	return false
end

local previous_faction = grug_core.get_player_faction
grug_core.get_player_faction = function(name)
	if name == OWNER then return "accord" end
	return previous_faction(name)
end

local function stand_in(name)
	local inv = core.create_detached_inventory("r25c_main_" .. name, {}, name)
	inv:set_size("main", 32)
	local meta = {["grug_factions:faction"] = "accord", ["grug_xp:xp"] = "0"}
	local p = {pos = vector.new(0, 0, 0)}
	function p:get_player_name() return name end
	function p:is_player() return true end
	function p:get_pos() return vector.new(self.pos) end
	function p:get_hp() return 20 end
	function p:get_look_horizontal() return 0 end
	function p:get_player_control() return {} end
	function p:get_inventory() return inv end
	function p:get_meta()
		return {
			get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end,
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = tostring(v) end,
		}
	end
	return p, inv, meta
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

local function sockets()
	local rows = H.manager_sockets()
	check(#rows == 6, "six Manager sockets")
	local seen = {}
	for _, row in ipairs(rows) do
		if row.role == "housing_manager" then seen[row.settlement] = row end
		log(("manager socket %s %s at %s"):format(row.settlement, row.socket,
			core.pos_to_string(row.pos)))
	end
	for _, key in ipairs(CAPITALS) do check(seen[key] ~= nil, key .. " has a Manager") end
	return seen.highcourt
end

local function run()
	local socket = sockets()
	local player, inv, meta = stand_in(OWNER)
	local STONE = H.STONE_ITEM

	-- 2. The Manager: level 19 refused, level 20 issued.
	local npc = {_grug_socket_role = "housing_manager", _grug_start = "highcourt",
		_grug_socket = socket.socket, object = {get_pos = function() return socket.pos end}}
	player.pos = vector.offset(socket.pos, 2, 0, 0)
	meta["grug_xp:xp"] = tostring(100 * 18 * 18)
	check(grug_xp.get_level(player) == 19, "stand-in at level 19")
	check(H.open_manager(player, npc), "Manager dialog opens")
	check(last_form().fs:find("99 lumps last about 30 days", 1, true) ~= nil,
		"Manager explains the upkeep")
	submit(player, "grug_housing:manager", {receive = ""})
	log("level 19: " .. (last_form().fs:match("label%[0.4,3.85;([^%]]*)%]") or "?"))
	check(count_item(inv, STONE) == 0, "level 19 gets no stone")
	meta["grug_xp:xp"] = tostring(100 * 19 * 19)
	submit(player, "grug_housing:manager", {receive = ""})
	log("level 20: " .. (last_form().fs:match("label%[0.4,3.85;([^%]]*)%]") or "?"))
	check(count_item(inv, STONE) == 1, "level 20 receives the Claim Stone")
	local _, state = H.player_claim(OWNER)
	check(state == "carried", "state carried after the hand-out")
	check((H.character_status(OWNER) or {}).text ==
		"Your Claim Stone is in your inventory, not placed yet", "status: carried")

	-- 3. Place at the eligible spot.
	core.emerge_area({x = SPOT.x - 8, y = -20, z = SPOT.z - 8},
		{x = SPOT.x + 8, y = 120, z = SPOT.z + 8}, function(_, _, remaining)
		if remaining > 0 then return end
		local ok, err = pcall(function()
		local y = surface(SPOT.x, SPOT.z)
		if not check(y ~= nil, "surface at the spot") then return end
		local pos = {x = SPOT.x, y = y + 1, z = SPOT.z}
		for dy = 0, 3 do
			for dz = -1, 1 do
				for dx = -1, 1 do
					core.set_node({x = pos.x + dx, y = pos.y + dy, z = pos.z + dz},
						{name = "air"})
				end
			end
		end
		player.pos = vector.offset(pos, 2, 0, 0)
		local stack = inv:remove_item("main", ItemStack(STONE))
		local left = core.registered_items[STONE].on_place(stack, player,
			{type = "node", under = {x = pos.x, y = y, z = pos.z}, above = pos})
		check(left:is_empty(), "stone placed through on_place")
		local claim
		claim, state = H.player_claim(OWNER)
		if not check(claim ~= nil and state == "placed", "state placed") then return end
		log("placed claim " .. claim.id .. " at " .. core.pos_to_string(claim.center))
		check(H.character_status(OWNER).text ==
			"Your Claim Stone needs fuel, anyone can access your home right now",
			"status: empty fuel")

		-- 4. Stone form and fuel.
		check(H.open_stone_interface(player, claim), "stone form opens for the owner")
		check(last_form().fs:find("No fuel: anyone can access your home right now", 1, true)
			~= nil, "form: no fuel")
		local invname = "grug_housing_fuel_" .. OWNER
		local def = core.detached_inventories[invname]
		local fuel = core.get_inventory({type = "detached", name = invname})
		local function put(item)
			local s = ItemStack(item)
			local n = def.allow_put(fuel, "fuel", 1, s, player)
			if n > 0 then
				s:set_count(n)
				fuel:set_stack("fuel", 1, s)
				def.on_put(fuel, "fuel", 1, s, player)
			end
			return n
		end
		check(put("default:coalblock 1") == 0, "coal block refused")
		check(put("default:coal_lump 10") == 10, "10 coal lumps put")
		local fs = last_form().fs
		log("fuel line: " .. (fs:match("label%[1.7,1.65;([^%]]*)%]") or "?"))
		check(fs:find("Fuel left: 3 d 0 h 40 min", 1, true) ~= nil or
			fs:find("Fuel left: 3 d 0 h 39 min", 1, true) ~= nil,
			"form: remaining time after 10 lumps")
		check(core.get_node(pos).name == STONE, "stone node is the fuelled variant")
		check(put("grug_smelting:charcoal 95") == 95, "95 charcoal put")
		check(count_item(inv, "grug_smelting:charcoal") == 6,
			"6 charcoal returned (99 - 10 = 89 accepted)")
		check(last_form().fs:find("Added 89\\, 6 returned", 1, true) ~= nil,
			"form: partial message")
		check(H.remaining_seconds(claim) > 98 * H.LUMP_SECONDS, "99 lumps burning")
		local status = H.character_status(OWNER)
		log("status: " .. status.text)
		check(status.text:find("^Claim Stone fuel: 29 d") ~= nil and status.color == nil,
			"status: remaining time, not red")

		-- 5. Permission through the form.
		core.get_auth_handler().create_auth(FRIEND, "")
		submit(player, "grug_housing:stone", {perm_name = "r25c_ghost", perm_interact = ""})
		check(last_form().fs:find("There is no player called r25c_ghost.", 1, true) ~= nil,
			"unknown player refused")
		submit(player, "grug_housing:stone", {perm_name = FRIEND, perm_interact = ""})
		check(H.permission(claim, FRIEND) == "interact", "friend has Interact")
		check(last_form().fs:find(FRIEND .. " — Interact", 1, true) ~= nil,
			"form lists the friend")
		local inside = {x = pos.x + 10, y = pos.y + 1, z = pos.z + 10}
		check(core.is_protected(inside, FRIEND), "Interact does not build")

		-- 6. Set as home (Lane D).
		check(last_form().fs:find("set_home;Set as home", 1, true) ~= nil,
			"Set-as-home button present")
		submit(player, "grug_housing:stone", {set_home = ""})
		log("set home: " .. (last_form().fs:match("label%[0.4,6.3;([^%]]*)%]") or "?"))
		check(grug_home.home_is_claim(player), "home is the claim")

		-- 7. Character page fragment.
		local page = H.character_status_formspec(OWNER, 2.75, 3.8)
		log("character fragment: " .. page)
		check(page:find("label[2.75,3.80;Claim Stone fuel: 29 d", 1, true) ~= nil,
			"character page label")

		-- 8. Pick up with confirmation.
		submit(player, "grug_housing:stone", {pick_up = ""})
		check(last_form().fs:find("Pick up your Claim Stone?", 1, true) ~= nil,
			"confirmation shown")
		submit(player, "grug_housing:stone", {confirm_pick_up = ""})
		local notice = last_form()
		log("pick up: " .. (notice.fs:match("label%[0.4,0.7;([^%]]*)%]") or "?"))
		check(notice.formname == "grug_housing:notice", "pick-up notice shown")
		check(count_item(inv, STONE) == 1, "stone back in the inventory")
		check(count_item(inv, "default:coal_lump") >= 98, "unburnt lumps returned")
		check(core.get_node(pos).name == "air", "stone node removed")
		_, state = H.player_claim(OWNER)
		check(state == "carried", "state carried after pick-up")
		check(not grug_home.home_is_claim(player), "home fell back to the innkeeper")
		check(H.character_status(OWNER).text ==
			"Your Claim Stone is in your inventory, not placed yet", "status after pick-up")
		end)
		if not ok then check(false, "probe error: " .. tostring(err)) end
		finish()
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
