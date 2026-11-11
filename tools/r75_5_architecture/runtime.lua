-- Compare the real game loader and all four rotations with accepted scene cells.
local root, manifest = assert(arg[1]), assert(arg[2])
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp13"
local templates = dofile(wp .. "/templates.lua")(wp)
local palettes = dofile(wp .. "/palette.lua")
local parts = dofile(wp .. "/parts.lua")
local jobs = dofile(manifest)
local checked, rotations = 0, 0
local function key(x,y,z) return x .. ":" .. y .. ":" .. z end
for _, job in ipairs(jobs) do
 local file = assert(io.open(root .. "/mods/MAPGEN/grug_mapgen/building_templates/templates/" .. job.name .. ".tpl"))
 local t = templates.parse_template(file:read("*a"), job.name, job.name); file:close()
 local binding = {}
 for channel, value in pairs(job.binding) do binding[channel] = palettes.new(value.race,value.roles) end
 local part = templates.part(t,"proof",job.race,function(channel) return binding[channel] or binding.main end)
 local expected = {}
 for line in io.lines(job.cells) do
  local x,y,z,name,p2 = line:match("^(%-?%d+) (%-?%d+) (%-?%d+) (%S+) (%d+)$")
  expected[#expected+1] = {x=tonumber(x),y=tonumber(y),z=tonumber(z),name=name,param2=tonumber(p2)}
 end
 for turn = 0, 3 do
  local buf = parts.buffer()
  parts.stamp(buf,part,0,0,0,turn)
  parts.resolve_panes(buf)
  local actual = {}; local cells,count = buf:cells()
  for i=1,count do local c=cells[i]; actual[key(c.x,c.y,c.z)] = c end
  if job.exact then assert(count == #expected, job.name .. " occupied cells differ") end
  for _, e in ipairs(expected) do
   -- Independent footprint rotation, rather than the game's helper.
   local x,z = e.x,e.z
   if turn == 1 then x,z = e.z,part.w-1-e.x
   elseif turn == 2 then x,z = part.w-1-e.x,part.d-1-e.z
   elseif turn == 3 then x,z = part.d-1-e.z,e.x end
   local got = assert(actual[key(x,e.y,z)], job.name .. " missing cell")
   local p2 = e.param2
   local kind = parts.param2_kind(e.name)
   if kind == parts.FACEDIR then
    -- The authored architecture only changes upright shapes. Other unchanged
    -- furniture/tree orientations use the library's already-tested rotation.
    if p2 < 4 then p2 = (p2+turn)%4
    else p2 = parts.rotate_param2(p2,kind,turn) end
   elseif kind ~= parts.NONE then p2 = parts.rotate_param2(p2,kind,turn) end
   assert(got.name == e.name and parts.canonical_param2(got.name,got.param2) ==
    parts.canonical_param2(e.name,p2), job.name .. " cell differs at " .. key(x,e.y,z) ..
    ": " .. got.name .. "/" .. got.param2 .. " expected " .. e.name .. "/" .. p2)
   checked = checked+1
  end
  rotations = rotations+1
 end
end
print("Real loader: " .. #jobs .. " contexts, " .. rotations .. " rotations, " .. checked .. " cells agree")
