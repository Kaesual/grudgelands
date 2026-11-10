-- Read-only comparison against the state before this table/bed follow-up.
-- Redirect only the changed template reads and two runtime helper sources.
local repo = arg[1] or "."
local here = repo .. "/tools/capital_polish_study/implementation/"
local open, run = io.open, dofile
local function exists(path)
 local f = open(path, "rb")
 if not f then return false end
 f:close()
 return true
end
io.open = function(path, mode)
 local name = path:match("/building_templates/templates/([^/]+%.tpl)$")
 if name then
  for _, folder in ipairs({"all_tables/before/", "beds/before/"}) do
   local saved = here .. folder .. name
   if exists(saved) then return open(saved, mode) end
  end
 end
 return open(path, mode)
end
dofile = function(path)
 local name = path:match("/wp13/(parts%.lua)$") or path:match("/wp13/(dressing%.lua)$")
 if name then return run(here .. "all_tables/runtime-before/" .. name) end
 return run(path)
end
run(repo .. "/tools/r36_w2/portable_test.lua")
