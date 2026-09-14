-- Engine-free node registry for the WP13 KATs.
--
-- WP13 writes settlement cells straight through VoxelManip, so a palette may
-- only name nodes whose whole behaviour is their definition: no
-- `on_construct`, no node timer, no formspec, no inventory. The engine never
-- runs those for bulk placement (lua_api.md, `on_construct`: "Not called for
-- bulk node placement"), which turns a chest or a furnace written this way
-- into a dead prop.
--
-- Deciding that by eye does not scale, so this module reconstructs the real
-- registry the way `decor_registry_kat.lua` already does for `grug_decor`:
-- the node-registering sources of the vendored mods are executed against a
-- stub `core`, and the definition tables they hand over are kept. Nothing is
-- guessed and nothing is hand-listed; when an upstream mod grows a callback,
-- the KAT that consumes this table sees it.
--
-- It also gives the pane rule (`xpanes` `connects_to`) and the torch support
-- rule real `groups` and `drawtype` data instead of a name heuristic.
--
-- Plain Lua 5.1, pure apart from reading the mod sources; every global it
-- touches is restored before it returns.

local M = {}

-- The vendored mods run their descriptions through a translator; under the
-- stub the identity is the whole of it.
local function identity(text) return text end

-- The sources that register the nodes a settlement palette may name. Only
-- node-bearing files are listed: tools, crafting, mapgen and chat add no
-- node definition and would only widen the stub surface.
M.SOURCES = {
	-- `default/init.lua` is skipped: it registers no node and would pull in
	-- tools, crafting, mapgen and chat. Its one relevant act, publishing the
	-- `default` namespace table, is done by `seed` instead.
	{mod = "default", path = "mods/BASE/default", seed = "default",
		seed_table = {get_translator = identity, LIGHT_MAX = 14,
			get_hotbar_bg = function() return "" end,
			gui_survival_form = ""}, files = {
		"functions.lua", "trees.lua", "nodes.lua", "chests.lua",
		"furnace.lua", "torch.lua"}},
	{mod = "stairs", path = "mods/BASE/stairs", files = {"init.lua"}},
	{mod = "doors", path = "mods/BASE/doors", files = {"init.lua"}},
	{mod = "beds", path = "mods/BASE/beds", files = {"init.lua"}},
	-- `dye` registers no node; it is loaded because `wool` reads its colour
	-- roster to build the sixteen wool nodes.
	{mod = "dye", path = "mods/BASE/dye", files = {"init.lua"}},
	{mod = "wool", path = "mods/BASE/wool", files = {"init.lua"}},
	{mod = "vessels", path = "mods/BASE/vessels", files = {"init.lua"}},
	{mod = "walls", path = "mods/BASE/walls", files = {"init.lua"}},
	{mod = "xpanes", path = "mods/BASE/xpanes", files = {"init.lua"}},
	{mod = "grug_decor", path = "mods/ITEMS/grug_decor", files = {"init.lua"}},
	-- `grug_materials` last: its derivative nodes are clones of vendored
	-- definitions, so the sources above must already be in the registry.
	-- `overrides.lua`, `content_curation.lua` and `audit.lua` are not run:
	-- `core.override_item` is a no-op in this stub, so group edits made by
	-- `overrides.lua` (today only grug_natural/level/grug_pick_tier on a few
	-- ground nodes) are invisible here. If an override ever touches a group
	-- that `PANE_CONNECT_GROUPS` or `is_opaque_full` reads, extend this
	-- stub to apply it, or the KAT and the engine will disagree silently.
	{mod = "grug_materials", path = "mods/ITEMS/grug_materials",
		seed = "grug_materials",
		files = {"registry.lua", "mining.lua", "ores.lua",
			"derivatives.lua"}},
	-- `grug_trees` registers the two race trees (silverwood, gravewood) that
	-- the elf and undead palettes name. Its module body reads its own `.mts`
	-- schematics and keeps the decoded `size.y` before it registers a single
	-- node, so `read_schematic` below answers a shaped table rather than an
	-- empty one; nothing else in the file needs an engine.
	{mod = "grug_trees", path = "mods/ITEMS/grug_trees", files = {"init.lua"}},
	-- `grug_nodes` carries the signature surface nodes (blight dirt, the
	-- litters, the bone pile). It reads `grug_materials.natural_groups`, so
	-- it must load after that mod.
	{mod = "grug_nodes", path = "mods/ITEMS/grug_nodes", files = {"init.lua"}},
}

local function deep_copy(t, seen)
	seen = seen or {}
	if type(t) ~= "table" then return t end
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do out[deep_copy(k, seen)] = deep_copy(v, seen) end
	return out
end

local MOD_GLOBALS = {"default", "stairs", "doors", "beds", "wool", "vessels",
	"walls", "xpanes", "grug_decor", "dye", "grug_materials", "grug_trees"}

-- Load every source under a stub `core` and return what it registered.
-- `repo` is the repository root; the result is
-- {nodes = {[name] = def}, order = {name, ...}, per_mod = {[mod] = count}}.
function M.load(repo)
	local nodes, order, per_mod, aliases = {}, {}, {}, {}
	local current_mod = "?"

	local noop = function() end
	local core_stub = {}

	function core_stub.register_node(name, def)
		if type(name) ~= "string" or type(def) ~= "table" then return end
		if name:sub(1, 1) == ":" then name = name:sub(2) end
		if nodes[name] == nil then
			order[#order + 1] = name
			per_mod[current_mod] = (per_mod[current_mod] or 0) + 1
		end
		nodes[name] = def
	end
	function core_stub.register_alias(old, new) aliases[tostring(old)] = new end
	core_stub.register_alias_force = core_stub.register_alias
	function core_stub.get_modpath(name)
		for _, source in ipairs(M.SOURCES) do
			if source.mod == name then return repo .. "/" .. source.path end
		end
		return nil
	end
	function core_stub.get_current_modname() return current_mod end
	function core_stub.get_translator()
		return function(s) return s end
	end
	function core_stub.get_item_group(name, group)
		local def = nodes[name]
		if not def or type(def.groups) ~= "table" then return 0 end
		return def.groups[group] or 0
	end
	core_stub.registered_nodes = nodes
	core_stub.registered_items = nodes
	core_stub.registered_craftitems = {}
	core_stub.registered_tools = {}
	core_stub.registered_aliases = aliases
	core_stub.settings = {
		get_bool = function(_, _, fallback) return fallback end,
		get = function() return nil end,
		get_np_group = function() return nil end,
	}
	function core_stub.facedir_to_dir(dir)
		local steps = {[0] = {x = 0, y = 0, z = 1}, {x = 1, y = 0, z = 0},
			{x = 0, y = 0, z = -1}, {x = -1, y = 0, z = 0}}
		return steps[dir % 4]
	end
	function core_stub.dir_to_facedir() return 0 end
	-- A schematic handle is opaque to the registry; a mod only checks that it
	-- got one back before it keeps it. The decoded schematic, however, is
	-- read for its `size` (`grug_trees` keeps the height of each gravewood
	-- asset), so the stub answers a shaped table with a zero size rather than
	-- an empty one: no node definition depends on the value.
	function core_stub.read_schematic()
		return {size = {x = 0, y = 0, z = 0}}
	end
	function core_stub.register_schematic() return "wp13-stub-schematic" end
	function core_stub.get_craft_result()
		return {time = 0, item = nil, replacements = {}}
	end
	function core_stub.is_protected() return false end
	function core_stub.get_us_time() return 0 end
	function core_stub.is_creative_enabled() return false end
	function core_stub.pointed_thing_to_face_pos()
		return {x = 0, y = 0, z = 0}
	end
	-- Anything else a vendored mod reaches for at load time is a
	-- registration or a runtime helper; neither can change a node
	-- definition table here, so an inert function is the honest answer.
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	-- Globals the loaded mods publish or legitimately read.
	local saved, had = {}, {}
	local function set_global(name, value)
		had[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
		rawset(_G, name, value)
	end
	set_global("core", core_stub)
	set_global("minetest", core_stub)
	set_global("vector", {
		add = function(a, b)
			return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
		end,
		subtract = function(a, b)
			return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
		end,
		new = function(a) return {x = a.x, y = a.y, z = a.z} end,
		equals = function(a, b)
			return a.x == b.x and a.y == b.y and a.z == b.z
		end,
	})
	set_global("ItemStack", function(s)
		return {
			get_name = function() return s end,
			get_count = function() return 1 end,
			is_empty = function() return true end,
			add_wear_by_uses = noop,
			set_name = noop,
			take_item = noop,
		}
	end)
	set_global("PseudoRandom", function()
		return {next = function() return 0 end}
	end)
	for _, name in ipairs(MOD_GLOBALS) do set_global(name, nil) end
	local saved_copy = table.copy
	if not table.copy then table.copy = deep_copy end

	local storage_derivatives = {}
	local ok, err = pcall(function()
		for _, source in ipairs(M.SOURCES) do
			current_mod = source.mod
			if source.seed then
				rawset(_G, source.seed, deep_copy(source.seed_table or {}))
			end
			for _, file in ipairs(source.files) do
				local path = repo .. "/" .. source.path .. "/" .. file
				local chunk, load_err = loadfile(path)
				if not chunk then
					error("wp13 stub registry: cannot load " .. path .. ": " ..
						tostring(load_err), 0)
				end
				chunk()
			end
		end
	end)

	-- `grug_materials` publishes the second retirement roster on its own
	-- namespace table; copy it out before the globals go back.
	local materials = rawget(_G, "grug_materials")
	if type(materials) == "table" and
			type(materials.STORAGE_DERIVATIVES) == "table" then
		for index, entry in ipairs(materials.STORAGE_DERIVATIVES) do
			storage_derivatives[index] = {source = entry.source,
				target = entry.target}
		end
	end

	-- Hand the globals back exactly as they were.
	table.copy = saved_copy
	for name in pairs(saved) do
		rawset(_G, name, had[name] and saved[name] or nil)
	end
	if not ok then error(err, 0) end

	current_mod = "?"
	return {nodes = nodes, order = order, per_mod = per_mod, aliases = aliases,
		storage_derivatives = storage_derivatives}
end

-- ---------------------------------------------------------------------------
-- the properties WP13 asks of a registry
-- ---------------------------------------------------------------------------

-- Definition fields that make a node a service rather than a shape: an
-- inventory, a formspec or a timer, all of which are created in
-- `on_construct`, which bulk placement never calls. A node carrying any of
-- them and written through VoxelManip is a dead prop.
--
-- The set is deliberately narrow. `on_destruct`, `after_destruct`,
-- `on_blast`, `after_place_node` and `can_dig` run on dig, explosion or
-- player placement -- never on construction -- so a node that carries only
-- those behaves identically however it was written, and excluding them is
-- what lets a real door (`on_rightclick`, `on_destruct`, `on_blast`), a bed
-- half (`on_destruct`) and pine needles (`after_place_node`, the leaf-decay
-- marker) stay in a palette. `on_rightclick` is checked separately by the
-- KAT, which allows exactly the `doors` family.
M.META_FIELDS = {
	"allow_metadata_inventory_move", "allow_metadata_inventory_put",
	"allow_metadata_inventory_take", "formspec", "inventory", "on_construct",
	"on_metadata_inventory_move", "on_metadata_inventory_put",
	"on_metadata_inventory_take", "on_receive_fields", "on_timer",
}

-- Which META_FIELDS does this node carry? Returns a sorted list.
function M.meta_fields(def)
	local hits = {}
	if type(def) ~= "table" then return hits end
	for _, field in ipairs(M.META_FIELDS) do
		if def[field] ~= nil then hits[#hits + 1] = field end
	end
	return hits
end

-- `xpanes` panes connect to these groups (mods/BASE/xpanes/init.lua, the
-- `connects_to` of the connected pane node); a pane also always connects to
-- another pane, which `group:pane` already covers.
M.PANE_CONNECT_GROUPS = {"pane", "stone", "glass", "wood", "tree"}

function M.pane_connects(registry, name)
	local def = registry.nodes[name]
	if not def or type(def.groups) ~= "table" then return false end
	for _, group in ipairs(M.PANE_CONNECT_GROUPS) do
		local value = def.groups[group]
		if value ~= nil and value ~= 0 then return true end
	end
	return false
end

-- Opaque full cube: the only thing a wallmounted torch may hang on. A
-- `drawtype` other than the default is a nodebox, a mesh, a plant or a
-- liquid; `paramtype = "light"` or `sunlight_propagates` on a full cube is
-- glass, which is transparent and reads as a hole under a torch.
function M.is_opaque_full(registry, name)
	local def = registry.nodes[name]
	if not def then return false end
	local drawtype = def.drawtype or "normal"
	if drawtype ~= "normal" then return false end
	if def.paramtype == "light" then return false end
	if def.sunlight_propagates then return false end
	return true
end

return M
