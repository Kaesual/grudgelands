# Round 12 execution checkpoint

Date: 2026-09-20. User explicitly said **Go** after the independent plan review.
Status: ACTIVE. Integration branch `wp12-round12`, starting main `3fdd6b35`.
Authority: `round12-plan/README.md`, three package annexes and corrected review.
Frozen planning hashes remain historical and must not be rewritten during work.

## Session contract

Root Astra orchestrates; native Sol workers and independent reviewers. No
Claude, no own-provider CLI. At most three active workers beside root. No PUC
runtime, seed fleets or broad PERF/mapgen suites; mandatory Lua-5.1 parser,
SETGLOBAL/five sweeps plus bounded relevant LuaJIT checks. Native probes only
in disposable isolated test worlds, never the user's world. Fresh-development
mode, no migrations. Existing push/sync authorization persists; sync only the
reviewed integrated main build at final delivery.

## Work ownership and state

| Package | Worker / branch / checkout | State |
|---|---|---|
| FARM | native Sol / `wp32-r12-farm` / `/tmp/grug-r12-farm` | active |
| SKILLS | native Sol / `wp47-r12-skills` / `/tmp/grug-r12-skills` | active |
| ART | native Sol / `wp29-r12-art` / `/tmp/grug-r12-art` | active |
| TALENTS | native Sol / `wp11-r12-talents` / `/tmp/grug-r12-talents` | implementation candidate, behavior validation active |
| UI | root Astra / integration branch | implemented, review queued |
| RECIPES | native Sol / `wp12-recipes` / `/tmp/grug-r12-recipes` | active |
| FOOD | root Astra / integration branch | implemented, review queued |
| POSE | root Astra / integration branch | implemented, review queued |
| Independent code/visual reviews | separate non-author agents | queued |
| UX | independent report-only integrated-candidate audit | queued |

Workers first fold their approved rules into assigned living design sections,
then implement. Root owns cross-package integration, checkpoint/status docs and
shared-file handoffs. Do not let both Skills and Talents edit abilities init;
Creative guard patches land before UI Food filtering. Existing reference source
checkouts and luac51 binaries are read from the primary checkout, not repinned
or copied into worker commits. Worktree reference gitlinks remain untouched.

## Completion checklist

- [ ] Living specifications reflect the approved round and TODO is closed.
- [ ] All package implementations and focused evidence complete.
- [ ] Independent reviews and visual acceptance complete, no open blockers.
- [ ] Integrated startup/consumer checks pass on final bytes.
- [ ] UX findings returned as report, without unapproved scope expansion.
- [ ] Main merge, runtime sync, GitHub push, art gallery, next-playtest checklist.

Next: dispatch first-wave workers; root freezes UI/Skills seams, folds shared
specs, then advances remaining packages as worker slots free. Persist exact
heads, findings and next actions here at every significant handoff.

## FOOD candidate

Root changed `grug_food.DURATION` to 300 and made tooltip duration derive from
that value. `tools/r12_food/kat.lua` loads real food and status modules and
checks all 24 tier/role combinations, five-second cadence, the old/new expiry
boundaries and exactly-once deferred instant healing after expiry. PASS; static
parser checks 326 files, only declared/harness globals, five sweeps no live
forbidden constructs, 13 unchanged primary reference pins. Evidence in
`tools/r12_food/evidence/`. Independent review pending; not yet shipped.
The historical R7 combined fixture failed on a pre-existing armor accessor
lookup before its food checks; it was left unchanged and a focused current
fixture replaced it for this bounded change. No broader harness repair added.

## POSE candidate and frozen Skills seam

POSE changes only generic third-person/world attachment fallback; explicit
metadata and existing weapon/tool groups take priority. Real B3D geometry KAT
and required static gates pass; evidence is under `tools/r12_pose/`. ART retained
the existing diagonal grip for wands and double-bit Greataxes. Review pending.

SKILLS published entitlement API at worker commit
`ca55d4a576b82c666aa8f4829b9ae45809a4da8d`: `is_unlocked(player,id)`,
`unlocked_ids(player)`, `stack_for(player,id)`, `normalize_kit(player)`. TALENTS
may target this seam but must not concurrently edit abilities init.

Hades research download (not an imported or pinned source):
`https://content.luanti.org/packages/Wuzzy/hades_revisited/releases/35045/download/`,
version 0.20.2; archive SHA256
`332108fbedea5ea74f226c3bdae0ebfe2087d80f6252b06a63c6b2cc0bfa2d6e`.
No media import is authorized without verified per-file provenance and a
permanent reference pin; existing pinned alternatives remain preferred.

## First reviews and second wave

Independent Sol reviewer passed FOOD and POSE. ART `b44093bd` needs two Medium
corrections (broader opposing axe blade; include existing cooked meat/fish in
gallery). FARM `a1f1541f` needs whole-organism missing/foreign-helper refusal
and distinct berry/cane/bamboo silhouettes; original author is correcting it.
SKILLS `900102d7` review found missing talent unlock notice, equipment-stray
cleanup/notifier gaps, owner guard on catalog delete and late-detached audit.
Root owns these corrections after UI commit. Review reports currently under
`/tmp/grug-r12-{food-pose-art,farm,skills}-review.md`; archive at integration.

UI candidate uses a game-owned shared 10.4×11.1 form, content ending before 7.0
and main inventory at y=7.2/8.35. Character has separate model/stats/gear columns;
Talents has wider controls, wrapped tooltips and taller description, Help begins
with onboarding and Creative Food derives from edible groups. Recipes consumes
`grug_inventory.wrap_text(text,width)` and owns jobs files exclusively.
Existing focused layout/talent UI fixtures were brought to current Scout and
armor-rating API mocks, then pass layout bounds and purchase/respec behavior.
Source/static gates pass. No GUI readability claim until user playtest.

TALENTS author published `8478e603` but required behavior/native validation is
not complete. It now owns a separate serialized Whitehot cost hook commit in
its own checkout: `cost_for(player,cost,ability_id)` snapshots Fireball at 3%
while Whitehot is active before affordability/spend. Original Skills frozen
review bytes stay unchanged. Do not integrate X3 as complete on source-pattern
tests alone; required consumer and bounded native checks remain.

## Integrated candidates and active review gates

Root integrated independently approved FARM (`bd7c96ab`, `630d1d70`) and ART
(`301dcefc`, `81874bdb`). UI `562c1e48` independently passed. FOOD/POSE passed.
Review reports are archived under `round12-reviews/` (initial findings retained).

SKILLS commits `006ff5bb`, `932cde07`, root correction `eaac9849` now include
real callback/normalization/mount/transfer/cooldown tests and authoritative
cast/swing entitlement checks. Farm author, independent of Skills code, is
rechecking corrections. Recipe author Sol is correcting its initial review's
3 High +1 Medium findings on `wp12-recipes`: alloy main materials, Cooking
refinement provenance, Bronze armor starters, and complete runtime catalog
coverage. It must use the existing isolated Flatpak headless launcher rather
than claim an absent standalone binary prevents validation.

X3 candidate commits `8478e603`, `5a3e8894`, `5799c524` in
`/tmp/grug-r12-talents` include behavior tests and a bounded native LuaJIT probe.
A fresh native Astra reviewer `r12_x3_review` is auditing actual settlement and
all decided consumers. Not integrated before its review closes. Root's
`tools/wp39/combat_integration_test.lua` owns the shared mock update and already
passes the real existing settlement scenarios under current Skills lifecycle.

Remaining: re-review Skills/Recipes/X3; integrate their final corrections;
final focused consumer/static/native catalog and registration checks; fresh
report-only UX; update status/backlog/roadmap/README, close TODO; main merge,
sync/push and next playtest delivery. No Round12 bytes installed yet.

## Current checkpoint: reviewed packages and final corrections

Skills is independently clean at `eaac9849`. The separate UX reviewer also
approved the subsequent Q1 starter-weapon onboarding correction and Q2 separate
Abilities/Mounts catalog rows (real Skills behavior fixture PASS). Q3 trainer
wording, Q4 unlearn wrapping and P1/P2 style suggestions remain report-only.
FARM, ART, FOOD, POSE and UI have independently clean review outcomes; earlier
"active/pending" entries above are chronological history, not current gates.

RECIPES initial review remains 3 High / 1 Medium; Sol author is correcting the
full runtime catalog and Cooking ownership. X3 independent Astra review found
5 High / 5 Medium defects: accepted-action settlement, shield contribution
lifecycle, wear identity, physical impact location and insufficient consumer
proof, plus exact design numbers/modifiers. A separate Astra implementer now
owns `/tmp/grug-r12-talents`, including its own abilities init cost/context
seams and repair opaque-token deduplication. Root owns the shared wp39 fixture;
root Skills entitlement changes must survive integration. Original independent
reviewer must re-review X3 corrections. No package is marked shipped yet.

Root has prepared `tools/r12_integration/probe_round12` for an isolated final
native catalog/registration smoke after both remaining packages integrate;
this probe has not run yet. Gallery and next-playtest drafts are in
`round12-gallery.md` and `round12-next-playtest.md`. No Round12 runtime sync.

## Recipes closed

The second re-review caught one remaining High: presentation-only ownership
still allowed universal furnace extraction. Sol corrected this through verified
existing-engine recipe registrations; actual furnace callbacks now deny all
three refinements without Cooking and award progression after successful takes.
The obsolete discovery stub/caller was removed. Independent Sol review is clean
at `f86bc36a`; root integrated the three commits as `fa4b7ab6`, `afa7e632`,
`c46d94eb`. Native catalog: 830 routes, 596 Basics, 234 profession-owned,
63 starters, five dual alloys, four Bronze armor starters; all three refinements
have actual Cooking authority. X3 final correction/review remains pending.
