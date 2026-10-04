-- grug_sounds: the game's sound events (Round 34, docs/planning/round34-plan.md
-- §4.1). A call site is one line that names an event and who hears it:
--
--   grug_sounds.play("quest_accept", player)  -- a player ObjectRef
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
	"quest_page", "quest_accept", "quest_abandon", "quest_complete",
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
}
-- Silent by the user's choice (plan §2.2a), so without a call site: quest
-- progress, talent, achievement, drops, mount summon and dismount, respawn,
-- zone banner, PvP off and any automatic PvP flag change. Enchant keeps its
-- hook without a sound; quest_complete waits for the user's confirmed cut.

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
	quest_accept = {name = "grug_sounds_quest_accept", gain = 0.7, personal = true},
	quest_abandon = {name = "grug_sounds_quest_abandon", gain = 0.6, personal = true},
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
	local params = {gain = spec.gain or 1, max_hear_distance = spec.distance or DEFAULT_DISTANCE}
	local key
	if target.get_pos then
		if target:is_player() then
			key = target:get_player_name()
			if spec.personal then params.to_player = key else params.object = target end
		else
			key = target
			params.object = target
		end
	else
		key = "pos"
		params.pos = target
	end
	local times = last[event]
	if not times then
		times = setmetatable({}, {__mode = "k"})
		last[event] = times
	end
	local now = seconds()
	local previous = times[key]
	if previous and now - previous < (spec.interval or DEFAULT_INTERVAL) then return false end
	times[key] = now
	if spec.pitch then params.pitch = 1 + (math.random() * 2 - 1) * spec.pitch end
	core.sound_play(spec.name, params, true)
	return true
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
