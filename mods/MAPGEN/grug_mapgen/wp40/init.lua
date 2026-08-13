-- Shared pure WP40 foundation loader. T2 will supply authoritative geometry
-- and enable IPC publication; T1 deliberately publishes no placeholder data.

return function(directory)
	if type(directory) ~= "string" then
		error("WP40 foundation directory argument missing", 0)
	end
	local foundation = {
		enabled = false,
		disabled_reason = "T2 compiled geometry is not installed",
		schemas = dofile(directory .. "/schemas.lua"),
		canonical = dofile(directory .. "/canonical.lua"),
		deterministic = dofile(directory .. "/deterministic.lua"),
		validation = dofile(directory .. "/validation.lua"),
		index128 = dofile(directory .. "/index128.lua"),
		seed_corpus = dofile(directory .. "/seed_corpus.lua"),
	}
	local compiler_module = dofile(directory .. "/compiler.lua")(directory)
	local compile_authority = compiler_module.compile
	if type(compile_authority) ~= "function" then
		error("WP40 private compiler authority unavailable", 0)
	end
	-- Consumers capture this wrapper during initialization. Replacing any later
	-- public table field cannot replace the authority closed over here.
	function foundation.compile(...)
		return compile_authority(...)
	end
	function foundation.raw_sha256_from_core(core_api)
		if type(core_api) ~= "table" or type(core_api.sha256) ~= "function" then
			error("WP40 core.sha256 API unavailable", 0)
		end
		return function(data) return core_api.sha256(data, true) end
	end
	return foundation
end
