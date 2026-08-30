-- Final-byte LuaJIT/PUC-5.1 parity KAT for the disabled R6 transaction.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local rows = dofile(repo .. "/tools/wp40/r6/micro_kat_fixture.lua")(repo)
	table.sort(rows, common.less_bytes)
	local body = table.concat(rows)
	return body .. "output_sha256\t" .. common.hex(common.new_sha256()(body)) .. "\n"
end
