-- The two halls of the arena "Breach Road" of this world, for the box rewrite
-- of the migration 0.89.0 (`hall_rewrite.lua`): {key, place()}, the Accord's
-- first. `place()` gives every cell of a hall template's box as the arena's
-- writer (`breach_writer.lua`) settles it on this world's site: the same
-- model (`breach_model.lua`, this game's templates), the same writer, the
-- ground roles by the planner's biome of their column (the writer's own
-- rule, the same pure answer in every environment). A box cell the writer
-- leaves (above a column's top and the air it clears there) is air: the
-- levelled ground holds nothing above the datum.
--
-- The box is the hall template's box as the model places it (21 x 19 x 31,
-- from the floor layer up); the writer's clear above it (CLEAR_ABOVE) is air
-- in every world, old or new, and stays out of the write. The boxes are
-- pinned to those of 0.88.0: a template that moves or grows its box is
-- refused (round89-plan.md ruling 5, upgrade contract §5.9: the box is
-- unchanged), so the rewrite never leaves an old cell outside it.
--
-- The list holds only the site; the model and the writer are built once,
-- when a job asks, and go with the job. It lives here and not in
-- `r7_runtime.lua`, which is part of the preparation authority
-- (`preparation_identity.lua`). Plain Lua 5.1, no globals.
return function(wp40, core_api, placement_text, column_values_at)
	local L = dofile(wp40 .. "/breach_layout.lua")
	local site = L.from_placement(placement_text)
	-- Local boxes of 0.88.0's halls (inclusive; layout coordinates).
	local BOXES = {
		accord = {min = {x = 22, y = 6, z = -15}, max = {x = 42, y = 24, z = 15}},
		throng = {min = {x = -42, y = 6, z = -15}, max = {x = -22, y = 24, z = 15}},
	}
	local built
	local function build()
		if built then return built end
		local B = dofile(wp40 .. "/breach_model.lua")
		local model = B.new(wp40)
		local wp13 = wp40 .. "/../wp13"
		local templates = dofile(wp13 .. "/templates.lua")(wp13)
		built = {B = B, model = model, templates = templates,
			writer = dofile(wp40 .. "/breach_writer.lua")(core_api, {breach = site}, B, model)}
		return built
	end

	local function place(faction)
		local b = build()
		local hall = b.model.halls[faction]
		local name = hall.template
		local path = b.templates.ROOT .. "/templates/" .. name .. ".tpl"
		local t = b.templates.parse_template(b.templates.read(path), path, name)
		local o = hall.offset
		local lmin = {x = t.x0 + o.x, y = t.y0 + o.y, z = t.z0 + o.z}
		local lmax = {x = lmin.x + t.sx - 1, y = lmin.y + t.sy - 1, z = lmin.z + t.sz - 1}
		local pinned = BOXES[faction]
		for _, axis in ipairs({"x", "y", "z"}) do
			if lmin[axis] ~= pinned.min[axis] or lmax[axis] ~= pinned.max[axis] then
				error("the " .. name .. " box moved: the rewrite needs 0.88.0's box", 0)
			end
		end
		-- No kept natural cell inside the box (the writer would leave it).
		for lz = lmin.z, lmax.z do
			for lx = lmin.x, lmax.x do
				local c = b.model.column(lx, lz)
				for ly = lmin.y, lmax.y do
					if c and c.cells[ly + 1] == b.B.KEEP then
						error("a kept natural cell in the " .. name .. " box", 0)
					end
				end
			end
		end
		local min = {x = site.x + lmin.x, y = site.y + lmin.y, z = site.z + lmin.z}
		local max = {x = site.x + lmax.x, y = site.y + lmax.y, z = site.z + lmax.z}
		local sx, sy = t.sx, t.sy
		local cids, param2s = {}, {}
		local function index(x, y, z)
			return ((z - min.z) * sy + (y - min.y)) * sx + (x - min.x) + 1
		end
		b.writer.dress({min_x = min.x, max_x = max.x, min_y = min.y, max_y = max.y,
			min_z = min.z, max_z = max.z, column_values_at = column_values_at,
			-- never air: every air cell of the model is written
			settled_at = function() return -1 end,
			write_road = function(x, y, z, cid, param2)
				local at = index(x, y, z)
				cids[at], param2s[at] = cid, param2
			end})
		local cells, names = {}, {}
		local air = core_api.CONTENT_AIR
		for z = min.z, max.z do
			for y = min.y, max.y do
				for x = min.x, max.x do
					local at = index(x, y, z)
					local cid = cids[at] or air
					local node = names[cid]
					if not node then
						node = core_api.get_name_from_content_id(cid)
						names[cid] = node
					end
					cells[#cells + 1] = {x = x - min.x, y = y - min.y, z = z - min.z,
						name = node, param2 = param2s[at] or 0}
				end
			end
		end
		return {cells = cells, base = min, min = min, max = max}
	end

	local sites = {}
	for _, faction in ipairs({"accord", "throng"}) do
		sites[#sites + 1] = {key = faction, place = function() return place(faction) end}
	end
	return sites
end
