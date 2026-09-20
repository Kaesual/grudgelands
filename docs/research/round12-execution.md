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
