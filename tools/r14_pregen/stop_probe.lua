-- Tiny engine-only proof before choosing the production scheduler.
local storage = core.get_mod_storage()
local boot = storage:get_int("boot") + 1
storage:set_int("boot", boot)
local cursor = storage:get_int("cursor")
local dispatched = 0
local pending = false
local function log(s) core.log("action", "[stop_probe] " .. s) end
log("boot=" .. boot .. " cursor=" .. cursor)
core.register_globalstep(function()
	if pending then return end
	pending = true
	dispatched = dispatched + 1
	local index = cursor + 1
	local start = core.get_us_time()
	log("dispatch=" .. index)
	local seen, count, failed = {}, 0, false
	core.emerge_area({x=-32+(index-1)*80,y=-32,z=-32},
		{x=47+(index-1)*80,y=47,z=47}, function(pos, action, remaining)
		local key = pos.x .. ":" .. pos.y .. ":" .. pos.z
		if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
			failed = true
		elseif not seen[key] then seen[key] = true; count = count + 1 end
		if remaining == 0 then
			if not failed and count == 125 then
				cursor = index
				storage:set_int("cursor", cursor)
			end
			log("settled=" .. index .. " count=" .. count .. " cursor=" .. cursor ..
				" us=" .. (core.get_us_time()-start))
			core.after(0, function() pending = false; log("deferred") end)
		end
	end)
	-- Normal native shutdown request while the first request is pending.
	log("stop-request=" .. core.get_us_time())
	core.request_shutdown("tiny stop fixture", false, 0)
end)
core.register_on_shutdown(function()
	log("shutdown=" .. core.get_us_time() .. " dispatched=" .. dispatched .. " cursor=" .. cursor)
end)
