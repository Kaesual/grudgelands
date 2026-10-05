--
-- Is an authored actor still out there? (Round 37 MP, audit MOC-01 and
-- MOC-03, round37-plan.md §4.3.) One rule for the actors that persist with
-- the map and have no settlement socket of their own: the named rares
-- (rares.lua, key "rare:<id>") and the island dragons (bosses.lua, key
-- "dragon:<id>").
--
-- A spawn hands its instance the next GENERATION of its key: the plain,
-- persisted fields `_grug_live_key` and `_grug_live_gen`. Mod storage keeps,
-- per key,
--   live_gen:<key>     the generation of the instance that is meant to stand;
--   live_pos:<key>     where it was last known: written when it unloads (the
--                      block its static copy is in) and while it is active
--                      once it moved LIVE_NOTE_MOVE nodes;
--   live_absent:<key>  the seconds it was missing while that place was active.
--
-- On every activation (init.lua's after_activate wrapper) an instance claims
-- its key: a copy with an older generation, or a second copy while the claimed
-- one stands, removes itself. So a replacement can never meet the actor it
-- replaced, also across restarts and on a rolled-back map.
--
-- The watchdog (the callers' 10 s passes) counts absence ONLY while the last
-- known place is an active mapblock: a player is there, so the actor would be
-- active too if it still existed. Time nobody is near never counts, and an
-- actor standing out of everyone's range is never mistaken for a lost one --
-- the old rare watchdog aged a rare by game time and scanned only around its
-- route points, which declared a rare in an inactive block lost.
--

local storage = grug_mobs.storage

local L = {}
grug_mobs.liveness = L

-- Seconds missing at an active last place before the actor counts as lost.
L.LOST_AFTER = 60
-- A live actor's place is noted again once it moved this far.
local LIVE_NOTE_MOVE = 8

local live = {} -- key -> the ObjectRef that claimed it (runtime only)
local noted = {} -- key -> the last position written for it (runtime only)

local function gen_of(key)
	return storage:get_int("live_gen:" .. key)
end

local function note_pos(key, pos)
	local p = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5)}
	noted[key] = p
	storage:set_string("live_pos:" .. key, p.x .. " " .. p.y .. " " .. p.z)
end

function L.last_pos(key)
	local x, y, z = storage:get_string("live_pos:" .. key):match(
		"^(%-?%d+) (%-?%d+) (%-?%d+)$")
	if not x then return nil end
	return {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
end

-- The ObjectRef of the instance standing now, or nil.
function L.instance(key)
	local object = live[key]
	if object and object:get_pos() then return object end
	live[key] = nil
	return nil
end

-- A new instance of `key` is about to be added: its generation, one above the
-- last. Every older copy on disk is stale from here on.
function L.next_generation(key)
	local gen = gen_of(key) + 1
	storage:set_int("live_gen:" .. key, gen)
	storage:set_int("live_absent:" .. key, 0)
	return gen
end

-- `ent` becomes the instance of `key` with generation `gen` (a spawn whose
-- entity got its identity after add_entity, like a rare through add_mob).
function L.adopt(ent, key, gen)
	ent._grug_live_key = key
	ent._grug_live_gen = gen
	return L.claim(ent)
end

-- On activation: true when `ent` is the instance of its key, else false and
-- the reason ("stale": an older generation; "duplicate": another copy of the
-- current one stands). The caller removes a refused copy.
function L.claim(ent)
	local key = ent._grug_live_key
	if ent._grug_live_gen ~= gen_of(key) then return false, "stale" end
	local other = L.instance(key)
	if other and other ~= ent.object then return false, "duplicate" end
	live[key] = ent.object
	storage:set_int("live_absent:" .. key, 0)
	local pos = ent.object:get_pos()
	if pos then note_pos(key, pos) end
	return true
end

-- On unload or removal (the class-level on_deactivate below): where the
-- claimed instance went out of memory.
function L.release(ent)
	local key = ent._grug_live_key
	if not key or live[key] ~= ent.object then return end
	live[key] = nil
	local pos = ent.object:get_pos()
	if pos then note_pos(key, pos) end
end

local function block_active(pos)
	return core.compare_block_status(pos, "active") == true
end

-- One watchdog pass, `dt` seconds after the last: "here" while the instance
-- stands, "away" while its last place is not active (nothing counts),
-- "missing" while it counts absence there, and "lost" once that absence
-- reached LOST_AFTER (the count starts again). An actor that never reported a
-- place is lost at once; its generation keeps any old copy from coming back.
function L.watch(key, dt)
	local object = L.instance(key)
	if object then
		local pos = object:get_pos()
		local last = noted[key]
		if not last or math.abs(pos.x - last.x) + math.abs(pos.y - last.y) +
				math.abs(pos.z - last.z) >= LIVE_NOTE_MOVE then
			note_pos(key, pos)
		end
		return "here"
	end
	local pos = L.last_pos(key)
	if pos and not block_active(pos) then return "away" end
	local absent = storage:get_int("live_absent:" .. key) + dt
	if not pos or absent >= L.LOST_AFTER then
		storage:set_int("live_absent:" .. key, 0)
		return "lost"
	end
	storage:set_int("live_absent:" .. key, absent)
	return "missing"
end

-- The activation half for every grug mob (init.lua's after_activate
-- wrapper): a refused copy removes itself without a static copy of its own
-- and runs nothing else. Returns false for a removed copy.
function grug_mobs.live_claim(self)
	if not self._grug_live_key then return true end
	local ok, why = L.claim(self)
	if ok then return true end
	core.log("action", "[grug_mobs] " .. self._grug_live_key .. ": a " .. why ..
		" copy (generation " .. tostring(self._grug_live_gen) .. ") removed itself")
	self.object:set_properties({static_save = false})
	self.object:remove()
	return false
end

-- Class-level, like the other on_deactivate hooks (init.lua, start_npcs.lua).
local old_on_deactivate = mobs.mob_class.on_deactivate
mobs.mob_class.on_deactivate = function(self, removal)
	if self._grug_live_key then L.release(self) end
	if old_on_deactivate then
		return old_on_deactivate(self, removal)
	end
end
