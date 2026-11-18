-- Round 82 lane CAPITAL: the identity dump of the six capitals.
--
-- Builds every capital kit the game builds (`wp40/r7_capital_blueprint.lua`
-- `M.kit`): the civic core and every district plot, in the kit's order, and
-- hashes the WHOLE blueprint of each (cells with node, param2 and metadata,
-- bounds, palette, reference, clear_to, every landmark and every socket field
-- the game reads at run time: waystones, NPCs, stations), canonically
-- serialised with sorted keys. Each blueprint is built twice and both builds
-- must serialise alike (the lazy settlement rebuilds a plot through the same
-- builder and refuses a different answer).
--
-- `dump(repo)` returns the lines `<capital> <id> <kind> <district> <role>
-- <schema> <sha256>` in kit order, the canonical texts by line index and the
-- CPU seconds per capital of its kit and of the first build of each blueprint
-- (the construction cost, a before/after comparison only).
--
-- Usage (repo root), one capital set to a file and, optionally, every
-- canonical text into a directory for a diff:
--   luajit tools/r82_capital/dump.lua [REPO] [OUT_FILE] [TEXT_DIR]
local M = {}

local CAPITALS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
	"kezamba"}
M.CAPITALS = CAPITALS

local function canonical(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, out)
			out[#out + 1] = "="
			canonical(value[key], out)
			out[#out + 1] = ";\n"
		end
		out[#out + 1] = "}"
	elseif kind == "number" then
		out[#out + 1] = string.format("n%.17g", value)
	elseif kind == "string" then
		out[#out + 1] = string.format("%q", value)
	elseif kind == "boolean" then
		out[#out + 1] = value and "T" or "F"
	else
		out[#out + 1] = "<" .. kind .. ">"
	end
	return out
end
M.canonical = canonical

function M.dump(repo, keys)
	_G.core = _G.core or {}
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_capital_blueprint.lua")
	local lines, texts = {}, {}
	local seconds = {}
	local function add(key, id, kind, district, role, schema, build)
		local started = os.clock()
		local blueprint = build()
		seconds[key] = seconds[key] + (os.clock() - started)
		local text = table.concat(canonical(blueprint, {}))
		if table.concat(canonical(build(), {})) ~= text then
			error(key .. " " .. id .. ": a second build differs from the first", 0)
		end
		lines[#lines + 1] = table.concat({key, id, kind, district, role, schema,
			common.hex(sha(text))}, " ")
		texts[#lines] = text
	end
	for _, key in ipairs(keys or CAPITALS) do
		local started = os.clock()
		local kit = source.kit(key)
		seconds[key] = os.clock() - started
		add(key, "core", "core", "-", "-", kit.core.schema, kit.core.build)
		for _, plot in ipairs(kit.plots) do
			add(key, plot.id, plot.kind, plot.district, plot.role, plot.schema, plot.build)
		end
	end
	return lines, texts, seconds
end

if arg and arg[0] and arg[0]:match("dump%.lua$") then
	local repo, out, text_dir = arg[1] or ".", arg[2], arg[3]
	local lines, texts = M.dump(repo)
	local body = table.concat(lines, "\n") .. "\n"
	if out then
		local file = assert(io.open(out, "wb"))
		file:write(body)
		file:close()
	else
		io.write(body)
	end
	if text_dir then
		for index, line in ipairs(lines) do
			local key, id = line:match("^(%S+) (%S+)")
			local file = assert(io.open(text_dir .. "/" .. key .. "." .. id .. ".txt", "wb"))
			file:write(texts[index])
			file:close()
		end
	end
end

return M
