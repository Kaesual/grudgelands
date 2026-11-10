-- Encounters (Round 71): the rooms of a run and its boss. init.lua's encounters(run)
-- gives the markers; a room's mobs appear when a player of the run comes near, as
-- the rift boss does, once: nothing here places a room again, and each room is one
-- pack from then on (packs.lua: a wipe refills it, what a pack lost for good stays
-- dead). An idle server pays nothing: the one-second pass runs only while a run has
-- a player inside and a room still waiting.
--
-- Every mob carries in its first staticdata, so it holds from the first activation
-- (packs.lua's spawn is the one place an Expedition's mob is made, boss included, so a
-- new encounter or Expedition gets all of it without a line of its own):
--   _grug_spawn_level  the run's level, before the first tick (levels.lua)
--   _grug_expedition   the run's id, and the mark of an Expedition's mob: item levels
--                      above 60 (grug_quality), no ore; no undead truce (grug_mobs
--                      init.lua truce_active) and the full view range towards a
--                      player of any level (aggro.lua player_aggro_radius)
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
-- data/names.json. Since Round 72 it follows the bosses' reset rules
-- (grug_mobs/boss_floor.lua): its room is its range, the floor its body walks from its
-- marker inside the template's envelope (the places `boss_room_min` and
-- `boss_room_max`, two opposite corners; a template without them leaves it to the
-- navigation's give-up), a target who leaves the room leaves its list, and 15 s
-- without an attack reset it; the reset is the wipe.
--
-- Round 73 adds two kinds of room:
--   AMBUSH ROOM  named by a template's `ambush` line: never placed by proximity. It
--                waits for its candidate's zone (traps.lua), which hands it over with
--                M._spring_room(run, room, player): placed then, every mob set on that
--                player at once (packs.lua pull), a pack like every other from then on.
--                An unarmed candidate's room is never placed.
--   CRITTERS     a room of `critter` markers (CRITTERS, the roster): placed by
--                proximity like a room, but no pack (packs.lua add_critter): scenery
--                that drops nothing, settles no kill, starts no fight and gates nothing.
--                Never placed again; none spawn naturally (guard.lua).
local M = grug_expeditions
local path = core.get_modpath(core.get_current_modname())
local loot = dofile(path .. "/loot.lua")
local packs = dofile(path .. "/packs.lua")

local SPAWN_RANGE = grug_mobs.rift_rules.SPAWN_RANGE
local PASS_SECONDS = 1
-- One mob per offset round its marker, the marker's cell first.
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}}
local SPREAD_REACH = 4
local TIERS = {normal = true, elite = true, boss = true, critter = true}
-- The Expeditions' critters (Round 73, concept section 4.8): the critter tier of levels.lua.
local CRITTERS = {["grug_mobs:cave_bat"] = true, ["grug_mobs:cave_crawler"] = true,
	["grug_mobs:bone_weevil"] = true}

local states = {} -- run -> {rooms, ambush, boss_id, boss_dead}
local running = false

-- The rooms the run's template names in `ambush` lines: room -> true.
local function ambush_rooms(run)
	local def = M.definition(run.expedition)
	local tpl = def and def.template and M.templates[def.template]
	local rooms = {}
	for _, row in ipairs(tpl and tpl.ambushes or {}) do rooms[row.room] = true end
	return rooms
end

local function state_of(run)
	local state = states[run]
	if state then return state end
	state = {rooms = {}, ambush = {}}
	local waits = ambush_rooms(run)
	for _, row in ipairs(M.encounters(run)) do
		local set = waits[row.room] and state.ambush or state.rooms
		local room = set[row.room]
		if not room then
			room = {}
			set[row.room] = room
		end
		room[#room + 1] = {row = row, left = row.count}
		room.critter = row.tier == "critter"
		if row.tier == "boss" then
			state.boss_id = "expedition:" .. run.expedition .. ":" .. run.id
		end
	end
	for _, set in ipairs({state.rooms, state.ambush}) do
		for _, room in pairs(set) do
			if not room.critter then room.pack = packs.new(run, state.boss_id) end
		end
	end
	states[run] = state
	return state
end

-- The chest's gate: the boss is dead, or the template has none.
function M.rewards_open(run)
	local state = states[run]
	return state ~= nil and (state.boss_id == nil or state.boss_dead == true)
end

-- A spread cell needs room, no harm and a floor that holds (Round 73: no spread spot
-- over a lava basin or a pit's edge); else the marker's own cell.
local function spot(marker, index)
	local offset = SPREAD[(index - 1) % #SPREAD + 1]
	local pos = {x = marker.x + offset[1], y = marker.y, z = marker.z + offset[2]}
	return packs.standable(pos) and packs.has_floor(pos) and pos or
		{x = marker.x, y = marker.y, z = marker.z}
end

-- Places what is still missing; true when the room is done. A mob the engine
-- refused is tried again on the next pass.
local function spawn_room(run, room)
	local done = true
	for _, entry in ipairs(room) do
		local row = entry.row
		core.load_area(vector.subtract(row.pos, SPREAD_REACH), vector.add(row.pos, SPREAD_REACH))
		while entry.left > 0 do
			local at = spot(row.pos, row.count - entry.left + 1)
			local placed
			if room.critter then
				placed = packs.add_critter(run, row, at)
			else
				placed = packs.add(room.pack, row, at)
			end
			if not placed then
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

-- The ambush's half here (traps.lua fires it): the waiting room `key` is placed now
-- and set on `player` at once. A mob the engine refused joins the proximity pass.
-- Once only: the room leaves the waiting set.
function M._spring_room(run, key, player)
	local state = states[run]
	local room = state and state.ambush[key]
	if not room then return end
	state.ambush[key] = nil
	if not spawn_room(run, room) then
		state.rooms[key] = room
		start_pass()
	end
	packs.pull(room.pack, player)
end

M.register_on_ready(state_of)
M.register_on_enter(start_pass)
M.register_on_end(function(run)
	local state = states[run]
	if state and state.boss_id then
		grug_mobs.boss_attempt_reset(state.boss_id)
		if grug_mobs.boss_floor_forget then grug_mobs.boss_floor_forget(state.boss_id) end
	end
	states[run] = nil
	-- Live objects go with the run, a step before any new preparation's delete_area,
	-- which would leave the engine their saved copies to look for. Attached ones stay:
	-- a player's name tag and wield go on with them, a mob's follow it by their orphan
	-- checks.
	for object in core.objects_in_area(run.minp, run.maxp) do
		if not object:is_player() and not object:get_attach() then object:remove() end
	end
end)

-- A catalogue row's wall signs (`signs`, place name -> text; The Second Shift's shift
-- board): their text once the box is written. The text entity follows the node
-- (grug_text), and the next preparation clears both.
M.register_on_ready(function(run)
	for place, text in pairs(M.definition(run.expedition).signs or {}) do
		local pos = run.places[place]
		if pos then
			core.get_meta(pos):set_string("text", text)
			grug_text.refresh(pos)
		end
	end
end)

-- The boss's room, the bounds of its floor (grug_mobs/boss_floor.lua): the envelope's
-- columns over the whole box's height, or nil.
function grug_mobs.expedition_boss_room(self)
	local home = self._grug_home
	local run = home and M.run_at(home)
	if not run or run.id ~= self._grug_expedition then return nil end
	local a, b = run.places.boss_room_min, run.places.boss_room_max
	if not (a and b) then return nil end
	return {x0 = math.min(a.x, b.x), x1 = math.max(a.x, b.x),
		z0 = math.min(a.z, b.z), z1 = math.max(a.z, b.z), y0 = run.minp.y, y1 = run.maxp.y}
end

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
-- drops nothing, the coin bag included. Nor does a critter (Round 73).
local ores = loot.ore_items(grug_materials.RESOURCES)
local item_drop_filter = grug_mobs._item_drop_filter
function grug_mobs._item_drop_filter(self, drops)
	if not self._grug_expedition then return item_drop_filter(self, drops) end
	if self._grug_boss_id or self._grug_scenery then return nil end
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
		local waits = {}
		for _, row in ipairs(tpl.ambushes or {}) do waits[row.room] = true end
		for _, row in ipairs(tpl.encounters) do
			local where = "[grug_expeditions] template " .. name .. ": "
			local def = core.registered_entities[row.mob]
			if not def then error(where .. "no mob " .. row.mob, 0) end
			if not TIERS[row.tier] then error(where .. "no tier " .. row.tier, 0) end
			if row.tier == "boss" then bosses = bosses + row.count end
			if row.tier == "critter" and not CRITTERS[row.mob] then
				error(where .. row.mob .. " is no critter", 0)
			end
			-- An ambush fights in the dark: melee only, no shot from the black.
			if waits[row.room] and (def.attack_type == "shoot" or def.attack_type == "dogshoot") then
				error(where .. "the ambush " .. row.room .. " holds the archer " .. row.mob, 0)
			end
		end
		if bosses > 1 then error("[grug_expeditions] template " .. name .. ": two bosses", 0) end
	end
end)

assert(loadfile(path .. "/chest.lua"))(loot)
