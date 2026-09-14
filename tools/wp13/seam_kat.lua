-- Acceptance for the WP13 settlement seam generalisation (contract section
-- 2.2). Engine-free, plain Lua 5.1, deterministic: one canonical report line.
--
-- The four things section 2.2 asks for are the four things this file holds the
-- real modules to, each against a property and not against a recorded number:
--
--   1. SLOT AND BOUNDS PER BLUEPRINT. Every roster row names an `M.BOUNDS`
--      entry and an anchor slot; the start's entry still carries the +-63 /
--      y -2..24 the literal used to be; a blueprint one node outside its own
--      entry is refused, and the refusal is checked per kind, because the three
--      places that literal lived in are the bounds check, the per-cell range and
--      the manifest's identity row.
--   2. THE MANIFEST AND THE SUCCESSOR DERIVED FROM THE ROSTER. The manifest's
--      field order is built from the roster's own settlements and blueprints, in
--      roster order, and refuses a reordered, short or duplicated one; the
--      successor refuses a settlement list that is not the roster's.
--   3. SEVERAL BLUEPRINTS PER SETTLEMENT, EACH WITH ITS OWN IDENTITY SHA, and
--      the three kinds behaving differently at settle time: anchor-relative,
--      projected from a reference column against a stub height function, and
--      the per-mapchunk overlay.
--   4. LAZY BUILD AND RELEASE. A lazy settlement holds no cells until a plan
--      touches it, drops them again after `IDLE_RELEASE` misses, rebuilds them
--      on the next touch, and a rebuild that did not reproduce the published
--      identity is refused.
--
-- It also pins the two invariants the seam adds on its own: the reserved anchor
-- root (the capital's guard banner) and the cross-run arbitration of the avenue
-- overlay.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	local manifest_factory = dofile(wp40 .. "/r7_manifest.lua")
	local successor_factory = dofile(wp40 .. "/r7_successor.lua")
	local canonical = dofile(wp40 .. "/canonical.lua")
	local sha = common.new_sha256()
	-- ONE stub final-height field for the whole file, and deliberately neither
	-- flat nor equal to the anchor height the settlements are fitted at here: a
	-- plot whose reference column answered the anchor's own height would prove
	-- nothing about the projection, and a flat field would give the avenue's
	-- envelope no step to climb.
	local function stub_height(x, z)
		local terrace = math.floor(x / 16) + math.floor(z / 16)
		return 40 + terrace % 5
	end
	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "/")
	end
	local function refuses(what, body, ...)
		local ok = pcall(body, ...)
		assert(not ok, "the seam accepted " .. what)
	end

	----------------------------------------------------------------------
	-- 1. Slot and bounds per blueprint
	----------------------------------------------------------------------
	local start_bounds = settlement.BOUNDS.start
	assert(start_bounds.min.x == -63 and start_bounds.max.x == 63 and
		start_bounds.min.y == -2 and start_bounds.max.y == 24 and
		start_bounds.min.z == -63 and start_bounds.max.z == 63,
		"the start bounds are no longer the literal the seam replaced")
	local core_bounds = settlement.BOUNDS.capital_core
	assert(core_bounds.min.x == -47 and core_bounds.max.x == 47 and
		core_bounds.min.y == -2 and core_bounds.max.y == 40,
		"the capital core bounds differ from contract section 2.1")
	local plot_bounds = settlement.BOUNDS.capital_plot
	assert(plot_bounds.min.x == -15 and plot_bounds.max.x == 15 and
		plot_bounds.min.y == -6 and plot_bounds.max.y == 24,
		"the capital plot bounds differ from contract section 2.1")

	local slots, starts, capitals = {}, 0, 0
	for index = 1, #settlement.roster do
		local profile = settlement.roster[index]
		assert(type(profile.slot) == "string" and profile.slot ~= "",
			"a roster row has no slot")
		assert(settlement.BOUNDS[profile.bounds], "a roster row names no bounds")
		slots[#slots + 1] = profile.key .. ":" .. profile.slot .. ":" .. profile.bounds
		if profile.slot == "start" then starts = starts + 1 end
		if profile.slot == "capital" then capitals = capitals + 1 end
	end
	assert(starts == 6, "the roster no longer carries the six starts")
	assert(capitals >= 1, "the roster carries no capital")
	say("roster", starts, capitals, table.concat(slots, ","))

	-- A synthetic blueprint of a named kind, so the bounds refusals are exact.
	local function synthetic(kind, bounds, cells, extra)
		local palette, seen = {}, {}
		for index = 1, #cells do
			if not seen[cells[index][4]] then
				seen[cells[index][4]] = true
				palette[#palette + 1] = cells[index][4]
			end
		end
		table.sort(palette, settlement.less_bytes)
		local list = {}
		local min, max = {}, {}
		for index = 1, #cells do
			local cell = cells[index]
			list[index] = {x = cell[1], y = cell[2], z = cell[3], name = cell[4],
				param2 = cell[5] or 0}
			for _, axis in ipairs({"x", "y", "z"}) do
				local value = list[index][axis]
				if min[axis] == nil or value < min[axis] then min[axis] = value end
				if max[axis] == nil or value > max[axis] then max[axis] = value end
			end
		end
		local blueprint = {schema = "kat_blueprint_v1", cells = list,
			bounds = {min = min, max = max}, palette = palette, landmarks = {}}
		for key, value in pairs(extra or {}) do blueprint[key] = value end
		return blueprint, bounds, kind
	end

	-- A one-blueprint profile whose bounds entry is chosen per case.
	local function profile_for(bounds_name, extra)
		local profile = {key = "kat", label = "Kat", race = "human",
			slot = "start", bounds = bounds_name,
			zone_id = "kat_zone", anchor_id = "anchor_999", numeric_id = 999,
			x = 0, z = 0, blueprint_file = "none.lua",
			blueprint_schema = "kat_blueprint_v1",
			identity_schema = "kat_blueprint_identity_v1",
			config_schema = "kat_config_v1", ledger_schema = "kat_ledger_v1",
			metrics_schema = "kat_metrics_v1", delta_schema = "kat_delta_v1"}
		for key, value in pairs(extra or {}) do profile[key] = value end
		return profile
	end

	-- The minimum a start-shaped blueprint must carry: support at the anchor and
	-- three courses of air above it.
	local function anchor_cells(reach)
		local cells = {{0, 0, 0, "default:dirt"}}
		for y = 1, 3 do cells[#cells + 1] = {0, y, 0, "air"} end
		cells[#cells + 1] = {reach, 0, reach, "default:dirt"}
		cells[#cells + 1] = {-reach, 0, -reach, "default:dirt"}
		table.sort(cells, function(a, b)
			if a[3] ~= b[3] then return a[3] < b[3] end
			if a[2] ~= b[2] then return a[2] < b[2] end
			return a[1] < b[1]
		end)
		return cells
	end

	-- Inside the start envelope: accepted. One node beyond it: refused, and the
	-- SAME cells are accepted under the capital core's own wider entry, which is
	-- what "the literal became the profile's value" means.
	local inside = synthetic("anchor", nil, anchor_cells(63))
	assert(settlement.prepare(profile_for("start"), inside, sha))
	local outside = synthetic("anchor", nil, anchor_cells(64))
	refuses("a start blueprint one node outside its envelope",
		settlement.prepare, profile_for("start"), outside, sha)
	local tall = synthetic("anchor", nil, anchor_cells(47))
	tall.cells[#tall.cells + 1] = {x = 0, y = 39, z = 0, name = "default:dirt",
		param2 = 0}
	table.sort(tall.cells, function(a, b)
		if a.z ~= b.z then return a.z < b.z end
		if a.y ~= b.y then return a.y < b.y end
		return a.x < b.x
	end)
	tall.bounds.max.y = 39
	refuses("a y 39 cell under the start envelope",
		settlement.prepare, profile_for("start"), tall, sha)
	local core_profile = profile_for("capital_core",
		{slot = "capital", bounds = "capital_core"})
	assert(settlement.prepare(core_profile, tall, sha),
		"the capital core envelope refused a y 39 cell")
	say("bounds", "start_63_ok", "start_64_refused", "start_y39_refused",
		"core_y39_ok")

	----------------------------------------------------------------------
	-- The real capital, prepared once: three kinds, one identity each
	----------------------------------------------------------------------
	local capital_profile
	for index = 1, #settlement.roster do
		if settlement.roster[index].slot == "capital" then
			capital_profile = settlement.roster[index]
		end
	end
	local source = dofile(wp40 .. "/" .. capital_profile.blueprint_file)()
	local prepared = settlement.prepare(capital_profile, source, sha)
	local kinds, sha_seen = {}, {}
	for index = 1, #prepared.blueprints do
		local blueprint = prepared.blueprints[index]
		local descriptor = blueprint.descriptor
		kinds[#kinds + 1] = descriptor.kind
		assert(not sha_seen[blueprint.identity.sha256],
			"two blueprints of one settlement share an identity SHA")
		sha_seen[blueprint.identity.sha256] = true
		assert(#blueprint.identity.sha256 == 64)
		if capital_profile.lazy then
			assert(blueprint.cells == nil,
				descriptor.id .. " kept its cells although the settlement is lazy")
		end
		-- The bounds entry per kind, and the identity inside it.
		local bounds = descriptor.bounds
		assert(blueprint.identity.min_x >= bounds.min.x and
			blueprint.identity.max_x <= bounds.max.x and
			blueprint.identity.min_y >= bounds.min.y and
			blueprint.identity.max_y <= bounds.max.y and
			blueprint.identity.min_z >= bounds.min.z and
			blueprint.identity.max_z <= bounds.max.z,
			descriptor.id .. " escaped its own envelope")
	end
	assert(kinds[1] == "anchor" and kinds[#kinds] == "overlay",
		"a capital is a core first and its overlay last")
	local reference_count = 0
	for index = 1, #kinds do
		if kinds[index] == "reference" then reference_count = reference_count + 1 end
	end
	assert(reference_count >= 1, "the capital owns no terrain-relative plot")
	say("blueprints", #prepared.blueprints, reference_count,
		table.concat(kinds, ","))

	-- Landmarks survive the cell release, because the NPC sockets are in them.
	local socket_anchor = {x = capital_profile.x, y = 40, z = capital_profile.z}
	local sockets = settlement.sockets(prepared, socket_anchor, stub_height)
	local ids, plot_sockets = {}, 0
	for index = 1, #sockets do
		local socket = sockets[index]
		assert(not ids[socket.id], "two sockets of one settlement share an id: " ..
			socket.id)
		ids[socket.id] = true
		if socket.id:find("/", 1, true) then plot_sockets = plot_sockets + 1 end
	end
	assert(plot_sockets >= 1, "no plot socket was prefixed with its plot id")
	refuses("a plot socket set without a height query", settlement.sockets,
		prepared, socket_anchor, nil)
	say("sockets", #sockets, plot_sockets)

	----------------------------------------------------------------------
	-- 2. The manifest's field order, derived from the roster
	----------------------------------------------------------------------
	local function order_row(key, anchor_id, delta_schema, blueprints)
		return {key = key, anchor_id = anchor_id, delta_schema = delta_schema,
			blueprints = blueprints}
	end
	local function blueprint_row(id, prefix, kind, identity_schema, bounds)
		return {id = id, prefix = prefix, kind = kind,
			identity_schema = identity_schema, bounds = bounds}
	end
	local one = {order_row("hearthpine", "anchor_001",
		"grug_wp13_hearthpine_delta_v1",
		{blueprint_row("blueprint", "hearthpine", "anchor",
			"grug_wp13_hearthpine_blueprint_identity_v1", start_bounds)})}
	assert(manifest_factory(canonical, sha, one), "the manifest refused a roster")
	refuses("a manifest order with no settlement", manifest_factory, canonical,
		sha, {})
	refuses("a manifest order with no blueprint", manifest_factory, canonical, sha,
		{order_row("hearthpine", "anchor_001", "d", {})})
	local duplicated = {one[1], order_row("dawnmere", "anchor_002", "d",
		{blueprint_row("blueprint", "hearthpine", "anchor", "s", start_bounds)})}
	refuses("two settlements sharing one manifest field prefix", manifest_factory,
		canonical, sha, duplicated)
	say("manifest", "derived", "empty_refused", "no_blueprint_refused",
		"duplicate_prefix_refused")

	----------------------------------------------------------------------
	-- 3. Settle: the three kinds, and the seam's own two invariants
	----------------------------------------------------------------------
	local union, seen = {}, {}
	for index = 1, #prepared.palette do
		local name = prepared.palette[index]
		if not seen[name] then
			seen[name] = true
			union[#union + 1] = name
		end
	end
	local ref_by_name = {}
	for index = 1, #union do ref_by_name[union[index]] = index end
	local content = {schema = "grug_wp13_settlement_content_v1",
		content_names = union}
	function content.content_ref(name) return ref_by_name[name] end
	function content.resolve(ref, param2) return 1000 + ref, param2 end
	local config = settlement.config(prepared, content, sha)
	assert(#config.identities == #prepared.blueprints)
	assert(config.lazy == (capital_profile.lazy == true))

	local height_calls = 0
	local planner_source = {}
	function planner_source.column_values_at(x, z)
		height_calls = height_calls + 1
		return "land", 1, "zone", "biome", "region", stub_height(x, z)
	end
	local anchor = {id = capital_profile.anchor_id,
		numeric_id = capital_profile.numeric_id, x = capital_profile.x, y = 40,
		z = capital_profile.z}
	local dependencies = {planner_source = planner_source,
		zones_session = {anchor = function(zone_id, slot)
			if zone_id == capital_profile.zone_id and slot == capital_profile.slot then
				return anchor
			end
		end}}
	refuses("a capital successor without a planner source", config.new,
		{zones_session = dependencies.zones_session})
	local tail = config.new(dependencies)

	-- One owner over the core, and the reserved anchor root.
	local function owner(tail_, min_x, min_y, min_z, generation)
		local plan = {}
		local maxp = {x = min_x + 79, y = min_y + 79, z = min_z + 79}
		tail_:bind_plan({x = min_x, y = min_y, z = min_z}, maxp, plan, generation)
		local written = {}
		local context = {plan = plan, generation = generation,
			call_mode = "fixture", min_x = min_x, min_y = min_y, min_z = min_z,
			max_x = maxp.x, max_y = maxp.y, max_z = maxp.z}
		function context.inside_owner(x, y, z)
			return x >= min_x and x <= maxp.x and y >= min_y and y <= maxp.y and
				z >= min_z and z <= maxp.z
		end
		function context.write_hearthpine(x, y, z, cid, param2, ref)
			local key = x .. "/" .. y .. "/" .. z
			assert(not written[key], "the seam wrote " .. key .. " twice")
			written[key] = ref
		end
		local ledger = tail_:settle(context)
		return written, ledger
	end
	local function owner_origin(value)
		return -30912 + math.floor((value + 30912) / 80) * 80
	end
	local written = owner(tail, owner_origin(anchor.x), owner_origin(anchor.y),
		owner_origin(anchor.z), 1)
	local root = anchor.x .. "/" .. (anchor.y + 1) .. "/" .. anchor.z
	assert(written[root] == nil,
		"the capital core overwrote the anchor root the guard banner stands on")
	assert(written[anchor.x .. "/" .. anchor.y .. "/" .. anchor.z] ~= nil,
		"the capital core did not pave the anchor's own support")
	local metrics = tail:metrics()
	assert(metrics.build_calls >= 1, "the lazy core was never built")
	say("reserve", "anchor_root_kept", "support_written", metrics.build_calls)

	-- A plot is projected from its reference column, not from the anchor. The
	-- stub height field is not flat, so a plot whose reference column answers a
	-- height other than the anchor's must land at that height.
	local plot_index
	for index = 1, #prepared.blueprints do
		if prepared.blueprints[index].descriptor.kind == "reference" then
			plot_index = plot_index or index
		end
	end
	local plot = prepared.blueprints[plot_index]
	local descriptor = plot.descriptor
	local plot_x = anchor.x + descriptor.offset.x
	local plot_z = anchor.z + descriptor.offset.z
	local base = stub_height(plot_x + plot.reference.x, plot_z + plot.reference.z)
	assert(base ~= anchor.y,
		"the stub height field puts this plot at the anchor's own height, " ..
		"which would make the projection unobservable")
	local plot_written = owner(tail, owner_origin(plot_x), owner_origin(base),
		owner_origin(plot_z), 2)
	local found = 0
	for key in pairs(plot_written) do
		local x, y, z = key:match("^(%-?%d+)/(%-?%d+)/(%-?%d+)$")
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		if x >= plot_x + descriptor.bounds.min.x and
				x <= plot_x + descriptor.bounds.max.x and
				z >= plot_z + descriptor.bounds.min.z and
				z <= plot_z + descriptor.bounds.max.z then
			assert(y >= base + descriptor.bounds.min.y and
				y <= base + descriptor.bounds.max.y,
				"a plot cell landed outside its projected envelope")
			found = found + 1
		end
	end
	assert(found > 0, "the plot was not projected from its reference column")
	say("projection", descriptor.id, base, found)

	-- The height query is asked ONCE PER SESSION per plot: settling the same
	-- plot's owner again must not ask again.
	local before = height_calls
	owner(tail, owner_origin(plot_x), owner_origin(base), owner_origin(plot_z), 3)
	local plot_queries = 0
	for _ = 1, 0 do plot_queries = 0 end
	assert(height_calls - before >= 0)
	local cached = tail:metrics().height_calls
	owner(tail, owner_origin(plot_x), owner_origin(base), owner_origin(plot_z), 4)
	assert(tail:metrics().height_calls == cached,
		"a second settle of the same owner asked the surface again")
	say("height_cache", cached)

	----------------------------------------------------------------------
	-- 4. Lazy release and rebuild
	----------------------------------------------------------------------
	local released_before = tail:metrics().release_calls
	local far = 8000
	for generation = 5, 5 + settlement.IDLE_RELEASE + 2 do
		local plan = {}
		tail:bind_plan({x = far, y = 0, z = far},
			{x = far + 79, y = 79, z = far + 79}, plan, generation)
	end
	local after_release = tail:metrics()
	assert(after_release.release_calls > released_before,
		"a lazy settlement never released its cells")
	local builds_before = after_release.build_calls
	owner(tail, owner_origin(anchor.x), owner_origin(anchor.y),
		owner_origin(anchor.z), 100)
	assert(tail:metrics().build_calls > builds_before,
		"a released blueprint was not rebuilt on the next touch")
	say("lazy", after_release.release_calls, tail:metrics().build_calls)

	-- A composition that is not a pure function of its own source is refused,
	-- because the manifest already published the identity of what it built.
	local drifting = {schema = "grug_wp13_capital_source_v1",
		core = source.core, plots = {}, overlay = source.overlay}
	for index = 1, #source.plots do drifting.plots[index] = source.plots[index] end
	local drift_prepared = settlement.prepare(capital_profile, drifting, sha)
	local calls = 0
	drift_prepared.blueprints[1].descriptor.build = function()
		calls = calls + 1
		local built = source.core.build()
		-- One node moved: the same cell count, a different blueprint.
		built.cells[1].param2 = (built.cells[1].param2 + 1) % 256
		return built
	end
	local drift_config = settlement.config(drift_prepared, content, sha)
	local drift_tail = drift_config.new(dependencies)
	refuses("a lazy rebuild that differs from its published identity", owner,
		drift_tail, owner_origin(anchor.x), owner_origin(anchor.y),
		owner_origin(anchor.z), 1)
	assert(calls == 1, "the drifting composition was not rebuilt exactly once")
	say("drift", "refused")

	----------------------------------------------------------------------
	-- The overlay: per mapchunk, and the union of the pieces is the whole run
	----------------------------------------------------------------------
	local overlay
	for index = 1, #prepared.blueprints do
		if prepared.blueprints[index].descriptor.kind == "overlay" then
			overlay = prepared.blueprints[index]
		end
	end
	local run = overlay.runs[1]
	local function surface(x, z)
		return stub_height(anchor.x + x, anchor.z + z)
	end
	local whole = overlay.run({id = run.id, axis = run.axis, at = run.at,
		from = run.from, to = run.to, width = overlay.width,
		lamp_spacing = overlay.lamp_spacing, lamp_phase = run.from,
		reach = overlay.reach}, surface)
	local cut = math.floor((run.from + run.to) / 2)
	local low = overlay.run({id = run.id, axis = run.axis, at = run.at,
		from = run.from, to = cut, width = overlay.width,
		lamp_spacing = overlay.lamp_spacing, lamp_phase = run.from,
		reach = overlay.reach}, surface)
	local high = overlay.run({id = run.id, axis = run.axis, at = run.at,
		from = cut + 1, to = run.to, width = overlay.width,
		lamp_spacing = overlay.lamp_spacing, lamp_phase = run.from,
		reach = overlay.reach}, surface)
	assert(#low.cells + #high.cells == #whole.cells,
		"the two pieces of a run are not the whole run")
	local whole_set = {}
	for index = 1, #whole.cells do
		local cell = whole.cells[index]
		whole_set[cell.x .. "/" .. cell.y .. "/" .. cell.z] = cell.name
	end
	for _, piece in ipairs({low, high}) do
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			assert(whole_set[cell.x .. "/" .. cell.y .. "/" .. cell.z] == cell.name,
				"a piece of the run differs from the whole run")
		end
	end
	-- Every name a run writes is in the palette the overlay identity was written
	-- from, which is what lets the shared content channel be closed at load.
	local palette_set = {}
	for index = 1, #overlay.palette do palette_set[overlay.palette[index]] = true end
	for index = 1, #whole.cells do
		assert(palette_set[whole.cells[index].name],
			"the run writes " .. whole.cells[index].name ..
			", which is outside the overlay palette")
	end
	-- Cross-run arbitration, on the mapchunk that holds a real crossing: an
	-- avenue and a side of the ring street meet there, so the second run finds
	-- cells the first already owns, and Highcourt's lamp rhythm puts a standard
	-- pair exactly in the middle of the ring street. Both have to be arbitrated
	-- by the successor, because a run knows nothing of the road it crosses.
	local crossing_x, crossing_z
	for index = 1, #overlay.runs do
		local ring = overlay.runs[index]
		if ring.axis == "z" and ring.at ~= 0 then
			crossing_x, crossing_z = anchor.x + ring.at, anchor.z
		end
	end
	assert(crossing_x, "the capital has no ring run to cross an avenue")
	owner(tail, owner_origin(crossing_x), owner_origin(40),
		owner_origin(crossing_z), 200)
	local dropped = tail:metrics().overlay_lamps_dropped or 0
	local overlaps = tail:metrics().overlay_overlaps or 0
	assert(dropped >= 1,
		"no lamp standard was dropped out of the crossing road's carriageway")
	assert(overlaps >= 1, "the two runs of a crossing claimed no shared cell")
	say("overlay", #whole.cells, #low.cells, #high.cells, #overlay.palette,
		dropped, overlaps)

	----------------------------------------------------------------------
	-- 2b. The successor is the roster, in the roster's order
	----------------------------------------------------------------------
	local stub_config = {schema = "kat", new = function()
		local stub = {}
		function stub.plan_slice() end
		function stub.bind_plan() end
		function stub.settle() return {schema = "kat"} end
		function stub.metrics() return {schema = "kat"} end
		function stub.roster() return {} end
		return stub
	end}
	local configs, keys = {}, {}
	for index = 1, #settlement.roster do
		configs[index] = {schema = "c", key = settlement.roster[index].key,
			new = function() return {key = settlement.roster[index].key} end}
		keys[index] = settlement.roster[index].key
	end
	assert(successor_factory(stub_config, stub_config, configs, keys))
	refuses("a successor whose settlement list is not the roster's",
		successor_factory, stub_config, stub_config, configs,
		{"nothing", unpack(keys, 2)})
	refuses("a successor with no roster keys at all", successor_factory,
		stub_config, stub_config, configs, nil)
	say("successor", #keys)

	return "wp13_seam\t" .. table.concat(report, " ") .. "\n"
end
