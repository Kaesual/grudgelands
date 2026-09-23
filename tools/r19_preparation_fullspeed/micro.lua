-- Compact final-byte parity fixture; development runs use LuaJIT.
local repo = assert(arg[1], "repository path required")
io.write(dofile(repo .. "/tools/r19_preparation_fullspeed/fixture.lua")(repo))
