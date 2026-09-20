local failures = 0
local function check(value, message)
	if not value then
		failures = failures + 1
		core.log("error", "WP11X3 FAIL " .. message)
	end
end

core.register_on_mods_loaded(function()
	check(jit and type(jit.version) == "string", "LuaJIT runtime")
	if jit and jit.version then
		core.log("action", "WP11X3 runtime " .. jit.version)
	end
	for _, id in ipairs({"hold_ground", "cinderfall", "glacial_ward",
			"word_of_ruin"}) do
		local def = grug_abilities.registered[id]
		check(def ~= nil, "registered " .. id)
		check(def and def.talent_gated == true, "talent gate " .. id)
		check(def and type(def.cast) == "function", "cast " .. id)
	end
	check(grug_abilities.registered.hamstring.talent_gated,
		"Hamstring remains talent gated")
	check(grug_abilities.registered.renew.talent_gated,
		"Renew remains talent gated")
	check(type(grug_core.add_absorb) == "function", "named absorb API")
	check(type(grug_classes.try_trigger_talent_window) == "function",
		"window cooldown API")
	check(type(grug_abilities.cost_for) == "function", "resolved cost API")
	if failures == 0 then
		core.log("action", "WP11X3 RESULT PASS")
	else
		error("WP11X3 RESULT FAIL " .. failures)
	end
end)
