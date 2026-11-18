-- Round 82 lane BASE: compare two sets of seed fleet digests
-- (tools/seed_fleet/seed.lua digest mode), seed by seed.
--
--   luajit tools/r82_gen/compare.lua REFERENCE_DIR RUN_DIR SEEDS_FILE
--
-- For every seed of SEEDS_FILE it reads REFERENCE_DIR/<seed>.txt and
-- RUN_DIR/<seed>.txt and prints one line: "identical", or the first item that
-- differs (a layout, the roster, or a chunk with which of nodes, light and
-- meta differ) and how many items differ in all. Comment lines and "info"
-- lines (the coverage counters) are not compared; a different manifest
-- digest is printed as a note only (an identity of the contracts, not world
-- output). Exits 0 only when every seed is identical (otherwise it raises).
local ref_dir, run_dir, seeds_file = arg[1], arg[2], arg[3]
assert(ref_dir and run_dir and seeds_file,
	"usage: compare.lua REFERENCE_DIR RUN_DIR SEEDS_FILE")

-- {items = {{key, value}...}, manifest = string} of one digest file, or nil.
local function read(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local items, manifest = {}, nil
	for line in file:lines() do
		if line:find("^info manifest ") then
			manifest = line:sub(15)
		elseif line ~= "" and not line:find("^#") and not line:find("^info ") then
			local key, value
			local minp, fields, label = line:match("^chunk (%S+) (nodes=%S+ light=%S+ meta=%S+) (.*)$")
			if minp then
				key, value = "chunk " .. minp .. " (" .. label .. ")", fields
			elseif line:find("^FAIL ") then
				key, value = "FAIL", line:sub(6)
			else
				key, value = line:match("^(.-) (%S+)$")
				if not key then key, value = line, "" end
			end
			items[#items + 1] = {key, value}
		end
	end
	file:close()
	return {items = items, manifest = manifest}
end

-- What differs between two chunk field strings.
local function chunk_fields(a, b)
	local out = {}
	for _, name in ipairs({"nodes", "light", "meta"}) do
		local x, y = a:match(name .. "=(%S+)"), b:match(name .. "=(%S+)")
		if x ~= y then out[#out + 1] = name end
	end
	return table.concat(out, ", ")
end

local seeds = {}
for line in io.lines(seeds_file) do
	if line:match("^%d+$") then seeds[#seeds + 1] = line end
end
local identical = 0
for _, seed in ipairs(seeds) do
	local ref = read(ref_dir .. "/" .. seed .. ".txt")
	local run = read(run_dir .. "/" .. seed .. ".txt")
	local verdict
	if not ref then
		verdict = "no reference digest"
	elseif not run then
		verdict = "no digest written (the seed did not finish; see its log)"
	else
		local first, count = nil, 0
		local n = math.max(#ref.items, #run.items)
		for i = 1, n do
			local a, b = ref.items[i], run.items[i]
			if not a or not b or a[1] ~= b[1] or a[2] ~= b[2] then
				count = count + 1
				if not first then
					if a and b and a[1] == b[1] then
						first = a[1]:find("^chunk ") and
							(a[1] .. ": " .. chunk_fields(a[2], b[2]) .. " differ") or
							(a[1] .. " differs (" .. a[2]:sub(1, 16) .. " -> " .. b[2]:sub(1, 16) .. ")")
					elseif b and b[1] == "FAIL" then
						first = "FAIL " .. b[2]
					else
						first = ("item %d is %s, the reference has %s"):format(i,
							b and b[1] or "missing", a and a[1] or "nothing")
					end
				end
			end
		end
		if count == 0 then
			verdict = "identical"
			identical = identical + 1
		else
			verdict = ("differs: %s (%d of %d items differ)"):format(first, count, n)
		end
		if ref.manifest ~= run.manifest then
			verdict = verdict .. "; note: the manifest digest differs"
		end
	end
	print(("seed %s: %s"):format(seed, verdict))
end
print(("r82_gen compare: %d of %d seeds identical"):format(identical, #seeds))
io.stdout:flush()
if identical ~= #seeds then error("r82_gen compare: not identical", 0) end
