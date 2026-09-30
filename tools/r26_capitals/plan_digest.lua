-- Round 27 wall fixes (review follow-up): a digest of the six capital plans
-- per seed, to show a change leaves the plans alone (LuaJIT, no engine).
--
--   luajit tools/r26_capitals/plan_digest.lua <repo> seed [seed ...]
--
-- One line per seed and capital: the SHA-256 of the capital's layout
-- payload (outline, gates, wall with its walk and flags, turrets, squares,
-- plots) and its streets' centrelines and levels, then the planner's
-- statistics (every number and string of plan.stats outside the timings,
-- with junction_wet and junction_wall also summed as junction_all), and
-- last the planner seconds of each capital and their sum (timing: compare,
-- never a target).
local repo = arg[1]
assert(repo and arg[2], "usage: plan_digest.lua <repo> seed [seed ...]")
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local W = dofile(here .. "/world.lua")(repo)
for i = 2, #arg do
	local seed = arg[i]
	local run = W.plan(seed)
	local texts = W.planner.split(run.text .. "\n")
	local total = 0
	for _, key in ipairs(run.order) do
		local plan = run.plans[key]
		local parts = {texts[plan.anchor.id]}
		for _, r in ipairs(plan.streets) do
			for k = 1, #r.X do parts[#parts + 1] = ("%.4f,%.4f,%.4f"):format(r.X[k], r.Z[k], r.R[k] or 0) end
		end
		local sha = W.sha256(table.concat(parts, "\n")):gsub(".", function(c)
			return ("%02x"):format(c:byte())
		end)
		local keys, st = {}, plan.stats
		for k, v in pairs(st) do
			if (type(v) == "number" or type(v) == "string") and k ~= "junction_wet" and k ~= "junction_wall" then
				keys[#keys + 1] = k
			end
		end
		table.sort(keys)
		local out = {}
		for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. tostring(st[k]) end
		out[#out + 1] = "junction_all=" .. ((st.junction_wet or 0) + (st.junction_wall or 0))
		local secs = st.t and st.t.all_tries or 0
		total = total + secs
		print(("%s\t%s\t%s\t%s\twet=%d wall=%d\t%.3f"):format(seed, key, sha, table.concat(out, " "),
			st.junction_wet or 0, st.junction_wall or 0, secs))
	end
	print(("%s\tTOTAL\t%.3f"):format(seed, total))
end
