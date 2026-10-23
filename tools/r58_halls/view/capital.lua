-- A whole capital for the town viewer (Round 58 lane HALLS2): the civic core
-- and every district plot one seed's plan placed (tools/r58_halls/plan_layout.lua),
-- each plot turned and moved as the settlement writer turns and moves it
-- (`r7_settlement.lua`: positions by `plot_approach.rot`, param2 by `parts.rotate_param2`,
-- the panes settled again) and lifted to its planned base height over the
-- core's. No streets, walls or terrain: the planner's ground is not part of
-- a blueprint. The Miner's Guild house's plot is the landmark box
-- `miners_guild`, its door the point `miners_guild_door`. With `only =
-- "district"`, only the plots of the house's own district (no core): a whole
-- capital is some 350,000 cells, its district about 75,000.
--
--   dofile("tools/r58_halls/view/capital.lua")(repo, key, layout[, only])
return function(repo, key, layout, only)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local parts = dofile(wp13 .. "/parts.lua")
	local rot = dofile(wp13 .. "/plot_approach.lua").rot  -- r7_settlement.lua's
	local library = dofile(wp40 .. "/r7_wp13_library.lua")
	local kit = dofile(wp40 .. "/r7_capital_blueprint.lua").kit(key)
	local plan = assert(layout[key], "no plan for " .. key)
	local by_id = {}
	for _, plot in ipairs(kit.plots) do by_id[plot.id] = plot end
	local cells = {}
	local minp, maxp = {x = 1e9, y = 1e9, z = 1e9}, {x = -1e9, y = -1e9, z = -1e9}
	local function add(x, y, z, name, param2)
		cells[#cells + 1] = {x = x, y = y, z = z, name = name, param2 = param2}
		if x < minp.x then minp.x = x end
		if y < minp.y then minp.y = y end
		if z < minp.z then minp.z = z end
		if x > maxp.x then maxp.x = x end
		if y > maxp.y then maxp.y = y end
		if z > maxp.z then maxp.z = z end
	end
	if only ~= "district" then
		for _, cell in ipairs(library.composition(key).core().cells) do
			add(cell.x, cell.y, cell.z, cell.name, cell.param2 or 0)
		end
	end
	local district = assert(by_id.miners_guild, key .. ": no guild plot").district
	local landmarks = {}
	for _, placed in ipairs(plan.plots) do
		local plot = assert(by_id[placed.id], key .. ": no plot " .. placed.id)
		if only ~= "district" or plot.district == district then
			local bp = plot.build()
			local turns = placed.turns % 4
			local buf = parts.buffer()
			for _, cell in ipairs(bp.cells) do
				local x, z = rot(cell.x, cell.z, turns)
				buf:put(x, cell.y, z, cell.name, parts.canonical_param2(cell.name,
					parts.rotate_param2(cell.param2 or 0, parts.param2_kind(cell.name), turns)))
			end
			parts.resolve_panes(buf)
			local order, count = buf:cells()
			local dy = placed.y - plan.core_y
			for index = 1, count do
				local cell = order[index]
				add(cell.x + placed.x, cell.y + dy, cell.z + placed.z, cell.name, cell.param2)
			end
			if placed.id == "miners_guild" then
				local b = bp.bounds
				local ax, az = rot(b.min.x, b.min.z, turns)
				local bx, bz = rot(b.max.x, b.max.z, turns)
				landmarks.miners_guild = {
					min = {x = math.min(ax, bx) + placed.x, y = b.min.y + dy, z = math.min(az, bz) + placed.z},
					max = {x = math.max(ax, bx) + placed.x, y = b.max.y + dy, z = math.max(az, bz) + placed.z}}
				local door = bp.landmarks.doors[1]
				local dx, dz = rot(door.x, door.z, turns)
				landmarks.miners_guild_door = {x = dx + placed.x, y = door.y + dy, z = dz + placed.z}
			end
		end
	end
	return {cells = cells, bounds = {min = minp, max = maxp}, landmarks = landmarks}
end
