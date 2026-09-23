# Round 19 playtest

Prepared checklist; technical readiness and delivery are recorded in
round19-completion.md when available. Restart the server after local sync.
Use a fresh development world; no personal data migration is part of this round.

## First pass (about five minutes)

1. **Map overview:** open Map. The complete map fills the canvas without a large
   unused band or distortion. Regional-view buttons are gone; Return Home and
   zoom controls remain outside the map.
2. **Zoom and scroll:** use + for 2x and 4x. Scroll in both directions to all four
   corners; zoom preserves the viewed center until clamped at an edge. NPC,
   boss, quest and player icons remain the same on-screen size. Hover/click a
   marker near an edge: no unexpected jump or hidden marker covering controls.
3. **Live map state:** while another party member moves, keep a scrolled view
   open. Updates must preserve zoom/scroll. Switch tabs and return: full overview
   again. Close inventory and reopen Map: full overview again. Return Home still
   follows its ordinary authorization/cooldown rules.
4. **Character and Help:** Character shows concise HP/resource, armor, Crit,
   Dodge and money. No Pool and Armor Details. General formulas are in Help.
5. **Talents:** spend one available point with one click; exactly one rank is
   bought. Hover describes talents. Crit/Armor/Dodge rows are gone. Locked/maxed
   talents do not spend points; respec still requires confirmation.
6. **Skills:** the short drop/recover instruction is visible. Drop a skill, then
   drag it back from Skills. Check debug.txt for no Invalid textarea element.
7. **Party colors:** a character with no explicit color preference sees class
   colors. Select All green and reopen/reconnect: the explicit choice stays.
8. **Buffs/Sprint:** buffs appear top-center, clear of minimap and chat. Scout
   Sprint shows +50% Speed and its 10-second countdown; expiry/death removes it.

## Targeted follow-up

9. Damage each of the two dragons: its bar should sit near the visible upper
   body/head and be clearly readable at combat distance. At full health it hides.
   Compare a small animal, humanoid and guard: their ordinary bars remain normal.
10. Try the Map/Talents/Skills pages and a full buff list at a smaller window and
    your usual UI scaling. Report clipping/overlap with the window size/scaling.

Engine-native GUI behavior remains a user acceptance step. Offline Lua parity
and server-only integration checks cannot certify drag/focus/rendering behavior.
