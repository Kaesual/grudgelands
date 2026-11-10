-- Disposable engine probe of Round 74 lane MOUNT. Never shipped: run.sh stages
-- it through tools/luanti_headless.sh (PROBE=) and starts one real client,
-- stopping and starting it again on the probe's LEAVE and JOIN lines. The
-- scenario is a coroutine resumed once per server step.
--   A  a flyer 40 nodes over the start town logs out and back in: the ride's
--      tier is in the meta at the join, the flyer comes back with the rider
--      seated where it was, no fall on the way, no damage, the hold gone;
--   B  the same while the flight rule refuses every column (as over enemy
--      land): no flyer, the rider set down on the ground below, no damage.
local modpath = core.get_modpath(core.get_current_modname())
local lib = dofile(modpath .. "/lib.lua")
local HOLD = "grug_mounts:restore"

-- The key as the join finds it, before restore.lua clears it: this callback
-- runs first.
local joined_key = {}
table.insert(core.registered_on_joinplayers, 1, function(player)
	local key = player:get_meta():get_string(grug_mounts.LOGOUT_RIDE_KEY)
	joined_key[#joined_key + 1] = key
	lib.logf("join: saved ride %q at %s", key, core.pos_to_string(player:get_pos(), 1))
end)

local function gone() return lib.player() == nil end

-- Rejoin `n`, then follow the player for `seconds`: the lowest y, the first
-- time seated, the HP. Returns the player and the record.
local function rejoin(n, seconds)
	lib.logf("JOIN %d", n)
	lib.wait_for(function() return lib.player() ~= nil end, 120)
	local player = lib.player()
	if not player then return nil end
	local t0 = core.get_us_time()
	local seen = {min_y = player:get_pos().y, start_y = player:get_pos().y,
		hp = player:get_hp(), max_hp_drop = 0}
	while (core.get_us_time() - t0) / 1e6 < seconds do
		coroutine.yield()
		player = lib.player()
		if not player then return nil end
		local y = player:get_pos().y
		if y < seen.min_y then seen.min_y = y end
		if not seen.seated and grug_mounts.is_mounted(player) then
			seen.seated = (core.get_us_time() - t0) / 1e6
		end
		if not seen.released and not grug_core.is_movement_held(player, HOLD) then
			seen.released = (core.get_us_time() - t0) / 1e6
		end
	end
	seen.hp_end = player:get_hp()
	return player, seen
end

local function leave(n)
	lib.logf("LEAVE %d", n)
	return lib.wait_for(gone, 90)
end

local function scenario()
	local player = lib.wait_character()
	local name = lib.NAME
	local meta = player:get_meta()
	meta:set_int("grug_mounts:land_tier", 2)
	meta:set_int("grug_mounts:flight_tier", 4)
	lib.wait(3)

	-- A: a flyer in the air.
	local ok, message = grug_mounts.mount(player, 3)
	lib.check(ok, "A mounted the Expert flyer (" .. tostring(message) .. ")")
	local record = grug_mounts.active[name]
	if not record then return end
	record.object:set_pos(vector.offset(record.object:get_pos(), 0, 40, 0))
	lib.wait(3)
	local up = player:get_pos()
	local hp = player:get_hp()
	lib.logf("A in the air at %s, hp %d", core.pos_to_string(up, 1), hp)
	lib.check(leave(1) ~= nil, "A the client left")
	local seen
	player, seen = rejoin(2, 10)
	if not player then return lib.check(false, "A the client is back") end
	lib.check(joined_key[#joined_key] == "3", "A the join found tier 3 saved")
	lib.check(math.abs(seen.start_y - up.y) < 1, ("A joined where the mount was (y %.2f, before %.2f)")
		:format(seen.start_y, up.y))
	lib.check(seen.seated ~= nil, ("A seated after %s s"):format(tostring(seen.seated)))
	record = grug_mounts.active[name]
	lib.check(record and record.tier == 3, "A on the same tier")
	lib.check(seen.min_y > up.y - 1.5, ("A no fall: lowest y %.2f (before %.2f)"):format(seen.min_y, up.y))
	lib.check(seen.hp_end == hp, ("A no damage (hp %d, before %d)"):format(seen.hp_end, hp))
	lib.check(seen.released ~= nil, ("A the hold released after %s s"):format(tostring(seen.released)))
	lib.check(player:get_meta():get_string(grug_mounts.LOGOUT_RIDE_KEY) == "", "A the key cleared")

	-- B: the same ride, refused at the join: set down on the ground.
	up = player:get_pos()
	hp = player:get_hp()
	lib.check(leave(3) ~= nil, "B the client left")
	local real = grug_mounts.flight_rule
	grug_mounts.flight_rule = function() return false, "enemy" end
	player, seen = rejoin(4, 12)
	grug_mounts.flight_rule = real
	if not player then return lib.check(false, "B the client is back") end
	local pos = player:get_pos()
	local below = core.get_node({x = pos.x, y = pos.y - 0.6, z = pos.z})
	local definition = core.registered_nodes[below.name]
	lib.check(not grug_mounts.is_mounted(player), "B no flyer")
	lib.check(definition and (definition.walkable or definition.liquidtype ~= "none"),
		("B on the ground: %s under %s (was y %.2f)"):format(below.name, core.pos_to_string(pos, 1), up.y))
	lib.check(seen.hp_end == hp, ("B no damage (hp %d, before %d)"):format(seen.hp_end, hp))
	lib.check(seen.released ~= nil, ("B the hold released after %s s"):format(tostring(seen.released)))
end

local thread = coroutine.create(function()
	scenario()
	lib.log("shutdown")
	core.request_shutdown("probe done", false, 0)
end)

local failed = false
lib.on_step = function()
	if failed or coroutine.status(thread) == "dead" then return end
	local ok, err = coroutine.resume(thread)
	if not ok then
		failed = true
		lib.log("SCENARIO ERROR " .. debug.traceback(thread, tostring(err)))
		lib.log("shutdown")
		core.request_shutdown("probe failed", false, 0)
	end
end
