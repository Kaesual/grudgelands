-- Round 73 lane TOOLS portable test (LuaJIT): the authoring helpers and the one shared
-- proof (tools/expedition_templates/proofs.lua).
--
--   luajit tools/r73_tools/portable_test.lua [REPO]
--
-- cases.py (Python, run here) checks the helpers on hand-made maps, every refusal of
-- the relief helper included, and writes small templates: `base` meets every rule of the
-- proof, each other breaks one. This half proves them: on `base` every rule passes, on
-- each broken one its rule fails; the packs rule fails on `base` with a way round asked
-- for. The relief rule reads the stairs relief.py wrote with its own quarter rule, so the
-- two derivations of a stair's shape and param2 check each other.
-- Prints "R73 TOOLS PORTABLE PASS checks=<n>".
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local handle = io.popen("mktemp -d")
local dir = handle:read("*l")
handle:close()
handle = io.popen(("python3 '%s/tools/r73_tools/cases.py' '%s' 2>&1"):format(repo, dir))
local said = handle:read("*a")
handle:close()
io.write(said)
check(said:match("CASES OK"), "the helpers' cases: " .. said)

local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 1048576), ffi.new("unsigned long[1]", 1048576)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local PR = dofile(repo .. "/tools/expedition_templates/proofs.lua")
local registry = PR.registry(repo)
local DOOR = "grug_expeditions:reward_door"

-- The cases' rooms (cases.py base): a spider at 12,12 over its room, the golem boss at
-- 22,24 over the corner beyond the rise; the drift's mouth into room A; one ambush of
-- two zombies (zombie.lua: 1.89 tall) in the drift, past the spider holding its mouth (the
-- ambush is never the first fight).
local function in_box(x0, z0, x1, z1) return function(x, z) return x >= x0 and x <= x1 and z >= z0 and z <= z1 end end
local function spec_for(name)
	return {name = name, tallest = 1.7 * 1.4, mouths = {{27, 13}, {27, 14}}, ambushes = 1,
		sizes = {["grug_mobs:zombie"] = {1, 1.89}}, packs = {
		pack = {spots = {{x = 12, z = 12, view = 12, eye = 1.75}}, room = in_box(8, 8, 16, 16)},
		gate = {spots = {{x = 31, z = 13, view = 12, eye = 1.75}}, room = in_box(28, 12, 35, 15)},
		boss = {spots = {{x = 22, z = 24, view = 16, eye = 2.4}}, room = in_box(20, 21, 27, 27)},
	}}
end
local function prove(name, spec)
	local file = assert(io.open(dir .. "/" .. name .. ".exp", "rb"))
	local tpl = T.parse(file:read("*a"), inflate, name)
	file:close()
	local map = PR.map(tpl, registry, {open = {[DOOR] = true}})
	return PR.prove(map, spec or spec_for(name)), map
end

-- base: every rule holds, the stairs among them (normal, inner and outer).
local report, map = prove("base")
PR.enforce(report, check)
local shapes = {}
for _, cell in ipairs(map.list) do
	local f = map.node(cell.x, cell.h - 1, cell.z)
	if f.stair then shapes[f.stair] = (shapes[f.stair] or 0) + 1 end
end
check(shapes.normal and shapes.inner and shapes.outer, "base: stairs of all three shapes")
check(#report.rules.lava.problems == 0 and report.rules.lava.notes[1] ~= "0 lava cells", "base: its lava fall holds")
check(#map.tpl.ambushes == 1 and #map.tpl.particles == 1, "base: an ambush and a particle box, read by template.lua")

-- Each broken template fails its rule.
local BROKEN = {surface = "a hole in the hull", relief = "a stair facing the high side",
	free_height = "a rock at the head", head_room = "a rock a node over the head", perches = "a free table",
	dressing = "a cobweb on a walking cell", route = "a marker in a sealed pocket",
	light = "the pack's and the arrival's lanterns gone", sight = "a dark corner with no light in sight",
	lava = "lava open to the floor", traps = "a floor trap beside a stair",
	ambush = "a zone half the drift's width", particles = "a particle box in the rock",
	perches_rail = "a free table in a nook behind a rail"}
local RULE_OF = {perches_rail = "perches"}
local names = {}
for name in pairs(BROKEN) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
	local r = prove(name)
	local also = {}
	for _, id in ipairs(PR.RULES) do
		if id ~= (RULE_OF[name] or name) and #r.rules[id].problems > 0 then also[#also + 1] = id end
	end
	local rule = r.rules[RULE_OF[name] or name]
	print(("case %-11s %s: %s%s"):format(name, BROKEN[name], rule.problems[1] or "-",
		#also > 0 and (" (also " .. table.concat(also, ", ") .. ")") or ""))
	check(#rule.problems > 0, "case " .. name .. " fails its rule")
end
-- The packs: the spider can be walked round from the room's south-east to its
-- north-west (its view does not reach the corners), so a way round is found.
local spec = spec_for("base")
spec.packs.pack.ways = {{25, 6}, {6, 25}}
local walked = prove("base", spec)
print("case packs       a way round the spider: " .. (walked.rules.packs.problems[1] or "-"))
check(#walked.rules.packs.problems > 0, "case packs fails its rule")
-- The ambush is never the first fight (user, 2026-11-10): without the spider holding the
-- drift's mouth, a walk from the arrival reaches the zone past no pack room.
spec = spec_for("base")
spec.packs.gate = nil
local first = prove("base", spec).rules.ambush.problems
print("case first fight no pack before the drift: " .. (first[1] or "-"))
check(#first > 0 and first[1]:find("first fight", 1, true), "case first fight fails the ambush rule")
-- The switch: a rule reported only does not fail the fixture.
local reported = PR.enforce(prove("light"), function() end, {light = true})
check(reported == 1, "the switch reports the light rule only")

io.popen("rm -rf '" .. dir .. "'"):close()

-- The hidden test vault (lane GAME's probe, sources/test_vault.py) with every rule on.
-- It is a probe, not an Expedition: what it does not meet is reported, by rule, and
-- the rest holds. Its ambush lies in its first drift on purpose (no pack before it);
-- its trap gallery is closed (probes stand players in it), so its floor traps lie off
-- the walked floor; its passages and torches keep Round 72's three nodes; its lit hall
-- is no fighting floor at 4; its fall's foot is written open at the feet row.
do
	local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/test_vault.exp", "rb"))
	local tpl = T.parse(file:read("*a"), inflate, "test_vault")
	file:close()
	local vault = PR.map(tpl, registry, {open = {[DOOR] = true}})
	local spots = {}
	for _, row in ipairs(tpl.encounters) do
		if row.room == "hall" or row.room == "court" then
			for i = 1, row.count do
				-- spider.lua -0.75, golem.lua -1 at the boss's (elite) 1.4: their looks' starts.
				spots[#spots + 1] = {x = row.pos.x + PR.SPREAD[i][1], z = row.pos.z + PR.SPREAD[i][2],
					view = row.room == "hall" and 12 or 16, eye = row.room == "hall" and 1.75 or 2.4}
			end
		end
	end
	local VAULT_REPORT = {head_room = true, light = true, lava = true, traps = true, ambush = true}
	local r = PR.prove(vault, {name = "test_vault", tallest = 1.7 * 1.4, ambushes = 1, report = VAULT_REPORT,
		sizes = {["grug_mobs:zombie"] = {1, 1.89}},
		packs = {hall = {spots = spots, room = function(x, z) return x >= 28 and x <= 39 and z >= 8 and z <= 24 end}}})
	PR.enforce(r, check, VAULT_REPORT)
	check(#r.rules.ambush.problems > 0 and r.rules.ambush.problems[1]:find("first fight", 1, true),
		"the vault's ambush is its first fight, and nothing else of the rule fails: " .. (r.rules.ambush.problems[2] or ""))
	check(#r.rules.ambush.problems == 1, "the vault's ambush fails only the first fight")
end
print(("R73 TOOLS PORTABLE PASS checks=%d"):format(checks))
