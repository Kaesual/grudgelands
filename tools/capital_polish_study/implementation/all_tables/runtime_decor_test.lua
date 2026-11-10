-- Run the existing decor-kit section without the unrelated socket baseline.
local repo = arg[1] or "."
local path = repo .. "/tools/r36_w/portable_test.lua"
local f = assert(io.open(path, "rb"))
local source = f:read("*a")
f:close()
local start = assert(source:find("-- D. the decor kit", 1, true))
local finish = assert(source:find("-- E. windows and headroom", start, true))
local prelude = source:sub(1, assert(source:find("-- A. benches", 1, true)) - 1)
local section = source:sub(start, finish - 1)
assert(loadstring(prelude .. section .. '\nprint("existing r36_w decor section: " .. checks .. " PASS")', "@" .. path))()
