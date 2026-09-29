-- Portable fixture runner; development runs use LuaJIT:
--   luajit tools/r24_fill/micro.lua "$PWD"
local repo = assert(arg[1], "repository path required")
io.write(dofile(repo .. "/tools/r24_fill/fixture.lua")(repo))
