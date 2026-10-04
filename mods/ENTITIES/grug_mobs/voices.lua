--
-- Mob voices by family (Round 34 S1b, docs/planning/round34-plan.md §4.3).
--
-- A definition names its family in `_grug_voice`; grug_mobs.register_mob
-- turns it into the mobs_redo `sounds` table (a sub-type copies the field with
-- its base definition and gets the same voice). Every entry is a grug_sounds
-- event name: the vendored mob_sound plays it through grug_sounds.play
-- (GRUG PATCH), whose spec carries gain, pitch spread, distance and a per-mob
-- interval, so a mob hit several times a second grunts once. An event without
-- an approved file has no spec and is left out here, so the mob stays silent
-- for it (approval gate, plan §1). `_grug_voice = false` is a mob without a
-- voice (fish).
--
-- mobs_redo plays war_cry when a mob takes a target (90 %) and when its path
-- finder finds a route during a chase, damage on every health loss, death
-- once, random on 1 % of its one-second ticks. Random calls are the layer
-- most likely to become noise, so no family has one. A family's `telegraph`
-- is its elite wind-up cue (telegraph.lua); without one the wind-up is silent.
--
-- Felines carry no war_cry: they stalk silently (panther.lua; the stalker
-- verb, verbs.lua). The boars share the stalker's pounce but charge loudly.
--

local VOICES = {
	-- Bandits, poachers, mirefolk, the bog witch, guards, kings and generals.
	humanoid = {damage = "voice_humanoid_damage", death = "voice_humanoid_death"},
	goblin = {war_cry = "voice_goblin_war_cry", damage = "voice_goblin_damage",
		death = "voice_goblin_death"},
	-- Zombies.
	undead = {war_cry = "voice_undead_war_cry", damage = "voice_undead_damage",
		death = "voice_undead_death"},
	-- The sun-dried husks and mummies.
	mummy = {damage = "voice_mummy_damage", death = "voice_mummy_death"},
	skeleton = {damage = "voice_skeleton_damage", death = "voice_skeleton_death"},
	-- Wisps, ember wisps, the lava flan, the oerkki and the rift spawn.
	spirit = {damage = "voice_spirit_damage", death = "voice_spirit_death"},
	-- The Land Guard, the dungeon master and the treants.
	giant = {war_cry = "voice_giant_war_cry", damage = "voice_giant_damage",
		death = "voice_giant_death"},
	-- Golems, war constructs and the crystal shard.
	elemental = {damage = "voice_elemental_damage", death = "voice_elemental_death"},
	canine = {war_cry = "voice_canine_war_cry", damage = "voice_canine_damage",
		death = "voice_canine_death"},
	feline = {damage = "voice_feline_damage", death = "voice_feline_death"},
	boar = {war_cry = "voice_boar_war_cry", damage = "voice_boar_damage",
		death = "voice_boar_death"},
	-- Bears and the jungle ape.
	beast = {war_cry = "voice_beast_war_cry", damage = "voice_beast_damage",
		death = "voice_beast_death"},
	-- Stags, rams, ibexes, zebras, tapirs and the plains runner.
	grazer = {damage = "voice_grazer_damage", death = "voice_grazer_death"},
	bird = {damage = "voice_bird_damage", death = "voice_bird_death"},
	-- The Carrion Crow flees by design: a call when it is hit and takes flight
	-- (no roaming call, the user's choice).
	crow = {damage = "voice_crow_damage"},
	-- Rabbits, hares, rats and bats.
	critter = {damage = "voice_critter_damage", death = "voice_critter_death"},
	-- Spiders, crawlers, weevils, mites, scorpions and the glowwing.
	insect = {damage = "voice_insect_damage", death = "voice_insect_death"},
	slime = {damage = "voice_slime_damage", death = "voice_slime_death"},
	-- Crocodiles, serpents, vipers and the dragon whelps.
	reptile = {war_cry = "voice_reptile_war_cry", damage = "voice_reptile_damage",
		death = "voice_reptile_death"},
	-- Crabs and the reef lurker.
	aquatic = {damage = "voice_aquatic_damage", death = "voice_aquatic_death"},
	dragon = {war_cry = "voice_dragon_war_cry", damage = "voice_dragon_damage",
		death = "voice_dragon_death"},
	kraken = {war_cry = "voice_kraken_war_cry", damage = "voice_kraken_damage",
		death = "voice_kraken_death"},
}
grug_mobs.VOICES = VOICES

-- The `sounds` table of `family` with the events that have a sound, or nil.
function grug_mobs.voice_sounds(family)
	local voice = VOICES[family]
	local sounds
	for kind, event in pairs(voice or {}) do
		if grug_sounds.EVENTS[event] then
			sounds = sounds or {}
			sounds[kind] = event
		end
	end
	return sounds
end

-- Installs the family's voice on `def` (register_mob, before mobs_redo copies
-- the definition). Explicit `def.sounds` entries win (the rift spawn's fuse
-- and burst). A definition without `_grug_voice` is an error: every new mob
-- chooses a family, or false for none.
function grug_mobs.apply_voice(name, def)
	local family = def._grug_voice
	if family == nil then
		error("[grug_mobs] " .. name .. ": no _grug_voice (a family of " ..
			"grug_mobs.VOICES, or false for no voice)")
	end
	if family == false then return end
	if not VOICES[family] then
		error("[grug_mobs] " .. name .. ": unknown _grug_voice " .. tostring(family))
	end
	local sounds = grug_mobs.voice_sounds(family)
	if not sounds then return end
	for kind, event in pairs(def.sounds or {}) do sounds[kind] = event end
	def.sounds = sounds
end
