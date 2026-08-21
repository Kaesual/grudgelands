-- WP40 T5-0 engine-seam probe -- the counting VoxelManip proxy (contract 10.12).
-- Disposable: this file is injected into a generated world's game tree by
-- tools/wp40/t5_probe/run_t5_probe.sh and is never shipped with the game.
--
-- THIS IS THE ONLY FILE IN THE PACKAGE PERMITTED TO TOUCH THE RAW MAPGEN
-- VoxelManip OBJECT.  The raw object is captured as an upvalue of the
-- forwarding closures and is never stored under any key of the returned table,
-- so payload/mapgen.lua cannot reach it: the sandbox's debug whitelist is
-- gethook / traceback / upvalueid / sethook / debug only
-- (reference_projects/luanti/src/script/cpp_api/s_security.cpp:186-192), with no
-- getupvalue and no getfenv on a C-created closure that would hand it back.
--
-- One entry per method of
-- reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:499-518 -- all
-- eighteen.  The ten the probe may call (contract 10.11) forward to the real
-- object and, per call, increment a named counter and add a core.get_us_time()
-- delta to a per-method total.  The other eight raise immediately, so an
-- accidental call is a loud failure (abort A-11) rather than an uncounted one.
--
-- Registration order at l_vmanip.cpp:500-517 is read_from_map, initialize,
-- get_data, set_data, get_node_at, set_node_at, write_to_map, update_map,
-- update_liquids, calc_lighting, set_lighting, get_light_data, set_light_data,
-- get_param2_data, set_param2_data, was_modified, get_emerged_area, close.
-- The two lists below partition exactly that set.

local FORWARDED = {
	"get_data",
	"set_data",
	"get_param2_data",
	"set_param2_data",
	"get_light_data",
	"set_light_data",
	"calc_lighting",
	"set_lighting",
	"update_liquids",
	"get_emerged_area",
}

local FORBIDDEN = {
	"write_to_map",
	"read_from_map",
	"initialize",
	"close",
	"update_map",
	"was_modified",
	"get_node_at",
	"set_node_at",
}

-- Three positional arguments cover every forwarded method:
--   get_data(buffer), get_param2_data(buffer), get_light_data(buffer)  -- 1
--   set_data(t), set_param2_data(t), set_light_data(t)                 -- 1
--   update_liquids(), get_emerged_area()                               -- 0
--   calc_lighting(pmin, pmax, propagate_shadow)                        -- 3
--   set_lighting({day=, night=}, pmin, pmax)                           -- 3
-- A fourth argument is rejected rather than silently dropped.  Trailing nils
-- are harmless: every C body decides by lua_istable / lua_isboolean on a fixed
-- stack index (l_vmanip.cpp:97, :219-222, :245-247, :264), never by lua_gettop.
--
-- At most two results are returned by any forwarded method: get_emerged_area
-- pushes MinEdge and MaxEdge (l_vmanip.cpp:377-387); every other one pushes a
-- single table or nothing.
local function wrap(raw)
	local ops = {}
	local op_us = {}
	local proxy = {ops = ops, op_us = op_us}

	for index = 1, #FORWARDED do
		local name = FORWARDED[index]
		ops[name] = 0
		op_us[name] = 0
		proxy[name] = function(_, first, second, third, ...)
			if select("#", ...) > 0 then
				error("too many arguments to VoxelManip method: " .. name, 0)
			end
			local method = raw[name]
			local started = core.get_us_time()
			local result_a, result_b = method(raw, first, second, third)
			local spent = core.get_us_time() - started
			ops[name] = ops[name] + 1
			op_us[name] = op_us[name] + spent
			return result_a, result_b
		end
	end

	for index = 1, #FORBIDDEN do
		local name = FORBIDDEN[index]
		ops[name] = 0
		op_us[name] = 0
		proxy[name] = function()
			-- Level 0: the message is the exact contract fragment, with no
			-- "file:line:" prefix in front of it.
			error("forbidden VoxelManip method: " .. name, 0)
		end
	end

	return proxy
end

return {
	wrap = wrap,
	forwarded = FORWARDED,
	forbidden = FORBIDDEN,
}
