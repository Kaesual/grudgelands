-- Portable fixture runner; development runs use LuaJIT:
--   luajit tools/r23_full_column/micro.lua "$PWD"
local repo = assert(arg[1], "repository path required")
io.write(dofile(repo .. "/tools/r23_full_column/fixture.lua")(repo))
