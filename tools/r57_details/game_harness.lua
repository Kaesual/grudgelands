-- Round 57 lane DETAILS: the whole game's registrations under a permissive
-- stub engine (LuaJIT, portable; never shipped). Every mod's init.lua runs in
-- the engine's load order, so the registered items, recipes, shelves, drop
-- tables and catalogs are the game's own, with no second copy.
--
--   local game = dofile(ROOT .. "/tools/r57_details/game_harness.lua")(ROOT)
--   game.items, game.entities, game.crafts, game.failures, game.order
--
-- Sets the globals `core`, `ItemStack` and every mod's table. The stub:
--   - the mod order is the engine's (luanti src/content/mods.cpp
--     flattenMods over byte-sorted folders, mod_configuration.cpp
--     resolveDependencies: a last-in-first-out list of satisfied mods);
--   - registrations are kept (items, nodes, tools, entities, crafts,
--     aliases); `register_on_<event>` fills `registered_on_<event>s`;
--   - every other unknown engine call, and any mod table a failed file
--     leaves behind, is a permissive object: indexing, calling and
--     arithmetic yield more of it, so a load-time call that needs a world
--     answers nothing and the load goes on;
--   - grug_mapgen registers only its world nodes (world_nodes.lua,
--     poi_displays.lua); the world construction is skipped, grug_zones.get
--     answers from the mapgen's own zone source and grug_core gets the few
--     seams the installed authority would give it. grug_map (the minimap's
--     bake, seconds at load) is skipped: it registers no item;
--   - a file that fails is skipped and listed in `failures` (today: the
--     quest loader, which wants the world's NPC sockets, and grug_home);
--   - mods-loaded callbacks run only for the files named in `callbacks`
--     (default: the recipe registry's finalisation and the vendor shelf
--     audit), each in the engine's registration order.
return function(repo, options)
	options = options or {}
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()

	local function permissive()
		local mt = {}
		mt.__index = function(t, k)
			local v = permissive()
			rawset(t, k, v)
			return v
		end
		mt.__call = function() return permissive() end
		mt.__add = function() return 0 end
		mt.__sub, mt.__mul, mt.__div, mt.__mod, mt.__unm = mt.__add, mt.__add,
			mt.__add, mt.__add, mt.__add
		mt.__concat = function(a, b)
			return (type(a) == "string" and a or "") .. (type(b) == "string" and b or "")
		end
		return setmetatable({}, mt)
	end

	-- Directory listings through LuaJIT's FFI (glibc's opendir and readdir;
	-- the game's own get_dir_list in the stub below uses them too): the
	-- names in `path`, sorted, the folders or the files.
	local ffi = assert(select(2, pcall(require, "ffi")), "game_harness: LuaJIT FFI is required")
	ffi.cdef[[
		typedef struct grug_harness_dir grug_harness_dir;
		struct grug_harness_dirent {
			uint64_t d_ino; int64_t d_off; unsigned short d_reclen;
			unsigned char d_type; char d_name[256];
		};
		grug_harness_dir *opendir(const char *name);
		struct grug_harness_dirent *readdir(grug_harness_dir *dir);
		int closedir(grug_harness_dir *dir);
	]]
	local function list_dir(path, folders)
		local out = {}
		local dir = ffi.C.opendir(path)
		if dir == nil then return out end
		while true do
			local entry = ffi.C.readdir(dir)
			if entry == nil then break end
			local name = ffi.string(entry.d_name)
			if name:sub(1, 1) ~= "." then
				local is_dir = entry.d_type == 4
				if entry.d_type == 0 then -- unknown: try to open it
					local probe = ffi.C.opendir(path .. "/" .. name)
					is_dir = probe ~= nil
					if is_dir then ffi.C.closedir(probe) end
				end
				if is_dir == (folders == true) then out[#out + 1] = name end
			end
		end
		ffi.C.closedir(dir)
		table.sort(out)
		return out
	end

	-- The mods and their order.
	local mods, listing = {}, {}
	local conf_paths = {}
	for _, pack in ipairs(list_dir(repo .. "/mods", true)) do
		for _, mod in ipairs(list_dir(repo .. "/mods/" .. pack, true)) do
			local path = repo .. "/mods/" .. pack .. "/" .. mod .. "/mod.conf"
			local probe = io.open(path)
			if probe then
				probe:close()
				conf_paths[#conf_paths + 1] = path
			end
		end
	end
	for _, path in ipairs(conf_paths) do
		local handle = assert(io.open(path))
		local text = "\n" .. handle:read("*a")
		handle:close()
		local function names(key)
			local out = {}
			for dep in (text:match("\n" .. key .. "%s*=%s*([^\n]*)") or ""):gmatch("[%w_]+") do
				out[#out + 1] = dep
			end
			return out
		end
		local mod = {name = text:match("\nname%s*=%s*([%w_]+)"), dir = path:gsub("/mod%.conf$", ""),
			depends = names("depends"), optional = names("optional_depends")}
		mods[mod.name] = mod
		listing[#listing + 1] = mod
	end
	table.sort(listing, function(a, b) return a.dir < b.dir end)
	local order, satisfied, waiting = {}, {}, {}
	for _, mod in ipairs(listing) do
		mod.wait, mod.count = {}, 0
		for _, list in ipairs({mod.depends, mod.optional}) do
			for _, dep in ipairs(list) do
				if (list == mod.depends or mods[dep]) and not mod.wait[dep] then
					mod.wait[dep] = true
					mod.count = mod.count + 1
				end
			end
		end
		if mod.count == 0 then satisfied[#satisfied + 1] = mod else waiting[#waiting + 1] = mod end
	end
	while #satisfied > 0 do
		local mod = table.remove(satisfied)
		order[#order + 1] = mod.name
		local rest = {}
		for _, other in ipairs(waiting) do
			if other.wait[mod.name] then
				other.wait[mod.name] = nil
				other.count = other.count - 1
			end
			if other.count == 0 then satisfied[#satisfied + 1] = other else rest[#rest + 1] = other end
		end
		waiting = rest
	end
	assert(#waiting == 0, "game_harness: a mod's dependencies are not met")

	-- The engine stub.
	local items, nodes, tools, craftitems, entities, crafts, aliases = {}, {}, {}, {}, {}, {}, {}
	local loaded, current = {}, nil
	local function register(kind, list)
		return function(name, def)
			name = name:gsub("^:", "")
			def = def or {}
			def.name, def.type = name, kind
			def.groups = def.groups or {}
			items[name] = def
			if list then list[name] = def end
		end
	end
	local function storage()
		local data = {}
		return {
			get_string = function(_, k) return data[k] or "" end,
			set_string = function(_, k, v) data[k] = v end,
			get_int = function(_, k) return math.floor(tonumber(data[k]) or 0) end,
			set_int = function(_, k, v) data[k] = v end,
			get_float = function(_, k) return tonumber(data[k]) or 0 end,
			set_float = function(_, k, v) data[k] = v end,
			contains = function(_, k) return data[k] ~= nil end,
			get_keys = function() return {} end,
			to_table = function() return {fields = {}} end,
			from_table = function() end,
			set_tool_capabilities = function() end,
		}
	end
	local function craft_items(recipe)
		if type(recipe) == "string" then return {recipe} end
		local out = {}
		for _, row in ipairs(type(recipe) == "table" and recipe or {}) do
			if type(row) == "table" then
				for _, item in ipairs(row) do out[#out + 1] = item end
			else
				out[#out + 1] = row
			end
		end
		return out
	end
	local engine = {
		registered_items = items, registered_nodes = nodes, registered_tools = tools,
		registered_craftitems = craftitems, registered_entities = entities,
		registered_aliases = aliases,
		register_node = register("node", nodes),
		register_craftitem = register("craft", craftitems),
		register_tool = register("tool", tools),
		register_item = function(name, def) register(def.type or "none")(name, def) end,
		register_entity = function(name, def) entities[name:gsub("^:", "")] = def end,
		register_craft = function(def) crafts[#crafts + 1] = def end,
		clear_craft = function() end,
		register_alias = function(alias, name) aliases[alias] = name end,
		register_alias_force = function(alias, name) aliases[alias] = name end,
		override_item = function(name, def)
			local target = items[name]
			if target then
				for key, value in pairs(def) do target[key] = value end
			end
		end,
		unregister_item = function(name)
			items[name], nodes[name], tools[name], craftitems[name] = nil, nil, nil, nil
		end,
		get_item_group = function(name, group)
			local def = items[name]
			return def and def.groups and def.groups[group] or 0
		end,
		get_modpath = function(name) return mods[name] and mods[name].dir or nil end,
		get_current_modname = function() return current end,
		get_modnames = function() return order end,
		get_worldpath = function() return "/nonexistent-grug-harness-world" end,
		get_game_info = function() return {id = "grudgelands", path = repo} end,
		get_mod_storage = storage,
		settings = setmetatable({
			get = function() return nil end,
			get_bool = function(_, _, default) return default end,
		}, {__index = function() return function() return nil end end}),
		log = function() end,
		parse_json = function(text) return json.parse(text) end,
		sha256 = function(bytes, raw)
			local digest = raw_sha256(bytes)
			return raw and digest or common.hex(digest)
		end,
		get_us_time = function() return 0 end,
		after = function() end,
		formspec_escape = function(text) return text end,
		colorize = function(_, text) return text end,
		get_color_escape_sequence = function() return "" end,
		get_translator = function() return function(text) return text end end,
		is_singleplayer = function() return false end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		-- No fuel or cooking time is known here (stairs and the curation
		-- ask for fuel at load).
		get_craft_result = function()
			return {item = ItemStack(""), time = 0, replacements = {}}, {items = {}}
		end,
		get_dir_list = function(path, dirs)
			if dirs == nil then
				local all = list_dir(path, true)
				for _, name in ipairs(list_dir(path, false)) do all[#all + 1] = name end
				return all
			end
			return list_dir(path, dirs)
		end,
		get_all_craft_recipes = function(output)
			local out = {}
			for _, def in ipairs(crafts) do
				if type(def.output) == "string" and def.output:match("^(%S+)") == output then
					out[#out + 1] = {method = def.type == "cooking" and "cooking" or (def.type or "normal"),
						output = def.output, items = craft_items(def.recipe)}
				end
			end
			return #out > 0 and out or nil
		end,
	}
	core = setmetatable(engine, {__index = function(t, key)
		local event = type(key) == "string" and (key:match("^register_on_(.+)$") or
			key:match("^registered_on_(.+)s$"))
		if event then
			local list = {}
			rawset(t, "registered_on_" .. event .. "s", list)
			rawset(t, "register_on_" .. event, function(fn) list[#list + 1] = fn end)
			return rawget(t, key)
		end
		return permissive()
	end})
	minetest = core
	vector = permissive()
	PcgRandom = function() return permissive() end
	PseudoRandom = PcgRandom
	VoxelArea = permissive()
	AreaStore = function() return permissive() end
	dump = function(value) return tostring(value) end
	Settings = function(path)
		local values = {}
		local handle = io.open(path)
		if handle then
			for line in handle:lines() do
				local key, value = line:match("^%s*([%w_%.]+)%s*=%s*(.-)%s*$")
				if key then values[key] = value end
			end
			handle:close()
		end
		return {get = function(_, key) return values[key] end,
			get_bool = function(_, key, default)
				if values[key] == nil then return default end
				return values[key] == "true"
			end}
	end
	function table.copy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for key, entry in pairs(value) do out[key] = table.copy(entry) end
		return setmetatable(out, getmetatable(value))
	end
	function table.indexof(list, value)
		for index, entry in ipairs(list) do if entry == value then return index end end
		return -1
	end
	function string.split(text, separator)
		local out = {}
		separator = separator or ","
		for part in (text .. separator):gmatch("(.-)" .. separator:gsub("%p", "%%%0")) do
			out[#out + 1] = part
		end
		return out
	end
	function string.trim(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
	local Stack = {}
	Stack.__index = Stack
	function ItemStack(value)
		if type(value) == "table" and getmetatable(value) == Stack then
			return setmetatable({name = value.name, count = value.count, meta = value.meta}, Stack)
		end
		local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
		return setmetatable({name = name, count = name == "" and 0 or tonumber(count) or 1}, Stack)
	end
	function Stack:get_name() return self.name end
	function Stack:get_count() return self.count end
	function Stack:set_count(count) self.count = count end
	function Stack:is_empty() return self.count == 0 end
	function Stack:get_meta()
		self.meta = self.meta or storage()
		return self.meta
	end
	function Stack:set_name(name) self.name = name end
	function Stack:get_tool_capabilities()
		local def = items[self.name]
		return def and def.tool_capabilities or {}
	end
	function Stack:set_tool_capabilities() end
	function Stack:set_wear() end
	function Stack:get_free_space() return 99 - self.count end
	function Stack:take_item(count)
		count = math.min(count or 1, self.count)
		self.count = self.count - count
		local taken = ItemStack(self.name .. " " .. count)
		if self.count == 0 then self.name = "" end
		return taken
	end
	function Stack:get_definition() return items[self.name] or {} end
	function Stack:get_stack_max() return 99 end
	function Stack:to_string() return self.name .. " " .. self.count end
	function Stack:add_wear_by_uses() end
	function Stack:add_wear() end
	function Stack:get_wear() return 0 end

	-- The load.
	local failures = {}
	local real_dofile = dofile
	dofile = function(path)
		local results = {pcall(real_dofile, path)}
		if results[1] then return unpack(results, 2) end
		failures[#failures + 1] = tostring(path):gsub("^.*/mods/", "mods/") .. ": " ..
			tostring(results[2]):match("^[^\n]*")
		return permissive()
	end
	local zone_source = real_dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	for _, name in ipairs(order) do
		current = name
		local mod = mods[name]
		if name == "grug_mapgen" then
			grug_mapgen = {wp40 = permissive()}
			dofile(mod.dir .. "/world_nodes.lua")(core, mod.dir, grug_nodes, grug_gathering)
			dofile(mod.dir .. "/poi_displays.lua")(core)
			local zones = {}
			for _, zone in ipairs(zone_source.zones) do zones[zone.id] = zone end
			grug_zones = setmetatable({get = function(id) return zones[id] end},
				{__index = function() return permissive() end})
			grug_core.zone_authority_installed = function() return true end
			grug_core.rare_route = function() return permissive() end
			grug_core.assign_service_socket = function() return true end
			grug_core.assign_innkeeper_socket = function() return true end
		elseif name == "grug_map" then
			grug_map = permissive()
		else
			dofile(mod.dir .. "/init.lua")
		end
	end
	local wanted = {}
	for _, file in ipairs(options.callbacks or {"grug_jobs/registry.lua", "grug_traders/stock.lua"}) do
		wanted[file] = true
	end
	for _, fn in ipairs(loaded) do
		local source = debug.getinfo(fn, "S").source:match("([%w_]+/[%w_]+%.lua)$")
		if wanted[source] then
			local ok, err = pcall(fn)
			if not ok then failures[#failures + 1] = "mods_loaded " .. source .. ": " .. tostring(err) end
		end
	end
	dofile = real_dofile
	return {items = items, nodes = nodes, entities = entities, crafts = crafts,
		aliases = aliases, failures = failures, order = order}
end
