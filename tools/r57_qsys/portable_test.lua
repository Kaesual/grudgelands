-- Round 57 lane QSYS portable test (LuaJIT): the quest system's new
-- foundation (round57-plan.md §2 rulings 9-17, §4 QSYS; quests.md). Two
-- parts, each in its own process (their engine stubs differ):
--   quality_test.lua  the real grug_quality's authored stacks and the shared
--                     tooltip-text helper;
--   quest_test.lua    the real grug_quests on the sample data of
--                     tools/r57_qsys/samples.
--
--   luajit tools/r57_qsys/portable_test.lua [REPO]
-- Prints "R57 QSYS PORTABLE PASS" or the failures (exit 1).
local ROOT = arg and arg[1] or "."
local failed = false
for _, part in ipairs({"quality_test.lua", "quest_test.lua"}) do
	local handle = io.popen(('luajit "%s/tools/r57_qsys/%s" "%s" 2>&1'):format(ROOT, part, ROOT))
	local output = handle:read("*a")
	handle:close()
	io.write(output)
	if not output:find(" PASS checks=%d+") then failed = true; print("FAIL part " .. part) end
end
if failed then error("R57 QSYS PORTABLE FAIL", 0) end
print("R57 QSYS PORTABLE PASS")
