--
-- Round 38: every mob's name comes from data/names.json, one name per slot
-- (names_core.lua; the slot keys of tools/r38_names/inventory.py). A quest
-- counts a kill by the name the mob shows (grug_quests state.lua), so the
-- name is resolved here once per activation and on every relevel, from
-- what the mob carries:
--   source  `_grug_name_key` (a rare "rare.<id>", a PvP garrison post
--           "<settlement key>.<post>"), else the entity role
--   zone    the zone of its `_grug_area` tag (a region, camp or garrison
--           spawn), else of its first activation position
--           (`_grug_variant_zone`, persisted)
--   level   `_grug_level`, else the level a spawner handed it
-- A source the file does not name keeps its registered description (a
-- garrison captain, commander and General keep their data/pvp_names.json
-- name, written at placement). The name goes into `description`, the text
-- the nametag prints after the tier prefix (levels.lua tag_text), and into
-- `temp.grug_display` (a sub-type's per-step guard, subtypes.lua).
--
local modpath = core.get_modpath(core.get_current_modname())
local NC = dofile(modpath .. "/names_core.lua")

local function read_names()
	local handle = io.open(modpath .. "/data/names.json", "r")
	if not handle then
		error("[grug_mobs] data/names.json is missing")
	end
	local data = core.parse_json(handle:read("*a"))
	handle:close()
	if type(data) ~= "table" or type(data.names) ~= "table" then
		error("[grug_mobs] data/names.json: needs an object `names` (slot key -> name)")
	end
	return data.names
end

local index, errors = NC.build(read_names())
if #errors > 0 then
	error("[grug_mobs] data/names.json:\n  " .. table.concat(errors, "\n  "), 0)
end

local N = NC.api(index)
grug_mobs.names = N

-- The zone a mob's name is read in (see the header); nil when unknown.
function N.zone_of(self)
	local area = self._grug_area
	local zone = type(area) == "string" and area:match("^([^/]+)/")
	if zone then return zone end
	if self._grug_variant_zone == nil then
		local pos = self.object and self.object:get_pos()
		self._grug_variant_zone = pos and grug_zones.id_at(pos.x, pos.z) or ""
	end
	return self._grug_variant_zone ~= "" and self._grug_variant_zone or nil
end

-- The name `self` shows by the names file, or nil (not named there).
function N.name_of(self)
	local source = self._grug_name_key or (self.name and self.name:match("^grug_mobs:(.+)$"))
	if not source then return nil end
	return N.lookup(source, N.zone_of(self), self._grug_level or self._grug_spawn_level)
end

-- Writes the name; true when the description changed (the caller then
-- refreshes the nametag: levels.lua ensure_init and relevel do).
function grug_mobs.apply_name(self)
	local name = N.name_of(self)
	if not name then return false end
	self.temp = self.temp or {}
	self.temp.grug_display = name
	if self.description == name then return false end
	self.description = name
	return true
end
