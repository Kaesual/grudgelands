-- Round 58 lane HALLS2: one seed's capital plans as data for the review page
-- (build_pages.py), without the engine: the capital planner through
-- tools/r26_capitals/world.lua, as a world's first boot plans it. Prints a
-- Lua chunk returning {seed = <seed>, [<capital key>] = {core_y = <the
-- ground at the anchor>, plots = {{id, x, z, turns, y}, ...}}}, positions
-- relative to the capital's anchor, in the planner's plot order.
--
-- Usage (repo root): luajit tools/r58_halls/plan_layout.lua REPO SEED
local repo, seed = arg[1] or ".", tonumber(arg[2] or "1")
_G.core = _G.core or {}
local W = dofile(repo .. "/tools/r26_capitals/world.lua")(repo)
local run = W.plan(seed)
local out = {("return {seed = %d,"):format(seed)}
local keys = {}
for key in pairs(run.plans) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do
	local plan = run.plans[key]
	local anchor = plan.anchor
	local core_y = math.floor(run.session.terrain_height_at(anchor.x, anchor.z) + 0.5)
	out[#out + 1] = ("\t%s = {core_y = %d, plots = {"):format(key, core_y)
	for _, p in ipairs(plan.plots) do
		if not p.stand_in then
			out[#out + 1] = ("\t\t{id = %q, x = %d, z = %d, turns = %d, y = %d},"):format(
				p.id, p.x, p.z, p.turns, p.y)
		end
	end
	out[#out + 1] = "\t}},"
end
out[#out + 1] = "}"
print(table.concat(out, "\n"))
