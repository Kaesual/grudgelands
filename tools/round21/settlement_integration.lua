-- Reuse a caller's ONE built runtime and final VM snapshots. No constructors.
local M = {}
local function origin(n) return math.floor((n + 32) / 80) * 80 - 32 end
local function owner(x, y, z) return {x = origin(x), y = origin(y), z = origin(z)} end
local function contains(b, x, y, z)
	return x >= b.x and x <= b.x + 79 and y >= b.y and y <= b.y + 79 and z >= b.z and z <= b.z + 79
end
function M.owners(built)
	local columns = assert(built.round21_planner_source, "attach observed planner source")
	local prepared = assert(built.round21_prepared, "attach observed prepared settlements")
	local anchor = assert(built.zones_session.anchor("kragmar_kezamba", "capital"))
	local function ground(x, z) return select(6, columns.column_values_at(x, z)) end
	local _, _, _, _, _, gate_y = columns.column_values_at(2056, 1500)
	local cases = {
		{label = "Kezamba core", x = 1800, z = 1446, dx = 0, dz = 1, length = 5, expected = anchor.y},
		{label = "Kezamba east gate", x = 2053, z = 1499, dx = 1, dz = 0, length = 5, expected = gate_y, natural_from = 5},
	}
	local owners, seen = {}, {}
	local function add(b)
		local key = b.x .. ":" .. b.y .. ":" .. b.z
		if not seen[key] then seen[key] = true; owners[#owners + 1] = b end
	end
	for _, case in ipairs(cases) do add(owner(case.x, case.expected, case.z)) end
	local candidate, candidate_score
	for _, row in ipairs(prepared) do
		if row.profile.key == "kezamba" then
			local roads = {}
			for _, blueprint in ipairs(row.prepared.blueprints) do
				for _, run in ipairs(blueprint.runs or {}) do roads[#roads + 1] = run end
			end
			for _, blueprint in ipairs(row.prepared.blueprints) do
				local descriptor, marks = blueprint.descriptor, blueprint.landmarks
				if descriptor.kind == "reference" and marks and marks.plot and marks.entry then
					local x = descriptor.offset.x + marks.entry.x
					local end_z = descriptor.offset.z + marks.plot.min.z
					local road
					for _, run in ipairs(roads) do
						if run.junctions and run.axis == "x" and x >= run.from and x <= run.to and
								run.at < end_z - 2 and end_z - run.at <= 24 and (not road or run.at > road.at) then road = run end
					end
					if road then
						local wx, wz = anchor.x + x, anchor.z + road.at + 2
						local y = ground(anchor.x + descriptor.offset.x + blueprint.reference.x,
							anchor.z + descriptor.offset.z + blueprint.reference.z)
						local b = owner(wx, y, wz)
						if contains(b, wx, y + 4, anchor.z + end_z) and y >= b.y + 4 then
							local score = end_z - road.at
							for _, existing in ipairs(owners) do
								if existing.x == b.x and existing.y == b.y and existing.z == b.z then score = score - 100 end
							end
							if not candidate or score < candidate_score then
								candidate_score = score
								candidate = {label = "Kezamba " .. descriptor.id, x = wx, z = wz,
									dx = 0, dz = 1, length = end_z - road.at - 2, expected = y, owner = b}
							end
						end
					end
				end
			end
		end
	end
	assert(candidate, "no single-owner real plot approach found; choose explicitly")
	cases[#cases + 1] = candidate
	add(candidate.owner)
	built.round21_settlement_cases = cases
	for _, case in ipairs(cases) do print("walk_case", case.label, case.x, case.z, case.length, case.expected) end
	return owners
end
function M.check(built, api, outputs, metrics)
	local function node(x, y, z)
		for _, out in ipairs(outputs) do
			if contains(out.min, x, y, z) then
				local s = out.snapshot
				local axis = s.emax.x - s.emin.x + 1
				local sy = s.emax.y - s.emin.y + 1
				local i = (z-s.emin.z)*axis*sy + (y-s.emin.y)*axis + x-s.emin.x+1
				local name = assert(api.get_name_from_content_id(s.data[i]))
				local def = assert(api.registered_nodes[name], name)
				return {name = name, param2 = s.param2[i], stair = (def.groups or {}).stair == 1, solid = name ~= "air" and name ~= "ignore" and
					def.walkable ~= false and (def.liquidtype == nil or def.liquidtype == "none")}
			end
		end
	end
	local function floor_at(x, z, expected)
		local best, distance
		for y = math.floor(expected) - 24, math.floor(expected) + 24 do
			local floor, one, two = node(x,y,z), node(x,y+1,z), node(x,y+2,z)
			if floor and one and two and floor.solid and not one.solid and not two.solid then
				local d = math.abs(y-expected)
				if not best or d < distance then best, distance = {y=y,node=floor}, d end
			end
		end
		assert(best, "no final floor/headroom at " .. x .. "," .. z)
		return best
	end
	for _, case in ipairs(assert(built.round21_settlement_cases)) do
		local previous, rows = nil, {}
		for p = 0, case.length do
			local x, z = case.x + p*case.dx, case.z + p*case.dz
			local floor = floor_at(x, z, case.expected)
			rows[#rows + 1] = floor.y .. ":" .. floor.node.name .. ":" .. floor.node.param2
			for _, offset in ipairs({-0.25, 0.25}) do
				local y = floor.y + 0.5
				if floor.node.stair then
					assert(floor.node.param2 < 4, "unexpected upside-down road stair")
					local direction = ({[0]={0,1},[1]={1,0},[2]={0,-1},[3]={-1,0}})[floor.node.param2]
					if offset * (direction[1]*case.dx+direction[2]*case.dz) < 0 then y = floor.y end
				end
				-- Keep the authored gate and its first exterior connection strict;
				-- the remaining exterior terrain permits ordinary one-node steps.
				local limit = case.natural_from and p >= case.natural_from and 1.01 or 0.6
				assert(not previous or math.abs(y-previous) <= limit,
					case.label .. ": unwalkable half-step at " .. x .. "," .. z .. " (" .. tostring(previous) .. " -> " .. y .. ")")
				previous = y
			end
		end
		print("walk_pass", case.label, table.concat(rows, ";"))
	end
	local count = 0
	for key, row in pairs(metrics) do
		if type(row) == "table" and row.approach_findings then
			for _, finding in ipairs(row.approach_findings) do
				print("approach_finding", key, finding); count = count + 1
			end
		end
	end
	assert(count == 0, "actual touched plots have unresolved approach findings")
	print("approach_findings", count)
end
return M
