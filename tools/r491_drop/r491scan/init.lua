-- Client-side scan for tools/r491_drop/repro.sh (a client mod of the
-- disposable reproduction client only, never shipped). Once a second it casts
-- vertical rays over a 13 x 13 node square under the hovering local player
-- and logs, per object the rays meet, the mean point of its hits: where the
-- CLIENT draws that object (its selection box, the box a click points at).
-- Times are core.get_us_time(), the host's monotonic clock the server's probe
-- logs too.
local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < 1 then return end
	acc = 0
	local lp = core.localplayer
	if not lp then return end
	local p = lp:get_pos()
	local seen, order = {}, {}
	for ix = -32, 32 do
		for iz = -32, 32 do
			local a = {x = p.x + ix * 0.2, y = p.y - 1, z = p.z + iz * 0.2}
			local b = {x = a.x, y = p.y - 16, z = a.z}
			for hit in core.raycast(a, b, true, false) do
				if hit.type == "node" then break end
				if hit.type == "object" and hit.id then
					local s = seen[hit.id]
					if not s then
						s = {n = 0, x = 0, z = 0, y = hit.intersection_point.y}
						seen[hit.id] = s
						order[#order + 1] = hit.id
					end
					s.n = s.n + 1
					s.x = s.x + hit.intersection_point.x
					s.z = s.z + hit.intersection_point.z
					break
				end
			end
		end
	end
	local t = core.get_us_time() / 1e6
	for _, id in ipairs(order) do
		local s = seen[id]
		core.log("action", ("[r491c] t=%.2f id=%d x=%.3f y=%.3f z=%.3f n=%d"):format(t, id,
			s.x / s.n, s.y, s.z / s.n, s.n))
	end
end)
