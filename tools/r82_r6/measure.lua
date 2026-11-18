-- Round 82 lane R6: the per-chunk cost of the R6 planner and writer, before
-- and after (one run on the base, one on the branch; numbers are a
-- comparison, not a target). Builds the real runtime of one seed
-- (tools/seed_fleet/runtime.lua), then plans and writes each chunk named by
-- the "info cover" lines of a digest file (tools/r82_gen: the seed's sample
-- and dense chunks, in that order), once each, and prints per chunk the
-- plan and write seconds (os.clock), the surface rows the selectors
-- computed (memo hits not counted) and the content classifications, then
-- the totals.
--
--   luajit tools/r82_r6/measure.lua REPO SEED DIGEST_FILE
local repo, seed, digest_file = arg[1], arg[2], arg[3]
assert(repo and seed and digest_file, "usage: measure.lua REPO SEED DIGEST_FILE")

local chunks = {}
for line in io.lines(digest_file) do
	local x, y, z = line:match("^info cover (%-?%d+),(%-?%d+),(%-?%d+) ")
	if x then chunks[#chunks + 1] = {x = tonumber(x), y = tonumber(y), z = tonumber(z)} end
end
assert(#chunks > 0, "no chunk in " .. digest_file)

-- Count the rows the surface selectors compute: every selector the content
-- module builds is wrapped (a shared, memoised one calls through it).
local selections = 0
local saved_dofile = dofile
rawset(_G, "dofile", function(path)
	local chunk = saved_dofile(path)
	if type(path) ~= "string" or not path:match("/r6_content%.lua$") then return chunk end
	return function(...)
		local module = chunk(...)
		local new_selector = module.new_surface_selector
		module.new_surface_selector = function(...)
			local select = new_selector(...)
			return function(...)
				selections = selections + 1
				return select(...)
			end
		end
		return module
	end
end)
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
rawset(_G, "dofile", saved_dofile)

local function classified()
	return R.built.session.metrics().content.classify_calls
end
local plan_total, write_total, select_total, classify_total = 0, 0, 0, 0
print(("seed %s, %d chunks"):format(seed, #chunks))
for _, minp in ipairs(chunks) do
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local vm = R.new_vm(minp)
	local s0, c0 = selections, classified()
	local t0 = os.clock()
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	local t1 = os.clock()
	local s1 = selections
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local t2 = os.clock()
	local c2 = classified()
	plan_total, write_total = plan_total + t1 - t0, write_total + t2 - t1
	select_total = select_total + selections - s0
	classify_total = classify_total + c2 - c0
	print(("chunk %d,%d,%d plan=%.3f write=%.3f selections plan=%d write=%d classify=%d")
		:format(minp.x, minp.y, minp.z, t1 - t0, t2 - t1, s1 - s0, selections - s1, c2 - c0))
end
print(("total plan=%.2f write=%.2f selections=%d classify=%d"):format(plan_total,
	write_total, select_total, classify_total))
