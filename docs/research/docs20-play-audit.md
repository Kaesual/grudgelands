# Docs20 play/progression audit

Date: 2026-09-23. Baseline: `d6937b31` (`docs20-play`). Scope was limited to
the assigned living design documents; no code, root planning file, process file,
vendor, reference or media change was made.

## Coverage

Reviewed living authorities:

- `docs/design/combat_stats.md`, `classes.md`, `skill_trees.md`, `scout.md`,
  `progression.md`, `quests.md`, `story.md`, `parties.md`, `world_map.md`,
  `home_travel.md` and `playtest_quality_revision.md`;
- approved and delivered Round 11–19 decision, completion and follow-up records
  relevant to those topics, with priority given to the Round 17 homing/home
  contract, Round 18 quality revision, Round 19 atlas/status work, the Map/Talents
  follow-up and the movement-gated pursuit plus safe idle-healing follow-up;
- targeted current implementation around talent state/UI, ability kits, XP,
  parties, atlas/home, pursuit and idle healing where delivery status or wording
  needed confirmation.

No runtime test or broad source campaign was run; this is a documentation audit.
`git diff --check` passes.

## Round 18 rule ownership

The cross-topic `playtest_quality_revision.md` is now explicitly an index of
delivered decisions rather than a temporary higher-priority override. Its rules
already have these topical owners:

| Revision rule | Living owner |
|---|---|
| Incoming-damage pursuit, movement-gated return, actor exceptions, deferred guard healing | `combat_stats.md` §§4 and Ambient pursuit policy |
| Level-appropriate ambient species and one wildlife family per named zone | `biomes_mobs.md` |
| No death XP loss, level-60 cap, upward-level refill/burst | `progression.md` §3 and `classes.md` level transition contract |
| Shovel/pick loose-material behavior | `items_crafting.md` |
| Equip-slot weapon guidance and semantic ability icons | `classes.md` §2c and `inventory_equipment.md` |
| Trainer/Cooking, Crafting/Skills guidance and inventory selection | `professions.md`, `crafting_equipment_revision.md`, `inventory_equipment.md` |
| Concise quest item names and achievable local objectives | `quests.md` |
| Stable display tags and dragon/injured HP presentation | `combat_stats.md` §6 |
| Full atlas, zoom/scroll, shared window, minimap policy | `world_map.md` |
| Preparation ordering, dismissible waiting and scheduler behavior | `world.md` / current start-preparation authority outside this lane |
| Held-torch light | deferred only; no current implementation owner |

Root may remove `playtest_quality_revision.md` after verifying and remapping its
incoming links. The table above is the required link migration map. The file was
not deleted in this lane.

## Corrections made

- Marked the Round 18 revision as delivered and linked the later receipts that
  amend it. Removed wording that made held light sound optionally delivered;
  it remains explicitly deferred after the complexity preflight.
- Replaced the obsolete Scout ballistic-arrow quotation with the current Round
  17 release-lock homing rule, while preserving the approved simple class and
  the complete deferred stealth-v2 design.
- Removed the stale claim that the Mage crit override remained future WP11 X3
  work; Round 12 delivered the capstone consumers.
- Removed the unselected Warrior rage fallback from the current class rules.
  The delivered +8/+3/-5 ledger remains authoritative.
- Replaced the long superseded Phase-2 Rogue/poison narrative with the current
  rule: Scout has no player poison stat; mob poison and Antivenom remain.
- Reframed the talent introduction as current implemented design instead of an
  active revision/implementation-lane handoff. Preserved the pending measured
  respec-price calibration and every current tree/talent rule.
- Removed round-number labels from topical headings where the section now states
  the current rule. The underlying dates remain where provenance is useful.
- Preserved Round 19 atlas behavior, shared legacy-sized Map window, fixed-size
  markers, party class-color default, Sprint status, dragon HP bars, movement-
  gated pursuit and 30-second safe full idle recovery.

## Remaining approved future scope

- Scout stealth v2 remains deferred and unscheduled in `scout.md` §8, including
  its unresolved PvP/royal-guard/rendering choices. It was not promoted into V1.
- Talent respec prices still await the approved measured-income outputs from
  WP44; current six bracket values remain labelled placeholders.
- Cast bars/ability sounds, Warrior shield abilities and PvP control tuning
  remain deferred in `classes.md`. Friendly-guard healing and held-torch moving
  light remain deferred by Round 18.
- The broader named-zone main story remains future WP9 scope. Current starter
  and local quest catalogs remain implemented; Nether remains expansion scope.
- Rested XP, housing progression, waypoint travel and related later packages
  remain future scope where their topical documents say so.

## Unresolved documentation issues and root requests

1. `skill_trees.md` still contains extensive closed ruling, lane and code-line
   history after the current talent specification. It is internally labelled,
   and no contradictory active rule was found, but a later dedicated reduction
   should move that material to research rather than risk deleting evidence in
   this bounded lane.
2. `scout.md` likewise keeps detailed deferred stealth research. This is approved
   future scope rather than obsolete text, so it must remain available even if
   the living file is later split into current rules plus a research note.
3. Root planning should describe WP8, WP12 and WP20 as shipped and use the
   corrected total supplied by the root audit. This lane makes no global WP-count
   or completion claim.
4. If root deletes `playtest_quality_revision.md`, update all inbound links to
   the topical owners in the table above and retain the Round 18 plan/completion
   as historical execution evidence.
5. GUI acceptance remains pending for the current Round 19 atlas, shared Map
   window, talent affordance, party/status HUD and dragon presentation. The
   living docs describe delivered behavior; they do not claim GUI acceptance.

