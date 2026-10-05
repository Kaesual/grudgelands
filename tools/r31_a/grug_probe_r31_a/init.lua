-- Round 31 Lane A engine probe (disposable, never shipped): character looks
-- on a real world, over two boots of the same world (tools/r31_a/engine.sh).
--
-- Boot 1:
--   1. The look panel of the character-creation window (Round 35), driven
--      through its real functions on a player stand-in (a headless server
--      has no client): the panel builds with a model[] preview, next/random
--      change the draft, store keeps the look, a second store cannot change
--      it. The stand-in's meta lives in this mod's storage, so it survives
--      the reboot the way a real player's meta does.
--   2. A start settlement (the first fully placed one) after its NPCs: its
--      blocks are force-loaded so every NPC activates, and every humanoid NPC
--      there is read -- race drawn (the settlement's), a rolled seed, a
--      layered texture (no painted race skin), how many different looks.
--      Each NPC's seed and texture are stored by its socket.
-- Boot 2 (same world): the stand-in's look reads back to the same texture,
--   and every NPC of boot 1 comes back with the same seed and texture.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r31_a_probe] "
local storage = core.get_mod_storage()
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local boot = storage:get_int("boot") + 1
storage:set_int("boot", boot)
log("boot " .. boot)

local function finish()
	log(("RESULT %s boot=%d checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", boot, checks, failures))
	core.request_shutdown("r31 a probe done", false, 0)
end

local function wait(test, seconds, label, done)
	local left = seconds
	local function poll()
		if test() then return done() end
		left = left - 1
		if left <= 0 then
			check(false, "timed out waiting for " .. label)
			return finish()
		end
		core.after(1, poll)
	end
	poll()
end

------------------------------------------------------------------------------
-- The player stand-in: meta in mod storage, nothing else a look needs.
------------------------------------------------------------------------------
local NAME = "r31a_creator"
local function stand_in()
	local p = {}
	local meta = {}
	function meta:get_string(key) return storage:get_string("meta:" .. key) end
	function meta:set_string(key, value) storage:set_string("meta:" .. key, value) end
	function p:get_player_name() return NAME end
	function p:is_player() return true end
	function p:get_meta() return meta end
	function p:get_inventory() return nil end
	return p
end

-- grug_visuals.apply writes to player_api's model of a CONNECTED player; the
-- stand-in is drawn by composing its spec instead.
local real_apply = grug_visuals.apply
grug_visuals.apply = function(player)
	if player.get_player_name and player:get_player_name() == NAME then
		return grug_visuals.compose(grug_visuals.player_spec(player))
	end
	return real_apply(player)
end
local real_cosmetic = grug_inventory and grug_inventory.get_cosmetic_weapon
if real_cosmetic then
	grug_inventory.get_cosmetic_weapon = function(player)
		if player:get_player_name() == NAME then return nil end
		return real_cosmetic(player)
	end
end

local function player_part()
	local player = stand_in()
	local panel = grug_visuals.creation_panel
	if boot == 1 then
		player:get_meta():set_string("grug_factions:faction", "throng")
		player:get_meta():set_string("grug_classes:race", "troll")
		check(grug_classes.get_race(player) == "troll", "stand-in is a troll")
		check(not grug_visuals.has_look(player), "no look before creation")
		local look = panel.roll("troll")
		local form = panel.formspec("troll", look, 3.8, 4.7, 10.8, 5.5)
		check(form:find("model[", 1, true) ~= nil, "the panel has a model[] preview")
		check(form:find("grug_visuals_troll_body.png", 1, true) ~= nil,
			"the preview draws the troll's layers")
		check(panel.act("troll", look, {class_mage = "1"}) == nil,
			"the panel ignores fields that are not its own")
		local after_next = panel.act("troll", look, {look_next_style = ">"})
		check(after_next ~= nil and
			panel.formspec("troll", after_next, 3.8, 4.7, 10.8, 5.5) ~= form,
			"next changes the draft")
		local rolled = panel.act("troll", after_next, {look_random = "Random"})
		check(panel.store(player, rolled), "store keeps the look")
		check(grug_visuals.has_look(player), "the look is stored")
		local stored = player:get_meta():get_string("grug_visuals:look")
		check(stored:match("^%d,%d,%d,%d,%d$") ~= nil, "stored look " .. stored)
		check(not panel.store(player, panel.roll("troll")), "a second store is refused")
		check(player:get_meta():get_string("grug_visuals:look") == stored,
			"a stored look cannot be changed")
		local texture = grug_visuals.compose(grug_visuals.player_spec(player)).textures[1]
		storage:set_string("player_texture", texture)
		log("stand-in look " .. stored .. ", texture " .. #texture .. " chars")
	else
		check(grug_visuals.has_look(player), "the look is still stored")
		local texture = grug_visuals.compose(grug_visuals.player_spec(player)).textures[1]
		check(texture == storage:get_string("player_texture"),
			"the stand-in is drawn the same after the reboot")
		log("stand-in look " .. player:get_meta():get_string("grug_visuals:look"))
	end
end

------------------------------------------------------------------------------
-- A start settlement's NPCs.
------------------------------------------------------------------------------
-- The first start whose whole roster is placed (on seed 42 not every start's
-- sockets are loaded at start-ready); boot 2 reads the same one again.
local function settlement()
	local wanted = storage:get_string("settlement")
	for _, row in ipairs(grug_mobs.start_npc_census()) do
		if wanted ~= "" then
			if row.key == wanted then return row end
		elseif row.kind == "start" and row.roster > 0 and row.marked >= row.roster then
			storage:set_string("settlement", row.key)
			return row
		end
	end
	return nil
end

local function placed()
	local row = settlement()
	return row ~= nil and row.marked > 0
end

local function forceload(anchor)
	local count = 0
	for x = anchor.x - 80, anchor.x + 80, 16 do
		for z = anchor.z - 80, anchor.z + 80, 16 do
			for y = anchor.y - 32, anchor.y + 48, 16 do
				if core.forceload_block({x = x, y = y, z = z}, true, -1) then
					count = count + 1
				end
			end
		end
	end
	return count
end

local function read_npcs(anchor)
	local out = {}
	for _, object in ipairs(core.get_objects_inside_radius(anchor, 120)) do
		local entity = object:get_luaentity()
		if entity and entity._grug_visual_skin and entity._grug_start and
				entity._grug_socket then
			out[entity._grug_start .. "/" .. tostring(entity._grug_socket)] = {
				name = entity.name, seed = entity._grug_look_seed,
				skin = entity._grug_visual_skin}
		end
	end
	return out
end

local function npc_part(done)
	wait(function() return grug_core.world_preparation_status().ready and placed() end,
		240, "a start placed", function()
		local row = settlement()
		local race = row.race_id
		local anchor = grug_core.settlement_socket_anchor(row.key)
		log(("settlement %s (%s) roster %d marked %d; %d blocks force-loaded"):format(
			row.key, race, row.roster, row.marked, forceload(anchor)))
		core.after(15, function()
			local npcs = read_npcs(anchor)
			local count, looks, families = 0, {}, {}
			for key, npc in pairs(npcs) do
				count = count + 1
				looks[npc.skin] = true
				families[npc.name] = (families[npc.name] or 0) + 1
				check(type(npc.seed) == "number", key .. " has a rolled seed")
				check(npc.skin:find("grug_visuals_" .. race .. "_body.png", 1, true) ~= nil,
					key .. " (" .. npc.name .. ") is drawn as a " .. race)
				check(not npc.skin:find("grug_visuals_skin_" .. race .. ".png", 1, true),
					key .. " wears no painted race skin")
			end
			local distinct = 0
			for _ in pairs(looks) do distinct = distinct + 1 end
			-- Who shares a look (a few may: a helmet hides the hair, and a
			-- roll can repeat).
			local by_skin = {}
			for key, npc in pairs(npcs) do
				by_skin[npc.skin] = by_skin[npc.skin] or {}
				table.insert(by_skin[npc.skin], key .. " seed " .. tostring(npc.seed))
			end
			for _, keys in pairs(by_skin) do
				if #keys > 1 then
					table.sort(keys)
					log("same look: " .. table.concat(keys, ", "))
				end
			end
			local parts = {}
			for name, n in pairs(families) do parts[#parts + 1] = name .. " " .. n end
			table.sort(parts)
			log(("%d NPCs read, %d different textures: %s"):format(count, distinct,
				table.concat(parts, ", ")))
			check(count >= 10, "enough NPCs read (" .. count .. ")")
			check(distinct >= count / 2, "the NPCs do not share one look")
			if boot == 1 then
				storage:set_string("npcs", core.serialize(npcs))
			else
				local before = core.deserialize(storage:get_string("npcs")) or {}
				local compared = 0
				for key, npc in pairs(before) do
					local now = npcs[key]
					if check(now ~= nil, key .. " is back") then
						compared = compared + 1
						check(now.seed == npc.seed, key .. " kept its seed")
						check(now.skin == npc.skin, key .. " kept its look")
					end
				end
				log(compared .. " NPCs compared with boot 1")
			end
			done()
		end)
	end)
end

core.after(1, function()
	player_part()
	npc_part(finish)
end)
