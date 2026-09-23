# Playtest quality revision — Round 18

Decided and implemented 2026-09-23. This file is the cross-topic index for the
Round 18 playtest corrections, amended by the delivered Round 19 pursuit and UI
follow-ups. The topical documents remain authoritative for the complete rules;
implementation receipts are [Round 18](../research/round18-completion.md),
[Round 19](../research/round19-completion.md), the
[pursuit/idle-recovery follow-up](../research/round19-pursuit-followup.md) and
the [Map/Talents follow-up](../research/round19-ui-followup.md).

## Combat and world populations

- Ordinary free-roaming world mobs can be pulled indefinitely while receiving
  effective incoming HP damage from players or guards. Initial aggro starts a
  15-second grace clock; further incoming damage resets it. Without incoming
  damage for 15 seconds, the Round 19 follow-up permits return only when their
  current live target moves horizontally (see combat_stats.md). Standing still
  does not reset the clock. Missing/dead-target cleanup remains unchanged, as do
  the heal/untouchable-return and 40-second fallback teleport.
- Bosses/retinue, location-bound guards, camp-owned mobs and location-bound rares
  retain existing encounter/post/slot bounds. No new damage-origin anchor rule.
- Ordinary surface species spawn only where their natural minimum level fits
  local difficulty; no upward species clamp into easier starting bands.
- Only one lookalike wildlife variant per named zone; NPCs/guards may share
  models. Related startquests and local drop sources remain achievable.
- Friendly-guard healing is deferred as a coherent support-combat feature.

## XP and tools

- No death causes XP loss. Existing inventory, home and damage-event wear remain.
- Cumulative XP saturates at level 60, including admin grants. Excess is discarded.
- Actual upward level changes fill living characters' HP and mana to new maxima;
  rage is unchanged. One gold burst for a multi-level grant. No resurrection,
  join/equipment refill or downward-level refill.
- Shovels dig loose material, never rock/ore. Pickaxes dig loose material at twice
  the matching shovel time and retain rock/depth authority. Existing shovel speed
  and all approved tool durability values remain.

## Presentation and onboarding

- Weapons still function through equipped Weapon slot + combat skills only.
  Tooltips, slot guidance and a contextual hint explain this. No auto-equip.
- Active skills get semantic inventory/hotbar icons; held representation remains
  the equipped weapon, including bow draw stages. Existing accepted gear art stays.
- Trainer learning gets clear success/guidance; Cooking cannot be unlearned.
  Primary professions retain confirmation of progression loss before unlearning.
- Crafting and Skills pages explain their use; inventory hotbar row and selected
  controls are visibly highlighted. Quest objective names omit item stat lines;
  worn qualifying tools remain valid turn-ins.
- Stable display nametags use managed 25/30-node hysteresis and NPC lilac.
- Round 19 supersedes regional cutouts with one complete atlas, 1x/2x/4x zoom
  and native scrollbars; see world_map.md.
  Native minimap defaults to terrain + own arrow; all other object/player dots
  hidden. Rich party/quest/trainer markers stay on the atlas.
- Preparation precedes faction/race/class selection. Waiting can be dismissed
  to reach the native menu, without releasing safety gates. A failure transition
  reopens the error/retry form once; routine progress does not steal focus.

## Preparation and held light

- Preserve conservative surface coverage, world-mode lock, stop/resume,
  retries and tile progress; remove avoidable idle gaps, not legitimate I/O waits.
  Keep one emerge thread. Do not change accepted early ETA correction. Only short
  investigation; optional final 60–120-second observation occurs at most once.
- Held-torch moving light is deferred after the required VoxeLibre
  preflight. The existing approach owns light propagation/removal and multiplayer
  restoration, exceeding this round's simplicity condition. No client overlay or
  general lighting framework is substituted. All other round scope remains.
