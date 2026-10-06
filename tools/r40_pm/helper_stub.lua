-- Round 40 PM: the REAL particle helper and catalogue
-- (grug_core/particles.lua, particle_effects.lua) for a fixture's fake
-- engine. They load into a private environment with their own small vector
-- library and grug_particle_scale `scale` (default unset = 1.0); their engine
-- calls go to the fixture's global `core` as it is at call time, so a
-- fixture's add_particle / add_particlespawner recorder sees every particle.
--
--   grug_core.particles = dofile(repo .. "/tools/r40_pm/helper_stub.lua")(repo)
return function(repo, scale)
	local vector = {}
	function vector.new(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x or 0, y = y or 0, z = z or 0}
	end
	function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
	function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
	function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
	function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
	local function engine(name)
		return function(def)
			local fake = rawget(_G, "core")
			if fake and fake[name] then return fake[name](def) end
		end
	end
	local env = setmetatable({
		vector = vector,
		grug_core = {},
		core = {
			settings = {get = function(_, key)
				if key == "grug_particle_scale" then return scale end
			end},
			add_particle = engine("add_particle"),
			add_particlespawner = engine("add_particlespawner"),
			yaw_to_dir = function(yaw) return vector.new(-math.sin(yaw), 0, math.cos(yaw)) end,
			log = function() end,
		},
	}, {__index = _G})
	for _, file in ipairs({"particles.lua", "particle_effects.lua"}) do
		local chunk = assert(loadfile(repo .. "/mods/CORE/grug_core/" .. file))
		setfenv(chunk, env)
		chunk()
	end
	return env.grug_core.particles
end
