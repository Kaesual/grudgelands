-- Writes or checks tools/web_data/web_data.json (README.md next to this file).
--
--   luajit tools/web_data/export.lua [REPO]           regenerate the file
--   luajit tools/web_data/export.lua [REPO] --check   exit 1 when it is stale
--
-- REPO defaults to the current directory.

local root, mode = ".", "write"
for _, value in ipairs(arg or {}) do
	if value == "--check" then
		mode = "check"
	else
		root = value
	end
end

local web_data = dofile(root .. "/tools/web_data/build.lua")
local path = root .. "/tools/web_data/web_data.json"
local text = web_data.encode(web_data.build(root))

if mode == "check" then
	local handle = io.open(path, "rb")
	local committed = handle and handle:read("*a")
	if handle then handle:close() end
	if committed ~= text then
		print("web_data.json is stale: run luajit tools/web_data/export.lua")
		os.exit(1)
	end
	print("web_data.json is current (" .. #text .. " bytes)")
	return
end

local handle = assert(io.open(path, "wb"))
handle:write(text)
handle:close()
print("wrote " .. path .. " (" .. #text .. " bytes)")
