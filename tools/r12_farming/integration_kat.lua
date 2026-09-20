local repo = assert(arg[1], "repository path required")
local result = assert(loadfile(repo ..
	"/tools/r10_farm/farming_completion_kat.lua"))()(repo)
local renamed = result:gsub("r10_farming", "r12_farming_integration", 1)
io.write(renamed)
