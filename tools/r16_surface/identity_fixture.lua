-- Exercise the real bounded source roster without changing any source file.
return function(repo)
 local path = repo .. "/mods/MAPGEN/grug_mapgen/wp40/preparation_identity.lua"
 local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
 local changed, reads = nil, 0
 local env = setmetatable({io = {open = function(name, mode)
  local f = assert(io.open(name, mode))
  local bytes = assert(f:read("*a")); f:close(); reads = reads + 1
  if changed and name:sub(-#changed) == changed then bytes = bytes .. "\n-- changed authority" end
  return {read = function() return bytes end, close = function() end}
 end}}, {__index = _G})
 local identity = setfenv(assert(loadfile(path)), env)()
 -- Collision-free identity function is sufficient to observe which actual
 -- source bytes reach the hash seam; production uses core.sha256.
 local function encode(s) return #s .. ":" .. s end
 local original = identity(directory, encode)
 assert(reads == 15)
 assert(identity(directory, encode) == original, "unchanged restart identity")
 for _, name in ipairs({"height.lua", "source/simple_map.lua", "zones.lua",
  "preparation_plan.lua", "preparation_source.lua"}) do
  changed = name
  assert(identity(directory, encode) ~= original, "unbound authority: " .. name)
 end
 return "surface-identity:15-files:stable-restart:terrain-layout-selector-mismatch:ok"
end
