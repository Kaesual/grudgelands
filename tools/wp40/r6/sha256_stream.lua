-- LuaJIT/OpenSSL streaming SHA-256 seam for large R6 evidence files.
-- The runner injects LuaJIT FFI as the global wp40_ffi before loading this file.

return function(injected_ffi)
	local ffi = injected_ffi
	if type(ffi) ~= "table" and type(ffi) ~= "userdata" then
		error("WP40 R6 SHA-256: injected LuaJIT FFI is unavailable", 0)
	end

	ffi.cdef([[
		typedef struct evp_md_ctx_st EVP_MD_CTX;
		typedef struct evp_md_st EVP_MD;
		EVP_MD_CTX *EVP_MD_CTX_new(void);
		void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
		const EVP_MD *EVP_sha256(void);
		int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const EVP_MD *type, void *impl);
		int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *data, size_t count);
		int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md,
			unsigned int *size);
	]])
	local crypto = ffi.load("crypto")
	local module = {}

	local function fail(message)
		error("WP40 R6 SHA-256: " .. message, 0)
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	function module.new()
		local context = crypto.EVP_MD_CTX_new()
		if context == nil then fail("EVP context allocation failed") end
		ffi.gc(context, crypto.EVP_MD_CTX_free)
		if crypto.EVP_DigestInit_ex(context, crypto.EVP_sha256(), nil) ~= 1 then
			fail("EVP digest initialization failed")
		end
		local finished = false
		local hasher = {}

		function hasher.update(bytes)
			if finished then fail("digest already finalized") end
			if type(bytes) ~= "string" then fail("digest update is not bytes") end
			if #bytes > 0 and crypto.EVP_DigestUpdate(context, bytes, #bytes) ~= 1 then
				fail("EVP digest update failed")
			end
			return hasher
		end

		function hasher.final_hex()
			if finished then fail("digest already finalized") end
			local output = ffi.new("unsigned char[32]")
			local output_size = ffi.new("unsigned int[1]")
			if crypto.EVP_DigestFinal_ex(context, output, output_size) ~= 1 or
					output_size[0] ~= 32 then
				fail("EVP digest finalization failed")
			end
			finished = true
			ffi.gc(context, nil)
			crypto.EVP_MD_CTX_free(context)
			return hex(ffi.string(output, 32))
		end

		return hasher
	end

	function module.file(path)
		if type(path) ~= "string" or path == "" then fail("file path is missing") end
		local file = assert(io.open(path, "rb"), "cannot open " .. path)
		local hasher = module.new()
		local byte_count = 0
		while true do
			local bytes = file:read(1024 * 1024)
			if not bytes then break end
			byte_count = byte_count + #bytes
			hasher.update(bytes)
		end
		assert(file:close())
		return hasher.final_hex(), byte_count
	end

	return module
end
