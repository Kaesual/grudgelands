-- Round 49 lane HASH: a top view of the decorations, trees and gathering
-- sources of a 3 x 3 chunk area through the seed fleet's harness
-- (tools/seed_fleet/runtime.lua), to look for patterns in the placement
-- (grids, diagonals, runs) before and after a change. Per chunk column the
-- chunk holding the ground and the ones below and above it are planned and
-- written; per node column the highest written node that is not air gives
-- one letter:
--   T trunk or wood, L leaves, G gathering source, P plant (grass, fern,
--   flower, shrub ...), W water, . ground.
--
--   luajit tools/r49_hash/topview.lua REPO SEED X Z > view.txt
--   python3 -I tools/r49_hash/topview_png.py view.txt view.png
--
-- REPO is the checkout whose mapgen and harness run; X, Z any node of the
-- centre chunk column.
local repo, seed = assert(arg[1], "usage: topview.lua REPO SEED X Z"), arg[2]
local cx, cz = tonumber(arg[3]), tonumber(arg[4])
assert(seed and cx and cz, "usage: topview.lua REPO SEED X Z")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)

local function letter(name)
	if name == "air" then return nil end
	if name:find("water", 1, true) then return "W" end
	if name:find("^grug_gathering:") or name:find("_source$") then return "G" end
	if name:find("leaves", 1, true) or name:find("needles", 1, true) or
			name:find("hanging_moss", 1, true) then return "L" end
	if name:find("tree$") or name:find("_base$") or name:find("_branch$") or
			name:find("_twig$") or name:find("_quarter$") or name:find("_stem$") or
			name == "default:apple" then return "T" end
	if name:find("grass_", 1, true) or name:find("fern", 1, true) or
			name:find("flower", 1, true) or name:find("shrub", 1, true) or
			name:find("junglegrass", 1, true) or name:find("papyrus", 1, true) or
			name:find("reeds", 1, true) or name:find("cattails", 1, true) or
			name:find("moss_carpet", 1, true) or name:find("bone_pile", 1, true) or
			name:find("cactus", 1, true) or name:find("^flowers:") then return "P" end
	return "."
end

local ox0, oz0 = R.origin(cx) - 80, R.origin(cz) - 80
local SIZE = 240
local top, top_y = {}, {}
for gz = 0, 2 do
	for gx = 0, 2 do
		local ox, oz = ox0 + gx * 80, oz0 + gz * 80
		local ground = R.origin(R.ground_at(ox + 40, oz + 40))
		for _, y0 in ipairs({ground - 80, ground, ground + 80}) do
			local minp = {x = ox, y = y0, z = oz}
			local maxp = {x = ox + 79, y = y0 + 79, z = oz + 79}
			local vm = R.new_vm(minp)
			local plan, generation = R.built.session.plan_slice(minp, maxp)
			R.built.writer.apply(vm, minp, maxp, plan, generation)
			local data = vm.written.data or vm.native.data
			for z = minp.z, maxp.z do
				for x = minp.x, maxp.x do
					for y = maxp.y, minp.y, -1 do
						local index = (z - minp.z + 16) * 12544 + (y - minp.y + 16) * 112 +
							(x - minp.x + 16) + 1
						local mark = letter(R.fake.get_name_from_content_id(data[index]))
						if mark then
							local key = (z - oz0) * SIZE + (x - ox0) + 1
							if not top_y[key] or y > top_y[key] then
								top[key], top_y[key] = mark, y
							end
							break
						end
					end
				end
			end
		end
	end
end
print(("topview seed=%s origin=%d,%d size=%d"):format(seed, ox0, oz0, SIZE))
for z = SIZE - 1, 0, -1 do
	local row = {}
	for x = 0, SIZE - 1 do row[#row + 1] = top[z * SIZE + x + 1] or " " end
	print(table.concat(row))
end
