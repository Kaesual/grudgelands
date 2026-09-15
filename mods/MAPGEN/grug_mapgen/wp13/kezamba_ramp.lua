-- THE GATE RAMP: how Kezamba's avenues come down to the ground Lane R hands
-- them at the four gate points.
--
-- WHAT WENT WRONG WITHOUT IT. `wp13/avenue.lua` walks its road at the
-- ONE-LIPSCHITZ UPPER ENVELOPE of the surface -- "the lowest height field that
-- is everywhere at or above the surface and never changes by more than a node
-- between two columns" -- over a look-around of forty columns. Outside
-- Kezamba's 512 envelope the terrain climbs fast (40 nodes in 32 columns beyond
-- the east gate on seed 531802985935182545), so the envelope lifts the road
-- inside the envelope to meet ground that is outside it, and the run then STOPS
-- at the gate point. The independent review of 2026-09-16 measured the result on
-- all four gates and all nine seeds: the road arrives at its gate point up to
-- **26 nodes above the terrain**, as a sheer face with nothing beyond it, and
-- the threshold's posts and kerbs float on the same level.
--
-- Lane R ends every long-distance route on that column at FREE-TERRAIN height
-- and states that the first columns inside each gate are the city lane's to
-- terrace. The coordinator's ruling of 2026-09-16 is therefore: **the avenue
-- arrives at the gate point at the terrain height there**, descending inside
-- the envelope over as many columns as it needs, at most one node a column,
-- with nothing floating.
--
-- THE RULE, and it is one line:
--
--     T(p) = min( D(p), g + |p - gate| )
--
-- where `D(p)` is the road's own deck at column `p` -- read back off the piece
-- `avenue.run` just returned, not re-derived -- and `g` is the terrain at the
-- gate point's centre column. `T` is the minimum of two functions that each
-- change by at most a node per column, so `T` does too, and it is nowhere above
-- the road the module built. Where `T < D` the column is REBUILT: air from `T`
-- upward, deck at `T`, basalt from the column's own terrain up to `T`, a rail on
-- both kerbs, and the verge standards carried down to the road they light.
--
-- WHY IT IS HERE AND NOT IN `avenue.lua`. That module is the shared road of
-- three capitals and Lane R's; Highcourt's and Dur Brannoc's built roads are
-- frozen against it, and their gates measure at most +4 and +2, so this is
-- Kezamba's terrain and not a defect of the road. It is the same shape of fix
-- Dur Brannoc used for its causeway parapet: a pure function of the piece the
-- road module just returned, plus the surface callback the seam already hands
-- us, so a piece of a run stays exactly that stretch of the whole run.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The look-around the seam gives an overlay run. A ramp longer than this
	-- could not be computed by a piece that does not contain the gate point, so
	-- a drop deeper than `REACH` is refused rather than silently stepped.
	M.REACH = 40

	local function signature(palette)
		return palette.maybe("signature") or palette.node("foundation")
	end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function kerb(palette)
		return palette.node("plaza_edge")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end

	-- Every node name a ramp may write, for the overlay's own palette union.
	function M.palette_names(palette)
		local names = {parts.AIR, signature(palette), paving(palette),
			kerb(palette), tread(palette), palette.node("post"),
			palette.node("railing"), palette.node("light_post")}
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 kezamba ramp: the palette has no name for a role", 0)
			end
			if not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
		table.sort(list, parts.less_bytes)
		return list
	end

	local function axis_steps(axis)
		if axis == "x" then return 1, 0 end
		if axis == "z" then return 0, 1 end
		error("wp13 kezamba ramp: unknown axis " .. tostring(axis), 0)
	end

	-- THE HEIGHT THE ROAD MUST ARRIVE AT. The terrain of the gate point's own
	-- centre column, which is where Lane R ends its route. It is a function of
	-- one column, so every piece of the run computes the same number.
	function M.gate_level(spec, surface, gate)
		local dx = (spec.axis == "x") and 1 or 0
		local at = spec.at
		local x, z
		if dx == 1 then x, z = gate, at else x, z = at, gate end
		local y = surface(x, z)
		if type(y) ~= "number" or y % 1 ~= 0 then
			error("wp13 kezamba ramp: the surface at the gate point is " ..
				tostring(y) .. ", not a node height", 0)
		end
		return y
	end

	-- Bring one piece of one avenue down to its gate.
	--
	-- `piece` is what `avenue.run` returned; it is modified in place and
	-- returned. `plan.gate` is the run's gate point along its own axis.
	function M.run(palette, spec, surface, piece, plan)
		if type(surface) ~= "function" then
			error("wp13 kezamba ramp: a ramp needs a surface callback", 0)
		end
		if type(plan) ~= "table" or type(plan.gate) ~= "number" then
			error("wp13 kezamba ramp: a ramp needs its gate point", 0)
		end
		local width = spec.width
		if type(width) ~= "number" or width % 2 ~= 1 then
			error("wp13 kezamba ramp: the run has no carriageway", 0)
		end
		local half = (width - 1) / 2
		local band = half + 1                -- the seam's activation band
		local reach = spec.reach or M.REACH
		local dx, dz = axis_steps(spec.axis)
		local at = spec.at
		local gate = plan.gate
		local spacing = spec.lamp_spacing or 8
		local phase = spec.lamp_phase or spec.from

		local function column(p, lane)
			if dx == 1 then return p, at + lane end
			return at + lane, p
		end
		local queries = 0
		local function height(x, z)
			queries = queries + 1
			local y = surface(x, z)
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 kezamba ramp: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		local g = M.gate_level(spec, surface, gate)

		-- 1. The road's OWN deck per column of this piece, read back off the
		-- cells rather than re-derived: the topmost cell of the carriageway.
		local deck, high = {}, {}
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			local p = (dx == 1) and cell.x or cell.z
			local lane = (dx == 1) and (cell.z - at) or (cell.x - at)
			if lane >= -half and lane <= half then
				if deck[p] == nil or cell.y > deck[p] then deck[p] = cell.y end
			end
			if lane >= -band and lane <= band then
				if high[p] == nil or cell.y > high[p] then high[p] = cell.y end
			end
		end

		-- 2. The columns this ramp owns, and the refusal if the drop is deeper
		-- than a piece can see.
		local band_columns, drop = {}, 0
		for p = spec.from, spec.to do
			local distance = math.abs(p - gate)
			local D = deck[p]
			if D ~= nil and distance <= reach then
				local target = g + distance
				if target < D then
					band_columns[#band_columns + 1] = {p = p, target = target,
						deck = D}
					if D - target > drop then drop = D - target end
				end
			elseif D ~= nil and distance == reach + 1 and D > g + distance then
				error("wp13 kezamba ramp: the run " .. tostring(spec.id) ..
					" arrives " .. (D - g) .. " nodes over its gate, deeper " ..
					"than the " .. reach .. "-column look-around a piece has", 0)
			end
		end
		if #band_columns == 0 then
			piece.ramp_columns = 0
			piece.ramp_drop = 0
			piece.ramp_gate_level = g
			piece.ramp_queries = queries
			return piece
		end

		-- 3. Drop every cell of this piece in a ramp column, lamps included.
		local doomed = {}
		for index = 1, #band_columns do doomed[band_columns[index].p] = true end
		local kept = {}
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			local p = (dx == 1) and cell.x or cell.z
			local lane = (dx == 1) and (cell.z - at) or (cell.x - at)
			if not (doomed[p] and lane >= -band and lane <= band) then
				kept[#kept + 1] = cell
			end
		end
		local lamps = {}
		for index = 1, #(piece.lamps or {}) do
			local lamp = piece.lamps[index]
			local p = (dx == 1) and lamp.x or lamp.z
			if not doomed[p] then lamps[#lamps + 1] = lamp end
		end

		-- 4. Rebuild them. Air from the new deck up to whatever the old road
		-- reached, so nothing of it is left hanging over the ramp; basalt from
		-- the column's own terrain up to the deck, so nothing of the ramp
		-- floats; a tread where the level steps; a rail on both kerbs, because
		-- a ramp is what the causeway rail exists for; and the verge standards
		-- carried down to the road they light.
		local PIER = signature(palette)
		local PAVE = paving(palette)
		local KERB = kerb(palette)
		local TREAD = tread(palette)
		local RAIL = palette.node("railing")
		local POST = palette.node("post")
		local function add(x, y, z, name, param2)
			kept[#kept + 1] = {x = x, y = y, z = z, name = name,
				param2 = param2 or parts.place_param2(name)}
		end
		local level = {}
		for index = 1, #band_columns do
			level[band_columns[index].p] = band_columns[index].target
		end
		local function level_at(p)
			if level[p] ~= nil then return level[p] end
			if deck[p] ~= nil then return deck[p] end
			return g + math.abs(p - gate)
		end
		local piers, rails, treads, standards = 0, 0, 0, 0
		for index = 1, #band_columns do
			local entry = band_columns[index]
			local p, top = entry.p, entry.target
			local ceiling = entry.deck
			if high[p] ~= nil and high[p] > ceiling then ceiling = high[p] end
			for lane = -band, band do
				local x, z = column(p, lane)
				local ground = height(x, z)
				-- The airspace: everything the old road put here, and three
				-- courses of headroom over the new one.
				for y = top + 1, math.max(ceiling, ground) + 3 do
					add(x, y, z, parts.AIR, 0)
				end
				-- The body of the ramp.
				for y = ground, top - 1 do
					add(x, y, z, PIER)
					piers = piers + 1
				end
				if lane >= -half and lane <= half then
					local before, after = level_at(p - 1), level_at(p + 1)
					if top > before or top > after then
						local sign = (after >= before) and 1 or -1
						add(x, top, z, TREAD,
							parts.step_facedir(dx * sign, dz * sign))
						treads = treads + 1
					else
						add(x, top, z,
							(lane == -half or lane == half) and KERB or PAVE)
					end
					if lane == -half or lane == half then
						add(x, top + 1, z, RAIL)
						rails = rails + 1
					end
				else
					-- The verge: the kerb's own material at the road's level,
					-- so a standard has a footing and the threshold's posts
					-- stand on something.
					add(x, top, z, KERB)
					if (p - phase) % spacing == 0 then
						add(x, top + 1, z, POST)
						add(x, top + 2, z, POST)
						-- The torch, written the way `parts.floor_torch` writes
						-- one: the light role with the wallmounted param2 that
						-- stands it on the node below. It is spelled out rather
						-- than called because that helper takes a `parts` buffer
						-- and this routine builds a plain cell list.
						add(x, top + 3, z, palette.node("light_post"),
							parts.wallmounted_support(0, -1, 0))
						lamps[#lamps + 1] = {x = x, y = top + 3, z = z}
						standards = standards + 1
					end
				end
			end
		end

		table.sort(kept, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		piece.cells = kept
		piece.lamps = lamps
		piece.ramp_columns = #band_columns
		piece.ramp_drop = drop
		piece.ramp_gate_level = g
		piece.ramp_piers = piers
		piece.ramp_rails = rails
		piece.ramp_treads = treads
		piece.ramp_standards = standards
		piece.ramp_queries = queries
		return piece
	end

	return M
end

return loader
