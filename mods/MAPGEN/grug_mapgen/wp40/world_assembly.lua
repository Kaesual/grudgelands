-- The world's layout assembly, shared by the runtime and every portable tool
-- (Round 37, audit MGT-07/MGS-10): the pure part of `r7_runtime.lua` before
-- the zones session. It wires the inland water, the roads, the start towns'
-- ground (plan D78) and the capitals (planned as main plans them on a
-- world's first start, or parsed from the layout texts main handed over),
-- joins the capitals' protected cities, canals and squares the way every
-- session must see them, and hands out the horizontal and height factories
-- the zones session (`zones.lua`, through `r5.lua` in the runtime) is built
-- with. No engine global is read: `raw_sha256` is the only seam.
--
--   local A = dofile(wp40 .. "/world_assembly.lua")(wp40, raw_sha256)
--   local W = A.world(seed, texts)   -- texts {water, road, capital} or nil
--   W.capitals()                     -- plan (no capital text) and join
--
-- `A.world` builds no layout itself: the water and the roads are routed by
-- the first height session that asks (`height.lua`), the capitals by
-- `W.plan_capitals` (`W.capitals` = plan, then `W.join_capitals`). A tool
-- that needs only the planning phase calls `W.plan_capitals` alone.
--
-- `variant` (tools only; the runtime passes none) leaves parts out:
--   roads = false    no road layout (terrain and biomes only);
--   protection = shapes   the protected cities stood in by these shapes
--                    ({anchor id -> {member = function(x, z)}}) instead of
--                    the capitals' own, for a world without capital planning.
return function(wp40_directory, raw_sha256)
	local function fail(message)
		error("WP40 world assembly: " .. message, 0)
	end
	if type(wp40_directory) ~= "string" or wp40_directory == "" or
			type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end

	local A = {}
	A.source = dofile(wp40_directory .. "/source/simple_map.lua")
	A.schemas = dofile(wp40_directory .. "/schemas.lua")
	A.canonical = dofile(wp40_directory .. "/canonical.lua")
	A.deterministic = dofile(wp40_directory .. "/deterministic.lua")
	A.index128 = dofile(wp40_directory .. "/index128.lua")
	A.terrain_data = dofile(wp40_directory .. "/terrain_data.lua")
	A.terrain_field = dofile(wp40_directory .. "/terrain_field.lua")(A.terrain_data)
	A.settlement = dofile(wp40_directory .. "/r7_settlement.lua")
	A.capitals = dofile(wp40_directory .. "/r7_capitals.lua")(wp40_directory)
	-- The capitals' protected cities (plan D76) are a function of the capital
	-- layouts, which main plans after the first horizontal session exists;
	-- every horizontal session of a world shares that world's holder, filled
	-- once the layouts are parsed (before any claim or protection query).
	local capital_protection = dofile(wp40_directory .. "/capital_protection.lua")
	local simple_map_factory = dofile(wp40_directory .. "/simple_map.lua")(
		dofile(wp40_directory .. "/zone_field.lua"))
	local height_module_factory = dofile(wp40_directory .. "/height.lua")
	local water_layout_factory = dofile(wp40_directory .. "/water_layout.lua")
	local water_authored_factory = dofile(wp40_directory .. "/water_authored.lua")
	local road_module = dofile(wp40_directory .. "/road_layout.lua")
	A.zones_factory = dofile(wp40_directory .. "/zones.lua")

	-- The ground node each start's blueprint lays on its pad (its race's WP13
	-- palette), which the band round the pad carries out into the natural
	-- surface (plan D78). Both environments read the same files, so they agree.
	-- The band's top is a mapgen surface node of the R6 content contract.
	-- Sunscar's `default:dirt_with_dry_grass` is not one; its mapgen twin shows
	-- the same top texture (default_dry_grass.png).
	local SURFACE_TWIN = {
		["default:dirt_with_dry_grass"] = "default:dry_dirt_with_dry_grass",
	}
	local wp13_palette = dofile(wp40_directory .. "/../wp13/palette.lua")
	A.start_grounds = {}
	A.capital_profiles, A.capital_kits = {}, {}
	for index = 1, #A.settlement.roster do
		local profile = A.settlement.roster[index]
		if profile.slot == "start" then
			local race = wp13_palette.races[profile.race]
			if type(race) ~= "table" or type(race.ground) ~= "string" then
				fail("start town ground missing: " .. profile.key)
			end
			A.start_grounds[profile.anchor_id] = {
				ground = SURFACE_TWIN[race.ground] or race.ground}
		elseif profile.slot == "capital" then
			A.capital_profiles[#A.capital_profiles + 1] = profile
			A.capital_kits[profile.key] = A.capitals.source.kit(profile.key)
		end
	end

	-- Every capital plot prepared once (identity and bounds do not depend on
	-- the seed or on where a plot stands), keyed `<capital key>_<plot id>`.
	local capital_plots
	function A.capital_plots()
		if not capital_plots then
			capital_plots = {}
			for _, profile in ipairs(A.capital_profiles) do
				for _, plot in ipairs(A.capital_kits[profile.key].plots) do
					capital_plots[profile.key .. "_" .. plot.id] =
						A.settlement.prepare_plot(profile, plot, raw_sha256)
				end
			end
		end
		return capital_plots
	end

	-- Protected-city stand-ins for a world without capital planning: a square
	-- of half side `half` round each capital anchor.
	function A.square_cities(half)
		local shapes = {}
		for index = 1, #A.source.anchors do
			local anchor = A.source.anchors[index]
			if anchor.slot_id == "capital" then
				local ax, az = anchor.position.x, anchor.position.z
				shapes[anchor.id] = {member = function(x, z)
					return math.abs(x - ax) <= half and math.abs(z - az) <= half
				end}
			end
		end
		return shapes
	end

	function A.world(seed, texts, variant)
		seed = tostring(seed)
		texts = texts or {}
		variant = variant or {}
		if (texts.road == nil) ~= (texts.capital == nil) or
				(variant.protection ~= nil and texts.capital ~= nil) then
			fail("layout texts differ")
		end
		local W = {seed = seed}
		W.protection_holder = variant.protection and {shapes = variant.protection} or {}
		-- Inland water: one layout per world, shared by every height session
		-- (main builds it once, emerge deserializes main's). The planned canals
		-- are appended to `authored` before any world session.
		W.water = {module = water_layout_factory(A.terrain_data.water), text = texts.water,
			authored = water_authored_factory(A.terrain_data.water)}
		-- Roads (Round 22 Phase 4): routed once in main after the water,
		-- deserialized in emerge. The capital planner's streets and connectors
		-- join this layout (main: `height.lua` add_roads; emerge: already in the
		-- text); its squares are set below from the capital layouts.
		if variant.roads ~= false then
			W.roads = {module = road_module, text = texts.road}
		end
		-- Main plans the capitals on a height session of its own before the
		-- world is built; that session (streets and canals added, memos
		-- flushed) is handed to the world build's first height session request
		-- instead of building a second one (`height.lua` new_runtime).
		W.reuse = {}
		function W.horizontal_factory(dependencies)
			local bound = {}
			for key, value in pairs(dependencies) do bound[key] = value end
			bound.capital_protection = W.protection_holder
			return simple_map_factory(bound)
		end
		function W.height_factory(dependencies)
			local bound = {}
			for key, value in pairs(dependencies) do bound[key] = value end
			bound.water = W.water
			bound.roads = W.roads
			bound.reuse = W.reuse
			bound.start_grounds = A.start_grounds
			return height_module_factory(bound)
		end
		-- The capital plots `r7_settlement.prepare` takes in main (none when the
		-- capital text came in: emerge, or main on a layout-cache hit).
		W.capital_plots = texts.capital == nil and variant.protection == nil and
			A.capital_plots() or {}
		W.capital_layout_text = texts.capital

		-- THE CAPITAL LAYOUTS (Round 22 capital planner, plan D60, D69-D73),
		-- planned after height, water and roads on main's own height session.
		function W.plan_capitals()
			if W.capital_layout_text ~= nil then return end
			if variant.protection ~= nil or not W.roads then
				fail("a world without capitals plans none")
			end
			W.planning_horizontal = W.horizontal_factory({source = A.source,
				schemas = A.schemas, canonical = A.canonical,
				deterministic = A.deterministic, raw_sha256 = raw_sha256}).new(seed)
			W.planning_session = W.height_factory({source = A.source,
				canonical = A.canonical, deterministic = A.deterministic,
				raw_sha256 = raw_sha256, horizontal_session = W.planning_horizontal,
				terrain_field = A.terrain_field}).new_runtime(seed)
			-- plan_all already hands its canal rows to the planning session; the
			-- rows `join_capitals` adds are re-derived from the layout text, as
			-- in emerge.
			W.capital_layout_text, W.capital_rows, W.capital_stats = A.capitals.plan_all({
				seed = seed, session = W.planning_session,
				roads = W.roads.module, anchors = A.source.anchors,
				profiles = A.capital_profiles, kits = A.capital_kits,
				prepared = W.capital_plots, authored = W.water.authored,
				simplex = A.terrain_field.simplex, proxy = A.terrain_data.water.LAKE_PROXY})
			W.reuse.session, W.reuse.seed = W.planning_session, seed
		end

		-- The parsed layouts, the protected cities (each with its civic lake),
		-- the canals and the squares.
		function W.join_capitals()
			if W.capital_layout_text == nil then fail("capital layouts were never planned") end
			W.capital_layouts = A.capitals.parse(W.capital_layout_text)
			W.civic_lakes = {}
			for _, profile in ipairs(A.capital_profiles) do
				local lake_id = A.capital_kits[profile.key].cfg.lake
				if lake_id then
					for _, row in ipairs(W.water.authored) do
						if row.id == lake_id then W.civic_lakes[profile.anchor_id] = row end
					end
					if not W.civic_lakes[profile.anchor_id] then
						fail("civic lake missing: " .. lake_id)
					end
				end
			end
			capital_protection.install(W.protection_holder, W.capital_layouts, W.civic_lakes)
			local all_squares = {}
			for _, profile in ipairs(A.capital_profiles) do
				local entry = W.capital_layouts[profile.anchor_id]
				if not entry then fail("capital layout missing: " .. profile.key) end
				if entry.layout.anchor.x ~= profile.x or entry.layout.anchor.z ~= profile.z then
					fail("capital layout anchor differs: " .. profile.key)
				end
				if entry.layout.canal then
					W.water.authored[#W.water.authored + 1] = A.capitals.canal_row(
						"canal_" .. profile.key, entry.layout.anchor, entry.layout.canal,
						A.terrain_data.water.LAKE_PROXY)
				end
				for _, q in ipairs(A.capitals.squares(entry.layout)) do
					all_squares[#all_squares + 1] = q
				end
			end
			if texts.road ~= nil then W.roads.squares = all_squares end
		end

		function W.capitals()
			W.plan_capitals()
			W.join_capitals()
		end

		-- The zones module over this world's factories (`zones.lua`; the
		-- runtime builds its own through `r5.lua` with the same dependencies).
		function W.zones()
			return A.zones_factory({source = A.source, schemas = A.schemas,
				canonical = A.canonical, deterministic = A.deterministic,
				index128 = A.index128, horizontal_factory = W.horizontal_factory,
				height_factory = W.height_factory, terrain_field = A.terrain_field,
				raw_sha256 = raw_sha256})
		end
		return W
	end

	return A
end
