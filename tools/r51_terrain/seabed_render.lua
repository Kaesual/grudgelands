-- Round 51 TERRAIN T3: a top view of the seabed growth the real writer lays
-- in a block of mapchunks (seabed_png.py turns it into an image).
--
--   luajit tools/r51_terrain/seabed_render.lua REPO SEED OUT X Z [N]
--
-- Writes the N x N mapchunks (default 3) from the one holding (X, Z), at
-- chunk height -32, and one line per column, north first: "kind depth" with
-- kind land, coral, kelp, seagrass or bare.
local repo, seed, out, cx, cz, n = arg[1], arg[2], arg[3], tonumber(arg[4]),
	tonumber(arg[5]), tonumber(arg[6] or "3")
assert(repo and seed and out and cx and cz, "usage: seabed_render.lua REPO SEED OUT X Z [N]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local S = R.built.zones_session
local ox0, oz0 = R.origin(cx), R.origin(cz)
local kinds = {}
for j = 0, n - 1 do
	for i = 0, n - 1 do
		local ox, oz = ox0 + 80 * i, oz0 + 80 * j
		local minp = {x = ox, y = -32, z = oz}
		local vm = R.new_vm(minp)
		local plan, generation = R.built.session.plan_slice(minp,
			{x = ox + 79, y = 47, z = oz + 79})
		R.built.writer.apply(vm, minp, {x = ox + 79, y = 47, z = oz + 79}, plan, generation)
		local data = vm.written.data or vm.native.data
		for z = oz, oz + 79 do
			for x = ox, ox + 79 do
				local class, _, _, _, depth = S.water_query_at(x, z)
				local kind, d = "land", 0
				if class then
					d = depth
					local y = 1 - depth
					kind = "bare"
					if y >= -32 then
						local idx = (z - oz + 16) * 12544 + (y + 32 + 16) * 112 + (x - ox + 16) + 1
						local name = R.fake.get_name_from_content_id(data[idx])
						if name:find("^default:coral_") then kind = "coral"
						elseif name == "default:sand_with_kelp" then kind = "kelp"
						elseif name:find("^grug_mapgen:seagrass_") then kind = "seagrass" end
					end
				end
				kinds[x .. "," .. z] = kind .. " " .. d
			end
		end
	end
end
local file = assert(io.open(out, "w"))
file:write(("%d %d\n"):format(80 * n, 80 * n))
for z = oz0 + 80 * n - 1, oz0, -1 do
	for x = ox0, ox0 + 80 * n - 1 do file:write(kinds[x .. "," .. z], "\n") end
end
file:close()
