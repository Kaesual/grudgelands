--
-- ACTORS THE MAP NEVER SAVES (Round 84 ELITE): the zone leaders, the rift
-- boss and the depth pulse's arrivals live while their spot is loaded and
-- nowhere else, so their spawner's ObjectRef answers "is it out there".
--
-- `static_save = false` written after `core.add_entity` returned is too late:
-- the engine stores the object's staticdata in its mapblock while adding it
-- (`ServerEnvironment::addActiveObjectRaw`, after the activation callbacks),
-- and when that block is saved and unloaded before the object's own
-- deactivation, the deactivation reloads the block and cannot find the entry
-- it tries to delete, so the block keeps it. That first snapshot comes back
-- at the next visit beside the spawner's next actor: a leader seen twice
-- (docs/technical/upstream-workarounds.md §11).
--
-- So a spawner adds such an actor through `add_mob_unsaved` or
-- `add_entity_unsaved`, which name the entity being placed; its activation
-- inside the add (`unsaved_claim`, the first statement of init.lua's
-- after_activate wrapper) turns static_save off before the engine stores
-- anything. A definition marked `_grug_unsaved` (the leader sub-types, the
-- rift boss) has no saved form at all: every other activation of it is a
-- snapshot an older version left in the map, and it removes itself before
-- anything else runs, so it never fights, drops or credits anything. The
-- depth pulse's arrivals share their registrations with ambient mobs, so
-- only the add is covered there.
--

local placing -- the entity name being added unsaved right now, or nil

-- grug_mobs.add_mob for an actor the map never saves: the entity or nil.
function grug_mobs.add_mob_unsaved(pos, def)
	placing = def.name
	local ent = grug_mobs.add_mob(pos, def)
	placing = nil
	return ent
end

-- core.add_entity for an actor the map never saves: the ObjectRef or nil.
function grug_mobs.add_entity_unsaved(pos, name, staticdata)
	placing = name
	local object = core.add_entity(pos, name, staticdata)
	placing = nil
	return object
end

-- The activation half (init.lua's after_activate wrapper, before anything
-- else). Returns false for a removed snapshot, whose activation must do
-- nothing more.
function grug_mobs.unsaved_claim(self)
	if self.name == placing then
		self.object:set_properties({static_save = false})
		return true
	end
	if not self._grug_unsaved then return true end
	core.log("action", "[grug_mobs] a saved copy of " .. tostring(self.name) ..
		", which the map never saves, removed itself")
	self.object:set_properties({static_save = false})
	self.object:remove()
	return false
end
