-- One bounded final-byte process for a WP13 settlement increment.
--
-- Runs every WP13 fixture in a single interpreter process and writes one
-- canonical TSV. The same bytes are run once under LuaJIT and once under the
-- engine's bundled PUC 5.1 build and the two outputs must be byte-identical
-- (docs/research/luanti-lua.md, "Interpreter and test strategy").
--
--     luajit tools/wp13/final_micro.lua <repo> <out.tsv> luajit
--     tools/bin/lua51 tools/wp13/final_micro.lua <repo> <out.tsv> puc51
--
-- The portable WP40 R7 micro-KAT body is deliberately NOT included. Its
-- `tools/wp40/r7/node_semantics_fixture.lua` reconstructs registered-node
-- semantics engine-free from `default`, `grug_trees`, `grug_materials`,
-- `grug_nodes`, `grug_gathering` and three hand-listed stairs shapes only, so
-- it cannot resolve a palette that also names `doors`, `beds`, `xpanes`,
-- `wool`, `vessels` or `walls` nodes. Teaching it the seven newly vendored
-- mods belongs to the WP40 lane that owns that fixture. Until then the live
-- engine run is the stronger evidence for the same property: R7's real
-- content manifest hard-fails on any unregistered Hearthpine palette name.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local output = assert(arg[2], "output path required")
local interpreter = assert(arg[3], "interpreter label required")
if (interpreter ~= "luajit" and interpreter ~= "puc51") or arg[4] ~= nil then
	error("WP13 final micro argument population differs", 0)
end

local common = dofile(repo .. "/tools/wp40/r6/common.lua")

local rows = {}
rows[#rows + 1] = dofile(repo .. "/tools/wp13/library_kat.lua")(repo)
rows[#rows + 1] = dofile(repo .. "/tools/wp13/blueprint_kat.lua")(repo)
rows[#rows + 1] = dofile(repo .. "/tools/wp13/highcourt_kat.lua")(repo)
-- The second capital, and the first walled one: the same acceptance as
-- Highcourt's for its core, its nine plots and its avenues, plus the four
-- curtain-wall rules only a wall needs (`dur_brannoc_kat.lua` section 4).
rows[#rows + 1] = dofile(repo .. "/tools/wp13/dur_brannoc_kat.lua")(repo)
-- What a capital's street does where a WP40 route passes over it. It belongs
-- to neither capital: `wp13/avenue.lua` is the road of both of them, and the
-- crossing rule is a property of the module, held to synthetic profiles the
-- real gate seeds do not all happen to contain.
-- The third capital, the second OPEN one and the only one with a lake inside
-- its civic core: the same acceptance as Highcourt's for its core, its 44
-- plots and its avenues, plus the three rules only this capital has -- the
-- mere, the grove edge and a permutation over three quarters rather than four
-- (`lethariel_kat.lua`).
rows[#rows + 1] = dofile(repo .. "/tools/wp13/lethariel_kat.lua")(repo)
rows[#rows + 1] = dofile(repo .. "/tools/wp13/lane_crossing_kat.lua")(repo)
-- Where a WP40 route STOPS. Playtest round 4 ruled that an incoming route ends
-- at a gate on the city boundary and no longer runs into the interior; this is
-- that sentence held against the compiled layout, which is the same on every
-- world. Its terrain half needs a seed and lives in
-- `tools/wp13/route_gates.lua`.
rows[#rows + 1] = dofile(repo .. "/tools/wp13/route_gates_kat.lua")(repo)
-- The settlement seam itself: roster-derived manifest order, bounds per slot,
-- several blueprints per settlement, the terrain-relative projection against a
-- stub height function, and lazy build/release (contract section 2.2).
rows[#rows + 1] = dofile(repo .. "/tools/wp13/seam_kat.lua")(repo)
rows[#rows + 1] = "wp13_integration\t" ..
	dofile(repo .. "/tools/wp13/integration_fixture.lua")(repo) .. "\n"
-- Last, and last on purpose: the socket-registry KAT drives real grug_core
-- code, so it installs stub `core`/`vector`/`grug_core` globals and restores
-- them again. Running it after the three pure fixtures keeps their
-- environment untouched. "Pure" is the four above it: the library, the
-- blueprint, the Highcourt and the integration fixtures, none of which
-- installs a global.
rows[#rows + 1] = dofile(repo .. "/tools/wp13/settlement_sockets_kat.lua")(repo)
-- Same reason, same treatment: this one drives grug_mobs' placement engine
-- against a stub engine and restores `core`/`grug_core`/`grug_mobs` again.
rows[#rows + 1] = dofile(repo .. "/tools/wp13/start_npcs_kat.lua")(repo)
local text = table.concat(rows)
local digest = common.hex(common.new_sha256()(text))

local probe = io.open(output, "rb")
if probe then
	probe:close()
	error("WP13 final micro output exists", 0)
end
local file = assert(io.open(output, "wb"))
assert(file:write(text))
assert(file:close())
io.write("WP13 final micro PASS interpreter=", interpreter,
	" output_sha256=", digest, "\n")
