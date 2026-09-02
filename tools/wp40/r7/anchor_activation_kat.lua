local repo = assert(arg[1], "repository root required")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"

local function check(condition, message)
	if not condition then error("WP40 R7 anchor KAT: " .. message, 0) end
	return condition
end

local rows, by_column = {}, {}
for index = 1, 42 do
	local numeric_id = index <= 6 and index + 6 or index + 18
	local family = index <= 6 and "capital" or (index <= 30 and "outpost" or "bandit")
	local row = {id = string.format("anchor_%03d", numeric_id),
		numeric_id = numeric_id, zone_id = "zone_" .. numeric_id,
		slot_id = family .. "_slot", family = family,
		content_ref = family == "bandit" and 1 or 2,
		x = numeric_id * 10, y = 100 + numeric_id, z = numeric_id * -20,
		functional_kind = family == "capital" and "anchor_platform" or "land_grade",
		functional_y = 100 + numeric_id,
		functional_feature_id = "feature_" .. string.format("%03d", numeric_id),
		hard_foundation = family == "capital"}
	rows[index], by_column[row.x .. "/" .. row.z] = row, row
end
local roster = {schema = "grug_wp40_r7_anchor_roster_v1",
	sha256 = string.rep("a", 64), rows = rows}
local function roster_factory() return roster end
local anchor_content = {schema = "grug_wp40_r7_anchor_content_v1"}
function anchor_content.resolve_anchor(ref, param2)
	check((ref == 1 or ref == 2) and param2 == 0, "content resolver input differs")
	return 500 + ref, 1, 1, 0, 32
end
local content = {}
function content.content_contract()
	return {ignore_cid = 65535, r5 = {resolve = function(role, _, aux)
		check(role == 1 and aux == 0, "air resolver input differs")
		return 0, 0, 0, 0
	end, classify = function(cid)
		if cid == 88 then return 4, 1, 1 end
		if cid == 77 then return 1, 0, 0 end
		return 2, 0, 0
	end}}
end

local config = dofile(wp40 .. "/r7_anchor_activation.lua")(
	roster_factory, anchor_content)
local tail = config.new({source = {}, zones_session = {},
	planner_source = {}, raw_sha256 = function() return string.rep("x", 32) end,
	content = content})
local plan = {}
tail:bind_plan({x = -10000, y = -10000, z = -10000},
	{x = 10000, y = 10000, z = 10000}, plan, 7)
local written = {}
local context = {plan = plan, generation = 7, call_mode = "fixture"}
function context.inside_owner() return true end
function context.column_values_at(x, z)
	local row = check(by_column[x .. "/" .. z], "unknown anchor column")
	return "land", 0, row.zone_id, "biome", "race", row.y, nil, nil, nil,
		row.functional_kind, row.functional_y, row.functional_feature_id, nil,
		nil, nil, nil, nil, nil, nil, row.hard_foundation
end
function context.settled_at(x, y, z)
	local row = check(by_column[x .. "/" .. z], "unknown settled column")
	if y == row.y then return 66, 0, 0, 0, 0, 0, 0 end
	check(y == row.y + 1, "root y differs")
	return 0, 0, 0, 0, 0, 0, 0
end
function context.write_anchor(x, y, z, cid, param2, ref, feature)
	written[#written + 1] = {x, y, z, cid, param2, ref, feature}
end

local function rejected_tuple(family, support_override, root_override, tuple_drift)
	local candidate = config.new({source = {}, zones_session = {},
		planner_source = {}, raw_sha256 = function() return string.rep("x", 32) end,
		content = content})
	candidate:bind_plan({x = -10000, y = -10000, z = -10000},
		{x = 10000, y = 10000, z = 10000}, plan, 7)
	local altered = {}
	for key, value in pairs(context) do altered[key] = value end
	function altered.column_values_at(x, z)
		local values = {context.column_values_at(x, z)}
		local row = by_column[x .. "/" .. z]
		if row and row.family == family and tuple_drift then
			values[tuple_drift[1]] = tuple_drift[2]
		end
		return unpack(values, 1, 20)
	end
	function altered.settled_at(x, y, z)
		local row = by_column[x .. "/" .. z]
		if row and row.family == family and y == row.y then
			local values = {66, 0, 0, 0, 0, 0, 0}
			if support_override then values[support_override[1]] = support_override[2] end
			return unpack(values, 1, 7)
		elseif row and row.family == family and y == row.y + 1 then
			local values = {0, 0, 0, 0, 0, 0, 0}
			if root_override then values[root_override[1]] = root_override[2] end
			return unpack(values, 1, 7)
		end
		return context.settled_at(x, y, z)
	end
	return pcall(function() candidate:settle(altered) end)
end
for _, family in ipairs({"capital", "outpost", "bandit"}) do
	for _, support_case in ipairs({
		{1, 0, "air"}, {1, 65535, "ignore"}, {1, 88, "liquid"},
		{1, 77, "nonsolid"}, {3, 1, "occupancy"}, {4, 12, "opcode"},
		{5, 1, "feature"}, {6, 1, "interface"}, {7, 1, "aux"},
	}) do
		check(not rejected_tuple(family, support_case), support_case[3] .. " " ..
			family .. " support was accepted")
	end
	for _, root_case in ipairs({
		{1, 66, "CID"}, {2, 1, "param2"}, {3, 1, "occupancy"},
		{4, 1, "opcode"}, {5, 1, "feature"}, {6, 1, "interface"},
		{7, 1, "aux"},
	}) do
		check(not rejected_tuple(family, nil, root_case), root_case[3] .. " " ..
			family .. " root was accepted")
	end
	for _, drift in ipairs({
		{10, "causeway", "kind"}, {11, 999, "height"},
		{12, "other_feature", "feature"}, {20, family ~= "capital",
			"foundation"},
	}) do
		check(not rejected_tuple(family, nil, nil, drift), drift[3] .. " " ..
			family .. " planner drift was accepted")
	end
end
local boundary = config.new({source = {}, zones_session = {},
	planner_source = {}, raw_sha256 = function() return string.rep("x", 32) end,
	content = content})
boundary:bind_plan({x = -10000, y = -10000, z = -10000},
	{x = 10000, y = 10000, z = 10000}, plan, 7)
local boundary_context = {}
for key, value in pairs(context) do boundary_context[key] = value end
function boundary_context.inside_owner(x, y, z)
	local row = by_column[x .. "/" .. z]
	return row ~= nil and y == row.y + 1
end
local boundary_ledger = boundary:settle(boundary_context)
check(boundary_ledger.written == 42,
	"owner-edge roots did not validate support from the read-only halo")
written = {}
local ledger = tail:settle(context)
check(ledger.schema == "grug_wp40_r7_anchor_ledger_v1" and
	ledger.written == 42 and #ledger.operations == 42 and #written == 42,
	"closed write population differs")
for index = 1, 42 do
	local row, operation, write = rows[index], ledger.operations[index], written[index]
	check(operation.id == row.id and operation.y == row.y + 1 and
		operation.support_y == row.y and operation.final_opcode == 36 and
		operation.support_cid == 66 and operation.support_occupancy == 0 and
		operation.final_feature == row.numeric_id and
		operation.final_aux == (95 + row.content_ref - 1) * 256 and
		write[1] == row.x and write[2] == row.y + 1 and write[3] == row.z and
		write[4] == 500 + row.content_ref and write[6] == row.content_ref and
		write[7] == row.numeric_id, "operation differs at " .. index)
end

local session = {compatibility = {}}
function session.territory_rule_at() return "shared_editable" end
function session.compatibility.world_protected_for_faction() return false end
local wrapped = dofile(wp40 .. "/r7_zone_overlay.lua")(session, roster)
local protected = 0
for index = 1, 42 do
	local row = rows[index]
	if row.family ~= "capital" then
		protected = protected + 1
		check(wrapped.territory_rule_at({x = row.x, y = -700, z = row.z}) ==
			"hard_protected", "functional y-min is not protected")
		check(wrapped.territory_rule_at({x = row.x, y = -701, z = row.z}) ==
			"shared_editable", "contested deep column became protected")
		check(wrapped.compatibility.world_protected_for_faction(
			{x = row.x + 0.49, y = row.y + 1, z = row.z - 0.49}, "accord") == true,
			"rounded functional root is not protected")
		check(wrapped.territory_rule_at({x = row.x + 0.5, y = row.y + 1,
			z = row.z}) == "shared_editable", "adjacent column became protected")
	else
		check(wrapped.territory_rule_at({x = row.x, y = row.y + 1, z = row.z}) ==
			"shared_editable", "capital escaped predecessor authority")
	end
end
check(protected == 36 and wrapped.r7_functional_anchor_overlay.exact_columns == 36 and
	wrapped.r7_functional_anchor_overlay.y_min == -700,
	"protection overlay population differs")

local order = {}
local p9g_config = {new = function()
	return {plan_slice = function() order[#order + 1] = "p9g_plan" end,
		plan_evidence_owner = function() return {}, 1 end,
		settle = function(_, value)
			check(value.write_anchor == nil, "P9G received anchor writer")
			order[#order + 1] = "p9g_settle"
			return {schema = "grug_wp40_r7_p9g_ledger_v1"}
		end, metrics = function() return {} end,
		probe_reason = function() return "accepted" end}
end}
local anchor_config = {new = function()
	return {bind_plan = function() order[#order + 1] = "anchor_plan" end,
		settle = function(_, value)
			check(type(value.write_anchor) == "function", "anchor writer is absent")
			order[#order + 1] = "anchor_settle"
			return {schema = "grug_wp40_r7_anchor_ledger_v1"}
		end, metrics = function() return {} end, roster = function() return roster end}
end}
local successor = dofile(wp40 .. "/r7_successor.lua")(p9g_config, anchor_config).new({})
local composed_context = {write_anchor = function() end}
for _, key in ipairs({"schema", "plan", "generation", "call_mode", "min_x",
		"min_y", "min_z", "max_x", "max_y", "max_z", "inside_owner",
		"original_at", "settled_at", "production_content", "analytic_p7_ref",
		"analytic_p7_tuple", "exclusion_at", "housing_excluded_at",
		"column_values_at", "write_p9g"}) do composed_context[key] = function() end end
successor:plan_slice({}, {}, {}, 1)
local composed = successor:settle(composed_context)
check(composed.schema == "grug_wp40_r7_successor_ledger_v1" and
	table.concat(order, ",") == "p9g_plan,anchor_plan,p9g_settle,anchor_settle",
	"successor order differs")

io.write("WP40 R7 anchor activation KAT PASS roots=42 protected_columns=36\n")
