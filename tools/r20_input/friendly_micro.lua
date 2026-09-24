-- Final-only fixture: current visible ally wins; client/memory cannot redirect.
return function(root)
	local function noop() end
	local function registry(t)
		return setmetatable(t or {}, {__index = function(_, key)
			if key:match("^register_") then return noop end
		end})
	end
	local ray, selected
	local user, ally, old = {}, {}, {}
	local env = setmetatable({}, {__index = _G})
	env._G = env
	env.core = registry()
	env.grug_projectiles = registry()
	env.grug_classes = registry()
	env.grug_abilities = registry({
		valid_target = function(_, target, kind) return target == ally and kind == "friendly" end,
		get_range = function() return 20 end,
		get_target = function() error("Healing must not read remembered targets") end,
		set_target = function(_, target) selected = target end,
	})
	env.grug_core = registry({combat_ray = function(_, range)
		assert(range == 20)
		return ray
	end})
	local fn = assert(loadfile(root .. "/mods/PLAYER/grug_abilities/kits.lua"))
	setfenv(fn, env)()
	local resolve = env.grug_abilities.resolve_friendly_target
	local def = {target_kind = "friendly"}
	ray = {reason = "friendly", target = ally}
	assert(resolve(user, nil, def) == ally and selected == ally)
	for _, reason in ipairs({"empty", "node", "out_of_range", "hostile", "dead"}) do
		ray = {reason = reason, target = reason == "empty" and nil or old}
		assert(resolve(user, {type = "object", ref = ally}, def) == user)
	end
	ray = {reason = "friendly", target = old} -- Friendly NPC is not an eligible player.
	assert(resolve(user, nil, def) == user)
	return "r20_input:friendly-current-ray:ok"
end
