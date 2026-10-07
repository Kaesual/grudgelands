-- The failure mode of the chunk refinement (Round 41 ruling 8), emerge
-- environment: a failed refinement never stops the server. The chunk keeps
-- the engine's terrain -- the R7 writer changes the VoxelManip only after
-- every check and puts the engine's bytes back if a later engine call fails
-- (r6_settlement.lua) -- and the failure goes to the severe-error helper
-- (grug_core/severe.lua): one [GRUG-SEVERE] log line with the chunk, the
-- failing voxel and its node name, and a red chat message once per chunk.
-- Only the engine path (r7_mapgen.lua) runs through here; the seed fleet and
-- the fixtures call the writer directly, so a failure still fails them.
--
--   local run = dofile(wp40 .. "/degrade.lua")(severe, name_of_cid)
--   run(refine, vmanip, minp, maxp) -> true, or false after a report
return function(severe, name_of_cid)
	local function position_text(pos)
		if type(pos) ~= "table" then return tostring(pos) end
		return ("(%s,%s,%s)"):format(tostring(pos.x), tostring(pos.y),
			tostring(pos.z))
	end

	local function report_failure(minp, maxp, err)
		local message = tostring(err)
		local first = message:match("^[^\n]*")
		local chunk = position_text(minp)
		local details = ("minp=%s maxp=%s error=%s"):format(chunk,
			position_text(maxp), first)
		-- The adapter names the content id of a failing voxel; its node name
		-- is only known here.
		local cid = tonumber(first:match(" cid=(%d+)"))
		local ok, node = pcall(name_of_cid, cid)
		if cid and ok and type(node) == "string" then
			details = details .. " node=" .. node
		end
		severe.report("mapgen", "the map chunk at " .. chunk ..
			" was generated without its refinement (plain terrain there)", details,
			"mapgen:" .. chunk)
		if message ~= first then
			core.log("error", "grug_mapgen: refinement failure trace: " .. message)
		end
	end

	return function(refine, vmanip, minp, maxp)
		local ok, err = pcall(refine, vmanip, minp, maxp)
		if not ok then report_failure(minp, maxp, err) end
		return ok
	end
end
