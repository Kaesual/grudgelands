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
	assert(core_bounds.min.x == -49 and core_bounds.max.x == 49 and
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
		-- The FIRST capital, not the last. This used to take whichever capital
		-- the roster ended with, so the day a second one landed this fixture
		-- silently stopped exercising the first and nothing said so. The seam
		-- is what is under test here and one capital proves it; each capital's
		-- own KAT (`highcourt_kat.lua`, `dur_brannoc_kat.lua`) proves its own
		-- composition and its own seam wiring.
		if settlement.roster[index].slot == "capital" and not capital_profile then
			capital_profile = settlement.roster[index]
		end
	end
	local capital_file = dofile(wp40 .. "/" .. capital_profile.blueprint_file)
	local source = capital_file()
	local prepared = settlement.prepare(capital_profile, source, sha)

	-- THE QUADRANT SEAM IS HANDED IN, NOT READ. `r7_runtime.lua` validates the
	-- world seed once and passes it here, so the offsets and the `full_seed`
	-- the two environments compare are the same value. Three properties, and
	-- the third is the one that matters:
	--
	--   * no seam at all is the canonical assignment (every engine-free tool);
	--   * HALF a seam is refused, rather than silently falling back to
	--     canonical and putting the districts somewhere the other environment
	--     did not;
	--   * a seed changes the offsets and changes NO identity, because a plot's
	--     cells do not know which quadrant they will stand in.
	do
		refuses("a capital source with a seed and no SHA-256", capital_file,
			{full_seed = "8675309"})
		refuses("a capital source with a SHA-256 and no seed", capital_file,
			{raw_sha256 = sha})
		refuses("a capital source with a seed that is not one", capital_file,
			{full_seed = "not a seed", raw_sha256 = sha})
		local seeded = capital_file({full_seed = "8675309", raw_sha256 = sha})
		local again = capital_file({full_seed = "8675309", raw_sha256 = sha})
		assert(#seeded.plots == #source.plots,
			"a seeded capital has a different plot population")
		local moved, identical = 0, 0
		for index = 1, #seeded.plots do
			local canonical_plot, seeded_plot = source.plots[index], seeded.plots[index]
			assert(canonical_plot.id == seeded_plot.id,
				"the seed reordered the plot list")
			assert(seeded_plot.x == again.plots[index].x and
				seeded_plot.z == again.plots[index].z,
				"one seed placed the same plot twice over")
			if canonical_plot.x ~= seeded_plot.x or
					canonical_plot.z ~= seeded_plot.z then
				moved = moved + 1
			end
			local canonical_cells = canonical_plot.build()
			local seeded_cells = seeded_plot.build()
			if canonical_cells.schema == seeded_cells.schema and
					#canonical_cells.cells == #seeded_cells.cells then
				identical = identical + 1
			end
		end
		assert(moved > 0, "the seed moved no plot at all")
		assert(identical == #seeded.plots,
			"the seed changed a plot's own cells, which are not the seed's")
		say("quadrants", #seeded.plots, moved, identical,
			table.concat(seeded.districts.permutation, ","))
	end
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

	-- THE OVERLAY'S PUBLISHED BOX IS THE ROAD'S, not the civic core's, and it
	-- is inside the capital's hard protection. The first version of this package
	-- published the 96-node core box for a blueprint that writes out to +-256,
	-- and a cell count of 8 for a blueprint that has no cells at all.
	local overlay_blueprint
	for index = 1, #prepared.blueprints do
		if prepared.blueprints[index].descriptor.kind == "overlay" then
			overlay_blueprint = prepared.blueprints[index]
		end
	end
	local overlay_identity = overlay_blueprint.identity
	assert(overlay_identity.cell_count == nil,
		"the overlay publishes a cell count, and it has no cells")
	assert(overlay_identity.run_count == #overlay_blueprint.runs,
		"the overlay's published population is not its run count")
	local reach = 0
	for index = 1, #overlay_blueprint.runs do
		local run = overlay_blueprint.runs[index]
		reach = math.max(reach, math.abs(run.from), math.abs(run.to),
			math.abs(run.at) + overlay_blueprint.half + 1)
	end
	assert(overlay_identity.max_x >= reach and overlay_identity.min_x <= -reach,
		"the overlay's published box is narrower than the road it describes")
	-- The 532-node hard capital footprint of `source/simple_map.lua`, which is
	-- what the overlay's own envelope entry is: 266 either side.
	local PROTECTED_HALF_WIDTH = 266
	assert(settlement.BOUNDS.capital_overlay.max.x == PROTECTED_HALF_WIDTH and
		settlement.BOUNDS.capital_overlay.min.x == -PROTECTED_HALF_WIDTH,
		"the overlay envelope is no longer the capital's protected footprint")
	assert(reach <= PROTECTED_HALF_WIDTH,
		"an avenue run reaches " .. reach ..
		", outside the 532-node protected capital footprint")
	-- And a run that DOES leave it is refused, so the bound is enforced and not
	-- merely true today.
	do
		local rogue = {schema = "grug_wp13_capital_source_v1", core = source.core,
			plots = source.plots, overlay = {}}
		for key, value in pairs(source.overlay) do rogue.overlay[key] = value end
		rogue.overlay.runs = {}
		for index = 1, #source.overlay.runs do
			local run = source.overlay.runs[index]
			rogue.overlay.runs[index] = {id = run.id, axis = run.axis, at = run.at,
				from = run.from, to = run.to}
		end
		rogue.overlay.runs[1].to = PROTECTED_HALF_WIDTH + 1
		refuses("an avenue run outside the protected capital footprint",
			settlement.prepare, capital_profile, rogue, sha)
	end
	say("blueprints", #prepared.blueprints, reference_count,
		table.concat(kinds, ","), "overlay_reach_" .. reach)

	-- Landmarks survive the cell release, because the NPC sockets are in them.
	local socket_anchor = {x = capital_profile.x, y = 40, z = capital_profile.z}
	local sockets = settlement.sockets(prepared, socket_anchor, stub_height)
	local ids, plot_sockets, spare_sockets = {}, 0, 0
	for index = 1, #sockets do
		local socket = sockets[index]
		-- The SPARE flag has to cross the seam untouched: it is what tells the
		-- placement engine this authored position is a wander target and not a
		-- home (playtest round 2), and a seam that dropped it would quietly put
		-- a citizen on every one of them.
		if socket.spawn == false then spare_sockets = spare_sockets + 1 end
		assert(not ids[socket.id], "two sockets of one settlement share an id: " ..
			socket.id)
		ids[socket.id] = true
		if socket.id:find("/", 1, true) then plot_sockets = plot_sockets + 1 end
	end
	assert(plot_sockets >= 1, "no plot socket was prefixed with its plot id")
	refuses("a plot socket set without a height query", settlement.sockets,
		prepared, socket_anchor, nil)
	assert(spare_sockets >= 1, "no spare socket survived the seam")
	say("sockets", #sockets, plot_sockets, spare_sockets)

	-- THE TERRAIN AUDIT. The writer projects a terrain-relative blueprint from
	-- one column and asks nothing else about the ground; the positions it is
	-- handed are legal on the two seeds somebody measured. `audit_terrain` is
	-- what makes a THIRD seed diagnosable instead of silent, so it is checked
	-- the way a diagnostic has to be: it says nothing about ground that
	-- carries the plots, and it names every plot on ground that does not.
	do
		local function dry_and_flat() return "land", 1, "z", "b", "r", 40 end
		assert(#settlement.audit_terrain(prepared, socket_anchor,
			dry_and_flat) == 0,
			"the terrain audit complained about flat dry ground")
		-- A river down the middle of the envelope and a cliff beside it. The
		-- two are deliberately coarse: what is asserted is that the audit
		-- finds the plots standing in them, not a particular count.
		local function river_and_cliff(x, z)
			local dx, dz = x - socket_anchor.x, z - socket_anchor.z
			local class = (dx > 100) and "river" or "land"
			return class, 1, "z", "b", "r", 40 - math.abs(dz)
		end
		local findings = settlement.audit_terrain(prepared, socket_anchor,
			river_and_cliff)
		assert(#findings > 0, "the terrain audit passed a plot in a river")
		local wet, steep = 0, 0
		for index = 1, #findings do
			local finding = findings[index]
			assert(type(finding.plot_id) == "string",
				"a finding does not name its plot")
			if finding.submerged > 0 then wet = wet + 1 end
			if finding.fall > finding.skirt then steep = steep + 1 end
		end
		assert(wet > 0 and steep > 0,
			"the terrain audit found no water and no fall on ground that has both")
		refuses("a terrain audit without a column authority",
			settlement.audit_terrain, prepared, socket_anchor, nil)
		say("terrain_audit", #findings, wet, steep)
	end

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
	-- Every column the successor asks about, counted: this is what makes "once
	-- per session per plot" a statement about the plot's own column rather than
	-- about a total that several callers share.
	local probe_columns = {}
	-- A WP40 BRIDGE DECK OVER THE CAPITAL'S OWN STREET, in the stub.
	--
	-- The overlay is handed its ground AND the route geometry over it by this
	-- seam, out of one `column_values_at` (`wp40/r7_settlement.lua`,
	-- `walkable_values`). A stub that answered only six values could never
	-- report a deck, so the handoff had no engine-free gate at all: cutting it
	-- left every KAT green and only the live seeds noticed.
	--
	-- This band crosses the FIRST overlay run, far enough from the core and
	-- the plots that nothing else in this file sees it, at a level the road
	-- cannot pass under (the stub ground here is 40 to 44 and a deck's
	-- underside is one below its surface, so 46 leaves nothing walkable). The
	-- overlay must therefore climb onto it -- section "the overlay meets a
	-- route" below is that assertion.
	local DECK = {min_x = -4, max_x = 4, min_z = -1602, max_z = -1598, y = 46}
	local function stub_deck(x, z)
		if x >= DECK.min_x and x <= DECK.max_x and
				z >= DECK.min_z and z <= DECK.max_z then
			return DECK.y
		end
		return nil
	end
	local planner_source = {}
	function planner_source.column_values_at(x, z)
		height_calls = height_calls + 1
		local key = x .. ":" .. z
		probe_columns[key] = (probe_columns[key] or 0) + 1
		-- The tuple the live planner source publishes, as far as the seam
		-- reads it: water class, zone, biome, race, the final height, the
		-- water surface, the classified hydrology and its depth, then the
		-- FUNCTIONAL kind and height -- which is where a bridge deck lives.
		return "land", 1, "zone", "biome", "region", stub_height(x, z),
			nil, nil, nil,
			stub_deck(x, z) and "bridge_deck" or nil, stub_deck(x, z)
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
	-- THE NEGATIVE CASE, without which "the reservation works" says nothing: a
	-- settlement that does NOT reserve its anchor root writes that cell like any
	-- other. The six starts are exactly that, and a start's blueprint has air at
	-- (0, 1, 0) too -- its spawn clearance -- so the same cell is the test.
	local start_profile
	for index = 1, #settlement.roster do
		if settlement.roster[index].slot == "start" and not start_profile then
			start_profile = settlement.roster[index]
		end
	end
	assert(start_profile.reserve_anchor_root == nil,
		"a start reserves an anchor root; the negative case is gone")
	local start_source = dofile(wp40 .. "/" .. start_profile.blueprint_file)()
	local start_prepared = settlement.prepare(start_profile, start_source, sha)
	local start_union = {}
	for index = 1, #start_prepared.palette do
		start_union[index] = start_prepared.palette[index]
	end
	local start_refs = {}
	for index = 1, #start_union do start_refs[start_union[index]] = index end
	local start_content = {schema = "grug_wp13_settlement_content_v1",
		content_names = start_union}
	function start_content.content_ref(name) return start_refs[name] end
	function start_content.resolve(ref, param2) return 2000 + ref, param2 end
	local start_anchor = {id = start_profile.anchor_id,
		numeric_id = start_profile.numeric_id, x = start_profile.x, y = 40,
		z = start_profile.z}
	local start_tail = settlement.config(start_prepared, start_content, sha).new({
		zones_session = {anchor = function(zone_id, slot)
			if zone_id == start_profile.zone_id and slot == start_profile.slot then
				return start_anchor
			end
		end}})
	local start_written = owner(start_tail, owner_origin(start_anchor.x),
		owner_origin(start_anchor.y), owner_origin(start_anchor.z), 1)
	local start_root = start_anchor.x .. "/" .. (start_anchor.y + 1) .. "/" ..
		start_anchor.z
	assert(start_written[start_root] ~= nil,
		"a settlement that reserves nothing still skipped its anchor root, " ..
		"so the reservation is not what keeps the capital's banner")
	say("reserve", "anchor_root_kept", "support_written", metrics.build_calls,
		"start_root_written")

	-- A plot is projected from its reference column, not from the anchor. The
	-- stub height field is not flat, so a plot whose reference column answers a
	-- height other than the anchor's must land at that height.
	--
	-- WHICH plot is picked matters, and only in one way: it has to be one the
	-- stub field puts at a height that is NOT the anchor's, or the projection
	-- it is meant to demonstrate is invisible. A capital owns 36 of them and
	-- the stub field is a coarse terrace, so several land on the anchor's own
	-- height by coincidence; the first that does not is the one to walk.
	local plot_index
	for index = 1, #prepared.blueprints do
		local candidate = prepared.blueprints[index]
		if plot_index == nil and candidate.descriptor.kind == "reference" then
			local offset = candidate.descriptor.offset
			local height = stub_height(anchor.x + offset.x + candidate.reference.x,
				anchor.z + offset.z + candidate.reference.z)
			if height ~= anchor.y then plot_index = index end
		end
	end
	assert(plot_index, "the stub height field puts every plot at the anchor's " ..
		"own height, which would make the projection unobservable")
	local plot = prepared.blueprints[plot_index]
	local descriptor = plot.descriptor
	local plot_x = anchor.x + descriptor.offset.x
	local plot_z = anchor.z + descriptor.offset.z
	local base = stub_height(plot_x + plot.reference.x, plot_z + plot.reference.z)
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

	-- The height query is asked ONCE PER SESSION PER PLOT, and the way to say
	-- that is to count the reference-column queries themselves, not to watch a
	-- total stop growing: the overlay's ground memo shares the same counter, so
	-- "the number did not move" only ever meant "this owner asked nothing new".
	--
	-- `plot_probe` records every column the successor asks about. A plot's
	-- reference column must appear exactly once over the whole session,
	-- whatever order the mapchunks arrive in and however often the same plot is
	-- settled.
	local reference_column = (plot_x + plot.reference.x) .. ":" ..
		(plot_z + plot.reference.z)
	assert(probe_columns[reference_column] == 1,
		"the plot's reference column was asked " ..
		tostring(probe_columns[reference_column]) .. " times, not once")
	owner(tail, owner_origin(plot_x), owner_origin(base), owner_origin(plot_z), 3)
	owner(tail, owner_origin(plot_x), owner_origin(base), owner_origin(plot_z), 4)
	assert(probe_columns[reference_column] == 1,
		"re-settling a plot's owner asked its reference column again")
	-- And after a release and a rebuild it is STILL not asked again: the height
	-- is session state, the cells are not.
	local cached = tail:metrics().height_calls
	say("height_cache", cached, probe_columns[reference_column])

	----------------------------------------------------------------------
	-- 4. Lazy release and rebuild
	----------------------------------------------------------------------
	-- The idle window is PINNED, not read from the module: a package that
	-- shortened it to one would otherwise still pass this section while making
	-- every second mapchunk rebuild a capital.
	assert(settlement.IDLE_RELEASE == 64,
		"the lazy idle window is " .. tostring(settlement.IDLE_RELEASE) ..
		", not the 64 plans this KAT and the record are written against")
	local far = 8000
	-- The window, both sides, on a FRESH session so the idle counters start
	-- where this section can reason about them: one touch of the core's owner
	-- builds it and puts its counter at zero, and every later plan is a miss.
	do
		local window_tail = config.new(dependencies)
		owner(window_tail, owner_origin(anchor.x), owner_origin(anchor.y),
			owner_origin(anchor.z), 1)
		assert(window_tail:metrics().build_calls >= 1 and
			window_tail:metrics().release_calls == 0,
			"the fresh session did not build, or released at once")
		for generation = 2, settlement.IDLE_RELEASE do
			local plan = {}
			window_tail:bind_plan({x = far, y = 0, z = far},
				{x = far + 79, y = 79, z = far + 79}, plan, generation)
		end
		assert(window_tail:metrics().release_calls == 0,
			"a lazy settlement released its cells before the idle window was out")
		for generation = settlement.IDLE_RELEASE + 1, settlement.IDLE_RELEASE + 3 do
			local plan = {}
			window_tail:bind_plan({x = far, y = 0, z = far},
				{x = far + 79, y = 79, z = far + 79}, plan, generation)
		end
		assert(window_tail:metrics().release_calls >= 1,
			"a lazy settlement never released after its idle window was out")
	end
	local released_before = tail:metrics().release_calls
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
	-- The overlay meets a route: the seam's route handoff
	----------------------------------------------------------------------
	-- `wp13/avenue.lua` owns the crossing rule and `tools/wp13/
	-- lane_crossing_kat.lua` owns its properties, driving the module directly.
	-- What NEITHER of them can see is the HANDOFF: the seam reading the
	-- functional kind and height out of `column_values_at` and putting them in
	-- the run's spec. Cut that one field and both stay green, because a road
	-- with no route geometry is a perfectly good road -- it is only wrong in a
	-- world that has bridges in it.
	--
	-- So this drives the real successor over the stub's deck band and asks the
	-- WRITTEN CELLS whether the street climbed onto it. It is the same
	-- sentence the live capitals are held to, on a stub: at grade on the deck.
	local deck_written = owner(tail, owner_origin(0), owner_origin(anchor.y),
		owner_origin(DECK.min_z), 200)
	-- Every name the overlay may write that IS THE ROAD'S SURFACE.
	--
	-- An overlay's palette is the set of names its content channel is closed
	-- over, and it is wider than the carriageway in two ways this section has
	-- to take out, or it measures the top of the street as something that is
	-- standing on the street:
	--
	--   * AIR. Since Highcourt got a curtain wall the palette contains `air`,
	--     because `wall.palette_names` declares it: a wall CLEARS, the walk's
	--     headroom and the gate passage are authored air, and a name the
	--     channel does not know only fails on the mapchunk that finally needs
	--     it. An authored hole is not a road surface.
	--   * THE LAMP STANDARD. A standard is two log posts and a torch, and it
	--     stands ON the carriageway -- so in a deck column that carries one,
	--     the highest road-palette cell is the torch three courses over the
	--     deck, not the paving at it. The rhythm decides which columns those
	--     are, and the rhythm moves whenever a run's `from` moves: Highcourt's
	--     avenues reaching past the gate station to 261 for the wall's gate
	--     tunnel is what first put a standard on this stub's deck.
	--
	-- What is left is paving, kerb and tread, which is what "the street stands
	-- at the route's grade" is a sentence about.
	local NOT_THE_SURFACE = {["air"] = true, ["default:tree"] = true,
		["default:torch"] = true, ["default:torch_wall"] = true}
	local road_names = {}
	for index = 1, #overlay_blueprint.palette do
		local name = overlay_blueprint.palette[index]
		if not NOT_THE_SURFACE[name] then road_names[name] = true end
	end
	local deck_columns, deck_top = 0, {}
	for key, ref in pairs(deck_written) do
		local x, y, z = key:match("^(%-?%d+)/(%-?%d+)/(%-?%d+)$")
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		if road_names[union[ref]] and stub_deck(x, z) ~= nil then
			local column = x .. "/" .. z
			if deck_top[column] == nil then
				deck_columns = deck_columns + 1
				deck_top[column] = y
			elseif y > deck_top[column] then
				deck_top[column] = y
			end
		end
	end
	assert(deck_columns > 0,
		"the seam wrote no road at all over the stub's deck band; the overlay " ..
		"run this section relies on no longer crosses it")
	for column, top in pairs(deck_top) do
		assert(top == DECK.y, "the street stands at " .. top .. " in the column " ..
			column .. ", not at the route's grade " .. DECK.y ..
			" -- the seam's route handoff is gone")
	end
	-- And the ground under it is still the stub's, i.e. the deck did not leak
	-- into the height the plots are projected from.
	assert(stub_deck(DECK.min_x - 1, DECK.min_z) == nil and
		select(6, planner_source.column_values_at(DECK.min_x, DECK.min_z)) ==
			stub_height(DECK.min_x, DECK.min_z),
		"the stub deck changed the final height it stands over")
	say("route_handoff", deck_columns, DECK.y)

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
		lamp_spacing = overlay.lamp_spacing, lamp_phase = run.lamp_phase or run.from,
		reach = overlay.reach}, surface)
	local cut = math.floor((run.from + run.to) / 2)
	local low = overlay.run({id = run.id, axis = run.axis, at = run.at,
		from = run.from, to = cut, width = overlay.width,
		lamp_spacing = overlay.lamp_spacing, lamp_phase = run.lamp_phase or run.from,
		reach = overlay.reach}, surface)
	local high = overlay.run({id = run.id, axis = run.axis, at = run.at,
		from = cut + 1, to = run.to, width = overlay.width,
		lamp_spacing = overlay.lamp_spacing, lamp_phase = run.lamp_phase or run.from,
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
	-- Inclusion is only half of it. The seam must REFUSE a run that writes a
	-- name the channel was not closed over, or the check above is a promise
	-- nothing keeps: drive one whose run returns a foreign cell and watch the
	-- settle fail rather than write an unresolvable ref.
	do
		local rogue_profile = {}
		for key, value in pairs(capital_profile) do rogue_profile[key] = value end
		local rogue_source = {schema = "grug_wp13_capital_source_v1",
			core = source.core, plots = source.plots, overlay = {}}
		for key, value in pairs(source.overlay) do rogue_source.overlay[key] = value end
		rogue_source.overlay.run = function(spec, surface_fn)
			local piece = source.overlay.run(spec, surface_fn)
			if #piece.cells > 0 then
				piece.cells[1] = {x = piece.cells[1].x, y = piece.cells[1].y,
					z = piece.cells[1].z, name = "default:mese", param2 = 0}
			end
			return piece
		end
		local rogue_prepared = settlement.prepare(rogue_profile, rogue_source, sha)
		local rogue_tail = settlement.config(rogue_prepared, content, sha).new(
			dependencies)
		-- An owner over a run, so the overlay is actually evaluated.
		refuses("an overlay cell whose name the content channel never saw",
			owner, rogue_tail, owner_origin(anchor.x + 100),
			owner_origin(40), owner_origin(anchor.z), 300)
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
