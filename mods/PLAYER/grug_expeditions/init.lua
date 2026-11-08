-- Expeditions (Round 71): repeatable group content in 100 generic slots beyond the
-- map. A run is one activation: the server clears and fills a slot from a template
-- file, the owner's players enter it, and it ends when nobody has been inside for
-- 10 minutes. Rules: docs/planning/round71-expeditions-concept.md sections 2, 4, 5.
-- Nothing about a run is saved: a restart ends every run, a login in a box whose
-- run is gone stands at the waystone the player came in from (one saved value, its
-- id; a registrar's capital, or since Round 72 any waystone of the Expeditions tab),
-- else at home. Packs: packs.lua. The waystones in and out: entry.lua.
--
-- THE INTERFACE (other mods read it; a `run` row is read-only for them)
--
-- Reading. slot_at and run_at are arithmetic, safe on hot paths:
--   slot_at(pos)            the slot (1..100) whose box holds pos, or nil
--   run_at(pos)             the live run in that slot, or nil
--   run_of(player|name)     the live run of the player's owner (their party, or
--                           them), or nil; the player need not be online
--   run_inside(player|name) the run the player stands in now, or nil
--   belongs(run, player|name)
--   slot_box(slot)          minp, maxp
--   definition(id)          a catalogue row {id, name, level, max_level, max_players,
--                           template}: its mob levels run from level to max_level
--   list()                  the rows a dialog may offer (hidden test rows left out)
--   entry_level(level)      min(level - 2, 60)
--   rewards_open(run)       the boss is dead, or the template has none
--   catalogue               catalogue.lua itself: BOX, ORIGIN, PITCH, TIERS, tier_of, ...
--   written(run)            the template as the run's tier writes it: {ids, dig}, the
--                           tier's ore and gem in the template's places
--
-- A run row:
--   id          session-unique number
--   slot        1..100; minp, maxp its box
--   expedition  the catalogue id; bonus 0..max_level - level, level = catalogue
--               level + bonus
--   max_players
--   owner       {kind = "player", name = ...} or {kind = "party", id = ...}
--   creator     the name that opened it
--   state       "preparing", "ready" (nobody entered yet), "running", "ended"
--   entered     set of names holding a place (leaving the party frees it)
--   inside      set of names in the box now, online
--
-- The template's named places and encounter markers, in map coordinates:
--   places(run)             {arrival =, start_waystone =, end_waystone =, chest =,
--                           door =, ...}: what the template names
--   encounters(run)         a list of {room, mob, count, tier, pos}
--   start_arrival(run)      the position a player stands at beside the start
--                           waystone: arrival and respawn
--   preparation(run)        nil, {waiting = n} or {phase, done, total}, for notices
--                           (run.state "preparing" alone is enough for most)
--
-- Eligibility (a refusal is `false, text to show`):
--   offered_levels(player, id)     {{bonus, level}, ...} the player may enter
--   eligibility(player, id, bonus) one row per party member (or the player alone):
--                                  {name, level, online, eligible, reason}
--   can_create(player, id, bonus)  true, or false and why
--   may_enter(player[, run])       the run's own rules (owner, state, level, places):
--                                  true, or false and why; what the Expeditions tab lists
--   can_enter(player[, run])       may_enter and the player's state (alive, out of
--                                  combat): true, or false and why
--
-- Acting (the caller shows the refusal):
--   create(player, id, bonus)  the run, or nil and why; the state is "preparing"
--   enter(player, capital_id[, still])  starts the trip in, or false and why;
--                              capital_id is a grug_home waystone id, where the way
--                              back leads; still(player), when given, is one more
--                              condition on the trip's step
--   leave(player)              the way back to that waystone (scripted; the two stones
--                              open the waystone window, entry.lua)
--   use_waystone(player, pos)  a stone inside: the waystone window without the
--                              Expeditions tab (Round 72)
--   end_run(run, reason)       ends it at once
--   open_door(run)             takes the reward door away and tells those inside
--   open_registrar(player, entity)  the registrar's window; false for a player it
--                              does not serve
--
-- Hooks:
--   register_on_ready(function(run))           the box is written; set meta here
--   register_on_end(function(run, reason))     "empty" (10 minutes), "joined_party"
--                                              (the solo owner), "failed" (preparation)
--   register_on_enter(function(run, name))     stands in the box now
--   register_on_leave(function(run, name, reason))  "travel", "logout", "expelled"
--                                              (left the party), "ended"
--
-- Ownership follows grug_parties' events, the release clock is one core.after per
-- empty stretch, and "inside" follows grug_home's teleports: none of it looks at
-- every player. Rulings: docs/planning/round71-expeditions-concept.md section 4.
grug_expeditions = {}

local path = core.get_modpath(core.get_current_modname())
local catalogue = dofile(path .. "/catalogue.lua")
local template = dofile(path .. "/template.lua")
local preparation = dofile(path .. "/preparation.lua")

-- Read once at load: a broken file stops the server here, not in a preparation.
local REQUIRED_PLACES = {"arrival", "start_waystone", "end_waystone"}
grug_expeditions.templates = {}
for _, row in ipairs(catalogue.EXPEDITIONS) do
	if not grug_expeditions.templates[row.template] then
		grug_expeditions.templates[row.template] = template.load(
			path .. "/templates/" .. row.template .. template.EXTENSION,
			row.template, catalogue.BOX, REQUIRED_PLACES)
	end
end
core.register_on_mods_loaded(function()
	local swaps = catalogue.swaps()
	for _, tpl in pairs(grug_expeditions.templates) do template.resolve(tpl, swaps) end
end)

-- The template as `run` writes it, its tier's ore and gem in the template's places:
-- {ids, dig}. Read by the dig rule (guard.lua).
function grug_expeditions.written(run)
	local tpl = grug_expeditions.templates[catalogue.definition(run.expedition).template]
	return tpl.variants and tpl.variants[catalogue.tier_of(run.level).tier] or tpl
end

assert(loadfile(path .. "/runs.lua"))(catalogue, preparation)
dofile(path .. "/encounters.lua")
dofile(path .. "/guard.lua")
dofile(path .. "/registrar.lua")

-- The two stones inside: the capital's waystone in look, and since Round 72 the
-- ordinary waystone window in function (entry.lua).
core.register_node("grug_expeditions:waystone", {
	description = "Waystone",
	drawtype = "nodebox",
	tiles = {"grug_mapgen_waystone_top.png", "grug_mapgen_waystone_top.png",
		"grug_mapgen_waystone.png"},
	paramtype = "light",
	light_source = 4,
	node_box = {type = "fixed", fixed = {{-0.4, -0.5, -0.4, 0.4, -0.3, 0.4},
		{-0.25, -0.3, -0.25, 0.25, 1, 0.25}}},
	groups = {not_in_creative_inventory = 1},
	diggable = false,
	is_ground_content = false,
	drop = "",
	on_blast = function() end,
	sounds = default.node_sound_stone_defaults(),
	on_rightclick = function(pos, _, clicker)
		if clicker and clicker:is_player() then grug_expeditions.use_waystone(clicker, pos) end
	end,
})

dofile(path .. "/entry.lua")
