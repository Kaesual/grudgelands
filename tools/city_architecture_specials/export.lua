-- Export actual placed parts, including runtime planting and late cells.
local root, manifest = assert(arg[1]), assert(arg[2])
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp13"
local templates = dofile(wp .. "/templates.lua")(wp)
local palettes = dofile(wp .. "/palette.lua")
local parts = dofile(wp .. "/parts.lua")
for index, job in ipairs(dofile(manifest)) do
 local file = assert(io.open(job.source_file or (root .. "/mods/MAPGEN/grug_mapgen/building_templates/templates/" .. job.name .. ".tpl")))
 local tpl = templates.parse_template(file:read("*a"), job.name, job.name)
 file:close()
 local binding = {}
 for channel, value in pairs(job.binding) do binding[channel] = palettes.new(value.race,value.roles) end
 local part = templates.part(tpl,job.id,job.race,function(channel) return binding[channel] or binding.main end)
 local buf = parts.buffer()
 parts.stamp(buf,part,0,0,0,0)
 parts.resolve_panes(buf)
 local cells, count = buf:cells()
 for i = 1, count do
  local c = cells[i]
  io.write(index, "\t", c.x, "\t", c.y, "\t", c.z, "\t", c.name, "\t", c.param2 or 0, "\n")
 end
end
