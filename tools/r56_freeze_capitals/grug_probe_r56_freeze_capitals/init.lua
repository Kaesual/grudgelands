-- Round 56 FREEZE-CAPITALS disposable probe (tools/r56_freeze_capitals/run.sh;
-- never shipped). Emerges Highcourt's civic core (its buildings, the hall's
-- floor bands, braziers and hangings and the chapel's belfry are templates
-- now) and Dawnmere's pad, counts every node name inside each and logs the
-- counts; run.sh compares the building nodes with the blueprints. Then it
-- shuts the server down.
local function log(text) core.log("action", "[r56capitals] " .. text) end

local function count(label, minp, maxp, done)
	log(label .. " region " .. core.pos_to_string(minp) .. " " .. core.pos_to_string(maxp))
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
		for _, name in ipairs(names) do log(label .. " count " .. name .. " " .. counts[name]) end
		log(label .. " emerged in " ..
			string.format("%.1f", (core.get_us_time() - started) / 1e6) .. " s")
		done()
	end)
end

core.register_on_mods_loaded(function()
	core.after(3, function()
		local jobs = {}
		local a = grug_core.settlement_socket_anchor("highcourt")
		if a then
			jobs[#jobs + 1] = {"highcourt", {x = a.x - 49, y = a.y - 3, z = a.z - 49},
				{x = a.x + 49, y = a.y + 41, z = a.z + 49}}
		else
			log("highcourt has no anchor")
		end
		for _, start in ipairs(grug_core.start_identities()) do
			if start.race_id == "human" then
				local s = start.anchor
				jobs[#jobs + 1] = {"dawnmere", {x = s.x - 63, y = s.y - 2, z = s.z - 63},
					{x = s.x + 63, y = s.y + 24, z = s.z + 63}}
			end
		end
		local index = 0
		local function next_job()
			index = index + 1
			local job = jobs[index]
			if not job then
				log("done")
				core.request_shutdown("r56capitals probe done", false, 0)
				return
			end
			count(job[1], job[2], job[3], next_job)
		end
		next_job()
	end)
end)
