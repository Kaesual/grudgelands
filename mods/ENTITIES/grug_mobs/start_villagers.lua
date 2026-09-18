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
-- both health subtractions and check_for_death (api.lua:3204-3208 -- any
-- truthy return cancels, the comment there claims the opposite). Every
-- environmental damage source is switched off separately, because those
-- bypass on_punch.
--
-- NOBODY TOUCHES THEM: both families are NON-COMBATANTS
-- (`grug_mobs.noncombatant`, verbs.lua), so general_attack's candidate filter
-- drops them for every mob in the world -- guards, whose own
-- `attack_npcs = false` would have covered them anyway, and hostiles, which
-- since the round-2 ruling DO acquire guards. These definitions attack nothing
-- at all in return.
--
-- Movement is owned by `start_npcs.lua` (the ambling tick below reads the
-- fields it installs). `walk_chance = 0` and `randomly_turn = false` are what
-- stop mobs_redo's own wander from fighting it; `stand_chance` is left at its
-- default because do_states may still stop a walk, and a nudge once a second
-- is what an amble is (see patrol.lua's header).
--

--
-- One line per race and socket tag. Deliberately data, not generated: the
-- flavour is the whole point of a flair NPC. `default` answers a socket with
-- no line of its own, and the quest shell's single placeholder lives in
-- `quest`.
--
-- WHICH KEY A RESIDENT ANSWERS WITH: `tags[1]` of the socket it stands on
-- (contract section 8.1/section 6), and for a WORK socket with no tag at all
-- its `activity` (start_npcs.lua's `install`). So a capital lane that authors
-- `{id = ..., role = "work", activity = "mine"}` without a tag gets the `mine`
-- line for free, and one that tags it `{"work"}` keeps the generic one. Both
-- are legal; neither can produce a missing line, because an unknown key falls
-- back to `default`.
--
-- THE FOUR TAGS AUTHORED ON MAIN are `work`, `bench`, `door` and `fire`
-- (30/25/24/12 sockets across the six starts, Highcourt and Dur Brannoc), plus
-- one `shade`, which had no line and answered `default` until this lane. The
-- six added below are the wave-2 activity names of contract section 8.2.
--
local LINES = {
	dwarf = {
		door = "Mind the step. That stone was laid before my " ..
			"grandmother's grandmother.",
		bench = "Sit if you like. The bench holds heavier than you.",
		work = "Everything good in the vale started as ore and stubbornness.",
		fire = "The forge never goes cold. Someone always owes it a shift.",
		mine = "The seam runs deeper than the shaft. It always does.",
		brew = "Two barrels for the hall, one for whoever swung the hammer.",
		carve = "Stone remembers a careless chisel longer than you will.",
		mourn = "We cut their names into the wall. That is our kind of grief.",
		spar = "Blunt the practice blades. Sharp ones teach the wrong lesson.",
		forage = "The high slopes give mushrooms and little else. " ..
			"Take the mushrooms.",
		shade = "Out of the sun. The stone keeps its cool better than we do.",
		default = "Hearthpine keeps its own counsel. And its own ale.",
		quest = "There is work in the vale, but not yet written down. " ..
			"Ask me again when the road is busier.",
	},
	human = {
		door = "Door is open. Wipe your boots and we will get on fine.",
		bench = "Long day in the fields. Longer evening, if the ale holds.",
		work = "Barn is half full and the weather is turning. Story of my life.",
		fire = "The smithy fire is the warmest thing in Dawnmere.",
		mine = "Every bucket of ore goes up the road to the capital. Every one.",
		brew = "Barley in, patience in, ale out. Do not rush the middle part.",
		carve = "The gatepost has been recut three times. Weather wins in the end.",
		mourn = "We bury them facing the fields. It seemed right, and it stuck.",
		spar = "Drill in the morning, harvest after. Both keep you alive.",
		forage = "The hedgerow is full this year. Mind the thorns.",
		shade = "Sit out of the sun a while. The work will wait for you.",
		default = "Fields to the south, road to the north. That is the whole of it.",
		quest = "The hall keeps a list of things that need doing. " ..
			"It is blank today. Come back later.",
	},
	elf = {
		door = "Step quietly. The shrine hears more than it says.",
		bench = "Sit. The leaves will tell you the season faster than I will.",
		work = "A bow is grown, not carved. Ask me again in a year.",
		fire = "Lantern light suits the glade better than an open flame.",
		mine = "We take from the rock slowly. It was here first.",
		brew = "The cordial wants a season in the dark. Ask again in spring.",
		carve = "The figure is already in the wood. I only uncover it.",
		mourn = "We plant rather than bury. The grove is the memory.",
		spar = "Footwork first. A blade is only as honest as the stance.",
		forage = "The forest floor feeds anyone who knows where to look.",
		shade = "The canopy does the work. Stand under it and listen.",
		default = "The glades stood before the roads. They will outlast them.",
		quest = "The lore hall has errands for those who wait. " ..
			"Waiting is the errand, for now.",
	},
	orc = {
		door = "You walked in on your own feet. That earns you a word.",
		bench = "The council seats are for talking. Fighting happens elsewhere.",
		work = "The beasts eat first. They only fight hungry once.",
		fire = "Forge heat, sun heat. Sunscar has no shortage of either.",
		mine = "Pick, rock, pick. The mountain gives up eventually.",
		brew = "Strong enough to stand a spear in. That is the measure.",
		carve = "Every totem in this yard is a name somebody earned.",
		mourn = "We burn ours and shout the name once. Once is enough.",
		spar = "Hit me properly or do not waste the morning.",
		forage = "Roots and dry fruit. The savanna is stingy, but it is honest.",
		shade = "The sun is a second enemy here. Stand in the shade and live.",
		default = "Stand straight in the muster yard. The warlord looks out often.",
		quest = "The warlord gives orders, not chores. None for you today.",
	},
	troll = {
		door = "Lodge is dry. Rain is not. Choose.",
		bench = "Sit long. River moves. We do not.",
		work = "Shed is full of fish and patience. Mostly patience.",
		fire = "Smoke keeps the fish. Smoke keeps the flies. Good smoke.",
		mine = "Rock is slow. We are slower. We win.",
		brew = "River water. Root. Time. Good.",
		carve = "Wood was a tree. Tree was patient. Carve patient.",
		mourn = "We sit by the water and say nothing. That is the song.",
		spar = "Hit slow. Learn. Hit slow again.",
		forage = "Jungle floor gives. Look down more.",
		shade = "Rain stops here. Sit.",
		default = "Cradle is old. Trees older. Trolls oldest.",
		quest = "Spirits speak slow. No words for you yet. Come back.",
	},
	undead = {
		door = "The house still has a roof. That is more than most here.",
		bench = "The settles are cold. So are we. It suits.",
		work = "The bone works never runs short of material. Take that as a warning.",
		fire = "The gate braziers are lit for the living. Warm yourself.",
		mine = "The shafts under Stillgrave were dug by the living. We kept them.",
		brew = "It keeps the damp out. Nothing keeps the damp out.",
		carve = "Names on stone. It is most of the work we have left.",
		mourn = "We know both sides of this ceremony. Stand quietly.",
		spar = "We do not tire. That makes us poor teachers and worse opponents.",
		forage = "The blight grows things. Not all of them should be eaten.",
		shade = "The sun is no friend of ours. Step under the eaves.",
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
--
-- A STATIC IDLE RESIDENT'S DWELL (contract section 8.3, playtest round 3): four
-- residents out of five never walk a route, and the one thing they keep of the
-- round-1 amble is "at most a rare short hop on the spare ring". So the same
-- machinery runs with a dwell an order of magnitude longer -- three to seven
-- minutes of standing at the door or the bench -- and with a ring that holds
-- its own socket and the SPARE spots near it and nothing else, so a hop is
-- never a trade of homes with a neighbour.
--
local STATIC_DWELL_MIN, STATIC_DWELL_MAX = 180, 420
-- The bound on a walker's route lives where the ring is BUILT
-- (start_npcs.lua's `WALK_RADIUS`), not here: this file only spends the ring
-- it is handed.
-- The work tick, the same one-second throttle every ambient movement here uses.
local WORK_TICK = 1
-- HOW FAR A PLAYER MAY BE and still make the animation worth running. The model
-- is the vendor presence poll of grug_traders (PLAYER_RANGE = 24): an animation
-- nobody can see is a property write nobody can see. Squared, because this runs
-- once a second per resident and a square root does not.
local WATCH_RANGE_D2 = 24 * 24
-- The occasional swing of `fish` and `tend`: two seconds of animation every ten.
-- Two property writes per ten seconds per watched resident, and none at all
-- while nobody is near.
local SWING_ON, SWING_PERIOD = 2, 10
-- `sweep` is the one activity that moves (contract section 8.2: "it stays
-- within two nodes of its socket"). The line runs along the socket's own facing
-- and is walked at the ordinary pace, with no path-finding of any kind.
local SWEEP_SPAN = 2
local SWEEP_ARRIVED = 0.6
--
-- HOW FAR OFF ITS SOCKET a work resident may be before it walks back, and how
-- long it may fail to get there before it is put there.
--
-- A static resident is defined by standing on its socket, and things move an
-- NPC: a knockback, an admin teleport, an engine probe. Without this it would
-- stand wherever it was pushed for the life of the world -- which the WP13
-- round-3 engine probe found by moving the whole roster forty nodes and
-- watching the walkers come home while the workers did not.
--
-- The walk home is `walk_toward` and NOTHING else: no pathfinder, which is the
-- contract's own rule for a static resident (section 8.3), and it is the one
-- part of the tick that is NOT gated on a player being near -- a resident
-- stranded in the middle of a field is exactly what a player walking up would
-- see, so the correction has to have happened before they arrive. It costs one
-- squared distance per second, and a walk only in the rare case.
--
-- The last resort is patrol.lua's third stage, the out-of-sight snap (the
-- user's round-1 ruling: a teleport never happens where anyone can watch it).
-- It is keyed on the STALL clock -- thirty seconds without measurable progress
-- toward home -- and not on the total, because the thing that stops a resident
-- getting home is a tree or a fence it is pressed against, and a mob that
-- oscillates around an obstacle makes progress often enough to keep resetting a
-- total. Thirty seconds is also well inside the time a player takes to walk up.
--
local WORK_SLACK = 1.2
local WORK_STALL_SNAP = 30
-- Seconds of no measurable progress toward a spot after which the villager
-- gives that spot up and takes another (patrol.lua's stall clock). Short,
-- because the usual obstacle is another villager and the usual fix is to go
-- somewhere else.
local SPOT_GIVE_UP = 15
-- One answer per player per two seconds: on_rightclick fires per click and a
-- held mouse button is a chat flood otherwise.
local ANSWER_COOLDOWN = 2
--
-- THE MOURNER'S BOWED HEAD (contract section 8.2, wave 2: "stands still, head
-- bowed if the mesh allows"). MEASURED, not assumed: `character.b3d` carries
-- the bones `Head`, `Body`, `Arm_Left`, `Arm_Right`, `Leg_Left` and
-- `Leg_Right` -- read out of the model file itself -- so the mesh does allow
-- it, and the bow is a bone override rather than a frame range nobody
-- authored.
--
-- RELATIVE, not absolute (`absolute` is the default false): an absolute
-- override would replace the animated head pose outright, while a relative one
-- COMPOSES with whatever the stand animation is doing, so the mourner keeps
-- breathing. Radians, in the model's own coordinate system
-- (`lua_api.md` set_bone_override).
--
-- THE SIGN is the one thing a headless server cannot settle, and it is named
-- rather than claimed: VoxeLibre's trading piglin -- the same Blockmen-derived
-- humanoid lineage -- nods DOWN at the trade with a Head rotation of
-- `(-0.7, 0, 0)` (mobs_mc/piglin.lua:115), which is the evidence for the
-- negative x here. If the user's playtest shows a mourner looking at the sky,
-- this constant's sign is the whole fix.
--
-- One write per activation and none afterwards, and the API is checked on the
-- object rather than assumed: `set_bone_override` is Luanti >= 5.9, and an
-- engine without it simply gets the still stand the contract's "if the mesh
-- allows" already permits.
--
local MOURN_BONE = "Head"
local MOURN_PITCH = -0.35

--
-- THE ACTIVITY TABLE (contract section 8.2, which is closed on the NAMES and
-- leaves the animation and the wielded item to this lane).
--
-- `anim` is the mobs_redo animation key of the definition below:
--   stand  frames 0..79     the idle pose of `character.b3d`
--   walk   frames 168..187  the only moving activity, `sweep`
--   work   frames 189..198  the mesh's `mine` swing, run at a THIRD of the
--                           player's speed (10 against 30) so a hammer, a hoe
--                           and an axe read as work rather than as a fight
--   sit    frames 81..160   the mesh's own sit range
-- All four are `mods/BASE/player_api/init.lua`'s registered ranges, read off
-- that file rather than copied from a wiki: stand 0-79, sit 81-160, lay
-- 162-166, walk 168-187, mine 189-198, walk_mine 200-219.
--
-- `swing` means "stand, and lift the arm now and then": the weeding and the
-- rod-tending of section 8.2, which are a stand pose with an occasional mine
-- frame rather than a loop.
--
-- `bow` is the mourner's head (MOURN_PITCH above), and `weapon_family` plus
-- `bracket` is the sparring partner's blade -- the one activity that names a
-- grug_gear FAMILY instead of an item string, for the reason in the table's
-- own note.
--
-- `item` is what the hand holds, through the character-visuals wield seam
-- (`grug_visuals.apply_entity`'s `weapon` field, the same one a guard's sword
-- goes through). Only items the game ACTUALLY registers are named -- there is
-- no farming mod and therefore no hoe, so the field hand carries the stone
-- shovel, which is the closest tool this vocabulary has. The ANGLER no longer
-- carries the stick section 8.2 allowed as a stand-in: playtest round 5 ruled
-- that "the fishing rods of anglers sit in the middle of the hand, and they are
-- sticks", so `fish` now names the real `grug_fishing:rod` -- which is also
-- what moves it out of the anonymous-icon pose (a stick has no declared family
-- and is therefore held by its centre) and into the diagonal tool pose that
-- puts the grip in the fist. `grug_mobs` gains no dependency for it: this
-- field is a string the visuals seam resolves at draw time, and the audit at
-- the bottom of this file is what notices if the mod ever goes away.
-- An unregistered name would draw nothing at all
-- (grug_visuals/apply.lua), so the startup audit at the bottom of this file
-- reports one instead of leaving an empty hand nobody notices.
--
-- WAVE 2 (2026-09-15) added the six race-flavoured activities of the same
-- section: `mine`, `brew`, `carve`, `mourn`, `spar` and `forage`. Five of them
-- are the two shapes above -- a `work` loop with a tool, or a stand with an
-- occasional swing -- and the two that are not say why in their own rows:
--
--   * `mourn` is a still stand WITH A BOWED HEAD (see MOURN_PITCH). The
--     contract asks for the bow "if the mesh allows"; `character.b3d` carries
--     a `Head` bone, so it does.
--   * `spar` is the only activity that wields a WEAPON rather than a tool, and
--     it names a FAMILY instead of an item: `grug_gear`'s ladder is
--     material-named and has no race axis at all (items_crafting.md section
--     3.0.3 -- one item per concept, six material tiers, four weapon
--     families), so "the settlement's tier-1 weapon" resolves to the T1 rung
--     of a family and nothing here may spell an item string. `grug_mobs` does
--     not depend on `grug_gear`; `grug_visuals` does, and `weapon_family` plus
--     `bracket` is exactly the seam a GUARD's sword already goes through
--     (guard.lua's `_grug_visual`), so the dependency stays where it is.
--
local ACTIVITY = {
	smith = {anim = "work", item = "default:pick_bronze"},
	fish = {anim = "stand", swing = true, item = "grug_fishing:rod"},
	farm = {anim = "work", item = "default:shovel_stone"},
	chop = {anim = "work", item = "default:axe_stone"},
	tend = {anim = "stand", swing = true},
	pray = {anim = "stand"},
	stall = {anim = "stand"},
	sit = {anim = "sit"},
	sweep = {anim = "walk", sweep = true},
	-- Wave 2, contract section 8.2's second table.
	mine = {anim = "work", item = "default:pick_bronze"},
	brew = {anim = "stand", swing = true, item = "default:stick"},
	carve = {anim = "work", item = "default:axe_stone"},
	mourn = {anim = "stand", bow = true},
	spar = {anim = "work", weapon_family = "sword", bracket = 1},
	forage = {anim = "stand", swing = true},
}

function grug_mobs.start_npc_activity(name)
	return ACTIVITY[name]
end

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

--
-- Static white text on the observer-managed tag carrier.
--
-- mobs_redo recolours the tag by health on every do_env_damage tick
-- (api.lua:1050-1176, called from :3837-3938), so the method is overridden PER ENTITY
-- exactly as vendors.lua and levels.lua do it. A function field never reaches
-- staticdata, so this runs from after_activate on every activation.
--
-- WHAT CHANGED IN ROUND 3: this used to write the nametag property once and be
-- done, and the engine has no distance cull of its own -- so a villager's name
-- rendered out to the ~128 m object-send range while a guard's disappeared at
-- thirty, which is the clutter the user reported. The DESIRED text is now kept
-- in a plain string field (so it survives unload/reload with the mob and a
-- rename while nobody observes it costs no client send), and the once-a-second
-- slot changes only the carrier's observer set. mobs_redo's own `update_tag`
-- calls refresh the desired carrier text without exposing the parent tag.
--
local function install_nametag(self, text)
	self._grug_tag_want = text
	local carrier = grug_mobs.ensure_tag_carrier(self)
	grug_core.set_tag_carrier_text(carrier, text)
	self.update_tag = function(other)
		other._grug_tag_want = text
		grug_core.set_tag_carrier_text(
			grug_mobs.ensure_tag_carrier(other), text)
	end
end

-- The gate, called from every family's per-second tick. Resolved through the
-- table on each call because `levels.lua` is what installs it: the KAT fixture
-- drives these two families without the level engine, and a settlement NPC has
-- no level to want it for.
local function tag_gate(self)
	local gate = grug_mobs.plain_tag_gate_tick
	if gate then gate(self, self._grug_tag_want) end
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
	install_nametag(self, name)
	-- install_nametag updates the carrier immediately; its observer gate keeps
	-- the existing per-viewer states until the next one-second tick.
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
--
-- `activity` is the ACTIVITY row of a WORK resident (contract section 8.2) and
-- nil for everybody else. Its `item` goes through the same `weapon` field of
-- the visuals spec a guard's sword does, so the wield entity, its bone
-- attachment and its transform are the visuals lane's and not a second copy
-- here. Both halves are idempotent -- `apply_entity` skips the texture write
-- while the composed skin is unchanged and `sync_wield` skips while the item
-- is unchanged -- which is what makes calling it from a per-second tick free.
--
-- AND `weapon_family` + `bracket` IS THE SAME SEAM ONE LEVEL UP (wave 2):
-- `grug_visuals.compose` resolves a family at a bracket through
-- `grug_gear.weapon_item`, which is where the material ladder's names live. It
-- is passed on rather than resolved here on purpose -- `grug_mobs` does not
-- depend on `grug_gear` (mod.conf) and `grug_visuals` does, so resolving it in
-- this file would be a new dependency for one string.
--
local function apply_race_visual(self, race_id, activity)
	if not core.global_exists("grug_visuals") then return end
	grug_visuals.apply_entity(self, {race = race_id,
		weapon = activity and activity.item or nil,
		weapon_family = activity and activity.weapon_family or nil,
		-- Only alongside a family: `bracket` also picks an armour grade, and a
		-- villager has no armour line to grade.
		bracket = activity and activity.weapon_family and
			(activity.bracket or 1) or nil})
end

--
-- THE MOURNER'S POSE, once per activation (see MOURN_PITCH).
--
-- Called from both places a work resident is dressed -- `after_activate` for a
-- reload, whose staticdata already carries the activity, and the work tick's
-- own dress block for a fresh placement, where `install` has not run yet when
-- `after_activate` does. One flag in `self.temp`, which `mob_activate` clears
-- per activation, so the override is written exactly once whichever path gets
-- there first.
--
-- `object.set_bone_override` is checked rather than assumed (Luanti >= 5.9):
-- without it the mourner is the still stand the contract already allows, and
-- nothing logs, because an older engine is not a defect of this table.
--
local function apply_pose(self, activity)
	if not activity or not activity.bow then return end
	self.temp = self.temp or {}
	if self.temp.grug_work_posed then return end
	local object = self.object
	if not object or not object.set_bone_override then return end
	self.temp.grug_work_posed = true
	object:set_bone_override(MOURN_BONE,
		{rotation = {vec = vector.new(MOURN_PITCH, 0, 0), interpolation = 0,
			absolute = false}})
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
	-- THE ONE PER-SECOND SLOT this family has, shared by the amble and the
	-- nametag gate rather than opened twice (levels.lua's own note).
	tag_gate(self)
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
	--
	-- HOW LONG THIS RESIDENT STANDS STILL is the whole of the 80/20 rule on the
	-- idle side (contract section 8.3). A WALKER keeps the round-1 twenty to
	-- sixty seconds, which is a continuous route; a STATIC resident stands for
	-- three to seven minutes, which is a rare short hop with a very long dwell
	-- either side of it. `_grug_walker` is the plain boolean the placement
	-- engine wrote, so the two are decided once and never re-rolled.
	--
	local dwell_min, dwell_max = STATIC_DWELL_MIN, STATIC_DWELL_MAX
	if self._grug_walker then
		dwell_min, dwell_max = DWELL_MIN, DWELL_MAX
	end
	if self._grug_idle_dwell == nil then
		self._grug_idle_dwell = math.random(dwell_min, dwell_max)
	end
	-- THE FIRST TICK OF AN ACTIVATION caps whatever is left of the dwell at
	-- DWELL_MIN. A villager's dwell only counts down while its mapblock is
	-- active, i.e. while somebody is there to see it, so this is what bounds the
	-- wait a player walking into a settlement has before anything moves. The
	-- flag lives in self.temp, which mob_activate resets per activation.
	--
	-- WALKERS ONLY, since round 3. The cap exists because a dwell only counts
	-- down while somebody is there to see it, so it bounds the wait a player
	-- walking into a settlement has before anything moves -- and that is a
	-- statement about the people who are supposed to be moving. A STATIC
	-- resident standing at its door for its first three minutes is the
	-- behaviour, not a wait, and capping it would have made every static
	-- resident hop the moment its minimum ran out.
	--
	if self._grug_walker and not temp.grug_amble_fresh then
		temp.grug_amble_fresh = true
		if self._grug_idle_dwell > dwell_min then
			self._grug_idle_dwell = dwell_min
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

--
-- THE WORK TICK (contract section 8.1/8.2, playtest round 3).
--
-- A resident booked on a `work` socket never leaves it. It stands on the
-- socket, faces the authored direction, plays its activity's animation and
-- holds its activity's tool. Everything about it is built for the user's own
-- constraint -- "lived-in settlements without paying for it in server load" --
-- and the three things that cost anything are all switched off:
--
--   1. NO PATH-FINDING, EVER. A static resident has no destination, so nothing
--      here ever reaches `core.find_path`; `sweep`, the one activity that
--      moves, walks a two-node straight line with `walk_toward` and no rescue.
--   2. ONE PROPERTY WRITE PER CHANGE. mobs_redo's own `set_animation` returns
--      without touching the object when the animation is already the one asked
--      for (api.lua:500-548), so a hammering smith writes its animation once for
--      the life of its activation, and a swinging fisher twice per ten seconds.
--   3. NOTHING AT ALL WHILE NOBODY IS WATCHING. The vendor presence poll's own
--      rule (grug_traders/vendors.lua PLAYER_RANGE): beyond 24 nodes from the
--      nearest player the tick sets the velocity to zero once and returns.
--
-- AND IT RETURNS `false`, which is what makes the whole thing hold. mobs_redo
-- skips the rest of `on_step` as soon as `do_custom` answers exactly false
-- (api.lua:3837-3938), so `do_states` never runs for a work resident -- and
-- `do_states` in the stand state calls `set_animation("stand")` once a second
-- (api.lua:2232-2233), which would overwrite the activity's animation within a
-- second of it being set. It also skips `general_attack`, `breed` and
-- `follow_flop`, which for a non-combatant with no follow list is pure saving.
--
local function watched(self, pos)
	local nearest = grug_mobs.nearest_player_d2
	if not nearest then return true end
	local d2 = nearest(pos)
	return d2 ~= nil and d2 <= WATCH_RANGE_D2
end

-- The two ends of a `sweep`'s line: the socket itself and two nodes along its
-- authored facing. Derived from the yaw the placement engine wrote, so it
-- needs no second copy of the socket's `dir`.
local function sweep_ends(self)
	local home_x = self._grug_work_x
	local home_z = self._grug_work_z
	local yaw = self._grug_face_yaw or 0
	-- core.dir_to_yaw is atan2(-x, z), so this is its inverse.
	local dx = -math.sin(yaw)
	local dz = math.cos(yaw)
	return home_x, home_z, home_x + dx * SWEEP_SPAN, home_z + dz * SWEEP_SPAN
end

local function work_tick(self, dtime)
	self.temp = self.temp or {}
	local temp = self.temp
	temp.grug_work_acc = (temp.grug_work_acc or 0) + dtime
	if temp.grug_work_acc < WORK_TICK then return false end
	local elapsed = temp.grug_work_acc
	temp.grug_work_acc = 0
	if not temp.grug_socket_claimed then
		temp.grug_socket_claimed = true
		if not grug_mobs.start_npc_claim(self) then return false end
	end
	tag_gate(self)
	local activity = ACTIVITY[self._grug_work_activity]
	local pos = self.object and self.object:get_pos()
	if not activity or not pos then return false end
	-- Fighting, fleeing and flopping own the movement; a non-combatant can
	-- reach none of those states, and the test is the one patrol.lua and
	-- aggro.lua's roam cap use.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return false
	end
	--
	-- HOME FIRST, and deliberately BEFORE the "is anybody watching" gate: see
	-- WORK_SLACK.
	--
	-- `sweep` is NOT exempt, and the first cut of this made it one on the
	-- reasoning that its two-node line is its home. The review caught what that
	-- costs: the sweep branch below sits AFTER the watch gate, so a sweeper
	-- displaced while nobody was near would stand wherever it was pushed until
	-- a player walked up to it -- which is precisely the moment it is supposed
	-- to already be where it belongs. It gets the same walk home with a slack
	-- that allows for the line it legitimately walks.
	--
	local home_x, home_z = self._grug_work_x, self._grug_work_z
	local slack = WORK_SLACK
	if activity.sweep then slack = SWEEP_SPAN + WORK_SLACK end
	local dx = (home_x or pos.x) - pos.x
	local dz = (home_z or pos.z) - pos.z
	if dx * dx + dz * dz > slack * slack then
		local stalled = grug_mobs.stall_clock(self, home_x, home_z, pos,
			elapsed)
		if stalled >= WORK_STALL_SNAP and
				grug_mobs.snap_try(self, pos, home_x, home_z, elapsed,
					WORK_STALL_SNAP) then
			return false
		end
		grug_mobs.walk_toward(self, home_x, home_z, pos)
		self:set_animation("walk")
		return false
	end
	grug_mobs.stall_clear(self)
	if not watched(self, pos) then
		-- Nobody within 24 nodes: no activity, no swing, no facing. The one
		-- thing that still happens is STOPPING, and the stand animation goes
		-- with it -- a resident that had just walked home would otherwise jog
		-- on the spot for anyone watching from between the 24-node watch radius
		-- and the engine's much wider object-send range. `set_animation` writes
		-- nothing when the animation is already the one asked for, so a
		-- resident standing quietly out of range costs zero property writes.
		if (self.velocity or 0) ~= 0 then self:set_velocity(0) end
		self.state = "stand"
		self:set_animation("stand")
		return false
	end
	-- The tool and the pose, once per activation. Both halves of `apply_entity`
	-- are no-ops once the composed skin and the held item are what they should
	-- be, and `apply_pose` writes one bone override or nothing at all.
	if not temp.grug_work_dressed then
		temp.grug_work_dressed = true
		apply_race_visual(self, self._grug_npc_race, activity)
	end
	apply_pose(self, activity)
	if activity.sweep then
		local home_x, home_z, far_x, far_z = sweep_ends(self)
		local to_far = temp.grug_sweep_far == true
		local x, z = home_x, home_z
		if to_far then x, z = far_x, far_z end
		local dx, dz = x - pos.x, z - pos.z
		if dx * dx + dz * dz > SWEEP_ARRIVED * SWEEP_ARRIVED then
			grug_mobs.walk_toward(self, x, z, pos)
			self:set_animation("walk")
		else
			temp.grug_sweep_far = not to_far
			self.state = "stand"
			self:set_velocity(0)
		end
		return false
	end
	-- Everything else stands on its socket, facing the feature it works at.
	self.state = "stand"
	if (self.velocity or 0) ~= 0 then self:set_velocity(0) end
	grug_mobs.face_yaw(self, self._grug_face_yaw)
	if activity.swing then
		-- Two seconds of swing every ten. The phase is a runtime counter in
		-- self.temp, so it never reaches staticdata and a reload simply starts
		-- the cycle again.
		local phase = ((temp.grug_swing or 0) + elapsed) % SWING_PERIOD
		temp.grug_swing = phase
		self:set_animation(phase < SWING_ON and "work" or activity.anim)
	else
		self:set_animation(activity.anim)
	end
	return false
end

--
-- What a resident does is decided ONCE, by which socket it was placed on: a
-- `work` socket writes `_grug_work_activity` and a resident that carries one
-- never ambles. Both are plain fields, so the choice survives unload/reload
-- with the mob and no activation has to re-derive it.
--
local function resident_tick(self, dtime)
	if self._grug_work_activity then
		return work_tick(self, dtime)
	end
	return amble_tick(self, dtime)
end

--
-- The quest shell's own tick. It exists for ONE reason -- the nametag gate
-- needs a per-second slot and an elder has no movement to hang one on -- so it
-- does nothing else at all, and it returns false for the same reason the work
-- tick does: an elder that never reaches `do_states` also never has its
-- authored facing overwritten by mobs_redo's random idle turn (api.lua:2176-2864).
--
local function elder_tick(self, dtime)
	self.temp = self.temp or {}
	local temp = self.temp
	temp.grug_elder_acc = (temp.grug_elder_acc or 0) + dtime
	if temp.grug_elder_acc < WORK_TICK then return false end
	temp.grug_elder_acc = 0
	tag_gate(self)
	return false
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
		-- (api.lua:1178-1207: `or self.walk_chance == 0` is an alternative to having
		-- a solid node in front worth hopping onto). do_jump runs four times a
		-- second from on_step and only skips a mob whose vertical velocity is
		-- non-zero, so every one of these villagers hopped again the instant it
		-- landed, for the whole length of every walk -- with `jump_height = 4`
		-- and the `core.after(0.3, set_acceleration{y = 0})` that follows the
		-- jump in the same function. In Highcourt's core, where a villager's
		-- idle spots are further apart, that is most of its life.
		--
		-- `do_jump` returns before that clause when `jump_height == 0`
		-- (api.lua:1178-1207), which is the switch. `jump` itself is not a field
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
			-- THE TWO WORK RANGES (contract section 8.2), taken from
			-- `mods/BASE/player_api/init.lua`'s own registration of
			-- `character.b3d`: `mine` is 189..198 and `sit` is 81..160.
			-- `work` is the mine swing at a THIRD of the player's 30 fps, which
			-- is what turns a punch into a hammer blow, a hoe stroke and an axe
			-- swing; `sit` loops the sit range at its own pace. Both are extra
			-- keys of the same animation table, so `mob_class:set_animation`
			-- reaches them by name and still writes nothing when the animation
			-- is already the one asked for (api.lua:500-548).
			work_start = 189, work_end = 198, work_speed = 10,
			sit_start = 81, sit_end = 160, sit_speed = 15,
		},

		-- The character-visuals seam
		-- (docs/research/wp13-character-visuals-contract.md section 2). Inert
		-- until that lane merges, and NB mobs_redo copies only its own def
		-- whitelist onto the entity (api.lua:3956-4112), so the consumer reads
		-- this off `core.registered_entities[name]`, not off `self`.
		_grug_visual = {race = race_id},

		-- ANY truthy return cancels the punch outright (api.lua:3204-3208).
		do_punch = function()
			return true
		end,
	}
	for field, value in pairs(extra) do def[field] = value end
	-- NON-COMBATANT (user ruling, playtest round 2, 2026-09-15): nothing in the
	-- world may acquire a villager or an elder. The four `attack_*` fields above
	-- only say what THIS NPC attacks; this says what may attack IT, which is the
	-- half round 1 expressed by giving every hostile `attack_npcs = false` -- and
	-- that also stopped hostiles from ever fighting a guard. LAST, because it
	-- wraps `after_activate`, which `extra` may have just supplied.
	return grug_mobs.noncombatant(def)
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
			do_custom = resident_tick,
			after_activate = function(self)
				-- The name the PLACEMENT resolved (start_npcs.lua), because one
				-- entity per race serves that race's start and its capital.
				-- The race's own start flavour is the fallback for anything
				-- this engine did not place.
				local name = self._grug_npc_name or names.villager
				self._grug_npc_race = race_id
				self._grug_npc_tag = name
				install_nametag(self, name)
				-- A WORK RESIDENT COMES BACK HOLDING ITS TOOL. On a reload the
				-- activity is already in staticdata, so the hand can be dressed
				-- here; a fresh placement has no activity yet (`install` runs
				-- after `add_entity` activated the entity) and the first work
				-- tick dresses it instead.
				local activity = ACTIVITY[self._grug_work_activity]
				apply_race_visual(self, race_id, activity)
				if activity then
					self.temp = self.temp or {}
					self.temp.grug_work_dressed = true
					apply_pose(self, activity)
				end
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
			-- The elder's only tick: the nametag proximity gate needs a
			-- per-second slot and the quest shell has no movement to hang one
			-- on (see `elder_tick`).
			do_custom = elder_tick,
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

--
-- Startup audit of the activity tools (the pattern grug_traders' own audits
-- established: a check nobody sees the result of is a check nobody notices
-- breaking).
--
-- An item nobody registered draws NOTHING through the wield seam
-- (grug_visuals/apply.lua refuses to spawn a wielditem for an unknown name),
-- so a renamed or retired tool would leave the smith swinging an empty fist and
-- nothing would say so. This says so. Sorted, because `pairs` order over the
-- activity table is not reproducible and a log line that reorders itself is a
-- log line nobody can diff.
--
-- WAVE 2 ADDED THE WEAPON HALF. `spar` names a grug_gear family rather than an
-- item, so what the audit has to resolve is the family at its bracket -- and it
-- does that through the global rather than a dependency, because `grug_mobs`
-- has none on `grug_gear` and `core.global_exists` is the only way to probe a
-- global without tripping `strict.lua` (docs/research/luanti-lua.md). A missing
-- `grug_gear` is reported like an unregistered item: it is the same failure for
-- the player, an empty hand.
core.register_on_mods_loaded(function()
	local items = core.registered_items or {}
	local missing, tools, families = {}, 0, 0
	local gear = core.global_exists("grug_gear") and grug_gear or nil
	for name, activity in pairs(ACTIVITY) do
		if activity.item then
			tools = tools + 1
			if not items[activity.item] then
				missing[#missing + 1] = name .. "=" .. activity.item
			end
		end
		if activity.weapon_family then
			families = families + 1
			local resolved = gear and gear.weapon_item and
				gear.weapon_item(activity.weapon_family, activity.bracket or 1)
			if type(resolved) ~= "string" or not items[resolved] then
				missing[#missing + 1] = name .. "=" .. activity.weapon_family ..
					"/" .. tostring(resolved)
			end
		end
	end
	if #missing == 0 then
		-- Counts as labelled fields rather than as English plurals: "1 weapon
		-- families" is what a naive concatenation says, and this line is
		-- asserted verbatim by tools/wp13/start_npcs_kat.lua.
		core.log("action", "[grug_mobs] settlement work activities: tools " ..
			tools .. ", weapon families " .. families .. ", all registered")
		return
	end
	table.sort(missing)
	core.log("error", "[grug_mobs] settlement work activities wield " ..
		"unregistered items, so those hands stay empty: " ..
		table.concat(missing, " "))
end)
