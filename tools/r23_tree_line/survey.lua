-- Coarse survey: land altitude per biome (pre-design facts).
local repo, seed, step = arg[1], arg[2] or "4242", tonumber(arg[3] or "32")
local W = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, seed)
local ps = W.planner_source
local by_biome, all = {}, {}
local t0 = os.clock()
for z = -3340, 3340, step do
	for x = -3740, 3740, step do
		local water, _, zone, biome, _, ty, wy = ps.column_values_at(x, z)
		if water == "land" and biome and not (wy and wy > ty) then
			local list = by_biome[biome] or {}
			by_biome[biome] = list
			list[#list + 1] = ty
			all[#all + 1] = ty
		end
	end
end
local function q(list, p) return list[math.max(1, math.floor(#list * p))] end
local names = {}
for b in pairs(by_biome) do names[#names + 1] = b end
table.sort(names)
table.sort(all)
local function share(list, y)
	local n = 0
	for i = 1, #list do if list[i] >= y then n = n + 1 end end
	return n / #list
end
print(("seed %s step %d land %d  t=%.1fs"):format(seed, step, #all, os.clock() - t0))
print(("ALL med %d p90 %d p99 %d max %d  >=160 %.3f >=220 %.3f >=280 %.3f"):format(
	q(all, .5), q(all, .9), q(all, .99), all[#all], share(all, 160), share(all, 220), share(all, 280)))
for _, b in ipairs(names) do
	local l = by_biome[b]
	table.sort(l)
	print(("%-22s n=%6d med %4d p90 %4d p99 %4d max %4d  >=160 %.3f >=220 %.3f >=280 %.3f"):format(
		b, #l, q(l, .5), q(l, .9), q(l, .99), l[#l], share(l, 160), share(l, 220), share(l, 280)))
end
