-- /home (Round 76.2, user 2026-11-11): the same Return home as the button on
-- the Character page and the quickbar, typed instead of clicked. It adds no
-- rule of its own: grug_home.return_home decides (alive, out of combat, not
-- refused by a return guard such as an Expedition's lava, the 30-minute
-- cooldown, in that order) and answers those refusals itself. The command
-- only answers what the button never meets or where return_home stays
-- silent:
-- - character creation and its waiting point (a map-reset relocation or a
--   world still being prepared): the inventory, and with it both buttons, is
--   suspended there, and the respawn refuses the same state
--   (grug_factions); a home exists already, so without this check /home
--   would teleport the held player out and start the cooldown;
-- - no home (only a character without a faction, i.e. still in creation);
-- - a trip already being prepared (a return, a waystone or a lift: the
--   button reads "Preparing arrival" and a click does nothing);
-- - a dead player.
core.register_chatcommand("home", {
 description = "Return home (the Return home button, with its 30-minute cooldown)",
 func = function(name)
  local player = core.get_player_by_name(name)
  if not player then return false, "You must be in the game to return home." end
  if grug_core.player_in_creation_stasis and grug_core.player_in_creation_stasis(name) then
   return false, "You cannot return home yet."
  end
  if not grug_home.get(player) then return false, "You cannot return home yet." end
  if grug_home.is_pending(player) then return false, "Travel is already being prepared." end
  if player:get_hp() <= 0 then return false, "You cannot return home while dead." end
  grug_home.return_home(player)
  return true
 end,
})
