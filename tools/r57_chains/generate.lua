-- Round 57 lane CHAINDEPTH: the chain depth report (round57-plan.md ruling 8).
--
--   luajit tools/r57_chains/generate.lua DUMP OUT_DIR
--
-- Reads the probe's dump (tools/r57_chains/dump.sh: every recipe as the game
-- registered it), turns it into crafted steps (chains.steps_from_dump), walks
-- them (chains.lua) and writes OUT_DIR/report.txt and OUT_DIR/index.html (a
-- self-contained page: a sortable table, a filter by area, no external
-- resource). tools/r57_chains/run.sh does the dump and this in one go.
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local chains = dofile(here .. "/chains.lua")
local steps_from_dump = dofile(here .. "/steps.lua")

local dump_path, out_dir = arg[1], arg[2]
assert(dump_path and out_dir, "usage: luajit tools/r57_chains/generate.lua DUMP OUT_DIR")

local handle = assert(io.open(dump_path, "rb"))
local first_line = handle:read("*l") or ""
handle:close()
local commit = first_line:match("^%-%- Commit: (.*)$") or "unknown"
local dump = dofile(dump_path)
local input = steps_from_dump(dump)
local result = chains.analyse(input.steps, input.members)

------------------------------------------------------------------------------
-- Names and labels.
------------------------------------------------------------------------------
local function describe(name)
	local item = dump.items[name]
	local text = item and item.description or ""
	return text ~= "" and text or name
end

local function entry_text(entry, chosen)
	if entry.item then return entry.n .. " " .. describe(entry.item) end
	local text = entry.n .. " group:" .. entry.group
	if chosen then text = text .. " (" .. describe(chosen) .. ")" end
	return text
end

local function ingredients_text(step, chosen)
	local parts = {}
	for index, entry in ipairs(step.ingredients) do
		parts[index] = entry_text(entry, chosen and chosen[index])
	end
	return table.concat(parts, " + ")
end

local function output_text(step)
	local text = describe(step.output)
	if (step.count or 1) > 1 then text = text .. " x" .. step.count end
	return text
end

local function chain_text(step_id)
	local parts = {}
	for _, link in ipairs(chains.path(result, step_id)) do
		local label = describe(link.item)
		if link.step then
			label = label .. " [" .. input.meta[link.step].label .. "]"
		else
			label = label .. " (raw)"
		end
		parts[#parts + 1] = label
	end
	return table.concat(parts, " < ")
end

local function basics_text(list)
	local parts = {}
	for index, id in ipairs(list) do parts[index] = describe(input.by_id[id].output) end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local RULE_TEXT = {}
for _, rule in ipairs(chains.RULES) do RULE_TEXT[rule.id] = rule.text end

-- The notes of a step: alternatives, loop, groups.
local function notes(step)
	local info = result.steps[step.id]
	local parts = {}
	if info.alternatives > 1 then
		parts[#parts + 1] = info.alternatives .. " recipes make " .. describe(step.output) ..
			(info.source and "; this one is the source" or "; not the source")
	end
	if info.broken then
		parts[#parts + 1] = "loop step, rule " .. info.broken
	elseif info.loop and not info.source then
		parts[#parts + 1] = "loop step, rule " .. (result.items[step.output].seeded and
			"seed" or "shallower")
	end
	for index, entry in ipairs(step.ingredients) do
		if entry.group then
			parts[#parts + 1] = "group:" .. entry.group .. " = " ..
				describe(info.chosen[index] or "?")
		end
	end
	return table.concat(parts, "; ")
end

------------------------------------------------------------------------------
-- Numbers.
------------------------------------------------------------------------------
-- The counts and the ten deepest leave out the loop-back steps (rules
-- unpack and cut_back: a block back into bars, a stair back into its
-- block): they are recipes, listed in the table, but no chain to simplify.
local chain_order, loop_back = {}, 0
for _, id in ipairs(result.order) do
	if result.steps[id].broken then
		loop_back = loop_back + 1
	else
		chain_order[#chain_order + 1] = id
	end
end
local per_depth, top = {}, 0
for _, id in ipairs(chain_order) do
	local value = result.steps[id].depth
	per_depth[value] = (per_depth[value] or 0) + 1
	if value > top then top = value end
end
local per_area_depth, areas_seen = {}, {}
for _, id in ipairs(chain_order) do
	local area = input.meta[id].area_label
	per_area_depth[area] = per_area_depth[area] or {}
	per_area_depth[area][result.steps[id].depth] =
		(per_area_depth[area][result.steps[id].depth] or 0) + 1
	areas_seen[area] = true
end
local area_list = {}
for _, label in ipairs(input.area_order) do
	if areas_seen[label] then area_list[#area_list + 1] = label end
end

local operations = {}
for _, op in ipairs(dump.operations) do
	local list = {}
	for _, entry in ipairs(op.ingredients) do list[#list + 1] = entry end
	for _, entry in ipairs(op.weapon_extra or {}) do list[#list + 1] = entry end
	local cost = chains.consume(result, input.resolve_entries(list))
	operations[#operations + 1] = {op = op, cost = cost, list = input.resolve_entries(list)}
end
table.sort(operations, function(a, b)
	if a.cost.depth ~= b.cost.depth then return a.cost.depth > b.cost.depth end
	if a.cost.steps ~= b.cost.steps then return a.cost.steps > b.cost.steps end
	return a.op.id < b.op.id
end)

-- Raw materials: every item an ingredient may be that no step makes, or
-- only a loop-back step (rules unpack and cut_back); the loop seeds apart.
local raw = {}
local function note_raw(name)
	local item = result.items[name]
	if not item or (item.raw and not item.seeded) then raw[name] = true end
end
for _, step in ipairs(input.steps) do
	for _, entry in ipairs(step.ingredients) do
		if entry.item then note_raw(entry.item) else
			for _, name in ipairs(input.members[entry.group] or {}) do note_raw(name) end
		end
	end
end
for _, entry in ipairs(operations) do
	for _, item in ipairs(entry.list) do
		if item.item then note_raw(item.item) end
	end
end
local raw_list = {}
for name in pairs(raw) do raw_list[#raw_list + 1] = name end
table.sort(raw_list)

------------------------------------------------------------------------------
-- report.txt
------------------------------------------------------------------------------
local lines = {}
local function out(text) lines[#lines + 1] = text or "" end

local LEGEND = {
	"Depth: the longest chain of crafted ingredients down to raw materials.",
	"  A step whose ingredients are all raw has depth 1. A furnace (cooking)",
	"  and a dual furnace (alloy) step count like any recipe.",
	"Steps: the distinct crafted steps in the recipe's tree, the recipe itself",
	"  included (a step used twice counts once).",
	"Basic on the way: the Basic recipes in the tree, the recipe itself left out.",
	"Raw: an item no recipe makes (mined, gathered, dropped or bought), or a",
	"  loop seed (rule seed).",
	"Groups (group:wood and the like): the cheapest member by depth, then by",
	"  steps, then by name; the notes name the group and the member.",
	"Several recipes for one item: the item's depth is its shallowest recipe",
	"  (then the fewest steps, then the first id); the notes say so.",
	"Enchants and upgrades are no recipes: their own section gives the depth",
	"  of what they consume (an upgrade per level, a weapon's Stick included).",
}

out("Recipe chain depth report (Round 57 CHAINDEPTH)")
out("Source: the game's registered recipes at commit " .. commit ..
	", dumped by tools/r57_chains/dump.sh")
out(("Recipes: %d (registry %d, furnace %d, dual furnace %d); enchants and upgrades: %d; " ..
	"engine grid routes ignored (the grid has no slots): %d"):format(#input.steps,
	#dump.registry, #dump.furnace, #dump.alloys, #dump.operations, dump.grid or 0))
out()
out("== Legend")
for _, text in ipairs(LEGEND) do out(text) end
out()
out("== Loop rules (applied in this order)")
for _, rule in ipairs(chains.RULES) do out("- " .. rule.id .. ": " .. rule.text) end
out()
out("== Recipes per depth (without the " .. loop_back .. " loop-back steps)")
local header = ("%-14s"):format("Area")
for value = 1, top do header = header .. ("%6s"):format("d" .. value) end
out(header .. ("%7s"):format("all"))
for _, area in ipairs(area_list) do
	local row, total = ("%-14s"):format(area), 0
	for value = 1, top do
		local count = per_area_depth[area][value] or 0
		row, total = row .. ("%6d"):format(count), total + count
	end
	out(row .. ("%7d"):format(total))
end
local row = ("%-14s"):format("All")
for value = 1, top do row = row .. ("%6d"):format(per_depth[value] or 0) end
out(row .. ("%7d"):format(#chain_order))
out()
out("== The ten deepest recipes (then the most steps)")
for index = 1, math.min(10, #chain_order) do
	local id = chain_order[index]
	local step, info = input.by_id[id], result.steps[id]
	out(("%2d. depth %d, %d steps: %s (%s)"):format(index, info.depth, info.steps,
		output_text(step), input.meta[id].label))
	out("    chain: " .. chain_text(id))
end
out()
out("== Every recipe, deepest first")
out("depth steps area/tier: output = ingredients | Basic on the way | notes | chain")
for _, id in ipairs(result.order) do
	local step, info, meta = input.by_id[id], result.steps[id], input.meta[id]
	out(("%d %d %s: %s = %s"):format(info.depth, info.steps, meta.label, output_text(step),
		ingredients_text(step, info.chosen)))
	if #info.basics > 0 then out("    Basic: " .. basics_text(info.basics)) end
	local text = notes(step)
	if text ~= "" then out("    notes: " .. text) end
	if info.depth > 1 then out("    chain: " .. chain_text(id)) end
end
out()
out("== Enchants and upgrades (the depth of what they consume)")
out("depth steps profession T: operation = what one costs | Basic on the way")
for _, entry in ipairs(operations) do
	local op, cost = entry.op, entry.cost
	local parts = {}
	for index, item in ipairs(entry.list) do parts[index] = entry_text(item, cost.chosen[index]) end
	out(("%d %d %s T%d: %s = %s"):format(cost.depth, cost.steps, op.profession, op.tier,
		op.id, table.concat(parts, " + ")))
	if #cost.basics > 0 then out("    Basic: " .. basics_text(cost.basics)) end
end
out()
out("== Loops (" .. #result.loops .. ")")
out("Each loop: its items, then every step inside it with the rule that keeps it")
out("from being a source (no rule: the step is the item's source).")
for number, loop in ipairs(result.loops) do
	local names = {}
	for index, name in ipairs(loop.items) do names[index] = describe(name) end
	out(("%d. %s"):format(number, table.concat(names, ", ")))
	if #loop.seeds > 0 then
		local seeds = {}
		for index, name in ipairs(loop.seeds) do seeds[index] = describe(name) end
		out("   seeded as raw: " .. table.concat(seeds, ", "))
	end
	for _, entry in ipairs(loop.steps) do
		local step = input.by_id[entry.id]
		out(("   %s %s = %s"):format(entry.rule and ("[" .. entry.rule .. "]") or "[source]",
			output_text(step), ingredients_text(step)))
	end
end
out()
out("== Raw materials (" .. #raw_list .. ", plus " .. #result.seeded .. " loop seeds)")
for _, name in ipairs(raw_list) do out(describe(name) .. "  (" .. name .. ")") end
for _, name in ipairs(result.seeded) do out(describe(name) .. "  (" .. name .. ", loop seed)") end

local function write(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
end
write(out_dir .. "/report.txt", table.concat(lines, "\n") .. "\n")

------------------------------------------------------------------------------
-- index.html
------------------------------------------------------------------------------
local json_null = {}
local function json(value)
	if value == json_null then return "null" end
	local kind = type(value)
	if kind == "string" then
		return '"' .. value:gsub('[%c"\\<>&]', function(c)
			return ("\\u%04x"):format(c:byte())
		end) .. '"'
	end
	if kind == "number" then return tostring(value) end
	if kind == "boolean" then return value and "true" or "false" end
	if value == nil then return "null" end
	local parts = {}
	if #value > 0 or next(value) == nil then
		for index, item in ipairs(value) do parts[index] = json(item) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do parts[#parts + 1] = json(key) .. ":" .. json(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local rows = {}
for _, id in ipairs(result.order) do
	local step, info, meta = input.by_id[id], result.steps[id], input.meta[id]
	rows[#rows + 1] = {meta.area_label, meta.tier or json_null, info.depth, info.steps,
		output_text(step), ingredients_text(step, info.chosen), basics_text(info.basics),
		notes(step), info.depth > 1 and chain_text(id) or "", id}
end
local op_rows = {}
for _, entry in ipairs(operations) do
	local op, cost = entry.op, entry.cost
	local parts = {}
	for index, item in ipairs(entry.list) do parts[index] = entry_text(item, cost.chosen[index]) end
	op_rows[#op_rows + 1] = {input.area_label(op.profession), op.tier, cost.depth, cost.steps,
		op.operation .. " " .. op.id, table.concat(parts, " + "), basics_text(cost.basics)}
end
local loop_rows = {}
for _, loop in ipairs(result.loops) do
	local names, list, seeds = {}, {}, {}
	for index, name in ipairs(loop.items) do names[index] = describe(name) end
	for index, name in ipairs(loop.seeds) do seeds[index] = describe(name) end
	for _, entry in ipairs(loop.steps) do
		local step = input.by_id[entry.id]
		list[#list + 1] = {entry.rule or "source", output_text(step) .. " = " ..
			ingredients_text(step)}
	end
	loop_rows[#loop_rows + 1] = {table.concat(names, ", "), table.concat(seeds, ", "), list}
end
local raw_rows = {}
for _, name in ipairs(raw_list) do raw_rows[#raw_rows + 1] = describe(name) .. " (" .. name .. ")" end
for _, name in ipairs(result.seeded) do
	raw_rows[#raw_rows + 1] = describe(name) .. " (" .. name .. ", loop seed)"
end
local depth_rows = {}
for _, area in ipairs(area_list) do
	local cells = {area}
	for value = 1, top do cells[#cells + 1] = per_area_depth[area][value] or 0 end
	depth_rows[#depth_rows + 1] = cells
end
local all_cells = {"All"}
for value = 1, top do all_cells[#all_cells + 1] = per_depth[value] or 0 end
depth_rows[#depth_rows + 1] = all_cells
local rules = {}
for index, rule in ipairs(chains.RULES) do rules[index] = {rule.id, rule.text} end

local data = json({rows = rows, ops = op_rows, loops = loop_rows, raw = raw_rows,
	depths = depth_rows, top = top, loop_back = loop_back, areas = area_list, legend = LEGEND, rules = rules,
	source = "commit " .. commit .. ": " .. #input.steps .. " recipes, " ..
		#dump.operations .. " enchants and upgrades"})

local template = assert(io.open(here .. "/page.html", "rb"))
local page = template:read("*a")
template:close()
local start, finish = page:find("/*DATA*/null", 1, true)
assert(start, "page.html lacks the data marker")
page = page:sub(1, start - 1) .. data .. page:sub(finish + 1)
write(out_dir .. "/index.html", page)

print(("r57 chains: %d recipes, deepest %d, %d loops, %d seeds, %d enchants and upgrades -> %s"):format(
	#input.steps, top, #result.loops, #result.seeded, #dump.operations, out_dir))
