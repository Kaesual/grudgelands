-- Round 46: seed-dependent placement of the POIs (round46-plan.md §4.2,
-- rulings 2 and 17; the design note in the round's reports). The owner of
-- every placed anchor's position: nothing else holds one.
--
--   local P = dofile(wp40 .. "/placement.lua")(wp40, raw_sha256)
--   local fixed = P.fixed_view(source)        -- the source of the placement session
--   local positions, stats = P.place(seed, source, horizontal, height)
--   local text = P.serialize(source, positions)  -- main: payload and cache
--   local positions = P.parse(text, source)      -- emerge, a cache hit
--   local world_source = P.view(source, positions)
--
-- The placement session (`world_assembly.lua` W.place) is a horizontal and
-- a height session on `fixed_view(source)`: the zone field's keypoints, the
-- terrain field's bowls and the inland water know only the fixed anchors
-- (starts, capitals, dragon arenas, apex mines, the rift sites), so the
-- natural ground and the water are the same before and after placement.
-- Every placed anchor (`placement = "placed"` rows of the source) is then
-- placed, in the order (pass, kind order, anchor number), on the 16-node
-- coarse grid the water layout drained on, by its kind's rules
-- (`placement_rules.lua`):
--   * its fitting square plus the step's zone margin lies on land of its own
--     zone (also off the sea and the bays);
--   * its level band: the zone's level third at the centre (the mapgen level
--     field, `zone_level_at`), or a war camp's catalogue levels;
--   * fitting squares 16 apart from every anchor, TOWN_GAP from a start
--     town's or a capital's square, the kind's spacing from every placed POI
--     (PvP POIs never closer than PVP_SPACING_MIN);
--   * the middle road's corridor, the fortress side, the camp half and the
--     boat-path gap;
--   * relief under the core within the kind's limit and the terrain field's
--     bowl threshold (a placed POI gets no calm bowl);
--   * no inland water under the core plus its dry pad, the river guard of
--     the water layout (`wet_core`, Round 34 F3) and the core's ground not
--     below water within WATER_REACH.
-- The coarse tests sort the candidates by score; the exact tests walk them
-- until FINALISTS pass, and SHA-256 of seed and anchor id picks one of
-- those. A row that finds nothing relaxes step by step (R.STEPS), then
-- takes the last resort; placement never raises for a world.
--
-- Deterministic: integer cells, explicit sort ties, no `pairs` order. Main
-- computes it once; the text goes to emerge and the layout cache.
-- Plain Lua 5.1, no globals.
return function(wp40_directory, raw_sha256)
	local function fail(message)
		error("WP40 placement: " .. message, 0)
	end
	if type(wp40_directory) ~= "string" or type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end
	local R = dofile(wp40_directory .. "/placement_rules.lua")
	local pvp = dofile(wp40_directory .. "/r31_pvp_catalog.lua")
	local terrain_data = dofile(wp40_directory .. "/terrain_data.lua")
	local water_module = dofile(wp40_directory .. "/water_layout.lua")(terrain_data.water)
	local RELIEF_CAP = terrain_data.params.poi_bowl_relief
	local floor, abs, max, min = math.floor, math.abs, math.max, math.min
	local M = {rules = R}

	local kind_rank = {}
	for index, kind in ipairs(R.KIND_ORDER) do kind_rank[kind] = index end

	-- The placed anchors in placement order, every one with its rules.
	local function placement_order(source)
		local list = {}
		for _, a in ipairs(source.anchors) do
			if a.placement_mode == "placed" then
				if not R.KINDS[a.template_id] then
					fail("no placement rules for kind " .. tostring(a.template_id))
				end
				list[#list + 1] = a
			end
		end
		table.sort(list, function(l, r)
			if (l.pass or 1) ~= (r.pass or 1) then return (l.pass or 1) < (r.pass or 1) end
			local lk, rk = kind_rank[l.template_id] or 1000, kind_rank[r.template_id] or 1000
			if lk ~= rk then return lk < rk end
			if l.template_id ~= r.template_id then return l.template_id < r.template_id end
			return l.numeric_id < r.numeric_id
		end)
		return list
	end
	M.placement_order = placement_order

	-- The source the placement session is built on: the fixed anchors and
	-- their claim exclusions only.
	function M.fixed_view(source)
		local view = setmetatable({}, {__index = source})
		view.anchors = source.fixed_anchors
		view.claim_exclusions = source.claim_exclusions
		return view
	end

	-- A world's source: every anchor with its position (the placed ones
	-- copied with this world's), and the claim exclusions rebuilt from them.
	function M.view(source, positions)
		local view = setmetatable({}, {__index = source})
		view.anchors = {}
		for index, a in ipairs(source.anchors) do
			if a.placement_mode == "placed" then
				local p = positions[a.id]
				if not p then fail("placed anchor missing: " .. a.id) end
				local copy = {}
				for key, value in pairs(a) do copy[key] = value end
				copy.position = {x = p.x, z = p.z}
				copy.placement_step = p.step
				view.anchors[index] = copy
			else
				view.anchors[index] = a
			end
		end
		view.claim_exclusions = source.claim_exclusions_of(view.anchors)
		return view
	end

	-- The text: "P1 <count>" and one "<anchor id> <x> <z> <step>" line per
	-- placed anchor in anchor order.
	function M.serialize(source, positions)
		local out, count = {}, 0
		for _, a in ipairs(source.anchors) do
			if a.placement_mode == "placed" then
				local p = positions[a.id]
				if not p then fail("placed anchor missing: " .. a.id) end
				count = count + 1
				out[#out + 1] = ("%s %d %d %d\n"):format(a.id, p.x, p.z, p.step)
			end
		end
		return ("P1 %d\n"):format(count) .. table.concat(out)
	end

	function M.parse(text, source)
		if type(text) ~= "string" then fail("placement text differs") end
		local lines = {}
		for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
		local count = tonumber((lines[1] or ""):match("^P1 (%d+)$"))
		if not count or #lines ~= count + 1 then fail("placement text header differs") end
		local e = source.extent
		local positions, index = {}, 1
		for _, a in ipairs(source.anchors) do
			if a.placement_mode == "placed" then
				index = index + 1
				local id, x, z, step = (lines[index] or ""):match(
					"^(anchor_%d+) (%-?%d+) (%-?%d+) (%d+)$")
				x, z, step = tonumber(x), tonumber(z), tonumber(step)
				if id ~= a.id or not x or x < e.min_x or x > e.max_x or
						z < e.min_z or z > e.max_z or step < 1 or step > R.WET_RESORT then
					fail("placement text row differs at " .. a.id)
				end
				positions[id] = {x = x, z = z, step = step}
			end
		end
		if index ~= count + 1 then fail("placement text count differs") end
		return positions
	end

	-- The placement itself. `horizontal` and `height` are the placement
	-- session (built on `fixed_view(source)`, main only: it needs the water
	-- layout's coarse grid). Returns {anchor id -> {x, z, step}} and stats.
	function M.place(seed, source, horizontal, height)
		local started = os.clock()
		local grid = height.water_coarse_grid()
		if type(grid) ~= "table" then fail("the water layout's coarse grid is missing") end
		local layout = water_module.deserialize(height.water_layout_text())
		local sampler = height.water_sampler()
		local C, GX0, GZ0, NX, NZ = grid.cell, grid.x0, grid.z0, grid.nx, grid.nz
		local H, LAND = grid.height, grid.land
		local zones = source.zones
		local zone_number = {}
		for index, z in ipairs(zones) do zone_number[z.id] = index end
		local corridor = {}
		for _, id in ipairs(R.CORRIDOR.zones) do corridor[zone_number[id]] = true end
		local profile = {}
		for _, p in ipairs(source.anchor_profiles) do profile[p.id] = p end
		local pvp_row = {}
		for _, row in ipairs(pvp.rows) do
			pvp_row[zone_number[row.zone_id] .. "/" .. row.slot] = row
		end
		local BAND = {low = 1, mid = 2, high = 3}

		-- The coarse zone raster: every land cell of each zone, in cell order.
		local zone_of, cells_of = {}, {}
		for iz = 0, NZ - 1 do
			for ix = 0, NX - 1 do
				local k = iz * NX + ix
				if LAND[k] then
					local class, _, owner = horizontal.classification_values_at(GX0 + ix * C,
						GZ0 + iz * C)
					if class == "land" and owner then
						zone_of[k] = owner
						local list = cells_of[owner]
						if not list then list = {} cells_of[owner] = list end
						list[#list + 1] = k
					end
				end
			end
		end
		local function cell_index(x, z)
			local ix, iz = floor((x - GX0) / C + 0.5), floor((z - GZ0) / C + 0.5)
			if ix < 0 or iz < 0 or ix >= NX or iz >= NZ then return nil end
			return iz * NX + ix
		end

		local function third_at(x, z, zone)
			local zr = zones[zone]
			local level = horizontal.zone_level_at(x, z, zone) or zr.level_min
			if zr.level_min == zr.level_max then return 2, level end
			local count = zr.level_max - zr.level_min + 1
			local c1, c2 = floor(count / 3), floor(count * 2 / 3)
			if level < zr.level_min + c1 then return 1, level end
			if level < zr.level_min + c2 then return 2, level end
			return 3, level
		end

		-- The coarse test: every cell of the square (fitting half + margin) is
		-- land of `zone`; returns the coarse relief over the core's cells.
		local function coarse(x, z, zone, reach, core_half)
			local lo, hi = math.huge, -math.huge
			for dz = -reach, reach, C do
				for dx = -reach, reach, C do
					local k = cell_index(x + dx, z + dz)
					if not k or zone_of[k] ~= zone then return nil end
					if abs(dx) <= core_half + C and abs(dz) <= core_half + C then
						local h = H[k]
						if h < lo then lo = h end
						if h > hi then hi = h end
					end
				end
			end
			return hi - lo
		end

		local function wet(x, z)
			return sampler.maybe_wet(x, z) and height.inland_water_at(x, z) ~= nil
		end

		-- The exact test: relief, the dry core and pad, F3, the core above the
		-- water near it, the rare patrol points; nil or relief and the nearest
		-- water ring (near_water).
		local function exact(a, x, z, core_half, rule, relief_max, zone)
			local lo, hi, values = math.huge, -math.huge, {}
			for dz = -core_half, core_half - 1, 4 do
				for dx = -core_half, core_half - 1, 4 do
					local y = height.natural_height_at(x + dx, z + dz)
					values[#values + 1] = y
					if y < lo then lo = y end
					if y > hi then hi = y end
				end
			end
			if hi - lo > relief_max then return nil end
			local reach = core_half + rule.dry
			for dz = -reach, reach, 4 do
				for dx = -reach, reach, 4 do
					if wet(x + dx, z + dz) then return nil end
				end
			end
			if water_module.wet_core(layout, {{x = x, z = z, r = core_half * 2 * 0.75,
					id = a.id}}) then
				return nil
			end
			-- the fitted core height (the lower median) above nearby water
			table.sort(values)
			local reference = values[floor((#values + 1) / 2)]
			local ring = core_half + R.WATER_REACH
			for t = -ring, ring, 8 do
				for side = 1, 4 do
					local px, pz
					if side == 1 then px, pz = x + t, z - ring
					elseif side == 2 then px, pz = x + t, z + ring
					elseif side == 3 then px, pz = x - ring, z + t
					else px, pz = x + ring, z + t end
					if sampler.maybe_wet(px, pz) then
						local _, _, water_y = height.inland_water_at(px, pz)
						if water_y and water_y >= reference then return nil end
					end
				end
			end
			if rule.patrol then
				for _, p in ipairs(source.rare_patrol_shape) do
					local px, pz = x + p.x, z + p.z
					local class, _, owner = horizontal.classification_values_at(px, pz)
					if class ~= "land" or owner ~= zone or wet(px, pz) then return nil end
				end
			end
			local near
			if rule.near_water then
				for r = core_half + rule.dry + 8, core_half + rule.near_water, 8 do
					for t = -r, r, 8 do
						if not near and (wet(x + t, z - r) or wet(x + t, z + r) or
								wet(x - r, z + t) or wet(x + r, z + t)) then
							near = r
						end
					end
					if near then break end
				end
			end
			return hi - lo, near
		end

		local function pick_index(id, n)
			local d = raw_sha256("grug_r46_placement_v1\t" .. seed .. "\t" .. id)
			local b1, b2, b3 = d:byte(1, 3)
			return ((b1 * 256 + b2) * 256 + b3) % n + 1
		end

		-- Placed squares: fixed anchors first, then each placed one.
		local placed = {}
		for _, a in ipairs(source.fixed_anchors) do
			local half = profile[a.template_id].fitting_width / 2
			local town = a.slot_id == "start" or a.slot_id == "capital"
			if a.slot_id == "capital" then half = 266 elseif a.slot_id == "start" then half = 76 end
			placed[#placed + 1] = {x = a.position.x, z = a.position.z, half = half,
				fixed = true, town = town}
		end
		local boat_ends = {}
		for _, b in ipairs(source.boat_paths) do boat_ends[#boat_ends + 1] = b.centreline[1] end

		local positions = {}
		local stats = {relaxed = {}, last_resort = {}, wet = {}}
		for _, a in ipairs(placement_order(source)) do
			local kind = a.template_id
			local rule = R.KINDS[kind]
			local p = profile[kind]
			local zone = a.zone_numeric_id
			local fit_half, core_half = p.fitting_width / 2, p.building_core_width / 2
			local want = BAND[a.band] or 2
			local prow = pvp_row[zone .. "/" .. a.slot_id]
			local lv_lo, lv_hi
			if rule.camp then
				if not prow or not prow.band then fail("war camp catalogue row missing: " .. a.id) end
				local zr = zones[zone]
				lv_lo, lv_hi = pvp.camp_levels(zr.level_min, zr.level_max, prow.band)
			end
			local corridor_min = corridor[zone] and max(R.CORRIDOR.min,
				core_half + R.CORRIDOR.reserve) or nil

			-- The rules that never relax (own zone and land come from `coarse`).
			local function fixed_rules(x, z)
				if corridor_min and abs(x) < corridor_min then return false end
				if rule.fortress then
					local east = (prow and prow.faction or "accord") == "accord"
					local d = east and x or -x
					if d < rule.fortress.min or d > rule.fortress.max then return false end
				end
				if rule.camp then
					local accord = prow.faction == "accord"
					if (accord and z > -rule.camp.half) or (not accord and z < rule.camp.half) then
						return false
					end
					for _, e in ipairs(boat_ends) do
						local dx, dz = x - e.x, z - e.z
						if dx * dx + dz * dz < R.BOAT_GAP * R.BOAT_GAP then return false end
					end
				end
				for _, q in ipairs(placed) do
					if q.town then
						local gap = fit_half + q.half + R.TOWN_GAP
						if abs(q.x - x) < gap and abs(q.z - z) < gap then return false end
					end
				end
				return true
			end

			local choice
			local function try_step(step_index, step)
				local relief_max = min(rule.relief * step.relief, RELIEF_CAP)
				local cands = {}
				for _, k in ipairs(cells_of[zone] or {}) do
					local x, z = GX0 + (k % NX) * C, GZ0 + floor(k / NX) * C
					local ok = fixed_rules(x, z)
					if ok then
						local third, level = third_at(x, z, zone)
						if lv_lo then
							if level < lv_lo - step.band or level > lv_hi + step.band then ok = false end
						elseif abs(third - want) > step.band then
							ok = false
						end
					end
					local relief
					if ok then
						relief = coarse(x, z, zone, fit_half + step.margin, core_half)
						if not relief or relief > relief_max + 16 then ok = false end
					end
					if ok then
						for _, q in ipairs(placed) do
							if not q.town then
								local gap = fit_half + q.half + R.ANCHOR_GAP
								if abs(q.x - x) < gap and abs(q.z - z) < gap then ok = false break end
							end
							if not q.fixed then
								local sp = rule.spacing * step.spacing
								if rule.pvp and q.pvp then sp = max(sp, R.PVP_SPACING_MIN) end
								local dx, dz = q.x - x, q.z - z
								if dx * dx + dz * dz < sp * sp then ok = false break end
							end
						end
					end
					if ok then
						local score = relief
						if rule.hills then
							local top = H[k]
							for dz = -rule.hills, rule.hills, C do
								for dx = -rule.hills, rule.hills, C do
									local j = cell_index(x + dx, z + dz)
									if j and LAND[j] and H[j] > top then top = H[j] end
								end
							end
							score = score - min(top - H[k], 64) * 0.25
						end
						if rule.fortress then
							score = score + abs(x) * 0.05 + (abs(z) - 360) * 0.05
						end
						cands[#cands + 1] = {x = x, z = z, score = score}
					end
				end
				table.sort(cands, function(l, r)
					if l.score ~= r.score then return l.score < r.score end
					if l.x ~= r.x then return l.x < r.x end
					return l.z < r.z
				end)
				local pass = {}
				for i = 1, min(#cands, R.EXACT_MAX) do
					local c = cands[i]
					local relief, near = exact(a, c.x, c.z, core_half, rule, relief_max, zone)
					if relief and (not rule.near_water or near or step_index >= 3) then
						pass[#pass + 1] = c
						if #pass >= R.FINALISTS then break end
					end
				end
				if #pass > 0 then
					local c = pass[pick_index(a.id, #pass)]
					return {x = c.x, z = c.z, step = step_index}
				end
			end
			for step_index, step in ipairs(R.STEPS) do
				choice = try_step(step_index, step)
				if choice then break end
			end
			if not choice then
				-- The last resort: the zone's flattest land cell with a dry core
				-- (band and spacing ignored), else its flattest land cell.
				local cells = {}
				for _, k in ipairs(cells_of[zone] or {}) do
					local x, z = GX0 + (k % NX) * C, GZ0 + floor(k / NX) * C
					local relief = coarse(x, z, zone, core_half, core_half)
					if relief then cells[#cells + 1] = {x = x, z = z, score = relief} end
				end
				table.sort(cells, function(l, r)
					if l.score ~= r.score then return l.score < r.score end
					if l.x ~= r.x then return l.x < r.x end
					return l.z < r.z
				end)
				for _, c in ipairs(cells) do
					if fixed_rules(c.x, c.z) and exact(a, c.x, c.z, core_half, rule, RELIEF_CAP, zone) then
						choice = {x = c.x, z = c.z, step = R.LAST_RESORT}
						break
					end
				end
				if not choice then
					local c = cells[1]
					if not c then
						-- no land cell of the zone fits the core at all: its hub
						c = {x = zones[zone].hub.x, z = zones[zone].hub.z}
					end
					choice = {x = c.x, z = c.z, step = R.WET_RESORT}
				end
			end
			positions[a.id] = choice
			placed[#placed + 1] = {x = choice.x, z = choice.z, half = fit_half, pvp = rule.pvp}
			if choice.step == R.WET_RESORT then
				stats.wet[#stats.wet + 1] = a.id
			elseif choice.step == R.LAST_RESORT then
				stats.last_resort[#stats.last_resort + 1] = a.id
			elseif choice.step > 1 then
				stats.relaxed[#stats.relaxed + 1] = a.id .. ":" .. choice.step
			end
		end
		stats.seconds = os.clock() - started
		return positions, stats
	end

	return M
end
