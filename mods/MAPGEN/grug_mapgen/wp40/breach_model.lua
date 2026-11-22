-- The arena "Breach Road": its blocks relative to the site (Round 85 lane
-- BUILD, round85-plan.md §4 BUILD, rulings 3 and 5). Pure data and
-- arithmetic, plain Lua 5.1, no engine calls: the writer
-- (`breach_writer.lua`), the world envelope (`preparation_source.lua` through
-- `r7_runtime.lua`), the seed fleet and the fixtures read the same model.
--
--   local B = dofile(wp40 .. "/breach_model.lua")
--   local model = B.new(wp40)
--
-- The model is the approved draft "Breach Road", second pass
-- (`tools/r84_arena_draft/`): the field (terraces, stairs, breastworks,
-- piers, the road's wear, the rim, the hearths, the dressing) from
-- `breach_field.lua`, the data `tools/r85_build/gen_field.py` generates from
-- the draft's construction, and the two halls from their building templates
-- (`../building_templates/templates/breach_accord.tpl`, `breach_throng.tpl`),
-- placed where the layout (`breach_layout.lua`) puts each hall's waystone.
-- Composed as the draft composes it: a hall's solid cells replace the field,
-- its air cells clear what the field leaves empty. The game's waystone node
-- replaces each template's waystone marker on the layout's waystone cell.
--
-- Local coordinates are the layout's (lx = x - site.x, lz = z - site.z,
-- ly = y - datum). Nothing here depends on the seed except through
-- `family`: the ground's two roles and the dressing take the biome of their
-- own column (ruling 3: the palette fits the zones the site stands in, and
-- the fringe takes each column's local surface).
local M = {}

-- A column's cell values: an entry index (> 0), AIR (write air) or KEEP
-- (leave the natural surface the planner wrote at the datum).
M.AIR, M.KEEP = 0, -1
-- Nodes cleared above a column's highest cell (leaves reaching over the
-- footprint, a plant): the road writer's walking space.
M.CLEAR_ABOVE = 4

-- The ground's biome families: the draft's west (deep forest) and east
-- (badlands) ground and dressing, and the same idea for the other biomes the
-- two Battlegrounds zones put down (`source/simple_map.lua`: meadows, deep
-- forest and swamp; badlands, savanna and swamp). `accent` and `base` are
-- the draft's two ground roles (forest litter or mesa clay in patches over
-- dirt or dry dirt), `path` its trodden earth on the road, the flank paths,
-- the terraces and the apron (dry dirt in the draft; brown dirt where the
-- land is green); `dress` the dressing variant: broken trunks of the
-- woodland ("trunk") or excavated basalt of the dry land ("rock").
M.FAMILIES = {
	woodland = {accent = "grug_nodes:dirt_with_forest_litter", base = "default:dirt",
		path = "default:dirt", dress = "trunk"},
	meadow = {accent = "default:dirt_with_grass", base = "default:dirt", path = "default:dirt",
		dress = "trunk"},
	wetland = {accent = "grug_nodes:mud", base = "default:dirt", path = "default:dirt",
		dress = "trunk"},
	badland = {accent = "grug_nodes:mesa_clay", base = "default:dry_dirt",
		path = "default:dry_dirt", dress = "rock"},
	dryland = {accent = "default:dry_dirt_with_dry_grass", base = "default:dry_dirt",
		path = "default:dry_dirt", dress = "rock"},
}
M.ROLES = {"accent", "base", "path"}
M.FAMILY_ORDER = {"woodland", "meadow", "wetland", "badland", "dryland"}
M.BIOME_FAMILY = {
	grug_deep_forest = "woodland", grug_pine_hills = "woodland", grug_elf_forest = "woodland",
	grug_meadows = "meadow",
	grug_swamp = "wetland",
	grug_badlands = "badland", grug_badlands_east = "badland",
	grug_savanna = "dryland",
}
-- A biome without a row (the site never stands outside the Battlegrounds;
-- a later zone change must not break generation): the draft's west.
M.DEFAULT_FAMILY = "woodland"
function M.family(biome)
	return M.BIOME_FAMILY[biome] or M.DEFAULT_FAMILY
end

local HALL_TEMPLATES = {accord = "breach_accord", throng = "breach_throng"}
-- The game's waystone node (`world_nodes.lua`; grug_home's travel).
M.WAYSTONE = "grug_mapgen:waystone"

function M.new(wp40)
	local L = dofile(wp40 .. "/breach_layout.lua")
	local data = dofile(wp40 .. "/breach_field.lua")
	assert(data.version == 1, "breach model: the field data's version differs")
	local wp13 = wp40 .. "/../wp13"
	local templates = dofile(wp13 .. "/templates.lua")(wp13)

	local model = {}
	-- entries[i] = {name =, param2 =} or {role = "accent" | "base" | "path"}
	local entries, by_key = {}, {}
	local function entry(name, param2)
		local key = name .. "\0" .. param2
		if not by_key[key] then
			local e = {name = name, param2 = param2}
			local role = name:match("^@(%a+)$")
			if role then
				assert(role == "accent" or role == "base" or role == "path",
					"breach model: unknown role " .. name)
				e = {role = role, param2 = 0}
			end
			entries[#entries + 1] = e
			by_key[key] = #entries
		end
		return by_key[key]
	end
	local field_entry = {}
	for index, row in ipairs(data.entries) do field_entry[index] = entry(row[1], row[2]) end
	local code = {["="] = M.KEEP, ["-"] = M.AIR}
	for index = 1, #data.chars do
		local char = data.chars:sub(index, index)
		if field_entry[index] then code[char] = field_entry[index] end
	end

	-- columns["lx,lz"] = {lx =, lz =, cells = {[ly + 1] = value}, top = ly}
	local columns, list = {}, {}
	local function column(lx, lz)
		local key = lx .. "," .. lz
		local c = columns[key]
		if not c then
			c = {lx = lx, lz = lz, cells = {}, top = -1}
			columns[key] = c
			list[#list + 1] = c
		end
		return c
	end
	local function set(c, ly, value)
		assert(ly >= 0, "breach model: a cell below the datum")
		-- a gap below a new top is air
		for y = c.top + 1, ly - 1 do c.cells[y + 1] = M.AIR end
		c.cells[ly + 1] = value
		if ly > c.top then c.top = ly end
	end
	for lx, lz, codes in data.columns:gmatch("(%-?%d+) (%-?%d+) (%S+)") do
		lx, lz = tonumber(lx), tonumber(lz)
		assert(L.inside(lx, lz), "breach model: a field column outside the footprint")
		local c = column(lx, lz)
		for index = 1, #codes do
			local value = code[codes:sub(index, index)]
			assert(value, "breach model: unknown field code " .. codes:sub(index, index))
			set(c, index - 1, value)
		end
	end
	local field_count = #list

	-- The halls: each template placed so that its "arena_marker" point is the
	-- layout's waystone cell; its sockets and inside points must then be the
	-- layout's arrival and muster cells.
	model.halls = {}
	for _, faction in ipairs({"accord", "throng"}) do
		local name = HALL_TEMPLATES[faction]
		local path = templates.ROOT .. "/templates/" .. name .. ".tpl"
		local t = templates.parse_template(templates.read(path), path, name)
		local function point(group, id)
			for _, p in ipairs(t.points[group] or {}) do
				for _, attr in ipairs(p.attrs) do
					if attr.key == "id" and attr.value == id then return p end
				end
			end
			error("breach model: " .. name .. " has no " .. group .. " point " .. id)
		end
		local hall = L.HALLS[faction]
		local marker = point("arena_marker", "waystone")
		local ox, oy, oz = hall.waystone.x - marker.x, hall.waystone.y - marker.y,
			hall.waystone.z - marker.z
		for group, cell in pairs({sockets = {"arrival", hall.arrival},
				inside = {"muster", hall.muster}}) do
			local p = point(group, cell[1])
			assert(p.x + ox == cell[2].x and p.y + oy == cell[2].y and p.z + oz == cell[2].z,
				"breach model: " .. name .. "'s " .. cell[1] .. " point is not the layout's")
		end
		local count = 0
		for yi, layer in ipairs(t.grid) do
			local ly = t.y0 + yi - 1 + oy
			for zi, row in ipairs(layer) do
				local lz = t.z0 + zi - 1 + oz
				for xi, key in ipairs(row) do
					local lx = t.x0 + xi - 1 + ox
					if key then
						assert(L.inside(lx, lz), "breach model: a hall cell outside the footprint")
						local c = column(lx, lz)
						if key == "." then
							-- template air clears what the field leaves empty
							if ly > c.top or c.cells[ly + 1] == M.AIR then set(c, ly, M.AIR) end
						else
							local e = t.legend[key]
							assert(e.kind == "node" and not e.o, "breach model: " .. name ..
								" holds a legend entry other than a plain node")
							set(c, ly, entry(e.name, 0))
							count = count + 1
						end
					end
				end
			end
		end
		model.halls[faction] = {template = name, offset = {x = ox, y = oy, z = oz},
			solids = count}
	end
	assert(#list == field_count, "breach model: a hall stands outside the field")
	-- The waystones: the game's waystone node on each hall's waystone cell,
	-- written as the towns and the fortresses write it (a plain node, param2
	-- 0, no metadata), where the template holds its marker stack (basalt
	-- brick, emberglass lamp, basalt brick): the stone stands 1.5 nodes tall,
	-- so the two marker cells above it become air. The waystone rows of the
	-- fixed list point at these cells and the arrival cell beside them.
	for _, faction in ipairs({"accord", "throng"}) do
		local w = L.HALLS[faction].waystone
		local c = column(w.x, w.z)
		local marker = {"grug_decor:darkage_basalt_brick", "grug_materials:emberglass_lamp",
			"grug_decor:darkage_basalt_brick"}
		for index, name in ipairs(marker) do
			local value = c.cells[w.y + index]
			assert(value and value > 0 and entries[value].name == name,
				"breach model: the " .. faction .. " hall's marker is not on the layout's waystone cell")
		end
		c.cells[w.y + 1] = entry(M.WAYSTONE, 0)
		c.cells[w.y + 2], c.cells[w.y + 3] = M.AIR, M.AIR
	end

	-- The dressing groups: {x, z, trunk = cells, rock = cells}, cells {dx, ly, dz}.
	model.dressing = {}
	local dress_entry = {trunk = entry("default:tree", 0), rock = entry("grug_materials:basalt", 0)}
	for index, g in ipairs(data.dressing) do
		local group = {x = g.x, z = g.z, cells = {}}
		for variant, cells in pairs({trunk = g.trunk, rock = g.rock}) do
			local out = {}
			for _, cell in ipairs(cells) do
				-- (the writer finds a group's chunks by its centre +-1)
				assert(L.inside(g.x + cell[1], g.z + cell[3]) and math.abs(cell[1]) <= 1 and
					math.abs(cell[3]) <= 1, "breach model: dressing outside its group")
				out[#out + 1] = {x = g.x + cell[1], y = cell[2], z = g.z + cell[3],
					entry = dress_entry[variant]}
			end
			group.cells[variant] = out
		end
		model.dressing[index] = group
	end

	-- Every column in a fixed order (z, then x), and the model's height.
	table.sort(list, function(a, b)
		if a.lz ~= b.lz then return a.lz < b.lz end
		return a.lx < b.lx
	end)
	local top = 0
	for _, c in ipairs(list) do if c.top > top then top = c.top end end
	for _, g in ipairs(model.dressing) do
		for _, cells in pairs(g.cells) do
			for _, cell in ipairs(cells) do if cell.y > top then top = cell.y end end
		end
	end
	model.entries, model.columns, model.TOP = entries, list, top
	function model.column(lx, lz) return columns[lx .. "," .. lz] end
	-- The highest node any column may hold or clear above the datum.
	model.REACH = top + M.CLEAR_ABOVE
	model.layout = L
	-- The box the arena writes in world coordinates (the world envelope's
	-- fitted box, `preparation_source.lua`; `air_chunks.lua` reads it): the
	-- footprint's bounds from the datum up to its highest cell and clear.
	function model.box(site)
		return {x_min = site.x - L.HALF_X, x_max = site.x + L.HALF_X,
			z_min = site.z - L.HALF_Z, z_max = site.z + L.HALF_Z,
			y_min = site.y, y_max = site.y + model.REACH, radius = 0}
	end
	return model
end

return M
