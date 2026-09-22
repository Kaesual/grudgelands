-- Callable Round 16 progression fixture. LuaJIT owns development runs; the
-- coordinator may use this same entry point for the final interpreter pair.

local root = arg[1] or "."

dofile(root .. "/tools/r15_quests/check_catalog.lua")
dofile(root .. "/tools/r14_quests/core_kat.lua")
dofile(root .. "/tools/r16_progression/runtime_kat.lua")
io.write("R16_PROGRESSION_OK\n")
