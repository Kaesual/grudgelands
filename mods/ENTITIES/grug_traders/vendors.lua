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
-- ASSET TODO (WP13): vendors reuse the faction guards' character.b3d skins, so
-- a Quartermaster currently looks exactly like a guard. Real vendor art —
-- and race-specific skins for the six race vendors — belongs to the WP13
-- settlement/asset pass.

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

-- The buy price a specific player pays a specific vendor for a base price.
function grug_traders.price_for(player, vendor, base_price)
	base_price = math.floor(tonumber(base_price) or 0)
	if base_price <= 0 then
		return 0
	end
	if grug_traders.has_discount(player, vendor) then
		return grug_traders.discounted_price(base_price)
	end
	return base_price
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

local function vendor_def(vendor, texture)
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
		floats = 1,
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
		end,

		on_rightclick = function(self, clicker)
			grug_traders.open(clicker, vendor.name, self.object:get_pos())
		end,
	}
end

local function register_vendor(vendor, texture)
	grug_traders.vendors[vendor.name] = vendor
	mobs:register_mob(vendor.name, vendor_def(vendor, texture))
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
-- Deterministic and WITHOUT any mapgen change: a mapgen edit would force a
-- fresh world, and existing test worlds must get vendors too. Two slots per
-- race capital, derived from grug_core.capitals — one general vendor and one
-- race vendor, ten nodes apart.
--
-- The offsets stay inside the 25x25 spawn platform (grug_core.CAMP_HALF = 12)
-- and clear of both fixed features on it: the platform CENTRE, which is the
-- player spawn/respawn point (grug_core.get_spawn_pos), and the guard banner
-- in the +x/+z corner at (CAMP_HALF - 1, CAMP_HALF - 1) = (+11, +11)
-- (grug_mapgen/structures.lua CAMP_BANNER_OFFSET).
--
local SLOT_OFFSETS = {
	general = {x = -5, z = 3},
	race = {x = 5, z = 3},
}

local slots = {}
for _, race_id in ipairs(race_ids) do
	local capital = grug_core.capitals[race_id]
	if capital then
		slots[#slots + 1] = {
			entity = "grug_traders:vendor_general_" .. capital.faction,
			race = race_id,
			x = capital.x + SLOT_OFFSETS.general.x,
			z = capital.z + SLOT_OFFSETS.general.z,
		}
		slots[#slots + 1] = {
			entity = "grug_traders:vendor_race_" .. race_id,
			race = race_id,
			x = capital.x + SLOT_OFFSETS.race.x,
			z = capital.z + SLOT_OFFSETS.race.z,
		}
	end
end

local CHECK_INTERVAL = 5 -- s (AGENTS.md performance rule: dtime accumulator)
local PLAYER_RANGE = 48 -- only slots a player could actually see are checked
local PRESENCE_RADIUS = 8 -- "is a vendor of this kind already standing here"

local function player_near(players, x, y, z)
	for i = 1, #players do
		local p = players[i]:get_pos()
		if p then
			local dx, dy, dz = p.x - x, p.y - y, p.z - z
			if dx * dx + dy * dy + dz * dz <= PLAYER_RANGE * PLAYER_RANGE then
				return true
			end
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
	for i = 1, #slots do
		local slot = slots[i]
		-- nil = the capital platform has not been resolved yet (the chunks
		-- were never generated). Skip the slot this round rather than guess a
		-- y — grug_core persists the value the moment mapgen decides it.
		local ground_y = grug_core.get_camp_platform_y(slot.race)
		if ground_y then
			local y = ground_y + 1
			if player_near(players, slot.x, y, slot.z) then
				local pos = {x = slot.x, y = y, z = slot.z}
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
	end
end)

-- Vendors are never despawned by us: the engine unloads them with their
-- mapblock and mob_activate brings them back. No ObjectRef is stored anywhere
-- in this mod — the slot table holds coordinates only (AGENTS.md: refs must be
-- re-fetched across any callback boundary).
