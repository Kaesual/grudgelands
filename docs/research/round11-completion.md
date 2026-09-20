# Round 11 completion

Date: 2026-09-20. Baseline: main `ac232ec2` (Round 10).
Status: **DELIVERED — next playtest ready.** All implementation, independent
review and final technical gates PASS; main merge, synchronization and push complete.

The user authorized autonomous implementation of the approved
[plan](round11-plan/README.md), native Sol workers/reviewers and Astra for hard
work. Own-provider agents used native collaboration, never CLI; Claude was not
used. The user explicitly waived **all PUC runtime** for this round, including
the normal final parity pair. Plain-5.1 parser/SETGLOBAL/five static sweeps remain.
No old-world migrations, compatibility aliases or user-world edits were added.

## Delivered scope

- **GAME / WORLD-CAP:** immediate profession-book refresh, station window width,
  mount/rider look orientation, current-world dragon unload/reload persistence,
  corrected diagonal beach lowering, open earth-floor stables with animated
  grounded mounts, profession product displays and the one-cell gate clearance.
  The reported beach seed and both coordinates are retained in the checklist.
- **AFF-GEAR / ART:** one prefix and one suffix with family legality, bows,
  shields, two-handed staves versus wand/book, optional four-stack quiver,
  equivalent cloth/leather bags, distinct seed art, proper anvil/loom/bench
  presentation, neutral Silversteel and licensed reference imagery.
- **COMBAT:** uncapped raw armor rating, attacker-level reduction with a final
  70% cap, Protection/Bulwark's deep Unbroken multiplier, actual level-65 kings
  and level-70 dragons. Identical maximum gear reaches about 60.9% against a
  level-70 attacker without deep Protection, 68.5% with it, or 69.6% during its
  bounded emergency window. The Character preview uses the player's own level.
- **FARM:** halved initial density for 25 wild plant rows, 27 renewable source
  identities with bounded loaded-cell depletion renewal, seven hoe lifetimes,
  water-only source buckets and neutral protected-flow guards. Apple/Blueberry
  template populations stay unchanged; ores and salts never renew through this
  ecology system. First renewal is intentionally slow, 4–8 hours after depletion.
- **REPAIR:** slow once-per-settled-action equipment wear, retained broken items,
  all-item copper repair at every city profession trainer, exact stale-quote and
  inventory/money transaction checks, maximum 20% of regular purchase price.
  The future Housing station provider seam is present; Housing itself is not.
- **SCOUT / TRADERS:** fourth class, mana/leather, four base abilities plus
  Strike, all 16 Quarry/Veil talents, held ballistic arrows, atomic ammunition
  and Twin Shot, starter bow/sword/arrows, Bowyer and Tanner stock. No stealth,
  poison, traps or separate Rogue; weapon-derived damage uses the main hand.

Only **WP-Scout** closes as a whole WP: 23 of 53 tracked identities are shipped,
29 remain open/in progress and WP16 remains a canceled tombstone. Original-class
WP11 X3, carried light, broader economy/catalog work, six-pick calibration,
Housing and the general fire/lava/explosion guard remain separately open.

## Package acceptance and calibration

Every substantive package was reviewed by an agent that did not author it.
The heads below are accepted package checkpoints, not a claim that their old
as-of-package evidence covers every later integration edit. Review reports under
[round11-plan/review/](round11-plan/review/) retain both findings and corrections.
Observed elapsed delivery time was not reliably retained: **unknown** for each
package. No zero-finding claim replaces the initial defect record.

| Package | Accepted head | Implementer → independent reviewer | Initial / follow-up findings | Correction rounds |
| --- | --- | --- | --- | --- |
| GAME | `43c09f39` | Sol + root Astra → Sol | 0C/0H; 3M | several; exact count not retained |
| WORLD-CAP | `6270c80d` | Astra → Sol | 0C/0H; clean | 0 |
| AFF-GEAR | `18bbeacb` | Sol + root Astra → Sol | 0C/0H; 1M/2L | 1 |
| COMBAT | `3a9f0ce0` | Sol → Sol | 0C/0H; clean | 0 |
| ART | `28ef659a` | root Astra + Sol → Sol | 0C/0H; 1M | 1 |
| FARM | `a6889da2` | root Astra water/hoes + Sol ecology → Sol | 0C/0H; 1M/1L evidence corrections | 1 |
| SPEC | `ee6c3f6a` | Sol + root final row → Sol | 0C/0H; 4M then 1L | 2 |
| REPAIR | `20ab7b50` | root Astra service + Sol runtime/fixes → Sol | 0C/4H/1M/1L initially; 1 confirmed High cadence follow-up | 2 |
| SCOUT-TRADERS | `9730af25` | Sol + root comment → different Sol | 0C/0H; 2M/1L, then another stale-comment Low | 2 |
| SCOUT | `35bde4c8` | Sol → Astra | 0C/1H/4M/1L | 2 |

REPAIR's alleged ordinary-table identity defect was retracted after inspecting
Lua's actual `and/or` fallback and strengthening the first-debit assertion; it
is not counted as a product defect. Scout review found a real integration gap:
the existing quality wrapper dropped REPAIR's third notification argument.
That fix now preserves held cadence/draw through metadata-only wear updates.
The other Scout fixes cover resolved percentage mana, actual accepted-hit control,
mounted delayed release, true slow/root dispel and compare-first draw writes.

## Bounded verification

Package-specific KATs, input hashes and review evidence are retained in their
existing `tools/r11_*` directories and research records. Final integration adds
only the actual Scout dispatcher/gameplay and WP39 held-swing regression on the
merged bytes, plus changed-boundary regressions required by native findings.
There is no repeated multi-seed resource census, broad PERF run or dedicated
stair test. LuaJIT processes use idle scheduling and stay below the seven-process
ceiling. **No PUC runtime was run.**

The final static set covers all first-party mod Lua plus every changed Lua file,
including tools and the changed vendor file. Production SETGLOBALs are declared
owner tables; fixture globals are deliberate engine/mod mocks. Sweep hits are
comments, string delimiters, frozen manifest data and the existing vendored
namespace, not new prohibited first-party code. All 13 reference submodule pins
remain initialized and unchanged. Exact inputs, raw logs and classifications:
[`tools/r11_integration/evidence/`](../../tools/r11_integration/evidence/).

The native witness uses Flatpak Luanti 5.17.0 with LuaJIT 2.1.1784272936,
`tools/luanti_headless.sh`, a fresh isolated `/tmp` world and a 35-second timeout.
It disables only automatic six-start preload in the disposable probe, constructs
one 16-node scratch block and checks actual ordinary/river water callbacks,
protected air/non-air/metadata, 17 seed bindings, seven repair-priced hoes and
Scout registration. It does not claim visual, combat GUI or full world acceptance.

The first engine run passed its catalog and water witness (22 protected-air
callbacks, 4 allowed plant callbacks) but **failed whole-engine acceptance**:
the real mapgen thread rejected FARM's added planner-source fields, and the
startup trader audit found the arrow purchase/buy-back boundary. Its failed log
is preserved as `engine-initial.log`; successful water alone was not accepted.
Both narrow fixes passed an independent native Sol review with zero findings:
Astra extended the exact planner-source contract by four required functions
without changing geometry, and Sol raised the arrow offer from 2c to the minimum
safe 3c (discounted 2c, buy-back 1c). Correction rounds: one per defect;
observed elapsed time unknown. Review: [integration-final.md](round11-plan/review/integration-final.md).
The real runtime-zones → R5 → planner constructor/one-column fixture now passes,
and rejects unknown, missing or wrong-type fields. The real trader startup audit
fixture proves both the failing 2c control and the corrected 3c offer.

The second and final engine run **PASS** has no ERROR/ModError and an explicit
`R11_INTEGRATION_PASS` receipt: engine 5.17.0, LuaJIT 2.1.1784272936, 22 protected
callbacks and 4 allowed plant callbacks. All **1,894 staged runtime files** match
repository bytes; `runtime-inputs.sha256` has SHA-256
`d7c09c5bd10a85c4d4c292381440eb34ecf2fddd10112517948b27110e504d25`.
Final static coverage is **374 Lua files**. There were exactly two bounded
engine attempts, the second justified by the first attempt's concrete failures.
No broad world-generation or GUI acceptance is inferred. Existing nonfatal
recipe-audit warnings and missing Apple/Stick treant sell-price warnings remain
outside this round; the error-level arrow and planner regressions are closed.

## Delivery and next playtest

Final reviewed runtime/evidence checkpoint: `697391d8`; Scout merge: `5202dc1a`.
Documentation checkpoint `63242192` reconciles living specs, BACKLOG/ROADMAP/README
and the next-playtest checklist. Main merge
`737f25b4787d21a9e36d068e9bcd27fe032b5b3f` includes the full reviewed history.
`tools/sync_to_luanti.sh` ran from main, and every one of the 1,894 installed
runtime files matches the engine-tested payload. The authorized
`git push origin main` succeeded to `github.com/Kaesual/grudgelands`, advancing
remote main from `ac232ec2` to `737f25b4`. This final documentation receipt adds
no runtime changes. All worker/reviewer tasks are finished; GUI acceptance is
the next user action.

User runtime acceptance follows the
[Round 11 fresh-world checklist](round11-next-playtest.md). Prioritize the reported
beaches/capital defects and dragon return, then Scout, offhand/affix rules,
slow wear/repair, Protection versus damage armor, buckets and farming. Creative
must be off for wear. Slow natural renewal is an optional later observation,
not a requirement to wait hours during the short playtest.
