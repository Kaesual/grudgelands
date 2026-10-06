--
-- Round 38: the mob names, one per slot (data/names.json), as a pure index.
-- No engine call: names.lua loads it for the game, the fixtures directly.
--
-- A slot key is "<scope>/<source>/L<lo>-<hi>" (tools/r38_names/inventory.py):
--   scope   a zone id, or "world" for a slot without a zone
--   source  a sub-type or entity role ("small_boar", "guard_accord"), or a
--           placed individual's key ("rare.grimtusk",
--           "pvp_camp_shattered_line_throng_low.guard")
--   lo, hi  the levels the slot's mobs spawn at
-- A mob's name is lookup(source, its zone, its level): the slot of its zone
-- whose levels hold the level, else the "world" slots, else (a source only
-- named elsewhere) the source's one name. A level outside every range takes
-- the nearest range of that scope. Plain Lua 5.1.
--
local M = {}

function M.parse_key(key)
	if type(key) ~= "string" then return nil end
	local scope, source, lo, hi = key:match("^([%w_]+)/([%w_%.%-]+)/L(%d+)%-(%d+)$")
	if not scope then return nil end
	lo, hi = tonumber(lo), tonumber(hi)
	if lo > hi then return nil end
	return scope, source, lo, hi
end

-- `names` = {slot key = name}. Returns the index and a sorted list of
-- errors: a malformed key, an empty name, and two different names whose
-- ranges overlap in one (source, scope) -- the lookup could not decide.
function M.build(names)
	local index = {sources = {}, levels = {}, keys = {}}
	local errors = {}
	local keys = {}
	for key in pairs(names or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local name = names[key]
		local scope, source, lo, hi = M.parse_key(key)
		if not scope then
			errors[#errors + 1] = key .. ": not a slot key <scope>/<source>/L<lo>-<hi>"
		elseif type(name) ~= "string" or not name:find("%S") then
			errors[#errors + 1] = key .. ": the name must be a non-empty string"
		else
			local scopes = index.sources[source] or {}
			index.sources[source] = scopes
			local list = scopes[scope] or {}
			scopes[scope] = list
			for _, row in ipairs(list) do
				if row.name ~= name and row.lo <= hi and lo <= row.hi then
					errors[#errors + 1] = ("%s: %q overlaps %q (%s) in level"):format(key, name, row.name, row.key)
				end
			end
			list[#list + 1] = {lo = lo, hi = hi, name = name, key = key}
			local range = index.levels[name]
			if range then
				range[1], range[2] = math.min(range[1], lo), math.max(range[2], hi)
			else
				index.levels[name] = {lo, hi}
			end
			index.keys[key] = name
		end
	end
	for _, scopes in pairs(index.sources) do
		for _, list in pairs(scopes) do
			table.sort(list, function(a, b) return a.lo < b.lo or (a.lo == b.lo and a.key < b.key) end)
		end
	end
	return index, errors
end

-- The row of `list` whose range holds `level`, else the nearest (ties: the
-- lower range); without a level, the one name every row shares, or nil.
local function pick(list, level)
	if not list or #list == 0 then return nil end
	if level == nil then
		for i = 2, #list do
			if list[i].name ~= list[1].name then return nil end
		end
		return list[1].name
	end
	local best, gap
	for _, row in ipairs(list) do
		if level >= row.lo and level <= row.hi then return row.name end
		local d = level < row.lo and row.lo - level or level - row.hi
		if not gap or d < gap then best, gap = row, d end
	end
	return best.name
end

-- The one name of every row of `source` in any scope, or nil when they differ.
local function only_name(scopes)
	local name
	local scope_ids = {}
	for scope in pairs(scopes) do scope_ids[#scope_ids + 1] = scope end
	table.sort(scope_ids)
	for _, scope in ipairs(scope_ids) do
		for _, row in ipairs(scopes[scope]) do
			if name and row.name ~= name then return nil end
			name = row.name
		end
	end
	return name
end

-- The name a mob of `source` shows in `zone` (nil: none) at `level` (nil:
-- not yet levelled), or nil when the names file does not name it.
function M.lookup(index, source, zone, level)
	local scopes = index.sources[source]
	if not scopes then return nil end
	local list = zone and scopes[zone] or scopes.world
	if list then return pick(list, level) end
	return only_name(scopes)
end

-- The names of `source` in `zone` whose ranges meet [lo, hi], in level
-- order (a quest objective's selector: the role's levels in an area).
function M.names_in(index, source, zone, lo, hi)
	local scopes = index.sources[source]
	local list = scopes and (scopes[zone] or scopes.world)
	local out, seen = {}, {}
	if not list then
		local name = scopes and only_name(scopes)
		return name and {name} or out
	end
	for _, row in ipairs(list) do
		if row.lo <= hi and lo <= row.hi and not seen[row.name] then
			seen[row.name] = true
			out[#out + 1] = row.name
		end
	end
	return out
end

-- The one name every slot of `source` bears (any scope), or nil.
function M.only(index, source)
	local scopes = index.sources[source]
	return scopes and only_name(scopes) or nil
end

-- {lo, hi}: the levels of every slot that bears `name`, or nil.
function M.levels_of(index, name)
	local range = index.levels[name]
	return range and {range[1], range[2]} or nil
end

-- The query table over one index (names.lua publishes it as
-- grug_mobs.names; fixtures build one over their own names).
function M.api(index)
	return {
		core = M, index = index,
		lookup = function(source, zone, level) return M.lookup(index, source, zone, level) end,
		names_in = function(source, zone, lo, hi) return M.names_in(index, source, zone, lo, hi) end,
		levels_of = function(name) return M.levels_of(index, name) end,
		only = function(source) return M.only(index, source) end,
		-- The one name of `source`, or an error: a name the code shows
		-- outside a nametag (a broadcast, a crown, a registered
		-- description) reads the names file, never a second copy (Round 38
		-- lane B2).
		required = function(source)
			local name = M.only(index, source)
			if not name then
				error("[grug_mobs] data/names.json names no single " .. tostring(source), 2)
			end
			return name
		end,
	}
end

return M
