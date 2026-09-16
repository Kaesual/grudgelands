-- Acceptance for Kezamba, the troll capital: the core, the 52 district plots,
-- the avenues, the four gate thresholds and the two masks the whole capital is
-- built around.
--
--     luajit -e 'io.write(dofile("tools/wp13/kezamba_kat.lua")("."))'
--     tools/bin/lua51 -e 'io.write(dofile("tools/wp13/kezamba_kat.lua")("."))'
--
-- Engine-free, plain Lua 5.1, deterministic: one canonical report line per
-- section, byte-identical under both interpreters.
--
-- WHAT THIS FILE IS FOR THAT THE OTHER KATs ARE NOT.
--
-- `dur_brannoc_kat.lua` and `highcourt_kat.lua` measure a capital standing on
-- flat ground it was given. Kezamba's core is NOT flat: WP40's authored
-- `hydro_kezamba_cenote` fills 2 645 of its 9 025 columns with water whose
-- surface stands one node below the fitted civic reference. A second mask, the
-- RAVINE, held the 273 columns one graded route corridor used to cut up to 26
-- nodes into the pad; since WP40's routes stop at the capital gates
-- (`f5583e13`) it is empty, and both the mask and the rules below stay as the
-- guard that fires if it returns. `wp13/kezamba_lagoon.lua` is the committed
-- measurement of both (`tools/wp13/kezamba_water.lua --verify` re-takes it
-- against the planner on nine seeds), and the three rules this KAT exists for
-- are what that mask buys:
--
--   1. THE COMPOSITION WRITES NOTHING INTO A MASKED COLUMN except the
--      boardwalk, its piers, its rail and the moot house that deliberately
--      stands over the water. An AIR cell over the cenote is a hole in the lake
--      -- the settlement writer writes a blueprint's air exactly as it writes
--      its stone -- and a ground cell there fills it.
--   2. EVERY BOARDWALK COLUMN OVER WATER HAS A DECK, so the two avenues that
--      cross the lake are walkable end to end.
--   3. THE THREE ANGLERS FACE THE LAKE. The sockets contract's section 8.1
--      reads a `fish` socket's feature out of BLUEPRINT cells, which at Kezamba
--      is the wrong question: the water is WP40's and not this composition's.
--      The rule is answered against the committed mask instead, which is the
--      same claim about the same columns and is measured on nine seeds.
--
-- Everything else here is the acceptance the two shipped capitals already have,
-- applied to this one: bounds and budget, canonical unique cells, a byte-sorted
-- palette, every socket standing on something with air over it, the role
-- multiset, every patrol loop walked 1..n with no gap, at most one vendor per
-- kind over the whole capital, section 8.1 in full for every workplace, the
-- 80/20 arithmetic of section 8.3, and the overlay cut at every column with the
-- union compared to the whole.

return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local parts = dofile(wp13 .. "/parts.lua")
	local palettes = dofile(wp13 .. "/palette.lua")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local kezamba = dofile(wp13 .. "/kezamba.lua")(wp13)
	local districts = dofile(wp13 .. "/kezamba_districts.lua")(wp13)
	local mask = dofile(wp13 .. "/kezamba_lagoon.lua")()
	-- The capital's palette HANDLES, for the crop roles the base troll palette
	-- does not bind. `kezamba_plot.lua` gives the three crop fields
	-- `handle = "crop"`, so the nodes those fields are made of are not
	-- reachable through `palettes.new("troll")` and the feature sets below
	-- have to name them from the handle itself.
	local handles = dofile(wp13 .. "/troll_palette.lua")()
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha256 = common.new_sha256()
	-- The real node registry, loaded engine-free under a stub `core` exactly
	-- the way `library_kat` and `lethariel_kat` load it. Section 6 needs it:
	-- `library_kat` proves `parts.shaped` equal to the registry only for names
	-- a composition EMITS, and the two basalt corners this lane added to the
	-- SHAPED table are deliberately not emitted, so without a registry here
	-- they would carry no gate at all.
	local registry = dofile(repo .. "/tools/wp13/stub_registry.lua")
	local world = registry.load(repo)

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "/")
	end
	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return string.format("%02x", string.byte(byte))
		end))
	end

	local timber = palettes.new("troll")

	-- The contract's own envelopes.
	local CORE = settlement.BOUNDS.capital_core
	local PLOT = settlement.BOUNDS.capital_plot
	local CORE_BUDGET = 150000
	local PLOT_BUDGET = 12000
	local CAPITAL_BUDGET = 400000

	-- The closed activity vocabulary of the sockets contract's section 8.2,
	-- wave-2 table included. Spelled here rather than read from the registry
	-- because the registry is an engine module and this KAT has no engine; the
	-- two disagreeing is what `settlement_sockets_kat.lua` is for.
	local ACTIVITIES = {smith = true, fish = true, farm = true, chop = true,
		tend = true, pray = true, stall = true, sit = true, sweep = true,
		mine = true, brew = true, carve = true, mourn = true, spar = true,
		forage = true}
	-- Section 8.4: the two `grug_traders` families plus the professions this
	-- capital places.
	local VENDOR_KINDS = {race = true, general = true, fishmonger = true,
		brewer = true, butcher = true, herbalist = true, tailor = true}
	local CORE_VENDOR_KINDS = {race = true, general = true}

	-- Which node names satisfy which activity, built from the PALETTE's own
	-- roles wherever the contract names a palette thing, so a rebinding moves
	-- the rule with it.
	local FEATURE = {}
	local function feature_set(activity, roles, extra)
		local set = {}
		for _, role in ipairs(roles) do
			local name = timber.maybe(role)
			if name then set[name] = true end
		end
		for _, name in ipairs(extra or {}) do set[name] = true end
		FEATURE[activity] = set
	end
	-- `smith` IS AN ANVIL OR A FURNACE (§8.1), and neither is a palette role
	-- this game binds everywhere. The first version of this set read the
	-- palette's `workbench` and `hearth`, which for the troll palette are
	-- `grug_decor:cottages_tub` and `grug_decor:xdecor_cauldron` -- a washtub
	-- and a cooking pot -- so the one smith of this capital passed its own rule
	-- facing a tub. That is the same defect as `tend` accepting soil, caught by
	-- the independent review of 2026-09-16 instead of by this lane, and the
	-- answer is the same: name what the contract names, and put one in front of
	-- the socket. `cottages_anvil` is here because it is what the human palette
	-- binds `workbench` to and the rule should travel.
	feature_set("smith", {},
		{"default:furnace", "default:furnace_active",
			"grug_decor:cottages_anvil"})
	-- `farm` IS "A FARMLAND OR CROP NODE" (section 8.1), and until playtest 5
	-- the answer at Kezamba was neither. The troll race table binds no `crop`
	-- and no `crop_soil`, so `dressing.crop_rows` fell back to `ground_patch`
	-- and `planter_soil` -- both `grug_nodes:mud` for this race -- and the
	-- three fields were a rectangle of bare mud that grew nothing, which the
	-- first version of this note argued was "what a field in a flooded basin
	-- is". The user disagreed ("Fields in Kezamba grow 'Mossy Stone'? That
	-- cannot be right.") and was right: a field has to read as a field.
	-- `wp13/troll_palette.lua`'s `M.CROP` now binds tilled soil and papyrus,
	-- and the two names come out of THAT handle, because the fields are the
	-- only plots that carry it. The mud pair stays in the set: nothing in the
	-- capital relies on it any more, and leaving it would hide a field that
	-- lost its handle -- so it does not stay, and section 6c is the count that
	-- makes sure the reeds are really there.
	feature_set("farm", {"crop_soil", "crop", "ground_straw"},
		{handles.CROP.crop_soil, handles.CROP.crop, "farming:soil_wet"})
	-- `chop` IS A LOG OR A TREE (§8.1). `post` and `beam` came out of the set
	-- after the independent review of 2026-09-16 pointed out that this lane had
	-- already argued, in §5, why a drying rack's posts are not something to
	-- chop -- and then left them in. Every `chop` socket of this capital faces a
	-- `dressing.wood_pile`, which is `tree_log`.
	feature_set("chop", {"tree_log"}, {})
	-- `tend` IS A PLANT OR A FLOWER AND NOTHING ELSE (§8.1). The first version
	-- of this set also accepted `planter` and `planter_soil` -- the masonry kerb
	-- and the soil of a raised bed -- which is how a gardener came to face a
	-- brick and pass. Soil is not a plant; the composition grows something in
	-- the cell the socket looks at instead (`dressing.plant`, which breaks the
	-- kerb at one cell for exactly this reason).
	feature_set("tend", {"flower", "flower_alt", "hedge", "hedge_stem",
		"undergrowth", "grass_tuft", "fern", "crop", "tree_leaves"},
		{handles.CROP.crop})
	feature_set("pray", {"light_post", "light_wall", "light_indoor",
		"low_wall", "signature", "hearth"}, {})
	-- The six wave-2 activities of section 8.2. Each set is the contract's own
	-- wording turned into the palette's roles:
	--   brew   "a cauldron, barrel or a cooking pot node"
	--   carve  "a log, a totem/statue part or a stone block"
	--   mourn  "a grave marker, a coffin or a candle"
	--   spar   "another `spar` socket or a training dummy (a fence post or a
	--          wool node)"
	--   forage "a mushroom, a bush, a plant, a vine or leaves"
	--   mine   "a stone, ore or cobble node at head or chest height"
	feature_set("brew", {"hearth", "storage", "workbench"}, {})
	-- `carve` is "a log, a totem/statue part or a stone block". `plaza_edge` is
	-- a road kerb and is out; `post` and `signature` stay, because
	-- `dressing.totem` builds its posts out of exactly those two.
	feature_set("carve", {"tree_log", "post", "signature"}, {})
	-- `mourn` is "a grave marker, a coffin or a candle". `signature` is a plain
	-- basalt block and is out; `dressing.grave` sets its marker on a flagstone
	-- out of `low_wall` and `stepping`, and a candle is the palette's light.
	feature_set("mourn", {"low_wall", "light_post", "stepping"}, {})
	feature_set("spar", {"fence", "fence_rail", "post"},
		{"wool:white", "wool:grey"})
	-- `forage` is "a mushroom, a bush, a plant, a vine or leaves". `planter_soil`
	-- is soil, which is the very thing this lane removed from `tend` and then
	-- left here; the review found it.
	feature_set("forage", {"undergrowth", "fern", "grass_tuft", "flower",
		"flower_alt", "tree_leaves", "hedge"}, {})
	feature_set("mine", {"wall_accent", "foundation", "rubble", "signature"},
		{})

	-- ------------------------------------------------------------------
	-- 0. the masks themselves
	-- ------------------------------------------------------------------
	--
	-- The committed module is data, and the first thing to hold it to is its own
	-- shape: the two masks are disjoint, the lake is where the composition
	-- believes it is, and the three published counts are the counts.
	do
		local lagoon, ravine, both, shore = 0, 0, 0, 0
		for z = -mask.ENVELOPE, mask.ENVELOPE do
			for x = -mask.ENVELOPE, mask.ENVELOPE do
				local wet = mask.lagoon(x, z)
				if wet then lagoon = lagoon + 1 end
				if x >= -mask.REACH and x <= mask.REACH and
						z >= -mask.REACH and z <= mask.REACH then
					if mask.ravine(x, z) then
						ravine = ravine + 1
						if wet then both = both + 1 end
					end
					if mask.shore(x, z) then shore = shore + 1 end
				end
			end
		end
		assert(lagoon == mask.LAGOON_COLUMNS, "mask: the lagoon is " ..
			lagoon .. " columns and the module says " .. mask.LAGOON_COLUMNS)
		assert(ravine == mask.RAVINE_COLUMNS, "mask: the ravine is " ..
			ravine .. " columns and the module says " .. mask.RAVINE_COLUMNS)
		assert(both == 0, "mask: " .. both ..
			" columns are both lake and gorge, which is not a thing")
		assert(mask.WATER_SURFACE_Y == mask.REFERENCE_Y - 1,
			"mask: the lake stands at " .. mask.WATER_SURFACE_Y ..
			" and the pad at " .. mask.REFERENCE_Y ..
			", which is not the one node this composition is built on")
		assert(shore > 100, "mask: only " .. shore ..
			" shore columns in the core, which is not a lake city")
		-- The pad is the complement inside the core, and the numbers the core
		-- composition publishes have to be exactly that.
		say("mask", lagoon, ravine, shore, mask.REFERENCE_Y,
			mask.WATER_SURFACE_Y)
	end

	-- ------------------------------------------------------------------
	-- shared helpers
	-- ------------------------------------------------------------------

	local function index_cells(cells)
		local at = {}
		for index = 1, #cells do
			local cell = cells[index]
			at[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
		end
		return at
	end

	-- WHAT BLOCKS A LOOK. `highcourt_kat.lua`'s own answer, and for its reason:
	-- everything that is not on a short PASSABLE list counts as solid, which
	-- keeps the feature search conservative. `parts.full_solid` is the wrong
	-- instrument here -- a trestle counter is a fence leg under a slab top and
	-- neither is a full cube, yet a counter is exactly what the contract's
	-- `stall` rule means by "a solid node at waist height".
	local PASSABLE = {[parts.AIR] = true}
	for _, role in ipairs({"light_post", "light_wall", "light_indoor",
			"lantern", "rope", "undergrowth", "fern", "grass_tuft", "flower",
			"flower_alt", "mat", "door_hidden", "tree_leaves"}) do
		local name = timber.maybe(role)
		if name then PASSABLE[name] = true end
	end
	for _, name in ipairs({"default:torch", "default:torch_wall",
			"default:grass_1", "default:grass_3", "default:grass_4",
			"default:fern_1", "default:junglegrass", "doors:hidden",
			"default:jungleleaves", "default:papyrus"}) do
		PASSABLE[name] = true
	end
	local function solid_name(name)
		return name ~= nil and not PASSABLE[name]
	end

	-- The whole socket contract for one composition's socket list, against that
	-- composition's own cells.
	local counts = {}
	local vendor_kinds = {}
	local loops = {}
	local work_features = 0
	local function check_sockets(label, cells, sockets, core_composition)
		local at = index_cells(cells)
		local function cell_at(x, y, z) return at[x .. ":" .. y .. ":" .. z] end
		local function occupied(x, y, z)
			local cell = cell_at(x, y, z)
			return cell ~= nil and cell.name ~= parts.AIR
		end
		local seen = {}
		for _, entry in ipairs(sockets) do
			assert(type(entry.id) == "string" and entry.id ~= "",
				label .. ": a socket has no id")
			assert(not seen[entry.id],
				label .. ": duplicate socket id " .. entry.id)
			seen[entry.id] = true
			assert(type(entry.dir) == "table" and
				math.abs(entry.dir.x) + math.abs(entry.dir.z) == 1,
				label .. ": the socket " .. entry.id ..
				" carries no axis direction")
			local dx, dz = parts.facedir_step(entry.face)
			assert(dx == entry.dir.x and dz == entry.dir.z, label ..
				": the socket " .. entry.id ..
				" publishes a direction its facedir does not")
			-- Feet and head free, floor not air. A socket over the LAKE is the
			-- one exception a lake city has to allow for, and it is not used:
			-- every socket of this capital stands on a cell of its own
			-- composition, which is what makes this test meaningful.
			for _, level in ipairs({entry.y, entry.y + 1}) do
				assert(not occupied(entry.x, level, entry.z), label ..
					": the socket " .. entry.id .. " is blocked at y " .. level)
			end
			local below = cell_at(entry.x, entry.y - 1, entry.z)
			assert(below ~= nil and below.name ~= parts.AIR, label ..
				": the socket " .. entry.id .. " at " .. entry.x .. "," ..
				entry.y .. "," .. entry.z .. " stands on air")
			counts[entry.role] = (counts[entry.role] or 0) + 1
			if entry.role == "idle" and entry.spawn == false then
				counts.spare = (counts.spare or 0) + 1
			end
			assert(entry.spawn == nil or (entry.spawn == false and
					entry.role == "idle"), label .. ": the socket " ..
				entry.id .. " is spare and is not an idle spot")
			if entry.role == "vendor" then
				assert(VENDOR_KINDS[entry.kind], label .. ": the vendor " ..
					entry.id .. " is of the kind " .. tostring(entry.kind) ..
					", which the contract does not carry")
				assert(vendor_kinds[entry.kind] == nil, label ..
					": a second vendor of the kind " .. entry.kind ..
					" (" .. entry.id .. " after " ..
					tostring(vendor_kinds[entry.kind]) .. ")")
				vendor_kinds[entry.kind] = entry.id
				if CORE_VENDOR_KINDS[entry.kind] then
					assert(core_composition, label .. ": the vendor kind " ..
						entry.kind .. " belongs to the core alone")
				end
			end
			if entry.role == "guard_patrol" then
				assert(type(entry.group) == "string" and
					type(entry.order) == "number", label ..
					": the patrol waypoint " .. entry.id ..
					" carries no loop and order")
				local loop = loops[entry.group] or {}
				assert(loop[entry.order] == nil, label .. ": the loop " ..
					entry.group .. " has two waypoints at order " ..
					entry.order)
				loop[entry.order] = entry.id
				loops[entry.group] = loop
			end
			if entry.role == "work" then
				assert(ACTIVITIES[entry.activity], label ..
					": the work socket " .. entry.id .. " names the activity " ..
					tostring(entry.activity) .. ", which is not the " ..
					"contract's")
				assert(entry.spawn == nil, label .. ": the work socket " ..
					entry.id .. " is spare, and only an idle socket may be")
				local wanted = FEATURE[entry.activity]
				if entry.activity == "fish" then
					-- SECTION 8.1's `fish` RULE, ANSWERED AGAINST THE MAP --
					-- AND WITH ITS OCCLUSION HALF KEPT.
					--
					-- The contract wants "a water node" under `dir` within
					-- three nodes and reads blueprint cells for it. Kezamba's
					-- water is WP40's authored cenote, which no blueprint cell
					-- can be, so the WATER half of the claim is made against
					-- the committed mask -- a stronger instrument, measured on
					-- nine seeds where a blueprint cell is measured on none.
					--
					-- The first version of this branch stopped there, and the
					-- independent review of 2026-09-16 found the cost: one of
					-- the three anglers faced the stilt hall's own leg at reach
					-- one and the lake at reach two, and passed. §8.1's other
					-- half -- "the feature search stops at the first solid node
					-- on the socket's own course" -- is not the mask's to
					-- weaken, so it is asked here of the composition's cells
					-- exactly as it is for every other activity.
					local found, blocked = false, false
					for reach = 1, 3 do
						if not blocked and not found then
							if mask.lagoon(entry.x + dx * reach,
									entry.z + dz * reach) then
								found = true
							elseif solid_name((cell_at(entry.x + dx * reach,
									entry.y, entry.z + dz * reach) or {}).name)
									then
								blocked = true
							end
						end
					end
					assert(found, label .. ": the angler " .. entry.id ..
						" faces no open cenote within three unobstructed " ..
						"nodes of " .. entry.x .. "," .. entry.z)
					work_features = work_features + 1
				elseif wanted then
					-- THE SEARCH STOPS AT THE FIRST SOLID NODE ON THE SOCKET'S
					-- OWN COURSE: a feature behind a wall does not count. The
					-- cell that stops the search is examined first, so a
					-- counter or a cauldron -- itself solid -- still counts.
					local found, blocked = nil, false
					for reach = 1, 3 do
						local fx = entry.x + dx * reach
						local fz = entry.z + dz * reach
						if not blocked then
							for dy = -1, 1 do
								local cell = cell_at(fx, entry.y + dy, fz)
								if found == nil and cell and
										wanted[cell.name] then
									found = cell.name
								end
							end
							if found == nil and
									solid_name((cell_at(fx, entry.y, fz) or {}).name) then
								blocked = true
							end
						end
					end
					assert(found, label .. ": the work socket " .. entry.id ..
						" does " .. entry.activity .. " but faces no " ..
						entry.activity .. " feature within three nodes of " ..
						entry.x .. "," .. entry.y .. "," .. entry.z)
					work_features = work_features + 1
				elseif entry.activity == "stall" then
					local found = false
					for reach = 1, 3 do
						local cell = cell_at(entry.x + dx * reach, entry.y,
							entry.z + dz * reach)
						if not found and cell and solid_name(cell.name) then
							found = true
						end
					end
					assert(found, label .. ": the work socket " .. entry.id ..
						" keeps a stall but faces no counter within three nodes")
					work_features = work_features + 1
				end
			else
				assert(entry.activity == nil, label .. ": the socket " ..
					entry.id .. " carries an activity but is no workplace")
			end
		end
	end

	-- The canonical checks every composition of this capital is held to.
	local function check_composition(label, composition, bounds, budget)
		local cells = composition.cells
		assert(#cells > 0, label .. ": no cells")
		assert(#cells <= budget, label .. ": " .. #cells ..
			" cells against a budget of " .. budget)
		local seen, names = {}, {}
		local previous
		for index = 1, #cells do
			local cell = cells[index]
			local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
			assert(seen[key] == nil, label .. ": two cells at " .. key)
			seen[key] = true
			assert(cell.x >= bounds.min.x and cell.x <= bounds.max.x and
				cell.y >= bounds.min.y and cell.y <= bounds.max.y and
				cell.z >= bounds.min.z and cell.z <= bounds.max.z, label ..
				": the cell at " .. key .. " leaves the contract's envelope")
			if previous then
				local before = (cell.z > previous.z) or
					(cell.z == previous.z and cell.y > previous.y) or
					(cell.z == previous.z and cell.y == previous.y and
						cell.x > previous.x)
				assert(before, label .. ": the cell list is not canonical at " ..
					key)
			end
			previous = cell
			names[cell.name] = true
		end
		local listed = {}
		for index = 1, #composition.palette do
			local name = composition.palette[index]
			assert(listed[name] == nil, label .. ": the palette repeats " ..
				name)
			listed[name] = true
			assert(names[name], label .. ": the palette carries " .. name ..
				", which no cell emits")
			if index > 1 then
				assert(parts.less_bytes(composition.palette[index - 1], name),
					label .. ": the palette is not byte-sorted at " .. name)
			end
		end
		for name in pairs(names) do
			assert(listed[name], label .. ": the cell name " .. name ..
				" is not in the palette")
		end
		return #cells
	end

	-- ------------------------------------------------------------------
	-- 1. the core
	-- ------------------------------------------------------------------

	local core = kezamba.core()
	local core_cells = check_composition("kezamba core", core, CORE,
		CORE_BUDGET)
	do
		local L = core.landmarks
		local at = index_cells(core.cells)
		local function cell_at(x, y, z) return at[x .. ":" .. y .. ":" .. z] end

		-- RULE 1: NOTHING IN A MASKED COLUMN BUT THE BOARDWALK AND THE MOOT
		-- HOUSE. This is the rule the whole composition turns on: an air cell
		-- over the cenote is a hole in the lake, because the settlement writer
		-- writes a blueprint's air exactly as it writes its stone.
		local DECK = timber.node("path")
		local PIER = timber.maybe("signature") or timber.node("foundation")
		local RAIL = timber.node("railing")
		local moot = L.moot_house
		local over_water, deck_columns = 0, {}
		for index = 1, #core.cells do
			local cell = core.cells[index]
			if mask.lagoon(cell.x, cell.z) or mask.ravine(cell.x, cell.z) then
				over_water = over_water + 1
				local inside_moot = moot ~= nil and
					cell.x >= moot.min.x and cell.x <= moot.max.x and
					cell.z >= moot.min.z and cell.z <= moot.max.z
				assert(cell.name ~= parts.AIR or inside_moot,
					"kezamba core: an AIR cell at " .. cell.x .. "," ..
					cell.y .. "," .. cell.z ..
					" would drain the cenote or the gorge")
				assert(inside_moot or cell.name == DECK or cell.name == PIER or
					cell.name == RAIL, "kezamba core: the cell " .. cell.name ..
					" at " .. cell.x .. "," .. cell.y .. "," .. cell.z ..
					" stands in the lake and is neither deck, pier nor rail")
				if cell.name == DECK and cell.y == 0 then
					deck_columns[cell.x .. ":" .. cell.z] = true
				end
			end
		end

		-- RULE 2a: NOTHING OF THE COMPOSITION OBSTRUCTS AN AVENUE.
		--
		-- The first version of this KAT checked that every carriageway column
		-- over water carries a DECK and stopped there, and the independent
		-- review of 2026-09-16 found what that misses: the street routine
		-- railed the run's whole bounding box, so a junglewood fence was laid
		-- straight across the east and north avenues at their far ends, where
		-- both stand over open cenote and a walker cannot go round.
		-- `default:fence_*` is walkable with a raised collision box precisely so
		-- it cannot be jumped, so the road was closed at exactly the point the
		-- research note sends the player. A deck is not enough: the two courses
		-- a walker occupies have to be free as well.
		local CORE_REACH = mask.REACH
		local AVENUE_RUNS = {
			{axis = "x", at = 0, from = -CORE_REACH, to = CORE_REACH},
			{axis = "z", at = 0, from = -CORE_REACH, to = CORE_REACH},
		}
		local obstruction = 0
		for _, run in ipairs(AVENUE_RUNS) do
			-- THE CENTRE THREE LANES, and not all five. The two kerb lanes of
			-- an avenue carry its rail where it crosses the cenote, which is
			-- what a boardwalk five nodes over a lake needs and what
			-- `dressing.walkway` does with its own three-wide deck. What may
			-- never be railed is the walk itself.
			for p = run.from, run.to do
				for lane = -1, 1 do
					local x, z
					if run.axis == "x" then x, z = p, run.at + lane
					else x, z = run.at + lane, p end
					for level = 1, 2 do
						local cell = cell_at(x, level, z)
						if cell ~= nil and cell.name ~= parts.AIR then
							error("kezamba core: the avenue carriageway at " ..
								x .. "," .. level .. "," .. z ..
								" is obstructed by " .. cell.name, 0)
						end
						obstruction = obstruction + 1
					end
				end
			end
		end

		-- RULE 2: the two avenues that cross the lake are walkable end to end.
		-- Every column of the east and north carriageways that stands over
		-- water carries a deck at the pad's own level.
		local crossed, decked = 0, 0
		for _, run in ipairs({{axis = "x", from = 3, to = 47},
				{axis = "z", from = 3, to = 47}}) do
			for p = run.from, run.to do
				for lane = -2, 2 do
					local x, z
					if run.axis == "x" then x, z = p, lane
					else x, z = lane, p end
					if mask.lagoon(x, z) then
						crossed = crossed + 1
						local cell = cell_at(x, 0, z)
						assert(cell ~= nil and cell.name == DECK,
							"kezamba core: the avenue column " .. x .. "," ..
							z .. " stands over the cenote with no deck on it")
						decked = decked + 1
					end
				end
			end
		end
		assert(crossed > 100, "kezamba core: only " .. crossed ..
			" carriageway columns cross the lake, which is not a stilt city")

		-- The anchor root is RESERVED: the anchor writer puts the capital's
		-- guard banner at (0, 1, 0) and runs before the settlement writer, so
		-- this composition must have air there and not a cell of its own.
		local root = cell_at(0, 1, 0)
		assert(root == nil or root.name == parts.AIR,
			"kezamba core: the anchor root at (0,1,0) carries " ..
			tostring(root and root.name) .. " and not the guard banner's air")
		assert(cell_at(0, 0, 0) ~= nil, "kezamba core: the crossing has no " ..
			"ground under the anchor")

		-- The four gate mouths stand on the pad and are walkable.
		for _, gate in ipairs({{"gate_south", 0, -47}, {"gate_north", 0, 47},
				{"gate_west", -47, 0}, {"gate_east", 47, 0}}) do
			local landmark = L[gate[1]]
			assert(type(landmark) == "table" and landmark.x == gate[2] and
				landmark.z == gate[3],
				"kezamba core: the landmark " .. gate[1] .. " has moved")
			local under = cell_at(gate[2], 0, gate[3])
			assert(under ~= nil and under.name ~= parts.AIR,
				"kezamba core: the gate " .. gate[1] ..
				" has no ground under it")
		end

		-- Every destination is inside a room of this composition, every door is
		-- published, and the reserved plaza is empty above its paving.
		assert(#L.destinations >= 12, "kezamba core: only " ..
			#L.destinations .. " destinations")
		assert(#L.doors >= 6, "kezamba core: only " .. #L.doors .. " doors")
		local plaza = L.waypoint_plaza
		for z = plaza.min.z, plaza.max.z do
			for x = plaza.min.x, plaza.max.x do
				for y = 1, plaza.max.y do
					local cell = cell_at(x, y, z)
					assert(cell == nil or cell.name == parts.AIR,
						"kezamba core: the reserved travel plaza carries " ..
						cell.name .. " at " .. x .. "," .. y .. "," .. z)
				end
			end
		end

		-- The contract's "emergent trees kept" is a number and not a wish.
		assert(L.emergents >= 4, "kezamba core: " .. L.emergents ..
			" emergent kapoks, and the contract keeps them")

		check_sockets("kezamba core", core.cells, L.sockets, true)
		say("core", core_cells, #core.palette, #L.sockets, L.pad_columns,
			L.lagoon_columns, L.ravine_columns, L.boardwalk, L.piers, L.quay,
			L.bridge, L.emergents, over_water, crossed)
	end

	-- ------------------------------------------------------------------
	-- 2. the fifty-two plots
	-- ------------------------------------------------------------------

	local plot_cells, largest, largest_id = 0, 0, "-"
	local resolved = districts.resolve()
	do
		assert(#resolved == 52, "kezamba districts: " .. #resolved ..
			" plots and not the Highcourt standard's 52")
		local by_district, seen_id = {}, {}
		local occupied = {}
		-- WHAT COUNTS AS GROWN, and what counts as paved. `GROWN` is every
		-- node this capital's plots put in the air over soil, taken from the
		-- palette's own roles plus the crop handle -- naming the nodes by hand
		-- would pass a field that quietly lost its palette. `PAVED` is the
		-- `planter` role, which for the troll palette is
		-- `default:mossycobble`: the kerb of a raised bed, and the whole of
		-- what a bed one row deep is made of.
		local GROWN, PAVED = {}, timber.node("planter")
		for _, role in ipairs({"crop", "undergrowth", "grass_tuft", "fern",
				"flower", "flower_alt", "hedge"}) do
			local name = timber.maybe(role)
			if name then GROWN[name] = true end
		end
		-- The handle has to BIND, and the message has to say so: without this
		-- the mutation that empties `M.CROP` crashes on a nil table index
		-- instead of naming the defect.
		assert(type(handles.CROP.crop) == "string" and
			type(handles.CROP.crop_soil) == "string",
			"kezamba crops: wp13/troll_palette.lua's M.CROP binds no crop " ..
			"and no crop_soil, so dressing.crop_rows falls back to the mud " ..
			"pair and the fields grow nothing")
		GROWN[handles.CROP.crop] = true
		-- The three CROP FIELDS and the floor each has to clear. A field is
		-- `dressing.crop_rows` over the yard behind its forecourt, which plants
		-- every second row; the smallest of the three is `vine_kitchen`, whose
		-- yard is a reach-5 lot. The floors are the measured counts less a
		-- quarter, so a field that loses its crop handle (0) or half its rows
		-- turns this red while an ordinary lot move does not.
		local FIELD = {shore_gardens = 140, vine_common = 140,
			vine_kitchen = 20}
		-- The two RAISED-BED gardens, which are `dressing.planter` and read as
		-- stone the moment a bed is shallower than three rows.
		local GARDEN = {shore_vineyard = true, vine_terraces = true}
		local crop_row = {}
		for index = 1, #resolved do
			local entry = resolved[index]
			assert(not seen_id[entry.id],
				"kezamba districts: duplicate plot id " .. entry.id)
			seen_id[entry.id] = true
			by_district[entry.district] = (by_district[entry.district] or 0) + 1

			-- No lot may stand on water, on the core, on a gate corridor or on
			-- another lot. The lot predicate `tools/wp13/kezamba_lots.lua`
			-- measures the terrain half of that against the planner on nine
			-- seeds; this is the half that needs no terrain at all, and it is
			-- here because a roster edit is what moves a lot.
			local half = entry.reach + 2
			assert(math.abs(entry.x) + half <= 250 and
				math.abs(entry.z) + half <= 250,
				"kezamba districts: the lot " .. entry.id ..
				" leaves the envelope")
			assert(math.abs(entry.x) - half >= 48 or
				math.abs(entry.z) - half >= 48,
				"kezamba districts: the lot " .. entry.id ..
				" overlaps the civic core")
			assert(math.abs(entry.x) - half >= 16 and
				math.abs(entry.z) - half >= 16,
				"kezamba districts: the lot " .. entry.id ..
				" stands in a gate corridor")
			for _, other in ipairs(occupied) do
				local gap_x = math.abs(entry.x - other.x) -
					(half + other.reach + 2)
				local gap_z = math.abs(entry.z - other.z) -
					(half + other.reach + 2)
				assert(gap_x > 0 or gap_z > 0,
					"kezamba districts: the lot " .. entry.id ..
					" overlaps " .. other.id)
			end
			occupied[#occupied + 1] = {id = entry.id, x = entry.x,
				z = entry.z, reach = entry.reach}
			for _, corner in ipairs({{-half, -half}, {half, -half},
					{-half, half}, {half, half}}) do
				assert(not mask.lagoon(entry.x + corner[1],
					entry.z + corner[2]), "kezamba districts: the lot " ..
					entry.id .. " reaches the cenote")
			end

			local composition = entry.build()
			assert(composition.schema ==
				"grug_wp13_kezamba_plot_" .. entry.id .. "_v1",
				"kezamba districts: the plot " .. entry.id ..
				" publishes the schema " .. tostring(composition.schema))
			local count = check_composition("kezamba plot " .. entry.id,
				composition, PLOT, PLOT_BUDGET)
			plot_cells = plot_cells + count
			if count > largest then largest, largest_id = count, entry.id end

			-- A plot's own two halves of the contract's section 2.1: the
			-- reference column at its origin, the foundation skirt carried
			-- down to -6 on the whole perimeter, and the cleared airspace it
			-- publishes as `clear_to`.
			assert(composition.reference.x == 0 and
				composition.reference.z == 0,
				"kezamba districts: the plot " .. entry.id ..
				" references a column that is not its own origin")
			local at = index_cells(composition.cells)
			local box = composition.landmarks.plot
			local skirt = 0
			for z = box.min.z, box.max.z do
				for x = box.min.x, box.max.x do
					if x == box.min.x or x == box.max.x or
							z == box.min.z or z == box.max.z then
						local cell = at[x .. ":" .. PLOT.min.y .. ":" .. z]
						assert(cell ~= nil and cell.name ~= parts.AIR,
							"kezamba districts: the plot " .. entry.id ..
							" has no skirt under " .. x .. "," .. z)
						skirt = skirt + 1
					end
				end
			end
			assert(skirt > 0, "kezamba districts: the plot " .. entry.id ..
				" has no skirt at all")
			assert(type(composition.clear_to) == "number" and
				composition.clear_to >= 8,
				"kezamba districts: the plot " .. entry.id ..
				" clears " .. tostring(composition.clear_to) ..
				", below the lot predicate's own floor of 8")
			-- The plot's ground must not overrun its own lot: the lot
			-- predicate measured the terrain of `reach + 2` and no further.
			assert(box.min.x >= -entry.reach and box.max.x <= entry.reach and
				box.min.z >= -entry.reach and box.max.z <= entry.reach,
				"kezamba districts: the plot " .. entry.id ..
				" is wider than the lot it was measured on")

			check_sockets("kezamba plot " .. entry.id, composition.cells,
				composition.landmarks.sockets, false)

			-- 2c. WHAT A FIELD GROWS (playtest 5, 2026-09-16, user: "Fields in
			-- Kezamba grow 'Mossy Stone'? That cannot be right."). Two
			-- different plots read as stone and each for its own reason, so
			-- each gets its own count here rather than one rule that would
			-- pass on the average of the two.
			local grown, paved = 0, 0
			for cell_index = 1, #composition.cells do
				local name = composition.cells[cell_index].name
				if GROWN[name] then grown = grown + 1
				elseif name == PAVED then paved = paved + 1 end
			end
			crop_row[#crop_row + 1] = entry.id .. "=" .. grown .. "/" .. paved
			if FIELD[entry.id] then
				assert(grown >= FIELD[entry.id],
					"kezamba crops: the field " .. entry.id .. " grows " ..
					grown .. " plants, and a field that grows fewer than " ..
					FIELD[entry.id] .. " is the mud rectangle of playtest 5")
			end
			if GARDEN[entry.id] then
				assert(grown > paved, "kezamba crops: the garden " ..
					entry.id .. " lays " .. paved ..
					" cells of the palette's `planter` (" .. PAVED ..
					") against " .. grown ..
					" planted ones, which is a field of stone")
			end
		end
		local keys = {}
		for key in pairs(by_district) do keys[#keys + 1] = key end
		table.sort(keys)
		local row = {}
		for _, key in ipairs(keys) do
			row[#row + 1] = key .. "=" .. by_district[key]
		end
		say("plots", #resolved, plot_cells, largest, largest_id,
			table.concat(row, ","))
		-- The five plots the playtest finding is about, as grown/paved cells.
		local field_row = {}
		for _, id in ipairs({"shore_gardens", "shore_vineyard", "vine_common",
				"vine_kitchen", "vine_terraces"}) do
			for index = 1, #crop_row do
				if crop_row[index]:sub(1, #id + 1) == id .. "=" then
					field_row[#field_row + 1] = crop_row[index]
				end
			end
		end
		say("crops", handles.CROP.crop, handles.CROP.crop_soil,
			table.concat(field_row, ","))
	end

	-- ------------------------------------------------------------------
	-- 3. the capital's socket arithmetic
	-- ------------------------------------------------------------------

	do
		assert(counts.king == 1, "kezamba sockets: " ..
			tostring(counts.king) .. " thrones")
		assert(counts.quest == 1, "kezamba sockets: " ..
			tostring(counts.quest) .. " quest shells, and a capital has one")
		assert(counts.waypoint == 1, "kezamba sockets: " ..
			tostring(counts.waypoint) .. " travel waypoints")
		assert(vendor_kinds.race and vendor_kinds.general and
			vendor_kinds.fishmonger, "kezamba sockets: the core's three " ..
			"vendors are not all there")

		-- EVERY PATROL LOOP IS WALKED 1..n WITH NO GAP. A loop with a hole in
		-- its order is a guard who walks to a waypoint that does not exist.
		local loop_names = {}
		for name in pairs(loops) do loop_names[#loop_names + 1] = name end
		table.sort(loop_names)
		local loop_row = {}
		for _, name in ipairs(loop_names) do
			local loop = loops[name]
			local size = 0
			for _ in pairs(loop) do size = size + 1 end
			for step = 1, size do
				assert(loop[step] ~= nil, "kezamba sockets: the loop " ..
					name .. " has no waypoint at order " .. step ..
					" of " .. size)
			end
			assert(size >= 2, "kezamba sockets: the loop " .. name ..
				" has " .. size .. " waypoint")
			loop_row[#loop_row + 1] = name .. "=" .. size
		end

		-- SECTION 8.3, the structure lane's half: at least one `idle` SPAWN
		-- socket per `work` socket, so the NPC lane's "every fifth idle spawn
		-- socket walks" lands the walker share inside the 10-30 % band.
		local idle_spawn = (counts.idle or 0) - (counts.spare or 0)
		local work_sockets = counts.work or 0
		assert(idle_spawn >= work_sockets, "kezamba sockets: " .. idle_spawn ..
			" idle spawn sockets against " .. work_sockets ..
			" workplaces, which is the wrong side of section 8.3")
		local residents = idle_spawn + work_sockets
		local walkers = math.ceil(idle_spawn / 5)
		local share = walkers * 100 / residents
		assert(share >= 10 and share <= 30, "kezamba sockets: " .. walkers ..
			" walkers of " .. residents .. " residents is " ..
			string.format("%.1f", share) .. " per cent, outside the band")
		assert((counts.spare or 0) >= 4, "kezamba sockets: " ..
			tostring(counts.spare) .. " spare spots, and an amble needs room")
		-- THE COORDINATOR'''S WAVE-2 BAND (2026-09-15, after the first two
		-- capital reviews): 150 to 170 residents and at most 25 walkers per
		-- capital, against Highcourt'''s 144 / 22 as the reference. It is a
		-- SERVER-LOAD number -- path-finding and animated meshes are the cost --
		-- so it is asserted here rather than counted by eye, and a roster edit
		-- that walks out of it goes red.
		assert(residents >= 150 and residents <= 170, "kezamba sockets: " ..
			residents .. " residents, outside the wave-2 band of 150 to 170")
		assert(walkers <= 25, "kezamba sockets: " .. walkers ..
			" walkers, over the wave-2 ceiling of 25")

		local role_names = {}
		for role in pairs(counts) do role_names[#role_names + 1] = role end
		table.sort(role_names)
		local role_row = {}
		for _, role in ipairs(role_names) do
			role_row[#role_row + 1] = role .. "=" .. counts[role]
		end
		local kind_names = {}
		for kind in pairs(vendor_kinds) do kind_names[#kind_names + 1] = kind end
		table.sort(kind_names)
		say("sockets", table.concat(role_row, ","), residents, walkers,
			string.format("%.1f", share), work_features,
			table.concat(kind_names, ","), table.concat(loop_row, ","))
	end

	-- ------------------------------------------------------------------
	-- 4. the budget
	-- ------------------------------------------------------------------

	do
		local total = core_cells + plot_cells
		assert(total <= CAPITAL_BUDGET, "kezamba: " .. total ..
			" cells against the contract's " .. CAPITAL_BUDGET)
		say("budget", core_cells, plot_cells, total, CAPITAL_BUDGET)
	end

	-- ------------------------------------------------------------------
	-- 5. the overlay: the avenues, the lake rail and the four thresholds
	-- ------------------------------------------------------------------

	do
		local road = palettes.new("troll")
		-- A synthetic terrace, three nodes a step, plus the lake at its own
		-- measured surface: the seam hands an overlay the WALKABLE surface of a
		-- column, which over water is the water. This is that rule as a stub,
		-- so the run is exercised against exactly the input the engine gives
		-- it.
		local function surface(x, z)
			if mask.lagoon(x, z) then return mask.WATER_SURFACE_Y end
			local terrace = math.floor((math.abs(x) + math.abs(z)) / 48)
			return mask.REFERENCE_Y - 3 * terrace
		end

		local runs = kezamba.overlay_runs()
		assert(#runs == 12, "kezamba overlay: " .. #runs ..
			" runs and not the four avenues, four ring sides and four " ..
			"thresholds")
		-- The AVENUES RUN FIRST. The successor's cross-run arbitration is
		-- first-run-wins, and it is what lets the road keep the cells of its own
		-- carriageway where a threshold's lintel crosses it.
		for index = 1, 4 do
			assert(runs[index].id:sub(1, 7) == "avenue_",
				"kezamba overlay: run " .. index .. " is " .. runs[index].id ..
				" and the avenues must come first")
		end

		local names = kezamba.overlay_names(avenue, road)
		local listed = {}
		for index = 1, #names do
			listed[names[index]] = true
			if index > 1 then
				assert(parts.less_bytes(names[index - 1], names[index]),
					"kezamba overlay: the palette is not byte-sorted at " ..
					names[index])
			end
		end

		local HALF = (avenue.WIDTH - 1) / 2 + 1
		local rows = {}
		for _, run in ipairs(runs) do
			local function spec_for(from, to)
				return {id = run.id, axis = run.axis, at = run.at, from = from,
					to = to, width = avenue.WIDTH,
					lamp_spacing = avenue.LAMP_SPACING, lamp_phase = run.from,
					reach = avenue.REACH}
			end
			local whole = kezamba.overlay_run(avenue, road,
				spec_for(run.from, run.to), surface)
			local keys = {}
			for _, cell in ipairs(whole.cells) do
				local across = (run.axis == "x") and (cell.z - run.at) or
					(cell.x - run.at)
				assert(math.abs(across) <= HALF, "kezamba overlay: the run " ..
					run.id .. " writes at " .. cell.x .. "," .. cell.z ..
					", outside the band the seam activates it on")
				assert(listed[cell.name], "kezamba overlay: the run " ..
					run.id .. " writes " .. cell.name ..
					", which its palette does not carry")
				local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
				assert(keys[key] == nil, "kezamba overlay: the run " ..
					run.id .. " writes twice at " .. key)
				keys[key] = cell.name
			end

			-- A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN. Cut
			-- the run at every column and compare the union with the whole,
			-- cell for cell: that is what makes it safe to emerge one mapchunk
			-- at a time, and it is the property the lake rail could break,
			-- because a rail that read anything but its own piece's cells and
			-- the constant mask would not survive the cut.
			local union, union_count = {}, 0
			for p = run.from, run.to do
				local piece = kezamba.overlay_run(avenue, road, spec_for(p, p),
					surface)
				for _, cell in ipairs(piece.cells) do
					local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
					if union[key] == nil then union_count = union_count + 1 end
					union[key] = cell.name
				end
			end
			for key, name in pairs(keys) do
				assert(union[key] == name, "kezamba overlay: the run " ..
					run.id .. " cut at every column loses " .. name ..
					" at " .. key)
			end
			for key, name in pairs(union) do
				assert(keys[key] == name, "kezamba overlay: the run " ..
					run.id .. " cut at every column invents " .. name ..
					" at " .. key)
			end
			assert(union_count == #whole.cells, "kezamba overlay: the run " ..
				run.id .. " has " .. #whole.cells ..
				" cells whole and " .. union_count .. " cut")

			-- THE LAKE RAIL stands on kerb columns of the cenote and nowhere
			-- else, which is the whole of its rule.
			if whole.rail then
				local rail_name = road.node("railing")
				local rail_seen = 0
				-- A RAIL STANDS ON A KERB, AND ONLY WHERE THE ROAD NEEDS
				-- ONE: over the lake, or on a column the road had to fill by
				-- three courses or more, which is the embankment. Both halves
				-- are read back off the piece rather than trusted.
				local across_half = (avenue.WIDTH - 1) / 2
				local span = {}
				for _, cell in ipairs(whole.cells) do
					local across = (run.axis == "x") and (cell.z - run.at) or
						(cell.x - run.at)
					if math.abs(across) == across_half and
							cell.name ~= rail_name then
						local key = cell.x .. ":" .. cell.z
						local box = span[key]
						if box == nil then span[key] = {cell.y, cell.y}
						else
							if cell.y < box[1] then box[1] = cell.y end
							if cell.y > box[2] then box[2] = cell.y end
						end
					end
				end
				for _, cell in ipairs(whole.cells) do
					if cell.name == rail_name then
						local across = (run.axis == "x") and
							(cell.z - run.at) or (cell.x - run.at)
						assert(math.abs(across) == across_half,
							"kezamba overlay: the run " .. run.id ..
							" rails a column that is not a kerb")
						local box = span[cell.x .. ":" .. cell.z]
						assert(mask.lagoon(cell.x, cell.z) or
							(box ~= nil and box[2] - box[1] >= whole.rail_fill),
							"kezamba overlay: the run " .. run.id ..
							" rails the column " .. cell.x .. "," .. cell.z ..
							", which is neither lake nor embankment")
						assert(box ~= nil and cell.y == box[2] + 1,
							"kezamba overlay: the run " .. run.id ..
							" rails " .. cell.x .. "," .. cell.z ..
							" somewhere other than on top of its own kerb")
						rail_seen = rail_seen + 1
					end
				end
				assert(rail_seen == whole.rail, "kezamba overlay: the run " ..
					run.id .. " counts " .. whole.rail .. " rail cells and " ..
					"writes " .. rail_seen)
			end

			-- A THRESHOLD: two posts and a lintel over the road, and the road
			-- still passing under it.
			if whole.posts then
				assert(whole.posts == 2, "kezamba overlay: the threshold " ..
					run.id .. " has " .. whole.posts .. " posts")
				-- The lintel spans the carriageway between the two posts,
				-- which stand on the verges at +-3: five cells for the
				-- contract's five-wide road.
				assert(whole.lintel == avenue.WIDTH,
					"kezamba overlay: the threshold " .. run.id ..
					" spans " .. whole.lintel .. " and not the carriageway")
			end

			rows[#rows + 1] = run.id .. "=" .. #whole.cells
		end

		local digest_source = {}
		for _, run in ipairs(runs) do
			local piece = kezamba.overlay_run(avenue, road,
				{id = run.id, axis = run.axis, at = run.at, from = run.from,
					to = run.to, width = avenue.WIDTH,
					lamp_spacing = avenue.LAMP_SPACING, lamp_phase = run.from,
					reach = avenue.REACH}, surface)
			for _, cell in ipairs(piece.cells) do
				digest_source[#digest_source + 1] = table.concat({run.id,
					cell.x, cell.y, cell.z, cell.name, cell.param2 or 0}, ":")
			end
		end
		-- The overlay's MANIFEST identity is its specification: it has no cells
		-- until a surface arrives, so a change that moved every node of every
		-- avenue would move no blueprint SHA. This digest is what would see it.
		say("overlay", #runs, #names, table.concat(rows, ","),
			hex(sha256(table.concat(digest_source, "\n"))))
	end

	-- ------------------------------------------------------------------
	-- 6. THE ROOF FAMILY, and the library gap that used to decide it
	-- ------------------------------------------------------------------
	--
	-- `roofs.raster` turns a hip with `roof_stair_outer` and a valley with
	-- `roof_stair_inner`, so a roof family that a composition may bind has to
	-- carry all four shapes AND all four have to be nodes `parts.shaped` will
	-- let a part turn -- `Buffer:put` refuses a param2 on any other name with
	-- "has no paramtype2". Until 2026-09-16 `wp13/parts.lua`'s SHAPED table
	-- carried the straight basalt stair and the basalt slab but NOT the two
	-- corners, so the BASALT handle could not have a basalt roof even though
	-- `grug_decor` registers all four shapes. That is a LIBRARY GAP and it is
	-- closed; which family this capital actually roofs with is a separate,
	-- look-and-feel question, and the answer (2026-09-16, lane and independent
	-- review agreeing, and the contract's troll row naming junglewood) is
	-- TIMBER. This section therefore asserts the gap is closed and the bound
	-- family is complete, which holds whichever way that question is answered.
	--
	-- Three things are asserted and they fail for three different regressions.
	do
		local handles = dofile(wp13 .. "/troll_palette.lua")()
		local basalt = palettes.new("troll", handles.BASALT)
		local roof_roles = {"roof_stair", "roof_stair_outer",
			"roof_stair_inner", "roof_slab", "roof_ridge"}

		-- (a) THE LIBRARY GAP IS CLOSED. All four basalt shapes are nodes the
		-- library may give a facedir to, and `parts.shaped` agrees with the
		-- REGISTRY about each of them in both directions. `library_kat` proves
		-- that equality only for names a composition actually emits, and this
		-- capital no longer emits the two corners, so without this the SHAPED
		-- entries would have no gate at all. Dropping either corner from
		-- SHAPED fails here.
		local basalt_family = {"grug_decor:darkage_basalt_stair",
			"grug_decor:darkage_basalt_stair_inner",
			"grug_decor:darkage_basalt_stair_outer",
			"grug_decor:darkage_basalt_slab"}
		for _, name in ipairs(basalt_family) do
			local def = world.nodes[name]
			assert(def, "kezamba roof family: " .. name .. " is not registered")
			assert(def.paramtype2 == "facedir", "kezamba roof family: " ..
				name .. " is " .. tostring(def.paramtype2) .. ", not facedir")
			local groups = (type(def.groups) == "table") and def.groups or {}
			local shaped = (groups.slab or 0) > 0 or (groups.stair or 0) > 0
			assert(shaped, "kezamba roof family: the registry does not call " ..
				name .. " a stair or a slab")
			assert(parts.shaped(name) == shaped, "kezamba roof family: " ..
				"parts.shaped disagrees with the registry for " .. name ..
				"; the basalt roof cannot be bound while it does")
		end

		-- (b) THE BOUND FAMILY IS COMPLETE, whichever it is. Every one of the
		-- five roof roles of this handle resolves, the four shaped ones are
		-- shapes the library may turn, and all five come from ONE family --
		-- half a family bound is the defect this catches, and it is the defect
		-- that a partial basalt binding would be.
		--
		-- The family of a name is the MATERIAL with its shape taken off. The
		-- `stairs` mod puts the shape in front of the material
		-- (`stairs:stair_outer_junglewood`) and `grug_decor.register_shapes`
		-- puts it behind (`grug_decor:darkage_basalt_stair_outer`), and the
		-- full cube of either carries no shape at all
		-- (`default:junglewood`, `grug_decor:darkage_basalt`), so both
		-- spellings and the cube have to reduce to the same word.
		local function roof_family_of(name)
			local modname, rest = name:match("^([a-z_]+):(.*)$")
			assert(rest, "kezamba roof family: " .. name .. " is not a node name")
			if modname == "stairs" then
				rest = rest:gsub("^stair_inner_", ""):gsub("^stair_outer_", "")
				rest = rest:gsub("^stair_", ""):gsub("^slab_", "")
			else
				rest = rest:gsub("_stair_inner$", ""):gsub("_stair_outer$", "")
				rest = rest:gsub("_stair$", ""):gsub("_slab$", "")
			end
			return rest
		end
		local roof_names, family = {}, nil
		for _, role in ipairs(roof_roles) do
			local name = basalt.node(role)
			if role ~= "roof_ridge" then
				assert(parts.shaped(name), "kezamba roof family: " .. role ..
					" is bound to " .. name ..
					", which parts.lua will not let a part turn")
			end
			-- The family is the name with its shape suffix taken off:
			-- `stairs:stair_outer_junglewood` and `stairs:slab_junglewood` are
			-- both `junglewood`; `grug_decor:darkage_basalt_stair_inner` and
			-- `grug_decor:darkage_basalt` are both `grug_decor:darkage_basalt`.
			local here = roof_family_of(name)
			if family == nil then family = here end
			assert(here == family, "kezamba roof family: " .. role ..
				" is bound to " .. name .. ", which is " .. here ..
				" and not " .. family .. "; a roof may not mix two families")
			roof_names[#roof_names + 1] = name
		end

		-- (c) AND THE CORNERS ARE ACTUALLY WRITTEN. Counted out of the finished
		-- core rather than out of a part, because that is what the map gets: a
		-- roof that never rasters a corner is a roof whose corner shapes were
		-- never exercised, and this capital's hipped roofs do raster them. A
		-- binding that dropped `roof_stair_outer` to something the rasteriser
		-- cannot turn fails at construction; a binding that quietly stopped
		-- producing corners fails here.
		local counts = {}
		for _, cell in ipairs(core.cells) do
			counts[cell.name] = (counts[cell.name] or 0) + 1
		end
		local outer = counts[basalt.node("roof_stair_outer")] or 0
		local inner = counts[basalt.node("roof_stair_inner")] or 0
		assert(outer + inner > 0, "kezamba roof family: the core writes no " ..
			"corner piece of the bound roof family, so no hip or valley was " ..
			"rastered")
		say("roof_family", family, outer, inner,
			counts[basalt.node("roof_stair")] or 0,
			counts[basalt.node("roof_slab")] or 0,
			table.concat(roof_names, "+"))
	end

	-- ------------------------------------------------------------------
	-- 7. the roster row
	-- ------------------------------------------------------------------

	-- THE ROW IS AFTER THE CAPITALS IT WAS MERGED AFTER, which is what the
	-- order actually means, and NOT "last".
	--
	-- This used to assert `index == #settlement.roster` with a message naming a
	-- wave-2 order (`lethariel, nhal_veyr, gor_drazhak, kezamba`) that no roster
	-- ever had. "Last" is a property of whoever merged most recently, not of this
	-- capital: Nhal Veyr landed after Kezamba and the coordinator's ruling at
	-- merge was to APPEND it, because appending is what keeps every earlier
	-- capital's numeric id, anchor id and frozen digests where they are. What
	-- this capital can actually claim is that it comes after the two wave-2
	-- capitals that merged before it, and that is what is asserted. (Lane U,
	-- 2026-09-16, reported to Lane T as a change to its file.)
	do
		local profile
		local seen_before = 0
		for index = 1, #settlement.roster do
			local key = settlement.roster[index].key
			if key == "gor_drazhak" or key == "lethariel" then
				seen_before = seen_before + 1
			end
			if key == "kezamba" then
				profile = settlement.roster[index]
				assert(seen_before == 2, "kezamba roster: the row stands " ..
					"before gor_drazhak or lethariel, and it merged after both")
			end
		end
		assert(profile, "kezamba roster: the roster carries no kezamba")
		assert(profile.slot == "capital" and profile.race == "troll" and
			profile.x == 1800 and profile.z == 1500 and
			profile.anchor_id == "anchor_012" and profile.lazy == true and
			profile.reserve_anchor_root == true,
			"kezamba roster: the row differs")
		assert(profile.blueprint_schema == "grug_wp13_kezamba_core_v1" and
			core.schema == profile.blueprint_schema,
			"kezamba roster: the core schema differs")
		say("roster", profile.anchor_id, profile.numeric_id, profile.zone_id,
			profile.bounds, profile.plot_bounds)
	end

	table.sort(report)
	return "wp13_kezamba\t" .. table.concat(report, " ") .. "\n"
end
