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
-- Formspec clicks: the "click" spec's file is added to every formspec through
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
	"quest_page", "quest_accept", "quest_abandon", "quest_complete", "quest_progress",
	-- Trade and money.
	"vendor_buy", "vendor_sell", "money",
	-- Progression.
	"level_up", "profession_learned", "profession_tier", "talent", "achievement",
	-- Crafting, station operations, the crown and repair.
	"craft", "craft_smithy", "craft_cooking", "craft_alchemy", "enchant",
	"upgrade", "crown", "repair",
	-- Items.
	"equip", "cloak", "potion_drink", "drop_blue", "drop_gold", "drop_bag", "drop_boss",
	-- Mounts and boats.
	"mount_summon", "mount_dismount", "mount_gallop", "mount_wings", "boat_splash",
	-- Travel and the world.
	"travel", "respawn", "zone_banner", "pvp_on", "pvp_off",
	-- Fishing.
	"fishing_cast", "fishing_catch",
}

-- Filled with the user's picks (tools/r34_s1a/approved.txt).
local EVENTS = {
	-- The existing drinking sound of grug_alchemy (VoxeLibre, CC0).
	potion_drink = {name = "grug_alchemy_drink", personal = true},
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
