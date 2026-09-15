-- Vendor NPCs: eight entity registrations and their deterministic placement
-- at the six race capitals (world.md §3/§7, economy.md §2).
--
-- WHY THE IDENTITY IS IN THE ENTITY NAME
--
-- mobs_redo's register_mob copies only an EXPLICIT whitelist of def fields
-- into the entity table (mods/ENTITIES/mobs/api.lua:3418-3560), and
-- mob_staticdata drops every function field, so a `_grug_vendor_race` written
-- onto `self` would be a runtime-installation problem (the WP6 rule in
-- AGENTS.md) for no gain: nothing about a vendor needs to persist. One entity
-- name per vendor kind makes the identity static, readable in /lua dumps and
-- free of any activation ordering.
--
-- WHY NOT grug_mobs.register_mob
--
-- That wrapper IS the level/XP engine: it calls grug_mobs.register_level_cfg,
-- and ensure_init then derives HP/damage/XP from grug_core.mob_level_at and
-- installs the global nametag of combat_stats.md §6 —
-- "<name> [Lv 42] 250/250" (grug_mobs/levels.lua:147-165). A shopkeeper with
-- a level and a health bar is wrong on both counts, and the aggro/leash/
-- telegraph wrappers it also installs are dead weight on something that never
-- fights. So vendors go straight to mobs:register_mob, and the only piece of
-- grug_mobs they use is the placement helper grug_mobs.add_mob.
--
-- PERMANENCE (api.lua evidence, all three checked, not assumed)
--   * mob_staticdata's unload-delete is skipped for `self.type ~= "npc"`
--     (api.lua:3043-3045) — a vendor is type "npc".
--   * the `static_save = false` stamp that would make the engine forget the
--     object entirely only applies to `self.type == "monster"`
--     (api.lua:3200-3202).
--   * mob_expire returns immediately for `self.type == "npc"`
--     (api.lua:3226-3228).
--   Belt and braces on top of that: `lifetimer = 30000`, which is the
--   >= 20000 exemption the same three sites also honour (the mechanism
--   grug_mobs/rares.lua relies on).
--
-- INVULNERABILITY
--   api.lua:2807-2810 reads `if self.do_punch and not self:do_punch(...) ==
--   false then return true end`, which parses as `(not result) == false` —
--   i.e. ANY TRUTHY return cancels the punch, before weapon wear, before both
--   health subtractions and before check_for_death (the api.lua comment claims
--   the opposite; AGENTS.md documents the gotcha). Our do_punch returns true
--   unconditionally. Environmental damage bypasses on_punch, so every damage
--   source in the def is switched off as well.
--
-- APPEARANCE (WP13 character visuals): a vendor wears its own race's dress and
-- carries nothing — a shopkeeper with a sword reads as a guard. The six race
-- vendors take their race straight from the registry entry they were built
-- from; the two faction Quartermasters take the founding race of their side.
-- The guard skins below stay as the definition's textures, which is what a
-- build without grug_visuals falls back to.

--
-- Registry
--

-- entity name -> {name, kind, faction, race, nametag, salt}
grug_traders.vendors = {}

-- Per-vendor-kind constant that seeds the hourly rotation (stock.lua). Fixed
-- integers, never a table address or an iteration order: the shelf must be
-- reproducible across restarts.
local SALT_GENERAL = {accord = 1, throng = 2}
local RACE_SALT_BASE = 10

-- Nametag adjectives. The race IDS come from the grug_classes registry (never
-- hardcoded); only the English adjective is data, and an unknown race falls
-- back to the registry's own display name.
local RACE_ADJECTIVE = {
	human = "Human",
	dwarf = "Dwarven",
	elf = "Elven",
	orc = "Orcish",
	troll = "Troll",
	undead = "Undead",
}

-- Sorted race ids: pairs() order over the registry is not reproducible, and
-- the salts below must be.
local race_ids = {}
for id in pairs(grug_classes.registered_races) do
	race_ids[#race_ids + 1] = id
end
table.sort(race_ids)

function grug_traders.get_vendor(entity_name)
	return grug_traders.vendors[entity_name]
end

--
-- Access rules
--
-- Returns ok, message. The message is what the player is told when refused.
--

function grug_traders.can_trade(player, vendor)
	if not player or not player:is_player() or not vendor then
		return false, "This vendor is not open for business."
	end
	if vendor.faction then
		-- General vendor: refuses the OPPOSING faction. A factionless player
		-- (a brand-new character still in character creation) is not an enemy
		-- and is served — the same reasoning grug_mobs' guard faction veto
		-- uses for factionless players.
		local pf = grug_factions.get_faction(player)
		if pf and pf ~= vendor.faction then
			return false, "The " .. vendor.nametag .. " does not trade with " ..
				(grug_factions.display_name(pf) or "outsiders") .. "."
		end
	elseif vendor.race then
		-- Race vendor: THE race-exclusive vendor perk of world.md §7.
		local pr = grug_classes.get_race(player)
		if pr ~= vendor.race then
			local def = grug_classes.registered_races[vendor.race]
			return false, "The " .. vendor.nametag .. " trades only with " ..
				((def and def.name) or vendor.race) .. " characters."
		end
	end
	return true
end

-- Same-race discount (world.md §7, 10% — grug_traders.RACE_DISCOUNT). Only a
-- race vendor can grant it, and only on BUY prices.
function grug_traders.has_discount(player, vendor)
	return vendor ~= nil and vendor.race ~= nil and player ~= nil and
		player:is_player() and grug_classes.get_race(player) == vendor.race
end

-- A base price with an ALREADY DECIDED discount flag. Pure function: the
-- trade formspec resolves has_discount once per render (two player-meta
-- reads) and feeds the boolean in here for every one of its ~12 offer rows.
function grug_traders.apply_discount(base_price, discount)
	base_price = math.floor(tonumber(base_price) or 0)
	if base_price <= 0 then
		return 0
	end
	if discount then
		return grug_traders.discounted_price(base_price)
	end
	return base_price
end

-- The buy price a specific player pays a specific vendor for a base price.
function grug_traders.price_for(player, vendor, base_price)
	return grug_traders.apply_discount(base_price,
		grug_traders.has_discount(player, vendor))
end

--
-- Entity definition
--

-- Static nametag. mobs_redo's own mob_class:update_tag recolors the tag by
-- health on every do_env_damage tick (api.lua:636-668, called from
-- api.lua:989) — a green "healthy" tint on a shopkeeper. Overriding the method
-- PER ENTITY (the same trick grug_mobs/levels.lua uses for the level tag)
-- keeps mobs_redo's own call sites while we own the text and the colour.
-- Installed from after_activate because a function field is never serialized
-- into staticdata, so it must be re-installed on every activation; the "did we
-- already write it" flag lives in self.temp, which mob_activate resets per
-- activation exactly like the object's nametag property.
local function install_nametag(self, text)
	self.update_tag = function(s)
		local obj = s.object
		if not obj or not s.temp or s.temp.grug_tag_set then
			return
		end
		s.temp.grug_tag_set = true
		obj:set_properties({nametag = text, nametag_color = "#ffffff"})
	end
	self:update_tag()
end

-- The race a faction Quartermaster is drawn as. Only the two general vendors
-- need it; a race vendor carries its own `race` field.
local VENDOR_FACTION_RACE = {accord = "human", throng = "orc"}

local function vendor_def(vendor, texture)
	local visual = {race = vendor.race or VENDOR_FACTION_RACE[vendor.faction]}
	return {
		description = vendor.nametag,
		nametag = vendor.nametag,
		type = "npc",
		passive = true,
		-- Permanent: see the header. `type = "npc"` already exempts the mob
		-- from all three removal paths; the lifetimer is the second,
		-- independent guard.
		lifetimer = 30000,

		-- Stationary. `walk_chance = 0` never leaves the stand state,
		-- `stand_chance = 100` never leaves it either way, `jump_height = 0`
		-- is what actually disables jumping (api.lua:1119 — mobs_redo has no
		-- `jump` field at all), and zero velocities mean even a nudged mob
		-- has nothing to move with.
		walk_chance = 0,
		stand_chance = 100,
		randomly_turn = false,
		walk_velocity = 0,
		run_velocity = 0,
		jump_height = 0,
		fear_height = 0,
		floats = true,
		pushable = false,
		knock_back = false,
		view_range = 4, -- it only ever needs to notice that you are there
		reach = 0,

		-- Never fights anything, and is never a target worth acquiring.
		attack_type = "dogfight",
		attack_players = false,
		attack_monsters = false,
		attack_animals = false,
		attack_npcs = false,
		owner = "",

		-- Invulnerable to the environment too (do_punch below covers punches).
		hp_min = 100,
		hp_max = 100,
		armor = 1,
		water_damage = 0,
		lava_damage = 0,
		fire_damage = 0,
		air_damage = 0,
		light_damage = 0,
		node_damage = false,
		suffocation = 0,
		fall_damage = false,
		drops = {},
		blood_amount = 0,

		visual = "mesh",
		-- Reused engine/MTG player mesh, referenced BY NAME: Luanti's media
		-- namespace is flat, so a mob here may point at a mesh that lives in
		-- mods/BASE/player_api/models without copying it (wp6_model_notes §5).
		-- Textures are the faction guards' skins — the WP13 asset TODO above.
		mesh = "character.b3d",
		textures = {{texture}},
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		makes_footstep_sound = false,
		animation = {
			stand_start = 0, stand_end = 79, stand_speed = 30,
			walk_start = 168, walk_end = 187, walk_speed = 30,
			run_start = 168, run_end = 187, run_speed = 45,
			punch_start = 189, punch_end = 198, punch_speed = 30,
		},

		-- ANY truthy return cancels the punch outright (api.lua:2807-2810).
		do_punch = function()
			return true
		end,

		after_activate = function(self)
			install_nametag(self, vendor.nametag)
			-- Vendors are registered through plain mobs:register_mob (they must
			-- never get grug_mobs' level/XP engine), so the visuals seam is
			-- called here rather than by a register_mob wrapper. No tier tint
			-- writer: a vendor has no tier. Inert without the mod.
			if core.global_exists("grug_visuals") then
				grug_visuals.apply_entity(self, visual)
			end
			-- A vendor on a WP13 start socket was placed facing the way its
			-- blueprint says (grug_mobs/start_npcs.lua writes `_grug_face_yaw`).
			-- mob_activate hands every mob a RANDOM yaw on every activation
			-- (api.lua:3401), so without this the start vendor turns somewhere
			-- else on every reload. A capital vendor carries no such field and
			-- this is a no-op for it.
			grug_mobs.face_yaw(self, self._grug_face_yaw)
			-- A socket vendor claims its socket, so a twin from a world that
			-- lost a marker removes itself instead of standing in its own shop
			-- (grug_mobs/start_npcs.lua). A no-op for the two fixed capital
			-- offsets, which carry no settlement key.
			grug_mobs.start_npc_claim(self)
		end,

		on_rightclick = function(self, clicker)
			grug_traders.open(clicker, vendor.name, self.object:get_pos())
		end,
	}
end

local function register_vendor(vendor, texture)
	grug_traders.vendors[vendor.name] = vendor
	-- NON-COMBATANT (user ruling, WP13 playtest round 2, 2026-09-15): nothing in
	-- the world may acquire a shopkeeper. `attack_npcs = false` above only says
	-- what a VENDOR attacks; this says what may attack it, and it is the same
	-- flag the villagers and elders carry (grug_mobs/verbs.lua). It wraps
	-- `after_activate`, so it must run on the finished definition.
	mobs:register_mob(vendor.name,
		grug_mobs.noncombatant(vendor_def(vendor, texture)))
end

local GUARD_TEXTURE = {
	accord = "grug_mobs_guard_accord.png",
	throng = "grug_mobs_guard_throng.png",
}

-- The two general vendors, one per faction.
for _, faction_id in ipairs(grug_core.faction_ids) do
	register_vendor({
		name = "grug_traders:vendor_general_" .. faction_id,
		kind = "general",
		faction = faction_id,
		nametag = (grug_core.factions[faction_id].name) .. " Quartermaster",
		salt = SALT_GENERAL[faction_id],
	}, GUARD_TEXTURE[faction_id])
end

-- One race-exclusive vendor per race (world.md §7).
for index, race_id in ipairs(race_ids) do
	local def = grug_classes.registered_races[race_id]
	register_vendor({
		name = "grug_traders:vendor_race_" .. race_id,
		kind = "race",
		race = race_id,
		nametag = (RACE_ADJECTIVE[race_id] or def.name) .. " Quartermaster",
		salt = RACE_SALT_BASE + index,
	}, GUARD_TEXTURE[def.faction])
end

--
-- Placement
--
-- SOCKET IF REGISTERED, OFFSET OTHERWISE (docs/research/wp13-npc-sockets-
-- contract.md section 3: "the two vendor offsets in `vendors.lua` migrate to
-- `vendor` sockets at that moment and not before").
--
-- A capital whose core has landed exports two `vendor` sockets, and the one
-- placement engine that serves settlement sockets -- `grug_mobs/start_npcs.lua`
-- -- puts the two traders on them, through the `vendor` role resolver at the
-- bottom of this file. This mod then owns NO slot for that capital at all, or
-- the two mechanisms would both place a trader and the capital would end up
-- with four.
--
-- A capital whose core has NOT landed keeps the two fixed offsets below and the
-- globalstep that serves them, which is the whole of the pre-WP13 behaviour.
-- R7's stable capital anchor is the only origin in either case; there is no
-- retired platform state, discovery or height fallback.
--
-- Which capitals have sockets is read from the registry, not from a list of
-- capital names: a settlement is registered under a key this mod does not know,
-- so what identifies a race's capital is its published capital ANCHOR, the same
-- authority the offsets are measured from.
local SLOT_OFFSETS = {
	general = {x = -5, z = 3},
	race = {x = 5, z = 3},
}

local slots = {}

local function socketed_capitals()
	local socketed = {}
	if type(grug_core.settlement_socket_settlements) ~= "function" then
		return socketed
	end
	local settlements = grug_core.settlement_socket_settlements()
	for index = 1, #settlements do
		local record = settlements[index]
		local race = grug_classes.registered_races[record.race_id]
		local capital = race and grug_core.capital_anchor(race.faction,
			record.race_id) or nil
		if type(capital) == "table" and record.anchor.x == capital.x and
				record.anchor.y == capital.y and record.anchor.z == capital.z then
			local vendors = 0
			local sockets = grug_core.settlement_sockets_at(record.key)
			for socket_index = 1, #sockets do
				if sockets[socket_index].role == "vendor" then vendors = vendors + 1 end
			end
			if vendors > 0 then socketed[record.race_id] = record.key end
		end
	end
	return socketed
end

-- Built after every mod has loaded, because that is when grug_mapgen has
-- published its socket sets; before then the registry is legitimately empty and
-- this mod would give every capital the offsets.
local function build_slots()
	local socketed = socketed_capitals()
	local offset_races = 0
	for _, race_id in ipairs(race_ids) do
		local race = grug_classes.registered_races[race_id]
		if not race then error("grug_traders: race registry differs: " .. race_id, 0) end
		local capital = grug_core.capital_anchor(race.faction, race_id)
		if type(capital) ~= "table" or type(capital.x) ~= "number" or
				type(capital.y) ~= "number" or type(capital.z) ~= "number" then
			error("grug_traders: capital authority differs: " .. race_id, 0)
		end
		if socketed[race_id] then
			core.log("action", "[grug_traders] " .. race_id ..
				" capital vendors come from the sockets of " .. socketed[race_id])
		else
			offset_races = offset_races + 1
			slots[#slots + 1] = {
				entity = "grug_traders:vendor_general_" .. race.faction,
				race = race_id,
				x = capital.x + SLOT_OFFSETS.general.x,
				y = capital.y + 1,
				z = capital.z + SLOT_OFFSETS.general.z,
			}
			slots[#slots + 1] = {
				entity = "grug_traders:vendor_race_" .. race_id,
				race = race_id,
				x = capital.x + SLOT_OFFSETS.race.x,
				y = capital.y + 1,
				z = capital.z + SLOT_OFFSETS.race.z,
			}
		end
	end
	if #slots ~= offset_races * 2 then
		error("grug_traders: capital slot population differs", 0)
	end
end

local CHECK_INTERVAL = 5 -- s (AGENTS.md performance rule: dtime accumulator)
-- Only slots a player could actually see are checked — and the number is
-- COUPLED to object activation, it is not a taste decision. vendor_present
-- below asks core.get_objects_inside_radius, which only ever sees ACTIVATED
-- objects, and activation reaches `active_block_range * 16` nodes around a
-- player. `active_block_range` defaults to 4 on desktop but to 2 in other
-- platform profiles and is user-tunable down to 1. At 2 the activation radius
-- is 32 nodes: a gate any wider than that would look at a slot whose existing
-- vendor is loaded but INACTIVE, conclude "nobody here", and spawn a second
-- one — every 5 s, forever, because `type = "npc"` entities never expire.
-- 24 keeps the slot inside the activation radius with margin at 2 (and the
-- PRESENCE_RADIUS 8 sphere around it too: 24 + 8 = 32). The only visible
-- consequence is that vendors appear at 24 m instead of 48 m, and vendors are
-- stationary. active_block_range = 1 (16 nodes) is out of scope: at that
-- setting the engine deactivates a mob standing next to the player.
local PLAYER_RANGE = 24
local PRESENCE_RADIUS = 8 -- "is a vendor of this kind already standing here"

-- `positions` is the hoisted per-interval array from the globalstep below —
-- get_pos() is a C call per player, and calling it inside the 12-slot loop
-- would mean 12 x 100 of them every interval instead of 100.
--
-- y = nil runs the check HORIZONTALLY only. That form is the pre-filter used
-- before the capital's platform y is resolved: it can only be more permissive
-- than the full 3D check that follows, so no slot is lost by it.
local function player_near(positions, x, y, z)
	for i = 1, #positions do
		local p = positions[i]
		local dx, dz = p.x - x, p.z - z
		local d2 = dx * dx + dz * dz
		if y then
			local dy = p.y - y
			d2 = d2 + dy * dy
		end
		if d2 <= PLAYER_RANGE * PLAYER_RANGE then
			return true
		end
	end
	return false
end

-- Only ever called for a slot that already passed the player-range and
-- node-loaded gates, i.e. a handful of times a minute in the whole world.
local function vendor_present(pos, entity_name)
	local objs = core.get_objects_inside_radius(pos, PRESENCE_RADIUS)
	for i = 1, #objs do
		local ent = objs[i]:get_luaentity()
		if ent and ent.name == entity_name then
			return true
		end
	end
	return false
end

local acc = 0

core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < CHECK_INTERVAL then
		return
	end
	acc = 0
	local players = core.get_connected_players()
	if #players == 0 then
		return
	end
	-- Hoisted once per interval instead of once per (slot, player): get_pos()
	-- is a C call, and the loop below runs 12 slots x every player.
	local positions = {}
	for i = 1, #players do
		local p = players[i]:get_pos()
		if p then
			positions[#positions + 1] = p
		end
	end
	if #positions == 0 then
		return
	end
	for i = 1, #slots do
		local slot = slots[i]
		if player_near(positions, slot.x, slot.y, slot.z) then
				local pos = {x = slot.x, y = slot.y, z = slot.z}
				local node = core.get_node_or_nil(pos)
				local ndef = node and core.registered_nodes[node.name]
				-- node == nil: block not loaded, nothing to decide yet.
				if node and node.name ~= "ignore" and
						not (ndef and ndef.walkable) and
						not vendor_present(pos, slot.entity) then
					-- ignore_count = true: a vendor family has no mobs:spawn
					-- row, so mobs:add_mob's per-name area cap would default to
					-- 1 for the shared general-vendor entity and only ever let
					-- ONE of the three capitals of a faction have one
					-- (api.lua:3663-3667, the reason camps.lua passes it too).
					-- A decline (no player in the active area, active mob
					-- limit) simply means "retry in 5 s".
					local ent = grug_mobs.add_mob(pos,
						{name = slot.entity, ignore_count = true})
					if ent then
						core.log("action", "[grug_traders] " .. slot.entity ..
							" placed at " .. core.pos_to_string(pos))
					end
				end
		end
	end
end)

-- Vendors are never despawned by us: the engine unloads them with their
-- mapblock and mob_activate brings them back. No ObjectRef is stored anywhere
-- in this mod — the slot table holds coordinates only (AGENTS.md: refs must be
-- re-fetched across any callback boundary).

--
-- The socketed settlements (WP13)
--
-- A settlement's vendor stands on the `vendor` socket its blueprint exports
-- (docs/research/wp13-npc-sockets-contract.md), whether that settlement is a
-- start or a capital whose core has landed. The socket says WHERE and of which
-- family, this mod says WHICH ENTITY, and `grug_mobs/start_npcs.lua` owns the
-- one placement engine that serves every settlement NPC -- including its
-- persistence, which must survive a restart in which no player is anywhere
-- near the settlement and therefore cannot be a presence scan (see that
-- file's header). The offsets and the globalstep above serve exactly the
-- capitals whose core has not landed yet.
--
if type(grug_mobs.register_start_socket_role) == "function" then
	grug_mobs.register_start_socket_role("vendor", function(socket, settlement)
		if socket.kind == "general" then
			return "grug_traders:vendor_general_" .. settlement.faction_id
		end
		-- The race-exclusive vendor of world.md §7 -- the start roster's own
		-- kind, and the same entity the race's capital gets.
		return "grug_traders:vendor_race_" .. settlement.race_id
	end)
else
	core.log("error", "[grug_traders] grug_mobs offers no settlement socket role " ..
		"registry; the settlements get no vendor")
end

-- Last: the capital slots this mod still owns itself, which is every capital
-- whose core has not landed. It has to run after grug_mapgen published its
-- socket sets, and `register_on_mods_loaded` is where that is guaranteed.
core.register_on_mods_loaded(build_slots)
