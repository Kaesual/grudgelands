# Round 12 completion

Date: 2026-09-20. Technical implementation and independent review complete.
Main merge `81364e85`, runtime sync and authorized GitHub push are complete;
the final [execution checkpoint](round12-execution.md) records the receipt. GUI acceptance remains the user's next playtest.

## Delivered scope

- WP47 Skills: separate active-ability and mount lists, delete-on-drop without
  world entities, duplicate-safe manual recovery, owned bags and authoritative
  entitlement. Base kits are inserted once; later unlocks announce availability.
  Every purchased mount tier remains available at its original speed.
- Farming: seventeen families with distinct stages and annual, regrowing or
  retained-base harvests; Corn/Cane/Bamboo reach three/four/three nodes. Root-owned
  rewards and exact whole-organism preflight prevent duplicate/partial harvests.
  Existing bounded wild renewal remains separate.
- Basics: 596 routes, 63 immediate starters, persistent main-material discovery
  without crafting-level gates. Exact catalog audit covers 830 engine routes;
  234 have profession ownership. Bread, Cooked Meat and Cooked Fish use real
  Cooking furnace authorization and progression, and appear only in Cooking.
- UI: shared larger inventory, separated Character columns, wrapped Talents,
  onboarding Help, Creative Food with 57 edible entries and recipe station icons
  below the arrow. Generic held-icon fallback rotates forward in third person;
  authored poses and the engine's first-person wieldmesh remain separate.
- Food and art: every food status lasts 300 seconds. Distinct cooked/preparation
  sprites, six wand and double-bit Greataxe tiers; accepted swords, one-handed
  axes, armor and harvested crop icons retained. See the [gallery](round12-gallery.md).
- WP11 X3: four original-class abilities, gated Renew/Hamstring, replacements
  and capstone consumers. Accepted-hit settlement, named shield lifecycle,
  shared action wear, exact impact locations and talent numbers are independently
  reviewed. Scout and Ironbound/Unbroken behavior are preserved.

WP11 remains in progress only for the measured WP44 respec-price calibration;
WP32 still needs Claim Stone integration. Broader economy, Housing, quests and
world-structure work are unchanged. WP47 is the newly completed identity:
**24 of 53 shipped, 28 open/in progress, one canceled (WP16).**

## Validation and limits

The final integrated code passes all 110 native X3 assertions and the separate
native catalog/registration/discovery/Creative-Food probe under LuaJIT
2.1.1784272936. The existing combat settlement fixture, real Skills callbacks,
UI geometry and talent purchase/respec fixtures pass after neutral dependency
updates; no prior assertions were removed. Final static gates parse 351 Lua
files with plain Lua 5.1, inspect declared globals and all five source sweeps.
Sweep hits are comments, string delimiters/UI text and frozen manifest data;
no prohibited live constructs remain. Thirteen reference pins are unchanged.

Final evidence: `tools/r12_integration/evidence/`. All 1,961 runtime payload
files match the native catalog staging copy; its canonical manifest SHA256 is
`9f46c3c50ff80ba3bd8d510280ddf42dc162fa6c102bd10b0286d85dfdb04fda`.
Package-specific evidence remains with each `tools/r12_*` directory and
`tools/wp11/evidence/20260920-x3-corrections/`.

Native probes use synthetic player/mob adapters with actual game consumers;
they do not claim GUI, network-client or real fallback-engine acceptance.
The explicit session exception was **no PUC runtime**; no interpreter parity,
broad mapgen/seed/PERF run or user-world modification is claimed. Two independent
final probes ran concurrently with idle scheduling and separate worlds/ports.
Existing trader-price warnings for dropped Apple/Stick remain WP44 economy
work, not new Round12 regressions.

## Newly reported station architecture followup

The user identified shared world-station inventories during final delivery.
Ingredients/results are not bound to the supplying player; eligible users can
remove each other's work. Timer-based production can consume ingredients before
output-take profession authorization and leave results the supplier cannot take.
Normal digging refuses nonempty stations. This architecture needs a separate
multiplayer ownership/early-authorization package; see
[the open decision brief](../../TODO-station-ownership.md). The user explicitly
instructed completion of Round12 without implementing this additional scope.

## Independent review and calibration

All implementations and substantive coordinator corrections received separate
non-author review; final open implementation findings are zero. Elapsed wall
time is unknown for every lane. Models are native GPT-5.6 Sol and GPT-6 Astra;
no Claude or same-provider CLI delegation was used.

| Lane | Implementation | Independent review | Initial Critical/High | Correction rounds |
|---|---|---|---|---|
| FOOD, POSE | Astra | Sol | 0/0 | 0 |
| UI | Astra | Sol | 0/0 | 0; two approved UX contract corrections rechecked |
| FARM | Sol | Sol, non-author | 0/1 | 1 |
| ART | Sol, Astra blade correction | Sol, non-author | 0/0 | 1 (two Medium findings) |
| SKILLS | Sol, Astra corrections | Sol, non-author | 0/0 | 1 (two Medium/two Low findings) |
| RECIPES | Sol | Sol, non-author | 0/3 | 2; first correction retained one High authority defect |
| X3 | Sol, separate Astra corrections | Astra, non-author | 0/5 | 1; final integration recheck clean |

Detailed reports preserve the original findings and closure evidence under
[round12-reviews](round12-reviews/). X3's initial mocked/source-token fixtures
were rejected and replaced by actual consumer evidence. The repair-expression
parentheses are behaviorally equivalent; the real wear correction shares one
action identity across damage and support/secondary effects.

## UX report and next playtest

The independent [UX report](round12-reviews/ux.md) is source/heuristic and
asset-plate review, not observed novice GUI testing. Approved requirements Q1
(starter onboarding) and Q2 (separate Skills sections) were corrected. These
remaining proposals deliberately await a future user decision:

- Q3: clarify trader wording where “carried” currently means main inventory.
- Q4: wrap the profession-unlearning confirmation more clearly.
- P1: consider a later style pass for retained Cooked Meat/Fish sprites.
- P2: improve low-stage Salt Crust silhouette differences.

Start with the [Round12 checklist](round12-next-playtest.md): UI/Basics/Skills,
food and art, then family harvests and one new talent per original-class tree.
