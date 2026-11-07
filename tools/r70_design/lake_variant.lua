-- Design-only input transform. No game source or world is written.
-- The anchor and calm square stay fixed; only the capsule points move north.
local M = {}
M.shifts = {lethariel_crown_lake = 14, kezamba_cenote = 18}
function M.factory(path, shifted)
 local f = assert(io.open(path)); local source = f:read('*a'); f:close()
 local needle = 'local function lake(spec)'
 local injection = [[
  local shifts = {lethariel_crown_lake = %d, kezamba_cenote = %d}
  local dz = shifts[spec.id]
  if dz then
   spec.keep.half = 57
   if SHIFTED then
    for _, p in ipairs(spec.points) do p[2] = p[2] + dz end
   end
  end
 ]]
 injection = string.format(injection, M.shifts.lethariel_crown_lake, M.shifts.kezamba_cenote)
 injection = injection:gsub('SHIFTED', shifted and 'true' or 'false')
 local at = assert(source:find(needle, 1, true))
 source = source:sub(1, at + #needle - 1) .. injection .. source:sub(at + #needle)
 return assert(loadstring(source, '@design-only/' .. path))()
end
return M
