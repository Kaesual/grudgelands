-- Expeditions (Round 71): repeatable group content in 100 generic slots beyond the
-- map. A run is one activation: the server clears and fills a slot from a template
-- file, the owner's players enter it, and it ends when nobody has been inside for
-- 10 minutes. Rules: docs/planning/round71-expeditions-concept.md sections 2, 4, 5.
-- Nothing about a run is saved: a restart ends every run, a login in a box whose
-- run is gone goes home.
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
--   definition(id)          a catalogue row {id, name, level, max_players, template}
--   list()                  the rows a dialog may offer (hidden test rows left out)
--   entry_level(level)      min(level - 2, 60)
--   catalogue               catalogue.lua itself: BOX, ORIGIN, PITCH, MAX_BONUS, ...
--
-- A run row:
--   id          session-unique number
--   slot        1..100; minp, maxp its box
--   expedition  the catalogue id; bonus 0..9, level = catalogue level + bonus
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
--
-- Eligibility (a refusal is `false, text to show`):
--   offered_levels(player, id)     {{bonus, level}, ...} the player may enter
--   eligibility(player, id, bonus) one row per party member (or the player alone):
--                                  {name, level, online, eligible, reason}
--   can_create(player, id, bonus)  true, or false and why
--   can_enter(player[, run])       true, or false and why
--
-- Acting (the caller shows the refusal):
--   create(player, id, bonus)  the run, or nil and why; the state is "preparing"
--   enter(player, capital_id)  starts the trip in, or false and why; capital_id is a
--                              grug_home location id, where the way back leads
--   leave(player)              the way out of both waystones
--   end_run(run, reason)       ends it at once
--
-- Hooks:
--   register_on_ready(function(run))           the box is written; set meta here
--   register_on_end(function(run, reason))     "failed", more in phase 2
--   register_on_enter(function(run, name))     stands in the box now
--   register_on_leave(function(run, name, reason))  "travel", "logout"
--
-- NOT BUILT YET (lane FRAME phase 2; the interface above does not change for it):
-- changes of owner on party events, teleporting out whoever no longer belongs, the
-- 10-minute release, the login rule. Until then a run ends only through end_run.
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
	for _, tpl in pairs(grug_expeditions.templates) do template.resolve(tpl) end
end)

assert(loadfile(path .. "/runs.lua"))(catalogue, preparation)
dofile(path .. "/registrar.lua")

-- The two stones inside: the capital's waystone in look, the way back in function.
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
	on_rightclick = function(_, _, clicker)
		if clicker and clicker:is_player() then grug_expeditions.use_waystone(clicker) end
	end,
})
