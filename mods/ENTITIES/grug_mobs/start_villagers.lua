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
local DWELL_MIN, DWELL_MAX = 20, 60
local AMBLE_TICK = 1
-- Seconds of no measurable progress toward a spot after which the villager
-- gives that spot up and takes another (patrol.lua's stall clock). Short,
-- because the usual obstacle is another villager and the usual fix is to go
-- somewhere else.
local SPOT_GIVE_UP = 15
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

--
-- A NAME FOLLOWS THE SETTLEMENT, NOT THE RACE (playtest round 1, 2026-09-15).
--
-- There is one villager entity per RACE and it serves that race's start AND its
-- capital, so a nametag read off the race put "Dawnmere Farmer" in the middle of
-- Highcourt. The six starts keep the flavour names they shipped with -- a race
-- has exactly one start, so those are settlement names already -- and every
-- other settlement is named after itself: "Highcourt Citizen", "Highcourt
-- Elder". Derived from the key rather than a second hand-kept roster, so the
-- next capital needs no edit here.
--
local FAMILY_TITLE = {villager = "Citizen", elder = "Elder"}

local function settlement_label(settlement_key)
	local words = {}
	for word in settlement_key:gmatch("[^_]+") do
		words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2)
	end
	return table.concat(words, " ")
end

function grug_mobs.settlement_npc_name(settlement_key, kind, race_id, family)
	if kind == "start" then
		local name = grug_mobs.start_npc_name(race_id, family)
		if name then return name end
	end
	return settlement_label(settlement_key) .. " " ..
		(FAMILY_TITLE[family] or FAMILY_TITLE.villager)
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
-- Re-assert the nametag once the placement engine has decided it.
--
-- ORDERING, and it is the engine's and not ours: `core.add_entity` activates the
-- entity synchronously, so `after_activate` has already run by the time
-- `start_npcs.lua`'s `install` writes `_grug_npc_name`. Without this the very
-- first placement of a capital villager would wear the race's start name until
-- the first reload -- which is the whole defect this fixes. `place` calls it
-- immediately after `install`, next to the same file's `face_yaw` call, which
-- exists for exactly the same reason.
--
function grug_mobs.start_npc_retag(self)
	local name = self._grug_npc_name
	if type(name) ~= "string" or name == "" then
		return
	end
	self._grug_npc_tag = name
	if self.temp then
		self.temp.grug_tag_set = nil
	end
	install_nametag(self, name)
end

-- Is another villager of this family visibly standing on that spot? Only
-- asked when one of them changes spot, i.e. a handful of times a minute in a
-- whole settlement. `get_objects_inside_radius` sees only ACTIVATED objects,
-- so a spot in an unloaded corner reads as free -- which is the harmless
-- direction: nobody is watching that corner either.
local function spot_taken(self, spot)
	local objects = core.get_objects_inside_radius(
		{x = spot.x, y = spot.y, z = spot.z}, SPOT_ARRIVED)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		-- `entity ~= self` and not an ObjectRef comparison: the luaentity table
		-- is the identity that is certainly unique per mob.
		if entity and entity ~= self and entity.name == self.name then
			return true
		end
	end
	return false
end

-- THE VISUALS SEAM, called by hand and not by a wrapper.
--
-- `grug_mobs.register_mob` is what reads a definition's `_grug_visual` and
-- installs the after_activate that applies it (grug_mobs/init.lua). These two
-- families go through plain `mobs:register_mob` on purpose -- they must never
-- get the level/XP engine -- so nothing would ever read the field, and a
-- villager would keep the placeholder guard skin for good. Calling
-- `grug_visuals.apply_entity` here is exactly what `grug_traders/vendors.lua`
-- does for the same reason. The def still carries `_grug_visual` as the
-- contract's declaration of what this entity looks like; this call is what
-- makes it act.
--
-- No `write_textures` argument: that exists for grug_mobs' tier tint, which
-- layers an elite's gold over the pristine list. A villager has no tier.
local function apply_race_visual(self, race_id)
	if core.global_exists("grug_visuals") then
		grug_visuals.apply_entity(self, {race = race_id})
	end
end

--
-- The amble. Walk to the current idle socket, stand there facing its
-- direction for a while, then pick another one. Every field it reads is a
-- plain number, string or flat table installed by start_npcs.lua, so the
-- whole state survives unload/reload with the mob: never an ObjectRef, never
-- a function (the WP6 runtime-field rule in AGENTS.md).
--
-- THE NEXT SPOT IS THE NEXT ONE IN THE RING, and the occupancy test may only
-- ever SKIP a candidate, never cancel the move. That last clause is the
-- 2026-09-15 playtest fix: the first version walked the ring looking for a free
-- spot and fell back to `pick == index` -- its own spot -- when it found none,
-- and with four villagers standing on four spots EVERY candidate is always
-- taken. So every villager re-rolled its dwell where it stood and the four of
-- them never moved again, which is exactly what the user saw: villagers
-- standing in front of their houses doing nothing.
--
local function next_spot(self, spots, index)
	local count = #spots
	if count < 2 then
		return index
	end
	-- Advancing by exactly one is what keeps four villagers on four distinct
	-- sockets spread out: they all advance in step. A random pick puts two of
	-- them on one node most of the time (four on four collide in about nine
	-- attempts out of ten).
	local fallback = index % count + 1
	local pick = index
	for _ = 1, count - 1 do
		pick = pick % count + 1
		if not spot_taken(self, spots[pick]) then
			return pick
		end
	end
	return fallback
end

local function amble_tick(self, dtime)
	self.temp = self.temp or {}
	local temp = self.temp
	temp.grug_amble_acc = (temp.grug_amble_acc or 0) + dtime
	if temp.grug_amble_acc < AMBLE_TICK then return end
	local elapsed = temp.grug_amble_acc
	temp.grug_amble_acc = 0
	-- A twin on a socket somebody else already holds removes itself, once per
	-- activation (start_npcs.lua's claim registry). Checked here rather than in
	-- after_activate so it runs after the placement fields are certainly in
	-- place, and nothing below may run for a mob that has just been removed.
	if not temp.grug_socket_claimed then
		temp.grug_socket_claimed = true
		-- FALSE, not nil: mobs_redo's on_step returns as soon as do_custom
		-- answers false, which is how a mob that has just removed itself skips
		-- the rest of its own step.
		if not grug_mobs.start_npc_claim(self) then return false end
	end
	local spots = self._grug_idle_spots
	if type(spots) ~= "table" or #spots == 0 then return end
	-- Idle only, the same test patrol.lua and aggro.lua's roam cap use.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		grug_mobs.stall_clear(self)
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
		-- A BLOCKED VILLAGER PICKS ANOTHER SPOT instead of pushing forever. It
		-- has no pathfinder (mobs_redo only path-finds in the attack state) and
		-- since the round-1 fix no jump either, so "walk into it until it moves"
		-- is not a plan -- and the thing in the way is usually another villager
		-- on the same errand.
		local stalled = grug_mobs.stall_clock(self, spot.x, spot.z, pos, elapsed)
		if stalled >= SPOT_GIVE_UP then
			grug_mobs.stall_clear(self)
			self._grug_idle_spot = next_spot(self, spots, index)
			self.state = "stand"
			self:set_velocity(0)
			return
		end
		grug_mobs.walk_toward(self, spot.x, spot.z, pos)
		return
	end
	grug_mobs.stall_clear(self)
	if self._grug_idle_dwell == nil then
		self._grug_idle_dwell = math.random(DWELL_MIN, DWELL_MAX)
	end
	-- THE FIRST TICK OF AN ACTIVATION caps whatever is left of the dwell at
	-- DWELL_MIN. A villager's dwell only counts down while its mapblock is
	-- active, i.e. while somebody is there to see it, so this is what bounds the
	-- wait a player walking into a settlement has before anything moves. The
	-- flag lives in self.temp, which mob_activate resets per activation.
	if not temp.grug_amble_fresh then
		temp.grug_amble_fresh = true
		if self._grug_idle_dwell > DWELL_MIN then
			self._grug_idle_dwell = DWELL_MIN
		end
	end
	if self._grug_idle_dwell > 0 then
		self._grug_idle_dwell = self._grug_idle_dwell - elapsed
		self.state = "stand"
		self:set_velocity(0)
		grug_mobs.face_yaw(self, spot.yaw or 0)
		-- The line this NPC answers with follows the spot it is standing at.
		self._grug_idle_tag = spot.tag
		return
	end
	-- Dwell over: step on to the next spot and let the next tick walk there.
	self._grug_idle_spot = next_spot(self, spots, index)
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
		--
		-- A VILLAGER NEVER JUMPS, and `jump_height = 0` is the only field that
		-- says so (playtest round 1, 2026-09-15).
		--
		-- `walk_chance = 0` above means "mobs_redo's wander is off" to us, but
		-- inside mobs_redo's `do_jump` it means "this is a JUMPING mob"
		-- (api.lua:1131: `or self.walk_chance == 0` is an alternative to having
		-- a solid node in front worth hopping onto). do_jump runs four times a
		-- second from on_step and only skips a mob whose vertical velocity is
		-- non-zero, so every one of these villagers hopped again the instant it
		-- landed, for the whole length of every walk -- with `jump_height = 4`
		-- and the `core.after(0.3, set_acceleration{y = 0})` that follows the
		-- jump in the same function. In Highcourt's core, where a villager's
		-- idle spots are further apart, that is most of its life.
		--
		-- `do_jump` returns before that clause when `jump_height == 0`
		-- (api.lua:1114), which is the switch. `jump` itself is not a field
		-- mobs_redo reads at all -- it is in no def whitelist and nothing in
		-- api.lua consults it -- and is kept false only so the def does not
		-- claim the opposite of what it does. Flat settlement ground plus
		-- `stepheight = 1.1` is what a villager needs; something in the way is
		-- handled by picking another spot (amble_tick), not by climbing it.
		--
		jump = false,
		jump_height = 0,
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
				-- The name the PLACEMENT resolved (start_npcs.lua), because one
				-- entity per race serves that race's start and its capital.
				-- The race's own start flavour is the fallback for anything
				-- this engine did not place.
				local name = self._grug_npc_name or names.villager
				self._grug_npc_race = race_id
				self._grug_npc_tag = name
				install_nametag(self, name)
				apply_race_visual(self, race_id)
				grug_mobs.face_yaw(self, self._grug_face_yaw)
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
				local name = self._grug_npc_name or names.elder
				self._grug_npc_race = race_id
				self._grug_npc_tag = name
				install_nametag(self, name)
				apply_race_visual(self, race_id)
				-- The quest shell has no tick of its own, so this is the ONLY
				-- thing that puts it back on its authored facing after a reload,
				-- and the only place it can claim its socket (start_npcs.lua):
				-- a twin removes itself here instead of joining the settlement.
				grug_mobs.face_yaw(self, self._grug_face_yaw)
				grug_mobs.start_npc_claim(self)
			end,
			on_rightclick = function(self, clicker)
				answer(self, clicker, "quest")
			end,
		}))
end
