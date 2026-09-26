-- LuaJIT trace tuning for the mapgen (Round 22 D63). Changes only how LuaJIT
-- compiles, never a computed value; a no-op without LuaJIT (plain Lua 5.1).
--
-- Why: the noise functions (terrain_field / zone_field simplex, domain warp)
-- keep so many floats live that a side trace from one of their branch guards
-- fails in the assembler ("NYI: register coalescing too complex"). LuaJIT
-- then retries that side trace on EVERY later exit of the guard until the
-- exit's 8-bit counter saturates (hotexit .. 255), which measured ~200,000
-- aborted traces per 50 mapchunks: a third of planning time went to the JIT
-- compiler and the interpreter. A higher `hotexit` makes each hopeless exit
-- cost ~55 attempts instead of ~245; working side traces start after 200
-- exits instead of 10. Measured (seed 15140735923413111218, 98 owners):
-- plan -20 %, chunk callback -16 %, main-environment construction -15 %.
return function()
	local jit_api = rawget(_G, "jit")
	if type(jit_api) == "table" and type(jit_api.opt) == "table" and
			type(jit_api.opt.start) == "function" then
		jit_api.opt.start("hotexit=200")
	end
end
