-- Round 56 FREEZE-TOWNS disposable probe (tools/r56_freeze_towns/run.sh;
-- never shipped). Emerges the pads of two start towns built from building
-- templates (Dawnmere and Sunscar: the most building-bound content moved into
-- their templates), counts every node name inside each pad and logs the
-- counts; run.sh compares the building nodes with the blueprint. Then it shuts
-- the server down.
local TOWNS = {human = "dawnmere", orc = "sunscar"}
local function log(text) core.log("action", "[r56freeze] " .. text) end

core.register_on_mods_loaded(function()
	core.after(3, function()
		local pending = 0
		for _, start in ipairs(grug_core.start_identities()) do
			local town = TOWNS[start.race_id]
			if town then
				pending = pending + 1
				local a = start.anchor
				local minp = {x = a.x - 63, y = a.y - 2, z = a.z - 63}
				local maxp = {x = a.x + 63, y = a.y + 24, z = a.z + 63}
				log(town .. " anchor " .. a.x .. " " .. a.y .. " " .. a.z)
				local started = core.get_us_time()
				core.emerge_area(minp, maxp, function(_, _, remaining)
					if remaining > 0 then return end
					local vm = core.get_voxel_manip(minp, maxp)
					local e1, e2 = vm:get_emerged_area()
					local area = VoxelArea(e1, e2)
					local data = vm:get_data()
					local counts = {}
					for z = minp.z, maxp.z do
						for y = minp.y, maxp.y do
							for x = minp.x, maxp.x do
								local name = core.get_name_from_content_id(data[area:index(x, y, z)])
								counts[name] = (counts[name] or 0) + 1
							end
						end
					end
					local names = {}
					for name in pairs(counts) do names[#names + 1] = name end
					table.sort(names)
					for _, name in ipairs(names) do
						log(town .. " count " .. name .. " " .. counts[name])
					end
					log(town .. " emerged in " ..
						string.format("%.1f", (core.get_us_time() - started) / 1e6) .. " s")
					pending = pending - 1
					if pending == 0 then
						log("done")
						core.request_shutdown("r56freeze probe done", false, 0)
					end
				end)
			end
		end
	end)
end)
