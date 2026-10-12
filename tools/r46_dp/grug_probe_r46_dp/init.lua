-- Disposable engine probe (Round 46 lane DP, step 1). Never shipped:
-- tools/r46_dp/probe_physical.sh stages it through tools/luanti_headless.sh.
--
-- Question: mobs_redo's register_mob hard-codes initial_properties.physical =
-- true and never copies def.physical, so are the Glowwing, the Ember Wisp and
-- the Wisp (whose defs say `physical = false`) really physical at runtime?
-- Read the prototype, then place each mob once in a force-loaded block high in
-- the air and read the live object's properties.
--
-- Side question for lane LT's flag: does a def field such as
-- `_grug_no_coin_bag` (kraken.lua) reach the entity at all?

local P = "[r46_dp_probe] "
local NAMES = {"grug_mobs:blood_bat", "grug_mobs:glowwing", "grug_mobs:ember_wisp",
	"grug_mobs:wisp", "grug_mobs:cave_bat"}

local function log(msg) core.log("action", P .. msg) end

core.register_on_mods_loaded(function()
	for _, name in ipairs(NAMES) do
		local proto = core.registered_entities[name]
		log(("proto %s physical=%s"):format(name,
			tostring(proto and proto.initial_properties.physical)))
	end
	local kraken = core.registered_entities["grug_mobs:kraken"]
	log("proto grug_mobs:kraken _grug_no_coin_bag=" ..
		tostring(kraken and rawget(kraken, "_grug_no_coin_bag")) .. " (indexed: " ..
		tostring(kraken and kraken._grug_no_coin_bag) .. ")")
end)

local POS = {x = 8, y = 30008, z = 8}

core.after(3, function()
	core.forceload_block(POS, true)
	core.emerge_area(POS, POS, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(2, function()
			local failed = 0
			for i, name in ipairs(NAMES) do
				local at = {x = POS.x + 2 * i, y = POS.y, z = POS.z}
				local obj = core.add_entity(at, name)
				if obj then
					local props = obj:get_properties()
					log(("live %s physical=%s"):format(name, tostring(props.physical)))
					obj:remove()
				else
					failed = failed + 1
					log("live " .. name .. " add_entity failed")
				end
			end
			log("RESULT DONE failed=" .. failed)
			core.request_shutdown("r46 dp probe done", false, 0)
		end)
	end)
end)
