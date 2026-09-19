-- Narrow R7 correction for functional activation anchors omitted from R4's
-- hard-volume population. Geometry and every other R4 query remain delegated.

return function(session, roster)
	local function fail(message) error("WP40 R7 zone overlay: " .. message, 0) end
	if type(session) ~= "table" or type(session.territory_rule_at) ~= "function" or
			type(session.compatibility) ~= "table" or type(roster) ~= "table" or
			roster.schema ~= "grug_wp40_r7_anchor_roster_v1" or
			type(roster.rows) ~= "table" or #roster.rows ~= 42 then
		fail("construction seam differs")
	end
	local protected_columns = {}
	for index = 1, #roster.rows do
		local row = roster.rows[index]
		if row.family == "outpost" or row.family == "bandit" then
			local key = tostring(row.x) .. "/" .. tostring(row.z)
			if protected_columns[key] then fail("duplicate protected column") end
			protected_columns[key] = row.id
		end
	end
	local count = 0
	for _ in pairs(protected_columns) do count = count + 1 end
	if count ~= 36 then fail("protected column population differs") end
	local function coordinate(value, label)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge then fail(label .. " differs") end
		if value >= 0 then
			local base = math.floor(value)
			return value - base >= 0.5 and base + 1 or base
		end
		local base = math.ceil(value)
		return base - value >= 0.5 and base - 1 or base
	end
	local function functional_protected(position)
		if type(position) ~= "table" then fail("position differs") end
		local x, y, z = coordinate(position.x, "x"), coordinate(position.y, "y"),
			coordinate(position.z, "z")
		return y >= -700 and protected_columns[tostring(x) .. "/" .. tostring(z)] ~= nil
	end
	local wrapped = {}
	for key, value in pairs(session) do wrapped[key] = value end
	function wrapped.territory_rule_at(position)
		if functional_protected(position) then return "hard_protected" end
		return session.territory_rule_at(position)
	end
	local compatibility = {}
	for key, value in pairs(session.compatibility) do compatibility[key] = value end
	function compatibility.world_protected_for_faction(position, actor_faction)
		if functional_protected(position) then return true end
		return session.compatibility.world_protected_for_faction(position, actor_faction)
	end
	wrapped.compatibility = compatibility
	wrapped.r7_functional_anchor_overlay = {
		schema = "grug_wp40_r7_functional_anchor_protection_v1",
		roster_sha256 = roster.sha256, exact_columns = 36, y_min = -700}
	return wrapped
end
