-- List mobs_redo api.lua citations and the first code line at each target.
-- Run from the repository root, for example:
--   rg -l 'api\.lua:[0-9]' docs AGENTS.md BACKLOG.md mods/*/grug_* \
--     --glob '*.md' --glob '*.lua' | \
--     xargs tools/bin/lua51 tools/docs/check_api_citations.lua

local API_PATH = "mods/ENTITIES/mobs/api.lua"

local function read_lines(path)
	local handle, err = io.open(path, "r")
	if not handle then
		error(path .. ": " .. tostring(err))
	end
	local lines = {}
	for line in handle:lines() do
		lines[#lines + 1] = line
	end
	handle:close()
	return lines
end

local function trim(line)
	return (line:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function first_code_line(lines, target)
	for number = target, #lines do
		local line = trim(lines[number])
		if line ~= "" and not line:match("^%-%-") then
			return number, line
		end
	end
	return nil, "<past end of file>"
end

local function is_other_api(source, line)
	return line:find("mcl_mobs/api.lua:", 1, true)
		or line:find("mcl_armor/api.lua:", 1, true)
		or line:find("sfinv/api.lua:", 1, true)
		or source == "docs/research/lord_of_the_test.md"
end

if #arg == 0 then
	error("pass Markdown and Lua source files to inspect")
end

local api_lines = read_lines(API_PATH)
local count = 0

for index = 1, #arg do
	local source = arg[index]
	local source_lines = read_lines(source)
	for source_number = 1, #source_lines do
		local line = source_lines[source_number]
		if not is_other_api(source, line) then
			local offset = 1
			while true do
				local first, last, target = line:find("api%.lua:(%d+)", offset)
				if not first then break end
				local code_number, code = first_code_line(api_lines, tonumber(target))
				io.write(string.format("%s:%d api.lua:%s -> %s:%s %s\n",
					source, source_number, target, API_PATH,
					tostring(code_number or target), code))
				count = count + 1
				offset = last + 1
			end
		end
	end
end

io.write(string.format("TOTAL %d mobs api.lua citation(s)\n", count))
