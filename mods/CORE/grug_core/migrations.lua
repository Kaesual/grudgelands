-- The game's migration steps (Round 43; the hosting platform's migration
-- contract, docs/technical/upgrade-contract.md). A step converts a stopped
-- world of the previous version offline: the tool `python3 tools/migrate.py
-- --world <dir>` runs its file `tools/migration/steps/v<major>_<minor>_<patch>.py`.
-- A step that leaves online work writes markers, and the game finishes them
-- (grug_core/world_version.lua):
--   the world part:    mod storage of grug_core, key "migrate_world:<version>",
--                      at the next load, once every mod has loaded (so after
--                      every map-reset clear);
--   a character part:  player meta "grug_core:migrate:<version>", at that
--                      character's next join, before any other join callback.
-- Pending markers run in step order; each is deleted only after its handler
-- succeeded. A failing world handler stops the load; a failing character
-- handler disconnects that character with the marker kept, so the next load or
-- join runs the handler again: a handler must be safe to run again over what
-- the failed attempt and the game's own load or join left.
--
-- This file lives in the runtime tree, which a managed server keeps without
-- tools/ (the start guard cannot read tools/web_data/upgrade.json there).
grug_core.migrations = {
	-- The declaration's `migrate` list, ascending: the guard refuses a world
	-- whose record lies before one of them. tools/check_upgrade.py proves this
	-- list equal to tools/web_data/upgrade.json's `migrate` list.
	versions = {},
	-- Online work, only for a step that leaves some:
	--   handlers["x.y.z"] = {
	--     world = function(marker) end,             -- marker: the stored value
	--     character = function(player, marker) end,
	--   }
	handlers = {},
}
