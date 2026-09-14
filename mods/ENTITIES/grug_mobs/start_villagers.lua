--
-- The flair and quest NPCs of the six start settlements
-- (docs/design/settlements.md "Settlement NPCs", the roster of
-- docs/research/wp13-npc-sockets-contract.md section 4).
--
-- Two families, one entity per race in each:
--   grug_mobs:villager_<race>  -- occupies an `idle` socket, ambles between
--                                 the settlement's idle sockets, stands facing
--                                 the socket direction and answers a
--                                 right-click with one race-flavoured line.
--   grug_mobs:elder_<race>     -- the quest shell of a `quest` socket: a
--                                 nametag and one placeholder answer. NO
--                                 quest logic (settlements.md: a quest socket
--                                 is a position, not a system).
--
-- WHY plain `mobs:register_mob` AND NOT `grug_mobs.register_mob`: that wrapper
-- IS the level/XP engine (levels.lua derives HP/damage/XP and installs the
-- "<name> [Lv 42]" tag) plus the aggro/leash/telegraph wrappers. A villager
-- has no level, no health bar and nothing to aggro. Same reasoning, same
-- reference as `grug_traders/vendors.lua`.
--
-- PERMANENCE and INVULNERABILITY are exactly vendors.lua's, whose header
-- carries the api.lua evidence: `type = "npc"` is skipped by all three
-- mobs_redo removal paths, `lifetimer = 30000` is the second independent
-- guard, and a TRUTHY `do_punch` return cancels every punch before wear,
-- both health subtractions and check_for_death (api.lua:2807-2810 -- any
-- truthy return cancels, the comment there claims the opposite). Every
-- environmental damage source is switched off separately, because those
-- bypass on_punch.
--
-- GUARDS IGNORE THEM: `attack_npcs = false` in guard.lua already means no
-- guard ever acquires a `type = "npc"` entity, so a villager needs nothing of
-- its own for that; and these definitions attack nothing at all.
--
-- Movement is owned by `start_npcs.lua` (the ambling tick below reads the
-- fields it installs). `walk_chance = 0` and `randomly_turn = false` are what
-- stop mobs_redo's own wander from fighting it; `stand_chance` is left at its
-- default because do_states may still stop a walk, and a nudge once a second
-- is what an amble is (see patrol.lua's header).
--

-- One line per race and idle tag. Deliberately data, not generated: the
-- flavour is the whole point of a flair NPC. `default` answers a socket with
-- no tag, and the quest shell's single placeholder lives in `quest`.
local LINES = {
	dwarf = {
		door = "Mind the step. That stone was laid before my " ..
			"grandmother's grandmother.",
		bench = "Sit if you like. The bench holds heavier than you.",
		work = "Everything good in the vale started as ore and stubbornness.",
		fire = "The forge never goes cold. Someone always owes it a shift.",
		default = "Hearthpine keeps its own counsel. And its own ale.",
		quest = "There is work in the vale, but not yet written down. " ..
			"Ask me again when the road is busier.",
	},
	human = {
		door = "Door is open. Wipe your boots and we will get on fine.",
		bench = "Long day in the fields. Longer evening, if the ale holds.",
		work = "Barn is half full and the weather is turning. Story of my life.",
		fire = "The smithy fire is the warmest thing in Dawnmere.",
		default = "Fields to the south, road to the north. That is the whole of it.",
		quest = "The hall keeps a list of things that need doing. " ..
			"It is blank today. Come back later.",
	},
	elf = {
		door = "Step quietly. The shrine hears more than it says.",
		bench = "Sit. The leaves will tell you the season faster than I will.",
		work = "A bow is grown, not carved. Ask me again in a year.",
		fire = "Lantern light suits the glade better than an open flame.",
		default = "The glades stood before the roads. They will outlast them.",
		quest = "The lore hall has errands for those who wait. " ..
			"Waiting is the errand, for now.",
	},
	orc = {
		door = "You walked in on your own feet. That earns you a word.",
		bench = "The council seats are for talking. Fighting happens elsewhere.",
		work = "The beasts eat first. They only fight hungry once.",
		fire = "Forge heat, sun heat. Sunscar has no shortage of either.",
		default = "Stand straight in the muster yard. The warlord looks out often.",
		quest = "The warlord gives orders, not chores. None for you today.",
	},
	troll = {
		door = "Lodge is dry. Rain is not. Choose.",
		bench = "Sit long. River moves. We do not.",
		work = "Shed is full of fish and patience. Mostly patience.",
		fire = "Smoke keeps the fish. Smoke keeps the flies. Good smoke.",
		default = "Cradle is old. Trees older. Trolls oldest.",
		quest = "Spirits speak slow. No words for you yet. Come back.",
	},
	undead = {
		door = "The house still has a roof. That is more than most here.",
		bench = "The settles are cold. So are we. It suits.",
		work = "The bone works never runs short of material. Take that as a warning.",
		fire = "The gate braziers are lit for the living. Warm yourself.",
		default = "Stillgrave keeps quiet. Do the same and we will get along.",
		quest = "The chapel records the dead, not the errands. " ..
			"Nothing for you is written.",
	},
}

-- Nametags. Flair NPCs carry one as well as the quest shell: without it a
-- player cannot tell a clickable villager from a guard at a glance, and there
-- are at most five of them in a settlement.
local NAMES = {
	dwarf = {villager = "Vale Dwarf", elder = "Vale Elder"},
	human = {villager = "Dawnmere Farmer", elder = "Village Elder"},
	elf = {villager = "Glade Elf", elder = "Lore Keeper"},
	orc = {villager = "Camp Orc", elder = "Camp Elder"},
	troll = {villager = "Cradle Troll", elder = "Cradle Elder"},
	undead = {villager = "Hollow Dweller", elder = "Hollow Warden"},
}

-- Placeholder skins until the character-visuals lane merges
-- (docs/research/wp13-character-visuals-contract.md section 2): the faction
-- guard textures, exactly as vendors.lua still uses them.
local GUARD_TEXTURE = {
	accord = "grug_mobs_guard_accord.png",
	throng = "grug_mobs_guard_throng.png",
}

-- How close counts as "standing at the socket", how long an NPC dwells there,
-- and the tick rate of the amble. One second is the throttle every ambient
-- movement in this mod uses (patrol.lua, aggro.lua's roam cap).
local SPOT_ARRIVED = 1.6
local DWELL_MIN, DWELL_MAX = 20, 50
local AMBLE_TICK = 1
-- One answer per player per two seconds: on_rightclick fires per click and a
-- held mouse button is a chat flood otherwise.
local ANSWER_COOLDOWN = 2

function grug_mobs.start_npc_line(race_id, key)
	local race = LINES[race_id]
	if not race then return nil end
	return race[key] or race.default
end

function grug_mobs.start_npc_name(race_id, family)
	local row = NAMES[race_id]
	return row and row[family] or nil
end

-- Static white nametag. mobs_redo recolours the tag by health on every
-- do_env_damage tick (api.lua:634-662, called from :989), so the method is
-- overridden PER ENTITY exactly as vendors.lua and levels.lua do it. A
-- function field never reaches staticdata, so this runs from after_activate
-- on every activation; the "already written" flag lives in self.temp, which
-- mob_activate resets per activation.
local function install_nametag(self, text)
	self.update_tag = function(other)
		local obj = other.object
		if not obj or not other.temp or other.temp.grug_tag_set then return end
		other.temp.grug_tag_set = true
		obj:set_properties({nametag = text, nametag_color = "#ffffff"})
	end
	self:update_tag()
end

--
-- The amble. Walk to the current idle socket, stand there facing its
-- direction for a while, then pick another one. Every field it reads is a
-- plain number, string or flat table installed by start_npcs.lua, so the
-- whole state survives unload/reload with the mob: never an ObjectRef, never
-- a function (the WP6 runtime-field rule in AGENTS.md).
--
local function amble_tick(self, dtime)
	self.temp = self.temp or {}
	local temp = self.temp
	temp.grug_amble_acc = (temp.grug_amble_acc or 0) + dtime
	if temp.grug_amble_acc < AMBLE_TICK then return end
	temp.grug_amble_acc = 0
	local spots = self._grug_idle_spots
	if type(spots) ~= "table" or #spots == 0 then return end
	-- Idle only, the same test patrol.lua and aggro.lua's roam cap use.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return
	end
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	local index = self._grug_idle_spot or 1
	if index < 1 or index > #spots then index = 1 end
	local spot = spots[index]
	local dx, dz = spot.x - pos.x, spot.z - pos.z
	if dx * dx + dz * dz > SPOT_ARRIVED * SPOT_ARRIVED then
		-- Still on the way: clear the dwell so arriving starts a fresh one.
		self._grug_idle_dwell = nil
		grug_mobs.walk_toward(self, spot.x, spot.z, pos)
		return
	end
	if self._grug_idle_dwell == nil then
		self._grug_idle_dwell = math.random(DWELL_MIN, DWELL_MAX)
	end
	if self._grug_idle_dwell > 0 then
		self._grug_idle_dwell = self._grug_idle_dwell - AMBLE_TICK
		self.state = "stand"
		self:set_velocity(0)
		self:set_yaw(spot.yaw or 0, 0)
		-- The line this NPC answers with follows the spot it is standing at.
		self._grug_idle_tag = spot.tag
		return
	end
	-- Dwell over: choose a different spot (a single-socket settlement keeps
	-- the one it has) and let the next tick walk there.
	if #spots > 1 then
		local pick = index
		for _ = 1, 8 do
			pick = math.random(#spots)
			if pick ~= index then break end
		end
		self._grug_idle_spot = pick
	end
	self._grug_idle_dwell = nil
end

local function answer(self, clicker, key)
	if not clicker or not clicker:is_player() then return end
	self.temp = self.temp or {}
	local now = core.get_gametime()
	local last = self.temp.grug_answer_at or 0
	if now - last < ANSWER_COOLDOWN then return end
	self.temp.grug_answer_at = now
	local line = grug_mobs.start_npc_line(self._grug_npc_race, key)
	if not line then return end
	local tag = self._grug_npc_tag or "Villager"
	core.chat_send_player(clicker:get_player_name(), "<" .. tag .. "> " .. line)
end

-- Everything both families share. Stationary-by-default, harmless,
-- indestructible, permanent.
local function npc_def(race_id, faction_id, nametag, extra)
	local def = {
		description = nametag,
		type = "npc",
		passive = true,
		lifetimer = 30000,
		owner = "",

		-- Never fights and is never a target worth acquiring.
		attack_type = "dogfight",
		attack_players = false,
		attack_monsters = false,
		attack_animals = false,
		attack_npcs = false,

		-- mobs_redo's own wander is off; start_npcs.lua owns the movement.
		walk_chance = 0,
		randomly_turn = false,
		walk_velocity = 1.1, -- a walking pace, not the guard's 1.2 patrol
		run_velocity = 1.1,
		jump = true,
		jump_height = 4,
		stepheight = 1.1,
		fear_height = 4,
		-- No `pathfinding`: mobs_redo only path-finds in the attack state
		-- (api.lua smart_mobs), which a villager can never enter.
		view_range = 4,
		reach = 0,
		floats = true,
		pushable = false,
		knock_back = false,

		-- Indestructible, including every source that bypasses on_punch.
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
		-- The engine/MTG player mesh by name: Luanti's media namespace is flat,
		-- so a mob here may point at a mesh living in player_api/models without
		-- copying it (wp6_model_notes section 5).
		mesh = "character.b3d",
		textures = {{GUARD_TEXTURE[faction_id]}},
		visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		makes_footstep_sound = true,
		animation = {
			stand_start = 0, stand_end = 79, stand_speed = 30,
			walk_start = 168, walk_end = 187, walk_speed = 30,
			run_start = 168, run_end = 187, run_speed = 30,
			punch_start = 189, punch_end = 198, punch_speed = 30,
		},

		-- The character-visuals seam
		-- (docs/research/wp13-character-visuals-contract.md section 2). Inert
		-- until that lane merges, and NB mobs_redo copies only its own def
		-- whitelist onto the entity (api.lua:3196ff), so the consumer reads
		-- this off `core.registered_entities[name]`, not off `self`.
		_grug_visual = {race = race_id},

		-- ANY truthy return cancels the punch outright (api.lua:2807-2810).
		do_punch = function()
			return true
		end,
	}
	for field, value in pairs(extra) do def[field] = value end
	return def
end

--
-- Registration, one pair per start race. The race roster comes from the
-- authenticated start identities, never a hand-kept list.
--
local identities = grug_core.start_identities()
if #identities == 0 then
	core.log("error", "[grug_mobs] start NPCs: the world authority published " ..
		"no start identities, so no settlement NPC is registered")
end
for index = 1, #identities do
	local identity = identities[index]
	local race_id, faction_id = identity.race_id, identity.faction_id
	local names = NAMES[race_id]
	if not names or not LINES[race_id] or not GUARD_TEXTURE[faction_id] then
		error("grug_mobs: no settlement NPC flavour for race " ..
			tostring(race_id) .. " of faction " .. tostring(faction_id), 0)
	end
	mobs:register_mob("grug_mobs:villager_" .. race_id,
		npc_def(race_id, faction_id, names.villager, {
			do_custom = amble_tick,
			after_activate = function(self)
				self._grug_npc_race = race_id
				self._grug_npc_tag = names.villager
				install_nametag(self, names.villager)
			end,
			on_rightclick = function(self, clicker)
				answer(self, clicker, self._grug_idle_tag)
			end,
		}))
	-- The quest shell holds its socket: no amble, no route, no quest logic.
	mobs:register_mob("grug_mobs:elder_" .. race_id,
		npc_def(race_id, faction_id, names.elder, {
			walk_velocity = 0,
			run_velocity = 0,
			stand_chance = 100,
			jump_height = 0,
			after_activate = function(self)
				self._grug_npc_race = race_id
				self._grug_npc_tag = names.elder
				install_nametag(self, names.elder)
			end,
			on_rightclick = function(self, clicker)
				answer(self, clicker, "quest")
			end,
		}))
end
