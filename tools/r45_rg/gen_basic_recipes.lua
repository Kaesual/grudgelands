-- Round 45 lane RG: converts the base commit's engine grid routes into the
-- Basic recipe catalog mods/PLAYER/grug_jobs/basic_recipes.lua (ingredient
-- lists, round45-plan.md §3 and §4.2).
--
--   luajit tools/r45_rg/gen_basic_recipes.lua [REPO]           write the file
--   luajit tools/r45_rg/gen_basic_recipes.lua [REPO] --check   exit 1 when stale
--   luajit tools/r45_rg/gen_basic_recipes.lua [REPO] --report  print the counts
--
-- Input: tools/r45_rg/corpus_base.lua, the engine catalog of the base commit
-- c48eb681 as tools/r45_rg/dump_corpus.sh dumped it (every "normal" route
-- with its output count and slots, the profession registry, the gear
-- families). Each route is one of:
--   profession  the engine side of a profession registry grid recipe: those
--               recipes are converted where they are registered (grug_jobs
--               station_nodes.lua, grug_cooking, grug_alchemy);
--   gear        an equipment output: gear moves to its profession
--               (grug_professions/base_recipes.lua, spec §2.23 and §2.34);
--   dropped     a route the ingredient-list model cannot express (DROPPED);
--   family      a loop-made route (stairs, slabs, walls): one row per
--               material, registry.lua makes the routes as the vendored loops
--               did;
--   basic       everything else: one ingredient list, the slot items counted
--               in the order they first appear; a multi-group token
--               ("group:dye,color_red") with exactly one member becomes that
--               item; shaped variants with the same list (mirrored shapes)
--               become one recipe.
local root, mode = ".", "write"
for _, value in ipairs(arg or {}) do
	if value == "--check" then mode = "check"
	elseif value == "--report" then mode = "report"
	else root = value end
end

local corpus = dofile(root .. "/tools/r45_rg/corpus_base.lua")
local target = root .. "/mods/PLAYER/grug_jobs/basic_recipes.lua"

-- The routes the model drops, with the reason (reported).
local DROPPED = {
	["default:book_written"] = "copies a written book's text through a craft " ..
		"callback; ingredients with metadata never count (round45-plan.md §3)",
}

local function signature_of(tokens)
	local counts, order = {}, {}
	for _, token in ipairs(tokens) do
		if token ~= "" then
			if not counts[token] then order[#order + 1] = token end
			counts[token] = (counts[token] or 0) + 1
		end
	end
	local keys = {}
	for index, token in ipairs(order) do keys[index] = token .. "*" .. counts[token] end
	table.sort(keys)
	return table.concat(keys, "+"), order, counts
end

-- Profession grid recipes: output plus ingredient signature.
local profession = {}
for _, row in ipairs(corpus.registry) do
	if row.station == "grid" then
		profession[row.output_name .. "|" .. signature_of(row.flat_inputs or {})] = true
	end
end

local resolved = {}
local function resolve(token)
	if token:match("^group:.+,") then
		local members = corpus.groups[token] or {}
		assert(#members == 1, token .. " has " .. #members .. " members")
		resolved[token] = members[1]
		return members[1]
	end
	return token
end

local counts = {engine = #corpus.engine, profession = 0, gear = 0, dropped = 0,
	family = 0, basic = 0, merged = 0}
local plain, seen = {}, {}
local by_output = {}
-- get_all_craft_recipes("") answers the hand with an empty record.
local routes = {}
for _, route in ipairs(corpus.engine) do
	if route.output ~= "" then routes[#routes + 1] = route end
end
counts.engine = #routes
for _, route in ipairs(routes) do
	local tokens = {}
	for index, token in ipairs(route.items) do tokens[index] = resolve(token) end
	local signature, order, amount = signature_of(tokens)
	local key = route.output .. "|" .. signature
	if profession[route.output .. "|" .. signature_of(route.items)] then
		counts.profession = counts.profession + 1
	elseif corpus.gear[route.output] then
		counts.gear = counts.gear + 1
	elseif DROPPED[route.output] then
		counts.dropped = counts.dropped + 1
	elseif seen[key] then
		assert(seen[key].count == route.count, key .. " differs in count")
		counts.merged = counts.merged + 1
	else
		local ingredients = {}
		for index, token in ipairs(order) do
			local group = token:match("^group:(.+)$")
			ingredients[index] = group and {group = group, n = amount[token]} or
				{item = token, n = amount[token]}
		end
		local row = {output = route.output, count = route.count,
			ingredients = ingredients, signature = signature}
		seen[key] = row
		plain[#plain + 1] = row
		by_output[route.output] = by_output[route.output] or {}
		table.insert(by_output[route.output], row)
	end
end

-- One plain row of `output` made of exactly `n` of `item` (and count), or nil.
local function single(output, item, n, count)
	for _, row in ipairs(by_output[output] or {}) do
		if #row.ingredients == 1 and row.ingredients[1].item == item and
				row.ingredients[1].n == n and row.count == count and not row.family then
			return row
		end
	end
end

-- Loop-made families: a material joins only with every route of its family,
-- exactly as the vendored loop registers them (BASE/stairs/init.lua
-- register_stair, register_slab, register_stair_inner, register_stair_outer;
-- BASE/walls).
local stairs, walls = {}, {}
local subs = {}
for output in pairs(by_output) do
	local sub = output:match("^stairs:slab_(.+)$")
	if sub then subs[#subs + 1] = sub end
end
table.sort(subs)
for _, sub in ipairs(subs) do
	local slab_rows = by_output["stairs:slab_" .. sub]
	local item = #slab_rows == 1 and #slab_rows[1].ingredients == 1 and
		slab_rows[1].ingredients[1].item
	if item then
		local stair, slab = "stairs:stair_" .. sub, "stairs:slab_" .. sub
		local wanted = {{stair, item, 6, 8}, {slab, item, 3, 6},
			{"stairs:stair_inner_" .. sub, item, 6, 7},
			{"stairs:stair_outer_" .. sub, item, 4, 6},
			{item, stair, 4, 3}, {item, slab, 2, 1}}
		local rows = {}
		for _, shape in ipairs(wanted) do
			rows[#rows + 1] = single(shape[1], shape[2], shape[3], shape[4])
		end
		if #rows == #wanted then
			for _, row in ipairs(rows) do row.family = true end
			stairs[#stairs + 1] = {sub, item}
		end
	end
end
for output, rows in pairs(by_output) do
	if output:match("^walls:") and #rows == 1 and #rows[1].ingredients == 1 and
			rows[1].ingredients[1].n == 6 and rows[1].count == 6 then
		rows[1].family = true
		walls[#walls + 1] = {output, rows[1].ingredients[1].item}
	end
end
table.sort(walls, function(a, b) return a[1] < b[1] end)

local basic = {}
for _, row in ipairs(plain) do
	if row.family then counts.family = counts.family + 1
	else basic[#basic + 1] = row end
end
counts.basic = #basic
table.sort(basic, function(a, b)
	if a.output ~= b.output then return a.output < b.output end
	return a.signature < b.signature
end)

local function quote(value) return ("%q"):format(value) end
local lines = {
	"-- The Basic recipe catalog (Round 45, round45-plan.md §3 and §4.2): every",
	"-- profession-free recipe as an ingredient list. Converted from the engine",
	"-- grid routes of the base commit by tools/r45_rg/gen_basic_recipes.lua",
	"-- (its --check compares); edit it as data from",
	"-- now on and rerun nothing. registry.lua registers each row in the",
	"-- \"basic\" area and makes the loop-made families below.",
	"return {",
	"\trecipes = {",
}
for _, row in ipairs(basic) do
	local parts = {}
	for _, entry in ipairs(row.ingredients) do
		parts[#parts + 1] = entry.group and ("{group = %s, n = %d}"):format(
			quote(entry.group), entry.n) or ("{item = %s, n = %d}"):format(
			quote(entry.item), entry.n)
	end
	lines[#lines + 1] = ("\t\t{output = %s, count = %d, ingredients = {%s}},"):format(
		quote(row.output), row.count, table.concat(parts, ", "))
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\t-- {subname, block}: 8 stairs and 7 inner stairs from 6 blocks, 6 outer"
lines[#lines + 1] = "\t-- stairs from 4, 6 slabs from 3, back to 3 blocks from 4 stairs and to"
lines[#lines + 1] = "\t-- 1 block from 2 slabs."
lines[#lines + 1] = "\tstairs = {"
for _, row in ipairs(stairs) do
	lines[#lines + 1] = ("\t\t{%s, %s},"):format(quote(row[1]), quote(row[2]))
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\t-- {wall, block}: 6 walls from 6 blocks."
lines[#lines + 1] = "\twalls = {"
for _, row in ipairs(walls) do
	lines[#lines + 1] = ("\t\t{%s, %s},"):format(quote(row[1]), quote(row[2]))
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "}"
local text = table.concat(lines, "\n") .. "\n"

if mode == "report" then
	print(("engine grid routes %d: profession %d, gear %d, dropped %d, " ..
		"mirrored duplicates %d, loop-made %d (%d stair materials, %d walls), " ..
		"basic rows %d"):format(counts.engine, counts.profession, counts.gear,
		counts.dropped, counts.merged, counts.family, #stairs, #walls, counts.basic))
	local tokens = {}
	for token, item in pairs(resolved) do tokens[#tokens + 1] = token .. " -> " .. item end
	table.sort(tokens)
	print("multi-group tokens resolved: " .. #tokens)
	for _, line in ipairs(tokens) do print("  " .. line) end
	for output, reason in pairs(DROPPED) do print("dropped " .. output .. ": " .. reason) end
	return
end
if mode == "check" then
	local handle = io.open(target, "rb")
	local committed = handle and handle:read("*a")
	if handle then handle:close() end
	if committed ~= text then
		error("basic_recipes.lua is stale: run luajit tools/r45_rg/gen_basic_recipes.lua", 0)
	end
	print("basic_recipes.lua is current (" .. counts.basic .. " rows)")
	return
end
local handle = assert(io.open(target, "wb"))
handle:write(text)
handle:close()
print("wrote " .. target .. " (" .. counts.basic .. " rows)")
