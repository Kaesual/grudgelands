-- Round 82 lane CAPITAL portable test: the six capitals are byte-identical to
-- the base of the round.
--
--   A. every capital blueprint (the civic core and every district plot, whole:
--      cells, bounds, palette, reference, clear_to, landmarks and sockets) and
--      its kit row (id, kind, district, role, schema) hash exactly as on the
--      round's base 7bb0cec0 (`reference.txt`, captured by `dump.lua` there),
--      in the same order; a second build of each answers the same.
--
-- Prints the CPU seconds of each capital's construction (its kit and the
-- first build of every blueprint), and per capital the template parses and
-- tree generations of the kit and of building every blueprint twice (the
-- dump's work): a before/after comparison, never a gate.
--
-- Usage (repo root): luajit tools/r82_capital/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- A. the identity ---------------------------------------------------------------
-- The cost counters: every template parse and every tree generation, by the
-- capital being dumped (the dump builds one capital after the other).
local counts, current = {}, nil
local real_dofile = dofile
local function counter(field)
	if current then counts[current][field] = counts[current][field] + 1 end
end
rawset(_G, "dofile", function(path)
	local result = real_dofile(path)
	if path:match("/templates%.lua$") then
		return function(...)
			local M = result(...)
			local parse = M.parse_template
			M.parse_template = function(...) counter("parse") return parse(...) end
			return M
		end
	elseif path:match("/tree_templates%.lua$") then
		return function(...)
			local T = result(...)
			local tree = T.tree
			T.tree = function(...) counter("tree") return tree(...) end
			return T
		end
	elseif path:match("/r7_capital_blueprint%.lua$") then
		local kit = result.kit
		result.kit = function(key)
			current = key
			counts[key] = {parse = 0, tree = 0}
			return kit(key)
		end
	end
	return result
end)
local dump = dofile(repo .. "/tools/r82_capital/dump.lua")
local reference = {}
for line in io.lines(repo .. "/tools/r82_capital/reference.txt") do
	reference[#reference + 1] = line
end
local lines, _, seconds = dump.dump(repo)
rawset(_G, "dofile", real_dofile)
local differ = {}
for index = 1, math.max(#lines, #reference) do
	if lines[index] ~= reference[index] then
		differ[#differ + 1] = "  now: " .. tostring(lines[index]) .. "\n  was: " ..
			tostring(reference[index])
	end
end
if #differ > 0 then print(table.concat(differ, "\n")) end
check(#differ == 0, #differ .. " of " .. #reference .. " blueprints differ from the base")
check(#lines == 316, "316 blueprints (" .. #lines .. ")")
local total = 0
for _, key in ipairs(dump.CAPITALS) do
	print(string.format("  %-12s %.3f s, %d template parses, %d tree generations", key,
		seconds[key], counts[key].parse, counts[key].tree))
	total = total + seconds[key]
end
print(string.format("  construction %.3f s in all", total))

print("r82_capital portable test: PASS (" .. checks .. " checks)")
