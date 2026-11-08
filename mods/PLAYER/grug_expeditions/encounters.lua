-- Encounters (Round 71): the rooms of a run and its boss. init.lua's encounters(run)
-- gives the markers; a room's mobs appear when a player of the run comes near, as
-- the rift boss does, once: nothing here places a room again, and each room is one
-- pack from then on (packs.lua: a wipe refills it, what a pack lost for good stays
-- dead). An idle server pays nothing: the one-second pass runs only while a run has
-- a player inside and a room still waiting.
--
-- Every mob carries in its first staticdata, so it holds from the first activation:
--   _grug_spawn_level  the run's level, before the first tick (levels.lua)
--   _grug_expedition   the run's id: item levels above 60 (grug_quality), no ore
--   lifetimer          above 20000: mobs_redo's far despawn leaves it alone, so a
--                      pack the party walked past waits in its saved block. Not
--                      static_save = false: such a mob goes with its block
--                      (serverenvironment.cpp deactivateFarObjects). Preparation's
--                      delete_area takes whatever a run left behind
--   _grug_authored     the active-mob limit neither refuses nor removes it
--   _grug_pack         its body key (packs.lua), with the fields of a chase that
--                      does not end
--
-- A marker's tier is `normal`, `elite` or `boss`, at most one boss of count 1 per
-- template. The boss is an elite with a ledger id, never the `boss` tier of
-- levels.lua, whose HP are flat: HP come from its definition's `_grug_hp_scale`.
-- Its death settles credit only (bosses.lua, no lockout, no reward) and opens the
-- door; it is a pack of one, so a wipe heals it and sends it home and its attempt
-- starts over. Its registered definition names its fixed name: a world slot in
-- data/names.json.
local M = grug_expeditions
local path = core.get_modpath(core.get_current_modname())
local loot = dofile(path .. "/loot.lua")
local packs = dofile(path .. "/packs.lua")

local SPAWN_RANGE = grug_mobs.rift_rules.SPAWN_RANGE
local PASS_SECONDS = 1
-- One mob per offset round its marker, the marker's cell first.
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}}
local SPREAD_REACH = 4
local TIERS = {normal = true, elite = true, boss = true}

local states = {} -- run -> {rooms, boss_id, boss_dead}
local running = false

local function state_of(run)
	local state = states[run]
	if state then return state end
	state = {rooms = {}}
	for _, row in ipairs(M.encounters(run)) do
		local room = state.rooms[row.room]
		if not room then
			room = {}
			state.rooms[row.room] = room
		end
		room[#room + 1] = {row = row, left = row.count}
		if row.tier == "boss" then
			state.boss_id = "expedition:" .. run.expedition .. ":" .. run.id
		end
	end
	for _, room in pairs(state.rooms) do room.pack = packs.new(run, state.boss_id) end
	states[run] = state
	return state
end

-- The chest's gate: the boss is dead, or the template has none.
function M.rewards_open(run)
	local state = states[run]
	return state ~= nil and (state.boss_id == nil or state.boss_dead == true)
end

local function spot(marker, index)
	local offset = SPREAD[(index - 1) % #SPREAD + 1]
	local pos = {x = marker.x + offset[1], y = marker.y, z = marker.z + offset[2]}
	return packs.standable(pos) and pos or {x = marker.x, y = marker.y, z = marker.z}
end

-- Places what is still missing; true when the room is done. A mob the engine
-- refused is tried again on the next pass.
local function spawn_room(run, room)
	local done = true
	for _, entry in ipairs(room) do
		local row = entry.row
		core.load_area(vector.subtract(row.pos, SPREAD_REACH), vector.add(row.pos, SPREAD_REACH))
		while entry.left > 0 do
			if not packs.add(room.pack, row, spot(row.pos, row.count - entry.left + 1)) then
				core.log("error", "[grug_expeditions] " .. row.mob .. " could not be placed in " ..
					run.expedition)
				done = false
				break
			end
			entry.left = entry.left - 1
		end
	end
	return done
end

local function near(room, pos)
	local range2 = SPAWN_RANGE * SPAWN_RANGE
	for _, entry in ipairs(room) do
		local at = entry.row.pos
		local dx, dz = pos.x - at.x, pos.z - at.z
		if dx * dx + dz * dz <= range2 and math.abs(pos.y - at.y) <= SPAWN_RANGE then
			return true
		end
	end
	return false
end

local pass
local function start_pass()
	if running then return end
	running = true
	core.after(0, pass)
end

pass = function()
	local waiting = false
	for run, state in pairs(states) do
		if next(state.rooms) then
			for name in pairs(run.inside) do
				waiting = true
				local player = core.get_player_by_name(name)
				local pos = player and player:get_hp() > 0 and player:get_pos()
				for key, room in pairs(pos and state.rooms or {}) do
					if near(room, pos) and spawn_room(run, room) then
						state.rooms[key] = nil
					end
				end
			end
		end
	end
	if waiting then
		core.after(PASS_SECONDS, pass)
	else
		running = false
	end
end

M.register_on_ready(state_of)
M.register_on_enter(start_pass)
M.register_on_end(function(run)
	local state = states[run]
	if state and state.boss_id then grug_mobs.boss_attempt_reset(state.boss_id) end
	states[run] = nil
	-- Live objects go with the run, a step before any new preparation's delete_area,
	-- which would leave the engine their saved copies to look for. Attached ones stay:
	-- a player's name tag and wield go on with them, a mob's follow it by their orphan
	-- checks.
	for object in core.objects_in_area(run.minp, run.maxp) do
		if not object:is_player() and not object:get_attach() then object:remove() end
	end
end)

local function boss_died(self)
	local pos = self.object and self.object:get_pos()
	local run = pos and M.run_at(pos)
	local state = run and run.id == self._grug_expedition and states[run]
	if not state or state.boss_dead then return end
	state.boss_dead = true
	grug_mobs.boss_settle(state.boss_id, self, nil, "expedition:" .. run.expedition)
	M.open_door(run)
end

-- Every death cause reaches this boundary, after XP and the kill credit.
local settle_mob_death = grug_mobs.settle_mob_death
function grug_mobs.settle_mob_death(self)
	local result = settle_mob_death(self)
	if self._grug_expedition and self._grug_boss_id then boss_died(self) end
	return result
end

-- Ores and gems come from nodes only, and the boss pays through the chest: it
-- drops nothing, the coin bag included.
local ores = loot.ore_items(grug_materials.RESOURCES)
local item_drop_filter = grug_mobs._item_drop_filter
function grug_mobs._item_drop_filter(self, drops)
	if not self._grug_expedition then return item_drop_filter(self, drops) end
	if self._grug_boss_id then return nil end
	local rows = item_drop_filter(self, drops)
	if not rows then return nil end
	local kept = {}
	for _, row in ipairs(rows) do
		if not ores[row.name] then kept[#kept + 1] = row end
	end
	return kept
end

-- A broken marker stops the server here, not in a run.
core.register_on_mods_loaded(function()
	loot.check(ores)
	for _, row in ipairs(M.catalogue.EXPEDITIONS) do
		if not loot.TABLES[row.id] then error("[grug_expeditions] no loot table for " .. row.id, 0) end
	end
	for name, tpl in pairs(M.templates) do
		local bosses = 0
		for _, row in ipairs(tpl.encounters) do
			local where = "[grug_expeditions] template " .. name .. ": "
			if not core.registered_entities[row.mob] then error(where .. "no mob " .. row.mob, 0) end
			if not TIERS[row.tier] then error(where .. "no tier " .. row.tier, 0) end
			if row.tier == "boss" then bosses = bosses + row.count end
		end
		if bosses > 1 then error("[grug_expeditions] template " .. name .. ": two bosses", 0) end
	end
end)

assert(loadfile(path .. "/chest.lua"))(loot)
