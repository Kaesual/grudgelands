-- Compact coverage for generic R6 hash framing and arithmetic.

return function(repo)
	local path = repo .. "/mods/MAPGEN/grug_mapgen/wp40/"
	local hash_factory = dofile(path .. "r6_hash.lua")
	local captured, calls = false, 0
	local digest = string.char(0, 0, 0, 5, 255, 255, 255, 254) ..
		string.rep(string.char(0), 24)
	local hash = hash_factory(function(bytes)
		captured, calls = bytes, calls + 1
		return digest
	end)
	local function check(value, message)
		if not value then error("resource hash primitive: " .. message, 0) end
	end
	local function rejected(callback, prefix, message)
		local ok, failure = pcall(callback)
		check(not ok and type(failure) == "string" and
			string.find(failure, prefix, 1, true) == 1, message)
	end
	local function frame(value)
		local bytes = type(value) == "number" and
			(value == 0 and "0" or string.format("%.0f", value)) or value
		return tostring(#bytes) .. ":" .. bytes
	end

	local domains, domain_set = hash.domains(), {}
	for index = 1, #domains do domain_set[domains[index]] = true end
	check(domain_set.resource_root_shuffle_v1, "resource shuffle domain is absent")
	check(not domain_set.resource_root_rank_v1, "obsolete resource rank domain remains")
	local fields = {0, -31012, 31012, "", "a\0b", -0, 9007199254740991}
	local result = hash.digest_count("resource_root_shuffle_v1", "seed\0bytes",
		fields, 7)
	local expected = frame("grug_wp40_r6_hash_v1") ..
		frame("resource_root_shuffle_v1") .. frame("seed\0bytes")
	for index = 1, 7 do expected = expected .. frame(fields[index]) end
	check(result == digest and captured == expected and calls == 1,
		"counted canonical framing differs")
	check(hash.frame(-17) == "3:-17" and hash.frame("a\0b") == "3:a\0b",
		"public frame differs")

	local words = hash.words(digest)
	check(words[1] == 5 and words[2] == 4294967294, "big-endian digest words differ")
	for _, denominator in ipairs({1, 2, 97, 12000, 48000}) do
		local reduced = hash.reduce_words(words[1], words[2], denominator)
		check(reduced == hash.reduce_digest(digest, denominator) and
			reduced >= 0 and reduced < denominator, "digest reduction differs")
	end
	local budget, numerator, denominator, base, remainder =
		hash.budget(4096, 3, 12000, 5, 4, digest)
	check(numerator == 61440 and denominator == 48000 and base == 1 and
		remainder == 13440 and budget >= base and budget <= base + 1,
		"budget arithmetic differs")
	local exact = hash.budget(4096, 1, 4096, 1, 1, digest)
	check(exact == 1, "exact budget differs")
	check(hash.less_bytes("a", "a\0") and not hash.less_bytes("a\0", "a"),
		"byte ordering differs")
	check(hash.hex(string.char(0, 128, 255)) == "0080ff", "hex encoding differs")

	rejected(function() hash.digest_count("resource_root_rank_v1", "", {}, 0) end,
		"fail_hash:", "obsolete domain was accepted")
	rejected(function() hash.digest_count("resource_root_shuffle_v1", 0, {}, 0) end,
		"fail_hash:", "non-byte seed was accepted")
	rejected(function()
		hash.digest_count("resource_root_shuffle_v1", "", {[2] = 1}, 2)
	end, "fail_hash:", "field hole was accepted")
	rejected(function() hash.digest_count("resource_root_shuffle_v1", "", {}, 33) end,
		"fail_hash:", "field bound was accepted")
	rejected(function() hash.reduce_words(0, 0, 0) end,
		"fail_bound:", "zero denominator was accepted")
	rejected(function() hash.budget(4097, 1, 1, 1, 1, digest) end,
		"fail_bound:", "eligible bound was accepted")
	for _, value in ipairs({false, "", string.rep("x", 31), string.rep("x", 33)}) do
		local bad = hash_factory(function() return value end)
		rejected(function()
			bad.digest_count("resource_root_shuffle_v1", "", {}, 0)
		end, "fail_hash:", "invalid SHA result was accepted")
	end

	return table.concat({"schema\tgrug_wp40_resource_hash_primitives_v2",
		"domains\t" .. #domains, "framing\tcount7/binary/bounds",
		"arithmetic\twords/reduce/budget/byte_order/hex",
		"resource_hash_primitives\tok"}, "\n") .. "\n"
end
