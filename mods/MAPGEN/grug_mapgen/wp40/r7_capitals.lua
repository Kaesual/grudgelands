-- The capital planner in the R7 construction (Round 22, plan D60, D69-D73,
-- §11). Main plans every capital once, after height, water and roads, on a
-- height session of its own (`r7_runtime.lua` hands that session to the
-- world build afterwards): per capital the planner (`capital_planner.lua`)
-- lays out the outline, gates, streets, plots, edge and canal on the session's
-- fitted ground; its streets and connectors join the road layout through the
-- session-level connect (`height.lua` add_roads) and its canal joins the
-- height session as authored water (add_authored). The capital layouts travel
-- to emerge as one text (`capital_layout` in the ipc_set payload). Emerge
-- never plans: it parses the text, and both environments build the capitals,
-- the canal rows and the squares from the parsed text alone.
--
-- Plain Lua 5.1, no globals, no engine calls.
return function(wp40_directory)
	local planner = dofile(wp40_directory .. "/capital_planner.lua")
	local capital_source = dofile(wp40_directory .. "/r7_capital_blueprint.lua")
	local services = dofile(wp40_directory .. "/../wp13/capital_services.lua")
	local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

	local M = {planner = planner, source = capital_source}

	local function fail(message)
		error("WP40 capitals: " .. message, 0)
	end

	-- The planned canal (D58) as an authored water row: one level, river
	-- water, a carved trough `depth` deep, sealed off natural water. The
	-- indicator is the height module's convention, m = 0.5 + s / LAKE_PROXY
	-- with s the signed distance to the canal's edge.
	function M.canal_row(id, anchor, canal, proxy)
		local pts = {}
		for i, p in ipairs(canal.pts) do pts[i] = {anchor.x + p[1], anchor.z + p[2]} end
		local half = canal.half + 0.5
		local reach = half + 0.5 * proxy + 1
		local segs = {}
		local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
		for i = 1, #pts do
			local a, b = pts[i], pts[min(#pts, i + 1)]
			segs[#segs + 1] = {ax = a[1], az = a[2], vx = b[1] - a[1], vz = b[2] - a[2]}
			min_x, max_x = min(min_x, a[1]), max(max_x, a[1])
			min_z, max_z = min(min_z, a[2]), max(max_z, a[2])
		end
		local function indicator(x, z)
			local best = math.huge
			for i = 1, #segs do
				local g = segs[i]
				local l2 = g.vx * g.vx + g.vz * g.vz
				local ox, oz = x - g.ax, z - g.az
				local t = l2 > 0 and (ox * g.vx + oz * g.vz) / l2 or 0
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
				local ex, ez = ox - t * g.vx, oz - t * g.vz
				local d = ex * ex + ez * ez
				if d < best then best = d end
			end
			local m = 0.5 + (half - sqrt(best)) / proxy
			if m <= 0 then return 0 elseif m >= 1 then return 1 end
			return m
		end
		return {id = id, river = true, level = canal.level, depth = canal.depth,
			natural_clear = 8, indicator = indicator,
			min_x = floor(min_x - reach), max_x = floor(max_x + reach) + 1,
			min_z = floor(min_z - reach), max_z = floor(max_z + reach) + 1}
	end

	-- The squares of a parsed layout in world coordinates.
	function M.squares(layout)
		local out = {}
		for _, q in ipairs(layout.squares) do
			out[#out + 1] = {x = layout.anchor.x + q.x, z = layout.anchor.z + q.z,
				r = q.r, y = q.y}
		end
		return out
	end

	-- The parsed capital layouts of a payload text: {anchor id -> {text,
	-- layout}} and the ids in payload order.
	function M.parse(text)
		if type(text) ~= "string" or text == "" then fail("capital layout text differs") end
		local texts, order = planner.split(text)
		local out = {}
		for _, id in ipairs(order) do
			out[id] = {text = texts[id], layout = planner.deserialize(texts[id])}
		end
		return out, order
	end

	-- The required plots of a capital: the inn, the eight service plots (the
	-- cook's among them) and the stable (audit §2.2); a missing one is a load
	-- error in its consumer, so the planner always places them.
	local function required_of(key)
		local set = {}
		for _, id in pairs(assert(services.PLOTS[key], "service plots missing: " .. key)) do
			set[id] = true
		end
		set[assert(services.INNS[key], "inn plot missing: " .. key)] = true
		return set
	end

	-- Main only. `env`: seed, session (the planning height session), roads
	-- (the road module), anchors (source anchors), profiles (the capital
	-- roster rows), kits and prepared ({key -> kit}, {prefix -> prepared
	-- plot}), authored (the authored water rows), proxy (LAKE_PROXY).
	-- Returns the payload text, the canal rows and per-capital statistics.
	function M.plan_all(env)
		local session = env.session
		local network = session.road_layout()
		if not network then fail("the road network was not built in this environment") end
		local rivers = session.river_polylines()
		local texts, rows, stats = {}, {}, {}
		for _, profile in ipairs(env.profiles) do
			local key = profile.key
			local kit = env.kits[key]
			local cfg = kit.cfg
			local anchor
			for _, a in ipairs(env.anchors) do
				if a.id == profile.anchor_id then
					anchor = {id = a.id, x = a.position.x, z = a.position.z}
				end
			end
			if not anchor then fail("capital anchor missing: " .. key) end
			-- road ends at the reserved edge, heading into the area
			local ends = {}
			for _, r in ipairs(network.roads) do
				local n = #r.X
				if r.a == anchor.id then
					local hx, hz = r.X[1] - r.X[3], r.Z[1] - r.Z[3]
					local l = sqrt(hx * hx + hz * hz)
					ends[#ends + 1] = {x = r.X[1], z = r.Z[1], q = r.RQ[1], hx = hx / l,
						hz = hz / l, kind = r.kind, road = r.id}
				end
				if r.b == anchor.id then
					local hx, hz = r.X[n] - r.X[n - 2], r.Z[n] - r.Z[n - 2]
					local l = sqrt(hx * hx + hz * hz)
					ends[#ends + 1] = {x = r.X[n], z = r.Z[n], q = r.RQ[n], hx = hx / l,
						hz = hz / l, kind = r.kind, road = r.id}
				end
			end
			table.sort(ends, function(a, b) return a.road < b.road end)
			-- the plot kit with bounds and cleared airspace
			local required = required_of(key)
			local plots = {}
			for _, plot in ipairs(kit.plots) do
				local prepared = env.prepared[key .. "_" .. plot.id]
				plots[#plots + 1] = {id = plot.id, district = plot.district, kind = plot.kind,
					bounds = prepared.bounds, clear_to = prepared.clear_to,
					required = required[plot.id] == true}
			end
			for id in pairs(required) do
				local found = false
				for _, p in ipairs(plots) do if p.id == id then found = true end end
				if not found then fail(key .. ": required plot missing from the kit: " .. id) end
			end
			-- the district that stays beside the capital's civic lake
			local pin
			if cfg.lake then
				local lake
				for _, row in ipairs(env.authored) do
					if row.id == cfg.lake then lake = row end
				end
				if not lake then fail(key .. ": civic lake row missing: " .. cfg.lake) end
				local cx = 0.5 * (lake.min_x + lake.max_x) - anchor.x
				local cz = 0.5 * (lake.min_z + lake.max_z) - anchor.z
				for _, p in ipairs(plots) do
					if p.district:find(cfg.pin, 1, true) then
						pin = pin or {}
						pin[p.district] = {cx, cz}
					end
				end
			end
			local opts = {WALL = cfg.edge, PIN = pin, CANAL = cfg.canal == true}
			for k, v in pairs(planner.EDGE[cfg.edge].opts) do opts[k] = v end
			-- the core's own landing on an axis: a solid core cell at the
			-- core's edge on the axis near the core's level (Kezamba's decks
			-- over its cenote); a civic-water edge without one gets no avenue
			-- from the core (the planner starts it on the far shore)
			local core_cells = kit.core.build().cells
			local function core_landing(dx, dz)
				for _, cell in ipairs(core_cells) do
					local along = cell.x * dx + cell.z * dz
					local across = cell.x * dz - cell.z * dx
					if along >= 46 and along <= 49 and across >= -3 and across <= 3 and
							cell.y >= -1 and cell.y <= 1 and cell.name ~= "air" and
							not cell.name:find("water", 1, true) then
						return true
					end
				end
				return false
			end
			local inputs = {anchor = anchor, sample = session.fitted_values_at,
				core_landing = core_landing,
				rivers = rivers, simplex = env.simplex, road_ends = ends, plots = plots,
				roads_module = env.roads, network_roads = network.roads}
			local t0 = os.clock()
			local plan = planner.plan(env.seed, inputs, opts)
			local seconds = os.clock() - t0
			-- the required plots are always placed (the planner forces them in
			-- before any other plot); a missing one fails the load here, named
			local placed_ids = {}
			for _, p in ipairs(plan.plots) do placed_ids[p.id] = true end
			local missing = {}
			for id in pairs(required) do
				if not placed_ids[id] then missing[#missing + 1] = id end
			end
			if #missing > 0 then
				table.sort(missing)
				fail(key .. ": required plot not placed: " .. table.concat(missing, ", "))
			end
			local text = planner.serialize(plan)
			local layout = planner.deserialize(text)
			-- streets and connectors join the road layout (session-level
			-- connect: re-serialized, sampler rebuilt, memos flushed)
			session.add_roads(plan.layout.roads, M.squares(layout))
			if layout.canal then
				rows[#rows + 1] = M.canal_row("canal_" .. key, layout.anchor, layout.canal,
					env.proxy)
			end
			texts[#texts + 1] = text
			local st = plan.stats
			local built = 96 * 96
			local placed_required = 0
			for _, p in ipairs(plan.plots) do
				built = built + (p.x1 - p.x0 + 1) * (p.z1 - p.z0 + 1)
				if p.required then placed_required = placed_required + 1 end
			end
			local nreq = 0
			for _ in pairs(required) do nreq = nreq + 1 end
			local left_buildings = 0
			for _, p in ipairs(plan.left_out) do
				if p.kind ~= "fill" then left_buildings = left_buildings + 1 end
			end
			-- the streets whose profile did not fit their pinned ends (the core,
			-- a gate or a road end) and follow the ground instead: the road
			-- module's "infeasible" fallback, named by their ends for the log
			local unpinned = {}
			local kit_stats = st.kit_stats or {}
			for token in (kit_stats.infeasible_ids or ""):gmatch("%S+") do
				local road = plan.layout.roads[tonumber(token:match("^(%d+):") or "")]
				unpinned[#unpinned + 1] = road and
					(road.kind .. " " .. tostring(road.a) .. " - " .. tostring(road.b)) or token
			end
			stats[#stats + 1] = {key = key, area = plan.area, built = built / plan.area,
				placed = #plan.plots, total = #plots, overflowed = #st.overflowed,
				left_out = #plan.left_out, left_out_buildings = left_buildings,
				required = placed_required, required_total = nreq,
				relaxed = #plan.relaxed, seconds = seconds, sample_seconds = st.t.sample,
				payload = #text, open_arcs = st.open_arcs or 0, cross_lanes = st.cross_lanes or 0,
				squares = st.squares or 0, streets = #plan.layout.roads,
				infeasible = kit_stats.infeasible or 0, unpinned = unpinned,
				no_route = st.no_route, connector_failed = st.connector_failed or 0,
				shore_avenues = st.shore_avenues or 0, gate_runouts = st.gate_runouts or 0,
				wet_avenue_ends = st.wet_avenue_ends or 0,
				plan = plan}
		end
		if #rows > 0 then session.add_authored(rows) end
		return table.concat(texts), rows, stats
	end

	return M
end
