-- Compact final candidate: exercise the production scheduler through its fixture.
local repo = assert(arg[1], "repository path required")
io.write(dofile(repo .. "/tools/r18_preparation/fixture.lua")(repo))
