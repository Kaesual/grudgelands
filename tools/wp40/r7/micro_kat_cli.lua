-- Exactly one bounded final-byte R7 micro-KAT process.

local repo = assert(arg[1], "repository root required")
local output = assert(arg[2], "output path required")
local interpreter = assert(arg[3], "interpreter label required")
if (interpreter ~= "luajit" and interpreter ~= "puc51") or arg[4] ~= nil then
	error("micro-KAT argument population differs", 0)
end

local observed = { ["tools/wp40/r7/micro_kat_cli.lua"] = true }
local repo_prefix = repo .. "/"
local original_open, original_loadfile = io.open, loadfile
local function observe(path)
	if type(path) == "string" and path:sub(1, #repo_prefix) == repo_prefix then
		local relative = path:sub(#repo_prefix + 1)
		if relative == "" or relative:sub(1, 1) == "/" or
				relative:find("..", 1, true) then
			error("micro-KAT observed unsafe repository path", 0)
		end
		observed[relative] = true
	end
end
io.open = function(path, mode)
	if mode == nil or mode:sub(1, 1) == "r" then observe(path) end
	return original_open(path, mode)
end
local tracked_loadfile = function(path)
	observe(path)
	return original_loadfile(path)
end
rawset(_G, "loadfile", tracked_loadfile)
rawset(_G, "dofile", function(path)
	local chunk, message = tracked_loadfile(path)
	if not chunk then error(message, 2) end
	return chunk()
end)

local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local bytes = dofile(repo .. "/tools/wp40/r7/micro_kat.lua")(repo)
local body, claimed = bytes:match("^(.*)output_sha256\t([0-9a-f]+)\n$")
if not body or #claimed ~= 64 or
		common.hex(common.new_sha256()(body)) ~= claimed then
	error("WP40 R7 micro-KAT internal digest differs", 0)
end

local expected, expected_count = {}, 0
local function add_roster(path)
	if path == "" or path:sub(1, 1) == "/" or path:find("..", 1, true) or
			expected[path] then
		error("WP40 R7 micro-KAT input roster differs", 0)
	end
	expected[path], expected_count = true, expected_count + 1
end
observe(repo .. "/tools/wp40/r7/micro_inputs.txt")
for line in io.lines(repo .. "/tools/wp40/r7/micro_inputs.txt") do add_roster(line) end
observe(repo .. "/tools/wp40/r7/changed_production_lua.txt")
for line in io.lines(repo .. "/tools/wp40/r7/changed_production_lua.txt") do
	if not expected[line] then expected[line], expected_count = true, expected_count + 1 end
end
local missing, unexpected = {}, {}
for path in pairs(expected) do
	-- The shell is the reader/executor of itself; the interpreter observes every
	-- other declared byte, including this already-loaded CLI script.
	if path ~= "tools/wp40/r7/final_micro.sh" and not observed[path] then
		missing[#missing + 1] = path
	end
end
for path in pairs(observed) do
	if not expected[path] then unexpected[#unexpected + 1] = path end
end
table.sort(missing)
table.sort(unexpected)
if #missing ~= 0 or #unexpected ~= 0 then
	error("WP40 R7 micro-KAT exact input set differs missing=" ..
		table.concat(missing, ",") .. " unexpected=" ..
		table.concat(unexpected, ","), 0)
end
if expected_count <= 71 then error("WP40 R7 micro-KAT input population differs", 0) end
local probe = io.open(output, "rb")
if probe then probe:close(); error("WP40 R7 micro-KAT output exists", 0) end
local file = assert(io.open(output, "wb"))
assert(file:write(bytes)); assert(file:close())
io.write("WP40 R7 final micro PASS interpreter=", interpreter,
	" output_sha256=", claimed, "\n")
