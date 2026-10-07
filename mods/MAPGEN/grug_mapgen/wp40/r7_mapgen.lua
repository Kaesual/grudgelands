-- Emerge-environment half of the R7 cutover. This file is the sole registered
-- mapgen script and owns the sole generated callback and VM transaction.

local IPC_KEY = "grug_mapgen:r7_runtime_v1"
-- LuaJIT side-exit tuning for this environment (see ../jit_tuning.lua).
dofile(core.get_modpath("grug_mapgen") .. "/jit_tuning.lua")()
local function fail(message)
	error("WP40 R7 emerge: " .. message, 0)
end
local function plain_engine_position(value, label)
	if type(value) ~= "table" then fail(label .. " differs") end
	local metatable = getmetatable(value)
	if metatable ~= nil and (type(vector) ~= "table" or
			metatable ~= vector.metatable) then
		fail(label .. " metatable differs")
	end
	local count = 0
	for key in pairs(value) do
		if key ~= "x" and key ~= "y" and key ~= "z" then
			fail(label .. " field differs")
		end
		count = count + 1
	end
	if count ~= 3 or rawget(value, "x") == nil or rawget(value, "y") == nil or
			rawget(value, "z") == nil then
		fail(label .. " fields differ")
	end
	return {x = rawget(value, "x"), y = rawget(value, "y"),
		z = rawget(value, "z")}
end
local function exact_payload(value)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail("IPC payload differs")
	end
	local allowed = {schema = true, manifest_sha256 = true,
		full_seed = true, projection = true, water_layout = true, road_layout = true,
		capital_layout = true, prepared_blueprints = true}
	for key in pairs(value) do
		if not allowed[key] then fail("unexpected IPC field " .. tostring(key)) end
	end
	if value.schema ~= "grug_wp40_r7_ipc_v1" or
		type(value.manifest_sha256) ~= "string" or
		#value.manifest_sha256 ~= 64 or type(value.full_seed) ~= "string" or
		type(value.projection) ~= "table" or
		type(value.water_layout) ~= "string" or value.water_layout == "" or
		type(value.road_layout) ~= "string" or value.road_layout == "" or
		type(value.capital_layout) ~= "string" or value.capital_layout == "" or
		type(value.prepared_blueprints) ~= "table" then
		fail("IPC identity differs")
	end
	return value
end

local modpath = core.get_modpath("grug_mapgen")
local default_path = core.get_modpath("default")
local gathering_path = core.get_modpath("grug_gathering")
local core_path = core.get_modpath("grug_core")
if type(modpath) ~= "string" or type(default_path) ~= "string" or
		type(gathering_path) ~= "string" or type(core_path) ~= "string" then
	fail("required mod path differs")
end
-- The severe-error helper the main environment loads as grug_core.severe.
local severe = dofile(core_path .. "/severe.lua")
local wp40 = modpath .. "/wp40"
local native = dofile(wp40 .. "/r7_native.lua")
native.validate_emerge()
local payload = exact_payload(core.ipc_get(IPC_KEY))
local catalog = dofile(gathering_path .. "/catalog.lua")
local runtime = dofile(wp40 .. "/r7_runtime.lua")(core, wp40,
	default_path .. "/schematics", payload.projection, catalog,
	payload.water_layout, payload.road_layout, payload.capital_layout,
	payload.prepared_blueprints)
local built = runtime.build(native.identities(), payload.manifest_sha256)
if built.full_seed ~= payload.full_seed then fail("main/emerge seed differs") end
local native_baseline = core.settings and
	type(core.settings.get_bool) == "function" and
	core.settings:get_bool("grug_mapgen_r8_native_baseline", false) or false

local water_level = tonumber(core.get_mapgen_setting("water_level"))
if not water_level then fail("water level differs") end
local air_chunks = dofile(wp40 .. "/air_chunks.lua")(built.writer_bounds, water_level)
local function get_heightmap() return core.get_mapgen_object("heightmap") end

-- The chunk's refinement: plan and write the one R7 transaction.
local function refine(vmanip, minp, maxp)
	minp = plain_engine_position(minp, "generated minp")
	maxp = plain_engine_position(maxp, "generated maxp")
	-- Native air above everything the writer can place: the transaction would
	-- change nothing (air_chunks.lua), so it is not run.
	if air_chunks.untouched(minp, maxp, get_heightmap) then return end
	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	if type(result) ~= "string" then fail("writer result differs") end
end

-- A failed refinement never stops the server (Round 41 ruling 8): the chunk
-- keeps the engine's terrain (the writer changes the VoxelManip only after
-- every check and puts the engine's bytes back if a later engine call fails,
-- r6_settlement.lua), and the failure goes to the severe-error helper: one
-- [GRUG-SEVERE] log line with the chunk and the failing voxel, and a red chat
-- message once per chunk. Only this engine path degrades; the seed fleet and
-- the fixtures call the writer directly, so a failure still fails them.
local function position_text(pos)
	if type(pos) ~= "table" then return tostring(pos) end
	return ("(%s,%s,%s)"):format(tostring(pos.x), tostring(pos.y), tostring(pos.z))
end
local function report_failure(minp, maxp, err)
	local message = tostring(err)
	local first = message:match("^[^\n]*")
	local chunk = position_text(minp)
	local details = ("minp=%s maxp=%s error=%s"):format(chunk,
		position_text(maxp), first)
	local cid = tonumber(first:match(" cid=(%d+)"))
	local node = cid and core.get_name_from_content_id(cid)
	if node then details = details .. " node=" .. node end
	severe.report("mapgen", "the map chunk at " .. chunk ..
		" was generated without its refinement (plain terrain there)", details,
		"mapgen:" .. chunk)
	if message ~= first then
		core.log("error", "grug_mapgen: refinement failure trace: " .. message)
	end
end

core.register_on_generated(function(vmanip, minp, maxp, blockseed)
	-- Measurement-only comparison mode: retain the untouched v7 VM bytes so
	-- the external R8 cave checker can prove the component the real writer saw.
	if native_baseline then return end
	local ok, err = pcall(refine, vmanip, minp, maxp)
	if not ok then report_failure(minp, maxp, err) end
end)
