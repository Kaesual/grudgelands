-- One bounded final-byte process for a WP13 settlement increment.
--
-- Runs the three WP13 fixtures in a single interpreter process and writes one
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
rows[#rows + 1] = "wp13_integration\t" ..
	dofile(repo .. "/tools/wp13/integration_fixture.lua")(repo) .. "\n"
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
