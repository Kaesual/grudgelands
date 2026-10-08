-- Round 34 lane F1 portable test (mobs in water, round34-plan.md §2.3
-- ruling 1, §4.5). Loads the REAL code cut out of the vendored and grug
-- files under small stubs and checks:
--   A. the cliff/support probe of mobs/api.lua (is_node_dangerous,
--      grug_may_wade, has_safe_support, is_at_cliff) per state: ambient
--      stand/walk on land treats water as a drop; attack, runaway and the
--      evade run home pass harmless water; a mob already in water may move
--      on through it; lava (also for an immune mob), a damaging liquid and
--      water that hurts the mob always stay a boundary; fliers, swimmers and
--      the self-flying dragons are unchanged; solid ground and vegetation
--      over ground are support in every state; the navigation's cell test
--      (mobs/grug_nav.lua, Round 42, which replaced the close-obstacle
--      sidestep) keeps lava and damaging liquids a boundary too.
--   B. every mob definition that sets `floats` sets it to true (every
--      non-flier floats; the mob_class default is true as well).
--   C. grug_mobs/aggro.lua shore_check: an idle floating non-flier in water
--      is nudged toward its home once per tick; nothing happens on land, in a
--      fight, during the evade, for route carriers, rares, post guards,
--      fliers, dragons or a mob without a home; the leash tick runs it before
--      the roam cap and skips the roam cap when it nudged.
--   D. a mob floating in water facing a bank one node above the water rises
--      fast enough to step onto it (mobs/api.lua grug_bank_ahead in
--      falling()); a flush bank, open water and a two-node wall get no hop.
--
-- Usage (repo root): luajit tools/r34_f1/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- ---------------------------------------------------------------------------
-- A. the support probe (cut out of mobs/api.lua)
-- ---------------------------------------------------------------------------
local nodes = {
	air = {walkable = false, liquidtype = "none", groups = {}},
	ignore = {walkable = false, liquidtype = "none", groups = {}},
	stone = {walkable = true, liquidtype = "none", groups = {cracky = 3}},
	grass = {walkable = false, liquidtype = "none", groups = {flora = 1}},
	water = {walkable = false, liquidtype = "source",
		groups = {water = 3, liquid = 3}},
	water_flowing = {walkable = false, liquidtype = "flowing",
		groups = {water = 3, liquid = 3}},
	river_water = {walkable = false, liquidtype = "source",
		groups = {water = 3, liquid = 3}},
	lava = {walkable = false, liquidtype = "source", damage_per_second = 8,
		groups = {lava = 3, liquid = 2}},
	acid = {walkable = false, liquidtype = "source", damage_per_second = 2,
		groups = {liquid = 3}},
}

local api = read("mods/ENTITIES/mobs/api.lua")
local block = api:match("\n(local function is_node_dangerous%(self, nodename%).-"
	.. "\nfunction mob_class:is_at_cliff%(%).-\nend\n)")
check(block ~= nil, "A probe block found in api.lua")
check(block:find("local function grug_may_wade", 1, true) ~= nil,
	"A grug_may_wade sits inside the probe block")

-- The front column of a mob at (0, 0.5, 0) with yaw 0 and box half-width 0.3
-- is node x = 0, z = 1; the probe visits y = 1 (feet level) down to -1
-- (ambient 1.5) or deeper (the definition's fear_height).
local column = {}
local env = {
	floor = math.floor, ceil = math.ceil, sin = math.sin, cos = math.cos,
	mob_class = {}, mobs = {},
	mob_cbox = function(self) return self._grug_cbox end,
	core = {registered_nodes = nodes},
}
env.get_node = function(pos)
	if pos.x == 0 and pos.z == 1 and column[pos.y] then
		return {name = column[pos.y]}
	end
	return {name = pos.y <= 0 and "stone" or "air"}
end
local chunk = assert(loadstring(block))
setfenv(chunk, setmetatable(env, {__index = _G}))
chunk()
local mob_class = env.mob_class

local function set_front(spec)
	column = {}
	for y, name in pairs(spec) do column[y] = name end
end
local WATER = {[1] = "air", [0] = "water", [-1] = "water", [-2] = "stone"}
local function mob(fields)
	local self = {
		state = "stand", floats = true, fear_height = 2,
		water_damage = 0, lava_damage = 4, fire_damage = 4, node_damage = true,
		standing_on = "stone", standing_in = "air",
		_grug_cbox = {-0.3, 0, -0.3, 0.3, 0.8, 0.3},
		object = {
			get_yaw = function() return 0 end,
			get_pos = function() return {x = 0, y = 0.5, z = 0} end,
		},
	}
	for k, v in pairs(fields or {}) do self[k] = v end
	return setmetatable(self, {__index = mob_class})
end
local function cliff(fields)
	return mob(fields):is_at_cliff() == true
end

-- A1 ambient on land: water ahead is a drop, ground ahead is not.
set_front(WATER)
check(cliff({state = "stand"}), "A1 ambient stand avoids water")
check(cliff({state = "walk"}), "A1 ambient walk avoids water")
check(cliff({state = "walk", standing_in = "grass"}),
	"A1 ambient walk in grass avoids water")
set_front({[1] = "water_flowing", [0] = "water", [-1] = "stone"})
check(cliff({state = "walk"}), "A1 ambient walk avoids flowing water")
set_front({})
check(not cliff({state = "walk"}), "A1 ambient walk on ground")
set_front({[1] = "grass"})
check(not cliff({state = "walk"}), "A1 vegetation over ground is support")

-- A2 combat states pass harmless water.
set_front(WATER)
check(not cliff({state = "attack"}), "A2 attack passes water")
check(not cliff({state = "runaway"}), "A2 runaway passes water")
check(not cliff({state = "walk", temp = {grug_evading = {started = 0}}}),
	"A2 the evade run home passes water")
check(not cliff({state = "stand", temp = {grug_evading = {started = 0}}}),
	"A2 an evader standing still may move on through water")
set_front({[1] = "air", [0] = "river_water", [-1] = "stone"})
check(not cliff({state = "attack"}), "A2 attack passes river water")
check(cliff({state = "walk"}), "A2 ambient still avoids river water")
-- Water deeper than fear_height under the surface is still support.
set_front({[1] = "air", [0] = "water", [-1] = "water", [-2] = "water",
	[-3] = "water", [-4] = "water"})
check(not cliff({state = "attack"}), "A2 deep water is support for a swimmer")
-- A drop above the water larger than fear_height stays a cliff.
-- (fear_height 2 from feet 0.5 reaches node -2.)
set_front({[1] = "air", [0] = "air", [-1] = "air", [-2] = "air", [-3] = "water"})
check(cliff({state = "attack", fear_height = 2}),
	"A2 water below a drop beyond fear_height stays a cliff")

-- A3 a mob already in water may move on (ambient too), so it reaches land.
set_front(WATER)
check(not cliff({state = "stand", standing_on = "water", standing_in = "water"}),
	"A3 ambient in water moves on through water")
check(not cliff({state = "walk", standing_on = "water", standing_in = "air"}),
	"A3 bobbing at the surface (feet in water) counts as in water")
check(not cliff({state = "walk", standing_on = "stone", standing_in = "water"}),
	"A3 wading in a shallow (body in water) counts as in water")

-- A4 lava, damaging liquids and water that hurts the mob are boundaries.
set_front({[1] = "air", [0] = "lava", [-1] = "lava", [-2] = "stone"})
check(cliff({state = "attack"}), "A4 attack refuses lava")
check(cliff({state = "attack", lava_damage = 0}),
	"A4 attack refuses lava for a lava-immune mob")
check(cliff({state = "stand", lava_damage = 0, standing_on = "lava"}),
	"A4 a mob in lava does not wade on through lava")
set_front({[1] = "air", [0] = "acid", [-1] = "stone"})
check(cliff({state = "attack"}), "A4 attack refuses a damaging liquid")
check(cliff({state = "attack", node_damage = false}),
	"A4 a damaging liquid stays refused without node damage")
set_front(WATER)
check(cliff({state = "attack", water_damage = 4}),
	"A4 water that hurts the mob is refused in combat")
check(cliff({state = "walk", water_damage = 4,
	temp = {grug_evading = {started = 0}}}),
	"A4 water that hurts the mob is refused on the way home")

-- A5 fliers, swimmers and dragons keep their movement; a non-floater too.
check(mob({state = "attack", fly = true}):is_at_cliff() == nil,
	"A5 a flier never probes")
check(mob({state = "walk", fly = true, fly_in = "water"}):is_at_cliff() == nil,
	"A5 a water swimmer never probes")
check(cliff({state = "attack", keep_flying = true}),
	"A5 a self-flying dragon keeps water as a boundary")
check(cliff({state = "attack", floats = false}),
	"A5 a mob that does not float keeps water as a boundary")
check(mob({state = "attack", fear_height = 0}):is_at_cliff() == nil,
	"A5 fear_height 0 in combat still skips the probe")
check(mob({state = "stand", driver = {}}):is_at_cliff() == nil,
	"A5 a ridden mob never probes")

-- A6 solid ground and unknown terrain are unchanged in every state.
set_front({})
for _, state in ipairs({"stand", "walk", "attack", "runaway"}) do
	check(not cliff({state = state}), "A6 ground is support in " .. state)
end
set_front({[1] = "ignore"})
check(cliff({state = "attack"}), "A6 unloaded terrain stays a boundary")

-- A7 the navigation's cell test (Round 42 NV1 replaced the close-obstacle
-- sidestep): harmless liquid only for a wading mob, never lava or a
-- damaging liquid (behaviour: tools/r42_nv1 W5).
local nav_src = read("mods/ENTITIES/mobs/grug_nav.lua")
check(api:find("local function sidestep_safe", 1, true) == nil
	and nav_src:find("local ok = body.wades and not (groups and groups.lava)\n\t\t\tand (def.damage_per_second or 0) <= 0", 1, true) ~= nil,
	"A7 the navigation keeps the same liquid boundary")

-- ---------------------------------------------------------------------------
-- B. every floats field is true
-- ---------------------------------------------------------------------------
do
	local listing = io.popen("cd '" .. repo .. "' && ls mods/ENTITIES/*/*.lua")
	local files = 0
	for path in listing:lines() do
		files = files + 1
		local text = read(path)
		for value in text:gmatch("[^_%w]floats%s*=%s*([^,%s}]+)") do
			if path ~= "mods/ENTITIES/mobs/api.lua" or value ~= "def.floats" then
				check(value == "true", "B " .. path .. " floats = " .. value)
			end
		end
	end
	listing:close()
	check(files > 50, "B mob files scanned")
	check(api:find("\n\tfloats = true, %-%- floats in water") ~= nil,
		"B the mob_class default floats")
end

-- ---------------------------------------------------------------------------
-- C. shore_check (cut out of grug_mobs/aggro.lua)
-- ---------------------------------------------------------------------------
do
	local aggro = read("mods/ENTITIES/grug_mobs/aggro.lua")
	local cut = aggro:match("\n(local function in_liquid%(name%).-"
		.. "\nlocal function shore_check%(self%).-\nend\n)")
	check(cut ~= nil, "C shore_check found")
	local nudges = {}
	local cenv = {
		core = {registered_nodes = nodes},
		grug_mobs = {walk_toward = function(self, x, z, pos)
			nudges[#nudges + 1] = {self = self, x = x, z = z, pos = pos}
		end},
	}
	local cchunk = assert(loadstring(cut .. "\nreturn shore_check"))
	setfenv(cchunk, setmetatable(cenv, {__index = _G}))
	local shore_check = cchunk()
	local function idle(fields)
		local self = {
			state = "stand", floats = true,
			standing_on = "water", standing_in = "water",
			_grug_home = {x = 10, y = 5, z = -3},
			object = {get_pos = function() return {x = 0, y = 4, z = 0} end},
		}
		for k, v in pairs(fields or {}) do self[k] = v end
		return self
	end
	local function nudged(fields)
		nudges = {}
		local self = idle(fields)
		local result = shore_check(self)
		check((result == true) == (#nudges == 1), "C result matches the nudge")
		return #nudges == 1 and nudges[1].self == self and nudges[1].x == 10
			and nudges[1].z == -3
	end
	check(nudged(), "C idle in water swims home")
	check(nudged({state = "walk"}), "C walking in water swims home")
	check(nudged({standing_on = "water", standing_in = "air"}),
		"C bobbing at the surface swims home")
	check(nudged({standing_on = "stone", standing_in = "river_water"}),
		"C wading in a shallow swims home")
	check(not nudged({standing_on = "stone", standing_in = "air"}),
		"C nothing on land")
	check(not nudged({state = "attack"}), "C nothing in a fight")
	check(not nudged({attack = {}}), "C nothing with a target")
	check(not nudged({state = "runaway"}), "C nothing while fleeing")
	check(not nudged({following = {}}), "C nothing while following")
	check(not nudged({temp = {grug_evading = {started = 0}}}),
		"C nothing during the evade (it runs home already)")
	check(not nudged({_grug_patrol_route = {}}), "C nothing for a patroller")
	check(not nudged({_grug_rare_id = "grimtusk"}), "C nothing for a rare")
	check(not nudged({_grug_post_x = 3}), "C nothing for a post guard")
	check(not nudged({fly = true}), "C nothing for a flier or swimmer")
	check(not nudged({keep_flying = true}), "C nothing for a dragon")
	check(not nudged({floats = false}), "C nothing for a non-floater")
	check(not nudged({_grug_home = false}), "C nothing without a home")
	check(aggro:find("if not shore_check%(self%) then\n%s*roam_check%(self%)\n%s*end") ~= nil,
		"C the leash tick runs shore_check before the roam cap")
end

-- ---------------------------------------------------------------------------
-- D. climbing out onto a one-node bank (cut out of mobs/api.lua)
-- ---------------------------------------------------------------------------
do
	local cut = api:match("\n(local GRUG_CLIMB_RISE = %d+.-\nlocal function grug_bank_ahead%(self, pos%).-\nend\n)")
	check(cut ~= nil, "D grug_bank_ahead found")
	local front = {}
	local denv = {
		sin = math.sin, cos = math.cos,
		mob_cbox = function(self) return self._grug_cbox end,
		core = {registered_nodes = nodes},
		node_ok = function(pos)
			local y = math.floor(pos.y + 0.5)
			if pos.x == 0 and math.floor(pos.z + 0.5) == 1 and front[y] then
				return {name = front[y]}
			end
			return {name = "air"}
		end,
	}
	local dchunk = assert(loadstring(cut .. "\nreturn grug_bank_ahead, GRUG_CLIMB_RISE"))
	setfenv(dchunk, setmetatable(denv, {__index = _G}))
	local bank_ahead, rise = dchunk()
	-- Water surface node y = 0 (top 0.5); the mob floats with feet at 0.2.
	local self = {_grug_cbox = {-0.3, 0, -0.3, 0.3, 0.8, 0.3},
		object = {get_yaw = function() return 0 end}}
	local pos = {x = 0, y = 0.2, z = 0}
	front = {[0] = "stone", [1] = "stone"}
	check(bank_ahead(self, pos) == true, "D a bank one node above the water: hop")
	front = {[0] = "stone"}
	check(bank_ahead(self, pos) == false, "D a flush bank: no hop")
	front = {[0] = "stone", [1] = "stone", [2] = "stone"}
	check(bank_ahead(self, pos) == false, "D a two-node wall: no hop")
	front = {[0] = "water", [1] = "air"}
	check(bank_ahead(self, pos) == false, "D open water ahead: no hop")
	front = {[0] = "stone", [1] = "stone", [2] = "grass"}
	check(bank_ahead(self, pos) == true, "D a plant on the bank does not block the hop")
	-- The hop clears the step: v * v / (2 g) above the surface plus the
	-- quarter-node bob must exceed one node minus the smallest floating
	-- stepheight of 1 (the Shore Crab).
	check(rise * rise / (2 * 9.81) + 0.25 > 0.5 + 0.1,
		"D the hop lifts the feet over the stepheight line")
	check(api:find("local rise = grug_bank_ahead(self, pos) and GRUG_CLIMB_RISE or 0.45", 1, true) ~= nil,
		"D falling() rises at the hop speed facing a bank")
end

print(("R34 F1 PORTABLE PASS checks=%d"):format(checks))
