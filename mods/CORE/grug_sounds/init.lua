-- grug_sounds: the game's sound events (Round 34, docs/planning/round34-plan.md
-- §4.1). A call site is one line that names an event and who hears it:
--
--   grug_sounds.play("quest_page", player)    -- a player ObjectRef
--   grug_sounds.play("mount_gallop", object)  -- any other ObjectRef: the sound follows it
--   grug_sounds.play("drop_gold", pos)        -- a position
--
-- EVENTS maps an event to its spec:
--   name      the sound (a file in sounds/, grug_sounds_<what>; the engine picks
--             one of the .1, .2 ... variants at random)
--   gain      default 1
--   pitch     random pitch spread, 0.05 plays at 0.95-1.05 (default none)
--   distance  max_hear_distance of a positional sound (default 16)
--   personal  true: only the target player hears it, not positional
--   interval  at most once per this many seconds per target (default 0.1,
--             which folds the repeats of one server step, e.g. a shift-click
--             craft); a call inside the interval is dropped
-- Every sound is an ephemeral one-shot. Approval gate (plan §1): an event
-- whose file the user has not approved on a listening page has no spec, and
-- its call is a silent no-op. Refusals and errors have no event (user,
-- plan §2.2). HOOKS lists every event a call site may name
-- (tools/r34_s1a/portable_test.lua checks the call sites and the specs
-- against it).
--
-- Formspec clicks: the "click" spec's file (no gain: the client plays it
-- from the style at the file's level) is added to every formspec through
-- the formspec prepend (style_type, played by the client), and CLICK_STYLE
-- carries it into the two formspecs that drop the prepend (no_prepend[]).

grug_sounds = {}

grug_sounds.HOOKS = {
	-- Formspec buttons, checkboxes, tabs and dropdowns (style_type sound).
	"click",
	-- NPC dialogs: one cue per role (plan §2.1 ruling 2).
	"npc_quest", "npc_vendor", "npc_trainer", "npc_innkeeper", "npc_stable",
	"npc_shipwright", "npc_steward", "npc_crownbinder",
	-- Quests.
	"quest_page", "quest_abandon", "quest_complete",
	-- Trade and money (the Bag of Coins deposit).
	"vendor_buy", "vendor_sell", "money",
	-- Progression.
	"level_up", "profession_learned", "profession_tier",
	-- Crafting, station operations, the crown and repair.
	"craft", "craft_smithy", "craft_cooking", "craft_alchemy", "enchant",
	"upgrade", "crown", "repair",
	-- Items.
	"equip", "cloak", "potion_drink",
	-- Mounts and boats, repeated while moving (their interval is the clip).
	"mount_gallop", "mount_wings", "boat_splash",
	-- Travel and the PvP button.
	"travel", "pvp_on",
	-- Fishing.
	"fishing_cast", "fishing_catch",
	-- Combat (Round 34 S1b, plan §4.3): the swing into the air (an item sound
	-- of the swing skills' tools, played by the client), a player's hit by the
	-- kind of the equipped melee weapon, an absorb shield taking a hit, dodge
	-- and a player's death.
	"swing", "hit_blade", "hit_dagger", "hit_blunt", "hit_fist", "block", "dodge",
	"player_death",
	-- Abilities: one cue per theme at the caster (grug_abilities.CAST_SOUNDS);
	-- a projectile sounds at launch and at its hit (grug_projectiles.register).
	"cast_charge", "cast_taunt", "cast_guard", "cast_frost_nova",
	"cast_frost_ward", "cast_cinderfall", "cast_holy", "cast_heal",
	"cast_shield", "cast_shadow", "cast_evade",
	"fireball_launch", "fireball_hit", "bow_shot", "arrow_hit",
	-- Mob voices by family (grug_mobs.VOICES), played by mobs_redo's mob_sound.
	"voice_humanoid_damage", "voice_humanoid_death",
	"voice_goblin_war_cry", "voice_goblin_damage", "voice_goblin_death",
	"voice_undead_war_cry", "voice_undead_damage", "voice_undead_death",
	"voice_mummy_damage", "voice_mummy_death",
	"voice_skeleton_damage", "voice_skeleton_death",
	"voice_spirit_damage", "voice_spirit_death",
	"voice_giant_war_cry", "voice_giant_damage", "voice_giant_death",
	"voice_elemental_damage", "voice_elemental_death",
	"voice_canine_war_cry", "voice_canine_damage", "voice_canine_death",
	"voice_feline_damage", "voice_feline_death",
	"voice_boar_war_cry", "voice_boar_damage", "voice_boar_death",
	"voice_beast_war_cry", "voice_beast_damage", "voice_beast_death",
	"voice_grazer_damage", "voice_grazer_death",
	"voice_bird_damage", "voice_bird_death",
	"voice_crow_damage",
	"voice_critter_damage", "voice_critter_death",
	"voice_insect_damage", "voice_insect_death",
	"voice_slime_damage", "voice_slime_death",
	"voice_reptile_war_cry", "voice_reptile_damage", "voice_reptile_death",
	"voice_aquatic_damage", "voice_aquatic_death",
	"voice_dragon_war_cry", "voice_dragon_damage", "voice_dragon_death",
	"voice_kraken_war_cry", "voice_kraken_damage", "voice_kraken_death",
	-- Bosses: the dragons' wind-up growl, breath, lightning, enrage and
	-- wrath, the breaking arena ice, the kings' and Generals' signature attack.
	"telegraph", "dragon_breath_frost", "dragon_breath_fire", "dragon_lightning",
	"dragon_enrage", "dragon_wrath", "ice_break", "king_signature",
}
-- Silent by the user's choice (plan §2.2a), so without a call site: quest
-- accept and progress, talent, achievement, drops, mount summon and dismount,
-- respawn, zone banner, PvP off and any automatic PvP flag change; in combat
-- crit, Blink, Sprint, the Carrion Crow's roaming call and the wind-up of
-- every elite but the humanoids (S1b). Enchant keeps its hook without a sound.

-- The user's picks (tools/r34_s1a/approved.txt). Files are peak-normalised
-- to -3 dBFS; the gains set the balance (quiet, frequent cues lower). UI and
-- dialog cues are personal; crafting, mounts, fishing and travel are heard
-- nearby.
local EVENTS = {
	click = {name = "grug_sounds_click"},
	npc_quest = {name = "grug_sounds_npc_quest", gain = 0.6, personal = true},
	npc_vendor = {name = "grug_sounds_coins", gain = 0.5, personal = true},
	npc_trainer = {name = "grug_sounds_npc_trainer", gain = 0.6, personal = true},
	npc_innkeeper = {name = "grug_sounds_npc_innkeeper", gain = 0.6, personal = true},
	npc_stable = {name = "grug_sounds_npc_stable", gain = 0.6, personal = true},
	npc_shipwright = {name = "grug_sounds_npc_shipwright", gain = 0.6, personal = true},
	npc_steward = {name = "grug_sounds_npc_steward", gain = 0.6, personal = true},
	npc_crownbinder = {name = "grug_sounds_npc_crownbinder", gain = 0.6, personal = true},
	quest_page = {name = "grug_sounds_quest_page", gain = 0.5, personal = true},
	quest_abandon = {name = "grug_sounds_quest_abandon", gain = 0.6, personal = true},
	quest_complete = {name = "grug_sounds_quest_complete", gain = 0.7, personal = true},
	vendor_buy = {name = "grug_sounds_coins", gain = 0.6, personal = true, pitch = 0.05},
	vendor_sell = {name = "grug_sounds_coins", gain = 0.6, personal = true, pitch = 0.05},
	money = {name = "grug_sounds_money", gain = 0.7, personal = true},
	level_up = {name = "grug_sounds_level_up", gain = 0.8, personal = true},
	profession_learned = {name = "grug_sounds_profession_learned", gain = 0.7, personal = true},
	profession_tier = {name = "grug_sounds_profession_tier", gain = 0.8, personal = true},
	craft = {name = "grug_sounds_craft", gain = 0.5, distance = 10, pitch = 0.05},
	craft_smithy = {name = "grug_sounds_craft_smithy", gain = 0.6, distance = 16},
	craft_cooking = {name = "grug_sounds_craft_cooking", gain = 0.5, distance = 10},
	craft_alchemy = {name = "grug_sounds_craft_alchemy", gain = 0.5, distance = 10},
	upgrade = {name = "grug_sounds_upgrade", gain = 0.6, distance = 16},
	crown = {name = "grug_sounds_crown", gain = 0.7, personal = true},
	repair = {name = "grug_sounds_repair", gain = 0.6, distance = 16},
	equip = {name = "grug_sounds_equip", gain = 0.4, personal = true, pitch = 0.05},
	cloak = {name = "grug_sounds_cloak", gain = 0.5, personal = true},
	-- The existing drinking sound of grug_alchemy (VoxeLibre, CC0).
	potion_drink = {name = "grug_alchemy_drink", personal = true},
	mount_gallop = {name = "grug_sounds_mount_gallop", gain = 0.5, distance = 24, interval = 2.35},
	mount_wings = {name = "grug_sounds_mount_wings", gain = 0.5, distance = 24, interval = 1.5},
	boat_splash = {name = "grug_sounds_splash", gain = 0.3, distance = 16, interval = 1.6, pitch = 0.1},
	travel = {name = "grug_sounds_travel", gain = 0.7, distance = 16},
	pvp_on = {name = "grug_sounds_pvp_on", gain = 0.7, personal = true},
	fishing_cast = {name = "grug_sounds_splash", gain = 0.4, distance = 10, pitch = 0.1},
	fishing_catch = {name = "grug_sounds_splash", gain = 0.6, distance = 12},
	-- Combat and creatures (S1b, tools/r34_s1b/approved.txt). Hits, voices
	-- and spells follow their target or caster. Voices carry a per-mob
	-- interval, so a mob hit several times a second grunts once and a chase
	-- does not repeat its war cry; frequent cues sit lower.
	swing = {name = "grug_sounds_swing", gain = 0.5},
	hit_blade = {name = "grug_sounds_hit_blade", gain = 0.7, distance = 12, pitch = 0.05},
	hit_dagger = {name = "grug_sounds_hit_dagger", gain = 0.7, distance = 12, pitch = 0.05},
	hit_blunt = {name = "grug_sounds_hit_blunt", gain = 0.7, distance = 12, pitch = 0.05},
	-- The existing mobs_redo punch stays for fists (R32 3.5, CC0).
	hit_fist = {name = "mobs_punch", distance = 8},
	block = {name = "grug_sounds_block", gain = 0.6, distance = 12, interval = 0.4},
	dodge = {name = "grug_sounds_dodge", gain = 0.5, distance = 10, interval = 0.3},
	player_death = {name = "grug_sounds_player_death", gain = 0.8, distance = 16},
	cast_guard = {name = "grug_sounds_cast_guard", gain = 0.7},
	cast_frost_ward = {name = "grug_sounds_cast_frost_ward", gain = 0.6},
	cast_cinderfall = {name = "grug_sounds_cast_cinderfall", gain = 0.8, distance = 20},
	cast_holy = {name = "grug_sounds_cast_holy", gain = 0.7},
	cast_heal = {name = "grug_sounds_cast_heal", gain = 0.6},
	cast_shield = {name = "grug_sounds_cast_shield", gain = 0.6},
	cast_shadow = {name = "grug_sounds_cast_shadow", gain = 0.7},
	cast_evade = {name = "grug_sounds_cast_evade", gain = 0.6},
	fireball_launch = {name = "grug_sounds_fireball_launch", gain = 0.6, pitch = 0.05},
	fireball_hit = {name = "grug_sounds_fireball_hit", gain = 0.7, pitch = 0.05},
	bow_shot = {name = "grug_sounds_bow_shot", gain = 0.6, pitch = 0.05},
	arrow_hit = {name = "grug_sounds_arrow_hit", gain = 0.7, distance = 12, pitch = 0.05},
	-- Voices. Humans, zombies and mummies share one hurt sound (R34 C7.1).
	voice_humanoid_damage = {name = "grug_sounds_voice_humanoid_damage", gain = 0.6, interval = 1.5, pitch = 0.08},
	voice_goblin_war_cry = {name = "grug_sounds_voice_goblin_war_cry", gain = 0.6, interval = 8},
	voice_goblin_damage = {name = "grug_sounds_voice_goblin_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_goblin_death = {name = "grug_sounds_voice_goblin_death", gain = 0.7},
	voice_undead_war_cry = {name = "grug_sounds_voice_undead_war_cry", gain = 0.6, interval = 8},
	voice_undead_damage = {name = "grug_sounds_voice_humanoid_damage", gain = 0.6, interval = 1.5, pitch = 0.08},
	voice_undead_death = {name = "grug_sounds_voice_undead_death", gain = 0.7},
	voice_mummy_damage = {name = "grug_sounds_voice_humanoid_damage", gain = 0.6, interval = 1.5, pitch = 0.08},
	voice_mummy_death = {name = "grug_sounds_voice_mummy_death", gain = 0.7},
	voice_skeleton_damage = {name = "grug_sounds_voice_skeleton_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_skeleton_death = {name = "grug_sounds_voice_skeleton_death", gain = 0.7},
	voice_spirit_damage = {name = "grug_sounds_voice_spirit_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_spirit_death = {name = "grug_sounds_voice_spirit_death", gain = 0.7},
	voice_giant_war_cry = {name = "grug_sounds_voice_giant_war_cry", gain = 0.7, distance = 24, interval = 10},
	voice_giant_damage = {name = "grug_sounds_voice_giant_damage", gain = 0.6, distance = 20, interval = 2},
	voice_giant_death = {name = "grug_sounds_voice_giant_death", gain = 0.8, distance = 24},
	voice_elemental_damage = {name = "grug_sounds_voice_elemental_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_elemental_death = {name = "grug_sounds_voice_elemental_death", gain = 0.7, distance = 20},
	voice_canine_war_cry = {name = "grug_sounds_voice_canine_war_cry", gain = 0.6, interval = 8, pitch = 0.05},
	voice_canine_damage = {name = "grug_sounds_voice_canine_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_canine_death = {name = "grug_sounds_voice_canine_death", gain = 0.7},
	voice_feline_damage = {name = "grug_sounds_voice_feline_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_feline_death = {name = "grug_sounds_voice_feline_death", gain = 0.7},
	voice_boar_war_cry = {name = "grug_sounds_voice_boar_war_cry", gain = 0.6, interval = 8},
	voice_boar_damage = {name = "grug_sounds_voice_boar_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_boar_death = {name = "grug_sounds_voice_boar_death", gain = 0.7},
	voice_beast_war_cry = {name = "grug_sounds_voice_beast_war_cry", gain = 0.7, distance = 20, interval = 10},
	voice_beast_damage = {name = "grug_sounds_voice_beast_damage", gain = 0.6, interval = 1.5, pitch = 0.05},
	voice_beast_death = {name = "grug_sounds_voice_beast_death", gain = 0.7, distance = 20},
	voice_grazer_damage = {name = "grug_sounds_voice_grazer_damage", gain = 0.5, interval = 1.5, pitch = 0.08},
	voice_grazer_death = {name = "grug_sounds_voice_grazer_death", gain = 0.6},
	voice_bird_damage = {name = "grug_sounds_voice_bird_damage", gain = 0.5, interval = 1.5, pitch = 0.08},
	voice_bird_death = {name = "grug_sounds_voice_bird_death", gain = 0.6},
	voice_crow_damage = {name = "grug_sounds_voice_crow_damage", gain = 0.5, interval = 2, pitch = 0.05},
	voice_critter_damage = {name = "grug_sounds_voice_critter_damage", gain = 0.5, interval = 1.5, pitch = 0.08},
	voice_critter_death = {name = "grug_sounds_voice_critter_death", gain = 0.5},
	voice_insect_damage = {name = "grug_sounds_voice_insect_damage", gain = 0.5, interval = 1.5, pitch = 0.08},
	voice_insect_death = {name = "grug_sounds_voice_insect_death", gain = 0.6},
	voice_slime_damage = {name = "grug_sounds_voice_slime_damage", gain = 0.5, interval = 1.5, pitch = 0.05},
	voice_slime_death = {name = "grug_sounds_voice_slime_death", gain = 0.6},
	voice_reptile_war_cry = {name = "grug_sounds_voice_reptile_war_cry", gain = 0.5, interval = 8},
	voice_reptile_damage = {name = "grug_sounds_voice_reptile_damage", gain = 0.5, interval = 1.5, pitch = 0.05},
	voice_reptile_death = {name = "grug_sounds_voice_reptile_death", gain = 0.6},
	voice_aquatic_damage = {name = "grug_sounds_voice_aquatic_damage", gain = 0.5, interval = 1.5, pitch = 0.08},
	voice_aquatic_death = {name = "grug_sounds_voice_aquatic_death", gain = 0.5},
	voice_dragon_war_cry = {name = "grug_sounds_voice_dragon_war_cry", gain = 0.9, distance = 64, interval = 15},
	voice_dragon_damage = {name = "grug_sounds_voice_dragon_damage", gain = 0.7, distance = 48, interval = 6},
	voice_dragon_death = {name = "grug_sounds_voice_dragon_death", gain = 1, distance = 80},
	voice_kraken_war_cry = {name = "grug_sounds_voice_kraken_war_cry", gain = 0.8, distance = 40, interval = 15},
	voice_kraken_damage = {name = "grug_sounds_voice_kraken_damage", gain = 0.7, distance = 32, interval = 3},
	voice_kraken_death = {name = "grug_sounds_voice_kraken_death", gain = 0.9, distance = 48},
	-- Bosses. The dragon's wind-up growl at most every 10 s (a breath or
	-- lightning wind-up comes every 6-8 s); enrage is the 11.1 roar again.
	telegraph = {name = "grug_sounds_telegraph", gain = 0.8, distance = 48, interval = 10},
	dragon_breath_frost = {name = "grug_sounds_dragon_breath_frost", gain = 0.8, distance = 40},
	dragon_breath_fire = {name = "grug_sounds_dragon_breath_fire", gain = 0.8, distance = 40},
	dragon_lightning = {name = "grug_sounds_dragon_lightning", gain = 0.9, distance = 48},
	dragon_enrage = {name = "grug_sounds_voice_dragon_war_cry", gain = 1, distance = 80},
	dragon_wrath = {name = "grug_sounds_dragon_wrath", gain = 0.7, personal = true},
	-- A run over thin ice breaks a band every 0.25 s; one clip a second keeps
	-- it one continuous breaking instead of a stack of 2 s clips.
	ice_break = {name = "grug_sounds_ice_break", gain = 0.6, distance = 24, interval = 1},
	king_signature = {name = "grug_sounds_king_signature", gain = 0.8, distance = 24},
}
grug_sounds.EVENTS = EVENTS

local DEFAULT_INTERVAL = 0.1
local DEFAULT_DISTANCE = 16

-- event -> target key -> time of the last play. A key is a player name
-- (dropped on leave), "pos" for positions, or another ObjectRef (weak keys:
-- a removed mount's entry goes with its ObjectRef).
local last = {}

local function seconds()
	return core.get_us_time() / 1000000
end

-- Plays `event` for `target`; returns true when a sound was sent.
function grug_sounds.play(event, target)
	local spec = EVENTS[event]
	if not spec or target == nil then return false end
	-- The limit first: a dropped call (a mount's step) allocates nothing.
	local object = target.get_pos ~= nil
	local player = object and target:is_player()
	local key = player and target:get_player_name() or object and target or "pos"
	local times = last[event]
	if not times then
		times = setmetatable({}, {__mode = "k"})
		last[event] = times
	end
	local now = seconds()
	local previous = times[key]
	if previous and now - previous < (spec.interval or DEFAULT_INTERVAL) then return false end
	times[key] = now
	local params = {gain = spec.gain or 1, max_hear_distance = spec.distance or DEFAULT_DISTANCE}
	if not object then
		params.pos = target
	elseif player and spec.personal then
		params.to_player = key
	else
		params.object = target
	end
	if spec.pitch then params.pitch = 1 + (math.random() * 2 - 1) * spec.pitch end
	core.sound_play(spec.name, params, true)
	return true
end

-- The SimpleSoundSpec of `event` for an item definition's `sound` table
-- (the client plays it, e.g. punch_use_air), or nil without a spec.
function grug_sounds.item_sound(event)
	local spec = EVENTS[event]
	return spec and {name = spec.name, gain = spec.gain or 1} or nil
end

grug_sounds.CLICK_STYLE = EVENTS.click and
	("style_type[button,image_button,checkbox,tabheader,dropdown;sound=" ..
		EVENTS.click.name .. "]") or ""

-- `default` sets the prepend on join; this mod depends on it, so its join
-- callback runs later and extends that prepend.
if grug_sounds.CLICK_STYLE ~= "" then
	core.register_on_joinplayer(function(player)
		player:set_formspec_prepend(player:get_formspec_prepend() .. grug_sounds.CLICK_STYLE)
	end)
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	for _, times in pairs(last) do times[name] = nil end
end)
