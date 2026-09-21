# Round 15 playtest

Status: final technical gates PASS; delivery pending. Restart the game after
delivery and use a fresh world for the changed POI structures. Prefer two
same-faction characters for atlas/party checks. No full-world preparation is
needed for this test.

1. At a starter quest giver, check the larger yellow/silver `!` and `?` symbols.
   Their upper extent should stay at its former height. Walk away and back;
   individual quest states and the existing visibility distance should still work.
2. Accept and track quests. The tracker belongs at middle-right and wraps long
   text. Create a party: names/HP belong at middle-left. Test both page toggles;
   no quests/no party should hide the corresponding HUD. Check your usual HUD
   scaling and a smaller window for overlap, including GUI scale 1 with HUD
   scale 0.5.
3. Earn XP, then cross a level boundary. The thin gold bar above the hotbar fills
   for the current level; the old XP text is gone. `/xp` still gives exact values.
4. Open Map and turn/move where possible. Your gold triangle and a moving party
   member's cyan triangle should show position and heading in world and region
   views. Hover/click for names. A member who logs out disappears from the map
   but remains in the party's offline list. Close the map, reopen inventory
   (Character should appear), then click Map again to resume the live view.
5. Inspect an atlas quest symbol before acceptance, while active and when ready.
   Quest givers in the same settlement share a marker with relevant names/statuses in the
   tooltip. The map does not remotely accept/complete quests or teleport you.
6. Visit Goldmead village, Redtusk outpost and Mournfen bandit camp. Judge them
   from their road approaches and inside: distinct forms, usable entrances and
   lookout, furnishings and a readable working/captive area. Visit another
   culture if convenient to compare actual layout diversity.
7. Talk to the additional village giver and the existing outpost/camp contacts.
   Try a local item hand-in and a combat side quest. Read hints critically: the
   ordinary supplies and targets should be obtainable locally. Check reward feel
   without treating all optional quests as mandatory progression.

8. Cooking regression, with two clients on the same updated server: first let
   both characters open Cooking without learning. Only A learns; B then opens
   again without pressing Learn. B should still see Learn. If not, preserve the
   state and report server/time/character names plus the matching `[grug_jobs]
   trainer_` log lines and whether B has the Cooking book. Repeat with both
   trainer dialogs initially open if sequential use succeeds. Details:
   [Cooking investigation](round15-cooking-investigation.md).

Report overlap, misleading quest hints, inaccessible POI spaces and any map
refresh/click problem. Group/fishing findings from the prior playtest remain
welcome; their original checks are in [Round 14](round14-playtest.md).
