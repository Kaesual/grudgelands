-- Round 25 Lane G portable fixture (LuaJIT): ruling 24, no hostile spawns in
-- an active housing claim, against fake claims.
--
--   luajit tools/r25_spawn_guard/fixture.lua "$PWD"
--
-- 1. Loads the real spawn roster (tools/r24_density_xp/roster.lua: the real
--    spawn_policy.lua, density.lua and every mob file init.lua loads) and
--    prints which registered mobs a claim refuses (the hostile role) and
--    which it never refuses (neutral prey, passive critters, fish, NPCs).
-- 2. grug_mobs.claim_refuses_spawn on fake claims: an active and an expired
--    claim, no claim, the ±50 edge, the corner, the y floor, no housing mod;
--    exactly one claim_at call per hostile attempt and none otherwise.
-- 3. The three real call sites, cut verbatim out of their files and run on
--    stubs: init.lua mobs:spawn_abm_check (policy first, then the claim; the
--    palette density budget that followed went in Round 30 lane P2; the
--    stand position is the matched node + 1),
--    camps.lua spawn_one (a refused slot is "not served", guards pass) and
--    rares.lua try_spawn (a refused rare is not placed and not marked alive).
-- 4. The spawn policy is claim-agnostic: spawn_policy_allows and
--    spawn_allowed never consult the claim (the claim is its own check after
--    them). The Round 24 zone density budget this section also compared is
--    gone in practice since the Round 28 spawn recipes: no zone keeps a
--    palette cast (Round 30 lane C).
-- Prints "R25 SPAWN GUARD FIXTURE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit fixture.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- 1. Roster and the hostile definition
-- ---------------------------------------------------------------------------
local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
check(#roster.failed == 0, "every mob file loads: " .. table.concat(roster.failed, "; "))
local gm = roster.grug_mobs
check(type(gm.claim_refuses_spawn) == "function", "claim_refuses_spawn exported")

-- Fake claim core. Claims are 101 x 101 columns (±50) from MIN_Y upward.
local RADIUS, MIN_Y = 50, -100
local NOW = 1000000
local CLAIMS = {
	{id = 1, owner = "alice", center = {x = 1000, y = 20, z = 1000},
		placed_at = NOW - 10, paid_until = NOW + 3600},
	{id = 2, owner = "bob", center = {x = 2000, y = 20, z = 1000},
		placed_at = NOW - 7200, paid_until = NOW - 1}, -- expired
}
local claim_at_calls = 0
local function fake_housing()
	return {
		RADIUS = RADIUS, MIN_Y = MIN_Y,
		claim_at = function(pos)
			claim_at_calls = claim_at_calls + 1
			if pos.y < MIN_Y then return nil end
			for i = 1, #CLAIMS do
				local c = CLAIMS[i].center
				if math.abs(pos.x - c.x) <= RADIUS and math.abs(pos.z - c.z) <= RADIUS then
					return CLAIMS[i]
				end
			end
			return nil
		end,
		is_active = function(claim) return claim.paid_until > NOW end,
	}
end
_G.grug_housing = fake_housing()

local ACTIVE = {x = 1000, y = 21, z = 1000}
local EXPIRED = {x = 2000, y = 21, z = 1000}
local FREE = {x = 3000, y = 21, z = 1000}

local refused, spared = {}, {}
local names = {}
for name in pairs(roster.defs) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
	local before = claim_at_calls
	local no = gm.claim_refuses_spawn(name, ACTIVE)
	local calls = claim_at_calls - before
	if no then
		refused[#refused + 1] = name:gsub("^grug_mobs:", "")
		check(calls == 1, name .. ": one claim_at call per hostile attempt")
	else
		spared[#spared + 1] = name:gsub("^grug_mobs:", "")
		check(calls == 0, name .. ": no claim_at call for a non-hostile mob")
	end
	-- The claim role is exactly the start-footprint hostile role minus NPCs.
	local def = roster.defs[name]
	check(no == (gm.spawn_role_hostile(name) and def.type ~= "npc"),
		name .. ": claim role = hostile role minus type npc")
end
print(("refused in an active claim (%d): %s"):format(#refused, table.concat(refused, " ")))
print(("never refused (%d): %s"):format(#spared, table.concat(spared, " ")))

local function is_refused(short) return gm.claim_refuses_spawn("grug_mobs:" .. short, ACTIVE) end
-- Hostile wildlife, night families, cave rows, camp and rare families.
for _, short in ipairs({"zombie", "wolf", "bear", "giant_spider", "skeleton_archer",
		"bog_ooze", "wisp", "poacher", "goblin_raider", "oerkki", "stone_mite",
		"rift_spawn", "kraken", "bandit", "bandit_archer", "mirefolk",
		"plaguehide_bear", "stone_golem", "jungle_spider", "serpent",
		"skeleton_raider"}) do
	check(roster.defs["grug_mobs:" .. short] ~= nil, short .. " is registered")
	check(is_refused(short), short .. " is refused in an active claim")
end
-- Passive critters, neutral prey that only fights back, fish, NPC guards.
for _, short in ipairs({"rabbit", "stag", "boar", "cave_bat", "mountain_ram", "zebra", "shore_crab",
		"reed_angelfish", "guard_accord", "guard_throng"}) do
	check(roster.defs["grug_mobs:" .. short] ~= nil, short .. " is registered")
	check(not is_refused(short), short .. " is never refused")
end
check(not gm.claim_refuses_spawn("grug_mobs:villager_human", ACTIVE),
	"villagers (no grug spawn role) are never refused")

-- ---------------------------------------------------------------------------
-- 2. Active, expired, no claim; edge, corner, y floor, housing absent
-- ---------------------------------------------------------------------------
local HOSTILE, PASSIVE = "grug_mobs:zombie", "grug_mobs:rabbit"
local function at(dx, dz, y, base)
	base = base or ACTIVE
	return {x = base.x + dx, y = y or base.y, z = base.z + dz}
end
check(gm.claim_refuses_spawn(HOSTILE, ACTIVE), "active claim: hostile refused")
check(not gm.claim_refuses_spawn(PASSIVE, ACTIVE), "active claim: passive spawns")
check(not gm.claim_refuses_spawn(HOSTILE, EXPIRED), "expired claim: hostile spawns")
check(not gm.claim_refuses_spawn(PASSIVE, EXPIRED), "expired claim: passive spawns")
check(not gm.claim_refuses_spawn(HOSTILE, FREE), "no claim: hostile spawns")
for _, d in ipairs({50, -50}) do
	check(gm.claim_refuses_spawn(HOSTILE, at(d, 0)), "edge x " .. d .. " inside")
	check(gm.claim_refuses_spawn(HOSTILE, at(0, d)), "edge z " .. d .. " inside")
	local out = d > 0 and d + 1 or d - 1
	check(not gm.claim_refuses_spawn(HOSTILE, at(out, 0)), "x " .. out .. " outside")
	check(not gm.claim_refuses_spawn(HOSTILE, at(0, out)), "z " .. out .. " outside")
end
check(gm.claim_refuses_spawn(HOSTILE, at(50, 50)), "corner (50, 50) inside")
check(gm.claim_refuses_spawn(HOSTILE, at(-50, -50)), "corner (-50, -50) inside")
check(not gm.claim_refuses_spawn(HOSTILE, at(51, 50)), "corner (51, 50) outside")
check(not gm.claim_refuses_spawn(HOSTILE, at(50, -51)), "corner (50, -51) outside")
check(gm.claim_refuses_spawn(HOSTILE, at(10, 10, 300)), "high above the stone: inside")
check(gm.claim_refuses_spawn(HOSTILE, at(10, 10, -60)), "cave at y -60: inside")
check(gm.claim_refuses_spawn(HOSTILE, at(10, 10, MIN_Y)), "y = MIN_Y: inside")
check(not gm.claim_refuses_spawn(HOSTILE, at(10, 10, MIN_Y - 1)), "y = MIN_Y - 1: outside")
check(not gm.claim_refuses_spawn(HOSTILE, at(49, 0, nil, EXPIRED)), "expired edge: spawns")
_G.grug_housing = nil
local before = claim_at_calls
check(not gm.claim_refuses_spawn(HOSTILE, ACTIVE), "no housing mod: nothing refused")
check(claim_at_calls == before, "no housing mod: no lookup")
_G.grug_housing = fake_housing()
-- The Lane A stub on main (claim_at returns nil) refuses nothing.
_G.grug_housing = {claim_at = function() return nil end, is_active = function() return false end}
check(not gm.claim_refuses_spawn(HOSTILE, ACTIVE), "main's interface stub refuses nothing")
-- Round 26 ruling 8, with the REAL claim model: a draft refuses no spawn, the
-- same claim does once activated.
do
	local data = {}
	local model = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
		storage = {get_string = function(k) return data[k] or "" end,
			set_string = function(k, v) data[k] = v ~= "" and v or nil end,
			keys = function() return {} end},
		now = function() return NOW end})
	model.load()
	_G.grug_housing = {claim_at = model.claim_at, is_active = model.is_active}
	local claim = model.create("carol", {x = 5000, y = 20, z = 5000})
	local spot = {x = 5020, y = 21, z = 4980}
	check(model.is_draft(claim) and not gm.claim_refuses_spawn(HOSTILE, spot),
		"R26: a draft refuses no hostile spawn")
	model.activate(claim, 5)
	check(gm.claim_refuses_spawn(HOSTILE, spot), "R26: the activated claim refuses it")
end
_G.grug_housing = fake_housing()

-- ---------------------------------------------------------------------------
-- 3. The real call sites, cut out of their files
-- ---------------------------------------------------------------------------
local function extract(file, header, replacement, env)
	local source = assert(io.open(repo .. "/" .. file)):read("*a")
	local start = assert(source:find(header, 1, true), file .. ": " .. header)
	local stop = assert(source:find("\nend\n", start, true), file .. ": end of " .. header)
	local body = replacement .. source:sub(start + #header, stop + 4)
	local chunk = assert(loadstring(body, "=" .. file))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

-- 3a. init.lua mobs:spawn_abm_check (true = block).
local allowed_calls = {}
local policy_ok = true
local abm_gm = setmetatable({}, {__index = gm})
local abm_check = extract("mods/ENTITIES/grug_mobs/init.lua",
	"function mobs:spawn_abm_check(pos, node, name)", "return function(self, pos, node, name)", {
		grug_mobs = abm_gm,
		spawn_allowed = function(name, pos)
			allowed_calls[#allowed_calls + 1] = {name = name, y = pos.y}
			return policy_ok
		end,
	})
local node = {name = "default:dirt_with_grass"}
local function abm(name, ground)
	allowed_calls = {}
	local calls0 = claim_at_calls
	local pos = {x = ground.x, y = ground.y, z = ground.z}
	local blocked = abm_check(nil, pos, node, name) == true
	check(pos.y == ground.y and pos.x == ground.x, "abm check leaves the ABM position alone")
	return blocked, claim_at_calls - calls0
end
local ground = {x = ACTIVE.x, y = ACTIVE.y - 1, z = ACTIVE.z}
local blocked, lookups = abm(HOSTILE, ground)
check(blocked and lookups == 1, "abm: hostile in active claim blocked, one lookup")
check(allowed_calls[1] and allowed_calls[1].y == ground.y, "abm: policy sees the ABM node")
blocked, lookups = abm(PASSIVE, ground)
check(not blocked and lookups == 0, "abm: passive in active claim spawns")
blocked, lookups = abm(HOSTILE, {x = EXPIRED.x, y = EXPIRED.y - 1, z = EXPIRED.z})
check(not blocked and lookups == 1, "abm: hostile in expired claim spawns")
blocked, lookups = abm(HOSTILE, {x = FREE.x, y = FREE.y - 1, z = FREE.z})
check(not blocked and lookups == 1, "abm: hostile outside claims spawns")
blocked, lookups = abm(HOSTILE, {x = ACTIVE.x + 51, y = 20, z = ACTIVE.z})
check(not blocked and lookups == 1, "abm: hostile one column past the edge spawns")
blocked = abm(HOSTILE, {x = ACTIVE.x - 50, y = 20, z = ACTIVE.z + 50})
check(blocked, "abm: hostile on the edge corner blocked")
-- Stand position = matched node + 1: a node at MIN_Y - 1 puts the mob at MIN_Y.
check(abm(HOSTILE, {x = ACTIVE.x, y = MIN_Y - 1, z = ACTIVE.z}), "abm: stand y = MIN_Y blocked")
check(not abm(HOSTILE, {x = ACTIVE.x, y = MIN_Y - 2, z = ACTIVE.z}),
	"abm: stand y = MIN_Y - 1 spawns")
policy_ok = false
blocked, lookups = abm(HOSTILE, ground)
check(blocked and lookups == 0, "abm: policy refusal first, no lookup")
policy_ok = true

-- 3b. camps.lua spawn_one (false = slot not served, due time untouched).
local added, spot_next = {}, nil
local spawn_one = extract("mods/ENTITIES/grug_mobs/camps.lua",
	"local function spawn_one(pos, meta, cfg, living)",
	"return function(pos, meta, cfg, living)", {
		free_spot_near = function() return spot_next end,
		assign_patrol = function() end,
		grug_mobs = setmetatable({add_mob = function(pos, def)
			added[#added + 1] = {pos = pos, name = def.name}
			return {object = {}}
		end}, {__index = gm}),
	})
local camp_pos = {x = ACTIVE.x, y = 20, z = ACTIVE.z}
local bandit_cfg = {mob = "grug_mobs:bandit", radius = 12}
local guard_cfg = {mob = "grug_mobs:guard_accord", radius = 15}
spot_next = {x = ACTIVE.x + 3, y = 21, z = ACTIVE.z}
added = {}
check(spawn_one(camp_pos, {}, bandit_cfg, 0) == false and #added == 0,
	"camp: bandit slot in an active claim not served")
check(spawn_one(camp_pos, {}, guard_cfg, 1) == true and #added == 1,
	"camp: guard slot in an active claim served")
spot_next = {x = ACTIVE.x + 51, y = 21, z = ACTIVE.z}
check(spawn_one(camp_pos, {}, bandit_cfg, 0) == true and #added == 2,
	"camp: bandit slot beyond the edge served")
spot_next = {x = EXPIRED.x, y = 21, z = EXPIRED.z}
check(spawn_one(camp_pos, {}, {mob = "grug_mobs:mirefolk", radius = 10}, 0) == true
	and #added == 3, "camp: mirefolk slot in an expired claim served")

-- 3c. rares.lua try_spawn (refused: no add, no alive mark, retried next pass).
local marked, rare_added = 0, 0
local try_spawn = extract("mods/ENTITIES/grug_mobs/rares.lua",
	"local function try_spawn(id, spec)", "return function(id, spec)", {
		player_near_xz = function() return true end,
		PLAYER_RANGE = 120,
		-- Round 37 MP: liveness.lua answers "already out there" and stamps
		-- the generation.
		liveness = {instance = function() return nil end, adopt = function() end,
			next_generation = function() return 1 end},
		live_key = function(id) return "rare:" .. id end,
		route_pos = function(pt) return pt end,
		mark_alive = function() marked = marked + 1 end,
		broadcast = function() end,
		core = {log = function() end, pos_to_string = function() return "" end},
		vector = {round = function(p) return p end},
		grug_mobs = setmetatable({
			add_mob = function() rare_added = rare_added + 1; return {object = {
				set_properties = function() end}} end,
			set_tier = function() end,
			place_on_ground = function() end,
		}, {__index = gm}),
	})
try_spawn("r1", {mob = "grug_mobs:wolf", name = "Rare", route = {ACTIVE}})
check(rare_added == 0 and marked == 0, "rare: hostile rare in an active claim not placed")
try_spawn("r1", {mob = "grug_mobs:wolf", name = "Rare", route = {EXPIRED}})
check(rare_added == 1 and marked == 1, "rare: hostile rare in an expired claim placed")
try_spawn("r1", {mob = "grug_mobs:wolf", name = "Rare", route = {FREE}})
check(rare_added == 2 and marked == 2, "rare: hostile rare outside claims placed")

-- ---------------------------------------------------------------------------
-- 4. The spawn policy never sees the claim
-- ---------------------------------------------------------------------------
_G.grug_core = {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	-- Round 28 ruling 3 (protected spawn surface): no road or village here.
	world_feature_at = function() return nil end,
	start_identities = function()
		local out = {}
		for i = 1, 6 do out[i] = {anchor = {x = -90000 + i * 1000, y = 0, z = -90000}} end
		return out
	end}
_G.grug_zones = {
	id_at = function() return "elandor_moonfall_wood" end,
	biome_at = function() return "grug_deciduous_forest" end,
	mob_level_at = function() return 25 end,
	race_region_at = function() return "human" end,
	pvp_rule_at = function() return "peaceful" end,
	faction_at = function() return "accord" end,
	anchor = function() return nil end,
}
_G.core = {
	settings = {get = function() return nil end, get_bool = function() return nil end},
	get_timeofday = function() return 0.5 end,
	get_item_group = function() return 1 end,
	log = function() end,
}
local calls0 = claim_at_calls
-- Row checks read further zone queries and engine calls; any stub answer
-- does, since only the claim lookups are counted.
local function nothing() return nil end
setmetatable(_G.grug_zones, {__index = function() return nothing end})
setmetatable(_G.core, {__index = function() return nothing end})
for _, name in ipairs(names) do
	gm.spawn_policy_allows(name, ACTIVE)
	pcall(roster.spawn_allowed, name, ACTIVE)
end
check(claim_at_calls == calls0, "spawn_policy_allows / spawn_allowed never look up a claim")

print(("R25 SPAWN GUARD FIXTURE PASS checks=%d"):format(checks))
