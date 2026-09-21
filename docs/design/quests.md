# Quests

Decided 2026-09-21; Round 14 user Go.


### Confirmed by the user

- The Nether is excluded from V1 and reserved for the first expansion. V1
  quests must not require visiting it or obtaining Nether-exclusive items,
  kills or unlocks.

- Exactly 20 active quests maximum; accepting beyond that is refused with a
  clear explanation. Completion or abandonment frees a slot.
- A dedicated Quest inventory tab supports viewing and abandoning quests.
- A quest HUD toggle lives in this tab, defaults on and is saved per player.
  No active quests means no quest HUD, without changing the saved preference.
- Objective families are **item turn-in** and **kill**. A crafting lesson can
  request the resulting item. No separate crafting, mining, visit or escort
  objective engine is required for V1.
- Kill credit uses the same per-mob damage/effective-healing participation and
  eligibility mechanism as shared XP, never a killing-blow test and never
  party membership. Players from different parties are not a special case.
- Quest-giver markers are attached floating 3D question/exclamation symbols with `set_observers()`.
  Use the existing tag visibility/hysteresis loop and distances, not a second
  independent all-players scan.
- Marker precedence: ready to turn in (yellow question mark), available
  (yellow exclamation mark), active but incomplete (silver question mark),
  relevant prerequisite-locked quest (silver exclamation mark), otherwise none.
- Quest chains use existing faction story and zone identities. No cross-faction
  cooperative questline is introduced.

### Accepted defaults

- Track up to three selected quests on the HUD. Keep the tab authoritative;
  do not place the entire journal permanently on screen.
- Item turn-ins accept already-owned and traded/crafted-by-others items.
  Descriptions say “Bring ...” instead of claiming to verify personal crafting.
  V1 requirements match registered item id and count only, with no wear,
  enchantment, quality or provenance predicates. Author hand-ins around ordinary
  resources and basic Wood/Stone tools; do not request valuable enchanted gear.
- Count and consume from main inventory and the player's owned bag contents
  through existing inventory APIs; do not reach into equipment, stations,
  chests or another player's inventory. Recheck at turn-in, not only in the UI.
- Kill counters start at acceptance; item readiness reflects current holdings.
  Sharing credit does not divide quest counters: one eligible kill is one
  count for each relevant active quest. XP splitting itself stays unchanged.
- Do not use `xp > 0` as the sole participation test: gray-level XP suppression
  must not accidentally hide the shared eligible participant event from quests.
  Quest min-level/prerequisite/faction and target rules remain independent.
- Abandoning a quest removes its counters, not ordinary player items. It may be
  accepted again if prerequisites still hold. Completed one-time quests remain
  completed and do not consume active-log slots.
- One-time XP/coin/item rewards, with all prerequisites, consumed items and
  reward space preflighted together; insufficient space refuses the turn-in
  without consumption or a dropped reward. Avoid adding mail/escrow systems.
- Repeated packets and repeated dialogue clicks must not duplicate rewards.
  Persist active/completed state and HUD preference across reconnect/restart.
- Locked markers only expose the next relevant chain step, not all distant
  future quests. NPCs with multiple quests offer a simple list.
- Explain optional crafting through a side branch; do not force every player
  to craft as a prerequisite for the local combat story.
- Opening kill lessons use common mobs and small counts (e.g. five boars).
  Avoid five low-drop-rate tusks as the first mandatory task. Quest materials
  must actually exist locally under the current zone/time spawn policies.

## Round 15 presentation and regional expansion

Decided 2026-09-21: enlarge quest symbols fivefold while holding their upper
extent fixed (growth downward). Keep per-viewer states and existing visibility
hysteresis. The optional three-quest HUD sits at screen middle-right, with
right-aligned wrapped text and edge padding.

Add six optional local quests per race at the existing village/outpost/camp
and one additional village giver per race: 102 quests and 30 giver identities
in total. Reuse kill/item-hand-in objectives and existing race/faction gates;
no Nether, escort, custom quest drops or new world anchors. Compose tasks with
the visible local workplaces and ensure targets/materials are locally available.
Retune later quest XP modestly against authored target level/effort and required
combat; fixed rewards do not scale with the level at turn-in. Introductory
rewards must not receive a blanket increase.
