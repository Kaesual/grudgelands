-- WP40 T2 focused regression for the OPTIONAL fixed-geometry load inside the
-- real mods/MAPGEN/grug_mapgen/wp40/compiler.lua. Nothing here re-implements
-- the loader: every case dofiles the production file and enters it through its
-- documented offline entry point with a temporary directory that mirrors a real
-- wp40 directory by symlink, so the whole captured trust chain runs.
--
-- Background: absence of the optional file used to be decided by matching the
-- ENGLISH strerror prose "No such file or directory". Luanti localizes strerror
-- (src/main.cpp -> init_gettext, 5.16.1 and submodule HEAD :792, 5.17.0 :794,
-- reaching setlocale(LC_ALL, "") at src/gettext.cpp:192/:223, identical across
-- those three), and Luanti 5.17.0 removed strerror from the secured loader
-- altogether (5.17.0 s_security.cpp:731-732).
--
-- Presence is decided by an open probe, and -- because the sandbox truncates
-- io.open to two results (sl_io_open: lua_call(L, with_mode ? 2 : 1, 2) then
-- "return 2"; 5.16.1 s_security.cpp:1062-1063, 5.17.0 :1112-1113, submodule
-- HEAD :1054-1055)
-- so the errno is ALWAYS nil in production -- by a core.get_dir_list listing
-- whenever no errno is available. These cases hold that mechanism in place,
-- including the production shape itself, driven through a fake engine core
-- installed across exactly the trust-capture seam.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match(
	"^/tmp/grudgelands%-wp40%-t2%-compiler%-optional%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

-- Captured before any case replaces io.open, so the harness never probes
-- through a stub it installed for the code under test.
local real_io_open = io.open
local real_os_execute = os.execute

local wp40_dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local compiler_path = wp40_dir .. "/compiler.lua"
local mirror = scratch .. "/wp40-mirror"
local impl_path = mirror .. "/geometry/compiler_impl.lua"
-- A modpath whose "/wp40" child IS the mirror, so a production instance
-- resolves its directory exactly the way compiler.lua does: from get_modpath.
local prod_root = scratch .. "/prod-modpath"
local prod_wp40 = prod_root .. "/wp40"

-- MEASURED interpreter divergence, and the reason this is not a bare
-- "== 0" check: PUC 5.1 returns the raw system() status (0, and 256 for exit
-- code 1) while LuaJIT 2.1 returns the 5.2 shape true, "exit", 0.
local function run(command)
	local first, _, code = real_os_execute(command)
	local succeeded = first == 0 or
		(first == true and (code == 0 or code == nil))
	assert(succeeded, "command failed: " .. command)
end

local function write_file(path, text)
	local handle = assert(real_io_open(path, "wb"))
	assert(handle:write(text))
	assert(handle:close())
end

local function read_file(path)
	local handle = assert(real_io_open(path, "rb"))
	local text = assert(handle:read("*a"))
	assert(handle:close())
	return text
end

local sha_cache = {}
local sha_counter = 0

local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end

local function raw_sha256(data)
	local cached = sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/sha-" .. sha_counter .. ".txt"
	write_file(input, data)
	run("sha256sum " .. input .. " > " .. output)
	local digest = from_hex(assert(read_file(output):match("^([0-9a-f]+)")))
	assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

-- A genuine wp40 directory: every sibling authority the compiler loads is the
-- real file, reached through a symlink, and only geometry/ is ours to control.
local function build_mirror()
	run("rm -rf " .. mirror)
	run("mkdir -p " .. mirror .. "/geometry")
	local links = {"canonical.lua", "deterministic.lua", "validation.lua",
		"schemas.lua", "compiled_schema.lua", "index128.lua", "seed_corpus.lua",
		"init.lua", "source", "validation"}
	for i = 1, #links do
		run("ln -s " .. wp40_dir .. "/" .. links[i] .. " " ..
			mirror .. "/" .. links[i])
	end
end

local source = dofile(wp40_dir .. "/source/catalog.lua")

local function source_vocabulary()
	local resources, grades, cultures, woods = {}, {}, {}, {}
	local assignments = source.semantics.race_region_assignments
	for i = 1, #assignments do
		local row = assignments[i]
		resources[row.g1], resources[row.g2] = true, true
		grades[row.g1], grades[row.g2] = "G1", "G2"
		cultures[row.cultural], woods[row.signature_wood] = true, true
	end
	local function keys(values)
		local result = {}
		for key in pairs(values) do result[#result + 1] = key end
		table.sort(result)
		return result
	end
	local resource_keys = keys(resources)
	local resource_rows = {}
	for i = 1, #resource_keys do
		resource_rows[i] = {key = resource_keys[i], scope = "regional",
			grade = grades[resource_keys[i]]}
	end
	return {resource_keys = resource_keys, resource_rows = resource_rows,
		cultural_keys = keys(cultures), wood_keys = keys(woods)}
end
local vocabulary = source_vocabulary()

-- Instantiate the real compiler against the mirror. io_open_stub, when given,
-- is installed only across the dofile, which is exactly when compiler.lua
-- captures io.open -- the same trust-capture seam production relies on.
local function instantiate(io_open_stub)
	local restore
	if io_open_stub ~= nil then
		restore = io.open
		io.open = io_open_stub
	end
	local loaded, factory = pcall(dofile, compiler_path)
	if restore ~= nil then io.open = restore end
	if not loaded then return false, factory end
	local built, module = pcall(factory, mirror)
	if not built then return false, module end
	return true, module
end

-- The PRODUCTION shape. rawget(_G, "core") is what makes compiler.lua choose
-- its production branch, and it is read at the same dofile that captures
-- io.open, so the fake core is installed across exactly that seam. It is left
-- installed across the factory call too, so the sibling authorities
-- (validation/t2_source.lua in particular) also load production-side, as they
-- do in the engine. get_modpath returns prod_root, whose "/wp40" child is a
-- symlink to the mirror, so `directory` is derived, never handed in.
local function build_prod_root()
	run("rm -rf " .. prod_root)
	run("mkdir -p " .. prod_root)
	run("ln -s " .. mirror .. " " .. prod_wp40)
end

local function production_core(listing)
	local seen = {calls = 0, path = "unset", want_dirs = "unset"}
	local core = {
		get_modpath = function(name)
			assert(name == "grug_mapgen", "unexpected mod name " .. tostring(name))
			return prod_root
		end,
		sha256 = function(data, raw)
			assert(raw == true, "the production SHA must be asked for raw bytes")
			return raw_sha256(data)
		end,
		get_dir_list = function(path, want_dirs)
			seen.calls = seen.calls + 1
			seen.path = path
			seen.want_dirs = want_dirs
			-- A fresh table each call, like the engine, so the loader cannot be
			-- passing a listing it mutated back to us.
			local copy = {}
			for i = 1, #listing do copy[i] = listing[i] end
			return copy
		end,
	}
	return core, seen
end

local function instantiate_production(core, io_open_stub)
	local previous_core = rawget(_G, "core")
	rawset(_G, "core", core)
	local restore
	if io_open_stub ~= nil then
		restore = io.open
		io.open = io_open_stub
	end
	local loaded, factory = pcall(dofile, compiler_path)
	if restore ~= nil then io.open = restore end
	if not loaded then
		rawset(_G, "core", previous_core)
		return false, factory
	end
	-- nil, not the mirror: a production instance must derive its directory from
	-- the captured get_modpath and must ignore the offline argument entirely.
	local built, module = pcall(factory, nil)
	rawset(_G, "core", previous_core)
	if not built then return false, module end
	return true, module
end

-- The production counterpart of geometry_unavailable(): there is no offline
-- adapter on a production instance, so the closed door is the real compile().
local function production_geometry_unavailable(module, core)
	assert(module.new_offline_test_adapter == nil,
		"the offline adapter leaked into a production instance")
	assert(type(module.compile) == "function", "production compile is missing")
	local previous_core = rawget(_G, "core")
	rawset(_G, "core", core)
	local ok, message = pcall(module.compile, "42", vocabulary)
	rawset(_G, "core", previous_core)
	assert(not ok, "compile succeeded although geometry is unavailable")
	assert(tostring(message):find("compiled_geometry_unavailable", 1, true),
		tostring(message))
	return true
end

-- "geometry unavailable exactly as today" is a positive statement: the module
-- instantiates, the offline adapter exists, and compile fails closed with the
-- unchanged compiled_geometry_unavailable message.
local function geometry_unavailable(module)
	assert(type(module.new_offline_test_adapter) == "function")
	local adapter = module.new_offline_test_adapter({raw_sha256 = raw_sha256})
	local ok, message = pcall(adapter.compile, "42", vocabulary)
	assert(not ok, "compile succeeded although geometry is unavailable")
	assert(tostring(message):find("compiled_geometry_unavailable", 1, true),
		tostring(message))
	return true
end

local function claims_absent(message)
	local text = tostring(message)
	return text:find("compiled_geometry_unavailable", 1, true) ~= nil
end

local valid_impl_source = [[
local module = {}
function module.compile(bindings, full_seed_string, wp43_vocabulary,
		canonicalize_compiled)
	return {
		marker = "grug_wp40_test_impl_ok",
		seed = full_seed_string,
		bindings_ok = type(bindings) == "table" and
			type(bindings.raw_sha256) == "function",
		vocabulary_ok = type(wp43_vocabulary) == "table",
		canonicalize_ok = type(canonicalize_compiled) == "function",
	}
end
return module
]]

print("t2-compiler-optional-load v1")

-- Case 1: the optional file is genuinely absent (geometry/ exists and is
-- empty, exactly like the shipped tree). The compiler must instantiate and
-- geometry must stay unavailable.
build_mirror()
local ok1, module1 = instantiate(nil)
assert(ok1, tostring(module1))
print("case1-absent instantiate=ok geometry-unavailable=" ..
	tostring(geometry_unavailable(module1)))

-- Case 2: the file is present and valid. Its compile must be adopted and the
-- module contract validation must pass.
build_mirror()
write_file(impl_path, valid_impl_source)
local ok2, module2 = instantiate(nil)
assert(ok2, tostring(module2))
local adapter2 = module2.new_offline_test_adapter({raw_sha256 = raw_sha256})
local produced = adapter2.compile("42", vocabulary)
assert(type(produced) == "table", "adopted compile returned no table")
assert(produced.marker == "grug_wp40_test_impl_ok", "a foreign compile ran")
print("case2-present-valid adopted=true seed=" .. tostring(produced.seed) ..
	" bindings=" .. tostring(produced.bindings_ok) ..
	" vocabulary=" .. tostring(produced.vocabulary_ok) ..
	" canonicalize=" .. tostring(produced.canonicalize_ok))

-- Case 3: the file is present but does not parse. That must be loud, must name
-- the file, and must never be reported as absence.
build_mirror()
write_file(impl_path, "return {compile = function( end\n")
local ok3, message3 = instantiate(nil)
assert(not ok3, "a syntax error in the fixed geometry compiler was swallowed")
local names_file3 = tostring(message3):find("compiler_impl.lua", 1, true) ~= nil
assert(names_file3, "the load failure does not name the file: " ..
	tostring(message3))
assert(not claims_absent(message3), "a syntax error was reported as absence")
print("case3-syntax-error raised=true names-file=" .. tostring(names_file3) ..
	" absent-claimed=" .. tostring(claims_absent(message3)))

-- Case 4: the file is present and raises while executing. Same requirement,
-- and the raised message must survive verbatim (level 0, no wrapper text).
build_mirror()
write_file(impl_path, "error(\"grug_wp40_test_impl_boom\", 0)\n")
local ok4, message4 = instantiate(nil)
assert(not ok4, "a runtime error in the fixed geometry compiler was swallowed")
local verbatim4 = tostring(message4) == "grug_wp40_test_impl_boom"
assert(verbatim4, "the raised message did not survive: " .. tostring(message4))
assert(not claims_absent(message4), "a runtime error was reported as absence")
print("case4-runtime-error raised=true message-verbatim=" ..
	tostring(verbatim4) ..
	" absent-claimed=" .. tostring(claims_absent(message4)))

-- Case 5a: the decisive locale case. The probe fails with a GERMAN missing-file
-- message and, like the engine sandbox, with NO errno third return. The real
-- production loader must still treat this as ordinary absence.
build_mirror()
local german_missing = impl_path .. ": Datei oder Verzeichnis nicht gefunden"
local ok5a, module5a = instantiate(function() return nil, german_missing end)
assert(ok5a, tostring(module5a))
print("case5a-localized-enoent-no-errno instantiate=ok geometry-unavailable=" ..
	tostring(geometry_unavailable(module5a)))

-- Case 5b: same German message, with the errno a standalone interpreter does
-- supply. ENOENT is still absence.
local ok5b, module5b = instantiate(function() return nil, german_missing, 2 end)
assert(ok5b, tostring(module5b))
print("case5b-localized-enoent-errno2 instantiate=ok geometry-unavailable=" ..
	tostring(geometry_unavailable(module5b)))

-- Case 5c: a GERMAN permission failure with EACCES. A file that is there but
-- unreadable is a real I/O failure and must be loud, not absence.
local german_denied = impl_path .. ": Keine Berechtigung"
local ok5c, message5c = instantiate(function()
	return nil, german_denied, 13
end)
assert(not ok5c, "a non-ENOENT open failure was treated as absence")
local carries5c = tostring(message5c):find("Keine Berechtigung", 1, true) ~= nil
assert(carries5c, "the I/O failure lost its message: " .. tostring(message5c))
assert(not claims_absent(message5c), "an I/O failure was reported as absence")
print("case5c-localized-eacces-errno13 raised=true carries-message=" ..
	tostring(carries5c) ..
	" absent-claimed=" .. tostring(claims_absent(message5c)))

-- Case 5d: the static half of the locale proof. The EXECUTABLE text of
-- compiler.lua (comments removed, and the strip is proven complete) searches no
-- string at all, so no message in any language can steer the decision.
local function code_only(text)
	local lines = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		if not line:match("^%s*%-%-") then lines[#lines + 1] = line end
	end
	local code = table.concat(lines, "\n")
	assert(not code:find("--", 1, true),
		"compiler.lua carries an inline comment; the strip is incomplete")
	return code
end
local compiler_code = code_only(read_file(compiler_path))
local forbidden = {"No such file or directory", "Datei oder Verzeichnis",
	"Failed reading file", "strerror", "find(", "match(", "gmatch("}
for i = 1, #forbidden do
	assert(not compiler_code:find(forbidden[i], 1, true),
		"compiler.lua code contains " .. forbidden[i])
end
print("case5d-static-no-prose-match searches=0 forbidden-hits=0")

-- Case 6: the module contract check keeps its exact wording. The file is
-- present and loads, but exports no compile function.
build_mirror()
write_file(impl_path, "return {compile = 5}\n")
local ok6, message6 = instantiate(nil)
assert(not ok6, "an invalid module contract was accepted")
local unchanged6 = tostring(message6) ==
	"WP40 compiler: fixed geometry compiler has an invalid module contract"
assert(unchanged6, "the contract message changed: " .. tostring(message6))
print("case6-invalid-contract raised=true message-unchanged=" ..
	tostring(unchanged6))

-- Cases 7*: the PRODUCTION shape, which no case above reaches. Under mod
-- security sl_io_open truncates io.open to two results, so the errno is ALWAYS
-- nil there and case5c's errno guard is inert in exactly the environment that
-- matters. With production true the decision falls to core.get_dir_list, and
-- these cases pin that it is the LISTING and not the message that decides.
build_prod_root()

-- Case 7a: EACCES with NO errno -- the exact shape a secured server produces
-- for a file that is there but cannot be opened -- with the file PRESENT in
-- the listing. It must be loud, must carry the open message, must not be
-- reported as absence, and the listing must actually have been consulted, for
-- files (false) and in the geometry directory derived from get_modpath.
build_mirror()
write_file(impl_path, valid_impl_source)
local core7a, seen7a = production_core({"compiler_impl.lua"})
local ok7a, message7a = instantiate_production(core7a, function()
	return nil, german_denied
end)
assert(not ok7a, "an unreadable but PRESENT file was treated as absence")
local carries7a = tostring(message7a):find("Keine Berechtigung", 1, true) ~= nil
assert(carries7a, "the I/O failure lost its message: " .. tostring(message7a))
assert(not claims_absent(message7a),
	"EACCES without an errno was reported as absence")
assert(seen7a.calls == 1, "the directory listing was not consulted exactly once")
assert(seen7a.path == prod_wp40 .. "/geometry",
	"the listing asked for the wrong directory: " .. tostring(seen7a.path))
assert(seen7a.want_dirs == false, "the listing did not ask for files")
print("case7a-production-eacces-NO-errno raised=true carries-message=" ..
	tostring(carries7a) ..
	" absent-claimed=" .. tostring(claims_absent(message7a)) ..
	" listing-calls=" .. tostring(seen7a.calls) ..
	" listing-wants-files=" .. tostring(seen7a.want_dirs == false))

-- Case 7b: the localized ENOENT message with NO errno and the file genuinely
-- absent from the listing. Ordinary absence -- the production-shaped twin of
-- case5a -- and the production instance must still fail closed at compile.
build_mirror()
local core7b, seen7b = production_core({})
local ok7b, module7b = instantiate_production(core7b, function()
	return nil, german_missing
end)
assert(ok7b, tostring(module7b))
assert(seen7b.calls == 1, "the directory listing was not consulted exactly once")
print("case7b-production-enoent-NO-errno-unlisted instantiate=ok" ..
	" listing-calls=" .. tostring(seen7b.calls) ..
	" geometry-unavailable=" ..
	tostring(production_geometry_unavailable(module7b, core7b)))

-- Case 7c: the discriminator. Byte-identical message to case 7b, identically
-- missing errno; the ONLY difference from 7b is that the listing names the
-- file. 7b is absence and 7c is loud, so the listing, not the prose, decides.
build_mirror()
write_file(impl_path, valid_impl_source)
local core7c, seen7c = production_core({"other.lua", "compiler_impl.lua"})
local ok7c, message7c = instantiate_production(core7c, function()
	return nil, german_missing
end)
assert(not ok7c, "a listed file was treated as absence")
local carries7c = tostring(message7c):find(german_missing, 1, true) ~= nil
assert(carries7c, "the open failure lost its message: " .. tostring(message7c))
assert(not claims_absent(message7c), "a listed file was reported as absence")
assert(seen7c.calls == 1, "the directory listing was not consulted exactly once")
print("case7c-same-message-listed raised=true carries-message=" ..
	tostring(carries7c) ..
	" absent-claimed=" .. tostring(claims_absent(message7c)) ..
	" decided-by=listing")

-- Case 7d: production, no stub at all: the probe genuinely opens the planted
-- file. Branch 1 must be unchanged, the impl must be adopted, and the listing
-- must NOT be consulted, because a successful probe is evidence enough.
build_mirror()
write_file(impl_path, valid_impl_source)
local core7d, seen7d = production_core({"compiler_impl.lua"})
local ok7d, module7d = instantiate_production(core7d, nil)
assert(ok7d, tostring(module7d))
assert(module7d.new_offline_test_adapter == nil,
	"the offline adapter leaked into a production instance")
local previous7d = rawget(_G, "core")
rawset(_G, "core", core7d)
local produced7d = module7d.compile("42", vocabulary)
rawset(_G, "core", previous7d)
assert(type(produced7d) == "table", "adopted production compile returned no table")
assert(produced7d.marker == "grug_wp40_test_impl_ok", "a foreign compile ran")
assert(seen7d.calls == 0, "a successful probe still consulted the listing")
print("case7d-production-present-openable adopted=true seed=" ..
	tostring(produced7d.seed) ..
	" bindings=" .. tostring(produced7d.bindings_ok) ..
	" listing-calls=" .. tostring(seen7d.calls))

run("rm -rf " .. prod_root)

-- Leave the mirror in the shipped shape so a later reader of the scratch tree
-- does not find a planted implementation.
build_mirror()
print("WP40 T2 compiler optional-load tests passed")
