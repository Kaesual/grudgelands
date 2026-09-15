-- Nhal Veyr, the bone watch: the martial and garrison district, nine
-- terrain-relative plots and four fill dressings.
--
-- The contract's second district role. What a plot is and how it is built is
-- `nhal_veyr_plot.lua`; where the nine plots stand is
-- `nhal_veyr_quadrants.lua`. This file is the roster and nothing else.
--
-- The garrison is the one district that publishes GUARD POSTS -- the sockets
-- contract's "a guard stands here and returns here after fights" -- and it
-- publishes them where a guard would actually be posted: the barracks door,
-- the drill yard's gate and the watch tower's foot. There are no vendors here:
-- the city holds at most one of each kind and the six it has stand in the
-- market, the vigil and the core.
--
-- The wave-2 activity this district exists to place is `spar`, whose feature
-- is "another `spar` socket or a training dummy (a fence post or a wool
-- node)". Both readings are used: the drill yard's pair face each other across
-- two nodes, and the muster field's three each face a drill post -- which
-- `dressing.drill_post` builds out of the palette's own `fence`.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory)

	local M = {}

	local WATCH = "nhal_veyr_garrison_watch"

	local PLOTS = {
		-- 1. The barracks: the generator publishes its guard post, its muster
		-- idle spot and waypoint 1 of the loop, so this row carries no `order`.
		{id = "watch_barracks", module = "capitals", make = "barracks",
			handle = "crypt", roof = "vault",
			spec = {w = 17, d = 21, wall_h = 6, patrol_group = WATCH,
				order = 1},
			extra_sockets = function(area)
				return {
					plots.guard_post("gate_west", area.x0 + 2, area.z0 + 3, 0),
					plots.guard_post("gate_east", area.x1 - 2, area.z0 + 3, 0),
				}
			end},
		-- 2. The captain's hall, where the watch is read its orders: hip
		-- roofed under the vault so it reads as civic from the lane rather
		-- than as the biggest cottage in the district.
		{id = "watch_captain_hall", module = "buildings", make = "hall",
			handle = "crypt", roof = "vault", order = 2,
			spec = {w = 15, d = 17, wall_h = 5, infill = true}},
		-- 3. The armoury. A workshop, turned, opening in its x- wall for the
		-- reason the market's bonesmith records: the `workshop` kit stands the
		-- forge's cauldrons on the odd cells of the z- gable's inner run, so a
		-- door there would open onto a hearth. The anvil on the apron is the
		-- `smith` feature, named rather than taken from `workbench`, which in
		-- this palette is the bone carver's bench.
		{id = "watch_armoury", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, "grug_decor:cottages_anvil")
			end,
			extra_sockets = function(area)
				return {plots.work("anvil", "smith", area.x0 + 3, area.z0, 0)}
			end},
		-- 4. The dead-cart stables.
		{id = "watch_stables", module = "capitals", make = "stable",
			order = 4, spec = {w = 15, d = 13, wall_h = 5}},
		-- 5. The drill yard. The watchpost is the piece that makes it a yard
		-- and not a field: a guard room with a fighting deck over it, with
		-- five nodes of open ground all round for the posts and the standards.
		--
		-- THE TWO SPARRING GUARDS FACE EACH OTHER, which is the first of the
		-- two readings the contract's `spar` allows ("another `spar` socket or
		-- a training dummy"). They stand two nodes apart on the yard's own
		-- axis, which is inside the three the feature rule allows.
		{id = "watch_drill_yard", module = "buildings", make = "watchpost",
			order = 5, margin = 5, spec = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, spot in ipairs({{area.x0 + 2, area.z1 - 2},
						{area.x0 + 5, area.z1 - 2}, {area.x1 - 5, area.z1 - 2},
						{area.x1 - 2, area.z1 - 2}}) do
					dressing.drill_post(buf, palette, spot[1], spot[2], 3)
				end
				dressing.standard(buf, palette, area.x0 + 2, area.z0 + 4, 5)
				dressing.standard(buf, palette, area.x1 - 2, area.z0 + 4, 5)
				dressing.wood_pile(buf, palette, area.x1 - 4, area.z0 + 2, 3, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.guard_post("yard_west", area.x0 + 3, area.oz, 3),
					plots.guard_post("yard_east", area.x1 - 3, area.oz, 1),
					plots.work("spar_west", "spar", area.x0 + 4, area.z1 - 5, 1),
					plots.work("spar_east", "spar", area.x0 + 6, area.z1 - 5, 3),
					plots.spare("yard", area.x0 + 4, area.z1 - 4, 2),
				}
			end},
		-- 6. The quartermaster's store. Door index 6, single leaf, for the
		-- roof-post reason the market's charnel store records.
		{id = "watch_quartermaster", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 13, d = 15, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true}},
		-- 7. The cart shed: open on two sides, the wagon and the barrels under
		-- it and the rest of the load on the apron.
		{id = "watch_cart_shed", module = "buildings", make = "shed",
			order = 7, margin = 4, spec = {w = 13, d = 9, wall_h = 4},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wagon(buf, palette, area.x0 + 3, area.z1 - 3, "x")
				dressing.crates(buf, palette, area.x1 - 3, area.z1 - 3, 2)
				dressing.wood_pile(buf, palette, area.x0 + 2, area.z0 + 2, 3, "x")
			end},
		-- 8. The serjeant's house.
		{id = "watch_serjeant_house", module = "buildings", make = "cottage",
			order = 8,
			spec = {w = 11, d = 7, wall_h = 4, roof = "hip", infill = true}},
		-- 9. The watch tower at the district's far corner, turned a quarter so
		-- its door faces the lane rather than repeating the drill yard's post,
		-- and the second of the district's spare wander spots.
		{id = "watch_tower", module = "buildings", make = "watchpost",
			order = 9, turns = 1, spec = {},
			extra_sockets = function(area)
				return {
					plots.guard_post("tower_foot", area.ox - 1, area.z0 + 3, 0),
					plots.spare("tower", area.x1 - 2, area.z1 - 2, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL: four dressings on the quadrant's four fill lots,
	-- reaches 11, 11, 8 and 5, laid out on the forecourt/feature rule the
	-- market district's roster writes down. A garrison quarter is not fields
	-- and gardens, so its fill is the ground a watch keeps: the muster field it
	-- drills on, the bone rampart it is exercised over, the pyre court where
	-- its own are burned, and one close.
	local FILL = {
		-- 1. THE MUSTER FIELD: open trodden ground inside a rail, drill posts
		-- across the middle, standards at the head of it. Three SPAR at the
		-- posts and one SWEEPS the yard -- the one activity that moves
		-- (contract section 8.2), and raking a drill yard is what it is for.
		{id = "watch_muster_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for x = -8, 8, 4 do
					dressing.drill_post(buf, palette, x, 0, 3)
				end
				dressing.standard(buf, palette, -7, -6, 5)
				dressing.standard(buf, palette, 7, -6, 5)
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				-- The flora is sown in two bands with the SOCKET ROW left
				-- out between them. `dressing.blight_flora` sows any column
				-- whose ground is its own and whose cell above is free, and a
				-- standing position is exactly a free cell above its own
				-- ground: a dead shrub in a sparring guard's feet is a socket
				-- with no headroom, which is what the KAT said about the first
				-- version of this row.
				dressing.blight_flora(buf, palette, -10, 2, 10, 10, 9, 2, 3)
				dressing.blight_flora(buf, palette, -10, -8, 10, -3, 9, 2, 3)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("spar_west", "spar", -4, -1, 0),
					plots.work("spar_mid", "spar", 0, -1, 0),
					plots.work("spar_east", "spar", 4, -1, 0),
					plots.work("muster_rake", "sweep", 0, -9, 0),
					plots.work("muster_saw", "chop", -8, -9, 0),
				}
			end},
		-- 2. THE BONE RAMPART: a bank of the city's own spoil inside a
		-- palisade, which is what a garrison exercises over. The quarry face
		-- at the head of it is where the wave-2 `mine` activity belongs -- its
		-- feature is "a stone, ore or cobble node at head or chest height", and
		-- two courses of the palette's own foundation are exactly that.
		{id = "watch_bone_rampart", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.berm(buf, palette, -9, 4, 9, 9, 3)
				dressing.palisade(buf, palette, -11, 11, 11, 11, 3)
				-- The flora is sown in two bands with the SOCKET ROW left
				-- out between them. `dressing.blight_flora` sows any column
				-- whose ground is its own and whose cell above is free, and a
				-- standing position is exactly a free cell above its own
				-- ground: a dead shrub in a sparring guard's feet is a socket
				-- with no headroom, which is what the KAT said about the first
				-- version of this row.
				dressing.blight_flora(buf, palette, -10, -8, 10, -6, 7, 2, 2)
				dressing.blight_flora(buf, palette, -10, -2, 10, 3, 7, 2, 2)
				-- The quarry face: two courses of masonry standing clear, so
				-- the miner's pick meets stone at chest height.
				for x = -7, -3 do
					for y = 1, 2 do
						buf:put(x, y, -3, palette.node("foundation"))
					end
				end
				for x = 3, 7 do
					for y = 1, 2 do
						buf:put(x, y, -3, palette.node("foundation"))
					end
				end
				dressing.rubble_heap(buf, palette, -8, -5, 2)
				dressing.rubble_heap(buf, palette, 8, -5, 1)
				dressing.crates(buf, palette, 6, -7, 0)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("face_west", "mine", -5, -4, 0),
					plots.work("face_east", "mine", 5, -4, 0),
					plots.spare("rampart", 8, -10, 0),
				}
			end},
		-- 3. THE PYRE COURT, where the watch burns its own: the candle court
		-- of `undead_parts.lua` with two keeping the vigil at its altar.
		{id = "watch_pyre_court", module = "undead", make = "candle_court",
			margin = 3, spec = {size = 11},
			extra_sockets = function(area)
				return {
					plots.work("vigil_south", "pray",
						area.ox + 5, area.oz + 3, 0),
					plots.work("vigil_north", "pray",
						area.ox + 5, area.oz + 7, 2),
				}
			end},
		-- 4. THE GUARD CLOSE inside the quarter: a gravewood, a bench, the
		-- stores and the district's last spare.
		{id = "watch_close", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.gravewood(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("close_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("close", 4, -5, 0),
				}
			end},
	}

	M.martial = plots.district({
		key = "nhal_veyr_watch",
		role = "martial_garrison",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
