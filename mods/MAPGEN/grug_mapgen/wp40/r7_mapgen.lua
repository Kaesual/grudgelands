-- Emerge-environment half of the R7 cutover. This file is the sole registered
-- mapgen script and owns the sole generated callback and VM transaction.

local IPC_KEY = "grug_mapgen:r7_runtime_v1"
local function fail(message)
	error("WP40 R7 emerge: " .. message, 0)
end
local function exact_payload(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("IPC payload differs")
	end
	local allowed = {schema = true, manifest_sha256 = true,
		full_seed = true, projection = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unexpected IPC field " .. tostring(key)) end
	end
	if value.schema ~= "grug_wp40_r7_ipc_v1" or
		type(value.manifest_sha256) ~= "string" or
		#value.manifest_sha256 ~= 64 or type(value.full_seed) ~= "string" or
		type(value.projection) ~= "table" then
		fail("IPC identity differs")
	end
	return value
end

local modpath = core.get_modpath("grug_mapgen")
local default_path = core.get_modpath("default")
local gathering_path = core.get_modpath("grug_gathering")
if type(modpath) ~= "string" or type(default_path) ~= "string" or
		type(gathering_path) ~= "string" then
	fail("required mod path differs")
end
local wp40 = modpath .. "/wp40"
local native = dofile(wp40 .. "/r7_native.lua")
native.validate_emerge()
local payload = exact_payload(core.ipc_get(IPC_KEY))
local catalog = dofile(gathering_path .. "/catalog.lua")
local runtime = dofile(wp40 .. "/r7_runtime.lua")(core, wp40,
	default_path .. "/schematics", payload.projection, catalog)
local built = runtime.build(native.identities(), payload.manifest_sha256)
if built.full_seed ~= payload.full_seed then fail("main/emerge seed differs") end

core.register_on_generated(function(vmanip, minp, maxp, blockseed)
	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	if type(result) ~= "string" then fail("writer result differs") end
end)
