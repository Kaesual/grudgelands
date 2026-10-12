-- Round 46 lane PL, design note: an offline feasibility prototype of
-- seed-dependent POI placement (LuaJIT, a report; NOT the build).
--
--   luajit tools/r46_pl/place_proto.lua REPO SEED OUT_PREFIX
--
-- Builds the horizontal and height sessions of SEED through the shared
-- `world_assembly.lua` on a source view that holds ONLY the fixed anchors
-- (starts, capitals, dragon arenas, apex mines, the four rift sites), so the
-- zone field, the terrain field's bowls and the inland water know nothing
-- of the POIs that move (the design's "placement on the natural terrain").
-- Then it places every other anchor of the source, kind by kind, on the
-- 16-node coarse grid of the water layout, with the exact checks (natural
-- relief on a 4-node lattice, inland water, the F3 wet-core rule) on the
-- best coarse candidates only, and a stepwise relaxation when a row finds
-- nothing. Writes OUT_PREFIX.anchors.tsv (id, template, slot, x, z, zone,
-- relax step, candidates passing the coarse filter), OUT_PREFIX.zones.tsv
-- (a 32-node raster: x, z, zone number or 0, 1 on inland water) for
-- render_proto.py, and prints the timings and a summary. The rules here are the note's proposal in miniature.
local repo, seed, prefix = arg[1], arg[2], arg[3]
assert(repo and seed and prefix, "usage: place_proto.lua REPO SEED OUT_PREFIX")
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local floor, abs, max, min, sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local clock = os.clock

local t0 = clock()
local A = dofile(dir .. "/world_assembly.lua")(dir, sha)
local base = A.source
local pvp = dofile(dir .. "/r31_pvp_catalog.lua")

-- The fixed set (ruling 2) plus the apex mines (authored_fixed today).
local RIFT = {anchor_076 = true, anchor_077 = true, anchor_084 = true, anchor_085 = true}
local function is_fixed(a)
	return a.placement_mode == "authored_fixed" or RIFT[a.id] == true
end
local view = setmetatable({}, {__index = base})
view.anchors, view.claim_exclusions = {}, {}
local fixed_ids = {}
for _, a in ipairs(base.anchors) do
	if is_fixed(a) then
		view.anchors[#view.anchors + 1] = a
		fixed_ids[a.id] = true
	end
end
for _, row in ipairs(base.claim_exclusions) do
	if row.recipe_id ~= "exclude_anchor_blend_v1" or fixed_ids[row.source_id] then
		view.claim_exclusions[#view.claim_exclusions + 1] = row
	end
end

local W = A.world(seed, nil, {roads = false, protection = A.square_cities(120)})
local horizontal = W.horizontal_factory({source = view, schemas = A.schemas,
	canonical = A.canonical, deterministic = A.deterministic, raw_sha256 = sha}).new(seed)
local t1 = clock()
local height = W.height_factory({source = view, canonical = A.canonical,
	deterministic = A.deterministic, raw_sha256 = sha, horizontal_session = horizontal,
	terrain_field = A.terrain_field}).new_runtime(seed)
local t2 = clock()
local grid = assert(height.water_coarse_grid(), "coarse grid")
local water_module = dofile(dir .. "/water_layout.lua")(dofile(dir .. "/terrain_data.lua").water)
local layout = water_module.deserialize(height.water_layout_text())
local sampler = height.water_sampler()

-- Zone raster on the coarse grid (16 nodes): the land cells of every zone.
local C, GX0, GZ0, NX, NZ = grid.cell, grid.x0, grid.z0, grid.nx, grid.nz
local H, LAND = grid.height, grid.land
local zone_of, zone_number = {}, {}
for index, z in ipairs(base.zones) do zone_number[z.id] = index end
local cells_of = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local k = iz * NX + ix
		if LAND[k] then
			local x, z = GX0 + ix * C, GZ0 + iz * C
			local class, _, owner = horizontal.classification_values_at(x, z)
			if class == "land" and owner then
				zone_of[k] = owner
				local list = cells_of[owner]
				if not list then list = {} cells_of[owner] = list end
				list[#list + 1] = k
			end
		end
	end
end
local t3 = clock()
-- The coarse raster for the preview (x, z, zone number or 0, 1 when the
-- natural ground is inland water at the cell centre).
do
	local zf = assert(io.open(prefix .. ".zones.tsv", "w"))
	for iz = 0, NZ - 1, 2 do
		for ix = 0, NX - 1, 2 do
			local k = iz * NX + ix
			local x, z = GX0 + ix * C, GZ0 + iz * C
			local wet = (zone_of[k] and sampler.maybe_wet(x, z) and
				height.inland_water_at(x, z)) and 1 or 0
			zf:write(("%d\t%d\t%d\t%d\n"):format(x, z, zone_of[k] or 0, wet))
		end
	end
	zf:close()
end

local profile = {}
for _, p in ipairs(base.anchor_profiles) do profile[p.id] = p end

-- Level thirds of a zone (simple_map.lua band_ranges): 1, 2 or 3 at (x, z).
local function third_at(x, z, zone)
	local zr = base.zones[zone]
	local level = horizontal.zone_level_at(x, z, zone)
	if not level or zr.level_min == zr.level_max then return 2, level end
	local count = zr.level_max - zr.level_min + 1
	local c1, c2 = floor(count / 3), floor(count * 2 / 3)
	if level < zr.level_min + c1 then return 1, level end
	if level < zr.level_min + c2 then return 2, level end
	return 3, level
end

-- The PvP rows by zone/slot (camp bands and faction halves).
local pvp_row = {}
for _, row in ipairs(pvp.rows) do pvp_row[zone_number[row.zone_id] .. "/" .. row.slot] = row end

-- Kind rules (the note's table in miniature). relief: highest minus lowest
-- natural ground under the building core; spacing: centre distance to
-- every placed POI; gap: fitting squares apart; dry: nodes of dry ground
-- round the core.
local RULES = {
	village = {relief = 12, spacing = 192, dry = 12},
	outpost = {relief = 16, spacing = 160, dry = 8},
	bandit_home = {relief = 16, spacing = 160, dry = 8},
	bandit_frontier = {relief = 16, spacing = 160, dry = 8},
	mine = {relief = 20, spacing = 160, dry = 8, hills = true},
	mirefolk = {relief = 10, spacing = 160, dry = 6, near_water = 64},
	clash = {relief = 20, spacing = 160, dry = 8},
	rare_route = {relief = 28, spacing = 96, dry = 4},
	pvp_fortress = {relief = 12, spacing = 160, dry = 12, fortress = true},
	pvp_camp_low = {relief = 16, spacing = 160, dry = 8, camp = true},
	pvp_camp_high = {relief = 16, spacing = 160, dry = 8, camp = true},
}
local ORDER = {"pvp_fortress", "pvp_camp_high", "pvp_camp_low", "village", "mine",
	"outpost", "bandit_home", "bandit_frontier", "mirefolk", "clash", "rare_route"}
-- Relaxation steps: {band slack (thirds), relief factor, spacing factor,
-- zone margin}; the last keeps only "in the zone, on land, dry core".
local STEPS = {
	{0, 1, 1, 24}, {1, 1, 1, 24}, {1, 1.5, 1, 24}, {1, 1.5, 0.75, 16},
	{2, 2, 0.5, 8}, {2, 3, 0.25, 0},
}
local ZONE_GAP_START, ZONE_GAP_CAPITAL, ANCHOR_GAP = 32, 32, 16
local RELIEF_CAP = assert(dofile(dir .. "/terrain_data.lua").params.poi_bowl_relief)
local BOAT_GAP = 128
local boat_ends = {}
for _, b in ipairs(base.boat_paths) do boat_ends[#boat_ends + 1] = b.centreline[1] end

-- Placed squares: {x, z, half (fitting), zone, kind}; fixed first.
local placed = {}
for _, a in ipairs(view.anchors) do
	local p = profile[a.template_id]
	local half = p.fitting_width / 2
	if a.slot_id == "capital" then half = 266 elseif a.slot_id == "start" then half = 76 end
	placed[#placed + 1] = {x = a.position.x, z = a.position.z, half = half,
		zone = a.zone_numeric_id, kind = a.template_id, fixed = true, slot = a.slot_id}
end

local function cell_index(x, z)
	local ix, iz = floor((x - GX0) / C + 0.5), floor((z - GZ0) / C + 0.5)
	if ix < 0 or iz < 0 or ix >= NX or iz >= NZ then return nil end
	return iz * NX + ix
end

-- Coarse test: every cell of the square (half + margin) is land of `zone`;
-- returns the coarse relief over the core's cells too.
local function coarse(x, z, zone, fit_half, core_half, margin)
	local reach = fit_half + margin
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

local function hash_pick(id, n)
	local d = sha("grug_r46_place_proto\t" .. seed .. "\t" .. id)
	local b1, b2, b3 = d:byte(1, 3)
	return ((b1 * 256 + b2) * 256 + b3) % n + 1
end

local exact_calls = 0
local function exact(x, z, core_half, rule, relief_max)
	-- natural relief under the core on a 4-node lattice
	local lo, hi = math.huge, -math.huge
	for dz = -core_half, core_half - 1, 4 do
		for dx = -core_half, core_half - 1, 4 do
			local y = height.natural_height_at(x + dx, z + dz)
			exact_calls = exact_calls + 1
			if y < lo then lo = y end
			if y > hi then hi = y end
		end
	end
	if hi - lo > relief_max then return nil end
	-- dry core plus `dry` nodes (inland water, any kind)
	local reach = core_half + rule.dry
	for dz = -reach, reach, 4 do
		for dx = -reach, reach, 4 do
			if sampler.maybe_wet(x + dx, z + dz) and height.inland_water_at(x + dx, z + dz) then
				return nil
			end
		end
	end
	-- F3: the river's wet limit off the core's disc (water_layout.wet_core)
	if water_module.wet_core(layout, {{x = x, z = z, r = core_half * 2 * 0.75, id = "c"}}) then
		return nil
	end
	local near = nil
	if rule.near_water then
		for r = core_half + rule.dry + 8, core_half + rule.near_water, 8 do
			for t = -r, r, 8 do
				for _, p in ipairs({{t, -r}, {t, r}, {-r, t}, {r, t}}) do
					if not near and sampler.maybe_wet(x + p[1], z + p[2]) and
							height.inland_water_at(x + p[1], z + p[2]) then
						near = r
					end
				end
			end
			if near then break end
		end
	end
	return hi - lo, near
end

local out = assert(io.open(prefix .. ".anchors.tsv", "w"))
for _, a in ipairs(view.anchors) do
	out:write(("%s\t%s\t%s\t%d\t%d\t%d\tfixed\t0\n"):format(a.id, a.template_id, a.slot_id,
		a.position.x, a.position.z, a.zone_numeric_id))
end
local summary, relaxed, failed, t_scan = {}, {}, {}, clock()
local by_kind = {}
for _, a in ipairs(base.anchors) do
	if not is_fixed(a) then
		local list = by_kind[a.template_id] or {}
		by_kind[a.template_id] = list
		list[#list + 1] = a
	end
end
for _, kind in ipairs(ORDER) do
	for _, a in ipairs(by_kind[kind] or {}) do
		local rule = assert(RULES[kind], kind)
		local p = profile[kind]
		local zone = a.zone_numeric_id
		local fit_half, core_half = p.fitting_width / 2, p.building_core_width / 2
		-- the band: today's third at today's position on this seed's field
		local want = third_at(a.position.x, a.position.z, zone)
		local prow = pvp_row[zone .. "/" .. a.slot_id]
		local lv_lo, lv_hi
		if prow and prow.band then
			local zr = base.zones[zone]
			lv_lo, lv_hi = pvp.camp_levels(zr.level_min, zr.level_max, prow.band)
		end
		local choice, step_used, coarse_count
		for step_index, step in ipairs(STEPS) do
			-- never beyond the terrain field's POI bowl threshold: a placed POI
			-- gets no bowl (the natural field knows only the fixed anchors)
			local relief_max = min(rule.relief * step[2], RELIEF_CAP)
			local cands = {}
			for _, k in ipairs(cells_of[zone] or {}) do
				local x, z = GX0 + (k % NX) * C, GZ0 + floor(k / NX) * C
				local ok = true
				if rule.fortress then
					-- own side of the middle road's axis, within 448 of it, so
					-- the gate turns stay the catalogue's (accord east)
					local east = (prow and prow.faction or "accord") == "accord"
					if (east and (x < 48 or x > 448)) or (not east and (x > -48 or x < -448)) then
						ok = false
					end
				end
				if ok and rule.camp then
					local accord = prow.faction == "accord"
					if (accord and z > -16) or (not accord and z < 16) then ok = false end
					for _, e in ipairs(boat_ends) do
						local dx, dz = x - e.x, z - e.z
						if dx * dx + dz * dz < BOAT_GAP * BOAT_GAP then ok = false end
					end
				end
				if ok then
					local third, level = third_at(x, z, zone)
					if lv_lo then
						if level < lv_lo - step[1] or level > lv_hi + step[1] then ok = false end
					elseif abs(third - want) > step[1] then
						ok = false
					end
				end
				local relief
				if ok then
					relief = coarse(x, z, zone, fit_half, core_half, step[4])
					if not relief or relief > relief_max + 16 then ok = false end
				end
				if ok then
					for _, q in ipairs(placed) do
						local gap = fit_half + q.half + ANCHOR_GAP
						if q.slot == "start" then gap = gap + ZONE_GAP_START end
						if q.slot == "capital" then gap = gap + ZONE_GAP_CAPITAL end
						if abs(q.x - x) < gap and abs(q.z - z) < gap then ok = false break end
						if not q.fixed then
							local sp = rule.spacing * step[3]
							local dx, dz = q.x - x, q.z - z
							if dx * dx + dz * dz < sp * sp then ok = false break end
						end
					end
				end
				if ok then
					local score = relief
					if rule.hills then
						-- prefer high ground: rank by the coarse height (higher first)
						score = relief - H[k] * 0.25
					end
					if rule.fortress then score = score + abs(x) * 0.05 + (abs(z) - 360) * 0.05 end
					cands[#cands + 1] = {x = x, z = z, score = score}
				end
			end
			table.sort(cands, function(l, r)
				if l.score ~= r.score then return l.score < r.score end
				if l.x ~= r.x then return l.x < r.x end
				return l.z < r.z
			end)
			-- exact checks on the best coarse candidates (at most 400); up to 8 passing ones
			local pass = {}
			for i = 1, min(#cands, 400) do
				local c = cands[i]
				local relief, near = exact(c.x, c.z, core_half, rule, relief_max)
				if relief and (not rule.near_water or near or step_index >= 3) then
					pass[#pass + 1] = c
					if #pass >= 8 then break end
				end
			end
			if #pass > 0 then
				choice = pass[hash_pick(a.id, #pass)]
				step_used, coarse_count = step_index, #cands
				break
			end
		end
		if choice then
			placed[#placed + 1] = {x = choice.x, z = choice.z, half = fit_half, zone = zone,
				kind = kind}
			if step_used > 1 then relaxed[#relaxed + 1] = a.id .. ":" .. step_used end
			out:write(("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\n"):format(a.id, kind, a.slot_id,
				choice.x, choice.z, zone, step_used, coarse_count))
		else
			failed[#failed + 1] = a.id
		end
		summary[kind] = (summary[kind] or 0) + 1
	end
end
out:close()
local t4 = clock()
local kinds = {}
for kind, n in pairs(summary) do kinds[#kinds + 1] = kind .. "=" .. n end
table.sort(kinds)
print(("seed %s: horizontal %.1f s, height+water %.1f s, zone raster %.1f s, " ..
	"placement %.1f s (%d exact samples); placed %s; relaxed %d [%s]; failed %d [%s]")
	:format(seed, t1 - t0, t2 - t1, t3 - t2, t4 - t_scan, exact_calls,
	table.concat(kinds, " "), #relaxed, table.concat(relaxed, " "), #failed,
	table.concat(failed, " ")))
